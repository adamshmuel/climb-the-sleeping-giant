--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig

afterEach(cleanUp)

-- Where the sign's bottom-left corner is, in studs from the anchor in the camera's own directions: its middle (the
-- offset) minus half its size.
local function signCorner(sign: BillboardGui): Vector3
	return sign.StudsOffset - Vector3.new(sign.Size.X.Scale / 2, sign.Size.Y.Scale / 2, 0)
end

local function puffSizes(puff: ParticleEmitter): { number }
	local found: { number } = {}
	for _, keypoint in puff.Size.Keypoints do
		table.insert(found, keypoint.Value)
	end
	return found
end

local function close(actual: number, expected: number, within: number?)
	expect(math.abs(actual - expected) <= (within or 1e-3)).toBe(true)
end

describe("GiantFx Heavy Sleep settings", function()
	it("makes the Z Z Z 2.5 times bigger", function()
		expect(GiantFx.heavyLetterScale).toBe(2.5)
	end)

	it("makes the puffs come 3 times as often", function()
		expect(GiantFx.heavyPuffRateScale).toBe(3)
	end)

	it("makes the puffs 1.6 times bigger", function()
		expect(GiantFx.heavyPuffSizeScale).toBe(1.6)
	end)

	it("shrinks the Z Z Z back over 0.5 seconds, like the waking pose", function()
		expect(GiantFx.heavyShrinkSeconds).toBe(0.5)
	end)

	it("keeps the bottom-left corner of the sign where it is", function()
		expect(GiantFx.heavyFixedCorner).toBe(Vector2.new(-1, -1))
	end)
end)

describe("GiantFx.start: Heavy Sleep", function()
	it("makes the Z Z Z sign 2.5 times its size: 40 x 40 studs from 16 x 16", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)

	it("keeps the sign's bottom-left corner where it was, so it grows up and to the right", function()
		local rig = newRig()
		local before = signCorner(rig.floatingZ)
		rig.setState(100, "HeavySleep")
		local after = signCorner(rig.floatingZ)
		close((after - before).Magnitude, 0)
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
	end)

	it("makes the puff Rate 6 from 2", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		expect(rig.puff.Rate).toBe(6)
	end)

	it("makes every puff Size keypoint 1.6 times bigger: 3.2 and 11.2", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		local sizes = puffSizes(rig.puff)
		close(sizes[1], 3.2)
		close(sizes[2], 11.2)
	end)

	it("scales the envelope of each puff Size keypoint too, and keeps the times", function()
		local rig = newRig()
		rig.puff.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 2, 0.5), NumberSequenceKeypoint.new(1, 7, 1) })
		rig.setState(100, "HeavySleep")
		local keypoints = rig.puff.Size.Keypoints
		close(keypoints[1].Envelope, 0.8)
		close(keypoints[2].Envelope, 1.6)
		close(keypoints[1].Time, 0)
		close(keypoints[2].Time, 1)
	end)

	it("has the Z Z Z and puffs on, and big, after an 85 warning and a wake", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.puff.Rate).toBe(6)
	end)

	it("keeps them off while an 85 warning has them quiet and he is Asleep", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.puff.Rate).toBe(2)
	end)

	it("keeps the Z Z Z and puffs off, with the normal look, while he is Awake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.puff.Rate).toBe(2)
	end)

	it("still fades the big letters with the 60 warning rules after Heavy Sleep starts from a quiet sleep", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.fire(60)
		rig.advance(1)
		expect(rig.letters[1].TextTransparency > rig.normalLetters[1]).toBe(true)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)
end)

describe("GiantFx.start: Heavy Sleep ends", function()
	local function heavyRig(): Rig
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		return rig
	end

	it("has the puff Rate and Size back at once", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		expect(rig.puff.Rate).toBe(2)
		local sizes = puffSizes(rig.puff)
		close(sizes[1], 2)
		close(sizes[2], 7)
	end)

	it("has the sign still big on the same frame, then shrinks it", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)

	it("is half way through the shrink, with the smooth easing, at 0.25 seconds, on the same corner", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.25)
		close(rig.floatingZ.Size.X.Scale, 28)
		close(rig.floatingZ.Size.Y.Scale, 28)
		close(rig.floatingZ.StudsOffset.X, 20)
		close(rig.floatingZ.StudsOffset.Y, 14)
		close((signCorner(rig.floatingZ) - Vector3.new(6, 0, 2)).Magnitude, 0)
	end)

	it("eases: a tenth of the way through it has shrunk far less than a tenth", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.05)
		expect(rig.floatingZ.Size.X.Scale > 39).toBe(true)
	end)

	it("has the sign, offset and corner back at the saved values after 0.5 seconds", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
	end)

	it("lets go of the step when the shrink is over", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		expect(rig.step:count()).toBe(1)
		rig.advance(0.5)
		expect(rig.step:count()).toBe(0)
	end)

	it("counts the shrink by the clock, however many frames that is", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.1)
		rig.advance(0.1)
		rig.advance(0.05)
		close(rig.floatingZ.Size.X.Scale, 28)
	end)

	it("is big at once when Heavy Sleep comes back in the middle of a shrink", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.25)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		rig.advance(1)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)

	it("never grows the sign twice over a second round: always 2.5 times the saved size", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
		expect(rig.puff.Rate).toBe(6)
		close(puffSizes(rig.puff)[2], 11.2)
	end)

	it("never grows the puffs twice over a second round, then goes back to the saved ones", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.puff.Rate).toBe(2)
		close(puffSizes(rig.puff)[2], 7)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
	end)
