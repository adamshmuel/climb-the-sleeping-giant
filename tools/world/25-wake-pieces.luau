--!strict
-- World prep, plan 6 (wake-up) Task 10: the wake pieces move from Workspace.Mockup_WakeUp into the real world
-- (docs/plans/v2/wake-up.md, "Where the new wake pieces come from" and "New world script: 25-wake-pieces";
-- card work/p6t10/10-card.md; numbers: work/p6t10/10-design.md "What it moves").
-- What it moves (each moved part gets its saved values back from its Mockup* attributes, then loses all five of them):
--   Mockup_WakeUp.AwakeMouth -> World.Giant, turned back +12 degrees about X around (0, 78, 18) to the asleep pose.
--   Mockup_WakeUp.BangAnchor (Bang, ZPop) -> World.GiantFX. Both guis stay Enabled = false.
--   Mockup_WakeUp.Dust's 7 DustSpot parts -> a new Folder World.GiantFX.WakeDust. Emitters stay Enabled = false.
--   Mockup_WakeUp.Birds' 24 models -> a new Folder ReplicatedStorage.Assets.WakeBirds.
--   Every flower model under Workspace.World named in FLOWER_NAMES gets ShakesOnSlam = true.
--   World.Giant.right_arm.right_arm gets RightArmRest = true.
--   What is left of Mockup_WakeUp (Saved, Props, CamHelper, Pose, Make) -> ServerStorage.ArtLibrary.Mockup_WakeUp.
-- Before any change it clones Workspace.Mockup_WakeUp into ServerStorage.WorldBackups.p6t10 (attribute BackupOf).
-- No Mockup_WakeUp in the Workspace = "already done". Anything unexpected (a second AwakeMouth, a piece already in a
-- target, a ShakesOnSlam or RightArmRest mark already there, a count that differs) = STOP, nothing changed.
-- Rollback: clone WorldBackups.p6t10.Mockup_WakeUp back into the Workspace and delete the pieces named above from their
-- new homes; for the marks only, clear the two attributes ShakesOnSlam (flower models) and RightArmRest (the arm mesh).
-- CHECK_ONLY = true measures and prints only. Full report: shared.WakePiecesReport (list of lines).
-- Run in Studio EDIT mode: `return require(game.ServerStorage.Tools.world["25-wake-pieces"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "p6t10"

-- Counts and numbers from work/p6t10/10-design.md.
local DUST_COUNT = 7
local BIRD_COUNT = 24
local FLOWER_COUNT = 246
local FLOWER_NAMES: { [string]: boolean } = {
	Nature_Sunflower = true,
	Nature_FlowerPatch = true,
	Inno_Pink_Flowers = true,
	Inno_Yellow_Flowers = true,
	Inno_Blue_Flowers = true,
	Inno_White_Flowers = true,
}
local TURN_PIVOT = Vector3.new(0, 78, 18)
local TURN_BACK_DEGREES = 12
local MOUTH_AT = Vector3.new(0, 80.3, -15.6)
local TONGUE_AT = Vector3.new(0, 77.0, -16.7)
local POSITION_MARGIN = 0.1 -- studs

-- The four saved values the mockup kept as attributes, and the property each one goes back to. MockupEnabled is the
-- fifth Mockup* attribute: it is cleared, not restored (the guis and emitters stay switched off).
local RESTORE: { { attr: string, prop: string } } = {
	{ attr = "MockupCanCollide", prop = "CanCollide" },
	{ attr = "MockupCanQuery", prop = "CanQuery" },
	{ attr = "MockupCanTouch", prop = "CanTouch" },
	{ attr = "MockupTransparency", prop = "Transparency" },
}
local MOCKUP_ATTRIBUTES =
	{ "MockupCanCollide", "MockupCanQuery", "MockupCanTouch", "MockupTransparency", "MockupEnabled" }

local lines: { string } = {}

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.WakePiecesReport = lines
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

-- The instance and its descendants.
local function withDescendants(root: Instance): { Instance }
	local all: { Instance } = { root }
	for _, descendant in root:GetDescendants() do
		table.insert(all, descendant)
	end
	return all
end

-- Gives the saved values back to the part, then clears all five Mockup* attributes. Returns how many marks it cleared.
local function settle(instance: Instance): number
	local target: any = instance
	for _, pair in RESTORE do
		local value = instance:GetAttribute(pair.attr)
		if instance:IsA("BasePart") and value ~= nil then
			target[pair.prop] = value
		end
	end
	local cleared = 0
	for _, name in MOCKUP_ATTRIBUTES do
		if instance:GetAttribute(name) ~= nil then
			instance:SetAttribute(name, nil)
			cleared += 1
		end
	end
	return cleared
end

local function settleAll(root: Instance): number
	local cleared = 0
	for _, instance in withDescendants(root) do
		cleared += settle(instance)
	end
	return cleared
end

local function marksLeft(root: Instance): number
	local left = 0
	for _, instance in withDescendants(root) do
		for _, name in MOCKUP_ATTRIBUTES do
			if instance:GetAttribute(name) ~= nil then
				left += 1
			end
		end
	end
	return left
end

local function turnBack(part: BasePart)
	local turn = CFrame.new(TURN_PIVOT) * CFrame.Angles(math.rad(TURN_BACK_DEGREES), 0, 0) * CFrame.new(-TURN_PIVOT)
	part.CFrame = turn * part.CFrame
end

-- Every flower model under Workspace.World (the six names, models only).
local function flowerModels(world: Instance): { Model }
	local found: { Model } = {}
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("Model") and FLOWER_NAMES[descendant.Name] == true then
			table.insert(found, descendant)
		end
	end
	return found
end

-- How many instances in the whole place carry the attribute (a mark that is there already means an unexpected world).
local function marksOf(attribute: string): number
	local count = 0
	for _, descendant in game:GetDescendants() do
		if descendant:GetAttribute(attribute) ~= nil then
			count += 1
		end
	end
	return count
end

local function countsLine(): string
	local world = Workspace:FindFirstChild("World")
	local giant = if world ~= nil then world:FindFirstChild("Giant") else nil
	local fx = if world ~= nil then world:FindFirstChild("GiantFX") else nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local dust = if fx ~= nil then fx:FindFirstChild("WakeDust") else nil
	local birds = if assets ~= nil then assets:FindFirstChild("WakeBirds") else nil
	local mouth = if giant ~= nil then giant:FindFirstChild("AwakeMouth") else nil
	local mouthPart = if mouth ~= nil then mouth:FindFirstChild("Mouth") else nil
	local tonguePart = if mouth ~= nil then mouth:FindFirstChild("Tongue") else nil
	local where = ""
	if mouthPart ~= nil and mouthPart:IsA("BasePart") and tonguePart ~= nil and tonguePart:IsA("BasePart") then
		local m, t = mouthPart.Position, tonguePart.Position
		where = string.format("Mouth (%.1f, %.1f, %.1f), Tongue (%.1f, %.1f, %.1f)", m.X, m.Y, m.Z, t.X, t.Y, t.Z)
	end
	return `flower marks {marksOf("ShakesOnSlam")}, arm marks {marksOf("RightArmRest")}, birds {if birds ~= nil
		then #birds:GetChildren()
		else 0}, dust spots {if dust ~= nil then #dust:GetChildren() else 0}, {where}`
end

local function run25(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end

	-- 1. Where is everything now? Direct children only.
	local world = Workspace:FindFirstChild("World")
	local giant = if world ~= nil then world:FindFirstChild("Giant") else nil
	local fx = if world ~= nil then world:FindFirstChild("GiantFX") else nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	if world == nil or giant == nil or fx == nil or assets == nil or library == nil then
		return "STOP: World, World.Giant, World.GiantFX, ReplicatedStorage.Assets or ServerStorage.ArtLibrary is missing, nothing changed"
	end
	local mockupCount = countNamed(Workspace, "Mockup_WakeUp")
	if mockupCount == 0 then
		note(`ArtLibrary.Mockup_WakeUp: {countNamed(library, "Mockup_WakeUp")} there`)
		note(countsLine())
		return "already done: no Mockup_WakeUp in the Workspace, nothing changed"
	end
	if mockupCount > 1 then
		return `STOP: {mockupCount} Mockup_WakeUp in the Workspace, nothing changed`
	end
	local mockup = Workspace:FindFirstChild("Mockup_WakeUp") :: Instance

	-- 2. Nothing may be in a target yet, and no mark may be there yet.
	local taken: { string } = {}
	if countNamed(giant, "AwakeMouth") > 0 then
		table.insert(taken, "Giant.AwakeMouth")
	end
	if countNamed(fx, "BangAnchor") > 0 then
		table.insert(taken, "GiantFX.BangAnchor")
	end
	if countNamed(fx, "WakeDust") > 0 then
		table.insert(taken, "GiantFX.WakeDust")
	end
	if countNamed(assets, "WakeBirds") > 0 then
		table.insert(taken, "Assets.WakeBirds")
	end
	if countNamed(library, "Mockup_WakeUp") > 0 then
		table.insert(taken, "ArtLibrary.Mockup_WakeUp")
	end
	if #taken > 0 then
		return `STOP: already in a target: {table.concat(taken, ", ")}, nothing changed`
	end
	local slamMarks = marksOf("ShakesOnSlam")
	local armMarks = marksOf("RightArmRest")
	if slamMarks ~= 0 or armMarks ~= 0 then
		return `STOP: {slamMarks} ShakesOnSlam and {armMarks} RightArmRest marks are there already, nothing changed`
	end

	-- 3. The pieces in the mockup, and their counts.
	local mouth = mockup:FindFirstChild("AwakeMouth")
	local mouthPart = if mouth ~= nil then mouth:FindFirstChild("Mouth") else nil
	local tonguePart = if mouth ~= nil then mouth:FindFirstChild("Tongue") else nil
	local bang = mockup:FindFirstChild("BangAnchor")
	local dust = mockup:FindFirstChild("Dust")
	local birds = mockup:FindFirstChild("Birds")
	if
		mouth == nil
		or not mouth:IsA("Model")
		or mouthPart == nil
		or not mouthPart:IsA("BasePart")
		or tonguePart == nil
		or not tonguePart:IsA("BasePart")
	then
		return "STOP: Mockup_WakeUp.AwakeMouth (a Model with Mouth and Tongue parts) is missing, nothing changed"
	end
	if bang == nil or not bang:IsA("BasePart") then
		return "STOP: Mockup_WakeUp.BangAnchor (a part) is missing, nothing changed"
	end
	if dust == nil or birds == nil then
		return "STOP: Mockup_WakeUp.Dust or Birds is missing, nothing changed"
	end
	for _, name in { "AwakeMouth", "BangAnchor", "Dust", "Birds" } do
		if countNamed(mockup, name) ~= 1 then
			return `STOP: {countNamed(mockup, name)} {name} in Mockup_WakeUp (expected 1), nothing changed`
		end
	end
	local dustSpots = dust:GetChildren()
	local birdModels = birds:GetChildren()
	if #dustSpots ~= DUST_COUNT or #birdModels ~= BIRD_COUNT then
		return `STOP: {#dustSpots} dust spots and {#birdModels} birds (expected {DUST_COUNT} and {BIRD_COUNT}), nothing changed`
	end
	for _, spot in dustSpots do
		if not spot:IsA("BasePart") or spot:FindFirstChildWhichIsA("ParticleEmitter") == nil then
			return `STOP: dust spot {spot.Name} is not a part with an emitter, nothing changed`
		end
	end
	for _, bird in birdModels do
		if not bird:IsA("Model") then
			return `STOP: bird {bird.Name} is not a Model, nothing changed`
		end
	end
	local flowers = flowerModels(world)
	local armOuter = giant:FindFirstChild("right_arm")
	local arm = if armOuter ~= nil then armOuter:FindFirstChild("right_arm") else nil
	if arm == nil or not arm:IsA("MeshPart") or countNamed(armOuter, "right_arm") ~= 1 then
		return "STOP: World.Giant.right_arm.right_arm (one MeshPart) is missing, nothing changed"
	end
	note(`{#birdModels} birds, {#dustSpots} dust spots, {#flowers} flower models, 1 right-arm part`)
	note(`marks to clear: {marksLeft(mockup)}`)
	if #flowers ~= FLOWER_COUNT then
		return `STOP: {#flowers} flower models (expected {FLOWER_COUNT}), nothing changed`
	end

	-- 4. Where the mouth and tongue would end up.
	local turn = CFrame.new(TURN_PIVOT) * CFrame.Angles(math.rad(TURN_BACK_DEGREES), 0, 0) * CFrame.new(-TURN_PIVOT)
	local mouthTo = (turn * mouthPart.CFrame).Position
	local tongueTo = (turn * tonguePart.CFrame).Position
	note(
		string.format(
			"mouth would be at (%.1f, %.1f, %.1f), tongue at (%.1f, %.1f, %.1f)",
			mouthTo.X,
			mouthTo.Y,
			mouthTo.Z,
			tongueTo.X,
			tongueTo.Y,
			tongueTo.Z
		)
	)
	if (mouthTo - MOUTH_AT).Magnitude > POSITION_MARGIN or (tongueTo - TONGUE_AT).Magnitude > POSITION_MARGIN then
		return "STOP: the turned-back mouth or tongue is not where the design says, nothing changed"
	end

	local head =
		`would move {#birdModels} birds, {#dustSpots} dust spots, the mouth and the bang anchor, mark {#flowers} flower models and 1 arm part`
	if CHECK_ONLY then
		return `CHECK_ONLY: {head}; changed nothing`
	end

	-- 5. Backup, then move.
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
	if backupFolder:FindFirstChild("Mockup_WakeUp") == nil then
		local copy = mockup:Clone()
		copy:SetAttribute("BackupOf", mockup:GetFullName())
		copy.Parent = backupFolder
	end

	local okBegin, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording("p6t10 wake pieces")
	end)
	if not okBegin or recording == nil then
		ChangeHistoryService:SetWaypoint("25-wake-pieces: before")
		note("no recording available: used a waypoint")
	end

	local cleared = 0
	local ok, err = pcall(function()
		-- The mouth, back at the asleep pose, hidden.
		turnBack(mouthPart)
		turnBack(tonguePart)
		cleared += settleAll(mouth)
		mouth.Parent = giant
		-- The bang anchor.
		cleared += settleAll(bang)
		bang.Parent = fx
		-- The dust spots.
		local wakeDust = Instance.new("Folder")
		wakeDust.Name = "WakeDust"
		for _, spot in dustSpots do
			cleared += settleAll(spot)
			spot.Parent = wakeDust
		end
		wakeDust.Parent = fx
		-- The birds.
		local wakeBirds = Instance.new("Folder")
		wakeBirds.Name = "WakeBirds"
		for _, bird in birdModels do
			cleared += settleAll(bird)
			bird.Parent = wakeBirds
		end
		wakeBirds.Parent = assets
		-- The marks.
		for _, flower in flowers do
			flower:SetAttribute("ShakesOnSlam", true)
		end
		arm:SetAttribute("RightArmRest", true)
		-- What is left of the mockup.
		mockup.Parent = library
	end)
	if not ok then
		if okBegin and recording ~= nil then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		end
		return `STOP: a move failed ({tostring(err)}), the recording was cancelled; if anything moved, rollback: clone WorldBackups.{BACKUP_NAME}.Mockup_WakeUp back`
	end
	if okBegin and recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:SetWaypoint("25-wake-pieces: after")
	end

	-- 6. Report.
	note(`cleared {cleared} Mockup marks`)
	note(countsLine())
	local problems = 0
	local wakeBirdsAfter = assets:FindFirstChild("WakeBirds")
	local wakeDustAfter = fx:FindFirstChild("WakeDust")
	if wakeBirdsAfter == nil or #wakeBirdsAfter:GetChildren() ~= BIRD_COUNT then
		problems += 1
	end
	if wakeDustAfter == nil or #wakeDustAfter:GetChildren() ~= DUST_COUNT then
		problems += 1
	end
	if countNamed(Workspace, "Mockup_WakeUp") ~= 0 or countNamed(library, "Mockup_WakeUp") ~= 1 then
		problems += 1
	end
	if marksOf("ShakesOnSlam") ~= FLOWER_COUNT or marksOf("RightArmRest") ~= 1 then
		problems += 1
	end
	if problems > 0 then
		return `PROBLEM: {problems} count(s) differ; rollback: clone WorldBackups.{BACKUP_NAME}.Mockup_WakeUp back into the Workspace`
	end
	return `changed: {head}; backup in ServerStorage.WorldBackups.{BACKUP_NAME}`
end

local ok, message = pcall(run25)
if not ok then
	return finish(`STOPPED WITH AN ERROR: {tostring(message)}`)
end
return finish(message)
