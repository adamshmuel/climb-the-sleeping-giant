--!strict
-- World prep, task 23 (split into a folder in plan 3 Task 8a): works out every route point and landing spot from the
-- world and checks all of it (the same checks as the real-world tests in RealWorld.spec). A problem stops with an
-- error that names it, and nothing is changed. The numbers are in RoutePlaces.luau; the run is in Run.luau, which
-- describes every check.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- Loads a module fresh on every run: a clone placed next to the original (so its script.Parent requires still work),
-- removed again as soon as it is loaded. A copy this Studio session loaded before the module's last change is not reused.
local function loadFresh(original: ModuleScript): any
	local clone = original:Clone()
	clone.Parent = original.Parent
	local loaded, result = pcall(require, clone)
	clone:Destroy()
	if not loaded then
		error(`{original.Name} did not load: {result}`)
	end
	return result
end

local RouteData = loadFresh(ReplicatedStorage.Shared.RouteData :: ModuleScript)
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
export type PointPlan = {
	name: string,
	position: Vector3,
	target: string?,
	ladder: string?,
	wayUpFoot: string?,
	wayUpTop: string?,
}
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

-- The one shared walk check (src/server/World/PathCheck), loaded fresh on every run. This file is itself cloned on every run.
local PathCheck: any = loadFresh(ServerScriptService.Server.World.PathCheck :: ModuleScript)

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
	-- Every check after the points are made adds its lines here and goes on, so one run lists everything that is wrong.
	-- The run stops once, before anything is built, if this is not empty.
	local problems: { string } = {}
	local function add(name: string, position: Vector3, target: string?)
		if byName[name] then
			error(`two route points are named {name}`)
		end
		local tags = Places.POINT_TAGS[name]
		local plan: PointPlan = { name = name, position = position, target = target }
		if tags then
			plan.ladder, plan.wayUpFoot, plan.wayUpTop = tags.ladder, tags.wayUpFoot, tags.wayUpTop
		end
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

	-- the nests (plan 5 Task 17a): each one is a Model with a PromptAnchor. A nest with an entry in NEST_POINTS gets a
	-- point standing on the ground there, with the nest as its Target. The anchors keep every landing spot clear of them.
	local nestCount, nestPoints = 0, 0
	local eggPlaces: { { name: string, position: Vector3 } } = {}
	local nestNames: { string } = {}
	for _, spot in eggSpots:GetChildren() do
		local anchor = spot:FindFirstChild("PromptAnchor", true)
		if
			not spot:IsA("Model")
			or not string.match(spot.Name, "^Nest_")
			or anchor == nil
			or not anchor:IsA("Attachment")
		then
			error(`EggSpots.{spot.Name} is not a Nest_ Model with a PromptAnchor`)
		end
		table.insert(eggPlaces, { name = spot.Name, position = anchor.WorldPosition })
		table.insert(nestNames, spot.Name)
		nestCount += 1
	end
	table.sort(nestNames)
	local nestSet: { [string]: boolean } = {}
	for _, name in nestNames do
		nestSet[name] = true
		local place = Places.NEST_POINTS[name]
		if place == nil then
			local waits = false
			for _, pattern in Places.NESTS_WITHOUT_POINT do
				waits = waits or string.match(name, pattern) ~= nil
			end
			if not waits then
				table.insert(problems, `nests: {name} has no entry in NEST_POINTS`)
			end
			continue
		end
		add(name, groundAt(place[1], place[2], place[3], name).Position, name)
		nestPoints += 1
	end
	for name in Places.NEST_POINTS do
		if not nestSet[name] then
			table.insert(problems, `nests: NEST_POINTS has {name}, but there is no such nest`)
		end
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
	local usable: { { string } } = {} -- the links whose two points exist and which are listed once
	for _, pair in LINKS do
		local first, second = pair[1], pair[2]
		if byName[first] == nil or byName[second] == nil then
			table.insert(problems, `links: link {first} to {second}: there is no point with that name`)
			continue
		end
		if neighbourSets[first][second] then
			table.insert(problems, `links: link {first} to {second} is listed twice`)
			continue
		end
		neighbourSets[first][second] = true
		neighbourSets[second][first] = true
		table.insert(usable, pair)
	end
	local neighbours: { [string]: { string } } = {}
	for name, set in neighbourSets do
		local list: { string } = {}
		for other in set do
			table.insert(list, other)
		end
		table.sort(list)
		if #list == 0 then
			table.insert(problems, `links: {name} has no links`)
		end
		neighbours[name] = list
	end

	-- every link is short and walkable (a ladder's climb link is neither: it is climbed, and RouteData.isClimb names it)
	local longest, longestName = 0, ""
	local climbs = 0
	local baseOptions = walkOptions(world)
	local skipOptions: { [string]: any } = {} -- one options table per giant part a link may leave out (RouteData.bodyBoxSkip)
	for _, pair in usable do
		if RouteData.isClimb(byName[pair[1]] :: any, byName[pair[2]] :: any) then
			climbs += 1
			continue
		end
		local from, to = byName[pair[1]].position, byName[pair[2]].position
		local length = (to - from).Magnitude
		if length > MAX_LINK_LENGTH then
			table.insert(
				problems,
				`walk: link {pair[1]} to {pair[2]} is {length} studs long (the most is {MAX_LINK_LENGTH})`
			)
		end
		if length > longest then
			longest, longestName = length, `{pair[1]} to {pair[2]}`
		end
		local options = baseOptions
		local skipList = RouteData.bodyBoxSkip(pair[1], pair[2])
		if #skipList > 0 then
			local skipKey = table.concat(skipList, ",")
			if skipOptions[skipKey] == nil then
				local made = walkOptions(world)
				for _, part in RouteData.skipInstances(world, pair[1], pair[2]) do
					table.insert(made.boxIgnores, part)
				end
				skipOptions[skipKey] = made
			end
			options = skipOptions[skipKey]
		end
		local walkProblem = PathCheck.linkProblem(options, from, to)
		if walkProblem then
			table.insert(problems, `walk: link {pair[1]} to {pair[2]} is not walkable: {walkProblem}`)
		end
	end

	-- every link keeps clear of the props a player would walk through
	local stems, circles, flowerParts = collectProps(world)
	if #stems == 0 or #circles == 0 then
		error("no sunflowers or no bushes and rocks found under World: the prop check would see nothing")
	end
	for _, pair in usable do
		if RouteData.isClimb(byName[pair[1]] :: any, byName[pair[2]] :: any) then
			continue
		end
		local from, to = byName[pair[1]].position, byName[pair[2]].position
		for _, stem in stems do
			local distance = distanceToLink(stem.x, stem.z, from, to)
			if distance < STEM_LINK_CLEARANCE then
				table.insert(
					problems,
					string.format(
						"props: link %s to %s passes %.1f studs from a sunflower stem at (%.1f, %.1f) (the least is %g)",
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
				table.insert(
					problems,
					string.format(
						"props: link %s to %s passes %.1f studs from the edge of a %s at (%.1f, %.1f) (the least is %g)",
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
			table.insert(
				problems,
				`reach: {point.name} cannot be reached from {points[1].name}: the route is not one connected piece`
			)
		end
	end

	-- the landing spots; the boot ladder feet are the route points that carry both a Ladder and a WayUpFoot tag
	-- (the same rule as LandingSpots.spec)
	local ladderFeet: { { name: string, position: Vector3 } } = {}
	for _, point in points do
		if point.ladder ~= nil and point.wayUpFoot ~= nil then
			table.insert(ladderFeet, { name = point.name, position = point.position })
		end
	end
	local landing, flowerReport = LandingChecks.planLanding({
		plots = plots,
		zones = zones,
		giant = giant :: Model,
		ladderFeet = ladderFeet,
		eggPlaces = eggPlaces,
		stems = stems,
		circles = circles,
		flowerParts = flowerParts,
		groundAt = groundAt,
		flat = flat,
		problem = function(line: string)
			table.insert(problems, line)
		end,
	})

	-- everything that failed, in one error, before anything is built
	if #problems > 0 then
		error(`{#problems} route problems:\n{table.concat(problems, "\n")}`)
	end

	local info: { string } = {
		string.format("longest link: %.1f studs (%s)", longest, longestName),
		string.format("props checked: %d sunflower stems, %d bush and rock circles", #stems, #circles),
		`climb links (not length or walk checked): {climbs}`,
		`nest points: {nestPoints} of {nestCount} nests (the rest wait for Tasks 17b and 17c)`,
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
