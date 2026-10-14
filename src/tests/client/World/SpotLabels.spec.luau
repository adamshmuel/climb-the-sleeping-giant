--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)
local Theme = require(Client.Hud.Theme)

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

describe("SpotLabels.text", function()
	it("shows the time left, 0:42, 42 seconds before the refill", function()
		expect(SpotLabels.text(false, "Common", 142, 100)).toBe("0:42")
	end)

	it("rounds a part of a second up: 41.3 seconds before the refill is also 0:42", function()
		expect(SpotLabels.text(false, "Common", 141.3, 100)).toBe("0:42")
	end)

	it("shows 0:00 at and after the refill time", function()
		expect(SpotLabels.text(false, "Common", 100, 100)).toBe("0:00")
		expect(SpotLabels.text(false, "Common", 100, 107)).toBe("0:00")
	end)

	it("counts in minutes and seconds", function()
		expect(SpotLabels.text(false, "Rare", 160, 100)).toBe("1:00")
	end)

	it("names the rarity while an egg waits", function()
		expect(SpotLabels.text(true, "Rare", nil, 100)).toBe("Rare")
		expect(SpotLabels.text(true, "Uncommon", nil, 100)).toBe("Uncommon")
		expect(SpotLabels.text(true, "Common", nil, 100)).toBe("Common")
	end)

	it("names the rarity even if a refill time is left over", function()
		expect(SpotLabels.text(true, "Common", 142, 100)).toBe("Common")
	end)

	it("shows nothing while Waiting is not set yet", function()
		expect(SpotLabels.text(nil, "Common", nil, 100)).toBeNil()
		expect(SpotLabels.text(nil, "Common", 142, 100)).toBeNil()
	end)

	it("shows nothing for an empty spot that has no refill time", function()
		expect(SpotLabels.text(false, "Common", nil, 100)).toBeNil()
	end)
end)

type Rig = {
	parent: Folder,
	root: Folder,
	step: any,
	clock: { now: number },
	addSpot: (name: string, rarity: string, baseCFrame: CFrame?) -> Model,
	set: (spot: Model, name: string, value: any) -> (),
	labels: () -> { BillboardGui },
	labelOf: (spot: Model) -> BillboardGui?,
	textOf: (spot: Model) -> TextLabel,
	advance: (seconds: number) -> (),
	stop: () -> (),
}

-- A fake egg spot like the real ones: a Model with a Rarity and a flat Base part (2 x 0.2 x 2) whose top is where
-- the egg's bottom sits. `waiting`: nil leaves Waiting unset.
local function newSpotModel(name: string, rarity: string, baseCFrame: CFrame): Model
	local model = made(Instance.new("Model"))
	model.Name = name
	model:SetAttribute("Rarity", rarity)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(2, 0.2, 2)
	base.CFrame = baseCFrame
	base.Anchored = true
	base.Parent = model
	return model
end

-- A fake egg on a spot: a model with one part that is `height` studs tall (its extents are what the label reads).
local function addEgg(spot: Model, height: number): Model
	local egg = Instance.new("Model")
	egg.Name = "Egg"
	local part = Instance.new("Part")
	part.Size = Vector3.new(3, height, 3)
	part.Parent = egg
	egg.Parent = spot
	task.wait()
	return egg
end

