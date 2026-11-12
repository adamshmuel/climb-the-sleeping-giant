--!strict
-- The fake bodies the bonk tests share (BonkPose.spec and BonkFx.spec): the part names, sizes and rest places in the
-- root part's space, as box lists, and the same data built into a character with the real joint. R15 follows Studio's
-- default rig: an AnimationConstraint `Root` under LowerTorso, its Attachment0 `RootRigAttachment` on the root part
-- and its Attachment1 `RootRigAttachment` on LowerTorso (C0 and C1 are read-only aliases of the attachments' CFrames).
-- R6: a Motor6D `RootJoint` under the root part. Real sizes; every part is 1 stud deep (back face at z 0.5).
-- R15: the feet's bottoms are 3 below the root; the head's middle is 2.1 above it.
-- R6: the feet's bottoms are 3 below the root; the head's middle is 1.5 above it.

local StarterPlayer = game:GetService("StarterPlayer")

local BonkPose = require(StarterPlayer.StarterPlayerScripts.Client.Fx.BonkPose)

local BonkRigs = {}

export type Box = BonkPose.Box
export type Kind = "R15" | "R6"
-- A built fake character: the model, its root part, its head, the joint the tumble turns, and the joint's attachments
-- (2 for the R15 AnimationConstraint, none for the R6 Motor6D).
export type Rig = {
	character: Model,
	root: BasePart,
	head: BasePart,
	joint: AnimationConstraint | Motor6D,
	attachments: { Attachment },
}

type Piece = { name: string, cframe: CFrame, size: Vector3 }

local ROOT_NAME = "HumanoidRootPart"
local ROOT_SIZE = Vector3.new(2, 2, 1)
local JOINT_NAMES = { R15 = "Root", R6 = "RootJoint" }
-- The part the joint's Part1 is: the one the whole body hangs on.
local JOINTED_PART = { R15 = "LowerTorso", R6 = "Torso" }

local function piece(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number): Piece
	return { name = name, cframe = CFrame.new(x, y, z), size = Vector3.new(sx, sy, sz) }
end

-- Every part except the root. R15 is listed head first; R6 in a different order (legs first).
local function pieces(kind: Kind): { Piece }
	if kind == "R15" then
		return {
			piece("Head", 0, 2.1, 0, 2, 1, 1),
			piece("UpperTorso", 0, 0.8, 0, 2, 1.6, 1),
			piece("LowerTorso", 0, -0.2, 0, 2, 0.4, 1),
			piece("LeftUpperArm", -1.5, 1.0, 0, 1, 1.2, 1),
			piece("RightUpperArm", 1.5, 1.0, 0, 1, 1.2, 1),
			piece("LeftLowerArm", -1.5, 0, 0, 1, 1.1, 1),
			piece("RightLowerArm", 1.5, 0, 0, 1, 1.1, 1),
			piece("LeftUpperLeg", -0.5, -1.0, 0, 1, 1.2, 1),
			piece("RightUpperLeg", 0.5, -1.0, 0, 1, 1.2, 1),
			piece("LeftLowerLeg", -0.5, -2.0, 0, 1, 1.4, 1),
			piece("RightLowerLeg", 0.5, -2.0, 0, 1, 1.4, 1),
			piece("LeftFoot", -0.5, -2.85, 0, 1, 0.3, 1),
			piece("RightFoot", 0.5, -2.85, 0, 1, 0.3, 1),
		}
	end
	return {
		piece("Right Leg", 0.5, -2, 0, 1, 2, 1),
		piece("Left Leg", -0.5, -2, 0, 1, 2, 1),
		piece("Right Arm", 1.5, 0, 0, 1, 2, 1),
		piece("Left Arm", -1.5, 0, 0, 1, 2, 1),
		piece("Head", 0, 1.5, 0, 2, 1, 1),
		piece("Torso", 0, 0, 0, 2, 2, 1),
	}
end

-- The box list of one rig: every part except the root, in the root part's space.
function BonkRigs.boxesOf(kind: Kind): { Box }
	local boxes: { Box } = {}
	for _, one in pieces(kind) do
		table.insert(boxes, { cframe = one.cframe, size = one.size })
	end
	return boxes
end

-- The joint's C0, read. The typed API has no C0 on AnimationConstraint (it is a read-only alias of Attachment0's CFrame),
-- so the R15 joint is read through its attachment. Reading is all anyone does: the tumble never writes C0.
function BonkRigs.c0Of(rig: Rig): CFrame
	if #rig.attachments > 0 then
		return rig.attachments[1].CFrame -- Attachment0, on the root part
	end
	return (rig.joint :: Motor6D).C0
