--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)

local SPACING = 3.6

type Point = { name: string, position: Vector3, neighbours: { string }, target: string? }

-- A small fake route on flat ground. `places` gives every point's x and z (y is 0) and its target if it has one;
-- `links` lists the pairs that are joined, and each link goes both ways, like the real route.
type Place = { x: number, z: number, target: string? }

local function newRoute(places: { [string]: Place }, links: { { string } }): { Point }
	local neighbours: { [string]: { string } } = {}
	for name in places do
		neighbours[name] = {}
	end
	for _, link in links do
		table.insert(neighbours[link[1]], link[2])
		table.insert(neighbours[link[2]], link[1])
	end
	local points: { Point } = {}
	for name, place in places do
		table.insert(points, {
			name = name,
			position = Vector3.new(place.x, 0, place.z),
			neighbours = neighbours[name],
			target = place.target,
		})
	end
	table.sort(points, function(a, b)
		return a.name < b.name
	end)
	return points
end

local function expectNear(actual: Vector3, expected: Vector3)
	expect(actual.X).toBeCloseTo(expected.X, 3)
	expect(actual.Y).toBeCloseTo(expected.Y, 3)
	expect(actual.Z).toBeCloseTo(expected.Z, 3)
end

describe("RouteGraph.find: the shortest way", function()
	-- Two ways from S to T. Both have three links, so counting links can't tell them apart: only the walking
	-- distance can. The long way's points sort first by name on purpose.
	local points = newRoute({
		S = { x = 0, z = 0 },
		A = { x = 10, z = 0 },
		B = { x = 20, z = 0 },
		T = { x = 30, z = 0, target = "Egg_T" },
		Along1 = { x = 0, z = 20 },
		Along2 = { x = 30, z = 20 },
	}, {
		{ "S", "A" },
		{ "A", "B" },
		{ "B", "T" },
		{ "S", "Along1" },
		{ "Along1", "Along2" },
		{ "Along2", "T" },
	})

	it("finds the shortest way when there are two ways round", function()
		local graph = RouteGraph.new(points)
		local found = RouteGraph.find(graph, Vector3.new(0, 0, 0), { "Egg_T" })
		expect(found).never.toBeNil()
		local route = found :: RouteGraph.Found
		expect(route.target).toBe("Egg_T")
		expect(route.length).toBeCloseTo(30, 3)
		expect(#route.path).toBe(4)
		expectNear(route.path[1], Vector3.new(0, 0, 0))
		expectNear(route.path[2], Vector3.new(10, 0, 0))
		expectNear(route.path[3], Vector3.new(20, 0, 0))
		expectNear(route.path[4], Vector3.new(30, 0, 0))
	end)

	it("finds the long way when it is the only one left", function()
		-- The same route without the short middle link (A to B): the only way left is the long one (70 studs).
		local cut = newRoute({
			S = { x = 0, z = 0 },
			A = { x = 10, z = 0 },
			B = { x = 20, z = 0 },
			T = { x = 30, z = 0, target = "Egg_T" },
			Along1 = { x = 0, z = 20 },
			Along2 = { x = 30, z = 20 },
		}, {
			{ "S", "A" },
			{ "B", "T" },
			{ "S", "Along1" },
			{ "Along1", "Along2" },
			{ "Along2", "T" },
		})
		local found = RouteGraph.find(RouteGraph.new(cut), Vector3.new(0, 0, 0), { "Egg_T" })
		expect(found).never.toBeNil()
		expect((found :: RouteGraph.Found).length).toBeCloseTo(70, 3)
	end)
end)

describe("RouteGraph.find: joining the route", function()
	it("joins at the nearest spot on a link, not only at points", function()
		-- One long link P to Q (40 studs). The player stands 2 studs beside it, 25 studs along.
		local points = newRoute({
			P = { x = 0, z = 0 },
			Q = { x = 40, z = 0, target = "Egg_Q" },
		}, { { "P", "Q" } })
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(25, 0, 2), { "Egg_Q" })
		expect(found).never.toBeNil()
		local route = found :: RouteGraph.Found
		-- From the spot (25, 0, 0) to Q is 15 studs. (Joining at the point Q would have given 0.)
		expect(route.length).toBeCloseTo(15, 3)
		expectNear(route.path[1], Vector3.new(25, 0, 0))
		expectNear(route.path[#route.path], Vector3.new(40, 0, 0))
	end)

	it("uses the 3D distance from the feet: a link above the player is not the nearest one", function()
		-- Two links of the same length run side by side: a low one at z = 0 and a high one 10 studs up at z = 1. The
		-- player stands on the low level at z = 3. In 3D the low link is 3 studs away and the high one 10.2; if the
		-- height were ignored, the high one (2 studs away) would win.
		local low = Vector3.new(0, 0, 0)
		local points: { Point } = {
			{ name = "LowA", position = low, neighbours = { "LowB" }, target = nil },
			{ name = "LowB", position = Vector3.new(40, 0, 0), neighbours = { "LowA" }, target = "Egg_Low" },
			{ name = "HighA", position = Vector3.new(0, 10, 1), neighbours = { "HighB" }, target = nil },
			{ name = "HighB", position = Vector3.new(40, 10, 1), neighbours = { "HighA" }, target = "Egg_High" },
		}
		-- Only the low link leads to Egg_Low, and only the high one to Egg_High: the join decides which can be reached.
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(20, 0, 3), { "Egg_Low", "Egg_High" })
		expect(found).never.toBeNil()
		expect((found :: RouteGraph.Found).target).toBe("Egg_Low")
	end)

	it("goes toward the nearer end when that end is on the shortest way", function()
		-- P to Q is a long link; behind P, 10 studs further, is the target R. Q is a dead end.
		local points = newRoute({
			R = { x = -10, z = 0, target = "Egg_R" },
			P = { x = 0, z = 0 },
			Q = { x = 40, z = 0 },
		}, { { "R", "P" }, { "P", "Q" } })
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(12, 0, 3), { "Egg_R" })
		expect(found).never.toBeNil()
		local route = found :: RouteGraph.Found
		expect(route.length).toBeCloseTo(22, 3)
		expectNear(route.path[1], Vector3.new(12, 0, 0))
		expectNear(route.path[2], Vector3.new(0, 0, 0))
	end)

	it("goes toward the farther end when only that end leads to the target quickly", function()
		-- The player is nearer Q (10 studs) than P (30 studs). But from Q the only way to the target is a long detour
		-- (30 + 58.3), while from P it is 10 more studs.
		local points = newRoute({
			T = { x = -10, z = 0, target = "Egg_T" },
			P = { x = 0, z = 0 },
			Q = { x = 40, z = 0 },
			W = { x = 40, z = 30 },
		}, { { "T", "P" }, { "P", "Q" }, { "Q", "W" }, { "W", "T" } })
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(30, 0, 3), { "Egg_T" })
		expect(found).never.toBeNil()
		local route = found :: RouteGraph.Found
		expect(route.length).toBeCloseTo(40, 3)
		expectNear(route.path[2], Vector3.new(0, 0, 0))
	end)

	it("joins at a lone point when that is closer than any link", function()
		local points = newRoute({
			Lone = { x = 0, z = 0, target = "Egg_Lone" },
			P = { x = 50, z = 0 },
			Q = { x = 60, z = 0, target = "Egg_Q" },
		}, { { "P", "Q" } })
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(1, 0, 0), { "Egg_Lone", "Egg_Q" })
		expect(found).never.toBeNil()
		local route = found :: RouteGraph.Found
		expect(route.target).toBe("Egg_Lone")
		expect(route.length).toBeCloseTo(0, 3)
	end)
