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
		if reach.tiptoePeak >= Config.Ranks.TiptoeLimit then
			table.insert(
				reasons,
				string.format("Tiptoe peak %.1f is at or over the limit %g", reach.tiptoePeak, Config.Ranks.TiptoeLimit)
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

return EggRanks
