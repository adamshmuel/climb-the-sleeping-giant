--!strict
-- Session hold (red flag 61a). Paste once on the SERVER right after Start Play.
-- While the giant's Phase is "Asleep" it keeps Meter at 0, except while a player has the
-- attribute NoHold = true. Every 0.5 s it writes TrialHoldBeat and TrialHoldPhase on ReplicatedStorage.
-- It ends only when Play stops. A second paste sees a fresh beat and returns "already holding".
-- CHECK_ONLY = true (Edit): only the lookup, nothing is written (the folder is made at Play, so Edit says not found).
--
-- Run check: copy this into every run script (CLIENT or server) and call it before each case and
-- on every sample. When it returns false, log "VOID: giant not held (<reason>)" and stop.
--   local function held(): (boolean, string)
--   	local rs = game:GetService("ReplicatedStorage")
--   	local beat = rs:GetAttribute("TrialHoldBeat")
--   	if type(beat) ~= "number" then
--   		return false, "no beat"
--   	end
--   	if game:GetService("Workspace"):GetServerTimeNow() - beat > 2 then
--   		return false, "old beat"
--   	end
--   	if rs:GetAttribute("TrialHoldPhase") ~= "Asleep" then
--   		return false, "phase " .. tostring(rs:GetAttribute("TrialHoldPhase"))
--   	end
--   	return true, "held"
--   end
local CHECK_ONLY = false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local requireModule: (Instance) -> any = require :: any
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Net = requireModule(sharedFolder:WaitForChild("Net"):Clone()) -- the game's own name for the folder
local state = ReplicatedStorage:FindFirstChild(Net.GiantStateName, true)
if CHECK_ONLY then
	-- The server makes GiantState at Play (Net.setup), so in Edit it is normally missing.
	local found = if state == nil then "not found (the server makes it at Play)" else "found at " .. state:GetFullName()
	return "would look for " .. Net.GiantStateName .. " under ReplicatedStorage: " .. found .. "; writes nothing"
end
if state == nil then
	return "no GiantState"
end

local oldBeat = ReplicatedStorage:GetAttribute("TrialHoldBeat")
if type(oldBeat) == "number" and Workspace:GetServerTimeNow() - oldBeat < 1 then
	return "already holding"
end

local function noHold(): boolean
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("NoHold") == true then
			return true
		end
	end
	return false
end

task.spawn(function()
	local lastBeat = 0
	while state.Parent ~= nil do
		local phase = state:GetAttribute("Phase")
		if phase == "Asleep" and not noHold() then
			state:SetAttribute("Meter", 0)
		end
		local now = Workspace:GetServerTimeNow()
		if now - lastBeat >= 0.5 then
			lastBeat = now
			ReplicatedStorage:SetAttribute("TrialHoldBeat", now)
			ReplicatedStorage:SetAttribute("TrialHoldPhase", phase)
		end
		task.wait(0.1)
	end
end)

return "holding, phase " .. tostring(state:GetAttribute("Phase"))
