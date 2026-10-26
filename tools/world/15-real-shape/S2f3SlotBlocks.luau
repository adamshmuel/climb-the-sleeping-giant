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
local sameAs = Shared.sameAs
local SLOT_BLOCK_NAME = S2bHeadParts.SLOT_BLOCK_NAME
local FINAL_HEAD_PARTS_2F = S2bHeadParts.FINAL_HEAD_PARTS_2F
local SLOT_BLOCK_BEFORE_AFTER = S2bHeadParts.SLOT_BLOCK_BEFORE_AFTER
local FINAL_HEAD_PARTS_2G = S2bHeadParts.FINAL_HEAD_PARTS_2G
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local headProblems = S2bHeadChecks.headProblems
local someProblems = S2bHeadChecks.someProblems
local countParts = S2bHeadChecks.countParts
local countValues = FitShared.countValues
local CLOSER_PRECISION = FitShared.CLOSER_PRECISION
local CLOSER_PRECISION_SLACK = FitShared.CLOSER_PRECISION_SLACK
local CLOSER_FITS = FitShared.CLOSER_FITS
local SHAPE_PIECES_STAYING = FitShared.SHAPE_PIECES_STAYING
local isTunableAt = FitShared.isTunableAt
local stayingPieceProblem = FitShared.stayingPieceProblem
local SLOT_MAY_DIFFER = FitShared.SLOT_MAY_DIFFER
local SLOT_COMPARED = FitShared.SLOT_COMPARED
local slotBlockSnapshot = FitShared.slotBlockSnapshot
local slotBottomDepth = FitShared.slotBottomDepth

-- Section 2f3: the slot blocks reach his closer skin (stuck safety Task 26, step 26-4d2, Ruling 7)
-- Why: with his head at CollisionPrecision 1 (section 2f2), a thin 69 degree band of forehead in front of the two
-- LadderSlotBlocks has room for a body (5 spots on his left). Each block grows forward and down to fill it. They are
-- invisible and fill a slot nobody should stand in.
-- What it does:
--   - It refuses to run in Play.
--   - It checks everything first and changes nothing on any difference:
--       the 3 closer-fit pieces are Tunable at CollisionPrecision 1, legs and arms are PreciseConvexDecomposition (the
--       legs may also be Tunable at 1.0 once section 2f5 has run), and
--       the head is either the recorded one with both blocks 1 x 12 x 4 at (+-3.2, 102.5, 1.0) (before: the change is
--       made) or the recorded one with both blocks 1 x 17 x 6 at (+-3.2, 100.0, 0.0) (after: "already done").
--   - Before the change, for each new block: the front face is between z -3.25 and -2.75, and every bottom edge is at
--     least 0.5 studs inside his skin (the top of head_with_beard, measured straight down from the block's top at
--     every 0.1 studs across and 0.25 studs along each edge).
--   - It sets Size and CFrame of the two blocks and nothing else (it compares every other value before and after), with
--     waypoints before and after, and checks the head again.
--   - It prints before and after for each block.
local SLOT_FRONT_Z_FROM = -3.25

local SLOT_FRONT_Z_TO = -2.75

local SLOT_BOTTOM_INSIDE = 0.5

local SLOT_SKIN_PIECE = "head_with_beard"

local function slotBlockDifferences(first: { [string]: any }, second: { [string]: any }): { string }
	local names: { string } = {}
	for _, name in SLOT_COMPARED do
		if first[name] ~= second[name] then
			table.insert(names, name)
		end
	end
	return names
end

