--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RateLimiter = require(ServerScriptService.Server.Remotes.RateLimiter)

-- A clock the test moves by hand.
local function newClock()
	local time = 100
	return {
		now = function(): number
			return time
		end,
		advance = function(seconds: number)
			time += seconds
		end,
	}
end

describe("RateLimiter", function()
	it("allows 5 messages in one second", function()
		local clock = newClock()
		local limiter = RateLimiter.new(5, 1, clock.now)
		for _ = 1, 5 do
			expect(limiter:allow(1)).toBe(true)
		end
	end)

	it("refuses the 6th message within the second", function()
		local clock = newClock()
		local limiter = RateLimiter.new(5, 1, clock.now)
		for _ = 1, 5 do
			limiter:allow(1)
		end
		expect(limiter:allow(1)).toBe(false)
		clock.advance(0.5)
		expect(limiter:allow(1)).toBe(false)
	end)

	it("allows messages again one second after they were sent", function()
		local clock = newClock()
		local limiter = RateLimiter.new(5, 1, clock.now)
		for _ = 1, 5 do
			limiter:allow(1)
		end
		expect(limiter:allow(1)).toBe(false)
		clock.advance(1)
		expect(limiter:allow(1)).toBe(true)
	end)

	it("lets messages through again one at a time as the old ones age out", function()
		local clock = newClock()
		local limiter = RateLimiter.new(2, 1, clock.now)
		expect(limiter:allow(1)).toBe(true) -- at 0
		clock.advance(0.6)
		expect(limiter:allow(1)).toBe(true) -- at 0.6
		clock.advance(0.5) -- now 1.1: the first one has aged out, the second has not
		expect(limiter:allow(1)).toBe(true)
		expect(limiter:allow(1)).toBe(false)
	end)

	it("does not count refused messages against the player", function()
		local clock = newClock()
		local limiter = RateLimiter.new(1, 1, clock.now)
		expect(limiter:allow(1)).toBe(true)
		for _ = 1, 20 do
			expect(limiter:allow(1)).toBe(false)
			clock.advance(0.04)
		end
		clock.advance(0.2) -- 1.0 s after the one allowed message
		expect(limiter:allow(1)).toBe(true)
	end)

	it("counts each player on their own", function()
		local clock = newClock()
		local limiter = RateLimiter.new(1, 1, clock.now)
		expect(limiter:allow(1)).toBe(true)
		expect(limiter:allow(1)).toBe(false)
		expect(limiter:allow(2)).toBe(true)
	end)

	it("forgets a player who left, so a new player with the same key starts fresh", function()
		local clock = newClock()
		local limiter = RateLimiter.new(1, 1, clock.now)
		expect(limiter:allow(1)).toBe(true)
		expect(limiter:allow(1)).toBe(false)
		limiter:forget(1)
		expect(limiter:allow(1)).toBe(true)
	end)

	it("keeps nothing in memory for a player who left", function()
		local clock = newClock()
		local limiter = RateLimiter.new(5, 1, clock.now)
		limiter:allow(1)
		limiter:allow(2)
		expect(limiter:trackedCount()).toBe(2)
		limiter:forget(1)
		expect(limiter:trackedCount()).toBe(1)
		limiter:forget(2)
		expect(limiter:trackedCount()).toBe(0)
	end)
end)
