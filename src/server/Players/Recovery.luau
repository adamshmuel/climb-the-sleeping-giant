--!strict
-- Moves a player back to where they last stood safely (Rules 27, 31 and 33). It saves each player's safe spots from
-- their sample, keeps the spot picked at the moment of a death (a Reset on the giant uses it), and does the move
-- itself. The move is silent for the Sleep meter: the tracker is told first, so the jump is not read as a fall or as
-- walking noise. Everything it touches comes in through `deps`, so a test can use fake players and a fake clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PathCheck = require(script.Parent.Parent.World.PathCheck)
local RecoveryRules = require(script.Parent.RecoveryRules)
local SafeSpots = require(script.Parent.SafeSpots)
local StuckWatch = require(script.Parent.StuckWatch)

-- A Roblox event, as far as Recovery uses it. (The connection is typed `any`: Trove only needs to disconnect it.)
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> any,
}

export type PlayersLike = {
	GetPlayers: (self: any) -> { any },
	PlayerAdded: SignalLike,
	PlayerRemoving: SignalLike,
}

-- Where a player stands: the giant's noise zone, and whether the ground under them is part of the pillow.
export type Where = { zone: Config.ZoneName, onPillow: boolean }

export type Deps = {
	players: PlayersLike, -- each player has UserId, Character and CharacterAdded
	safeSpots: SafeSpots.SafeSpots, -- made with StarterPlayer.CharacterMaxSlopeAngle
	tracker: { moved: (self: any, userId: number) -> () },
	sampleOf: (player: any, now: number) -> SafeSpots.Sample?, -- nil without a living character
	fireRescued: (player: any, from: Vector3, to: CFrame) -> (),
	now: () -> number,
	whereIs: (player: any) -> Where?, -- nil without a living character
	phase: () -> Config.Phase,
	sendHome: (player: any) -> (), -- ends the player's character; Spawning puts them back in their garden
	falling: (player: any) -> boolean, -- the Humanoid is in free fall (a rescue waits)
	floating: (userId: number) -> boolean, -- still floating down after a wake-up (a rescue waits)
	inRedCircle: (position: Vector3) -> boolean, -- inside a red circle that hasn't landed (a rescue waits)
	-- Calls `callback` when the character dies, and returns the connection (or nil). The real one wraps Humanoid.Died.
	died: ((character: Model, callback: () -> ()) -> any)?,
}

export type Recovery = {
	step: (self: Recovery) -> (),
	setPressing: (self: Recovery, player: any, on: boolean) -> (),
	moveBack: (self: Recovery, player: any) -> CFrame?,
	reset: (self: Recovery, player: any) -> (),
	keptSpot: (self: Recovery, player: any) -> SafeSpots.Spot?,
	destroy: (self: Recovery) -> (),
}

local Recovery = {}

-- Lifts the player this far above the spot's ground when placing them, so the feet can't start inside it (Section 5).
local LIFT = 0.5
-- How far below the root the ground ray looks. The body hangs about 3 studs under the root; this leaves some spare.
local GROUND_RAY = 4

local function realDied(character: Model, callback: () -> ()): any
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	return humanoid.Died:Connect(callback)
end

