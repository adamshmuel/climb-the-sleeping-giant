--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2f2: a closer fit (stuck safety Task 26, step 26-4b)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

local BODY_PIECE = Shared.BODY_PIECE
local RECORDS = Shared.RECORDS
local MAX_WAIT = Shared.MAX_WAIT
local readRays = Shared.readRays
type Piece = Shared.Piece
local findPieces = Shared.findPieces
local waitForShapes = Shared.waitForShapes
local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local FINAL_HEAD_PARTS_2F = S2bHeadParts.FINAL_HEAD_PARTS_2F
local headProblemsEitherSlot = S2bHeadChecks.headProblemsEitherSlot
local someProblems = S2bHeadChecks.someProblems
local BODY_TUNABLE_PRECISION = FitShared.BODY_TUNABLE_PRECISION
local BODY_PRECISION_SLACK = FitShared.BODY_PRECISION_SLACK
local bodySnapshot = FitShared.bodySnapshot
local bodyDifferences = FitShared.bodyDifferences
local unexpectedDifferences = FitShared.unexpectedDifferences
local countValues = FitShared.countValues
local CLOSER_PRECISION = FitShared.CLOSER_PRECISION
local CLOSER_PRECISION_SLACK = FitShared.CLOSER_PRECISION_SLACK
type CloserFit = FitShared.CloserFit
local CLOSER_FITS = FitShared.CLOSER_FITS
local SHAPE_PIECES_STAYING = FitShared.SHAPE_PIECES_STAYING
local pointRays = FitShared.pointRays
local hitHeight = FitShared.hitHeight
local pointsText = FitShared.pointsText
local heightText = FitShared.heightText
local waitForSourceShape = FitShared.waitForSourceShape
local isTunableAt = FitShared.isTunableAt
local stayingPieceProblem = FitShared.stayingPieceProblem

local STAGING_NAME = "Task26Staging2f2"

type Prepared = {
	fit: CloserFit,
	piece: Piece,
	source: MeshPart,
	before: { [string]: any },
	oldFidelity: string,
	oldPrecision: number,
	wiped: boolean,
	sourceMove: number,
	sourceSeconds: number,
	firstPointRay: number,
}

-- The dry runs, then the change, then the wait. Everything it makes lives in `staging`, which the caller destroys.
local function changeToCloserFit(
	staging: WorldModel,
	pieces: { Piece },
	byName: { [string]: Piece },
	walk: Instance
): string
	local lines: { string } = {}
	local prepared: { Prepared } = {}
	for _, fit in CLOSER_FITS do
		local piece = byName[fit.name]
		local mesh = piece.mesh
		local made, madeOrWhy = pcall(function(): MeshPart
			return AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
				CollisionFidelity = Enum.CollisionFidelity.Tunable,
				RenderFidelity = mesh.RenderFidelity,
				FluidFidelity = mesh.FluidFidelity,
			})
		end)
		if not made then
			error(`nothing was changed. CreateMeshPartAsync failed for {fit.name}: {tostring(madeOrWhy)}`)
		end
		local source = madeOrWhy :: MeshPart
		source.Anchored = true
		source.Size = mesh.Size
		source.CFrame = mesh.CFrame
		source.Parent = staging

		local rays = pointRays(RECORDS[fit.name], fit.points)
		local baselineSteady, _, _, baseline = waitForSourceShape(staging, source, rays, nil)
		if not baselineSteady then
			error(
				`nothing was changed. The copy of {fit.name} never settled at its first precision within {MAX_WAIT} seconds`
			)
		end
		(source :: any).CollisionPrecision = CLOSER_PRECISION
		local moved, seconds, movedBy = waitForSourceShape(staging, source, rays, baseline)
		if not moved then
			error(
				string.format(
					"nothing was changed. The copy of %s did not change its shape within %d seconds of CollisionPrecision 1 (largest ray move %.3f studs)",
					fit.name,
					MAX_WAIT,
					movedBy
				)
			)
		end

		-- Dry run on a clone.
		local trial = mesh:Clone()
		trial.Parent = staging
		local wiped = false
		local trialOk, trialWhy = pcall(function()
			trial:ApplyMesh(source)
			wiped = trial.TextureID ~= fit.textureId
			trial.TextureID = fit.textureId
		end)
		if not trialOk then
			error(`nothing was changed. ApplyMesh failed on the clone of {fit.name}: {tostring(trialWhy)}`)
		end
		local before = bodySnapshot(mesh)
		local trialDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(trial)))
		if #trialDifferences > 0 then
			error(
				`nothing was changed. ApplyMesh on the clone of {fit.name} changed more than the collision: {table.concat(
					trialDifferences,
					", "
				)}`
			)
		end
		if not isTunableAt(trial, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			error(
				string.format(
					"nothing was changed. The clone of %s is %s at CollisionPrecision %.3f, expected Tunable at 1.0",
					fit.name,
					trial.CollisionFidelity.Name,
					trial.CollisionPrecision
				)
			)
		end
		trial:Destroy()
		table.insert(prepared, {
			fit = fit,
			piece = piece,
			source = source,
			before = before,
			oldFidelity = mesh.CollisionFidelity.Name,
			oldPrecision = mesh.CollisionPrecision,
			wiped = wiped,
			sourceMove = movedBy,
			sourceSeconds = seconds,
			firstPointRay = 0,
		})
	end

	-- The rays read before the change: section 1's fixed rays and the named points, on all six pieces.
	for _, item in prepared do
		item.piece.changing = true
		item.firstPointRay = #item.piece.rays + 1
		for _, ray in pointRays(RECORDS[item.fit.name], item.fit.points) do
			table.insert(item.piece.rays, ray)
		end
	end
	for _, piece in pieces do
		piece.before = readRays(piece.mesh, piece.rays)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f2: before")
	end)
	local changed, whyNot = pcall(function()
		for _, item in prepared do
			item.piece.mesh:ApplyMesh(item.source)
			item.piece.mesh.TextureID = item.fit.textureId
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f2: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f2: before") and tell code_lead`
		)
	end

	-- The same check on the live pieces, and what must not have moved.
	for _, item in prepared do
		local mesh = item.piece.mesh
		local differences = unexpectedDifferences(bodyDifferences(item.before, bodySnapshot(mesh)))
		if #differences > 0 or not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			error(
				string.format(
					"%s was changed, but the check afterwards found it is %s at CollisionPrecision %.3f and differs from before in: %s. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead",
					item.fit.name,
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
				item.oldFidelity,
				item.oldPrecision,
				mesh.CollisionPrecision,
				if item.wiped then "wiped" else "did not wipe",
				mesh.TextureID,
				countValues(item.before),
				pointsText(item.fit.points),
				item.sourceMove,
				item.sourceSeconds
			)
		)
	end
	local stillProblems = headProblemsEitherSlot(walk)
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(stillProblems, stayingProblem)
		end
	end
	if #stillProblems > 0 then
		error(
			"the pieces were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(lines, "legs_and_boots, left_arm and right_arm stay PreciseConvexDecomposition")

	-- Wait until Roblox has worked out the new shapes: every changed piece's rays must have moved.
	local steady, seconds, moves = waitForShapes(pieces)
	for _, item in prepared do
		local name = item.fit.name
		local now = readRays(item.piece.mesh, item.piece.rays)
		for offset, point in item.fit.points do
			local index = item.firstPointRay + offset - 1
			local ray = item.piece.rays[index]
			table.insert(
				lines,
				`{name} at ({point.X}, {point.Y}): the live piece's top was {heightText(
					hitHeight(ray, item.piece.before[index])
				)}, is {heightText(hitHeight(ray, now[index]))}`
			)
		end
		table.insert(lines, string.format("%s: largest ray move from before the change %.2f studs", name, moves[name]))
	end
	if steady then
		table.insert(
			lines,
			string.format("Roblox worked out the shapes: the rays were steady after %.1f seconds of waiting", seconds)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shapes were not steady yet, or a changed piece's rays did not move. Run the script again to wait further, and if it is the same, STOP and tell code_lead",
				seconds
			)
		)
	end
	return table.concat(lines, "\n")
