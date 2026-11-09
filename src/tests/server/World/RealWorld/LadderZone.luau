--!strict
-- The plan's rule "Which zone a climber is in": the higher of the zone boxes' zone and the zone of any ladder box
-- (World.LadderBoxes) that holds the point. A missing LadderBoxes folder means no ladder boxes. It ranks nothing itself:
-- Zones does. It lasts until plan 3 Task 3 builds Zones.ladderAt; that task points the tests at it and deletes this file.
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)

local function climberZone(world: Instance, point: Vector3): string
	local boxes = WorldIndex.readZones(world) :: { Zones.ZoneBox }
	local zone = Zones.zoneAt(point, boxes)
	local folder = world:FindFirstChild("LadderBoxes")
	if folder ~= nil then
		for _, box in folder:GetChildren() do
			if box:IsA("BasePart") and Zones.isInside(point, box.CFrame, box.Size) then
				zone = Zones.higher(zone, box:GetAttribute("Zone") :: any)
			end
		end
	end
	return zone
end

return { climberZone = climberZone }
