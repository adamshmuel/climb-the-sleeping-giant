--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)

-- costsFrom and routeFrom: one search from a spot, reused for every goal. Each test builds its own fake map by hand
-- (nothing is placed in the world) and compares the answers with route, the one-goal search.
describe("PathCheck.costsFrom and routeFrom", function()
	local function spot(id: number)
		return {
			id = id,
			position = Vector3.new(id, 0, 0),
			up = Vector3.new(0, 1, 0),
			standsOn = Instance.new("Part"),
		}
	end
	local function link(to: number, kind: PathCheck.LinkKind, length: number, seconds: number): PathCheck.Link
		return { to = to, kind = kind, length = length, seconds = seconds }
	end
	-- 1-2-4 is two walks of 10 s, 1-3-4 is a walk of 5 s then a climb of 5 s, 4 to 5 is a slide of 2 s. Spot 6 has no
	-- link in. Every link is one way.
	local function buildMap(): PathCheck.WalkMap
		return {
			spacing = Config.Stuck.ScanSpacing,
			spots = { spot(1), spot(2), spot(3), spot(4), spot(5), spot(6) },
			links = {
				[1] = { link(2, "Walk", 10, 10), link(3, "Walk", 5, 5) },
				[2] = { link(4, "Walk", 10, 10) },
				[3] = { link(4, "Climb", 5, 5) },
				[4] = { link(5, "Slide", 2, 2) },
				[5] = {},
				[6] = {},
			},
			columns = {},
			origin = Vector3.zero,
			countX = 0,
			countZ = 0,
		} :: any
	end

	local function expectSameCostsAsRoute(map: PathCheck.WalkMap, rules: PathCheck.Rules?)
		local search = PathCheck.costsFrom(map, 1, rules)
		for id = 1, 6 do
			local routed = PathCheck.route(map, 1, { id }, rules)
			if routed == nil then
				expect(search.costs[id]).toBeNil()
			else
				expect(search.costs[id]).never.toBeNil()
				expect(search.costs[id]).toBeCloseTo(routed.cost, 5)
			end
		end
	end

	it("costsFrom gives every reachable spot the cost route finds, and 0 for the start", function()
		local map = buildMap()
		local search = PathCheck.costsFrom(map, 1)
		expect(search.from).toBe(1)
		expect(search.costs[1]).toBe(0)
		for id = 1, 5 do
			local routed = PathCheck.route(map, 1, { id }) :: PathCheck.Route
			expect(routed).never.toBeNil()
			expect(search.costs[id]).never.toBeNil()
			expect(search.costs[id]).toBeCloseTo(routed.cost, 5)
		end
	end)

	it("a spot with no way in has no cost, as route finds no route to it", function()
		local map = buildMap()
		expect(PathCheck.costsFrom(map, 1).costs[6]).toBeNil()
		expect(PathCheck.route(map, 1, { 6 })).toBeNil()
	end)

	it("costsFrom follows the allowed link kinds like route", function()
		local map = buildMap()
		local rules: PathCheck.Rules = { allow = { Walk = true } }
		local search = PathCheck.costsFrom(map, 1, rules)
		expect(search.costs[4]).toBeCloseTo(20, 5)
		expect(search.costs[5]).toBeNil()
		expect(search.costs[6]).toBeNil()
		expectSameCostsAsRoute(map, rules)
	end)

	it("costsFrom follows a cost rule like route", function()
		local map = buildMap()
		local rules: PathCheck.Rules = {
			cost = function(each: PathCheck.Link): number
				return if each.kind == "Climb" then 100 else each.seconds
			end,
		}
		expectSameCostsAsRoute(map, rules)
		expect(PathCheck.costsFrom(map, 1, rules).costs[5]).toBeCloseTo(22, 5)
	end)

	it("routeFrom gives the steps route gives, from one search built once", function()
		local map = buildMap()
		local search = PathCheck.costsFrom(map, 1)
		for id = 1, 5 do
			local routed = PathCheck.route(map, 1, { id }) :: PathCheck.Route
			local fromSearch = PathCheck.routeFrom(search, id)
			expect(fromSearch).never.toBeNil()
			expect((fromSearch :: PathCheck.Route).steps).toEqual(routed.steps)
			expect((fromSearch :: PathCheck.Route).cost).toBeCloseTo(routed.cost, 5)
		end
	end)

	it("routeFrom to the start is no steps, and to an unreachable spot is nil", function()
		local search = PathCheck.costsFrom(buildMap(), 1)
		expect(PathCheck.routeFrom(search, 1)).toEqual({ steps = {}, cost = 0 })
		expect(PathCheck.routeFrom(search, 6)).toBeNil()
	end)

	it("a one way link is not followed backwards", function()
		expect(PathCheck.costsFrom(buildMap(), 4).costs[1]).toBeNil()
	end)
end)
