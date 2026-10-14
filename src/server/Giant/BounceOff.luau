--!strict
-- Gives each bounced player a landing spot (Rule 12). Pure maths: it is given players and spots and returns the pairs.

local ServerScriptService = game:GetService("ServerScriptService")

local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

export type Bounced = { id: any, position: Vector3 }

local BounceOff = {}

-- The distance across the ground only: players on his belly are high up and float straight down.
local function flatDistance(a: Vector3, b: Vector3): number
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end

-- "Nearest free one first": repeatedly take the closest (player, free spot) pair, give that player that spot and mark
-- the spot taken. Ties go to the earlier player in the list, then to the lower spot index. When every spot is taken and
-- players are left, all spots are free again, so players share spots.
function BounceOff.assign(players: { Bounced }, spots: { WorldIndex.LandingSpot }): { [any]: WorldIndex.LandingSpot }
	local result: { [any]: WorldIndex.LandingSpot } = {}
	if #players == 0 then
		return result
	end
	if #spots == 0 then
		error("BounceOff.assign needs at least one spot, but LandingSpots is empty", 0)
	end

	local waiting: { number } = {} -- positions in `players` that have no spot yet, in list order
	for position = 1, #players do
		table.insert(waiting, position)
	end
	local taken: { [WorldIndex.LandingSpot]: boolean } = {}
	local takenCount = 0

	while #waiting > 0 do
		if takenCount == #spots then
			taken = {}
			takenCount = 0
		end
		local bestWaiting = 0
		local bestSpot: WorldIndex.LandingSpot? = nil
		local bestDistance = math.huge
		for waitingPosition, playerPosition in waiting do
			for _, spot in spots do
				if not taken[spot] then
					local distance = flatDistance(players[playerPosition].position, spot.position)
					local better = distance < bestDistance
					-- Equal distance: the earlier player wins (the loop meets them first), then the lower spot index.
					if
						not better
						and distance == bestDistance
						and bestSpot ~= nil
						and waitingPosition == bestWaiting
					then
						better = spot.index < bestSpot.index
					end
					if better then
						bestDistance = distance
						bestWaiting = waitingPosition
						bestSpot = spot
					end
				end
			end
		end
		local chosen = bestSpot :: WorldIndex.LandingSpot
		result[players[waiting[bestWaiting]].id] = chosen
		taken[chosen] = true
		takenCount += 1
		table.remove(waiting, bestWaiting)
	end
	return result
end

return BounceOff
