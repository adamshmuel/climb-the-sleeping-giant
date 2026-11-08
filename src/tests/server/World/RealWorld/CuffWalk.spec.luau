--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Zones = require(ServerScriptService.Server.Giant.Zones)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)

-- Plan 5 (docs/plans/v2/egg-nests-and-climbing.md) Task 13: the solid, invisible cuff straps and ledges in World.CuffWalk
-- and the two Belly boxes round the cuffs. Spec 5, section 5: "Cuff strap and ledge (Epic)" and "Belly zone around each
-- cuff". These tests only READ the real world. The pieces are made by tools/world/22-cuff-walk.luau from the art in
-- Workspace.Mockup_Nests.Art, the boxes by tools/world/02-zones.luau. Numbers: work/p5t13/p5t13-scripts.md, sections W and T.
-- Plan 5 Task 13b adds the flap (Tab_), the foot (Foot_) and the two foot curbs (CurbFar_, CurbSide_) to each cuff: 9 pieces
-- on each of 2 sides, then four more invisible walk curbs per side (StrapCurbInboard_, StrapCurbTop_, FlapCurbUphill_,
-- FlapCurbEnd_): 13 on each of 2 sides, 26 in all. Numbers: work/p5t13b/p5t13b-scripts.md, sections W2 and T2, and
-- work/p5t13b/curbs-done.md.

local SIDES = { "Left", "Right" }
local SHAPE_KINDS = { "Strap", "Tab", "Foot", "CurbFar", "CurbSide", "FrontLedge", "FrontStrip", "BackLedge", "Join" }
local EDGE_CURB_KINDS = { "StrapCurbInboard", "StrapCurbTop", "FlapCurbUphill", "FlapCurbEnd" }
local PIECE_KINDS = {}
for _, kind in SHAPE_KINDS do
	table.insert(PIECE_KINDS, kind)
end
for _, kind in EDGE_CURB_KINDS do
	table.insert(PIECE_KINDS, kind)
end
-- Walls, not floors: no art lies under their tops.
local WALL_KINDS = { "CurbFar", "CurbSide", "StrapCurbInboard", "StrapCurbTop", "FlapCurbUphill", "FlapCurbEnd" }
local HEM_NAMES = { "FootHemFar", "FootHemSide" } -- art in the mockup (not copied into the world)
local LEDGE_KINDS = { "FrontLedge", "FrontStrip", "BackLedge", "Join" }

-- Spec 5, "Cuff strap and ledge (Epic)".
local STRAP_MIN_WIDTH = 5 -- studs: never under 5
local STRAP_SLOPE_DEGREES = 39 -- over any 5 studs
local STRAP_SLOPE_SPAN = 5 -- studs
local STRAP_MAX_DEGREES = 60 -- never over
local LEDGE_STEP = 0.05 -- studs: the step from the strap onto the ledge is none (the 0.05 is rounding)
local LEDGE_TOP = 32.5 -- studs: each ledge is level at this height...
local LEDGE_TOP_MARGIN = 0.1 -- ...within this
local LEVEL_UP_Y = 0.9998 -- a level top: its up direction has at least this Y (about 1 degree)
-- The one typed point: the strap's top-end middle (spec 5 row "Cuff strap and ledge (Epic)"), x mirrored for the right.
local STRAP_TOP_POINT = Vector3.new(54.6, 38.5, 4.4)
local STRAP_TOP_MARGIN = 0.3 -- studs

-- Flap (Tab_), spec 5 row "Cuff strap and ledge (Epic)", flap words of 2026-11-08 (work/p5t13b/tab-decision.md).
local TAB_MAX_PITCH = 30 -- degrees
local TAB_MAX_ROLL = 1 -- degrees: level along the hinge
local TAB_CLOTH_LOW = -0.1 -- studs: the inner end's top over his cloth, lowest...
local TAB_CLOTH_HIGH = 0.2 -- ...and highest
local TAB_END_INSET = 0.02 -- studs: the cloth rays run this far in from the inner end
local TAB_GRID = 0.5 -- studs between rays
local JOIN_OFFSET = 0.05 -- studs: the join rays run this far each side of the hinge
local JOIN_STEP = 0.05 -- studs: the largest step at the hinge
local SINK_AT_END = 0.3 -- studs: the inner end face may sink this far into his cloth...
local SINK_INSIDE = 0.1 -- ...and 0.1 in from it, this far
local SINK_INSIDE_DISTANCE = 0.1

