--!strict
-- World prep, plan 5 Task 8 (first part of the nests script): the refill pop's star burst goes into the place
-- (card work/p5t8/p5t8-card.md; spec 5 Rule 77 and section 6 "A new egg appears"; style guide
-- docs/design/v2/style-guide/nests-art.md lines 32-49).
-- Why: the client's NestPop (src/client/Fx/NestPop.luau) clones ReplicatedStorage.Assets.RefillPop when a nest gets its
-- egg back. The 4 mockup copies in Workspace.Mockup_Nests.Art.RefillPop are all the same, so the Common one is the source.
-- What it does: clones Workspace.Mockup_Nests.Art.RefillPop.RefillPop_Common.SparkleShell (a see-through Part holding one
-- ParticleEmitter, Sparkles) to ReplicatedStorage.Assets.RefillPop, anchored, with CanCollide, CanQuery and CanTouch off.
-- It adds only: 1 new part (plus its emitter). Nothing existing is touched, so there is no backup clone.
-- STOP (nothing changed, the reason is reported): Assets or the source missing; the source not a BasePart with exactly 1
-- ParticleEmitter; an Assets.RefillPop that is there but is not a BasePart holding a ParticleEmitter.
-- An Assets.RefillPop that is already right = "already done".
-- CHECK_ONLY = true looks and prints only. More tasks add their nest parts to this script later.
--
-- Second part, plan 5 fix 2 Step 3 (card work/p5fix2/p5fix2-card.md; spec 5 Rule 85): the invisible EggPost on every
-- Common meadow spot (EggSpots models whose Rarity is Common; eggs on him are never touched).
-- A post is a roof ridge: 2 WedgeParts back to back, base 2 x Config.Nests.PostClear.HalfBase (0.4 of the Common egg's
-- width each side), faces at FACE_DEGREES (75 or steeper), no flat top, invisible, anchored, CanCollide false (the server's
-- SpotModels turns it solid while the egg waits). Each is the Folder "EggPost" inside the spot model.
-- It adds only: PLANNED_POST_SPOTS Folders with 2 wedge parts each. Before changing anything it clones the spot models to
-- ServerStorage.WorldBackups.p5t12.PostSpots. A spot that already has an EggPost is skipped; all of them = "already done".
-- STOP (nothing changed): the Common egg template missing; Config HalfBase not within HALF_BASE_MARGIN of 0.4 x the egg
-- width; the number of spots to change not PLANNED_POST_SPOTS. The CHECK_ONLY pass also builds a test pair at
-- TEST_HEIGHT, rays it and destroys it in the same call.
-- Task 12 (2026-11-10): runs after 21b-nest-models (which makes the 38 nest models and WorldBackups.p5t12). BACKUP_NAME is
-- p5t12 and PLANNED_POST_SPOTS is 16. The backup reuses that folder: the spot models go in its PostSpots child.
-- Run in Studio EDIT mode: paste this file's text with execute_luau. The place file must be saved afterwards (the
-- template lives in the place file, not in the Rojo tree).

local CHECK_ONLY = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- How many parts this script adds, as planned in the card (the one template).
local PLANNED_PARTS = 1
local TEMPLATE_NAME = "RefillPop"

-- The emitter's first colour as a hex word, for the report.
local function emitterLine(emitter: ParticleEmitter): string
	local first = emitter.Color.Keypoints[1].Value
	return `emitter {emitter.Name}, colour #{first:ToHex()}`
end

-- The one ParticleEmitter in a part's children, or nil when there is none or more than one.
local function onlyEmitter(part: Instance): ParticleEmitter?
	local found: ParticleEmitter? = nil
	for _, child in part:GetChildren() do
		if child:IsA("ParticleEmitter") then
			if found ~= nil then
				return nil
			end
			found = child
		end
	end
	return found
end

