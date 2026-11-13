-- Plan 5 Task 22, Part 22-2, Step 1 (work/p5t22/22-2-card.md, "t22-letgo"): CLIENT job in Play, pasted JOINED after client-a
-- (uses client-a's press, placeBot, settle, landingWatch, feetOf, bot, drive and ZERO; no --!strict here, the joined paste takes
-- client-a's). 6 tries on the BeardLadder: each side (x -1.5 then +1.5 of the foot, 1.5 studs back) climbs by pressing into the
-- rungs, then lets go at 50% (feet y about 78) and at 85% (about 89) of the climb by pressing back, plus one sideways press at 50%.
-- Per try it logs the peak horizontal and downward speed, the landing feet, and the flat distance walked in 2 s toward -z (away from
-- the ladder). Results: shared.T22Letgo = { lines, ends, done, error }.
-- Foot and top: World.Route.RoutePoint_BeardLadder_Foot (0, 61.9, -27.2) and _Top (0, 93.7, -10.5), Edit read 2026-11-11.
local CHECK_ONLY = false

-- selene: allow(global_usage)
local letgoStore = shared :: any

local FOOT, TOP = Vector3.new(0, 61.9, -27.2), Vector3.new(0, 93.7, -10.5)
local SIDE_OFFSET, BACK_OFFSET, CLIMB_LIMIT, FALL_LIMIT = 1.5, 1.5, 12, 8
local SIDE_HOLD, WALK_SECONDS = 0.4, 2

type Release = { name: string, fraction: number, sideways: boolean }
type LetgoEnd = {
	label: string,
	released: number,
	peakH: number,
	peakDown: number,
	ex: number,
	ey: number,
	ez: number,
	walked: number,
}

local RELEASES: { Release } = {
	{ name = "50", fraction = 0.5, sideways = false },
	{ name = "85", fraction = 0.85, sideways = false },
	{ name = "side50", fraction = 0.5, sideways = true },
}

-- Presses into the rungs until the feet reach `targetY`. Returns whether the ladder was climbed to there, and Climbing seen.
-- Steers back onto the ladder's centre line (x 0) while pressing +z (ruling 11: a fixed diagonal ran past the ladder).
local function climbTo(targetY: number, humanoid: Humanoid, root: BasePart): (boolean, boolean)
	local climbed = false
	drive(function()
		if humanoid:GetState() == ST.Climbing then
			climbed = true
		end
		if feetOf(root).Y >= targetY then
			return nil, nil
		end
		return Vector3.new(-root.Position.X * 0.8, 0, 1).Unit, false
	end, CLIMB_LIMIT)
	return feetOf(root).Y >= targetY, climbed
end

-- Lets go the spec's way (press back, -z, away from the ladder; or a sideways press; ruling 11) and watches the fall: peak horizontal and downward speed until landed.
local function fall(release: Release, sideDir: Vector3, humanoid: Humanoid, root: BasePart): (number, number, boolean)
	local watch = landingWatch(humanoid, root)
	local peakH, peakDown, landed = 0, 0, false
	drive(function(elapsed: number)
		local v = root.AssemblyLinearVelocity
		peakH = math.max(peakH, Vector3.new(v.X, 0, v.Z).Magnitude)
		peakDown = math.max(peakDown, -v.Y)
		if elapsed >= 0.5 and watch(elapsed) then
			landed = true
			return nil, nil
		end
		local away = if release.sideways then sideDir else -Vector3.zAxis
		return if elapsed < SIDE_HOLD then away else ZERO, false
	end, FALL_LIMIT)
	return peakH, peakDown, landed
end

-- Walks a fixed -z (away from the ladder, so the rungs can't be grabbed again; code_lead ruling 10) and returns the flat distance.
local function walkForward(root: BasePart): number
	local before = feetOf(root)
	press(-Vector3.zAxis, WALK_SECONDS)
	local after = feetOf(root)
	return Vector3.new(after.X - before.X, 0, after.Z - before.Z).Magnitude
end

local function tryOnce(label: string, side: number, release: Release): (string, LetgoEnd?)
	local humanoid, root = bot()
	local start = Vector3.new(side * SIDE_OFFSET, FOOT.Y, FOOT.Z - BACK_OFFSET)
	placeBot(start)
	settle(humanoid)
	local targetY = FOOT.Y + release.fraction * (TOP.Y - FOOT.Y)
	local reached, climbed = climbTo(targetY, humanoid, root)
	local at = feetOf(root)
	if not reached then
		return string.format("%s NO_CLIMB reached y %.1f of %.1f climbed %s", label, at.Y, targetY, tostring(climbed)),
			nil
	end
	local peakH, peakDown, landed = fall(release, Vector3.new(side, 0, 0), humanoid, root)
	local feet = feetOf(root)
	local walked = walkForward(root)
	local line = string.format(
		"%s let go y %.1f at x %.1f: %s end %.1f, %.1f, %.1f peakH %.1f peakDown %.1f walked %.1f",
		label,
		at.Y,
		at.X,
		if landed then "landed" else "NOLAND",
		feet.X,
		feet.Y,
		feet.Z,
		peakH,
		peakDown,
		walked
	)
	local record: LetgoEnd = {
		label = label,
		released = at.Y,
		peakH = peakH,
		peakDown = peakDown,
		ex = feet.X,
		ey = feet.Y,
		ez = feet.Z,
		walked = walked,
	}
	return line, record
end

local function runLetgo(): ()
	local lines: { string } = {}
	local ends: { LetgoEnd } = {}
	local state = { lines = lines, ends = ends, done = false, error = "" }
	letgoStore.T22Letgo = state
	local ok, failure = pcall(function()
		for _, side in { -1, 1 } do
			for _, release in RELEASES do
				local label = `{if side < 0 then "L" else "R"}{release.name}`
				local line, record = tryOnce(label, side, release)
				table.insert(lines, line)
				print("T22 letgo " .. line)
				if record ~= nil then
					table.insert(ends, record)
				end
			end
		end
	end)
	state.error = if ok then "" else tostring(failure)
	state.done = true
end

-- client-a's runLeg is for client-b's loop; named here so the joined lint sees it used (this job does not call it).
local _ = runLeg

if not CHECK_ONLY then
	task.spawn(runLetgo)
end