end

local function sectionCloserFit(): string
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

	-- What never changes: each mesh and texture as recorded, the three staying pieces, the head parts and the 30 long truss.
	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if mesh.MeshId ~= fit.meshId then
			table.insert(problems, `{fit.name}: MeshId is {mesh.MeshId}, recorded {fit.meshId}`)
		end
		if mesh.TextureID ~= fit.textureId then
			table.insert(problems, `{fit.name}: TextureID is {mesh.TextureID}, recorded {fit.textureId}`)
		end
	end
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(problems, stayingProblem)
		end
	end
	for _, problem in headProblemsEitherSlot(walk) do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	-- Which world is it?
	local done: { string } = {}
	local notDone: { string } = {}
	local unknown: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		local isBefore = if fit.name == BODY_PIECE
			then isTunableAt(mesh, BODY_TUNABLE_PRECISION, BODY_PRECISION_SLACK)
			else mesh.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition
		if isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(done, fit.name)
		elseif isBefore then
			table.insert(notDone, fit.name)
		else
			table.insert(
				unknown,
				string.format(
					"%s is %s at CollisionPrecision %.3f",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	if #unknown > 0 or (#done > 0 and #notDone > 0) then
		error(
			`nothing was changed. His body pieces are neither the world after section 2f nor the world after 2f2 (done: {table.concat(
				done,
				", "
			)}; not done: {table.concat(notDone, ", ")}; unknown: {table.concat(unknown, "; ")})`
		)
	end
	if #done == #CLOSER_FITS then
		return string.format(
			"already done: %s are Tunable at CollisionPrecision %.2f, with their mesh and texture as recorded, left_arm and right_arm are PreciseConvexDecomposition (so is legs_and_boots, until section 2f5 makes it Tunable at 1.0), and the head parts (%d recorded, with the 30 long beard truss, or 32 after section 2f4) are as recorded",
			table.concat(done, ", "),
			CLOSER_PRECISION,
			#FINAL_HEAD_PARTS_2F
		)
	end

	-- The staging WorldModel: a leftover from a stopped run goes first, and it is destroyed whatever happens.
	local leftover = ServerStorage:FindFirstChild(STAGING_NAME)
	if leftover ~= nil then
		leftover:Destroy()
	end
	local staging = Instance.new("WorldModel")
	staging.Name = STAGING_NAME
	staging.Archivable = false
	staging.Parent = ServerStorage
	local ok, result = pcall(changeToCloserFit, staging, pieces, byName, walk)
	staging:Destroy()
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

return sectionCloserFit
