--!strict
-- Plan 4 Task 13c: nest-pose. Paste once on the CLIENT in Play, after session-hold and nest-meter (server).
-- Listens to the local attribute P4t13Pose; sets P4t13PoseDone to the pose text plus facts, or `FIRED <pose>: <reason>`.
--   gate:<g>     stand 3 studs over Plot_<g>.SpawnSpot facing the giant.   carry:<nest> as `by`, grab, 5 studs back.
--   by:<nest>    start the trip (PlotIndex 4, meter held), stand on the floor cell nearest 4 studs from the prompt,
--                camera on the nest, wait for PromptShown (3 s). `by:Epic` / `by:Legendary` (a rank) use the nest that
--                holds an egg of that rank now (waits up to 70 s). Done text adds the shot camera numbers.
--   home:<nest> was cut (product, 13c-state-ruling.md Item 1).
local CHECK_ONLY = false

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if CHECK_ONLY or not RunService:IsRunning() or not RunService:IsClient() then
	return "no Play: nest-pose runs on the client in Play; changes nothing"
end
if ReplicatedStorage:GetAttribute("P4t13PoseLoaded") == true then
	return "nest-pose already loaded"
end
ReplicatedStorage:SetAttribute("P4t13PoseLoaded", true)

local GARDEN = 4 -- the trip's garden, as nest-walk's `start`
local TRIP = 90 -- the trip number the meter script is given
local NEST_SIDE = 4 -- studs from the nest for `by` and `carry`
local BACK = 5 -- studs back after the grab
local LOOK_AT = Vector3.new(0, 3, -40)

local player = Players.LocalPlayer
local world = Workspace:FindFirstChild("World") :: any
local busy = false
local running: string? = nil

local shown: { [ProximityPrompt]: boolean } = {}
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	shown[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	shown[prompt] = nil
end)

-- Copied from scripts/studio/session-hold.luau (the held check).
local function held(): (boolean, string)
	local beat = ReplicatedStorage:GetAttribute("TrialHoldBeat")
	local phase = ReplicatedStorage:GetAttribute("TrialHoldPhase")
	if type(beat) ~= "number" or Workspace:GetServerTimeNow() - beat > 2 then
		return false, "no or old beat"
	end
	return phase == "Asleep", "phase " .. tostring(phase)
end

local function waitUntil(done: () -> boolean, seconds: number): boolean
	local started = os.clock()
	while not done() and os.clock() - started < seconds do
		task.wait(0.1)
	end
	return done()
end

local function body(): (Humanoid, BasePart)
	local c = player.Character or player.CharacterAdded:Wait()
	return c:WaitForChild("Humanoid") :: Humanoid, c:WaitForChild("HumanoidRootPart") :: BasePart
end

local function f1(v: number): string
	return string.format("%.1f", v)
end

local function v3(v: Vector3): string
	return `{f1(v.X)},{f1(v.Y)},{f1(v.Z)}`
end

local function fire(pose: string, reason: string)
	ReplicatedStorage:SetAttribute("P4t13PoseDone", `FIRED {pose}: {reason}`)
end

-- Puts the root at `at` (root position), turns to `look`, waits for the floor. Returns true when standing.
local function standAt(at: Vector3, look: Vector3): boolean
	local hum, root = body()
	root.AssemblyLinearVelocity = Vector3.zero
	root:PivotTo(CFrame.lookAt(at, Vector3.new(look.X, at.Y, look.Z)))
	return waitUntil(function(): boolean
		return hum.FloorMaterial ~= Enum.Material.Air
	end, 5)
end

local function pivotOf(inst: Instance): Vector3
	return (inst :: PVInstance):GetPivot().Position
end

-- Starts the trip, stands by the nest. Returns nest, prompt, the way out, the shown time (or a reason). The stand spot is the floor cell nearest 4 studs from the prompt: the cuffs have no floor outward, the arm is 7 studs up.
local function goBy(nestName: string): (Instance?, ProximityPrompt?, Vector3, number?, string)
	local out = Vector3.new(1, 0, 0)
	local nest = world.EggSpots:FindFirstChild(nestName)
	local remote = ReplicatedStorage:FindFirstChild("P4t13Trip") :: RemoteEvent?
	if nest == nil or remote == nil then
		return nil, nil, out, nil, "no nest or P4t13Trip"
	end
	local prompt = nest:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt == nil then
		return nil, nil, out, nil, "no prompt on the nest"
	end
	remote:FireServer("start", TRIP, nestName, GARDEN)
	task.wait(0.5)
	local hum, root = body()
	local at = pivotOf(nest)
	local lift = hum.HipHeight + root.Size.Y / 2
	local reach = (prompt.Parent :: Attachment).WorldPosition
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, nest }
	-- Floor cells within 6 studs whose standing root is nearest NEST_SIDE studs from the prompt (rays, 2026-11-11).
	local floor: Vector3? = nil
	local bestMiss = math.huge
	for dx = -6, 6 do
		for dz = -6, 6 do
			local hit = Workspace:Raycast(at + Vector3.new(dx, 15, dz), Vector3.new(0, -30, 0), params)
			local miss = if hit ~= nil and hit.Normal.Y > 0.7
				then math.abs((hit.Position + Vector3.new(0, lift, 0) - reach).Magnitude - NEST_SIDE)
				else math.huge
			if hit ~= nil and miss < bestMiss and Vector3.new(dx, 0, dz).Magnitude >= 2 then
				bestMiss, floor, out = miss, hit.Position, Vector3.new(dx, 0, dz).Unit
			end
		end
	end
	if floor == nil then
		return nest, prompt, out, nil, "no floor on any side of the nest"
	end
	local ok = standAt(floor + Vector3.new(0, lift + 0.5, 0), at)
	if not ok then
		return nest, prompt, out, nil, "no floor by the nest"
	end
	if prompt.Enabled == false then
		return nest, prompt, out, nil, "prompt off (no egg on the nest)"
	end
	-- A prompt whose nest is off screen never shows: aim the camera at the nest from behind the player.
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(root.Position + out * 8 + Vector3.new(0, 3, 0), at)
	local started = os.clock()
	local isShown = waitUntil(function(): boolean
		return shown[prompt] == true
	end, 3)
	local took = if isShown then os.clock() - started else nil
	local d = (root.Position - at).Magnitude
	return nest,
		prompt,
		out,
		took,
		if took == nil then `no PromptShown in 3 s, root {f1(d)} studs from the nest` else ""
