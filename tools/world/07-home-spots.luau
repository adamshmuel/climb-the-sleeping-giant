--!strict
-- World prep, task 38: the places where eggs sit at home (spec Rule 5, "Bring it home", and the "Egg safe at home"
-- row of spec section 6).
-- Why: 12 fixed places per garden, made once and checked by a real-world test, are easier to check and to look at than
-- places worked out while the game runs.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks first, so a second run changes nothing and says "already done". It returns a short plain-text report.
-- Nothing is deleted or moved. The place file must be saved by Adam afterwards.
--
-- Each garden (Workspace.World.Plots.Plot_1 .. Plot_8) gets a Folder "HomeSpots" with 12 invisible parts,
-- HomeSpot_1 .. HomeSpot_12. Each part is 2 x 0.2 x 2 studs, anchored, flat, and nothing can touch, hit or see it. Its
-- TOP centre is where a home egg's bottom sits (an egg model's pivot is at its bottom centre).
--   1 to 6   on top of PetPad1 .. PetPad6, in the middle of the pad's walk surface (the flat dish in the top of the pad).
--   7 to 12  on the grass, in two short rows of 3 along one line, measured from the garden's own box:
--            the west row stands beside the incubator, the east row beside the cash chest, and the lawn between them
--            stays free as the walkway from the gate. (The garden has no clean place for one row of 6: flowers, the
--            path stones and the pads fill the rest. The flowers differ from garden to garden, so the rows were
--            chosen where none of the 8 gardens has a flower, bush, stone-bed or prop in the way.)
-- Before it makes anything, the script checks every spot of every garden: a pad's walk surface is flat, a grass spot
-- has flat terrain under it, and an egg-sized box (6 x 7 x 6) standing on the spot touches no part with CanCollide on
-- (an egg on a pad may touch its own pad, whose rim rises 0.6 studs above the dish). Any failure stops the script with
-- nothing changed.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLOT_COUNT = 8
local PAD_COUNT = 6
local SPOT_SIZE = Vector3.new(2, 0.2, 2)

-- Spots 7 to 12: x and z in the garden's own frame (the GardenVolume's centre and turn). x runs across the garden
-- and z runs from the gate (z = -26) toward the far fence. The height comes from the terrain under the point.
-- The rows are on z = -7.5, 6.6 studs apart (the least allowed is 6.5): between the incubator and chest (z -17.5 to
-- -10.5) and the pads (z -0.25 on). Only z = -7.5 (give or take 0.2) is clear of flowers, the incubator and the Plot 4
-- sunflower in all 8 gardens, so x and z were tuned together.
local ROW_SPOTS: { { number } } = {
	{ -24.2, -7.5 }, -- west row, beside the incubator
	{ -17.6, -7.5 },
	{ -11, -7.5 },
	{ 11, -7.5 }, -- east row, beside the cash chest
	{ 17.6, -7.5 },
	{ 24.2, -7.5 },
}
-- Every garden is built the same way. These two pieces tell the script the garden is the one the table was made for.
local INCUBATOR_LOCAL = Vector3.new(-22, 0, -14)
local GATE_LOCAL = Vector3.new(0, 0, -26)
local PLACE_LIMIT = 0.6 -- studs: how far the incubator and the gate may be from those places

local EGG_BOX = Vector3.new(6, 7, 6) -- holds the widest egg (Rare, about 5.9 across) and the tallest (7.0)
local EGG_BOX_LIFT = 0.1 -- the box starts this far above the top of the spot
local MAX_SLOPE_DEGREES = 10
-- The dish in the top of a pad is rough stone: measured 7.82 in the middle and up to 0.11 higher 1 stud away. The very
-- middle is on an edge between two triangles of the mesh, where the ray reports a wrong slope, so the slope is read
-- 0.1 studs to the side. These limits catch a pad that is badly tilted or broken.
local DISH_FLAT_LIMIT = 0.2 -- studs: the dish may differ this much in height 1 stud from its middle
local DISH_PROBE = 1
local DISH_SLOPE_PROBE = Vector3.new(0.1, 0, 0.1)
local DISH_MIN_NORMAL_Y = 0.98 -- a slope of about 11 degrees