-- Foot (Foot_) and curbs.
local FOOT_LEDGE_REACH = 0.25 -- studs: the foot-to-ledge rays run this far past the foot's far edge
local CURB_HEIGHT = 1.5 -- studs: each curb top over the foot top...
local CURB_MARGIN = 0.05 -- ...within this
local CURB_FROM = 0.5 -- studs outboard: the far curb covers the far edge from here...
local CURB_TO = 3.1 -- ...to here
local SHORT_RAY_ABOVE = 5 -- studs: a ray onto a part starts this high over it
local SHORT_RAY_LENGTH = 30

-- Edge drops (card work/p5t13b/card.md Step 5): beside the way home, along every top edge of the strap, flap and foot.
local EDGE_STEP = 0.5 -- studs between the points on an edge
local EDGE_OUT = 0.3 -- studs out from the edge...
local EDGE_RAY_UP = 20 -- ...and up, where the ray down starts (above the arm beside the edge; a hit no more than 2 below the edge is no drop: product ruling, work/p5t13b/door-ruling.md)
local EDGE_RAY_LENGTH = 60
local EDGE_MAX_DROP = 2 -- studs: a drop over this fails unless a wall holds the edge: a ray along the top, this far...
local EDGE_WALL_UP = 0.75 -- ...up, from this far inside the edge to EDGE_OUT past it (as the designer measured the curbs,
local EDGE_WALL_IN = 1 -- work/p5t13b/curbs-done.md: a curb or his arm that the ray hits first is a wall)
local EDGE_CORNER = 0.5 -- studs: the outboard corner of the strap and foot (accepted open: the visible meadow edge)

-- Spec 5, Rule 79's window: a top sits 0.2 below to 0.7 above the visible strap or pocket under it.
local TOP_BELOW_ART = 0.2
local TOP_ABOVE_ART = 0.7
-- code_lead ruling (Plan 5 Task 13, 2026-11-08): a 0.5-stud crack runs down the middle of each Join piece and
-- at its ends; a foot covers half a stud, so a point with no art directly under it passes if a ray this far
-- away (+-x or +-z) finds art in the same window.
local EDGE_ALLOWANCE = 0.5

local SAMPLE_STEP = 1 -- studs between the points checked over a top
local RAY_ABOVE = 150 -- studs: a ray onto his cloth starts this high (Helpers.BODY_SLOPE_RAY_ABOVE)
local RAY_LENGTH = 250

-- Spec 5, "Belly zone around each cuff" and plan 5 Task 13's decision: the cuff tops, out to x 68.
local CUFF_X_FROM = 46
local CUFF_X_TO = 68
local CUFF_Z_FROM = -15
local CUFF_Z_TO = 7

-- The boot tops are read in front of his belly (z -70 to -47), at the height the boot ladders top out at (Config's toe
-- nests, 30.4 in the ways-up spec); a ray hit lower than this is a leg, not a boot top.
local BOOT_Z_FROM = -70
local BOOT_Z_TO = -47
local BOOT_X_TO = 40
local BOOT_TOP_MIN_Y = 28

local function world(): Instance
	return Helpers.realWorld()
end

local function cuffFolder(): Instance
	local folder = world():FindFirstChild("CuffWalk")
	if folder == nil then
		error("World.CuffWalk is missing", 0)
	end
	return folder
end

local function pieceName(kind: string, side: string): string
	return `{kind}_{side}`
end

local function piece(kind: string, side: string): BasePart
	local found = cuffFolder():FindFirstChild(pieceName(kind, side))
	if found == nil or not found:IsA("BasePart") then
		error(`World.CuffWalk.{pieceName(kind, side)} is missing`, 0)
	end
	return found :: BasePart
end

-- A piece, or nil when the world has not got it yet (the tests that need all of them say so first).
local function maybePiece(kind: string, side: string): BasePart?
	local found = cuffFolder():FindFirstChild(pieceName(kind, side))
	if found ~= nil and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function expectNoProblems(problems: { string })
	if #problems > 0 then
		local summary = Helpers.firstLines(problems)
		error(`{summary.count} problems: {table.concat(summary.first, "; ")}`, 0)
	end
end

local function topPoint(part: BasePart, along: number): Vector3
	return part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2, along))
end

