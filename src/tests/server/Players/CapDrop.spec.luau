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

-- Task 61n: a cap-to-cap fall is a fall with no jump that started on his cap, a cap tie or a tie's landing and ended
-- on his cap (spec 5, section 10: CapToCapFall). Its fields bucket the height, name the egg and the trip.
local function isCapToCap(drop: Drop): boolean
	local CapDrop = require(ServerScriptService.Server.Players.CapDrop)
	return CapDrop.isCapToCap(drop)
end

describe("CapDrop.isCapToCap", function()
	it("a fall with no jump that ends on the cap is a cap-to-cap fall", function()
		expect(isCapToCap(dropFor("Nightcap", "Nightcap", false, false))).toBe(true)
	end)

	it("a jump that ends on the cap is not", function()
		expect(isCapToCap(dropFor("Nightcap", "Nightcap", true, true))).toBe(false)
	end)

	it("a drop that ends on the pillow is not", function()
		expect(isCapToCap(dropFor("Nightcap", "Belly", false, false))).toBe(false)
	end)
end)

describe("CapDrop.capFallFields", function()
	local function fieldsOf(height: number, carrying: string?, trip: number)
		local CapDrop = require(ServerScriptService.Server.Players.CapDrop)
		return CapDrop.capFallFields(height, carrying, trip)
	end

	it("cap fall fields bucket the height, name the egg and the trip", function()
		expect(fieldsOf(3.9, nil, 1)).toEqual({ height = "under 4", egg = "none", trip = "trip 1" })
		expect(fieldsOf(4, "Gold", 3)).toEqual({ height = "4 to 10", egg = "Gold", trip = "trip 3" })
		expect(fieldsOf(10, nil, 9).height).toBe("10 to 20")
		expect(fieldsOf(25, nil, 12)).toEqual({ height = "20 and over", egg = "none", trip = "trip 10 and over" })
	end)
end)
