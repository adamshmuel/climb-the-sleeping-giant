--!strict
-- The bonk: when the giant's slam hits a player, they tumble and are held still for a moment, and nothing else
-- happens (spec 6, Rule 61). Bonker only marks the player with the attribute "Bonked" ("Ground", or "Ladder" for a
-- climber) for the length of the tumble. Carry.watchSpeed reads that attribute and holds the walk and the jump at 0.
-- The caller says whether the player is on a ladder (plan 3 Task 3 works that out). Bonker never moves a character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type PlayerLike = {
	UserId: number,
	GetAttribute: (self: any, name: string) -> any,
	SetAttribute: (self: any, name: string, value: any) -> (),
	CharacterAdded: { Connect: (self: any, callback: (any) -> ()) -> ConnectionLike },
}

export type PlayersLike = {
	PlayerRemoving: { Connect: (self: any, callback: (any) -> ()) -> ConnectionLike },
}

export type Deps = {
	players: PlayersLike,
	-- Runs `callback` after `seconds` and returns a function that cancels it.
	delay: (seconds: number, callback: () -> ()) -> () -> (),
}

export type Bonker = {
	-- Starts a bonk unless the player is already bonked. Fires `bonked` only for a bonk that started.
	bonk: (self: Bonker, player: PlayerLike, onLadder: boolean) -> (),
	-- Fires with the player right after a bonk starts. Analytics listens to it.
	bonked: Signal.Signal<PlayerLike>,
	-- Cancels every timer, clears every mark and disconnects everything. Safe to call twice.
	destroy: (self: Bonker) -> (),
}

local Bonker = {}

function Bonker.new(deps: Deps): Bonker
	local bonked = Signal.new() :: Signal.Signal<PlayerLike>
	-- One Trove per bonked player holds the timer's cancel and the new-character connection.
	local troves: { [number]: typeof(Trove.new()) } = {}
	local bonkedPlayers: { [number]: PlayerLike } = {}

	-- Clears the mark, cancels the timer and destroys the player's Trove.
	local function endBonk(player: PlayerLike)
		local userId = player.UserId
		local trove = troves[userId]
		troves[userId] = nil
		bonkedPlayers[userId] = nil
		player:SetAttribute("Bonked", nil)
		if trove ~= nil then
			trove:Destroy()
		end
	end

	local removingConnection = deps.players.PlayerRemoving:Connect(function(player: PlayerLike)
		if troves[player.UserId] ~= nil then
			endBonk(player)
		end
	end)

	local self = {} :: Bonker
	self.bonked = bonked

	function self.bonk(_self: Bonker, player: PlayerLike, onLadder: boolean)
		local userId = player.UserId
		if troves[userId] ~= nil or player:GetAttribute("Bonked") ~= nil then
			return -- already bonked: nothing to gain
		end
		local trove = Trove.new()
		troves[userId] = trove
		bonkedPlayers[userId] = player
		player:SetAttribute("Bonked", if onLadder then "Ladder" else "Ground")

		local finished = false
		local cancel = deps.delay(
			Config.Wake.TumbleDownSeconds + Config.Wake.TumbleStillSeconds + Config.Wake.TumbleUpSeconds,
			function()
				finished = true
				endBonk(player)
			end
		)
		trove:Add(function()
			if not finished then
				cancel()
			end
		end)
		trove:Add(player.CharacterAdded:Connect(function()
			endBonk(player)
		end))
		bonked:Fire(player)
	end

	function self.destroy(_self: Bonker)
		removingConnection:Disconnect()
		for _, player in table.clone(bonkedPlayers) do
			endBonk(player)
		end
		bonked:Destroy()
	end

	return self
end

return Bonker
