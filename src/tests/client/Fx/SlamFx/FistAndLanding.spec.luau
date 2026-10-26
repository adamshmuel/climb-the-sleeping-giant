--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamFx = require(Client.Fx.SlamFx)
local Theme = require(Client.Hud.Theme)
local Helpers = require(script.Parent.Helpers)
local POINT = Helpers.POINT
local SLOPE_58 = Helpers.SLOPE_58
local UP = Helpers.UP
local cleanUp = Helpers.cleanUp
local countChildren = Helpers.countChildren
local expectNear = Helpers.expectNear
local newRig = Helpers.newRig
local theDust = Helpers.theDust
local theFist = Helpers.theFist
local transparencyOfPieces = Helpers.transparencyOfPieces
local warnAndBuild = Helpers.warnAndBuild

afterEach(cleanUp)

local function bottomOf(model: Model): number
	local cframe, size = model:GetBoundingBox()
	return cframe.Position.Y - size.Y / 2
end

local function centreOf(model: Model): Vector3
	return (model:GetBoundingBox()).Position
end

describe("SlamFx.start: the fist", function()
	it("is not there before 0.6 seconds ahead of the landing", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(0.5)
		expect(theFist(rig)).toBeNil()
		rig.advance(0.39)
		expect(theFist(rig)).toBeNil()
	end)

	it("appears 0.6 seconds before the landing, with its bottom 45 studs straight above the point", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(0.9)
		local fist = theFist(rig) :: Model
		expect(fist).never.toBeNil()
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y + 45, 1)
		expect(centreOf(fist).X).toBeCloseTo(POINT.X, 2)
		expect(centreOf(fist).Z).toBeCloseTo(POINT.Z, 2)
	end)

	it("falls faster and faster, following the fall curve", function()
		local rig = newRig()
		local landsAt = rig.warn(1, POINT, 1.5)
		rig.advance(0.9)
		rig.advance(0.3) -- 0.3 before the landing
		local fist = theFist(rig) :: Model
		local expected = SlamFx.fistHeight(rig.now() - landsAt) :: number
		expect(expected > 0 and expected < 45).toBe(true)
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y + expected, 1)
	end)

	it("touches the point at the landing time", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y, 1)
		expect(centreOf(fist).X).toBeCloseTo(POINT.X, 2)
		expect(centreOf(fist).Z).toBeCloseTo(POINT.Z, 2)
	end)

	it("stays down for 0.4 seconds, then lifts, and is destroyed after 0.8 seconds", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		rig.advance(0.35)
		expect(bottomOf(theFist(rig) :: Model)).toBeCloseTo(POINT.Y, 1)
		rig.advance(0.25) -- 0.6 s after the landing
		expect(bottomOf(theFist(rig) :: Model)).toBeCloseTo(POINT.Y + 45 * 0.25, 0)
		rig.advance(0.25) -- 0.85 s
		expect(theFist(rig)).toBeNil()
	end)

	it("is a copy: the template stays where it was and is not put in the world", function()
		local rig = newRig()
		local before = rig.template:GetPivot()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		expect(fist).never.toBeNil()
		expect(fist).never.toBe(rig.template)
		expect(rig.template.Parent).toBeNil()
		expect(rig.template:GetPivot() == before).toBe(true)
		local geometry = rig.template:FindFirstChild("body_geom", true) :: Part
		expect(geometry.Anchored).toBe(false)
	end)

	it("makes every part of the copy anchored, not solid, not hit by rays and not touchable", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		local count = 0
		for _, part in fist:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				expect(part.Anchored).toBe(true)
				expect(part.CanCollide).toBe(false)
				expect(part.CanQuery).toBe(false)
				expect(part.CanTouch).toBe(false)
			end
		end
		expect(count).toBe(2)
	end)

	it("stays upright and keeps the template's turn, even when the circle is tilted", function()
		local rig = newRig()
		rig.setNormal(SLOPE_58)
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		local want = rig.template:GetPivot().Rotation
		local got = fist:GetPivot().Rotation
		expectNear(got.XVector, want.XVector)
		expectNear(got.YVector, want.YVector)
		expectNear(got.ZVector, want.ZVector)
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y, 1)
	end)
