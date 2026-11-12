--!strict
-- The "RUN HOME!" pill (plan 6 Task 19; spec 6 Rule 67). Look and place: style guide docs/design/v2/style-guide/wake-up.md,
-- lines 39 to 44 ("RUN HOME!" and "Where RUN HOME! sits"). Sizes and colours are read from Layout and Theme; the one
-- test that types the guide's numbers is "holds the style guide's numbers", so a wrong table entry shows up there.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Layout = require(Hud.Layout)
local RunHome = require(Hud.RunHome)
local Theme = require(Hud.Theme)

local COMPUTER = Vector2.new(1280, 720)
local PHONE = Vector2.new(844, 390)
local screens: { [string]: Vector2 } = { computer = COMPUTER, phone = PHONE }
local METER_RIGHT = 700 -- where the meter's right edge is, as SleepMeterUi's onLayout would say

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeGuis: { ScreenGui } = {}
local handles: { RunHome.Handle } = {}

afterEach(function()
	for _, handle in handles do
		handle.destroy()
	end
	table.clear(handles)
	for _, gui in madeGuis do
		gui:Destroy()
	end
	table.clear(madeGuis)
end)

local function newPill(): (ScreenGui, RunHome.Handle)
	local gui = Instance.new("ScreenGui")
	table.insert(madeGuis, gui)
	local handle = RunHome.new(gui)
	table.insert(handles, handle)
	return gui, handle
end

local function pillOf(gui: ScreenGui): Frame
	local pill = gui:FindFirstChild("RunHome")
	assert(pill ~= nil and pill:IsA("Frame"), "no RunHome frame")
	return pill
end

local function wordsOf(pill: Frame): TextLabel
	for _, descendant in pill:GetDescendants() do
		if descendant:IsA("TextLabel") and descendant.Text == "RUN HOME!" then
			return descendant
		end
	end
	error("no RUN HOME! words")
end

