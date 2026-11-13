--!strict
-- The snore (plan 7 Task 7; spec 7 Rule 90 "The snore follows his sleep"). Silent: the board is a fake that records its
-- plays and stops, `setPuffs` calls stand in for GiantFx, the clock is a number the test moves, and the random pick is fixed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Snore = require(StarterPlayer.StarterPlayerScripts.Client.Audio.Snore)
local SoundBoard = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundBoard)
local SoundList = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundList)

local PRECISION = 2 -- volumes and speeds compare to about 0.01 (luau.md, "Test first")
local DT = 0.05 -- the fake clock steps by 0.05 s
local NORMAL = "Snore (loop)"
local HEAVY = "Heavy Sleep snore (loop)"
local MOUTH = Vector3.new(0, 80, -40)
local SPEED = Config.Audio.SnoreSpeed
local HEAVY_SPEED = Config.Audio.HeavySleepSnoreSpeed
local FULL = SoundList.playerVolume(0.8) -- the spec's snore loudness, as an AudioPlayer volume (plan 7, "The loudness scale")
local HEAVY_FULL = SoundList.playerVolume(0.9)

type Play = { row: string, at: Vector3?, copy: AudioPlayer }
type Rig = {
	plays: { Play },
	stops: { string },
	refuse: { count: number }, -- the next N plays return nil, as a board does while a file loads
	meter: { value: number },
	randoms: { number }, -- the next random picks; 0.5 when empty
	handle: Snore.Handle,
	loopedCount: (self: Rig) -> number, -- looped connections still live
	fireLoop: (self: Rig, copy: AudioPlayer) -> (),
	run: (self: Rig, seconds: number) -> (),
	playsOf: (self: Rig, row: string) -> { Play },
}

local rigs: { Rig } = {}

local function newRig(): Rig
	local plays: { Play } = {}
	local stops: { string } = {}
	local refuse = { count = 0 }
	local meter = { value = 10 }
	local randoms: { number } = {}
	local callbacks: { [AudioPlayer]: { [() -> ()]: boolean } } = {}
	local live = 0
	local clock = 1000
	local stepCallbacks: { [(...any) -> ()]: boolean } = {}
	local step: Snore.SignalLike = {
		Connect = function(_self: any, callback: (...any) -> ()): SoundBoard.Disconnectable
			stepCallbacks[callback] = true
			return {
				Disconnect = function()
					stepCallbacks[callback] = nil
				end,
			}
		end,
	}
	local board: SoundBoard.Board = {
		play = function(rowName: string, at: Vector3?, _options: SoundBoard.PlayOptions?): AudioPlayer?
			if refuse.count > 0 then
				refuse.count -= 1
				return nil
			end
			local copy = Instance.new("AudioPlayer")
			copy.Volume = 99 -- a value no row has: the snore must set the volume itself
			table.insert(plays, { row = rowName, at = at, copy = copy })
			return copy
		end,
		stop = function(rowName: string)
			table.insert(stops, rowName)
		end,
		music = Instance.new("AudioFader"),
		log = {},
		destroy = function() end,
	}
	local rig: Rig
	rig = {
		plays = plays,
		stops = stops,
		refuse = refuse,
		meter = meter,
		randoms = randoms,
		handle = Snore.start({
			board = board,
			step = step,
			now = function(): number
				return clock
			end,
			meter = function(): number
				return meter.value
			end,
			mouth = function(): Vector3?
				return MOUTH
			end,
			random = function(): number
				return table.remove(randoms, 1) or 0.5
			end,
			looped = function(copy: AudioPlayer, callback: () -> ()): SoundBoard.Disconnectable
				local set: { [() -> ()]: boolean } = callbacks[copy] or {}
				callbacks[copy] = set
				set[callback] = true
				live += 1
				return {
					Disconnect = function()
						local current = callbacks[copy]
						if current ~= nil and current[callback] then
							current[callback] = nil
							live -= 1
						end
					end,
				}
			end,
		}),
		loopedCount = function(): number
			return live
		end,
		fireLoop = function(_self: Rig, copy: AudioPlayer)
			local set = callbacks[copy]
			if set ~= nil then
				for callback in table.clone(set) do
					callback()
				end
			end
		end,
		run = function(_self: Rig, seconds: number)
			for _ = 1, math.round(seconds / DT) do
				clock += DT
				for callback in table.clone(stepCallbacks) do
					callback(DT)
				end
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
	}
	table.insert(rigs, rig)
	return rig
end

afterEach(function()
	for _, rig in rigs do
		rig.handle.destroy()
		for _, play in rig.plays do
			play.copy:Destroy()
		end
	end
	table.clear(rigs)
end)

