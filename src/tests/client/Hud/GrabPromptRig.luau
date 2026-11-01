--!strict
-- The fake-prompt test rig shared by the GrabPrompt specs (not a spec itself): stand-ins for the player's screen, the
-- player, Roblox's prompt events, the frame clock, the screen size and the egg's point on the screen, so a test can drive
-- all of them. Every spec calls `cleanup()` in `afterEach`.
local StarterPlayer = game:GetService("StarterPlayer")

local GrabPrompt = require(StarterPlayer.StarterPlayerScripts.Client.Hud.GrabPrompt)

local PINNED_LAYER = "PinnedPrompt"
-- Where the egg's point starts in pin mode: high on the screen, so the pill follows the egg.
local START_POINT = Vector2.new(300, 200)

local GrabPromptRig = {}

-- A stand-in for a grab prompt on an egg spot's anchor: it counts the presses it is told about.
export type FakePrompt = {
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

export type Rig = {
	parent: Folder,
	root: Folder,
	attributes: Folder,
	service: any,
	step: any,
	handle: GrabPrompt.Handle,
	clock: { now: number },
	-- Pin mode only (options.pin): the egg's point on the screen, and every pinned or let-go call, in order.
	point: { value: Vector2? },
	pinnedCalls: { boolean },
	setCarrying: (value: any) -> (),
	setViewport: (size: Vector2) -> (),
	show: (prompt: FakePrompt, inputType: Enum.ProximityPromptInputType?) -> (),
	hide: (prompt: FakePrompt) -> (),
	holdBegin: (prompt: FakePrompt) -> (),
	holdEnd: (prompt: FakePrompt) -> (),
	advance: (seconds: number) -> (),
	-- Pin mode: moves the egg's point and fires one frame.
	frame: (point: Vector2?) -> (),
	prompts: () -> { BillboardGui },
	prompt: () -> BillboardGui,
	pill: () -> TextButton,
	-- The pill wherever it is now: next to the egg or on the pinned layer. Nil if there is none.
	pinnedPill: () -> TextButton?,
	fill: () -> Frame,
	key: () -> TextLabel,
	words: () -> TextLabel,
}

export type Options = {
	-- Wires the egg's point and the pin calls, like the real phone screen. Left out, the pill never pins.
	pin: boolean?,
	-- Called with true or false each time the pill is pinned or let go (pin mode).
	onPinned: ((pinned: boolean) -> ())?,
}

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

function GrabPromptRig.made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end
local made = GrabPromptRig.made

-- Stops every grab prompt a rig started and destroys everything the rig made.
function GrabPromptRig.cleanup()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end

-- Runs `stop` when `cleanup()` is called, for a prompt a test started itself.
function GrabPromptRig.onCleanup(stop: () -> ())
	table.insert(stops, stop)
end

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
function GrabPromptRig.newSignal(): any
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
local newSignal = GrabPromptRig.newSignal

function GrabPromptRig.newFakePrompt(name: string?): FakePrompt
	local anchor = made(Instance.new("Attachment"))
	local prompt: FakePrompt
	prompt = {
		Name = name or "Grab",
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

-- Starts the grab prompt on the stand-ins. `viewport` is the screen size (a computer's, if left out).
function GrabPromptRig.newRig(viewport: Vector2?, options: Options?): Rig
	local pinMode = options ~= nil and options.pin == true
	local onPinned = if options then options.onPinned else nil
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
	local point: { value: Vector2? } = { value = START_POINT }
	local pinnedCalls: { boolean } = {}

	local deps: GrabPrompt.Deps = {
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
		project = if pinMode
			then function(_adornee: Instance): Vector2?
				return point.value
			end
			else nil,
		onPinned = if pinMode
			then function(pinned: boolean)
				table.insert(pinnedCalls, pinned)
				if onPinned then
					onPinned(pinned)
				end
			end
			else nil,
	}
	local handle = GrabPrompt.start(deps)
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
	local function pinnedPill(): TextButton?
		for _, layerName in { "WorldPrompts", PINNED_LAYER } do
			local layer = parent:FindFirstChild(layerName)
			local found = if layer then layer:FindFirstChild("Pill", true) else nil
			if found then
				return found :: TextButton
			end
		end
		return nil
	end
	return {
		parent = parent,
		root = root,
		attributes = attributes,
		service = service,
		step = step,
		handle = handle,
		clock = clock,
		point = point,
		pinnedCalls = pinnedCalls,
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
		frame = function(newPoint: Vector2?)
			point.value = newPoint
			step:Fire()
		end,
		prompts = prompts,
		prompt = function()
			return prompts()[1]
		end,
		pill = function()
			return find("Pill")
		end,
		pinnedPill = pinnedPill,
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

return GrabPromptRig
