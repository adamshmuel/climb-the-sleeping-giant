--!strict

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

type Piece = Shared.Piece
local findPieces = Shared.findPieces
local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local describePlace = Shared.describePlace
local FINAL_HEAD_PARTS_2G = S2bHeadParts.FINAL_HEAD_PARTS_2G
local TRUSS_LONGER_EXTRA = S2bHeadParts.TRUSS_LONGER_EXTRA
local TRUSS_LONGER_TOP_SLACK = S2bHeadParts.TRUSS_LONGER_TOP_SLACK
local PART_B_BACK_BEFORE = S2bHeadParts.PART_B_BACK_BEFORE
local PART_B_BACK_AFTER = S2bHeadParts.PART_B_BACK_AFTER
local PART_B_BACK_MIN = S2bHeadParts.PART_B_BACK_MIN
local PART_B_BACK_MAX = S2bHeadParts.PART_B_BACK_MAX
local HEAD_CHANGES_2F4 = S2bHeadParts.HEAD_CHANGES_2F4
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local headProblems = S2bHeadChecks.headProblems
local someProblems = S2bHeadChecks.someProblems
local countParts = S2bHeadChecks.countParts
local countValues = FitShared.countValues
local trussEnds = FitShared.trussEnds
local CLOSER_PRECISION = FitShared.CLOSER_PRECISION
local CLOSER_PRECISION_SLACK = FitShared.CLOSER_PRECISION_SLACK
local CLOSER_FITS = FitShared.CLOSER_FITS
local SHAPE_PIECES_STAYING = FitShared.SHAPE_PIECES_STAYING
local isTunableAt = FitShared.isTunableAt
local stayingPieceProblem = FitShared.stayingPieceProblem
local SLOT_MAY_DIFFER = FitShared.SLOT_MAY_DIFFER
local headPartSnapshot = FitShared.headPartSnapshot
local headPartDifferences = FitShared.headPartDifferences
local liveHeadPart = FitShared.liveHeadPart
local headPartText = FitShared.headPartText

local function sectionTrussAndPartB(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local byName: { [string]: Piece } = {}
	for _, piece in pieces do
		byName[piece.name] = piece
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(
				problems,
				string.format(
					"%s is %s at CollisionPrecision %.3f, expected Tunable at 1.0 (section 2f2)",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(problems, stayingProblem)
		end
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterProblems = {} -- the world after section 2f6: the same, with the truss's foot swung back
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the same, with the longer beard rails and the extra rung
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: the beard truss is 2 x 2 x 32 and both part B SideRails end at z %.1f (%d recorded head parts)",
			PART_B_BACK_AFTER,
			#FINAL_HEAD_PARTS_2H
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2G)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f3 ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2f4 ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live parts, and the numbers that must hold for what they would become.
	local live: { BasePart } = {}
	local lines: { string } = {}
	for _, pair in HEAD_CHANGES_2F4 do
		local old, new = pair[1], pair[2]
		local found = liveHeadPart(walk, old, live)
		if found == nil then
			error(`nothing was changed. No {old.parent}.{old.name} at {describePlace(old.cframe)} to change`)
		end
		table.insert(live, found)
		if
			old.cframe.LookVector:Dot(new.cframe.LookVector) < 0.99999
			or old.cframe.UpVector:Dot(new.cframe.UpVector) < 0.99999
		then
			error(`nothing was changed. The new {old.parent}.{old.name} would be turned differently`)
		end
		if old.name == "Climb" then
			local oldTop, oldFoot = trussEnds(old.size, old.cframe)
			local newTop, newFoot = trussEnds(new.size, new.cframe)
			if (oldTop - newTop).Magnitude > TRUSS_LONGER_TOP_SLACK then
				error(
					`nothing was changed. The longer truss would move its top end by {(oldTop - newTop).Magnitude} studs`
				)
			end
			if math.abs((oldFoot - newFoot).Magnitude - TRUSS_LONGER_EXTRA) > 0.01 or newFoot.Y >= oldFoot.Y then
				error("nothing was changed. The longer truss's foot is not 2.0 studs further down the same line")
			end
		else
			local oldFront, oldBack = old.cframe.Z - old.size.Z / 2, old.cframe.Z + old.size.Z / 2
			local newFront, newBack = new.cframe.Z - new.size.Z / 2, new.cframe.Z + new.size.Z / 2
			if math.abs(oldFront - newFront) > 0.01 then
				error(
					`nothing was changed. The shorter part B at x {new.cframe.X} would move its front end to z {newFront}`
				)
			end
			if
				math.abs(oldBack - PART_B_BACK_BEFORE) > 0.01
				or newBack < PART_B_BACK_MIN
				or newBack > PART_B_BACK_MAX
			then
				error(
					`nothing was changed. Part B at x {new.cframe.X} would end at z {newBack} (now {oldBack}), needs {PART_B_BACK_MIN} to {PART_B_BACK_MAX}`
				)
			end
			if
				math.abs(old.cframe.X - new.cframe.X) > 0.001
				or math.abs(old.cframe.Y - new.cframe.Y) > 0.001
				or math.abs(old.size.X - new.size.X) > 0.001
				or math.abs(old.size.Y - new.size.Y) > 0.001
			then
				error(`nothing was changed. Part B at x {new.cframe.X} would change in more than its length`)
			end
		end
		table.insert(lines, `before: {old.parent}.{old.name} {headPartText(old.size, old.cframe, old.name == "Climb")}`)
	end

	local before: { { [string]: any } } = {}
	for _, part in live do
		table.insert(before, headPartSnapshot(part))
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f4: before")
	end)
	local changed, whyNot = pcall(function()
		for index, part in live do
			local new = HEAD_CHANGES_2F4[index][2]
			part.Size = new.size
			part.CFrame = new.cframe
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f4: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f4: before") and tell code_lead`
		)
	end
	for index, part in live do
		local unexpected: { string } = {}
		for _, name in headPartDifferences(before[index], headPartSnapshot(part)) do
			if not SLOT_MAY_DIFFER[name] then
				table.insert(unexpected, name)
			end
		end
		if #unexpected > 0 then
			error(
				"a part was changed, but the check afterwards found it differs from before in: "
					.. table.concat(unexpected, ", ")
					.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
			)
		end
		local pair = HEAD_CHANGES_2F4[index]
		table.insert(
			lines,
			`after: {pair[1].parent}.{pair[1].name} {headPartText(part.Size, part.CFrame, pair[1].name == "Climb")}; {countValues(
				before[index]
			)} values compared before and after: only Size and CFrame differ`
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #stillProblems > 0 then
		error(
			"the parts were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		`ForeheadGuard holds {#(walk:FindFirstChild("ForeheadGuard") :: Instance):GetChildren()} children ({countParts(
			FINAL_HEAD_PARTS_2H,
			"ForeheadGuard"
		)} recorded head parts), BeardLadder {#(walk:FindFirstChild("BeardLadder") :: Instance):GetChildren()} ({countParts(
			FINAL_HEAD_PARTS_2H,
			"BeardLadder"
		)} recorded)`
	)
	return table.concat(lines, "\n")
end

return sectionTrussAndPartB
