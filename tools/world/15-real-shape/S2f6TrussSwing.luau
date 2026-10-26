--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2f6: the beard truss's foot swings back toward his beard (stuck safety Task 26, step 26-6a1b, Ruling 12)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

type Piece = Shared.Piece
local findPieces = Shared.findPieces
local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local SIZE_TOLERANCE = Shared.SIZE_TOLERANCE
local describePlace = Shared.describePlace
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local TRUSS_SWING_MIN = S2bHeadChecks.TRUSS_SWING_MIN
local TRUSS_SWING_MAX = S2bHeadChecks.TRUSS_SWING_MAX
local TRUSS_SWING_SLACK = S2bHeadChecks.TRUSS_SWING_SLACK
local TRUSS_SWING_TOP_SLACK = S2bHeadChecks.TRUSS_SWING_TOP_SLACK
local HEAD_CHANGES_2F6 = S2bHeadChecks.HEAD_CHANGES_2F6
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local headProblems = S2bHeadChecks.headProblems
local someProblems = S2bHeadChecks.someProblems
local countValues = FitShared.countValues
local trussEnds = FitShared.trussEnds
local CLOSER_PRECISION = FitShared.CLOSER_PRECISION
local CLOSER_PRECISION_SLACK = FitShared.CLOSER_PRECISION_SLACK
local CLOSER_FITS = FitShared.CLOSER_FITS
local SHAPE_PIECES_STAYING = FitShared.SHAPE_PIECES_STAYING
local isTunableAt = FitShared.isTunableAt
local stayingPieceProblem = FitShared.stayingPieceProblem
local headPartSnapshot = FitShared.headPartSnapshot
local headPartDifferences = FitShared.headPartDifferences
local liveHeadPart = FitShared.liveHeadPart
local headPartText = FitShared.headPartText

-- Why: the climbing truss is 2 studs thick and its centre line runs along the visible rails, so its front face stood 1
-- stud out from the rungs and a walker crossing in front of the ladder's foot was lifted off his cloth (designer: a player
-- may only grab it where he visibly touches the ladder). The numbers are at TRUSS_SWING above. It is invisible.
-- What it does:
--   - It refuses to run in Play.
--   - It checks everything first and changes nothing on any difference: the 3 closer-fit pieces are Tunable at
--     CollisionPrecision 1, the legs and arms are as section 2f5 leaves them, and the head is either section 2f4's (before:
--     the truss 2 x 2 x 32 as it is; the change is made) or the final one (after: the truss's foot swung back by
--     TRUSS_SWING: "already done").
--   - Before the change: the truss's top end stays within 0.05; its foot end moves 0.85 to 1.0 studs along minus its
--     UpVector (and hardly at all along its length); it turns only about its own X axis.
--   - It sets the CFrame of that one part and nothing else (it compares every other value before and after, Size
--     included), with waypoints before and after, and checks the head again.
--   - It prints before and after: size, place, top end, foot and front-bottom edge (the foot plus UpVector times 1).
local TRUSS_HALF_THICKNESS = 1.0 -- studs: half of the truss's 2 stud thickness

local TRUSS_ALONG_SLACK = 0.05 -- studs: the foot may move this far along the truss's length (a turn shortens it a little)

local TRUSS_TURN_SLACK = 0.00001 -- on the dot product of the truss's X axis before and after: the turn is about it

-- One line about the truss: size, place, top end, foot and front-bottom edge.
local function trussSwingText(size: Vector3, cframe: CFrame): string
	local _, foot = trussEnds(size, cframe)
	local frontBottom = foot + cframe.UpVector * TRUSS_HALF_THICKNESS
	return headPartText(size, cframe, true)
		.. string.format("; front-bottom edge y %.3f, z %.3f", frontBottom.Y, frontBottom.Z)
end

local function sectionTrussSwing(): string
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

	local pair = HEAD_CHANGES_2F6[1]
	local old, new = pair[1], pair[2]
	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2I)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the same truss, with the longer beard rails and the extra rung
	end
	if #afterProblems == 0 then
		local swungTruss = liveHeadPart(walk, new, {})
		return "already done: the beard truss's foot is swung back ("
			.. (if swungTruss ~= nil then trussSwingText(swungTruss.Size, swungTruss.CFrame) else "not found")
			.. `; {#FINAL_HEAD_PARTS_2I} recorded head parts)`
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f4 ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2f6 ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live truss, and the numbers that must hold for what it would become.
	local live = liveHeadPart(walk, old, {})
	if live == nil then
		error(`nothing was changed. No BeardLadder.Climb at {describePlace(old.cframe)} to change`)
	end
	if (old.size - new.size).Magnitude > SIZE_TOLERANCE then
		error("nothing was changed. The swung truss would have another size")
	end
	local oldTop, oldFoot = trussEnds(old.size, old.cframe)
	local newTop, newFoot = trussEnds(new.size, new.cframe)
	if (oldTop - newTop).Magnitude > TRUSS_SWING_TOP_SLACK then
		error(`nothing was changed. The swung truss would move its top end by {(oldTop - newTop).Magnitude} studs`)
	end
	local moved = newFoot - oldFoot
	local towardBeard = -moved:Dot(old.cframe.UpVector)
	local alongLength = moved:Dot(old.cframe.LookVector)
	if
		towardBeard < TRUSS_SWING_MIN
		or towardBeard > TRUSS_SWING_MAX + TRUSS_SWING_SLACK
		or math.abs(alongLength) > TRUSS_ALONG_SLACK
	then
		error(
			string.format(
				"nothing was changed. The swung truss's foot would move %.3f studs toward his beard and %.3f along its length; it must move %g to %g and hardly along",
				towardBeard,
				alongLength,
				TRUSS_SWING_MIN,
				TRUSS_SWING_MAX
			)
		)
	end
	if math.abs(new.cframe.RightVector:Dot(old.cframe.RightVector) - 1) > TRUSS_TURN_SLACK then
		error("nothing was changed. The swung truss would turn about another axis than its own X axis")
	end

	local lines: { string } = {
		`before: BeardLadder.Climb {trussSwingText(old.size, old.cframe)}`,
	}
	local before = headPartSnapshot(live)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f6: before")
	end)
	local changed, whyNot = pcall(function()
		live.CFrame = new.cframe
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f6: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f6: before") and tell code_lead`
		)
	end
	local unexpected: { string } = {}
	for _, name in headPartDifferences(before, headPartSnapshot(live)) do
		if name ~= "CFrame" then
			table.insert(unexpected, name)
		end
	end
	if #unexpected > 0 then
		error(
			"the truss was changed, but the check afterwards found it differs from before in: "
				.. table.concat(unexpected, ", ")
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	local liveTop = trussEnds(live.Size, live.CFrame)
	local topMoved = string.format("%.4f", (oldTop - liveTop).Magnitude)
	local footMoved = string.format("%.3f", towardBeard)
	table.insert(
		lines,
		`after: BeardLadder.Climb {trussSwingText(live.Size, live.CFrame)}; the top end moved {topMoved} studs and the foot {footMoved} toward his beard; {countValues(
			before
		)} values compared before and after: only CFrame differs`
	)
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2I)
	if #stillProblems > 0 then
		error(
			"the truss was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		`ForeheadGuard holds {#(walk:FindFirstChild("ForeheadGuard") :: Instance):GetChildren()} children, BeardLadder {#(
			walk:FindFirstChild("BeardLadder") :: Instance
		):GetChildren()} ({#FINAL_HEAD_PARTS_2I} recorded head parts in all)`
	)
	return table.concat(lines, "\n")
end

return sectionTrussSwing
