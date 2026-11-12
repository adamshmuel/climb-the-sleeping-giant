--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamFx = require(Client.Fx.SlamFx)
local Helpers = require(script.Parent.Helpers)
local UP = Helpers.UP
local cleanUp = Helpers.cleanUp
local expectNear = Helpers.expectNear
local made = Helpers.made

afterEach(cleanUp)

describe("SlamFx.huggableParts and workspaceCastHug", function()
	-- A little world far from the map, built like the real one: the meadow's Terrain stays the real one (empty here).
	-- Every part is solid (CanCollide on) so only the list decides what a ray meets.
	local ORIGIN = Vector3.new(3000, 100, 3000)

	local function newWorld(): Folder
		local world = made(Instance.new("Folder"))
		world.Name = "World"
		world.Parent = Workspace
		return world
	end

	local function add(parent: Instance, name: string, size: Vector3, position: Vector3, className: string?): Part
		local part = Instance.new(className or "Part") :: Part
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.Position = ORIGIN + position
		part.Parent = parent
		return part
	end

	local function folderIn(parent: Instance, name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end

	local function modelIn(parent: Instance, name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent
		return model
	end

	-- Everything the real world has that matters, each thing at its own place along x (top faces at y = 5 unless said).
	type Scene = {
		world: Folder,
		bridge: Model,
		plank: Part,
		cast: SlamFx.CastHug,
		refresh: () -> (),
	}

	local function newScene(): Scene
		local world = newWorld()
		local giant = modelIn(world, "Giant")
		local function giantPart(name: string, x: number): Part
			local model = modelIn(giant, name)
			return add(model, name, Vector3.new(10, 10, 10), Vector3.new(x, 0, 0)) -- top at 5
		end
		giantPart("body_and_cushion", 0)
		giantPart("head_with_beard", 20)
		giantPart("legs_and_boots", 40)
		giantPart("nightcap", 60)
		giantPart("left_arm", 80)
		giantPart("right_arm", 100)
		local walk = folderIn(world, "WalkSurfaces")
		add(modelIn(walk, "BootRamp"), "Ramp_Walk", Vector3.new(10, 10, 10), Vector3.new(120, 0, 0))
		add(modelIn(walk, "RightBootRamp"), "Ramp_Walk", Vector3.new(10, 10, 10), Vector3.new(140, 0, 0))
		-- An invisible solid plank on top of the body, like the ones players walk on.
		local belly = add(walk, "Belly_Walk", Vector3.new(10, 1, 10), Vector3.new(0, 5.5, 0))
		belly.Transparency = 1
		local bridges = folderIn(world, "Bridges")
		local bridge = modelIn(bridges, "PlankBridge_1")
		local plank = add(bridge, "Plank", Vector3.new(10, 1, 10), Vector3.new(160, 4.5, 0))
		add(bridge, "Post", Vector3.new(2, 8, 2), Vector3.new(180, 4, 0))
		add(bridge, "Rope", Vector3.new(10, 1, 10), Vector3.new(200, 4.5, 0))
		local things = folderIn(world, "GiantsThings")
		add(things, "Teacup", Vector3.new(10, 10, 10), Vector3.new(220, 0, 0))
		local nature = folderIn(world, "Nature")
		add(nature, "TreeTrunk", Vector3.new(10, 10, 10), Vector3.new(240, 0, 0))
		local cast, refresh = SlamFx.workspaceCastHug(Workspace, world)
		return { world = world, bridge = bridge, plank = plank, cast = cast, refresh = refresh }
	end

	-- Casts straight down at the place `x` along the row and gives the height of what it hit, or nil.
	local function hitHeight(scene: Scene, x: number): number?
		local position = scene.cast(ORIGIN + Vector3.new(x, 30, 0), Vector3.new(0, -60, 0))
		return if position ~= nil then position.Y - ORIGIN.Y else nil
	end

	it("hits his body_and_cushion, head, legs, nightcap and left arm", function()
		local scene = newScene()
		for _, x in { 0, 20, 40, 60, 80 } do
			local height = hitHeight(scene, x)
			expect(height).never.toBeNil()
			expect(math.abs((height :: number) - 5) < 1e-3).toBe(true)
		end
	end)

	it("hits a Ramp_Walk and a bridge Plank", function()
		local scene = newScene()
		expect(math.abs((hitHeight(scene, 120) :: number) - 5) < 1e-3).toBe(true)
		expect(math.abs((hitHeight(scene, 140) :: number) - 5) < 1e-3).toBe(true)
		expect(math.abs((hitHeight(scene, 160) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("gives the normal of what it hits", function()
		local scene = newScene()
		local _, normal = scene.cast(ORIGIN + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0))
		expect(normal).never.toBeNil()
		expectNear(normal :: Vector3, UP)
	end)

	it("goes through his right arm, which moves during slams", function()
		local scene = newScene()
		expect(hitHeight(scene, 100)).toBeNil()
	end)

	it("goes through a bridge Post and a Rope", function()
		local scene = newScene()
		expect(hitHeight(scene, 180)).toBeNil()
		expect(hitHeight(scene, 200)).toBeNil()
	end)

	it("goes through an invisible walk plank on top of his body, and hits the body under it", function()
		local scene = newScene()
		-- The plank's top is at 6; the body's at 5.
		expect(math.abs((hitHeight(scene, 0) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("goes through props: a solid part in GiantsThings and a tree trunk", function()
		local scene = newScene()
		expect(hitHeight(scene, 220)).toBeNil()
		expect(hitHeight(scene, 240)).toBeNil()
	end)

	it("goes through a character model standing on the body", function()
		local scene = newScene()
		local character = made(Instance.new("Model"))
		character.Name = "SomeoneStanding"
		add(character, "HumanoidRootPart", Vector3.new(4, 5, 2), Vector3.new(0, 8, 0))
		character.Parent = Workspace
		expect(math.abs((hitHeight(scene, 0) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("hits only what is on the list, not a part that is not under the Giant, WalkSurfaces or Bridges", function()
		local scene = newScene()
		scene.refresh()
		local extra = add(scene.world, "SolidCrate", Vector3.new(10, 10, 10), Vector3.new(260, 0, 0))
		expect(extra.CanCollide).toBe(true)
		expect(hitHeight(scene, 260)).toBeNil()
	end)

	it("goes through a part that can't be collided with, even one on the list", function()
		local scene = newScene()
		scene.plank.CanCollide = false
		expect(hitHeight(scene, 160)).toBeNil()
	end)

	-- Guard (plan 3 Task 15a): passes when written, because the list only holds the giant, the ramps and the planks. The
	-- server's slam point skips ladders too (SlamSurface.ladderParts), so the two circles agree on a ladder.
	it("a ladder model in the world is never in huggableParts, and a ray over it finds the pad", function()
		local scene = newScene()
		local walk = scene.world:FindFirstChild("WalkSurfaces") :: Instance
		add(modelIn(walk, "PadRamp"), "Ramp_Walk", Vector3.new(10, 10, 10), Vector3.new(300, 0, 0)) -- top at 5
		local ladder = modelIn(walk, "BeardLadder")
		add(ladder, "Climb", Vector3.new(2, 10, 1), Vector3.new(300, 12, 0), "TrussPart")
		for step = 1, 3 do
			add(ladder, "Rung", Vector3.new(2, 0.5, 0.5), Vector3.new(300, 6 + step * 3, 0))
		end
		scene.refresh()
		local list = SlamFx.huggableParts(Workspace, scene.world)
		for _, instance in list do
			expect(instance:IsDescendantOf(ladder)).toBe(false)
		end
		expect(table.find(list, scene.plank)).never.toBeNil()
		expect(math.abs((hitHeight(scene, 300) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("lists the Terrain, the five body parts, the two ramps and the planks, and nothing else", function()
		local scene = newScene()
		local list = SlamFx.huggableParts(Workspace, scene.world)
		expect(table.find(list, Workspace.Terrain)).never.toBeNil()
		local names: { string } = {}
		for _, instance in list do
			if instance ~= Workspace.Terrain then
				table.insert(names, instance.Name)
			end
		end
		table.sort(names)
		expect(table.concat(names, ",")).toBe(
			"Plank,Ramp_Walk,Ramp_Walk,body_and_cushion,head_with_beard,left_arm,legs_and_boots,nightcap"
		)
	end)

	it("never lists a part marked RightArmRest, even inside left_arm", function()
		local scene = newScene()
		local giant = scene.world:FindFirstChild("Giant") :: Instance
		local leftArm = giant:FindFirstChild("left_arm") :: Instance
		local marked = add(leftArm, "RestingArm", Vector3.new(10, 10, 10), Vector3.new(80, 0, 20))
		marked:SetAttribute("RightArmRest", true)
		local list = SlamFx.huggableParts(Workspace, scene.world)
		expect(table.find(list, marked)).toBeNil()
		expect(table.find(list, leftArm:FindFirstChild("left_arm") :: Instance)).never.toBeNil() -- the unmarked arm part stays on the list
	end)

	it("lists single parts, never the Bridges or WalkSurfaces folders or the Giant", function()
		local scene = newScene()
		for _, instance in SlamFx.huggableParts(Workspace, scene.world) do
			expect(instance:IsA("BasePart")).toBe(true)
		end
	end)

	it("builds its list once for each refresh, not for each ray", function()
		local scene = newScene()
		expect(hitHeight(scene, 160)).never.toBeNil()
		local newPlank = add(scene.bridge, "Plank", Vector3.new(10, 1, 10), Vector3.new(280, 4.5, 0))
		expect(newPlank.CanCollide).toBe(true)
		expect(hitHeight(scene, 280)).toBeNil() -- a bridge that streamed in since the list was made is not on it yet
		scene.refresh()
		expect(hitHeight(scene, 280)).never.toBeNil()
	end)

	it("builds the list at the first ray when it was never refreshed", function()
		local world = newWorld()
		local bridge = modelIn(folderIn(world, "Bridges"), "PlankBridge_1")
		add(bridge, "Plank", Vector3.new(10, 1, 10), Vector3.new(0, 4.5, 0))
		local cast = SlamFx.workspaceCastHug(Workspace, world)
		local position = cast(ORIGIN + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0))
		expect(position).never.toBeNil()
	end)

	it("copes with a world that has no Giant, WalkSurfaces or Bridges", function()
		local world = newWorld()
		local list = SlamFx.huggableParts(Workspace, world)
		expect(#list).toBe(1) -- the Terrain
	end)

	it("sets the ray up to see only collidable parts, on a list, and to see water", function()
		local seen: { RaycastParams } = {}
		local fakeWorkspace: any = {
			Terrain = Workspace.Terrain,
			Raycast = function(_self: any, _origin: Vector3, _direction: Vector3, params: RaycastParams)
				table.insert(seen, params)
				return nil
			end,
		}
		local world = newWorld()
		local cast = SlamFx.workspaceCastHug(fakeWorkspace, world)
		cast(Vector3.zero, Vector3.new(0, -1, 0))
		expect(seen[1].FilterType).toBe(Enum.RaycastFilterType.Include)
		expect(seen[1].RespectCanCollide).toBe(true)
		expect(seen[1].IgnoreWater).toBe(false)
	end)
end)

describe("SlamFx.workspaceSurfaceNormal", function()
	-- A tilted floor far away from anything else, and a tool that lists the players' characters.
	local function newSlope(): Part
		local floor = made(Instance.new("Part"))
		floor.Anchored = true
		floor.Size = Vector3.new(60, 2, 60)
		floor.CFrame = CFrame.new(2000, 0, 2000) * CFrame.Angles(0, 0, math.rad(20))
		floor.Parent = Workspace
		return floor
	end

	local noPlayers: any = {
		GetPlayers = function(_self: any)
			return {}
		end,
	}

	it("gives the normal of the surface just under the point", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0)) -- the middle of the top face
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("gives straight up when nothing is under the point", function()
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(Vector3.new(5000, 0, 5000)), UP)
	end)

	it("goes through a part that can't be collided with, such as a bush", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0))
		local bush = made(Instance.new("Part"))
		bush.Anchored = true
		bush.CanCollide = false
		bush.Size = Vector3.new(6, 1, 6)
		bush.CFrame = CFrame.new(point + Vector3.new(0, 0.3, 0))
		bush.Parent = Workspace
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("goes through a part marked RightArmRest and gives the floor under it", function()
		local floor = made(Instance.new("Part"))
		floor.Anchored = true
		floor.Size = Vector3.new(60, 2, 60)
		floor.CFrame = CFrame.new(4000, 0, 4000) -- level, its top face at y = 1
		floor.Parent = Workspace
		local arm = made(Instance.new("Part"))
		arm.Anchored = true
		arm.Size = Vector3.new(20, 0.5, 20)
		arm.CFrame = CFrame.new(4000, 1.5, 4000) * CFrame.Angles(0, 0, math.rad(30)) -- tilted, just over the floor
		arm:SetAttribute("RightArmRest", true)
		arm.Parent = Workspace
		local point = Vector3.new(4000, 1, 4000)
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(point), UP, 1e-3)
	end)

	it("goes through every player's character", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0))
		local character = made(Instance.new("Model"))
		local body = Instance.new("Part")
		body.Anchored = true
		body.Size = Vector3.new(6, 0.5, 6)
		body.CFrame = CFrame.new(point + Vector3.new(0, 0.5, 0)) -- level, so a hit would give straight up
		body.Parent = character
		character.Parent = Workspace
		local players: any = {
			GetPlayers = function(_self: any)
				local list: { any } = { { Character = character }, { Character = nil } }
				return list
			end,
		}
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, players, made(Instance.new("Folder")))
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("goes through SlamFx's own folder", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0))
		local folder = made(Instance.new("Folder"))
		folder.Name = "SlamFx"
		folder.Parent = Workspace
		local disc = Instance.new("Part")
		disc.Anchored = true
		disc.Size = Vector3.new(6, 0.5, 6)
		disc.CFrame = CFrame.new(point + Vector3.new(0, 0.5, 0)) -- level, so a hit would give straight up
		disc.Parent = folder
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, Workspace)
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("starts one stud above the point and looks only two studs down", function()
		local calls: { { origin: Vector3, direction: Vector3 } } = {}
		local fakeWorkspace: any = {
			Raycast = function(_self: any, origin: Vector3, direction: Vector3, _params: RaycastParams)
				table.insert(calls, { origin = origin, direction = direction })
				return nil
			end,
		}
		local normalOf = SlamFx.workspaceSurfaceNormal(fakeWorkspace, noPlayers, made(Instance.new("Folder")))
		normalOf(Vector3.new(3, 4, 5))
		expect(#calls).toBe(1)
		expectNear(calls[1].origin, Vector3.new(3, 5, 5))
		expectNear(calls[1].direction, Vector3.new(0, -2, 0))
	end)

	it("only sees parts that can collide, and leaves out characters and the folder", function()
		local seen: { RaycastParams } = {}
		local fakeWorkspace: any = {
			Raycast = function(_self: any, _origin: Vector3, _direction: Vector3, params: RaycastParams)
				table.insert(seen, params)
				return nil
			end,
		}
		local character = made(Instance.new("Model"))
		local parent = made(Instance.new("Folder"))
		local folder = Instance.new("Folder")
		folder.Name = "SlamFx"
		folder.Parent = parent
		local players: any = {
			GetPlayers = function(_self: any)
				return { { Character = character } }
			end,
		}
		SlamFx.workspaceSurfaceNormal(fakeWorkspace, players, parent)(Vector3.zero)
		local params = seen[1]
		expect(params.RespectCanCollide).toBe(true)
		expect(params.FilterType).toBe(Enum.RaycastFilterType.Exclude)
		expect(table.find(params.FilterDescendantsInstances, character)).never.toBeNil()
		expect(table.find(params.FilterDescendantsInstances, folder)).never.toBeNil()
	end)
end)
