--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")
local HangRule = require(ServerStorage.Tools.checks.HangRule)

-- Stuck safety Task 47, step 1 (Rule 22, What counts as stuck): a run in the climbing pose is a hang when the player
-- presses to move, stays in the pose for the hang time (0.5 s) or more, and moves less than 1 stud. Tested on made-up
-- run summaries, so nothing needs a world.
describe("HangRule.judge", function()
	local function run(seconds: number, moved: number, pressing: boolean, ladder: string?): HangRule.Run
		return { seconds = seconds, moved = moved, pressing = pressing, ladder = ladder }
	end

	it("counts a pressed run of 0.5 seconds that moves less than 1 stud as a hang", function()
		expect(HangRule.judge(run(0.5, 0.2, true)).hang).toBe(true)
	end)

	it("does not count a pressed run of 0.45 seconds", function()
		expect(HangRule.judge(run(0.45, 0.2, true)).hang).toBe(false)
	end)

	it("does not count a run of 0.5 seconds or more that moves 1 stud or more", function()
		expect(HangRule.judge(run(2, 1, true)).hang).toBe(false)
	end)

	it("does not count a run while the player is not pressing to move", function()
		expect(HangRule.judge(run(3, 0, false)).hang).toBe(false)
	end)

	it("counts a run beside a ladder that does not move for 0.5 seconds, and keeps the ladder's name", function()
		local verdict = HangRule.judge(run(0.5, 0, true, "BeardLadder/Climb"))
		expect(verdict.hang).toBe(true)
		expect((string.find(verdict.reason, "BeardLadder/Climb", 1, true))).never.toBeNil()
	end)

	it("does not count a run beside a ladder that moves 1 stud", function()
		expect(HangRule.judge(run(0.5, 1, true, "BeardLadder/Climb")).hang).toBe(false)
	end)
end)
