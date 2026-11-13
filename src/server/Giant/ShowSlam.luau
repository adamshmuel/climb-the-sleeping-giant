--!strict
-- Where a show slam lands near a protected player (Rule 60 point 3, Rule 63): a meadow spot 35 to 45 studs from them
-- that covers nobody, no landing spot and no garden, and keeps off every protected player's way home. Pure maths: it is
-- given spots, players, gates and gardens and returns the answer. The random pick is passed in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Slams = require(script.Parent.Slams)
local Zones = require(script.Parent.Zones)

local ShowSlam = {}

-- Across the ground, from a point to the stretch from `from` to `to` (the stretch only, never the line past its end).
local function distanceToStretch(point: Vector3, from: Vector3, to: Vector3): number
	local dx, dz = to.X - from.X, to.Z - from.Z
	local lengthSquared = dx * dx + dz * dz
	local along = 0
	if lengthSquared > 0 then
		along = math.clamp(((point.X - from.X) * dx + (point.Z - from.Z) * dz) / lengthSquared, 0, 1)
	end
	return math.sqrt((point.X - (from.X + along * dx)) ^ 2 + (point.Z - (from.Z + along * dz)) ^ 2)
end

-- The player the show slam lands near: the one the slam before bonked, else the one nearest to the anchor. A tie goes to
-- the lower user id.
local function chooseTarget(candidates: { Slams.Player }, anchor: Vector3): Slams.Player
	local best = candidates[1]
	local bestDistance = Slams.flatDistance(best.position, anchor)
	for index = 2, #candidates do
		local player = candidates[index]
		local distance = Slams.flatDistance(player.position, anchor)
		local better: boolean
		if (player.bonkedLast == true) ~= (best.bonkedLast == true) then
			better = player.bonkedLast == true
		elseif distance ~= bestDistance then
			better = distance < bestDistance
		else
			better = player.userId < best.userId
		end
		if better then
			best = player
			bestDistance = distance
		end
	end
	return best
end

-- `spots`: the meadow points. `players`: everyone. `protected`: who can't be targeted now. `gates`: the Safe Gate of
-- each protected player's own garden, by user id. `anchor`: his face. `pick(count)` returns 1 to count.
-- `circleDiameter` is the red circle's width (default: `Config.Wake.SlamCircleDiameter`).
-- A spot suits when it is `ShowSlamNearStuds` to `ShowSlamFarStuds` from the chosen player, clear of the gardens,
-- covers no player or landing spot, and is half the circle's width plus the garden margin away from each protected
-- player's way to their gate. A random suiting spot; if none, the nearest suiting spot out to `ShowSlamMaxStuds`.
-- Returns nil when every protected player is in a garden or no spot suits (the caller then uses `Slams.pickEmpty`).
function ShowSlam.pickShow(
	spots: { Vector3 },
	players: { Slams.Player },
	protected: { Slams.Player },
	gates: { [number]: Vector3 },
	gardens: { Zones.GardenBox },
	landingSpots: { Vector3 },
	anchor: Vector3,
	pick: (count: number) -> number,
	circleDiameter: number?
): Vector3?
	local outside = {}
	for _, player in protected do
		if not player.inGarden then
			table.insert(outside, player)
		end
	end
	if #outside == 0 then
		return nil
	end
	local target = chooseTarget(outside, anchor)

	local radius = (circleDiameter or Config.Wake.SlamCircleDiameter) / 2
	local wayHomeMargin = radius + Config.Wake.SlamGardenMarginStuds

	-- Everything but the distance from the target: gardens, who it covers, and the ways home.
	local function fits(spot: Vector3): boolean
		if Slams.clearOfGardens(spot, gardens, anchor) ~= spot then
			return false
		end
		for _, player in players do
			if Slams.flatDistance(spot, player.position) < radius then
				return false
			end
		end
		for _, landing in landingSpots do
			if Slams.flatDistance(spot, landing) < radius then
				return false
			end
		end
		for _, player in outside do
			local gate: Vector3? = gates[player.userId]
			if gate ~= nil and distanceToStretch(spot, player.position, gate) < wayHomeMargin then
				return false
			end
		end
		return true
	end

	local ring = {}
	local nearest: Vector3? = nil
	local nearestDistance = math.huge
	for _, spot in spots do
		local distance = Slams.flatDistance(spot, target.position)
		if distance < Config.Wake.ShowSlamNearStuds or distance > Config.Wake.ShowSlamMaxStuds or not fits(spot) then
			continue
		end
		if distance <= Config.Wake.ShowSlamFarStuds then
			table.insert(ring, spot)
		end
		if distance < nearestDistance then
			nearest = spot
			nearestDistance = distance
		end
	end
	if #ring > 0 then
		return ring[pick(#ring)]
	end
	return nearest
end

return ShowSlam
