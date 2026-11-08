--!strict
-- World prep, plan 5 (egg nests and climbing) Task 13: the solid cuff straps and ledges
-- (docs/plans/v2/egg-nests-and-climbing.md Task 13; spec 5 "Cuff strap and ledge (Epic)"; card work/p5t13/card.md;
-- numbers: work/p5t13/p5t13-scripts.md sections W and S).
-- Task 13b (card work/p5t13b/card.md; numbers work/p5t13b/p5t13b-scripts.md sections W2, S2, R2): the designer re-fitted
-- the straps and added a flap, a foot and two curbs to each cuff, then four more walk curbs on each strap
-- (work/p5t13b/curbs-done.md), so this script now copies 13 pieces per side (26).
-- What it does: for each cuff (Left and Right) it clones the thirteen invisible walk pieces from the art in
-- Workspace.Mockup_Nests.Art into a new folder World.CuffWalk, with the same place and size:
--   Straps.CuffStrap_<side>.StrapWalk                      -> Strap_<side>
--   Straps.CuffStrap_<side>.CuffTabWalk                    -> Tab_<side>
--   Straps.CuffStrap_<side>.StrapFootWalk                  -> Foot_<side>
--   Straps.CuffStrap_<side>.FootCurbFar                    -> CurbFar_<side>
--   Straps.CuffStrap_<side>.FootCurbSide                   -> CurbSide_<side>
--   Straps.CuffStrap_<side>.StrapCurbInboard               -> StrapCurbInboard_<side>
--   Straps.CuffStrap_<side>.StrapCurbTop                   -> StrapCurbTop_<side>
--   Straps.CuffStrap_<side>.FlapCurbUphill                 -> FlapCurbUphill_<side>
--   Straps.CuffStrap_<side>.FlapCurbEnd                    -> FlapCurbEnd_<side>
--   Pockets.CuffPocketFront_<side>.LedgeWalk               -> FrontLedge_<side>
--   Pockets.CuffPocketFront_<side>.LedgeWalk_FrontStrip    -> FrontStrip_<side>
--   Pockets.CuffPocketBack_<side>.LedgeWalk                -> BackLedge_<side>
--   Pockets.CuffPocketBack_<side>.LedgeWalk_Join           -> Join_<side>
-- The foot hems (FootHemFar, FootHemSide) are art like all art: they stay in the mockup and are not copied.
-- Each copy is Anchored, CanCollide / CanQuery / CanTouch true, Transparency 1, has no Mockup* attribute, has
-- StitchedEdge = true, and the right side also RidesRightArm = true. The art is not touched.
-- Worlds, checked before any change: a piece missing = STOP; World.CuffWalk with 26 parts matching their sources (count,
-- CFrame within 0.01, size) = "already done"; World.CuffWalk with parts that do not match = it is backed up, removed and
-- rebuilt with all 26.
-- Before any change it clones World.CuffWalk and both CuffStrap_* models (as <name>_Before22) into
-- ServerStorage.WorldBackups.Plan5Task13b, in the same call.
-- Rollback: delete World.CuffWalk and clone the backup back.
-- CHECK_ONLY = true measures and prints only. Full report: shared.Plan5Task13CuffReport (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["22-cuff-walk"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "Plan5Task13b"
local FOLDER_NAME = "CuffWalk"
local EXPECTED = 26 -- plan 5 Task 13b: 13 pieces on each of 2 sides

local SIDES = { "Left", "Right" }

type Piece = { group: string, model: string, part: string, name: string }
-- The thirteen pieces of one side (`{side}` is filled in below).
local PIECES: { Piece } = {
	{ group = "Straps", model = "CuffStrap_{side}", part = "StrapWalk", name = "Strap_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "CuffTabWalk", name = "Tab_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "StrapFootWalk", name = "Foot_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "FootCurbFar", name = "CurbFar_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "FootCurbSide", name = "CurbSide_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "StrapCurbInboard", name = "StrapCurbInboard_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "StrapCurbTop", name = "StrapCurbTop_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "FlapCurbUphill", name = "FlapCurbUphill_{side}" },
	{ group = "Straps", model = "CuffStrap_{side}", part = "FlapCurbEnd", name = "FlapCurbEnd_{side}" },
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

-- True when World.CuffWalk already holds all the finished pieces (same names, CFrame within 0.01 and size as the art).
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
			or not made.CFrame:FuzzyEq(source.CFrame, 0.01)
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

	-- 1. Find the 26 pieces.
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
		return finish(`STOP: {count} pieces found, plan 5 Task 13b says {EXPECTED}, nothing changed`)
	end

	-- 3. CHECK_ONLY: print the names and stop.
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: {table.concat(order, ", ")}; changed nothing`)
	end

	-- 4. Already done?
	local existing = world:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and alreadyDone(existing, sources) then
		return finish("already done")
	end

	-- 5. Backup in the same call: World.CuffWalk (if there is one) and both CuffStrap_* models.
	local backupFolder = getBackupFolder()
	local toBackUp: { Instance } = {}
	if existing ~= nil then
		table.insert(toBackUp, existing)
	end
	for _, model in models do
		if model.Parent ~= nil and model.Parent.Name == "Straps" then
			table.insert(toBackUp, model)
		end
	end
	for _, original in toBackUp do
		local copyName = `{original.Name}_Before22`
		if backupFolder:FindFirstChild(copyName) == nil then
			local copy = original:Clone()
			copy.Name = copyName
			copy:SetAttribute("BackupOf", original:GetFullName())
			copy.Parent = backupFolder
		end
	end
	if existing ~= nil then
		note(
			`removed the old World.{FOLDER_NAME} ({#existing:GetChildren()} parts), backed up as {FOLDER_NAME}_Before22`
		)
	end

	-- 6. Make the folder and the pieces.
	ChangeHistoryService:SetWaypoint("22-cuff-walk: before")
	if existing ~= nil then
		existing:Destroy()
	end
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
