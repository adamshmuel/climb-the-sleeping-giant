-- (no --!strict line: job-check lints a part without it together with the part before it, as one paste.)
-- Task 8b slot 4, second half: pasted right after client-a.luau in the same Client call.
-- Uses client-a's names (Leg, BotWalk, feetNow, placeBot, press, runLeg) and never redefines them.
-- Every name here starts with "wk" so it can't clash with client-a's.
local wkWallName = "Left boot ramp up"
local wkWallHold = 30
local wkFailHold = 60
local wkGuess: { [string]: number } = { up = 9, down = 9, drop = 14, step = 6 }

type WkState = {
	done: boolean,
	walked: number,
	total: number,
	heartbeat: number,
	last: string,
	letters: { [number]: string },
	byKind: { [string]: { [string]: number } },
	fails: { string },
	short: { string },
	failCount: number,
	failLegs: { number },
	expectedEnd: number,
	startedAt: number,
	holds: { [string]: { [string]: number } },
}

-- selene: allow(global_usage)
local wkShared: any = shared
local wkRequire: (Instance) -> any = require :: any
local wkOut: { string } = {}

-- A stop goes first in the reply and names the check that fired with its own failure.
local function wkStop(line: string): string
	table.insert(wkOut, 1, "FIRED: " .. line)
	return string.sub(table.concat(wkOut, "\n"), 1, 1000)
