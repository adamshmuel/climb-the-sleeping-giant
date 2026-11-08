--!strict
-- World prep, plan 5 (egg nests and climbing) Task 13: the solid cuff straps and ledges
-- (docs/plans/v2/egg-nests-and-climbing.md Task 13; spec 5 "Cuff strap and ledge (Epic)"; card work/p5t13/card.md;
-- numbers: work/p5t13/p5t13-scripts.md sections W and S).
-- What it does: for each cuff (Left and Right) it clones the five invisible walk pieces from the art in
-- Workspace.Mockup_Nests.Art into a new folder World.CuffWalk, with the same place and size:
--   Straps.CuffStrap_<side>.StrapWalk                      -> Strap_<side>
--   Pockets.CuffPocketFront_<side>.LedgeWalk               -> FrontLedge_<side>
--   Pockets.CuffPocketFront_<side>.LedgeWalk_FrontStrip    -> FrontStrip_<side>
--   Pockets.CuffPocketBack_<side>.LedgeWalk                -> BackLedge_<side>
--   Pockets.CuffPocketBack_<side>.LedgeWalk_Join           -> Join_<side>
-- Each copy is Anchored, CanCollide / CanQuery / CanTouch true, Transparency 1, has no Mockup* attribute, has
-- StitchedEdge = true, and the right side also RidesRightArm = true. The art is not touched.
-- Worlds, checked before any change: a piece missing = STOP; World.CuffWalk with 10 matching parts = "already done";
-- anything else half-made = STOP, nothing changed.
-- Before any change it clones World.Zones and the six cuff art models into ServerStorage.WorldBackups.Plan5Task13.
-- Rollback: delete World.CuffWalk.
-- CHECK_ONLY = true measures and prints only. Full report: shared.Plan5Task13CuffReport (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["22-cuff-walk"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "Plan5Task13"
local FOLDER_NAME = "CuffWalk"
local EXPECTED = 10 -- plan 5 Task 13: 5 pieces on each of 2 sides

local SIDES = { "Left", "Right" }

type Piece = { group: string, model: string, part: string, name: string }
-- The five pieces of one side (`{side}` is filled in below).
local PIECES: { Piece } = {
	{ group = "Straps", model = "CuffStrap_{side}", part = "StrapWalk", name = "Strap_{side}" },
	{ group = "Pockets", model = "CuffPocketFront_{side}", part = "LedgeWalk", name = "FrontLedge_{side}" },
	{ group = "Pockets", model = "CuffPocketFront_{side}", part = "LedgeWalk_FrontStrip", name = "FrontStrip_{side}" },
	{ group = "Pockets", model = "CuffPocketBack_{side}", part = "LedgeWalk", name = "BackLedge_{side}" },
	{ group = "Pockets", model = "CuffPocketBack_{side}", part = "LedgeWalk_Join", name = "Join_{side}" },
}

local lines: { string } = {}

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.Plan5Task13CuffReport = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function note(text: string)
	table.insert(lines, text)
end

local function fill(text: string, side: string): string
	return (string.gsub(text, "{side}", side))
end

local function child(parent: Instance?, name: string): Instance?
	if parent == nil then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function getBackupFolder(): Instance
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
	return backupFolder :: Instance
end

-- True when World.CuffWalk already holds all the finished pieces (same names, place and size as the art).
local function alreadyDone(folder: Instance, sources: { [string]: BasePart }): boolean
	local parts = folder:GetChildren()
	if #parts ~= EXPECTED then
		return false
	end
	for name, source in sources do
		local made = folder:FindFirstChild(name)
		if made == nil or not made:IsA("BasePart") then
			return false
		end
		if
			(made.Size - source.Size).Magnitude > 1e-3
			or (made.Position - source.Position).Magnitude > 1e-3
			or made:GetAttribute("StitchedEdge") ~= true
		then
			return false
		end
	end
	return true
end

local function run22(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end

	local world = Workspace:FindFirstChild("World")
	local art = child(child(Workspace, "Mockup_Nests"), "Art")
	if world == nil or art == nil then
		return "STOP: Workspace.World or Workspace.Mockup_Nests.Art is missing, nothing changed"
	end

	-- 1. Find the 10 pieces.
	local sources: { [string]: BasePart } = {}
	local order: { string } = {}
	local models: { Instance } = {}
	for _, side in SIDES do
		for _, piece in PIECES do
			local model = child(child(art, piece.group), fill(piece.model, side))
			local part = child(model, piece.part)
			local newName = fill(piece.name, side)
			if model == nil or part == nil or not part:IsA("BasePart") then
				return `STOP: {fill(piece.model, side)}.{piece.part} missing`
			end
			sources[newName] = part
			table.insert(order, newName)
			if not table.find(models, model) then
				table.insert(models, model)
			end
		end
	end

	-- 2. How many parts will be added?
	local count = #order
	note(`will add {count} parts to World.{FOLDER_NAME}`)
	if count ~= EXPECTED then
		return finish(`STOP: {count} pieces found, plan 5 Task 13 says {EXPECTED}, nothing changed`)
	end

	-- 3. CHECK_ONLY: print the names and stop.
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: {table.concat(order, ", ")}; changed nothing`)
	end

	-- 4. Already done?
	local existing = world:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		if alreadyDone(existing, sources) then
			return finish("already done")
		end
		return finish(`STOP: World.{FOLDER_NAME} exists but is not the 10 finished pieces, nothing changed`)
	end

	-- 5. Backup in the same call.
	local backupFolder = getBackupFolder()
	local zones = world:FindFirstChild("Zones")
	if zones ~= nil and backupFolder:FindFirstChild("Zones") == nil then
		local copy = zones:Clone()
		copy:SetAttribute("BackupOf", zones:GetFullName())
		copy.Parent = backupFolder
	end
	for _, model in models do
		local path = model:GetFullName()
		local have = false
		for _, kept in backupFolder:GetChildren() do
			if kept:GetAttribute("BackupOf") == path then
				have = true
			end
		end
		if not have then
			local copy = model:Clone()
			copy:SetAttribute("BackupOf", path)
			copy.Parent = backupFolder
		end
	end

	-- 6. Make the folder and the pieces.
	ChangeHistoryService:SetWaypoint("22-cuff-walk: before")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in order do
		local source = sources[name]
		local copy = source:Clone()
		copy.Name = name
		copy.CFrame = source.CFrame
		copy.Size = source.Size
		for attributeName in copy:GetAttributes() do
			if string.sub(attributeName, 1, 6) == "Mockup" then
				copy:SetAttribute(attributeName, nil)
			end
		end
		copy.Anchored = true
		copy.CanCollide = true
		copy.CanQuery = true
		copy.CanTouch = true
		copy.Transparency = 1
		copy:SetAttribute("StitchedEdge", true)
		if string.sub(name, -6) == "_Right" then
			copy:SetAttribute("RidesRightArm", true)
		end
		copy.Parent = folder
	end
	folder.Parent = world
	ChangeHistoryService:SetWaypoint("22-cuff-walk: after")

	-- 7. Done.
	return finish(`added {count} parts to World.{FOLDER_NAME}`)
end

return run22()
