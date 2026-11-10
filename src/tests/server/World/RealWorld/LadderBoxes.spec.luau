--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
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

	-- The zones before this task, plain values (work/p3t7/before-zones.md, read in Edit 2026-11-09), now by nest name
	-- (plan 5 Task 12): the 16 meadow nests were V1's 8 Common spots, the boot-toe nests V1's Uncommon boot spots, and
	-- Rare egg 1 (Config.Nests.RareEggOne) V1's EggSpot_Rare_1. The other nests are new: this check leaves them alone.
	local EGG_SPOT_ZONES: { [string]: { string } } = {
		Meadow = {},
		Boots = {
			"Nest_BootToeInner_Left",
			"Nest_BootToeInner_Right",
			"Nest_BootToeOuter_Left",
			"Nest_BootToeOuter_Right",
		},
		Belly = { Config.Nests.RareEggOne },
	}
	for garden = 1, 8 do
		table.insert(EGG_SPOT_ZONES.Meadow, `Nest_Meadow_{garden}a`)
		table.insert(EGG_SPOT_ZONES.Meadow, `Nest_Meadow_{garden}b`)
	end
	local ROUTE_ZONES: { [string]: { string } } = {
		Belly = {
			"Belly_4",
			"BellyRampRight_4",
			"Belly_Crest",
			"Egg_Rare_1",
			"Egg_Rare_2",
			"Egg_Rare_3",
			"Egg_Rare_4",
			-- Plan 5 Task 17b: the arm and strap points down to the cuffs
			"ArmLeft_1",
			"ArmLeft_2",
			"ArmLeft_3",
			"ArmLeft_4",
			"ArmLeft_5",
			"ArmLeft_6",
			"ArmLeft_7",
			"ArmLeft_8",
			"ArmLeft_9",
			"ArmRight_0",
			"ArmRight_1",
			"ArmRight_2",
			"ArmRight_3",
			"ArmRight_4",
			"ArmRight_5",
			"ArmRight_6",
			"ArmRight_7",
			"ArmRight_8",
			"ArmRight_9",
			"ArmRight_10",
			"StrapLeft_Top",
			"StrapLeft_Foot",
			"StrapRight_Top",
			"StrapRight_Foot",
		},
		Boots = {
			"BellyRampLeft_1",
			"BellyRampLeft_2",
			"BellyRampLeft_3",
			"BellyRampRight_1",
			"BellyRampRight_2",
			"BellyRampRight_3",
			"Landing_Back",
			"LadderLeft_Top",
			"LadderRight_Top",
			"PlankLeft_In",
			"PlankLeft_Out",
			"PlankRight_In",
			"PlankRight_Out",
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
				if spot.name == Config.Nests.RareEggOne then
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
				if spot.name == Config.Nests.RareEggOne then
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
			local want = listedZone(EGG_SPOT_ZONES, spot.name, "new")
			for _, point in { spot.cframe.Position, base.Position } do
				if want ~= "new" and zoneOf(point) ~= want then
					table.insert(changed, `{spot.name} {want}>{zoneOf(point)}`)
				end
			end
		end
		-- route points are judged by the zone boxes only (8c ruling, 2026-11-10)
		local zoneBoxes = WorldIndex.readZones(realWorld()) :: { Zones.ZoneBox }
		for _, point in WorldIndex.readRoute(realWorld()) :: { WorldIndex.RoutePoint } do
			local short = string.gsub(point.name, "^RoutePoint_", "")
			local want = listedZone(ROUTE_ZONES, short, "Meadow")
			if string.find(short, "^Nest_") ~= nil then
				-- Plan 5 Task 17a: a nest point stands where its nest does; the nests with no V1 zone are new and left alone
				want = listedZone(EGG_SPOT_ZONES, short, "new")
			end
			local zone = Zones.zoneAt(point.position + UP, zoneBoxes)
			if want ~= "new" and zone ~= want then
				table.insert(changed, `{short} {want}>{zone}`)
			end
		end
		table.sort(changed)
		expect(table.concat(changed, "; ")).toBe("")
	end)
end)
