--!strict
-- Task 11, His face wakes (spec Rule 66, Rule 69): the mouth with the eyes, the 0.3 second head tip, the "!", the bubble
-- pop, and the sound hooks.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local HEAD_PIVOT = Helpers.HEAD_PIVOT
local HEAD_TILT_DEGREES = Helpers.HEAD_TILT_DEGREES
local RAISE_DEGREES = Helpers.RAISE_DEGREES
local SHOULDER = Helpers.SHOULDER
local cleanUp = Helpers.cleanUp
local newRig = Helpers.newRig
local samePlace = Helpers.samePlace

afterEach(cleanUp)

-- Where the head pieces should be `share` of the way into the head tip.
local function tipped(start: CFrame, share: number): CFrame
	return GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, share) * start
end

-- The share of the head tip at `age` seconds, going forward or back (Motion.headShare, exported as GiantFx.headShare).
local function headShare(age: number, forward: boolean): number
	return GiantFx.headShare(age, forward)
end

-- How many times its own size the "!" is now (its size at the start is the whole size).
local function bangScale(rig: Rig): number
	return rig.bang.Size.X.Scale / rig.bangSize.X.Scale
end

-- A piece of the "!" now looks as it did at the start.
local function bangLooksRestored(rig: Rig): boolean
	for piece, look in rig.bangLooks do
		local now = if piece:IsA("UIStroke") then piece.Transparency else (piece :: Frame).BackgroundTransparency
		if math.abs(now - look) > 1e-6 then
			return false
		end
	end
	return rig.bang.Size == rig.bangSize
end

-- The sounds played so far, by name.
local function soundNames(rig: Rig): { string }
	local names: { string } = {}
	for _, sound in rig.sounds do
		table.insert(names, sound.name)
	end
	return names
end

local function mouthTransparencies(rig: Rig): { number }
	local found: { number } = {}
	for _, part in rig.mouthParts do
		table.insert(found, part.Transparency)
	end
	return found
end

describe("GiantFx.start: his face wakes", function()
	it("shows the mouth with the eyes and hides it again at the lie-down", function()
		local rig = newRig()
		expect(mouthTransparencies(rig)).toEqual({ 1, 1 })
		rig.setState(100, "Awake")
		expect(mouthTransparencies(rig)).toEqual({ 0, 0 })
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		expect(mouthTransparencies(rig)).toEqual({ 1, 1 })
	end)

	it("tips the mouth with the head at every step of the tip", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		local clock = 0
		for _, age in { 0.15, 0.3 } do
			rig.advance(age - clock)
			clock = age
			local share = headShare(age, true)
			expect(samePlace(rig.head:GetPivot(), tipped(rig.headStart, share))).toBe(true)
			expect(samePlace(rig.mouth:GetPivot(), tipped(rig.mouthStart, share))).toBe(true)
		end
	end)

	it("has the head fully tipped at 0.3 seconds while the arm is not yet fully raised", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.3)
		expect(samePlace(rig.head:GetPivot(), tipped(rig.headStart, 1))).toBe(true)
		expect(samePlace(rig.mouth:GetPivot(), tipped(rig.mouthStart, 1))).toBe(true)
		local armShare = GiantFx.poseShare(0.3)
		expect(armShare < 1).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, armShare) * rig.armStart)).toBe(
			true
		)
	end)

	it("takes 0.5 seconds to put the head and mouth back after the lie-down", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.advance(0.25)
		local share = headShare(0.25, false)
		expect(share > 0 and share < 1).toBe(true)
		expect(samePlace(rig.head:GetPivot(), tipped(rig.headStart, share))).toBe(true)
		expect(samePlace(rig.mouth:GetPivot(), tipped(rig.mouthStart, share))).toBe(true)
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.mouth:GetPivot() == rig.mouthStart).toBe(true)
	end)

	it("pops the '!' from nothing, over the top, to its own size, and takes it off with its looks restored", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.bang.Enabled).toBe(true)
		expect(bangScale(rig)).toBe(0)
		rig.advance(0.16)
		expect(bangScale(rig) > 1).toBe(true)
		rig.advance(0.84)
		expect(bangScale(rig)).toBeCloseTo(1, 6)
		expect(rig.bang.Enabled).toBe(true)
		rig.advance(0.8) -- 1.8 seconds: the fade is on
		expect(rig.bang.Enabled).toBe(true)
		expect(bangLooksRestored(rig)).toBe(false)
		rig.advance(0.16) -- 1.96 seconds
		expect(rig.bang.Enabled).toBe(false)
		expect(bangLooksRestored(rig)).toBe(true)
	end)

	it("shows the bubble pop until 0.4 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.zpop.Enabled).toBe(true)
		rig.advance(0.39)
		expect(rig.zpop.Enabled).toBe(true)
		rig.advance(0.02)
		expect(rig.zpop.Enabled).toBe(false)
	end)

	it("shows the mouth but neither the '!' nor the pop to a player who joins while he is awake", function()
		local rig = newRig(nil, "Awake")
		expect(mouthTransparencies(rig)).toEqual({ 0, 0 })
		for _ = 1, 4 do
			rig.advance(0.1)
			expect(rig.bang.Enabled).toBe(false)
			expect(rig.zpop.Enabled).toBe(false)
		end
	end)
