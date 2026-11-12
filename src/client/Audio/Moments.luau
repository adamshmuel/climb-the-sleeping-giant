--!strict
-- Moments (plan 7 Task 9; spec 7 Rule 92 "The wake-up is loud", Rule 86 "8 boings"): plays the named sound places (Cues)
-- on the sound board, holds back the ones with a delay, and plays a boing at a player's root when their Floating turns true.
-- The 8-to-3 cap is the board's own (Config.Audio.MaxCopies). Everything the engine does is passed in.
local Cues = require(script.Parent.Cues)

local Moments = {}

export type Board = {
	play: (rowName: string, at: Vector3?, options: any?) -> any,
	stop: (rowName: string) -> (),
}
export type Deps = {
	board: Board,
	after: (seconds: number, callback: () -> ()) -> (), -- task.delay in the game
	playerList: Instance, -- Players in the game
	rootOf: (player: Instance) -> Vector3?,
	localPlayer: Instance, -- this device's player: their Carrying and their egg home are heard (Rule 95)
}
-- The EggHome remote's signal, as far as this module uses it (same shape as Celebrations').
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}
export type Handle = {
	play: (name: string, at: Vector3?) -> (),
	stop: (name: string) -> (),
	hearEggHome: (eggHome: { OnClientEvent: SignalLike }) -> (),
	hearEggPop: (eggPop: { OnClientEvent: SignalLike }) -> (),
	destroy: () -> (),
}

function Moments.start(deps: Deps): Handle
	local connections: { RBXScriptConnection } = {}
	local perPlayer: { [Instance]: RBXScriptConnection? } = {} -- each player's Floating listener, gone when they leave
	local alive = true
	local carrying = deps.localPlayer:GetAttribute("Carrying") ~= nil -- an egg already carried at start is not a grab

	local function play(name: string, at: Vector3?)
		local cue = Cues.forName(name)
		if cue == nil or not alive then
			return
		end
		local options = { speed = cue.speed, fade = cue.fade }
		local function playRows()
			deps.board.play(cue.row, at, options)
			if cue.also ~= nil then
				for _, row in cue.also do
					deps.board.play(row, at, nil)
				end
			end
		end
		local delay = cue.delay
		if delay ~= nil and delay > 0 then
			deps.after(delay, function()
				if alive then
					playRows()
				end
			end)
		else
			playRows()
		end
	end

	local function stop(name: string)
		local cue = Cues.forName(name)
		if cue ~= nil then
			deps.board.stop(cue.row)
		end
	end

	-- A player already here is heard too, but a Floating already true at start plays nothing: only a change to true does.
	-- A player who joins is heard from their start: a ChildAdded reaches us a moment late (deferred events), so a Floating
	-- that turned true in between counts as a change to true.
	local function boing(player: Instance)
		if player:GetAttribute("Floating") ~= true then
			return
		end
		local at = deps.rootOf(player)
		if at ~= nil then
			play("Boing", at)
		end
	end
	local function listen(player: Instance)
		if perPlayer[player] ~= nil then
			return
		end
		perPlayer[player] = player:GetAttributeChangedSignal("Floating"):Connect(function()
			boing(player)
		end)
	end
	for _, player in deps.playerList:GetChildren() do
		listen(player)
	end
	table.insert(
		connections,
		deps.playerList.ChildAdded:Connect(function(player: Instance)
			listen(player)
			boing(player)
		end)
	)
	table.insert(
		connections,
		deps.playerList.ChildRemoved:Connect(function(player: Instance)
			local connection = perPlayer[player]
			if connection ~= nil then
				connection:Disconnect()
				perPlayer[player] = nil
			end
		end)
	)

	-- Plan 7 Task 11 (Rule 95): the grab. Only a change from nothing to an egg plays, so an egg already carried at start is silent.
	table.insert(
		connections,
		deps.localPlayer:GetAttributeChangedSignal("Carrying"):Connect(function()
			if deps.localPlayer:GetAttribute("Carrying") ~= nil and not carrying then
				local name = Cues.grabName(deps.localPlayer:GetAttribute("Carrying"))
				if name ~= nil then
					play(name, nil)
				end
			end
			carrying = deps.localPlayer:GetAttribute("Carrying") ~= nil
		end)
	)

	-- The egg home: the remote fires (player, rarity, position); only this device's own player is heard.
	local function hearEggHome(eggHome: { OnClientEvent: SignalLike })
		table.insert(
			connections,
			eggHome.OnClientEvent:Connect(function(player: any, rank: any)
				if player ~= deps.localPlayer then
					return
				end
				local name = Cues.homeName(rank)
				if name ~= nil then
					play(name, nil)
				end
			end)
		)
	end

	-- An egg pops at a nest: the remote fires (position, kind). A new egg sparkles; a lost one pops. Anything else is
	-- ignored.
	local function hearEggPop(eggPop: { OnClientEvent: SignalLike })
		table.insert(
			connections,
			eggPop.OnClientEvent:Connect(function(position: any, kind: any)
				if typeof(position) ~= "Vector3" then
					return
				end
				if kind == "Refill" then
					play("SparklePop", position)
				elseif kind == "Back" or kind == "Gone" then
					play("EggPop", position)
				end
			end)
		)
	end

	local function destroy()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, connection in perPlayer do
			if connection ~= nil then
				connection:Disconnect()
			end
		end
		table.clear(perPlayer)
	end

	return { play = play, stop = stop, hearEggHome = hearEggHome, hearEggPop = hearEggPop, destroy = destroy }
end

return Moments
