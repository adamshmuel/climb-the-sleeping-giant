--!strict
-- World prep, Task 6d (plan "gardens-and-ways-up", Task 6): adds the CollectionService tag `MainCharacter` to
-- Workspace.World.Giant, so the "no visible part sinks into a main character" test (SunkParts.spec) finds every main
-- character by its tag, never by a folder name. No part changes, so there is no backup.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau, or require a copy.
-- It returns "tagged", or "already done" when the tag is there. Save the place file afterwards.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TAG = "MainCharacter"

local function run(): string
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local giant = world:FindFirstChild("Giant")
	if giant == nil or not giant:IsA("Model") then
		error("Workspace.World.Giant (Model) is missing")
	end
	if CollectionService:HasTag(giant, TAG) then
		return "already done"
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("32-main-character-tag: before")
	end)
	CollectionService:AddTag(giant, TAG)
	pcall(function()
		ChangeHistoryService:SetWaypoint("32-main-character-tag: after")
	end)
	return "tagged"
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
