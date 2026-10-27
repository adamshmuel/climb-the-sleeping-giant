--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")
local PlayedList = require(ServerStorage.Tools.checks.PlayedList)

-- Stuck safety Task 45, step 1 (lessons 38 and 40): the played list's groups, far sample, labels and known-place
-- candidates, tested on made-up lists. The function parts are plain functions here, so nothing needs a world.
describe("PlayedList.group", function()
	local FAR = 1000 -- studs: a distance to needs that puts a spot in no core group

	local function guard(x: number, z: number): PlayedList.Item
		return { kind = "guard", position = Vector3.new(x, 0, z) }
	end

	local function spot(x: number, z: number): PlayedList.Item
		return { kind = "steep", position = Vector3.new(x, 0, z) }
	end

	-- Two needs: one at the origin (on the giant) and one at x 200 (off it). The giant is everything with x under 100.
	local function options(): PlayedList.Options
		local farNeed = Vector3.new(200, 0, 0)
		return {
			distanceToNeeds = function(position: Vector3): number
				return math.min(position.Magnitude, (position - farNeed).Magnitude)
			end,
			onGiant = function(position: Vector3): boolean
				return position.X < 100
			end,
		}
	end

	local function labels(group: PlayedList.Group): { string }
		local found: { string } = {}
		for _, played in group.played do
			table.insert(found, played.label)
		end
		return found
	end

	it("puts a guard and a spot within 12 studs of a need in core, and one 12.1 studs away in far", function()
		local group = PlayedList.group({ guard(50, 0), spot(0, 11.9), spot(0, -12.1) }, options())
		expect(group.counts.core).toBe(2)
		expect(group.counts.far).toBe(1)
		expect(group.counts.played).toBe(3)
		expect(labels(group)).toEqual({ "C-001", "C-002", "F-003 sq 0,-16" })
	end)

	it("puts a spot off the giant in out of reach, unless it is also near a need", function()
		local list = { spot(200, FAR), spot(200, 5) }
		local group = PlayedList.group(list, options())
		expect(group.counts.reach).toBe(1)
		expect(group.counts.core).toBe(1)
		expect(labels(group)).toEqual({ "C-001", "R-002" })
		expect(group.played[2].position).toBe(Vector3.new(200, 0, FAR))
	end)

	it("plays only the first far spot of a 4 stud square, and names the square", function()
		local group = PlayedList.group({ spot(1, 40), spot(2, 41), spot(3, 42), spot(5, 40) }, options())
		expect(group.counts.far).toBe(4)
		expect(group.counts.sampled).toBe(2)
		expect(labels(group)).toEqual({ "F-001 sq 0,40", "F-002 sq 4,40" })
		expect(group.played[1].position).toBe(Vector3.new(1, 0, 40))
	end)

	it("redoes the far sample in 8 stud squares when over the cap, and stops when core alone is over", function()
		local list: { PlayedList.Item } = {}
		for index = 1, 150 do
			table.insert(list, guard(index * 3, 0))
		end
		for index = 0, 59 do
			table.insert(list, spot(-(index * 4 + 1), 500)) -- 60 squares of 4 studs, 30 squares of 8
		end
		local group = PlayedList.group(list, options())
		expect(group.counts.square).toBe(8)
		expect(group.counts.played).toBe(180)
		expect(#group.played).toBe(180)
		expect(group.stop).toBeNil()

		local tooMany: { PlayedList.Item } = {}
		for index = 1, 201 do
			table.insert(tooMany, guard(index * 3, 0))
		end
		local stopped = PlayedList.group(tooMany, options())
		expect(stopped.stop).never.toBeNil()
		expect(#stopped.played).toBe(0)
		expect(stopped.counts.core).toBe(201)
	end)

	-- 20 far spots, 9 studs apart along x and 8 apart along z: 20 squares at 4 and 8 studs, 8 at 12, 6 at 16.
	local function twentyFar(): { PlayedList.Item }
		local list: { PlayedList.Item } = {}
		for column = 0, 9 do
			for row = 0, 1 do
				table.insert(
					list,
					{ kind = "steep", position = Vector3.new(-297 + 9 * column, 0, 8 * row), slope = 50 }
				)
			end
		end
		return list
	end

	it("grows the far squares to 12 and then 16 studs until the samples fit the room left", function()
		local roomTen = options()
		roomTen.cap = 10
		local atTwelve = PlayedList.group(twentyFar(), roomTen)
		expect(atTwelve.counts.square).toBe(12)
		expect(atTwelve.counts.played).toBe(8)
		expect(atTwelve.stop).toBeNil()

		local roomSix = options()
		roomSix.cap = 6
		local atSixteen = PlayedList.group(twentyFar(), roomSix)
		expect(atSixteen.counts.square).toBe(16)
		expect(atSixteen.counts.played).toBe(6)
		expect(atSixteen.stop).toBeNil()
	end)

	it("at 16-stud squares keeps only the steepest samples that fit, ties by x then z", function()
		local list: { PlayedList.Item } = {
			{ kind = "steep", position = Vector3.new(-150, 0, 0), slope = 60 },
			{ kind = "steep", position = Vector3.new(-100, 0, 0), slope = 55 },
			{ kind = "steep", position = Vector3.new(-200, 0, 0), slope = 50 },
			{ kind = "steep", position = Vector3.new(-250, 0, 0), slope = 50 }, -- ties with x -200; smaller x wins
			{ kind = "steep", position = Vector3.new(-300, 0, 0), slope = 45 },
		}
		local roomThree = options()
		roomThree.cap = 3
		local group = PlayedList.group(list, roomThree)
		expect(group.counts.square).toBe(16)
		expect(group.counts.played).toBe(3)
		expect(labels(group)).toEqual({ "F-001 sq -160,0", "F-002 sq -112,0", "F-003 sq -256,0" })
		expect(group.played[3].position).toBe(Vector3.new(-250, 0, 0))
	end)

	it("stops with nothing played when core and out of reach alone are over the cap", function()
		local list: { PlayedList.Item } = { spot(-40, 40) } -- a far spot that must not be sampled
		for index = 1, 120 do
			table.insert(list, guard(index * 3, 0))
		end
		for index = 1, 81 do
			table.insert(list, spot(200, FAR + index * 20))
		end
		local group = PlayedList.group(list, options())
		expect(group.counts.core).toBe(120)
		expect(group.counts.reach).toBe(81)
		expect(group.counts.played).toBe(0)
		expect(#group.played).toBe(0)
		expect(group.stop).toBe("no room: core 120 + out of reach 81 is over the cap of 200")
	end)

	it("numbers the labels in play order: core, then out of reach, then far", function()
		local list = { spot(1, 40), spot(200, FAR), guard(60, 0) }
		local group = PlayedList.group(list, options())
		expect(labels(group)).toEqual({ "C-001", "R-002", "F-003 sq 0,40" })
	end)
end)

describe("PlayedList.candidates", function()
	local PLACE = Vector3.new(10, 50, 20)
	local PLUS_X = Vector3.new(1, 0, 0)

	local function same(point: Vector3): Vector3?
		return point
	end

	local function tags(found: { PlayedList.Candidate }): { string }
		local list: { string } = {}
		for _, candidate in found do
			table.insert(list, candidate.tag)
		end
		return list
	end

	it("walking +x gives -x2 first, then 3, 4, 6 and 8 studs back from the place", function()
		local found = PlayedList.candidates(PLACE, PLUS_X, same)
		expect(tags(found)).toEqual({ "-x2", "-x3", "-x4", "-x6", "-x8" })
		expect(found[1].position).toBe(Vector3.new(8, 50, 20))
		expect(found[5].position).toBe(Vector3.new(2, 50, 20))
	end)

	it("skips a candidate more than 1.5 studs sideways from its point", function()
		local function sideways(point: Vector3): Vector3?
			if math.abs(point.X - 8) < 0.01 then
				return point + Vector3.new(0, 0, 2) -- the d 2 point
			end
			return point + Vector3.new(0, 0, 1) -- 1 stud sideways is fine
		end
		local found = PlayedList.candidates(PLACE, PLUS_X, sideways)
		expect(tags(found)).toEqual({ "-x3", "-x4", "-x6", "-x8" })
	end)

	it("without a walk tries +x 2 to 8 studs, then -x", function()
		local found = PlayedList.candidates(PLACE, nil, same)
		local all = tags(found)
		expect(#all).toBe(20)
		expect(all[1]).toBe("+x2")
		expect(all[5]).toBe("+x8")
		expect(all[6]).toBe("-x2")
		expect(all[11]).toBe("+z2")
		expect(all[16]).toBe("-z2")
		expect(found[1].position).toBe(Vector3.new(12, 50, 20))
	end)

	it("skips a candidate that has no walk-map spot", function()
		local function noneAtTwo(point: Vector3): Vector3?
			if math.abs(point.X - 8) < 0.01 then
				return nil
			end
			return point
		end
		expect(tags(PlayedList.candidates(PLACE, PLUS_X, noneAtTwo))).toEqual({ "-x3", "-x4", "-x6", "-x8" })
	end)
end)
