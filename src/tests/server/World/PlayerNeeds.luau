--!strict
-- PlayerNeeds: a test helper (stuck safety Task 23, review round 1). One list of "the places players need", shared by the
-- stuck scan's rare-spot check (StuckScan.spec) and the slide guard check (RealWorld.spec), so the two can never
-- disagree about what players need. A place is a point, a segment (a route link) or a box (a walk piece, a seam part).
-- When a later spec adds a new walk piece, a seam or a steep layer, it goes here and both checks see it.

local WorldIndex = require(game:GetService("ServerScriptService").Server.World.WorldIndex)

export type Need = {
	name: string,
	kind: "point" | "segment" | "box",
	a: Vector3, -- the point, one end of the segment, or the middle of the box
	b: Vector3?, -- the other end of a segment
	part: BasePart?, -- the part of a box
	-- The corners of a box that holds the place (its reach), to skip the far ones quickly.
	low: Vector3,
	high: Vector3,
	-- How far a point is from the place (0 inside a box).
	distance: (position: Vector3) -> number,
}

-- Spec 5's four Legendary nest points on his nightcap (docs/specs/v2/egg-nests-and-climbing.md, the nests table). The
-- brim pair is just past the cap ladder's top, the side pair farther up the cap's front slope.
export type Nest = { name: string, position: Vector3, group: "brim" | "side" }
local NESTS: { Nest } = {
	{ name = "left brim nest", position = Vector3.new(-14, 117.1, 14), group = "brim" },
	{ name = "right brim nest", position = Vector3.new(14, 117.1, 14), group = "brim" },
	{ name = "left side nest", position = Vector3.new(-17, 119, 28), group = "side" },
	{ name = "right side nest", position = Vector3.new(17, 119, 28), group = "side" },
}

local LADDER_NAMES = { "CapTieLeft", "CapTieRight" } -- the two cap ties (Task 61b); BeardLadder and CapLadder are gone
local LADDER_TRUSS = "Climb"
local WALK_PIECE_SUFFIX = "_Walk" -- Boots_Walk, RightBoots_Walk, Belly_Walk, Ramp_Walk: the invisible walk pieces
local WALK_PIECE_RAMP_PREFIX = "CrossingRamp" -- the crossing ramps are walk pieces too
-- The seam's stitch parts are World.Seam (plan 5, Task 11). Spec 5's steep invisible layer has no folder name in plan 5
-- yet, so STEEP_LAYER_FOLDER is a placeholder: while no such folder exists in the world, nothing is checked for it.
local SEAM_FOLDER = "Seam"
local STEEP_LAYER_FOLDER = "SteepLayer"

local PlayerNeeds = {}
PlayerNeeds.NESTS = NESTS
PlayerNeeds.LADDER_NAMES = LADDER_NAMES

-- How far a point is from a box (0 inside it). A wedge is measured as its whole box, so a wedge is never judged farther
-- away than it is.
function PlayerNeeds.distanceToBox(point: Vector3, cframe: CFrame, size: Vector3): number
	local at = cframe:PointToObjectSpace(point)
	local half = size / 2
	local outside = Vector3.new(
		math.max(math.abs(at.X) - half.X, 0),
		math.max(math.abs(at.Y) - half.Y, 0),
		math.max(math.abs(at.Z) - half.Z, 0)
	)
	return outside.Magnitude
end

function PlayerNeeds.pointNeed(name: string, point: Vector3): Need
	return {
		name = name,
		kind = "point",
		a = point,
		low = point,
		high = point,
		distance = function(position: Vector3): number
			return (position - point).Magnitude
		end,
	}
end

-- A route link: the nearest point on the segment from `a` to `b`.
function PlayerNeeds.segmentNeed(name: string, a: Vector3, b: Vector3): Need
	local along = b - a
	local lengthSquared = along:Dot(along)
	return {
		name = name,
		kind = "segment",
		a = a,
		b = b,
		low = a:Min(b),
		high = a:Max(b),
		distance = function(position: Vector3): number
			local fraction = if lengthSquared > 1e-9
				then math.clamp((position - a):Dot(along) / lengthSquared, 0, 1)
				else 0
			return (position - (a + along * fraction)).Magnitude
		end,
	}
end

-- A part as a place players need: the nearest point of its box.
function PlayerNeeds.boxNeed(name: string, part: BasePart): Need
	local reach = Vector3.one * (part.Size.Magnitude / 2)
	return {
		name = name,
		kind = "box",
		a = part.Position,
		part = part,
		low = part.Position - reach,
		high = part.Position + reach,
		distance = function(position: Vector3): number
			return PlayerNeeds.distanceToBox(position, part.CFrame, part.Size)
		end,
	}
end

-- How far a point is from the nearest of the places.
function PlayerNeeds.nearestDistance(needs: { Need }, position: Vector3): number
	local nearest = math.huge
	for _, need in needs do
		nearest = math.min(nearest, need.distance(position))
	end
	return nearest
end

