--!strict
-- The difficulty score of a nest (spec 4, Rules 46 to 48): the player walks up from a foot of a way up to a spot they
-- can grab the nest from and home again, the quietest way, with no jump; the score is the highest the shared sleep
-- meter reaches (HeistScore.replay). Pure code on a walk map: nothing is placed or measured in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local HeistScore = require(ServerScriptService.Server.World.HeistScore)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Noise = require(ServerScriptService.Server.Giant.Noise)

export type Foot = { name: string, spot: number }
export type Garden = { garden: number, spot: number }
export type NestInput = { name: string, position: Vector3, inMeadow: boolean }
export type Options = {
	map: PathCheck.WalkMap,
	feet: { Foot },
	gardens: { Garden },
	zoneOf: (spot: number) -> Config.ZoneName,
	rareFrom: number,
	hasRoom: ((spot: PathCheck.Spot) -> boolean)?,
}
export type GardenTime = { garden: number, seconds: number }
export type NestResult = {
	name: string,
	roomToStand: boolean,
	reached: boolean,
	left: boolean,
	score: number,
	eggUsed: Config.RarityName?,
	tiptoePeak: number,
	upBy: string?,
	homeBy: string?,
	ladderSeconds: number,
	quickest: GardenTime?,
	slowest: GardenTime?,
}
export type Pick = { upBy: string, homeBy: string, up: PathCheck.Route, down: PathCheck.Route }
-- One foot's own trip to a nest (Rule 41): the route up, the route back down (the up route's way, reversed) and the
-- highest the meter reaches on it.
export type FootTrip = { peak: number, up: PathCheck.Route, down: PathCheck.Route }

local ReachCheck = {}

-- The louder of two zones (the larger Config.Noise.ZoneMultiplier): a link between two zones is walked in it.
local function louder(a: Config.ZoneName, b: Config.ZoneName): Config.ZoneName
	if Config.Noise.ZoneMultiplier[b] > Config.Noise.ZoneMultiplier[a] then
		return b
	end
	return a
end

-- Two costs or times within this are a tie (the silent meadow makes many routes cost the same).
local TIE = 1e-6

local function secondsOf(route: PathCheck.Route): number
	local total = 0
	for _, step in route.steps do
		total += step.seconds
	end
	return total
end

-- Does `route` (named `name`) beat `best` (named `bestName`)? Lower cost wins. A cost tie (within 1e-6) goes to fewer
-- seconds, and a seconds tie to the name that sorts first.
local function beats(route: PathCheck.Route, name: string, best: PathCheck.Route, bestName: string): boolean
	if route.cost < best.cost - TIE then
		return true
	end
	if route.cost > best.cost + TIE then
		return false
	end
	local seconds, bestSeconds = secondsOf(route), secondsOf(best)
	if seconds < bestSeconds - TIE then
		return true
	end
	return seconds <= bestSeconds + TIE and name < bestName
end

-- The name of the cheapest route (see `beats`). nil if there is no route at all.
local function cheapest(routes: { [string]: PathCheck.Route? }): (string?, PathCheck.Route?)
	local bestName: string? = nil
	local best: PathCheck.Route? = nil
	for name, route in routes do
		if route ~= nil then
			local bestNow = best
			local bestNameNow = bestName
			if bestNow == nil or bestNameNow == nil or beats(route, name, bestNow, bestNameNow) then
				best = route
				bestName = name
			end
		end
	end
	return bestName, best
end

-- Rule 47: the cheapest trip up and the cheapest trip home (the two feet may differ), or nil if either has none.
function ReachCheck.pickRoutes(ups: { [string]: PathCheck.Route? }, downs: { [string]: PathCheck.Route? }): Pick?
	local upBy, up = cheapest(ups)
	local homeBy, down = cheapest(downs)
	if upBy == nil or up == nil or homeBy == nil or down == nil then
		return nil
	end
	return { upBy = upBy, homeBy = homeBy, up = up, down = down }
end

