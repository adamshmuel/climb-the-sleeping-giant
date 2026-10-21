--!strict
-- DrawnSkin: a test helper (stuck safety Task 26). It answers one question: "how high is the skin the player SEES
-- under this spot?" The giant has two kinds of surface. His solid shape is what a player stands on. His drawn skin is
-- the mesh triangles Roblox paints, plus any shirt folds (blocks and wedges that players pass through and that only lift
-- what is drawn). The two can differ, so tests measure the solid shape against this skin, never against itself.
--
-- The skin is read from the real mesh triangles (AssetService:CreateEditableMeshAsync, mapped through the part's
-- CFrame and Size/MeshSize), put into a grid of 2-stud cells so a lookup only tests the few triangles under the spot.
-- A fold is a Part (block) or a WedgePart, measured by box and wedge maths (a vertical line cut through a convex
-- shape). Nothing here changes the world: the editable meshes are destroyed as soon as their triangles are copied.

local AssetService = game:GetService("AssetService")

local CELL = 2 -- studs: the side of one grid cell
local INSIDE_SLACK = 1e-7 -- a spot on a triangle's edge counts as inside
local PARALLEL = 1e-9 -- a line this parallel to a face never crosses it

export type Triangle = { a: Vector3, b: Vector3, c: Vector3 }

-- A block or a wedge: where it is, how big, and which of the two it is.
export type Solid = { cframe: CFrame, size: Vector3, isWedge: boolean }

export type Skin = {
	-- The highest drawn surface at (x, z) that is at or below maxY (any height when maxY is nil), or nil if none.
	heightAt: (x: number, z: number, maxY: number?) -> number?,
	triangleCount: number,
	solidCount: number,
}

local DrawnSkin = {}

