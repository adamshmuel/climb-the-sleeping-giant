--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- Builds a fake world that only has a Route (Task 23) with a few points, with no parent. The route is a Model that
-- always streams to players, like the real one.
type RouteOptions = {
	noRoute: boolean?,
	routeClass: string?, -- build the Route as this class instead of a Model
	streaming: Enum.ModelStreamingMode?, -- instead of Persistent
	brokenLink: boolean?, -- the second point lists a neighbour that does not exist
}

local function makeRouteWorld(options: RouteOptions?): Folder
	local opts: RouteOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	if opts.noRoute then
		return world
	end
	local route: Instance = Instance.new((opts.routeClass or "Model") :: any)
	route.Name = "Route"
	if route:IsA("Model") then
		route.ModelStreamingMode = opts.streaming or Enum.ModelStreamingMode.Persistent
	end
	route.Parent = world
	local entries: { { name: string, top: Vector3, neighbours: string, target: string } } = {
		{
			name = "RoutePoint_Spawn_1",
			top = Vector3.new(0, 2, 0),
			neighbours = "RoutePoint_Egg_Common_1",
			target = "Spawn_1",
		},
		{
			name = "RoutePoint_Egg_Common_1",
			top = Vector3.new(20, 2, 0),
			neighbours = if opts.brokenLink then "RoutePoint_Spawn_1,RoutePoint_Nowhere" else "RoutePoint_Spawn_1",
			target = "EggSpot_Common_1",
		},
	}
	for _, entry in entries do
		local point = Instance.new("Part")
		point.Name = entry.name
		point.Size = Vector3.new(1, 0.2, 1)
		point.CFrame = CFrame.new(entry.top - Vector3.new(0, 0.1, 0))
		point:SetAttribute("Neighbours", entry.neighbours)
		point:SetAttribute("Target", entry.target)
		point.Parent = route
	end
	return world
end

describe("WorldIndex.readRoute", function()
	it("reads the route points: names, top centres, neighbours and targets", function()
		local world = makeRouteWorld()
		local points, problems = WorldIndex.readRoute(world)
		expect(problems).toEqual({})
		expect(points).never.toBeNil()
		local list = points :: { WorldIndex.RoutePoint }
		expect(#list).toBe(2)
		expect(list[1].name).toBe("RoutePoint_Egg_Common_1")
		expect(list[1].position).toEqual(Vector3.new(20, 2, 0))
		expect(list[1].neighbours).toEqual({ "RoutePoint_Spawn_1" })
		expect(list[1].target).toBe("EggSpot_Common_1")
		world:Destroy()
	end)

	it("reports a missing Route", function()
		local world = makeRouteWorld({ noRoute = true })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({ "World is missing Route" })
		world:Destroy()
	end)

	it("reports a Route that is not a Model", function()
		local world = makeRouteWorld({ routeClass = "Folder" })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({ "World.Route must be a Model, not a Folder" })
		world:Destroy()
	end)

	it("reports a Route that does not always stream to players", function()
		local world = makeRouteWorld({ streaming = Enum.ModelStreamingMode.Default })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({ "World.Route must have ModelStreamingMode Persistent, not Default" })
		world:Destroy()
	end)

	it("reports the problems that RouteData finds in the points", function()
		local world = makeRouteWorld({ brokenLink = true })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({
			"RoutePoint_Egg_Common_1 lists RoutePoint_Nowhere as a neighbour, but there is no such point",
		})
		world:Destroy()
	end)
end)

describe("WorldIndex.loadRoute", function()
	it("returns the points of a good world, and errors with every problem of a bad one", function()
		local good = makeRouteWorld()
		expect(#WorldIndex.loadRoute(good)).toBe(2)
		good:Destroy()
		local bad = makeRouteWorld({ brokenLink = true, streaming = Enum.ModelStreamingMode.Atomic })
		local ok, message = pcall(WorldIndex.loadRoute, bad)
		expect(ok).toBe(false)
		expect(message).toBe(
			"World.Route must have ModelStreamingMode Persistent, not Atomic\n"
				.. "RoutePoint_Egg_Common_1 lists RoutePoint_Nowhere as a neighbour, but there is no such point"
		)
		bad:Destroy()
		local noRoute = makeRouteWorld({ noRoute = true })
		local okMissing, missingMessage = pcall(WorldIndex.loadRoute, noRoute)
		expect(okMissing).toBe(false)
		expect(missingMessage).toBe("World is missing Route")
		noRoute:Destroy()
	end)
end)

-- Builds a fake world that only has LandingSpots (Task 23): spots 1 to 8, with no parent.
type LandingOptions = {
	skip: { number }?, -- spot numbers to leave out
	wrongClass: { [number]: string }?, -- spot number -> class to build it as
	extra: { string }?, -- names of unexpected children to add
	noFolder: boolean?,
}

local function makeLandingWorld(options: LandingOptions?): Folder
	local opts: LandingOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	if opts.noFolder then
		return world
	end
	local folder = Instance.new("Folder")
	folder.Name = "LandingSpots"
	folder.Parent = world
	for number = 8, 1, -1 do -- built backwards on purpose: the reader must give them back in order
		if opts.skip and table.find(opts.skip, number) then
			continue
		end
		local className = if opts.wrongClass and opts.wrongClass[number] then opts.wrongClass[number] else "Part"
		local spot = Instance.new(className :: any)
		spot.Name = `LandingSpot_{number}`
		if spot:IsA("BasePart") then
			spot.Size = Vector3.new(1, 0.2, 1)
			spot.CFrame = CFrame.new(number * 12, 1.9, -70) -- its top centre is 0.1 higher
		end
		spot.Parent = folder
	end
	local extra: { string } = opts.extra or {}
	for _, name in extra do
		local stray = Instance.new("Part")
		stray.Name = name
		stray.Parent = folder
	end
	return world
end

describe("WorldIndex.readLandingSpots", function()
	it("reads the 8 landing spots in order, each with the top centre of its part", function()
		local world = makeLandingWorld()
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(problems).toEqual({})
		expect(spots).never.toBeNil()
		local list = spots :: { WorldIndex.LandingSpot }
		expect(#list).toBe(8)
		for number, spot in list do
			expect(spot.index).toBe(number)
			expect(spot.position).toEqual(Vector3.new(number * 12, 2, -70))
		end
		world:Destroy()
	end)

	it("reports the missing spot when there are only 7", function()
		local world = makeLandingWorld({ skip = { 5 } })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "LandingSpots is missing LandingSpot_5" })
		world:Destroy()
	end)

	it("reports a spot of the wrong class", function()
		local world = makeLandingWorld({ wrongClass = { [3] = "Folder" } })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "LandingSpots.LandingSpot_3 must be a BasePart, not a Folder" })
		world:Destroy()
	end)

	it("reports a missing LandingSpots folder", function()
		local world = makeLandingWorld({ noFolder = true })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "World is missing LandingSpots" })
		world:Destroy()
	end)

	it("reports a child that is not one of the 8 spots", function()
		local world = makeLandingWorld({ extra = { "LandingSpot_9", "Stray" } })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({
			"LandingSpots has an unexpected child LandingSpot_9",
			"LandingSpots has an unexpected child Stray",
		})
		world:Destroy()
	end)
