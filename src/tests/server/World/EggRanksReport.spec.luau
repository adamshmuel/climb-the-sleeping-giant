--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local EggRanks = require(ServerScriptService.Server.World.EggRanks)
local EggRanksReport = require(ServerScriptService.Server.World.EggRanksReport)
local Helpers = require(ServerStorage.Tests.server.World.RealWorld.Helpers)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)
local inFakeWorld = Helpers.inFakeWorld

-- The egg rank report (spec 4 Rules 56 and 57) on made-up rows: the text, its table, its rank lines and its cell
-- words are in work/p4t10/p4t10-tests.md. Fake rows come from a helper; only the tool test builds a tiny world.
describe("EggRanksReport", function()
	local HEADER: EggRanksReport.Header = { date = "2026-11-11", drain = 0.8, surfaceWords = { Skin = "His skin" } }

	local function rowOf(
		name: string?,
		kind: "nest" | "egg",
		rank: Config.RarityName,
		score: number,
		seat: { surface: string, pose: string, gap: number, sink: number, eggOffset: number? },
		verdict: { close: boolean, reasons: { string } }
	): EggRanksReport.ReportRow
		local reach: ReachCheck.NestResult = {
			name = name or "",
			roomToStand = true,
			reached = true,
			left = true,
			score = score,
			eggUsed = if rank == "Common" then nil else rank,
			tiptoePeak = score / 3,
			ladderSeconds = score / 10,
			quickest = { garden = 4, seconds = 2.4 },
			slowest = { garden = 7, seconds = 9.96 },
		}
		local seatResult = {
			ok = true,
			surface = seat.surface,
			pose = seat.pose,
			gap = seat.gap,
			sink = seat.sink,
			eggOffset = seat.eggOffset,
			reasons = {},
		}
		local made: EggRanks.Verdict = {
			rank = rank,
			band = "any",
			close = verdict.close,
			reasons = verdict.reasons,
			ok = #verdict.reasons == 0,
		}
		return { name = name, seatKind = kind, reach = reach, seat = seatResult, verdict = made }
	end

	local FLUSH = { surface = "Floor", pose = "upright", gap = 0, sink = 0 }
	local NO_REASONS: { close: boolean, reasons: { string } } = { close = false, reasons = {} }

	-- Three rows, given out of order: an Uncommon at 30.4, a Rare at 66.4 (not close) and an Epic at 87.5 (close).
	local function threeRows(): { EggRanksReport.ReportRow }
		local epic = rowOf("Nest_Cap_Top", "egg", "Epic", 87.5, FLUSH, { close = true, reasons = {} })
		local uncommon = rowOf("Nest_Boot_Left", "egg", "Uncommon", 30.4, FLUSH, NO_REASONS)
		local rare = rowOf(
			"Nest_Belly_Left",
			"nest",
			"Rare",
			66.4,
			{ surface = "Skin", pose = "leaning", gap = 0, sink = 0.9, eggOffset = 0 },
			NO_REASONS
		)
		return { epic, uncommon, rare }
	end

	local EXPECTED = table.concat({
		"Egg rank report",
		"Date: 2026-11-11",
		"Solo drain used: 0.8 points a second (how fast the sleep meter falls with one player in the server)",
		"Nest: the name of the nest in the world",
		"Score: the highest the shared sleep meter gets on the quietest trip to the nest and home with its egg, in percent (100% wakes the giant; a meadow nest is 0%). The rank comes from it.",
		"Rank and colour: the rank the score earns, and the colour of its glow",
		"Tiptoe peak: the same trip with Tiptoe on the whole way; 60% or more fails the nest (85% for Legendary)",
		"Quickest garden: the garden whose player gets to the nest fastest, walking and climbing, and how many seconds it takes",
		"Slowest garden: the garden whose player takes longest to get to the nest, and how many seconds it takes",
		"Ladder seconds: the seconds spent on ladders on the trip",
		"Sits on: what the nest or egg sits on, whether it is upright or leaning, whether it floats or sinks, and for a nest how far its egg is from the nest's bottom (all in studs)",
		"Note: Close to the edge, or why the nest fails",
		"",
		"| Nest | Score | Rank and colour | Tiptoe peak | Quickest | Slowest | Ladder seconds | Sits on | Note |",
		"|---|---|---|---|---|---|---|---|---|",
		"| Nest_Boot_Left | 30% | Uncommon, leaf green | 10.1% | garden 4, 2.4 s | garden 7, 10.0 s | 3.0 s | Floor, upright egg, flush |  |",
		"| Nest_Belly_Left | 66% | Rare, sky blue | 22.1% | garden 4, 2.4 s | garden 7, 10.0 s | 6.6 s | His skin, leaning nest, sinks 0.9; egg 0.0 from the nest's bottom |  |",
		"| Nest_Cap_Top | 88% | Epic, purple | 29.2% | garden 4, 2.4 s | garden 7, 10.0 s | 8.8 s | Floor, upright egg, flush | Close to the edge |",
		"",
		"Common: no nests",
		"Uncommon: 1 nest, lowest 30%, highest 30%",
		"Rare: 1 nest, lowest 66%, highest 66%",
		"Epic: 1 nest, lowest 88%, highest 88%",
		"Legendary: no nests",
	}, "\n")

	it("writes the header, the table sorted easiest first, and the five rank lines", function()
		expect(EggRanksReport.build(threeRows(), HEADER)).toBe(EXPECTED)
	end)

	it("adds nothing after the rank lines when the header has no order list", function()
		local text = EggRanksReport.build(threeRows(), HEADER)
		expect(string.find(text, "Rank order and counts", 1, true)).toBeNil()
		expect(string.sub(text, -#"Legendary: no nests")).toBe("Legendary: no nests")
	end)

	it("says Rank order and counts: all pass when the order list is empty", function()
		local header: EggRanksReport.Header =
			{ date = HEADER.date, drain = HEADER.drain, surfaceWords = HEADER.surfaceWords, order = {} }
		local text = EggRanksReport.build(threeRows(), header)
		expect(text).toBe(`{EXPECTED}\nRank order and counts: all pass`)
	end)

	it("writes one Rank order and counts line for each problem", function()
		local order = { "Rare has 5 nests, expected 6", "Cap nest A scores 50%, under Beard nest B at 60%" }
		local header: EggRanksReport.Header =
			{ date = HEADER.date, drain = HEADER.drain, surfaceWords = HEADER.surfaceWords, order = order }
		local text = EggRanksReport.build(threeRows(), header)
		local lines = string.split(text, "\n")
		expect(lines[#lines - 1]).toBe(`Rank order and counts: {order[1]}`)
		expect(lines[#lines]).toBe(`Rank order and counts: {order[2]}`)
		expect(string.find(text, "all pass", 1, true)).toBeNil()
	end)

	it("writes scored by Task 22 as the note of a bot-walk row", function()
		local row = rowOf("Nest_Cuff", "nest", "Epic", 0, FLUSH, { close = false, reasons = { "not reached" } })
		row.botWalk = true
		local lines = string.split(EggRanksReport.build({ row }, HEADER), "\n")
		expect(string.sub(lines[16] or "", -#"| scored by Task 22 |")).toBe("| scored by Task 22 |")
		expect(string.find(lines[16] or "", "not reached", 1, true)).toBeNil()
	end)

	it("counts a bot-walk nest at its target rank, outside lowest and highest", function()
		local scored = rowOf("Nest_Scored", "egg", "Epic", 90, FLUSH, NO_REASONS)
		local walk = rowOf("Nest_Cuff", "nest", "Legendary", 216, FLUSH, NO_REASONS)
		walk.botWalk = true
		walk.worldRank = "Epic"
		local text = EggRanksReport.build({ scored, walk }, HEADER)
		expect((string.find(text, "Epic: 2 nests, lowest 90%, highest 90% (1 scored by Task 22)", 1, true))).toBeDefined()
		expect((string.find(text, "Legendary: no nests", 1, true))).toBeDefined()
		local only = rowOf("Nest_Cuff", "nest", "Legendary", 216, FLUSH, NO_REASONS)
		only.botWalk = true
		only.worldRank = "Epic"
		local alone = EggRanksReport.build({ only }, HEADER)
		expect((string.find(alone, "Epic: 1 nest (1 scored by Task 22)", 1, true))).toBeDefined()
	end)

	it("shows a bot-walk row's score as not scored yet and its target rank", function()
		local row = rowOf("Nest_Cuff", "nest", "Legendary", 216, FLUSH, NO_REASONS)
		row.botWalk = true
		row.worldRank = "Epic"
		local lines = string.split(EggRanksReport.build({ row }, HEADER), "\n")
		local cells = string.split(lines[16] or "", " | ")
		expect(cells[2]).toBe("not scored yet")
		local target: Config.RarityName = "Epic"
		expect(cells[3]).toBe(`Epic (target), {Config.Ranks.ColourWords[target]}`)
	end)

	it("shows a missing name as unnamed nest and fails its row", function()
		local nameless = rowOf(nil, "egg", "Rare", 50, FLUSH, NO_REASONS)
		local empty = rowOf("", "egg", "Rare", 60, FLUSH, NO_REASONS)
		local text = EggRanksReport.build({ nameless, empty }, HEADER)
		local lines = string.split(text, "\n")
		local firstRow = (lines[16] or "")
		expect((string.find(firstRow, "| unnamed nest | 50% |", 1, true))).never.toBeNil()
		expect(
			(
				string.find(
					firstRow,
					"| problem: this nest has no name in the world (its NestName label is empty) |",
					1,
					true
				)
			)
		).never.toBeNil()
		expect((string.find((lines[17] or ""), "| unnamed nest | 60% |", 1, true))).never.toBeNil()
		expect((string.find(text, "Rare: 2 nests, lowest 50%, highest 60%", 1, true))).never.toBeNil()
		for _, bare in { "nil" } do
			expect(string.find(text, bare, 1, true)).toBeNil()
		end
	end)

	it("ends a nest's Sits on cell with the egg's distance, or no egg found", function()
		local found = rowOf(
			"Nest_A",
			"nest",
			"Rare",
			50,
			{ surface = "Floor", pose = "upright", gap = 0, sink = 0, eggOffset = 0 },
			NO_REASONS
		)
		local missing =
			rowOf("Nest_B", "nest", "Rare", 60, { surface = "Floor", pose = "upright", gap = 0, sink = 0 }, NO_REASONS)
		local lines = string.split(EggRanksReport.build({ found, missing }, HEADER), "\n")
		expect(
			(string.find((lines[16] or ""), "| Floor, upright nest, flush; egg 0.0 from the nest's bottom |", 1, true))
		).never.toBeNil()
		expect((string.find((lines[17] or ""), "| Floor, upright nest, flush; no egg found |", 1, true))).never.toBeNil()
	end)

	it("says no nests for a rank that has none", function()
		local lines = string.split(EggRanksReport.build({}, HEADER), "\n")
		local tail = {}
		for i = #lines - 4, #lines do
			table.insert(tail, lines[i])
		end
		expect(tail).toEqual({
			"Common: no nests",
			"Uncommon: no nests",
			"Rare: no nests",
			"Epic: no nests",
			"Legendary: no nests",
		})
	end)

	it("holds no bare code words (nil, true, false, NaN, inf, table:)", function()
		local rows = threeRows()
		table.insert(
			rows,
			rowOf(nil, "egg", "Common", 0, { surface = "", pose = "upright", gap = 0, sink = 0 }, NO_REASONS)
		)
		for _, text in { EggRanksReport.build(threeRows(), HEADER), EggRanksReport.build(rows, HEADER) } do
			expect(#text).toBeGreaterThan(100) -- an empty stub text must not pass
			for _, bare in { "nil", "true", "false", "NaN", "inf", "table:" } do
				expect(`{bare}: {string.find(text, bare, 1, true)}`).toBe(`{bare}: nil`)
			end
		end
	end)

	it("writes a failing row's reasons joined with a semicolon, and a close pass as Close to the edge", function()
		local failing = rowOf(
			"Nest_Bad",
			"egg",
			"Epic",
			88,
			{ surface = "Floor", pose = "upright", gap = 0.3, sink = 0 },
			{ close = true, reasons = { "floats: gap 0.3", "can't be left with no jump" } }
		)
		local close = rowOf("Nest_Edge", "egg", "Rare", 41, FLUSH, { close = true, reasons = {} })
		local text = EggRanksReport.build({ failing, close }, HEADER)
		local lines = string.split(text, "\n")
		local failingLine = (lines[17] or "")
		local reasons = "| Floor, upright egg, floats 0.3 | floats: gap 0.3; can't be left with no jump |"
		expect((string.find(failingLine, reasons, 1, true))).never.toBeNil()
		expect((string.find((lines[16] or ""), "| Nest_Edge | 41% |", 1, true))).never.toBeNil()
		expect(string.sub((lines[16] or ""), -21)).toBe("| Close to the edge |")
	end)

	it("the tool's run builds the report for a made-up world with two nests", function()
		local tool: { run: (input: any) -> string } = require(ServerStorage.Tools.report["egg-ranks"]) :: any
		local function spot(id: number, x: number): PathCheck.Spot
			return { id = id, position = Vector3.new(x, 0, 0), up = Vector3.yAxis, standsOn = Instance.new("Part") }
		end
		local map: PathCheck.WalkMap = {
			spacing = Config.Stuck.ScanSpacing,
			spots = { spot(1, 0), spot(2, 10) },
			links = {
				[1] = { { to = 2, kind = "Walk", length = 10, seconds = 0.6 } },
				[2] = { { to = 1, kind = "Walk", length = 10, seconds = 0.6 } },
			},
			columns = {},
			origin = Vector3.zero,
			countX = 0,
			countZ = 0,
		} :: any
		local options: ReachCheck.Options = {
			map = map,
			feet = { { name = "Ramp", spot = 1 } },
			gardens = { { garden = 1, spot = 2 } },
			zoneOf = function(_id: number): Config.ZoneName
				return "Meadow"
			end,
			rareFrom = 40,
		}
		local text = ""
		inFakeWorld(function(world)
			for index, x in { 0, 10 } do
				local part = Instance.new("Part")
				part.Name = `Ground{index}`
				part.Anchored = true
				part.Size = Vector3.new(8, 1, 8)
				part.Position = Vector3.new(x, -0.5, 0)
				part.Parent = world
			end
			local nests = {}
			for index, x in { 0, 10 } do
				table.insert(nests, {
					name = `Nest_Test{index}`,
					input = { name = `Nest_Test{index}`, position = Vector3.new(x, 1, 0), inMeadow = true },
					worldRank = "Common",
					seat = { kind = "nest", bottom = Vector3.new(x, 0, 0), pose = "upright" },
				})
			end
			text = tool.run({ options = options, world = world, header = HEADER, nests = nests })
		end)
		for _, wanted in
			{
				"Nest_Test1",
				"Nest_Test2",
				"Date: 2026-11-11",
				"Epic: no nests",
				"Common: 2 nests, lowest 0%, highest 0%",
			}
		do
			expect(`{wanted}: {string.find(text, wanted, 1, true) ~= nil}`).toBe(`{wanted}: true`)
		end
	end)
end)
