--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Call = Helpers.Call
type FakePlayer = Helpers.FakePlayer
type Harness = Helpers.Harness
local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local FIELD_THREE = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local callsOf = Helpers.callsOf
local cleanUp = Helpers.cleanUp
local grab = Helpers.grab
local refill = Helpers.refill
local serverOf = Helpers.serverOf
local slide = Helpers.slide

afterEach(cleanUp)

-- Every custom event with this name, on any player.
local function eventsNamed(harness: Harness, eventName: string): { Call }
	local found: { Call } = {}
	for _, call in callsOf(harness, "custom") do
		if call.eventName == eventName then
			table.insert(found, call)
		end
	end
	return found
end

local function field(call: Call, key: string): string?
	return (call.fields :: { [string]: string })[key]
end

describe("Analytics refills and slides", function()
	it("logs one EggRefill with rank, band, size and value 1 on the first player to enter", function()
		local harness, all = serverOf(3)

		refill(harness, "Rare", 5)

		local events = eventsNamed(harness, "EggRefill")
		expect(#events).toBe(1)
		expect(events[1].player).toBe(all[1])
		expect(events[1].value).toBe(1)
		expect(field(events[1], FIELD_ONE)).toBe("Rare")
		expect(field(events[1], FIELD_TWO)).toBe("1–30 s")
		expect(field(events[1], FIELD_THREE)).toBe("2-4")
	end)

	it("puts the wait into the right band", function()
		local harness = serverOf(1)
		local cases: { { waited: number, band: string } } = {
			{ waited = 0, band = "0 s" },
			{ waited = 0.4, band = "0 s" },
			{ waited = 1, band = "1–30 s" },
			{ waited = 30, band = "1–30 s" },
			{ waited = 30.5, band = "over 30 s" },
			{ waited = 31, band = "over 30 s" },
		}
		local got: { string } = {}
		for _, case in cases do
			table.clear(harness.calls)
			refill(harness, "Common", case.waited)
			local events = eventsNamed(harness, "EggRefill")
			table.insert(got, `{case.waited}={field(events[1], FIELD_TWO)}`)
		end
		local want: { string } = {}
		for _, case in cases do
			table.insert(want, `{case.waited}={case.band}`)
		end
		expect(table.concat(got, "; ")).toBe(table.concat(want, "; "))
	end)

	it("logs a Common refill that never waited as 0 s and a Rare one that waited 31 as over 30 s", function()
		local harness = serverOf(1)

		refill(harness, "Common", 0)
		refill(harness, "Rare", 31)

		local events = eventsNamed(harness, "EggRefill")
		expect(#events).toBe(2)
		expect(`{field(events[1], FIELD_ONE)}/{field(events[1], FIELD_TWO)}`).toBe("Common/0 s")
		expect(`{field(events[2], FIELD_ONE)}/{field(events[2], FIELD_TWO)}`).toBe("Rare/over 30 s")
	end)

	it("logs the server size of 1, 3 and 6 players", function()
		local sizes: { string } = {}
		for _, count in { 1, 3, 6 } do
			local harness = serverOf(count)
			refill(harness, "Rare", 2)
			table.insert(sizes, `{count}={field(eventsNamed(harness, "EggRefill")[1], FIELD_THREE)}`)
		end
		expect(table.concat(sizes, "; ")).toBe("1=1; 3=2-4; 6=5-8")
	end)

	it("logs three lines for three refills", function()
		local harness = serverOf(2)

		refill(harness, "Common", 0)
		refill(harness, "Uncommon", 3)
		refill(harness, "Rare", 40)

		expect(#eventsNamed(harness, "EggRefill")).toBe(3)
	end)

	it("logs nothing for a refill with no players, and does not throw", function()
		local harness = serverOf(0)

		expect(function()
			refill(harness, "Rare", 5)
		end).never.toThrow()

		expect(#eventsNamed(harness, "EggRefill")).toBe(0)
	end)

	it("logs nothing after stop, for both events", function()
		local harness, all = serverOf(2)
		harness.analytics:stop()

		refill(harness, "Rare", 5)
		slide(harness, all[1].UserId, 1)

		expect(#eventsNamed(harness, "EggRefill")).toBe(0)
		expect(#eventsNamed(harness, "SlideOff")).toBe(0)
	end)

	it("logs a slide by a carrier as Carrying and First", function()
		local harness, all = serverOf(1)
		grab(harness, all[1], "Rare")
		table.clear(harness.calls)

		slide(harness, all[1].UserId, 1)

		local events = eventsNamed(harness, "SlideOff")
		expect(#events).toBe(1)
		expect(events[1].player).toBe(all[1])
		expect(events[1].value).toBe(1)
		expect(field(events[1], FIELD_ONE)).toBe("Carrying")
		expect(field(events[1], FIELD_TWO)).toBe("First")
	end)

	it("logs an empty-handed second slide as Empty and Second", function()
		local harness, all = serverOf(1)

		slide(harness, all[1].UserId, 2)

		local events = eventsNamed(harness, "SlideOff")
		expect(#events).toBe(1)
		expect(field(events[1], FIELD_ONE)).toBe("Empty")
		expect(field(events[1], FIELD_TWO)).toBe("Second")
	end)

	it("logs the 3rd and 5th slide as Later, one line per slide", function()
		local harness, all = serverOf(1)

		slide(harness, all[1].UserId, 3)
		slide(harness, all[1].UserId, 5)

		local events = eventsNamed(harness, "SlideOff")
		expect(#events).toBe(2)
		expect(field(events[1], FIELD_TWO)).toBe("Later")
		expect(field(events[2], FIELD_TWO)).toBe("Later")
	end)

	it("logs nothing for a slide by a UserId that is not in the server", function()
		local harness = serverOf(2)

		slide(harness, 999, 1)

		expect(#eventsNamed(harness, "SlideOff")).toBe(0)
	end)
end)
