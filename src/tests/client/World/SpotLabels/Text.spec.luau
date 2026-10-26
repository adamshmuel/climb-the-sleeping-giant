--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)

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
