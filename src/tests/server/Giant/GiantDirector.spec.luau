--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)

type Sample = PlayerTracker.Sample
type PlayerInfo = GiantDirector.PlayerInfo

-- What the fake bounce saw when the director called it: which player, which landing spot, and what GiantState
-- looked like at that moment (so a test can tell the player was moved before anything else changed).
type BounceCall = {
	userId: number,
	spotIndex: number,
	phase: any,
	wokenBy: any,
	phaseEndsAt: any,
}

-- What the fake slam deps saw. `clock` is the shared server clock at the moment of the call.
type SlamWarningCall = { slam: number, point: Vector3, landsAt: number, clock: number }
type SlamLandedCall = { slam: number, point: Vector3, clock: number }
type CatchCall = { userId: number, phase: any } -- phase: what GiantState's Phase was at the moment of the call

-- One fake giant: a GiantState folder that is never parented anywhere, a list of samples and players the test
-- can change between steps, a clock the test sets by hand, and a record of what the director did.
type Harness = {
	state: Folder,
	director: GiantDirector.Director,
	samples: { Sample },
	infos: { PlayerInfo },
	warnings: { number },
	wakes: { string },
	wakeDetails: { { name: string, wokenBy: number?, cause: string } }, -- everything the woke signal said, in order
	clock: number, -- the shared server clock; it stands still until the test moves it
	bounces: { BounceCall },
	-- The fake world for the slams. The tables are shared with the director, so a test may change what is in them.
	gardens: { Zones.GardenBox },
	meadowPoints: { Vector3 },
	floating: { [number]: boolean }, -- who is still floating down (nobody unless the test says so)
	landedAgo: { [number]: number }, -- seconds since a player touched down (nobody has unless the test says so)
	pickChoice: number, -- which of the fitting meadow points the fake pick chooses (it is held to the count)
	pickCounts: { number }, -- the count each call to pick was given
	surfaceDrop: number, -- how many studs below the planned centre the fake surface is
	surfaceCalls: { Vector3 }, -- the centre each call to surfaceBelow was given: the planned circle centres
	floatingCalls: number, -- how many times the director asked who is floating
	slamWarnings: { SlamWarningCall },
	slamLandings: { SlamLandedCall },
	catches: { CatchCall },
	order: { string }, -- "W1" (warning of slam 1), "L1" (landing of slam 1), "catch5" (user 5 caught), in call order
}

-- The fake meadow points. Far from the landing spots below and from every place a test stands.
local MEADOW_POINTS: { Vector3 } = {
	Vector3.new(0, 2, 100),
	Vector3.new(0, 2, -100),
	Vector3.new(100, 2, 100),
}

-- The point on his face that the slams count distance from.
local FACE = Vector3.new(0, 95, 0)

-- Four landing spots, two on each side, at known places across the ground (the height is not used to pick one).
local LANDING_SPOTS: { WorldIndex.LandingSpot } = {
	{ index = 1, position = Vector3.new(-50, 2, 0) },
	{ index = 2, position = Vector3.new(-50, 2, 30) },
	{ index = 3, position = Vector3.new(50, 2, 0) },
	{ index = 4, position = Vector3.new(50, 2, 30) },
}

-- The clock when a harness starts. A whole number, so adding 15 or 60 to it is exact.
local START_CLOCK = 1000

local harnesses: { Harness } = {}

local function newHarness(startMeter: number?): Harness
	local state = Instance.new("Folder")
	state:SetAttribute("Meter", startMeter or 0)
	state:SetAttribute("Phase", "Asleep")
	local harness: Harness = {
		state = state,
		samples = {},
		infos = {},
		warnings = {},
		wakes = {},
		wakeDetails = {},
		clock = START_CLOCK,
		bounces = {},
		gardens = {},
		meadowPoints = table.clone(MEADOW_POINTS),
		floating = {},
		landedAgo = {},
		pickChoice = 1,
		pickCounts = {},
		surfaceDrop = 3,
		surfaceCalls = {},
		floatingCalls = 0,
		slamWarnings = {},
		slamLandings = {},
		catches = {},
		order = {},
		director = nil :: any,
	}
	harness.director = GiantDirector.new({
		tick = function()
			return harness.samples
		end,
		players = function()
			return harness.infos
		end,
		state = state,
		fireWarning = function(mark: number)
			table.insert(harness.warnings, mark)
		end,
		now = function()
			return harness.clock
		end,
		landingSpots = LANDING_SPOTS,
		bounce = function(userId: number, spot: WorldIndex.LandingSpot)
			table.insert(harness.bounces, {
				userId = userId,
				spotIndex = spot.index,
				phase = state:GetAttribute("Phase"),
				wokenBy = state:GetAttribute("WokenBy"),
				phaseEndsAt = state:GetAttribute("PhaseEndsAt"),
			})
		end,
		gardens = harness.gardens,
		meadowPoints = harness.meadowPoints,
		face = FACE,
		floating = function(userId: number): boolean
			harness.floatingCalls += 1
			return harness.floating[userId] == true
		end,
		landedAgo = function(userId: number): number?
			return harness.landedAgo[userId]
		end,
		pick = function(count: number): number
			table.insert(harness.pickCounts, count)
			return math.min(harness.pickChoice, count)
		end,
		surfaceBelow = function(centre: Vector3): Vector3
			table.insert(harness.surfaceCalls, centre)
			return centre - Vector3.new(0, harness.surfaceDrop, 0)
		end,
		fireSlamWarning = function(slam: number, point: Vector3, landsAt: number)
			table.insert(harness.slamWarnings, { slam = slam, point = point, landsAt = landsAt, clock = harness.clock })
			table.insert(harness.order, `W{slam}`)
		end,
		fireSlamLanded = function(slam: number, point: Vector3)
			table.insert(harness.slamLandings, { slam = slam, point = point, clock = harness.clock })
			table.insert(harness.order, `L{slam}`)
		end,
		catch = function(userId: number)
			table.insert(harness.catches, { userId = userId, phase = state:GetAttribute("Phase") })
			table.insert(harness.order, `catch{userId}`)
		end,
	})
	harness.director.woke:Connect(function(name: string, wokenBy: number?, cause: string)
		table.insert(harness.wakes, name)
		table.insert(harness.wakeDetails, { name = name, wokenBy = wokenBy, cause = cause })
	end)
	table.insert(harnesses, harness)
	return harness
