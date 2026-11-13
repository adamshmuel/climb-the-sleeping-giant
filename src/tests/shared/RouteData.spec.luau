--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local RouteData = require(ReplicatedStorage.Shared.RouteData)

-- One fake route point: its name, where its top centre is, who it links to (a text list) and what it stands at.
type Entry = {
	name: string,
	top: Vector3?,
	neighbours: any?, -- the text written to the Neighbours attribute (any, so a test can write a wrong type)
	target: any?,
	ladder: any?, -- the text written to the Ladder attribute (any, so a test can write a wrong type)
	wayUpFoot: any?,
	wayUpTop: any?,
	className: string?, -- what to build instead of a Part
}

-- Every fake route made by a test is destroyed afterwards, so the real place is never changed.
local madeRoutes: { Instance } = {}
afterEach(function()
	for _, route in madeRoutes do
		route:Destroy()
	end
	table.clear(madeRoutes)
end)

-- Builds a fake route Model with no parent. Each point is a flat 1 x 0.2 x 1 part whose top centre is `top`.
local function makeRoute(entries: { Entry }): Model
	local route = Instance.new("Model")
	route.Name = "Route"
	table.insert(madeRoutes, route)
	for _, entry in entries do
		local point: Instance = Instance.new((entry.className or "Part") :: any)
		point.Name = entry.name
		if point:IsA("BasePart") then
			point.Size = Vector3.new(1, 0.2, 1)
			point.CFrame = CFrame.new((entry.top or Vector3.zero) - Vector3.new(0, 0.1, 0))
		end
		if entry.neighbours ~= nil then
			point:SetAttribute("Neighbours", entry.neighbours)
		end
		if entry.target ~= nil then
			point:SetAttribute("Target", entry.target)
		end
		if entry.ladder ~= nil then
			point:SetAttribute("Ladder", entry.ladder)
		end
		if entry.wayUpFoot ~= nil then
			point:SetAttribute("WayUpFoot", entry.wayUpFoot)
		end
		if entry.wayUpTop ~= nil then
			point:SetAttribute("WayUpTop", entry.wayUpTop)
		end
		point.Parent = route
	end
	return route
end

-- A good little route: Spawn - Bridge - Egg, with the egg and the spawn named as targets.
local function goodEntries(): { Entry }
	return {
		{
			name = "RoutePoint_Egg",
			top = Vector3.new(30, 2, 0),
			neighbours = "RoutePoint_Bridge",
			target = "EggSpot_Common_1",
		},
		{
			name = "RoutePoint_Spawn",
			top = Vector3.new(0, 2, 0),
			neighbours = "RoutePoint_Bridge",
			target = "Spawn_1",
		},
		{
			name = "RoutePoint_Bridge",
			top = Vector3.new(15, 0.7, 0),
			neighbours = "RoutePoint_Spawn,RoutePoint_Egg",
		},
	}
end

