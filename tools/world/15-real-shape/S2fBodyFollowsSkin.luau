--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2f: his body follows his skin (stuck safety Task 26, step 26-2)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

local BODY_PIECE = Shared.BODY_PIECE
local CLOSER_FIT_PIECES = Shared.CLOSER_FIT_PIECES
local readRays = Shared.readRays
type Piece = Shared.Piece
local findPieces = Shared.findPieces
local waitForShapes = Shared.waitForShapes
local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local describePlace = Shared.describePlace
local sameAs = Shared.sameAs
local FINAL_HEAD_PARTS_2E = S2bHeadParts.FINAL_HEAD_PARTS_2E
local BEARD_TRUSS_EXTRA = S2bHeadParts.BEARD_TRUSS_EXTRA
local BEARD_TRUSS_TOP_SLACK = S2bHeadParts.BEARD_TRUSS_TOP_SLACK
local BEARD_TRUSS_BEFORE_AFTER = S2bHeadParts.BEARD_TRUSS_BEFORE_AFTER
local FINAL_HEAD_PARTS_2F = S2bHeadParts.FINAL_HEAD_PARTS_2F
local headProblems = S2bHeadChecks.headProblems
local headProblemsEitherSlot = S2bHeadChecks.headProblemsEitherSlot
local someProblems = S2bHeadChecks.someProblems
local BODY_MESH_ID = FitShared.BODY_MESH_ID
local BODY_TEXTURE_ID = FitShared.BODY_TEXTURE_ID
local BODY_TUNABLE_PRECISION = FitShared.BODY_TUNABLE_PRECISION
local BODY_PRECISION_SLACK = FitShared.BODY_PRECISION_SLACK
local bodySnapshot = FitShared.bodySnapshot
local bodyDifferences = FitShared.bodyDifferences
local unexpectedDifferences = FitShared.unexpectedDifferences
local countValues = FitShared.countValues
local trussEnds = FitShared.trussEnds

