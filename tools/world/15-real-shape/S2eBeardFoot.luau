--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2e: the beard ladder's foot (stuck safety Task 25, step 6b-1 ruling)
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
local FINAL_HEAD_PARTS_2D = S2bHeadParts.FINAL_HEAD_PARTS_2D
local BEARD_RAIL_LONG_LENGTH = S2bHeadParts.BEARD_RAIL_LONG_LENGTH
local BEARD_TOP_SLACK = S2bHeadParts.BEARD_TOP_SLACK
local BEARD_RAIL_BEFORE_AFTER = S2bHeadParts.BEARD_RAIL_BEFORE_AFTER
local FINAL_HEAD_PARTS_2E = S2bHeadParts.FINAL_HEAD_PARTS_2E
local BEARD_LOWEST_RUNG = S2bHeadParts.BEARD_LOWEST_RUNG
local BEARD_EXTRA_RUNG = S2bHeadParts.BEARD_EXTRA_RUNG
local FINAL_HEAD_PARTS_2F = S2bHeadParts.FINAL_HEAD_PARTS_2F
local FINAL_HEAD_PARTS_2G = S2bHeadParts.FINAL_HEAD_PARTS_2G
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local headSettingsProblem = S2bHeadChecks.headSettingsProblem
local headProblems = S2bHeadChecks.headProblems
local someProblems = S2bHeadChecks.someProblems
local countParts = S2bHeadChecks.countParts

