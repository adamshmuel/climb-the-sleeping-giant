--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local HeistScore = require(ServerScriptService.Server.World.HeistScore)

-- Worked from Config: Walk 16 studs/s (a Climb runs at 0.7 of it), Boots x1, Belly x1.5, Nightcap x3, ladder x1.2,
-- walk noise 4/s, solo drain 1.5/s, Uncommon slowdown 0.05 and carry x1.5, Rare 0.1 and x2.5, tiptoe 0.6 speed, 0.2 noise.
describe("HeistScore.replay", function()
	it("a 30 stud ladder in the Boots peaks near 8.84 (spec 4 section 5)", function()
		local score = HeistScore.replay({ up = { { length = 30, kind = "Climb", zone = "Boots" } }, tiptoe = false })
		expect(score.peak).toBeGreaterThan(8.5)
		expect(score.peak).toBeLessThan(9.5)
	end)

	it("a 3.1 second ramp in the Boots peaks near 7.75 (spec 4 section 5)", function()
		local score = HeistScore.replay({ up = { { length = 49.6, kind = "Walk", zone = "Boots" } }, tiptoe = false })
		expect(score.peak).toBeGreaterThan(7.5)
		expect(score.peak).toBeLessThan(8.5)
	end)

	it("the ladder multiplier counts on a Climb step", function()
		local score = HeistScore.replay({ up = { { length = 11.2, kind = "Climb", zone = "Boots" } }, tiptoe = false })
		expect(score.peak).toBeCloseTo(3.3, 5)
		expect(score.ladderSeconds).toBeCloseTo(1, 5)
	end)

	it("the ladder multiplier does not count on a Walk step", function()
		local score = HeistScore.replay({ up = { { length = 16, kind = "Walk", zone = "Boots" } }, tiptoe = false })
		expect(score.peak).toBeCloseTo(2.5, 5)
		expect(score.ladderSeconds).toBe(0)
	end)

	it("a tiptoed Boots trip never goes below 0", function()
		local score = HeistScore.replay({ up = { { length = 96, kind = "Walk", zone = "Boots" } }, tiptoe = true })
		expect(score.peak).toBe(0)
	end)

	it("the floor at 0 holds between steps", function()
		local score = HeistScore.replay({
			up = {
				{ length = 96, kind = "Walk", zone = "Meadow" },
				{ length = 9.6, kind = "Walk", zone = "Nightcap" },
			},
			tiptoe = true,
		})
		expect(score.peak).toBeCloseTo(0.9, 5)
	end)

	it("the meter is not capped at 100", function()
		local score = HeistScore.replay({ up = { { length = 160, kind = "Walk", zone = "Nightcap" } }, tiptoe = false })
		expect(score.peak).toBeCloseTo(105, 5)
	end)

	it("a Rare egg is slower and louder than an Uncommon one", function()
		local function trip(egg: "Uncommon" | "Rare"): HeistScore.Score
			local leg: HeistScore.Step = { length = 48, kind = "Walk", zone = "Belly" }
			return HeistScore.replay({ up = { leg }, down = { leg }, egg = egg, tiptoe = false })
		end
		local uncommon = trip("Uncommon")
		local rare = trip("Rare")
		expect(uncommon.peak).toBeCloseTo(35.68, 2)
		expect(uncommon.totalSeconds).toBeCloseTo(7.158, 2)
		expect(rare.peak).toBeCloseTo(57, 2)
		expect(rare.totalSeconds).toBeCloseTo(7.333, 2)
		expect(rare.totalSeconds).toBeGreaterThan(uncommon.totalSeconds)
	end)
end)
