--!strict
-- Text for numbers the player reads. Pure: it only turns a number into words.

local Format = {}

-- Seconds as minutes and seconds, for example 15 -> "0:15", 75 -> "1:15". Never below "0:00".
-- A part of a second is dropped: round up before calling if the countdown should show the time still to wait.
function Format.countdown(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Format
