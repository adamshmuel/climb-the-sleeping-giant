--!strict
-- Stuck safety Task 54: the two hidden brim blocks' sizes and places, so section 4b and the tests read the same numbers.
-- Copied from work/t54/measure.md, "The place to build" (the exact values the measure scored, moved -0.5 along Up).

local BrimPlaces = {}

export type Block = { name: string, side: number, size: Vector3, cframe: CFrame }

BrimPlaces.POSITION_TOLERANCE = 0.01 -- studs: Roblox may tidy the axes by under 0.001

local BRIM_FILL_PLUS_X_SIZE = Vector3.new(8, 6.5, 12)
local BRIM_FILL_PLUS_X_CFRAME = CFrame.fromMatrix(
	Vector3.new(10.75, 113.56, 15.53),
	Vector3.new(0.938, -0.229, 0.261),
	Vector3.new(0.300, 0.913, -0.276)
) * CFrame.new(0, -0.5, 0)

local BRIM_FILL_MINUS_X_SIZE = Vector3.new(8, 6.7, 12)
local BRIM_FILL_MINUS_X_CFRAME = CFrame.fromMatrix(
	Vector3.new(-10.66, 113.74, 15.62),
	Vector3.new(0.932, 0.242, -0.272),
	Vector3.new(-0.319, 0.901, -0.295)
) * CFrame.new(0, -0.5, 0)

BrimPlaces.BLOCKS = {
	{ name = "BrimFill_PlusX", side = 1, size = BRIM_FILL_PLUS_X_SIZE, cframe = BRIM_FILL_PLUS_X_CFRAME },
	{ name = "BrimFill_MinusX", side = -1, size = BRIM_FILL_MINUS_X_SIZE, cframe = BRIM_FILL_MINUS_X_CFRAME },
} :: { Block }

return BrimPlaces
