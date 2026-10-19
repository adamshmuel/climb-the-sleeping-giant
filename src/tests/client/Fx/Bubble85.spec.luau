--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bubble85 = require(StarterPlayer.StarterPlayerScripts.Client.Fx.Bubble85)

local function near(actual: number, wanted: number): boolean
	return math.abs(actual - wanted) < 1e-6
end

describe("Bubble85.size", function()
	it("is 120 by 40 px with words at font size 14 on a phone", function()
		local look = Bubble85.size(true)
		expect(look.size).toEqual(UDim2.fromOffset(120, 40))
		expect(look.textSize).toBe(14)
	end)

	it("is 170 by 52 px with words at font size 20 on a computer", function()
		local look = Bubble85.size(false)
		expect(look.size).toEqual(UDim2.fromOffset(170, 52))
		expect(look.textSize).toBe(20)
	end)
end)

describe("Bubble85.side", function()
	it("sits left of his nose and grows left when the camera's right side points toward his head", function()
		local side = Bubble85.side(0.5)
		expect(side.studsOffset).toEqual(Vector3.new(-14, -3, 2))
		expect(side.sizeOffset).toEqual(Vector2.new(-0.5, 0.5))
		expect(side.tailRight).toBe(true)
	end)

	it("sits right of his nose, with the tail bottom-left, when RightVector.Z is exactly 0", function()
		local side = Bubble85.side(0)
		expect(side.studsOffset).toEqual(Vector3.new(14, -3, 2))
		expect(side.sizeOffset).toEqual(Vector2.new(0.5, 0.5))
		expect(side.tailRight).toBe(false)
	end)

	it("sits right of his nose when the camera's right side points away from his head", function()
		local side = Bubble85.side(-0.9)
		expect(side.studsOffset).toEqual(Vector3.new(14, -3, 2))
		expect(side.sizeOffset).toEqual(Vector2.new(0.5, 0.5))
		expect(side.tailRight).toBe(false)
	end)

	it("puts the tail at the bottom corner nearest his nose", function()
		expect(Bubble85.tailPosition(true)).toEqual(UDim2.fromScale(0.93, 0.93))
		expect(Bubble85.tailPosition(false)).toEqual(UDim2.fromScale(0.07, 0.93))
	end)
end)

describe("Bubble85.popScale", function()
	it("starts from nothing at 0 seconds", function()
		expect(Bubble85.popScale(0, false)).toBe(0)
	end)

	it("reaches 110% at 0.1 seconds", function()
		expect(near(Bubble85.popScale(0.1, false), 1.1)).toBe(true)
	end)

	it("settles at exactly 100% at 0.2 seconds and stays there", function()
		expect(Bubble85.popScale(0.2, false)).toBe(1)
		expect(Bubble85.popScale(1.5, false)).toBe(1)
	end)

	it("grows between 0 and 110% before 0.1 seconds and comes back down between 0.1 and 0.2", function()
		local rising = Bubble85.popScale(0.05, false)
		expect(rising > 0 and rising < 1.1).toBe(true)
		local settling = Bubble85.popScale(0.15, false)
		expect(settling > 1 and settling < 1.1).toBe(true)
	end)

	it("is 100% at once with Reduce Motion on", function()
		expect(Bubble85.popScale(0, true)).toBe(1)
		expect(Bubble85.popScale(0.1, true)).toBe(1)
	end)
end)

describe("Bubble85.fade", function()
	it("is solid (0) until 3 seconds", function()
		expect(Bubble85.fade(0, false)).toBe(0)
		expect(Bubble85.fade(3, false)).toBe(0)
	end)

	it("is half see-through at 3.15 seconds", function()
		expect(near(Bubble85.fade(3.15, false), 0.5)).toBe(true)
	end)

	it("is fully see-through (1) from 3.3 seconds", function()
		expect(Bubble85.fade(3.3, false)).toBe(1)
		expect(Bubble85.fade(4, false)).toBe(1)
	end)

	it("never fades with Reduce Motion on", function()
		expect(Bubble85.fade(3.15, true)).toBe(0)
		expect(Bubble85.fade(3.3, true)).toBe(0)
	end)
end)

describe("Bubble85.showSeconds", function()
	it("is 3.3 seconds: 3 to read, then 0.3 to fade out", function()
		expect(near(Bubble85.showSeconds(false), 3.3)).toBe(true)
	end)

	it("is 3 seconds with Reduce Motion on, because it just goes", function()
		expect(Bubble85.showSeconds(true)).toBe(3)
	end)
end)
