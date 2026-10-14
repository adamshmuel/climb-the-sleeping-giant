--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

-- Faces are compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local SleepMeterUi = require(Hud.SleepMeterUi)
local Theme = require(Hud.Theme)
local Ui = require(Hud.Ui)

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

type Rig = {
	parent: Folder,
	giantState: Folder,
	set: (name: string, value: any) -> (),
	fireWarning: (mark: number) -> (),
	setViewport: (size: Vector2) -> (),
	setTopbarEdge: (x: number) -> (),
	setNow: (time: number) -> (),
	stop: () -> (),
	hud: () -> ScreenGui,
	meter: () -> Frame,
	label: () -> TextLabel,
	face: () -> TextLabel,
	panel: () -> Frame,
	fill: () -> Frame,
	lock: () -> TextLabel,
	pulse: () -> UIScale,
}

-- Starts the meter on fake stand-ins for the player's screen, the giant's state, the Warning remote and the
-- screen size, so a test can drive all of them.
local function newRig(viewport: Vector2?, now: number?, topbarEdge: number?): Rig
	local parent = made(Instance.new("Folder"))
	local giantState = made(Instance.new("Folder"))
	giantState:SetAttribute("Meter", 0)
	giantState:SetAttribute("Phase", "Asleep")
	local warningEvent = made(Instance.new("BindableEvent"))
	local viewportEvent = made(Instance.new("BindableEvent"))
	local topbarEvent = made(Instance.new("BindableEvent"))
	local currentTopbarEdge = topbarEdge or 164
	local viewportSize = viewport or Vector2.new(1280, 720)
	local currentTime = now or 0

	local stop = SleepMeterUi.start({
		parent = parent,
		giantState = giantState,
		warning = { OnClientEvent = warningEvent.Event },
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
		topbarInset = {
			get = function()
				return currentTopbarEdge
			end,
			connect = function(callback: () -> ())
				local connection = topbarEvent.Event:Connect(callback)
				return function()
					connection:Disconnect()
				end
			end,
		},
		now = function()
			return currentTime
		end,
	})
	table.insert(stops, stop)

	local function find<T>(name: string): T
		local hud = parent:FindFirstChild("HudTop") :: Instance
		return hud:FindFirstChild(name, true) :: any
	end
	return {
		parent = parent,
		giantState = giantState,
		set = function(name: string, value: any)
			giantState:SetAttribute(name, value)
			task.wait() -- attribute changes reach listeners a moment after they are set
		end,
		fireWarning = function(mark: number)
			warningEvent:Fire(mark)
		end,
		setViewport = function(size: Vector2)
			viewportSize = size
			viewportEvent:Fire()
			task.wait()
		end,
		setTopbarEdge = function(x: number)
			currentTopbarEdge = x
			topbarEvent:Fire()
			task.wait()
		end,
		setNow = function(time: number)
			currentTime = time
		end,
		stop = stop,
		hud = function()
			return parent:FindFirstChild("HudTop") :: ScreenGui
		end,
		meter = function()
			return find("SleepMeter")
		end,
		label = function()
			return find("Label")
		end,
		face = function()
			return find("Face")
		end,
		panel = function()
			return find("Panel")
		end,
		fill = function()
			return find("Fill")
		end,
		lock = function()
			return find("Lock")
		end,
		pulse = function()
			return find("Pulse")
		end,
	}
end

