--!strict
-- Colour maths for the sleep meter's bar. Pure: it only builds colour sequences from the ones it is given.

local BarPaint = {}

-- The colour a sequence has at position `t` (0 to 1).
local function colorAt(sequence: ColorSequence, t: number): Color3
	local points = sequence.Keypoints
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		if t <= to.Time then
			local span = to.Time - from.Time
			return from.Value:Lerp(to.Value, if span <= 0 then 0 else math.max(0, (t - from.Time) / span))
		end
	end
	return points[#points].Value
end

-- The colours of a bar that is only `fill` full (0 to 1), when `sequence` is drawn over the whole bar: green stays at
-- the start and yellow only shows once the bar nears the yellow stop. It returns the start of `sequence`, squeezed
-- to fit the shorter bar, so the colours sit at the same places on the full bar as in the mockup.
function BarPaint.reveal(sequence: ColorSequence, fill: number): ColorSequence
	if fill >= 1 then
		return sequence
	end
	local shown = math.max(fill, 0.01)
	local keypoints: { ColorSequenceKeypoint } = {}
	for _, point in sequence.Keypoints do
		if point.Time < shown then
			table.insert(keypoints, ColorSequenceKeypoint.new(point.Time / shown, point.Value))
		end
	end
	table.insert(keypoints, ColorSequenceKeypoint.new(1, colorAt(sequence, shown)))
	return ColorSequence.new(keypoints)
end

return BarPaint
