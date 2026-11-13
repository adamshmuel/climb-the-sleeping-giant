--!strict
-- Task 37: how the slide guard checks read the Sock's boards (SlideGuard_Sock_<n>). Two named exceptions came first
-- (product and designer, 2026-10-27, work/handoff-p2-task35.md); Ruling 47 (work/handoff-p2-task37.md) then made the lip
-- boards read along their own face. Only a board named like SOCK_GUARD_PATTERN can use any of this.
--   Row 4, the plate rule for skirts: a skirt under one of Task 32's plates (SOCK_PLATE_PATTERN, in the patch folder next
--   to the guard folder) is read against that plate, so it has no Cloth or Skin line. It must sit inside the plate's
--   footprint, with its top within PLATE_TOP_SLACK of the plate's bottom, and its front no further out than the plate's.
--   Row 3, the lip boards (every other Sock board). The Sock's lip is a thin upright curtain, so a straight-down read
--   misses it. The cloth and the drawn skin are read along the board's flat line: the face's outward direction with its up
--   part taken out.
--     3a: the cloth, with a fan of rays; 3b: the drawn skin, with a line read.
--     3c: the knee band. Under knee height (KNEE_HEIGHT above the board's lowest point) a point is not read, column by
--     column, while the lowest point above knee height passes 3b by itself.
--     3c+: no lean at the foot (leanFailures). 3d: the plate rule for lip boards. 3e: a board with no point above knee
--     height is read in full. 3f: the steepness check is never skipped (it lives in SlideGuardHelpers).
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local Helpers = require(script.Parent.Helpers)
type Face = Helpers.Face
local cornersOf = Helpers.cornersOf
local describePoint = Helpers.describePoint
local pointsOver = Helpers.pointsOver
local topFaceOf = Helpers.topFaceOf

-- The Sock's mesh as cloth: for the Sock's lip boards only.
export type SockCloth = {
	clothParams: RaycastParams, -- a ray may hit only the Sock's mesh
	-- A made-up reader for the slope at a cloth point, used by the made-up-world tests. The real Sock leaves it nil, and
	-- the slope is read from a fan of rays along the face.
	slopeAt: ((point: Vector3, normal: Vector3) -> number?)?,
	solids: { Instance }, -- the Sock's mesh: a buried face or corner of a Sock board is buried in it too
}

-- The limits the slide guard checks hold every guard to, handed in so they are written once (SlideGuardHelpers).
export type Limits = {
	minSlopeDegrees: number, -- cloth under a guard is at least this steep
	maxOut: number, -- studs a guard may stand out from the drawn skin
	maxIn: number, -- studs a guard may sink into it
	slack: number, -- rounding in the numbers written into the world
	reach: number, -- studs: the skin is looked for this far out from a point and this far in
}

-- A grid point that fails the close-fit check: "out" (too far from the skin), "in" (sunk too deep) or "missing" (no
-- drawn skin within reach).
export type Failure = { point: Vector3, kind: string, gap: number? }

local SOCK_GUARD_PATTERN = "^SlideGuard_Sock_%d+$"
local SOCK_PLATE_PATTERN = "^Patch_Sock_%d+$"
local PLATE_TOP_SLACK = 0.05 -- studs: a skirt's top and the plate's bottom may differ by this much
local PLATE_FIT_SLACK = 1e-3 -- studs: rounding in a skirt's footprint and front against the plate's
local MIN_FRONT_PART = 1e-3 -- a face whose sideways part is flatter than this has no front

local KNEE_HEIGHT = 1.5 -- studs above a board's lowest point (designer: the knee of a standard avatar)
local LEAN = 0.1 -- studs: under knee height a board's face may stand this far out past its face at the knee point
local PLATE_BEHIND = 0.25 -- studs: a plate this far behind a point (or nearer) excuses it (product's Ruling 41 limit)
local PLATE_START_OUT = 0.5 -- studs: the plate ray starts this far out from the point

local CLOTH_START_OUT = 0.5 -- studs: a cloth ray starts this far out from its spot
local CLOTH_RAY_LENGTH = 2.5 -- studs: and goes this far in, so it reaches 2 studs behind the spot
local FAN_STEP = 0.5 -- studs between the rays of the 3 by 3 fan
local MIN_FAN_HITS = 5 -- fewer hits than this and the slope can't be read

local GRID_STEP = 1 -- studs between the points of a board's face (the close-fit check's grid)

local function platesIn(guardFolder: Instance): { BasePart }
	local found: { BasePart } = {}
	local plates = if guardFolder.Parent ~= nil
		then guardFolder.Parent:FindFirstChild(Helpers.SMALL_PATCHES_FOLDER)
		else nil
	if plates ~= nil then
		for _, plate in plates:GetChildren() do
			if plate:IsA("BasePart") and string.match(plate.Name, SOCK_PLATE_PATTERN) ~= nil then
				table.insert(found, plate)
			end
		end
	end
	return found
end

-- The plate of Task 32 that `guard` (a Sock skirt) sits flush under, or nil: the guard is not named like a Sock guard, no
-- plate fits, or one of the three limits above is missed.
local function plateUnder(guard: BasePart, guardFolder: Instance): BasePart?
	if string.match(guard.Name, SOCK_GUARD_PATTERN) == nil then
		return nil
	end
	local normal = guard.CFrame:VectorToWorldSpace(topFaceOf(guard).normal)
	local sideways = Vector3.new(normal.X, 0, normal.Z)
	if sideways.Magnitude < MIN_FRONT_PART then
		return nil
	end
	local front = sideways.Unit
	local guardCorners = cornersOf(guard)
	local guardTop, guardFront = -math.huge, -math.huge
	for _, corner in guardCorners do
		guardTop = math.max(guardTop, corner.Y)
		guardFront = math.max(guardFront, corner:Dot(front))
	end
	for _, plate in platesIn(guardFolder) do
		local half = plate.Size / 2
		local inside = true
		for _, corner in guardCorners do
			local local_ = plate.CFrame:PointToObjectSpace(corner)
			if math.abs(local_.X) > half.X + PLATE_FIT_SLACK or math.abs(local_.Z) > half.Z + PLATE_FIT_SLACK then
				inside = false
			end
		end
		local plateBottom, plateFront = math.huge, -math.huge
		for _, corner in cornersOf(plate) do
			plateBottom = math.min(plateBottom, corner.Y)
			plateFront = math.max(plateFront, corner:Dot(front))
		end
		if
			inside
			and math.abs(guardTop - plateBottom) <= PLATE_TOP_SLACK
			and guardFront <= plateFront + PLATE_FIT_SLACK
		then
			return plate
		end
	end
	return nil
end

-- The flat line: the face's outward direction with its up part taken out, 1 stud long. A face that looks straight up has
-- none, and its line is the face's own direction (straight up).
local function outwardOf(normal: Vector3): Vector3
	local sideways = Vector3.new(normal.X, 0, normal.Z)
	return if sideways.Magnitude >= MIN_FRONT_PART then sideways.Unit else normal
end

-- The height of a board's lowest corner and of its highest.
local function heightsOf(guard: BasePart): (number, number)
	local lowest, highest = math.huge, -math.huge
	for _, corner in cornersOf(guard) do
		lowest = math.min(lowest, corner.Y)
		highest = math.max(highest, corner.Y)
	end
	return lowest, highest
end

-- The grid points of the face in columns side by side across the board, each column from its lowest point up, and the
-- direction across the board.
local function columnsOf(guard: BasePart, top: Face, out: Vector3): ({ { Vector3 } }, Vector3)
	local across = out:Cross(Vector3.yAxis)
	if across.Magnitude < MIN_FRONT_PART then
		across = guard.CFrame:VectorToWorldSpace(top.u)
	end
	across = across.Unit
	local byKey: { [number]: { Vector3 } } = {}
	local keys: { number } = {}
	for _, point in pointsOver(guard, top, GRID_STEP) do
		local key = math.floor(point:Dot(across) * 1000 + 0.5)
		if byKey[key] == nil then
			byKey[key] = {}
			table.insert(keys, key)
		end
		table.insert(byKey[key], point)
	end
	table.sort(keys)
	local columns: { { Vector3 } } = {}
	for _, key in keys do
		local column = byKey[key]
		table.sort(column, function(a, b)
			return a.Y < b.Y
		end)
		table.insert(columns, column)
	end
	return columns, across
end

-- 3a: how many of the cloth `spots` the Sock's mesh does not hold steep enough, and the first example. Each spot sends a 3
-- by 3 fan of rays in along the flat line (0.5 apart across and along the face); the average up part of the hit
-- directions must be at most the cosine of the limit. Fewer than MIN_FAN_HITS hits means the slope can't be read. Under
-- knee height a spot is not read (3c), unless the whole board is under it (3e). A buried spot is skipped.
local function clothGentle(
	guard: BasePart,
	top: Face,
	spots: { Vector3 },
	sock: SockCloth,
	world: WorldRoot,
	isBuried: (point: Vector3) -> boolean,
	limits: Limits
): (number, string?)
	local normal = guard.CFrame:VectorToWorldSpace(top.normal)
	local out = outwardOf(normal)
	local across = guard.CFrame:VectorToWorldSpace(top.u) * FAN_STEP
	local along = guard.CFrame:VectorToWorldSpace(top.v) * FAN_STEP
	local lowest, highest = heightsOf(guard)
	local knee = lowest + KNEE_HEIGHT
	local maxUp = math.cos(math.rad(limits.minSlopeDegrees))
	local reach = CLOTH_RAY_LENGTH - CLOTH_START_OUT
	local gentle = 0
	local example: string? = nil
	for _, spot in spots do
		if (highest > knee and spot.Y < knee) or isBuried(spot) then
			continue
		end
		local hits: { RaycastResult } = {}
		for _, first in { 0, -1, 1 } do
			for _, second in { 0, -1, 1 } do
				local origin = spot + out * CLOTH_START_OUT + across * first + along * second
				local hit = world:Raycast(origin, -out * CLOTH_RAY_LENGTH, sock.clothParams)
				if hit ~= nil then
					table.insert(hits, hit)
				end
			end
		end
		local slope: number? = nil
		if #hits > 0 then
			if sock.slopeAt ~= nil then
				slope = sock.slopeAt(hits[1].Position, normal)
			elseif #hits >= MIN_FAN_HITS then
				local up = 0
				for _, hit in hits do
					up += hit.Normal.Y
				end
				slope = math.deg(math.acos(math.clamp(up / #hits, -1, 1)))
			end
		end
		local steep = slope ~= nil and math.cos(math.rad(slope)) <= maxUp + 1e-9
		if not steep then
			gentle += 1
			if example == nil then
				example = if #hits == 0
					then `no cloth within {reach} studs in from {describePoint(spot)}`
					elseif slope == nil then `the slope can't be read at {describePoint(hits[1].Position)}`
					else `{string.format("%.0f", slope)} degrees at {describePoint(hits[1].Position)}`
			end
		end
	end
	return gentle, example
end

-- "out", "in" or "missing" for the gap from a point to the drawn skin (positive when the skin lies behind the point), or
-- nil when the point is close enough.
local function classifyGap(gap: number?, limits: Limits): string?
	if gap == nil then
		return "missing"
	elseif gap > limits.maxOut + limits.slack then
		return "out"
	elseif gap < -limits.maxIn - limits.slack then
		return "in"
	end
	return nil
end

-- 3b, 3c, 3d and 3e: the grid points of a lip board's face that fail the close-fit check against the Sock's drawn skin,
-- and how many points the grid has. The skin is read along the flat line: it starts reach studs out from the point and
-- runs 2 * reach in, and the gap is the distance to the first triangle minus reach. In a column whose lowest point above
-- knee height passes by itself, the points under it are not read (3c). Above knee height, a point that is too far out or
-- has no skin passes when a plate of Task 32 stands within PLATE_BEHIND behind it on the same line (3d); a point sunk in
-- never does. A column with no point above knee height is read in full (3e).
local function skinFailures(
	guard: BasePart,
	folder: Instance,
	skin: DrawnSkin.Skin,
	limits: Limits
): ({ Failure }, number)
	local top = topFaceOf(guard)
	local out = outwardOf(guard.CFrame:VectorToWorldSpace(top.normal))
	local lowest = heightsOf(guard)
	local knee = lowest + KNEE_HEIGHT
	local world = guard:FindFirstAncestorWhichIsA("WorldRoot")
	local plates = platesIn(folder)
	local plateParams = RaycastParams.new()
	plateParams.FilterType = Enum.RaycastFilterType.Include
	plateParams.FilterDescendantsInstances = plates :: { any }
	plateParams.RespectCanCollide = false
	local function plateBehind(point: Vector3): boolean
		if world == nil or #plates == 0 then
			return false
		end
		local origin = point + out * PLATE_START_OUT
		return world:Raycast(origin, -out * (PLATE_START_OUT + PLATE_BEHIND), plateParams) ~= nil
	end

	local failures: { Failure } = {}
	local total = 0
	for _, column in (columnsOf(guard, top, out)) do
		total += #column
		local gaps: { number? } = {}
		local kinds: { string? } = {}
		local firstAbove: number? = nil
		for index, point in column do
			local distance = skin.distanceAlong(point + out * limits.reach, -out, 2 * limits.reach)
			gaps[index] = if distance ~= nil then distance - limits.reach else nil
			kinds[index] = classifyGap(gaps[index], limits)
			if firstAbove == nil and point.Y >= knee then
				firstAbove = index
			end
		end
		local bandHolds = firstAbove ~= nil and kinds[firstAbove] == nil
		for index, point in column do
			local kind = kinds[index]
			if bandHolds and index < (firstAbove :: number) then
				continue
			end
			if kind ~= nil and kind ~= "in" and point.Y >= knee and plateBehind(point) then
				kind = nil
			end
			if kind ~= nil then
				table.insert(failures, { point = point, kind = kind, gap = gaps[index] })
			end
		end
	end
	return failures, total
end

-- 3c+: where a lip board's face, under knee height, stands further out along the flat line than its face at the lowest grid
-- point above knee height, by more than LEAN. Checked at every grid point under knee height and at the board's bottom
-- edge, column by column. Returns each such place with how far out it is.
local function leanFailures(guard: BasePart): { { point: Vector3, lean: number } }
	local top = topFaceOf(guard)
	local out = outwardOf(guard.CFrame:VectorToWorldSpace(top.normal))
	local lowest = heightsOf(guard)
	local knee = lowest + KNEE_HEIGHT
	local columns, across = columnsOf(guard, top, out)
	-- The face's bottom edge: its two lowest corners.
	local corners: { Vector3 } = {}
	for _, sideways in { -1, 1 } do
		for _, lengthways in { -1, 1 } do
			local corner = top.center + top.u * (sideways * top.uHalf) + top.v * (lengthways * top.vHalf)
			table.insert(corners, guard.CFrame:PointToWorldSpace(corner))
		end
	end
	table.sort(corners, function(a, b)
		return a.Y < b.Y
	end)
	local edgeStart, edgeEnd = corners[1], corners[2]
	local failures: { { point: Vector3, lean: number } } = {}
	for _, column in columns do
		local reference: Vector3? = nil
		for _, point in column do
			if point.Y >= knee then
				reference = point
				break
			end
		end
		if reference == nil then
			continue
		end
		local referenceOut = (reference :: Vector3):Dot(out)
		local places: { Vector3 } = {}
		for _, point in column do
			if point.Y < knee then
				table.insert(places, point)
			end
		end
		local from, to = edgeStart:Dot(across), edgeEnd:Dot(across)
		local fraction = if math.abs(to - from) < MIN_FRONT_PART
			then 0.5
			else math.clamp((column[1]:Dot(across) - from) / (to - from), 0, 1)
		table.insert(places, edgeStart:Lerp(edgeEnd, fraction))
		for _, place in places do
			local lean = place:Dot(out) - referenceOut
			if lean > LEAN + 1e-9 then
				table.insert(failures, { point = place, lean = lean })
			end
		end
	end
	return failures
end

return {
	LEAN = LEAN,
	SOCK_GUARD_PATTERN = SOCK_GUARD_PATTERN,
	classifyGap = classifyGap,
	clothGentle = clothGentle,
	leanFailures = leanFailures,
	plateUnder = plateUnder,
	skinFailures = skinFailures,
}
