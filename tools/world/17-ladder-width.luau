--!strict
-- World prep, V2 stuck safety Task 58: every ladder can be climbed across its whole width
-- (docs/plans/v2/stuck-safety/7-ladder-width.md, "Task 58"; spec Rule 24 and Rule 20).
-- Why: each ladder (BeardLadder, CapLadder) has one 2 stud climbable truss, `Climb`, under rails and rungs 5.2 studs wide.
-- A push a little off the line let go 3 of 3 times (Lesson 153).
-- What it does, for every solid TrussPart under Workspace.World.WalkSurfaces that has `Rail` parts beside it, in that
-- ladder's own model (Lesson 2: never in the giant):
--   * 2 trusses named `ClimbSide`: the same size and lean as `Climb`, 2 studs left and right of it, so 3 trusses cover 6
--     studs (the rails' outer edges are at about 2.63). Fully clear, solid, like `Climb`.
--   * 2 parts named `SideWall`: 0.4 thick, as long as `Climb`, 3 studs deep from the middle line toward the climber, their
--     inner face 3.2 studs from the middle (a 0.2 stud gap from the side trusses, so they never touch). Fully clear, solid.
-- `Climb` is never changed: other checks read the ladder's centre line from it.
-- Three worlds per part, all decided before any change:
--   1. the part is missing: it is added;
--   2. the part is there but differs from the table (size, place, lean, collision or look): it is updated;
--   3. the part is as the table says: it stays.
-- Anything unexpected stops with nothing changed: a solid truss with no rails beside it, a ladder without exactly one
-- centre truss, two parts of one name on one side, a part of the right name but the wrong kind, or an extra one.
-- The message starts with how much changed (Lesson 58): "added 8 parts", "updated 2 parts" or "already done".
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau. The place file must be saved by
-- Adam afterwards. Run twice, it changes nothing the second time.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SIDE_TRUSS = "ClimbSide"
local SIDE_WALL = "SideWall"
local RAIL = "Rail"
local TRUSS_STEP = 2 -- studs: a side truss's middle is this far from the centre truss
local WALL_THICKNESS = 0.4 -- studs across the ladder
local WALL_DEPTH = 3 -- studs from the middle line toward the climber
local WALL_INNER_FACE = 3.2 -- studs from the middle line to the wall's inner face
local SAME_PLACE = 0.05 -- studs: how close an existing part's middle must be to count as in place
local SAME_SIZE = 0.01 -- studs
local SAME_LEAN = 0.001 -- difference between look vectors
local WORLD_UP = Vector3.new(0, 1, 0)

type Plan = {
	ladder: Instance,
	name: string,
	className: string,
	side: number, -- 1 = right of the centre truss's way up, -1 = left
	size: Vector3,
	cframe: CFrame,
	centre: BasePart, -- the centre truss, where the look comes from
	existing: BasePart?,
}

-- The direction a part's longest side runs (pointing up), and that length.
local function longSide(part: BasePart): (Vector3, number)
	local size = part.Size
	local length = math.max(size.X, size.Y, size.Z)
	local direction = if size.X == length
		then part.CFrame.RightVector
		elseif size.Y == length then part.CFrame.UpVector
		else part.CFrame.LookVector
	if direction.Y < 0 then
		direction = -direction
	end
	return direction, length
end

local function stopped(reason: string): never
	error(`nothing was changed. {reason}`)
end

-- Is the part as the plan says? (Size, place, lean, collision and look; the look is the centre truss's.)
local function matches(part: BasePart, plan: Plan): boolean
	local centre = plan.centre
	return part.ClassName == plan.className
		and (part.Size - plan.size).Magnitude <= SAME_SIZE
		and (part.Position - plan.cframe.Position).Magnitude <= SAME_PLACE
		and (part.CFrame.LookVector - plan.cframe.LookVector).Magnitude <= SAME_LEAN
		and (part.CFrame.UpVector - plan.cframe.UpVector).Magnitude <= SAME_LEAN
		and part.Anchored == centre.Anchored
		and part.CanCollide == true
		and part.CanQuery == centre.CanQuery
		and part.CanTouch == centre.CanTouch
		and part.Transparency == 1
		and part.CastShadow == false
		and part.Material == centre.Material
		and part.Color == centre.Color
		and part.CollisionGroup == centre.CollisionGroup
end

local function applyLook(part: BasePart, plan: Plan)
	local centre = plan.centre
	part.Size = plan.size
	part.CFrame = plan.cframe
	part.Anchored = centre.Anchored
	part.CanCollide = true
	part.CanQuery = centre.CanQuery
	part.CanTouch = centre.CanTouch
	part.Transparency = 1
	part.CastShadow = false
	part.Material = centre.Material
	part.Color = centre.Color
	part.CollisionGroup = centre.CollisionGroup
end

-- Reads the world and returns one plan per part to have. Changes nothing; errors with the reason when anything is
-- unexpected.
local function planAll(): { Plan }
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	if walk == nil then
		stopped("Workspace.World.WalkSurfaces is missing")
	end

	local groups: { [Instance]: { BasePart } } = {}
	local order: { Instance } = {}
	for _, instance in (walk :: Instance):GetDescendants() do
		if instance:IsA("TrussPart") and instance.CanCollide then
			local model = instance.Parent :: Instance
			if groups[model] == nil then
				groups[model] = {}
				table.insert(order, model)
			end
			table.insert(groups[model], instance)
		end
	end
	if #order == 0 then
		stopped("no solid TrussPart stands under Workspace.World.WalkSurfaces")
	end

	local plans: { Plan } = {}
	for _, model in order do
		local hasRails = false
		local walls: { BasePart } = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Name == RAIL then
				hasRails = true
			end
		end
		if not hasRails then
			for _, truss in groups[model] do
				stopped(`{truss:GetFullName()} is a solid truss with no Rail parts beside it`)
			end
		end
		local centres: { BasePart } = {}
		local sideTrusses: { BasePart } = {}
		for _, truss in groups[model] do
			if truss.Name == SIDE_TRUSS then
				table.insert(sideTrusses, truss)
			else
				table.insert(centres, truss)
			end
		end
		if #centres ~= 1 then
			stopped(`{model:GetFullName()} has {#centres} centre trusses, expected 1`)
		end
		local centre = centres[1]
		local up, length = longSide(centre)
		local across = WORLD_UP:Cross(up).Unit
		-- "back" is toward his body: along the flat direction and tilted down, square to the ladder. The climber is on the
		-- other side of the ladder.
		local flatPart = Vector3.new(up.X, 0, up.Z)
		if flatPart.Magnitude < 0.01 then
			stopped(`{model:GetFullName()}'s centre truss stands straight up, which this script doesn't handle`)
		end
		local back = (flatPart.Unit * up.Y - WORLD_UP * flatPart.Magnitude).Unit
		local toClimber = -back
		-- Side trusses: any part of that name that is not a solid TrussPart is also a surprise.
		for _, child in model:GetChildren() do
			if child.Name == SIDE_TRUSS and not (child:IsA("TrussPart") and child.CanCollide) then
				stopped(`{child:GetFullName()} is called {SIDE_TRUSS} but is a {child.ClassName}`)
			end
			if child.Name == SIDE_WALL then
				if not (child:IsA("Part") and child.ClassName == "Part") then
					stopped(`{child:GetFullName()} is called {SIDE_WALL} but is a {child.ClassName}`)
				end
				table.insert(walls, child :: BasePart)
			end
		end

		local function existingOn(candidates: { BasePart }, side: number, label: string): BasePart?
			local found: BasePart? = nil
			for _, candidate in candidates do
				local offset = (candidate.Position - centre.Position):Dot(across)
				if math.abs(offset) < 0.5 then
					stopped(`{candidate:GetFullName()} ({label}) is {offset} studs from the middle, not on a side`)
				end
				if (if offset > 0 then 1 else -1) == side then
					if found ~= nil then
						stopped(
							`{model:GetFullName()} has two {label} parts on its {if side > 0 then "right" else "left"} side`
						)
					end
					found = candidate
				end
			end
			return found
		end

		for _, side in { -1, 1 } do
			table.insert(plans, {
				ladder = model,
				name = SIDE_TRUSS,
				className = "TrussPart",
				side = side,
				size = centre.Size,
				cframe = centre.CFrame + across * (side * TRUSS_STEP),
				centre = centre,
				existing = existingOn(sideTrusses, side, SIDE_TRUSS),
			})
			local wallMiddle = centre.Position
				+ across * (side * (WALL_INNER_FACE + WALL_THICKNESS / 2))
				+ toClimber * (WALL_DEPTH / 2)
			table.insert(plans, {
				ladder = model,
				name = SIDE_WALL,
				className = "Part",
				side = side,
				size = Vector3.new(WALL_THICKNESS, WALL_DEPTH, length),
				cframe = CFrame.fromMatrix(wallMiddle, across, toClimber),
				centre = centre,
				existing = existingOn(walls, side, SIDE_WALL),
			})
		end
	end
	return plans
end

local function run(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local plans = planAll()

	local toAdd: { Plan } = {}
	local toUpdate: { Plan } = {}
	for _, plan in plans do
		if plan.existing == nil then
			table.insert(toAdd, plan)
		elseif not matches(plan.existing, plan) then
			table.insert(toUpdate, plan)
		end
	end
	if #toAdd == 0 and #toUpdate == 0 then
		return `already done: {#plans} parts in {#plans / 4} ladders are as the table says`
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("17-ladder-width: before")
	end)
	for _, plan in toAdd do
		local part: BasePart = if plan.className == "TrussPart" then Instance.new("TrussPart") else Instance.new("Part")
		part.Name = plan.name
		applyLook(part, plan)
		part.Parent = plan.ladder
		plan.existing = part
	end
	for _, plan in toUpdate do
		applyLook(plan.existing :: BasePart, plan)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("17-ladder-width: after")
	end)

	local wrong = 0
	for _, plan in plans do
		if plan.existing == nil or not matches(plan.existing, plan) then
			wrong += 1
		end
	end
	if wrong > 0 then
		error(
			`{wrong} parts stand wrong after the change. Undo it in Studio (Ctrl+Z, back to the waypoint "17-ladder-width: before") and tell code_lead`
		)
	end
	local ladderNames: { string } = {}
	local seen: { [Instance]: boolean } = {}
	for _, plan in plans do
		if not seen[plan.ladder] then
			seen[plan.ladder] = true
			table.insert(ladderNames, plan.ladder:GetFullName())
		end
	end
	return `added {#toAdd} parts, updated {#toUpdate} parts, in {#ladderNames} ladders: {table.concat(ladderNames, ", ")}`
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
