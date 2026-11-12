-- Plan 3 Task 19, Step 3 (work/p3t19/t19-card.md): CLIENT job in Play, pasted JOINED after client-a (it uses client-a's
-- press, drive, placeBot, settle, feetOf, bot and ZERO; no --!strict here, the joined paste takes client-a's).
-- Condition 5 of Rule 36 (the lap planks): the camera does not snap in on the plank. The real character is placed at the boot end
-- of LapPlank_Left's deck, waits until it stands on the ground, then walks flat toward LapLanding with `press`. Every 0.1 s the
-- distance from the camera to the head and the character's feet are sampled.
-- Results: shared.T19Plank = { lines, minDist, startDist, ends, done, error }.
local PLANK_CHECK_ONLY = false

-- selene: allow(global_usage)
local plankStore = shared :: any

local GROUND_WAIT, SAMPLE_EVERY, STEP_SECONDS, MAX_STEPS, ARRIVE_FLAT = 3, 0.1, 0.5, 20, 1.5

-- Edit read 2026-11-12 (Workspace.World.WalkSurfaces.LapPlank_Left.Deck: centre (-13.2, 31.1, -55.0), size 9.0 x 0.6 x 16.9,
-- up (-0.21, 0.98, -0.01); top-centre of its two ends (-21.50, 29.60, -55.56) boot end and (-5.05, 33.20, -54.50) landing end).
-- The boot end sits 2.3 studs above the boot top (a ray 2 studs beyond it hit the boot at y 27.26).
local BOOT_END_FEET = Vector3.new(-20.8, 29.8, -55.5) -- 0.7 stud along the deck from the boot end; y = deck top there + 0.2
-- Edit read 2026-11-12: LapLanding.Deck centre (0, 32.9, -50.6), size 11.2 x 0.6 x 5.8, top y 33.2.
local LANDING_FLAT = Vector3.new(0, 0, -50.6)

type PlankEnd = { x: number, y: number, z: number, flatToLanding: number, steps: number }
type PlankState = {
	lines: { string },
	minDist: number,
	startDist: number,
	ends: { PlankEnd },
	done: boolean,
	error: string,
}

local function plankFlat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function plankRun()
	local state: PlankState = { lines = {}, minDist = math.huge, startDist = 0, ends = {}, done = false, error = "" }
	plankStore.T19Plank = state
	local ok, failure = pcall(function()
		local humanoid, root = bot()
		local camera = Workspace.CurrentCamera
		local head = (root.Parent :: Model):FindFirstChild("Head") :: BasePart
		if camera == nil or head == nil then
			error("T19: no camera or head", 0)
		end
		local running = true
		local began = os.clock()
		local function sample(label: string)
			local dist = (camera.CFrame.Position - head.Position).Magnitude
			local feet = feetOf(root)
			state.minDist = math.min(state.minDist, dist)
			table.insert(
				state.lines,
				string.format(
					"T19 s %s t%.1f dist %.2f feet %.1f,%.1f,%.1f",
					label,
					os.clock() - began,
					dist,
					feet.X,
					feet.Y,
					feet.Z
				)
			)
		end
		task.spawn(function()
			while running do
				sample("walk")
				task.wait(SAMPLE_EVERY)
			end
		end)
		placeBot(BOOT_END_FEET)
		settle(humanoid)
		local waited = 0
		while humanoid.FloorMaterial == Enum.Material.Air and waited < GROUND_WAIT do
			waited += task.wait()
		end
		task.wait(0.5) -- the camera settles behind the placed body before the start distance is read
		state.startDist = (camera.CFrame.Position - head.Position).Magnitude
		table.insert(
			state.lines,
			string.format(
				"T19 start dist %.2f floor %s feet %s",
				state.startDist,
				tostring(humanoid.FloorMaterial),
				tostring(feetOf(root))
			)
		)
		local steps = 0
		while steps < MAX_STEPS and plankFlat(feetOf(root), LANDING_FLAT) > ARRIVE_FLAT do
			local feet = feetOf(root)
			local dir = Vector3.new(LANDING_FLAT.X - feet.X, 0, LANDING_FLAT.Z - feet.Z).Unit
			press(dir, STEP_SECONDS)
			steps += 1
		end
		task.wait(0.5)
		running = false
		local feet = feetOf(root)
		table.insert(
			state.ends,
			{ x = feet.X, y = feet.Y, z = feet.Z, flatToLanding = plankFlat(feet, LANDING_FLAT), steps = steps }
		)
		table.insert(
			state.lines,
			string.format(
				"T19 end feet %.1f,%.1f,%.1f flat to landing %.1f steps %d minDist %.2f startDist %.2f",
				feet.X,
				feet.Y,
				feet.Z,
				plankFlat(feet, LANDING_FLAT),
				steps,
				state.minDist,
				state.startDist
			)
		)
		print(state.lines[#state.lines])
	end)
	state.error = if ok then "" else tostring(failure)
	state.done = true
end

if not PLANK_CHECK_ONLY then
	task.spawn(plankRun)
end