end

afterEach(function()
	for _, harness in harnesses do
		harness.director:destroy()
		harness.state:Destroy()
	end
	table.clear(harnesses)
end)

local function addPlayer(
	harness: Harness,
	userId: number,
	name: string,
	eggsHome: number?,
	extra: { tiptoe: boolean?, carrying: Config.RarityName?, displayName: string? }?
)
	table.insert(harness.infos, {
		userId = userId,
		name = name,
		-- Most tests don't care about the display name, so it is the same as the name unless the test sets one.
		displayName = if extra ~= nil and extra.displayName ~= nil then extra.displayName else name,
		tiptoe = extra ~= nil and extra.tiptoe == true,
		carrying = if extra ~= nil then extra.carrying else nil,
		eggsHome = eggsHome or 2,
	})
end

local function sample(
	userId: number,
	zone: Config.ZoneName,
	moving: boolean,
	thudFrom: Config.ZoneName?,
	garden: number?,
	groundSpeed: number?
): Sample
	return {
		userId = userId,
		position = Vector3.zero,
		moving = moving,
		groundSpeed = groundSpeed or 0,
		zone = zone,
		garden = garden,
		thudFrom = thudFrom,
	}
end

local function stepTimes(harness: Harness, count: number)
	for _ = 1, count do
		harness.director:step()
	end
end

local function meter(harness: Harness): number
	return harness.state:GetAttribute("Meter") :: number
end

