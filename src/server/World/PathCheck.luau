--!strict
-- The one shared walk check (V2 Rule 23, "One walk check for everything"): "can a player walk from here to there
-- with no jump?" The real-world route test, the world script that builds the footprint route and the stuck scan all
-- call it, so they can never disagree. It never looks up the Workspace itself: the caller says which world to
-- search, so a test can hand it a fake one.
--
-- The walk map (Rule 22, "What counts as stuck"): spots on a grid, the links between them (walk, ladder, slide or
-- drop, never a jump), the cheapest route between two spots and the spots with no way out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Collisions = require(ServerScriptService.Server.Players.Collisions)

export type Options = {
	-- The world to search: the Workspace, or a test's WorldModel.
	world: WorldRoot,
	-- The steepest slope a player walks, in degrees. Default: StarterPlayer.CharacterMaxSlopeAngle.
	slopeAngle: number?,
	-- Studs between the spots of the walk map. Default: Config.Stuck.ScanSpacing.
	spacing: number?,
	-- Parts left out of the step check's body box: only edges a player steps over by design (a ramp plank). Making a
	-- spot leaves nothing out. Set it before the first check: the settings are made once per options table.
	-- Default: none.
	boxIgnores: { Instance }?,
	-- The meadow ground. Roblox's exact overlap check can't see the Terrain, so when this is set the body check also
	-- says "in the way" for a box that lies inside the ground (see inTheGround). Only the real Workspace has any: a
	-- fake world has none. Set it before the first check: the settings are made once per options table.
	-- Default: none (PathCheck.defaults gives the Workspace's Terrain when the world is the Workspace).
	terrain: Terrain?,
}

local SAMPLE_STEP = 2 -- studs between the places checked along a link
local RAY_START_ABOVE = 3 -- the ground ray starts this far above the line...
local RAY_LENGTH = 4 -- ...and reaches this far down
local MAX_OFF_LINE = 1 -- studs: how far the ground may be from the line (a line above the ground is corner-cutting)
local BODY_LIFT = 0.5 -- studs: the body box is held this far above the ground (a player steps over less than that)
local PROBE_NAME = "PathCheckProbe"
local STRAIGHT_UP = Vector3.new(0, 1, 0)
-- The meadow ground check (stuck safety Task 20, trial B's way): a ray straight down from far above the feet that sees
-- only the Terrain, and a ray straight up from just above them.
local GROUND_RAY_ABOVE = 500 -- studs: the ray down starts this far above the feet (higher than anything in the world)
local GROUND_SLACK = 0.3 -- studs: ground this far above the feet or less is what they stand on, not ground over them
local FEET_LIFT = 0.1 -- studs: the ray up starts this far above the feet...
local GROUND_RAY_UP = 500 -- ...and looks this far up for an overhang

-- The walk map's words.
export type LinkKind = "Walk" | "Climb" | "Slide"
export type Spot = { id: number, position: Vector3, up: Vector3, standsOn: BasePart }
export type Link = { to: number, kind: LinkKind, length: number, seconds: number }
-- A straight, unturned box in world space.
export type Area = { min: Vector3, max: Vector3 }
export type WalkMap = {
	spacing: number,
	spots: { Spot },
	links: { [number]: { Link } },
	-- Private lookup: a grid column's key (see columnKey) to the ids of the spots in it. `origin` is the area's lowest
	-- corner, and the grid is countX by countZ columns.
	columns: { [number]: { number } },
	origin: Vector3,
	countX: number,
	countZ: number,
}
export type Step = { from: number, to: number, kind: LinkKind, length: number, seconds: number }
export type Route = { steps: { Step }, cost: number }
-- Which link kinds count: a kind that isn't listed (or is false) doesn't.
export type AllowedKinds = { Walk: boolean?, Climb: boolean?, Slide: boolean? }
-- allow: the link kinds that count (default: all). cost: what a link costs (default: its seconds).
export type Rules = { allow: AllowedKinds?, cost: ((Link) -> number)? }

local ROOM_TURNS = { 0, 15, 30, 45, 60, 75 } -- degrees: a square repeats every 90
local RAY_RESTART = 0.01 -- studs: the next ray down a column starts this far below the last surface it hit
local MAX_SURFACES = 200 -- most surfaces one column can have (a safety stop)
local COLUMNS_PER_YIELD = 200
local SPOTS_PER_YIELD = 200
-- A ladder's foot and top join the nearest spot within this many grid steps of them. Two, because a ladder's end is the
-- middle of its end face, about 1 stud inside the ladder; a body can't stand closer to the ladder than half its width;
-- and the nearest grid column can be up to 1.4 studs to the side. (The real ladders' ends are 2.0 to 3.5 studs from
-- their nearest spot.)
local CLIMB_REACH_STEPS = 2
local CLIMB_SPEED = 0.7 -- Roblox climbs at 70% of WalkSpeed (docs, Humanoid.Climbing)
local SLIDE_LIFT = 0.5 -- studs: the body is checked this far above the edge the slide starts from
local SLIDE_STEP = 1 -- studs: how far a slide follows a steep surface downhill before looking again
local MAX_SLIDE_STEPS = 200
local LOWER_BY = 0.05 -- studs: a slide only goes to a spot at least this far lower than where it starts

local PathCheck = {}

-- One invisible probe part per world (GetPartsInPart needs a real part in the same world as the parts it checks).
-- Weak keys, so a destroyed test world doesn't keep its entry.
local probes: { [WorldRoot]: BasePart? } = setmetatable({}, { __mode = "k" }) :: any

local function describeVector(vector: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", vector.X, vector.Y, vector.Z)
end

-- The ray and overlap settings of one options table, made once and kept (weak keys, so a dropped options table
-- takes its settings with it). Every one of them looks only at what a player bumps into: it uses the players'
-- collision group, so a part in a group players pass through, such as another player's body, is never ground and never
-- in the way. The safe spots (stuck safety Task 9) check "room for their body" on the live server, where other
-- characters stand. `overlap` leaves out the box ignore list; `bare` leaves nothing out (making a spot).
-- `ignores` is the box ignore list the overlap settings were made from: a caller who sets a new list gets new
-- settings.
type Settings = {
	ground: RaycastParams,
	overlap: OverlapParams,
	bare: OverlapParams,
	ignores: { Instance }?,
	-- A ray that sees only the Terrain, water left out; nil when the options have no terrain.
	terrainOnly: RaycastParams?,
	terrain: Terrain?,
}
local settingsCache: { [Options]: Settings } = setmetatable({}, { __mode = "k" }) :: any

local function settingsFor(options: Options): Settings
	local settings = settingsCache[options]
	if settings ~= nil and settings.ignores == options.boxIgnores and settings.terrain == options.terrain then
		return settings
	end
	local ground = if settings ~= nil then settings.ground else RaycastParams.new()
	-- What a player stands on: a ray down that skips everything with CanCollide off (flowers, ropes, cleats).
	ground.RespectCanCollide = true
	ground.CollisionGroup = Collisions.GROUP
	local overlap = OverlapParams.new()
	overlap.RespectCanCollide = true
	overlap.CollisionGroup = Collisions.GROUP
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = options.boxIgnores or {}
	local bare = if settings ~= nil then settings.bare else OverlapParams.new()
	bare.RespectCanCollide = true
	bare.CollisionGroup = Collisions.GROUP
	bare.FilterType = Enum.RaycastFilterType.Exclude
	bare.FilterDescendantsInstances = {}
	local terrainOnly: RaycastParams? = nil
	if options.terrain ~= nil then
		local only = RaycastParams.new()
		only.IncludeInstances = { options.terrain }
		only.IgnoreWater = true
		only.RespectCanCollide = true
		only.CollisionGroup = Collisions.GROUP
		terrainOnly = only
	end
	local fresh: Settings = {
		ground = ground,
		overlap = overlap,
		bare = bare,
		ignores = options.boxIgnores,
		terrainOnly = terrainOnly,
		terrain = options.terrain,
	}
	settingsCache[options] = fresh
	return fresh
end

-- The probe for this world: the one we made if it is still there, otherwise a new one (a stray left by another copy
-- of this module, or one that was destroyed or moved out, is replaced).
local function getProbe(world: WorldRoot): BasePart
	local probe = probes[world]
	if probe ~= nil and probe.Parent == world then
		return probe
	end
	for _, child in world:GetChildren() do
		if child.Name == PROBE_NAME then
			child:Destroy()
		end
	end
	local fresh = Instance.new("Part")
	fresh.Name = PROBE_NAME
	fresh.Anchored = true
	fresh.Transparency = 1
	fresh.CanCollide = false
	fresh.CanTouch = false
	fresh.CanQuery = false
	fresh.Archivable = false -- never saved with the place
	fresh.Parent = world
	probes[world] = fresh
	return fresh
end

-- A frame at `position` whose up is `up`. When `facing` is given, the frame's front points along it (flattened onto
-- the surface); otherwise it is the shortest turn from straight up.
local function frameWithUp(position: Vector3, up: Vector3, facing: Vector3?): CFrame
	if facing ~= nil then
		local along = facing - up * facing:Dot(up)
		if along.Magnitude >= 1e-3 then -- written so a zero or NaN direction falls through
			return CFrame.fromMatrix(position, along.Unit:Cross(up), up)
		end
	end
	local axis = STRAIGHT_UP:Cross(up)
	if axis.Magnitude < 1e-6 then
		if up.Y >= 0 then
			return CFrame.new(position)
		end
		return CFrame.new(position) * CFrame.Angles(math.pi, 0, 0)
	end
	local angle = math.acos(math.clamp(STRAIGHT_UP:Dot(up), -1, 1))
	return CFrame.new(position) * CFrame.fromAxisAngle(axis, angle)
end

-- Whether a body standing on `feet` lies inside the meadow ground, which GetPartsInPart can't see. Trial B's way: the
-- ground is over the feet when a ray straight down from far above, seeing only the Terrain (water left out), reaches
-- ground more than GROUND_SLACK above the feet; and a ray straight up from just above the feet finds no ground. A ray
-- that starts inside the ground doesn't hit it, while feet under an overhang of ground (a cave roof) see the overhang.
local function inTheGround(options: Options, feet: Vector3): boolean
	local only = settingsFor(options).terrainOnly
	if only == nil then
		return false
	end
	local down = options.world:Raycast(
		feet + Vector3.new(0, GROUND_RAY_ABOVE, 0),
		Vector3.new(0, -(GROUND_RAY_ABOVE - GROUND_SLACK), 0),
		only
	)
	if down == nil then
		return false
	end
	local up = options.world:Raycast(feet + Vector3.new(0, FEET_LIFT, 0), Vector3.new(0, GROUND_RAY_UP, 0), only)
	return up == nil
end

-- The body check itself, with the overlap settings to use (the box ignore list left out, or nothing left out).
local function boxFits(
	options: Options,
	overlap: OverlapParams,
	feet: Vector3,
	up: Vector3?,
	facing: Vector3?
): (boolean, BasePart?)
	if options.terrain ~= nil and inTheGround(options, feet) then
		return false, options.terrain
	end
	local direction = if up ~= nil then up.Unit else STRAIGHT_UP
	local width = Config.Stuck.BodyWidth
	local height = Config.Stuck.BodyHeight - BODY_LIFT
	local probe = getProbe(options.world)
	probe.Size = Vector3.new(width, height, width)
	probe.CFrame = frameWithUp(feet + direction * (BODY_LIFT + height / 2), direction, facing)

	local touching = options.world:GetPartsInPart(probe, overlap)
	if #touching > 0 then
		return false, touching[1]
	end
	return true, nil
end

-- Whether a player's body fits standing on `feet`, with nothing in the way. `up` is the surface direction (default
-- straight up): the box tilts with it. `facing` is the way the body points (default: no particular way): a square
-- box reaches farther at its corners, so a walk check turns it to face the way it walks. The box is BodyWidth wide
-- and deep, from BODY_LIFT above the feet to BodyHeight above them. The check is exact (GetPartsInPart), not the
-- outer boxes of the parts around. The box ignore list is left out. Returns true, or false and the first part in the
-- way.
function PathCheck.bodyFits(options: Options, feet: Vector3, up: Vector3?, facing: Vector3?): (boolean, BasePart?)
	return boxFits(options, settingsFor(options).overlap, feet, up, facing)
end

-- Removes this world's probe. Call it when the checks are done, so nothing is left in the world.
function PathCheck.cleanup(options: Options)
	local world = options.world
	local probe = probes[world]
	if probe ~= nil then
		probe:Destroy()
		probes[world] = nil
	end
	for _, child in world:GetChildren() do
		if child.Name == PROBE_NAME then
			child:Destroy()
		end
	end
end

-- roomToStand with the overlap settings to use.
local function roomFor(options: Options, overlap: OverlapParams, feet: Vector3, up: Vector3?): (boolean, BasePart?)
	local direction = if up ~= nil then up.Unit else STRAIGHT_UP
	local fits, inTheWay = boxFits(options, overlap, feet, direction, nil)
	if fits then
		return true, nil
	end
	if options.terrain ~= nil and inTheWay == options.terrain then
		return false, inTheWay -- the ground is over the feet however the body turns
	end
	local reference = frameWithUp(feet, direction, nil).LookVector
	for index = 2, #ROOM_TURNS do
		local turned = CFrame.fromAxisAngle(direction, math.rad(ROOM_TURNS[index])) * reference
		if boxFits(options, overlap, feet, direction, turned) then
			return true, nil
		end
	end
	return false, inTheWay
end

-- Whether a body fits standing on `feet` facing some way. A standing player can turn, so the box is tried unturned
-- and then turned 15, 30, 45, 60 and 75 degrees around `up` (a square repeats every 90), and the first that fits
-- counts. The box ignore list is left out. When none fits it returns false and the part in the way of the unturned
-- box.
function PathCheck.roomToStand(options: Options, feet: Vector3, up: Vector3?): (boolean, BasePart?)
	return roomFor(options, settingsFor(options).overlap, feet, up)
end

-- Returns what is wrong with walking straight from `from` to `to`, or nil if a player can. Checked every 2 studs
-- along the line (at least once between the two ends): ground under it (not water, no steeper than the slope limit,
-- within 1 stud of the line) and room for a body box held just above the ground. At the two ends a player stands
-- and can turn before walking, so the box only has to fit facing some way (roomToStand); between them it walks, so
-- the box faces the way it walks. The place's text is only made when there is a problem to report.
function PathCheck.linkProblem(options: Options, from: Vector3, to: Vector3): string?
	local world = options.world
	local maxSlope = math.cos(math.rad(options.slopeAngle or StarterPlayer.CharacterMaxSlopeAngle))
	local settings = settingsFor(options)
	local groundRay = settings.ground
	local overlap = settings.overlap

	local length = (to - from).Magnitude
	local steps = math.max(2, math.ceil(length / SAMPLE_STEP))
	for step = 0, steps do
		local onLine = from:Lerp(to, step / steps)
		local hit =
			world:Raycast(onLine + Vector3.new(0, RAY_START_ABOVE, 0), Vector3.new(0, -RAY_LENGTH, 0), groundRay)
		if hit == nil then
			return `no ground at {describeVector(onLine)}`
		end
		if hit.Material == Enum.Material.Water then
			return `water at {describeVector(onLine)}`
		end
		if hit.Normal.Y < maxSlope then
			return `too steep at {describeVector(onLine)} ({hit.Instance.Name})`
		end
		if math.abs(hit.Position.Y - onLine.Y) > MAX_OFF_LINE then
			return `the ground is {hit.Position.Y - onLine.Y} studs off the line at {describeVector(onLine)} ({hit.Instance.Name})`
		end
		-- room for a body, standing on the ground and tilted with it: facing some way at the ends, facing the way it
		-- walks between them
		local fits, inTheWay
		if step == 0 or step == steps then
			fits, inTheWay = roomFor(options, overlap, hit.Position, hit.Normal)
		else
			fits, inTheWay = boxFits(options, overlap, hit.Position, hit.Normal, to - from)
		end
		if not fits then
			return `{(inTheWay :: BasePart):GetFullName()} is in the way at {describeVector(onLine)}`
		end
	end
	return nil
end

-- The options to use unless a caller needs something different: the slope limit and spacing from the game's own
-- settings, nothing left out of the body check, and (for the real Workspace only) the meadow ground, so a box inside
-- it is in the way.
function PathCheck.defaults(world: WorldRoot): Options
	return {
		world = world,
		slopeAngle = StarterPlayer.CharacterMaxSlopeAngle,
		spacing = Config.Stuck.ScanSpacing,
		boxIgnores = {},
		terrain = if world == Workspace then Workspace.Terrain else nil,
	}
end

-- A grid column's key, or nil when the column is outside the map.
local function columnKey(map: WalkMap, ix: number, iz: number): number?
	if ix < 0 or iz < 0 or ix >= map.countX or iz >= map.countZ then
		return nil
	end
	return iz * map.countX + ix
end

local NO_IDS: { number } = {}
local NO_LINKS: { Link } = {}

-- The ids of the spots in a grid column (none outside the map).
local function spotsInColumn(map: WalkMap, ix: number, iz: number): { number }
	local key = columnKey(map, ix, iz)
	if key == nil then
		return NO_IDS
	end
	return map.columns[key] or NO_IDS
end

local function columnOf(map: WalkMap, position: Vector3): (number, number)
	return math.round((position.X - map.origin.X) / map.spacing), math.round((position.Z - map.origin.Z) / map.spacing)
end

local function addLink(map: WalkMap, from: number, to: number, kind: LinkKind, seconds: number)
	local length = (map.spots[from].position - map.spots[to].position).Magnitude
	table.insert(map.links[from], { to = to, kind = kind, length = length, seconds = seconds })
end

-- The spot nearest `position` within `maxStuds`, or nil. Only the columns that close are looked at.
function PathCheck.nearestSpot(map: WalkMap, position: Vector3, maxStuds: number): number?
	local gridX = (position.X - map.origin.X) / map.spacing
	local gridZ = (position.Z - map.origin.Z) / map.spacing
	local reach = maxStuds / map.spacing
	local best: number? = nil
	local bestDistance = math.huge
	for iz = math.max(0, math.ceil(gridZ - reach)), math.min(map.countZ - 1, math.floor(gridZ + reach)) do
		for ix = math.max(0, math.ceil(gridX - reach)), math.min(map.countX - 1, math.floor(gridX + reach)) do
			for _, id in spotsInColumn(map, ix, iz) do
				local distance = (map.spots[id].position - position).Magnitude
				if distance <= maxStuds and distance < bestDistance then
					best = id
					bestDistance = distance
				end
			end
		end
	end
	return best
end

-- Casts down column by column through every surface and makes a spot of each one a body can stand on.
local function findSpots(options: Options, map: WalkMap, area: Area)
	local world = options.world
	local settings = settingsFor(options)
	local ground = settings.ground
	local maxSlope = math.cos(math.rad(options.slopeAngle or StarterPlayer.CharacterMaxSlopeAngle))
	local columnsDone = 0
	for iz = 0, map.countZ - 1 do
		for ix = 0, map.countX - 1 do
			local x = map.origin.X + ix * map.spacing
			local z = map.origin.Z + iz * map.spacing
			local ids: { number } = {}
			local y = area.max.Y
			local justAfterWater = false
			for _ = 1, MAX_SURFACES do
				if y <= area.min.Y then
					break
				end
				local hit = world:Raycast(Vector3.new(x, y, z), Vector3.new(0, area.min.Y - y, 0), ground)
				if hit == nil then
					break
				end
				-- a surface is a spot if it isn't too steep, isn't water, isn't right under water (a player there swims,
				-- and swimming isn't walking) and a body fits on it with nothing left out. A ladder is never a spot (a
				-- player who touches a ladder climbs it, so the climb link covers being on one); the ray goes on down
				-- below it.
				local isWater = hit.Material == Enum.Material.Water
				if
					not justAfterWater
					and not isWater
					and not hit.Instance:IsA("TrussPart")
					and hit.Normal.Y >= maxSlope
					and roomFor(options, settings.bare, hit.Position, hit.Normal)
				then
					local id = #map.spots + 1
					map.spots[id] = {
						id = id,
						position = hit.Position,
						up = hit.Normal,
						standsOn = hit.Instance :: BasePart,
					}
					map.links[id] = {}
					table.insert(ids, id)
				end
				justAfterWater = isWater
				-- the next ray starts just below this surface (a ray never hits the part it starts inside)
				y = hit.Position.Y - RAY_RESTART
			end
			map.columns[iz * map.countX + ix] = ids
			columnsDone += 1
			if columnsDone % COLUMNS_PER_YIELD == 0 then
				task.wait()
			end
		end
	end
