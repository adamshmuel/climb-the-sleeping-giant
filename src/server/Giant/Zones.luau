--!strict
-- Which zone of the giant (and which garden) a position is in. Pure maths: it is given boxes and
-- positions, and touches no players, parts or clocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type ZoneBox = { zone: Config.ZoneName, cframe: CFrame, size: Vector3 } -- zone is never "Meadow"
export type GardenBox = { index: number, cframe: CFrame, size: Vector3 }
export type Place = { zone: Config.ZoneName, garden: number? }

-- Higher number = higher on the giant. Where boxes overlap, the highest zone wins.
local RANK: { [Config.ZoneName]: number } = { Meadow = 0, Boots = 1, Belly = 2, Beard = 3, Nightcap = 4 }

local Zones = {}

-- The higher of two zones: Meadow is lowest, then Boots, Belly, Beard and Nightcap.
function Zones.higher(a: Config.ZoneName, b: Config.ZoneName): Config.ZoneName
	return if RANK[b] > RANK[a] then b else a
end

-- Is the point inside a box that may be turned? The point is moved into the box's own space, where the
-- box lines up with the axes, and compared with half its size. A point on a face counts as inside.
function Zones.isInside(position: Vector3, cframe: CFrame, size: Vector3): boolean
	local local_ = cframe:PointToObjectSpace(position)
	local half = size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

-- The zone a position is in: the highest zone among the boxes that hold it, or the Meadow.
function Zones.zoneAt(position: Vector3, zoneBoxes: { ZoneBox }): Config.ZoneName
	local best: Config.ZoneName = "Meadow"
	for _, box in zoneBoxes do
		if Zones.isInside(position, box.cframe, box.size) and RANK[box.zone] > RANK[best] then
			best = box.zone
		end
	end
	return best
end

-- The garden a position is in, or nil.
function Zones.gardenAt(position: Vector3, gardens: { GardenBox }): number?
	for _, garden in gardens do
		if Zones.isInside(position, garden.cframe, garden.size) then
			return garden.index
		end
	end
	return nil
end

-- Where a position is: in a garden (a garden always wins over a zone box, and counts as Meadow),
-- or else in a zone with no garden.
function Zones.locate(position: Vector3, zoneBoxes: { ZoneBox }, gardens: { GardenBox }): Place
	local garden = Zones.gardenAt(position, gardens)
	if garden then
		return { zone = "Meadow", garden = garden }
	end
	return { zone = Zones.zoneAt(position, zoneBoxes), garden = nil }
end

return Zones
