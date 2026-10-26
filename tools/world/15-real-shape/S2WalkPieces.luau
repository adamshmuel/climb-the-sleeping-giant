--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2: walk pieces (stuck safety Task 24, legs and belly)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2WalkParts = require(script.Parent.S2WalkParts)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local describePlace = Shared.describePlace
local sameAs = Shared.sameAs
local GUARD_FOLDER_NAME = S2WalkParts.GUARD_FOLDER_NAME
local OLD_NAMES = S2WalkParts.OLD_NAMES
local OLD_WIDTH = S2WalkParts.OLD_WIDTH
local OLD_THICKNESS = S2WalkParts.OLD_THICKNESS
local OLD_PIECES = S2WalkParts.OLD_PIECES
type NewPart = S2WalkParts.NewPart
local SLIPPERY = S2WalkParts.SLIPPERY
local COMMON_PARTS = S2WalkParts.COMMON_PARTS
local FIRST_RUN_KNEE_PARTS = S2WalkParts.FIRST_RUN_KNEE_PARTS
local FINAL_KNEE_PARTS = S2WalkParts.FINAL_KNEE_PARTS
local FINAL_PARTS = S2WalkParts.FINAL_PARTS
local partProblems = S2WalkParts.partProblems
local findPart = S2WalkParts.findPart
local makePart = S2WalkParts.makePart

