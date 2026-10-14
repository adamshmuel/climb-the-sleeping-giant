--!strict
-- Turns the giant's state into what the sleep meter shows: the face, the words, the bar and how full it is.
-- It is the table "The sleep meter (top centre)" in spec section 6. Pure: the time is passed in, never read here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MeterView = {}

-- The five rows of the spec table.
export type Row = "Sleeping" | "Stirring" | "WakingUp" | "Awake" | "HeavySleep"
-- How the bar looks: green to yellow, solid yellow, orange, red, or blue stripes.
export type BarStyle = "GreenToYellow" | "Yellow" | "Orange" | "Red" | "BlueStripes"

export type Look = {
	row: Row,
	face: string,
	label: string,
	barStyle: BarStyle,
	fill: number, -- 0 to 1: how much of the bar is filled
	locked: boolean, -- Heavy Sleep shows a lock on the bar
	refreshIn: number?, -- seconds until the words change by themselves (a countdown); nil if they won't
}

local STIRRING_AT = Config.Meter.WarningMarks[1]
local WAKING_UP_AT = Config.Meter.WarningMarks[2]

-- A tiny extra wait so a refresh lands just after the shown second changes, never just before it.
local REFRESH_MARGIN = 0.02

local PHASES: { [string]: Config.Phase } = { Asleep = "Asleep", Awake = "Awake", HeavySleep = "HeavySleep" }

-- Seconds still to wait, rounded up, never below 0. If the end time is missing, the phase's full time.
local function secondsLeft(phaseEndsAt: number?, now: number, fullSeconds: number): number
	if phaseEndsAt == nil then
		return fullSeconds
	end
	return math.max(0, math.ceil(phaseEndsAt - now))
end

-- True while the label shows a countdown, so the screen only needs to refresh every second in these phases.
function MeterView.countsDown(phase: Config.Phase): boolean
	return phase == "Awake" or phase == "HeavySleep"
end

-- What the meter shows for a meter value (0 to 100), the giant's phase, when the phase ends (on the server
-- clock, if known) and what time it is on that clock now.
function MeterView.read(meter: number, phase: Config.Phase, phaseEndsAt: number?, now: number): Look
	if phase == "Awake" then
		local left = secondsLeft(phaseEndsAt, now, Config.Wake.AwakeSeconds)
		return {
			row = "Awake",
			face = "😠",
			label = `AWAKE! Back to sleep in {Format.countdown(left)}`,
			barStyle = "Red",
			fill = 1,
			locked = false,
			refreshIn = MeterView.secondsUntilTextChanges(phase, phaseEndsAt, now),
		}
	elseif phase == "HeavySleep" then
		local left = secondsLeft(phaseEndsAt, now, Config.Wake.HeavySleepSeconds)
		return {
			row = "HeavySleep",
			face = "😪",
			label = `Heavy Sleep · safe for {Format.countdown(left)}`,
			barStyle = "BlueStripes",
			fill = 1,
			locked = true,
			refreshIn = MeterView.secondsUntilTextChanges(phase, phaseEndsAt, now),
		}
	end

	local fill = math.clamp(meter / Config.Meter.Max, 0, 1)
	if meter >= WAKING_UP_AT then
		return {
			row = "WakingUp",
			face = "😟",
			label = "He's waking up! Tiptoe!",
			barStyle = "Orange",
			fill = fill,
			locked = false,
		}
	elseif meter >= STIRRING_AT then
		return {
			row = "Stirring",
			face = "😔",
			label = "He's stirring... tiptoe!",
			barStyle = "Yellow",
			fill = fill,
			locked = false,
		}
	end
	return {
		row = "Sleeping",
		face = "😴",
		label = "Giant is sleeping",
		barStyle = "GreenToYellow",
		fill = fill,
		locked = false,
	}
end

-- How long to wait before the countdown text next changes, so the screen is refreshed once per shown second
-- and not more. nil when the text will not change by itself: he is asleep, the end time is missing, or the
-- time has run out.
function MeterView.secondsUntilTextChanges(phase: Config.Phase, phaseEndsAt: number?, now: number): number?
	if not MeterView.countsDown(phase) or phaseEndsAt == nil then
		return nil
	end
	local remaining = phaseEndsAt - now
	if remaining <= 0 then
		return nil
	end
	-- The text shows `ceil(remaining)`. It changes once `remaining` falls to one second less than that.
	return remaining - (math.ceil(remaining) - 1) + REFRESH_MARGIN
end

-- The same, from raw attribute values. An attribute can be missing or the wrong type (a value is only trusted
-- once checked), so anything odd falls back to an empty, sleeping meter.
function MeterView.fromAttributes(meterValue: any, phaseValue: any, phaseEndsAtValue: any, now: number): Look
	-- (A number that is not equal to itself is NaN, "not a number".)
	local isNumber = type(meterValue) == "number" and meterValue == meterValue
	local meter = if isNumber then math.clamp(meterValue, 0, Config.Meter.Max) else 0
	local phase: Config.Phase = if type(phaseValue) == "string" and PHASES[phaseValue]
		then PHASES[phaseValue]
		else "Asleep"
	local phaseEndsAt = if type(phaseEndsAtValue) == "number" then phaseEndsAtValue else nil
	return MeterView.read(meter, phase, phaseEndsAt, now)
end

return MeterView
