--!strict
-- World prep, task 23 (split into a folder in plan 3 Task 8a): the numbers and places of the footprint route and the
-- landing spots. The checks are in RouteChecks.luau and the run is in Run.luau. See Run.luau for what the script does.
--
-- Props: a sunflower is its Stem part's position; a bush or rock is a circle at the middle of the model's bounding
-- box, as wide as half its smaller side. designer owns which props count. Ground cover (flowers, ferns, grass tufts,
-- clovers, water lilies) may be walked over, trees have solid trunks, and Workspace.World.FarTrees is left out.

local PLOT_COUNT = 8
local GATE_OUTSIDE = 5.5 -- studs from the middle of a Safe Gate toward its spawn spot
local POINT_SIZE = Vector3.new(1, 0.2, 1)
local MAX_LINK_LENGTH = 25
local RAY_START_ABOVE = 3
local LANDING_SPACING = 10
local LANDING_REACH = 110
local LANDING_BOX = Vector3.new(4, 6, 4)
local LANDING_BOX_LIFT = 0.1
local LANDING_MIN_NORMAL_Y = math.cos(math.rad(10)) -- flat grass only
local STEM_LINK_CLEARANCE = 3 -- studs, across the ground, between a route link and a sunflower stem
local EDGE_LINK_CLEARANCE = 1 -- studs between a route link and the edge of a bush or rock (half a player's width)
local PROP_LANDING_CLEARANCE = 5 -- studs between a landing spot and a stem, or the edge of a bush or rock
local EGG_LANDING_CLEARANCE = 10 -- studs between a landing spot and every egg spot
local FLOWER_LANDING_CLEARANCE = 2.5 -- studs: designer's look rule, reported only
local SAME_PLACE = 0.05 -- studs: closer than this is "the same place" when the script compares with what exists
local SKY_RAY_LENGTH = 300

-- The props a player walks straight through (their CanCollide is off). The same list as RealWorld.spec.
local SOLID_LOOKING_PROPS: { [string]: boolean } = {
	Nature_Bush = true,
	Nature_BerryBush = true,
	Nature_FloweringBush = true,
	GateBush = true,
	Nature_MossyBoulder = true,
	Nature_MediumRock = true,
	Nature_Stump = true,
	Inno_Mushroom_02 = true,
	Inno_Mushroom_03 = true,
}
local FLOWER_CLUMPS: { [string]: boolean } = {
	Inno_Blue_Flowers = true,
	Inno_Pink_Flowers = true,
	Inno_White_Flowers = true,
	Inno_Yellow_Flowers = true,
	Nature_FlowerPatch = true,
}

-- Points that are placed by hand: name -> x, z and a rough height (to tell the ramp from the grass under it, and the
-- belly path from the belly). The exact height comes from the ground under the point.
local HAND_POINTS: { [string]: { number } } = {
	-- the meadow ring, from the west round the front to the east
	Meadow_1 = { -94, -18, 2 },
	Meadow_2 = { -70, -36, 2 },
	Meadow_3 = { -54, -48, 2 }, -- these three pass between the sock and the giant
	Meadow_4 = { -57, -68, 2 }, -- placed 3 studs clear of a sunflower stem at (-53.1, -62.2), which 10-clear-landing-views later took away
	Meadow_5 = { -30.5, -101, 2 }, -- the way off the end of bridge 4 beside the left ramp foot
	Meadow_6 = { -18, -75, 2 }, -- Meadow_6 .. 8 run in front of his boots, under both ramps; clear of a stem
	Meadow_7 = { 2, -80, 2 },
	Meadow_8 = { 22, -80, 2 },
	Meadow_9 = { 30.5, -101, 2 }, -- the same beside the right ramp foot
	Meadow_10 = { 54, -76, 2 },
	Meadow_11 = { 52, -58, 2 }, -- these three pass between the giant and the teacup; moved 6 east of the right boot ladder foot (48.6, -64)
	Meadow_12 = { 54, -40, 2 },
	Meadow_13 = { 70, -30, 2 },
	Meadow_14 = { 102, -22, 2 }, -- Meadow_14, 16 and 17 go round the flowering bush and the boulder east of the giant
	Meadow_15 = { 94, 4, 2 },
	Meadow_16 = { 106, -6, 2 },
	Meadow_17 = { 103, 4, 2 },
	Meadow_18 = { 64, -84, 2 }, -- bridge 6's way off its end, round the sunflower at (67.1, -79.7) and the bridge's rope
	-- the ramps, from the foot (level with the grass) to the top (on the boot)
	Ramp_Left_Foot = { -24, -102.3, 2 },
	Ramp_Left_Low = { -24, -90.3, 12.2 },
	Ramp_Left_High = { -24, -78.2, 22 },
	Ramp_Left_Top = { -24, -65.5, 32 },
	Ramp_Right_Foot = { 24, -102.3, 2 },
	Ramp_Right_Low = { 24, -90.3, 12.2 },
	Ramp_Right_High = { 24, -78.2, 22 },
	Ramp_Right_Top = { 24, -65.5, 32 },
	-- the ways up (plan 3 Task 8c): the two boot ladders, measured 2026-11-10 (work/p3t8/8c-step1-note.md); the right side
	-- is the left side with x turned to -x, so only the left side is listed and the right side is made below. A ladder's
	-- Foot is 1 stud out from its bottom rung's outer face, RunIn 3 studs out (spec 3: 2 to 4), and the two In points are
	-- 8 studs from RunIn at 25 degrees to the line, one on the side each group of gardens comes from. The Walk points
	-- split the straight line from a bridge's giant end to InNorth into parts under 25 studs. The Top is the middle of
	-- the ladder's TopPad. The plank points are 1.5 studs onto a lap plank's deck from each end, Landing_Back is 3.3 in
	-- from the landing's back edge (moved from 1.3 in: the deck's back edge blocked the walk to ramp piece 3), and the BellyRamp points are the top middles of ramp pieces 3, 9, 13 and 16.
	LadderLeft_Foot = { -51.30, -64.00, 2.09 },
	LadderLeft_RunIn = { -53.30, -64.00, 2.0 },
	LadderLeft_InNorth = { -60.55, -60.62, 2.0 },
	LadderLeft_InSouth = { -60.55, -67.38, 2.0 },
	LadderLeft_Top = { -31.55, -64.00, 30.40 },
	-- listed by hand, not mirrored: from the pad middle (31.55, -64) the walk to Egg_Uncommon_3 hits the pad's edge
	-- (probed 2026-11-10); this spot is on the same pad, 1.5 studs north and 0.55 in
	LadderRight_Top = { 31.00, -62.50, 30.40 },
	Walk1_1 = { -95.89, -8.80, 2 },
	Walk1_2 = { -84.11, -26.08, 2 },
	Walk1_3 = { -72.33, -43.35, 2 },
	Walk2_1 = { -80.17, -50.98, 2 },
	-- listed by hand: the right meadow props are not a mirror of the left (8c2, 2026-11-10)
	Walk8_1 = { 89.89, 1.20, 2 },
	Walk8_2 = { 80.11, -18.08, 2 },
	Walk8_3 = { 70.33, -39.35, 2 },
	Walk6_1 = { 71.35, -78.75, 2 },
	PlankLeft_Out = { -19.0, -57.5, 30.3 },
	PlankLeft_In = { -6.51, -54.59, 32.88 },
	-- listed by hand, not mirrored: the right boot's mesh and thigh guard are not a mirror of the left, and the only
	-- spot that links to the deck from Egg_Uncommon_4 is this one (probed 2026-11-10; a 0.2 stud move breaks it)
	PlankRight_Out = { 20.0, -59.0, 29.87 },
	BellyRampLeft_1 = { -3.21, -48.05, 35.08 },
	BellyRampLeft_2 = { -9.50, -46.20, 35.92 }, -- moved 0.9 off the piece-9 middle: the edge guard blocked the link
	BellyRampLeft_3 = { -11.38, -42.55, 39.12 },
	-- the lap landing's back point, on its middle line (x 0): where the way forks onto both belly ramps (Rule 45)
	Landing_Back = { 0, -51.0, 33.2 },
	-- the right ramp that has no egg yet: a dead end until plan 5 Task 12 puts the twin nest there
	BellyRampRight_4 = { 12.61, -40.07, 41.89 },
	-- Belly_4 moved (-0.83, +4.67) in x and z, 4.7 studs north, to the gentle north end of the raised strip on his belly
	-- (stuck safety Task 26, Rulings 10 and 11; product and game_creator both said yes). The closer fit shows the strip's
	-- sides as steep walls (70 to 80 degrees), so the footprints go round its north end, not straight into a side.
	Belly_4 = { -5.5, -26.0, 58.7 },
	Belly_Crest = { -1.1, -30.1, 61.8 }, -- on the crest between Belly_4 and Rare egg 4 (a straight link is 1.2 studs off it)
}

