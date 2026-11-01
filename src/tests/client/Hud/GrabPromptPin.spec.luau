--!strict
-- The phone grab pill follows the egg, or is pinned to a fixed spot when the egg's point is low or off the screen
-- (Task 56; spec Rule 4, Hold to grab). Every test starts from a brand-new player: nothing carried, no grab yet.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local GrabPrompt = require(Hud.GrabPrompt)
local Messages = require(Hud.Messages)
local MessagesHelpers = require(script.Parent.Messages.Helpers)
local Layout = require(Hud.Layout)

-- The iPhone 14 play area: a phone screen (short side under 500).
local PHONE = Vector2.new(749, 388)
local COMPUTER = Vector2.new(1280, 720)
-- The egg's point on the screen. The pill is 44 px tall, so its bottom is 22 px below the point.
local HALF_PILL = 22
local UNPIN_LINE_Y = PHONE.Y - Layout.pin.unpinLine -- 304: at or above it, the pill follows the egg again
local PIN_LINE_Y = PHONE.Y - Layout.pin.pinLine -- 324: below it, the pill pins
local HIGH = Vector2.new(300, 200) -- bottom 222: well above the 84 px line
local LOW = Vector2.new(300, 380) -- bottom 402: below the screen
local BETWEEN = Vector2.new(300, (UNPIN_LINE_Y + PIN_LINE_Y) / 2 - HALF_PILL) -- bottom 314: between the two lines
local ON_UNPIN_LINE = Vector2.new(300, UNPIN_LINE_Y - HALF_PILL) -- bottom 304: exactly on the 84 px line
local PINNED_LAYER = "PinnedPrompt"

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
	MessagesHelpers.cleanUp()
end)

local newSignal = MessagesHelpers.newSignal

type FakePrompt = {
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

local function newFakePrompt(): FakePrompt
	return {
		Parent = made(Instance.new("Attachment")),
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
end

type Rig = {
	parent: Folder,
	attributes: Folder,
	service: any,
	step: any,
	handle: GrabPrompt.Handle,
	point: { value: Vector2? },
	pinnedCalls: { boolean },
	show: (prompt: FakePrompt, touch: boolean) -> (),
	frame: (point: Vector2?) -> (),
	pill: () -> TextButton?,
}

-- Starts the grab prompt on stand-ins for the player's screen, the prompt events, the frame signal and the egg's
-- point on the screen. `onPinned` is called with true or false each time the pill is pinned or let go.
local function newRig(viewport: Vector2, onPinned: ((pinned: boolean) -> ())?): Rig
	local parent = made(Instance.new("Folder"))
	local root = made(Instance.new("Folder"))
	local attributes = made(Instance.new("Folder"))
	local service = {
		PromptShown = newSignal(),
		PromptHidden = newSignal(),
		PromptButtonHoldBegan = newSignal(),
		PromptButtonHoldEnded = newSignal(),
	}
	local step = newSignal()
	local point: { value: Vector2? } = { value = HIGH }
	local pinnedCalls: { boolean } = {}
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
			return 100
		end,
		viewport = {
			get = function()
				return viewport
			end,
			connect = function(_callback: () -> ())
				return function() end
			end,
		},
		project = function(_adornee: Instance): Vector2?
			return point.value
		end,
		onPinned = function(pinned: boolean)
			table.insert(pinnedCalls, pinned)
			if onPinned then
				onPinned(pinned)
			end
		end,
	})
	table.insert(stops, handle.stop)
	local function pill(): TextButton?
		local layers = { parent:FindFirstChild("WorldPrompts"), parent:FindFirstChild(PINNED_LAYER) }
		for _, layer in layers do
			local found = layer:FindFirstChild("Pill", true)
			if found then
				return found :: TextButton
			end
		end
		return nil
	end
	return {
		parent = parent,
		attributes = attributes,
		service = service,
		step = step,
		handle = handle,
		point = point,
		pinnedCalls = pinnedCalls,
		show = function(prompt: FakePrompt, touch: boolean)
			local inputType = if touch
				then Enum.ProximityPromptInputType.Touch
				else Enum.ProximityPromptInputType.Keyboard
			service.PromptShown:Fire(prompt, inputType)
		end,
		frame = function(newPoint: Vector2?)
			point.value = newPoint
			step:Fire()
		end,
		pill = pill,
	}
end

local function isPinned(rig: Rig): boolean
	local pill = rig.pill()
	return pill ~= nil and pill.Parent ~= nil and pill.Parent.Name == PINNED_LAYER
end

