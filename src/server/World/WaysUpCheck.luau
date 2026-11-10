--!strict
-- The ways-up check (plan 5 Task 18; spec 5 Rule 82 "No new way onto the belly"): it holds the walk part (is the lap landing
-- the only way onto the belly?) and the jump part (does a jump reach the belly, a climb or a nest?). Pure checks that run only in tests, never per frame.
--
-- Each check returns a list of problems, empty when the check passes. The caller names the parts (Rules); this module
-- names none.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(script.Parent.PathCheck)
local WalkAreaCheck = require(script.Parent.WalkAreaCheck)

export type Problem = WalkAreaCheck.Problem
export type Rules = {
	-- A spot the walk starts from (a boot top).
	isSource: (PathCheck.Spot) -> boolean,
	-- A spot the walk may not use (the lap landing and its apron).
	isTakenOut: (PathCheck.Spot) -> boolean,
	-- A spot on the belly.
	isBelly: (PathCheck.Spot) -> boolean,
}

-- Jump part (plan 5 Task 18a Step 2). Feet positions; the jump numbers are Config.Nests.Jump.
export type JumpSurface = { name: string, points: { Vector3 } }
export type JumpInput = {
	surfaces: { JumpSurface },
	walkArea: { Vector3 },
	ignore: { Instance },
	trusses: { BasePart },
	nests: { Vector3 },
	-- Feet spots a body can stand on (every walk-map spot and every guard top point).
	stands: { Vector3 },
}

local WaysUpCheck = {}

local WALK_ABOVE = 12 -- studs: a walk-area spot in reach of a jump surface sits at least this far above it
local RAY_START_ABOVE = 0.5 -- studs: the ray down from a walk-area spot starts this far above it...
local RAY_LENGTH = 60 -- ...and reaches this far down
local TRUSS_ABOVE = 15 -- studs: a climbable part within reach of a jump surface has its lowest corner this far above it
local NEST_CLEAR = 8 -- studs: a nest is this far or farther (plain 3D) from every stand a jump reaches
local START_NEAR = 1 -- studs: a point this close to a start counts as reached without a jump
local NO_SOLID = -math.huge -- the ray found nothing

local NO_LINKS: { PathCheck.Link } = {}

local function problem(kind: string, position: Vector3, detail: string): Problem
	return { kind = kind, position = position, detail = detail }
end

-- Ids of the belly spots reached by a flood over links of every kind (Walk, Climb, Slide) from every source spot, in
-- the order the flood found them. With takeOut true, spots where isTakenOut is true are never entered and never used
-- as a source.
function WaysUpCheck.bellyReached(map: PathCheck.WalkMap, rules: Rules, takeOut: boolean): { number }
	local seen: { [number]: boolean } = {}
	local queue: { number } = {}
	local reached: { number } = {}
	local function enter(spot: PathCheck.Spot)
		if seen[spot.id] or (takeOut and rules.isTakenOut(spot)) then
			return
		end
		seen[spot.id] = true
		table.insert(queue, spot.id)
	end
	for _, spot in map.spots do
		if rules.isSource(spot) then
			enter(spot)
		end
	end
	local head = 1
	while head <= #queue do
		local id = queue[head]
		head += 1
		if rules.isBelly(map.spots[id]) then
			table.insert(reached, id)
		end
		for _, link in map.links[id] or NO_LINKS do
			enter(map.spots[link.to])
		end
	end
	return reached
end

-- The control (nothing taken out) must reach the belly, else one "control" problem: a broken flood is not a pass.
-- Then each belly spot still reached with the landing taken out is a "skips the landing" problem; the first one in
-- flood order is named in every detail.
function WaysUpCheck.skipsLanding(map: PathCheck.WalkMap, rules: Rules): { Problem }
	local control = WaysUpCheck.bellyReached(map, rules, false)
	if #control == 0 then
		return { problem("control", Vector3.zero, "no route reaches the belly even with nothing taken out") }
	end
	local skipped = WaysUpCheck.bellyReached(map, rules, true)
	local problems: { Problem } = {}
	if #skipped == 0 then
		return problems
	end
	local first = map.spots[skipped[1]].position
	for _, id in skipped do
		local at = map.spots[id].position
		table.insert(
			problems,
			problem(
				"skips the landing",
				at,
				`belly spot at {at} reached without the landing; the walk's first is at {first}`
			)
		)
	end
	return problems
