--!strict
-- The bot's legs list (stuck safety Task 8, Rule 24: A bot walks every way). It works out every leg the bot walk must
-- walk, in Edit, from the world alone, so the Play walk (Task 8b) and the later plans share one tested list.
--
-- A leg is one straight job for the bot: walk from `from` to `to`.
--   * "up" and "down": each way up, from the route's points. A way names its two route points (World.Route); the up
--     leg goes first to last, the down leg last to first.
--   * "stepoff": a step off an edge, from the walk map's Slide links (PathCheck.buildMap). Every spot that has a slide
--     link is an edge spot; its leg ends where its shortest slide lands. The edge spots are thinned so no two legs
--     start less than STEPOFF_EVERY studs apart (flat distance) along the same edge. Only starts at about the same
--     height crowd each other (SAME_HEIGHT), so a lower ledge beside a higher edge keeps its own step-offs. Then the
--     named cuff step-offs are added: each starts at its named position and uses the nearest edge spot's slide.
-- A name that gives no leg (a route point that isn't in the route, a cuff with no edge spot near it) comes back in the
-- second list, never skipped.
--
-- It builds a walk map, so it yields (task.wait) like PathCheck.buildMap. It uses no `script.Parent`, so a Studio
-- job can require a clone of it.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local RouteData = require(ReplicatedStorage.Shared.RouteData)

export type Way = { name: string, from: string, to: string } -- `from` and `to` are route point names
export type Cuff = { name: string, position: Vector3 } -- a named station to step off from
export type Leg = { kind: "up" | "down" | "stepoff", from: Vector3, to: Vector3, name: string }
export type Options = {
	ways: { Way }?,
	-- The box to build the walk map in. Without it there are no edge or cuff step-offs.
	area: PathCheck.Area?,
	cuffs: { Cuff }?,
	-- Where the route points are. Default: `world`'s child named "Route".
	route: Instance?,
	-- The walk map's settings. Default: PathCheck.defaults(world).
	path: PathCheck.Options?,
	-- Studs between two edge step-offs. Default: STEPOFF_EVERY.
	every: number?,
}

local BotLegs = {}

local STEPOFF_EVERY = 10 -- studs: edge step-offs start at least this far apart
local CUFF_REACH = 4 -- studs: a cuff's edge spot is within this distance of the named position
local SAME_HEIGHT = 2 -- studs: two starts crowd each other only when their heights differ by less than this
local SAME_STUD = 1e-3 -- studs: slack for "at least STEPOFF_EVERY apart" (the grid is exact, but floats aren't)

type Source = { spot: PathCheck.Spot, landing: PathCheck.Spot }

local NO_LINKS: { PathCheck.Link } = {}
local NO_SOURCES: { Source } = {}
local NO_WAYS: { Way } = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The landing of the shortest slide off a spot (flat distance), or nil when it has none.
local function shortestSlide(map: PathCheck.WalkMap, spot: PathCheck.Spot): PathCheck.Spot?
	local best: PathCheck.Spot? = nil
	local bestDistance = math.huge
	for _, link in map.links[spot.id] or NO_LINKS do
		if link.kind == "Slide" then
			local landing = map.spots[link.to]
			local distance = flatDistance(spot.position, landing.position)
			if distance < bestDistance then
				best = landing
				bestDistance = distance
			end
		end
	end
	return best
end

-- Every spot with a slide link, in x then z order, with where its shortest slide lands.
local function edgeSources(map: PathCheck.WalkMap): { Source }
	local sources: { Source } = {}
	for _, spot in map.spots do
		local landing = shortestSlide(map, spot)
		if landing ~= nil then
			table.insert(sources, { spot = spot, landing = landing })
		end
	end
	table.sort(sources, function(a, b)
		if a.spot.position.X ~= b.spot.position.X then
			return a.spot.position.X < b.spot.position.X
		end
		if a.spot.position.Z ~= b.spot.position.Z then
			return a.spot.position.Z < b.spot.position.Z
		end
		return a.spot.id < b.spot.id
	end)
	return sources
end

-- Keeps a source when no kept source is closer than `every` studs (flat) and within SAME_HEIGHT studs in height, so
-- legs start `every` apart along an edge, and a lower ledge beside a higher edge still gets its own.
-- Kept sources are hashed into square cells `every` wide, so each check looks at 9 cells, not at every kept source.
local function thinned(sources: { Source }, every: number): { Source }
	local kept: { Source } = {}
	local cells: { [string]: { Source } } = {}
	for _, source in sources do
		local position = source.spot.position
		local cellX = math.floor(position.X / every)
		local cellZ = math.floor(position.Z / every)
		local crowded = false
		for dx = -1, 1 do
			for dz = -1, 1 do
				for _, other in cells[`{cellX + dx},{cellZ + dz}`] or NO_SOURCES do
					if
						flatDistance(position, other.spot.position) < every - SAME_STUD
						and math.abs(position.Y - other.spot.position.Y) < SAME_HEIGHT
					then
						crowded = true
					end
				end
			end
		end
		if not crowded then
			table.insert(kept, source)
			local key = `{cellX},{cellZ}`
			local cell = cells[key] or {}
			cells[key] = cell
			table.insert(cell, source)
		end
	end
	return kept
end

local function stepoffName(position: Vector3): string
	return string.format("Step-off at (%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
end

-- The up and down legs of each way. Route points that aren't in the route go to `missing`.
local function wayLegs(world: WorldRoot, options: Options, legs: { Leg }, missing: { string })
	local ways = options.ways or NO_WAYS
	if #ways == 0 then
		return
	end
	local route = options.route or world:FindFirstChild("Route")
	local points: { RouteData.Point } = if route ~= nil then (RouteData.read(route)) else {}
	local byName: { [string]: RouteData.Point } = {}
	for _, point in points do
		byName[point.name] = point
	end
	for _, way in ways do
		local from = byName[way.from]
		local to = byName[way.to]
		if from == nil then
			table.insert(missing, way.from)
		end
		if to == nil then
			table.insert(missing, way.to)
		end
		if from ~= nil and to ~= nil then
			table.insert(legs, { kind = "up", from = from.position, to = to.position, name = `{way.name} up` })
			table.insert(legs, { kind = "down", from = to.position, to = from.position, name = `{way.name} down` })
		end
	end
end

-- The named cuff step-offs: each uses the nearest edge spot within CUFF_REACH of its position.
local function cuffLegs(sources: { Source }, cuffs: { Cuff }, legs: { Leg }, missing: { string })
	for _, cuff in cuffs do
		local best: Source? = nil
		local bestDistance = CUFF_REACH
		for _, source in sources do
			local distance = (source.spot.position - cuff.position).Magnitude
			if distance <= bestDistance then
				best = source
				bestDistance = distance
			end
		end
		if best == nil then
			table.insert(missing, cuff.name)
		else
			table.insert(legs, { kind = "stepoff", from = cuff.position, to = best.landing.position, name = cuff.name })
		end
	end
end

-- Works out the legs: the up and down legs of `options.ways`, the edge step-offs in `options.area`, then the cuff
-- step-offs. Returns the legs and the names that gave none. It yields.
function BotLegs.legs(world: WorldRoot, options: Options): ({ Leg }, { string })
	local legs: { Leg } = {}
	local missing: { string } = {}
	wayLegs(world, options, legs, missing)

	local area = options.area
	if area ~= nil then
		local pathOptions = options.path or PathCheck.defaults(world)
		local map = PathCheck.buildMap(pathOptions, area)
		PathCheck.cleanup(pathOptions)
		local sources = edgeSources(map)
		for _, source in thinned(sources, options.every or STEPOFF_EVERY) do
			table.insert(legs, {
				kind = "stepoff",
				from = source.spot.position,
				to = source.landing.position,
				name = stepoffName(source.spot.position),
			})
		end
		cuffLegs(sources, options.cuffs or {}, legs, missing)
	elseif options.cuffs ~= nil and #options.cuffs > 0 then
		for _, cuff in options.cuffs do
			table.insert(missing, cuff.name) -- no area, so no walk map to step off from
		end
	end
	return legs, missing
end

return BotLegs