end

-- Walk links: from each spot to each spot in the 8 columns around it, when the step check finds nothing wrong. The
-- check is the same both ways (the same samples, and a square turned 180 degrees is the same box), so each pair is
-- checked once and linked both ways.
local function findWalkLinks(options: Options, map: WalkMap)
	local seconds = 0
	for _, spot in map.spots do
		local ix, iz = columnOf(map, spot.position)
		for dz = -1, 1 do
			for dx = -1, 1 do
				local neighbours: { number } = NO_IDS
				if dx ~= 0 or dz ~= 0 then
					neighbours = spotsInColumn(map, ix + dx, iz + dz)
				end
				for _, otherId in neighbours do
					local other = map.spots[otherId]
					if otherId > spot.id and PathCheck.linkProblem(options, spot.position, other.position) == nil then
						seconds = (spot.position - other.position).Magnitude / StarterPlayer.CharacterWalkSpeed
						addLink(map, spot.id, otherId, "Walk", seconds)
						addLink(map, otherId, spot.id, "Walk", seconds)
					end
				end
			end
		end
		if spot.id % SPOTS_PER_YIELD == 0 then
			task.wait()
		end
	end
end

-- Climb links: each solid TrussPart joins the spot at its foot to the spot at its top (both within two grid steps of
-- the ends of its longest axis), both ways, at 70% of walking speed.
local function findClimbLinks(options: Options, map: WalkMap)
	local reach = CLIMB_REACH_STEPS * map.spacing
	for _, descendant in options.world:GetDescendants() do
		if descendant:IsA("TrussPart") and descendant.CanCollide then
			local size = descendant.Size
			local half = Vector3.zero
			if size.X >= size.Y and size.X >= size.Z then
				half = Vector3.new(size.X / 2, 0, 0)
			elseif size.Y >= size.Z then
				half = Vector3.new(0, size.Y / 2, 0)
			else
				half = Vector3.new(0, 0, size.Z / 2)
			end
			local endA = descendant.CFrame:PointToWorldSpace(half)
			local endB = descendant.CFrame:PointToWorldSpace(-half)
			local foot, top = endA, endB
			if endB.Y < endA.Y then
				foot, top = endB, endA
			end
			local footSpot = PathCheck.nearestSpot(map, foot, reach)
			local topSpot = PathCheck.nearestSpot(map, top, reach)
			if footSpot ~= nil and topSpot ~= nil and footSpot ~= topSpot then
				local length = (map.spots[footSpot].position - map.spots[topSpot].position).Magnitude
				local seconds = length / (CLIMB_SPEED * StarterPlayer.CharacterWalkSpeed)
				addLink(map, footSpot, topSpot, "Climb", seconds)
				addLink(map, topSpot, footSpot, "Climb", seconds)
			end
		end
	end
