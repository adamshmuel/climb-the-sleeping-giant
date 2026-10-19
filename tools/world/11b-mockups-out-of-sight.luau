--!strict
-- World prep, V2 setup 3: nothing in designer's mockup folders shows in Play (docs/plans/v2/index.md, "V2 setup 3").
-- Why: the Workspace folders that start with "Mockup_" are mockup pieces, not the game, but in Play they still showed
-- about 90 egg labels (stacked "Rare Rare Rare" on the belly), mockup eggs, see-through helper slabs that tint half the
-- screen (the ramps, the red side panels, the red glow on a ladder), empty nests, pockets, straps and ramps that look
-- climbable but are not solid, and floating names over mockup avatars.
-- What it does, only inside Workspace children whose name starts with "Mockup_":
--   1. Parts: every BasePart, Decal and Texture gets Transparency = 1. (Transparency, not LocalTransparencyModifier:
--      that one is not saved in the place file.) Old value saved as the attribute MockupTransparency.
--   2. Labels, screens and effects: every BillboardGui, SurfaceGui, Beam, Trail, ParticleEmitter, PointLight,
--      SpotLight, SurfaceLight, Fire, Smoke, Sparkles and Highlight gets Enabled = false. Old value saved as the
--      attribute MockupEnabled.
--   3. Mockup avatars: every Humanoid gets DisplayDistanceType = None. Old setting saved as the attribute
--      MockupDisplayDistanceType (the setting's name as text, for example "Viewer").
--   A value that is already saved is kept, never overwritten. Designer can show a mockup again by putting the saved
--      values back.
-- It moves nothing, deletes nothing, and leaves CanCollide, CanQuery and CanTouch (V2 setup 1) as they are. A later
-- script that moves a mockup piece into the game gives the piece back its saved values (see the V2 setup 1 rule in
-- docs/plans/v2/index.md).
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when nothing
-- differs it changes nothing and says "already done". The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FOLDER_PREFIX = "Mockup_"
local SWITCHED_CLASSES = {
	"BillboardGui",
	"SurfaceGui",
	"Beam",
	"Trail",
	"ParticleEmitter",
	"PointLight",
	"SpotLight",
	"SurfaceLight",
	"Fire",
	"Smoke",
	"Sparkles",
	"Highlight",
}

type Counts = { parts: number, switched: number, avatars: number }

-- One thing to hide: the object, how its current value is saved (a number, a boolean or text), whether it is already
-- hidden, the attribute that keeps the old value, and how to hide it.
type Job = {
	object: Instance,
	attribute: string,
	saved: any,
	hidden: boolean,
	hide: () -> (),
	kind: string,
}

local function newJob(
	object: Instance,
	attribute: string,
	saved: any,
	hidden: boolean,
	hide: () -> (),
	kind: string
): Job
	return { object = object, attribute = attribute, saved = saved, hidden = hidden, hide = hide, kind = kind }
end

local function isMockupFolder(child: Instance): boolean
	return string.sub(child.Name, 1, #FOLDER_PREFIX) == FOLDER_PREFIX
end

local function isSwitched(instance: Instance): boolean
	for _, className in SWITCHED_CLASSES do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

-- The job for one object, or nil when the script leaves it alone.
local function jobFor(object: Instance): Job?
	if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
		local thing = object :: BasePart
		return newJob(object, "MockupTransparency", thing.Transparency, thing.Transparency == 1, function()
			thing.Transparency = 1
		end, "parts")
	elseif isSwitched(object) then
		local thing = object :: any
		return newJob(object, "MockupEnabled", thing.Enabled, thing.Enabled == false, function()
			thing.Enabled = false
		end, "switched")
	elseif object:IsA("Humanoid") then
		local none = Enum.HumanoidDisplayDistanceType.None
		return newJob(
			object,
			"MockupDisplayDistanceType",
			object.DisplayDistanceType.Name,
			object.DisplayDistanceType == none,
			function()
				object.DisplayDistanceType = none
			end,
			"avatars"
		)
	end
	return nil
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

	local jobs: { Job } = {}
	local counts: { [Instance]: Counts } = {}
	for _, folder in folders do
		local count: Counts = { parts = 0, switched = 0, avatars = 0 }
		counts[folder] = count
		local objects: { Instance } = folder:GetDescendants()
		table.insert(objects, folder)
		for _, object in objects do
			local job = jobFor(object)
			if job ~= nil then
				local kept = object:GetAttribute(job.attribute)
				if kept ~= nil and typeof(kept) ~= typeof(job.saved) then
					error(
						`{object:GetFullName()} attribute {job.attribute} is a {typeof(kept)}, not a {typeof(job.saved)}`
					)
				end
				-- Needs work when the old value is not saved yet, or the object is not hidden yet.
				if kept == nil or not job.hidden then
					table.insert(jobs, job)
					if job.kind == "parts" then
						count.parts += 1
					elseif job.kind == "switched" then
						count.switched += 1
					else
						count.avatars += 1
					end
				end
			end
		end
	end

	if #jobs == 0 then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("11b-mockups-out-of-sight: before")
	end)
	for _, job in jobs do
		-- Save the old value first, only when none is saved yet.
		if job.object:GetAttribute(job.attribute) == nil then
			job.object:SetAttribute(job.attribute, job.saved)
		end
		job.hide()
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("11b-mockups-out-of-sight: after")
	end)

	local report: { string } = {}
	local totalParts, totalSwitched, totalAvatars = 0, 0, 0
	for _, folder in folders do
		local count = counts[folder]
		totalParts += count.parts
		totalSwitched += count.switched
		totalAvatars += count.avatars
		table.insert(
			report,
			`{folder.Name}: parts, decals and textures changed {count.parts}, labels, screens and effects changed {count.switched}, avatars changed {count.avatars}`
		)
	end
	table.insert(
		report,
		`{#folders} folders, parts, decals and textures changed {totalParts}, labels, screens and effects changed {totalSwitched}, avatars changed {totalAvatars}`
	)
	return table.concat(report, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
