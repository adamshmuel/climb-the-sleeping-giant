--!strict
-- Stuck safety Task 8b (Rule 24: A bot walks every way): how the bot's walks and landings are judged.
-- Pure: no services, no require, no script.Parent, so the server can clone it into ReplicatedStorage (Lesson 74).
local BotWalk = {}

-- A walk must reach its end within this many seconds (spec: "Bot walk time limit").
BotWalk.LIMIT = 8
-- A walk-out try that ends this many studs from the end's feet got the bot out (Rule 22).
BotWalk.AWAY = 3
-- The walk-out tries, in order: four pushes, then one jump.
BotWalk.TRIES = { "north", "east", "south", "west", "jump" }

-- A walk passes when it reached its end within the time limit. Reason: OK or SLOW.
function BotWalk.judgeWalk(seconds: number, reached: boolean): (boolean, string)
	if reached and seconds <= BotWalk.LIMIT then
		return true, "OK"
	end
	return false, "SLOW"
end

-- The next walk-out try, or nil once a try got AWAY studs or all tries are done.
-- `distances` holds the feet distance measured after each try so far, in order.
function BotWalk.nextTry(distances: { number }): string?
	for _, distance in distances do
		if distance >= BotWalk.AWAY then
			return nil
		end
	end
	return BotWalk.TRIES[#distances + 1]
end

-- A landing passes when the bot landed and is on the meadow, or a walk-out try got it AWAY studs (Lesson 69:
-- only a walk-out decides "got out"). Reason: OK, NO_LANDING (never landed) or WEDGED (landed, but stuck).
function BotWalk.judgeLanding(onMeadow: boolean, landed: boolean, distances: { number }): (boolean, string)
	if not landed then
		return false, "NO_LANDING"
	end
	if onMeadow then
		return true, "OK"
	end
	for _, distance in distances do
		if distance >= BotWalk.AWAY then
			return true, "OK"
		end
	end
	return false, "WEDGED"
end

return BotWalk
