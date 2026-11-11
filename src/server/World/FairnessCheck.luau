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
-- One rank (Rare, Epic, ...) or one pair of nests (the fold, the cuff front pocket): the peak per way up, nil when the
-- way up can't reach it.
export type RankRow = { label: string, ways: { { name: string, footprint: number?, quiet: number? } } }

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
	-- Plan 5 Task 20, Rule 73: no heist to a Rare nest may reach this meter value (it wakes him), on either route.
	RareCeiling = 100,
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
-- are skipped. Any table with a name fits (a WayUpPeaks or a RankRow way).
local function checkGap<T>(into: { string }, ways: { T }, peakOf: (T) -> number?, nameOf: (T) -> string, label: string)
	local lowest: T? = nil
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
		if peak ~= nil and lowest ~= nil and peak - lowestPeak > Limits.GapPoints then
			table.insert(
				into,
				cut(
					`{format(peak - lowestPeak)} points apart (limit {Limits.GapPoints}): {nameOf(way)} at {format(peak)} vs {nameOf(
						lowest
					)} at {format(lowestPeak)} on the {label}`
				)
			)
		end
	end
end

local function wayName(way: WayUpPeaks): string
	return way.name
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
	end, wayName, "footprint Rare")
	checkGap(failures, ways, function(way)
		return way.footprintUncommon
	end, wayName, "footprint Uncommon")
	checkGap(reports, ways, function(way)
		return way.quietRare
	end, wayName, "quietest Rare")
	checkGap(reports, ways, function(way)
		return way.quietUncommon
	end, wayName, "quietest Uncommon")
	checkLadders(reports, ways)

	return { failures = failures, reports = reports, table = table.concat(lines, "\n") }
end

-- Plan 5 Task 20, Rule 73: judges every rank (and the fold and cuff pairs) the way judge does Rare egg 1. A footprint
-- gap over GapPoints fails (naming the rank and both ways up), a way up with no footprint peak fails as can't reach,
-- a quietest-route gap is only reported. One table line per row.
function FairnessCheck.judgeRanks(rows: { RankRow }): Verdict
	local failures: { string } = {}
	local reports: { string } = {}
	local lines: { string } = {}
	local function footprintOf(way: { name: string, footprint: number?, quiet: number? }): number?
		return way.footprint
	end
	local function quietOf(way: { name: string, footprint: number?, quiet: number? }): number?
		return way.quiet
	end
	local function nameOf(way: { name: string, footprint: number?, quiet: number? }): string
		return way.name
	end
	for _, row in rows do
		local parts: { string } = {}
		for _, way in row.ways do
			table.insert(parts, `{way.name} footprint {orDash(way.footprint)} quietest {orDash(way.quiet)}`)
			if way.footprint == nil then
				table.insert(failures, cut(`can't reach: {way.name} footprint {row.label}`))
			end
		end
		table.insert(lines, `{row.label} | {table.concat(parts, " | ")}`)
		checkGap(failures, row.ways, footprintOf, nameOf, `footprint {row.label}`)
		checkGap(reports, row.ways, quietOf, nameOf, `quietest {row.label}`)
	end
	return { failures = failures, reports = reports, table = table.concat(lines, "\n") }
end

-- Plan 5 Task 20, Rule 73: every trip (one Rare nest through one way up on one route) with a peak of RareCeiling or
-- more fails, naming the nest, the way up and the route.
function FairnessCheck.judgeCeiling(trips: { { nest: string, way: string, route: string, peak: number } }): { string }
	local failures: { string } = {}
	for _, trip in trips do
		if trip.peak >= Limits.RareCeiling then
			table.insert(
				failures,
				cut(
					`{format(trip.peak)} reaches {Limits.RareCeiling}: {trip.nest} through {trip.way} on the {trip.route} route`
				)
			)
		end
	end
	return failures
end

return FairnessCheck
