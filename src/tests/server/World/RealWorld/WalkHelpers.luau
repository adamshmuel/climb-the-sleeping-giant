--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local BODY_PIECES = Helpers.BODY_PIECES
local realWorld = Helpers.realWorld
local Workspace = game:GetService("Workspace")

local WALK_NAMES: { [string]: boolean } = { Boots_Walk = true, RightBoots_Walk = true, Belly_Walk = true }

local WINDOW_BELOW = 0.2 -- studs: a walk top may be this far under his skin

local WINDOW_ABOVE = 0.7 -- studs: ...and this far over it

local WINDOW_SLACK = 0.001 -- studs: rounding in the numbers written into the world

local GRID_STEP = 1 -- studs: the points checked on a top are at most this far apart

local GRID_INSET = 0.5 -- studs: ...and this far in from every edge, with both inner edges included

local RAY_ABOVE = 12

local RAY_LENGTH = 24

local MAX_EXAMPLES = 3 -- most examples written out for each piece

local BODY_PATCH_REACH = 2 -- the body-size slope: 25 rays 1 stud apart on a 4 by 4 stud square

local function walkFolder(): Instance
	local walk = realWorld():FindFirstChild("WalkSurfaces")
	expect(walk).never.toBeNil()
	return walk :: Instance
end

-- His six body pieces.
local function bodyInstances(): { Instance }
	local giant = realWorld():FindFirstChild("Giant")
	expect(giant).never.toBeNil()
	local meshes: { Instance } = {}
	for _, name in BODY_PIECES do
		local model = (giant :: Instance):FindFirstChild(name)
		expect(model).never.toBeNil()
		local mesh = (model :: Instance):FindFirstChild(name)
		expect(mesh).never.toBeNil()
		table.insert(meshes, mesh :: Instance)
	end
	return meshes
end

-- A ray that sees only his six body pieces.
local function bodyParams(): RaycastParams
	local params = RaycastParams.new()
	params.IncludeInstances = bodyInstances()
	params.RespectCanCollide = false
	return params
end

-- The places along one side of a top: GRID_INSET in from both edges, at most GRID_STEP apart, both inner edges included.
local function axisPoints(extent: number): { number }
	local span = extent - 2 * GRID_INSET
	if span <= 0 then
		return { 0 }
	end
	local count = math.ceil(span / GRID_STEP)
	local points: { number } = {}
	for index = 0, count do
		table.insert(points, -span / 2 + span * index / count)
	end
	return points
end

-- The grid of a flat piece's top, in world space.
local function topGrid(cframe: CFrame, size: Vector3): { Vector3 }
	local points: { Vector3 } = {}
	for _, x in axisPoints(size.X) do
		for _, z in axisPoints(size.Z) do
			table.insert(points, cframe:PointToWorldSpace(Vector3.new(x, size.Y / 2, z)))
		end
	end
	return points
end

-- Where his skin is under `point`: a ray straight down from RAY_ABOVE over it, RAY_LENGTH long.
local function skinUnder(params: RaycastParams, point: Vector3): RaycastResult?
	return Workspace:Raycast(point + Vector3.new(0, RAY_ABOVE, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
end

local function walkPieces(): { BasePart }
	local pieces: { BasePart } = {}
	for _, piece in walkFolder():GetChildren() do
		if piece:IsA("BasePart") and WALK_NAMES[piece.Name] then
			table.insert(pieces, piece)
		end
	end
	return pieces
end

local function crossingRamps(): { BasePart }
	local ramps: { BasePart } = {}
	for _, piece in walkFolder():GetChildren() do
		if piece:IsA("BasePart") and string.match(piece.Name, "^CrossingRamp_") then
			table.insert(ramps, piece)
		end
	end
	return ramps
end

-- The ladder's centre line is its truss, `Climb`: the longest side of the truss runs up the ladder.
export type LadderAxis = { foot: Vector3, top: Vector3, up: Vector3, flat: Vector3, back: Vector3 }

local function ladderAxis(ladder: Instance): LadderAxis
	local truss = ladder:FindFirstChild("Climb")
	expect(truss).never.toBeNil()
	local part = truss :: BasePart
	local size = part.Size
	local length = math.max(size.X, size.Y, size.Z)
	local up = if size.X == length
		then part.CFrame.RightVector
		elseif size.Y == length then part.CFrame.UpVector
		else part.CFrame.LookVector
	if up.Y < 0 then
		up = -up
	end
	local flatPart = Vector3.new(up.X, 0, up.Z)
	local flat = flatPart.Unit
	-- "back" is toward his face: along the flat direction and tilted down, square to the ladder.
	local back = (flat * up.Y - Vector3.yAxis * flatPart.Magnitude).Unit
	return {
		foot = part.Position - up * length / 2,
		top = part.Position + up * length / 2,
		up = up,
		flat = flat,
		back = back,
	}
end

-- The named parts of a ladder: rails and rungs are in its Look model, the Climb truss is in the ladder itself.
local function ladderParts(ladder: Instance, name: string): { BasePart }
	local found: { BasePart } = {}
	local holder = if name == "Climb" then ladder else ladder:FindFirstChild("Look")
	if holder == nil then
		return found
	end
	for _, child in holder:GetChildren() do
		if child:IsA("BasePart") and child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

-- The direction a part's longest side runs, and that length.
local function longSide(part: BasePart): (Vector3, number)
	local size = part.Size
	local length = math.max(size.X, size.Y, size.Z)
	local direction = if size.X == length
		then part.CFrame.RightVector
		elseif size.Y == length then part.CFrame.UpVector
		else part.CFrame.LookVector
	return direction, length
end

-- His body-size slope at (x, z) in degrees: the plane that best fits 25 rays straight down on a 4 by 4 stud square
-- (designer's rule, as in the seam test). nil when a ray misses him.
local function bodySlopeAt(params: RaycastParams, x: number, z: number): number?
	local sumX, sumZ = 0, 0
	for offsetX = -BODY_PATCH_REACH, BODY_PATCH_REACH do
		for offsetZ = -BODY_PATCH_REACH, BODY_PATCH_REACH do
			local hit = Workspace:Raycast(Vector3.new(x + offsetX, 200, z + offsetZ), Vector3.new(0, -250, 0), params)
			if hit == nil then
				return nil
			end
			sumX += offsetX * hit.Position.Y
			sumZ += offsetZ * hit.Position.Y
		end
	end
	local squares = (2 * BODY_PATCH_REACH + 1)
		* (BODY_PATCH_REACH * (BODY_PATCH_REACH + 1) * (2 * BODY_PATCH_REACH + 1) / 3)
	local normal = Vector3.new(-sumX / squares, 1, -sumZ / squares).Unit
	return math.deg(math.acos(math.clamp(normal.Y, -1, 1)))
end

return {
	GRID_INSET = GRID_INSET,
	GRID_STEP = GRID_STEP,
	MAX_EXAMPLES = MAX_EXAMPLES,
	RAY_ABOVE = RAY_ABOVE,
	WINDOW_ABOVE = WINDOW_ABOVE,
	WINDOW_BELOW = WINDOW_BELOW,
	WINDOW_SLACK = WINDOW_SLACK,
	bodyInstances = bodyInstances,
	bodyParams = bodyParams,
	bodySlopeAt = bodySlopeAt,
	crossingRamps = crossingRamps,
	ladderAxis = ladderAxis,
	ladderParts = ladderParts,
	longSide = longSide,
	skinUnder = skinUnder,
	topGrid = topGrid,
	walkFolder = walkFolder,
	walkPieces = walkPieces,
}
