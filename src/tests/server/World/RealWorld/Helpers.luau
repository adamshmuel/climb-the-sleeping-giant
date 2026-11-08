--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local Workspace = game:GetService("Workspace")

-- Check 6's limits (stuck safety spec, Rule 20) and its sideways search, in one place. "his solid body sits where he's
-- drawn" and "the patches" both use them, so the two can never drift apart.
local ABOVE_LIMIT = 0.2 -- studs: a solid shape may be this far over his drawn skin...

local BELOW_LIMIT = 0.3 -- studs: ...and this far under it

local LIMIT_SLACK = 0.001 -- studs: rounding in the numbers written into the world

local SKIN_SEARCH_ABOVE = 1 -- studs: the drawn skin is read up to this far over the solid shape (not the skin of a floor above)

local SKIN_SIDE_REACH = 0.3 -- studs: the drawn skin is also read this far sideways of a point (never the solid shape)

local SKIN_SIDE_STEPS = 3 -- the sideways reads are SKIN_SIDE_REACH / SKIN_SIDE_STEPS = 0.1 studs apart, inside a circle

-- His slope at body size (designer's rule) is read by SlideProfile (plan 5 Task 15a), so "his slide line is the seam",
-- the slide-guard tests and the steep layer read it the same way.
local BODY_SLOPE_REACH = SlideProfile.BODY_SLOPE_REACH

local BODY_SLOPE_RAY_ABOVE = SlideProfile.BODY_SLOPE_RAY_ABOVE

local BODY_SLOPE_RAY_LENGTH = SlideProfile.BODY_SLOPE_RAY_LENGTH

local bodySizeSlopeAt = SlideProfile.bodySizeSlopeAt

-- Helpers the describe blocks below share. Each is written once, here.
local BODY_PIECES = { "legs_and_boots", "body_and_cushion", "left_arm", "right_arm", "head_with_beard", "nightcap" }

local SMALL_PATCHES_FOLDER = "SmallPatches" -- World.WalkSurfaces.SmallPatches (Task 23, decision 3)

local function describePoint(point: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", point.X, point.Y, point.Z)
end

-- A face of a patch in its own space: where its middle is, which way it faces, and the two directions it spreads in
-- with half its length in each.
export type Face = { center: Vector3, normal: Vector3, u: Vector3, uHalf: number, v: Vector3, vHalf: number }

-- The faces of a block (six) or a wedge (five: its bottom, back, two sides and sloped top), as DrawnSkin draws them.
local function facesOf(patch: BasePart): { Face }
	local half = patch.Size / 2
	local x, y, z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	local faces: { Face } = {
		{ center = -y * half.Y, normal = -y, u = x, uHalf = half.X, v = z, vHalf = half.Z },
		{ center = x * half.X, normal = x, u = y, uHalf = half.Y, v = z, vHalf = half.Z },
		{ center = -x * half.X, normal = -x, u = y, uHalf = half.Y, v = z, vHalf = half.Z },
		{ center = z * half.Z, normal = z, u = x, uHalf = half.X, v = y, vHalf = half.Y },
	}
	if patch:IsA("WedgePart") then
		local slope = Vector3.new(0, patch.Size.Y, patch.Size.Z)
		table.insert(faces, {
			center = Vector3.zero,
			normal = Vector3.new(0, patch.Size.Z, -patch.Size.Y).Unit,
			u = x,
			uHalf = half.X,
			v = slope.Unit,
			vHalf = slope.Magnitude / 2,
		})
	else
		table.insert(faces, { center = y * half.Y, normal = y, u = x, uHalf = half.X, v = z, vHalf = half.Z })
		table.insert(faces, { center = -z * half.Z, normal = -z, u = x, uHalf = half.X, v = y, vHalf = half.Y })
	end
	return faces
end

local UP_FACE_MIN = 0.001 -- a face counts as facing up when its up-direction is more than this

-- The points of a grid over a face, `step` studs apart at most, in world space.
local function pointsOver(guard: BasePart, face: Face, step: number): { Vector3 }
	local points: { Vector3 } = {}
	local uCount = math.max(1, math.ceil(2 * face.uHalf / step - 1e-9))
	local vCount = math.max(1, math.ceil(2 * face.vHalf / step - 1e-9))
	for i = 1, uCount do
		for j = 1, vCount do
			local u = ((i - 0.5) / uCount * 2 - 1) * face.uHalf
			local v = ((j - 0.5) / vCount * 2 - 1) * face.vHalf
			table.insert(points, guard.CFrame:PointToWorldSpace(face.center + face.u * u + face.v * v))
		end
	end
	return points
end

-- The face a player slides down: of the faces that face up, the biggest (a steep board's end faces are small). A
-- guard with no face up uses the one that faces the most up.
local function topFaceOf(guard: BasePart): Face
	local faces = facesOf(guard)
	local best: Face = faces[1]
	local anyUp = false
	local bestArea = -1
	local bestUp = -math.huge
	for _, face in faces do
		local up = guard.CFrame:VectorToWorldSpace(face.normal).Y
		if up > UP_FACE_MIN then
			local area = face.uHalf * face.vHalf
			if not anyUp or area > bestArea then
				best = face
				bestArea = area
			end
			anyUp = true
		elseif not anyUp and up > bestUp then
			best = face
			bestUp = up
		end
	end
	return best
end

-- The 8 corners of a part's bounding box, in world space.
local function cornersOf(part: BasePart): { Vector3 }
	local half = part.Size / 2
	local corners: { Vector3 } = {}
	for _, signX in { -1, 1 } do
		for _, signY in { -1, 1 } do
			for _, signZ in { -1, 1 } do
				table.insert(
					corners,
					part.CFrame:PointToWorldSpace(Vector3.new(signX * half.X, signY * half.Y, signZ * half.Z))
				)
			end
		end
	end
	return corners
end

-- Runs `run` with a made-up WorldModel that is destroyed afterwards, even when `run` fails.
local function inFakeWorld(run: (world: WorldModel) -> ())
	local world = Instance.new("WorldModel")
	world.Archivable = false
	world.Parent = game:GetService("ServerStorage")
	local ok, message = pcall(function(): string?
		run(world)
		return nil
	end)
	world:Destroy()
	if not ok then
		error(message, 0)
	end
end

local function startsWith(problems: { string }, prefix: string): { string }
	local found: { string } = {}
	for _, problem in problems do
		if string.sub(problem, 1, #prefix) == prefix then
			table.insert(found, problem)
		end
	end
	return found
end

-- A place under a roof (a crevice, the underside of a chair arm) can't be read by rays from y 150: they hit whatever is
-- on top. So a cloth point with a face that points down within ROOF_SEARCH studs above it (the search starts CLOTH_LIFT
-- over the point) is read square to its face instead: `bodySizeSlopeFacing`.
local ROOF_SEARCH = 10 -- studs: how far up to look for a roof

local CLOTH_LIFT = 0.5 -- studs: the roof search starts this far over the cloth point under a place

-- The same best-fit plane, read square to a face instead of straight down (code_lead's ruling after step 23-8a, round 1,
-- point 2b): on a face of 70 to 80 degrees a 4 by 4 stud square read from above spans up to 11 studs of height, so the
-- rays from above start inside him. These 25 rays form the same 5 by 5 grid, 1 stud apart, in the plane square to
-- `normal` (the face's outward direction). They start FACING_OUT studs out from `point` and aim back along `normal`,
-- FACING_OUT + FACING_IN studs long. The plane fitted to where they hit has its steepness from straight up returned.
-- Nil when a ray misses.
local FACING_OUT = 2 -- studs: the rays start this far out from the cloth point...

local FACING_IN = 2 -- ...and look this far in past it

local function bodySizeSlopeFacing(params: RaycastParams, point: Vector3, normal: Vector3): number?
	local out = normal.Unit
	local side = out:Cross(Vector3.yAxis)
	local across = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local along = out:Cross(across)
	local sumAcross, sumAlong = 0, 0
	for offsetAcross = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
		for offsetAlong = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
			local origin = point + out * FACING_OUT + across * offsetAcross + along * offsetAlong
			local hit = game:GetService("Workspace"):Raycast(origin, -out * (FACING_OUT + FACING_IN), params)
			if hit == nil then
				return nil
			end
			local height = (hit.Position - point):Dot(out) -- how far the hit lies out from the plane through `point`
			sumAcross += offsetAcross * height
			sumAlong += offsetAlong * height
		end
	end
	-- the same sum as bodySizeSlopeAt's: for offsets -2 to 2 the sum of offset squared over the grid is 50
	local squares = (2 * BODY_SLOPE_REACH + 1)
		* (BODY_SLOPE_REACH * (BODY_SLOPE_REACH + 1) * (2 * BODY_SLOPE_REACH + 1) / 3)
	local planeNormal = (out - across * (sumAcross / squares) - along * (sumAlong / squares)).Unit
	return math.deg(math.acos(math.clamp(planeNormal.Y, -1, 1)))
end

-- A roof higher than ROOF_SEARCH (code_lead's ruling after step 23-8b.1, Ruling 10) makes the read from above hit the
-- roof, not the cloth: its middle ray lands far from the cloth point. If it lands more than CLOTH_MATCH studs from the
-- cloth point's height, it didn't read the cloth, so the facing read is used. Where it does land on the cloth, the read
-- from above stands, as the seam test reads it (the 65 degree line is read the same way).
local CLOTH_MATCH = 0.5 -- studs: the most the middle ray's height may differ from the cloth point's height

-- His slope at body size at a cloth point (with the face's outward direction there): where a roof lies within ROOF_SEARCH
-- studs above the point (a crevice, the underside of a chair arm), or the read from above didn't land on the cloth
-- (CLOTH_MATCH), the facing read; otherwise exactly bodySizeSlopeAt's read from above, as the seam test reads it.
local function bodySizeSlopeAtCloth(params: RaycastParams, point: Vector3, normal: Vector3): number?
	local roof = game:GetService("Workspace")
		:Raycast(point + Vector3.new(0, CLOTH_LIFT, 0), Vector3.new(0, ROOF_SEARCH, 0), params)
	if roof ~= nil and roof.Normal.Y < 0 then
		return bodySizeSlopeFacing(params, point, normal)
	end
	local fromAbove, middleHeight = bodySizeSlopeAt(params, point.X, point.Z)
	if middleHeight ~= nil and math.abs(middleHeight - point.Y) > CLOTH_MATCH then
		return bodySizeSlopeFacing(params, point, normal)
	end
	return fromAbove
end

local function outsideLimits(gap: number): boolean
	return gap ~= gap or gap > ABOVE_LIMIT + LIMIT_SLACK or gap < -BELOW_LIMIT - LIMIT_SLACK
end

-- The gap to the drawn skin within SKIN_SIDE_REACH studs sideways of (x, z) that fits the limits and is the closest to
-- zero, or nil when no skin there fits. `solidY` is the solid shape's height at the point.
local function sidewaysFit(reader: DrawnSkin.Skin, x: number, z: number, solidY: number): number?
	local best: number? = nil
	local step = SKIN_SIDE_REACH / SKIN_SIDE_STEPS
	for i = -SKIN_SIDE_STEPS, SKIN_SIDE_STEPS do
		for j = -SKIN_SIDE_STEPS, SKIN_SIDE_STEPS do
			if i * i + j * j <= SKIN_SIDE_STEPS * SKIN_SIDE_STEPS then
				local drawn = reader.heightAt(x + i * step, z + j * step, solidY + SKIN_SEARCH_ABOVE)
				if drawn ~= nil then
					local gap = solidY - drawn
					if not outsideLimits(gap) and (best == nil or math.abs(gap) < math.abs(best)) then
						best = gap
					end
				end
			end
		end
	end
	return best
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function realWorld(): Instance
	local world = game:GetService("Workspace"):FindFirstChild("World")
	expect(world).never.toBeNil()
	return world :: Instance
end

local function bodyMesh(pieceName: string): MeshPart
	local world = Workspace:FindFirstChild("World")
	expect(world).never.toBeNil()
	local giant = (world :: Instance):FindFirstChild("Giant")
	expect(giant).never.toBeNil()
	local piece = (giant :: Instance):FindFirstChild(pieceName)
	expect(piece).never.toBeNil()
	local mesh = (piece :: Instance):FindFirstChild(pieceName)
	expect(mesh).never.toBeNil()
	expect((mesh :: Instance):IsA("MeshPart")).toBe(true)
	return mesh :: MeshPart
end

-- Where a point is, using the real zone boxes and the real garden boxes.
local function locator(): (Instance, (Vector3) -> any)
	local world = realWorld()
	local zoneBoxes, zoneProblems = WorldIndex.readZones(world)
	expect(zoneProblems).toEqual({})
	local gardens, gardenProblems = WorldIndex.readGardens(world)
	expect(gardenProblems).toEqual({})
	local gardenBoxes = {}
	for _, garden in gardens :: { WorldIndex.Garden } do
		table.insert(gardenBoxes, { index = garden.index, cframe = garden.box.cframe, size = garden.box.size })
	end
	return world,
		function(point: Vector3)
			return Zones.locate(point, zoneBoxes :: { Zones.ZoneBox }, gardenBoxes)
		end
end

-- The invisible side rails close both sides of the open top of his nose, and run beside the cap ladder, so nobody can
-- step off the nose onto the ledge and into the slot between the forehead walls and his cheeks. V1's pair was built
-- by tools/world/03b-forehead.luau; stuck safety Task 25 (tools/world/15-real-shape.luau section 2b) replaces it
-- with up to two parts per side.
local function sideRails(): { BasePart }
	local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
	expect(guard).never.toBeNil()
	local rails: { BasePart } = {}
	for _, child in (guard :: Instance):GetChildren() do
		if child.Name == "SideRail" and child:IsA("BasePart") then
			table.insert(rails, child)
		end
	end
	table.sort(rails, function(a, b)
		return a.Position.X < b.Position.X
	end)
	return rails
end

local WALL_MIN_DEGREES = 75

local MAX_PROBLEM_LINES = 8

local function wallDegrees(normal: Vector3): number
	return math.deg(math.acos(math.clamp(math.abs(normal.Y), 0, 1)))
end

local function firstLines(lines: { string }): { count: number, first: { string } }
	local first: { string } = {}
	for index = 1, math.min(#lines, MAX_PROBLEM_LINES) do
		table.insert(first, lines[index])
	end
	return { count = #lines, first = first }
end

local RAY_START_ABOVE = 3 -- studs: a ground ray starts this far above the place it checks

local STAND_LIMIT = 0.3 -- studs: how far a point's top may be from the ground under it

local function loadRoute(): { WorldIndex.RoutePoint }
	local points, problems = WorldIndex.readRoute(realWorld())
	expect(problems).toEqual({})
	return points :: { WorldIndex.RoutePoint }
end

-- What a player stands on: a ray down that skips everything with CanCollide off (flowers, ropes, cleats).
local function groundRay(): RaycastParams
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	return params
end

local function describeVector(vector: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", vector.X, vector.Y, vector.Z)
end

return {
	ABOVE_LIMIT = ABOVE_LIMIT,
	BELOW_LIMIT = BELOW_LIMIT,
	BODY_PIECES = BODY_PIECES,
	BODY_SLOPE_RAY_ABOVE = BODY_SLOPE_RAY_ABOVE,
	BODY_SLOPE_RAY_LENGTH = BODY_SLOPE_RAY_LENGTH,
	RAY_START_ABOVE = RAY_START_ABOVE,
	SKIN_SEARCH_ABOVE = SKIN_SEARCH_ABOVE,
	SKIN_SIDE_REACH = SKIN_SIDE_REACH,
	SMALL_PATCHES_FOLDER = SMALL_PATCHES_FOLDER,
	STAND_LIMIT = STAND_LIMIT,
	UP_FACE_MIN = UP_FACE_MIN,
	WALL_MIN_DEGREES = WALL_MIN_DEGREES,
	bodyMesh = bodyMesh,
	bodySizeSlopeAt = bodySizeSlopeAt,
	bodySizeSlopeAtCloth = bodySizeSlopeAtCloth,
	bodySizeSlopeFacing = bodySizeSlopeFacing,
	cornersOf = cornersOf,
	describePoint = describePoint,
	describeVector = describeVector,
	facesOf = facesOf,
	firstLines = firstLines,
	flat = flat,
	groundRay = groundRay,
	inFakeWorld = inFakeWorld,
	loadRoute = loadRoute,
	locator = locator,
	outsideLimits = outsideLimits,
	pointsOver = pointsOver,
	realWorld = realWorld,
	sideRails = sideRails,
	sidewaysFit = sidewaysFit,
	startsWith = startsWith,
	topFaceOf = topFaceOf,
	wallDegrees = wallDegrees,
}
