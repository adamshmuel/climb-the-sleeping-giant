--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll, afterAll =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll, JestGlobals.afterAll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local Helpers = require(script.Parent.Helpers)
type Landing = Helpers.Landing
type StuckSpot = Helpers.StuckSpot
local CLOSED_SPOTS = Helpers.CLOSED_SPOTS
local LADDER_REACH_STEPS = Helpers.LADDER_REACH_STEPS
local NEST_REACH = Helpers.NEST_REACH
local closedBrokenConditions = Helpers.closedBrokenConditions
local format = Helpers.format
local rareBrokenConditions = Helpers.rareBrokenConditions
local unlistedStuck = Helpers.unlistedStuck
local ScanFacts = require(script.Parent.ScanFacts)
local giantModel = ScanFacts.giantModel
local namedProblems = ScanFacts.namedProblems
local stuckReport = ScanFacts.stuckReport
local rareFacts = ScanFacts.rareFacts
local PillowWayUp = require(script.Parent.PillowWayUp)
local closedFacts = ScanFacts.closedFacts
local WalkFacts = require(script.Parent.WalkFacts)
local WalkAreaFacts = require(script.Parent.WalkAreaFacts)
local walkTowardCave = WalkFacts.walkTowardCave
local ladderEndSpots = WalkFacts.ladderEndSpots
local hasClimbLink = WalkFacts.hasClimbLink
local canWalk = WalkFacts.canWalk
local spotsNearNest = WalkFacts.spotsNearNest
local sortedNames = WalkFacts.sortedNames

local GiantPlaces = require(script.Parent.GiantPlaces)
local WaysUpRoutes = require(script.Parent.WaysUpRoutes)
local SCAN_TIMEOUT_MS = GiantPlaces.SCAN_TIMEOUT_MS
local UNDER_LEFT_ARMREST = GiantPlaces.UNDER_LEFT_ARMREST
local UNDER_RIGHT_ARMREST = GiantPlaces.UNDER_RIGHT_ARMREST
local FRONT_OF_CHAIR = GiantPlaces.FRONT_OF_CHAIR
local NEAR_A_POINT = GiantPlaces.NEAR_A_POINT
local LANDING_RAY_ABOVE = GiantPlaces.LANDING_RAY_ABOVE
local LANDING_RAY_LENGTH = GiantPlaces.LANDING_RAY_LENGTH
local BEARD_FOOT_SPOTS = GiantPlaces.BEARD_FOOT_SPOTS
local BEARD_FOOT_RADIUS = GiantPlaces.BEARD_FOOT_RADIUS
local HUMP_TOPS = GiantPlaces.HUMP_TOPS
local HUMP_REACH = GiantPlaces.HUMP_REACH
local BRIM_NESTS = GiantPlaces.BRIM_NESTS
local SIDE_NESTS = GiantPlaces.SIDE_NESTS
local FIXED_PLACES = GiantPlaces.FIXED_PLACES
local FIXED_PLACE_SPOTS_SHOWN = GiantPlaces.FIXED_PLACE_SPOTS_SHOWN
local CAVE_TRAP_START = GiantPlaces.CAVE_TRAP_START
local CAVE_HUMP_XS = GiantPlaces.CAVE_HUMP_XS
local CAVE_HUMP_Y = GiantPlaces.CAVE_HUMP_Y
local CAVE_HUMP_Z = GiantPlaces.CAVE_HUMP_Z
local CAVE_LEDGE_LEFT = GiantPlaces.CAVE_LEDGE_LEFT
local CAVE_LEDGE_RIGHT = GiantPlaces.CAVE_LEDGE_RIGHT
local CAVE_HUMP_TURNS = GiantPlaces.CAVE_HUMP_TURNS
local CAVE_LEDGE_TURNS = GiantPlaces.CAVE_LEDGE_TURNS
local CAVE_LEDGE_LEFT_HEADING = GiantPlaces.CAVE_LEDGE_LEFT_HEADING
local CAVE_LEDGE_RIGHT_HEADING = GiantPlaces.CAVE_LEDGE_RIGHT_HEADING
local RARE_SPOTS = GiantPlaces.RARE_SPOTS
local scanArea = GiantPlaces.scanArea

