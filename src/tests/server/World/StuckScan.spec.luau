--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll, afterAll, beforeEach, afterEach =
	JestGlobals.describe,
	JestGlobals.it,
	JestGlobals.expect,
	JestGlobals.beforeAll,
	JestGlobals.afterAll,
	JestGlobals.beforeEach,
	JestGlobals.afterEach

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local PlayerNeeds = require(ServerStorage.Tests.server.World.PlayerNeeds)

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

-- Stuck safety Task 23, test 1 (spec Rule 22, "Rare spots left to the rescue", conditions 1 to 3). A stuck spot is left
-- to the rescue instead of fixed only if all hold: it is on the giant, not in the Meadow zone; it is more than
-- MUST_FIX_DISTANCE studs from every place players need; and the walk map can't reach it from those places. The scan
-- fails on any stuck spot that is not on this list, and on any listed spot that breaks one of the three.
local RARE_PROOF =
	"rescue proof: Task 12 (3 of 3, one try in the Climbing pose); re-measured against the real walk area in plan 5, Task 15"
local MUST_FIX_DISTANCE = 12 -- studs (spec section 5, "Must-fix distance")
local RARE_MATCH = 0.25 -- studs: a stuck spot is "the listed spot" when it is this close (the list is rounded to 0.1)

type StuckSpot = { id: number, position: Vector3, standsOn: BasePart }
type RareSpot = { name: string, group: number, position: Vector3, proof: string }
-- What the check needs to know about the world, so a made-up world can answer for the tests.
type RareFacts = {
	isMeadow: (position: Vector3) -> boolean,
	distanceToPlace: (position: Vector3) -> number, -- to the nearest place players need
	reachedFromPlaces: (position: Vector3) -> boolean,
}

local function rareSpot(name: string, group: number, x: number, y: number, z: number): RareSpot
	return { name = name, group = group, position = Vector3.new(x, y, z), proof = RARE_PROOF }
end

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

local function closedSpot(name: string, piece: string, x: number, y: number, z: number): ClosedSpot
	return { name = name, position = Vector3.new(x, y, z), piece = piece }
end

