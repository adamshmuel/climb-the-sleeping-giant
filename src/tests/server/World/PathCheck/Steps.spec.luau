--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require(ReplicatedStorage.Shared.Config)
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
