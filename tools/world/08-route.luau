--!strict
-- World prep, task 23: the footprint route and the landing spots (spec Rule 2, "Footprints show the way", Rule 12,
-- "Waking bounces everyone off", and section 8, "Many players land at once after the bounce-off").
-- Why: footprints (Task 24) follow a map of the walkable ground, and the bounce-off (Tasks 26 and 27) needs places in
-- the meadow to put players down. Both are made here and checked by real-world tests.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every run plans and checks everything first, so a problem stops the script with nothing changed. Then:
--   * if World.Route and World.LandingSpots already match the plan, it says "already done" and changes nothing;
--   * if neither exists, it makes both;
--   * if both exist but differ from the plan, it builds the new ones away from the Workspace, then (between two
--     ChangeHistoryService waypoints) destroys the old ones and puts the new ones in, and reports what changed. Route
--     points and landing spots are made only by this script and nothing else refers to them, so replacing them is safe;
--   * if only one of the two exists, it stops with nothing changed.
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
--
-- Workspace.World.Route is a Model (ModelStreamingMode Persistent: every client reads it for its own footprints) full
-- of route points, RoutePoint_<name>. Each point is an invisible, anchored 1 x 0.2 x 1 part that nothing can touch,
-- hit or see, level, with its TOP centre on the ground a player walks on. A point has:
--   * Neighbours: the names of the points it links to, separated by commas. Every link is listed on both ends.
--   * Target (only where it stands at something): the egg spot's model name ("EggSpot_Rare_2"), "Gate_<n>" or
--     "Spawn_<n>".
-- The points, in the order a player meets them:
--   * Spawn_n, Gate_n (5.5 studs outside the arch, toward the spawn spot) and the two ends of PlankBridge_n, for
--     each garden n;
--   * the meadow: each Common egg spot, and Meadow_1 .. Meadow_18 between them (a ring in front of the giant, round
--     the sock and the teacup, never over water or through props), with a way past the ramp feet;
--   * each ramp: Foot, Low, High, Top (the top is on the boot);
--   * the boot tops: the two Uncommon egg spots of each boot;
--   * the belly path: Belly_1 .. Belly_4 on its middle and the four Rare egg spots. (The right boot top does not
--     join the belly path: there is a gap between his legs. The right ramp only leads to Uncommon_3 and _4.)
-- Workspace.World.LandingSpots is a Folder of LandingSpot_1 .. LandingSpot_8, the same kind of part, with its top
-- centre on the meadow grass around his feet.
--
-- Before it changes anything, the script checks (the same checks as the real-world tests in RealWorld.spec):
--   * every point has ground a player walks on under it, not water;
--   * every link is at most 25 studs long and walkable: sampled every 2 studs, a ray from 3 studs above the line
--     finds a solid, non-water surface within 4 studs, no steeper than StarterPlayer.CharacterMaxSlopeAngle and no
--     more than 1 stud from the line; a 2 x 4 x 2 box held 0.5 studs above the ground (tilted with it) touches
--     nothing with CanCollide on; and rays along the way at body height meet no part of the giant or the teacup.
--     Left out of the box check: the giant and the teacup, whose boxes are far bigger than their shapes (the cup's
--     box covers the end of bridge 6, 25 studs from the cup), so they get the rays instead; and the two ramp planks,
--     whose edges a player touches when stepping on or off a ramp foot;
--   * every link keeps clear of the props a player would walk through (every meadow prop has CanCollide off, so the
--     checks above never see them): at least 3 studs from every sunflower stem and at least 1 stud from the edge of
--     every bush or rock;
--   * every point can reach every other point;
--   * every landing spot is on flat grass, in the Meadow and in no garden, with a clear 4 x 6 x 4 box above it and open
--     sky above, at least 10 studs from every other spot, within 110 studs of the giant's middle, at least 10 studs
--     from every egg spot (a bounced player must not land on an egg: the grab reach is 8), and at least 5 studs from
--     every sunflower stem and from the edge of every bush or rock. The nearest flower clump is reported (designer
--     wants none within 2.5 studs), but it does not stop the script.
-- Props: a sunflower is its Stem part's position; a bush or rock is a circle at the middle of the model's bounding
-- box, as wide as half its smaller side. designer owns which props count. Ground cover (flowers, ferns, grass tufts,
-- clovers, water lilies) may be walked over, trees have solid trunks, and Workspace.World.FarTrees is left out.

