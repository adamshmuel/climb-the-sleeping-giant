--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local FairnessCheck = require(ServerScriptService.Server.World.FairnessCheck)

-- Spec 3, Rule 41 (Every way up is equally loud): the judge only reads numbers, so each test gives it the peaks of a
-- few ways up. Limits: gap 5, window 60 to 80, drain trigger 77, ladder trigger 3.
describe("FairnessCheck.judge", function()
	local function way(
		name: string,
		isLadder: boolean,
		quietRare: number?,
		footprintRare: number?,
		quietUncommon: number?,
		footprintUncommon: number?
	): FairnessCheck.WayUpPeaks
		return {
			name = name,
			gardens = { 1 },
			isLadder = isLadder,
			quietRare = quietRare,
			footprintRare = footprintRare,
			quietUncommon = quietUncommon,
			footprintUncommon = footprintUncommon,
		}
	end

	local function mentions(lines: { string }, text: string): boolean
		for _, line in lines do
			if string.find(line, text, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	it("two ways up 10 points apart fail, naming both", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 65, 66, 40, 40),
			way("BootLadder_Left", true, 75, 76, 41, 41),
		})
		expect(#verdict.failures).toBe(1)
		expect(mentions(verdict.failures, "BootRamp")).toBe(true)
		expect(mentions(verdict.failures, "BootLadder_Left")).toBe(true)
		expect(string.find(verdict.failures[1], "10.0", 1, true) == 1).toBe(true)
	end)

	it("two ways up whose quietest Uncommon peaks are 10 apart are reported, not failed", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 70, 71, 40, 40),
			way("BootLadder_Left", true, 71, 72, 50, 41),
		})
		expect(#verdict.failures).toBe(0)
		expect(#verdict.reports).toBe(1)
		expect(mentions(verdict.reports, "BootRamp")).toBe(true)
		expect(mentions(verdict.reports, "BootLadder_Left")).toBe(true)
		expect(mentions(verdict.reports, "Uncommon")).toBe(true)
	end)

	it("two ways up 3 points apart pass", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 70, 71, 40, 40),
			way("BootLadder_Left", true, 73, 74, 41, 41),
		})
		expect(#verdict.failures).toBe(0)
	end)

	it("a quietest-route peak of 85 fails the 60 to 80 window", function()
		local verdict = FairnessCheck.judge({ way("BootRamp", false, 85, 75, 40, 40) })
		expect(#verdict.failures).toBe(1)
		expect(string.find(verdict.failures[1], "85.0", 1, true) == 1).toBe(true)
		expect(mentions(verdict.failures, "BootRamp")).toBe(true)
	end)

	it("a footprint route at 82 fails the window while the quietest route is at 75", function()
		local verdict = FairnessCheck.judge({ way("BootRamp", false, 75, 82, 40, 40) })
		expect(#verdict.failures).toBe(1)
		expect(string.find(verdict.failures[1], "82.0", 1, true) == 1).toBe(true)
		expect(mentions(verdict.failures, "ootprint")).toBe(true)
	end)

	it("two ways up whose footprint Rare peaks are 10 apart fail, naming both", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 65, 65, 40, 40),
			way("BootLadder_Left", true, 68, 75, 41, 41),
		})
		expect(#verdict.failures).toBe(1)
		expect(mentions(verdict.failures, "BootRamp")).toBe(true)
		expect(mentions(verdict.failures, "BootLadder_Left")).toBe(true)
		expect(string.find(verdict.failures[1], "10.0", 1, true) == 1).toBe(true)
		expect(mentions(verdict.failures, "footprint Rare")).toBe(true)
	end)

	it("two ways up whose quietest Rare peaks are 10 apart are reported, not failed", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 62, 70, 40, 40),
			way("BootLadder_Left", true, 72, 73, 41, 41),
		})
		expect(#verdict.failures).toBe(0)
		expect(mentions(verdict.reports, "BootLadder_Left")).toBe(true)
		expect(mentions(verdict.reports, "quietest Rare")).toBe(true)
		expect(string.find(verdict.reports[1], "10.0", 1, true) == 1).toBe(true)
	end)

	it("two ways up whose footprint Uncommon peaks are 10 apart fail, naming both", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 70, 71, 40, 40),
			way("BootLadder_Left", true, 71, 72, 41, 50),
		})
		expect(#verdict.failures).toBe(1)
		expect(mentions(verdict.failures, "BootRamp")).toBe(true)
		expect(mentions(verdict.failures, "BootLadder_Left")).toBe(true)
		expect(mentions(verdict.failures, "footprint Uncommon")).toBe(true)
	end)

	it("a way with no footprint Uncommon route fails as can't reach", function()
		local verdict = FairnessCheck.judge({ way("BootRamp", false, 70, 71, 40, nil) })
		expect(#verdict.failures).toBe(1)
		expect(string.find(verdict.failures[1], "can't reach", 1, true) == 1).toBe(true)
		expect(mentions(verdict.failures, "footprint Uncommon")).toBe(true)
	end)

	it("Rare egg 1 over 77 is reported, not failed", function()
		local verdict = FairnessCheck.judge({ way("BootRamp", false, 78.5, 79, 40, 40) })
		expect(#verdict.failures).toBe(0)
		expect(#verdict.reports).toBe(1)
		expect(string.find(verdict.reports[1], "78.5", 1, true) == 1).toBe(true)
	end)

	it("ladders all more than 3 points from the ramps are reported, not failed", function()
		local verdict = FairnessCheck.judge({
			way("BootRamp", false, 66, 67, 40, 40),
			way("RightBootRamp", false, 67, 68, 40, 40),
			way("BootLadder_Left", true, 70.5, 71, 41, 41),
			way("BootLadder_Right", true, 71, 72, 41, 41),
		})
		expect(#verdict.failures).toBe(0)
		expect(#verdict.reports).toBe(1)
		expect(mentions(verdict.reports, "adder")).toBe(true)
	end)
end)
