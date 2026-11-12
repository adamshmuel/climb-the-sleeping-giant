--!strict
-- The red edges while he hunts (plan 6 Task 20; spec 6 Rule 68): four bands along the screen edges that pulse while he is
-- awake and the player is outside every garden. The maths here is pure (no Instances, no clock). The numbers are in
-- Theme.redEdge and Layout.redEdges.

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local RedEdges = {}

-- A band's place on the screen. The side bands use RelativeYY, so a depth of 14% of the height is the same on every edge.
export type Box = {
	position: UDim2,
	size: UDim2,
	anchorPoint: Vector2,
	sizeConstraint: Enum.SizeConstraint,
}

-- One strip of a faded phone end: its own name, its place, and its strength at the screen edge (0 to 1). Strip k counts
-- from the band towards the end, so strip 1 is the strongest.
export type Strip = {
	name: string,
	box: Box,
	strength: number,
}

-- Once per frame, with the frame time in seconds (RunService.RenderStepped).
export type StepLike = {
	Connect: (self: StepLike, callback: (dt: number) -> ()) -> { Disconnect: (self: any) -> () },
}

export type Deps = {
	step: StepLike,
	now: () -> number, -- a clock in seconds, for the pulse
	screenSize: () -> Vector2,
	reducedMotion: () -> boolean,
}

export type Handle = {
	setEdges: (shown: boolean) -> (), -- HuntView's `edges`
	destroy: () -> (),
}

-- The band transparency with Reduce Motion on: steady, no pulse.
RedEdges.steadyTransparency = Theme.redEdge.steady

-- The band transparency `seconds` into the pulse: a sine, once a second, from 0 (full strength) to `weakest` (40% strength)
-- and back. 0 at 0 and 1 s, the weakest at 0.5 s.
function RedEdges.pulseTransparency(seconds: number): number
	local turns = seconds / Layout.redEdges.pulseSeconds
	return Theme.redEdge.weakest / 2 * (1 - math.cos(2 * math.pi * turns))
end

-- Moves the fade amount (0 clear, 1 fully shown) towards 1 when `wantShown` and towards 0 when not, over `fadeSeconds`
-- for the whole way.
function RedEdges.fade(current: number, wantShown: boolean, dt: number): number
	local change = dt / Layout.redEdges.fadeSeconds
	if wantShown then
		return math.min(1, current + change)
	end
	return math.max(0, current - change)
end

-- Where one band goes. `kind` is "Computer" (four full-length bands) or "Phone" (side bands stop 45% above the bottom, the
-- bottom band covers only 28% to 72% of the width). `edge` is "Left", "Right", "Top" or "Bottom".
function RedEdges.bandBox(kind: string, edge: string): Box
	local layout = Layout.redEdges
	local phone = kind == "Phone"
	if edge == "Left" or edge == "Right" then
		local height = if phone then layout.phoneSideHeight else 1
		return {
			position = UDim2.fromScale(if edge == "Right" then 1 else 0, 0),
			size = UDim2.fromScale(layout.depth, height),
			anchorPoint = Vector2.new(if edge == "Right" then 1 else 0, 0),
			sizeConstraint = Enum.SizeConstraint.RelativeYY,
		}
	elseif edge == "Top" then
		return {
			position = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, layout.depth),
			anchorPoint = Vector2.new(0, 0),
			sizeConstraint = Enum.SizeConstraint.RelativeXY,
		}
	elseif edge == "Bottom" then
		local from = if phone then layout.phoneBottomFrom else 0
		local to = if phone then layout.phoneBottomTo else 1
		return {
			position = UDim2.fromScale(from, 1),
			size = UDim2.fromScale(to - from, layout.depth),
			anchorPoint = Vector2.new(0, 1),
			sizeConstraint = Enum.SizeConstraint.RelativeXY,
		}
	end
	error(`RedEdges.bandBox: unknown edge {edge}`)
end

-- Where one band's solid body goes. On a computer, and for the top band, it is the whole band (`bandBox`). On a phone the
-- side bands stop short by the faded fifth, and the bottom band keeps only its middle half; the strips fill the rest.
function RedEdges.bodyBox(kind: string, edge: string): Box
	local box = RedEdges.bandBox(kind, edge)
	if kind ~= "Phone" then
		return box
	end
	local layout = Layout.redEdges
	if edge == "Left" or edge == "Right" then
		local height = layout.phoneSideHeight * (1 - layout.sideFadeShare)
		return {
			position = box.position,
			size = UDim2.fromScale(layout.depth, height),
			anchorPoint = box.anchorPoint,
			sizeConstraint = box.sizeConstraint,
		}
	elseif edge == "Bottom" then
		local width = layout.phoneBottomTo - layout.phoneBottomFrom
		local from = layout.phoneBottomFrom + width * layout.bottomFadeShare
		local to = layout.phoneBottomTo - width * layout.bottomFadeShare
		return {
			position = UDim2.fromScale(from, 1),
			size = UDim2.fromScale(to - from, layout.depth),
			anchorPoint = box.anchorPoint,
			sizeConstraint = box.sizeConstraint,
		}
	end
	return box
end

-- The strength of strip `k` (1 to stripCount) at the screen edge: the band's own strength times (1 - k / 5).
function RedEdges.stripStrength(k: number): number
	return Theme.redEdge.solid * (1 - k / (Layout.redEdges.stripCount + 1))
end

