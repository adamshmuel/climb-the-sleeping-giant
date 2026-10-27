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
export type Candidate = { tag: string, position: Vector3 }

local DEFAULT_MUST_FIX = 12 -- studs from a need
local DEFAULT_SQUARE = 4
local SQUARES = { 4, 8, 12, 16 } -- the far sample grows through these until it fits the room left
local DEFAULT_CAP = 200
local SIDEWAYS_LIMIT = 1.5
local DISTANCES = { 2, 3, 4, 6, 8 }
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

-- The side name of a flat direction: its larger part, as "+x", "-x", "+z" or "-z".
local function sideOf(direction: Vector3): string
	if math.abs(direction.X) >= math.abs(direction.Z) then
		return if direction.X >= 0 then "+x" else "-x"
	end
	return if direction.Z >= 0 then "+z" else "-z"
end

function PlayedList.candidates(place: Vector3, walk: Vector3?, nearest: (Vector3) -> Vector3?): { Candidate }
	local found: { Candidate } = {}
	local function try(tag: string, point: Vector3, flatWalk: Vector3?)
		local spot = nearest(point)
		if not spot then
			return
		end
		local off = Vector3.new(spot.X - point.X, 0, spot.Z - point.Z)
		-- With a walk only the sideways part counts (a step along the walk is fine); without one, the whole flat gap.
		local gap = if flatWalk then math.abs(off.X * flatWalk.Z - off.Z * flatWalk.X) else off.Magnitude
		if gap > SIDEWAYS_LIMIT then
			return
		end
		table.insert(found, { tag = tag, position = spot })
	end

	if walk and (walk.X ~= 0 or walk.Z ~= 0) then
		local flat = Vector3.new(walk.X, 0, walk.Z).Unit
		local side = sideOf(-flat)
		for _, distance in DISTANCES do
			try(`{side}{distance}`, place - flat * distance, flat)
		end
	else
		local sides = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
		for _, direction in sides do
			for _, distance in DISTANCES do
				try(`{sideOf(direction)}{distance}`, place + direction * distance, nil)
			end
		end
	end
	return found
end

return PlayedList