-- The right side of the ways up: the left points with x turned to -x. Garden 8 mirrors garden 1, 7 mirrors 2 and 6
-- mirrors 3. Landing_Back (x 0) and BellyRampRight_4 are listed above and are not mirrored.
do
	local mirrored: { [string]: { number } } = {}
	for name, place in HAND_POINTS do
		local right: string? = nil
		if string.find(name, "Left", 1, true) ~= nil and name ~= "BellyRampLeft_4" then
			right = (string.gsub(name, "Left", "Right"))
		elseif string.match(name, "^Walk1_%d$") then
			right = (string.gsub(name, "^Walk1", "Walk8"))
		elseif string.match(name, "^Walk2_%d$") then
			right = (string.gsub(name, "^Walk2", "Walk7"))
		end
		if right ~= nil and HAND_POINTS[right] == nil then
			mirrored[right] = { -place[1], place[2], place[3] }
		end
	end
	for name, place in mirrored do
		HAND_POINTS[name] = place
	end
end

-- The tags the route points of the ways up carry (the Ladder, WayUpFoot and WayUpTop attributes that
-- RouteData.readRoute reads): point name -> tags. The way names are Config.WaysUp names. A ladder is on exactly two
-- points, its foot and its top, which link to each other.
export type Tags = { ladder: string?, wayUpFoot: string?, wayUpTop: string? }
local POINT_TAGS: { [string]: Tags } = {
	LadderLeft_Foot = { ladder = "BootLadder_Left", wayUpFoot = "Left boot ladder" },
	LadderLeft_Top = { ladder = "BootLadder_Left", wayUpTop = "Left boot ladder" },
	LadderRight_Foot = { ladder = "BootLadder_Right", wayUpFoot = "Right boot ladder" },
	LadderRight_Top = { ladder = "BootLadder_Right", wayUpTop = "Right boot ladder" },
	Ramp_Left_Foot = { wayUpFoot = "Left ramp" },
	Ramp_Left_Top = { wayUpTop = "Left ramp" },
	Ramp_Right_Foot = { wayUpFoot = "Right ramp" },
	Ramp_Right_Top = { wayUpTop = "Right ramp" },
}

