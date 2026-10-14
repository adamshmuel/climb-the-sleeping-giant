--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Noise = require(ServerScriptService.Server.Giant.Noise)

describe("Noise.perSecond", function()
	it("standing still makes no noise", function()
		local noise =
			Noise.perSecond({ zone = "Belly", garden = nil, moving = false, tiptoe = false, carrying = "Rare" })
		expect(noise).toBe(0)
	end)

	it("walking in the meadow makes no noise", function()
		local noise = Noise.perSecond({ zone = "Meadow", garden = nil, moving = true, tiptoe = false, carrying = nil })
		expect(noise).toBe(0)
	end)

	it("carrying any egg in the meadow makes no noise", function()
		local function carryingInMeadow(rarity: Config.RarityName): number
			return Noise.perSecond({ zone = "Meadow", garden = nil, moving = true, tiptoe = false, carrying = rarity })
		end
		expect(carryingInMeadow("Common")).toBe(0)
		expect(carryingInMeadow("Uncommon")).toBe(0)
		expect(carryingInMeadow("Rare")).toBe(0)
	end)

	it("walking on the belly carrying a Rare makes 15 a second", function()
		local noise =
			Noise.perSecond({ zone = "Belly", garden = nil, moving = true, tiptoe = false, carrying = "Rare" })
		expect(noise).toBeCloseTo(15)
	end)

	it("Tiptoe on the belly makes 1.2 a second", function()
		local noise = Noise.perSecond({ zone = "Belly", garden = nil, moving = true, tiptoe = true, carrying = nil })
		expect(noise).toBeCloseTo(1.2)
	end)

	it("Tiptoe and a Rare on the belly make 3 a second", function()
		local noise = Noise.perSecond({ zone = "Belly", garden = nil, moving = true, tiptoe = true, carrying = "Rare" })
		expect(noise).toBeCloseTo(3)
	end)

	it("each zone has its own loudness", function()
		local function walkingIn(zone: Config.ZoneName): number
			return Noise.perSecond({ zone = zone, garden = nil, moving = true, tiptoe = false, carrying = nil })
		end
		expect(walkingIn("Boots")).toBeCloseTo(4)
		expect(walkingIn("Beard")).toBeCloseTo(8)
		expect(walkingIn("Nightcap")).toBeCloseTo(12)
	end)

	it("each egg makes its own extra noise", function()
		local function carryingOnBoots(rarity: Config.RarityName): number
			return Noise.perSecond({ zone = "Boots", garden = nil, moving = true, tiptoe = false, carrying = rarity })
		end
		expect(carryingOnBoots("Common")).toBeCloseTo(5)
		expect(carryingOnBoots("Uncommon")).toBeCloseTo(6)
		expect(carryingOnBoots("Rare")).toBeCloseTo(10)
	end)

	it("nothing counts inside a garden", function()
		-- a garden always reports the Meadow, but the rule must hold for any zone
		local noise = Noise.perSecond({ zone = "Belly", garden = 3, moving = true, tiptoe = false, carrying = "Rare" })
		expect(noise).toBe(0)
	end)
end)

describe("Noise.jumpBurst", function()
	it("a jump landing on the belly makes 30", function()
		expect(Noise.jumpBurst("Belly", nil)).toBeCloseTo(30)
	end)

	it("a jump landing in the meadow makes none", function()
		expect(Noise.jumpBurst("Meadow", nil)).toBe(0)
	end)

	it("a jump landing in a garden makes none", function()
		-- a garden always reports the Meadow, but the rule must hold for any zone
		expect(Noise.jumpBurst("Belly", 3)).toBe(0)
	end)

	it("a jump landing on the nightcap makes 60", function()
		expect(Noise.jumpBurst("Nightcap", nil)).toBeCloseTo(60)
	end)
end)
