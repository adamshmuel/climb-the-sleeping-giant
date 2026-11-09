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
	-- the belly path (its flat start at the boot, the bend, the steep run, and the top turn)
	-- (stuck safety Task 24: V1's invisible belly boards are gone, so these stand on his skin, or on a crossing ramp's
	-- middle line. The rough heights are the ground now. Belly_1 moved (-0.6, -0.45) in x and z, just past the foot of
	-- the ankle ramp; Belly_2 moved (-2.47, +1.5) onto the long knee ramp (Ruling 10) and then stayed; Belly_3 moved
	-- (-3.62, +2.28) from V1's place onto the long knee ramp's middle line, 9 studs up from its foot; Belly_4 stayed. The
	-- Belly_<place> points have no target.)
	Belly_1 = { -21.1, -51.7, 25.5 },
	Belly_2 = { -19.97, -45.25, 32 }, -- on the long knee ramp, 6.5 studs up from its foot, 1.3 studs off the middle line
	Belly_3 = { -19.62, -42.44, 34.5 }, -- on the long knee ramp's middle line, 9.0 studs up from its foot
	-- Belly_4 moved (-0.83, +4.67) in x and z, 4.7 studs north, to the gentle north end of the raised strip on his belly
	-- (stuck safety Task 26, Rulings 10 and 11; product and game_creator both said yes). The closer fit shows the strip's
	-- sides as steep walls (70 to 80 degrees), so the footprints go round its north end, not straight into a side.
	Belly_4 = { -5.5, -26.0, 58.7 },
	Belly_BootStep = { -22.6, -59.9, 30.2 }, -- on the step piece over the 1 stud step in the left boot top
	Belly_AnkleTop = { -21.1, -56.1, 29.3 }, -- the top of the ankle ramp, on its middle line, at the boot's top edge
	-- Belly_KneeFoot moved (-0.57, -0.82) in x and z, 1.0 stud back down the long knee ramp, to 0.2 studs up from its foot
	-- edge (Ruling 11): from 0.6 studs up, the link from Belly_1 (beside the ramp's east edge) cuts across the ramp's side.
	Belly_KneeFoot = { -24.631, -49.674, 25.7 }, -- the long knee ramp's foot, on its middle line, 0.2 studs up from the foot edge
	Belly_KneeTop = { -17.68, -39.64, 37.9 }, -- the long knee ramp's top, on its middle line, 12.4 studs up (the tip is at 13.3)
	-- Belly_BandTop (Ruling 11): on his skin 2.85 studs past the ramp's tip and 1 stud east of its middle line. A straight
	-- link from Belly_KneeTop to Rare egg 1 touches Knee_Guard_2's end, so the way goes round it through this point.
	Belly_BandTop = { -14.724, -37.134, 44.7 },
	Belly_Crest = { -1.1, -30.1, 61.8 }, -- on the crest between Belly_4 and Rare egg 4 (a straight link is 1.2 studs off it)
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
link("Egg_Uncommon_2", "Belly_BootStep")
link("Belly_BootStep", "Belly_AnkleTop")
link("Belly_AnkleTop", "Belly_1")
link("Belly_1", "Belly_KneeFoot")
link("Belly_KneeFoot", "Belly_2")
link("Belly_2", "Belly_3")
link("Belly_3", "Belly_KneeTop")
link("Belly_KneeTop", "Belly_BandTop")
link("Belly_BandTop", "Egg_Rare_1")
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
	LINKS = LINKS,
	LANDING_PLACES = LANDING_PLACES,
}
