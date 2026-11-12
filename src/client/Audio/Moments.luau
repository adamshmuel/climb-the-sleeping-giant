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
}
export type Handle = {
	play: (name: string, at: Vector3?) -> (),
	stop: (name: string) -> (),
	destroy: () -> (),
}

function Moments.start(deps: Deps): Handle
	local connections: { RBXScriptConnection } = {}
	local perPlayer: { [Instance]: RBXScriptConnection? } = {} -- each player's Floating listener, gone when they leave
	local alive = true

	local function play(name: string, at: Vector3?)
		local cue = Cues.forName(name)
		if cue == nil or not alive then
			return
		end
		local options = { speed = cue.speed, fade = cue.fade }
		local delay = cue.delay
		if delay ~= nil and delay > 0 then
			deps.after(delay, function()
				if alive then
					deps.board.play(cue.row, at, options)
				end
			end)
		else
			deps.board.play(cue.row, at, options)
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

	return { play = play, stop = stop, destroy = destroy }
end

return Moments