describe("GrabPrompt: the pinned phone pill", function()
	it("draws the pill on the pinned layer, fully on screen, when the egg's point is low on a touch screen", function()
		local rig = newRig(PHONE)
		rig.show(newFakePrompt(), true)
		expect(isPinned(rig)).toBe(false)
		rig.frame(LOW)
		expect(isPinned(rig)).toBe(true)
		local pill = rig.pill() :: TextButton
		expect(pill.AnchorPoint).toBe(Vector2.new(0, 1))
		expect(pill.Position).toBe(UDim2.new(0.5, 0, 1, -12))
		expect(rig.pinnedCalls).toEqual({ true })
	end)

	it("pins when the egg's point is behind the camera", function()
		local rig = newRig(PHONE)
		rig.show(newFakePrompt(), true)
		rig.frame(nil)
		expect(isPinned(rig)).toBe(true)
	end)

	it("follows the egg again once the point rises past the 84 px line", function()
		local rig = newRig(PHONE)
		rig.show(newFakePrompt(), true)
		rig.frame(LOW)
		rig.frame(BETWEEN)
		expect(isPinned(rig)).toBe(true) -- between the lines it stays put, so it does not flicker
		rig.frame(ON_UNPIN_LINE)
		expect(isPinned(rig)).toBe(false)
		local pill = rig.pill() :: TextButton
		expect(pill.AnchorPoint).toBe(Vector2.new(0.5, 0.5))
		expect(pill.Position).toBe(UDim2.fromScale(0.5, 0.5))
		expect(rig.pinnedCalls).toEqual({ true, false })
	end)

	it("never pins on a computer, however low the point is", function()
		local rig = newRig(COMPUTER)
		rig.show(newFakePrompt(), false)
		rig.frame(Vector2.new(640, 700))
		expect(isPinned(rig)).toBe(false)
		expect(#rig.pinnedCalls).toBe(0)
	end)

	it(
		"holds the prompt when the pinned pill is pressed, and the press survives a point that crosses the line",
		function()
			local rig = newRig(PHONE)
			local prompt = newFakePrompt()
			rig.show(prompt, true)
			rig.frame(LOW)
			rig.handle.press()
			expect(prompt.holdBegins).toBe(1)
			rig.frame(HIGH) -- the point rises well past the line, but a finger is on the pill
			expect(isPinned(rig)).toBe(true)
			expect(prompt.holdEnds).toBe(0)
			rig.handle.release()
			expect(prompt.holdEnds).toBe(1)
			rig.frame(HIGH) -- after the release it may switch
			expect(isPinned(rig)).toBe(false)
		end
	)

	it("lets go of the pin when the prompt goes away", function()
		local rig = newRig(PHONE)
		local prompt = newFakePrompt()
		rig.show(prompt, true)
		rig.frame(LOW)
		rig.service.PromptHidden:Fire(prompt)
		expect(rig.pill()).toBe(nil)
		expect(rig.pinnedCalls).toEqual({ true, false })
	end)
end)

describe("GrabPrompt and the messages: a whole short session on a phone", function()
	it("pins the pill and hides the tip on the egg, then the carry pill takes over after the grab", function()
		local messages = MessagesHelpers.newRig(PHONE)
		local rig = newRig(PHONE, messages.handle.setPillPinned)
		local prompt = newFakePrompt()

		-- A brand-new player: the footprints tip shows, nothing is carried.
		expect(messages.tip().Visible).toBe(true)
		expect(messages.tipText().Text).toBe(Messages.footprintsText)

		-- Walks up to the egg: the pill follows it, the tip stays.
		rig.show(prompt, true)
		rig.frame(HIGH)
		expect(isPinned(rig)).toBe(false)
		expect(messages.tip().Visible).toBe(true)

		-- Stands on the egg: the point drops, the pill pins and the tip hides.
		rig.frame(LOW)
		expect(isPinned(rig)).toBe(true)
		expect(messages.tip().Visible).toBe(false)

		-- Holds the pill and the server says the egg is theirs: the pill is gone and the carry pill shows.
		rig.handle.press()
		expect(prompt.holdBegins).toBe(1)
		rig.attributes:SetAttribute("Carrying", "Common")
		messages.setCarrying("Common")
		expect(rig.pill()).toBe(nil)
		expect(messages.pill().Visible).toBe(true)
		-- The carry pill wins the bottom centre, and the footprints tip is over for good after the first grab.
		expect(messages.tip().Visible).toBe(false)
		expect(rig.pinnedCalls).toEqual({ true, false })
	end)
end)