-- The body parts of a living character, found by name (the Humanoid's own RootPart is nil outside Workspace).
local function bodyOf(character: Model?): (BasePart?, Humanoid?)
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil, nil
	end
	return root, humanoid
end

-- Where the feet are: the root is a Humanoid's HipHeight plus half the root's height above them. Spots are feet, so a
-- distance to a spot measures feet to feet (Lesson 110).
local function feetOf(root: BasePart, humanoid: Humanoid): Vector3
	return root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
end

-- Everything made for one player: a trove for the player and one for the current character, which is cleaned on every
-- new character and destroyed with the player's trove.
local function newWatched()
	return { trove = Trove.new(), characterTrove = Trove.new() }
end
type Watched = typeof(newWatched())

function Recovery.start(deps: Deps): Recovery
	local safeSpots = deps.safeSpots
	local diedFn: (Model, () -> ()) -> any = deps.died or realDied
	local trove = Trove.new()
	local destroyed = false
	local watched: { [number]: Watched } = {}
	local kept: { [number]: SafeSpots.Spot? } = {}
	local moves: { [number]: { number } } = {} -- when each player was last moved back (the last LoopSeconds only)
	local pressing: { [number]: boolean } = {} -- who is pressing to move right now, as the client says
	local holding: { [number]: any } = {} -- the players held still after a move back, until they let go (attribute Held)
	local stuckWatch = StuckWatch.new()

	-- Ends a player's hold: the attribute goes, and Carry gives the walking speed back.
	local function release(userId: number)
		local player = holding[userId]
		if player ~= nil then
			holding[userId] = nil
			player:SetAttribute("Held", nil)
		end
	end

	-- On a death, pick the spot first: the new character's arrival clears the list.
	local function watchCharacter(player: any, record: Watched, character: Model)
		record.characterTrove:Clean()
		local connection = diedFn(character, function()
			local root, humanoid = bodyOf(character)
			kept[player.UserId] = if root ~= nil and humanoid ~= nil
				then safeSpots:pick(player.UserId, feetOf(root, humanoid))
				else nil
			release(player.UserId)
		end)
		if connection ~= nil then
			record.characterTrove:Add(connection)
		end
	end

	local function watchPlayer(player: any)
		local userId: number = player.UserId
		if watched[userId] ~= nil then
			return
		end
		local record = newWatched()
		record.trove:Add(record.characterTrove)
		watched[userId] = record
		record.trove:Add(player.CharacterAdded:Connect(function(character: Model)
			safeSpots:forget(userId)
			pressing[userId] = nil
			release(userId)
			stuckWatch:forget(userId)
			watchCharacter(player, record, character)
		end))
		if player.Character ~= nil then
			watchCharacter(player, record, player.Character)
		end
	end

	local function forgetPlayer(player: any)
		local userId: number = player.UserId
		safeSpots:forget(userId)
		kept[userId] = nil
		moves[userId] = nil
		pressing[userId] = nil
		release(userId)
		stuckWatch:forget(userId)
		local record = watched[userId]
		if record ~= nil then
			watched[userId] = nil
			record.trove:Destroy()
		end
	end

	for _, player in deps.players:GetPlayers() do
		watchPlayer(player)
	end
	trove:Add(deps.players.PlayerAdded:Connect(watchPlayer))
	trove:Add(deps.players.PlayerRemoving:Connect(forgetPlayer))

	-- Moves a player back to the newest safe spot at least RescueDistance studs from their feet. A player who is still
	-- pressing is held still there until they let go (Rule 28). Nil when no spot is far enough.
	local function moveBackTo(player: any): CFrame?
		local character: Model? = player.Character
		local root, humanoid = bodyOf(character)
		if character == nil or root == nil or humanoid == nil then
			return nil
		end
		local spot = safeSpots:pick(player.UserId, feetOf(root, humanoid))
		if spot == nil then
			return nil
		end
		local oldPosition = root.Position
		local standing = spot.feet + Vector3.new(0, LIFT + humanoid.HipHeight + root.Size.Y / 2, 0)
		local target = CFrame.lookAt(standing, standing + spot.facing)
		-- Moves the whole character, not only the root: whatever hangs on the character keeps its place.
		character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		deps.tracker:moved(player.UserId) -- first: the jump must not be read as a fall or as walking
		deps.fireRescued(player, oldPosition, target)
		local now = deps.now()
		local recent = RecoveryRules.recent(moves[player.UserId] or {}, now)
		table.insert(recent, now)
		moves[player.UserId] = recent
		if pressing[player.UserId] == true then
			holding[player.UserId] = player
			player:SetAttribute("Held", true)
		end
		return target
	end

	local function moveBack(_self: Recovery, player: any): CFrame?
		return moveBackTo(player)
	end

	-- A player's Reset (Rules 25 to 33): back to a safe spot while the giant sleeps and the move is not a loop, home
	-- otherwise. The egg is never touched here: a move keeps it, and a send home puts it back (Banking).
	local function reset(_self: Recovery, player: any)
		local _, humanoid = bodyOf(player.Character)
		local where = deps.whereIs(player)
		if humanoid == nil or humanoid.Health <= 0 or where == nil then
			return
		end
		local onGiant = RecoveryRules.onGiant(where.zone, where.onPillow)
		local choice = RecoveryRules.resetChoice(onGiant, deps.phase(), moves[player.UserId] or {}, deps.now())
		if choice == "MoveBack" and moveBackTo(player) ~= nil then
			return
		end
		deps.sendHome(player) -- "Home", or no spot far enough (Rule 27)
	end

	local function setPressing(_self: Recovery, player: any, on: boolean)
		pressing[player.UserId] = on
		if not on then
			release(player.UserId)
		end
	end

	-- Moves a stuck player (Rule 28): back to a safe spot, or home when that would be a loop (Rule 29) or no spot is
	-- far enough. A move back keeps the egg.
	local function rescue(player: any, now: number)
		local choice = RecoveryRules.rescueChoice(moves[player.UserId] or {}, now)
		if choice == "MoveBack" and moveBackTo(player) ~= nil then
			return
		end
		deps.sendHome(player)
	end

	-- Each tick: saves the safe spots, then watches every living player who is pressing to move.
	local function step(_self: Recovery)
		local now = deps.now()
		for _, player in deps.players:GetPlayers() do
			local userId: number = player.UserId
			local sample = deps.sampleOf(player, now)
			if sample ~= nil then
				safeSpots:sample(userId, sample)
			end
			local where = deps.whereIs(player)
			local root = bodyOf(player.Character)
			if where == nil or root == nil then
				stuckWatch:forget(userId)
				continue
			end
			local position = root.Position
			local stuck = stuckWatch:update(userId, {
				pressing = pressing[userId] == true,
				position = position,
				onGiant = RecoveryRules.onGiant(where.zone, where.onPillow),
				blocked = deps.falling(player) or deps.floating(userId) or deps.inRedCircle(position),
				held = holding[userId] ~= nil,
			}, now)
			if stuck then
				rescue(player, now)
			end
		end
	end

	local function keptSpot(_self: Recovery, player: any): SafeSpots.Spot?
		return kept[player.UserId]
	end

	local function destroy(_self: Recovery)
		if destroyed then
			return
		end
		destroyed = true
		trove:Destroy()
		for userId in watched do
			local record = watched[userId]
			watched[userId] = nil
			if record ~= nil then
				record.trove:Destroy()
			end
		end
		table.clear(kept)
		table.clear(moves)
		table.clear(pressing)
		for userId in table.clone(holding) do
			release(userId)
		end
	end

	return {
		step = step,
		setPressing = setPressing,
		moveBack = moveBack,
		reset = reset,
		keptSpot = keptSpot,
		destroy = destroy,
	}
end

-- The real reader of a player's place for the safe spots: feet, the way they move, the ground under them and whether
-- a body fits there.
local rayParams: { [Player]: { character: Model, params: RaycastParams } } = setmetatable({}, { __mode = "k" }) :: any
local roomOptions: PathCheck.Options? = nil

local function paramsFor(player: Player, character: Model): RaycastParams
	local entry = rayParams[player]
	if entry == nil or entry.character ~= character then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		entry = { character = character, params = params }
		rayParams[player] = entry
	end
	return entry.params
end

-- The ray down from the root that finds the ground under the feet (the safe spots and the pillow check both use it).
local function groundUnder(player: Player, character: Model, root: BasePart): RaycastResult?
	return Workspace:Raycast(root.Position, Vector3.new(0, -GROUND_RAY, 0), paramsFor(player, character))
end

-- The part under the player's feet, or nil in the air or without a living character.
function Recovery.groundOf(player: Player): Instance?
	local character = player.Character
	local root, humanoid = bodyOf(character)
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local hit = groundUnder(player, character, root)
	return if hit ~= nil then hit.Instance else nil
end

function Recovery.sampleOf(player: Player, now: number, floating: (userId: number) -> boolean): SafeSpots.Sample?
	local character = player.Character
	local root, humanoid = bodyOf(character)
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local velocity = root.AssemblyLinearVelocity
	local hit = groundUnder(player, character, root)
	local normal = if hit ~= nil then hit.Normal else nil
	if roomOptions == nil then
		roomOptions = PathCheck.defaults(Workspace)
	end
	local options = roomOptions :: PathCheck.Options
	return {
		now = now,
		feet = feet,
		facing = Vector3.new(velocity.X, 0, velocity.Z),
		groundNormal = normal,
		state = humanoid:GetState(),
		floating = floating(player.UserId),
		hasRoom = function()
			return (PathCheck.roomToStand(options, feet, normal))
		end,
	}
end

return Recovery
