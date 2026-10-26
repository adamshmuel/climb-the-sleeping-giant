--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)
local Helpers = require(script.Parent.Helpers)
local FIXED_DIRECTION = Helpers.FIXED_DIRECTION
local GIANT_PIVOT = Helpers.GIANT_PIVOT
local SHOULDER = Helpers.SHOULDER
local degreesBetween = Helpers.degreesBetween

describe("GiantFx.warningPlan", function()
	it("at 60 flutters the eyelids and fades the Z Z Z", function()
		expect(GiantFx.warningPlan(60)).toEqual({ "flutterEyelids", "fadeLetters" })
	end)

	it("at 85 stops the Z Z Z and puffs, mumbles, snorts twice, glows Tiptoe and shows the tip", function()
		expect(GiantFx.warningPlan(85)).toEqual({
			"stopLetters",
			"stopPuffs",
			"mumbleBubble",
			"snortNose",
			"tiptoeGlow",
			"standStillTip",
		})
	end)

	it("at 85 has no arm twitch (Rule 100: nothing he sleeps on moves)", function()
		expect(table.find(GiantFx.warningPlan(85), "twitchArm")).toBe(nil)
	end)

	it("does nothing for any other mark", function()
		expect(GiantFx.warningPlan(50)).toEqual({})
		expect(GiantFx.warningPlan(0)).toEqual({})
		expect(GiantFx.warningPlan("85")).toEqual({})
		expect(GiantFx.warningPlan(nil)).toEqual({})
	end)
end)

describe("GiantFx.flutterLift", function()
	it("is 0 at the start", function()
		expect(GiantFx.flutterLift(0, 1.4)).toBe(0)
	end)

	it("is the whole 1.4 at the top of each flutter, 0.25 s and 0.75 s in", function()
		expect(GiantFx.flutterLift(0.25, 1.4)).toBeCloseTo(1.4, 6)
		expect(GiantFx.flutterLift(0.75, 1.4)).toBeCloseTo(1.4, 6)
	end)

	it("is back at 0 between the two flutters, 0.5 s in", function()
		expect(GiantFx.flutterLift(0.5, 1.4)).toBeCloseTo(0, 6)
	end)

	it("is 0 at 1 s and after", function()
		expect(GiantFx.flutterLift(1, 1.4)).toBe(0)
		expect(GiantFx.flutterLift(5, 1.4)).toBe(0)
	end)

	it("eases: a tenth of the way up it has lifted far less than a tenth of the way", function()
		local lift = GiantFx.flutterLift(0.025, 1.4)
		expect(lift > 0).toBe(true)
		expect(lift < 0.14).toBe(true)
	end)
end)

describe("GiantFx snort settings", function()
	it("has bursts of 20 puffs, 0.5 seconds apart (style guide, the snort)", function()
		expect(GiantFx.snortPuffs).toBe(20)
		expect(GiantFx.snortGapSeconds).toBe(0.5)
	end)

	it("no longer has the arm twitch", function()
		expect((GiantFx :: any).twitchAngle).toBe(nil)
		expect((GiantFx :: any).twitchDegrees).toBe(nil)
	end)
end)

describe("GiantFx.fadedTransparency", function()
	it("takes a letter at 0.05 to half from 0.2 s to 1.8 s", function()
		expect(GiantFx.fadedTransparency(0.05, 0.2)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedTransparency(0.05, 1)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedTransparency(0.05, 1.8)).toBeCloseTo(0.5, 6)
	end)

	it("is about halfway, 0.275, 0.1 s into the fade, and again 0.1 s before the end", function()
		expect(GiantFx.fadedTransparency(0.05, 0.1)).toBeCloseTo(0.275, 6)
		expect(GiantFx.fadedTransparency(0.05, 1.9)).toBeCloseTo(0.275, 6)
	end)

	it("is the normal 0.05 at the start, at 2 s and after", function()
		expect(GiantFx.fadedTransparency(0.05, 0)).toBe(0.05)
		expect(GiantFx.fadedTransparency(0.05, 2)).toBe(0.05)
		expect(GiantFx.fadedTransparency(0.05, 9)).toBe(0.05)
	end)

	it("takes an outline at 0 to half at the hold and back to 0 at 2 s", function()
		expect(GiantFx.fadedTransparency(0, 1)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedTransparency(0, 2)).toBe(0)
	end)
end)

