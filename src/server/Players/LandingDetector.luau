--!strict
-- Follows each player's fall and says when it ends with a thud. Pure: it is given what the character is doing
-- this tick and returns the new state, so it touches no players, parts or clocks.
--
-- A fall starts after a few ticks in the air, lasts while the player slides or drops, and ends once the player
-- is back on standable ground and has stopped moving up or down. It makes one thud, sized by the highest zone
-- the player was in on the ground since they were last at rest, up to the moment the fall started. A jump starts
-- a fall on the spot and always thuds; a fall without a jump thuds only if it went fast. Time in the
-- air never raises it (the zone boxes reach out over the meadow) and nothing changes it once the fall has started.
-- A new jump while a fall is under way means that fall has landed (a Humanoid only jumps from the ground, a ladder
-- or water), so it thuds then, even with Jump held down and under 0.3 s on the ground between hops. A jump's zone
-- is the zone it took off from (docs/architecture.md, section 3: "How is a jump or fall's noise found?").
-- Climbing a ladder never thuds: a fall that a ladder catches is cancelled, and the count starts again from the
-- zone the player is in (the ground check finds nothing below a ladder, so it can't tell a climb from a drop).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(script.Parent.Parent.Giant.Zones)

export type State = {
	airTicks: number, -- ticks in a row in the air; counts up to AIR_TICKS, then the fall has started
	falling: boolean, -- a fall is under way
	fellFast: boolean, -- the fall (or the air time before it) went faster than FAST_FALL downward
	jumped: boolean, -- the fall began with a jump, which always thuds, however slowly it fell
	fromClimb: boolean, -- the fall began straight from a climb; set while climbing, cleared by a grounded tick
	-- the highest zone they were in on the ground since they were last at rest; frozen once the fall starts
	highest: Config.ZoneName,
	restTicks: number, -- ticks in a row at rest on standable ground; 3 reset `highest` (and end a fall)
	-- thuds that were due on one tick with another, oldest first. One is returned per tick, before any new thud.
	owed: { Config.ZoneName },
}

-- A fall that started on the cap, a cap tie or a tie's landing and ended on the giant (Task 61d). `thudded` is
-- false for a head drop (no thud), true for a jump or a drop that ended elsewhere.
export type Drop = { from: Config.ZoneName, to: Config.ZoneName, jumped: boolean, thudded: boolean }

-- A fall starts after this many ticks in a row in the air (0.3 s). One missed ground check while walking down
-- a slope is not a fall.
local AIR_TICKS = 3
-- A fall ends after this many ticks in a row at rest on standable ground (0.3 s).
local REST_TICKS = 3
-- "At rest" means going up or down by no more than this many studs per second.
local REST_SPEED = 2
-- The fall makes a thud only if it went faster than this many studs per second downward at some point.
-- Climbing a ladder and small steps never do.
local FAST_FALL = 10

-- The most thuds kept waiting. A real player never has more than 1 waiting; 4 keeps the backlog from spamming
-- Jumping states for 0.4 s, and stops a device that fakes 4 jumps a tick from growing the list without end.
local MAX_OWED = 4

local LandingDetector = {}

-- A player standing in `zone`.
function LandingDetector.new(zone: Config.ZoneName): State
	return {
		airTicks = 0,
		falling = false,
		fellFast = false,
		jumped = false,
		fromClimb = false,
		highest = zone,
		restTicks = 0,
		owed = {},
	}
end

-- Is the player on standable ground and going up or down by no more than REST_SPEED? The one place this rule lives.
function LandingDetector.isAtRest(grounded: boolean, verticalSpeed: number): boolean
	return grounded and math.abs(verticalSpeed) <= REST_SPEED
end

local function listHas(list: { Config.ZoneName }, zone: Config.ZoneName): boolean
	return table.find(list, zone) ~= nil
end

-- Hands out the first thud that is due, and keeps the rest in the state to come one a tick on the next ticks.
local function oneThud(due: { Config.ZoneName }, state: State, drop: Drop?): (Config.ZoneName?, State, Drop?)
	local thud: Config.ZoneName? = due[1]
	table.remove(due, 1)
	while #due > MAX_OWED do
		table.remove(due) -- keep the oldest, drop the newest
	end
	state.owed = due
	return thud, state, drop
end

-- Takes one 0.1 s tick: is the player on standable ground, how fast are they going up (+) or down (-), which zone
-- are they in, and the zones they took off from in jumps since the last tick (oldest first, usually none or one).
-- Returns the zone to thud from (the highest zone the fall left) when a fall that began with a jump, or went fast,
-- ends, otherwise nil, and the new state. A third value is the drop report when a fall from the cap, a cap tie or a
-- tie's landing (or a let-go straight from a climb) ends on the giant or his head: a fast fall without a jump in
-- those zones adds no thud when it ends on the giant (HeadDropTo), a jump from them still thuds. At most one thud a tick: more are kept to come on the next ticks.
-- `climbing` is true while the Humanoid is in its Climbing state. `onCapTie` (optional) says the climber is on a cap
-- tie: that climb counts as from the head at any height (Task 61h). A fall with no jump from the head is also quiet
-- when it ends on the cap (Nightcap), with a drop report.
function LandingDetector.step(
	state: State,
	grounded: boolean,
	verticalSpeed: number,
	zone: Config.ZoneName,
	takeoffs: { Config.ZoneName },
	climbing: boolean,
	onCapTie: boolean?
): (Config.ZoneName?, State, Drop?)
	local fellFast = state.fellFast or verticalSpeed < -FAST_FALL
	local atRest = LandingDetector.isAtRest(grounded, verticalSpeed)
	local restTicks = if atRest then state.restTicks + 1 else 0
	local due = table.clone(state.owed)

	if #takeoffs > 0 then
		-- The fall as it stands before each take-off. A jump needs no 0.3 s in the air: an uphill jump on the steep
		-- belly is in the air for less than that.
		local falling, jumped, wentFast = state.falling, state.jumped, fellFast
		local highest: Config.ZoneName = state.highest
		local justLanded = false
		for _, takeoff: Config.ZoneName in takeoffs do
			if falling then
				-- A fall under way has landed: a jump always thuds, a fall without one only if it went fast.
				if jumped or wentFast then
					table.insert(due, highest)
				end
				justLanded = true
			end
			-- The new jump starts from its take-off zone, raised by the highest zone so far only if they didn't just
			-- land and didn't just rest.
			highest = if justLanded or restTicks >= REST_TICKS then takeoff else Zones.higher(highest, takeoff)
			falling, jumped, wentFast = true, true, false
		end
		return oneThud(due, {
			airTicks = AIR_TICKS,
			falling = true,
			fellFast = wentFast,
			jumped = true,
			fromClimb = false,
			highest = highest,
			restTicks = 0,
			owed = due,
		})
	end

	if climbing then
		-- A ladder caught them: no fall, no air count, and no zones from before the climb.
		return oneThud(due, {
			airTicks = 0,
			falling = false,
			fellFast = false,
			jumped = false,
			fromClimb = state.fromClimb or onCapTie == true or listHas(Config.Noise.HeadDropFrom, zone),
			highest = zone,
			restTicks = 0,
			owed = due,
		})
	end

	if state.falling then
		if restTicks >= REST_TICKS then
			local fromHead = state.fromClimb or listHas(Config.Noise.HeadDropFrom, state.highest)
			local toGiant = listHas(Config.Noise.HeadDropTo, zone)
			-- With no jump, the cap itself is a quiet landing too (no height limit).
			local quiet = fellFast and not state.jumped and fromHead and (toGiant or zone == "Nightcap")
			local thuds = (fellFast or state.jumped) and not quiet
			if thuds then
				table.insert(due, state.highest)
			end
			local drop: Drop? = nil
			if fellFast and fromHead and not state.jumped then
				drop = { from = state.highest, to = zone, jumped = false, thudded = thuds }
			elseif state.jumped and listHas(Config.Noise.HeadDropFrom, state.highest) and toGiant then
				drop = { from = state.highest, to = zone, jumped = true, thudded = true }
			end
			return oneThud(due, LandingDetector.new(zone), drop)
		end
		return oneThud(due, {
			airTicks = state.airTicks,
			falling = true,
			fellFast = fellFast,
			jumped = state.jumped,
			fromClimb = state.fromClimb,
			highest = state.highest,
			restTicks = restTicks,
			owed = due,
		})
	end

	if grounded then
		-- The highest zone if they are on the ground this tick: a rest of REST_TICKS forgets the zones before it.
		local groundedHighest: Config.ZoneName = if restTicks >= REST_TICKS
			then zone
			else Zones.higher(state.highest, zone)
		-- A tick on the ground before the fall starts never counts as fast, and it cancels the air count.
		return oneThud(due, {
			airTicks = 0,
			falling = false,
			fellFast = false,
			jumped = false,
			fromClimb = false,
			highest = groundedHighest,
			restTicks = restTicks,
			owed = due,
		})
	end

	local airTicks = state.airTicks + 1
	return oneThud(due, {
		airTicks = airTicks,
		falling = airTicks >= AIR_TICKS,
		fellFast = fellFast,
		jumped = false,
		fromClimb = state.fromClimb,
		highest = state.highest,
		restTicks = 0,
		owed = due,
	})
end

return LandingDetector
