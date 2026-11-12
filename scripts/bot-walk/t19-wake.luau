--!strict
-- Plan 3 Task 19, Step 3 (work/p3t19/t19-card.md): SERVER job in Play. Condition 4 of Rule 36 (the lap planks): he wakes while
-- the player stands on LapPlank_Left, and the player is carried off the plank to a landing spot. It puts the character on the
-- deck 2 studs from RailGuard_Left, waits until it stands still, wakes him the way p15b2-server does (NoHold true and Meter 100,
-- never Phase or Carrying), then for 10 s logs every 0.1 s the root position, the Humanoid state and the speed.
-- Reads Carrying and BonkStars at the start and the end only; it never writes them.
-- Ladder mode (Step 1 of part 2, work/p3t19/t19b-card.md): set shared.T19WakeCfg = { side = "Right", start = <feet Vector3> } before
-- the paste. The CLIENT job (t19-ladder, mode "half") puts the player on a rung; this job then does not place anything: it waits
-- up to 8 s for the Humanoid state Climbing, waits 1 s, wakes him, and reads the landing spot among those on the side's x sign
-- (Right = x above 0, Left = x below 0). Without a cfg it runs the plank wake as before.
-- Result: shared.T19Wake = { lines, samples, spots, nearest, nearestFlat, restSeconds, endRoot, done, error }; signal lines "T19 wake ...".
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ROOT_OFFSET = 3.225 -- Config.luau line 170 (root = feet + 3.225)
local GUARD_GAP = 2 -- studs from RailGuard_Left's face to the root (card: "2 studs from RailGuard_Left")
local STAND_WAIT, WAKE_WAIT, LOG_SECONDS, LOG_EVERY = 5, 10, 10, 0.1
local REST_Y, REST_SPEED = 25, 1 -- condition 4: never rests above y 25 for 1.5 s while the speed is under 1

local requireModule: (Instance) -> any = require :: any
local Net = requireModule(RS.Shared.Net)
-- selene: allow(global_usage)
local store: { [string]: any } = shared :: any
local cfg: { side: string?, start: Vector3? } = store.T19WakeCfg or {}
local ladderMode = cfg.start ~= nil
local sideSign = if cfg.side == "Right" then 1 elseif cfg.side == "Left" then -1 else 0
local player = Players:GetPlayers()[1]
local state = RS:FindFirstChild(Net.GiantStateName, true)
local world = Workspace:FindFirstChild("World")
local surfaces = world and world:FindFirstChild("WalkSurfaces")
local plank = surfaces and surfaces:FindFirstChild("LapPlank_Left")
local deck = plank and plank:FindFirstChild("Deck") :: BasePart?
local guard = surfaces and surfaces:FindFirstChild("RailGuard_Left") :: BasePart?
local spotsFolder = world and world:FindFirstChild("LandingSpots")
print(
	`T19 wake found player {player ~= nil} state {state ~= nil} deck {deck ~= nil} guard {guard ~= nil} spots {spotsFolder ~= nil}`
)
if not (player and state and spotsFolder and (ladderMode or (deck and guard))) then
	return "MISSING"
end

type Sample = { t: number, x: number, y: number, z: number, state: string, speed: number }
type WakeState = {
	lines: { string },
	samples: { Sample },
	spots: { string },
	nearest: string,
	nearestFlat: number,
	restSeconds: number,
	endRoot: Vector3,
	done: boolean,
	error: string,
}
local D: WakeState = {
	lines = {},
	samples = {},
	spots = {},
	nearest = "",
	nearestFlat = math.huge,
	restSeconds = 0,
	endRoot = Vector3.zero,
	done = false,
	error = "",
}
store.T19Wake = D

