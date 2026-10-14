--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local SlamCircle = require(StarterPlayer.StarterPlayerScripts.Client.Fx.SlamCircle)

local UP = Vector3.yAxis
local RAYS_A_FRAME = 1000

-- Maths surfaces: each has a ray (the shape the module takes) and its own way of saying how high a point is above it,
-- so the tests never use the module's own check.
type Surface = {
	cast: SlamCircle.Cast,
	height: (point: Vector3) -> number?, -- how far above the surface, or nil where there is no surface
}

local function planeSurface(origin: Vector3, normalVector: Vector3): Surface
	local normal = normalVector.Unit
	return {
		cast = function(rayOrigin: Vector3, direction: Vector3): (Vector3?, Vector3?)
			local along = direction:Dot(normal)
			if along >= 0 then
				return nil, nil
			end
			local through = (origin - rayOrigin):Dot(normal) / along
			if through < 0 or through > 1 then
				return nil, nil
			end
			return rayOrigin + direction * through, normal
		end,
		height = function(point: Vector3): number?
			return (point - origin):Dot(normal)
		end,
	}
end

-- A ball of this radius whose top (or, for `inside`, whose bottom) is at the origin: a hill, or a bowl.
local function ballSurface(radius: number, inside: boolean): Surface
	local centre = if inside then Vector3.new(0, radius, 0) else Vector3.new(0, -radius, 0)
	return {
		cast = function(rayOrigin: Vector3, direction: Vector3): (Vector3?, Vector3?)
			local offset = rayOrigin - centre
			local a = direction:Dot(direction)
			local b = 2 * direction:Dot(offset)
			local c = offset:Dot(offset) - radius * radius
			local discriminant = b * b - 4 * a * c
			if discriminant < 0 then
				return nil, nil
			end
			local root = math.sqrt(discriminant)
			local through = if inside then (-b + root) / (2 * a) else (-b - root) / (2 * a)
			if through < 0 or through > 1 then
				return nil, nil
			end
			local hit = rayOrigin + direction * through
			local outward = (hit - centre).Unit
			return hit, if inside then -outward else outward
		end,
		height = function(point: Vector3): number?
			local distance = (point - centre).Magnitude
			return if inside then radius - distance else distance - radius
		end,
	}
end

-- A surface given by its height at each place (nil where there is none), found by walking along the ray.
local function fieldCast(field: (x: number, z: number) -> number?): SlamCircle.Cast
	local function normalAt(x: number, z: number): Vector3
		local step = 1e-3
		local right, left = field(x + step, z), field(x - step, z)
		local ahead, behind = field(x, z + step), field(x, z - step)
		if right == nil or left == nil or ahead == nil or behind == nil then
			return Vector3.yAxis
		end
		return Vector3.new((left - right) / (2 * step), 1, (behind - ahead) / (2 * step)).Unit
	end
	return function(rayOrigin: Vector3, direction: Vector3): (Vector3?, Vector3?)
		local steps = 240
		local previousT = 0
		local previousAbove: number? = nil
		for index = 0, steps do
			local t = index / steps
			local point = rayOrigin + direction * t
			local ground = field(point.X, point.Z)
			if ground == nil then
				previousAbove = nil
			else
				local above = point.Y - ground
				if previousAbove ~= nil and previousAbove > 0 and above <= 0 then
					local low, high = previousT, t
					for _ = 1, 24 do
						local middle = (low + high) / 2
						local probe = rayOrigin + direction * middle
						local probeGround = field(probe.X, probe.Z)
						if probeGround ~= nil and probe.Y - probeGround > 0 then
							low = middle
						else
							high = middle
						end
					end
					local hit = rayOrigin + direction * high
					return hit, normalAt(hit.X, hit.Z)
				end
				previousAbove = above
			end
			previousT = t
		end
		return nil, nil
	end
end

-- A roof: two planes tilted 30 degrees each way (60 degrees between them), meeting along the line x = 0.
local FOLD_TILT = math.rad(30)
local function foldSurface(): Surface
	local function field(x: number, _z: number): number?
		return -math.tan(FOLD_TILT) * math.abs(x)
	end
	return {
		cast = fieldCast(field),
		height = function(point: Vector3): number?
			-- The distance to the plane on this point's own side of the fold.
			return (point.Y + math.tan(FOLD_TILT) * math.abs(point.X)) * math.cos(FOLD_TILT)
		end,
	}