-- A route's steps as the heist replay's steps; each one is in the louder zone of its two ends. A Slide step is a small
-- step down (peaksByFoot allows no other), so it is scored as a Walk.
local function replaySteps(route: PathCheck.Route, zoneOf: (spot: number) -> Config.ZoneName): { HeistScore.Step }
	local steps: { HeistScore.Step } = {}
	for _, step in route.steps do
		local kind: "Walk" | "Climb" = if step.kind == "Climb" then "Climb" else "Walk"
		table.insert(steps, { length = step.length, kind = kind, zone = louder(zoneOf(step.from), zoneOf(step.to)) })
	end
	return steps
end

-- The meter replay (HeistScore) of a picked trip, carrying `egg` home.
function ReachCheck.replayPick(
	pick: Pick,
	egg: Config.RarityName,
	tiptoe: boolean,
	zoneOf: (spot: number) -> Config.ZoneName
): HeistScore.Score
	return HeistScore.replay({
		up = replaySteps(pick.up, zoneOf),
		down = replaySteps(pick.down, zoneOf),
		egg = egg,
		tiptoe = tiptoe,
	})
end

-- No jump, no drop: only walking and climbing links count (Rule 46).
local ALLOWED: PathCheck.AllowedKinds = { Walk = true, Climb = true }
-- Product's ruling (work/p3t12b/12b-mirror-decision.md): a one-way Slide that drops less than this many studs is a
-- step down, walked like a Walk by peaksByFoot. Any bigger drop is a jump and never part of a trip.
local STEP_DOWN_STUDS = 2
local WITH_STEPS_DOWN: PathCheck.AllowedKinds = { Walk = true, Climb = true, Slide = true }
-- A spot is flat enough to stand on when its up direction is within 70 degrees of straight up.
local FLAT_UP_Y = math.cos(math.rad(70))

-- The zone of every link: the louder zone of its two ends, so a ladder from the meadow up to a boot is in the Boots
-- both ways. The cost function only gets the link, so it reads the zone from this table.
local function linkZones(map: PathCheck.WalkMap, zoneOf: (spot: number) -> Config.ZoneName)
	local zones: { [PathCheck.Link]: Config.ZoneName } = {}
	for from, links in map.links do
		for _, link in links do
			zones[link] = louder(zoneOf(from), zoneOf(link.to))
		end
	end
	return zones
end

-- What a link costs for "quietest": the noise of walking it (carrying `carrying`, or nothing) for its seconds. The same
-- Noise.perSecond the replay uses, so the search and the replay agree.
local function noiseCost(zones: { [PathCheck.Link]: Config.ZoneName }, carrying: Config.RarityName?)
	return function(link: PathCheck.Link): number
		local perSecond = Noise.perSecond({
			zone = zones[link],
			garden = nil,
			moving = true,
			tiptoe = false,
			carrying = carrying,
			onLadder = link.kind == "Climb",
		})
		return perSecond * link.seconds
	end
end

-- The spots a player could stand on to grab the nest: flat, within Config.Grab.ReachStuds of it, and with room for the
-- body (options.hasRoom, default always).
local function standSpots(options: Options, position: Vector3): { PathCheck.Spot }
	local found: { PathCheck.Spot } = {}
	local hasRoom = options.hasRoom
	for _, spot in options.map.spots do
		if
			(spot.position - position).Magnitude <= Config.Grab.ReachStuds
			and spot.up.Y >= FLAT_UP_Y
			and (hasRoom == nil or hasRoom(spot))
		then
			table.insert(found, spot)
		end
	end
	return found
end

-- The cheapest trip home from the stand spot to each foot, with `egg` in hand: the routes by the foot's name.
local function tripsHome(
	options: Options,
	zones: { [PathCheck.Link]: Config.ZoneName },
	from: number,
	egg: Config.RarityName
)
	local search = PathCheck.costsFrom(options.map, from, { allow = ALLOWED, cost = noiseCost(zones, egg) })
	local downs: { [string]: PathCheck.Route? } = {}
	for _, foot in options.feet do
		downs[foot.name] = PathCheck.routeFrom(search, foot.spot)
	end
	return downs
end

