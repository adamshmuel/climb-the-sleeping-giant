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

-- The stuck scan (V2 Rule 21, "The stuck scan runs on every test run", and Rule 22, "What counts as stuck"): it reads
-- the real world, builds the walk map of the giant and the meadow around him, and fails if even one spot has no way
-- out by walking, ladders and slides or drops. The V1 stuck spots are also checked by name. Nothing is changed or left
-- in the world: the body probe is removed in afterAll.

local SCAN_TIMEOUT_MS = 150000 -- Jest's limit for the build: more than the scan's own 120 seconds
local MAX_LINES = 300 -- most stuck spots written out one by one
local NEAR_GIANT = 10 -- studs: the farthest a "nearest part of the giant" is looked for
local BELOW_AND_ABOVE = 5 -- studs the scan area reaches below the lowest ground and above the giant
local FOREHEAD_POINT = Vector3.new(20, 104, 6) -- V1's stuck spot on the forehead
local GUARD_SIDE_X = 7 -- the side guard walls stand beyond this x on both sides of the forehead's middle
local DROP_FROM_ABOVE = 3 -- a named point with no spot near it is checked by casting down from this far above...
local DROP_LENGTH = 6 -- ...this far down
local ROUTE_NAMES = {
	"RoutePoint_Belly_1",
	"RoutePoint_Belly_2",
	"RoutePoint_Belly_3",
	"RoutePoint_Belly_4",
	"RoutePoint_Egg_Rare_1",
	"RoutePoint_Egg_Rare_2",
	"RoutePoint_Egg_Rare_3",
	"RoutePoint_Egg_Rare_4",
}

-- Three places inside the meadow ground under his chair (stuck safety Task 20). Each is a stuck spot from the stuck scan
-- after Task 19 (his real shape; the list of 436 spots, 2026-10-20): the spot stands on the underside of his chair
-- (body_and_cushion), more than half a stud under the meadow top (y 2). The scan used to count them because Roblox's
-- exact overlap check can't see the Terrain.
local UNDER_LEFT_ARMREST = Vector3.new(-28.8, -1.2, 9) -- the list's line "-28.8,-1.2,9.0|body_and_cushion|body_and_cushion"
local UNDER_RIGHT_ARMREST = Vector3.new(27.2, 0.6, 27) -- "27.2,0.6,27.0|body_and_cushion|body_and_cushion"
local FRONT_OF_CHAIR = Vector3.new(-30.8, 0.3, -15) -- "-30.8,0.3,-15.0|body_and_cushion|body_and_cushion": the lowest z
local NEAR_A_POINT = 1 -- studs: a named stuck spot sits on a grid column, so "a spot at that point" is one within this far
local LANDING_RAY_ABOVE = 3 -- the ground under a landing spot: a ray from this far above it...
local LANDING_RAY_LENGTH = 6 -- ...this far down

