--!strict
-- The sleep meter at the top centre of the screen: one meter, the same for every player (spec Rule 7), with
-- the pulse at 60% (Rule 10). It only shows what the server says: it reads the GiantState attributes and
-- listens for the Warning remote. What it shows for each state is worked out in MeterView.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local BarPaint = require(script.Parent.BarPaint)
local Layout = require(script.Parent.Layout)
local MeterView = require(script.Parent.MeterView)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local SleepMeterUi = {}

-- The pulse at 60%: the meter grows to this size and back, over PULSE_SECONDS in all.
local PULSE_SCALE = 1.1
local PULSE_SECONDS = 0.3
-- The face is a little wider than its text size, so the emoji is never cut off.
local FACE_WIDTH_FACTOR = 1.25
-- The Heavy Sleep stripes lean right by this many degrees, like the mockup's.
local STRIPE_LEAN_DEGREES = 30
-- The lock sits this many pixels in from the bar's right end.
local LOCK_MARGIN = 6
-- The bar's marks are drawn at these shares of its length.
local TICK_NAMES = { "Tick60", "Tick85" }

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}
export type WarningLike = { OnClientEvent: SignalLike }

-- The screen size: `get` reads it, and `connect` calls `callback` whenever it may have changed and returns a
-- function that stops that.
export type ViewportLike = {
	get: () -> Vector2,
	connect: (callback: () -> ()) -> () -> (),
}

-- The right edge of Roblox's own buttons at the top left (GuiService.TopbarInset.Min.X): `get` reads it, and
-- `connect` calls `callback` whenever it may have changed and returns a function that stops that.
export type TopbarLike = {
	get: () -> number,
	connect: (callback: () -> ()) -> () -> (),
}

export type Deps = {
	parent: Instance, -- the player's screen (PlayerGui): HudTop goes in it
	giantState: Instance, -- has the attributes Meter, Phase and PhaseEndsAt
	warning: WarningLike, -- fires 60 or 85 when the meter rises past that mark
	viewport: ViewportLike,
	topbarInset: TopbarLike,
	now: () -> number, -- the server's clock (Workspace:GetServerTimeNow())
}

type Parts = {
	root: Frame,
	pulse: UIScale,
	shadow: Frame,
	panel: Frame,
	panelStroke: UIStroke,
	face: TextLabel,
	column: Frame,
	columnList: UIListLayout,
	label: TextLabel,
	barHolder: Frame,
	track: Frame,
	trackStroke: UIStroke,
	fill: Frame,
	gradient: UIGradient,
	stripes: Frame, -- holds the Heavy Sleep stripes
	stripeFrames: { Frame },
	ticks: { Frame },
	lock: TextLabel,
}

-- Builds the meter's pieces (sizes come later, from the layout).
local function build(hud: ScreenGui): Parts
	local root = Ui.group("SleepMeter", hud)
	root.AnchorPoint = Vector2.new(0.5, 0)
	local pulse = Instance.new("UIScale")
	pulse.Name = "Pulse"
	pulse.Parent = root

	-- The Ink shadow under the meter: the same pill shape, shifted down.
	local shadow = Ui.panel("Shadow", root, Theme.ink, UDim.new(0.5, 0))
	shadow.Size = UDim2.fromScale(1, 1)

	local panel = Ui.panel("Panel", root, Theme.cream, UDim.new(0.5, 0))
	local panelStroke = Ui.outline(panel, Theme.ink, 1)

	local face = Ui.text("Face", panel, "", 1, Theme.white)
	local column = Ui.group("Column", panel)
	local columnList = Instance.new("UIListLayout")
	columnList.FillDirection = Enum.FillDirection.Vertical
	columnList.VerticalAlignment = Enum.VerticalAlignment.Center
	columnList.SortOrder = Enum.SortOrder.LayoutOrder
	columnList.Parent = column

	local label = Ui.text("Label", column, "", 1, Theme.sleepBlueDark)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = 1

	local barHolder = Ui.group("BarHolder", column)
	barHolder.LayoutOrder = 2
	-- The bar sits inside the holder, and its outline is drawn just outside it.
	local track = Ui.panel("Track", barHolder, Theme.track, UDim.new(0.5, 0))
	local trackStroke = Ui.outline(track, Theme.ink, 1)
	local fill = Ui.panel("Fill", track, Theme.white, UDim.new(0.5, 0))
	local gradient = Instance.new("UIGradient")
	gradient.Parent = fill
	-- The Heavy Sleep stripes sit inside the bar, clipped to the bar's straight middle (its round ends stay plain).
	local stripes = Ui.group("Stripes", fill)
	stripes.ClipsDescendants = true
	stripes.Visible = false

	local ticks: { Frame } = {}
	for index, name in TICK_NAMES do
		local tick = Instance.new("Frame")
		tick.Name = name
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.BackgroundColor3 = Theme.tickColor
		tick.BackgroundTransparency = Theme.tickTransparency
		tick.BorderSizePixel = 0
		tick.ZIndex = 2
		tick.Position = UDim2.fromScale(Config.Meter.WarningMarks[index] / Config.Meter.Max, 0)
		tick.Parent = track
		table.insert(ticks, tick)
	end

	local lock = Ui.text("Lock", track, "🔒", 1, Theme.white)
	lock.AnchorPoint = Vector2.new(1, 0.5)
	lock.ZIndex = 3
	lock.Visible = false

	return {
		root = root,
		pulse = pulse,
		shadow = shadow,
		panel = panel,
		panelStroke = panelStroke,
		face = face,
		column = column,
		columnList = columnList,
		label = label,
		barHolder = barHolder,
		track = track,
		trackStroke = trackStroke,
		fill = fill,
		gradient = gradient,
		stripes = stripes,
		stripeFrames = {},
		ticks = ticks,
		lock = lock,
	}
