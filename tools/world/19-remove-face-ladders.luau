--!strict
-- World prep, V2 stuck safety Task 60 (Adam, 2026-11-02): the ladders on the giant's face come off, so a new player's
-- first view shows his sleeping face (spec Rule 20, One collision source; Rule 24, A bot walks every way; Rule 101,
-- Ladders hold you; none of their ladder parts apply to his face any more).
-- What it does: moves the two models Workspace.World.WalkSurfaces.BeardLadder and .CapLadder (and everything inside
-- them: the fills, the foot ledge, the braces, the nose deck and DreamEggNest) into ServerStorage.WorldBackups.FaceLadders.
-- Nothing is destroyed: moving them back is the undo. Rojo leaves ServerStorage.WorldBackups alone.
-- ForeheadGuard stays (the forehead patches use it as their roof). The egg spots and RoutePoint_Belly_4 are put back in
-- Task 62, after the ear ladders are built.
-- Check mode is the default (Lesson 166): with no attribute `Apply` set to true on the clone, it only checks and says
-- "CHECK ONLY: passed, would move <n> parts". Set `Apply` to true on the clone to make the change.
-- Three worlds, all decided before any change:
--   1. both ladders are in WalkSurfaces and neither is in the backup: they are moved;
--   2. both ladders are in the backup and neither is in WalkSurfaces: "already done", nothing changes;
--   3. anything else (a ladder in both places, in neither, or only one moved): it stops with nothing changed, and says why.
-- Run in Studio EDIT mode by requiring a clone of ServerStorage.Tools.world["19-remove-face-ladders"] (Lesson 190).
-- The place file must be saved by Adam afterwards. Run twice, it changes nothing the second time.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local LADDER_NAMES = { "BeardLadder", "CapLadder" }
local BACKUPS_NAME = "WorldBackups"
local FOLDER_NAME = "FaceLadders"
local BACKUP_PATH = `ServerStorage.{BACKUPS_NAME}.{FOLDER_NAME}`

-- true: run every lookup and guard, then stop before any change (Lesson 166). The default. A clone with the attribute
-- `Apply` set to true switches it off for that run.
local CHECK_ONLY = true

local function stopped(reason: string): never
	error(`STOPPED, nothing changed: {reason}`, 0)
end

local function countParts(model: Instance): number
	local total = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

local function run(): string
	if RunService:IsRunning() then
		stopped("Play is on, this job runs in Edit")
	end
	local apply = script:GetAttribute("Apply") == true or not CHECK_ONLY

	local world = Workspace:FindFirstChild("World")
	local walkSurfaces = if world then world:FindFirstChild("WalkSurfaces") else nil
	if walkSurfaces == nil then
		stopped("Workspace.World.WalkSurfaces is missing (lost input)")
	end
	local backups = ServerStorage:FindFirstChild(BACKUPS_NAME)
	local backup = if backups then backups:FindFirstChild(FOLDER_NAME) else nil

	local inWalk: { Instance } = {}
	local inBackup: { Instance } = {}
	local report: { string } = {}
	for _, name in LADDER_NAMES do
		local here = (walkSurfaces :: Instance):FindFirstChild(name)
		local there = if backup then backup:FindFirstChild(name) else nil
		if here ~= nil and there ~= nil then
			stopped(`{name} is in WalkSurfaces and in {BACKUP_PATH}`)
		elseif here == nil and there == nil then
			stopped(`{name} is in neither WalkSurfaces nor {BACKUP_PATH}`)
		elseif here ~= nil then
			if not here:IsA("Model") then
				stopped(`{here:GetFullName()} is a {here.ClassName}, not a Model`)
			end
			table.insert(inWalk, here)
		else
			table.insert(inBackup, there :: Instance)
		end
	end
	if #inWalk > 0 and #inBackup > 0 then
		stopped("one ladder is moved and the other is not")
	end

	if #inBackup == #LADDER_NAMES then
		return `already done: {table.concat(LADDER_NAMES, " and ")} are in {BACKUP_PATH}`
	end

	local total = 0
	for _, ladder in inWalk do
		total += countParts(ladder)
	end
	if not apply then
		return `CHECK ONLY: passed, would move {total} parts ({table.concat(LADDER_NAMES, " and ")}) to {BACKUP_PATH}`
	end

	local recording = ChangeHistoryService:TryBeginRecording("Remove face ladders")
	local parent: Instance? = backups
	if parent == nil then
		local made = Instance.new("Folder")
		made.Name = BACKUPS_NAME
		made.Parent = ServerStorage
		parent = made
	end
	local folder: Instance? = backup
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = parent
		folder = made
	end
	for _, ladder in inWalk do
		table.insert(report, ladder.Name)
		ladder.Parent = folder
	end
	if recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return `moved {table.concat(report, " and ")} to {BACKUP_PATH} ({total} parts)`
end

local ok, message = pcall(run)
if not ok then
	return tostring(message)
end
return message
