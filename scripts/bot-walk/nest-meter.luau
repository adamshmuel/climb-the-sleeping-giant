--!strict
-- Plan 4 Task 13a: nest-meter. Paste once on the SERVER, in Play, after session-hold.
-- It makes ReplicatedStorage.P4t13Trip (RemoteEvent). nest-walk (CLIENT) fires it:
--   ("start", i, nestName, garden)  sets PlotIndex, the waiting egg, NoHold, Meter 0, offset 0, peak 0.
--   ("end", i)                      writes P4t13Peak_<i> and P4t13Phase_<i> on ReplicatedStorage.
-- While a trip runs, every Heartbeat: peak = max(peak, Meter + offset). When Meter reaches 40 (under the
-- lowest warning mark) it is cut back by 40 and the offset grows by 40, so Meter + offset is the meter
-- the giant would have had with no cut (the drain is the same at any value above 0).
-- In Edit, or with CHECK_ONLY, it changes nothing and returns "no Play: lowest warning mark <n>".
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
local lowestMark = math.huge
for _, mark in config.Meter.WarningMarks do
	lowestMark = math.min(lowestMark, mark)
end

-- Play check first: nothing below runs in Edit.
if CHECK_ONLY or not RunService:IsRunning() or not RunService:IsServer() then
	return `no Play: lowest warning mark {lowestMark}`
end
local CUT = 40
if lowestMark <= CUT then
	return `STOP: lowest warning mark {lowestMark} is not above {CUT}`
end
print(`nest-meter: lowest warning mark {lowestMark}, meter cut at {CUT}`)

if ReplicatedStorage:FindFirstChild("P4t13Trip") ~= nil then
	return "already running"
end

local GIANT_STATE = "GiantState" -- Net.GiantStateName
local state = ReplicatedStorage:FindFirstChild(GIANT_STATE, true)
local world = Workspace:FindFirstChild("World")
local spots = if world ~= nil then world:FindFirstChild("EggSpots") else nil
if state == nil or spots == nil then
	return "no GiantState or World.EggSpots"
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
remote.Name = "P4t13Trip"
remote.Parent = ReplicatedStorage

local active: number? = nil
local offset = 0
local peak = 0

RunService.Heartbeat:Connect(function()
	if active == nil then
		return
	end
	local m = state:GetAttribute("Meter")
	if type(m) ~= "number" then
		return
	end
	peak = math.max(peak, m + offset)
	if m >= CUT then
		state:SetAttribute("Meter", m - CUT)
		offset += CUT
	end
end)

local function isInt(v: any, low: number, high: number): boolean
	return type(v) == "number" and v % 1 == 0 and v >= low and v <= high
end

local function start(player: Player, i: number, nestName: string, garden: number)
	local ok, why = held()
	if not ok then
		print(`nest-meter: start {i} refused, giant not held ({why})`)
		return
	end
	player:SetAttribute("PlotIndex", garden)
	for _, nest in spots:GetChildren() do
		nest:SetAttribute("Waiting", nest.Name == nestName)
	end
	player:SetAttribute("NoHold", true)
	state:SetAttribute("Meter", 0)
	offset = 0
	peak = 0
	active = i
end

remote.OnServerEvent:Connect(function(player: Player, action: any, i: any, nestName: any, garden: any)
	if player ~= Players:GetPlayers()[1] then
		print(`nest-meter: ignored {player.Name}`)
		return
	end
	if action == "start" then
		if not isInt(i, 1, 99) or type(nestName) ~= "string" or spots:FindFirstChild(nestName) == nil then
			print(`nest-meter: bad start {tostring(i)} {tostring(nestName)}`)
			return
		end
		if not isInt(garden, 1, 8) then
			print(`nest-meter: bad garden {tostring(garden)}`)
			return
		end
		start(player, i, nestName, garden)
	elseif action == "end" then
		if active == nil or i ~= active then
			print(`nest-meter: bad end {tostring(i)}`)
			return
		end
		active = nil
		player:SetAttribute("NoHold", false)
		ReplicatedStorage:SetAttribute(`P4t13Peak_{i}`, math.floor(peak * 10 + 0.5) / 10)
		ReplicatedStorage:SetAttribute(`P4t13Phase_{i}`, state:GetAttribute("Phase"))
	else
		print(`nest-meter: unknown action {tostring(action)}`)
	end
end)

return `nest-meter running: lowest warning mark {lowestMark}, cut {CUT}`
