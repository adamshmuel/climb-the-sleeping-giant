--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 4b: the two hidden brim blocks (stuck safety Task 54)
----------------------------------------------------------------------------------------------------------------------
-- At the top of the climb, by the Legendary brim nests, a player pushing along his forehead wedges for 2 to 4 seconds in
-- the crease under the cap's edge. Two invisible blocks fill most of that hollow. The player sees nothing new.
--
-- What it makes, in World.WalkSurfaces: BrimFill_PlusX and BrimFill_MinusX, the sizes and places in BrimPlaces. Each is
-- invisible, anchored, collides, can be hit by rays, and does not fire touch events.
-- What it removes: the folder Workspace.Mockup_Brim (the 10 non-colliding mock-up parts that measured the hollow).
--
-- It counts first and goes on only when the count is exactly "adding 2 parts, removing 1 folder". It finds
-- every part by its full path, never by a name search. On a second run, when both blocks match
-- BrimPlaces and Mockup_Brim is gone, it says "already done". A world it doesn't know (one block missing, a block in the
-- wrong place, a second copy, the mock-up folder changed) stops with nothing changed and names what differs.
-- The change runs between two ChangeHistoryService waypoints, with the blocks built away from the Workspace first, and
-- is checked again afterwards.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local BrimPlaces = require(script.Parent.BrimPlaces)
local PillowPlaces = require(script.Parent.PillowPlaces)

local EXPECTED_COUNT = "adding 2 parts, removing 1 folder"
local MOCKUP_NAME = "Mockup_Brim"
local MOCKUP_PARTS = 10
local STRAY_PREFIX = "BrimFill_"

local function fmt(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

-- What differs between a block in the world and its record, as short sentences. Empty when it matches.
local function blockProblems(block: BasePart, place: BrimPlaces.Block): { string }
	local problems: { string } = {}
	local tolerance = BrimPlaces.POSITION_TOLERANCE
	if not block:IsA("Part") then
		table.insert(problems, `{place.name}: is a {block.ClassName}, not a Part`)
		return problems
	end
	if (block.Size - place.size).Magnitude > tolerance then
		table.insert(problems, `{place.name}: size {fmt(block.Size)} is not {fmt(place.size)}`)
	end
	local movedBy = (block.Position - place.cframe.Position).Magnitude
	if movedBy > tolerance or not PillowPlaces.sameTurn(block.CFrame, place.cframe, tolerance) then
		table.insert(problems, `{place.name}: place {fmt(block.Position)} is not {fmt(place.cframe.Position)}`)
	end
	if
		block.Transparency ~= 1
		or not block.Anchored
		or not block.CanCollide
		or not block.CanQuery
		or block.CanTouch
	then
		table.insert(problems, `{place.name}: must be invisible, anchored, collide on, query on and touch off`)
	end
	return problems
end

local function makeBlock(place: BrimPlaces.Block): Part
	local part = Instance.new("Part")
	part.Name = place.name
	part.Size = place.size
	part.CFrame = place.cframe
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function sectionBrimFill(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	if world == nil or walk == nil then
		error("nothing was changed. Workspace.World.WalkSurfaces is missing")
	end

	-- Read the world: each block by its full path (a direct child of WalkSurfaces), and the mock-up folder.
	local problems: { string } = {}
	local missing: { BrimPlaces.Block } = {}
	for _, place in BrimPlaces.BLOCKS do
		local found = 0
		local only: Instance? = nil
		for _, child in walk:GetChildren() do
			if child.Name == place.name then
				found += 1
				only = child
			end
		end
		if found == 0 then
			table.insert(missing, place)
		elseif found > 1 then
			table.insert(problems, `World.WalkSurfaces has {found} parts called {place.name}`)
		elseif only ~= nil and only:IsA("BasePart") then
			for _, problem in blockProblems(only, place) do
				table.insert(problems, problem)
			end
		else
			table.insert(problems, `{place.name}: is not a part`)
		end
	end
	for _, descendant in world:GetDescendants() do
		if string.sub(descendant.Name, 1, #STRAY_PREFIX) == STRAY_PREFIX and descendant.Parent ~= walk then
			table.insert(problems, `{descendant:GetFullName()} is a brim block outside World.WalkSurfaces`)
		end
	end

	local mockups: { Instance } = {}
	for _, child in Workspace:GetChildren() do
		if child.Name == MOCKUP_NAME then
			table.insert(mockups, child)
		end
	end
	local mockup: Instance? = mockups[1]
	if #mockups > 1 then
		table.insert(problems, `Workspace has {#mockups} folders called {MOCKUP_NAME}`)
	elseif mockup ~= nil then
		local partCount = 0
		for _, descendant in mockup:GetDescendants() do
			if descendant:IsA("BasePart") then
				partCount += 1
				if descendant.CanCollide then
					table.insert(problems, `{descendant:GetFullName()} collides, so it is not the mock-up`)
				end
			end
		end
		if partCount ~= MOCKUP_PARTS then
			table.insert(problems, `{MOCKUP_NAME} holds {partCount} parts, not {MOCKUP_PARTS}`)
		end
	end

	-- Which world is this? "before" (both blocks missing, mock-up there) or "done" (both there, mock-up gone).
	local adding = #missing
	local removing = if mockup ~= nil then 1 else 0
	local isDone = adding == 0 and removing == 0
	if not isDone and not (adding == #BrimPlaces.BLOCKS and removing == 1) then
		table.insert(
			problems,
			`it would be adding {adding} parts, removing {removing} folders: only 0 and 0 (done) or 2 and 1 (before) are known`
		)
	end
	if #problems > 0 then
		error(`nothing was changed. This is not a world section 4b knows: {table.concat(problems, "; ")}`)
	end
	if isDone then
		return "already done: both brim blocks are in World.WalkSurfaces as recorded and Mockup_Brim is gone"
	end
	local counted = `adding {adding} parts, removing {removing} folder`
	print(counted)
	if counted ~= EXPECTED_COUNT then
		error(`nothing was changed. The count is "{counted}", not "{EXPECTED_COUNT}"`)
	end

	-- The change itself, between two waypoints. The blocks are built away from the Workspace first.
	local descendantsBefore = #world:GetDescendants()
	local built: { Part } = {}
	for _, place in BrimPlaces.BLOCKS do
		table.insert(built, makeBlock(place))
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 4b: before")
	end)
	local changed, whyNot = pcall(function()
		for _, part in built do
			part.Parent = walk
		end
		local oldFolder = mockup :: Instance
		oldFolder:Destroy()
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 4b: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 4b: before") and tell code_lead`
		)
	end

	-- The same check afterwards, on the live world.
	local wrong: { string } = {}
	for _, place in BrimPlaces.BLOCKS do
		local live = walk:FindFirstChild(place.name)
		if live == nil or not live:IsA("BasePart") then
			table.insert(wrong, `{place.name} is not in World.WalkSurfaces`)
		else
			for _, problem in blockProblems(live, place) do
				table.insert(wrong, problem)
			end
		end
	end
	if Workspace:FindFirstChild(MOCKUP_NAME) ~= nil then
		table.insert(wrong, `{MOCKUP_NAME} is still in the Workspace`)
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {table.concat(wrong, "; ")}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	return string.format(
		"%s: made BrimFill_PlusX and BrimFill_MinusX in World.WalkSurfaces and removed Workspace.Mockup_Brim; World now has %d descendants (%d before)",
		counted,
		#world:GetDescendants(),
		descendantsBefore
	)
end

return sectionBrimFill