describe("RouteData.read", function()
	it("reads each point's name, the top centre of its part, its neighbours and its target", function()
		local route = makeRoute(goodEntries())
		local points, problems = RouteData.read(route)
		expect(problems).toEqual({})
		expect(#points).toBe(3)
		-- the points come back in name order, whatever order they were made in
		expect(points[1].name).toBe("RoutePoint_Bridge")
		expect(points[2].name).toBe("RoutePoint_Egg")
		expect(points[3].name).toBe("RoutePoint_Spawn")
		expect(points[1].position).toEqual(Vector3.new(15, 0.7, 0))
		expect(points[2].position).toEqual(Vector3.new(30, 2, 0))
		expect(points[3].position).toEqual(Vector3.new(0, 2, 0))
		expect(points[1].neighbours).toEqual({ "RoutePoint_Spawn", "RoutePoint_Egg" })
		expect(points[2].neighbours).toEqual({ "RoutePoint_Bridge" })
		expect(points[1].target).toBeNil()
		expect(points[2].target).toBe("EggSpot_Common_1")
		expect(points[3].target).toBe("Spawn_1")
	end)

	it("finds the top centre of a part that is turned, not only of a flat one", function()
		local route = makeRoute({ { name = "RoutePoint_Lone", top = Vector3.zero } })
		local part = route:FindFirstChild("RoutePoint_Lone") :: Part
		-- turned 90 degrees round X, so the part's own up now points along world +Z
		part.CFrame = CFrame.new(5, 5, 5) * CFrame.Angles(math.rad(90), 0, 0)
		local points = RouteData.read(route)
		expect(points[1].position.X).toBeCloseTo(5, 5)
		expect(points[1].position.Y).toBeCloseTo(5, 5)
		expect(points[1].position.Z).toBeCloseTo(5 + 0.1, 5)
	end)

	it("treats a point with no Neighbours as having none, and ignores spaces around names", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", neighbours = "RoutePoint_B , RoutePoint_C" },
			{ name = "RoutePoint_B", neighbours = "RoutePoint_A" },
			{ name = "RoutePoint_C", neighbours = "RoutePoint_A" },
			{ name = "RoutePoint_Island" },
		})
		local points, problems = RouteData.read(route)
		expect(problems).toEqual({})
		expect(points[1].neighbours).toEqual({ "RoutePoint_B", "RoutePoint_C" })
		expect(points[4].name).toBe("RoutePoint_Island")
		expect(points[4].neighbours).toEqual({})
	end)

	it("reports a neighbour that does not exist", function()
		local entries = goodEntries()
		entries[3].neighbours = "RoutePoint_Spawn,RoutePoint_Egg,RoutePoint_Ghost"
		local route = makeRoute(entries)
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			"RoutePoint_Bridge lists RoutePoint_Ghost as a neighbour, but there is no such point",
		})
	end)

	it("reports a link that is listed on only one end, once", function()
		local entries = goodEntries()
		entries[1].neighbours = nil -- the egg no longer lists the bridge, but the bridge still lists the egg
		local route = makeRoute(entries)
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({ "RoutePoint_Bridge links to RoutePoint_Egg, but RoutePoint_Egg does not link back" })
	end)

	it("reports something in the route that is not a part", function()
		local entries = goodEntries()
		table.insert(entries, { name = "RoutePoint_Oops", className = "Model" })
		local route = makeRoute(entries)
		local points, problems = RouteData.read(route)
		expect(problems).toEqual({ "Route.RoutePoint_Oops must be a BasePart, not a Model" })
		expect(#points).toBe(3) -- the good points are still read
	end)

	it("reports two points that stand at the same target", function()
		local entries = goodEntries()
		entries[3].target = "EggSpot_Common_1" -- the bridge now claims the egg's target too
		local route = makeRoute(entries)
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			'RoutePoint_Bridge and RoutePoint_Egg have the same Target "EggSpot_Common_1"',
		})
	end)

	it("reports a Neighbours or Target attribute that is not text", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", neighbours = 5 },
			{ name = "RoutePoint_B", target = true },
		})
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			"RoutePoint_A has a Neighbours attribute that is not text",
			"RoutePoint_B has a Target attribute that is not text",
		})
	end)

	it("reports a point that lists itself, and two points with the same name", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", neighbours = "RoutePoint_A" },
			{ name = "RoutePoint_Twin" },
			{ name = "RoutePoint_Twin" },
		})
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			"Route has 2 children named RoutePoint_Twin",
			"RoutePoint_A lists itself as a neighbour",
		})
	end)

	it("reads the Ladder, WayUpFoot and WayUpTop attributes, and leaves them nil when absent", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", neighbours = "RoutePoint_B", ladder = "Boot", wayUpFoot = "Left boot ladder" },
			{ name = "RoutePoint_B", neighbours = "RoutePoint_A", ladder = "Boot", wayUpTop = "Left boot ladder" },
			{ name = "RoutePoint_C" },
		})
		local points, problems = RouteData.read(route)
		expect(problems).toEqual({})
		expect(points[1].ladder).toBe("Boot")
		expect(points[1].wayUpFoot).toBe("Left boot ladder")
		expect(points[1].wayUpTop).toBeNil()
		expect(points[2].ladder).toBe("Boot")
		expect(points[2].wayUpFoot).toBeNil()
		expect(points[2].wayUpTop).toBe("Left boot ladder")
		expect(points[3].ladder).toBeNil()
		expect(points[3].wayUpFoot).toBeNil()
		expect(points[3].wayUpTop).toBeNil()
	end)

	it("reports a Ladder, WayUpFoot or WayUpTop attribute that is not text", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", ladder = 5 },
			{ name = "RoutePoint_B", wayUpFoot = true },
			{ name = "RoutePoint_C", wayUpTop = 7 },
		})
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			"RoutePoint_A has a Ladder attribute that is not text",
			"RoutePoint_B has a WayUpFoot attribute that is not text",
			"RoutePoint_C has a WayUpTop attribute that is not text",
		})
	end)

	it("reports a ladder that is on only 1 point", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", ladder = "Boot" },
			{ name = "RoutePoint_B" },
		})
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			'Ladder "Boot" is on 1 point (RoutePoint_A), but must be on exactly 2',
		})
	end)

	it("reports a ladder that is on 3 points", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", ladder = "Boot" },
			{ name = "RoutePoint_B", ladder = "Boot" },
			{ name = "RoutePoint_C", ladder = "Boot" },
		})
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			'Ladder "Boot" is on 3 points (RoutePoint_A, RoutePoint_B, RoutePoint_C), but must be on exactly 2',
		})
	end)

	it("reports a ladder whose 2 points do not link to each other", function()
		local route = makeRoute({
			{ name = "RoutePoint_A", ladder = "Boot" },
			{ name = "RoutePoint_B", ladder = "Boot" },
		})
		local _, problems = RouteData.read(route)
		expect(problems).toEqual({
			'Ladder "Boot" points RoutePoint_A and RoutePoint_B do not link to each other',
		})
	end)