-- The quickest and the slowest garden to the stand spot, by walking and climbing seconds; a garden that can't get there
-- is left out.
local function gardenTimes(options: Options, standId: number): (GardenTime?, GardenTime?)
	local quickest: GardenTime? = nil
	local slowest: GardenTime? = nil
	for _, garden in options.gardens do
		local seconds = PathCheck.costsFrom(options.map, garden.spot, { allow = ALLOWED }).costs[standId]
		if seconds ~= nil then
			if quickest == nil or seconds < quickest.seconds then
				quickest = { garden = garden.garden, seconds = seconds }
			end
			if slowest == nil or seconds > slowest.seconds then
				slowest = { garden = garden.garden, seconds = seconds }
			end
		end
	end
	return quickest, slowest
end

-- A cost that never takes a link into an off-limits spot other than `footSpot` (the foot this search starts from):
-- Rule 41's trip goes up and back down the same foot, never across another way up.
local function keepOffLimits(
	cost: (PathCheck.Link) -> number,
	spotsById: { [number]: PathCheck.Spot },
	offLimits: (spot: PathCheck.Spot) -> boolean,
	footSpot: number
): (PathCheck.Link) -> number
	return function(link: PathCheck.Link): number
		local target = spotsById[link.to]
		if link.to ~= footSpot and target ~= nil and offLimits(target) then
			return math.huge
		end
		return cost(link)
	end
end

-- Every Slide link that is a step down of under STEP_DOWN_STUDS (spot heights).
local function stepsDown(map: PathCheck.WalkMap, spotsById: { [number]: PathCheck.Spot }): { [PathCheck.Link]: boolean }
	local steps: { [PathCheck.Link]: boolean } = {}
	for from, links in map.links do
		for _, link in links do
			local fromSpot, toSpot = spotsById[from], spotsById[link.to]
			if
				link.kind == "Slide"
				and fromSpot ~= nil
				and toSpot ~= nil
				and fromSpot.position.Y - toSpot.position.Y < STEP_DOWN_STUDS
			then
				steps[link] = true
			end
		end
	end
	return steps
end

-- `cost`, except that a Slide drops `math.huge` unless it is in `steps`.
local function onlyStepsDown(
	steps: { [PathCheck.Link]: boolean },
	cost: (PathCheck.Link) -> number
): (PathCheck.Link) -> number
	return function(link: PathCheck.Link): number
		if link.kind == "Slide" and not steps[link] then
			return math.huge
		end
		return cost(link)
	end
end

-- A route walked the other way: the steps in reverse order, each from and to swapped.
local function reversed(route: PathCheck.Route): PathCheck.Route
	local steps: { PathCheck.Step } = {}
	for index = #route.steps, 1, -1 do
		local step = route.steps[index]
		table.insert(
			steps,
			{ from = step.to, to = step.from, kind = step.kind, length = step.length, seconds = step.seconds }
		)
	end
	return { steps = steps, cost = route.cost }
end

