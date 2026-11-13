-- (no --!strict line: job-check lints a part without it together with the part before it, as one paste.)
-- Plan 5 Task 22, Part 22-1 (work/p5t22/22-scripts.md, "t22-grab", rulings 6 to 9). CLIENT job, Play only. ONE paste:
-- client-a.luau, this file, client-b.luau (last: it ends with a return). It shadows client-a's runLeg for every leg:
-- T22Leg attribute and events (t22-meter counts thuds); A and P legs grab and walk back carrying; X legs cross (x flips,
-- |x| >= 6, feet above the seam, no stall); O legs step off within 4 s. Leg fields are re-read from T8bLegs.
-- Every name starts with "tg". In Edit (or CHECK_ONLY) it returns "no Play: nothing walked".
local CHECK_ONLY = false
local tgRun = game:GetService("RunService")
if CHECK_ONLY or not tgRun:IsRunning() then
	return "no Play: nothing walked"
end

local tgRS = game:GetService("ReplicatedStorage")
local tgPromptService = game:GetService("ProximityPromptService")
local tgOrigRunLeg = runLeg -- client-a's, kept for the plain legs
local TG_STALL_SPEED, TG_STALL_SECONDS, TG_MOVING_SPEED = 2, 1, 4 -- xk-decision.md
local TG_CROSS_MIN_X, TG_BAND_SECONDS = 6, 4 -- xk-decision.md, pocket-decision.md

local tgRemoteItem = tgRS:WaitForChild("T22Leg", 5)
local tgValue = tgRS:WaitForChild("T8bLegs", 10)
print(`t22-grab: found {(if tgRemoteItem ~= nil then 1 else 0) + (if tgValue ~= nil then 1 else 0)} of 2`)
if tgRemoteItem == nil or tgValue == nil then
	error(
		"t22-grab: ReplicatedStorage.T22Leg (paste t22-meter first) or T8bLegs (paste t22-legs-a and b) is missing",
		0
	)
end
local tgRemote = tgRemoteItem :: RemoteEvent
local tgOkLoad, tgData: any = pcall(function()
	return game:GetService("HttpService"):JSONDecode((tgValue :: StringValue).Value)
end)
if not tgOkLoad or type(tgData) ~= "table" or type(tgData.legs) ~= "table" then
	error("t22-grab: the T8bLegs JSON would not load: " .. tostring(tgData), 0)
end
local tgExtra: { [number]: any } = {}
for _, raw in tgData.legs do
	tgExtra[raw.n] = raw
end

local tgShown: { [ProximityPrompt]: boolean } = {}
tgPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	tgShown[prompt] = true
end)
tgPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	tgShown[prompt] = nil
end)

-- Key mode (shared.T22KeyGrab, ruling 9): the clock of the first hold began, trigger and Carrying change on a cuff pocket.
-- selene: allow(global_usage)
local TG_KEY_MODE = shared.T22KeyGrab == true
local TG_KEY_WINDOW = 60 -- s the tester has to hold E (it was 30)
local tgHoldAt: number? = nil
local tgTrigAt: number? = nil
local tgCarryAt: number? = nil

local function tgIsCuff(prompt: ProximityPrompt): boolean
	local node: Instance? = prompt
	while node ~= nil do
		if string.sub(node.Name, 1, 9) == "Nest_Cuff" then
			return true
		end
		node = node.Parent
	end
	return false
end

if TG_KEY_MODE then
	tgPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		if tgHoldAt == nil and tgIsCuff(prompt) then
			tgHoldAt = os.clock()
		end
	end)
	tgPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if tgTrigAt == nil and tgIsCuff(prompt) then
			tgTrigAt = os.clock()
		end
	end)
end

local function tgF(v: number): string
	return string.format("%.1f", v)
end

local function tgSince(clock: number?, t0: number): string
	return if clock ~= nil then tgF(clock - t0) else "-"
end

local function tgWaitUntil(done: () -> boolean, seconds: number): boolean
	local started = os.clock()
	while not done() and os.clock() - started < seconds do
		task.wait(0.1)
	end
	return done()
end

local function tgPoints(list: any): { Vector3 }
	local out: { Vector3 } = {}
	if type(list) == "table" then
		for _, a in list do
			table.insert(out, Vector3.new(a[1], a[2], a[3]))
		end
	end
	return out