end

-- Lays out the slanted Heavy Sleep stripes along a bar `barWidth` wide and `barHeight` tall: light stripes half a
-- period wide, one every `period` pixels. The bar's round ends (half its height at each end) stay plain.
local function layoutStripes(parts: Parts, barWidth: number, barHeight: number, period: number)
	local endCap = math.floor(barHeight / 2)
	local width = barWidth - 2 * endCap
	parts.stripes.Position = UDim2.fromOffset(endCap, 0)
	parts.stripes.Size = UDim2.new(0, width, 1, 0)
	-- Enough stripes to cover the width, plus extra at each end because the lean moves the tops sideways.
	local count = math.ceil(width / period) + 2
	for _ = #parts.stripeFrames + 1, count do
		local stripe = Instance.new("Frame")
		stripe.Name = "Stripe"
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.BackgroundColor3 = Theme.stripeLight
		stripe.BorderSizePixel = 0
		stripe.Rotation = STRIPE_LEAN_DEGREES
		stripe.Parent = parts.stripes
		table.insert(parts.stripeFrames, stripe)
	end
	for index, stripe in parts.stripeFrames do
		stripe.Visible = index <= count
		stripe.Size = UDim2.fromOffset(period / 2, barHeight * 3)
		stripe.Position = UDim2.new(0, (index - 1) * period, 0.5, 0)
	end
end

-- Sets every size and text size for a computer or a phone screen.
local function applyLayout(parts: Parts, size: Layout.Meter, centerShift: number)
	local border = size.borderThickness
	local innerWidth = size.width - 2 * border
	local faceWidth = math.ceil(size.faceTextSize * FACE_WIDTH_FACTOR)
	local columnLeft = size.padding + faceWidth + size.gap
	local columnWidth = innerWidth - columnLeft - size.padding
	local barStroke = size.barStrokeThickness

	parts.root.Size = UDim2.fromOffset(size.width, size.height)
	parts.root.Position = UDim2.new(0.5, centerShift, 0, size.topOffset)
	-- The outline is drawn outside the panel, so the panel is made smaller by the outline's thickness.
	parts.shadow.Position = UDim2.fromOffset(0, size.shadowOffset)
	parts.panel.Position = UDim2.fromOffset(border, border)
	parts.panel.Size = UDim2.new(1, -2 * border, 1, -2 * border)
	parts.panelStroke.Thickness = border

	parts.face.Position = UDim2.fromOffset(size.padding, 0)
	parts.face.Size = UDim2.new(0, faceWidth, 1, 0)
	parts.face.TextSize = size.faceTextSize
	parts.column.Position = UDim2.fromOffset(columnLeft, 0)
	parts.column.Size = UDim2.new(0, columnWidth, 1, 0)
	parts.columnList.Padding = UDim.new(0, size.rowGap)
	parts.label.Size = UDim2.new(1, 0, 0, size.labelTextSize + 3)
	parts.label.TextSize = size.labelTextSize
	parts.barHolder.Size = UDim2.new(1, 0, 0, size.barHeight)
	parts.track.Position = UDim2.fromOffset(barStroke, barStroke)
	parts.track.Size = UDim2.new(1, -2 * barStroke, 1, -2 * barStroke)
	parts.trackStroke.Thickness = barStroke

	for _, tick in parts.ticks do
		tick.Size = UDim2.new(0, size.tickWidth, 1, 0)
	end
	layoutStripes(parts, columnWidth - 2 * barStroke, size.barHeight - 2 * barStroke, size.stripePeriod)
	parts.lock.TextSize = size.lockTextSize
	parts.lock.Size = UDim2.fromOffset(math.ceil(size.lockTextSize * FACE_WIDTH_FACTOR), size.barHeight)
	parts.lock.Position = UDim2.new(1, -LOCK_MARGIN, 0.5, 0)
end

-- Paints the bar for a style: one solid colour, a gradient the fill uncovers, or slanted stripes.
local function paintBar(parts: Parts, barStyle: MeterView.BarStyle, fill: number)
	local paint = Theme.bars[barStyle]
	parts.fill.BackgroundColor3 = paint.color
	parts.stripes.Visible = paint.stripes
	local colors = paint.gradient
	if colors == nil then
		parts.gradient.Enabled = false
		return
	end
	parts.gradient.Enabled = true
	parts.gradient.Color = if paint.reveal then BarPaint.reveal(colors, fill) else colors