local function sectionWalkPieces(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	-- what stands in the folder now
	local oldFound: { BasePart } = {}
	local rampsFound: { BasePart } = {}
	for _, child in walk:GetChildren() do
		if child:IsA("BasePart") and OLD_NAMES[child.Name] then
			table.insert(oldFound, child)
		elseif child:IsA("BasePart") and child.Name:match("^CrossingRamp_") then
			table.insert(rampsFound, child)
		end
	end
	local guardFolder = walk:FindFirstChild(GUARD_FOLDER_NAME)

	-- Four states are known; anything else stops with nothing changed.
	--   (c) the final world: already done.
	--   (d) the final shape with the two knee guards still on the material's own friction (the world after an earlier
	--       run of this section): only their friction is set (Ruling 12).
	--   (b) the first run's world: the step piece, the ankle ramp and its guards are final, and the knee ramp and its two
	--       guards are the first-run ones. Those three go; the long ramp and its guards come in.
	--   (a) V1's world: all 33 old pieces, and nothing of the new work. All 33 go; the final parts come in.
	local fromFirstRun = false
	local problems: { string } = {}
	if #oldFound == 1 and #rampsFound == 2 and guardFolder ~= nil then
		local finalProblems = partProblems(walk, guardFolder, FINAL_PARTS, true)
		if #finalProblems == 0 then
			return string.format(
				"already done: the step piece, CrossingRamp_Ankle, the long CrossingRamp_Knee and the 4 guards (the 2 knee guards frictionless) are as recorded and none of the 33 old pieces is left (%d parts under World.WalkSurfaces, %d in all)",
				#walk:GetChildren(),
				#walk:GetDescendants()
			)
		end
		local firstRunRecords: { NewPart } = {}
		for _, record in COMMON_PARTS do
			table.insert(firstRunRecords, record)
		end
		for _, record in FIRST_RUN_KNEE_PARTS do
			table.insert(firstRunRecords, record)
		end
		-- (d) the final shape and settings with only the two knee guards' friction missing (Ruling 12): set only that
		if #partProblems(walk, guardFolder, FINAL_PARTS, false) == 0 then
			local lines: { string } = {}
			pcall(function()
				ChangeHistoryService:SetWaypoint("15-real-shape section 2 friction: before")
			end)
			for _, record in FINAL_PARTS do
				if record.slippery == true then
					findPart(guardFolder, record).CustomPhysicalProperties = SLIPPERY
				end
			end
			pcall(function()
				ChangeHistoryService:SetWaypoint("15-real-shape section 2 friction: after")
			end)
			table.insert(lines, "Knee_Guard_1 and Knee_Guard_2: friction 0 (was the material's)")
			table.insert(
				lines,
				string.format(
					"started from the final shape with plain knee guards; nothing else changed (%d parts under World.WalkSurfaces, %d in all)",
					#walk:GetChildren(),
					#walk:GetDescendants()
				)
			)
			return table.concat(lines, "\n")
		end
		local firstRunProblems = partProblems(walk, guardFolder, firstRunRecords, false)
		if #firstRunProblems == 0 then
			fromFirstRun = true
		else
			error(
				"nothing was changed. The new parts are neither the final ones ("
					.. table.concat(finalProblems, "; ")
					.. ") nor the first run's ("
					.. table.concat(firstRunProblems, "; ")
					.. ")"
			)
		end
	end

	-- V1's world: all 33 old pieces as recorded, and nothing of the new work.
	local matches: { BasePart } = {}
	if not fromFirstRun then
		if #rampsFound > 0 or guardFolder ~= nil then
			table.insert(
				problems,
				"a CrossingRamp_* part or the CrossingGuards folder is there, but the old pieces are too"
			)
		end
		if #oldFound ~= #OLD_PIECES then
			table.insert(problems, `{#oldFound} old pieces found, expected {#OLD_PIECES}`)
		end
		local taken: { [BasePart]: boolean } = {}
		for index, record in OLD_PIECES do
			local size = Vector3.new(OLD_WIDTH, OLD_THICKNESS, record.length)
			local found: BasePart? = nil
			for _, piece in oldFound do
				if not taken[piece] and piece.Name == record.name and piece.ClassName == "Part" then
					if sameAs(piece, size, record.cframe) then
						found = piece
						break
					end
				end
			end
			if found == nil then
				table.insert(
					problems,
					`old piece {index} ({record.name} at {describePlace(record.cframe)}) is not there as recorded`
				)
			else
				taken[found] = true
				matches[index] = found
			end
		end
		if #problems > 0 then
			error("nothing was changed. " .. table.concat(problems, "; "))
		end
	end

	-- Build the new parts away from the Workspace. From V1's world that is every final part; from the first run's world
	-- it is the long knee ramp and its 2 guards.
	local toBuild: { NewPart } = if fromFirstRun then FINAL_KNEE_PARTS else FINAL_PARTS
	local staging = Instance.new("Folder")
	staging.Name = "Task24Staging"
	staging.Archivable = false
	local stagedGuards = Instance.new("Folder")
	stagedGuards.Name = GUARD_FOLDER_NAME
	stagedGuards.Parent = staging
	for _, record in toBuild do
		makePart(record, if record.folder ~= nil then stagedGuards else staging)
	end

	local childrenBefore, descendantsBefore = #walk:GetChildren(), #walk:GetDescendants()
	local lines: { string } = {}
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2: before")
	end)
	if fromFirstRun then
		-- the first run's knee ramp and its 2 guards go (their old size and place are in the report)
		local liveGuards = guardFolder :: Instance
		for _, record in FIRST_RUN_KNEE_PARTS do
			local piece = findPart(if record.folder ~= nil then liveGuards else walk, record)
			table.insert(
				lines,
				string.format(
					"removed %s%s (first run): %.3f x %.3f x %.3f at %s",
					if record.folder ~= nil then `{record.folder}.` else "",
					record.name,
					piece.Size.X,
					piece.Size.Y,
					piece.Size.Z,
					describePlace(piece.CFrame)
				)
			)
			piece:Destroy()
		end
		for _, part in stagedGuards:GetChildren() do
			part.Parent = liveGuards
		end
		stagedGuards:Destroy()
		for _, part in staging:GetChildren() do
			part.Parent = walk
		end
	else
		for index, record in OLD_PIECES do
			local piece = matches[index]
			table.insert(
				lines,
				string.format(
					"removed %s %d: %.2f x %.2f x %.2f at %s",
					record.name,
					index,
					piece.Size.X,
					piece.Size.Y,
					piece.Size.Z,
					describePlace(piece.CFrame)
				)
			)
			piece:Destroy()
		end
		for _, part in staging:GetChildren() do
			if part ~= stagedGuards then
				part.Parent = walk
			end
		end
		stagedGuards.Parent = walk
	end
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2: after")
	end)
	for _, record in toBuild do
		table.insert(
			lines,
			string.format(
				"added %s%s: %s %.3f x %.3f x %.3f at %s",
				if record.folder ~= nil then `{record.folder}.` else "",
				record.name,
				record.className,
				record.size.X,
				record.size.Y,
				record.size.Z,
				describePlace(record.cframe)
			)
		)
	end
	local walkSurfaces = 0 -- what the test "no walk surface on the route is steeper than 60 degrees" counts
	for _, child in walk:GetChildren() do
		if child:IsA("BasePart") and (child.Name:match("_Walk$") or child.Name:match("^CrossingRamp_")) then
			walkSurfaces += 1
		end
	end
	for _, side in { "BootRamp", "RightBootRamp" } do
		local ramp = walk:FindFirstChild(side)
		if ramp ~= nil and ramp:FindFirstChild("Ramp_Walk") ~= nil then
			walkSurfaces += 1
		end
	end
	table.insert(
		lines,
		string.format(
			"started from %s; parts directly under World.WalkSurfaces: %d before, %d after; in all (with the folders' children): %d before, %d after",
			if fromFirstRun then "the first run's world" else "V1's world (33 old pieces)",
			childrenBefore,
			#walk:GetChildren(),
			descendantsBefore,
			#walk:GetDescendants()
		)
	)
	table.insert(
		lines,
		`walk surfaces on the route now (parts named *_Walk or CrossingRamp_*, plus the 2 ramp planks): {walkSurfaces} (ROUTE_SURFACE_COUNT in RealWorld.spec)`
	)
	return table.concat(lines, "\n")
end

return sectionWalkPieces
