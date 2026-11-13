--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2d: rail tops and the ladder slot (stuck safety Task 25, Rulings 12 and 13, steps 5b and 5c)
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
local HEAD_SETTINGS = S2bHeadParts.HEAD_SETTINGS
local FINAL_HEAD_PARTS = S2bHeadParts.FINAL_HEAD_PARTS
local PART_A_BEHIND_Z = S2bHeadParts.PART_A_BEHIND_Z
local SLOT_BLOCK_NAME = S2bHeadParts.SLOT_BLOCK_NAME
local PART_A_BEFORE_AFTER = S2bHeadParts.PART_A_BEFORE_AFTER
local FINAL_HEAD_PARTS_2D = S2bHeadParts.FINAL_HEAD_PARTS_2D
local SLOT_BLOCK_PARTS = S2bHeadParts.SLOT_BLOCK_PARTS
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

-- Why: step 5b's second grid found stuck spots the first missed.
--   * Ruling 13: the flat top of each rail beside the nose (part A, 1.5 wide) holds a body. Part A becomes a wedge: its
--     inner face stays upright and full height, its outer side is one slope of about 87 degrees, so it has no top.
--   * Ruling 12: between the cap ladder's truss (|x| 1.0) and the cap part of the rails (part B, |x| 3.6) is a 2.6 wide
--     slot under the brim where a body fits on his forehead. One invisible LadderSlotBlock per side fills it.
-- The numbers are at the top of this file's head data (PART_A_*, WEDGE_SIZE_*, SLOT_BLOCK_*), as confirmed by step 5c-1.
-- It knows three worlds, and changes nothing on any difference:
--   (a) the world after 2b and 2c: part A boxes, no LadderSlotBlock. The change below is made.
--   (b) the world after 2d: part A wedges and the 2 blocks. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- The change (between two ChangeHistoryService waypoints): part A gets its Shape, Size and CFrame set in place; the 2
-- blocks are copies of part B (a SideRail), built away from the Workspace first, then parented to ForeheadGuard.
local function sectionRailTops(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local guardBox = walk:FindFirstChild("ForeheadGuard")
	if guardBox == nil then
		error("World.WalkSurfaces.ForeheadGuard is missing")
	end

	local afterRecords = FINAL_HEAD_PARTS_2D
	local afterProblems = headProblems(walk, afterRecords)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2E) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2E
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2F) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2F
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2G
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2H
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2I
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2J
		afterProblems = {}
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: the 2 part A rails are wedges and ForeheadGuard holds the 2 %s (%d recorded head parts)",
			SLOT_BLOCK_NAME,
			#afterRecords
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after sections 2b and 2c ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2d ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live part A rails (the check above found each one) and part B, whose settings the blocks copy.
	local liveRails: { Part } = {}
	for _, pair in PART_A_BEFORE_AFTER do
		local found: Part? = nil
		for _, child in guardBox:GetChildren() do
			if child.Name == pair[1].name and child:IsA("Part") and sameAs(child, pair[1].size, pair[1].cframe) then
				found = child
				break
			end
		end
		if found == nil then
			error(`nothing was changed. No part A SideRail at {describePlace(pair[1].cframe)} to turn into a wedge`)
		end
		table.insert(liveRails, found)
	end
	local template: Part? = nil
	for _, child in guardBox:GetChildren() do
		if child.Name == "SideRail" and child:IsA("Part") and child.Shape == Enum.PartType.Block then
			if child.Position.Z > PART_A_BEHIND_Z then
				template = child
				break
			end
		end
	end
	if template == nil then
		error("nothing was changed. No part B SideRail in ForeheadGuard to copy for the blocks")
	end

	-- Build the blocks away from the Workspace and check them.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging2d"
	staging.Archivable = false
	local problems: { string } = {}
	for _, record in SLOT_BLOCK_PARTS do
		local block = template:Clone()
		block.Name = record.name
		block.Size = record.size
		block.CFrame = record.cframe
		block.Parent = staging
		local same, why = sameAs(block, record.size, record.cframe)
		if not same then
			table.insert(problems, `{record.name}: {why}`)
		end
		local wrong = headSettingsProblem(block, HEAD_SETTINGS[record.name])
		if wrong ~= nil then
			table.insert(problems, `{record.name}: {wrong}`)
		end
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The blocks are not right: " .. someProblems(problems))
	end

	-- The report's lines for part A (old size and place), taken before the change.
	local lines: { string } = {}
	for index, rail in liveRails do
		local wedge = PART_A_BEFORE_AFTER[index][2]
		table.insert(
			lines,
			string.format(
				"part A at x %.2f: box %.4f x %.4f x %.4f at %s -> wedge %.4f x %.4f x %.4f at %s (same centre)",
				rail.Position.X,
				rail.Size.X,
				rail.Size.Y,
				rail.Size.Z,
				describePlace(rail.CFrame),
				wedge.size.X,
				wedge.size.Y,
				wedge.size.Z,
				describePlace(wedge.cframe)
			)
		)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2d: before")
	end)
	local changed, whyNot = pcall(function()
		for index, rail in liveRails do
			local wedge = PART_A_BEFORE_AFTER[index][2]
			rail.Shape = Enum.PartType.Wedge
			rail.Size = wedge.size
			rail.CFrame = wedge.cframe
		end
		for _, block in staging:GetChildren() do
			block.Parent = guardBox
		end
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2d: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2d: before") and tell code_lead`
		)
	end

	-- Check the result against the recorded final head.
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2D)
	if #stillProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	for _, record in SLOT_BLOCK_PARTS do
		table.insert(
			lines,
			string.format(
				"added ForeheadGuard.%s: %.1f x %.1f x %.1f at %s",
				record.name,
				record.size.X,
				record.size.Y,
				record.size.Z,
				describePlace(record.cframe)
			)
		)
	end
	table.insert(
		lines,
		string.format(
			"ForeheadGuard now holds %d children (%d recorded head parts)",
			#guardBox:GetChildren(),
			countParts(FINAL_HEAD_PARTS_2D, "ForeheadGuard")
		)
	)
	return table.concat(lines, "\n")
end

return sectionRailTops
