--!strict
-- Task 8c (Client, Play): re-walks the legs in LEGS, one full line each (Rule 24: A bot walks every way).
-- Pasted joined after client-a.luau. The first paste starts the run in the background and returns at once
--; pasting again only reads: "running k of n", then every line and the shot windows (shots only if RW_SHOTS > 0).
-- Each line has reason, end feet, part under them, speed, note ("climbed" for drops). The
-- task's close clears shared.T8cRewalk and shared.T8cShow.
local LEGS = { 144, 147, 178, 279, 347 }
-- selene: allow(global_usage)
local rwShared: any = shared
local rwRequire: (Instance) -> any = require :: any
local RW_GUESS, RW_SLOT, RW_WALK, RW_HOLD, RW_SHOTS = 22, 90, 40, 45, 0 -- s per leg, per shot, to walk, to hold; shots (none in step 4)
local RW_BEARD = Vector3.new(-11, 82.8, -9.2) -- #178's known beard wedge

local function rwClock(t: number): string
	return DateTime.fromUnixTimestamp(t):FormatUniversalTime("HH:mm:ss", "en-us")
end

-- 1. Load the two items; a missing one is a lost input, so the paste stops.
local rwRS = game:GetService("ReplicatedStorage")
local rwValue, rwModule = rwRS:WaitForChild("T8bLegs", 10), rwRS:WaitForChild("T8bBotWalk", 10)
if rwValue == nil or rwModule == nil then
	return "FIRED load (lost input): T8bLegs or T8bBotWalk missing in ReplicatedStorage; was Play restarted?"
end
BotWalk = rwRequire(rwModule)
local rwByN: { [number]: Leg } = {}
for _, raw in game:GetService("HttpService"):JSONDecode((rwValue :: StringValue).Value).legs do
	local leg: any = { n = raw.n, kind = raw.kind, name = raw.name, onHim = raw.onHim, open = raw.open }
	leg.how, leg.ladder = raw.how, raw.ladder
	for _, key in { "from", "to", "foot", "top", "away" } do
		leg[key] = if raw[key] then Vector3.new(raw[key][1], raw[key][2], raw[key][3]) else nil
	end
	rwByN[raw.n] = leg :: Leg
end

-- The part under the feet (full path): a down-ray from 2 studs above to 6 below; if it misses, 4 more from 1 stud
-- north, east, south and west of the feet. Says which ray hit, or "none".
local function rwUnder(feet: Vector3): string
	local _, root = bot()
	rayParams.FilterDescendantsInstances = { root.Parent :: Instance }
	local rays: { { any } } = {
		{ "centre", ZERO },
		{ "north", Vector3.zAxis },
		{ "east", Vector3.xAxis },
		{ "south", -Vector3.zAxis },
		{ "west", -Vector3.xAxis },
	}
	for _, ray in rays do
		local from = feet + (ray[2] :: Vector3) + Vector3.new(0, 2, 0)
		local hit = Workspace:Raycast(from, Vector3.new(0, -8, 0), rayParams)
		if hit then
			return `{hit.Instance:GetFullName()} ({ray[1]} ray)`
		end
	end
	return "none (5 rays)"
end

-- The #347 escape: never placeBot (a hang has no floor); press from where the body really is. Got out = AWAY studs.
local function rwEscape(leg: Leg, endFeet: Vector3): (boolean, string, { number })
	local away = leg.away :: Vector3
	local plan: { { any } } = { { "toward", -away, false }, { "away", away, false } }
	for _, name in BotWalk.TRIES do
		table.insert(plan, { name, PUSH_DIRECTIONS[name] or ZERO, name == "jump" })
	end
	local parts: { string }, distances: { number } = {}, {}
	for _, try in plan do
		press(try[2], PUSH_SECONDS, try[3])
		task.wait(SETTLE_SECONDS)
		local distance = (feetNow() - endFeet).Magnitude
		table.insert(parts, string.format("%s %.1f", try[1], distance))
		table.insert(distances, distance)
		if distance >= BotWalk.AWAY then
			return true, "escape got out: " .. table.concat(parts, ", "), distances
		end
	end
	return false, "escape FAILED: " .. table.concat(parts, ", "), distances
end

