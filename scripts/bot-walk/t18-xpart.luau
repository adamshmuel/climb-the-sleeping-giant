--!strict
-- Plan 3 Task 18, Step 1 (work/p3t18/t18-card.md, row X): SERVER paste in Play. Toggles one anchored test part, T18TestRamp
-- (6 wide, 1 thick, 6 long), straight ahead of the first left plank row (the start of t18-tries' X1 and PL1: feet -20.5,
-- 29.91, -55.5, pushing toward BellyRamp_Left's foot at -1.9, -49.3). First paste makes it, a second paste destroys it.
-- Its top is the plank deck's surface at its centre plus TOP_LIFT, so a down ray from a landing on it hits it, not the deck
-- (the card says "top at the plank deck's top y"; the deck slopes up about 0.22 per stud, so a flush top would lose the ray).
local CHECK_ONLY = false

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PART_NAME = "T18TestRamp"
local START = Vector3.new(-20.5, 29.91, -55.5)
local FOOT = Vector3.new(-1.9, 0, -49.3)
local AHEAD, TOP_LIFT, THICK = 8, 0.7, 1

local function job(): string
	if CHECK_ONLY or not RunService:IsRunning() then
		return "no Play: nothing made"
	end
	local old = Workspace:FindFirstChild(PART_NAME)
	if old ~= nil then
		old:Destroy()
		return `{PART_NAME} destroyed (still there: {if Workspace:FindFirstChild(PART_NAME) ~= nil then "yes" else "no"})`
	end
	local walkSurfaces = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("WalkSurfaces")
	if walkSurfaces == nil then
		return "STOP: Workspace.World.WalkSurfaces missing"
	end
	local dir = Vector3.new(FOOT.X - START.X, 0, FOOT.Z - START.Z).Unit
	local center = Vector3.new(START.X, 0, START.Z) + dir * AHEAD
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { walkSurfaces }
	local hit = Workspace:Raycast(Vector3.new(center.X, 45, center.Z), Vector3.new(0, -30, 0), params)
	if hit == nil then
		return `STOP: no deck under {string.format("%.1f, %.1f", center.X, center.Z)}`
	end
	local top = hit.Position.Y + TOP_LIFT
	local part = Instance.new("Part")
	part.Name = PART_NAME
	part.Size = Vector3.new(6, THICK, 6)
	part.Anchored = true
	part.CanCollide = true
	part.CFrame = CFrame.lookAt(
		Vector3.new(center.X, top - THICK / 2, center.Z),
		Vector3.new(center.X, top - THICK / 2, center.Z) + dir
	)
	part.Parent = Workspace
	return `{PART_NAME} made at {string.format("%.1f, %.1f, %.1f", center.X, top, center.Z)} over {hit.Instance.Name} (deck surface {string.format(
		"%.2f",
		hit.Position.Y
	)})`
end

return job()
