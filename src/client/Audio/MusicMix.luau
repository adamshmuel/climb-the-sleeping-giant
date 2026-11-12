--!strict
-- What the music should be doing (V2 spec 7, Rule 89: Music follows the meter; Rule 93: Chase music; section 5 "Music
-- change fade", "Thinned music", "Silence at 85%", "Chase tune start"). Pure: no services, no instances, no clock of
-- its own. Music (Task 6) feeds `step` every frame with the giant's state and the server time, and applies the answer.
--   * calm, chase: 0 to 1 (Task 6 multiplies by the row's volume). muffled: 0 clear, 1 fully muffled.
--   * chaseFileTime: where the chase file should be, nil while the chase isn't due.
--   * every value moves toward its target by at most dt / MusicFadeSeconds a step; the music button off cuts at once.
-- The mixer is a brand-new player's: calm and chase start at 0, muffled starts at its target (no filter sweep on joining).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Bubble85 = require(script.Parent.Parent.Fx.Bubble85)
local SoundList = require(script.Parent.SoundList)

export type Input = {
	phase: Config.Phase,
	meter: number, -- the giant's Meter attribute, 0 to 100
	phaseEndsAt: number?, -- PhaseEndsAt, server time; set while Awake
	warningAt: number?, -- server time of the latest 85% warning, first or replayed (nil = none yet)
	inGarden: boolean,
	musicOn: boolean,
	now: number, -- server time
}

export type Mix = { calm: number, chase: number, muffled: number, chaseFileTime: number? }

type Fields = {
	calm: number,
	chase: number,
	muffled: number,
	lastNow: number?, -- nil until the first step
	warning: number?, -- the 85% warning that is still holding the music silent (its start, server time)
	handledWarning: number?, -- the last warningAt value taken in, so a forgotten warning never starts again
}

local Mixer = {}
Mixer.__index = Mixer

export type Mixer = typeof(setmetatable({} :: Fields, Mixer))

local MusicMix = {}

local THINNED_FROM = Config.Meter.WarningMarks[1] -- 60: the thinned, muffled tune
local SILENT_FROM = Config.Meter.WarningMarks[2] -- 85: the silence
-- The silence ends once the meter is under this (75): the point the warning rearms (Rule 89).
local SILENT_UNTIL_UNDER = SILENT_FROM - Config.Meter.WarningRearmDrop
-- Reduce Motion never changes a sound (Rule 88), so the warning is the bubble's full length, 3.3 s.
local WARNING_SECONDS = Bubble85.showSeconds(false)
-- Decimal sums like 1000.3 - 1000 come out a hair off; anything closer than this to a time counts as on it.
local ROUNDING = 1e-6

local function approach(value: number, target: number, step: number): number
	if value < target then
		return math.min(target, value + step)
	end
	return math.max(target, value - step)
end

-- Takes in a new warning, and forgets the held one once it has ended and the meter is under 75.
local function updateWarning(self: Mixer, input: Input)
	local at = input.warningAt
	if at ~= nil and at ~= self.handledWarning then
		self.warning = at
		self.handledWarning = at
	end
	local held = self.warning
	if held ~= nil and input.now >= held + WARNING_SECONDS - ROUNDING and input.meter < SILENT_UNTIL_UNDER then
		self.warning = nil
	end
end

-- Where the chase file should be: its loop part start plus the time since the chase began, wrapped inside the loop.
local function chaseFileTime(input: Input): number?
	if input.phase ~= "Awake" or input.phaseEndsAt == nil then
		return nil
	end
	local row = SoundList.byName("Chase tune (loop)")
	if row == nil or row.loopStart == nil or row.loopEnd == nil then
		return nil
	end
	local wake = input.phaseEndsAt - Config.Wake.AwakeSeconds
	local elapsed = input.now - wake - Config.Audio.ChaseStartSeconds
	if elapsed < -ROUNDING then
		return nil
	end
	local length = row.loopEnd - row.loopStart
	return row.loopStart + math.max(elapsed, 0) % length
end

function MusicMix.new(): Mixer
	local fields: Fields = { calm = 0, chase = 0, muffled = 0, lastNow = nil, warning = nil, handledWarning = nil }
	return setmetatable(fields, Mixer)
end

function Mixer.step(self: Mixer, input: Input): Mix
	updateWarning(self, input)
	local first = self.lastNow == nil
	local dt = math.max(0, if self.lastNow ~= nil then input.now - self.lastNow else 0)
	self.lastNow = input.now
	local step = dt / Config.Audio.MusicFadeSeconds
	local thinned = Config.Audio.ThinnedMusicFactor

	local fileTime = chaseFileTime(input)
	local calmTarget = 0
	local chaseTarget = 0
	local mutedTarget = 0
	if input.phase == "Awake" then
		if fileTime ~= nil then
			chaseTarget = if input.inGarden then thinned else 1
		end
		mutedTarget = if input.inGarden then 1 else 0
	elseif input.phase == "HeavySleep" then
		calmTarget = 1
	else
		local silent = input.meter >= SILENT_FROM or self.warning ~= nil
		if not silent then
			calmTarget = if input.meter >= THINNED_FROM then thinned else 1
		end
		mutedTarget = if input.meter >= THINNED_FROM then 1 else 0
	end

	if first then
		self.muffled = mutedTarget -- the first step of a new mixer: no filter sweep on joining
	end
	self.muffled = approach(self.muffled, mutedTarget, step)
	if not input.musicOn then
		self.calm = 0
		self.chase = 0
		return { calm = 0, chase = 0, muffled = self.muffled, chaseFileTime = nil }
	end
	self.calm = approach(self.calm, calmTarget, step)
	self.chase = approach(self.chase, chaseTarget, step)
	return { calm = self.calm, chase = self.chase, muffled = self.muffled, chaseFileTime = fileTime }
end

return MusicMix
