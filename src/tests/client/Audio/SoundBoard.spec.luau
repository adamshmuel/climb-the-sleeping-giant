--!strict
-- The sound board (plan 7 Task 3; spec 7 Rule 86 "Three ways to hear", section 8 "A sound doesn't load"). Silent: the
-- output is an AudioFader stand-in, the world parent is a detached Part, "start playing" is a recorder, and nothing here
-- calls :Play() on an AudioPlayer or makes a speaker output, a listener or a Sound (plan 7, "Nobody listens, ever").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local SoundList = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundList)
local SoundBoard = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundBoard)

-- Float numbers like 0.7 * 2 compare to about 0.01 (luau.md, "Test first").
local PRECISION = 2
local PLACE = Vector3.new(40, 5, -30)
local LOG_LIMIT = 200 -- plan 7, Task 3: "the last 200 plays"

-- One fade the board asked for: the copy, the seconds to wait, and the seconds the fade lasts.
type Fade = { copy: AudioPlayer, afterSeconds: number, seconds: number }

type Rig = {
	board: SoundBoard.Board,
	root: Folder,
	output: AudioFader,
	worldParent: Part,
	started: { AudioPlayer }, -- every copy startPlaying was asked to start, in order
	notReady: { [string]: boolean }, -- Asset strings whose file "isn't ready yet"
	fades: { Fade }, -- every fadeOut the board asked for, in order
	setTime: (seconds: number) -> (),
	fireEnded: (copy: AudioPlayer) -> (),
}

local rigs: { Rig } = {}

local function newRig(): Rig
	local root = Instance.new("Folder")
	local output = Instance.new("AudioFader")
	local worldParent = Instance.new("Part")
	local started: { AudioPlayer } = {}
	local notReady: { [string]: boolean } = {}
	local endedCallbacks: { [AudioPlayer]: () -> () } = {}
	local fades: { Fade } = {}
	local time = 0
	local board = SoundBoard.start({
		root = root,
		output = output,
		worldParent = worldParent,
		startPlaying = function(player: AudioPlayer)
			table.insert(started, player)
		end,
		isReady = function(player: AudioPlayer): boolean
			return not notReady[player.Asset]
		end,
		ended = function(player: AudioPlayer, callback: () -> ())
			endedCallbacks[player] = callback
			return {
				Disconnect = function()
					endedCallbacks[player] = nil
				end,
			}
		end,
		fadeOut = function(copy: AudioPlayer, afterSeconds: number, seconds: number)
			table.insert(fades, { copy = copy, afterSeconds = afterSeconds, seconds = seconds })
		end,
		now = function(): number
			return time
		end,
	})
	local rig: Rig = {
		board = board,
		root = root,
		output = output,
		worldParent = worldParent,
		started = started,
		notReady = notReady,
		fades = fades,
		setTime = function(seconds: number)
			time = seconds
		end,
		fireEnded = function(copy: AudioPlayer)
			local callback = endedCallbacks[copy]
			if callback then
				callback()
			end
		end,
	}
	table.insert(rigs, rig)
	return rig
end

afterEach(function()
	for _, rig in rigs do
		rig.board.destroy()
		rig.root:Destroy()
		rig.output:Destroy()
		rig.worldParent:Destroy()
	end
	table.clear(rigs)
end)

-- Every wire in the board's own tree that starts at this copy.
local function wiresFrom(rig: Rig, copy: AudioPlayer): { Wire }
	local found: { Wire } = {}
	for _, item in rig.root:GetDescendants() do
		if item:IsA("Wire") and item.SourceInstance == copy then
			table.insert(found, item)
		end
	end
	return found
end

local function bus(rig: Rig, name: string): Instance
	return rig.root:FindFirstChild(name) :: Instance
end

