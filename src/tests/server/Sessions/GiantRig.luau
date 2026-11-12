--!strict
-- Starts the real GiantDirector and Catcher for a whole-session test, with the same stand-ins StuckSession uses
-- for the parts of the world a test can't drive (landing spots, a slam ring that sinks 3 studs, no bounce, no
-- gates). Also does the wiring init.server.luau does: a fist tells Grab. Call `stop` when the test is over.
local ServerScriptService = game:GetService("ServerScriptService")

local Catcher = require(ServerScriptService.Server.Giant.Catcher)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local PlayerInfo = require(ServerScriptService.Server.Players.PlayerInfo)

local FACE = Vector3.new(0, 95, 0)

local GiantRig = {}

export type Options = {
	player: Instance, -- the fake player (attributes read by PlayerInfo)
	service: any, -- the fake Players service (GetPlayerByUserId), for the Catcher
	sample: () -> any, -- the tracker stand-in's sample for this tick
	now: () -> number, -- the test's clock
	grab: any, -- the real Grab: gets noteFist on every fist, and gives the egg back on a catch
	plot: number, -- the player's garden
	home: Vector3, -- where a catch puts the player (the garden's spawn spot)
	onCaught: (rank: string) -> (),
	onFist: () -> (),
}

export type Rig = {
	state: Folder,
	director: any,
	catcher: any,
	stop: () -> (),
}

local function constant(value: any): () -> any
	return function()
		return value
	end
end

function GiantRig.start(options: Options): Rig
	local state = Instance.new("Folder")
	state:SetAttribute("Meter", 0)
	state:SetAttribute("Phase", "Asleep")
	local spawn = Instance.new("Part")
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(options.home.X, 0, options.home.Z)
	local players = function()
		return { PlayerInfo.fromPlayer(options.player :: any) }
	end
	local catcher = Catcher.new({
		players = options.service,
		grab = options.grab,
		gardens = { { index = options.plot, spawnSpot = spawn } } :: any,
		facePoint = FACE,
		fireCaught = function() end,
	})
	catcher.caught:Connect(function(_who: any, rank: string)
		options.onCaught(rank)
	end)
	local director = GiantDirector.new({
		tick = function()
			return { options.sample() }
		end,
		players = players,
		state = state,
		fireWarning = function() end,
		now = options.now,
		landingSpots = { { index = 1, position = Vector3.new(-50, 2, 0) } } :: any,
		bounce = function() end,
		gardens = {},
		meadowPoints = { Vector3.new(0, 2, 100), Vector3.new(0, 2, -100) },
		face = FACE,
		floating = constant(false),
		landedAgo = constant(nil),
		pick = constant(1),
		surfaceBelow = function(centre: Vector3): Vector3
			return centre - Vector3.new(0, 3, 0)
		end,
		fireSlamWarning = function() end,
		fireSlamLanded = function() end,
		catch = function(userId: number)
			catcher:catch(userId)
		end,
		joinedAt = constant(nil),
		appearedAt = constant(nil),
		showSpots = {},
		gates = {},
		bonk = function() end,
		onLadder = constant(false),
		spendSave = function(_userId: number)
			options.player:SetAttribute("FreeSaveUsed", true)
		end,
	})
	director.slammed:Connect(function()
		options.grab:noteFist()
		options.onFist()
	end)
	return {
		state = state,
		director = director,
		catcher = catcher,
		stop = function()
			director:destroy()
			catcher:stop()
			state:Destroy()
			spawn:Destroy()
		end,
	}
end

return GiantRig