describe("Snore", function()
	it("plays nothing until GiantFx says the puffs are on", function()
		local rig = newRig()
		rig:run(1)
		expect(#rig.plays).toBe(0)
	end)

	it("plays the snore at its full volume, looping, from his mouth, while asleep under 60", function()
		local rig = newRig()
		rig.handle.setPuffs("Normal")
		rig:run(0.5)
		expect(#rig.plays).toBe(1)
		local play = rig.plays[1]
		expect(play.row).toBe(NORMAL)
		expect(play.at).toBe(MOUTH)
		expect(play.copy.Looping).toBe(true)
		expect(play.copy.Volume).toBeCloseTo(FULL, PRECISION)
		expect(play.copy.PlaybackSpeed).toBeCloseTo(SPEED.Min + 0.5 * (SPEED.Max - SPEED.Min), PRECISION)
	end)

	it("keeps asking the board each step until it returns a copy, then plays once", function()
		local rig = newRig()
		rig.refuse.count = 3
		rig.handle.setPuffs("Normal")
		rig:run(1)
		expect(#rig.plays).toBe(1)
	end)

	it("stops for the 2 second pause at 60, then plays at half volume until 85", function()
		local rig = newRig()
		rig.handle.setPuffs("Normal")
		rig:run(0.5)
		local first = rig.plays[1].copy
		rig.meter.value = 60
		rig.handle.setPuffs("Off") -- GiantFx at 60
		rig:run(0.2)
		expect(first.Volume).toBeCloseTo(0, PRECISION)
		expect(rig.stops).toEqual({ NORMAL })
		rig:run(1.8) -- 2 s after the 60 warning
		rig.handle.setPuffs("Normal")
		rig:run(0.2)
		expect(#rig.plays).toBe(2)
		expect(rig.plays[2].copy.Volume).toBeCloseTo(FULL * Config.Audio.LightSnoreFactor, PRECISION)
	end)

	it("is silent within 0.1 seconds of the 85 warning, not after a slow fade", function()
		local rig = newRig()
		rig.handle.setPuffs("Normal")
		rig:run(0.5)
		local copy = rig.plays[1].copy
		rig.handle.setPuffs("Off")
		rig:run(Config.Audio.SnoreStopSeconds / 2)
		expect(copy.Volume).toBeCloseTo(FULL / 2, 1) -- half way down on the ramp
		rig:run(Config.Audio.SnoreStopSeconds / 2 + DT) -- the 0.1 s are over
		expect(copy.Volume).toBeCloseTo(0, PRECISION)
		expect(rig.stops).toEqual({ NORMAL })
		expect(rig:loopedCount()).toBe(0)
	end)

	it("plays nothing while he is awake, and a free save keeps it off until GiantFx says Normal", function()
		local rig = newRig()
		rig.handle.setPuffs("Off") -- awake, or a replayed warning
		rig.meter.value = 80
		rig:run(3)
		expect(#rig.plays).toBe(0)
		rig.meter.value = 70 -- the replay is over and the meter fell under 75: GiantFx brings the puffs back
		rig.handle.setPuffs("Normal")
		rig:run(0.2)
		expect(#rig.plays).toBe(1)
	end)

	it("plays the Heavy Sleep snore at its own volume and speed, and goes back to the normal one after", function()
		local rig = newRig()
		rig.handle.setPuffs("Normal")
		rig:run(0.5)
		rig.handle.setPuffs("Heavy")
		rig:run(0.5)
		local heavy = rig:playsOf(HEAVY)
		expect(#heavy).toBe(1)
		expect(heavy[1].copy.Volume).toBeCloseTo(HEAVY_FULL, PRECISION)
		expect(heavy[1].copy.PlaybackSpeed).toBeCloseTo(
			HEAVY_SPEED.Min + 0.5 * (HEAVY_SPEED.Max - HEAVY_SPEED.Min),
			PRECISION
		)
		expect(rig.plays[1].copy.Volume).toBeCloseTo(0, PRECISION) -- the normal one ramped off
		expect(rig.stops).toEqual({ NORMAL })
		rig.handle.setPuffs("Normal")
		rig:run(0.5)
		expect(#rig:playsOf(NORMAL)).toBe(2)
		expect(rig.stops).toEqual({ NORMAL, HEAVY })
	end)

	it("picks a new speed in 0.95 to 1.05 each time the loop starts again, and never restarts the copy", function()
		local rig = newRig()
		table.move({ 0, 1, 0.5 }, 1, 3, 1, rig.randoms) -- fill the rig's own list (the random pick reads it)
		rig.handle.setPuffs("Normal")
		rig:run(0.2)
		local copy = rig.plays[1].copy
		expect(copy.PlaybackSpeed).toBeCloseTo(SPEED.Min, PRECISION) -- the first pick was 0
		rig:fireLoop(copy)
		expect(copy.PlaybackSpeed).toBeCloseTo(SPEED.Max, PRECISION)
		rig:fireLoop(copy)
		expect(copy.PlaybackSpeed).toBeCloseTo(0.5 * (SPEED.Min + SPEED.Max), PRECISION)
		expect(#rig.plays).toBe(1)
		expect(#rig.stops).toBe(0)
	end)

	it("stops everything and lets go of the loop event when destroyed", function()
		local rig = newRig()
		rig.handle.setPuffs("Normal")
		rig:run(0.5)
		rig.handle.destroy()
		expect(rig.stops).toEqual({ NORMAL })
		expect(rig:loopedCount()).toBe(0)
	end)
end)