-- The closed hollows (step 23-S2, t23/sort-23-S2.txt; code_lead's Ruling 8). Each is a stuck spot inside a hollow that
-- no body can enter without passing through his skin, so it is not fixed and not left to the rescue: it is listed by name
-- here, and test 1 fails if it opens, if a link leads into it from outside, or if a place players need lies inside it.
-- The 17-ray closed check (escapingRays) decides, so a spot that fails it is not listed here and stays a stuck spot to fix.
local CLOSED_SPOTS: { ClosedSpot } = {
	-- Inside the Sock (its piece is the Sock model, not a giant piece).
	closedSpot("Closed_Sock_1", "Sock", -68.8, 6.0, -67.0),
	closedSpot("Closed_Sock_2", "Sock", -68.8, 3.0, -63.0),
	closedSpot("Closed_Sock_3", "Sock", -68.8, 2.9, -61.0),
	closedSpot("Closed_Sock_4", "Sock", -66.8, 5.0, -63.0),
	closedSpot("Closed_Sock_5", "Sock", -66.8, 5.1, -61.0),
	-- Inside the beard.
	closedSpot("Closed_Beard_1", "head_with_beard", 3.2, 73.8, 17.0),
	closedSpot("Closed_Beard_2", "head_with_beard", 5.2, 74.2, 13.0),
	-- Inside his left arm.
	closedSpot("Closed_LeftArm_1", "left_arm", -48.8, 29.9, -9.0),
	closedSpot("Closed_LeftArm_2", "left_arm", -48.8, 30.0, -7.0),
	closedSpot("Closed_LeftArm_3", "left_arm", -48.8, 29.5, -1.0),
	closedSpot("Closed_LeftArm_4", "left_arm", -46.8, 27.6, -9.0),
	closedSpot("Closed_LeftArm_5", "left_arm", -46.8, 27.7, -7.0),
	closedSpot("Closed_LeftArm_6", "left_arm", -46.8, 27.8, -5.0),
	closedSpot("Closed_LeftArm_7", "left_arm", -46.8, 27.9, -3.0),
	closedSpot("Closed_LeftArm_8", "left_arm", -44.8, 25.4, -5.0),
	closedSpot("Closed_LeftArm_9", "left_arm", -44.8, 25.5, -3.0),
	closedSpot("Closed_LeftArm_10", "left_arm", -42.8, 24.7, -11.0),
	closedSpot("Closed_LeftArm_11", "left_arm", -42.8, 31.7, -1.0),
	closedSpot("Closed_LeftArm_12", "left_arm", -40.8, 28.8, -11.0),
	closedSpot("Closed_LeftArm_13", "left_arm", -40.8, 28.1, -9.0),
	closedSpot("Closed_LeftArm_14", "left_arm", -40.8, 27.3, -7.0),
	closedSpot("Closed_LeftArm_15", "left_arm", -40.8, 26.5, -5.0),
	closedSpot("Closed_LeftArm_16", "left_arm", -40.8, 25.7, -3.0),
	closedSpot("Closed_LeftArm_17", "left_arm", -38.8, 31.0, -11.0),
	closedSpot("Closed_LeftArm_18", "left_arm", -38.8, 30.2, -9.0),
	closedSpot("Closed_LeftArm_19", "left_arm", -38.8, 29.4, -7.0),
	closedSpot("Closed_LeftArm_20", "left_arm", -38.8, 28.6, -5.0),
	closedSpot("Closed_LeftArm_21", "left_arm", -38.8, 31.8, -3.0),
	-- Inside his right arm.
	closedSpot("Closed_RightArm_1", "right_arm", 39.2, 29.8, -1.0),
	closedSpot("Closed_RightArm_2", "right_arm", 41.2, 27.8, -11.0),
	closedSpot("Closed_RightArm_3", "right_arm", 41.2, 27.4, -9.0),
	closedSpot("Closed_RightArm_4", "right_arm", 41.2, 27.0, -7.0),
	closedSpot("Closed_RightArm_5", "right_arm", 41.2, 26.5, -5.0),
	closedSpot("Closed_RightArm_6", "right_arm", 43.2, 28.7, -11.0),
	closedSpot("Closed_RightArm_7", "right_arm", 45.2, 28.6, -11.0),
	closedSpot("Closed_RightArm_8", "right_arm", 45.2, 25.3, -3.0),
	closedSpot("Closed_RightArm_9", "right_arm", 45.2, 25.8, -1.0),
	closedSpot("Closed_RightArm_10", "right_arm", 47.2, 25.0, -5.0),
	closedSpot("Closed_RightArm_11", "right_arm", 47.2, 26.9, -3.0),
	closedSpot("Closed_RightArm_12", "right_arm", 47.2, 27.4, -1.0),
	closedSpot("Closed_RightArm_13", "right_arm", 49.2, 28.5, -3.0),
	closedSpot("Closed_RightArm_14", "right_arm", 49.2, 29.0, -1.0),
}

-- The indexes of the stuck spots that are not on the rare list.
local function unlistedSpots(positions: { Vector3 }, rare: { RareSpot }): { number }
	local unlisted: { number } = {}
	for index, position in positions do
		local found = false
		for _, spot in rare do
			if (spot.position - position).Magnitude <= RARE_MATCH then
				found = true
				break
			end
		end
		if not found then
			table.insert(unlisted, index)
		end
	end
	return unlisted
end

-- One line for each listed spot that breaks condition 1, 2 or 3.
local function rareBrokenConditions(rare: { RareSpot }, facts: RareFacts): { string }
	local problems: { string } = {}
	for _, spot in rare do
		local where = `{spot.name} at {format(spot.position)}`
		if facts.isMeadow(spot.position) then
			table.insert(problems, `{where}: in the Meadow zone, so the rescue does not cover it (condition 1)`)
		end
		local distance = facts.distanceToPlace(spot.position)
		if distance <= MUST_FIX_DISTANCE then
			table.insert(
				problems,
				string.format(
					"%s: %.1f studs from a place players need, at most %g (condition 2)",
					where,
					distance,
					MUST_FIX_DISTANCE
				)
			)
		end
		if facts.reachedFromPlaces(spot.position) then
			table.insert(problems, `{where}: the walk map reaches it from the places players need (condition 3)`)
		end
	end
	return problems
end

-- Stuck safety Task 23, test 1 (spec Rule 22, "A closed void"; code_lead's Ruling 8 after step 23-S2). A hollow inside
-- his body (or the Sock) that no body can enter without passing through solid is not a stuck spot. The scan lists each
-- one by name and fails if it ever opens. A hollow is closed when, from 2.5 studs over the feet (1 stud over them under
-- a roof lower than 2.8), all 17 rays of 40 studs hit a solid piece of the giant or the Sock: 8 level (every 45
-- degrees), 8 tilted 45 degrees upward on the same headings, and 1 straight up. Two more things fail the test: a walk-map
-- link of any kind (walk, climb or slide; a drop is a slide) that leads into a listed spot from a spot that is not
-- listed, and a place players need (route point, egg spot or landing spot) inside a listed hollow.
local CLOSED_RAY_LENGTH = 40 -- studs
local CLOSED_ABOVE = 2.5 -- studs over the feet where the rays start...
local CLOSED_ABOVE_LOW_ROOF = 1 -- ...or this far under a roof lower than CLOSED_LOW_ROOF
local CLOSED_LOW_ROOF = 2.8 -- studs over the feet
local CLOSED_ROOF_START = 0.05 -- the roof is measured by a ray straight up from this far over the feet
local CLOSED_HEADINGS = 8 -- every 45 degrees
local CLOSED_TILT_DEGREES = 45
local CLOSED_HOLLOW_EYE = 1 -- studs: a line between a spot and a place is cast from this far over each

type Cast = (origin: Vector3, direction: Vector3) -> RaycastResult?
type ClosedSpot = { name: string, position: Vector3, piece: string }
type Place = { name: string, position: Vector3 }
-- What the check needs to know about the world, so a made-up world can answer for the tests.
type ClosedFacts = {
	escapingRays: (position: Vector3) -> number, -- of the 17 rays, how many do not hit a solid piece
	linkedFromOutside: (position: Vector3) -> boolean,
	placeInside: (position: Vector3) -> string?, -- the name of a place players need that lies in this spot's hollow
}

-- The 17 rays, each as a vector of CLOSED_RAY_LENGTH studs.
local function closedRayDirections(): { Vector3 }
	local tilt = math.rad(CLOSED_TILT_DEGREES)
	local directions: { Vector3 } = {}
	for index = 0, CLOSED_HEADINGS - 1 do
		local heading = math.rad(index * 360 / CLOSED_HEADINGS)
		table.insert(directions, Vector3.new(math.cos(heading), 0, math.sin(heading)) * CLOSED_RAY_LENGTH)
		table.insert(
			directions,
			Vector3.new(math.cos(heading) * math.cos(tilt), math.sin(tilt), math.sin(heading) * math.cos(tilt))
				* CLOSED_RAY_LENGTH
		)
	end
	table.insert(directions, Vector3.new(0, CLOSED_RAY_LENGTH, 0))
	return directions
end

-- How many of the 17 rays from `feet` do not hit a solid piece (`isSolid` says which pieces are solid). The rays start
-- 2.5 studs over the feet, or 1 stud over them under a roof lower than 2.8: higher than that, the start would be inside
-- the roof, and a ray that starts inside a piece skips the whole piece.
local function escapingRays(feet: Vector3, cast: Cast, isSolid: (Instance) -> boolean): number
	local roof = cast(feet + Vector3.new(0, CLOSED_ROOF_START, 0), Vector3.new(0, CLOSED_RAY_LENGTH, 0))
	local roofHeight = if roof ~= nil then roof.Distance + CLOSED_ROOF_START else math.huge
	local above = if roofHeight < CLOSED_LOW_ROOF then CLOSED_ABOVE_LOW_ROOF else CLOSED_ABOVE
	local origin = feet + Vector3.new(0, above, 0)
	local escaping = 0
	for _, direction in closedRayDirections() do
		local hit = cast(origin, direction)
		if hit == nil or not isSolid(hit.Instance) then
			escaping += 1
		end
	end
	return escaping
end

-- The spots of `inside` that a link from a spot not in `inside` leads into.
local function linkedInto(links: { [number]: { PathCheck.Link } }, inside: { [number]: boolean }): { [number]: boolean }
	local into: { [number]: boolean } = {}
	for from, outgoing in links do
		if not inside[from] then
			for _, link in outgoing do
				if inside[link.to] then
					into[link.to] = true
				end
			end
		end
	end
	return into
end

-- The names of the places that lie in the hollow of `spot`. A hollow is one body of air, so a place with a clear line to
-- the spot (nothing solid between them, cast from CLOSED_HOLLOW_EYE studs over each) is in it. A place farther than
-- CLOSED_RAY_LENGTH studs is left out: no hollow is that big.
local function placesInHollow(spot: Vector3, places: { Place }, cast: Cast): { string }
	local eye = Vector3.new(0, CLOSED_HOLLOW_EYE, 0)
	local inside: { string } = {}
	for _, place in places do
		local along = (place.position + eye) - (spot + eye)
		if along.Magnitude <= CLOSED_RAY_LENGTH and cast(spot + eye, along) == nil then
			table.insert(inside, place.name)
		end
	end
	return inside
end

-- One line for each listed closed spot that has opened, is linked into from outside, or holds a place players need.
local function closedBrokenConditions(closed: { ClosedSpot }, facts: ClosedFacts): { string }
	local problems: { string } = {}
	for _, spot in closed do
		local where = `{spot.name} at {format(spot.position)} ({spot.piece})`
		local escaping = facts.escapingRays(spot.position)
		if escaping > 0 then
			table.insert(
				problems,
				`{where}: {escaping} of 17 rays leave the hollow, so it has opened and must be fixed or sorted again`
			)
		end
		if facts.linkedFromOutside(spot.position) then
			table.insert(problems, `{where}: a walk-map link leads into it from a spot outside the hollow`)
		end
		local place = facts.placeInside(spot.position)
		if place ~= nil then
			table.insert(problems, `{where}: {place}, a place players need, lies inside its hollow`)
		end
	end
	return problems
end

-- A closed spot written as a rare-list entry, so the one list-matching rule serves both lists.
local function closedAsRare(closed: { ClosedSpot }): { RareSpot }
	local asRare: { RareSpot } = {}
	for _, spot in closed do
		table.insert(asRare, { name = spot.name, group = 0, position = spot.position, proof = "closed hollow" })
	end
	return asRare
end

-- The indexes of the stuck spots that are on neither the rare list nor the closed list.
local function unlistedStuck(positions: { Vector3 }, rare: { RareSpot }, closed: { ClosedSpot }): { number }
	local notRare = unlistedSpots(positions, rare)
	local rest: { Vector3 } = {}
	for _, index in notRare do
		table.insert(rest, positions[index])
	end
	local unlisted: { number } = {}
	for _, restIndex in unlistedSpots(rest, closedAsRare(closed)) do
		table.insert(unlisted, notRare[restIndex])
	end
	return unlisted
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

-- The part of the giant a stuck spot is on (if it stands on one), or else the part whose box is nearest within
-- NEAR_GIANT studs. nil when none is that close.
local function nearestGiantPart(giantParts: { BasePart }, giant: Model, spotOn: BasePart, position: Vector3): BasePart?
	if spotOn:IsDescendantOf(giant) then
		return spotOn
	end
	local best: BasePart? = nil
	local bestDistance = NEAR_GIANT
	for _, part in giantParts do
		local distance = PlayerNeeds.distanceToBox(position, part.CFrame, part.Size)
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

	-- The given stuck spots as text: a summary, then one line each (at most MAX_LINES).
	local function stuckReport(spots: { StuckSpot }): { string }
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
		for _, spot in spots do
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
			`{#spots} stuck spots. Count by giant piece (the piece of the part a spot stands on, else of the nearest part; the pillow has its own line), largest first:`,
		}
		for _, name in names do
			table.insert(report, `  {counts[name]}  {name}`)
		end
		table.insert(report, "Each stuck spot (position, the part it stands on, nearest giant part):")
		for _, line in lines do
			table.insert(report, `  {line}`)
		end
		if #spots > #lines then
			table.insert(report, `  ...and {#spots - #lines} more`)
		end
		return report
	end

	-- Stuck safety Task 23, test 1: what the real world says about Rule 22's conditions 1 to 3 for the rare list. The
	-- places players need are test 3's list: route points and links, egg spots, landing spots, walk pieces (the ladders'
	-- trusses included) and the four Legendary nest points; plus spec 5's walk area (Rule 79). Spec 5's walk area and
	-- the seam are not built yet, so a stand-in is used: the free walk-map spots on his body and arms, in the Belly zone,
	-- on cloth under the seam angle, joined by neighbouring spots to the belly route points and egg spots. When plan 5,
	-- Task 15 builds the real area, any rare spot within MUST_FIX_DISTANCE studs of it turns this test red on its own.
	-- Built once, on first use (it takes a few seconds).
	local WALK_AREA_PIECES: { [string]: boolean } = { body_and_cushion = true, left_arm = true, right_arm = true }
	local WALK_AREA_MAX_DEGREES = 65
	local SEED_STEPS = 2 -- a free spot within this many grid steps of a place players need starts the reach search
	local cachedFacts: RareFacts? = nil

	local function buildRareFacts(): RareFacts
		local giant = giantModel()
		local zoneBoxes = WorldIndex.loadZones(world)
		local route = WorldIndex.loadRoute(world)
		local needs = PlayerNeeds.build(world, route, WorldIndex.loadEggSpots(world), landings)

		-- The walk-area stand-in: the candidate spots, then those joined to the belly route points and egg spots.
		local candidates: { [number]: boolean } = {}
		for _, spot in map.spots do
			local piece = pieceOf(giant, spot.standsOn)
			if
				not stuckIds[spot.id]
				and piece ~= nil
				and WALK_AREA_PIECES[piece]
				and Zones.zoneAt(spot.position, zoneBoxes) == "Belly"
				and math.deg(math.acos(math.clamp(spot.up.Y, -1, 1))) < WALK_AREA_MAX_DEGREES
			then
				candidates[spot.id] = true
			end
		end
		local columns: { [number]: { number } } = {}
		local function columnKey(position: Vector3): number
			return math.floor(position.X / map.spacing) * 100000 + math.floor(position.Z / map.spacing)
		end
		for id in candidates do
			local key = columnKey(map.spots[id].position)
			columns[key] = columns[key] or {}
			table.insert(columns[key], id)
		end
		local joined: { [number]: boolean } = {}
		local queue: { number } = {}
		for _, point in route do
			if string.find(point.name, "^RoutePoint_Belly_") or string.find(point.name, "^RoutePoint_Egg_") then
				local id = PathCheck.nearestSpot(map, point.position, 3 * map.spacing)
				if id ~= nil and candidates[id] and not joined[id] then
					joined[id] = true
					table.insert(queue, id)
				end
			end
		end
		-- One grid step up or down may rise as much as the steepest cloth that still counts as walk area.
		local maxRise = map.spacing * math.tan(math.rad(WALK_AREA_MAX_DEGREES)) + 0.05
		local head = 1
		while head <= #queue do
			local position = map.spots[queue[head]].position
			head += 1
			local key = columnKey(position)
			for dx = -1, 1 do
				for dz = -1, 1 do
					local column: { number } = columns[key + dx * 100000 + dz] or {}
					for _, other in column do
						if not joined[other] then
							local there = map.spots[other].position
							local across = Vector3.new(there.X - position.X, 0, there.Z - position.Z).Magnitude
							if math.abs(there.Y - position.Y) <= maxRise * math.max(across / map.spacing, 0.01) then
								joined[other] = true
								table.insert(queue, other)
							end
						end
					end
				end
			end
		end
		local walkArea: { Vector3 } = {}
		for _, id in queue do
			table.insert(walkArea, map.spots[id].position)
		end

		-- The reach search: from the free spots near a place players need, and from the walk area, over every link.
		local seedRadius = SEED_STEPS * map.spacing
		local reached: { [number]: boolean } = {}
		local frontier: { number } = {}
		for id in joined do
			reached[id] = true
			table.insert(frontier, id)
		end
		for _, spot in map.spots do
			if not stuckIds[spot.id] and not reached[spot.id] then
				local at = spot.position
				for _, need in needs do
					if
						at.X >= need.low.X - seedRadius
						and at.X <= need.high.X + seedRadius
						and at.Y >= need.low.Y - seedRadius
						and at.Y <= need.high.Y + seedRadius
						and at.Z >= need.low.Z - seedRadius
						and at.Z <= need.high.Z + seedRadius
						and need.distance(at) <= seedRadius
					then
						reached[spot.id] = true
						table.insert(frontier, spot.id)
						break
					end
				end
			end
		end
		local index = 1
		while index <= #frontier do
			local id = frontier[index]
			index += 1
			local links: { PathCheck.Link } = map.links[id] or {}
			for _, link in links do
				if not reached[link.to] then
					reached[link.to] = true
					table.insert(frontier, link.to)
				end
			end
		end

		return {
			isMeadow = function(position: Vector3): boolean
				return Zones.zoneAt(position, zoneBoxes) == "Meadow"
			end,
			distanceToPlace = function(position: Vector3): number
				local nearest = PlayerNeeds.nearestDistance(needs, position)
				for _, spot in walkArea do
					nearest = math.min(nearest, (spot - position).Magnitude)
				end
				return nearest
			end,
			reachedFromPlaces = function(position: Vector3): boolean
				for _, spot in map.spots do
					if reached[spot.id] and (spot.position - position).Magnitude <= RARE_MATCH then
						return true
					end
				end
				return false
			end,
		}
	end

	local function rareFacts(): RareFacts
		if cachedFacts == nil then
			cachedFacts = buildRareFacts()
		end
		return cachedFacts :: RareFacts
	end

	-- Stuck safety Task 23, test 1: what the real world says about the closed hollows. The rays use the walk map's
	-- ground settings. A solid piece is any part of the giant or of the Sock. The places players need that can lie in a
	-- hollow are the route points, the egg spots and the landing spots; a safe spot (Rule 27) is only ever saved where
	-- a player stood, and players only stand on the route, so the route stands for them. The spots "inside" are the walk-map
	-- spots on the closed list. Built once, on first use.
	local cachedClosedFacts: ClosedFacts? = nil

	local function buildClosedFacts(): ClosedFacts
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = Collisions.GROUP
		local function cast(origin: Vector3, direction: Vector3): RaycastResult?
			return Workspace:Raycast(origin, direction, params)
		end
		local sock = (world :: any).GiantsThings:FindFirstChild("Sock")
		local function isSolid(instance: Instance): boolean
			return instance:IsDescendantOf(giantModel()) or (sock ~= nil and instance:IsDescendantOf(sock))
		end
		local places: { Place } = {}
		for _, point in WorldIndex.loadRoute(world) do
			table.insert(places, { name = point.name, position = point.position })
		end
		for _, eggSpot in WorldIndex.loadEggSpots(world) do
			table.insert(places, { name = eggSpot.name, position = eggSpot.cframe.Position })
		end
		for _, landing in landings do
			table.insert(places, { name = `LandingSpot_{landing.index}`, position = landing.position })
		end
		local inside: { [number]: boolean } = {}
		for _, spot in map.spots do
			for _, closed in CLOSED_SPOTS do
				if (spot.position - closed.position).Magnitude <= RARE_MATCH then
					inside[spot.id] = true
					break
				end
			end
		end
		local into = linkedInto(map.links, inside)
		return {
			escapingRays = function(position: Vector3): number
				return escapingRays(position, cast, isSolid)
			end,
			linkedFromOutside = function(position: Vector3): boolean
				for _, spot in map.spots do
					if into[spot.id] and (spot.position - position).Magnitude <= RARE_MATCH then
						return true
					end
				end
				return false
			end,
			placeInside = function(position: Vector3): string?
				local names = placesInHollow(position, places, cast)
				return if #names > 0 then table.concat(names, ", ") else nil
			end,
		}
	end

	local function closedFacts(): ClosedFacts
		if cachedClosedFacts == nil then
			cachedClosedFacts = buildClosedFacts()
		end
		return cachedClosedFacts :: ClosedFacts
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
			for _, line in stuckReport(unlisted) do
				table.insert(problems, line)
			end
		end
		local broken = rareBrokenConditions(RARE_SPOTS, rareFacts())
		if #broken > 0 then
			table.insert(problems, "Rare-list spots that no longer meet Rule 22's conditions 1 to 3:")
			for _, problem in broken do
				table.insert(problems, `  {problem}`)
			end
		end
		local opened = closedBrokenConditions(CLOSED_SPOTS, closedFacts())
		if #opened > 0 then
			table.insert(problems, "Closed-list hollows that are no longer closed, unlinked and empty:")
			for _, problem in opened do
				table.insert(problems, `  {problem}`)
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

