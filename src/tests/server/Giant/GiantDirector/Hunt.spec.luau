--!strict
-- Plan 6 Task 8: the director hunts everyone outside a garden (Rules 13, 60, 62 and 63).
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local Slams = require(ServerScriptService.Server.Giant.Slams)
local Helpers = require(script.Parent.Helpers)

afterEach(Helpers.cleanUp)

local DOOR = Helpers.DOOR
local LAND = Helpers.LAND
local START_CLOCK = Helpers.START_CLOCK
local WARN = Helpers.WARN
local moveTo = Helpers.moveTo
local setCarrying = Helpers.setCarrying
local slamHarness = Helpers.slamHarness
local stepAt = Helpers.stepAtSlam

-- Where a no-egg player stands in the meadow, 76 studs from his face across the ground.
local NEAR = Vector3.new(30, 5, 70)

-- A second place, farther from his face (about 108 studs).
local FAR = Vector3.new(-40, 5, -100)

-- How far a dodger moves after a warning: more than the circle's radius, so the hand misses.
local DODGE = Vector3.new(Config.Wake.SlamCircleDiameter / 2 + 10, 0, 0)

-- The centre of the circle slam `n` warned at, as the fake surfaceBelow was asked.
local function centreOf(harness: Helpers.Harness, slam: number): Vector3
	return harness.surfaceCalls[slam]
end

local function bonkedIds(harness: Helpers.Harness): { number }
	local ids: { number } = {}
	for _, call in harness.bonks do
		table.insert(ids, call.userId)
	end
	return ids
end

local function seconds(clock: number): number
	return math.floor((clock - START_CLOCK) * 1000 + 0.5) / 1000
end

