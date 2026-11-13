--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local FIXED_DIRECTION = Helpers.FIXED_DIRECTION
local GIANT_PIVOT = Helpers.GIANT_PIVOT
local RAISE_DEGREES = Helpers.RAISE_DEGREES
local SHOULDER = Helpers.SHOULDER
local cleanUp = Helpers.cleanUp
local degreesBetween = Helpers.degreesBetween
local finishFace = Helpers.finishFace
local made = Helpers.made
local newRig = Helpers.newRig
local samePlace = Helpers.samePlace

afterEach(cleanUp)

describe("GiantFx.start: the arm swing", function()
	local AHEAD_LEFT = Vector3.new(-30, 2, -60)
	local AHEAD_RIGHT = Vector3.new(90, 2, -45)
	local BELLY = Vector3.new(-12.7, 49, -40.6)

	local function armMiddle(rig: Rig): Vector3
		return (rig.arm:GetBoundingBox()).Position
	end

	-- How many degrees the arm's middle is off the line from the shoulder to `point`.
	local function offLine(rig: Rig, point: Vector3): number
		return degreesBetween(armMiddle(rig) - SHOULDER, point - SHOULDER)
	end

	local function awakeRig(): Rig
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		finishFace(rig) -- the wake face keeps the step connected after the pose; wait it out
		return rig
	end

	local function fullRaise(rig: Rig): CFrame
		return GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart
	end

	it("points the arm's middle at the target 0.5 seconds after the warning", function()
		for _, point in { AHEAD_LEFT, AHEAD_RIGHT, BELLY } do
			local rig = awakeRig()
			rig.slamWarning:Fire(1, point, 0)
			rig.advance(0.5)
			expect(offLine(rig, point) < 1).toBe(true)
		end
	end)

	it("starts from the raised fist: the warning itself moves nothing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
		rig.advance(0)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("swings out with the easing: half way round at 0.25 seconds", function()
		local rig = awakeRig()
		local raisedMiddle = armMiddle(rig)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.25)
		local total = degreesBetween(raisedMiddle - SHOULDER, AHEAD_LEFT - SHOULDER)
		local done = degreesBetween(raisedMiddle - SHOULDER, armMiddle(rig) - SHOULDER)
		expect(total > 10).toBe(true)
		expect(math.abs(done - total / 2) < 1).toBe(true)
	end)

	it("is still pointing at the target at 1.9 seconds", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_RIGHT, 0)
		rig.advance(1.9)
		expect(offLine(rig, AHEAD_RIGHT) < 1).toBe(true)
	end)

	it("is back on the full-raise pivot at 2.4 seconds", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1.9)
		rig.advance(0.51)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("lets go of the step when the swing is over", function()
		local rig = awakeRig()
		expect(rig.step:count()).toBe(0)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(rig.step:count()).toBe(1)
		rig.advance(2.5)
		expect(rig.step:count()).toBe(0)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("counts the swing from when the warning arrived, however many frames that is", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		for _ = 1, 30 do
			rig.advance(0.5 / 30)
		end
		expect(offLine(rig, AHEAD_LEFT) < 1).toBe(true)
	end)

	it("moves nothing for a warning that arrives while he is asleep", function()
		local rig = newRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("moves nothing for a warning that arrives while he settles back to sleep", function()
		local rig = awakeRig()
		rig.setState(0, "HeavySleep")
		rig.advance(0.2) -- 0.3 seconds into the pose back
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.1) -- 0.2 seconds left of the pose
		local share = GiantFx.poseShare(0.2)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * rig.armStart)).toBe(
			true
		)
		rig.advance(0.4)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("puts the arm back on its start pivot when Phase leaves Awake in the middle of a swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(offLine(rig, AHEAD_LEFT) < 1).toBe(true)
		rig.setState(0, "HeavySleep")
		rig.advance(0.6)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(2)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("takes the swing back with the pose: the swing share is scaled by how far the pose still is", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		rig.setState(0, "HeavySleep")
		rig.advance(0.25) -- 1.25 s into the swing (all the way out), and half way back in the pose
		local poseShare = GiantFx.poseShare(0.25)
		-- The arm's middle at the start, which is the middle of its one part.
		local from = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1):PointToWorldSpace(Vector3.new(41, 68, 8)) - SHOULDER
		local expected = GiantFx.slamTurn(SHOULDER, from, AHEAD_LEFT, poseShare)
			* GiantFx.armRaise(SHOULDER, RAISE_DEGREES, poseShare)
			* rig.armStart
		expect(samePlace(rig.arm:GetPivot(), expected)).toBe(true)
	end)

	it("ends the 6th swing at the end of Awake without leaving the arm out", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(6, AHEAD_RIGHT, 0)
		rig.advance(1.5) -- the 6th slam lands as Phase turns HeavySleep
		rig.setState(0, "HeavySleep")
		rig.advance(0.55) -- the pose is back at rest, but the swing has 0.35 seconds left
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.2)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.5)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("lets a new warning replace the swing before it", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		rig.slamWarning:Fire(2, AHEAD_RIGHT, 0)
		rig.advance(0.5)
		expect(offLine(rig, AHEAD_RIGHT) < 1).toBe(true)
		rig.advance(1.9)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("ignores a warning whose point is not a position", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, "there", 0)
		rig.slamWarning:Fire(1, nil, 0)
		rig.advance(1)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("puts the arm on its start pivot when stopped in the middle of a swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		rig.handle.stop()
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
		expect(rig.slamWarning:count()).toBe(0)
	end)

	it("changes nothing for a warning after stop", function()
		local rig = awakeRig()
		rig.handle.stop()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("does not move the head or the other pieces", function()
		local rig = awakeRig()
		local headBefore = rig.head:GetPivot()
		local lidBefore = rig.leftLid:GetPivot()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(rig.head:GetPivot() == headBefore).toBe(true)
		expect(rig.leftLid:GetPivot() == lidBefore).toBe(true)
	end)

	it("swings from the full raise even when he was already awake when the script started", function()
		local rig = newRig(nil, "Awake")
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.5)
		expect(offLine(rig, AHEAD_LEFT) < 1).toBe(true)
		rig.advance(2)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)
end)

