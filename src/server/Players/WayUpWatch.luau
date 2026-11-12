--!strict
-- Says when a player has climbed a way up (plan 3 Task 16; spec 3 section 10, "Success signals"). Pure: it reads
-- Vector3s and zone names only. A sample's position is the player's root, a little above the feet. `check` takes one
-- tick (one sample per player) and returns a "reached" line for each player who is at a way up's top now and has been
-- in the Meadow zone since the last reach (armed). A climb reports Boots for many ticks before the top, so the Meadow
-- tick need not be the one just before. Staying at the top, or walking on to the boot top and back, says nothing more;
-- a Meadow tick arms it again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

type ZoneName = Config.ZoneName

export type Sample = { userId: number, position: Vector3, zone: ZoneName }
export type Top = { name: string, top: Vector3 }
export type Reached = { userId: number, name: string }
export type Watch = {
	check: (self: Watch, samples: { Sample }) -> { Reached },
	lastOf: (self: Watch, userId: number) -> string?,
	forget: (self: Watch, userId: number) -> (),
}

type PlayerState = { armed: boolean, last: string? }

local ACROSS = 4 -- studs, flat, a player may be from a top and still be at it (plan 3 Task 16 details, "Step 1 tests")
local UP_DOWN = 3 -- studs up or down a player may be from a top and still be at it (same place)
-- A standing root is HipHeight + half the root above the feet; measured 3.0-3.46 at the Left ramp top (p3t16 Step 3).
local ROOT_ABOVE_FEET = 3

local WayUpWatch = {}

local function atTop(position: Vector3, top: Vector3): boolean
	local across = Vector3.new(position.X - top.X, 0, position.Z - top.Z).Magnitude
	return across <= ACROSS and math.abs(position.Y - ROOT_ABOVE_FEET - top.Y) <= UP_DOWN
end

function WayUpWatch.new(tops: { Top }): Watch
	local players: { [number]: PlayerState } = {}
	local watch = {} :: Watch

	function watch.check(_self: Watch, samples: { Sample }): { Reached }
		local reached: { Reached } = {}
		for _, sample in samples do
			local state = players[sample.userId]
			if state == nil then
				state = { armed = false, last = nil }
				players[sample.userId] = state
			end
			if sample.zone == "Meadow" then
				state.armed = true
			elseif state.armed then
				for _, wayUp in tops do
					if atTop(sample.position, wayUp.top) then
						state.last = wayUp.name
						state.armed = false
						table.insert(reached, { userId = sample.userId, name = wayUp.name })
						break
					end
				end
			end
		end
		return reached
	end

	function watch.lastOf(_self: Watch, userId: number): string?
		local state = players[userId]
		return if state then state.last else nil
	end

	function watch.forget(_self: Watch, userId: number)
		players[userId] = nil
	end

	return watch
end

return WayUpWatch