describe("GiantDirector meter", function()
	it("rises while a player walks on his belly", function()
		-- 6 noise a second minus 1 drain a second is +5 a second. The meter starts at 10, not 0, because the
		-- drain can't take it below 0 on the first step.
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(15, 5)
	end)

	it("starts from 0 without going below it", function()
		local harness = newHarness(0)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 1)
		-- The drain of 0.1 can't take 0 below 0, so the whole 0.6 of noise stays.
		expect(meter(harness)).toBeCloseTo(0.6, 5)
	end)

	it("falls while a player stands still", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", false) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(9, 5)
	end)

	it("drains one point a second for every player", function()
		local harness = newHarness(10)
		for id = 1, 4 do
			addPlayer(harness, id, `Player{id}`)
		end
		harness.samples = { sample(1, "Meadow", false), sample(2, "Meadow", false) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(6, 5)
	end)

	it("adds noise for a player carrying an egg and tiptoeing", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", 2, { tiptoe = true, carrying = "Rare" })
		-- Boots 1 x walk 4 x Rare 2.5 x tiptoe 0.2 = 2 a second, so 0.2 a step, minus 0.1 of drain.
		harness.samples = { sample(1, "Boots", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(11, 5)
	end)

	it("makes no noise inside a garden", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		-- a garden always reports the Meadow, but the rule must hold for any zone
		harness.samples = { sample(1, "Belly", true, nil, 3) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(9, 5)
	end)

	it("ignores a sample whose player is not in the player list", function()
		local harness = newHarness(10)
		harness.samples = { sample(99, "Belly", true, "Belly") }
		stepTimes(harness, 1)
		-- No players are listed, so nothing drains and nothing is added.
		expect(meter(harness)).toBeCloseTo(10, 5)
	end)
end)

describe("GiantDirector tiptoe speed", function()
	-- All of these walk on the Belly for one second (10 steps) from a meter of 10, with the drain of 1 a second
	-- already in the numbers. Normal walking there is 1.5 x 4 = 6 a second; with Tiptoe it is a fifth of that.
	local function walkOnBelly(
		groundSpeed: number,
		extra: { tiptoe: boolean?, carrying: Config.RarityName?, displayName: string? }?
	): number
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", 2, extra)
		harness.samples = { sample(1, "Belly", true, nil, nil, groundSpeed) }
		stepTimes(harness, 10)
		return meter(harness)
	end

	it("a Tiptoe player walking at tiptoe speed makes tiptoe noise", function()
		-- 1.5 x 4 x 0.2 = 1.2 a second, minus 1 of drain.
		expect(walkOnBelly(9.6, { tiptoe = true })).toBeCloseTo(10.2, 5)
	end)

	it("a Tiptoe player walking at full speed makes normal walking noise", function()
		-- 6 a second, minus 1 of drain.
		expect(walkOnBelly(16, { tiptoe = true })).toBeCloseTo(15, 5)
	end)

	it("exactly 1.25 times tiptoe speed (12) still counts as tiptoe", function()
		expect(walkOnBelly(12, { tiptoe = true })).toBeCloseTo(10.2, 5)
	end)

	it("just over 1.25 times tiptoe speed counts as normal walking", function()
		expect(walkOnBelly(12.01, { tiptoe = true })).toBeCloseTo(15, 5)
	end)

	it("with a Rare egg the limit is 1.25 times 8.64 (10.8)", function()
		-- A Rare makes the noise 2.5 times louder: 15 a second normally, 3 with Tiptoe. Minus 1 of drain.
		expect(walkOnBelly(10.79, { tiptoe = true, carrying = "Rare" })).toBeCloseTo(12, 5)
		expect(walkOnBelly(10.81, { tiptoe = true, carrying = "Rare" })).toBeCloseTo(24, 5)
	end)

	it("a player without Tiptoe makes normal walking noise at any speed", function()
		expect(walkOnBelly(5, nil)).toBeCloseTo(15, 5)
		expect(walkOnBelly(16, nil)).toBeCloseTo(15, 5)
	end)

	it("the speed limit is checked on each step", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", 2, { tiptoe = true })
		harness.samples = { sample(1, "Belly", true, nil, nil, 16) }
		stepTimes(harness, 5) -- +5 a second for half a second: 12.5
		harness.samples = { sample(1, "Belly", true, nil, nil, 9.6) }
		stepTimes(harness, 5) -- +0.2 a second for half a second: 12.6
		expect(meter(harness)).toBeCloseTo(12.6, 5)
	end)
end)

describe("GiantDirector thuds", function()
	it("adds 30 at once for a thud from the belly", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		-- +30 from the thud, then this step's drain of 0.1.
		expect(meter(harness)).toBeCloseTo(39.9, 5)
	end)

	it("adds nothing for a thud that ends in a garden", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly", 2) }
		stepTimes(harness, 1)
		expect(meter(harness)).toBeCloseTo(9.9, 5)
	end)

	it("adds the thud's size for the zone the fall left", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Beard") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBeCloseTo(49.9, 5)
	end)
end)

describe("GiantDirector warnings", function()
	it("calls fireWarning(60) once when the meter rises past 60", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeGreaterThan(60)
		expect(harness.warnings).toEqual({ 60 })
	end)

	it("does not call it again while the meter stays above 60", function()
		local harness = newHarness(65)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(harness.warnings).toEqual({})
	end)

	it("does not repeat a warning until the meter has dropped 10 below the mark", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		expect(harness.warnings).toEqual({ 60 })
		-- Something else puts the meter back to 59.5. That is not 10 below the mark, so it stays used up.
		harness.state:SetAttribute("Meter", 59.5)
		stepTimes(harness, 5)
		expect(harness.warnings).toEqual({ 60 })
	end)

	it("warns again after the meter has dropped to 50 and rises past 60 again", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		harness.state:SetAttribute("Meter", 49)
		harness.samples = { sample(1, "Meadow", false) }
		stepTimes(harness, 1)
		harness.state:SetAttribute("Meter", 59.5)
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		expect(harness.warnings).toEqual({ 60, 60 })
	end)

	it("calls fireWarning(85) when the meter rises past 85", function()
		local harness = newHarness(70)
		addPlayer(harness, 1, "Mia")
		-- A thud from the boots is +20.
		harness.samples = { sample(1, "Meadow", false, "Boots") }
		stepTimes(harness, 1)
		expect(harness.warnings).toEqual({ 85 })
	end)

	it("sends both warnings, in order, when one step jumps past both", function()
		local harness = newHarness(57)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.warnings).toEqual({ 60, 85 })
	end)
end)

describe("GiantDirector new players", function()
	it("never lets a player with no eggs home push the meter past 84", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Newbie", 0)
		local highest = 0
		for _ = 1, 20 do
			harness.samples = { sample(1, "Belly", false, "Belly") }
			harness.director:step()
			highest = math.max(highest, meter(harness))
		end
		expect(highest).toBeLessThanOrEqual(84)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
	end)

	it("does not let a player with one egg home push it past 84 either", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Newbie", 1)
		harness.samples = { sample(1, "Meadow", false, "Nightcap") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBeLessThanOrEqual(84)
	end)

	it("lets a player with 2 eggs home reach 100 with the same noise", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Veteran", 2)
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("still counts a veteran's noise in full when a new player is also there", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Newbie", 0)
		addPlayer(harness, 2, "Veteran", 2)
		harness.samples = { sample(1, "Meadow", false, "Belly"), sample(2, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBe(100)
		expect(harness.wakes).toEqual({ "Veteran" })
	end)
end)

describe("GiantDirector waking", function()
	it("sets Phase to Awake and WokenBy to the player's name when the meter reaches 100", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
	end)

	it("sets WokenBy to the waker's display name, not the user name", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "mia_2014", nil, { displayName = "Mia" })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
	end)

	it("fires the woke signal with the waker's display name too", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "mia_2014", nil, { displayName = "Mia" })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakes).toEqual({ "Mia" })
	end)

	it("fires the woke signal once, with the waker's name", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		expect(harness.wakes).toEqual({ "Mia" })
	end)

	it("fires the woke signal with the display name first, then the waker's id and the cause", function()
		local harness = newHarness(90)
		addPlayer(harness, 7, "mia_2014", nil, { displayName = "Mia" })
		harness.samples = { sample(7, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 7, cause = "Jump on him" } })
	end)

	it("says Walking when the walking step fills the meter", function()
		local harness = newHarness(99.9)
		addPlayer(harness, 4, "Mia")
		-- Walking on the belly adds 0.6 in a tick; the drain takes 0.1.
		harness.samples = { sample(4, "Belly", true) }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 4, cause = "Walking" } })
	end)

	it("says Jump on him when a thud that lands on him fills the meter", function()
		local harness = newHarness(90)
		addPlayer(harness, 4, "Mia")
		harness.samples = { sample(4, "Beard", false, "Beard") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 4, cause = "Jump on him" } })
	end)

	it("says Jump off when a thud that lands in the meadow fills the meter", function()
		local harness = newHarness(90)
		addPlayer(harness, 4, "Mia")
		harness.samples = { sample(4, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 4, cause = "Jump off" } })
	end)

	it("counts a walk off an edge that ends in a thud as a jump", function()
		local harness = newHarness(90)
		addPlayer(harness, 4, "Mia")
		harness.samples = { sample(4, "Meadow", true, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails[1].cause).toBe("Jump off")
	end)

	it("judges the cause by the waker's own sample, not another player's", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Walker")
		addPlayer(harness, 2, "Jumper")
		harness.samples = {
			sample(1, "Meadow", false), -- on the grass, no thud
			sample(2, "Belly", false, "Belly"),
		}
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Jumper", wokenBy = 2, cause = "Jump on him" } })
	end)

	it("names nobody and says Waker left when the meter was already full at the start of the tick", function()
		local harness = newHarness(100)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "", wokenBy = nil, cause = "Waker left" } })
	end)

	it("keeps the meter at 100 on later steps", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		harness.samples = {}
		stepTimes(harness, 20)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("names the jumper whose thud crosses 100, with 3 players on him and the meter at 95", function()
		-- Spec check C1.
		local harness = newHarness(95)
		addPlayer(harness, 1, "Walker")
		addPlayer(harness, 2, "Other")
		addPlayer(harness, 3, "Jumper")
		harness.samples = {
			sample(1, "Belly", true),
			sample(2, "Belly", true),
			sample(3, "Belly", false, "Belly"),
		}
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Jumper")
		expect(harness.wakes).toEqual({ "Jumper" })
	end)

	it("names the jumper even when the walkers' noise alone would also have filled the meter", function()
		local harness = newHarness(99.5)
		addPlayer(harness, 1, "Walker")
		addPlayer(harness, 2, "Other")
		addPlayer(harness, 3, "Jumper")
		harness.samples = {
			sample(1, "Belly", true),
			sample(2, "Belly", true),
			sample(3, "Belly", false, "Belly"),
		}
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("WokenBy")).toBe("Jumper")
	end)

	it("names the walker whose steps fill the meter", function()
		local harness = newHarness(99.9)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
		expect(harness.wakes).toEqual({ "Mia" })
	end)

	it("wakes him on the next step when the meter is put at 100 while he sleeps", function()
		local harness = newHarness(0)
		harness.state:SetAttribute("Meter", 100)
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("")
		expect(harness.wakes).toEqual({ "" })
		expect(meter(harness)).toBe(100)
	end)

	it("still sends the warning for a mark the waking step rose past", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.warnings).toEqual({ 85 })
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("does not change the meter or send warnings while he is not asleep", function()
		local harness = newHarness(40)
		harness.state:SetAttribute("Phase", "HeavySleep")
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true, "Belly") }
		stepTimes(harness, 5)
		expect(meter(harness)).toBe(40)
		expect(harness.warnings).toEqual({})
		expect(harness.wakes).toEqual({})
	end)
