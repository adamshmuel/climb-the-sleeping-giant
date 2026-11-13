--!strict
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local PlayerNeeds = require(game:GetService("ServerStorage").Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
local SockGuardReads = require(script.Parent.SockGuardReads)
type Face = Helpers.Face
local UP_FACE_MIN = Helpers.UP_FACE_MIN
local describePoint = Helpers.describePoint
local facesOf = Helpers.facesOf
local pointsOver = Helpers.pointsOver
local topFaceOf = Helpers.topFaceOf
local plateUnder = SockGuardReads.plateUnder
local SOCK_GUARD_PATTERN = SockGuardReads.SOCK_GUARD_PATTERN

local GUARD_FOLDER = "SlideGuards" -- World.WalkSurfaces.SlideGuards (stuck safety Task 23, decision 3)

export type Box = { name: string, min: Vector3, max: Vector3 }

export type Need = PlayerNeeds.Need

export type SockCloth = SockGuardReads.SockCloth

export type Context = {
	world: WorldRoot, -- the world the guards are in (the probe ball goes here)
	clothParams: RaycastParams, -- what a ray from a guard's face, aimed in at the cloth, may hit: the cloth only
	-- his body-size slope at a cloth point, given the direction the guard's top face points there (so a place under a
	-- roof is read square to the face), or nil when it can't be read: a ray missed
	slopeAt: (point: Vector3, normal: Vector3) -> number?,
	clothNameAt: (x: number, z: number) -> string?, -- the name of the cloth piece on top at (x, z), or nil with none
	chairBoxes: { Box }, -- body_and_cushion cloth inside any of these counts as the chair
	-- a guard named like BEARD_POCKET_GUARD_PATTERN with all 8 corners inside one of these skips the Cloth check
	beardPocketBoxes: { Box },
	solids: { Instance }, -- what a buried face or a buried corner is buried in
	needs: { Need }, -- the places players need, and the seam
	sock: SockCloth?, -- the Sock's mesh; without it, the Sock exceptions are off and every board gets the strict check
}

-- Product's condition 1 (docs/specs/v2/research/decisions-plans.md, "product on slide guards in the Belly zone") and
-- the plan's Task 23 test 3.
local MIN_GUARD_DEGREES = 72 -- a guard's faces that face up are at least this steep (V1's guards are 75 to 80)

local MAX_UP_NORMAL_Y = math.cos(math.rad(MIN_GUARD_DEGREES)) -- a face this steep has an up-direction of at most this

local NORMAL_SLACK = 1e-6 -- rounding in a face's direction

local MIN_CLOTH_DEGREES = 65 -- a guard stands on cloth this steep or more (spec 5, "Seam angle", the body-size slope)

-- The close-fit check (stuck safety Task 23, test 5): a guard is invisible, so the player sees the skin under it. A guard far
-- out from the skin looks like a float, and a guard sunk deep into it hides its slide.
local MAX_OUT = 1 -- studs a guard may stand out from the drawn skin around it

local MAX_IN = 0.5 -- studs a guard may sink into the drawn skin

local GAP_SLACK = 0.001 -- studs: rounding in the numbers written into the world

local GAP_REACH = 2 -- studs: the skin is looked for this far out from a point and this far in

local LIMITS: SockGuardReads.Limits = {
	minSlopeDegrees = MIN_CLOTH_DEGREES,
	maxOut = MAX_OUT,
	maxIn = MAX_IN,
	slack = GAP_SLACK,
	reach = GAP_REACH,
}

local KEEP_AWAY = 2 -- studs from every place players need, the seam and spec 5's steep layer

local BURY_STEP = 1 -- studs between the points checked on a face that faces up too flat

local SURFACE_STEP = 0.5 -- studs between the points of a guard's surface, for the distance to a walk piece

local SEGMENT_STEP = 0.25 -- studs between the points checked along a route link

local PROBE_SIZE = 0.2 -- studs: the ball that tests whether a point is inside a solid

local PROBE_NAME = "SlideGuardProbe"

local EXAMPLES_SHOWN = 3