-- Starts the labels on a fake player screen, fake egg spots, a fake clock and a fake frame signal.
local function newRig(view: SpotLabels.View?): Rig
	local parent = made(Instance.new("Folder"))
	local root = made(Instance.new("Folder"))
	local step = newSignal()
	local clock = { now = 100 }
	local stop = SpotLabels.start({
		parent = parent,
		root = root,
		now = function()
			return clock.now
		end,
		step = step,
		view = view,
	})
	table.insert(stops, stop)

	local function labels(): { BillboardGui }
		local found: { BillboardGui } = {}
		for _, descendant in parent:GetDescendants() do
			if descendant:IsA("BillboardGui") and descendant.Name == "SpotLabel" then
				table.insert(found, descendant)
			end
		end
		return found
	end
	local function labelOf(spot: Model): BillboardGui?
		for _, gui in labels() do
			if gui.Adornee == spot:FindFirstChild("Base") then
				return gui
			end
		end
		return nil
	end
	return {
		parent = parent,
		root = root,
		step = step,
		clock = clock,
		addSpot = function(name: string, rarity: string, baseCFrame: CFrame?): Model
			local spot = newSpotModel(name, rarity, baseCFrame or CFrame.new(0, 10, 0))
			spot.Parent = root
			task.wait()
			return spot
		end,
		set = function(spot: Model, attribute: string, value: any)
			spot:SetAttribute(attribute, value)
			task.wait()
		end,
		labels = labels,
		labelOf = labelOf,
		textOf = function(spot: Model): TextLabel
			return (labelOf(spot) :: BillboardGui):FindFirstChildOfClass("TextLabel") :: TextLabel
		end,
		advance = function(seconds: number)
			clock.now += seconds
			step:Fire(seconds)
		end,
		stop = stop,
	}
end

-- Where the label's centre is in the world, the way Roblox really draws it: the offset is read in the Adornee's own
-- directions (measured in Play on the tilted belly spots), not the world's as its docs say.
local function centreOf(gui: BillboardGui): Vector3
	local adornee = gui.Adornee :: BasePart
	return adornee.Position + adornee.CFrame:VectorToWorldSpace(gui.StudsOffsetWorldSpace)
end

-- The lowest point of the label in studs: its centre minus half its height in studs.
local function bottomOf(gui: BillboardGui): number
	return centreOf(gui).Y - gui.Size.Y.Scale / 2
end

