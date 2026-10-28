--!strict
-- The played list (stuck safety Task 45, step 1): which spots of the steep list a Play job tries, how the far ones are
-- sampled, how each is labelled, and where to start from at a known hang place. Pure: no services, no world.
export type Item = { kind: string, position: Vector3, slope: number? }
export type Options = {
	distanceToNeeds: (Vector3) -> number,
	onGiant: (Vector3) -> boolean,
	mustFix: number?,
	square: number?,
	cap: number?,
}
export type Played = { label: string, position: Vector3 }
export type Counts = { core: number, reach: number, far: number, sampled: number, square: number, played: number }
export type Group = { played: { Played }, counts: Counts, stop: string? }

local DEFAULT_MUST_FIX = 12 -- studs from a need
local DEFAULT_SQUARE = 4
local SQUARES = { 4, 8, 12, 16 } -- the far sample grows through these until it fits the room left
local DEFAULT_CAP = 200
local SLOPE_STEP = 1e-3 -- degrees: slopes this close count as tied

local PlayedList = {}

type Sorted = { core: { Item }, reach: { Item }, far: { Item } }
type Sample = { item: Item, name: string, x: number, z: number }

-- The first far spot of each square, in list order (the list is steepest first).
local function sampleFar(far: { Item }, square: number): { Sample }
	local seen: { [string]: boolean } = {}
	local sampled: { Sample } = {}
	for _, item in far do
		local x = math.floor(item.position.X / square) * square
		local z = math.floor(item.position.Z / square) * square
		local name = `{x},{z}`
		if not seen[name] then
			seen[name] = true
			table.insert(sampled, { item = item, name = name, x = x, z = z })
		end
	end
	return sampled
end

local function slopeStep(sample: Sample): number
	return math.floor((sample.item.slope or 0) / SLOPE_STEP + 0.5)
end

-- The steepest first; ties by the spot's x, then its z.
local function steeper(a: Sample, b: Sample): boolean
	local slopeA, slopeB = slopeStep(a), slopeStep(b)
	if slopeA ~= slopeB then
		return slopeA > slopeB
	end
	if a.item.position.X ~= b.item.position.X then
		return a.item.position.X < b.item.position.X
	end
	return a.item.position.Z < b.item.position.Z
end

function PlayedList.group(list: { Item }, options: Options): Group
	local mustFix = options.mustFix or DEFAULT_MUST_FIX
	local cap = options.cap or DEFAULT_CAP
	local sorted: Sorted = { core = {}, reach = {}, far = {} }
	for _, item in list do
		if item.kind == "guard" or options.distanceToNeeds(item.position) <= mustFix then
			table.insert(sorted.core, item)
		elseif not options.onGiant(item.position) then
			table.insert(sorted.reach, item)
		else
			table.insert(sorted.far, item)
		end
	end

	local counts: Counts = {
		core = #sorted.core,
		reach = #sorted.reach,
		far = #sorted.far,
		sampled = 0,
		square = options.square or DEFAULT_SQUARE,
		played = 0,
	}
	-- Core and out of reach spots are always played, so the far samples only get what they leave.
	local room = cap - counts.core - counts.reach
	if room < 0 then
		local reason = `no room: core {counts.core} + out of reach {counts.reach} is over the cap of {cap}`
		return { played = {}, counts = counts, stop = reason }
	end

	local sampled: { Sample } = {}
	for _, square in SQUARES do
		if square >= (options.square or DEFAULT_SQUARE) then
			counts.square = square
			sampled = sampleFar(sorted.far, square)
			if #sampled <= room then
				break
			end
		end
	end
	counts.sampled = #sampled
	if #sampled > room then
		-- Even the widest squares give too many: keep the steepest that fit.
		table.sort(sampled, steeper)
		sampled = table.move(sampled, 1, room, 1, {})
	end

	local played: { Played } = {}
	local function add(prefix: string, item: Item, suffix: string)
		table.insert(
			played,
			{ label = string.format("%s-%03d%s", prefix, #played + 1, suffix), position = item.position }
		)
	end
	for _, item in sorted.core do
		add("C", item, "")
	end
	for _, item in sorted.reach do
		add("R", item, "")
	end
	for _, sample in sampled do
		add("F", sample.item, ` sq {sample.name}`)
	end
	counts.played = #played
	return { played = played, counts = counts }
end

export type Point = { tag: string, position: Vector3, distance: number? }
export type Check = { open: boolean, position: Vector3?, blockers: { string } }

local BACK_DISTANCES = { 2, 3, 4, 6, 8 } -- studs behind a place (or beside it, with no walk)
local START_LIFT = 3 -- studs: a start is this far over the open feet
local HEIGHT_SLACK = 1 -- studs: a walk-in start's feet may differ from the place by its distance plus this

-- The side a flat direction mostly points to: "+x", "-x", "+z" or "-z".
local function sideOf(flat: Vector3): string
	if math.abs(flat.X) >= math.abs(flat.Z) then
		return if flat.X >= 0 then "+x" else "-x"
	end
	return if flat.Z >= 0 then "+z" else "-z"
end

local function pointAt(place: Vector3, flat: Vector3, tag: string, distance: number): Point
	local offset = flat * distance + Vector3.new(0, distance, 0)
	return { tag = tag .. tostring(distance), position = place + offset, distance = distance }
end

-- Tries to start a walk into `place`, nearest first. With a walk direction: only behind it, raised by their distance
-- so ground that rises toward the place is still under the start check's rays. With no walk: all four sides.
function PlayedList.backPoints(place: Vector3, walk: Vector3?): { Point }
	local points: { Point } = {}
	local flat = if walk then Vector3.new(walk.X, 0, walk.Z) else nil
	if flat and flat.Magnitude > 1e-6 then
		local back = -flat.Unit
		for _, distance in BACK_DISTANCES do
			table.insert(points, pointAt(place, back, sideOf(back), distance))
		end
		return points
	end
	local sides: { { name: string, flat: Vector3 } } = {
		{ name = "+x", flat = Vector3.new(1, 0, 0) },
		{ name = "-x", flat = Vector3.new(-1, 0, 0) },
		{ name = "+z", flat = Vector3.new(0, 0, 1) },
		{ name = "-z", flat = Vector3.new(0, 0, -1) },
	}
	for _, side in sides do
		for _, distance in BACK_DISTANCES do
			table.insert(points, pointAt(place, side.flat, side.name, distance))
		end
	end
	return points
end

-- The first point the start check finds open twice (at the point, then START_LIFT over the found feet). The returned
-- point's `position` is the start. A walk-in point (one with a distance) must have its feet near the place's height.
function PlayedList.firstOpen(points: { Point }, placeY: number, find: (Vector3) -> Check): (Point?, string?)
	local firstReason: string? = nil
	for _, point in points do
		local reason: string? = nil
		local first = find(point.position)
		local feet = first.position
		if not first.open or not feet then
			reason = first.blockers[1] or "none"
		elseif point.distance and math.abs(feet.Y - placeY) > point.distance + HEIGHT_SLACK then
			reason = "height"
		else
			local start = feet + Vector3.new(0, START_LIFT, 0)
			local second = find(start)
			if second.open then
				return { tag = point.tag, position = start, distance = point.distance }, nil
			end
			reason = second.blockers[1] or "none"
		end
		if not firstReason then
			firstReason = if point.tag == "" then reason else `{point.tag} {reason}`
		end
	end
	return nil, firstReason or "no points"
end

return PlayedList