describe("RunHome.new", function()
	it("builds a hidden RunHome pill on the screen it is given", function()
		local gui = newPill()
		expect(pillOf(gui).Visible).toBe(false)
	end)

	it("says RUN HOME! in white Fredoka One", function()
		local gui = newPill()
		local words = wordsOf(pillOf(gui))
		expect(words.TextColor3).toEqual(Theme.white)
		expect(words.FontFace.Family).toBe(Theme.font.Family)
	end)

	it("has a runner picture before the words", function()
		local gui = newPill()
		local pill = pillOf(gui)
		local picture: TextLabel? = nil
		for _, descendant in pill:GetDescendants() do
			if descendant:IsA("TextLabel") and descendant.Text ~= "RUN HOME!" and descendant.Text ~= "" then
				picture = descendant
			end
		end
		expect(picture ~= nil).toBe(true)
		expect((picture :: TextLabel).LayoutOrder < wordsOf(pill).LayoutOrder).toBe(true)
	end)

	it("fills the pill from Theme.runHome.fillTop down to Theme.runHome.fillBottom", function()
		local gui = newPill()
		local gradient = pillOf(gui):FindFirstChildWhichIsA("UIGradient", true)
		assert(gradient ~= nil, "no UIGradient")
		local keypoints = gradient.Color.Keypoints
		expect(keypoints[1].Value).toEqual(Theme.runHome.fillTop)
		expect(keypoints[#keypoints].Value).toEqual(Theme.runHome.fillBottom)
	end)
end)

describe("RunHome.setShown", function()
	it("shows the pill at once, and hides it at once", function()
		local gui, handle = newPill()
		handle.setShown(true)
		expect(pillOf(gui).Visible).toBe(true)
		handle.setShown(false)
		expect(pillOf(gui).Visible).toBe(false)
	end)
end)

describe("RunHome.place: where the pill goes", function()
	for name, size in screens do
		it(
			`puts the pill level with the meter, its left edge a gap right of the meter's right edge, on a {name}`,
			function()
				local layout = Layout.forScreen(size)
				local gui, handle = newPill()
				handle.place(layout, METER_RIGHT)
				local pill = pillOf(gui)
				expect(pill.Position.X.Offset).toBeCloseTo(METER_RIGHT + layout.runHome.leftGap, 3)
				expect(pill.Position.Y.Offset).toBeCloseTo(layout.runHome.topOffset, 3)
				expect(pill.Size.X.Offset).toBeCloseTo(layout.runHome.width, 3)
				expect(pill.Size.Y.Offset).toBeCloseTo(layout.runHome.height, 3)
			end
		)

		it(`draws the words at the style guide's text size, with its outline, shadow and tilt, on a {name}`, function()
			local layout = Layout.forScreen(size)
			local gui, handle = newPill()
			handle.place(layout, METER_RIGHT)
			local pill = pillOf(gui)
			expect(wordsOf(pill).TextSize).toBe(layout.runHome.textSize)
			expect(pill.Rotation).toBeCloseTo(layout.runHome.tilt, 3)
			local outline = pill:FindFirstChildWhichIsA("UIStroke")
			assert(outline ~= nil, "no UIStroke on the pill")
			expect(outline.Thickness).toBe(layout.runHome.borderThickness)
			expect(outline.Color).toEqual(Theme.ink)
			local shadow = pill:FindFirstChild("Shadow", true)
			assert(shadow ~= nil and shadow:IsA("GuiObject"), "no Shadow")
			expect(shadow.Position.Y.Offset).toBeCloseTo(layout.runHome.shadowOffset, 3)
			expect(shadow.BackgroundColor3).toEqual(Theme.ink)
		end)

		it(`reports its box in the screen's pixels, to the pixel, on a {name}`, function()
			local layout = Layout.forScreen(size)
			local _, handle = newPill()
			handle.place(layout, METER_RIGHT)
			local box = handle.box()
			assert(box ~= nil, "no box")
			expect(box.x).toBeCloseTo(METER_RIGHT + layout.runHome.leftGap, 3)
			expect(box.y).toBeCloseTo(layout.runHome.topOffset, 3)
			expect(box.width).toBeCloseTo(layout.runHome.width, 3)
			expect(box.height).toBeCloseTo(layout.runHome.height, 3)
		end)
	end

	it("moves the pill when the meter moves (a new layout)", function()
		local gui, handle = newPill()
		handle.place(Layout.forScreen(COMPUTER), METER_RIGHT)
		handle.place(Layout.forScreen(COMPUTER), METER_RIGHT + 100)
		expect(pillOf(gui).Position.X.Offset).toBeCloseTo(
			METER_RIGHT + 100 + Layout.forScreen(COMPUTER).runHome.leftGap,
			3
		)
	end)

	it("has no box until it has been placed", function()
		local _, handle = newPill()
		expect(handle.box()).toBeNil()
	end)

	it("holds the style guide's numbers (wake-up.md lines 39 to 44)", function()
		local computer = Layout.forScreen(COMPUTER).runHome
		expect(computer.textSize).toBe(34)
		expect(computer.leftGap).toBe(14)
		expect(computer.topOffset).toBe(14)
		expect(computer.borderThickness).toBe(4)
		expect(computer.shadowOffset).toBe(5)
		expect(computer.tilt).toBe(-2)
		local phone = Layout.forScreen(PHONE).runHome
		expect(phone.textSize).toBe(20)
		expect(phone.leftGap).toBe(10)
		expect(phone.topOffset).toBe(12)
		expect(phone.borderThickness).toBe(3)
		expect(phone.shadowOffset).toBe(3)
		expect(phone.tilt).toBe(-2)
		expect(Theme.runHome.fillTop).toEqual(Color3.fromHex("FF7A86"))
		expect(Theme.runHome.fillBottom).toEqual(Color3.fromHex("C4142A"))
	end)
end)

describe("RunHome.destroy", function()
	it("removes the pill from the screen", function()
		local gui, handle = newPill()
		handle.place(Layout.forScreen(COMPUTER), METER_RIGHT)
		handle.setShown(true)
		handle.destroy()
		expect(gui:FindFirstChild("RunHome")).toBeNil()
	end)
end)

-- Roblox turns a GuiObject about its centre (GuiObject.Rotation docs), so a tilted pill's corners reach past the
-- unrotated box; the Ink outline and the shadow reach past it too. `paintedBox` is what labels must keep clear of.
describe("RunHome.paintedBox", function()
	it("covers the tilted corners, the outline and the shadow, and keeps the same centre line", function()
		for _, size in screens do
			local screen = Layout.forScreen(size)
			local sizes = screen.runHome
			local box = { x = 700, y = sizes.topOffset, width = sizes.width, height = sizes.height }
			local painted = RunHome.paintedBox(box, screen)
			local radians = math.rad(math.abs(sizes.tilt))
			local halfX = (box.width / 2) * math.cos(radians) + (box.height / 2) * math.sin(radians)
			local halfY = (box.width / 2) * math.sin(radians) + (box.height / 2) * math.cos(radians)
			local centreX = box.x + box.width / 2
			local centreY = box.y + box.height / 2
			expect(painted.x).toBeCloseTo(centreX - halfX - sizes.borderThickness, 3)
			expect(painted.x + painted.width).toBeCloseTo(centreX + halfX + sizes.borderThickness, 3)
			expect(painted.y).toBeCloseTo(centreY - halfY - sizes.borderThickness, 3)
			expect(painted.y + painted.height).toBeCloseTo(
				centreY + halfY + sizes.borderThickness + sizes.shadowOffset,
				3
			)
			-- the unrotated box is always inside it
			expect(painted.x <= box.x and painted.y <= box.y).toBe(true)
			expect(painted.x + painted.width >= box.x + box.width).toBe(true)
			expect(painted.y + painted.height >= box.y + box.height).toBe(true)
		end
	end)
end)
