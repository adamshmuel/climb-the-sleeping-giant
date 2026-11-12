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

describe("SpotLabels: empty spots", function()
	-- Spec Rule 77: an empty nest shows no timer and no words.
	it("an empty spot never shows a label, and never hides a rarity label", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local empty = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local waiting = rig.addSpot("EggSpot_Rare_1", "Rare")
		-- the empty spot is the nearer one and sits right on the rarity label, with a RefillAt left over
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, 200, 80, 30), distance = 5 }
		screen.places["EggSpot_Rare_1"] = { rect = rect(310, 205, 80, 30), distance = 20 }
		empty:SetAttribute("RefillAt", 150)
		rig.set(empty, "Waiting", false)
		rig.set(waiting, "Waiting", true)
		rig.advance(0.3)
		rig.advance(0.3)
		expect((rig.labelOf(empty) :: BillboardGui).Enabled).toBe(false)
		expect(screen.measured["EggSpot_Uncommon_1"]).toBeNil()
		expect(seeThrough(rig, waiting)).toBe(0)
		expect(outlineSeeThrough(rig, waiting)).toBe(0)
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

describe("SpotLabels: labels never sit under the RUN HOME! pill", function()
	local pill = rect(914, 14, 200, 50)

	it("fades a label that touches the pill's box in 0.15 s, and brings it back once it is clear", function()
		local screen = newScreen()
		screen.pill = pill
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(1000, 40, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.075)
		expect(seeThrough(rig, spot)).toBeCloseTo(0.5, 3)
		rig.advance(0.075)
		expect(seeThrough(rig, spot)).toBeCloseTo(1, 3)
		-- the pill goes (the egg is home): the label is not hidden any more
		screen.pill = nil
		rig.advance(0.1)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, spot)).toBeCloseTo(0, 3)
	end)

	it("shows a label clear of the pill", function()
		local screen = newScreen()
		screen.pill = pill
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		screen.places["EggSpot_Common_1"] = { rect = rect(1000, 120, 60, 20), distance = 5 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, spot)).toBe(0)
	end)
end)

describe("SpotLabels: labels never stack", function()
	-- Spec V1 rule "Egg labels never stack": words that touch or nearly touch read as one clipped word, so only the
	-- nearer label shows.
	it("fades the farther of two labels whose words sit 2 px apart, at about the same distance", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local nearer = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local farther = rig.addSpot("EggSpot_Uncommon_2", "Uncommon")
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, 200, 60, 20), distance = 60 }
		screen.places["EggSpot_Uncommon_2"] = { rect = rect(362, 200, 60, 20), distance = 60.5 }
		rig.set(nearer, "Waiting", true)
		rig.set(farther, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, nearer)).toBe(0)
		expect(seeThrough(rig, farther)).toBeCloseTo(1, 3)
	end)

	it("fades the farther of two labels whose words touch edge to edge", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local nearer = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local farther = rig.addSpot("EggSpot_Uncommon_2", "Uncommon")
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, 200, 60, 20), distance = 60 }
		screen.places["EggSpot_Uncommon_2"] = { rect = rect(360, 200, 60, 20), distance = 60.5 }
		rig.set(nearer, "Waiting", true)
		rig.set(farther, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, nearer)).toBe(0)
		expect(seeThrough(rig, farther)).toBeCloseTo(1, 3)
	end)

	-- Spec Rule 52: the word shows up to 75 studs. Roblox culls a billboard by depth along the look, not by real
	-- distance, so a far word can still be drawn: the picker hides it itself.
	it("fades both of two overlapping labels that are past 75 studs", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local first = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local second = rig.addSpot("EggSpot_Uncommon_2", "Uncommon")
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, 200, 60, 18), distance = 104.6 }
		screen.places["EggSpot_Uncommon_2"] = { rect = rect(310, 200, 60, 18), distance = 108.4 }
		rig.set(first, "Waiting", true)
		rig.set(second, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, first)).toBeCloseTo(1, 3)
		expect(seeThrough(rig, second)).toBeCloseTo(1, 3)
	end)

	it("fades a label at 76 studs and shows one at 75", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local past = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local atTheLimit = rig.addSpot("EggSpot_Uncommon_2", "Uncommon")
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(100, 200, 60, 20), distance = 76 }
		screen.places["EggSpot_Uncommon_2"] = { rect = rect(400, 200, 60, 20), distance = 75 }
		rig.set(past, "Waiting", true)
		rig.set(atTheLimit, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, past)).toBeCloseTo(1, 3)
		expect(seeThrough(rig, atTheLimit)).toBe(0)
	end)

	it("keeps both labels when their words sit well apart", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local nearer = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local farther = rig.addSpot("EggSpot_Uncommon_2", "Uncommon")
		screen.places["EggSpot_Uncommon_1"] = { rect = rect(300, 200, 60, 20), distance = 60 }
		screen.places["EggSpot_Uncommon_2"] = { rect = rect(380, 200, 60, 20), distance = 60.5 }
		rig.set(nearer, "Waiting", true)
		rig.set(farther, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, nearer)).toBe(0)
		expect(seeThrough(rig, farther)).toBe(0)
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

	it("gives the words and real distance for a far label", function()
		local view = SpotLabels.screenView(fakeCamera, function()
			return nil
		end, sizes)
		local gui, text = makeLabel()
		local words, distance = view.words(gui, text, Vector3.new(0, 0, 76))
		expect(words).never.toBeNil()
		expect(distance).toBeCloseTo(76, 3)
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

	it("passes on the RUN HOME! pill's box, or nothing", function()
		local box: SpotLabels.Rect? = rect(5, 6, 7, 8)
		local view = SpotLabels.screenView(
			fakeCamera,
			function()
				return nil
			end,
			sizes,
			function()
				return box
			end
		)
		expect(view.pill()).toEqual(rect(5, 6, 7, 8))
		box = nil
		expect(view.pill()).toBeNil()
	end)
end)

describe("SpotLabels.screenRect", function()
	-- A stand-in for a GuiObject: Roblox only reports these two for it.
	local function fakeGui(position: Vector2, size: Vector2): GuiObject
		return { AbsolutePosition = position, AbsoluteSize = size } :: any
	end

	it("adds the top bar's inset to where the object reports itself", function()
		-- The pill in Play B reported (560, -46) and the top bar is 58 high: it really sits at y 12.
		local box = SpotLabels.screenRect(fakeGui(Vector2.new(560, -46), Vector2.new(160, 38)), Vector2.new(0, 58))
		expect(box).toEqual(rect(560, 12, 160, 38))
	end)

	it("gives nothing for an object that is not drawn yet (no size)", function()
		expect(SpotLabels.screenRect(fakeGui(Vector2.new(5, 5), Vector2.new(0, 0)), Vector2.new(0, 58))).toBeNil()
	end)
end)