end

-- Writes the joint's Transform, as the Animator does each frame.
function BonkRigs.setTransform(rig: Rig, transform: CFrame)
	local joint = rig.joint
	if joint:IsA("AnimationConstraint") then
		(joint :: AnimationConstraint).Transform = transform
	else
		(joint :: Motor6D).Transform = transform
	end
end

-- Both rigs' box lists, by name.
function BonkRigs.boxes(): { [string]: { Box } }
	return { R15 = BonkRigs.boxesOf("R15"), R6 = BonkRigs.boxesOf("R6") }
end

-- Builds a fake character with its root part at `at` (default 5 studs up): a Humanoid, the root part, every other
-- part at its rest place, and the joint (root side = root, C0 = the jointed part's rest place, C1 = identity). Like the
-- real ones it has no PrimaryPart; `reversed` puts the root part and the joint's part last among the children.
-- The caller destroys `character`.
function BonkRigs.build(kind: Kind, reversed: boolean?, at: CFrame?): Rig
	local origin = at or CFrame.new(0, 5, 0)
	local character = Instance.new("Model")
	character.Name = `Fake{kind}`
	Instance.new("Humanoid").Parent = character

	local root = Instance.new("Part")
	root.Name = ROOT_NAME
	root.Size = ROOT_SIZE
	root.CFrame = origin

	local list = pieces(kind)
	if reversed == true then
		local flipped: { Piece } = {}
		for index = #list, 1, -1 do
			table.insert(flipped, list[index])
		end
		list = flipped
	else
		root.Parent = character
	end

	local jointed: BasePart? = nil
	local head: BasePart? = nil
	local jointedAt = CFrame.new()
	for _, one in list do
		local part = Instance.new("Part")
		part.Name = one.name
		part.Size = one.size
		part.CFrame = origin * one.cframe
		part.Parent = character
		if one.name == JOINTED_PART[kind] then
			jointed = part
			jointedAt = one.cframe
		elseif one.name == "Head" then
			head = part
		end
	end
	if reversed == true then
		root.Parent = character
	end

	local joint: AnimationConstraint | Motor6D
	local attachments: { Attachment } = {}
	if kind == "R15" then
		local rootSide = Instance.new("Attachment")
		rootSide.Name = "RootRigAttachment"
		rootSide.CFrame = jointedAt
		rootSide.Parent = root
		local partSide = Instance.new("Attachment")
		partSide.Name = "RootRigAttachment"
		partSide.CFrame = CFrame.new()
		partSide.Parent = jointed
		local constraint = Instance.new("AnimationConstraint")
		constraint.Name = JOINT_NAMES[kind]
		constraint.Attachment0 = rootSide
		constraint.Attachment1 = partSide
		constraint.Parent = jointed
		joint = constraint
		attachments = { rootSide, partSide }
	else
		local motor = Instance.new("Motor6D")
		motor.Name = JOINT_NAMES[kind]
		motor.Part0 = root
		motor.Part1 = jointed
		motor.C0 = jointedAt
		motor.C1 = CFrame.new()
		motor.Parent = root
		joint = motor
	end

	return { character = character, root = root, head = head :: BasePart, joint = joint, attachments = attachments }
end

return BonkRigs
