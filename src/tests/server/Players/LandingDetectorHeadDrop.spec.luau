--!strict
-- Task 61d: a fall from the cap, a cap tie or a tie's landing that ends on the giant is quiet (spec 5, Rule 8: Steps
-- make noise). The detector reports each such fall as a "drop" (a third value from `step`) and says whether it thudded.
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LandingDetector = require(ServerScriptService.Server.Players.LandingDetector)

-- Under strict typing a plain local widens "Belly" to `string`, so each zone is declared with its type.
local MEADOW: Config.ZoneName = "Meadow"
local BOOTS: Config.ZoneName = "Boots"
local BELLY: Config.ZoneName = "Belly"
local BEARD: Config.ZoneName = "Beard"
local NIGHTCAP: Config.ZoneName = "Nightcap"

type Tick = {
	grounded: boolean,
	speed: number,
	zone: Config.ZoneName,
	takeoffs: { Config.ZoneName }?,
	climbing: boolean?,
	onCapTie: boolean?,
}
type Drop = { from: Config.ZoneName, to: Config.ZoneName, jumped: boolean, thudded: boolean }
type Result = { thuds: { Config.ZoneName }, drops: { Drop } }

local FAST = -20 -- studs a second down, well over the fast-fall line

local function add(ticks: { Tick }, count: number, grounded: boolean, speed: number, zone: Config.ZoneName)
	for _ = 1, count do
		table.insert(ticks, { grounded = grounded, speed = speed, zone = zone })
	end
end

local function addClimb(ticks: { Tick }, count: number, zone: Config.ZoneName, onCapTie: boolean?)
	for _ = 1, count do
		table.insert(ticks, { grounded = false, speed = 5, zone = zone, climbing = true, onCapTie = onCapTie })
	end
end

-- Resting on the ground in `from`, then 4 ticks of a fast fall in the air, then 3 ticks at rest in `to` (the fall ends).
local function fastFall(from: Config.ZoneName, to: Config.ZoneName): { Tick }
	local ticks: { Tick } = {}
	add(ticks, 2, true, 0, from)
	add(ticks, 4, false, FAST, from)
	add(ticks, 3, true, 0, to)
	return ticks
end

-- Feeds the ticks to a detector that starts in `startZone`; returns every thud zone and every drop report, in order.
-- `step` returns the drop as a third value (the cast keeps this file loading until the detector has it).
local function run(startZone: Config.ZoneName, ticks: { Tick }): Result
	local state = LandingDetector.new(startZone)
	local result: Result = { thuds = {}, drops = {} }
	for _, tick in ticks do
		local thud: Config.ZoneName?, drop: Drop?
		thud, state, drop = (LandingDetector.step :: any)(
			state,
			tick.grounded,
			tick.speed,
			tick.zone,
			tick.takeoffs or {},
			tick.climbing == true,
			tick.onCapTie
		)
		if thud ~= nil then
			table.insert(result.thuds, thud)
		end
		if drop ~= nil then
			table.insert(result.drops, drop)
		end
	end
	return result
end

describe("LandingDetector head drop", function()
	it("walking off the landing and ending on his belly makes no thud", function()
		local result = run(NIGHTCAP, fastFall(NIGHTCAP, BELLY))

		expect(#result.thuds).toBe(0)
	end)

	it("walking off the landing and ending on his belly reports one quiet drop", function()
		local result = run(NIGHTCAP, fastFall(NIGHTCAP, BELLY))

		expect(#result.drops).toBe(1)
		expect(result.drops[1]).toEqual({ from = NIGHTCAP, to = BELLY, jumped = false, thudded = false })
	end)

	it("letting go of a tie in the Beard zone and ending on his belly makes no thud", function()
		local ticks: { Tick } = {}
		addClimb(ticks, 3, BEARD)
		add(ticks, 4, false, FAST, BEARD)
		add(ticks, 3, true, 0, BELLY)

		expect(#run(BEARD, ticks).thuds).toBe(0)
	end)

	it(
		"climbing partway down a tie from the cap, letting go in the Belly zone and ending on his belly makes no thud",
		function()
			local ticks: { Tick } = {}
			addClimb(ticks, 1, NIGHTCAP)
			addClimb(ticks, 3, BELLY)
			add(ticks, 4, false, FAST, BELLY)
			add(ticks, 3, true, 0, BELLY)

			expect(#run(NIGHTCAP, ticks).thuds).toBe(0)
		end
	)

	it(
		"a fast let-go from a climb that stayed in the Boots and Belly zones, ending in Belly, thuds once and is no drop",
		function()
			local ticks: { Tick } = {}
			addClimb(ticks, 2, BOOTS)
			addClimb(ticks, 2, BELLY)
			add(ticks, 4, false, FAST, BELLY)
			add(ticks, 3, true, 0, BELLY)

			local result = run(BOOTS, ticks)

			expect(result.thuds).toEqual({ BELLY })
			expect(#result.drops).toBe(0)
		end
	)

	it("a fast fall from cap height that ends on his head or face makes no thud", function()
		local result = run(NIGHTCAP, fastFall(NIGHTCAP, BEARD))

		expect(#result.thuds).toBe(0)
		expect(result.drops[1]).toEqual({ from = NIGHTCAP, to = BEARD, jumped = false, thudded = false })
	end)

	it("the same fall ending in the meadow thuds once from the Nightcap zone and reports a loud drop", function()
		local result = run(NIGHTCAP, fastFall(NIGHTCAP, MEADOW))

		expect(result.thuds).toEqual({ NIGHTCAP })
		expect(result.drops).toEqual({ { from = NIGHTCAP, to = MEADOW, jumped = false, thudded = true } })
	end)

	it("a jump from the Nightcap zone that ends on his belly thuds once and reports a jumped drop", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, NIGHTCAP)
		table.insert(ticks, { grounded = false, speed = 15, zone = NIGHTCAP, takeoffs = { NIGHTCAP } })
		add(ticks, 4, false, FAST, NIGHTCAP)
		add(ticks, 3, true, 0, BELLY)

		local result = run(NIGHTCAP, ticks)

		expect(result.thuds).toEqual({ NIGHTCAP })
		expect(result.drops).toEqual({ { from = NIGHTCAP, to = BELLY, jumped = true, thudded = true } })
	end)

	it("a fast fall that starts on the boots and ends in the meadow thuds once and is no drop", function()
		local result = run(BOOTS, fastFall(BOOTS, MEADOW))

		expect(result.thuds).toEqual({ BOOTS })
		expect(#result.drops).toBe(0)
	end)

	it(
		"climbing a cap tie from its foot, letting go low and ending on the pillow makes no thud, with a drop report",
		function()
			local ticks: { Tick } = {}
			addClimb(ticks, 3, BELLY, true)
			add(ticks, 4, false, FAST, BELLY)
			add(ticks, 3, true, 0, BELLY)

			local result = run(BELLY, ticks)

			expect(#result.thuds).toBe(0)
			expect(result.drops).toEqual({ { from = BELLY, to = BELLY, jumped = false, thudded = false } })
		end
	)

	it("a fall with no jump from the cap that ends on the cap makes no thud, with a drop report", function()
		local result = run(NIGHTCAP, fastFall(NIGHTCAP, NIGHTCAP))

		expect(#result.thuds).toBe(0)
		expect(result.drops).toEqual({ { from = NIGHTCAP, to = NIGHTCAP, jumped = false, thudded = false } })
	end)
end)
