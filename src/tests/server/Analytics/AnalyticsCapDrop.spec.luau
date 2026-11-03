--!strict
-- The "CapDrop" analytics event's fields reach the dashboard as plain values (Task 61c; spec 5, section 10: CapDrop).
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local CapDrop = require(ServerScriptService.Server.Players.CapDrop)
local Helpers = require(script.Parent.Helpers)

local FIELD_ONE = Helpers.FIELD_ONE
local FIELD_TWO = Helpers.FIELD_TWO
local FIELD_THREE = Helpers.FIELD_THREE
local ENDINGS = { "pillow", "face", "shoulders", "belly" }
local REJECTED = { ",", '"', "'" } -- the characters Roblox refuses in a custom event field

afterEach(Helpers.cleanUp)

describe("The CapDrop event's fields", function()
	it("no CapDrop field holds a character Roblox rejects", function()
		local harness, players = Helpers.serverOf(1)
		local player = players[1] :: any
		for _, endedOn in ENDINGS do
			harness.analytics:capDrop(player, CapDrop.fields(false, false, false, endedOn))
		end
		local calls = Helpers.callsOf(harness, "custom", player)
		expect(#calls).toBe(#ENDINGS)
		for _, call in calls do
			expect(call.eventName).toBe("CapDrop")
			for _, value in call.fields :: { [string]: string } do
				for _, bad in REJECTED do
					expect(string.find(value, bad, 1, true) ~= nil).toBe(false)
				end
			end
		end
	end)

	it("all four endings arrive as plain values", function()
		local harness, players = Helpers.serverOf(1)
		local player = players[1] :: any
		for _, endedOn in ENDINGS do
			harness.analytics:capDrop(player, CapDrop.fields(false, false, false, endedOn))
		end
		harness.analytics:capDrop(player, CapDrop.fields(false, true, true, "belly"))
		local calls = Helpers.callsOf(harness, "custom", player)
		expect(#calls).toBe(#ENDINGS + 1)
		for index, endedOn in ENDINGS do
			local fields = calls[index].fields :: { [string]: string }
			expect(fields[FIELD_ONE]).toBe("walked off")
			expect(fields[FIELD_TWO]).toBe(endedOn)
			expect(fields[FIELD_THREE]).toBe("woke no - egg no")
		end
		local last = calls[#ENDINGS + 1].fields :: { [string]: string }
		expect(last[FIELD_THREE]).toBe("woke yes - egg yes")
	end)
end)

describe("The CapToCapFall event", function()
	it("capToCapFall logs CapToCapFall with its height, egg and trip, and no CapDrop", function()
		local harness, players = Helpers.serverOf(1)
		local player = players[1] :: any
		harness.analytics:capToCapFall(player, CapDrop.capFallFields(12, "Gold", 2))
		local calls = Helpers.callsOf(harness, "custom", player)
		expect(#calls).toBe(1)
		expect(calls[1].eventName).toBe("CapToCapFall")
		local fields = calls[1].fields :: { [string]: string }
		expect(fields[FIELD_ONE]).toBe("10 to 20")
		expect(fields[FIELD_TWO]).toBe("Gold")
		expect(fields[FIELD_THREE]).toBe("trip 2")
		for _, call in calls do
			expect(call.eventName ~= "CapDrop").toBe(true)
		end
	end)
end)
