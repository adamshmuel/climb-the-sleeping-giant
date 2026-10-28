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

-- Task 8c (Lesson 85): when the press stops. Args: where the fall began (nil: never seen falling), feet height now,
-- standing on a floor, and whether this is a step-off (true) or a drop (false).
describe("BotWalk.keepPressing", function()
	it("a step-off stops pressing on the first floor after a fall of 3 studs", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(50.9, 42.1, true, true)).toBe(false)
		expect(BotWalk.keepPressing(50.9, 47.9, true, true)).toBe(false)
	end)

	it("a step-off does not use the target height: a ledge far above it still stops the press", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(100, 90, true, true)).toBe(false)
	end)

	it("a step-off keeps pressing after a bump of less than 3 studs", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(100, 98, true, true)).toBe(true)
		expect(BotWalk.keepPressing(100, 97.1, true, true)).toBe(true)
	end)

	it("a step-off still in the air keeps pressing, however far it has fallen", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(100, 60, false, true)).toBe(true)
	end)

	it("a drop stops pressing at touchdown, however short the fall", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(2.5, 2.0, true, false)).toBe(false)
		expect(BotWalk.keepPressing(50, 2.0, true, false)).toBe(false)
	end)

	it("a drop still in the air keeps pressing", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(50, 20, false, false)).toBe(true)
	end)

	it("a body that was never seen falling keeps pressing", function()
		local BotWalk = botWalk()
		expect(BotWalk.keepPressing(nil, 6.1, true, true)).toBe(true)
		expect(BotWalk.keepPressing(nil, 2.0, true, false)).toBe(true)
	end)
end)

-- Task 8c (product's ruling on #347): a ladder drop that grabbed is judged by its walk-out tries.
describe("BotWalk.judgeGrab", function()
	it("passes a drop that grabbed the ladder when a walk-out try gets 3 studs away", function()
		local BotWalk = botWalk()
		local ok, reason = BotWalk.judgeGrab(true, { 0.0, 25.9 })
		expect(ok).toBe(true)
		expect(reason).toBe("OK")
	end)

	it("fails a drop that grabbed the ladder when every try stays under 3 studs", function()
		local BotWalk = botWalk()
		local ok, reason = BotWalk.judgeGrab(true, { 0.0, 2.9 })
		expect(ok).toBe(false)
		expect(reason).toBe("WEDGED")
	end)

	it("fails a drop that never grabbed the ladder, whatever the tries say", function()
		local BotWalk = botWalk()
		local ok, reason = BotWalk.judgeGrab(false, { 25.9 })
		expect(ok).toBe(false)
		expect(reason).toBe("NO_GRAB")
	end)
end)
