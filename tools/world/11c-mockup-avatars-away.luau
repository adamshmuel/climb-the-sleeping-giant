--!strict
-- World prep, V2 setup 4: no mockup avatar stands in a player's way (docs/plans/v2/index.md, "V2 setup 4").
-- Why: a mockup avatar is a model with a Humanoid that designer uses to show a player's size in mockup shots. Six of them
-- stood in the Workspace, invisible (V2 setup 3). A character's body parts become solid again in Play, even with
-- CanCollide off in Edit, so the avatar on garden 4's spawn spot lifted a real player 4 studs, and the other five stood on
-- ways up and on the giant, where they can block a climbing player.
-- What it does: every model that holds a Humanoid, inside a Workspace folder whose name starts with "Mockup_", moves to
--   ServerStorage.ArtLibrary.MockupAvatars.<that mockup folder's name>.<the model's name>
--   (for example MockupAvatars.Mockup_WakeUp.Avatar; MockupAvatars.Mockup_Nests.Avatar for the one that stood in
--   Mockup_Nests.LapBuild_Designer). Designer can bring one back for a shot by moving it to Workspace again.
-- It keeps every Mockup* attribute and changes nothing else: no other piece is moved, changed or deleted.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when no avatar
-- is left in a Mockup_ folder it changes nothing and says "already done". The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FOLDER_PREFIX = "Mockup_"
local LIBRARY_NAME = "ArtLibrary"
local AVATARS_NAME = "MockupAvatars"

type Move = { avatar: Model, folderName: string }

local function isMockupFolder(child: Instance): boolean
	return string.sub(child.Name, 1, #FOLDER_PREFIX) == FOLDER_PREFIX
end

-- Stops with an error when something outside the avatar is joined to a part of the avatar: moving it would break the join.
local function checkNotJoinedToOutside(folder: Instance, avatar: Model)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsDescendantOf(avatar) then
			continue
		end
		if descendant:IsA("JointInstance") or descendant:IsA("Constraint") or descendant:IsA("WeldConstraint") then
			local joined = descendant :: any
			for _, other in { joined.Part0, joined.Part1 } do
				if other ~= nil and (other :: Instance):IsDescendantOf(avatar) then
					error(`{descendant:GetFullName()} joins the avatar {avatar:GetFullName()} to a piece outside it`)
				end
			end
		end
	end
end

local function run(): string
	-- Check everything first, so a problem stops the script before anything changes.
	local folders: { Instance } = {}
	for _, child in Workspace:GetChildren() do
		if isMockupFolder(child) then
			table.insert(folders, child)
		end
	end
	if #folders == 0 then
		error("no Workspace child starts with Mockup_")
	end

	local library = ServerStorage:FindFirstChild(LIBRARY_NAME)
	if library == nil then
		error(`ServerStorage.{LIBRARY_NAME} is missing`)
	end
	local avatars = library:FindFirstChild(AVATARS_NAME)
	if avatars ~= nil and not avatars:IsA("Folder") then
		error(`{avatars:GetFullName()} is not a Folder`)
	end

	local moves: { Move } = {}
	local taken: { [string]: boolean } = {}
	for _, folder in folders do
		for _, descendant in folder:GetDescendants() do
			if not descendant:IsA("Humanoid") then
				continue
			end
			local avatar = descendant.Parent
			if avatar == nil or not avatar:IsA("Model") then
				error(`{descendant:GetFullName()} is not inside a Model`)
			end
			local key = `{folder.Name}/{avatar.Name}`
			if taken[key] then
				error(`two avatars named {avatar.Name} would both go to {AVATARS_NAME}.{folder.Name}`)
			end
			taken[key] = true
			if avatars ~= nil then
				local target = avatars:FindFirstChild(folder.Name)
				if target ~= nil and target:FindFirstChild(avatar.Name) ~= nil then
					error(`{AVATARS_NAME}.{folder.Name}.{avatar.Name} already exists`)
				end
				if target ~= nil and not target:IsA("Folder") then
					error(`{target:GetFullName()} is not a Folder`)
				end
			end
			checkNotJoinedToOutside(folder, avatar)
			table.insert(moves, { avatar = avatar, folderName = folder.Name })
		end
	end

	if #moves == 0 then
		if avatars ~= nil and #avatars:GetChildren() > 0 then
			return "already done"
		end
		error(`no avatar is left in a Mockup_ folder, but {LIBRARY_NAME}.{AVATARS_NAME} holds none either`)
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("11c-mockup-avatars-away: before")
	end)

	local avatarsFolder: Instance
	if avatars == nil then
		local created = Instance.new("Folder")
		created.Name = AVATARS_NAME
		created.Parent = library
		avatarsFolder = created
	else
		avatarsFolder = avatars
	end

	local report: { string } = {}
	for _, move in moves do
		local target = avatarsFolder:FindFirstChild(move.folderName)
		if target == nil then
			local created = Instance.new("Folder")
			created.Name = move.folderName
			created.Parent = avatarsFolder
			target = created
		end
		local from = move.avatar:GetFullName()
		move.avatar.Parent = target
		table.insert(report, `{from} -> {move.avatar:GetFullName()}`)
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("11c-mockup-avatars-away: after")
	end)

	table.insert(report, `{#moves} avatars moved to {avatarsFolder:GetFullName()}`)
	return table.concat(report, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
