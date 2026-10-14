--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BarPaint = require(StarterPlayer.StarterPlayerScripts.Client.Hud.BarPaint)

local GREEN = Color3.fromRGB(0, 200, 0)
local YELLOW = Color3.fromRGB(250, 250, 0)
local ORANGE = Color3.fromRGB(250, 100, 0)

-- Green at the start, yellow 60% along, orange at the end.
local function threeColors(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, GREEN),
		ColorSequenceKeypoint.new(0.6, YELLOW),
		ColorSequenceKeypoint.new(1, ORANGE),
	})
end

-- The colour a sequence has at position `t` (0 to 1), found by hand so the tests don't rely on Roblox's own maths.
local function colorAt(sequence: ColorSequence, t: number): Color3
	local points = sequence.Keypoints
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		if t >= from.Time and t <= to.Time then
			local span = to.Time - from.Time
			return from.Value:Lerp(to.Value, if span == 0 then 0 else (t - from.Time) / span)
		end
	end
	return points[#points].Value
end

local function closeTo(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.002 and math.abs(a.G - b.G) < 0.002 and math.abs(a.B - b.B) < 0.002
end

describe("BarPaint.reveal", function()
	it("keeps the whole sequence when the bar is full", function()
		local result = BarPaint.reveal(threeColors(), 1)
		expect(#result.Keypoints).toBe(3)
		expect(closeTo(colorAt(result, 0.6), YELLOW)).toBe(true)
		expect(closeTo(colorAt(result, 1), ORANGE)).toBe(true)
	end)

	it("starts with the first colour", function()
		expect(closeTo(colorAt(BarPaint.reveal(threeColors(), 0.4), 0), GREEN)).toBe(true)
	end)

	it("ends with the colour the full bar has at that point", function()
		-- 30% along the full bar is halfway from green (0) to yellow (0.6).
		local result = BarPaint.reveal(threeColors(), 0.3)
		expect(closeTo(colorAt(result, 1), GREEN:Lerp(YELLOW, 0.5))).toBe(true)
	end)

	it("drops colour stops the fill does not reach", function()
		local result = BarPaint.reveal(threeColors(), 0.3)
		expect(#result.Keypoints).toBe(2)
	end)

	it("squeezes the stops it keeps so they sit at the same places on the bar", function()
		-- Yellow is 60% along the full bar, so at a fill of 0.8 it is 75% along the visible part.
		local result = BarPaint.reveal(threeColors(), 0.8)
		expect(closeTo(colorAt(result, 0.75), YELLOW)).toBe(true)
		expect(closeTo(colorAt(result, 1), YELLOW:Lerp(ORANGE, 0.5))).toBe(true)
	end)

	it("still gives a sequence for an empty bar", function()
		local result = BarPaint.reveal(threeColors(), 0)
		expect(closeTo(colorAt(result, 0), GREEN)).toBe(true)
	end)
end)