type Placement = { number: number, top: Vector3, pad: Model? }
type Plan = { plot: Instance, box: BasePart, rotation: CFrame, placements: { Placement } }

-- A downward ray from `from` that skips everything a player walks through (flowers, stones, the spots themselves).
-- With `onlyThese` it can only hit those parts.
local function rayDown(from: Vector3, length: number, onlyThese: { Instance }?): RaycastResult?
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	if onlyThese then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = onlyThese
	end
	return Workspace:Raycast(from, Vector3.new(0, -length, 0), params)
end

-- Works out where the 12 spots of one garden go, and checks every one. Stops with an error that names the problem.
local function planGarden(plot: Instance): Plan
	local box = plot:FindFirstChild("GardenVolume")
	local dressing = plot:FindFirstChild("Dressing")
	local gate = plot:FindFirstChild("SafeGate")
	if box == nil or not box:IsA("BasePart") then
		error(`{plot.Name} has no GardenVolume part`)
	end
	if dressing == nil then
		error(`{plot.Name} has no Dressing`)
	end
	local incubator = dressing:FindFirstChild("Incubator1")
	if incubator == nil or not incubator:IsA("Model") then
		error(`{plot.Name} has no Dressing.Incubator1`)
	end
	if gate == nil or not gate:IsA("Model") then
		error(`{plot.Name} has no SafeGate`)
	end

	-- The garden is turned about the up axis only, so the spots lie flat. `rotation` is that turn.
	local look = box.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.5 then
		error(`{plot.Name}: GardenVolume does not face along the ground`)
	end
	local rotation = CFrame.lookAt(Vector3.zero, flatLook.Unit)

	-- The garden is built like the others: its incubator and gate are where the table expects them.
	local incubatorLocal = box.CFrame:PointToObjectSpace(incubator:GetPivot().Position)
	local gateLocal = box.CFrame:PointToObjectSpace(gate:GetPivot().Position)
	if
		(Vector3.new(incubatorLocal.X, 0, incubatorLocal.Z) - INCUBATOR_LOCAL).Magnitude > PLACE_LIMIT
		or (Vector3.new(gateLocal.X, 0, gateLocal.Z) - GATE_LOCAL).Magnitude > PLACE_LIMIT
	then
		error(`{plot.Name} is not built like the others: its incubator or gate is not where 07-home-spots expects`)
	end

	local placements: { Placement } = {}

	-- 1 to 6: the middle of each pad's walk surface.
	for number = 1, PAD_COUNT do
		local pad = dressing:FindFirstChild(`PetPad{number}`)
		if pad == nil or not pad:IsA("Model") then
			error(`{plot.Name} has no Dressing.PetPad{number}`)
		end
		local onlyThisPad: { Instance } = { pad }
		local boxCFrame, boxSize = pad:GetBoundingBox()
		local middle = boxCFrame.Position
		local from = Vector3.new(middle.X, middle.Y + boxSize.Y / 2 + 5, middle.Z)
		local hit = rayDown(from, boxSize.Y + 10, onlyThisPad)
		if hit == nil then
			error(`{plot.Name}.PetPad{number}: no walk surface found under the middle of the pad`)
		end
		local slopeHit = rayDown(from + DISH_SLOPE_PROBE, boxSize.Y + 10, onlyThisPad)
		if slopeHit == nil or slopeHit.Normal.Y < DISH_MIN_NORMAL_Y then
			error(`{plot.Name}.PetPad{number}: the middle of the pad is too steep`)
		end
		for _, offset in
			{
				Vector3.new(DISH_PROBE, 0, 0),
				Vector3.new(-DISH_PROBE, 0, 0),
				Vector3.new(0, 0, DISH_PROBE),
				Vector3.new(0, 0, -DISH_PROBE),
			}
		do
			local side = rayDown(from + offset, boxSize.Y + 10, onlyThisPad)
			if side == nil or math.abs(side.Position.Y - hit.Position.Y) > DISH_FLAT_LIMIT then
				error(`{plot.Name}.PetPad{number}: the walk surface is not flat 1 stud from the middle`)
			end
		end
		table.insert(placements, { number = number, top = hit.Position, pad = pad })
	end

	-- 7 to 12: on the grass, from the table.
	local maxSlope = math.cos(math.rad(MAX_SLOPE_DEGREES))
	for index, place in ROW_SPOTS do
		local number = PAD_COUNT + index
		local above = box.CFrame:PointToWorldSpace(Vector3.new(place[1], box.Size.Y / 2, place[2]))
		local hit = rayDown(above, box.Size.Y + 20, nil)
		if hit == nil then
			error(`{plot.Name}.HomeSpot_{number}: nothing solid under ({place[1]}, {place[2]})`)
		end
		if hit.Instance ~= Workspace.Terrain then
			error(`{plot.Name}.HomeSpot_{number}: not on the grass (found {hit.Instance:GetFullName()})`)
		end
		if hit.Normal.Y < maxSlope then
			error(`{plot.Name}.HomeSpot_{number}: the grass is steeper than {MAX_SLOPE_DEGREES} degrees`)
		end
		table.insert(placements, { number = number, top = hit.Position, pad = nil })
	end

	-- An egg standing on each spot touches nothing solid.
	for _, placement in placements do
		local params = OverlapParams.new()
		params.RespectCanCollide = true
		if placement.pad then
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { placement.pad }
		end
		local eggBox = CFrame.new(placement.top + Vector3.new(0, EGG_BOX_LIFT + EGG_BOX.Y / 2, 0)) * rotation
		local parts = Workspace:GetPartBoundsInBox(eggBox, EGG_BOX, params)
		if #parts > 0 then
			error(`{plot.Name}.HomeSpot_{placement.number}: an egg here would touch {parts[1]:GetFullName()}`)
		end
	end

	return { plot = plot, box = box, rotation = rotation, placements = placements }
