--!strict
-- The 85% warning's bubble "Mmm... my eggs..." beside his nose (V2 spec 1, Rule 17: A free save replays the 85% warning,
-- section 5 "The 85% bubble's size and spot"). This module is pure maths: no services, no instances, no clock. GiantFx
-- does the placing. The values are designer's, tested in Studio from all 8 gardens (style guide, "The 85% warning:
-- tested values (2026-10-19)", "The bubble").
--   * size: fixed on the screen, in pixels, on one line (phone 120 x 40 with words at font size 14, computer 170 x 52
--     with words at font size 20).
--   * side: beside his nose, on the side away from his head. Which side that is depends on where the camera looks from,
--     so it comes from the camera's RightVector.Z. The offset is measured from the camera (StudsOffset, on purpose: like
--     the floating Z Z Z, and unlike StudsOffsetWorldSpace, which the rest of the project uses).
--   * pop: grows from nothing to 110% and settles at 100% over 0.2 s, stays until 3 s, then fades out over 0.3 s. With
--     Reduce Motion on it just appears and goes.

local Bubble85 = {}

Bubble85.phoneSize = UDim2.fromOffset(120, 40)
Bubble85.phoneTextSize = 14
Bubble85.computerSize = UDim2.fromOffset(170, 52)
Bubble85.computerTextSize = 20

-- The bubble's spot from the camera, in studs: 14 to the side, 3 down, 2 toward the camera. The sign of the side flips.
local SIDE_STUDS = 14
local DOWN_STUDS = -3
local TOWARD_CAMERA_STUDS = 2

Bubble85.popSeconds = 0.2 -- from nothing to settled at 100%
Bubble85.popPeak = 1.1 -- the biggest it gets, halfway through the pop
Bubble85.readSeconds = 3 -- how long it stays at full size and fully solid
Bubble85.fadeSeconds = 0.3 -- the way out after that
-- The tail's centre across the bubble when it sits at the left (0.07) or the right (0.93) corner, and down it (0.93).
local TAIL_NEAR_EDGE = 0.07
local TAIL_FAR_EDGE = 0.93
local TAIL_DOWN = 0.93
-- Decimal sums like 3.3 - 3 come out a hair off; anything closer than this to a target counts as on it.
local ROUNDING = 1e-6

export type Look = {
	size: UDim2, -- the size on the screen, in pixels
	textSize: number, -- the words' font size
}

export type Side = {
	studsOffset: Vector3,
	sizeOffset: Vector2, -- which corner of the bubble sits on the spot (the one nearest his nose)
	tailRight: boolean, -- true: the tail sits at the bottom-right corner, false: at the bottom-left
}

-- Smooth start and finish: 0 to 1 over `t` from 0 to 1.
local function smooth(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- The size and the font size for a phone or a computer screen.
function Bubble85.size(isPhone: boolean): Look
	if isPhone then
		return { size = Bubble85.phoneSize, textSize = Bubble85.phoneTextSize }
	end
	return { size = Bubble85.computerSize, textSize = Bubble85.computerTextSize }
end

-- The side of his nose the bubble goes on, from the camera's RightVector.Z. Above 0 the camera's right side points
-- toward his head, so the bubble goes to the left and grows left. At 0 or below it goes to the right and grows right.
function Bubble85.side(rightVectorZ: number): Side
	if rightVectorZ > 0 then
		return {
			studsOffset = Vector3.new(-SIDE_STUDS, DOWN_STUDS, TOWARD_CAMERA_STUDS),
			sizeOffset = Vector2.new(-0.5, 0.5),
			tailRight = true,
		}
	end
	return {
		studsOffset = Vector3.new(SIDE_STUDS, DOWN_STUDS, TOWARD_CAMERA_STUDS),
		sizeOffset = Vector2.new(0.5, 0.5),
		tailRight = false,
	}
end

-- Where the tail's centre sits inside the bubble: at the bottom corner nearest his nose.
function Bubble85.tailPosition(tailRight: boolean): UDim2
	return UDim2.fromScale(if tailRight then TAIL_FAR_EDGE else TAIL_NEAR_EDGE, TAIL_DOWN)
end

-- How big the bubble is, as a share of its full size, `seconds` after it popped in: 0 at the start, 1.1 halfway (0.1 s),
-- exactly 1 from 0.2 s on. Both halves ease smoothly. With Reduce Motion on it is 1 from the start.
function Bubble85.popScale(seconds: number, reducedMotion: boolean): number
	if reducedMotion then
		return 1
	end
	local half = Bubble85.popSeconds / 2
	if seconds >= Bubble85.popSeconds then
		return 1
	end
	if seconds <= 0 then
		return 0
	end
	if seconds < half then
		return Bubble85.popPeak * smooth(seconds / half)
	end
	return Bubble85.popPeak + (1 - Bubble85.popPeak) * smooth((seconds - half) / half)
end

-- How see-through the bubble is, `seconds` after it popped in: 0 (solid) until 3 s, then evenly to 1 (gone) at 3.3 s.
-- With Reduce Motion on it never fades.
function Bubble85.fade(seconds: number, reducedMotion: boolean): number
	if reducedMotion then
		return 0
	end
	local share = (seconds - Bubble85.readSeconds) / Bubble85.fadeSeconds
	if share >= 1 - ROUNDING then
		return 1 -- exactly 1, not a hair under it from the rounding of 3.3 - 3
	end
	return math.clamp(share, 0, 1)
end

-- How long the bubble shows in all, from when it pops in until it goes: 3.3 s, or 3 s with Reduce Motion on.
function Bubble85.showSeconds(reducedMotion: boolean): number
	if reducedMotion then
		return Bubble85.readSeconds
	end
	return Bubble85.readSeconds + Bubble85.fadeSeconds
end

return Bubble85
