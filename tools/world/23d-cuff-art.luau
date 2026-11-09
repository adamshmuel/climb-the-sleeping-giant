--!strict
-- World prep, plan 5 Task 15e3: the visible cuff strap and cuff pocket art goes into the world
-- (ruling work/p5t15e3/art-decision.md, card work/p5t15e3/15e3-card.md; spec 5 section 5 "Cuff strap and ledge (Epic)",
-- Rule 79 and Rule 100).
-- Why: the walk pieces in Workspace.World.CuffWalk are invisible. The art they stand on lived only in the mockup folder
-- Workspace.Mockup_Nests.Art (every piece there is CanQuery off and CanCollide off), so the ledge showed no ground.
-- What it does: for each of the 6 source models (Art.Straps.CuffStrap_Left and _Right, Art.Pockets.CuffPocketFront_Left,
-- CuffPocketBack_Left, CuffPocketFront_Right, CuffPocketBack_Right) it makes a Model of the same name in the new Folder
-- Workspace.World.CuffArt and clones into it every Part or MeshPart whose MockupTransparency is 0 (the invisible walk and
-- curb clones inside Art.Straps have 1 and stay behind). Each clone gets CanCollide, CanQuery, CanTouch and Transparency
-- from its own Mockup* attributes, then loses every Mockup* attribute; CanCollide is then forced off (art is never solid).
-- Every piece of a _Right model also gets RidesRightArm = true (Rule 100); the left arm gets none.
-- The source art is not touched. The new folder holds only copies, so there is no backup clone.
-- STOP (nothing changed, the reason is reported): World, a source model or Mockup_Nests missing; a model's visible count
-- not as planned (17, 17 and 4 x 12 = 82); CuffArt there already but not complete (a partial copy).
-- CuffArt complete (6 models, 82 pieces, none with a Mockup* attribute) = "already done".
-- CHECK_ONLY = true counts and prints only (nothing is created). Full report: shared.T15e3Report (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["23d-cuff-art"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MOCKUP_PREFIX = "Mockup"
local TOTAL = 82
-- Source group, model name, planned visible pieces (plan 5 Task 15e3 world table, measured in Edit by code_lead).
local MODELS: { { group: string, name: string, count: number } } = {
	{ group = "Straps", name = "CuffStrap_Left", count = 17 },
	{ group = "Straps", name = "CuffStrap_Right", count = 17 },
	{ group = "Pockets", name = "CuffPocketFront_Left", count = 12 },
	{ group = "Pockets", name = "CuffPocketBack_Left", count = 12 },
	{ group = "Pockets", name = "CuffPocketFront_Right", count = 12 },
	{ group = "Pockets", name = "CuffPocketBack_Right", count = 12 },
}

local report: { string } = {}

local function finish(text: string): string
	-- selene: allow(global_usage)
	shared.T15e3Report = report
	return text
end

-- The visible pieces of a source model: its Parts and MeshParts whose MockupTransparency is 0.
local function visiblePieces(source: Instance): { BasePart }
	local list: { BasePart } = {}
	for _, child in source:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("MockupTransparency") == 0 then
			table.insert(list, child)
		end
	end
	return list
end

local function hasMockupAttribute(object: Instance): boolean
	for name in object:GetAttributes() do
		if string.sub(name, 1, #MOCKUP_PREFIX) == MOCKUP_PREFIX then
			return true
		end
	end
	return false
end

-- Gives a clone (and anything inside it) its saved values, removes every Mockup* attribute, then forces CanCollide off.
local function settle(copy: BasePart)
	local objects: { Instance } = copy:GetDescendants()
	table.insert(objects, copy)
	for _, object in objects do
		if object:IsA("BasePart") then
			local collide = object:GetAttribute("MockupCanCollide")
			local query = object:GetAttribute("MockupCanQuery")
			local touch = object:GetAttribute("MockupCanTouch")
			if type(collide) == "boolean" then
				object.CanCollide = collide
			end
			if type(query) == "boolean" then
				object.CanQuery = query
			end
			if type(touch) == "boolean" then
				object.CanTouch = touch
			end
		end
		if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
			local transparency = object:GetAttribute("MockupTransparency")
			if type(transparency) == "number" then
				(object :: BasePart).Transparency = transparency
			end
		end
		for name in object:GetAttributes() do
			if string.sub(name, 1, #MOCKUP_PREFIX) == MOCKUP_PREFIX then
				object:SetAttribute(name, nil)
			end
		end
	end
	copy.CanCollide = false
end

-- True when World.CuffArt already holds every model with its planned count and no Mockup* attribute; false when it is not
-- there at all; nil (with a reason) when it is there but not complete.
local function existingState(world: Instance): (boolean?, string)
	local folder = world:FindFirstChild("CuffArt")
	if folder == nil then
		return false, ""
	end
	local pieces = 0
	for _, entry in MODELS do
		local model = folder:FindFirstChild(entry.name)
		if model == nil then
			return nil, `World.CuffArt is there but {entry.name} is missing`
		end
		local count = 0
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				count += 1
				if hasMockupAttribute(child) then
					return nil, `World.CuffArt.{entry.name}.{child.Name} still has a Mockup attribute`
				end
			end
		end
		if count ~= entry.count then
			return nil, `World.CuffArt.{entry.name} holds {count} pieces, planned {entry.count}`
		end
		pieces += count
	end
	if pieces ~= TOTAL then
		return nil, `World.CuffArt holds {pieces} pieces, planned {TOTAL}`
	end
	return true, ""
end

local function run23d(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		return finish("STOP: Workspace.World is missing, nothing changed")
	end
	local complete, why = existingState(world)
	if complete == true then
		return finish("already done")
	elseif complete == nil then
		return finish(`STOP: {why}, nothing changed`)
	end

	local nests = Workspace:FindFirstChild("Mockup_Nests")
	local art = if nests ~= nil then nests:FindFirstChild("Art") else nil
	if art == nil then
		return finish("STOP: Workspace.Mockup_Nests.Art is missing, nothing changed")
	end

	local plan: { { entry: typeof(MODELS[1]), pieces: { BasePart } } } = {}
	local total = 0
	local lines: { string } = {}
	for _, entry in MODELS do
		local group = art:FindFirstChild(entry.group)
		local source = if group ~= nil then group:FindFirstChild(entry.name) else nil
		if source == nil then
			return finish(`STOP: Mockup_Nests.Art.{entry.group}.{entry.name} is missing, nothing changed`)
		end
		local pieces = visiblePieces(source)
		if #pieces ~= entry.count then
			return finish(`STOP: {entry.name} has {#pieces} visible pieces, planned {entry.count}, nothing changed`)
		end
		total += #pieces
		table.insert(plan, { entry = entry, pieces = pieces })
		table.insert(lines, `{entry.name} {#pieces}`)
	end
	table.insert(report, table.concat(lines, ", "))
	print(`23d-cuff-art: will copy {total} pieces into {#plan} models (plan: {TOTAL} into {#MODELS})`)
	if total ~= TOTAL then
		return finish(`STOP: {total} pieces, the plan is {TOTAL}, nothing changed`)
	end
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: would copy {total} pieces into {#plan} models | {table.concat(lines, " | ")}`)
	end

	ChangeHistoryService:SetWaypoint("23d-cuff-art: before")
	local folder = Instance.new("Folder")
	folder.Name = "CuffArt"
	local rides = 0
	for _, item in plan do
		local model = Instance.new("Model")
		model.Name = item.entry.name
		local right = string.sub(item.entry.name, -6) == "_Right"
		for _, piece in item.pieces do
			local copy = piece:Clone()
			settle(copy)
			if right then
				copy:SetAttribute("RidesRightArm", true)
				rides += 1
			end
			copy.Parent = model
		end
		model.Parent = folder
	end
	folder.Parent = world
	ChangeHistoryService:SetWaypoint("23d-cuff-art: after")

	local verified, verifiedWhy = existingState(world)
	if verified ~= true then
		return finish(`copied {total} pieces but the check failed: {verifiedWhy}`)
	end
	return finish(
		`copied {total} pieces into {#plan} models ({rides} marked RidesRightArm) | {table.concat(lines, " | ")}`
	)
end

return run23d()
