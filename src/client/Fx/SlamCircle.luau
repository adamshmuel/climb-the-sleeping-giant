--!strict
-- The red slam circle as small pieces that hug the surface under it (spec Rule 13, style guide "The slams", row "Circle
-- follows the surface (everywhere)"). This module is pure maths: no Workspace, no instances, no clock. The ray that finds
-- the surface is passed in as a function, so tests can give it maths surfaces.
--
-- The circle is laid out as rings of cells in its own flat plane (so the edge stays round): one cell in the middle, five
-- rings of red out to radius 13.5, and one ring of gold from 13.5 to 15 (the rim). Every cell is turned so its length runs
-- along its ring. Each cell becomes a thin block (a piece) that sits on the real surface under it, tilted to match it.
-- A piece that does not lie close enough to the surface at nine places is split into four smaller cells and tried again,
-- or dropped if it is already small.

local SlamCircle = {}

export type Cell = {
	u: number, -- studs from the circle's middle, along `right` in the circle's flat plane
	v: number, -- studs from the circle's middle, along `forward` in the circle's flat plane
	angle: number, -- the ring's outward direction here, in radians from `right` towards `forward`
	length: number, -- studs along the ring
	width: number, -- studs across the ring
	gold: boolean,
}

export type Piece = {
	cframe: CFrame, -- X runs along the piece's length, Y is its top (the surface's normal), Z runs across
	size: Vector3, -- length, thickness, width
	gold: boolean,
}

-- A ray: gives where it hit and the surface's normal there, or nil twice for no hit. `direction` includes the length.
export type Cast = (origin: Vector3, direction: Vector3) -> (Vector3?, Vector3?)

-- Lower limits than the defaults, for tests.
export type Limits = {
	maxRays: number?,
	maxPieces: number?,
}

export type StepResult = {
	pieces: { Piece }, -- the pieces made in this step
	finished: boolean, -- true when the circle is complete, or its budget has run out
}

export type Builder = {
	step: (raysAllowed: number) -> StepResult,
	raysUsed: () -> number,
	piecesMade: () -> number,
}

-- The circle: red out to this radius, then a gold rim to the next one (30 studs across, a 1.5-stud rim).
SlamCircle.RED_RADIUS = 13.5
SlamCircle.RIM_RADIUS = 15
-- No cell is more than this many studs on a side, so a piece (a cell plus 0.05 each side) is never over 3.
SlamCircle.MAX_CELL = 2.9
-- A circle is complete at about 125 cells. This budget (rays and pieces) ends a circle that keeps failing, like a bumpy
-- surface, so building it can never go on for ever.
SlamCircle.MAX_RAYS = 8000
SlamCircle.MAX_PIECES = 700
-- The most rays one cell can use: one for its middle and eight for the check. A step only starts a cell when it has these.
SlamCircle.RAYS_PER_CELL = 9
SlamCircle.PIECE_THICKNESS = 0.05
-- A piece is its cell plus this much on every side, so neighbours overlap and no seam opens.
SlamCircle.PIECE_MARGIN = 0.05
-- How high the top of a piece sits above the surface: red 0.01 above gold where they overlap at the rim.
SlamCircle.RED_ABOVE_SURFACE = 0.12
SlamCircle.GOLD_ABOVE_SURFACE = 0.11
-- The top of a piece must be this high above the surface at all nine places: never buried, never floating.
SlamCircle.MIN_ABOVE_SURFACE = 0.02
SlamCircle.MAX_ABOVE_SURFACE = 0.3

local RED_RADIUS = SlamCircle.RED_RADIUS
local RIM_RADIUS = SlamCircle.RIM_RADIUS
local MAX_CELL = SlamCircle.MAX_CELL
local RAYS_PER_CELL = SlamCircle.RAYS_PER_CELL
local THICKNESS = SlamCircle.PIECE_THICKNESS
local MARGIN = SlamCircle.PIECE_MARGIN
-- No piece is more than this many studs on a side (a cell and its margin).
local MAX_PIECE = MAX_CELL + 2 * MARGIN + 1e-6
-- A cell on a leaning surface may be covered by a piece that is this much shorter than the surface part it should cover
-- (the piece is held to 3 studs), so no gap between neighbours gets wider than this.
local MAX_UNCOVERED = 0.5
-- A surface that leans away from the circle's plane by more than this (the cosine of the angle between its normal and
-- the circle's up, about 78 degrees) is too steep to cover with pieces of up to 3 studs: the cell is split, then dropped.
local MIN_LEAN_COSINE = 0.2
local MIN_HEIGHT = SlamCircle.MIN_ABOVE_SURFACE - 1e-6
local MAX_HEIGHT = SlamCircle.MAX_ABOVE_SURFACE + 1e-6

