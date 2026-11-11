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
describe("the ways up are equally loud (Rule 41)", function()
	local options: PathCheck.Options? = nil
	local verdict: FairnessCheck.Verdict? = nil
	local skirtSteps = 0 -- steps of any fairness route that stand on World.CaveSkirt

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
		local eggSpots, spotProblems = WorldIndex.readEggSpots(world)
		expect(spotProblems).toEqual({})
		for _, eggSpot in eggSpots :: { WorldIndex.EggSpot } do
			local nest: ReachCheck.NestInput =
				{ name = eggSpot.name, position = eggSpot.cframe.Position, inMeadow = eggSpot.garden ~= nil }
			if eggSpot.name == Config.Nests.RareEggOne then
				table.insert(rareNests, nest)
			elseif eggSpot.rarity == "Uncommon" then
				table.insert(uncommonNests, nest)
			end
		end
		local rareTrips = ReachCheck.peaksByFoot(reach, rareNests, "Rare", offLimits)
		local uncommonTrips = ReachCheck.peaksByFoot(reach, uncommonNests, "Uncommon", offLimits)

		local uncommonNames: { string } = {}
		for _, nest in uncommonNests do
			table.insert(uncommonNames, nest.name)
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
			local footprintRare: number? = nil
			local foundRoute = RouteGraph.find(graph, wayUp.foot.position, { Config.Nests.RareEggOne })
			if foundRoute ~= nil then
				local up = FootprintSteps.up(foundRoute, points, ladders, zoneBoxes)
				footprintRare =
					HeistScore.replay({ up = up, down = HeistScore.dropDown(up), egg = "Rare", tiptoe = false }).peak
			end
			local footprintUncommon: number? = nil
			local uncommonRoute = RouteGraph.find(graph, wayUp.foot.position, uncommonNames)
			if uncommonRoute ~= nil then
				local up = FootprintSteps.up(uncommonRoute, points, ladders, zoneBoxes)
				footprintUncommon = HeistScore.replay({
					up = up,
					down = HeistScore.dropDown(up),
					egg = "Uncommon",
					tiptoe = false,
				}).peak
			end
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

		local judged = FairnessCheck.judge(ways)
		verdict = judged
		skirtSteps = RealReach.standsOnSkirt(setup.map, world:FindFirstChild("CaveSkirt"), routes)
		print("FAIRNESS TABLE")
		print(judged.table)
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

	it("no fairness route stands on the cave skirt", function()
		expect(skirtSteps).toBe(0)
	end)
end)
