--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local Helpers = require(script.Parent.Helpers)
type Call = Helpers.Call
type FakePlayer = Helpers.FakePlayer
type Harness = Helpers.Harness
local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local bank = Helpers.bank
local callsOf = Helpers.callsOf
local cleanUp = Helpers.cleanUp
local enter = Helpers.enter
local grab = Helpers.grab
local leave = Helpers.leave
local makePlayer = Helpers.makePlayer
local newHarness = Helpers.newHarness
local serverOf = Helpers.serverOf

afterEach(cleanUp)

local FIELD_THREE = Enum.AnalyticsCustomFieldKeys.CustomField03.Name

-- Grab's order for an egg sent back: Carrying is cleared, then `returned` fires with the reason.
local function sendBack(harness: Harness, player: FakePlayer, why: string)
	local rarity = player.attributes.Carrying
	player.attributes.Carrying = nil
	harness.returned:Fire(player, rarity, why)
end

-- Catcher's order for a catch: the egg goes back first (`returned` with "Caught"), then `caught` fires.
local function catchForReal(harness: Harness, player: FakePlayer)
	local rarity = player.attributes.Carrying
	sendBack(harness, player, "Caught")
	harness.caught:Fire(player, rarity)
end

-- The director spends the player's free save in `zone`.
local function save(harness: Harness, player: FakePlayer, zone: Config.ZoneName)
	harness.saved:Fire(player.UserId, zone)
end

