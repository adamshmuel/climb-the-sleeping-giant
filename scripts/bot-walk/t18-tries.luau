-- Plan 3 Task 18, Step 1 (work/p3t18/t18-card.md): CLIENT job in Play, pasted JOINED after client-a (it uses client-a's
-- press, drive, placeBot, settle, landingWatch, feetOf, bot, rayParams, Workspace, ST and ZERO; no --!strict here, the joined
-- paste takes client-a's). Three groups, one table (TRIES):
--   S  skin tries (Check D2): from each boot top the real character walks flat at Rare egg 1 for 4 s, no jump.
--   J  jump tries (Check D4): 1 jump each, pushed toward the belly ramp's foot, from every 3 studs along the 2 lap plank
--      decks and the 2 boot-top lines (ladder top toward the plank). Same jump as t22-jumps: press(dir, 0.6, true).
--   X  fail proof: one jump from the first left plank row onto T18TestRamp (the Server paste t18-xpart makes it first).
-- Per try it logs the landing feet, the highest feet y, and the chain of names under the feet (part < parents).
-- Results: shared.T18Tries = { lines, ends, done, error }; t18-judge reads it (paste it in the Client, same as this job).
local CHECK_ONLY = false

-- selene: allow(global_usage)
local triesStore = shared :: any

local JUMP_PUSH, WALK_SECONDS, GROUND_WAIT, LAND_WAIT = 0.6, 4, 3, 4

-- Edit read 2026-11-12: Nest_LowerBelly_Left (-12.5, 41.5, -40.3) and Nest_LowerBelly_Right (12.5, 40.8, -40.3) are Rare egg 1.
local EGG_LEFT, EGG_RIGHT = Vector3.new(-12.5, 0, -40.3), Vector3.new(12.5, 0, -40.3)
-- Edit read 2026-11-12: BellyRamp_Left / BellyRamp_Right, lowest Piece1 at (-1.9, 33.3, -49.3) / (1.9, 33.3, -49.3).
local RAMP_FOOT_LEFT, RAMP_FOOT_RIGHT = Vector3.new(-1.9, 0, -49.3), Vector3.new(1.9, 0, -49.3)

type Try = { label: string, kind: string, feet: Vector3, dir: Vector3 }
type TryEnd = {
	label: string,
	kind: string,
	sx: number,
	sy: number,
	sz: number,
	ex: number,
	ey: number,
	ez: number,
	maxY: number,
	landed: boolean,
	chain: string,
}

local function flatToward(from: Vector3, target: Vector3): Vector3
	return Vector3.new(target.X - from.X, 0, target.Z - from.Z).Unit
end

local function row(label: string, kind: string, x: number, y: number, z: number, foot: Vector3): Try
	local feet = Vector3.new(x, y, z)
	return { label = label, kind = kind, feet = feet, dir = flatToward(feet, foot) }
end

-- Edit rays 2026-11-12 (down from above, hit + 0.1, measured): boot tops J1/J2 y 26.56 / 26.83 (legs_and_boots, 2026-11-11);
-- plank decks every 2.9 studs along LapPlank_Left/_Right.Deck's centre line (Deck, y 29.91 to 33.11); boot-top lines from
-- BootLadder TopPad (-29.6, -64.2) toward the plank's low end (legs_and_boots / TopPad, y 29.83 to 30.50).
local TRIES: { Try } = {
	row("S1", "S", -21, 26.56, -50, EGG_LEFT),
	row("S2", "S", 21, 26.83, -50, EGG_RIGHT),
	row("PL1", "J", -20.5, 29.91, -55.5, RAMP_FOOT_LEFT),
	row("PL2", "J", -17.6, 30.55, -55.3, RAMP_FOOT_LEFT),
	row("PL3", "J", -14.7, 31.19, -55.1, RAMP_FOOT_LEFT),
	row("PL4", "J", -11.7, 31.83, -54.9, RAMP_FOOT_LEFT),
	row("PL5", "J", -8.8, 32.47, -54.7, RAMP_FOOT_LEFT),
	row("PL6", "J", -5.9, 33.11, -54.6, RAMP_FOOT_LEFT),
	row("BL1", "J", -29.6, 30.5, -64.2, RAMP_FOOT_LEFT),
	row("BL2", "J", -27.6, 30.5, -62.1, RAMP_FOOT_LEFT),
	row("BL3", "J", -25.5, 30.21, -59.9, RAMP_FOOT_LEFT),
	row("BL4", "J", -23.4, 29.88, -57.7, RAMP_FOOT_LEFT),
	row("PR1", "J", 20.5, 29.91, -55.5, RAMP_FOOT_RIGHT),
	row("PR2", "J", 17.6, 30.55, -55.3, RAMP_FOOT_RIGHT),
	row("PR3", "J", 14.7, 31.19, -55.1, RAMP_FOOT_RIGHT),
	row("PR4", "J", 11.7, 31.83, -54.9, RAMP_FOOT_RIGHT),
	row("PR5", "J", 8.8, 32.47, -54.7, RAMP_FOOT_RIGHT),
	row("PR6", "J", 5.9, 33.11, -54.6, RAMP_FOOT_RIGHT),
	row("BR1", "J", 29.6, 30.5, -64.2, RAMP_FOOT_RIGHT),
	row("BR2", "J", 27.6, 30.5, -62.1, RAMP_FOOT_RIGHT),
	row("BR3", "J", 25.5, 30.17, -59.9, RAMP_FOOT_RIGHT),
	row("BR4", "J", 23.4, 29.83, -57.7, RAMP_FOOT_RIGHT),
	-- X: the same start and push as PL1; t18-xpart puts T18TestRamp straight ahead of it.
	row("X1", "X", -20.5, 29.91, -55.5, RAMP_FOOT_LEFT),
}

-- The names from the part under the feet up to Workspace, for example "Piece1 < BellyRamp_Left < WalkSurfaces < World".
local function chainUnder(feet: Vector3, root: BasePart): string
	rayParams.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(feet + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)
	if hit == nil then
		return "nothing"
	end
	local names: { string } = {}
	local node: Instance? = hit.Instance
	while node ~= nil and node ~= Workspace and #names < 5 do
		table.insert(names, node.Name)
		node = node.Parent
	end
	return table.concat(names, " < ")
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

local function tryOnce(t: Try): (string, TryEnd)
	local humanoid, root = bot()
	placeBot(t.feet)
	settle(humanoid)
	local waited = 0
	while humanoid.FloorMaterial == Enum.Material.Air and waited < GROUND_WAIT do
		waited += task.wait()
	end
	local standing = feetOf(root)
	local maxY = standing.Y
	if humanoid.FloorMaterial == Enum.Material.Air then
		maxY = math.max(maxY, standing.Y)
	else
		if t.kind == "S" then
			drive(function(_elapsed: number)
				maxY = math.max(maxY, feetOf(root).Y)
				return t.dir, false
			end, WALK_SECONDS)
		else
			press(t.dir, JUMP_PUSH, true)
		end
	end
	local feet, landed = waitLanded(humanoid, root)
	maxY = math.max(maxY, feet.Y)
	local chain = if humanoid.FloorMaterial == Enum.Material.Air and feet == standing
		then "NOGROUND"
		else chainUnder(feet, root)
	local line = string.format(
		"%s start %.1f, %.1f, %.1f end %.1f, %.1f, %.1f max y %.1f %s on %s",
		t.label,
		standing.X,
		standing.Y,
		standing.Z,
		feet.X,
		feet.Y,
		feet.Z,
		maxY,
		if landed then "landed" else "NOLAND",
		chain
	)
	local record: TryEnd = {
		label = t.label,
		kind = t.kind,
		sx = standing.X,
		sy = standing.Y,
		sz = standing.Z,
		ex = feet.X,
		ey = feet.Y,
		ez = feet.Z,
		maxY = maxY,
		landed = landed,
		chain = chain,
	}
	return line, record
end

local function runTries(): ()
	local lines: { string } = {}
	local ends: { TryEnd } = {}
	local state = { lines = lines, ends = ends, done = false, error = "" }
	triesStore.T18Tries = state
	local ok, failure = pcall(function()
		for _, t in TRIES do
			local line, record = tryOnce(t)
			table.insert(lines, line)
			print("T18 " .. line)
			table.insert(ends, record)
		end
	end)
	state.error = if ok then "" else tostring(failure)
	state.done = true
end

-- client-a's runLeg is for client-b's loop; named here so the joined lint sees it used (this job does not call it).
local _ = runLeg

if not CHECK_ONLY then
	task.spawn(runTries)
end