-- The chair is part of this cloth piece's mesh, so only this cloth can be the chair (code_lead's ruling after 23-3).
-- His arms on the chair arms are in legs_and_boots and must be 65 degrees or steeper like any other cloth.
local CHAIR_CLOTH = "body_and_cushion"

-- Cloth under a guard is looked for from the 4 corners and the middle of its top face, this far in (code_lead's ruling
-- after step 23-8a, round 1, point 2a). With no cloth within reach the guard hangs over open air.
local CLOTH_REACH = 2 -- studs

-- Ruling 13 (docs/specs/v2/research/decisions-plans.md, "Task 23: the beard pocket and the decision table", approved by
-- product on 2026-10-26): the three beard pocket spots sit on cloth of 50 to 57 degrees with no walk out, so a small
-- guard there may stand on cloth gentler than MIN_CLOTH_DEGREES. The exception needs both the name and a box.
local BEARD_POCKET_GUARD_PATTERN = "^SlideGuard_BeardPocket_%d+$"

local function insideAnyBox(point: Vector3, boxes: { Box }): boolean
	for _, box in boxes do
		if
			point.X >= box.min.X
			and point.X <= box.max.X
			and point.Y >= box.min.Y
			and point.Y <= box.max.Y
			and point.Z >= box.min.Z
			and point.Z <= box.max.Z
		then
			return true
		end
	end
	return false
end

-- True when all 8 corners of the part's bounding box are inside one single box of `boxes` (Ruling 16).
local function insideOneBox(part: BasePart, boxes: { Box }): boolean
	local half = part.Size / 2
	for _, box in boxes do
		local allInside = true
		for _, signX in { -1, 1 } do
			for _, signY in { -1, 1 } do
				for _, signZ in { -1, 1 } do
					local corner = part.CFrame * Vector3.new(signX * half.X, signY * half.Y, signZ * half.Z)
					if not insideAnyBox(corner, { box }) then
						allInside = false
					end
				end
			end
		end
		if allInside then
			return true
		end
	end
	return false
end

-- The nearest the guard comes to a place players need. `surface` gives the points of the guard's surface (made once).
local function distanceToNeed(guard: BasePart, surface: () -> { Vector3 }, need: Need): number
	if need.kind == "point" then
		return PlayerNeeds.distanceToBox(need.a, guard.CFrame, guard.Size)
	elseif need.kind == "segment" then
		local to = need.b :: Vector3
		local length = (to - need.a).Magnitude
		local best = math.huge
		local steps = math.max(1, math.ceil(length / SEGMENT_STEP))
		for i = 0, steps do
			local point = need.a:Lerp(to, i / steps)
			best = math.min(best, PlayerNeeds.distanceToBox(point, guard.CFrame, guard.Size))
		end
		return best
	end
	local part = need.part :: BasePart
	-- Far apart for sure: skip the point-by-point measure.
	local reach = guard.Size.Magnitude / 2 + part.Size.Magnitude / 2 + KEEP_AWAY
	if (guard.Position - part.Position).Magnitude > reach then
		return math.huge
	end
	local best = math.huge
	for _, point in surface() do
		best = math.min(best, PlayerNeeds.distanceToBox(point, part.CFrame, part.Size))
	end
	return best
end

