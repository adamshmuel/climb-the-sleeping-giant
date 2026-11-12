--!strict
-- The red edges while he hunts (plan 6 Task 20; spec 6 Rule 68, Checks C1 last point, C2, C3). The maths first (pulse, steady,
-- fade, band boxes), then the gui on a stand-in parent with a stand-in frame step.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local HuntView = require(Hud.HuntView)
local RedEdges = require(Hud.RedEdges)
local Ui = require(Hud.Ui)

local TOLERANCE = 0.01
local EDGES = { "Left", "Right", "Top", "Bottom" }
local COMPUTER = Vector2.new(1280, 720)
local PHONE = Vector2.new(844, 390)
local RED = Color3.fromHex("FF3B4E")

local function near(actual: number, expected: number): boolean
	return math.abs(actual - expected) < TOLERANCE
end

-- A stand-in for RenderStepped: it counts the live connections and fires them with a frame time.
type FakeStep = {
	live: number,
	Connect: (self: FakeStep, callback: (dt: number) -> ()) -> { Disconnect: (self: any) -> () },
	fire: (self: FakeStep, dt: number) -> (),
}

local function newStep(): FakeStep
	local callbacks: { [number]: (dt: number) -> () } = {}
	local nextId = 0
	local step: FakeStep = {
		live = 0,
		Connect = function(self: FakeStep, callback: (dt: number) -> ())
			nextId += 1
			local id = nextId
			callbacks[id] = callback
			self.live += 1
			local connection = {}
			function connection.Disconnect(_self: any)
				if callbacks[id] ~= nil then
					callbacks[id] = nil
					self.live -= 1
				end
			end
			return connection
		end,
		fire = function(_self: FakeStep, dt: number)
			for _, callback in table.clone(callbacks) do
				callback(dt)
			end
		end,
	}
	return step
end

type Rig = {
	parent: Folder,
	step: FakeStep,
	clock: { now: number },
	handle: RedEdges.Handle,
	gui: ScreenGui,
	screen: { size: Vector2 }, -- the stand-in screen size; a test can change it
}

local rigs: { Rig } = {}

local function newRig(screenSize: Vector2, reduced: boolean): Rig
	local parent = Instance.new("Folder")
	local step = newStep()
	local clock = { now = 0 }
	local screen = { size = screenSize }
	local handle = RedEdges.new(parent, {
		step = step,
		now = function(): number
			return clock.now
		end,
		screenSize = function(): Vector2
			return screen.size
		end,
		reducedMotion = function(): boolean
			return reduced
		end,
	})
	local gui = parent:FindFirstChild("RedEdges")
	assert(gui ~= nil and gui:IsA("ScreenGui"), "no RedEdges screen")
	local rig: Rig = { parent = parent, step = step, clock = clock, handle = handle, gui = gui, screen = screen }
	table.insert(rigs, rig)
	return rig
end

local function band(rig: Rig, edge: string): Frame
	local frame = rig.gui:FindFirstChild(edge)
	assert(frame ~= nil and frame:IsA("Frame"), `no {edge} band`)
	return frame
end

-- Runs frames for `seconds` of the stand-in clock, 0.05 s at a time.
local function run(rig: Rig, seconds: number)
	local frames = math.round(seconds / 0.05)
	for _ = 1, frames do
		rig.clock.now += 0.05
		rig.step:fire(0.05)
	end
end

afterEach(function()
	for _, rig in rigs do
		rig.handle.destroy()
		rig.parent:Destroy()
	end
	table.clear(rigs)
end)

-- Where a box starts and ends across and down the screen, as fractions of the screen, from its anchor, position and size.
local function span(box: RedEdges.Box): (number, number, number, number)
	local left = box.position.X.Scale - box.anchorPoint.X * box.size.X.Scale
	local top = box.position.Y.Scale - box.anchorPoint.Y * box.size.Y.Scale
	return left, left + box.size.X.Scale, top, top + box.size.Y.Scale
end

