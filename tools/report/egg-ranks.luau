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
}
export type ToolInput = {
	options: ReachCheck.Options,
	world: WorldRoot,
	header: EggRanksReport.Header,
	nests: { ToolNest },
}

local function run(input: ToolInput): string
	local rows: { EggRanksReport.ReportRow } = {}
	for _, nest in input.nests do
		local reach = ReachCheck.analyse(input.options, nest.input)
		local seat = NestSeat.measure(input.world, nest.seat)
		local verdict =
			EggRanks.judge({ name = nest.name or "", worldRank = nest.worldRank, reach = reach, seat = seat })
		table.insert(
			rows,
			{ name = nest.name, seatKind = nest.seat.kind, reach = reach, seat = seat, verdict = verdict }
		)
	end
	return EggRanksReport.build(rows, input.header)
end

return { run = run }
