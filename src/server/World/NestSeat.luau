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

local NestSeat = {}

function NestSeat.measure(world: WorldRoot, seat: Seat): Result
	local result: Result = { ok = false, surface = "", pose = seat.pose, gap = 0, sink = 0, reasons = {} }
	local hit = visibleHit(world, seat)
	if hit == nil then
		table.insert(result.reasons, "no surface")
		return result
	end
	result.surface = hit.Instance.Name
	local offset = seat.bottom.Y - hit.Position.Y
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

return NestSeat
