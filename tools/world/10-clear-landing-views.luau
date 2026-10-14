--!strict
-- World prep, task 27 (round 2): a clear view behind each landing spot (spec Rule 12, "Waking bounces everyone off",
-- and the "Clear view behind each landing spot" row of the style guide).
-- Why: designer's look check in Play. While a bounced player floats down, and just after landing, the camera sits 9 to
-- 11 studs behind them and low, so it ended up inside meadow props: a sunflower head filled a third to half of the
-- screen at landing spots 3, 5, 6 and 7, and flower clumps stood in front of the player at spots 6 and 8. This script
-- takes the 7 props that were in the way out of the meadow: five Nature_Sunflower, one Inno_White_Flowers and one
-- Inno_Yellow_Flowers (all direct children of Workspace.World.Nature). Each prop is found by its name and the middle
-- of its bounding box (x and z, within 0.5 studs), not by its pivot.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. A second run changes nothing and says
-- "already done". Nothing is destroyed: the 7 props are moved to ServerStorage.ArtLibrary.RemovedNature, where the props
-- that 02b-garden-extras took away already are, so they are easy to bring back. They are not moved anywhere else in the
-- meadow. The place file must be saved by Adam afterwards.
-- After the move it adds a report (it changes nothing): for each landing spot, the sunflowers, bushes, rocks, mushrooms
-- and flower clumps that are still behind it (on the side away from his face, 1 to 14 studs back, at most 3 studs to
-- each side).

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SAME_PLACE = 0.5 -- studs, across the ground (x and z): "the same prop"
local BEHIND_MIN = 1 -- studs back from a landing spot, away from his face
local BEHIND_MAX = 14
local BEHIND_SIDE = 3 -- studs to each side

type Entry = { name: string, x: number, z: number }
type Prop = { name: string, middle: Vector3 }

-- The 7 props, with the middle of each model's bounding box.
local REMOVED_PROPS: { Entry } = {
	{ name = "Nature_Sunflower", x = 51.7, z = -96.9 },
	{ name = "Nature_Sunflower", x = -50.3, z = -70.7 },
	{ name = "Nature_Sunflower", x = -52.9, z = -62.4 },
	{ name = "Nature_Sunflower", x = -60.2, z = -59.0 },
	{ name = "Nature_Sunflower", x = 47.7, z = -72.0 },
	{ name = "Inno_White_Flowers", x = -56.6, z = -62.9 },
	{ name = "Inno_Yellow_Flowers", x = 52.6, z = -59.8 },
}

-- Props that count in the report. The same lists as 08-route.
local SOLID_LOOKING_PROPS: { [string]: boolean } = {
	Nature_Bush = true,
	Nature_BerryBush = true,
	Nature_FloweringBush = true,
	GateBush = true,
	Nature_MossyBoulder = true,
	Nature_MediumRock = true,
	Nature_Stump = true,
	Inno_Mushroom_02 = true,
	Inno_Mushroom_03 = true,
}
local FLOWER_CLUMPS: { [string]: boolean } = {
	Inno_Blue_Flowers = true,
	Inno_Pink_Flowers = true,
	Inno_White_Flowers = true,
	Inno_Yellow_Flowers = true,
	Nature_FlowerPatch = true,
}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- The Models directly under `folder` with this name whose bounding box middle is where the entry says.
local function findMatches(folder: Instance, entry: Entry): { Model }
	local matches: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.Name == entry.name then
			local middle = child:GetBoundingBox().Position
			if (flat(middle) - Vector3.new(entry.x, 0, entry.z)).Magnitude <= SAME_PLACE then
				table.insert(matches, child)
			end
		end
	end
	return matches
end

local function label(entry: Entry): string
	return string.format("%s at (%.1f, %.1f)", entry.name, entry.x, entry.z)
end

