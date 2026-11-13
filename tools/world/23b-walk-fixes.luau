--!strict
-- World prep, plan 5 (egg nests and climbing) Task 15d: the two invisible thigh guards (spec 7 Rule 82 "No new way onto
-- the belly"; card work/p5t15d/15d-card.md Step 5; details work/p5t15d/15d-scripts.md section D, test B6 in
-- src/tests/server/World/RealWorld/ThighGuards.spec.luau).
-- What it does: makes the folder Workspace.World.ThighGuards with ThighGuard_Left and ThighGuard_Right. Each is a plain
-- Part 11.2 x 22.5 x 0.4 studs, centre (+-27.9, 31.25, -55) (Left is his left: stud x below 0), so it spans x 22.3 to
-- 33.5 on its side, y 20 to 42.5, across the thigh edge of a boot top. Transparency 1, CanCollide true, CanQuery true,
-- CanTouch false, Anchored true. The material is the material of WalkSurfaces.RailGuard_Left. The numbers are the
-- stand-in's (work/p5t15d/guard-walks.luau lines 107-113), proven in Task 15d Steps 2 and 3.
-- Before any change it makes ServerStorage.WorldBackups.Plan5Task15d (if missing) holding a copy of World.ThighGuards if
-- it is there, or else an empty marker folder named ThighGuards_absent, in the same call.
-- Stops (no change) unless it will add exactly 2 parts. Both guards there already = "already done", nothing changed.
-- Rollback: delete World.ThighGuards (or clone the backup back).
-- Run: `return require(game:GetService("ServerStorage").Tools.world["23b-walk-fixes"]:Clone())()` through execute_luau in
-- Studio EDIT mode. The report is also in shared.Walk23bReport (list of lines).

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "Plan5Task15d"
local FOLDER_NAME = "ThighGuards"
local SIZE = Vector3.new(11.2, 22.5, 0.4) -- studs: 11.2 across x, 22.5 tall, 0.4 thick
local CENTRE_X = 27.9 -- studs from the middle line
local CENTRE_Y = 31.25
local CENTRE_Z = -55
local PLANNED = 2

local SIDES: { { label: string, sign: number } } = {
	{ label = "Left", sign = -1 },
	{ label = "Right", sign = 1 },
}

local function run23b(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local report: { string } = {}
	-- selene: allow(global_usage)
	shared.Walk23bReport = report
	local world = Workspace:FindFirstChild("World")
	local surfaces = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	local rail = if surfaces ~= nil then surfaces:FindFirstChild("RailGuard_Left") else nil
	if world == nil or rail == nil or not rail:IsA("BasePart") then
		error("nothing was changed. Workspace.World or WalkSurfaces.RailGuard_Left is missing")
	end
	local material = (rail :: BasePart).Material
	local existing = world:FindFirstChild(FOLDER_NAME)
	local missing: { { label: string, sign: number } } = {}
	for _, side in SIDES do
		local there = if existing ~= nil then existing:FindFirstChild(`ThighGuard_{side.label}`) else nil
		if there == nil then
			table.insert(missing, side)
		end
	end
	if #missing == 0 then
		table.insert(report, "already done")
		return "already done"
	end
	if #missing ~= PLANNED then
		error(`nothing was changed. it would add {#missing} parts, the plan is {PLANNED}`)
	end
	table.insert(report, `will add {#missing} parts to World.{FOLDER_NAME}`)

	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	local backup = backups:FindFirstChild(BACKUP_NAME)
	if backup == nil then
		backup = Instance.new("Folder")
		backup.Name = BACKUP_NAME
		backup.Parent = backups
		if existing ~= nil then
			existing:Clone().Parent = backup
		else
			local marker = Instance.new("Folder")
			marker.Name = `{FOLDER_NAME}_absent`
			marker.Parent = backup
		end
	end

	ChangeHistoryService:SetWaypoint("23b-walk-fixes: before")
	local folder = existing
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = world
	end
	for _, side in missing do
		local part = Instance.new("Part")
		part.Name = `ThighGuard_{side.label}`
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Material = material
		part.Size = SIZE
		part.CFrame = CFrame.new(side.sign * CENTRE_X, CENTRE_Y, CENTRE_Z)
		part.Parent = folder
		table.insert(report, `made {part.Name} at {part.Position} size {part.Size}`)
	end
	ChangeHistoryService:SetWaypoint("23b-walk-fixes: after")
	return string.sub(`made {#missing} parts in World.{FOLDER_NAME}: {table.concat(report, "; ")}`, 1, 1000)
end

return run23b
