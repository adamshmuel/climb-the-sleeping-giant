--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local GiantCycle = require(ServerScriptService.Server.Giant.GiantCycle)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)

export type Sample = PlayerTracker.Sample

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
type SlamWarningCall = { slam: number, point: Vector3, landsAt: number, centre: Vector3?, clock: number }

type SlamLandedCall = { slam: number, point: Vector3, clock: number }

type CatchCall = { userId: number, phase: any } -- phase: what GiantState's Phase was at the moment of the call

type BonkCall = { userId: number, onLadder: boolean, clock: number }

-- Everything the slammed signal said: the target (nil for none), its kind, the caught ids and the bonked ids.
export type SlammedCall = { target: number?, kind: string, caught: { number }, bonked: { number } }

-- One fake giant: a GiantState folder that is never parented anywhere, a list of samples and players the test
-- can change between steps, a clock the test sets by hand, and a record of what the director did.
export type Harness = {
	state: Folder,
	director: GiantDirector.Director,
	samples: { Sample },
	infos: { PlayerInfo },
	warnings: { number }, -- the mark of every plain warning (no second value), in order
	replays: { number }, -- the mark of every replayed warning (second value "FreeSave"), in order
	warningCalls: { string }, -- every fireWarning call in order: "60" for a plain mark, "85:FreeSave" for a replay
	wakes: { string },
	wakeDetails: { { name: string, wokenBy: number?, cause: string } }, -- everything the woke signal said, in order
	spent: { number }, -- the user id of every spendSave call, in order
	saves: { { userId: number, zone: Config.ZoneName } }, -- everything the saved signal said, in order
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
	surfaceCalls: { Vector3 }, -- the centre each planning call to surfaceBelow was given: the planned circle centres
	landing: boolean, -- true from a slam's landing to the next tick: surfaceBelow is then asked about players, not centres
	floatingCalls: number, -- how many times the director asked who is floating
	slamWarnings: { SlamWarningCall },
	slamLandings: { SlamLandedCall },
	catches: { CatchCall },
	order: { string }, -- "W1" (warning of slam 1), "L1" (landing of slam 1), "catch5" (user 5 caught), in call order
	-- The hunt (Rules 60, 62, 63). Each table is shared with the director, so a test may change what is in it.
	joinedAt: { [number]: number }, -- the clock when a player joined (nobody has unless the test says so)
	appearedAt: { [number]: number }, -- the clock when a player appeared at the door (nobody has unless the test says so)
	showSpots: { Vector3 },
	gates: { [number]: Vector3 }, -- the Safe Gate of each player's own garden (none unless the test says so)
	onLadder: { [number]: boolean }, -- who the tracker has on a ladder (nobody unless the test says so)
	-- Who is on which ladder: the tick stamps `onLadder = true` and `ladder = <name>` on that player's sample, as
	-- Zones.locateClimber makes them. A name from Config.Ladders.Models. Nobody unless the test says so; set to nil to drop.
	ladders: { [number]: string },
	bonks: { BonkCall },
	slammedCalls: { SlammedCall },
}

-- The fake meadow points. Far from the landing spots below and from every place a test stands.
local MEADOW_POINTS: { Vector3 } = {
	Vector3.new(0, 2, 100),
	Vector3.new(0, 2, -100),
	Vector3.new(100, 2, 100),
}

-- The fake show spots: one 40 studs behind DOOR (the place a caught player appears at), far from the landing spots.
local DOOR = Vector3.new(0, 5, -40)
local SHOW_SPOTS: { Vector3 } = {
	Vector3.new(0, 2, -80),
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
		replays = {},
		warningCalls = {},
		wakes = {},
		wakeDetails = {},
		spent = {},
		saves = {},
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
		landing = false,
		floatingCalls = 0,
		slamWarnings = {},
		slamLandings = {},
		catches = {},
		order = {},
		joinedAt = {},
		appearedAt = {},
		showSpots = table.clone(SHOW_SPOTS),
		gates = {},
		onLadder = {},
		ladders = {},
		bonks = {},
		slammedCalls = {},
		director = nil :: any,
	}
	harness.director = GiantDirector.new({
		tick = function()
			harness.landing = false
			for _, sample in harness.samples do
				local ladder = harness.ladders[sample.userId]
				if ladder ~= nil then
					sample.onLadder = true
					sample.ladder = ladder
				elseif sample.ladder ~= nil then
					sample.onLadder = nil -- dropped off: the tracker would say so
					sample.ladder = nil
				end
			end
			return harness.samples
		end,
		players = function()
			return harness.infos
		end,
		state = state,
		fireWarning = function(mark: number, kind: "FreeSave"?)
			if kind == nil then
				table.insert(harness.warnings, mark)
				table.insert(harness.warningCalls, tostring(mark))
			else
				table.insert(harness.replays, mark)
				table.insert(harness.warningCalls, `{mark}:{kind}`)
			end
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
			if not harness.landing then
				table.insert(harness.surfaceCalls, centre)
			end
			return centre - Vector3.new(0, harness.surfaceDrop, 0)
		end,
		joinedAt = function(userId: number): number?
			return harness.joinedAt[userId]
		end,
		appearedAt = function(userId: number): number?
			return harness.appearedAt[userId]
		end,
		showSpots = harness.showSpots,
		gates = harness.gates,
		onLadder = function(userId: number): boolean
			return harness.onLadder[userId] == true
		end,
		bonk = function(userId: number, onLadder: boolean)
			table.insert(harness.bonks, { userId = userId, onLadder = onLadder, clock = harness.clock })
			table.insert(harness.order, `bonk{userId}`)
		end,
		fireSlamWarning = function(slam: number, point: Vector3, landsAt: number, centre: Vector3?)
			table.insert(
				harness.slamWarnings,
				{ slam = slam, point = point, landsAt = landsAt, centre = centre, clock = harness.clock }
			)
			table.insert(harness.order, `W{slam}`)
		end,
		fireSlamLanded = function(slam: number, point: Vector3)
			harness.landing = true
			table.insert(harness.slamLandings, { slam = slam, point = point, clock = harness.clock })
			table.insert(harness.order, `L{slam}`)
		end,
		catch = function(userId: number)
			table.insert(harness.catches, { userId = userId, phase = state:GetAttribute("Phase") })
			table.insert(harness.order, `catch{userId}`)
		end,
		-- Like the real one, it marks the player's save as used, so the next tick can't save them again.
		spendSave = function(userId: number)
			table.insert(harness.spent, userId)
			for _, info in harness.infos do
				if info.userId == userId then
					info.freeSaveUsed = true
				end
			end
		end,
	})
	harness.director.woke:Connect(function(name: string, wokenBy: number?, cause: string)
		table.insert(harness.wakes, name)
		table.insert(harness.wakeDetails, { name = name, wokenBy = wokenBy, cause = cause })
	end)
	-- Typed loosely: the signal gained its kind and bonked arguments in plan 6 Task 8.
	local looseDirector: any = harness.director
	looseDirector.slammed:Connect(function(target: number?, kind: string, caught: { number }, bonked: { number })
		harness.landing = false -- the hit test is over: the next surfaceBelow call plans a circle
		table.insert(harness.slammedCalls, { target = target, kind = kind, caught = caught, bonked = bonked })
	end)
	harness.director.saved:Connect(function(userId: number, zone: Config.ZoneName)
		table.insert(harness.saves, { userId = userId, zone = zone })
	end)
	table.insert(harnesses, harness)
	return harness
