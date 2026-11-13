--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ServerStorage = game:GetService("ServerStorage")
local PostRim = require(ServerStorage.Tools.checks.PostRim)

-- Plan 5 Task 19c, Step 1: the rail post rim check (tools/checks/PostRim.luau) on made-up parts. A nest's rim is half
-- the larger of its mesh's X and Z; a post is a problem when its flat distance to the nest centre is less than the rim
-- plus half the post's larger X/Z, and its height overlaps the nest model's bounding box.

describe("PostRim.problems", function()
	local world: WorldModel
	local mesh: Part
	local nests: { { name: string, mesh: BasePart, box: { cframe: CFrame, size: Vector3 } } }

	-- A post 0.4 wide and 1 tall, its middle `flat` studs from the nest centre (along X) and `y` studs up.
	local function addPost(flat: number, y: number): Part
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(0.4, 1, 0.4)
		post.CFrame = CFrame.new(flat, y, 0)
		post.Parent = world
		return post
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Parent = ServerStorage
		-- The nest mesh is 5.2 by 5.2 (rim 2.6) at y 10; its model's box runs from y 9.5 to 11.5.
		mesh = Instance.new("Part")
		mesh.Name = "Nest"
		mesh.Anchored = true
		mesh.Size = Vector3.new(5.2, 1, 5.2)
		mesh.CFrame = CFrame.new(0, 10, 0)
		mesh.Parent = world
		nests = {
			{
				name = "Nest_Test_Left",
				mesh = mesh,
				box = { cframe = CFrame.new(0, 10.5, 0), size = Vector3.new(5.2, 2, 5.2) },
			},
		}
	end)

	afterEach(function()
		world:Destroy()
	end)

	it("lists a post 0.1 inside a rim and names the post and the nest", function()
		-- Needs 2.6 + 0.2 = 2.8 from the centre; 2.7 is 0.1 inside.
		local list = PostRim.problems(nests, { addPost(2.7, 10) })
		expect(#list).toBe(1)
		expect((string.find(list[1], "Post", 1, true))).never.toBe(nil)
		expect((string.find(list[1], "Nest_Test_Left", 1, true))).never.toBe(nil)
		expect((string.find(list[1], "-0.10", 1, true))).never.toBe(nil)
	end)

	it("does not list a post 0.3 outside the rim", function()
		expect(#PostRim.problems(nests, { addPost(3.1, 10) })).toBe(0)
	end)

	it("does not list a post that stands above the nest's height band", function()
		expect(#PostRim.problems(nests, { addPost(2.7, 20) })).toBe(0)
	end)
end)
