--!strict
-- Players walk through each other. Every character part goes in one collision group that does not
-- collide with itself, so nobody can block a ramp or a ladder. Only server Scripts can change groups.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

-- What this module needs from PhysicsService, so tests can pass a stand-in.
export type PhysicsLike = {
	IsCollisionGroupRegistered: (self: any, name: string) -> boolean,
	RegisterCollisionGroup: (self: any, name: string) -> (),
	CollisionGroupSetCollidable: (self: any, first: string, second: string, collidable: boolean) -> (),
}

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type PlayerLike = {
	Character: Model?,
	CharacterAdded: { Connect: (self: any, callback: (Model) -> ()) -> ConnectionLike },
}

export type PlayersLike = {
	PlayerAdded: { Connect: (self: any, callback: (PlayerLike) -> ()) -> ConnectionLike },
	PlayerRemoving: { Connect: (self: any, callback: (PlayerLike) -> ()) -> ConnectionLike },
	GetPlayers: (self: any) -> { PlayerLike },
}

local Collisions = {}

Collisions.GROUP = "Players"

-- Registers the group (only if it is not there yet) and makes it not collide with itself.
function Collisions.setupGroup(physics: PhysicsLike)
	if not physics:IsCollisionGroupRegistered(Collisions.GROUP) then
		physics:RegisterCollisionGroup(Collisions.GROUP)
	end
	physics:CollisionGroupSetCollidable(Collisions.GROUP, Collisions.GROUP, false)
end

local function putInGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = Collisions.GROUP
	end
end

-- Puts a character in the Players group now, and every part added to it later (accessories, tools).
-- Returns a function that stops watching it.
function Collisions.addCharacter(character: Model): () -> ()
	local trove = Trove.new()
	for _, descendant in character:GetDescendants() do
		putInGroup(descendant)
	end
	trove:Connect(character.DescendantAdded, putInGroup)
	return function()
		trove:Destroy()
	end
end

-- Sets up the group, then puts every player's character in it: the ones who are here now, the ones
-- who join, and every new character after a respawn. Returns a function that stops it all.
function Collisions.start(players: PlayersLike, physics: PhysicsLike): () -> ()
	Collisions.setupGroup(physics)
	local stopWatching: { [PlayerLike]: () -> () } = {}

	local function watchPlayer(player: PlayerLike)
		if stopWatching[player] then
			return
		end
		local stopCharacter: (() -> ())? = nil
		local function watchCharacter(character: Model)
			if stopCharacter then
				stopCharacter() -- the old character is replaced
			end
			stopCharacter = Collisions.addCharacter(character)
		end
		local connection = player.CharacterAdded:Connect(watchCharacter)
		if player.Character then
			watchCharacter(player.Character)
		end
		stopWatching[player] = function()
			connection:Disconnect()
			if stopCharacter then
				stopCharacter()
				stopCharacter = nil
			end
		end
	end

	local function unwatchPlayer(player: PlayerLike)
		local stop = stopWatching[player]
		if stop then
			stopWatching[player] = nil
			stop()
		end
	end

	local addedConnection = players.PlayerAdded:Connect(watchPlayer)
	local removingConnection = players.PlayerRemoving:Connect(unwatchPlayer)
	for _, player in players:GetPlayers() do
		watchPlayer(player)
	end

	return function()
		addedConnection:Disconnect()
		removingConnection:Disconnect()
		for player in table.clone(stopWatching) do
			unwatchPlayer(player)
		end
	end
end

return Collisions
