--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 3a: the pillow's closer fit (stuck safety Task 22, step 22-2; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = require(script.Parent.Shared)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)

local MAX_WAIT = Shared.MAX_WAIT
type FixedRay = Shared.FixedRay
local readRays = Shared.readRays
local someProblems = S2bHeadChecks.someProblems
local bodySnapshot = FitShared.bodySnapshot
local bodyDifferences = FitShared.bodyDifferences
local unexpectedDifferences = FitShared.unexpectedDifferences
local countValues = FitShared.countValues
local hitHeight = FitShared.hitHeight
local heightText = FitShared.heightText
local waitForSourceShape = FitShared.waitForSourceShape
local isTunableAt = FitShared.isTunableAt

-- Why: the pillow behind his head (World.GiantsThings.Pillow.body.body_geom) has Roblox's usual collision shape
-- (CollisionFidelity Default), which sits above the pillow players see in places: 35 of the 287 stuck spots are on it.
-- CollisionPrecision 1 on the Tunable shape ("closest to the visual mesh", Roblox docs, TriangleMeshPart) follows the
-- pillow's drawn surface much closer, and a pillow is a plain MeshPart, so it is done the way section 2f2 does it:
-- AssetService:CreateMeshPartAsync makes a Tunable copy, CollisionPrecision 1 is set on the copy, and MeshPart:ApplyMesh
-- takes its shape onto the pillow. ApplyMesh wipes TextureID (measured in step 6b-1f), so it is put back at once.
-- It knows two worlds, and changes nothing on any difference:
--   (a) before: the pillow is CollisionFidelity Default, with its MeshId, TextureID, Size and CFrame as recorded in step
--       22-0 (below). The change is made.
--   (b) after: the pillow is Tunable at CollisionPrecision 1.0 (+-0.01), with the same MeshId, TextureID, Size and
--       CFrame. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- Away from the Workspace (in a WorldModel in ServerStorage that is destroyed at the end, also when something fails):
--   1. The Tunable copy is made, given the pillow's Size and CFrame, and its 7 rays (below) are read until steady.
--   2. CollisionPrecision is set to 1, and it waits until the rays move and are steady again (up to MAX_WAIT seconds,
--      then it stops with nothing changed).
--   3. Dry run: ApplyMesh from the copy onto a clone of the pillow, TextureID put back. The same 28 values as in 2f are
--      compared (only CollisionFidelity and CollisionPrecision may differ) and the clone must be Tunable at 1.0.
-- Only then, between two ChangeHistoryService waypoints: ApplyMesh onto the live pillow and TextureID put back, the same
-- check on the live pillow, and a wait until its rays have moved and are steady.
-- Rays: straight down from y 140 at 7 points (x, z), reading the pillow alone, as in step 22-0 (heights before the change):
--   (0, 50) 116.0, (0, 66) 93.8, (20, 66) 90.3, (-20, 66) 90.1, (0, 72) 77.5, (17, 41) 119.6, (-17, 41) 119.8.
-- No earlier section reads the pillow, so all of them still say "already done" after this one has run.
local function sectionPillowCloserFit(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	-- As recorded in step 22-0 (Studio Edit mode, 2026-10-21).
	local PATH = { "World", "GiantsThings", "Pillow", "body", "body_geom" }
	local MESH_ID = "rbxassetid://106761089887672"
	local TEXTURE_ID = "rbxassetid://138710597423165"
	local SIZE = Vector3.new(95.004646, 91.194412, 35.748734)
	local CFRAME = CFrame.new(0.142862, 79.86055, 52.141579, 1, 0, 0, 0, 0.939693, 0.34202, 0, -0.34202, 0.939692)
	local PLACE_TOLERANCE_STUDS = 0.01 -- on the size and the middle
	local TURN_TOLERANCE_NUMBER = 0.001 -- on each of the nine numbers of the turn
	local PILLOW_PRECISION = 1.0
	local PILLOW_PRECISION_SLACK = 0.01
	local RAY_FROM_Y = 140
	local RAY_LENGTH = 150
	local RAY_POINTS = {
		Vector2.new(0, 50),
		Vector2.new(0, 66),
		Vector2.new(20, 66),
		Vector2.new(-20, 66),
		Vector2.new(0, 72),
		Vector2.new(17, 41),
		Vector2.new(-17, 41),
	}
	local PILLOW_STAGING_NAME = "Task22Staging3a"

	local node: Instance? = Workspace
	for _, name in PATH do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	if node == nil or not node:IsA("MeshPart") then
		error(`nothing was changed. {table.concat(PATH, ".")} (a MeshPart) is missing`)
	end
	local pillow: MeshPart = node

	local rays: { FixedRay } = {}
	for _, point in RAY_POINTS do
		table.insert(rays, {
			origin = Vector3.new(point.X, RAY_FROM_Y, point.Y),
			direction = Vector3.new(0, -RAY_LENGTH, 0),
		})
	end
	local function raysText(distances: { number }): string
		local texts: { string } = {}
		for index, ray in rays do
			table.insert(
				texts,
				`({RAY_POINTS[index].X}, {RAY_POINTS[index].Y}) {heightText(hitHeight(ray, distances[index]))}`
			)
		end
		return table.concat(texts, "; ")
	end
	local function stateText(mesh: MeshPart): string
		return string.format(
			"CollisionFidelity %s, CollisionPrecision %.2f, TextureID %s",
			mesh.CollisionFidelity.Name,
			mesh.CollisionPrecision,
			mesh.TextureID
		)
	end

	-- What never changes: the mesh, the texture, the size and the place as recorded.
	local problems: { string } = {}
	if pillow.MeshId ~= MESH_ID then
		table.insert(problems, `MeshId is {pillow.MeshId}, recorded {MESH_ID}`)
	end
	if pillow.TextureID ~= TEXTURE_ID then
		table.insert(problems, `TextureID is {pillow.TextureID}, recorded {TEXTURE_ID}`)
	end
	if (pillow.Size - SIZE).Magnitude > PLACE_TOLERANCE_STUDS then
		table.insert(problems, `Size is {pillow.Size}, recorded {SIZE}`)
	end
	if (pillow.CFrame.Position - CFRAME.Position).Magnitude > PLACE_TOLERANCE_STUDS then
		table.insert(problems, `its middle is {pillow.CFrame.Position}, recorded {CFRAME.Position}`)
	end
	local nowTurn = { pillow.CFrame:GetComponents() }
	local recordedTurn = { CFRAME:GetComponents() }
	for index = 4, 12 do
		if math.abs(nowTurn[index] - recordedTurn[index]) > TURN_TOLERANCE_NUMBER then
			table.insert(problems, `its turn differs from the recorded one (number {index - 3} of 9)`)
			break
		end
	end
	if #problems > 0 then
		error(`nothing was changed. The pillow is not the one recorded in step 22-0: {someProblems(problems)}`)
	end

	-- Which world is it?
	if isTunableAt(pillow, PILLOW_PRECISION, PILLOW_PRECISION_SLACK) then
		return `already done: the pillow is Tunable at CollisionPrecision {string.format(
			"%.2f",
			pillow.CollisionPrecision
		)}, with its mesh, texture, size and place as recorded. {stateText(pillow)}. Its rays now: {raysText(
			readRays(pillow, rays)
		)}`
	end
	if pillow.CollisionFidelity ~= Enum.CollisionFidelity.Default then
		error(
			`nothing was changed. The pillow is neither the world before nor the world after section 3a: {stateText(
				pillow
			)}`
		)
	end

	local function changePillow(staging: WorldModel): string
		local oldPrecision = pillow.CollisionPrecision
		local lines: { string } = {}
		table.insert(lines, `before: {stateText(pillow)}`)
		local beforeLive = readRays(pillow, rays)
		table.insert(lines, `before: the live pillow's rays: {raysText(beforeLive)}`)

		local made, madeOrWhy = pcall(function(): MeshPart
			return AssetService:CreateMeshPartAsync(Content.fromUri(pillow.MeshId), {
				CollisionFidelity = Enum.CollisionFidelity.Tunable,
				RenderFidelity = pillow.RenderFidelity,
				FluidFidelity = pillow.FluidFidelity,
			})
		end)
		if not made then
			error(`nothing was changed. CreateMeshPartAsync failed for the pillow: {tostring(madeOrWhy)}`)
		end
		local source = madeOrWhy :: MeshPart
		source.Anchored = true
		source.Size = pillow.Size
		source.CFrame = pillow.CFrame
		source.Parent = staging

		local baselineSteady, _, _, baseline = waitForSourceShape(staging, source, rays, nil)
		if not baselineSteady then
			error(
				`nothing was changed. The copy of the pillow never settled at its first precision within {MAX_WAIT} seconds`
			)
		end
		(source :: any).CollisionPrecision = PILLOW_PRECISION
		local moved, seconds, movedBy = waitForSourceShape(staging, source, rays, baseline)
		if not moved then
			error(
				string.format(
					"nothing was changed. The copy of the pillow did not change its shape within %d seconds of CollisionPrecision 1 (largest ray move %.3f studs)",
					MAX_WAIT,
					movedBy
				)
			)
		end

		-- Dry run on a clone.
		local trial = pillow:Clone()
		trial.Parent = staging
		local wiped = false
		local trialOk, trialWhy = pcall(function()
			trial:ApplyMesh(source)
			wiped = trial.TextureID ~= TEXTURE_ID
			trial.TextureID = TEXTURE_ID
		end)
		if not trialOk then
			error(`nothing was changed. ApplyMesh failed on the clone of the pillow: {tostring(trialWhy)}`)
		end
		local before = bodySnapshot(pillow)
		local trialDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(trial)))
		if #trialDifferences > 0 then
			error(
				`nothing was changed. ApplyMesh on the clone of the pillow changed more than the collision: {table.concat(
					trialDifferences,
					", "
				)}`
			)
		end
		if not isTunableAt(trial, PILLOW_PRECISION, PILLOW_PRECISION_SLACK) then
			error(
				string.format(
					"nothing was changed. The clone of the pillow is %s at CollisionPrecision %.3f, expected Tunable at 1.0",
					trial.CollisionFidelity.Name,
					trial.CollisionPrecision
				)
			)
		end
		trial:Destroy()

		-- The change itself, between two waypoints.
		pcall(function()
			ChangeHistoryService:SetWaypoint("15-real-shape section 3a: before")
		end)
		local changed, whyNot = pcall(function()
			pillow:ApplyMesh(source)
			pillow.TextureID = TEXTURE_ID
		end)
		pcall(function()
			ChangeHistoryService:SetWaypoint("15-real-shape section 3a: after")
		end)
		if not changed then
			error(
				`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3a: before") and tell code_lead`
			)
		end

		-- The same check on the live pillow.
		local differences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(pillow)))
		if #differences > 0 or not isTunableAt(pillow, PILLOW_PRECISION, PILLOW_PRECISION_SLACK) then
			error(
				string.format(
					"the pillow was changed, but the check afterwards found it is %s at CollisionPrecision %.3f and differs from before in: %s. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead",
					pillow.CollisionFidelity.Name,
					pillow.CollisionPrecision,
					table.concat(differences, ", ")
				)
			)
		end
		table.insert(
			lines,
			string.format(
				"CollisionFidelity Default -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after: only CollisionFidelity and CollisionPrecision differ. The staging copy's rays moved %.2f studs after CollisionPrecision 1 (steady after %.1f seconds)",
				oldPrecision,
				pillow.CollisionPrecision,
				if wiped then "wiped" else "did not wipe",
				pillow.TextureID,
				countValues(before),
				movedBy,
				seconds
			)
		)

		-- Wait until Roblox has worked out the new shape: the live pillow's rays must have moved and be steady.
		local steady, waited, liveMoved, now = waitForSourceShape(Workspace, pillow, rays, beforeLive)
		table.insert(lines, `after: {stateText(pillow)}`)
		table.insert(lines, `after: the live pillow's rays: {raysText(now)}`)
		table.insert(
			lines,
			string.format("largest ray move on the live pillow from before the change: %.2f studs", liveMoved)
		)
		if steady then
			table.insert(
				lines,
				string.format("Roblox worked out the shape: the rays were steady after %.1f seconds of waiting", waited)
			)
		else
			table.insert(
				lines,
				string.format(
					"TIMED OUT after %.0f seconds: the shape was not steady yet, or the pillow's rays did not move. Run the script again to wait further, and if it is the same, STOP and tell code_lead",
					waited
				)
			)
		end
		return table.concat(lines, "\n")
	end

	-- The staging WorldModel: a leftover from a stopped run goes first, and it is destroyed whatever happens.
	local leftover = ServerStorage:FindFirstChild(PILLOW_STAGING_NAME)
	if leftover ~= nil then
		leftover:Destroy()
	end
	local staging = Instance.new("WorldModel")
	staging.Name = PILLOW_STAGING_NAME
	staging.Archivable = false
	staging.Parent = ServerStorage
	local ok, result = pcall(changePillow, staging)
	staging:Destroy()
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

return sectionPillowCloserFit
