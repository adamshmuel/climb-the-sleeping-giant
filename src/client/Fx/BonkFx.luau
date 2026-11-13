--!strict
-- The bonk on screen (spec Rule 61): when a player's `Bonked` attribute turns "Ground" or "Ladder", the body tips
-- over (Ground only), and a ring of 4 stars and a cream puff show, for 1.0 s. It plays for every player, so
-- everyone sees every bonk. The maths is in BonkPose. The body tips through the root joint's Transform: Studio's R15
-- rig joins its parts with AnimationConstraints, whose C0 and C1 are read-only, and the Animator rewrites Transform
-- every frame before PreSimulation, so the tip is multiplied onto the animation's pose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BonkPose = require(script.Parent.BonkPose)
local SpotLabels = require(script.Parent.Parent.World.SpotLabels)

local BonkFx = {}

-- What this needs of a player; a real `Player` fits, and the tests pass plain tables.
export type PlayerLike = {
	Character: Model?,
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> SpotLabels.SignalLike,
	CharacterRemoving: SpotLabels.SignalLike,
}

export type Deps = {
	players: () -> { PlayerLike }, -- everyone in the server now (Players:GetPlayers())
	playerAdded: SpotLabels.SignalLike, -- fires with the player (Players.PlayerAdded)
	playerRemoving: SpotLabels.SignalLike, -- fires with the player (Players.PlayerRemoving)
	step: SpotLabels.SignalLike, -- once per frame, after the Animator wrote its pose (RunService.PreSimulation)
	now: () -> number, -- a clock in seconds
	reducedMotion: () -> boolean, -- read at each bonk start
	burst: (emitter: ParticleEmitter, count: number) -> (), -- the real one is emitter:Emit(count)
	playSound: ((name: string, at: Vector3?) -> ())?, -- plays a named sound (plan 7); nothing without it
	animatorThrottled: ((Animator) -> boolean)?, -- true when the Animator skipped this frame; default reads EvaluationThrottled
}

local ATTRIBUTE = "Bonked"
local GROUND = "Ground"
local LADDER = "Ladder"
local JOINT_NAMES = { Root = true, RootJoint = true } -- R15 and R6; the joint whose Part0 is the root part
local STAR = "⭐"
local STAR_COUNT = 4
local STAR_SIZE = UDim2.fromScale(0.2, 0.5) -- of the ring, before the depth scale
local STAR_DEPTH_SCALE = 0.2 -- a star in front is 1.2 times the base, one behind 0.8
local RING_SIZE = UDim2.fromScale(5.5, 2.6)
local RING_OFFSET = Vector3.new(0, 2.4, 0)
local PUFF_COUNT = 5
local PUFF_PLACE = Vector3.new(0, -2.5, 0) -- at the feet, from the root part
local PUFF_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local PUFF_COLOR = Color3.fromHex("FFF6E4")

type Joint = AnimationConstraint | Motor6D

-- One bonk that is playing on one player.
type Bonk = {
	startedAt: number,
	still: boolean, -- Reduce Motion: the stars stand still
	joint: Joint?, -- Ground only
	animator: Animator?, -- the Humanoid's Animator, when there is one (it rewrites the joint's Transform each frame)
	rest: CFrame, -- where the joint puts its part, read before the tumble
	pivot: Vector3,
	ring: BillboardGui,
	labels: { TextLabel },
	puff: Attachment,
}

local function bonkSeconds(): number
	local wake = Config.Wake
	return wake.TumbleDownSeconds + wake.TumbleStillSeconds + wake.TumbleUpSeconds
end

local function isRootJoint(descendant: Instance, root: BasePart): boolean
	if not JOINT_NAMES[descendant.Name] then
		return false
	end
	if descendant:IsA("AnimationConstraint") then
		local side = descendant.Attachment0
		return side ~= nil and side.Parent == root
	end
	return descendant:IsA("Motor6D") and descendant.Part0 == root