-- The strips of one band's faded ends: none on a computer or for the top band; on a phone 4 below each side band and
-- 4 at each end of the bottom band (8). Their names are `<edge>_Strip<k>`, the bottom band's with an `L` or `R` first.
function RedEdges.strips(kind: string, edge: string): { Strip }
	local list: { Strip } = {}
	if kind ~= "Phone" then
		return list
	end
	local layout = Layout.redEdges
	local count = layout.stripCount
	if edge == "Left" or edge == "Right" then
		local full = RedEdges.bandBox(kind, edge)
		local body = RedEdges.bodyBox(kind, edge)
		local each = (full.size.Y.Scale - body.size.Y.Scale) / count
		for k = 1, count do
			table.insert(list, {
				name = `{edge}_Strip{k}`,
				box = {
					position = UDim2.fromScale(body.position.X.Scale, body.size.Y.Scale + (k - 1) * each),
					size = UDim2.fromScale(layout.depth, each),
					anchorPoint = body.anchorPoint,
					sizeConstraint = body.sizeConstraint,
				},
				strength = RedEdges.stripStrength(k),
			})
		end
	elseif edge == "Bottom" then
		local body = RedEdges.bodyBox(kind, edge)
		local bodyLeft = body.position.X.Scale
		local bodyRight = bodyLeft + body.size.X.Scale
		local each = (bodyLeft - layout.phoneBottomFrom) / count
		for _, end_ in { "L", "R" } do
			for k = 1, count do
				local left = if end_ == "L" then bodyLeft - k * each else bodyRight + (k - 1) * each
				table.insert(list, {
					name = `Bottom_Strip{end_}{k}`,
					box = {
						position = UDim2.fromScale(left, 1),
						size = UDim2.fromScale(each, layout.depth),
						anchorPoint = body.anchorPoint,
						sizeConstraint = body.sizeConstraint,
					},
					strength = RedEdges.stripStrength(k),
				})
			end
		end
	end
	return list
end

local EDGES = { "Left", "Right", "Top", "Bottom" }
-- Which way each band's gradient runs, so the solid end is on the screen edge. A UIGradient at rotation 0 runs left to
-- right, 90 top to bottom.
local GRADIENT_ROTATION: { [string]: number } = { Left = 0, Right = 180, Top = 90, Bottom = 270 }
-- Below this the fade counts as finished: the screen goes off and the frame step is disconnected.
local FADE_DONE = 0.001

-- One red gradient per frame, set once here and never changed: `strength` at the screen edge, clear at the inner edge.
local function makeGradient(edge: string, strength: number): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - strength),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = GRADIENT_ROTATION[edge]
	return gradient
end

function RedEdges.new(parent: Instance, deps: Deps): Handle
	local gui = Instance.new("ScreenGui")
	gui.Name = "RedEdges"
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = Layout.redEdges.displayOrder
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	-- `bands` is every frame whose transparency is written each frame: the four bands and the 16 phone strips.
	local bands: { Frame } = {}
	local function newFrame(name: string, edge: string, strength: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = Theme.redEdge.color
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Active = false
		makeGradient(edge, strength).Parent = frame
		frame.Parent = gui
		table.insert(bands, frame)
		return frame
	end
	local bandFrames: { [string]: Frame } = {}
	local stripFrames: { [string]: Frame } = {}
	local stripList: { Strip } = {}
	for _, edge in EDGES do
		bandFrames[edge] = newFrame(edge, edge, Theme.redEdge.solid)
		for _, strip in RedEdges.strips("Phone", edge) do
			stripFrames[strip.name] = newFrame(strip.name, edge, strip.strength)
			table.insert(stripList, strip)
		end
	end
	gui.Parent = parent

	-- The bands' places depend on the screen shape; they are read again each time the edges start to show.
	local function place()
		local kind = if Layout.isPhone(deps.screenSize()) then "Phone" else "Computer"
		local function put(frame: Frame, box: Box)
			frame.Position = box.position
			frame.Size = box.size
			frame.AnchorPoint = box.anchorPoint
			frame.SizeConstraint = box.sizeConstraint
		end
		for edge, frame in bandFrames do
			put(frame, RedEdges.bodyBox(kind, edge))
		end
		for _, strip in stripList do
			local frame = stripFrames[strip.name]
			put(frame, strip.box)
			frame.Visible = kind == "Phone"
		end
	end
	place()

	local wanted = false
	local fade = 0
	local destroyed = false
	local connection: { Disconnect: (self: any) -> () }? = nil

	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	local function onFrame(dt: number)
		fade = RedEdges.fade(fade, wanted, dt)
		if not wanted and fade <= FADE_DONE then
			fade = 0
			for _, frame in bands do
				frame.BackgroundTransparency = 1
			end
			gui.Enabled = false
			stop()
			return
		end
		local pulse = if deps.reducedMotion()
			then RedEdges.steadyTransparency
			else RedEdges.pulseTransparency(deps.now())
		local transparency = 1 - (1 - pulse) * fade
		for _, frame in bands do
			frame.BackgroundTransparency = transparency
		end
	end

	local function setEdges(shown: boolean)
		if destroyed then
			return
		end
		wanted = shown
		if shown and connection == nil then
			place()
			gui.Enabled = true
			connection = deps.step:Connect(onFrame)
		end
	end

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		stop()
		gui:Destroy()
	end

	return { setEdges = setEdges, destroy = destroy }
end

return RedEdges
