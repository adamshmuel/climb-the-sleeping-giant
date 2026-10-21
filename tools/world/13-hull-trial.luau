--!strict
-- World trial, V2 stuck safety Task 5: the giant's smooth wrap (docs/plans/v2/stuck-safety.md, "Task 5").
-- Why: Rule 20 (One collision source) asks for a try-out of the "smooth wrap" (CollisionFidelity Hull, Roblox's
-- convex hull of a mesh) before the invisible shell is chosen. This script only sets the trial up and puts it back.
-- The results (stuck scan, world tests) are recorded by the builder's report, not by this script.
-- What it does:
--   MODE "trial":   finds his solid body pieces (MeshParts under World.Giant with CanCollide on), saves each piece's
--                   CollisionFidelity in the attribute HullTrialFidelity, then sets the piece to Hull.
--   MODE "putBack": gives every piece that has HullTrialFidelity its saved CollisionFidelity back and removes the
--                   attribute. A second run changes nothing and says "already back".
-- Change MODE below, then run in Studio EDIT mode (a running game can't change CollisionFidelity): read this file and
-- pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. "trial" run twice says
-- "already in trial". This is a TRIAL: it is never meant to stay. Always run "putBack" afterwards, and the place file
-- is then as it was (Adam has nothing to save for this task).

local MODE = "trial" -- "trial" or "putBack"

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ATTRIBUTE = "HullTrialFidelity"

local function bodyPieces(giant: Instance): { MeshPart }
	local pieces: { MeshPart } = {}
	for _, descendant in giant:GetDescendants() do
		if descendant:IsA("MeshPart") and descendant.CanCollide then
			table.insert(pieces, descendant)
		end
	end
	return pieces
end

local function markedPieces(giant: Instance): { MeshPart }
	local pieces: { MeshPart } = {}
	for _, descendant in giant:GetDescendants() do
		if descendant:IsA("MeshPart") and descendant:GetAttribute(ATTRIBUTE) ~= nil then
			table.insert(pieces, descendant)
		end
	end
	return pieces
end

local function fidelityByName(name: string): Enum.CollisionFidelity
	for _, item in Enum.CollisionFidelity:GetEnumItems() do
		if item.Name == name then
			return item
		end
	end
	error(`{name} is not a CollisionFidelity`)
end

local function run(): string
	if MODE ~= "trial" and MODE ~= "putBack" then
		error(`MODE must be "trial" or "putBack", not {MODE}`)
	end
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local giant = world:FindFirstChild("Giant")
	if giant == nil then
		error("Workspace.World.Giant is missing")
	end
	-- A mark anywhere else in the place would be a leftover from this trial.
	for _, descendant in Workspace:GetDescendants() do
		if descendant:GetAttribute(ATTRIBUTE) ~= nil and not descendant:IsDescendantOf(giant) then
			error(`{descendant:GetFullName()} has {ATTRIBUTE} but is not under the giant`)
		end
	end

	local marked = markedPieces(giant)
	local lines: { string } = {}

	if MODE == "trial" then
		local pieces = bodyPieces(giant)
		if #pieces == 0 then
			error("No solid MeshPart under Workspace.World.Giant")
		end
		if #marked > 0 then
			-- Already in trial (or half of one): every solid piece must carry a mark, or something is wrong.
			for _, piece in pieces do
				if piece:GetAttribute(ATTRIBUTE) == nil then
					error(`{piece:GetFullName()} has no {ATTRIBUTE} but others do: run putBack first`)
				end
			end
			return "already in trial"
		end
		pcall(function()
			ChangeHistoryService:SetWaypoint("13-hull-trial: before trial")
		end)
		for _, piece in pieces do
			local was = piece.CollisionFidelity.Name
			piece:SetAttribute(ATTRIBUTE, was)
			piece.CollisionFidelity = Enum.CollisionFidelity.Hull
			-- Written from `was`, not read back: Studio shows the new value only after a moment.
			table.insert(lines, `trial: {piece:GetFullName()}: {was} -> Hull`)
		end
		pcall(function()
			ChangeHistoryService:SetWaypoint("13-hull-trial: after trial")
		end)
		return table.concat(lines, "\n")
	end

	-- putBack: check every mark first.
	if #marked == 0 then
		return "already back"
	end
	for _, piece in marked do
		local saved = piece:GetAttribute(ATTRIBUTE)
		if typeof(saved) ~= "string" then
			error(`{piece:GetFullName()}: {ATTRIBUTE} is not a string`)
		end
		fidelityByName(saved)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("13-hull-trial: before put back")
	end)
	for _, piece in marked do
		local saved = piece:GetAttribute(ATTRIBUTE)
		piece.CollisionFidelity = fidelityByName(tostring(saved))
		piece:SetAttribute(ATTRIBUTE, nil)
		table.insert(lines, `put back: {piece:GetFullName()} = {saved}`)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("13-hull-trial: after put back")
	end)
	return table.concat(lines, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