local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLOT_COUNT = 8
local GATE_OUTSIDE = 5.5 -- studs from the middle of a Safe Gate toward its spawn spot
local POINT_SIZE = Vector3.new(1, 0.2, 1)
local MAX_LINK_LENGTH = 25
local SAMPLE_STEP = 2
local RAY_START_ABOVE = 3
local RAY_LENGTH = 4
local MAX_OFF_LINE = 1
local BODY_BOX = Vector3.new(2, 4, 2)
local BODY_LIFT = 0.5
local GIANT_SWEEP_HEIGHTS = { 1, 2.5, 4 }
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
	Meadow_11 = { 46, -58, 2 }, -- these three pass between the giant and the teacup
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
	Belly_1 = { -20.5, -51.25, 29.3 },
	Belly_2 = { -17.5, -46.75, 29.3 },
	Belly_3 = { -16, -44.72, 32.2 },
	Belly_4 = { -4.67, -30.67, 60.2 },
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
link("Egg_Uncommon_2", "Belly_1")
link("Belly_1", "Belly_2")
link("Belly_2", "Belly_3")
link("Belly_3", "Egg_Rare_1")
link("Egg_Rare_1", "Egg_Rare_2")
link("Egg_Rare_2", "Egg_Rare_3")
link("Egg_Rare_3", "Belly_4")
link("Belly_4", "Egg_Rare_4")
link("Ramp_Right_Top", "Egg_Uncommon_3")
link("Egg_Uncommon_3", "Egg_Uncommon_4")

-- The landing spots: x and z (the grass under them gives the height). Around his feet, in the meadow, and each one at
-- least 10 studs from every egg spot. Spots 1 and 2 are west of the left ramp, 3 and 4 east of the right ramp, 5 and 6
-- beside his left foot, 7 and 8 beside his right foot. Spot 3 is a stud north of the place designer drew, (52, -92),
-- because the grass there is a 22 degree slope and the rule says flat grass. Spot 8 is a stud west of (50, -54), where
-- a flower clump was 2.4 studs away.
local LANDING_PLACES: { { number } } = {
	{ -45, -79 },
	{ -42, -97 },
	{ 52, -91 },
	{ 48, -80 },
	{ -48, -64 },
	{ -50, -54 },
	{ 46, -64 },
	{ 49, -54 },
}

type Stem = { name: string, x: number, z: number }
type Circle = { name: string, x: number, z: number, radius: number }
type PointPlan = { name: string, position: Vector3, target: string? }
type Plan = {
	points: { PointPlan },
	byName: { [string]: PointPlan },
	neighbours: { [string]: { string } },
	landing: { Vector3 },
	info: { string },
}

-- The surface a player stands on under (x, z): a ray down that skips everything with CanCollide off (flowers, ropes).
local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	return params
end

local function groundAt(x: number, z: number, heightHint: number, label: string): RaycastResult
	local hit = Workspace:Raycast(
		Vector3.new(x, heightHint + RAY_START_ABOVE, z),
		Vector3.new(0, -(RAY_START_ABOVE + 5), 0),
		groundParams()
	)
	if hit == nil then
		error(`{label}: no ground under ({x}, {z}) near height {heightHint}`)
	end
	if hit.Material == Enum.Material.Water then
		error(`{label}: ({x}, {z}) is water`)
	end
	return hit
end

local function describeVector(vector: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", vector.X, vector.Y, vector.Z)
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function topOf(part: BasePart): Vector3
	return (part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)).Position
end