end

-- Starts the meter on the player's screen. Returns a function that takes it off again and stops everything:
-- every connection, tween and waiting thread is cleaned up by it.
function SleepMeterUi.start(deps: Deps): () -> ()
	local hud = Ui.hudTop(deps.parent)
	local leftOver = hud:FindFirstChild("SleepMeter")
	if leftOver then
		leftOver:Destroy() -- never two meters
	end

	local trove = Trove.new()
	local parts = build(hud)
	trove:Add(parts.root)

	local look: MeterView.Look? = nil
	local refreshThread: thread? = nil
	local pulseTween: Tween? = nil

	local function cancelRefresh()
		if refreshThread then
			task.cancel(refreshThread)
			refreshThread = nil
		end
	end

	local function render()
		cancelRefresh()
		local state = deps.giantState
		local current = MeterView.fromAttributes(
			state:GetAttribute("Meter"),
			state:GetAttribute("Phase"),
			state:GetAttribute("PhaseEndsAt"),
			deps.now()
		)
		local previous = look
		look = current

		parts.face.Text = current.face
		parts.label.Text = current.label
		local colors = Theme.rows[current.row]
		parts.panel.BackgroundColor3 = colors.panel
		parts.label.TextColor3 = colors.label
		parts.lock.Visible = current.locked
		parts.fill.Visible = current.fill > 0
		parts.fill.Size = UDim2.fromScale(current.fill, 1)
		-- The gradient only needs redoing when the style changes, or (for the uncovering one) when the fill does.
		local paint = Theme.bars[current.barStyle]
		if
			previous == nil
			or previous.barStyle ~= current.barStyle
			or (paint.reveal and previous.fill ~= current.fill)
		then
			paintBar(parts, current.barStyle, current.fill)
		end

		-- A countdown changes the words by itself: come back just after the shown second changes.
		if current.refreshIn then
			refreshThread = task.delay(current.refreshIn, function()
				refreshThread = nil
				render()
			end)
		end
	end

	-- Sizes the meter for the screen and puts it in the middle, or just right of Roblox's buttons if they come close.
	local function relayout()
		local screen = Layout.forScreen(deps.viewport.get())
		local width = deps.viewport.get().X
		local centerX = Layout.meterCenterX(width, screen.meter.width, deps.topbarInset.get(), PULSE_SCALE)
		applyLayout(parts, screen.meter, centerX - width / 2)
		if look then
			paintBar(parts, look.barStyle, look.fill)
		end
	end

	local function stopPulse()
		if pulseTween then
			pulseTween:Cancel()
			pulseTween:Destroy()
			pulseTween = nil
		end
		parts.pulse.Scale = 1
	end

	-- One pulse: grows to PULSE_SCALE and back (the tween reverses itself), PULSE_SECONDS in all.
	local function pulseOnce()
		stopPulse()
		local info = TweenInfo.new(PULSE_SECONDS / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true)
		local tween = TweenService:Create(parts.pulse, info, { Scale = PULSE_SCALE })
		pulseTween = tween
		tween:Play()
	end

	local function onWarning(mark: any)
		if mark == Config.Meter.WarningMarks[1] then
			pulseOnce()
		end
	end

	relayout()
	render()
	for _, name in { "Meter", "Phase", "PhaseEndsAt" } do
		trove:Connect(deps.giantState:GetAttributeChangedSignal(name), render)
	end
	trove:Add(deps.warning.OnClientEvent:Connect(onWarning))
	trove:Add(deps.viewport.connect(relayout))
	trove:Add(deps.topbarInset.connect(relayout))
	trove:Add(cancelRefresh)
	trove:Add(stopPulse)

	return function()
		trove:Destroy()
	end
end

-- The real screen size: the current camera's ViewportSize, followed when the window changes or Roblox swaps
-- the camera.
function SleepMeterUi.workspaceViewport(workspace: Workspace): ViewportLike
	return {
		get = function()
			local camera = workspace.CurrentCamera
			if camera then
				return camera.ViewportSize
			end
			return Vector2.new(1280, 720) -- no camera yet: assume a computer screen until it arrives
		end,
		connect = function(callback: () -> ())
			local sizeConnection: RBXScriptConnection? = nil
			local function watchCamera()
				if sizeConnection then
					sizeConnection:Disconnect()
					sizeConnection = nil
				end
				local camera = workspace.CurrentCamera
				if camera then
					sizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(callback)
				end
			end
			watchCamera()
			local cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				watchCamera()
				callback()
			end)
			return function()
				cameraConnection:Disconnect()
				if sizeConnection then
					sizeConnection:Disconnect()
				end
			end
		end,
	}
end

-- The real buttons' edge: GuiService.TopbarInset.Min.X, followed when Roblox changes it.
function SleepMeterUi.guiServiceTopbar(guiService: GuiService): TopbarLike
	return {
		get = function()
			return guiService.TopbarInset.Min.X
		end,
		connect = function(callback: () -> ())
			local connection = guiService:GetPropertyChangedSignal("TopbarInset"):Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
	}
end

return SleepMeterUi
