--!strict
-- The cheapest-route search over a graph of links (split out of PathCheck): the binary heap, the one search behind
-- route and costsFrom, and the three functions that read it. It knows only the links, never the walk map's spots, so
-- PathCheck can re-export it without a require cycle (a WalkMap fits Graph).

-- The walk map's words.
export type LinkKind = "Walk" | "Climb" | "Slide"
export type Link = { to: number, kind: LinkKind, length: number, seconds: number }
-- What the search needs from a walk map: its links.
export type Graph = { links: { [number]: { Link } } }
export type Step = { from: number, to: number, kind: LinkKind, length: number, seconds: number }
export type Route = { steps: { Step }, cost: number }
-- One search from a spot: the cheapest cost to every spot it reaches (a spot it can't reach has no entry) and the
-- step that reached each spot. Read with routeFrom.
export type Search = { from: number, costs: { [number]: number }, cameBy: { [number]: Step } }
-- Which link kinds count: a kind that isn't listed (or is false) doesn't.
export type AllowedKinds = { Walk: boolean?, Climb: boolean?, Slide: boolean? }
-- allow: the link kinds that count (default: all). cost: what a link costs (default: its seconds).
export type Rules = { allow: AllowedKinds?, cost: ((Link) -> number)? }

local NO_LINKS: { Link } = {}

local PathSearch = {}

-- A binary heap of (cost, id) pairs, smallest cost first.
type Heap = { costs: { number }, ids: { number }, size: number }

local function heapPush(heap: Heap, cost: number, id: number)
	heap.size += 1
	local index = heap.size
	while index > 1 do
		local parent = index // 2
		if heap.costs[parent] <= cost then
			break
		end
		heap.costs[index] = heap.costs[parent]
		heap.ids[index] = heap.ids[parent]
		index = parent
	end
	heap.costs[index] = cost
	heap.ids[index] = id
end

local function heapPop(heap: Heap): (number, number)
	local topCost, topId = heap.costs[1], heap.ids[1]
	local lastCost, lastId = heap.costs[heap.size], heap.ids[heap.size]
	heap.costs[heap.size] = nil :: any
	heap.ids[heap.size] = nil :: any
	heap.size -= 1
	if heap.size > 0 then
		local index = 1
		while true do
			local child = index * 2
			if child > heap.size then
				break
			end
			if child < heap.size and heap.costs[child + 1] < heap.costs[child] then
				child += 1
			end
			if heap.costs[child] >= lastCost then
				break
			end
			heap.costs[index] = heap.costs[child]
			heap.ids[index] = heap.ids[child]
			index = child
		end
		heap.costs[index] = lastCost
		heap.ids[index] = lastId
	end
	return topCost, topId
end

-- The search behind route and costsFrom: the cheapest cost to each spot reached (best) and the step that reached it
-- (cameBy). With `goals` it stops, before expanding, when it settles a spot in `goals` and returns that spot's id;
-- without, it settles every spot it can reach. `rules.allow` picks the link kinds that count (default: all) and
-- `rules.cost` sets what each link costs (default: its seconds; never negative).
local function search(
	map: Graph,
	from: number,
	rules: Rules?,
	goals: { [number]: boolean }?
): ({ [number]: number }, { [number]: Step }, number?)
	local allow = if rules ~= nil then rules.allow else nil
	local costOf = if rules ~= nil then rules.cost else nil

	local best: { [number]: number } = { [from] = 0 }
	local cameBy: { [number]: Step } = {}
	local heap: Heap = { costs = {}, ids = {}, size = 0 }
	heapPush(heap, 0, from)
	while heap.size > 0 do
		local cost, id = heapPop(heap)
		if cost <= (best[id] or math.huge) then -- (a dearer duplicate of a spot already settled is skipped)
			if goals ~= nil and goals[id] then
				return best, cameBy, id
			end
			for _, link in map.links[id] or NO_LINKS do
				if allow == nil or allow[link.kind] then
					local total = cost + (if costOf ~= nil then costOf(link) else link.seconds)
					if total < (best[link.to] or math.huge) then
						best[link.to] = total
						cameBy[link.to] = {
							from = id,
							to = link.to,
							kind = link.kind,
							length = link.length,
							seconds = link.seconds,
						}
						heapPush(heap, total, link.to)
					end
				end
			end
		end
	end
	return best, cameBy, nil
end

-- The steps walked back through `cameBy` from `to` to `from`.
local function stepsTo(cameBy: { [number]: Step }, from: number, to: number): { Step }
	local steps: { Step } = {}
	local at = to
	while at ~= from do
		local step = cameBy[at]
		table.insert(steps, 1, step)
		at = step.from
	end
	return steps
end

-- The cheapest route from one spot to any of the `to` spots, or nil. `rules.allow` picks the link kinds that count
-- (default: all) and `rules.cost` sets what each link costs (default: its seconds; never negative). Starting on one of
-- the `to` spots is a route with no steps.
function PathSearch.route(map: Graph, from: number, to: { number }, rules: Rules?): Route?
	local goals: { [number]: boolean } = {}
	for _, id in to do
		goals[id] = true
	end
	if goals[from] then
		return { steps = {}, cost = 0 }
	end
	local best, cameBy, reached = search(map, from, rules, goals)
	if reached == nil then
		return nil
	end
	return { steps = stepsTo(cameBy, from, reached), cost = best[reached] }
end

-- One search from a spot (a way-up foot), reused for every goal (every nest): the cheapest cost to every spot it can
-- reach, with no entry for a spot it can't. `rules` mean what they mean for route (`allow`, `cost`). Read the routes
-- with routeFrom. The links the rules allow must cost the same both ways for the costs to read as "back" too: that is
-- the caller's job.
function PathSearch.costsFrom(map: Graph, from: number, rules: Rules?): Search
	local best, cameBy = search(map, from, rules, nil)
	return { from = from, costs = best, cameBy = cameBy }
end

-- The route to `to` from the spot a costsFrom search started on, or nil if that search didn't reach it.
function PathSearch.routeFrom(searched: Search, to: number): Route?
	local cost = searched.costs[to]
	if cost == nil then
		return nil
	end
	if to == searched.from then
		return { steps = {}, cost = 0 }
	end
	return { steps = stepsTo(searched.cameBy, searched.from, to), cost = cost }
end

return PathSearch
