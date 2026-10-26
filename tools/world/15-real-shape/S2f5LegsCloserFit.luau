--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2f5: the legs' closer fit (stuck safety Task 26, step 26-4f, Ruling 9)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = require(script.Parent.Shared)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

local RECORDS = Shared.RECORDS
local MAX_WAIT = Shared.MAX_WAIT
local readRays = Shared.readRays
type Piece = Shared.Piece
local findPieces = Shared.findPieces
local waitForShapes = Shared.waitForShapes
local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local someProblems = S2bHeadChecks.someProblems
local bodySnapshot = FitShared.bodySnapshot
local bodyDifferences = FitShared.bodyDifferences
local unexpectedDifferences = FitShared.unexpectedDifferences
local countValues = FitShared.countValues
local CLOSER_PRECISION = FitShared.CLOSER_PRECISION
local CLOSER_PRECISION_SLACK = FitShared.CLOSER_PRECISION_SLACK
local LEGS_PIECE = FitShared.LEGS_PIECE
local pointRays = FitShared.pointRays
local hitHeight = FitShared.hitHeight
local pointsText = FitShared.pointsText
local heightText = FitShared.heightText
local waitForSourceShape = FitShared.waitForSourceShape
local isTunableAt = FitShared.isTunableAt
local LEGS_FIT = FitShared.LEGS_FIT
local restOfHisBodyProblems = FitShared.restOfHisBodyProblems

-- Why: after the closer fit on his belly, head and nightcap (section 2f2) one spot on his right knee is still too far over
-- his drawn skin (check 6: +0.33 at (24.5, 27.7, -40.5)). code_lead measured on 2026-10-21 that legs_and_boots made with
-- AssetService:CreateMeshPartAsync as Tunable at CollisionPrecision 1 has no such spot, and the ray at (24.5, -40.5) goes
-- from 27.66 to 27.34. It is built like section 2f2, for one piece. It knows three worlds, and changes nothing on any
-- difference:
--   (a) before: legs_and_boots is PreciseConvexDecomposition; the belly, head and nightcap are Tunable at 1.0 (+-0.01); both
--       arms are PreciseConvexDecomposition; the head parts are the final ones of section 2f4 (truss 32 long). The change
--       is made.
--   (b) after: legs_and_boots is Tunable at 1.0 (+-0.01) with the same other pieces and head. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- The change: away from the Workspace (a WorldModel in ServerStorage, destroyed at the end whatever happens) it makes the
-- legs with CreateMeshPartAsync (Tunable, the piece's Render- and FluidFidelity) at the piece's size and place, reads the
-- ray at the named point (24.5, -40.5) until steady, sets CollisionPrecision 1 and waits until that ray moves and is
-- steady again (up to MAX_WAIT seconds, then it stops with nothing changed). Dry run: ApplyMesh onto a clone, TextureID put
-- back, the same 28 values as in 2f2 compared (only CollisionFidelity and CollisionPrecision may differ), the clone must be
-- Tunable at 1.0. Only then, between two ChangeHistoryService waypoints: ApplyMesh onto the live legs, TextureID put back,
-- the same check on the live piece, and a wait until Roblox has worked out the new shape (the fixed rays of section 1 plus
-- the named point; the legs' rays must have moved).
local LEGS_STAGING_NAME = "Task26Staging2f5"

-- The dry run, then the change, then the wait. Everything it makes lives in `staging`, which the caller destroys.
local function changeLegsToCloserFit(
	staging: WorldModel,
	pieces: { Piece },
	byName: { [string]: Piece },
	walk: Instance
): string
	local lines: { string } = {}
	local piece = byName[LEGS_PIECE]
	local mesh = piece.mesh
	local made, madeOrWhy = pcall(function(): MeshPart
		return AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
			CollisionFidelity = Enum.CollisionFidelity.Tunable,
			RenderFidelity = mesh.RenderFidelity,
			FluidFidelity = mesh.FluidFidelity,
		})
	end)
	if not made then
		error(`nothing was changed. CreateMeshPartAsync failed for {LEGS_PIECE}: {tostring(madeOrWhy)}`)
	end
	local source = madeOrWhy :: MeshPart
	source.Anchored = true
	source.Size = mesh.Size
	source.CFrame = mesh.CFrame
	source.Parent = staging

	local rays = pointRays(RECORDS[LEGS_PIECE], LEGS_FIT.points)
	local baselineSteady, _, _, baseline = waitForSourceShape(staging, source, rays, nil)
	if not baselineSteady then
		error(
			`nothing was changed. The copy of {LEGS_PIECE} never settled at its first precision within {MAX_WAIT} seconds`
		)
	end
	(source :: any).CollisionPrecision = CLOSER_PRECISION
	local moved, sourceSeconds, sourceMove = waitForSourceShape(staging, source, rays, baseline)
	if not moved then
		error(
			string.format(
				"nothing was changed. The copy of %s did not change its shape within %d seconds of CollisionPrecision 1 (largest ray move %.3f studs)",
				LEGS_PIECE,
				MAX_WAIT,
				sourceMove
			)
		)
	end

	-- Dry run on a clone.
	local trial = mesh:Clone()
	trial.Parent = staging
	local wiped = false
	local trialOk, trialWhy = pcall(function()
		trial:ApplyMesh(source)
		wiped = trial.TextureID ~= LEGS_FIT.textureId
		trial.TextureID = LEGS_FIT.textureId
	end)
	if not trialOk then
		error(`nothing was changed. ApplyMesh failed on the clone of {LEGS_PIECE}: {tostring(trialWhy)}`)
	end
	local before = bodySnapshot(mesh)
	local trialDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(trial)))
	if #trialDifferences > 0 then
		error(
			`nothing was changed. ApplyMesh on the clone of {LEGS_PIECE} changed more than the collision: {table.concat(
				trialDifferences,
				", "
			)}`
		)
	end
	if not isTunableAt(trial, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		error(
			string.format(
				"nothing was changed. The clone of %s is %s at CollisionPrecision %.3f, expected Tunable at 1.0",
				LEGS_PIECE,
				trial.CollisionFidelity.Name,
				trial.CollisionPrecision
			)
		)
	end
	trial:Destroy()
	local oldFidelity = mesh.CollisionFidelity.Name
	local oldPrecision = mesh.CollisionPrecision

	-- The rays read before the change: section 1's fixed rays and the named point, on all six pieces.
	piece.changing = true
	local firstPointRay = #piece.rays + 1
	for _, ray in pointRays(RECORDS[LEGS_PIECE], LEGS_FIT.points) do
		table.insert(piece.rays, ray)
	end
	for _, each in pieces do
		each.before = readRays(each.mesh, each.rays)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f5: before")
	end)
	local changed, whyNot = pcall(function()
		mesh:ApplyMesh(source)
		mesh.TextureID = LEGS_FIT.textureId
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f5: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f5: before") and tell code_lead`
		)
	end

	-- The same check on the live piece, and what must not have moved.
	local differences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(mesh)))
	if #differences > 0 or not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		error(
			string.format(
				"%s was changed, but the check afterwards found it is %s at CollisionPrecision %.3f and differs from before in: %s. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead",
				LEGS_PIECE,
				mesh.CollisionFidelity.Name,
				mesh.CollisionPrecision,
				table.concat(differences, ", ")
			)
		)
	end
	table.insert(
		lines,
		string.format(
			"%s: CollisionFidelity %s -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after: only CollisionFidelity and CollisionPrecision differ. The staging copy's ray at %s moved %.2f studs after CollisionPrecision 1 (steady after %.1f seconds)",
			mesh:GetFullName(),
			oldFidelity,
			oldPrecision,
			mesh.CollisionPrecision,
			if wiped then "wiped" else "did not wipe",
			mesh.TextureID,
			countValues(before),
			pointsText(LEGS_FIT.points),
			sourceMove,
			sourceSeconds
		)
	)
	local stillProblems = restOfHisBodyProblems(byName, walk)
	if #stillProblems > 0 then
		error(
			"the legs were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		"the belly, head and nightcap stay Tunable at 1.0, left_arm and right_arm stay PreciseConvexDecomposition, the head parts are as recorded"
	)

	-- Wait until Roblox has worked out the new shape: the legs' rays must have moved.
	local steady, seconds, moves = waitForShapes(pieces)
	local now = readRays(mesh, piece.rays)
	for offset, point in LEGS_FIT.points do
		local index = firstPointRay + offset - 1
		local ray = piece.rays[index]
		table.insert(
			lines,
			`{LEGS_PIECE} at ({point.X}, {point.Y}): the live piece's top was {heightText(
				hitHeight(ray, piece.before[index])
			)}, is {heightText(hitHeight(ray, now[index]))}`
		)
	end
	table.insert(
		lines,
		string.format("%s: largest ray move from before the change %.2f studs", LEGS_PIECE, moves[LEGS_PIECE])
	)
	if steady then
		table.insert(
			lines,
			string.format("Roblox worked out the shape: the rays were steady after %.1f seconds of waiting", seconds)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shape was not steady yet, or the legs' rays did not move. Run the script again to wait further, and if it is the same, STOP and tell code_lead",
				seconds
			)
		)
	end
	return table.concat(lines, "\n")
