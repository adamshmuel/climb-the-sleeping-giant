--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll = JestGlobals.beforeAll, JestGlobals.afterAll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local FairnessCheck = require(ServerScriptService.Server.World.FairnessCheck)
local HeistScore = require(ServerScriptService.Server.World.HeistScore)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
local FootprintSteps = require(script.Parent.FootprintSteps)
local GiantPlaces = require(script.Parent.GiantPlaces)
local RealReach = require(script.Parent.RealReach)
local WaysUpRoutes = require(script.Parent.WaysUpRoutes)

-- Spec 3, Rule 41 (Every way up is equally loud), on the real world: each way up's quietest Rare egg 1 peak, its
-- footprint route's peak and its quietest Uncommon peak, on the same even-row map as the route tests in
-- OnTheGiant.spec. It also works out the footprint Uncommon peak; the 5-point gap is judged on the footprint route. The
-- limits and the judging are FairnessCheck's; the search is ReachCheck's. The table is printed for the notes.
-- Plan 5 Task 20, Rule 73: the same comparison for every rank (Rare, Epic, Legendary), the beard-belly fold and the
-- Epic cuff front pocket, on the footprint route, and the 100 line for every Rare nest on both routes.
describe("the ways up are equally loud (Rule 41)", function()
	local options: PathCheck.Options? = nil
	local verdict: FairnessCheck.Verdict? = nil
	local skirtSteps = 0 -- steps of any fairness route that stand on World.CaveSkirt
	local rankFailures: { string } = {}
	local ceilingFailures: { string } = {}

	-- The two ways up on his left (gardens 1 to 4) use the left nest of a pair; the other two use the _Right twin.
	local LEFT_WAYS: { [string]: boolean } = { ["Left boot ladder"] = true, ["Left ramp"] = true }
	-- The quietest-route column the check does not score (Rule 73 ruling): the bot walk and the egg check do.
	local QUIET_BY: { [string]: string } =
		{ Epic = "Task 22", Legendary = "egg check", ["cuff front pocket"] = "Task 22" }

	beforeAll(function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		local world = found :: Instance
		local setup = RealReach.build(world, WaysUpRoutes.ROUTE_AREA)
		options = setup.options
		local points, ladders, zoneBoxes = setup.points, setup.ladders, setup.zoneBoxes
		local waysUp, graph, offLimits = setup.waysUp, setup.graph, setup.offLimits

		local reach: ReachCheck.Options = {
			map = setup.map,
			feet = setup.feet,
			gardens = {},
			zoneOf = setup.zoneOf,
			rareFrom = math.huge,
		}
		local rareNests: { ReachCheck.NestInput } = {}
		local uncommonNests: { ReachCheck.NestInput } = {}
		local namesOfRank: { [string]: { string } } = { Rare = {}, Epic = {}, Legendary = {} }
		local eggSpots, spotProblems = WorldIndex.readEggSpots(world)
		expect(spotProblems).toEqual({})
		for _, eggSpot in eggSpots :: { WorldIndex.EggSpot } do
			local nest: ReachCheck.NestInput =
				{ name = eggSpot.name, position = eggSpot.cframe.Position, inMeadow = eggSpot.garden ~= nil }
			if eggSpot.rarity == "Rare" then
				table.insert(rareNests, nest)
			elseif eggSpot.rarity == "Uncommon" then
				table.insert(uncommonNests, nest)
			end
			if namesOfRank[eggSpot.rarity] ~= nil then
				table.insert(namesOfRank[eggSpot.rarity], eggSpot.name)
			end
		end
		local rareTrips = ReachCheck.peaksByFoot(reach, rareNests, "Rare", offLimits)
		local uncommonTrips = ReachCheck.peaksByFoot(reach, uncommonNests, "Uncommon", offLimits)

		local uncommonNames: { string } = {}
		for _, nest in uncommonNests do
			table.insert(uncommonNames, nest.name)
		end
		-- The footprint route's peak from a foot to the nearest of `names`, carrying `egg` home; nil when it can't reach.
		local function footprintPeak(foot: Vector3, names: { string }, egg: Config.RarityName): number?
			local route = RouteGraph.find(graph, foot, names)
			if route == nil then
				return nil
			end
			local up = FootprintSteps.up(route, points, ladders, zoneBoxes)
			return HeistScore.replay({ up = up, down = HeistScore.dropDown(up), egg = egg, tiptoe = false }).peak
		end

		local ways: { FairnessCheck.WayUpPeaks } = {}
		local routes: { PathCheck.Route } = {}
		for _, wayUp in waysUp do
			local rare = rareTrips[Config.Nests.RareEggOne][wayUp.name]
			local quietUncommon: number? = nil
			for _, byFoot in uncommonTrips do
				local trip = byFoot[wayUp.name]
				if trip ~= nil then
					quietUncommon = math.min(quietUncommon or math.huge, trip.peak)
					table.insert(routes, trip.up)
					table.insert(routes, trip.down)
				end
			end
			local footprintRare = footprintPeak(wayUp.foot.position, { Config.Nests.RareEggOne }, "Rare")
			local footprintUncommon = footprintPeak(wayUp.foot.position, uncommonNames, "Uncommon")
			if rare ~= nil then
				table.insert(routes, rare.up)
				table.insert(routes, rare.down)
			end
			table.insert(ways, {
				name = wayUp.name,
				gardens = wayUp.gardens,
				isLadder = WaysUpRoutes.PIECE_OF[wayUp.name].isLadder,
				quietRare = if rare ~= nil then rare.peak else nil,
				footprintRare = footprintRare,
				quietUncommon = quietUncommon,
				footprintUncommon = footprintUncommon,
			})
		end

		-- Rule 73: per rank and per pair, the lowest footprint peak over its nests (each found alone) for every way up.
		local function lowestFootprint(foot: Vector3, names: { string }, egg: Config.RarityName): number?
			local best: number? = nil
			for _, name in names do
				local peak = footprintPeak(foot, { name }, egg)
				if peak ~= nil then
					best = math.min(best or math.huge, peak)
				end
			end
			return best
		end
		local function lowestQuiet(wayName: string, names: { string }): number?
			local best: number? = nil
			for _, name in names do
				local trip = rareTrips[name][wayName]
				if trip ~= nil then
					best = math.min(best or math.huge, trip.peak)
				end
			end
			return best
		end
		local function pairName(base: string, wayName: string): string
			return `{base}_{if LEFT_WAYS[wayName] then "Left" else "Right"}`
		end
		local rows: { FairnessCheck.RankRow } = {}
		local function addRankRow(rank: Config.RarityName)
			local row: FairnessCheck.RankRow = { label = rank, ways = {} }
			for _, wayUp in waysUp do
				local footprint = lowestFootprint(wayUp.foot.position, namesOfRank[rank], rank)
				local quiet = if rank == "Rare" then lowestQuiet(wayUp.name, namesOfRank.Rare) else nil
				table.insert(row.ways, { name = wayUp.name, footprint = footprint, quiet = quiet })
			end
			table.insert(rows, row)
		end
		addRankRow("Rare")
		addRankRow("Epic")
		addRankRow("Legendary")
		local pairRows: { { label: string, base: string, egg: Config.RarityName, rare: boolean } } = {
			{ label = "beard-belly fold", base = "Nest_BeardFold", egg = "Rare", rare = true },
			{ label = "cuff front pocket", base = "Nest_CuffFront", egg = "Epic", rare = false },
		}
		for _, pair in pairRows do
			local row: FairnessCheck.RankRow = { label = pair.label, ways = {} }
			for _, wayUp in waysUp do
				local name = pairName(pair.base, wayUp.name)
				table.insert(row.ways, {
					name = wayUp.name,
					footprint = footprintPeak(wayUp.foot.position, { name }, pair.egg),
					quiet = if pair.rare then lowestQuiet(wayUp.name, { name }) else nil,
				})
			end
			table.insert(rows, row)
		end
		local ranked = FairnessCheck.judgeRanks(rows)
		rankFailures = ranked.failures

		-- The 100 line: every Rare nest through every way up, on both routes.
		local trips: { { nest: string, way: string, route: string, peak: number } } = {}
		for _, name in namesOfRank.Rare do
			for _, wayUp in waysUp do
				local quiet = rareTrips[name][wayUp.name]
				if quiet ~= nil then
					table.insert(trips, { nest = name, way = wayUp.name, route = "quietest", peak = quiet.peak })
				end
				local footprint = footprintPeak(wayUp.foot.position, { name }, "Rare")
				if footprint ~= nil then
					table.insert(trips, { nest = name, way = wayUp.name, route = "footprint", peak = footprint })
				end
			end
		end
		ceilingFailures = FairnessCheck.judgeCeiling(trips)
		local highest = 0
		for _, trip in trips do
			highest = math.max(highest, trip.peak)
		end

		local judged = FairnessCheck.judge(ways)
		verdict = judged
		skirtSteps = RealReach.standsOnSkirt(setup.map, world:FindFirstChild("CaveSkirt"), routes)
		print("FAIRNESS TABLE")
		print(judged.table)
		print("RANK TABLE")
		print(ranked.table)
		for label, by in QUIET_BY do
			print(`quietest column for {label}: {by}`)
		end
		print(`RANK REPORTS {#ranked.reports}`)
		for _, line in ranked.reports do
			print(line)
		end
		print(
			`CEILING: {#trips} trips, highest peak {string.format("%.1f", highest)}, {#ceilingFailures} at 100 or more`
		)
		print(`FAIRNESS REPORTS {#judged.reports}`)
		for _, line in judged.reports do
			print(line)
		end
	end, GiantPlaces.SCAN_TIMEOUT_MS)

	afterAll(function()
		if options ~= nil then
			pcall(PathCheck.cleanup, options)
		end
	end)

	it("every way up is equally loud to Rare egg 1 and the Uncommon nests", function()
		expect(table.concat((verdict :: FairnessCheck.Verdict).failures, " | ")).toBe("")
	end)

	it("every rank, the beard-belly fold and the cuff front pocket are fair from every way up (Rule 73)", function()
		expect(table.concat(rankFailures, " | ")).toBe("")
	end)

	it("no heist to a Rare nest reaches 100 through any way up", function()
		expect(table.concat(ceilingFailures, " | ")).toBe("")
	end)

	it("no fairness route stands on the cave skirt", function()
		expect(skirtSteps).toBe(0)
	end)
end)
