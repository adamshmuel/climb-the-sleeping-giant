--!strict
-- World prep, task 23 (split into a folder in plan 3 Task 8a): works out every route point and landing spot from the
-- world and checks all of it (the same checks as the real-world tests in RealWorld.spec). A problem stops with an
-- error that names it, and nothing is changed. The numbers are in RoutePlaces.luau; the run is in Run.luau, which
-- describes every check.

local Workspace = game:GetService("Workspace")

local Places = require(script.Parent.RoutePlaces)
local LandingChecks = require(script.Parent.LandingChecks)

local PLOT_COUNT = Places.PLOT_COUNT
local GATE_OUTSIDE = Places.GATE_OUTSIDE
local MAX_LINK_LENGTH = Places.MAX_LINK_LENGTH
local RAY_START_ABOVE = Places.RAY_START_ABOVE
local STEM_LINK_CLEARANCE = Places.STEM_LINK_CLEARANCE
local EDGE_LINK_CLEARANCE = Places.EDGE_LINK_CLEARANCE
local SOLID_LOOKING_PROPS = Places.SOLID_LOOKING_PROPS
local FLOWER_CLUMPS = Places.FLOWER_CLUMPS
local HAND_POINTS = Places.HAND_POINTS
local LINKS = Places.LINKS

type Stem = LandingChecks.Stem
type Circle = LandingChecks.Circle
export type PointPlan = { name: string, position: Vector3, target: string? }
export type Plan = {
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

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function topOf(part: BasePart): Vector3
	return (part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)).Position
end

-- The one shared walk check (src/server/World/PathCheck), loaded fresh on every run: a clone of the module, placed next
-- to the original (the clone is removed again as soon as it is loaded). This file is itself cloned on every run.
local PathCheck: any
do
	local original = game:GetService("ServerScriptService").Server.World.PathCheck :: ModuleScript
	local clone = original:Clone()
	clone.Parent = original.Parent
	local loaded, result = pcall(require, clone)
	clone:Destroy()
	if not loaded then
		error(`PathCheck did not load: {result}`)
	end
	PathCheck = result
end

-- What PathCheck.linkProblem needs to walk-check the real world, the same as RealWorld.spec: the shared defaults (the
-- slope limit, the spacing and the meadow ground, Rule 23: One walk check for everything), then the two ramp planks.
-- The planks are left out of the body check (a player steps on or off a ramp foot over their edges by design).
local function walkOptions(world: Instance): any
	local walk = world:FindFirstChild("WalkSurfaces") :: Instance
	local boxIgnores: { Instance } = {}
	for _, side in { "BootRamp", "RightBootRamp" } do
		local plank = (walk:FindFirstChild(side) :: Instance):FindFirstChild("Ramp_Walk") :: Instance
		table.insert(boxIgnores, plank)
	end
	local options = PathCheck.defaults(Workspace)
	options.boxIgnores = boxIgnores
	return options
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
		local problem = PathCheck.linkProblem(walkOptions(world), from, to)
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
	local landing, flowerReport = LandingChecks.planLanding({
		plots = plots,
		zones = zones,
		giant = giant :: Model,
		eggPlaces = eggPlaces,
		stems = stems,
		circles = circles,
		flowerParts = flowerParts,
		groundAt = groundAt,
		flat = flat,
	})

	-- for the report: does the right boot top join the belly path? (It does not: his legs have a gap between them.)
	local rightToBelly =
		PathCheck.linkProblem(walkOptions(world), byName.Egg_Uncommon_4.position, byName.Belly_1.position)
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

-- The body probe the walk check leaves in the Workspace never stays, whatever happened.
local function cleanup()
	PathCheck.cleanup({ world = Workspace })
end

return {
	planWorld = planWorld,
	topOf = topOf,
	cleanup = cleanup,
}
