--!strict
-- World prep, task 16: the egg spots and the egg models (spec Rule 3, "Eggs wait in three zones").
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every step checks first, so a second run changes nothing and says "already done".
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
-- Nothing is deleted: the mockup eggs go to ServerStorage.ArtLibrary.MockupEggs.
--
-- 1. ServerStorage.Assets.Eggs gets one egg model per rarity (Common, Uncommon, Rare), copied from the approved
--    mockup eggs. Each is fully anchored and does not collide, has no glow ring (the ring belongs to the spot),
--    and its pivot is at the bottom centre of the egg, so `PivotTo(spot.cframe)` stands it on a spot.
-- 2. Workspace.World.EggSpots gets 16 spots: 8 Common in the meadow (one past each garden's bridge), 4 Uncommon
--    (2 on each boot top) and 4 Rare along the belly path. Each spot is a Model with a Rarity attribute, an
--    invisible Base whose top is where the egg's bottom sits, a PromptAnchor for the hold prompt, and (meadow
--    only) its own glow ring. Every spot is always sent to players.
-- 2b. A spot whose place differs from its table entry (by more than half a stud) is moved to the table place:
--    its Base, its prompt anchor (it rides on the Base) and, on Common spots, its glow ring.
-- 3. The mockup eggs leave Workspace.World.Eggs. The emptied folder goes with them, so World has no Eggs folder.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Where each spot is: x and z only. The height and the lean come from the surface found under the point.
-- Common: past each garden's bridge, on flat grass that no flower, rock or prop touches, 34 to 43 studs
-- (a few seconds' walk) from that garden's spawn spot. Index = garden number.
local COMMON_SPOTS: { { number } } = {
	{ -94, 1 },
	{ -88, -32 },
	{ -54, -86 },
	{ -36, -85 },
	{ 36, -85 },
	{ 59, -73 },
	{ 88, -32 },
	{ 93, 12 },
}
-- Uncommon: on the boot tops (the walk surfaces), 2 on each.
local UNCOMMON_SPOTS: { { number } } = {
	{ -26, -62.5 },
	{ -21.5, -55.5 },
	{ 26, -61.5 },
	{ 21.5, -55 },
}
-- Rare: along the belly path, from low to high. The last one is on the right edge so it stays clear of the beard ladder.
local RARE_SPOTS: { { number } } = {
	{ -12.5, -40.3 },
	{ -11.2, -34.8 },
	{ -8.1, -30.7 },
	{ 2.5, -29.5 },
}

-- The mockup egg each template is made from.
local TEMPLATE_SOURCES: { { string } } = {
	{ "Common", "Egg_Meadow1" },
	{ "Uncommon", "Egg_Boot1" },
	{ "Rare", "Egg_Belly1" },
}

local BASE_SIZE = Vector3.new(2, 0.2, 2)
local PROMPT_HEIGHT = 2 -- studs above the top of the Base
-- The belly path is steep (up to 58 degrees), so an upright egg would sink into its uphill side. A Rare spot is
-- tilted this fraction of the way from straight up to the surface's own up direction (0 = upright, 1 = flat on it).
-- At 0.5 the egg leans about 28 degrees toward the climber and nothing of it is buried.
local BELLY_LEAN = 0.5
local RING_LIFT = 0.02 -- the glow ring's middle sits this far above the grass, so its 0.2 thick top shows

local MOVE_LIMIT = 0.5 -- studs: a spot closer than this to its table place counts as already there

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

-- The first solid thing under (x, z): a ray from high above that skips everything a player walks through
-- (the glow rings, the zone boxes, the eggs). Stops with an error if nothing is there.
local function surfaceAt(world: Instance, x: number, z: number): RaycastResult
	local ignore: { Instance } = {}
	local zones = world:FindFirstChild("Zones")
	if zones then
		table.insert(ignore, zones)
	end
	for _ = 1, 40 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -500, 0), params)
		if hit == nil then
			error(`nothing solid at ({x}, {z})`)
		end
		if hit.Instance.CanCollide then
			return hit
		end
		table.insert(ignore, hit.Instance)
	end
	error(`too many see-through parts at ({x}, {z})`)
end