describe("GiantFx.start: the arm and his body", function()
	local AHEAD_LEFT = Vector3.new(-30, 2, -60)
	local AHEAD_RIGHT = Vector3.new(90, 2, -45)
	-- The arm's middle at the start (the middle of its one part), and its direction from the shoulder in the full raise.
	local FROM = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1):PointToWorldSpace(Vector3.new(41, 68, 8)) - SHOULDER

	local function armMiddle(rig: Rig): Vector3
		return (rig.arm:GetBoundingBox()).Position
	end

	local function offDirection(rig: Rig, direction: Vector3): number
		return degreesBetween(armMiddle(rig) - SHOULDER, direction)
	end

	local function awakeRig(): Rig
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		return rig
	end

	local function blocked(_shoulder: Vector3, _direction: Vector3): boolean
		return false
	end

	local function fullRaise(rig: Rig): CFrame
		return GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart
	end

	it("asks four times when the warning arrives, with the shoulder and the directions of the swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(#rig.armClearCalls).toBe(4)
		for index, share in { 0.25, 0.5, 0.75, 1 } do
			local expected = GiantFx.slamTurn(SHOULDER, FROM, AHEAD_LEFT, share):VectorToWorldSpace(FROM)
			expect(rig.armClearCalls[index].shoulder == SHOULDER).toBe(true)
			expect((rig.armClearCalls[index].direction - expected).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("points at the target when the arm is clear", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) < 1).toBe(true)
	end)

	it("goes to the fixed pose 0.5 seconds after the warning when the arm is blocked", function()
		local rig = awakeRig()
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
		-- And not at the target.
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) > 5).toBe(true)
	end)

	it("turns the fixed pose with the giant", function()
		local rig = awakeRig()
		rig.giant.WorldPivot = GIANT_PIVOT * CFrame.Angles(0, math.rad(90), 0)
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_RIGHT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, Vector3.new(FIXED_DIRECTION.Z, FIXED_DIRECTION.Y, -FIXED_DIRECTION.X)) < 1).toBe(true)
	end)

	it("keeps the fixed pose until the fist lifts, then is back on the full-raise pivot at 2.4 seconds", function()
		local rig = awakeRig()
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1.9)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
		rig.advance(0.51)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("swings to the fixed pose with the same easing: half way round at 0.25 seconds", function()
		local rig = awakeRig()
		local raisedMiddle = armMiddle(rig)
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.25)
		local total = degreesBetween(raisedMiddle - SHOULDER, FIXED_DIRECTION)
		local done = degreesBetween(raisedMiddle - SHOULDER, armMiddle(rig) - SHOULDER)
		expect(total > 10).toBe(true)
		expect(math.abs(done - total / 2) < 1).toBe(true)
	end)

	it("decides once: a stand-in that turns to blocked after the warning does not move the aim", function()
		local rig = awakeRig()
		local blockedNow = false
		rig.setArmClear(function(_shoulder: Vector3, _direction: Vector3)
			return not blockedNow
		end)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		blockedNow = true
		rig.advance(0.5)
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) < 1).toBe(true)
		rig.advance(1.4)
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) < 1).toBe(true)
	end)

	it("decides once: a stand-in that turns to clear after the warning keeps the fixed pose", function()
		local rig = awakeRig()
		local blockedNow = true
		rig.setArmClear(function(_shoulder: Vector3, _direction: Vector3)
			return not blockedNow
		end)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		blockedNow = false
		rig.advance(0.5)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
		rig.advance(1.4)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
	end)

	it("asks only when the warning arrives, never again on the frames of the swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		local asked = #rig.armClearCalls
		for _ = 1, 20 do
			rig.advance(0.1)
		end
		expect(#rig.armClearCalls).toBe(asked)
	end)

	it("decides again for the next warning", function()
		local rig = awakeRig()
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(2.5)
		rig.setArmClear(function(_shoulder: Vector3, _direction: Vector3)
			return true
		end)
		rig.slamWarning:Fire(2, AHEAD_RIGHT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, AHEAD_RIGHT - SHOULDER) < 1).toBe(true)
	end)

	it("asks nothing for a warning that arrives while he is asleep", function()
		local rig = newRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(#rig.armClearCalls).toBe(0)
	end)

	it("asks nothing for a warning whose point is not a position", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, "there", 0)
		expect(#rig.armClearCalls).toBe(0)
	end)
end)