end

-- Whether a jump from one standing place reaches another (Task 41 ruling 6): up to the jump height, and across as far
-- as walking speed carries the player while in the air, plus 1 stud.
function WaysUpCheck.jumpReaches(
	from: Vector3,
	to: Vector3,
	jumpHeight: number,
	gravity: number,
	walkSpeed: number
): boolean
	local rise = to.Y - from.Y
	if rise > jumpHeight then
		return false
	end
	local launch = math.sqrt(2 * gravity * jumpHeight)
	local airTime = (launch + math.sqrt(math.max(0, launch * launch - 2 * gravity * rise))) / gravity
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude
	return flat <= walkSpeed * airTime + 1
end

-- Where the body is at the top of a jump between two places: halfway across, half the jump height above the higher end.
function WaysUpCheck.apexBetween(from: Vector3, to: Vector3, jumpHeight: number): Vector3
	local middle = (from + to) / 2
	return middle + Vector3.new(0, math.max(from.Y, to.Y) - middle.Y + jumpHeight * 0.5, 0)
end

-- Rule 1, walk area: no walk-area spot above a jump surface point, within Across of it (flat), is less than
-- WALK_ABOVE above it. The spot's own column counts too: a ray down from it (every solid part, `ignore` left out)
-- finds the highest solid beneath, and that top is one more surface point when it is within Up + BodyHeight above the
-- point. One problem per surface point and spot, the first rule that fails.
local function walkAreaProblems(world: WorldRoot, input: JumpInput, problems: { Problem })
	local jump = Config.Nests.Jump
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = input.ignore
	params.RespectCanCollide = true
	-- The walk area, lowest x first, so a surface point only looks at the spots in its x band.
	local spots = table.clone(input.walkArea)
	table.sort(spots, function(a, b)
		return a.X < b.X
	end)
	local tops: { [number]: number } = {} -- spot index -> the top of the highest solid under it
	local function topUnder(index: number): number
		local cached = tops[index]
		if cached == nil then
			local spot = spots[index]
			local hit = world:Raycast(spot + Vector3.new(0, RAY_START_ABOVE, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
			cached = if hit then hit.Position.Y else NO_SOLID
			tops[index] = cached
		end
		return cached
	end
	for _, surface in input.surfaces do
		for _, point in surface.points do
			-- The first spot with x at least point.X - Across (binary search).
			local low, high = 1, #spots + 1
			while low < high do
				local middle = (low + high) // 2
				if spots[middle].X < point.X - jump.Across then
					low = middle + 1
				else
					high = middle
				end
			end
			local index = low
			while index <= #spots and spots[index].X <= point.X + jump.Across do
				local spot = spots[index]
				local flat = Vector3.new(spot.X - point.X, 0, spot.Z - point.Z).Magnitude
				if flat <= jump.Across and spot.Y > point.Y then
					local above = spot.Y - point.Y
					local reason: string? = if above < WALK_ABOVE then `{above} above the point` else nil
					if reason == nil then
						local top = topUnder(index)
						if top ~= NO_SOLID and top < spot.Y and top - point.Y <= jump.Up + jump.BodyHeight then
							local over = spot.Y - top
							if over < WALK_ABOVE then
								reason = `{over} above the solid under it (top {top}, {top - point.Y} above the point)`
							end
						end
					end
					if reason ~= nil then
						local detail = `{surface.name}: point {point}, spot {spot}, {reason}; limit {WALK_ABOVE}`
						table.insert(problems, problem("walk area", spot, detail))
					end
				end
				index += 1
			end
		end
	end
end

-- The lowest and highest corner of a part's box on x, y and z (the axis-aligned bounds of its eight corners).
local function boundsOf(part: BasePart): (Vector3, Vector3)
	local half = part.Size / 2
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return low, high
end

-- Rule 2, climbable parts: a part a player can climb, within Across (flat) of a jump surface point's reach, has its
-- lowest corner at least TRUSS_ABOVE above the point. One problem per surface and part (the first point that fails).
local function climbableProblems(input: JumpInput, problems: { Problem })
	local jump = Config.Nests.Jump
	for _, part in input.trusses do
		local low, high = boundsOf(part)
		for _, surface in input.surfaces do
			for _, point in surface.points do
				local flat = Vector3.new(
					math.max(low.X - point.X, 0, point.X - high.X),
					0,
					math.max(low.Z - point.Z, 0, point.Z - high.Z)
				).Magnitude
				local above = low.Y - point.Y
				if flat <= jump.Across and above < TRUSS_ABOVE then
					local detail =
						`{surface.name}: point {point}, climbable part {part:GetFullName()}, lowest corner {above} above the point; limit {TRUSS_ABOVE}`
					table.insert(problems, problem("climbable", point, detail))
					break
				end
			end
		end
	end
end

-- Whether a jump from one place reaches another, with the numbers the walk-area rule uses: the jump height is
-- Config.Nests.Jump.Up, the speed is the walk speed, and gravity is the world's.
local function jumpFrom(from: Vector3, to: Vector3): boolean
	return WaysUpCheck.jumpReaches(from, to, Config.Nests.Jump.Up, Workspace.Gravity, Config.Movement.WalkSpeed)
end

-- Rule 3, nests: a nest fails when a stand within NEST_CLEAR of it (plain 3D distance from the stand) is reached by a
-- jump from some surface point. Mid-air volumes do not count: a grab needs a 1 s hold, so only a place a body can stand
-- on matters. The stands within NEST_CLEAR of any nest are kept first, then the surface points are tested against those
-- few. One problem per surface and nest (the first point that fails).
local function nestProblems(input: JumpInput, problems: { Problem })
	local close: { { stand: Vector3, nest: Vector3 } } = {}
	for _, stand in input.stands do
		for _, nest in input.nests do
			if (stand - nest).Magnitude < NEST_CLEAR then
				table.insert(close, { stand = stand, nest = nest })
			end
		end
	end
	if #close == 0 then
		return
	end
	for _, nest in input.nests do
		for _, surface in input.surfaces do
			local found = false
			for _, point in surface.points do
				for _, item in close do
					if item.nest == nest and jumpFrom(point, item.stand) then
						local distance = (item.stand - nest).Magnitude
						local detail =
							`{surface.name}: point {point}, stand {item.stand}, nest {nest}, {distance} from the stand a jump reaches; limit {NEST_CLEAR}`
						table.insert(problems, problem("nest", nest, detail))
						found = true
						break
					end
				end
				if found then
					break
				end
			end
		end
	end
end

-- The points some start reaches with a jump, or that sit within START_NEAR of a start. Input order is kept.
function WaysUpCheck.reachedByJump(starts: { Vector3 }, points: { Vector3 }): { Vector3 }
	local kept: { Vector3 } = {}
	for _, point in points do
		for _, start in starts do
			if (point - start).Magnitude <= START_NEAR or jumpFrom(start, point) then
				table.insert(kept, point)
				break
			end
		end
	end
	return kept
end

-- The jump rules on a made-up or real world: walk area, climbable parts and nests.
function WaysUpCheck.jumpProblems(world: WorldRoot, input: JumpInput): { Problem }
	local problems: { Problem } = {}
	walkAreaProblems(world, input, problems)
	climbableProblems(input, problems)
	nestProblems(input, problems)
	return problems
end

return WaysUpCheck