-- The two ends of a ladder's truss: its foot and its top.
local function trussEnds(truss: BasePart): (Vector3, Vector3)
	local size = truss.Size
	local half = if size.X >= size.Y and size.X >= size.Z
		then Vector3.new(size.X / 2, 0, 0)
		elseif size.Y >= size.Z then Vector3.new(0, size.Y / 2, 0)
		else Vector3.new(0, 0, size.Z / 2)
	local endA = truss.CFrame:PointToWorldSpace(half)
	local endB = truss.CFrame:PointToWorldSpace(-half)
	if endB.Y < endA.Y then
		return endB, endA
	end
	return endA, endB
end

-- The two ends of a cap tie: its foot is the bottom centre between ClimbTrussUp_1 and _2, its top is the top centre
-- between ClimbTrussLean_1 and _2. nil, nil when a truss is missing.
function PlayerNeeds.tieEnds(tie: Instance): (Vector3?, Vector3?)
	local function trussPart(name: string): BasePart?
		local part = tie:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			return part
		end
		return nil
	end
	local up1, up2 = trussPart("ClimbTrussUp_1"), trussPart("ClimbTrussUp_2")
	local lean1, lean2 = trussPart("ClimbTrussLean_1"), trussPart("ClimbTrussLean_2")
	if up1 == nil or up2 == nil or lean1 == nil or lean2 == nil then
		return nil, nil
	end
	local foot1 = trussEnds(up1)
	local foot2 = trussEnds(up2)
	local _, top1 = trussEnds(lean1)
	local _, top2 = trussEnds(lean2)
	return (foot1 + foot2) / 2, (top1 + top2) / 2
end

-- Every place players need, as the plan lists them: every route point and link, every egg spot, every landing spot,
-- every ladder's foot and top and truss, every invisible walk piece, spec 5's Legendary nest points, and the seam and
-- the steep layer when they exist. `world` is the model that holds WalkSurfaces (and the seam's folder, which may also be
-- inside WalkSurfaces). The route, egg spots and landing spots are given, so a made-up world can pass none.
function PlayerNeeds.build(
	world: Instance,
	route: { WorldIndex.RoutePoint },
	eggSpots: { WorldIndex.EggSpot },
	landings: { WorldIndex.LandingSpot }
): { Need }
	local needs: { Need } = {}
	local byName: { [string]: WorldIndex.RoutePoint } = {}
	for _, point in route do
		byName[point.name] = point
		table.insert(needs, PlayerNeeds.pointNeed(point.name, point.position))
	end
	for _, point in route do
		for _, neighbour in point.neighbours do
			local other = byName[neighbour]
			if other ~= nil and point.name < neighbour then
				table.insert(
					needs,
					PlayerNeeds.segmentNeed(`link {point.name} to {neighbour}`, point.position, other.position)
				)
			end
		end
	end
	for _, spot in eggSpots do
		table.insert(needs, PlayerNeeds.pointNeed(spot.name, spot.cframe.Position))
	end
	for _, spot in landings do
		table.insert(needs, PlayerNeeds.pointNeed(`LandingSpot_{spot.index}`, spot.position))
	end
	local walk = world:FindFirstChild("WalkSurfaces")
	if walk ~= nil then
		for _, ladderName in LADDER_NAMES do
			local ladder = walk:FindFirstChild(ladderName)
			local foot, top = nil, nil
			if ladder ~= nil then
				foot, top = PlayerNeeds.tieEnds(ladder)
			end
			if foot ~= nil and top ~= nil then
				table.insert(needs, PlayerNeeds.pointNeed(`{ladderName} foot`, foot))
				table.insert(needs, PlayerNeeds.pointNeed(`{ladderName} top`, top))
			end
		end
		local walkParts: { Instance } = walk:GetDescendants()
		for _, descendant in walkParts do
			if
				descendant:IsA("BasePart")
				and (
					descendant.Name == LADDER_TRUSS
					or string.sub(descendant.Name, -#WALK_PIECE_SUFFIX) == WALK_PIECE_SUFFIX
					or string.sub(descendant.Name, 1, #WALK_PIECE_RAMP_PREFIX) == WALK_PIECE_RAMP_PREFIX
				)
			then
				table.insert(needs, PlayerNeeds.boxNeed(`walk piece {descendant.Name}`, descendant))
			end
		end
	end
	for _, nest in NESTS do
		table.insert(needs, PlayerNeeds.pointNeed(nest.name, nest.position))
	end
	for _, folderName in { SEAM_FOLDER, STEEP_LAYER_FOLDER } do
		local folder = world:FindFirstChild(folderName) or (if walk then walk:FindFirstChild(folderName) else nil)
		if folder ~= nil then
			local folderParts: { Instance } = folder:GetDescendants()
			for _, descendant in folderParts do
				if descendant:IsA("BasePart") then
					table.insert(needs, PlayerNeeds.boxNeed(`{folderName} {descendant.Name}`, descendant))
				end
			end
		end
	end
	return needs
end

-- The same, read from the real world (it stops with an error if the route, egg spots or landing spots are missing).
function PlayerNeeds.fromWorld(world: Instance): { Need }
	return PlayerNeeds.build(
		world,
		WorldIndex.loadRoute(world),
		WorldIndex.loadEggSpots(world),
		WorldIndex.loadLandingSpots(world)
	)
end

return PlayerNeeds
