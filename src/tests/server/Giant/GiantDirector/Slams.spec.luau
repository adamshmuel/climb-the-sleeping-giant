--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Harness = Helpers.Harness
local MEADOW_POINTS = Helpers.MEADOW_POINTS
local START_CLOCK = Helpers.START_CLOCK
local addPlayer = Helpers.addPlayer
local cleanUp = Helpers.cleanUp
local newHarness = Helpers.newHarness
local placed = Helpers.placed
local sample = Helpers.sample
local stepAt = Helpers.stepAt

afterEach(cleanUp)

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
		addPlayer(harness, 1, "Mia", { carrying = "Common" })
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