end

local function grab(nest: Instance, prompt: ProximityPrompt): boolean
	local rank = nest:GetAttribute("Rarity")
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.3)
	prompt:InputHoldEnd()
	return waitUntil(function(): boolean
		return player:GetAttribute("Carrying") == rank
	end, 2)
end

local function poseGate(pose: string, g: number)
	local plot = world.Plots:FindFirstChild("Plot_" .. g)
	local spawn = if plot ~= nil then plot:FindFirstChild("SpawnSpot") else nil
	if spawn == nil or not spawn:IsA("BasePart") then
		return fire(pose, `no Plot_{g}.SpawnSpot`)
	end
	local hum, root = body()
	local at = (spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0))
		+ Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 3, 0)
	if not standAt(at, LOOK_AT) then
		return fire(pose, "no floor at the gate")
	end
	ReplicatedStorage:SetAttribute("P4t13PoseDone", pose)
end

local function poseBy(pose: string, nestName: string)
	local nest, prompt, out, took, why = goBy(nestName)
	if nest == nil or prompt == nil or took == nil then
		return fire(pose, why)
	end
	local _, root = body()
	local at = pivotOf(nest)
	local cam = root.Position + out * 8 + Vector3.new(0, 3, 0) -- goBy's Scriptable camera spot
	ReplicatedStorage:SetAttribute(
		"P4t13PoseDone",
		`{pose} shown {f1(took)} s cam {v3(cam)} egg {v3(at)} word {v3(at + Vector3.new(0, 4, 0))}`
	)
end

local function poseCarry(pose: string, nestName: string)
	local nest, prompt, out, took, why = goBy(nestName)
	if nest == nil or prompt == nil or took == nil then
		return fire(pose, why)
	end
	local rank = nest:GetAttribute("Rarity")
	if not grab(nest, prompt) then
		return fire(pose, `grab failed, Carrying {tostring(player:GetAttribute("Carrying"))} want {tostring(rank)}`)
	end
	local hum, root = body()
	hum:MoveTo(root.Position + out * BACK)
	hum.MoveToFinished:Wait()
	local now = player:GetAttribute("Carrying")
	if now ~= rank then
		return fire(pose, `Carrying {tostring(now)} after the step back, want {tostring(rank)}`)
	end
	local cam = root.Position - out * 7 + Vector3.new(0, 3, 0) -- the egg is on the back: look from the nest side
	ReplicatedStorage:SetAttribute(
		"P4t13PoseDone",
		`{pose} carrying {tostring(now)} cam {v3(cam)} look {v3(root.Position + Vector3.new(0, 1, 0))}`
	)
end

-- The nest (by name) whose egg of `rank` waits now; waits up to 70 s, nil when none (refill is 60 s after the take).
local function waitingNest(rank: string): string?
	local found: string? = nil
	waitUntil(function(): boolean
		for _, n in world.EggSpots:GetChildren() do
			if n:GetAttribute("Rarity") == rank and n:GetAttribute("Waiting") == true then
				found = n.Name
				return true
			end
		end
		return false
	end, 70)
	return found
end

local function run(pose: string)
	local kind, arg = string.match(pose, "^(%a+):(.+)$")
	if kind == nil or arg == nil then
		return fire(pose, "bad pose text")
	end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom -- `by` and `carry` leave it Scriptable
	local ok, why = held()
	if not ok then
		return fire(pose, `giant not held ({why})`)
	end
	if (kind == "by" or kind == "carry") and (arg == "Epic" or arg == "Legendary") then
		local nest = waitingNest(arg)
		if nest == nil then
			return fire(pose, `no {arg} egg waiting in 70 s`)
		end
		arg = nest
		pose = `{kind}:{arg}` -- every later text shows the nest used
	end
	if kind == "gate" then
		local g = tonumber(arg)
		if g == nil or g % 1 ~= 0 or g < 1 or g > 8 then
			return fire(pose, "bad garden")
		end
		poseGate(pose, g)
	elseif kind == "by" then
		poseBy(pose, arg)
	elseif kind == "carry" then
		poseCarry(pose, arg)
	else
		fire(pose, "unknown pose kind")
	end
end

ReplicatedStorage:GetAttributeChangedSignal("P4t13Pose"):Connect(function()
	local pose = ReplicatedStorage:GetAttribute("P4t13Pose")
	if type(pose) ~= "string" then
		return
	end
	-- Signals run deferred: the snippet's nil-then-pose sets queue 2 calls that both read the new pose. Skip the copy.
	if busy and pose == running then
		return
	end
	if busy then
		return fire(pose, "another pose is still running")
	end
	busy = true
	running = pose
	local ok, err = pcall(function(): string?
		run(pose)
		return nil
	end)
	busy = false
	if not ok then
		fire(pose, `error {tostring(err)}`)
	end
end)

return "nest-pose loaded: poses gate:<g>, by:<nest or rank>, carry:<nest or rank>"
