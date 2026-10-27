--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local Helpers = require(script.Parent.Helpers)
local SlideGuardHelpers = require(script.Parent.SlideGuardHelpers)
local SMALL_PATCHES_FOLDER = Helpers.SMALL_PATCHES_FOLDER
local describePoint = Helpers.describePoint
local inFakeWorld = Helpers.inFakeWorld
local startsWith = Helpers.startsWith
local GUARD_FOLDER = SlideGuardHelpers.GUARD_FOLDER
local fakeFolder = SlideGuardHelpers.fakeFolder

describe("the real world, slide guards", function()
	local Workspace = game:GetService("Workspace")

	-- Test 6 (Task 23): every place where a player hung in Climbing on foot has its fix. A hang place is fixed in one of
	-- two ways, as code_lead ruled after step 23-6 (decision 2 and its notch ruling):
	--   "patch": the hang root lies inside a part of World.WalkSurfaces.SmallPatches named <prefix><n> (a sealed fill);
	--   "guard": the root hangs in the air beside a face, so a ray down from above it would hit the ground. Instead, 8 flat
	--   rays (every 45 degrees) go out from the root up to HANG_FACE_REACH studs, ignoring the guards; the nearest hit on
	--   the part named `face` is the face point. A ray from the root to that face point must then hit a part of
	--   World.WalkSurfaces.SlideGuards before the face (code_lead's ruling after step 23-7, point 4).
	-- Later hang places (from the steep-spot batches in step 23-15) join the list by a ruling, one Edit each.
	local HANG_FACE_REACH = 3 -- studs: the flat rays look this far out from a hang root
	local HANG_FACE_DIRECTIONS = 8 -- how many flat directions they cover, evenly round
	local HANG_FACE_RAY_STRETCH = 1.05 -- the root-to-face ray looks 5% past the face point, so a face hit at the point still counts
	type HangPlace = { name: string, kind: "patch" | "guard", root: Vector3, prefix: string, face: string? }
	local NOTCH_PATCH_PREFIX = "Patch_Notch_"
	local FOREHEAD_PATCH_PREFIX = "Patch_Forehead_"
	local SOCK_PATCH_PREFIX = "Patch_Sock_"
	-- Task 34: the forehead band's fill (Task 29's try T6) came out again, because it stood where players walk along his
	-- skin (code_lead's Rulings 30 and 31). The forehead hang place has no test here until Task 33 brings the fill back.
	-- Where the characters ended up hanging (steps 23-5 and 23-6, Play on the computer): the five notch walks W03, W04,
	-- W08, W09 and W14, and the pillow's spot 1 (35.2, 75.4, 65) after its slide down the +x/+z face. Spots 2 and 3 of
	-- the pillow never hung and get no fix.
	local HANG_PLACES: { HangPlace } = {
		{ name = "notch, walk 3", kind = "patch", root = Vector3.new(-5.3, 21.7, 39.1), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 4", kind = "patch", root = Vector3.new(2.3, 22.6, 39.8), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 8", kind = "patch", root = Vector3.new(-5.3, 21.6, 39.0), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 9", kind = "patch", root = Vector3.new(2.6, 22.6, 39.8), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 14", kind = "patch", root = Vector3.new(-1.1, 22.2, 39.7), prefix = NOTCH_PATCH_PREFIX },
		-- Task 32: the Sock's open spot (-68.8, 4.4, -45) (stuck scan, test 2's Sock box). It lies inside Patch_Sock_10 of the
		-- chosen fill (rank 1 of work/t32/cands-2b.txt: x -75.625 to -66.125, y 3.643 to 10.299, z -45.125 to -44.875).
		{ name = "Sock", kind = "patch", root = Vector3.new(-68.8, 4.4, -45), prefix = SOCK_PATCH_PREFIX },
		-- Task 37: the Sock's lips and gaps (the boards and boxes of work/t36/cands.txt, "board|2|" rows).
		{
			name = "Sock, west lip",
			kind = "guard",
			-- Task 35's hang table, "Scrape walk going +x, run 1"
			root = Vector3.new(-76.61, 5.42, -42.13),
			prefix = "",
			face = "body_geom", -- the Sock's mesh part (World.GiantsThings.Sock.body.body_geom)
		},
		{
			name = "Sock, east lip",
			kind = "guard",
			-- Task 35's hang table, "Walk into the fill's east end, run 1"
			root = Vector3.new(-64.65, 5.21, -43.37),
			prefix = "",
			face = "body_geom",
		},
		-- Inside Patch_Sock_20, in the gap under the west ledge (work/t35/results-35-1.txt, rows Ws1 and Ws2).
		{ name = "Sock, west gap", kind = "patch", root = Vector3.new(-77.0, 3.0, -44.0), prefix = SOCK_PATCH_PREFIX },
		-- Inside Patch_Sock_23, in the open cave under the east ledge (work/t35/results-35-1.txt, row E1a).
		{ name = "Sock, east gap", kind = "patch", root = Vector3.new(-64.75, 3.0, -45.1), prefix = SOCK_PATCH_PREFIX },
		-- Task 39's hang start (step 39-3), moved 0.5 studs into Patch_Sock_25 so the turned corner boxes have a red-first test.
		{
			name = "Sock, west corner",
			kind = "patch",
			root = Vector3.new(-76.5, 7.03, -49.0),
			prefix = SOCK_PATCH_PREFIX,
		},
		{
			name = "pillow spot 1",
			kind = "guard",
			root = Vector3.new(42.0, 45.8, 72.2),
			prefix = "",
			face = "body_geom", -- the pillow's mesh part (World.GiantsThings.Pillow.body.body_geom)
		},
	}

	-- Whether a point is inside a block or a wedge (the sloped half only). Any other shape counts as not inside: a patch
	-- of another shape can't be proven to hold the point.
	local function pointInsidePart(part: BasePart, point: Vector3): boolean
		local isBlock = part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Block)
		if not isBlock then
			return false
		end
		local at = part.CFrame:PointToObjectSpace(point)
		local half = part.Size / 2
		if math.abs(at.X) > half.X or math.abs(at.Y) > half.Y or math.abs(at.Z) > half.Z then
			return false
		end
		if part:IsA("WedgePart") then
			-- The sloped face runs from the bottom front edge (-y, -z) up to the top back edge (+y, +z), facing up and
			-- toward -z (the same face as `facesOf` draws). The solid half is under it.
			local slopeNormal = Vector3.new(0, part.Size.Z, -part.Size.Y)
			return slopeNormal:Dot(at - Vector3.new(0, -half.Y, -half.Z)) <= 0
		end
		return true
	end

	-- One line per hang place that has no fix. `guards` and `patches` are the two folders (nil when missing); `world` is
	-- the world the ray looks in.
	local function hangPlaceProblems(
		places: { HangPlace },
		guards: Instance?,
		patches: Instance?,
		world: WorldRoot
	): { string }
		local problems: { string } = {}
		-- A ray sees what a player bumps into.
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = Collisions.GROUP
		for _, place in places do
			if place.kind == "patch" then
				local fixed = false
				if patches ~= nil then
					for _, child in patches:GetChildren() do
						if
							child:IsA("BasePart")
							and string.sub(child.Name, 1, #place.prefix) == place.prefix
							and pointInsidePart(child, place.root)
						then
							fixed = true
							break
						end
					end
				end
				if not fixed then
					table.insert(
						problems,
						`Patch: {place.name} at {describePoint(place.root)} is not inside a part named {place.prefix}<n> in {SMALL_PATCHES_FOLDER}`
					)
				end
			else
				-- Step 1: find the face. The flat rays ignore the guards, so the face point is found whether or not a guard
				-- already stands there.
				local faceParams = RaycastParams.new()
				faceParams.RespectCanCollide = true
				faceParams.CollisionGroup = Collisions.GROUP
				if guards ~= nil then
					faceParams.FilterType = Enum.RaycastFilterType.Exclude
					faceParams.FilterDescendantsInstances = { guards }
				end
				local facePoint: Vector3? = nil
				local faceDistance = math.huge
				for index = 0, HANG_FACE_DIRECTIONS - 1 do
					local angle = index * 2 * math.pi / HANG_FACE_DIRECTIONS
					local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) * HANG_FACE_REACH
					local faceHit = world:Raycast(place.root, direction, faceParams)
					if faceHit ~= nil and faceHit.Instance.Name == place.face then
						local distance = (faceHit.Position - place.root).Magnitude
						if distance < faceDistance then
							faceDistance = distance
							facePoint = faceHit.Position
						end
					end
				end
				if facePoint == nil then
					table.insert(
						problems,
						`Guard: {place.name} at {describePoint(place.root)}: no face of a part named {place.face} within {HANG_FACE_REACH} studs`
					)
				else
					-- Step 2: a guard must stand between the root and the face point.
					local toFace = (facePoint - place.root) * HANG_FACE_RAY_STRETCH
					local hit = world:Raycast(place.root, toFace, params)
					if hit == nil then
						table.insert(
							problems,
							`Guard: {place.name}: a ray from {describePoint(place.root)} to the face at {describePoint(
								facePoint
							)} hits nothing, so no slide guard is there`
						)
					elseif guards == nil or not hit.Instance:IsDescendantOf(guards) then
						table.insert(
							problems,
							`Guard: {place.name}: a ray from {describePoint(place.root)} to the face at {describePoint(
								facePoint
							)} first hits {hit.Instance:GetFullName()}, not a part of {GUARD_FOLDER}`
						)
					end
				end
			end
		end
		return problems
	end

	local function fakePatchFolder(world: WorldModel): Folder
		local folder = Instance.new("Folder")
		folder.Name = SMALL_PATCHES_FOLDER
		folder.Parent = world
		return folder
	end

	-- A block patch 4 studs on every side, centred at the origin.
	local function addPatch(folder: Folder, name: string, wedge: boolean): BasePart
		local patch: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		patch.Name = name
		patch.Size = Vector3.new(4, 4, 4)
		patch.CFrame = CFrame.new(0, 0, 0)
		patch.Anchored = true
		patch.CanCollide = true
		patch.Parent = folder
		return patch
	end

	local function patchPlace(root: Vector3): HangPlace
		return { name = "made-up notch", kind = "patch", root = root, prefix = NOTCH_PATCH_PREFIX }
	end

	it("the hang place check passes a root inside a block patch with the right name", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", false)
			expect(hangPlaceProblems({ patchPlace(Vector3.new(1.5, -1.5, 1.5)) }, nil, patches, world)).toEqual({})
		end)
	end)

	it("the hang place check names a root outside every patch", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", false)
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(5, 0, 0)) }, nil, patches, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check names a root in the empty half of a wedge patch", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", true)
			-- A wedge is solid under its slope, which rises from the bottom front edge (-y, -z) to the top back edge
			-- (+y, +z): the top front corner is empty air.
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(0, 1.5, -1.5)) }, nil, patches, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check passes a root in the solid half of a wedge patch", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", true)
			expect(hangPlaceProblems({ patchPlace(Vector3.new(0, -1.5, 1.5)) }, nil, patches, world)).toEqual({})
		end)
	end)

	it("the hang place check names a root inside a patch with another name", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Other_1", false)
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(0, 0, 0)) }, nil, patches, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	-- A made-up pillow: a block named body_geom, 4 studs on every side, its -x face at x 1. The hang root sits at the
	-- origin, 1 stud out from that face, in the air.
	local FAKE_FACE_NAME = "body_geom"
	local function addFakePillow(parent: Instance, centre: Vector3): Part
		local pillow = Instance.new("Part")
		pillow.Name = FAKE_FACE_NAME
		pillow.Size = Vector3.new(4, 4, 4)
		pillow.Position = centre
		pillow.Anchored = true
		pillow.CanCollide = true
		pillow.Parent = parent
		return pillow
	end

	-- A thin guard board lying across the path from the root to the face, at x 0.6.
	local function addFakeGuard(parent: Instance, name: string, x: number): Part
		local board = Instance.new("Part")
		board.Name = name
		board.Size = Vector3.new(0.2, 4, 4)
		board.Position = Vector3.new(x, 0, 0)
		board.Anchored = true
		board.CanCollide = true
		board.Parent = parent
		return board
	end

	local function guardPlace(): HangPlace
		return {
			name = "made-up pillow",
			kind = "guard",
			root = Vector3.new(0, 0, 0),
			prefix = "",
			face = FAKE_FACE_NAME,
		}
	end

	it("the hang place check passes a root with a slide guard in front of the face", function()
		inFakeWorld(function(world)
			local guards = fakeFolder(world)
			addFakePillow(world, Vector3.new(3, 0, 0))
			addFakeGuard(guards, "SlideGuard_Fake_1", 0.6)
			expect(hangPlaceProblems({ guardPlace() }, guards, nil, world)).toEqual({})
		end)
	end)

	it(
		"the hang place check names a root whose face has no guard in front, even with a guard under the root",
		function()
			inFakeWorld(function(world)
				local guards = fakeFolder(world)
				addFakePillow(world, Vector3.new(3, 0, 0))
				-- A guard right under the root, where the old ray down would have found it, but not between root and face.
				addFakeGuard(guards, "SlideGuard_Fake_1", 0).Position = Vector3.new(0, -1, 0)
				local problems = hangPlaceProblems({ guardPlace() }, guards, nil, world)
				expect(#startsWith(problems, "Guard:")).toBe(1)
				expect(#problems).toBe(1)
			end)
		end
	)

	it("the hang place check names a root with no pillow face within reach", function()
		inFakeWorld(function(world)
			local guards = fakeFolder(world)
			addFakePillow(world, Vector3.new(30, 0, 0))
			addFakeGuard(guards, "SlideGuard_Fake_1", 0.6)
			local problems = hangPlaceProblems({ guardPlace() }, guards, nil, world)
			expect(#startsWith(problems, "Guard:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check names a guard buried behind the face", function()
		inFakeWorld(function(world)
			local guards = fakeFolder(world)
			addFakePillow(world, Vector3.new(3, 0, 0))
			addFakeGuard(guards, "SlideGuard_Fake_1", 2)
			local problems = hangPlaceProblems({ guardPlace() }, guards, nil, world)
			expect(#startsWith(problems, "Guard:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check names every place when both fix folders are missing", function()
		inFakeWorld(function(world)
			addFakePillow(world, Vector3.new(3, 0, 0))
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(0, 0, 0)), guardPlace() }, nil, nil, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#startsWith(problems, "Guard:")).toBe(1)
			expect(#problems).toBe(2)
		end)
	end)

	it("every known Climbing hang place has its fix", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local problems = hangPlaceProblems(
			HANG_PLACES,
			(walk :: Instance):FindFirstChild(GUARD_FOLDER),
			(walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER),
			Workspace
		)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("the forehead fill stays out until Task 33", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local smallFolder = (walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER)
		expect(smallFolder).never.toBeNil()
		local found: { string } = {}
		for _, child in (smallFolder :: Instance):GetChildren() do
			if string.sub(child.Name, 1, #FOREHEAD_PATCH_PREFIX) == FOREHEAD_PATCH_PREFIX then
				table.insert(found, child.Name)
			end
		end
		expect(found).toEqual({})
	end)
end)
