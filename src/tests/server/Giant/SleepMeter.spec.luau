--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local SleepMeter = require(ServerScriptService.Server.Giant.SleepMeter)

-- One player's noise in a step. A player starts brand-new, with a free save to spend; a test that needs a veteran
-- (nobody to save) passes true. Only a share whose noise fills the meter needs a veteran.
local function contribution(id: number, noise: number, veteran: boolean?): SleepMeter.Contribution
	return { id = id, noise = noise, canBeSaved = veteran ~= true }
end

describe("SleepMeter.drainPerSecond", function()
	it("drains 1.5 a second with 1 player", function()
		expect(SleepMeter.drainPerSecond(1)).toBe(1.5)
	end)

	it("drains 2 a second with 2 players, 1 per player", function()
		expect(SleepMeter.drainPerSecond(2)).toBe(2)
	end)

	it("drains 8 a second with 8 players, 1 per player", function()
		expect(SleepMeter.drainPerSecond(8)).toBe(8)
	end)

	it("drains 5 a second with 5 players", function()
		expect(SleepMeter.drainPerSecond(5)).toBe(5)
	end)

	it("drains nothing with no players", function()
		expect(SleepMeter.drainPerSecond(0)).toBe(0)
	end)
end)

describe("SleepMeter.drain", function()
	it("a lone player's meter falls 1.5 in one second", function()
		expect(SleepMeter.drain(10, "Asleep", 1, 1)).toBe(8.5)
	end)

	it("never drains below 0", function()
		expect(SleepMeter.drain(1, "Asleep", 1, 10)).toBe(0)
	end)
end)

