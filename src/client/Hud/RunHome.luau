--!strict
-- The red "RUN HOME!" pill (plan 6 Task 19; spec 6 Rule 67), drawn on the top Hud screen right of the sleep meter. When it
-- shows is HuntView's job; this builds the pill, places it and shows or hides it at once. Look and place: style guide
-- wake-up.md lines 39 to 44; the sizes are in Layout.runHome and the colours in Theme.runHome.
--
-- The pill is a transparent "RunHome" frame that carries the Ink outline. Inside it, drawn in this order: the Ink shadow
-- (the same shape, shifted down), the red fill, and a row with the 🏃 and the words. (A child is always drawn above its
-- parent, so the shadow and the fill have to be children.)

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local RunHome = {}

local RUNNER = "🏃"
local WORDS = "RUN HOME!"
local FULL_ROUND = UDim.new(0.5, 0) -- a pill: the corners are half the height

export type Box = { x: number, y: number, width: number, height: number }

export type Handle = {
	setShown: (shown: boolean) -> (),
	place: (screen: Layout.Screen, meterRight: number) -> (),
	box: () -> Box?, -- the pill's rectangle in its screen's pixels, nil until `place`
	destroy: () -> (),
}

-- Makes the Ink-outlined, round-ended panel the shadow and the fill share.
local function roundPanel(name: string, parent: Instance, color: Color3, zIndex: number): (Frame, UIStroke)
	local panel = Ui.panel(name, parent, color, FULL_ROUND)
	panel.Size = UDim2.fromScale(1, 1)
	panel.ZIndex = zIndex
	return panel, Ui.outline(panel, Theme.ink, 1)
end

-- The rectangle the pill really paints, for labels that must keep clear of it. Roblox turns a GuiObject about its centre
-- (GuiObject.Rotation, never the AnchorPoint), so a tilted pill's corners reach past the unrotated `box`; the Ink
-- outline reaches `borderThickness` past every side and the shadow `shadowOffset` more below.
function RunHome.paintedBox(box: Box, screen: Layout.Screen): Box
	local sizes = screen.runHome
	local radians = math.rad(math.abs(sizes.tilt))
	local halfX = (box.width / 2) * math.cos(radians) + (box.height / 2) * math.sin(radians) + sizes.borderThickness
	local halfY = (box.width / 2) * math.sin(radians) + (box.height / 2) * math.cos(radians) + sizes.borderThickness
	local centreX = box.x + box.width / 2
	local centreY = box.y + box.height / 2
	return {
		x = centreX - halfX,
		y = centreY - halfY,
		width = halfX * 2,
		height = halfY * 2 + sizes.shadowOffset,
	}
end

function RunHome.new(parent: ScreenGui): Handle
	local pill = Ui.group("RunHome", parent)
	pill.Visible = false
	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = FULL_ROUND
	pillCorner.Parent = pill
	local outline = Ui.outline(pill, Theme.ink, 1)

	local shadow, shadowOutline = roundPanel("Shadow", pill, Theme.ink, 1)
	local fill = roundPanel("Fill", pill, Theme.white, 2)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90 -- light at the top, dark at the bottom
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.runHome.fillTop),
		ColorSequenceKeypoint.new(Theme.runHome.middleAt, Theme.runHome.fillMiddle),
		ColorSequenceKeypoint.new(1, Theme.runHome.fillBottom),
	})
	gradient.Parent = fill

	local row = Ui.group("Row", pill)
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = 3
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row

	local runner = Ui.text("Runner", row, RUNNER, 1, Theme.white)
	runner.AutomaticSize = Enum.AutomaticSize.XY
	runner.LayoutOrder = 1
	runner.ZIndex = 3
	local words = Ui.text("Words", row, WORDS, 1, Theme.white)
	words.AutomaticSize = Enum.AutomaticSize.XY
	words.LayoutOrder = 2
	words.ZIndex = 3
	local wordsOutline = Instance.new("UIStroke")
	wordsOutline.Color = Theme.ink
	wordsOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	wordsOutline.Parent = words

	local placed: Box? = nil

	local handle = {} :: Handle

	function handle.setShown(shown: boolean)
		pill.Visible = shown
	end

	function handle.place(screen: Layout.Screen, meterRight: number)
		local sizes = screen.runHome
		local x = meterRight + sizes.leftGap
		pill.Position = UDim2.fromOffset(x, sizes.topOffset)
		pill.Size = UDim2.fromOffset(sizes.width, sizes.height)
		pill.Rotation = sizes.tilt
		outline.Thickness = sizes.borderThickness
		shadow.Position = UDim2.fromOffset(0, sizes.shadowOffset)
		shadowOutline.Thickness = sizes.borderThickness
		list.Padding = UDim.new(0, sizes.gap)
		runner.TextSize = sizes.emojiTextSize
		words.TextSize = sizes.textSize
		wordsOutline.Thickness = sizes.textOutline
		placed = { x = x, y = sizes.topOffset, width = sizes.width, height = sizes.height }
	end

	function handle.box(): Box?
		return placed
	end

	function handle.destroy()
		pill:Destroy()
		placed = nil
	end

	return handle
end

return RunHome