end

-- The joint that holds the rest of the body to the root part: an AnimationConstraint (Studio's R15) first, else a
-- Motor6D (R6, or an older R15).
local function findJoint(character: Model, root: BasePart): Joint?
	local motor: Motor6D? = nil
	for _, descendant in character:GetDescendants() do
		if isRootJoint(descendant, root) then
			if descendant:IsA("AnimationConstraint") then
				return descendant
			elseif motor == nil and descendant:IsA("Motor6D") then
				motor = descendant
			end
		end
	end
	return motor
end

-- Where the joint puts its part, in the root part's space. C0 on an AnimationConstraint is a read-only stand-in for
-- Attachment0's CFrame, so that is read there.
local function restOf(joint: Joint): CFrame
	if joint:IsA("AnimationConstraint") then
		local side = joint.Attachment0
		return if side ~= nil then side.CFrame else CFrame.identity
	end
	return joint.C0
end

-- Each class is narrowed on its own: the type checker rejects a write to a property of the two-class union.
local function setTransform(joint: Joint, transform: CFrame)
	-- selene: allow(if_same_then_else)
	if joint:IsA("AnimationConstraint") then
		joint.Transform = transform
	else
		joint.Transform = transform
	end
end

-- Every other part, in the root part's space.
local function boxesOf(character: Model, root: BasePart): { BonkPose.Box }
	local boxes: { BonkPose.Box } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			table.insert(boxes, { cframe = root.CFrame:ToObjectSpace(descendant.CFrame), size = descendant.Size })
		end
	end
	return boxes
end

local function newRing(parent: BasePart): (BillboardGui, { TextLabel })
	local ring = Instance.new("BillboardGui")
	ring.Name = "BonkStars"
	ring.Size = RING_SIZE
	ring.StudsOffset = RING_OFFSET
	ring.LightInfluence = 0
	ring.AlwaysOnTop = false
	ring.ResetOnSpawn = false
	local labels: { TextLabel } = {}
	for _ = 1, STAR_COUNT do
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = STAR_SIZE
		label.BackgroundTransparency = 1
		label.Text = STAR
		label.TextScaled = true
		label.Parent = ring
		table.insert(labels, label)
	end
	ring.Parent = parent
	return ring, labels
end

local function newPuff(root: BasePart): (Attachment, ParticleEmitter)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BonkPuff"
	attachment.Position = PUFF_PLACE
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Texture = PUFF_TEXTURE
	emitter.Color = ColorSequence.new(PUFF_COLOR)
	emitter.Size = NumberSequence.new(1.5, 4)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.7)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = attachment
	attachment.Parent = root
	return attachment, emitter
end

-- Puts one frame of a bonk on screen, `seconds` into it.
local function draw(bonk: Bonk, seconds: number, throttled: (Animator) -> boolean)
	local joint = bonk.joint
	local animator = bonk.animator
	if joint ~= nil and not (animator ~= nil and throttled(animator)) then
		local tip = BonkPose.tippedTransform(bonk.rest, bonk.pivot, BonkPose.angleAt(seconds))
		-- With an Animator it wrote its pose into Transform this frame, so the tip goes on top; without one nothing
		-- else writes it, so the tip is set (multiplying would pile up). A throttled frame wrote nothing: skipped.
		setTransform(joint, if animator ~= nil then tip * joint.Transform else tip)
	end
	local turn = Config.Wake.BonkStarTurnSeconds
	for index, label in bonk.labels do
		local place = BonkPose.starPlace(index, STAR_COUNT, seconds, bonk.still, turn)
		label.Position = UDim2.fromScale(place.x, place.y)
		label.Size = UDim2.fromScale(
			STAR_SIZE.X.Scale * (1 + STAR_DEPTH_SCALE * place.depth),
			STAR_SIZE.Y.Scale * (1 + STAR_DEPTH_SCALE * place.depth)
		)
		label.ZIndex = if place.depth > 0 then 2 else 1
	end
