--!strict
-- The moment an egg comes home safe (spec Rule 5 and the "Egg safe at home" row of section 6), for everyone in the
-- server, because it happens in the world. The server fires EggHome (player, rarity, position of the new egg), and for
-- each one this module does two things:
--   * confetti: a burst of 160 from that player's own Safe Gate arch (the SafeConfetti emitter that is already in the
--     place, found through the player's PlotIndex);
--   * "+1 egg": gold words with an Ink outline, no panel, that float up from the new egg and fade out over 1 second.
-- (The green card is for the player who banked only, so it lives in Hud/Messages.)
-- It also draws the star puff (spec Rule 13, "Hand slams hunt egg carriers"): when the server fires Caught for a player,
-- every device bursts a puff of stars and smoke on that player's own spawn spot, where they now stand.
-- Everything it touches is passed in, so a test can give it stand-ins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Theme = require(script.Parent.Parent.Hud.Theme)

local Celebrations = {}

local CONFETTI_COUNT = 160
local FLOAT_SECONDS = 1
local RISE_STUDS = 3
-- The middle of the words starts this many studs above the top of the new egg.
Celebrations.startLift = 2

-- The star puff. The template in the place (ReplicatedStorage.Assets.CaughtPoof) is an Attachment holding two emitters,
-- switched off: "CaughtPoof" (white-gold stars) and "CaughtCloud" (white smoke). Each caught player gets a copy.
-- Starting values from designer: a puff smaller than the slam dust, because it wraps one player.
local STAR_EMITTER = "CaughtPoof"
local CLOUD_EMITTER = "CaughtCloud"
Celebrations.starCount = 30
Celebrations.cloudCount = 15
-- A standing player's middle is this many studs above the top of the spawn spot.
local PUFF_LIFT = 3
-- The emitters' longest particle lifetime is 3 seconds, so the copy goes away 3 seconds after its burst.
local PUFF_SECONDS = 3

local FLOAT_TEXT = "+1 egg"
local FLOAT_NAME = "EggPlusOne"
-- The sign's size is in studs, so it shrinks with distance like the eggs-waiting tag. The words are never under 18 px
-- or over 44 px, and the sign is hidden past 120 studs. It is the biggest moment on screen, so it is large.
local SIGN_WIDTH_STUDS = 12
local SIGN_HEIGHT_STUDS = 3.6
local MIN_TEXT = 18
local MAX_TEXT = 44
local OUTLINE_THICKNESS = 2
local MAX_DISTANCE = 120

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

-- The EggHome remote, as far as this module uses it: it fires (player, rarity, position of the new egg).
export type EggHomeLike = { OnClientEvent: SignalLike }

export type EmitterLike = {
	Emit: (self: any, count: number) -> (),
}

-- The Caught remote, as far as this module uses it: it fires the player who was caught.
export type CaughtLike = { OnClientEvent: SignalLike }

export type Deps = {
	eggHome: EggHomeLike, -- the EggHome remote
	caught: CaughtLike, -- the Caught remote
	-- Gives a garden's spawn spot (garden numbers 1 to 8), or nil if it isn't there (yet): with streaming, a far spot can
	-- be missing on this device.
	findSpawnSpot: (plotIndex: number) -> BasePart?,
	-- The star puff to copy (ReplicatedStorage.Assets.CaughtPoof), or nil if the place doesn't have it: then there is no puff.
	poofTemplate: Instance?,
	-- Bursts `count` particles from an emitter (the game calls emitter:Emit(count); tests record it).
	burst: (emitter: ParticleEmitter, count: number) -> (),
	-- Gives the confetti emitter of a garden's Safe Gate (garden numbers 1 to 8), or nil if it isn't there (yet).
	findEmitter: (plotIndex: number) -> EmitterLike?,
	anchorParent: Instance, -- where each "+1 egg" puts its Attachment (Workspace.Terrain)
	step: SignalLike, -- once per frame, for the motion; called with the seconds since the last frame (RenderStepped)
	now: () -> number, -- a clock in seconds (os.clock)
}

-- Where the "+1 egg" is `t` of the way through its 1 second (0 to 1): how many studs it has risen and how
-- see-through it is (0 is solid, 1 is gone). It rises fast at first and slows down; it fades evenly.
function Celebrations.float(t: number): { rise: number, transparency: number }
	local clamped = math.clamp(t, 0, 1)
	local slow = 1 - clamped
	return {
		rise = RISE_STUDS * (1 - slow * slow),
		transparency = clamped,
	}
end

-- A finder for the confetti emitters under `world` (Workspace.World): Plots.Plot_N.SafeGate.ConfettiSource.SafeConfetti.
-- It looks again on every call, so a gate that streams in later is found. It gives nil for anything missing.
function Celebrations.emitterInWorld(world: Instance): (plotIndex: number) -> EmitterLike?
	return function(plotIndex: number): EmitterLike?
		local node: Instance? = world
		for _, name in { "Plots", `Plot_{plotIndex}`, "SafeGate", "ConfettiSource", "SafeConfetti" } do
			if node == nil then
				return nil
			end
			node = node:FindFirstChild(name)
		end
		if node ~= nil and node:IsA("ParticleEmitter") then
			return node :: any -- a ParticleEmitter has the Emit that EmitterLike asks for, but its class type doesn't say so
		end
		return nil
	end
end

-- A finder for the spawn spots under `world` (Workspace.World): Plots.Plot_N.SpawnSpot. It looks again on every call, so a
-- spot that streams in later is found. It gives nil for anything missing.
function Celebrations.spawnSpotInWorld(world: Instance): (plotIndex: number) -> BasePart?
	return function(plotIndex: number): BasePart?
		local node: Instance? = world
		for _, name in { "Plots", `Plot_{plotIndex}`, "SpawnSpot" } do
			if node == nil then
				return nil
			end
			node = node:FindFirstChild(name)
		end
		if node ~= nil and node:IsA("BasePart") then
			return node
		end
		return nil
	end