end

-- The spot a player who lands at `hit` stands on, or nil. The first drop (`firstDrop`) lands in the column it started
-- over: the spot there within half a stud of the hit. After sliding, any spot of the same part within a grid step.
local function landingSpot(map: WalkMap, hit: RaycastResult, firstDrop: boolean, ix: number, iz: number): number?
	local landX, landZ = columnOf(map, hit.Position)
	local landing: number? = nil
	local landingDistance = math.huge
	for dz = -1, 1 do
		for dx = -1, 1 do
			for _, id in spotsInColumn(map, landX + dx, landZ + dz) do
				local spot = map.spots[id]
				local distance = (spot.position - hit.Position).Magnitude
				local close = if firstDrop
					then landX + dx == ix and landZ + dz == iz and distance <= 0.5
					else spot.standsOn == hit.Instance and distance <= map.spacing
				if close and distance < landingDistance then
					landing = id
					landingDistance = distance
				end
			end
		end
	end
	return landing
end

-- Where a player who steps off `from` toward column (ix, iz) ends up: the spot they land on, or nil. A wall (no room
-- for a body there) stops the slide. A surface too steep to stand on is followed downhill, 1 stud at a time, until
-- it reaches ground a body can stand on. Water, nothing, or 200 steps: no slide. Only a spot lower than `from`.
local function slideTarget(options: Options, map: WalkMap, area: Area, from: Spot, ix: number, iz: number): number?
	local world = options.world
	local ground = settingsFor(options).ground
	local maxSlope = math.cos(math.rad(options.slopeAngle or StarterPlayer.CharacterMaxSlopeAngle))
	local feet =
		Vector3.new(map.origin.X + ix * map.spacing, from.position.Y + SLIDE_LIFT, map.origin.Z + iz * map.spacing)
	if not PathCheck.roomToStand(options, feet, STRAIGHT_UP) then
		return nil
	end

	local function castDown(start: Vector3): RaycastResult?
		return world:Raycast(start, Vector3.new(0, math.min(area.min.Y - 1 - start.Y, -0.1), 0), ground)
	end

	local hit = castDown(feet)
	for step = 0, MAX_SLIDE_STEPS do
		if hit == nil or hit.Material == Enum.Material.Water then
			return nil
		end
		if hit.Normal.Y >= maxSlope then
			local landing = landingSpot(map, hit, step == 0, ix, iz)
			if landing ~= nil and map.spots[landing].position.Y < from.position.Y - LOWER_BY then
				return landing
			end
			return nil
		end
		-- too steep to stand on: one stud downhill (gravity flattened onto the surface), then look again
		local downhill = Vector3.new(0, -1, 0) + hit.Normal * hit.Normal.Y
		if downhill.Magnitude < 1e-3 then
			return nil
		end
		hit = castDown(hit.Position + downhill.Unit * SLIDE_STEP + Vector3.new(0, SLIDE_LIFT, 0))
	end
	return nil