describe("SleepMeterUi.start: the screen", function()
	it("puts the meter on HudTop, which survives respawn and only avoids the phone notch", function()
		local rig = newRig()
		local hudTop = rig.hud()
		expect(hudTop).never.toBeNil()
		expect(hudTop.ClassName).toBe("ScreenGui")
		expect(hudTop.ResetOnSpawn).toBe(false)
		expect(hudTop.ScreenInsets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
		expect(rig.meter().Parent).toBe(hudTop)
	end)

	it("leaves Hud, which keeps clear of Roblox's buttons, for the other screen parts", function()
		local rig = newRig()
		expect(rig.parent:FindFirstChild("Hud")).toBeNil()
		expect(Ui.hud(rig.parent).ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
	end)

	it("puts the meter at the top centre", function()
		local meter = newRig().meter()
		expect(meter.AnchorPoint).toBe(Vector2.new(0.5, 0))
		expect(meter.Position.X.Scale).toBe(0.5)
		expect(meter.Position.X.Offset).toBe(0)
	end)

	it("makes no second HudTop or meter when started again on the same screen", function()
		local rig = newRig()
		local stopSecond = SleepMeterUi.start({
			parent = rig.parent,
			giantState = rig.giantState,
			warning = { OnClientEvent = made(Instance.new("BindableEvent")).Event },
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function()
					return function() end
				end,
			},
			topbarInset = {
				get = function()
					return 164
				end,
				connect = function()
					return function() end
				end,
			},
			now = function()
				return 0
			end,
		})
		table.insert(stops, stopSecond)
		local huds = 0
		local meters = 0
		for _, child in rig.parent:GetChildren() do
			if child.Name == "HudTop" then
				huds += 1
			end
		end
		for _, descendant in rig.parent:GetDescendants() do
			if descendant.Name == "SleepMeter" then
				meters += 1
			end
		end
		expect(huds).toBe(1)
		expect(meters).toBe(1)
	end)

	it("takes the meter off the screen when stopped, and leaves HudTop", function()
		local rig = newRig()
		rig.stop()
		expect(rig.hud()).never.toBeNil()
		expect(rig.hud():FindFirstChild("SleepMeter")).toBeNil()
	end)
end)

describe("SleepMeterUi.start: what the meter shows", function()
	it("starts as 'Giant is sleeping' with 😴", function()
		local rig = newRig()
		expect(rig.label().Text).toBe("Giant is sleeping")
		expect(rig.face().Text == "😴").toBe(true)
		expect(rig.lock().Visible).toBe(false)
	end)

	it("fills the bar as the meter rises", function()
		local rig = newRig()
		rig.set("Meter", 40)
		expect(rig.fill().Size.X.Scale).toBeCloseTo(0.4, 3)
	end)

	it("shows 😔 and 'He's stirring... tiptoe!' at 60", function()
		local rig = newRig()
		rig.set("Meter", 60)
		expect(rig.face().Text == "😔").toBe(true)
		expect(rig.label().Text).toBe("He's stirring... tiptoe!")
	end)

	it("turns the bar solid yellow at 60", function()
		local rig = newRig()
		rig.set("Meter", 60)
		expect(rig.fill().BackgroundColor3).toBe(Theme.bars.Yellow.color)
	end)

	it("shows 😟, the peach panel and orange words at 85", function()
		local rig = newRig()
		rig.set("Meter", 85)
		expect(rig.face().Text == "😟").toBe(true)
		expect(rig.label().Text).toBe("He's waking up! Tiptoe!")
		expect(rig.panel().BackgroundColor3).toBe(Theme.rows.WakingUp.panel)
		expect(rig.label().TextColor3).toBe(Theme.rows.WakingUp.label)
	end)

	it("goes back to the cream panel when the meter falls below 85", function()
		local rig = newRig()
		rig.set("Meter", 90)
		rig.set("Meter", 30)
		expect(rig.panel().BackgroundColor3).toBe(Theme.rows.Sleeping.panel)
		expect(rig.label().Text).toBe("Giant is sleeping")
	end)

	it("shows the awake row with the time left from the server's clock", function()
		local rig = newRig(nil, 100)
		rig.set("PhaseEndsAt", 115)
		rig.set("Phase", "Awake")
		expect(rig.face().Text == "😠").toBe(true)
		expect(rig.label().Text).toBe("AWAKE! Back to sleep in 0:15")
	end)

	it("shows Heavy Sleep with the lock and the full bar", function()
		local rig = newRig(nil, 100)
		rig.set("PhaseEndsAt", 145)
		rig.set("Phase", "HeavySleep")
		expect(rig.label().Text).toBe("Heavy Sleep · safe for 0:45")
		expect(rig.lock().Visible).toBe(true)
		expect(rig.fill().Size.X.Scale).toBe(1)
	end)

	it("shows the slanted stripes only in Heavy Sleep", function()
		local rig = newRig(nil, 100)
		local stripes = rig.hud():FindFirstChild("Stripes", true) :: Frame
		expect(stripes.Visible).toBe(false)
		rig.set("PhaseEndsAt", 145)
		rig.set("Phase", "HeavySleep")
		expect(stripes.Visible).toBe(true)
		expect(#stripes:GetChildren() > 3).toBe(true)
		expect(rig.fill().BackgroundColor3).toBe(Theme.stripeDark)
		rig.set("Phase", "Asleep")
		expect(stripes.Visible).toBe(false)
	end)

	it("counts the time down about once a second", function()
		local rig = newRig(nil, 100)
		rig.set("PhaseEndsAt", 100.3)
		rig.set("Phase", "Awake")
		expect(rig.label().Text).toBe("AWAKE! Back to sleep in 0:01")
		rig.setNow(100.3)
		task.wait(0.5)
		expect(rig.label().Text).toBe("AWAKE! Back to sleep in 0:00")
	end)

	it("does not change by itself while he is asleep", function()
		local rig = newRig()
		task.wait(0.2)
		expect(rig.label().Text).toBe("Giant is sleeping")
	end)

	it("stops counting once stopped", function()
		local rig = newRig(nil, 100)
		rig.set("PhaseEndsAt", 100.3)
		rig.set("Phase", "Awake")
		local label = rig.label()
		rig.stop()
		rig.setNow(100.3)
		task.wait(0.5)
		expect(label.Text).toBe("AWAKE! Back to sleep in 0:01")
	end)
end)

describe("SleepMeterUi.start: the pulse at 60", function()
	it("grows to about 110% on the 60 warning and is back to 100% after 0.3 s", function()
		local rig = newRig()
		local pulse = rig.pulse()
		expect(pulse.Scale).toBe(1)
		rig.fireWarning(60)
		local biggest = 1
		local started = os.clock()
		while os.clock() - started < 0.7 do
			biggest = math.max(biggest, pulse.Scale)
			task.wait()
		end
		expect(biggest > 1.08).toBe(true)
		expect(biggest <= 1.1001).toBe(true)
		expect(pulse.Scale).toBe(1)
	end)

	it("does not pulse on the 85 warning", function()
		local rig = newRig()
		local pulse = rig.pulse()
		rig.fireWarning(85)
		local biggest = 1
		local started = os.clock()
		while os.clock() - started < 0.4 do
			biggest = math.max(biggest, pulse.Scale)
			task.wait()
		end
		expect(biggest).toBe(1)
	end)

	it("ignores a warning that is not a number", function()
		local rig = newRig()
		rig.fireWarning("60" :: any)
		task.wait(0.1)
		expect(rig.pulse().Scale).toBe(1)
	end)
end)

describe("SleepMeterUi.start: computer and phone", function()
	it("is 400x62 on a computer screen", function()
		local meter = newRig(Vector2.new(1280, 720)).meter()
		expect(meter.Size).toBe(UDim2.fromOffset(400, 62))
	end)

	it("is 260x46 with a 14 px label on a phone screen", function()
		local rig = newRig(Vector2.new(750, 390))
		expect(rig.meter().Size).toBe(UDim2.fromOffset(260, 46))
		expect(rig.label().TextSize).toBe(14)
	end)

	it("changes size when the screen size changes", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.setViewport(Vector2.new(750, 390))
		expect(rig.meter().Size).toBe(UDim2.fromOffset(260, 46))
		rig.setViewport(Vector2.new(1280, 720))
		expect(rig.meter().Size).toBe(UDim2.fromOffset(400, 62))
	end)

	it("never uses text under 14 px on a phone", function()
		local rig = newRig(Vector2.new(750, 390))
		expect(rig.label().TextSize >= 14).toBe(true)
		expect(rig.lock().TextSize >= 14).toBe(true)
	end)
end)

describe("SleepMeterUi.start: keeping clear of Roblox's buttons", function()
	it("stays centred when Roblox's buttons end well to the left", function()
		local meter = newRig(Vector2.new(1280, 720), nil, 164).meter()
		expect(meter.Position.X.Scale).toBe(0.5)
		expect(meter.Position.X.Offset).toBe(0)
	end)

	it("slides right when Roblox's buttons come too close", function()
		-- 750 wide, meter 260 (286 at the pulse), buttons end at 250: the centre moves from 375 to 401.
		local meter = newRig(Vector2.new(750, 390), nil, 250).meter()
		expect(meter.Position.X.Scale).toBe(0.5)
		expect(meter.Position.X.Offset).toBeCloseTo(26, 3)
	end)

	it("moves when Roblox's buttons change, and comes back", function()
		local rig = newRig(Vector2.new(750, 390), nil, 164)
		expect(rig.meter().Position.X.Offset).toBe(0)
		rig.setTopbarEdge(250)
		expect(rig.meter().Position.X.Offset).toBeCloseTo(26, 3)
		rig.setTopbarEdge(164)
		expect(rig.meter().Position.X.Offset).toBe(0)
	end)

	it("moves when the screen size changes", function()
		local rig = newRig(Vector2.new(1280, 720), nil, 250)
		expect(rig.meter().Position.X.Offset).toBe(0)
		rig.setViewport(Vector2.new(568, 390))
		-- 568 wide, phone meter 260 (286 at the pulse): the centre is 250 + 8 + 143 = 401, which is 117 right of 284.
		expect(rig.meter().Position.X.Offset).toBeCloseTo(117, 3)
	end)
end)
