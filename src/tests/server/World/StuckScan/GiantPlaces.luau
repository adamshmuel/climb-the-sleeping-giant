--!strict
-- The places and numbers the stuck scan on the real world (OnTheGiant.spec) checks, moved out of it so the spec has room
-- for the way-up route tests (plan 3, Task 9, Step 1). The lines below are unchanged from the spec.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local PlayerNeeds = require(ServerStorage.Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
type Landing = Helpers.Landing
type RareSpot = Helpers.RareSpot
local rareSpot = Helpers.rareSpot

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
	groupBox("chair's side, group 10", Vector3.new(19.2, 14.5, 37), Vector3.new(23.2, 16.7, 37)),
	groupBox("chair's side, group 16", Vector3.new(21.2, 10.9, 35), Vector3.new(23.2, 12.2, 35)),
	groupBox("chair's side, group 17", Vector3.new(-30.8, 6.4, 1), Vector3.new(-30.8, 6.4, 1)),
	-- Group 21 (the beard wedge) is accepted for now (spec Rule 22); spec 10, Launch polish, brings this box back.
	groupBox("under the chin, group 25", Vector3.new(7.2, 81.1, -11), Vector3.new(7.2, 81.1, -11)),
	groupBox("under the chin, group 27", Vector3.new(9.2, 77.3, -13), Vector3.new(9.2, 77.3, -13)),
	groupBox("right forehead band, group 28", Vector3.new(11.2, 98.2, 1), Vector3.new(11.2, 98.2, 1)),
	groupBox("chair's side, group 31", Vector3.new(33.2, 6.4, -3), Vector3.new(33.2, 6.4, -3)),
	groupBox("chair's side, group 33", Vector3.new(35.2, 6.5, -7), Vector3.new(35.2, 6.5, -7)),
	-- Step 23-S2 (t23/sort-23-S2.txt): the must-fix spots that the walk-map fix showed. The two open cushion spots at the
	-- front edge of the cave under the cushion (product: found by real play in Task 22), and the Sock's one open spot
	-- (the Sock is in the Meadow zone, where the rescue does not cover a stuck player).
	groupBox("under the cushion, front edge", Vector3.new(-16.8, 27.6, 43), Vector3.new(-14.8, 27.6, 43)),
	groupBox("the Sock's open spot", Vector3.new(-70.8, 4.4, 35), Vector3.new(-70.8, 4.4, 35)),
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

-- The 76 rare spots. The first 10 are from step 23-S (t23/sort-23-S.txt, after the re-measure against Rule 79's walk
-- area); their names are the start list's group numbers. Group 30 (the right side of the neck, 4.4 studs from the right
-- arm top) is not here. The last 5 are from step 23-S2 (t23/sort-23-S2.txt; product checked each one): two pockets
-- between the knees, a pocket in the right arm and two spots on the nightcap. They belong to no start-list group, so
-- their group is 0. A knee pocket that is re-measured under MUST_FIX_DISTANCE studs from a place players need turns this
-- test red on its own.
-- The last 61 (Rare_Cap_*) are from Task 41: the flat pillow left them reachable only by a jump or a fall; their rescue
-- proof is Task 12's.
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
	-- Task 41: the nightcap's lower sides and back, reached only by a jump or a fall (product, 2026-10-27, work/t41/decision-cap-spots.md); rescue proof in Task 12
	rareSpot("Rare_Cap_1", 0, 35.2, 86.5, 39),
	rareSpot("Rare_Cap_2", 0, -32.8, 79.7, 41),
	rareSpot("Rare_Cap_3", 0, 33.2, 79.8, 41),
	rareSpot("Rare_Cap_4", 0, 35.2, 79.2, 41),
	rareSpot("Rare_Cap_5", 0, -38.8, 78.3, 43),
	rareSpot("Rare_Cap_6", 0, -36.8, 77.9, 43),
	rareSpot("Rare_Cap_7", 0, -34.8, 77.1, 43),
	rareSpot("Rare_Cap_8", 0, 35.2, 77.1, 43),
	rareSpot("Rare_Cap_9", 0, 37.2, 77.9, 43),
	rareSpot("Rare_Cap_10", 0, 39.2, 78.5, 43),
	rareSpot("Rare_Cap_11", 0, -38.8, 77.7, 45),
	rareSpot("Rare_Cap_12", 0, -36.8, 77.6, 45),
	rareSpot("Rare_Cap_13", 0, -34.8, 76.9, 45),
	rareSpot("Rare_Cap_14", 0, 31.2, 77.8, 45),
	rareSpot("Rare_Cap_15", 0, 35.2, 77.1, 45),
	rareSpot("Rare_Cap_16", 0, 37.2, 77.6, 45),
	rareSpot("Rare_Cap_17", 0, 39.2, 77.8, 45),
	rareSpot("Rare_Cap_18", 0, -38.8, 77.2, 47),
	rareSpot("Rare_Cap_19", 0, -36.8, 77.2, 47),
	rareSpot("Rare_Cap_20", 0, -34.8, 76.6, 47),
	rareSpot("Rare_Cap_21", 0, -30.8, 78.8, 47),
	rareSpot("Rare_Cap_22", 0, 31.2, 78.5, 47),
	rareSpot("Rare_Cap_23", 0, 35.2, 76.9, 47),
	rareSpot("Rare_Cap_24", 0, 37.2, 77.1, 47),
	rareSpot("Rare_Cap_25", 0, 39.2, 77.1, 47),
	rareSpot("Rare_Cap_26", 0, 41.2, 77.6, 47),
	rareSpot("Rare_Cap_27", 0, -38.8, 76.9, 49),
	rareSpot("Rare_Cap_28", 0, -36.8, 76.6, 49),
	rareSpot("Rare_Cap_29", 0, -32.8, 77, 49),
	rareSpot("Rare_Cap_30", 0, -30.8, 79.4, 49),
	rareSpot("Rare_Cap_31", 0, 29.2, 80.3, 49),
	rareSpot("Rare_Cap_32", 0, 31.2, 78.8, 49),
	rareSpot("Rare_Cap_33", 0, 35.2, 76.4, 49),
	rareSpot("Rare_Cap_34", 0, 37.2, 76.8, 49),
	rareSpot("Rare_Cap_35", 0, -34.8, 76.9, 51),
	rareSpot("Rare_Cap_36", 0, -32.8, 78.2, 51),
	rareSpot("Rare_Cap_37", 0, -30.8, 80.1, 51),
	rareSpot("Rare_Cap_38", 0, -28.8, 81.7, 51),
	rareSpot("Rare_Cap_39", 0, 29.2, 81.9, 51),
	rareSpot("Rare_Cap_40", 0, 31.2, 79.5, 51),
	rareSpot("Rare_Cap_41", 0, 33.2, 77.5, 51),
	rareSpot("Rare_Cap_42", 0, -32.8, 80.7, 53),
	rareSpot("Rare_Cap_43", 0, -30.8, 82.2, 53),
	rareSpot("Rare_Cap_44", 0, -28.8, 83.8, 53),
	rareSpot("Rare_Cap_45", 0, 27.2, 83.5, 53),
	rareSpot("Rare_Cap_46", 0, 29.2, 83.3, 53),
	rareSpot("Rare_Cap_47", 0, 31.2, 81.5, 53),
	rareSpot("Rare_Cap_48", 0, 35.2, 79.2, 53),
	rareSpot("Rare_Cap_49", 0, -30.8, 85.4, 55),
	rareSpot("Rare_Cap_50", 0, -28.8, 86.3, 55),
	rareSpot("Rare_Cap_51", 0, -26.8, 87.4, 55),
	rareSpot("Rare_Cap_52", 0, 27.2, 87.1, 55),
	rareSpot("Rare_Cap_53", 0, 29.2, 86.4, 55),
	rareSpot("Rare_Cap_54", 0, 31.2, 85.2, 55),
	rareSpot("Rare_Cap_55", 0, 33.2, 85.7, 55),
	rareSpot("Rare_Cap_56", 0, -26.8, 90.9, 57),
	rareSpot("Rare_Cap_57", 0, 25.2, 90.8, 57),
	rareSpot("Rare_Cap_58", 0, 27.2, 90.7, 57),
	rareSpot("Rare_Cap_59", 0, 29.2, 90.5, 57),
	rareSpot("Rare_Cap_60", 0, 13.2, 83.6, 63),
	rareSpot("Rare_Cap_61", 0, 7.2, 84.5, 65),
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

