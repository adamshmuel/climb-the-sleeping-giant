--!strict
-- The real world set up for the reach checks (plan 4, Task 9a): the walk map over an area, the feet of the four ways up,
-- the zone lookup, the "off the meadow" limit (spec 3, Rule 41), and each garden's walk to its way up. WaysUpFairness
-- and the egg-reach check both build on it, so the setup lives here once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
local FootprintSteps = require(script.Parent.FootprintSteps)
local WaysUpRoutes = require(script.Parent.WaysUpRoutes)

export type Setup = {
	map: PathCheck.WalkMap,
	options: PathCheck.Options,
	feet: { ReachCheck.Foot },
	zoneOf: (spot: number) -> Config.ZoneName,
	offLimits: (spot: PathCheck.Spot) -> boolean,
	waysUp: { WorldIndex.WayUp },
	points: { WorldIndex.RoutePoint },
	ladders: { Zones.LadderBox },
	zoneBoxes: { Zones.ZoneBox },
	graph: RouteGraph.Graph,
}

local RealReach = {}

-- Builds the map over `area` and everything the reach checks read from the world. The caller cleans up `options`
-- (PathCheck.cleanup) when it is done. `fineBoxes` (default none) are the boxes the map also gets a spot every stud in.
-- An error names what is missing from the world.
function RealReach.build(world: Instance, area: PathCheck.Area, fineBoxes: { PathCheck.Area }?): Setup
	local options = PathCheck.defaults(game:GetService("Workspace"))
	local surfaces = (world :: any).WalkSurfaces
	options.boxIgnores = { surfaces.BootRamp.Ramp_Walk, surfaces.RightBootRamp.Ramp_Walk }
	options.fineBoxes = fineBoxes
	local map = PathCheck.buildMap(options, area)

	local zoneBoxes = WorldIndex.loadZones(world)
	local ladders = WorldIndex.loadLadders(world)
	local points = WorldIndex.loadRoute(world)
	local waysUp, wayProblems = WorldIndex.readWaysUp(world)
	if waysUp == nil then
		pcall(PathCheck.cleanup, options)
		error(`RealReach: the ways up cannot be read: {table.concat(wayProblems, " | ")}`)
	end
	local spotsById: { [number]: PathCheck.Spot } = {}
	for _, spot in map.spots do
		spotsById[spot.id] = spot
	end
	local function zoneOf(id: number): Config.ZoneName
		return Zones.zoneAt(spotsById[id].position + FootprintSteps.ROOT_ABOVE_FEET, zoneBoxes)
	end

	-- The feet, and the 4 way-up models a route may stand on (Rule 41, "off the meadow").
	local feet: { ReachCheck.Foot } = {}
	local wayModels: { Instance } = {}
	for _, wayUp in waysUp do
		local info = WaysUpRoutes.PIECE_OF[wayUp.name]
		local spot = WaysUpRoutes.startSpot(info.piece, info.isLadder, map, world)
		if spot == nil then
			pcall(PathCheck.cleanup, options)
			error(`RealReach: no standing spot at the foot of {wayUp.name}`)
		end
		table.insert(feet, { name = wayUp.name, spot = spot })
		table.insert(wayModels, surfaces[info.piece])
	end
	local function offLimits(spot: PathCheck.Spot): boolean
		if zoneOf(spot.id) ~= "Meadow" then
			return false
		end
		for _, model in wayModels do
			if spot.standsOn:IsDescendantOf(model) then
				return false
			end
		end
		return true
	end

	return {
		map = map,
		options = options,
		feet = feet,
		zoneOf = zoneOf,
		offLimits = offLimits,
		waysUp = waysUp,
		points = points,
		ladders = ladders,
		zoneBoxes = zoneBoxes,
		graph = RouteGraph.new(points),
	}
end

-- How many steps of `routes` stand on `skirt` (0 when there is no skirt).
function RealReach.standsOnSkirt(map: PathCheck.WalkMap, skirt: Instance?, routes: { PathCheck.Route }): number
	if skirt == nil then
		return 0
	end
	local spotsById: { [number]: PathCheck.Spot } = {}
	for _, spot in map.spots do
		spotsById[spot.id] = spot
	end
	local count = 0
	for _, route in routes do
		for _, step in route.steps do
			for _, id in { step.from, step.to } do
				if spotsById[id].standsOn:IsDescendantOf(skirt) then
					count += 1
				end
			end
		end
	end
	return count
end

-- Each garden with the foot of its way up: for every way up and every garden in it, { garden, spot, startSeconds }.
-- startSeconds is the footprint route's walk on the meadow from the garden's spawn spot (the steps up to the first one
-- that is not a Meadow walk) at Config.Movement.WalkSpeed. It errors with the garden number when a garden has no spawn
-- spot or the footprint route finds no way to Rare egg 1: a missing time is never a guess.
function RealReach.gardens(setup: Setup, world: Instance): { ReachCheck.Garden }
	local spawnOf: { [number]: Vector3 } = {}
	for _, garden in WorldIndex.loadGardens(world) do
		spawnOf[garden.index] = garden.spawnSpot.Position
	end
	local gardens: { ReachCheck.Garden } = {}
	for index, wayUp in setup.waysUp do
		for _, number in wayUp.gardens do
			local spawn: Vector3? = spawnOf[number]
			if spawn == nil then
				error(`RealReach: garden {number} has no spawn spot`)
			end
			local found = RouteGraph.find(setup.graph, spawn, { Config.Nests.RareEggOne })
			if found == nil then
				error(`RealReach: garden {number} has no footprint route to {Config.Nests.RareEggOne}`)
			end
			local studs = 0
			for _, step in FootprintSteps.up(found, setup.points, setup.ladders, setup.zoneBoxes) do
				if step.kind ~= "Walk" or step.zone ~= "Meadow" then
					break
				end
				studs += step.length
			end
			table.insert(gardens, {
				garden = number,
				spot = setup.feet[index].spot,
				startSeconds = studs / Config.Movement.WalkSpeed,
			})
		end
	end
	return gardens
end

return RealReach
