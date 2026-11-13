--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Theme = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Theme)

local RANKS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- How bright a colour looks (the usual weights for red, green and blue).
local function brightness(color: Color3): number
	return color.R * 0.299 + color.G * 0.587 + color.B * 0.114
end

describe("Theme.rarity: one colour per rank (spec Rule 51)", function()
	it("has all five rank names", function()
		for _, rank in RANKS do
			expect(Theme.rarity[rank] ~= nil).toBe(true)
		end
		expect(Theme.rarity.Epic ~= nil).toBe(true)
	end)

	it("makes Epic purple, B05CFF (the style guide)", function()
		expect(Theme.rarity.Epic.main == Color3.fromHex("B05CFF")).toBe(true)
	end)

	it("makes Legendary gold, FFC93C (the style guide)", function()
		expect(Theme.rarity.Legendary.main == Color3.fromHex("FFC93C")).toBe(true)
	end)

	it("gives no two ranks the same main colour", function()
		for i, first in RANKS do
			for j = i + 1, #RANKS do
				local second = RANKS[j]
				local a = Theme.rarity[first]
				local b = Theme.rarity[second]
				-- a rank with no entry yet is the five-names test's failure, not this one's
				if a ~= nil and b ~= nil then
					expect(a.main ~= b.main).toBe(true)
				end
			end
		end
	end)

	it("makes light brighter than dark for every rank", function()
		for _, rank in RANKS do
			local look = Theme.rarity[rank]
			if look ~= nil then
				expect(brightness(look.light) > brightness(look.dark)).toBe(true)
			end
		end
	end)
end)
