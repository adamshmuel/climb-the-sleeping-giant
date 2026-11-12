--!strict
-- "EggGrab" and "WakeRank" (plan 4 Task 12): the egg's rank on a grab, and the rank the waker carried when he woke.
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Call = Helpers.Call
type Harness = Helpers.Harness
local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local FIELD_THREE = Helpers.FIELD_THREE
local cleanUp = Helpers.cleanUp
local eventsNamed = Helpers.eventsNamed
local grab = Helpers.grab
local makePlayer = Helpers.makePlayer
local newHarness = Helpers.newHarness
local serverOf = Helpers.serverOf

afterEach(cleanUp)

describe("Analytics EggGrab", function()
	it("logs one on the grabber, valued 1, with the rank and the server size", function()
		local harness, all = serverOf(3)
		grab(harness, all[2], "Uncommon")
		local events = eventsNamed(harness, "EggGrab")
		expect(#events).toBe(1)
		expect(events[1].method).toBe("custom")
		expect(events[1].player).toBe(all[2])
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Uncommon")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("2-4")
	end)

	for _, row in
		{
			{ count = 1, size = "1" },
			{ count = 2, size = "2-4" },
			{ count = 4, size = "2-4" },
			{ count = 5, size = "5-8" },
			{ count = 8, size = "5-8" },
		}
	do
		local count, size = row.count, row.size
		it(`calls a server of {count} players "{size}"`, function()
			local harness, all = serverOf(count)
			grab(harness, all[1], "Common")
			expect((eventsNamed(harness, "EggGrab")[1].fields :: any)[FIELD_TWO]).toBe(size)
		end)
	end

	for _, rank in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		it(`says "{rank}" for a {rank} egg`, function()
			local harness, all = serverOf(1)
			grab(harness, all[1], rank :: any)
			expect((eventsNamed(harness, "EggGrab")[1].fields :: any)[FIELD_ONE]).toBe(rank)
		end)
	end

	it("logs one for every grab", function()
		local harness, all = serverOf(1)
		grab(harness, all[1], "Common")
		all[1].attributes.Carrying = nil
		grab(harness, all[1], "Rare")
		local events = eventsNamed(harness, "EggGrab")
		expect(#events).toBe(2)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Common")
		expect((events[2].fields :: any)[FIELD_ONE]).toBe("Rare")
	end)

	it("logs nothing for a grab by a player the module does not watch", function()
		local harness = newHarness()
		local stranger = makePlayer(9, 1)
		grab(harness, stranger, "Epic")
		expect(#eventsNamed(harness, "EggGrab")).toBe(0)
	end)
end)

local function wakeRankCalls(harness: Harness): { Call }
	return eventsNamed(harness, "WakeRank")
end

describe("Analytics WakeRank", function()
	it("logs the rank the waker carries, with the server size, valued 1, on the waker", function()
		local harness, all = serverOf(3)
		all[2].attributes.Carrying = "Epic"
		harness.woke:Fire("Bo", all[2].UserId, "Walking")
		local events = wakeRankCalls(harness)
		expect(#events).toBe(1)
		expect(events[1].method).toBe("custom")
		expect(events[1].player).toBe(all[2])
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Epic")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("2-4")
	end)

	it("says Legendary for a waker carrying a Legendary", function()
		local harness, all = serverOf(1)
		all[1].attributes.Carrying = "Legendary"
		harness.woke:Fire("Player1", all[1].UserId, "Jump on him")
		expect((wakeRankCalls(harness)[1].fields :: any)[FIELD_ONE]).toBe("Legendary")
	end)

	it("says None for an empty-handed waker", function()
		local harness, all = serverOf(2)
		harness.woke:Fire("Player1", all[1].UserId, "Walking")
		local events = wakeRankCalls(harness)
		expect(#events).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("None")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("2-4")
	end)

	it("says None when nobody is named, even if the player it is logged on carries an egg", function()
		local harness, all = serverOf(2)
		all[1].attributes.Carrying = "Epic"
		harness.woke:Fire("Nobody", nil, "Walking")
		local events = wakeRankCalls(harness)
		expect(#events).toBe(1)
		expect(events[1].player).toBe(all[1])
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("None")
	end)

	it("says None when the named waker has left", function()
		local harness, all = serverOf(2)
		all[1].attributes.Carrying = "Rare"
		harness.woke:Fire("Gone", 777, "Walking")
		expect((wakeRankCalls(harness)[1].fields :: any)[FIELD_ONE]).toBe("None")
	end)

	it("keeps the rank carried when he woke, even if the egg goes back right after", function()
		local harness, all = serverOf(1)
		all[1].attributes.Carrying = "Epic"
		harness.woke:Fire("Player1", all[1].UserId, "Walking")
		all[1].attributes.Carrying = nil
		expect((wakeRankCalls(harness)[1].fields :: any)[FIELD_ONE]).toBe("Epic")
	end)

	it("logs exactly one WakeRank for one wake-up, next to one GiantWoke", function()
		local harness, all = serverOf(2)
		all[1].attributes.Carrying = "Rare"
		harness.woke:Fire("Player1", all[1].UserId, "Walking")
		expect(#wakeRankCalls(harness)).toBe(1)
		expect(#eventsNamed(harness, "GiantWoke")).toBe(1)
	end)

	it("keeps the three GiantWoke breakdowns exactly as before", function()
		local harness, all = serverOf(3)
		all[2].attributes.Carrying = "Epic"
		harness.woke:Fire("Bo", all[2].UserId, "Jump on him")
		local woke = eventsNamed(harness, "GiantWoke")[1]
		expect(woke.value).toBe(3)
		expect((woke.fields :: any)[FIELD_ONE]).toBe("2-4")
		expect((woke.fields :: any)[FIELD_TWO]).toBe("Jump on him")
		expect((woke.fields :: any)[FIELD_THREE]).toBe("New")
	end)
end)