-- Spec Rule 22, "Accepted for now: the beard wedge": the exception stays one named spot and never joins the rare list.
describe("the accepted-for-now list", function()
	it("holds only the beard wedge, and it is not on the rare list", function()
		expect(#Helpers.ACCEPTED_FOR_NOW).toBe(1)
		local wedge = Helpers.ACCEPTED_FOR_NOW[1]
		expect(wedge.name).toBe("Beard wedge")
		expect(wedge.position).toEqual(Vector3.new(-6.8, 81.5, -11))
		expect(wedge.laterSpec).toBe("Launch polish: Beard wedge")
		for _, spot in RARE_SPOTS do
			expect((spot.position - wedge.position).Magnitude > Helpers.RARE_MATCH).toBe(true)
		end
	end)
end)

-- Spec Rule 22, "Map-only stops at the steep layer's foot": exactly these 6, apart from the rare spots and the wedge.
describe("the map-only stops list", function()
	it("holds the 6 named spots, apart from the rare spots and the wedge", function()
		local names: { string } = {}
		for _, stop in Helpers.MAP_ONLY_STOPS do
			table.insert(names, stop.name)
			expect((stop.position - Helpers.ACCEPTED_FOR_NOW[1].position).Magnitude > Helpers.MAP_ONLY_RADIUS).toBe(
				true
			)
			for _, spot in RARE_SPOTS do
				expect((spot.position - stop.position).Magnitude > Helpers.MAP_ONLY_RADIUS).toBe(true)
			end
		end
		expect(names).toEqual({ "R-35", "R-33", "L-27", "L-16", "LCuff", "RCuff" })
	end)
end)

describe("the stuck scan on the real world", function()
	local world: Instance
	local options: PathCheck.Options
	local landings: { Landing } = {}
	local area: PathCheck.Area
	local map: PathCheck.WalkMap
	local stuck: { { id: number, position: Vector3, standsOn: BasePart } } = {}
	local stuckIds: { [number]: boolean } = {}
	local landingExits: { number } = {} -- the walk-map spot nearest each landing spot
	local exits: { number } = {} -- the landing exits plus the meadow ground on the area's outer edge
	local edgeExits: { number } = {}
	local buildAndSearchSeconds = 0

	-- Builds the walk map once for all the tests (it takes tens of seconds) and finds the stuck spots.
	beforeAll(function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		world = found :: Instance
		landings = WorldIndex.loadLandingSpots(world)
		area = scanArea(giantModel(world), landings, Config.Stuck.ScanMargin)

		-- The two ramp planks are left out of the body check: a player steps on or off a ramp foot over its edge,
		-- which the body box touches by design (the same as the route test in RealWorld.spec).
		options = PathCheck.defaults(Workspace)
		options.boxIgnores = {
			(world :: any).WalkSurfaces.BootRamp.Ramp_Walk,
			(world :: any).WalkSurfaces.RightBootRamp.Ramp_Walk,
		}

		local started = os.clock()
		map = PathCheck.buildMap(options, area)
		for _, landing in landings do
			local id = PathCheck.nearestSpot(map, landing.position, 2 * map.spacing)
			if id ~= nil then
				table.insert(landingExits, id)
			end
		end
		-- The open meadow on the area's outer edge is a Meadow exit: the world goes on past it (spec, "Meadow exit"). Only
		-- the Terrain counts, not the sock, the teacup or a bridge that happen to cross the edge.
		edgeExits = PathCheck.edgeSpots(map, { Workspace.Terrain })
		for _, id in landingExits do
			table.insert(exits, id)
		end
		for _, id in edgeExits do
			table.insert(exits, id)
		end
		stuck = PathCheck.stuckSpots(map, exits)
		buildAndSearchSeconds = os.clock() - started
		for _, spot in stuck do
			stuckIds[spot.id] = true
		end
	end, SCAN_TIMEOUT_MS)

	afterAll(function()
		if options ~= nil then
			pcall(PathCheck.cleanup, options) -- takes the body probe out of the Workspace, whatever the result
		end
	end)

	it("every landing spot has a walk-map spot within two grid steps", function()
		for _, landing in landings do
			local id = PathCheck.nearestSpot(map, landing.position, 2 * map.spacing)
			if id == nil then
				error(
					`LandingSpot_{landing.index} at {format(landing.position)} has no walk-map spot within two grid steps`,
					0
				)
			end
		end
		expect(#landingExits).toBe(#landings)
	end)

	it("the real options carry the meadow ground, and a fake world's carry none", function()
		expect(options.terrain).toBe(Workspace.Terrain)
		local fake = Instance.new("WorldModel")
		expect(PathCheck.defaults(fake).terrain).toBeNil()
		fake:Destroy()
	end)

	it("no spot inside the meadow ground under his chair", function()
		local named: { [string]: Vector3 } = {
			["under the left armrest"] = UNDER_LEFT_ARMREST,
			["under the right armrest"] = UNDER_RIGHT_ARMREST,
			["the front of the chair"] = FRONT_OF_CHAIR,
		}
		local problems: { string } = {}
		for name, point in named do
			local fits, inTheWay = PathCheck.roomToStand(options, point)
			if fits then
				table.insert(problems, `{name} {format(point)}: a body "fits" inside the ground`)
			elseif inTheWay ~= Workspace.Terrain then
				table.insert(problems, `{name} {format(point)}: the part in the way is not the Terrain`)
			end
			local spot = PathCheck.nearestSpot(map, point, NEAR_A_POINT)
			if spot ~= nil then
				table.insert(
					problems,
					`{name} {format(point)}: the walk map has a spot at {format(map.spots[spot].position)}`
				)
			end
		end
		table.sort(problems)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("every landing spot still has room to stand and a spot", function()
		local problems: { string } = {}
		-- The ground under a landing spot is what a player bumps into, like every ground ray in PathCheck (Rule 23): a
		-- flower or a rope with CanCollide off is not ground.
		local ground = RaycastParams.new()
		ground.RespectCanCollide = true
		ground.CollisionGroup = Collisions.GROUP
		for _, landing in landings do
			local hit = Workspace:Raycast(
				landing.position + Vector3.new(0, LANDING_RAY_ABOVE, 0),
				Vector3.new(0, -LANDING_RAY_LENGTH, 0),
				ground
			)
			if hit == nil then
				table.insert(problems, `LandingSpot_{landing.index} at {format(landing.position)}: no ground under it`)
			else
				if not PathCheck.roomToStand(options, hit.Position, hit.Normal) then
					table.insert(
						problems,
						`LandingSpot_{landing.index} at {format(hit.Position)}: no room for a body to stand`
					)
				end
				if PathCheck.nearestSpot(map, hit.Position, map.spacing) == nil then
					table.insert(
						problems,
						`LandingSpot_{landing.index} at {format(hit.Position)}: no walk-map spot within one grid step`
					)
				end
			end
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
		expect(#landings).toBe(10)
	end)

	it("the giant has no stuck spots, and the V1 stuck spots stay fixed", function()
		local problems: { string } = {}
		-- A stuck spot is allowed only if it is on the rare list (Rule 22), and a listed spot only while it still meets
		-- conditions 1 to 3; or if it is a closed hollow on the closed list, and a listed hollow only while it stays
		-- closed, with no link into it from outside and no place players need inside it.
		local positions: { Vector3 } = {}
		for _, spot in stuck do
			table.insert(positions, spot.position)
		end
		local unlisted: { StuckSpot } = {}
		for _, index in
			unlistedStuck(positions, RARE_SPOTS, CLOSED_SPOTS, Helpers.ACCEPTED_FOR_NOW, Helpers.MAP_ONLY_STOPS)
		do
			table.insert(unlisted, stuck[index])
		end
		if #unlisted > 0 then
			table.insert(
				problems,
				"Stuck spots that are on neither the rare list, the closed list nor the accepted-for-now list, nor the map-only stops:"
			)
			for _, line in stuckReport(unlisted, world) do
				table.insert(problems, line)
			end
		end
		local broken = rareBrokenConditions(RARE_SPOTS, rareFacts(world, map, landings, stuckIds))
		if #broken > 0 then
			table.insert(problems, "Rare-list spots that no longer meet Rule 22's conditions 1 to 3:")
			for _, problem in broken do
				table.insert(problems, `  {problem}`)
			end
		end
		local opened = closedBrokenConditions(CLOSED_SPOTS, closedFacts(world, map, landings))
		if #opened > 0 then
			table.insert(problems, "Closed-list hollows that are no longer closed, unlinked and empty:")
			for _, problem in opened do
				table.insert(problems, `  {problem}`)
			end
		end
		local named = namedProblems(map, options, stuckIds, world)
		if #named > 0 then
			table.insert(problems, "Named V1 stuck spots that failed:")
			for _, problem in named do
				table.insert(problems, `  {problem}`)
			end
		end
		if buildAndSearchSeconds > Config.Stuck.ScanSeconds then
			table.insert(
				problems,
				string.format(
					"The scan took %.1f seconds, over the %g second limit.",
					buildAndSearchSeconds,
					Config.Stuck.ScanSeconds
				)
			)
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, SCAN_TIMEOUT_MS)

	-- Stuck safety Task 22, test 1: no stuck spot lies in a fixed place. The message gives each failing place's name and
	-- its count, and the first few spots in it.
	it("no stuck spot in a fixed place", function()
		local problems: { string } = {}
		for _, place in FIXED_PLACES do
			local inside: { Vector3 } = {}
			for _, spot in stuck do
				local p = spot.position
				if
					p.X >= place.min.X
					and p.X <= place.max.X
					and p.Y >= place.min.Y
					and p.Y <= place.max.Y
					and p.Z >= place.min.Z
					and p.Z <= place.max.Z
				then
					table.insert(inside, p)
				end
			end
			if #inside > 0 then
				local shown: { string } = {}
				for index = 1, math.min(#inside, FIXED_PLACE_SPOTS_SHOWN) do
					table.insert(shown, format(inside[index]))
				end
				table.insert(problems, `{place.name}: {#inside} stuck spots, first {table.concat(shown, ", ")}`)
			end
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("nobody walks into the cave under the cushion", function()
		local ray = RaycastParams.new()
		ray.CollisionGroup = Collisions.GROUP
		ray.IgnoreWater = true

		type Walk = { start: Vector3, heading: number, mustStand: boolean }
		local walks: { Walk } = {}
		for _, turn in CAVE_HUMP_TURNS do
			table.insert(walks, { start = CAVE_TRAP_START, heading = turn, mustStand = true })
		end
		for _, x in CAVE_HUMP_XS do
			for _, turn in CAVE_HUMP_TURNS do
				table.insert(
					walks,
					{ start = Vector3.new(x, CAVE_HUMP_Y, CAVE_HUMP_Z), heading = turn, mustStand = false }
				)
			end
		end
		for _, turn in CAVE_LEDGE_TURNS do
			table.insert(walks, { start = CAVE_LEDGE_LEFT, heading = CAVE_LEDGE_LEFT_HEADING + turn, mustStand = true })
			table.insert(
				walks,
				{ start = CAVE_LEDGE_RIGHT, heading = CAVE_LEDGE_RIGHT_HEADING + turn, mustStand = true }
			)
		end
		expect(#walks).toBe(36)

		local problems: { string } = {}
		for _, walk in walks do
			local inside, stood = walkTowardCave(walk.start, walk.heading, ray, options)
			if not stood and walk.mustStand then
				table.insert(problems, `No ground: nobody can stand at {format(walk.start)}`)
			elseif inside ~= nil then
				table.insert(
					problems,
					`Walk-in: from {format(walk.start)}, heading {walk.heading}, inside at {format(inside)}`
				)
			end
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	----------------------------------------------------------------------------------------------------------------
	-- The ladders join their ends on the real walk map (stuck safety Task 25, test 6)
	----------------------------------------------------------------------------------------------------------------

	-- Rule 15 (The climb needs no jump), designer 9 and game_creator 1 and 2: the beard ladder joins his belly top to
	-- his nose top and the cap ladder joins his nose top to his cap, by climb links. A walk joins the beard ladder's top
	-- to the cap ladder's foot across the nose top, and the cap ladder's top to both brim nest points with no jump. The
	-- two side nest points are only reported, as "reached" or "not reached".
	it("each ladder joins its two ends on the real walk map", function()
		local problems: { string } = {}
		local beardFoot, beardTop = ladderEndSpots("BeardLadder", map, world)
		local capFoot, capTop = ladderEndSpots("CapLadder", map, world)
		for label, spot in
			{
				["beard ladder foot"] = beardFoot,
				["beard ladder top"] = beardTop,
				["cap ladder foot"] = capFoot,
				["cap ladder top"] = capTop,
			}
		do
			if spot == nil then
				table.insert(problems, `{label}: no walk-map spot within {LADDER_REACH_STEPS} grid steps`)
			end
		end
		if #problems == 0 then
			if not hasClimbLink(beardFoot :: number, beardTop :: number, map) then
				table.insert(problems, "no climb link joins the beard ladder's foot to its top")
			end
			if not hasClimbLink(capFoot :: number, capTop :: number, map) then
				table.insert(problems, "no climb link joins the cap ladder's foot to its top")
			end
			if not canWalk(beardTop :: number, { capFoot :: number }, map) then
				table.insert(
					problems,
					"no walk joins the beard ladder's top to the cap ladder's foot across the nose top"
				)
			end
			for _, name in sortedNames(BRIM_NESTS) do
				local near = spotsNearNest(BRIM_NESTS[name], map)
				if #near == 0 then
					table.insert(problems, `{name}: no walk-map spot within {NEST_REACH} studs of it`)
				elseif not canWalk(capTop :: number, near, map) then
					table.insert(problems, `{name}: no walk from the cap ladder's top reaches it`)
				end
			end
			local report: { string } = {}
			for _, name in sortedNames(SIDE_NESTS) do
				local near = spotsNearNest(SIDE_NESTS[name], map)
				local reached = #near > 0 and canWalk(capTop :: number, near, map)
				table.insert(report, `{name}: {if reached then "reached" else "not reached"}`)
			end
			print(
				`[Task 25 test 6] side nest points from the cap ladder's top by walking: {table.concat(report, ", ")}`
			)
		end
		expect(problems).toEqual({})
	end)

	-- The check above must be able to fail: two spots no ladder joins have no climb link, and no walk gets from his
	-- belly to his nose without the beard ladder.
	it("the ladder link check notices two spots no ladder joins", function()
		local beardFoot, beardTop = ladderEndSpots("BeardLadder", map, world)
		local capFoot, capTop = ladderEndSpots("CapLadder", map, world)
		expect(beardFoot).never.toBeNil()
		expect(capTop).never.toBeNil()
		expect(hasClimbLink(beardFoot :: number, capTop :: number, map)).toBe(false)
		expect(hasClimbLink(beardTop :: number, capFoot :: number, map)).toBe(false)
		expect(canWalk(beardFoot :: number, { capFoot :: number }, map)).toBe(false)
	end)

	-- Stuck safety Task 22, test 4 (game_creator's check 5): the patches must not narrow or block the way past the beard
	-- ladder's foot. From the walk-map spot nearest the foot, a walk alone reaches the spot nearest RoutePoint_Belly_4, and
	-- at least BEARD_FOOT_SPOTS spots lie within BEARD_FOOT_RADIUS studs of the foot. It uses the walk map built above.
	it("the way to the beard ladder stays open", function()
		local ladder = (world :: any).WalkSurfaces:FindFirstChild("BeardLadder") :: Instance?
		expect(ladder).never.toBeNil()
		local truss = (ladder :: Instance):FindFirstChild("Climb") :: BasePart?
		expect(truss).never.toBeNil()
		-- The foot: the lower end of the truss's longest side, as ladderEndSpots finds it.
		local size = (truss :: BasePart).Size
		local half = if size.X >= size.Y and size.X >= size.Z
			then Vector3.new(size.X / 2, 0, 0)
			elseif size.Y >= size.Z then Vector3.new(0, size.Y / 2, 0)
			else Vector3.new(0, 0, size.Z / 2)
		local endA = (truss :: BasePart).CFrame:PointToWorldSpace(half)
		local endB = (truss :: BasePart).CFrame:PointToWorldSpace(-half)
		local foot = if endB.Y < endA.Y then endB else endA

		local problems: { string } = {}
		local near = 0
		for _, spot in map.spots do
			if (spot.position - foot).Magnitude <= BEARD_FOOT_RADIUS then
				near += 1
			end
		end
		if near < BEARD_FOOT_SPOTS then
			table.insert(
				problems,
				`only {near} walk-map spots within {BEARD_FOOT_RADIUS} studs of the beard ladder's foot {format(foot)}, wanted at least {BEARD_FOOT_SPOTS}`
			)
		end

		local footSpot = PathCheck.nearestSpot(map, foot, LADDER_REACH_STEPS * map.spacing)
		local bellyFour: Vector3? = nil
		for _, point in WorldIndex.loadRoute(world) do
			if point.name == "RoutePoint_Belly_4" then
				bellyFour = point.position
			end
		end
		local goal = if bellyFour then PathCheck.nearestSpot(map, bellyFour, 2 * map.spacing) else nil
		if footSpot == nil then
			table.insert(problems, "no walk-map spot near the beard ladder's foot")
		elseif goal == nil then
			table.insert(problems, "no walk-map spot near RoutePoint_Belly_4")
		elseif not canWalk(footSpot, { goal }, map) then
			table.insert(problems, "no walk from the beard ladder's foot reaches RoutePoint_Belly_4's spot")
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	-- Stuck safety Task 23, test 3: the hump top walks out by the walk map. Each point of HUMP_TOPS has a walk-map spot
	-- within HUMP_REACH studs, and that spot has a route (any link kind) to a meadow exit. The points are feet points.
	it("the hump top walks out by the walk map", function()
		local problems: { string } = {}
		for name, point in HUMP_TOPS do
			local spot = PathCheck.nearestSpot(map, point, HUMP_REACH)
			if spot == nil then
				table.insert(problems, `{name} {format(point)}: no walk-map spot within {HUMP_REACH} studs`)
			elseif PathCheck.route(map, spot, exits) == nil then
				table.insert(
					problems,
					`{name} {format(point)}: the spot {format(map.spots[spot].position)} has no route to a meadow exit`
				)
			end
		end
		if #problems > 0 then
			table.sort(problems)
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("the scan finishes within the time limit", function()
		expect(buildAndSearchSeconds).toBeLessThanOrEqual(Config.Stuck.ScanSeconds)
	end)

	-- Stuck safety Task 41, test 3: the pillow has no stuck spot. The report's "Pillow" line counts the spots standing on
	-- a part of World.GiantsThings.Pillow.
	it("the pillow has no stuck spot", function()
		local pillow = (world :: any).GiantsThings.Pillow :: Instance
		local onPillow: { string } = {}
		for _, spot in stuck do
			if spot.standsOn:IsDescendantOf(pillow) then
				table.insert(onPillow, format(spot.position))
			end
		end
		local shown: { string } = {}
		for index = 1, math.min(#onPillow, 5) do
			table.insert(shown, onPillow[index])
		end
		expect(`{#onPillow} stuck spots on the pillow, first: {table.concat(shown, ", ")}`).toBe(
			"0 stuck spots on the pillow, first: "
		)
	end)

	-- Task 41, test 6: the pillow gives no way up. Red first on a made-up map with a step from the top to a nest.
	it("the way-up check notices a step from the pillow's top to a nest", function()
		local spots: { PillowWayUp.Spot } = {
			{ id = 1, position = Vector3.new(0, 0, 0) },
			{ id = 2, position = Vector3.new(5, 1, 0) },
			{ id = 3, position = Vector3.new(10, 1, 0) },
		}
		local function rulesFor(jumps: boolean): PillowWayUp.Rules
			return {
				isGround = function(spot)
					return spot.id == 1
				end,
				isBlocked = function(_spot)
					return false
				end,
				isTop = function(spot)
					return spot.id == 2
				end,
				isTarget = function(spot)
					return spot.id == 3
				end,
				canJump = function(_from, _to)
					return jumps
				end,
			}
		end
		local withStep: PillowWayUp.MapLike =
			{ spots = spots, links = { [1] = { { to = 2, kind = "Walk" } }, [2] = { { to = 3, kind = "Walk" } } } }
		local noStep: PillowWayUp.MapLike = { spots = spots, links = { [1] = { { to = 2, kind = "Walk" } } } }
		local unreachable: PillowWayUp.MapLike = { spots = spots, links = { [2] = { { to = 3, kind = "Walk" } } } }
		expect(#PillowWayUp.problems(withStep, rulesFor(false))).toBeGreaterThan(0)
		expect(#PillowWayUp.problems(noStep, rulesFor(true))).toBeGreaterThan(0)
		expect(PillowWayUp.problems(noStep, rulesFor(false))).toEqual({})
		expect(PillowWayUp.problems(unreachable, rulesFor(false))).toEqual({})
	end)

	it("the pillow gives no way up", function()
		local pillow = (world :: any).GiantsThings.Pillow :: Instance
		local giant = giantModel(world)
		local nests: { Vector3 } = {}
		for _, part in (world :: any).EggSpots:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(nests, part.Position)
			end
		end
		local player = game:GetService("StarterPlayer")
		local gravity = Workspace.Gravity
		local jumpHeight = (
			if player.CharacterUseJumpPower
				then player.CharacterJumpPower ^ 2 / (2 * gravity)
				else player.CharacterJumpHeight
		) + 0.5
		local walkSpeed = (Config :: any).Movement.WalkSpeed :: number
		local rules: PillowWayUp.Rules = {
			isGround = function(spot)
				return spot.standsOn == Workspace.Terrain
			end,
			isBlocked = function(spot)
				return spot.standsOn ~= nil and spot.standsOn:IsDescendantOf(giant)
			end,
			isTop = function(spot)
				return spot.standsOn ~= nil and spot.standsOn:IsDescendantOf(pillow)
			end,
			isTarget = function(spot)
				local on = spot.standsOn
				if
					on ~= nil
					and (
						on:IsDescendantOf((giant :: any).nightcap) or on:IsDescendantOf((giant :: any).head_with_beard)
					)
				then
					return true
				end
				for _, nest in nests do
					if (spot.position - nest).Magnitude <= NEST_REACH then
						return true
					end
				end
				return false
			end,
			canJump = function(from, to)
				if not PillowWayUp.jumpReaches(from, to, jumpHeight, gravity, walkSpeed) then
					return false
				end
				return PathCheck.bodyFits(options, PillowWayUp.apexBetween(from, to, jumpHeight))
			end,
		}
		expect(PillowWayUp.problems(map :: any, rules)).toEqual({})
	end, SCAN_TIMEOUT_MS)

	-- Plan 5 Task 14 (spec 5 "Walk anywhere down to the seam"): the scan area holds both arms out to x 64 each side. The
	-- area is the giant's box plus Config.Stuck.ScanMargin, so no change to scanArea is needed.
	it("the scan area reaches both arms, out to x -64 and x 64", function()
		expect(area.min.X <= -64).toBe(true)
		expect(area.max.X >= 64).toBe(true)
	end)

	-- Plan 5 Task 14: red until plan 5 Tasks 15 and 16 (steep layer, seam). The message counts each kind of problem.
	it("the walk area passes the walk-area check", function()
		local found, areaSpots = WalkAreaFacts.problems(world, map)
		expect(WalkAreaFacts.message(found, areaSpots)).toBe(WalkAreaFacts.message({}, areaSpots))
	end, SCAN_TIMEOUT_MS)

	it("the scan area holds every way-up piece, and all 10 landing spots are exits", function()
		expect(WaysUpRoutes.piecesOutside(world, area)).toEqual({})
		expect(#landingExits).toBe(10)
	end)
end)

-- Plan 3 Task 9 (spec 3 Rules 15, 43 and 45): each way up has a walk-and-climb route to Rare egg 1 through the lap landing.
-- The scan map's rows sit on odd z, so none runs along z -58, the only lane from a boot top onto its lap plank. This map
-- starts at an even z, so one row runs along that lane (measured 2026-11-11).
describe("the ways up on a route map with even rows", function()
	local world: Instance
	local options: PathCheck.Options
	local map: PathCheck.WalkMap

	beforeAll(function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		world = found :: Instance
		options = PathCheck.defaults(Workspace)
		options.boxIgnores = {
			(world :: any).WalkSurfaces.BootRamp.Ramp_Walk,
			(world :: any).WalkSurfaces.RightBootRamp.Ramp_Walk,
		}
		local routeArea: PathCheck.Area = { min = Vector3.new(-69, -8, -104), max = Vector3.new(69, 70, 0) }
		map = PathCheck.buildMap(options, routeArea)
	end, SCAN_TIMEOUT_MS)

	afterAll(function()
		if options ~= nil then
			pcall(PathCheck.cleanup, options)
		end
	end)

	it("a walk-and-climb route from BootLadder_Left reaches Rare egg 1 through the lap landing", function()
		expect(WaysUpRoutes.routeProblem("BootLadder_Left", true, map, world)).toBe("ok")
	end, SCAN_TIMEOUT_MS)

	it("a walk-and-climb route from BootRamp reaches Rare egg 1 through the lap landing", function()
		expect(WaysUpRoutes.routeProblem("BootRamp", false, map, world)).toBe("ok")
	end, SCAN_TIMEOUT_MS)

	it("a walk-and-climb route from RightBootRamp reaches Rare egg 1 through the lap landing", function()
		expect(WaysUpRoutes.routeProblem("RightBootRamp", false, map, world)).toBe("ok")
	end, SCAN_TIMEOUT_MS)

	it("a walk-and-climb route from BootLadder_Right reaches Rare egg 1 through the lap landing", function()
		expect(WaysUpRoutes.routeProblem("BootLadder_Right", true, map, world)).toBe("ok")
	end, SCAN_TIMEOUT_MS)
end)