end

local EDGE_X = 5
-- Level ground at height 0 that stops at a straight edge, x = 5.
local function edgeSurface(): Surface
	local function field(x: number, _z: number): number?
		return if x <= EDGE_X then 0 else nil
	end
	return {
		cast = fieldCast(field),
		height = function(point: Vector3): number?
			return if point.X <= EDGE_X then point.Y else nil
		end,
	}
end

-- Counts how many rays a surface is asked for.
local function counted(cast: SlamCircle.Cast): (SlamCircle.Cast, () -> number)
	local count = 0
	return function(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
		count += 1
		return cast(origin, direction)
	end, function(): number
		return count
	end
end

-- Steps the builder (1,000 rays a step) until it is finished. Gives every piece, and how many steps it took.
local function buildAll(builder: SlamCircle.Builder, raysAStep: number?): ({ SlamCircle.Piece }, number)
	local all: { SlamCircle.Piece } = {}
	local steps = 0
	repeat
		steps += 1
		local result = builder.step(raysAStep or RAYS_A_FRAME)
		for _, piece in result.pieces do
			table.insert(all, piece)
		end
	until result.finished or steps > 200
	return all, steps
end

-- The 9 points of a piece's top face: the middle, the 4 corners and the middle of each of the 4 sides.
local function topPoints(piece: SlamCircle.Piece): { Vector3 }
	local cframe = piece.cframe
	local centre = cframe.Position + cframe.YVector * (piece.size.Y / 2)
	local halfLength, halfWidth = piece.size.X / 2, piece.size.Z / 2
	local points: { Vector3 } = {}
	for _, side in { { 0, 0 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		table.insert(points, centre + cframe.XVector * (side[1] * halfLength) + cframe.ZVector * (side[2] * halfWidth))
	end
	return points
end

-- Is the point (a place in the circle's flat plane) covered by a piece, looking straight down along `up`? The ray from
-- the point meets the piece's top plane; it is covered when it lands inside the piece's rectangle.
local function coveredFromAbove(pieces: { SlamCircle.Piece }, point: Vector3, up: Vector3): boolean
	for _, piece in pieces do
		local normal = piece.cframe.YVector
		local leans = up:Dot(normal)
		if math.abs(leans) > 1e-4 and (piece.cframe.Position - point).Magnitude < 8 then
			local top = piece.cframe.Position + normal * (piece.size.Y / 2)
			local through = (top - point):Dot(normal) / leans
			local offset = point + up * through - piece.cframe.Position
			if
				math.abs(offset:Dot(piece.cframe.XVector)) <= piece.size.X / 2
				and math.abs(offset:Dot(piece.cframe.ZVector)) <= piece.size.Z / 2
			then
				return true
			end
		end
	end
	return false
end

-- The widest stretch of the circle's plane, in studs, that no piece covers (looking straight down along `up`), among the
-- places of a 0.25-stud grid inside radius 15 whose x is between `fromX` and `toX` (both inclusive). A row of the grid
-- along x is walked; a run of n uncovered places is n * 0.25 studs wide. The fold and the leaning surfaces run along x.
local function widestGapAlongX(pieces: { SlamCircle.Piece }, up: Vector3, fromX: number, toX: number): number
	local widest = 0
	for iz = -60, 60 do
		local run = 0
		for ix = math.round(fromX / 0.25), math.round(toX / 0.25) do
			local x, z = ix * 0.25, iz * 0.25
			if x * x + z * z <= 15 * 15 and not coveredFromAbove(pieces, Vector3.new(x, 0, z), up) then
				run += 1
				widest = math.max(widest, run * 0.25)
			else
				run = 0
			end
		end
	end
	return widest
end

-- A hair of slack for the numbers: a height of 0.0199 is not a real failure.
local SLACK = 0.002

local function expectNear(actual: Vector3, expected: Vector3, tolerance: number?)
	expect((actual - expected).Magnitude < (tolerance or 1e-3)).toBe(true)
end

-- Is the point (x, z) inside the cell? The cell's length runs along the ring, its width across it.
local function cellContains(cell: SlamCircle.Cell, x: number, z: number): boolean
	local dx, dz = x - cell.u, z - cell.v
	local along = -math.sin(cell.angle) * dx + math.cos(cell.angle) * dz
	local across = math.cos(cell.angle) * dx + math.sin(cell.angle) * dz
	return math.abs(along) <= cell.length / 2 + 1e-9 and math.abs(across) <= cell.width / 2 + 1e-9
end

describe("SlamCircle.layout", function()
	local cells = SlamCircle.layout()

	it("makes no cell longer or wider than 2.9 studs", function()
		expect(#cells > 0).toBe(true)
		for _, cell in cells do
			expect(cell.length <= 2.9 + 1e-9).toBe(true)
			expect(cell.width <= 2.9 + 1e-9).toBe(true)
			expect(cell.length > 0 and cell.width > 0).toBe(true)
		end
	end)

	it("starts with one cell at the circle's middle", function()
		expect(#cells > 0).toBe(true)
		expect(cells[1].u).toBe(0)
		expect(cells[1].v).toBe(0)
	end)

	it("makes a cell gold exactly when its middle is out in the rim, between radius 13.5 and 15", function()
		local gold = 0
		for _, cell in cells do
			local radius = math.sqrt(cell.u * cell.u + cell.v * cell.v)
			expect(cell.gold).toBe(radius >= 13.5)
			expect(radius <= 15).toBe(true)
			if cell.gold then
				gold += 1
			end
		end
		expect(gold > 0).toBe(true)
		expect(gold < #cells).toBe(true)
	end)

	it("covers every point of a 0.25-stud grid inside radius 15 with a cell", function()
		local missed: { string } = {}
		for ix = -60, 60 do
			for iz = -60, 60 do
				local x, z = ix * 0.25, iz * 0.25
				if x * x + z * z <= 15 * 15 then
					local covered = false
					for _, cell in cells do
						if cellContains(cell, x, z) then
							covered = true
							break
						end
					end
					if not covered then
						table.insert(missed, `({x}, {z})`)
					end
				end
			end
		end
		expect(table.concat(missed, " ")).toBe("")
	end)

	it("keeps every corner of every cell within 15.08 studs of the middle, so the edge stays round", function()
		expect(#cells > 100).toBe(true)
		local farthest = 0
		for _, cell in cells do
			for _, alongSide in { -1, 1 } do
				for _, acrossSide in { -1, 1 } do
					local along, across = alongSide * cell.length / 2, acrossSide * cell.width / 2
					local x = cell.u - math.sin(cell.angle) * along + math.cos(cell.angle) * across
					local z = cell.v + math.cos(cell.angle) * along + math.sin(cell.angle) * across
					farthest = math.max(farthest, math.sqrt(x * x + z * z))
				end
			end
		end
		expect(farthest <= 15.08).toBe(true)
	end)

	it("has at most 128 cells, and at least 100 to cover a 30-stud circle", function()
		expect(#cells <= 128).toBe(true)
		expect(#cells >= 100).toBe(true)
	end)

	it("gives the cells of one ring the same length and the same width", function()
		expect(#cells > 100).toBe(true)
		local rings: { [string]: { length: number, width: number } } = {}
		for _, cell in cells do
			local key = string.format("%.2f", math.sqrt(cell.u * cell.u + cell.v * cell.v))
			local first = rings[key]
			if first == nil then
				rings[key] = { length = cell.length, width = cell.width }
			else
				expect(math.abs(first.length - cell.length) < 1e-9).toBe(true)
				expect(math.abs(first.width - cell.width) < 1e-9).toBe(true)
			end
		end
	end)

	it("points each ring cell's angle outward from the middle", function()
		expect(#cells > 100).toBe(true)
		for _, cell in cells do
			local radius = math.sqrt(cell.u * cell.u + cell.v * cell.v)
			if radius > 0.5 then
				expect(math.abs(math.cos(cell.angle) - cell.u / radius) < 1e-6).toBe(true)
				expect(math.abs(math.sin(cell.angle) - cell.v / radius) < 1e-6).toBe(true)
			end
		end
	end)
end)

describe("SlamCircle.new on a tilted plane", function()
	local middle = Vector3.new(5, 3, -7)
	local normal = Vector3.new(0.3, 1, -0.2).Unit
	local plane = planeSurface(middle, normal)
	local cells = SlamCircle.layout()

	-- Builds the whole circle on the plane: one piece for each cell, in the cells' order.
	local function builtPieces(): { SlamCircle.Piece }
		local pieces = buildAll(SlamCircle.new(middle, normal, plane.cast))
		expect(#cells > 100).toBe(true)
		expect(#pieces).toBe(#cells)
		return pieces
	end

	it("makes exactly one piece for each cell, with nothing split and nothing dropped", function()
		local builder = SlamCircle.new(middle, normal, plane.cast)
		local pieces = buildAll(builder)
		expect(#cells > 100).toBe(true)
		expect(#pieces).toBe(#cells)
		expect(builder.piecesMade()).toBe(#cells)
	end)

	it("is not finished after one step of 1,000 rays and finished after two", function()
		local builder = SlamCircle.new(middle, normal, plane.cast)
		expect(builder.step(RAYS_A_FRAME).finished).toBe(false)
		expect(builder.step(RAYS_A_FRAME).finished).toBe(true)
	end)

	it("uses 9 rays for each cell: one for the middle and eight for the check", function()
		local cast, rays = counted(plane.cast)
		local builder = SlamCircle.new(middle, normal, cast)
		buildAll(builder)
		expect(#cells > 100).toBe(true)
		expect(rays()).toBe(9 * #cells)
		expect(builder.raysUsed()).toBe(9 * #cells)
	end)

	it("makes each piece 0.1 longer and wider than its cell, and 0.05 thick", function()
		local pieces = builtPieces()
		for index, piece in pieces do
			expect(math.abs(piece.size.X - (cells[index].length + 0.1)) < 1e-6).toBe(true)
			expect(math.abs(piece.size.Z - (cells[index].width + 0.1)) < 1e-6).toBe(true)
			expect(math.abs(piece.size.Y - 0.05) < 1e-6).toBe(true)
		end
	end)

	it("keeps every piece within 3 studs on both sides", function()
		local pieces = builtPieces()
		for _, piece in pieces do
			expect(piece.size.X <= 3 + 1e-6).toBe(true)
			expect(piece.size.Z <= 3 + 1e-6).toBe(true)
		end
	end)

	it("puts the top of a red piece 0.12 studs above the plane and the top of a gold piece 0.11", function()
		local pieces = builtPieces()
		for index, piece in pieces do
			local top = piece.cframe.Position + piece.cframe.YVector * (piece.size.Y / 2)
			local expected = if cells[index].gold then 0.11 else 0.12
			expect(math.abs((plane.height(top) :: number) - expected) < 1e-4).toBe(true)
		end
	end)

	it("colours each piece like its cell", function()
		local pieces = builtPieces()
		for index, piece in pieces do
			expect(piece.gold).toBe(cells[index].gold)
		end
	end)

	it("tilts each piece to the plane's normal", function()
		local pieces = builtPieces()
		for _, piece in pieces do
			expectNear(piece.cframe.YVector, normal, 1e-4)
		end
	end)

	it("puts each piece over its cell's place in the circle's flat plane", function()
		local right, forward = SlamCircle.basis(normal)
		local pieces = builtPieces()
		for index, piece in pieces do
			local flat = piece.cframe.Position - normal * (piece.cframe.Position - middle):Dot(normal)
			expectNear(flat, middle + right * cells[index].u + forward * cells[index].v, 1e-3)
		end
	end)

	it("runs each piece's length along its ring, at right angles to the way out from the middle", function()
		local pieces = builtPieces()
		for index, piece in pieces do
			local out = piece.cframe.Position - middle
			out -= normal * out:Dot(normal)
			if index > 1 and out.Magnitude > 0.5 then
				expect(math.abs(piece.cframe.XVector:Dot(out.Unit)) < 1e-3).toBe(true)
			end
		end
	end)

	it("makes the circle's flat plane by the 'up' it is given, whatever that is, with no NaN", function()
		for _, up in { UP, Vector3.new(0, -1, 0), Vector3.xAxis, Vector3.zero } do
			local flat = planeSurface(Vector3.zero, if up.Magnitude > 0 then up else UP)
			local pieces = buildAll(SlamCircle.new(Vector3.zero, up, flat.cast))
			expect(#cells > 100).toBe(true)
			expect(#pieces).toBe(#cells)
			for _, piece in pieces do
				expect(piece.cframe.Position.X == piece.cframe.Position.X).toBe(true)
			end
		end
	end)
end)

describe("SlamCircle.new on a curved surface", function()
	local function expectAllNineHeightsRight(surface: Surface, pieces: { SlamCircle.Piece })
		local checked = 0
		for _, piece in pieces do
			for _, point in topPoints(piece) do
				local height = surface.height(point)
				expect(height).never.toBeNil()
				expect((height :: number) >= 0.02 - SLACK).toBe(true)
				expect((height :: number) <= 0.3 + SLACK).toBe(true)
				checked += 1
			end
		end
		expect(checked > 0).toBe(true)
	end

	it("keeps all nine points of every piece 0.02 to 0.3 studs above a hill of radius 20", function()
		local hill = ballSurface(20, false)
		local builder = SlamCircle.new(Vector3.zero, UP, hill.cast)
		local pieces = buildAll(builder)
		expect(#pieces > 100).toBe(true)
		expectAllNineHeightsRight(hill, pieces)
	end)

	it("keeps all nine points of every piece 0.02 to 0.3 studs above a bowl of radius 20", function()
		local bowl = ballSurface(20, true)
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, bowl.cast))
		expect(#pieces > 100).toBe(true)
		expectAllNineHeightsRight(bowl, pieces)
	end)

	it("splits the pieces in a bowl, where a flat piece would sink at its corners", function()
		local bowl = ballSurface(20, true)
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, bowl.cast))
		expect(#pieces > #SlamCircle.layout()).toBe(true)
	end)

	it("never makes a piece more than 3 studs on a side", function()
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, ballSurface(20, true).cast))
		for _, piece in pieces do
			expect(piece.size.X <= 3 + 1e-6 and piece.size.Z <= 3 + 1e-6).toBe(true)
		end
	end)
end)

describe("SlamCircle.new across a 60 degree fold", function()
	local fold = foldSurface()
	local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, fold.cast))

	it("splits the pieces that cross the fold, so there are more pieces than cells", function()
		expect(#pieces > #SlamCircle.layout()).toBe(true)
	end)

	it("keeps all nine points of every piece 0.02 to 0.3 studs above the surface", function()
		expect(#pieces > 100).toBe(true)
		for _, piece in pieces do
			for _, point in topPoints(piece) do
				local height = fold.height(point) :: number
				expect(height >= 0.02 - SLACK and height <= 0.3 + SLACK).toBe(true)
			end
		end
	end)

	it(
		"covers the circle's plane between 1.1 and 8 studs from the fold line, with no gap wider than half a stud",
		function()
			-- Farther out than 8 studs the surface is 4.6 studs below the circle's plane and then out of the rays' reach.
			-- The surface on each side leans 30 degrees away from the plane, so a 2.9-stud cell needs a piece of 3.35 and a
			-- piece is held to 3: a little bare strip is left between neighbours, but never half a stud.
			expect(#pieces > 100).toBe(true)
			expect(widestGapAlongX(pieces, UP, 1.1, 8) <= 0.5).toBe(true)
			expect(widestGapAlongX(pieces, UP, -8, -1.1) <= 0.5).toBe(true)
		end
	)
end)

describe("SlamCircle.new on a surface that leans away from the circle's plane", function()
	local function leaning(degrees: number): Surface
		return planeSurface(Vector3.zero, Vector3.new(math.sin(math.rad(degrees)), math.cos(math.rad(degrees)), 0))
	end

	it("leaves no gap wider than 0.3 studs on a surface leaning 20 degrees", function()
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, leaning(20).cast))
		expect(#pieces > 100).toBe(true)
		expect(widestGapAlongX(pieces, UP, -14, 14) <= 0.3).toBe(true)
	end)

	it("covers the circle's plane with no gap wider than half a stud on a surface leaning 50 degrees", function()
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, leaning(50).cast))
		expect(#pieces > 100).toBe(true)
		-- The rays reach 6 studs up and down, so the surface is found out to 6 / tan(50) = 5 studs along x.
		expect(widestGapAlongX(pieces, UP, -4.5, 4.5) <= 0.5).toBe(true)
	end)

	it("never makes a piece over 3 studs on a side, however far the surface leans", function()
		for _, degrees in { 20, 40, 60, 70 } do
			local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, leaning(degrees).cast))
			for _, piece in pieces do
				expect(piece.size.X <= 3 + 1e-6 and piece.size.Z <= 3 + 1e-6).toBe(true)
			end
		end
	end)

	it("keeps all nine points of every piece 0.02 to 0.3 studs above the surface", function()
		local lean = leaning(40)
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, lean.cast))
		expect(#pieces > 100).toBe(true)
		for _, piece in pieces do
			for _, point in topPoints(piece) do
				local height = lean.height(point) :: number
				expect(height >= 0.02 - SLACK and height <= 0.3 + SLACK).toBe(true)
			end
		end
	end)

	it("makes no piece where the surface faces away from the circle, such as the underside of something", function()
		local facingAway: SlamCircle.Cast = function(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
			return origin + direction * (origin.Y / -direction.Y), Vector3.new(0, -1, 0)
		end
		local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, facingAway))
		expect(#pieces).toBe(0)
	end)

	it("makes no piece on a surface almost at right angles to the circle's plane", function()
		local pieces, steps = buildAll(SlamCircle.new(Vector3.zero, UP, leaning(80).cast))
		expect(#pieces).toBe(0)
		expect(steps < 100).toBe(true)
	end)
end)

describe("SlamCircle.new at the edge of a surface", function()
	local edge = edgeSurface()
	local pieces = buildAll(SlamCircle.new(Vector3.zero, UP, edge.cast))

	it("makes no piece past the edge", function()
		expect(#pieces > 0).toBe(true)
		for _, piece in pieces do
			local halfLength, halfWidth = piece.size.X / 2, piece.size.Z / 2
			for _, sideA in { -1, 1 } do
				for _, sideB in { -1, 1 } do
					local corner = piece.cframe.Position
						+ piece.cframe.XVector * (sideA * halfLength)
						+ piece.cframe.ZVector * (sideB * halfWidth)
					expect(corner.X <= EDGE_X + 1e-6).toBe(true)
				end
			end
		end
	end)

	it("keeps all nine points of every piece 0.02 to 0.3 studs above the surface", function()
		expect(#pieces > 0).toBe(true)
		for _, piece in pieces do
			for _, point in topPoints(piece) do
				local height = edge.height(point)
				expect(height).never.toBeNil()
				expect((height :: number) >= 0.02 - SLACK and (height :: number) <= 0.3 + SLACK).toBe(true)
			end
		end
	end)

	it("still covers the ground well short of the edge", function()
		for _, probe in { Vector3.new(-12, 0, 0), Vector3.new(3, 0, 6), Vector3.new(0, 0, -9), Vector3.new(3.5, 0, 0) } do
			local covered = false
			for _, piece in pieces do
				local offset = probe - piece.cframe.Position
				if
					math.abs(offset:Dot(piece.cframe.XVector)) <= piece.size.X / 2
					and math.abs(offset:Dot(piece.cframe.ZVector)) <= piece.size.Z / 2
				then
					covered = true
					break
				end
			end
			expect(covered).toBe(true)
		end
	end)

	it("makes nothing at all where the surface is missing everywhere", function()
		local nothing: SlamCircle.Cast = function(_origin: Vector3, _direction: Vector3): (Vector3?, Vector3?)
			return nil, nil
		end
		local cast, rays = counted(nothing)
		local all = buildAll(SlamCircle.new(Vector3.zero, UP, cast))
		expect(#SlamCircle.layout() > 100).toBe(true)
		expect(#all).toBe(0)
		-- A cell whose middle misses is tried at its four corners, and dropped at once if they miss too: 5 rays each.
		expect(rays()).toBe(5 * #SlamCircle.layout())
	end)
end)

describe("SlamCircle.new budget", function()
	local plane = planeSurface(Vector3.zero, UP)

	it("never casts more rays in a step than it is allowed", function()
		for _, allowed in { 0, 1, 9, 10, 37, 250, 1000 } do
			local cast, rays = counted(plane.cast)
			local builder = SlamCircle.new(Vector3.zero, UP, cast)
			builder.step(allowed)
			expect(rays() <= allowed).toBe(true)
			expect(rays() >= allowed - 8).toBe(true) -- it uses what it is allowed, up to the last unfinished cell
		end
	end)

	it("makes no progress and is not finished when no rays are allowed", function()
		local cast, rays = counted(plane.cast)
		local builder = SlamCircle.new(Vector3.zero, UP, cast)
		local result = builder.step(0)
		expect(#result.pieces).toBe(0)
		expect(result.finished).toBe(false)
		expect(rays()).toBe(0)
	end)

	it("carries on where it stopped, whatever size the steps are", function()
		local small = buildAll(SlamCircle.new(Vector3.zero, UP, plane.cast), 50)
		local large = buildAll(SlamCircle.new(Vector3.zero, UP, plane.cast), 5000)
		expect(#small).toBe(#SlamCircle.layout())
		expect(#large).toBe(#SlamCircle.layout())
	end)

	it("stops at 8,000 rays on a surface that keeps failing, and says it is finished", function()
		-- Every cell fails at its last check ray (the 9th), so each try costs 9 rays and the cells split down to nothing:
		-- 125 + 500 + 2,000 tries, 23,625 rays if nothing stopped it.
		local calls = 0
		local cast: SlamCircle.Cast = function(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
			calls += 1
			if calls % 9 == 0 then
				return nil, nil
			end
			return plane.cast(origin, direction)
		end
		local builder = SlamCircle.new(Vector3.zero, UP, cast)
		local pieces = buildAll(builder)
		expect(calls <= 8000).toBe(true)
		expect(calls > 7000).toBe(true)
		expect(builder.raysUsed()).toBe(calls)
		expect(#pieces <= 700).toBe(true)
		expect(builder.step(RAYS_A_FRAME).finished).toBe(true)
		expect(calls <= 8000).toBe(true)
	end)

	it("stops at the ray limit it is given", function()
		local cast, rays = counted(plane.cast)
		local builder = SlamCircle.new(Vector3.zero, UP, cast, { maxRays = 500 })
		local pieces = buildAll(builder)
		expect(rays() <= 500).toBe(true)
		expect(rays() > 480).toBe(true)
		expect(#pieces > 0 and #pieces < #SlamCircle.layout()).toBe(true)
		expect(builder.step(RAYS_A_FRAME).finished).toBe(true)
	end)

	it("stops at the piece limit it is given", function()
		local builder = SlamCircle.new(Vector3.zero, UP, plane.cast, { maxPieces = 50 })
		local pieces = buildAll(builder)
		expect(#pieces).toBe(50)
		expect(builder.piecesMade()).toBe(50)
		expect(builder.step(RAYS_A_FRAME).finished).toBe(true)
	end)

	it("makes at most 700 pieces by default, and at most 8,000 rays", function()
		expect(SlamCircle.MAX_PIECES).toBe(700)
		expect(SlamCircle.MAX_RAYS).toBe(8000)
	end)
end)

describe("SlamCircle.new order", function()
	it("makes the middle and the inner rings first, so a half-built circle is a smaller disc", function()
		local plane = planeSurface(Vector3.zero, UP)
		local builder = SlamCircle.new(Vector3.zero, UP, plane.cast)
		local first = builder.step(300).pieces
		local rest = buildAll(builder)
		expect(#first > 10 and #first < #SlamCircle.layout()).toBe(true)
		local farthestFirst = 0
		for _, piece in first do
			farthestFirst =
				math.max(farthestFirst, Vector3.new(piece.cframe.Position.X, 0, piece.cframe.Position.Z).Magnitude)
		end
		local nearestRest = math.huge
		for _, piece in rest do
			nearestRest =
				math.min(nearestRest, Vector3.new(piece.cframe.Position.X, 0, piece.cframe.Position.Z).Magnitude)
		end
		expect(farthestFirst <= nearestRest + 1e-6).toBe(true)
	end)

	it("tries the pieces of a split cell before moving on to the next ring", function()
		local bowl = ballSurface(20, true)
		local builder = SlamCircle.new(Vector3.zero, UP, bowl.cast)
		local first = builder.step(300).pieces
		local rest = buildAll(builder)
		local farthestFirst = 0
		for _, piece in first do
			farthestFirst =
				math.max(farthestFirst, Vector3.new(piece.cframe.Position.X, 0, piece.cframe.Position.Z).Magnitude)
		end
		local nearestRest = math.huge
		for _, piece in rest do
			nearestRest =
				math.min(nearestRest, Vector3.new(piece.cframe.Position.X, 0, piece.cframe.Position.Z).Magnitude)
		end
		expect(#first > 0).toBe(true)
		-- Splits come out near their parent, so the first step is still the inner part (the rings are 2.4 studs apart).
		expect(farthestFirst <= nearestRest + 3.5).toBe(true)
	end)
end)
