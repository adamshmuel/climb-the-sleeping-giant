--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

-- The hand is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local GrabPrompt = require(Hud.GrabPrompt)
local Theme = require(Hud.Theme)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal(): any
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

-- A stand-in for a grab prompt on an egg spot's anchor: it counts the presses it is told about.
type FakePrompt = {
	Name: string,
	Parent: Attachment,
	Style: Enum.ProximityPromptStyle,
	HoldDuration: number,
	KeyboardKeyCode: Enum.KeyCode,
	Enabled: boolean,
	holdBegins: number,
	holdEnds: number,
	InputHoldBegin: (self: FakePrompt) -> (),
	InputHoldEnd: (self: FakePrompt) -> (),
}

local function newFakePrompt(name: string): FakePrompt
	local anchor = made(Instance.new("Attachment"))
	local prompt: FakePrompt
	prompt = {
		Name = name,
		Parent = anchor,
		Style = Enum.ProximityPromptStyle.Custom,
		HoldDuration = 1,
		KeyboardKeyCode = Enum.KeyCode.E,
		Enabled = true,
		holdBegins = 0,
		holdEnds = 0,
		InputHoldBegin = function(self: FakePrompt)
			self.holdBegins += 1
		end,
		InputHoldEnd = function(self: FakePrompt)
			self.holdEnds += 1
		end,
	}
	return prompt
end

type Rig = {
	parent: Folder,
	root: Folder,
	attributes: Folder,
	service: any,
	step: any,
	handle: GrabPrompt.Handle,
	clock: { now: number },
	setCarrying: (value: any) -> (),
	setViewport: (size: Vector2) -> (),
	show: (prompt: FakePrompt, inputType: Enum.ProximityPromptInputType?) -> (),
	hide: (prompt: FakePrompt) -> (),
	holdBegin: (prompt: FakePrompt) -> (),
	holdEnd: (prompt: FakePrompt) -> (),
	advance: (seconds: number) -> (),
	prompts: () -> { BillboardGui },
	prompt: () -> BillboardGui,
	pill: () -> TextButton,
	fill: () -> Frame,
	key: () -> TextLabel,
	words: () -> TextLabel,
}

-- Starts the prompt drawing on fake stand-ins for the player's screen, the player, Roblox's prompt events, the frame
-- clock and the screen size, so a test can drive all of them.
local function newRig(viewport: Vector2?): Rig
	local parent = made(Instance.new("Folder"))
	local root = made(Instance.new("Folder"))
	local attributes = made(Instance.new("Folder"))
	local viewportEvent = made(Instance.new("BindableEvent"))
	local viewportSize = viewport or Vector2.new(1280, 720)
	local service = {
		PromptShown = newSignal(),
		PromptHidden = newSignal(),
		PromptButtonHoldBegan = newSignal(),
		PromptButtonHoldEnded = newSignal(),
	}
	local step = newSignal()
	local clock = { now = 100 }

	local handle = GrabPrompt.start({
		parent = parent,
		service = service,
		player = {
			GetAttribute = function(_self: any, name: string): any
				return attributes:GetAttribute(name)
			end,
			GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
				return attributes:GetAttributeChangedSignal(name)
			end,
		},
		root = root,
		step = step,
		now = function()
			return clock.now
		end,
		viewport = {
			get = function()
				return viewportSize
			end,
			connect = function(callback: () -> ())
				local connection = viewportEvent.Event:Connect(callback)
				return function()
					connection:Disconnect()
				end
			end,
		},
	})
	table.insert(stops, handle.stop)

	local function prompts(): { BillboardGui }
		local found: { BillboardGui } = {}
		local layer = parent:FindFirstChild("WorldPrompts")
		if layer then
			for _, child in layer:GetDescendants() do
				if child.Name == "GrabPrompt" and child:IsA("BillboardGui") then
					table.insert(found, child)
				end
			end
		end
		return found
	end
	local function find<T>(name: string): T
		local gui = prompts()[1]
		return gui:FindFirstChild(name, true) :: any
	end
	return {
		parent = parent,
		root = root,
		attributes = attributes,
		service = service,
		step = step,
		handle = handle,
		clock = clock,
		setCarrying = function(value: any)
			attributes:SetAttribute("Carrying", value)
			task.wait()
		end,
		setViewport = function(size: Vector2)
			viewportSize = size
			viewportEvent:Fire()
			task.wait()
		end,
		show = function(prompt: FakePrompt, inputType: Enum.ProximityPromptInputType?)
			service.PromptShown:Fire(prompt, inputType or Enum.ProximityPromptInputType.Keyboard)
		end,
		hide = function(prompt: FakePrompt)
			service.PromptHidden:Fire(prompt)
		end,
		holdBegin = function(prompt: FakePrompt)
			service.PromptButtonHoldBegan:Fire(prompt, nil)
		end,
		holdEnd = function(prompt: FakePrompt)
			service.PromptButtonHoldEnded:Fire(prompt, nil)
		end,
		advance = function(seconds: number)
			clock.now += seconds
			step:Fire(seconds)
		end,
		prompts = prompts,
		prompt = function()
			return prompts()[1]
		end,
		pill = function()
			return find("Pill")
		end,
		fill = function()
			return find("Fill")
		end,
		key = function()
			return find("KeyText")
		end,
		words = function()
			return find("GrabText")
		end,
	}
