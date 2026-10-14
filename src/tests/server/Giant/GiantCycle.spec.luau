--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local GiantCycle = require(ServerScriptService.Server.Giant.GiantCycle)

-- The spec values (section 5, "The wake-up"). They are typed in here on purpose: if Config changes, these tests fail.
local WARNING_TIMES = { 1.0, 3.5, 6.0, 8.5, 11.0, 13.5 }
local LANDING_TIMES = { 2.5, 5, 7.5, 10, 12.5, 15 }

local function near(actual: number, expected: number)
	expect(math.abs(actual - expected) < 1e-6).toBe(true)
end

-- The time of tick number n is n x 0.1, never 0.1 added again and again (that drifts).
local function walk(tickCount: number): { GiantCycle.CycleEvent }
	local all: { GiantCycle.CycleEvent } = {}
	for tickNumber = 1, tickCount do
		for _, event in GiantCycle.eventsBetween((tickNumber - 1) * 0.1, tickNumber * 0.1) do
			table.insert(all, event)
		end
	end
	return all
end

local function kindsOf(events: { GiantCycle.CycleEvent }): { string }
	local kinds: { string } = {}
	for _, event in events do
		table.insert(kinds, `{event.kind}@{event.at}`)
	end
	return kinds
end

describe("GiantCycle.slams", function()
	it("there are 6 slams, numbered 1 to 6 in order", function()
		local slams = GiantCycle.slams()
		expect(#slams).toBe(6)
		for index, slam in slams do
			expect(slam.number).toBe(index)
		end
	end)

	it("the slams land at 2.5, 5, 7.5, 10, 12.5 and 15 seconds", function()
		local slams = GiantCycle.slams()
		expect(#slams).toBe(#LANDING_TIMES)
		for index, slam in slams do
			near(slam.landsAt, LANDING_TIMES[index])
		end
	end)

	it("the warnings come at 1.0, 3.5, 6.0, 8.5, 11.0 and 13.5 seconds", function()
		local slams = GiantCycle.slams()
		expect(#slams).toBe(#WARNING_TIMES)
		for index, slam in slams do
			near(slam.warnAt, WARNING_TIMES[index])
		end
	end)

	it("each slam lands 1.5 seconds after its warning", function()
		local slams = GiantCycle.slams()
		expect(#slams).toBe(6)
		for _, slam in slams do
			near(slam.landsAt - slam.warnAt, 1.5)
		end
	end)
end)

describe("GiantCycle.phaseAt", function()
	it("he is Awake at 0 with 15 seconds left", function()
		local phase, secondsLeft = GiantCycle.phaseAt(0)
		expect(phase).toBe("Awake")
		near(secondsLeft, 15)
	end)

	it("he is Awake at 7.5 seconds", function()
		local phase, secondsLeft = GiantCycle.phaseAt(7.5)
		expect(phase).toBe("Awake")
		near(secondsLeft, 7.5)
	end)

	it("he is still Awake at 14.99 with about 0.01 left", function()
		local phase, secondsLeft = GiantCycle.phaseAt(14.99)
		expect(phase).toBe("Awake")
		near(secondsLeft, 0.01)
	end)

	it("at exactly 15 seconds Heavy Sleep starts, with 45 left", function()
		local phase, secondsLeft = GiantCycle.phaseAt(15)
		expect(phase).toBe("HeavySleep")
		near(secondsLeft, 45)
	end)

	it("he is in Heavy Sleep at 59.99", function()
		local phase, secondsLeft = GiantCycle.phaseAt(59.99)
		expect(phase).toBe("HeavySleep")
		near(secondsLeft, 0.01)
	end)

	it("at exactly 60 seconds he is Asleep, with nothing left", function()
		local phase, secondsLeft = GiantCycle.phaseAt(60)
		expect(phase).toBe("Asleep")
		expect(secondsLeft).toBe(0)
	end)

	it("he stays Asleep after 60 seconds", function()
		local phase, secondsLeft = GiantCycle.phaseAt(100)
		expect(phase).toBe("Asleep")
		expect(secondsLeft).toBe(0)
	end)
end)

describe("GiantCycle.eventsBetween", function()
	it("0 to 1.0 holds only the first warning (a warning at the end of the window counts)", function()
		local events = GiantCycle.eventsBetween(0, 1.0)
		expect(#events).toBe(1)
		expect(events[1].kind).toBe("SlamWarning")
		expect(events[1].slam).toBe(1)
		near(events[1].at, 1.0)
		near(events[1].landsAt :: number, 2.5)
	end)

	it("1.0 to 1.1 holds nothing (an event exactly at the start doesn't count again)", function()
		expect(#GiantCycle.eventsBetween(1.0, 1.1)).toBe(0)
	end)

	it("a landing carries its slam number and time", function()
		local events = GiantCycle.eventsBetween(2.4, 2.5)
		expect(#events).toBe(1)
		expect(events[1].kind).toBe("SlamLanded")
		expect(events[1].slam).toBe(1)
		near(events[1].at, 2.5)
	end)

	it("14.9 to 15.0 holds the 6th landing first, then Heavy Sleep starting", function()
		local events = GiantCycle.eventsBetween(14.9, 15.0)
		expect(#events).toBe(2)
		expect(events[1].kind).toBe("SlamLanded")
		expect(events[1].slam).toBe(6)
		expect(events[2].kind).toBe("Phase")
		expect(events[2].phase).toBe("HeavySleep")
		near(events[2].at, 15)
		near(events[2].endsAt :: number, 60)
	end)

	it("59.9 to 60.0 holds the Asleep change with the meter back at 0", function()
		local events = GiantCycle.eventsBetween(59.9, 60.0)
		expect(#events).toBe(1)
		expect(events[1].kind).toBe("Phase")
		expect(events[1].phase).toBe("Asleep")
		near(events[1].at, 60)
		expect(events[1].meter).toBe(0)
	end)

	it("walking 0 to 61 seconds in 0.1 second ticks gives every event exactly once, in time order", function()
		local events = walk(610)
		expect(#events).toBe(14)
		local counts: { [string]: number } = { SlamWarning = 0, SlamLanded = 0, Phase = 0 }
		local lastTime = -1
		for _, event in events do
			counts[event.kind] += 1
			expect(event.at >= lastTime).toBe(true)
			lastTime = event.at
		end
		expect(counts.SlamWarning).toBe(6)
		expect(counts.SlamLanded).toBe(6)
		expect(counts.Phase).toBe(2)
	end)

	it("one long tick from 0 to 61 gives the same 14 events in the same order", function()
		local long = GiantCycle.eventsBetween(0, 61)
		expect(#long).toBe(14)
		expect(kindsOf(long)).toEqual(kindsOf(walk(610)))
	end)

	it("the 14 events come in the order warning, landing, ... with Heavy Sleep after the 6th landing", function()
		local events = GiantCycle.eventsBetween(0, 61)
		expect(events[11].kind).toBe("SlamWarning")
		expect(events[12].kind).toBe("SlamLanded")
		expect(events[12].slam).toBe(6)
		expect(events[13].phase).toBe("HeavySleep")
		expect(events[14].phase).toBe("Asleep")
	end)

	it("nothing happens after 60 seconds", function()
		expect(#GiantCycle.eventsBetween(60, 1000)).toBe(0)
	end)

	it("an empty window holds nothing", function()
		expect(#GiantCycle.eventsBetween(5, 5)).toBe(0)
	end)
end)
