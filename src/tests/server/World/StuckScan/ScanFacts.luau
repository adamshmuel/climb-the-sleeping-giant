--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local PlayerNeeds = require(ServerStorage.Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
type ClosedFacts = Helpers.ClosedFacts
type Landing = Helpers.Landing
type Place = Helpers.Place
type RareFacts = Helpers.RareFacts
type StuckSpot = Helpers.StuckSpot
local CLOSED_SPOTS = Helpers.CLOSED_SPOTS
local RARE_MATCH = Helpers.RARE_MATCH
local escapingRays = Helpers.escapingRays
local format = Helpers.format
local linkedInto = Helpers.linkedInto
local placesInHollow = Helpers.placesInHollow

local MAX_LINES = 300 -- most stuck spots written out one by one

local NEAR_GIANT = 10 -- studs: the farthest a "nearest part of the giant" is looked for

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

-- The part's full name without the leading "Workspace.".
local function shortName(part: Instance): string
	return (string.gsub(part:GetFullName(), "^Workspace%.", ""))
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

local function giantModel(world: Instance): Model
	return (world :: any).Giant :: Model
end

-- A named V1 point passes if every walk-map spot within one grid step of it reaches an exit. With no spot that
-- close, it passes only if no body fits there. Returns why it failed, or nil.
local function namedPointProblem(
	name: string,
	point: Vector3,
	map: PathCheck.WalkMap,
	options: PathCheck.Options,
	stuckIds: { [number]: boolean }
): string?
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
	local hit = Workspace:Raycast(point + Vector3.new(0, DROP_FROM_ABOVE, 0), Vector3.new(0, -DROP_LENGTH, 0), params)
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
local function foreheadSlotProblems(
	map: PathCheck.WalkMap,
	stuckIds: { [number]: boolean },
	world: Instance
): { string }
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
local function namedProblems(
	map: PathCheck.WalkMap,
	options: PathCheck.Options,
	stuckIds: { [number]: boolean },
	world: Instance
): { string }
	local problems: { string } = {}
	local forehead = namedPointProblem("forehead point", FOREHEAD_POINT, map, options, stuckIds)
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
			local problem = namedPointProblem(name, position, map, options, stuckIds)
			if problem ~= nil then
				table.insert(problems, problem)
			end
		end
	end
	for _, problem in foreheadSlotProblems(map, stuckIds, world) do
		table.insert(problems, problem)
	end
	return problems
end

-- The given stuck spots as text: a summary, then one line each (at most MAX_LINES).
local function stuckReport(spots: { StuckSpot }, world: Instance): { string }
	local giantParts: { BasePart } = {}
	for _, descendant in giantModel(world):GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(giantParts, descendant)
		end
	end
	local pillowFolder = world:FindFirstChild("GiantsThings")
	local pillow: Instance? = if pillowFolder ~= nil then pillowFolder:FindFirstChild("Pillow") else nil
	local counts: { [string]: number } = {}
	local lines: { string } = {}
	for _, spot in spots do
		local nearest = nearestGiantPart(giantParts, giantModel(world), spot.standsOn, spot.position)
		local nearestName = if nearest ~= nil then shortName(nearest) else `none within {NEAR_GIANT} studs`
		local pieceName = labelOf(giantModel(world), pillow, spot.standsOn, nearest) or `none within {NEAR_GIANT} studs`
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

local function buildRareFacts(
	world: Instance,
	map: PathCheck.WalkMap,
	landings: { Landing },
	stuckIds: { [number]: boolean }
): RareFacts
	local giant = giantModel(world)
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

local function rareFacts(
	world: Instance,
	map: PathCheck.WalkMap,
	landings: { Landing },
	stuckIds: { [number]: boolean }
): RareFacts
	if cachedFacts == nil then
		cachedFacts = buildRareFacts(world, map, landings, stuckIds)
	end
	return cachedFacts :: RareFacts
end

-- Stuck safety Task 23, test 1: what the real world says about the closed hollows. The rays use the walk map's
-- ground settings. A solid piece is any part of the giant or of the Sock. The places players need that can lie in a
-- hollow are the route points, the egg spots and the landing spots; a safe spot (Rule 27) is only ever saved where
-- a player stood, and players only stand on the route, so the route stands for them. The spots "inside" are the walk-map
-- spots on the closed list. Built once, on first use.
local cachedClosedFacts: ClosedFacts? = nil

local function buildClosedFacts(world: Instance, map: PathCheck.WalkMap, landings: { Landing }): ClosedFacts
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.CollisionGroup = Collisions.GROUP
	local function cast(origin: Vector3, direction: Vector3): RaycastResult?
		return Workspace:Raycast(origin, direction, params)
	end
	local sock = (world :: any).GiantsThings:FindFirstChild("Sock")
	local function isSolid(instance: Instance): boolean
		return instance:IsDescendantOf(giantModel(world)) or (sock ~= nil and instance:IsDescendantOf(sock))
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

local function closedFacts(world: Instance, map: PathCheck.WalkMap, landings: { Landing }): ClosedFacts
	if cachedClosedFacts == nil then
		cachedClosedFacts = buildClosedFacts(world, map, landings)
	end
	return cachedClosedFacts :: ClosedFacts
end

return {
	giantModel = giantModel,
	namedProblems = namedProblems,
	stuckReport = stuckReport,
	rareFacts = rareFacts,
	closedFacts = closedFacts,
}
