--!strict
-- Rule 100 (Nothing you stand on moves while he sleeps) and Story F: the pieces marked RidesRightArm ride his right arm
-- by exactly the arm's own move, and the beams in the eggs on them fade while he is awake.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local GiantFx = require(Client.Fx.GiantFx)
local Ride = require(Client.Fx.GiantFx.Ride)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local RAISE_DEGREES = Helpers.RAISE_DEGREES
local SHOULDER = Helpers.SHOULDER
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig
local samePlace = Helpers.samePlace

afterEach(cleanUp)

local MARK = "RidesRightArm"
local BEAM_LOOK = 0.2

describe("GiantFx.start: the right cuff rides his arm", function()
	-- A marked nest with a base part, and an unmarked part beside it, put into the world after GiantFx started.
	local function addCuff(rig: Rig): (Model, Part, Part)
		local nest = Instance.new("Model")
		nest.Name = "Nest_CuffFront_Right"
		nest:SetAttribute(MARK, true)
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Anchored = true
		base.CFrame = CFrame.new(45, 60, 10)
		base.Parent = nest
		nest.Parent = rig.world
		local other = Instance.new("Part")
		other.Name = "Unmarked"
		other.Anchored = true
		other.CFrame = CFrame.new(-20, 10, 10)
		other.Parent = rig.world
		return nest, base, other
	end

	-- An egg with a shell and a beam, put into a nest the way the server does (parented last).
	local function addEgg(nest: Model): (Model, Part, Beam)
		local egg = Instance.new("Model")
		egg.Name = "Egg"
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Anchored = true
		shell.CFrame = CFrame.new(45, 62, 10)
		shell.Parent = egg
		local beam = Instance.new("Beam")
		beam.Transparency = NumberSequence.new(BEAM_LOOK)
		beam.Parent = shell
		egg.Parent = nest
		return egg, shell, beam
	end

	-- Where the arm's own move puts a piece that was at `start`.
	local function movedByArm(rig: Rig, start: CFrame): CFrame
		return rig.arm:GetPivot() * rig.armStart:Inverse() * start
	end

	local function beamValues(beam: Beam): { number }
		local values: { number } = {}
		for _, keypoint in beam.Transparency.Keypoints do
			table.insert(values, keypoint.Value)
		end
		return values
	end

	it("moves no marked piece at the 85% warning", function()
		local rig = newRig()
		local _, base, other = addCuff(rig)
		local baseStart, otherStart = base.CFrame, other.CFrame
		rig.fire(85)
		rig.advance(0.5)
		expect(samePlace(base.CFrame, baseStart)).toBe(true)
		expect(samePlace(other.CFrame, otherStart)).toBe(true)
	end)

	it("puts a marked piece where the arm's move puts it half way through the waking pose", function()
		local rig = newRig()
		local _, base, other = addCuff(rig)
		local baseStart, otherStart = base.CFrame, other.CFrame
		rig.setState(100, "Awake")
		rig.advance(0.25)
		local share = GiantFx.poseShare(0.25)
		local expected = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * baseStart
		expect(samePlace(base.CFrame, expected)).toBe(true)
		expect(samePlace(base.CFrame, baseStart)).toBe(false)
		expect(samePlace(other.CFrame, otherStart)).toBe(true)
	end)

	it("keeps a marked piece on the arm's move during a slam swing", function()
		local rig = newRig()
		local _, base = addCuff(rig)
		local baseStart = base.CFrame
		rig.setState(100, "Awake")
		rig.advance(0.5)
		local raised = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * baseStart
		rig.slamWarning:Fire(1, Vector3.new(-30, 2, -60), 0)
		rig.advance(0.25)
		expect(samePlace(base.CFrame, movedByArm(rig, baseStart))).toBe(true)
		expect(samePlace(base.CFrame, raised)).toBe(false) -- the swing really moved it past the raise
	end)

	it("puts every marked piece back on its start once he sleeps again", function()
		local rig = newRig()
		local nest, base = addCuff(rig)
		local _, shell = addEgg(nest)
		local baseStart, shellStart = base.CFrame, shell.CFrame
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(samePlace(shell.CFrame, shellStart)).toBe(false) -- it really rode up first
		rig.slamWarning:Fire(1, Vector3.new(-30, 2, -60), 0)
		rig.advance(0.3)
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(samePlace(base.CFrame, baseStart)).toBe(true)
		expect(samePlace(shell.CFrame, shellStart)).toBe(true)
	end)

	it("fades the beam in 0.3 seconds when he wakes and brings it back 0.3 seconds after the arm is down", function()
		expect(Config.Nests.BeamFadeSeconds).toBe(0.3)
		local rig = newRig()
		local nest = addCuff(rig)
		local _, _, beam = addEgg(nest)
		rig.setState(100, "Awake")
		rig.advance(0.3)
		for _, value in beamValues(beam) do
			expect(value).toBeCloseTo(1, 2)
		end
		rig.advance(0.3)
		rig.setState(0, "Asleep")
		rig.advance(0.5) -- the arm comes down
		rig.advance(0.3)
		for _, value in beamValues(beam) do
			expect(value).toBeCloseTo(BEAM_LOOK, 2)
		end
	end)

	it("makes a new egg in a right cuff nest ride the arm at once while he is awake", function()
		local rig = newRig()
		local nest = addCuff(rig)
		rig.setState(100, "Awake")
		rig.advance(0.5)
		local _, shell, beam = addEgg(nest)
		task.wait() -- DescendantAdded is deferred: the egg is picked up on the next frame
		local shellStart = CFrame.new(45, 62, 10)
		expect(samePlace(shell.CFrame, movedByArm(rig, shellStart))).toBe(true)
		expect(samePlace(shell.CFrame, shellStart)).toBe(false)
		for _, value in beamValues(beam) do
			expect(value).toBeCloseTo(1, 2)
		end
	end)

	it("rides a CuffFill_Right piece, and the placed CuffFill_Right is marked", function()
		local rig = newRig()
		local fill = Instance.new("Part")
		fill.Name = "CuffFill_Right"
		fill.Anchored = true
		fill.CFrame = CFrame.new(44, 58, 9)
		fill:SetAttribute(MARK, true)
		fill.Parent = rig.world
		local start = fill.CFrame
		rig.setState(100, "Awake")
		rig.advance(0.25)
		local expected = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, GiantFx.poseShare(0.25)) * start
		expect(samePlace(fill.CFrame, expected)).toBe(true)
		local worldFolder = Workspace:FindFirstChild("World")
		expect(worldFolder).never.toBeNil()
		local real = if worldFolder ~= nil then worldFolder:FindFirstChild("CuffFill_Right") else nil
		expect(real).never.toBeNil()
		if real ~= nil then
			expect(real:GetAttribute(MARK)).toBe(true)
		end
	end)

	it("finds the marked pieces that were already in the world when it started", function()
		local world = made(Instance.new("Folder"))
		local part = Instance.new("Part")
		part.Anchored = true
		part.CFrame = CFrame.new(45, 60, 10)
		part:SetAttribute(MARK, true)
		part.Parent = world
		local fakeState: any = { awake = false, poseDirection = 0, poseAge = 0 }
		local fakeDeps: any = { world = world }
		local ride = Ride.new(fakeState, fakeDeps)
		local move = CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(20), 0)
		ride.place(move)
		expect(samePlace(part.CFrame, move * CFrame.new(45, 60, 10))).toBe(true)
		ride.place(nil)
		expect(samePlace(part.CFrame, CFrame.new(45, 60, 10))).toBe(true)
		ride.destroy()
	end)
end)