end)

describe("GiantFx.start: Heavy Sleep, saved values", function()
	it(
		"takes the normal look from what the place had: a sign of 10 x 12 and a Rate of 5 keep their own numbers",
		function()
			local rig = newRig()
			rig.floatingZ.Size = UDim2.fromScale(10, 12)
			rig.floatingZ.StudsOffset = Vector3.new(3, 4, 5)
			rig.puff.Rate = 5
			rig.puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
			rig.setState(100, "HeavySleep")
			expect(rig.floatingZ.Size).toBe(UDim2.fromScale(25, 30))
			expect(rig.puff.Rate).toBe(15)
			close(puffSizes(rig.puff)[2], 4.8)
			close((signCorner(rig.floatingZ) - Vector3.new(3 - 5, 4 - 6, 5)).Magnitude, 0)
			rig.setState(0, "Asleep")
			rig.advance(0.5)
			expect(rig.floatingZ.Size).toBe(UDim2.fromScale(10, 12))
			expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(3, 4, 5))
			expect(rig.puff.Rate).toBe(5)
			close(puffSizes(rig.puff)[2], 3)
		end
	)
end)

describe("GiantFx.start: Heavy Sleep, joining", function()
	it("gives a module that starts during Heavy Sleep the big look at once", function()
		local rig = newRig(true, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
		expect(rig.puff.Rate).toBe(6)
		close(puffSizes(rig.puff)[1], 3.2)
	end)

	it("shrinks a module that started during Heavy Sleep back to the saved look at its end", function()
		local rig = newRig(true, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.puff.Rate).toBe(2)
	end)
end)

describe("GiantFx.start: Heavy Sleep, streaming", function()
	it("gives a GiantFX that streams in during Heavy Sleep the big look", function()
		local rig = newRig(false)
		rig.setState(100, "HeavySleep")
		rig.fx.Parent = rig.world
		task.wait()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
		expect(rig.puff.Rate).toBe(6)
		close(puffSizes(rig.puff)[2], 11.2)
	end)

	it("gives a GiantFX that streams in after Heavy Sleep the normal look", function()
		local rig = newRig(false)
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		rig.fx.Parent = rig.world
		task.wait()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.puff.Rate).toBe(2)
		close(puffSizes(rig.puff)[2], 7)
	end)

	it("gives a part added to GiantFX during Heavy Sleep the big look", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		-- A fresh copy of the pieces arrives from the server, as the place made them.
		rig.floatingZ.Size = UDim2.fromScale(16, 16)
		rig.floatingZ.StudsOffset = Vector3.new(14, 8, 2)
		rig.puff.Rate = 2
		local extra = made(Instance.new("Part"))
		extra.Parent = rig.fx
		task.wait()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.puff.Rate).toBe(6)
	end)

	it("gives a new FloatingZ that streams in during Heavy Sleep the big look from its own size", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.floatingZ.Parent = nil
		local fresh = made(Instance.new("BillboardGui"))
		fresh.Name = "FloatingZ"
		fresh.Size = UDim2.fromScale(8, 8)
		fresh.StudsOffset = Vector3.new(1, 2, 3)
		fresh.Parent = rig.snoreEmitter
		task.wait()
		expect(fresh.Size).toBe(UDim2.fromScale(20, 20))
		expect(fresh.StudsOffset).toBe(Vector3.new(1 + 6, 2 + 6, 3))
	end)
end)

describe("GiantFx.start: Heavy Sleep, stop", function()
	it("puts the saved sign, offset, Rate and puff Size back when stopped in Heavy Sleep", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.handle.stop()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.puff.Rate).toBe(2)
		close(puffSizes(rig.puff)[1], 2)
		close(puffSizes(rig.puff)[2], 7)
	end)

	it("puts the saved look back when stopped in the middle of the shrink", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.2)
		rig.handle.stop()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.step:count()).toBe(0)
	end)

	it("changes nothing on a later Heavy Sleep after stop", function()
		local rig = newRig()
		rig.handle.stop()
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.puff.Rate).toBe(2)
	end)
end)
