--!strict
-- The Zs on the meter follow the world's Z Z Z (plan 3 Task 8f): GiantFx tells them, through onSignsChanged, when to
-- show, fade, hide and go big. The 60 and 85 and 75 rules stay in GiantFx; the meter Zs never copy them.
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
local cleanUp = Helpers.cleanUp
local newRig = Helpers.newRig

afterEach(cleanUp)

local function last(signs: { string }): string?
	return signs[#signs]
end

describe("GiantFx.start: the Zs on the meter", function()
	it("starts them shown while he sleeps", function()
		local rig = newRig()
		expect(rig.signs).toEqual({ "shown" })
	end)

	it("starts them big for a player who joins in Heavy Sleep", function()
		local rig = newRig(false, "HeavySleep")
		expect(rig.signs).toEqual({ "heavy" })
	end)

	it("fades them with the world Z Z Z at 60 and shows them again after the 2 second fade", function()
		local rig = newRig()
		rig.fire(60)
		expect(last(rig.signs)).toBe("faded")
		rig.advance(1)
		expect(last(rig.signs)).toBe("faded")
		rig.advance(1)
		expect(rig.signs).toEqual({ "shown", "faded", "shown" })
	end)

	it("says faded once for two 60 warnings back to back", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.5)
		rig.fire(60)
		expect(rig.signs).toEqual({ "shown", "faded" })
	end)

	it("hides them at 85 and keeps them hidden until the meter falls to 75", function()
		local rig = newRig()
		rig.fire(85)
		expect(last(rig.signs)).toBe("hidden")
		rig.setState(80, "Asleep")
		expect(last(rig.signs)).toBe("hidden")
		rig.setState(75, "Asleep")
		expect(last(rig.signs)).toBe("shown")
	end)

	it("hides them when he wakes and shows them again when he sleeps", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(last(rig.signs)).toBe("hidden")
		rig.setState(30, "Asleep")
		expect(last(rig.signs)).toBe("shown")
	end)

	it("makes them big in Heavy Sleep and normal after it", function()
		local rig = newRig()
		rig.setState(50, "HeavySleep")
		expect(last(rig.signs)).toBe("heavy")
		rig.setState(50, "Asleep")
		expect(last(rig.signs)).toBe("shown")
	end)
end)
