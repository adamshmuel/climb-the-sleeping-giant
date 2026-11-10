--!strict
local CHECK_ONLY = false
-- World fixes, plan 5 Task 12 Step 1b (work/p5t12/redfix-card.md, rows 1, 3, 4, 5, 8):
--  1. Nest_CuffBack_Left and Right move 0.5 along the ledge so they are 6.005 from the front nests.
--  8. Nest_CuffFront_Left and Right move 1.1 studs outward and 0.5 back so the nest box clears his sleeve.
--  3. Nest_Meadow_3b and 6b stand 4.45 studs past their bridge's end plank (NestTable garden 3 and 6, b).
--  4. Every nest model streams in always (ModelStreamingMode Persistent).
--  5. A visible prop that touches a nest's egg box moves away from the nest (the first of TRY_DISTANCES that clears every
--     padded egg box and touches no other visible part outside Nature: scenery may overlap scenery). No distance clears = STOP, nothing changed.
-- Backs up World.EggSpots and each moved prop into ServerStorage.WorldBackups.p5t12c in the same call as the first change.
-- CHECK_ONLY = true tries the moves and puts them back. Report: shared.P5t12cReport.
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["21c-nest-fixes"]:Clone())` through execute_luau.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BOX_PAD = 1 -- as in 21b: the egg box is this much wider than the template
local TRY_DISTANCES = { 3, 4, 5, 6, 7, 8, 10 }
local TURNS = { 0, 45, -45, 90, -90, 135, -135, 180 } -- degrees off "straight away from the nest", tried in this order
local NEST_MOVES: { [string]: Vector2 } = {
	Nest_Meadow_3b = Vector2.new(-68.7, -77.5),
	Nest_Meadow_6b = Vector2.new(68.7, -77.5),
	Nest_CuffBack_Left = Vector2.new(-57.51, -5.545), -- row 1: 6.005 from the front nest, still on BackLedge_Left
	Nest_CuffBack_Right = Vector2.new(57.41, -5.545),
	Nest_CuffFront_Left = Vector2.new(-56.1, -11.5), -- row 8: its box poked into his sleeve (sunk 1.02)
	Nest_CuffFront_Right = Vector2.new(56.0, -11.5),
}

type Box = { cf: CFrame, size: Vector3 }
type Move = { target: PVInstance, from: CFrame, to: CFrame, label: string }

local lines: { string } = {}
local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P5t12cReport = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	local eggSpots = if world then world:FindFirstChild("EggSpots") else nil
	local nature = if world then world:FindFirstChild("Nature") else nil
	local zones = if world then world:FindFirstChild("Zones") else nil
	local giant = if world then world:FindFirstChild("Giant") else nil
	local fx = if world then world:FindFirstChild("GiantFX") else nil
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	local assets = ServerStorage:FindFirstChild("Assets")
	local eggs = if assets then assets:FindFirstChild("Eggs") else nil
	if not (eggSpots and nature and zones and giant and fx and backups and eggs) then
		return finish("STOP: a name this script needs is missing (World parts, WorldBackups, Assets.Eggs)")
	end
	local ignore: { Instance } = { Workspace.Terrain, zones, eggSpots, fx }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local models: { Model } = {}
	for _, item in eggSpots:GetChildren() do
		if item:IsA("Model") and item:FindFirstChild("Base") then
			table.insert(models, item)
		end
	end
	if #models ~= 38 then
		return finish(`STOP: {#models} nest models, plan 38, nothing changed`)
	end

	local function boxOf(model: Model, pad: number): Box
		local base = model:FindFirstChild("Base") :: BasePart
		local template = eggs:FindFirstChild(model:GetAttribute("Rarity") :: string) :: Model
		local _, size = template:GetBoundingBox()
		local top = base.Position + Vector3.new(0, base.Size.Y / 2, 0)
		return { cf = CFrame.new(top.X, top.Y + size.Y / 2, top.Z), size = size + Vector3.new(pad, 0, pad) }
	end
	local function visible(part: BasePart): boolean
		return part.Transparency < 1 and not part:IsDescendantOf(giant)
	end
	local function touching(model: Model, pad: number): { BasePart }
		local box = boxOf(model, pad)
		local found: { BasePart } = {}
		for _, part in Workspace:GetPartBoundsInBox(box.cf, box.size, params) do
			if visible(part) then
				table.insert(found, part)
			end
		end
		return found
	end
	local function moverOf(part: BasePart): PVInstance
		local parent = part.Parent
		if
			parent
			and parent:IsA("Model")
			and parent.Parent == nature
			and string.sub(parent.Name, 1, 7) == "Nature_"
		then
			return parent
		end
		return part
	end

	local function isClear(mover: PVInstance, clearParams: OverlapParams): boolean
		for _, other in models do
			for _, hit in touching(other, BOX_PAD) do
				if hit == mover or hit:IsDescendantOf(mover) then
					return false
				end
			end
		end
		local parts: { Instance } = mover:GetDescendants()
		table.insert(parts, mover)
		for _, piece in parts do
			if piece:IsA("BasePart") and visible(piece) then
				for _, hit in Workspace:GetPartsInPart(piece, clearParams) do
					if visible(hit) and not hit:IsDescendantOf(nature) then
						return false
					end
				end
			end
		end
		return true
	end

	local moves: { Move } = {}
	local function apply(target: PVInstance, to: CFrame, label: string)
		table.insert(moves, { target = target, from = target:GetPivot(), to = to, label = label })
		target:PivotTo(to)
	end

	-- Row 3: the two meadow nests.
	for _, model in models do
		local wanted = NEST_MOVES[model.Name]
		if wanted then
			local base = model:FindFirstChild("Base") :: BasePart
			local delta = Vector3.new(wanted.X - base.Position.X, 0, wanted.Y - base.Position.Z)
			if delta.Magnitude > 0.05 then
				apply(model, model:GetPivot() + delta, `{model.Name} by {delta}`)
			end
		end
	end

	-- Row 5: props that touch an egg box move away from the nest.
	local moved: { [Instance]: boolean } = {}
	for _, model in models do
		for _, part in touching(model, 0) do
			local mover = moverOf(part)
			if not moved[mover] then
				moved[mover] = true
				local box = boxOf(model, 0)
				local away = (mover:GetPivot().Position - box.cf.Position) * Vector3.new(1, 0, 1)
				local direction = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
				local origin = mover:GetPivot()
				local own: { Instance } = table.clone(ignore)
				table.insert(own, mover)
				local clearParams = OverlapParams.new()
				clearParams.FilterType = Enum.RaycastFilterType.Exclude
				clearParams.FilterDescendantsInstances = own
				local chosen: Vector3? = nil
				for _, distance in TRY_DISTANCES do
					for _, angle in TURNS do
						local step = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(direction) * distance
						mover:PivotTo(origin + step)
						if isClear(mover, clearParams) then
							chosen = step
							break
						end
					end
					if chosen then
						break
					end
				end
				mover:PivotTo(origin)
				if chosen == nil then
					for index = #moves, 1, -1 do
						moves[index].target:PivotTo(moves[index].from)
					end
					return finish(`STOP: no distance clears {mover:GetFullName()} for {model.Name}, nothing changed`)
				end
				apply(mover, origin + chosen, `{mover:GetFullName()} by {chosen} from {model.Name}`)
			end
		end
	end

	local notPersistent = 0
	for _, model in models do
		if model.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
			notPersistent += 1
		end
	end
	for index = #moves, 1, -1 do
		moves[index].target:PivotTo(moves[index].from)
	end
	for _, move in moves do
		table.insert(lines, move.label)
	end
	if #moves == 0 and notPersistent == 0 then
		return finish("already done: nests placed, props clear, 38 Persistent")
	end
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: would make {#moves} moves and set {notPersistent} nests Persistent`)
	end

	ChangeHistoryService:SetWaypoint("21c nest fixes: before")
	local folder = backups:FindFirstChild("p5t12c")
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = "p5t12c"
		eggSpots:Clone().Parent = made
		for _, move in moves do
			if not move.target:IsDescendantOf(eggSpots) then
				local copy = move.target:Clone()
				copy:SetAttribute("BackupOf", move.target:GetFullName())
				copy.Parent = made
			end
		end
		made.Parent = backups
	end
	for _, move in moves do
		move.target:PivotTo(move.to)
	end
	for _, model in models do
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	ChangeHistoryService:SetWaypoint("21c nest fixes: after")
	return finish(`changed: {#moves} moves, {notPersistent} nests set Persistent`)
end

return run()
