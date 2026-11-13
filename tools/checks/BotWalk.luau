--!strict
-- Stuck safety Task 8b (Rule 24: A bot walks every way): how the bot's walks and landings are judged.
-- Pure: no services, no require, no script.Parent, so the server can clone it into ReplicatedStorage.
local BotWalk = {}

-- A walk must reach its end within this many seconds (spec: "Bot walk time limit").
BotWalk.LIMIT = 8
-- A walk-out try that ends this many studs from the end's feet got the bot out (product's walk-out ruling, Task 8b
-- block in the plan).
BotWalk.AWAY = 3
-- The walk-out tries, in order: four pushes, then one jump.
BotWalk.TRIES = { "north", "east", "south", "west", "jump" }
-- A walk has reached its end: studs flat, studs in height.
BotWalk.REACH_FLAT, BotWalk.REACH_HEIGHT = 2, 3

function BotWalk.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function BotWalk.steer(feet: Vector3, target: Vector3): Vector3
	local delta = BotWalk.flat(target - feet)
	return if delta.Magnitude < 0.3 then Vector3.zero else delta.Unit
end

function BotWalk.reachedEnd(feet: Vector3, target: Vector3): boolean
	return BotWalk.flat(target - feet).Magnitude <= BotWalk.REACH_FLAT
		and math.abs(target.Y - feet.Y) <= BotWalk.REACH_HEIGHT
end

-- A walk passes when it reached its end within the time limit. Reason: OK or SLOW.
function BotWalk.judgeWalk(seconds: number, reached: boolean): (boolean, string)
	if reached and seconds <= BotWalk.LIMIT then
		return true, "OK"
	end
	return false, "SLOW"
end

-- True when a walk-out try got the bot AWAY studs (only a walk-out decides "got out").
local function gotAway(distances: { number }): boolean
	for _, distance in distances do
		if distance >= BotWalk.AWAY then
			return true
		end
	end
	return false
end

-- The next walk-out try, or nil once a try got AWAY studs or all tries are done.
-- `distances` holds the feet distance measured after each try so far, in order.
function BotWalk.nextTry(distances: { number }): string?
	if gotAway(distances) then
		return nil
	end
	return BotWalk.TRIES[#distances + 1]
end

-- A landing passes when the bot landed and is on the meadow, or a walk-out try got it AWAY studs.
-- Reason: OK, NO_LANDING (never landed) or WEDGED (landed, but stuck).
function BotWalk.judgeLanding(onMeadow: boolean, landed: boolean, distances: { number }): (boolean, string)
	if not landed then
		return false, "NO_LANDING"
	end
	if onMeadow or gotAway(distances) then
		return true, "OK"
	end
	return false, "WEDGED"
end

-- Should the press go on? `fallStartY` is the feet height where the fall began (nil: never seen falling).
-- A drop stops at touchdown after any fall. A step-off stops on the first floor after a real fall of REACH_HEIGHT
-- studs (a smaller bump on the way to the edge does not count); it never looks at its target height, because a ledge
-- above it is a floor too.
function BotWalk.keepPressing(fallStartY: number?, feetY: number, onFloor: boolean, stepOff: boolean): boolean
	if fallStartY == nil or not onFloor then
		return true
	end
	return stepOff and fallStartY - feetY < BotWalk.REACH_HEIGHT
end

-- A drop that was to grab the ladder (product's ruling on #347): no grab fails NO_GRAB; a grab passes when a walk-out
-- try got AWAY studs, else WEDGED.
function BotWalk.judgeGrab(climbed: boolean, distances: { number }): (boolean, string)
	if not climbed then
		return false, "NO_GRAB"
	end
	if gotAway(distances) then
		return true, "OK"
	end
	return false, "WEDGED"
end

return BotWalk