describe("SpotLabels: a waiting egg", function()
	it("shows the rarity name in the rarity's colour", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		expect(rig.textOf(spot).Text).toBe("Common")
		expect(rig.textOf(spot).TextColor3 == Theme.rarity.Common.main).toBe(true)
	end)

	it("uses green for Uncommon and blue for Rare", function()
		local rig = newRig()
		local uncommon = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		local rare = rig.addSpot("EggSpot_Rare_1", "Rare")
		rig.set(uncommon, "Waiting", true)
		rig.set(rare, "Waiting", true)
		expect(rig.textOf(uncommon).Text).toBe("Uncommon")
		expect(rig.textOf(uncommon).TextColor3 == Theme.rarity.Uncommon.main).toBe(true)
		expect(rig.textOf(rare).Text).toBe("Rare")
		expect(rig.textOf(rare).TextColor3 == Theme.rarity.Rare.main).toBe(true)
	end)

	it("is hidden past 75 studs, never bigger than 130x36 px, with text of at most 30 px", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		local gui = rig.labelOf(spot) :: BillboardGui
		expect(gui.MaxDistance).toBe(75)
		local text = rig.textOf(spot)
		local sizeLimit = text:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
		expect(sizeLimit.MaxSize).toEqual(Vector2.new(130, 36))
		local textLimit = text:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		expect(textLimit.MaxTextSize).toBe(30)
	end)

	it("shrinks with distance (sized in studs) and can be hidden behind the giant", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		local gui = rig.labelOf(spot) :: BillboardGui
		expect(gui.Size.X.Scale > 0).toBe(true)
		expect(gui.Size.Y.Scale > 0).toBe(true)
		expect(gui.AlwaysOnTop).toBe(false)
		expect(gui.LightInfluence).toBe(0)
	end)

	it("is placed with world-space offsets only, never the camera-based StudsOffset", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		local gui = rig.labelOf(spot) :: BillboardGui
		expect(gui.StudsOffset).toEqual(Vector3.zero)
		expect(gui.ExtentsOffset).toEqual(Vector3.zero)
		expect(gui.ExtentsOffsetWorldSpace).toEqual(Vector3.zero)
	end)

	it("has no background behind the text, and an Ink outline in Fredoka", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		local text = rig.textOf(spot)
		expect(text.BackgroundTransparency).toBe(1)
		expect(text.FontFace == Theme.font).toBe(true)
		local stroke = text:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.ink).toBe(true)
		expect(stroke.Thickness > 0).toBe(true)
	end)

	it("sits 1 stud above the top of the egg", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		addEgg(spot, 4)
		rig.set(spot, "Waiting", true)
		local baseTop = 10 + 0.1
		expect(bottomOf(rig.labelOf(spot) :: BillboardGui)).toBeCloseTo(baseTop + 4 + 1, 3)
	end)

	it("follows the lean of a tilted spot: above the egg's real top, not above the spot", function()
		local rig = newRig()
		-- the spot's up direction points along +X, so the egg lies sideways
		local tilted = CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare", tilted)
		addEgg(spot, 7)
		rig.set(spot, "Waiting", true)
		local centre = centreOf(rig.labelOf(spot) :: BillboardGui)
		local baseTopPosition = (tilted * CFrame.new(0, 0.1, 0)).Position
		local eggTop = baseTopPosition + tilted.UpVector * 7
		expect(centre.X).toBeCloseTo(eggTop.X, 3)
		expect(centre.Z).toBeCloseTo(eggTop.Z, 3)
		expect(bottomOf(rig.labelOf(spot) :: BillboardGui)).toBeCloseTo(eggTop.Y + 1, 3)
	end)

	it("sits straight above the egg's tip on a spot tilted 30 degrees, with the same gap as a flat spot", function()
		local rig = newRig()
		-- like Rare_1: leaning 30 degrees, and turned around the world's up as well
		local tilted = CFrame.new(5, 10, 3) * CFrame.Angles(0, math.rad(40), math.rad(30))
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare", tilted)
		addEgg(spot, 7)
		rig.set(spot, "Waiting", true)
		local gui = rig.labelOf(spot) :: BillboardGui
		local tip = (tilted * CFrame.new(0, 0.1, 0)).Position + tilted.UpVector * 7
		local centre = centreOf(gui)
		expect(centre.X).toBeCloseTo(tip.X, 3)
		expect(centre.Z).toBeCloseTo(tip.Z, 3)
		expect(bottomOf(gui)).toBeCloseTo(tip.Y + 1, 3)
	end)

	it("moves to the egg's real top when the egg model appears after Waiting is set", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		rig.set(spot, "Waiting", true)
		local before = bottomOf(rig.labelOf(spot) :: BillboardGui)
		addEgg(spot, 9)
		local after = bottomOf(rig.labelOf(spot) :: BillboardGui)
		expect(after).toBeCloseTo(10.1 + 9 + 1, 3)
		expect(after).never.toBeCloseTo(before, 1)
	end)
end)