end

-- One "+1 egg" in the world.
type Floater = {
	attachment: Attachment,
	sign: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
	startedAt: number,
}

-- The garden number (a whole number from 1 up) the server gave a player, or nil.
local function plotIndexOf(player: Instance): number?
	local value: any = player:GetAttribute("PlotIndex")
	if type(value) == "number" and value >= 1 and value == math.floor(value) then
		return value
	end
	return nil
end

-- One star puff in the world: the copy, and when its burst was.
type Puff = {
	attachment: Attachment,
	burstAt: number,
}

-- Makes a "+1 egg" at `position`: an Attachment on `anchorParent` that holds the sign. The sign is placed with
-- StudsOffsetWorldSpace (StudsOffset is measured from the camera, so it is never used here).
local function makeFloater(anchorParent: Instance, position: Vector3, now: number): Floater
	local attachment = Instance.new("Attachment")
	attachment.Name = FLOAT_NAME
	attachment.Parent = anchorParent
	attachment.WorldPosition = position

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Adornee = attachment
	sign.Size = UDim2.fromScale(SIGN_WIDTH_STUDS, SIGN_HEIGHT_STUDS)
	sign.MaxDistance = MAX_DISTANCE
	sign.AlwaysOnTop = true -- it lasts 1 second in the banker's own garden, so it may show through the arch and fences
	sign.LightInfluence = 0
	sign.Active = false

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = Theme.font
	label.TextColor3 = Theme.gold
	label.TextScaled = true
	label.Text = FLOAT_TEXT
	label.Parent = sign

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = OUTLINE_THICKNESS
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = MIN_TEXT
	limit.MaxTextSize = MAX_TEXT
	limit.Parent = label

	sign.StudsOffsetWorldSpace = Vector3.new(0, Celebrations.startLift, 0)
	sign.Parent = attachment
	return { attachment = attachment, sign = sign, label = label, stroke = stroke, startedAt = now }
end

-- Starts the celebrations. Returns a function that stops them and removes everything they made.
function Celebrations.start(deps: Deps): () -> ()
	local trove = Trove.new()
	local stopped = false
	local floaters: { Floater } = {}
	local puffs: { Puff } = {}

	local function removeAll()
		for _, floater in floaters do
			floater.attachment:Destroy() -- the sign goes with it
		end
		table.clear(floaters)
		for _, puff in puffs do
			puff.attachment:Destroy() -- the emitters go with it
		end
		table.clear(puffs)
	end
	trove:Add(removeAll)

	local function onEggHome(player: any, _rarity: any, position: any)
		if stopped then
			return
		end
		if typeof(player) == "Instance" then
			local plotIndex = plotIndexOf(player)
			local emitter = if plotIndex ~= nil then deps.findEmitter(plotIndex) else nil
			if emitter ~= nil then
				emitter:Emit(CONFETTI_COUNT)
			end
		end
		if typeof(position) == "Vector3" then
			table.insert(floaters, makeFloater(deps.anchorParent, position, deps.now()))
		end
	end

	-- A player was caught: a puff of stars and smoke on their spawn spot. It is placed on the spot, not on the character,
	-- because the character may not have moved there yet when the remote arrives.
	local function onCaught(player: any)
		local template = deps.poofTemplate
		if stopped or template == nil or typeof(player) ~= "Instance" then
			return
		end
		local plotIndex = plotIndexOf(player)
		local spot = if plotIndex ~= nil then deps.findSpawnSpot(plotIndex) else nil
		if spot == nil then
			return
		end
		local copy = template:Clone()
		if not copy:IsA("Attachment") then
			copy:Destroy()
			return
		end
		copy.Parent = deps.anchorParent
		copy.WorldPosition = spot.Position + Vector3.new(0, spot.Size.Y / 2 + PUFF_LIFT, 0)
		table.insert(puffs, { attachment = copy, burstAt = deps.now() })
		for _, child in copy:GetChildren() do
			if child:IsA("ParticleEmitter") then
				if child.Name == STAR_EMITTER then
					deps.burst(child, Celebrations.starCount)
				elseif child.Name == CLOUD_EMITTER then
					deps.burst(child, Celebrations.cloudCount)
				end
			end
		end
	end

	-- Moves each "+1 egg" along `float`, and takes it away when its second is over. Takes each star puff away when its
	-- particles are gone.
	local function onStep()
		local now = deps.now()
		for index = #puffs, 1, -1 do
			if now - puffs[index].burstAt >= PUFF_SECONDS then
				puffs[index].attachment:Destroy()
				table.remove(puffs, index)
			end
		end
		for index = #floaters, 1, -1 do
			local floater = floaters[index]
			local t = (now - floater.startedAt) / FLOAT_SECONDS
			if t >= 1 then
				floater.attachment:Destroy()
				table.remove(floaters, index)
			else
				local state = Celebrations.float(t)
				floater.sign.StudsOffsetWorldSpace = Vector3.new(0, Celebrations.startLift + state.rise, 0)
				floater.label.TextTransparency = state.transparency
				floater.stroke.Transparency = state.transparency
			end
		end
	end

	trove:Add(deps.eggHome.OnClientEvent:Connect(onEggHome))
	trove:Add(deps.caught.OnClientEvent:Connect(onCaught))
	trove:Add(deps.step:Connect(onStep))

	return function()
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end
end

return Celebrations
