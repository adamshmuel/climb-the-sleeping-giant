--!strict
-- Plan 3 Task 17: one whole session of a brand-new solo player's three heists in a row, through two different ways up
-- (spec 3, Rules 34 and 35 and section 10; .claude/rules/tdd.md, "Whole-session tests"). The pieces that are real: the
-- PlotAssigner (the garden), PlayerInfo, Banking, Noise, SleepMeter, the GiantDirector and Analytics (with WayUpWatch).
-- The stand-ins: the tracker (the test says where the player stands each tick), the grab (the egg is put on the
-- player's back), the Players service and the AnalyticsService (Analytics/Helpers).
-- Wired like `init.server.luau`: each tick banks first, then Analytics and the director read the player.
-- The steps of a heist are the real footprint route of the built world, from the way up's foot to Rare egg 1 (the same
-- steps WaysUpFairness scores), with the walk from the garden to the foot added (Config.WaysUp WalkLimitSeconds) and
-- the way home a drop (HeistScore.dropDown). The tracker walks each step at the speed HeistScore uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Banking = require(ServerScriptService.Server.Eggs.Banking)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local SleepMeter = require(ServerScriptService.Server.Giant.SleepMeter)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local PlayerInfo = require(ServerScriptService.Server.Players.PlayerInfo)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local PlotAssigner = require(ServerScriptService.Server.Players.PlotAssigner)
local HeistScore = require(ServerScriptService.Server.World.HeistScore)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
local Helpers = require(script.Parent.Parent.Analytics.Helpers)
local FootprintSteps = require(script.Parent.Parent.World.StuckScan.FootprintSteps)
local RealReach = require(script.Parent.Parent.World.StuckScan.RealReach)
local WaysUpRoutes = require(script.Parent.Parent.World.StuckScan.WaysUpRoutes)

type Sample = PlayerTracker.Sample
type Step = HeistScore.Step

local USER_ID = 7
local START_CLOCK = 1000
local TICK = Config.Tick.Seconds
local WALK_SPEED = Config.Movement.WalkSpeed
local CLIMB_SPEED = Config.Movement.ClimbSpeedFactor
local RARE: Config.RarityName = "Rare"
local COMMON: Config.RarityName = "Common"
local FIELD_ONE, FIELD_TWO, FIELD_THREE = Helpers.FIELD_ONE, Helpers.FIELD_TWO, Helpers.FIELD_THREE
-- One entry of Helpers.WAY_UP_TOPS stands for each of these Config.WaysUp entries, by index (1 the ladder, 2 the ramp).
-- Helpers calls them BootLadder_Left and BootRamp; Config calls them "Left boot ladder" and "Left ramp".
local LADDER_WAY, RAMP_WAY = 1, 2

local cleanups: { () -> () } = {}

afterEach(function()
	for _, cleanup in cleanups do
		cleanup()
	end
	table.clear(cleanups)
	Helpers.cleanUp()
end)

type Session = {
	player: Helpers.FakePlayer,
	harness: Helpers.Harness,
	state: Folder,
	director: GiantDirector.Director,
	samples: { Sample },
	clock: number,
	owed: number, -- seconds walked that have not made a whole tick yet
	peak: number, -- the highest meter seen in the whole session
	wakes: number,
	ladderOff: boolean, -- check (e): the same climb with no step counted as on a ladder
}

