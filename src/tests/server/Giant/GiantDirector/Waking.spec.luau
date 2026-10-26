--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Harness = Helpers.Harness
local START_CLOCK = Helpers.START_CLOCK
local addPlayer = Helpers.addPlayer
local cleanUp = Helpers.cleanUp
local meter = Helpers.meter
local newHarness = Helpers.newHarness
local placed = Helpers.placed
local sample = Helpers.sample
local stepAt = Helpers.stepAt
local stepTimes = Helpers.stepTimes

afterEach(cleanUp)

describe("GiantDirector waking", function()
	it("sets Phase to Awake and WokenBy to the player's name when the meter reaches 100", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
	end)

	it("sets WokenBy to the waker's display name, not the user name", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "mia_2014", { displayName = "Mia", veteran = true })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
	end)

	it("fires the woke signal with the waker's display name too", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "mia_2014", { displayName = "Mia", veteran = true })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakes).toEqual({ "Mia" })
	end)

	it("fires the woke signal once, with the waker's name", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		expect(harness.wakes).toEqual({ "Mia" })
	end)

	it("fires the woke signal with the display name first, then the waker's id and the cause", function()
		local harness = newHarness(90)
		addPlayer(harness, 7, "mia_2014", { displayName = "Mia", veteran = true })
		harness.samples = { sample(7, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 7, cause = "Jump on him" } })
	end)

	it("says Walking when the walking step fills the meter", function()
		local harness = newHarness(99.9)
		addPlayer(harness, 4, "Mia", { veteran = true })
		-- Walking on the belly adds 0.6 in a tick; the drain takes 0.15.
		harness.samples = { sample(4, "Belly", true) }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 4, cause = "Walking" } })
	end)

	it("says Jump on him when a thud that lands on him fills the meter", function()
		local harness = newHarness(90)
		addPlayer(harness, 4, "Mia", { veteran = true })
		harness.samples = { sample(4, "Beard", false, "Beard") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 4, cause = "Jump on him" } })
	end)

	it("says Jump off when a thud that lands in the meadow fills the meter", function()
		local harness = newHarness(90)
		addPlayer(harness, 4, "Mia", { veteran = true })
		harness.samples = { sample(4, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Mia", wokenBy = 4, cause = "Jump off" } })
	end)

	it("counts a walk off an edge that ends in a thud as a jump", function()
		local harness = newHarness(90)
		addPlayer(harness, 4, "Mia", { veteran = true })
		harness.samples = { sample(4, "Meadow", true, "Belly") }
		stepTimes(harness, 1)
		expect(harness.wakeDetails[1].cause).toBe("Jump off")
	end)

	it("judges the cause by the waker's own sample, not another player's", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Walker", { veteran = true })
		addPlayer(harness, 2, "Jumper", { veteran = true })
		harness.samples = {
			sample(1, "Meadow", false), -- on the grass, no thud
			sample(2, "Belly", false, "Belly"),
		}
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "Jumper", wokenBy = 2, cause = "Jump on him" } })
	end)

	it("names nobody and says Waker left when the meter was already full at the start of the tick", function()
		local harness = newHarness(100)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 1)
		expect(harness.wakeDetails).toEqual({ { name = "", wokenBy = nil, cause = "Waker left" } })
	end)

	it("keeps the meter at 100 on later steps", function()
		local harness = newHarness(90)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		harness.samples = {}
		stepTimes(harness, 20)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("names the jumper whose thud crosses 100, with 3 players on him and the meter at 95", function()
		-- Spec check C1.
		local harness = newHarness(95)
		addPlayer(harness, 1, "Walker", { veteran = true })
		addPlayer(harness, 2, "Other", { veteran = true })
		addPlayer(harness, 3, "Jumper", { veteran = true })
		harness.samples = {
			sample(1, "Belly", true),
			sample(2, "Belly", true),
			sample(3, "Belly", false, "Belly"),
		}
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Jumper")
		expect(harness.wakes).toEqual({ "Jumper" })
	end)

	it("names the jumper even when the walkers' noise alone would also have filled the meter", function()
		local harness = newHarness(99.5)
		addPlayer(harness, 1, "Walker", { veteran = true })
		addPlayer(harness, 2, "Other", { veteran = true })
		addPlayer(harness, 3, "Jumper", { veteran = true })
		harness.samples = {
			sample(1, "Belly", true),
			sample(2, "Belly", true),
			sample(3, "Belly", false, "Belly"),
		}
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("WokenBy")).toBe("Jumper")
	end)

	it("names the walker whose steps fill the meter", function()
		local harness = newHarness(99.9)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
		expect(harness.wakes).toEqual({ "Mia" })
	end)

	it("wakes him on the next step when the meter is put at 100 while he sleeps", function()
		local harness = newHarness(0)
		harness.state:SetAttribute("Meter", 100)
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("")
		expect(harness.wakes).toEqual({ "" })
		expect(meter(harness)).toBe(100)
	end)

	it("still sends the warning for a mark the waking step rose past", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.warnings).toEqual({ 85 })
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("does not change the meter or send warnings while he is not asleep", function()
		local harness = newHarness(40)
		harness.state:SetAttribute("Phase", "HeavySleep")
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true, "Belly") }
		stepTimes(harness, 5)
		expect(meter(harness)).toBe(40)
		expect(harness.warnings).toEqual({})
		expect(harness.wakes).toEqual({})
	end)
