--!strict
-- The ladder grace (Rule 60): from a player's first touch of a ladder in one wake-up, no slam circle is aimed at them
-- for that ladder's number of seconds. Pure: it reads no clock and no instances, the caller passes the time.

export type LadderGrace = {
	touch: (self: LadderGrace, userId: number, ladder: string, now: number) -> (),
	active: (self: LadderGrace, userId: number, now: number) -> boolean,
	clear: (self: LadderGrace) -> (),
}

local LadderGrace = {}

-- `graceSeconds` is how long the grace lasts for each ladder name (Config.Wake.LadderGraceSeconds).
function LadderGrace.new(graceSeconds: { [string]: number }): LadderGrace
	-- userId -> the moment their grace ends, set by the first touch only
	local endsAt: { [number]: number } = {}

	local self: LadderGrace = {
		touch = function(_self: LadderGrace, userId: number, ladder: string, now: number)
			local seconds = graceSeconds[ladder]
			if seconds == nil or endsAt[userId] ~= nil then
				return
			end
			endsAt[userId] = now + seconds
		end,
		active = function(_self: LadderGrace, userId: number, now: number): boolean
			local ends = endsAt[userId]
			return ends ~= nil and now < ends
		end,
		clear = function(_self: LadderGrace)
			table.clear(endsAt)
		end,
	}
	return self
end

return LadderGrace