describe("RedEdges.pulseTransparency", function()
	it("is full strength at 0 and 1 s, 70 percent at 0.25 s and 40 percent at 0.5 s", function()
		expect(near(RedEdges.pulseTransparency(0), 0)).toBe(true)
		expect(near(RedEdges.pulseTransparency(0.25), 0.3)).toBe(true)
		expect(near(RedEdges.pulseTransparency(0.5), 0.6)).toBe(true)
		expect(near(RedEdges.pulseTransparency(1), 0)).toBe(true)
	end)

	it("repeats once a second", function()
		expect(near(RedEdges.pulseTransparency(3.5), 0.6)).toBe(true)
	end)
end)

describe("RedEdges.steadyTransparency", function()
	it("is 0.3, the 70 percent strength of Reduce Motion", function()
		expect(near(RedEdges.steadyTransparency, 0.3)).toBe(true)
	end)
end)

describe("RedEdges.fade", function()
	it("is fully clear 0.5 s after he stops hunting you, and fully back 0.5 s after you leave the garden", function()
		expect(RedEdges.fade(1, false, 0.5)).toBe(0)
		expect(RedEdges.fade(0, true, 0.5)).toBe(1)
	end)

	it("moves at the same speed both ways and stops at the ends", function()
		expect(near(RedEdges.fade(1, false, 0.25), 0.5)).toBe(true)
		expect(near(RedEdges.fade(0, true, 0.25), 0.5)).toBe(true)
		expect(RedEdges.fade(0.9, true, 1)).toBe(1)
		expect(RedEdges.fade(0.1, false, 1)).toBe(0)
		expect(RedEdges.fade(0, true, 0)).toBe(0)
	end)
end)

describe("RedEdges.bandBox", function()
	it("makes the computer bands full length, 14 percent of the height deep", function()
		for _, edge in EDGES do
			local box = RedEdges.bandBox("Computer", edge)
			local left, right, top, bottom = span(box)
			if edge == "Left" or edge == "Right" then
				expect(box.sizeConstraint).toBe(Enum.SizeConstraint.RelativeYY)
				expect(near(box.size.X.Scale, 0.14)).toBe(true)
				expect(near(top, 0)).toBe(true)
				expect(near(bottom, 1)).toBe(true)
			else
				expect(near(box.size.Y.Scale, 0.14)).toBe(true)
				expect(near(left, 0)).toBe(true)
				expect(near(right, 1)).toBe(true)
			end
		end
	end)

	it("puts each band on its own edge", function()
		local _, _, topOfTop = span(RedEdges.bandBox("Computer", "Top"))
		local _, _, _, bottomOfBottom = span(RedEdges.bandBox("Computer", "Bottom"))
		local leftOfLeft = span(RedEdges.bandBox("Computer", "Left"))
		local right = RedEdges.bandBox("Computer", "Right")
		expect(near(topOfTop, 0)).toBe(true)
		expect(near(bottomOfBottom, 1)).toBe(true)
		expect(near(leftOfLeft, 0)).toBe(true)
		-- The right band hangs from the right edge: its anchor and its position are both at 1.
		expect(near(right.anchorPoint.X, 1)).toBe(true)
		expect(near(right.position.X.Scale, 1)).toBe(true)
	end)

	it(
		"stops the phone side bands 45 percent above the bottom, so the thumbstick and Jump button stay clear",
		function()
			for _, edge in { "Left", "Right" } do
				local box = RedEdges.bandBox("Phone", edge)
				local _, _, top, bottom = span(box)
				expect(near(top, 0)).toBe(true)
				expect(near(bottom, 0.55)).toBe(true)
				expect(near(box.size.X.Scale, 0.14)).toBe(true)
				expect(box.sizeConstraint).toBe(Enum.SizeConstraint.RelativeYY)
			end
		end
	)

	it("covers only 28 to 72 percent of the phone's width with the bottom band", function()
		local box = RedEdges.bandBox("Phone", "Bottom")
		local left, right, _, bottom = span(box)
		expect(near(left, 0.28)).toBe(true)
		expect(near(right, 0.72)).toBe(true)
		expect(near(bottom, 1)).toBe(true)
		expect(near(box.size.Y.Scale, 0.14)).toBe(true)
	end)

	it("keeps the top band full width on a phone", function()
		local left, right = span(RedEdges.bandBox("Phone", "Top"))
		expect(near(left, 0)).toBe(true)
		expect(near(right, 1)).toBe(true)
	end)
end)

