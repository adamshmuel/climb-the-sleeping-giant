--!strict
-- The pure maths of the warnings and the pose: what a warning does, the smooth easing, the slam swing, the head tip and the arm raise, the lid lift and the fades. No instances, no state.

local Shared = require(script.Parent.Shared)

local PLAN_60 = Shared.PLAN_60
local PLAN_85 = Shared.PLAN_85
local PLAN_NONE = Shared.PLAN_NONE
local smooth = Shared.smooth

local Motion = {}

-- The slam swing is checked at these shares of the way to the target: a quarter, half, three quarters and all of it.
local SWING_CHECK_SHARES: { number } = table.freeze({ 0.25, 0.5, 0.75, 1 })
-- The piece of the giant that is the arm itself, which the arm's path doesn't count as his body.
local ARM_NAME = "right_arm"

-- What each warning does. Any other mark does nothing.
function Motion.warningPlan(mark: any): { string }
	if mark == 60 then
		return PLAN_60
	elseif mark == 85 then
		return PLAN_85
	end
	return PLAN_NONE
end

-- How far into the waking pose it is, from 0 (at rest) to 1 (the full pose), `seconds` after it started. It starts and
-- finishes smoothly, like the warnings.
function Motion.poseShare(seconds: number): number
	return smooth(seconds / Shared.poseSeconds)
end

