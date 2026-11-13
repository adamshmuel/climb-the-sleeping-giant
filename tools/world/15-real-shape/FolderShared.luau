--!strict
-- The folder records the cave and slide-guard sections share: what a folder must hold, how it is checked and how it is made.

local Shared = require(script.Parent.Shared)

local samePhysics = Shared.samePhysics

local FolderShared = {}

-- One part as recorded. `place` is the small place it belongs to (only used to count parts per place in a message).
export type FolderRecord = { name: string, className: string, size: Vector3, cframe: CFrame, place: string }

-- What a section asks of its folders: the look every part has, the colour to check (nil: not checked), and how that
-- section compares size, place and turn (it returns what differs; empty when all is right).
export type FolderSpec = {
	look: { [string]: any },
	color: Color3?,
	geometry: (part: BasePart, recorded: FolderRecord) -> { string },
}

local SHOWN_MATERIAL = Enum.Material.SmoothPlastic

local function colorText(color: Color3): string
	return `{math.round(color.R * 255)}, {math.round(color.G * 255)}, {math.round(color.B * 255)}`
end

local function countsText(records: { FolderRecord }): string
	local perPlace: { [string]: number } = {}
	for _, recorded in records do
		perPlace[recorded.place] = (perPlace[recorded.place] or 0) + 1
	end
	local texts: { string } = {}
	for place, count in perPlace do
		table.insert(texts, `{place} {count}`)
	end
	table.sort(texts)
	return `{#records} parts (per place: {table.concat(texts, ", ")})`
end

-- What is wrong with a folder that should hold exactly `records` with this spec; the list is empty when all is right.
local function folderProblems(folder: Instance, records: { FolderRecord }, spec: FolderSpec): { string }
	local problems: { string } = {}
	if not folder:IsA("Folder") then
		table.insert(problems, `{folder.Name} is a {folder.ClassName}, not a Folder`)
	end
	if #folder:GetChildren() ~= #records then
		table.insert(problems, `{folder.Name} holds {#folder:GetChildren()} children, expected {#records}`)
	end
	for _, recorded in records do
		local found: { Instance } = {}
		for _, child in folder:GetChildren() do
			if child.Name == recorded.name then
				table.insert(found, child)
			end
		end
		if #found ~= 1 or found[1].ClassName ~= recorded.className then
			table.insert(problems, `{recorded.name}: {#found} found, expected 1 {recorded.className}`)
			continue
		end
		local part = found[1] :: BasePart
		local wrong: { string } = spec.geometry(part, recorded)
		for property, value in spec.look do
			if (part :: any)[property] ~= value then
				table.insert(wrong, `{property} is {tostring((part :: any)[property])}, expected {tostring(value)}`)
			end
		end
		if part.Material ~= SHOWN_MATERIAL then
			table.insert(wrong, `Material is {part.Material.Name}`)
		end
		if part.CollisionGroup ~= "Default" then
			table.insert(wrong, `CollisionGroup is {part.CollisionGroup}, expected Default`)
		end
		if part.MaterialVariant ~= "" then
			table.insert(wrong, `MaterialVariant is "{part.MaterialVariant}"`)
		end
		if not samePhysics(part, nil) then
			table.insert(wrong, "CustomPhysicalProperties are set")
		end
		if #part:GetChildren() > 0 then
			table.insert(wrong, `it has {#part:GetChildren()} children`)
		end
		if spec.color ~= nil and colorText(part.Color) ~= colorText(spec.color) then
			table.insert(wrong, `Color is {colorText(part.Color)}, expected {colorText(spec.color)}`)
		end
		if #wrong > 0 then
			table.insert(problems, `{recorded.name}: {table.concat(wrong, ", ")}`)
		end
	end
	return problems
end

-- A new folder with all `records`, built away from the Workspace.
local function makeFolder(name: string, records: { FolderRecord }, look: { [string]: any }, color: Color3): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, recorded in records do
		local part = Instance.new(recorded.className) :: BasePart
		part.Name = recorded.name
		part.Size = recorded.size
		part.CFrame = recorded.cframe
		for property, value in look do
			(part :: any)[property] = value
		end
		part.Material = SHOWN_MATERIAL
		part.Color = color
		part.CollisionGroup = "Default"
		part.Parent = folder
	end
	return folder
end

local function childrenNamed(parent: Instance, name: string): number
	local count = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			count += 1
		end
	end
	return count
end

FolderShared.countsText = countsText
FolderShared.folderProblems = folderProblems
FolderShared.makeFolder = makeFolder
FolderShared.childrenNamed = childrenNamed

return FolderShared
