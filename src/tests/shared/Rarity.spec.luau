--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Rarity = require(ReplicatedStorage.Shared.Rarity)

describe("Rarity.isRareOrRarer", function()
	it("is true for Rare", function()
		expect(Rarity.isRareOrRarer("Rare")).toBe(true)
	end)

	it("is false for Common", function()
		expect(Rarity.isRareOrRarer("Common")).toBe(false)
	end)

	it("is false for Uncommon", function()
		expect(Rarity.isRareOrRarer("Uncommon")).toBe(false)
	end)

	it("is false for a name that is not a rarity", function()
		expect(Rarity.isRareOrRarer("Diamond")).toBe(false)
		expect(Rarity.isRareOrRarer("")).toBe(false)
	end)

	it("is false for a rarity name in the wrong case", function()
		expect(Rarity.isRareOrRarer("rare")).toBe(false)
	end)
end)
