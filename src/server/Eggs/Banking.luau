--!strict
-- Bringing eggs home, and sending them back when the carrier can't. Every tick, a carrier whose real position is
-- inside their OWN garden banks the egg (it leaves their back for the garden, and their EggsHome goes up by one).
-- A carrier who dies, loses their character or leaves sends the egg back to its spot instead.
-- Nothing here reads anything a client sends: positions come from PlayerTracker, and the rest are attributes and
-- events the server owns. Everything it touches is passed in, so a test can give it fake players and a fake Grab.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Grab = require(script.Parent.Grab)
local PlayerInfo = require(script.Parent.Parent.Players.PlayerInfo)
local PlayerTracker = require(script.Parent.Parent.Players.PlayerTracker)

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (any) -> ()) -> ConnectionLike,
}

-- What Banking needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Character: Model?,
	CharacterAdded: SignalLike,
	CharacterRemoving: SignalLike,
	GetAttribute: (self: any, name: string) -> any,
	SetAttribute: (self: any, name: string, value: any) -> (),
}

export type PlayersLike = {
	PlayerAdded: SignalLike,
	PlayerRemoving: SignalLike,
	GetPlayers: (self: any) -> { PlayerLike },
	GetPlayerByUserId: (self: any, userId: number) -> PlayerLike?,
}

-- The two things Banking asks of Grab (the handle that Grab.start returns).
export type GrabLike = {
	bank: (self: any, player: Grab.PlayerLike) -> (string?, Config.RarityName?),
	returnEgg: (self: any, player: Grab.PlayerLike) -> (("back" | "gone")?, string?),
}

export type Deps = {
	grab: GrabLike,
	players: PlayersLike,
}

export type Banking = {
	-- One tick: banks every carrier in the samples who stands in their own garden.
	check: (self: Banking, samples: { PlayerTracker.Sample }) -> (),
	-- Fires after an egg is banked, with the player and the egg's rarity. HomeDisplay and Analytics listen to it.
	banked: Signal.Signal<PlayerLike, Config.RarityName>,
	-- Removes every connection. Safe to call twice.
	stop: (self: Banking) -> (),
}

-- How long to wait for a new character's Humanoid to show up.
local HUMANOID_WAIT_SECONDS = 10

local Banking = {}

-- Does this player bank their egg? Only when they carry something and the garden they stand in is their own
-- (`garden` is nil in the meadow, `plotIndex` is nil for a player with no garden).
function Banking.shouldBank(carrying: string?, garden: number?, plotIndex: number?): boolean
	return carrying ~= nil and garden ~= nil and plotIndex ~= nil and garden == plotIndex
end

-- A player's PlotIndex attribute as a number, or nil if it isn't one.
local function plotIndexFrom(value: any): number?
	if type(value) == "number" then
		return value
	end
	return nil
end

function Banking.start(deps: Deps): Banking
	local grab = deps.grab
	local players = deps.players
	local trove = Trove.new()
	local stopped = false
	local banked = Signal.new() :: Signal.Signal<PlayerLike, Config.RarityName>
	trove:Add(function()
		banked:Destroy()
	end)

	local function sendBack(player: PlayerLike)
		grab:returnEgg(player)
	end

	-- One cleanup per watched player, which removes every connection made for them.
	local cleanups: { [number]: () -> () } = {}

	local function watchPlayer(player: PlayerLike)
		local userId = player.UserId
		if cleanups[userId] ~= nil then
			return -- already watched
		end
		local playerTrove = Trove.new()
		-- The connection and the waiting task of the current character's Humanoid.
		local healthConnection: RBXScriptConnection? = nil
		local waitingForHumanoid: thread? = nil
		local function stopWatchingCharacter()
			if healthConnection ~= nil then
				healthConnection:Disconnect()
				healthConnection = nil
			end
			if waitingForHumanoid ~= nil then
				task.cancel(waitingForHumanoid)
				waitingForHumanoid = nil
			end
		end
		playerTrove:Add(stopWatchingCharacter)
		cleanups[userId] = function()
			playerTrove:Destroy()
		end

		-- A Humanoid at 0 health is dead: a reset, damage, or falling out of the world.
		local function watchHumanoid(humanoid: Humanoid)
			healthConnection = humanoid.HealthChanged:Connect(function(health)
				if health <= 0 then
					sendBack(player)
				end
			end)
		end

		local function watchCharacter(character: Model?)
			stopWatchingCharacter()
			if character == nil then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				watchHumanoid(humanoid)
				return
			end
			waitingForHumanoid = task.spawn(function()
				local arrived = character:WaitForChild("Humanoid", HUMANOID_WAIT_SECONDS)
				waitingForHumanoid = nil
				if arrived ~= nil and arrived:IsA("Humanoid") then
					watchHumanoid(arrived)
				end
			end)
		end

		playerTrove:Add(player.CharacterAdded:Connect(watchCharacter))
		playerTrove:Add(player.CharacterRemoving:Connect(function()
			stopWatchingCharacter()
			sendBack(player)
		end))
		watchCharacter(player.Character)
	end

	local function onPlayerRemoving(player: PlayerLike)
		sendBack(player)
		local cleanup = cleanups[player.UserId]
		if cleanup ~= nil then
			cleanups[player.UserId] = nil
			cleanup()
		end
	end

	trove:Add(players.PlayerAdded:Connect(watchPlayer))
	trove:Add(players.PlayerRemoving:Connect(onPlayerRemoving))
	trove:Add(function()
		for userId, cleanup in cleanups do
			cleanups[userId] = nil
			cleanup()
		end
	end)
	for _, player in players:GetPlayers() do
		watchPlayer(player)
	end

	local function check(_self: Banking, samples: { PlayerTracker.Sample })
		if stopped then
			return
		end
		for _, sample in samples do
			local player = players:GetPlayerByUserId(sample.userId)
			if player ~= nil then
				local info = PlayerInfo.fromPlayer(player)
				local plotIndex = plotIndexFrom(player:GetAttribute("PlotIndex"))
				if Banking.shouldBank(info.carrying, sample.garden, plotIndex) then
					local _spotName: string?, rarity: Config.RarityName? = grab:bank(player)
					if rarity ~= nil then
						player:SetAttribute("EggsHome", info.eggsHome + 1)
						banked:Fire(player, rarity)
					end
				end
			end
		end
	end

	local function stop(_self: Banking)
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end

	return { check = check, banked = banked, stop = stop }
end

return Banking
