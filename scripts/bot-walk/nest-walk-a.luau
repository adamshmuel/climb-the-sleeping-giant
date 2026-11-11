--!strict
-- Plan 4 Task 13b: nest-walk, part a of 2. Paste a then b joined, on the CLIENT in Play after session-hold,
-- nest-meter (server) and nest-legs. Group: attribute P4t13Group (smoke, A, B, C, M, L, R). Rows: P4t13Results R<trip>.
local CHECK_ONLY = false

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

if CHECK_ONLY or not RunService:IsRunning() or not RunService:IsClient() then
	return "no Play: nest-walk runs on the client in Play; changes nothing"
end

type Point = { x: number, y: number, z: number, c: boolean? }
type Trip = { n: string, w: string, g: number, s: number, k: string, st: Point, up: { Point }, dn: { Point } }

local ARRIVE = 2 -- studs flat; a climb point also needs 1.5 studs in height
local RANGE =
	{ smoke = { 17, 17 }, A = { 1, 24 }, B = { 25, 32 }, C = { 33, 44 }, M = { 1, 16 }, L = { 31, 32 }, R = { 1, 44 } }
local GRAB_REACH = 6 -- studs, 3D: Config.Grab.ReachStuds 8 minus ReachToleranceStuds 2
local PLANTED = Vector3.new(0, 5, -20)

local player = Players.LocalPlayer
local group = ReplicatedStorage:GetAttribute("P4t13Group")
local bounds = if type(group) == "string" then (RANGE :: any)[group] else nil
local legs = ReplicatedStorage:FindFirstChild("P4t13Legs")
local legsState = ReplicatedStorage:GetAttribute("P4t13LegsState")
if bounds == nil then
	return "set ReplicatedStorage attribute P4t13Group to smoke, A, B, C, M, L or R first"
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

local function row(name: string, text: string)
	local value = Instance.new("StringValue")
	value.Name = name
	value.Value = text
	value.Parent = results
end

local function held(): (boolean, string)
	local beat, phase =
		ReplicatedStorage:GetAttribute("TrialHoldBeat"), ReplicatedStorage:GetAttribute("TrialHoldPhase")
	if type(beat) ~= "number" or Workspace:GetServerTimeNow() - beat > 2 then
		return false, "no or old beat"
	end
	return phase == "Asleep", "phase " .. tostring(phase)
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
	local c = player.Character or player.CharacterAdded:Wait()
	return c:WaitForChild("Humanoid") :: Humanoid, c:WaitForChild("HumanoidRootPart") :: BasePart
end

local function feetOf(hum: Humanoid, root: BasePart): Vector3
	return root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
end

-- One walk point, 8 s a try; after a timeout: step back 4 studs, turn to it, one more try. `anchor` (up walk): also
-- reached within GRAB_REACH (3D) of it (3rd result true). `nextPt` (up climb point): walk to it, reached at flat <= 3
-- and feet.Y >= target.Y - 1.5. `down` (down climb point): reached when feet.Y - target.Y is -1.5 to 2.5.
local function leg(
	target: Vector3,
	climb: boolean,
	anchor: Vector3?,
	nextPt: Vector3?,
	down: boolean?
): (boolean, Vector3, boolean)
	local hum, root = body()
	local lift = Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	local viaNear = false
	for attempt = 1, 2 do
		local lastCall = 0.0
		local reached = waitUntil(function(): boolean
			local feet = feetOf(hum, root)
			if os.clock() - lastCall > 1.5 then
				hum:MoveTo((nextPt or target) + lift)
				lastCall = os.clock()
			end
			local flat = ((feet - target) * Vector3.new(1, 0, 1)).Magnitude
			local dy = feet.Y - target.Y
			if anchor ~= nil and (feet - anchor).Magnitude <= GRAB_REACH then
				viaNear = true
				return true
			elseif nextPt ~= nil then
				return flat <= 3 and dy >= -1.5
			elseif down == true and climb then
				return flat <= ARRIVE and dy >= -1.5 and dy <= 2.5
			end
			return flat <= ARRIVE and (not climb or math.abs(dy) <= 1.5)
		end, 8)
		if reached then
			return true, feetOf(hum, root), viaNear
		elseif attempt == 1 then
			local away = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
			hum:MoveTo(root.Position + (if away.Magnitude > 0.1 then away.Unit * 4 else Vector3.new(4, 0, 0)))
			task.wait(1.5)
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
		end
	end
	return false, feetOf(hum, root), false
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

local function anchorOf(prompt: ProximityPrompt): Vector3?
	local at: any = prompt.Parent
	return if at:IsA("Attachment") then at.WorldPosition elseif at:IsA("BasePart") then at.Position else nil
end

-- The nest name of a prompt (the child of EggSpots above it).
local function nestOf(prompt: ProximityPrompt): string
	local node: Instance? = prompt
	while node ~= nil and node.Parent ~= spots do
		node = node.Parent
	end
	return if node ~= nil then node.Name else prompt.Name
end

-- T32 note for a grab that failed: feet-to-anchor 3D distance and the nests whose prompts are shown now.
local function grabNote(hum: Humanoid, root: BasePart, anchor: Vector3?): string
	local names: { string } = {}
	for prompt in shown do
		table.insert(names, nestOf(prompt))
	end
	local d = if anchor ~= nil then f1((feetOf(hum, root) - anchor).Magnitude) else "none"
	return ` d {d} shown {if #names > 0 then table.concat(names, ",") else "none"}`
end