end

local function defaultThrottled(animator: Animator): boolean
	return animator.EvaluationThrottled
end

-- Watches every player's Bonked attribute. Returns a function that stops it all.
function BonkFx.start(deps: Deps): () -> ()
	local active: { [PlayerLike]: Bonk } = {}
	local activeCount = 0
	local stepConnection: SpotLabels.ConnectionLike? = nil
	local watched: { [PlayerLike]: { SpotLabels.ConnectionLike } } = {}
	local stopped = false
	local isThrottled = deps.animatorThrottled or defaultThrottled

	local function endBonk(player: PlayerLike)
		local bonk = active[player]
		if bonk == nil then
			return
		end
		active[player] = nil
		activeCount -= 1
		-- With an Animator the next frame puts Transform back by itself; without one it is put back here.
		if bonk.joint ~= nil and bonk.animator == nil then
			setTransform(bonk.joint, CFrame.identity)
		end
		bonk.ring:Destroy()
		bonk.puff:Destroy()
		if activeCount == 0 and stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end

	local function onStep()
		local now = deps.now()
		for player, bonk in active do
			local seconds = now - bonk.startedAt
			if seconds >= bonkSeconds() then
				endBonk(player)
			else
				draw(bonk, seconds, isThrottled)
			end
		end
	end

	local function beginBonk(player: PlayerLike, value: string)
		endBonk(player)
		local character = player.Character
		if character == nil then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return
		end
		local head = character:FindFirstChild("Head")
		local ringParent = if head ~= nil and head:IsA("BasePart") then head else root
		local joint: Joint? = nil
		local animator: Animator? = nil
		local rest = CFrame.new()
		local pivot = Vector3.zero
		if value == GROUND then
			joint = findJoint(character, root)
			if joint ~= nil then
				rest = restOf(joint)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				animator = if humanoid ~= nil then humanoid:FindFirstChildWhichIsA("Animator") else nil
				pivot = BonkPose.pivotOf(boxesOf(character, root))
			end
		end
		local ring, labels = newRing(ringParent)
		local puff, emitter = newPuff(root)
		local bonk: Bonk = {
			startedAt = deps.now(),
			still = deps.reducedMotion(),
			joint = joint,
			animator = animator,
			rest = rest,
			pivot = pivot,
			ring = ring,
			labels = labels,
			puff = puff,
		}
		active[player] = bonk
		activeCount += 1
		draw(bonk, 0, isThrottled)
		deps.burst(emitter, PUFF_COUNT)
		if deps.playSound ~= nil then
			deps.playSound("Bonk", root.Position)
		end
		if stepConnection == nil then
			stepConnection = deps.step:Connect(onStep)
		end
	end

	local function onChanged(player: PlayerLike)
		local value = player:GetAttribute(ATTRIBUTE)
		if value == GROUND or value == LADDER then
			beginBonk(player, value)
		else
			endBonk(player)
		end
	end

	-- Only changes seen after this are played: a bonk already on when the player is watched plays nothing.
	local function watch(player: PlayerLike)
		if watched[player] ~= nil then
			return
		end
		watched[player] = {
			player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
				onChanged(player)
			end),
			player.CharacterRemoving:Connect(function()
				endBonk(player)
			end),
		}
	end

	local function unwatch(player: PlayerLike)
		endBonk(player)
		local connections = watched[player]
		if connections ~= nil then
			watched[player] = nil
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end

	for _, player in deps.players() do
		watch(player)
	end
	local addedConnection = deps.playerAdded:Connect(function(player: any)
		if not stopped then
			watch(player)
		end
	end)
	local removingConnection = deps.playerRemoving:Connect(function(player: any)
		unwatch(player)
	end)

	return function()
		stopped = true
		addedConnection:Disconnect()
		removingConnection:Disconnect()
		for player in table.clone(watched) do
			unwatch(player)
		end
	end
end

return BonkFx