return {
	SCAN_TIMEOUT_MS = SCAN_TIMEOUT_MS,
	UNDER_LEFT_ARMREST = UNDER_LEFT_ARMREST,
	UNDER_RIGHT_ARMREST = UNDER_RIGHT_ARMREST,
	FRONT_OF_CHAIR = FRONT_OF_CHAIR,
	NEAR_A_POINT = NEAR_A_POINT,
	LANDING_RAY_ABOVE = LANDING_RAY_ABOVE,
	LANDING_RAY_LENGTH = LANDING_RAY_LENGTH,
	BEARD_FOOT_SPOTS = BEARD_FOOT_SPOTS,
	BEARD_FOOT_RADIUS = BEARD_FOOT_RADIUS,
	HUMP_TOPS = HUMP_TOPS,
	HUMP_REACH = HUMP_REACH,
	BRIM_NESTS = BRIM_NESTS,
	SIDE_NESTS = SIDE_NESTS,
	FIXED_PLACES = FIXED_PLACES,
	FIXED_PLACE_SPOTS_SHOWN = FIXED_PLACE_SPOTS_SHOWN,
	CAVE_TRAP_START = CAVE_TRAP_START,
	CAVE_HUMP_XS = CAVE_HUMP_XS,
	CAVE_HUMP_Y = CAVE_HUMP_Y,
	CAVE_HUMP_Z = CAVE_HUMP_Z,
	CAVE_LEDGE_LEFT = CAVE_LEDGE_LEFT,
	CAVE_LEDGE_RIGHT = CAVE_LEDGE_RIGHT,
	CAVE_HUMP_TURNS = CAVE_HUMP_TURNS,
	CAVE_LEDGE_TURNS = CAVE_LEDGE_TURNS,
	CAVE_LEDGE_LEFT_HEADING = CAVE_LEDGE_LEFT_HEADING,
	CAVE_LEDGE_RIGHT_HEADING = CAVE_LEDGE_RIGHT_HEADING,
	RARE_SPOTS = RARE_SPOTS,
	scanArea = scanArea,
}