end

local function sectionLegsCloserFit(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
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

	-- What never changes: the legs' mesh and texture as recorded, and the rest of his body as after sections 2f2 to 2f4.
	local legs = byName[LEGS_PIECE].mesh
	local problems: { string } = {}
	if legs.MeshId ~= LEGS_FIT.meshId then
		table.insert(problems, `{LEGS_PIECE}: MeshId is {legs.MeshId}, recorded {LEGS_FIT.meshId}`)
	end
	if legs.TextureID ~= LEGS_FIT.textureId then
		table.insert(problems, `{LEGS_PIECE}: TextureID is {legs.TextureID}, recorded {LEGS_FIT.textureId}`)
	end
	for _, problem in restOfHisBodyProblems(byName, walk) do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	-- Which world is it?
	if isTunableAt(legs, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		return string.format(
			"already done: %s is Tunable at CollisionPrecision %.2f with its mesh and texture as recorded, the belly, head and nightcap are Tunable at 1.0, left_arm and right_arm are PreciseConvexDecomposition, and the head parts (%d recorded, truss 32 long) are as recorded",
			LEGS_PIECE,
			legs.CollisionPrecision,
			#FINAL_HEAD_PARTS_2H
		)
	end
	if legs.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
		error(
			string.format(
				"nothing was changed. %s is %s at CollisionPrecision %.3f: neither the world before section 2f5 (PreciseConvexDecomposition) nor the world after it (Tunable at 1.0)",
				LEGS_PIECE,
				legs.CollisionFidelity.Name,
				legs.CollisionPrecision
			)
		)
	end

	-- The staging WorldModel: a leftover from a stopped run goes first, and it is destroyed whatever happens.
	local leftover = ServerStorage:FindFirstChild(LEGS_STAGING_NAME)
	if leftover ~= nil then
		leftover:Destroy()
	end
	local staging = Instance.new("WorldModel")
	staging.Name = LEGS_STAGING_NAME
	staging.Archivable = false
	staging.Parent = ServerStorage
	local ok, result = pcall(changeLegsToCloserFit, staging, pieces, byName, walk)
	staging:Destroy()
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

return sectionLegsCloserFit
