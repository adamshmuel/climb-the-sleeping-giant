--!strict
-- The one way to read the slope of his side and cuffs (plan 5 Task 15a). The slide-line test, the slide-guard tests,
-- the steep-layer tests and the world script tools/world/23-steep-layer.luau all read it here, so no copy can drift.
-- It only READS the world (rays); it never changes it, and it never calls a test framework. Moved unchanged from
-- tests/server/World/RealWorld/Helpers.luau (bodySizeSlopeAt) and SlideLine.spec.luau (the walks and lists).

local WalkAreaCheck = require(script.Parent.WalkAreaCheck)

local SlideProfile = {}

-- His slope at body size (designer's rule): 25 rays 1 stud apart on a 4 by 4 stud square around the place.
local BODY_SLOPE_REACH = 2
local BODY_SLOPE_RAY_ABOVE = 150 -- the rays start this high...
local BODY_SLOPE_RAY_LENGTH = 250 -- ...and look this far down
SlideProfile.BODY_SLOPE_REACH = BODY_SLOPE_REACH
SlideProfile.BODY_SLOPE_RAY_ABOVE = BODY_SLOPE_RAY_ABOVE
SlideProfile.BODY_SLOPE_RAY_LENGTH = BODY_SLOPE_RAY_LENGTH

-- Spec 5 (docs/specs/v2/egg-nests-and-climbing.md), section 5: "Seam angle" 65 degrees.
SlideProfile.SEAM_ANGLE_DEGREES = 65
local SEAM_ANGLE_DEGREES = SlideProfile.SEAM_ANGLE_DEGREES
local SLIP_DEGREES = WalkAreaCheck.SLIP_DEGREES

-- The style guide's seam line (docs/design/v2/style-guide.md, "The seam: where walking ends", the table "Along his
-- side"): (x, y, z) of each point on his left and on his right, from z -38 to z -14.
SlideProfile.SEAM_LEFT = {
	Vector3.new(-16.5, 41.7, -38),
	Vector3.new(-18.5, 42.9, -36),
	Vector3.new(-20.5, 43.9, -34),
	Vector3.new(-22.5, 44.5, -32),
	Vector3.new(-24.5, 44.6, -30),
	Vector3.new(-26, 45.2, -28),
	Vector3.new(-29, 45.4, -24),
	Vector3.new(-31, 45.6, -20),
	Vector3.new(-32, 46.8, -16),
	Vector3.new(-32.5, 47, -14),
} :: { Vector3 }
SlideProfile.SEAM_RIGHT = {
	Vector3.new(15, 43.4, -38),
	Vector3.new(17.5, 44.4, -36),
	Vector3.new(20, 44.7, -34),
	Vector3.new(22, 45.3, -32),
	Vector3.new(24.5, 44.8, -30),
	Vector3.new(26, 45.2, -28),
	Vector3.new(29, 45.6, -24),
	Vector3.new(30.5, 46.7, -20),
	Vector3.new(31.5, 47.6, -16),
	Vector3.new(31.5, 48.9, -14),
} :: { Vector3 }
-- The same guide, on his arms (docs/design/v2/style-guide.md, "The seam: where walking ends", the cuff table, moved
-- 2026-10-20): the five points of the outer rim of each white cuff, front to back. His left has the negative x.
SlideProfile.CUFF_LEFT = {
	Vector3.new(-46.0, 39.25, -13.0),
	Vector3.new(-50.5, 39.0, -10.2),
	Vector3.new(-52.75, 39.3, -5.75),
	Vector3.new(-51.2, 39.25, -0.6),
	Vector3.new(-49.5, 39.25, 4.0),
} :: { Vector3 }
SlideProfile.CUFF_RIGHT = {
	Vector3.new(46.0, 39.25, -13.0),
	Vector3.new(50.5, 39.0, -10.2),
	Vector3.new(52.75, 39.3, -5.75),
	Vector3.new(51.2, 39.25, -0.6),
	Vector3.new(49.5, 39.25, 4.0),
} :: { Vector3 }
-- Where the strap to the cuff pockets starts (style guide, "The Epic cuff pockets", row "Strap top") and how wide it
-- is (spec 5, "A 6.2-wide strap"). The strap is walk area: a station within half its width of its start is never a fail.
SlideProfile.STRAP_START_LEFT = Vector3.new(-52, 38.3, 3.8)
SlideProfile.STRAP_START_RIGHT = Vector3.new(52, 38.3, 3.8)
local STRAP_WIDTH = 6.2
local STRAP_GAP = STRAP_WIDTH / 2
SlideProfile.STRAP_GAP = STRAP_GAP
-- The two belly pocket ledges (ArtLibrary.Mockup_Nests.Art.Pockets.BellyPocket_<side>.LedgeWalk, read 2026-11-08): centre (x, z),
-- size (x, z) and turn about Y in degrees. They are walk area: the steep layer stays off them (steepList).
local LEDGE_KEEP_OFF = 0.5 -- studs: the steep layer keeps this far off a ledge's flat footprint
SlideProfile.BELLY_LEDGES = {
	{ x = -16, z = -36.5, sizeX = 5.4, sizeZ = 4.4, yaw = 28.926 },
	{ x = 16, z = -36.5, sizeX = 5.4, sizeZ = 4.4, yaw = -30.63 },
}
-- The seam lies on one piece: the side table on body_and_cushion, each cuff rim on its arm.
SlideProfile.SIDE_PIECE = "body_and_cushion"

-- How the real line is found.
local STEP = 0.25 -- studs between the places a walk looks at
local PAST_THE_LINE = 6 -- studs a walk goes on past the first place steeper than the seam angle
local SIDE_REACH = 80 -- studs: the farthest a walk from his middle goes before giving up
local CUFF_BACK = 4 -- studs a cuff walk starts on the sleeve's top side of the rim
local CUFF_REACH = 40 -- studs: the farthest a cuff walk goes past the rim before giving up
SlideProfile.STEP = STEP
SlideProfile.PAST_THE_LINE = PAST_THE_LINE
SlideProfile.SIDE_REACH = SIDE_REACH
SlideProfile.CUFF_BACK = CUFF_BACK
SlideProfile.CUFF_REACH = CUFF_REACH

export type Place = { offset: number, position: Vector3, slope: number }
-- One walk: where the style guide says the line is, the first place steeper than the seam angle (nil if none), and
-- every place on the walk that is steeper than the seam angle (the list later keeps only those up to SLIP_DEGREES).
-- `lastSeen` is the last place whose whole square of rays hit his piece. `ranOff` says how the walk stopped: true when
-- a ray of the next square missed his piece (the square reached past the edge, the rays ran out), false when the walk
-- reached its full length. `onCuff` rows are the ones where the end of his arm counts as a place where walking ends.
export type Row = {
	name: string,
	guide: Vector3,
	first: Place?,
	steeperThanSeam: { Place },
	lastSeen: Place?,
	ranOff: boolean,
	onCuff: boolean,
	byStrap: boolean,
	strapStart: Vector3?,
}

-- The steepness in degrees of the flat plane that best fits 25 rays straight down on a 4 by 4 stud square around
-- (x, z). Gives the height of the middle ray too. Nil when a ray misses (the square reaches past what `params` sees).
-- The grid is even, so the best-fit plane comes from two sums.
local function bodySizeSlopeAt(params: RaycastParams, x: number, z: number): (number?, number?)
	local sumX, sumZ, middleY = 0, 0, 0
	for offsetX = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
		for offsetZ = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
			local hit = game:GetService("Workspace"):Raycast(
				Vector3.new(x + offsetX, BODY_SLOPE_RAY_ABOVE, z + offsetZ),
				Vector3.new(0, -BODY_SLOPE_RAY_LENGTH, 0),
				params
			)
			if hit == nil then
				return nil, nil
			end
			sumX += offsetX * hit.Position.Y
			sumZ += offsetZ * hit.Position.Y
			if offsetX == 0 and offsetZ == 0 then
				middleY = hit.Position.Y
			end
		end
	end
	-- for offsets -2 to 2 the sum of offset squared over the grid is 5 columns of (4 + 1 + 0 + 1 + 4) = 50
	local squares = (2 * BODY_SLOPE_REACH + 1)
		* (BODY_SLOPE_REACH * (BODY_SLOPE_REACH + 1) * (2 * BODY_SLOPE_REACH + 1) / 3)
	local normal = Vector3.new(-sumX / squares, 1, -sumZ / squares).Unit
	return math.deg(math.acos(math.clamp(normal.Y, -1, 1))), middleY
end
SlideProfile.bodySizeSlopeAt = bodySizeSlopeAt

-- A ray that sees only this one piece of him.
local function onlyParams(piece: Instance): RaycastParams
	local params = RaycastParams.new()
	params.IncludeInstances = { piece }
	params.RespectCanCollide = false
	return params
end
SlideProfile.onlyParams = onlyParams

-- Walks from `origin` (x and z only) along `direction` (flat, length 1), STEP studs at a time, from `fromOffset` to
-- `toOffset`. Finds the first place steeper than the seam angle, keeps going PAST_THE_LINE studs, and keeps every
-- place on the way that is steeper than the seam angle.
local function walk(
	name: string,
	guide: Vector3,
	params: RaycastParams,
	origin: Vector3,
	direction: Vector3,
	fromOffset: number,
	toOffset: number,
	onCuff: boolean
): Row
	local row: Row = {
		name = name,
		guide = guide,
		first = nil,
		steeperThanSeam = {},
		lastSeen = nil,
		ranOff = false,
		onCuff = onCuff,
		byStrap = false,
	}
	local stopAt = toOffset
	local count = math.floor((toOffset - fromOffset) / STEP + 0.5)
	for index = 0, count do
		local offset = fromOffset + index * STEP
		if offset > stopAt then
			break
		end
		local x, z = origin.X + direction.X * offset, origin.Z + direction.Z * offset
		local slope, y = bodySizeSlopeAt(params, x, z)
		if slope == nil or y == nil then
			row.ranOff = true -- the square reaches past the edge of the piece: his top ends here
			break
		end
		local place: Place = { offset = offset, position = Vector3.new(x, y, z), slope = slope }
		row.lastSeen = place
		if slope > SEAM_ANGLE_DEGREES then
			if row.first == nil then
				row.first = place
				stopAt = offset + PAST_THE_LINE
			end
			table.insert(row.steeperThanSeam, place)
		end
	end
	return row
end
SlideProfile.walk = walk

-- The 5 stations of a cuff are the style guide's 5 points. At each one, the rim's direction is the average of the two
-- flat rim pieces that meet there (stations 1 and 5 have only one piece).
function SlideProfile.cuffStations(line: { Vector3 }): { { position: Vector3, along: Vector3 } }
	local stations: { { position: Vector3, along: Vector3 } } = {}
	for index, point in line do
		local sum = Vector3.zero
		if index > 1 then
			sum += Vector3.new(point.X - line[index - 1].X, 0, point.Z - line[index - 1].Z).Unit
		end
		if index < #line then
			sum += Vector3.new(line[index + 1].X - point.X, 0, line[index + 1].Z - point.Z).Unit
		end
		table.insert(stations, { position = point, along = sum.Unit })
	end
	return stations
end

-- `sidePiece` is his body_and_cushion mesh (the caller finds it; this module never reads a test helper).
function SlideProfile.sideRows(line: { Vector3 }, sideName: string, towards: number, sidePiece: Instance): { Row }
	local params = onlyParams(sidePiece)
	local rows: { Row } = {}
	for _, point in line do
		table.insert(
			rows,
			walk(
				`{sideName} side, z {point.Z}`,
				point,
				params,
				Vector3.new(0, 0, point.Z),
				Vector3.new(towards, 0, 0),
				0,
				SIDE_REACH,
				false
			)
		)
	end
	return rows
end

-- One cuff walk from one station (a point of the rim and the rim's direction there). `params` sees only his arm.
function SlideProfile.cuffRow(
	params: RaycastParams,
	name: string,
	station: { position: Vector3, along: Vector3 },
	strapStart: Vector3
): Row
	-- across the rim, flat, at right angles to the rim line; the sleeve's top side is the side where his skin
	-- is higher 4 studs from the station, so a walk starts there and goes outward
	local across = Vector3.new(-station.along.Z, 0, station.along.X)
	local _, heightOne =
		bodySizeSlopeAt(params, station.position.X + across.X * CUFF_BACK, station.position.Z + across.Z * CUFF_BACK)
	local _, heightTwo =
		bodySizeSlopeAt(params, station.position.X - across.X * CUFF_BACK, station.position.Z - across.Z * CUFF_BACK)
	local outward = if (heightOne or -math.huge) > (heightTwo or -math.huge) then -across else across
	local row = walk(name, station.position, params, station.position, outward, -CUFF_BACK, CUFF_REACH, true)
	-- by the strap: within half the strap's width of where it starts, flat across the ground
	row.byStrap = Vector3.new(station.position.X - strapStart.X, 0, station.position.Z - strapStart.Z).Magnitude
		<= STRAP_GAP
	row.strapStart = strapStart
	return row
end

-- `armPiece` is his arm mesh (left_arm or right_arm).
function SlideProfile.cuffRows(line: { Vector3 }, cuffName: string, armPiece: Instance, strapStart: Vector3): { Row }
	local params = onlyParams(armPiece)
	local rows: { Row } = {}
	for number, station in SlideProfile.cuffStations(line) do
		table.insert(rows, SlideProfile.cuffRow(params, `{cuffName} cuff, station {number}`, station, strapStart))
	end
	return rows
end

-- The steep layer's rows (plan 5 Task 15a): a side walk at every whole z from the first to the last point of the style
-- guide's line, with x and y linear between its stations (`sideRows` only uses z).
function SlideProfile.sideSamples(line: { Vector3 }): { Vector3 }
	local samples: { Vector3 } = {}
	local first, last = math.round(line[1].Z), math.round(line[#line].Z)
	for z = first, last do
		for index = 1, #line - 1 do
			local from, to = line[index], line[index + 1]
			if z >= from.Z and z <= to.Z then
				local fraction = (z - from.Z) / (to.Z - from.Z)
				local point = from:Lerp(to, fraction)
				table.insert(samples, Vector3.new(point.X, point.Y, z))
				break
			end
		end
	end
	return samples
end

export type Station = { number: number, position: Vector3, along: Vector3 }

-- The cuff stations the steep layer walks: 1, 1.5, 2, 2.5 and 3 (stations 4 and 5 are by the strap and get none). A
-- midpoint sits halfway between its two stations, with the average of their rim directions.
function SlideProfile.cuffSamples(line: { Vector3 }): { Station }
	local stations = SlideProfile.cuffStations(line)
	local samples: { Station } = {}
	for number = 1, 3 do
		local station = stations[number]
		table.insert(samples, { number = number, position = station.position, along = station.along })
		if number < 3 then
			local after = stations[number + 1]
			table.insert(samples, {
				number = number + 0.5,
				position = station.position:Lerp(after.position, 0.5),
				along = (station.along + after.along).Unit,
			})
		end
	end
	return samples
end

-- Whether a flat place (x, z) is inside a belly pocket ledge's footprint plus LEDGE_KEEP_OFF.
local function onALedge(position: Vector3): boolean
	for _, ledge in SlideProfile.BELLY_LEDGES do
		local at = CFrame.new(ledge.x, 0, ledge.z) * CFrame.Angles(0, math.rad(ledge.yaw), 0)
		local local_ = at:PointToObjectSpace(Vector3.new(position.X, 0, position.Z))
		if
			math.abs(local_.X) <= ledge.sizeX / 2 + LEDGE_KEEP_OFF
			and math.abs(local_.Z) <= ledge.sizeZ / 2 + LEDGE_KEEP_OFF
		then
			return true
		end
	end
	return false
end

-- The cloth of one walk that is steeper than the seam angle but that a character still walks on in Play (no steeper
-- than SLIP_DEGREES, and only up to the first place that is). Two lists: the places for the steep layer, and the places
-- in the strap's mouth (within half the strap's width of where it starts), which are walk area and get no steep layer.
-- Places on a belly pocket ledge's footprint (plus LEDGE_KEEP_OFF) are left out of both lists.
function SlideProfile.steepList(row: Row): ({ Place }, { Place })
	local forSteepLayer: { Place } = {}
	local inTheMouth: { Place } = {}
	for _, place in row.steeperThanSeam do
		local start = row.strapStart
		if place.slope > SLIP_DEGREES then
			break -- a character slips here in Play: this and everything farther on is not cloth they walk on
		end
		if onALedge(place.position) then
			continue -- a belly pocket ledge is walk area: no steep layer over it
		end
		if
			start ~= nil
			and Vector3.new(place.position.X - start.X, 0, place.position.Z - start.Z).Magnitude <= STRAP_GAP
		then
			table.insert(inTheMouth, place)
		else
			table.insert(forSteepLayer, place)
		end
	end
	return forSteepLayer, inTheMouth
end

return SlideProfile