-- Stuck safety Task 23, test 1's made-up-world tests: the rare-spot check must be able to fail. The made-up world has
-- one place players need at its centre, a Meadow zone below y 0, and a list of positions the walk map reaches.
describe("the rare-spot check on a made-up world", function()
	local PLACE = Vector3.new(0, 0, 0)

	local function madeUpFacts(reached: { Vector3 }): RareFacts
		return {
			isMeadow = function(position: Vector3): boolean
				return position.Y < 0
			end,
			distanceToPlace = function(position: Vector3): number
				return (position - PLACE).Magnitude
			end,
			reachedFromPlaces = function(position: Vector3): boolean
				for _, spot in reached do
					if (spot - position).Magnitude <= RARE_MATCH then
						return true
					end
				end
				return false
			end,
		}
	end

	local function listed(name: string, position: Vector3): RareSpot
		return { name = name, group = 1, position = position, proof = RARE_PROOF }
	end

	local function has(text: string, part: string): boolean
		return string.find(text, part, 1, true) ~= nil
	end

	it("a stuck spot that is not on the rare list fails", function()
		local onList = Vector3.new(0, 30, 0)
		local notOnList = Vector3.new(4, 30, 4)
		local unlisted = unlistedSpots({ onList, notOnList }, { listed("Rare_Made_Up_1", onList) })
		expect(unlisted).toEqual({ 2 })
	end)

	it("a listed rare spot within 12 studs of a place players need fails", function()
		local near = madeUpFacts({})
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 11.9, 0)) }, near)
		expect(#problems).toBe(1)
		expect(has(problems[1], "Rare_Made_Up_1")).toBe(true)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
		-- Just past 12 studs, nothing is wrong.
		expect(rareBrokenConditions({ listed("Rare_Made_Up_2", Vector3.new(0, 12.1, 0)) }, near)).toEqual({})
	end)

	-- The places players need come from a made-up world: a model with a WalkSurfaces folder, and the seam's folder.
	-- Nothing else (no route, egg spots or landing spots).
	local function factsFromMadeUpWorld(build: (world: Model) -> ()): RareFacts
		local world = Instance.new("Model")
		world.Name = "MadeUpPlacesWorld"
		build(world)
		local needs = PlayerNeeds.build(world, {}, {}, {})
		world:Destroy()
		return {
			isMeadow = function(): boolean
				return false
			end,
			distanceToPlace = function(position: Vector3): number
				return PlayerNeeds.nearestDistance(needs, position)
			end,
			reachedFromPlaces = function(): boolean
				return false
			end,
		}
	end

	local function addPiece(parent: Instance, name: string, position: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(4, 1, 10)
		part.Position = position
		part.Parent = parent
	end

	local function folderIn(parent: Instance, name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end

	it("a listed rare spot within 12 studs of a Belly_Walk piece fails", function()
		local facts = factsFromMadeUpWorld(function(world)
			addPiece(folderIn(world, "WalkSurfaces"), "Belly_Walk", Vector3.new(0, 50, 0))
		end)
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 60, 0)) }, facts)
		expect(#problems).toBe(1)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
		-- 20 studs from the piece's top is far enough.
		expect(rareBrokenConditions({ listed("Rare_Made_Up_2", Vector3.new(0, 71, 0)) }, facts)).toEqual({})
	end)

	it("a listed rare spot within 12 studs of a seam piece fails", function()
		local facts = factsFromMadeUpWorld(function(world)
			addPiece(folderIn(world, "Seam"), "Stitch_1", Vector3.new(0, 50, 0))
		end)
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 60, 0)) }, facts)
		expect(#problems).toBe(1)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
	end)

	it("a listed rare spot the walk map reaches from the places fails", function()
		local spot = Vector3.new(0, 30, 0)
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", spot) }, madeUpFacts({ spot }))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Rare_Made_Up_1")).toBe(true)
		expect(has(problems[1], "walk map reaches it")).toBe(true)
	end)

	it("a listed rare spot in the Meadow zone fails", function()
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, -30, 0)) }, madeUpFacts({}))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Rare_Made_Up_1")).toBe(true)
		expect(has(problems[1], "Meadow zone")).toBe(true)
	end)

	it("a listed rare spot that meets all three passes", function()
		local spot = Vector3.new(0, 30, 0)
		local elsewhere = Vector3.new(0, 20, 0)
		expect(rareBrokenConditions({ listed("Rare_Made_Up_1", spot) }, madeUpFacts({ elsewhere }))).toEqual({})
		expect(unlistedSpots({ spot }, { listed("Rare_Made_Up_1", spot) })).toEqual({})
	end)