-- Where a spot goes, worked out from its table place. Making a spot and moving one both use this, so they
-- agree. The Base lies in the leaned plane with its top centre on the surface; the ring (Commons) lies flat on it.
type SpotShape = { top: Vector3, up: Vector3, baseCFrame: CFrame, ringCFrame: CFrame, surfaceName: string }
local function spotShape(
	world: Instance,
	rarity: string,
	number: number,
	x: number,
	z: number,
	ringRotation: CFrame
): SpotShape
	local hit = surfaceAt(world, x, z)
	if hit.Material == Enum.Material.Water then
		error(`{rarity} spot {number} at ({x}, {z}) is in the water`)
	end
	if rarity == "Common" and (hit.Instance ~= Workspace.Terrain or hit.Normal.Y < 0.98) then
		error(`Common spot {number} at ({x}, {z}) is not on flat grass (found {hit.Instance:GetFullName()})`)
	end
	local top = hit.Position
	local lean = if rarity == "Rare" then BELLY_LEAN else 0
	local up = Vector3.new(0, 1, 0):Lerp(hit.Normal, lean).Unit
	local right = up:Cross(Vector3.zAxis).Unit
	return {
		top = top,
		up = up,
		baseCFrame = CFrame.fromMatrix(top - up * (BASE_SIZE.Y / 2), right, up),
		ringCFrame = CFrame.new(top + Vector3.new(0, RING_LIFT, 0)) * ringRotation,
		surfaceName = hit.Instance.Name,
	}
end

