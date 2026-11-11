--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local Helpers = require(script.Parent.Helpers)
local addPlayer = Helpers.addPlayer
local cleanUp = Helpers.cleanUp
local meter = Helpers.meter
local newHarness = Helpers.newHarness
local sample = Helpers.sample
local stepTimes = Helpers.stepTimes

afterEach(cleanUp)

describe("GiantDirector meter", function()
	it("rises while a player walks on his belly", function()
		-- 6 noise a second minus 1.5 drain a second (one player alone) is +4.5 a second. The meter starts at 10,
		-- not 0, because the drain can't take it below 0 on the first step.
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(14.5, 5)
	end)

	it("makes a climber on a ladder a little louder", function()
		-- Belly 1.5 x walk 4 x ladder multiplier (Config.Noise.LadderMultiplier) = 7.8 a second, so 0.78 a step,
		-- minus 0.15 of drain (0.63). The same walk off a ladder is 0.6 a step (the first test). Ten steps, because the
		-- meter reads out to 0.1 and one step's 0.57 would round.
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		local climber = sample(1, "Belly", true)
		climber.onLadder = true
		harness.samples = { climber }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(10 + (6 * Config.Noise.LadderMultiplier - 1.5), 5)
	end)

	it("starts from 0 without going below it", function()
		local harness = newHarness(0)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 1)
		-- The drain of 0.15 can't take 0 below 0, so the whole 0.6 of noise stays.
		expect(meter(harness)).toBeCloseTo(0.6, 5)
	end)

	it("falls while a player stands still", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", false) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(8.5, 5)
	end)

	it("drains one point a second for every player", function()
		local harness = newHarness(10)
		for id = 1, 4 do
			addPlayer(harness, id, `Player{id}`)
		end
		harness.samples = { sample(1, "Meadow", false), sample(2, "Meadow", false) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(6, 5)
	end)

	it("adds noise for a player carrying an egg and tiptoeing", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", { tiptoe = true, carrying = "Rare" })
		-- Boots 1 x walk 4 x Rare 2.5 x tiptoe 0.2 = 2 a second, so 0.2 a step, minus 0.15 of drain.
		harness.samples = { sample(1, "Boots", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(10.5, 5)
	end)

	it("makes no noise inside a garden", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		-- a garden always reports the Meadow, but the rule must hold for any zone
		harness.samples = { sample(1, "Belly", true, nil, 3) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeCloseTo(8.5, 5)
	end)

	it("ignores a sample whose player is not in the player list", function()
		local harness = newHarness(10)
		harness.samples = { sample(99, "Belly", true, "Belly") }
		stepTimes(harness, 1)
		-- No players are listed, so nothing drains and nothing is added.
		expect(meter(harness)).toBeCloseTo(10, 5)
	end)
end)

describe("GiantDirector tiptoe speed", function()
	-- All of these walk on the Belly for one second (10 steps) from a meter of 10, with the drain of 1.5 a second
	-- already in the numbers. Normal walking there is 1.5 x 4 = 6 a second; with Tiptoe it is a fifth of that.
	local function walkOnBelly(
		groundSpeed: number,
		extra: { tiptoe: boolean?, carrying: Config.RarityName?, displayName: string? }?
	): number
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", {
			tiptoe = extra ~= nil and extra.tiptoe == true,
			carrying = if extra ~= nil then extra.carrying else nil,
			displayName = if extra ~= nil then extra.displayName else nil,
		})
		harness.samples = { sample(1, "Belly", true, nil, nil, groundSpeed) }
		stepTimes(harness, 10)
		return meter(harness)
	end

	it("a Tiptoe player walking at tiptoe speed makes tiptoe noise", function()
		-- 1.5 x 4 x 0.2 = 1.2 a second, minus 1.5 of drain.
		expect(walkOnBelly(9.6, { tiptoe = true })).toBeCloseTo(9.7, 5)
	end)

	it("a Tiptoe player walking at full speed makes normal walking noise", function()
		-- 6 a second, minus 1.5 of drain.
		expect(walkOnBelly(16, { tiptoe = true })).toBeCloseTo(14.5, 5)
	end)

	it("exactly 1.25 times tiptoe speed (12) still counts as tiptoe", function()
		expect(walkOnBelly(12, { tiptoe = true })).toBeCloseTo(9.7, 5)
	end)

	it("just over 1.25 times tiptoe speed counts as normal walking", function()
		expect(walkOnBelly(12.01, { tiptoe = true })).toBeCloseTo(14.5, 5)
	end)

	it("with a Rare egg the limit is 1.25 times 8.64 (10.8)", function()
		-- A Rare makes the noise 2.5 times louder: 15 a second normally, 3 with Tiptoe. Minus 1.5 of drain.
		expect(walkOnBelly(10.79, { tiptoe = true, carrying = "Rare" })).toBeCloseTo(11.5, 5)
		expect(walkOnBelly(10.81, { tiptoe = true, carrying = "Rare" })).toBeCloseTo(23.5, 5)
	end)

	it("a player without Tiptoe makes normal walking noise at any speed", function()
		expect(walkOnBelly(5, nil)).toBeCloseTo(14.5, 5)
		expect(walkOnBelly(16, nil)).toBeCloseTo(14.5, 5)
	end)

	it("the speed limit is checked on each step", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", { tiptoe = true })
		harness.samples = { sample(1, "Belly", true, nil, nil, 16) }
		stepTimes(harness, 5) -- +4.5 a second for half a second: 12.25
		harness.samples = { sample(1, "Belly", true, nil, nil, 9.6) }
		stepTimes(harness, 5) -- -0.3 a second for half a second: 12.1
		expect(meter(harness)).toBeCloseTo(12.1, 5)
	end)
end)

describe("GiantDirector thuds", function()
	it("adds 30 at once for a thud from the belly", function()
		local harness = newHarness(10.15)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		-- 10.15 + 30 from the thud, then this step's drain of 0.15: exactly 40, so no rounding decides the result.
		expect(meter(harness)).toBeCloseTo(40, 5)
	end)

	it("adds nothing for a thud that ends in a garden", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly", 2) }
		stepTimes(harness, 1)
		expect(meter(harness)).toBeCloseTo(9.9, 5)
	end)

	it("adds the thud's size for the zone the fall left", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Beard") }
		stepTimes(harness, 1)
		expect(meter(harness)).toBeCloseTo(49.9, 5)
	end)
end)

describe("GiantDirector warnings", function()
	it("calls fireWarning(60) once when the meter rises past 60", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeGreaterThan(60)
		expect(harness.warnings).toEqual({ 60 })
	end)

	it("does not call it again while the meter stays above 60", function()
		local harness = newHarness(65)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(harness.warnings).toEqual({})
	end)

	it("does not repeat a warning until the meter has dropped 10 below the mark", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		expect(harness.warnings).toEqual({ 60 })
		-- Something else puts the meter back to 59.5. That is not 10 below the mark, so it stays used up.
		harness.state:SetAttribute("Meter", 59.5)
		stepTimes(harness, 5)
		expect(harness.warnings).toEqual({ 60 })
	end)

	it("warns again after the meter has dropped to 50 and rises past 60 again", function()
		local harness = newHarness(59)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		harness.state:SetAttribute("Meter", 49)
		harness.samples = { sample(1, "Meadow", false) }
		stepTimes(harness, 1)
		harness.state:SetAttribute("Meter", 59.5)
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 5)
		expect(harness.warnings).toEqual({ 60, 60 })
	end)

	it("calls fireWarning(85) when the meter rises past 85", function()
		local harness = newHarness(70)
		addPlayer(harness, 1, "Mia")
		-- A thud from the boots is +20.
		harness.samples = { sample(1, "Meadow", false, "Boots") }
		stepTimes(harness, 1)
		expect(harness.warnings).toEqual({ 85 })
	end)

	it("sends both warnings, in order, when one step jumps past both", function()
		local harness = newHarness(57)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Meadow", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.warnings).toEqual({ 60, 85 })
	end)
end)
