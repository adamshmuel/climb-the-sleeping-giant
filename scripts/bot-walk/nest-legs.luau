--!strict
-- Plan 4 Task 13a: the nest walk's legs job (SERVER; an Edit dry run is allowed). Spec: work/p4t13/13a-scripts.md.
-- Builds the 44 trips (16 meadow, 8 Uncommon, 6 Rare, 2 Beard Fold extras, 4 cap, 8 cuff) from the real routes and
-- writes one StringValue per trip, T01 to T44, into the folder P4t13Legs (ReplicatedStorage in Play, ServerStorage in
-- Edit). Status: attribute P4t13LegsState on the same service: building, then `done 44 trips, ...` or `FIRED <why>`.
-- Group of a trip by its number: A = T01 to T24, B = T25 to T32, C = T33 to T44. `st` is the start point (feet).
-- CHECK_ONLY = true: writes nothing.
local CHECK_ONLY = false

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HeistScore = require(ServerScriptService.Server.World.HeistScore)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
-- WalkFacts requires JestGlobals, which errors outside a Jest run (see work/p5t15d/facts.luau). So the job works on a
-- clone of the StuckScan folder (parent nil) whose WalkFacts has a stand-in expect (nil check only).
local STUB = "local JestGlobals = { expect = function(v) return { never = { toBeNil = function() "
	.. "assert(v ~= nil, 'WalkFacts: nil') end } } end }\n"
local requireModule: (Instance) -> any = require :: any
local StuckScan: any = ServerStorage.Tests.server.World.StuckScan:Clone()
local walkFacts: any = StuckScan.WalkFacts
walkFacts.Source = string.gsub(walkFacts.Source :: string, "local JestGlobals = require%([^\n]*\n", STUB, 1)
local FootprintSteps: any = requireModule(StuckScan.FootprintSteps)
local RealReach: any = requireModule(StuckScan.RealReach)
local WaysUpRoutes: any = requireModule(StuckScan.WaysUpRoutes)

local function held(): (boolean, string)
	local beat, phase =
		ReplicatedStorage:GetAttribute("TrialHoldBeat"), ReplicatedStorage:GetAttribute("TrialHoldPhase")
	if type(beat) ~= "number" or Workspace:GetServerTimeNow() - beat > 2 then
		return false, "no or old beat"
	end
	return phase == "Asleep", "phase " .. tostring(phase)
end

local isEdit = not RunService:IsRunning()
local box: Instance = if isEdit then ServerStorage else ReplicatedStorage
local STATE = "P4t13LegsState"
if CHECK_ONLY then
	return `would build 44 trips into P4t13Legs under {box.Name}; writes nothing`
end
if box:GetAttribute(STATE) == "building" then
	return "already building"
end

type Point = { x: number, y: number, z: number, c: boolean }
type Trip = { n: string, w: string, g: number, s: number, k: string, st: Point, up: { Point }, dn: { Point } }
type Adder = (string, string, number, number, string, Vector3, { Point }, { Point }) -> ()

-- The home garden of each way up (Config.WaysUp, WaysUpRoutes.PIECE_OF).
local HOME: { [string]: number } =
	{ ["Left boot ladder"] = 3, ["Left ramp"] = 4, ["Right ramp"] = 5, ["Right boot ladder"] = 6 }
local SIDE_WAYS: { [string]: { string } } =
	{ Left = { "Left boot ladder", "Left ramp" }, Right = { "Right ramp", "Right boot ladder" } }
-- docs/egg-ranks.md (2026-11-11), name without "Nest_" and its score: a scored nest more than 1 point off is FIRED.
local EXPECT: { [string]: number } = {}
for name, score in
	string.gmatch(
		[[BootToeOuter_Right 18 BootToeOuter_Left 18 BootToeInner_Right 19 BootToeInner_Left 19 LapFold_Left 27
		KneePocket_Left 28 LapFold_Right 39 KneePocket_Right 39 LowerBelly_Left 69 BellyPocket_Left 72
		LowerBelly_Right 72 BeardFold_Left 75 BeardFold_Right 75 BellyPocket_Right 75 CapBrim_Left 373
		CapBrim_Right 375 CapSide_Left 405 CapSide_Right 406]],
		"(%S+) (%d+)"
	)
do
	EXPECT["Nest_" .. name] = tonumber(score) or 0
