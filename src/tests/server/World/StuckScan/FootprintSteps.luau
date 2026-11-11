--!strict
-- The footprint route of a way up as the heist replay's steps (spec 3, Rule 41: the footprint route's peak must lie in
-- the window too). The zones follow how the game zones a player: a walker's root, 3 studs over its feet, is looked up
-- in the zone boxes; a climber takes the zone of the ladder's box (a climber rides about 3 studs off the truss, so a
-- lookup at the stretch would miss it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require(ReplicatedStorage.Shared.Config)
local HeistScore = require(ServerScriptService.Server.World.HeistScore)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)

local PIECE_STUDS = 1 -- a walk stretch is cut into pieces of at most this length, each zoned at its middle
local SAME_POINT = 0.05 -- studs: a path position this near a route point is that point

local FootprintSteps = {}

FootprintSteps.ROOT_ABOVE_FEET = Vector3.new(0, 3, 0) -- studs: the game zones the root, this far over the feet

-- The ladder name on the route point a path position is (nil when it is no point, or its point is on no ladder).
local function ladderAt(position: Vector3, points: { WorldIndex.RoutePoint }): string?
	for _, point in points do
		if (point.position - position).Magnitude <= SAME_POINT and point.ladder ~= nil then
			return point.ladder
		end
	end
	return nil
end

-- The zone of the ladder box named `ladder`; an error that names the stretch when there is none.
local function ladderZone(ladder: string, ladders: { Zones.LadderBox }): Config.ZoneName
	for _, box in ladders do
		if box.ladder == ladder then
			return box.zone
		end
	end
	error(`FootprintSteps: no ladder box is named {ladder}`)
end

-- The route `found` (a RouteGraph way) as steps, from the join spot to the target.
function FootprintSteps.up(
	found: RouteGraph.Found,
	points: { WorldIndex.RoutePoint },
	ladders: { Zones.LadderBox },
	zoneBoxes: { Zones.ZoneBox }
): { HeistScore.Step }
	local steps: { HeistScore.Step } = {}
	for index = 1, #found.path - 1 do
		local from, to = found.path[index], found.path[index + 1]
		local length = (to - from).Magnitude
		if found.climbs[index] then
			local ladder = ladderAt(from, points) or ladderAt(to, points)
			if ladder == nil then
				error(`FootprintSteps: a climb stretch {index} has no route point with a ladder at either end`)
			end
			table.insert(steps, { length = length, kind = "Climb", zone = ladderZone(ladder, ladders) })
		elseif length > 0 then
			local pieces = math.ceil(length / PIECE_STUDS)
			for piece = 1, pieces do
				local middle = from:Lerp(to, (piece - 0.5) / pieces)
				table.insert(steps, {
					length = length / pieces,
					kind = "Walk",
					zone = Zones.zoneAt(middle + FootprintSteps.ROOT_ABOVE_FEET, zoneBoxes),
				})
			end
		end
	end
	return steps
end

return FootprintSteps