end)

-- A harness at 100 about to wake on the next step, with players 1 to 3 listed.
local function newReadyHarness(): Harness
	local harness = newHarness(100)
	addPlayer(harness, 1, "Mia")
	addPlayer(harness, 2, "Leo")
	addPlayer(harness, 3, "Noa")
	return harness
end

local function bouncedSpots(harness: Harness): { [number]: number }
	local result: { [number]: number } = {}
	for _, call in harness.bounces do
		result[call.userId] = call.spotIndex
	end
	return result
end

describe("GiantDirector bounce-off", function()
	it("bounces players in Belly, Boots and Beard once each, to the nearest landing spots", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)), -- nearest spot 1
			placed(sample(2, "Boots", false), Vector3.new(48, 10, 28)), -- nearest spot 4
			placed(sample(3, "Beard", false), Vector3.new(-52, 90, 28)), -- nearest spot 2
		}
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(3)
		expect(bouncedSpots(harness)).toEqual({ [1] = 1, [2] = 4, [3] = 2 })
	end)

	it("bounces a player in the Nightcap too", function()
		local harness = newReadyHarness()
		harness.samples = { placed(sample(1, "Nightcap", false), Vector3.new(50, 120, 2)) }
		stepTimes(harness, 1)
		expect(bouncedSpots(harness)).toEqual({ [1] = 3 })
	end)

	it("does not bounce a player in the meadow or in a garden", function()
		local harness = newReadyHarness()
		harness.samples = {
			sample(1, "Meadow", false),
			sample(2, "Meadow", false, nil, 3), -- a garden reports the Meadow
			placed(sample(3, "Belly", false), Vector3.new(-45, 60, 5)),
		}
		stepTimes(harness, 1)
		expect(bouncedSpots(harness)).toEqual({ [3] = 1 })
	end)

	it("does not bounce a player whose sample is inside a garden, whatever the zone says", function()
		local harness = newReadyHarness()
		harness.samples = { sample(1, "Belly", false, nil, 3) }
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(0)
	end)

	it("gives players who stand in the same place different spots", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-50, 60, 2)),
			placed(sample(2, "Belly", false), Vector3.new(-50, 60, 2)),
		}
		stepTimes(harness, 1)
		local spots = bouncedSpots(harness)
		expect(spots[1]).never.toBe(spots[2])
	end)

	it("calls bounce in the order of the samples", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(3, "Belly", false), Vector3.new(-45, 60, 5)),
			placed(sample(1, "Belly", false), Vector3.new(48, 60, 5)),
			placed(sample(2, "Belly", false), Vector3.new(-45, 60, 25)),
		}
		stepTimes(harness, 1)
		local order: { number } = {}
		for _, call in harness.bounces do
			table.insert(order, call.userId)
		end
		expect(order).toEqual({ 3, 1, 2 })
	end)

	it("moves everyone while Phase is still Asleep, before WokenBy and PhaseEndsAt, then sets Awake", function()
		local harness = newReadyHarness()
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)),
			placed(sample(2, "Boots", false), Vector3.new(48, 10, 28)),
		}
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(2)
		for _, call in harness.bounces do
			expect(call.phase).toBe("Asleep")
			expect(call.wokenBy).toBe(nil)
			expect(call.phaseEndsAt).toBe(nil)
		end
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("")
	end)

	it("names the player who filled the meter and ends Awake 15 seconds after the clock of the waking step", function()
		local harness = newHarness(95)
		addPlayer(harness, 1, "Mia", { veteran = true })
		addPlayer(harness, 2, "Leo", { veteran = true })
		harness.clock = START_CLOCK + 7
		harness.samples = {
			placed(sample(1, "Belly", true), Vector3.new(-45, 60, 5)),
			placed(sample(2, "Belly", false, "Belly"), Vector3.new(-45, 60, 5)),
		}
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("WokenBy")).toBe("Leo")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 7 + 15)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("wakes with no bounce call when nobody is on him", function()
		local harness = newReadyHarness()
		harness.samples = { sample(1, "Meadow", false) }
		stepTimes(harness, 1)
		expect(#harness.bounces).toBe(0)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.wakes).toEqual({ "" })
	end)

	it("does not bounce a sample whose player is not in the player list", function()
		local harness = newHarness(100)
		addPlayer(harness, 1, "Mia")
		harness.samples = {
			placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)),
			placed(sample(99, "Belly", false), Vector3.new(48, 60, 5)),
		}
		stepTimes(harness, 1)
		expect(bouncedSpots(harness)).toEqual({ [1] = 1 })
	end)

	it("bounces once, not on every later tick", function()
		local harness = newReadyHarness()
		harness.samples = { placed(sample(1, "Belly", false), Vector3.new(-45, 60, 5)) }
		stepTimes(harness, 1)
		harness.clock += 1
		stepTimes(harness, 5)
		expect(#harness.bounces).toBe(1)
	end)
end)