describe("SleepMeter.add", function()
	it("adds a player's noise", function()
		local result = SleepMeter.add(40, "Asleep", { contribution(1, 6) })
		expect(result.value).toBe(46)
		expect(result.woke).toBe(false)
		expect(result.wokenBy).toBe(nil)
	end)

	it("never goes above 100", function()
		local result = SleepMeter.add(98, "Asleep", { contribution(1, 50, true) })
		expect(result.value).toBe(100)
	end)

	it("reaching 100 wakes him and names the player whose noise crossed it", function()
		local result = SleepMeter.add(90, "Asleep", { contribution(7, 10, true) })
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(7)
	end)

	it("adds the biggest noise first", function()
		-- The smaller noise is listed first on purpose. Added in list order, player 1 would fill it.
		local result = SleepMeter.add(95, "Asleep", {
			contribution(1, 5),
			contribution(2, 8, true),
		})
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(2)
	end)

	it("adds the lower id first when two noises are equal", function()
		local result = SleepMeter.add(95, "Asleep", {
			contribution(9, 10),
			contribution(4, 10, true),
		})
		expect(result.wokenBy).toBe(4)
	end)

	it("a brand-new player's noise takes the meter from 80 to 90, with no cap", function()
		local result = SleepMeter.add(80, "Asleep", { contribution(1, 10) })
		expect(result.value).toBe(90)
		expect(result.woke).toBe(false)
		expect(result.wokenBy).toBe(nil)
		expect(result.saved).toEqual({})
	end)

	it("a brand-new player whose noise would fill the meter is saved: it drops to 70 and he stays asleep", function()
		local result = SleepMeter.add(95, "Asleep", { contribution(1, 10) })
		expect(result.value).toBe(70)
		expect(result.woke).toBe(false)
		expect(result.wokenBy).toBe(nil)
		expect(result.saved).toEqual({ 1 })
	end)

	it("a player whose save is used wakes him and is named", function()
		local result = SleepMeter.add(95, "Asleep", { contribution(1, 10, true) })
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(1)
		expect(result.saved).toEqual({})
	end)

	it("a veteran's bigger noise wakes him and nobody's save is spent, even with a brand-new player on him", function()
		-- Check E1. The veteran's noise is the biggest, so it goes in first. The new player's share is never reached.
		local result = SleepMeter.add(95, "Asleep", {
			contribution(1, 5),
			contribution(2, 10, true),
		})
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(2)
		expect(result.saved).toEqual({})
	end)

	it("two brand-new players who fill it one after the other each spend only their own save", function()
		-- 95 + 40 fills it: player 1 is saved, 70. Then 70 + 35 fills it again: player 2 is saved, 70.
		local result = SleepMeter.add(95, "Asleep", {
			contribution(2, 35),
			contribution(1, 40),
		})
		expect(result.value).toBe(70)
		expect(result.woke).toBe(false)
		expect(result.saved).toEqual({ 1, 2 })
	end)

	it("the other players' noise goes on from 70 after a save", function()
		-- Player 1 (40) fills it and is saved: 70. Player 2's 8 then goes on from 70, not from 95.
		local result = SleepMeter.add(95, "Asleep", {
			contribution(1, 40),
			contribution(2, 8),
		})
		expect(result.value).toBe(78)
		expect(result.saved).toEqual({ 1 })
	end)

	it(
		"one player with two shares that each fill the meter is saved once, the second share wakes him, and no save is spent",
		function()
			-- Rule 19 (Only the waker's save counts) was changed by product on 2026-10-19: a save is spent only if he
			-- is still asleep at the end of the step. So this used to expect saved = { 1 }, and now expects {}.
			local result = SleepMeter.add(95, "Asleep", {
				contribution(1, 40),
				contribution(1, 35),
			})
			expect(result.value).toBe(100)
			expect(result.woke).toBe(true)
			expect(result.wokenBy).toBe(1)
			expect(result.saved).toEqual({})
		end
	)

	it("a brand-new player who is saved, then a veteran who fills it again, wake him and spend no save", function()
		-- Rule 19. At 95, player 1 (brand-new, +30) goes first (equal noise: the lower id) and would be saved to 70.
		-- Then veteran player 2 (+30) fills it again. He wakes, player 2 is named, and player 1 keeps their save.
		local result = SleepMeter.add(95, "Asleep", {
			contribution(1, 30),
			contribution(2, 30, true),
		})
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(2)
		expect(result.saved).toEqual({})
	end)

	it("a brand-new player is not saved while the meter is locked", function()
		local result = SleepMeter.add(95, "Awake", { contribution(1, 10) })
		expect(result.value).toBe(95)
		expect(result.saved).toEqual({})
	end)

	it("a jump burst wakes him at once and names the jumper", function()
		-- 30 is a jump landing on the belly: 20 x 1.5.
		local result = SleepMeter.add(75, "Asleep", { contribution(3, 30, true) })
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(3)
	end)

	local function expectLocked(phase: "Awake" | "HeavySleep")
		local added = SleepMeter.add(50, phase, { contribution(1, 60, true) })
		expect(added.value).toBe(50)
		expect(added.woke).toBe(false)
		expect(added.wokenBy).toBe(nil)
		expect(SleepMeter.drain(50, phase, 1, 10)).toBe(50)
		local stepped = SleepMeter.step(50, phase, { contribution(1, 60, true) }, 1, 0.1)
		expect(stepped.value).toBe(50)
		expect(stepped.woke).toBe(false)
	end

	it("nothing changes the meter while he is Awake or in Heavy Sleep", function()
		expectLocked("Awake")
		expectLocked("HeavySleep")
	end)
end)

describe("SleepMeter.step", function()
	it("drains first, then adds the noise", function()
		-- Drain first: 0.5 - 1 = 0 (floored), then + 6 = 6. Adding first would give 6.5 - 1 = 5.5.
		local result = SleepMeter.step(0.5, "Asleep", { contribution(1, 6) }, 1, 1)
		expect(result.value).toBe(6)
		expect(result.woke).toBe(false)
	end)
end)

-- Rule 41's Rare egg 1 window is checked on the real routes by StuckScan/WaysUpFairness.spec (plan 3 Task 12b).