-- The links, as pairs of point names (without the RoutePoint_ start). Every one is made on both ends.
local LINKS: { { string } } = {}
local function link(first: string, second: string)
	table.insert(LINKS, { first, second })
end
for index = 1, PLOT_COUNT do
	link(`Spawn_{index}`, `Gate_{index}`)
	link(`Spawn_{index}`, `Bridge{index}_Garden`)
	link(`Bridge{index}_Garden`, `Bridge{index}_Giant`)
	-- bridges 4 and 5 end on a ramp foot, and bridge 6's way goes round a sunflower (below)
	if index ~= 4 and index ~= 5 and index ~= 6 then
		link(`Bridge{index}_Giant`, `Egg_Common_{index}`)
	end
end
link("Bridge6_Giant", "Meadow_18")
link("Meadow_18", "Egg_Common_6")
link("Egg_Common_1", "Meadow_1")
link("Meadow_1", "Egg_Common_2")
link("Egg_Common_2", "Meadow_2")
link("Meadow_2", "Meadow_3")
link("Meadow_3", "Meadow_4")
link("Meadow_4", "Egg_Common_3")
link("Egg_Common_3", "Egg_Common_4")
-- bridges 4 and 5 end on the foot of a ramp, so their way into the meadow goes beside it
link("Egg_Common_4", "Meadow_5")
link("Meadow_5", "Bridge4_Giant")
link("Meadow_5", "Ramp_Left_Foot")
link("Bridge4_Giant", "Ramp_Left_Foot")
link("Egg_Common_4", "Meadow_6")
link("Meadow_6", "Meadow_7")
link("Meadow_7", "Meadow_8")
link("Meadow_8", "Egg_Common_5")
link("Egg_Common_5", "Meadow_9")
link("Meadow_9", "Bridge5_Giant")
link("Meadow_9", "Ramp_Right_Foot")
link("Bridge5_Giant", "Ramp_Right_Foot")
link("Egg_Common_5", "Meadow_10")
link("Meadow_10", "Egg_Common_6")
link("Egg_Common_6", "Meadow_11")
link("Meadow_11", "Meadow_12")
link("Meadow_12", "Meadow_13")
link("Meadow_13", "Egg_Common_7")
link("Egg_Common_7", "Meadow_14")
link("Meadow_14", "Meadow_16")
link("Meadow_16", "Meadow_17")
link("Meadow_17", "Meadow_15")
link("Meadow_15", "Egg_Common_8")
for _, side in { "Left", "Right" } do
	link(`Ramp_{side}_Foot`, `Ramp_{side}_Low`)
	link(`Ramp_{side}_Low`, `Ramp_{side}_High`)
	link(`Ramp_{side}_High`, `Ramp_{side}_Top`)