end)

-- The same sample, standing somewhere else.
local function placed(base: Sample, position: Vector3): Sample
	local copy = table.clone(base)
	copy.position = position
	return copy
end

-- A harness at 100 about to wake on the next step, with players 1 to 3 listed.
local function newReadyHarness(): Harness
	local harness = newHarness(100)
	addPlayer(harness, 1, "Mia")
	addPlayer(harness, 2, "Leo")
	addPlayer(harness, 3, "Noa")
	return harness
end

local function bouncedSpots(harness: Harness): { [number]: number }
	local result: { [number]: number } = {}
	for _, call in harness.bounces do
		result[call.userId] = call.spotIndex
	end
	return result
end

describe("GiantDirector bounce-off", function()
	it("bounces players in Belly, Boots and Beard once each, to the nearest landing spots", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)), -- nearest spot 1
			placed(sample(2, "Boots", false), Vector3.new(48, 10, 28)), -- nearest spot 4
			placed(sample(3, "Beard", false), Vector3.new(-52, 90, 28)), -- nearest spot 2
		}
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(3)
		expect(bouncedSpots(harness)).toEqual({ [1] = 1, [2] = 4, [3] = 2 })
	end)

	it("bounces a player in the Nightcap too", function()
		local harness = newReadyHarness()
		harness.samples = { placed(sample(1, "Nightcap", false), Vector3.new(50, 120, 2)) }
		stepTimes(harness, 1)
		expect(bouncedSpots(harness)).toEqual({ [1] = 3 })
	end)

	it("does not bounce a player in the meadow or in a garden", function()
		local harness = newReadyHarness()
		harness.samples = {
			sample(1, "Meadow", false),
			sample(2, "Meadow", false, nil, 3), -- a garden reports the Meadow
			placed(sample(3, "Belly", false), Vector3.new(-45, 60, 5)),
		}
		stepTimes(harness, 1)
		expect(bouncedSpots(harness)).toEqual({ [3] = 1 })
	end)

	it("does not bounce a player whose sample is inside a garden, whatever the zone says", function()
		local harness = newReadyHarness()
		harness.samples = { sample(1, "Belly", false, nil, 3) }
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(0)
	end)

	it("gives players who stand in the same place different spots", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-50, 60, 2)),
			placed(sample(2, "Belly", false), Vector3.new(-50, 60, 2)),
		}
		stepTimes(harness, 1)
		local spots = bouncedSpots(harness)
		expect(spots[1]).never.toBe(spots[2])
	end)

	it("calls bounce in the order of the samples", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(3, "Belly", false), Vector3.new(-45, 60, 5)),
			placed(sample(1, "Belly", false), Vector3.new(48, 60, 5)),
			placed(sample(2, "Belly", false), Vector3.new(-45, 60, 25)),
		}
		stepTimes(harness, 1)
		local order: { number } = {}
		for _, call in harness.bounces do
			table.insert(order, call.userId)
		end
		expect(order).toEqual({ 3, 1, 2 })
	end)

	it("moves everyone while Phase is still Asleep, before WokenBy and PhaseEndsAt, then sets Awake", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)),
			placed(sample(2, "Boots", false), Vector3.new(48, 10, 28)),
		}
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(2)
		for _, call in harness.bounces do
			expect(call.phase).toBe("Asleep")
			expect(call.wokenBy).toBe(nil)
			expect(call.phaseEndsAt).toBe(nil)
		end
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("")
	end)

	it("names the player who filled the meter and ends Awake 15 seconds after the clock of the waking step", function()
		local harness = newHarness(95)
		addPlayer(harness, 1, "Mia")
		addPlayer(harness, 2, "Leo")
		harness.clock = START_CLOCK + 7
		harness.samples = {
			placed(sample(1, "Belly", true), Vector3.new(-45, 60, 5)),
			placed(sample(2, "Belly", false, "Belly"), Vector3.new(-45, 60, 5)),
		}
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("WokenBy")).toBe("Leo")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 7 + 15)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("wakes with no bounce call when nobody is on him", function()
		local harness = newReadyHarness()
		harness.samples = { sample(1, "Meadow", false) }
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(0)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.wakes).toEqual({ "" })
	end)

	it("does not bounce a sample whose player is not in the player list", function()
		local harness = newHarness(100)
		addPlayer(harness, 1, "Mia")
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)),
			placed(sample(99, "Belly", false), Vector3.new(48, 60, 5)),
		}
		stepTimes(harness, 1)
		expect(bouncedSpots(harness)).toEqual({ [1] = 1 })
	end)

	it("bounces once, not on every later tick", function()
		local harness = newReadyHarness()
		harness.samples = { placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)) }
		stepTimes(harness, 1)
		harness.clock += 1
		stepTimes(harness, 5)
		expect(#harness.bounces).toBe(1)
	end)
end)

-- Wakes him with Mia standing on the belly at START_CLOCK, then leaves her walking there for the rest of the test.
local function wakeWithWalker(): Harness
	local harness = newHarness(100)
	addPlayer(harness, 1, "Mia")
	harness.samples = { placed(sample(1, "Belly", true), Vector3.new(-45, 60, 5)) }
	stepTimes(harness, 1)
	return harness
end

-- One tick, `secondsSinceWoke` seconds after START_CLOCK (the clock of the waking step).
local function stepAt(harness: Harness, secondsSinceWoke: number)
	harness.clock = START_CLOCK + secondsSinceWoke
	harness.director:step()
end

