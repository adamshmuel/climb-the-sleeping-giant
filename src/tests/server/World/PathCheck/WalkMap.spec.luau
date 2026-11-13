--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)

-- The walk map. Every test builds its own small world in a WorldModel in ServerStorage and destroys it afterwards.
-- The ground's top is at y = 0. The grid is Config.Stuck.ScanSpacing apart and starts at the area's lowest x and z.
describe("PathCheck walk map", function()
	local SPACING = Config.Stuck.ScanSpacing
	local WALK_SPEED = StarterPlayer.CharacterWalkSpeed
	local ALL_BUT_SLIDES = { Walk = true, Climb = true }
	local FLOOR_AREA: PathCheck.Area = { min = Vector3.new(-20, -12, -20), max = Vector3.new(20, 12, 20) }

	local world: WorldModel
	local options: PathCheck.Options

	local function addBox(name: string, min: Vector3, max: Vector3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = max - min
		part.CFrame = CFrame.new((min + max) / 2)
		part.Parent = world
		return part
	end

	-- Ground whose top is y = 0, from -20 to 20 in x and z.
	local function addFloor(): Part
		return addBox("Floor", Vector3.new(-20, -1, -20), Vector3.new(20, 0, 20))
	end

	-- A thin shelf floating with its top at y = 8, from x = -3 to 9 and z = -9 to 9.
	local function addShelf(): Part
		return addBox("Shelf", Vector3.new(-3, 7, -9), Vector3.new(9, 8, 9))
	end

	local function spotNear(map: PathCheck.WalkMap, position: Vector3): number
		local id = PathCheck.nearestSpot(map, position, SPACING / 2)
		assert(id ~= nil, `no spot near {position}`)
		return id
	end

	local function linksOfKind(map: PathCheck.WalkMap, id: number, kind: PathCheck.LinkKind): { PathCheck.Link }
		local found = {}
		local links: { PathCheck.Link } = map.links[id] or {}
		for _, link in links do
			if link.kind == kind then
				table.insert(found, link)
			end
		end
		return found
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "PathCheckTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		options = PathCheck.defaults(world)
		world.Parent = ServerStorage
	end)

	afterEach(function()
		-- The world goes first, so a failing cleanup can never leave it behind (the probe lives inside it).
		local made = world :: WorldModel? -- nil if the first beforeEach failed before it made the world
		if made ~= nil then
			made:Destroy()
		end
		pcall(PathCheck.cleanup, options)
	end)

	it("a flat floor next to an exit has no stuck spots", function()
		addFloor()
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 100).toBe(true)
		local exit = spotNear(map, Vector3.new(-18, 0, -18))
		expect(PathCheck.stuckSpots(map, { exit })).toEqual({})
	end)

	it("a pit with walls steeper than 70 degrees: every spot in the pit is stuck, and none outside it", function()
		-- ground 10 studs thick with a hole x and z from -7.5 to 7.5 (vertical walls), and a pit floor at y = -10
		addBox("GroundNorth", Vector3.new(-20, -10, 7.5), Vector3.new(20, 0, 20))
		addBox("GroundSouth", Vector3.new(-20, -10, -20), Vector3.new(20, 0, -7.5))
		addBox("GroundWest", Vector3.new(-20, -10, -7.5), Vector3.new(-7.5, 0, 7.5))
		addBox("GroundEast", Vector3.new(7.5, -10, -7.5), Vector3.new(20, 0, 7.5))
		addBox("PitFloor", Vector3.new(-7.5, -11, -7.5), Vector3.new(7.5, -10, 7.5))
		local map = PathCheck.buildMap(options, FLOOR_AREA)

		local inPit: { [number]: boolean } = {}
		for _, spot in map.spots do
			if spot.position.Y < -5 then
				inPit[spot.id] = true
			end
		end
		local exit = spotNear(map, Vector3.new(-18, 0, -18))
		local stuck: { [number]: boolean } = {}
		for _, spot in PathCheck.stuckSpots(map, { exit }) do
			stuck[spot.id] = true
		end
		expect((next(inPit))).never.toBeNil()
		expect(stuck).toEqual(inPit)
	end)

	it(
		"a shelf above the floor: its spots slide down, so none is stuck, but no walk or ladder goes up or down",
		function()
			addFloor()
			addShelf()
			local map = PathCheck.buildMap(options, FLOOR_AREA)
			local floorSpot = spotNear(map, Vector3.new(-14, 0, 0))
			local shelfSpot = spotNear(map, Vector3.new(0, 8, 0))

			expect(PathCheck.stuckSpots(map, { floorSpot })).toEqual({})
			expect(PathCheck.route(map, floorSpot, { shelfSpot }, { allow = { Walk = true } })).toBeNil()
			expect(PathCheck.route(map, floorSpot, { shelfSpot })).toBeNil() -- slides only go down
			expect(PathCheck.route(map, shelfSpot, { floorSpot }, { allow = ALL_BUT_SLIDES })).toBeNil()
			local down = PathCheck.route(map, shelfSpot, { floorSpot })
			expect(down).never.toBeNil()
			local kinds: { [string]: boolean } = {}
			for _, step in (down :: PathCheck.Route).steps do
				kinds[step.kind] = true
			end
			expect(kinds.Slide).toBe(true)
		end
	)

	it("a wall between a shelf's edge and the lower floor: no slide through the wall", function()
		addFloor()
		addShelf()
		local controlMap = PathCheck.buildMap(options, FLOOR_AREA)
		local edge = Vector3.new(8, 8, 0) -- the last shelf spot before the edge at x = 9
		expect(#linksOfKind(controlMap, spotNear(controlMap, edge), "Slide") > 0).toBe(true) -- the control

		-- a wall that hangs over the edge, high enough above the floor that a floor spot beneath it still exists:
		-- only the check for room beside the edge can stop the slide
		addBox("Wall", Vector3.new(9.5, 8.5, -20), Vector3.new(11.5, 20, 20))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(linksOfKind(map, spotNear(map, edge), "Slide")).toEqual({})
	end)

	it("a ladder from the floor to the shelf: a route up works with climb links, at 70% of walking speed", function()
		addFloor()
		addShelf()
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Anchored = true
		truss.Size = Vector3.new(2, 8, 2)
		truss.CFrame = CFrame.new(9.5, 4, 0.5)
		truss.Parent = world
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local floorSpot = spotNear(map, Vector3.new(12, 0, 0))
		local shelfSpot = spotNear(map, Vector3.new(0, 8, 0))

		expect(PathCheck.route(map, floorSpot, { shelfSpot }, { allow = { Walk = true } })).toBeNil()
		local route = PathCheck.route(map, floorSpot, { shelfSpot }, { allow = ALL_BUT_SLIDES })
		expect(route).never.toBeNil()
		local climbs = {}
		for _, step in (route :: PathCheck.Route).steps do
			if step.kind == "Climb" then
				table.insert(climbs, step)
			end
		end
		expect(#climbs).toBe(1)
		expect(climbs[1].length > 7).toBe(true)
		expect(climbs[1].seconds).toBeCloseTo(climbs[1].length / (Config.Movement.ClimbSpeedFactor * WALK_SPEED), 5)
	end)

	-- A ladder like the real ones: a 2 x 2 truss leaning about 54 degrees from the floor up to the shelf's edge, its
	-- foot end 15 studs along x. Its foot end is more than 3 but less than 4 studs from the nearest floor spot (the
	-- truss itself and a body's half width keep the spots away), as the real ladders' ends are.
	local LEAN = math.rad(54)
	local LADDER_RISE = 8
	local LADDER_FOOT = Vector3.new(15, 0, 1)

	local function addLeaningLadder(): TrussPart
		local top = LADDER_FOOT + Vector3.new(-LADDER_RISE / math.tan(LEAN), LADDER_RISE, 0)
		local along = (top - LADDER_FOOT).Unit -- up the ladder
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Anchored = true
		truss.Size = Vector3.new(2, LADDER_RISE / math.sin(LEAN), 2)
		truss.CFrame = CFrame.fromMatrix((top + LADDER_FOOT) / 2, Vector3.new(0, 0, -1):Cross(along), along)
		truss.Parent = world
		return truss
	end

	it("a leaning ladder whose foot is more than 3 studs from the nearest floor spot: a route up works", function()
		addFloor()
		addShelf()
		addLeaningLadder()
		local map = PathCheck.buildMap(options, FLOOR_AREA)

		-- the setup means something: the nearest floor spot is more than 3 but less than 4 studs from the foot
		local nearestFloor = math.huge
		for _, spot in map.spots do
			if spot.standsOn.Name == "Floor" then
				nearestFloor = math.min(nearestFloor, (spot.position - LADDER_FOOT).Magnitude)
			end
		end
		expect(nearestFloor > 3).toBe(true)
		expect(nearestFloor < 4).toBe(true)

		local floorSpot = spotNear(map, Vector3.new(-14, 0, 0))
		local shelfSpot = spotNear(map, Vector3.new(0, 8, 0))
		expect(PathCheck.route(map, floorSpot, { shelfSpot }, { allow = { Walk = true } })).toBeNil()
		local route = PathCheck.route(map, floorSpot, { shelfSpot }, { allow = ALL_BUT_SLIDES })
		expect(route).never.toBeNil()
		local climbs = {}
		for _, step in (route :: PathCheck.Route).steps do
			if step.kind == "Climb" then
				table.insert(climbs, step)
			end
		end
		expect(#climbs).toBe(1)
		-- the climb joins a floor spot to a shelf spot, not a spot on the ladder itself
		expect(map.spots[climbs[1].from].standsOn.Name).toBe("Floor")
		expect(map.spots[climbs[1].to].standsOn.Name).toBe("Shelf")
	end)

	it("no spot stands on a ladder, however gently it leans", function()
		addFloor()
		addShelf()
		local truss = addLeaningLadder()
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local onLadder = 0
		for _, spot in map.spots do
			if spot.standsOn == truss then
				onLadder += 1
			end
		end
		expect(#map.spots > 100).toBe(true)
		expect(onLadder).toBe(0)
	end)

	it("a slide follows a surface too steep to stand on downhill and reaches the floor beyond its bottom", function()
		addFloor()
		addShelf()
		-- a 77 degree face from the shelf's edge (x = 9, y = 8) down to the floor, about 1.8 studs further along x
		local steep = math.rad(77)
		local down = Vector3.new(math.cos(steep), -math.sin(steep), 0)
		local normal = Vector3.new(math.sin(steep), math.cos(steep), 0)
		local faceLength = 8 / math.sin(steep)
		local face = Instance.new("Part")
		face.Name = "SteepFace"
		face.Anchored = true
		face.Size = Vector3.new(faceLength, 0.5, 16)
		face.CFrame = CFrame.fromMatrix(Vector3.new(9, 8, 0) + down * (faceLength / 2) - normal * 0.25, down, normal)
		face.Parent = world
		local bottomX = 9 + 8 / math.tan(steep)

		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local edge = spotNear(map, Vector3.new(8, 8, 0))
		local slidTo = {}
		for _, link in linksOfKind(map, edge, "Slide") do
			table.insert(slidTo, map.spots[link.to])
		end
		expect(#slidTo > 0).toBe(true)
		for _, landing in slidTo do
			expect(landing.standsOn.Name).toBe("Floor")
			expect(landing.position.X > bottomX).toBe(true)
		end
	end)

	it("a floor under an overhang has spots both on the overhang and under it", function()
		addFloor()
		addBox("Overhang", Vector3.new(-6, 7, -6), Vector3.new(6, 8, 6))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local under = PathCheck.nearestSpot(map, Vector3.new(0, 0, 0), 0.5)
		local on = PathCheck.nearestSpot(map, Vector3.new(0, 8, 0), 0.5)
		expect(under).never.toBeNil()
		expect(on).never.toBeNil()
		expect(under).never.toBe(on)
		expect(map.spots[under :: number].standsOn.Name).toBe("Floor")
		expect(map.spots[on :: number].standsOn.Name).toBe("Overhang")
	end)

	it("a floor under a piece the column's ray starts inside is still a spot", function()
		addFloor()
		-- One solid piece shaped like a C: a top block, a side wall and a low seat, with clear room over the seat. A ray
		-- that starts inside a piece skips the whole piece, so the ray that follows the top block's surface down the
		-- column at the middle never sees the seat.
		local top = addBox("Top", Vector3.new(-5, 28, -5), Vector3.new(5, 30, 5))
		local wall = addBox("Wall", Vector3.new(4, 4, -5), Vector3.new(6, 30, 5))
		local seat = addBox("Seat", Vector3.new(-5, 4, -5), Vector3.new(5, 6, 5))
		local made, pieces = pcall(function()
			return GeometryService:UnionAsync(top, { wall, seat }, {
				CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
			})
		end)
		assert(made, `the union could not be made: {pieces}`)
		expect(#pieces).toBe(1)
		top:Destroy()
		wall:Destroy()
		seat:Destroy()
		local hook = pieces[1]
		hook.Name = "Hook"
		hook.Anchored = true
		hook.Parent = world
		local map = PathCheck.buildMap(options, { min = Vector3.new(-20, -12, -20), max = Vector3.new(20, 40, 20) })
		local onSeat = PathCheck.nearestSpot(map, Vector3.new(0, 6, 0), 0.5)
		expect(onSeat).never.toBeNil()
		expect(map.spots[onSeat :: number].standsOn.Name).toBe("Hook")
	end)

	it("there is no spot where a body doesn't fit, under a ceiling lower than a body", function()
		addFloor()
		addBox("LowCeiling", Vector3.new(0, 3, -20), Vector3.new(20, 4, 20))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(PathCheck.nearestSpot(map, Vector3.new(10, 0, 0), 1)).toBeNil()
		expect(PathCheck.nearestSpot(map, Vector3.new(10, 4, 0), 1)).never.toBeNil() -- on top of it
		expect(PathCheck.nearestSpot(map, Vector3.new(-10, 0, 0), 1)).never.toBeNil() -- in the open
	end)

	it("there is no spot on water", function()
		addFloor()
		local pond = addBox("Pond", Vector3.new(0, -1, -20), Vector3.new(20, 0, 20))
		pond.Material = Enum.Material.Water
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(PathCheck.nearestSpot(map, Vector3.new(10, 0, 0), 1)).toBeNil()
		expect(PathCheck.nearestSpot(map, Vector3.new(-10, 0, 0), 1)).never.toBeNil()
	end)

	it("no spot under a left-out plank lower than a body", function()
		addFloor()
		-- a plank 2.9 studs above the floor: a body (4.3 tall) does not fit under it
		local plank = addBox("Plank", Vector3.new(-6, 2.9, -6), Vector3.new(6, 3.9, 6))
		options.boxIgnores = { plank :: Instance }
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(PathCheck.nearestSpot(map, Vector3.new(0, 0, 0), 1)).toBeNil() -- under the plank
		expect(PathCheck.nearestSpot(map, Vector3.new(0, 3.9, 0), 1)).never.toBeNil() -- on top of it
		expect(PathCheck.nearestSpot(map, Vector3.new(-14, 0, 0), 1)).never.toBeNil() -- in the open
	end)

	it("a spot where a body fits only turned still walks away", function()
		addFloor()
		-- A wall whose face is turned 30 degrees (around straight up), its face 1.1 times the half width from the
		-- spot at the middle of the floor: only a box turned to match it clears the wall.
		local half = Config.Stuck.BodyWidth / 2
		local toWall = Vector3.new(math.cos(math.rad(30)), 0, math.sin(math.rad(30)))
		local center = toWall * (half * 1.1 + 0.5) + Vector3.new(0, 10, 0)
		local wall = addBox("TurnedWall", Vector3.new(-0.5, -10, -20), Vector3.new(0.5, 10, 20))
		wall.CFrame = CFrame.fromMatrix(center, toWall, Vector3.new(0, 1, 0))
		local feet = Vector3.new(0, 0, 0)
		expect((PathCheck.bodyFits(options, feet, nil, nil))).toBe(false) -- unturned: touches the wall
		expect((PathCheck.bodyFits(options, feet, nil, Vector3.new(1, 0, 1)))).toBe(false) -- turned 45: touches
		expect((PathCheck.roomToStand(options, feet, nil))).toBe(true) -- turned the right way: fits

		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local here = spotNear(map, feet)
		local away = spotNear(map, Vector3.new(-2, 0, 0)) -- the far side from the wall
		local walksAway = false
		for _, link in linksOfKind(map, here, "Walk") do
			if link.to == away then
				walksAway = true
			end
		end
		expect(walksAway).toBe(true)
	end)

	it("no spot on the ground right under water", function()
		addFloor()
		-- water 7 to 9 studs up over half the floor: a body fits between the floor and the water
		local pond = addBox("Pond", Vector3.new(0, 7, -20), Vector3.new(20, 9, 20))
		pond.Material = Enum.Material.Water
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(PathCheck.nearestSpot(map, Vector3.new(10, 0, 0), 1)).toBeNil() -- under the water
		expect(PathCheck.nearestSpot(map, Vector3.new(-10, 0, 0), 1)).never.toBeNil() -- beside it
	end)

	it("something between two spots still blocks the link", function()
		addFloor()
		-- a thin post between two diagonal spots, off the grid so it is no spot's neighbour on its own
		addBox("Post", Vector3.new(0.95, 0, 0.95), Vector3.new(1.05, 6, 1.05))
		local from = Vector3.new(0, 0, 0)
		local to = Vector3.new(2, 0, 2)
		-- the setup proves itself: a body standing at either end, turned the best way, clears the post...
		expect((PathCheck.roomToStand(options, from, nil))).toBe(true)
		expect((PathCheck.roomToStand(options, to, nil))).toBe(true)
		-- ...but a body between them, facing the way it walks, does not
		expect((PathCheck.bodyFits(options, Vector3.new(1, 0, 1), nil, to - from))).toBe(false)

		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local fromId = spotNear(map, from)
		local toId = spotNear(map, to)
		for _, link in linksOfKind(map, fromId, "Walk") do
			expect(link.to).never.toBe(toId)
		end
	end)

	it("there is no spot on a surface steeper than the slope limit", function()
		addFloor()
		local tilt = CFrame.Angles(0, 0, math.rad(80))
		local ramp = Instance.new("Part")
		ramp.Name = "SteepRamp"
		ramp.Anchored = true
		ramp.Size = Vector3.new(30, 1, 20)
		ramp.CFrame = CFrame.new(0, 14, 0) * tilt
		ramp.Parent = world
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local onRamp = 0
		for _, spot in map.spots do
			if spot.standsOn == ramp then
				onRamp += 1
			end
		end
		expect(onRamp).toBe(0)
		expect(#map.spots > 100).toBe(true)
	end)

	it("route returns its steps, picks the quicker way, and follows a cost rule", function()
		-- 1 to 4 by two ways: 1-2-4 (two walks of 10 s) or 1-3-4 (a walk of 5 s, then a climb of 5 s)
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
		local map = {
			spacing = SPACING,
			spots = { spot(1), spot(2), spot(3), spot(4) },
			links = {
				[1] = { link(2, "Walk", 10, 10), link(3, "Walk", 5, 5) },
				[2] = { link(4, "Walk", 10, 10) },
				[3] = { link(4, "Climb", 5, 5) },
				[4] = {},
			},
			columns = {},
			origin = Vector3.zero,
			countX = 0,
			countZ = 0,
		} :: any

		local quick = PathCheck.route(map, 1, { 4 })
		expect(quick).never.toBeNil()
		expect((quick :: PathCheck.Route).cost).toBeCloseTo(10, 5)
		expect((quick :: PathCheck.Route).steps).toEqual({
			{ from = 1, to = 3, kind = "Walk", length = 5, seconds = 5 },
			{ from = 3, to = 4, kind = "Climb", length = 5, seconds = 5 },
		})

		local dearClimb = PathCheck.route(map, 1, { 4 }, {
			cost = function(each: PathCheck.Link): number
				return if each.kind == "Climb" then 100 else each.seconds
			end,
		})
		expect((dearClimb :: PathCheck.Route).steps[1].to).toBe(2)
		expect((dearClimb :: PathCheck.Route).cost).toBeCloseTo(20, 5)

		local walkOnly = PathCheck.route(map, 1, { 4 }, { allow = { Walk = true } })
		expect((walkOnly :: PathCheck.Route).steps[1].to).toBe(2)

		local alreadyThere = PathCheck.route(map, 4, { 4, 2 })
		expect((alreadyThere :: PathCheck.Route).steps).toEqual({})
		expect((alreadyThere :: PathCheck.Route).cost).toBe(0)

		expect(PathCheck.route(map, 4, { 1 })).toBeNil() -- the links only go one way
	end)

	it("nearestSpot gives the nearest spot within the distance, and nil when none is that close", function()
		addFloor()
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local near = PathCheck.nearestSpot(map, Vector3.new(0.3, 0, 0.2), 1)
		expect(map.spots[near :: number].position).toEqual(Vector3.new(0, 0, 0))
		local between = PathCheck.nearestSpot(map, Vector3.new(1.4, 0, 0), 3)
		expect(map.spots[between :: number].position).toEqual(Vector3.new(2, 0, 0))
		expect(PathCheck.nearestSpot(map, Vector3.new(0, 30, 0), 3)).toBeNil()
		expect(PathCheck.nearestSpot(map, Vector3.new(0, 1, 0), 0.5)).toBeNil()
		expect(PathCheck.nearestSpot(map, Vector3.new(0, 1, 0), 1.2)).never.toBeNil()
	end)

	it("the grid reaches the far sides of an area that isn't a whole number of steps wide", function()
		-- 41 studs wide in x and z: 20 whole steps and 1 stud more. A floor reaches well past it on every side.
		addBox("BigFloor", Vector3.new(-30, -1, -30), Vector3.new(30, 0, 30))
		local area: PathCheck.Area = { min = Vector3.new(-20, -12, -20), max = Vector3.new(21, 12, 21) }
		local map = PathCheck.buildMap(options, area)
		local farthestX, farthestZ = -math.huge, -math.huge
		for _, spot in map.spots do
			farthestX = math.max(farthestX, spot.position.X)
			farthestZ = math.max(farthestZ, spot.position.Z)
		end
		expect(farthestX).toBeGreaterThanOrEqual(area.max.X)
		expect(farthestZ).toBeGreaterThanOrEqual(area.max.Z)
	end)

	-- The outermost columns of the floor area: |x| = 20 or |z| = 20 (the area is a whole number of steps wide).
	local function onAreaEdge(position: Vector3): boolean
		return math.abs(position.X) > 19.9 or math.abs(position.Z) > 19.9
	end

	it("edgeSpots lists the ground spots of the outermost columns and no others", function()
		local floor = addFloor()
		-- a box standing on the west edge column: a spot on top of it is in an outermost column but not on the ground
		local box = addBox("Box", Vector3.new(-21, 0, -1), Vector3.new(-19, 3, 1))
		local map = PathCheck.buildMap(options, FLOOR_AREA)

		local expected: { [number]: boolean } = {}
		local boxTopSpot: number? = nil
		for _, spot in map.spots do
			if spot.standsOn == floor and onAreaEdge(spot.position) then
				expected[spot.id] = true
			elseif spot.standsOn == box then
				boxTopSpot = spot.id
			end
		end
		expect(boxTopSpot).never.toBeNil() -- the box's top is a spot, so leaving it out means something
		expect(#PathCheck.edgeSpots(map, {}) == 0).toBe(true) -- no ground, no edge spots

		local found: { [number]: boolean } = {}
		local count = 0
		for _, id in PathCheck.edgeSpots(map, { floor }) do
			found[id] = true
			count += 1
		end
		expect(count > 60).toBe(true) -- most of the 80 spots round the floor's rim
		expect(found).toEqual(expected)
		expect(found[boxTopSpot :: number]).toBeNil()
	end)

	it("a floor with no exit but its edge spots has no stuck spots", function()
		local floor = addFloor()
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local exits = PathCheck.edgeSpots(map, { floor })
		expect(#exits > 0).toBe(true)
		expect(PathCheck.stuckSpots(map, exits)).toEqual({})
	end)

	it("a closed pit on the edge whose floor isn't the ground is still stuck", function()
		-- ground 10 studs thick with a closed pit against the west edge (x from -21.5 to -12, z from -4 to 4). Its walls
		-- are vertical, and the west wall stands 1.5 studs beyond the edge column, so a body fits at the edge.
		local ground: { Instance } = {
			addBox("GroundNorth", Vector3.new(-30, -10, 4), Vector3.new(30, 0, 30)),
			addBox("GroundSouth", Vector3.new(-30, -10, -30), Vector3.new(30, 0, -4)),
			addBox("GroundWest", Vector3.new(-30, -10, -4), Vector3.new(-21.5, 0, 4)),
			addBox("GroundEast", Vector3.new(-12, -10, -4), Vector3.new(30, 0, 4)),
		}
		addBox("PitFloor", Vector3.new(-21.5, -11, -4), Vector3.new(-12, -10, 4)) -- not on the ground list
		local map = PathCheck.buildMap(options, FLOOR_AREA)

		local inPit: { [number]: boolean } = {}
		local pitSpotOnEdge = false
		for _, spot in map.spots do
			if spot.position.Y < -5 then
				inPit[spot.id] = true
				pitSpotOnEdge = pitSpotOnEdge or onAreaEdge(spot.position)
			end
		end
		expect(pitSpotOnEdge).toBe(true) -- the pit really reaches the outermost column
		local stuck: { [number]: boolean } = {}
		for _, spot in PathCheck.stuckSpots(map, PathCheck.edgeSpots(map, ground)) do
			stuck[spot.id] = true
		end
		expect(stuck).toEqual(inPit)
	end)
end)
