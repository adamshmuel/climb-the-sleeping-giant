--!strict
-- Moves a player back to where they last stood safely (Rules 27, 31 and 33). It saves each player's safe spots from
-- their sample, keeps the spot picked at the moment of a death (a Reset on the giant uses it), and does the move
-- itself. The move is silent for the Sleep meter: the tracker is told first, so the jump is not read as a fall or as
-- walking noise. Everything it touches comes in through `deps`, so a test can use fake players and a fake clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)
local PathCheck = require(script.Parent.Parent.World.PathCheck)
local SafeSpots = require(script.Parent.SafeSpots)

-- A Roblox event, as far as Recovery uses it. (The connection is typed `any`: Trove only needs to disconnect it.)
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> any,
}

export type PlayersLike = {
	GetPlayers: (self: any) -> { any },
	PlayerAdded: SignalLike,
	PlayerRemoving: SignalLike,
}

export type Deps = {
	players: PlayersLike, -- each player has UserId, Character and CharacterAdded
	safeSpots: SafeSpots.SafeSpots, -- made with StarterPlayer.CharacterMaxSlopeAngle
	tracker: { moved: (self: any, userId: number) -> () },
	sampleOf: (player: any, now: number) -> SafeSpots.Sample?, -- nil without a living character
	fireRescued: (player: any, from: Vector3, to: CFrame) -> (),
	now: () -> number,
	-- Calls `callback` when the character dies, and returns the connection (or nil). The real one wraps Humanoid.Died.
	died: ((character: Model, callback: () -> ()) -> any)?,
}

export type Recovery = {
	step: (self: Recovery) -> (),
	moveBack: (self: Recovery, player: any) -> CFrame?,
	keptSpot: (self: Recovery, player: any) -> SafeSpots.Spot?,
	destroy: (self: Recovery) -> (),
}

local Recovery = {}

-- Lifts the player this far above the spot's ground when placing them, so the feet can't start inside it (Section 5).
local LIFT = 0.5
-- How far below the root the ground ray looks. The body hangs about 3 studs under the root; this leaves some spare.
local GROUND_RAY = 4

local latest: Recovery? = nil

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

	-- On a death, pick the spot first: the new character's arrival clears the list.
	local function watchCharacter(player: any, record: Watched, character: Model)
		record.characterTrove:Clean()
		local connection = diedFn(character, function()
			local root = bodyOf(character)
			kept[player.UserId] = if root ~= nil then safeSpots:pick(player.UserId, root.Position) else nil
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

	local self: Recovery
	local function step(_self: Recovery)
		local now = deps.now()
		for _, player in deps.players:GetPlayers() do
			local sample = deps.sampleOf(player, now)
			if sample ~= nil then
				safeSpots:sample(player.UserId, sample)
			end
		end
	end

	local function moveBack(_self: Recovery, player: any): CFrame?
		local character: Model? = player.Character
		local root, humanoid = bodyOf(character)
		if character == nil or root == nil or humanoid == nil then
			return nil
		end
		local spot = safeSpots:pick(player.UserId, root.Position)
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
		return target
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
		if latest == self then
			latest = nil
		end
	end

	self = { step = step, moveBack = moveBack, keptSpot = keptSpot, destroy = destroy }
	latest = self
	return self
end

-- The last Recovery started, for Play jobs only (nothing in the game reads it).
function Recovery.current(): Recovery?
	return latest
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

function Recovery.sampleOf(player: Player, now: number, floating: (userId: number) -> boolean): SafeSpots.Sample?
	local character = player.Character
	local root, humanoid = bodyOf(character)
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local velocity = root.AssemblyLinearVelocity
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -GROUND_RAY, 0), paramsFor(player, character))
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
