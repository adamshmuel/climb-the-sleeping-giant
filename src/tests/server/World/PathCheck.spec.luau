--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach, beforeAll, afterAll =
	JestGlobals.describe,
	JestGlobals.it,
	JestGlobals.expect,
	JestGlobals.beforeEach,
	JestGlobals.afterEach,
	JestGlobals.beforeAll,
	JestGlobals.afterAll

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)

-- Every test builds a few parts in a WorldModel in ServerStorage (it answers rays and overlap checks like the
-- Workspace) and destroys it afterwards. The real place is never touched.
describe("PathCheck.linkProblem", function()
	local function contains(text: string, part: string): boolean
		return string.find(text, part, 1, true) ~= nil
	end

	local function startsWith(text: string, part: string): boolean
		return string.sub(text, 1, #part) == part
	end

	local world: WorldModel
	local options: PathCheck.Options

	local function addPart(name: string, size: Vector3, cframe: CFrame): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.CFrame = cframe
		part.Parent = world
		return part
	end

	-- A floor whose top surface is at y = 0, from x = minX to x = maxX and 20 studs wide.
	local function addFloor(name: string, minX: number, maxX: number): Part
		return addPart(name, Vector3.new(maxX - minX, 1, 20), CFrame.new((minX + maxX) / 2, -0.5, 0))
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "PathCheckTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		options = { world = world }
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

	it("a flat floor is walkable", function()
		addFloor("Floor", -30, 30)
		expect(PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))).toBeNil()
	end)

	it("a gap in the floor says there is no ground, and where", function()
		addFloor("FloorLeft", -30, -3)
		addFloor("FloorRight", 3, 30)
		expect(PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))).toBe(
			"no ground at (-2.0, 0.0, 0.0)"
		)
	end)

	it("water says water, and where", function()
		addFloor("FloorLeft", -30, -3)
		addFloor("FloorRight", 3, 30)
		local pond = addPart("Pond", Vector3.new(6, 1, 20), CFrame.new(0, -0.5, 0))
		pond.Material = Enum.Material.Water
		expect(PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))).toBe(
			"water at (-2.0, 0.0, 0.0)"
		)
	end)

	it("a 75 degree slope says too steep, and where", function()
		local tilt = CFrame.Angles(0, 0, math.rad(75))
		local ramp = addPart("Ramp", Vector3.new(40, 1, 20), CFrame.new(0, 10, 0) * tilt)
		-- the line runs along the top of the ramp
		local up = tilt.RightVector
		local topNormal = tilt.UpVector
		local from = ramp.Position + up * -8 + topNormal * 0.5
		local to = ramp.Position + up * 8 + topNormal * 0.5
		local problem = PathCheck.linkProblem(options, from, to)
		expect(problem).never.toBeNil()
		expect(startsWith(problem :: string, "too steep at (")).toBe(true)
		expect(contains(problem :: string, "Ramp")).toBe(true)
	end)

	it("a 65 degree slope is walkable", function()
		local tilt = CFrame.Angles(0, 0, math.rad(65))
		local ramp = addPart("Ramp", Vector3.new(40, 1, 20), CFrame.new(0, 10, 0) * tilt)
		local up = tilt.RightVector
		local topNormal = tilt.UpVector
		local from = ramp.Position + up * -8 + topNormal * 0.5
		local to = ramp.Position + up * 8 + topNormal * 0.5
		expect(PathCheck.linkProblem(options, from, to)).toBeNil()
	end)

	it("a wall across the way says what is in the way, and where", function()
		addFloor("Floor", -30, 30)
		addPart("Wall", Vector3.new(1, 10, 20), CFrame.new(0, 5, 0))
		local problem = PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))
		expect(problem).never.toBeNil()
		expect(contains(problem :: string, "Wall is in the way at (")).toBe(true)
	end)

	it("a part on the box ignore list is not in the way", function()
		addFloor("Floor", -30, 30)
		local wall = addPart("Wall", Vector3.new(1, 10, 20), CFrame.new(0, 5, 0))
		options.boxIgnores = { wall :: Instance }
		expect(PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))).toBeNil()
	end)

	it("a new box ignore list set after a check is used by the next check", function()
		addFloor("Floor", -30, 30)
		local wall = addPart("Wall", Vector3.new(1, 10, 20), CFrame.new(0, 5, 0))
		expect(PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))).never.toBeNil()
		options.boxIgnores = { wall :: Instance }
		expect(PathCheck.linkProblem(options, Vector3.new(-20, 0, 0), Vector3.new(20, 0, 0))).toBeNil()
	end)

	it("a line 2 studs under the ground says how far off the line the ground is", function()
		addFloor("Floor", -30, 30)
		local problem = PathCheck.linkProblem(options, Vector3.new(-20, -2, 0), Vector3.new(20, -2, 0))
		expect(problem).never.toBeNil()
		expect(contains(problem :: string, "studs off the line at (-20.0, -2.0, 0.0)")).toBe(true)
	end)
