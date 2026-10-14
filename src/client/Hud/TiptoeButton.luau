--!strict
-- The round Tiptoe button on the right side of the screen, and the C key that does the same (spec Rule 9).
-- It only asks: a click or a press of C sends "the opposite of what the server says now" and nothing else. It
-- lights up from the player's Tiptoe attribute, which the server writes, so the button never shows a guess.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Layout = require(script.Parent.Layout)
local SleepMeterUi = require(script.Parent.SleepMeterUi)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local TiptoeButton = {}

-- The orange glow of the 85% warning (style guide, "Tiptoe orange glow"): full strength at once, held, then faded.
local GLOW_START_TRANSPARENCY = 0.15 -- 15% see-through
local GLOW_HOLD_SECONDS = 0.4
local GLOW_FADE_SECONDS = 0.8
local GLOW_TOTAL_SECONDS = 1.2 -- hold + fade; written out so 0.4 + 0.8 can't come out a hair over 1.2
local CLOCK_SLACK = 1e-6 -- a clock that adds up frame times may be a hair short of an exact second
local WARNING_MARK = 85

local KEY = Enum.KeyCode.C
local KEY_NAME = "C"
local FOOT = "🦶"
-- The word's Ink outline, as a share of its text size (the mockup draws it 5 px wide on 17 px text).
local WORD_OUTLINE = 2
-- The key letter sits on a small Ink tag with this much space at each side of the letter and this radius.
local KEY_SIDE_PADDING = 6
local KEY_CORNER_RADIUS = 5
-- The white shine stripe at the top, as shares of the button (left/right 14%, top 8%, height 20%).
local SHINE_SIDE = 0.14
local SHINE_TOP = 0.08
local SHINE_HEIGHT = 0.2
local SHINE_TRANSPARENCY = 0.65

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type InputLike = { KeyCode: Enum.KeyCode }

export type InputSignalLike = {
	Connect: (self: any, callback: (InputLike, boolean) -> ()) -> ConnectionLike,
}

export type PlayerLike = {
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
}

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

export type Deps = {
	parent: Instance, -- the player's screen (PlayerGui): Hud goes in it
	player: PlayerLike, -- the local player: their Tiptoe attribute is the server's answer
	send: (on: boolean) -> (), -- asks the server for Tiptoe on or off
	input: { InputBegan: InputSignalLike }, -- UserInputService
	warning: { OnClientEvent: SignalLike }, -- the Warning remote: fires 60 or 85 when the meter rises past that mark
	step: SignalLike, -- once per frame, for the glow (RenderStepped)
	now: () -> number, -- a clock in seconds (os.clock)
	viewport: SleepMeterUi.ViewportLike,
}

-- What start gives back: `stop` takes the button off again and cleans everything up, `toggle` does what a click
-- or a press of C does.
export type Handle = {
	stop: () -> (),
	toggle: () -> (),
}

type Parts = {
	root: Frame,
	shadow: Frame,
	ring: Frame,
	ringStroke: UIStroke,
	glow: Frame,
	glowStroke: UIStroke,
	button: TextButton,
	buttonStroke: UIStroke,
	emoji: TextLabel,
	word: TextLabel,
	key: TextLabel,
}

