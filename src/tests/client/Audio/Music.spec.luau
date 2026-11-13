--!strict
-- The music player (plan 7 Task 6; spec 7 Rule 89, Rule 93). Silent: the board is a fake that records its plays, the
-- step and the Warning remote are fake signals, and the clock is a number the test moves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Music = require(StarterPlayer.StarterPlayerScripts.Client.Audio.Music)
local SoundBoard = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundBoard)

-- Float numbers like 0.1 * 5 compare to about 0.01; a cutoff in Hz compares to about 1 (luau.md, "Test first").
local PRECISION = 2
local HZ_PRECISION = -1 -- within 5 Hz
local DT = 0.1 -- the fake clock steps by 0.1 s, like a slow frame
local START = 1000 -- server time when a test begins
local AWAKE = Config.Wake.AwakeSeconds
local CALM = "Calm tune (loop)"
local CHASE = "Chase tune (loop)"
local CLEAR = Config.Audio.ClearCutoffHz
local MUFFLED = Config.Audio.MuffledCutoffHz

type Play = { row: string, into: Instance?, copy: AudioPlayer }
type FakeSignal = {
	Connect: (self: FakeSignal, callback: (...any) -> ()) -> SoundBoard.Disconnectable,
	fire: (...any) -> (),
	count: () -> number, -- connections still live
}
type Rig = {
	root: Folder,
	giant: Folder,
	player: Folder,
	music: AudioFader, -- the fake board's Music bus
	plays: { Play },
	stops: { string },
	refuse: { count: number }, -- the next N plays return nil, as a board does while a file loads
	character: { spawned: boolean },
	step: FakeSignal,
	warning: FakeSignal,
	handle: Music.Handle,
	ticks: number,
	now: (self: Rig) -> number,
	run: (self: Rig, seconds: number) -> (),
	playsOf: (self: Rig, row: string) -> { Play },
	calm: (self: Rig) -> AudioFader,
	chase: (self: Rig) -> AudioFader,
	muffle: (self: Rig) -> AudioFilter,
}

local function newSignal(): FakeSignal
	local callbacks: { [(...any) -> ()]: boolean } = {}
	local live = 0
	local signal: FakeSignal
	signal = {
		Connect = function(_self: FakeSignal, callback: (...any) -> ()): SoundBoard.Disconnectable
			callbacks[callback] = true
			live += 1
			return {
				Disconnect = function()
					if callbacks[callback] then
						callbacks[callback] = nil
						live -= 1
					end
				end,
			}
		end,
		fire = function(...: any)
			for callback in table.clone(callbacks) do
				callback(...)
			end
		end,
		count = function(): number
			return live
		end,
	}
	return signal
end

local rigs: { Rig } = {}

-- A fresh player, fake board and clock for every test; the character has spawned unless the test says otherwise.
local function newRig(spawned: boolean?): Rig
	local root = Instance.new("Folder")
	local giant = Instance.new("Folder")
	giant:SetAttribute("Phase", "Asleep")
	giant:SetAttribute("Meter", 10)
	local player = Instance.new("Folder")
	player:SetAttribute("InGarden", 0)
	local musicBus = Instance.new("AudioFader")
	local plays: { Play } = {}
	local stops: { string } = {}
	local refuse = { count = 0 }
	local character = { spawned = spawned ~= false }
	local step = newSignal()
	local warning = newSignal()
	local rig: Rig
	local board: SoundBoard.Board = {
		play = function(rowName: string, _at: Vector3?, options: SoundBoard.PlayOptions?): AudioPlayer?
			if refuse.count > 0 then
				refuse.count -= 1
				return nil
			end
			local copy = Instance.new("AudioPlayer")
			table.insert(plays, { row = rowName, into = if options then options.into else nil, copy = copy })
			return copy
		end,
		stop = function(rowName: string)
			table.insert(stops, rowName)
		end,
		music = musicBus,
		log = {},
		destroy = function() end,
	}
	rig = {
		root = root,
		giant = giant,
		player = player,
		music = musicBus,
		plays = plays,
		stops = stops,
		refuse = refuse,
		character = character,
		step = step,
		warning = warning,
		ticks = 0,
		handle = Music.start({
			board = board,
			root = root,
			step = step,
			giantState = giant,
			player = player,
			warning = { OnClientEvent = warning },
			serverNow = function(): number
				return START + rig.ticks / 10
			end,
			hasCharacter = function(): boolean
				return character.spawned
			end,
		}),
		now = function(self: Rig): number
			return START + self.ticks / 10
		end,
		run = function(self: Rig, seconds: number)
			for _ = 1, math.round(seconds / DT) do
				self.ticks += 1
				step.fire(DT)
			end
		end,
		playsOf = function(self: Rig, row: string): { Play }
			local found: { Play } = {}
			for _, play in self.plays do
				if play.row == row then
					table.insert(found, play)
				end
			end
			return found
		end,
		calm = function(self: Rig): AudioFader
			return self.root:FindFirstChild("CalmFader") :: AudioFader
		end,
		chase = function(self: Rig): AudioFader
			return self.root:FindFirstChild("ChaseFader") :: AudioFader
		end,
		muffle = function(self: Rig): AudioFilter
			return self.root:FindFirstChild("Muffle") :: AudioFilter
		end,
	}
	table.insert(rigs, rig)
	return rig