end
local function names(text: string): { string }
	local list: { string } = {}
	for word in string.gmatch(text, "%S+") do
		list[#list + 1] = "Nest_" .. word
	end
	return list
end
local UNCOMMON = names("BootToeOuter_Left BootToeOuter_Right BootToeInner_Left BootToeInner_Right")
table.move(names("LapFold_Left LapFold_Right KneePocket_Left KneePocket_Right"), 1, 4, 5, UNCOMMON)
local RARE = names("LowerBelly_Left LowerBelly_Right BellyPocket_Left BellyPocket_Right BeardFold_Left BeardFold_Right")
local FOLDS = names("BeardFold_Left BeardFold_Right")
local CAPS = names("CapBrim_Left CapBrim_Right CapSide_Left CapSide_Right")
local CUFFS = names("CuffBack_Left CuffBack_Right CuffFront_Left CuffFront_Right")

local function r2(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end
local function pt(p: Vector3, c: boolean): Point
	return { x = r2(p.X), y = r2(p.Y), z = r2(p.Z), c = c }
end
local function sideOf(name: string): string
	return if string.find(name, "_Left", 1, true) ~= nil then "Left" else "Right"
end
-- A nil value is a FIRED line (the checker does not narrow after a `never` call, so this returns the value).
local function need<T>(value: T?, why: string): T
	if value == nil then
		error(`FIRED {why}`, 0)
	end
	return value
end

local function build(): string
	local started = os.clock()
	local world = need(Workspace:FindFirstChild("World"), "Workspace.World is missing")
	local setup = RealReach.build(world, WaysUpRoutes.EGG_AREA, WaysUpRoutes.EGG_FINE_BOXES)
	local ok, text = pcall(function(): string
		local reach: ReachCheck.Options = {
			map = setup.map,
			feet = setup.feet,
			gardens = RealReach.gardens(setup, world),
			zoneOf = setup.zoneOf,
			rareFrom = Config.Ranks.BandEdges.Rare,
		}
		local read, problems = WorldIndex.readEggSpots(world)
		local eggSpots = need(read, `egg spots: {table.concat(problems, " | ")}`)
		local spotOf: { [string]: WorldIndex.EggSpot } = {}
		for _, eggSpot in eggSpots do
			spotOf[eggSpot.name] = eggSpot
		end
		local function input(name: string): ReachCheck.NestInput
			local eggSpot = need(spotOf[name], `{name} is not in World.EggSpots`)
			return { name = name, position = eggSpot.cframe.Position, inMeadow = eggSpot.garden ~= nil }
		end

		local spotsById: { [number]: PathCheck.Spot } = {}
		for _, spot in setup.map.spots do
			spotsById[spot.id] = spot
		end
		local footSpot: { [string]: number } = {}
		for _, foot in setup.feet do
			footSpot[foot.name] = foot.spot
		end
		local footOf: { [string]: Vector3 } = {}
		for _, wayUp in setup.waysUp do
			footOf[wayUp.name] = wayUp.foot.position
		end
		local spawnTop: { [number]: Vector3 } = {}
		for _, garden in WorldIndex.loadGardens(world) do
			local spot = garden.spawnSpot
			spawnTop[garden.index] = spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
		end
		local function footAt(way: string): Vector3
			return spotsById[need(footSpot[way], `{way} has no foot spot`)].position
		end

		local trips: { Trip } = {}
		local stepCount = 0
		local add: Adder = function(name, way, garden, score, kind, start, up, dn)
			stepCount += #up + #dn
			table.insert(
				trips,
				{ n = name, w = way, g = garden, s = r2(score), k = kind, st = pt(start, false), up = up, dn = dn }
			)
		end
		local function stepPoints(route: PathCheck.Route): { Point }
			local list: { Point } = {}
			for _, step in route.steps do
				local spot = need(spotsById[step.to], `a route step goes to spot {step.to}, not on the map`)
				list[#list + 1] = pt(spot.position, step.kind == "Climb")
			end
			return list
		end
		-- A footprint route found from `start`: its peak carrying `egg`, up = its points, dn = the same path reversed.
		local function footprintLeg(
			name: string,
			start: Vector3,
			egg: Config.RarityName
		): (number, { Point }, { Point })
			local found = need(RouteGraph.find(setup.graph, start, { name }), `{name}: no footprint route from {start}`)
			local up: { Point } = {}
			local dn: { Point } = {}
			for i = 1, #found.path - 1 do
				up[#up + 1] = pt(found.path[i + 1], found.climbs[i])
			end
			for i = #found.path - 1, 1, -1 do
				dn[#dn + 1] = pt(found.path[i], found.climbs[i])
			end
			local steps = FootprintSteps.up(found, setup.points, setup.ladders, setup.zoneBoxes)
			local replay = { up = steps, down = HeistScore.dropDown(steps), egg = egg, tiptoe = false }
			return HeistScore.replay(replay).peak, up, dn
		end

		-- Group A: the 16 meadow nests, from their own garden's SpawnSpot top.
		for garden = 1, 8 do
			for _, letter in { "a", "b" } do
				local name = `Nest_Meadow_{garden}{letter}`
				if input(name).inMeadow == false then
					error(`FIRED {name} is not a meadow nest`, 0)
				end
				local start = need(spawnTop[garden], `garden {garden} has no SpawnSpot`)
				local peak, up, dn = footprintLeg(name, start, "Common")
				add(name, `garden {garden}`, garden, peak, "footprint", start, up, dn)
			end
		end

		-- The 18 scored nests on him (no cuffs), found alone and picked by the egg check's own search.
		local scoredNames: { string } = {}
		for _, list in { UNCOMMON, RARE, CAPS } do
			table.move(list, 1, #list, #scoredNames + 1, scoredNames)
		end
		local inputs: { ReachCheck.NestInput } = {}
		for _, name in scoredNames do
			table.insert(inputs, input(name))
		end
		local resultOf: { [string]: ReachCheck.NestResult } = {}
		for index, result in ReachCheck.analyseAll(reach, inputs) do
			resultOf[scoredNames[index]] = result
		end
		local function addScored(name: string)
			local result = resultOf[name]
			local why = `{name}: no route (reached {tostring(result.reached)}, score {r2(result.score)})`
			local upRoute, downRoute = need(result.up, why), need(result.down, why)
			local upBy, homeBy = need(result.upBy, why), need(result.homeBy, why)
			if math.abs(result.score - EXPECT[name]) > 1 then
				error(`FIRED {name}: score {r2(result.score)}, docs/egg-ranks.md says {EXPECT[name]}`, 0)
			end
			local steps = { stepPoints(upRoute), stepPoints(downRoute) }
			add(name, upBy, HOME[homeBy], result.score, "scored", footAt(upBy), steps[1], steps[2])
		end
		for _, list in { UNCOMMON, RARE } do
			for _, name in list do
				addScored(name)
			end
		end
		-- Group B extras: each Beard Fold nest from the way up on its side that is not its upBy.
		local foldInputs: { ReachCheck.NestInput } = { input(FOLDS[1]), input(FOLDS[2]) }
		local peaks = ReachCheck.peaksByFoot(reach, foldInputs, "Rare", setup.offLimits)
		for _, name in FOLDS do
			local other: string? = nil
			for _, way in SIDE_WAYS[sideOf(name)] do
				if way ~= resultOf[name].upBy then
					other = way
				end
			end
			local way = need(other, `{name}: no other way up on its side`)
			local trip = need(peaks[name][way], `{name}: no trip from {way}`)
			add(name, way, HOME[way], trip.peak, "foot", footAt(way), stepPoints(trip.up), stepPoints(trip.down))
		end
		for _, name in CAPS do
			addScored(name)
		end
		-- Group C cuffs: footprint route from each of the 2 ways up on the nest's own side.
		for _, name in CUFFS do
			for _, way in SIDE_WAYS[sideOf(name)] do
				local peak, up, dn = footprintLeg(name, footOf[way], "Epic")
				add(name, way, HOME[way], peak, "footprint", footOf[way], up, dn)
			end
		end

		if #trips ~= 44 then
			error(`FIRED {#trips} trips built, expected 44`, 0)
		end
		local old = box:FindFirstChild("P4t13Legs")
		if old ~= nil then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "P4t13Legs"
		for index, trip in trips do
			local value = Instance.new("StringValue")
			value.Name = string.format("T%02d", index)
			value.Value = HttpService:JSONEncode(trip)
			value.Parent = folder
		end
		folder.Parent = box
		return `done 44 trips, {stepCount} steps, {string.format("%.0f", os.clock() - started)} s`
	end)
	pcall(PathCheck.cleanup, setup.options)
	if not ok then
		local message = tostring(text)
		error(if string.sub(message, 1, 5) == "FIRED" then message else `FIRED error: {message}`, 0)
	end
	return text
end

local function fired(state: any): string
	local message = tostring(state)
	return if string.sub(message, 1, 5) == "FIRED" then message else `FIRED {message}`
end
box:SetAttribute(STATE, "building")
task.defer(function()
	local ok, state = pcall(build)
	box:SetAttribute(STATE, if ok then state else fired(state))
end)
if isEdit then
	return "started"
end
local heldOk, heldWhy = held()
return `started (giant hold: {if heldOk then "held" else heldWhy})`