end

local function tgWalkTo(target: Vector3): boolean
	local _, root = bot()
	local reached = false
	drive(function()
		local feet = feetOf(root)
		if BotWalk.reachedEnd(feet, target) then
			reached = true
			return nil, nil
		end
		return BotWalk.steer(feet, target), false
	end, BotWalk.LIMIT + 1)
	return reached
end

-- At the ledge: grab from the pocket whose prompt is on (Grab.luau line 223). Returns grabbed, why.
local function tgGrabAt(nestName: string): (boolean, string)
	local t0 = os.clock() -- the moment T22Wait is set (below); the start of the check for the early and no-grab returns
	local function stamp(): string
		return ` hold={tgSince(tgHoldAt, t0)} trig={tgSince(tgTrigAt, t0)} carry={tgSince(tgCarryAt, t0)}`
	end
	if player:GetAttribute("Carrying") == "Epic" then
		return true, "GRABBED early" .. stamp()
	end
	local world = Workspace:FindFirstChild("World")
	local spots = if world ~= nil then world:FindFirstChild("EggSpots") else nil
	local side = if string.sub(nestName, -5) == "_Left" then "Left" else "Right"
	local nest: Instance? = nil
	local prompt: ProximityPrompt? = nil
	for _, pocket in { `Nest_CuffFront_{side}`, `Nest_CuffBack_{side}` } do
		local found = if spots ~= nil then spots:FindFirstChild(pocket) else nil
		local foundPrompt = if found ~= nil then found:FindFirstChildWhichIsA("ProximityPrompt", true) else nil
		if foundPrompt ~= nil and foundPrompt.Enabled then
			nest, prompt = found, foundPrompt
			break
		end
	end
	if nest == nil or prompt == nil then
		return false, "NO_EGG" .. stamp()
	end
	local pocketName = nest.Name
	local rank = nest:GetAttribute("Rarity")
	local readyPrompt = prompt
	if not tgWaitUntil(function(): boolean
		return tgShown[readyPrompt] == true
	end, 3) then
		return false, `NO_PROMPT {pocketName}` .. stamp()
	end
	local carryConnection: RBXScriptConnection? = nil
	if TG_KEY_MODE then
		-- The tester holds E with the keyboard tool while T22Wait names the pocket.
		t0 = os.clock()
		carryConnection = player:GetAttributeChangedSignal("Carrying"):Connect(function()
			local carrying = player:GetAttribute("Carrying")
			if tgCarryAt == nil and (if rank ~= nil then carrying == rank else carrying ~= nil) then
				tgCarryAt = os.clock()
			end
		end)
		player:SetAttribute("T22Wait", pocketName)
	else
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration + 0.2)
		prompt:InputHoldEnd()
	end
	local got = tgWaitUntil(function(): boolean
		local carrying = player:GetAttribute("Carrying")
		return if rank ~= nil then carrying == rank else carrying ~= nil
	end, if TG_KEY_MODE then TG_KEY_WINDOW else 2)
	if TG_KEY_MODE then
		player:SetAttribute("T22Wait", nil)
	end
	if carryConnection ~= nil then
		carryConnection:Disconnect()
	end
	local text = (if got then `GRABBED {pocketName}` else `NO_GRAB {pocketName}`) .. stamp()
	-- selene: allow(global_usage)
	shared.T22GrabWhy = text
	return got, text
end

-- A and P: walk the path to the nest, grab, walk back carrying. Pass: grabbed and (no way back, or back at its end carrying).
local function tgGrabLeg(leg: Leg, extra: any): (boolean, string, Vector3, number)
	local humanoid = bot()
	placeBot(leg.from)
	settle(humanoid)
	local began = os.clock()
	local path, back = tgPoints(extra.path), tgPoints(extra.back)
	local down, home = 0, 0
	local reason = "ARRIVED"
	for i = 2, #path do
		if not tgWalkTo(path[i]) then
			reason = "STOPPED"
			break
		end
		down += 1
	end
	local grabbed, why = false, "NOT_REACHED"
	if reason == "ARRIVED" then
		grabbed, why = tgGrabAt(tostring(extra.nest))
		if not grabbed then
			reason = why
		end
	end
	if grabbed then
		for _, point in back do
			if not tgWalkTo(point) then
				reason = "BACK_STOPPED"
				break
			end
			home += 1
		end
	end
	local carrying = player:GetAttribute("Carrying") ~= nil
	local pass = reason == "ARRIVED" and carrying
	if reason == "ARRIVED" and not carrying then
		reason = "DROPPED"
	end
	local endFeet = feetNow()
	print(
		`T22 grab #{leg.n} {leg.name}: {reason}, grabbed {if grabbed then "yes" else "no"} ({why}), down {down} of {#path - 1}, back {home} of {#back}, carrying {if carrying
			then "yes"
			else "no"}, end ({tgF(endFeet.X)}, {tgF(endFeet.Y)}, {tgF(endFeet.Z)})`
	)
	return pass, reason, endFeet, os.clock() - began
