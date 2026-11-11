--!strict
-- The verdict of each nest (spec 4 Rules 50, 54 and 56): the score sets the rank, and a nest fails when its score
-- is outside the band of the rank it was placed for, when it can't be reached or left with no jump, has no room to
-- stand, floats or sinks, or when its Tiptoe peak is at the limit. Pure code on made-up or measured inputs: nothing
-- here touches the world. Every number is read from Config.Ranks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local NestSeat = require(ServerScriptService.Server.World.NestSeat)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)

export type NestVerdictInput = {
	name: string,
	worldRank: Config.RarityName,
	reach: ReachCheck.NestResult,
	seat: NestSeat.Result,
}
-- One nest for the order and count check: the rank it is meant to have, the score it got and the rank that score
-- earns. A bot-walk nest (scored by Task 22) has no real score yet.
export type OrderRow = {
	name: string,
	worldRank: Config.RarityName,
	score: number,
	scoreRank: Config.RarityName,
	botWalk: boolean?,
}
export type Verdict = { rank: Config.RarityName, band: string, close: boolean, reasons: { string }, ok: boolean }
export type Failure = { name: string, score: number, rank: Config.RarityName, band: string, reasons: { string } }
export type RunResult = { verdicts: { Verdict }, failures: { Failure }, ok: boolean }

local EggRanks = {}

-- The rank a score earns. A meadow nest (no egg used) is Common. A score on an edge takes the higher rank.
local function rankOf(reach: ReachCheck.NestResult): Config.RarityName
	if reach.eggUsed == nil then
		return "Common"
	end
	local edges = Config.Ranks.BandEdges
	if reach.score >= edges.Legendary then
		return "Legendary"
	elseif reach.score >= edges.Epic then
		return "Epic"
	elseif reach.score >= edges.Rare then
		return "Rare"
	end
	return "Uncommon"
end

-- The words for a rank's band, with the numbers read from Config.Ranks.BandEdges.
local function bandText(rank: Config.RarityName): string
	local edges = Config.Ranks.BandEdges
	if rank == "Common" then
		return "0, in the meadow"
	elseif rank == "Uncommon" then
		return string.format("under %g", edges.Rare)
	elseif rank == "Rare" then
		return string.format("%g to %g", edges.Rare, edges.Epic)
	elseif rank == "Epic" then
		return string.format("%g to %g", edges.Epic, edges.Legendary)
	end
	return string.format("%g and over", edges.Legendary)
end

-- True when the score is within EdgeWarning of any edge, above or below it. Never for a Common nest.
local function isClose(rank: Config.RarityName, score: number): boolean
	if rank == "Common" then
		return false
	end
	local edges = Config.Ranks.BandEdges
	local warning = Config.Ranks.EdgeWarning
	return math.abs(score - edges.Rare) <= warning
		or math.abs(score - edges.Epic) <= warning
		or math.abs(score - edges.Legendary) <= warning
end

-- The Tiptoe limit for a nest of this world rank: Legendary nests have their own, higher one (Rule 54).
local function tiptoeLimitFor(worldRank: Config.RarityName): number
	if worldRank == "Legendary" then
		return Config.Ranks.TiptoeLimitLegendary
	end
	return Config.Ranks.TiptoeLimit
end

-- A NestSeat reason in the words the report uses; an unknown one is copied as it is.
local function seatReason(text: string): string
	if string.sub(text, 1, 3) == "gap" then
		return `floats: {text}`
	elseif string.sub(text, 1, 4) == "sink" then
		return `sinks: {text}`
	elseif text == "no surface" then
		return "no visible surface under it"
	elseif string.sub(text, 1, 3) == "egg" then
		return `egg out of its nest: {text}`
	end
	return text
end

