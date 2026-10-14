--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlotAssigner = require(ServerScriptService.Server.Players.PlotAssigner)

describe("PlotAssigner", function()
	it("gives the first free garden", function()
		local assigner = PlotAssigner.new(8)
		expect(assigner:assign(1001)).toBe(1)
		expect(assigner:assign(1002)).toBe(2)
		expect(assigner:plotOf(1002)).toBe(2)
	end)

	it("gives the same garden to the same player", function()
		local assigner = PlotAssigner.new(8)
		assigner:assign(1001)
		assigner:assign(1002)
		expect(assigner:assign(1002)).toBe(2)
		expect(assigner:assign(1001)).toBe(1)
	end)

	it("frees a garden when its player leaves", function()
		local assigner = PlotAssigner.new(8)
		assigner:assign(1001)
		assigner:assign(1002)
		assigner:release(1001)
		expect(assigner:plotOf(1001)).toBeNil()
		expect(assigner:assign(1003)).toBe(1)
	end)

	it("gives nothing when all 8 are taken", function()
		local assigner = PlotAssigner.new(8)
		for userId = 1, 8 do
			expect(assigner:assign(userId)).toBe(userId)
		end
		expect(assigner:assign(9)).toBeNil()
		expect(assigner:plotOf(9)).toBeNil()
	end)

	it("ignores a release for a player who has no garden", function()
		local assigner = PlotAssigner.new(8)
		assigner:assign(1001)
		assigner:release(555)
		expect(assigner:plotOf(1001)).toBe(1)
	end)
end)