end

-- Slide links (one way, down only): off each edge of a spot, where there is no walk link toward the next column.
local function findSlideLinks(options: Options, map: WalkMap, area: Area)
	for _, spot in map.spots do
		local ix, iz = columnOf(map, spot.position)
		local walksTo: { [number]: boolean } = {}
		for _, link in map.links[spot.id] or NO_LINKS do
			if link.kind == "Walk" then
				local otherX, otherZ = columnOf(map, map.spots[link.to].position)
				walksTo[otherZ * map.countX + otherX] = true
			end
		end
		for dz = -1, 1 do
			for dx = -1, 1 do
				local key = if dx ~= 0 or dz ~= 0 then columnKey(map, ix + dx, iz + dz) else nil
				if key ~= nil and not walksTo[key] then
					local target = slideTarget(options, map, area, spot, ix + dx, iz + dz)
					if target ~= nil then
						addLink(
							map,
							spot.id,
							target,
							"Slide",
							(map.spots[target].position - spot.position).Magnitude / StarterPlayer.CharacterWalkSpeed
						)
					end
				end
			end
		end
		if spot.id % SPOTS_PER_YIELD == 0 then
			task.wait()
		end
	end
end

-- Builds the walk map of an area: a grid of columns `options.spacing` apart (default Config.Stuck.ScanSpacing), the
-- spots in them, and the walk, climb and slide links between the spots. It yields (task.wait) every few hundred
-- columns and spots, so Studio never freezes long enough to drop the connection. The body probe stays in the world
-- until the caller calls cleanup(options).
function PathCheck.buildMap(options: Options, area: Area): WalkMap
	local spacing = options.spacing or Config.Stuck.ScanSpacing
	local map: WalkMap = {
		spacing = spacing,
		spots = {},
		links = {},
		columns = {},
		origin = area.min,
		-- rounded up, so the last column lies on the area's far side or just past it (never short of it)
		countX = math.ceil((area.max.X - area.min.X) / spacing - 1e-6) + 1,
		countZ = math.ceil((area.max.Z - area.min.Z) / spacing - 1e-6) + 1,
	}
	findSpots(options, map, area)
	findWalkLinks(options, map)
	findClimbLinks(options, map)
	findSlideLinks(options, map, area)
	return map
