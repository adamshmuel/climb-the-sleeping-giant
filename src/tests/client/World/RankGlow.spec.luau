--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Client = StarterPlayer.StarterPlayerScripts.Client
local RankGlow = require(Client.World.RankGlow)

local GLOW_RANKS = { "Uncommon", "Rare", "Epic", "Legendary" }
local ALL_RANKS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local function closeTo(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.005 and math.abs(a.G - b.G) < 0.005 and math.abs(a.B - b.B) < 0.005
end

describe("RankGlow.fade", function()
	it("is 0 up to 55 studs, 0.5 at 65 and 1 from 75 studs", function()
		expect(RankGlow.fade(50)).toBe(0)
		expect(RankGlow.fade(55)).toBe(0)
		expect(RankGlow.fade(65)).toBeCloseTo(0.5, 5)
		expect(RankGlow.fade(75)).toBe(1)
		expect(RankGlow.fade(80)).toBe(1)
		expect(RankGlow.fade(500)).toBe(1)
	end)

	it("never falls as the distance grows and never jumps more than 0.06 in one stud", function()
		local previous = RankGlow.fade(0)
		local worstJump = 0
		local fell = false
		for distance = 1, 100 do
			local now = RankGlow.fade(distance)
			if now < previous then
				fell = true
			end
			worstJump = math.max(worstJump, now - previous)
			previous = now
		end
		expect(fell).toBe(false)
		expect(worstJump <= 0.06).toBe(true)
		expect(worstJump > 0).toBe(true)
	end)
end)

describe("RankGlow Common", function()
	it("has no glow, no strength, no colours and a see-through ring at every distance", function()
		expect(RankGlow.hasGlow("Common")).toBe(false)
		expect(RankGlow.strength("Common")).toBe(0)
		expect(RankGlow.colors("Common")).toBe(nil)
		expect(RankGlow.ringColor("Common", 1)).toBe(nil)
		expect(RankGlow.ringTransparency("Common", 50)).toBe(1)
		expect(RankGlow.ringTransparency("Common", 65)).toBe(1)
		expect(RankGlow.ringTransparency("Common", 80)).toBe(1)
	end)
end)

describe("RankGlow ranks above Common", function()
	it("every one of them has a glow", function()
		for _, rank in GLOW_RANKS do
			expect(RankGlow.hasGlow(rank :: any)).toBe(true)
		end
	end)

	it("strength is 0.104, 0.117, 0.124 and 0.124, never weaker than the rank below", function()
		expect(RankGlow.strength("Uncommon")).toBeCloseTo(0.104, 3)
		expect(RankGlow.strength("Rare")).toBeCloseTo(0.117, 3)
		expect(RankGlow.strength("Epic")).toBeCloseTo(0.124, 3)
		expect(RankGlow.strength("Legendary")).toBeCloseTo(0.124, 3)
		for index = 2, #ALL_RANKS do
			local below = RankGlow.strength(ALL_RANKS[index - 1] :: any)
			local this = RankGlow.strength(ALL_RANKS[index] :: any)
			expect(this >= below).toBe(true)
		end
	end)

	it("ring see-through for Rare is 1 at 50, about 0.9415 at 65 and 0.883 at 80", function()
		expect(RankGlow.ringTransparency("Rare", 50)).toBe(1)
		expect(RankGlow.ringTransparency("Rare", 65)).toBeCloseTo(0.9415, 3)
		expect(RankGlow.ringTransparency("Rare", 80)).toBeCloseTo(0.883, 3)
	end)
end)

describe("RankGlow.size", function()
	it("is twice the egg's height", function()
		expect(RankGlow.size(6.2)).toBeCloseTo(12.4, 5)
		expect(RankGlow.size(7)).toBeCloseTo(14, 5)
	end)
end)

describe("RankGlow.ringScale", function()
	it("has 12 rings, from full size down to 0.45, each smaller than the one before", function()
		expect(RankGlow.RING_COUNT).toBe(12)
		expect(RankGlow.ringScale(1)).toBeCloseTo(1, 5)
		expect(RankGlow.ringScale(12)).toBeCloseTo(0.45, 5)
		for index = 2, 12 do
			expect(RankGlow.ringScale(index) < RankGlow.ringScale(index - 1)).toBe(true)
		end
	end)
end)

describe("RankGlow colours", function()
	it("each rank has its own edge and centre, ring 1 is the edge and ring 12 the centre", function()
		local expected: { [string]: { string } } = {
			Uncommon = { "5BD45B", "E4FFDC" },
			Rare = { "3FA9FF", "E6F6FF" },
			Epic = { "B05CFF", "F3E3FF" },
			Legendary = { "FFC93C", "FFF6D6" },
		}
		for rank, hexes in expected do
			local colors = RankGlow.colors(rank :: any)
			expect(colors ~= nil).toBe(true)
			if colors then
				expect(closeTo(colors.edge, Color3.fromHex(hexes[1]))).toBe(true)
				expect(closeTo(colors.centre, Color3.fromHex(hexes[2]))).toBe(true)
			end
			local first = RankGlow.ringColor(rank :: any, 1)
			local last = RankGlow.ringColor(rank :: any, 12)
			expect(first ~= nil and closeTo(first, Color3.fromHex(hexes[1]))).toBe(true)
			expect(last ~= nil and closeTo(last, Color3.fromHex(hexes[2]))).toBe(true)
		end
	end)

	it("no two ranks share an edge colour (Rule 51)", function()
		for a = 1, #GLOW_RANKS do
			for b = a + 1, #GLOW_RANKS do
				local colorA = RankGlow.colors(GLOW_RANKS[a] :: any)
				local colorB = RankGlow.colors(GLOW_RANKS[b] :: any)
				expect(colorA ~= nil and colorB ~= nil and not closeTo(colorA.edge, colorB.edge)).toBe(true)
			end
		end
	end)
end)
