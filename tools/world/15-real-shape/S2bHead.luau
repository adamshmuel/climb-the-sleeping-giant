--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2b: his head (stuck safety Task 25)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local describePlace = Shared.describePlace
local sameAs = Shared.sameAs
local HEAD_PARENTS = S2bHeadParts.HEAD_PARENTS
local HEAD_WALK_NAMES = S2bHeadParts.HEAD_WALK_NAMES
local MIDDLE_GUARD_X = S2bHeadParts.MIDDLE_GUARD_X
local CAP_LADDER_ANGLE = S2bHeadParts.CAP_LADDER_ANGLE
local BEARD_LADDER_ANGLE = S2bHeadParts.BEARD_LADDER_ANGLE
local HEAD_SETTINGS = S2bHeadParts.HEAD_SETTINGS
local V1_HEAD_PARTS = S2bHeadParts.V1_HEAD_PARTS
local NEW_HEAD_PARTS = S2bHeadParts.NEW_HEAD_PARTS
local FINAL_HEAD_PARTS = S2bHeadParts.FINAL_HEAD_PARTS
local FINAL_HEAD_PARTS_2D = S2bHeadParts.FINAL_HEAD_PARTS_2D
local FINAL_HEAD_PARTS_2E = S2bHeadParts.FINAL_HEAD_PARTS_2E
local FINAL_HEAD_PARTS_2F = S2bHeadParts.FINAL_HEAD_PARTS_2F
local FINAL_HEAD_PARTS_2G = S2bHeadParts.FINAL_HEAD_PARTS_2G
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local headSettingsProblem = S2bHeadChecks.headSettingsProblem
local headProblems = S2bHeadChecks.headProblems
local someProblems = S2bHeadChecks.someProblems
local countParts = S2bHeadChecks.countParts

-- Which of V1's own parts each kind of new part is a copy of (same class, material, colour and settings).
local TEMPLATE_BOX: { [string]: string } = {
	SideRail = "ForeheadGuard",
	Rung = "CapLadder",
	Rail = "CapLadder",
	Climb = "CapLadder",
}

local NEW_HEAD_BOXES = { "ForeheadGuard", "BeardLadder", "CapLadder" }

-- Every head part that goes: Nose_Walk, the 3 Nightcap_Walk, the middle Guard, V1's 2 SideRail and every part of both
-- ladders (both are re-made).
local function oldHeadParts(walk: Instance): { BasePart }
	local old: { BasePart } = {}
	for _, child in walk:GetChildren() do
		if HEAD_WALK_NAMES[child.Name] and child:IsA("BasePart") then
			table.insert(old, child)
		end
	end
	local forehead = walk:FindFirstChild("ForeheadGuard")
	if forehead ~= nil then
		for _, child in forehead:GetChildren() do
			if child:IsA("BasePart") then
				if
					child.Name == "SideRail" or (child.Name == "Guard" and math.abs(child.Position.X) < MIDDLE_GUARD_X)
				then
					table.insert(old, child)
				end
			end
		end
	end
	for _, boxName in { "CapLadder", "BeardLadder" } do
		local box = walk:FindFirstChild(boxName)
		if box ~= nil then
			for _, child in box:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(old, child)
				end
			end
		end
	end
	return old
end

