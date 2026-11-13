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
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)

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
