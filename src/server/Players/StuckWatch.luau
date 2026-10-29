--!strict
-- Watches who presses to move but doesn't get anywhere (Rule 28). Pure: no services and no clock, the caller gives
-- the time. A player is "stuck" after pressing for StuckSeconds with the body moving less than StuckDistance, on the
-- giant, and free to move. Being blocked (falling, floating down, standing in a red circle that hasn't landed) is not
-- stuck, and neither is being held still after a rescue while still pressing: the watch starts again when it ends.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Input = { pressing: boolean, position: Vector3, onGiant: boolean, blocked: boolean, held: boolean }
type Start = { position: Vector3, at: number }
export type Watch = {
	update: (self: Watch, userId: number, input: Input, now: number) -> boolean,
	forget: (self: Watch, userId: number) -> (),
	_starts: { [number]: Start },
}

local StuckWatch = {}
local methods = {}
local meta = { __index = methods }

function StuckWatch.new(): Watch
	local watch = { _starts = {} }
	return setmetatable(watch, meta) :: any
end

-- True when the player should be rescued now. The watch then starts again from here.
function methods.update(self: Watch, userId: number, input: Input, now: number): boolean
	if not input.pressing or not input.onGiant or input.blocked or input.held then
		self._starts[userId] = nil
		return false
	end
	local start = self._starts[userId]
	if start == nil or (input.position - start.position).Magnitude >= Config.Stuck.StuckDistance then
		self._starts[userId] = { position = input.position, at = now }
		return false
	end
	if now - start.at >= Config.Stuck.StuckSeconds then
		self._starts[userId] = { position = input.position, at = now }
		return true
	end
	return false
end

function methods.forget(self: Watch, userId: number)
	self._starts[userId] = nil
end

return StuckWatch