describe("GiantDirector hunt", function()
	it("aims slams 1, 3 and 5 at a solo player with no egg and bonks them; slams 2, 4 and 6 land for show", function()
		local harness = slamHarness({ { id = 1, position = DOOR, carrying = false } })
		for index = 1, #WARN do
			stepAt(harness, WARN[index])
			stepAt(harness, LAND[index])
		end
		expect(#harness.slamLandings).toBe(6)
		for index = 1, 6 do
			local distance = Slams.flatDistance(centreOf(harness, index), DOOR)
			if index % 2 == 1 then
				expect(centreOf(harness, index)).toEqual(DOOR)
			else
				expect(distance).toBeGreaterThanOrEqual(Config.Wake.ShowSlamNearStuds)
				expect(distance).toBeLessThanOrEqual(Config.Wake.ShowSlamFarStuds)
			end
		end
		expect(bonkedIds(harness)).toEqual({ 1, 1, 1 })
		expect({ seconds(harness.bonks[1].clock), seconds(harness.bonks[2].clock), seconds(harness.bonks[3].clock) }).toEqual({
			LAND[1],
			LAND[3],
			LAND[5],
		})
		expect(#harness.catches).toBe(0)
	end)

	it("aims all 6 slams at a player who dodges every circle, and none hits", function()
		local harness = slamHarness({ { id = 1, position = DOOR, carrying = false } })
		local position = DOOR
		for index = 1, #WARN do
			stepAt(harness, WARN[index])
			expect(centreOf(harness, index)).toEqual(position)
			position += DODGE
			moveTo(harness, 1, position)
			stepAt(harness, LAND[index])
		end
		expect(#harness.slamLandings).toBe(6)
		expect(#harness.bonks).toBe(0)
		expect(#harness.catches).toBe(0)
	end)

	it("aims at the carrier until they are caught, then at the player with no egg", function()
		local harness = slamHarness({
			{ id = 1, position = FAR },
			{ id = 2, position = NEAR, carrying = false },
		})
		stepAt(harness, WARN[1])
		expect(centreOf(harness, 1)).toEqual(FAR)
		moveTo(harness, 1, FAR + DODGE) -- the carrier dodges slam 1
		stepAt(harness, LAND[1])
		expect(#harness.catches).toBe(0)
		stepAt(harness, WARN[2])
		expect(centreOf(harness, 2)).toEqual(FAR + DODGE) -- still the carrier, though player 2 is nearer to him
		stepAt(harness, LAND[2])
		expect(harness.catches[1].userId).toBe(1)
		-- Caught: the egg is back and the carrier is home in their garden.
		setCarrying(harness, 1, false)
		table.clear(harness.samples)
		table.insert(harness.samples, Helpers.placed(Helpers.sample(2, "Meadow", false), NEAR))
		table.insert(harness.samples, Helpers.placed(Helpers.sample(1, "Meadow", false, nil, 1), FAR + DODGE))
		stepAt(harness, WARN[3])
		expect(centreOf(harness, 3)).toEqual(NEAR)
	end)

	it("gives a caught carrier no circle for 3 seconds after they appear at the door", function()
		local harness = slamHarness({ { id = 1, position = NEAR } })
		stepAt(harness, WARN[1])
		stepAt(harness, LAND[1])
		expect(harness.catches[1].userId).toBe(1)
		-- Like init: the egg goes back, and the player appears at the door at this moment.
		setCarrying(harness, 1, false)
		harness.appearedAt[1] = harness.clock
		moveTo(harness, 1, DOOR)
		stepAt(harness, WARN[2]) -- 1 second after they appeared
		expect(centreOf(harness, 2)).never.toEqual(DOOR)
		expect(Slams.flatDistance(centreOf(harness, 2), DOOR)).toBeGreaterThanOrEqual(Config.Wake.ShowSlamNearStuds)
		stepAt(harness, WARN[3]) -- more than 3 seconds after they appeared
		expect(WARN[3] - LAND[1]).toBeGreaterThanOrEqual(Config.Wake.DoorSeconds)
		expect(centreOf(harness, 3)).toEqual(DOOR)
	end)

	it("does not aim the first warning at a player who respawned 0.5 seconds before he woke", function()
		local harness = slamHarness({ { id = 1, position = DOOR, carrying = false } })
		harness.appearedAt[1] = START_CLOCK - 0.5
		stepAt(harness, WARN[1]) -- 2.8 seconds after they appeared
		expect(centreOf(harness, 1)).never.toEqual(DOOR)
		expect(Slams.flatDistance(centreOf(harness, 1), DOOR)).toBeGreaterThanOrEqual(Config.Wake.ShowSlamNearStuds)
		stepAt(harness, LAND[1])
		stepAt(harness, WARN[2]) -- more than 3 seconds after they appeared
		expect(centreOf(harness, 2)).toEqual(DOOR)
	end)

	it("never targets a player who joined during this wake-up, but does in the next", function()
		local harness = slamHarness({ { id = 1, position = FAR } })
		stepAt(harness, 5)
		-- Player 2 joins at 5 seconds and stands nearer to him than player 1, carrying an egg.
		Helpers.addPlayer(harness, 2, "Joiner", { carrying = "Common" })
		harness.joinedAt[2] = START_CLOCK + 5
		table.insert(harness.samples, Helpers.placed(Helpers.sample(2, "Meadow", false), NEAR))
		for index = 3, #WARN do
			stepAt(harness, WARN[index])
			stepAt(harness, LAND[index])
		end
		for index = 1, #WARN do
			expect(centreOf(harness, index)).toEqual(FAR)
		end
		-- The next wake-up: player 1 has gone, and the joiner is a target.
		table.remove(harness.infos, 1)
		table.remove(harness.samples, 1)
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		stepAt(harness, 14) -- the reset ends the timeline
		harness.state:SetAttribute("Meter", 100)
		stepAt(harness, 200) -- he wakes again
		stepAt(harness, 200 + WARN[1])
		expect(centreOf(harness, 7)).toEqual(NEAR)
	end)

	it("aims the next warning at a player who grabbed an egg at 6 seconds", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR, carrying = false },
			{ id = 2, position = FAR, carrying = false },
		})
		stepAt(harness, WARN[1])
		expect(centreOf(harness, 1)).toEqual(NEAR)
		stepAt(harness, LAND[1])
		stepAt(harness, WARN[2])
		expect(centreOf(harness, 2)).toEqual(FAR) -- player 1 was bonked, so slam 2 aims at player 2
		moveTo(harness, 2, FAR + DODGE)
		stepAt(harness, 6)
		setCarrying(harness, 2, true)
		stepAt(harness, LAND[2])
		stepAt(harness, WARN[3])
		-- Without the egg this would aim at the nearer player 1, who wasn't the last target.
		expect(centreOf(harness, 3)).toEqual(FAR + DODGE)
	end)

	it("still lands the fist when the target leaves, and hits anyone else inside it", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = NEAR + Vector3.new(5, 0, 0), carrying = false },
		})
		stepAt(harness, WARN[1])
		expect(centreOf(harness, 1)).toEqual(NEAR)
		table.remove(harness.infos, 1)
		table.remove(harness.samples, 1)
		stepAt(harness, LAND[1])
		expect(#harness.slamLandings).toBe(1)
		expect(bonkedIds(harness)).toEqual({ 2 })
		expect(#harness.catches).toBe(0)
		expect(harness.slammedCalls[1].target).toBe(1)
	end)

	it("sends the slammed signal's four arguments for a carrier, a no-egg and a show slam", function()
		local harness = slamHarness({
			{ id = 1, position = NEAR },
			{ id = 2, position = FAR, carrying = false },
		})
		harness.showSpots[1] = FAR + Vector3.new(0, -3, -40)
		stepAt(harness, WARN[1])
		stepAt(harness, LAND[1])
		-- The carrier is caught and home in their garden.
		setCarrying(harness, 1, false)
		harness.samples[1] = Helpers.placed(Helpers.sample(1, "Meadow", false, nil, 1), NEAR)
		stepAt(harness, WARN[2])
		stepAt(harness, LAND[2])
		stepAt(harness, WARN[3])
		stepAt(harness, LAND[3])
		local expected: { Helpers.SlammedCall } = {
			{ target = 1, kind = "Carrier", caught = { 1 }, bonked = {} },
			{ target = 2, kind = "No egg", caught = {}, bonked = { 2 } },
			{ target = nil, kind = "None", caught = {}, bonked = {} },
		}
		expect(harness.slammedCalls).toEqual(expected)
	end)
end)