end

-- A binary heap of (cost, id) pairs, smallest cost first.
type Heap = { costs: { number }, ids: { number }, size: number }

local function heapPush(heap: Heap, cost: number, id: number)
	heap.size += 1
	local index = heap.size
	while index > 1 do
		local parent = index // 2
		if heap.costs[parent] <= cost then
			break
		end
		heap.costs[index] = heap.costs[parent]
		heap.ids[index] = heap.ids[parent]
		index = parent
	end
	heap.costs[index] = cost
	heap.ids[index] = id
end

local function heapPop(heap: Heap): (number, number)
	local topCost, topId = heap.costs[1], heap.ids[1]
	local lastCost, lastId = heap.costs[heap.size], heap.ids[heap.size]
	heap.costs[heap.size] = nil :: any
	heap.ids[heap.size] = nil :: any
	heap.size -= 1
	if heap.size > 0 then
		local index = 1
		while true do
			local child = index * 2
			if child > heap.size then
				break
			end
			if child < heap.size and heap.costs[child + 1] < heap.costs[child] then
				child += 1
			end
			if heap.costs[child] >= lastCost then
				break
			end
			heap.costs[index] = heap.costs[child]
			heap.ids[index] = heap.ids[child]
			index = child
		end
		heap.costs[index] = lastCost
		heap.ids[index] = lastId
	end
	return topCost, topId
