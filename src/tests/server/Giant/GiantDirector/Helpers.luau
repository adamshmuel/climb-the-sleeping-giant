--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
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
type SlamWarningCall = { slam: number, point: Vector3, landsAt: number, clock: number }

type SlamLandedCall = { slam: number, point: Vector3, clock: number }

type CatchCall = { userId: number, phase: any } -- phase: what GiantState's Phase was at the moment of the call

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

return {
	MEADOW_POINTS = MEADOW_POINTS,
	START_CLOCK = START_CLOCK,
	addPlayer = addPlayer,
	cleanUp = cleanUp,
	meter = meter,
	newHarness = newHarness,
	placed = placed,
	sample = sample,
	stepAt = stepAt,
	stepTimes = stepTimes,
}