end

-- Real prompts for the "turned off while carrying" tests: Roblox's own instances, never parented into the place.
local function newRealPrompt(parent: Instance): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = parent
	return prompt
end

describe("GrabPrompt: drawing the prompt", function()
	it("draws nothing at the start", function()
		local rig = newRig()
		expect(#rig.prompts()).toBe(0)
	end)

	it("draws our prompt on the egg spot's anchor when Roblox shows the prompt", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		expect(#rig.prompts()).toBe(1)
		expect(rig.prompt().Adornee).toBe(prompt.Parent)
		expect(rig.prompt().AlwaysOnTop).toBe(true)
	end)

	it("says Hold to Grab, with Grab in gold", function()
		local rig = newRig()
		rig.show(newFakePrompt("Grab"))
		expect(rig.words().ContentText).toBe("Hold to Grab")
		expect(string.find(string.upper(rig.words().Text), "FFE27A", 1, true) ~= nil).toBe(true)
		expect(rig.words().RichText).toBe(true)
	end)

	it("outlines the words in Ink so they stay readable over the gold fill", function()
		local rig = newRig()
		rig.show(newFakePrompt("Grab"))
		local stroke = rig.words():FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.ink).toBe(true)
		expect(stroke.Thickness).toBe(2)
	end)

	it("removes our prompt when Roblox hides the prompt", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.hide(prompt)
		expect(#rig.prompts()).toBe(0)
	end)

	it("draws nothing for a prompt that is not ours (not the Custom style)", function()
		local rig = newRig()
		local prompt = newFakePrompt("Door")
		prompt.Style = Enum.ProximityPromptStyle.Default
		rig.show(prompt)
		expect(#rig.prompts()).toBe(0)
	end)

	it("shows the key E on computers (keyboard input)", function()
		local rig = newRig()
		rig.show(newFakePrompt("Grab"), Enum.ProximityPromptInputType.Keyboard)
		expect(rig.key().Text).toBe("E")
	end)

	it("shows a hand on touch screens", function()
		local rig = newRig(Vector2.new(844, 390))
		rig.show(newFakePrompt("Grab"), Enum.ProximityPromptInputType.Touch)
		expect(rig.key().Text == "👆").toBe(true)
	end)

	it("uses 20 px text and a 38 px key on a 1280x720 computer screen", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.show(newFakePrompt("Grab"))
		expect(rig.words().TextSize).toBe(20)
		expect(rig.key().Parent :: Instance).never.toBeNil()
		expect((rig.key().Parent :: Frame).Size).toBe(UDim2.fromOffset(38, 38))
	end)

	it("uses 16 px text on an 844x390 phone screen, and a smaller key (34 px)", function()
		local rig = newRig(Vector2.new(844, 390))
		rig.show(newFakePrompt("Grab"), Enum.ProximityPromptInputType.Touch)
		expect(rig.words().TextSize).toBe(16)
		expect((rig.key().Parent :: Frame).Size.X.Offset).toBe(34)
	end)

	it("changes size when the screen changes while the prompt is up", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.show(newFakePrompt("Grab"))
		rig.setViewport(Vector2.new(844, 390))
		expect(rig.words().TextSize).toBe(16)
	end)

	it("shows only one prompt at a time: the one Roblox showed last", function()
		local rig = newRig()
		local first = newFakePrompt("GrabOne")
		local second = newFakePrompt("GrabTwo")
		rig.show(first)
		rig.show(second)
		expect(#rig.prompts()).toBe(1)
		expect(rig.prompt().Adornee).toBe(second.Parent)
	end)

	it("keeps the second prompt when Roblox hides the first one afterwards", function()
		local rig = newRig()
		local first = newFakePrompt("GrabOne")
		local second = newFakePrompt("GrabTwo")
		rig.show(first)
		rig.show(second)
		rig.hide(first)
		expect(#rig.prompts()).toBe(1)
		expect(rig.prompt().Adornee).toBe(second.Parent)
	end)

	it("draws the same prompt again when Roblox shows it a second time", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.hide(prompt)
		rig.show(prompt)
		expect(#rig.prompts()).toBe(1)
	end)
end)

describe("GrabPrompt: the fill while the player holds", function()
	it("is empty before the hold starts", function()
		local rig = newRig()
		rig.show(newFakePrompt("Grab"))
		expect(rig.fill().Size.X.Scale).toBe(0)
	end)

	it("grows from empty to full over the hold's one second", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.holdBegin(prompt)
		expect(rig.fill().Size.X.Scale).toBe(0)
		rig.advance(0.25)
		expect(rig.fill().Size.X.Scale).toBeCloseTo(0.25, 5)
		rig.advance(0.25)
		expect(rig.fill().Size.X.Scale).toBeCloseTo(0.5, 5)
		rig.advance(0.5)
		expect(rig.fill().Size.X.Scale).toBeCloseTo(1, 5)
	end)

	it("takes the length of the hold from the prompt", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		prompt.HoldDuration = 2
		rig.show(prompt)
		rig.holdBegin(prompt)
		rig.advance(1)
		expect(rig.fill().Size.X.Scale).toBeCloseTo(0.5, 5)
	end)

	it("stays full if the frames carry on after a second", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.holdBegin(prompt)
		rig.advance(3)
		expect(rig.fill().Size.X.Scale).toBe(1)
	end)

	it("goes back to empty when the hold stops", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.holdBegin(prompt)
		rig.advance(0.6)
		rig.holdEnd(prompt)
		expect(rig.fill().Size.X.Scale).toBe(0)
		rig.advance(0.3)
		expect(rig.fill().Size.X.Scale).toBe(0)
	end)

	it("starts from empty again on the next hold", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.holdBegin(prompt)
		rig.advance(0.6)
		rig.holdEnd(prompt)
		rig.holdBegin(prompt)
		rig.advance(0.2)
		expect(rig.fill().Size.X.Scale).toBeCloseTo(0.2, 5)
	end)

	it("ignores a hold on a prompt that is not the one drawn", function()
		local rig = newRig()
		local shown = newFakePrompt("GrabOne")
		local other = newFakePrompt("GrabTwo")
		rig.show(shown)
		rig.holdBegin(other)
		rig.advance(0.5)
		expect(rig.fill().Size.X.Scale).toBe(0)
	end)

	it("stops following the frames when the hold ends and when the prompt goes", function()
		local rig = newRig()
		local prompt = newFakePrompt("Grab")
		rig.show(prompt)
		rig.holdBegin(prompt)
		expect(rig.step:count()).toBe(1)
		rig.holdEnd(prompt)
		expect(rig.step:count()).toBe(0)
		rig.holdBegin(prompt)
		rig.hide(prompt)
		expect(rig.step:count()).toBe(0)
	end)
end)

describe("GrabPrompt: pressing the prompt (touch screens)", function()
	it("starts the hold when the prompt is pressed", function()
		local rig = newRig(Vector2.new(844, 390))
		local prompt = newFakePrompt("Grab")
		rig.show(prompt, Enum.ProximityPromptInputType.Touch)
		rig.handle.press()
		expect(prompt.holdBegins).toBe(1)
		expect(prompt.holdEnds).toBe(0)
	end)

	it("ends the hold when the finger lifts", function()
		local rig = newRig(Vector2.new(844, 390))
		local prompt = newFakePrompt("Grab")
		rig.show(prompt, Enum.ProximityPromptInputType.Touch)
		rig.handle.press()
		rig.handle.release()
		expect(prompt.holdEnds).toBe(1)
	end)

	it("does nothing when the finger lifts without a press", function()
		local rig = newRig(Vector2.new(844, 390))
		local prompt = newFakePrompt("Grab")
		rig.show(prompt, Enum.ProximityPromptInputType.Touch)
		rig.handle.release()
		expect(prompt.holdEnds).toBe(0)
	end)

	it("does nothing when no prompt is drawn", function()
		local rig = newRig(Vector2.new(844, 390))
		rig.handle.press()
		rig.handle.release()
		expect(#rig.prompts()).toBe(0)
	end)

	it("ends a hold that is still down when the prompt goes away, so it never sticks", function()
		local rig = newRig(Vector2.new(844, 390))
		local prompt = newFakePrompt("Grab")
		rig.show(prompt, Enum.ProximityPromptInputType.Touch)
		rig.handle.press()
		rig.hide(prompt)
		expect(prompt.holdEnds).toBe(1)
	end)

	it("is a button that fills the whole prompt, so the whole prompt can be pressed", function()
		local rig = newRig(Vector2.new(844, 390))
		rig.show(newFakePrompt("Grab"), Enum.ProximityPromptInputType.Touch)
		expect(rig.pill():IsA("TextButton")).toBe(true)
		expect(rig.prompt().Active).toBe(true)
	end)
end)

describe("GrabPrompt: while the player carries an egg", function()
	it("turns every grab prompt off on this device", function()
		local rig = newRig()
		local one = newRealPrompt(rig.root)
		local two = newRealPrompt(rig.root)
		rig.setCarrying("Common")
		expect(one.Enabled).toBe(false)
		expect(two.Enabled).toBe(false)
	end)

	it("turns them back on when the player carries nothing again", function()
		local rig = newRig()
		local one = newRealPrompt(rig.root)
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		expect(one.Enabled).toBe(true)
	end)

	it("turns off prompts that were already there when the player already carried an egg at the start", function()
		local parent = made(Instance.new("Folder"))
		local root = made(Instance.new("Folder"))
		local attributes = made(Instance.new("Folder"))
		attributes:SetAttribute("Carrying", "Rare")
		local prompt = newRealPrompt(root)
		local handle = GrabPrompt.start({
			parent = parent,
			service = {
				PromptShown = newSignal(),
				PromptHidden = newSignal(),
				PromptButtonHoldBegan = newSignal(),
				PromptButtonHoldEnded = newSignal(),
			},
			player = {
				GetAttribute = function(_self: any, name: string): any
					return attributes:GetAttribute(name)
				end,
				GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
					return attributes:GetAttributeChangedSignal(name)
				end,
			},
			root = root,
			step = newSignal(),
			now = function()
				return 0
			end,
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function(_callback: () -> ())
					return function() end
				end,
			},
		})
		table.insert(stops, handle.stop)
		expect(prompt.Enabled).toBe(false)
	end)

	it("turns off a prompt that arrives (streams in) while the player carries an egg", function()
		local rig = newRig()
		rig.setCarrying("Common")
		local late = newRealPrompt(rig.root)
		task.wait()
		expect(late.Enabled).toBe(false)
	end)

	it("takes our prompt away when the player grabs an egg while it is up", function()
		local rig = newRig()
		rig.show(newFakePrompt("Grab"))
		rig.setCarrying("Common")
		expect(#rig.prompts()).toBe(0)
	end)

	it("draws nothing when Roblox shows a prompt while the player carries an egg", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.show(newFakePrompt("Grab"))
		expect(#rig.prompts()).toBe(0)
	end)

	it("draws the prompt again once the player carries nothing", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		rig.show(newFakePrompt("Grab"))
		expect(#rig.prompts()).toBe(1)
	end)
end)

-- A real egg spot as far as the prompt can tell: Model > Base > PromptAnchor > the prompt. `waiting` is the spot's
-- Waiting attribute (nil leaves it unset). It goes into the root, so the prompt is found there.
local function newSpotWithPrompt(root: Instance, waiting: boolean?): (Model, ProximityPrompt)
	local spot = made(Instance.new("Model"))
	spot.Name = "EggSpot"
	spot:SetAttribute("Waiting", waiting)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Parent = spot
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Parent = base
	local prompt = newRealPrompt(anchor)
	spot.Parent = root
	task.wait() -- the prompt is found after the code yields
	return spot, prompt
end

local function setWaiting(spot: Model, waiting: boolean?)
	spot:SetAttribute("Waiting", waiting)
	task.wait()
end

describe("GrabPrompt: spots without an egg", function()
	it("switches the prompt off on a spot that is empty (Waiting is false)", function()
		local rig = newRig()
		local _, prompt = newSpotWithPrompt(rig.root, false)
		expect(prompt.Enabled).toBe(false)
	end)

	it("leaves the prompt on while an egg waits, and while Waiting is not set yet", function()
		local rig = newRig()
		local _, waiting = newSpotWithPrompt(rig.root, true)
		local _, unset = newSpotWithPrompt(rig.root, nil)
		expect(waiting.Enabled).toBe(true)
		expect(unset.Enabled).toBe(true)
	end)

	it("switches the prompt off when the egg is taken", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, true)
		setWaiting(spot, false)
		expect(prompt.Enabled).toBe(false)
	end)

	it("switches the prompt back on when the egg returns", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, false)
		setWaiting(spot, true)
		expect(prompt.Enabled).toBe(true)
	end)

	it("draws nothing when Roblox shows the prompt of an empty spot", function()
		local rig = newRig()
		local _, prompt = newSpotWithPrompt(rig.root, false)
		rig.show(prompt :: any)
		expect(#rig.prompts()).toBe(0)
	end)

	it("takes our prompt away when its spot empties while the prompt is up", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, true)
		rig.show(prompt :: any)
		expect(#rig.prompts()).toBe(1)
		setWaiting(spot, false)
		expect(#rig.prompts()).toBe(0)
	end)

	it("keeps the prompt of another spot when one spot empties", function()
		local rig = newRig()
		local _, other = newSpotWithPrompt(rig.root, true)
		local spot = newSpotWithPrompt(rig.root, true)
		rig.show(other :: any)
		setWaiting(spot, false)
		expect(#rig.prompts()).toBe(1)
		expect(other.Enabled).toBe(true)
	end)

	it("keeps a prompt off when its spot refills while the player carries an egg", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, false)
		rig.setCarrying("Common")
		setWaiting(spot, true)
		expect(prompt.Enabled).toBe(false)
	end)

	it("keeps the prompt of an empty spot off when the player stops carrying", function()
		local rig = newRig()
		local _, emptyPrompt = newSpotWithPrompt(rig.root, false)
		local _, waitingPrompt = newSpotWithPrompt(rig.root, true)
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		expect(emptyPrompt.Enabled).toBe(false)
		expect(waitingPrompt.Enabled).toBe(true)
	end)

	it("switches a prompt on once its spot refills after the player stopped carrying", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, false)
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		setWaiting(spot, true)
		expect(prompt.Enabled).toBe(true)
	end)

	it("stops listening to a spot that leaves the root", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, true)
		spot.Parent = nil
		task.wait()
		setWaiting(spot, false)
		expect(prompt.Enabled).toBe(true)
	end)

	it("turns the prompts back on and stops listening when it is stopped", function()
		local rig = newRig()
		local spot, prompt = newSpotWithPrompt(rig.root, false)
		rig.handle.stop()
		expect(prompt.Enabled).toBe(true)
		setWaiting(spot, true)
		setWaiting(spot, false)
		expect(prompt.Enabled).toBe(true)
	end)
end)

describe("GrabPrompt.start", function()
	it("takes the prompt off, turns the grab prompts back on and stops listening when it is stopped", function()
		local rig = newRig()
		local real = newRealPrompt(rig.root)
		rig.setCarrying("Common")
		local prompt = newFakePrompt("Grab")
		rig.setCarrying(nil)
		rig.show(prompt)
		rig.holdBegin(prompt)
		rig.handle.stop()
		expect(#rig.prompts()).toBe(0)
		expect(rig.service.PromptShown:count()).toBe(0)
		expect(rig.service.PromptHidden:count()).toBe(0)
		expect(rig.service.PromptButtonHoldBegan:count()).toBe(0)
		expect(rig.service.PromptButtonHoldEnded:count()).toBe(0)
		expect(rig.step:count()).toBe(0)
		expect(real.Enabled).toBe(true)
	end)

	it("turns the prompts back on when it is stopped while the player carries an egg", function()
		local rig = newRig()
		local real = newRealPrompt(rig.root)
		rig.setCarrying("Common")
		rig.handle.stop()
		expect(real.Enabled).toBe(true)
	end)

	it("looks like the mockup's prompt: white outline, dark see-through plate", function()
		local rig = newRig()
		rig.show(newFakePrompt("Grab"))
		local pill = rig.pill()
		expect(pill.BackgroundColor3 == Theme.ink).toBe(true)
		expect(pill.BackgroundTransparency).toBeCloseTo(Theme.promptTransparency, 5)
		local stroke = pill:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.white).toBe(true)
		expect(stroke.Thickness).toBe(3)
	end)
end)
