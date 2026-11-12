--!strict
-- Plan 3 Task 16: "WayUp" (which way up a player climbed) and "WakeWayUp" (the waker's last way up).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local Helpers = require(script.Parent.Helpers)
type FakePlayer = Helpers.FakePlayer
type Harness = Helpers.Harness
local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local FIELD_THREE = Helpers.FIELD_THREE
local WAY_UP_LADDER = Helpers.WAY_UP_LADDER
local callsOf = Helpers.callsOf
local cleanUp = Helpers.cleanUp
local enter = Helpers.enter
local grab = Helpers.grab
local leave = Helpers.leave
local makePlayer = Helpers.makePlayer
local newHarness = Helpers.newHarness
local sampleOf = Helpers.sampleOf
local serverOf = Helpers.serverOf

afterEach(cleanUp)

local LADDER_TOP = Helpers.WAY_UP_TOPS[1].top

-- One tick with this player at `position` in `zone`.
local function tick(harness: Harness, player: FakePlayer, position: Vector3, zone: Config.ZoneName)
	local sample = sampleOf(player, nil, position.X, position.Z, position.Y)
	sample.zone = zone
	harness.analytics:check({ sample })
end

-- The player stands in the meadow, then on the boot top at the ladder's top: one climb.
local function climb(harness: Harness, player: FakePlayer)
	tick(harness, player, Vector3.new(-50, 3, -60), "Meadow")
	tick(harness, player, LADDER_TOP, "Boots")
end

local function wayUpCalls(harness: Harness, player: FakePlayer): { Helpers.Call }
	local found = {}
	for _, call in callsOf(harness, "custom", player) do
		if call.eventName == "WayUp" then
			table.insert(found, call)
		end
	end
	return found
end

local function wakeCalls(harness: Harness): { Helpers.Call }
	local found = {}
	for _, call in callsOf(harness, "custom") do
		if call.eventName == "WakeWayUp" then
			table.insert(found, call)
		end
	end
	return found
end

describe("Analytics WayUp", function()
	it("logs one WayUp for one climb: the way up, the garden, and Empty", function()
		local harness = newHarness()
		local mia = makePlayer(1, 6)
		enter(harness, mia)
		climb(harness, mia)
		local events = wayUpCalls(harness, mia)
		expect(#events).toBe(1)
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe(WAY_UP_LADDER)
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("6")
		expect((events[1].fields :: any)[FIELD_THREE]).toBe("Empty")
	end)

	it("says Carrying when the climber carries an egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 2)
		enter(harness, mia)
		grab(harness, mia, "Common")
		climb(harness, mia)
		local events = wayUpCalls(harness, mia)
		expect(#events).toBe(1)
		expect((events[1].fields :: any)[FIELD_THREE]).toBe("Carrying")
	end)

	it("logs no second WayUp for walking on to the boot top and back", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		climb(harness, mia)
		tick(harness, mia, LADDER_TOP + Vector3.new(10, 0, 0), "Boots")
		tick(harness, mia, LADDER_TOP, "Boots")
		expect(#wayUpCalls(harness, mia)).toBe(1)
	end)

	it("logs a second WayUp for a second climb after the Meadow", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		climb(harness, mia)
		climb(harness, mia)
		expect(#wayUpCalls(harness, mia)).toBe(2)
	end)
end)

describe("Analytics WakeWayUp", function()
	it("logs the waker's last way up and the server size", function()
		local harness, all = serverOf(3)
		climb(harness, all[2])
		table.clear(harness.calls)
		harness.woke:Fire("Player2", all[2].UserId, "Noise")
		local events = wakeCalls(harness)
		expect(#events).toBe(1)
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe(WAY_UP_LADDER)
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("2-4")
	end)

	it("logs None for a waker who never climbed", function()
		local harness, all = serverOf(1)
		harness.woke:Fire("Player1", all[1].UserId, "Noise")
		local events = wakeCalls(harness)
		expect(#events).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("None")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("1")
	end)

	it("logs None when nobody is named, on the same player GiantWoke is logged on", function()
		local harness, all = serverOf(5)
		climb(harness, all[1])
		table.clear(harness.calls)
		harness.woke:Fire("Nobody", nil, "Noise")
		local events = wakeCalls(harness)
		expect(#events).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("None")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("5-8")
		local woke = {}
		for _, call in callsOf(harness, "custom") do
			if call.eventName == "GiantWoke" then
				table.insert(woke, call)
			end
		end
		expect(#woke).toBe(1)
		expect(events[1].player).toBe(woke[1].player)
	end)

	it("forgets a player's last way up when they leave", function()
		local harness, all = serverOf(2)
		climb(harness, all[1])
		leave(harness, all[1])
		enter(harness, all[1])
		table.clear(harness.calls)
		harness.woke:Fire("Player1", all[1].UserId, "Noise")
		expect((wakeCalls(harness)[1].fields :: any)[FIELD_ONE]).toBe("None")
	end)
end)
