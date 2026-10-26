--!strict
-- The 85 bubble: saves how it looked first, places it each frame, paints it and puts it back.

local Bubble85 = require(script.Parent.Parent.Bubble85)
local Shared = require(script.Parent.Shared)
local Find = require(script.Parent.Find)

type BubbleStart = Shared.BubbleStart

local BubbleLook = {}

function BubbleLook.new(state: Shared.State, deps: Shared.Deps, find: Find.Finders)
	local function forgetBubble(gui: BillboardGui)
		state.startBubble[gui] = nil
		local watching = state.bubbleWatch[gui]
		if watching ~= nil then
			state.bubbleWatch[gui] = nil
			for _, connection in watching do
				connection:Disconnect()
			end
		end
	end

	local function watchBubble(gui: BillboardGui)
		local function onLeft()
			if not gui:IsDescendantOf(deps.world) then
				forgetBubble(gui)
			end
		end
		-- Destroying fires while the bubble is still in the world, so it forgets at once.
		state.bubbleWatch[gui] = {
			gui.AncestryChanged:Connect(onLeft),
			gui.Destroying:Connect(function()
				forgetBubble(gui)
			end),
		}
	end

	-- The pieces of the bubble: the pill, its words and the tail (found by name each time).
	local function bubbleWords(gui: BillboardGui): TextLabel?
		local found = find.child(find.child(gui, "Frame"), "TextLabel")
		if found ~= nil and found:IsA("TextLabel") then
			return found
		end
		return nil
	end

	local function bubbleTail(gui: BillboardGui): GuiObject?
		local found = find.child(gui, "Tail")
		if found ~= nil and found:IsA("GuiObject") then
			return found
		end
		return nil
	end

	local function bubbleStartOf(gui: BillboardGui): BubbleStart
		local saved = state.startBubble[gui]
		if saved ~= nil then
			return saved
		end
		local words = bubbleWords(gui)
		local tail = bubbleTail(gui)
		local made: BubbleStart = {
			size = gui.Size,
			studsOffset = gui.StudsOffset,
			sizeOffset = gui.SizeOffset,
			textScaled = if words ~= nil then words.TextScaled else false,
			textWrapped = if words ~= nil then words.TextWrapped else false,
			textSize = if words ~= nil then words.TextSize else 0,
			tailPosition = if tail ~= nil then tail.Position else UDim2.new(),
			background = {},
			text = {},
			stroke = {},
		}
		for _, piece in gui:GetDescendants() do
			if piece:IsA("TextLabel") then
				made.text[piece] = piece.TextTransparency
			end
			if piece:IsA("GuiObject") then
				made.background[piece] = piece.BackgroundTransparency
			elseif piece:IsA("UIStroke") then
				made.stroke[piece] = piece.Transparency
			end
		end
		state.startBubble[gui] = made
		watchBubble(gui)
		return made
	end

	-- Makes every part of the bubble `fade` of the way from its own look to fully see-through (0 is its own look).
	local function paintBubble(gui: BillboardGui, fade: number)
		local start = bubbleStartOf(gui)
		for piece, look in start.background do
			piece.BackgroundTransparency = look + (1 - look) * fade
		end
		for piece, look in start.text do
			piece.TextTransparency = look + (1 - look) * fade
		end
		for piece, look in start.stroke do
			piece.Transparency = look + (1 - look) * fade
		end
	end

	-- Sets the bubble's size, side, pop and fade for `now`: `now - bubbleAt` seconds after it popped in.
	local function placeBubble(gui: BillboardGui, now: number)
		local at = state.bubbleAt
		if at == nil then
			return
		end
		bubbleStartOf(gui)
		local seconds = now - at
		local reduced = deps.reducedMotion()
		local look = Bubble85.size(deps.isPhone())
		local scale = Bubble85.popScale(seconds, reduced)
		gui.Size = UDim2.fromOffset(math.round(look.size.X.Offset * scale), math.round(look.size.Y.Offset * scale))
		local side = Bubble85.side(deps.cameraRight().Z)
		gui.StudsOffset = side.studsOffset
		gui.SizeOffset = side.sizeOffset
		local words = bubbleWords(gui)
		if words ~= nil then
			-- One line at a fixed font size; during the pop the words grow with the bubble.
			words.TextScaled = false
			words.TextWrapped = false
			words.TextSize = math.max(1, math.round(look.textSize * scale))
		end
		local tail = bubbleTail(gui)
		if tail ~= nil then
			tail.Position = Bubble85.tailPosition(side.tailRight)
		end
		paintBubble(gui, Bubble85.fade(seconds, reduced))
	end

	-- Puts the bubble's size, side, words and look back as they were before this module changed them.
	local function restoreBubble(gui: BillboardGui?)
		if gui == nil then
			return
		end
		local start = state.startBubble[gui]
		if start == nil then
			return
		end
		gui.Size = start.size
		gui.StudsOffset = start.studsOffset
		gui.SizeOffset = start.sizeOffset
		local words = bubbleWords(gui)
		if words ~= nil then
			words.TextScaled = start.textScaled
			words.TextWrapped = start.textWrapped
			words.TextSize = start.textSize
		end
		local tail = bubbleTail(gui)
		if tail ~= nil then
			tail.Position = start.tailPosition
		end
		paintBubble(gui, 0)
	end

	return {
		forgetBubble = forgetBubble,
		placeBubble = placeBubble,
		restoreBubble = restoreBubble,
	}
end

return BubbleLook
