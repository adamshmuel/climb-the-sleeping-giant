--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)
local Helpers = require(script.Parent.Helpers)
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig
local newScreen = Helpers.newScreen
local outlineSeeThrough = Helpers.outlineSeeThrough
local overlappingRares = Helpers.overlappingRares
local rect = Helpers.rect
local seeThrough = Helpers.seeThrough

afterEach(cleanUp)

describe("SpotLabels: countdowns", function()
	it("are never hidden, and never hide a rarity label", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local countdown = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local waiting = rig.addSpot("EggSpot_Rare_1", "Rare")
		-- the countdown is the nearer one and sits right on the rarity label
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, 200, 80, 30), distance = 5 }
		screen.places["EggSpot_Rare_1"] = { rect = rect(310, 205, 80, 30), distance = 20 }
		countdown:SetAttribute("RefillAt", 150)
		rig.set(countdown, "Waiting", false)
		rig.set(waiting, "Waiting", true)
		rig.advance(0.3)
		rig.advance(0.3)
		expect(seeThrough(rig, countdown)).toBe(0)
		expect(outlineSeeThrough(rig, countdown)).toBe(0)
		expect(seeThrough(rig, waiting)).toBe(0)
		expect(outlineSeeThrough(rig, waiting)).toBe(0)
	end)

	it("are not measured at all, even when the screen has a place for them", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local countdown = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, -50, 80, 30), distance = 5 }
		countdown:SetAttribute("RefillAt", 150)
		rig.set(countdown, "Waiting", false)
		rig.advance(0.3)
		expect(screen.measured["EggSpot_Uncommon_1"]).toBeNil()
		-- not even the top edge or the meter touch it
		expect(seeThrough(rig, countdown)).toBe(0)
	end)

	it("show at once when a hidden label's egg is taken", function()
		local screen = newScreen()
		local rig, _near, far = overlappingRares(screen)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
		far:SetAttribute("RefillAt", 150)
		rig.set(far, "Waiting", false)
		expect(rig.textOf(far).Text).toBe("0:50")
		expect(seeThrough(rig, far)).toBe(0)
		expect(outlineSeeThrough(rig, far)).toBe(0)
		-- and it stays shown through the next checks
		rig.advance(0.3)
		expect(seeThrough(rig, far)).toBe(0)
	end)

	it("show at once when a hidden label's spot stops waiting and has no countdown yet", function()
		local screen = newScreen()
		local rig, _near, far = overlappingRares(screen)
		rig.advance(0.075)
		rig.advance(0.075)
		rig.set(far, "Waiting", nil)
		expect(seeThrough(rig, far)).toBe(0)
		expect(outlineSeeThrough(rig, far)).toBe(0)
	end)
end)

describe("SpotLabels: labels never sit under the meter", function()
	local meter = rect(500, 16, 400, 54)

	it("fades a label that touches the meter's box, and brings it back once it is clear", function()
		local screen = newScreen()
		screen.meter = meter
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(560, 50, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.075)
		expect(seeThrough(rig, spot)).toBeCloseTo(0.5, 3)
		rig.advance(0.075)
		expect(seeThrough(rig, spot)).toBeCloseTo(1, 3)
		-- the player walks on: the label drops clear of the meter
		screen.places["EggSpot_Common_1"] = { rect = rect(560, 120, 60, 20), distance = 8 }
		rig.advance(0.1)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, spot)).toBeCloseTo(0, 3)
		expect(outlineSeeThrough(rig, spot)).toBeCloseTo(0, 3)
	end)

	it("fades a label that reaches past the top edge of the screen", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare")
		screen.places["EggSpot_Rare_1"] = { rect = rect(100, -10, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.2)
		expect(seeThrough(rig, spot)).toBeCloseTo(1, 3)
	end)

	it("does not need a meter: a label shows where the meter would be", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(560, 50, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, spot)).toBe(0)
	end)

	it("never hides a countdown for being under the meter", function()
		local screen = newScreen()
		screen.meter = meter
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(560, 50, 60, 20), distance = 5 }
		spot:SetAttribute("RefillAt", 150)
		rig.set(spot, "Waiting", false)
		rig.advance(0.3)
		expect(seeThrough(rig, spot)).toBe(0)
	end)

	it("lets a label hidden by the meter step aside for a farther label that overlaps it", function()
		local screen = newScreen()
		screen.meter = meter
		local rig = newRig(screen.view)
		local under = rig.addSpot("EggSpot_Common_1", "Common")
		local beside = rig.addSpot("EggSpot_Common_2", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(470, 50, 60, 20), distance = 5 }
		screen.places["EggSpot_Common_2"] = { rect = rect(440, 60, 40, 20), distance = 15 }
		rig.set(under, "Waiting", true)
		rig.set(beside, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, under)).toBeCloseTo(1, 3)
		expect(seeThrough(rig, beside)).toBe(0)
	end)
end)

