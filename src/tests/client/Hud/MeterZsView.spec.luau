--!strict
-- The Z Z Z on the sleep meter (plan 3 Task 8f): where the three letters go and what they look like in each state.
-- The numbers come from docs/design/v2/style-guide/meter-zs.md.
local StarterPlayer = game:GetService("StarterPlayer")
local TextService = game:GetService("TextService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Layout = require(Hud.Layout)
local MeterZsView = require(Hud.MeterZsView)

type Rect = { x: number, y: number, width: number, height: number }

type Case = {
	name: string,
	screenSize: Vector2,
	topInset: number, -- points the safe area starts below the screen top
	heavy: boolean,
}

-- The two real screens: the Phone_844x390 play view (840 x 368 under a 20-point inset) and a 1280 x 720 computer.
local CASES: { Case } = {
	{ name = "phone calm", screenSize = Vector2.new(840, 368), topInset = 20, heavy = false },
	{ name = "phone Heavy Sleep", screenSize = Vector2.new(840, 368), topInset = 20, heavy = true },
	{ name = "computer calm", screenSize = Vector2.new(1280, 720), topInset = 0, heavy = false },
	{ name = "computer Heavy Sleep", screenSize = Vector2.new(1280, 720), topInset = 0, heavy = true },
}

local MIN_LETTER_HEIGHT = 24 -- the 8f bar: every Z at least 24 points tall (meter-zs.md, "Size")
local MIN_TOP_GAP = 4 -- the letters stay at least 4 points below the screen top (meter-zs.md, "Where")

local function overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
end

-- How far below the top of its Hud screen a letter's highest corner rests once the letter is turned by the layout's tilt.
-- The letter is as MeterZs draws it: a textSize square (left aligned, centred up and down) in a group that turns about its
-- own middle, the group being the square plus the padding all round. Positive tilt is clockwise on the screen (Roblox).
local function turnedTop(box: MeterZsView.Box, tilt: number): number
	local size = math.round(box.textSize) -- TextSize is a whole number
	local width = TextService:GetTextSize("Z", size, Enum.Font.FredokaOne, Vector2.new(1000, 1000)).X
	local centerX = box.x + box.textSize / 2
	local centerY = box.y + box.textSize / 2
	local middleY = box.y + box.textSize / 2
	local angle = math.rad(tilt)
	local top = math.huge
	for _, x in { box.x, box.x + width } do
		for _, y in { middleY - box.height / 2, middleY + box.height / 2 } do
			top = math.min(top, centerY + (x - centerX) * math.sin(angle) + (y - centerY) * math.cos(angle))
		end
	end
	return top
end

-- Everything in the safe area's own coordinates, as the Hud screen draws it.
local function setup(case: Case)
	local screen = Layout.forScreen(case.screenSize)
	local centerX = case.screenSize.X / 2
	local meterRight = centerX + screen.meter.width / 2
	local meterRect: Rect = {
		x = centerX - screen.meter.width / 2,
		y = screen.meter.topOffset,
		width = screen.meter.width,
		height = screen.meter.height,
	}
	local diameter = screen.tiptoe.diameter
	local tiptoeRect: Rect = {
		x = case.screenSize.X - screen.tiptoe.rightMargin - diameter,
		y = case.screenSize.Y / 2 - diameter / 2,
		width = diameter,
		height = diameter + screen.tiptoe.shadowOffset,
	}
	local boxes = MeterZsView.boxes(screen, meterRight, case.heavy)
	return screen, meterRight, meterRect, tiptoeRect, boxes
end

describe("MeterZsView.boxes", function()
	it("gives three letters, each one bigger than the one before", function()
		for _, case in CASES do
			local _, _, _, _, boxes = setup(case)
			expect(#boxes).toBe(3)
			expect(boxes[2].height > boxes[1].height).toBe(true)
			expect(boxes[3].height > boxes[2].height).toBe(true)
		end
	end)

	it("makes every letter at least 24 points tall", function()
		for _, case in CASES do
			local _, _, _, _, boxes = setup(case)
			for index, box in boxes do
				expect(`{case.name} Z{index}: {box.height}`).toBe(
					`{case.name} Z{index}: {math.max(box.height, MIN_LETTER_HEIGHT)}`
				)
			end
		end
	end)

	it("sets the text size to the letter height divided by 0.74", function()
		for _, case in CASES do
			local _, _, _, _, boxes = setup(case)
			for _, box in boxes do
				expect(box.textSize).toBeCloseTo(box.height / 0.74, 3)
			end
		end
	end)

	it("keeps every letter clear of the meter, the words and the face on it", function()
		for _, case in CASES do
			local _, _, meterRect, _, boxes = setup(case)
			for index, box in boxes do
				local rect: Rect = { x = box.x, y = box.y, width = box.textSize, height = box.textSize }
				expect(`{case.name} Z{index} overlaps the meter: {overlaps(rect, meterRect)}`).toBe(
					`{case.name} Z{index} overlaps the meter: false`
				)
			end
		end
	end)

	it("keeps every letter clear of the Tiptoe button", function()
		for _, case in CASES do
			local _, _, _, tiptoeRect, boxes = setup(case)
			for index, box in boxes do
				local rect: Rect = { x = box.x, y = box.y, width = box.textSize, height = box.textSize }
				expect(`{case.name} Z{index} overlaps Tiptoe: {overlaps(rect, tiptoeRect)}`).toBe(
					`{case.name} Z{index} overlaps Tiptoe: false`
				)
			end
		end
	end)

	it("keeps every letter's top at least 4 points below the screen top, at the top of its rise", function()
		for _, case in CASES do
			local _, _, _, _, boxes = setup(case)
			for index, box in boxes do
				local gap = case.topInset + box.letterTop - MeterZsView.RISE_POINTS
				expect(`{case.name} Z{index} gap {gap}`).toBe(`{case.name} Z{index} gap {math.max(gap, MIN_TOP_GAP)}`)
			end
		end
	end)

	it("keeps every turned letter's top at least 4 points below the screen top, at the top of its rise", function()
		for _, case in CASES do
			local screen, _, _, _, boxes = setup(case)
			for index, box in boxes do
				local gap = case.topInset + turnedTop(box, screen.zs.tilt) - MeterZsView.RISE_POINTS
				expect(`{case.name} Z{index} turned gap {gap}`).toBe(
					`{case.name} Z{index} turned gap {math.max(gap, MIN_TOP_GAP)}`
				)
			end
		end
	end)

	it("keeps every letter on the screen's right side", function()
		for _, case in CASES do
			local _, _, _, _, boxes = setup(case)
			for index, box in boxes do
				local right = box.x + box.textSize
				expect(`{case.name} Z{index} right {right}`).toBe(
					`{case.name} Z{index} right {math.min(right, case.screenSize.X)}`
				)
			end
		end
	end)

	it("puts the first Z 8 points right of the computer meter, level with 30 points below its top", function()
		-- meter-zs.md, "Where" and the computer calm row of the card's look table: (8, 30, 30).
		local case = CASES[3]
		local screen, meterRight, _, _, boxes = setup(case)
		expect(boxes[1].x).toBeCloseTo(meterRight + 8, 3)
		expect(boxes[1].y).toBeCloseTo(screen.meter.topOffset + 30, 3)
		expect(boxes[1].height).toBe(30)
	end)

	it("puts the third Heavy Sleep Z on the phone 80 points right and 19 above the meter top, 44 tall", function()
		-- The phone Heavy Sleep row of the card's look table, 5 points lower for the rise (plan 4 Task 13d): (80, -19, 44).
		local case = CASES[2]
		local screen, meterRight, _, _, boxes = setup(case)
		expect(boxes[3].x).toBeCloseTo(meterRight + 80, 3)
		expect(boxes[3].y).toBeCloseTo(screen.meter.topOffset - 19, 3)
		expect(boxes[3].height).toBe(44)
	end)
end)

describe("MeterZsView.look", function()
	it("hides the Zs when hidden (the 85% warning, and when he is awake)", function()
		expect(MeterZsView.look("hidden").visible).toBe(false)
	end)

	it("shows the Zs at half strength when faded (stirring)", function()
		local look = MeterZsView.look("faded")
		expect(look.visible).toBe(true)
		expect(look.transparency).toBeCloseTo(0.5, 3)
		expect(look.heavy).toBe(false)
	end)

	it("shows the Zs fully, rising over 2 seconds, when shown", function()
		local look = MeterZsView.look("shown")
		expect(look.visible).toBe(true)
		expect(look.transparency).toBe(0)
		expect(look.heavy).toBe(false)
		expect(look.riseSeconds).toBeCloseTo(2, 3)
	end)

	it("shows the bigger Zs rising over 1.4 seconds in Heavy Sleep", function()
		local look = MeterZsView.look("heavy")
		expect(look.visible).toBe(true)
		expect(look.transparency).toBe(0)
		expect(look.heavy).toBe(true)
		expect(look.riseSeconds).toBeCloseTo(1.4, 3)
	end)
end)