-- Rule 41: the meter peak of each foot's own trip to each nest, by nest name then foot name. Per foot, the quietest way
-- up empty-handed and the quietest way carrying `egg`, both kept off every spot `offLimits` names except this foot's
-- own; per nest, the stand spot cheapest from this foot. The way down is the up route's way with `egg` in hand,
-- replayed as HeistScore.dropDown (a leaning ladder can't be climbed down). A foot that can't reach a nest has no entry
-- for it.
function ReachCheck.peaksByFoot(
	options: Options,
	nests: { NestInput },
	egg: Config.RarityName,
	offLimits: (spot: PathCheck.Spot) -> boolean
): { [string]: { [string]: FootTrip } }
	local zones = linkZones(options.map, options.zoneOf)
	local spotsById: { [number]: PathCheck.Spot } = {}
	for _, spot in options.map.spots do
		spotsById[spot.id] = spot
	end
	local result: { [string]: { [string]: FootTrip } } = {}
	for _, nest in nests do
		result[nest.name] = {}
	end
	local steps = stepsDown(options.map, spotsById)
	local function trimmed(carrying: Config.RarityName?, footSpot: number): (PathCheck.Link) -> number
		return onlyStepsDown(steps, keepOffLimits(noiseCost(zones, carrying), spotsById, offLimits, footSpot))
	end
	for _, foot in options.feet do
		local upSearch =
			PathCheck.costsFrom(options.map, foot.spot, { allow = WITH_STEPS_DOWN, cost = trimmed(nil, foot.spot) })
		local eggSearch =
			PathCheck.costsFrom(options.map, foot.spot, { allow = WITH_STEPS_DOWN, cost = trimmed(egg, foot.spot) })
		for _, nest in nests do
			local stand: PathCheck.Spot? = nil
			local standCost = math.huge
			for _, spot in standSpots(options, nest.position) do
				local cost = upSearch.costs[spot.id]
				if cost ~= nil and cost < standCost then
					stand = spot
					standCost = cost
				end
			end
			if stand ~= nil then
				local up = PathCheck.routeFrom(upSearch, stand.id)
				local eggRoute = PathCheck.routeFrom(eggSearch, stand.id)
				if up ~= nil and eggRoute ~= nil then
					local score = HeistScore.replay({
						up = replaySteps(up, options.zoneOf),
						down = HeistScore.dropDown(replaySteps(eggRoute, options.zoneOf)),
						egg = egg,
						tiptoe = false,
					})
					result[nest.name][foot.name] = { peak = score.peak, up = up, down = reversed(eggRoute) }
				end
			end
		end
	end
	return result
end

-- Rules 46 to 48: how hard is it to take the egg from this nest and get home with no jump.
function ReachCheck.analyse(options: Options, nest: NestInput): NestResult
	local result: NestResult = {
		name = nest.name,
		roomToStand = false,
		reached = false,
		left = false,
		score = 0,
		eggUsed = nil,
		tiptoePeak = 0,
		upBy = nil,
		homeBy = nil,
		ladderSeconds = 0,
		quickest = nil,
		slowest = nil,
	}
	local spots = standSpots(options, nest.position)
	result.roomToStand = #spots > 0
	if not result.roomToStand then
		return result
	end

	-- The player stands on the stand spot with the cheapest trip up (the quietest from any foot).
	local zones = linkZones(options.map, options.zoneOf)
	local upCost = noiseCost(zones, nil)
	local upSearches: { [string]: PathCheck.Search } = {}
	for _, foot in options.feet do
		upSearches[foot.name] = PathCheck.costsFrom(options.map, foot.spot, { allow = ALLOWED, cost = upCost })
	end
	local stand: PathCheck.Spot? = nil
	local standCost = math.huge
	for _, spot in spots do
		for _, foot in options.feet do
			local cost = upSearches[foot.name].costs[spot.id]
			if cost ~= nil and cost < standCost then
				stand = spot
				standCost = cost
			end
		end
	end
	if stand == nil then
		return result
	end
	result.reached = true

	local ups: { [string]: PathCheck.Route? } = {}
	for _, foot in options.feet do
		ups[foot.name] = PathCheck.routeFrom(upSearches[foot.name], stand.id)
	end
	local downs = tripsHome(options, zones, stand.id, "Uncommon")
	result.left = next(downs) ~= nil
	result.quickest, result.slowest = gardenTimes(options, stand.id)
	if nest.inMeadow or not result.left then
		return result
	end

	-- Rule 48: score with the Uncommon egg; a score at or over rareFrom means the nest would hold a Rare, so the trip home
	-- is chosen and replayed again with the Rare egg (it is heavier and louder, so it can pick another way).
	local egg: Config.RarityName = "Uncommon"
	local pick = ReachCheck.pickRoutes(ups, downs)
	if pick == nil then
		return result
	end
	local score = ReachCheck.replayPick(pick, egg, false, options.zoneOf)
	if score.peak >= options.rareFrom then
		local rareDowns = tripsHome(options, zones, stand.id, "Rare")
		local rarePick = ReachCheck.pickRoutes(ups, rareDowns)
		if rarePick ~= nil then
			egg = "Rare"
			pick = rarePick
			score = ReachCheck.replayPick(pick, egg, false, options.zoneOf)
		end
	end
	result.eggUsed = egg
	result.score = score.peak
	result.ladderSeconds = score.ladderSeconds
	result.tiptoePeak = ReachCheck.replayPick(pick, egg, true, options.zoneOf).peak
	result.upBy = pick.upBy
	result.homeBy = pick.homeBy
	return result
end

return ReachCheck