end

-- The cheapest route from one spot to any of the `to` spots, or nil. `rules.allow` picks the link kinds that count
-- (default: all) and `rules.cost` sets what each link costs (default: its seconds; never negative). Starting on one of
-- the `to` spots is a route with no steps.
function PathCheck.route(map: WalkMap, from: number, to: { number }, rules: Rules?): Route?
	local goals: { [number]: boolean } = {}
	for _, id in to do
		goals[id] = true
	end
	if goals[from] then
		return { steps = {}, cost = 0 }
	end
	local allow = if rules ~= nil then rules.allow else nil
	local costOf = if rules ~= nil then rules.cost else nil

	local best: { [number]: number } = { [from] = 0 }
	local cameBy: { [number]: Step } = {}
	local heap: Heap = { costs = {}, ids = {}, size = 0 }
	heapPush(heap, 0, from)
	while heap.size > 0 do
		local cost, id = heapPop(heap)
		if cost <= (best[id] or math.huge) then -- (a dearer duplicate of a spot already settled is skipped)
			if goals[id] then
				local steps: { Step } = {}
				local at = id
				while at ~= from do
					local step = cameBy[at]
					table.insert(steps, 1, step)
					at = step.from
				end
				return { steps = steps, cost = cost }
			end
			for _, link in map.links[id] or NO_LINKS do
				if allow == nil or allow[link.kind] then
					local total = cost + (if costOf ~= nil then costOf(link) else link.seconds)
					if total < (best[link.to] or math.huge) then
						best[link.to] = total
						cameBy[link.to] = {
							from = id,
							to = link.to,
							kind = link.kind,
							length = link.length,
							seconds = link.seconds,
						}
						heapPush(heap, total, link.to)
					end
				end
			end
		end
	end
	return nil