-- Every problem with the guards in `folder`, one line for each guard and kind of problem. Kinds:
--   Folder: the folder is missing or holds no guard.
--   Steepness: a face that faces up is flatter than MIN_GUARD_DEGREES and is not buried in a solid.
--   Cloth: at a corner or the middle of the sloped top face, the cloth behind the guard (found by a ray in, up to
--     CLOTH_REACH studs) is gentler than MIN_CLOTH_DEGREES (or there is none within reach) and the point is not
--     buried in a solid and is not the chair (body_and_cushion cloth only). Ruling 13's exception: a guard named
--     SlideGuard_BeardPocket_<n> with all 8 corners inside one beard pocket box is not checked for Cloth at all.
--   Distance: the guard comes within KEEP_AWAY studs of a place players need, the seam or the steep layer.
local function guardProblems(folder: Instance?, context: Context): { string }
	local guards: { BasePart } = {}
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(guards, child)
			end
		end
	end
	if #guards == 0 then
		return { `Folder: World.WalkSurfaces.{GUARD_FOLDER} is missing or holds no guard` }
	end

	local problems: { string } = {}
	-- A small ball that is moved onto each point of a flat face: a point inside a solid is buried. It is made once and
	-- destroyed at the end, even when a check throws.
	local probe = Instance.new("Part")
	probe.Name = PROBE_NAME
	probe.Shape = Enum.PartType.Ball
	probe.Size = Vector3.one * PROBE_SIZE
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = true
	probe.Archivable = false
	probe.Parent = context.world
	local inside = OverlapParams.new()
	inside.FilterType = Enum.RaycastFilterType.Include
	inside.FilterDescendantsInstances = context.solids
	inside.RespectCanCollide = false
	-- A Sock board is also buried in the Sock's mesh.
	local sockSolids = table.clone(context.solids)
	if context.sock ~= nil then
		for _, solid in context.sock.solids do
			table.insert(sockSolids, solid)
		end
	end
	local insideSock = OverlapParams.new()
	insideSock.FilterType = Enum.RaycastFilterType.Include
	insideSock.FilterDescendantsInstances = sockSolids
	insideSock.RespectCanCollide = false

	local ok, message = pcall(function(): string?
		for _, guard in guards do
			-- Task 37: a Sock lip board (with a Sock in the context) reads the Sock's mesh as its cloth, along its face
			-- (SockGuardReads); a skirt under a plate has no Cloth line.
			local sockCloth = if context.sock ~= nil and string.match(guard.Name, SOCK_GUARD_PATTERN) ~= nil
				then context.sock
				else nil
			local buriedIn = if sockCloth ~= nil then insideSock else inside
			local underPlate = plateUnder(guard, folder :: Instance) ~= nil
			-- Steepness: one line for the first open face that faces up too flat.
			for _, face in facesOf(guard) do
				local normal = guard.CFrame:VectorToWorldSpace(face.normal)
				if normal.Y > UP_FACE_MIN and normal.Y > MAX_UP_NORMAL_Y + NORMAL_SLACK then
					local open: Vector3? = nil
					for _, point in pointsOver(guard, face, BURY_STEP) do
						probe.Position = point
						if #context.world:GetPartsInPart(probe, buriedIn) == 0 then
							open = point
							break
						end
					end
					if open ~= nil then
						local degrees = math.deg(math.acos(math.clamp(normal.Y, -1, 1)))
						table.insert(
							problems,
							`Steepness: {guard.Name} has a face {string.format("%.0f", degrees)} degrees from flat that faces up, open at {describePoint(
								open
							)} (wanted at least {MIN_GUARD_DEGREES}, or buried)`
						)
						break
					end
				end
			end

			-- Cloth: the 4 corners and the middle of the sloped top face. From each, a ray goes in along the face's
			-- negative direction, up to CLOTH_REACH studs; its hit is the cloth point. None within reach means the
			-- guard hangs over open air.
			local top = topFaceOf(guard)
			local topNormal = guard.CFrame:VectorToWorldSpace(top.normal)
			local spots: { Vector3 } = { guard.CFrame:PointToWorldSpace(top.center) }
			for _, sideways in { -1, 1 } do
				for _, lengthways in { -1, 1 } do
					local corner = top.center + top.u * (sideways * top.uHalf) + top.v * (lengthways * top.vHalf)
					table.insert(spots, guard.CFrame:PointToWorldSpace(corner))
				end
			end
			local gentle = 0
			local example: string? = nil
			local function isBuried(point: Vector3): boolean
				probe.Position = point
				return #context.world:GetPartsInPart(probe, buriedIn) > 0
			end
			if sockCloth ~= nil and not underPlate then
				gentle, example =
					SockGuardReads.clothGentle(guard, top, spots, sockCloth, context.world, isBuried, LIMITS)
			end
			local strictSpots: { Vector3 } = if sockCloth == nil then spots else {}
			for _, spot in strictSpots do
				-- A point buried in his solid shape or the pillow is skipped (decision 4 buries a guard's top end). The
				-- chair exception counts only for the chair's own cloth, never for another piece.
				local buried = isBuried(spot)
				local chair = insideAnyBox(spot, context.chairBoxes)
					and context.clothNameAt(spot.X, spot.Z) == CHAIR_CLOTH
				if not buried and not chair then
					local hit = context.world:Raycast(spot, -topNormal * CLOTH_REACH, context.clothParams)
					local slope = if hit ~= nil then context.slopeAt(hit.Position, topNormal) else nil
					if slope == nil or slope < MIN_CLOTH_DEGREES then
						gentle += 1
						if example == nil then
							example = if hit == nil
								then `no cloth within {CLOTH_REACH} studs in from {describePoint(spot)}`
								elseif slope == nil then `the slope can't be read at {describePoint(hit.Position)}`
								else `{string.format("%.0f", slope)} degrees at {describePoint(hit.Position)}`
						end
					end
				end
			end
			-- Ruling 13 and Ruling 16: a beard pocket guard (by name) with all 8 corners in one pocket box skips this check.
			local pocketGuard = string.match(guard.Name, BEARD_POCKET_GUARD_PATTERN) ~= nil
				and insideOneBox(guard, context.beardPocketBoxes)
			if gentle > 0 and not pocketGuard and not underPlate then
				table.insert(
					problems,
					`Cloth: {guard.Name} stands on cloth under {MIN_CLOTH_DEGREES} degrees at {gentle} of {#spots} points, for example {example :: string}`
				)
			end

			-- Distance: the closest few places players need.
			local surface: { Vector3 }? = nil
			local function guardSurface(): { Vector3 }
				if surface == nil then
					local all: { Vector3 } = {}
					for _, face in facesOf(guard) do
						for _, point in pointsOver(guard, face, SURFACE_STEP) do
							table.insert(all, point)
						end
					end
					surface = all
				end
				return surface :: { Vector3 }
			end
			local near: { { name: string, distance: number } } = {}
			for _, need in context.needs do
				local distance = distanceToNeed(guard, guardSurface, need)
				if distance < KEEP_AWAY then
					table.insert(near, { name = need.name, distance = distance })
				end
			end
			if #near > 0 then
				table.sort(near, function(a, b)
					return a.distance < b.distance
				end)
				local shown: { string } = {}
				for index = 1, math.min(#near, EXAMPLES_SHOWN) do
					table.insert(shown, `{near[index].name} ({string.format("%.2f", near[index].distance)})`)
				end
				table.insert(
					problems,
					`Distance: {guard.Name} is within {KEEP_AWAY} studs of {#near} places, nearest {table.concat(
						shown,
						", "
					)}`
				)
			end
		end
		return nil
	end)
	probe:Destroy()
	if not ok then
		error(message, 0)
	end
	return problems
end

-- Stuck safety Task 23, test 5 (docs/plans/v2/stuck-safety.md, "slide guards lie close to what players see"). A guard
-- is invisible, so the player sees the skin under it: a guard far out from the skin looks like a float, and a guard
-- sunk deep into it hides its slide. On a 1-stud grid over each guard's top face, the guard stays within these
-- distances of the drawn skin. The distance is measured straight out from the face, because a guard is steep: a gap
-- measured straight down would read 3 to 4 times too big.
local GRID_STEP = 1 -- studs between the points on a guard's top face

local GAP_MARCH = 0.05 -- studs between the reads along that line

local SKIN_WINDOW = 4 -- studs: the skin is read up to this far over a read point (a sunk steep face has skin well over it)

-- How far the point is out from the drawn skin, measured along `normal` (the face's outward direction): positive when
-- the skin lies behind the point, negative when the point is sunk into the skin. Nil when no skin crosses the line
-- within GAP_REACH either way.
local function gapToSkin(skin: DrawnSkin.Skin, point: Vector3, normal: Vector3): number?
	local function over(along: number): number?
		local at = point + normal * along
		local height = skin.heightAt(at.X, at.Z, at.Y + SKIN_WINDOW)
		return if height ~= nil then at.Y - height else nil
	end
	local startValue = over(0)
	if startValue == 0 then
		return 0
	end
	local lastAlong: { [number]: number } = { [-1] = 0, [1] = 0 }
	local lastValue: { [number]: number? } = { [-1] = startValue, [1] = startValue }
	for step = 1, math.floor(GAP_REACH / GAP_MARCH + 0.5) do
		for _, direction in { -1, 1 } do
			local along = direction * step * GAP_MARCH
			local value = over(along)
			local before = lastValue[direction]
			if value ~= nil then
				if before ~= nil and (before > 0) ~= (value > 0) then
					local fraction = before / (before - value)
					return -(lastAlong[direction] + (along - lastAlong[direction]) * fraction)
				end
				lastValue[direction] = value
				lastAlong[direction] = along
			end
		end
	end
	return nil
end

-- Every problem with how close the guards in `folder` lie to `skin`, one line for each guard and kind of problem:
--   Folder: the folder is missing or holds no guard.
--   Top: a guard has no face that faces up.
--   Out: the guard stands out from the skin by more than MAX_OUT at some points.
--   In: the guard sinks into the skin by more than MAX_IN at some points.
--   Skin: no drawn skin within GAP_REACH of some points.
-- `sockSkin` is the Sock's drawn skin for the Sock lip boards (Task 37); a skirt under a plate gets no line.
local function guardCloseProblems(folder: Instance?, skin: DrawnSkin.Skin, sockSkin: DrawnSkin.Skin?): { string }
	local guards: { BasePart } = {}
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(guards, child)
			end
		end
	end
	if #guards == 0 then
		return { `Folder: World.WalkSurfaces.{GUARD_FOLDER} is missing or holds no guard` }
	end

	local problems: { string } = {}
	for _, guard in guards do
		-- Task 37: a skirt under a plate is read against that plate (no line); a Sock lip board reads the Sock's drawn
		-- skin (see SOCK_GUARD_PATTERN).
		if plateUnder(guard, folder :: Instance) ~= nil then
			continue
		end
		local lipSkin = if sockSkin ~= nil and string.match(guard.Name, SOCK_GUARD_PATTERN) ~= nil
			then sockSkin
			else nil
		-- The top face: the biggest face that faces up.
		local top: Face? = nil
		local topNormal = Vector3.yAxis
		for _, face in facesOf(guard) do
			local normal = guard.CFrame:VectorToWorldSpace(face.normal)
			if normal.Y > UP_FACE_MIN and (top == nil or face.uHalf * face.vHalf > top.uHalf * top.vHalf) then
				top = face
				topNormal = normal
			end
		end
		if top == nil then
			table.insert(problems, `Top: {guard.Name} has no face that faces up`)
			continue
		end

		-- Every grid point that fails, with how far out it is: a lip board is read along its face (SockGuardReads), any
		-- other guard straight out from its face.
		local failures: { SockGuardReads.Failure }
		local pointCount: number
		if lipSkin ~= nil then
			failures, pointCount = SockGuardReads.skinFailures(guard, folder :: Instance, lipSkin, LIMITS)
		else
			failures = {}
			local points = pointsOver(guard, top, GRID_STEP)
			pointCount = #points
			for _, point in points do
				local gap = gapToSkin(skin, point, topNormal)
				local kind = SockGuardReads.classifyGap(gap, LIMITS)
				if kind ~= nil then
					table.insert(failures, { point = point, kind = kind, gap = gap })
				end
			end
		end
		local tooFar, worstOut, outExample = 0, 0, nil :: Vector3?
		local tooDeep, worstIn, inExample = 0, 0, nil :: Vector3?
		local missing, missingExample = 0, nil :: Vector3?
		for _, failure in failures do
			local gap = failure.gap
			if failure.kind == "missing" then
				missing += 1
				missingExample = missingExample or failure.point
			elseif failure.kind == "out" and gap ~= nil then
				tooFar += 1
				if gap > worstOut then
					worstOut, outExample = gap, failure.point
				end
			elseif gap ~= nil then
				tooDeep += 1
				if -gap > worstIn then
					worstIn, inExample = -gap, failure.point
				end
			end
		end
		if tooFar > 0 then
			table.insert(
				problems,
				`Out: {guard.Name} stands up to {string.format("%.2f", worstOut)} studs out from the drawn skin at {tooFar} of {pointCount} points (wanted at most {MAX_OUT}), worst at {describePoint(
					outExample :: Vector3
				)}`
			)
		end
		if tooDeep > 0 then
			table.insert(
				problems,
				`In: {guard.Name} sinks up to {string.format("%.2f", worstIn)} studs into the drawn skin at {tooDeep} of {pointCount} points (wanted at most {MAX_IN}), worst at {describePoint(
					inExample :: Vector3
				)}`
			)
		end
		if missing > 0 then
			table.insert(
				problems,
				`Skin: {guard.Name} has no drawn skin within {GAP_REACH} studs at {missing} of {pointCount} points, for example at {describePoint(
					missingExample :: Vector3
				)}`
			)
		end
	end
	return problems
end

-- Row 3c+ (Ruling 47): every problem with a Sock lip board's foot leaning out, one line for each board. Under knee height
-- a lip board is not read against the drawn skin, so its face may not stand further out at the foot than it does at its
-- knee point by more than LEAN. A skirt under a plate is read against that plate and has no line.
local function guardLeanProblems(folder: Instance?): { string }
	local problems: { string } = {}
	if folder == nil then
		return problems
	end
	for _, guard in folder:GetChildren() do
		if
			guard:IsA("BasePart")
			and string.match(guard.Name, SOCK_GUARD_PATTERN) ~= nil
			and plateUnder(guard, folder) == nil
			and guard.CFrame:VectorToWorldSpace(topFaceOf(guard).normal).Y > UP_FACE_MIN
		then
			local worst: { point: Vector3, lean: number }? = nil
			local failures = SockGuardReads.leanFailures(guard)
			for _, failure in failures do
				if worst == nil or failure.lean > worst.lean then
					worst = failure
				end
			end
			if worst ~= nil then
				problems[#problems + 1] =
					`Lean: {guard.Name} leans out up to {string.format("%.2f", worst.lean)} studs past its knee point at {#failures} places under knee height (wanted at most {SockGuardReads.LEAN}), worst at {describePoint(
						worst.point
					)}`
			end
		end
	end
	return problems
end

local function fakeFolder(world: WorldModel): Folder
	local folder = Instance.new("Folder")
	folder.Name = GUARD_FOLDER
	folder.Parent = world
	return folder
end

-- A solid wall: everything at z 0 or less, from y -30 to 30.
local function addWall(world: WorldModel): Part
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = Vector3.new(60, 60, 60)
	wall.Position = Vector3.new(0, 0, -30)
	wall.Anchored = true
	wall.CanCollide = true
	wall.Parent = world
	return wall
end

-- A thin board `length` studs long and 4 wide. Its big faces slope `degrees` from flat, facing +z and up. Its top end
-- centre is at `topEnd`; the board leans down and out toward +z from there.
local function addBoard(folder: Folder, topEnd: Vector3, degrees: number, length: number): Part
	local fromVertical = math.rad(90 - degrees)
	local board = Instance.new("Part")
	board.Name = "SlideGuard_Fake_1"
	board.Size = Vector3.new(4, length, 0.5)
	board.CFrame = CFrame.new(topEnd) * CFrame.Angles(-fromVertical, 0, 0) * CFrame.new(0, -length / 2, 0)
	board.Anchored = true
	board.CanCollide = true
	board.Parent = folder
	return board
end

return {
	CHAIR_CLOTH = CHAIR_CLOTH,
	addBoard = addBoard,
	addWall = addWall,
	GUARD_FOLDER = GUARD_FOLDER,
	LEAN = SockGuardReads.LEAN,
	fakeFolder = fakeFolder,
	guardCloseProblems = guardCloseProblems,
	guardLeanProblems = guardLeanProblems,
	guardProblems = guardProblems,
}
