--!strict
-- World prep, plan 4 Task 2 (card work/p5t12/p4t2-card.md): the Epic and Legendary egg templates.
-- Clones Egg_Epic_at_Rare_2 and Egg_Legendary_at_Rare_4 (Workspace.Mockup_EggRanks.Eggs, or ArtLibrary.Mockup_EggRanks.Eggs
-- after a move) into ServerStorage.Assets.Eggs as Epic and Legendary. On each clone: Halo destroyed, saved Mockup* values
-- restored and Mockup* attributes removed, every BasePart Anchored and not CanCollide, attribute Rarity set, WorldPivot at
-- the bottom centre (04-egg-spots way), scaled to the Rare's height. Then Workspace.Mockup_EggRanks moves to ArtLibrary.
-- Backup first: the two eggs and the folder go into ServerStorage.WorldBackups.p4t2 (BackupOf).
-- Both templates there and no folder in the Workspace = "already done"; a lost input = STOP.
-- Rollback: delete Assets.Eggs.Epic and .Legendary, parent ArtLibrary.Mockup_EggRanks back to the Workspace, delete
-- WorldBackups.p4t2. CHECK_ONLY = true prints the plan only. Report lines: shared.P4t2Report.
-- Run in Edit: `require(ServerStorage.Tools.world["28-rank-eggs"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BACKUP_NAME = "p4t2"
local FOLDER_NAME = "Mockup_EggRanks"

type Rank = { rarity: string, sourceName: string }
local RANKS: { Rank } = {
	{ rarity = "Epic", sourceName = "Egg_Epic_at_Rare_2" },
	{ rarity = "Legendary", sourceName = "Egg_Legendary_at_Rare_4" },
}

-- The saved Mockup* value and the property it gives back (11b-mockups-out-of-sight saved these).
local RESTORES: { { attribute: string, property: string, kind: string } } = {
	{ attribute = "MockupTransparency", property = "Transparency", kind = "number" },
	{ attribute = "MockupEnabled", property = "Enabled", kind = "boolean" },
	{ attribute = "MockupCanQuery", property = "CanQuery", kind = "boolean" },
	{ attribute = "MockupCanTouch", property = "CanTouch", kind = "boolean" },
}

local lines: { string } = {}

local function two(n: number): string
	return string.format("%.2f", n)
end

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P4t2Report = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function note(text: string)
	table.insert(lines, text)
end

local function countNamed(parent: Instance?, name: string): number
	local count = 0
	if parent == nil then
		return 0
	end
	for _, child in parent:GetChildren() do
		if child.Name == name then
			count += 1
		end
	end
	return count
end

local function onlyChild(parent: Instance?, name: string): Instance?
	if parent == nil or countNamed(parent, name) ~= 1 then
		return nil
	end
	return parent:FindFirstChild(name)
end

-- The pivot at the bottom centre of the box around every part of the egg (the 04-egg-spots way), and its height.
local function pivotFor(egg: Model): (CFrame, number)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in egg:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for corner = 0, 7 do
				local sx, sy, sz = corner % 2 * 2 - 1, corner // 2 % 2 * 2 - 1, corner // 4 * 2 - 1
				local c = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				low = Vector3.new(math.min(low.X, c.X), math.min(low.Y, c.Y), math.min(low.Z, c.Z))
				high = Vector3.new(math.max(high.X, c.X), math.max(high.Y, c.Y), math.max(high.Z, c.Z))
			end
		end
	end
	return CFrame.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2), high.Y - low.Y
end

local function withSelf(egg: Instance): { Instance }
	local everything = egg:GetDescendants()
	table.insert(everything, egg)
	return everything
end

-- The Mockup* attributes of the egg: how many, and a text with each name's count.
local function mockupCounts(egg: Instance): (number, string)
	local counts: { [string]: number } = {}
	local total = 0
	for _, item in withSelf(egg) do
		for name in item:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				counts[name] = (counts[name] or 0) + 1
				total += 1
			end
		end
	end
	local names: { string } = {}
	for name, count in counts do
		table.insert(names, `{name}={count}`)
	end
	table.sort(names)
	return total, table.concat(names, " ")
end

local function halosIn(egg: Instance): { Instance }
	local found: { Instance } = {}
	for _, item in egg:GetDescendants() do
		if item.Name == "Halo" then
			table.insert(found, item)
		end
	end
	return found
end

local function effectsText(egg: Instance): string
	local parts: { string } = {}
	for _, className in { "PointLight", "ParticleEmitter", "Beam" } do
		local item: any = egg:FindFirstChildWhichIsA(className, true)
		table.insert(parts, `{className}={if item ~= nil then tostring(item.Enabled) else "none"}`)
	end
	return table.concat(parts, " ")
end

local function bodyTransparency(egg: Instance): number
	local best, volume = 1, -1
	for _, item in egg:GetDescendants() do
		local size = if item:IsA("BasePart") then item.Size.X * item.Size.Y * item.Size.Z else -1
		if size > volume then
			best, volume = (item :: BasePart).Transparency, size
		end
	end
	return best
end

-- Gives the saved values back, removes the Mockup* attributes, then sets the Rare template's body values.
local function restoreEgg(egg: Model)
	for _, item in withSelf(egg) do
		local loose: any = item
		for _, restore in RESTORES do
			local saved = item:GetAttribute(restore.attribute)
			if typeof(saved) == restore.kind then
				loose[restore.property] = saved
			end
		end
		for name in item:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				item:SetAttribute(name, nil)
			end
		end
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
		end
	end
end

local function folderIn(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found ~= nil then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function run28(): string
	if RunService:IsRunning() then
		return "STOP: Play is on, this job runs in Edit"
	end

	local assets = ServerStorage:FindFirstChild("Assets")
	local eggsFolder = if assets ~= nil then assets:FindFirstChild("Eggs") else nil
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	local rare = onlyChild(eggsFolder, "Rare")
	if eggsFolder == nil or rare == nil or not rare:IsA("Model") or library == nil then
		return "STOP: Assets.Eggs, its Rare or ArtLibrary is missing (lost input); changed nothing"
	end
	local worldFolder = onlyChild(Workspace, FOLDER_NAME)
	local libraryFolder = onlyChild(library, FOLDER_NAME)
	local epics, legendaries = countNamed(eggsFolder, "Epic"), countNamed(eggsFolder, "Legendary")
	local inWorld, inLibrary = countNamed(Workspace, FOLDER_NAME), countNamed(library, FOLDER_NAME)
	note(`Eggs: Epic x{epics}, Legendary x{legendaries}; {FOLDER_NAME}: Workspace x{inWorld}, ArtLibrary x{inLibrary}`)
	if epics == 1 and legendaries == 1 and inWorld == 0 then
		return "already done: Epic and Legendary are in Assets.Eggs, no Mockup_EggRanks in the Workspace; changed nothing"
	end
	if epics ~= 0 or legendaries ~= 0 or (worldFolder ~= nil and libraryFolder ~= nil) then
		return "STOP: Assets.Eggs holds only one of Epic and Legendary, or the mockup folder is in two places; changed nothing"
	end
	local mockupFolder = if worldFolder ~= nil then worldFolder else libraryFolder
	local mockupEggs = onlyChild(mockupFolder, "Eggs")
	if mockupFolder == nil or mockupEggs == nil then
		return "STOP: Mockup_EggRanks or its Eggs folder is missing (lost input); changed nothing"
	end
	local sources: { Model } = {}
	for _, rank in RANKS do
		local source = onlyChild(mockupEggs, rank.sourceName)
		if not (source and source:IsA("Model") and source:FindFirstChildWhichIsA("SurfaceAppearance", true)) then
			return `STOP: {rank.sourceName} or its SurfaceAppearance is missing (lost input); changed nothing`
		end
		table.insert(sources, source :: Model)
	end

	local _, rareHeight = pivotFor(rare)
	note(`from {mockupFolder:GetFullName()}; folder goes to ServerStorage.ArtLibrary.{FOLDER_NAME}`)
	note(`Rare: height {two(rareHeight)}; {effectsText(rare)}`)
	for index, rank in RANKS do
		local source = sources[index]
		local pivot, height = pivotFor(source)
		local appearance = source:FindFirstChildWhichIsA("SurfaceAppearance", true) :: SurfaceAppearance
		local total, names = mockupCounts(source)
		note(
			`{rank.rarity}: {source:GetFullName()}; height {two(height)} ({math.floor(height / rareHeight * 1000) / 10}% of Rare)`
		)
		note(`{rank.rarity}: colour #{appearance.Color:ToHex()}; Mockup attributes to remove {total} ({names})`)
		note(`{rank.rarity}: Halo to destroy {#halosIn(source)}; effects {effectsText(source)}; pivot {pivot.Position}`)
	end
	if CHECK_ONLY then
		return "CHECK_ONLY: both source eggs found, plan printed; changed nothing"
	end

	local backupFolder = folderIn(folderIn(ServerStorage, "WorldBackups"), BACKUP_NAME)
	local toBackUp: { Instance } = { sources[1], sources[2], mockupFolder }
	for _, source in toBackUp do
		local copy = source:Clone()
		copy:SetAttribute("BackupOf", source:GetFullName())
		copy.Parent = backupFolder
	end
	local made: { Model } = {}
	local before: { number } = {}
	local oldParent = mockupFolder.Parent
	local ok, err = pcall(function()
		for index, rank in RANKS do
			local egg = sources[index]:Clone()
			egg.Name = rank.rarity
			for _, halo in halosIn(egg) do
				halo:Destroy()
			end
			restoreEgg(egg)
			before[index] = select(2, pivotFor(egg))
			egg:ScaleTo(egg:GetScale() * rareHeight / before[index]) -- same 7 studs as the Rare (style guide, Rule 49)
			egg:SetAttribute("Rarity", rank.rarity)
			egg.WorldPivot = pivotFor(egg)
			egg.Parent = eggsFolder
			table.insert(made, egg)
		end
		mockupFolder.Parent = library
	end)
	if not ok then
		for _, egg in made do
			egg:Destroy()
		end
		mockupFolder.Parent = oldParent
		return `STOP: the build failed ({tostring(err)}); new eggs deleted, folder put back`
	end

	local problems = 0
	for index, rank in RANKS do
		local egg = made[index]
		local left = mockupCounts(egg)
		local halos, shows = #halosIn(egg), bodyTransparency(egg)
		local _, height = pivotFor(egg)
		local rarity = tostring(egg:GetAttribute("Rarity"))
		note(`{rank.rarity}: Mockup left {left}, Halos left {halos}, Rarity {rarity}, body Transparency {shows}`)
		note(
			`{rank.rarity}: height {two(before[index])} -> {two(height)} (Rare {two(rareHeight)}); effects {effectsText(
				egg
			)}`
		)
		if left ~= 0 or halos ~= 0 or rarity ~= rank.rarity or shows >= 0.5 then
			problems += 1
		end
	end
	local movedOk = onlyChild(library, FOLDER_NAME) ~= nil and countNamed(Workspace, FOLDER_NAME) == 0
	note(`{FOLDER_NAME} in ArtLibrary, none in the Workspace: {tostring(movedOk)}`)
	if problems > 0 or not movedOk then
		return `PROBLEM: {problems} egg(s) wrong or the folder did not move; rollback: see the header`
	end
	return `changed: Epic and Legendary made in Assets.Eggs, {FOLDER_NAME} moved to ArtLibrary; backup WorldBackups.{BACKUP_NAME}`
end

local ran, message = pcall(run28)
if not ran then
	return finish(`STOPPED WITH AN ERROR: {tostring(message)}`)
end
return finish(message)
