--!strict
-- World prep, V2 new-player safety Task 7: the 85% warning pieces (docs/plans/v2/new-player-safety.md, "Task 7").
-- Why: designer tested the new 85% warning (a snort from his nose and a bubble beside it) in the mockup folder
-- Workspace.Mockup_Warning85. The game needs the two tested pieces in the real world, and the rest of the mockup out of
-- the Workspace (docs/specs/v2/new-player-safety.md, Rule 17: A free save replays the 85% warning, section 5).
-- What it does:
--   1. Moves Mockup_Warning85.SnortNose (with its SnortPuff) into Workspace.World.GiantFX.
--   2. Moves Mockup_Warning85.BubbleAnchor.Bubble (the pill, the words and the tail) into World.GiantFX.SnoreEmitter,
--      renamed Warning85Bubble and switched off. Its Adornee is cleared, so it hangs on the SnoreEmitter it sits in.
--      (The old Adornee, BubbleAnchor, sits at the same spot, -8, 104, -22.) The client sets its size and side in Task 9.
--   3. Moves what is left of Mockup_Warning85 (BubbleAnchor, SnortEmitter and the two ModuleScripts) to
--      ServerStorage.ArtLibrary, in the folder Mockup_Warning85. Those pieces keep their Mockup* attributes.
--   4. Leaves World.GiantFX.MumbleAnchor where it is: GiantFx still shows it until Task 9.
-- Mockup values (docs/plans/v2/index.md, V2 setup 1 and 3): each piece moved into the World gets back the values it saved
--   (MockupCanCollide, MockupCanQuery, MockupCanTouch, MockupTransparency, MockupEnabled) and then loses every Mockup*
--   attribute. Except the values named here: the nose is not solid, not found by checks and not touchable, and the
--   bubble is off.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when the pieces
-- are already in place it changes nothing and says "already done". The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MOCKUP_FOLDER = "Mockup_Warning85"
local NOSE_NAME = "SnortNose"
local PUFF_NAME = "SnortPuff"
local BUBBLE_ANCHOR_NAME = "BubbleAnchor"
local BUBBLE_OLD_NAME = "Bubble"
local BUBBLE_NEW_NAME = "Warning85Bubble"
local SNORE_EMITTER_NAME = "SnoreEmitter"
local MOCKUP_PREFIX = "Mockup"
-- Where designer tested the nose (docs/design/v2/style-guide.md, "The 85% warning: tested values (2026-10-19)").
local NOSE_POSITION = Vector3.new(0, 89, -14)
local NOSE_SIZE = Vector3.new(2, 0.4, 2)
local NOSE_FACING = Vector3.new(0, 0.5, -0.87)
local TOLERANCE = 0.02

local function child(parent: Instance, name: string): Instance?
	return parent:FindFirstChild(name)
end