-- Builds the button's pieces (sizes come later, from the layout).
local function build(hud: ScreenGui): Parts
	local root = Ui.group("Tiptoe", hud)
	root.AnchorPoint = Vector2.new(1, 0.5)

	-- The Ink shadow under the button: the same circle, shifted down.
	local shadow = Ui.panel("Shadow", root, Theme.ink, UDim.new(0.5, 0))
	shadow.Size = UDim2.fromScale(1, 1)

	-- The white ring that shows Tiptoe is on: a circle with no fill whose outline is drawn just outside it.
	local ring = Ui.group("OnRing", root)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.ZIndex = 3
	ring.Visible = false
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring
	local ringStroke = Ui.outline(ring, Theme.white, 1)

	-- The orange glow of the 85% warning: a round ring with no fill, behind the white ring and the button, with its
	-- outline drawn outside it. It is hidden until a warning comes.
	local glow = Ui.group("WarnGlow", root)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.ZIndex = 1
	glow.Visible = false
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = glow
	local glowStroke = Ui.outline(glow, Theme.warningOrange, 1)
	glowStroke.Transparency = GLOW_START_TRANSPARENCY

	-- The button itself. Its outline is drawn outside it, so the button is made smaller by the outline's thickness.
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.white
	button.BorderSizePixel = 0
	button.ZIndex = 2
	button.Parent = root
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.5, 0)
	buttonCorner.Parent = button
	local buttonStroke = Ui.outline(button, Theme.ink, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90 -- top to bottom
	gradient.Color = Theme.tiptoeGradient
	gradient.Parent = button

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Theme.white
	shine.BackgroundTransparency = SHINE_TRANSPARENCY
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(SHINE_SIDE, SHINE_TOP)
	shine.Size = UDim2.fromScale(1 - 2 * SHINE_SIDE, SHINE_HEIGHT)
	shine.ZIndex = 2
	shine.Parent = button
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(0.5, 0)
	shineCorner.Parent = shine

	-- The foot, the word and the key letter, stacked and centred.
	local content = Ui.group("Content", button)
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 3
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 1)
	list.Parent = content

	local emoji = Ui.text("Emoji", content, FOOT, 1, Theme.white)
	emoji.LayoutOrder = 1
	emoji.ZIndex = 3
	local word = Ui.text("Word", content, "Tiptoe", 1, Theme.white)
	word.LayoutOrder = 2
	word.ZIndex = 3
	local wordStroke = Ui.outline(word, Theme.ink, WORD_OUTLINE)
	wordStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	local key = Ui.text("Key", content, KEY_NAME, 1, Theme.white)
	key.LayoutOrder = 3
	key.ZIndex = 3
	key.BackgroundTransparency = 0
	key.BackgroundColor3 = Theme.ink
	key.AutomaticSize = Enum.AutomaticSize.X
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, KEY_CORNER_RADIUS)
	keyCorner.Parent = key
	local keyPadding = Instance.new("UIPadding")
	keyPadding.PaddingLeft = UDim.new(0, KEY_SIDE_PADDING)
	keyPadding.PaddingRight = UDim.new(0, KEY_SIDE_PADDING)
	keyPadding.Parent = key

	return {
		root = root,
		shadow = shadow,
		ring = ring,
		ringStroke = ringStroke,
		glow = glow,
		glowStroke = glowStroke,
		button = button,
		buttonStroke = buttonStroke,
		emoji = emoji,
		word = word,
		key = key,
	}
end

-- Sets every size and text size for a computer or a phone screen.
local function applyLayout(parts: Parts, size: Layout.Tiptoe)
	local diameter = size.diameter
	local border = size.borderThickness
	parts.root.Size = UDim2.fromOffset(diameter, diameter)
	parts.root.Position = UDim2.new(1, -size.rightMargin, 0.5, 0)
	parts.shadow.Position = UDim2.fromOffset(0, size.shadowOffset)
	parts.ring.Size = UDim2.fromOffset(diameter + 2 * size.onGap, diameter + 2 * size.onGap)
	parts.ringStroke.Thickness = size.onThickness
	parts.glowStroke.Thickness = size.glowThickness
	parts.button.Position = UDim2.fromOffset(border, border)
	parts.button.Size = UDim2.new(1, -2 * border, 1, -2 * border)
	parts.buttonStroke.Thickness = border
	parts.emoji.TextSize = size.emojiTextSize
	parts.emoji.Size = UDim2.new(1, 0, 0, size.emojiTextSize + 4)
	parts.word.TextSize = size.wordTextSize
	parts.word.Size = UDim2.new(1, 0, 0, size.wordTextSize + 2)
	parts.key.TextSize = size.keyTextSize
	parts.key.Size = UDim2.fromOffset(0, size.keyTextSize + 3)
	parts.key.Visible = size.showKey
