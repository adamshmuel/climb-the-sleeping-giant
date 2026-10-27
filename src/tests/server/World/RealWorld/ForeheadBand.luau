--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

-- The band where players walk along the giant's forehead, as boxes (code_lead's measure, work/t33/measure.md line 9):
-- x 5 to 12, z -5 to 7, and a player's feet from y 102 (the band's lowest feet) up to a body's height above that, so a
-- fill that reaches into the space a walking body fills is caught too.
-- Task 28 step 5 records the real band frames and replaces this one box with them.
export type Box = { min: Vector3, max: Vector3 }

local BAND_LOWEST_FEET = 102 -- studs (y)

local BOXES: { Box } = {
	{
		min = Vector3.new(5, BAND_LOWEST_FEET, -5),
		max = Vector3.new(12, BAND_LOWEST_FEET + Config.Stuck.BodyHeight, 7),
	},
}

return {
	BOXES = BOXES,
}