-- A cell is split only while it is at least this many studs on one side; a smaller one that fails is dropped.
local SPLIT_ABOVE = 1
-- Where the rays for a cell start and how far they go, along the circle's up: 6 studs above the plane, 12 down.
local CAST_UP = 6
local CAST_DOWN = 12
-- The check: from 1 stud above a point on the top face, 2 studs down along the piece's up.
local CHECK_UP = 1
local CHECK_DOWN = 2

-- The red rings are all as wide as a cell can be (MAX_CELL), laid over each other a little so there are no gaps where
-- the cells of a ring meet. The rings start after a centre cell of MAX_CELL and run out to RED_RADIUS.
local RED_RINGS = 5
-- The gold rim cells reach this far in under the red (the red is 0.01 higher), so no sliver is left between them.
local RIM_REACH_IN = 0.2
-- How many cells a red ring needs. Its cells are MAX_CELL long and sit side by side round the ring. Between two
-- neighbours a thin wedge opens that gets wider towards the ring's outer edge. The ring outside it reaches in over
-- `overlap` studs and covers the wedge there, so the cells only have to meet at `radius`, which is the ring's outer
-- radius less that overlap.
local function cellsInRing(radius: number): number
	return math.ceil(2 * math.pi * radius / MAX_CELL)
end

local layoutCells: { Cell }? = nil

-- The cells of a circle, from the middle out: the centre cell, the red rings, then the gold rim. They are in the circle's
-- flat plane: (u, v) is the cell's middle, `angle` the way out from the middle there. The same for every circle.
function SlamCircle.layout(): { Cell }
	local made = layoutCells
	if made ~= nil then
		return made
	end
	local cells: { Cell } = {}
	table.insert(cells, { u = 0, v = 0, angle = 0, length = MAX_CELL, width = MAX_CELL, gold = false })

	local centreHalf = MAX_CELL / 2
	local bandWidth = (RED_RADIUS - centreHalf) / RED_RINGS
	local width = MAX_CELL
	local overlap = width - bandWidth
	for ring = 1, RED_RINGS do
		local outer = centreHalf + ring * bandWidth
		local middleRadius = outer - width / 2
		local count = cellsInRing(outer - overlap)
		-- Every other ring is turned half a step, so the places where cells meet do not line up.
		local turn = if ring % 2 == 0 then math.pi / count else 0
		for index = 0, count - 1 do
			local angle = 2 * math.pi * index / count + turn
			table.insert(cells, {
				u = middleRadius * math.cos(angle),
				v = middleRadius * math.sin(angle),
				angle = angle,
				length = MAX_CELL,
				width = width,
				gold = false,
			})
		end
	end

	local rimWidth = RIM_RADIUS - RED_RADIUS + RIM_REACH_IN
	local rimMiddle = RIM_RADIUS - rimWidth / 2
	-- The rim's cells meet at its outer edge, so they are counted there.
	local rimCount = math.ceil(math.pi / math.asin(MAX_CELL / (2 * RIM_RADIUS)))
	for index = 0, rimCount - 1 do
		local angle = 2 * math.pi * index / rimCount
		table.insert(cells, {
			u = rimMiddle * math.cos(angle),
			v = rimMiddle * math.sin(angle),
			angle = angle,
			length = MAX_CELL,
			width = rimWidth,
			gold = true,
		})
	end
	layoutCells = cells
	return cells
end

