--!strict
-- World prep, task 7, part B: garden extras and prop fixes (from product and designer).
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every step checks first, so a second run changes nothing and says "already done".
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
-- Nothing is deleted: eggs, the second incubator and the flowers go to ServerStorage.ArtLibrary.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLOT_COUNT = 8
local TEACUP_CENTRE = Vector2.new(76, -58)
local SOCK_CENTRE = Vector2.new(-76, -58)
local SOCK_YAW_DEGREES = 96
local FLOWER_CLEAR_RADIUS = 15
local FLOATING_Z_OFFSET = Vector3.new(14, 8, 2)

local report: { string } = {}
local function say(line: string)
	table.insert(report, line)
end

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function flat(position: Vector3): Vector2
	return Vector2.new(position.X, position.Z)
end

-- The ground (Terrain) height at a spot.
local function groundAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	if hit == nil then
		error(`no ground at ({x}, {z})`)
	end
	return hit.Position.Y
end

local function run(): any
	pcall(function()
		ChangeHistoryService:SetWaypoint("02b-garden-extras: before")
	end)

	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local artLibrary = ServerStorage:FindFirstChild("ArtLibrary")
	if artLibrary == nil then
		error("ServerStorage.ArtLibrary is missing (run 01-gardens first)")
	end
	local laterSpecs = getOrCreateFolder(artLibrary, "LaterSpecs")

	----------------------------------------------------------------------------------------------
	-- 1. Empty the incubator domes, and keep one incubator per garden
	----------------------------------------------------------------------------------------------
	local plots = world:FindFirstChild("Plots")
	if plots == nil then
		error("World.Plots is missing")
	end
	local step1: { string } = {}
	for index = 1, PLOT_COUNT do
		local plot = plots:FindFirstChild(`Plot_{index}`)
		local dressing = if plot then plot:FindFirstChild("Dressing") else nil
		if dressing then
			local shelf = getOrCreateFolder(laterSpecs, `Plot_{index}`)
			local incubator = dressing:FindFirstChild("Incubator1")
			local egg = if incubator then incubator:FindFirstChild("HatchingEgg") else nil
			if egg then
				egg.Name = "Incubator1_HatchingEgg"
				egg.Parent = shelf
				table.insert(step1, `Plot_{index}: egg moved out of Incubator1`)
			end
			local second = dressing:FindFirstChild("Incubator2")
			if second then
				second.Parent = shelf
				table.insert(step1, `Plot_{index}: Incubator2 (with its egg) moved`)
			end
		end
	end
	say("1 Incubators: " .. (if #step1 > 0 then table.concat(step1, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- 2. Move the giant teacup and sock out of the way, and keep their height above the ground
	----------------------------------------------------------------------------------------------
	local things = world:FindFirstChild("GiantsThings")
	if things == nil then
		error("World.GiantsThings is missing")
	end

	-- Moves a prop so the horizontal centre of its box is at `target`, keeping its height above the ground.
	-- `yawDegrees` (optional) turns it around Y to that angle, keeping its other turns.
	local function moveProp(name: string, target: Vector2, yawDegrees: number?): string
		local prop = things:FindFirstChild(name)
		if prop == nil or not prop:IsA("Model") then
			error(`GiantsThings.{name} is missing`)
		end
		local boxCentre = prop:GetBoundingBox().Position
		local rx, ry, rz = prop:GetPivot():ToOrientation()
		local yawDone = yawDegrees == nil or math.abs(math.deg(ry) - yawDegrees) < 0.5
		if (flat(boxCentre) - target).Magnitude < 0.5 and yawDone then
			return `{name}: already done`
		end
		local oldGround = groundAt(boxCentre.X, boxCentre.Z)
		local pivot = prop:GetPivot()
		local rotation = pivot.Rotation
		if yawDegrees then
			rotation = CFrame.fromOrientation(rx, math.rad(yawDegrees), rz)
		end
		local newGround = groundAt(target.X, target.Y)
		local offset = pivot.Position - boxCentre
		-- first move, then correct once for how far the centre of the box moved when it was turned
		prop:PivotTo(
			CFrame.new(target.X + offset.X, pivot.Position.Y + (newGround - oldGround), target.Y + offset.Z) * rotation
		)
		local after = prop:GetBoundingBox().Position
		local fix = Vector3.new(target.X - after.X, 0, target.Y - after.Z)
		prop:PivotTo(prop:GetPivot() + fix)
		local final = prop:GetBoundingBox().Position
		return string.format(
			"%s: box centre (%.1f, %.1f) -> (%.1f, %.1f), ground %.2f -> %.2f%s",
			name,
			boxCentre.X,
			boxCentre.Z,
			final.X,
			final.Z,
			oldGround,
			newGround,
			if yawDegrees then `, turned to {yawDegrees} degrees` else ", same turn"
		)
	end
	say(
		"2 Props: " .. moveProp("Teacup", TEACUP_CENTRE, nil) .. "; " .. moveProp("Sock", SOCK_CENTRE, SOCK_YAW_DEGREES)
	)

	----------------------------------------------------------------------------------------------
	-- 3. Take away the flowers and bushes within 15 studs of the new prop spots
	----------------------------------------------------------------------------------------------
	local nature = world:FindFirstChild("Nature")
	if nature == nil then
		error("World.Nature is missing")
	end
	local removed: { string } = {}
	local removedFolder: Folder? = nil
	for _, model in nature:GetChildren() do
		local lower = string.lower(model.Name)
		if model:IsA("Model") and (string.find(lower, "flower", 1, true) or string.find(lower, "bush", 1, true)) then
			local position = flat(model:GetPivot().Position)
			for _, centre in { TEACUP_CENTRE, SOCK_CENTRE } do
				if (position - centre).Magnitude <= FLOWER_CLEAR_RADIUS then
					removedFolder = removedFolder or getOrCreateFolder(artLibrary, "RemovedNature")
					table.insert(removed, string.format("%s at (%.0f, %.0f)", model.Name, position.X, position.Y))
					model.Parent = removedFolder
					break
				end
			end
		end
	end
	say(
		"3 Flowers and bushes: "
			.. (
				if #removed > 0
					then `{#removed} moved to ArtLibrary.RemovedNature: ` .. table.concat(removed, ", ")
					else "already done"
			)
	)

	----------------------------------------------------------------------------------------------
	-- 4. The floating Z Z Z: just above his face (the size and the snore puff stay as they are)
	----------------------------------------------------------------------------------------------
	local giantFx = world:FindFirstChild("GiantFX")
	local emitter = if giantFx then giantFx:FindFirstChild("SnoreEmitter") else nil
	local floatingZ = if emitter then emitter:FindFirstChild("FloatingZ") else nil
	if floatingZ == nil or not floatingZ:IsA("BillboardGui") then
		error("World.GiantFX.SnoreEmitter.FloatingZ is missing")
	end
	if floatingZ.StudsOffset ~= FLOATING_Z_OFFSET then
		local before = floatingZ.StudsOffset
		floatingZ.StudsOffset = FLOATING_Z_OFFSET
		say(`4 Floating Z Z Z: StudsOffset ({before.X}, {before.Y}, {before.Z}) -> (14, 8, 2)`)
	else
		say("4 Floating Z Z Z: already done")
	end

	----------------------------------------------------------------------------------------------
	-- 5. No stars in the daytime sky
	----------------------------------------------------------------------------------------------
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky == nil then
		error("Lighting has no Sky")
	end
	if sky.StarCount ~= 0 then
		say(`5 Sky: StarCount {sky.StarCount} -> 0`)
		sky.StarCount = 0
	else
		say("5 Sky: already done")
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("02b-garden-extras: after")
	end)
	return nil
end

local ok, message = pcall(run)
if not ok then
	say("STOPPED WITH AN ERROR: " .. tostring(message))
end
return table.concat(report, "\n")