local function lastCopy(rig: Rig): AudioPlayer
	return rig.started[#rig.started]
end

describe("SoundBoard", function()
	it("builds a music bus and an effects bus, each wired to the output", function()
		local rig = newRig()
		for _, name in { "Music", "Effects" } do
			local found = bus(rig, name)
			expect(found).never.toBe(nil)
			expect(found:IsA("AudioFader")).toBe(true)
			local wired = false
			for _, item in rig.root:GetDescendants() do
				if item:IsA("Wire") and item.SourceInstance == found and item.TargetInstance == rig.output then
					wired = true
				end
			end
			expect(wired).toBe(true)
		end
	end)

	it("wires a Just for you row to the effects bus and gives it no emitter", function()
		local rig = newRig()
		rig.board.play("Grab pluck")
		expect(#rig.started).toBe(1)
		local wires = wiresFrom(rig, lastCopy(rig))
		expect(#wires).toBe(1)
		expect(wires[1].TargetInstance).toBe(bus(rig, "Effects"))
		expect(#rig.worldParent:GetChildren()).toBe(0)
		for _, item in rig.root:GetDescendants() do
			expect(item:IsA("AudioEmitter")).toBe(false)
		end
	end)

	it("wires a tune to the music bus", function()
		local rig = newRig()
		rig.board.play("Calm tune (loop)")
		local wires = wiresFrom(rig, lastCopy(rig))
		expect(#wires).toBe(1)
		expect(wires[1].TargetInstance).toBe(bus(rig, "Music"))
	end)

	it("gives a Whole valley row an attachment at the place and an emitter with the valley curve", function()
		local rig = newRig()
		rig.board.play("Snore (loop)", PLACE)
		local wires = wiresFrom(rig, lastCopy(rig))
		expect(#wires).toBe(1)
		local emitter = wires[1].TargetInstance :: AudioEmitter
		expect(emitter:IsA("AudioEmitter")).toBe(true)
		local attachment = emitter.Parent :: Attachment
		expect(attachment.Parent).toBe(rig.worldParent)
		expect((attachment.WorldPosition - PLACE).Magnitude).toBeCloseTo(0, PRECISION)
		expect(emitter.DistanceAttenuationMode).toBe(Enum.DistanceAttenuationMode.Custom)
		local curve = emitter:GetDistanceAttenuation()
		for distance, volume in Config.Audio.WholeValleyCurve do
			expect(curve[distance]).toBeCloseTo(volume, PRECISION)
		end
	end)

	it("gives a Nearby row an emitter with the nearby curve", function()
		local rig = newRig()
		rig.board.play("Bonk", PLACE)
		local emitter = wiresFrom(rig, lastCopy(rig))[1].TargetInstance :: AudioEmitter
		local curve = emitter:GetDistanceAttenuation()
		for distance, volume in Config.Audio.NearbyCurve do
			expect(curve[distance]).toBeCloseTo(volume, PRECISION)
		end
		expect(curve[60]).toBe(nil) -- the valley curve has no point the nearby one lacks
	end)

	it("skips a Whole valley or Nearby row that is given no place", function()
		local rig = newRig()
		rig.board.play("Bonk")
		expect(#rig.started).toBe(0)
		expect(#rig.board.log).toBe(0)
		rig.board.play("Bonk", PLACE) -- the same row, given a place: the board is working
		expect(#rig.started).toBe(1)
	end)

	it("sets the volume to twice the spec's loudness", function()
		local rig = newRig()
		rig.board.play("Bonk", PLACE) -- the spec's 1.0
		expect(lastCopy(rig).Volume).toBeCloseTo(2, PRECISION)
	end)

	it("gives the flump 1.4 for a +30 thud", function()
		local rig = newRig()
		rig.board.play('Thud "flump"', PLACE, { thud = 30 }) -- the spec's 0.7 for +30
		expect(lastCopy(rig).Volume).toBeCloseTo(1.4, PRECISION)
	end)

	it("sets a row's fixed speed", function()
		local rig = newRig()
		rig.board.play("Big yawn", PLACE) -- speed 0.8
		expect(lastCopy(rig).PlaybackSpeed).toBeCloseTo(0.8, PRECISION)
	end)

	it("picks a speed inside a row's speed range", function()
		local rig = newRig()
		local range = Config.Audio.SnoreSpeed
		for _ = 1, 20 do
			rig.board.play("Snore (loop)", PLACE)
			local speed = lastCopy(rig).PlaybackSpeed
			expect(speed).toBeGreaterThanOrEqual(range.Min - 0.001)
			expect(speed).toBeLessThanOrEqual(range.Max + 0.001)
			rig.board.stop("Snore (loop)")
		end
	end)

	it("starts at the row's file start and loops a tune over its loop part", function()
		local rig = newRig()
		rig.board.play("Chase tune (loop)") -- 0.3 s in, loop 0.3 to 102.35
		local copy = lastCopy(rig)
		expect(copy.TimePosition).toBeCloseTo(0.3, PRECISION)
		expect(copy.Looping).toBe(true)
		expect(copy.LoopRegion.Min).toBeCloseTo(0.3, PRECISION)
		expect(copy.LoopRegion.Max).toBeCloseTo(102.35, PRECISION)
	end)

	it("loads the row's own file", function()
		local rig = newRig()
		rig.board.play("Bonk", PLACE)
		expect(lastCopy(rig).Asset).toBe("rbxassetid://9113496949")
	end)

	it("skips a 4th copy of one row while 3 play, and still plays a different row", function()
		local rig = newRig()
		for _ = 1, Config.Audio.MaxCopies + 1 do
			rig.board.play("Bonk", PLACE)
		end
		expect(#rig.started).toBe(Config.Audio.MaxCopies)
		rig.board.play("Fist thud", PLACE)
		expect(#rig.started).toBe(Config.Audio.MaxCopies + 1)
	end)

	it("stops a one-at-a-time row's old copy first", function()
		local rig = newRig()
		rig.board.play('"Mmm..." mumble', PLACE)
		local first = lastCopy(rig)
		rig.board.play('"Mmm..." mumble', PLACE)
		expect(first.Parent).toBe(nil)
		expect(#rig.started).toBe(2)
		expect(lastCopy(rig).Parent).never.toBe(nil)
	end)

	it("skips a row whose file isn't ready, with no error", function()
		local rig = newRig()
		rig.notReady["rbxassetid://15675055424"] = true -- Egg "pop"
		rig.board.play('Egg "pop"', PLACE)
		expect(#rig.started).toBe(0)
		expect(#rig.board.log).toBe(0)
		expect(#rig.worldParent:GetChildren()).toBe(0)
		rig.board.play("Bonk", PLACE) -- another row: the board is working
		expect(#rig.started).toBe(1)
	end)

	it("skips a row name that is not in the list", function()
		local rig = newRig()
		rig.board.play("No such sound", PLACE)
		expect(#rig.started).toBe(0)
		rig.board.play("Bonk", PLACE) -- a real row: the board is working
		expect(#rig.started).toBe(1)
	end)

	it("removes everything a play made when it ends", function()
		local rig = newRig()
		rig.board.play("Snore (loop)", PLACE)
		local copy = lastCopy(rig)
		local emitter = wiresFrom(rig, copy)[1].TargetInstance :: AudioEmitter
		rig.fireEnded(copy)
		expect(copy.Parent).toBe(nil)
		expect(emitter.Parent).toBe(nil)
		expect(#rig.worldParent:GetChildren()).toBe(0)
		expect(#wiresFrom(rig, copy)).toBe(0)
	end)

	it("removes everything a play made when it is stopped", function()
		local rig = newRig()
		rig.board.play("Snore (loop)", PLACE)
		local copy = lastCopy(rig)
		rig.board.stop("Snore (loop)")
		expect(copy.Parent).toBe(nil)
		expect(#rig.worldParent:GetChildren()).toBe(0)
	end)

	it("frees a slot when a copy ends, so the row plays again", function()
		local rig = newRig()
		for _ = 1, Config.Audio.MaxCopies do
			rig.board.play("Bonk", PLACE)
		end
		rig.fireEnded(rig.started[1])
		rig.board.play("Bonk", PLACE)
		expect(#rig.started).toBe(Config.Audio.MaxCopies + 1)
	end)

	it("logs each play with its row, time and place", function()
		local rig = newRig()
		rig.setTime(12.5)
		rig.board.play("Bonk", PLACE)
		rig.setTime(13)
		rig.board.play("Grab pluck")
		expect(#rig.board.log).toBe(2)
		expect(rig.board.log[1].row).toBe("Bonk")
		expect(rig.board.log[1].time).toBeCloseTo(12.5, PRECISION)
		expect((rig.board.log[1].place :: Vector3 - PLACE).Magnitude).toBeCloseTo(0, PRECISION)
		expect(rig.board.log[2].row).toBe("Grab pluck")
		expect(rig.board.log[2].place).toBe(nil)
	end)

	it("keeps only the last 200 log records", function()
		local rig = newRig()
		for i = 1, LOG_LIMIT + 5 do
			rig.setTime(i)
			rig.board.play("Grab pluck")
			rig.fireEnded(lastCopy(rig))
		end
		expect(#rig.board.log).toBe(LOG_LIMIT)
		expect(rig.board.log[1].time).toBeCloseTo(6, PRECISION)
		expect(rig.board.log[LOG_LIMIT].time).toBeCloseTo(LOG_LIMIT + 5, PRECISION)
	end)

	it("returns the copy it started, and nil when it skips a play", function()
		local rig = newRig()
		local copy = rig.board.play("Grab pluck")
		expect(copy).toBe(lastCopy(rig))
		expect(rig.board.play("No such row")).toBe(nil)
		expect(rig.board.play("Snore (loop)")).toBe(nil) -- a world row without a place
		local row = SoundList.byName("Grab pluck") :: SoundList.Entry
		rig.notReady[`rbxassetid://{row.id}`] = true
		expect(rig.board.play("Grab pluck")).toBe(nil)
		expect(#rig.started).toBe(1)
	end)

	it("wires a Just for you copy into the instance given in options.into, and not to its bus", function()
		local rig = newRig()
		local fader = Instance.new("AudioFader")
		local options: SoundBoard.PlayOptions = { into = fader :: Instance }
		local copy = rig.board.play("Calm tune (loop)", nil, options)
		expect(copy).never.toBe(nil)
		local wires = wiresFrom(rig, copy :: AudioPlayer)
		expect(#wires).toBe(1)
		expect(wires[1].TargetInstance).toBe(fader)
		fader:Destroy()
	end)

	it("exposes the music bus, and counts every play in the folder's PlayCount and LastPlay", function()
		local rig = newRig()
		expect(rig.board.music).toBe(bus(rig, "Music"))
		expect(rig.root:GetAttribute("PlayCount")).toBe(0)
		rig.setTime(3.14159)
		rig.board.play("Grab pluck")
		expect(rig.root:GetAttribute("PlayCount")).toBe(1)
		expect(rig.root:GetAttribute("LastPlay")).toBe("Grab pluck @ 3.14")
		rig.board.play("No such row") -- a skipped play counts for nothing
		expect(rig.root:GetAttribute("PlayCount")).toBe(1)
		rig.setTime(7)
		rig.board.play("Snore (loop)", PLACE)
		expect(rig.root:GetAttribute("PlayCount")).toBe(2)
		expect(rig.root:GetAttribute("LastPlay")).toBe("Snore (loop) @ 7.00")
	end)

	it("makes no speaker output and starts only through startPlaying", function()
		local rig = newRig()
		rig.board.play("Grab pluck")
		rig.board.play("Snore (loop)", PLACE)
		expect(#rig.started).toBe(2)
		local trees: { Instance } = { rig.root, rig.worldParent }
		for _, tree in trees do
			for _, item in tree:GetDescendants() do
				expect(item:IsA("AudioDeviceOutput")).toBe(false)
				if item:IsA("AudioPlayer") then
					expect(item.IsPlaying).toBe(false)
				end
			end
		end
	end)
end)

describe("SoundBoard: the snort's speed, cut and fade (plan 7 Task 8)", function()
	it("plays a row at the speed option instead of the row's own speed", function()
		local rig = newRig()
		rig.board.play("85% snort (two)", PLACE) -- the row's speed 1
		expect(lastCopy(rig).PlaybackSpeed).toBeCloseTo(1, PRECISION)
		rig.board.play("85% snort (two)", PLACE, { speed = 0.9 })
		expect(lastCopy(rig).PlaybackSpeed).toBeCloseTo(0.9, PRECISION)
	end)

	it("lets the speed option beat a row's speed range", function()
		local rig = newRig()
		rig.board.play("Snore (loop)", PLACE, { speed = 1.25 })
		expect(lastCopy(rig).PlaybackSpeed).toBeCloseTo(1.25, PRECISION)
	end)

	it("cuts the snort to 3.46 s to 3.86 s and leaves every row without a fileEnd uncut", function()
		local rig = newRig()
		rig.board.play("85% snort (two)", PLACE)
		local region = lastCopy(rig).PlaybackRegion
		expect(region.Min).toBeCloseTo(3.46, PRECISION)
		expect(region.Max).toBeCloseTo(3.86, PRECISION)
		rig.board.play("Bonk", PLACE)
		local uncut = Instance.new("AudioPlayer").PlaybackRegion
		expect(lastCopy(rig).PlaybackRegion).toEqual(uncut)
	end)

	it("asks for the end fade 0.35 s in and 0.05 s long at speed 1", function()
		local rig = newRig()
		local copy = rig.board.play("85% snort (two)", PLACE) :: AudioPlayer
		expect(#rig.fades).toBe(1)
		expect(rig.fades[1].copy).toBe(copy)
		expect(rig.fades[1].afterSeconds).toBeCloseTo(0.35, PRECISION)
		expect(rig.fades[1].seconds).toBeCloseTo(0.05, PRECISION)
	end)

	it("stretches the end fade with the speed option", function()
		local rig = newRig()
		rig.board.play("85% snort (two)", PLACE, { speed = 0.9 })
		expect(rig.fades[1].afterSeconds).toBeCloseTo(0.35 / 0.9, PRECISION)
		expect(rig.fades[1].seconds).toBeCloseTo(0.05 / 0.9, PRECISION)
	end)

	it("asks for no fade for a row without an endFade", function()
		local rig = newRig()
		rig.board.play("Bonk", PLACE)
		rig.board.play('"Mmm..." mumble', PLACE)
		expect(#rig.fades).toBe(0)
	end)
end)