-- Stuck safety Task 25, test 6. PathCheck joins a ladder's foot and top to the nearest spot within two grid steps
-- (its CLIMB_REACH_STEPS, which is private). Spec 5's four Legendary nest points are on his cap: the brim pair is just
-- past the cap ladder's top, the side pair farther up the cap's front slope. A nest is reached when a spot within
-- NEST_REACH studs of its point can be walked to.
local LADDER_REACH_STEPS = 2
local NEST_REACH = 2 -- studs
-- Stuck safety Task 22, test 4 (game_creator's check 5): the way to the beard ladder stays open. The walk-map spots
-- within BEARD_FOOT_RADIUS studs of the ladder's foot must not drop below what they were before the patches.
local BEARD_FOOT_SPOTS = 4 -- measured in step 22-0, after Task 25
local BEARD_FOOT_RADIUS = 4 -- studs
local BRIM_NESTS: { [string]: Vector3 } = {
	["left brim nest"] = Vector3.new(-14, 117.1, 14),
	["right brim nest"] = Vector3.new(14, 117.1, 14),
}
local SIDE_NESTS: { [string]: Vector3 } = {
	["left side nest"] = Vector3.new(-17, 119, 28),
	["right side nest"] = Vector3.new(17, 119, 28),
}

-- Stuck safety Task 22, test 1: the places the patches and the pillow's closer fit close. Each is a box (x, y, z minimum
-- and maximum) around a group of stuck spots from the list after Task 26 (287 spots in 43 groups, 2026-10-21; the group
-- numbers are the start list's). No stuck spot may lie in any of them, on every run, like the named V1 spots.
type FixedPlace = { name: string, min: Vector3, max: Vector3 }
local FIXED_PLACES: { FixedPlace } = {
	-- Group 1: the flat top of the chair's back cushion, under the pillow.
	{ name = "cushion top behind his head", min = Vector3.new(-30, 48, 49), max = Vector3.new(30, 58, 69) },
	-- Group 2: the sealed air pocket under the cushion, inside the chair's back.
	{ name = "cave under the cushion", min = Vector3.new(-21, 22, 49), max = Vector3.new(21, 36, 59) },
	-- Groups 3, 18, 39 and 41: behind his head, on the right.
	{ name = "behind his head, right", min = Vector3.new(14, 96, 36), max = Vector3.new(30, 114.5, 52) },
	-- Groups 4, 13 and 42: behind his head, on the left.
	{ name = "behind his head, left", min = Vector3.new(-28, 99, 36), max = Vector3.new(-9, 114.5, 54) },
	-- The back of the neck, the right side of the neck, under the brim, the right chair arm (low and high) and the left
	-- chair arm: moved to Task 23 by code_lead's ruling after step 22-8 (plan).
}
local FIXED_PLACE_SPOTS_SHOWN = 3 -- stuck spots written out for each place that fails

-- Stuck safety Task 22, test 5: nobody walks into the cave under the cushion. The walk map has no link over the hump,
-- so this test walks a body itself, from named starts, half a stud at a time.
-- The cave's box (step 22-8f's pass rule): x -21 to 21, y 16 to 44, z 45.5 to 60. Feet inside it fail the test.
local CAVE_BOX_MIN = Vector3.new(-21, 16, 45.5)
local CAVE_BOX_MAX = Vector3.new(21, 44, 60)
-- Ruling 6's Play walk: up the slope behind his back to here, over the hump, and down into the cave.
local CAVE_TRAP_START = Vector3.new(-12, 23, 41)
-- The hump points: z 41 and x -12, -6, 0, 6 and 12, at the trap start's height. Step 22-8f pushed toward the cave from
-- these, and found ground with room for a body only near x -12: the others stand on no ground, and have no walk.
local CAVE_HUMP_XS = { -12, -6, 0, 6, 12 }
local CAVE_HUMP_Y = 23
local CAVE_HUMP_Z = 41
-- The two ledges over his shoulders, as ground points (step 22-8f3: the root stands 3.4 above them).
local CAVE_LEDGE_LEFT = Vector3.new(-16.8, 48.4, 43)
local CAVE_LEDGE_RIGHT = Vector3.new(17.2, 48.2, 43)
-- Headings in degrees: 0 is toward +Z (toward the cave), a positive turn goes toward +X. From the hump, 5 headings
-- (straight and 20 and 40 to each side); from a ledge, 3 (toward x 0 and 20 to each side).
local CAVE_HUMP_TURNS = { -40, -20, 0, 20, 40 }
local CAVE_LEDGE_TURNS = { -20, 0, 20 }
local CAVE_LEDGE_LEFT_HEADING = 90 -- toward x 0 from the left ledge
local CAVE_LEDGE_RIGHT_HEADING = -90 -- toward x 0 from the right ledge
local CAVE_WALK_STEP = 0.5 -- studs along the heading at a time...
local CAVE_WALK_STEPS = 20 -- ...for 10 studs
local CAVE_START_RAY_ABOVE = 3 -- a start is put on the ground a ray finds from this far above it...
local CAVE_START_RAY_LENGTH = 12 -- ...this far down; no ground there means nobody stands on that point
local CAVE_STEP_RAY_ABOVE = 3 -- each step finds the ground with a ray from this far above the feet...
local CAVE_STEP_RAY_LENGTH = 60 -- ...down to the ground, however far (a fall is a lower step)
local CAVE_FALL_DROP = 1 -- studs: ground lower than this under the next step is a fall
local CAVE_FALL_CARRY = 3 -- studs: a falling body goes on this far along the heading, to find where it lands
-- A steep ramp ahead holds a body higher than the feet: half the body's width times the steepest slope's tangent
-- (tan 70 degrees is 2.75). The body is tried held up this far in half-stud steps, and half a stud off the line.
local CAVE_BODY_MAX_LIFT = 2.5
local CAVE_BODY_LIFT_STEP = 0.5
local CAVE_BODY_NUDGES = { 0, 0.25, -0.25, 0.5, -0.5 }

type Landing = WorldIndex.LandingSpot