describe("SpotLabels: an empty spot", function()
	it("shows the countdown in white", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		rig.set(spot, "RefillAt", 142)
		rig.set(spot, "Waiting", false)
		expect(rig.textOf(spot).Text).toBe("0:42")
		expect(rig.textOf(spot).TextColor3 == Theme.white).toBe(true)
	end)

	it("shows the countdown when RefillAt arrives together with Waiting false", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		spot:SetAttribute("RefillAt", 160)
		spot:SetAttribute("Waiting", false)
		task.wait()
		expect(rig.textOf(spot).Text).toBe("1:00")
	end)

	it("counts down live on every frame", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		spot:SetAttribute("RefillAt", 142)
		rig.set(spot, "Waiting", false)
		expect(rig.textOf(spot).Text).toBe("0:42")
		rig.advance(1)
		expect(rig.textOf(spot).Text).toBe("0:41")
		rig.advance(40)
		expect(rig.textOf(spot).Text).toBe("0:01")
		rig.advance(5)
		expect(rig.textOf(spot).Text).toBe("0:00")
	end)

	it("sets the text only when it changes", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		spot:SetAttribute("RefillAt", 142)
		rig.set(spot, "Waiting", false)
		local changes = 0
		local connection = rig.textOf(spot):GetPropertyChangedSignal("Text"):Connect(function()
			changes += 1
		end)
		rig.advance(0.2)
		rig.advance(0.2)
		task.wait()
		expect(changes).toBe(0)
		rig.advance(1)
		task.wait()
		expect(changes).toBe(1)
		connection:Disconnect()
	end)

	it("sits 1.5 studs above the top of the Base", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Uncommon_1", "Uncommon", CFrame.new(0, 10, 0))
		spot:SetAttribute("RefillAt", 130)
		rig.set(spot, "Waiting", false)
		expect(bottomOf(rig.labelOf(spot) :: BillboardGui)).toBeCloseTo(10.1 + 1.5, 3)
	end)

	it("sits straight above the Base's top centre on a tilted spot, 1.5 studs up", function()
		local rig = newRig()
		local tilted = CFrame.new(5, 10, 3) * CFrame.Angles(0, math.rad(40), math.rad(30))
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare", tilted)
		spot:SetAttribute("RefillAt", 130)
		rig.set(spot, "Waiting", false)
		local gui = rig.labelOf(spot) :: BillboardGui
		local top = (tilted * CFrame.new(0, 0.1, 0)).Position
		local centre = centreOf(gui)
		expect(centre.X).toBeCloseTo(top.X, 3)
		expect(centre.Z).toBeCloseTo(top.Z, 3)
		expect(bottomOf(gui)).toBeCloseTo(top.Y + 1.5, 3)
	end)

	it("keeps the limits of the egg label: 130x36 px, 30 px text, 75 studs", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		spot:SetAttribute("RefillAt", 130)
		rig.set(spot, "Waiting", false)
		local gui = rig.labelOf(spot) :: BillboardGui
		expect(gui.MaxDistance).toBe(75)
		expect(gui.AlwaysOnTop).toBe(false)
		expect(gui.LightInfluence).toBe(0)
		local text = rig.textOf(spot)
		expect((text:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint).MaxSize).toEqual(
			Vector2.new(130, 36)
		)
		expect((text:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MaxTextSize).toBe(30)
	end)

	it("goes back to the rarity name when the egg comes back", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare")
		spot:SetAttribute("RefillAt", 142)
		rig.set(spot, "Waiting", false)
		spot:SetAttribute("RefillAt", nil)
		rig.set(spot, "Waiting", true)
		expect(rig.textOf(spot).Text).toBe("Rare")
		expect(rig.textOf(spot).TextColor3 == Theme.rarity.Rare.main).toBe(true)
		-- and the frames no longer touch it
		rig.advance(5)
		expect(rig.textOf(spot).Text).toBe("Rare")
	end)

	it("shows nothing for an empty spot that has no refill time yet", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", false)
		expect((rig.labelOf(spot) :: BillboardGui).Enabled).toBe(false)
	end)
end)

describe("SpotLabels: the rest of the lifetime", function()
	it("shows nothing while Waiting is not set", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		local gui = rig.labelOf(spot)
		expect(gui == nil or not gui.Enabled).toBe(true)
	end)

	it("hides the label when Waiting is cleared", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		rig.set(spot, "Waiting", nil)
		expect((rig.labelOf(spot) :: BillboardGui).Enabled).toBe(false)
	end)

	it("labels spots that are there at the start", function()
		local parent = made(Instance.new("Folder"))
		local root = made(Instance.new("Folder"))
		local spot = newSpotModel("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		spot:SetAttribute("Waiting", true)
		spot.Parent = root
		local stop = SpotLabels.start({
			parent = parent,
			root = root,
			now = function()
				return 100
			end,
			step = newSignal(),
		})
		table.insert(stops, stop)
		local found = parent:FindFirstChild("SpotLabel", true) :: BillboardGui
		expect((found:FindFirstChildOfClass("TextLabel") :: TextLabel).Text).toBe("Common")
		expect(found.Enabled).toBe(true)
	end)

	it("labels a spot that arrives later and drops the label of a spot that leaves", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		expect(#rig.labels()).toBe(1)
		spot.Parent = nil
		task.wait()
		expect(#rig.labels()).toBe(0)
	end)

	it("keeps one label per spot, so two close spots both read", function()
		local rig = newRig()
		local one = rig.addSpot("EggSpot_Uncommon_1", "Uncommon", CFrame.new(0, 10, 0))
		local two = rig.addSpot("EggSpot_Uncommon_2", "Uncommon", CFrame.new(8, 10, 0))
		rig.set(one, "Waiting", true)
		rig.set(two, "Waiting", true)
		expect(#rig.labels()).toBe(2)
		expect(rig.labelOf(one)).never.toBe(rig.labelOf(two))
	end)

	it("removes every label and every connection when it is stopped", function()
		local rig = newRig()
		local one = rig.addSpot("EggSpot_Common_1", "Common")
		local two = rig.addSpot("EggSpot_Uncommon_1", "Uncommon")
		rig.set(one, "Waiting", true)
		two:SetAttribute("RefillAt", 150)
		rig.set(two, "Waiting", false)
		expect(rig.step:count()).toBe(1)
		rig.stop()
		expect(#rig.labels()).toBe(0)
		expect(rig.step:count()).toBe(0)
		-- changes after the stop draw nothing
		rig.set(one, "Waiting", false)
		rig.addSpot("EggSpot_Common_2", "Common")
		expect(#rig.labels()).toBe(0)
	end)

	it("can be stopped twice", function()
		local rig = newRig()
		rig.stop()
		rig.stop()
		expect(#rig.labels()).toBe(0)
	end)
end)

-- A rectangle on the screen, in pixels, from the top left corner.
local function rect(x: number, y: number, width: number, height: number): SpotLabels.Rect
	return { x = x, y = y, width = width, height = height }
end

local function candidate(id: number, area: SpotLabels.Rect, distance: number): SpotLabels.Candidate
	return { id = id, rect = area, distance = distance }
end

-- Where the labels are placed in these tests: well below the top edge, with no meter unless a test gives one.
local NEAR = 10
local MIDDLE = 20
local FAR = 30

describe("SpotLabels.pickShown: labels never stack", function()
	it("shows only the nearer of two overlapping labels", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), FAR),
			candidate(2, rect(130, 105, 60, 20), NEAR),
		}, nil)
		expect(shown[2]).toBe(true)
		expect(shown[1]).toBe(false)
	end)

	it("shows both labels when they do not overlap", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(200, 100, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("shows both labels when they only touch edge to edge, side by side", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(160, 100, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("shows both labels when they only touch edge to edge, one above the other", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(100, 120, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("in a row where only neighbours overlap, shows the nearest and the farthest", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(140, 100, 60, 20), MIDDLE),
			candidate(3, rect(180, 100, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(false)
		expect(shown[3]).toBe(true)
	end)

	it("gives the same answer when the list comes in another order", function()
		local one = candidate(1, rect(100, 100, 60, 20), NEAR)
		local two = candidate(2, rect(140, 100, 60, 20), MIDDLE)
		local three = candidate(3, rect(180, 100, 60, 20), FAR)
		local forward = SpotLabels.pickShown({ one, two, three }, nil)
		local backward = SpotLabels.pickShown({ three, two, one }, nil)
		local shuffled = SpotLabels.pickShown({ two, three, one }, nil)
		for id = 1, 3 do
			expect(backward[id]).toBe(forward[id])
			expect(shuffled[id]).toBe(forward[id])
		end
	end)

	it("picks the same one of two labels at the same distance, whatever the order", function()
		local one = candidate(1, rect(100, 100, 60, 20), NEAR)
		local two = candidate(2, rect(130, 100, 60, 20), NEAR)
		local forward = SpotLabels.pickShown({ one, two }, nil)
		local backward = SpotLabels.pickShown({ two, one }, nil)
		expect(forward[1]).toBe(true)
		expect(forward[2]).toBe(false)
		expect(backward[1]).toBe(true)
		expect(backward[2]).toBe(false)
	end)

	it("answers for every label it was given, and for none when given none", function()
		local shown = SpotLabels.pickShown({ candidate(7, rect(100, 100, 60, 20), NEAR) }, nil)
		expect(shown[7]).toBe(true)
		expect(next(SpotLabels.pickShown({}, nil))).toBeNil()
	end)
end)

describe("SpotLabels.pickShown: labels never sit under the meter", function()
	local meter = rect(500, 16, 400, 54) -- 500 to 900 across, 16 to 70 down

	it("hides a label that overlaps the meter's box", function()
		local shown = SpotLabels.pickShown({ candidate(1, rect(480, 50, 60, 20), NEAR) }, meter)
		expect(shown[1]).toBe(false)
	end)

	it("hides a label that only touches the meter's box edge to edge", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(440, 30, 60, 20), NEAR), -- its right edge is the meter's left edge
			candidate(2, rect(600, 70, 60, 20), NEAR), -- its top edge is the meter's bottom edge
		}, meter)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(false)
	end)

	it("shows a label that is clear of the meter's box", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(300, 30, 60, 20), NEAR), -- to the left
			candidate(2, rect(600, 100, 60, 20), NEAR), -- below
		}, meter)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("hides a label that reaches past the top edge of the screen", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, -1, 60, 20), NEAR),
			candidate(2, rect(200, 0, 60, 20), NEAR), -- exactly at the edge is still on the screen
		}, nil)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(true)
	end)

	it("with no meter, only the top edge counts", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(600, 30, 60, 20), NEAR), -- where the meter would be
			candidate(2, rect(100, -5, 60, 20), NEAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(false)
	end)

	it("lets a label hidden by the meter step aside for a farther label that overlaps it", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(470, 50, 60, 20), NEAR), -- under the meter (500 to 900 across)
			candidate(2, rect(440, 55, 50, 20), FAR), -- overlaps label 1, but ends at 490, clear of the meter
		}, meter)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(true)
	end)

	it("lets a label hidden by the top edge step aside for a farther label that overlaps it", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, -5, 60, 20), NEAR),
			candidate(2, rect(120, 10, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(true)
	end)
end)

