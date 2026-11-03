--!strict
-- The rules of a drop from the cap, a cap tie or a tie's landing (Task 61d; spec 5, Rule 8: Steps make noise). Pure:
-- the detector says how a fall ended, and these two functions say whether the landing puffs and what the "CapDrop"
-- analytics event records.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LandingDetector = require(script.Parent.LandingDetector)

export type EndedOn = "pillow" | "face" | "shoulders" | "belly"

export type Fields = { how: string, woke: string, egg: string, endedOn: string }

-- The fields of one "CapToCapFall" event (Task 61n): the drop height bucket, the egg carried and the trip number.
export type FallFields = { height: string, egg: string, trip: string }

-- The drop height buckets in studs: the first edge is the 4 studs of the section 5 playtest trigger.
local HEIGHT_EDGES = { 4, 10, 20 }
local HEIGHT_NAMES = { "under 4", "4 to 10", "10 to 20", "20 and over" }
local MAX_NAMED_TRIP = 9

local CapDrop = {}

-- Does the landing puff, and where did the drop end? A walk-off ending on the pillow, his shoulders or his belly puffs
-- (the shoulders are the Belly zone's open tops, z at or above Config.Noise.ShoulderMinZ). One ending on his head or
-- face is quiet with no puff. A jump never puffs, because it thuds. Nothing else is a CapDrop: no ending (nil).
function CapDrop.landing(drop: LandingDetector.Drop, onPillow: boolean, position: Vector3): (boolean, EndedOn?)
	if drop.to == "Beard" then
		return false, "face"
	end
	if drop.to ~= "Belly" then
		return false, nil
	end
	local endedOn: EndedOn = if onPillow
		then "pillow"
		elseif position.Z >= Config.Noise.ShoulderMinZ then "shoulders"
		else "belly"
	return not drop.jumped, endedOn
end

-- The fields of one "CapDrop" event: how they dropped, whether it woke him, whether they carried an egg, where it ended.
function CapDrop.fields(jumped: boolean, woke: boolean, carrying: boolean, endedOn: string): Fields
	return {
		how = if jumped then "jumped" else "walked off",
		woke = if woke then "yes" else "no",
		egg = if carrying then "yes" else "no",
		endedOn = endedOn,
	}
end

-- Is this drop a cap-to-cap fall? A fall with no jump that started on his cap, a cap tie or a tie's landing (the
-- detector only reports those, Task 61h) and ended on his cap. It is never logged as a "CapDrop".
function CapDrop.isCapToCap(drop: LandingDetector.Drop): boolean
	return drop.to == "Nightcap" and not drop.jumped
end

-- The fields of one "CapToCapFall" event: the height bucket, the egg carried (none, or its rank) and the trip number.
function CapDrop.capFallFields(height: number, carrying: string?, trip: number): FallFields
	local bucket = #HEIGHT_NAMES
	for index, edge in HEIGHT_EDGES do
		if height < edge then
			bucket = index
			break
		end
	end
	return {
		height = HEIGHT_NAMES[bucket],
		egg = carrying or "none",
		trip = if trip > MAX_NAMED_TRIP then `trip {MAX_NAMED_TRIP + 1} and over` else `trip {trip}`,
	}
end

return CapDrop
