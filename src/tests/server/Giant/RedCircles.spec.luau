--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RedCircles = require(ServerScriptService.Server.Giant.RedCircles)

local CENTRE = Vector3.new(0, 40, 0)

-- The surface under a player: the circle's own point (a flat floor, so nothing changes the height rule).
local function flat(circle: { centre: Vector3, point: Vector3 }, _position: Vector3): number
	return circle.point.Y
end

describe("RedCircles.covers", function()
	it("a spot inside a circle before it lands is covered", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, CENTRE, 110)
		expect(circles:covers(Vector3.new(5, 40, 5), 100, flat)).toBe(true)
	end)

	it("after it lands it isn't", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, CENTRE, 110)
		expect(circles:covers(Vector3.new(5, 40, 5), 110, flat)).toBe(false)
		expect(circles:covers(Vector3.new(5, 40, 5), 120, flat)).toBe(false)
	end)

	it("outside the circle isn't", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, CENTRE, 110)
		expect(circles:covers(Vector3.new(40, 40, 0), 100, flat)).toBe(false)
	end)

	it("covers a spot inside any one of several circles", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, CENTRE, 110)
		circles:add(Vector3.new(100, 40, 0), Vector3.new(100, 40, 0), 120)
		expect(circles:covers(Vector3.new(102, 40, 0), 115, flat)).toBe(true)
	end)

	it("drops landed circles", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, CENTRE, 110)
		circles:covers(Vector3.new(5, 40, 5), 120, flat)
		-- Asking with an earlier time afterwards finds nothing: the landed circle is gone.
		expect(circles:covers(Vector3.new(5, 40, 5), 100, flat)).toBe(false)
	end)

	-- 7: the guard uses the hand's height (Config.Wake.HandAboveStuds, 45), not the old 10 studs.
	it("blocks a player 30 studs over a circle that has not landed, not one 46 over", function()
		local circles = RedCircles.new()
		local grass = Vector3.new(0, 1, 0)
		circles:add(grass, grass, 110)
		expect(circles:covers(Vector3.new(0, 31, 0), 100, flat)).toBe(true)
		expect(circles:covers(Vector3.new(0, 47, 0), 100, flat)).toBe(false)
	end)

	it("a landed circle never blocks, even with a player 30 studs over it", function()
		local circles = RedCircles.new()
		local grass = Vector3.new(0, 1, 0)
		circles:add(grass, grass, 110)
		expect(circles:covers(Vector3.new(0, 31, 0), 110, flat)).toBe(false)
	end)

	it("asks surfaceUnder with the circle and the player's position", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, Vector3.new(0, 35, 0), 110)
		local seen: { Vector3 } = {}
		circles:covers(Vector3.new(5, 38, 5), 100, function(circle, position)
			table.insert(seen, circle.point)
			table.insert(seen, position)
			return 35
		end)
		expect(seen[1]).toEqual(Vector3.new(0, 35, 0))
		expect(seen[2]).toEqual(Vector3.new(5, 38, 5))
	end)
end)
