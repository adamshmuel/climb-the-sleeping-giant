--!strict
-- Plan 4 Task 13a: nest-walk. Paste on the CLIENT in Play after session-hold, nest-meter (server) and nest-legs.
-- Group: ReplicatedStorage attribute P4t13Group (smoke, A, B, C). Rows: LocalPlayer.P4t13Results R<trip>. Edit: changes nothing.
-- Per trip: start point, fire ("start", i, nest, garden), up points, grab, down points, SpawnSpot, bank, ("end", i).
local CHECK_ONLY = false

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- Play check first: no World or StuckScan module is read anywhere in this file.
if CHECK_ONLY or not RunService:IsRunning() or not RunService:IsClient() then
	return "no Play: nest-walk runs on the client in Play; changes nothing"
end

type Point = { x: number, y: number, z: number, c: boolean? }
type Trip = { n: string, w: string, g: number, s: number, k: string, st: Point, up: { Point }, dn: { Point } }

local ARRIVE = 2 -- studs flat; a climb point also needs 1.5 studs in height
local RANGE = { smoke = { 17, 17 }, A = { 1, 24 }, B = { 25, 32 }, C = { 33, 44 } }
local PLANTED = Vector3.new(0, 5, -20)

local player = Players.LocalPlayer
local group = ReplicatedStorage:GetAttribute("P4t13Group")
local bounds = if type(group) == "string" then (RANGE :: any)[group] else nil
local legs = ReplicatedStorage:FindFirstChild("P4t13Legs")
local legsState = ReplicatedStorage:GetAttribute("P4t13LegsState")
if bounds == nil then
	return "set ReplicatedStorage attribute P4t13Group to smoke, A, B or C first"
elseif ReplicatedStorage:GetAttribute("P4t13Running") == true then
	return "already running"
elseif legs == nil or type(legsState) ~= "string" or string.sub(legsState, 1, 4) ~= "done" then
	return `nest-legs is not done (state {tostring(legsState)})`
end
local world = Workspace:FindFirstChild("World") :: any
local remote = ReplicatedStorage:FindFirstChild("P4t13Trip") :: RemoteEvent?
if world == nil or remote == nil then
	return "no World or P4t13Trip (paste nest-meter on the server first)"
end
local spots, plots = world.EggSpots :: Instance, world.Plots :: Instance

local trips: { [number]: Trip } = {}
local order: { number } = {}
local leftRamp: Trip? = nil
for _, v in legs:GetChildren() do
	local no = tonumber(string.match(v.Name, "^T(%d+)$"))
	if no ~= nil and v:IsA("StringValue") then
		local trip = HttpService:JSONDecode(v.Value) :: Trip
		leftRamp = leftRamp or (if trip.w == "Left ramp" then trip else nil)
		if no >= bounds[1] and no <= bounds[2] then
			trips[no] = trip
			table.insert(order, no)
		end
	end
end
table.sort(order)
local count = #order + (if group == "smoke" then 1 else 0)

local results = player:FindFirstChild("P4t13Results") or Instance.new("Folder")
results:ClearAllChildren()
results.Name = "P4t13Results"
results.Parent = player
ReplicatedStorage:SetAttribute("P4t13Count", count)
ReplicatedStorage:SetAttribute("P4t13Running", true)

local function row(name: string, text: string): string
	local value = Instance.new("StringValue")
	value.Name = name
	value.Value = text
	value.Parent = results
	return text
end

local function held(): (boolean, string)
	local beat = ReplicatedStorage:GetAttribute("TrialHoldBeat")
	local phase = ReplicatedStorage:GetAttribute("TrialHoldPhase")
	if type(beat) ~= "number" then
		return false, "no beat"
	elseif Workspace:GetServerTimeNow() - beat > 2 then
		return false, "old beat"
	elseif phase ~= "Asleep" then
		return false, "phase " .. tostring(phase)
	end
	return true, "held"
end

local shown: { [ProximityPrompt]: boolean } = {}
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	shown[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	shown[prompt] = nil
end)

local function waitUntil(done: () -> boolean, seconds: number): boolean
	local started = os.clock()
	while not done() and os.clock() - started < seconds do
		task.wait(0.1)
	end
	return done()
end

local function body(): (Humanoid, BasePart)
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("Humanoid") :: Humanoid, character:WaitForChild("HumanoidRootPart") :: BasePart
end

local function feetOf(hum: Humanoid, root: BasePart): Vector3
	return root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
end

-- One walk point, 8 s a try. After a timeout: step back 4 studs, turn to the point, one more try.
local function leg(target: Vector3, climb: boolean): (boolean, Vector3)
	local hum, root = body()
	local lift = Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	for attempt = 1, 2 do
		local lastCall = 0.0
		local reached = waitUntil(function(): boolean
			local feet = feetOf(hum, root)
			if os.clock() - lastCall > 1.5 then
				hum:MoveTo(target + lift)
				lastCall = os.clock()
			end
			return ((feet - target) * Vector3.new(1, 0, 1)).Magnitude <= ARRIVE
				and (not climb or math.abs(feet.Y - target.Y) <= 1.5)
		end, 8)
		if reached then
			return true, feetOf(hum, root)
		elseif attempt == 1 then
			local away = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
			hum:MoveTo(root.Position + (if away.Magnitude > 0.1 then away.Unit * 4 else Vector3.new(4, 0, 0)))
			task.wait(1.5)
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
		end
	end
	return false, feetOf(hum, root)
