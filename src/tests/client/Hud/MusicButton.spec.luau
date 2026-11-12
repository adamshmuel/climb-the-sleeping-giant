--!strict
-- The music button (plan 7 Task 16; spec 7 Rule 98). Silent: the topbar, the meter's left edge, the music and the click
-- are fake stand-ins the test drives. All positions are HudTop pixels: 58 px band, Roblox's free space from 164, the
-- first Roblox button's left edge 16 (measured in Play, work/p7/task16-ruling.md).
--
-- The shape the code must have (Step 3 builds it):
--   MusicButton.start(deps) -> { toggle, setMeterLeft, stop }
--   deps.parent     the HudTop screen; the button is a TextButton named "MusicButton" put straight in it
--   deps.topbar     { get: () -> { minX, height }, connect: (callback) -> (() -> ()) } (GuiService.TopbarInset)
--   deps.hudLeft    () -> number, HudTop's AbsolutePosition.X; the button's x is minX minus this
--   deps.music      { setOn: (on) -> () }
--   deps.click      () -> (), plays the row "Music button click" once
--   deps.send       (on: boolean) -> (), tells the server (SetMusic); called once per tap, after music.setOn
--                   (plan 7 Task 17; the real wiring is FireServer in init.client)
--   handle.setMeterLeft(x): the meter's left edge at its biggest, told by SleepMeterUi's onLayout; before it is told,
--     the button assumes the meter is far away.
--   handle.toggle(): what a tap does (the button's Activated calls it).
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

-- The emoji is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local MusicButton = require(Hud.MusicButton)
local Theme = require(Hud.Theme)

local NOTE = "🎵"
local BAND = 58
local MIN_X = 164
local PRECISION = 3

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

type Rig = {
	parent: Folder,
	handle: MusicButton.Handle,
	setOnCalls: { boolean },
	sends: { boolean },
	clicks: () -> number,
	topbarConnections: () -> number,
	moveTopbar: (minX: number, height: number?) -> (),
	button: () -> TextButton,
	note: () -> TextLabel,
	slash: () -> Frame,
}

local function newRig(hudLeft: number?): Rig
	local parent = made(Instance.new("Folder"))
	local topbarEvent = made(Instance.new("BindableEvent"))
	local rect = { minX = MIN_X, height = BAND }
	local connections = 0
	local setOnCalls: { boolean } = {}
	local sends: { boolean } = {}
	local clicks = 0

	local handle = MusicButton.start({
		parent = parent,
		topbar = {
			get = function()
				return rect
			end,
			connect = function(callback: () -> ())
				connections += 1
				local connection = topbarEvent.Event:Connect(callback)
				return function()
					connections -= 1
					connection:Disconnect()
				end
			end,
		},
		hudLeft = function()
			return hudLeft or 0
		end,
		music = {
			setOn = function(on: boolean)
				table.insert(setOnCalls, on)
			end,
		},
		click = function()
			clicks += 1
		end,
		send = function(on: boolean)
			table.insert(sends, on)
		end,
	})
	table.insert(stops, handle.stop)

	local function find<T>(name: string): T
		local button = parent:FindFirstChild("MusicButton") :: Instance
		if name == "MusicButton" then
			return button :: any
		end
		return button:FindFirstChild(name, true) :: any
	end
	return {
		parent = parent,
		handle = handle,
		setOnCalls = setOnCalls,
		sends = sends,
		clicks = function()
			return clicks
		end,
		topbarConnections = function()
			return connections
		end,
		moveTopbar = function(minX: number, height: number?)
			rect = { minX = minX, height = height or rect.height }
			topbarEvent:Fire()
			task.wait()
		end,
		button = function()
			return find("MusicButton")
		end,
		note = function()
			return find("Note")
		end,
		slash = function()
			return find("Slash")
		end,
	}
end

local function sameColor(a: Color3, b: Color3): boolean
	return a == b
end

describe("MusicButton.start: the look", function()
	it("puts a round Ink button named MusicButton on the screen, 44 px, with a 2 px white ring", function()
		local rig = newRig()
		local button = rig.button()
		expect(button.ClassName).toBe("TextButton")
		expect(sameColor(button.BackgroundColor3, Theme.ink)).toBe(true)
		expect(button.BackgroundTransparency).toBeCloseTo(0.08, PRECISION)
		expect(button.Size).toBe(UDim2.fromOffset(44, 44))
		local corner = button:FindFirstChildOfClass("UICorner") :: UICorner
		expect(corner.CornerRadius).toBe(UDim.new(0.5, 0))
		local ring = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(ring.Thickness).toBe(2)
		expect(sameColor(ring.Color, Color3.new(1, 1, 1))).toBe(true)
	end)

	it("shows the 🎵 note at 60 percent of the button's height, no word", function()
		local rig = newRig()
		local note = rig.note()
		expect(note.Text == NOTE).toBe(true)
		expect(math.abs(note.TextSize - 0.6 * 44) <= 1).toBe(true)
		expect(note.TextTransparency).toBeCloseTo(0, PRECISION)
		expect(rig.button().Text).toBe("")
	end)

	it("starts on: the note at full strength and no slash", function()
		local rig = newRig()
		expect(rig.slash().Visible).toBe(false)
		expect(rig.note().TextTransparency).toBeCloseTo(0, PRECISION)
		expect(#rig.setOnCalls).toBe(0)
	end)

	it("has a red slash turned -45 degrees (top right to bottom left) with an Ink outline", function()
		local rig = newRig()
		local slash = rig.slash()
		expect(slash.Rotation).toBe(-45)
		expect(sameColor(slash.BackgroundColor3, Theme.bannerRed)).toBe(true)
		local stroke = slash:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(sameColor(stroke.Color, Theme.ink)).toBe(true)
	end)
end)

describe("MusicButton.start: where it sits", function()
	it("goes where Roblox's free space starts, level with Roblox's buttons, when the meter is far away", function()
		local rig = newRig()
		rig.handle.setMeterLeft(277)
		local position = rig.button().Position
		expect(position.X.Offset).toBe(164)
		expect(position.Y.Offset).toBe(12)
	end)

	it("sits at the edge before the meter has told its left edge", function()
		local rig = newRig()
		expect(rig.button().Position.X.Offset).toBe(164)
		expect(rig.button().Position.Y.Offset).toBe(12)
	end)

	it("takes HudTop's own left edge off the inset's Min.X", function()
		local rig = newRig(10)
		rig.handle.setMeterLeft(277)
		expect(rig.button().Position.X.Offset).toBe(154)
	end)

	it("is placed again when Roblox's buttons change", function()
		local rig = newRig()
		rig.handle.setMeterLeft(1000)
		rig.moveTopbar(250)
		expect(rig.button().Position.X.Offset).toBe(250)
		rig.moveTopbar(164)
		expect(rig.button().Position.X.Offset).toBe(164)
	end)

	it("sizes itself from the band's height when the band changes", function()
		local rig = newRig()
		rig.moveTopbar(MIN_X, 40)
		expect(rig.button().Size).toBe(UDim2.fromOffset(30, 30))
	end)

	it("moves under Roblox's first button when the meter comes within 8 px (the 4.7-inch phone)", function()
		local rig = newRig()
		rig.handle.setMeterLeft(189)
		local position = rig.button().Position
		expect(position.X.Offset).toBe(16)
		expect(position.Y.Offset).toBe(64)
	end)

	it("is placed again when the meter's left edge changes, down and back up", function()
		local rig = newRig()
		rig.handle.setMeterLeft(189)
		expect(rig.button().Position.Y.Offset).toBe(64)
		rig.handle.setMeterLeft(277)
		expect(rig.button().Position.X.Offset).toBe(164)
		expect(rig.button().Position.Y.Offset).toBe(12)
	end)
end)

describe("MusicButton.start: a tap", function()
	it("turns the music off, shows the slash, fades the note and clicks once", function()
		local rig = newRig()
		rig.handle.toggle()
		expect(#rig.setOnCalls).toBe(1)
		expect(rig.setOnCalls[1]).toBe(false)
		expect(rig.slash().Visible).toBe(true)
		expect(rig.note().TextTransparency).toBeCloseTo(0.5, PRECISION)
		expect(rig.clicks()).toBe(1)
	end)

	it("a second tap turns the music back on, hides the slash and clicks again", function()
		local rig = newRig()
		rig.handle.toggle()
		rig.handle.toggle()
		expect(#rig.setOnCalls).toBe(2)
		expect(rig.setOnCalls[2]).toBe(true)
		expect(rig.slash().Visible).toBe(false)
		expect(rig.note().TextTransparency).toBeCloseTo(0, PRECISION)
		expect(rig.clicks()).toBe(2)
	end)

	it("tells the server false on the first tap and true on the second, one message per tap", function()
		local rig = newRig()
		expect(#rig.sends).toBe(0)
		rig.handle.toggle()
		expect(#rig.sends).toBe(1)
		expect(rig.sends[1]).toBe(false)
		rig.handle.toggle()
		expect(#rig.sends).toBe(2)
		expect(rig.sends[2]).toBe(true)
	end)

	it("keeps its off look when it is placed again", function()
		local rig = newRig()
		rig.handle.toggle()
		rig.handle.setMeterLeft(189)
		rig.moveTopbar(250)
		expect(rig.slash().Visible).toBe(true)
		expect(rig.note().TextTransparency).toBeCloseTo(0.5, PRECISION)
	end)
end)

describe("MusicButton.start: stopping", function()
	it("stop takes the button off the screen and lets go of the topbar", function()
		local rig = newRig()
		expect(rig.topbarConnections()).toBe(1)
		rig.handle.stop()
		expect(rig.parent:FindFirstChild("MusicButton")).toBeNil()
		expect(rig.topbarConnections()).toBe(0)
	end)
end)
