--!strict
-- World prep, task 18 look fix: the carried egg is smaller and lower (spec Rule 4, "Hold to grab", and the
-- "Carrying" row of spec section 6, where the player's hair and the top of the head show above the egg).
-- Why: designer's look check in Play. With the egg 4.2 studs tall and its middle 0.8 studs above the root part,
-- the egg's top was 2.90 studs above the root and the top of the head only 1.85, so the egg hid the whole head.
-- designer tested these values in Play: the egg is 3.6 studs tall and its middle is at (0, -0.1, 1.75) from the
-- HumanoidRootPart, so its top is 1.70 studs above the root, just under the top of the head.
-- They replace the values that 01-gardens measured (step 4 only sets them when they are missing, so it is not changed).
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks first, so a second run changes nothing and says "already done". It returns a short plain-text report.
-- Nothing is deleted. The place file must be saved by Adam afterwards.

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local NEW_HEIGHT = 3.6
local NEW_OFFSET = CFrame.new(0, -0.1, 1.75) -- no rotation
local SAME_LIMIT = 0.001 -- studs: a value closer than this to the new one counts as already set

local function describeOffset(value: any): string
	if typeof(value) == "CFrame" then
		local p = (value :: CFrame).Position
		return string.format("(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
	end
	return "missing"
end

local function describeHeight(value: any): string
	if typeof(value) == "number" then
		return string.format("%.1f", value :: number)
	end
	return "missing"
end

local function run(): string
	local assets = ServerStorage:FindFirstChild("Assets")
	if assets == nil then
		error("ServerStorage.Assets is missing (run 01-gardens first)")
	end

	local oldHeight: any = assets:GetAttribute("CarriedEggHeight")
	local oldOffset: any = assets:GetAttribute("CarriedEggOffset")

	local heightIsSet = typeof(oldHeight) == "number" and math.abs((oldHeight :: number) - NEW_HEIGHT) < SAME_LIMIT
	local offsetIsSet = typeof(oldOffset) == "CFrame"
		and ((oldOffset :: CFrame).Position - NEW_OFFSET.Position).Magnitude < SAME_LIMIT
		and ((oldOffset :: CFrame).Rotation.LookVector - Vector3.new(0, 0, -1)).Magnitude < SAME_LIMIT
		and ((oldOffset :: CFrame).Rotation.UpVector - Vector3.new(0, 1, 0)).Magnitude < SAME_LIMIT

	if heightIsSet and offsetIsSet then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("05-carried-egg: before")
	end)
	assets:SetAttribute("CarriedEggHeight", NEW_HEIGHT)
	assets:SetAttribute("CarriedEggOffset", NEW_OFFSET)
	pcall(function()
		ChangeHistoryService:SetWaypoint("05-carried-egg: after")
	end)

	return string.format(
		"CarriedEggHeight %s -> %.1f; CarriedEggOffset %s -> %s",
		describeHeight(oldHeight),
		NEW_HEIGHT,
		describeOffset(oldOffset),
		describeOffset(NEW_OFFSET)
	)
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
