--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Call = Helpers.Call
type Harness = Helpers.Harness
local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local awayFromHome = Helpers.awayFromHome
local bank = Helpers.bank
local callsOf = Helpers.callsOf
local catch = Helpers.catch
local cleanUp = Helpers.cleanUp
local enter = Helpers.enter
local eventsNamed = Helpers.eventsNamed
local grab = Helpers.grab
local join = Helpers.join
local leave = Helpers.leave
local makePlayer = Helpers.makePlayer
local newHarness = Helpers.newHarness
local serverOf = Helpers.serverOf
local spawnCharacter = Helpers.spawnCharacter

afterEach(cleanUp)

describe("Analytics Slam", function()
	-- The one "Slam" call the harness got, with its fields read as text.
	local function onlySlam(harness: Harness): (Call, string, string)
		expect(#harness.calls).toBe(1)
		local call = harness.calls[1]
		expect(call.method).toBe("custom")
		expect(call.eventName).toBe("Slam")
		local fields = call.fields :: { [string]: string }
		return call, fields[FIELD_ONE], fields[FIELD_TWO]
	end

	it("logs 'Caught' with value 1 on the target, with the result and the server size", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[2].UserId, "Carrier", { all[2].UserId }, {})
		local call, result, size = onlySlam(harness)
		expect(call.player).toBe(all[2])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
		expect(size).toBe("2-4")
	end)

	it("logs 'Missed' with value 0 on the target when a slam aimed at a carrier caught nobody", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[3].UserId, "Carrier", {}, {})
		local call, result, size = onlySlam(harness)
		expect(call.player).toBe(all[3])
		expect(call.value).toBe(0)
		expect(result).toBe("Missed")
		expect(size).toBe("2-4")
	end)

	it("values the event at the number of players the slam caught", function()
		local harness, all = serverOf(4)
		harness.slammed:Fire(all[1].UserId, "Carrier", { all[1].UserId, all[3].UserId }, {})
		local call, result = onlySlam(harness)
		expect(call.value).toBe(2)
		expect(result).toBe("Caught")
	end)

	it("logs 'Empty' with value 0 on the player here longest when nobody was the target", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(nil, "Carrier", {}, {})
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(0)
		expect(result).toBe("Empty")
	end)

	it("picks the longest-in-server player for an 'Empty' slam by join time, not by place in GetPlayers", function()
		local harness = newHarness()
		local early = makePlayer(1, 1)
		local late = makePlayer(2, 2)
		harness.clock = 10
		enter(harness, early)
		harness.clock = 50
		enter(harness, late)
		harness.list = { late, early }
		table.clear(harness.calls)
		harness.slammed:Fire(nil, "Carrier", {}, {})
		local call = onlySlam(harness)
		expect(call.player).toBe(early)
	end)

	it("logs on the player here longest, with the same result, when the target has left", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(all[3].UserId, "Carrier", {}, {})
		local call, result, size = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(0)
		expect(result).toBe("Missed")
		expect(size).toBe("2-4")
	end)

	it("logs 'Caught' on the player here longest when the target left but the slam caught someone else", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(all[3].UserId, "Carrier", { all[2].UserId }, {})
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
	end)

	it("logs 'Caught' on the caught player when an empty-meadow slam caught a carrier who walked under it", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(nil, "Carrier", { all[3].UserId }, {})
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[3])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
	end)

	it("logs an empty-meadow slam that caught two on the first caught player", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(nil, "Carrier", { all[3].UserId, all[2].UserId }, {})
		local call = onlySlam(harness)
		expect(call.player).toBe(all[3])
		expect(call.value).toBe(2)
	end)

	it("skips a caught player who has left, and logs on the next caught player still here", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(nil, "Carrier", { all[3].UserId, all[2].UserId }, {})
		local call = onlySlam(harness)
		expect(call.player).toBe(all[2])
	end)

	it("logs 'Caught' on the player here longest when every player an empty-meadow slam caught has left", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(nil, "Carrier", { all[3].UserId }, {})
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
	end)

	for _, row in { { count = 1, size = "1" }, { count = 4, size = "2-4" }, { count = 5, size = "5-8" } } do
		local count, size = row.count, row.size
		it(`calls a server of {count} players "{size}"`, function()
			local harness, all = serverOf(count)
			harness.slammed:Fire(all[1].UserId, "Carrier", {}, {})
			local _call, _result, logged = onlySlam(harness)
			expect(logged).toBe(size)
		end)
	end

	it("logs nothing when there is no player in the server", function()
		local harness, all = serverOf(2)
		leave(harness, all[1])
		leave(harness, all[2])
		harness.slammed:Fire(nil, "Carrier", {}, {})
		harness.slammed:Fire(all[1].UserId, "Carrier", { all[2].UserId }, {})
		expect(harness.calls).toEqual({})
	end)

	it("logs one event for each slam", function()
		local harness, all = serverOf(2)
		harness.slammed:Fire(all[1].UserId, "Carrier", { all[1].UserId }, {})
		harness.slammed:Fire(all[2].UserId, "Carrier", {}, {})
		harness.slammed:Fire(nil, "Carrier", {}, {})
		expect(#harness.calls).toBe(3)
		expect((harness.calls[1].fields :: any)[FIELD_ONE]).toBe("Caught")
		expect((harness.calls[2].fields :: any)[FIELD_ONE]).toBe("Missed")
		expect((harness.calls[3].fields :: any)[FIELD_ONE]).toBe("Empty")
	end)

	it("goes on and logs the next slam when the service fails", function()
		local harness, all = serverOf(2)
		harness.failing.custom = true
		expect(function()
			harness.slammed:Fire(all[1].UserId, "Carrier", { all[1].UserId }, {})
		end).never.toThrow()
		harness.failing.custom = false
		harness.slammed:Fire(all[2].UserId, "Carrier", {}, {})
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[2])
		expect(#harness.warnings).toBe(1)
	end)

	it("logs nothing after stop", function()
		local harness, all = serverOf(2)
		harness.analytics:stop()
		harness.slammed:Fire(all[1].UserId, "Carrier", { all[1].UserId }, {})
		harness.slammed:Fire(nil, "Carrier", {}, {})
		expect(harness.calls).toEqual({})
	end)
end)