end

-- Every spot in the outermost grid columns (all four sides of the area) that stands on one of the `ground` instances or
-- on a part inside one. A spot on something else on the edge (a bridge, the giant's sock, a teacup) isn't open ground,
-- so it isn't listed. In order of id.
function PathCheck.edgeSpots(map: WalkMap, ground: { Instance }): { number }
	local found: { number } = {}
	local seen: { [number]: boolean } = {}
	local function addColumn(ix: number, iz: number)
		for _, id in spotsInColumn(map, ix, iz) do
			if not seen[id] then
				seen[id] = true
				local standsOn = map.spots[id].standsOn
				for _, root in ground do
					if standsOn == root or standsOn:IsDescendantOf(root) then
						table.insert(found, id)
						break
					end
				end
			end
		end
	end
	for ix = 0, map.countX - 1 do
		addColumn(ix, 0)
		addColumn(ix, map.countZ - 1)
	end
	for iz = 1, map.countZ - 2 do
		addColumn(0, iz)
		addColumn(map.countX - 1, iz)
	end
	table.sort(found)
	return found
end

-- Every spot with no way to any of the exit spots by walking, ladders, slides or drops: one search backwards from
-- the exits. Each is listed with its position and the part it stands on.
function PathCheck.stuckSpots(
	map: WalkMap,
	exits: { number }
): { { id: number, position: Vector3, standsOn: BasePart } }
	local comingFrom: { [number]: { number } } = {}
	for id, links in map.links do
		for _, link in links do
			local list = comingFrom[link.to]
			if list == nil then
				list = {}
				comingFrom[link.to] = list
			end
			table.insert(list, id)
		end
	end

	local reached: { [number]: boolean } = {}
	local queue: { number } = {}
	for _, id in exits do
		if map.spots[id] ~= nil and not reached[id] then
			reached[id] = true
			table.insert(queue, id)
		end
	end
	local head = 1
	while head <= #queue do
		local id = queue[head]
		head += 1
		for _, before in comingFrom[id] or NO_IDS do
			if not reached[before] then
				reached[before] = true
				table.insert(queue, before)
			end
		end
	end

	local stuck = {}
	for _, spot in map.spots do
		if not reached[spot.id] then
			table.insert(stuck, { id = spot.id, position = spot.position, standsOn = spot.standsOn })
		end
	end
	return stuck
end

return PathCheck
