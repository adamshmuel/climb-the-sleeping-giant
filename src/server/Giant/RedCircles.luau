--!strict
-- The red circles that have been shown and haven't landed yet (Rule 28). A rescue waits while the player stands in one.
-- Pure: no services and no clock. `landsAt` and `now` are in the same clock (the server time the giant's warnings use).

local Slams = require(script.Parent.Slams)

type Circle = { centre: Vector3, landsAt: number }
export type Circles = {
	add: (self: Circles, point: Vector3, landsAt: number) -> (),
	covers: (self: Circles, position: Vector3, now: number) -> boolean,
	_circles: { Circle },
}

local RedCircles = {}
local methods = {}
local meta = { __index = methods }

function RedCircles.new(): Circles
	return setmetatable({ _circles = {} }, meta) :: any
end

function methods.add(self: Circles, point: Vector3, landsAt: number)
	table.insert(self._circles, { centre = point, landsAt = landsAt })
end

-- True when the position is inside a circle that hasn't landed yet. Landed circles are dropped on the way.
function methods.covers(self: Circles, position: Vector3, now: number): boolean
	local circles = self._circles
	local covered = false
	local keep = 0
	for i = 1, #circles do
		local circle = circles[i]
		if circle.landsAt > now then
			keep += 1
			circles[keep] = circle
			if Slams.inCircle(position, circle.centre) then
				covered = true
			end
		end
	end
	for i = #circles, keep + 1, -1 do
		circles[i] = nil
	end
	return covered
end

return RedCircles