-- The height, in studs, from the lowest corner of the egg's parts to the top, and where its middle is.
local function eggBounds(egg: Model): (Vector3, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in egg:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						low =
							Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
						high = Vector3.new(
							math.max(high.X, corner.X),
							math.max(high.Y, corner.Y),
							math.max(high.Z, corner.Z)
						)
					end
				end
			end
		end
	end
	return low, high
end

local function run(): any
	pcall(function()
		ChangeHistoryService:SetWaypoint("04-egg-spots: before")
	end)

	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local artLibrary = ServerStorage:FindFirstChild("ArtLibrary")
	if artLibrary == nil then
		error("ServerStorage.ArtLibrary is missing (run 01-gardens first)")
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	if assets == nil then
		error("ServerStorage.Assets is missing (run 01-gardens first)")
	end

	-- A mockup egg: still in World.Eggs on the first run, in ArtLibrary.MockupEggs after step 3.
	local function findMockup(name: string): Model
		for _, folder in { world:FindFirstChild("Eggs"), artLibrary:FindFirstChild("MockupEggs") } do
			local found = folder and folder:FindFirstChild(name)
			if found and found:IsA("Model") then
				return found
			end
		end
		error(`the mockup egg {name} is missing (it should be in World.Eggs or ArtLibrary.MockupEggs)`)
	end

	----------------------------------------------------------------------------------------------
	-- 1. The egg models in ServerStorage.Assets.Eggs
	----------------------------------------------------------------------------------------------
	local eggsFolder = getOrCreateFolder(assets, "Eggs")
	local made: { string } = {}
	for _, pair in TEMPLATE_SOURCES do
		local rarity, sourceName = pair[1], pair[2]
		if eggsFolder:FindFirstChild(rarity) == nil then
			local egg = findMockup(sourceName):Clone()
			egg.Name = rarity
			-- the glow ring belongs to the spot: an empty meadow spot still shows a faded ring
			local ring = egg:FindFirstChild("GlowRing")
			if ring then
				ring:Destroy() -- only the copy; the mockup keeps its ring
			end
			for _, part in egg:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
			local low, high = eggBounds(egg)
			egg.WorldPivot = CFrame.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
			egg.Parent = eggsFolder
			table.insert(made, `{rarity} (from {sourceName}, {string.format("%.1f", high.Y - low.Y)} studs tall)`)
		end
	end
	say(
		"1 Egg models in ServerStorage.Assets.Eggs: "
			.. (if #made > 0 then table.concat(made, "; ") else "already done")
	)

	----------------------------------------------------------------------------------------------
	-- 2. The 16 egg spots in World.EggSpots
	----------------------------------------------------------------------------------------------
	local existingSpots = world:FindFirstChild("EggSpots")
	if existingSpots then
		local count = #existingSpots:GetChildren()
		if count == 16 then
			say("2 Egg spots: already done (16 spots)")
		else
			error(`World.EggSpots exists but has {count} children, not 16. Nothing was changed there.`)
		end
	else
		local ringSource = findMockup("Egg_Meadow1"):FindFirstChild("GlowRing")
		if ringSource == nil or not ringSource:IsA("BasePart") then
			error("Egg_Meadow1 has no GlowRing to copy")
		end
		local ringRotation = ringSource.CFrame.Rotation

		local spotsFolder = Instance.new("Folder")
		spotsFolder.Name = "EggSpots"
		local lines: { string } = {}

		local function makeSpot(rarity: string, number: number, x: number, z: number)
			local shape = spotShape(world, rarity, number, x, z, ringRotation)
			local top, up = shape.top, shape.up

			local spot = Instance.new("Model")
			spot.Name = `EggSpot_{rarity}_{number}`
			spot:SetAttribute("Rarity", rarity)
			spot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

			local base = Instance.new("Part")
			base.Name = "Base"
			base.Size = BASE_SIZE
			base.CFrame = shape.baseCFrame
			base.Anchored = true
			base.Transparency = 1
			base.CanCollide = false
			base.CanQuery = false
			base.CanTouch = false
			base.CastShadow = false
			base.Parent = spot

			local anchor = Instance.new("Attachment")
			anchor.Name = "PromptAnchor"
			anchor.Position = Vector3.new(0, BASE_SIZE.Y / 2 + PROMPT_HEIGHT, 0)
			anchor.Parent = base

			if rarity == "Common" then
				local ring = (ringSource :: BasePart):Clone()
				ring.Name = "GlowRing"
				ring.CFrame = shape.ringCFrame
				ring.Anchored = true
				ring.CanCollide = false
				ring.CanQuery = false
				ring.Parent = spot
			end
			spot.PrimaryPart = base
			spot.Parent = spotsFolder
			table.insert(
				lines,
				string.format(
					"%s (%.1f, %.1f, %.1f) on %s, leans %.0f degrees",
					spot.Name,
					top.X,
					top.Y,
					top.Z,
					shape.surfaceName,
					math.deg(math.acos(math.clamp(up.Y, -1, 1)))
				)
			)
		end

		for number, xz in COMMON_SPOTS do
			makeSpot("Common", number, xz[1], xz[2])
		end
		for number, xz in UNCOMMON_SPOTS do
			makeSpot("Uncommon", number, xz[1], xz[2])
		end
		for number, xz in RARE_SPOTS do
			makeSpot("Rare", number, xz[1], xz[2])
		end
		spotsFolder.Parent = world
		say("2 Egg spots made in World.EggSpots:\n   " .. table.concat(lines, "\n   "))
	end

	----------------------------------------------------------------------------------------------
	-- 2b. Spots that are not at their table place move there
	----------------------------------------------------------------------------------------------
	local spotTables: { [string]: { { number } } } = {
		Common = COMMON_SPOTS,
		Uncommon = UNCOMMON_SPOTS,
		Rare = RARE_SPOTS,
	}
	local movedLines: { string } = {}
	local spotsNow = world:FindFirstChild("EggSpots")
	if spotsNow then
		for _, spot in spotsNow:GetChildren() do
			local rarityText, numberText = string.match(spot.Name, "^EggSpot_(%a+)_(%d+)$")
			local rarity: string = rarityText or ""
			local number: number = tonumber(numberText) or 0
			local rows = spotTables[rarity]
			local place = if rows then rows[number] else nil
			local base = spot:FindFirstChild("Base")
			if place and base and base:IsA("BasePart") then
				local oldTop = base.CFrame:PointToWorldSpace(Vector3.new(0, base.Size.Y / 2, 0))
				local miss = (Vector2.new(oldTop.X, oldTop.Z) - Vector2.new(place[1], place[2])).Magnitude
				if miss > MOVE_LIMIT then
					local ringRotation = (findMockup("Egg_Meadow1"):FindFirstChild("GlowRing") :: BasePart).CFrame.Rotation
					local shape = spotShape(world, rarity, number, place[1], place[2], ringRotation)
					base.CFrame = shape.baseCFrame -- the PromptAnchor attachment rides on the Base
					local ring = spot:FindFirstChild("GlowRing")
					if ring and ring:IsA("BasePart") then
						ring.CFrame = shape.ringCFrame
					end
					table.insert(
						movedLines,
						string.format(
							"%s (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f)",
							spot.Name,
							oldTop.X,
							oldTop.Y,
							oldTop.Z,
							shape.top.X,
							shape.top.Y,
							shape.top.Z
						)
					)
				end
			end
		end
	end
	if #movedLines > 0 then
		say("2b Spot places moved:\n   " .. table.concat(movedLines, "\n   "))
	else
		say("2b Spot places: already done")
	end

	----------------------------------------------------------------------------------------------
	-- 3. The mockup eggs leave the world
	----------------------------------------------------------------------------------------------
	local mockEggs = world:FindFirstChild("Eggs")
	if mockEggs == nil then
		say("3 Mockup eggs: already done")
	else
		local keep = artLibrary:FindFirstChild("MockupEggs")
		if keep == nil then
			-- the whole folder moves, so nothing is left behind and nothing is deleted
			mockEggs.Name = "MockupEggs"
			mockEggs.Parent = artLibrary
			say(
				`3 Mockup eggs: World.Eggs moved to ServerStorage.ArtLibrary.MockupEggs ({#mockEggs:GetChildren()} eggs)`
			)
		else
			local moved = 0
			for _, egg in mockEggs:GetChildren() do
				egg.Parent = keep
				moved += 1
			end
			say(
				`3 Mockup eggs: {moved} eggs moved into the existing ArtLibrary.MockupEggs; the empty World.Eggs folder is left`
			)
		end
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("04-egg-spots: after")
	end)
	return nil
end

local ok, message = pcall(run)
if not ok then
	say("STOPPED WITH AN ERROR: " .. tostring(message))
end
return table.concat(report, "\n")
