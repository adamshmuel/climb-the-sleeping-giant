--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)

local READ_EVERY = Shared.READ_EVERY
local readRays = Shared.readRays
type Piece = Shared.Piece
local findPieces = Shared.findPieces
local waitForShapes = Shared.waitForShapes

local function sectionHisRealShape(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	local pieces, problems = findPieces()
	if #problems > 0 then
		error("nothing was changed. " .. table.concat(problems, "; "))
	end

	local changing: { Piece } = {}
	for _, piece in pieces do
		if piece.changing then
			table.insert(changing, piece)
		end
	end
	local lines: { string } = {}

	if #changing == 0 then
		local steady, seconds = waitForShapes(pieces)
		if not steady then
			error(
				string.format(
					"all six pieces are in their final shape, but their rays were still moving after %.0f seconds",
					seconds
				)
			)
		end
		return string.format(
			"already done: all six body pieces are in their final shape (PreciseConvexDecomposition, or Tunable for body_and_cushion, head_with_beard and nightcap after sections 2f and 2f2, and for legs_and_boots after section 2f5) and their rays are steady (two reads %d seconds apart, after %.1f seconds)",
			READ_EVERY,
			seconds
		)
	end

	for _, piece in pieces do
		piece.before = readRays(piece.mesh, piece.rays)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape: before")
	end)
	for _, piece in changing do
		piece.mesh.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
		table.insert(lines, `{piece.mesh:GetFullName()}: CollisionFidelity Default -> PreciseConvexDecomposition`)
	end
	local steady, seconds, moves = waitForShapes(pieces)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape: after")
	end)
	for _, piece in pieces do
		table.insert(
			lines,
			string.format(
				"%s: %d fixed rays; the largest move from before the change is %.2f studs%s",
				piece.name,
				#piece.rays,
				moves[piece.name],
				if piece.changing then "" else " (not changed now)"
			)
		)
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
				"TIMED OUT after %.0f seconds: the shapes were not steady yet. Run the script again to wait further",
				seconds
			)
		)
	end
	return table.concat(lines, "\n")
end

return sectionHisRealShape
