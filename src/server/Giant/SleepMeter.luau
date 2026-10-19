--!strict
-- The giant's sleep meter, one step at a time. Pure maths: it is given numbers and returns numbers.
-- Every number comes from Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Contribution = {
	id: number, -- the player's UserId
	noise: number, -- points to add now
	canBeSaved: boolean, -- true while this player is new and still has their free save
}

export type Result = {
	value: number,
	woke: boolean,
	wokenBy: number?,
	saved: { number }, -- the UserIds whose free save was spent in this step; always empty when he woke
}

local SleepMeter = {}

function SleepMeter.drainPerSecond(playerCount: number): number
	if playerCount == 1 then
		return Config.Meter.SoloDrain
	end
	return Config.Meter.DrainPerPlayer * playerCount
end

function SleepMeter.add(value: number, phase: Config.Phase, contributions: { Contribution }): Result
	-- The meter is locked unless he is asleep.
	if phase ~= "Asleep" then
		return { value = value, woke = false, wokenBy = nil, saved = {} }
	end
	local current = value
	-- Biggest noise first. Equal noise: the lower id first. Sort a copy, so the caller's list stays as it was.
	local ordered = table.clone(contributions)
	table.sort(ordered, function(a, b)
		if a.noise ~= b.noise then
			return a.noise > b.noise
		end
		return a.id < b.id
	end)
	local saved: { number } = {}
	local savedIds: { [number]: boolean } = {}
	for _, contribution in ordered do
		current += contribution.noise
		if current >= Config.Meter.Max then
			-- A player is saved once per step: a second share that fills the meter wakes him, naming that player.
			if contribution.canBeSaved and not savedIds[contribution.id] then
				savedIds[contribution.id] = true
				table.insert(saved, contribution.id)
				current = Config.Meter.FreeSaveMeter
			else
				-- A save is spent only if he is still asleep at the end of the step (Rule 19), so a wake spends none.
				return { value = Config.Meter.Max, woke = true, wokenBy = contribution.id, saved = {} }
			end
		end
	end
	return { value = current, woke = false, wokenBy = nil, saved = saved }
end

function SleepMeter.drain(value: number, phase: Config.Phase, playerCount: number, dt: number): number
	if phase ~= "Asleep" then
		return value
	end
	return math.max(0, value - SleepMeter.drainPerSecond(playerCount) * dt)
end

-- One tick: the drain comes off first, then the noise goes on.
function SleepMeter.step(
	value: number,
	phase: Config.Phase,
	contributions: { Contribution },
	playerCount: number,
	dt: number
): Result
	return SleepMeter.add(SleepMeter.drain(value, phase, playerCount, dt), phase, contributions)
end

return SleepMeter
