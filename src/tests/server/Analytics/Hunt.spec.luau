--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Call = Helpers.Call
type Harness = Helpers.Harness
local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local FIELD_THREE = Helpers.FIELD_THREE
local cleanUp = Helpers.cleanUp
local leave = Helpers.leave
local serverOf = Helpers.serverOf

afterEach(cleanUp)

-- The "Slam" and "Bonked" events of the hunt (Rules 69 and 70).
describe("Analytics hunt", function()
	-- The one call the harness got, checked to be a custom event of that name.
	local function only(harness: Harness, eventName: string): Call
		expect(#harness.calls).toBe(1)
		local call = harness.calls[1]
		expect(call.method).toBe("custom")
		expect(call.eventName).toBe(eventName)
		return call
	end

	it("logs 'Caught' valued at the number caught, with the target kind in the third slot", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[2].UserId, "Carrier", { all[2].UserId, all[3].UserId }, {})
		local call = only(harness, "Slam")
		local fields = call.fields :: { [string]: string }
		expect(call.value).toBe(2)
		expect(fields[FIELD_ONE]).toBe("Caught")
		expect(fields[FIELD_TWO]).toBe("2-4")
		expect(fields[FIELD_THREE]).toBe("Carrier")
	end)

	it("logs 'Bonked' valued 0 when the slam only bonked", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[1].UserId, "No egg", {}, { all[3].UserId })
		local call = only(harness, "Slam")
		local fields = call.fields :: { [string]: string }
		expect(call.value).toBe(0)
		expect(fields[FIELD_ONE]).toBe("Bonked")
		expect(fields[FIELD_THREE]).toBe("No egg")
	end)

	it("logs 'Missed' when the slam had a target and hit nobody", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[1].UserId, "Carrier", {}, {})
		local call = only(harness, "Slam")
		local fields = call.fields :: { [string]: string }
		expect(fields[FIELD_ONE]).toBe("Missed")
		expect(fields[FIELD_THREE]).toBe("Carrier")
	end)

	it("logs 'Empty' when there was no target and nobody was hit", function()
		local harness = serverOf(3)
		harness.slammed:Fire(nil, "None", {}, {})
		local call = only(harness, "Slam")
		local fields = call.fields :: { [string]: string }
		expect(fields[FIELD_ONE]).toBe("Empty")
		expect(fields[FIELD_THREE]).toBe("None")
	end)

	it("logs on the target, else the first caught, else the first bonked, else the player here longest", function()
		local harness, all = serverOf(4)
		harness.slammed:Fire(all[3].UserId, "Carrier", { all[2].UserId }, { all[4].UserId })
		expect(only(harness, "Slam").player).toBe(all[3])
		table.clear(harness.calls)
		harness.slammed:Fire(nil, "Carrier", { all[4].UserId, all[2].UserId }, { all[3].UserId })
		expect(only(harness, "Slam").player).toBe(all[4])
		table.clear(harness.calls)
		harness.slammed:Fire(nil, "Carrier", {}, { all[3].UserId, all[2].UserId })
		expect(only(harness, "Slam").player).toBe(all[3])
		table.clear(harness.calls)
		harness.slammed:Fire(nil, "None", {}, {})
		expect(only(harness, "Slam").player).toBe(all[1])
		table.clear(harness.calls)
		leave(harness, all[3])
		table.clear(harness.calls)
		harness.slammed:Fire(all[3].UserId, "Carrier", {}, { all[3].UserId })
		expect(only(harness, "Slam").player).toBe(all[1])
	end)

	it("logs one 'Bonked' event per bonked player, valued 1, with the server size", function()
		local harness, all = serverOf(3)
		harness.bonked:Fire(all[2])
		local first = only(harness, "Bonked")
		expect(first.player).toBe(all[2])
		expect(first.value).toBe(1)
		expect((first.fields :: { [string]: string })[FIELD_ONE]).toBe("2-4")
		harness.bonked:Fire(all[3])
		expect(#harness.calls).toBe(2)
		expect(harness.calls[2].player).toBe(all[3])
		expect(harness.calls[2].eventName).toBe("Bonked")
	end)

	it("logs one 'Caught' Slam when the slam caught one player and bonked another", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[1].UserId, "Carrier", { all[1].UserId }, { all[2].UserId })
		local call = only(harness, "Slam")
		local fields = call.fields :: { [string]: string }
		expect(call.value).toBe(1)
		expect(fields[FIELD_ONE]).toBe("Caught")
		expect(fields[FIELD_THREE]).toBe("Carrier")
	end)

	it("logs nothing about a slam or a bonk once analytics is stopped", function()
		local harness, all = serverOf(3)
		harness.analytics:stop()
		harness.slammed:Fire(all[1].UserId, "Carrier", { all[2].UserId }, { all[3].UserId })
		harness.bonked:Fire(all[3])
		expect(harness.calls).toEqual({})
	end)
end)
