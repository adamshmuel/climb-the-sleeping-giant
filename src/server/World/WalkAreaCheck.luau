--!strict
-- The walk-area check (plan 5 Task 14; spec 5 "Seam angle", "Seam match", "Walk surface over what you see"; Rules 79
-- and 80): is every place a player can walk on the giant fit to walk on, and does the seam line mark where walking
-- ends? Pure checks on a PathCheck walk map plus rays; they run only in tests, never per frame.
--
-- The walk area is a list of spot ids. Each check returns a list of problems, empty when the check passes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(script.Parent.PathCheck)

export type Problem = { kind: string, position: Vector3, detail: string }

local WalkAreaCheck = {}

-- Spec 5 "Seam angle": a walk surface is under this many degrees from level.
WalkAreaCheck.SEAM_DEGREES = Config.Nests.SeamDegrees
-- The steepness at which a player slips off (the slide line's number; SlideLine.spec.luau reads it from here).
WalkAreaCheck.SLIP_DEGREES = 78

local FLOAT_LIMIT = Config.Nests.WalkSurfaceAbove -- studs: the visible surface this far below the feet or more is "floating"
local SUNK_LIMIT = Config.Nests.WalkSurfaceBelow -- studs: the visible surface this far above the feet or more is "sunk"
local LOOK_ABOVE = 1 -- studs: the look for the visible surface starts this far above the feet
local GAP_REACH = 1.5 -- studs: a sample with no walk-area spot this close is a gap
local STITCH_REACH = Config.Nests.SeamMatch -- studs: the seam match looks this far uphill and downhill of a stitch
local STITCH_RAY_ABOVE = 3 -- studs: the seam match's ray down starts this far above the stitch...
local STITCH_RAY_LENGTH = 200 -- ...and reaches this far down

local NO_LINKS: { PathCheck.Link } = {}
local NO_POSITIONS: { Vector3 } = {}

local function degreesFromLevel(normal: Vector3): number
	return math.deg(math.acos(math.clamp(normal.Unit.Y, -1, 1)))
end

local function problem(kind: string, position: Vector3, detail: string): Problem
	return { kind = kind, position = position, detail = detail }
end

-- The spots a player can walk to from `starts` by walk links only (no climb, no slide), keeping the ones where
-- isBelly says yes; plus every spot where alsoIn says yes (the cuff spots). Spot ids, lowest first.
function WalkAreaCheck.walkArea(
	map: PathCheck.WalkMap,
	starts: { number },
	isBelly: (Vector3) -> boolean,
	alsoIn: (PathCheck.Spot) -> boolean
): { number }
	local inArea: { [number]: boolean } = {}
	local queue: { number } = {}
	for _, id in starts do
		if not inArea[id] and isBelly(map.spots[id].position) then
			inArea[id] = true
			table.insert(queue, id)
		end
	end
	local head = 1
	while head <= #queue do
		local id = queue[head]
		head += 1
		for _, link in map.links[id] or NO_LINKS do
			if link.kind == "Walk" and not inArea[link.to] and isBelly(map.spots[link.to].position) then
				inArea[link.to] = true
				table.insert(queue, link.to)
			end
		end
	end
	for _, spot in map.spots do
		if alsoIn(spot) then
			inArea[spot.id] = true
		end
	end
	local ids: { number } = {}
	for id in inArea do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- A spot whose up is SEAM_DEGREES or more from straight up.
function WalkAreaCheck.tooSteep(map: PathCheck.WalkMap, area: { number }): { Problem }
	local found: { Problem } = {}
	for _, id in area do
		local spot = map.spots[id]
		local degrees = degreesFromLevel(spot.up)
		if degrees >= WalkAreaCheck.SEAM_DEGREES then
			table.insert(found, problem("too steep", spot.position, `{math.round(degrees * 10) / 10} degrees`))
		end
	end
	return found
end

-- The visible surface under the feet against the feet. Spots on his skin are left out (the skin is what is drawn), and
-- so is every spot `skipSpot` says yes to (the ramp and curb spots whose cover the rays cannot see; Task 15g).
function WalkAreaCheck.floatingOrSunk(
	map: PathCheck.WalkMap,
	area: { number },
	visibleHeightAt: (number, number, number) -> number?,
	onSkin: (BasePart) -> boolean,
	skipSpot: ((PathCheck.Spot) -> boolean)?
): { Problem }
	local found: { Problem } = {}
	for _, id in area do
		local spot = map.spots[id]
		if not onSkin(spot.standsOn) and not (skipSpot ~= nil and skipSpot(spot)) then
			local position = spot.position
			local seen = visibleHeightAt(position.X, position.Z, position.Y + LOOK_ABOVE)
			if seen == nil then
				table.insert(found, problem("floating", position, "no visible surface under the feet"))
			elseif position.Y - seen > FLOAT_LIMIT then
				table.insert(
					found,
					problem("floating", position, `{math.round((position.Y - seen) * 100) / 100} above`)
				)
			elseif seen - position.Y > SUNK_LIMIT then
				table.insert(found, problem("sunk", position, `{math.round((seen - position.Y) * 100) / 100} below`))
			end
		end
	end
	return found
end

-- A visible walk surface point with no walk-area spot within GAP_REACH (3D). Walk-area spots are put in buckets
-- GAP_REACH wide first, so each sample looks at nine buckets, not at the whole area. A sample `skip` says yes to is
-- not counted (the cut parts of the body and the sleeves; Task 15g).
function WalkAreaCheck.gaps(
	map: PathCheck.WalkMap,
	area: { number },
	samples: { Vector3 },
	skip: ((Vector3) -> boolean)?
): { Problem }
	local buckets: { [string]: { Vector3 } } = {}
	for _, id in area do
		local position = map.spots[id].position
		local key = `{math.floor(position.X / GAP_REACH)},{math.floor(position.Z / GAP_REACH)}`
		local bucket = buckets[key] or {}
		buckets[key] = bucket
		table.insert(bucket, position)
	end
	local found: { Problem } = {}
	for _, sample in samples do
		local bx, bz = math.floor(sample.X / GAP_REACH), math.floor(sample.Z / GAP_REACH)
		local covered = skip ~= nil and skip(sample)
		for dx = -1, 1 do
			for dz = -1, 1 do
				local bucket: { Vector3 } = buckets[`{bx + dx},{bz + dz}`] or NO_POSITIONS
				for _, position in bucket do
					if (position - sample).Magnitude <= GAP_REACH then
						covered = true
					end
				end
			end
		end
		if not covered then
			table.insert(found, problem("gap", sample, "no walk-area spot within reach"))
		end
	end
	return found
end

-- A spot that is not in the Belly zone.
function WalkAreaCheck.zones(map: PathCheck.WalkMap, area: { number }, zoneOf: (Vector3) -> string): { Problem }
	local found: { Problem } = {}
	for _, id in area do
		local spot = map.spots[id]
		local zone = zoneOf(spot.position)
		if zone ~= "Belly" then
			table.insert(found, problem("zone", spot.position, zone))
		end
	end
	return found
end

-- The first solid surface a ray finds going down at x, z from `fromY`, or nil.
local function surfaceAt(world: WorldRoot, params: RaycastParams, x: number, z: number, fromY: number): RaycastResult?
	return world:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -STITCH_RAY_LENGTH, 0), params)
