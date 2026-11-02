--!strict
-- Task 61d: the fields of the "CapDrop" analytics event (spec 5, "CapDrop"): how they dropped, whether it woke him,
-- whether they carried an egg, and where the fall ended (pillow, face, shoulders or belly). The module is required inside each test, so a missing module fails that test only.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)

type Fields = { how: string, woke: string, egg: string, endedOn: string }

local function fieldsFor(jumped: boolean, woke: boolean, carrying: boolean, endedOn: string): Fields
	local CapDrop = require(ServerScriptService.Server.Players.CapDrop)
	return CapDrop.fields(jumped, woke, carrying, endedOn)
end

describe("CapDrop.fields", function()
	it("a walk-off that did not wake him and carried nothing", function()
		expect(fieldsFor(false, false, false, "pillow")).toEqual({
			how = "walked off",
			woke = "no",
			egg = "no",
			endedOn = "pillow",
		})
	end)

	it("a jump that carried an egg", function()
		expect(fieldsFor(true, false, true, "shoulders")).toEqual({
			how = "jumped",
			woke = "no",
			egg = "yes",
			endedOn = "shoulders",
		})
	end)

	it("a fall that ended on his belly says belly", function()
		expect(fieldsFor(false, true, false, "belly").endedOn).toBe("belly")
	end)

	it("a drop that woke him says woke yes", function()
		expect(fieldsFor(false, true, false, "face")).toEqual({
			how = "walked off",
			woke = "yes",
			egg = "no",
			endedOn = "face",
		})
	end)
end)

-- The decision table of Task 61d: which drops puff and which ending they log. A drop is what the detector reports.
type Drop = { from: Config.ZoneName, to: Config.ZoneName, jumped: boolean, thudded: boolean }

local function dropFor(from: Config.ZoneName, to: Config.ZoneName, jumped: boolean, thudded: boolean): Drop
	return { from = from, to = to, jumped = jumped, thudded = thudded }
end

local function landing(drop: Drop, onPillow: boolean, position: Vector3): (boolean, string?)
	local CapDrop = require(ServerScriptService.Server.Players.CapDrop)
	return CapDrop.landing(drop, onPillow, position)
end

describe("CapDrop.landing", function()
	it("a walk-off ending in Belly on the pillow puffs and ends on the pillow", function()
		local puff, endedOn = landing(dropFor("Nightcap", "Belly", false, false), true, Vector3.new(-45.6, 54, 32))
		expect(puff).toBe(true)
		expect(endedOn).toBe("pillow")
	end)

	it("a walk-off ending in Belly off the pillow at z -4 puffs and ends on his shoulders", function()
		local puff, endedOn = landing(dropFor("Nightcap", "Belly", false, false), false, Vector3.new(28, 57.2, -4))
		expect(puff).toBe(true)
		expect(endedOn).toBe("shoulders")
	end)

	it("a walk-off ending in Belly off the pillow at z -26 puffs and ends on his belly", function()
		local puff, endedOn = landing(dropFor("Beard", "Belly", false, false), false, Vector3.new(-5.5, 60, -26))
		expect(puff).toBe(true)
		expect(endedOn).toBe("belly")
	end)

	it("a walk-off ending in Beard is quiet with no puff and ends on his face", function()
		local puff, endedOn = landing(dropFor("Nightcap", "Beard", false, false), false, Vector3.new(0, 90, 20))
		expect(puff).toBe(false)
		expect(endedOn).toBe("face")
	end)

	it("a jump from the cap onto the pillow has no puff and still ends on the pillow", function()
		local puff, endedOn = landing(dropFor("Nightcap", "Belly", true, true), true, Vector3.new(45.6, 54, 32))
		expect(puff).toBe(false)
		expect(endedOn).toBe("pillow")
	end)

	it("a drop that ends in the Meadow has no puff and is not a CapDrop", function()
		local puff, endedOn = landing(dropFor("Nightcap", "Meadow", false, true), false, Vector3.new(-60, 4, 32))
		expect(puff).toBe(false)
		expect(endedOn).toBe(nil)
	end)
end)