end

-- How see-through the orange glow is `seconds` after the warning, or nil when it is over. It is 15% see-through at
-- once, holds for 0.4 s, then fades evenly to fully see-through over 0.8 s.
function TiptoeButton.glowTransparency(seconds: number): number?
	if seconds >= GLOW_TOTAL_SECONDS - CLOCK_SLACK then
		return nil
	end
	if seconds <= GLOW_HOLD_SECONDS then
		return GLOW_START_TRANSPARENCY
	end
	local faded = (seconds - GLOW_HOLD_SECONDS) / GLOW_FADE_SECONDS
	return GLOW_START_TRANSPARENCY + (1 - GLOW_START_TRANSPARENCY) * faded
end

-- Puts the button on the player's screen. Returns a handle: `stop` takes it off again and cleans up everything it
-- made (every connection and the button itself), and `toggle` does what a click or a press of C does.
function TiptoeButton.start(deps: Deps): Handle
	local hud = Ui.hud(deps.parent)
	local leftOver = hud:FindFirstChild("Tiptoe")
	if leftOver then
		leftOver:Destroy() -- never two buttons
	end

	local trove = Trove.new()
	local parts = build(hud)
	trove:Add(parts.root)

	local size: Layout.Tiptoe = Layout.forScreen(deps.viewport.get()).tiptoe

	-- Sizes the glow: round the button's edge, or, when Tiptoe is on, round the outer edge of the white ring (7 px
	-- out), so the whole orange ring shows outside the white one.
	local function placeGlow()
		local out = if deps.player:GetAttribute("Tiptoe") == true then size.onGap + size.onThickness else 0
		local across = size.diameter + 2 * out
		parts.glow.Size = UDim2.fromOffset(across, across)
	end

	-- The ring shows what the server says, and nothing else.
	local function render()
		parts.ring.Visible = deps.player:GetAttribute("Tiptoe") == true
		placeGlow()
	end

	local function relayout()
		size = Layout.forScreen(deps.viewport.get()).tiptoe
		applyLayout(parts, size)
		placeGlow()
	end

	-- Asks for the opposite of what the server says now.
	local function toggle()
		deps.send(deps.player:GetAttribute("Tiptoe") ~= true)
	end

	local function onInput(input: InputLike, gameProcessed: boolean)
		-- gameProcessed is true while the player types in chat (or another part of Roblox took the key).
		if gameProcessed then
			return
		end
		if input.KeyCode == KEY then
			toggle()
		end
	end

	-- The glow listens to the frame step only while it plays.
	local glowStart = 0
	local stepConnection: RBXScriptConnection? = nil
	local function endGlow()
		parts.glow.Visible = false
		if stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end
	trove:Add(endGlow)

	local function onStep()
		local transparency = TiptoeButton.glowTransparency(deps.now() - glowStart)
		if transparency == nil then
			endGlow()
		else
			parts.glowStroke.Transparency = transparency
		end
	end

	-- A warning at 85 lights the glow again from full strength. Any other mark does nothing.
	local function onWarning(mark: any)
		if mark ~= WARNING_MARK then
			return
		end
		glowStart = deps.now()
		parts.glowStroke.Transparency = GLOW_START_TRANSPARENCY
		parts.glow.Visible = true
		if stepConnection == nil then
			stepConnection = deps.step:Connect(onStep)
		end
	end

	relayout()
	render()
	trove:Add(deps.warning.OnClientEvent:Connect(onWarning))
	trove:Add(deps.player:GetAttributeChangedSignal("Tiptoe"):Connect(render))
	trove:Add(parts.button.Activated:Connect(toggle))
	trove:Add(deps.input.InputBegan:Connect(onInput))
	trove:Add(deps.viewport.connect(relayout))

	return {
		stop = function()
			trove:Destroy()
		end,
		toggle = toggle,
	}
end

return TiptoeButton