local function runTemplate(): string
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return "STOP: ReplicatedStorage.Assets is missing, nothing changed"
	end
	local mockup = Workspace:FindFirstChild("Mockup_Nests")
	local art = if mockup then mockup:FindFirstChild("Art") else nil
	local group = if art then art:FindFirstChild("RefillPop") else nil
	local common = if group then group:FindFirstChild("RefillPop_Common") else nil
	local source = if common then common:FindFirstChild("SparkleShell") else nil
	if source == nil or not source:IsA("BasePart") then
		return "STOP: Workspace.Mockup_Nests.Art.RefillPop.RefillPop_Common.SparkleShell is missing or not a part, nothing changed"
	end
	local sourceEmitter = onlyEmitter(source)
	if sourceEmitter == nil then
		return "STOP: the SparkleShell does not hold exactly 1 ParticleEmitter, nothing changed"
	end

	local existing = assets:FindFirstChild(TEMPLATE_NAME)
	if existing ~= nil then
		if not existing:IsA("BasePart") then
			return "STOP: Assets.RefillPop is there but is not a part, nothing changed"
		end
		local emitter = onlyEmitter(existing)
		if emitter == nil then
			return "STOP: Assets.RefillPop is there but holds no single ParticleEmitter, nothing changed"
		end
		return `already done: {existing:GetFullName()} {emitterLine(emitter)}`
	end

	local willAdd = 1
	print(`21-nests: will add {willAdd} part (plan: {PLANNED_PARTS})`)
	if willAdd ~= PLANNED_PARTS then
		return `STOP: {willAdd} parts, the plan is {PLANNED_PARTS}, nothing changed`
	end
	if CHECK_ONLY then
		return `CHECK_ONLY: would add 1 part, Assets.RefillPop, from {source:GetFullName()}, {emitterLine(sourceEmitter)}`
	end

	ChangeHistoryService:SetWaypoint("21-nests: before")
	local copy = source:Clone()
	copy.Name = TEMPLATE_NAME
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Parent = assets
	ChangeHistoryService:SetWaypoint("21-nests: after")

	local emitter = onlyEmitter(copy)
	if emitter == nil then
		return "STOPPED: the copy lost its emitter"
	end
	return `added 1 part: {copy:GetFullName()} {emitterLine(emitter)}`
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Part 2: the EggPost on every Common meadow spot.

local ServerStorage = game:GetService("ServerStorage")

local POST_NAME = "EggPost"
local BACKUP_FOLDER = "WorldBackups"
local BACKUP_NAME = "p5t12"
local PLANNED_POST_SPOTS = 16 -- the 16 Common meadow nests (plan 5 Task 12; 21b builds the models first)
local PARTS_PER_POST = 2
local WIDTH_SHARE = 0.8 -- the post's base is this share of the egg's width
local FACE_DEGREES = 75.2 -- the steepness of each face (the rule says 75 or steeper)
local MIN_FACE_DEGREES = 74.9
local HALF_BASE_MARGIN = 0.05
local TEST_HEIGHT = 5000 -- where the CHECK_ONLY test pair is built (empty sky)
local GRID = 0.1