function EggRanks.judge(input: NestVerdictInput): Verdict
	local reach = input.reach
	local rank: Config.RarityName = rankOf(reach)
	local reasons: { string } = {}
	local reachable = reach.reached and reach.left and reach.roomToStand
	local close = reachable and isClose(rank, reach.score)
	if not reach.reached then
		table.insert(reasons, "can't be reached with no jump")
	end
	if not reach.left then
		table.insert(reasons, "can't be left with no jump")
	end
	if not reach.roomToStand then
		table.insert(reasons, "no room to stand")
	end
	for _, text in input.seat.reasons do
		table.insert(reasons, seatReason(text))
	end
	-- An unreached nest has no real score, so no band or Tiptoe reason is added for it.
	if reachable then
		if rank ~= input.worldRank then
			table.insert(
				reasons,
				string.format(
					"score %.1f is outside %s, band %s (it is %s)",
					reach.score,
					input.worldRank,
					bandText(input.worldRank),
					rank
				)
			)
		end
		local tiptoeLimit = tiptoeLimitFor(input.worldRank)
		if reach.tiptoePeak >= tiptoeLimit then
			table.insert(
				reasons,
				string.format("Tiptoe peak %.1f is at or over the limit %g", reach.tiptoePeak, tiptoeLimit)
			)
		end
	end
	return {
		rank = rank,
		band = bandText(input.worldRank),
		close = close,
		reasons = reasons,
		ok = #reasons == 0,
	}
end

function EggRanks.run(inputs: { NestVerdictInput }): RunResult
	local result: RunResult = { verdicts = {}, failures = {}, ok = true }
	for _, input in inputs do
		local verdict = EggRanks.judge(input)
		table.insert(result.verdicts, verdict)
		if not verdict.ok then
			result.ok = false
			table.insert(result.failures, {
				name = input.name,
				score = input.reach.score,
				rank = verdict.rank,
				band = verdict.band,
				reasons = verdict.reasons,
			})
		end
	end
	return result
end

-- The nest with the lowest (or highest) score among the rows that pass `keep`; nil when none does.
local function extreme(rows: { OrderRow }, keep: (OrderRow) -> boolean, wantHighest: boolean): OrderRow?
	local best: OrderRow? = nil
	for _, row in rows do
		if keep(row) and (best == nil or (if wantHighest then row.score > best.score else row.score < best.score)) then
			best = row
		end
	end
	return best
end

-- The problems in the order and count of every nest, in plain words, sorted. Empty when all is well: every nest has
-- a name; each rank has Config.Rarity[rank].Nests nests at its world rank (Rule 71); every Uncommon nest scores
-- under every Rare nest; every "Cap " nest scores at least as high as every "Beard " nest. A bot-walk nest counts at
-- its world rank but is left out of both score comparisons.
function EggRanks.rankOrder(rows: { OrderRow }): { string }
	local problems: { string } = {}
	local counts: { [string]: number } = {}
	for _, row in rows do
		if row.name == "" then
			table.insert(problems, "a nest has no name")
		end
		counts[row.worldRank] = (counts[row.worldRank] or 0) + 1
	end
	for _, rank in Config.RarityOrder do
		local have = counts[rank] or 0
		local want = Config.Rarity[rank].Nests
		if have ~= want then
			table.insert(problems, string.format("%s has %d nests, expected %d", rank, have, want))
		end
	end
	local function scored(row: OrderRow): boolean
		return row.botWalk ~= true
	end
	local topUncommon = extreme(rows, function(row)
		return scored(row) and row.worldRank == "Uncommon"
	end, true)
	local lowRare = extreme(rows, function(row)
		return scored(row) and row.worldRank == "Rare"
	end, false)
	if topUncommon ~= nil and lowRare ~= nil and topUncommon.score > lowRare.score then
		table.insert(
			problems,
			string.format(
				"Uncommon nest %s scores %.1f, above Rare nest %s at %.1f (every Uncommon nest must be easier than every Rare nest)",
				topUncommon.name,
				topUncommon.score,
				lowRare.name,
				lowRare.score
			)
		)
	end
	local lowCap = extreme(rows, function(row)
		return scored(row) and string.sub(row.name, 1, 4) == "Cap "
	end, false)
	local topBeard = extreme(rows, function(row)
		return scored(row) and string.sub(row.name, 1, 6) == "Beard "
	end, true)
	if lowCap ~= nil and topBeard ~= nil and lowCap.score < topBeard.score then
		table.insert(
			problems,
			string.format(
				"Cap nest %s scores %.1f, under Beard nest %s at %.1f (every cap nest must be at least as hard as every beard nest)",
				lowCap.name,
				lowCap.score,
				topBeard.name,
				topBeard.score
			)
		)
	end
	table.sort(problems)
	return problems
end

return EggRanks
