--!strict
-- How deep a point sits inside a main character's body (Plan "gardens-and-ways-up", Task 6d, product's sink ruling; method:
-- code_lead's ruling, work/t6d/method-ruling.md, 2026-11-04). One module for the test (SunkParts.spec) and the belly cover
-- tool (tools/world/17b-belly-cover.luau), so the two never drift apart.
--
-- Every visible character part has its own RaycastParams. A point is tested only against the character parts whose world
-- box holds it. Against one such part: 26 outward rays (20 studs) hit nothing, and at least 20 of 26 inward rays hit it =
-- the point is INSIDE that part, and its depth is the shortest inward hit (the distance to his skin). The point's depth is
-- the largest over those parts. (Rays are filtered to one part because a point sunk in one part is often near another,
-- and that other part would hide it.) A face is tested at 3 x 3 points, 0.95 studs in from its edges. The limit is 0.3
-- studs on a part's two end faces (across its longest axis), 0.1 on every other face (Rule 103). A face whose world normal
-- points down (Y under -0.7) rests on him and is skipped.
-- Reads the world only (rays); changes nothing.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

export type CharacterPart = { part: BasePart, params: RaycastParams, min: Vector3, max: Vector3 }
-- One tested face. axis 1 = the part's Right, 2 = Up, 3 = Look; sign = which end of that axis (-1 or 1).
-- worst = the deepest of its points that is over the limit (0 when none); failing / total = points over the limit / tested.
export type Face = { axis: number, sign: number, limit: number, worst: number, failing: number, total: number }

local SinkDepth = {}

SinkDepth.END_LIMIT = 0.3 -- studs, on a part's two end faces
SinkDepth.OTHER_LIMIT = 0.1 -- studs, on every other face
SinkDepth.DOWN_FACE_Y = -0.7 -- a face whose world normal Y is under this rests on him and is skipped
SinkDepth.FACE_INSET = 0.95 -- studs: the 3 x 3 points on a face stay this far from its edges
SinkDepth.RAY_LENGTH = 20 -- studs, every ray
SinkDepth.INSIDE_MIN_HITS = 20 -- of the 26 inward rays
SinkDepth.INVISIBLE = 0.99 -- transparency from here up is not visible

local DIRECTIONS: { Vector3 } = {}
for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			if x ~= 0 or y ~= 0 or z ~= 0 then
				table.insert(DIRECTIONS, Vector3.new(x, y, z).Unit)
			end
		end
	end
end

function SinkDepth.isVisible(part: BasePart): boolean
	return part.Transparency < SinkDepth.INVISIBLE
end

-- The world-space box (min, max) around a part.
function SinkDepth.boxOf(part: BasePart): (Vector3, Vector3)
	local extent = Vector3.new(
		math.abs(part.CFrame.RightVector.X) * part.Size.X / 2
			+ math.abs(part.CFrame.UpVector.X) * part.Size.Y / 2
			+ math.abs(part.CFrame.LookVector.X) * part.Size.Z / 2,
		math.abs(part.CFrame.RightVector.Y) * part.Size.X / 2
			+ math.abs(part.CFrame.UpVector.Y) * part.Size.Y / 2
			+ math.abs(part.CFrame.LookVector.Y) * part.Size.Z / 2,
		math.abs(part.CFrame.RightVector.Z) * part.Size.X / 2
			+ math.abs(part.CFrame.UpVector.Z) * part.Size.Y / 2
			+ math.abs(part.CFrame.LookVector.Z) * part.Size.Z / 2
	)
	return part.Position - extent, part.Position + extent
end

-- Every visible part of every model with this tag, each with its own Include params and world box.
function SinkDepth.characterParts(tag: string): { CharacterPart }
	local characters: { CharacterPart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("Model") then
			for _, descendant in instance:GetDescendants() do
				if descendant:IsA("BasePart") and SinkDepth.isVisible(descendant) then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { descendant }
					local low, high = SinkDepth.boxOf(descendant)
					table.insert(characters, { part = descendant, params = params, min = low, max = high })
				end
			end
		end
	end
	return characters
end

local function holds(box: CharacterPart, point: Vector3): boolean
	return point.X >= box.min.X
		and point.X <= box.max.X
		and point.Y >= box.min.Y
		and point.Y <= box.max.Y
		and point.Z >= box.min.Z
		and point.Z <= box.max.Z
end

-- How deep the point sits inside this one character part, or nil when it is not inside it.
local function depthInside(params: RaycastParams, point: Vector3): number?
	for _, direction in DIRECTIONS do
		if Workspace:Raycast(point, direction * SinkDepth.RAY_LENGTH, params) ~= nil then
			return nil
		end
	end
	local hits = 0
	local shallowest = math.huge
	for _, direction in DIRECTIONS do
		local result =
			Workspace:Raycast(point + direction * SinkDepth.RAY_LENGTH, -direction * SinkDepth.RAY_LENGTH, params)
		if result ~= nil then
			hits += 1
			shallowest = math.min(shallowest, SinkDepth.RAY_LENGTH - result.Distance)
		end
	end
	if hits >= SinkDepth.INSIDE_MIN_HITS then
		return shallowest
	end
	return nil
end

-- The largest depth over the character parts whose box holds the point (0 when it is inside none).
function SinkDepth.depth(characters: { CharacterPart }, point: Vector3): number
	local deepest = 0
	for _, box in characters do
		if holds(box, point) then
			local depth = depthInside(box.params, point)
			if depth ~= nil and depth > deepest then
				deepest = depth
			end
		end
	end
	return deepest
end

-- Every non-down face of a box (its frame and size), each with its 3 x 3 points measured against the limit.
function SinkDepth.faceDepths(cf: CFrame, size: Vector3, characters: { CharacterPart }): { Face }
	local longest = 1
	if size.Y > size.X and size.Y >= size.Z then
		longest = 2
	elseif size.Z > size.X and size.Z > size.Y then
		longest = 3
	end
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local sizes = { size.X, size.Y, size.Z }
	local faces: { Face } = {}
	for axis = 1, 3 do
		for _, sign in { -1, 1 } do
			local normal = axes[axis] * sign
			if normal.Y >= SinkDepth.DOWN_FACE_Y then
				local limit = if axis == longest then SinkDepth.END_LIMIT else SinkDepth.OTHER_LIMIT
				local others = {}
				for other = 1, 3 do
					if other ~= axis then
						table.insert(others, other)
					end
				end
				local reachA = math.max(0, sizes[others[1]] / 2 - SinkDepth.FACE_INSET)
				local reachB = math.max(0, sizes[others[2]] / 2 - SinkDepth.FACE_INSET)
				local middle = cf.Position + normal * (sizes[axis] / 2)
				local face: Face = { axis = axis, sign = sign, limit = limit, worst = 0, failing = 0, total = 0 }
				for a = -1, 1 do
					for b = -1, 1 do
						local point = middle + axes[others[1]] * (a * reachA) + axes[others[2]] * (b * reachB)
						local depth = SinkDepth.depth(characters, point)
						face.total += 1
						if depth > limit then
							face.failing += 1
							face.worst = math.max(face.worst, depth)
						end
					end
				end
				table.insert(faces, face)
			end
		end
	end
	return faces
end

return SinkDepth