-- 2. The run, in the background. Each line is kept in shared and printed as it ends.
local function rwLeg(state: any, n: number): string
	local leg = rwByN[n]
	local text = `#{n} FIRED: no such leg in T8bLegs (lost input)`
	if leg ~= nil then
		local pass, reason, endFeet, secs = runLeg(leg)
		local floor = ended.floor -- read at the leg's end, before any walk-out
		local judged = ""
		if n == 347 then -- a ladder drop: judged by its escape (product's ruling)
			state.escape = "escape not run: #347 gave " .. reason
			if reason == "NO_GRAB" then
				local ok, gotOut, escText, distances = pcall(rwEscape, leg, endFeet)
				state.escapeFailed = not (ok and gotOut)
				state.escape = if ok then escText else "escape ERROR: " .. tostring(gotOut)
				pass, reason = BotWalk.judgeGrab(ended.climbed, if ok then distances else {})
				judged = " (judged by the escape)"
			end
			print("T8c " .. state.escape)
		end
		local who = `#{n} {leg.kind} {leg.name}: {if pass then "PASS" else "FAIL"} {reason}{judged}`
		local feet = string.format("%.1f, %.1f, %.1f", endFeet.X, endFeet.Y, endFeet.Z)
		local at = `end ({feet}) under {rwUnder(endFeet)}, speed {string.format("%.1f", ended.speed)}`
		text = `{who} {at}{if pass then "" else ", floor " .. floor}, {string.format("%.1f", secs)} s,{note}`
		table.insert(state.results, { n = n, reason = reason, endFeet = endFeet })
	end
	table.insert(state.lines, text)
	print("T8c " .. text)
	return text
end

-- A leg that errors prints its own line and the run goes on; done is always set.
local function rwRun(state: any)
	for _, n in LEGS do
		local ok, err = pcall(rwLeg, state, n)
		if not ok then
			local text = `#{n} FIRED run error: {tostring(err)}`
			table.insert(state.lines, text)
			print("T8c " .. text)
		end
	end
	state.done = true
end

-- 3. Shot candidates, in order: the failed escape, WEDGED ends (not the beard wedge), unknown kinds. The first 5 get shots.
local function rwShots(state: any): { { any } }
	local shots: { { any } } = if state.escapeFailed then { { 347, "escape failed", true } } else {}
	local known = { OK = true, NO_LANDING = true, ERROR = true, WEDGED = true }
	for pass = 1, 2 do
		for _, r in state.results do
			local beard = r.n == 178 and (r.endFeet - RW_BEARD).Magnitude <= 3
			local pick = if pass == 1 then r.reason == "WEDGED" and not beard else not known[r.reason]
			if pick then
				table.insert(shots, { r.n, r.reason, false })
			end
		end
	end
	return shots
end

-- Walks each shot leg again and holds 45 s inside its printed window.
local function rwReplay(shots: { { any } }, t0: number)
	for index, shot in shots do
		local leg = rwByN[shot[1]]
		local _, _, endFeet = runLeg(leg)
		if shot[3] then
			pcall(rwEscape, leg, endFeet)
		else
			placeBot(endFeet) -- the walk-out left the bot elsewhere; the shot shows the fail's end
		end
		task.wait(math.max(0, t0 + (index - 1) * RW_SLOT + RW_WALK - os.time()))
		task.wait(RW_HOLD)
	end
end

local state: any = rwShared.T8cRewalk
if state == nil then
	state = { done = false, shown = false, lines = {}, results = {}, escape = "", escapeFailed = false }
	state.expectedEnd = os.time() + #LEGS * RW_GUESS + 25
	rwShared.T8cRewalk = state
	task.spawn(rwRun, state)
	return `started {#LEGS} legs, expected end {rwClock(state.expectedEnd)} UTC (os.time {state.expectedEnd})`
elseif not state.done then
	return `running {#state.lines} of {#LEGS}, expected end {rwClock(state.expectedEnd)} UTC; last: {state.lines[#state.lines]}`
end
local rwOut = table.move(state.lines, 1, #state.lines, 2, { `done: {#state.results} legs walked; {state.escape}` })
local rwAll, rwT0 = rwShots(state), os.time()
local rwPlan = table.move(rwAll, 1, RW_SHOTS, 1, {})
for index, shot in rwPlan do
	local from = rwT0 + (index - 1) * RW_SLOT + RW_WALK
	local window = `hold {rwClock(from)} to {rwClock(from + RW_HOLD)} UTC (os.time {from} to {from + RW_HOLD})`
	table.insert(rwOut, `shot {index} #{shot[1]} {shot[2]}: {window}`)
end
for index = RW_SHOTS + 1, #rwAll do
	table.insert(rwOut, `NO SHOT (limit {RW_SHOTS}, to product): #{rwAll[index][1]} {rwAll[index][2]}`)
end
if not state.shown then
	state.shown = true
	rwShared.T8cShow = true
	task.spawn(rwReplay, rwPlan, rwT0)
end
return table.concat(rwOut, "\n")
