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
	play: (name: string, at: Vector3?, thud: number?) -> (),
	stop: (name: string) -> (),
	hearEggHome: (eggHome: { OnClientEvent: SignalLike }) -> (),
	hearEggPop: (eggPop: { OnClientEvent: SignalLike }) -> (),
	hearThud: (thud: { OnClientEvent: SignalLike }) -> (),
	hearRescued: (rescued: { OnClientEvent: SignalLike }) -> (),
	destroy: () -> (),
}

function Moments.start(deps: Deps): Handle
	local connections: { RBXScriptConnection } = {}
	local perPlayer: { [Instance]: RBXScriptConnection? } = {} -- each player's Floating listener, gone when they leave
	local alive = true
	local carrying = deps.localPlayer:GetAttribute("Carrying") ~= nil -- an egg already carried at start is not a grab

	local function play(name: string, at: Vector3?, thud: number?)
		local cue = Cues.forName(name)
		if cue == nil or not alive then
			return
		end
		local options = { speed = cue.speed, fade = cue.fade, thud = thud }
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

	-- A body lands somewhere: the remote fires (position, noise). The flump plays there, and the board gets the noise to pick
	-- its loudness (Rule 96). A bad position, or a noise that is not a finite number above 0, plays nothing.
	local function hearThud(thud: { OnClientEvent: SignalLike })
		table.insert(
			connections,
			thud.OnClientEvent:Connect(function(position: any, noise: any)
				if typeof(position) ~= "Vector3" then
					return
				end
				if typeof(noise) ~= "number" or noise ~= noise or noise <= 0 or noise == math.huge then
					return
				end
				play("Thud", position, noise)
			end)
		)
	end

	-- A rescue happens: the remote fires (player, from, to). One poof plays where he left and one where he lands, at once
	-- (Rule 97). Every player's rescue is heard, so the player is never read. A bad `from` or `to` plays nothing.
	local function hearRescued(rescued: { OnClientEvent: SignalLike })
		table.insert(
			connections,
			rescued.OnClientEvent:Connect(function(_player: any, from: any, to: any)
				if typeof(from) ~= "Vector3" or typeof(to) ~= "CFrame" then
					return
				end
				play("RescuePoof", from)
				play("RescuePoof", to.Position)
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

	return {
		play = play,
		stop = stop,
		hearEggHome = hearEggHome,
		hearEggPop = hearEggPop,
		hearThud = hearThud,
		hearRescued = hearRescued,
		destroy = destroy,
	}
end

return Moments
