--!strict
-- The giant's sleep meter, one step at a time. Pure maths: it is given numbers and returns numbers.
-- Every number comes from Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Contribution = {
	id: number, -- the player's UserId
	noise: number, -- points to add now
	eggsHome: number, -- eggs this player banked this session
}

export type Result = {
	value: number,
	woke: boolean,
	wokenBy: number?,
}

local SleepMeter = {}

function SleepMeter.drainPerSecond(playerCount: number): number
	return Config.Meter.DrainPerPlayer * playerCount
end

function SleepMeter.add(value: number, phase: Config.Phase, contributions: { Contribution }): Result
	-- The meter is locked unless he is asleep.
	if phase ~= "Asleep" then
		return { value = value, woke = false, wokenBy = nil }
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
	for _, contribution in ordered do
		if contribution.eggsHome < Config.Meter.NewPlayerEggsNeeded then
			-- A new player can only push the meter up to the cap, and never pulls it down from above it.
			if current < Config.Meter.NewPlayerCap then
				current = math.min(current + contribution.noise, Config.Meter.NewPlayerCap)
			end
		else
			current += contribution.noise
		end
		if current >= Config.Meter.Max then
			return { value = Config.Meter.Max, woke = true, wokenBy = contribution.id }
		end
	end
	return { value = current, woke = false, wokenBy = nil }
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
