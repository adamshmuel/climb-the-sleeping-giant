--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Zones = require(ServerScriptService.Server.Giant.Zones)

describe("Zones.isInside", function()
	-- A box 20 long (X) and 4 wide (Z), turned 45 degrees around Y, centred on the origin.
	local turned = CFrame.Angles(0, math.rad(45), 0)
	local size = Vector3.new(20, 10, 4)

	it("a point inside a turned box is inside it", function()
		-- 7 studs along the box's long side: inside the turned box, but at x = 4.95, z = -4.95,
		-- where the same box unturned would not reach (it is only 2 studs wide in Z)
		local point = turned:PointToWorldSpace(Vector3.new(7, 0, 0))
		expect(Zones.isInside(point, turned, size)).toBe(true)
		expect(Zones.isInside(point, CFrame.new(), size)).toBe(false)
	end)

	it("a point just outside a turned box is outside", function()
		-- 2.2 studs out sideways: the box is only 4 wide, so it ends at 2. Unturned, this point would be inside.
		local point = turned:PointToWorldSpace(Vector3.new(0, 0, 2.2))
		expect(Zones.isInside(point, turned, size)).toBe(false)
		expect(Zones.isInside(point, CFrame.new(), size)).toBe(true)
	end)

	it("a point on the edge of a box counts as inside", function()
		-- exactly on the face at x = 10, and exactly on the corner (10, 5, 2)
		expect(Zones.isInside(Vector3.new(10, 0, 0), CFrame.new(), size)).toBe(true)
		expect(Zones.isInside(Vector3.new(10, 5, 2), CFrame.new(), size)).toBe(true)
	end)
end)

-- Zone boxes for the tests: each 10 studs on every side, centred on the given point.
local function zoneBox(zone: string, centre: Vector3): Zones.ZoneBox
	return { zone = zone :: any, cframe = CFrame.new(centre), size = Vector3.new(10, 10, 10) }
end

describe("Zones.zoneAt", function()
	it("a point in no zone box is in the Meadow", function()
		local boxes = { zoneBox("Boots", Vector3.new(100, 0, 0)), zoneBox("Belly", Vector3.new(200, 0, 0)) }
		expect(Zones.zoneAt(Vector3.new(0, 0, 0), boxes)).toBe("Meadow")
		expect(Zones.zoneAt(Vector3.new(0, 0, 0), {})).toBe("Meadow")
	end)

	it("a point in the Belly box is on the Belly", function()
		local boxes = { zoneBox("Boots", Vector3.new(100, 0, 0)), zoneBox("Belly", Vector3.new(200, 0, 0)) }
		expect(Zones.zoneAt(Vector3.new(203, 1, -2), boxes)).toBe("Belly")
		expect(Zones.zoneAt(Vector3.new(97, 0, 0), boxes)).toBe("Boots")
	end)

	it("where zone boxes overlap, the higher zone wins", function()
		local here = Vector3.new(0, 0, 0)
		local function boxesFor(zones: { string }): { Zones.ZoneBox }
			local boxes = {}
			for _, zone in zones do
				table.insert(boxes, zoneBox(zone, here))
			end
			return boxes
		end
		expect(Zones.zoneAt(here, boxesFor({ "Boots", "Belly" }))).toBe("Belly")
		expect(Zones.zoneAt(here, boxesFor({ "Belly", "Boots" }))).toBe("Belly")
		expect(Zones.zoneAt(here, boxesFor({ "Belly", "Beard" }))).toBe("Beard")
		expect(Zones.zoneAt(here, boxesFor({ "Beard", "Belly" }))).toBe("Beard")
		expect(Zones.zoneAt(here, boxesFor({ "Boots", "Belly", "Beard", "Nightcap" }))).toBe("Nightcap")
		expect(Zones.zoneAt(here, boxesFor({ "Nightcap", "Beard", "Belly", "Boots" }))).toBe("Nightcap")
	end)
end)

-- Garden boxes for the tests: 10 studs on every side, centred on the given point.
local function gardenBox(index: number, centre: Vector3): Zones.GardenBox
	return { index = index, cframe = CFrame.new(centre), size = Vector3.new(10, 10, 10) }
end

describe("Zones.gardenAt", function()
	local gardens = {
		gardenBox(1, Vector3.new(0, 0, 0)),
		gardenBox(2, Vector3.new(50, 0, 0)),
		gardenBox(3, Vector3.new(100, 0, 0)),
		gardenBox(4, Vector3.new(150, 0, 0)),
	}

	it("a point in a garden box is in that garden", function()
		expect(Zones.gardenAt(Vector3.new(102, 3, -1), gardens)).toBe(3)
		expect(Zones.gardenAt(Vector3.new(-4, 0, 4), gardens)).toBe(1)
	end)

	it("a point in no garden box is in no garden", function()
		expect(Zones.gardenAt(Vector3.new(25, 0, 0), gardens)).toBeNil() -- between gardens 1 and 2
		expect(Zones.gardenAt(Vector3.new(0, 20, 0), gardens)).toBeNil() -- above garden 1
		expect(Zones.gardenAt(Vector3.new(0, 0, 0), {})).toBeNil()
	end)
end)

describe("Zones.locate", function()
	it("being in a garden wins over a zone box", function()
		-- a garden box (garden 2) overlapping a Boots box
		local gardens = { gardenBox(1, Vector3.new(0, 0, 0)), gardenBox(2, Vector3.new(50, 0, 0)) }
		local boxes = { zoneBox("Boots", Vector3.new(52, 0, 0)) }
		expect(Zones.locate(Vector3.new(51, 0, 0), boxes, gardens)).toEqual({ zone = "Meadow", garden = 2 })
	end)

	it("outside every garden, it gives the zone and no garden", function()
		local gardens = { gardenBox(1, Vector3.new(0, 0, 0)) }
		local boxes = { zoneBox("Boots", Vector3.new(100, 0, 0)), zoneBox("Belly", Vector3.new(200, 0, 0)) }
		expect(Zones.locate(Vector3.new(201, 0, 0), boxes, gardens)).toEqual({ zone = "Belly", garden = nil })
		expect(Zones.locate(Vector3.new(500, 0, 0), boxes, gardens)).toEqual({ zone = "Meadow", garden = nil })
	end)
end)

describe("Zones.higher", function()
	it("gives the higher of two zones, Meadow lowest and Nightcap highest", function()
		expect(Zones.higher("Meadow", "Boots")).toBe("Boots")
		expect(Zones.higher("Belly", "Boots")).toBe("Belly")
		expect(Zones.higher("Belly", "Beard")).toBe("Beard")
		expect(Zones.higher("Nightcap", "Beard")).toBe("Nightcap")
		expect(Zones.higher("Belly", "Belly")).toBe("Belly")
	end)
end)
