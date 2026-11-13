--!strict
-- World prep, plan 5 (egg nests and climbing) Task 13b: the fill under the right back cuff ledge
-- (card work/p5t13b/card.md, "Step 7 ruling"; product's ruling: fix it in the world; work/p5t13b/fill-done.md).
-- What it fills: a slot between his right arm and the underside of World.CuffWalk.BackLedge_Right (y 32.1), open only
-- outboard over a 20-stud drop. The stuck scan found a spot there at (55.2, 27.4, -5.0) with 4.7 studs of room.
-- What it does: makes one solid, invisible block, World.CuffFill_Right, from the arm's side (x 55.15) out to his arm's
-- outer edge (x 56.0), from 0.5 over his arm (y 27.95) up to the ledge's underside (y 32.1), z -6.2 to -4.6.
-- Why invisible: seen from gates 7 and 8 the block stands out of his forearm under the white cuff, so a coloured one
-- would look worse. Its color is his skin's, for Studio only.
-- Measured (2026-11-08): it touches no giant part (GetPartsInPart: none); his arm is 0.5 or more under its bottom;
-- its top is covered by BackLedge_Right / Foot_Right at every point (no new floor); the slot's spot is gone from the
-- stuck scan (114 spots, none unlisted). The left side needs nothing: 3.9 studs of room, under the scan's 4.3 body.
-- Worlds, checked before any change: World.CuffWalk missing = STOP; the block already there with this size and place =
-- "already done"; a block there that differs = it is backed up and rebuilt.
-- Before any change it clones the old block (if there is one) and World.CuffWalk into
-- ServerStorage.WorldBackups.Plan5Task13b_Fill, in the same call.
-- Rollback: delete World.CuffFill_Right.
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["22b-cuff-fill"]:Clone())` through execute_luau.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "Plan5Task13b_Fill"
local PART_NAME = "CuffFill_Right"
local SIZE = Vector3.new(0.85, 4.15, 1.6)
local CENTER = CFrame.new(55.575, 30.025, -5.4) -- x 55.15 to 56.0, y 27.95 to 32.1, z -6.2 to -4.6
local SKIN = Color3.fromHex("e8b98f")

local function getBackupFolder(): Instance
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		local folder = Instance.new("Folder")
		folder.Name = "WorldBackups"
		folder.Parent = ServerStorage
		backups = folder
	end
	local backupFolder = (backups :: Instance):FindFirstChild(BACKUP_NAME)
	if backupFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		folder.Parent = backups
		backupFolder = folder
	end
	return backupFolder :: Instance
end

local function backUp(folder: Instance, original: Instance, copyName: string)
	if folder:FindFirstChild(copyName) == nil then
		local copy = original:Clone()
		copy.Name = copyName
		copy:SetAttribute("BackupOf", original:GetFullName())
		copy.Parent = folder
	end
end

local function run22b(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local cuffWalk = if world ~= nil then world:FindFirstChild("CuffWalk") else nil
	if world == nil or cuffWalk == nil then
		return "STOP: Workspace.World.CuffWalk is missing (run 22-cuff-walk first), nothing changed"
	end

	local existing = world:FindFirstChild(PART_NAME)
	if
		existing ~= nil
		and existing:IsA("BasePart")
		and (existing.Size - SIZE).Magnitude < 1e-3
		and existing.CFrame:FuzzyEq(CENTER, 0.01)
		and existing.Transparency == 1
		and existing.CanCollide
	then
		return "already done"
	end

	print("22b-cuff-fill: will add 1 part (plan: 1)")

	-- Backup in the same call.
	local backupFolder = getBackupFolder()
	backUp(backupFolder, cuffWalk, "CuffWalk_BeforeFill")
	if existing ~= nil then
		backUp(backupFolder, existing, `{PART_NAME}_Before22b`)
	end

	ChangeHistoryService:SetWaypoint("22b-cuff-fill: before")
	if existing ~= nil then
		existing:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = PART_NAME
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	part.Transparency = 1
	part.Material = Enum.Material.SmoothPlastic
	part.Color = SKIN
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = SIZE
	part.CFrame = CENTER
	part:SetAttribute("RidesRightArm", true)
	part.Parent = world
	ChangeHistoryService:SetWaypoint("22b-cuff-fill: after")
	return `added World.{PART_NAME} (size {SIZE}, at {CENTER.Position})`
end

return run22b()
