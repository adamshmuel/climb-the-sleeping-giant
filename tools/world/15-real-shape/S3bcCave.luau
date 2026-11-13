--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 3b and 3c: the cave's patches and the cave skirt (stuck safety Task 22, step 22-9; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FolderShared = require(script.Parent.FolderShared)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local PLACE_TOLERANCE = Shared.PLACE_TOLERANCE
local GUARD_COLOR = Shared.GUARD_COLOR
local someProblems = S2bHeadChecks.someProblems
type FolderRecord = FolderShared.FolderRecord
type FolderSpec = FolderShared.FolderSpec
local countsText = FolderShared.countsText
local folderProblems = FolderShared.folderProblems
local makeFolder = FolderShared.makeFolder
local childrenNamed = FolderShared.childrenNamed

-- Why: under his cushion there is a cave (x -21 to 21, y 16 to 44, z 45.5 to 60) where a body fits and can get stuck.
-- It is closed off with 61 blocks, all measured in step 22-8e (the lid), 22-8f2 and 22-8h2 on trial copies, and made into
-- the final numbers in step 22-8e6 (files t22/patches.txt and t22/skirt.txt):
--   3b. 41 invisible patches (strips and the fill behind the skirt), named Patch_Cave_<n>, in the new folder
--       World.WalkSurfaces.Patches. They have the steep guards' settings (step 22-0): Transparency 1, CanCollide, CanQuery,
--       CanTouch off, CastShadow off, SmoothPlastic, collision group Default, Anchored.
--   3c. 20 visible blocks, the cave skirt, named CaveSkirt_<n>, in the new folder World.CaveSkirt (the panel ruling after
--       the rule C rerun: what players see is what they bump into). They are in collision group Default, so players bump
--       into them, and have designer's look: SmoothPlastic, #C2383E, no MaterialVariant, no texture, CastShadow off.
-- None of the 61 blocks is turned. The small places went to Task 23, so every block here is in the cave.
-- It knows three worlds for each folder, and changes nothing on any difference:
--   (a) before: the folder is missing (and no block named like these stands anywhere in World). The folder is made.
--   (b) after: the folder holds exactly its blocks, each within 0.01 studs of the recorded size and place, unturned, with
--       its settings. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- Both folders are checked before anything is changed. The change runs between two ChangeHistoryService waypoints, with
-- the folders built away from the Workspace first, and is checked again afterwards.
local function sectionFolderRecords(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local PATCH_FOLDER_NAME = "Patches" -- under World.WalkSurfaces
	local SKIRT_FOLDER_NAME = "CaveSkirt" -- under World
	local PATCH_NAME_PATTERN = "^Patch_Cave_%d+$"
	local SKIRT_NAME_PATTERN = "^CaveSkirt_%d+$"
	local CAVE_PLACE = "cave" -- the small places went to Task 23
	local TURN_TOLERANCE = 0.001 -- how far a block's axes may differ from unturned
	-- The steep guards' settings, measured in step 22-0 (all 30 identical): Part, Transparency 1, CanCollide, CanQuery,
	-- CanTouch off, CastShadow off, SmoothPlastic, group Default, Anchored, Archivable.
	local PATCH_LOOK: { [string]: any } = {
		Transparency = 1,
		CanCollide = true,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		Anchored = true,
		Archivable = true,
	}
	-- designer on the cave skirt's look, decisions-plans.md (the same named values as the test "the cave skirt is drawn and
	-- solid"). CanTouch is on, because players bump into it like any wall.
	local SKIRT_LOOK: { [string]: any } = {
		Transparency = 0,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = false,
		Anchored = true,
		Archivable = true,
	}
	local SKIRT_COLOR = Color3.fromRGB(194, 56, 62) -- #C2383E

	-- One block as recorded: name, size, then place of the middle (measured in step 22-8e, final numbers of step 22-8h2).
	local function block(
		name: string,
		sizeX: number,
		sizeY: number,
		sizeZ: number,
		x: number,
		y: number,
		z: number
	): FolderRecord
		return {
			name = name,
			className = "Part",
			size = Vector3.new(sizeX, sizeY, sizeZ),
			cframe = CFrame.new(x, y, z),
			place = CAVE_PLACE,
		}
	end
	-- Measured in step 22-8e. The strips across the cave (1 to 14), the front fill (15 to 28) and the upper fill (29 to 41).
	local PATCHES: { FolderRecord } = {
		block("Patch_Cave_1", 1, 5.88, 10, -21.5, 23.2241, 54.5),
		block("Patch_Cave_2", 1, 7.199, 10, -20.5, 24.0633, 54.5),
		block("Patch_Cave_3", 1, 8.498, 10, -19.5, 24.8899, 54.5),
		block("Patch_Cave_4", 2, 9.826, 10, -18, 25.701, 54.5),
		block("Patch_Cave_5", 3, 11.695, 10, -15.5, 26.9302, 54.5),
		block("Patch_Cave_6", 4, 13.425, 10, -12, 28.169, 54.5),
		block("Patch_Cave_7", 20, 14.995, 10, 0, 29.3433, 54.5),
		block("Patch_Cave_8", 4, 13.447, 10, 12, 28.1801, 54.5),
		block("Patch_Cave_9", 3, 11.925, 10, 15.5, 27.0445, 54.5),
		block("Patch_Cave_10", 1, 10.926, 10, 17.5, 26.3978, 54.5),
		block("Patch_Cave_11", 1, 9.618, 10, 18.5, 25.597, 54.5),
		block("Patch_Cave_12", 1, 8.344, 10, 19.5, 24.813, 54.5),
		block("Patch_Cave_13", 1, 7.109, 10, 20.5, 24.0166, 54.5),
		block("Patch_Cave_14", 1, 5.801, 10, 21.5, 23.1721, 54.5),
		block("Patch_Cave_15", 1, 6.267, 1.25, -22.5, 18.6844, 46.375),
		block("Patch_Cave_16", 1, 9.04, 1.25, -21.5, 20.5378, 46.375),
		block("Patch_Cave_17", 1.5, 12.14, 1.25, -20.25, 22.287, 46.375),
		block("Patch_Cave_18", 2, 14.922, 1.25, -18.5, 23.9393, 46.375),
		block("Patch_Cave_19", 3, 17.572, 1.25, -16, 25.5651, 46.375),
		block("Patch_Cave_20", 4, 19.556, 1.25, -12.5, 26.9531, 46.375),
		block("Patch_Cave_21", 5.5, 21.716, 1.25, -7.75, 28.4458, 46.375),
		block("Patch_Cave_22", 13.5, 22.513, 1.25, 1.75, 29.0119, 46.375),
		block("Patch_Cave_23", 4, 20.36, 1.25, 10.5, 27.5913, 46.375),
		block("Patch_Cave_24", 3.5, 18.089, 1.25, 14.25, 26.042, 46.375),
		block("Patch_Cave_25", 2.5, 15.688, 1.25, 17.25, 24.473, 46.375),
		block("Patch_Cave_26", 1.5, 12.957, 1.25, 19.25, 22.882, 46.375),
		block("Patch_Cave_27", 1.5, 10.123, 1.25, 20.75, 21.1903, 46.375),
		block("Patch_Cave_28", 2.5, 7.636, 1.25, 22.75, 18.7765, 46.375),
		block("Patch_Cave_29", 1.5, 6.109, 2.5, -22.25, 20.2355, 48.25),
		block("Patch_Cave_30", 2, 9.414, 2.5, -20.5, 22.254, 48.25),
		block("Patch_Cave_31", 1.5, 12.427, 2.5, -18.75, 24.1907, 48.25),
		block("Patch_Cave_32", 2.5, 14.239, 2.5, -16.75, 25.3243, 48.25),
		block("Patch_Cave_33", 3, 16.123, 2.5, -14, 26.6201, 48.25),
		block("Patch_Cave_34", 4, 17.816, 2.5, -10.5, 27.8161, 48.25),
		block("Patch_Cave_35", 16.5, 19.433, 2.5, -0.25, 28.9634, 48.25),
		block("Patch_Cave_36", 4, 17.888, 2.5, 10, 27.9019, 48.25),
		block("Patch_Cave_37", 3, 16.136, 2.5, 13.5, 26.6851, 48.25),
		block("Patch_Cave_38", 3, 14.001, 2.5, 16.5, 25.2057, 48.25),
		block("Patch_Cave_39", 2, 11.237, 2.5, 19, 23.5209, 48.25),
		block("Patch_Cave_40", 2, 8.238, 2.5, 21, 21.5745, 48.25),
		block("Patch_Cave_41", 2, 6.335, 2.5, 23, 19.9084, 48.25),
	}
	-- Measured in step 22-8e, fronts pulled back in steps 22-8f2 and 22-8h2. Every top is at or under y 47.0.
	local SKIRT: { FolderRecord } = {
		block("CaveSkirt_1", 4.897, 21.639, 4, -20.9486, 34.9456, 43.75),
		block("CaveSkirt_2", 3.2, 21.036, 1.15, -17.5, 36.482, 45.175),
		block("CaveSkirt_3", 2.2, 21.027, 1.15, -15, 36.4865, 45.175),
		block("CaveSkirt_4", 3.2, 12.6, 1.15, -12.5, 32.2861, 45.175),
		block("CaveSkirt_5", 3.2, 14.925, 1.15, -9.5, 33.4485, 45.175),
		block("CaveSkirt_6", 1.2, 16.872, 1.15, -7.5, 34.3831, 45.175),
		block("CaveSkirt_7", 2.2, 17.476, 1.15, -6, 34.6501, 45.175),
		block("CaveSkirt_8", 2.2, 17.864, 1.15, -4, 34.7739, 45.175),
		block("CaveSkirt_9", 8.2, 19.206, 1, 1, 34.9274, 45.25),
		block("CaveSkirt_10", 2.2, 17.81, 1.5, 6, 34.8866, 45),
		block("CaveSkirt_11", 1.2, 17.382, 2, 7.5, 34.7313, 44.75),
		block("CaveSkirt_12", 1.2, 16.482, 2.5, 8.5, 34.2877, 44.5),
		block("CaveSkirt_13", 1.2, 15.574, 3, 9.5, 34.0488, 44.25),
		block("CaveSkirt_14", 1.2, 15.291, 2.5, 10.5, 33.5423, 44.5),
		block("CaveSkirt_15", 1.2, 14.706, 3, 11.5, 33.1006, 44.25),
		block("CaveSkirt_16", 1.2, 17.931, 3.5, 12.5, 34.5616, 44),
		block("CaveSkirt_17", 1.2, 21.818, 4, 13.5, 36.0911, 43.75),
		block("CaveSkirt_18", 1.2, 22.236, 4.5, 14.5, 35.882, 43.5),
		block("CaveSkirt_19", 4.2, 27.562, 4.5, 17, 33.219, 43.5),
		block("CaveSkirt_20", 5.558, 23.473, 5.25, 21.279, 31.175, 43.125),
	}

	local function largestGap(difference: Vector3): number
		return math.max(math.abs(difference.X), math.abs(difference.Y), math.abs(difference.Z))
	end
	-- Size, place and turn, with this section's own tolerances.
	local function caveGeometry(part: BasePart, recorded: FolderRecord): { string }
		local wrong: { string } = {}
		local sizeGap = largestGap(part.Size - recorded.size)
		if sizeGap > PLACE_TOLERANCE then
			table.insert(wrong, `size is off by {string.format("%.3f", sizeGap)}`)
		end
		local placeGap = largestGap(part.Position - recorded.cframe.Position)
		if placeGap > PLACE_TOLERANCE then
			table.insert(wrong, `place is off by {string.format("%.3f", placeGap)}`)
		end
		local cframe = part.CFrame
		if
			(cframe.XVector - Vector3.xAxis).Magnitude > TURN_TOLERANCE
			or (cframe.YVector - Vector3.yAxis).Magnitude > TURN_TOLERANCE
			or (cframe.ZVector - Vector3.zAxis).Magnitude > TURN_TOLERANCE
		then
			table.insert(wrong, "it is turned")
		end
		return wrong
	end
	local PATCH_SPEC: FolderSpec = { look = PATCH_LOOK, color = nil, geometry = caveGeometry }
	local SKIRT_SPEC: FolderSpec = { look = SKIRT_LOOK, color = SKIRT_COLOR, geometry = caveGeometry }

	-- Which world is it?
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if world == nil or walk == nil then
		error("nothing was changed. World.WalkSurfaces is missing")
	end
	local patchFolder = walk:FindFirstChild(PATCH_FOLDER_NAME)
	local skirtFolder = world:FindFirstChild(SKIRT_FOLDER_NAME)
	local problems: { string } = {}
	if childrenNamed(walk, PATCH_FOLDER_NAME) > 1 then
		table.insert(problems, `World.WalkSurfaces has {childrenNamed(walk, PATCH_FOLDER_NAME)} folders called Patches`)
	end
	if childrenNamed(world, SKIRT_FOLDER_NAME) > 1 then
		table.insert(problems, `World has {childrenNamed(world, SKIRT_FOLDER_NAME)} folders called CaveSkirt`)
	end
	local strays: { string } = {}
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BasePart") then
			local likePatch = string.match(descendant.Name, PATCH_NAME_PATTERN) ~= nil
			local likeSkirt = string.match(descendant.Name, SKIRT_NAME_PATTERN) ~= nil
			if (likePatch and descendant.Parent ~= patchFolder) or (likeSkirt and descendant.Parent ~= skirtFolder) then
				table.insert(strays, descendant:GetFullName())
			end
		end
	end
	if #strays > 0 then
		table.insert(
			problems,
			`{#strays} parts named like the patches or the skirt stand outside their folders: {someProblems(strays)}`
		)
	end
	if patchFolder ~= nil then
		for _, text in folderProblems(patchFolder, PATCHES, PATCH_SPEC) do
			table.insert(problems, `3b {text}`)
		end
	end
	if skirtFolder ~= nil then
		for _, text in folderProblems(skirtFolder, SKIRT, SKIRT_SPEC) do
			table.insert(problems, `3c {text}`)
		end
	end
	if #problems > 0 then
		error(
			`nothing was changed. This is neither the world before nor the world after sections 3b and 3c: {someProblems(
				problems
			)}`
		)
	end
	local patchesText = countsText(PATCHES)
	local skirtText = countsText(SKIRT)
	if patchFolder ~= nil and skirtFolder ~= nil then
		return `already done: World.WalkSurfaces.Patches holds {patchesText} and World.CaveSkirt holds {skirtText}, all as recorded`
	end

	-- The change itself: build what is missing away from the Workspace, then put it in between two waypoints.
	local newPatches: Folder? = if patchFolder == nil
		then makeFolder(PATCH_FOLDER_NAME, PATCHES, PATCH_LOOK, GUARD_COLOR)
		else nil
	local newSkirt: Folder? = if skirtFolder == nil
		then makeFolder(SKIRT_FOLDER_NAME, SKIRT, SKIRT_LOOK, SKIRT_COLOR)
		else nil
	local descendantsBefore = #world:GetDescendants()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3b: before")
	end)
	local changed, whyNot = pcall(function()
		if newPatches ~= nil then
			newPatches.Parent = walk
		end
		if newSkirt ~= nil then
			newSkirt.Parent = world
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3b: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3b: before") and tell code_lead`
		)
	end

	-- The same check afterwards, on the live folders.
	local wrong: { string } = {}
	local livePatches = walk:FindFirstChild(PATCH_FOLDER_NAME)
	local liveSkirt = world:FindFirstChild(SKIRT_FOLDER_NAME)
	if livePatches == nil then
		table.insert(wrong, "World.WalkSurfaces.Patches is missing")
	else
		for _, text in folderProblems(livePatches, PATCHES, PATCH_SPEC) do
			table.insert(wrong, `3b {text}`)
		end
	end
	if liveSkirt == nil then
		table.insert(wrong, "World.CaveSkirt is missing")
	else
		for _, text in folderProblems(liveSkirt, SKIRT, SKIRT_SPEC) do
			table.insert(wrong, `3c {text}`)
		end
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	return string.format(
		"made %s%s%s; World now has %d descendants (%d before). Patches: %s. Skirt: %s",
		if newPatches ~= nil then "World.WalkSurfaces.Patches" else "",
		if newPatches ~= nil and newSkirt ~= nil then " and " else "",
		if newSkirt ~= nil then "World.CaveSkirt" else "",
		#world:GetDescendants(),
		descendantsBefore,
		patchesText,
		skirtText
	)
end

return sectionFolderRecords
