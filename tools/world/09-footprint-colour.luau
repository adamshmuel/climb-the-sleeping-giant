--!strict
-- World prep, task 24 (round 1): the glowing footprint gets designer's colour, neon yellow #FFD43B (spec Rule 2,
-- "Footprints show the way", and the "Footprint colour" row of the style guide).
-- Why: designer's look check in Play. The pale #FFEC78 washed out on the bridge planks and looked like the cream
-- Common egg. ReplicatedStorage.Assets.Footprint is a Model in the place file (not in Rojo) with 4 parts: Sole, Toe1,
-- Toe2 and Toe3. Only the Color of those 4 parts changes. The material (Neon), the sizes, the positions, the meshes
-- and everything else stay as they are.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks first, so a second run changes nothing and says "already done". It returns a short plain-text report.
-- Nothing is deleted. The place file must be saved by Adam afterwards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local NEW_COLOR = Color3.fromHex("FFD43B")
local PART_NAMES = { "Sole", "Toe1", "Toe2", "Toe3" }

local function run(): string
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = if assets then assets:FindFirstChild("Footprint") else nil
	if template == nil then
		error("ReplicatedStorage.Assets.Footprint is missing")
	end

	-- Check everything first, so a problem stops the script before anything changes.
	local toChange: { BasePart } = {}
	local alreadyDone = 0
	for _, name in PART_NAMES do
		local part = template:FindFirstChild(name)
		if part == nil then
			error(`{template:GetFullName()} has no part named {name}`)
		end
		if not part:IsA("BasePart") then
			error(`{part:GetFullName()} is a {part.ClassName}, not a part`)
		end
		if part.Color:ToHex():upper() == NEW_COLOR:ToHex():upper() then
			alreadyDone += 1
		else
			table.insert(toChange, part)
		end
	end

	if #toChange == 0 then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("09-footprint-colour: before")
	end)
	for _, part in toChange do
		part.Color = NEW_COLOR
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("09-footprint-colour: after")
	end)

	return string.format("recoloured %d footprint parts (%d were already done) to #FFD43B", #toChange, alreadyDone)
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
