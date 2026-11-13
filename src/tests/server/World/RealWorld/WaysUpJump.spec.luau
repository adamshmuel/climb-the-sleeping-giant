--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll, afterAll =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll, JestGlobals.afterAll
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WaysUpCheck = require(ServerScriptService.Server.World.WaysUpCheck)
local WalkAreaCheck = require(ServerScriptService.Server.World.WalkAreaCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Helpers = require(script.Parent.Helpers)
local NestRoute = require(script.Parent.NestRoute)
local WalkAreaFacts = require(ServerStorage.Tests.server.World.StuckScan.WalkAreaFacts)

-- The jump part of the ways-up check on the real world (plan 5 Task 18a Step 5; spec Rule 82, "No new way onto the
-- belly"): from every surface a player can stand on below the belly, a jump reaches no walk-area spot, no climbable part
-- and no nest. It only READS the world; the control briefly switches the two ThighGuards off and puts them back.
describe("the real world, no jump reaches the belly, a climb or a nest", function()
	local SLOPE_LIMIT, SPACING = 78, 2 -- degrees, studs (the same map as WaysUpWalk.spec)
	local SMALL: PathCheck.Area = { min = Vector3.new(-40, 24, -68), max = Vector3.new(40, 56, -30) }
	local WIDE: PathCheck.Area = { min = Vector3.new(-50, 24, -68), max = Vector3.new(50, 90, 60) }
	local BOOT_MIN_Z, BOOT_MAX_Z = -68, -60.4
	local CREASE = { Vector3.new(-16, 35.4, -42), Vector3.new(16, 35.4, -42) } -- the hip creases (Task 15d)
	local CREASE_REACH = 3 -- studs
	local GRID, MEADOW_GRID = 3, 4 -- studs between sample points on guard tops and on the meadow
	local NOT_LADDERS = { "BootLadder_Left", "BootLadder_Right", "BeardLadder", "CapLadder" }
	local LIMIT_LINES = 40 -- problem lines printed at most
	local NEST_ZONES = { Belly = true, Beard = true, Nightcap = true } -- the nests Rule 82 guards
	local ACCEPTED_NEAR = 0.5 -- studs
	-- Problems product accepted. The walk-area point (-6, 33.03, -52) is on LapPlank_Left.Deck; its spot is the left
	-- ramp top.
	local ACCEPTED: { { kind: string, position: Vector3 } } = {
		-- product, 2026-11-10: lands beside the left ramp top, no time saved
		{ kind = "walk area", position = Vector3.new(-6, 41.17, -42) },
	}

	local world: Instance
	local zoneBoxes: { Zones.ZoneBox }
	local options: PathCheck.Options
	local controlOptions: PathCheck.Options
	local map: PathCheck.WalkMap
	local controlMap: PathCheck.WalkMap
	local takenOut: { Instance } = {}
	local guards: { Instance } = {}

	local function isUnder(part: Instance, roots: { Instance }): boolean
		for _, root in roots do
			if part == root or part:IsDescendantOf(root) then
				return true
			end
		end
		return false
	end

	local function onBootTop(spot: PathCheck.Spot): boolean
		local at = spot.position
		return math.abs(at.X) >= 16 and math.abs(at.X) <= 30 and at.Z >= BOOT_MIN_Z and at.Z <= BOOT_MAX_Z
	end

	local function rules(isBelly: (PathCheck.Spot) -> boolean): WaysUpCheck.Rules
		return {
			isSource = onBootTop,
			isTakenOut = function(spot)
				return isUnder(spot.standsOn, takenOut)
			end,
			isBelly = isBelly,
		}
	end

	local function inBelly(spot: PathCheck.Spot): boolean
		return Zones.zoneAt(spot.position, zoneBoxes) == "Belly"
	end

	-- Sample points over the top of one guard part, by its shape (a wedge counts as a box, so more cautious).
	local function topPoints(part: BasePart, into: { Vector3 })
		local half = part.Size / 2
		local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
		for i = 0, 7 do
			local corner = part.CFrame:PointToWorldSpace(
				Vector3.new(
					if i % 2 == 0 then -half.X else half.X,
					if i // 2 % 2 == 0 then -half.Y else half.Y,
					if i // 4 == 0 then -half.Z else half.Z
				)
			)
			low, high = low:Min(corner), high:Max(corner)
		end
		for x = math.ceil(low.X / GRID) * GRID, high.X, GRID do
			for z = math.ceil(low.Z / GRID) * GRID, high.Z, GRID do
				local top = WalkAreaFacts.artTopUnder({ part }, x, z, high.Y + 0.01)
				if top ~= nil then
					table.insert(into, Vector3.new(x, top, z))
				end
			end
		end
	end

	-- The guard families' top points, by family name, and every guard top point in one list (the stands).
	local function guardTops(): ({ WaysUpCheck.JumpSurface }, { Vector3 })
		local families: { WaysUpCheck.JumpSurface } = {}
		local all: { Vector3 } = {}
		for _, root in guards do
			local points: { Vector3 } = {}
			for _, part in root:GetDescendants() do
				if part:IsA("BasePart") then
					topPoints(part, points)
				end
			end
			if root:IsA("BasePart") then
				topPoints(root, points)
			end
			table.insert(families, { name = root.Name, points = points })
			table.move(points, 1, #points, #all + 1, all)
		end
		return families, all
	end

	-- The surfaces a jump can start from: the meadow, the body, and each guard family's points that a jump from the
	-- meadow or the body reaches (a family left with none is dropped).
	local function buildSurfaces(families: { WaysUpCheck.JumpSurface }): { WaysUpCheck.JumpSurface }
		local surfaces: { WaysUpCheck.JumpSurface } = {}
		-- The meadow round him: the Terrain only, on a grid.
		local meadowParams = RaycastParams.new()
		meadowParams.FilterType = Enum.RaycastFilterType.Include
		meadowParams.FilterDescendantsInstances = { Workspace.Terrain }
		local meadow: { Vector3 } = {}
		for x = -70, 70, MEADOW_GRID do
			for z = -90, 60, MEADOW_GRID do
				local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), meadowParams)
				if hit ~= nil then
					table.insert(meadow, hit.Position)
				end
			end
		end
		table.insert(surfaces, { name = "meadow", points = meadow })
		-- The body: every spot a walk, climb or slide reaches from a boot top without the landing, below the belly.
		local reached = WaysUpCheck.bellyReached(
			map,
			rules(function()
				return true
			end),
			true
		)
		local body: { Vector3 } = {}
		for _, id in reached do
			local spot = map.spots[id]
			if not inBelly(spot) then
				table.insert(body, spot.position)
			end
		end
		table.insert(surfaces, { name = "boot tops, planks and body", points = body })
		local starts: { Vector3 } = table.clone(meadow)
		table.move(body, 1, #body, #starts + 1, starts)
		for _, family in families do
			local kept = WaysUpCheck.reachedByJump(starts, family.points)
			if #kept > 0 then
				table.insert(surfaces, 1, { name = family.name, points = kept })
			end
		end
		return surfaces
	end

	beforeAll(function()
		world = Helpers.realWorld()
		zoneBoxes = WorldIndex.loadZones(world)
		local walkSurfaces = (world :: any).WalkSurfaces :: Instance
		takenOut = {
			walkSurfaces:FindFirstChild("LapLanding") :: Instance,
			walkSurfaces:FindFirstChild("LapApron") :: Instance,
			walkSurfaces:FindFirstChild("BellyRamp_Left") :: Instance,
			walkSurfaces:FindFirstChild("BellyRamp_Right") :: Instance,
		}
		for _, name in
			{
				"SlideGuards",
				"ForeheadGuard",
				"RailGuard_Left",
				"RailGuard_Right",
				"ToeGuard_Left",
				"ToeGuard_Right",
				"RampEdgeGuards",
				"SteepGuards",
			}
		do
			table.insert(guards, walkSurfaces:FindFirstChild(name) :: Instance)
		end
		for _, name in { "LapLanding", "LapApron" } do
			table.insert(guards, (walkSurfaces:FindFirstChild(name) :: Instance):FindFirstChild("Guards") :: Instance)
		end
		for _, side in { "Left", "Right" } do
			for _, part in (walkSurfaces:FindFirstChild("LapPlank_" .. side) :: Instance):GetDescendants() do
				if part:IsA("BasePart") and string.find(part.Name, "Guard") ~= nil then
					table.insert(guards, part)
				end
			end
		end
		table.insert(guards, (world :: any).CaveSkirt)

		local function mapFor(area: PathCheck.Area): (PathCheck.Options, PathCheck.WalkMap)
			local built = PathCheck.defaults(Workspace)
			built.spacing, built.slopeAngle = SPACING, SLOPE_LIMIT
			built.boxIgnores = { takenOut[3], takenOut[4] }
			return built, PathCheck.buildMap(built, area)
		end
		options, map = mapFor(WIDE)
		-- The control: the same walk with the two ThighGuards switched off, then put back at once.
		local saved: { [BasePart]: { collide: boolean, query: boolean } } = {}
		for _, part in (world :: any).ThighGuards:GetDescendants() do
			if part:IsA("BasePart") then
				saved[part] = { collide = part.CanCollide, query = part.CanQuery }
				part.CanCollide, part.CanQuery = false, false
			end
		end
		local ok = pcall(function()
			controlOptions, controlMap = mapFor(SMALL)
		end)
		for part, was in saved do
			part.CanCollide, part.CanQuery = was.collide, was.query
		end
		expect(ok).toBe(true)
	end, 400000)

	afterAll(function()
		pcall(PathCheck.cleanup, options)
		pcall(PathCheck.cleanup, controlOptions)
	end)

	it("without the thigh guards the walk reaches the hip crease, so the check works", function()
		local reached = WaysUpCheck.bellyReached(
			controlMap,
			rules(function(spot)
				return (spot.position - CREASE[1]).Magnitude <= CREASE_REACH
					or (spot.position - CREASE[2]).Magnitude <= CREASE_REACH
			end),
			false
		)
		expect(#reached > 0).toBe(true)
	end)

	it("no jump from the body reaches a belly spot, a climbable part or a nest", function()
		local starts = WalkAreaFacts.startIds(world, map)
		local cuff = (world :: any).CuffWalk :: Instance
		local area = WalkAreaCheck.walkArea(map, starts, function(position)
			return Zones.zoneAt(position, zoneBoxes) == "Belly"
		end, function(spot)
			return spot.standsOn:IsDescendantOf(cuff)
		end)
		local spots: { Vector3 } = {}
		for _, id in area do
			table.insert(spots, map.spots[id].position)
		end
		local trusses: { BasePart } = {}
		for _, part in world:GetDescendants() do
			if part:IsA("TrussPart") then
				local ladder = false
				for _, name in NOT_LADDERS do
					local found = part:FindFirstAncestor(name)
					ladder = ladder or found ~= nil
				end
				if not ladder then
					table.insert(trusses, part)
				end
			end
		end
		local nests: { Vector3 } = {}
		local nestZones: { [string]: number } = {}
		for _, nest in NestRoute.nests() do
			local zone = Zones.zoneAt(nest.cframe.Position, zoneBoxes)
			if NEST_ZONES[zone] then
				table.insert(nests, nest.cframe.Position)
				nestZones[zone] = (nestZones[zone] or 0) + 1
			end
		end
		local families, guardPoints = guardTops()
		local stands: { Vector3 } = table.clone(guardPoints)
		for _, spot in map.spots do
			-- The landing, apron and belly ramps are the one way up already, so they are not stands to guard.
			if not isUnder(spot.standsOn, takenOut) then
				table.insert(stands, spot.position)
			end
		end
		local surfaces = buildSurfaces(families)
		local all = WaysUpCheck.jumpProblems(Workspace, {
			surfaces = surfaces,
			walkArea = spots,
			ignore = {},
			trusses = trusses,
			nests = nests,
			stands = stands,
		})
		local problems: { WaysUpCheck.Problem } = {}
		local accepted = 0
		for _, item in all do
			local skip = false
			for _, ok in ACCEPTED do
				skip = skip or (item.kind == ok.kind and (item.position - ok.position).Magnitude <= ACCEPTED_NEAR)
			end
			if skip then
				accepted += 1
			else
				table.insert(problems, item)
			end
		end
		local zoneText =
			`Belly {nestZones.Belly or 0}, Beard {nestZones.Beard or 0}, Nightcap {nestZones.Nightcap or 0}`
		local lines = {
			`{#problems} problems ({accepted} accepted); walk area {#spots} spots, {#trusses} climbables, {#nests} nests ({zoneText}), {#stands} stands, {#surfaces} surfaces`,
		}
		for index, item in problems do
			if index <= LIMIT_LINES then
				table.insert(lines, `{item.kind}: {item.detail}`)
			end
		end
		expect(if #problems == 0 then {} else lines).toEqual({})
	end)
end)
