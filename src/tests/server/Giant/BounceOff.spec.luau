--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BounceOff = require(ServerScriptService.Server.Giant.BounceOff)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

type Spot = WorldIndex.LandingSpot

-- Fake spots along the X axis, 20 studs apart: spot 1 at x = 0, spot 2 at x = 20, and so on.
local function spotsAlongALine(count: number): { Spot }
	local spots: { Spot } = {}
	for index = 1, count do
		table.insert(spots, { index = index, position = Vector3.new((index - 1) * 20, 5, 0) })
	end
	return spots
end

local function player(id: string, x: number, y: number?, z: number?): { id: any, position: Vector3 }
	return { id = id, position = Vector3.new(x, y or 80, z or 0) }
end

describe("BounceOff.assign", function()
	it("one player gets the spot nearest to them", function()
		local result = BounceOff.assign({ player("a", 41) }, spotsAlongALine(5))
		expect(result.a.index).toBe(3)
	end)

	it("height is ignored: a player 80 studs up gets the spot nearest across the ground", function()
		-- Across the ground spot 1 is 2 studs away and spot 2 is 28. In 3D, spot 1 (500 up) would be far and spot 2 near.
		local spots: { Spot } = {
			{ index = 1, position = Vector3.new(0, 500, 0) },
			{ index = 2, position = Vector3.new(30, 5, 0) },
		}
		local result = BounceOff.assign({ player("a", 2, 80) }, spots)
		expect(result.a.index).toBe(1)
	end)

	it("two players nearest the same spot: the closer one gets it, the other gets the next nearest free one", function()
		-- Both are nearest spot 2 (x = 20). "far" is listed first, but "near" is closer.
		local result = BounceOff.assign({ player("far", 28), player("near", 21) }, spotsAlongALine(4))
		expect(result.near.index).toBe(2)
		expect(result.far.index).toBe(3)
	end)

	it("every player gets a different spot while there are spots left", function()
		local players = {}
		for number = 1, 8 do
			table.insert(players, player(`p{number}`, 33))
		end
		local result = BounceOff.assign(players, spotsAlongALine(8))
		local used: { [number]: boolean } = {}
		local usedCount = 0
		for _, spot in result do
			if not used[spot.index] then
				used[spot.index] = true
				usedCount += 1
			end
		end
		expect(usedCount).toBe(8)
	end)

	it("a tie in distance goes to the earlier player in the list", function()
		local first = BounceOff.assign({ player("a", 20, 80, 10), player("b", 20, 80, -10) }, {
			{ index = 1, position = Vector3.new(20, 5, 0) },
		})
		-- With one spot and two players the first fills it; the second shares it after the spots are freed.
		expect(first.a.index).toBe(1)
		local two = BounceOff.assign({ player("a", 20, 80, 10), player("b", 20, 80, -10) }, spotsAlongALine(2))
		expect(two.a.index).toBe(2)
		expect(two.b.index).toBe(1)
	end)

	it("a player halfway between two spots gets the lower index", function()
		local result = BounceOff.assign({ player("a", 10) }, spotsAlongALine(3))
		expect(result.a.index).toBe(1)
	end)

	it("a player halfway between two spots gets the lower index, even when the spots come in reverse order", function()
		local ordered = spotsAlongALine(3)
		local reversed = { ordered[3], ordered[2], ordered[1] }
		local result = BounceOff.assign({ player("a", 10) }, reversed)
		expect(result.a.index).toBe(1)
	end)

	it("10 players, 8 spots: all get a spot, all 8 spots are used, none is given more than twice", function()
		local players = {}
		for number = 1, 10 do
			table.insert(players, player(`p{number}`, number * 13))
		end
		local result = BounceOff.assign(players, spotsAlongALine(8))
		local timesUsed: { [number]: number } = {}
		local given = 0
		for _, spot in result do
			given += 1
			timesUsed[spot.index] = (timesUsed[spot.index] or 0) + 1
		end
		expect(given).toBe(10)
		local distinct = 0
		for _, times in timesUsed do
			distinct += 1
			expect(times <= 2).toBe(true)
		end
		expect(distinct).toBe(8)
	end)

	it("no players gives an empty table", function()
		local result = BounceOff.assign({}, spotsAlongALine(8))
		expect(next(result)).toBe(nil)
	end)

	it("no spots is a mistake in the world: the error names LandingSpots", function()
		expect(function()
			BounceOff.assign({ player("a", 0) }, {})
		end).toThrow("LandingSpots")
	end)

	it("the result doesn't change if the spots come in a different order", function()
		local players = { player("a", 5), player("b", 18), player("c", 55), player("d", 61), player("e", 100) }
		local ordered = spotsAlongALine(6)
		local shuffled = { ordered[4], ordered[1], ordered[6], ordered[3], ordered[5], ordered[2] }
		local one = BounceOff.assign(players, ordered)
		local two = BounceOff.assign(players, shuffled)
		for _, entry in players do
			expect(two[entry.id].index).toBe(one[entry.id].index)
		end
	end)
end)
