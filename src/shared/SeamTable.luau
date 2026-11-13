--!strict
-- The style guide's seam table and the line helpers built on it (plan 5 Task 16). Jest-free and service-free, so a world
-- script (tools/world/24-seam.luau, run through execute_luau) and a test (WalkAreaFacts, Seam.spec) read the same copy.
-- Table source: docs/design/v2/style-guide/nests-map.md, "Where it is", 2026-11-09.

local SeamTable = {}

-- Along his side (z) and the x of the line, the same on both sides (his left is the negative x).
SeamTable.TABLE = {
	{ z = -38, x = 16.9 },
	{ z = -36, x = 19.1 },
	{ z = -34, x = 21.2 },
	{ z = -32, x = 23.1 },
	{ z = -30, x = 25.2 },
	{ z = -28, x = 26.6 },
	{ z = -24, x = 29.3 },
	{ z = -20, x = 30.8 },
	{ z = -16, x = 31.5 },
	{ z = -14, x = 31.8 },
} :: { { z: number, x: number } }

-- The table's points on one side (side -1 his left, 1 his right) as (x, 0, z).
function SeamTable.seamLine(side: number): { Vector3 }
	local line: { Vector3 } = {}
	for _, row in SeamTable.TABLE do
		table.insert(line, Vector3.new(side * row.x, 0, row.z))
	end
	return line
end

-- Distance in the flat (x, z) plane from a point to the nearest piece of a line.
function SeamTable.flatDistanceToLine(point: Vector3, line: { Vector3 }): number
	local best = math.huge
	local from = Vector3.new(point.X, 0, point.Z)
	for index = 1, #line - 1 do
		local a = Vector3.new(line[index].X, 0, line[index].Z)
		local b = Vector3.new(line[index + 1].X, 0, line[index + 1].Z)
		local along = b - a
		local t = math.clamp((from - a):Dot(along) / along:Dot(along), 0, 1)
		best = math.min(best, (from - (a + along * t)).Magnitude)
	end
	return best
end

-- Distance from a point to the box of a part (0 inside it).
function SeamTable.distanceToBox(part: BasePart, point: Vector3): number
	local inPart = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local inside = Vector3.new(
		math.clamp(inPart.X, -half.X, half.X),
		math.clamp(inPart.Y, -half.Y, half.Y),
		math.clamp(inPart.Z, -half.Z, half.Z)
	)
	return (inPart - inside).Magnitude
end

-- Points every `step` studs along a polyline, measured in the flat (x, z) plane: the first point, then each mark. A
-- point keeps its y (the line's own y between its two ends).
function SeamTable.marksAlong(line: { Vector3 }, step: number): { Vector3 }
	local marks: { Vector3 } = { line[1] }
	local carried = 0 -- length walked since the last mark
	for index = 1, #line - 1 do
		local a, b = line[index], line[index + 1]
		local flatLength = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
		local walked = 0
		while carried + (flatLength - walked) >= step do
			walked += step - carried
			carried = 0
			table.insert(marks, a:Lerp(b, walked / flatLength))
		end
		carried += flatLength - walked
	end
	return marks
end

return SeamTable
