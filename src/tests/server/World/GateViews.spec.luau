--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Workspace = game:GetService("Workspace")

-- Split from WaysUp.spec.luau (size limit). These tests only READ the real world.

local function ladderOf(side: number): Model
	local world = Workspace:FindFirstChild("World")
	expect(world).never.toBeNil()
	local surfaces = (world :: Instance):FindFirstChild("WalkSurfaces")
	expect(surfaces).never.toBeNil()
	local ladder = (surfaces :: Instance):FindFirstChild(if side < 0 then "BootLadder_Left" else "BootLadder_Right")
	expect(ladder).never.toBeNil()
	return ladder :: Model
end

-- Task 4g (docs/plans/v2/gardens-and-ways-up.md): a kid at home in garden 1, 2, 7 or 8 sees the boot ladder.
-- Spec Rule 44 (Your way up is in view from home). Looking is not walking, so the rays ignore collision
-- (RespectCanCollide = false). The camera spots are the fixed gate cameras of docs/design/v2/look-cameras.md.
describe("the gate views show the boot ladders (four g)", function()
	local GATE_VIEWS: { { gate: number, camera: Vector3, side: number } } = {
		{ gate = 1, camera = Vector3.new(-142.2, 3.9, 11.7), side = -1 },
		{ gate = 2, camera = Vector3.new(-132, 4.5, -54.1), side = -1 },
		{ gate = 7, camera = Vector3.new(132, 4.5, -54.1), side = 1 },
		{ gate = 8, camera = Vector3.new(142.2, 3.9, 11.7), side = 1 },
	}
	local POINTS = 11
	local MIN_CLEAR = 7 -- the giant's boots always hide the two end points, so 9 is the most possible

	-- The two ends of the ladder model's long side, as {top, bottom}.
	local function modelEnds(ladder: Model): (Vector3, Vector3)
		local box, size = ladder:GetBoundingBox()
		local axis, length = box.RightVector, size.X
		if size.Y > length then
			axis, length = box.UpVector, size.Y
		end
		if size.Z > length then
			axis, length = box.LookVector, size.Z
		end
		if axis.Y < 0 then
			axis = -axis
		end
		return box.Position + axis * length / 2, box.Position - axis * length / 2
	end

	it("from each gate camera at least 7 of 11 points along the ladder can be seen (Rule 44)", function()
		for _, view in GATE_VIEWS do
			local ladder = ladderOf(view.side)
			local top, bottom = modelEnds(ladder)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			-- Fully invisible parts (the egg posts) can't hide the ladder from a player, so the rays skip them.
			local skip: { Instance } = { ladder }
			for _, part in Workspace:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency >= 1 then
					table.insert(skip, part)
				end
			end
			params.FilterDescendantsInstances = skip
			params.RespectCanCollide = false
			local clear = 0
			for i = 0, POINTS - 1 do
				local point = top:Lerp(bottom, i / (POINTS - 1))
				if Workspace:Raycast(view.camera, point - view.camera, params) == nil then
					clear += 1
				end
			end
			expect(`gate {view.gate}: {clear} of {POINTS} clear`).toBe(
				`gate {view.gate}: {math.max(clear, MIN_CLEAR)} of {POINTS} clear`
			)
		end
	end)
end)
