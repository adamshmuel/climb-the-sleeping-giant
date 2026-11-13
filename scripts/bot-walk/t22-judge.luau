--!strict
-- Plan 5 Task 22, Part 22-2, Step 1 (work/p5t22/22-scripts.md): SERVER job, paste in Play after t22-legs-a (it needs
-- shared.T22Legs.areaList, the walk area as t22-legs-a floods it). For each ENDS entry (a jump's landing from t22-jumps or a
-- let-go landing from t22-letgo, written in at Step 2) prints IN AREA when a spot of the area lies within 2 studs flat and at
-- most 1.5 studs below the landing (the area test of t22-check4.luau), else OUT, and whether the landing is level with the
-- start or lower (end y at most start y + 0.5). Not in Play it returns "no Play:".
local CHECK_ONLY = false

local RunService = game:GetService("RunService")
-- selene: allow(global_usage)
local store = shared :: any

type Spot = { position: Vector3 }
type State = { areaList: { Spot } }
type End = { label: string, start: Vector3, feet: Vector3 }

local FLAT, BELOW, LEVEL = 2, 1.5, 0.5
-- Step 2 writes the landings here: { label = "J1.1", start = Vector3.new(...), feet = Vector3.new(...) }
local ENDS: { End } = {}

local function inArea(state: State, feet: Vector3): (boolean, number, number)
	local bestFlat, bestDy, found = math.huge, 0, false
	for _, spot in state.areaList do
		local d = spot.position - feet
		local flat = Vector3.new(d.X, 0, d.Z).Magnitude
		if flat < bestFlat then
			bestFlat, bestDy = flat, d.Y
		end
		if flat <= FLAT and d.Y >= -BELOW then
			found = true
		end
	end
	return found, bestFlat, bestDy
end

local function job(): string
	if CHECK_ONLY or not RunService:IsRunning() then
		return "no Play: nothing read"
	end
	local state = store.T22Legs :: State?
	if state == nil then
		return "STOP: paste t22-legs-a first"
	end
	local lines: { string } = {}
	local outCount, levelCount = 0, 0
	for _, e in ENDS do
		local ok, flat, dy = inArea(state, e.feet)
		local level = e.feet.Y <= e.start.Y + LEVEL
		outCount += if ok then 0 else 1
		levelCount += if level then 1 else 0
		table.insert(
			lines,
			`{e.label}: {if ok then "IN AREA" else "OUT"}, {if level then "level/lower" else "HIGHER"} ({string.format(
				"%.1f",
				e.feet.Y - e.start.Y
			)}), nearest flat {string.format("%.1f", flat)} dy {string.format("%.1f", dy)}`
		)
	end
	table.insert(lines, `{#ENDS} ends, {outCount} OUT, {levelCount} level or lower, {#state.areaList} spots`)
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

return job()
