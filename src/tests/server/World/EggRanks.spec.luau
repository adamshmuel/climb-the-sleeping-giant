--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local EggRanks = require(ServerScriptService.Server.World.EggRanks)

-- The verdict of each nest (spec 4 Rules 50, 54 and 56) on made-up inputs: no world, no walk map. A helper builds a
-- good Rare nest and each test changes the fields it is about.
describe("EggRanks", function()
	local function nestWith(
		score: number,
		eggUsed: Config.RarityName?,
		worldRank: Config.RarityName
	): EggRanks.NestVerdictInput
		return {
			name = "Nest_Test",
			worldRank = worldRank,
			reach = {
				name = "Nest_Test",
				roomToStand = true,
				reached = true,
				left = true,
				score = score,
				eggUsed = eggUsed,
				tiptoePeak = 0,
				ladderSeconds = 0,
			},
			seat = { ok = true, surface = "Floor", pose = "upright", gap = 0, sink = 0, reasons = {} },
		}
	end

	local function goodRare(): EggRanks.NestVerdictInput
		return nestWith(70, "Rare", "Rare")
	end

	it("sets the rank from the score, and an edge takes the higher rank", function()
		local cases: { { score: number, eggUsed: Config.RarityName?, rank: Config.RarityName } } = {
			{ score = 0, eggUsed = nil, rank = "Common" },
			{ score = 39.9, eggUsed = "Uncommon", rank = "Uncommon" },
			{ score = 40.0, eggUsed = "Uncommon", rank = "Rare" },
			{ score = 84.9, eggUsed = "Uncommon", rank = "Rare" },
			{ score = 85.0, eggUsed = "Uncommon", rank = "Epic" },
			{ score = 129.9, eggUsed = "Uncommon", rank = "Epic" },
			{ score = 130.0, eggUsed = "Uncommon", rank = "Legendary" },
		}
		for _, case in cases do
			local verdict = EggRanks.judge(nestWith(case.score, case.eggUsed, "Rare"))
			expect(`{case.score}: {verdict.rank}`).toBe(`{case.score}: {case.rank}`)
		end
	end)

	it("flags a close call within 3 of an edge, above or below, but never a Common nest", function()
		for _, score in { 85.0, 87.5, 83.0, 82.0, 127.0, 40.0 } do
			expect(`{score}: {EggRanks.judge(nestWith(score, "Rare", "Rare")).close}`).toBe(`{score}: true`)
		end
		for _, score in { 88.1, 81.9, 5 } do
			expect(`{score}: {EggRanks.judge(nestWith(score, "Rare", "Rare")).close}`).toBe(`{score}: false`)
		end
		expect(EggRanks.judge(nestWith(0, nil, "Common")).close).toBe(false)
	end)

	it("fails a nest whose score is outside the band of its world rank (Story C), and passes an edge", function()
		local wrong = EggRanks.judge(nestWith(88, "Rare", "Rare"))
		expect(wrong.ok).toBe(false)
		expect(wrong.rank).toBe("Epic")
		expect(wrong.band).toBe("40 to 85")
		expect(wrong.reasons).toEqual({ "score 88.0 is outside Rare, band 40 to 85 (it is Epic)" })
		local edge = EggRanks.judge(nestWith(40.0, "Rare", "Rare"))
		expect(edge.ok).toBe(true)
		expect(edge.rank).toBe("Rare")
		local mid = EggRanks.judge(goodRare())
		expect(mid.ok).toBe(true)
		expect(mid.reasons).toEqual({})
		expect(mid.close).toBe(false)
	end)

	it("fails a Tiptoe peak at the limit and passes one just under it", function()
		local atLimit = goodRare()
		atLimit.reach.tiptoePeak = 60.0
		local failing = EggRanks.judge(atLimit)
		expect(failing.ok).toBe(false)
		expect(failing.reasons).toEqual({ "Tiptoe peak 60.0 is at or over the limit 60" })
		local under = goodRare()
		under.reach.tiptoePeak = 59.9
		expect(EggRanks.judge(under).ok).toBe(true)
	end)

	it("lists only the reach reason for a nest that is not reached, not left or has no room", function()
		local unreached = goodRare()
		unreached.reach.reached = false
		unreached.reach.score = 0
		unreached.reach.eggUsed = nil
		local a = EggRanks.judge(unreached)
		expect(a.ok).toBe(false)
		expect(a.reasons).toEqual({ "can't be reached with no jump" })
		expect(a.close).toBe(false)
		local stuck = goodRare()
		stuck.reach.left = false
		expect(EggRanks.judge(stuck).reasons).toEqual({ "can't be left with no jump" })
		local crowded = goodRare()
		crowded.reach.roomToStand = false
		expect(EggRanks.judge(crowded).reasons).toEqual({ "no room to stand" })
	end)

	it("turns each seat reason into its words, one line per reason", function()
		local function withSeat(reasons: { string }): { string }
			local input = goodRare()
			input.seat.ok = false
			input.seat.reasons = reasons
			return EggRanks.judge(input).reasons
		end
		expect(withSeat({ "gap 0.3" })).toEqual({ "floats: gap 0.3" })
		expect(withSeat({ "sink 0.4" })).toEqual({ "sinks: sink 0.4" })
		expect(withSeat({ "no surface" })).toEqual({ "no visible surface under it" })
		expect(withSeat({ "egg 0.35 from nest bottom" })).toEqual({ "egg out of its nest: egg 0.35 from nest bottom" })
		expect(withSeat({ "gap 0.3", "egg 0.35 from nest bottom" })).toEqual({
			"floats: gap 0.3",
			"egg out of its nest: egg 0.35 from nest bottom",
		})
	end)

	it("run gives one verdict per nest and the failures in input order", function()
		local band = nestWith(88, "Rare", "Rare")
		band.name = "Nest_Band"
		local float = goodRare()
		float.name = "Nest_Float"
		float.seat.reasons = { "gap 0.3" }
		local unreached = goodRare()
		unreached.name = "Nest_Unreached"
		unreached.reach.reached = false
		unreached.reach.score = 0
		unreached.reach.eggUsed = nil
		local good = goodRare()
		good.name = "Nest_Good"
		local result = EggRanks.run({ good, band, float, unreached })
		expect(result.ok).toBe(false)
		expect(#result.verdicts).toBe(4)
		expect(result.failures).toEqual({
			{
				name = "Nest_Band",
				score = 88,
				rank = "Epic",
				band = "40 to 85",
				reasons = { "score 88.0 is outside Rare, band 40 to 85 (it is Epic)" },
			},
			{ name = "Nest_Float", score = 70, rank = "Rare", band = "40 to 85", reasons = { "floats: gap 0.3" } },
			{
				name = "Nest_Unreached",
				score = 0,
				rank = "Common",
				band = "40 to 85",
				reasons = { "can't be reached with no jump" },
			},
		})
		local allGood = EggRanks.run({ good, goodRare() })
		expect(allGood.ok).toBe(true)
		expect(allGood.failures).toEqual({})
		expect(#allGood.verdicts).toBe(2)
	end)
end)