end)

describe("GiantFx.start: the sound hooks", function()
	it("calls each wake sound once, with its place, at the wake", function()
		local rig = newRig()
		local mouthAt = rig.mouthParts[1].Position
		rig.setState(100, "Awake")
		rig.advance(1)
		expect(soundNames(rig)).toEqual({ "WakeEyes", "WakeRoar", "ZzzPop" })
		expect(rig.sounds[1].at).toBe(nil)
		expect(rig.sounds[2].at).toEqual(mouthAt)
		expect(rig.sounds[3].at).toEqual(rig.bangAnchor.Position)
		for _, sound in rig.sounds do
			expect(sound.time).toBe(0)
		end
	end)

	it("calls LieDown once, with no place, at the lie-down", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(2)
		rig.setState(0, "Asleep")
		rig.advance(1)
		expect(soundNames(rig)).toEqual({ "WakeEyes", "WakeRoar", "ZzzPop", "LieDown" })
		expect(rig.sounds[4].at).toBe(nil)
		expect(rig.sounds[4].time).toBe(2)
	end)

	it("calls no sound for a player who joins while he is awake", function()
		local rig = newRig(nil, "Awake")
		rig.advance(1)
		expect(#rig.sounds).toBe(0)
	end)

	it("wakes and lies down without error when there is no sound setting", function()
		local rig = newRig(nil, nil, nil, false)
		rig.setState(100, "Awake")
		rig.advance(1)
		expect(rig.bang.Enabled).toBe(true) -- the face still plays without the sound setting
		rig.setState(0, "Asleep")
		rig.advance(1)
		expect(#rig.sounds).toBe(0)
		expect(rig.bang.Enabled).toBe(false)
	end)
end)

describe("GiantFx.start: ending the face early", function()
	it("takes the '!' and the pop off at once, looks restored, when he lies down in the middle", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.3)
		expect(rig.bang.Enabled).toBe(true)
		expect(rig.zpop.Enabled).toBe(true)
		rig.setState(0, "Asleep")
		expect(rig.bang.Enabled).toBe(false)
		expect(rig.zpop.Enabled).toBe(false)
		expect(bangLooksRestored(rig)).toBe(true)
		expect(rig.zpop.Size).toBe(rig.zpopSize)
	end)

	it("plays the whole face again at a second wake-up", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(2.5)
		rig.setState(0, "Asleep")
		rig.advance(1)
		rig.setState(100, "Awake")
		expect(rig.bang.Enabled).toBe(true)
		expect(rig.zpop.Enabled).toBe(true)
		expect(bangScale(rig)).toBe(0)
		rig.advance(0.16)
		expect(bangScale(rig) > 1).toBe(true)
		rig.advance(2)
		expect(rig.bang.Enabled).toBe(false)
		local wakes = 0
		for _, name in soundNames(rig) do
			if name == "WakeEyes" then
				wakes += 1
			end
		end
		expect(wakes).toBe(2)
	end)

	it("puts the face back as it was when the module stops in the middle", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.3)
		expect(rig.bang.Enabled).toBe(true) -- the face is running when the module stops
		rig.handle.stop()
		expect(rig.bang.Enabled).toBe(false)
		expect(rig.zpop.Enabled).toBe(false)
		expect(bangLooksRestored(rig)).toBe(true)
		expect(rig.zpop.Size).toBe(rig.zpopSize)
		expect(mouthTransparencies(rig)).toEqual({ 1, 1 })
		expect(rig.mouth:GetPivot() == rig.mouthStart).toBe(true)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
	end)
end)
