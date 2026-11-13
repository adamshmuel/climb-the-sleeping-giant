--!strict
-- Plan 5 Task 23a push job (Client, Play). CHECK_ONLY = true or no Play: returns "no Play: nothing set".
-- Paste once on the Client after scripts/studio/session-hold.luau runs on the Server.
-- Sets shared.P23 = { Tp, Push, Shown, Floor, Ramp, Slide, Stop }. The camera is never changed.
-- One render-step loop at Input+1 holds the push (studio-jobs: the control script resets Move each frame).
-- Meter: attribute "Meter" on GiantState (src/server/Giant/GiantDirector.luau).
local CHECK_ONLY = false
local RunService = game:GetService("RunService")
if CHECK_ONLY or not RunService:IsRunning() then
	return "no Play: nothing set"
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PromptService = game:GetService("ProximityPromptService")

-- selene: allow(global_usage)
local store: { [string]: any } = shared :: any
local plr = Players.LocalPlayer
local requireModule: (Instance) -> any = require :: any
local Net = requireModule(RS:WaitForChild("Shared"):WaitForChild("Net"))
local state = RS:FindFirstChild(Net.GiantStateName, true)
local push = Vector3.zero
local sliding = false
local seen: { string } = {}
-- PromptShown fires once when a prompt appears: one listener from load keeps every Nest_ name seen.
local old = store.P23Conn :: RBXScriptConnection?
if old then
	old:Disconnect()
end
store.P23Conn = PromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	local node: Instance? = prompt
	while node ~= nil and node ~= Workspace do
		if string.sub(node.Name, 1, 5) == "Nest_" then
			if not table.find(seen, node.Name) then
				table.insert(seen, node.Name)
				table.sort(seen)
			end
			return
		end
		node = node.Parent
	end
end)

pcall(function()
	RunService:UnbindFromRenderStep("P23Move")
end)
RunService:BindToRenderStep("P23Move", Enum.RenderPriority.Input.Value + 1, function()
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum ~= nil and push.Magnitude > 0 then
		hum:Move(push, false)
	end
end)

-- From scripts/studio/session-hold.luau: a run needs a fresh beat while the phase is Asleep.
local function held(): (boolean, string)
	local beat = RS:GetAttribute("TrialHoldBeat")
	if type(beat) ~= "number" then
		return false, "no beat"
	end
	if Workspace:GetServerTimeNow() - beat > 2 then
		return false, "old beat"
	end
	if RS:GetAttribute("TrialHoldPhase") ~= "Asleep" then
		return false, "phase " .. tostring(RS:GetAttribute("TrialHoldPhase"))
	end
	return true, "held"
end
local function meter(): number
	local m = if state then state:GetAttribute("Meter") else nil
	return if type(m) == "number" then m else -1
end
local function at(v: Vector3): string
	return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end
local function body(): (Humanoid, BasePart)
	local c = plr.Character :: Model
	return c:FindFirstChildOfClass("Humanoid") :: Humanoid, c:FindFirstChild("HumanoidRootPart") :: BasePart
end
local function floorPart(root: BasePart): string
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { plr.Character :: Model }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rp)
	return if hit then `{hit.Instance.Name} @ {at(hit.Position)}` else "none"
end
local function report(tag: string, m0: number, ok: boolean, why: string): string
	local hum, root = body()
	local cam = (Workspace.CurrentCamera :: Camera).CFrame
	local line = `{tag} {if ok then "held" else `VOID ({why})`} root {at(root.Position)} state {tostring(hum:GetState())}`
		.. ` floor {floorPart(root)} meter {m0}->{meter()} seen [{table.concat(seen, ",")}] CAMPOS {at(cam.Position)} CAMLOOK {at(
			cam.Position + cam.LookVector * 20
		)}`
	print(line)
	return line
end
local function begin(dx: number, dz: number): (number, boolean, string)
	local ok, why = held()
	local d = Vector3.new(dx, 0, dz)
	push = if d.Magnitude > 0 then d.Unit else d
	return meter(), ok, why
end

local P23: { [string]: (...any) -> any } = {}
store.P23 = P23

function P23.Tp(x: number, y: number, z: number, lookX: number, lookZ: number): string
	local hum, root = body()
	table.clear(seen)
	push = Vector3.zero
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(lookX, y, lookZ))
	local t = os.clock()
	repeat
		task.wait(0.1)
	until (hum.FloorMaterial ~= Enum.Material.Air and root.AssemblyLinearVelocity.Magnitude < 2) or os.clock() - t > 5
	local line = `Tp root {at(root.Position)} state {tostring(hum:GetState())} floor {floorPart(root)}`
	print(line)
	return line
end

function P23.Push(dx: number, dz: number, secs: number): string
	local m0, ok, why = begin(dx, dz)
	task.wait(secs)
	push = Vector3.zero
	return report("Push", m0, ok, why)
end

function P23.Slide(dx: number, dz: number, secs: number): string
	local m0, ok, why = begin(dx, dz)
	local t0 = os.clock()
	print(`SLIDE-T0 {t0}`)
	sliding = true
	task.spawn(function()
		while sliding and os.clock() < t0 + secs do
			task.wait(0.05)
		end
		if sliding then
			sliding = false
			push = Vector3.zero
			report("Slide-end", m0, ok, why)
		end
	end)
	return `Slide started {t0} meter {m0} {if ok then "held" else `VOID ({why})`}`
end

function P23.Stop(): string
	push = Vector3.zero
	sliding = false
	return report("Stop", meter(), (held()), "")
end

function P23.Shown(secs: number): { string }
	task.wait(secs)
	local names = table.clone(seen)
	table.clear(seen)
	print(`Shown {#names}: {table.concat(names, ",")}`)
	return names
end

function P23.Floor(): string
	local _, root = body()
	local line = `Floor {floorPart(root)}`
	print(line)
	return line
end

-- Top and foot of a walk part: floor rays down at both ends of its long axis (higher end is the top).
function P23.Ramp(name: string): string
	local part = Workspace.World.WalkSurfaces:FindFirstChild(name)
	if part == nil or not part:IsA("BasePart") then
		return `Ramp {name}: not found`
	end
	local s = part.Size
	local axis = if s.X >= s.Z then Vector3.xAxis else Vector3.zAxis
	local half = math.max(s.X, s.Z) / 2
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { part }
	local ends: { Vector3 } = {}
	for _, sign in { 1, -1 } do
		local p = part.Position + part.CFrame:VectorToWorldSpace(axis) * half * sign * 0.9
		local hit = Workspace:Raycast(p + Vector3.new(0, s.Y + 10, 0), Vector3.new(0, -(s.Y + 20), 0), rp)
		if hit == nil then
			return `Ramp {name}: no hit at end {sign}`
		end
		table.insert(ends, hit.Position)
	end
	local hi = (ends[1] :: Vector3).Y >= (ends[2] :: Vector3).Y
	local line =
		`Ramp {name} top {at(ends[if hi then 1 else 2] :: Vector3)} foot {at(ends[if hi then 2 else 1] :: Vector3)}`
	print(line)
	return line
end

return "P23 ready: Tp Push Shown Floor Ramp Slide Stop"
