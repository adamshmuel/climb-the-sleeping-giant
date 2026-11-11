--!strict
-- The egg rank report (spec 4 Rules 56 and 57): the text Adam reads to check every nest's rank. Pure: it reads only its
-- arguments and Config. Layout and cell words: work/p4t10/p4t10-tests.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local EggRanks = require(ServerScriptService.Server.World.EggRanks)
local NestSeat = require(ServerScriptService.Server.World.NestSeat)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)

export type Header = { date: string, drain: number, surfaceWords: { [string]: string } }
export type ReportRow = {
	name: string?,
	seatKind: "nest" | "egg",
	reach: ReachCheck.NestResult,
	seat: NestSeat.Result,
	verdict: EggRanks.Verdict,
}

local UNNAMED = "unnamed nest"
local NO_NAME_PROBLEM = "problem: this nest has no name in the world (its NestName label is empty)"
local COLUMNS = {
	"Nest",
	"Score",
	"Rank and colour",
	"Tiptoe peak",
	"Quickest",
	"Slowest",
	"Ladder seconds",
	"Sits on",
	"Note",
}

local EggRanksReport = {}

-- The score as a whole number of percent (66.4 gives "66%").
local function percent(score: number): string
	return `{math.floor(score + 0.5)}%`
end

local function gardenCell(time: ReachCheck.GardenTime?): string
	if time == nil then
		return "none"
	end
	return string.format("garden %d, %.1f s", time.garden, time.seconds)
end

local function sitsOn(row: ReportRow, header: Header): string
	local seat = row.seat
	local surface = "none"
	if seat.surface ~= "" then
		surface = header.surfaceWords[seat.surface] or seat.surface
	end
	local thing = if row.seatKind == "nest" then "nest" else "egg"
	local fit = "flush"
	if seat.gap > 0 then
		fit = string.format("floats %.1f", seat.gap)
	elseif seat.sink > 0 then
		fit = string.format("sinks %.1f", seat.sink)
	end
	local cell = `{surface}, {seat.pose} {thing}, {fit}`
	if row.seatKind == "nest" then
		if seat.eggOffset ~= nil then
			cell ..= string.format("; egg %.1f from the nest's bottom", seat.eggOffset)
		else
			cell ..= "; no egg found"
		end
	end
	return cell
end

local function hasName(row: ReportRow): boolean
	return row.name ~= nil and row.name ~= ""
end

local function noteOf(row: ReportRow): string
	local parts: { string } = {}
	if not hasName(row) then
		table.insert(parts, NO_NAME_PROBLEM)
	end
	local verdict = row.verdict
	if verdict.ok then
		if verdict.close then
			table.insert(parts, "Close to the edge")
		end
	else
		table.insert(parts, table.concat(verdict.reasons, "; "))
	end
	return table.concat(parts, "; ")
end

local function rowLine(row: ReportRow, header: Header): string
	local rank: Config.RarityName = row.verdict.rank
	local cells = {
		if hasName(row) then row.name :: string else UNNAMED,
		percent(row.reach.score),
		`{rank}, {Config.Ranks.ColourWords[rank]}`,
		string.format("%.1f%%", row.reach.tiptoePeak),
		gardenCell(row.reach.quickest),
		gardenCell(row.reach.slowest),
		string.format("%.1f s", row.reach.ladderSeconds),
		sitsOn(row, header),
		noteOf(row),
	}
	return `| {table.concat(cells, " | ")} |`
end

-- The rows from easiest to hardest; equal scores keep their input order.
local function sortedRows(rows: { ReportRow }): { ReportRow }
	local order: { { row: ReportRow, index: number } } = {}
	for index, row in rows do
		table.insert(order, { row = row, index = index })
	end
	table.sort(order, function(a, b)
		if a.row.reach.score ~= b.row.reach.score then
			return a.row.reach.score < b.row.reach.score
		end
		return a.index < b.index
	end)
	local sorted: { ReportRow } = {}
	for _, entry in order do
		table.insert(sorted, entry.row)
	end
	return sorted
end

local function headerLines(header: Header): { string }
	return {
		"Egg rank report",
		`Date: {header.date}`,
		string.format(
			"Solo drain used: %g points a second (how fast the sleep meter falls with one player in the server)",
			header.drain
		),
		"Nest: the name of the nest in the world",
		"Score: the highest the shared sleep meter gets on the quietest trip to the nest and home with its egg, in percent (100% wakes the giant; a meadow nest is 0%). The rank comes from it.",
		"Rank and colour: the rank the score earns, and the colour of its glow",
		string.format(
			"Tiptoe peak: the same trip with Tiptoe on the whole way; %g%% or more fails the nest",
			Config.Ranks.TiptoeLimit
		),
		"Quickest garden: the garden whose player gets to the nest fastest, walking and climbing, and how many seconds it takes",
		"Slowest garden: the garden whose player takes longest to get to the nest, and how many seconds it takes",
		"Ladder seconds: the seconds spent on ladders on the trip",
		"Sits on: what the nest or egg sits on, whether it is upright or leaning, whether it floats or sinks, and for a nest how far its egg is from the nest's bottom (all in studs)",
		"Note: Close to the edge, or why the nest fails",
	}
end

local function rankLine(rank: Config.RarityName, rows: { ReportRow }): string
	local count = 0
	local lowest, highest = math.huge, -math.huge
	for _, row in rows do
		if row.verdict.rank == rank then
			count += 1
			lowest = math.min(lowest, row.reach.score)
			highest = math.max(highest, row.reach.score)
		end
	end
	if count == 0 then
		return `{rank}: no nests`
	end
	local noun = if count == 1 then "nest" else "nests"
	return `{rank}: {count} {noun}, lowest {percent(lowest)}, highest {percent(highest)}`
end

function EggRanksReport.build(rows: { ReportRow }, header: Header): string
	local lines = headerLines(header)
	table.insert(lines, "")
	table.insert(lines, `| {table.concat(COLUMNS, " | ")} |`)
	table.insert(lines, `|{string.rep("---|", #COLUMNS)}`)
	for _, row in sortedRows(rows) do
		table.insert(lines, rowLine(row, header))
	end
	table.insert(lines, "")
	for _, rank: Config.RarityName in Config.RarityOrder do
		table.insert(lines, rankLine(rank, rows))
	end
	return table.concat(lines, "\n")
end

return EggRanksReport
