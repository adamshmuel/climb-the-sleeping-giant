-- Plan 5 Task 22, Part 22-2, Step 1 (work/p5t22/22-2-card.md, "t22-jumps"): CLIENT job in Play, pasted JOINED after client-a
-- (it uses client-a's press, placeBot, settle, landingWatch, feetOf, bot, drive and ZERO; no --!strict here, the joined paste
-- takes client-a's). Per start (J1 to J8): stand, wait for the floor, then 3 jumps, each from the start again, pushed straight in
-- with press(dir, 0.6, true). Per jump it logs the landing feet, the part under them, any Climbing state and any PromptShown.
-- Results: shared.T22Jumps = { lines, ends, done, error }. ends hold plain numbers for t22-judge's ENDS (label, start, feet).
-- The start feet are the Edit down-ray hits of 2026-11-11 plus 0.1 (a part name per start is in the comment).
local CHECK_ONLY = false

local ProximityPromptService = game:GetService("ProximityPromptService")
-- selene: allow(global_usage)
local jumpStore = shared :: any

local JUMP_PUSH, JUMPS, GROUND_WAIT, LAND_WAIT = 0.6, 3, 3, 4
-- The cuff front nests (World.EggSpots.Nest_CuffFront_Left / _Right, flat position) that J3 and J4 push toward.
local CUFF_LEFT, CUFF_RIGHT = Vector3.new(-56.1, 0, -11.5), Vector3.new(56.0, 0, -11.5)

type JumpStart = { label: string, feet: Vector3, dir: Vector3 }
type Seen = { climbed: boolean, prompts: { string } }
type JumpEnd = {
	label: string,
	sx: number,
	sy: number,
	sz: number,
	ex: number,
	ey: number,
	ez: number,
	under: string,
}

local function flatToward(from: Vector3, target: Vector3): Vector3
	return Vector3.new(target.X - from.X, 0, target.Z - from.Z).Unit
end

-- Edit rays 2026-11-11 (down from above, hit + 0.1): J1 -21 legs_and_boots y 26.46, J2 21 legs_and_boots 26.73,
-- J3 -27 legs_and_boots 29.39, J4 27 legs_and_boots 29.30, J5/J6 Terrain 2.00, J7/J8 LapPlank_Left/_Right.Deck 33.03.
local JUMP_STARTS: { JumpStart } = {
	{ label = "J1", feet = Vector3.new(-21, 26.56, -50), dir = Vector3.zAxis },
	{ label = "J2", feet = Vector3.new(21, 26.83, -50), dir = Vector3.zAxis },
	{ label = "J3", feet = Vector3.new(-27, 29.49, -58), dir = flatToward(Vector3.new(-27, 0, -58), CUFF_LEFT) },
	{ label = "J4", feet = Vector3.new(27, 29.40, -58), dir = flatToward(Vector3.new(27, 0, -58), CUFF_RIGHT) },
	{ label = "J5", feet = Vector3.new(-56, 2.1, -20), dir = Vector3.zAxis },
	{ label = "J6", feet = Vector3.new(56, 2.1, -20), dir = Vector3.zAxis },
	{ label = "J7", feet = Vector3.new(-6, 33.13, -52), dir = Vector3.zAxis },
	{ label = "J8", feet = Vector3.new(6, 33.13, -52), dir = Vector3.zAxis },
}

local function partUnder(feet: Vector3, root: BasePart): string
	rayParams.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(feet + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)
	if hit == nil then
		return "nothing"
	end
	local parent = hit.Instance.Parent
	return `{hit.Instance.Name} in {if parent ~= nil then parent.Name else "?"}`
end

-- Waits for the landing (floor, calm 0.5 s) and returns the feet and whether it landed.
local function waitLanded(humanoid: Humanoid, root: BasePart): (Vector3, boolean)
	local watch = landingWatch(humanoid, root)
	local landed = false
	drive(function(elapsed: number)
		if watch(elapsed) then
			landed = true
			return nil, nil
		end
		return ZERO, false
	end, LAND_WAIT)
	return feetOf(root), landed
end

local function jumpOnce(s: JumpStart, k: number, seen: Seen): (string, JumpEnd?)
	local humanoid, root = bot()
	local tag = `{s.label}.{k}`
	placeBot(s.feet)
	settle(humanoid)
	local waited = 0
	while humanoid.FloorMaterial == Enum.Material.Air and waited < GROUND_WAIT do
		waited += task.wait()
	end
	local standing = feetOf(root)
	if humanoid.FloorMaterial == Enum.Material.Air then
		return `{tag} NOGROUND at {string.format("%.1f, %.1f, %.1f", standing.X, standing.Y, standing.Z)}`, nil
	end
	seen.climbed, seen.prompts = false, {}
	press(s.dir, JUMP_PUSH, true)
	local feet, landed = waitLanded(humanoid, root)
	local under = partUnder(feet, root)
	local line = string.format(
		"%s start %.1f, %.1f, %.1f end %.1f, %.1f, %.1f dy %.1f %s on %s climbed %s prompts %d%s",
		tag,
		standing.X,
		standing.Y,
		standing.Z,
		feet.X,
		feet.Y,
		feet.Z,
		feet.Y - standing.Y,
		if landed then "landed" else "NOLAND",
		under,
		tostring(seen.climbed),
		#seen.prompts,
		if #seen.prompts > 0 then " (" .. table.concat(seen.prompts, ",") .. ")" else ""
	)
	local record: JumpEnd = {
		label = tag,
		sx = standing.X,
		sy = standing.Y,
		sz = standing.Z,
		ex = feet.X,
		ey = feet.Y,
		ez = feet.Z,
		under = under,
	}
	return line, record
end

local function runJumps(): ()
	local lines: { string } = {}
	local ends: { JumpEnd } = {}
	local state = { lines = lines, ends = ends, done = false, error = "" }
	jumpStore.T22Jumps = state
	local humanoid = bot()
	local seen: Seen = { climbed = false, prompts = {} }
	local stateConn = humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == ST.Climbing then
			seen.climbed = true
		end
	end)
	local promptConn = ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local owner = prompt.Parent
		table.insert(seen.prompts, if owner ~= nil then owner.Name else "?")
	end)
	local ok, failure = pcall(function()
		for _, s in JUMP_STARTS do
			for k = 1, JUMPS do
				local line, record = jumpOnce(s, k, seen)
				table.insert(lines, line)
				print("T22 jump " .. line)
				if record ~= nil then
					table.insert(ends, record)
				end
			end
		end
	end)
	stateConn:Disconnect()
	promptConn:Disconnect()
	state.error = if ok then "" else tostring(failure)
	state.done = true
end

-- client-a's runLeg is for client-b's loop; named here so the joined lint sees it used (this job does not call it).
local _ = runLeg

if not CHECK_ONLY then
	task.spawn(runJumps)
end
