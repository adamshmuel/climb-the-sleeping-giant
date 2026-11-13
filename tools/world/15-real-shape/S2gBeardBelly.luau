--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2g: the beard rails reach his drawn belly (stuck safety Task 25, after the Task 26 ruling)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local SIZE_TOLERANCE = Shared.SIZE_TOLERANCE
local describePlace = Shared.describePlace
local sameAs = Shared.sameAs
local HEAD_SETTINGS = S2bHeadParts.HEAD_SETTINGS
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local BELLY_RAIL_EXTRA = S2bHeadChecks.BELLY_RAIL_EXTRA
local BELLY_RAIL_EXTRA_SLACK = S2bHeadChecks.BELLY_RAIL_EXTRA_SLACK
local BELLY_RAIL_LENGTH = S2bHeadChecks.BELLY_RAIL_LENGTH
local BELLY_RUNG_STEP = S2bHeadChecks.BELLY_RUNG_STEP
local BELLY_RUNG_STEP_SLACK = S2bHeadChecks.BELLY_RUNG_STEP_SLACK
local BELLY_TURN_SLACK = S2bHeadChecks.BELLY_TURN_SLACK
local BELLY_TOP_SLACK = S2bHeadChecks.BELLY_TOP_SLACK
local BEARD_RAIL_BELLY_BEFORE_AFTER = S2bHeadChecks.BEARD_RAIL_BELLY_BEFORE_AFTER
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local BEARD_LOW_RUNG = S2bHeadChecks.BEARD_LOW_RUNG
local BEARD_BELLY_RUNG = S2bHeadChecks.BEARD_BELLY_RUNG
local headSettingsProblem = S2bHeadChecks.headSettingsProblem
local headProblems = S2bHeadChecks.headProblems
local someProblems = S2bHeadChecks.someProblems
local countValues = FitShared.countValues
local SLOT_MAY_DIFFER = FitShared.SLOT_MAY_DIFFER
local headPartSnapshot = FitShared.headPartSnapshot
local headPartDifferences = FitShared.headPartDifferences
local liveHeadPart = FitShared.liveHeadPart
local headPartText = FitShared.headPartText

-- Why: designer asked that the beard ladder's visible rails touch his belly. The rails of section 2e still end 2.4 to 2.7
-- studs over his drawn belly, measured on his drawn skin (DrawnSkin). Each rail gets BELLY_RAIL_EXTRA (2.75) studs longer
-- at its bottom end only (its top end stays, its turn and thickness stay), and one more rung, a copy of today's lowest
-- rung, goes BELLY_RUNG_STEP (1.80) studs further down the ladder. Rails and rungs are not solid (CanCollide off), so
-- nothing new can be stood on. The numbers are the BELLY_* constants above.
-- What it does:
--   - It refuses to run in Play.
--   - It knows two worlds and changes nothing on any difference:
--       (a) the world after 2f6: beard rails 31.85 long and 17 rungs (FINAL_HEAD_PARTS_2I). The change below is made.
--       (b) the world after 2g: beard rails 34.60 long and 18 rungs (FINAL_HEAD_PARTS_2J). It says "already done".
--       (c) anything else: it stops with nothing changed and names what differs.
--   - Before the change, for each rail: its top end stays within 0.05, its bottom end moves 2.75 (within 0.01) along the
--     same line, it keeps its thickness and its turn. The extra rung has the lowest rung's size and turn and stands 1.80
--     (within 0.01) further down the same line.
--   - The extra rung is built away from the Workspace first (a clone of the lowest live rung), then parented to
--     BeardLadder. The 2 live rails get their Size and CFrame set in place and nothing else (it compares every other
--     value before and after), with waypoints before and after, and checks the head again.
--   - It prints before and after for each rail and the added rung.
-- One line about a beard rail: size, place, ends z, and its lowest end.
local function railBellyText(size: Vector3, cframe: CFrame): string
	local bottom = cframe.Position - cframe.RightVector * (size.X / 2)
	return headPartText(size, cframe, false) .. string.format("; bottom end y %.4f, z %.4f", bottom.Y, bottom.Z)
