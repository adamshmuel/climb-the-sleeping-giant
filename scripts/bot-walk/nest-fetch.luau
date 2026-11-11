--!strict
-- Plan 4 Task 13a: the fetch for the nest walk (read only; paste it on either side). Spec: work/p4t13/13a-scripts.md.
-- Server: returns P4t13LegsState; when the legs are done it prints the trips per group and checks every trip has up and
-- down points. In Edit it then destroys the Edit legs folder and clears the status (nothing is left behind).
-- Client: returns every P4t13Results line in order, then `running` or `done N of M`. Over 3500 characters: the first
-- 3500 and `fetch again` (a second paste returns the rest). CHECK_ONLY = true: reads nothing.
local CHECK_ONLY = false

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local STATE = "P4t13LegsState"
local LIMIT = 3500
local SHOWN = 1000 -- Studio cuts a returned text at about 1024 characters

if CHECK_ONLY then
	return "would read P4t13LegsState (server) or P4t13Results (client); changes nothing"
end

local function onClient(): string
	local player = game:GetService("Players").LocalPlayer
	local folder = player:FindFirstChild("P4t13Results")
	if folder == nil then
		folder = ReplicatedStorage:FindFirstChild("P4t13Results")
	end
	if folder == nil then
		return "no P4t13Results"
	end
	local rows = folder:GetChildren()
	table.sort(rows, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	local lines: { string } = {}
	for _, row in rows do
		if row:IsA("StringValue") then
			lines[#lines + 1] = row.Value
		end
	end
	local want = ReplicatedStorage:GetAttribute("P4t13Count")
	local status = if type(want) == "number" and #lines >= want then `done {#lines} of {want}` else "running"
	local text = table.concat(lines, "\n")
	if #text > LIMIT then
		-- the part past the limit is fetched by the second paste
		local rest = player:GetAttribute("P4t13FetchFrom")
		local from = if type(rest) == "number" then rest else 1
		if from > 1 then
			player:SetAttribute("P4t13FetchFrom", nil)
			return string.sub(text, from, from + LIMIT - 1) .. "\n" .. status
		end
		player:SetAttribute("P4t13FetchFrom", LIMIT + 1)
		return string.sub(text, 1, LIMIT) .. "\nfetch again"
	end
	return text .. "\n" .. status
end

local function onServer(): string
	local isEdit = not RunService:IsRunning()
	local box: Instance = if isEdit then ServerStorage else ReplicatedStorage
	local state = box:GetAttribute(STATE)
	if state == nil then
		return "no P4t13LegsState"
	end
	local text = tostring(state)
	if string.sub(text, 1, 4) ~= "done" then
		return text
	end
	local folder = box:FindFirstChild("P4t13Legs")
	if folder == nil then
		return `{text}; but the folder P4t13Legs is gone`
	end
	local groups = { A = 0, B = 0, C = 0 }
	local missing: { string } = {}
	for _, value in folder:GetChildren() do
		local index = tonumber(string.sub(value.Name, 2))
		local ok, trip = pcall(function(): any
			return HttpService:JSONDecode((value :: StringValue).Value)
		end)
		if index == nil or not ok then
			missing[#missing + 1] = `{value.Name} unreadable`
			continue
		end
		local group = if index <= 24 then "A" elseif index <= 32 then "B" else "C"
		groups[group] += 1
		if #trip.up == 0 or #trip.dn == 0 then
			missing[#missing + 1] = `{value.Name} {trip.n} has no up or down points`
		end
	end
	local summary = `{text}; A {groups.A} B {groups.B} C {groups.C}`
	if #missing > 0 then
		summary ..= `; PROBLEMS {table.concat(missing, " | ")}`
	end
	print(summary)
	if isEdit then
		folder:Destroy()
		box:SetAttribute(STATE, nil)
		summary ..= "; Edit folder destroyed"
	end
	return string.sub(summary, 1, SHOWN)
end

if RunService:IsRunning() and RunService:IsClient() then
	return string.sub(onClient(), 1, 3800)
end
return onServer()
