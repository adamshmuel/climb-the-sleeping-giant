--!strict
-- The fist on your own screen (spec 6, Rule 13, "The fist on your own screen") and the slam sounds' places.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local Helpers = require(script.Parent.Helpers)
local POINT = Helpers.POINT
local cleanUp = Helpers.cleanUp
local newRig = Helpers.newRig
local theFist = Helpers.theFist

afterEach(cleanUp)

-- POINT's surface is level at POINT.Y (Helpers' default plane). A body standing there: middle 3.5 above it, head top
-- 4.5 above it (HumanoidRootPart middle and Head top of a player, roughly).
local OWN = Config.Wake.OwnFistTransparency
local MIDDLE_ABOVE_SURFACE = 3.5
local HEAD_TOP_ABOVE_SURFACE = 4.5
local HEAD_TOP_Y = POINT.Y + HEAD_TOP_ABOVE_SURFACE
local LANDING = 1.5 -- seconds from the warning to landsAt in these tests

type Body = { middle: Vector3, headTopY: number }

local function bodyAt(position: Vector3): Body
	return {
		middle = Vector3.new(position.X, POINT.Y + MIDDLE_ABOVE_SURFACE, position.Z),
		headTopY = HEAD_TOP_Y,
	}
end

-- A rig whose own body is whatever `current.body` is when the slam lands (nil means no character).
local function newBodyRig(current: { body: Body? }, sounds: { { name: string, at: Vector3? } }?)
	return newRig({
		ownBody = function()
			return current.body
		end,
		playSound = if sounds ~= nil
			then function(name: string, at: Vector3?)
				table.insert(sounds, { name = name, at = at })
			end
			else nil,
	})
end

-- Every part of the fist, or an empty list if there is no fist.
local function fistParts(rig: Helpers.Rig): { BasePart }
	local fist = theFist(rig)
	local found: { BasePart } = {}
	if fist ~= nil then
		for _, descendant in fist:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(found, descendant)
			end
		end
	end
	return found
end

-- Every fist part has this transparency (and there is at least one part).
local function allFistPartsAre(rig: Helpers.Rig, transparency: number): boolean
	local parts = fistParts(rig)
	if #parts == 0 then
		return false
	end
	for _, part in parts do
		if math.abs(part.Transparency - transparency) > 1e-3 then
			return false
		end
	end
	return true
end

-- Warns and moves the clock to `secondsAfterLanding` after the landing, in small steps (the fist is redrawn each frame).
local function playTo(rig: Helpers.Rig, point: Vector3, secondsAfterLanding: number)
	rig.warn(1, point, LANDING)
	rig.advance(LANDING - 0.6) -- the fist appears
	rig.advance(0.6 + secondsAfterLanding)
end

describe("SlamFx.start: the fist on your own screen", function()
	it("is see-through from the landing when your body is under the hand", function()
		local rig = newBodyRig({ body = bodyAt(POINT) })
		playTo(rig, POINT, 0.1)
		expect(allFistPartsAre(rig, OWN)).toBe(true)
	end)

	it("is solid again once its bottom is above the top of your head", function()
		local rig = newBodyRig({ body = bodyAt(POINT) })
		-- 0.7 seconds after the landing the fist has lifted 25 studs, far over a head top 4.5 studs above the surface.
		playTo(rig, POINT, 0.7)
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, 0)).toBe(true)
	end)

	it("is solid while it falls, before the landing", function()
		local rig = newBodyRig({ body = bodyAt(POINT) })
		rig.warn(1, POINT, LANDING)
		rig.advance(LANDING - 0.6)
		rig.advance(0.3) -- 0.3 seconds before the landing
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, 0)).toBe(true)
	end)

	it("is solid throughout for a body outside the circle", function()
		local radius = Config.Wake.SlamCircleDiameter / 2
		local rig = newBodyRig({ body = bodyAt(POINT + Vector3.new(radius + 5, 0, 0)) })
		playTo(rig, POINT, 0.1)
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, 0)).toBe(true)
	end)

	it("is solid for a body above the top of the hand's reach", function()
		local high = bodyAt(POINT)
		high.middle = Vector3.new(POINT.X, POINT.Y + Config.Wake.HandAboveStuds + 1, POINT.Z)
		high.headTopY = high.middle.Y + 1
		local rig = newBodyRig({ body = high })
		playTo(rig, POINT, 0.1)
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, 0)).toBe(true)
	end)

	it("is always solid when there is no ownBody dependency", function()
		local rig = newRig()
		playTo(rig, POINT, 0.1)
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, 0)).toBe(true)
	end)

	it("keeps a part that is already fully see-through at 1 (never lowers it)", function()
		local rig = newBodyRig({ body = bodyAt(POINT) })
		for _, descendant in rig.template:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			end
		end
		playTo(rig, POINT, 0.1)
		expect(#fistParts(rig) > 0).toBe(true)
		expect(allFistPartsAre(rig, 1)).toBe(true)
		rig.advance(0.6) -- lifted over the head: back to its own transparency, which is 1
		expect(allFistPartsAre(rig, 1)).toBe(true)
	end)

	it("decides each slam on its own", function()
		local current: { body: Body? } = { body = bodyAt(POINT) }
		local rig = newBodyRig(current)
		rig.warn(1, POINT, LANDING)
		rig.advance(LANDING + 0.1)
		expect(allFistPartsAre(rig, OWN)).toBe(true)
		rig.advance(1) -- slam 1 is over
		expect(theFist(rig)).toBeNil()
		current.body = nil -- the body has left: the next slam does not see it
		rig.warn(2, POINT, LANDING)
		rig.advance(LANDING + 0.1)
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, 0)).toBe(true)
	end)

	it("starts the see-through when SlamLanded arrives before landsAt", function()
		local rig = newBodyRig({ body = bodyAt(POINT) })
		rig.warn(1, POINT, LANDING)
		rig.advance(0.5) -- the fist is not there yet
		expect(theFist(rig)).toBeNil()
		rig.land(1, POINT)
		expect(theFist(rig)).never.toBeNil()
		expect(allFistPartsAre(rig, OWN)).toBe(true)
	end)
end)

describe("SlamFx.start: the slam sounds' places", function()
	it("plays SlamCircle once at the warning, with the slam's point", function()
		local sounds: { { name: string, at: Vector3? } } = {}
		local rig = newBodyRig({ body = nil }, sounds)
		rig.warn(1, POINT, LANDING)
		rig.advance(0.5)
		expect(#sounds).toBe(1)
		expect(sounds[1].name).toBe("SlamCircle")
		expect(sounds[1].at).toBe(POINT)
	end)

	it("plays SlamThud once at the landing, with the slam's point", function()
		local sounds: { { name: string, at: Vector3? } } = {}
		local rig = newBodyRig({ body = nil }, sounds)
		rig.warn(1, POINT, LANDING)
		rig.advance(LANDING - 0.1)
		expect(#sounds).toBe(1) -- only the circle's sound so far
		rig.advance(0.2)
		rig.advance(0.5)
		expect(#sounds).toBe(2)
		expect(sounds[2].name).toBe("SlamThud")
		expect(sounds[2].at).toBe(POINT)
	end)

	it("plays no sound and draws as usual without a playSound dependency", function()
		local rig = newBodyRig({ body = bodyAt(POINT) })
		playTo(rig, POINT, 0.1)
		expect(allFistPartsAre(rig, OWN)).toBe(true)
	end)
end)