end

local function makeFolder(plan: Plan): Folder
	local folder = Instance.new("Folder")
	folder.Name = "HomeSpots"
	for _, placement in plan.placements do
		local spot = Instance.new("Part")
		spot.Name = `HomeSpot_{placement.number}`
		spot.Size = SPOT_SIZE
		-- the top centre of the part is `top`, so its middle is half its thickness lower
		spot.CFrame = CFrame.new(placement.top - Vector3.new(0, SPOT_SIZE.Y / 2, 0)) * plan.rotation
		spot.Anchored = true
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.CastShadow = false
		spot.Parent = folder
	end
	return folder
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	local plots = if world then world:FindFirstChild("Plots") else nil
	if plots == nil then
		error("Workspace.World.Plots is missing (run 01-gardens first)")
	end

	-- Check every garden first, so a problem stops the script before anything changes.
	local todo: { Plan } = {}
	local alreadyThere = 0
	for index = 1, PLOT_COUNT do
		local plot = plots:FindFirstChild(`Plot_{index}`)
		if plot == nil then
			error(`Plot_{index} is missing`)
		end
		local existing = plot:FindFirstChild("HomeSpots")
		if existing then
			local count = #existing:GetChildren()
			if count ~= PAD_COUNT + #ROW_SPOTS then
				error(
					`{plot.Name}.HomeSpots exists but has {count} children, not {PAD_COUNT + #ROW_SPOTS}. Nothing was changed.`
				)
			end
			alreadyThere += 1
		else
			table.insert(todo, planGarden(plot))
		end
	end

	if #todo == 0 then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("07-home-spots: before")
	end)
	local lines: { string } = {}
	for _, plan in todo do
		makeFolder(plan).Parent = plan.plot
		local padLow, padHigh = math.huge, -math.huge
		local rowLow, rowHigh = math.huge, -math.huge
		for _, placement in plan.placements do
			if placement.pad then
				padLow = math.min(padLow, placement.top.Y)
				padHigh = math.max(padHigh, placement.top.Y)
			else
				rowLow = math.min(rowLow, placement.top.Y)
				rowHigh = math.max(rowHigh, placement.top.Y)
			end
		end
		table.insert(
			lines,
			string.format(
				"%s: 12 spots (pad tops y %.2f to %.2f, grass spots y %.2f to %.2f)",
				plan.plot.Name,
				padLow,
				padHigh,
				rowLow,
				rowHigh
			)
		)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("07-home-spots: after")
	end)

	return string.format("made HomeSpots in %d gardens (%d already had them):\n   ", #todo, alreadyThere)
		.. table.concat(lines, "\n   ")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