describe("SpotLabels.wordsRect", function()
	it("centres the words on the billboard when the label fills it", function()
		local words =
			SpotLabels.wordsRect(Vector2.new(400, 300), Vector2.new(100, 30), Vector2.new(100, 30), Vector2.new(60, 20))
		expect(words.width).toBe(60)
		expect(words.height).toBe(20)
		expect(words.x).toBe(370)
		expect(words.y).toBe(290)
	end)

	it("keeps the label's bottom edge on the billboard's bottom edge when the label is capped smaller", function()
		-- billboard 160 x 50 around (400, 300): bottom at 325. The label is capped to 130 x 36, so it spans 289 to 325.
		local words = SpotLabels.wordsRect(
			Vector2.new(400, 300),
			Vector2.new(160, 50),
			Vector2.new(130, 36),
			Vector2.new(130, 36)
		)
		expect(words.x).toBe(335)
		expect(words.y).toBe(289)
		expect(words.width).toBe(130)
		expect(words.height).toBe(36)
	end)

	it("uses the drawn words, not the whole label, when the words are narrower", function()
		local words =
			SpotLabels.wordsRect(Vector2.new(400, 300), Vector2.new(160, 50), Vector2.new(130, 36), Vector2.new(65, 36))
		expect(words.x).toBe(367.5)
		expect(words.width).toBe(65)
	end)

	it("never lets the words reach outside the label", function()
		local words = SpotLabels.wordsRect(
			Vector2.new(400, 300),
			Vector2.new(100, 30),
			Vector2.new(100, 30),
			Vector2.new(140, 50)
		)
		expect(words.width).toBe(100)
		expect(words.height).toBe(30)
	end)
end)

