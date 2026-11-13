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
local enter = Helpers.enter
local grab = Helpers.grab
local makePlayer = Helpers.makePlayer
local newHarness = Helpers.newHarness

afterEach(cleanUp)

-- The custom events with this name, on a player.
local function eventsNamed(harness: Harness, eventName: string, player: FakePlayer): { Call }
	local found: { Call } = {}
	for _, call in callsOf(harness, "custom", player) do
		if call.eventName == eventName then
			table.insert(found, call)
		end
	end
	return found
end

-- Grab's order for an egg sent back: Carrying is cleared, then `returned` fires with the reason.
local function sendBack(harness: Harness, player: FakePlayer, why: string)
	local rarity = player.attributes.Carrying
	player.attributes.Carrying = nil
	harness.returned:Fire(player, rarity, why)
end

describe("Analytics Unstuck", function()
	-- A brand-new player standing in the game, with nothing in their hands.
	local function emptyHanded(): (Harness, FakePlayer)
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		return harness, mia
	end

	it("logs one custom event with how, zone and Carrying", function()
		local harness, mia = emptyHanded()
		grab(harness, mia, "Rare")
		table.clear(harness.calls)

		harness.unstuck:Fire(mia, "Rescue", "Belly")

		local events = eventsNamed(harness, "Unstuck", mia)
		expect(#harness.calls).toBe(1)
		expect(#events).toBe(1)
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Rescue")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("Belly")
		expect((events[1].fields :: any)[FIELD_THREE]).toBe("Carrying")
	end)

	it("an empty-handed player's Unstuck logs Empty", function()
		local harness, mia = emptyHanded()

		harness.unstuck:Fire(mia, "Reset on giant", "Belly")

		local events = eventsNamed(harness, "Unstuck", mia)
		expect(#events).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Reset on giant")
		expect((events[1].fields :: any)[FIELD_THREE]).toBe("Empty")
	end)

	it("a Reset on the giant after a carrier's free save logs no FreeSaveResult", function()
		local harness, mia = emptyHanded()
		grab(harness, mia, "Rare")
		harness.clock = 100
		harness.saved:Fire(mia.UserId, "Belly")

		harness.unstuck:Fire(mia, "Reset on giant", "Belly")

		expect(#eventsNamed(harness, "Unstuck", mia)).toBe(1)
		expect(#eventsNamed(harness, "FreeSaveResult", mia)).toBe(0)
	end)

	it("a Loop home after a carrier's free save logs Unstuck, then FreeSaveResult Lost once", function()
		local harness, mia = emptyHanded()
		grab(harness, mia, "Rare")
		harness.clock = 100
		harness.saved:Fire(mia.UserId, "Belly")
		table.clear(harness.calls)

		harness.unstuck:Fire(mia, "Loop home", "Belly") -- Recovery tells first, while the egg is still carried
		sendBack(harness, mia, "Lost") -- then Grab puts the egg back

		local names: { string } = {}
		for _, call in callsOf(harness, "custom", mia) do
			table.insert(names, call.eventName :: string)
		end
		expect(names).toEqual({ "Unstuck", "FreeSaveResult" })
		local events = eventsNamed(harness, "Unstuck", mia)
		expect((events[1].fields :: any)[FIELD_THREE]).toBe("Carrying")
		local results = eventsNamed(harness, "FreeSaveResult", mia)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Lost")
	end)

	it("after stop, Unstuck logs nothing", function()
		local harness, mia = emptyHanded()
		table.clear(harness.calls)
		harness.unstuck:Fire(mia, "Rescue", "Belly")
		expect(#harness.calls).toBe(1) -- it listens until stop
		harness.analytics:stop()

		harness.unstuck:Fire(mia, "Rescue", "Belly")

		expect(#harness.calls).toBe(1)
	end)
end)