local function newSession(plot: number): Session
	local harness = Helpers.newHarness()
	local player = Helpers.makePlayer(USER_ID, plot)
	-- Banking and PlayerInfo write attributes; Helpers' player only reads them.
	local loose = player :: any
	loose.SetAttribute = function(self: any, name: string, value: any)
		self.attributes[name] = value
	end
	loose.CharacterRemoving = Signal.new() -- Banking watches it
	Helpers.enter(harness, player)
	local body = Instance.new("Model") -- Banking reads the character's Humanoid
	Instance.new("Humanoid").Parent = body
	loose.Character = body
	table.insert(cleanups, function()
		body:Destroy()
	end)
	local players = {
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
		GetPlayers = function(_self: any): { any }
			return { player }
		end,
		GetPlayerByUserId = function(_self: any, userId: number): any
			return if userId == USER_ID then player else nil
		end,
	}
	local grab = {
		bank = function(_self: any, who: any): (string?, Config.RarityName?)
			local rarity = who:GetAttribute("Carrying")
			if rarity == nil then
				return nil, nil
			end
			who:SetAttribute("Carrying", nil)
			return "Spot_1", rarity
		end,
		returnEgg = function(): (("back" | "gone")?, string?)
			return nil, nil
		end,
	}
	local banking = Banking.start({ grab = grab, players = players :: any })
	banking.banked:Connect(function(who: any, rarity: Config.RarityName)
		harness.banked:Fire(who, rarity)
	end)
	local state = Instance.new("Folder")
	state:SetAttribute("Meter", 0)
	state:SetAttribute("Phase", "Asleep")
	local session: Session = {
		player = player,
		harness = harness,
		state = state,
		director = nil :: any,
		samples = {},
		clock = START_CLOCK,
		owed = 0,
		peak = 0,
		wakes = 0,
		ladderOff = false,
	}
	session.director = GiantDirector.new({
		tick = function()
			banking:check(session.samples)
			harness.analytics:check(session.samples)
			return session.samples
		end,
		players = function()
			return { PlayerInfo.fromPlayer(player :: any) }
		end,
		state = state,
		fireWarning = function() end,
		now = function()
			return session.clock
		end,
		landingSpots = { { index = 1, position = Vector3.new(-50, 2, 0) } },
		bounce = function() end,
		gardens = {},
		meadowPoints = { Vector3.new(0, 2, 100), Vector3.new(0, 2, -100) },
		face = Vector3.new(0, 95, 0),
		floating = function()
			return false
		end,
		landedAgo = function()
			return nil
		end,
		pick = function()
			return 1
		end,
		surfaceBelow = function(centre: Vector3): Vector3
			return centre - Vector3.new(0, 3, 0)
		end,
		fireSlamWarning = function() end,
		fireSlamLanded = function() end,
		catch = function() end,
		joinedAt = function()
			return nil
		end,
		appearedAt = function()
			return nil
		end,
		showSpots = {},
		gates = {},
		bonk = function() end,
		onLadder = function()
			return false
		end,
		spendSave = function() end,
	})
	session.director.woke:Connect(function()
		session.wakes += 1
	end)
	table.insert(cleanups, function()
		session.director:destroy()
		banking:stop()
		state:Destroy()
	end)
	return session
end

local function at(zone: Config.ZoneName, moving: boolean, speed: number, garden: number?, onLadder: boolean?): Sample
	return {
		userId = USER_ID,
		position = Vector3.zero,
		moving = moving,
		groundSpeed = speed,
		zone = zone,
		garden = garden,
		thudFrom = nil,
		falling = false,
		moveGrace = false,
		onStitchedEdge = false,
		onLadder = onLadder,
	}
end

local function meterOf(session: Session): number
	return session.state:GetAttribute("Meter") :: number
end

-- One tick of the clock with the player standing as `session.samples` says.
local function tick(session: Session)
	session.clock += TICK
	session.harness.clock = session.clock
	session.director:step()
	session.peak = math.max(session.peak, meterOf(session))
end

-- Stands for `seconds` (whole ticks, the left-over carried to the next call).
local function spend(session: Session, seconds: number, sample: Sample)
	session.samples = { sample }
	session.owed += seconds
	while session.owed >= TICK do
		session.owed -= TICK
		tick(session)
	end
end

-- Walks the steps at the speeds HeistScore uses (no tiptoe).
local function walk(session: Session, steps: { Step }, carrying: Config.RarityName?)
	for _, step in steps do
		local speed = WALK_SPEED
		if carrying ~= nil then
			speed *= 1 - Config.Rarity[carrying].CarrySlowdown
		end
		local climbing = step.kind == "Climb"
		if climbing then
			speed *= CLIMB_SPEED
		end
		spend(session, step.length / speed, at(step.zone, true, speed, nil, climbing and not session.ladderOff))
	end