describe("Analytics EggHome", function()
	it("logs a Rare banked from garden 8 with value 1, the rarity and the garden number", function()
		local harness = newHarness()
		local mia = makePlayer(1, 8)
		enter(harness, mia)
		grab(harness, mia, "Rare")
		bank(harness, mia)
		local events = callsOf(harness, "custom", mia)
		expect(#events).toBe(1)
		expect(events[1].eventName).toBe("EggHome")
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Rare")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("8")
		expect(type((events[1].fields :: any)[FIELD_TWO])).toBe("string")
	end)

	it("logs one EggHome for every banked egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 3)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		local events = callsOf(harness, "custom", mia)
		expect(#events).toBe(2)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Common")
		expect((events[2].fields :: any)[FIELD_ONE]).toBe("Uncommon")
		expect((events[2].fields :: any)[FIELD_TWO]).toBe("3")
	end)
end)

describe("Analytics GiantWoke", function()
	it("logs once on the player who woke him, valued at the number of players, with the server size", function()
		local harness, all = serverOf(3)
		harness.woke:Fire("Bo", all[2].UserId, "Jump on him")
		expect(#harness.calls).toBe(1)
		local call = harness.calls[1]
		expect(call.method).toBe("custom")
		expect(call.player).toBe(all[2])
		expect(call.eventName).toBe("GiantWoke")
		expect(call.value).toBe(3)
		expect((call.fields :: any)[FIELD_ONE]).toBe("2-4")
		expect((call.fields :: any)[FIELD_TWO]).toBe("Jump on him")
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
			harness.woke:Fire("Name", all[1].UserId, "Walking")
			expect(harness.calls[1].value).toBe(count)
			expect((harness.calls[1].fields :: any)[FIELD_ONE]).toBe(size)
		end)
	end

	for _, cause in { "Walking", "Jump on him", "Jump off" } do
		it(`passes the director's cause "{cause}" through`, function()
			local harness, all = serverOf(2)
			harness.woke:Fire("Name", all[1].UserId, cause)
			expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe(cause)
		end)
	end

	it("logs on the player who joined first, with 'Waker left', when nobody is named", function()
		local harness, all = serverOf(3)
		harness.woke:Fire("", nil, "Waker left")
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[1])
		expect(harness.calls[1].value).toBe(3)
		expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe("Waker left")
	end)

	it("says 'Waker left' when nobody is named, whatever cause came with it", function()
		local harness, _all = serverOf(2)
		harness.woke:Fire("", nil, "Walking")
		expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe("Waker left")
	end)

	it("takes the player who joined first by join time, even when that is not first in GetPlayers", function()
		local harness = newHarness()
		local early = makePlayer(1, 1)
		local late = makePlayer(2, 2)
		harness.clock = 10
		enter(harness, early)
		harness.clock = 50
		enter(harness, late)
		-- GetPlayers happens to list the newest player first.
		harness.list = { late, early }
		table.clear(harness.calls)
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls[1].player).toBe(early)
	end)

	it("counts players already there when it starts in GetPlayers order, before anyone who joins later", function()
		local first = makePlayer(1, 1)
		local second = makePlayer(2, 2)
		local harness = newHarness({ second, first })
		local late = makePlayer(3, 3)
		harness.clock = 5
		enter(harness, late)
		table.clear(harness.calls)
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls[1].player).toBe(second)
	end)

	it("skips a player who has left when it looks for the one who has been there longest", function()
		local harness, all = serverOf(3)
		leave(harness, all[1])
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls[1].player).toBe(all[2])
		expect(harness.calls[1].value).toBe(2)
	end)

	it("logs 'Waker left' on the player who joined first when the named waker has left", function()
		local harness, all = serverOf(3)
		local gone = all[3]
		leave(harness, gone)
		harness.woke:Fire("Cy", gone.UserId, "Jump on him")
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[1])
		expect(harness.calls[1].value).toBe(2)
		expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe("Waker left")
	end)

	it("calls the waker 'New' when they have no Rare home, in the third slot", function()
		local harness, all = serverOf(2)
		harness.woke:Fire("Ann", all[1].UserId, "Walking")
		expect((harness.calls[1].fields :: any)[FIELD_THREE]).toBe("New")
	end)

	it("calls the waker 'Veteran' when they have a Rare home", function()
		local harness, all = serverOf(2)
		all[2].attributes.RareHome = true
		harness.woke:Fire("Bo", all[2].UserId, "Jump off")
		expect((harness.calls[1].fields :: any)[FIELD_THREE]).toBe("Veteran")
	end)

	it("says 'Nobody' in the third slot when nobody is named", function()
		local harness, _all = serverOf(2)
		harness.woke:Fire("", nil, "Waker left")
		expect((harness.calls[1].fields :: any)[FIELD_THREE]).toBe("Nobody")
	end)

	it("says 'Nobody' in the third slot when the named waker has left", function()
		local harness, all = serverOf(3)
		all[3].attributes.RareHome = true
		leave(harness, all[3])
		harness.woke:Fire("Cy", all[3].UserId, "Jump on him")
		expect((harness.calls[1].fields :: any)[FIELD_THREE]).toBe("Nobody")
	end)

	it("logs nothing when there is no player in the server", function()
		local harness, all = serverOf(2)
		leave(harness, all[1])
		leave(harness, all[2])
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls).toEqual({})
	end)

	it("logs again on the next wake", function()
		local harness, all = serverOf(2)
		harness.woke:Fire("Ann", all[1].UserId, "Walking")
		harness.woke:Fire("Bo", all[2].UserId, "Jump off")
		expect(#harness.calls).toBe(2)
		expect(harness.calls[1].player).toBe(all[1])
		expect(harness.calls[2].player).toBe(all[2])
	end)

	it("logs one event per wake, not one for each player", function()
		local harness, all = serverOf(5)
		harness.woke:Fire("Ann", all[1].UserId, "Walking")
		expect(#harness.calls).toBe(1)
	end)
end)

-- The "FreeSaveUsed" calls on a player, and the "FreeSaveResult" calls.
local function eventsNamed(harness: Harness, eventName: string, player: FakePlayer?): { Call }
	local found: { Call } = {}
	for _, call in callsOf(harness, "custom", player) do
		if call.eventName == eventName then
			table.insert(found, call)
		end
	end
	return found
end

describe("Analytics FreeSaveUsed", function()
	for _, row in
		{
			{ zone = "Boots", where = "Boots" },
			{ zone = "Belly", where = "Belly" },
			{ zone = "Beard", where = "Higher" },
			{ zone = "Nightcap", where = "Higher" },
		}
	do
		local zone, where = row.zone :: any, row.where
		it(`says where the save happened: {zone} is "{where}"`, function()
			local harness = newHarness()
			local mia = makePlayer(1, 1)
			enter(harness, mia)
			grab(harness, mia, "Rare")
			save(harness, mia, zone)
			local events = eventsNamed(harness, "FreeSaveUsed", mia)
			expect(#events).toBe(1)
			expect(events[1].value).toBe(1)
			expect((events[1].fields :: any)[FIELD_ONE]).toBe(where)
		end)
	end

	it("logs the Meadow as it is, so a save there shows on the chart", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Rare")
		save(harness, mia, "Meadow")
		expect((eventsNamed(harness, "FreeSaveUsed", mia)[1].fields :: any)[FIELD_ONE]).toBe("Meadow")
	end)

	for _, row in
		{
			{ eggsHome = 0, bucket = "0" },
			{ eggsHome = 1, bucket = "1" },
			{ eggsHome = 2, bucket = "2+" },
			{ eggsHome = 7, bucket = "2+" },
		}
	do
		local eggsHome, bucket = row.eggsHome, row.bucket
		it(`puts {eggsHome} eggs home in the "{bucket}" bucket`, function()
			local harness = newHarness()
			local mia = makePlayer(1, 1)
			enter(harness, mia)
			mia.attributes.EggsHome = eggsHome
			grab(harness, mia, "Rare")
			save(harness, mia, "Belly")
			expect((eventsNamed(harness, "FreeSaveUsed", mia)[1].fields :: any)[FIELD_TWO]).toBe(bucket)
		end)
	end

	it("names the rarity of the egg they carry in the third slot", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Rare")
		save(harness, mia, "Belly")
		expect((eventsNamed(harness, "FreeSaveUsed", mia)[1].fields :: any)[FIELD_THREE]).toBe("Rare")
	end)

	it("says 'None' in the third slot when they carry nothing", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		save(harness, mia, "Belly")
		local events = eventsNamed(harness, "FreeSaveUsed", mia)
		expect(#events).toBe(1)
		expect((events[1].fields :: any)[FIELD_THREE]).toBe("None")
	end)

	it("logs once for the player who was saved and for nobody else", function()
		local harness, all = serverOf(3)
		save(harness, all[2], "Boots")
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[2])
	end)

	it("logs nothing for a player who has left", function()
		local harness, all = serverOf(2)
		local gone = all[2]
		leave(harness, gone)
		save(harness, gone, "Belly")
		expect(harness.calls).toEqual({})
	end)
end)

describe("Analytics FreeSaveResult", function()
	-- A brand-new player carrying a Rare who has just been saved on the belly at clock 100.
	local function savedCarrier(): (Harness, FakePlayer)
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Rare")
		harness.clock = 100
		save(harness, mia, "Belly")
		return harness, mia
	end

	local function resultsOf(harness: Harness, player: FakePlayer): { Call }
		return eventsNamed(harness, "FreeSaveResult", player)
	end

	it("logs nothing yet right after the save", function()
		local harness, mia = savedCarrier()
		expect(#resultsOf(harness, mia)).toBe(0)
	end)

	it("logs 'Home' when the egg is banked", function()
		local harness, mia = savedCarrier()
		harness.clock = 130
		bank(harness, mia)
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Home")
	end)

	it("logs 'Woke him' when they are named as the waker", function()
		local harness, mia = savedCarrier()
		harness.clock = 112
		harness.woke:Fire("Player1", mia.UserId, "Walking")
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Woke him")
	end)

	it("does not close the result of a player who is not the waker", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		local bo = makePlayer(2, 2)
		enter(harness, mia)
		enter(harness, bo)
		grab(harness, mia, "Rare")
		save(harness, mia, "Belly")
		harness.woke:Fire("Player2", bo.UserId, "Jump on him")
		expect(#eventsNamed(harness, "FreeSaveResult", mia)).toBe(0)
		bank(harness, mia)
		expect((eventsNamed(harness, "FreeSaveResult", mia)[1].fields :: any)[FIELD_ONE]).toBe("Home")
	end)

	it("logs 'Caught' when a catch comes: the egg goes back first, then `caught` fires", function()
		local harness, mia = savedCarrier()
		catchForReal(harness, mia)
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Caught")
	end)

	it("logs 'Lost' when the egg goes back for any other reason", function()
		local harness, mia = savedCarrier()
		sendBack(harness, mia, "Lost")
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Lost")
	end)

	it("logs 'Lost' when they leave with the result still open and Banking's handler ran first", function()
		local harness, mia = savedCarrier()
		-- Banking sends the egg back as they leave, then Analytics hears them leave.
		sendBack(harness, mia, "Lost")
		leave(harness, mia)
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Lost")
	end)

	it("logs 'Lost' when they leave with the result still open and Analytics' handler ran first", function()
		local harness, mia = savedCarrier()
		leave(harness, mia)
		-- Banking sends the egg back after Analytics has already forgotten them.
		sendBack(harness, mia, "Lost")
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect((results[1].fields :: any)[FIELD_ONE]).toBe("Lost")
	end)

	it("values the result at the seconds since the save", function()
		local harness, mia = savedCarrier()
		harness.clock = 137.5
		bank(harness, mia)
		expect(resultsOf(harness, mia)[1].value).toBe(37.5)
	end)

	it("logs one result per save: the first outcome closes it and nothing later logs again", function()
		local harness, mia = savedCarrier()
		harness.woke:Fire("Player1", mia.UserId, "Walking")
		sendBack(harness, mia, "Lost")
		leave(harness, mia)
		expect(#resultsOf(harness, mia)).toBe(1)
		expect((resultsOf(harness, mia)[1].fields :: any)[FIELD_ONE]).toBe("Woke him")
	end)

	it("does not log a later egg that is banked after the result was closed", function()
		local harness, mia = savedCarrier()
		sendBack(harness, mia, "Lost")
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(#resultsOf(harness, mia)).toBe(1)
	end)

	it("opens no result for a save while carrying nothing", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		save(harness, mia, "Belly")
		grab(harness, mia, "Common")
		bank(harness, mia)
		sendBack(harness, mia, "Lost")
		harness.woke:Fire("Player1", mia.UserId, "Walking")
		leave(harness, mia)
		expect(#eventsNamed(harness, "FreeSaveUsed", mia)).toBe(1)
		expect(#eventsNamed(harness, "FreeSaveResult", mia)).toBe(0)
	end)

	it("lets a second save replace the open result", function()
		local harness, mia = savedCarrier()
		harness.clock = 150
		save(harness, mia, "Boots")
		harness.clock = 160
		bank(harness, mia)
		local results = resultsOf(harness, mia)
		expect(#results).toBe(1)
		expect(results[1].value).toBe(10)
	end)

	it("logs a result for each saved carrier, on their own player", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		local bo = makePlayer(2, 2)
		enter(harness, mia)
		enter(harness, bo)
		grab(harness, mia, "Rare")
		grab(harness, bo, "Rare")
		save(harness, mia, "Belly")
		save(harness, bo, "Belly")
		bank(harness, bo)
		sendBack(harness, mia, "Lost")
		expect((eventsNamed(harness, "FreeSaveResult", bo)[1].fields :: any)[FIELD_ONE]).toBe("Home")
		expect((eventsNamed(harness, "FreeSaveResult", mia)[1].fields :: any)[FIELD_ONE]).toBe("Lost")
	end)
end)