end)

-- bodyFits: does a player's body fit standing on a spot? The sizes come from Config.Stuck, so a new measurement
-- doesn't break these tests. The box rides 0.5 studs above the feet (BODY_LIFT in PathCheck), so a floor or a
-- doorstep under 0.5 studs high is stepped over.
describe("PathCheck.bodyFits", function()
	local WIDTH = Config.Stuck.BodyWidth
	local HEIGHT = Config.Stuck.BodyHeight
	local LIFT = 0.5
	local MARGIN = 0.2 -- every "just fits" and "just touches" case is this far from the edge

	local world: WorldModel
	local options: PathCheck.Options
	local feet = Vector3.new(0, 0, 0)

	local function addPart(name: string, size: Vector3, cframe: CFrame): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.CFrame = cframe
		part.Parent = world
		return part
	end

	-- A floor whose top surface is at y = 0, under the spot.
	local function addFloor(): Part
		return addPart("Floor", Vector3.new(60, 1, 60), CFrame.new(0, -0.5, 0))
	end

	-- A wall 1 stud thick, 20 tall and 40 long, standing on the floor, whose face nearest the spot is at x = faceX
	-- (the wall is on the right of the spot when faceX is positive).
	local function addWallAt(name: string, faceX: number): Part
		local sign = if faceX >= 0 then 1 else -1
		return addPart(name, Vector3.new(1, 20, 40), CFrame.new(faceX + sign * 0.5, 10, 0))
	end

	local function countProbes(): number
		local count = 0
		for _, descendant in world:GetDescendants() do
			if descendant.Name == "PathCheckProbe" then
				count += 1
			end
		end
		return count
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "PathCheckTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		options = { world = world }
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

	it("a body fits on an open floor", function()
		addFloor()
		local fits, inTheWay = PathCheck.bodyFits(options, feet)
		expect(fits).toBe(true)
		expect(inTheWay).toBeNil()
	end)

	it("a body doesn't fit under a ceiling lower than its height, and the ceiling is named", function()
		addFloor()
		local ceiling = addPart("LowCeiling", Vector3.new(30, 1, 30), CFrame.new(0, HEIGHT - MARGIN + 0.5, 0))
		local fits, inTheWay = PathCheck.bodyFits(options, feet)
		expect(fits).toBe(false)
		expect(inTheWay).toBe(ceiling)
	end)

	it("a body fits under a ceiling a little higher than its height", function()
		addFloor()
		addPart("HighCeiling", Vector3.new(30, 1, 30), CFrame.new(0, HEIGHT + MARGIN + 0.5, 0))
		expect((PathCheck.bodyFits(options, feet))).toBe(true)
	end)

	it("a body doesn't fit beside a wall that cuts into its box, and the wall is named", function()
		addFloor()
		local wall = addWallAt("NearWall", WIDTH / 2 - MARGIN)
		local fits, inTheWay = PathCheck.bodyFits(options, feet)
		expect(fits).toBe(false)
		expect(inTheWay).toBe(wall)
	end)

	it("a body fits beside a wall that is just clear of its box", function()
		addFloor()
		addWallAt("ClearWall", WIDTH / 2 + MARGIN)
		expect((PathCheck.bodyFits(options, feet))).toBe(true)
	end)

	it("a body fits in a gap between two walls a little wider than its box", function()
		addFloor()
		addWallAt("WallRight", WIDTH / 2 + MARGIN)
		addWallAt("WallLeft", -(WIDTH / 2 + MARGIN))
		expect((PathCheck.bodyFits(options, feet))).toBe(true)
	end)

	it("a body doesn't fit in a gap between two walls a little narrower than its box", function()
		addFloor()
		addWallAt("WallRight", WIDTH / 2 - MARGIN)
		addWallAt("WallLeft", -(WIDTH / 2 - MARGIN))
		expect((PathCheck.bodyFits(options, feet))).toBe(false)
	end)

	it("a body doesn't fit in a closed room smaller than itself", function()
		-- inside: 3/4 of the body in every direction, floor top at y = 0
		local inside = Vector3.new(WIDTH * 0.75, HEIGHT * 0.75, WIDTH * 0.75)
		local half = inside / 2
		addPart("RoomFloor", Vector3.new(inside.X + 2, 1, inside.Z + 2), CFrame.new(0, -0.5, 0))
		addPart("RoomRoof", Vector3.new(inside.X + 2, 1, inside.Z + 2), CFrame.new(0, inside.Y + 0.5, 0))
		addPart("RoomWallEast", Vector3.new(1, inside.Y, inside.Z), CFrame.new(half.X + 0.5, half.Y, 0))
		addPart("RoomWallWest", Vector3.new(1, inside.Y, inside.Z), CFrame.new(-half.X - 0.5, half.Y, 0))
		addPart("RoomWallNorth", Vector3.new(inside.X + 2, inside.Y, 1), CFrame.new(0, half.Y, half.Z + 0.5))
		addPart("RoomWallSouth", Vector3.new(inside.X + 2, inside.Y, 1), CFrame.new(0, half.Y, -half.Z - 0.5))
		expect((PathCheck.bodyFits(options, feet))).toBe(false)
	end)

	-- A wedge 10 studs wide and 10 deep, standing on the floor, thin at its front (z = -5) and rising to the back
	-- (z = +5). Its sloped side rises 0.3 studs over the body's width. Its outer box, 3 / WIDTH studs tall, covers
	-- the spot, so only an exact-shape check can see that the body is clear of it.
	local function addWedge(): WedgePart
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Wedge"
		wedge.Anchored = true
		wedge.Size = Vector3.new(10, 3 / WIDTH, 10)
		wedge.CFrame = CFrame.new(0, 1.5 / WIDTH, 0)
		wedge.Parent = world
		return wedge
	end

	it("a body fits where it is clear of a wedge's sloped side, though the wedge's outer box covers it", function()
		addFloor()
		addWedge()
		local nearTheThinEdge = Vector3.new(0, 0, -5 + WIDTH / 2)
		-- the same body box, checked by outer boxes only, does find the wedge: this is what the exact shape fixes
		local boxCenter = nearTheThinEdge + Vector3.new(0, LIFT + (HEIGHT - LIFT) / 2, 0)
		local byOuterBox = world:GetPartBoundsInBox(CFrame.new(boxCenter), Vector3.new(WIDTH, HEIGHT - LIFT, WIDTH))
		expect(#byOuterBox > 0).toBe(true)
		expect((PathCheck.bodyFits(options, nearTheThinEdge))).toBe(true)
	end)

	it("a body doesn't fit where a wedge's sloped side cuts into its box", function()
		addFloor()
		local wedge = addWedge()
		local deeperIn = Vector3.new(0, 0, -5 + WIDTH / 2 + 4)
		local fits, inTheWay = PathCheck.bodyFits(options, deeperIn)
		expect(fits).toBe(false)
		expect(inTheWay).toBe(wedge)
	end)

	it("the box turns to face the way the body points, so a corner can reach a wall a flat side doesn't", function()
		addFloor()
		-- just clear of a box that faces along an axis, but within reach of the corner of the same box turned 45 degrees
		local wall = addWallAt("DiagonalWall", WIDTH / 2 + MARGIN)
		local straightFits = PathCheck.bodyFits(options, feet, nil, Vector3.new(0, 0, 1))
		local diagonalFits, inTheWay = PathCheck.bodyFits(options, feet, nil, Vector3.new(1, 0, 1))
		expect(straightFits).toBe(true)
		expect(diagonalFits).toBe(false)
		expect(inTheWay).toBe(wall)
	end)

	it("a part on the box ignore list is not in the way", function()
		addFloor()
		local wall = addWallAt("IgnoredWall", WIDTH / 2 - MARGIN)
		options.boxIgnores = { wall :: Instance }
		expect((PathCheck.bodyFits(options, feet))).toBe(true)
	end)

	it("on a slope, a body fits between the slope and a ceiling parallel to it, tilted with the surface", function()
		local tilt = CFrame.Angles(0, 0, math.rad(30))
		local up = tilt.UpVector
		local onSlope = Vector3.new(0, 10, 0)
		-- the slope's top surface passes through the spot; the ceiling's underside is MARGIN above the body's top
		addPart("Slope", Vector3.new(60, 1, 60), CFrame.new(onSlope - up * 0.5) * tilt)
		addPart("SlopeCeiling", Vector3.new(60, 1, 60), CFrame.new(onSlope + up * (HEIGHT + MARGIN + 0.5)) * tilt)
		-- a box that stayed straight up would be cut by the slope at its uphill side, so this proves the tilt
		expect((PathCheck.bodyFits(options, onSlope, up))).toBe(true)
	end)

	it("on a slope, a body doesn't fit under a ceiling parallel to it that is lower than the body", function()
		local tilt = CFrame.Angles(0, 0, math.rad(30))
		local up = tilt.UpVector
		local onSlope = Vector3.new(0, 10, 0)
		addPart("Slope", Vector3.new(60, 1, 60), CFrame.new(onSlope - up * 0.5) * tilt)
		local ceiling =
			addPart("SlopeCeiling", Vector3.new(60, 1, 60), CFrame.new(onSlope + up * (HEIGHT - MARGIN + 0.5)) * tilt)
		local fits, inTheWay = PathCheck.bodyFits(options, onSlope, up)
		expect(fits).toBe(false)
		expect(inTheWay).toBe(ceiling)
	end)

	it("keeps one invisible probe part in the world, however many times it checks", function()
		addFloor()
		PathCheck.bodyFits(options, feet)
		PathCheck.bodyFits(options, feet + Vector3.new(3, 0, 0))
		expect(countProbes()).toBe(1)
		local probe = world:FindFirstChild("PathCheckProbe") :: BasePart
		expect(probe.Transparency).toBe(1)
		expect(probe.Anchored).toBe(true)
		expect(probe.CanCollide).toBe(false)
		expect(probe.CanTouch).toBe(false)
		expect(probe.CanQuery).toBe(false)
		expect(probe.Archivable).toBe(false)
	end)

	it("cleanup removes the probe, and a check after it still works with a new probe", function()
		addFloor()
		PathCheck.bodyFits(options, feet)
		PathCheck.cleanup(options)
		expect(countProbes()).toBe(0)
		expect((PathCheck.bodyFits(options, feet))).toBe(true)
		expect(countProbes()).toBe(1)
	end)

	it("makes a new probe if the old one was destroyed", function()
		addFloor()
		PathCheck.bodyFits(options, feet);
		(world:FindFirstChild("PathCheckProbe") :: Instance):Destroy()
		expect((PathCheck.bodyFits(options, feet))).toBe(true)
		expect(countProbes()).toBe(1)
	end)

	it("a probe left behind by another copy of the module is replaced, not doubled, and cleanup removes it", function()
		addFloor()
		local stray = Instance.new("Part")
		stray.Name = "PathCheckProbe"
		stray.Anchored = true
		stray.Parent = world
		PathCheck.bodyFits(options, feet)
		expect(countProbes()).toBe(1)
		expect(stray.Parent).toBeNil()
		local another = Instance.new("Part")
		another.Name = "PathCheckProbe"
		another.Parent = world
		PathCheck.cleanup(options)
		expect(countProbes()).toBe(0)
	end)

	it("the probe is never in the way of itself", function()
		addFloor()
		PathCheck.bodyFits(options, feet)
		local fits, inTheWay = PathCheck.bodyFits(options, feet)
		expect(fits).toBe(true)
		expect(inTheWay).toBeNil()
	end)
end)

-- roomToStand: a standing player can turn, so a body fits if it fits facing any of several ways.
describe("PathCheck.roomToStand", function()
	local WIDTH = Config.Stuck.BodyWidth

	local world: WorldModel
	local options: PathCheck.Options
	local feet = Vector3.new(0, 0, 0)

	local function addPart(name: string, size: Vector3, cframe: CFrame): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.CFrame = cframe
		part.Parent = world
		return part
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "PathCheckTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		options = PathCheck.defaults(world)
		world.Parent = ServerStorage
		addPart("Floor", Vector3.new(60, 1, 60), CFrame.new(0, -0.5, 0))
	end)

	afterEach(function()
		-- The world goes first, so a failing cleanup can never leave it behind (the probe lives inside it).
		local made = world :: WorldModel? -- nil if the first beforeEach failed before it made the world
		if made ~= nil then
			made:Destroy()
		end
		pcall(PathCheck.cleanup, options)
	end)

	it("fits where the unturned square's corner touches a slanted wall but a turned square fits", function()
		-- A wall slanted 45 degrees, its face 1.2 times the half width away: the unturned square's corner (1.41 times
		-- the half width) reaches it, a square turned 45 degrees (1.0 times the half width) does not.
		local toWall = Vector3.new(1, 0, 1).Unit
		local center = feet + toWall * (WIDTH / 2 * 1.2 + 0.5) + Vector3.new(0, 10, 0)
		addPart("SlantedWall", Vector3.new(1, 20, 40), CFrame.fromMatrix(center, toWall, Vector3.new(0, 1, 0)))
		expect((PathCheck.bodyFits(options, feet))).toBe(false) -- so the test means something
		local fits, inTheWay = PathCheck.roomToStand(options, feet)
		expect(fits).toBe(true)
		expect(inTheWay).toBeNil()
	end)

	it("doesn't fit where no turn helps, and names the part in the way", function()
		local wall = addPart("NearWall", Vector3.new(1, 20, 40), CFrame.new(WIDTH / 2 * 0.8 + 0.5, 10, 0))
		local fits, inTheWay = PathCheck.roomToStand(options, feet)
		expect(fits).toBe(false)
		expect(inTheWay).toBe(wall)
	end)
