--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local HEAD_PIVOT = Helpers.HEAD_PIVOT
local finishFace = Helpers.finishFace
local HEAD_TILT_DEGREES = Helpers.HEAD_TILT_DEGREES
local RAISE_DEGREES = Helpers.RAISE_DEGREES
local SHOULDER = Helpers.SHOULDER
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig
local samePlace = Helpers.samePlace

afterEach(cleanUp)

describe("GiantFx.start: the waking pose", function()
	local function headGroup(rig: Rig): { { piece: Model, start: CFrame } }
		return {
			{ piece = rig.head, start = rig.headStart },
			{ piece = rig.cap, start = rig.capStart },
			{ piece = rig.leftLid, start = rig.leftStart },
			{ piece = rig.rightLid, start = rig.rightStart },
			{ piece = rig.awakeEyes, start = rig.awakeEyesStart },
		}
	end

	it("puts the head, the cap, both lids and the awake eyes at the full head tip after 0.5 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		for _, entry in headGroup(rig) do
			expect(samePlace(entry.piece:GetPivot(), turn * entry.start)).toBe(true)
		end
	end)

	it("puts the right arm at the full raise after 0.5 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
	end)

	it("has the arm half way, with the easing, and the head on its own 0.3 s tip, at 0.25 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.25)
		local share = GiantFx.poseShare(0.25)
		expect(share).toBeCloseTo(0.5, 6)
		local headShare = GiantFx.headShare(0.25, true)
		expect(
			samePlace(rig.head:GetPivot(), GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, headShare) * rig.headStart)
		).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * rig.armStart)).toBe(
			true
		)
	end)

	it("does not move anything before the next step", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("stays on the full pose on later steps", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.advance(1)
		rig.advance(5)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
	end)

	it("swaps the eyes at once: the awake eyes show and every sleep eye part is hidden", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(0)
		end
		for _, part in rig.sleepParts do
			expect(part.Transparency).toBe(1)
		end
	end)

	it("shows only the awake eye parts that are marked ShownWhenAwake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.stray.Transparency).toBe(1)
	end)

	it(
		"wakes from an 85 warning that is running: the arm ends on the full raise and nothing puts it back down",
		function()
			local rig = newRig()
			rig.fire(85)
			rig.advance(0.25) -- the 85 warning is running
			rig.setState(100, "Awake")
			rig.advance(0.5)
			rig.advance(2) -- the warning would have ended by now
			expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(
				true
			)
		end
	)

	it("stops a flutter that is running: the lids end on the head tip alone and the slices are hidden", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25) -- the lids are lifted
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.advance(2) -- the flutter would have ended by now, and put the lids back at their start
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.leftLid:GetPivot(), turn * rig.leftStart)).toBe(true)
		expect(samePlace(rig.rightLid:GetPivot(), turn * rig.rightStart)).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
	end)

	it("ends the Z Z Z fade at once, with the letters at their normal looks", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(1)
		rig.setState(100, "Awake")
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
		rig.advance(2)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
		end
	end)

	it("hides the mumble bubble at once, and it stays hidden", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(1)
		expect(rig.bubble.Enabled).toBe(true)
		rig.setState(100, "Awake")
		expect(rig.bubble.Enabled).toBe(false)
		rig.advance(5)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("turns the Z Z Z and the puffs off even when there was no 85 warning", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("keeps the Z Z Z and the puffs off for as long as he is awake, also when Meter changes", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.setState(40, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("gives a GiantFX that streams in during the wake-up the Z Z Z off state", function()
		local rig = newRig(false)
		rig.setState(100, "Awake")
		rig.fx.Parent = rig.world
		task.wait()
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("ignores a warning that arrives after he is awake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.fire(85)
		rig.fire(60)
		rig.advance(0.5)
		expect(rig.bubble.Enabled).toBe(false)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
		finishFace(rig) -- the wake face keeps the step connected after the pose
		expect(rig.step:count()).toBe(0)
	end)

	it("is connected to the step while the pose plays and let go of when it is over", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.step:count()).toBe(1)
		rig.advance(0.25)
		expect(rig.step:count()).toBe(1)
		rig.advance(0.25)
		finishFace(rig) -- the wake face keeps the step connected after the pose
		expect(rig.step:count()).toBe(0)
	end)

	it("takes 0.5 seconds of the clock, however many frames that is", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		for _ = 1, 5 do
			rig.advance(0.1)
		end
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
	end)

	it("does not move the giant's other pieces", function()
		local rig = newRig()
		local body = made(Instance.new("Model"))
		body.Name = "body_and_cushion"
		local bodyPart = Instance.new("Part")
		bodyPart.Anchored = true
		bodyPart.Parent = body
		body.Parent = rig.giant
		local before = body:GetPivot()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(body:GetPivot() == before).toBe(true)
	end)

	it("skips pieces that are not there", function()
		local rig = newRig()
		rig.head.Parent = nil
		rig.awakeEyes.Parent = nil
		rig.arm.Parent = nil
		rig.setState(100, "Awake")
		rig.advance(0.5)
		finishFace(rig) -- the wake face keeps the step connected after the pose
		expect(rig.step:count()).toBe(0)
	end)

	it("does not move the head when the giant has no head pivot, but still swaps the eyes", function()
		local rig = newRig()
		rig.giant:SetAttribute("Awake_HeadPivot", nil)
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.awakeParts[1].Transparency).toBe(0)
	end)
end)

describe("GiantFx.start: going back to sleep", function()
	it("swaps the eyes back at once, to each part's own look, with the slices still hidden", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
		expect(rig.leftSliver.Transparency).toBe(1)
	end)

	it("puts every moved piece exactly back on its start pivot after 0.5 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(false) -- half way back
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.cap:GetPivot() == rig.capStart).toBe(true)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.awakeEyes:GetPivot() == rig.awakeEyesStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("goes back the same way for a reset to Asleep", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.floatingZ.Enabled).toBe(true)
	end)

	it("turns back from where it is when he falls asleep in the middle of the pose", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.25)
		rig.setState(100, "HeavySleep")
		rig.advance(0.25) -- as long as it had been going forward
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("brings the Z Z Z and the puffs back for Heavy Sleep when no warning had stopped them", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
	end)

	it("brings the Z Z Z and the puffs back for Heavy Sleep after an 85 warning stopped them", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(100, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
	end)

	it("can wake him again after a return: the pose goes from the start pivots each time", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.setState(100, "Awake")
		rig.advance(0.5)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(0)
		end
	end)

	it("snorts and mumbles again after a return, and keeps the arm still", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(samePlace(rig.arm:GetPivot(), rig.armStart)).toBe(true)
		rig.fire(85)
		rig.advance(0.5)
		expect(samePlace(rig.arm:GetPivot(), rig.armStart)).toBe(true)
		expect(#rig.bursts).toBe(2)
		expect(rig.bubble.Enabled).toBe(true)
	end)
end)

describe("GiantFx.start: already awake at the start", function()
	it("gives the full pose at once, with no motion, and nothing to step", function()
		local rig = newRig(nil, "Awake")
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("still has the full pose on the first step", function()
		local rig = newRig(nil, "Awake")
		rig.advance(0.016)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
	end)

	it("has the eyes swapped and the Z Z Z off", function()
		local rig = newRig(nil, "Awake")
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(0)
		end
		for _, part in rig.sleepParts do
			expect(part.Transparency).toBe(1)
		end
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("goes back to sleep over 0.5 seconds like any wake-up", function()
		local rig = newRig(nil, "Awake")
		rig.setState(100, "HeavySleep")
		rig.advance(0.25)
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
	end)
end)

describe("GiantFx.start: stop during and after the pose", function()
	it("puts everything back as it was when stopped in the middle of the pose", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.25)
		rig.handle.stop()
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.cap:GetPivot() == rig.capStart).toBe(true)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.awakeEyes:GetPivot() == rig.awakeEyesStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("puts everything back when stopped while he is awake and the pose is over", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.handle.stop()
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
	end)

	it("puts everything back when stopped in a pose that was there from the start", function()
		local rig = newRig(nil, "Awake")
		rig.handle.stop()
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
	end)

	it("changes nothing on a later wake-up or step", function()
		local rig = newRig()
		rig.handle.stop()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.awakeParts[1].Transparency).toBe(1)
		expect(rig.floatingZ.Enabled).toBe(true)
	end)
end)
