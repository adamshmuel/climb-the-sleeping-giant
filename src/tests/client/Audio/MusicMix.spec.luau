--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local MusicMix = require(StarterPlayer.StarterPlayerScripts.Client.Audio.MusicMix)

-- Float numbers like 0.1 * 5 compare to about 0.01 (luau.md, "Test first").
local PRECISION = 2
local DT = 0.1 -- the fake clock steps by 0.1 s, like a slow frame
local START = 1000 -- server time when a test begins
local WARNING = 3.3 -- Bubble85.showSeconds(false)
local AWAKE = Config.Wake.AwakeSeconds
local CHASE_START = Config.Audio.ChaseStartSeconds

type Overrides = {
	phase: Config.Phase?,
	meter: number?,
	phaseEndsAt: number?,
	warningAt: number?,
	inGarden: boolean?,
	musicOn: boolean?,
}

type Rig = {
	mixer: MusicMix.Mixer,
	ticks: number,
	base: number,
	now: (self: Rig) -> number,
	step: (self: Rig, o: Overrides) -> MusicMix.Mix,
	run: (self: Rig, seconds: number, o: Overrides) -> (MusicMix.Mix, { MusicMix.Mix }),
}

-- A brand-new mixer and clock for every test. `step` feeds one frame at the current time, then moves the clock on.
local function newRig(base: number?): Rig
	local rig: Rig
	rig = {
		mixer = MusicMix.new(),
		ticks = 0,
		base = base or START,
		now = function(self: Rig): number
			return self.base + self.ticks / 10
		end,
		step = function(self: Rig, o: Overrides): MusicMix.Mix
			local mix = self.mixer:step({
				phase = o.phase or "Asleep",
				meter = o.meter or 10,
				phaseEndsAt = o.phaseEndsAt,
				warningAt = o.warningAt,
				inGarden = o.inGarden == true,
				musicOn = o.musicOn ~= false,
				now = self:now(),
			})
			self.ticks += 1
			return mix
		end,
		run = function(self: Rig, seconds: number, o: Overrides): (MusicMix.Mix, { MusicMix.Mix })
			local all: { MusicMix.Mix } = {}
			local last: MusicMix.Mix = { calm = 0, chase = 0, muffled = 0 }
			for _ = 1, math.round(seconds / DT) do
				last = self:step(o)
				table.insert(all, last)
			end
			return last, all
		end,
	}
	return rig
end

local function awake(wake: number, extra: Overrides?): Overrides
	local o: Overrides = { phase = "Awake", meter = 100, phaseEndsAt = wake + AWAKE }
	if extra then
		for key, value in extra :: any do
			(o :: any)[key] = value
		end
	end
	return o
end

