--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 3a2: lit like before (stuck safety Task 22, step 22-6d; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

local someProblems = S2bHeadChecks.someProblems
local bodySnapshot = FitShared.bodySnapshot
local bodyDifferences = FitShared.bodyDifferences
local countValues = FitShared.countValues
local isTunableAt = FitShared.isTunableAt

-- Why: after its closer collision fit (Tunable, CollisionPrecision 1) the pillow looked dark navy and tan instead of
-- light blue and cream gingham. Nothing was lost: Color, Material, MaterialVariant, Transparency, Reflectance and TextureID
-- are all still the ArtLibrary original's. The precise solid shape shades the pillow itself in Roblox's lighting, and
-- CastShadow false puts the light look back (step 22-6a and 22-6b: the nightcap, head, body and legs keep CastShadow true,
-- because they stayed light; only the pieces in LIT_PIECES below change). The cost: the pillow no longer drops a shadow on
-- the grass (designer judges that in step 22-6g).
-- It knows two worlds, and changes nothing on any difference:
--   (a) before: each listed piece is Tunable at CollisionPrecision 1.0 (+-0.01) with CastShadow true. CastShadow is set to
--       false, and nothing else is touched.
--   (b) after: each listed piece is Tunable at CollisionPrecision 1.0 (+-0.01) with CastShadow false. It says "already
--       done".
--   (c) anything else (a piece missing or not the recorded one, not Tunable at 1.0, or some pieces before and some
--       after): it stops with nothing changed and names what differs.
-- The change runs between two ChangeHistoryService waypoints, and every value the pillow-style snapshot compares (the 28
-- values of section 2f) is checked again afterwards: only CastShadow may differ.
local function sectionLitLikeBefore(): string
	if RunService:IsRunning() then
		error("a running game can't be checked like this: stop Play and run this in Edit mode")
	end
	-- The listed pieces, as recorded in step 22-0 (Studio Edit mode, 2026-10-21).
	local LIT_PIECES = {
		{
			label = "the pillow",
			path = { "World", "GiantsThings", "Pillow", "body", "body_geom" },
			meshId = "rbxassetid://106761089887672",
			textureId = "rbxassetid://138710597423165",
		},
	}
	local LIT_PRECISION = 1.0
	local LIT_PRECISION_SLACK = 0.01
	local LIT_MAY_DIFFER = "CastShadow"

	local pieces: { { label: string, mesh: MeshPart } } = {}
	for _, listed in LIT_PIECES do
		local node: Instance? = Workspace
		for _, name in listed.path do
			node = if node ~= nil then node:FindFirstChild(name) else nil
		end
		if node == nil or not node:IsA("MeshPart") then
			error(`nothing was changed. {table.concat(listed.path, ".")} (a MeshPart) is missing`)
		end
		local mesh: MeshPart = node
		if mesh.MeshId ~= listed.meshId or mesh.TextureID ~= listed.textureId then
			error(
				`nothing was changed. {listed.label} is not the one recorded: MeshId {mesh.MeshId}, TextureID {mesh.TextureID}`
			)
		end
		table.insert(pieces, { label = listed.label, mesh = mesh })
	end

	local function pieceText(label: string, mesh: MeshPart): string
		return string.format(
			"%s: CollisionFidelity %s, CollisionPrecision %.2f, CastShadow %s",
			label,
			mesh.CollisionFidelity.Name,
			mesh.CollisionPrecision,
			tostring(mesh.CastShadow)
		)
	end

	-- Which world is it?
	local before: { string } = {}
	local after: { string } = {}
	local other: { string } = {}
	local allTexts: { string } = {}
	for _, piece in pieces do
		table.insert(allTexts, pieceText(piece.label, piece.mesh))
		if not isTunableAt(piece.mesh, LIT_PRECISION, LIT_PRECISION_SLACK) then
			table.insert(other, `{piece.label} is not Tunable at CollisionPrecision {LIT_PRECISION}`)
		elseif piece.mesh.CastShadow then
			table.insert(before, piece.label)
		else
			table.insert(after, piece.label)
		end
	end
	if #other > 0 then
		error(
			`nothing was changed. This is neither the world before nor the world after section 3a2: {someProblems(other)}`
		)
	end
	if #before > 0 and #after > 0 then
		error(`nothing was changed. Some pieces are lit like before and some are not: {table.concat(allTexts, "; ")}`)
	end
	if #after == #pieces then
		return `already done: {table.concat(allTexts, "; ")}`
	end

	-- The change itself, between two waypoints: CastShadow false on each listed piece, and nothing else.
	local snapshots: { { [string]: any } } = {}
	for _, piece in pieces do
		table.insert(snapshots, bodySnapshot(piece.mesh))
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3a2: before")
	end)
	local changed, whyNot = pcall(function()
		for _, piece in pieces do
			piece.mesh.CastShadow = false
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3a2: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3a2: before") and tell code_lead`
		)
	end

	-- The same check afterwards: only CastShadow may differ, and it must now be false.
	local wrong: { string } = {}
	local valuesCompared = 0
	for index, piece in pieces do
		valuesCompared += countValues(snapshots[index])
		for _, name in bodyDifferences(snapshots[index], bodySnapshot(piece.mesh)) do
			if name ~= LIT_MAY_DIFFER then
				table.insert(wrong, `{piece.label}: {name} changed`)
			end
		end
		if piece.mesh.CastShadow then
			table.insert(wrong, `{piece.label}: CastShadow is still true`)
		end
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	local afterTexts: { string } = {}
	for _, piece in pieces do
		table.insert(afterTexts, pieceText(piece.label, piece.mesh))
	end
	return string.format(
		"CastShadow true -> false on %d piece(s); %d values compared before and after: only CastShadow differs. Before: %s. After: %s",
		#pieces,
		valuesCompared,
		table.concat(allTexts, "; "),
		table.concat(afterTexts, "; ")
	)
end

return sectionLitLikeBefore
