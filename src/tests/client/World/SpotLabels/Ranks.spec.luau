--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Theme = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Theme)
local Helpers = require(script.Parent.Helpers)

afterEach(Helpers.cleanUp)

-- Spec Rule 52: the rank shows everywhere, in the rank's colour. Rule 77: an empty nest shows nothing.
describe("SpotLabels: Epic and Legendary", function()
	it("shows Epic in the Epic colour on a waiting nest", function()
		local rig = Helpers.newRig()
		local spot = rig.addSpot("EggSpot_Epic_1", "Epic")
		rig.set(spot, "Waiting", true)
		expect(rig.textOf(spot).Text).toBe("Epic")
		expect(rig.textOf(spot).TextColor3 == Theme.rarity.Epic.main).toBe(true)
	end)

	it("shows Legendary in the Legendary colour on a waiting nest", function()
		local rig = Helpers.newRig()
		local spot = rig.addSpot("EggSpot_Legendary_1", "Legendary")
		rig.set(spot, "Waiting", true)
		expect(rig.textOf(spot).Text).toBe("Legendary")
		expect(rig.textOf(spot).TextColor3 == Theme.rarity.Legendary.main).toBe(true)
	end)

	it("shows no label on an empty Epic nest", function()
		local rig = Helpers.newRig()
		local spot = rig.addSpot("EggSpot_Epic_1", "Epic")
		rig.set(spot, "Waiting", false)
		local gui = rig.labelOf(spot)
		expect(gui == nil or gui.Enabled == false).toBe(true)
	end)
end)
