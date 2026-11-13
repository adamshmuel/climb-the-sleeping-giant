--!strict
-- The shared start check (stuck safety Task 27): is the place where a walk, a check or a camera is about to
-- start open, with nothing of a mesh around it? A ray never hits the part it starts in, so a start inside a mesh looks
-- "clear" to rays. This asks a body-sized probe instead, with GetPartsInPart, which uses the real shapes (never
-- GetPartBoundsInBox: it compares rough outer boxes, so near the giant every spot looks closed).
--
-- `find(spot, root)` shoots 5 rays down from RAY_ABOVE studs over `spot` (the centre and the 4 corners of a
-- FOOTPRINT x FOOTPRINT square), then sets the probe's bottom PROBE_LIFT over the highest hit. If something overlaps
-- the probe, it moves STEP studs downhill (toward the lowest of the 5 hits) and tries again, at most MAX_MOVES times,
-- then says "not open" and names up to MAX_BLOCKERS parts in the way.
-- On steep ground the uphill corners start inside the slope (a ray never hits the part it starts in), so a corner whose
-- start is inside a solid (a tiny probe asks) is read again from higher up, by its sideways distance x tan(climb limit).
-- A hit steeper than the climb limit is a wall: it pulls the way downhill but never sets the probe's height.
-- The probe is only used by the players' collision group, so other players' bodies never count.
--
-- Stuck safety Task 46: the walk map and this check must agree, so whether a body fits is asked of the walk
-- map's own test, `PathCheck.roomToStand`, standing on the centre ray's hit with the ground's normal (its box tilts with
-- the ground, and may turn). And the start needs a floor: the centre ray must hit ground within MAX_FLOOR
-- studs under the spot, else "no floor". A corner ray landing on a thin plate never counts as the floor for the body.
--
-- Stuck safety Task 53: every start comes from the walk map. `nearSpot(near, maxStuds, root, standsOn)` builds the walk
-- map around `near`, takes the nearest spots (on `standsOn`, if given), checks each one has the floor the map says
-- (the first thing a ray hits under it is that part, and flat enough to stand on), and runs `find` on it. The first
-- open one wins. With no spot at all it says what is at `near`, or "no walk-map spot".
--
-- Task 12i: a start must also hold still. The floor under the centre of where `find` ended up (its `ground`,
-- after the downhill moves) must have a normal Y of HOLD_MIN_NORMAL_Y or more, else "too steep to hold still".

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Config = require(ReplicatedStorage.Shared.Config)

local RAY_ABOVE = 0.5 -- studs: the rays start this far over the spot (a roof higher than this is never mistaken for ground)
local RAY_BELOW = 30 -- studs: and look this far under the spot
local FOOTPRINT = 2 -- studs: the square the 5 rays cover (the body's width, the scan's grid)
local PROBE_LIFT = 0.1 -- studs: the probe's bottom is this far over the highest hit
local STEP = 0.5 -- studs: one move downhill
local MAX_MOVES = 4
local MAX_BLOCKERS = 5
local MAX_FLOOR = 8 -- studs: the floor under the centre of the start is at most this far under the spot
local NO_FLOOR = "no floor"
local TINY = 0.1 -- studs: the size of the probe that asks whether a ray's start point is inside a part
local PROBE_NAME = "StartCheckProbe"
local SPOT_SPACING = 1 -- studs: the walk map nearSpot builds around its point
local MAX_TRIES = 5 -- the nearest this many walk-map spots are tried
local FLOOR_RAY_UP = 3 -- studs: the floor check's ray starts this far over a spot
local FLOOR_RAY_LENGTH = 10 -- studs: and looks this far down
local NO_SPOT = "no walk-map spot"
local HOLD_MIN_NORMAL_Y = 0.65 -- about 49 degrees: the floor under a start is no steeper than a body has stood still on
local TOO_STEEP = "too steep to hold still"

-- `position` is the highest ray's hit + 0.1 (so no start digs into a slope); `ground` is the centre ray's hit, the
-- ground under the body's middle. In a dip they are far apart: measure a settle from `ground`.
export type Result = { open: boolean, position: Vector3?, ground: Vector3?, moves: number, blockers: { string } }

local StartCheck = {}

local HALF = FOOTPRINT / 2
local OFFSETS: { Vector3 } = {
	Vector3.new(0, 0, 0),
	Vector3.new(HALF, 0, HALF),
	Vector3.new(HALF, 0, -HALF),
	Vector3.new(-HALF, 0, HALF),
	Vector3.new(-HALF, 0, -HALF),
}

local function newRayParams(): RaycastParams
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.CollisionGroup = Collisions.GROUP
	return params
