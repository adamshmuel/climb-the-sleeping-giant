--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RecoveryRules = require(ServerScriptService.Server.Players.RecoveryRules)

local NOW = 100

describe("RecoveryRules.resetChoice", function()
	it("a Reset on the giant while he sleeps moves the player back", function()
		expect(RecoveryRules.resetChoice(true, "Asleep", {}, NOW)).toBe("MoveBack")
	end)

	it("a Reset on the giant in Heavy Sleep moves the player back", function()
		expect(RecoveryRules.resetChoice(true, "HeavySleep", {}, NOW)).toBe("MoveBack")
	end)

	it("a Reset on the giant while he's awake sends the player home", function()
		expect(RecoveryRules.resetChoice(true, "Awake", {}, NOW)).toBe("Home")
	end)

	it("a Reset off the giant sends the player home, asleep or awake", function()
		expect(RecoveryRules.resetChoice(false, "Asleep", {}, NOW)).toBe("Home")
		expect(RecoveryRules.resetChoice(false, "HeavySleep", {}, NOW)).toBe("Home")
		expect(RecoveryRules.resetChoice(false, "Awake", {}, NOW)).toBe("Home")
	end)

	it("the third move within 30 seconds sends the player home", function()
		expect(RecoveryRules.resetChoice(true, "Asleep", { NOW - 20, NOW - 10 }, NOW)).toBe("Home")
		expect(RecoveryRules.resetChoice(true, "Asleep", { NOW - 30, NOW - 10 }, NOW)).toBe("Home")
	end)

	it("a move from 31 seconds ago no longer counts", function()
		expect(RecoveryRules.resetChoice(true, "Asleep", { NOW - 31, NOW - 10 }, NOW)).toBe("MoveBack")
	end)
end)

describe("RecoveryRules.recent", function()
	it("keeps only the last 30 seconds of moves", function()
		local kept = RecoveryRules.recent({ NOW - 31, NOW - 30, NOW - 5 }, NOW)
		expect(kept).toEqual({ NOW - 30, NOW - 5 })
	end)
end)

describe("RecoveryRules.onGiant", function()
	it("every noise zone but the Meadow is on the giant", function()
		for _, zone in { "Boots", "Belly", "Beard", "Nightcap" } do
			expect(RecoveryRules.onGiant(zone :: any, false)).toBe(true)
		end
	end)

	it("the Meadow off the pillow isn't on the giant", function()
		expect(RecoveryRules.onGiant("Meadow", false)).toBe(false)
	end)

	it("the pillow counts as on the giant", function()
		expect(RecoveryRules.onGiant("Meadow", true)).toBe(true)
	end)
end)