end

local function tgWatch(): () -> (number, boolean)
	local _, root = bot()
	local last, minY, moving, slow, stalled = root.Position, math.huge, false, 0, false
	local connection = tgRun.Heartbeat:Connect(function(dt: number)
		local now = root.Position
		local speed = Vector3.new(now.X - last.X, 0, now.Z - last.Z).Magnitude / math.max(dt, 0.001)
		last = now
		minY = math.min(minY, now.Y - ROOT_OFFSET)
		if speed >= TG_MOVING_SPEED then
			moving = true
		end
		if moving and speed < TG_STALL_SPEED then
			slow += dt
			stalled = stalled or slow >= TG_STALL_SECONDS
		else
			slow = 0
		end
	end)
	return function(): (number, boolean)
		connection:Disconnect()
		return minY, stalled
	end
end

local function tgInBand(feet: Vector3): boolean
	local ax = math.abs(feet.X)
	return ax >= 30 and ax <= 34 and feet.Z >= -56 and feet.Z <= -49 and feet.Y >= 18 and feet.Y <= 26
end

local function tgPlainLeg(leg: Leg, extra: any): (boolean, string, Vector3, number)
	placeBot(leg.from) -- client-a places again at the same spot; the watch starts from the real start
	local stop = tgWatch()
	local pass, reason, endFeet, secs = tgOrigRunLeg(leg)
	local minY, stalled = stop()
	local extraText = ""
	if extra ~= nil and extra.cross == true then
		local flips = (leg.from.X < 0) ~= (endFeet.X < 0) and math.abs(endFeet.X) >= TG_CROSS_MIN_X
		local above = endFeet.Y >= math.min(leg.from.Y, leg.to.Y) - 2 -- assumed: the seam is not lower than the belly top
		extraText = ` cross: flips {tostring(flips)}, above {tostring(above)}, stalled {tostring(stalled)}`
		if pass and not flips then
			pass, reason = false, "CROSS_FLIP"
		elseif pass and not above then
			pass, reason = false, "CROSS_LOW"
		elseif pass and stalled then
			pass, reason = false, "CROSS_STALL"
		end
	elseif leg.kind == "step" and not pass and tgInBand(endFeet) then
		local _, root = bot()
		local landed, pushSecs = pushUntilLanded(nil, leg.to)
		local off = landed and pushSecs <= TG_BAND_SECONDS and onMeadow(feetNow(), root)
		pass, reason = off, if off then "PERCH_OFF" else "PERCH"
		extraText = ` band: off {tostring(off)} in {tgF(pushSecs)} s`
	end
	print(`T22 leg #{leg.n} {leg.kind} {leg.name}: {reason}, lowest feet y {tgF(minY)}{extraText}`)
	return pass, reason, endFeet, secs
end

-- selene: allow(shadowing)
local runLeg: (Leg) -> (boolean, string, Vector3, number) = function(leg: Leg): (boolean, string, Vector3, number)
	player:SetAttribute("T22Leg", leg.n)
	tgRemote:FireServer("start", leg.n, leg.kind)
	local extra = tgExtra[leg.n]
	local ok, pass, reason, endFeet, secs = pcall(if leg.kind == "grab" then tgGrabLeg else tgPlainLeg, leg, extra)
	tgRemote:FireServer("end", leg.n)
	if not ok then
		print(`T22 leg #{leg.n} ERROR {string.sub(tostring(pass), 1, 160)}`)
		return false, "ERROR", leg.from, 0
	end
	return pass :: boolean, reason :: string, endFeet :: Vector3, secs :: number
end
