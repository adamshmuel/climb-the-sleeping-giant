--!strict
-- The phone grab pill follows the egg, or is pinned to a fixed spot when the egg's point is low or off the screen
-- (Task 56; spec Rule 4, Hold to grab). Every test starts from a brand-new player: nothing carried, no grab yet.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
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

local GrabPromptRig = require(script.Parent.GrabPromptRig)

type Rig = GrabPromptRig.Rig
local TOUCH = Enum.ProximityPromptInputType.Touch
local KEYBOARD = Enum.ProximityPromptInputType.Keyboard
local newFakePrompt = GrabPromptRig.newFakePrompt

afterEach(function()
	GrabPromptRig.cleanup()
	MessagesHelpers.cleanUp()
end)

-- Starts the grab prompt in pin mode. `onPinned` is called with true or false each time the pill is pinned or let go.
local function newRig(viewport: Vector2, onPinned: ((pinned: boolean) -> ())?): Rig
	return GrabPromptRig.newRig(viewport, { pin = true, onPinned = onPinned })
end

local function isPinned(rig: Rig): boolean
	local pill = rig.pinnedPill()
	return pill ~= nil and pill.Parent ~= nil and pill.Parent.Name == PINNED_LAYER
end

describe("GrabPrompt: the pinned phone pill", function()
	it("draws the pill on the pinned layer, fully on screen, when the egg's point is low on a touch screen", function()
		local rig = newRig(PHONE)
		rig.show(newFakePrompt(), TOUCH)
		expect(isPinned(rig)).toBe(false)
		rig.frame(LOW)
		expect(isPinned(rig)).toBe(true)
		local pill = rig.pinnedPill() :: TextButton
		expect(pill.AnchorPoint).toBe(Vector2.new(0, 1))
		expect(pill.Position).toBe(UDim2.new(0.5, 0, 1, -12))
		expect(rig.pinnedCalls).toEqual({ true })
	end)

	it("pins when the egg's point is behind the camera", function()
		local rig = newRig(PHONE)
		rig.show(newFakePrompt(), TOUCH)
		rig.frame(nil)
		expect(isPinned(rig)).toBe(true)
	end)

	it("follows the egg again once the point rises past the 84 px line", function()
		local rig = newRig(PHONE)
		rig.show(newFakePrompt(), TOUCH)
		rig.frame(LOW)
		rig.frame(BETWEEN)
		expect(isPinned(rig)).toBe(true) -- between the lines it stays put, so it does not flicker
		rig.frame(ON_UNPIN_LINE)
		expect(isPinned(rig)).toBe(false)
		local pill = rig.pinnedPill() :: TextButton
		expect(pill.AnchorPoint).toBe(Vector2.new(0.5, 0.5))
		expect(pill.Position).toBe(UDim2.fromScale(0.5, 0.5))
		expect(rig.pinnedCalls).toEqual({ true, false })
	end)

	it("never pins on a computer, however low the point is", function()
		local rig = newRig(COMPUTER)
		rig.show(newFakePrompt(), KEYBOARD)
		rig.frame(Vector2.new(640, 700))
		expect(isPinned(rig)).toBe(false)
		expect(#rig.pinnedCalls).toBe(0)
	end)

	it(
		"holds the prompt when the pinned pill is pressed, and the press survives a point that crosses the line",
		function()
			local rig = newRig(PHONE)
			local prompt = newFakePrompt()
			rig.show(prompt, TOUCH)
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
		rig.show(prompt, TOUCH)
		rig.frame(LOW)
		rig.service.PromptHidden:Fire(prompt)
		expect(rig.pinnedPill()).toBe(nil)
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
		rig.show(prompt, TOUCH)
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
		expect(rig.pinnedPill()).toBe(nil)
		expect(messages.pill().Visible).toBe(true)
		-- The carry pill wins the bottom centre, and the footprints tip is over for good after the first grab.
		expect(messages.tip().Visible).toBe(false)
		expect(rig.pinnedCalls).toEqual({ true, false })
	end)
end)
