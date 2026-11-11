--!strict
-- Plan 5 Task 22, Part 22-1, Step 4 (work/p5t22/22-step4-card.md, part 1 item 5): SERVER job, paste in Play after t22-legs-a
-- and t22-legs-b. Prints (1) the grab prompt's Enabled on the 4 Nest_Cuff* nests (Grab.luau line 223: on only while an egg waits),
-- (2) for the ends of leg 29 (-29.2, 56.6, 13.0) and leg 74 (-9.0, 41.8, -41.2): IN AREA when a spot of shared.T22Legs.areaList
-- (the walk area, as t22-legs-a floods it) lies within 2 studs flat and at most 1.5 studs below the end, else OUT.
-- (The card says T22Legs.area; that is only the box, the spot list is areaList.) Not in Play it returns "no Play:".
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
-- selene: allow(global_usage)
local store = shared :: any

type Spot = { position: Vector3 }
type State = { areaList: { Spot } }

local FLAT, BELOW = 2, 1.5
local ENDS: { { n: number, feet: Vector3 } } = {
	{ n = 29, feet = Vector3.new(-29.2, 56.6, 13.0) },
	{ n = 74, feet = Vector3.new(-9.0, 41.8, -41.2) },
}

local function job(): string
	if not RunService:IsRunning() then
		return "no Play: nothing read"
	end
	local lines: { string } = {}
	local world = Workspace:FindFirstChild("World")
	local spots = if world ~= nil then world:FindFirstChild("EggSpots") else nil
	for _, name in { "Nest_CuffFront_Left", "Nest_CuffBack_Left", "Nest_CuffFront_Right", "Nest_CuffBack_Right" } do
		local nest = if spots ~= nil then spots:FindFirstChild(name) else nil
		local prompt = if nest ~= nil then nest:FindFirstChildWhichIsA("ProximityPrompt", true) else nil
		table.insert(
			lines,
			`{name}: {if prompt == nil then "NO PROMPT" else if prompt.Enabled then "EGG (prompt on)" else "empty (off)"}`
		)
	end
	local state = store.T22Legs :: State?
	if state == nil then
		return "STOP: paste t22-legs-a first"
	end
	for _, e in ENDS do
		local bestFlat, bestDy = math.huge, 0
		for _, spot in state.areaList do
			local d = spot.position - e.feet
			local flat = Vector3.new(d.X, 0, d.Z).Magnitude
			if flat < bestFlat then
				bestFlat, bestDy = flat, d.Y
			end
		end
		local ok = false
		for _, spot in state.areaList do
			local d = spot.position - e.feet
			if Vector3.new(d.X, 0, d.Z).Magnitude <= FLAT and d.Y >= -BELOW then
				ok = true
				break
			end
		end
		table.insert(
			lines,
			`O/X {e.n}: {if ok then "IN AREA" else "OUT"}, nearest spot flat {string.format("%.1f", bestFlat)}, dy {string.format(
				"%.1f",
				bestDy
			)} ({#state.areaList} spots)`
		)
	end
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

return job()
