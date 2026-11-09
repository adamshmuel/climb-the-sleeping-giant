--!strict
-- The real-world inputs for the walk-area check (plan 5 Task 14; spec 5 "Seam angle", "Seam match", "Walk surface over
-- what you see"): where the walk area starts, what is drawn, where the seam is, and the text of the result. The checks
-- themselves are in WalkAreaCheck; the one test that runs them on the real world is in OnTheGiant.spec. These helpers
-- only READ the world.
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)
local WalkAreaCheck = require(ServerScriptService.Server.World.WalkAreaCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local DrawnSkin = require(ServerStorage.Tests.server.World.DrawnSkin)
local RealWorldHelpers = require(ServerStorage.Tests.server.World.RealWorld.Helpers)
local StuckHelpers = require(script.Parent.Helpers)

type Problem = WalkAreaCheck.Problem

local SIDES = { "Left", "Right" }
local START_EGG_SPOT = "EggSpot_Rare_1" -- on the Belly (Zones.zoneAt), the walk area's start
local START_STEPS = 2 -- grid steps round the start egg spot where walk-map spots are starts
local SAMPLE_STEP = 2 -- studs between the gap check's samples
local SKIP_LIMIT = 12 -- rays that skip invisible parts at one point, at most
local MARGIN = 1 -- studs a sample ray starts above the zone box, and ends below it
local KINDS = { "too steep", "floating", "sunk", "gap", "zone", "seam match" }
local LISTED_PER_KIND = 10
local ART_RAY_LENGTH = 250 -- studs: the ray down onto the strap and pocket art reaches this far
local CHEST_SOUTH_Z = -20 -- Q1: north of this z, between x -CHEST_HALF_X and CHEST_HALF_X, his chest is not walk area
local CHEST_HALF_X = 22
local COVER_BELOW = 0.2 -- studs: a ramp spot passes when it is this far below its Cover board...
local COVER_ABOVE = 0.7 -- ...to this far above it
local SLEEVE_X_MIN, SLEEVE_X_MAX = 42, 52 -- Rule 79: gap rows with |x| in this range are the sleeves
local STEEP_REACH = 1.5 -- studs: a gap sample this close to a steep-layer piece is a slide by design

local WalkAreaFacts = {}

function WalkAreaFacts.artFolder(): Instance
	local nests = Workspace:FindFirstChild("Mockup_Nests")
	expect(nests).never.toBeNil()
	local art = (nests :: Instance):FindFirstChild("Art")
	expect(art).never.toBeNil()
	return art :: Instance
end

-- The art parts a top is measured against: the visible strap (Strap, StrapFoot...) and the visible pocket parts of one
-- side, never the walk pieces (StrapWalk, LedgeWalk*) and never the stitches.
function WalkAreaFacts.visibleArt(side: string): { BasePart }
	local models: { Instance } = {}
	local straps = WalkAreaFacts.artFolder():FindFirstChild("Straps")
	local pockets = WalkAreaFacts.artFolder():FindFirstChild("Pockets")
	expect(straps).never.toBeNil()
	expect(pockets).never.toBeNil()
	for _, found in
		{
			(straps :: Instance):FindFirstChild(`CuffStrap_{side}`),
			(pockets :: Instance):FindFirstChild(`CuffPocketFront_{side}`),
			(pockets :: Instance):FindFirstChild(`CuffPocketBack_{side}`),
		}
	do
		expect(found).never.toBeNil()
		table.insert(models, found :: Instance)
	end
	local parts: { BasePart } = {}
	for _, model in models do
		for _, child in model:GetChildren() do
			local name = child.Name
			local isWalk = name == "StrapWalk"
				or name == "CuffTabWalk"
				or name == "StrapFootWalk"
				or string.sub(name, 1, 9) == "LedgeWalk"
				or string.find(name, "Curb", 1, true) ~= nil
			if child:IsA("BasePart") and not isWalk and child.Name ~= "Stitch" then
				table.insert(parts, child)
			end
		end
	end
	return parts
end

-- The walk-map spots within START_STEPS grid steps of the start egg spot.
local function startIds(world: Instance, map: PathCheck.WalkMap): { number }
	local eggSpot = (world :: any).EggSpots:FindFirstChild(START_EGG_SPOT)
	expect(eggSpot).never.toBeNil()
	local at = (eggSpot :: Model):GetPivot().Position
	local ids: { number } = {}
	for _, spot in map.spots do
		if (spot.position - at).Magnitude <= START_STEPS * map.spacing then
			table.insert(ids, spot.id)
		end
	end
	return ids
end

-- The top of the highest of `parts` under (x, z) at or below maxY, by the parts' shape (CFrame and Size, turned boxes
-- too), so art that rays skip (CanQuery off) still counts; nil when none. A part that reaches above maxY is ignored.
function WalkAreaFacts.artTopUnder(parts: { BasePart }, x: number, z: number, maxY: number): number?
	local best: number? = nil
	for _, part in parts do
		-- The vertical line through (x, z) in the part's own space: world y = t, local point = origin + up * t.
		local origin = part.CFrame:PointToObjectSpace(Vector3.new(x, 0, z))
		local up = part.CFrame:VectorToObjectSpace(Vector3.yAxis)
		local low, high = -math.huge, math.huge
		local size = part.Size
		for _, axis in { "X", "Y", "Z" } do
			local half = (size :: any)[axis] / 2
			local o, d = (origin :: any)[axis], (up :: any)[axis]
			if math.abs(d) < 1e-6 then
				if math.abs(o) > half then
					low, high = 1, 0
				end
			else
				local a, b = (-half - o) / d, (half - o) / d
				low, high = math.max(low, math.min(a, b)), math.min(high, math.max(a, b))
			end
		end
		if low <= high and high <= maxY and (best == nil or high > best) then
			best = high
		end
	end
	return best