local function format(position: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
end

-- The part's full name without the leading "Workspace.".
local function shortName(part: Instance): string
	return (string.gsub(part:GetFullName(), "^Workspace%.", ""))
end

-- The area to scan: the giant's box grown to hold every landing spot, then `margin` studs of meadow on each side in x
-- and z. In y: BELOW_AND_ABOVE below the lowest of the giant's bottom and the landing spots, to BELOW_AND_ABOVE above
-- the giant's top. A landing spot outside the area could never be reached, so the area must hold all of them.
local function scanArea(giant: Model, landings: { Landing }, margin: number): PathCheck.Area
	local boxCFrame, boxSize = giant:GetBoundingBox()
	local low = boxCFrame.Position - boxSize / 2
	local high = boxCFrame.Position + boxSize / 2
	local minX, minZ, maxX, maxZ = low.X, low.Z, high.X, high.Z
	local bottom = low.Y
	for _, landing in landings do
		minX = math.min(minX, landing.position.X)
		maxX = math.max(maxX, landing.position.X)
		minZ = math.min(minZ, landing.position.Z)
		maxZ = math.max(maxZ, landing.position.Z)
		bottom = math.min(bottom, landing.position.Y)
	end
	return {
		min = Vector3.new(minX - margin, bottom - BELOW_AND_ABOVE, minZ - margin),
		max = Vector3.new(maxX + margin, high.Y + BELOW_AND_ABOVE, maxZ + margin),
	}
end

-- How far `position` is from the nearest point of the part's box (in the part's own space).
local function distanceToBox(part: BasePart, position: Vector3): number
	local inside = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	local nearest = Vector3.new(
		math.clamp(inside.X, -half.X, half.X),
		math.clamp(inside.Y, -half.Y, half.Y),
		math.clamp(inside.Z, -half.Z, half.Z)
	)
	return (inside - nearest).Magnitude
end

-- The part of the giant a stuck spot is on (if it stands on one), or else the part whose box is nearest within
-- NEAR_GIANT studs. nil when none is that close.
local function nearestGiantPart(giantParts: { BasePart }, giant: Model, spotOn: BasePart, position: Vector3): BasePart?
	if spotOn:IsDescendantOf(giant) then
		return spotOn
	end
	local best: BasePart? = nil
	local bestDistance = NEAR_GIANT
	for _, part in giantParts do
		local distance = distanceToBox(part, position)
		if distance <= bestDistance then
			best = part
			bestDistance = distance
		end
	end
	return best
end

-- The piece of the giant (his direct child model, such as legs_and_boots) that a part belongs to, or nil when it is not
-- inside the giant.
local function pieceOf(giant: Model, part: BasePart?): string?
	if part == nil then
		return nil
	end
	local at: Instance = part
	while at.Parent ~= nil and at.Parent ~= giant do
		at = at.Parent
	end
	if at.Parent == giant then
		return at.Name
	end
	return nil
end

-- The line of the report that a stuck spot counts for. A spot standing on a part of the pillow (World.GiantsThings.Pillow)
-- has a line of its own, "Pillow", and is not counted for the giant piece nearest to it. Any other spot counts for the
-- piece of the part it stands on, else of the nearest part of the giant.
local PILLOW_LABEL = "Pillow"
local function labelOf(giant: Model, pillow: Instance?, spotOn: BasePart, nearest: BasePart?): string?
	if pillow ~= nil and spotOn:IsDescendantOf(pillow) then
		return PILLOW_LABEL
	end
	return pieceOf(giant, nearest)