end

-- One tick with the player standing on the boot top at the way up's top (the root 3 studs over the feet), after the
-- Meadow ticks of the walk out: WayUpWatch (inside Analytics) logs "WayUp" once.
local function arriveAtTop(session: Session, wayIndex: number)
	local sample = at("Boots", false, 0, nil)
	sample.position = Helpers.WAY_UP_TOPS[wayIndex].top + FootprintSteps.ROOT_ABOVE_FEET
	session.samples = { sample }
	tick(session)
end

-- The index in `steps` after which the player is at the way up's top: after the last climb, or for a ramp after the
-- first step that is not in the meadow.
local function topIndex(steps: { Step }): number
	local last = 0
	for index, step in steps do
		if step.kind == "Climb" then
			last = index
		end
	end
	if last > 0 then
		return last
	end
	for index, step in steps do
		if step.zone ~= "Meadow" then
			return index
		end
	end
	return #steps
end

-- Spec 3, Rule 34: the garden is the player's own for the whole session; the real server never moves a player.
local function wayUpOf(plot: number): number
	for index, wayUp in Config.WaysUp do
		if table.find(wayUp.Gardens, plot) ~= nil then
			return index
		end
	end
	error(`no way up serves garden {plot}`)
end

-- One heist, as the player does it: leaves the garden, walks the meadow, climbs to the top, walks on to Rare egg 1,
-- grabs it, drops down, carries it home, banks it and rests until the meter is 0. Returns the meter at its start and
-- at its end (before the rest).
local function runHeist(session: Session, heist: { way: number, garden: number }, up: { Step }): (number, number)
	local player, harness = session.player, session.harness
	player.attributes.PlotIndex = heist.garden
	local startMeter = meterOf(session)
	local config = Config.WaysUp[heist.way]
	local limit = config.WalkLimitSeconds[table.find(config.Gardens, heist.garden) :: number]
	local meadow: Step = { length = limit * WALK_SPEED, kind = "Walk", zone = "Meadow" }
	local cut = topIndex(up)

	spend(session, TICK, at("Meadow", true, WALK_SPEED, nil))
	walk(session, { meadow }, nil)
	walk(session, { table.unpack(up, 1, cut) }, nil)
	arriveAtTop(session, heist.way)
	walk(session, { table.unpack(up, cut + 1) }, nil)

	-- Grabs the Rare (it takes HoldSeconds standing), then drops down and carries it home.
	Helpers.grab(harness, player, RARE)
	spend(session, Config.Grab.HoldSeconds, at(up[#up].zone, false, 0, nil))
	walk(session, HeistScore.dropDown(up), RARE)
	walk(session, { meadow }, RARE)
	spend(session, TICK, at("Meadow", true, WALK_SPEED, heist.garden))
	expect(player.attributes.Carrying).toBeNil()
	local endMeter = meterOf(session)

	-- Rests in the garden until the meter is at 0 (the garden is silent): the time it takes to drain it.
	spend(session, endMeter / SleepMeter.drainPerSecond(1) + TICK, at("Meadow", false, 0, heist.garden))
	expect(meterOf(session)).toBe(0)
	return startMeter, endMeter
end

describe("A brand-new solo player's whole session of three heists", function()
	it("drains between heists, never wakes him, and logs one WayUp per climb", function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		local setup = RealReach.build(found :: Instance, WaysUpRoutes.ROUTE_AREA)
		table.insert(cleanups, function()
			PathCheck.cleanup(setup.options)
		end)

		-- Joins through the real PlotAssigner: the first free middle garden (a fixed pick).
		local assigner = PlotAssigner.new(#Config.Gardens.MiddleFirst + #Config.Gardens.Outer, function()
			return 1
		end)
		local plot = assigner:assign(USER_ID) :: number
		local session = newSession(plot)
		local player, harness = session.player, session.harness
		table.clear(harness.calls)

		-- Heist 1 and 2 use the player's own way up; heist 3 another one. The real server never moves a player, so
		-- the test sets the garden to one of the other way up's gardens for that heist (the walk out is that garden's).
		local ownWay = wayUpOf(plot)
		local otherWay = if ownWay == LADDER_WAY then RAMP_WAY else LADDER_WAY
		local heists = {
			{ way = ownWay, garden = plot },
			{ way = ownWay, garden = plot },
			{ way = otherWay, garden = Config.WaysUp[otherWay].Gardens[1] },
		}
		expect(ownWay <= #Helpers.WAY_UP_TOPS and otherWay <= #Helpers.WAY_UP_TOPS).toBe(true)

		-- The real route of each way up: its foot to Rare egg 1, as steps.
		local routes: { [number]: { Step } } = {}
		for _, heist in heists do
			if routes[heist.way] == nil then
				local foot: Vector3? = nil
				for _, candidate in setup.waysUp do
					if candidate.name == Config.WaysUp[heist.way].Name then
						foot = candidate.foot.position
					end
				end
				expect(foot).never.toBeNil()
				local route = RouteGraph.find(setup.graph, foot :: Vector3, { Config.Nests.RareEggOne })
				expect(route).never.toBeNil()
				routes[heist.way] =
					FootprintSteps.up(route :: RouteGraph.Found, setup.points, setup.ladders, setup.zoneBoxes)
			end
		end

		-- Joins and banks a Common from the silent meadow: nothing is earned yet.
		Helpers.grab(harness, player, COMMON)
		walk(session, { { length = WALK_SPEED, kind = "Walk", zone = "Meadow" } }, COMMON)
		spend(session, TICK, at("Meadow", true, WALK_SPEED, plot))
		expect(player.attributes.EggsHome).toBe(1)
		expect(meterOf(session)).toBe(0)

		local peakOne = 0 -- the session's highest meter once heist 1 is done
		local startMeters: { number } = {}
		local endMeters: { number } = {}
		for _, heist in heists do
			local startMeter, endMeter = runHeist(session, heist, routes[heist.way])
			table.insert(startMeters, startMeter)
			table.insert(endMeters, endMeter)
			if #endMeters == 1 then
				peakOne = session.peak
			end
		end

		-- (a) The meter never reached the wake line.
		expect(session.wakes).toBe(0)
		expect(session.peak).toBeLessThan(100)
		expect(session.state:GetAttribute("Phase")).toBe("Asleep")
		-- (b) It drained between the heists: each starts lower than the one before ended.
		for number = 1, #heists do
			expect(startMeters[number]).toBeLessThan(endMeters[number])
		end
		-- (c) "WayUp" was logged once per climb, in order, with that heist's way up and garden.
		local wayUps = Helpers.eventsNamed(harness, "WayUp", player)
		expect(#wayUps).toBe(#heists)
		for number, heist in heists do
			local fields = wayUps[number].fields :: { [string]: string }
			expect(fields[FIELD_ONE]).toBe(Helpers.WAY_UP_TOPS[heist.way].name)
			expect(fields[FIELD_TWO]).toBe(tostring(heist.garden))
			expect(fields[FIELD_THREE]).toBe("Empty")
		end
		-- (d) Every egg banked: the Common and the three Rares.
		local home = Helpers.eventsNamed(harness, "EggHome", player)
		expect(#home).toBe(1 + #heists)
		expect((home[1].fields :: { [string]: string })[FIELD_ONE]).toBe(COMMON)
		for number = 2, #home do
			expect((home[number].fields :: { [string]: string })[FIELD_ONE]).toBe(RARE)
		end
		expect(player.attributes.EggsHome).toBe(1 + #heists)
		-- (e) Heist 1 again in a new session with no step on a ladder (the same as a ladder multiplier of 1; Config is
		-- frozen, so the samples are changed instead): the real run's peak is higher, so the ladder loudness counts.
		local flat = newSession(plot)
		flat.ladderOff = true
		runHeist(flat, heists[1], routes[heists[1].way])
		expect(if peakOne > flat.peak then "louder" else `ladder {peakOne} vs flat {flat.peak}`).toBe("louder")
	end)
end)
