--!strict
-- Works out the glowing footprints' way from maths alone (spec Rule 2, "Footprints show the way"). It is given the
-- route's points (RouteData.read) and a position, and touches no services, instances or clocks.
--
-- How a way is found:
--  * Joining: the player joins the route at the nearest spot on any link (the closest place on the straight line
--    between a link's two points, by 3D distance from their feet), or at a lone point (one with no links) if that is
--    closer. From the join spot the way can go toward either end of that link.
--  * The shortest way: by walking distance along the links, starting with the stretch from the join spot.
--  * Choosing: of the targets that are allowed right now, the one with the shortest walk wins. A tie goes to the
--    first name in alphabetical order, so the choice never flickers between two equal eggs.
--  * Placing: one footprint every `spacing` studs, counted back from the target (the first at the target, the next
--    one `spacing` studs before it, and so on) and stopping at the join spot. Counting from the target means the
--    footprints ahead of a walking player stay where they are: only the ones behind them go away.

local RouteGraph = {}

-- One route point, as RouteData.read gives it.
export type Point = {
	name: string,
	position: Vector3, -- the point on the ground
	neighbours: { string }, -- the names of the points it links to
	target: string?, -- what it stands at (for example "EggSpot_Common_1" or "Gate_3"), or nil
}

-- The route as numbers, built once. Every point has an index (its place in name order).
export type Graph = {
	positions: { Vector3 },
	adjacent: { { number } }, -- for each point, the indexes it links to
	links: { { number } }, -- every link once, as { first index, second index }
	lone: { number }, -- the points that have no link at all
	pointOfTarget: { [string]: number }, -- target name -> index of the point that stands there
}

-- A way: where it starts (`path[1]`, the join spot), the points it passes, and where it ends (the target's point).
export type Found = {
	target: string,
	length: number, -- walking distance in studs, from the join spot
	path: { Vector3 },
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

	return { positions = positions, adjacent = adjacent, links = links, lone = lone, pointOfTarget = pointOfTarget }
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

	-- Shortest walking distance from the join spot to every point (Dijkstra's method): from the spot the walk can go
	-- to either end of the joined link, then along the links.
	local count = #graph.positions
	local distanceTo: { number } = table.create(count, math.huge)
	local cameFrom: { number } = table.create(count, 0) -- 0 means "straight from the join spot"
	if joinedLink ~= nil then
		for _, end_ in joinedLink do
			distanceTo[end_] = (spot - graph.positions[end_]).Magnitude
		end
	elseif joinedLone ~= nil then
		distanceTo[joinedLone] = 0
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
			local through = best + (graph.positions[current] - graph.positions[other]).Magnitude
			if through < distanceTo[other] then
				distanceTo[other] = through
				cameFrom[other] = current
			end
		end
	end

	-- The target with the shortest walk. Looking at the names in alphabetical order, and only taking a clearly
	-- shorter walk, gives a tie to the first name.
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
	local path: { Vector3 } = { spot }
	for at = #backwards, 1, -1 do
		local position = graph.positions[backwards[at]]
		if (position - path[#path]).Magnitude > NEARLY_ZERO then
			table.insert(path, position)
		end
	end
	return { target = chosen, length = chosenDistance, path = path }
end

-- One footprint every `spacing` studs along the way, counted back from the target. Nothing for a way of no length
-- (the player is at the target).
function RouteGraph.place(found: Found, spacing: number): { Step }
	local steps: { Step } = {}
	local path = found.path
	if #path < 2 or spacing <= 0 then
		return steps
	end

	local total = 0
	for at = 1, #path - 1 do
		total += (path[at + 1] - path[at]).Magnitude
	end
	local lastIndex = math.floor(total / spacing + NEARLY_ZERO)

	-- Walk back from the target along the segments; `segment` is the one that holds the distance asked for.
	local segment = #path - 1
	local doneBefore = 0 -- the distance from the target to the end of this segment that is nearer the target
	for index = 0, lastIndex do
		local distance = index * spacing
		while segment > 1 and distance > doneBefore + (path[segment + 1] - path[segment]).Magnitude do
			doneBefore += (path[segment + 1] - path[segment]).Magnitude
			segment -= 1
		end
		local nearEnd = path[segment + 1]
		local farEnd = path[segment]
		local length = (nearEnd - farEnd).Magnitude
		table.insert(steps, {
			position = nearEnd + (farEnd - nearEnd) * ((distance - doneBefore) / length),
			direction = (nearEnd - farEnd) / length,
		})
	end
	return steps
end

-- The whole answer in one go: the best target among `targets`, the walking distance, and the footprints.
function RouteGraph.way(graph: Graph, from: Vector3, targets: { string }, spacing: number): Way?
	local found = RouteGraph.find(graph, from, targets)
	if found == nil then
		return nil
	end
	return { target = found.target, length = found.length, steps = RouteGraph.place(found, spacing) }
end

return RouteGraph
