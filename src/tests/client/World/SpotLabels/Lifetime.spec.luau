--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)
local Theme = require(Client.Hud.Theme)
local Helpers = require(script.Parent.Helpers)
local addEgg = Helpers.addEgg
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig
local newSignal = Helpers.newSignal
local newSpotModel = Helpers.newSpotModel
local stops = Helpers.stops

afterEach(cleanUp)

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

	-- Spec Rule 85: the bottom of the word sits 8 studs above the top of the nest base, or 1 stud above the egg's top
	-- when that is higher.
	it("sits 8 studs above the top of the nest base when the egg is short", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		addEgg(spot, 5.5)
		rig.set(spot, "Waiting", true)
		local baseTop = 10 + 0.1
		expect(bottomOf(rig.labelOf(spot) :: BillboardGui)).toBeCloseTo(baseTop + 8, 3)
	end)

	it("sits 1 stud above the top of an egg taller than 7 studs", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		addEgg(spot, 7.5)
		rig.set(spot, "Waiting", true)
		local baseTop = 10 + 0.1
		expect(bottomOf(rig.labelOf(spot) :: BillboardGui)).toBeCloseTo(baseTop + 8.5, 3)
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

	it("sits above the full-size egg even when the egg is already shrunk to a speck when Waiting turns true", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		-- 6 studs tall: at the 0.01 scale NestPop uses it is 0.06, above the 0.05 smallest size a part can have, so
		-- the shrunk egg's size is exact (a 4-stud egg would be held at 0.05 and read as 5 studs when divided back).
		local egg = addEgg(spot, 6)
		egg:ScaleTo(0.01)
		rig.set(spot, "Waiting", true)
		local baseTop = 10 + 0.1
		expect(bottomOf(rig.labelOf(spot) :: BillboardGui)).toBeCloseTo(baseTop + 8, 2)
	end)
end)

describe("SpotLabels: an empty spot", function()
	-- Spec Rule 77: an empty nest shows no timer, so a RefillAt left over from the server shows nothing.
	it("shows no label, even with a RefillAt left over", function()
		local rig = newRig()
		local spot = rig.addSpot("EggSpot_Common_1", "Common")
		rig.set(spot, "Waiting", true)
		rig.set(spot, "RefillAt", 142)
		rig.set(spot, "Waiting", false)
		expect((rig.labelOf(spot) :: BillboardGui).Enabled).toBe(false)
		-- and the frames never bring a countdown back
		rig.advance(1)
		expect((rig.labelOf(spot) :: BillboardGui).Enabled).toBe(false)
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