local function sectionBodyFollowsSkin(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local found: Piece? = nil
	for _, piece in pieces do
		if piece.name == BODY_PIECE then
			found = piece
		end
	end
	if found == nil then
		error(`nothing was changed. {BODY_PIECE} is missing`)
	end
	local body: Piece = found
	local mesh = body.mesh
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local beardBox = walk:FindFirstChild("BeardLadder")
	if beardBox == nil then
		error("World.WalkSurfaces.BeardLadder is missing")
	end

	-- What never changes: the mesh and the texture as recorded, and the other five pieces on PreciseConvexDecomposition
	-- (the head, the nightcap and the legs may already be Tunable once sections 2f2 and 2f5 have run).
	local problems: { string } = {}
	local headOrCapTunable = false
	if mesh.MeshId ~= BODY_MESH_ID then
		table.insert(problems, `{BODY_PIECE}: MeshId is {mesh.MeshId}, recorded {BODY_MESH_ID}`)
	end
	if mesh.TextureID ~= BODY_TEXTURE_ID then
		table.insert(problems, `{BODY_PIECE}: TextureID is {mesh.TextureID}, recorded {BODY_TEXTURE_ID}`)
	end
	for _, piece in pieces do
		if piece.name ~= BODY_PIECE then
			local pieceFidelity = piece.mesh.CollisionFidelity
			if CLOSER_FIT_PIECES[piece.name] and pieceFidelity == Enum.CollisionFidelity.Tunable then
				headOrCapTunable = true
			elseif pieceFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
				table.insert(
					problems,
					`{piece.name}: CollisionFidelity is {pieceFidelity.Name}, expected PreciseConvexDecomposition`
				)
			end
		end
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	local trussPair = BEARD_TRUSS_BEFORE_AFTER[1]
	local fidelity = mesh.CollisionFidelity
	local afterProblems = headProblemsEitherSlot(walk)
	-- The Tunable body is at 0.36 (after 2f) or at 1.0 (after the closer fit, section 2f2): both count as done here.
	local bodyPrecision = mesh.CollisionPrecision
	local bodyPrecisionKnown = math.abs(bodyPrecision - BODY_TUNABLE_PRECISION) <= BODY_PRECISION_SLACK
		or math.abs(bodyPrecision - 1) <= 0.01
	if fidelity == Enum.CollisionFidelity.Tunable and bodyPrecisionKnown and #afterProblems == 0 then
		return string.format(
			"already done: %s is Tunable (collision precision %.2f) with its mesh and texture as recorded, the other five pieces are PreciseConvexDecomposition (or Tunable for the head, the nightcap and the legs after sections 2f2 and 2f5), and the beard truss is %.0f long, or 32 after section 2f4 (%d recorded head parts)",
			BODY_PIECE,
			mesh.CollisionPrecision,
			trussPair[2].size.Z,
			#FINAL_HEAD_PARTS_2F
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2E)
	if fidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition or headOrCapTunable or #beforeProblems > 0 then
		error(
			`nothing was changed. His body and head are neither the world after section 2e ({BODY_PIECE} {fidelity.Name} at {string.format(
				"%.2f",
				bodyPrecision
			)}, head or nightcap Tunable: {headOrCapTunable}, head: {someProblems(beforeProblems)}) nor the world after 2f (head: {someProblems(
				afterProblems
			)})`
		)
	end

	-- The live truss, and the numbers that must hold for the longer one: top end stays, bottom end moves BEARD_TRUSS_EXTRA.
	local truss: TrussPart? = nil
	for _, child in beardBox:GetChildren() do
		if
			child.Name == "Climb"
			and child:IsA("TrussPart")
			and sameAs(child, trussPair[1].size, trussPair[1].cframe)
		then
			truss = child
			break
		end
	end
	if truss == nil then
		error("nothing was changed. No beard Climb truss as recorded to make longer")
	end
	local oldTop, oldBottom = trussEnds(trussPair[1].size, trussPair[1].cframe)
	local newTop, newBottom = trussEnds(trussPair[2].size, trussPair[2].cframe)
	if (oldTop - newTop).Magnitude > BEARD_TRUSS_TOP_SLACK then
		error(`nothing was changed. The longer truss would move its top end by {(oldTop - newTop).Magnitude} studs`)
	end
	if math.abs((oldBottom - newBottom).Magnitude - BEARD_TRUSS_EXTRA) > 0.01 or newBottom.Y >= oldBottom.Y then
		error("nothing was changed. The longer truss's bottom end is not 2.0 studs further down the same line")
	end

	-- Dry run: ApplyMesh on a clone, away from the Workspace. Nothing in the world changes if it is not right.
	local staging = Instance.new("Folder")
	staging.Name = "Task26Staging2f"
	staging.Archivable = false
	local made, madeOrWhy = pcall(function(): MeshPart
		return AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
			CollisionFidelity = Enum.CollisionFidelity.Tunable,
			RenderFidelity = mesh.RenderFidelity,
			FluidFidelity = mesh.FluidFidelity,
		})
	end)
	if not made then
		staging:Destroy()
		error("nothing was changed. CreateMeshPartAsync failed: " .. tostring(madeOrWhy))
	end
	local source = madeOrWhy :: MeshPart
	source.Parent = staging
	local trial = mesh:Clone()
	trial.Parent = staging
	local wiped = false
	local trialOk, trialWhy = pcall(function()
		trial:ApplyMesh(source)
		wiped = trial.TextureID ~= BODY_TEXTURE_ID
		trial.TextureID = BODY_TEXTURE_ID
	end)
	local before = bodySnapshot(mesh)
	local trialSnapshot = bodySnapshot(trial)
	local trialPrecision = trial.CollisionPrecision
	local trialFidelity = trial.CollisionFidelity
	if not trialOk then
		staging:Destroy()
		error("nothing was changed. ApplyMesh failed on the clone: " .. tostring(trialWhy))
	end
	local trialDifferences = unexpectedDifferences(bodyDifferences(before, trialSnapshot))
	if #trialDifferences > 0 then
		staging:Destroy()
		error(
			"nothing was changed. ApplyMesh on the clone changed more than the collision: "
				.. table.concat(trialDifferences, ", ")
		)
	end
	if trialFidelity ~= Enum.CollisionFidelity.Tunable then
		staging:Destroy()
		error(`nothing was changed. The clone's CollisionFidelity is {trialFidelity.Name}, expected Tunable`)
	end
	if math.abs(trialPrecision - BODY_TUNABLE_PRECISION) > BODY_PRECISION_SLACK then
		staging:Destroy()
		error(
			string.format(
				"nothing was changed. The clone's CollisionPrecision is %.3f, step 6b-1f measured %.2f",
				trialPrecision,
				BODY_TUNABLE_PRECISION
			)
		)
	end

	-- The report's lines, and the rays read before the change.
	local lines: { string } = {}
	local oldPrecision = mesh.CollisionPrecision
	for _, piece in pieces do
		piece.changing = piece.name == BODY_PIECE
		piece.before = readRays(piece.mesh, piece.rays)
	end
	table.insert(
		lines,
		string.format(
			"beard Climb truss: %.0f x %.0f x %.0f at %s -> %.0f x %.0f x %.0f at %s; top end moved %.3f studs; foot (bottom end) %s -> %s, %.2f studs lower",
			trussPair[1].size.X,
			trussPair[1].size.Y,
			trussPair[1].size.Z,
			describePlace(trussPair[1].cframe),
			trussPair[2].size.X,
			trussPair[2].size.Y,
			trussPair[2].size.Z,
			describePlace(trussPair[2].cframe),
			(oldTop - newTop).Magnitude,
			describePlace(CFrame.new(oldBottom)),
			describePlace(CFrame.new(newBottom)),
			oldBottom.Y - newBottom.Y
		)
	)

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f: before")
	end)
	local changed, whyNot = pcall(function()
		mesh:ApplyMesh(source)
		mesh.TextureID = BODY_TEXTURE_ID
		truss.Size = trussPair[2].size
		truss.CFrame = trussPair[2].cframe
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f: before") and tell code_lead`
		)
	end

	-- Check the result the same way as the clone, and the head against the recorded final head.
	local afterDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(mesh)))
	if #afterDifferences > 0 or mesh.CollisionFidelity ~= Enum.CollisionFidelity.Tunable then
		error(
			"the body was changed, but the check afterwards found it differs from before in: "
				.. table.concat(afterDifferences, ", ")
				.. `; CollisionFidelity is {mesh.CollisionFidelity.Name}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2F)
	if #stillProblems > 0 then
		error(
			"the truss was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		string.format(
			"%s: CollisionFidelity PreciseConvexDecomposition -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after (size, place, turn, material, color, collision group and flags, mesh, texture, fidelities, children, attributes): only CollisionFidelity and CollisionPrecision differ",
			mesh:GetFullName(),
			oldPrecision,
			mesh.CollisionPrecision,
			if wiped then "wiped" else "did not wipe",
			mesh.TextureID,
			countValues(before)
		)
	)
	table.insert(
		lines,
		"legs_and_boots, left_arm, right_arm, head_with_beard and nightcap stay PreciseConvexDecomposition"
	)

	-- Wait until Roblox has worked out the new shape (the body's rays must have moved).
	local steady, seconds, moves = waitForShapes(pieces)
	if steady then
		table.insert(
			lines,
			string.format(
				"Roblox worked out the shape: the rays were steady after %.1f seconds of waiting; the body's largest ray move is %.2f studs",
				seconds,
				moves[BODY_PIECE]
			)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shape was not steady yet (the body's largest ray move is %.2f studs). Run the script again to wait further",
				seconds,
				moves[BODY_PIECE]
			)
		)
	end
	return table.concat(lines, "\n")
end

return sectionBodyFollowsSkin