end)

describe("PathCheck.defaults", function()
	it("has the slope limit, the grid spacing and an empty box ignore list", function()
		local world = Instance.new("WorldModel")
		local options = PathCheck.defaults(world)
		expect(options.world).toBe(world)
		expect(options.slopeAngle).toBe(StarterPlayer.CharacterMaxSlopeAngle)
		expect(options.spacing).toBe(Config.Stuck.ScanSpacing)
		expect(options.boxIgnores).toEqual({})
		world:Destroy()
	end)
end)

-- The meadow ground (stuck safety Task 20). A fake world cannot hold real Terrain, so a block stands in for it (the
-- options take it through `any`) and is also put on the box ignore list: that makes the exact overlap check blind to
-- it, as it is to the real Terrain, so only the two rays that see just the ground can find it.
describe("PathCheck and the meadow ground", function()
	local GROUND_TOP = 0
	local world: WorldModel
	local options: PathCheck.Options

	local function addBlock(name: string, size: Vector3, centre: Vector3): Part
		local block = Instance.new("Part")
		block.Name = name
		block.Anchored = true
		block.Size = size
		block.CFrame = CFrame.new(centre)
		block.Parent = world
		return block
	end

	-- A block 10 studs thick under y = GROUND_TOP, as the "meadow ground".
	local function addGround(): Part
		local ground = addBlock("Ground", Vector3.new(40, 10, 40), Vector3.new(0, GROUND_TOP - 5, 0))
		options.boxIgnores = { ground :: Instance }
		options.terrain = ground :: any
		return ground
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "PathCheckTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		options = { world = world }
		world.Parent = ServerStorage
	end)

	afterEach(function()
		local made = world :: WorldModel? -- nil if the first beforeEach failed before it made the world
		if made ~= nil then
			made:Destroy()
		end
		pcall(PathCheck.cleanup, options)
	end)

	it("feet sunk into the ground have no room, and the ground is what is in the way", function()
		local ground = addGround()
		local fits, inTheWay = PathCheck.roomToStand(options, Vector3.new(0, GROUND_TOP - 3, 0))
		expect(fits).toBe(false)
		expect(inTheWay).toBe(ground)
	end)

	it("the overlap check alone does not see the ground", function()
		addGround()
		options.terrain = nil
		expect((PathCheck.roomToStand(options, Vector3.new(0, GROUND_TOP - 3, 0)))).toBe(true)
	end)

	it("feet on top of the ground have room", function()
		addGround()
		expect((PathCheck.roomToStand(options, Vector3.new(0, GROUND_TOP, 0)))).toBe(true)
	end)

	it("ground 0.2 studs over the feet is the ground they stand on", function()
		addGround()
		expect((PathCheck.roomToStand(options, Vector3.new(0, GROUND_TOP - 0.2, 0)))).toBe(true)
	end)

	it("ground 0.4 studs over the feet is in the way", function()
		addGround()
		expect((PathCheck.roomToStand(options, Vector3.new(0, GROUND_TOP - 0.4, 0)))).toBe(false)
	end)

	it("feet under an overhang of ground have room", function()
		-- a roof of ground 5 studs up and 10 thick, with nothing under it
		local roof = addBlock("Roof", Vector3.new(40, 10, 40), Vector3.new(0, 10, 0))
		options.boxIgnores = { roof :: Instance }
		options.terrain = roof :: any
		expect((PathCheck.roomToStand(options, Vector3.new(0, 0, 0)))).toBe(true)
	end)

	it("a world with no ground set changes nothing", function()
		addBlock("Floor", Vector3.new(40, 1, 40), Vector3.new(0, -0.5, 0))
		expect((PathCheck.roomToStand(options, Vector3.new(0, 0, 0)))).toBe(true)
		expect((PathCheck.bodyFits(options, Vector3.new(0, 0, 0)))).toBe(true)
	end)
