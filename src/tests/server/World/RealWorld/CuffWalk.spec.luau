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

local SIDES = { "Left", "Right" }
local PIECE_KINDS = { "Strap", "FrontLedge", "FrontStrip", "BackLedge", "Join" }
local LEDGE_KINDS = { "FrontLedge", "FrontStrip", "BackLedge", "Join" }

-- Spec 5, "Cuff strap and ledge (Epic)".
local STRAP_MIN_WIDTH = 5 -- studs: never under 5
local STRAP_SLOPE_DEGREES = 39 -- over any 5 studs
local STRAP_SLOPE_SPAN = 5 -- studs
local STRAP_MAX_DEGREES = 60 -- never over
local CLOTH_STEP_MAX = 0.2 -- studs: the step onto the strap from his cloth
local LEDGE_STEP = 0.05 -- studs: the step from the strap onto the ledge is none (the 0.05 is rounding)
local LEDGE_TOP = 32.5 -- studs: each ledge is level at this height...
local LEDGE_TOP_MARGIN = 0.1 -- ...within this
local LEVEL_UP_Y = 0.9998 -- a level top: its up direction has at least this Y (about 1 degree)
local CLOTH_NEAR = 3 -- studs: a cloth hit counts as "beside the strap's top end" within this height of it

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

local function distanceToTop(part: BasePart, point: Vector3): number
	local local_ = part.CFrame:PointToObjectSpace(point)
	local outX = math.max(math.abs(local_.X) - part.Size.X / 2, 0)
	local outZ = math.max(math.abs(local_.Z) - part.Size.Z / 2, 0)
	return math.sqrt(outX * outX + outZ * outZ)
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
			local isWalk = child.Name == "StrapWalk" or string.sub(child.Name, 1, 9) == "LedgeWalk"
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
			table.insert(list, piece(kind, side))
		end
	end
	return list
end

describe("CuffWalk", function()
	it("each strap and ledge has the shape the spec gives and the strap meets his cloth and the ledge", function()
		local problems: { string } = {}
		for _, side in SIDES do
			local strap = piece("Strap", side)
			local sign = if side == "Left" then -1 else 1
			local label = pieceName("Strap", side)
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
			local highAlong = if endA.Y > endB.Y then -length / 2 else length / 2
			local low = topPoint(strap, -highAlong)
			-- the step from his cloth: rays down across the top end's width, onto his arm; the best fit must be close
			local params = onlyParams({ armOf(sign) })
			local bestStep: number? = nil
			for across = -strap.Size.X / 2, strap.Size.X / 2 + 1e-6, SAMPLE_STEP do
				local point = strap.CFrame:PointToWorldSpace(Vector3.new(across, strap.Size.Y / 2, highAlong))
				local hit = cloth(params, point.X, point.Z)
				if hit ~= nil and math.abs(hit.Position.Y - point.Y) <= CLOTH_NEAR then
					local step = math.abs(hit.Position.Y - point.Y)
					if bestStep == nil or step < bestStep then
						bestStep = step
					end
				end
			end
			if bestStep == nil then
				table.insert(problems, `{label} top end finds no cloth within {CLOTH_NEAR} studs of its height`)
			elseif bestStep > CLOTH_STEP_MAX then
				table.insert(problems, `{label} step from his cloth is {bestStep}, over {CLOTH_STEP_MAX}`)
			end
			-- the low end meets the nearest ledge with no step
			local nearest: BasePart? = nil
			local nearestDistance = math.huge
			for _, kind in LEDGE_KINDS do
				local ledge = piece(kind, side)
				local distance = distanceToTop(ledge, low)
				if distance < nearestDistance then
					nearest = ledge
					nearestDistance = distance
				end
			end
			local ledgeTop = (nearest :: BasePart).Position.Y + (nearest :: BasePart).Size.Y / 2
			if math.abs(low.Y - ledgeTop) > LEDGE_STEP then
				table.insert(
					problems,
					`{label} low end {low.Y} to {(nearest :: BasePart).Name} top {ledgeTop}: step over {LEDGE_STEP}`
				)
			end
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
					local part = piece(kind, side)
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

	it("every right-side piece rides his right arm and no left-side piece does", function()
		local problems: { string } = {}
		for _, side in SIDES do
			for _, kind in PIECE_KINDS do
				local part = piece(kind, side)
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
				table.insert(problems, `World.CuffWalk.{child.Name} is not one of the 10 pieces`)
			end
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