end
local function wkFeet(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end
local function wkClock(t: number): string
	return DateTime.fromUnixTimestamp(t):FormatUniversalTime("HH:mm:ss", "en-us")
end
local function wkVec(a: any): Vector3
	return Vector3.new(a[1], a[2], a[3])
end
local function wkToLeg(raw: any): Leg
	local leg: any = { n = raw.n, kind = raw.kind, name = raw.name, from = wkVec(raw.from), to = wkVec(raw.to) }
	leg.onHim, leg.open, leg.how, leg.ladder = raw.onHim, raw.open, raw.how, raw.ladder
	for _, key in { "foot", "top", "away" } do
		if raw[key] ~= nil then
			leg[key] = wkVec(raw[key])
		end
	end
	return leg :: Leg
end

-- 1. Load the two items (found N of 2).
local wkRS = game:GetService("ReplicatedStorage")
local wkLegsValue = wkRS:WaitForChild("T8bLegs", 10)
local wkModule = wkRS:WaitForChild("T8bBotWalk", 10)
local wkFound = (if wkLegsValue ~= nil then 1 else 0) + (if wkModule ~= nil then 1 else 0)
table.insert(wkOut, `found {wkFound} of 2`)
if wkLegsValue == nil or wkModule == nil then
	return wkStop(`found {wkFound} of 2: slot 3 made no T8bLegs or T8bBotWalk in 10 s`)
end
local wkOkLoad, wkData: any = pcall(function()
	BotWalk = wkRequire(wkModule)
	return game:GetService("HttpService"):JSONDecode((wkLegsValue :: StringValue).Value)
end)
if not wkOkLoad or type(wkData) ~= "table" or type(wkData.legs) ~= "table" then
	return wkStop("T8bBotWalk or the T8bLegs JSON would not load: " .. tostring(wkData))
end

local wkLegs: { Leg } = {}
local wkByN: { [number]: Leg } = {}
local wkTotals: { [string]: number } = {}
local wkDone: { [string]: number } = {}
local wkSecs: { [string]: number } = {}
local wkWall: Leg? = nil
for _, raw in wkData.legs do
	local leg = wkToLeg(raw)
	table.insert(wkLegs, leg)
	wkByN[leg.n] = leg
	wkTotals[leg.kind] = (wkTotals[leg.kind] or 0) + 1
	if leg.name == wkWallName and wkWall == nil then
		wkWall = leg
	end
end
-- Task 22's legs have no wall leg: then the wall steps (2 and 3 below) are skipped and the self-check starts from leg 1.
if #wkLegs == 0 or #wkLegs ~= wkData.total then
	return wkStop(`T8bLegs holds {#wkLegs} legs, total says {tostring(wkData.total)}`)
end
local wallLeg: Leg? = wkWall
local wkSelfLeg: Leg = if wallLeg ~= nil then wallLeg else wkLegs[1]
local wkHoldSeconds = if wallLeg ~= nil then wkWallHold else 0

-- A leg never errors (client-a's contract), but a stray error must not kill the whole job.
local wkErr = ""
local function wkRun(leg: Leg): (boolean, string, Vector3, number)
	local ok, pass, reason, endFeet, secs = pcall(runLeg, leg)
	wkErr = if ok then "" else tostring(pass)
	if not ok then
		return false, "ERROR", leg.from, 0
	end
	return pass, reason, endFeet, secs
end

-- 2. Self-check: 1 s of input along the first leg's flat direction (from to to) must move the body at least 5 studs.
-- Leg 1 slopes towards -z, so a fixed -z press can stall (Task 22 Step 3); the leg's own direction is what the bot walks.
local wkSelfDir = Vector3.new(wkSelfLeg.to.X - wkSelfLeg.from.X, 0, wkSelfLeg.to.Z - wkSelfLeg.from.Z)
if wkSelfDir.Magnitude < 5 then
	return wkStop(`INPUT DEAD: the first leg is {string.format("%.1f", wkSelfDir.Magnitude)} studs flat, need 5`)
end
placeBot(wkSelfLeg.from)
task.wait(1.5)
local wkStart = feetNow()
press(wkSelfDir.Unit, 1)
local wkMoved = feetNow() - wkStart
local wkFlat = Vector3.new(wkMoved.X, 0, wkMoved.Z).Magnitude
if wkFlat < 5 then
	return wkStop(string.format("INPUT DEAD: 1 s of Move along the first leg moved %.1f studs flat, need 5", wkFlat))
end
table.insert(wkOut, string.format("self-check ok: %.1f studs in 1 s", wkFlat))

-- 3. Test wall (client-b owns it): the left ramp walk must fail with SLOW. Skipped when there is no wall leg (Task 22).
local wkWallPart: Part? = nil
if wallLeg ~= nil then
	local wkWallNew = Instance.new("Part")
	wkWallNew.Name, wkWallNew.Anchored = "T8bTestWall", true
	wkWallNew.Size, wkWallNew.CFrame = Vector3.new(12, 10, 1), CFrame.new(-24.0, 16.8, -84.5)
	wkWallNew.Parent = game:GetService("Workspace")
	wkWallPart = wkWallNew
	local wkPass, wkReason, wkEnd, wkSecsWall = wkRun(wallLeg)
	local wkWallLine = `wall leg #{wallLeg.n} {wkReason} end {wkFeet(wkEnd)} {math.floor(wkSecsWall * 10) / 10} s`
	if wkPass or wkReason ~= "SLOW" then
		wkWallNew:Destroy()
		return wkStop(`WALL MISSED: must fail SLOW, got pass={tostring(wkPass)}: {wkWallLine} {wkErr}`)
	end
	table.insert(wkOut, wkWallLine .. " (wanted SLOW, ok)")
else
	table.insert(wkOut, "no wall leg: wall test skipped")
end

-- 4. The shared state the fetches read.
local wkNow = os.time()
local wkState: WkState = {
	done = false,
	walked = 0,
	total = #wkLegs,
	heartbeat = 0,
	last = "wall hold",
	letters = {},
	byKind = {},
	fails = {},
	short = {},
	failCount = 0,
	failLegs = {},
	expectedEnd = 0,
	startedAt = wkNow + wkHoldSeconds,
	holds = { wall = { from = wkNow, to = wkNow + wkHoldSeconds } },
}
wkShared.T8bWalk = wkState

-- Seconds left: each kind's average so far, or the first guess (9 per walk, 14 per drop, 6 per step-off).
local function wkLeft(): number
	local left = 0
	for kind, total in wkTotals do
		local done = wkDone[kind] or 0
		local avg = if done > 0 then (wkSecs[kind] or 0) / done else (wkGuess[kind] or 9)
		left += (total - done) * avg
	end
	return left
end

local function wkHold(seconds: number)
	for i = 1, seconds do
		task.wait(1)
		if i % 5 == 0 then
			wkState.heartbeat += 1
		end
	end
end

-- One finished leg: letter by BotLegs number, counts, a fail line (full for 1 to 5, short for 6 to 20), the last line.
local function wkRecord(leg: Leg, pass: boolean, reason: string, endFeet: Vector3, secs: number): boolean
	wkState.walked += 1
	wkState.heartbeat += 1
	wkState.letters[leg.n] = if pass then "P" else "F"
	local kind = wkState.byKind[leg.kind] or { pass = 0, fail = 0 }
	wkState.byKind[leg.kind] = kind
	if pass then
		kind.pass += 1
	else
		kind.fail += 1
		wkState.failCount += 1
		table.insert(wkState.failLegs, leg.n)
		local why = if reason == "ERROR" then reason .. " " .. wkErr else reason
		local head = `#{leg.n} {leg.kind}`
		if wkState.failCount <= 5 then
			table.insert(wkState.fails, `{head} {leg.name} start {wkFeet(leg.from)} end {wkFeet(endFeet)} {why}`)
		elseif wkState.failCount <= 20 then
			table.insert(wkState.short, head .. " start " .. wkFeet(leg.from))
		end
	end
	wkState.last = `{wkState.walked} of {wkState.total}: #{leg.n} {leg.kind} {reason} {math.floor(secs * 10) / 10} s`
	return true
end

-- Fails 1 and 2: walk again, then hold at the end for the shot. The window is in shared before the walk.
local function wkReplay(slot: string, index: number, holdFrom: number)
	local n = wkState.failLegs[index]
	if n == nil then
		return
	end
	local _, reason, endFeet = wkRun(wkByN[n])
	placeBot(endFeet) -- the walk-out left the bot elsewhere; the shot shows the fail's end
	local from = math.max(os.time(), holdFrom)
	wkState.holds[slot] = { from = from, to = from + wkFailHold }
	wkState.last = `replay {slot} #{n} {reason} end {wkFeet(endFeet)}, hold {from} to {from + wkFailHold}`
	task.wait(math.max(0, from - os.time()))
	wkHold(wkFailHold)
end

-- 5. The reply the slot returns now. The hold, the walk and the replay go on in the background.
wkState.expectedEnd = wkState.startedAt + math.ceil(wkLeft())
local wkWalkAt, wkEndAt = wkState.startedAt, wkState.expectedEnd
table.insert(wkOut, `wall hold {wkClock(wkNow)} to {wkClock(wkWalkAt)} UTC (os.time {wkNow} to {wkWalkAt})`)
table.insert(
	wkOut,
	`walk expected end {wkClock(wkEndAt)} UTC (os.time {wkEndAt}), about {math.ceil(wkLeft() / 60)} min`
)

task.spawn(function()
	wkHold(wkHoldSeconds)
	if wkWallPart ~= nil then
		wkWallPart:Destroy()
	end
	for _, leg in wkLegs do
		local t0 = os.clock()
		local pass, reason, endFeet, secs = wkRun(leg)
		wkDone[leg.kind] = (wkDone[leg.kind] or 0) + 1
		wkSecs[leg.kind] = (wkSecs[leg.kind] or 0) + os.clock() - t0
		local okRec, recErr = pcall(wkRecord, leg, pass, reason, endFeet, secs)
		if not okRec then
			wkState.last = string.format("JOB ERROR #%d %s", leg.n, tostring(recErr))
			wkState.letters[leg.n] = wkState.letters[leg.n] or "F"
		end
		wkState.expectedEnd = os.time() + math.ceil(wkLeft())
	end
	wkState.done = true
	wkState.expectedEnd = os.time()
	local waited = 0
	while wkShared.T8bShow ~= true and waited < 3600 do
		task.wait(1)
		waited += 1
	end
	if wkShared.T8bShow == true then
		local t0 = os.time()
		wkReplay("fail1", 1, t0 + 20)
		wkReplay("fail2", 2, t0 + 100)
		wkState.last = "replay finished"
	end
end)

return string.sub(table.concat(wkOut, "\n"), 1, 1000)