end)

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
		expect(climbs[1].seconds).toBeCloseTo(climbs[1].length / (0.7 * WALK_SPEED), 5)
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

-- The walk check sees only what a player bumps into (stuck safety Task 19): a part in a collision group that does not
-- collide with the players' group (such as another player's body) is never ground, never in the way and never takes a
-- spot away. A fake WorldModel ignores collision groups, so this describe builds a small arena in the real Workspace,
-- far from the map, and takes it away again (docs/architecture.md, section 6, "The second exception:
-- collision-group tests").
describe("PathCheck and collision groups", function()
	local LOOK_GROUP = "PathCheckTestLook" -- a group players pass through, registered for these tests
	local ARENA_NAME = "PathCheckGroupArena"
	local CENTER = Vector3.new(5000, 5000, 5000) -- the real map is nowhere near here
	-- Columns every 2 studs: x and z 4996, 4998, 5000, 5002, 5004. The floor's top is at y = 5000.
	local AREA: PathCheck.Area = { min = Vector3.new(4996, 4995, 4996), max = Vector3.new(5004, 5010, 5004) }

	local arena: Model?
	local options: PathCheck.Options

	local function startsWith(text: string, part: string): boolean
		return string.sub(text, 1, #part) == part
	end

	local function addPart(name: string, size: Vector3, center: Vector3, group: string?): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.Position = center
		if group ~= nil then
			part.CollisionGroup = group
		end
		part.Parent = arena
		return part
	end

	-- A floor 20 by 20 studs whose top is at y = 5000.
	local function addFloor(group: string?): Part
		return addPart("Floor", Vector3.new(20, 1, 20), CENTER - Vector3.new(0, 0.5, 0), group)
	end

	beforeAll(function()
		-- anything a crashed run left: the arena first, then the group
		for _, child in Workspace:GetChildren() do
			if child.Name == ARENA_NAME then
				child:Destroy()
			end
		end
		if PhysicsService:IsCollisionGroupRegistered(LOOK_GROUP) then
			PhysicsService:UnregisterCollisionGroup(LOOK_GROUP)
		end
		Collisions.setupGroup(PhysicsService) -- "Players" exists the way the running game makes it
		PhysicsService:RegisterCollisionGroup(LOOK_GROUP)
		PhysicsService:CollisionGroupSetCollidable(LOOK_GROUP, Collisions.GROUP, false)
	end)

	afterAll(function()
		if PhysicsService:IsCollisionGroupRegistered(LOOK_GROUP) then
			PhysicsService:UnregisterCollisionGroup(LOOK_GROUP)
		end
	end)

	beforeEach(function()
		local made = Instance.new("Model")
		made.Name = ARENA_NAME
		made.Archivable = false -- a crashed run never saves its arena with the place
		made.Parent = Workspace
		arena = made
		options = PathCheck.defaults(Workspace)
	end)

	afterEach(function()
		-- the arena goes first, so a failing cleanup can never leave it behind
		local made = arena
		if made ~= nil then
			made:Destroy()
		end
		arena = nil
		pcall(PathCheck.cleanup, options)
	end)

	it("a floor in a group players pass through is no ground: no spot, and a link across it says so", function()
		addFloor(LOOK_GROUP)
		local map = PathCheck.buildMap(options, AREA)
		expect(#map.spots).toBe(0)
		local problem = PathCheck.linkProblem(options, CENTER + Vector3.new(-3, 0, 0), CENTER + Vector3.new(3, 0, 0))
		expect(problem).never.toBeNil()
		expect(startsWith(problem :: string, "no ground at (")).toBe(true)
	end)

	it("a wall in a group players pass through does not block a link on a real floor", function()
		addFloor()
		addPart("Wall", Vector3.new(1, 10, 12), CENTER + Vector3.new(0, 5, 0), LOOK_GROUP)
		expect(PathCheck.linkProblem(options, CENTER + Vector3.new(-3, 0, 0), CENTER + Vector3.new(3, 0, 0))).toBeNil()
	end)

	it("a block in a group players pass through does not take a standing place away", function()
		addFloor()
		addPart("Block", Vector3.new(3, 4, 3), CENTER + Vector3.new(0, 2, 0), LOOK_GROUP)
		local map = PathCheck.buildMap(options, AREA)
		local onFloor = false
		local onBlock = false
		for _, spot in map.spots do
			if math.abs(spot.position.X - CENTER.X) < 0.1 and math.abs(spot.position.Z - CENTER.Z) < 0.1 then
				onFloor = onFloor or math.abs(spot.position.Y - CENTER.Y) < 0.1
				onBlock = onBlock or math.abs(spot.position.Y - (CENTER.Y + 4)) < 0.1
			end
		end
		expect(onFloor).toBe(true) -- the block under the body's box is not in the way
		expect(onBlock).toBe(false) -- and its top is no ground
	end)

	it("a part in the players' own group, like another player's body, doesn't take a standing place away", function()
		addFloor()
		-- another player's body: about 2 studs wide and 4.3 tall, standing where this body would stand
		addPart("OtherBody", Vector3.new(2, 4.3, 2), CENTER + Vector3.new(0, 2.15, 0), Collisions.GROUP)
		local map = PathCheck.buildMap(options, AREA)
		local onFloor = false
		for _, spot in map.spots do
			if math.abs(spot.position.X - CENTER.X) < 0.1 and math.abs(spot.position.Z - CENTER.Z) < 0.1 then
				onFloor = onFloor or math.abs(spot.position.Y - CENTER.Y) < 0.1
			end
		end
		expect(onFloor).toBe(true) -- the spot is still on the floor
		expect(PathCheck.roomToStand(options, CENTER, Vector3.yAxis)).toBe(true)
	end)
end)