end
link("Ramp_Left_Top", "Egg_Uncommon_1")
link("Egg_Uncommon_1", "Egg_Uncommon_2")
-- Plan 3 Task 8c: the walk from each garden to its way up, the two boot ladders, the lap planks, the landing and the
-- belly ramps. `sides` lists, per boot, the ladder side name, the gardens (north one, middle one, south one), the walk
-- point names that garden uses, its boot-top egg and its plank's first egg.
local BOOT_SIDES = {
	{
		side = "Left",
		north = 1,
		middle = 2,
		south = 3,
		northWalk = "Walk1",
		middleWalk = "Walk2",
		topEgg = 1,
		plankEgg = 1,
	},
	{
		side = "Right",
		north = 8,
		middle = 7,
		south = 6,
		northWalk = "Walk8",
		middleWalk = "Walk7",
		southWalk = "Walk6",
		topEgg = 3,
		plankEgg = 4,
	},
}
for _, boot in BOOT_SIDES do
	local ladder = `Ladder{boot.side}`
	local northChain = { `Bridge{boot.north}_Giant`, `{boot.northWalk}_1`, `{boot.northWalk}_2`, `{boot.northWalk}_3` }
	for index = 1, #northChain - 1 do
		link(northChain[index], northChain[index + 1])
	end
	link(northChain[#northChain], `{ladder}_InNorth`)
	link(`Bridge{boot.middle}_Giant`, `{boot.middleWalk}_1`)
	link(`{boot.middleWalk}_1`, `{ladder}_InNorth`)
	if boot.southWalk then
		link(`Bridge{boot.south}_Giant`, `{boot.southWalk}_1`)
		link(`{boot.southWalk}_1`, `{ladder}_InSouth`)
	else
		link(`Bridge{boot.south}_Giant`, `{ladder}_InSouth`)
	end
	link(`{ladder}_InNorth`, `{ladder}_RunIn`)
	link(`{ladder}_InSouth`, `{ladder}_RunIn`)
	link(`{ladder}_RunIn`, `{ladder}_Foot`)
	link(`{ladder}_Foot`, `{ladder}_Top`) -- the climb link
	link(`{ladder}_Top`, `Egg_Uncommon_{boot.topEgg}`)
	link(`Egg_Uncommon_{boot.plankEgg}`, `Plank{boot.side}_Out`)
	link(`Plank{boot.side}_Out`, `Plank{boot.side}_In`)
	link(`Plank{boot.side}_In`, "Landing_Back")
	link("Landing_Back", `BellyRamp{boot.side}_1`) -- the fork: both ramps start at the landing
	link(`BellyRamp{boot.side}_1`, `BellyRamp{boot.side}_2`)
	link(`BellyRamp{boot.side}_2`, `BellyRamp{boot.side}_3`)
end
link("BellyRampLeft_3", "Egg_Rare_1")
link("BellyRampRight_3", "BellyRampRight_4") -- the right ramp's end is a dead end
link("Egg_Rare_1", "Egg_Rare_2")
link("Egg_Rare_2", "Egg_Rare_3")
link("Egg_Rare_3", "Belly_4")
link("Belly_4", "Belly_Crest")
link("Belly_Crest", "Egg_Rare_4")
link("Ramp_Right_Top", "Egg_Uncommon_3")
link("Egg_Uncommon_3", "Egg_Uncommon_4")

-- The landing spots: x and z (the grass under them gives the height). Around his feet, in the meadow, and each one at
-- least 10 studs from every egg spot. Spots 1 and 2 are west of the left ramp, 3 and 4 east of the right ramp, 5 and 6
-- beside his left foot, 7 and 8 beside his right foot. Spot 7 is at (56, -62), 5.4 from the moved boot ladder rail foot (Task 5b2); spot 5 at x -58
-- (truss feet at x ±50.2); x -62 and 62 touch the sock and the teacup, measured. Spot 3 is a stud north of the place designer drew, (52, -92),
-- because the grass there is a 22 degree slope and the rule says flat grass. Spot 8 is a stud west of (50, -54), where
-- a flower clump was 2.4 studs away.
local LANDING_PLACES: { { number } } = {
	{ -45, -79 },
	{ -42, -97 },
	{ 52, -91 },
	{ 48, -80 },
	{ -58, -64 },
	{ -50, -54 },
	{ 56, -62 }, -- Task 5b2 moved: product's addendum, spec 3 line 93
	{ 49, -54 },
}

return {
	PLOT_COUNT = PLOT_COUNT,
	GATE_OUTSIDE = GATE_OUTSIDE,
	POINT_SIZE = POINT_SIZE,
	MAX_LINK_LENGTH = MAX_LINK_LENGTH,
	RAY_START_ABOVE = RAY_START_ABOVE,
	LANDING_SPACING = LANDING_SPACING,
	LANDING_REACH = LANDING_REACH,
	LANDING_BOX = LANDING_BOX,
	LANDING_BOX_LIFT = LANDING_BOX_LIFT,
	LANDING_MIN_NORMAL_Y = LANDING_MIN_NORMAL_Y,
	STEM_LINK_CLEARANCE = STEM_LINK_CLEARANCE,
	EDGE_LINK_CLEARANCE = EDGE_LINK_CLEARANCE,
	PROP_LANDING_CLEARANCE = PROP_LANDING_CLEARANCE,
	EGG_LANDING_CLEARANCE = EGG_LANDING_CLEARANCE,
	FLOWER_LANDING_CLEARANCE = FLOWER_LANDING_CLEARANCE,
	SAME_PLACE = SAME_PLACE,
	SKY_RAY_LENGTH = SKY_RAY_LENGTH,
	SOLID_LOOKING_PROPS = SOLID_LOOKING_PROPS,
	FLOWER_CLUMPS = FLOWER_CLUMPS,
	HAND_POINTS = HAND_POINTS,
	POINT_TAGS = POINT_TAGS,
	LINKS = LINKS,
	LANDING_PLACES = LANDING_PLACES,
}
