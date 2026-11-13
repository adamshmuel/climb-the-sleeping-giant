--!strict
-- World prep, Task 4g (spec Rule 44, "Your way up is in view from home"): from the gate 1 and gate 8 cameras a meadow
-- rock and a meadow bush hid about two thirds of the boot ladder (3 of 11 sight lines clear). Designer's pick:
--   Nature_MediumRock (middle (-105.9, 5.0, -13.8), gate 1's line) is taken out of the meadow into
--     ServerStorage.ArtLibrary.RemovedNature, the same way 10-clear-landing-views does it (nothing is destroyed).
--   Nature_Bush (middle (132.7, 5.9, -1.3), gate 8's line) moves by (3.8, 0, -4.7): 8 of 11 sight lines clear. This
--     keeps it off the walk from the spawn spot to the ladder, the bridges, the egg spots and the landing spots.
-- Each prop is found by its name and the middle of its bounding box (x and z, within 0.5 studs), not by its pivot.
-- Not touched on purpose: the Nature_FloweringBush with attribute MeadowBushR141 (it covers Block_R141_1).
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau, or require a copy.
-- It checks everything first, so a problem stops the script with nothing changed. A second run changes nothing and says
-- "already done" (a rock found in RemovedNature counts as done). Back the two props up first
-- (ServerStorage.WorldBackups.T4g). The place file must be saved afterwards.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SAME_PLACE = 0.5 -- studs, across the ground (x and z): "the same prop"

-- offset == nil means: take the prop out of the meadow into ServerStorage.ArtLibrary.RemovedNature.
type Move = { name: string, x: number, z: number, offset: Vector3? }

local MOVES: { Move } = {
	{ name = "Nature_MediumRock", x = -105.9, z = -13.8, offset = nil },
	{ name = "Nature_Bush", x = 132.7, z = -1.3, offset = Vector3.new(3.8, 0, -4.7) },
}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- The Models directly under `folder` with this name whose bounding box middle is at (x, z).
local function findAt(folder: Instance, name: string, x: number, z: number): { Model }
	local matches: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.Name == name then
			local middle = child:GetBoundingBox().Position
			if (flat(middle) - Vector3.new(x, 0, z)).Magnitude <= SAME_PLACE then
				table.insert(matches, child)
			end
		end
	end
	return matches
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local nature = world:FindFirstChild("Nature")
	if nature == nil then
		error("Workspace.World.Nature is missing")
	end
	local artLibrary = ServerStorage:FindFirstChild("ArtLibrary")
	if artLibrary == nil then
		error("ServerStorage.ArtLibrary is missing")
	end
	local removedNature = artLibrary:FindFirstChild("RemovedNature")

	local toMove: { { move: Move, model: Model } } = {}
	local alreadyDone = 0
	for _, move in MOVES do
		local atOld = findAt(nature, move.name, move.x, move.z)
		local offset = move.offset
		local elsewhere: { Model }
		if offset then
			elsewhere = findAt(nature, move.name, move.x + offset.X, move.z + offset.Z)
		else
			elsewhere = if removedNature then findAt(removedNature, move.name, move.x, move.z) else {}
		end
		if #atOld == 1 and #elsewhere == 0 then
			table.insert(toMove, { move = move, model = atOld[1] })
		elseif #atOld == 0 and #elsewhere == 1 then
			alreadyDone += 1
		else
			error(
				`{move.name} at ({move.x}, {move.z}): found {#atOld} at the old spot and {#elsewhere} at the new place (expected 1 and 0, or 0 and 1)`
			)
		end
	end

	if #toMove == 0 then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("30-clear-gate-views: before")
	end)
	local lines: { string } = {}
	for _, item in toMove do
		local offset = item.move.offset
		if offset then
			item.model:PivotTo(item.model:GetPivot() + offset)
			local middle = item.model:GetBoundingBox().Position
			table.insert(
				lines,
				string.format("moved %s to (%.1f, %.1f, %.1f)", item.move.name, middle.X, middle.Y, middle.Z)
			)
		else
			if removedNature == nil then
				local folder = Instance.new("Folder")
				folder.Name = "RemovedNature"
				folder.Parent = artLibrary
				removedNature = folder
			end
			item.model.Parent = removedNature
			table.insert(lines, `removed {item.move.name} to ServerStorage.ArtLibrary.RemovedNature`)
		end
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("30-clear-gate-views: after")
	end)
	table.insert(lines, `{#toMove} changed, {alreadyDone} were already done`)
	return table.concat(lines, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