end

-- Q1 (work/p5t15c/q1-ruling.md): a spot on his body that is not walk area. His chest north of z -20 between x -22 and
-- 22, and everything outboard of the seam line and lower than it (below the seam). Mirrored by the sign of x.
function WalkAreaFacts.isCutGap(position: Vector3): boolean
	if position.Z > CHEST_SOUTH_Z and math.abs(position.X) <= CHEST_HALF_X then
		return true
	end
	local points = if position.X < 0 then SlideProfile.SEAM_LEFT else SlideProfile.SEAM_RIGHT
	local z = math.clamp(position.Z, points[1].Z, points[#points].Z)
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		if z >= from.Z and z <= to.Z then
			local fraction = if to.Z > from.Z then (z - from.Z) / (to.Z - from.Z) else 0
			local seam = from:Lerp(to, fraction)
			return math.abs(position.X) > math.abs(seam.X) and position.Y < seam.Y
		end
	end
	return false
end

-- Task 15g (trace row 4): a ramp spot is not checked against the visible surface when it stands on a BellyRamp_* piece
-- and: it is a curb or a Fill block; or a Cover board (drawn, no collision; `covers`) lies under it by shape, 0.2 below to 0.7 above;
-- or it is a Piece<n> with its own Fill<n> beside it (Piece13 stands on Fill13, ruled not a float).
function WalkAreaFacts.skipRampSpot(spot: PathCheck.Spot, covers: { BasePart }): boolean
	local part = spot.standsOn
	local ramp: Instance? = part.Parent
	while ramp ~= nil and string.sub(ramp.Name, 1, 10) ~= "BellyRamp_" do
		ramp = ramp.Parent
	end
	if ramp == nil then
		return false
	end
	if string.find(part.Name, "Curb", 1, true) ~= nil or string.match(part.Name, "^Fill%d+$") ~= nil then
		return true -- a curb, or the invisible Fill block a Piece stands on (a spot on its top sits inside the ramp)
	end
	local position = spot.position
	local top = WalkAreaFacts.artTopUnder(covers, position.X, position.Z, position.Y + COVER_ABOVE)
	if top ~= nil and position.Y - top >= -COVER_BELOW and position.Y - top <= COVER_ABOVE then
		return true
	end
	local number = string.match(part.Name, "^Piece(%d+)$")
	return number ~= nil and ramp:FindFirstChild(`Fill{number}`) ~= nil
end

-- True when `position` is within STEEP_REACH of a steep-layer piece, by shape: a slide by design (Task 15a), never a gap.
local function nearSteep(position: Vector3, pieces: { BasePart }): boolean
	for _, piece in pieces do
		local local_ = piece.CFrame:PointToObjectSpace(position)
		local half = piece.Size / 2
		if
			math.abs(local_.X) <= half.X + STEEP_REACH
			and math.abs(local_.Y) <= half.Y + STEEP_REACH
			and math.abs(local_.Z) <= half.Z + STEEP_REACH
		then
			return true
		end
	end
	return false
end

-- The first visible hit of a ray straight down onto `parts` (parts with Transparency 1 are skipped), or nil.
local function visibleHitDown(
	params: RaycastParams,
	x: number,
	fromY: number,
	z: number,
	length: number
): RaycastResult?
	local origin = Vector3.new(x, fromY, z)
	local travelled = 0
	for _ = 1, SKIP_LIMIT do
		local hit = Workspace:Raycast(origin, Vector3.new(0, -(length - travelled), 0), params)
		if hit == nil then
			return nil
		end
		if hit.Instance.Transparency < 1 then
			return hit
		end
		travelled = fromY - hit.Position.Y + 0.01
		origin = Vector3.new(x, hit.Position.Y - 0.01, z)
	end
	return nil
end

-- The Belly zone boxes' world-space bounds (the zone boxes are turned, so the box's corners give them).
local function bellyBounds(boxes: { Zones.ZoneBox }): { { min: Vector3, max: Vector3 } }
	local bounds: { { min: Vector3, max: Vector3 } } = {}
	for _, box in boxes do
		if box.zone == "Belly" then
			local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						local corner = box.cframe:PointToWorldSpace(box.size / 2 * Vector3.new(sx, sy, sz))
						low, high = low:Min(corner), high:Max(corner)
					end
				end
			end
			table.insert(bounds, { min = low, max = high })
		end
	end
	return bounds
end

-- Everything the checks need from the real world. `giantParts` is the Giant model plus the visible strap and pocket art.
export type Inputs = {
	starts: { number },
	isBelly: (Vector3) -> boolean,
	zoneOf: (Vector3) -> string,
	alsoIn: (PathCheck.Spot) -> boolean,
	onSkin: (BasePart) -> boolean,
	visibleHeightAt: (number, number, number) -> number?,
	skipSpot: (PathCheck.Spot) -> boolean,
	skipGap: (Vector3) -> boolean,
	samples: { Vector3 },
	stitches: { Vector3 }?,
	steepLayer: Instance?,
}

function WalkAreaFacts.inputs(world: Instance, map: PathCheck.WalkMap): Inputs
	local giant = (world :: any).Giant :: Instance
	local cuffWalk = (world :: any).CuffWalk :: Instance
	local zoneBoxes = WorldIndex.loadZones(world)
	local function zoneOf(position: Vector3): string
		return Zones.zoneAt(position, zoneBoxes)
	end

	-- The drawn skin: his meshes (as Patches.spec does) and the higher of that and the visible strap and pocket art.
	local meshes: { MeshPart } = {}
	for _, name in RealWorldHelpers.BODY_PIECES do
		local piece = giant:FindFirstChild(name)
		expect(piece).never.toBeNil()
		table.insert(meshes, (piece :: Instance):FindFirstChild(name) :: MeshPart)
	end
	local skin = DrawnSkin.fromWorld(meshes, {})
	local artParams = RaycastParams.new()
	artParams.FilterType = Enum.RaycastFilterType.Include
	local art: { Instance } = {}
	for _, side in SIDES do
		for _, part in WalkAreaFacts.visibleArt(side) do
			table.insert(art, part)
		end
	end
	artParams.FilterDescendantsInstances = art
	local function visibleHeightAt(x: number, z: number, maxY: number): number?
		local best = skin.heightAt(x, z, maxY)
		local byShape = WalkAreaFacts.artTopUnder(art :: any, x, z, maxY)
		if byShape ~= nil and (best == nil or byShape > best) then
			best = byShape
		end
		local hit = Workspace:Raycast(Vector3.new(x, maxY, z), Vector3.new(0, -ART_RAY_LENGTH, 0), artParams)
		if hit ~= nil and (best == nil or hit.Position.Y > best) then
			best = hit.Position.Y
		end
		return best
	end

	-- Samples: every SAMPLE_STEP studs over the Belly boxes, where the first visible hit is his giant or the art and its
	-- slope is under SEAM_DEGREES. Each is keyed by its grid cell.
	local sampleParams = RaycastParams.new()
	sampleParams.FilterType = Enum.RaycastFilterType.Include
	local sampled: { Instance } = { giant }
	local isArt: { [Instance]: boolean } = {}
	for _, part in art do
		table.insert(sampled, part)
		isArt[part] = true
	end
	sampleParams.FilterDescendantsInstances = sampled
	local startSpot = (world :: any).EggSpots:FindFirstChild(START_EGG_SPOT)
	expect(startSpot).never.toBeNil()
	local startAt = (startSpot :: Model):GetPivot().Position
	local cells: { [string]: { position: Vector3, x: number, z: number }? } = {}
	local seeds: { [string]: boolean } = {}
	local seen: { [string]: boolean } = {}
	for _, bounds in bellyBounds(zoneBoxes) do
		local top, length = bounds.max.Y + MARGIN, bounds.max.Y - bounds.min.Y + 2 * MARGIN
		for x = math.ceil(bounds.min.X / SAMPLE_STEP) * SAMPLE_STEP, bounds.max.X, SAMPLE_STEP do
			for z = math.ceil(bounds.min.Z / SAMPLE_STEP) * SAMPLE_STEP, bounds.max.Z, SAMPLE_STEP do
				local key = `{x},{z}`
				local hit = if seen[key] then nil else visibleHitDown(sampleParams, x, top, z, length)
				if hit ~= nil then
					seen[key] = true
					local degrees = math.deg(math.acos(math.clamp(hit.Normal.Y, -1, 1)))
					if zoneOf(hit.Position) == "Belly" and degrees < WalkAreaCheck.SEAM_DEGREES then
						cells[key] = { position = hit.Position, x = x, z = z }
						local nearStart = Vector3.new(hit.Position.X - startAt.X, 0, hit.Position.Z - startAt.Z).Magnitude
							<= SAMPLE_STEP
						if nearStart or isArt[hit.Instance] then
							seeds[key] = true
						end
					end
				end
			end
		end
	end

	-- Only the part of the skin a player can walk to counts as a gap sample. The Belly boxes also hold skin that no
	-- walk could ever reach (a wall past a fold, the far side of a ridge), so a sample joins only if it is joined to a
	-- seed (the start egg spot, or the strap and pocket art) through a chain of 8 grid neighbours, each step at most
	-- SAMPLE_STEP * tan(SEAM_DEGREES) studs higher or lower (a slope under the seam angle).
	local maxRise = SAMPLE_STEP * math.tan(math.rad(WalkAreaCheck.SEAM_DEGREES))
	local joined: { [string]: boolean } = {}
	local queue: { string } = {}
	for key in seeds do
		joined[key] = true
		table.insert(queue, key)
	end
	local samples: { Vector3 } = {}
	local head = 1
	while head <= #queue do
		local at = cells[queue[head]] :: { position: Vector3, x: number, z: number }
		head += 1
		table.insert(samples, at.position)
		for dx = -SAMPLE_STEP, SAMPLE_STEP, SAMPLE_STEP do
			for dz = -SAMPLE_STEP, SAMPLE_STEP, SAMPLE_STEP do
				local nextKey = `{at.x + dx},{at.z + dz}`
				local nextAt = cells[nextKey]
				if nextAt ~= nil and not joined[nextKey] and math.abs(nextAt.position.Y - at.position.Y) <= maxRise then
					joined[nextKey] = true
					table.insert(queue, nextKey)
				end
			end
		end
	end

	-- The seam and the steep layer are built by plan 5 Tasks 16 and 15: until then they are nil (never an error).
	local seam = world:FindFirstChild("Seam")
	local stitches: { Vector3 }? = nil
	if seam ~= nil then
		stitches = {}
		for _, part in seam:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(stitches :: { Vector3 }, part.Position)
			end
		end
	end

	-- The Cover boards of the belly ramps (drawn, no collision) and the steep layer's pieces.
	local covers: { BasePart } = {}
	for _, item in world:GetDescendants() do
		if item:IsA("BasePart") and item.Parent ~= nil and item.Parent.Name == "Cover" then
			local ramp = item.Parent.Parent
			if ramp ~= nil and string.sub(ramp.Name, 1, 10) == "BellyRamp_" then
				table.insert(covers, item)
			end
		end
	end
	local steepPieces: { BasePart } = {}
	local steepLayer = world:FindFirstChild("SteepLayer")
	if steepLayer ~= nil then
		for _, item in steepLayer:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(steepPieces, item)
			end
		end
	end

	return {
		starts = startIds(world, map),
		isBelly = function(position)
			return zoneOf(position) == "Belly"
		end,
		zoneOf = zoneOf,
		alsoIn = function(spot)
			return spot.standsOn:IsDescendantOf(cuffWalk)
		end,
		onSkin = function(part)
			return part:IsDescendantOf(giant)
		end,
		visibleHeightAt = visibleHeightAt,
		skipSpot = function(spot)
			return WalkAreaFacts.skipRampSpot(spot, covers)
		end,
		-- Rule 79: sleeves are walk area; checked in Task 15e and Task 22 walk-offs. So gap rows with |x| 42 to 52 are
		-- left out here (gaps only, never floats).
		skipGap = function(position)
			local x = math.abs(position.X)
			return WalkAreaFacts.isCutGap(position)
				or (x >= SLEEVE_X_MIN and x <= SLEEVE_X_MAX)
				or nearSteep(position, steepPieces)
		end,
		samples = samples,
		stitches = stitches,
		steepLayer = world:FindFirstChild("SteepLayer"),
	}
end

-- All six checks on the walk area of the real world. Problems, in the order of KINDS.
function WalkAreaFacts.problems(world: Instance, map: PathCheck.WalkMap): ({ Problem }, number)
	local facts = WalkAreaFacts.inputs(world, map)
	local area = WalkAreaCheck.walkArea(map, facts.starts, facts.isBelly, facts.alsoIn)
	local found: { Problem } = {}
	for _, list in
		{
			WalkAreaCheck.tooSteep(map, area),
			WalkAreaCheck.floatingOrSunk(map, area, facts.visibleHeightAt, facts.onSkin, facts.skipSpot),
			WalkAreaCheck.gaps(map, area, facts.samples, facts.skipGap),
			WalkAreaCheck.zones(map, area, facts.zoneOf),
			WalkAreaCheck.seamMatch(Workspace, facts.stitches, facts.steepLayer),
		}
	do
		for _, item in list do
			table.insert(found, item)
		end
	end
	return found, #area
end

-- The message for a failing walk-area check: the count of each kind, then up to LISTED_PER_KIND positions of that kind,
-- lowest x first. At most 1 + 6 * 11 lines.
function WalkAreaFacts.message(found: { Problem }, areaSpots: number): string
	local lines = { `walk area: {areaSpots} spots, {#found} problems` }
	for _, kind in KINDS do
		local ofKind: { Problem } = {}
		for _, item in found do
			if item.kind == kind then
				table.insert(ofKind, item)
			end
		end
		table.sort(ofKind, function(a, b)
			return a.position.X < b.position.X
		end)
		table.insert(lines, `{kind}: {#ofKind}`)
		for index = 1, math.min(#ofKind, LISTED_PER_KIND) do
			table.insert(lines, `  {StuckHelpers.format(ofKind[index].position)} {ofKind[index].detail}`)
		end
	end
	return table.concat(lines, "\n")
end

return WalkAreaFacts
