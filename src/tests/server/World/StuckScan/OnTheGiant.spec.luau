--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll, afterAll =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll, JestGlobals.afterAll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PlayerNeeds = require(ServerStorage.Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
type Landing = Helpers.Landing
type RareSpot = Helpers.RareSpot
type StuckSpot = Helpers.StuckSpot
local CLOSED_SPOTS = Helpers.CLOSED_SPOTS
local LADDER_REACH_STEPS = Helpers.LADDER_REACH_STEPS
local NEST_REACH = Helpers.NEST_REACH
local closedBrokenConditions = Helpers.closedBrokenConditions
local format = Helpers.format
local rareBrokenConditions = Helpers.rareBrokenConditions
local rareSpot = Helpers.rareSpot
local unlistedStuck = Helpers.unlistedStuck
local ScanFacts = require(script.Parent.ScanFacts)
local giantModel = ScanFacts.giantModel
local namedProblems = ScanFacts.namedProblems
local stuckReport = ScanFacts.stuckReport
local rareFacts = ScanFacts.rareFacts
local closedFacts = ScanFacts.closedFacts
local WalkFacts = require(script.Parent.WalkFacts)
local walkTowardCave = WalkFacts.walkTowardCave
local ladderEndSpots = WalkFacts.ladderEndSpots
local hasClimbLink = WalkFacts.hasClimbLink
local canWalk = WalkFacts.canWalk
local spotsNearNest = WalkFacts.spotsNearNest
local sortedNames = WalkFacts.sortedNames

local SCAN_TIMEOUT_MS = 150000 -- Jest's limit for the build: more than the scan's own 120 seconds

local BELOW_AND_ABOVE = 5 -- studs the scan area reaches below the lowest ground and above the giant

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

-- Stuck safety Task 22, test 4 (game_creator's check 5): the way to the beard ladder stays open. The walk-map spots
-- within BEARD_FOOT_RADIUS studs of the ladder's foot must not drop below what they were before the patches.
local BEARD_FOOT_SPOTS = 4 -- measured in step 22-0, after Task 25

local BEARD_FOOT_RADIUS = 4 -- studs

-- Stuck safety Task 23, test 3: the hump top under his cushion, where Task 22's seat walks 5 and 10 ended their push
-- (plan, Task 23, "walks 5 and 10"). Walk 5's point is the plan's hump top; walk 10's is its 30 degree twin, the push end
-- written in "t22/walk-22-14a2.txt" (line W10: push end (9.5, 25.1, 40.8)). Those are positions of the walker's root
-- part; a walk-map spot is where the feet stand, so each point is the root position minus FEET_BELOW_ROOT. Each needs a
-- walk-map spot within HUMP_REACH studs, and a route from that spot to a meadow exit.
-- A standing R15 root is half the root's height plus the hip height over the ground (the Humanoid.HipHeight page of the
-- Roblox docs): half of 2 plus 2 is 3. The project's own tests use the same rig (a 2 x 2 x 1 root, HipHeight 2).
local FEET_BELOW_ROOT = 3 -- studs

local HUMP_TOPS: { [string]: Vector3 } = {
	["hump top, walk 5"] = Vector3.new(10.5, 24.6 - FEET_BELOW_ROOT, 40.8),
	["hump top, walk 10"] = Vector3.new(9.5, 25.1 - FEET_BELOW_ROOT, 40.8),
}

-- The nearest grid column is at most 1.41 studs away sideways (the grid spacing is 2, so the farthest point of a cell is
-- 1.41 studs from its column), and on a 70 degree slope that is up to 4.13 studs away in a straight line (1.414 / cos 70
-- degrees; 70 degrees is the steepest face a push can end on).
local HUMP_REACH = 4.2 -- studs

-- The four Legendary nest points are in PlayerNeeds (one list for every check); these pick one pair, by name.
local function nestsIn(group: string): { [string]: Vector3 }
	local picked: { [string]: Vector3 } = {}
	for _, nest in PlayerNeeds.NESTS do
		if nest.group == group then
			picked[nest.name] = nest.position
		end
	end
	return picked
end

local BRIM_NESTS = nestsIn("brim")

local SIDE_NESTS = nestsIn("side")

-- Stuck safety Task 22, test 1: the places the patches and the pillow's closer fit close. Each is a box (x, y, z minimum
-- and maximum) around a group of stuck spots from the list after Task 26 (287 spots in 43 groups, 2026-10-21; the group
-- numbers are the start list's). No stuck spot may lie in any of them, on every run, like the named V1 spots.
type FixedPlace = { name: string, min: Vector3, max: Vector3 }

-- Stuck safety Task 23, test 2: one box for each must-fix group of the start list after Task 22 (74 stuck spots in 33
-- groups, "t22/start-list-task23.md"; the 8 groups that hold only rare spots, RARE_SPOTS, have no box). A box is the
-- group's extent from that list plus GROUP_BOX_MARGIN studs on every side. A group of one spot has the spot as both
-- corners.
local GROUP_BOX_MARGIN = 1 -- studs

local function groupBox(name: string, lowest: Vector3, highest: Vector3): FixedPlace
	local margin = Vector3.new(GROUP_BOX_MARGIN, GROUP_BOX_MARGIN, GROUP_BOX_MARGIN)
	return { name = name, min = lowest - margin, max = highest + margin }
end

local FIXED_PLACES: { FixedPlace } = {
	-- Group 1: the flat top of the chair's back cushion, under the pillow.
	{ name = "cushion top behind his head", min = Vector3.new(-30, 48, 49), max = Vector3.new(30, 58, 69) },
	-- Group 2: the sealed air pocket under the cushion, inside the chair's back.
	{ name = "cave under the cushion", min = Vector3.new(-21, 22, 49), max = Vector3.new(21, 36, 59) },
	-- Groups 3, 18, 39 and 41: behind his head, on the right.
	{ name = "behind his head, right", min = Vector3.new(14, 96, 36), max = Vector3.new(30, 114.5, 52) },
	-- Groups 4, 13 and 42: behind his head, on the left.
	{ name = "behind his head, left", min = Vector3.new(-28, 99, 36), max = Vector3.new(-9, 114.5, 54) },
	-- Task 23: the 33 groups of "t22/start-list-task23.md" (extent from its table, plus GROUP_BOX_MARGIN on each side).
	groupBox("ledge between the boots, group 1", Vector3.new(-2.8, 6.2, -37), Vector3.new(3.2, 6.3, -31)),
	groupBox("chair's side, group 2", Vector3.new(15.2, 18.2, 39), Vector3.new(23.2, 21.2, 39)),
	groupBox("pillow's back, group 3", Vector3.new(-22.8, 90.9, 65), Vector3.new(-16.8, 94.2, 65)),
	groupBox("pillow's back, group 4", Vector3.new(-16.8, 88.9, 67), Vector3.new(-10.8, 90.3, 67)),
	groupBox("pillow's back, group 5", Vector3.new(-0.8, 85.6, 69), Vector3.new(5.2, 85.8, 69)),
	groupBox("pillow's back, group 6", Vector3.new(9.2, 84, 69), Vector3.new(15.2, 85.2, 69)),
	groupBox("pillow's back, group 7", Vector3.new(-16.8, 83.5, 69), Vector3.new(-12.8, 84.5, 69)),
	groupBox("pillow's back, group 8", Vector3.new(13.2, 88.8, 67), Vector3.new(17.2, 89.9, 67)),
	groupBox("pillow's back, group 9", Vector3.new(17.2, 92.3, 65), Vector3.new(21.2, 94.2, 65)),
	groupBox("chair's side, group 10", Vector3.new(19.2, 14.5, 37), Vector3.new(23.2, 16.7, 37)),
	groupBox("pillow's back, group 12", Vector3.new(-22.8, 96.1, 63), Vector3.new(-20.8, 97.3, 63)),
	groupBox("pillow's back, group 13", Vector3.new(1.2, 80.2, 71), Vector3.new(3.2, 80.3, 71)),
	groupBox("pillow's back, group 14", Vector3.new(11.2, 79, 71), Vector3.new(13.2, 79.5, 71)),
	groupBox("pillow's back, group 15", Vector3.new(21.2, 96.1, 63), Vector3.new(23.2, 97.3, 63)),
	groupBox("chair's side, group 16", Vector3.new(21.2, 10.9, 35), Vector3.new(23.2, 12.2, 35)),
	groupBox("chair's side, group 17", Vector3.new(-30.8, 6.4, 1), Vector3.new(-30.8, 6.4, 1)),
	groupBox("pillow's edge, group 19", Vector3.new(-22.8, 100.8, 61), Vector3.new(-22.8, 100.8, 61)),
	groupBox("under the chin, group 21", Vector3.new(-6.8, 81.5, -11), Vector3.new(-6.8, 81.5, -11)),
	groupBox("under the chin, group 25", Vector3.new(7.2, 81.1, -11), Vector3.new(7.2, 81.1, -11)),
	groupBox("under the chin, group 27", Vector3.new(9.2, 77.3, -13), Vector3.new(9.2, 77.3, -13)),
	groupBox("right forehead band, group 28", Vector3.new(11.2, 98.2, 1), Vector3.new(11.2, 98.2, 1)),
	groupBox("chair's side, group 31", Vector3.new(33.2, 6.4, -3), Vector3.new(33.2, 6.4, -3)),
	groupBox("chair's side, group 33", Vector3.new(35.2, 6.5, -7), Vector3.new(35.2, 6.5, -7)),
	-- Step 23-S2 (t23/sort-23-S2.txt): the must-fix spots that the walk-map fix showed. The two open cushion spots at the
	-- front edge of the cave under the cushion (product: found by real play in Task 22), and the Sock's one open spot
	-- (the Sock is in the Meadow zone, where the rescue does not cover a stuck player).
	groupBox("under the cushion, front edge", Vector3.new(-16.8, 27.6, 43), Vector3.new(-14.8, 27.6, 43)),
	groupBox("the Sock's open spot", Vector3.new(-68.8, 4.4, -45), Vector3.new(-68.8, 4.4, -45)),
	-- Task 23: the small-place boxes that are still fixed, with the plan's exact numbers (plan, Task 23, "the 10 small
	-- spots"): group 30 (right side of the neck) and group 23 (under the brim). The plan's other four small boxes
	-- (groups 20, 26 and 29 at the back of the neck, 11 and 32 on the right chair arm, 18 on the left chair arm) and
	-- the boxes of groups 22 and 24 (between the knees) hold only rare spots (RARE_SPOTS), so they are gone.
	{ name = "right side of the neck, group 30", min = Vector3.new(23, 58.5, 9), max = Vector3.new(27.5, 63, 13) },
	{ name = "under the brim, group 23", min = Vector3.new(-3, 111, 9), max = Vector3.new(1.5, 115.5, 13) },
}

local FIXED_PLACE_SPOTS_SHOWN = 3 -- stuck spots written out for each place that fails

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

-- The 15 rare spots. The first 10 are from step 23-S (t23/sort-23-S.txt, after the re-measure against Rule 79's walk
-- area); their names are the start list's group numbers. Group 30 (the right side of the neck, 4.4 studs from the right
-- arm top) is not here. The last 5 are from step 23-S2 (t23/sort-23-S2.txt; product checked each one): two pockets
-- between the knees, a pocket in the right arm and two spots on the nightcap. They belong to no start-list group, so
-- their group is 0. A knee pocket that is re-measured under MUST_FIX_DISTANCE studs from a place players need turns this
-- test red on its own.
local RARE_SPOTS: { RareSpot } = {
	rareSpot("Rare_G11_1", 11, 25.2, 11.5, 9), -- right chair arm, low
	rareSpot("Rare_G11_2", 11, 25.2, 11.7, 9),
	rareSpot("Rare_G11_3", 11, 27.2, 12.3, 7),
	rareSpot("Rare_G18_1", 18, -28.8, 13.4, 5), -- left chair arm
	rareSpot("Rare_G20_1", 20, -8.8, 49.4, 39), -- back of the neck
	rareSpot("Rare_G22_1", 22, -2.8, 23, -37), -- between the knees
	rareSpot("Rare_G24_1", 24, 3.2, 23, -37), -- between the knees
	rareSpot("Rare_G26_1", 26, 9.2, 49.7, 39), -- back of the neck
	rareSpot("Rare_G29_1", 29, 13.2, 50.1, 37), -- back of the neck
	rareSpot("Rare_G32_1", 32, 35.2, 18.4, -5), -- right chair arm, high
	rareSpot("Rare_Knees_1", 0, -4.8, 23.4, -39), -- a pocket between the knees
	rareSpot("Rare_Knees_2", 0, 5.2, 23, -41), -- a pocket between the knees
	rareSpot("Rare_RightArm_1", 0, 41.2, 25, -15), -- a pocket in the right arm
	rareSpot("Rare_Nightcap_1", 0, -40.8, 77.9, 45), -- the left end of the nightcap
	rareSpot("Rare_Nightcap_2", 0, 41.2, 78.2, 45), -- the right end of the nightcap
}

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
		expect(#landings).toBe(8)
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
		for _, index in unlistedStuck(positions, RARE_SPOTS, CLOSED_SPOTS) do
			table.insert(unlisted, stuck[index])
		end
		if #unlisted > 0 then
			table.insert(problems, "Stuck spots that are on neither the rare list nor the closed list:")
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
end)
