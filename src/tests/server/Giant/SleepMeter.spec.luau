--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local SleepMeter = require(ServerScriptService.Server.Giant.SleepMeter)

describe("SleepMeter.drainPerSecond", function()
	it("drains 1 a second with 1 player", function()
		expect(SleepMeter.drainPerSecond(1)).toBe(1)
	end)

	it("drains 5 a second with 5 players", function()
		expect(SleepMeter.drainPerSecond(5)).toBe(5)
	end)

	it("drains nothing with no players", function()
		expect(SleepMeter.drainPerSecond(0)).toBe(0)
	end)
end)

describe("SleepMeter.drain", function()
	it("never drains below 0", function()
		expect(SleepMeter.drain(1, "Asleep", 1, 10)).toBe(0)
	end)
end)

describe("SleepMeter.add", function()
	it("adds a player's noise", function()
		local result = SleepMeter.add(40, "Asleep", { { id = 1, noise = 6, eggsHome = 2 } })
		expect(result.value).toBe(46)
		expect(result.woke).toBe(false)
		expect(result.wokenBy).toBe(nil)
	end)

	it("never goes above 100", function()
		local result = SleepMeter.add(98, "Asleep", { { id = 1, noise = 50, eggsHome = 2 } })
		expect(result.value).toBe(100)
	end)

	it("reaching 100 wakes him and names the player whose noise crossed it", function()
		local result = SleepMeter.add(90, "Asleep", { { id = 7, noise = 10, eggsHome = 2 } })
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(7)
	end)

	it("adds the biggest noise first", function()
		-- The smaller noise is listed first on purpose. Added in list order, player 1 would fill it.
		local result = SleepMeter.add(95, "Asleep", {
			{ id = 1, noise = 5, eggsHome = 2 },
			{ id = 2, noise = 8, eggsHome = 2 },
		})
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(2)
	end)

	it("adds the lower id first when two noises are equal", function()
		local result = SleepMeter.add(95, "Asleep", {
			{ id = 9, noise = 10, eggsHome = 2 },
			{ id = 4, noise = 10, eggsHome = 2 },
		})
		expect(result.wokenBy).toBe(4)
	end)

	it("a new player's noise stops at 84", function()
		local result = SleepMeter.add(80, "Asleep", { { id = 1, noise = 10, eggsHome = 0 } })
		expect(result.value).toBe(84)
		expect(result.woke).toBe(false)
	end)

	it("a new player adds nothing once the meter is above 84", function()
		local result = SleepMeter.add(90, "Asleep", { { id = 1, noise = 10, eggsHome = 0 } })
		expect(result.value).toBe(90)
		expect(result.woke).toBe(false)
	end)

	it("a player with 2 eggs home pushes past 84", function()
		local result = SleepMeter.add(80, "Asleep", { { id = 1, noise = 10, eggsHome = 2 } })
		expect(result.value).toBe(90)
	end)

	it("a new player can never wake him on their own", function()
		local result = SleepMeter.add(84, "Asleep", { { id = 1, noise = 50, eggsHome = 0 } })
		expect(result.value).toBe(84)
		expect(result.woke).toBe(false)
		expect(result.wokenBy).toBe(nil)
	end)

	it("other players' noise still counts in full beside a new player", function()
		local result = SleepMeter.add(80, "Asleep", {
			{ id = 1, noise = 10, eggsHome = 0 },
			{ id = 2, noise = 5, eggsHome = 2 },
		})
		expect(result.value).toBe(89)
	end)

	it("a jump burst wakes him at once and names the jumper", function()
		-- 30 is a jump landing on the belly: 20 x 1.5.
		local result = SleepMeter.add(75, "Asleep", { { id = 3, noise = 30, eggsHome = 2 } })
		expect(result.value).toBe(100)
		expect(result.woke).toBe(true)
		expect(result.wokenBy).toBe(3)
	end)

	local function expectLocked(phase: "Awake" | "HeavySleep")
		local added = SleepMeter.add(50, phase, { { id = 1, noise = 60, eggsHome = 2 } })
		expect(added.value).toBe(50)
		expect(added.woke).toBe(false)
		expect(added.wokenBy).toBe(nil)
		expect(SleepMeter.drain(50, phase, 1, 10)).toBe(50)
		local stepped = SleepMeter.step(50, phase, { { id = 1, noise = 60, eggsHome = 2 } }, 1, 0.1)
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
		local result = SleepMeter.step(0.5, "Asleep", { { id = 1, noise = 6, eggsHome = 2 } }, 1, 1)
		expect(result.value).toBe(6)
		expect(result.woke).toBe(false)
	end)
end)

describe("spec worked example 1: a solo player stealing a Rare egg", function()
	-- The spec's legs from the left boot ramp (section 5): how long each took and the noise it made in total.
	-- The meadow is silent, so the first and last legs make none.
	type Leg = { name: string, seconds: number, noise: number }

	local TICK = 0.1

	local LEGS: { Leg } = {
		{ name = "meadow out", seconds = 1.3, noise = 0 },
		{ name = "up the boot ramp", seconds = 3.1, noise = 12.2 },
		{ name = "boot top and belly path", seconds = 2.3, noise = 9.2 },
		{ name = "grab", seconds = 1, noise = 0 },
		{ name = "down the belly path", seconds = 2.4, noise = 23 },
		{ name = "down the boot ramp", seconds = 3.5, noise = 33.5 },
		{ name = "meadow home", seconds = 2.6, noise = 0 },
	}

	-- Walks every leg in 0.1 second ticks, as the server does, for one player with 2 eggs home.
	-- Returns the final meter value, the highest value on the way, and whether he woke.
	local function walk(legs: { Leg }): (number, number, boolean)
		local value = 0
		local peak = 0
		for _, leg in legs do
			local noisePerTick = leg.noise / leg.seconds * TICK
			for _ = 1, math.round(leg.seconds / TICK) do
				local result =
					SleepMeter.step(value, "Asleep", { { id = 1, noise = noisePerTick, eggsHome = 2 } }, 1, TICK)
				value = result.value
				peak = math.max(peak, value)
				if result.woke then
					return value, peak, true
				end
			end
		end
		return value, peak, false
	end

	it("a solo Rare heist from Rare_1 peaks between 60 and 80 without waking him", function()
		local _, peak, woke = walk(LEGS)
		expect(woke).toBe(false)
		expect(peak >= 60 and peak <= 80).toBe(true)
	end)

	it("the silent meadow walk home drains the meter below its peak", function()
		local value, peak = walk(LEGS)
		expect(value < peak).toBe(true)
	end)
end)
