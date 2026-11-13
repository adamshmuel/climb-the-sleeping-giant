--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WayUpWatch = require(ServerScriptService.Server.Players.WayUpWatch)

type Sample = WayUpWatch.Sample
type ZoneName = Config.ZoneName

local ACROSS = 4 -- WayUpWatch's flat limit (plan 3 Task 16 details, "Step 1 tests")
local UPDOWN = 3 -- WayUpWatch's height limit (same place)
local ROOT = 3 -- a standing root sits this far above the feet (fix card: measured 3.0 to 3.46 at the Left ramp top)
local TOPS: { WayUpWatch.Top } = {
	{ name = "Left boot ladder", top = Vector3.new(-51, 30, -64) },
	{ name = "Left ramp", top = Vector3.new(-24, 30, -100) },
}
-- Samples carry the root position, so the spots below are at root height.
local LADDER_TOP = TOPS[1].top + Vector3.new(0, ROOT, 0)
local RAMP_TOP = TOPS[2].top + Vector3.new(0, ROOT, 0)
local MEADOW_SPOT = Vector3.new(-51, 1 + ROOT, -70)
local ON_BOOT = Vector3.new(-45, 30 + ROOT, -64)

local function sample(userId: number, position: Vector3, zone: ZoneName): Sample
	return { userId = userId, position = position, zone = zone }
end

type Step = { any }

-- Feeds ticks of one player; returns how many "reached" lines each tick said.
local function feed(watch: any, userId: number, steps: { Step }): { number }
	local counts: { number } = {}
	for _, step in steps do
		local reached = watch:check({ sample(userId, step[1], step[2]) })
		table.insert(counts, #reached)
	end
	return counts
end

describe("WayUpWatch", function()
	it("says reached once for one climb, with the way up's name", function()
		local watch = WayUpWatch.new(TOPS)
		expect(watch:check({ sample(1, MEADOW_SPOT, "Meadow") })).toEqual({})
		local reached = watch:check({ sample(1, LADDER_TOP, "Boots") })
		expect(reached).toEqual({ { userId = 1, name = "Left boot ladder" } })
	end)

	it("says nothing more while staying at the top or walking on and back", function()
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, {
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP, "Boots" },
			{ LADDER_TOP, "Boots" },
			{ ON_BOOT, "Boots" },
			{ LADDER_TOP, "Boots" },
		})
		expect(counts).toEqual({ 0, 1, 0, 0, 0 })
	end)

	it("says it again for a second climb after the Meadow", function()
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, {
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP, "Boots" },
			{ MEADOW_SPOT, "Meadow" },
			{ RAMP_TOP, "Boots" },
		})
		expect(counts).toEqual({ 0, 1, 0, 1 })
		expect(watch:lastOf(1)).toBe("Left ramp")
	end)

	it("keeps each player's own last way up, nil if never, and forget clears it", function()
		local watch = WayUpWatch.new(TOPS)
		expect(watch:lastOf(1)).toBeNil()
		watch:check({ sample(1, MEADOW_SPOT, "Meadow"), sample(2, MEADOW_SPOT, "Meadow") })
		local reached = watch:check({ sample(1, LADDER_TOP, "Boots"), sample(2, ON_BOOT, "Boots") })
		expect(#reached).toBe(1)
		expect(watch:lastOf(1)).toBe("Left boot ladder")
		expect(watch:lastOf(2)).toBeNil()
		watch:forget(1)
		expect(watch:lastOf(1)).toBeNil()
	end)

	it("says nothing for a player outside 4 studs across or 3 up or down", function()
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, {
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP + Vector3.new(ACROSS + 0.5, 0, 0), "Boots" },
		})
		expect(counts).toEqual({ 0, 0 })
		local watch2 = WayUpWatch.new(TOPS)
		local counts2 = feed(watch2, 1, {
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP + Vector3.new(0, UPDOWN + 0.5, 0), "Boots" },
		})
		expect(counts2).toEqual({ 0, 0 })
		expect(watch2:lastOf(1)).toBeNil()
	end)

	it("counts a player just inside both limits", function()
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, {
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP + Vector3.new(ACROSS - 0.1, UPDOWN - 0.1, 0), "Boots" },
		})
		expect(counts).toEqual({ 0, 1 })
	end)

	it("says nothing for a player whose first tick is already on the boot top", function()
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, { { LADDER_TOP, "Boots" }, { LADDER_TOP, "Boots" } })
		expect(counts).toEqual({ 0, 0 })
	end)

	it("fires for a standing root 3.0 to 3.46 above the top, not 6.5 above", function()
		for _, rise in { 3.0, 3.46 } do
			local watch = WayUpWatch.new(TOPS)
			local counts =
				feed(watch, 1, { { MEADOW_SPOT, "Meadow" }, { TOPS[1].top + Vector3.new(0, rise, 0), "Boots" } })
			expect(counts).toEqual({ 0, 1 })
		end
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, { { MEADOW_SPOT, "Meadow" }, { TOPS[1].top + Vector3.new(0, 6.5, 0), "Boots" } })
		expect(counts).toEqual({ 0, 0 })
	end)

	it("fires once for a ladder climb that reports Boots for many ticks before the top", function()
		local watch = WayUpWatch.new(TOPS)
		local steps: { Step } = { { MEADOW_SPOT, "Meadow" } }
		for i = 1, 10 do
			-- more than 4 studs from the top, climbing: Boots all the way up
			local climbing: Step = { Vector3.new(-51, 1 + ROOT + i * 2, -64 - ACROSS - 2), "Boots" }
			table.insert(steps, climbing)
		end
		local atTop: Step = { LADDER_TOP, "Boots" }
		table.insert(steps, atTop)
		local counts = feed(watch, 1, steps)
		local total = 0
		for _, count in counts do
			total += count
		end
		expect(total).toBe(1)
		expect(counts[#counts]).toBe(1)
	end)

	it("says nothing more until a Meadow tick re-arms it", function()
		local watch = WayUpWatch.new(TOPS)
		local counts = feed(watch, 1, {
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP, "Boots" },
			{ ON_BOOT + Vector3.new(0, 0, 20), "Boots" },
			{ LADDER_TOP, "Boots" },
			{ MEADOW_SPOT, "Meadow" },
			{ LADDER_TOP, "Boots" },
		})
		expect(counts).toEqual({ 0, 1, 0, 0, 0, 1 })
	end)
end)
