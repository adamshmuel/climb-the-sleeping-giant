--!strict
-- Spec 3, Rule 41 (Every way up is equally loud): judges the peaks of every way up. Pure maths on numbers: the search,
-- the link costs and the replay stay in ReachCheck and HeistScore. All failures are listed at once; a message starts
-- with its numbers and stays within 150 characters (a run report keeps only that much, luau.md).

export type WayUpPeaks = {
	name: string,
	gardens: { number },
	isLadder: boolean,
	quietRare: number?,
	footprintRare: number?,
	quietUncommon: number?,
	footprintUncommon: number?,
}
export type Verdict = { failures: { string }, reports: { string }, table: string }

-- Rule 41's numbers.
local Limits = {
	-- Two ways up may differ by at most this many points on the footprint route (Rare egg 1 and the Uncommon nests).
	-- The same gap on the quietest routes is only reported.
	GapPoints = 5,
	-- A Rare route's peak must lie inside this window, on the quietest route and on the footprint route.
	WindowMin = 60,
	WindowMax = 80,
	-- Rare egg 1 over this is reported (the meter's drain decides the pace), not failed.
	DrainTrigger = 77,
	-- Every ladder more than this from the ramps' mean is reported, not failed.
	LadderTrigger = 3,
}

local MESSAGE_LIMIT = 150

local FairnessCheck = {}
FairnessCheck.Limits = Limits

local function format(value: number): string
	return string.format("%.1f", value)
end

local function cut(text: string): string
	return string.sub(text, 1, MESSAGE_LIMIT)
end

local function gardensText(way: WayUpPeaks): string
	local parts: { string } = {}
	for _, garden in way.gardens do
		table.insert(parts, tostring(garden))
	end
	return table.concat(parts, ",")
end

local function orDash(value: number?): string
	if value == nil then
		return "-"
	end
	return format(value)
end

-- One Rare peak against the window: a nil peak can't be reached, a peak outside the window fails.
local function checkWindow(failures: { string }, way: WayUpPeaks, peak: number?, label: string)
	if peak == nil then
		table.insert(failures, cut(`can't reach: {way.name} {label}`))
	elseif peak < Limits.WindowMin or peak > Limits.WindowMax then
		table.insert(
			failures,
			cut(`{format(peak)} is outside {Limits.WindowMin} to {Limits.WindowMax}: {way.name} {label}`)
		)
	end
end

-- Every way whose peak is more than GapPoints above the lowest way's is added to `into`, naming both. Ways with no peak
-- are skipped.
local function checkGap(into: { string }, ways: { WayUpPeaks }, peakOf: (WayUpPeaks) -> number?, label: string)
	local lowest: WayUpPeaks? = nil
	local lowestPeak = math.huge
	for _, way in ways do
		local peak = peakOf(way)
		if peak ~= nil and peak < lowestPeak then
			lowest, lowestPeak = way, peak
		end
	end
	if lowest == nil then
		return
	end
	for _, way in ways do
		local peak = peakOf(way)
		if peak ~= nil and peak - lowestPeak > Limits.GapPoints then
			table.insert(
				into,
				cut(
					`{format(peak - lowestPeak)} points apart (limit {Limits.GapPoints}): {way.name} at {format(peak)} vs {lowest.name} at {format(
						lowestPeak
					)} on the {label}`
				)
			)
		end
	end
end

local function checkLadders(reports: { string }, ways: { WayUpPeaks })
	local rampTotal, rampCount = 0, 0
	for _, way in ways do
		if not way.isLadder and way.quietRare ~= nil then
			rampTotal += way.quietRare
			rampCount += 1
		end
	end
	if rampCount == 0 then
		return
	end
	local rampMean = rampTotal / rampCount
	local ladders: { string } = {}
	local nearest = math.huge
	for _, way in ways do
		if way.isLadder and way.quietRare ~= nil then
			table.insert(ladders, way.name)
			nearest = math.min(nearest, math.abs(way.quietRare - rampMean))
		end
	end
	if #ladders > 0 and nearest > Limits.LadderTrigger then
		table.insert(
			reports,
			cut(
				`{format(nearest)} points: every ladder is over {Limits.LadderTrigger} from the ramps' {format(rampMean)} ({table.concat(
					ladders,
					", "
				)})`
			)
		)
	end
end

-- Judges the ways up: failures (footprint gap, window, can't reach), reports (quietest gap, not failures) and a table
-- of one line per way.
function FairnessCheck.judge(ways: { WayUpPeaks }): Verdict
	local failures: { string } = {}
	local reports: { string } = {}
	local lines: { string } = {}

	for _, way in ways do
		table.insert(
			lines,
			`gardens {gardensText(way)} | {way.name} | quietest Rare {orDash(way.quietRare)} | footprint Rare {orDash(
				way.footprintRare
			)} | quietest Uncommon {orDash(way.quietUncommon)} | footprint Uncommon {orDash(way.footprintUncommon)}`
		)
		checkWindow(failures, way, way.quietRare, "quietest Rare")
		checkWindow(failures, way, way.footprintRare, "footprint Rare")
		if way.quietUncommon == nil then
			table.insert(failures, cut(`can't reach: {way.name} quietest Uncommon`))
		end
		if way.footprintUncommon == nil then
			table.insert(failures, cut(`can't reach: {way.name} footprint Uncommon`))
		end
		local quiet = way.quietRare
		if quiet ~= nil then
			if quiet > Limits.DrainTrigger then
				table.insert(
					reports,
					cut(`{format(quiet)} is over {Limits.DrainTrigger}: {way.name} Rare egg 1 (the drain decides)`)
				)
			end
		end
	end
	checkGap(failures, ways, function(way)
		return way.footprintRare
	end, "footprint Rare")
	checkGap(failures, ways, function(way)
		return way.footprintUncommon
	end, "footprint Uncommon")
	checkGap(reports, ways, function(way)
		return way.quietRare
	end, "quietest Rare")
	checkGap(reports, ways, function(way)
		return way.quietUncommon
	end, "quietest Uncommon")
	checkLadders(reports, ways)

	return { failures = failures, reports = reports, table = table.concat(lines, "\n") }
end

return FairnessCheck