-- The raycast params that see only `parts`.
local function onlyParams(parts: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	return params
end

-- The first art found by a ray down EDGE_ALLOWANCE away from the point (+-x, then +-z) whose gap is in the window.
local function nearbyHit(fake: WorldModel, point: Vector3, params: RaycastParams): RaycastResult?
	for _, offset in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local from = point + offset * EDGE_ALLOWANCE + Vector3.new(0, 5, 0)
		local hit = fake:Raycast(from, Vector3.new(0, -20, 0), params)
		if hit ~= nil then
			local gap = point.Y - hit.Position.Y
			if gap >= -TOP_BELOW_ART - 1e-3 and gap <= TOP_ABOVE_ART + 1e-3 then
				return hit
			end
		end
	end
	return nil
end

local function giantParts(): Instance
	local giant = world():FindFirstChild("Giant")
	expect(giant).never.toBeNil()
	return giant :: Instance
end

local function armOf(sign: number): Instance
	local arm = giantParts():FindFirstChild(if sign < 0 then "left_arm" else "right_arm")
	expect(arm).never.toBeNil()
	return arm :: Instance
end

-- A ray straight down onto the parts in `params` (his cloth), from high above.
local function cloth(params: RaycastParams, x: number, z: number): RaycastResult?
	return Workspace:Raycast(Vector3.new(x, RAY_ABOVE, z), Vector3.new(0, -RAY_LENGTH, 0), params)
end

local function artFolder(): Instance
	local nests = Workspace:FindFirstChild("Mockup_Nests")
	expect(nests).never.toBeNil()
	local art = (nests :: Instance):FindFirstChild("Art")
	expect(art).never.toBeNil()
	return art :: Instance
end

-- The art parts a top is measured against: the visible strap (Strap, StrapFoot...) and the visible pocket parts of one
-- side, never the walk pieces (StrapWalk, LedgeWalk*) and never the stitches.
local function visibleArt(side: string): { BasePart }
	local models: { Instance } = {}
	local straps = artFolder():FindFirstChild("Straps")
	local pockets = artFolder():FindFirstChild("Pockets")
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

local function allPieces(): { BasePart }
	local list: { BasePart } = {}
	for _, side in SIDES do
		for _, kind in PIECE_KINDS do
			local found = maybePiece(kind, side)
			if found ~= nil then
				table.insert(list, found)
			end
		end
	end
	return list
end

-- +1 when the part's local X points to the middle of his body (its inner side), -1 when it points away.
local function innerSide(part: BasePart, sign: number): number
	return if part.CFrame.XVector.X * -sign >= 0 then 1 else -1
end

-- A ray straight down onto `params`'s parts from SHORT_RAY_ABOVE over `point`.
local function rayUnder(params: RaycastParams, point: Vector3): RaycastResult?
	return Workspace:Raycast(point + Vector3.new(0, SHORT_RAY_ABOVE, 0), Vector3.new(0, -SHORT_RAY_LENGTH, 0), params)
end

-- Pieces and hems that must exist before the shape is measured; the missing ones, by name.
local function missingParts(side: string): { string }
	local missing: { string } = {}
	for _, kind in SHAPE_KINDS do
		if maybePiece(kind, side) == nil then
			table.insert(missing, pieceName(kind, side))
		end
	end
	local model = (artFolder():FindFirstChild("Straps") :: Instance):FindFirstChild(`CuffStrap_{side}`)
	for _, hem in HEM_NAMES do
		if model == nil or model:FindFirstChild(hem) == nil then
			table.insert(missing, `{hem} (art, {side})`)
		end
	end
	return missing
end

-- The strap: wide enough, not too steep, top end where the spec puts it. Returns the top-end and low-end middle points.
local function checkStrap(problems: { string }, strap: BasePart, sign: number): (Vector3, Vector3)
	local label = strap.Name
	if strap.Size.X < STRAP_MIN_WIDTH then
		table.insert(problems, `{label} is {strap.Size.X} wide, under {STRAP_MIN_WIDTH}`)
	end
	-- steepness: the whole face, then every window of STRAP_SLOPE_SPAN studs along the middle line
	local tilt = math.deg(math.acos(math.clamp(strap.CFrame.UpVector.Y, -1, 1)))
	if tilt > STRAP_MAX_DEGREES then
		table.insert(problems, `{label} is {tilt} degrees, over {STRAP_MAX_DEGREES}`)
	end
	local length = strap.Size.Z
	local span = math.min(STRAP_SLOPE_SPAN, length)
	local start = -length / 2
	while start + span <= length / 2 + 1e-6 do
		local from = topPoint(strap, start)
		local to = topPoint(strap, start + span)
		local flat = Helpers.flat(to - from).Magnitude
		local degrees = math.deg(math.atan2(math.abs(to.Y - from.Y), flat))
		if degrees > STRAP_SLOPE_DEGREES + 0.01 then
			table.insert(problems, `{label} is {degrees} degrees over {span} studs, over {STRAP_SLOPE_DEGREES}`)
		end
		start += SAMPLE_STEP
	end
	-- the top end is the higher one
	local endA = topPoint(strap, -length / 2)
	local endB = topPoint(strap, length / 2)
	local high = if endA.Y > endB.Y then endA else endB
	local low = if endA.Y > endB.Y then endB else endA
	local wanted = Vector3.new(sign * STRAP_TOP_POINT.X, STRAP_TOP_POINT.Y, STRAP_TOP_POINT.Z)
	if (high - wanted).Magnitude > STRAP_TOP_MARGIN then
		local at, should = Helpers.describePoint(high), Helpers.describePoint(wanted)
		table.insert(problems, `{label} top end {at} is more than {STRAP_TOP_MARGIN} from {should}`)
	end
	return high, low
end

-- The flap: gently pitched and level along the hinge; its inner end meets his cloth; it meets the strap with no step.
local function checkFlap(
	problems: { string },
	tab: BasePart,
	strap: BasePart,
	strapTop: Vector3,
	sign: number,
	clothParams: RaycastParams
)
	local label = tab.Name
	local pitch = math.deg(math.acos(math.clamp(tab.CFrame.UpVector.Y, -1, 1)))
	if pitch > TAB_MAX_PITCH then
		table.insert(problems, `{label} is pitched {pitch} degrees, over {TAB_MAX_PITCH}`)
	end
	local roll = math.deg(math.asin(math.clamp(math.abs(tab.CFrame.XVector.Y), 0, 1)))
	if roll > TAB_MAX_ROLL then
		table.insert(problems, `{label} is {roll} degrees out of level along its hinge, over {TAB_MAX_ROLL}`)
	end
	local halfX, halfY, halfZ = tab.Size.X / 2, tab.Size.Y / 2, tab.Size.Z / 2
	local endX = innerSide(tab, sign) * halfX
	-- the inner end meets his cloth, and does not sink into it
	for offset = 0, tab.Size.Z + 1e-6, TAB_GRID do
		local z = math.clamp(-halfZ + offset, -halfZ + TAB_END_INSET, halfZ - TAB_END_INSET)
		local top = tab.CFrame:PointToWorldSpace(Vector3.new(endX - math.sign(endX) * TAB_END_INSET, halfY, z))
		local hit = rayUnder(clothParams, top)
		if hit == nil then
			table.insert(problems, `{label} inner end {Helpers.describePoint(top)} has no cloth under it`)
		else
			local over = top.Y - hit.Position.Y
			if over < TAB_CLOTH_LOW or over > TAB_CLOTH_HIGH then
				table.insert(
					problems,
					`{label} inner end {Helpers.describePoint(top)} is {over} over his cloth, not {TAB_CLOTH_LOW} to {TAB_CLOTH_HIGH}`
				)
			end
		end
		for _, inset in { 0, SINK_INSIDE_DISTANCE } do
			local bottom = tab.CFrame:PointToWorldSpace(Vector3.new(endX - math.sign(endX) * inset, -halfY, z))
			local below = rayUnder(clothParams, bottom)
			local sink = if below == nil then 0 else below.Position.Y - bottom.Y
			local limit = if inset == 0 then SINK_AT_END else SINK_INSIDE
			if sink > limit then
				table.insert(
					problems,
					`{label} sinks {sink} into his cloth {inset} in from its inner end {Helpers.describePoint(bottom)}, over {limit}`
				)
			end
		end
	end
	-- the hinge is the edge nearer the strap's top end; rays 0.05 each side of it, every 0.5 along it
	local hingeZ = halfZ
	local edgeA = tab.CFrame:PointToWorldSpace(Vector3.new(0, halfY, halfZ))
	local edgeB = tab.CFrame:PointToWorldSpace(Vector3.new(0, halfY, -halfZ))
	if Helpers.flat(edgeB - strapTop).Magnitude < Helpers.flat(edgeA - strapTop).Magnitude then
		hingeZ = -halfZ
	end
	local outward = Helpers.flat(tab.CFrame:VectorToWorldSpace(Vector3.new(0, 0, math.sign(hingeZ)))).Unit
	local tabParams = onlyParams({ tab })
	local strapParams = onlyParams({ strap })
	for step = 0, math.ceil(2 * halfX / TAB_GRID) do
		-- the two end points sit 0.05 inside the flap's sides: a ray exactly on a side face can miss
		local along = math.clamp(-halfX + step * TAB_GRID, -halfX + JOIN_OFFSET, halfX - JOIN_OFFSET)
		local edge = tab.CFrame:PointToWorldSpace(Vector3.new(along, halfY, hingeZ))
		local onTab = rayUnder(tabParams, edge - outward * JOIN_OFFSET)
		local onStrap = rayUnder(strapParams, edge + outward * JOIN_OFFSET)
		if onTab == nil or onStrap == nil then
			table.insert(problems, `{label} hinge {Helpers.describePoint(edge)} has no surface on one side`)
		elseif math.abs(onTab.Position.Y - onStrap.Position.Y) > JOIN_STEP then
			table.insert(
				problems,
				`{label} hinge {Helpers.describePoint(edge)} steps {math.abs(onTab.Position.Y - onStrap.Position.Y)}, over {JOIN_STEP}`
			)
		end
	end
end

-- The foot's edge away from the strap's low end, as a local Z (+-half its length).
local function farEdgeZ(foot: BasePart, strapLow: Vector3): number
	local halfZ = foot.Size.Z / 2
	local a = foot.CFrame:PointToWorldSpace(Vector3.new(0, 0, halfZ))
	local b = foot.CFrame:PointToWorldSpace(Vector3.new(0, 0, -halfZ))
	return if Helpers.flat(a - strapLow).Magnitude > Helpers.flat(b - strapLow).Magnitude then halfZ else -halfZ
end

-- The strap's low end meets the foot, and the foot meets the back ledge, with no step.
local function checkFoot(problems: { string }, foot: BasePart, ledge: BasePart, strapLow: Vector3, sign: number)
	local label = foot.Name
	local footTop = topPoint(foot, 0).Y
	if math.abs(strapLow.Y - footTop) > LEDGE_STEP then
		table.insert(problems, `{label} top {footTop} to the strap's low end {strapLow.Y}: step over {LEDGE_STEP}`)
	end
	local farZ = farEdgeZ(foot, strapLow)
	local ledgeParams = onlyParams({ ledge })
	local ledgeTop = ledge.Position.Y + ledge.Size.Y / 2
	local inner = innerSide(foot, sign)
	for across = 0, foot.Size.X / 2 - 0.1 + 1e-6, TAB_GRID do
		local point = foot.CFrame:PointToWorldSpace(
			Vector3.new(inner * across, foot.Size.Y / 2, farZ + math.sign(farZ) * FOOT_LEDGE_REACH)
		)
		local hit = rayUnder(ledgeParams, point)
		if hit == nil then
			table.insert(problems, `{label} to {ledge.Name}: nothing under {Helpers.describePoint(point)}`)
		elseif math.abs(hit.Position.Y - ledgeTop) > LEDGE_STEP then
			table.insert(
				problems,
				`{label} to {ledge.Name} at {Helpers.describePoint(point)}: top {hit.Position.Y} is not {ledgeTop}`
			)
		end
	end
end

-- Each curb top is CURB_HEIGHT over the foot top; the far curb covers the foot's far edge from CURB_FROM to CURB_TO outboard.
local function checkCurbs(
	problems: { string },
	foot: BasePart,
	curbFar: BasePart,
	curbSide: BasePart,
	strapLow: Vector3,
	sign: number
)
	local footTop = topPoint(foot, 0).Y
	for _, curb in { curbFar, curbSide } do
		local over = curb.Position.Y + curb.Size.Y / 2 - footTop
		if math.abs(over - CURB_HEIGHT) > CURB_MARGIN then
			table.insert(problems, `{curb.Name} top is {over} over the foot, not {CURB_HEIGHT}`)
		end
	end
	local outboard = -innerSide(foot, sign)
	local lowest, highest = math.huge, -math.huge
	local zLow, zHigh = math.huge, -math.huge
	for _, corner in Helpers.cornersOf(curbFar) do
		local local_ = foot.CFrame:PointToObjectSpace(corner)
		lowest = math.min(lowest, outboard * local_.X)
		highest = math.max(highest, outboard * local_.X)
		zLow = math.min(zLow, local_.Z)
		zHigh = math.max(zHigh, local_.Z)
	end
	if lowest > CURB_FROM + CURB_MARGIN or highest < CURB_TO - CURB_MARGIN then
		table.insert(problems, `{curbFar.Name} covers {lowest} to {highest} outboard, not {CURB_FROM} to {CURB_TO}`)
	end
	local farZ = farEdgeZ(foot, strapLow)
	if farZ < zLow - CURB_MARGIN or farZ > zHigh + CURB_MARGIN then
		table.insert(problems, `{curbFar.Name} does not reach the foot's far edge (z {farZ}, curb {zLow} to {zHigh})`)
	end
end

local function sideSign(side: string): number
	return if side == "Left" then -1 else 1
end

-- True when a wall (a curb, or his arm) stands at the edge: a ray along the top of the way home, EDGE_WALL_UP over the
-- edge point, from EDGE_WALL_IN inside it to EDGE_OUT past it, hits something. `part` is left out of the ray.
local function heldByWall(part: BasePart, edge: Vector3, out: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { part }
	local from = edge - out * EDGE_WALL_IN + Vector3.new(0, EDGE_WALL_UP, 0)
	return Workspace:Raycast(from, out * (EDGE_WALL_IN + EDGE_OUT), params) ~= nil
end

-- Every top-edge point of `part` every EDGE_STEP: the edge point, the way out (flat, unit), and whether the point is
-- on the strap's outboard long edge or at the outboard corner of the strap or foot (accepted open).
type EdgePoint = { point: Vector3, out: Vector3, accepted: boolean }
local function edgePoints(part: BasePart, sign: number): { EdgePoint }
	local list: { EdgePoint } = {}
	local half = part.Size / 2
	local outboard = -innerSide(part, sign)
	local isStrap = string.sub(part.Name, 1, 5) == "Strap"
	local isFoot = string.sub(part.Name, 1, 4) == "Foot"
	for _, axis in { "X", "Z" } do
		for _, end_ in { -1, 1 } do
			local length = if axis == "X" then part.Size.Z else part.Size.X
			local dir = if axis == "X" then Vector3.xAxis * end_ else Vector3.zAxis * end_
			local out = Helpers.flat(part.CFrame:VectorToWorldSpace(dir))
			local steps = math.ceil(length / EDGE_STEP - 1e-6)
			for i = 0, steps do
				local along = -length / 2 + length * i / steps
				local localPoint = if axis == "X"
					then Vector3.new(end_ * half.X, half.Y, along)
					else Vector3.new(along, half.Y, end_ * half.Z)
				local outboardGap = half.X - outboard * localPoint.X
				local accepted = (isStrap or isFoot) and outboardGap <= EDGE_CORNER
				if isStrap and axis == "X" and end_ == outboard then
					accepted = true
				end
				table.insert(list, {
					point = part.CFrame:PointToWorldSpace(localPoint),
					out = out.Unit,
					accepted = accepted,
				})
			end
		end
	end
	return list
end

describe("CuffWalk", function()
	it("each strap, flap, foot, curb and ledge has the spec's shape and they meet with no step", function()
		local problems: { string } = {}
		for _, side in SIDES do
			local sign = sideSign(side)
			local missing = missingParts(side)
			if #missing > 0 then
				table.insert(problems, `{side}: missing {table.concat(missing, ", ")}`)
				continue
			end
			local strap = piece("Strap", side)
			local strapTop, strapLow = checkStrap(problems, strap, sign)
			local clothParams = onlyParams({ giantParts() })
			checkFlap(problems, piece("Tab", side), strap, strapTop, sign, clothParams)
			local foot = piece("Foot", side)
			checkFoot(problems, foot, piece("BackLedge", side), strapLow, sign)
			checkCurbs(problems, foot, piece("CurbFar", side), piece("CurbSide", side), strapLow, sign)
			-- each ledge is level at LEDGE_TOP
			for _, kind in LEDGE_KINDS do
				local ledge = piece(kind, side)
				local height = ledge.Position.Y + ledge.Size.Y / 2
				if math.abs(height - LEDGE_TOP) > LEDGE_TOP_MARGIN or ledge.CFrame.UpVector.Y < LEVEL_UP_Y then
					table.insert(
						problems,
						`{ledge.Name} top is {height} (level {ledge.CFrame.UpVector.Y}), not {LEDGE_TOP}`
					)
				end
			end
		end
		expectNoProblems(problems)
	end)

	it("each strap and ledge top sits 0.2 below to 0.7 above the visible strap or pocket under it", function()
		local misses: { string } = {}
		for _, side in SIDES do
			Helpers.inFakeWorld(function(fake: WorldModel)
				local copies: { Instance } = {}
				for _, part in visibleArt(side) do
					local copy = part:Clone()
					copy.CanQuery = true
					copy.Parent = fake
					table.insert(copies, copy)
				end
				local params = onlyParams(copies)
				for _, kind in PIECE_KINDS do
					-- The curbs are walls, not floors: no art lies under their tops, so only the floors are checked.
					if table.find(WALL_KINDS, kind) then
						continue
					end
					local part = maybePiece(kind, side)
					if part == nil then
						table.insert(misses, `{pieceName(kind, side)} is missing`)
						continue
					end
					for _, point in Helpers.pointsOver(part, Helpers.topFaceOf(part), SAMPLE_STEP) do
						local hit = fake:Raycast(point + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
						if hit == nil then
							hit = nearbyHit(fake, point, params)
						end
						if hit == nil then
							table.insert(misses, `{part.Name} {Helpers.describePoint(point)} has no art under it`)
						else
							local gap = point.Y - hit.Position.Y
							if gap < -TOP_BELOW_ART - 1e-3 or gap > TOP_ABOVE_ART + 1e-3 then
								table.insert(
									misses,
									`{part.Name} {Helpers.describePoint(point)} is {gap} over {hit.Instance.Name}`
								)
							end
						end
					end
				end
			end)
		end
		expectNoProblems(misses)
	end)

	it(
		"every spot over each strap, ledge and cuff top is Belly, and the boot tops and lap planks stay Boots",
		function()
			local boxes, zoneProblems = WorldIndex.readZones(world())
			expect(zoneProblems).toEqual({})
			local problems: { string } = {}
			local function zoneOf(point: Vector3): string
				return Zones.zoneAt(point, boxes :: { Zones.ZoneBox })
			end
			-- cuff tops: a ray down at every stud of x 46 to 68, z -15 to 7, onto that side's arm
			for _, sign in { -1, 1 } do
				local params = onlyParams({ armOf(sign) })
				for x = CUFF_X_FROM, CUFF_X_TO, SAMPLE_STEP do
					for z = CUFF_Z_FROM, CUFF_Z_TO, SAMPLE_STEP do
						local hit = cloth(params, sign * x, z)
						if hit ~= nil and zoneOf(hit.Position) ~= "Belly" then
							table.insert(
								problems,
								`cuff top {Helpers.describePoint(hit.Position)} is {zoneOf(hit.Position)}, not Belly`
							)
						end
					end
				end
			end
			-- the straps and ledges
			if world():FindFirstChild("CuffWalk") == nil then
				table.insert(problems, "World.CuffWalk is missing")
			else
				for _, part in allPieces() do
					for _, point in Helpers.pointsOver(part, Helpers.topFaceOf(part), SAMPLE_STEP) do
						if zoneOf(point) ~= "Belly" then
							table.insert(
								problems,
								`{part.Name} {Helpers.describePoint(point)} is {zoneOf(point)}, not Belly`
							)
						end
					end
				end
			end
			-- the boot tops (rays onto his legs and boots) and both lap plank decks stay Boots
			local legs = giantParts():FindFirstChild("legs_and_boots")
			expect(legs).never.toBeNil()
			local legParams = onlyParams({ legs :: Instance })
			for _, sign in { -1, 1 } do
				for x = 0, BOOT_X_TO, SAMPLE_STEP do
					for z = BOOT_Z_FROM, BOOT_Z_TO, SAMPLE_STEP do
						local hit = cloth(legParams, sign * x, z)
						if hit ~= nil and hit.Position.Y >= BOOT_TOP_MIN_Y and zoneOf(hit.Position) ~= "Boots" then
							table.insert(
								problems,
								`boot top {Helpers.describePoint(hit.Position)} is {zoneOf(hit.Position)}, not Boots`
							)
						end
					end
				end
			end
			local surfaces = world():FindFirstChild("WalkSurfaces")
			expect(surfaces).never.toBeNil()
			for _, side in SIDES do
				local plank = (surfaces :: Instance):FindFirstChild(`LapPlank_{side}`)
				expect(plank).never.toBeNil()
				local deck = (plank :: Instance):FindFirstChild("Deck")
				expect(deck).never.toBeNil()
				for _, point in Helpers.pointsOver(deck :: BasePart, Helpers.topFaceOf(deck :: BasePart), SAMPLE_STEP) do
					if zoneOf(point) ~= "Boots" then
						table.insert(
							problems,
							`LapPlank_{side} deck {Helpers.describePoint(point)} is {zoneOf(point)}, not Boots`
						)
					end
				end
			end
			expectNoProblems(problems)
		end
	)

	it("no hidden drop beside the way home: a drop over 2 beside the strap, flap or foot has a wall", function()
		local problems: { string } = {}
		-- Curbs are walls, never floor: the ray down skips them; the 0.75 wall ray judges them.
		local curbs: { Instance } = {}
		for _, wallKind in WALL_KINDS do
			for _, wallSide in SIDES do
				local curb = maybePiece(wallKind, wallSide)
				if curb ~= nil then
					table.insert(curbs, curb)
				end
			end
		end
		local downParams = RaycastParams.new()
		downParams.FilterType = Enum.RaycastFilterType.Exclude
		downParams.FilterDescendantsInstances = curbs
		for _, side in SIDES do
			local sign = sideSign(side)
			for _, kind in { "Tab", "Strap", "Foot" } do
				local part = maybePiece(kind, side)
				if part == nil then
					table.insert(problems, `{pieceName(kind, side)} is missing`)
					continue
				end
				for _, edge in edgePoints(part, sign) do
					local start = edge.point + edge.out * EDGE_OUT + Vector3.new(0, EDGE_RAY_UP, 0)
					local hit = Workspace:Raycast(start, Vector3.new(0, -EDGE_RAY_LENGTH, 0), downParams)
					local drop = if hit == nil then math.huge else edge.point.Y - hit.Position.Y
					if drop > EDGE_MAX_DROP and not edge.accepted then
						if not heldByWall(part, edge.point, edge.out) then
							table.insert(problems, `{part.Name} {Helpers.describePoint(edge.point)} drops {drop}`)
						end
					end
				end
			end
		end
		expectNoProblems(problems)
	end)

	it("every right-side piece rides his right arm and no left-side piece does", function()
		local problems: { string } = {}
		for _, side in SIDES do
			for _, kind in PIECE_KINDS do
				local part = maybePiece(kind, side)
				if part == nil then
					continue
				end
				local rides = part:GetAttribute("RidesRightArm") == true
				if rides ~= (side == "Right") then
					table.insert(problems, `{part.Name} RidesRightArm is {rides}`)
				end
			end
		end
		expectNoProblems(problems)
	end)

	it("every piece is marked StitchedEdge, and nothing else in the Workspace is", function()
		local problems: { string } = {}
		local inFolder: { [Instance]: boolean } = {}
		for _, part in allPieces() do
			inFolder[part] = true
			if part:GetAttribute("StitchedEdge") ~= true then
				table.insert(problems, `{part.Name} has no StitchedEdge`)
			end
		end
		for _, child in cuffFolder():GetChildren() do
			if not inFolder[child] then
				table.insert(problems, `World.CuffWalk.{child.Name} is not one of the {#SIDES * #PIECE_KINDS} pieces`)
			end
		end
		local wanted = #SIDES * #PIECE_KINDS
		if #cuffFolder():GetChildren() ~= wanted then
			table.insert(problems, `World.CuffWalk holds {#cuffFolder():GetChildren()} parts, wanted {wanted}`)
		end
		for _, descendant in Workspace:GetDescendants() do
			if descendant:GetAttribute("StitchedEdge") ~= nil and not inFolder[descendant] then
				table.insert(problems, `{descendant:GetFullName()} has StitchedEdge`)
			end
		end
		expectNoProblems(problems)
	end)

	it("every piece arrives solid with no Mockup attribute", function()
		local problems: { string } = {}
		for _, part in allPieces() do
			if not (part.CanCollide and part.CanQuery and part.CanTouch) then
				table.insert(
					problems,
					`{part.Name} is not solid (collide {part.CanCollide}, query {part.CanQuery}, touch {part.CanTouch})`
				)
			end
			for name in part:GetAttributes() do
				if string.sub(name, 1, 6) == "Mockup" then
					table.insert(problems, `{part.Name} still has {name}`)
				end
			end
		end
		expectNoProblems(problems)
	end)
end)