-- Finds what is wrong with walking from `from` to `to`, or nil. The same checks as RealWorld.spec.
local function walkProblem(world: Instance, from: Vector3, to: Vector3): string?
	local maxSlope = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
	local walk = world:FindFirstChild("WalkSurfaces") :: Instance
	local giant = world:FindFirstChild("Giant") :: Instance
	local things = world:FindFirstChild("GiantsThings") :: Instance
	local teacup = things:FindFirstChild("Teacup") :: Instance
	local swept: { Instance } = { giant, teacup }
	local boxIgnores: { Instance } = { giant, teacup }
	for _, side in { "BootRamp", "RightBootRamp" } do
		local plank = (walk:FindFirstChild(side) :: Instance):FindFirstChild("Ramp_Walk") :: Instance
		table.insert(boxIgnores, plank)
	end
	local sweepParams = RaycastParams.new()
	sweepParams.RespectCanCollide = true
	sweepParams.FilterType = Enum.RaycastFilterType.Include
	sweepParams.FilterDescendantsInstances = swept
	local boxParams = OverlapParams.new()
	boxParams.RespectCanCollide = true
	boxParams.FilterType = Enum.RaycastFilterType.Exclude
	boxParams.FilterDescendantsInstances = boxIgnores

	local length = (to - from).Magnitude
	local steps = math.max(1, math.ceil(length / SAMPLE_STEP))
	local direction = (to - from).Unit
	local previous: { position: Vector3, normal: Vector3 }? = nil
	for step = 0, steps do
		local onLine = from:Lerp(to, step / steps)
		local where = describeVector(onLine)
		local hit = Workspace:Raycast(
			onLine + Vector3.new(0, RAY_START_ABOVE, 0),
			Vector3.new(0, -RAY_LENGTH, 0),
			groundParams()
		)
		if hit == nil then
			return `no ground at {where}`
		end
		if hit.Material == Enum.Material.Water then
			return `water at {where}`
		end
		if hit.Normal.Y < maxSlope then
			return `too steep at {where} ({hit.Instance.Name})`
		end
		if math.abs(hit.Position.Y - onLine.Y) > MAX_OFF_LINE then
			return `the ground is {hit.Position.Y - onLine.Y} studs off the line at {where} ({hit.Instance.Name})`
		end
		local normal = hit.Normal
		local along = direction - normal * direction:Dot(normal)
		if along.Magnitude < 1e-3 then
			along = Vector3.xAxis
		end
		local across = along.Unit:Cross(normal)
		local boxCFrame = CFrame.fromMatrix(hit.Position + normal * (BODY_LIFT + BODY_BOX.Y / 2), across, normal)
		local touching = Workspace:GetPartBoundsInBox(boxCFrame, BODY_BOX, boxParams)
		if #touching > 0 then
			return `{touching[1]:GetFullName()} is in the way at {where}`
		end
		if previous then
			for _, height in GIANT_SWEEP_HEIGHTS do
				local start = previous.position + previous.normal * height
				local finish = hit.Position + normal * height
				if Workspace:Raycast(start, finish - start, sweepParams) then
					return `the giant or the teacup is in the way at {where}, {height} studs up`
				end
			end
		end
		previous = { position = hit.Position, normal = normal }
	end
	return nil
end

-- True if `point` is inside the box of `part` (a zone box or a garden volume).
local function insideBox(part: BasePart, point: Vector3): boolean
	local local_ = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

-- The props a player would walk through: every sunflower stem, and a circle for every bush or rock. Searches every
-- model under Workspace.World except FarTrees. Also gives the parts of every flower clump (for the report).
local function collectProps(world: Instance): ({ Stem }, { Circle }, { BasePart })
	local stems: { Stem } = {}
	local circles: { Circle } = {}
	local flowerParts: { BasePart } = {}
	for _, instance in world:GetDescendants() do
		if not instance:IsA("Model") then
			continue
		end
		local isSunflower = instance.Name == "Nature_Sunflower"
		local isFlowers = FLOWER_CLUMPS[instance.Name] == true
		if not isSunflower and not isFlowers and not SOLID_LOOKING_PROPS[instance.Name] then
			continue
		end
		if instance:FindFirstAncestor("FarTrees") ~= nil then
			continue
		end
		if isSunflower then
			local stem = instance:FindFirstChild("Stem")
			if stem == nil or not stem:IsA("BasePart") then
				error(`{instance:GetFullName()} has no Stem part`)
			end
			table.insert(stems, { name = instance.Name, x = stem.Position.X, z = stem.Position.Z })
		elseif isFlowers then
			for _, part in instance:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(flowerParts, part)
				end
			end
		else
			local boxCFrame, boxSize = instance:GetBoundingBox()
			table.insert(circles, {
				name = instance.Name,
				x = boxCFrame.Position.X,
				z = boxCFrame.Position.Z,
				radius = math.min(boxSize.X, boxSize.Z) / 2,
			})
		end
	end
	return stems, circles, flowerParts
end

-- The shortest distance, across the ground, from (x, z) to the line between two points.
local function distanceToLink(x: number, z: number, from: Vector3, to: Vector3): number
	local point = Vector3.new(x, 0, z)
	local start, finish = flat(from), flat(to)
	local along = finish - start
	local fraction = math.clamp((point - start):Dot(along) / along:Dot(along), 0, 1)
	return (point - (start + along * fraction)).Magnitude
end