end

local function cleanUp()
	for _, harness in harnesses do
		harness.director:destroy()
		harness.state:Destroy()
	end
	table.clear(harnesses)
end

local function addPlayer(
	harness: Harness,
	userId: number,
	name: string,
	extra: {
		tiptoe: boolean?,
		carrying: Config.RarityName?,
		displayName: string?,
		veteran: boolean?, -- has brought a Rare home: no free save
		saveUsed: boolean?, -- has already had the free save
	}?
)
	table.insert(harness.infos, {
		userId = userId,
		name = name,
		-- Most tests don't care about the display name, so it is the same as the name unless the test sets one.
		displayName = if extra ~= nil and extra.displayName ~= nil then extra.displayName else name,
		tiptoe = extra ~= nil and extra.tiptoe == true,
		carrying = if extra ~= nil then extra.carrying else nil,
		-- A player starts brand-new: nothing banked, no Rare home, no save used. A test that needs a veteran asks for
		-- one with `veteran = true`, which means a Rare is home: the player has no free save, so a share that fills
		-- the meter wakes him.
		eggsHome = 0, -- the director doesn't read it; PlayerInfo still has the field
		rareHome = extra ~= nil and extra.veteran == true,
		freeSaveUsed = extra ~= nil and extra.saveUsed == true,
		held = false,
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
		falling = false,
		moveGrace = false,
		onStitchedEdge = false,
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

-- The same sample, standing somewhere else.
local function placed(base: Sample, position: Vector3): Sample
	local copy = table.clone(base)
	copy.position = position
	return copy
end

-- One tick, `secondsSinceWoke` seconds after START_CLOCK (the clock of the waking step).
local function stepAt(harness: Harness, secondsSinceWoke: number)
	harness.clock = START_CLOCK + secondsSinceWoke
	harness.director:step()
end

-- A slam time such as 2.3 is not exact in binary: START_CLOCK + 2.3 - START_CLOCK can come out a hair under 2.3 and the
-- tick would not reach the event. This steps a hair past the time asked for.
local TICK_SLACK = 1e-6

local function stepAtSlam(harness: Harness, secondsSinceWoke: number)
	stepAt(harness, secondsSinceWoke + TICK_SLACK)
end

-- Every slam time comes from GiantCycle (Config.Wake.SlamWarningTimes), never typed: WARN[n] is when slam n's warning
-- comes and LAND[n] is when its hand lands (seconds since he woke).
local WARN: { number } = {}
local LAND: { number } = {}
for _, slam in GiantCycle.slams() do
	table.insert(WARN, slam.warnAt)
	table.insert(LAND, slam.landsAt)
end

-- One person in a slam test: standing still in the meadow, carrying a Common egg unless `carrying` is false.
export type Person = { id: number, position: Vector3, carrying: boolean? }

-- Wakes him at START_CLOCK with these people standing in the meadow.
local function slamHarness(people: { Person }): Harness
	local harness = newHarness(100)
	for _, person in people do
		addPlayer(
			harness,
			person.id,
			`Player{person.id}`,
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

-- The player now carries a Common egg (`true`) or no egg (`false`).
local function setCarrying(harness: Harness, userId: number, carrying: boolean)
	for _, info in harness.infos do
		if info.userId == userId then
			info.carrying = if carrying then "Common" else nil
		end
	end
end

return {
	DOOR = DOOR,
	LAND = LAND,
	MEADOW_POINTS = MEADOW_POINTS,
	START_CLOCK = START_CLOCK,
	WARN = WARN,
	addPlayer = addPlayer,
	cleanUp = cleanUp,
	meter = meter,
	moveTo = moveTo,
	newHarness = newHarness,
	placed = placed,
	sample = sample,
	setCarrying = setCarrying,
	slamHarness = slamHarness,
	stepAt = stepAt,
	stepAtSlam = stepAtSlam,
	stepTimes = stepTimes,
}