-- Gives a moved piece (and everything inside it) its saved values back, then removes every Mockup* attribute.
-- Each saved value is checked first by `checkRestorable`, so this never fails half way.
local function restore(piece: Instance)
	local objects: { Instance } = piece:GetDescendants()
	table.insert(objects, piece)
	for _, object in objects do
		if object:IsA("BasePart") then
			local collide = object:GetAttribute("MockupCanCollide")
			local query = object:GetAttribute("MockupCanQuery")
			local touch = object:GetAttribute("MockupCanTouch")
			if collide ~= nil then
				object.CanCollide = collide :: boolean
			end
			if query ~= nil then
				object.CanQuery = query :: boolean
			end
			if touch ~= nil then
				object.CanTouch = touch :: boolean
			end
		end
		if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
			local transparency = object:GetAttribute("MockupTransparency")
			if transparency ~= nil then
				(object :: BasePart).Transparency = transparency :: number
			end
		end
		local enabled = object:GetAttribute("MockupEnabled")
		if enabled ~= nil then
			(object :: any).Enabled = enabled :: boolean
		end
		for name in object:GetAttributes() do
			if string.sub(name, 1, #MOCKUP_PREFIX) == MOCKUP_PREFIX then
				object:SetAttribute(name, nil)
			end
		end
	end
end

-- Stops with an error when a saved value is not the kind of value this script restores.
local function checkRestorable(piece: Instance)
	local objects: { Instance } = piece:GetDescendants()
	table.insert(objects, piece)
	local expected: { [string]: string } = {
		MockupCanCollide = "boolean",
		MockupCanQuery = "boolean",
		MockupCanTouch = "boolean",
		MockupTransparency = "number",
		MockupEnabled = "boolean",
	}
	for _, object in objects do
		for name, value in object:GetAttributes() do
			if string.sub(name, 1, #MOCKUP_PREFIX) == MOCKUP_PREFIX then
				local kind = expected[name]
				if kind == nil then
					error(`{object:GetFullName()} has an attribute {name} this script does not restore`)
				end
				if typeof(value) ~= kind then
					error(`{object:GetFullName()} attribute {name} is a {typeof(value)}, not a {kind}`)
				end
			end
		end
	end
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
	if snoreEmitter == nil or not snoreEmitter:IsA("BasePart") then
		error("Workspace.World.GiantFX.SnoreEmitter is missing or is not a part")
	end
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	if library == nil then
		error("ServerStorage.ArtLibrary is missing")
	end

	local mockup = Workspace:FindFirstChild(MOCKUP_FOLDER)
	local placedNose = child(giantFx, NOSE_NAME)
	local placedBubble = child(snoreEmitter, BUBBLE_NEW_NAME)
	if mockup == nil then
		if placedNose ~= nil and placedBubble ~= nil and child(library, MOCKUP_FOLDER) ~= nil then
			return "already done"
		end
		error(`Workspace.{MOCKUP_FOLDER} is gone but the pieces are not all in place`)
	end

	-- The mockup is still in the Workspace: nothing may be in the way, and it must have the pieces we move.
	if placedNose ~= nil then
		error(`Workspace.World.GiantFX already has a {NOSE_NAME}`)
	end
	if placedBubble ~= nil then
		error(`Workspace.World.GiantFX.SnoreEmitter already has a {BUBBLE_NEW_NAME}`)
	end
	if child(library, MOCKUP_FOLDER) ~= nil then
		error(`ServerStorage.ArtLibrary already has a {MOCKUP_FOLDER}`)
	end
	local nose = child(mockup, NOSE_NAME)
	if nose == nil or not nose:IsA("BasePart") then
		error(`{MOCKUP_FOLDER}.{NOSE_NAME} is missing or is not a part`)
	end
	local puff = child(nose, PUFF_NAME)
	if puff == nil or not puff:IsA("ParticleEmitter") then
		error(`{NOSE_NAME}.{PUFF_NAME} is missing or is not a ParticleEmitter`)
	end
	local anchor = child(mockup, BUBBLE_ANCHOR_NAME)
	if anchor == nil then
		error(`{MOCKUP_FOLDER}.{BUBBLE_ANCHOR_NAME} is missing`)
	end
	local bubble = child(anchor, BUBBLE_OLD_NAME)
	if bubble == nil or not bubble:IsA("BillboardGui") then
		error(`{BUBBLE_ANCHOR_NAME}.{BUBBLE_OLD_NAME} is missing or is not a BillboardGui`)
	end
	local nosePart = nose :: BasePart
	if
		(nosePart.Position - NOSE_POSITION).Magnitude > TOLERANCE
		or (nosePart.Size - NOSE_SIZE).Magnitude > TOLERANCE
		or (nosePart.CFrame.UpVector - NOSE_FACING).Magnitude > TOLERANCE
	then
		error(`{NOSE_NAME} is not at the tested place, size and facing`)
	end
	checkRestorable(nose)
	checkRestorable(bubble)

	pcall(function()
		ChangeHistoryService:SetWaypoint("12-warning85: before")
	end)

	-- 1. The snort nose, with its puff, goes into GiantFX with its saved values back.
	restore(nose)
	nosePart.CanCollide = false
	nosePart.CanQuery = false
	nosePart.CanTouch = false
	nose.Parent = giantFx

	-- 2. The bubble goes into the SnoreEmitter, off.
	restore(bubble)
	local bubbleGui = bubble :: BillboardGui
	bubbleGui.Name = BUBBLE_NEW_NAME
	local looseGui = bubbleGui :: any -- Adornee's type does not allow nil, but nil is allowed in Studio
	looseGui.Adornee = nil
	bubbleGui.Enabled = false
	bubble.Parent = snoreEmitter

	-- 3. What is left of the mockup goes to the library, with its Mockup* attributes.
	local leftOver = #mockup:GetDescendants()
	mockup.Parent = library

	pcall(function()
		ChangeHistoryService:SetWaypoint("12-warning85: after")
	end)

	return table.concat({
		`{NOSE_NAME} (with {PUFF_NAME}) moved to {giantFx:GetFullName()}`,
		`{BUBBLE_NEW_NAME} moved to {snoreEmitter:GetFullName()}, off`,
		`{MOCKUP_FOLDER} ({leftOver} pieces left in it) moved to {library:GetFullName()}`,
		`{giantFx:GetFullName()}.MumbleAnchor left where it is`,
	}, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