-- The change: build the new parts away from the Workspace (copies of V1's own SideRail, Rung, Rail and Climb), check
-- them, then between two waypoints remove the old parts and put the new ones in. Returns the report.
local function changeHead(walk: Instance): string
	-- What goes, counted first: V1 had 52 head parts, the final head keeps its 4 side Guards.
	local old = oldHeadParts(walk)
	local expectedOld = #V1_HEAD_PARTS - (#FINAL_HEAD_PARTS - #NEW_HEAD_PARTS)
	if #old ~= expectedOld then
		error(`nothing was changed. {#old} head parts would go, expected {expectedOld}`)
	end

	-- V1's own parts are the templates.
	local templates: { [string]: BasePart } = {}
	for name, boxName in TEMPLATE_BOX do
		local box = walk:FindFirstChild(boxName)
		local template: BasePart? = nil
		if box ~= nil then
			for _, child in box:GetChildren() do
				if child.Name == name and child:IsA("BasePart") then
					template = child
					break
				end
			end
		end
		if template == nil then
			error(`nothing was changed. No {boxName}.{name} to copy`)
		end
		templates[name] = template
	end

	-- Build every new part away from the Workspace and check it.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging"
	staging.Archivable = false
	local stagedBoxes: { [string]: Folder } = {}
	for _, boxName in NEW_HEAD_BOXES do
		local folder = Instance.new("Folder")
		folder.Name = boxName
		folder.Parent = staging
		stagedBoxes[boxName] = folder
	end
	local problems: { string } = {}
	for _, record in NEW_HEAD_PARTS do
		local copy = templates[record.name]:Clone() :: BasePart
		copy.Size = record.size
		copy.CFrame = record.cframe
		copy.Parent = stagedBoxes[record.parent]
		local same, why = sameAs(copy, record.size, record.cframe)
		if not same then
			table.insert(problems, `{record.parent}.{record.name}: {why}`)
		end
		local wrong = headSettingsProblem(copy, HEAD_SETTINGS[record.name])
		if wrong ~= nil then
			table.insert(problems, `{record.parent}.{record.name}: {wrong}`)
		end
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The new parts are not right: " .. someProblems(problems))
	end

	-- The report's lines for what goes (old size and place).
	local lines: { string } = {}
	local before: { [string]: number } = {}
	for _, boxName in HEAD_PARENTS do
		local box = if boxName == WALK_FOLDER_NAME then walk else walk:FindFirstChild(boxName)
		before[boxName] = if box ~= nil then #box:GetChildren() else 0
	end
	for _, part in old do
		local boxName = if part.Parent ~= nil then part.Parent.Name else "?"
		table.insert(
			lines,
			string.format(
				"removed %s.%s: %.3f x %.3f x %.3f at %s",
				boxName,
				part.Name,
				part.Size.X,
				part.Size.Y,
				part.Size.Z,
				describePlace(part.CFrame)
			)
		)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2b: before")
	end)
	local changed, whyNot = pcall(function()
		for _, part in old do
			part:Destroy()
		end
		for _, boxName in NEW_HEAD_BOXES do
			local liveBox = walk:FindFirstChild(boxName)
			if liveBox == nil then
				error(`{boxName} is missing`)
			end
			for _, part in stagedBoxes[boxName]:GetChildren() do
				part.Parent = liveBox
			end
		end
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2b: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2b: before") and tell code_lead`
		)
	end

	-- Check the result against the recorded final head.
	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS)
	if #afterProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(afterProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end

	-- The report's lines for what was added: every side rail, truss and rail, and each ladder's first and last rung.
	local rungsTotal: { [string]: number } = {}
	for _, record in NEW_HEAD_PARTS do
		if record.name == "Rung" then
			rungsTotal[record.parent] = (rungsTotal[record.parent] or 0) + 1
		end
	end
	local rungsSeen: { [string]: number } = {}
	for _, record in NEW_HEAD_PARTS do
		local show = true
		if record.name == "Rung" then
			local seen = (rungsSeen[record.parent] or 0) + 1
			rungsSeen[record.parent] = seen
			show = seen == 1 or seen == rungsTotal[record.parent]
		end
		if show then
			table.insert(
				lines,
				string.format(
					"added %s.%s: %s %.3f x %.3f x %.3f at %s",
					record.parent,
					record.name,
					HEAD_SETTINGS[record.name].className,
					record.size.X,
					record.size.Y,
					record.size.Z,
					describePlace(record.cframe)
				)
			)
		end
	end
	for _, boxName in { "BeardLadder", "CapLadder" } do
		table.insert(lines, `{boxName}: {rungsTotal[boxName]} rungs added (the first and the last are listed above)`)
	end
	table.insert(
		lines,
		string.format(
			"head parts removed: %d; added: %d; kept (the 4 side Guards): %d",
			#old,
			#NEW_HEAD_PARTS,
			#FINAL_HEAD_PARTS - #NEW_HEAD_PARTS
		)
	)
	for _, boxName in HEAD_PARENTS do
		local box = if boxName == WALK_FOLDER_NAME then walk else walk:FindFirstChild(boxName)
		local now = if box ~= nil then #box:GetChildren() else 0
		table.insert(lines, `{boxName}: {before[boxName]} children before, {now} after`)
	end
	return table.concat(lines, "\n")
end

local function sectionHead(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	-- Two worlds are known; anything else stops with nothing changed.
	--   (b) the final head: already done. Part A may be the box (this section's own result) or section 2d's wedge, and
	--       then the 2 slot blocks are there too.
	--   (a) V1's head: all 52 parts as recorded. The change is made.
	local finalProblems = headProblems(walk, FINAL_HEAD_PARTS)
	local finalRecords = FINAL_HEAD_PARTS
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2D) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2D
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2E) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2E
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2F) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2F
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2G
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2H
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2I
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2J
	end
	if #finalProblems == 0 then
		return string.format(
			"already done: his head is the final one (%d recorded head parts: ForeheadGuard %d, BeardLadder %d at %.1f degrees, CapLadder %d at %.1f degrees; Nose_Walk, Nightcap_Walk and the middle Guard are gone; part A is %s)",
			#finalRecords,
			countParts(finalRecords, "ForeheadGuard"),
			countParts(finalRecords, "BeardLadder"),
			BEARD_LADDER_ANGLE,
			countParts(finalRecords, "CapLadder"),
			CAP_LADDER_ANGLE,
			if finalRecords == FINAL_HEAD_PARTS
				then "the box"
				elseif finalRecords == FINAL_HEAD_PARTS_2D then "section 2d's wedge, with the 2 slot blocks"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2E
				then "section 2d's wedge, with the 2 slot blocks, and the beard rails are section 2e's longer ones"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2F
				then "section 2d's wedge, with the 2 slot blocks, section 2e's longer beard rails and section 2f's longer truss"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2G
				then "section 2d's wedge, section 2e's longer beard rails, section 2f's longer truss and section 2f3's wider slot blocks"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2H
				then "section 2d's wedge, section 2e's longer beard rails, section 2f4's 32 long truss, section 2f3's wider slot blocks and section 2f4's shorter part B"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2I
				then "section 2d's wedge, section 2e's longer beard rails, section 2f4's 32 long truss turned by section 2f6, section 2f3's wider slot blocks and section 2f4's shorter part B"
				else "section 2d's wedge, section 2g's 34.60 long beard rails and extra rung, section 2f4's 32 long truss turned by section 2f6, section 2f3's wider slot blocks and section 2f4's shorter part B"
		)
	end
	local v1Problems = headProblems(walk, V1_HEAD_PARTS)
	if #v1Problems > 0 then
		error(
			"nothing was changed. His head is neither V1's ("
				.. someProblems(v1Problems)
				.. ") nor the final one ("
				.. someProblems(finalProblems)
				.. ")"
		)
	end
	return changeHead(walk)
end

return sectionHead