end)

describe("RouteGraph.find: choosing the target", function()
	it("picks the egg with the shortest walk, even when another is nearer in a straight line", function()
		-- Near is 10 studs from S in a straight line, but a wall is in the way: its route goes 30 up, 10 across and
		-- 30 down (70 studs). Far is 40 studs away with a clear way.
		local points = newRoute({
			S = { x = 0, z = 0 },
			Near = { x = 10, z = 0, target = "Egg_Near" },
			U = { x = 0, z = 30 },
			V = { x = 10, z = 30 },
			Far = { x = -40, z = 0, target = "Egg_Far" },
		}, { { "S", "U" }, { "U", "V" }, { "V", "Near" }, { "S", "Far" } })
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(0, 0, 0), { "Egg_Near", "Egg_Far" })
		expect(found).never.toBeNil()
		local route = found :: RouteGraph.Found
		expect(route.target).toBe("Egg_Far")
		expect(route.length).toBeCloseTo(40, 3)
	end)

	it("gives a tie to the first name in alphabetical order, whatever order the names are given in", function()
		local points = newRoute({
			S = { x = 0, z = 0 },
			B = { x = 10, z = 0, target = "Egg_B" },
			A = { x = -10, z = 0, target = "Egg_A" },
		}, { { "S", "A" }, { "S", "B" } })
		local graph = RouteGraph.new(points)
		local first = RouteGraph.find(graph, Vector3.new(0, 0, 0), { "Egg_B", "Egg_A" })
		local second = RouteGraph.find(graph, Vector3.new(0, 0, 0), { "Egg_A", "Egg_B" })
		expect((first :: RouteGraph.Found).target).toBe("Egg_A")
		expect((second :: RouteGraph.Found).target).toBe("Egg_A")
	end)

	it("gives no way when no target is allowed", function()
		local points = newRoute({
			S = { x = 0, z = 0 },
			A = { x = 10, z = 0, target = "Egg_A" },
		}, { { "S", "A" } })
		expect(RouteGraph.find(RouteGraph.new(points), Vector3.new(0, 0, 0), {})).toBeNil()
	end)

	it("gives no way to a target that has no route point", function()
		local points = newRoute({
			S = { x = 0, z = 0 },
			A = { x = 10, z = 0, target = "Egg_A" },
		}, { { "S", "A" } })
		expect(RouteGraph.find(RouteGraph.new(points), Vector3.new(0, 0, 0), { "Egg_Missing" })).toBeNil()
	end)

	it("skips a target that has no route point when another one can be reached", function()
		local points = newRoute({
			S = { x = 0, z = 0 },
			A = { x = 10, z = 0, target = "Egg_A" },
		}, { { "S", "A" } })
		local found = RouteGraph.find(RouteGraph.new(points), Vector3.new(0, 0, 0), { "Egg_Aaa", "Egg_A" })
		expect((found :: RouteGraph.Found).target).toBe("Egg_A")
	end)

	it("gives no way to a target that no link reaches", function()
		local points = newRoute({
			S = { x = 0, z = 0 },
			A = { x = 10, z = 0 },
			Island1 = { x = 100, z = 0, target = "Egg_Island" },
			Island2 = { x = 110, z = 0 },
		}, { { "S", "A" }, { "Island1", "Island2" } })
		expect(RouteGraph.find(RouteGraph.new(points), Vector3.new(0, 0, 0), { "Egg_Island" })).toBeNil()
	end)

	it("gives no way on an empty route", function()
		expect(RouteGraph.find(RouteGraph.new({}), Vector3.new(0, 0, 0), { "Egg_A" })).toBeNil()
	end)