describe("SpotLabels: how often it checks", function()
	it("measures the labels at most every 0.1 s", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(300, 200, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		local before = screen.calls
		for _ = 1, 5 do
			rig.advance(0.03) -- 0.15 s in all, in frames of 0.03 s
		end
		-- a check at the first frame, and one more once 0.1 s has gone by (at 0.15 s)
		expect(screen.calls - before).toBe(2)
		for _ = 1, 4 do
			rig.advance(0.03) -- 0.27 s in all: the third check is due at 0.25 s
		end
		expect(screen.calls - before).toBe(3)
	end)

	it("checks about ten times a second, not once a second", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(300, 200, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		local before = screen.calls
		for _ = 1, 20 do
			rig.advance(0.05) -- one second in all
		end
		expect(screen.calls - before >= 9).toBe(true)
		expect(screen.calls - before <= 11).toBe(true)
	end)

	it("does nothing without a screen: no measuring and no fading", function()
		local rig = newRig(nil)
		local one = rig.addSpot("EggSpot_Rare_1", "Rare")
		local two = rig.addSpot("EggSpot_Rare_2", "Rare")
		rig.set(one, "Waiting", true)
		rig.set(two, "Waiting", true)
		rig.advance(0.5)
		expect(seeThrough(rig, one)).toBe(0)
		expect(seeThrough(rig, two)).toBe(0)
	end)
end)

describe("SpotLabels: stopping while a label is fading", function()
	it("leaves no connection behind and measures nothing more", function()
		local screen = newScreen()
		local rig, _near, _far = overlappingRares(screen)
		rig.advance(0.075)
		local callsAtStop = screen.calls
		rig.stop()
		expect(rig.step:count()).toBe(0)
		expect(#rig.labels()).toBe(0)
		rig.advance(0.5)
		expect(screen.calls).toBe(callsAtStop)
	end)

	it("forgets a spot that leaves, even one that is hidden", function()
		local screen = newScreen()
		local rig, _near, far = overlappingRares(screen)
		rig.advance(0.2)
		far.Parent = nil
		task.wait()
		rig.advance(0.2)
		expect(#rig.labels()).toBe(1)
		-- measured once, at the first check, and never again after it left
		expect(screen.measured["EggSpot_Rare_2"]).toBe(1)
	end)
end)

describe("SpotLabels.screenView", function()
	-- A flat stand-in camera: looks down +Z from the origin, and puts a point at x pixels = 500 + 10 * X.
	local function fakeCamera(): SpotLabels.CameraLike
		return {
			CFrame = CFrame.new(0, 0, 0),
			WorldToViewportPoint = function(_self: any, point: Vector3): (Vector3, boolean)
				return Vector3.new(500 + 10 * point.X, 300 - 10 * point.Y, point.Z), point.Z > 0
			end,
		}
	end
	local sizes = function(_gui: BillboardGui, _text: TextLabel): SpotLabels.Sizes?
		return { billboard = Vector2.new(100, 30), box = Vector2.new(100, 30), words = Vector2.new(60, 20) }
	end

	local function makeLabel(): (BillboardGui, TextLabel)
		local gui = made(Instance.new("BillboardGui"))
		local text = Instance.new("TextLabel")
		text.Parent = gui
		return gui, text
	end

	it("gives the words' rectangle and the distance for a label in front of the camera", function()
		local view = SpotLabels.screenView(fakeCamera, function()
			return nil
		end, sizes)
		local gui, text = makeLabel()
		local words, distance = view.words(gui, text, Vector3.new(3, 0, 40))
		expect((words :: SpotLabels.Rect).x).toBe(530 - 30)
		expect((words :: SpotLabels.Rect).width).toBe(60)
		expect(distance).toBeCloseTo(Vector3.new(3, 0, 40).Magnitude, 3)
	end)

	it("gives nothing for a label behind the camera", function()
		local view = SpotLabels.screenView(fakeCamera, function()
			return nil
		end, sizes)
		local gui, text = makeLabel()
		expect(view.words(gui, text, Vector3.new(0, 0, -5))).toBeNil()
	end)

	it("gives nothing for a label past 75 studs", function()
		local view = SpotLabels.screenView(fakeCamera, function()
			return nil
		end, sizes)
		local gui, text = makeLabel()
		local past = view.words(gui, text, Vector3.new(0, 0, 76))
		local atTheLimit = view.words(gui, text, Vector3.new(0, 0, 75))
		expect(past).toBeNil()
		expect(atTheLimit).never.toBeNil()
	end)

	it("gives nothing for a label that is not drawn yet (no size)", function()
		local view = SpotLabels.screenView(fakeCamera, function()
			return nil
		end, function()
			return nil
		end)
		local gui, text = makeLabel()
		expect(view.words(gui, text, Vector3.new(0, 0, 40))).toBeNil()
	end)

	it("gives nothing when there is no camera", function()
		local view = SpotLabels.screenView(function()
			return nil
		end, function()
			return nil
		end, sizes)
		local gui, text = makeLabel()
		expect(view.words(gui, text, Vector3.new(0, 0, 40))).toBeNil()
	end)

	it("passes on the meter's box, or nothing", function()
		local box: SpotLabels.Rect? = rect(1, 2, 3, 4)
		local view = SpotLabels.screenView(fakeCamera, function()
			return box
		end, sizes)
		expect(view.meter()).toEqual(rect(1, 2, 3, 4))
		box = nil
		expect(view.meter()).toBeNil()
	end)
end)
