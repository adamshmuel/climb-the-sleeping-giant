--!strict
-- The maths of the bonk on screen (spec Rule 61): how far the body is tipped over at a moment, the point it turns
-- about, and where each of the 4 stars is on its ring. Pure: no Instances except CFrame and Vector3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- The body lies flat on its back: a quarter turn. The one place this number lives.
local TIP_ANGLE = math.pi / 2
-- A star's ring: how far it reaches from the label's middle (0 to 1 across, and up and down).
local RING_X = 0.38
local RING_Y = 0.2

local BonkPose = {}

export type Box = { cframe: CFrame, size: Vector3 } -- a body part in the root part's space
export type StarPlace = { x: number, y: number, depth: number }

-- How far the body is tipped back (radians) this many seconds after the bonk starts: 0 before it, a straight line
-- up to a quarter turn, held, a straight line back to 0, then 0.
function BonkPose.angleAt(seconds: number): number
	local wake = Config.Wake
	local down = wake.TumbleDownSeconds
	local holdEnd = down + wake.TumbleStillSeconds
	local upEnd = holdEnd + wake.TumbleUpSeconds
	if seconds <= 0 or seconds >= upEnd then
		return 0
	elseif seconds <= down then
		return TIP_ANGLE * seconds / down
	elseif seconds <= holdEnd then
		return TIP_ANGLE
	end
	return TIP_ANGLE * (upEnd - seconds) / wake.TumbleUpSeconds
end

-- The joint's new C0 when the whole body turns by `angle` about `pivot` (root-part space). A positive angle puts the
-- head toward +Z, behind him, because the character looks toward -Z.
function BonkPose.tipped(restC0: CFrame, pivot: Vector3, angle: number): CFrame
	return CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot) * restC0
end

-- The Transform that tips a joint (AnimationConstraint or Motor6D) the same way: the joint's part ends at
-- `Part0 * C0 * Transform * C1:Inverse()`, so `rest * tippedTransform(...) == tipped(...)`.
function BonkPose.tippedTransform(restC0: CFrame, pivot: Vector3, angle: number): CFrame
	return restC0:Inverse() * BonkPose.tipped(restC0, pivot, angle)
end

-- The point the body turns about: x 0, the lowest corner's height, the highest corner's z (the heels' back edge on
-- the ground). After a quarter turn every corner is at or above this height.
function BonkPose.pivotOf(boxes: { Box }): Vector3
	if #boxes == 0 then
		return Vector3.zero
	end
	local lowest = math.huge
	local highestZ = -math.huge
	for _, part in boxes do
		local half = part.size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = part.cframe:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
					lowest = math.min(lowest, corner.Y)
					highestZ = math.max(highestZ, corner.Z)
				end
			end
		end
	end
	return Vector3.new(0, lowest, highestZ)
end

-- Where star `index` of `count` sits on the ring (0 to 1 across the label), and its depth (-1 to 1: behind to in
-- front). The ring turns once every `turnSeconds`, unless `still` (Reduce Motion).
function BonkPose.starPlace(
	index: number,
	count: number,
	seconds: number,
	still: boolean,
	turnSeconds: number
): StarPlace
	local angle = 2 * math.pi * (index - 1) / count
	if not still then
		angle += 2 * math.pi * seconds / turnSeconds
	end
	return {
		x = 0.5 + RING_X * math.cos(angle),
		y = 0.5 + RING_Y * math.sin(angle),
		depth = math.sin(angle),
	}
end

return BonkPose
