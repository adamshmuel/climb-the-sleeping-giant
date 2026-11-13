--!strict
-- Starts the real GiantDirector, Catcher and Bonker for a whole-session test of the hunt (Rules 60, 62 and 63), with
-- the same stand-ins GiantRig uses for what a test can't drive (landing spots, a slam ring that sinks 3 studs, no
-- bounce), but with the show spots, the Safe Gates and the garden boxes the test gives it, and the real Bonker.
-- The Bonker's timer is a stand-in driven by the test's clock: call `runDue` after each step. Also does the wiring
-- init.server.luau does: a fist tells Grab, a bonk marks the player. Call `stop` when the test is over.
local ServerScriptService = game:GetService("ServerScriptService")

local Bonker = require(ServerScriptService.Server.Giant.Bonker)
local Catcher = require(ServerScriptService.Server.Giant.Catcher)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local PlayerInfo = require(ServerScriptService.Server.Players.PlayerInfo)

local FACE = Vector3.new(0, 95, 0)

local HuntRig = {}

export type Options = {
	list: () -> { any }, -- every fake player in the server (attributes read by PlayerInfo)
	service: any, -- the fake Players service (GetPlayerByUserId, PlayerRemoving), for the Catcher and the Bonker
	tick: () -> { any }, -- one tick: where every player is (the test also banks and logs analytics here)
	now: () -> number, -- the test's clock
	grab: any, -- the real Grab: gets noteFist on every fist, and gives the egg back on a catch
	plot: number, -- the garden the Catcher sends a caught player to
	home: Vector3, -- where a catch puts the player (that garden's spawn spot)
	gardens: { any }, -- the garden boxes (index, cframe, size) a circle never touches
	showSpots: { Vector3 }, -- the meadow spots a show slam may use
	gates: { [number]: Vector3 }, -- the Safe Gate of each player's own garden, by user id
	pick: ((count: number) -> number)?, -- the random pick (default: always the first)
	joinedAt: ((userId: number) -> number?)?, -- when a player joined, in the `now` clock (default: not known)
	appearedAt: ((userId: number) -> number?)?, -- when a catch last put a player at the door (default: not known)
	onCaught: ((rank: string) -> ())?,
	onWarning: ((slam: number, centre: Vector3) -> ())?, -- a circle starts: its number and its centre
}

export type Rig = {
	state: Folder,
	director: any,
	catcher: any,
	bonker: any,
	bounced: { number }, -- the user ids the wake-up bounce moved (nobody should be pushed otherwise)
	runDue: () -> (), -- runs every Bonker timer that has come due on the test's clock
	stop: () -> (),
}

type Timer = { due: number, callback: () -> (), cancelled: boolean }

local function constant(value: any): () -> any
	return function()
		return value
	end
end

function HuntRig.start(options: Options): Rig
	local state = Instance.new("Folder")
	state:SetAttribute("Meter", 0)
	state:SetAttribute("Phase", "Asleep")
	local spawn = Instance.new("Part")
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(options.home.X, 0, options.home.Z)
	local players = function()
		local infos = {}
		for _, player in options.list() do
			table.insert(infos, PlayerInfo.fromPlayer(player))
		end
		return infos
	end
	local timers: { Timer } = {}
	local bonker = Bonker.new({
		players = options.service,
		delay = function(seconds: number, callback: () -> ()): () -> ()
			local timer: Timer = { due = options.now() + seconds, callback = callback, cancelled = false }
			table.insert(timers, timer)
			return function()
				timer.cancelled = true
			end
		end,
	})
	local catcher = Catcher.new({
		players = options.service,
		grab = options.grab,
		gardens = { { index = options.plot, spawnSpot = spawn } } :: any,
		facePoint = FACE,
		fireCaught = function() end,
	})
	local onCaught = options.onCaught
	if onCaught ~= nil then
		catcher.caught:Connect(function(_who: any, rank: string)
			onCaught(rank)
		end)
	end
	local bounced: { number } = {}
	local onWarning = options.onWarning
	local director = GiantDirector.new({
		tick = options.tick,
		players = players,
		state = state,
		fireWarning = function() end,
		now = options.now,
		landingSpots = { { index = 1, position = Vector3.new(-50, 2, 0) } } :: any,
		bounce = function(userId: number)
			table.insert(bounced, userId)
		end,
		gardens = options.gardens,
		meadowPoints = { Vector3.new(0, 2, 100), Vector3.new(0, 2, -100) },
		face = FACE,
		floating = constant(false),
		landedAgo = constant(nil),
		pick = options.pick or constant(1),
		surfaceBelow = function(centre: Vector3): Vector3
			return centre - Vector3.new(0, 3, 0)
		end,
		fireSlamWarning = function(slam: number, _point: Vector3, _landsAt: number, centre: Vector3)
			if onWarning ~= nil then
				onWarning(slam, centre)
			end
		end,
		fireSlamLanded = function() end,
		catch = function(userId: number)
			catcher:catch(userId)
		end,
		joinedAt = options.joinedAt or constant(nil),
		appearedAt = options.appearedAt or constant(nil),
		showSpots = options.showSpots,
		gates = options.gates,
		bonk = function(userId: number, onLadder: boolean)
			local player = options.service:GetPlayerByUserId(userId)
			if player ~= nil then
				bonker:bonk(player, onLadder)
			end
		end,
		onLadder = constant(false),
		spendSave = function() end,
	})
	director.slammed:Connect(function()
		options.grab:noteFist()
	end)
	return {
		state = state,
		director = director,
		catcher = catcher,
		bonker = bonker,
		bounced = bounced,
		runDue = function()
			local now = options.now()
			for index = #timers, 1, -1 do
				local timer = timers[index]
				if timer.cancelled then
					table.remove(timers, index)
				elseif timer.due <= now then
					table.remove(timers, index)
					timer.callback()
				end
			end
		end,
		stop = function()
			director:destroy()
			catcher:stop()
			bonker:destroy()
			state:Destroy()
			spawn:Destroy()
		end,
	}
end

return HuntRig