-- The distance, across the ground, from (x, z) to the nearest edge of a part (0 if it is under the part).
local function distanceToPart(part: BasePart, x: number, z: number): number
	local inside = part.CFrame:PointToObjectSpace(Vector3.new(x, part.Position.Y, z))
	local half = part.Size / 2
	return Vector3.new(math.max(math.abs(inside.X) - half.X, 0), 0, math.max(math.abs(inside.Z) - half.Z, 0)).Magnitude
end

-- Works out every point and the landing spots, and checks all of it. Stops with an error that names the problem.
local function planWorld(world: Instance): Plan
	local plots = world:FindFirstChild("Plots")
	local bridges = world:FindFirstChild("Bridges")
	local eggSpots = world:FindFirstChild("EggSpots")
	local zones = world:FindFirstChild("Zones")
	local walk = world:FindFirstChild("WalkSurfaces")
	local giant = world:FindFirstChild("Giant")
	local things = world:FindFirstChild("GiantsThings")
	if plots == nil or bridges == nil or eggSpots == nil or zones == nil or walk == nil or giant == nil then
		error("World is missing Plots, Bridges, EggSpots, Zones, WalkSurfaces or Giant (run 01 to 07 first)")
	end
	if things == nil or things:FindFirstChild("Teacup") == nil then
		error("World.GiantsThings.Teacup is missing")
	end

	local points: { PointPlan } = {}
	local byName: { [string]: PointPlan } = {}
	local function add(name: string, position: Vector3, target: string?)
		if byName[name] then
			error(`two route points are named {name}`)
		end
		local plan: PointPlan = { name = name, position = position, target = target }
		table.insert(points, plan)
		byName[name] = plan
	end

	-- the garden points: spawn, gate, and the two ends of the bridge
	for index = 1, PLOT_COUNT do
		local plot = plots:FindFirstChild(`Plot_{index}`)
		local bridge = bridges:FindFirstChild(`PlankBridge_{index}`)
		if plot == nil or bridge == nil then
			error(`Plot_{index} or PlankBridge_{index} is missing`)
		end
		local spawnSpot = plot:FindFirstChild("SpawnSpot")
		local gate = plot:FindFirstChild("SafeGate")
		if spawnSpot == nil or not spawnSpot:IsA("BasePart") or gate == nil or not gate:IsA("Model") then
			error(`Plot_{index} has no SpawnSpot part or SafeGate model`)
		end
		local spawnGround = groundAt(spawnSpot.Position.X, spawnSpot.Position.Z, spawnSpot.Position.Y, `Spawn_{index}`)
		add(`Spawn_{index}`, spawnGround.Position, `Spawn_{index}`)
		local gateMiddle = flat(gate:GetPivot().Position)
		local towardSpawn = (flat(spawnSpot.Position) - gateMiddle).Unit
		local outside = gateMiddle + towardSpawn * GATE_OUTSIDE
		local gateGround = groundAt(outside.X, outside.Z, spawnGround.Position.Y, `Gate_{index}`)
		add(`Gate_{index}`, gateGround.Position, `Gate_{index}`)

		local planks: { BasePart } = {}
		for _, child in bridge:GetChildren() do
			if child.Name == "Plank" and child:IsA("BasePart") then
				table.insert(planks, child)
			end
		end
		if #planks < 2 then
			error(`PlankBridge_{index} has fewer than 2 planks`)
		end
		table.sort(planks, function(a, b)
			return a.Position.Magnitude < b.Position.Magnitude
		end)
		local giantEnd = topOf(planks[1])
		local gardenEnd = topOf(planks[#planks])
		local giantGround = groundAt(giantEnd.X, giantEnd.Z, giantEnd.Y, `Bridge{index}_Giant`)
		local gardenGround = groundAt(gardenEnd.X, gardenEnd.Z, gardenEnd.Y, `Bridge{index}_Garden`)
		add(`Bridge{index}_Giant`, giantGround.Position, nil)
		add(`Bridge{index}_Garden`, gardenGround.Position, nil)
	end

	-- the egg spots: each gets a point standing on the ground at the top of its Base
	local spotCount = 0
	local eggPlaces: { { name: string, position: Vector3 } } = {}
	for _, spot in eggSpots:GetChildren() do
		local base = spot:FindFirstChild("Base")
		local rarityAndNumber = string.match(spot.Name, "^EggSpot_(%a+_%d+)$")
		if base == nil or not base:IsA("BasePart") or rarityAndNumber == nil then
			error(`EggSpots.{spot.Name} has no Base part or is not named EggSpot_<Rarity>_<n>`)
		end
		local top = topOf(base)
		local ground = groundAt(top.X, top.Z, top.Y, spot.Name)
		add(`Egg_{rarityAndNumber}`, ground.Position, spot.Name)
		table.insert(eggPlaces, { name = spot.Name, position = top })
		spotCount += 1
	end
	if spotCount ~= 16 then
		error(`EggSpots has {spotCount} spots, not 16`)
	end

	-- the hand-placed points
	local handNames: { string } = {}
	for name in HAND_POINTS do
		table.insert(handNames, name)
	end
	table.sort(handNames)
	for _, name in handNames do
		local place = HAND_POINTS[name]
		add(name, groundAt(place[1], place[2], place[3], name).Position, nil)
	end

	-- the links, both ways
	local neighbourSets: { [string]: { [string]: boolean } } = {}
	for _, point in points do
		neighbourSets[point.name] = {}
	end
	for _, pair in LINKS do
		local first, second = pair[1], pair[2]
		if byName[first] == nil or byName[second] == nil then
			error(`link {first} to {second}: there is no point with that name`)
		end
		if neighbourSets[first][second] then
			error(`link {first} to {second} is listed twice`)
		end
		neighbourSets[first][second] = true
		neighbourSets[second][first] = true
	end
	local neighbours: { [string]: { string } } = {}
	for name, set in neighbourSets do
		local list: { string } = {}
		for other in set do
			table.insert(list, other)
		end
		table.sort(list)
		if #list == 0 then
			error(`{name} has no links`)
		end
		neighbours[name] = list
	end

	-- every link is short and walkable
	local longest, longestName = 0, ""
	for _, pair in LINKS do
		local from, to = byName[pair[1]].position, byName[pair[2]].position
		local length = (to - from).Magnitude
		if length > MAX_LINK_LENGTH then
			error(`link {pair[1]} to {pair[2]} is {length} studs long (the most is {MAX_LINK_LENGTH})`)
		end
		if length > longest then
			longest, longestName = length, `{pair[1]} to {pair[2]}`
		end
		local problem = walkProblem(world, from, to)
		if problem then
			error(`link {pair[1]} to {pair[2]} is not walkable: {problem}`)
		end
	end

	-- every link keeps clear of the props a player would walk through
	local stems, circles, flowerParts = collectProps(world)
	if #stems == 0 or #circles == 0 then
		error("no sunflowers or no bushes and rocks found under World: the prop check would see nothing")
	end
	for _, pair in LINKS do
		local from, to = byName[pair[1]].position, byName[pair[2]].position
		for _, stem in stems do
			local distance = distanceToLink(stem.x, stem.z, from, to)
			if distance < STEM_LINK_CLEARANCE then
				error(
					string.format(
						"link %s to %s passes %.1f studs from a sunflower stem at (%.1f, %.1f) (the least is %g)",
						pair[1],
						pair[2],
						distance,
						stem.x,
						stem.z,
						STEM_LINK_CLEARANCE
					)
				)
			end
		end
		for _, circle in circles do
			local gap = distanceToLink(circle.x, circle.z, from, to) - circle.radius
			if gap < EDGE_LINK_CLEARANCE then
				error(
					string.format(
						"link %s to %s passes %.1f studs from the edge of a %s at (%.1f, %.1f) (the least is %g)",
						pair[1],
						pair[2],
						gap,
						circle.name,
						circle.x,
						circle.z,
						EDGE_LINK_CLEARANCE
					)
				)
			end
		end
	end

	-- one connected route
	local seen: { [string]: boolean } = { [points[1].name] = true }
	local queue: { string } = { points[1].name }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, other in neighbours[current] do
			if not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	for _, point in points do
		if not seen[point.name] then
			error(`{point.name} cannot be reached from {points[1].name}: the route is not one connected piece`)
		end
	end

	-- the landing spots
	local zoneBoxes: { BasePart } = {}
	for _, child in zones:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(zoneBoxes, child)
		end
	end
	local gardenBoxes: { BasePart } = {}
	for index = 1, PLOT_COUNT do
		local volume = (plots:FindFirstChild(`Plot_{index}`) :: Instance):FindFirstChild("GardenVolume")
		if volume == nil or not volume:IsA("BasePart") then
			error(`Plot_{index} has no GardenVolume part`)
		end
		table.insert(gardenBoxes, volume)
	end
	local giantMiddle = flat((giant :: Model):GetPivot().Position)
	local boxParams = OverlapParams.new()
	boxParams.RespectCanCollide = true
	local landing: { Vector3 } = {}
	local flowerReport: { string } = {}
	for number, place in LANDING_PLACES do
		local label = `LandingSpot_{number}`
		local ground = groundAt(place[1], place[2], 2, label)
		if ground.Instance ~= Workspace.Terrain then
			error(`{label}: not on the grass (found {ground.Instance:GetFullName()})`)
		end
		if ground.Normal.Y < LANDING_MIN_NORMAL_Y then
			error(`{label}: the grass is not flat enough here`)
		end
		local spot = ground.Position
		for _, height in { 0, 3 } do -- its feet and its root
			local probe = spot + Vector3.new(0, height, 0)
			for _, box in zoneBoxes do
				if insideBox(box, probe) then
					error(`{label}: inside the zone box {box.Name}, so not Meadow`)
				end
			end
			for _, box in gardenBoxes do
				if insideBox(box, probe) then
					error(`{label}: inside a garden ({box.Parent and box.Parent.Name})`)
				end
			end
		end
		local boxCFrame = CFrame.new(spot + Vector3.new(0, LANDING_BOX_LIFT + LANDING_BOX.Y / 2, 0))
		local touching = Workspace:GetPartBoundsInBox(boxCFrame, LANDING_BOX, boxParams)
		if #touching > 0 then
			error(`{label}: a standing player would touch {touching[1]:GetFullName()}`)
		end
		if (flat(spot) - giantMiddle).Magnitude > LANDING_REACH then
			error(`{label}: more than {LANDING_REACH} studs from the giant's middle`)
		end
		for other, otherSpot in landing do
			if (flat(spot) - flat(otherSpot)).Magnitude < LANDING_SPACING then
				error(`{label} is closer than {LANDING_SPACING} studs to LandingSpot_{other}`)
			end
		end
		if Workspace:Raycast(spot + Vector3.new(0, LANDING_BOX_LIFT, 0), Vector3.new(0, SKY_RAY_LENGTH, 0)) then
			error(`{label}: something is over it (no open sky)`)
		end
		for _, egg in eggPlaces do
			local distance = (flat(spot) - flat(egg.position)).Magnitude
			if distance < EGG_LANDING_CLEARANCE then
				error(
					`{label}: only {string.format("%.1f", distance)} studs from {egg.name} (the least is {EGG_LANDING_CLEARANCE})`
				)
			end
		end
		for _, stem in stems do
			local distance = (flat(spot) - Vector3.new(stem.x, 0, stem.z)).Magnitude
			if distance < PROP_LANDING_CLEARANCE then
				error(
					string.format(
						"%s: only %.1f studs from a sunflower stem at (%.1f, %.1f) (the least is %g)",
						label,
						distance,
						stem.x,
						stem.z,
						PROP_LANDING_CLEARANCE
					)
				)
			end
		end
		for _, circle in circles do
			local gap = (flat(spot) - Vector3.new(circle.x, 0, circle.z)).Magnitude - circle.radius
			if gap < PROP_LANDING_CLEARANCE then
				error(
					string.format(
						"%s: only %.1f studs from the edge of a %s at (%.1f, %.1f) (the least is %g)",
						label,
						gap,
						circle.name,
						circle.x,
						circle.z,
						PROP_LANDING_CLEARANCE
					)
				)
			end
		end
		local nearestFlower = math.huge
		for _, part in flowerParts do
			nearestFlower = math.min(nearestFlower, distanceToPart(part, spot.X, spot.Z))
		end
		table.insert(
			flowerReport,
			string.format(
				"%s: nearest flower clump %.1f studs%s",
				label,
				nearestFlower,
				if nearestFlower < FLOWER_LANDING_CLEARANCE then " (CLOSER THAN 2.5, designer decides)" else ""
			)
		)
		table.insert(landing, spot)
	end

	-- for the report: does the right boot top join the belly path? (It does not: his legs have a gap between them.)
	local rightToBelly = walkProblem(world, byName.Egg_Uncommon_4.position, byName.Belly_1.position)
	local info: { string } = {
		string.format("longest link: %.1f studs (%s)", longest, longestName),
		string.format("props checked: %d sunflower stems, %d bush and rock circles", #stems, #circles),
		"right boot top (Uncommon_4) to the belly path start (Belly_1): "
			.. (if rightToBelly then `not walkable: {rightToBelly}` else "walkable"),
	}
	for _, line in flowerReport do
		table.insert(info, line)
	end
	return { points = points, byName = byName, neighbours = neighbours, landing = landing, info = info }
end

-- An invisible, anchored, level part whose TOP centre is `top`. Nothing can touch, hit or see it.
local function makeMarker(name: string, top: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = POINT_SIZE
	part.CFrame = CFrame.new(top - Vector3.new(0, POINT_SIZE.Y / 2, 0))
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- What is in the place now, in the same terms as the plan: every route point (by its part name) with its top, its
-- neighbours (sorted) and its target, and the landing spots by number.
type ExistingPoint = { top: Vector3, neighbours: { string }, target: string? }
type Existing = {
	points: { [string]: ExistingPoint },
	landing: { [number]: Vector3 },
	odd: { string }, -- things that are not what the script makes (so the place does not match)
}

local function readExisting(route: Instance, landingFolder: Instance): Existing
	local existing: Existing = { points = {}, landing = {}, odd = {} }
	if not route:IsA("Model") or route.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		table.insert(existing.odd, "World.Route is not a Persistent Model")
	end
	for _, child in route:GetChildren() do
		if not child:IsA("BasePart") then
			table.insert(existing.odd, `World.Route.{child.Name} is not a part`)
			continue
		end
		local neighboursValue: any = child:GetAttribute("Neighbours")
		local targetValue: any = child:GetAttribute("Target")
		local neighbours: { string } = {}
		if type(neighboursValue) == "string" then
			for piece in string.gmatch(neighboursValue, "[^,]+") do
				table.insert(neighbours, (string.match(piece, "^%s*(.-)%s*$")) :: string)
			end
		end
		table.sort(neighbours)
		existing.points[child.Name] = {
			top = topOf(child),
			neighbours = neighbours,
			target = if type(targetValue) == "string" then targetValue else nil,
		}
	end
	for _, child in landingFolder:GetChildren() do
		local number = string.match(child.Name, "^LandingSpot_(%d+)$")
		if number == nil or not child:IsA("BasePart") then
			table.insert(existing.odd, `World.LandingSpots.{child.Name} is not a LandingSpot_<n> part`)
			continue
		end
		existing.landing[tonumber(number) :: number] = topOf(child)
	end
	return existing
end

local function joinNames(names: { string }): string
	table.sort(names)
	return if #names == 0 then "none" else table.concat(names, ", ")
end

-- A point's name without the RoutePoint_ start.
local function bare(name: string): string
	local short = string.gsub(name, "^RoutePoint_", "")
	return short
end

local function shortPlace(position: Vector3): string
	return string.format("(%.1f, %.1f)", position.X, position.Z)
end

-- Every link as "A - B" (the shorter name first, no RoutePoint_ start), from a point -> neighbours table.
local function linkSet(neighboursOf: { [string]: { string } }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for name, list in neighboursOf do
		for _, other in list do
			local first, second = name, other
			if second < first then
				first, second = second, first
			end
			set[`{bare(first)} - {bare(second)}`] = true
		end
	end
	return set
end

-- Compares the place with the plan. Returns the report lines of what differs (empty if nothing does).
local function differences(plan: Plan, existing: Existing): { string }
	local lines: { string } = {}
	for _, text in existing.odd do
		table.insert(lines, `different: {text}`)
	end

	local planned: { [string]: ExistingPoint } = {}
	local plannedNeighbours: { [string]: { string } } = {}
	local existingNeighbours: { [string]: { string } } = {}
	for _, point in plan.points do
		local full = `RoutePoint_{point.name}`
		local names: { string } = {}
		for _, other in plan.neighbours[point.name] do
			table.insert(names, `RoutePoint_{other}`)
		end
		table.sort(names)
		planned[full] = { top = point.position, neighbours = names, target = point.target }
		plannedNeighbours[full] = names
	end
	for name, point in existing.points do
		existingNeighbours[name] = point.neighbours
	end

	local added, moved, removed, retargeted, relisted = {}, {}, {}, {}, {}
	for name, point in planned do
		local old = existing.points[name]
		if old == nil then
			table.insert(added, `{bare(name)} {shortPlace(point.top)}`)
			continue
		end
		if (old.top - point.top).Magnitude > SAME_PLACE then
			table.insert(moved, `{bare(name)} {shortPlace(old.top)} to {shortPlace(point.top)}`)
		end
		if old.target ~= point.target then
			table.insert(retargeted, bare(name))
		end
		if table.concat(old.neighbours, ",") ~= table.concat(point.neighbours, ",") then
			table.insert(relisted, bare(name))
		end
	end
	for name in existing.points do
		if planned[name] == nil then
			table.insert(removed, bare(name))
		end
	end

	local plannedLinks, existingLinks = linkSet(plannedNeighbours), linkSet(existingNeighbours)
	local linksAdded, linksRemoved = {}, {}
	for key in plannedLinks do
		if not existingLinks[key] then
			table.insert(linksAdded, key)
		end
	end
	for key in existingLinks do
		if not plannedLinks[key] then
			table.insert(linksRemoved, key)
		end
	end

	local landingMoved: { string } = {}
	for number, spot in plan.landing do
		local old: Vector3? = existing.landing[number]
		if old == nil then
			table.insert(landingMoved, `LandingSpot_{number} is new at {shortPlace(spot)}`)
		elseif (old - spot).Magnitude > SAME_PLACE then
			table.insert(landingMoved, `LandingSpot_{number} {shortPlace(old)} to {shortPlace(spot)}`)
		end
	end
	for number in existing.landing do
		local wanted: Vector3? = plan.landing[number]
		if wanted == nil then
			table.insert(landingMoved, `LandingSpot_{number} is no longer wanted`)
		end
	end
	table.sort(landingMoved)

	local function add(title: string, list: { string })
		if #list > 0 then
			table.insert(lines, `{title} ({#list}): {joinNames(list)}`)
		end
	end
	add("points added", added)
	add("points moved", moved)
	add("points removed", removed)
	add("points whose Target changed", retargeted)
	add("points whose Neighbours changed", relisted)
	add("links added", linksAdded)
	add("links removed", linksRemoved)
	if #landingMoved > 0 then
		table.insert(lines, `landing spots moved ({#landingMoved}): {table.concat(landingMoved, "; ")}`)
	end
	return lines
end

-- Builds a whole new Route model and LandingSpots folder from the plan. Neither is in the Workspace yet.
local function buildNew(plan: Plan): (Model, Folder, number)
	local model = Instance.new("Model")
	model.Name = "Route"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local targets = 0
	for _, point in plan.points do
		local part = makeMarker(`RoutePoint_{point.name}`, point.position)
		local names: { string } = {}
		for _, other in plan.neighbours[point.name] do
			table.insert(names, `RoutePoint_{other}`)
		end
		part:SetAttribute("Neighbours", table.concat(names, ","))
		if point.target then
			part:SetAttribute("Target", point.target)
			targets += 1
		end
		part.Parent = model
	end
	local folder = Instance.new("Folder")
	folder.Name = "LandingSpots"
	for number, spot in plan.landing do
		makeMarker(`LandingSpot_{number}`, spot).Parent = folder
	end
	return model, folder, targets
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing (run 01-gardens first)")
	end

	local oldRoute = world:FindFirstChild("Route")
	local oldLanding = world:FindFirstChild("LandingSpots")
	if (oldRoute == nil) ~= (oldLanding == nil) then
		error("World.Route or World.LandingSpots exists without the other. Nothing was changed.")
	end

	-- Check everything first, so a problem stops the script before anything changes.
	local plan = planWorld(world)

	local changes: { string } = {}
	if oldRoute ~= nil and oldLanding ~= nil then
		changes = differences(plan, readExisting(oldRoute, oldLanding))
		if #changes == 0 then
			return "already done"
		end
	end

	-- Build the new ones completely before touching the old ones.
	local model, folder, targets = buildNew(plan)

	pcall(function()
		ChangeHistoryService:SetWaypoint("08-route: before")
	end)
	if oldRoute ~= nil and oldLanding ~= nil then
		oldRoute:Destroy()
		oldLanding:Destroy()
	end
	model.Parent = world
	folder.Parent = world
	pcall(function()
		ChangeHistoryService:SetWaypoint("08-route: after")
	end)

	local summary = string.format(
		"World.Route: %d points (%d at a target), %d links; World.LandingSpots: %d spots",
		#plan.points,
		targets,
		#LINKS,
		#plan.landing
	)
	if oldRoute == nil then
		return `made {summary}\n   {table.concat(plan.info, "\n   ")}`
	end
	local checks = table.concat(plan.info, "\n   ")
	return `updated {summary}\n   changes:\n   {table.concat(changes, "\n   ")}\n   checks:\n   {checks}`
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
