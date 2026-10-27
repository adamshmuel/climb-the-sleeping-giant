--!strict
-- The shared start check (stuck safety Task 27, lesson 21): is the place where a walk, a check or a camera is about to
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

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Collisions = require(ServerScriptService.Server.Players.Collisions)
local Config = require(ReplicatedStorage.Shared.Config)

local RAY_ABOVE = 0.5 -- studs: the rays start this far over the spot (a roof higher than this is never mistaken for ground)
local RAY_BELOW = 30 -- studs: and look this far under the spot
local FOOTPRINT = 2 -- studs: the square the 5 rays cover (the body's width, the scan's grid)
local PROBE_LIFT = 0.1 -- studs: the probe's bottom is this far over the highest hit
local STEP = 0.5 -- studs: one move downhill
local MAX_MOVES = 4
local MAX_BLOCKERS = 5
local TINY = 0.1 -- studs: the size of the probe that asks whether a ray's start point is inside a part
local PROBE_NAME = "StartCheckProbe"

export type Result = { open: boolean, position: Vector3?, moves: number, blockers: { string } }

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

-- True when a point is inside a solid part. A tiny probe, because a ray never hits the part it starts in (lesson 21).
local function isInside(point: Vector3, world: WorldRoot, probe: Part, overlap: OverlapParams): boolean
	local size = probe.Size
	probe.Size = Vector3.one * TINY
	probe.CFrame = CFrame.new(point)
	local inside = #world:GetPartsInPart(probe, overlap) > 0
	probe.Size = size
	return inside
end

local function search(spot: Vector3, world: WorldRoot, probe: Part): Result
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
				table.insert(offsets, offset)
				table.insert(heights, hit.Position.Y)
				-- A hit steeper than the climb limit is a wall: it pulls the way downhill, but never sets the height.
				if math.deg(math.acos(math.clamp(hit.Normal.Y, -1, 1))) <= limit then
					highest = math.max(highest, hit.Position.Y)
				end
			end
		end

		if highest == -math.huge then
			-- No ground to read (no ray hit ground: the spot is over nothing, or only walls): the body is
			-- tested where the spot is, so the part it sits in gets named.
			probe.CFrame = CFrame.new(spot)
			return {
				open = false,
				position = nil,
				moves = moves,
				blockers = namesOf(world:GetPartsInPart(probe, overlap)),
			}
		end

		local feet = Vector3.new(x, highest + PROBE_LIFT, z)
		probe.CFrame = CFrame.new(feet + Vector3.new(0, height / 2, 0))
		local touching = world:GetPartsInPart(probe, overlap)
		if #touching == 0 then
			return { open = true, position = feet, moves = moves, blockers = {} }
		end

		local way = if moves < MAX_MOVES then downhill(offsets, heights) else nil
		if way == nil then
			return { open = false, position = nil, moves = moves, blockers = namesOf(touching) }
		end
		x += way.X * STEP
		z += way.Z * STEP
		moves += 1
	end
end

-- `spot` is the place to start from; `root` is the world to look in (default: the Workspace). `position` is the
-- middle of the body's bottom: the place to stand. The probe is destroyed on every path, an error included.
function StartCheck.find(spot: Vector3, root: Instance?): Result
	local world = (root or Workspace) :: Instance
	assert(world:IsA("WorldRoot"), "StartCheck.find needs a Workspace or a WorldModel")

	local probe = Instance.new("Part")
	probe.Name = PROBE_NAME
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	probe.Parent = world

	local ok, outcome = pcall(search, spot, world, probe)
	probe:Destroy()
	if not ok then
		error(outcome, 0)
	end
	return outcome :: Result
end

return StartCheck
