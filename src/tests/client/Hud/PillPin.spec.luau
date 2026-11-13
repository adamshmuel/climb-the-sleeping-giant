--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PillPin = require(StarterPlayer.StarterPlayerScripts.Client.Hud.PillPin)

-- The iPhone 14 play area, landscape, with a 40 px inset on the left and right (the notch and rounded corners).
local SAFE: PillPin.Box = { left = 40, top = 0, right = 709, bottom = 388 }
local WIDTH = 120
local HEIGHT = 44

-- A following box that is `above` px above the safe area's bottom and `left` px from the screen's left.
local function boxAt(above: number, left: number): PillPin.Box
	return { left = left, top = SAFE.bottom - above - HEIGHT, right = left + WIDTH, bottom = SAFE.bottom - above }
end

-- A brand-new touch player: nothing pressed, the pill following.
-- `behind = true` means the egg's point is behind the camera, so there is no box.
local function input(overrides: { [string]: any }): PillPin.Input
	local base: { [string]: any } =
		{ touch = true, pressed = false, current = "following", box = boxAt(150, 300), safe = SAFE }
	for key, value in overrides do
		base[key] = value
	end
	if base.behind then
		base.box = nil
	end
	return base :: PillPin.Input
end

describe("PillPin.decide", function()
	it("keeps a following box that is fully above the 84 px line following", function()
		expect(PillPin.decide(input({ box = boxAt(84, 300) }))).toBe("following")
		expect(PillPin.decide(input({ box = boxAt(200, 300) }))).toBe("following")
	end)

	it("pins a box with any part lower than the 64 px line", function()
		expect(PillPin.decide(input({ box = boxAt(63, 300) }))).toBe("pinned")
		expect(PillPin.decide(input({ box = boxAt(-20, 300) }))).toBe("pinned")
	end)

	it("pins a box past the left, right or top edge", function()
		expect(PillPin.decide(input({ box = boxAt(150, 30) }))).toBe("pinned")
		expect(PillPin.decide(input({ box = boxAt(150, 600) }))).toBe("pinned")
		local tooHigh: PillPin.Box = { left = 300, top = -10, right = 420, bottom = 34 }
		expect(PillPin.decide(input({ box = tooHigh }))).toBe("pinned")
	end)

	it("pins when the egg's point is behind the camera", function()
		expect(PillPin.decide(input({ behind = true }))).toBe("pinned")
	end)

	it("keeps a pinned pill pinned while its box is between the two lines", function()
		expect(PillPin.decide(input({ current = "pinned", box = boxAt(74, 300) }))).toBe("pinned")
	end)

	it("never switches while the pill is pressed", function()
		expect(PillPin.decide(input({ pressed = true, current = "following", box = boxAt(10, 300) }))).toBe("following")
		expect(PillPin.decide(input({ pressed = true, current = "pinned", box = boxAt(200, 300) }))).toBe("pinned")
	end)

	it("never pins on a computer screen", function()
		expect(PillPin.decide(input({ touch = false, box = boxAt(10, 300) }))).toBe("following")
		expect(PillPin.decide(input({ touch = false, behind = true }))).toBe("following")
	end)
end)
