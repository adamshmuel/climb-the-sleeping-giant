--!strict
-- Works out the glowing footprints' way from maths alone (spec Rule 2, "Footprints show the way"). It is given the
-- route's points (RouteData.read) and a position, and touches no services, instances or clocks. (Its only require is
-- the shared RouteData and Config, for the Point type and the walking speed.)
--
-- How a way is found:
--  * Joining: the player joins the route at the nearest spot on any link (the closest place on the straight line
--    between a link's two points, by 3D distance from their feet), or at a lone point (one with no links) if that is
--    closer. From the join spot the way can go toward either end of that link.
--  * The shortest way: by walking time (spec Rule 42, "Footprints take the quickest way"), starting with the stretch
--    from the join spot. A walk link takes length / WalkSpeed seconds; a climb link (both ends on the same ladder,
--    RouteData.isClimb) takes length / (0.7 x WalkSpeed), because Roblox climbs at 70% of WalkSpeed (docs,
--    Humanoid.Climbing; the same factor as PathCheck.CLIMB_SPEED). The stretch from the join spot is costed by the
--    kind of the joined link.
--  * Choosing: of the targets that are allowed right now, the one with the fewest seconds wins. A tie goes to the
--    first name in alphabetical order, so the choice never flickers between two equal eggs.
--  * Placing: one footprint every `spacing` studs, counted back from the target (the first at the target, the next
--    one `spacing` studs before it, and so on) and stopping at the join spot. Counting from the target means the
--    footprints ahead of a walking player stay where they are: only the ones behind them go away. None go on a climb
--    link: the way is cut into walk runs, each counted back from its own end, and a run that ends at a ladder stops
--    Config.Footprints.LadderStop studs before the ladder's foot point, so the trail ends in front of the rungs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RouteData = require(ReplicatedStorage.Shared.RouteData)

local RouteGraph = {}

-- One route point, as RouteData.read gives it.
export type Point = RouteData.Point

-- The route as numbers, built once. Every point has an index (its place in name order).
export type Graph = {
	positions: { Vector3 },
	adjacent: { { number } }, -- for each point, the indexes it links to
	links: { { number } }, -- every link once, as { first index, second index }
	lone: { number }, -- the points that have no link at all
	pointOfTarget: { [string]: number }, -- target name -> index of the point that stands there
	climb: { [string]: boolean }, -- link key `{low}:{high}` -> true when that link is a climb (a ladder)
}

-- A way: where it starts (`path[1]`, the join spot), the points it passes, and where it ends (the target's point).
export type Found = {
	target: string,
	length: number, -- distance in studs along the way, from the join spot
	seconds: number, -- time the way takes: walk links at WalkSpeed, climb links at 0.7 of it
	path: { Vector3 },
	climbs: { boolean }, -- for each stretch of `path` (`climbs[i]` is path[i] to path[i + 1]): true on a climb link
}

export type Step = {
	position: Vector3, -- on the route line
	direction: Vector3, -- the way to walk from here (a unit vector, along the route line)
}

export type Way = {
	target: string,
	length: number,
	steps: { Step }, -- the first is at the target; the rest follow one `spacing` further back each
}

local NEARLY_ZERO = 1e-6
local CLIMB_SPEED_FACTOR = 0.7 -- Roblox climbs at 70% of WalkSpeed (docs, Humanoid.Climbing; PathCheck.CLIMB_SPEED)

function RouteGraph.new(points: { Point }): Graph
	local sorted = table.clone(points)
	table.sort(sorted, function(a, b)
		return a.name < b.name
	end)

	local indexOf: { [string]: number } = {}
	local positions: { Vector3 } = {}
	for index, point in sorted do
		indexOf[point.name] = index
		positions[index] = point.position
	end

	-- A link is a link if either end lists the other. Every link is kept once.
	local adjacent: { { number } } = {}
	for index = 1, #sorted do
		adjacent[index] = {}
	end
	local links: { { number } } = {}
	local seen: { [string]: boolean } = {}
	for index, point in sorted do
		for _, neighbourName in point.neighbours do
			local other = indexOf[neighbourName]
			if other == nil or other == index then
				continue
			end
			local low, high = math.min(index, other), math.max(index, other)
			local key = `{low}:{high}`
			if not seen[key] then
				seen[key] = true
				table.insert(links, { low, high })
				table.insert(adjacent[low], high)
				table.insert(adjacent[high], low)
			end
		end
	end

	local climb: { [string]: boolean } = {}
	for _, link in links do
		if RouteData.isClimb(sorted[link[1]], sorted[link[2]]) then
			climb[`{link[1]}:{link[2]}`] = true
		end
	end

	local lone: { number } = {}
	local pointOfTarget: { [string]: number } = {}
	for index, point in sorted do
		if #adjacent[index] == 0 then
			table.insert(lone, index)
		end
		if point.target ~= nil and pointOfTarget[point.target] == nil then
			pointOfTarget[point.target] = index
		end
	end

	return {
		positions = positions,
		adjacent = adjacent,
		links = links,
		lone = lone,
		pointOfTarget = pointOfTarget,
		climb = climb,
	}
end

-- The place on the straight line from `a` to `b` that is nearest to `from`.
local function nearestOnLink(from: Vector3, a: Vector3, b: Vector3): Vector3
	local along = b - a
	local lengthSquared = along:Dot(along)
	if lengthSquared < NEARLY_ZERO then
		return a
	end
	local t = math.clamp((from - a):Dot(along) / lengthSquared, 0, 1)
	return a + along * t
end

-- How many seconds it takes to cross `studs` of the link between points `a` and `b`.
local function secondsAlong(graph: Graph, a: number, b: number, studs: number): number
	local speed = Config.Movement.WalkSpeed
	if graph.climb[`{math.min(a, b)}:{math.max(a, b)}`] then
		speed *= CLIMB_SPEED_FACTOR
	end
	return studs / speed
end

-- Finds the way from the join spot to the best of the allowed `targets`, or nil if there is none.
function RouteGraph.find(graph: Graph, from: Vector3, targets: { string }): Found?
	-- Join the route at the nearest spot on a link, or at a lone point. The first of equally near ones wins.
	local spot: Vector3? = nil
	local spotDistance = math.huge
	local joinedLink: { number }? = nil
	local joinedLone: number? = nil
	for _, link in graph.links do
		local candidate = nearestOnLink(from, graph.positions[link[1]], graph.positions[link[2]])
		local distance = (from - candidate).Magnitude
		if distance < spotDistance then
			spot, spotDistance, joinedLink, joinedLone = candidate, distance, link, nil
		end
	end
	for _, index in graph.lone do
		local distance = (from - graph.positions[index]).Magnitude
		if distance < spotDistance then
			spot, spotDistance, joinedLink, joinedLone = graph.positions[index], distance, nil, index
		end
	end
	if spot == nil then
		return nil
	end

	-- Quickest time from the join spot to every point (Dijkstra's method): from the spot the walk can go to either
	-- end of the joined link, then along the links. `studsTo` carries the studs of the same way.
	local count = #graph.positions
	local distanceTo: { number } = table.create(count, math.huge) -- seconds
	local studsTo: { number } = table.create(count, math.huge)
	local cameFrom: { number } = table.create(count, 0) -- 0 means "straight from the join spot"
	if joinedLink ~= nil then
		for _, end_ in joinedLink do
			local studs = (spot - graph.positions[end_]).Magnitude
			studsTo[end_] = studs
			distanceTo[end_] = secondsAlong(graph, joinedLink[1], joinedLink[2], studs)
		end
	elseif joinedLone ~= nil then
		distanceTo[joinedLone] = 0
		studsTo[joinedLone] = 0
	end
	local settled: { [number]: boolean } = {}
	while true do
		local current = 0
		local best = math.huge
		for index = 1, count do
			if not settled[index] and distanceTo[index] < best then
				current, best = index, distanceTo[index]
			end
		end
		if current == 0 then
			break
		end
		settled[current] = true
		for _, other in graph.adjacent[current] do
			local studs = (graph.positions[current] - graph.positions[other]).Magnitude
			local through = best + secondsAlong(graph, current, other, studs)
			if through < distanceTo[other] then
				distanceTo[other] = through
				studsTo[other] = studsTo[current] + studs
				cameFrom[other] = current
			end
		end
	end

	-- The target with the quickest way. Looking at the names in alphabetical order, and only taking a clearly
	-- quicker way, gives a tie to the first name.
	local names = table.clone(targets)
	table.sort(names)
	local chosen: string? = nil
	local chosenPoint = 0
	local chosenDistance = math.huge
	for _, name in names do
		local index = graph.pointOfTarget[name]
		if index ~= nil and distanceTo[index] < chosenDistance - NEARLY_ZERO then
			chosen, chosenPoint, chosenDistance = name, index, distanceTo[index]
		end
	end
	if chosen == nil then
		return nil
	end

	-- The path: the join spot, then the points back from the target. A point that is where the previous one is (the
	-- join spot standing exactly on a point) is left out.
	local backwards: { number } = {}
	local walker = chosenPoint
	while walker ~= 0 do
		table.insert(backwards, walker)
		walker = cameFrom[walker]
	end
	-- `climbs` says for each stretch whether it is a climb link. The stretch from the join spot lies on the joined link.
	local path: { Vector3 } = { spot }
	local climbs: { boolean } = {}
	local previous = 0 -- the last point passed (0 while only the join spot has been passed)
	for at = #backwards, 1, -1 do
		local index = backwards[at]
		local position = graph.positions[index]
		if (position - path[#path]).Magnitude > NEARLY_ZERO then
			table.insert(path, position)
			if previous == 0 then
				table.insert(climbs, joinedLink ~= nil and graph.climb[`{joinedLink[1]}:{joinedLink[2]}`] == true)
			else
				table.insert(climbs, graph.climb[`{math.min(previous, index)}:{math.max(previous, index)}`] == true)
			end
		end
		previous = index
	end
	return {
		target = chosen,
		length = studsTo[chosenPoint],
		seconds = chosenDistance,
		path = path,
		climbs = climbs,
	}
end

-- Adds one footprint every `spacing` studs along `line`, counted back from its last point (the first at that point),
-- to `steps`. Nothing for a line of no length.
local function placeAlong(line: { Vector3 }, spacing: number, steps: { Step })
	if #line < 2 then
		return
	end
	local total = 0
	for at = 1, #line - 1 do
		total += (line[at + 1] - line[at]).Magnitude
	end
	local lastIndex = math.floor(total / spacing + NEARLY_ZERO)

	-- Walk back from the end along the segments; `segment` is the one that holds the distance asked for.
	local segment = #line - 1
	local doneBefore = 0 -- the distance from the end to the end of this segment that is nearer the end
	for index = 0, lastIndex do
		local distance = index * spacing
		while segment > 1 and distance > doneBefore + (line[segment + 1] - line[segment]).Magnitude do
			doneBefore += (line[segment + 1] - line[segment]).Magnitude
			segment -= 1
		end
		local nearEnd = line[segment + 1]
		local farEnd = line[segment]
		local length = (nearEnd - farEnd).Magnitude
		table.insert(steps, {
			position = nearEnd + (farEnd - nearEnd) * ((distance - doneBefore) / length),
			direction = (nearEnd - farEnd) / length,
		})
	end
end

-- Takes `studs` off the end of `line` (a copy is changed), so the line stops that far short of where it ended.
local function trimEnd(line: { Vector3 }, studs: number)
	local remaining = studs
	while remaining > NEARLY_ZERO and #line >= 2 do
		local last, before = line[#line], line[#line - 1]
		local length = (last - before).Magnitude
		if length > remaining + NEARLY_ZERO then
			line[#line] = last + (before - last).Unit * remaining
			return
		end
		table.remove(line)
		remaining -= length
	end
end

-- One footprint every `spacing` studs along the way's walk runs, never on a climb link. A walk run is a stretch of the
-- path with no climb link in it, and each run is counted back from its own end, so footprints ahead of a walker stay
-- put. A run that ends at a ladder stops `stop` studs before the ladder's foot point. The first footprint is at the
-- target; the rest follow from the last run back to the first. Nothing for a way of no length (the player is at the
-- target).
function RouteGraph.place(found: Found, spacing: number, stop: number): { Step }
	local steps: { Step } = {}
	local path = found.path
	if #path < 2 or spacing <= 0 then
		return steps
	end

	-- The runs, from the end of the way back: each is { first stretch, last stretch }.
	local runEnd = #path - 1
	while runEnd >= 1 do
		if found.climbs[runEnd] then
			runEnd -= 1
			continue
		end
		local runStart = runEnd
		while runStart > 1 and not found.climbs[runStart - 1] do
			runStart -= 1
		end
		local line: { Vector3 } = {}
		for at = runStart, runEnd + 1 do
			table.insert(line, path[at])
		end
		if found.climbs[runEnd + 1] then
			trimEnd(line, stop)
		end
		placeAlong(line, spacing, steps)
		runEnd = runStart - 1
	end
	return steps
end

-- The whole answer in one go: the best target among `targets`, the walking distance, and the footprints.
function RouteGraph.way(graph: Graph, from: Vector3, targets: { string }, spacing: number): Way?
	local found = RouteGraph.find(graph, from, targets)
	if found == nil then
		return nil
	end
	return {
		target = found.target,
		length = found.length,
		steps = RouteGraph.place(found, spacing, Config.Footprints.LadderStop),
	}
end

return RouteGraph