-- Wakes him with Mia standing on the belly at START_CLOCK, then leaves her walking there for the rest of the test.
local function wakeWithWalker(): Harness
	local harness = newHarness(100)
	addPlayer(harness, 1, "Mia")
	harness.samples = { placed(sample(1, "Belly", true), Vector3.new(-45, 60, 5)) }
	stepTimes(harness, 1)
	return harness
end

describe("GiantDirector wake-up timeline", function()
	it("keeps the meter at 100 and sends no warning while he is awake, whatever the players do", function()
		local harness = wakeWithWalker()
		stepAt(harness, 3)
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepAt(harness, 7)
		expect(meter(harness)).toBe(100)
		expect(harness.warnings).toEqual({})
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
	end)

	it("is still Awake at 14.9 seconds", function()
		local harness = wakeWithWalker()
		stepAt(harness, 14.9)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 15)
	end)

	it("turns to HeavySleep at 15 seconds, ending at 60, with the meter still full", function()
		local harness = wakeWithWalker()
		stepAt(harness, 15)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 60)
		expect(meter(harness)).toBe(100)
	end)

	it("keeps the meter locked in Heavy Sleep, for walking and for a belly thud (Check C3)", function()
		local harness = wakeWithWalker()
		stepAt(harness, 15)
		stepAt(harness, 30)
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepAt(harness, 30.1)
		harness.samples = { sample(1, "Belly", true) }
		stepAt(harness, 59.9)
		expect(meter(harness)).toBe(100)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
		expect(harness.warnings).toEqual({})
	end)

	it("is Asleep at 60 seconds with the meter at 0 and PhaseEndsAt removed", function()
		local harness = wakeWithWalker()
		stepAt(harness, 15)
		stepAt(harness, 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBe(0)
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(nil)
	end)

	it("keeps WokenBy after he is Asleep again", function()
		local harness = newHarness(95)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { placed(sample(1, "Belly", false, "Belly"), Vector3.new(-45, 60, 5)) }
		stepTimes(harness, 1)
		stepAt(harness, 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
	end)

	it("keeps the meter locked on the tick that sets Asleep, and counts noise again from the next tick", function()
		local harness = wakeWithWalker()
		stepAt(harness, 60) -- Mia walks on the belly during this tick, but the meter is still locked
		expect(meter(harness)).toBe(0)
		stepAt(harness, 60.1)
		expect(meter(harness)).toBeGreaterThan(0)
	end)

	it("raises the meter again from 0 when a player walks on the belly after he is Asleep", function()
		local harness = wakeWithWalker()
		stepAt(harness, 60)
		for tickNumber = 1, 11 do
			stepAt(harness, 60 + tickNumber * 0.1)
		end
		-- 6 a second of walking noise minus the drain of 1.5 a second, for 11 ticks. The first tick can't drain from
		-- 0, so it keeps its whole 0.6: 0.6 + 10 x 0.45 = 5.1.
		expect(meter(harness)).toBeCloseTo(5.1, 1)
	end)

	it("can send the 60 warning again after the cycle", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { placed(sample(1, "Belly", true), Vector3.new(-45, 60, 5)) }
		stepTimes(harness, 10)
		expect(harness.warnings).toEqual({ 60 })
		-- Now he wakes and goes through the whole cycle.
		harness.state:SetAttribute("Meter", 100)
		stepTimes(harness, 1)
		stepAt(harness, 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		-- Four thuds from the boots (+20 each) take the meter from 0 past 60 again.
		harness.samples = { sample(1, "Meadow", false, "Boots") }
		for jump = 1, 4 do
			stepAt(harness, 60 + jump * 0.1)
		end
		expect(harness.warnings).toEqual({ 60, 60 })
	end)

	it("ends Asleep at 0 after one long tick that jumps over every event", function()
		local harness = wakeWithWalker()
		stepAt(harness, 1)
		stepAt(harness, 61)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBe(0)
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(nil)
	end)

	it("follows the clock, not the number of ticks", function()
		local harness = wakeWithWalker()
		-- 1000 ticks with the clock standing still: still the same second, still Awake.
		stepTimes(harness, 1000)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		-- One tick after the clock moved 15 seconds: HeavySleep.
		stepAt(harness, 15)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
	end)

	it("stops the timeline when Phase is put back to Asleep from outside", function()
		local harness = wakeWithWalker()
		stepAt(harness, 5)
		harness.state:SetAttribute("Meter", 0)
		harness.state:SetAttribute("Phase", "Asleep")
		harness.samples = {}
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 15)
		stepAt(harness, 5.1)
		-- GiantState holds no end time while he is Asleep.
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBeNil()
		stepAt(harness, 20)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		stepAt(harness, 70)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.state:GetAttribute("PhaseEndsAt")).never.toBe(START_CLOCK + 60)
	end)

	it("wakes a second time after the cycle, with a new clock and a new bounce", function()
		local harness = wakeWithWalker()
		stepAt(harness, 60)
		harness.state:SetAttribute("Meter", 100)
		harness.samples = { placed(sample(1, "Belly", false), Vector3.new(48, 60, 5)) }
		stepAt(harness, 200)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 200 + 15)
		expect(#harness.bounces).toBe(2)
		expect(harness.bounces[2].spotIndex).toBe(3)
		stepAt(harness, 200 + 15)
		expect(harness.state:GetAttribute("Phase")).toBe("HeavySleep")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(START_CLOCK + 200 + 60)
		stepAt(harness, 200 + 60)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBe(0)
	end)

	it("starts no timeline for a Phase set from outside", function()
		local harness = newHarness(40)
		harness.state:SetAttribute("Phase", "Awake")
		stepAt(harness, 100)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("PhaseEndsAt")).toBe(nil)
	end)
end)
