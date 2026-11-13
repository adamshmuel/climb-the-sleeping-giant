--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local PlayerNeeds = require(game:GetService("ServerStorage").Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
local SlideGuardHelpers = require(script.Parent.SlideGuardHelpers)
local BODY_PIECES = Helpers.BODY_PIECES
local BODY_SLOPE_RAY_ABOVE = Helpers.BODY_SLOPE_RAY_ABOVE
local BODY_SLOPE_RAY_LENGTH = Helpers.BODY_SLOPE_RAY_LENGTH
local bodySizeSlopeAtCloth = Helpers.bodySizeSlopeAtCloth
type Box = SlideGuardHelpers.Box
type Context = SlideGuardHelpers.Context
type Need = SlideGuardHelpers.Need
local GUARD_FOLDER = SlideGuardHelpers.GUARD_FOLDER
local guardCloseProblems = SlideGuardHelpers.guardCloseProblems
local guardLeanProblems = SlideGuardHelpers.guardLeanProblems
local guardProblems = SlideGuardHelpers.guardProblems

describe("the real world, slide guards", function()
	local Workspace = game:GetService("Workspace")

	local BUILD_TIMEOUT_MS = 60000 -- reading the seven meshes takes a few seconds
	local TEST_TIMEOUT_MS = 60000

	local BEARD_POCKET_BOXES: { Box } = {
		{ name = "beard pocket, left", min = Vector3.new(-9.8, 77.5, -14), max = Vector3.new(-3.8, 85.5, -8) },
		{ name = "beard pocket, right", min = Vector3.new(4.2, 73.3, -16), max = Vector3.new(12.2, 85.1, -8) },
	}

	-- The real world's inputs. The cloth is his six pieces and the pillow. The chair is part of the body_and_cushion mesh
	-- and the legs_and_boots mesh, so it is named by boxes: the chair's two sides, from the start list's "chair's side"
	-- groups and the plan's chair-arm boxes (t22/start-list-task23.md; plan Task 23, "the 10 small spots").
	-- PLACEHOLDER: these boxes are a guess, to be replaced in step 23-8b by boxes measured from the drawn mesh (seat, sides
	-- and arms only).
	local CHAIR_BOXES: { Box } = {
		{ name = "chair, right side", min = Vector3.new(14, 5, -10), max = Vector3.new(38, 22, 42) },
		{ name = "chair, left side", min = Vector3.new(-38, 5, -10), max = Vector3.new(-14, 22, 42) },
	}
	local function clothParts(world: Instance): { Instance }
		local parts: { Instance } = {}
		local giant = world:FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		for _, name in BODY_PIECES do
			local piece = (giant :: Instance):FindFirstChild(name)
			expect(piece).never.toBeNil()
			local mesh = (piece :: Instance):FindFirstChild(name)
			expect(mesh).never.toBeNil()
			table.insert(parts, mesh :: Instance)
		end
		local things = world:FindFirstChild("GiantsThings")
		local pillow = if things then things:FindFirstChild("Pillow") else nil
		local body = if pillow then pillow:FindFirstChild("body") else nil
		local geometry = if body then body:FindFirstChild("body_geom") else nil
		expect(geometry).never.toBeNil()
		table.insert(parts, geometry :: Instance)
		return parts
	end

	-- The Sock's mesh (World.GiantsThings.Sock.body.body_geom): the cloth and the drawn skin of the Sock's lip boards (Task 37).
	local function sockGeometry(world: Instance): MeshPart
		local things = world:FindFirstChild("GiantsThings")
		local sock = if things then things:FindFirstChild("Sock") else nil
		local body = if sock then sock:FindFirstChild("body") else nil
		local geometry = if body then body:FindFirstChild("body_geom") else nil
		expect(geometry).never.toBeNil()
		return geometry :: MeshPart
	end

	-- Every place players need and the seam: the one list in PlayerNeeds, which the stuck scan's rare-spot check reads too,
	-- plus spec 5's steep layer (not a need for the scan, but guards keep 2 studs from it: plan 2c).
	-- Both ladders' trusses must exist, so a missing ladder can't hide as a shorter list.
	local function realNeeds(world: Instance): { Need }
		local needs = PlayerNeeds.fromWorld(world)
		for _, steep in PlayerNeeds.steepLayer(world) do
			table.insert(needs, steep)
		end
		-- Plan 5 Task 19c: each nest's straw box (World.EggSpots.<nest>.Nest) is a place players need too.
		local eggSpots = world:FindFirstChild("EggSpots")
		if eggSpots ~= nil then
			for _, model in eggSpots:GetChildren() do
				local straw = model:FindFirstChild("Nest")
				if straw ~= nil and straw:IsA("BasePart") then
					table.insert(needs, PlayerNeeds.boxNeed(`nest straw {model.Name}`, straw))
				end
			end
		end
		local names: { [string]: boolean } = {}
		for _, need in needs do
			names[need.name] = true
		end
		for _, ladderName in { "BeardLadder", "CapLadder" } do
			expect(names[`{ladderName} foot`]).toBe(true)
			expect(names[`{ladderName} top`]).toBe(true)
		end
		return needs
	end

	it("slide guards stay off the walk area and out of players' way", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local cloth = clothParts(world :: Instance)
		local clothOnly = RaycastParams.new()
		clothOnly.FilterType = Enum.RaycastFilterType.Include
		clothOnly.FilterDescendantsInstances = cloth
		clothOnly.RespectCanCollide = false
		local sockMesh = sockGeometry(world :: Instance)
		local sockOnly = RaycastParams.new()
		sockOnly.FilterType = Enum.RaycastFilterType.Include
		sockOnly.FilterDescendantsInstances = { sockMesh }
		sockOnly.RespectCanCollide = false
		local context: Context = {
			world = Workspace,
			clothParams = clothOnly,
			slopeAt = function(point: Vector3, normal: Vector3): number?
				return bodySizeSlopeAtCloth(clothOnly, point, normal)
			end,
			clothNameAt = function(x: number, z: number): string?
				local hit = Workspace:Raycast(
					Vector3.new(x, BODY_SLOPE_RAY_ABOVE, z),
					Vector3.new(0, -BODY_SLOPE_RAY_LENGTH, 0),
					clothOnly
				)
				return if hit then hit.Instance.Name else nil
			end,
			chairBoxes = CHAIR_BOXES,
			beardPocketBoxes = BEARD_POCKET_BOXES,
			solids = cloth,
			needs = realNeeds(world :: Instance),
			-- The Sock's lip boards read the slope from a fan of rays along their face (Ruling 47), not from a slope reader.
			sock = { clothParams = sockOnly, solids = { sockMesh } },
		}
		local problems = guardProblems((walk :: Instance):FindFirstChild(GUARD_FOLDER), context)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, TEST_TIMEOUT_MS)

	it("slide guards lie close to what players see", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		-- What players see: his six pieces, the pillow, and any shirt folds (none until Task 26 adds them).
		local meshes: { MeshPart } = {}
		for _, mesh in clothParts(world :: Instance) do
			table.insert(meshes, mesh :: MeshPart)
		end
		local giant = (world :: Instance):FindFirstChild("Giant")
		local foldFolder = if giant then giant:FindFirstChild("ShirtFolds") else nil
		local folds: { BasePart } = {}
		if foldFolder ~= nil then
			for _, descendant in foldFolder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(folds, descendant)
				end
			end
		end
		local skin = DrawnSkin.fromWorld(meshes, folds)
		local sockSkin = DrawnSkin.fromWorld({ sockGeometry(world :: Instance) }, {})
		local guardFolder = (walk :: Instance):FindFirstChild(GUARD_FOLDER)
		local problems = guardCloseProblems(guardFolder, skin, sockSkin)
		-- Under knee height a Sock lip board is not read against the skin, so its foot may not lean out (Ruling 47).
		for _, problem in guardLeanProblems(guardFolder) do
			table.insert(problems, problem)
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, BUILD_TIMEOUT_MS + TEST_TIMEOUT_MS)

	-- Plan 5 Task 19c: the nests' straw boxes are places players need, so the slide guards keep clear of them.
	it("the slide guards' list of places holds every nest's straw box", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local spots = (world :: Instance):FindFirstChild("EggSpots")
		expect(spots).never.toBeNil()
		local names: { [string]: boolean } = {}
		for _, need in realNeeds(world :: Instance) do
			names[need.name] = true
		end
		local missing: { string } = {}
		local nests = 0
		for _, model in (spots :: Instance):GetChildren() do
			if model:IsA("Model") and model:FindFirstChild("Nest") ~= nil then
				nests += 1
				if not names[`nest straw {model.Name}`] then
					table.insert(missing, model.Name)
				end
			end
		end
		expect(nests).toBeGreaterThan(0)
		expect(missing).toEqual({})
	end)
end)