end)

describe("WorldIndex.loadLandingSpots", function()
	it("returns the spots of a good world, and errors with every problem of a bad one", function()
		local good = makeLandingWorld()
		expect(#WorldIndex.loadLandingSpots(good)).toBe(8)
		good:Destroy()
		local bad = makeLandingWorld({ skip = { 2, 7 } })
		local ok, message = pcall(WorldIndex.loadLandingSpots, bad)
		expect(ok).toBe(false)
		expect(message).toBe("LandingSpots is missing LandingSpot_2\nLandingSpots is missing LandingSpot_7")
		bad:Destroy()
	end)
end)

-- Builds a fake world that only has Giant.SleepEyes (Task 27): a Model whose pivot is the point the eyes look from.
type FaceOptions = {
	noGiant: boolean?,
	noEyes: boolean?,
	eyesClass: string?,
}

local function makeFaceWorld(options: FaceOptions?): Folder
	local opts: FaceOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	if opts.noGiant then
		return world
	end
	local giant = Instance.new("Model")
	giant.Name = "Giant"
	giant.Parent = world
	if not opts.noEyes then
		local eyes = Instance.new((opts.eyesClass or "Model") :: any) :: Instance
		eyes.Name = "SleepEyes"
		if eyes:IsA("Model") then
			local part = Instance.new("Part")
			part.CFrame = CFrame.new(0.95, 95.3, 0.01)
			part.Parent = eyes
			eyes.PrimaryPart = part
			eyes:PivotTo(CFrame.new(0.95, 95.3, 0.01))
		end
		eyes.Parent = giant
	end
	return world
end

describe("WorldIndex.loadGiantFace", function()
	it("returns the pivot position of Giant.SleepEyes", function()
		local world = makeFaceWorld()
		local face = WorldIndex.loadGiantFace(world)
		expect(face.X).toBeCloseTo(0.95, 3)
		expect(face.Y).toBeCloseTo(95.3, 3)
		expect(face.Z).toBeCloseTo(0.01, 3)
		world:Destroy()
	end)

	it("stops the server with a clear message when the Giant is missing", function()
		local world = makeFaceWorld({ noGiant = true })
		local ok, message = pcall(WorldIndex.loadGiantFace, world)
		expect(ok).toBe(false)
		expect(message).toBe("World is missing Giant")
		world:Destroy()
	end)

	it("stops the server with a clear message when SleepEyes is missing", function()
		local world = makeFaceWorld({ noEyes = true })
		local ok, message = pcall(WorldIndex.loadGiantFace, world)
		expect(ok).toBe(false)
		expect(message).toBe("Giant is missing SleepEyes")
		world:Destroy()
	end)

	it("stops the server with a clear message when SleepEyes is not a Model", function()
		local world = makeFaceWorld({ eyesClass = "Folder" })
		local ok, message = pcall(WorldIndex.loadGiantFace, world)
		expect(ok).toBe(false)
		expect(message).toBe("Giant.SleepEyes must be a Model, not a Folder")
		world:Destroy()
	end)
end)