-- A stand-in for the screen: the rectangle (and distance) each spot's label has this moment, and the meter's box.
type FakeScreen = {
	view: SpotLabels.View,
	places: { [string]: { rect: SpotLabels.Rect, distance: number } },
	meter: SpotLabels.Rect?,
	calls: number, -- how many times a label was measured
	measured: { [string]: number }, -- how many times each spot's label was measured
	centres: { [string]: Vector3 }, -- where each spot's label was said to be centred, in the world, at its last measuring
}

local function newScreen(): FakeScreen
	local screen: FakeScreen = {
		places = {},
		meter = nil,
		calls = 0,
		measured = {},
		centres = {},
		view = nil :: any,
	}
	screen.view = {
		words = function(gui: BillboardGui, _text: TextLabel, centre: Vector3)
			local spot = (gui.Adornee :: Instance).Parent :: Instance
			screen.calls += 1
			screen.centres[spot.Name] = centre
			screen.measured[spot.Name] = (screen.measured[spot.Name] or 0) + 1
			local place = screen.places[spot.Name]
			if place == nil then
				return nil
			end
			return place.rect, place.distance
		end,
		meter = function()
			return screen.meter
		end,
	}
	return screen
end

local function seeThrough(rig: Rig, spot: Model): number
	return rig.textOf(spot).TextTransparency
