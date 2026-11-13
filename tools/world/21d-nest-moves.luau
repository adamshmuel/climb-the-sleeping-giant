--!strict
local CHECK_ONLY = false
-- World moves, plan 5 Task 19a Step 4 (card work/p5t19/19a-card.md; picks work/p5t19/19a-note.md):
-- the four right-side nests whose spots in tools/checks/NestTable.luau the task changed (Beard Fold R, Lap Fold R, Knee
-- Pocket R, Lower Belly R) move by the difference between their Base top and their spot, so the Base top lands on the
-- spot. No other nest moves, even if it sits over MOVE_OVER studs off its spot (the left twins and Cap Side R sit up to
-- 0.34 off, inside the 0.5 the test allows, and their scores are final). More than four, or any other name, can't
-- happen: each nest is looked up by name.
-- Backs up World.EggSpots into ServerStorage.WorldBackups.p5t19 in the same call as the first change.
-- CHECK_ONLY = true measures and prints only. Report: shared.P5t19dReport.
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["21d-nest-moves"]:Clone())` through execute_luau.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MOVE_OVER = 0.02 -- studs: a nest closer than this to its spot stays where it is
local EXPECTED: { [string]: boolean } = {
	Nest_BeardFold_Right = true,
	Nest_LapFold_Right = true,
	Nest_KneePocket_Right = true,
	Nest_LowerBelly_Right = true,
}
local BACKUP_NAME = "p5t19"

local requireModule: (Instance) -> any = require :: any

type Move = { model: Model, name: string, from: Vector3, to: Vector3 }

local lines: { string } = {}
local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P5t19dReport = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	local eggSpots = if world then world:FindFirstChild("EggSpots") else nil
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	local tools = ServerStorage:FindFirstChild("Tools")
	local checks = if tools then tools:FindFirstChild("checks") else nil
	local tableModule = if checks then checks:FindFirstChild("NestTable") else nil
	if not (eggSpots and backups and tableModule) then
		return finish(
			"STOP: a name this script needs is missing (World.EggSpots, WorldBackups, Tools.checks.NestTable)"
		)
	end
	local NestTable = requireModule(tableModule:Clone())
	local byName = NestTable.BY_NAME :: { [string]: { spot: Vector3 } }

	local moves: { Move } = {}
	local seen = 0
	for _, item in eggSpots:GetChildren() do
		local base = item:FindFirstChild("Base")
		local nest = byName[item.Name]
		if item:IsA("Model") and base and base:IsA("BasePart") and nest then
			seen += 1
			local top = (base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)).Position
			if EXPECTED[item.Name] and (nest.spot - top).Magnitude > MOVE_OVER then
				table.insert(moves, { model = item, name = item.Name, from = top, to = nest.spot })
			end
		end
	end
	if seen ~= 38 then
		return finish(`STOP: {seen} nest models match NestTable, plan 38, nothing changed`)
	end
	for _, move in moves do
		table.insert(lines, string.format("%s by %s", move.name, tostring(move.to - move.from)))
	end
	if #moves == 0 then
		return finish("already done: the four nests are within 0.02 of their spots")
	end
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: would move {#moves} nests`)
	end

	ChangeHistoryService:SetWaypoint("21d nest moves: before")
	if backups:FindFirstChild(BACKUP_NAME) == nil then
		local made = Instance.new("Folder")
		made.Name = BACKUP_NAME
		eggSpots:Clone().Parent = made
		made.Parent = backups
	end
	local failed = 0
	for _, move in moves do
		local ok = pcall(function()
			move.model:PivotTo(move.model:GetPivot() + (move.to - move.from))
		end)
		if not ok then
			failed += 1
			table.insert(lines, `FAILED to move {move.name}`)
		end
	end
	ChangeHistoryService:SetWaypoint("21d nest moves: after")
	return finish(`changed: {#moves - failed} of {#moves} nests moved`)
end

return run()
