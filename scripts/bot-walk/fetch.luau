--!strict
-- Task 8b fetch: reads shared.T8bWalk. Done: adds the 350 letters (BotLegs order) and sets T8bShow.
-- Fail lines (fails, then short) are paged: each fetch adds the whole lines that fit under 1000 characters.
-- selene: allow(global_usage)
local sh: any = shared
if sh.T8bWalk == nil then
	return "FIRED: shared.T8bWalk missing: slot 4 never ran in this Play"
end
local deadline = os.clock() + 30
while not sh.T8bWalk.done and os.clock() < deadline do
	task.wait(1)
end
local w: any, LIMIT = sh.T8bWalk, 1000
local lines: { string } = {}
for _, group in { w.fails or {}, w.short or {} } do
	for _, line in group do
		table.insert(lines, tostring(line))
	end
end
local kinds: { string } = {}
for _, kind in { "up", "down", "drop", "step" } do
	local k = w.byKind and w.byKind[kind] or { pass = 0, fail = 0 }
	table.insert(kinds, `{kind} {k.pass}/{k.fail}`)
end
local endAt = if w.expectedEnd then os.date("%H:%M:%S", w.expectedEnd) else "?"
local out: { string } = {
	`{if w.done then "done" else "running"} {w.walked}/{w.total} fails {w.failCount} hb {w.heartbeat} end {endAt} (in {(w.expectedEnd or os.time()) - os.time()} s)`,
	table.concat(kinds, " ") .. " pass/fail",
	"last: " .. string.sub(tostring(w.last), 1, 70),
}
local from, more = 1, ""
if w.done then
	local seen: number? = sh.T8bPage
	if seen == nil then
		local runs: { string } = {}
		local current, count = w.letters[1] or "?", 0
		for n = 1, w.total do
			local letter = w.letters[n] or "?"
			if letter ~= current then
				table.insert(runs, current .. count)
				current, count = letter, 0
			end
			count += 1
		end
		table.insert(runs, current .. count)
		table.insert(out, `letters as runs ({w.total}, BotLegs order): {table.concat(runs)}`)
		table.insert(out, "shots: fail 1 at about +50 s, fail 2 at about +130 s from now")
		sh.T8bShow = true
	else
		from = seen
	end
end
local used, nextAt = #table.concat(out, "\n"), from
for i = from, #lines do
	if used + 1 + #lines[i] > LIMIT - 36 or (not w.done and i > 5) then
		break
	end
	table.insert(out, lines[i])
	used += 1 + #lines[i]
	nextAt = i + 1
end
if w.done then
	sh.T8bPage = nextAt
	if nextAt <= #lines then
		more = `\nmore: {#lines - nextAt + 1} fail lines, fetch again`
	end
end
return string.sub(table.concat(out, "\n") .. more, 1, 1000)
