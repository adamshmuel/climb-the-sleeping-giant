--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local Carry = require(ServerScriptService.Server.Eggs.Carry)
local Helpers = require(script.Parent.Helpers)
type Harness = Helpers.Harness
type Sample = Helpers.Sample
local addPlayer = Helpers.addPlayer
local cleanUp = Helpers.cleanUp
local meter = Helpers.meter
local newHarness = Helpers.newHarness
local sample = Helpers.sample
local stepTimes = Helpers.stepTimes

afterEach(cleanUp)

describe("GiantDirector free save", function()
	-- The walking sample of a player carrying a Rare on the belly: 4 x 1.5 x 2.5 = 15 noise a second, so +1.35 a tick
	-- after the drain of 0.15.
	local function walkingOnBelly(): Sample
		return sample(1, "Belly", true)
	end

	-- Steps `count` ticks and returns the highest meter seen on the way (the meter is written to 0.1).
	local function stepAndPeak(harness: Harness, count: number, peakSoFar: number): number
		local peak = peakSoFar
		for _ = 1, count do
			harness.director:step()
			peak = math.max(peak, meter(harness))
		end
		return peak
	end

	it("Check D1: a brand-new carrier walking on the belly is saved once, keeps moving, then wakes him", function()
		local harness = newHarness(0)
		addPlayer(harness, 1, "Mia", { carrying = "Rare" })
		harness.samples = { walkingOnBelly() }
		local previous = -1
		local stillTicks = 0
		local longestStill = 0
		local wokeAtTick: number? = nil
		local atSave: { meter: number, phase: any, warnings: { number }, spent: { number } }? = nil
		for tick = 1, 600 do -- 60 seconds
			harness.director:step()
			if harness.state:GetAttribute("Phase") ~= "Asleep" then
				wokeAtTick = tick
				break
			end
			if atSave == nil and #harness.spent > 0 then
				atSave = {
					meter = meter(harness),
					phase = harness.state:GetAttribute("Phase"),
					warnings = table.clone(harness.warnings),
					spent = table.clone(harness.spent),
				}
			end
			if meter(harness) == previous then
				stillTicks += 1
			else
				stillTicks = 0
			end
			previous = meter(harness)
			longestStill = math.max(longestStill, stillTicks)
		end
		-- At the first would-be wake: the meter is 70, he is still asleep, one save is spent, and both warnings played.
		expect(atSave).never.toBeNil()
		local saveMoment = atSave :: { meter: number, phase: any, warnings: { number }, spent: { number } }
		expect(saveMoment.meter).toBe(70)
		expect(saveMoment.phase).toBe("Asleep")
		expect(saveMoment.warnings).toEqual({ 60, 85 })
		expect(saveMoment.spent).toEqual({ 1 })
		-- Then he wakes before the 60 seconds are up, and the banner names the player. The save is not spent again.
		expect(wokeAtTick).never.toBeNil()
		expect(wokeAtTick :: number).toBeLessThan(600)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
		expect(harness.spent).toEqual({ 1 })
		expect(harness.saves).toEqual({ { userId = 1, zone = "Belly" } })
		-- The V1 bug: the meter sat at 84 for good. It never stands still for 10 seconds while they walk.
		expect(longestStill).toBeLessThan(100)
	end)

	it("Check D2: after the save, 1 second of walking and then a tiptoe home never wakes him", function()
		local harness = newHarness(70)
		addPlayer(harness, 1, "Mia", { carrying = "Rare", saveUsed = true })
		local tiptoeSpeed = Carry.speed(true, "Rare")
		harness.samples = { walkingOnBelly() }
		local peak = stepAndPeak(harness, 10, 0) -- 1 second of walking on the belly
		harness.infos[1].tiptoe = true
		harness.samples = { sample(1, "Belly", true, nil, nil, tiptoeSpeed) }
		peak = stepAndPeak(harness, 40, peak) -- 4 seconds tiptoeing on the belly
		harness.samples = { sample(1, "Boots", true, nil, nil, tiptoeSpeed) }
		peak = stepAndPeak(harness, 80, peak) -- 8 seconds tiptoeing on the boots
		harness.samples = { sample(1, "Meadow", true, nil, nil, tiptoeSpeed) }
		peak = stepAndPeak(harness, 30, peak) -- then the meadow
		-- 70 + 13.5 + 6 + 4 = 93.5: a close call, but he stays asleep.
		expect(peak).toBeGreaterThanOrEqual(92)
		expect(peak).toBeLessThanOrEqual(96)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.wakes).toEqual({})
	end)

	it("Check D3: after the save, walking on without Tiptoe wakes him within 3 seconds", function()
		local harness = newHarness(70)
		addPlayer(harness, 1, "Mia", { carrying = "Rare", saveUsed = true })
		harness.samples = { walkingOnBelly() }
		stepTimes(harness, 30)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
		expect(harness.spent).toEqual({})
	end)

	it("Check E3: a player whose save is used fills the meter, wakes him, and is named", function()
		local harness = newHarness(99)
		addPlayer(harness, 1, "Mia", { carrying = "Rare", saveUsed = true })
		harness.samples = { walkingOnBelly() }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
		expect(harness.spent).toEqual({})
		expect(harness.saves).toEqual({})
	end)

	it(
		"Check E1: a veteran's thud wakes him while a brand-new player stands on the belly, and no save is spent",
		function()
			local harness = newHarness(95)
			addPlayer(harness, 1, "Veteran", { veteran = true })
			addPlayer(harness, 2, "Newbie")
			harness.samples = { sample(1, "Belly", false, "Belly"), sample(2, "Belly", false) }
			stepTimes(harness, 1)
			expect(harness.state:GetAttribute("Phase")).toBe("Awake")
			expect(harness.state:GetAttribute("WokenBy")).toBe("Veteran")
			expect(harness.spent).toEqual({})
			expect(harness.saves).toEqual({})
			expect(harness.infos[2].freeSaveUsed).toBe(false)
		end
	)

	it(
		"a brand-new player who was saved, then a veteran's thud in the same tick: he wakes and no save is spent",
		function()
			-- Rule 19 (Only the waker's save counts). Both thuds have the same noise, so the lower id (the brand-new
			-- player) goes first and would be saved to 70. Then the veteran fills it again: he wakes, so no save is spent.
			local harness = newHarness(95)
			addPlayer(harness, 1, "Newbie")
			addPlayer(harness, 2, "Veteran", { veteran = true })
			harness.samples = { sample(1, "Belly", false, "Belly"), sample(2, "Belly", false, "Belly") }
			stepTimes(harness, 1)
			expect(harness.state:GetAttribute("Phase")).toBe("Awake")
			expect(harness.state:GetAttribute("WokenBy")).toBe("Veteran")
			expect(harness.spent).toEqual({})
			expect(harness.saves).toEqual({})
			expect(harness.infos[1].freeSaveUsed).toBe(false)
		end
	)

	it("a thud that would fill the meter spends a brand-new player's save and leaves the meter at 70", function()
		local harness = newHarness(75)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		-- 75 + 30 would be 105, so the save drops it to 70, and this step's drain of 0.15 comes off after that.
		expect(meter(harness)).toBeGreaterThan(69.7)
		expect(meter(harness)).toBeLessThan(70)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.spent).toEqual({ 1 })
		expect(harness.saves).toEqual({ { userId = 1, zone = "Belly" } })
	end)

	it("a player with a Rare home has no save: his thud wakes him and he is named", function()
		local harness = newHarness(80)
		addPlayer(harness, 1, "Mia", { veteran = true })
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.state:GetAttribute("WokenBy")).toBe("Mia")
		expect(harness.spent).toEqual({})
		expect(harness.saves).toEqual({})
	end)

	it("a save fires the 85 warning once, with the second value FreeSave", function()
		local harness = newHarness(75)
		addPlayer(harness, 1, "Mia")
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.spent).toEqual({ 1 })
		expect(harness.warningCalls).toEqual({ "85:FreeSave" })
		-- The next ticks have no save, so nothing more is sent.
		harness.samples = { sample(1, "Belly", false) }
		stepTimes(harness, 3)
		expect(harness.warningCalls).toEqual({ "85:FreeSave" })
	end)

	it("two brand-new players saved in the same tick send one FreeSave warning", function()
		local harness = newHarness(75)
		addPlayer(harness, 1, "Mia")
		addPlayer(harness, 2, "Noa")
		harness.samples = { sample(1, "Belly", false, "Belly"), sample(2, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.spent).toEqual({ 1, 2 })
		expect(harness.warningCalls).toEqual({ "85:FreeSave" })
	end)

	it("a tick where he wakes sends no FreeSave warning", function()
		local harness = newHarness(95)
		addPlayer(harness, 1, "Newbie")
		addPlayer(harness, 2, "Veteran", { veteran = true })
		harness.samples = { sample(1, "Belly", false, "Belly"), sample(2, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.state:GetAttribute("Phase")).toBe("Awake")
		expect(harness.replays).toEqual({})
	end)

	it("a pass of 85 one second after the save sends nothing: the meter just turns orange", function()
		local harness = newHarness(75)
		-- A Rare carrier on the belly adds 1.35 a tick, so he is past 85 about a second after the save.
		addPlayer(harness, 1, "Mia", { carrying = "Rare" })
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(harness.warningCalls).toEqual({ "85:FreeSave" })
		harness.clock += 1
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 12)
		expect(meter(harness)).toBeGreaterThan(85)
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(harness.warningCalls).toEqual({ "85:FreeSave" })
	end)

	it("after the 3 seconds, a fall below 75 and a new pass of 85 sends a plain 85", function()
		local harness = newHarness(75)
		addPlayer(harness, 1, "Mia", { carrying = "Rare" })
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		harness.clock += 1
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 12) -- past 85, inside the 3 seconds: nothing
		harness.clock += Config.Meter.FreeSaveWarningSeconds
		harness.state:SetAttribute("Meter", 74) -- he has fallen below 75
		harness.samples = { sample(1, "Meadow", false) }
		stepTimes(harness, 1)
		harness.samples = { sample(1, "Belly", true) }
		stepTimes(harness, 10)
		expect(meter(harness)).toBeGreaterThan(85)
		expect(harness.warningCalls).toEqual({ "85:FreeSave", "85" })
	end)

	it("a thud from 45 that would fill the meter sends 60, then 85 as a FreeSave, and ends at 70", function()
		local harness = newHarness(45)
		addPlayer(harness, 1, "Mia")
		-- A thud from the nightcap is +60: 45 + 60 would be 105.
		harness.samples = { sample(1, "Belly", false, "Nightcap") }
		stepTimes(harness, 1)
		expect(harness.spent).toEqual({ 1 })
		expect(harness.warningCalls).toEqual({ "60", "85:FreeSave" })
		expect(harness.state:GetAttribute("Phase")).toBe("Asleep")
		expect(meter(harness)).toBeCloseTo(69.9, 1)
	end)

	it("removes the saved connections when the director is destroyed", function()
		local harness = newHarness(75)
		addPlayer(harness, 1, "Mia")
		local calls = 0
		harness.director.saved:Connect(function()
			calls += 1
		end)
		harness.director:destroy()
		harness.samples = { sample(1, "Belly", false, "Belly") }
		stepTimes(harness, 1)
		expect(calls).toBe(0)
	end)
end)
