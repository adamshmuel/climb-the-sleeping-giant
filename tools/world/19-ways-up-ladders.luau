--!strict
-- World prep, plan 3 (gardens and ways up) Task 4a: the two rope ladders on the boots
-- (docs/plans/v2/gardens-and-ways-up.md, "Task 4a"; spec Rule 37 (Rope ladders on the boots) and Rule 15 (The climb needs
-- no jump)). Handoff and rulings: work/t4a/handoff.md.
-- Why: the mockup ladders (Workspace.Mockup_WaysUp.BootLadder_Left and _Right) are only a picture. Players need a real
-- climb from the meadow grass to the boot top, with no jump at the top.
-- What it does, for each side: makes Workspace.World.WalkSurfaces.BootLadder_<side> holding
--   * Climb: an invisible TrussPart 2 x 2 x n (n a multiple of 2) on the mockup's slope, top end at (side x 32.4, 30.4, -64);
--   * TopPad: an invisible flat pad 3.5 x 1 x 5, top face at y 30.4, so the top end is level with the boot top;
--   * Look: the mockup's rungs, rails, hooks and pegs, kept where designer put them (the TrailGlow is not copied).
-- Before any change it makes ServerStorage.WorldBackups.T4a and clones both mockup models into it. Rollback: delete
-- WalkSurfaces.BootLadder_Left and _Right (nothing that existed before is changed).
-- Worlds, checked before any change: both ladders there = "already done"; none there = build; one there = stop.
-- The message starts with how much changed. Run in Studio EDIT mode: read this file and pass its text as
-- `code` to execute_luau. The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TOP_HEIGHT = 30.4 -- the outer toe nest height (spec 5's table)
local TOP_X = 32.4 -- the truss top end, x (the sign is the side)
local FOOT_X = 49 -- where the centre line must cross y 2
local FOOT_Z = -64
local FOOT_REACH = 0.5 -- studs: how far the foot may be from (side 49, -64)
local GRASS_Y = 2
local PAD_SIZE = Vector3.new(3.5, 1, 5)
local PAD_CENTRE_X = 30.75 -- pad runs x 29 to 32.5
local PAD_INNER_X = 29
local BOOT_DROP_MAX = 0.3 -- the boot at the pad's inner edge may be at most this far below the pad top
local BACKUP_NAME = "T4a"
local SIDES = { { name = "BootLadder_Left", sign = -1 }, { name = "BootLadder_Right", sign = 1 } }

local function numberAttr(part: Instance, name: string): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function run4a(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local surfaces = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	local giant = if world ~= nil then world:FindFirstChild("Giant") else nil
	local mockups = Workspace:FindFirstChild("Mockup_WaysUp")
	if surfaces == nil or giant == nil or mockups == nil then
		error(
			"nothing was changed. Workspace.World.WalkSurfaces, Workspace.World.Giant or Workspace.Mockup_WaysUp is missing"
		)
	end
	local beard = surfaces:FindFirstChild("BeardLadder")
	local beardClimb = if beard ~= nil then beard:FindFirstChild("Climb") else nil
	if beardClimb == nil or not beardClimb:IsA("TrussPart") then
		error("nothing was changed. WalkSurfaces.BeardLadder.Climb (the truss source) is missing")
	end

	local existing = 0
	for _, side in SIDES do
		if surfaces:FindFirstChild(side.name) ~= nil then
			existing += 1
		end
	end
	if existing == #SIDES then
		return "already done: both boot ladders are in WalkSurfaces"
	elseif existing ~= 0 then
		error("nothing was changed. only one boot ladder is in WalkSurfaces, expected 0 or 2")
	end

	-- Checks before any change.
	local giantOnly = RaycastParams.new()
	giantOnly.FilterType = Enum.RaycastFilterType.Include
	giantOnly.FilterDescendantsInstances = { giant }
	local plans = {}
	for _, side in SIDES do
		local mockup = mockups:FindFirstChild(side.name)
		local mockClimb = if mockup ~= nil then mockup:FindFirstChild("Climb") else nil
		if mockup == nil or mockClimb == nil or not mockClimb:IsA("BasePart") then
			error(`nothing was changed. Workspace.Mockup_WaysUp.{side.name} or its Climb is missing`)
		end
		local hit =
			Workspace:Raycast(Vector3.new(side.sign * PAD_INNER_X, 60, FOOT_Z), Vector3.new(0, -80, 0), giantOnly)
		if hit == nil or hit.Position.Y < TOP_HEIGHT - BOOT_DROP_MAX then
			error(
				`nothing was changed. the boot at the {side.name} pad's inner edge is not within {BOOT_DROP_MAX} of y {TOP_HEIGHT}`
			)
		end
		-- The mockup's slope, pointing up (long axis of its Climb is Z).
		local slope = mockClimb.CFrame.LookVector
		if slope.Y < 0 then
			slope = -slope
		end
		slope = Vector3.new(slope.X, slope.Y, 0).Unit
		local top = Vector3.new(side.sign * TOP_X, TOP_HEIGHT, FOOT_Z)
		local toGrass = (TOP_HEIGHT - GRASS_Y) / slope.Y -- distance from the top end to y 2 along the slope
		local length = math.ceil(toGrass / 2) * 2
		local foot = top - slope * toGrass
		if math.abs(foot.X - side.sign * FOOT_X) > FOOT_REACH or math.abs(foot.Z - FOOT_Z) > FOOT_REACH then
			error(
				`nothing was changed. the {side.name} foot would be at x {foot.X}, z {foot.Z}, more than {FOOT_REACH} from ({side.sign * FOOT_X}, {FOOT_Z})`
			)
		end
		table.insert(plans, { side = side, mockup = mockup, slope = slope, top = top, length = length, foot = foot })
	end

	-- Backup first, in the same run as the change.
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	if backups:FindFirstChild(BACKUP_NAME) == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		for _, plan in plans do
			plan.mockup:Clone().Parent = folder
		end
		folder.Parent = backups
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("19-ways-up-ladders: before")
	end)
	local made: { string } = {}
	for _, plan in plans do
		local ladder = Instance.new("Model")
		ladder.Name = plan.side.name

		local climb = Instance.new("TrussPart")
		climb.Name = "Climb"
		climb.Size = Vector3.new(2, 2, plan.length)
		climb.CFrame = CFrame.lookAt(
			plan.top - plan.slope * (plan.length / 2),
			plan.top - plan.slope * (plan.length / 2) + plan.slope
		)
		climb.Anchored = true
		climb.Style = (beardClimb :: TrussPart).Style
		climb.Transparency = (beardClimb :: TrussPart).Transparency
		climb.CanCollide = (beardClimb :: TrussPart).CanCollide
		climb.CanQuery = (beardClimb :: TrussPart).CanQuery
		climb.CanTouch = (beardClimb :: TrussPart).CanTouch
		climb.Parent = ladder

		local pad = Instance.new("Part")
		pad.Name = "TopPad"
		pad.Size = PAD_SIZE
		pad.Position = Vector3.new(plan.side.sign * PAD_CENTRE_X, TOP_HEIGHT - PAD_SIZE.Y / 2, FOOT_Z)
		pad.Anchored = true
		pad.Transparency = 1
		pad.CanCollide = true
		pad.CanQuery = true
		pad.CanTouch = true
		pad.Parent = ladder

		local look = Instance.new("Model")
		look.Name = "Look"
		for _, child in plan.mockup:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "Climb" then
				local part = child:Clone() :: BasePart
				part.Transparency = numberAttr(child, "MockupTransparency")
				part.CanCollide = false
				part.CanQuery = true
				part.CanTouch = true
				for name in part:GetAttributes() do
					if string.sub(name, 1, 6) == "Mockup" then
						part:SetAttribute(name, nil)
					end
				end
				if part.Name == "Rung" or part.Name == "Rail" then
					local reference = (beard :: Instance):FindFirstChild(part.Name) :: BasePart
					part.Material = reference.Material
					part.BrickColor = reference.BrickColor
				end
				part.Parent = look
			end
		end
		look.Parent = ladder
		ladder.Parent = surfaces
		table.insert(made, string.format("%s (truss %d long, foot x %.2f)", plan.side.name, plan.length, plan.foot.X))
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("19-ways-up-ladders: after")
	end)
	return "built 2 boot ladders: "
		.. table.concat(made, "; ")
		.. ". Backup: ServerStorage.WorldBackups."
		.. BACKUP_NAME
