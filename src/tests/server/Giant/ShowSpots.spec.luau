--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local ShowSpots = require(ServerScriptService.Server.Giant.ShowSpots)
local Zones = require(ServerScriptService.Server.Giant.Zones)

-- A little world far from the map. Every part is anchored and solid. The grass top is at ORIGIN.Y. The folders named
-- Giant and Nature sit under a folder named World, as in the real world.
local ORIGIN = Vector3.new(3000, 100, 3600)
local GRASS_TOP = ORIGIN.Y
local GARDEN_SIZE = Vector3.new(24, 20, 24)
local STEP = 4 -- studs between neighbouring spots (the plan: a 4-stud grid)

local made: { Instance } = {}

afterEach(function()
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end)

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- A part whose top face is at `top`, centred over `x`, `z`.
local function onGround(parent: Instance, name: string, size: Vector3, x: number, z: number, top: number): Part
	return part(parent, name, size, CFrame.new(x, top - size.Y / 2, z))
end

type Fake = { root: Folder, world: Folder, giant: Folder, nature: Folder }

local function fakeWorld(): Fake
	local root = newFolder("ShowSpotsFake", Workspace)
	table.insert(made, root)
	local world = newFolder("World", root)
	local giant = newFolder("Giant", world)
	local nature = newFolder("Nature", world)
	onGround(root, "Grass", Vector3.new(260, 4, 260), ORIGIN.X, ORIGIN.Z, GRASS_TOP).Material = Enum.Material.Grass
	return { root = root, world = world, giant = giant, nature = nature }
end

local function gardenBoxes(): { Zones.GardenBox }
	return { { index = 1, cframe = CFrame.new(ORIGIN + Vector3.new(0, 10, 0)), size = GARDEN_SIZE } }
end

local function build(zoneBoxes: { Zones.ZoneBox }?): { Vector3 }
	return ShowSpots.build(Workspace, gardenBoxes(), zoneBoxes or {}, {})
end

local function flatNear(spot: Vector3, x: number, z: number, radius: number): boolean
	return math.abs(spot.X - x) <= radius and math.abs(spot.Z - z) <= radius
end

describe("ShowSpots.build", function()
	it("puts spots only on dry grass", function()
		local fake = fakeWorld()
		local pond = onGround(fake.root, "Pond", Vector3.new(20, 4, 20), ORIGIN.X + 40, ORIGIN.Z + 40, GRASS_TOP + 1)
		pond.Material = Enum.Material.Water
		local spots = build()
		expect(#spots > 100).toBe(true)
		for _, spot in spots do
			expect(spot.Y).toBeCloseTo(GRASS_TOP, 1)
		end
	end)

	it("puts no spot in a garden, on the pond, on a lily pad or on the giant", function()
		local fake = fakeWorld()
		local pond = onGround(fake.root, "Pond", Vector3.new(20, 4, 20), ORIGIN.X + 40, ORIGIN.Z + 40, GRASS_TOP + 1)
		pond.Material = Enum.Material.Water
		onGround(fake.giant, "Boot", Vector3.new(20, 30, 20), ORIGIN.X - 40, ORIGIN.Z + 40, GRASS_TOP + 30)
		onGround(fake.nature, "LilyPad", Vector3.new(14, 0.4, 14), ORIGIN.X + 40, ORIGIN.Z - 40, GRASS_TOP + 0.4)
		local spots = build()
		expect(#spots > 100).toBe(true)
		local boxes = gardenBoxes()
		for _, spot in spots do
			expect(Zones.gardenAt(spot + Vector3.new(0, 10, 0), boxes)).toBeNil()
			expect(flatNear(spot, ORIGIN.X + 40, ORIGIN.Z + 40, 9)).toBe(false)
			expect(flatNear(spot, ORIGIN.X - 40, ORIGIN.Z + 40, 9)).toBe(false)
			expect(flatNear(spot, ORIGIN.X + 40, ORIGIN.Z - 40, 6)).toBe(false)
		end
	end)

	it("keeps neighbouring spots 4 studs apart", function()
		fakeWorld()
		local spots = build()
		expect(#spots > 100).toBe(true)
		local closest = math.huge
		for index, spot in spots do
			for other = index + 1, #spots do
				local distance = (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(spots[other].X, 0, spots[other].Z)).Magnitude
				closest = math.min(closest, distance)
			end
		end
		expect(closest).toBeCloseTo(STEP, 3)
	end)

	it("gives no spot on a 75-degree slope", function()
		local fake = fakeWorld()
		-- A wedge 6 studs along and 6 * tan(75 degrees) high: its one sloping face is 75 degrees steep.
		local slope = Instance.new("WedgePart")
		slope.Name = "Slope"
		slope.Anchored = true
		slope.Size = Vector3.new(24, 6 * math.tan(math.rad(75)), 6)
		slope.CFrame = CFrame.new(ORIGIN + Vector3.new(40, slope.Size.Y / 2, -40))
		slope.Parent = fake.root
		local spots = build()
		expect(#spots > 100).toBe(true)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { slope }
		for _, spot in spots do
			local hit = Workspace:Raycast(Vector3.new(spot.X, spot.Y + 60, spot.Z), Vector3.new(0, -70, 0), params)
			expect(hit).toBeNil()
		end
	end)

	it("gives no spot outside the Meadow zone box", function()
		fakeWorld()
		local box: Zones.ZoneBox = {
			zone = "Boots",
			cframe = CFrame.new(ORIGIN + Vector3.new(50, 10, 0)),
			size = Vector3.new(30, 60, 200),
		}
		local spots = build({ box })
		expect(#spots > 100).toBe(true)
		for _, spot in spots do
			expect(Zones.zoneAt(spot, { box })).toBe("Meadow")
		end
	end)
end)
