--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Helpers = require(script.Parent.Helpers)
local LadderZone = require(script.Parent.LadderZone)
local realWorld = Helpers.realWorld

-- Plan 3 Task 7 (rules 36, 39, 40, 45): the ladder boxes (World.LadderBoxes) and the reshaped zone boxes, built by
-- tools/world/18-ladder-boxes-and-zones.luau. These tests only READ the real world.
describe("the real world, ladder boxes and zone boxes", function()
	local UP = Vector3.new(0, 3, 0) -- a player's root is about 3 studs above the surface
	local BEARD_FOOT_Y = 63 -- the beard ladder's foot is on the belly at (0, 63, -25) (Task 7 card, table B)
	local BOX_COUNT = 4 -- both boot ladders, the beard ladder and the cap ladder
	local TRUSS_STEP = 2 -- studs between the points up a ladder
	-- the grass at a boot ladder's foot is at y 2 (table B)
	local FOOT_GRASS_Y = 2

	-- The zones before this task, plain values (work/p3t7/before-zones.md, read in Edit 2026-11-09). The 16 V1 egg
	-- spots, and the route points that were not Meadow; every other route point (56 of 84) was Meadow.
	local EGG_SPOT_ZONES: { [string]: { string } } = {
		Meadow = {
			"EggSpot_Common_1",
			"EggSpot_Common_2",
			"EggSpot_Common_3",
			"EggSpot_Common_4",
			"EggSpot_Common_5",
			"EggSpot_Common_6",
			"EggSpot_Common_7",
			"EggSpot_Common_8",
		},
		Boots = { "EggSpot_Uncommon_1", "EggSpot_Uncommon_2", "EggSpot_Uncommon_3", "EggSpot_Uncommon_4" },
		Belly = { "EggSpot_Rare_1", "EggSpot_Rare_2", "EggSpot_Rare_3", "EggSpot_Rare_4" },
	}
	local ROUTE_ZONES: { [string]: { string } } = {
		Belly = {
			"Belly_4",
			"Belly_BandTop",
			"Belly_Crest",
			"Belly_KneeTop",
			"Egg_Rare_1",
			"Egg_Rare_2",
			"Egg_Rare_3",
			"Egg_Rare_4",
		},
		Boots = {
			"Belly_1",
			"Belly_2",
			"Belly_3",
			"Belly_AnkleTop",
			"Belly_BootStep",
			"Belly_KneeFoot",
			"Bridge4_Giant",
			"Bridge5_Giant",
			"Egg_Uncommon_1",
			"Egg_Uncommon_2",
			"Egg_Uncommon_3",
			"Egg_Uncommon_4",
			"Ramp_Left_Foot",
			"Ramp_Left_High",
			"Ramp_Left_Low",
			"Ramp_Left_Top",
			"Ramp_Right_Foot",
			"Ramp_Right_High",
			"Ramp_Right_Low",
			"Ramp_Right_Top",
		},
	}

	-- The zones up the beard and cap ladders, lowest point first (a point every 2 studs up the truss), read in Edit on
	-- 2026-11-09 with the zone boxes alone, before this task changed anything (code_lead, work/p3t7/7-scripts.md E).
	-- Belly_Path holds the 7 lowest beard points, so this also guards its removal.
	local TRUSS_ZONES: { [string]: { string } } = {
		BeardLadder = {
			"Belly",
			"Belly",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
		},
		CapLadder = {
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Beard",
			"Nightcap",
			"Nightcap",
		},
	}

	local function walkSurfaces(): any
		return (realWorld() :: any).WalkSurfaces
	end

	local function zoneOf(point: Vector3): string
		return LadderZone.climberZone(realWorld(), point)
	end

	local function mirror(point: Vector3): Vector3
		return Vector3.new(-point.X, point.Y, point.Z)
	end

	local function ladderBoxes(): { BasePart }
		local folder = realWorld():FindFirstChild("LadderBoxes")
		expect(folder).never.toBeNil()
		local boxes: { BasePart } = {}
		for _, child in (folder :: Instance):GetChildren() do
			if child:IsA("BasePart") then
				table.insert(boxes, child)
			end
		end
		return boxes
	end

	-- the ladders: the models in WalkSurfaces that hold a TrussPart named Climb
	local function ladderModels(): { Instance }
		local found: { Instance } = {}
		for _, child in walkSurfaces():GetChildren() do
			local climb = child:FindFirstChild("Climb")
			if climb ~= nil and climb:IsA("TrussPart") then
				table.insert(found, child)
			end
		end
		return found
	end

	-- points every 2 studs along a ladder's truss (its long axis is its local Z)
	local function trussPoints(ladderName: string): { Vector3 }
		local climb = walkSurfaces()[ladderName].Climb :: TrussPart
		local points: { Vector3 } = {}
		local half = climb.Size.Z / 2
		local along = -half
		while along <= half do
			table.insert(points, climb.CFrame:PointToWorldSpace(Vector3.new(0, 0, along)))
			along += TRUSS_STEP
		end
		table.sort(points, function(a, b)
			return a.Y < b.Y
		end)
		return points
	end

	local function stationPoint(ramp: string, index: number): Vector3?
		local piece = walkSurfaces()[ramp]:FindFirstChild(`Piece{index}`)
		if piece == nil then
			return nil
		end
		return (piece :: BasePart).Position + UP
	end

	local function listedZone(lists: { [string]: { string } }, name: string, default: string): string
		for zone, names in lists do
			if table.find(names, name) ~= nil then
				return zone
			end
		end
		return default
	end

	it("every ladder has exactly one ladder box, and every box names a ladder", function()
		local boxes = ladderBoxes()
		local named: { string } = {}
		for _, box in boxes do
			table.insert(named, tostring(box:GetAttribute("Ladder")))
		end
		table.sort(named)
		local ladders: { string } = {}
		for _, model in ladderModels() do
			table.insert(ladders, model.Name)
		end
		table.sort(ladders)
		expect(named).toEqual(ladders)
		expect(#ladders).toBe(BOX_COUNT)
	end)

	it(
		"the lap planks, landing, apron and ramp pieces 1 to 15 are Boots, and Rare egg 1 and its mirror are Belly",
		function()
			local walk = walkSurfaces()
			local points: { [string]: Vector3? } = {
				LapPlank_Left = walk.LapPlank_Left.Deck.Position + UP,
				LapPlank_Right = walk.LapPlank_Right.Deck.Position + UP,
				LapLanding = walk.LapLanding.Deck.Position + UP,
				LapApron = walk.LapApron.Deck.Position + UP,
			}
			for _, ramp in { "BellyRamp_Left", "BellyRamp_Right" } do
				for index = 1, 15 do
					points[`{ramp}.Piece{index}`] = stationPoint(ramp, index)
				end
			end
			local misses: { string } = {}
			for name, point in points do
				if point == nil or zoneOf(point) ~= "Boots" then
					table.insert(misses, `{name}={if point == nil then "missing" else zoneOf(point)}`)
				end
			end
			table.sort(misses)
			expect(table.concat(misses, " ")).toBe("")
			local spots = WorldIndex.readEggSpots(realWorld()) :: { WorldIndex.EggSpot }
			local rare1: Vector3? = nil
			for _, spot in spots do
				if spot.name == "EggSpot_Rare_1" then
					rare1 = spot.cframe.Position
				end
			end
			expect(rare1).never.toBeNil()
			expect({ egg = zoneOf(rare1 :: Vector3), mirror = zoneOf(mirror(rare1 :: Vector3)) }).toEqual({
				egg = "Belly",
				mirror = "Belly",
			})
		end
	)

	it(
		"each ramp piece 1 to 16 and each V1 belly route point up to the beard ladder foot has the zone of its mirror",
		function()
			local differs: { string } = {}
			for _, ramp in { "BellyRamp_Left", "BellyRamp_Right" } do
				for index = 1, 16 do
					local point = stationPoint(ramp, index)
					if point ~= nil and zoneOf(point) ~= zoneOf(mirror(point)) then
						table.insert(differs, `{ramp}.Piece{index} {zoneOf(point)}/{zoneOf(mirror(point))}`)
					end
				end
			end
			local spots = WorldIndex.readEggSpots(realWorld()) :: { WorldIndex.EggSpot }
			local rareY = 0
			for _, spot in spots do
				if spot.name == "EggSpot_Rare_1" then
					rareY = spot.cframe.Position.Y
				end
			end
			local route = WorldIndex.readRoute(realWorld()) :: { WorldIndex.RoutePoint }
			for _, point in route do
				local short = string.gsub(point.name, "^RoutePoint_", "")
				local floorY = point.position.Y
				if
					listedZone(ROUTE_ZONES, short, "Meadow") == "Belly"
					and floorY >= rareY - 1
					and floorY <= BEARD_FOOT_Y + 1
					and zoneOf(point.position + UP) ~= zoneOf(mirror(point.position + UP))
				then
					table.insert(differs, `{short} {zoneOf(point.position + UP)}/{zoneOf(mirror(point.position + UP))}`)
				end
			end
			table.sort(differs)
			expect(table.concat(differs, "; ")).toBe("")
		end
	)

	it("every point up the boot ladders is Boots, and the beard and cap ladders keep the zones they had", function()
		local misses: { string } = {}
		for _, name in { "BootLadder_Left", "BootLadder_Right" } do
			for index, point in trussPoints(name) do
				if zoneOf(point) ~= "Boots" then
					table.insert(misses, `{name}#{index}={zoneOf(point)}`)
				end
			end
		end
		for _, name in { "BeardLadder", "CapLadder" } do
			local want = TRUSS_ZONES[name]
			local points = trussPoints(name)
			if #points ~= #want then
				table.insert(misses, `{name} has {#points} points, not {#want}`)
			end
			for index, point in points do
				if zoneOf(point) ~= want[index] then
					table.insert(misses, `{name}#{index}={zoneOf(point)} not {want[index]}`)
				end
			end
		end
		expect(table.concat(misses, " ")).toBe("")
	end)

	it("the grass at each boot ladder's foot is Meadow with the zone boxes alone", function()
		expect(#ladderBoxes()).toBe(BOX_COUNT) -- the ladder boxes exist: this check is about the zone boxes beside them
		local zoneBoxes = WorldIndex.readZones(realWorld()) :: { Zones.ZoneBox }
		local zones: { string } = {}
		for _, name in { "BootLadder_Left", "BootLadder_Right" } do
			local points = trussPoints(name)
			local foot = if points[1].Y < points[#points].Y then points[1] else points[#points]
			table.insert(zones, Zones.zoneAt(Vector3.new(foot.X, FOOT_GRASS_Y, foot.Z), zoneBoxes))
		end
		expect(zones).toEqual({ "Meadow", "Meadow" })
	end)

	it("every V1 egg spot and route point keeps its zone", function()
		expect(#ladderBoxes()).toBe(BOX_COUNT) -- the ladder boxes exist: this check is about what they leave alone
		local changed: { string } = {}
		for _, spot in WorldIndex.readEggSpots(realWorld()) :: { WorldIndex.EggSpot } do
			local base = spot.model:FindFirstChild("Base") :: BasePart
			local want = listedZone(EGG_SPOT_ZONES, spot.name, "?")
			for _, point in { spot.cframe.Position, base.Position } do
				if zoneOf(point) ~= want then
					table.insert(changed, `{spot.name} {want}>{zoneOf(point)}`)
				end
			end
		end
		for _, point in WorldIndex.readRoute(realWorld()) :: { WorldIndex.RoutePoint } do
			local short = string.gsub(point.name, "^RoutePoint_", "")
			local want = listedZone(ROUTE_ZONES, short, "Meadow")
			if zoneOf(point.position + UP) ~= want then
				table.insert(changed, `{short} {want}>{zoneOf(point.position + UP)}`)
			end
		end
		table.sort(changed)
		expect(table.concat(changed, "; ")).toBe("")
	end)
end)
