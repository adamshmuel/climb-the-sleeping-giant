--!strict
-- The music button's two events (plan 7 Task 17; spec 7 section 10): "MusicOff" and "MusicOn", logged when the server
-- hears that a player changed their music. Value = whole minutes since they joined, rounded down. CustomField01 = the
-- server size, counted the way "GiantWoke" counts it. Step 2 adds the `musicToggled` dep to Analytics.start.
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
local FIELD_ONE = Helpers.FIELD_ONE
local cleanUp = Helpers.cleanUp
local eventsNamed = Helpers.eventsNamed
local fireMusic = Helpers.fireMusic
local serverOf = Helpers.serverOf

afterEach(cleanUp)

describe("Analytics music events", function()
	it("logs one MusicOff, value 3, when a player turns the music off 180 s after joining", function()
		local harness, all = serverOf(3)
		harness.clock = 180

		fireMusic(harness, all[1].UserId, false)

		local events = eventsNamed(harness, "MusicOff")
		expect(#events).toBe(1)
		expect(events[1].player).toBe(all[1])
		expect(events[1].value).toBe(3)
		expect((events[1].fields :: { [string]: string })[FIELD_ONE]).toBe("2-4")
		expect(#eventsNamed(harness, "MusicOn")).toBe(0)
	end)

	it("logs a MusicOn when the music goes back on", function()
		local harness, all = serverOf(1)
		harness.clock = 180

		fireMusic(harness, all[1].UserId, true)

		local events = eventsNamed(harness, "MusicOn")
		expect(#events).toBe(1)
		expect(events[1].player).toBe(all[1])
		expect(events[1].value).toBe(3)
		expect((events[1].fields :: { [string]: string })[FIELD_ONE]).toBe("1")
		expect(#eventsNamed(harness, "MusicOff")).toBe(0)
	end)

	it("rounds the minutes down: 179 s is value 2", function()
		local harness, all = serverOf(1)
		harness.clock = 179

		fireMusic(harness, all[1].UserId, false)

		expect(eventsNamed(harness, "MusicOff")[1].value).toBe(2)
	end)

	it("logs nothing for a UserId that is not in the server", function()
		local harness = serverOf(2)
		harness.clock = 180

		fireMusic(harness, 999, false)
		fireMusic(harness, 999, true)

		expect(#eventsNamed(harness, "MusicOff")).toBe(0)
		expect(#eventsNamed(harness, "MusicOn")).toBe(0)
	end)
end)