end

local function newOverlapParams(): OverlapParams
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	params.CollisionGroup = Collisions.GROUP
	return params
end

-- The names of up to MAX_BLOCKERS different parts touching the probe.
local function namesOf(parts: { BasePart }): { string }
	local names: { string } = {}
	for _, part in parts do
		if #names >= MAX_BLOCKERS then
			break
		end
		if not table.find(names, part.Name) then
			table.insert(names, part.Name)
		end
	end
	return names
end

-- The way down: from the centre toward the lowest of the hits. Read as a slope (each hit pulls by how far it lies under
-- the average), so two corners tied for lowest don't send the probe sideways. Nil on level ground.
local function downhill(offsets: { Vector3 }, heights: { number }): Vector3?
	local sum = 0
	for _, height in heights do
		sum += height
	end
	local mean = sum / #heights
	local pull = Vector3.zero
	for index, offset in offsets do
		pull += offset * (mean - heights[index])
	end
	if pull.Magnitude < 1e-6 then
		return nil
	end
	return pull.Unit
end

-- True when a point is inside a solid part. A tiny probe, because a ray never hits the part it starts in.
local function isInside(point: Vector3, world: WorldRoot, probe: Part, overlap: OverlapParams): boolean
	local size = probe.Size
	probe.Size = Vector3.one * TINY
	probe.CFrame = CFrame.new(point)
	local inside = #world:GetPartsInPart(probe, overlap) > 0
	probe.Size = size
	return inside
end

local function search(spot: Vector3, world: WorldRoot, probe: Part, options: PathCheck.Options): Result
	local rays = newRayParams()
	local overlap = newOverlapParams()
	local width, height = Config.Stuck.BodyWidth, Config.Stuck.BodyHeight
	probe.Size = Vector3.new(width, height, width)

	local limit = StarterPlayer.CharacterMaxSlopeAngle
	local climb = math.tan(math.rad(limit))
	local x, z = spot.X, spot.Z
	local moves = 0
	while true do
		local offsets: { Vector3 } = {}
		local heights: { number } = {}
		local highest = -math.huge
		local centre: RaycastResult? = nil
		for _, offset in OFFSETS do
			local from = Vector3.new(x + offset.X, spot.Y + RAY_ABOVE, z + offset.Z)
			local rise = offset.Magnitude * climb
			if rise > 0 and isInside(from, world, probe, overlap) then
				-- On steep ground the uphill corner starts inside the slope: read it again from higher up.
				from += Vector3.new(0, rise, 0)
			end
			local reach = from.Y - (spot.Y - RAY_BELOW)
			local hit = world:Raycast(from, Vector3.new(0, -reach, 0), rays)
			if hit ~= nil then
				if offset.Magnitude == 0 then
					centre = hit
				end
				table.insert(offsets, offset)
				table.insert(heights, hit.Position.Y)
				-- A hit steeper than the climb limit is a wall: it pulls the way downhill, but never sets the height.
				if math.deg(math.acos(math.clamp(hit.Normal.Y, -1, 1))) <= limit then
					highest = math.max(highest, hit.Position.Y)
				end
			end
		end

		if highest == -math.huge or centre == nil or spot.Y - centre.Position.Y > MAX_FLOOR then
			-- No floor to stand on. With no ground under the centre, the body is tested where the spot is, so the part
			-- it sits in gets named; with nothing there, or a centre floor too far down, the blocker is "no floor".
			local names = { NO_FLOOR }
			if centre == nil then
				probe.CFrame = CFrame.new(spot)
				local inside = namesOf(world:GetPartsInPart(probe, overlap))
				if #inside > 0 then
					names = inside
				end
			end
			return { open = false, position = nil, moves = moves, blockers = names }
		end

		local feet = Vector3.new(x, highest + PROBE_LIFT, z)
		local fits, inTheWay = PathCheck.roomToStand(options, centre.Position, centre.Normal)
		if fits then
			return { open = true, position = feet, ground = centre.Position, moves = moves, blockers = {} }
		end

		local way = if moves < MAX_MOVES then downhill(offsets, heights) else nil
		if way == nil then
			local blockers = if inTheWay ~= nil then { inTheWay.Name } else {}
			return { open = false, position = nil, moves = moves, blockers = blockers }
		end
		x += way.X * STEP
		z += way.Z * STEP
		moves += 1
	end
end

local function newProbe(world: WorldRoot): Part
	local probe = Instance.new("Part")
	probe.Name = PROBE_NAME
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	probe.Parent = world
	return probe
end