local function sectionSlotBlocks(): string
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
	local guardBox = walk:FindFirstChild("ForeheadGuard")
	if guardBox == nil then
		error("World.WalkSurfaces.ForeheadGuard is missing")
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

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2G)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		afterProblems = {} -- the world after section 2f4: the same blocks, with the 32 long truss and the shorter part B
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterProblems = {} -- the world after section 2f6: the same, with the truss's foot swung back
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the same, with the longer beard rails and the extra rung
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: both %s are 1 x 17 x 6 at (+-3.2, 100.0, 0.0) and the head parts (%d recorded) are as recorded",
			SLOT_BLOCK_NAME,
			#FINAL_HEAD_PARTS_2G
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2F)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2f3 ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live blocks, and the checks on what they would become.
	local head = byName[SLOT_SKIN_PIECE].mesh
	local live: { Part } = {}
	local lines: { string } = {}
	for _, pair in SLOT_BLOCK_BEFORE_AFTER do
		local found: Part? = nil
		for _, child in guardBox:GetChildren() do
			if child.Name == SLOT_BLOCK_NAME and child:IsA("Part") and sameAs(child, pair[1].size, pair[1].cframe) then
				if not table.find(live, child) then
					found = child
					break
				end
			end
		end
		if found == nil then
			error(`nothing was changed. No {SLOT_BLOCK_NAME} at {describePlace(pair[1].cframe)} to make bigger`)
		end
		table.insert(live, found)
		local wide = pair[2]
		local frontZ = wide.cframe.Z - wide.size.Z / 2
		if frontZ < SLOT_FRONT_Z_FROM or frontZ > SLOT_FRONT_Z_TO then
			error(`nothing was changed. The front face of the block at x {wide.cframe.X} would be at z {frontZ}`)
		end
		local depth, where = slotBottomDepth(head, wide)
		table.insert(
			lines,
			string.format(
				"block at x %+.1f: front face z %.2f -> %.2f; bottom y %.2f -> %.2f; its bottom edges sit at least %.2f studs inside his skin (worst at %s)",
				wide.cframe.X,
				pair[1].cframe.Z - pair[1].size.Z / 2,
				frontZ,
				pair[1].cframe.Y - pair[1].size.Y / 2,
				wide.cframe.Y - wide.size.Y / 2,
				depth,
				where
			)
		)
		if depth < SLOT_BOTTOM_INSIDE then
			error(
				string.format(
					"nothing was changed. The bottom edge of the block at x %+.1f would be only %.2f studs inside his skin (worst at %s), needs %.1f",
					wide.cframe.X,
					depth,
					where,
					SLOT_BOTTOM_INSIDE
				)
			)
		end
	end

	local before: { { [string]: any } } = {}
	for _, block in live do
		table.insert(before, slotBlockSnapshot(block))
		local old = block
		table.insert(
			lines,
			string.format(
				"before: %s x %+.1f is %.1f x %.1f x %.1f at %s",
				SLOT_BLOCK_NAME,
				old.Position.X,
				old.Size.X,
				old.Size.Y,
				old.Size.Z,
				describePlace(old.CFrame)
			)
		)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f3: before")
	end)
	local changed, whyNot = pcall(function()
		for index, block in live do
			local wide = SLOT_BLOCK_BEFORE_AFTER[index][2]
			block.Size = wide.size
			block.CFrame = wide.cframe
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f3: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f3: before") and tell code_lead`
		)
	end
	for index, block in live do
		local unexpected: { string } = {}
		for _, name in slotBlockDifferences(before[index], slotBlockSnapshot(block)) do
			if not SLOT_MAY_DIFFER[name] then
				table.insert(unexpected, name)
			end
		end
		if #unexpected > 0 then
			error(
				"a block was changed, but the check afterwards found it differs from before in: "
					.. table.concat(unexpected, ", ")
					.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
			)
		end
		table.insert(
			lines,
			string.format(
				"after: %s x %+.1f is %.1f x %.1f x %.1f at %s; %d values compared before and after: only Size and CFrame differ",
				SLOT_BLOCK_NAME,
				block.Position.X,
				block.Size.X,
				block.Size.Y,
				block.Size.Z,
				describePlace(block.CFrame),
				countValues(before[index])
			)
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2G)
	if #stillProblems > 0 then
		error(
			"the blocks were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		`ForeheadGuard now holds {#guardBox:GetChildren()} children ({countParts(FINAL_HEAD_PARTS_2G, "ForeheadGuard")} recorded head parts)`
	)
	return table.concat(lines, "\n")
end

return sectionSlotBlocks
