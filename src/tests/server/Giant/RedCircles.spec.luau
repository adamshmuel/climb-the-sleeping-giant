--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RedCircles = require(ServerScriptService.Server.Giant.RedCircles)

local CENTRE = Vector3.new(0, 40, 0)

describe("RedCircles.covers", function()
	it("a spot inside a circle before it lands is covered", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, 110)
		expect(circles:covers(Vector3.new(5, 40, 5), 100)).toBe(true)
	end)

	it("after it lands it isn't", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, 110)
		expect(circles:covers(Vector3.new(5, 40, 5), 110)).toBe(false)
		expect(circles:covers(Vector3.new(5, 40, 5), 120)).toBe(false)
	end)

	it("outside the circle isn't", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, 110)
		expect(circles:covers(Vector3.new(40, 40, 0), 100)).toBe(false)
	end)

	it("covers a spot inside any one of several circles", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, 110)
		circles:add(Vector3.new(100, 40, 0), 120)
		expect(circles:covers(Vector3.new(102, 40, 0), 115)).toBe(true)
	end)

	it("drops landed circles", function()
		local circles = RedCircles.new()
		circles:add(CENTRE, 110)
		circles:covers(Vector3.new(5, 40, 5), 120)
		-- Asking with an earlier time afterwards finds nothing: the landed circle is gone.
		expect(circles:covers(Vector3.new(5, 40, 5), 100)).toBe(false)
	end)
end)
