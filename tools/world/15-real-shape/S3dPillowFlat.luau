--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 3d: the pillow is laid flat and sunk under his head (stuck safety Task 41; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FitShared = require(script.Parent.FitShared)
local PillowPlaces = require(script.Parent.PillowPlaces)

local someProblems = S2bHeadChecks.someProblems
local bodySnapshot = FitShared.bodySnapshot
local bodyDifferences = FitShared.bodyDifferences
local countValues = FitShared.countValues
local sameTurn = PillowPlaces.sameTurn

-- Why: the pillow stood tilted behind his head, and its top reached the nightcap and made 34 stuck spots. It is laid flat
-- (its thin side straight up) and sunk until it is 1 stud under the nightcap. Only its Size and CFrame change: it is
-- already on its closer fit (section 3a) and lit like before (section 3a2), and ApplyMesh is not needed to resize it.
-- Measured on a clone in step 1 (2026-10-27, work/t41/state.md): size 120 x 46 x 30, centre (0.142862, 46.594, 40), no turn
-- but its own Z axis up, so its top is at y 61.59. It is 0.1 lower than step 1's first place, because the nearest
-- nightcap part was 0.94 above that (code_lead, 2026-10-27).
-- The nightcap, the cap ladder, his head and the noise zone boxes never move.
-- The one piece that is removed with the old pillow is World.WalkSurfaces.SteepGuards.CapSideLeft_52: it touched nothing
-- but the old pillow (the decision table's first row). Section 03-climb no longer makes it either.
-- It knows two worlds, and changes nothing on any difference:
--   (a) before: the pillow has the recorded old size and place (+-0.01), and CapSideLeft_52 is there. The change is made.
--   (a2) Task 42: the pillow is where Task 41 left it (1 stud higher), and CapSideLeft_52 is gone. It is moved down 1 stud.
--   (b) after: the pillow has the new size and place (+-0.01), and CapSideLeft_52 is gone. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- With dryRun true it changes nothing and says what it would do.
local function sectionPillowFlat(dryRun: boolean?): string
	if RunService:IsRunning() then
		error("a running game can't be changed like this: stop Play and run this in Edit mode")
	end
	local PATH = { "World", "GiantsThings", "Pillow", "body", "body_geom" }
	local GUARD_PATH = { "World", "WalkSurfaces", "SteepGuards", "CapSideLeft_52" }
	local OLD_SIZE = Vector3.new(95.004646, 91.194412, 35.748734)
	local OLD_POSITION = Vector3.new(0.142862, 79.86055, 52.141579)
	local NEW_SIZE = PillowPlaces.FLAT_SIZE
	local NEW_CFRAME = PillowPlaces.FLAT_CFRAME
	local TOLERANCE = 0.01
	-- The values that may differ when the pillow is resized and moved.
	local MAY_DIFFER = { Size = true, CFrame = true }

	local function find(path: { string }): Instance?
		local node: Instance? = Workspace
		for _, name in path do
			node = if node ~= nil then node:FindFirstChild(name) else nil
		end
		return node
	end

	local node = find(PATH)
	if node == nil or not node:IsA("MeshPart") then
		error(`nothing was changed. {table.concat(PATH, ".")} (a MeshPart) is missing`)
	end
	local pillow: MeshPart = node
	local guard: Instance? = find(GUARD_PATH)
	local guardThere: boolean = guard ~= nil

	local isOld = (pillow.Size - OLD_SIZE).Magnitude <= TOLERANCE
		and (pillow.Position - OLD_POSITION).Magnitude <= TOLERANCE
	local isNew = (pillow.Size - NEW_SIZE).Magnitude <= TOLERANCE
		and (pillow.Position - NEW_CFRAME.Position).Magnitude <= TOLERANCE
		and sameTurn(pillow.CFrame, NEW_CFRAME, 0.001)
	local isTask41 = (pillow.Size - NEW_SIZE).Magnitude <= TOLERANCE
		and (pillow.Position - PillowPlaces.TASK_41_FLAT_CFRAME.Position).Magnitude <= TOLERANCE
		and sameTurn(pillow.CFrame, PillowPlaces.TASK_41_FLAT_CFRAME, 0.001)

	local function stateText(): string
		return string.format(
			"pillow size (%.2f, %.2f, %.2f) at (%.3f, %.3f, %.3f), its thin side %.1f degrees from straight up; CapSideLeft_52 %s",
			pillow.Size.X,
			pillow.Size.Y,
			pillow.Size.Z,
			pillow.Position.X,
			pillow.Position.Y,
			pillow.Position.Z,
			math.deg(pillow.CFrame.ZVector:Angle(Vector3.yAxis)),
			if guardThere then "is there" else "is gone"
		)
	end

	if isNew and not guardThere then
		return `already done: {stateText()}`
	end
	if not ((isOld and guardThere) or (isTask41 and not guardThere)) then
		local problems: { string } = {}
		if not isOld and not isNew and not isTask41 then
			table.insert(problems, "the pillow is neither the recorded old one, Task 41's one nor the new one")
		end
		if isTask41 and guardThere then
			table.insert(problems, "the pillow is Task 41's one but CapSideLeft_52 is still there")
		end
		if isOld and not guardThere then
			table.insert(problems, "CapSideLeft_52 is gone but the pillow is still the old one")
		end
		if isNew and guardThere then
			table.insert(problems, "the pillow is the new one but CapSideLeft_52 is still there")
		end
		error(
			`nothing was changed. This is neither the world before nor the world after section 3d: {someProblems(
				problems
			)}. {stateText()}`
		)
	end
	if dryRun then
		return `dry run, nothing changed. It would set Size {NEW_SIZE} and CFrame at {NEW_CFRAME.Position} (own Z axis up) on the pillow and destroy CapSideLeft_52. Now: {stateText()}`
	end

	-- The change itself, between two waypoints.
	local before = bodySnapshot(pillow)
	local staying: Instance? = guard
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3d: before")
	end)
	local changed, whyNot = pcall(function()
		pillow.Size = NEW_SIZE
		pillow.CFrame = NEW_CFRAME
		if staying ~= nil then
			staying:Destroy()
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3d: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3d: before") and tell code_lead`
		)
	end

	-- The same check afterwards: only Size and CFrame may differ, and the world must be the world after.
	local wrong: { string } = {}
	for _, name in bodyDifferences(before, bodySnapshot(pillow)) do
		if not MAY_DIFFER[name] then
			table.insert(wrong, `{name} changed`)
		end
	end
	if
		(pillow.Size - NEW_SIZE).Magnitude > TOLERANCE
		or (pillow.Position - NEW_CFRAME.Position).Magnitude > TOLERANCE
	then
		table.insert(wrong, "the pillow is not at the new size and place")
	end
	if find(GUARD_PATH) ~= nil then
		table.insert(wrong, "CapSideLeft_52 is still there")
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	return string.format(
		"changed: %d values compared before and after, only Size and CFrame differ. Now: %s",
		countValues(before),
		stateText()
	)
end

return sectionPillowFlat