-- `spot` is the place to start from; `root` is the world to look in (default: the Workspace). `position` is the
-- middle of the body's bottom: the place to stand. The probe is destroyed on every path, an error included.
function StartCheck.find(spot: Vector3, root: Instance?): Result
	local world = (root or Workspace) :: Instance
	assert(world:IsA("WorldRoot"), "StartCheck.find needs a Workspace or a WorldModel")

	local probe = newProbe(world)

	local options = PathCheck.defaults(world)
	local ok, outcome = pcall(search, spot, world, probe, options)
	probe:Destroy()
	pcall(PathCheck.cleanup, options)
	if not ok then
		error(outcome, 0)
	end
	return outcome :: Result
end

local function notOpen(blockers: { string }): Result
	return { open = false, position = nil, moves = 0, blockers = blockers }
end

-- Does a ray from over the spot, straight down, first hit the part the walk map says the spot stands on, on ground a
-- player can stand on?
local function hasFloor(spot: PathCheck.Spot, world: WorldRoot, rays: RaycastParams): boolean
	local from = spot.position + Vector3.new(0, FLOOR_RAY_UP, 0)
	local hit = world:Raycast(from, Vector3.new(0, -FLOOR_RAY_LENGTH, 0), rays)
	if hit == nil or hit.Instance ~= spot.standsOn then
		return false
	end
	return hit.Normal.Y >= math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
end

-- Is the floor under the centre of where `find` ended up (its `ground`, after the downhill moves) flat enough for a body
-- to stand still on (Task 12i)? That limit is lower than the walk-up limit hasFloor reads.
local function holdsStill(found: Result, world: WorldRoot, rays: RaycastParams): boolean
	local ground = found.ground
	if ground == nil then
		return false
	end
	local from = ground + Vector3.new(0, FLOOR_RAY_UP, 0)
	local hit = world:Raycast(from, Vector3.new(0, -FLOOR_RAY_LENGTH, 0), rays)
	return hit ~= nil and hit.Normal.Y >= HOLD_MIN_NORMAL_Y
end

local function searchNear(
	near: Vector3,
	maxStuds: number,
	world: WorldRoot,
	standsOn: BasePart?,
	options: PathCheck.Options,
	probe: Part
): Result
	local reach = Vector3.one * maxStuds
	local map = PathCheck.buildMap(options, { min = near - reach, max = near + reach })
	PathCheck.cleanup(options) -- the map is plain data: its probes are not needed any more

	local candidates: { PathCheck.Spot } = {}
	for _, spot in map.spots do
		if (spot.position - near).Magnitude <= maxStuds and (standsOn == nil or spot.standsOn == standsOn) then
			table.insert(candidates, spot)
		end
	end
	table.sort(candidates, function(a, b)
		return (a.position - near).Magnitude < (b.position - near).Magnitude
	end)

	if #candidates == 0 then
		probe.Size = Vector3.one * TINY
		probe.CFrame = CFrame.new(near)
		local touching = namesOf(world:GetPartsInPart(probe, newOverlapParams()))
		return notOpen(if #touching > 0 then touching else { NO_SPOT })
	end

	local rays = newRayParams()
	local nearest: Result? = nil
	for index = 1, math.min(#candidates, MAX_TRIES) do
		local spot = candidates[index]
		local result: Result
		if hasFloor(spot, world, rays) then
			result = StartCheck.find(spot.position, world)
			if result.open and not holdsStill(result, world, rays) then
				result = notOpen({ TOO_STEEP })
			end
			if result.open then
				return result
			end
		else
			result = notOpen({ "not on " .. spot.standsOn.Name })
		end
		nearest = nearest or result
	end
	return nearest :: Result
end

-- The nearest walk-map spot within `maxStuds` of `near` (on `standsOn`, when given) that is open to start from, found
-- by `find`. `root` is the world to look in (default: the Workspace). Not open: the nearest spot's reason, or what
-- sits at `near`. The probe and the walk map's probes are destroyed on every path, an error included.
function StartCheck.nearSpot(near: Vector3, maxStuds: number, root: Instance?, standsOn: BasePart?): Result
	local world = (root or Workspace) :: Instance
	assert(world:IsA("WorldRoot"), "StartCheck.nearSpot needs a Workspace or a WorldModel")

	local probe = newProbe(world)
	local options = PathCheck.defaults(world)
	options.spacing = SPOT_SPACING
	local ok, outcome = pcall(searchNear, near, maxStuds, world, standsOn, options, probe)
	probe:Destroy()
	pcall(PathCheck.cleanup, options)
	if not ok then
		error(outcome, 0)
	end
	return outcome :: Result
end

return StartCheck
