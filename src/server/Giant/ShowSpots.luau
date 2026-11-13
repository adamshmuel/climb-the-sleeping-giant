--!strict
-- The meadow spots a show slam may land on (Rule 60 point 3): a grid of dry, open, flat grass points away from the
-- gardens, built once at start. Each spot is a point on the ground. `ShowSlam.pickShow` picks among them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SlamSurface = require(script.Parent.SlamSurface)
local Zones = require(script.Parent.Zones)

-- Studs between neighbouring spots (plan 6, "The meadow spots a show slam can use").
local STEP = 4
-- The ray down starts this high and looks this far, so it finds the ground and everything standing on it.
local RAY_START_Y = 200
local RAY_REACH = 300
-- A spot is flat enough when the standable surface below it is this close to where the first ray hit.
local SAME_HEIGHT = 0.1
-- The world folders whose parts are never ground for a slam: trees and plants (lily pads too), the giant and his
-- props, the gardens, and the steep and cuff layers. Each is a child of the folder named "World".
local NOT_GROUND: { [string]: boolean } = {
	Nature = true,
	Giant = true,
	GiantsThings = true,
	Plots = true,
	SteepLayer = true,
	CuffWalk = true,
}

local ShowSpots = {}

-- Is this part inside one of the World folders in NOT_GROUND?
local function inNotGround(instance: Instance): boolean
	local current: Instance? = instance
	while current ~= nil do
		local parent = current.Parent
		if parent ~= nil and parent.Name == "World" and NOT_GROUND[current.Name] then
			return true
		end
		current = parent
	end
	return false
end

-- The flat rectangle around every garden box, grown on each side by `grow` studs: minX, maxX, minZ, maxZ.
local function bounds(gardens: { Zones.GardenBox }, grow: number): (number, number, number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, garden in gardens do
		local half = garden.size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = garden.cframe * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
					minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
				end
			end
		end
	end
	return minX - grow, maxX + grow, minZ - grow, maxZ + grow
end

-- Every spot of the grid that is outside the gardens, in the Meadow zone, on ground (not water, a tree, the giant, his
-- props or a garden) and on a surface a player can stand on. `gardens` are the garden boxes, `zoneBoxes` the zone
-- boxes, `ignore` what a slam's ray skips (characters, ladders). A spot is the point on the ground.
function ShowSpots.build(
	worldRoot: WorldRoot,
	gardens: { Zones.GardenBox },
	zoneBoxes: { Zones.ZoneBox },
	ignore: { Instance }
): { Vector3 }
	local spots: { Vector3 } = {}
	if #gardens == 0 then
		return spots
	end
	local minX, maxX, minZ, maxZ = bounds(gardens, Config.Wake.ShowSlamMaxStuds)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local reach = Vector3.new(0, -RAY_REACH, 0)

	local x = minX
	while x <= maxX do
		local z = minZ
		while z <= maxZ do
			local hit = worldRoot:Raycast(Vector3.new(x, RAY_START_Y, z), reach, params)
			if hit ~= nil and hit.Material ~= Enum.Material.Water and not inNotGround(hit.Instance) then
				local spot = Vector3.new(x, hit.Position.Y, z)
				if
					Zones.gardenAt(spot, gardens) == nil
					and Zones.zoneAt(spot, zoneBoxes) == "Meadow"
					and math.abs(SlamSurface.below(worldRoot, spot, ignore).Y - spot.Y) <= SAME_HEIGHT
				then
					table.insert(spots, spot)
				end
			end
			z += STEP
		end
		x += STEP
	end
	return spots
end

return ShowSpots