end

-- Each stitch of the seam line sits where walking ends: one stud uphill the surface is walkable (under SEAM_DEGREES,
-- not in the steep layer), one stud downhill it is the steep layer or steeper than SLIP_DEGREES. "Downhill" is the flat
-- part of the surface normal under the stitch.
function WalkAreaCheck.seamMatch(world: WorldRoot, stitches: { Vector3 }?, steepLayer: Instance?): { Problem }
	if stitches == nil or #stitches == 0 then
		return { problem("seam match", Vector3.zero, "no seam built yet") }
	end
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local found: { Problem } = {}
	for _, stitch in stitches do
		local fromY = stitch.Y + STITCH_RAY_ABOVE
		local under = surfaceAt(world, params, stitch.X, stitch.Z, fromY)
		local flat = if under ~= nil then Vector3.new(under.Normal.X, 0, under.Normal.Z) else Vector3.zero
		if under == nil or flat.Magnitude < 1e-3 then
			table.insert(found, problem("seam match", stitch, "no slope under the stitch to say which way is downhill"))
		else
			local downhill = flat.Unit
			local up = surfaceAt(
				world,
				params,
				stitch.X - downhill.X * STITCH_REACH,
				stitch.Z - downhill.Z * STITCH_REACH,
				fromY
			)
			local down = surfaceAt(
				world,
				params,
				stitch.X + downhill.X * STITCH_REACH,
				stitch.Z + downhill.Z * STITCH_REACH,
				fromY
			)
			if
				up == nil
				or degreesFromLevel(up.Normal) >= WalkAreaCheck.SEAM_DEGREES
				or (steepLayer ~= nil and up.Instance:IsDescendantOf(steepLayer))
			then
				table.insert(found, problem("seam match", stitch, "1 stud uphill is not a walk surface"))
			elseif
				down == nil
				or not (
					(steepLayer ~= nil and down.Instance:IsDescendantOf(steepLayer))
					or degreesFromLevel(down.Normal) > WalkAreaCheck.SLIP_DEGREES
				)
			then
				table.insert(found, problem("seam match", stitch, "1 stud downhill is not steep enough to slip"))
			end
		end
	end
	return found
end

return WalkAreaCheck
