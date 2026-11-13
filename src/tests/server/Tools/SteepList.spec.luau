--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")
local Helpers = require(ServerStorage.Tests.server.World.RealWorld.Helpers)
local SteepList = require(ServerStorage.Tools.checks.SteepList)
local inFakeWorld = Helpers.inFakeWorld

-- Stuck safety Task 45, step 1: the steep list's rule, tested on made-up worlds. Each kind of entry
-- (steep, wall, guard) is listed in one test, and each "not listed" case sits next to a listed one, so a stub that
-- returns an empty list fails every test.
describe("SteepList.build", function()
	local CLIMB_LIMIT = 70 -- degrees: the climb limit in these tests

	local function part(parent: Instance, name: string, size: Vector3, frame: CFrame): BasePart
		local made = Instance.new("Part")
		made.Name = name
		made.Anchored = true
		made.Size = size
		made.CFrame = frame
		made.Parent = parent
		return made
	end

	-- A giant model holding a small part named body_and_cushion at the origin (the spots stand on it; its 1 stud top is
	-- under the rays' first reach, so it never gets in the wall rays' way).
	local function newGiant(world: WorldModel): (Model, BasePart)
		local giant = Instance.new("Model")
		giant.Name = "Giant"
		giant.Parent = world
		return giant, part(giant, "body_and_cushion", Vector3.one, CFrame.new(0, -0.5, 0))
	end

	local function newSpot(position: Vector3, degrees: number, standsOn: BasePart): SteepList.Spot
		local radians = math.rad(degrees)
		return { position = position, up = Vector3.new(math.sin(radians), math.cos(radians), 0), standsOn = standsOn }
	end

	local function newOptions(giant: Instance, guards: { BasePart }?): SteepList.Options
		return { giant = giant, guards = guards or {}, climbLimit = CLIMB_LIMIT, rayParams = RaycastParams.new() }
	end

	-- A thin plate whose top face leans `degrees` from flat, toward -x (facing a spot at the origin). Its lowest top
	-- edge is `edge` studs out along +x, and 2 studs under the spot, so a ray down 1.5 to 2 studs out lands on the face.
	local function facePlate(world: WorldModel, degrees: number, edge: number)
		local radians = math.rad(degrees)
		local length, thick = 6, 0.5
		local centre = Vector3.new(
			edge + length / 2 * math.cos(radians) + thick / 2 * math.sin(radians),
			-2 + length / 2 * math.sin(radians) - thick / 2 * math.cos(radians),
			0
		)
		part(world, "Face", Vector3.new(length, thick, length), CFrame.new(centre) * CFrame.Angles(0, 0, radians))
	end

	-- The list for one flat spot at the origin, with a plate of `degrees` whose near edge is `edge` studs away.
	local function listNearFace(degrees: number, edge: number): { SteepList.Entry }
		local entries: { SteepList.Entry } = {}
		inFakeWorld(function(world)
			local giant, body = newGiant(world)
			facePlate(world, degrees, edge)
			entries = SteepList.build({ newSpot(Vector3.zero, 0, body) }, newOptions(giant)).list
		end)
		return entries
	end

	it("lists a 45 degree cloth spot as steep, and not a 44 degree one", function()
		inFakeWorld(function(world)
			local giant, body = newGiant(world)
			local spots = { newSpot(Vector3.new(10, 0, 0), 45, body), newSpot(Vector3.new(20, 0, 0), 44, body) }
			local result = SteepList.build(spots, newOptions(giant))
			expect(#result.list).toBe(1)
			expect(result.list[1].kind).toBe("steep")
			expect(result.list[1].position).toBe(Vector3.new(10, 0, 0))
			expect(result.list[1].slope).toBeCloseTo(45, 3)
		end)
	end)

	it("lists a flat cloth spot 1.5 studs from a 75 degree face as wall, and not at 3 studs", function()
		local near = listNearFace(75, 1.5)
		expect(#near).toBe(1)
		expect(near[1].kind).toBe("wall")
		expect(near[1].slope).toBeCloseTo(75, 2)
		expect(#listNearFace(75, 3)).toBe(0)
	end)

	it("does not list a flat cloth spot 1.5 studs from a 60 degree face", function()
		expect(#listNearFace(60, 1.5)).toBe(0)
		expect(#listNearFace(75, 1.5)).toBe(1) -- the same world with a face past the limit, so the test can fail
	end)

	it("does not list a steep spot off the cloth part or outside the giant", function()
		inFakeWorld(function(world)
			local giant, body = newGiant(world)
			local patch = part(giant, "Patch_1", Vector3.one, CFrame.new(30, -0.5, 0))
			local pillow = part(world, "body_and_cushion", Vector3.one, CFrame.new(40, -0.5, 0)) -- outside the giant
			local spots = {
				newSpot(Vector3.new(10, 0, 0), 50, body),
				newSpot(Vector3.new(30, 0, 0), 50, patch),
				newSpot(Vector3.new(40, 0, 0), 50, pillow),
			}
			local result = SteepList.build(spots, newOptions(giant))
			expect(#result.list).toBe(1)
			expect(result.list[1].position).toBe(Vector3.new(10, 0, 0))
			expect(result.counts.cloth).toBe(1)
		end)
	end)

	it("lists a guard with nothing under it first, at its top middle", function()
		inFakeWorld(function(world)
			local giant, body = newGiant(world)
			local guard = part(world, "Guard_1", Vector3.new(4, 2, 4), CFrame.new(100, 50, 100))
			local result = SteepList.build({ newSpot(Vector3.new(10, 0, 0), 50, body) }, newOptions(giant, { guard }))
			expect(#result.list).toBe(2)
			expect(result.list[1].kind).toBe("guard")
			expect(result.list[1].position).toBe(Vector3.new(100, 51, 100))
			expect(result.list[1].slope).toBe(0)
			expect(result.list[2].kind).toBe("steep")
		end)
	end)

	it("orders guards by name, then steepest first by x then z, and counts every kind", function()
		inFakeWorld(function(world)
			local giant, body = newGiant(world)
			local guardB = part(world, "B", Vector3.one, CFrame.new(0, 10, 0))
			local guardA = part(world, "A", Vector3.one, CFrame.new(0, 20, 0))
			local spots = {
				newSpot(Vector3.new(5, 0, 0), 50, body),
				newSpot(Vector3.new(7, 0, 0), 60, body),
				newSpot(Vector3.new(-3, 0, 2), 50, body),
				newSpot(Vector3.new(-3, 0, -2), 50, body),
			}
			local result = SteepList.build(spots, newOptions(giant, { guardB, guardA }))
			local positions: { Vector3 } = {}
			for _, entry in result.list do
				table.insert(positions, entry.position)
			end
			expect(positions).toEqual({
				Vector3.new(0, 20.5, 0), -- guard A
				Vector3.new(0, 10.5, 0), -- guard B
				Vector3.new(7, 0, 0), -- 60 degrees
				Vector3.new(-3, 0, -2), -- 50 degrees: x, then z
				Vector3.new(-3, 0, 2),
				Vector3.new(5, 0, 0),
			})
			expect(result.counts).toEqual({ cloth = 4, steep = 4, wall = 0, guards = 2, total = 6 })
		end)
	end)
end)