local function behindReport(world: Instance, nature: Instance, face: Vector3): { string }
	local spots: { BasePart } = {}
	for _, spot in (world:FindFirstChild("LandingSpots") :: Instance):GetChildren() do
		if spot:IsA("BasePart") then
			table.insert(spots, spot)
		end
	end
	table.sort(spots, function(a, b)
		return a.Name < b.Name
	end)

	local props: { Prop } = {}
	for _, instance in nature:GetDescendants() do
		if instance:IsA("Model") then
			local name = instance.Name
			if name == "Nature_Sunflower" or SOLID_LOOKING_PROPS[name] or FLOWER_CLUMPS[name] then
				local prop: Prop = { name = instance.Name, middle = instance:GetBoundingBox().Position }
				table.insert(props, prop)
			end
		end
	end

	local lines: { string } = {}
	for _, spot in spots do
		local away = flat(spot.Position - face)
		if away.Magnitude < 0.001 then
			table.insert(lines, `{spot.Name}: cannot tell which way is behind (the spot is under his face)`)
			continue
		end
		local back = away.Unit
		local side = Vector3.new(-back.Z, 0, back.X)
		local found: { string } = {}
		for _, prop in props do
			local offset = flat(prop.middle - spot.Position)
			local distanceBack = offset:Dot(back)
			local distanceSide = offset:Dot(side)
			if distanceBack >= BEHIND_MIN and distanceBack <= BEHIND_MAX and math.abs(distanceSide) <= BEHIND_SIDE then
				table.insert(
					found,
					string.format(
						"%s at (%.1f, %.1f), %.1f studs back and %.1f to the side",
						prop.name,
						prop.middle.X,
						prop.middle.Z,
						distanceBack,
						math.abs(distanceSide)
					)
				)
			end
		end
		table.sort(found)
		table.insert(lines, `{spot.Name}: ` .. (if #found == 0 then "clear" else table.concat(found, "; ")))
	end
	return lines
end

local function run(): string
	-- Check everything first, so a problem stops the script before anything changes.
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local nature = world:FindFirstChild("Nature")
	if nature == nil then
		error("Workspace.World.Nature is missing")
	end
	local giant = world:FindFirstChild("Giant")
	local sleepEyes = if giant then giant:FindFirstChild("SleepEyes") else nil
	if sleepEyes == nil or not sleepEyes:IsA("PVInstance") then
		error("Workspace.World.Giant.SleepEyes is missing")
	end
	if world:FindFirstChild("LandingSpots") == nil then
		error("Workspace.World.LandingSpots is missing")
	end
	local artLibrary = ServerStorage:FindFirstChild("ArtLibrary")
	if artLibrary == nil then
		error("ServerStorage.ArtLibrary is missing")
	end
	local removedNature = artLibrary:FindFirstChild("RemovedNature")

	local toMove: { { entry: Entry, model: Model } } = {}
	local alreadyDone = 0
	for _, entry in REMOVED_PROPS do
		local inMeadow = findMatches(nature, entry)
		local inRemoved = if removedNature then findMatches(removedNature, entry) else {}
		if #inMeadow == 1 and #inRemoved == 0 then
			table.insert(toMove, { entry = entry, model = inMeadow[1] })
		elseif #inMeadow == 0 and #inRemoved == 1 then
			alreadyDone += 1
		else
			error(
				`{label(entry)}: found {#inMeadow} in World.Nature and {#inRemoved} in RemovedNature (expected 1 and 0, or 0 and 1)`
			)
		end
	end

	if #toMove == 0 then
		return "already done"
	end

	if removedNature == nil then
		local folder = Instance.new("Folder")
		folder.Name = "RemovedNature"
		folder.Parent = artLibrary
		removedNature = folder
	end
	local target = removedNature :: Instance

	pcall(function()
		ChangeHistoryService:SetWaypoint("10-clear-landing-views: before")
	end)
	local lines: { string } = {}
	for _, item in toMove do
		item.model.Parent = target
		table.insert(lines, `moved {label(item.entry)}`)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("10-clear-landing-views: after")
	end)

	table.insert(lines, `{#toMove} moved to ServerStorage.ArtLibrary.RemovedNature, {alreadyDone} were already done`)
	table.insert(lines, "Props still behind each landing spot (1 to 14 studs back, 3 to each side):")
	for _, line in behindReport(world, nature, (sleepEyes :: PVInstance):GetPivot().Position) do
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
