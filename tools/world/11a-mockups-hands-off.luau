--!strict
-- World prep, V2 setup 1: designer's mockup folders are hands-off (docs/plans/v2/index.md, "V2 setup 1").
-- Why: the folders Workspace.Mockup_Nests, Mockup_WaysUp, Mockup_EggRanks, Mockup_Rescue and the others are designer's
-- mockup pieces, not the game. Their parts were solid and were found by the game's ground and slam checks. One example:
-- the mockup ramp Mockup_Nests.RampModel.RampLeft lies over Rare egg 1, so the slam circle landed on it at y 42.24
-- and a player could walk on it. This made 7 real-world tests fail before V2 started.
-- What it does: every part (BasePart) inside each Workspace child whose name starts with "Mockup_" gets CanCollide,
-- CanQuery and CanTouch set to false (not solid, never found by a ray or a box check, not touchable). Before that,
-- each part's own three values are saved on the part as the attributes MockupCanCollide, MockupCanQuery and
-- MockupCanTouch, so nothing designer set is lost. A later script that moves a mockup piece into the game gives the
-- piece back its values from those attributes and then removes them. The attributes are only saved when the part has
-- none yet, so a second run never overwrites designer's values with false. CanCollide is set first: the Roblox docs
-- (BasePart.CanQuery) say CanQuery only takes effect once CanCollide is off.
-- It moves nothing, deletes nothing and changes no look (no Transparency, no Color, no CFrame, no Size).
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when nothing
-- differs it changes nothing and says "already done". The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FOLDER_PREFIX = "Mockup_"
local ATTRIBUTES = { "MockupCanCollide", "MockupCanQuery", "MockupCanTouch" }

type Counts = { parts: number, saved: number, switchedOff: number }

local function isMockupFolder(child: Instance): boolean
	return string.sub(child.Name, 1, #FOLDER_PREFIX) == FOLDER_PREFIX
end

-- How many of the three attributes a part has (0 to 3).
local function savedCount(part: BasePart): number
	local count = 0
	for _, name in ATTRIBUTES do
		if part:GetAttribute(name) ~= nil then
			count += 1
		end
	end
	return count
end

local function run(): string
	-- Check everything first, so a problem stops the script before anything changes.
	local folders: { Instance } = {}
	for _, child in Workspace:GetChildren() do
		if isMockupFolder(child) then
			table.insert(folders, child)
		end
	end
	if #folders == 0 then
		error("no Workspace child starts with Mockup_")
	end

	local partsByFolder: { [Instance]: { BasePart } } = {}
	local counts: { [Instance]: Counts } = {}
	local needsWork = 0
	for _, folder in folders do
		local parts: { BasePart } = {}
		if folder:IsA("BasePart") then
			table.insert(parts, folder)
		end
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
		local count: Counts = { parts = #parts, saved = 0, switchedOff = 0 }
		for _, part in parts do
			local have = savedCount(part)
			if have ~= 0 and have ~= #ATTRIBUTES then
				error(`{part:GetFullName()} has only some of the Mockup attributes ({have} of {#ATTRIBUTES})`)
			end
			for _, name in ATTRIBUTES do
				local value = part:GetAttribute(name)
				if value ~= nil and typeof(value) ~= "boolean" then
					error(`{part:GetFullName()} attribute {name} is not a boolean`)
				end
			end
			local saves = have == 0
			local switches = part.CanCollide or part.CanQuery or part.CanTouch
			if saves then
				count.saved += 1
			end
			if switches then
				count.switchedOff += 1
			end
			if saves or switches then
				needsWork += 1
			end
		end
		partsByFolder[folder] = parts
		counts[folder] = count
	end

	if needsWork == 0 then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("11a-mockups-hands-off: before")
	end)
	for _, folder in folders do
		for _, part in partsByFolder[folder] do
			-- Save the part's own values first, only when it has none saved yet.
			if savedCount(part) == 0 then
				part:SetAttribute("MockupCanCollide", part.CanCollide)
				part:SetAttribute("MockupCanQuery", part.CanQuery)
				part:SetAttribute("MockupCanTouch", part.CanTouch)
			end
			-- CanCollide first: CanQuery only takes effect once CanCollide is off.
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("11a-mockups-hands-off: after")
	end)

	local report: { string } = {}
	local totalParts, totalSaved, totalSwitched = 0, 0, 0
	for _, folder in folders do
		local count = counts[folder]
		totalParts += count.parts
		totalSaved += count.saved
		totalSwitched += count.switchedOff
		table.insert(
			report,
			`{folder.Name}: {count.parts} parts, values saved on {count.saved}, switched off on {count.switchedOff}`
		)
	end
	table.insert(
		report,
		`{#folders} folders, {totalParts} parts, values saved on {totalSaved}, switched off on {totalSwitched}`
	)
	return table.concat(report, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