end)

describe("SlamFx.start: the landing", function()
	it("bursts the dust 36 and the sparkles 40, once, when the landing time comes", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.25)
		expect(#rig.bursts).toBe(0)
		rig.advance(0.25)
		expect(#rig.bursts).toBe(2)
		expect(rig.bursts[1].name).toBe("SlamDust")
		expect(rig.bursts[1].count).toBe(36)
		expect(rig.bursts[2].name).toBe("SlamSparkles")
		expect(rig.bursts[2].count).toBe(40)
		rig.advance(0.1)
		rig.advance(0.1)
		expect(#rig.bursts).toBe(2)
	end)

	it(
		"makes an invisible, untouchable part 2 studs above the point for the two emitters, and no dust before the landing",
		function()
			local rig = newRig()
			rig.warn(1, POINT, 1.5)
			rig.advance(1.25)
			expect(theDust(rig)).toBeNil()
			rig.advance(0.25)
			local dust = theDust(rig) :: Part
			expect(dust).never.toBeNil()
			expectNear(dust.Position, POINT + UP * 2)
			expect(dust.Size == Vector3.new(1, 1, 1)).toBe(true)
			expect(dust.Transparency).toBe(1)
			expect(dust.Anchored).toBe(true)
			expect(dust.CanCollide).toBe(false)
			expect(dust.CanQuery).toBe(false)
			expect(dust.CanTouch).toBe(false)
			expect(rig.bursts[1].parent).toBe(dust)
			expect(rig.bursts[2].parent).toBe(dust)
		end
	)

	it("makes the dust a white smoke and the sparkles gold, both off until they are told to burst", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local smoke, sparkles = rig.bursts[1].emitter, rig.bursts[2].emitter
		expect(smoke.Texture).toBe("rbxasset://textures/particles/smoke_main.dds")
		expect(sparkles.Texture).toBe("rbxasset://textures/particles/sparkles_main.dds")
		expect(smoke.Enabled).toBe(false)
		expect(sparkles.Enabled).toBe(false)
		expect(sparkles.Color.Keypoints[1].Value == Theme.slamGold).toBe(true)
		expect(sparkles.Color.Keypoints[#sparkles.Color.Keypoints].Value == Theme.slamGold).toBe(true)
		expect(smoke.Color.Keypoints[1].Value == Color3.new(1, 1, 1)).toBe(true)
	end)

	it("puts the dust part 2 studs above the point along a slope's normal too, and keeps it upright", function()
		local rig = newRig()
		rig.setNormal(SLOPE_58)
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local dust = theDust(rig) :: Part
		expectNear(dust.Position, POINT + SLOPE_58 * 2)
		-- Upright: the puffs go up, whatever the slope.
		expectNear(dust.CFrame.XVector, Vector3.xAxis)
		expectNear(dust.CFrame.YVector, UP)
		expectNear(dust.CFrame.ZVector, Vector3.zAxis)
	end)

	it("puts the dust part 2 studs above the point even for a normal that is not 1 long or has no direction", function()
		local longRig = newRig()
		longRig.setNormal(Vector3.new(0, 5, 0))
		longRig.warn(1, POINT, 1.5)
		longRig.advance(1.5)
		expectNear((theDust(longRig) :: Part).Position, POINT + UP * 2)
		local noneRig = newRig()
		noneRig.setNormal(Vector3.zero)
		noneRig.warn(1, POINT, 1.5)
		noneRig.advance(1.5)
		expectNear((theDust(noneRig) :: Part).Position, POINT + UP * 2)
	end)

	it("keeps the dust part upright on level ground", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local dust = theDust(rig) :: Part
		expectNear(dust.CFrame.YVector, UP)
		expectNear(dust.CFrame.XVector, Vector3.xAxis)
	end)

	-- The emitters as they are at the landing, for the look tests below.
	local function emittersAtLanding(): (ParticleEmitter, ParticleEmitter)
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		return rig.bursts[1].emitter, rig.bursts[2].emitter
	end

	it("makes the dust pure white all through its life", function()
		local smoke = emittersAtLanding()
		expect(smoke.Name).toBe("SlamDust")
		for _, keypoint in smoke.Color.Keypoints do
			expect(keypoint.Value == Color3.fromHex("FFFFFF")).toBe(true)
		end
	end)

	it("makes each dust puff grow from 8 to 16 studs", function()
		local smoke = emittersAtLanding()
		local size = smoke.Size.Keypoints
		expect(#size).toBe(2)
		expect(size[1].Time).toBe(0)
		expect(size[1].Value).toBeCloseTo(8, 3)
		expect(size[2].Time).toBe(1)
		expect(size[2].Value).toBeCloseTo(16, 3)
	end)

	it("makes the dust 5% see-through at the start and fully clear at the end", function()
		local smoke = emittersAtLanding()
		local clear = smoke.Transparency.Keypoints
		expect(#clear).toBe(2)
		expect(clear[1].Time).toBe(0)
		expect(clear[1].Value).toBeCloseTo(0.05, 3)
		expect(clear[2].Time).toBe(1)
		expect(clear[2].Value).toBeCloseTo(1, 3)
	end)

	it("gives each dust puff a life of 0.9 to 1.3 seconds", function()
		local smoke = emittersAtLanding()
		expect(smoke.Lifetime.Min).toBeCloseTo(0.9, 3)
		expect(smoke.Lifetime.Max).toBeCloseTo(1.3, 3)
	end)

	it("throws the dust out at 20 to 32 studs a second", function()
		local smoke = emittersAtLanding()
		expect(smoke.Speed.Min).toBeCloseTo(20, 3)
		expect(smoke.Speed.Max).toBeCloseTo(32, 3)
	end)

	it("spreads the dust 85 degrees each way", function()
		local smoke = emittersAtLanding()
		expect(smoke.SpreadAngle == Vector2.new(85, 85)).toBe(true)
	end)

	it("slows the dust down with a drag of 4", function()
		local smoke = emittersAtLanding()
		expect(smoke.Drag).toBeCloseTo(4, 3)
	end)

	it("gives the dust a light emission of 0.2", function()
		local smoke = emittersAtLanding()
		expect(smoke.LightEmission).toBeCloseTo(0.2, 3)
	end)

	it("gives each sparkle one size for its whole life: 1.1 studs, from start to end", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Name).toBe("SlamSparkles")
		local size = sparkles.Size.Keypoints
		expect(#size).toBe(2)
		expect(size[1].Time).toBe(0)
		expect(size[2].Time).toBe(1)
		expect(size[1].Value).toBeCloseTo(1.1, 3)
		expect(size[2].Value).toBeCloseTo(1.1, 3)
	end)

	it("makes the sparkles vary by 0.3 studs either way, so they run from 0.8 to 1.4 studs", function()
		local _, sparkles = emittersAtLanding()
		for _, keypoint in sparkles.Size.Keypoints do
			expect(keypoint.Envelope).toBeCloseTo(0.3, 3)
		end
	end)

	it("gives the sparkles full light emission", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.LightEmission).toBeCloseTo(1, 3)
	end)

	it("keeps the sparkles' speed of 24 to 44", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Speed.Min).toBeCloseTo(24, 3)
		expect(sparkles.Speed.Max).toBeCloseTo(44, 3)
	end)

	it("keeps the sparkles' spread of 40 degrees", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.SpreadAngle == Vector2.new(40, 40)).toBe(true)
	end)

	it("keeps the sparkles' gravity", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Acceleration == Vector3.new(0, -50, 0)).toBe(true)
	end)

	it("keeps the sparkles' life of 0.5 to 0.9 seconds", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Lifetime.Min).toBeCloseTo(0.5, 3)
		expect(sparkles.Lifetime.Max).toBeCloseTo(0.9, 3)
	end)

	it("keeps the dust part until 1.3 seconds after the landing, the longest life", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		rig.advance(1.25)
		expect(theDust(rig)).never.toBeNil()
		rig.advance(0.1)
		expect(theDust(rig)).toBeNil()
	end)

	it("gives the particles a short life, gone within about a second", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		expect(#rig.bursts).toBe(2)
		for _, burst in rig.bursts do
			expect(burst.emitter.Lifetime.Max <= 1.3).toBe(true)
			expect(burst.emitter.Lifetime.Min > 0).toBe(true)
		end
	end)

	it("lands at once when SlamLanded comes before the landing time, and puts the fist on the point", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.2) -- 0.3 s before the landing time
		expect(#rig.bursts).toBe(0)
		expect(bottomOf(theFist(rig) :: Model) > POINT.Y + 1).toBe(true)
		rig.land(1, POINT)
		expect(#rig.bursts).toBe(2)
		rig.advance(0)
		expect(bottomOf(theFist(rig) :: Model)).toBeCloseTo(POINT.Y, 1)
		expect(theDust(rig)).never.toBeNil()
	end)

	it("counts the fade and the lift from the moment SlamLanded came", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		rig.advance(1.2)
		rig.land(1, POINT)
		rig.advance(0.55) -- 0.55 s after the landing, though the landing time is still 0.25 s away
		expect(transparencyOfPieces(rig) :: number).toBeCloseTo(0.5, 2)
		rig.advance(0.2) -- 0.75 s: the circle is gone, the fist is lifting
		expect(#rig.pieces()).toBe(0)
		expect(theFist(rig)).never.toBeNil()
		rig.advance(0.1) -- 0.85 s
		expect(theFist(rig)).toBeNil()
	end)

	it("bursts only once when SlamLanded and the landing time both come", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.2)
		rig.land(1, POINT)
		rig.advance(0.5)
		rig.land(1, POINT)
		rig.advance(0.5)
		expect(#rig.bursts).toBe(2)
	end)

	it("does not burst twice when the landing time passes first and SlamLanded comes after it", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.6)
		expect(#rig.bursts).toBe(2)
		rig.land(1, POINT)
		rig.advance(0.1)
		expect(#rig.bursts).toBe(2)
	end)

	it(
		"keeps the circle solid until 0.4 seconds after the landing, half see-through at 0.55 and gone by 0.7",
		function()
			local rig = newRig()
			warnAndBuild(rig, 1, POINT, 1.5)
			rig.advance(1.5)
			rig.advance(0.4)
			expect(transparencyOfPieces(rig) :: number).toBeCloseTo(0, 6)
			rig.advance(0.15)
			expect(transparencyOfPieces(rig) :: number).toBeCloseTo(0.5, 2)
			rig.advance(0.16)
			expect(#rig.pieces()).toBe(0)
			expect(#rig.circles()).toBe(0)
		end
	)

	it("destroys the dust part once its longest particle has lived out its time", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local life = math.max(rig.bursts[1].emitter.Lifetime.Max, rig.bursts[2].emitter.Lifetime.Max)
		rig.advance(life - 0.05)
		expect(theDust(rig)).never.toBeNil()
		rig.advance(0.1)
		expect(theDust(rig)).toBeNil()
	end)

	it("leaves the folder empty and lets go of the step when the slam is over", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.settle()
		expect(rig.step:count()).toBe(1)
		rig.advance(1.5)
		rig.advance(0.9)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(rig.folder()).never.toBeNil()
		expect(countChildren(rig)).toBe(0)
		expect(rig.step:count()).toBe(0)
	end)
end)
