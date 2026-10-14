--!strict
-- Our own "Hold to Grab" prompt (spec Rule 4 and the "Near an egg" row of section 6). The egg spots' prompts use
-- the Custom style, so Roblox draws nothing for them and this module draws the look from the mockups instead
-- (hud.html, .prompt): a pill next to the egg with a white round key (the letter E on computers, a hand on touch
-- screens), the words "Hold to Grab" with "Grab" in gold, and a gold fill that grows over the one second hold.
-- On touch screens (and with a mouse) the pill is a button: pressing it holds, letting go stops.
-- While the player carries an egg, every grab prompt is switched off on this device only and none is drawn
-- (a player carries one egg at a time). A spot whose egg was taken has nothing to grab, so its prompt is switched off
-- the same way while the spot's Waiting is false, and comes back when the egg does (the "Empty egg spot" row of spec
-- section 6). The server still checks every grab itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local GrabPrompt = {}

local HAND = "👆"
-- "Grab" is picked out in gold (core-hud's .prompt b).
local WORDS = `Hold to <font color="#{Theme.gold:ToHex()}">Grab</font>`
-- The fill is see-through enough for the white and gold words to stay readable on top of it.
local FILL_TRANSPARENCY = 0.65
-- Where the prompt floats around the egg's anchor, as a share of its own size: a little to the right of the egg's
-- middle, as in the mockups. (Positive y is up.)
local SIZE_OFFSET = Vector2.new(0.55, 0)

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

-- The four events of ProximityPromptService that this module listens to.
export type ServiceLike = {
	PromptShown: SignalLike, -- (prompt, inputType)
	PromptHidden: SignalLike, -- (prompt)
	PromptButtonHoldBegan: SignalLike, -- (prompt, player)
	PromptButtonHoldEnded: SignalLike, -- (prompt, player)
}

-- A hold prompt as this module uses it. A real ProximityPrompt fits.
export type PromptLike = {
	Parent: Instance?,
	Style: Enum.ProximityPromptStyle,
	HoldDuration: number,
	KeyboardKeyCode: Enum.KeyCode,
	InputHoldBegin: (self: any) -> (),
	InputHoldEnd: (self: any) -> (),
}

export type PlayerLike = {
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
}

-- The screen size: `get` reads it, and `connect` calls `callback` whenever it may have changed and returns a
-- function that stops that.
export type ViewportLike = {
	get: () -> Vector2,
	connect: (callback: () -> ()) -> () -> (),
}

export type Deps = {
	parent: Instance, -- the player's screen (PlayerGui): WorldPrompts goes in it
	service: ServiceLike, -- ProximityPromptService's events
	player: PlayerLike, -- the local player: their Carrying attribute is the server's answer
	root: Instance, -- holds every grab prompt (Workspace.World.EggSpots): they are switched off while carrying
	step: SignalLike, -- once per frame, for the fill (RunService.RenderStepped)
	now: () -> number, -- the clock in seconds, for the fill
	viewport: ViewportLike,
}

-- What start gives back: `stop` takes the prompt off and cleans up. `press` and `release` do what pressing and
-- letting go of the drawn prompt do (the pill calls them itself; tests call them because a test can't press a
-- button).
export type Handle = {
	stop: () -> (),
	press: () -> (),
	release: () -> (),
}

type Parts = {
	gui: BillboardGui,
	pill: TextButton,
	pillCorner: UICorner,
	pillStroke: UIStroke,
	fill: Frame,
	content: Frame,
	padding: UIPadding,
	list: UIListLayout,
	key: Frame,
	keyText: TextLabel,
	words: TextLabel,
	wordsStroke: UIStroke,
}

-- The prompt that is drawn right now.
type Shown = {
	prompt: PromptLike,
	parts: Parts,
	pressed: boolean,
	holdStart: number?,
	stepConnection: ConnectionLike?,
}

-- Builds the prompt's pieces for one egg spot (sizes come later, from the layout).
local function build(layer: ScreenGui, prompt: PromptLike, inputType: Enum.ProximityPromptInputType): Parts
	local gui = Instance.new("BillboardGui")
	gui.Name = "GrabPrompt"
	gui.AlwaysOnTop = true
	gui.Active = true -- so the pill can be pressed
	gui.Adornee = prompt.Parent :: Instance
	gui.SizeOffset = SIZE_OFFSET

	-- The pill is a button, so a press on it (touch, or a mouse click) holds the prompt.
	local pill = Instance.new("TextButton")
	pill.Name = "Pill"
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.Selectable = false
	pill.BackgroundColor3 = Theme.ink
	pill.BackgroundTransparency = Theme.promptTransparency
	pill.BorderSizePixel = 0
	pill.ClipsDescendants = true
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Parent = gui
	local pillCorner = Instance.new("UICorner")
	pillCorner.Parent = pill
	local pillStroke = Ui.outline(pill, Theme.white, 1)

	-- The fill grows from the left over the plate, behind the key and the words.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.gold
	fill.BackgroundTransparency = FILL_TRANSPARENCY
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 1
	fill.Parent = pill

	local content = Ui.group("Content", pill)
	content.AutomaticSize = Enum.AutomaticSize.XY
	content.ZIndex = 2
	local padding = Instance.new("UIPadding")
	padding.Parent = content
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content

	local key = Ui.panel("Key", content, Theme.white, UDim.new(0.5, 0))
	key.LayoutOrder = 1
	local keyLabel = if inputType == Enum.ProximityPromptInputType.Touch then HAND else prompt.KeyboardKeyCode.Name
	local keyText = Ui.text("KeyText", key, keyLabel, 1, Theme.ink)
	keyText.Size = UDim2.fromScale(1, 1)

	local words = Ui.text("GrabText", content, WORDS, 1, Theme.white)
	words.RichText = true
	words.AutomaticSize = Enum.AutomaticSize.XY
	words.LayoutOrder = 2
	local wordsStroke = Ui.outline(words, Theme.ink, 1)
	wordsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	gui.Parent = layer
	return {
		gui = gui,
		pill = pill,
		pillCorner = pillCorner,
		pillStroke = pillStroke,
		fill = fill,
		content = content,
		padding = padding,
		list = list,
		key = key,
		keyText = keyText,
		words = words,
		wordsStroke = wordsStroke,
	}
end

-- Sets every size and text size for a computer or a phone screen.
local function applyLayout(parts: Parts, size: Layout.Prompt)
	parts.gui.Size = UDim2.fromOffset(size.billboardWidth, size.billboardHeight)
	parts.pillCorner.CornerRadius = UDim.new(0, size.cornerRadius)
	parts.pillStroke.Thickness = size.borderThickness
	parts.padding.PaddingLeft = UDim.new(0, size.paddingLeft)
	parts.padding.PaddingRight = UDim.new(0, size.paddingRight)
	parts.padding.PaddingTop = UDim.new(0, size.paddingY)
	parts.padding.PaddingBottom = UDim.new(0, size.paddingY)
	parts.list.Padding = UDim.new(0, size.gap)
	parts.key.Size = UDim2.fromOffset(size.keyDiameter, size.keyDiameter)
	parts.keyText.TextSize = size.keyTextSize
	parts.words.TextSize = size.textSize
	parts.wordsStroke.Thickness = size.textOutline
end

-- The egg spot a prompt belongs to: the model that holds the prompt (prompt, PromptAnchor, Base, spot).
local function spotOf(inside: Instance?): Instance?
	if inside == nil then
		return nil
	end
	return inside:FindFirstAncestorOfClass("Model")
end

-- A spot whose egg was taken has Waiting set to false. A prompt that belongs to no spot is never empty.
local function isEmpty(spot: Instance?): boolean
	return spot ~= nil and spot:GetAttribute("Waiting") == false
end

-- A touch or a mouse click starts and ends a press on the pill (like Roblox's own prompt).
local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Draws our prompt for every Custom grab prompt Roblox shows, and returns a handle (see Handle).
function GrabPrompt.start(deps: Deps): Handle
	local layer = Ui.worldLayer(deps.parent)
	local trove = Trove.new()
	local stopped = false
	local shown: Shown? = nil
	local carrying = deps.player:GetAttribute("Carrying") ~= nil
	-- Every grab prompt under the root, so they can be switched off and on.
	local tracked: { [Instance]: boolean } = {}
	-- Each tracked prompt's listener for its spot's Waiting attribute.
	local watching: { [Instance]: RBXScriptConnection? } = {}

	local function setFill(current: Shown, share: number)
		current.parts.fill.Size = UDim2.fromScale(share, 1)
	end

	local function stopFollowingFrames(current: Shown)
		if current.stepConnection then
			current.stepConnection:Disconnect()
			current.stepConnection = nil
		end
	end

	local function remove()
		local current = shown
		if current == nil then
			return
		end
		shown = nil
		stopFollowingFrames(current)
		-- A finger still down when the prompt goes away would leave the hold stuck, so let go for it.
		if current.pressed then
			current.pressed = false
			current.prompt:InputHoldEnd()
		end
		current.parts.gui:Destroy()
	end
	trove:Add(remove)

	local function relayout()
		local current = shown
		if current then
			applyLayout(current.parts, Layout.forScreen(deps.viewport.get()).prompt)
		end
	end

	local press: () -> () = function() end
	local release: () -> () = function() end

	local function onShown(prompt: PromptLike, inputType: Enum.ProximityPromptInputType)
		-- Prompts of other styles draw themselves. While carrying, or on an empty spot, nothing is drawn.
		if
			stopped
			or carrying
			or prompt.Style ~= Enum.ProximityPromptStyle.Custom
			or isEmpty(spotOf(prompt.Parent))
		then
			return
		end
		remove() -- one prompt at a time: the one Roblox showed last
		local parts = build(layer, prompt, inputType)
		shown = { prompt = prompt, parts = parts, pressed = false, holdStart = nil, stepConnection = nil }
		-- These connections end when the pill is destroyed in remove().
		parts.pill.InputBegan:Connect(function(input: InputObject)
			if isPress(input) and input.UserInputState ~= Enum.UserInputState.Change then
				press()
			end
		end)
		parts.pill.InputEnded:Connect(function(input: InputObject)
			if isPress(input) then
				release()
			end
		end)
		relayout()
	end

	local function onHidden(prompt: PromptLike)
		if shown and shown.prompt == prompt then
			remove()
		end
	end

	-- The fill is how far through the prompt's hold time the player is.
	local function onHoldBegan(prompt: PromptLike)
		local current = shown
		if current == nil or current.prompt ~= prompt then
			return
		end
		stopFollowingFrames(current)
		current.holdStart = deps.now()
		setFill(current, 0)
		current.stepConnection = deps.step:Connect(function()
			local start = current.holdStart
			if start == nil then
				return
			end
			local hold = prompt.HoldDuration
			local share = if hold > 0 then (deps.now() - start) / hold else 1
			setFill(current, math.clamp(share, 0, 1))
		end)
	end

	local function onHoldEnded(prompt: PromptLike)
		local current = shown
		if current == nil or current.prompt ~= prompt then
			return
		end
		stopFollowingFrames(current)
		current.holdStart = nil
		setFill(current, 0)
	end

	-- Pressing the pill holds the prompt, like pressing the key.
	press = function()
		local current = shown
		if current and not current.pressed then
			current.pressed = true
			current.prompt:InputHoldBegin()
		end
	end

	release = function()
		local current = shown
		if current and current.pressed then
			current.pressed = false
			current.prompt:InputHoldEnd()
		end
	end

	-- A prompt is on unless the player carries an egg or its spot is empty. Roblox hides a switched-off prompt by
	-- itself (and calls onHidden); switching it off is the point.
	local function update(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			instance.Enabled = not carrying and not isEmpty(spotOf(instance))
		end
	end

	local function track(instance: Instance)
		if not instance:IsA("ProximityPrompt") then
			return
		end
		tracked[instance] = true
		update(instance)
		local spot = spotOf(instance)
		if spot ~= nil and watching[instance] == nil then
			watching[instance] = spot:GetAttributeChangedSignal("Waiting"):Connect(function()
				update(instance)
				-- The prompt that is drawn belongs to the spot that just emptied: take it away.
				local current = shown
				if current ~= nil and isEmpty(spot) and spotOf(current.prompt.Parent) == spot then
					remove()
				end
			end)
		end
	end

	local function untrack(instance: Instance)
		tracked[instance] = nil
		local connection = watching[instance]
		if connection ~= nil then
			watching[instance] = nil
			connection:Disconnect()
		end
	end

	local function onCarryingChanged()
		carrying = deps.player:GetAttribute("Carrying") ~= nil
		for instance in tracked do
			update(instance)
		end
		if carrying then
			remove()
		end
	end

	for _, descendant in deps.root:GetDescendants() do
		track(descendant)
	end
	trove:Add(deps.root.DescendantAdded:Connect(track))
	trove:Add(deps.root.DescendantRemoving:Connect(untrack))
	trove:Add(deps.player:GetAttributeChangedSignal("Carrying"):Connect(onCarryingChanged))
	trove:Add(deps.service.PromptShown:Connect(onShown))
	trove:Add(deps.service.PromptHidden:Connect(onHidden))
	trove:Add(deps.service.PromptButtonHoldBegan:Connect(onHoldBegan))
	trove:Add(deps.service.PromptButtonHoldEnded:Connect(onHoldEnded))
	trove:Add(deps.viewport.connect(relayout))
	-- Back to normal when this stops: no prompt stays switched off, and no spot is listened to any more.
	trove:Add(function()
		for instance in tracked do
			if instance:IsA("ProximityPrompt") then
				instance.Enabled = true
			end
		end
		for instance in watching do
			untrack(instance)
		end
	end)

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			trove:Destroy()
		end,
		press = function()
			press()
		end,
		release = function()
			release()
		end,
	}
end

return GrabPrompt