end

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

	local function giantModel(): Model
		return (world :: any).Giant :: Model
	end

	-- Builds the walk map once for all the tests (it takes tens of seconds) and finds the stuck spots.
	beforeAll(function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		world = found :: Instance
		landings = WorldIndex.loadLandingSpots(world)
		area = scanArea(giantModel(), landings, Config.Stuck.ScanMargin)

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

	-- A named V1 point passes if every walk-map spot within one grid step of it reaches an exit. With no spot that
	-- close, it passes only if no body fits there. Returns why it failed, or nil.
	local function namedPointProblem(name: string, point: Vector3): string?
		local anySpot = false
		for _, spot in map.spots do
			if (spot.position - point).Magnitude <= map.spacing then
				anySpot = true
				if stuckIds[spot.id] then
					return `{name} at {format(point)}: the spot at {format(spot.position)} has no route to a meadow exit`
				end
			end
		end
		if anySpot then
			return nil
		end
		local params = RaycastParams.new()
		local hit =
			Workspace:Raycast(point + Vector3.new(0, DROP_FROM_ABOVE, 0), Vector3.new(0, -DROP_LENGTH, 0), params)
		if hit == nil then
			return nil
		end
		if PathCheck.roomToStand(options, hit.Position, hit.Normal) then
			return `{name}: a body fits at {format(hit.Position)} but the walk map has no spot there`
		end
		return nil
	end

	-- Every map spot behind one of the four side guard walls of the forehead: inside the wall's x range and height
	-- range, and with a larger z than the wall's middle. Each is a slot a player could step into.
	local function foreheadSlotProblems(): { string }
		local problems: { string } = {}
		local guards = (world :: any).WalkSurfaces.ForeheadGuard :: Instance
		for _, wall in guards:GetChildren() do
			if wall:IsA("BasePart") and wall.Name == "Guard" and math.abs(wall.Position.X) > GUARD_SIDE_X then
				local lowX, highX, lowY, highY = math.huge, -math.huge, math.huge, -math.huge
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner = wall.CFrame:PointToWorldSpace(
								Vector3.new(wall.Size.X / 2 * sx, wall.Size.Y / 2 * sy, wall.Size.Z / 2 * sz)
							)
							lowX, highX = math.min(lowX, corner.X), math.max(highX, corner.X)
							lowY, highY = math.min(lowY, corner.Y), math.max(highY, corner.Y)
						end
					end
				end
				for _, spot in map.spots do
					local at = spot.position
					if
						at.X >= lowX
						and at.X <= highX
						and at.Y >= lowY
						and at.Y <= highY
						and at.Z > wall.Position.Z
						and stuckIds[spot.id]
					then
						table.insert(
							problems,
							`forehead slot behind the side wall at x {string.format("%.1f", wall.Position.X)}: the spot at {format(
								at
							)} has no route to a meadow exit`
						)
					end
				end
			end
		end
		return problems
	end

	-- Every named V1 stuck spot that fails, with the reason.
	local function namedProblems(): { string }
		local problems: { string } = {}
		local forehead = namedPointProblem("forehead point", FOREHEAD_POINT)
		if forehead ~= nil then
			table.insert(problems, forehead)
		end
		local points = WorldIndex.loadRoute(world)
		local byName: { [string]: Vector3 } = {}
		for _, point in points do
			byName[point.name] = point.position
		end
		for _, name in ROUTE_NAMES do
			local position: Vector3? = byName[name]
			if position == nil then
				table.insert(problems, `{name} is missing from World.Route`)
			else
				local problem = namedPointProblem(name, position)
				if problem ~= nil then
					table.insert(problems, problem)
				end
			end
		end
		for _, problem in foreheadSlotProblems() do
			table.insert(problems, problem)
		end
		return problems
	end

	-- The stuck spots as text: a summary, then one line each (at most MAX_LINES).
	local function stuckReport(): { string }
		local giantParts: { BasePart } = {}
		for _, descendant in giantModel():GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(giantParts, descendant)
			end
		end
		local pillowFolder = world:FindFirstChild("GiantsThings")
		local pillow: Instance? = if pillowFolder ~= nil then pillowFolder:FindFirstChild("Pillow") else nil
		local counts: { [string]: number } = {}
		local lines: { string } = {}
		for _, spot in stuck do
			local nearest = nearestGiantPart(giantParts, giantModel(), spot.standsOn, spot.position)
			local nearestName = if nearest ~= nil then shortName(nearest) else `none within {NEAR_GIANT} studs`
			local pieceName = labelOf(giantModel(), pillow, spot.standsOn, nearest) or `none within {NEAR_GIANT} studs`
			counts[pieceName] = (counts[pieceName] or 0) + 1
			if #lines < MAX_LINES then
				table.insert(
					lines,
					`{format(spot.position)} on {shortName(spot.standsOn)}, nearest giant part: {nearestName}`
				)
			end
		end
		local names: { string } = {}
		for name in counts do
			table.insert(names, name)
		end
		table.sort(names, function(a, b)
			if counts[a] ~= counts[b] then
				return counts[a] > counts[b]
			end
			return a < b
		end)
		local report: { string } = {
			`{#stuck} stuck spots. Count by giant piece (the piece of the part a spot stands on, else of the nearest part; the pillow has its own line), largest first:`,
		}
		for _, name in names do
			table.insert(report, `  {counts[name]}  {name}`)
		end
		table.insert(report, "Each stuck spot (position, the part it stands on, nearest giant part):")
		for _, line in lines do
			table.insert(report, `  {line}`)
		end
		if #stuck > #lines then
			table.insert(report, `  ...and {#stuck - #lines} more`)
		end
		return report
	end

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
		expect(#landings).toBe(8)
	end)

	it("the giant has no stuck spots, and the V1 stuck spots stay fixed", function()
		local problems: { string } = {}
		if #stuck > 0 then
			for _, line in stuckReport() do
				table.insert(problems, line)
			end
		end
		local named = namedProblems()
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
	end)

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

	-- Stuck safety Task 22, test 5 (product's condition on the cave lid): nobody walks into the cave under the cushion.
	-- The test walks a body from each named start, half a stud along a heading at a time, up to 10 studs. Each step
	-- finds the ground with a ray straight down from above the feet (players' collision group), and the feet go there,
	-- down any drop. A step ends the walk when no body fits there (PathCheck.bodyFits). The walker is meant to be
	-- generous: it goes anywhere a player can and a few places a player can't (a steep ramp holds the body higher, and
	-- a body can stand half a stud off the line), so it may fail by mistake but never pass by mistake.
	local function bodyFitsNear(feet: Vector3, heading: Vector3): boolean
		local lift = 0
		while lift <= CAVE_BODY_MAX_LIFT + 1e-6 do
			for _, dx in CAVE_BODY_NUDGES do
				for _, dz in CAVE_BODY_NUDGES do
					if PathCheck.bodyFits(options, feet + Vector3.new(dx, lift, dz), nil, heading) then
						return true
					end
				end
			end
			lift += CAVE_BODY_LIFT_STEP
		end
		return false
	end

	local function insideCave(feet: Vector3): boolean
		return feet.X >= CAVE_BOX_MIN.X
			and feet.X <= CAVE_BOX_MAX.X
			and feet.Y >= CAVE_BOX_MIN.Y
			and feet.Y <= CAVE_BOX_MAX.Y
			and feet.Z >= CAVE_BOX_MIN.Z
			and feet.Z <= CAVE_BOX_MAX.Z
	end

	-- Walks from `start` along `headingDegrees`. Returns where the feet were inside the cave's box, or nil. `stood` says
	-- whether the start had ground under it.
	local function walkTowardCave(start: Vector3, headingDegrees: number, ray: RaycastParams): (Vector3?, boolean)
		local radians = math.rad(headingDegrees)
		local heading = Vector3.new(math.sin(radians), 0, math.cos(radians))
		local first = Workspace:Raycast(
			start + Vector3.new(0, CAVE_START_RAY_ABOVE, 0),
			Vector3.new(0, -CAVE_START_RAY_LENGTH, 0),
			ray
		)
		if first == nil then
			return nil, false
		end
		local feet = first.Position
		for _ = 1, CAVE_WALK_STEPS do
			local ahead = feet + heading * CAVE_WALK_STEP
			local function groundAt(point: Vector3): RaycastResult?
				return Workspace:Raycast(
					Vector3.new(point.X, feet.Y + CAVE_STEP_RAY_ABOVE, point.Z),
					Vector3.new(0, -CAVE_STEP_RAY_LENGTH, 0),
					ray
				)
			end
			local ground = groundAt(ahead)
			if ground == nil then
				return nil, true
			end
			local landing: RaycastResult? = nil
			if ground.Position.Y < feet.Y - CAVE_FALL_DROP then
				-- A fall: the body goes on along the heading while it drops, and lands where a body fits.
				local carried = 0
				while carried <= CAVE_FALL_CARRY + 1e-6 do
					local found = groundAt(ahead + heading * carried)
					if found ~= nil and bodyFitsNear(found.Position, heading) then
						landing = found
						break
					end
					carried += CAVE_WALK_STEP
				end
			elseif bodyFitsNear(ground.Position, heading) then
				landing = ground
			end
			if landing == nil then
				return nil, true
			end
			feet = landing.Position
			if insideCave(feet) then
				return feet, true
			end
		end
		return nil, true
	end

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
			local inside, stood = walkTowardCave(walk.start, walk.heading, ray)
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

	-- The walk-map spots at the foot and the top of a ladder's solid Climb truss, found the way PathCheck joins them:
	-- the end of the truss's longest side, and the nearest spot within two grid steps. nil when there is none.
	local function ladderEndSpots(ladderName: string): (number?, number?)
		local ladder = (world :: any).WalkSurfaces:FindFirstChild(ladderName) :: Instance?
		expect(ladder).never.toBeNil()
		local truss = (ladder :: Instance):FindFirstChild("Climb") :: BasePart?
		expect(truss).never.toBeNil()
		local size = (truss :: BasePart).Size
		local half = if size.X >= size.Y and size.X >= size.Z
			then Vector3.new(size.X / 2, 0, 0)
			elseif size.Y >= size.Z then Vector3.new(0, size.Y / 2, 0)
			else Vector3.new(0, 0, size.Z / 2)
		local endA = (truss :: BasePart).CFrame:PointToWorldSpace(half)
		local endB = (truss :: BasePart).CFrame:PointToWorldSpace(-half)
		local foot, top = endA, endB
		if endB.Y < endA.Y then
			foot, top = endB, endA
		end
		local reach = LADDER_REACH_STEPS * map.spacing
		return PathCheck.nearestSpot(map, foot, reach), PathCheck.nearestSpot(map, top, reach)
	end

	-- Whether a climb link goes from one spot to another.
	local function hasClimbLink(from: number, to: number): boolean
		local links: { PathCheck.Link } = map.links[from] or {}
		for _, link in links do
			if link.to == to and link.kind == "Climb" then
				return true
			end
		end
		return false
	end

	-- Whether a player can get from one spot to any of `goals` by walking alone: no climb, no slide, no jump.
	local function canWalk(from: number, goals: { number }): boolean
		return PathCheck.route(map, from, goals, { allow = { Walk = true } }) ~= nil
	end

	-- Every spot within NEST_REACH studs of a nest point.
	local function spotsNearNest(point: Vector3): { number }
		local found: { number } = {}
		for _, spot in map.spots do
			if (spot.position - point).Magnitude <= NEST_REACH then
				table.insert(found, spot.id)
			end
		end
		return found
	end

	local function sortedNames(points: { [string]: Vector3 }): { string }
		local names: { string } = {}
		for name in points do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	-- Rule 15 (The climb needs no jump), designer 9 and game_creator 1 and 2: the beard ladder joins his belly top to
	-- his nose top and the cap ladder joins his nose top to his cap, by climb links. A walk joins the beard ladder's top
	-- to the cap ladder's foot across the nose top, and the cap ladder's top to both brim nest points with no jump. The
	-- two side nest points are only reported, as "reached" or "not reached".
	it("each ladder joins its two ends on the real walk map", function()
		local problems: { string } = {}
		local beardFoot, beardTop = ladderEndSpots("BeardLadder")
		local capFoot, capTop = ladderEndSpots("CapLadder")
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
			if not hasClimbLink(beardFoot :: number, beardTop :: number) then
				table.insert(problems, "no climb link joins the beard ladder's foot to its top")
			end
			if not hasClimbLink(capFoot :: number, capTop :: number) then
				table.insert(problems, "no climb link joins the cap ladder's foot to its top")
			end
			if not canWalk(beardTop :: number, { capFoot :: number }) then
				table.insert(
					problems,
					"no walk joins the beard ladder's top to the cap ladder's foot across the nose top"
				)
			end
			for _, name in sortedNames(BRIM_NESTS) do
				local near = spotsNearNest(BRIM_NESTS[name])
				if #near == 0 then
					table.insert(problems, `{name}: no walk-map spot within {NEST_REACH} studs of it`)
				elseif not canWalk(capTop :: number, near) then
					table.insert(problems, `{name}: no walk from the cap ladder's top reaches it`)
				end
			end
			local report: { string } = {}
			for _, name in sortedNames(SIDE_NESTS) do
				local near = spotsNearNest(SIDE_NESTS[name])
				local reached = #near > 0 and canWalk(capTop :: number, near)
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
		local beardFoot, beardTop = ladderEndSpots("BeardLadder")
		local capFoot, capTop = ladderEndSpots("CapLadder")
		expect(beardFoot).never.toBeNil()
		expect(capTop).never.toBeNil()
		expect(hasClimbLink(beardFoot :: number, capTop :: number)).toBe(false)
		expect(hasClimbLink(beardTop :: number, capFoot :: number)).toBe(false)
		expect(canWalk(beardFoot :: number, { capFoot :: number })).toBe(false)
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
		elseif not canWalk(footSpot, { goal }) then
			table.insert(problems, "no walk from the beard ladder's foot reaches RoutePoint_Belly_4's spot")
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("the scan finishes within the time limit", function()
		expect(buildAndSearchSeconds).toBeLessThanOrEqual(Config.Stuck.ScanSeconds)
	end)
end)