end

-- He wakes now: Phase and PhaseEndsAt, the way the server writes them (PhaseEndsAt first).
local function wake(rig: Rig)
	rig.giant:SetAttribute("PhaseEndsAt", rig:now() + AWAKE)
	rig.giant:SetAttribute("Phase", "Awake")
end

local function lieDown(rig: Rig)
	rig.giant:SetAttribute("PhaseEndsAt", nil)
	rig.giant:SetAttribute("Phase", "Asleep")
end

afterEach(function()
	for _, rig in rigs do
		rig.handle.destroy()
		rig.root:Destroy()
		rig.music:Destroy()
		for _, play in rig.plays do
			play.copy:Destroy()
		end
	end
	table.clear(rigs)
end)

describe("Music", function()
	it("builds two faders and a low-pass filter into the music bus", function()
		local rig = newRig()
		expect(rig:calm()).never.toBe(nil)
		expect(rig:chase()).never.toBe(nil)
		expect(rig:muffle()).never.toBe(nil)
		expect(rig:calm():IsA("AudioFader")).toBe(true)
		expect(rig:chase():IsA("AudioFader")).toBe(true)
		expect(rig:muffle():IsA("AudioFilter")).toBe(true)
		expect(rig:muffle().FilterType).toBe(Enum.AudioFilterType.Lowpass24dB)
		local routes: { [Instance]: Instance } = {}
		for _, item in rig.root:GetDescendants() do
			if item:IsA("Wire") then
				local from: Instance?, to: Instance? = item.SourceInstance, item.TargetInstance
				if from ~= nil and to ~= nil then
					routes[from] = to
				end
			end
		end
		expect(routes[rig:calm()]).toBe(rig:muffle())
		expect(routes[rig:chase()]).toBe(rig:muffle())
		expect(routes[rig:muffle()]).toBe(rig.music)
	end)

	it("starts nothing until the character has spawned", function()
		local rig = newRig(false)
		rig:run(2)
		expect(#rig.plays).toBe(0)
		rig.character.spawned = true
		rig:run(DT)
		expect(#rig:playsOf(CALM)).toBe(1)
	end)

	it("plays the calm tune once, into the calm fader, trying again each frame until the board gives a copy", function()
		local rig = newRig()
		rig.refuse.count = 3 -- the file isn't ready for three frames
		rig:run(DT * 2)
		expect(#rig.plays).toBe(0)
		rig:run(DT * 10)
		expect(#rig.plays).toBe(1)
		expect(rig.plays[1].row).toBe(CALM)
		expect(rig.plays[1].into).toBe(rig:calm())
	end)

	it("moves the calm fader with the mix, frame by frame, from silence to full over one second", function()
		local rig = newRig()
		rig:run(DT) -- the first frame
		expect(rig:calm().Volume).toBeCloseTo(0, PRECISION)
		rig:run(0.5)
		expect(rig:calm().Volume).toBeCloseTo(0.5, PRECISION)
		rig:run(0.5)
		expect(rig:calm().Volume).toBeCloseTo(1, PRECISION)
		expect(rig:chase().Volume).toBeCloseTo(0, PRECISION)
	end)

	it("sweeps the filter between clear and muffled over one second", function()
		local rig = newRig()
		rig:run(2)
		expect(rig:muffle().Frequency).toBeCloseTo(CLEAR, HZ_PRECISION)
		rig.giant:SetAttribute("Meter", 62)
		rig:run(0.5)
		expect(rig:muffle().Frequency).toBeCloseTo(CLEAR * (MUFFLED / CLEAR) ^ 0.5, HZ_PRECISION)
		rig:run(0.5)
		expect(rig:muffle().Frequency).toBeCloseTo(MUFFLED, HZ_PRECISION)
		expect(rig:calm().Volume).toBeCloseTo(Config.Audio.ThinnedMusicFactor, PRECISION)
		rig.giant:SetAttribute("Meter", 50)
		rig:run(1)
		expect(rig:muffle().Frequency).toBeCloseTo(CLEAR, HZ_PRECISION)
		expect(rig:calm().Volume).toBeCloseTo(1, PRECISION)
	end)

	it("goes silent within a second of an 85% warning, even with the meter under 85", function()
		local rig = newRig()
		rig.giant:SetAttribute("Meter", 70)
		rig:run(2)
		expect(rig:calm().Volume).toBeCloseTo(Config.Audio.ThinnedMusicFactor, PRECISION)
		rig.warning.fire(85)
		rig:run(1)
		expect(rig:calm().Volume).toBeCloseTo(0, PRECISION)
	end)

	it("starts the chase tune once, one second after the wake, at its first file time, into the chase fader", function()
		local rig = newRig()
		rig:run(1)
		wake(rig)
		rig:run(0.9)
		expect(#rig:playsOf(CHASE)).toBe(0)
		expect(rig:chase().Volume).toBeCloseTo(0, PRECISION)
		rig:run(DT)
		local chases = rig:playsOf(CHASE)
		expect(#chases).toBe(1)
		expect(chases[1].into).toBe(rig:chase())
		expect(chases[1].copy.TimePosition).toBeCloseTo(0.3, PRECISION)
		rig:run(0.8) -- the frame the chase began already moved the fader 0.1, so 0.1 + 0.8
		expect(rig:chase().Volume).toBeCloseTo(0.9, PRECISION)
		rig:run(5)
		expect(#rig:playsOf(CHASE)).toBe(1) -- started once, never again
		expect(rig:chase().Volume).toBeCloseTo(1, PRECISION)
	end)

	it("never moves a playing chase copy, not even while it fades out after he lies down", function()
		local rig = newRig()
		wake(rig)
		rig:run(8)
		local copy = rig:playsOf(CHASE)[1].copy
		local startedAt = copy.TimePosition
		lieDown(rig)
		rig:run(0.5)
		expect(copy.TimePosition).toBe(startedAt) -- the fake file never advances: any seek would show
		expect(#rig.stops).toBe(0) -- still fading out, still playing
		expect(rig:chase().Volume).toBeCloseTo(0.5, PRECISION)
	end)

	it("stops the chase copy once its fader has reached 0 after he lies down, and only then", function()
		local rig = newRig()
		wake(rig)
		rig:run(8)
		lieDown(rig)
		rig:run(0.9)
		expect(#rig.stops).toBe(0)
		rig:run(0.2)
		expect(rig:chase().Volume).toBeCloseTo(0, PRECISION)
		expect(#rig.stops).toBe(1)
		expect(rig.stops[1]).toBe(CHASE)
		rig:run(2)
		expect(#rig.stops).toBe(1) -- stopped once
		expect(#rig:playsOf(CHASE)).toBe(1) -- and not started again
	end)

	it("destroy disconnects the step and the warning, removes what it built and starts nothing more", function()
		local rig = newRig()
		rig:run(1)
		expect(rig.step.count()).toBe(1)
		expect(rig.warning.count()).toBe(1)
		rig.handle.destroy()
		expect(rig.step.count()).toBe(0)
		expect(rig.warning.count()).toBe(0)
		expect(rig.root:FindFirstChild("CalmFader")).toBe(nil)
		expect(rig.root:FindFirstChild("ChaseFader")).toBe(nil)
		expect(rig.root:FindFirstChild("Muffle")).toBe(nil)
		wake(rig)
		rig:run(3)
		expect(#rig:playsOf(CHASE)).toBe(0)
	end)
end)

-- The music button (plan 7 Task 16; spec 7 Rule 98): setOn turns the whole music bus off or on at once. The faders and
-- the filter keep following the mix; only the bus changes.
describe("Music.setOn", function()
	it("silences the music bus at once and brings it back at once", function()
		local rig = newRig()
		rig:run(1)
		expect(rig.music.Volume).toBeCloseTo(1, PRECISION)
		rig.handle.setOn(false)
		expect(rig.music.Volume).toBeCloseTo(0, PRECISION)
		rig.handle.setOn(true)
		expect(rig.music.Volume).toBeCloseTo(1, PRECISION)
	end)

	it("leaves the faders and the filter following the mix while it is off", function()
		local rig = newRig()
		rig.handle.setOn(false)
		rig:run(DT) -- the first frame
		rig:run(1)
		expect(rig:calm().Volume).toBeCloseTo(1, PRECISION)
		expect(rig:chase().Volume).toBeCloseTo(0, PRECISION)
		expect(rig:muffle().Frequency).toBeCloseTo(CLEAR, HZ_PRECISION)
		expect(rig.music.Volume).toBeCloseTo(0, PRECISION)
		wake(rig)
		rig:run(8)
		expect(rig:chase().Volume).toBeGreaterThan(0.5)
		expect(rig.music.Volume).toBeCloseTo(0, PRECISION)
	end)

	it("stays off when the character goes away and comes back", function()
		local rig = newRig()
		rig:run(1)
		rig.handle.setOn(false)
		rig.character.spawned = false
		rig:run(1)
		rig.character.spawned = true
		rig:run(1)
		expect(rig.music.Volume).toBeCloseTo(0, PRECISION)
	end)
end)
