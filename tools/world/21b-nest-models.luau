--!strict
-- World prep, plan 5 Task 12 Step 3a/4 (card work/p5t12/p5t12-card.md; tables work/p5t12/p5t12-tables.md; designer ruling
-- work/p5t12/placement-ruling.md; spots: tools/checks/NestTable.luau).
-- What it does, in this order:
--  1. Clones World.EggSpots (and every prop or flower clump it moves) into ServerStorage.WorldBackups.p5t12, in the same call
--     as the first change (attribute BackupOf = the old full path on the moved clones).
--  2. Removes V1's 16 bare spots (with their glow rings and EggPosts) from World.EggSpots and builds the 38 nest models
--     there: Base + PromptAnchor (cloned from V1's EggSpot_Rare_1.Base), Nest (the straw nest from Mockup_Nests.Art.Library,
--     leaned as NestTable says) and the attributes Rarity, NestName, Twin, Garden (meadow), RidesRightArm (right cuff).
--     On-him nests sit at a down ray from the map's x and z (ray from y+4, 10 down); the hit must be within 0.5 of the map.
--  3. World.NestArt (new Folder): clones of KneePocket_* (down 3.1, back 0.5), BellyPocket_* (in place) and LaceBow_*
--     (behind the toes: x +-23.25, z -58.3, same lift over the skin). The Mockup* attributes are stripped and the pieces get
--     Transparency from MockupTransparency (0 if missing), CanCollide, CanQuery and CanTouch off (not solid).
--  4. Moves 3 props (two sunflowers, the mossy boulder, exact offsets) and every Nature model that touches a Common egg box
--     at G3 A, G3 B, G4 A or G6 B away from the nest (first clear try of 3 to 10 studs, clear of the moved props).
-- Worlds, checked before any change: 38 nests and no V1 spot = nests done; 16 V1 spots and no nest = build; anything else
-- = STOP. Each other piece is "already done" on its own. "will add N (plan: M)" is printed; a count off the plan = STOP.
-- Rollback: delete World.EggSpots and World.NestArt, parent the clone WorldBackups.p5t12.EggSpots back as World.EggSpots,
-- and put each clone in WorldBackups.p5t12.Moved back at its BackupOf path.
-- CHECK_ONLY = true measures and prints only (moves are tried and put back exactly). Report: shared.P5t12Report.
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["21b-nest-models"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "p5t12"
local PLANNED_NESTS = 38
local PLANNED_REMOVED = 16
local PLANNED_ART = 6
local PLANNED_PROP_MOVES = 3
local PLANNED_CLUMP_MOVES = 7 -- measured in Edit 2026-11-10 with the ruling's box (egg size + 0.5 each side): 7 flower clumps
local HIT_TOLERANCE = 0.5
local KNEE_SHIFT = Vector3.new(0, -3.1, 0.5) -- ruling row 1b
local BOW_X, BOW_Z = 23.25, -58.3 -- ruling row 2b
local BOX_PAD = 1 -- the egg box is this much wider than the template (0.5 each side, the measure job's pad)
local TRY_DISTANCES = { 3, 4, 5, 6, 7, 8, 10 }
local CLUMP_NESTS = { "Nest_Meadow_3a", "Nest_Meadow_3b", "Nest_Meadow_4a", "Nest_Meadow_6b" }

-- Props with exact offsets (ruling rows 3): found by name and their x and z.
type PropMove = { name: string, from: Vector2, delta: Vector3 }
local PROP_MOVES: { PropMove } = {
	{ name = "Nature_Sunflower", from = Vector2.new(57.2, -80.4), delta = Vector3.new(-1.3, 0, 0.7) },
	{ name = "Nature_Sunflower", from = Vector2.new(66.9, -79.8), delta = Vector3.new(-3.0, 0, 1.8) },
	{ name = "Nature_MossyBoulder", from = Vector2.new(95.9, -5.1), delta = Vector3.new(4.5, 0, 0) },
}

type Nest = {
	name: string,
	rank: string,
	spot: Vector3,
	twin: string,
	garden: number?,
	ridesRightArm: boolean?,
	lean: Vector3,
}
type ArtItem = { source: Instance?, name: string, shift: Vector3?, bow: number? }
type Move = { target: PVInstance, to: CFrame, label: string }

local lines: { string } = {}
local function note(text: string)
	table.insert(lines, text)
end
local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P5t12Report = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function child(parent: Instance?, name: string): Instance?
	if parent == nil then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function countParts(root: Instance): number
	local count = if root:IsA("BasePart") then 1 else 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- Mockup rule: real look back, never solid, and no Mockup* attribute left.
local function restore(root: Instance)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, item in all do
		if item:IsA("BasePart") then
			local transparency = item:GetAttribute("MockupTransparency")
			item.Transparency = if type(transparency) == "number" then transparency else 0
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
		for name in item:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				item:SetAttribute(name, nil)
			end
		end
	end
end

local function displayName(nestName: string): string
	local place, side = string.match(nestName, "^Nest_(%a+)_(%w+)$")
	if place == nil then
		return nestName
	end
	local words = string.gsub(place :: string, "(%l)(%u)", "%1 %2")
	return `{words} ({side})`
end

local function run(): string
	local requireModule: (ModuleScript) -> any = require :: any
	local tableModule = child(child(child(ServerStorage, "Tools"), "checks"), "NestTable")
	local world = child(Workspace, "World")
	local eggSpots = child(world, "EggSpots")
	local nature = child(world, "Nature")
	local art = child(child(Workspace, "Mockup_Nests"), "Art")
	local library = child(art, "Library")
	local pockets = child(art, "Pockets")
	local bowsFolder = child(art, "Nests")
	local straw = child(child(child(library, "StrawNest_Final"), "body"), "body_geom")
	local strawModel = child(library, "StrawNest_Final")
	local eggTemplate = child(child(child(ServerStorage, "Assets"), "Eggs"), "Common")
	local backups = child(ServerStorage, "WorldBackups")
	if
		tableModule == nil
		or not tableModule:IsA("ModuleScript")
		or world == nil
		or eggSpots == nil
		or nature == nil
		or art == nil
		or pockets == nil
		or bowsFolder == nil
		or straw == nil
		or not straw:IsA("MeshPart")
		or strawModel == nil
		or not strawModel:IsA("Model")
		or eggTemplate == nil
		or not eggTemplate:IsA("Model")
		or backups == nil
	then
		return finish(
			"STOP: a name this script needs is missing (NestTable, World, EggSpots, Nature, mockup art, egg, backups)"
		)
	end
	local NestTable = requireModule(tableModule:Clone())
	local nests = NestTable.NESTS :: { Nest }
	local byName = NestTable.BY_NAME :: { [string]: Nest }
	local eggSize = eggTemplate:GetExtentsSize()

	-- 1. The world as it is now.
	local v1Spots: { Instance } = {}
	local present = 0
	for _, spot in eggSpots:GetChildren() do
		if byName[spot.Name] then
			present += 1
		elseif string.sub(spot.Name, 1, 8) == "EggSpot_" then
			table.insert(v1Spots, spot)
		else
			return finish(`STOP: World.EggSpots holds an unknown child {spot.Name}, nothing changed`)
		end
	end
	local buildNests = present == 0 and #v1Spots == PLANNED_REMOVED
	if not buildNests and not (present == PLANNED_NESTS and #v1Spots == 0) then
		return finish(`STOP: {present} nests and {#v1Spots} V1 spots in EggSpots, nothing changed`)
	end
	local template = child(child(eggSpots, "EggSpot_Rare_1"), "Base")
	if buildNests and (template == nil or not template:IsA("BasePart")) then
		return finish("STOP: EggSpot_Rare_1.Base (the Base template) is missing, nothing changed")
	end
	if buildNests then
		-- a copy, so destroying the V1 spots below can't strip the template's children (the red-fix cause)
		template = (template :: Instance):Clone()
	end

	-- 1b. Repair: the first build cloned a template that had lost its PromptAnchor. Add the anchor to each such Base.
	if not buildNests then
		local missing: { BasePart } = {}
		for _, nest in eggSpots:GetChildren() do
			local base = nest:FindFirstChild("Base")
			if byName[nest.Name] and base and base:IsA("BasePart") and base:FindFirstChild("PromptAnchor") == nil then
				table.insert(missing, base)
			end
		end
		if #missing > 0 then
			local source = child(child(child(child(backups, "p5t12"), "EggSpots"), "EggSpot_Rare_1"), "Base")
			local sourceAnchor = child(source, "PromptAnchor")
			if sourceAnchor == nil or not sourceAnchor:IsA("Attachment") then
				return finish(
					"STOP: WorldBackups.p5t12.EggSpots.EggSpot_Rare_1.Base.PromptAnchor is missing, nothing changed"
				)
			end
			if #missing ~= PLANNED_NESTS then
				return finish(`STOP: {#missing} bases lack an anchor, plan {PLANNED_NESTS}, nothing changed`)
			end
			if CHECK_ONLY then
				return finish(`CHECK_ONLY: {#missing} anchors planned`)
			end
			ChangeHistoryService:SetWaypoint("21b anchors: before")
			if backups:FindFirstChild("p5t12b") == nil then
				local folder = Instance.new("Folder")
				folder.Name = "p5t12b"
				eggSpots:Clone().Parent = folder
				folder.Parent = backups
			end
			for _, base in missing do
				sourceAnchor:Clone().Parent = base
			end
			ChangeHistoryService:SetWaypoint("21b anchors: after")
			return finish(`changed: {#missing} PromptAnchors added`)
		end
	end

	-- 2. Where each nest goes (a down ray for the ones on him).
	local ignore: { Instance } = { eggSpots, nature, child(Workspace, "Mockup_Nests") :: Instance }
	local nestArt = child(world, "NestArt")
	if nestArt then
		table.insert(ignore, nestArt)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	local function skin(x: number, y: number, z: number, reach: number): number?
		local hit = Workspace:Raycast(Vector3.new(x, y + 4, z), Vector3.new(0, -reach, 0), rayParams)
		return if hit then hit.Position.Y else nil
	end
	local placed: { { nest: Nest, spot: Vector3 } } = {}
	local problems: { string } = {}
	if buildNests then
		for _, nest in nests do
			local spot = nest.spot
			if nest.garden == nil then
				local hit = skin(spot.X, spot.Y, spot.Z, 10)
				if hit == nil or math.abs(hit - spot.Y) > HIT_TOLERANCE then
					table.insert(problems, `{nest.name} ray {hit} map {spot.Y}`)
				else
					spot = Vector3.new(spot.X, hit, spot.Z)
				end
			end
			table.insert(placed, { nest = nest, spot = spot })
		end
	end

	-- 3. The art pieces still to add.
	local artSources: { ArtItem } = {}
	local haveArt = 0
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		local list: { ArtItem } = {
			{ source = child(pockets, `KneePocket_{side}`), name = `KneePocket_{side}`, shift = KNEE_SHIFT },
			{ source = child(pockets, `BellyPocket_{side}`), name = `BellyPocket_{side}` },
			{ source = child(bowsFolder, `LaceBow_{side}`), name = `LaceBow_{side}`, bow = sign },
		}
		for _, item in list do
			if child(nestArt, item.name) then
				haveArt += 1
			elseif item.source == nil then
				table.insert(problems, `{item.name} source missing`)
			else
				table.insert(artSources, item)
			end
		end
	end
	local artParts = 0
	for _, item in artSources do
		artParts += countParts(item.source :: Instance)
	end

	-- 4. Moves: try them, record them, put every part back exactly.
	local snapshot: { [BasePart]: CFrame? } = {}
	local pivots: { [Model]: CFrame? } = {}
	local function remember(item: PVInstance)
		local all = item:GetDescendants()
		table.insert(all, item)
		for _, d in all do
			if d:IsA("BasePart") and snapshot[d] == nil then
				snapshot[d] = d.CFrame
			end
			if d:IsA("Model") and pivots[d] == nil and d.PrimaryPart == nil then
				pivots[d] = d.WorldPivot
			end
		end
	end
	local function putBack()
		for part, cf in snapshot do
			part.CFrame = cf :: CFrame
		end
		for model, cf in pivots do
			model.WorldPivot = cf :: CFrame
		end
	end

	local moves: { Move } = {}
	local propModels: { Instance } = {}
	local propsDone = 0
	for _, prop in PROP_MOVES do
		local found: PVInstance? = nil
		for _, c in nature:GetChildren() do
			if c.Name == prop.name and c:IsA("PVInstance") then
				local at = c:GetPivot().Position
				local flat = Vector2.new(at.X, at.Z)
				if (flat - prop.from).Magnitude < 0.3 then
					found = c
					table.insert(
						moves,
						{ target = c, to = c:GetPivot() + prop.delta, label = `{prop.name} {prop.from}` }
					)
					break
				elseif (flat - (prop.from + Vector2.new(prop.delta.X, prop.delta.Z))).Magnitude < 0.3 then
					found = c
					propsDone += 1
					break
				end
			end
		end
		if found == nil then
			table.insert(problems, `prop {prop.name} at {prop.from} not found`)
		else
			table.insert(propModels, found)
		end
	end
	local propMoveCount = #moves
	for _, move in moves do
		remember(move.target)
		move.target:PivotTo(move.to)
	end

	local boxes: { { cf: CFrame, size: Vector3 } } = {}
	for _, name in CLUMP_NESTS do
		local spot = byName[name].spot
		table.insert(boxes, {
			cf = CFrame.new(spot.X, spot.Y + eggSize.Y / 2, spot.Z),
			size = Vector3.new(eggSize.X + BOX_PAD, eggSize.Y, eggSize.Z + BOX_PAD),
		})
	end
	local onlyNature = OverlapParams.new()
	onlyNature.FilterType = Enum.RaycastFilterType.Include
	onlyNature.FilterDescendantsInstances = { nature }
	local onlyProps = OverlapParams.new()
	onlyProps.FilterType = Enum.RaycastFilterType.Include
	onlyProps.FilterDescendantsInstances = propModels
	local function touched(): { [Instance]: Vector3? }
		local set: { [Instance]: Vector3? } = {}
		for _, box in boxes do
			for _, part in Workspace:GetPartBoundsInBox(box.cf, box.size, onlyNature) do
				local top: Instance = part
				while top.Parent ~= nil and top.Parent ~= nature do
					top = top.Parent :: Instance
				end
				if top.Parent == nature and set[top] == nil then
					set[top] = box.cf.Position
				end
			end
		end
		return set
	end
	local function hitsProp(item: PVInstance): boolean
		local all = item:GetDescendants()
		table.insert(all, item)
		for _, d in all do
			if d:IsA("BasePart") and #Workspace:GetPartsInPart(d, onlyProps) > 0 then
				return true
			end
		end
		return false
	end
	local isProp: { [Instance]: boolean } = {}
	for _, prop in propModels do
		isProp[prop] = true
	end
	for prop in isProp do
		if touched()[prop] then
			table.insert(problems, `prop {prop.Name} still touches a nest box`)
		end
	end
	for item, centre in touched() do
		if isProp[item] or not item:IsA("PVInstance") then
			continue
		end
		remember(item)
		local from = item:GetPivot()
		local at = centre :: Vector3
		local flat = Vector3.new(from.X - at.X, 0, from.Z - at.Z)
		local direction = if flat.Magnitude < 0.1 then Vector3.new(0, 0, 1) else flat.Unit
		local chosen: number? = nil
		for _, distance in TRY_DISTANCES do
			item:PivotTo(from + direction * distance)
			if touched()[item] == nil and not hitsProp(item) then
				chosen = distance
				break
			end
		end
		item:PivotTo(from)
		if chosen == nil then
			table.insert(problems, `clump {item.Name} has no clear move up to 10 studs`)
		else
			table.insert(moves, { target = item, to = from + direction * chosen, label = `{item.Name} {chosen}` })
		end
	end
	putBack()
	local clumpMoves = #moves - propMoveCount

	-- 5. Report and the plan check.
	note(`removes {#v1Spots} V1 spots; nests {present} of {PLANNED_NESTS}; art {haveArt} of {PLANNED_ART} there`)
	for _, move in moves do
		note(`move {move.label}`)
	end
	for _, line in problems do
		note(`PROBLEM: {line}`)
	end
	local addNests = if buildNests then #placed else 0
	local addParts = addNests * 2 + artParts
	print(
		`21b-nest-models: will add {addNests} nests, {#artSources} art pieces, {addParts} parts (plan: {if buildNests
			then PLANNED_NESTS
			else 0} nests, {PLANNED_ART - haveArt} art)`
	)
	if #problems > 0 then
		return finish(`STOP: {#problems} problems, nothing changed`)
	end
	if addNests ~= (if buildNests then PLANNED_NESTS else 0) or #artSources ~= PLANNED_ART - haveArt then
		return finish("STOP: the nests or art pieces to add are not the plan, nothing changed")
	end
	if propMoveCount + propsDone ~= PLANNED_PROP_MOVES or (clumpMoves ~= PLANNED_CLUMP_MOVES and clumpMoves ~= 0) then
		return finish(
			`STOP: {propMoveCount} prop and {clumpMoves} clump moves, plan {PLANNED_PROP_MOVES} and {PLANNED_CLUMP_MOVES}`
		)
	end
	if addNests == 0 and #artSources == 0 and #moves == 0 then
		return finish("already done: 38 nests, 6 art pieces, props and flowers in place")
	end
	if CHECK_ONLY then
		return finish(
			`CHECK_ONLY: would add {addNests} nests, {#artSources} art pieces, move {#moves} items, remove {#v1Spots} V1 spots`
		)
	end

	-- 6. The change: backup first.
	ChangeHistoryService:SetWaypoint("21b nest models: before")
	local backup = backups:FindFirstChild(BACKUP_NAME)
	if backup == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		eggSpots:Clone().Parent = folder
		local movedFolder = Instance.new("Folder")
		movedFolder.Name = "Moved"
		for _, move in moves do
			local copy = move.target:Clone()
			copy:SetAttribute("BackupOf", move.target:GetFullName())
			copy.Parent = movedFolder
		end
		movedFolder.Parent = folder
		folder.Parent = backups
	end
	for _, move in moves do
		move.target:PivotTo(move.to)
	end
	if buildNests then
		for _, spot in v1Spots do
			spot:Destroy()
		end
		local strawPivot = strawModel:GetPivot()
		for _, item in placed do
			local nest = item.nest
			local model = Instance.new("Model")
			model.Name = nest.name
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			local base = (template :: BasePart):Clone()
			base.Name = "Base"
			base.Anchored = true
			base.CFrame = CFrame.new(item.spot.X, item.spot.Y - base.Size.Y / 2, item.spot.Z)
			base.Parent = model
			local strawCopy = straw:Clone()
			strawCopy.Name = "Nest"
			local atSpot = table.clone(nest)
			atSpot.spot = item.spot
			local pivot = NestTable.nestPivot(atSpot) :: CFrame
			strawCopy.CFrame = pivot * strawPivot:ToObjectSpace(straw.CFrame)
			strawCopy.Anchored = true
			restore(strawCopy)
			strawCopy.Parent = model
			model.PrimaryPart = base
			model:SetAttribute("Rarity", nest.rank)
			model:SetAttribute("NestName", displayName(nest.name))
			model:SetAttribute("Twin", nest.twin)
			model:SetAttribute("Garden", nest.garden)
			if nest.ridesRightArm then
				model:SetAttribute("RidesRightArm", true)
				base:SetAttribute("RidesRightArm", true)
				strawCopy:SetAttribute("RidesRightArm", true)
			end
			model.Parent = eggSpots
		end
	end
	if nestArt == nil then
		local folder = Instance.new("Folder")
		folder.Name = "NestArt"
		folder.Parent = world
		nestArt = folder
	end
	for _, item in artSources do
		local copy = (item.source :: Instance):Clone()
		copy.Name = item.name
		restore(copy)
		if copy:IsA("PVInstance") then
			local pivot = copy:GetPivot()
			if item.shift then
				copy:PivotTo(pivot + item.shift)
			elseif item.bow then
				local lift = pivot.Y - (skin(pivot.X, pivot.Y, pivot.Z, 12) or pivot.Y)
				local newSkin = skin(item.bow * BOW_X, pivot.Y, BOW_Z, 12) or pivot.Y
				copy:PivotTo(CFrame.new(item.bow * BOW_X, newSkin + lift, BOW_Z) * pivot.Rotation)
			end
		end
		copy.Parent = nestArt
	end
	ChangeHistoryService:SetWaypoint("21b nest models: after")
	return finish(`changed: {addNests} nests, {#artSources} art pieces, {#moves} moves, {#v1Spots} V1 spots removed`)
end

return run()
