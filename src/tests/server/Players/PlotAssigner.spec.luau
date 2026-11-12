--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlotAssigner = require(ServerScriptService.Server.Players.PlotAssigner)

-- A fake pick that always takes the first free garden of the group.
local function first(_n: number): number
	return 1
end

-- A fake pick that cycles 1, 2, 3, 4, ... (wrapping at n), so a run shows every garden of the group.
local function newCycle(): (number) -> number
	local calls = 0
	return function(n: number): number
		calls += 1
		return (calls - 1) % n + 1
	end
end

describe("PlotAssigner", function()
	it("fills the middle gardens 3 to 6 first, in the pick's order", function()
		local assigner = PlotAssigner.new(8, first)
		expect(assigner:assign(1001)).toBe(3)
		expect(assigner:assign(1002)).toBe(4)
		expect(assigner:plotOf(1002)).toBe(4)
	end)

	it("gives the same garden to the same player", function()
		local assigner = PlotAssigner.new(8, first)
		assigner:assign(1001)
		assigner:assign(1002)
		expect(assigner:assign(1002)).toBe(4)
		expect(assigner:assign(1001)).toBe(3)
	end)

	it("frees a garden when its player leaves", function()
		local assigner = PlotAssigner.new(8, first)
		assigner:assign(1001)
		assigner:assign(1002)
		assigner:release(1001)
		expect(assigner:plotOf(1001)).toBeNil()
		expect(assigner:assign(1003)).toBe(3)
	end)

	it("gives nothing when all 8 are taken", function()
		local assigner = PlotAssigner.new(8, first)
		for userId = 1, 8 do
			expect(assigner:assign(userId)).never.toBeNil()
		end
		expect(assigner:assign(9)).toBeNil()
		expect(assigner:plotOf(9)).toBeNil()
	end)

	it("ignores a release for a player who has no garden", function()
		local assigner = PlotAssigner.new(8, first)
		assigner:assign(1001)
		assigner:release(555)
		expect(assigner:plotOf(1001)).toBe(3)
	end)

	-- B1
	it("B1: on an empty server 12 joins that each leave always get 3, 4, 5 or 6, and not always the same", function()
		local assigner = PlotAssigner.new(8, newCycle())
		local seen: { [number]: boolean } = {}
		local seenCount = 0
		for userId = 1, 12 do
			local plot = assigner:assign(userId)
			expect(plot).never.toBeNil()
			expect(plot == 3 or plot == 4 or plot == 5 or plot == 6).toBe(true)
			if plot and not seen[plot] then
				seen[plot] = true
				seenCount += 1
			end
			assigner:release(userId)
		end
		expect(seenCount > 1).toBe(true)
	end)

	-- B2
	it("B2: with gardens 3 to 6 taken, a join gets 1, 2, 7 or 8", function()
		local assigner = PlotAssigner.new(8, newCycle())
		for userId = 1, 4 do
			assigner:assign(userId)
		end
		local plot = assigner:assign(5)
		expect(plot == 1 or plot == 2 or plot == 7 or plot == 8).toBe(true)
	end)

	-- B3
	it("B3: a player in garden 7 keeps it when garden 4's player leaves, and the next join gets 4", function()
		local assigner = PlotAssigner.new(8, first)
		for userId = 1, 8 do
			assigner:assign(userId)
		end
		-- first-pick order: users 1 to 4 get 3, 4, 5, 6; users 5 to 8 get 1, 2, 7, 8
		expect(assigner:plotOf(2)).toBe(4)
		expect(assigner:plotOf(7)).toBe(7)
		assigner:release(2)
		expect(assigner:plotOf(7)).toBe(7)
		expect(assigner:assign(9)).toBe(4)
	end)

	it("8 joins at once get 8 different gardens, the first four from the middle", function()
		local assigner = PlotAssigner.new(8, newCycle())
		local used: { [number]: boolean } = {}
		for userId = 1, 8 do
			local plot = assigner:assign(userId)
			expect(plot).never.toBeNil()
			if plot then
				expect(used[plot]).never.toBe(true)
				used[plot] = true
				if userId <= 4 then
					expect(plot >= 3 and plot <= 6).toBe(true)
				end
			end
		end
	end)

	it("never gives a garden above count on a server with fewer gardens", function()
		local assigner = PlotAssigner.new(4, first)
		expect(assigner:assign(1)).toBe(3)
		expect(assigner:assign(2)).toBe(4)
		expect(assigner:assign(3)).toBe(1)
		expect(assigner:assign(4)).toBe(2)
		expect(assigner:assign(5)).toBeNil()
	end)
end)
