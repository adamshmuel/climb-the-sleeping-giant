--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local HeistScore = require(ServerScriptService.Server.World.HeistScore)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)

-- ReachCheck (spec 4, Rules 46 to 48): the difficulty score of a nest on a hand-built map (nothing is placed in the
-- world). The map is in work/p4t7/p4t7-tests.md: two feet (Ramp 1, Ladder 2) on a meadow floor (3), a ledge in the
-- Boots (5) reached by a walk from the Ramp and a climb from the Ladder, a high ledge in the Nightcap (6), a ledge only
-- a slide leads to (7), and a trap ledge (8) with a walk up and only a drop back.
describe("ReachCheck", function()
	local ZONES: { [number]: Config.ZoneName } = {
		[1] = "Meadow",
		[2] = "Meadow",
		[3] = "Meadow",
		[5] = "Boots",
		[6] = "Nightcap",
		[7] = "Nightcap",
		[8] = "Boots",
		[9] = "Meadow",
		[10] = "Boots",
	}
	local function spot(id: number, position: Vector3, up: Vector3?): PathCheck.Spot
		return { id = id, position = position, up = up or Vector3.new(0, 1, 0), standsOn = Instance.new("Part") }
	end
	local function link(to: number, kind: PathCheck.LinkKind, length: number, seconds: number): PathCheck.Link
		return { to = to, kind = kind, length = length, seconds = seconds }
	end
	local function buildMap(): PathCheck.WalkMap
		return {
			spacing = Config.Stuck.ScanSpacing,
			spots = {
				spot(1, Vector3.new(0, 0, 0)),
				spot(2, Vector3.new(20, 0, 0)),
				spot(3, Vector3.new(10, 0, 0)),
				spot(5, Vector3.new(10, 20, -30)),
				spot(6, Vector3.new(10, 60, -30)),
				spot(7, Vector3.new(50, 50, -30)), -- 10 studs below spot 6: the slide to it is a real drop
				spot(8, Vector3.new(-30, 20, -30)),
				spot(9, Vector3.new(100, 0, 100), Vector3.new(0.954, 0.3, 0).Unit),
			},
			links = {
				[1] = { link(3, "Walk", 10, 0.625), link(5, "Walk", 48, 3), link(8, "Walk", 40, 2.5) },
				[2] = { link(3, "Walk", 10, 0.625), link(5, "Climb", 20, 20 / 11.2) },
				[3] = { link(1, "Walk", 10, 0.625), link(2, "Walk", 10, 0.625) },
				[5] = { link(1, "Walk", 48, 3), link(2, "Climb", 20, 20 / 11.2), link(6, "Climb", 100, 100 / 11.2) },
				[6] = { link(5, "Climb", 100, 100 / 11.2), link(7, "Slide", 20, 1) },
				[7] = {},
				[8] = { link(1, "Slide", 40, 2) },
				[9] = {},
			},
			columns = {},
			origin = Vector3.zero,
			countX = 0,
			countZ = 0,
		} :: any
	end
	local function buildOptions(feet: { ReachCheck.Foot }?, rareFrom: number?, hasRoom: ((PathCheck.Spot) -> boolean)?)
		local options: ReachCheck.Options = {
			map = buildMap(),
			feet = feet or { { name = "Ramp", spot = 1 }, { name = "Ladder", spot = 2 } },
			gardens = { { garden = 1, spot = 1 }, { garden = 4, spot = 3 } },
			zoneOf = function(id: number): Config.ZoneName
				return ZONES[id]
			end,
			rareFrom = rareFrom or 40,
			hasRoom = hasRoom,
		}
		return options
	end
	local function nest(name: string, x: number, y: number, z: number, inMeadow: boolean): ReachCheck.NestInput
		return { name = name, position = Vector3.new(x, y, z), inMeadow = inMeadow }
	end
	local FLOOR = nest("Floor", 10, 1, 0, true)
	local LEDGE = nest("Ledge", 10, 21, -30, false)
	local HIGH = nest("High", 10, 61, -30, false)

	local function step(length: number, kind: "Walk" | "Climb"): HeistScore.Step
		return { length = length, kind = kind, zone = "Boots" }
	end

	local function routeOf(cost: number): PathCheck.Route
		return { steps = {}, cost = cost }
	end

	local function routeWith(cost: number, seconds: number): PathCheck.Route
		local only: PathCheck.Step = { from = 1, to = 3, kind = "Walk", length = 10, seconds = seconds }
		return { steps = { only }, cost = cost }
	end

	it("a meadow nest scores 0, has no egg and no feet, and is reached and left", function()
		local result = ReachCheck.analyse(buildOptions(), FLOOR)
		expect(result.score).toBe(0)
		expect(result.eggUsed).toBeNil()
		expect(result.roomToStand).toBe(true)
		expect(result.reached).toBe(true)
		expect(result.left).toBe(true)
		expect(result.upBy).toBeNil()
		expect(result.homeBy).toBeNil()
	end)

	it("a ledge reached by both feet takes the quietest, and scores the replay of that trip", function()
		local options = buildOptions()
		local result = ReachCheck.analyse(options, LEDGE)
		expect(result.reached).toBe(true)
		expect(result.left).toBe(true)
		expect(result.upBy).toBe("Ladder")
		expect(result.homeBy).toBe("Ladder")
		local byHand = HeistScore.replay({
			up = { step(20, "Climb") },
			down = { step(20, "Climb") },
			egg = "Uncommon",
			tiptoe = false,
		})
		expect(result.score).toBeCloseTo(byHand.peak, 5)
		-- No climb between the ladder foot (2) and the ledge (5): the Ramp foot can't borrow the ladder through the meadow.
		local rampOptions = buildOptions({ { name = "Ramp", spot = 1 } })
		for _, id in { 2, 5 } do
			local kept: { PathCheck.Link } = {}
			for _, candidate in rampOptions.map.links[id] do
				local joinsLadder = candidate.kind == "Climb" and (candidate.to == 2 or candidate.to == 5)
				if not joinsLadder then
					table.insert(kept, candidate)
				end
			end
			rampOptions.map.links[id] = kept
		end
		local rampOnly = ReachCheck.analyse(rampOptions, LEDGE)
		expect(rampOnly.score).toBeGreaterThan(result.score)
	end)

	it("the egg is Uncommon, and Rare once the Uncommon score reaches rareFrom", function()
		local ledge = ReachCheck.analyse(buildOptions(), LEDGE)
		expect(ledge.eggUsed).toBe("Uncommon")
		expect(ledge.score).toBeLessThan(40)
		local high = ReachCheck.analyse(buildOptions(), HIGH)
		local uncommonOnly = ReachCheck.analyse(buildOptions(nil, 100000), HIGH)
		expect(uncommonOnly.eggUsed).toBe("Uncommon")
		expect(uncommonOnly.score).toBeGreaterThanOrEqual(40)
		expect(high.eggUsed).toBe("Rare")
		expect(high.score).toBeGreaterThan(uncommonOnly.score)
	end)

	it("a nest only a slide reaches, or only a drop leaves, is not reached or not left and scores 0", function()
		local dropped = ReachCheck.analyse(buildOptions(), nest("Dropped", 50, 51, -30, false))
		expect(dropped.reached).toBe(false)
		expect(dropped.left).toBe(false)
		expect(dropped.score).toBe(0)
		local trap = ReachCheck.analyse(buildOptions(), nest("Trap", -30, 21, -30, false))
		expect(trap.reached).toBe(true)
		expect(trap.left).toBe(false)
		expect(trap.score).toBe(0)
	end)

	it("a nest with no flat spot, or no room, within reach has no room to stand", function()
		local far = ReachCheck.analyse(buildOptions(), nest("Far", 100, 1, 100, false))
		expect(far.roomToStand).toBe(false)
		expect(far.reached).toBe(false)
		expect(far.left).toBe(false)
		expect(far.score).toBe(0)
		local noRoom = ReachCheck.analyse(
			buildOptions(nil, nil, function(s: PathCheck.Spot): boolean
				return s.id ~= 3
			end),
			nest("Crowded", 10, 3, 0, true)
		)
		expect(noRoom.roomToStand).toBe(false)
		expect(noRoom.reached).toBe(false)
	end)

	it("the Tiptoe peak is lower than the score, and the ladder time counts only the ladder", function()
		local high = ReachCheck.analyse(buildOptions(), HIGH)
		expect(high.tiptoePeak).toBeLessThan(high.score)
		local ledge = ReachCheck.analyse(buildOptions(), LEDGE)
		expect(ledge.ladderSeconds).toBeCloseTo(3.6654, 3)
	end)

	it(
		"pickRoutes takes the cheapest up and the cheapest way home, and replayPick matches the hand-built trip",
		function()
			local pick = ReachCheck.pickRoutes(
				{ Ladder = routeOf(10), Ramp = routeOf(12) },
				{ Ladder = routeOf(9), Ramp = routeOf(4) }
			)
			expect(pick).never.toBeNil()
			local picked = pick :: ReachCheck.Pick
			expect(picked.upBy).toBe("Ladder")
			expect(picked.homeBy).toBe("Ramp")
			expect(picked.up.cost).toBe(10)
			expect(picked.down.cost).toBe(4)
			expect(ReachCheck.pickRoutes({}, { Ramp = routeOf(4) })).toBeNil()
			expect(ReachCheck.pickRoutes({ Ramp = routeOf(4) }, {})).toBeNil()
			local tied = ReachCheck.pickRoutes(
				{ Ramp = routeOf(5), Ladder = routeOf(5) },
				{ Ramp = routeOf(7), Ladder = routeOf(7) }
			) :: ReachCheck.Pick
			expect(tied.upBy).toBe("Ladder")
			expect(tied.homeBy).toBe("Ladder")

			local climb: PathCheck.Step = { from = 2, to = 5, kind = "Climb", length = 20, seconds = 20 / 11.2 }
			local walk: PathCheck.Step = { from = 5, to = 1, kind = "Walk", length = 48, seconds = 3 }
			local handBuilt: ReachCheck.Pick = {
				upBy = "Ladder",
				homeBy = "Ramp",
				up = { steps = { climb }, cost = 1 },
				down = { steps = { walk }, cost = 1 },
			}
			local zones = buildOptions().zoneOf
			local replayed = ReachCheck.replayPick(handBuilt, "Uncommon", false, zones)
			local byHand = HeistScore.replay({
				up = { step(20, "Climb") },
				down = { step(48, "Walk") },
				egg = "Uncommon",
				tiptoe = false,
			})
			expect(replayed.peak).toBeCloseTo(byHand.peak, 5)
			expect(replayed.ladderSeconds).toBeCloseTo(byHand.ladderSeconds, 5)
		end
	)

	it("pickRoutes breaks a cost tie by fewer seconds, then by name", function()
		local bySeconds = ReachCheck.pickRoutes(
			{ Ladder = routeWith(5, 4), Ramp = routeWith(5, 2) },
			{ Ladder = routeWith(7 + 1e-9, 3), Ramp = routeWith(7, 1) }
		) :: ReachCheck.Pick
		expect(bySeconds.upBy).toBe("Ramp")
		expect(bySeconds.homeBy).toBe("Ramp")
		local byName = ReachCheck.pickRoutes(
			{ Ladder = routeWith(5, 2), Ramp = routeWith(5, 2) },
			{ Ladder = routeWith(7, 2), Ramp = routeWith(7, 2) }
		) :: ReachCheck.Pick
		expect(byName.upBy).toBe("Ladder")
		expect(byName.homeBy).toBe("Ladder")
	end)

	it("the garden times of a ledge are the quickest and slowest garden to its stand spot", function()
		local result = ReachCheck.analyse(buildOptions(), LEDGE)
		local quickest = result.quickest :: ReachCheck.GardenTime
		local slowest = result.slowest :: ReachCheck.GardenTime
		expect(quickest.garden).toBe(4)
		expect(quickest.seconds).toBeCloseTo(2.4107, 3)
		expect(slowest.garden).toBe(1)
		expect(slowest.seconds).toBeCloseTo(3, 3)
	end)

	describe("ReachCheck.analyseAll", function()
		it("analyseAll gives what analyse gives for each nest", function()
			local nests = { FLOOR, LEDGE, HIGH, nest("Trap", -30, 21, -30, false), nest("Far", 100, 1, 100, false) }
			local all = ReachCheck.analyseAll(buildOptions(), nests)
			expect(#all).toBe(#nests)
			for index, each in nests do
				local alone = ReachCheck.analyse(buildOptions(), each)
				expect(all[index].name).toBe(each.name)
				expect(all[index]).toEqual(alone)
			end
		end)

		it("a garden's startSeconds is added to its time", function()
			local options = buildOptions()
			-- Garden 4 (spot 3) is the quickest to the ledge's stand spot (2.4107 s); a 10 s start puts it last.
			options.gardens = { { garden = 1, spot = 1 }, { garden = 4, spot = 3, startSeconds = 10 } }
			local result = ReachCheck.analyseAll(options, { LEDGE })[1]
			local quickest = result.quickest :: ReachCheck.GardenTime
			local slowest = result.slowest :: ReachCheck.GardenTime
			expect(quickest.garden).toBe(1)
			expect(quickest.seconds).toBeCloseTo(3, 3)
			expect(slowest.garden).toBe(4)
			expect(slowest.seconds).toBeCloseTo(12.4107, 3)
		end)

		-- Task 9d: the walk map joins a narrow strap to its deck by a step of under 2 studs, kept as a one-way Slide down;
		-- a player walks it up and down, so a nest only such a step reaches is still reached and scored.
		it("a step down of under 2 studs is part of a trip up", function()
			local options = buildOptions()
			table.insert(options.map.spots, spot(10, Vector3.new(40, 19.2, -30)))
			table.insert(options.map.links[5], link(10, "Slide", 30, 1)) -- 0.8 studs down: the only way in
			options.map.links[10] = { link(5, "Walk", 30, 1.9) } -- the way back is a walk
			local below = nest("Below", 40, 20.2, -30, false)
			local result = ReachCheck.analyseAll(options, { below })[1]
			expect(result.reached).toBe(true)
			expect(result.left).toBe(true)
			expect(result.score > 0).toBe(true)
		end)

		it("a scored nest carries its up and down routes", function()
			local result = ReachCheck.analyseAll(buildOptions(), { LEDGE, FLOOR })[1]
			expect(result.upBy).toBe("Ladder")
			local up = result.up :: PathCheck.Route
			local down = result.down :: PathCheck.Route
			expect(up.steps[1].from).toBe(2)
			expect(up.steps[#up.steps].to).toBe(5)
			expect(down.steps[1].from).toBe(5)
			expect(down.steps[#down.steps].to).toBe(2)
			local floor = ReachCheck.analyseAll(buildOptions(), { FLOOR })[1]
			expect(floor.up).toBeNil()
			expect(floor.down).toBeNil()
		end)
	end)

	-- Spec 3, Rule 41: the score of each foot on its own, on the same fake map. The ledge (5) is 48 studs from the Ramp
	-- (1) by a walk and 20 studs from the Ladder (2) by a climb; the trap ledge (8) is reached by a walk from the Ramp.
	describe("ReachCheck.peaksByFoot", function()
		local TRAP = nest("Trap", -30, 21, -30, false)
		local function nothingOffLimits(_spot: PathCheck.Spot): boolean
			return false
		end
		local function feetOffLimits(offLimitsSpot: PathCheck.Spot): boolean
			return offLimitsSpot.id == 1 or offLimitsSpot.id == 2
		end

		it("each foot's trip goes up and back down the same foot", function()
			local byNest = ReachCheck.peaksByFoot(buildOptions(), { LEDGE }, "Uncommon", feetOffLimits)
			local trips = byNest.Ledge
			local ramp = trips.Ramp
			local ladder = trips.Ladder
			expect(ramp.up.steps[1].from).toBe(1)
			expect(ramp.up.steps[#ramp.up.steps].to).toBe(5)
			expect(ramp.down.steps[1].from).toBe(5)
			expect(ramp.down.steps[#ramp.down.steps].to).toBe(1)
			expect(ladder.up.steps[1].from).toBe(2)
			expect(ladder.down.steps[#ladder.down.steps].to).toBe(2)
			local walked: HeistScore.Step = { length = 48, kind = "Walk", zone = "Boots" }
			local expected = HeistScore.replay({ up = { walked }, down = { walked }, egg = "Uncommon", tiptoe = false })
			expect(ramp.peak).toBeCloseTo(expected.peak, 5)
		end)

		it("a route never steps onto an off-limits spot other than its own foot", function()
			local byNest = ReachCheck.peaksByFoot(buildOptions(), { LEDGE, TRAP }, "Uncommon", feetOffLimits)
			expect(byNest.Trap.Ramp).never.toBeNil()
			expect(byNest.Trap.Ladder).toBeNil()
			for _, trips in byNest do
				for footName, trip in trips do
					local own = if footName == "Ramp" then 1 else 2
					for _, route in { trip.up, trip.down } do
						for _, routeStep in route.steps do
							expect(routeStep.to == own or routeStep.to == 5 or routeStep.to == 8).toBe(true)
						end
					end
				end
			end
			local open = ReachCheck.peaksByFoot(buildOptions(), { TRAP }, "Uncommon", nothingOffLimits)
			expect(open.Trap.Ladder).never.toBeNil()
		end)

		it("a ladder on the way down is scored as a drop", function()
			local byNest = ReachCheck.peaksByFoot(buildOptions(), { LEDGE }, "Uncommon", feetOffLimits)
			local climbed: HeistScore.Step = { length = 20, kind = "Climb", zone = "Boots" }
			local dropped: HeistScore.Step = { length = 20, kind = "Walk", zone = "Boots" }
			local asDrop = HeistScore.replay({ up = { climbed }, down = { dropped }, egg = "Uncommon", tiptoe = false })
			local climbedDown =
				HeistScore.replay({ up = { climbed }, down = { climbed }, egg = "Uncommon", tiptoe = false })
			expect(byNest.Ledge.Ladder.peak).toBeCloseTo(asDrop.peak, 5)
			expect(byNest.Ledge.Ladder.peak).toBeLessThan(climbedDown.peak)
		end)

		-- A new spot (10) 30 studs from the ledge (5), `drop` studs lower, joined only by a one-way Slide from the ledge.
		local function withSlideDown(drop: number): (ReachCheck.Options, ReachCheck.NestInput)
			local options = buildOptions()
			table.insert(options.map.spots, spot(10, Vector3.new(40, 20 - drop, -30)))
			table.insert(options.map.links[5], link(10, "Slide", 30, 1))
			options.map.links[10] = {}
			return options, nest("Below", 40, 21 - drop, -30, false)
		end

		-- Product's ruling (work/p3t12b/12b-mirror-decision.md): a Slide of under 2 studs is a walked step.
		it("a step down of under 2 studs is walked on the way up", function()
			local options, below = withSlideDown(0.7)
			local byNest = ReachCheck.peaksByFoot(options, { below }, "Uncommon", feetOffLimits)
			local trip = byNest.Below.Ramp
			expect(trip).never.toBeNil()
			expect(trip.up.steps[#trip.up.steps].kind).toBe("Slide")
			local walked: { HeistScore.Step } = { step(48, "Walk"), step(30, "Walk") }
			local byHand = HeistScore.replay({ up = walked, down = walked, egg = "Uncommon", tiptoe = false })
			expect(trip.peak).toBeCloseTo(byHand.peak, 5)
		end)

		it("a drop of 2 studs or more is never part of a trip", function()
			local options, below = withSlideDown(2)
			local byNest = ReachCheck.peaksByFoot(options, { below }, "Uncommon", feetOffLimits)
			expect(byNest.Below.Ramp).toBeNil()
			expect(byNest.Below.Ladder).toBeNil()
		end)
	end)
end)