-- Two directions at right angles to `up` and to each other, that turn the layout's (u, v) into the circle's plane.
function SlamCircle.basis(up: Vector3): (Vector3, Vector3)
	local unit = if up.Magnitude > 1e-6 then up.Unit else Vector3.yAxis
	-- Any direction that isn't (nearly) along `up` will do; straight up is the usual one, so a circle whose up is
	-- straight up or down needs another.
	local helper = if math.abs(unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	local right = unit:Cross(helper).Unit
	local forward = right:Cross(unit)
	return right, forward
end

-- The places on a top face that are checked, as (steps along the length, steps across the width) where one step is half
-- the side: the four corners first (they fail first), then the middle of each side. The ninth place, the middle, always
-- passes: the piece sits exactly 0.12 (or 0.11) studs above the ray that found it, so it is not cast again.
local CHECK_PLACES = {
	{ 1, 1 },
	{ 1, -1 },
	{ -1, 1 },
	{ -1, -1 },
	{ 1, 0 },
	{ -1, 0 },
	{ 0, 1 },
	{ 0, -1 },
}

-- Makes the builder for one circle: `middle` is where its middle lies on the surface, `up` which way the circle's flat
-- plane faces, and `cast` finds the surface. Call `step(raysAllowed)` once a frame: it works through the cells, from the
-- middle outward, and gives back the new pieces and whether the circle is finished.
function SlamCircle.new(middle: Vector3, up: Vector3, cast: Cast, limits: Limits?): Builder
	local circleUp = if up.Magnitude > 1e-6 then up.Unit else Vector3.yAxis
	local right, forward = SlamCircle.basis(circleUp)
	local maxRays = if limits ~= nil and limits.maxRays ~= nil then limits.maxRays else SlamCircle.MAX_RAYS
	local maxPieces = if limits ~= nil and limits.maxPieces ~= nil then limits.maxPieces else SlamCircle.MAX_PIECES

	local layout = SlamCircle.layout()
	local nextCell = 1
	-- Cells made by splitting; tried before the next layout cell, nearest the middle first, so a half-built circle is
	-- still a smaller disc.
	local splits: { Cell } = {}
	local raysUsed = 0
	local piecesMade = 0
	local finished = false

	local function ray(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
		raysUsed += 1
		return cast(origin, direction)
	end

	-- A point in the circle's flat plane, `u` along right and `v` along forward from the middle.
	local function planePoint(u: number, v: number): Vector3
		return middle + right * u + forward * v
	end

	-- The ray that finds the surface under a point of the plane: from above, down through it.
	local function castDown(point: Vector3): (Vector3?, Vector3?)
		return ray(point + circleUp * CAST_UP, -circleUp * CAST_DOWN)
	end

	local function isUsable(position: Vector3?, normal: Vector3?): boolean
		return position ~= nil and normal ~= nil and normal.Magnitude > 1e-6
	end

	-- Cuts a cell into four, half the length and half the width, and puts them first in line (nearest the middle first).
	local function split(cell: Cell)
		local alongU, alongV = -math.sin(cell.angle), math.cos(cell.angle)
		local acrossU, acrossV = math.cos(cell.angle), math.sin(cell.angle)
		local children: { Cell } = {}
		for _, alongSide in { -1, 1 } do
			for _, acrossSide in { -1, 1 } do
				local along, across = alongSide * cell.length / 4, acrossSide * cell.width / 4
				table.insert(children, {
					u = cell.u + alongU * along + acrossU * across,
					v = cell.v + alongV * along + acrossV * across,
					angle = cell.angle,
					length = cell.length / 2,
					width = cell.width / 2,
					gold = cell.gold,
				})
			end
		end
		table.sort(children, function(first: Cell, second: Cell): boolean
			return first.u * first.u + first.v * first.v < second.u * second.u + second.v * second.v
		end)
		for index = #children, 1, -1 do
			table.insert(splits, children[index])
		end
	end

	-- A cell that failed: cut in four, or dropped if it is already small.
	local function fail(cell: Cell)
		if cell.length < SPLIT_ABOVE and cell.width < SPLIT_ABOVE then
			return
		end
		split(cell)
	end

	-- Tries one cell: finds the surface under its middle, puts the piece there and checks it at nine places. Gives the
	-- piece, or nil (and the cell has been split or dropped).
	local function attempt(cell: Cell): Piece?
		local centre = planePoint(cell.u, cell.v)
		-- The cell's two directions in the circle's plane: along the ring, and out from the middle.
		local ringDirection = right * -math.sin(cell.angle) + forward * math.cos(cell.angle)
		local outDirection = right * math.cos(cell.angle) + forward * math.sin(cell.angle)
		local hit, hitNormal = castDown(centre)
		if hit == nil or hitNormal == nil or not isUsable(hit, hitNormal) then
			-- Nothing under the middle: look under the four corners. All four empty means no surface here at all.
			for _, alongSide in { -1, 1 } do
				for _, acrossSide in { -1, 1 } do
					local corner = centre
						+ ringDirection * (alongSide * cell.length / 2)
						+ outDirection * (acrossSide * cell.width / 2)
					local cornerHit, cornerNormal = castDown(corner)
					if isUsable(cornerHit, cornerNormal) then
						fail(cell)
						return nil
					end
				end
			end
			return nil
		end

		local normal = hitNormal.Unit
		-- The surface may lean away from the circle's flat plane. The piece has to cover the part of the surface that lies
		-- under the cell, looking straight down along `up`, and that part is longer than the cell on a lean. So the cell's
		-- two directions are carried along `up` onto the surface, and the piece is the smallest rectangle that holds them,
		-- with its length along the ring. A piece is never over 3 studs, so a cell that needs more than that is covered as
		-- far as 3 studs reach, as long as no more than MAX_UNCOVERED studs are left bare. A cell that needs more is
		-- split in four (smaller cells need less) and tried again.
		local leans = circleUp:Dot(normal)
		if leans < MIN_LEAN_COSINE then
			fail(cell)
			return nil
		end
		local function carried(direction: Vector3): Vector3
			return direction - circleUp * (direction:Dot(normal) / leans)
		end
		local alongOnSurface = carried(ringDirection)
		local acrossOnSurface = carried(outDirection)
		local along = alongOnSurface.Unit
		local across = along:Cross(normal)
		local halfLength = cell.length / 2 * alongOnSurface.Magnitude
			+ cell.width / 2 * math.abs(acrossOnSurface:Dot(along))
		local halfWidth = cell.width / 2 * math.abs(acrossOnSurface:Dot(across))
		local wantedLength, wantedWidth = 2 * halfLength + 2 * MARGIN, 2 * halfWidth + 2 * MARGIN
		if wantedLength > MAX_PIECE + MAX_UNCOVERED or wantedWidth > MAX_PIECE + MAX_UNCOVERED then
			fail(cell)
			return nil
		end
		local size = Vector3.new(math.min(wantedLength, MAX_PIECE), THICKNESS, math.min(wantedWidth, MAX_PIECE))

		local above = if cell.gold then SlamCircle.GOLD_ABOVE_SURFACE else SlamCircle.RED_ABOVE_SURFACE
		local position = hit + normal * (above - THICKNESS / 2)
		local topCentre = position + normal * (THICKNESS / 2)
		for _, place in CHECK_PLACES do
			local point = topCentre + along * (place[1] * size.X / 2) + across * (place[2] * size.Z / 2)
			local below = ray(point + normal * CHECK_UP, -normal * CHECK_DOWN)
			if below == nil then
				fail(cell)
				return nil
			end
			local height = (point - below):Dot(normal)
			if height < MIN_HEIGHT or height > MAX_HEIGHT then
				fail(cell)
				return nil
			end
		end
		return { cframe = CFrame.fromMatrix(position, along, normal, across), size = size, gold = cell.gold }
	end

	local function step(raysAllowed: number): StepResult
		local made: { Piece } = {}
		local startRays = raysUsed
		while not finished do
			local cell: Cell? = splits[#splits] or layout[nextCell]
			if cell == nil or piecesMade >= maxPieces or raysUsed + RAYS_PER_CELL > maxRays then
				finished = true
				break
			end
			if raysUsed - startRays + RAYS_PER_CELL > raysAllowed then
				break
			end
			if #splits > 0 then
				table.remove(splits)
			else
				nextCell += 1
			end
			local piece = attempt(cell)
			if piece ~= nil then
				piecesMade += 1
				table.insert(made, piece)
			end
		end
		return { pieces = made, finished = finished }
	end

	return {
		step = step,
		raysUsed = function(): number
			return raysUsed
		end,
		piecesMade = function(): number
			return piecesMade
		end,
	}
end

return SlamCircle