describe("GiantFx.fadedInTransparency", function()
	it("starts fully see-through, is half way at 0.1 s, and is the normal look from 0.2 s", function()
		expect(GiantFx.fadedInTransparency(0.05, 0)).toBe(1)
		expect(GiantFx.fadedInTransparency(0.05, 0.1)).toBeCloseTo(0.525, 6)
		expect(GiantFx.fadedInTransparency(0.05, 0.2)).toBe(0.05)
		expect(GiantFx.fadedInTransparency(0.05, 5)).toBe(0.05)
	end)

	it("takes an outline at 0 from fully see-through to 0 over 0.2 s", function()
		expect(GiantFx.fadedInTransparency(0, 0)).toBe(1)
		expect(GiantFx.fadedInTransparency(0, 0.1)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedInTransparency(0, 0.2)).toBe(0)
	end)
end)

describe("GiantFx.poseShare", function()
	it("is 0 at 0 seconds and before", function()
		expect(GiantFx.poseShare(0)).toBe(0)
		expect(GiantFx.poseShare(-1)).toBe(0)
	end)

	it("is 1 at 0.5 seconds and after", function()
		expect(GiantFx.poseSeconds).toBe(0.5)
		expect(GiantFx.poseShare(0.5)).toBe(1)
		expect(GiantFx.poseShare(0.6)).toBe(1)
		expect(GiantFx.poseShare(9)).toBe(1)
	end)

	it("is smooth: 0.5 at 0.25 seconds, and slow at the start", function()
		expect(GiantFx.poseShare(0.25)).toBeCloseTo(0.5, 6)
		expect(GiantFx.poseShare(0.05) < 0.1).toBe(true)
	end)
end)