end)

describe("RouteData.isClimb", function()
	local function readPoints(): { RouteData.Point }
		local route = makeRoute({
			{ name = "RoutePoint_A", neighbours = "RoutePoint_B,RoutePoint_C", ladder = "Boot" },
			{ name = "RoutePoint_B", neighbours = "RoutePoint_A", ladder = "Boot" },
			{ name = "RoutePoint_C", neighbours = "RoutePoint_A,RoutePoint_D" },
			{ name = "RoutePoint_D", neighbours = "RoutePoint_C" },
		})
		local points = RouteData.read(route)
		return points
	end

	it("is true when both points are on the same ladder", function()
		local points = readPoints()
		expect(RouteData.isClimb(points[1], points[2])).toBe(true)
	end)

	it("is false for a point on a ladder and one off it, or two points off any ladder", function()
		local points = readPoints()
		expect(RouteData.isClimb(points[1], points[3])).toBe(false)
		expect(RouteData.isClimb(points[3], points[4])).toBe(false)
	end)
end)

describe("RouteData.bodyBoxSkip", function()
	local LEFT_PARTS = { "Giant.body_and_cushion", "WalkSurfaces.BellyRamp_Left.Piece16" }

	it("names the body mesh and ramp Piece16 for the left belly ramp top and Rare egg 1, in either order", function()
		expect(RouteData.bodyBoxSkip("RoutePoint_Egg_Rare_1", "RoutePoint_BellyRampLeft_3")).toEqual(LEFT_PARTS)
		expect(RouteData.bodyBoxSkip("BellyRampLeft_3", "Egg_Rare_1")).toEqual(LEFT_PARTS)
	end)

	it("names the same two parts for Rare egg 1 to Rare egg 2", function()
		expect(RouteData.bodyBoxSkip("RoutePoint_Egg_Rare_1", "RoutePoint_Egg_Rare_2")).toEqual(LEFT_PARTS)
	end)

	it("names only the body mesh for the right belly ramp top link", function()
		expect(RouteData.bodyBoxSkip("RoutePoint_BellyRampRight_4", "RoutePoint_BellyRampRight_3")).toEqual({
			"Giant.body_and_cushion",
		})
	end)

	it("names nothing for any other link", function()
		expect(RouteData.bodyBoxSkip("RoutePoint_BellyRampLeft_2", "RoutePoint_BellyRampLeft_3")).toEqual({})
	end)
end)

describe("RouteData.skipInstances", function()
	-- A fake World with Giant.body_and_cushion and WalkSurfaces.BellyRamp_Left.Piece16 (left empty on request).
	local function makeWorld(withPiece: boolean): Folder
		local world = Instance.new("Folder")
		local giant = Instance.new("Model")
		giant.Name = "Giant"
		giant.Parent = world
		local body = Instance.new("Part")
		body.Name = "body_and_cushion"
		body.Parent = giant
		local walk = Instance.new("Folder")
		walk.Name = "WalkSurfaces"
		walk.Parent = world
		local ramp = Instance.new("Model")
		ramp.Name = "BellyRamp_Left"
		ramp.Parent = walk
		if withPiece then
			local piece = Instance.new("Part")
			piece.Name = "Piece16"
			piece.Parent = ramp
		end
		table.insert(madeRoutes, world)
		return world
	end

	it("finds each named part under the world", function()
		local world = makeWorld(true)
		local found = RouteData.skipInstances(world, "Egg_Rare_1", "BellyRampLeft_3")
		expect(#found).toBe(2)
		expect(found[1]).toBe((world :: any).Giant.body_and_cushion)
		expect(found[2]).toBe((world :: any).WalkSurfaces.BellyRamp_Left.Piece16)
	end)

	it("errors when a named part is missing", function()
		local world = makeWorld(false)
		expect(function()
			RouteData.skipInstances(world, "Egg_Rare_1", "BellyRampLeft_3")
		end).toThrow("Piece16")
	end)

	it("gives an empty list for a link with no skip", function()
		expect(#RouteData.skipInstances(makeWorld(true), "BellyRampLeft_2", "BellyRampLeft_3")).toBe(0)
	end)
end)