describe("MusicMix", function()
	describe("1. asleep under 60%", function()
		it("plays the calm tune full and clear, with no chase", function()
			local rig = newRig()
			local mix = rig:run(1.2, { meter = 10 })
			expect(mix.calm).toBeCloseTo(1, PRECISION)
			expect(mix.muffled).toBeCloseTo(0, PRECISION)
			expect(mix.chase).toBeCloseTo(0, PRECISION)
			expect(mix.chaseFileTime).toBe(nil)
		end)
	end)

	describe("2. passing 60%", function()
		it("fades the calm tune to half and fully muffled over 1 s", function()
			local rig = newRig()
			rig:run(1.2, { meter = 50 })
			local midway = rig:run(0.5, { meter = 65 })
			expect(midway.muffled).toBeCloseTo(0.5, PRECISION)
			local mix = rig:run(0.5, { meter = 65 })
			expect(mix.calm).toBeCloseTo(Config.Audio.ThinnedMusicFactor, PRECISION)
			expect(mix.muffled).toBeCloseTo(1, PRECISION)
		end)

		it("never moves the calm tune by more than one frame's share of the fade", function()
			local rig = newRig()
			rig:run(1.2, { meter = 50 })
			local _, steps = rig:run(1.2, { meter = 65 })
			local previous = 1
			for _, step in steps do
				expect(math.abs(step.calm - previous) <= DT + 0.01).toBe(true)
				previous = step.calm
			end
		end)

		it("fades back to full and clear over 1 s when the meter falls under 60%", function()
			local rig = newRig()
			rig:run(1.2, { meter = 65 })
			local mix = rig:run(1.1, { meter = 55 })
			expect(mix.calm).toBeCloseTo(1, PRECISION)
			expect(mix.muffled).toBeCloseTo(0, PRECISION)
		end)
	end)

	describe("3. passing 85%", function()
		it("is silent by 1 s, stays silent at 80%, and returns to the thinned half at 74%", function()
			local rig = newRig()
			rig:run(1.2, { meter = 50 })
			local warningAt = rig:now()
			local mix = rig:run(1.0, { meter = 90, warningAt = warningAt })
			expect(mix.calm).toBeCloseTo(0, PRECISION)
			mix = rig:run(3.0, { meter = 80, warningAt = warningAt })
			expect(rig:now() - warningAt > WARNING).toBe(true) -- the warning has ended, the meter is still 75 or more
			expect(mix.calm).toBeCloseTo(0, PRECISION)
			mix = rig:run(1.2, { meter = 74, warningAt = warningAt })
			expect(mix.calm).toBeCloseTo(Config.Audio.ThinnedMusicFactor, PRECISION)
			expect(mix.muffled).toBeCloseTo(1, PRECISION)
		end)
	end)

	describe("4. a player who joins at 90%", function()
		it("hears silence from the first frame", function()
			local rig = newRig()
			local mix = rig:step({ meter = 90 })
			expect(mix.calm).toBeCloseTo(0, PRECISION)
			mix = rig:run(1.0, { meter = 90 })
			expect(mix.calm).toBeCloseTo(0, PRECISION)
		end)

		it("hears the tune fade in once the meter is under 60%", function()
			local rig = newRig()
			rig:run(1.0, { meter = 90 })
			local mix = rig:run(1.2, { meter = 50 })
			expect(mix.calm).toBeCloseTo(1, PRECISION)
		end)
	end)

	describe("5. awake", function()
		it("starts the chase tune 1 s after the wake, 0.3 s into its file", function()
			local wake = START + 5
			local rig = newRig()
			rig:run(5.0, { meter = 50 })
			local before = rig:run(CHASE_START, awake(wake)) -- the frames at 0 to 0.9 s after the wake
			expect(before.chaseFileTime).toBe(nil)
			expect(before.chase).toBeCloseTo(0, PRECISION)
			local mix = rig:step(awake(wake))
			expect(mix.chaseFileTime :: number).toBeCloseTo(0.3, PRECISION)
			local later = rig:run(1.1, awake(wake))
			expect(later.chase).toBeCloseTo(1, PRECISION)
			expect(later.calm).toBeCloseTo(0, PRECISION)
		end)

		it("puts a player who joins 6 s into the wake 5.3 s into the file", function()
			local wake = START
			local rig = newRig(wake + 6)
			local mix = rig:step(awake(wake))
			expect(mix.chaseFileTime :: number).toBeCloseTo(5.3, PRECISION)
		end)
	end)

	describe("6. awake in a garden", function()
		it("plays the chase tune at half loudness and muffled within 1 s, full again outside", function()
			local wake = START + 1
			local rig = newRig()
			rig:run(1.0, { meter = 10, inGarden = true })
			local mix = rig:run(2.2, awake(wake, { inGarden = true }))
			expect(mix.chase).toBeCloseTo(Config.Audio.ThinnedMusicFactor, PRECISION)
			expect(mix.muffled).toBeCloseTo(1, PRECISION)
			mix = rig:run(1.1, awake(wake, { inGarden = false }))
			expect(mix.chase).toBeCloseTo(1, PRECISION)
			expect(mix.muffled).toBeCloseTo(0, PRECISION)
		end)
	end)

	describe("7. the lie-down", function()
		it("fades the chase tune out as the calm tune fades back in", function()
			local wake = START + 1
			local rig = newRig()
			rig:run(1.0, { meter = 10 })
			local mix = rig:run(3.0, awake(wake))
			expect(mix.chase).toBeCloseTo(1, PRECISION)
			mix = rig:run(0.5, { phase = "HeavySleep", meter = 70 })
			expect(mix.chase).toBeCloseTo(0.5, PRECISION)
			expect(mix.calm).toBeCloseTo(0.5, PRECISION)
			mix = rig:run(0.6, { phase = "HeavySleep", meter = 70 })
			expect(mix.chase).toBeCloseTo(0, PRECISION)
			expect(mix.calm).toBeCloseTo(1, PRECISION)
		end)

		it("plays the calm tune full and clear in Heavy Sleep, whatever the meter", function()
			local rig = newRig()
			rig:run(1.2, { meter = 65 })
			local mix = rig:run(1.2, { phase = "HeavySleep", meter = 65 })
			expect(mix.calm).toBeCloseTo(1, PRECISION)
			expect(mix.muffled).toBeCloseTo(0, PRECISION)
		end)
	end)

	describe("8. the music button off", function()
		it("silences both tunes at once and fades the calm tune back in from 0", function()
			local rig = newRig()
			local mix = rig:run(1.2, { meter = 10 })
			expect(mix.calm).toBeCloseTo(1, PRECISION)
			mix = rig:step({ meter = 10, musicOn = false })
			expect(mix.calm).toBe(0)
			expect(mix.chase).toBe(0)
			mix = rig:step({ meter = 10, musicOn = true })
			expect(mix.calm).toBeCloseTo(0.1, PRECISION)
		end)

		it("never starts the chase tune in a wake while it is off", function()
			local wake = START + 1
			local rig = newRig()
			rig:run(1.0, { meter = 10, musicOn = false })
			local mix = rig:run(4.0, awake(wake, { musicOn = false }))
			expect(mix.chase).toBe(0)
			expect(mix.chaseFileTime).toBe(nil)
			mix = rig:step(awake(wake, { musicOn = true }))
			expect(mix.chase).toBeCloseTo(0.1, PRECISION)
		end)
	end)

	describe("9. a free save at 88%", function()
		it("stays silent until the replayed warning ends, then returns to the tune for the meter", function()
			local rig = newRig()
			rig:run(1.2, { meter = 50 })
			local first = rig:now()
			rig:run(1.5, { meter = 88, warningAt = first })
			local replay = rig:now()
			-- The save drops the meter to 70 while the warning replays.
			local mix = rig:run(2.0, { meter = 70, warningAt = replay })
			expect(mix.calm).toBeCloseTo(0, PRECISION)
			mix = rig:run(1.0, { meter = 70, warningAt = replay })
			expect(rig:now() - replay < WARNING + 0.01).toBe(true)
			expect(mix.calm).toBeCloseTo(0, PRECISION)
			mix = rig:run(1.5, { meter = 70, warningAt = replay })
			expect(mix.calm).toBeCloseTo(Config.Audio.ThinnedMusicFactor, PRECISION)
			expect(mix.muffled).toBeCloseTo(1, PRECISION)
		end)
	end)
end)