end

-- Task 4d (docs/plans/v2/gardens-and-ways-up.md, "Task 4d"; spec Rule 42 (Footprints take the quickest way): the glow
-- covers only the visible ladder). The beard and cap ladders get a Look model like the boot ladders: their Rail and Rung
-- parts move into a new Look model inside the same ladder. Nothing else changes and nothing moves. Before any change both
-- ladders are cloned into ServerStorage.WorldBackups.T4d (an existing T4d is left alone). Rollback: paste the T4d clones
-- back over the two ladders. Worlds: both have a Look = "already done"; none = change; one = stop.
local LADDERS_4D = { "BeardLadder", "CapLadder" }
local BACKUP_4D = "T4d"

local function run4d(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local surfaces = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	if surfaces == nil then
		error("nothing was changed. Workspace.World.WalkSurfaces is missing")
	end
	local ladders: { Instance } = {}
	local withLook = 0
	for _, name in LADDERS_4D do
		local ladder = surfaces:FindFirstChild(name)
		if ladder == nil or not ladder:IsA("Model") or ladder:FindFirstChild("Climb") == nil then
			error(`nothing was changed. WalkSurfaces.{name} or its Climb is missing`)
		end
		table.insert(ladders, ladder)
		if ladder:FindFirstChild("Look") ~= nil then
			withLook += 1
		end
	end
	if withLook == #LADDERS_4D then
		return "already done: every ladder has a Look model"
	elseif withLook ~= 0 then
		error("nothing was changed. only one of the beard and cap ladders has a Look model, expected 0 or 2")
	end

	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	if backups:FindFirstChild(BACKUP_4D) == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_4D
		for _, ladder in ladders do
			ladder:Clone().Parent = folder
		end
		folder.Parent = backups
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("19-ways-up-ladders 4d: before")
	end)
	local moved = 0
	for _, ladder in ladders do
		local look = Instance.new("Model")
		look.Name = "Look"
		for _, child in ladder:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Rail" or child.Name == "Rung") then
				child.Parent = look
				moved += 1
			end
		end
		look.Parent = ladder
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("19-ways-up-ladders 4d: after")
	end)
	return `4d: gave {#ladders} ladders a Look model ({moved} parts moved). Backup: ServerStorage.WorldBackups.{BACKUP_4D}`
end

local function run(): string
	return run4a() .. " | " .. run4d()
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
