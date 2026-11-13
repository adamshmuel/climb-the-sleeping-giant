--!strict
-- The egg rank report tool (spec 4 Rule 57): measures each nest and returns the report text.
-- It reads only its input: the caller builds the nest list from the world.
local ServerScriptService = game:GetService("ServerScriptService")

local EggRanks = require(ServerScriptService.Server.World.EggRanks)
local EggRanksReport = require(ServerScriptService.Server.World.EggRanksReport)
local NestSeat = require(ServerScriptService.Server.World.NestSeat)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type ToolNest = {
	name: string?,
	input: ReachCheck.NestInput,
	worldRank: Config.RarityName,
	seat: NestSeat.Seat,
	botWalk: boolean?,
}
export type ToolInput = {
	options: ReachCheck.Options,
	world: WorldRoot,
	header: EggRanksReport.Header,
	nests: { ToolNest },
}

-- Measures every nest (ReachCheck.analyseAll makes the searches once) and returns the report text, the rank run's result
-- (its failure list) and the report rows (each nest's reach, seat and verdict, in input order).
local function check(input: ToolInput): (string, EggRanks.RunResult, { EggRanksReport.ReportRow })
	local nestInputs: { ReachCheck.NestInput } = {}
	for _, nest in input.nests do
		table.insert(nestInputs, nest.input)
	end
	local reaches = ReachCheck.analyseAll(input.options, nestInputs)
	local seats: { NestSeat.Result } = {}
	local verdictInputs: { EggRanks.NestVerdictInput } = {}
	for index, nest in input.nests do
		seats[index] = NestSeat.measure(input.world, nest.seat)
		verdictInputs[index] =
			{ name = nest.name or "", worldRank = nest.worldRank, reach = reaches[index], seat = seats[index] }
	end
	local result = EggRanks.run(verdictInputs)
	local rows: { EggRanksReport.ReportRow } = {}
	local orderRows: { EggRanks.OrderRow } = {}
	for index, nest in input.nests do
		rows[index] = {
			name = nest.name,
			seatKind = nest.seat.kind,
			reach = reaches[index],
			seat = seats[index],
			verdict = result.verdicts[index],
			botWalk = nest.botWalk,
			worldRank = nest.worldRank,
		}
		orderRows[index] = {
			name = nest.name or "",
			worldRank = nest.worldRank,
			score = reaches[index].score,
			scoreRank = result.verdicts[index].rank,
			botWalk = nest.botWalk,
		}
	end
	local header: EggRanksReport.Header = {
		date = input.header.date,
		drain = input.header.drain,
		surfaceWords = input.header.surfaceWords,
		order = EggRanks.rankOrder(orderRows),
	}
	return EggRanksReport.build(rows, header), result, rows
end

local function run(input: ToolInput): string
	local text = check(input)
	return text
end

return { run = run, check = check }