end)

-- Stuck safety Task 23, test 1's closed-void tests on a made-up world: the closed check must be able to fail. The made-up
-- world is a hollow box of walls in a WorldModel (it answers rays like the real Workspace). The inside of the box is
-- 12 studs wide in x and z, and its floor's top is y 0, where the feet stand.
describe("the closed-void check on a made-up world", function()
	local HALF = 6 -- studs: half the inside width
	local WALL = 1 -- studs thick
	local world: WorldModel

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "ClosedVoidTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		world.Parent = ServerStorage
	end)

	afterEach(function()
		local made = world :: WorldModel? -- nil if the first beforeEach failed before it made the world
		if made ~= nil then
			made:Destroy()
		end
	end)

	local function wall(name: string, size: Vector3, center: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.Position = center
		part.Parent = world
	end

	-- A hollow box with a floor, a roof and four side walls (the walls overlap at the corners, so there is no gap).
	-- `height` is the inside height. `leaveOut` names a side that gets no wall: "+x", "-x", "+z" or "-z".
	local function hollowBox(height: number, leaveOut: string?)
		local across = 2 * (HALF + WALL)
		local tall = height + 2 * WALL
		local middle = height / 2
		wall("Floor", Vector3.new(across, WALL, across), Vector3.new(0, -WALL / 2, 0))
		wall("Roof", Vector3.new(across, WALL, across), Vector3.new(0, height + WALL / 2, 0))
		local out = HALF + WALL / 2
		if leaveOut ~= "+x" then
			wall("SideEast", Vector3.new(WALL, tall, across), Vector3.new(out, middle, 0))
		end
		if leaveOut ~= "-x" then
			wall("SideWest", Vector3.new(WALL, tall, across), Vector3.new(-out, middle, 0))
		end
		if leaveOut ~= "+z" then
			wall("SideSouth", Vector3.new(across, tall, WALL), Vector3.new(0, middle, out))
		end
		if leaveOut ~= "-z" then
			wall("SideNorth", Vector3.new(across, tall, WALL), Vector3.new(0, middle, -out))
		end
	end

	local function cast(origin: Vector3, direction: Vector3): RaycastResult?
		return world:Raycast(origin, direction)
	end

	local function inWorld(instance: Instance): boolean
		return instance:IsDescendantOf(world)
	end

	local function link(to: number): PathCheck.Link
		return { to = to, kind = "Walk", length = 1, seconds = 1 }
	end

	local function closedAt(name: string, position: Vector3): ClosedSpot
		return { name = name, position = position, piece = "made_up_piece" }
	end

	local function has(text: string, part: string): boolean
		return string.find(text, part, 1, true) ~= nil
	end

	-- What a world with these answers says about one listed spot.
	local function facts(escaping: number, linked: boolean, place: string?): ClosedFacts
		return {
			escapingRays = function(): number
				return escaping
			end,
			linkedFromOutside = function(): boolean
				return linked
			end,
			placeInside = function(): string?
				return place
			end,
		}
	end

	it("the closed check casts 8 level, 8 tilted and 1 straight up ray of 40 studs", function()
		local level, tilted, up = 0, 0, 0
		local directions = closedRayDirections()
		for _, direction in directions do
			expect(math.abs(direction.Magnitude - CLOSED_RAY_LENGTH) < 1e-6).toBe(true)
			if math.abs(direction.Y) < 1e-6 then
				level += 1
			elseif math.abs(direction.Y - CLOSED_RAY_LENGTH) < 1e-6 then
				up += 1
			elseif math.abs(direction.Y - CLOSED_RAY_LENGTH * math.sin(math.rad(CLOSED_TILT_DEGREES))) < 1e-6 then
				tilted += 1
			end
		end
		expect({ #directions, level, tilted, up }).toEqual({ 17, 8, 8, 1 })
	end)

	it("a sealed box has no ray that gets out", function()
		hollowBox(12, nil)
		expect(escapingRays(Vector3.zero, cast, inWorld)).toBe(0)
	end)

	it("a box with one open side lets the rays toward that side out", function()
		hollowBox(12, "+x")
		-- The level ray and the tilted ray on heading 0 (toward +x) leave. The tilted ray on each diagonal still
		-- meets a side wall, because the box is 12 tall.
		expect(escapingRays(Vector3.zero, cast, inWorld)).toBe(2)
	end)

	it("under a roof lower than 2.8 studs the rays start 1 stud over the feet", function()
		-- The roof's underside is 2.2 over the feet and the roof is 1 thick, so a start 2.5 over the feet would be
		-- inside the roof, and every ray that goes up would get out above it.
		hollowBox(2.2, nil)
		expect(escapingRays(Vector3.zero, cast, inWorld)).toBe(0)
	end)

	it("a place inside the hollow is found, and a place behind a wall is not", function()
		hollowBox(12, nil)
		local places: { Place } = {
			{ name = "Inside_EggSpot", position = Vector3.new(3, 0, 3) },
			{ name = "Outside_RoutePoint", position = Vector3.new(20, 0, 0) },
		}
		expect(placesInHollow(Vector3.zero, places, cast)).toEqual({ "Inside_EggSpot" })
	end)

	it("a place in the open air beside an open box is in the same air", function()
		hollowBox(12, "+x")
		local places: { Place } = { { name = "Outside_LandingSpot", position = Vector3.new(20, 0, 0) } }
		expect(placesInHollow(Vector3.zero, places, cast)).toEqual({ "Outside_LandingSpot" })
	end)

	it("a link from outside into the hollow is found, and a link inside it is not", function()
		local inside = { [2] = true, [3] = true }
		expect(linkedInto({ [1] = { link(2) }, [2] = { link(3) }, [4] = { link(3) } }, inside)).toEqual({
			[2] = true,
			[3] = true,
		})
		expect(linkedInto({ [2] = { link(3) }, [3] = { link(2) } }, inside)).toEqual({})
	end)

	it("a listed closed spot that has opened fails", function()
		local problems = closedBrokenConditions({ closedAt("Closed_Made_Up_1", Vector3.zero) }, facts(2, false, nil))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Closed_Made_Up_1")).toBe(true)
		expect(has(problems[1], "2 of 17 rays")).toBe(true)
	end)

	it("a listed closed spot that a link from outside leads into fails", function()
		local problems = closedBrokenConditions({ closedAt("Closed_Made_Up_1", Vector3.zero) }, facts(0, true, nil))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Closed_Made_Up_1")).toBe(true)
		expect(has(problems[1], "link")).toBe(true)
	end)

	it("a listed closed spot with a place players need inside its hollow fails", function()
		local problems = closedBrokenConditions(
			{ closedAt("Closed_Made_Up_1", Vector3.zero) },
			facts(0, false, "RoutePoint_Made_Up")
		)
		expect(#problems).toBe(1)
		expect(has(problems[1], "Closed_Made_Up_1")).toBe(true)
		expect(has(problems[1], "RoutePoint_Made_Up")).toBe(true)
	end)

	it("a listed closed spot that is still closed, unlinked and empty passes", function()
		expect(closedBrokenConditions({ closedAt("Closed_Made_Up_1", Vector3.zero) }, facts(0, false, nil))).toEqual({})
	end)

	it("a stuck spot on the closed list is not unlisted, and one on neither list is", function()
		local onRare = Vector3.new(0, 30, 0)
		local onClosed = Vector3.new(4, 30, 4)
		local onNeither = Vector3.new(8, 30, 8)
		local unlisted = unlistedStuck(
			{ onRare, onClosed, onNeither },
			{ rareSpot("Rare_Made_Up_1", 1, 0, 30, 0) },
			{ closedAt("Closed_Made_Up_1", onClosed) }
		)
		expect(unlisted).toEqual({ 3 })
	end)
end)