describe("GiantFx.workspaceArmClear", function()
	-- A fake world far from the map, with a Giant that has a body piece, a right arm and a boot.
	local SHOULDER_AT = Vector3.new(2000, 50, 2000)
	local EAST = Vector3.new(1, 0, 0)

	local function newWorld(): Folder
		local world = made(Instance.new("Folder"))
		world.Name = "World"
		local giant = Instance.new("Model")
		giant.Name = "Giant"
		giant.Parent = world
		world.Parent = Workspace
		return world
	end

	local function pieceOf(giant: Instance, name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = giant
		return model
	end

	-- A 4-stud block `studs` east of the shoulder.
	local function blockAt(studs: number, parent: Instance): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(4, 4, 4)
		part.CFrame = CFrame.new(SHOULDER_AT + EAST * studs)
		part.Parent = parent
		return part
	end

	local function giantOf(world: Folder): Model
		return world:FindFirstChild("Giant") :: Model
	end

	it("is not clear when a part of his body is on the line 20 studs out", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(false)
	end)

	it("is clear when the only part of his body on the line is 55 studs out, beyond the arm", function()
		local world = newWorld()
		blockAt(55, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is clear when the only part on the line is under the right arm itself", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "right_arm"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is clear when the part on the line is outside the Giant", function()
		local world = newWorld()
		pieceOf(giantOf(world), "body_and_cushion")
		blockAt(20, world)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is clear when there is no Giant", function()
		local world = made(Instance.new("Folder"))
		world.Parent = Workspace
		blockAt(20, world)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is not clear when a part that is a direct child of the Giant is on the line", function()
		local world = newWorld()
		blockAt(20, giantOf(world))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(false)
	end)

	it(
		"counts a part that can't be collided with: the body blocks the arm even if a player walks through it",
		function()
			local world = newWorld()
			blockAt(20, pieceOf(giantOf(world), "head_with_beard")).CanCollide = false
			local clear = GiantFx.workspaceArmClear(Workspace, world)
			expect(clear(SHOULDER_AT, EAST)).toBe(false)
		end
	)

	it("uses the direction's way, not its length", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST * 0.01)).toBe(false)
		expect(clear(SHOULDER_AT, EAST * 500)).toBe(false)
		expect(clear(SHOULDER_AT, -EAST)).toBe(true)
	end)

	it("looks at the Giant's pieces each time it is asked, so a piece that streams in later counts", function()
		local world = newWorld()
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
		blockAt(20, pieceOf(giantOf(world), "legs_and_boots"))
		expect(clear(SHOULDER_AT, EAST)).toBe(false)
	end)

	it("is clear for a direction of nothing, instead of making a NaN ray", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, Vector3.zero)).toBe(true)
	end)
end)