describe("Analytics PlayerCaught", function()
	it("logs with value 1 and the lost egg's rarity", function()
		local harness = newHarness()
		local mia = makePlayer(1, 4)
		enter(harness, mia)
		table.clear(harness.calls)
		grab(harness, mia, "Uncommon")
		table.clear(harness.calls)
		catch(harness, mia)
		local events = callsOf(harness, "custom", mia)
		expect(#events).toBe(1)
		expect(events[1].eventName).toBe("PlayerCaught")
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Uncommon")
		expect((events[1].fields :: any)[FIELD_TWO]).toBeNil()
	end)
end)

describe("Analytics when the service fails", function()
	it("goes on and still logs the other events of the same moment", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.failing.onboarding = true
		grab(harness, mia, "Common")
		expect(function()
			bank(harness, mia)
		end).never.toThrow()
		-- Step 3 failed, and EggHome was still logged.
		expect(#eventsNamed(harness, "EggHome", mia)).toBe(1)
	end)

	it("goes on with a check when the service fails, and logs the next event", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.failing.funnel = true
		expect(function()
			harness.analytics:check({ awayFromHome(mia, 11) })
		end).never.toThrow()
		harness.failing.funnel = false
		grab(harness, mia, "Common")
		expect(#callsOf(harness, "funnel", mia)).toBe(1)
		expect(callsOf(harness, "funnel", mia)[1].step).toBe(2)
	end)

	it("warns once with the method name, not for every failure", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.failing.custom = true
		for _ = 1, 3 do
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		expect(#harness.warnings).toBe(1)
		expect((string.find(harness.warnings[1], "LogCustomEvent", 1, true))).never.toBeNil()
	end)

	it("warns once for each method that fails", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		harness.failing.onboarding = true
		harness.failing.funnel = true
		join(harness, mia)
		spawnCharacter(mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		expect(#harness.warnings).toBe(2)
	end)
end)

describe("Analytics.stop", function()
	it("logs nothing after stop, whatever happens", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		table.clear(harness.calls)
		harness.analytics:stop()
		grab(harness, mia, "Common")
		bank(harness, mia)
		catch(harness, mia)
		harness.woke:Fire("Mia", 1, "Walking")
		harness.analytics:check({ awayFromHome(mia, 50) })
		enter(harness, makePlayer(2, 2))
		spawnCharacter(mia)
		expect(harness.calls).toEqual({})
	end)

	it("removes every connection it made, and can be called twice", function()
		local mia = makePlayer(1, 1)
		local harness = newHarness({ mia })
		expect(#harness.playerAdded:GetConnections()).toBe(1)
		expect(#harness.playerRemoving:GetConnections()).toBe(1)
		expect(#harness.grabbed:GetConnections()).toBe(1)
		expect(#harness.banked:GetConnections()).toBe(1)
		expect(#harness.caught:GetConnections()).toBe(1)
		expect(#harness.woke:GetConnections()).toBe(1)
		expect(#harness.slammed:GetConnections()).toBe(1)
		expect(#harness.saved:GetConnections()).toBe(1)
		expect(#harness.returned:GetConnections()).toBe(1)
		expect(#mia.CharacterAdded:GetConnections()).toBe(1)
		harness.analytics:stop()
		harness.analytics:stop()
		expect(#harness.playerAdded:GetConnections()).toBe(0)
		expect(#harness.playerRemoving:GetConnections()).toBe(0)
		expect(#harness.grabbed:GetConnections()).toBe(0)
		expect(#harness.banked:GetConnections()).toBe(0)
		expect(#harness.caught:GetConnections()).toBe(0)
		expect(#harness.woke:GetConnections()).toBe(0)
		expect(#harness.slammed:GetConnections()).toBe(0)
		expect(#harness.saved:GetConnections()).toBe(0)
		expect(#harness.returned:GetConnections()).toBe(0)
		expect(#mia.CharacterAdded:GetConnections()).toBe(0)
	end)

	it("removes a player's character connection when the player leaves", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		expect(#mia.CharacterAdded:GetConnections()).toBe(1)
		leave(harness, mia)
		expect(#mia.CharacterAdded:GetConnections()).toBe(0)
	end)
end)