-- The turn about `shoulder` that swings the arm toward a target: it turns the direction `from` toward the direction
-- (toward - shoulder) by `share` of the angle between them. At share 0 it is the identity, and at share 1 `from` points
-- exactly at the target. Put it in front of the arm's other turns: slamTurn * armRaise * start. Directions that are
-- already the same turn nothing; exactly opposite directions turn about any axis at right angles to `from`; a target
-- on the shoulder itself, or no `from`, turn nothing.
function Motion.slamTurn(shoulder: Vector3, from: Vector3, toward: Vector3, share: number): CFrame
	local aim = toward - shoulder
	if from.Magnitude < 1e-6 or aim.Magnitude < 1e-6 or share == 0 then
		return CFrame.identity
	end
	local start = from.Unit
	local goal = aim.Unit
	local cross = start:Cross(goal)
	local angle = math.atan2(cross.Magnitude, start:Dot(goal))
	local axis: Vector3
	if cross.Magnitude > 1e-6 then
		axis = cross.Unit
	elseif angle > math.pi / 2 then
		-- Exactly opposite: any axis at right angles to `from` will do.
		local helper = if math.abs(start.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		axis = start:Cross(helper).Unit
	else
		return CFrame.identity
	end
	return CFrame.new(shoulder) * CFrame.fromAxisAngle(axis, angle * share) * CFrame.new(-shoulder)
end

-- How far out the arm is swung, from 0 (raised, as after waking) to 1 (pointing at the target), `seconds` after the
-- SlamWarning arrived. It swings out over 0.5 seconds with the same smooth easing as the pose, stays out until the fist
-- starts to lift, comes back over 0.5 seconds, and is 0 for good after that.
function Motion.slamShare(seconds: number): number
	if seconds <= 0 then
		return 0
	elseif seconds < Shared.slamSwingSeconds then
		return smooth(seconds / Shared.slamSwingSeconds)
	elseif seconds <= Shared.slamHoldUntil then
		return 1
	end
	return 1 - smooth((seconds - Shared.slamHoldUntil) / Shared.slamSwingSeconds)
end

-- The point the arm aims at in the fixed pose: GiantFx.armLength studs from `shoulder`, 70 degrees raised forward and 25
-- degrees out to his right. The directions are in the giant's own axes (he faces -Z, his right is +X), so they turn with
-- `giantPivot`: hanging straight down, raised `forward` degrees toward the front, then `out` degrees toward his right.
function Motion.slamFixedAim(shoulder: Vector3, giantPivot: CFrame): Vector3
	local forward = math.rad(Shared.slamFixedForwardDegrees)
	local out = math.rad(Shared.slamFixedOutDegrees)
	local direction = Vector3.new(math.sin(out), -math.cos(forward) * math.cos(out), -math.sin(forward) * math.cos(out))
	return shoulder + giantPivot:VectorToWorldSpace(direction) * Shared.armLength
end

-- Where the arm aims at a slam: `point` if the arm's straight line from `shoulder` stays clear of his body through the
-- whole swing, otherwise `fixedAim`. The swing is checked at a quarter, half, three quarters and all of the way: for
-- each, `isClear` is asked about the direction the arm's own direction `from` points in after that much of the turn.
function Motion.slamAim(
	shoulder: Vector3,
	from: Vector3,
	point: Vector3,
	fixedAim: Vector3,
	isClear: (shoulder: Vector3, direction: Vector3) -> boolean
): Vector3
	for _, share in SWING_CHECK_SHARES do
		local direction = Motion.slamTurn(shoulder, from, point, share):VectorToWorldSpace(from)
		if not isClear(shoulder, direction) then
			return fixedAim
		end
	end
	return point
end

-- The real way to ask whether the arm's path is clear: one ray from the shoulder along the direction, as long as the
-- arm, that sees only the giant's own pieces except the right arm. It looks at the giant's pieces each time, because
-- they can stream in and out on a player's device. With no giant there is no arm to move, so the path counts as clear.
function Motion.workspaceArmClear(
	workspace: WorldRoot,
	world: Instance
): (shoulder: Vector3, direction: Vector3) -> boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	return function(shoulder: Vector3, direction: Vector3): boolean
		local giant = world:FindFirstChild("Giant")
		if giant == nil or direction.Magnitude < 1e-6 then
			return true
		end
		local body: { Instance } = {}
		for _, piece in giant:GetChildren() do
			if piece.Name ~= ARM_NAME then
				table.insert(body, piece)
			end
		end
		params.FilterDescendantsInstances = body
		return workspace:Raycast(shoulder, direction.Unit * Shared.armLength, params) == nil
	end
end

-- The turn that tips the head `share` of the way: put it in front of a piece's start pivot (turn * start). The head
-- turns about the X axis through `pivot`, by `tiltDegrees` times `share`.
function Motion.headTurn(pivot: Vector3, tiltDegrees: number, share: number): CFrame
	return CFrame.new(pivot) * CFrame.Angles(math.rad(tiltDegrees * share), 0, 0) * CFrame.new(-pivot)
end

-- The turn that raises the right arm `share` of the way: put it in front of the arm's start pivot. The arm turns about
-- `shoulder`, around the axis of the rotation CFrame.Angles(x, y, z) (`raiseDegreesXZ` holds x, y and z in degrees: the
-- same axis the wake-up raise uses), by that rotation's own angle times `share`. At share 1 it is exactly the full raise.
function Motion.armRaise(shoulder: Vector3, raiseDegreesXZ: Vector3, share: number): CFrame
	local full = CFrame.Angles(math.rad(raiseDegreesXZ.X), math.rad(raiseDegreesXZ.Y), math.rad(raiseDegreesXZ.Z))
	local axis, angle = full:ToAxisAngle()
	if angle == 0 then
		return CFrame.identity
	end
	return CFrame.new(shoulder) * CFrame.fromAxisAngle(axis, angle * share) * CFrame.new(-shoulder)
end

-- How far up a flutter is, from 0 (down) to 1 (all the way up), `seconds` after the warning started.
-- Two up-and-down movements, 0.25 s up and 0.25 s down each, with no pause. After the last one it is 0 for good.
function Motion.lift(seconds: number): number
	local total = Shared.flutterSeconds * Shared.flutterCount
	if seconds <= 0 or seconds >= total then
		return 0
	end
	local half = Shared.flutterSeconds / 2
	local inside = (seconds % Shared.flutterSeconds) / half -- 0 to 2 within one movement
	if inside <= 1 then
		return smooth(inside)
	end
	return smooth(2 - inside)
end

-- How many studs a lid is lifted `seconds` after a 60 warning started, for a lid that lifts `flutterLift` studs.
function Motion.flutterLift(seconds: number, flutterLift: number): number
	return flutterLift * Motion.lift(seconds)
end

-- How see-through a Z letter or its outline is `seconds` after a 60 warning started, if it normally has `normal`.
-- It goes to half over the first 0.2 s, holds, and comes back over the last 0.2 s. After 2 s it is `normal` again.
function Motion.fadedTransparency(normal: number, seconds: number): number
	local total = Shared.fadeSeconds
	local edge = Shared.fadeEdgeSeconds
	if seconds <= 0 or seconds >= total then
		return normal
	end
	local share = 1
	if seconds < edge then
		share = seconds / edge
	elseif seconds > total - edge then
		share = (total - seconds) / edge
	end
	return normal + (Shared.fadeTo - normal) * share
end

-- How see-through a Z letter or its outline is `seconds` after the Z Z Z came back at the end of a replayed warning, if
-- it normally has `normal`. It starts fully see-through (1), comes back evenly over 0.2 s, and is `normal` after that.
function Motion.fadedInTransparency(normal: number, seconds: number): number
	if seconds >= Shared.fadeInSeconds then
		return normal
	end
	local share = math.max(seconds, 0) / Shared.fadeInSeconds
	return 1 + (normal - 1) * share
end

return Motion
