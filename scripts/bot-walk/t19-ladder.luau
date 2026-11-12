-- Plan 3 Task 19 part 2, Step 1 (work/p3t19/t19b-card.md): CLIENT job in Play, pasted JOINED after client-a (it uses client-a's
-- drive, placeBot, settle, feetOf and bot; no --!strict here, the joined paste takes client-a's). Phone on, Check C3 and Rule 43.
-- Every part is found at run time from Workspace.World.WalkSurfaces (Edit read left for Step 2's dry run, see b-step1-note.md).
-- Set shared.T19LadderMode = "climb" (default) or "half" before the paste.
--   "climb": placed at the foot of BootLadder_Right (lowest Rung x and z, feet y from a ray), it presses FORWARD only (towards the
--            wall the ladder leans on; never a jump key) up the ladder, walks to the boot end of LapPlank_Right's deck, then to
--            LapLanding. Every 0.1 s it samples state, position and whether the state is Climbing; it counts every Jumping entry.
--   "half":  placed on the middle Rung (a PivotTo to its x and z, a ray for the standing y), it presses forward to keep its grip
--            until the giant's Phase is Awake and 12 s have passed (the server job t19-wake in ladder mode wakes him).
-- Results: shared.T19Ladder = { lines, climbedAt, bootTopAt, jumps, ends, done, error }.
local LADDER_CHECK_ONLY = false

-- selene: allow(global_usage)
local ladderStore = shared :: any

local LADDER_NAME, PLANK_NAME, LANDING_NAME = "BootLadder_Right", "LapPlank_Right", "LapLanding"
local SAMPLE_EVERY, CLIMB_SECONDS, WALK_SECONDS, HALF_HOLD, ARRIVE_FLAT = 0.1, 14, 14, 12, 1.5
local LADDER_FALLBACK_AWAY = -Vector3.xAxis -- the right boot's ladder leans on the wall towards the giant (x falls) if no rung tilt shows

type LadderEnd = { x: number, y: number, z: number, state: string, flatToLanding: number, floor: string, jumps: number }
type LadderState = {
	lines: { string },
	climbedAt: number?,
	bootTopAt: number?,
	jumps: number,
	ends: { LadderEnd },
	done: boolean,
	error: string,
}

local function ladderFlat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function ladderRun()
	local mode: string = ladderStore.T19LadderMode or "climb"
	local state: LadderState =
		{ lines = {}, climbedAt = nil, bootTopAt = nil, jumps = 0, ends = {}, done = false, error = "" }
	ladderStore.T19Ladder = state
	local function log(text: string)
		table.insert(state.lines, text)
		print("T19 " .. text)
	end
	local ok, failure = pcall(function()
		local world = Workspace:FindFirstChild("World")
		local surfaces = world and world:FindFirstChild("WalkSurfaces")
		local ladder = surfaces and surfaces:FindFirstChild(LADDER_NAME)
		local look = ladder and ladder:FindFirstChild("Look")
		local plank = surfaces and surfaces:FindFirstChild(PLANK_NAME)
		local deck = plank and plank:FindFirstChild("Deck")
		local landing = surfaces and surfaces:FindFirstChild(LANDING_NAME)
		local landingDeck = landing and landing:FindFirstChild("Deck")
		log(
			`found surfaces {tostring(surfaces ~= nil)} ladder {tostring(ladder ~= nil)} look {tostring(look ~= nil)}`
				.. ` plank {tostring(plank ~= nil)} deck {tostring(deck ~= nil)} landing {tostring(landing ~= nil)}`
				.. ` landingDeck {tostring(landingDeck ~= nil)} mode {mode}`
		)
		if not (ladder and look and deck and deck:IsA("BasePart") and landing) then
			error("T19: a ladder, plank or landing part is missing (see the found line)", 0)
		end
		local rungs: { BasePart } = {}
		for _, child in look:GetChildren() do
			if child.Name == "Rung" and child:IsA("BasePart") then
				table.insert(rungs, child)
			end
		end
		table.sort(rungs, function(a, b)
			return a.Position.Y < b.Position.Y
		end)
		if #rungs < 2 then
			error(`T19: only {#rungs} Rung parts under {LADDER_NAME}.Look`, 0)
		end
		local lowest, highest = rungs[1], rungs[#rungs]
		-- "forward": from the lowest rung towards the top rung's x and z; a plumb ladder falls back to "towards the giant".
		local lean = Vector3.new(highest.Position.X - lowest.Position.X, 0, highest.Position.Z - lowest.Position.Z)
		local towardWall = if lean.Magnitude > 0.3 then lean.Unit else LADDER_FALLBACK_AWAY
		log(
			`rungs {#rungs} lowest {tostring(lowest.Position)} top {tostring(highest.Position)} lean {string.format(
				"%.2f",
				lean.Magnitude
			)}` .. ` forward {tostring(towardWall)}`
		)

		local humanoid, root = bot()
		local character = root.Parent :: Model
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { ladder, character }
		local floorParams = RaycastParams.new() -- the floor check keeps the ladder in, to tell ladder from boot
		floorParams.FilterType = Enum.RaycastFilterType.Exclude
		floorParams.FilterDescendantsInstances = { character }

		-- the boot top: a ray down 2 studs beyond the plank's boot end (as the Left read did); the boot end is the end with the larger |x|
		local longSize = math.max(deck.Size.X, deck.Size.Z)
		local axis = if deck.Size.X >= deck.Size.Z then deck.CFrame.RightVector else deck.CFrame.LookVector
		local flatAxis = Vector3.new(axis.X, 0, axis.Z).Unit
		local endA = deck.Position + flatAxis * (longSize / 2)
		local endB = deck.Position - flatAxis * (longSize / 2)
		local bootEnd = if math.abs(endA.X) > math.abs(endB.X) then endA else endB
		local outward = Vector3.new(bootEnd.X - deck.Position.X, 0, bootEnd.Z - deck.Position.Z).Unit
		local topHit = Workspace:Raycast(bootEnd + outward * 2 + Vector3.yAxis * 6, Vector3.yAxis * -20, rp)
		local bootTopY = if topHit then topHit.Position.Y else bootEnd.Y - 2.3
		local onPlank = bootEnd - outward * 0.7 -- 0.7 stud along the deck from its boot end, as t19-plank does
		local landingFlat = (
			if landingDeck and landingDeck:IsA("BasePart")
				then landingDeck.Position
				else (landing :: Model):GetPivot().Position
		)
		log(
			`boot end {tostring(bootEnd)} bootTopY {string.format("%.2f", bootTopY)} (ray {tostring(topHit ~= nil)})`
				.. ` landing {tostring(landingFlat)}`
		)

		local began = os.clock()
		local climbedSeen = false
		local prevState = humanoid:GetState()
		local jumpConn = humanoid.StateChanged:Connect(function(_old, new)
			prevState = new
			if new == Enum.HumanoidStateType.Jumping then
				state.jumps += 1
				log(`JUMPING entered at t{string.format("%.2f", os.clock() - began)}`)
			end
		end)
		local running = true
		task.spawn(function()
			while running do
				local feet = feetOf(root)
				local name = humanoid:GetState().Name
				if name == "Climbing" and not climbedSeen then
					climbedSeen = true
					state.climbedAt = os.clock() - began
				end
				-- boot top: real top reached (feet within 0.5 of the ray's top), off the ladder state, and the floor under the
				-- feet is not part of the ladder (a leaning ladder's face counts as standable; it fired at feet y 28.0 of 30.3)
				local floorHit = Workspace:Raycast(feet + Vector3.yAxis * 0.5, Vector3.yAxis * -3, floorParams)
				local onLadder = floorHit ~= nil and floorHit.Instance:IsDescendantOf(ladder)
				if
					state.bootTopAt == nil
					and climbedSeen
					and feet.Y >= bootTopY - 0.5
					and name ~= "Climbing"
					and humanoid.FloorMaterial ~= Enum.Material.Air
					and not onLadder
				then
					local topAt = os.clock() - began
					state.bootTopAt = topAt
					log(`bootTop at t{string.format("%.2f", topAt)} feet {tostring(feet)}`)
				end
				table.insert(
					state.lines,
					string.format(
						"T19 s t%.1f %s feet %.1f,%.1f,%.1f floor %s climbing %s",
						os.clock() - began,
						name,
						feet.X,
						feet.Y,
						feet.Z,
						humanoid.FloorMaterial.Name,
						tostring(name == "Climbing")
					)
				)
				task.wait(SAMPLE_EVERY)
			end
		end)

		local footFeet: Vector3
		if mode == "half" then
			local mid = rungs[math.ceil(#rungs / 2)]
			local hit = Workspace:Raycast(mid.Position + Vector3.yAxis * 0.5, Vector3.yAxis * -10, rp)
			-- halfway up the ground is far below: stand the feet 2 studs under the rung, as a climber hangs
			local y = if hit and mid.Position.Y - hit.Position.Y < 4 then hit.Position.Y else mid.Position.Y - 2
			footFeet = Vector3.new(mid.Position.X, y, mid.Position.Z)
			log(`half: rung {tostring(mid.Position)} ground ray {tostring(hit ~= nil)} feet {tostring(footFeet)}`)
		else
			local hit = Workspace:Raycast(lowest.Position + Vector3.yAxis * 0.5, Vector3.yAxis * -10, rp)
			if hit == nil then
				error("T19: no ground below the lowest Rung", 0)
			end
			footFeet = Vector3.new(lowest.Position.X, hit.Position.Y, lowest.Position.Z)
			log(`foot feet {tostring(footFeet)}`)
		end
		placeBot(footFeet)
		settle(humanoid)

		if mode == "half" then
			-- hold the grip: press forward (no jump) until he is Awake and HALF_HOLD seconds are over
			local giant: Instance? = nil
			for _, child in game:GetService("ReplicatedStorage"):GetDescendants() do
				if child.Name == "GiantState" then
					giant = child
					break
				end
			end
			local awakeAt: number? = nil
			drive(function()
				if giant ~= nil and giant:GetAttribute("Phase") == "Awake" and awakeAt == nil then
					awakeAt = os.clock()
					log("Awake seen on the client")
				end
				if awakeAt ~= nil and os.clock() - awakeAt >= HALF_HOLD then
					return nil, nil
				end
				return towardWall, false
			end, CLIMB_SECONDS + HALF_HOLD + 10)
		else
			-- 1: up the ladder, forward only, until the boot top is reached
			drive(function()
				if state.bootTopAt ~= nil then
					return nil, nil
				end
				return towardWall, false
			end, CLIMB_SECONDS)
			-- 2: across the boot top to the plank's boot end, then across the deck to the landing (still no jump)
			local flatTarget = onPlank
			drive(function()
				local feet = feetOf(root)
				if ladderFlat(feet, flatTarget) < 1 and flatTarget == onPlank then
					flatTarget = landingFlat
				end
				if ladderFlat(feet, landingFlat) <= ARRIVE_FLAT then
					return nil, nil
				end
				local dir = Vector3.new(flatTarget.X - feet.X, 0, flatTarget.Z - feet.Z)
				return if dir.Magnitude > 0.05 then dir.Unit else nil, false
			end, WALK_SECONDS)
		end
		task.wait(0.5)
		running = false
		jumpConn:Disconnect()
		local feet = feetOf(root)
		local floor = humanoid.FloorMaterial.Name
		table.insert(state.ends, {
			x = feet.X,
			y = feet.Y,
			z = feet.Z,
			state = humanoid:GetState().Name,
			flatToLanding = ladderFlat(feet, landingFlat),
			floor = floor,
			jumps = state.jumps,
		})
		log(
			string.format(
				"end feet %.1f,%.1f,%.1f state %s floor %s flat to landing %.1f climbedAt %s bootTopAt %s jumps %d (prev state %s)",
				feet.X,
				feet.Y,
				feet.Z,
				humanoid:GetState().Name,
				floor,
				ladderFlat(feet, landingFlat),
				tostring(state.climbedAt),
				tostring(state.bootTopAt),
				state.jumps,
				prevState.Name
			)
		)
	end)
	state.error = if ok then "" else tostring(failure)
	if not ok then
		log("ERROR " .. state.error)
	end
	state.done = true
end

if not LADDER_CHECK_ONLY then
	task.spawn(ladderRun)
end
