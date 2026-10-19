--!strict
-- World prep, V2 new-player safety Task 9: the old bubble goes away (docs/plans/v2/new-player-safety.md, "Task 9").
-- Why: GiantFx now shows the new bubble, World.GiantFX.SnoreEmitter.Warning85Bubble, at every 85% warning (V2 spec 1,
-- Rule 17: A free save replays the 85% warning, section 5). The old bubble by his mouth, World.GiantFX.MumbleAnchor with
-- its Mumble, is never shown any more, so it leaves the Workspace.
-- What it does:
--   1. Moves World.GiantFX.MumbleAnchor (with its Mumble) to ServerStorage.ArtLibrary.
--   2. Removes the stale "Note" attribute from Warning85Bubble: designer wrote it for the first test values (1.6 times
--      V1's size, 2 studs up), which the tested values in the style guide have replaced.
-- Run it only after GiantFx shows Warning85Bubble (it does from Task 9 on), or the game has no bubble at all.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when both
-- things are done it changes nothing and says "already done". The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local OLD_NAME = "MumbleAnchor"
local BUBBLE_NAME = "Warning85Bubble"
local SNORE_EMITTER_NAME = "SnoreEmitter"
local NOTE_ATTRIBUTE = "Note"

local function child(parent: Instance, name: string): Instance?
	return parent:FindFirstChild(name)
end

local function run(): string
	-- Check everything first, so a problem stops the script before anything changes.
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local giantFx = child(world, "GiantFX")
	if giantFx == nil then
		error("Workspace.World.GiantFX is missing")
	end
	local snoreEmitter = child(giantFx, SNORE_EMITTER_NAME)
	if snoreEmitter == nil then
		error("Workspace.World.GiantFX.SnoreEmitter is missing")
	end
	local bubble = child(snoreEmitter, BUBBLE_NAME)
	if bubble == nil or not bubble:IsA("BillboardGui") then
		error(
			`Workspace.World.GiantFX.SnoreEmitter.{BUBBLE_NAME} is missing or is not a BillboardGui: run 12-warning85 first`
		)
	end
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	if library == nil then
		error("ServerStorage.ArtLibrary is missing")
	end

	-- Where the old bubble is now: in GiantFX (to move), in the library (done), or both or neither (a problem).
	local old = child(giantFx, OLD_NAME)
	local inLibrary = child(library, OLD_NAME)
	local elsewhere: { string } = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == OLD_NAME and descendant ~= old then
			table.insert(elsewhere, descendant:GetFullName())
		end
	end
	if #elsewhere > 0 then
		error(`{OLD_NAME} is also in the Workspace somewhere else: {table.concat(elsewhere, ", ")}`)
	end
	if old ~= nil and inLibrary ~= nil then
		error(`{OLD_NAME} is both in GiantFX and in ServerStorage.ArtLibrary`)
	end
	if old == nil and inLibrary == nil then
		error(`{OLD_NAME} is in neither GiantFX nor ServerStorage.ArtLibrary`)
	end
	local needsMove = old ~= nil
	local needsNote = bubble:GetAttribute(NOTE_ATTRIBUTE) ~= nil
	if not needsMove and not needsNote then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("12b-old-bubble-away: before")
	end)

	local lines: { string } = {}
	-- 1. The old bubble goes to the library.
	if old ~= nil then
		local pieces = #old:GetDescendants()
		old.Parent = library
		table.insert(lines, `{OLD_NAME} ({pieces} pieces in it) moved to {library:GetFullName()}`)
	end
	-- 2. The stale note on the new bubble goes.
	if needsNote then
		bubble:SetAttribute(NOTE_ATTRIBUTE, nil)
		table.insert(lines, `{NOTE_ATTRIBUTE} attribute removed from {bubble:GetFullName()}`)
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("12b-old-bubble-away: after")
	end)
	return table.concat(lines, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