describe("GiantFx.headTurn", function()
	local pivot = Vector3.new(0, 78, 18)

	it("at share 1 turns a point about the head pivot by the full tilt", function()
		local turn = GiantFx.headTurn(pivot, -12, 1)
		local probe = Vector3.new(3, 90, 30)
		local expected = pivot + CFrame.Angles(math.rad(-12), 0, 0):VectorToWorldSpace(probe - pivot)
		expect((turn:PointToWorldSpace(probe) - expected).Magnitude < 1e-3).toBe(true)
	end)

	it("keeps the pivot point where it is", function()
		local turn = GiantFx.headTurn(pivot, -12, 1)
		expect((turn:PointToWorldSpace(pivot) - pivot).Magnitude < 1e-3).toBe(true)
	end)

	it("at share 0 moves nothing", function()
		local turn = GiantFx.headTurn(pivot, -12, 0)
		for _, probe in { Vector3.zero, Vector3.new(3, 90, 30), Vector3.new(-40, 5, 9) } do
			expect((turn:PointToWorldSpace(probe) - probe).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("at share 0.5 turns half the tilt", function()
		local turn = GiantFx.headTurn(pivot, -12, 0.5)
		local _, angle = turn:ToAxisAngle()
		expect(math.deg(angle)).toBeCloseTo(6, 3)
	end)
end)

describe("GiantFx.armRaise", function()
	local shoulder = Vector3.new(40, 58, 8)
	local raise = Vector3.new(135, 0, 15)
	local full = CFrame.Angles(math.rad(135), 0, math.rad(15))

	it("at share 1 turns a point about the shoulder by the full raise", function()
		local turn = GiantFx.armRaise(shoulder, raise, 1)
		for _, probe in { Vector3.new(41, 68, 8), Vector3.new(45, 40, 20) } do
			local expected = shoulder + full:VectorToWorldSpace(probe - shoulder)
			expect((turn:PointToWorldSpace(probe) - expected).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("at share 0 moves nothing", function()
		local turn = GiantFx.armRaise(shoulder, raise, 0)
		for _, probe in { Vector3.zero, Vector3.new(41, 68, 8) } do
			expect((turn:PointToWorldSpace(probe) - probe).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("at share 0.5 turns half the angle about the same axis as the full raise", function()
		local fullAxis, fullAngle = full:ToAxisAngle()
		local half = GiantFx.armRaise(shoulder, raise, 0.5)
		local axis, angle = half.Rotation:ToAxisAngle()
		expect(angle).toBeCloseTo(fullAngle / 2, 3)
		expect(axis:Dot(fullAxis)).toBeCloseTo(1, 3)
	end)

	it("keeps the shoulder point where it is", function()
		local turn = GiantFx.armRaise(shoulder, raise, 1)
		expect((turn:PointToWorldSpace(shoulder) - shoulder).Magnitude < 1e-3).toBe(true)
	end)

	it("moves nothing for a raise of no angle", function()
		local turn = GiantFx.armRaise(shoulder, Vector3.zero, 1)
		expect((turn:PointToWorldSpace(Vector3.new(41, 68, 8)) - Vector3.new(41, 68, 8)).Magnitude < 1e-3).toBe(true)
	end)
end)

local function hasNaN(cframe: CFrame): boolean
	for _, value in { cframe:GetComponents() } do
		if value ~= value then
			return true
		end
	end
	return false
end

describe("GiantFx.slamTurn", function()
	local FROM = Vector3.new(0.3, 0.8, -0.5).Unit

	-- Where the direction `from` points after the turn.
	local function turned(turn: CFrame, from: Vector3): Vector3
		return turn:PointToWorldSpace(SHOULDER + from) - SHOULDER
	end

	it("moves nothing at share 0", function()
		local turn = GiantFx.slamTurn(SHOULDER, FROM, Vector3.new(-30, 2, -60), 0)
		expect(turn == CFrame.identity).toBe(true)
	end)

	it("at share 1 turns `from` to point exactly at the target (under 0.1 degree off)", function()
		local target = Vector3.new(-30, 2, -60)
		local turn = GiantFx.slamTurn(SHOULDER, FROM, target, 1)
		expect(degreesBetween(turned(turn, FROM), target - SHOULDER) < 0.1).toBe(true)
	end)

	it("at share 0.5 turns half the angle", function()
		local target = Vector3.new(70, 5, -40)
		local full = degreesBetween(FROM, target - SHOULDER)
		local turn = GiantFx.slamTurn(SHOULDER, FROM, target, 0.5)
		expect(math.abs(degreesBetween(FROM, turned(turn, FROM)) - full / 2) < 0.1).toBe(true)
	end)

	it("turns about the shoulder: the shoulder stays where it is", function()
		local turn = GiantFx.slamTurn(SHOULDER, FROM, Vector3.new(-30, 2, -60), 0.7)
		expect((turn:PointToWorldSpace(SHOULDER) - SHOULDER).Magnitude < 1e-3).toBe(true)
	end)

	it("gives no turn and no NaN when the directions are already the same", function()
		local target = SHOULDER + FROM * 80
		for _, share in { 0, 0.5, 1 } do
			local turn = GiantFx.slamTurn(SHOULDER, FROM, target, share)
			expect(hasNaN(turn)).toBe(false)
			expect(degreesBetween(turned(turn, FROM), FROM) < 0.1).toBe(true)
		end
	end)

	it("turns about an axis at right angles to `from` when the directions are exactly opposite", function()
		local target = SHOULDER - FROM * 80
		local turn = GiantFx.slamTurn(SHOULDER, FROM, target, 1)
		expect(hasNaN(turn)).toBe(false)
		expect(degreesBetween(turned(turn, FROM), -FROM) < 0.1).toBe(true)
		local half = GiantFx.slamTurn(SHOULDER, FROM, target, 0.5)
		expect(hasNaN(half)).toBe(false)
		expect(math.abs(degreesBetween(FROM, turned(half, FROM)) - 90) < 0.1).toBe(true)
	end)

	it("makes no NaN when the target is the shoulder itself or `from` is nothing", function()
		expect(hasNaN(GiantFx.slamTurn(SHOULDER, FROM, SHOULDER, 1))).toBe(false)
		expect(hasNaN(GiantFx.slamTurn(SHOULDER, Vector3.zero, Vector3.new(1, 2, 3), 1))).toBe(false)
	end)
end)

describe("GiantFx.slamShare", function()
	it("is 0 at the warning and before", function()
		expect(GiantFx.slamShare(0)).toBe(0)
		expect(GiantFx.slamShare(-1)).toBe(0)
	end)

	it("swings out smoothly over 0.5 seconds: half way at 0.25", function()
		expect(GiantFx.slamShare(0.25)).toBeCloseTo(0.5, 6)
		expect(GiantFx.slamShare(0.1) < 0.12).toBe(true) -- a straight line would be 0.2 here
	end)

	it("is all the way out from 0.5 seconds to 1.9 seconds, when the fist starts to lift", function()
		expect(GiantFx.slamShare(0.5)).toBe(1)
		expect(GiantFx.slamShare(1.2)).toBe(1)
		expect(GiantFx.slamShare(1.9)).toBe(1)
	end)

	it("comes back smoothly over the next 0.5 seconds: half way at 2.15", function()
		expect(GiantFx.slamShare(2.15)).toBeCloseTo(0.5, 6)
	end)

	it("is 0 from 2.4 seconds on", function()
		expect(GiantFx.slamShare(2.4)).toBeCloseTo(0, 6)
		expect(GiantFx.slamShare(3)).toBe(0)
	end)
end)

describe("GiantFx arm constants", function()
	it("has an arm 50 studs long, and a fixed pose 70 degrees forward and 25 degrees out", function()
		expect(GiantFx.armLength).toBe(50)
		expect(GiantFx.slamFixedForwardDegrees).toBe(70)
		expect(GiantFx.slamFixedOutDegrees).toBe(25)
	end)
end)

describe("GiantFx.slamFixedAim", function()
	it("is 50 studs from the shoulder, 70 degrees forward and 25 degrees out to his right", function()
		local aim = GiantFx.slamFixedAim(SHOULDER, GIANT_PIVOT)
		local offset = aim - SHOULDER
		expect(offset.Magnitude).toBeCloseTo(50, 2)
		expect((offset.Unit - FIXED_DIRECTION).Magnitude < 0.001).toBe(true)
	end)

	it("turns with the giant: a giant turned 90 degrees about Y turns the pose the same way", function()
		local turned = GIANT_PIVOT * CFrame.Angles(0, math.rad(90), 0)
		local offset = GiantFx.slamFixedAim(SHOULDER, turned) - SHOULDER
		-- A quarter turn about Y sends (x, y, z) to (z, y, -x).
		local expected = Vector3.new(FIXED_DIRECTION.Z, FIXED_DIRECTION.Y, -FIXED_DIRECTION.X)
		expect(offset.Magnitude).toBeCloseTo(50, 2)
		expect((offset.Unit - expected).Magnitude < 0.001).toBe(true)
	end)

	it("does not depend on where the giant stands, only on how he is turned", function()
		local moved = CFrame.new(300, 40, -20)
		local first = GiantFx.slamFixedAim(SHOULDER, GIANT_PIVOT) - SHOULDER
		local second = GiantFx.slamFixedAim(SHOULDER, moved) - SHOULDER
		expect((first - second).Magnitude < 0.001).toBe(true)
	end)
end)

describe("GiantFx.slamAim", function()
	local FROM = Vector3.new(0.141, 0.910, -0.390).Unit
	local POINT = Vector3.new(-97, 2, 1)
	local FIXED = Vector3.new(60, 30, -20)
	local SHARES = { 0.25, 0.5, 0.75, 1 }

	local function alwaysClear(_shoulder: Vector3, _direction: Vector3): boolean
		return true
	end

	it("gives the point itself when the arm is clear at every share", function()
		expect(GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, alwaysClear) == POINT).toBe(true)
	end)

	it("gives the fixed aim when the arm is blocked only at the full swing", function()
		local calls = 0
		local aim = GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(_shoulder: Vector3, _direction: Vector3)
			calls += 1
			return calls ~= 4
		end)
		expect(aim == FIXED).toBe(true)
	end)

	it("gives the fixed aim when the arm is blocked only half way through the swing", function()
		local calls = 0
		local aim = GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(_shoulder: Vector3, _direction: Vector3)
			calls += 1
			return calls ~= 2
		end)
		expect(aim == FIXED).toBe(true)
	end)

	it("gives the fixed aim when the arm is blocked only a quarter of the way", function()
		local calls = 0
		local aim = GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(_shoulder: Vector3, _direction: Vector3)
			calls += 1
			return calls ~= 1
		end)
		expect(aim == FIXED).toBe(true)
	end)

	it(
		"asks with the shoulder and the arm's direction at a quarter, half, three quarters and all of the swing",
		function()
			local seen: { { shoulder: Vector3, direction: Vector3 } } = {}
			GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(shoulder: Vector3, direction: Vector3)
				table.insert(seen, { shoulder = shoulder, direction = direction })
				return true
			end)
			expect(#seen).toBe(4)
			for index, share in SHARES do
				local expected = GiantFx.slamTurn(SHOULDER, FROM, POINT, share):VectorToWorldSpace(FROM)
				expect(seen[index].shoulder == SHOULDER).toBe(true)
				expect((seen[index].direction - expected).Magnitude < 1e-4).toBe(true)
			end
			-- The last one points at the point, and the first is a quarter of the way there.
			expect(degreesBetween(seen[4].direction, POINT - SHOULDER) < 0.1).toBe(true)
			expect(degreesBetween(seen[1].direction, FROM) > 1).toBe(true)
		end
	)
end)
