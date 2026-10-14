--!strict
-- Allows at most `limit` messages per player in any `windowSeconds` seconds. Extra messages are refused.
-- Pure: the clock is passed in, so a test can move time by hand.

export type RateLimiter = {
	-- True if this player may send a message now (and counts it), false if they sent too many.
	allow: (self: RateLimiter, key: number) -> boolean,
	-- Forgets a player (for example when they leave).
	forget: (self: RateLimiter, key: number) -> (),
	-- How many players are remembered right now.
	trackedCount: (self: RateLimiter) -> number,
}

local RateLimiter = {}

-- `key` is anything that names a player, such as their UserId.
function RateLimiter.new(limit: number, windowSeconds: number, now: () -> number): RateLimiter
	-- For each player, the times of their allowed messages that are still inside the window, oldest first.
	-- A refused message is never stored, so this never holds more than `limit` times per player.
	local sentTimes: { [number]: { number } } = {}
	local tracked = 0

	local limiter: RateLimiter = {
		allow = function(_self, key)
			local time = now()
			local times = sentTimes[key]
			if times == nil then
				times = {}
				sentTimes[key] = times
				tracked += 1
			end
			-- Drop the messages that have aged out of the window.
			while #times > 0 and time - times[1] >= windowSeconds do
				table.remove(times, 1)
			end
			if #times >= limit then
				return false
			end
			table.insert(times, time)
			return true
		end,
		forget = function(_self, key)
			if sentTimes[key] ~= nil then
				sentTimes[key] = nil
				tracked -= 1
			end
		end,
		trackedCount = function(_self)
			return tracked
		end,
	}
	return limiter
end

return RateLimiter
