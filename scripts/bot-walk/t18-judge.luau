--!strict
-- Plan 3 Task 18, Step 1 (work/p3t18/t18-card.md): the judge and the fetch for t18-tries. Paste it in the CLIENT (shared.T18Tries
-- lives there). It waits up to 30 s for shared.T18Tries.done, then judges every end:
--   S rows (Check D2, "he stops at a guard and walks back"): the feet end on legs_and_boots, TopPad, Terrain or a plank Deck,
--      never above y 34 (BELLY_Y), and the end is within 6 studs (flat) of the start or on the plank Deck.
--   J rows (Check D4): landed, the part under the feet is not a ramp part (chain holds BellyRamp_Left, BellyRamp_Right or
--      T18TestRamp) and the feet are not on the belly (end y at most 34).
--   X row (the fail proof): judged like a J row; it must print FAIL because the part under it is T18TestRamp. It is left
--      out of the real pass count. "X fired: yes" is the proof the fail line works.
-- Names come from the Edit read of 2026-11-12: Workspace.World.WalkSurfaces.BellyRamp_Left and BellyRamp_Right (models; their
-- parts are Piece*, Fill*, Board_*, Post_* and Rope_*), LapPlank_Left/_Right.Deck, legs_and_boots, TopPad.
-- Output (cut at 1000 characters): a status line, the counts, the FAIL lines, the closest J case and the X line.
local CHECK_ONLY = false

-- selene: allow(global_usage)
local store = shared :: any

type End = {
	label: string,
	kind: string,
	sx: number,
	sz: number,
	ex: number,
	ey: number,
	ez: number,
	maxY: number,
	landed: boolean,
	chain: string,
}
type State = { lines: { string }, ends: { End }, done: boolean, error: string }

local BELLY_Y, BACK_FLAT = 34, 6
local RAMP_NAMES = { "BellyRamp_Left", "BellyRamp_Right", "T18TestRamp" }
local GROUND_NAMES = { "legs_and_boots", "TopPad", "Terrain", "Deck" }

local function chainHas(chain: string, names: { string }): boolean
	for _, name in names do
		-- plain find, the chain is "part < parent < ..."
		if string.find(chain, name, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function firstName(chain: string): string
	local first = string.match(chain, "^(.-) <")
	return first or chain
end

-- Returns the fail reason, or "" for a pass.
local function judgeEnd(e: End): string
	local flat = Vector3.new(e.ex - e.sx, 0, e.ez - e.sz).Magnitude
	if e.chain == "NOGROUND" or e.chain == "nothing" then
		return `no ground ({e.chain})`
	end
	if not e.landed then
		return "NOLAND"
	end
	if e.ey > BELLY_Y then
		return `end y {string.format("%.1f", e.ey)} above {BELLY_Y} (belly)`
	end
	if e.kind == "S" then
		local first = firstName(e.chain)
		if not table.find(GROUND_NAMES, first) then
			return `S ends on {first}, not boots, meadow or plank`
		end
		if first ~= "Deck" and flat > BACK_FLAT then
			return `S ends {string.format("%.1f", flat)} flat from the start (limit {BACK_FLAT})`
		end
		if e.maxY > BELLY_Y then
			return `S climbed to y {string.format("%.1f", e.maxY)}`
		end
		return ""
	end
	if chainHas(e.chain, RAMP_NAMES) then
		return `landed on a ramp part: {e.chain}`
	end
	return ""
end

local function job(): string
	local state = store.T18Tries :: State?
	if CHECK_ONLY then
		return "CHECK_ONLY: nothing read"
	end
	if state == nil then
		return "STOP: paste t18-tries first (shared.T18Tries missing)"
	end
	local deadline = os.clock() + 30
	while not state.done and os.clock() < deadline do
		task.wait(1)
	end
	local sPass, sTotal, jPass, jTotal = 0, 0, 0, 0
	local fails: { string } = {}
	local xLine = "X: not run yet"
	local maxJy, maxJlabel = -math.huge, "-"
	for _, e in state.ends do
		local reason = judgeEnd(e)
		if e.kind == "X" then
			xLine =
				`X {e.label}: {if reason ~= "" then "FAIL (expected)" else "PASS (the fail line did NOT fire)"} {reason} | {e.chain}`
		elseif e.kind == "S" then
			sTotal += 1
			sPass += if reason == "" then 1 else 0
		else
			jTotal += 1
			jPass += if reason == "" then 1 else 0
			if e.ey > maxJy then
				maxJy, maxJlabel = e.ey, e.label
			end
		end
		if reason ~= "" and e.kind ~= "X" then
			table.insert(
				fails,
				`FAIL {e.label} start {string.format("%.1f, %.1f", e.sx, e.sz)} end {string.format(
					"%.1f, %.1f, %.1f",
					e.ex,
					e.ey,
					e.ez
				)}: {reason}`
			)
		end
	end
	local out: { string } = {
		`{if state.done then "done" else "running (fetch again)"} {#state.ends} of 23 ends error "{state.error}"`,
		`S {sPass}/{sTotal} J {jPass}/{jTotal} (X not counted)`,
		`closest J: {maxJlabel} end y {string.format("%.1f", maxJy)} (limit {BELLY_Y})`,
		xLine,
	}
	for _, line in fails do
		table.insert(out, line)
	end
	return string.sub(table.concat(out, "\n"), 1, 1000)
end

return job()
