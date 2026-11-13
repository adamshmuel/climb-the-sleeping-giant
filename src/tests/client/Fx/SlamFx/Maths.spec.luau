--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamFx = require(Client.Fx.SlamFx)
local Theme = require(Client.Hud.Theme)

describe("SlamFx constants", function()
	it("keeps the fist down for 0.4 seconds, for the giant's arm to read", function()
		expect(SlamFx.FIST_DOWN_SECONDS).toBe(0.4)
	end)
end)

describe("Theme slam colours", function()
	it("has the style guide's gold and red for the slam circle", function()
		expect(Theme.slamGold == Color3.fromHex("FFC93C")).toBe(true)
		expect(Theme.slamRed == Color3.fromHex("E0233A")).toBe(true)
	end)

	it("keeps the slam red apart from the banner's red, which stays FF3B4E", function()
		expect(Theme.bannerRed == Color3.fromHex("FF3B4E")).toBe(true)
		expect(Theme.slamRed == Theme.bannerRed).toBe(false)
	end)
end)

describe("SlamFx.fistHeight", function()
	it("is nil before the fist appears, 0.6 seconds before the landing", function()
		expect(SlamFx.fistHeight(-0.61)).toBeNil()
		expect(SlamFx.fistHeight(-5)).toBeNil()
	end)

	it("starts 45 studs up, 0.6 seconds before the landing", function()
		expect(SlamFx.fistHeight(-0.6)).toBe(45)
	end)

	it("touches the surface at the landing", function()
		expect(SlamFx.fistHeight(0)).toBeCloseTo(0, 2)
	end)

	it("stays down from the landing until 0.4 seconds after it", function()
		expect(SlamFx.fistHeight(0.2)).toBeCloseTo(0, 2)
		expect(SlamFx.fistHeight(0.4)).toBeCloseTo(0, 2)
	end)

	it("is 45 studs up again 0.8 seconds after the landing", function()
		expect(SlamFx.fistHeight(0.8)).toBeCloseTo(45, 2)
	end)

	it("is nil once it has lifted away", function()
		expect(SlamFx.fistHeight(0.81)).toBeNil()
		expect(SlamFx.fistHeight(3)).toBeNil()
	end)

	it("falls faster and faster: the last tenth of a second drops more than the first", function()
		local first = (SlamFx.fistHeight(-0.6) :: number) - (SlamFx.fistHeight(-0.5) :: number)
		local last = (SlamFx.fistHeight(-0.1) :: number) - (SlamFx.fistHeight(0) :: number)
		expect(last > first).toBe(true)
	end)

	it("lifts slowly at first: 45 times the square of how far through the lift it is", function()
		expect(SlamFx.fistHeight(0.6)).toBeCloseTo(45 * 0.25, 2)
		local first = (SlamFx.fistHeight(0.5) :: number) - (SlamFx.fistHeight(0.4) :: number)
		local last = (SlamFx.fistHeight(0.8) :: number) - (SlamFx.fistHeight(0.7) :: number)
		expect(last > first).toBe(true)
	end)
end)

describe("SlamFx.circleTransparency", function()
	it("is 0, solid, until the fist starts to lift, 0.4 seconds after the landing", function()
		expect(SlamFx.circleTransparency(-1.5)).toBe(0)
		expect(SlamFx.circleTransparency(0)).toBe(0)
		expect(SlamFx.circleTransparency(0.39)).toBe(0)
		expect(SlamFx.circleTransparency(0.4)).toBe(0)
	end)

	it("fades in a straight line to see-through over the next 0.3 seconds", function()
		expect(SlamFx.circleTransparency(0.55)).toBeCloseTo(0.5, 3)
		expect(SlamFx.circleTransparency(0.7)).toBeCloseTo(1, 3)
	end)

	it("is nil once the circle is gone", function()
		expect(SlamFx.circleTransparency(0.71)).toBeNil()
		expect(SlamFx.circleTransparency(5)).toBeNil()
	end)
end)