describe("GiantDirector wake-up timeline", function()
	it("keeps the meter at 100 and sends no warning while he is awake, whatever the players do", function()
		local harness = wakeWithWalker()
		stepAt(harness, 3)
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepAt(harness, 7)
		expect(meter(harness)).toBe(100)
		expect(harness.warnings).toEqual({})
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("is still Awake at 14.9 seconds", function()
		local harness = wakeWithWalker()
		stepAt(harness, 14.9)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 15)
	end)

	it("turns to HeavySleep at 15 seconds, ending at 60, with the meter still full", function()
		local harness = wakeWithWalker()
		stepAt(harness, 15)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 60)
		expect(meter(harness)).toBe(100)
	end)

	it("keeps the meter locked in Heavy Sleep, for walking and for a belly thud (Check C3)", function()
		local harness = wakeWithWalker()
		stepAt(harness, 15)
		stepAt(harness, 30)
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepAt(harness, 30.1)
		harness.samples = { sample(1, "Belly", true) }
		stepAt(harness, 59.9)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
		expect(harness.warnings).toEqual({})
	end)

	it("is Asleep at 60 seconds with the meter at 0 and PhaseEndsAt removed", function()
		local harness = wakeWithWalker()
		stepAt(harness, 15)
		stepAt(harness, 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBe(0)
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(nil)
	end)

	it("keeps WokenBy after he is Asleep again", function()
		local harness = newHarness(95)
		addPlayer(harness, 1, "Mia")
		harness.samples = { placed(sample(1, "Belly", false, "Belly"), Vector3.new(-45, 60, 5)) }
		stepTimes(harness, 1)
		stepAt(harness, 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
	end)

	it("keeps the meter locked on the tick that sets Asleep, and counts noise again from the next tick", function()
		local harness = wakeWithWalker()
		stepAt(harness, 60) -- Mia walks on the belly during this tick, but the meter is still locked
		expect(meter(harness)).toBe(0)
		stepAt(harness, 60.1)
		expect(meter(harness)).toBeGreaterThan(0)
	end)

	it("raises the meter again from 0 when a player walks on the belly after he is Asleep", function()
		local harness = wakeWithWalker()
		stepAt(harness, 60)
		for tickNumber = 1, 10 do
			stepAt(harness, 60 + tickNumber * 0.1)
		end
		-- 6 a second of walking noise minus the drain of 1 a second, for 10 ticks. The first tick can't drain from
		-- 0, so it keeps its whole 0.6: 0.6 + 9 x 0.5 = 5.1.
		expect(meter(harness)).toBeCloseTo(5.1, 1)
	end)

	it("can send the 60 warning again after the cycle", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { placed(sample(1, "Belly", true), Vector3.new(-45, 60, 5)) }
		stepTimes(harness, 10)
		expect(harness.warnings).toEqual({ 60 })
		-- Now he wakes and goes through the whole cycle.
		harness.state:SetAttribute("Meter", 100)
		stepTimes(harness, 1)
		stepAt(harness, 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		-- Four thuds from the boots (+20 each) take the meter from 0 past 60 again.
		harness.samples = { sample(1, "Meadow", false, "Boots") }
		for jump = 1, 4 do
			stepAt(harness, 60 + jump * 0.1)
		end
		expect(harness.warnings).toEqual({ 60, 60 })
	end)

	it("ends Asleep at 0 after one long tick that jumps over every event", function()
		local harness = wakeWithWalker()
		stepAt(harness, 1)
		stepAt(harness, 61)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBe(0)
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(nil)
	end)

	it("follows the clock, not the number of ticks", function()
		local harness = wakeWithWalker()
		-- 1000 ticks with the clock standing still: still the same second, still Awake.
		stepTimes(harness, 1000)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		-- One tick after the clock moved 15 seconds: HeavySleep.
		stepAt(harness, 15)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
	end)

	it("stops the timeline when Phase is put back to Asleep from outside", function()
		local harness = wakeWithWalker()
		stepAt(harness, 5)
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		harness.samples = {}
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 15)
		stepAt(harness, 5.1)
		-- GiantState holds no end time while he is Asleep.
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBeNil()
		stepAt(harness, 20)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		stepAt(harness, 70)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.state:GetAttribute("PhaseEndsAt")).never.toBe(START_CLOCK + 60)
	end)

	it("wakes a second time after the cycle, with a new clock and a new bounce", function()
		local harness = wakeWithWalker()
		stepAt(harness, 60)
		harness.state:SetAttribute("Meter", 100)
		harness.samples = { placed(sample(1, "Belly", false), Vector3.new(48, 60, 5)) }
		stepAt(harness, 200)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 200 + 15)
		expect(#harness.bounces).toBe(2)
		expect(harness.bounces[2].spotIndex).toBe(3)
		stepAt(harness, 200 + 15)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 200 + 60)
		stepAt(harness, 200 + 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBe(0)
	end)

	it("starts no timeline for a Phase set from outside", function()
		local harness = newHarness(40)
		harness.state:SetAttribute("Phase", "Awake")
		stepAt(harness, 100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(nil)
	end)
end)
describe("GiantDirector Meter writes", function()
	it("rounds the written Meter to 0.1", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", 2, { tiptoe = true, carrying = "Uncommon" })
		harness.samples = { sample(1, "Boots", true) }
		-- Boots 1 x walk 4 x Uncommon 1.5 x tiptoe 0.2 = 1.2 a second, minus 1 of drain.
		-- Each step is +0.02, so 10 steps end at 10.2; three steps end at 10.06, which shows as 10.1.
		stepTimes(harness, 3)
		expect(meter(harness)).toBe(10.1)
	end)

	it("writes Meter only when its rounded value changes", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", 2, { tiptoe = true, carrying = "Uncommon" })
		harness.samples = { sample(1, "Boots", true) }
		local writes = 0
		local connection = harness.state:GetAttributeChangedSignal("Meter"):Connect(function()
			writes += 1
		end)
		-- Each step is +0.02 (1.2 a second of noise, minus 1 of drain). Steps 1 and 2 end at 10.02 and 10.04, which
		-- still show as 10.0: no write.
		stepTimes(harness, 2)
		task.wait()
		expect(writes).toBe(0)
		expect(meter(harness)).toBe(10)
		-- Step 3 ends at 10.06, which shows as 10.1: one write.
		stepTimes(harness, 1)
		task.wait()
		expect(writes).toBe(1)
		expect(meter(harness)).toBe(10.1)
		connection:Disconnect()
	end)

	it("does not write at all when nothing changes the meter", function()
		local harness = newHarness(0)
		local writes = 0
		local connection = harness.state:GetAttributeChangedSignal("Meter"):Connect(function()
			writes += 1
		end)
		stepTimes(harness, 10)
		task.wait()
		expect(writes).toBe(0)
		connection:Disconnect()
	end)
end)

-- A stand-in for Heartbeat: Connect, Fire and Disconnect, all in plain Luau.
local function newHeartbeat()
	local handlers: { (number) -> () } = {}
	return {
		Connect = function(_self: any, callback: (number) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, dt: number)
			for _, handler in table.clone(handlers) do
				handler(dt)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

describe("GiantDirector.run", function()
	local function start(maxSteps: number)
		local steps = 0
		local heartbeat = newHeartbeat()
		local stop = GiantDirector.run({
			step = function()
				steps += 1
			end,
		}, heartbeat, Config.Tick.Seconds, maxSteps)
		return heartbeat, stop, function()
			return steps
		end
	end

	it("runs one step for every 0.1 seconds", function()
		local heartbeat, stop, steps = start(3)
		heartbeat:Fire(0.1)
		heartbeat:Fire(0.1)
		expect(steps()).toBe(2)
		stop()
	end)

	it("adds up short frames before it steps", function()
		local heartbeat, stop, steps = start(3)
		heartbeat:Fire(0.04)
		heartbeat:Fire(0.04)
		expect(steps()).toBe(0)
		heartbeat:Fire(0.04)
		expect(steps()).toBe(1)
		stop()
	end)

	it("runs at most 3 steps in one frame and drops the rest", function()
		local heartbeat, stop, steps = start(3)
		heartbeat:Fire(2)
		expect(steps()).toBe(3)
		heartbeat:Fire(0.05)
		expect(steps()).toBe(3)
		stop()
	end)

	it("stops stepping and disconnects when cleaned up", function()
		local heartbeat, stop, steps = start(3)
		expect(heartbeat:count()).toBe(1)
		stop()
		expect(heartbeat:count()).toBe(0)
		heartbeat:Fire(1)
		expect(steps()).toBe(0)
	end)
end)

-- Wakes him with these people standing still in the meadow, at START_CLOCK. Everyone carries a Common egg unless
-- `carrying` is false.
type Person = { id: number, position: Vector3, carrying: boolean? }

local function slamHarness(people: { Person }): Harness
	local harness = newHarness(100)
	for _, person in people do
		addPlayer(
			harness,
			person.id,
			`Player{person.id}`,
			2,
			{ carrying = if person.carrying == false then nil else "Common" }
		)
		table.insert(harness.samples, placed(sample(person.id, "Meadow", false), person.position))
	end
	harness.director:step()
	return harness
end

local function moveTo(harness: Harness, userId: number, position: Vector3)
	for index, existing in harness.samples do
		if existing.userId == userId then
			harness.samples[index] = placed(existing, position)
		end
	end
end

-- Every time (seconds since he woke) when a slam's warning comes or its hand lands, in order.
local SLAM_TIMES = { 1, 2.5, 3.5, 5, 6, 7.5, 8.5, 10, 11, 12.5, 13.5, 15 }
local WARNING_TIMES = { 1, 3.5, 6, 8.5, 11, 13.5 }
local LANDING_TIMES = { 2.5, 5, 7.5, 10, 12.5, 15 }

local function runAllSlams(harness: Harness)
	for _, seconds in SLAM_TIMES do
		stepAt(harness, seconds)
	end
end

local function secondsOf(calls: { any }): { number }
	local result: { number } = {}
	for _, call in calls do
		table.insert(result, call.clock - START_CLOCK)
	end
	return result
end

local function catchIds(harness: Harness): { number }
	local ids: { number } = {}
	for _, call in harness.catches do
		table.insert(ids, call.userId)
	end
	return ids
end

-- Where the nearest carrier stands, 76 studs from his face across the ground.
local NEAR = Vector3.new(30, 5, 70)
-- A second carrier, farther from his face (about 108 studs).
local FAR = Vector3.new(-40, 5, -100)

describe("GiantDirector slams", function()
	it("sends the 6 warnings at 1.0, 3.5, 6.0, 8.5, 11.0 and 13.5 seconds", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		runAllSlams(harness)
		expect(#harness.slamWarnings).toBe(6)
		expect(secondsOf(harness.slamWarnings)).toEqual(WARNING_TIMES)
		for index, call in harness.slamWarnings do
			expect(call.slam).toBe(index)
		end
	end)

	it("lands each slam 1.5 seconds after its warning, with the same point", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		runAllSlams(harness)
		expect(#harness.slamLandings).toBe(6)
		expect(secondsOf(harness.slamLandings)).toEqual(LANDING_TIMES)
		for index, landing in harness.slamLandings do
			expect(landing.slam).toBe(index)
			expect(landing.point).toEqual(harness.slamWarnings[index].point)
		end
	end)

	it("sends landsAt as the clock when he woke plus the landing's seconds", function()
		local harness = newHarness(100)
		addPlayer(harness, 1, "Mia", 2, { carrying = "Common" })
		harness.samples = { placed(sample(1, "Meadow", false), NEAR) }
		harness.clock = START_CLOCK + 7
		harness.director:step() -- he wakes with the clock at START_CLOCK + 7
		for _, seconds in SLAM_TIMES do
			harness.clock = START_CLOCK + 7 + seconds
			harness.director:step()
		end
		expect(#harness.slamWarnings).toBe(6)
		for index, call in harness.slamWarnings do
			expect(call.landsAt).toBe(START_CLOCK + 7 + LANDING_TIMES[index])
		end
	end)

	it("sends the surface point below the planned centre, not the centre", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		harness.surfaceDrop = 12
		stepAt(harness, 1)
		expect(harness.surfaceCalls[1]).toEqual(NEAR)
		expect(harness.slamWarnings[1].point).toEqual(NEAR - Vector3.new(0, 12, 0))
	end)

	it("sends no slam events before the first warning, or when no one is awake", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 0.9)
		expect(#harness.slamWarnings).toBe(0)
		expect(#harness.slamLandings).toBe(0)
		expect(harness.floatingCalls).toBe(0)
	end)

	it("checks who is floating only on ticks that have a slam event", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 0.5)
		stepAt(harness, 0.9)
		expect(harness.floatingCalls).toBe(0)
		stepAt(harness, 1)
		expect(harness.floatingCalls).toBeGreaterThan(0)
	end)

	it("aims at a carrier standing still in the meadow and catches them when the hand lands", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		expect(harness.surfaceCalls[1]).toEqual(NEAR)
		expect(catchIds(harness)).toEqual({})
		stepAt(harness, 2.5)
		expect(catchIds(harness)).toEqual({ 1 })
	end)

	it("does not catch a carrier who walked more than 15 studs from the circle by the landing tick", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		moveTo(harness, 1, NEAR + Vector3.new(0, 0, 20))
		stepAt(harness, 2.5)
		expect(#harness.slamLandings).toBe(1)
		expect(catchIds(harness)).toEqual({})
	end)

	it("still catches a carrier who walked 10 studs inside the circle", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		moveTo(harness, 1, NEAR + Vector3.new(0, 0, 10))
		stepAt(harness, 2.5)
		expect(catchIds(harness)).toEqual({ 1 })
	end)

	it("measures the catch from the planned centre, not from the surface point 12 studs below", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		harness.surfaceDrop = 12
		stepAt(harness, 1)
		stepAt(harness, 2.5)
		expect(catchIds(harness)).toEqual({ 1 })
	end)

	it("does not catch a carrier who is floating down when the hand lands", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		harness.floating[1] = true
		stepAt(harness, 2.5)
		expect(#harness.slamLandings).toBe(1)
		expect(catchIds(harness)).toEqual({})
	end)

	it("does not catch a carrier who has stepped into a garden when the hand lands", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		harness.samples = { placed(sample(1, "Meadow", false, nil, 3), NEAR) }
		stepAt(harness, 2.5)
		expect(#harness.slamLandings).toBe(1)
		expect(catchIds(harness)).toEqual({})
	end)

	it("does not catch a carrier who touched down 1.4 seconds before the hand lands", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		harness.landedAgo[1] = 1.4
		stepAt(harness, 2.5)
		expect(catchIds(harness)).toEqual({})
	end)

	it("catches a carrier who touched down 2 seconds before the hand lands", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		harness.landedAgo[1] = 2
		stepAt(harness, 2.5)
		expect(catchIds(harness)).toEqual({ 1 })
	end)

	it("never aims at, or catches, a player who carries nothing", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR, carrying = false }, -- nearest to him, but carries nothing
			{ id = 2, position = FAR },
		})
		stepAt(harness, 1)
		expect(harness.surfaceCalls[1]).toEqual(FAR)
		stepAt(harness, 2.5)
		expect(catchIds(harness)).toEqual({ 2 })
	end)

	it("ignores a sample whose player is not in the player list", function()
		local harness = slamHarness({ { id = 2, position = FAR } })
		table.insert(harness.samples, placed(sample(99, "Meadow", false), NEAR))
		stepAt(harness, 1)
		expect(harness.surfaceCalls[1]).toEqual(FAR)
	end)

	it("aims the second slam at the other carrier, and the third back at the first", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = FAR },
		})
		stepAt(harness, 1)
		stepAt(harness, 3.5)
		stepAt(harness, 6)
		expect(harness.surfaceCalls).toEqual({ NEAR, FAR, NEAR })
	end)

	it("aims every slam at a lone carrier", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		runAllSlams(harness)
		expect(harness.surfaceCalls).toEqual({ NEAR, NEAR, NEAR, NEAR, NEAR, NEAR })
		expect(catchIds(harness)).toEqual({ 1, 1, 1, 1, 1, 1 })
	end)

	it("slams meadow points when nobody carries, one the fake pick chooses, and catches no one", function()
		local harness = slamHarness({ { id = 1, position = Vector3.new(200, 5, 0), carrying = false } })
		harness.pickChoice = 2
		stepAt(harness, 1)
		expect(harness.pickCounts).toEqual({ 3 })
		expect(harness.surfaceCalls[1]).toEqual(MEADOW_POINTS[2])
		expect(harness.slamWarnings[1].point).toEqual(MEADOW_POINTS[2] - Vector3.new(0, 3, 0))
		stepAt(harness, 2.5)
		expect(#harness.slamLandings).toBe(1)
		expect(catchIds(harness)).toEqual({})
	end)

	it("passes the last empty slam's point on, so the next empty slam picks another point", function()
		local harness = slamHarness({ { id = 1, position = Vector3.new(200, 5, 0), carrying = false } })
		harness.pickChoice = 2
		stepAt(harness, 1)
		stepAt(harness, 3.5)
		-- The second slam may not repeat the first point, so only 2 points are left to pick from.
		expect(harness.pickCounts).toEqual({ 3, 2 })
		expect(harness.surfaceCalls[2]).toEqual(MEADOW_POINTS[3])
	end)

	it("keeps a garden's circle clear of the garden", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		-- A garden right on the carrier: the circle must be pushed toward his face until it is clear.
		table.insert(
			harness.gardens,
			{ index = 1, cframe = CFrame.new(NEAR.X, 0, NEAR.Z), size = Vector3.new(20, 10, 20) }
		)
		stepAt(harness, 1)
		local centre = harness.surfaceCalls[1]
		expect(centre).never.toEqual(NEAR)
		-- Pushed toward his face across the ground: still at the carrier's height, and nearer to the face.
		expect(centre.Y).toBe(NEAR.Y)
		expect(math.sqrt(centre.X ^ 2 + centre.Z ^ 2)).toBeLessThan(math.sqrt(NEAR.X ^ 2 + NEAR.Z ^ 2))
	end)

	it("forgets the last target at a new wake-up", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = FAR },
		})
		stepAt(harness, 1) -- slam 1 aims at the nearest carrier (1); the last target is now 1
		expect(harness.surfaceCalls).toEqual({ NEAR })
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		stepAt(harness, 1.1) -- the reset ends the timeline
		harness.state:SetAttribute("Meter", 100)
		stepAt(harness, 200) -- he wakes again
		stepAt(harness, 201) -- slam 1 of the new wake-up
		-- Without the memory of the last target this would aim at the other carrier.
		expect(harness.surfaceCalls).toEqual({ NEAR, NEAR })
	end)

	it("forgets the last empty point at a new wake-up", function()
		local harness = slamHarness({ { id = 1, position = Vector3.new(200, 5, 0), carrying = false } })
		harness.pickChoice = 2
		stepAt(harness, 1)
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		stepAt(harness, 1.1)
		harness.state:SetAttribute("Meter", 100)
		stepAt(harness, 200)
		stepAt(harness, 201)
		-- All 3 points are choices again: the point of the slam before the reset is not left out.
		expect(harness.pickCounts).toEqual({ 3, 3 })
		expect(harness.surfaceCalls[2]).toEqual(MEADOW_POINTS[2])
	end)

	it("sends no more slam events and catches no one after a reset to Asleep from outside", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 1)
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		stepAt(harness, 2.5)
		stepAt(harness, 3.5)
		stepAt(harness, 5)
		expect(#harness.slamWarnings).toBe(1)
		expect(#harness.slamLandings).toBe(0)
		expect(catchIds(harness)).toEqual({})
	end)

	it("fires the landing before any catch, and each catch after its own landing", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = NEAR + Vector3.new(0, 0, 3) },
		})
		stepAt(harness, 1)
		stepAt(harness, 2.5)
		expect(harness.order).toEqual({ "W1", "L1", "catch1", "catch2" })
	end)

	it("lets the 6th slam's catches happen before Phase turns HeavySleep on the same tick", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		for _, seconds in SLAM_TIMES do
			if seconds < 15 then
				stepAt(harness, seconds)
			end
		end
		expect(#harness.catches).toBe(5)
		stepAt(harness, 15)
		expect(#harness.catches).toBe(6)
		expect(harness.catches[6].phase).toBe("Awake")
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
	end)

	it("plays every slam in order after one long tick", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, 15)
		expect(harness.order).toEqual({
			"W1",
			"L1",
			"catch1",
			"W2",
			"L2",
			"catch1",
			"W3",
			"L3",
			"catch1",
			"W4",
			"L4",
			"catch1",
			"W5",
			"L5",
			"catch1",
			"W6",
			"L6",
			"catch1",
		})
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
	end)

	it("sends nothing more once he is in Heavy Sleep", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		runAllSlams(harness)
		stepAt(harness, 20)
		stepAt(harness, 40)
		stepAt(harness, 60)
		expect(#harness.slamWarnings).toBe(6)
		expect(#harness.slamLandings).toBe(6)
		expect(#harness.catches).toBe(6)
	end)
end)

-- What the slammed signal said, and how many carriers had been caught (by the fake catch) when it said it.
type SlammedCall = { target: number?, caught: { number }, catchesBefore: number }

-- Listens to the slammed signal of this harness's director. The connection goes with the director when it is destroyed.
local function watchSlams(harness: Harness): { SlammedCall }
	local calls: { SlammedCall } = {}
	(harness.director :: any).slammed:Connect(function(target: number?, caught: { number })
		table.insert(calls, { target = target, caught = caught, catchesBefore = #harness.catches })
	end)
	return calls
end

describe("GiantDirector slammed signal", function()
	it("says who the slam was aimed at and who it caught, when the hand lands on a carrier", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		local slams = watchSlams(harness)
		stepAt(harness, 1)
		expect(#slams).toBe(0)
		stepAt(harness, 2.5)
		expect(slams).toEqual({ { target = 1, caught = { 1 }, catchesBefore = 1 } })
	end)

	it("says the target and an empty list when the carrier ran out of the circle", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		local slams = watchSlams(harness)
		stepAt(harness, 1)
		moveTo(harness, 1, NEAR + Vector3.new(0, 0, 20))
		stepAt(harness, 2.5)
		expect(slams).toEqual({ { target = 1, caught = {}, catchesBefore = 0 } })
	end)

	it("says no target and an empty list for a slam on the empty meadow", function()
		local harness = slamHarness({ { id = 1, position = Vector3.new(200, 5, 0), carrying = false } })
		local slams = watchSlams(harness)
		stepAt(harness, 1)
		stepAt(harness, 2.5)
		expect(#slams).toBe(1)
		expect(slams[1].target).toBeNil()
		expect(slams[1].caught).toEqual({})
	end)

	it("says who an empty-meadow slam caught when a carrier walked under it", function()
		local harness = slamHarness({ { id = 1, position = Vector3.new(200, 5, 0), carrying = false } })
		local slams = watchSlams(harness)
		stepAt(harness, 1)
		-- Player 1 picks up an egg and stands where the circle will land (the first meadow point).
		harness.infos[1].carrying = "Common"
		moveTo(harness, 1, MEADOW_POINTS[1])
		stepAt(harness, 2.5)
		expect(slams).toEqual({ { target = nil, caught = { 1 }, catchesBefore = 1 } })
	end)

	it("fires once for each of the 6 slams, with the target each time", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		local slams = watchSlams(harness)
		runAllSlams(harness)
		expect(#slams).toBe(6)
		for _, call in slams do
			expect(call.target).toBe(1)
			expect(call.caught).toEqual({ 1 })
		end
	end)

	it("fires after every catch of that landing, and lists them all", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = NEAR + Vector3.new(0, 0, 3) },
		})
		local slams = watchSlams(harness)
		stepAt(harness, 1)
		stepAt(harness, 2.5)
		expect(slams).toEqual({ { target = 1, caught = { 1, 2 }, catchesBefore = 2 } })
	end)

	it("fires nothing for a slam that has warned when he is put back to sleep from outside", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		local slams = watchSlams(harness)
		stepAt(harness, 1)
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		stepAt(harness, 2.5)
		stepAt(harness, 3.5)
		expect(slams).toEqual({})
	end)

	it("fires once for a slam after one long tick, and the target is the one of the slam", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = FAR },
		})
		local slams = watchSlams(harness)
		stepAt(harness, 15)
		expect(#slams).toBe(6)
		-- The targets alternate: the nearest carrier first, never the same one twice in a row.
		expect({ slams[1].target, slams[2].target, slams[3].target }).toEqual({ 1, 2, 1 })
	end)

	it("removes the slammed connections when the director is destroyed", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		local slams = watchSlams(harness)
		harness.director:destroy()
		stepAt(harness, 1)
		stepAt(harness, 2.5)
		expect(slams).toEqual({})
	end)
end)