local STRIP = 0.0275 -- 1/20 of the phone side band's 0.55 length, and 1/16 of the phone bottom band's 0.44 width
local STRENGTHS = { 0.44, 0.33, 0.22, 0.11 } -- 55% x (1 - k/5), k = 1..4 (designer-fades.md)

local function stripsOf(kind: string): { RedEdges.Strip }
	local all: { RedEdges.Strip } = {}
	for _, edge in EDGES do
		for _, strip in RedEdges.strips(kind, edge) do
			table.insert(all, strip)
		end
	end
	return all
end

describe("RedEdges.strips", function()
	it("makes 16 strips on a phone, 4 on each side band and 8 on the bottom band, and none on a computer", function()
		expect(#stripsOf("Phone")).toBe(16)
		expect(#stripsOf("Computer")).toBe(0)
		expect(#RedEdges.strips("Phone", "Left")).toBe(4)
		expect(#RedEdges.strips("Phone", "Right")).toBe(4)
		expect(#RedEdges.strips("Phone", "Bottom")).toBe(8)
		expect(#RedEdges.strips("Phone", "Top")).toBe(0)
	end)

	it("gives every strip its own name", function()
		local seen: { [string]: boolean } = {}
		for _, strip in stripsOf("Phone") do
			expect(seen[strip.name]).toBe(nil)
			seen[strip.name] = true
		end
	end)

	it(
		"ends the phone side band's body a fifth short, and the strips fill the last fifth, each 1/20 of the length",
		function()
			for _, edge in { "Left", "Right" } do
				local _, _, bodyTop, bodyBottom = span(RedEdges.bodyBox("Phone", edge))
				expect(near(bodyTop, 0)).toBe(true)
				expect(near(bodyBottom, 0.44)).toBe(true)
				local strips = RedEdges.strips("Phone", edge)
				for k, strip in strips do
					local _, _, top, bottom = span(strip.box)
					expect(near(top, 0.44 + (k - 1) * STRIP)).toBe(true)
					expect(near(bottom, 0.44 + k * STRIP)).toBe(true)
					expect(near(strip.box.size.X.Scale, 0.14)).toBe(true)
					expect(strip.box.sizeConstraint).toBe(Enum.SizeConstraint.RelativeYY)
					expect(strip.box.anchorPoint.X).toBe(if edge == "Right" then 1 else 0)
					expect(strip.box.position.X.Scale).toBe(if edge == "Right" then 1 else 0)
				end
				local _, _, _, last = span(strips[4].box)
				expect(near(last, 0.55)).toBe(true) -- the same end as bandBox
			end
		end
	)

	it("splits the phone bottom band: body in the middle half, 4 strips at each end, each 1/16 of the width", function()
		local bodyLeft, bodyRight, _, bodyBottom = span(RedEdges.bodyBox("Phone", "Bottom"))
		expect(near(bodyLeft, 0.39)).toBe(true)
		expect(near(bodyRight, 0.61)).toBe(true)
		expect(near(bodyBottom, 1)).toBe(true)
		local strips = RedEdges.strips("Phone", "Bottom")
		local leftEnd, rightEnd = {}, {}
		for _, strip in strips do
			local left, right, _, bottom = span(strip.box)
			expect(near(right - left, STRIP)).toBe(true)
			expect(near(bottom, 1)).toBe(true)
			expect(near(strip.box.size.Y.Scale, 0.14)).toBe(true)
			expect(strip.box.sizeConstraint).toBe(Enum.SizeConstraint.RelativeXY)
			if right <= bodyLeft + 0.001 then
				table.insert(leftEnd, strip)
			else
				table.insert(rightEnd, strip)
			end
		end
		expect(#leftEnd).toBe(4)
		expect(#rightEnd).toBe(4)
		-- Strip k counts from the body towards the screen end, so strip 1 touches the body and strip 4 is outermost.
		for k = 1, 4 do
			local lLeft, lRight = span(leftEnd[k].box)
			expect(near(lRight, bodyLeft - (k - 1) * STRIP)).toBe(true)
			expect(near(lLeft, bodyLeft - k * STRIP)).toBe(true)
			local rLeft, rRight = span(rightEnd[k].box)
			expect(near(rLeft, bodyRight + (k - 1) * STRIP)).toBe(true)
			expect(near(rRight, bodyRight + k * STRIP)).toBe(true)
		end
		local outerLeft = span(leftEnd[4].box)
		local _, outerRight = span(rightEnd[4].box)
		expect(near(outerLeft, 0.28)).toBe(true) -- the same ends as bandBox
		expect(near(outerRight, 0.72)).toBe(true)
	end)

	it("has strengths of 44, 33, 22 and 11 percent for strips 1 to 4, at both ends", function()
		for _, edge in { "Left", "Right" } do
			for k, strip in RedEdges.strips("Phone", edge) do
				expect(near(strip.strength, STRENGTHS[k])).toBe(true)
			end
		end
		local bottom = RedEdges.strips("Phone", "Bottom")
		for index, strip in bottom do
			expect(near(strip.strength, STRENGTHS[(index - 1) % 4 + 1])).toBe(true)
		end
	end)
end)

describe("RedEdges.new", function()
	it("builds a screen of its own with no insets, drawn below the Hud and HudTop screens", function()
		local rig = newRig(COMPUTER, false)
		local hud = Ui.hud(rig.parent)
		local hudTop = Ui.hudTop(rig.parent)
		expect(rig.gui.ScreenInsets).toBe(Enum.ScreenInsets.None)
		expect(rig.gui.DisplayOrder < hud.DisplayOrder).toBe(true)
		expect(rig.gui.DisplayOrder < hudTop.DisplayOrder).toBe(true)
	end)

	it("makes four red bands, each with one gradient, sized like bodyBox for this screen", function()
		for _, screenSize in { COMPUTER, PHONE } do
			local rig = newRig(screenSize, false)
			local kind = if screenSize == PHONE then "Phone" else "Computer"
			for _, edge in EDGES do
				local frame = band(rig, edge)
				local box = RedEdges.bodyBox(kind, edge)
				expect(frame.BackgroundColor3).toBe(RED)
				expect(frame.Size).toBe(box.size)
				expect(frame.Position).toBe(box.position)
				expect(frame.AnchorPoint).toBe(box.anchorPoint)
				expect(frame.SizeConstraint).toBe(box.sizeConstraint)
				expect(#frame:GetChildren() >= 1).toBe(true)
				local gradients = 0
				for _, child in frame:GetChildren() do
					if child:IsA("UIGradient") then
						gradients += 1
					end
				end
				expect(gradients).toBe(1)
			end
		end
	end)

	it("starts hidden with no frame step connected", function()
		local rig = newRig(COMPUTER, false)
		expect(rig.gui.Enabled).toBe(false)
		expect(rig.step.live).toBe(0)
	end)
end)

local function stripFrames(rig: Rig, kind: string): { Frame }
	local frames: { Frame } = {}
	for _, edge in EDGES do
		for _, strip in RedEdges.strips(kind, edge) do
			local frame = rig.gui:FindFirstChild(strip.name)
			assert(frame ~= nil and frame:IsA("Frame"), `no strip {strip.name}`)
			table.insert(frames, frame)
		end
	end
	return frames
end

local function gradientsOf(frame: Frame): { UIGradient }
	local list: { UIGradient } = {}
	for _, child in frame:GetChildren() do
		if child:IsA("UIGradient") then
			table.insert(list, child)
		end
	end
	return list
end

describe("RedEdges strips on the screen", function()
	it("shows 16 red strips on a phone, each with one gradient at its own strength, placed like strips()", function()
		local rig = newRig(PHONE, false)
		local frames = stripFrames(rig, "Phone")
		expect(#frames).toBe(16)
		local index = 0
		for _, edge in EDGES do
			for _, strip in RedEdges.strips("Phone", edge) do
				index += 1
				local frame = frames[index]
				expect(frame.Visible).toBe(true)
				expect(frame.BackgroundColor3).toBe(RED)
				expect(frame.Position).toBe(strip.box.position)
				expect(frame.Size).toBe(strip.box.size)
				expect(frame.AnchorPoint).toBe(strip.box.anchorPoint)
				expect(frame.SizeConstraint).toBe(strip.box.sizeConstraint)
				local gradients = gradientsOf(frame)
				expect(#gradients).toBe(1)
				-- solid at the screen edge: transparency 1 - strength; clear at the inner edge
				local points = gradients[1].Transparency.Keypoints
				expect(near(points[1].Value, 1 - strip.strength)).toBe(true)
				expect(points[#points].Value).toBe(1)
			end
		end
	end)

	it("runs each strip's gradient the same way as its band", function()
		local rig = newRig(PHONE, false)
		for _, edge in EDGES do
			local bandGradient = gradientsOf(band(rig, edge))[1]
			for _, strip in RedEdges.strips("Phone", edge) do
				local frame = rig.gui:FindFirstChild(strip.name) :: Frame
				expect(gradientsOf(frame)[1].Rotation).toBe(bandGradient.Rotation)
			end
		end
	end)

	it("shows no strips on a computer", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.setEdges(true)
		run(rig, 0.5)
		for _, frame in stripFrames(rig, "Phone") do
			expect(frame.Visible).toBe(false)
		end
		for _, edge in EDGES do
			local frame = band(rig, edge)
			expect(frame.Visible).toBe(true)
		end
	end)

	it("switches the strips with the screen shape each time the edges start to show", function()
		local rig = newRig(COMPUTER, false)
		rig.screen.size = PHONE
		rig.handle.setEdges(true)
		for _, frame in stripFrames(rig, "Phone") do
			expect(frame.Visible).toBe(true)
		end
		for _, edge in EDGES do
			local box = RedEdges.bodyBox("Phone", edge)
			expect(band(rig, edge).Size).toBe(box.size)
		end
		run(rig, 0.5)
		rig.handle.setEdges(false)
		run(rig, 0.5)
		rig.screen.size = COMPUTER
		rig.handle.setEdges(true)
		for _, frame in stripFrames(rig, "Phone") do
			expect(frame.Visible).toBe(false)
		end
		for _, edge in EDGES do
			expect(band(rig, edge).Size).toBe(RedEdges.bodyBox("Computer", edge).size)
		end
	end)

	it("pulses and fades each strip with its band", function()
		local rig = newRig(PHONE, false)
		rig.handle.setEdges(true)
		for _ = 1, 30 do
			run(rig, 0.05)
			for _, edge in EDGES do
				local expected = band(rig, edge).BackgroundTransparency
				for _, strip in RedEdges.strips("Phone", edge) do
					local frame = rig.gui:FindFirstChild(strip.name) :: Frame
					expect(near(frame.BackgroundTransparency, expected)).toBe(true)
				end
			end
		end
		rig.handle.setEdges(false)
		run(rig, 0.5)
		for _, frame in stripFrames(rig, "Phone") do
			expect(frame.BackgroundTransparency).toBe(1)
		end
	end)

	it("never writes to a strip gradient across a pulse", function()
		local rig = newRig(PHONE, false)
		local before: { [Frame]: { Transparency: NumberSequence, Rotation: number, Color: ColorSequence } } = {}
		for _, frame in stripFrames(rig, "Phone") do
			local gradient = gradientsOf(frame)[1]
			before[frame] =
				{ Transparency = gradient.Transparency, Rotation = gradient.Rotation, Color = gradient.Color }
		end
		rig.handle.setEdges(true)
		run(rig, 2)
		rig.handle.setEdges(false)
		run(rig, 0.5)
		for frame, was in before do
			local gradient = gradientsOf(frame)[1]
			expect(gradient.Transparency).toBe(was.Transparency)
			expect(gradient.Rotation).toBe(was.Rotation)
			expect(gradient.Color).toBe(was.Color)
		end
	end)
end)

describe("RedEdges while the edges show", function()
	it("shows on all four sides, pulsing between full and 40 percent strength once a second", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.setEdges(true)
		run(rig, 0.5) -- the fade-in; the clock is at 0.5 s
		expect(rig.gui.Enabled).toBe(true)
		expect(rig.step.live).toBe(1)
		for _, edge in EDGES do
			expect(near(band(rig, edge).BackgroundTransparency, 0.6)).toBe(true)
		end
		run(rig, 0.5) -- the clock is at 1 s
		for _, edge in EDGES do
			expect(near(band(rig, edge).BackgroundTransparency, 0)).toBe(true)
		end
	end)

	it("holds steady at 0.3 at every time with Reduce Motion", function()
		local rig = newRig(COMPUTER, true)
		rig.handle.setEdges(true)
		run(rig, 0.5)
		for _ = 1, 7 do
			run(rig, 0.15)
			for _, edge in EDGES do
				expect(near(band(rig, edge).BackgroundTransparency, 0.3)).toBe(true)
			end
		end
	end)

	it("keeps one frame step connection however many times it is told to show", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.setEdges(true)
		rig.handle.setEdges(true)
		run(rig, 0.5)
		rig.handle.setEdges(true)
		expect(rig.step.live).toBe(1)
	end)

	it("never writes to a gradient across a pulse", function()
		local rig = newRig(COMPUTER, false)
		local before: { [string]: any } = {}
		for _, edge in EDGES do
			local gradient = band(rig, edge):FindFirstChildOfClass("UIGradient")
			assert(gradient ~= nil, `no gradient on {edge}`)
			before[edge] = {
				color = gradient.Color,
				transparency = gradient.Transparency,
				rotation = gradient.Rotation,
				offset = gradient.Offset,
				enabled = gradient.Enabled,
			}
		end
		rig.handle.setEdges(true)
		run(rig, 2) -- two whole pulses
		rig.handle.setEdges(false)
		run(rig, 0.5)
		for _, edge in EDGES do
			local gradient = band(rig, edge):FindFirstChildOfClass("UIGradient")
			assert(gradient ~= nil, `no gradient on {edge}`)
			local was = before[edge]
			expect(gradient.Color).toBe(was.color)
			expect(gradient.Transparency).toBe(was.transparency)
			expect(gradient.Rotation).toBe(was.rotation)
			expect(gradient.Offset).toBe(was.offset)
			expect(gradient.Enabled).toBe(was.enabled)
		end
	end)
end)

describe("RedEdges when the edges go off", function()
	it("is fully clear 0.5 s after the player walks into a garden", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.setEdges(true)
		run(rig, 1)
		rig.handle.setEdges(false) -- the view says edges is false: in a garden
		run(rig, 0.25)
		expect(rig.gui.Enabled).toBe(true)
		for _, edge in EDGES do
			expect(band(rig, edge).BackgroundTransparency > 0.5).toBe(true)
		end
		run(rig, 0.25)
		for _, edge in EDGES do
			expect(near(band(rig, edge).BackgroundTransparency, 1)).toBe(true)
		end
	end)

	it("is fully clear 0.5 s after he lies down, read from the hunt view", function()
		local rig = newRig(COMPUTER, false)
		local awakeOutside =
			HuntView.read({ phase = "Awake", carrying = false, inGarden = 0, plotIndex = 1, floating = false })
		local asleep =
			HuntView.read({ phase = "Asleep", carrying = false, inGarden = 0, plotIndex = 1, floating = false })
		rig.handle.setEdges(awakeOutside.edges)
		run(rig, 1)
		rig.handle.setEdges(asleep.edges)
		run(rig, 0.5)
		for _, edge in EDGES do
			expect(near(band(rig, edge).BackgroundTransparency, 1)).toBe(true)
		end
	end)

	it("hides the screen and disconnects the frame step once the fade is done", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.setEdges(true)
		run(rig, 1)
		expect(rig.step.live).toBe(1)
		rig.handle.setEdges(false)
		run(rig, 0.5)
		expect(rig.gui.Enabled).toBe(false)
		expect(rig.step.live).toBe(0)
	end)

	it("is back at full strength 0.5 s after the player leaves the garden", function()
		local rig = newRig(COMPUTER, true)
		rig.handle.setEdges(true)
		run(rig, 1)
		rig.handle.setEdges(false)
		run(rig, 0.5)
		rig.handle.setEdges(true)
		run(rig, 0.5)
		expect(rig.gui.Enabled).toBe(true)
		for _, edge in EDGES do
			expect(near(band(rig, edge).BackgroundTransparency, 0.3)).toBe(true)
		end
	end)
end)

describe("RedEdges.destroy", function()
	it("removes the screen and the frame step connection, also while the edges show", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.setEdges(true)
		run(rig, 0.5)
		expect(rig.step.live).toBe(1)
		rig.handle.destroy()
		expect(rig.step.live).toBe(0)
		expect(rig.parent:FindFirstChild("RedEdges")).toBe(nil)
	end)

	it("ignores a later setEdges", function()
		local rig = newRig(COMPUTER, false)
		rig.handle.destroy()
		rig.handle.setEdges(true)
		expect(rig.step.live).toBe(0)
	end)
end)
