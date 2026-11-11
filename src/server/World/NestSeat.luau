--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

-- What an egg or a nest sits on (spec 4 Rule 59 and section 5 rows "Visible surface", "Float limit", "Sink limit").
-- Measured on demand by world checks, never per frame. A seat is a bare egg or a nest; a nest with its egg also checks how far the egg sits from the nest bottom.
export type Seat = {
	kind: "nest" | "egg",
	bottom: Vector3, -- a bare egg's lowest point, or the nest's bottom centre
	pose: "upright" | "leaning",
	eggBottom: Vector3?, -- a nest's egg's lowest point
	ignore: { Instance }?,
	-- Look parts rays skip (CanQuery false): one that is visible and under the bottom counts as a surface too.
	lookParts: { BasePart }?,
}

export type Result = {
	ok: boolean,
	surface: string, -- the visible surface's Name ("" when there is none)
	pose: string,
	gap: number, -- studs the bottom sits above the surface top
	sink: number, -- studs the bottom sits below the surface top
	eggOffset: number?,
	reasons: { string },
}

local RAY_UP = 3 -- studs above the bottom where the ray starts
local RAY_LENGTH = 203 -- studs the ray reaches down from there
local SLACK = 1e-6 -- so a sink of exactly the limit passes despite float error
local MAX_SKIPS = 60 -- see-through parts one ray may skip before it gives up

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function sinkLimit(seat: Seat): number
	local ranks = Config.Ranks
	if seat.kind == "nest" then
		return if seat.pose == "upright" then ranks.SinkNestUpright else ranks.SinkNestLeaning
	end
	return if seat.pose == "upright" then ranks.SinkEggUpright else ranks.SinkEggLeaning
end

-- The first part below the seat that is less see-through than VisibleBelow: the ray is cast again past each
-- see-through part (a growing exclude list).
local function visibleHit(world: WorldRoot, seat: Seat): RaycastResult?
	local exclude: { Instance } = {}
	if seat.ignore ~= nil then
		for _, instance in seat.ignore do
			table.insert(exclude, instance)
		end
	end
	local origin = seat.bottom + Vector3.new(0, RAY_UP, 0)
	local direction = Vector3.new(0, -RAY_LENGTH, 0)
	for _ = 1, MAX_SKIPS do
		params.FilterDescendantsInstances = exclude
		local hit = world:Raycast(origin, direction, params)
		if hit == nil then
			return nil
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or part.Transparency < Config.Ranks.VisibleBelow then
			return hit
		end
		table.insert(exclude, part)
	end
	return nil
end

-- The world height of the top of `part`'s box along the vertical line through `point`, or nil when the line misses the
-- box (the box may be turned: the line is cut by the box's three pairs of faces in its own space).
local function boxTopAt(part: BasePart, point: Vector3): number?
	local origin = part.CFrame:PointToObjectSpace(point)
	local direction = part.CFrame:VectorToObjectSpace(Vector3.yAxis)
	local half = part.Size / 2
	local low, high = -math.huge, math.huge
	for _, axis in { "X", "Y", "Z" } do
		local o, d, h = (origin :: any)[axis], (direction :: any)[axis], (half :: any)[axis]
		if math.abs(d) < 1e-9 then
			if math.abs(o) > h then
				return nil
			end
		else
			local near, far = (-h - o) / d, (h - o) / d
			low = math.max(low, math.min(near, far))
			high = math.min(high, math.max(near, far))
		end
	end
	if low > high then
		return nil
	end
	return point.Y + high
end

-- The highest visible look part of the seat under its bottom (its top no more than RAY_UP above the bottom, where the
-- ray starts), and that top's height. A part inside the seat's `ignore` list (the egg's own model) doesn't count.
local function lookPartTop(seat: Seat): (BasePart?, number)
	local best: BasePart? = nil
	local bestTop = -math.huge
	local parts: { BasePart } = seat.lookParts or {}
	local ignored: { Instance } = seat.ignore or {}
	for _, part in parts do
		local skipped = false
		for _, instance in ignored do
			if part:IsDescendantOf(instance) then
				skipped = true
				break
			end
		end
		if not skipped and part.Transparency < Config.Ranks.VisibleBelow then
			local top = boxTopAt(part, seat.bottom)
			if top ~= nil and top <= seat.bottom.Y + RAY_UP and top > bestTop then
				best, bestTop = part, top
			end
		end
	end
	return best, bestTop
end

local NestSeat = {}

function NestSeat.measure(world: WorldRoot, seat: Seat): Result
	local result: Result = { ok = false, surface = "", pose = seat.pose, gap = 0, sink = 0, reasons = {} }
	local hit = visibleHit(world, seat)
	local look, lookTop = lookPartTop(seat)
	local surfaceY = if hit ~= nil then hit.Position.Y else -math.huge
	local surface = if hit ~= nil then hit.Instance.Name else ""
	if look ~= nil and lookTop > surfaceY then
		surfaceY, surface = lookTop, look.Name
	end
	if surface == "" then
		table.insert(result.reasons, "no surface")
		return result
	end
	result.surface = surface
	local offset = seat.bottom.Y - surfaceY
	result.gap = math.max(offset, 0)
	result.sink = math.max(-offset, 0)
	if result.gap > Config.Ranks.FloatLimit + SLACK then
		table.insert(result.reasons, string.format("gap %.1f", result.gap))
	end
	if result.sink > sinkLimit(seat) + SLACK then
		table.insert(result.reasons, string.format("sink %.1f", result.sink))
	end
	if seat.kind == "nest" and seat.eggBottom ~= nil then
		local eggOffset = math.abs(seat.eggBottom.Y - seat.bottom.Y)
		result.eggOffset = eggOffset
		if eggOffset > Config.Ranks.EggInNest + SLACK then
			table.insert(result.reasons, string.format("egg %.2f from nest bottom", eggOffset))
		end
	end
	result.ok = #result.reasons == 0
	return result
end

-- The angle in degrees between a part's up direction and straight up.
local function tiltDegrees(part: BasePart): number
	return math.deg(math.acos(math.clamp(part.CFrame.UpVector.Y, -1, 1)))
end

-- The seat of a nest (its bottom centre, along its own up direction) with its egg's lowest point, or, with no nest, a
-- bare egg's seat at `eggBottom` with its pose taken from `base` (the part it rests on). Leaning when the part is tilted
-- over Config.Ranks.LeaningFromDegrees (Rule 59).
function NestSeat.seatOf(
	nest: BasePart?,
	base: BasePart,
	eggBottom: Vector3,
	ignore: { Instance },
	lookParts: { BasePart }?
): Seat
	if nest == nil then
		return {
			kind = "egg",
			bottom = eggBottom,
			pose = if tiltDegrees(base) > Config.Ranks.LeaningFromDegrees then "leaning" else "upright",
			ignore = ignore,
			lookParts = lookParts,
		}
	end
	return {
		kind = "nest",
		bottom = nest.Position - nest.CFrame.UpVector * (nest.Size.Y / 2),
		pose = if tiltDegrees(nest) > Config.Ranks.LeaningFromDegrees then "leaning" else "upright",
		eggBottom = eggBottom,
		ignore = ignore,
		lookParts = lookParts,
	}
end

return NestSeat
