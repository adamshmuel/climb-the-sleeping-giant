--!strict
-- The difficulty score of a nest (spec 4, Rules 46 to 48): the player walks up from a foot of a way up to a spot they can
-- grab the nest from and home again, the quietest way, with no jump; the score is the highest the shared sleep meter
-- reaches (HeistScore.replay). Pure code on a walk map: nothing is placed or measured in the world.

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

-- A route's steps as the heist replay's steps; each one is in the louder zone of its two ends. A Slide never gets here
-- (the searches don't allow it).
local function replaySteps(route: PathCheck.Route, zoneOf: (spot: number) -> Config.ZoneName): { HeistScore.Step }
	local steps: { HeistScore.Step } = {}
	for _, step in route.steps do
		if step.kind == "Slide" then
			error("ReachCheck: a Slide step is never part of a trip")
		end
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
-- A spot is flat enough to stand on when its up direction is within 70 degrees of straight up.
local FLAT_UP_Y = math.cos(math.rad(70))

-- The zone of every link: the louder zone of its two ends, so a ladder from the meadow up to a boot is in the Boots both
-- ways. The cost function only gets the link, so it reads the zone from this table.
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
