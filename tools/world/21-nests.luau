--!strict
-- World prep, plan 5 Task 8 (first part of the nests script): the refill pop's star burst goes into the place
-- (card work/p5t8/p5t8-card.md; spec 5 Rule 77 and section 6 "A new egg appears"; style guide
-- docs/design/v2/style-guide/nests-art.md lines 32-49).
-- Why: the client's NestPop (src/client/Fx/NestPop.luau) clones ReplicatedStorage.Assets.RefillPop when a nest gets its
-- egg back. The 4 mockup copies in Workspace.Mockup_Nests.Art.RefillPop are all the same, so the Common one is the source.
-- What it does: clones Workspace.Mockup_Nests.Art.RefillPop.RefillPop_Common.SparkleShell (a see-through Part holding one
-- ParticleEmitter, Sparkles) to ReplicatedStorage.Assets.RefillPop, anchored, with CanCollide, CanQuery and CanTouch off.
-- It adds only: 1 new part (plus its emitter). Nothing existing is touched, so there is no backup clone.
-- STOP (nothing changed, the reason is reported): Assets or the source missing; the source not a BasePart with exactly 1
-- ParticleEmitter; an Assets.RefillPop that is there but is not a BasePart holding a ParticleEmitter.
-- An Assets.RefillPop that is already right = "already done".
-- CHECK_ONLY = true looks and prints only. More tasks add their nest parts to this script later.
-- Run in Studio EDIT mode: paste this file's text with execute_luau. The place file must be saved afterwards (the
-- template lives in the place file, not in the Rojo tree).

local CHECK_ONLY = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- How many parts this script adds, as planned in the card (the one template).
local PLANNED_PARTS = 1
local TEMPLATE_NAME = "RefillPop"

-- The emitter's first colour as a hex word, for the report.
local function emitterLine(emitter: ParticleEmitter): string
	local first = emitter.Color.Keypoints[1].Value
	return `emitter {emitter.Name}, colour #{first:ToHex()}`
end

-- The one ParticleEmitter in a part's children, or nil when there is none or more than one.
local function onlyEmitter(part: Instance): ParticleEmitter?
	local found: ParticleEmitter? = nil
	for _, child in part:GetChildren() do
		if child:IsA("ParticleEmitter") then
			if found ~= nil then
				return nil
			end
			found = child
		end
	end
	return found
end

local function run(): string
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return "STOP: ReplicatedStorage.Assets is missing, nothing changed"
	end
	local mockup = Workspace:FindFirstChild("Mockup_Nests")
	local art = if mockup then mockup:FindFirstChild("Art") else nil
	local group = if art then art:FindFirstChild("RefillPop") else nil
	local common = if group then group:FindFirstChild("RefillPop_Common") else nil
	local source = if common then common:FindFirstChild("SparkleShell") else nil
	if source == nil or not source:IsA("BasePart") then
		return "STOP: Workspace.Mockup_Nests.Art.RefillPop.RefillPop_Common.SparkleShell is missing or not a part, nothing changed"
	end
	local sourceEmitter = onlyEmitter(source)
	if sourceEmitter == nil then
		return "STOP: the SparkleShell does not hold exactly 1 ParticleEmitter, nothing changed"
	end

	local existing = assets:FindFirstChild(TEMPLATE_NAME)
	if existing ~= nil then
		if not existing:IsA("BasePart") then
			return "STOP: Assets.RefillPop is there but is not a part, nothing changed"
		end
		local emitter = onlyEmitter(existing)
		if emitter == nil then
			return "STOP: Assets.RefillPop is there but holds no single ParticleEmitter, nothing changed"
		end
		return `already done: {existing:GetFullName()} {emitterLine(emitter)}`
	end

	local willAdd = 1
	print(`21-nests: will add {willAdd} part (plan: {PLANNED_PARTS})`)
	if willAdd ~= PLANNED_PARTS then
		return `STOP: {willAdd} parts, the plan is {PLANNED_PARTS}, nothing changed`
	end
	if CHECK_ONLY then
		return `CHECK_ONLY: would add 1 part, Assets.RefillPop, from {source:GetFullName()}, {emitterLine(sourceEmitter)}`
	end

	ChangeHistoryService:SetWaypoint("21-nests: before")
	local copy = source:Clone()
	copy.Name = TEMPLATE_NAME
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Parent = assets
	ChangeHistoryService:SetWaypoint("21-nests: after")

	local emitter = onlyEmitter(copy)
	if emitter == nil then
		return "STOPPED: the copy lost its emitter"
	end
	return `added 1 part: {copy:GetFullName()} {emitterLine(emitter)}`
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