end

local function outlineSeeThrough(rig: Rig, spot: Model): number
	return (rig.textOf(spot):FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency
end

-- Two waiting Rare spots whose labels overlap on the screen. Rare_1 is the nearer one.
local function overlappingRares(screen: FakeScreen): (Rig, Model, Model)
	local rig = newRig(screen.view)
	local near = rig.addSpot("EggSpot_Rare_1", "Rare")
	local far = rig.addSpot("EggSpot_Rare_2", "Rare")
	screen.places["EggSpot_Rare_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
	screen.places["EggSpot_Rare_2"] = { rect = rect(330, 210, 80, 30), distance = 20 }
	rig.set(near, "Waiting", true)
	rig.set(far, "Waiting", true)
	return rig, near, far
end

describe("SpotLabels: two overlapping labels", function()
	it("fades the farther label to fully see-through over 0.15 s, words and outline together", function()
		local screen = newScreen()
		local rig, near, far = overlappingRares(screen)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(0.5, 3)
		expect(outlineSeeThrough(rig, far)).toBeCloseTo(0.5, 3)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
		expect(outlineSeeThrough(rig, far)).toBeCloseTo(1, 3)
		expect(seeThrough(rig, near)).toBe(0)
		expect(outlineSeeThrough(rig, near)).toBe(0)
	end)

	it("brings the label back over 0.15 s once they no longer overlap", function()
		local screen = newScreen()
		local rig, near, far = overlappingRares(screen)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
		-- the player walks on: the two labels separate
		screen.places["EggSpot_Rare_2"] = { rect = rect(500, 210, 80, 30), distance = 20 }
		rig.advance(0.075)
		-- the next check comes at 0.1 s after the last one, which was at the very first step
		rig.advance(0.075)
		expect(seeThrough(rig, far) < 1).toBe(true)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(0, 3)
		expect(outlineSeeThrough(rig, far)).toBeCloseTo(0, 3)
		expect(seeThrough(rig, near)).toBe(0)
	end)

	it("takes exactly 0.15 s to come back: half see-through after 0.075 s of coming back", function()
		local screen = newScreen()
		local rig, _near, far = overlappingRares(screen)
		rig.advance(0.075)
		rig.advance(0.075)
		screen.places["EggSpot_Rare_2"] = { rect = rect(500, 210, 80, 30), distance = 20 }
		rig.advance(0.075) -- a check comes: they have separated, and the fade back starts
		expect(seeThrough(rig, far)).toBeCloseTo(0.5, 3)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(0, 3)
	end)

	it("never touches the eggs themselves", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local near = rig.addSpot("EggSpot_Rare_1", "Rare")
		local far = rig.addSpot("EggSpot_Rare_2", "Rare")
		addEgg(near, 7)
		addEgg(far, 7)
		screen.places["EggSpot_Rare_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
		screen.places["EggSpot_Rare_2"] = { rect = rect(330, 210, 80, 30), distance = 20 }
		rig.set(near, "Waiting", true)
		rig.set(far, "Waiting", true)
		rig.advance(0.2)
		rig.advance(0.2)
		for _, spot in { near, far } do
			for _, descendant in spot:GetDescendants() do
				if descendant:IsA("BasePart") then
					expect(descendant.Transparency).toBe(0)
					expect(descendant.LocalTransparencyModifier).toBe(0)
				end
			end
		end
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
	end)

	it("leaves labels alone that only sit close together", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local one = rig.addSpot("EggSpot_Common_3", "Common")
		local two = rig.addSpot("EggSpot_Common_4", "Common")
		screen.places["EggSpot_Common_3"] = { rect = rect(300, 200, 60, 20), distance = 10 }
		screen.places["EggSpot_Common_4"] = { rect = rect(362, 200, 60, 20), distance = 12 }
		rig.set(one, "Waiting", true)
		rig.set(two, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, one)).toBe(0)
		expect(seeThrough(rig, two)).toBe(0)
	end)

	it("does not count a label that is behind the camera or past 75 studs", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local near = rig.addSpot("EggSpot_Rare_1", "Rare")
		local far = rig.addSpot("EggSpot_Rare_2", "Rare")
		-- the near spot has no place this moment (the screen couldn't measure it), the far one has
		screen.places["EggSpot_Rare_2"] = { rect = rect(330, 210, 80, 30), distance = 20 }
		rig.set(near, "Waiting", true)
		rig.set(far, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, near)).toBe(0)
		expect(seeThrough(rig, far)).toBe(0)
	end)
end)

describe("SpotLabels: where the screen is told the label is", function()
	it("is the label's intended world spot: straight above the egg's tip on a tilted spot", function()
		-- The screen is told the point Roblox draws the label at. On a tilted spot that must be the spot the label was
		-- meant for (straight above the egg's tip), so the rectangle matches the drawn words.
		local screen = newScreen()
		local rig = newRig(screen.view)
		local tilted = CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, -math.pi / 2) -- the Base's up points along +X
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare", tilted)
		addEgg(spot, 4)
		screen.places["EggSpot_Rare_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.1)
		local gui = rig.labelOf(spot) :: BillboardGui
		local base = gui.Adornee :: BasePart
		local tip = (tilted * CFrame.new(0, 0.1, 0)).Position + tilted.UpVector * 4
		local intended = tip + Vector3.new(0, 1 + gui.Size.Y.Scale / 2, 0)
		local told = screen.centres["EggSpot_Rare_1"]
		expect(told.X).toBeCloseTo(intended.X, 3)
		expect(told.Y).toBeCloseTo(intended.Y, 3)
		expect(told.Z).toBeCloseTo(intended.Z, 3)
		expect(told).never.toEqual(base.Position + gui.StudsOffsetWorldSpace)
	end)

	it("is the plain offset on a Base that stands straight", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		screen.places["EggSpot_Common_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.1)
		local gui = rig.labelOf(spot) :: BillboardGui
		expect(screen.centres["EggSpot_Common_1"]).toEqual(
			(gui.Adornee :: BasePart).Position + gui.StudsOffsetWorldSpace
		)
	end)
end)

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
