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
			WalkAreaCheck.floatingOrSunk(map, area, facts.visibleHeightAt, facts.onSkin),
			WalkAreaCheck.gaps(map, area, facts.samples),
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
