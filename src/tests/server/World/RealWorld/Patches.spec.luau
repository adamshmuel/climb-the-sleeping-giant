--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local Helpers = require(script.Parent.Helpers)
type Face = Helpers.Face
local ABOVE_LIMIT = Helpers.ABOVE_LIMIT
local BELOW_LIMIT = Helpers.BELOW_LIMIT
local BODY_PIECES = Helpers.BODY_PIECES
local SKIN_SEARCH_ABOVE = Helpers.SKIN_SEARCH_ABOVE
local SMALL_PATCHES_FOLDER = Helpers.SMALL_PATCHES_FOLDER
local describePoint = Helpers.describePoint
local facesOf = Helpers.facesOf
local inFakeWorld = Helpers.inFakeWorld
local outsideLimits = Helpers.outsideLimits
local sidewaysFit = Helpers.sidewaysFit
local startsWith = Helpers.startsWith

-- Stuck safety Task 22, test 3 (docs/plans/v2/stuck-safety.md, "Ruling 4: flush for a filled pocket"): the patches are
-- invisible solid blocks in World.WalkSurfaces.Patches that fill the cracks and pockets in his shape. A patch inside a
-- sealed pocket has no surface a player can reach, so the check measures only what a player can reach:
--   Folder:   the folder exists and holds at least one patch.
--   Settings: every patch has the settings of V1's steep guards.
--   Tops:     wherever a ray straight down meets a patch first, that point is within check 6's limits of his drawn skin.
--   Sides:    no ray from 3 studs outside a side face, toward the face, meets the patch first. Rays that start under the
--             grass don't count.
-- The checker is a function over a world, a folder and a drawn skin, so two made-up worlds can prove it bites.
describe("the real world, the patches", function()
	local Workspace = game:GetService("Workspace")

	-- The steep guards' settings, measured in step 22-0 (all 30 guards are identical). A patch is a Part or a WedgePart.
	local GUARD_TRANSPARENCY = 1 -- measured in step 22-0
	local GUARD_CAN_COLLIDE = true -- measured in step 22-0
	local GUARD_CAN_QUERY = true -- measured in step 22-0
	local GUARD_CAN_TOUCH = false -- measured in step 22-0
	local GUARD_CAST_SHADOW = false -- measured in step 22-0
	local GUARD_MATERIAL = Enum.Material.SmoothPlastic -- measured in step 22-0
	local GUARD_COLLISION_GROUP = "Default" -- measured in step 22-0
	local GUARD_ANCHORED = true -- measured in step 22-0
	local GUARD_ARCHIVABLE = true -- measured in step 22-0

	-- Check 6's limits and its sideways search (outsideLimits, sidewaysFit) are the ones at the top of this file.

	local GRID_STEP = 1 -- studs: the rays are this far apart over each face
	local RAY_OUTSIDE = 3 -- studs: a ray starts this far above a top, or outside a side
	local RAY_MARGIN = 0.5 -- studs: ...and reaches this far past the face
	local MIN_TOP_NORMAL = 0.1 -- a face counts as a top only when it faces up at least this much
	local PROBE_SIZE = 0.2 -- studs: the ball that tests whether a side ray starts inside a solid
	local GRASS_RAY_ABOVE = 500 -- studs: the grass is found by a ray down from this far over the start of a side ray
	local PROBE_NAME = "PatchSideProbe"
	-- The scan's body (Config.Stuck, and PathCheck's lift): a box BODY_WIDTH wide and deep that starts BODY_LIFT above the
	-- feet and ends BODY_HEIGHT above them. A top counts only where this body has room to stand on it. A side ray counts
	-- only where this body has room to stand beside the face, with the face point at the bottom, middle or top of the box.
	local BODY_WIDTH = Config.Stuck.BodyWidth -- studs
	local BODY_HEIGHT = Config.Stuck.BodyHeight -- studs: from the feet to the top of the head
	local BODY_LIFT = 0.5 -- studs: PathCheck's lift of the box above the feet (a player steps over less than that)
	local FOOT_GAP = 0.1 -- studs: a foot beside a face is this far past half a body's width from it
	local POINT_FROM_BOX_END = 0.6 -- studs: the face point is this far inside the box's bottom, or its top
	local MIN_FLAT_SIDE = 1e-3 -- a face whose outward direction is flatter than this has no sideways direction
	local BOX_HEIGHT = BODY_HEIGHT - BODY_LIFT
	local POINT_ABOVE_BOX_BOTTOM = { POINT_FROM_BOX_END, BOX_HEIGHT / 2, BOX_HEIGHT - POINT_FROM_BOX_END }
	local EXAMPLES_SHOWN = 3 -- most points written out for each problem line
	local BUILD_TIMEOUT_MS = 60000 -- reading the six meshes takes a few seconds
	local TEST_TIMEOUT_MS = 60000

	-- The points of a 1-stud grid over a face, in world space.
	local function gridOver(patch: BasePart, face: Face): { Vector3 }
		local points: { Vector3 } = {}
		local uCount = math.max(1, math.round(2 * face.uHalf / GRID_STEP))
		local vCount = math.max(1, math.round(2 * face.vHalf / GRID_STEP))
		for i = 1, uCount do
			for j = 1, vCount do
				local u = ((i - 0.5) / uCount * 2 - 1) * face.uHalf
				local v = ((j - 0.5) / vCount * 2 - 1) * face.vHalf
				table.insert(points, patch.CFrame:PointToWorldSpace(face.center + face.u * u + face.v * v))
			end
		end
		return points
	end

	local function describeDirection(direction: Vector3): string
		return string.format("(%.0f, %.0f, %.0f)", direction.X, direction.Y, direction.Z)
	end

	-- Whether a body fits standing beside a face. Three feet are tried: each is the face point moved out along the face's
	-- flat outward direction, and lowered so that the point is near the bottom, the middle or the top of the body box.
	local function bodyFitsBeside(options: PathCheck.Options, point: Vector3, outward: Vector3): boolean
		local flat = Vector3.new(outward.X, 0, outward.Z)
		local away = if flat.Magnitude > MIN_FLAT_SIDE then flat.Unit else outward
		local beside = point + away * (BODY_WIDTH / 2 + FOOT_GAP)
		for _, above in POINT_ABOVE_BOX_BOTTOM do
			local feet = Vector3.new(beside.X, point.Y - BODY_LIFT - above, beside.Z)
			if PathCheck.roomToStand(options, feet) then
				return true
			end
		end
		return false
	end

	-- The checker. Returns its problems as sentences, each starting with the name of its rule; none means the patches
	-- pass. `world` is the Workspace, or a made-up WorldModel. A top counts only where a body can stand on it, and a side
	-- only where a body can stand beside it (see BODY_WIDTH). Use patchProblems, which cleans up when a check throws.
	-- `smallFolder` (Task 23, Ruling 11) is World.WalkSurfaces.SmallPatches: only its `Patch_<Place>_<n>` blocks are read
	-- like the patches; its `Ramp_<Place>_<n>` blocks have their own test.
	local SMALL_PATCH_PREFIX = "Patch_"
	local function runPatchChecks(
		world: WorldRoot,
		folder: Instance?,
		skin: DrawnSkin.Skin,
		smallFolder: Instance?
	): { string }
		-- (a) Folder
		local patches: { BasePart } = {}
		if folder ~= nil then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(patches, descendant)
				end
			end
		end
		if smallFolder ~= nil then
			for _, descendant in smallFolder:GetDescendants() do
				if
					descendant:IsA("BasePart")
					and string.sub(descendant.Name, 1, #SMALL_PATCH_PREFIX) == SMALL_PATCH_PREFIX
				then
					table.insert(patches, descendant)
				end
			end
		end
		if #patches == 0 then
			return { "Folder: World.WalkSurfaces.Patches is missing or holds no patch" }
		end

		local problems: { string } = {}
		-- The body rule's settings, made once per run (the body check keeps a probe of its own in the world).
		local options = PathCheck.defaults(world)
		-- A ray sees what a player bumps into.
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = Collisions.GROUP
		-- A ray that sees only the grass.
		local grassOnly = RaycastParams.new()
		grassOnly.FilterType = Enum.RaycastFilterType.Include
		grassOnly.FilterDescendantsInstances = { Workspace.Terrain }
		-- A small ball that is moved to the start of each side ray: a start inside a solid has nothing to reach the patch
		-- from, so that ray doesn't count. It is made once per run and destroyed at the end.
		local probe = Instance.new("Part")
		probe.Name = PROBE_NAME
		probe.Shape = Enum.PartType.Ball
		probe.Size = Vector3.one * PROBE_SIZE
		probe.Anchored = true
		probe.CanCollide = false
		probe.CanQuery = true
		probe.Archivable = false
		probe.Parent = world
		local insideCheck = OverlapParams.new()
		insideCheck.RespectCanCollide = true
		insideCheck.CollisionGroup = Collisions.GROUP
		insideCheck.FilterType = Enum.RaycastFilterType.Exclude
		insideCheck.FilterDescendantsInstances = { probe, folder :: Instance }

		for _, patch in patches do
			-- (b) Settings
			local wrong: { string } = {}
			if not (patch.ClassName == "Part" or patch.ClassName == "WedgePart") then
				table.insert(wrong, `class {patch.ClassName}`)
			end
			if patch.Transparency ~= GUARD_TRANSPARENCY then
				table.insert(wrong, `Transparency {patch.Transparency}`)
			end
			if patch.CanCollide ~= GUARD_CAN_COLLIDE then
				table.insert(wrong, `CanCollide {patch.CanCollide}`)
			end
			if patch.CanQuery ~= GUARD_CAN_QUERY then
				table.insert(wrong, `CanQuery {patch.CanQuery}`)
			end
			if patch.CanTouch ~= GUARD_CAN_TOUCH then
				table.insert(wrong, `CanTouch {patch.CanTouch}`)
			end
			if patch.CastShadow ~= GUARD_CAST_SHADOW then
				table.insert(wrong, `CastShadow {patch.CastShadow}`)
			end
			if patch.Material ~= GUARD_MATERIAL then
				table.insert(wrong, `Material {patch.Material.Name}`)
			end
			if patch.CollisionGroup ~= GUARD_COLLISION_GROUP then
				table.insert(wrong, `CollisionGroup {patch.CollisionGroup}`)
			end
			if patch.Anchored ~= GUARD_ANCHORED then
				table.insert(wrong, `Anchored {patch.Anchored}`)
			end
			if patch.Archivable ~= GUARD_ARCHIVABLE then
				table.insert(wrong, `Archivable {patch.Archivable}`)
			end
			if #wrong > 0 then
				table.insert(
					problems,
					`Settings: {patch.Name} differs from the steep guards: {table.concat(wrong, ", ")}`
				)
			end

			-- The top face faces up the most, the bottom face the least; the others are sides.
			local faces = facesOf(patch)
			local topIndex, bottomIndex = 1, 1
			for index, face in faces do
				local up = patch.CFrame:VectorToWorldSpace(face.normal).Y
				if up > patch.CFrame:VectorToWorldSpace(faces[topIndex].normal).Y then
					topIndex = index
				end
				if up < patch.CFrame:VectorToWorldSpace(faces[bottomIndex].normal).Y then
					bottomIndex = index
				end
			end

			-- (c) Tops
			local topNormal = patch.CFrame:VectorToWorldSpace(faces[topIndex].normal)
			if topNormal.Y >= MIN_TOP_NORMAL then
				local met, bad = 0, 0
				local examples: { string } = {}
				for _, point in gridOver(patch, faces[topIndex]) do
					local hit = world:Raycast(
						point + Vector3.new(0, RAY_OUTSIDE, 0),
						Vector3.new(0, -(RAY_OUTSIDE + RAY_MARGIN), 0),
						params
					)
					if
						hit ~= nil
						and hit.Instance == patch
						and PathCheck.roomToStand(options, hit.Position, hit.Normal)
					then
						met += 1
						local drawn = skin.heightAt(hit.Position.X, hit.Position.Z, hit.Position.Y + SKIN_SEARCH_ABOVE)
						local gap = if drawn == nil then 0 / 0 else hit.Position.Y - drawn
						if
							outsideLimits(gap)
							and sidewaysFit(skin, hit.Position.X, hit.Position.Z, hit.Position.Y) == nil
						then
							bad += 1
							if #examples < EXAMPLES_SHOWN then
								local gapText = if gap ~= gap
									then "no drawn skin under it"
									else string.format("%+.2f", gap)
								table.insert(examples, `{describePoint(hit.Position)} {gapText}`)
							end
						end
					end
				end
				if bad > 0 then
					table.insert(
						problems,
						`Tops: {patch.Name}: {bad} of {met} points a player can reach are not within {ABOVE_LIMIT} over or {BELOW_LIMIT} under his drawn skin, such as {table.concat(
							examples,
							", "
						)}`
					)
				end
			end

			-- (d) Sides
			for index, face in faces do
				if index ~= topIndex and index ~= bottomIndex then
					local outward = patch.CFrame:VectorToWorldSpace(face.normal)
					local met, total = 0, 0
					local examples: { string } = {}
					for _, point in gridOver(patch, face) do
						local start = point + outward * RAY_OUTSIDE
						local grass = world:Raycast(
							start + Vector3.new(0, GRASS_RAY_ABOVE, 0),
							Vector3.new(0, -GRASS_RAY_ABOVE - 1000, 0),
							grassOnly
						)
						probe.Position = start
						local insideSolid = #world:GetPartsInPart(probe, insideCheck) > 0
						-- a start under the grass or inside a solid doesn't count
						if not insideSolid and (grass == nil or grass.Position.Y <= start.Y) then
							total += 1
							local hit = world:Raycast(start, -outward * (RAY_OUTSIDE + RAY_MARGIN), params)
							if hit ~= nil and hit.Instance == patch and bodyFitsBeside(options, point, outward) then
								met += 1
								if #examples < EXAMPLES_SHOWN then
									table.insert(examples, describePoint(hit.Position))
								end
							end
						end
					end
					if met > 0 then
						table.insert(
							problems,
							`Sides: {patch.Name}, the side facing {describeDirection(outward)}: {met} of {total} rays from {RAY_OUTSIDE} studs outside meet the patch first, with room for a body beside it, such as {table.concat(
								examples,
								", "
							)}`
						)
					end
				end
			end
		end
		probe:Destroy()
		PathCheck.cleanup(options)
		return problems
	end

	-- runPatchChecks, with its two probes (this one's ball and the body check's box) taken out of the world even when a
	-- check throws.
	local function patchProblems(
		world: WorldRoot,
		folder: Instance?,
		skin: DrawnSkin.Skin,
		smallFolder: Instance?
	): { string }
		local ok, result = pcall(runPatchChecks, world, folder, skin, smallFolder)
		if not ok then
			for _, child in world:GetChildren() do
				if child.Name == PROBE_NAME then
					child:Destroy()
				end
			end
			PathCheck.cleanup(PathCheck.defaults(world))
			error(result, 0)
		end
		return result
	end

	-- A flat drawn skin at height 10 made of two triangles, 40 studs square.
	local function flatSkin(): DrawnSkin.Skin
		local a, b = Vector3.new(-20, 10, -20), Vector3.new(20, 10, -20)
		local c, d = Vector3.new(20, 10, 20), Vector3.new(-20, 10, 20)
		return DrawnSkin.new({ { a = a, b = b, c = c }, { a = a, b = c, c = d } }, {})
	end

	-- A patch with the steep guards' settings, in a folder inside the world (Patches, or `folderName`).
	local function addPatch(
		world: WorldModel,
		name: string,
		position: Vector3,
		size: Vector3,
		folderName: string?
	): Part
		local wanted = folderName or "Patches"
		local folder: Instance? = world:FindFirstChild(wanted)
		if folder == nil then
			local made = Instance.new("Folder")
			made.Name = wanted
			made.Parent = world
			folder = made
		end
		local patch = Instance.new("Part")
		patch.Name = name
		patch.Size = size
		patch.Position = position
		patch.Transparency = GUARD_TRANSPARENCY
		patch.CanCollide = GUARD_CAN_COLLIDE
		patch.CanQuery = GUARD_CAN_QUERY
		patch.CanTouch = GUARD_CAN_TOUCH
		patch.CastShadow = GUARD_CAST_SHADOW
		patch.Material = GUARD_MATERIAL
		patch.CollisionGroup = GUARD_COLLISION_GROUP
		patch.Anchored = GUARD_ANCHORED
		patch.Archivable = GUARD_ARCHIVABLE
		patch.Parent = folder
		return patch
	end

	local function addWall(world: WorldModel, position: Vector3, size: Vector3)
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Size = size
		wall.Position = position
		wall.Anchored = true
		wall.CanCollide = true
		wall.Parent = world
	end

	it("the patch check names a block that stands up in the open", function()
		inFakeWorld(function(world)
			addPatch(world, "Patch_Test_1", Vector3.new(0, 10, 0), Vector3.new(4, 2, 4)) -- its top is at height 11
			local problems = patchProblems(world, world:FindFirstChild("Patches"), flatSkin())
			local tops = startsWith(problems, "Tops:")
			expect(#tops).toBe(1)
			expect((string.find(tops[1], "Patch_Test_1", 1, true))).never.toBeNil()
		end)
	end)

	it("the patch check names only the open side of a block sunk under the skin", function()
		inFakeWorld(function(world)
			-- Its top is at height 9.9, 0.1 under the skin: fine. Walls touch three of its four sides.
			addPatch(world, "Patch_Test_2", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4))
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6)) -- the -X side
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6)) -- the +X side
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1)) -- the -Z side
			local problems = patchProblems(world, world:FindFirstChild("Patches"), flatSkin())
			expect(#startsWith(problems, "Tops:")).toBe(0)
			local sides = startsWith(problems, "Sides:")
			expect(#sides).toBe(1)
			expect((string.find(sides[1], "(0, 0, 1)", 1, true))).never.toBeNil() -- the +Z side, the one left open
			expect(#problems).toBe(1)
		end)
	end)

	it("the patch check ignores side rays that start inside a solid", function()
		inFakeWorld(function(world)
			-- The same block under the skin and the same three walls...
			addPatch(world, "Patch_Test_3", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4))
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1))
			-- ...and a solid 4 studs thick on the +Z side, so every side ray on that face starts inside it.
			addWall(world, Vector3.new(0, 9, 4), Vector3.new(4, 6, 4))
			expect(patchProblems(world, world:FindFirstChild("Patches"), flatSkin())).toEqual({})
		end)
	end)

	it("the patch check skips a top no body can stand on", function()
		inFakeWorld(function(world)
			-- The first test's block: its top is at height 11, in the open...
			addPatch(world, "Patch_Test_4", Vector3.new(0, 10, 0), Vector3.new(4, 2, 4))
			-- ...under a ceiling 3 studs thick. Its underside (12.5) is 1.5 over the block's top, and it reaches 1 stud
			-- past the block on every side. A body is taller than 1.5, so none stands on the block, and every top ray
			-- starts inside the ceiling.
			addWall(world, Vector3.new(0, 14, 0), Vector3.new(6, 3, 6))
			local problems = patchProblems(world, world:FindFirstChild("Patches"), flatSkin())
			expect(#startsWith(problems, "Tops:")).toBe(0)
		end)
	end)

	it("the patch check skips a side no body can touch", function()
		inFakeWorld(function(world)
			-- The second test's block under the skin and its three walls...
			addPatch(world, "Patch_Test_5", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4)) -- top 9.9, bottom 7.9
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1))
			-- ...and on the open +Z side a floor (top at the block's bottom, 7.9) and a ceiling (underside 0.1 over the
			-- block's top, 10). Both reach 6 studs out and are 6 wide, 1 stud wider than the block on each side. The slot
			-- between them is 2.1 tall: too low for a body to stand in or beside.
			addWall(world, Vector3.new(0, 7.4, 5), Vector3.new(6, 1, 6))
			addWall(world, Vector3.new(0, 10.5, 5), Vector3.new(6, 1, 6))
			expect(patchProblems(world, world:FindFirstChild("Patches"), flatSkin())).toEqual({})
		end)
	end)

	it("the patch check counts a neighbouring patch as solid", function()
		inFakeWorld(function(world)
			-- Two blocks, side by side, 0.1 under the skin. They share a face at x = 0.
			addPatch(world, "Patch_Test_6", Vector3.new(-2, 8.9, 0), Vector3.new(4, 2, 4))
			addPatch(world, "Patch_Test_7", Vector3.new(2, 8.9, 0), Vector3.new(4, 2, 4))
			-- Walls close their outer sides: -X, +X, and one long wall each on -Z and +Z.
			addWall(world, Vector3.new(-4.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(4.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(10, 6, 1))
			addWall(world, Vector3.new(0, 9, 2.5), Vector3.new(10, 6, 1))
			expect(patchProblems(world, world:FindFirstChild("Patches"), flatSkin())).toEqual({})
		end)
	end)

	-- Task 23 (Ruling 11): World.WalkSurfaces.SmallPatches holds Task 23's flush patches (`Patch_<Place>_<n>`, read here
	-- like the patches of Task 22) and its ramps on meadow props (`Ramp_<Place>_<n>`, read by their own test below).
	it("the patch check also reads the Patch_ blocks of the small patches folder", function()
		inFakeWorld(function(world)
			addPatch(world, "Patch_Test_8", Vector3.new(0, 10, 0), Vector3.new(4, 2, 4), SMALL_PATCHES_FOLDER) -- top at height 11
			local problems = patchProblems(world, nil, flatSkin(), world:FindFirstChild(SMALL_PATCHES_FOLDER))
			local tops = startsWith(problems, "Tops:")
			expect(#tops).toBe(1)
			expect((string.find(tops[1], "Patch_Test_8", 1, true))).never.toBeNil()
		end)
	end)

	it("the patch check leaves a Ramp_ block of the small patches folder alone", function()
		inFakeWorld(function(world)
			-- The sealed block of the third test, in Patches, with its four walls: it passes.
			addPatch(world, "Patch_Test_3", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4))
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1))
			addWall(world, Vector3.new(0, 9, 4), Vector3.new(4, 6, 4))
			-- A ramp in the open in SmallPatches would fail Tops if it were read.
			addPatch(world, "Ramp_Test_1", Vector3.new(12, 10, 12), Vector3.new(4, 2, 4), SMALL_PATCHES_FOLDER)
			local problems = patchProblems(
				world,
				world:FindFirstChild("Patches"),
				flatSkin(),
				world:FindFirstChild(SMALL_PATCHES_FOLDER)
			)
			expect(problems).toEqual({})
		end)
	end)

	it("patches sit on his drawn skin, or are sealed inside him", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walkSurfaces = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walkSurfaces).never.toBeNil()
		local giant = (world :: Instance):FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local meshes: { MeshPart } = {}
		for _, name in BODY_PIECES do
			local piece = (giant :: Instance):FindFirstChild(name)
			expect(piece).never.toBeNil()
			table.insert(meshes, (piece :: Instance):FindFirstChild(name) :: MeshPart)
		end
		local skin = DrawnSkin.fromWorld(meshes, {})
		local problems = patchProblems(
			Workspace,
			(walkSurfaces :: Instance):FindFirstChild("Patches"),
			skin,
			(walkSurfaces :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER)
		)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, BUILD_TIMEOUT_MS + TEST_TIMEOUT_MS)
end)