local function includeOnly(parts: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	return params
end

-- +1 when a WedgePart's top rises toward +Z, -1 when it rises toward -Z (tested with a probe, not remembered).
local function slopeSign(): number
	local probe = Instance.new("WedgePart")
	probe.Anchored = true
	probe.Size = Vector3.new(2, 4, 2)
	probe.CFrame = CFrame.new(0, TEST_HEIGHT, 0)
	probe.Parent = Workspace
	local params = includeOnly({ probe })
	local function topAt(z: number): number
		local hit = Workspace:Raycast(Vector3.new(0, TEST_HEIGHT + 10, z), Vector3.new(0, -20, 0), params)
		return if hit then hit.Position.Y else -math.huge
	end
	local sign = if topAt(0.8) > topAt(-0.8) then 1 else -1
	probe:Destroy()
	return sign
end

-- Makes the 2 wedges of one post inside `folder`, standing on `base` (the egg's bottom centre).
local function buildPost(folder: Folder, base: Vector3, halfBase: number, height: number, sign: number): { WedgePart }
	local made = {}
	for index = 1, PARTS_PER_POST do
		local side = if index == 1 then -sign else sign
		local wedge = Instance.new("WedgePart")
		wedge.Name = `Ridge_{index}`
		wedge.Size = Vector3.new(halfBase * 2, height, halfBase)
		local at = CFrame.new(base + Vector3.new(0, height / 2, side * halfBase / 2))
		wedge.CFrame = if index == 1 then at else at * CFrame.Angles(0, math.pi, 0)
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanTouch = false
		wedge.CastShadow = false
		wedge.Transparency = 1
		wedge.Parent = folder
		table.insert(made, wedge)
	end
	return made
end

-- Rays down over the post's footprint. Prints the apex height over the base, the flattest face found (degrees from
-- level) and how wide the strip within 0.5 studs of the apex is.
local function rayReport(root: Instance, base: Vector3, halfBase: number, height: number): string
	local params = includeOnly({ root })
	local steps = math.floor(halfBase / GRID)
	local hits, apex, flattest = 0, -math.huge, math.huge
	local heights: { [number]: number } = {}
	for xi = -steps, steps do
		for zi = -steps, steps do
			local origin = base + Vector3.new(xi * GRID, height + 5, zi * GRID)
			local hit = Workspace:Raycast(origin, Vector3.new(0, -(height + 10), 0), params)
			if hit then
				hits += 1
				local up = hit.Position.Y - base.Y
				apex = math.max(apex, up)
				flattest = math.min(flattest, math.deg(math.acos(math.clamp(hit.Normal.Y, -1, 1))))
				if xi == 0 then
					heights[zi] = up
				end
			end
		end
	end
	local strip = 0
	for _, up in heights do
		if up >= apex - 0.5 then
			strip += 1
		end
	end
	return `{hits} hits, apex {string.format("%.2f", apex)} over the base, flattest face {string.format(
		"%.1f",
		flattest
	)} deg, strip within 0.5 of the apex {string.format("%.1f", strip * GRID)} wide`
end

local function runPosts(): string
	-- A clone, because in Edit a plain require returns the copy Studio cached first (studio-jobs).
	local shared = ReplicatedStorage:FindFirstChild("Shared") :: Folder
	local configModule = shared:FindFirstChild("Config") :: ModuleScript
	local requireModule: (ModuleScript) -> any = require :: any
	local config = requireModule(configModule:Clone())
	local halfBase: number = config.Nests.PostClear.HalfBase
	local serverAssets = ServerStorage:FindFirstChild("Assets")
	local eggs = if serverAssets then serverAssets:FindFirstChild("Eggs") else nil
	local template = if eggs then eggs:FindFirstChild("Common") else nil
	if template == nil or not template:IsA("Model") then
		return "STOP (posts): ServerStorage.Assets.Eggs.Common is missing, nothing changed"
	end
	local _, size = template:GetBoundingBox()
	local width = math.max(size.X, size.Z)
	local wanted = width * WIDTH_SHARE / 2
	local lines = {
		`egg width {string.format("%.3f", width)}, wanted half base {string.format("%.3f", wanted)}, Config half base {halfBase}`,
	}
	if math.abs(wanted - halfBase) > HALF_BASE_MARGIN then
		table.insert(
			lines,
			`STOP (posts): Config HalfBase {halfBase} is not within {HALF_BASE_MARGIN} of {string.format("%.3f", wanted)}, nothing changed`
		)
		return table.concat(lines, "\n")
	end
	local height = halfBase * math.tan(math.rad(FACE_DEGREES))

	local spots = Workspace:FindFirstChild("World"):FindFirstChild("EggSpots")
	local todo: { Model } = {}
	local have = 0
	local common = 0
	for _, spot in spots:GetChildren() do
		if spot:IsA("Model") and spot:GetAttribute("Rarity") == "Common" then
			common += 1
			if spot:FindFirstChild(POST_NAME) then
				have += 1
			else
				table.insert(todo, spot)
			end
		end
	end
	table.insert(
		lines,
		`Common spots {common}, with a post {have}, without {#todo}; apex {string.format("%.2f", height)} over the egg base`
	)
	if #todo == 0 then
		table.insert(lines, `already done: {have} posts`)
		return table.concat(lines, "\n")
	end

	local sign = slopeSign()
	table.insert(lines, `wedge rises toward {if sign > 0 then "+Z" else "-Z"}`)
	-- The test pair proves the shape in empty sky before anything is added to the world.
	local testFolder = Instance.new("Folder")
	testFolder.Name = "PostTest"
	testFolder.Parent = Workspace
	local testBase = Vector3.new(0, TEST_HEIGHT, 0)
	buildPost(testFolder, testBase, halfBase, height, sign)
	table.insert(lines, `test pair: {rayReport(testFolder, testBase, halfBase, height)}`)
	testFolder:Destroy()
	local flatTest = string.match(lines[#lines], "flattest face ([%d%.]+)")
	if tonumber(flatTest) == nil or (tonumber(flatTest) :: number) < MIN_FACE_DEGREES then
		table.insert(lines, "STOP (posts): the test pair has a face flatter than 75 degrees, nothing changed")
		return table.concat(lines, "\n")
	end

	local willAddParts = #todo * PARTS_PER_POST
	print(`21-nests: will add {#todo} posts, {willAddParts} parts (plan: {PLANNED_POST_SPOTS} posts)`)
	if #todo ~= PLANNED_POST_SPOTS then
		table.insert(lines, `STOP (posts): {#todo} posts to add, the plan is {PLANNED_POST_SPOTS}, nothing changed`)
		return table.concat(lines, "\n")
	end
	if CHECK_ONLY then
		table.insert(
			lines,
			`CHECK_ONLY: would add {#todo} posts ({willAddParts} parts) and back up {#todo} spot models`
		)
		return table.concat(lines, "\n")
	end

	-- Backup first: the spot models, as they are now.
	local backups = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	if backups == nil then
		return "STOP (posts): ServerStorage.WorldBackups is missing, nothing changed"
	end
	ChangeHistoryService:SetWaypoint("21-nests posts: before")
	local holder = backups:FindFirstChild(BACKUP_NAME)
	if holder == nil then
		holder = Instance.new("Folder")
		holder.Name = BACKUP_NAME
		holder.Parent = backups
	end
	if holder:FindFirstChild("PostSpots") then
		return `STOP (posts): WorldBackups.{BACKUP_NAME}.PostSpots is already there, nothing changed`
	end
	local backup = Instance.new("Folder")
	backup.Name = "PostSpots"
	for _, spot in todo do
		spot:Clone().Parent = backup
	end
	backup.Parent = holder
	table.insert(lines, `backed up {#backup:GetChildren()} spot models to {backup:GetFullName()}`)

	local firstFolder: Folder? = nil
	local firstBase = Vector3.zero
	for _, spot in todo do
		local base = spot:FindFirstChild("Base") :: BasePart
		local bottom = (base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)).Position
		local folder = Instance.new("Folder")
		folder.Name = POST_NAME
		buildPost(folder, bottom, halfBase, height, sign)
		folder.Parent = spot
		if firstFolder == nil then
			firstFolder = folder
			firstBase = bottom
		end
	end
	ChangeHistoryService:SetWaypoint("21-nests posts: after")
	table.insert(lines, `added {#todo} posts, {willAddParts} parts`)
	if firstFolder then
		table.insert(lines, `first post: {rayReport(firstFolder, firstBase, halfBase, height)}`)
	end
	return table.concat(lines, "\n")
end

local function runAll(): string
	return runTemplate() .. "\n" .. runPosts()
end

local ok, message = pcall(runAll)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
