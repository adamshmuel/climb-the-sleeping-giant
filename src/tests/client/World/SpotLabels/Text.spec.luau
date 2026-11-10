--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)

describe("SpotLabels.text", function()
	it("names the rarity while an egg waits", function()
		expect(SpotLabels.text(true, "Rare")).toBe("Rare")
		expect(SpotLabels.text(true, "Uncommon")).toBe("Uncommon")
		expect(SpotLabels.text(true, "Common")).toBe("Common")
	end)

	it("shows nothing while Waiting is not set yet", function()
		expect(SpotLabels.text(nil, "Common")).toBeNil()
	end)

	it("shows nothing for an empty spot (spec Rule 77: no timer)", function()
		expect(SpotLabels.text(false, "Common")).toBeNil()
	end)
end)
