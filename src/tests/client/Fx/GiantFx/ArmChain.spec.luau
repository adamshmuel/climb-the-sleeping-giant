--!strict
-- Plan 6 Task 12. Rule 64 (He gets faster): the next slam warning takes the arm on from where it is, with no jump, and
-- Rule 100 (Nothing you stand on moves while he sleeps): the arm is back at rest the moment the shared clock says
-- his awake time is over, however late this device hears of it.
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local GiantFx = require(Client.Fx.GiantFx)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local RAISE_DEGREES = Helpers.RAISE_DEGREES
local SHOULDER = Helpers.SHOULDER
local cleanUp = Helpers.cleanUp
local degreesBetween = Helpers.degreesBetween
local finishFace = Helpers.finishFace
local newRig = Helpers.newRig
local samePlace = Helpers.samePlace

afterEach(cleanUp)

local FRAME = 1 / 60
local WAKE_CLOCK = 100 -- the rig clock when he wakes (Helpers.newRig starts at 100)
local AWAKE_SECONDS = Config.Wake.AwakeSeconds

describe("GiantFx.start: the chained slam swing and the return on the shared clock", function()
	local AHEAD_LEFT = Vector3.new(-30, 2, -60)
	local AHEAD_RIGHT = Vector3.new(90, 2, -45)

	local function awakeRig(): Rig
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		finishFace(rig) -- the wake face keeps the step connected after the pose; wait it out
		return rig
	end

	-- A rig that woke at the rig clock 100 with the server saying his awake time ends `AWAKE_SECONDS` later.
	local function wokenRig(): Rig
		local rig = newRig()
		rig.setPhaseEnds(WAKE_CLOCK + AWAKE_SECONDS)
		rig.setState(100, "Awake")
		return rig
	end

	-- The server's write order when he goes back to sleep: PhaseEndsAt first, then the Phase.
	local function sleepAgain(rig: Rig)
		rig.setPhaseEnds(WAKE_CLOCK + 60)
		rig.setState(100, "HeavySleep")
	end

	local function frames(rig: Rig, count: number)
		for _ = 1, count do
			rig.advance(FRAME)
		end
	end

	local function armDirection(rig: Rig): Vector3
		return (rig.arm:GetBoundingBox()).Position - SHOULDER
	end

	local function atRest(rig: Rig): boolean
		return samePlace(rig.arm:GetPivot(), rig.armStart) and samePlace(rig.head:GetPivot(), rig.headStart)
	end

	it("chains a close aim: no jump on the warning's frame, then no frame faster than the swing allows", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		frames(rig, 120) -- warning 2 comes 2.0 s later
		local direction = AHEAD_LEFT - SHOULDER
		local axis = direction:Cross(Vector3.yAxis).Unit
		local second = SHOULDER + CFrame.fromAxisAngle(axis, math.rad(15)):VectorToWorldSpace(direction)
		local before = armDirection(rig)
		rig.slamWarning:Fire(2, second, 0)
		rig.advance(FRAME)
		local atWarning = armDirection(rig)
		expect(degreesBetween(before, atWarning)).toBeLessThan(1)
		-- The next 60 frames: a 0.5 s eased swing peaks at 1.5 times its average speed (travel over 30 frames).
		local turns: { number } = {}
		local previous = atWarning
		local halfSecondLater = atWarning
		for index = 1, 60 do
			rig.advance(FRAME)
			local current = armDirection(rig)
			turns[index] = degreesBetween(previous, current)
			previous = current
			if index == 30 then
				halfSecondLater = current
			end
		end
		local travel = degreesBetween(atWarning, halfSecondLater)
		local limit = 1.5 * travel / 30 + 0.1
		local worst, worstIndex = 0, 0
		for index, turn in turns do
			if turn > worst then
				worst, worstIndex = turn, index
			end
		end
		if worst > limit then
			error(`travel {travel} deg, worst frame {worst} deg at frame {worstIndex}, limit {limit} deg`)
		end
		expect(worst).toBeLessThanOrEqual(limit)
	end)

	it("chains a far aim: no jump on the warning's frame, and on the new aim 0.5 s later", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		frames(rig, 120)
		local before = armDirection(rig)
		rig.slamWarning:Fire(2, AHEAD_RIGHT, 0)
		rig.advance(FRAME)
		expect(degreesBetween(before, armDirection(rig))).toBeLessThan(1)
		rig.advance(0.5 - FRAME)
		expect(degreesBetween(armDirection(rig), AHEAD_RIGHT - SHOULDER)).toBeLessThan(1)
	end)

	it("keeps a piece marked RidesRightArm in the same place from the arm through a chained swing", function()
		local rig = newRig()
		local nest = Instance.new("Model")
		nest.Name = "Nest_CuffFront_Right"
		nest:SetAttribute("RidesRightArm", true)
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Anchored = true
		base.CFrame = CFrame.new(45, 60, 10)
		base.Parent = nest
		nest.Parent = rig.world
		rig.setState(100, "Awake")
		rig.advance(0.5)
		finishFace(rig)
		local function offsetFromArm(): CFrame
			return rig.arm:GetPivot():Inverse() * base.CFrame
		end
		local first = offsetFromArm()
		local worst = 0
		local function check()
			local now = offsetFromArm()
			for _, point in { Vector3.zero, Vector3.new(5, 0, 0), Vector3.new(0, 5, 0), Vector3.new(0, 0, 5) } do
				worst = math.max(worst, (now:PointToWorldSpace(point) - first:PointToWorldSpace(point)).Magnitude)
			end
		end
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		for index = 1, 240 do
			if index == 120 then
				rig.slamWarning:Fire(2, AHEAD_RIGHT, 0)
			end
			rig.advance(FRAME)
			check()
		end
		expect(worst).toBeLessThan(0.01)
	end)

	it(
		"puts the arm and head back on the shared clock when the Phase change comes after the awake time ends",
		function()
			local rig = wokenRig()
			rig.advance(15.3) -- the Phase change reaches this device 0.3 s after PhaseEndsAt
			sleepAgain(rig)
			rig.advance(0.2) -- 0.5 s after PhaseEndsAt
			expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
			expect(samePlace(rig.head:GetPivot(), rig.headStart)).toBe(true)
		end
	)

	it("has the arm and head at rest on the first frame when the Phase change is over 0.5 s late", function()
		local rig = wokenRig()
		rig.advance(15.7)
		sleepAgain(rig)
		rig.advance(FRAME)
		expect(atRest(rig)).toBe(true)
	end)

	it("still takes the full 0.5 s to return when the Phase change comes before the awake time ends", function()
		local rig = wokenRig()
		rig.advance(14.9)
		sleepAgain(rig)
		rig.advance(0.25)
		local share = GiantFx.poseShare(0.25)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * rig.armStart)).toBe(
			true
		)
	end)

	it("still takes the full 0.5 s to return when the server wrote no PhaseEndsAt", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(15.2)
		rig.setState(100, "HeavySleep")
		rig.advance(0.25)
		local share = GiantFx.poseShare(0.25)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * rig.armStart)).toBe(
			true
		)
	end)

	it("has the arm at rest within ArmReturnSeconds of the 6th fist through a whole wake-up", function()
		local rig = wokenRig()
		local times = Config.Wake.SlamWarningTimes
		local points = { AHEAD_LEFT, AHEAD_RIGHT, AHEAD_LEFT, AHEAD_RIGHT, AHEAD_LEFT, AHEAD_RIGHT }
		-- The 6th fist lands 1.5 s after its warning (Config.Wake.SlamWarningSeconds): 13.5 + 1.5 = 15.0.
		local lastFist = times[#times] + Config.Wake.SlamWarningSeconds
		local sleepAt = AWAKE_SECONDS + 0.3
		local restBy = lastFist + Config.Nests.ArmReturnSeconds + FRAME
		local nextWarning = 1
		local asleep = false
		local elapsed = 0
		local frameCount = 0
		while elapsed < restBy do
			frameCount += 1
			elapsed = frameCount * FRAME
			if nextWarning <= #times and elapsed >= times[nextWarning] then
				rig.slamWarning:Fire(
					nextWarning,
					points[nextWarning],
					WAKE_CLOCK + elapsed + Config.Wake.SlamWarningSeconds
				)
				nextWarning += 1
			end
			if not asleep and elapsed >= sleepAt then
				asleep = true
				sleepAgain(rig)
			end
			rig.advance(FRAME)
		end
		expect(atRest(rig)).toBe(true)
	end)
end)