end

local function sectionBeardBelly(): string
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

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2J)
	if #afterProblems == 0 then
		local lowestRung = liveHeadPart(walk, BEARD_BELLY_RUNG, {})
		return string.format(
			"already done: the 2 beard rails are %.2f long and BeardLadder holds the extra rung at %s (%d recorded head parts)",
			BELLY_RAIL_LENGTH,
			if lowestRung ~= nil then describePlace(lowestRung.CFrame) else "(not found)",
			#FINAL_HEAD_PARTS_2J
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2I)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f6 ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2g ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The numbers must do what the ruling says, or nothing is changed.
	local axis: Vector3 = BEARD_RAIL_BELLY_BEFORE_AFTER[1][1].cframe.RightVector -- up the ladder
	for _, pair in BEARD_RAIL_BELLY_BEFORE_AFTER do
		local old, new = pair[1], pair[2]
		local oldTop = old.cframe.Position + old.cframe.RightVector * (old.size.X / 2)
		local newTop = new.cframe.Position + new.cframe.RightVector * (new.size.X / 2)
		if (oldTop - newTop).Magnitude > BELLY_TOP_SLACK then
			error(
				`nothing was changed. The beard rail at x {old.cframe.X} would move its top end by {(oldTop - newTop).Magnitude} studs`
			)
		end
		local oldBottom = old.cframe.Position - old.cframe.RightVector * (old.size.X / 2)
		local newBottom = new.cframe.Position - new.cframe.RightVector * (new.size.X / 2)
		local moved = newBottom - oldBottom
		local down = -moved:Dot(old.cframe.RightVector)
		local sideways = (moved + old.cframe.RightVector * down).Magnitude
		if math.abs(down - BELLY_RAIL_EXTRA) > BELLY_RAIL_EXTRA_SLACK or sideways > BELLY_RAIL_EXTRA_SLACK then
			error(
				string.format(
					"nothing was changed. The beard rail at x %.2f would grow %.3f studs down its line and %.3f sideways, expected %g and 0",
					old.cframe.X,
					down,
					sideways,
					BELLY_RAIL_EXTRA
				)
			)
		end
		if
			math.abs(old.size.Y - new.size.Y) > SIZE_TOLERANCE
			or math.abs(old.size.Z - new.size.Z) > SIZE_TOLERANCE
			or new.cframe.RightVector:Dot(old.cframe.RightVector) < 1 - BELLY_TURN_SLACK
			or new.cframe.UpVector:Dot(old.cframe.UpVector) < 1 - BELLY_TURN_SLACK
			or new.cframe.LookVector:Dot(old.cframe.LookVector) < 1 - BELLY_TURN_SLACK
		then
			error(`nothing was changed. The beard rail at x {old.cframe.X} would change its thickness or turn`)
		end
	end
	local stepMoved = BEARD_LOW_RUNG.cframe.Position - BEARD_BELLY_RUNG.cframe.Position
	local stepAlong = stepMoved:Dot(axis)
	local stepSideways = (stepMoved - axis * stepAlong).Magnitude
	if
		math.abs(stepAlong - BELLY_RUNG_STEP) > BELLY_RUNG_STEP_SLACK
		or stepSideways > BELLY_RUNG_STEP_SLACK
		or (BEARD_BELLY_RUNG.size - BEARD_LOW_RUNG.size).Magnitude > SIZE_TOLERANCE
		or BEARD_BELLY_RUNG.cframe.RightVector:Dot(BEARD_LOW_RUNG.cframe.RightVector) < 1 - BELLY_TURN_SLACK
		or BEARD_BELLY_RUNG.cframe.UpVector:Dot(BEARD_LOW_RUNG.cframe.UpVector) < 1 - BELLY_TURN_SLACK
	then
		error(
			string.format(
				"nothing was changed. The extra rung would stand %.3f studs down the line and %.3f sideways from the lowest rung, expected %g and 0 (same size and turn)",
				stepAlong,
				stepSideways,
				BELLY_RUNG_STEP
			)
		)
	end

	-- The live rails (each found by its recorded size and place) and the lowest live rung, whose settings the extra rung copies.
	local liveRails: { Part } = {}
	local taken: { BasePart } = {}
	for _, pair in BEARD_RAIL_BELLY_BEFORE_AFTER do
		local found = liveHeadPart(walk, pair[1], taken)
		if found == nil or not found:IsA("Part") then
			error(`nothing was changed. No beard Rail at {describePlace(pair[1].cframe)} to make longer`)
		end
		table.insert(taken, found)
		table.insert(liveRails, found)
	end
	local template = liveHeadPart(walk, BEARD_LOW_RUNG, {})
	if template == nil or not template:IsA("Part") then
		error("nothing was changed. The lowest beard Rung is not there to copy for the extra rung")
	end

	-- Build the extra rung away from the Workspace and check it.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging2g"
	staging.Archivable = false
	local extra = template:Clone()
	extra.Name = BEARD_BELLY_RUNG.name
	extra.Size = BEARD_BELLY_RUNG.size
	extra.CFrame = BEARD_BELLY_RUNG.cframe
	extra.Parent = staging
	local problems: { string } = {}
	local same, why = sameAs(extra, BEARD_BELLY_RUNG.size, BEARD_BELLY_RUNG.cframe)
	if not same then
		table.insert(problems, `{BEARD_BELLY_RUNG.name}: {why}`)
	end
	local wrong = headSettingsProblem(extra, HEAD_SETTINGS[BEARD_BELLY_RUNG.name])
	if wrong ~= nil then
		table.insert(problems, `{BEARD_BELLY_RUNG.name}: {wrong}`)
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The extra rung is not right: " .. someProblems(problems))
	end

	-- The report's lines for the rails (old place), taken before the change.
	local lines: { string } = {}
	local before: { { [string]: any } } = {}
	for index, rail in liveRails do
		table.insert(before, headPartSnapshot(rail))
		table.insert(
			lines,
			`before: BeardLadder.Rail at x {string.format("%.2f", rail.Position.X)}: {railBellyText(
				rail.Size,
				rail.CFrame
			)}`
		)
		if index == #liveRails then
			table.insert(lines, `before: BeardLadder holds {#beardBox:GetChildren()} children`)
		end
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2g: before")
	end)
	local changed, whyNot = pcall(function()
		for index, rail in liveRails do
			local longer = BEARD_RAIL_BELLY_BEFORE_AFTER[index][2]
			rail.Size = longer.size
			rail.CFrame = longer.cframe
		end
		extra.Parent = beardBox
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2g: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2g: before") and tell code_lead`
		)
	end

	-- Every other value of each rail is as before.
	for index, rail in liveRails do
		local unexpected: { string } = {}
		for _, name in headPartDifferences(before[index], headPartSnapshot(rail)) do
			if not SLOT_MAY_DIFFER[name] then
				table.insert(unexpected, name)
			end
		end
		if #unexpected > 0 then
			error(
				"a rail was changed, but the check afterwards found it differs from before in: "
					.. table.concat(unexpected, ", ")
					.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
			)
		end
		table.insert(
			lines,
			`after: BeardLadder.Rail at x {string.format("%.2f", rail.Position.X)}: {railBellyText(
				rail.Size,
				rail.CFrame
			)}; {countValues(before[index])} values compared before and after: only Size and CFrame differ`
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2J)
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
			BEARD_BELLY_RUNG.name,
			BEARD_BELLY_RUNG.size.X,
			BEARD_BELLY_RUNG.size.Y,
			BEARD_BELLY_RUNG.size.Z,
			describePlace(BEARD_BELLY_RUNG.cframe)
		)
	)
	table.insert(
		lines,
		string.format(
			"BeardLadder now holds %d children (%d recorded head parts in all)",
			#beardBox:GetChildren(),
			#FINAL_HEAD_PARTS_2J
		)
	)
	return table.concat(lines, "\n")
end

return sectionBeardBelly
