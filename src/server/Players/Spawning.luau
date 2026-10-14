--!strict
-- Gives every player their own garden: their spawn spot, their number and their name on the gate sign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local PlotAssigner = require(script.Parent.PlotAssigner)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)

local FULL_MESSAGE = "This valley is full. Please join another server."

-- What Spawning needs from a player and from the Players service. The real ones fit these shapes,
-- and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	DisplayName: string,
	Character: Model?,
	RespawnLocation: SpawnLocation?,
	SetAttribute: (self: any, name: string, value: any) -> (),
	LoadCharacter: (self: any) -> (),
	Kick: (self: any, message: string?) -> (),
}

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (PlayerLike) -> ()) -> ConnectionLike,
}

export type PlayersLike = {
	PlayerAdded: SignalLike,
	PlayerRemoving: SignalLike,
	GetPlayers: (self: any) -> { PlayerLike },
}

local Spawning = {}

function Spawning.signText(displayName: string): string
	return `{displayName}'s Garden`
end

local function writeSigns(garden: WorldIndex.Garden, text: string)
	for _, label in garden.signLabels do
		label.Text = text
	end
end

-- Starts giving gardens to players, now and whenever one joins or leaves.
-- Returns a function that stops it and cleans everything up.
function Spawning.start(gardens: { WorldIndex.Garden }, players: PlayersLike): () -> ()
	local assigner = PlotAssigner.new(#gardens)
	local gardenByIndex: { [number]: WorldIndex.Garden } = {}
	for _, garden in gardens do
		gardenByIndex[garden.index] = garden
		writeSigns(garden, "") -- an empty garden has a blank sign
	end
	-- One Trove per player holds what must be undone when they leave. Each entry here destroys one Trove.
	local cleanups: { [number]: () -> () } = {}

	local function onPlayerAdded(player: PlayerLike)
		local userId = player.UserId
		if cleanups[userId] then
			return -- already handled
		end
		local plotIndex = assigner:assign(userId)
		if plotIndex == nil then
			player:Kick(FULL_MESSAGE)
			return
		end
		local garden = gardenByIndex[plotIndex]
		local trove = Trove.new()
		cleanups[userId] = function()
			trove:Destroy()
		end
		trove:Add(function()
			writeSigns(garden, "")
			assigner:release(userId)
		end)

		player:SetAttribute("PlotIndex", plotIndex)
		player.RespawnLocation = garden.spawnSpot
		writeSigns(garden, Spawning.signText(player.DisplayName))
		if player.Character ~= nil then
			-- They already spawned somewhere else, so spawn them again on their own spot.
			player:LoadCharacter()
		end
	end

	local function onPlayerRemoving(player: PlayerLike)
		local cleanup = cleanups[player.UserId]
		if cleanup then
			cleanups[player.UserId] = nil
			cleanup()
		end
	end

	local addedConnection = players.PlayerAdded:Connect(onPlayerAdded)
	local removingConnection = players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in players:GetPlayers() do
		onPlayerAdded(player)
	end

	return function()
		addedConnection:Disconnect()
		removingConnection:Disconnect()
		for userId, cleanup in cleanups do
			cleanups[userId] = nil
			cleanup()
		end
	end
end

return Spawning
