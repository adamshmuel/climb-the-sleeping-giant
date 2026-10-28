--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")

-- Loaded inside each test, as a clone (Lesson 74), so a missing module turns each test red on its own.
local function botWalk(): any
	return (require :: any)(ServerStorage.Tools.checks.BotWalk:Clone())
end

-- Stuck safety Task 8b (Rule 24: A bot walks every way): how a walk and a landing are judged, on made-up walk logs.
describe("BotWalk.judgeWalk", function()
	it("passes a walk when it reaches its end within 8 seconds", function()
		local BotWalk = botWalk()
		local okFast, reasonFast = BotWalk.judgeWalk(5.2, true)
		local okLimit, reasonLimit = BotWalk.judgeWalk(8, true)
		expect(okFast).toBe(true)
		expect(reasonFast).toBe("OK")
		expect(okLimit).toBe(true)
		expect(reasonLimit).toBe("OK")
	end)

	it("fails a walk when it takes more than 8 seconds", function()
		local BotWalk = botWalk()
		local okSlow, reasonSlow = BotWalk.judgeWalk(8.5, true)
		local okShort, reasonShort = BotWalk.judgeWalk(3, false)
		expect(okSlow).toBe(false)
		expect(reasonSlow).toBe("SLOW")
		expect(okShort).toBe(false)
		expect(reasonShort).toBe("SLOW")
	end)
end)

describe("BotWalk.judgeLanding", function()
	it("passes a step-off when it ends on the meadow", function()
		local BotWalk = botWalk()
		local ok, reason = BotWalk.judgeLanding(true, true, {})
		expect(ok).toBe(true)
		expect(reason).toBe("OK")
	end)

	it("passes a step-off on him when a walk-out try gets 3 studs away", function()
		local BotWalk = botWalk()
		local ok, reason = BotWalk.judgeLanding(false, true, { 0.4, 1.1, 3.5 })
		expect(ok).toBe(true)
		expect(reason).toBe("OK")
	end)

	it("never counts an end lower than the start as got out by itself", function()
		-- Lesson 69: only a walk-out decides "got out". Landed, not on the meadow, no try got 3 studs away.
		local BotWalk = botWalk()
		local okNoTries, reasonNoTries = BotWalk.judgeLanding(false, true, {})
		local okShortTries, reasonShortTries = BotWalk.judgeLanding(false, true, { 0.5, 2.9 })
		local okNoLanding, reasonNoLanding = BotWalk.judgeLanding(false, false, {})
		expect(okNoTries).toBe(false)
		expect(reasonNoTries).toBe("WEDGED")
		expect(okShortTries).toBe(false)
		expect(reasonShortTries).toBe("WEDGED")
		expect(okNoLanding).toBe(false)
		expect(reasonNoLanding).toBe("NO_LANDING")
	end)
end)

describe("BotWalk.nextTry", function()
	it("stops the walk-out at its first try that gets 3 studs away", function()
		local BotWalk = botWalk()
		local first = BotWalk.nextTry({})
		local second = BotWalk.nextTry({ 0.8 })
		local stopped = BotWalk.nextTry({ 0.8, 3.0 })
		local stoppedLater = BotWalk.nextTry({ 0.8, 1.0, 1.2, 4.6 })
		expect(first).toBe("north")
		expect(second).toBe("east")
		expect(stopped).toBe(nil)
		expect(stoppedLater).toBe(nil)
	end)

	it("runs all four pushes and the jump while none gets 3 studs away, then fails", function()
		local BotWalk = botWalk()
		local tries: { string } = {}
		local distances: { number } = {}
		while true do
			local try = BotWalk.nextTry(distances)
			if try == nil or #tries >= 10 then
				break
			end
			table.insert(tries, try)
			table.insert(distances, 0.5)
		end
		expect(tries).toEqual({ "north", "east", "south", "west", "jump" })
		local ok, reason = BotWalk.judgeLanding(false, true, distances)
		expect(ok).toBe(false)
		expect(reason).toBe("WEDGED")
	end)
end)
