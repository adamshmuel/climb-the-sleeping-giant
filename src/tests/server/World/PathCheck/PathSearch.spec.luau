--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local PathSearch = require(ServerScriptService.Server.World.PathSearch)

-- PathSearch on its own: the cheapest-route search over a graph of links. Each test builds a hand-made 4-spot graph
-- (nothing is placed in the world).
describe("PathSearch", function()
	local function link(to: number, kind: PathSearch.LinkKind, seconds: number): PathSearch.Link
		return { to = to, kind = kind, length = seconds, seconds = seconds }
	end
	-- 1 to 2 to 4 is two walks of 10 s; 1 to 3 to 4 is a walk of 5 s then a climb of 5 s. Spot 5 has no link in.
	local function buildGraph(): PathSearch.Graph
		return {
			links = {
				[1] = { link(2, "Walk", 10), link(3, "Walk", 5) },
				[2] = { link(4, "Walk", 10) },
				[3] = { link(4, "Climb", 5) },
				[4] = {},
				[5] = {},
			},
		}
	end

	it("route finds the quicker of two ways and returns its steps and cost", function()
		local route = PathSearch.route(buildGraph(), 1, { 4 })
		expect(route).never.toBeNil()
		local found = route :: PathSearch.Route
		expect(found.cost).toBe(10)
		expect(#found.steps).toBe(2)
		expect(found.steps[1].from).toBe(1)
		expect(found.steps[1].to).toBe(3)
		expect(found.steps[2].to).toBe(4)
		expect(found.steps[2].kind).toBe("Climb")
	end)

	it("costsFrom gives each reachable cost and no entry for an unreachable spot", function()
		local searched = PathSearch.costsFrom(buildGraph(), 1)
		expect(searched.costs[1]).toBe(0)
		expect(searched.costs[2]).toBe(10)
		expect(searched.costs[3]).toBe(5)
		expect(searched.costs[4]).toBe(10)
		expect(searched.costs[5]).toBeNil()
	end)

	it("routeFrom gives the same steps as route and nil for an unreachable spot", function()
		local graph = buildGraph()
		local searched = PathSearch.costsFrom(graph, 1)
		local fromSearch = PathSearch.routeFrom(searched, 4) :: PathSearch.Route
		local direct = PathSearch.route(graph, 1, { 4 }) :: PathSearch.Route
		expect(fromSearch.cost).toBe(direct.cost)
		expect(#fromSearch.steps).toBe(#direct.steps)
		for index, step in direct.steps do
			expect(fromSearch.steps[index].from).toBe(step.from)
			expect(fromSearch.steps[index].to).toBe(step.to)
		end
		expect(PathSearch.routeFrom(searched, 5)).toBeNil()
	end)

	it("PathCheck re-exports the very same functions", function()
		expect(PathCheck.route == PathSearch.route).toBe(true)
		expect(PathCheck.costsFrom == PathSearch.costsFrom).toBe(true)
		expect(PathCheck.routeFrom == PathSearch.routeFrom).toBe(true)
	end)
end)
