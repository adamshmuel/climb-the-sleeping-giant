--!strict
-- World prep, plan 7 (audio) Task 4: Roblox's character sounds (walking, climbing, jumping) on the newer audio objects
-- (docs/plans/v2/audio.md, Task 4 block; card work/p7/task4-card.md; spec 7 Rules 96 and 99).
-- What it does: sets SoundService.CharacterSoundsUseNewApi to Enabled (a saved place setting; only a plugin-level
-- script such as an Edit paste can write it). It reads the listener too: DefaultListenerLocation None = STOP, nothing changed.
-- Worlds, checked before any change: Enabled and the listener not None = "already done"; otherwise it sets Enabled.
-- No part moves. Before the change it makes ServerStorage.WorldBackups.p7t4 (a Folder) with the attribute
-- OldCharacterSoundsUseNewApi = the old value's name. An existing p7t4 folder while the setting is not Enabled = STOP.
-- The write is in a pcall and is read back. A ChangeHistoryService recording is the undo point.
-- Rollback: set SoundService.CharacterSoundsUseNewApi to Enum.RolloutState[<the folder's attribute>] and delete
-- ServerStorage.WorldBackups.p7t4.
-- CHECK_ONLY = true prints the two values and what it would do, and changes nothing. Full report: shared.P7t4Report.
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["26-sound-setup"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "p7t4"

local lines: { string } = {}

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P7t4Report = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function note(text: string)
	table.insert(lines, text)
end

local function run26(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end

	local oldValue = SoundService.CharacterSoundsUseNewApi
	local listener = SoundService.DefaultListenerLocation
	note(`CharacterSoundsUseNewApi = {oldValue.Name}`)
	note(`DefaultListenerLocation = {listener.Name}`)

	if listener == Enum.ListenerLocation.None then
		return "STOP: DefaultListenerLocation is None, so nothing would be heard; nothing changed"
	end
	if oldValue == Enum.RolloutState.Enabled then
		return "already done: CharacterSoundsUseNewApi is already Enabled, nothing changed"
	end

	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups ~= nil and backups:FindFirstChild(BACKUP_NAME) ~= nil then
		return `STOP: WorldBackups.{BACKUP_NAME} already exists while the setting is {oldValue.Name}; nothing changed`
	end

	if CHECK_ONLY then
		note(`would make ServerStorage.WorldBackups.{BACKUP_NAME} with OldCharacterSoundsUseNewApi = {oldValue.Name}`)
		return `CHECK_ONLY: would set Enabled (now {oldValue.Name}), listener {listener.Name} is fine; changed nothing`
	end

	-- Backup, then the write.
	if backups == nil then
		local folder = Instance.new("Folder")
		folder.Name = "WorldBackups"
		folder.Parent = ServerStorage
		backups = folder
	end
	local backupFolder = Instance.new("Folder")
	backupFolder.Name = BACKUP_NAME
	backupFolder:SetAttribute("OldCharacterSoundsUseNewApi", oldValue.Name)
	backupFolder.Parent = backups

	local okBegin, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording("p7t4 character sounds")
	end)
	if not okBegin or recording == nil then
		ChangeHistoryService:SetWaypoint("26-sound-setup: before")
		note("no recording available: used a waypoint")
	end

	local okWrite, err = pcall(function()
		SoundService.CharacterSoundsUseNewApi = Enum.RolloutState.Enabled
	end)
	if not okWrite then
		if okBegin and recording ~= nil then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		end
		backupFolder:Destroy()
		return `STOP: the write failed, nothing changed. pcall error: {tostring(err)}`
	end
	if okBegin and recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:SetWaypoint("26-sound-setup: after")
	end

	-- Read it back.
	local newValue = SoundService.CharacterSoundsUseNewApi
	note(`backup: ServerStorage.WorldBackups.{BACKUP_NAME}, OldCharacterSoundsUseNewApi = {oldValue.Name}`)
	note(`read back: CharacterSoundsUseNewApi = {newValue.Name}`)
	if newValue ~= Enum.RolloutState.Enabled then
		return `PROBLEM: the write did not stick (read back {newValue.Name}); rollback: delete WorldBackups.{BACKUP_NAME}`
	end
	return `changed: CharacterSoundsUseNewApi {oldValue.Name} -> {newValue.Name}; backup in ServerStorage.WorldBackups.{BACKUP_NAME}`
end

local ok, message = pcall(run26)
if not ok then
	return finish(`STOPPED WITH AN ERROR: {tostring(message)}`)
end
return finish(message)
