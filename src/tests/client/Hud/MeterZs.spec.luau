--!strict
-- The Z Z Z on the sleep meter, built on the screen (plan 3 Task 8f). Where they go is MeterZsView.spec.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Layout = require(Hud.Layout)
local MeterZs = require(Hud.MeterZs)
local MeterZsView = require(Hud.MeterZsView)

type Rig = {
	gui: ScreenGui,
	zs: MeterZs.Handle,
	plays: { { target: Instance, info: TweenInfo, goals: { [string]: any } } },
	delays: { number },
	cancels: { number },
}

local function newRig(reduced: boolean): Rig
	local rig: Rig = {
		gui = Instance.new("ScreenGui"),
		plays = {},
		delays = {},
		cancels = { 0 },
		zs = nil :: any,
	}
	rig.zs = MeterZs.new(rig.gui, {
		reducedMotion = function(): boolean
			return reduced
		end,
		play = function(target: Instance, info: TweenInfo, goals: { [string]: any }): () -> ()
			table.insert(rig.plays, { target = target, info = info, goals = goals })
			return function()
				rig.cancels[1] += 1
			end
		end,
		delay = function(seconds: number, _callback: () -> ()): () -> ()
			table.insert(rig.delays, seconds)
			return function()
				rig.cancels[1] += 1
			end
		end,
	})
	return rig
end

local function letter(rig: Rig, index: number): CanvasGroup
	local frame = rig.gui:FindFirstChild("MeterZs")
	assert(frame ~= nil, "no MeterZs frame")
	local z = frame:FindFirstChild(`Z{index}`)
	assert(z ~= nil and z:IsA("CanvasGroup"), `no Z{index}`)
	return z
end

describe("MeterZs.new", function()
	it("builds a MeterZs frame with Z1, Z2 and Z3 in the screen", function()
		local rig = newRig(true)
		local frame = rig.gui:FindFirstChild("MeterZs")
		expect(frame ~= nil).toBe(true)
		for index = 1, 3 do
			expect(letter(rig, index):FindFirstChildWhichIsA("TextLabel", true) ~= nil).toBe(true)
		end
		rig.zs.destroy()
	end)

	it("starts with the three Zs hidden", function()
		local rig = newRig(true)
		for index = 1, 3 do
			expect(letter(rig, index).Visible).toBe(false)
		end
		rig.zs.destroy()
	end)
end)

describe("MeterZs setLook", function()
	it("shows all three Zs for the shown look and hides all three for the hidden look", function()
		local rig = newRig(true)
		rig.zs.setLook(MeterZsView.look("shown"))
		for index = 1, 3 do
			expect(letter(rig, index).Visible).toBe(true)
		end
		rig.zs.setLook(MeterZsView.look("hidden"))
		for index = 1, 3 do
			expect(letter(rig, index).Visible).toBe(false)
		end
		rig.zs.destroy()
	end)

	it("shows the Zs half see-through for the faded look", function()
		local rig = newRig(true)
		rig.zs.setLook(MeterZsView.look("faded"))
		expect(letter(rig, 1).GroupTransparency).toBeCloseTo(0.5, 3)
		rig.zs.destroy()
	end)

	it("makes no tween and no wait with Reduce Motion on", function()
		local rig = newRig(true)
		rig.zs.setLook(MeterZsView.look("shown"))
		rig.zs.setLook(MeterZsView.look("heavy"))
		expect(#rig.plays).toBe(0)
		expect(#rig.delays).toBe(0)
		expect(letter(rig, 1).GroupTransparency).toBe(0)
		rig.zs.destroy()
	end)

	it("starts the first Z at once and the next two 0.6 and 1.2 seconds later with Reduce Motion off", function()
		local rig = newRig(false)
		rig.zs.setLook(MeterZsView.look("shown"))
		expect(#rig.plays > 0).toBe(true)
		expect(rig.delays).toEqual({ 0.6, 1.2 })
		rig.zs.destroy()
	end)

	it("rises over 2 seconds for the shown look and 1.4 seconds for Heavy Sleep", function()
		local shown = newRig(false)
		shown.zs.setLook(MeterZsView.look("shown"))
		expect(shown.plays[1].info.Time).toBeCloseTo(2, 3)
		shown.zs.destroy()
		local heavy = newRig(false)
		heavy.zs.setLook(MeterZsView.look("heavy"))
		expect(heavy.plays[1].info.Time).toBeCloseTo(1.4, 3)
		heavy.zs.destroy()
	end)

	it("stops the running tweens when the look changes", function()
		local rig = newRig(false)
		rig.zs.setLook(MeterZsView.look("shown"))
		local before = rig.cancels[1]
		rig.zs.setLook(MeterZsView.look("hidden"))
		expect(rig.cancels[1] > before).toBe(true)
		rig.zs.destroy()
	end)
end)

describe("MeterZs place", function()
	it("puts each Z where MeterZsView.boxes says, tipped 12 degrees counter-clockwise", function()
		local rig = newRig(true)
		local screen = Layout.forScreen(Vector2.new(1280, 720))
		rig.zs.place(screen, 640)
		rig.zs.setLook(MeterZsView.look("shown"))
		local boxes = MeterZsView.boxes(screen, 640, false)
		for index = 1, 3 do
			local z = letter(rig, index)
			local label = z:FindFirstChild("Letter") :: TextLabel
			expect(label.TextSize).toBe(math.round(boxes[index].textSize)) -- TextSize is a whole number
			expect(z.Position.X.Offset + MeterZs.padding).toBeCloseTo(boxes[index].x, 2)
			expect(z.Position.Y.Offset + MeterZs.padding).toBeCloseTo(boxes[index].y, 2)
			expect(z.Rotation).toBeCloseTo(-12, 2) -- counter-clockwise, like the mockup's rotate(-12deg)
		end
		rig.zs.destroy()
	end)

	it("uses the bigger letters for the heavy look", function()
		local rig = newRig(true)
		local screen = Layout.forScreen(Vector2.new(840, 368))
		rig.zs.place(screen, 550)
		rig.zs.setLook(MeterZsView.look("heavy"))
		local label = letter(rig, 3):FindFirstChild("Letter") :: TextLabel
		expect(label.TextSize).toBe(math.round(44 / 0.74)) -- the phone Heavy Sleep Z3: 44 points tall (meter-zs.md)
		rig.zs.destroy()
	end)
end)

describe("MeterZs destroy", function()
	it("removes the frame and stops the tweens", function()
		local rig = newRig(false)
		rig.zs.setLook(MeterZsView.look("shown"))
		local before = rig.cancels[1]
		rig.zs.destroy()
		expect(rig.gui:FindFirstChild("MeterZs")).toBe(nil)
		expect(rig.cancels[1] > before).toBe(true)
	end)
end)
