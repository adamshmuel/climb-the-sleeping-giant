--!strict
-- The giant's timeline after a wake-up (Rules 12 to 14). Pure maths: time comes in as a number, in seconds since he
-- woke (0 = the tick he woke). Every number comes from Config.Wake.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Slam = { number: number, warnAt: number, landsAt: number }

-- One thing that happens on the timeline. Which fields are filled depends on `kind`:
--   SlamWarning: slam, at (the warning), landsAt
--   SlamLanded:  slam, at (the landing)
--   Phase:       phase, at, and endsAt (HeavySleep) or meter (Asleep)
export type CycleEvent = {
	kind: "SlamWarning" | "SlamLanded" | "Phase",
	at: number,
	slam: number?,
	landsAt: number?,
	phase: Config.Phase?,
	endsAt: number?,
	meter: number?,
}

-- At the same time: a warning, then a landing, then a phase change (the 6th slam lands while he is still awake).
local ORDER = { SlamWarning = 1, SlamLanded = 2, Phase = 3 }

local GiantCycle = {}

local function heavySleepEndsAt(): number
	return Config.Wake.AwakeSeconds + Config.Wake.HeavySleepSeconds
end

-- The slams that land while he is awake (a landing exactly at the end of the awake time counts).
function GiantCycle.slams(): { Slam }
	local list: { Slam } = {}
	local number = 1
	while true do
		local warnAt = Config.Wake.FirstSlamWarningAt + (number - 1) * Config.Wake.SlamInterval
		local landsAt = warnAt + Config.Wake.SlamWarningSeconds
		if landsAt > Config.Wake.AwakeSeconds then
			break
		end
		table.insert(list, { number = number, warnAt = warnAt, landsAt = landsAt })
		number += 1
	end
	return list
end

-- The phase `seconds` after he woke, and how many seconds that phase has left (0 when Asleep).
function GiantCycle.phaseAt(seconds: number): (Config.Phase, number)
	if seconds < Config.Wake.AwakeSeconds then
		return "Awake", Config.Wake.AwakeSeconds - seconds
	end
	local endsAt = heavySleepEndsAt()
	if seconds < endsAt then
		return "HeavySleep", endsAt - seconds
	end
	return "Asleep", 0
end

-- Every event at a time t with fromSeconds < t <= toSeconds, in time order. Called once per tick with the last tick's
-- time and this tick's time, so no event is missed or sent twice, even after a long tick.
function GiantCycle.eventsBetween(fromSeconds: number, toSeconds: number): { CycleEvent }
	local all: { CycleEvent } = {}
	for _, slam in GiantCycle.slams() do
		table.insert(all, { kind = "SlamWarning", slam = slam.number, at = slam.warnAt, landsAt = slam.landsAt })
		table.insert(all, { kind = "SlamLanded", slam = slam.number, at = slam.landsAt })
	end
	table.insert(all, {
		kind = "Phase",
		phase = "HeavySleep",
		at = Config.Wake.AwakeSeconds,
		endsAt = heavySleepEndsAt(),
	})
	table.insert(all, { kind = "Phase", phase = "Asleep", at = heavySleepEndsAt(), meter = 0 })

	local inWindow: { CycleEvent } = {}
	for _, event in all do
		if fromSeconds < event.at and event.at <= toSeconds then
			table.insert(inWindow, event)
		end
	end
	table.sort(inWindow, function(a: CycleEvent, b: CycleEvent): boolean
		if a.at ~= b.at then
			return a.at < b.at
		end
		return ORDER[a.kind] < ORDER[b.kind]
	end)
	return inWindow
end

return GiantCycle
