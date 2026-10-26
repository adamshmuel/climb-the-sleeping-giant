--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 2c: the zone over the nose rails (stuck safety Task 25, step 4 ruling)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)

local RECORD_TOLERANCE = Shared.RECORD_TOLERANCE

-- Why: the tops of the new side rails beside the open nose top stand at y 107, so a player on one stands at y 110. The
-- Beard_Ladder zone box (it holds the nose top) stops at y 107, so those two spots (+-4, 110, -11) were in no giant zone.
-- The box grows upward by 4 studs, to y 111 (1 stud to spare). Nothing else changes: its foot (y 66), its width and depth,
-- its place across and along, its Beard zone and every other zone box stay. Where the box now reaches above y 107 and
-- z -10 or further back, the higher Nightcap_Brow zone already wins, so no other spot changes zone.
-- Recorded as measured in Studio Edit mode on 2026-10-20.
local ZONE_BOX_NAME = "Beard_Ladder"

local ZONE_BOX_BEFORE_SIZE = Vector3.new(24, 41, 32)

local ZONE_BOX_BEFORE_POSITION = Vector3.new(0, 86.5, -12)

local ZONE_BOX_AFTER_SIZE = Vector3.new(24, 45, 32)

local ZONE_BOX_AFTER_POSITION = Vector3.new(0, 88.5, -12)

-- Is the box this size and place, and not turned? An empty string means yes.
local function zoneBoxProblem(box: BasePart, size: Vector3, position: Vector3): string
	if (box.Size - size).Magnitude > RECORD_TOLERANCE then
		return string.format("size is %.2f, %.2f, %.2f", box.Size.X, box.Size.Y, box.Size.Z)
	end
	if (box.Position - position).Magnitude > RECORD_TOLERANCE then
		return string.format("place is %.2f, %.2f, %.2f", box.Position.X, box.Position.Y, box.Position.Z)
	end
	local turned = box.CFrame.RightVector:Dot(Vector3.xAxis) < 0.9999
		or box.CFrame.UpVector:Dot(Vector3.yAxis) < 0.9999
		or box.CFrame.LookVector:Dot(Vector3.zAxis) > -0.9999
	if turned then
		return "it is turned"
	end
	return ""
end

local function sectionZone(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local zones = if world ~= nil then world:FindFirstChild("Zones") else nil
	local found = if zones ~= nil then zones:FindFirstChild(ZONE_BOX_NAME) else nil
	if found == nil or not found:IsA("BasePart") then
		error(`World.Zones.{ZONE_BOX_NAME} is missing`)
	end
	local box = found :: BasePart
	if box:GetAttribute("Zone") ~= "Beard" then
		error(`nothing was changed. World.Zones.{ZONE_BOX_NAME} is not a Beard zone box`)
	end

	-- Two worlds are known; anything else stops with nothing changed.
	--   (b) the grown box: already done.
	--   (a) V1's box: it grows.
	local afterProblem = zoneBoxProblem(box, ZONE_BOX_AFTER_SIZE, ZONE_BOX_AFTER_POSITION)
	if afterProblem == "" then
		return string.format(
			"already done: World.Zones.%s is the grown box (size %.0f, %.0f, %.0f at %.1f, %.1f, %.1f, so it reaches up to y %.1f)",
			ZONE_BOX_NAME,
			box.Size.X,
			box.Size.Y,
			box.Size.Z,
			box.Position.X,
			box.Position.Y,
			box.Position.Z,
			box.Position.Y + box.Size.Y / 2
		)
	end
	local beforeProblem = zoneBoxProblem(box, ZONE_BOX_BEFORE_SIZE, ZONE_BOX_BEFORE_POSITION)
	if beforeProblem ~= "" then
		error(
			`nothing was changed. World.Zones.{ZONE_BOX_NAME} is neither the old box ({beforeProblem}) nor the grown one ({afterProblem})`
		)
	end

	ChangeHistoryService:SetWaypoint("15-real-shape section 2c: before")
	box.Size = ZONE_BOX_AFTER_SIZE
	box.CFrame = CFrame.new(ZONE_BOX_AFTER_POSITION)
	ChangeHistoryService:SetWaypoint("15-real-shape section 2c: after")
	local stillProblem = zoneBoxProblem(box, ZONE_BOX_AFTER_SIZE, ZONE_BOX_AFTER_POSITION)
	if stillProblem ~= "" then
		error(`World.Zones.{ZONE_BOX_NAME} did not become the grown box: {stillProblem}`)
	end
	return string.format(
		"grown: World.Zones.%s was size 24, 41, 32 at 0, 86.5, -12 (up to y 107) and is now size 24, 45, 32 at 0, 88.5, -12 (up to y 111)",
		ZONE_BOX_NAME
	)
end

return sectionZone