local function log(text: string)
	table.insert(D.lines, text)
	print("T19 wake " .. text)
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function run(): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and root and humanoid) then
		error("T19 wake: no character", 0)
	end
	local spotParts: { BasePart } = {}
	for _, child in spotsFolder:GetChildren() do
		if child:IsA("BasePart") and (sideSign == 0 or math.sign(child.Position.X) == sideSign) then
			table.insert(spotParts, child)
			table.insert(
				D.spots,
				`{child.Name} {string.format("%.1f,%.1f,%.1f", child.Position.X, child.Position.Y, child.Position.Z)}`
			)
		end
	end
	log(`side {tostring(cfg.side)} start {tostring(cfg.start)} ladderMode {tostring(ladderMode)}`)
	log(`landing spots {#spotParts}: {table.concat(D.spots, "; ")}`)

	local waited = 0
	if ladderMode then
		while humanoid:GetState() ~= Enum.HumanoidStateType.Climbing and waited < 8 do
			waited += task.wait(0.1)
		end
		if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
			error("T19 wake: the player never reached the Climbing state on the ladder", 0)
		end
		task.wait(1)
		log(
			`ladder root {string.format("%.1f,%.1f,%.1f", root.Position.X, root.Position.Y, root.Position.Z)} state`
				.. ` {tostring(humanoid:GetState())}, Carrying {tostring(player:GetAttribute("Carrying"))}`
				.. ` BonkStars {tostring(player:GetAttribute("BonkStars"))} (read only)`
		)
	elseif not deck or not guard then
		error("T19 wake: no deck or guard", 0)
	else
		-- The stand spot: the deck's middle, 2 studs in front of the guard's face (the guard stands on the +z side of the deck).
		local standZ = guard.Position.Z - guard.Size.Z / 2 - GUARD_GAP
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { character }
		local hit =
			Workspace:Raycast(Vector3.new(deck.Position.X, deck.Position.Y + 6, standZ), Vector3.new(0, -12, 0), rp)
		if not hit or hit.Instance ~= deck then
			error(
				`T19 wake: the ray at the stand spot hit {if hit then hit.Instance:GetFullName() else "nothing"}, not the deck`,
				0
			)
		end
		character:PivotTo(CFrame.new(hit.Position + Vector3.new(0, ROOT_OFFSET, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
		local stillSince: number? = nil
		waited = 0
		while waited < STAND_WAIT do
			local still = humanoid.FloorMaterial ~= Enum.Material.Air
				and root.AssemblyLinearVelocity.Magnitude < REST_SPEED
			stillSince = if still then (stillSince or os.clock()) else nil
			if stillSince ~= nil and os.clock() - stillSince >= 1 then
				break
			end
			waited += task.wait(0.1)
		end
		if stillSince == nil then
			error("T19 wake: the body never stood still on the deck", 0)
		end
		local guardFlat = math.abs(root.Position.Z - (guard.Position.Z - guard.Size.Z / 2))
		log(
			`stand root {string.format("%.1f,%.1f,%.1f", root.Position.X, root.Position.Y, root.Position.Z)} {guardFlat}`
				.. ` studs from guard face, floor {tostring(humanoid.FloorMaterial)}, Carrying {tostring(
					player:GetAttribute("Carrying")
				)}`
				.. ` BonkStars {tostring(player:GetAttribute("BonkStars"))} (read only)`
		)
	end

	local awakeAt: number? = nil
	local connection = state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") == "Awake" and awakeAt == nil then
			awakeAt = os.clock()
			log("Awake")
		end
	end)
	player:SetAttribute("NoHold", true)
	state:SetAttribute("Meter", 100)
	log("start: NoHold true, Meter 100")
	waited = 0
	while awakeAt == nil and waited < WAKE_WAIT do
		waited += task.wait(0.1)
	end
	connection:Disconnect()
	if awakeAt == nil then
		player:SetAttribute("NoHold", false)
		error("T19 wake: he never woke within 10 s", 0)
	end

	local began = awakeAt
	local restSince: number? = nil
	local longestRest = 0
	while os.clock() - began < LOG_SECONDS do
		local at = os.clock() - began
		local pos = root.Position
		local speed = root.AssemblyLinearVelocity.Magnitude
		local stateName = tostring(humanoid:GetState())
		table.insert(D.samples, { t = at, x = pos.X, y = pos.Y, z = pos.Z, state = stateName, speed = speed })
		table.insert(
			D.lines,
			string.format("t%.1f %.1f,%.1f,%.1f %s speed %.1f", at, pos.X, pos.Y, pos.Z, stateName, speed)
		)
		if pos.Y - ROOT_OFFSET > REST_Y and speed < REST_SPEED then
			local since = restSince or at
			restSince = since
			longestRest = math.max(longestRest, at - since)
		else
			restSince = nil
		end
		task.wait(LOG_EVERY)
	end
	D.restSeconds = longestRest
	D.endRoot = root.Position
	for _, spot in spotParts do
		local dist = flat(root.Position, spot.Position)
		if dist < D.nearestFlat then
			D.nearest, D.nearestFlat = spot.Name, dist
		end
	end
	player:SetAttribute("NoHold", false)
	log(
		`end root {string.format("%.1f,%.1f,%.1f", D.endRoot.X, D.endRoot.Y, D.endRoot.Z)} nearest {D.nearest}`
			.. ` {string.format("%.1f", D.nearestFlat)} flat, longest rest above y {REST_Y} {string.format(
				"%.1f",
				D.restSeconds
			)} s`
			.. ` Carrying {tostring(player:GetAttribute("Carrying"))} BonkStars {tostring(
				player:GetAttribute("BonkStars")
			)} (read only)`
	)
	return "ok"
end

task.spawn(function()
	local ok, failure = pcall(run)
	D.error = if ok then "" else tostring(failure)
	if not ok then
		log("ERROR " .. D.error)
	end
	D.done = true
end)
return "t19 wake started"
