--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")
local PlayedList = require(ServerStorage.Tools.checks.PlayedList)

-- Stuck safety Task 45, step 1: the played list's groups, far sample, labels and known-place
-- walk-in points, tested on made-up lists. The function parts are plain functions here, so nothing needs a world.
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

describe("PlayedList.backPoints", function()
	local PLACE = Vector3.new(10, 50, 20)
	local PLUS_X = Vector3.new(1, 0, 0)

	local function tags(found: { PlayedList.Point }): { string }
		local list: { string } = {}
		for _, point in found do
			table.insert(list, point.tag)
		end
		return list
	end

	it("walking +x gives -x2 first, then 3, 4, 6 and 8 studs back, each raised by its distance", function()
		local found = PlayedList.backPoints(PLACE, PLUS_X)
		expect(tags(found)).toEqual({ "-x2", "-x3", "-x4", "-x6", "-x8" })
		expect(found[1].position).toBe(Vector3.new(8, 52, 20))
		expect(found[5].position).toBe(Vector3.new(2, 58, 20))
		expect(found[1].distance).toBe(2)
		expect(found[5].distance).toBe(8)
	end)

	it("without a walk gives 20 points: +x 2 to 8 studs, then -x, +z and -z", function()
		local found = PlayedList.backPoints(PLACE, nil)
		local all = tags(found)
		expect(#all).toBe(20)
		expect(all[1]).toBe("+x2")
		expect(all[5]).toBe("+x8")
		expect(all[6]).toBe("-x2")
		expect(all[11]).toBe("+z2")
		expect(all[16]).toBe("-z2")
		expect(found[1].position).toBe(Vector3.new(12, 52, 20))
	end)
end)

describe("PlayedList.firstOpen", function()
	local PLACE_Y = 50

	local function closed(): PlayedList.Check
		return { open = false, blockers = { "body" } }
	end

	-- A fake start check: a point is open when `isOpen` says so; its feet are 1 stud under it.
	local function finder(isOpen: (Vector3) -> boolean, calls: { Vector3 }?): (Vector3) -> PlayedList.Check
		return function(point: Vector3): PlayedList.Check
			if calls then
				table.insert(calls, point)
			end
			if isOpen(point) then
				return { open = true, position = point - Vector3.new(0, 1, 0), blockers = {} }
			end
			return { open = false, blockers = { "body" } }
		end
	end

	local function point(tag: string, x: number, y: number, distance: number?): PlayedList.Point
		return { tag = tag, position = Vector3.new(x, y, 0), distance = distance }
	end

	it("takes the first point open twice, and starts 3 studs over its feet", function()
		local calls: { Vector3 } = {}
		local find = finder(function(at: Vector3): boolean
			return at.X ~= 1 -- the first point is closed
		end, calls)
		local points = { point("-x2", 1, 51, 2), point("-x3", 2, 51, 3), point("-x4", 3, 51, 4) }
		local found, reason = PlayedList.firstOpen(points, PLACE_Y, find)
		expect(reason).toBeNil()
		expect((found :: PlayedList.Point).tag).toBe("-x3")
		-- feet at (2, 50, 0), so the start is (2, 53, 0)
		expect((found :: PlayedList.Point).position).toBe(Vector3.new(2, 53, 0))
		expect(calls).toEqual({ Vector3.new(1, 51, 0), Vector3.new(2, 51, 0), Vector3.new(2, 53, 0) })
	end)

	it("skips a point whose second check, 3 studs over the feet, is not open", function()
		local find = finder(function(at: Vector3): boolean
			return not (at.X == 1 and at.Y == 53) -- the first point's raised start is closed
		end)
		local points = { point("-x2", 1, 51, 2), point("-x3", 2, 51, 3) }
		local found = PlayedList.firstOpen(points, PLACE_Y, find)
		expect((found :: PlayedList.Point).tag).toBe("-x3")
	end)

	it("skips a start whose feet are over the distance plus 1 stud above or below the place", function()
		local find = finder(function(): boolean
			return true
		end)
		-- feet are 1 under the point: the first at y 55 (5 above the place, limit 3), the second at y 40 (10 below)
		local points = { point("-x2", 1, 56, 2), point("-x3", 2, 41, 3), point("-x4", 3, 53, 4) }
		local found = PlayedList.firstOpen(points, PLACE_Y, find)
		expect((found :: PlayedList.Point).tag).toBe("-x4")
	end)

	it("puts no height limit on a point with no distance (a played spot)", function()
		local find = finder(function(): boolean
			return true
		end)
		local found = PlayedList.firstOpen({ point("", 1, 91, nil) }, PLACE_Y, find)
		expect((found :: PlayedList.Point).position).toBe(Vector3.new(1, 93, 0))
	end)

	it("returns nil, with the first point's tag and first blocker, when nothing is open", function()
		local points = PlayedList.backPoints(Vector3.new(10, 50, 20), Vector3.new(1, 0, 0))
		local found, reason = PlayedList.firstOpen(points, PLACE_Y, closed)
		expect(found).toBeNil()
		expect(reason).toBe("-x2 body")
	end)
end)