-- The faces of a block or a wedge, each as "normal . point <= limit", in the shape's own space. A WedgePart is a block
-- cut along one diagonal: it stands full height on its +Z side and thins to nothing at its -Z side, so its sloped face
-- is y = z * size.Y / size.Z. (Checked against Roblox's own wedge by a test in DrawnSkin.spec.)
local function facesOf(solid: Solid): { { normal: Vector3, limit: number } }
	local half = solid.size / 2
	local faces = {
		{ normal = Vector3.xAxis, limit = half.X },
		{ normal = -Vector3.xAxis, limit = half.X },
		{ normal = Vector3.zAxis, limit = half.Z },
		{ normal = -Vector3.yAxis, limit = half.Y },
	}
	if solid.isWedge then
		table.insert(faces, { normal = Vector3.new(0, 1, -solid.size.Y / solid.size.Z), limit = 0 })
		table.insert(faces, { normal = -Vector3.zAxis, limit = half.Z })
	else
		table.insert(faces, { normal = Vector3.yAxis, limit = half.Y })
		table.insert(faces, { normal = -Vector3.zAxis, limit = half.Z })
	end
	return faces
end

-- Reads a part as a solid. Only blocks, wedges and trusses (a truss is a plain box) are allowed.
function DrawnSkin.solidOf(part: BasePart): Solid
	if part:IsA("WedgePart") then
		return { cframe = part.CFrame, size = part.Size, isWedge = true }
	end
	if part:IsA("TrussPart") then
		return { cframe = part.CFrame, size = part.Size, isWedge = false }
	end
	if part:IsA("Part") and part.Shape == Enum.PartType.Block then
		return { cframe = part.CFrame, size = part.Size, isWedge = false }
	end
	error(`{part:GetFullName()} is a {part.ClassName}: only blocks and wedges are allowed`)
end

-- Where a straight vertical line through (x, z) is inside the solid: its lowest and highest y, or nil nil when the
-- line misses it.
function DrawnSkin.columnSpan(solid: Solid, x: number, z: number): (number?, number?)
	local origin = solid.cframe:PointToObjectSpace(Vector3.new(x, 0, z))
	local direction = solid.cframe:VectorToObjectSpace(Vector3.yAxis)
	local lowest, highest = -math.huge, math.huge
	for _, face in facesOf(solid) do
		local rate = face.normal:Dot(direction)
		local room = face.limit - face.normal:Dot(origin)
		if math.abs(rate) < PARALLEL then
			if room < 0 then
				return nil, nil
			end
		elseif rate > 0 then
			highest = math.min(highest, room / rate)
		else
			lowest = math.max(lowest, room / rate)
		end
	end
	if lowest > highest then
		return nil, nil
	end
	return lowest, highest
end

-- The height of a triangle's plane over (x, z), or nil when (x, z) is outside it (seen from above).
local function triangleHeight(triangle: Triangle, x: number, z: number): number?
	local a, b, c = triangle.a, triangle.b, triangle.c
	local firstX, firstZ = b.X - a.X, b.Z - a.Z
	local secondX, secondZ = c.X - a.X, c.Z - a.Z
	local determinant = firstX * secondZ - secondX * firstZ
	if math.abs(determinant) < PARALLEL then
		return nil -- a wall seen edge-on
	end
	local pointX, pointZ = x - a.X, z - a.Z
	local u = (pointX * secondZ - secondX * pointZ) / determinant
	local v = (firstX * pointZ - pointX * firstZ) / determinant
	if u < -INSIDE_SLACK or v < -INSIDE_SLACK or u + v > 1 + INSIDE_SLACK then
		return nil
	end
	return a.Y + u * (b.Y - a.Y) + v * (c.Y - a.Y)
end

-- A skin made of these triangles (world space) and these blocks and wedges.
function DrawnSkin.new(triangles: { Triangle }, solids: { Solid }?): Skin
	local solidList: { Solid } = solids or {}
	local cells: { [number]: { [number]: { Triangle } } } = {}
	for _, triangle in triangles do
		local minX = math.min(triangle.a.X, triangle.b.X, triangle.c.X)
		local maxX = math.max(triangle.a.X, triangle.b.X, triangle.c.X)
		local minZ = math.min(triangle.a.Z, triangle.b.Z, triangle.c.Z)
		local maxZ = math.max(triangle.a.Z, triangle.b.Z, triangle.c.Z)
		for cellX = math.floor(minX / CELL), math.floor(maxX / CELL) do
			local column = cells[cellX]
			if column == nil then
				column = {}
				cells[cellX] = column
			end
			for cellZ = math.floor(minZ / CELL), math.floor(maxZ / CELL) do
				local list = (column :: any)[cellZ]
				if list == nil then
					list = {}
					(column :: any)[cellZ] = list
				end
				table.insert(list, triangle)
			end
		end
	end

	local function heightAt(x: number, z: number, maxY: number?): number?
		local ceiling = maxY or math.huge
		local best: number? = nil
		local column = cells[math.floor(x / CELL)]
		local list: { Triangle }? = if column then (column :: any)[math.floor(z / CELL)] else nil
		if list then
			for _, triangle in list do
				local height = triangleHeight(triangle, x, z)
				if height ~= nil and height <= ceiling and (best == nil or height > best) then
					best = height
				end
			end
		end
		for _, solid in solidList do
			local _, top = DrawnSkin.columnSpan(solid, x, z)
			if top ~= nil and top <= ceiling and (best == nil or top > best) then
				best = top
			end
		end
		return best
	end

	return { heightAt = heightAt, triangleCount = #triangles, solidCount = #solidList }
end

-- The mesh triangles of one MeshPart, in world space. The editable mesh is destroyed before this returns.
function DrawnSkin.meshTriangles(mesh: MeshPart): { Triangle }
	local ok, editable = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromUri(mesh.MeshId))
	end)
	if not ok or editable == nil then
		error(`could not read the mesh of {mesh:GetFullName()}: {tostring(editable)}`)
	end
	local scale = mesh.Size / mesh.MeshSize
	local function corner(vertexId: number): Vector3
		return mesh.CFrame:PointToWorldSpace(editable:GetPosition(vertexId) * scale)
	end
	local triangles: { Triangle } = {}
	for _, faceId in editable:GetFaces() :: { number } do
		local ids = editable:GetFaceVertices(faceId) :: { number }
		table.insert(triangles, { a = corner(ids[1]), b = corner(ids[2]), c = corner(ids[3]) })
	end
	editable:Destroy()
	return triangles
end

-- The skin of these body meshes plus these shirt folds. A fold that is not a block or a wedge is an error.
function DrawnSkin.fromWorld(meshes: { MeshPart }, folds: { BasePart }): Skin
	local triangles: { Triangle } = {}
	for _, mesh in meshes do
		for _, triangle in DrawnSkin.meshTriangles(mesh) do
			table.insert(triangles, triangle)
		end
	end
	local solids: { Solid } = {}
	for _, fold in folds do
		if fold:IsA("TrussPart") then
			error(`{fold:GetFullName()} is a TrussPart: a shirt fold is a block or a wedge`)
		end
		table.insert(solids, DrawnSkin.solidOf(fold))
	end
	return DrawnSkin.new(triangles, solids)
end

return DrawnSkin