-- Why: designer asked that the beard ladder's visible rails reach down to touch his belly. Each rail gets 3.15 studs
-- longer at its bottom end only (its top end stays), and one more rung, a copy of the lowest rung, goes 1.80 further
-- down the ladder. The truss, the foot point and the 16 rungs don't move. Rails and rungs are not solid (CanCollide off),
-- so nothing new can be stood on. The numbers are BEARD_RAIL_LONG_* and BEARD_EXTRA_RUNG_CENTRE above, from step 6b-1a.
-- It knows three worlds, and changes nothing on any difference:
--   (a) the world after 2d: beard rails 28.70 long and 16 rungs. The change below is made.
--   (b) the world after 2e: beard rails 31.85 long and 17 rungs. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- The change (between two ChangeHistoryService waypoints): the 2 live rails get their Size and CFrame set in place; the
-- extra rung is a copy of the lowest live rung, built away from the Workspace first, then parented to BeardLadder.
local function sectionBeardFoot(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local beardBox = walk:FindFirstChild("BeardLadder")
	if beardBox == nil then
		error("World.WalkSurfaces.BeardLadder is missing")
	end

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2E)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2F) == 0 then
		afterProblems = {} -- the world after section 2f: the same rails and rung, with the longer truss
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		afterProblems = {} -- the world after section 2f3: the same, with the wider slot blocks
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		afterProblems = {} -- the world after section 2f4: the same, with the 32 long truss and the shorter part B
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterProblems = {} -- the world after section 2f6: the same, with the truss's foot swung back
	end
	local longerStill = false
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the rails are longer still and one more rung is in
		longerStill = true
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: the 2 beard rails are %.2f long%s and BeardLadder holds the extra rung (%d recorded head parts)",
			BEARD_RAIL_LONG_LENGTH,
			if longerStill then " (section 2g has made them longer still)" else "",
			#FINAL_HEAD_PARTS_2E
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2D)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2d ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2e ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The numbers must keep each rail's top end where it is (within BEARD_TOP_SLACK), or nothing is changed.
	local lines: { string } = {}
	for _, pair in BEARD_RAIL_BEFORE_AFTER do
		local oldTop = pair[1].cframe.Position + pair[1].cframe.RightVector * (pair[1].size.X / 2)
		local newTop = pair[2].cframe.Position + pair[2].cframe.RightVector * (pair[2].size.X / 2)
		if (oldTop - newTop).Magnitude > BEARD_TOP_SLACK then
			error(
				`nothing was changed. The beard rail at x {pair[1].cframe.X} would move its top end by {(
					oldTop - newTop
				).Magnitude} studs`
			)
		end
	end

	-- The live rails (the check above found each one) and the lowest live rung, whose settings the extra rung copies.
	local liveRails: { Part } = {}
	for _, pair in BEARD_RAIL_BEFORE_AFTER do
		local found: Part? = nil
		for _, child in beardBox:GetChildren() do
			if child.Name == pair[1].name and child:IsA("Part") and sameAs(child, pair[1].size, pair[1].cframe) then
				found = child
				break
			end
		end
		if found == nil then
			error(`nothing was changed. No beard Rail at {describePlace(pair[1].cframe)} to make longer`)
		end
		table.insert(liveRails, found)
	end
	local template: Part? = nil
	for _, child in beardBox:GetChildren() do
		if child.Name == BEARD_LOWEST_RUNG.name and child:IsA("Part") then
			if sameAs(child, BEARD_LOWEST_RUNG.size, BEARD_LOWEST_RUNG.cframe) then
				template = child
				break
			end
		end
	end
	if template == nil then
		error("nothing was changed. The lowest beard Rung is not there to copy for the extra rung")
	end

	-- Build the extra rung away from the Workspace and check it.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging2e"
	staging.Archivable = false
	local extra = template:Clone()
	extra.Name = BEARD_EXTRA_RUNG.name
	extra.Size = BEARD_EXTRA_RUNG.size
	extra.CFrame = BEARD_EXTRA_RUNG.cframe
	extra.Parent = staging
	local problems: { string } = {}
	local same, why = sameAs(extra, BEARD_EXTRA_RUNG.size, BEARD_EXTRA_RUNG.cframe)
	if not same then
		table.insert(problems, `{BEARD_EXTRA_RUNG.name}: {why}`)
	end
	local wrong = headSettingsProblem(extra, HEAD_SETTINGS[BEARD_EXTRA_RUNG.name])
	if wrong ~= nil then
		table.insert(problems, `{BEARD_EXTRA_RUNG.name}: {wrong}`)
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The extra rung is not right: " .. someProblems(problems))
	end

	-- The report's lines for the rails (old and new size and place), taken before the change.
	for index, rail in liveRails do
		local longer = BEARD_RAIL_BEFORE_AFTER[index][2]
		table.insert(
			lines,
			string.format(
				"beard Rail at x %.2f: %.4f x %.4f x %.4f at %s -> %.4f x %.4f x %.4f at %s (bottom end only; top end stays)",
				rail.Position.X,
				rail.Size.X,
				rail.Size.Y,
				rail.Size.Z,
				describePlace(rail.CFrame),
				longer.size.X,
				longer.size.Y,
				longer.size.Z,
				describePlace(longer.cframe)
			)
		)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2e: before")
	end)
	local changed, whyNot = pcall(function()
		for index, rail in liveRails do
			local longer = BEARD_RAIL_BEFORE_AFTER[index][2]
			rail.Size = longer.size
			rail.CFrame = longer.cframe
		end
		extra.Parent = beardBox
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2e: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2e: before") and tell code_lead`
		)
	end

	-- Check the result against the recorded final head.
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2E)
	if #stillProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		string.format(
			"added BeardLadder.%s: %.2f x %.2f x %.2f at %s (a copy of the lowest rung, 1.80 further down)",
			BEARD_EXTRA_RUNG.name,
			BEARD_EXTRA_RUNG.size.X,
			BEARD_EXTRA_RUNG.size.Y,
			BEARD_EXTRA_RUNG.size.Z,
			describePlace(BEARD_EXTRA_RUNG.cframe)
		)
	)
	table.insert(
		lines,
		string.format(
			"BeardLadder now holds %d children (%d recorded head parts)",
			#beardBox:GetChildren(),
			countParts(FINAL_HEAD_PARTS_2E, "BeardLadder")
		)
	)
	return table.concat(lines, "\n")
end

return sectionBeardFoot
