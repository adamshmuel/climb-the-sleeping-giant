--!strict
-- Plan 5 Task 22, Part 22-1, Step 1 (work/p5t22/22-scripts.md, "t22-meter"): paste once on the SERVER, in Play, after
-- session-hold. A copy of nest-meter.luau keyed on the client's leg number instead of trips. It makes
-- ReplicatedStorage.T22Leg (RemoteEvent). The client fires ("start", n, kind) at each leg start and ("end", n) after it
-- (a player attribute set on the client never reaches the server, so the attribute T22Leg is not enough).
--   start: Meter 0, offset 0, NoHold on, then every Heartbeat counts a burst when the meter rose by LOW (15) or more since the
--          last read (the meter is cut by 40 at 40, as nest-meter, so no warning mark fires).
--   end:   writes on ReplicatedStorage: T22Rise_<n> (the biggest burst), T22Thud_<n> ("one" for exactly one burst of 0.5 to 1.5
--          times the Belly burst, "none" for no burst, "many" for more or a bigger one) and T22Meter_<n> (before, after, bursts, kind).
-- In Edit, or with CHECK_ONLY, it changes nothing and returns "no Play: Belly burst <n>, ...".
local CHECK_ONLY = false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local requireModule: (Instance) -> any = require :: any
local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local configModule = if sharedFolder ~= nil then sharedFolder:FindFirstChild("Config") else nil
if configModule == nil then
	return "no Shared.Config"
end
local config = requireModule(configModule:Clone())

-- One Belly thud = Config.Noise.JumpBurst * Config.Noise.ZoneMultiplier.Belly (as Noise.jumpBurst("Belly")); a thud is one
-- meter change of LOW or more between two Heartbeat reads (footsteps raise the meter too, so the total is not used).
local burst = config.Noise.JumpBurst * config.Noise.ZoneMultiplier.Belly
local lowestMark = math.huge
for _, mark in config.Meter.WarningMarks do
	lowestMark = math.min(lowestMark, mark)
end
local LOW, HIGH = 0.5 * burst, 1.5 * burst -- a tolerance set by code_lead (22-scripts.md)
local info = `Belly burst {burst}, one thud = one jump of {LOW} to {HIGH}, lowest warning mark {lowestMark}`

-- Play check first: nothing below runs in Edit.
if CHECK_ONLY or not RunService:IsRunning() or not RunService:IsServer() then
	return `no Play: {info}`
end
local CUT = 40
if lowestMark <= CUT then
	return `STOP: lowest warning mark {lowestMark} is not above {CUT}`
end
if ReplicatedStorage:FindFirstChild("T22Leg") ~= nil then
	return "already running"
end

local GIANT_STATE = "GiantState" -- Net.GiantStateName
local state = ReplicatedStorage:FindFirstChild(GIANT_STATE, true)
if state == nil then
	return "no GiantState"
end

local function held(): (boolean, string)
	local beat = ReplicatedStorage:GetAttribute("TrialHoldBeat")
	if type(beat) ~= "number" then
		return false, "no beat"
	end
	if Workspace:GetServerTimeNow() - beat > 2 then
		return false, "old beat"
	end
	if ReplicatedStorage:GetAttribute("TrialHoldPhase") ~= "Asleep" then
		return false, "phase " .. tostring(ReplicatedStorage:GetAttribute("TrialHoldPhase"))
	end
	return true, "held"
end

local remote = Instance.new("RemoteEvent")
remote.Name = "T22Leg"
remote.Parent = ReplicatedStorage

local active: number? = nil
local activeKind = ""
local before = 0
local offset = 0
local lastMeter = 0
local bursts: { number } = {}

RunService.Heartbeat:Connect(function()
	if active == nil then
		return
	end
	local m = state:GetAttribute("Meter")
	if type(m) ~= "number" then
		return
	end
	if m - lastMeter >= LOW then
		table.insert(bursts, m - lastMeter)
	end
	lastMeter = m
	if m >= CUT then
		state:SetAttribute("Meter", m - CUT)
		offset += CUT
		lastMeter = m - CUT
	end
end)

local function isInt(v: any): boolean
	return type(v) == "number" and v % 1 == 0 and v >= 1 and v <= 9999
end
local function round1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

remote.OnServerEvent:Connect(function(player: Player, action: any, n: any, kind: any)
	if player ~= Players:GetPlayers()[1] then
		print(`t22-meter: ignored {player.Name}`)
		return
	end
	if not isInt(n) then
		print(`t22-meter: bad leg number {tostring(n)}`)
		return
	end
	if action == "start" then
		local ok, why = held()
		if not ok then
			print(`t22-meter: start {n} refused, giant not held ({why})`)
			return
		end
		local m = state:GetAttribute("Meter")
		before = if type(m) == "number" then m else 0
		activeKind = if type(kind) == "string" then kind else ""
		player:SetAttribute("NoHold", true)
		state:SetAttribute("Meter", 0)
		offset, lastMeter, bursts, active = 0, 0, {}, n
	elseif action == "end" then
		if active == nil or n ~= active then
			print(`t22-meter: bad end {tostring(n)}`)
			return
		end
		local m = state:GetAttribute("Meter")
		local after = round1((if type(m) == "number" then m else 0) + offset)
		active = nil
		player:SetAttribute("NoHold", false)
		local rise = round1(if #bursts > 0 then math.max(table.unpack(bursts)) else 0)
		local thud = if #bursts == 0 then "none" elseif #bursts > 1 or rise > HIGH then "many" else "one"
		ReplicatedStorage:SetAttribute(`T22Rise_{n}`, rise)
		ReplicatedStorage:SetAttribute(`T22Thud_{n}`, thud)
		ReplicatedStorage:SetAttribute(
			`T22Meter_{n}`,
			`before {round1(before)} after {after} bursts {#bursts} biggest {rise} {activeKind}`
		)
	else
		print(`t22-meter: unknown action {tostring(action)}`)
	end
end)

return `t22-meter running: {info}, cut {CUT}`