end)

describe("RouteGraph.way: placing footprints", function()
	-- S (0,0) to A (10,0), then a turn to T (10,15): 25 studs in all. The way to walk is +X, then +Z.
	local points = newRoute({
		S = { x = 0, z = 0 },
		A = { x = 10, z = 0 },
		T = { x = 10, z = 15, target = "Egg_T" },
	}, { { "S", "A" }, { "A", "T" } })
	local graph = RouteGraph.new(points)

	it("places one every 3.6 studs counted back from the target, the first one at the target", function()
		local way = RouteGraph.way(graph, Vector3.new(0, 0, 0), { "Egg_T" }, SPACING)
		expect(way).never.toBeNil()
		local steps = (way :: RouteGraph.Way).steps
		-- 25 / 3.6 = 6.94, so seven footprints: 0, 3.6, ... 21.6 studs back from the target.
		expect(#steps).toBe(7)
		expectNear(steps[1].position, Vector3.new(10, 0, 15))
		expectNear(steps[2].position, Vector3.new(10, 0, 11.4))
		expectNear(steps[5].position, Vector3.new(10, 0, 0.6))
		-- 18 studs back is 3 studs past the turn, on the first part.
		expectNear(steps[6].position, Vector3.new(7, 0, 0))
		expectNear(steps[7].position, Vector3.new(3.4, 0, 0))
	end)

	it("gives each one the direction to walk there", function()
		local way = RouteGraph.way(graph, Vector3.new(0, 0, 0), { "Egg_T" }, SPACING)
		local steps = (way :: RouteGraph.Way).steps
		-- The last part runs +Z (from the turn to the target), the first part +X.
		expectNear(steps[1].direction, Vector3.new(0, 0, 1))
		expectNear(steps[5].direction, Vector3.new(0, 0, 1))
		expectNear(steps[6].direction, Vector3.new(1, 0, 0))
		expectNear(steps[7].direction, Vector3.new(1, 0, 0))
	end)

	it("reports the target and the walking distance", function()
		local way = RouteGraph.way(graph, Vector3.new(0, 0, 0), { "Egg_T" }, SPACING) :: RouteGraph.Way
		expect(way.target).toBe("Egg_T")
		expect(way.length).toBeCloseTo(25, 3)
	end)

	it("keeps the ones ahead where they are when the player walks 1 stud along the way", function()
		local before = (RouteGraph.way(graph, Vector3.new(0, 0, 0), { "Egg_T" }, SPACING) :: RouteGraph.Way).steps
		local after = (RouteGraph.way(graph, Vector3.new(1, 0, 0), { "Egg_T" }, SPACING) :: RouteGraph.Way).steps
		expect(#after).toBe(#before)
		for index, step in before do
			expectNear(after[index].position, step.position)
			expectNear(after[index].direction, step.direction)
		end
	end)

	it("drops only the one behind the player when they walk past it", function()
		local before = (RouteGraph.way(graph, Vector3.new(0, 0, 0), { "Egg_T" }, SPACING) :: RouteGraph.Way).steps
		-- The last footprint is at x = 3.4. At x = 4 the player has passed it.
		local after = (RouteGraph.way(graph, Vector3.new(4, 0, 0), { "Egg_T" }, SPACING) :: RouteGraph.Way).steps
		expect(#after).toBe(#before - 1)
		for index, step in after do
			expectNear(step.position, before[index].position)
		end
	end)

	it("keeps the ones ahead where they are when the player stands a little beside the way", function()
		local before = (RouteGraph.way(graph, Vector3.new(2, 0, 1.5), { "Egg_T" }, SPACING) :: RouteGraph.Way).steps
		local after = (RouteGraph.way(graph, Vector3.new(3, 0, -1), { "Egg_T" }, SPACING) :: RouteGraph.Way).steps
		expect(#after).toBe(#before)
		for index, step in before do
			expectNear(after[index].position, step.position)
		end
	end)

	it("shows nothing when the player stands at the target", function()
		local way = RouteGraph.way(graph, Vector3.new(10, 0, 15), { "Egg_T" }, SPACING) :: RouteGraph.Way
		expect(way.length).toBeCloseTo(0, 3)
		expect(#way.steps).toBe(0)
	end)

	it("gives no way when no target can be reached", function()
		expect(RouteGraph.way(graph, Vector3.new(0, 0, 0), {}, SPACING)).toBeNil()
	end)

	it("follows a way that climbs: the direction points up the slope", function()
		local ramp = newRoute({
			Foot = { x = 0, z = 0 },
			Top = { x = 10, z = 0, target = "Egg_Top" },
		}, { { "Foot", "Top" } })
		-- Lift the top 5 studs.
		for _, point in ramp do
			if point.name == "Top" then
				point.position = Vector3.new(10, 5, 0)
			end
		end
		local way = RouteGraph.way(RouteGraph.new(ramp), Vector3.new(0, 0, 0), { "Egg_Top" }, SPACING) :: RouteGraph.Way
		local expected = Vector3.new(10, 5, 0).Unit
		expectNear(way.steps[1].direction, expected)
		expectNear(way.steps[1].position, Vector3.new(10, 5, 0))
		expect(way.steps[2].position.Y).toBeCloseTo(5 - 3.6 * expected.Y, 3)
	end)
end)
