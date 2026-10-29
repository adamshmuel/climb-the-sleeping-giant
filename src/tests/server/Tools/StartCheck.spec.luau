--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Helpers = require(ServerStorage.Tests.server.World.RealWorld.Helpers)
local StartCheck = require(ServerStorage.Tools.checks.StartCheck)
local inFakeWorld = Helpers.inFakeWorld

local function solid(world: WorldModel, name: string, size: Vector3, frame: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = frame
	part.Parent = world
	return part
end

-- A level floor whose top is y 0.
local function flatFloor(world: WorldModel)
	solid(world, "Floor", Vector3.new(200, 1, 200), CFrame.new(0, -0.5, 0))
end

-- A floor tilted `degrees` whose top passes through the origin, uphill toward the direction `yaw` turns +X to.
local function tiltedFloor(world: WorldModel, degrees: number, yawDegrees: number?)
	local turn = CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
	solid(
		world,
		"Floor",
		Vector3.new(200, 1, 200),
		turn * CFrame.Angles(0, 0, math.rad(degrees)) * CFrame.new(0, -0.5, 0)
	)
end

-- Stuck safety Task 27, step 1 (lesson 21): the shared start check, tested on made-up worlds. Since step 1b the rays
-- start 0.5 studs over the spot (RAY_ABOVE), not 10. The thick roofs here are kept so the old cases still run: a ray
-- from 0.5 up still starts inside a thick slab, so (like a ray in the giant) it never hits the roof and finds the floor.
describe("StartCheck.find", function()
	local SLOPE = math.rad(20) -- the floor's tilt in the slope tests: +X is uphill, so downhill is -X

	-- A floor tilted 20 degrees whose top passes through the origin (height = tan(20) * x).
	local function slopedFloor(world: WorldModel)
		solid(world, "Floor", Vector3.new(200, 1, 200), CFrame.Angles(0, 0, SLOPE) * CFrame.new(0, -0.5, 0))
	end

	it("is open on a flat floor at floor + 0.1", function()
		inFakeWorld(function(world)
			flatFloor(world)
			local result = StartCheck.find(Vector3.new(0, 3, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(0)
			expect(result.position).never.toBeNil()
			expect((result.position :: Vector3).Y).toBeCloseTo(0.1, 3)
		end)
	end)

	it("is not open under a low roof, and names the roof", function()
		inFakeWorld(function(world)
			flatFloor(world)
			solid(world, "LowRoof", Vector3.new(200, 40, 200), CFrame.new(0, 23, 0)) -- y 3 to 43
			local result = StartCheck.find(Vector3.new(0, 1, 0), world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("LowRoof")
		end)
	end)

	it("is open after 1 downhill move on a wedge slope", function()
		inFakeWorld(function(world)
			slopedFloor(world)
			-- x 0.6 to 10.6. The walk map's tilted, lifted box reaches x 0.77 on the 20 degree wedge, so the first
			-- try is blocked by 0.17. After the move it reaches x 0.27, clear by 0.33. That try's uphill corner
			-- ray at x 0.5 stays 0.1 clear of the wall's face.
			solid(world, "Wall", Vector3.new(10, 20, 30), CFrame.new(5.6, 10, 0))
			local result = StartCheck.find(Vector3.new(0, 3, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(1)
			expect((result.position :: Vector3).X).toBeCloseTo(-0.5, 3)
		end)
	end)

	it("is not open after 4 moves inside a closed box", function()
		inFakeWorld(function(world)
			slopedFloor(world)
			solid(world, "BoxRoof", Vector3.new(200, 40, 200), CFrame.new(0, 23, 0))
			local result = StartCheck.find(Vector3.new(0, 1, 0), world)
			expect(result.open).toBe(false)
			expect(result.moves).toBe(4)
			expect(result.blockers).toContain("BoxRoof")
		end)
	end)

	it("says a spot inside a solid part is not open", function()
		inFakeWorld(function(world)
			solid(world, "Block", Vector3.new(60, 60, 60), CFrame.new(0, 5, 0))
			local result = StartCheck.find(Vector3.new(0, 5, 0), world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("Block")
		end)
	end)

	it("says a spot under a thin roof is not open, and names the roof", function()
		inFakeWorld(function(world)
			flatFloor(world)
			solid(world, "ThinRoof", Vector3.new(200, 0.5, 200), CFrame.new(0, 4.25, 0)) -- y 4 to 4.5
			local result = StartCheck.find(Vector3.new(0, 3, 0), world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("ThinRoof")
		end)
	end)

	-- Stuck safety Task 27, step 1c (lesson 38): steep ground. The uphill corner rays start inside the slope.
	it("is open on a 45 degree slope, standing above its uphill corners", function()
		inFakeWorld(function(world)
			tiltedFloor(world, 45)
			local result = StartCheck.find(Vector3.new(0, 0, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(0)
			expect((result.position :: Vector3).Y).toBeCloseTo(math.tan(math.rad(45)) + 0.1, 2)
		end)
	end)

	it("is open on a slope 1 degree under the climb limit", function()
		inFakeWorld(function(world)
			local angle = StarterPlayer.CharacterMaxSlopeAngle - 1
			tiltedFloor(world, angle)
			local result = StartCheck.find(Vector3.new(0, 0, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(0)
			expect((result.position :: Vector3).Y).toBeCloseTo(math.tan(math.rad(angle)) + 0.1, 2)
		end)
	end)

	it("is open on a 60 degree slope that rises toward a corner", function()
		inFakeWorld(function(world)
			tiltedFloor(world, 60, -45) -- uphill is +X +Z: the corner (1, 1) is the highest
			local result = StartCheck.find(Vector3.new(0, 0, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(0)
			expect((result.position :: Vector3).Y).toBeCloseTo(math.sqrt(2) * math.tan(math.rad(60)) + 0.1, 2)
		end)
	end)

	it("at the foot of a wall steeper than the climb limit, it stands on the floor", function()
		inFakeWorld(function(world)
			flatFloor(world)
			local degrees = StarterPlayer.CharacterMaxSlopeAngle + 10
			-- A wall whose face leaves the floor at x 0.8 and rises toward +X.
			solid(
				world,
				"SteepWall",
				Vector3.new(60, 1, 60),
				CFrame.new(0.8, 0, 0) * CFrame.Angles(0, 0, math.rad(degrees)) * CFrame.new(0, -0.5, 0)
			)
			local result = StartCheck.find(Vector3.new(0, 0, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(1)
			expect((result.position :: Vector3).X).toBeCloseTo(-0.5, 2)
			expect((result.position :: Vector3).Y).toBeCloseTo(0.1, 2)
			expect((result.position :: Vector3).Z).toBeCloseTo(0, 2)
		end)
	end)

	it("a thin ledge over two corners is not read as ground", function()
		inFakeWorld(function(world)
			flatFloor(world)
			solid(world, "Ledge", Vector3.new(4.4, 0.2, 10), CFrame.new(2.8, 2.1, 0)) -- y 2.0 to 2.2, x 0.6 to 5
			local result = StartCheck.find(Vector3.new(0, 0, 0), world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("Ledge")
		end)
	end)

	-- Stuck safety Task 46: the walk map's own fit test (PathCheck.roomToStand) decides whether the body fits, and the
	-- centre of the start must have a floor.
	it("is open on a 65 degree slope with an overhang over its uphill side, where the tilted body fits", function()
		inFakeWorld(function(world)
			tiltedFloor(world, 65)
			-- A block high over the uphill side (x 0.9 and more, from y 5): an upright body reaches it, a body leaning with the slope does not.
			solid(world, "Overhang", Vector3.new(10, 4, 10), CFrame.new(5.9, 7, 0))
			local result = StartCheck.find(Vector3.new(0, 0, 0), world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(0)
			expect((result.position :: Vector3).Y).toBeCloseTo(math.tan(math.rad(65)) + 0.1, 2)
		end)
	end)

	it("says a start with no floor under its centre is not open, even with a thin plate under two corners", function()
		inFakeWorld(function(world)
			flatFloor(world)
			solid(world, "Plate", Vector3.new(4.4, 0.2, 10), CFrame.new(2.8, 19.5, 0)) -- y 19.4 to 19.6, x 0.6 to 5
			local result = StartCheck.find(Vector3.new(0, 20, 0), world) -- the floor is 20 studs under the centre
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("no floor")
		end)
	end)

	-- Stuck safety Task 55 (lesson 75): `position` is the highest ray's hit + 0.1, so in a dip it is not the ground under
	-- the body's middle. `ground` is that middle ground, for jobs that measure how far a body settles.
	it("find gives the ground under the middle of a dip", function()
		inFakeWorld(function(world)
			flatFloor(world)
			-- A block 2 studs high over one corner only (x and z 0.9 and more): the middle and the other corners stay
			-- on the floor, and a body turned 45 degrees still fits beside it.
			solid(world, "Rim", Vector3.new(2.1, 2, 2.1), CFrame.new(1.95, 1, 1.95))
			local result = StartCheck.find(Vector3.new(0, 3, 0), world)
			expect(result.open).toBe(true)
			expect(result.ground).never.toBeNil()
			expect((result.ground :: Vector3).Y).toBeCloseTo(0, 2)
			local position = result.position :: Vector3
			expect(position.Y - (result.ground :: Vector3).Y).toBeCloseTo(2.1, 2)
		end)
	end)

	it("leaves no probe behind", function()
		inFakeWorld(function(world)
			flatFloor(world)
			solid(world, "LowRoof", Vector3.new(200, 40, 200), CFrame.new(0, 23, 0))
			StartCheck.find(Vector3.new(0, 1, 0), world) -- blocked
			StartCheck.find(Vector3.new(500, 3, 500), world) -- no ground
			solid(world, "FarFloor", Vector3.new(200, 1, 200), CFrame.new(300, -0.5, 0))
			StartCheck.find(Vector3.new(300, 3, 0), world) -- open
			tiltedFloor(world, 45)
			StartCheck.find(Vector3.new(0, 0, 0), world) -- open, on steep ground
			expect(#world:GetChildren()).toBe(4)
			expect(world:FindFirstChild("StartCheckProbe")).toBeNil()
		end)
	end)
end)

-- Stuck safety Task 53: every start comes from the walk map, through the shared start check.
describe("StartCheck.nearSpot", function()
	it("a start on a tilted plank next to a round boulder is open, though the boulder's outer box covers it", function()
		inFakeWorld(function(world)
			-- The ball's radius is 4. The walk map's tilted, lifted body box (PathCheck.roomToStand) comes no closer
			-- than 5.47 to its centre (clear by 1.47). Its outer box (x and z 0.6 to 8.6) covers the upright box
			-- (x and z -1 to 1), so a check on outer boxes would call the start blocked.
			solid(world, "Plank", Vector3.new(12, 1, 6), CFrame.Angles(0, 0, math.rad(30)) * CFrame.new(0, -0.5, 0))
			local boulder = solid(world, "Boulder", Vector3.new(8, 8, 8), CFrame.new(4.6, 2, 4.6))
			boulder.Shape = Enum.PartType.Ball
			expect(table.find(world:GetPartBoundsInBox(CFrame.new(0, 2.65, 0), Vector3.new(2, 4.3, 2)), boulder)).never.toBeNil()
			local result = StartCheck.nearSpot(Vector3.zero, 4, world)
			expect(result.open).toBe(true)
			expect(result.moves).toBe(0)
			expect((result.position :: Vector3).X).toBeCloseTo(0, 2)
			expect((result.position :: Vector3).Z).toBeCloseTo(0, 2)
		end)
	end)

	it("a start inside a solid block is not open and names it", function()
		inFakeWorld(function(world)
			solid(world, "Block", Vector3.new(60, 60, 60), CFrame.new(0, 5, 0))
			local result = StartCheck.nearSpot(Vector3.new(0, 5, 0), 4, world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("Block")
		end)
	end)

	it("a thin upright plate has no walk-map spot", function()
		inFakeWorld(function(world)
			flatFloor(world)
			local plate = solid(world, "Plate", Vector3.new(0.2, 12, 6), CFrame.new(0, 6, 0))
			local result = StartCheck.nearSpot(Vector3.new(0.5, 4, 0), 4, world, plate)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("no walk-map spot")
		end)
	end)

	-- Task 12i (Lesson 125): a start is accepted only on ground a body has stood still on (normal Y 0.65, about 49
	-- degrees), not on any ground it can walk up (70 degrees).
	it("a 60 degree slope is too steep to hold still", function()
		inFakeWorld(function(world)
			tiltedFloor(world, 60)
			local result = StartCheck.nearSpot(Vector3.zero, 4, world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("too steep to hold still")
		end)
	end)

	it("a 50 degree slope is too steep to hold still", function()
		inFakeWorld(function(world)
			tiltedFloor(world, 50)
			local result = StartCheck.nearSpot(Vector3.zero, 4, world)
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("too steep to hold still")
		end)
	end)

	it("the start is checked where it ends up, not where the walk-map spot was", function()
		inFakeWorld(function(world)
			-- The spot is on a flat floor. A 60 degree face stands 20 studs away, and `find` (stubbed) ends over it, as
			-- the downhill moves would.
			flatFloor(world)
			local faceFrame = CFrame.new(20, 3, 0) * CFrame.Angles(0, 0, math.rad(60)) * CFrame.new(0, -0.5, 0)
			solid(world, "Face", Vector3.new(10, 1, 10), faceFrame)
			local realFind = StartCheck.find
			StartCheck.find = function(_spot: Vector3, _root: Instance?): StartCheck.Result
				return {
					open = true,
					position = Vector3.new(20, 3.1, 0),
					ground = Vector3.new(20, 3, 0),
					moves = 2,
					blockers = {},
				}
			end
			local ok, outcome = pcall(StartCheck.nearSpot, Vector3.zero, 4, world)
			StartCheck.find = realFind
			if not ok then
				error(outcome, 0)
			end
			local result = outcome :: StartCheck.Result
			expect(result.open).toBe(false)
			expect(result.blockers).toContain("too steep to hold still")
		end)
	end)

	it("a 40 degree slope still holds a start", function()
		inFakeWorld(function(world)
			tiltedFloor(world, 40)
			local result = StartCheck.nearSpot(Vector3.zero, 4, world)
			expect(result.open).toBe(true)
		end)
	end)
end)
