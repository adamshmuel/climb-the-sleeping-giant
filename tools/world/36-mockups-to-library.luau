--!strict
-- World prep, plan 3 (gardens and ways up) Task 6c: the ways-up mockups leave the Workspace for ServerStorage.ArtLibrary
-- (docs/plans/v2/gardens-and-ways-up.md, plan 3 line 60; card work/t6c/card.md; numbers: work/t6c/6c-scripts.md B and S).
-- What it does: moves Workspace.Mockup_WaysUp to ServerStorage.ArtLibrary.Mockup_WaysUp, and
-- Workspace.Mockup_Nests.LapBuild_Designer and .RampBuild_CodeLead to ServerStorage.ArtLibrary.Mockup_Nests (a Folder made
-- if missing). Values inside are not touched (the Mockup* attributes stay; RampBuild_CodeLead keeps LeftStations).
-- Step 2 (plan 5 Task 16b, card work/p5t16b/16b-card.md): the rest of Workspace.Mockup_Nests (Art and the other folders) moves
-- into ServerStorage.ArtLibrary.Mockup_Nests and the empty Workspace folder is removed. Before any change the whole old
-- folder is cloned into ServerStorage.WorldBackups.p5t16b (attribute BackupOf). No Mockup_Nests in the Workspace = "already
-- done". The names in the Workspace folder must not already be in ArtLibrary.Mockup_Nests (else STOP, nothing changed).
-- Rollback of step 2: parent the children back into a new Workspace Folder named Mockup_Nests, or clone the backup back.
-- Before any change it clones the three into ServerStorage.WorldBackups.t6c (attribute BackupOf = the old full path).
-- Worlds, checked before any change: all three in ArtLibrary and none in the Workspace = "already done"; all three in the
-- Workspace and none in ArtLibrary (with the descendant counts of B) = move; anything else = STOP, nothing changed.
-- Every lookup is a direct child: ServerStorage.ArtLibrary.MockupAvatars also holds a folder named Mockup_WaysUp.
-- Rollback: parent the three back to their old spots (Workspace, and Workspace.Mockup_Nests) and delete
-- ServerStorage.WorldBackups.t6c.
-- CHECK_ONLY = true measures and prints only. Full report: shared.T6cReport (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["36-mockups-to-library"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "t6c"

-- Descendant counts from work/t6c/6c-scripts.md section B.
type Item = { name: string, fromNests: boolean, toNests: boolean, descendants: number }
local ITEMS: { Item } = {
	{ name = "Mockup_WaysUp", fromNests = false, toNests = false, descendants = 1083 },
	{ name = "LapBuild_Designer", fromNests = true, toNests = true, descendants = 362 },
	{ name = "RampBuild_CodeLead", fromNests = true, toNests = true, descendants = 39 },
}

local lines: { string } = {}

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.T6cReport = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function note(text: string)
	table.insert(lines, text)
end

-- How many direct children of parent (nil = none) are named name.
local function countNamed(parent: Instance?, name: string): number
	if parent == nil then
		return 0
	end
	local count = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			count += 1
		end
	end
	return count
end

local function getFolder(parent: Instance?, name: string): Instance?
	if parent == nil then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function run36(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end

	local library = ServerStorage:FindFirstChild("ArtLibrary")
	if library == nil or not library:IsA("Folder") then
		return "STOP: ServerStorage.ArtLibrary (a Folder) is missing, nothing changed"
	end
	local worldNests = Workspace:FindFirstChild("Mockup_Nests")
	local libNests = library:FindFirstChild("Mockup_Nests")
	if libNests ~= nil and not libNests:IsA("Folder") then
		return `STOP: ArtLibrary.Mockup_Nests is a {libNests.ClassName}, not a Folder, nothing changed`
	end
	if countNamed(library, "Mockup_Nests") > 1 or countNamed(Workspace, "Mockup_Nests") > 1 then
		return "STOP: more than one Mockup_Nests folder, nothing changed"
	end

	-- 1. Where is each of the three now (direct children only)?
	local inWorld = 0
	local inLibrary = 0
	local sources: { Instance } = {}
	for _, item in ITEMS do
		local fromParent: Instance? = if item.fromNests then worldNests else Workspace
		local toParent: Instance? = if item.toNests then libNests else library
		local nWorld = countNamed(fromParent, item.name)
		local nLib = countNamed(toParent, item.name)
		note(`{item.name}: {nWorld} in the Workspace, {nLib} in ArtLibrary`)
		if nWorld > 1 or nLib > 1 then
			return `STOP: {item.name} is there more than once ({nWorld} in the Workspace, {nLib} in ArtLibrary), nothing changed`
		end
		inWorld += nWorld
		inLibrary += nLib
	end
	if inWorld == 0 and inLibrary == #ITEMS then
		for _, item in ITEMS do
			local toParent = if item.toNests then libNests else library
			local moved = getFolder(toParent, item.name)
			if moved ~= nil then
				note(`{item.name}: {#moved:GetDescendants()} descendants in ArtLibrary`)
			end
		end
		return "already done: all three mockups are in ArtLibrary and none is in the Workspace, nothing changed"
	end
	if not (inWorld == #ITEMS and inLibrary == 0) then
		return `STOP: {inWorld} of 3 in the Workspace and {inLibrary} of 3 in ArtLibrary (expected 3 and 0, or 0 and 3), nothing changed`
	end

	-- 2. Counts before the move must be the counts of B.
	local before: { number } = {}
	for index, item in ITEMS do
		local fromParent = if item.fromNests then worldNests else Workspace
		local source = getFolder(fromParent, item.name)
		if source == nil or not source:IsA("Folder") then
			return `STOP: {item.name} is not a Folder, nothing changed`
		end
		local count = #source:GetDescendants()
		before[index] = count
		sources[index] = source
		note(`{item.name}: {count} descendants before (B says {item.descendants})`)
		if count ~= item.descendants then
			return `STOP: {item.name} has {count} descendants, B says {item.descendants}, nothing changed`
		end
	end
	local rampSource = sources[3]
	if typeof(rampSource:GetAttribute("LeftStations")) ~= "string" then
		return "STOP: RampBuild_CodeLead has no string LeftStations attribute, nothing changed"
	end

	local head =
		`would move Mockup_WaysUp ({before[1]}), LapBuild_Designer ({before[2]}), RampBuild_CodeLead ({before[3]}) to ArtLibrary`
	if CHECK_ONLY then
		return `CHECK_ONLY: {head}; changed nothing`
	end

	-- 3. Backup, then move.
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		local folder = Instance.new("Folder")
		folder.Name = "WorldBackups"
		folder.Parent = ServerStorage
		backups = folder
	end
	local backupFolder = backups:FindFirstChild(BACKUP_NAME)
	if backupFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		folder.Parent = backups
		backupFolder = folder
	end
	for _, source in sources do
		local path = source:GetFullName()
		local have = false
		for _, kept in backupFolder:GetChildren() do
			if kept:GetAttribute("BackupOf") == path and kept.Name == source.Name then
				have = true
			end
		end
		if not have then
			local copy = source:Clone()
			copy:SetAttribute("BackupOf", path)
			copy.Parent = backupFolder
		end
	end

	if libNests == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Mockup_Nests"
		folder.Parent = library
		libNests = folder
	end

	local okBegin, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording("t6c mockups")
	end)
	if not okBegin or recording == nil then
		ChangeHistoryService:SetWaypoint("36-mockups-to-library: before")
		note("no recording available: used a waypoint")
	end

	local oldParents: { Instance } = {}
	local movedCount = 0
	local failure: string? = nil
	for index, item in ITEMS do
		local source = sources[index]
		oldParents[index] = source.Parent :: Instance
		local target: Instance = if item.toNests then libNests :: Instance else library
		local ok, err = pcall(function()
			source.Parent = target
		end)
		if not ok then
			failure = `{item.name}: {err}`
			break
		end
		movedCount += 1
	end
	if failure ~= nil then
		for index = 1, movedCount do
			sources[index].Parent = oldParents[index]
		end
		if okBegin and recording ~= nil then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		end
		return `STOP: a move failed ({failure}), the moved ones were put back`
	end
	if okBegin and recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:SetWaypoint("36-mockups-to-library: after")
	end

	-- 4. Report: counts after must match counts before.
	local problems = 0
	for index, item in ITEMS do
		local toParent = if item.toNests then libNests else library
		local moved = getFolder(toParent, item.name)
		local after = if moved ~= nil then #moved:GetDescendants() else -1
		local fromParent = if item.fromNests then Workspace:FindFirstChild("Mockup_Nests") else Workspace
		local left = countNamed(fromParent, item.name)
		note(`{item.name}: {before[index]} before, {after} after, {left} left in the Workspace`)
		if after ~= before[index] or left ~= 0 then
			problems += 1
		end
	end
	local ramp = getFolder(libNests, "RampBuild_CodeLead")
	local keptLeft = ramp ~= nil and typeof(ramp:GetAttribute("LeftStations")) == "string"
	note(if keptLeft then "LeftStations kept" else "LeftStations LOST")
	if problems > 0 or not keptLeft then
		return `PROBLEM: {problems} count(s) differ or LeftStations lost; rollback: parent the three back, delete WorldBackups.{BACKUP_NAME}`
	end
	return `changed: moved 3 mockup folders to ArtLibrary, counts match, LeftStations kept; backup in ServerStorage.WorldBackups.{BACKUP_NAME}`
end

local NESTS_BACKUP_NAME = "p5t16b"

-- Step 2: moves what is left in Workspace.Mockup_Nests into ArtLibrary.Mockup_Nests (a Folder made by step 1).
local function runNests(): string
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	local worldNests = Workspace:FindFirstChild("Mockup_Nests")
	local libNests = if library ~= nil then library:FindFirstChild("Mockup_Nests") else nil
	if libNests == nil or not libNests:IsA("Folder") then
		return "STOP: ArtLibrary.Mockup_Nests (a Folder) is missing, nothing changed"
	end
	if worldNests == nil then
		return `already done: no Mockup_Nests in the Workspace; ArtLibrary.Mockup_Nests has {#libNests:GetChildren()} children`
	end
	if not worldNests:IsA("Folder") or countNamed(Workspace, "Mockup_Nests") > 1 then
		return "STOP: Workspace.Mockup_Nests is not one Folder, nothing changed"
	end
	local moving = worldNests:GetChildren()
	local total = #worldNests:GetDescendants()
	local libBefore = #libNests:GetDescendants()
	for _, item in moving do
		if libNests:FindFirstChild(item.Name) ~= nil then
			return `STOP: {item.Name} is already in ArtLibrary.Mockup_Nests, nothing changed`
		end
		note(`{item.Name}: {item.ClassName}, {#item:GetDescendants()} descendants`)
	end
	local head = `would move {#moving} children ({total} descendants) from Workspace.Mockup_Nests to ArtLibrary`
	if CHECK_ONLY then
		return `CHECK_ONLY: {head}; changed nothing`
	end

	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		local folder = Instance.new("Folder")
		folder.Name = "WorldBackups"
		folder.Parent = ServerStorage
		backups = folder
	end
	local backupFolder = backups:FindFirstChild(NESTS_BACKUP_NAME)
	if backupFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = NESTS_BACKUP_NAME
		folder.Parent = backups
		backupFolder = folder
	end
	if backupFolder:FindFirstChild("Mockup_Nests") == nil then
		local copy = worldNests:Clone()
		copy:SetAttribute("BackupOf", worldNests:GetFullName())
		copy.Parent = backupFolder
	end

	ChangeHistoryService:SetWaypoint("36-mockups-to-library: nests before")
	local oldParents: { Instance } = {}
	local movedCount = 0
	local failure: string? = nil
	for index, item in moving do
		oldParents[index] = item.Parent :: Instance
		local ok, err = pcall(function()
			item.Parent = libNests
		end)
		if not ok then
			failure = `{item.Name}: {err}`
			break
		end
		movedCount += 1
	end
	if failure ~= nil then
		for index = 1, movedCount do
			moving[index].Parent = oldParents[index]
		end
		return `STOP: a move failed ({failure}), the moved ones were put back`
	end
	for name, value in worldNests:GetAttributes() do
		if libNests:GetAttribute(name) == nil then
			libNests:SetAttribute(name, value)
		end
	end
	local left = #worldNests:GetChildren()
	if left == 0 then
		worldNests:Destroy()
	end
	ChangeHistoryService:SetWaypoint("36-mockups-to-library: nests after")

	local gained = #libNests:GetDescendants() - libBefore
	local inWorld = countNamed(Workspace, "Mockup_Nests")
	note(
		`{total} before, {gained} gained in ArtLibrary.Mockup_Nests, {left} children left, {inWorld} Mockup_Nests in the Workspace`
	)
	if gained ~= total or left ~= 0 or inWorld ~= 0 then
		return `PROBLEM: counts differ; rollback: clone WorldBackups.{NESTS_BACKUP_NAME}.Mockup_Nests back into the Workspace`
	end
	return `changed: moved {#moving} children ({total} descendants) to ArtLibrary.Mockup_Nests; backup in ServerStorage.WorldBackups.{NESTS_BACKUP_NAME}`
end

local ok, message = pcall(run36)
if not ok then
	return finish(`STOPPED WITH AN ERROR: {tostring(message)}`)
end
local isStop = string.sub(message, 1, 4) == "STOP" or string.sub(message, 1, 7) == "PROBLEM"
if isStop or string.sub(message, 1, 10) == "CHECK_ONLY" then
	return finish(message)
end
local okNests, nestsMessage = pcall(runNests)
if not okNests then
	return finish(`STOPPED WITH AN ERROR in step 2: {tostring(nestsMessage)}`)
end
return finish(`step 2: {nestsMessage} | step 1: {message}`)