end

local function put(p: Vector3): boolean
	local hum, root = body()
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(p + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 3, 0))
	return waitUntil(function(): boolean
		return hum.FloorMaterial ~= Enum.Material.Air
	end, 5)
end

local function toVec(p: Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function f1(v: number?): string
	return if v ~= nil then string.format("%.1f", v) else "none"
end

local function fmt(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function grab(nest: Instance): boolean
	local prompt = nest:FindFirstChildWhichIsA("ProximityPrompt", true)
	local rank = nest:GetAttribute("Rarity")
	if prompt == nil or not waitUntil(function(): boolean
		return shown[prompt] == true
	end, 3) then
		return false
	end
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.3)
	prompt:InputHoldEnd()
	return waitUntil(function(): boolean
		return player:GetAttribute("Carrying") == rank
	end, 2)
end

local function waitBank(): boolean
	return waitUntil(function(): boolean
		return player:GetAttribute("Carrying") == nil
	end, 3)
end

local function walk(points: { Point }): (number, Vector3?)
	local reached = 0
	for _, p in points do
		local ok, at = leg(toVec(p), p.c == true)
		if not ok then
			return reached, at
		end
		reached += 1
	end
	return reached, nil
end

-- From the SpawnSpot top; the spec banks there, Banking.luau needs the real position inside the garden.
local function bank(plot: Instance, spawn: BasePart): (boolean, boolean, Vector3?)
	local ok, at = leg(spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0), false)
	if not ok then
		return false, false, at
	end
	local banked = waitBank()
	local volume = plot:FindFirstChild("GardenVolume") :: BasePart
	if banked then
		return true, false, nil
	end
	local inside = leg(Vector3.new(volume.Position.X, spawn.Position.Y, volume.Position.Z), false)
	banked = inside and waitBank()
	return banked, banked, nil
end

local function runTrip(no: number, trip: Trip): boolean
	local tag = string.format("R%02d", no)
	local okHeld, why = held()
	if not okHeld then
		row(tag, `VOID: giant not held ({why})`)
		return false
	end
	local jumps, fall, fallFrom = 0, 0.0, nil :: number?
	local hum = body()
	local watch = hum.StateChanged:Connect(function(prev: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		jumps += if new == Enum.HumanoidStateType.Jumping then 1 else 0
		if new == Enum.HumanoidStateType.Freefall then
			fallFrom = os.clock()
		elseif prev == Enum.HumanoidStateType.Freefall and fallFrom ~= nil then
			fall = math.max(fall, os.clock() - fallFrom)
			fallFrom = nil
		end
	end)
	local stopped: Vector3? = nil
	local done, grabbed, banked, viaGarden = 0, false, false, false
	if not put(toVec(trip.st)) then
		stopped = toVec(trip.st)
	else
		remote:FireServer("start", no, trip.n, trip.g)
		task.wait(0.5)
		local n, at = walk(trip.up)
		done, stopped = n, at
		if stopped == nil then
			grabbed = grab(spots:FindFirstChild(trip.n) :: Instance)
			n, at = walk(trip.dn)
			done, stopped = done + n, at
		end
		local plot = plots:FindFirstChild(`Plot_{trip.g}`) :: Instance
		if stopped == nil then
			banked, viaGarden, stopped = bank(plot, plot:FindFirstChild("SpawnSpot") :: BasePart)
			done += if stopped == nil then 1 else 0
		end
	end
	remote:FireServer("end", no)
	watch:Disconnect()
	local peakName = `P4t13Peak_{no}`
	waitUntil(function(): boolean
		return ReplicatedStorage:GetAttribute(peakName) ~= nil
	end, 2)
	local peak = ReplicatedStorage:GetAttribute(peakName) :: number?
	local phase = ReplicatedStorage:GetAttribute(`P4t13Phase_{no}`)
	local gap = if peak ~= nil then f1(math.abs(peak - trip.s)) else "none"
	local text = `T{string.format("%02d", no)} {trip.n} {trip.w} legs {done}/{#trip.up + #trip.dn + 1} jumps {jumps}`
	text ..= ` fall {f1(fall)} grabbed {if grabbed then "yes" else "no"} banked {if banked then "yes" else "no"}`
	text ..= `{if viaGarden then " (garden)" else ""} peak {f1(peak)} score {trip.s} gap {gap}`
	text ..= if phase ~= "Asleep" then ` phase {tostring(phase)}` else ""
	text ..= if stopped ~= nil then ` STOPPED {fmt(stopped)}` else ""
	row(tag, text)
	return true
end

local function plantedFail()
	local floor = put(toVec((leftRamp or trips[order[1]]).st))
	local ok, at = leg(PLANTED, false)
	return row(
		"R90",
		if ok then "FAIL-PLANTED reached (unexpected)" else `FAIL-PLANTED STOPPED {fmt(at)} floor {floor}`
	)
end

task.spawn(function()
	local clean = true
	for _, no in order do
		local ok, ran = pcall(runTrip, no, trips[no])
		if not ok then
			row(string.format("R%02d", no), `FIRED T{no}: {tostring(ran)}`)
		end
		if not ok or not ran then
			clean = false
			break
		end
	end
	if clean and group == "smoke" then
		local ok, err = pcall(plantedFail)
		if not ok then
			row("R90", `FIRED planted fail: {tostring(err)}`)
		end
	end
	ReplicatedStorage:SetAttribute("P4t13Running", false)
end)

return `started {group} {count}`
