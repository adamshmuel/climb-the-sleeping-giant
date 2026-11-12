--!strict
-- The sound board (plan 7 Task 3; spec 7 Rule 86 "Three ways to hear"). It builds, on this device only, two buses and one
-- AudioPlayer per file to copy from, and plays a row by copying its player, wiring the copy to a bus ("Just for you") or
-- to an emitter at a place ("Whole valley", "Nearby"), and removing everything when the sound ends or is stopped.
-- Everything it can't drive in a test is passed in: the speaker output, where world attachments go, the "start playing"
-- step, "is the file ready", "tell me when it ended" and the clock. Fades are the music player's (Task 6), so none are here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundList = require(script.Parent.SoundList)

export type Disconnectable = { Disconnect: (self: any) -> () }
export type Deps = {
	root: Instance, -- where the buses and the players to copy from are built (a folder in SoundService)
	output: Instance, -- the speaker output (an AudioDeviceOutput in the game, an AudioFader stand-in in tests)
	worldParent: Instance, -- where the attachments for world sounds go (Workspace.Terrain in the game)
	startPlaying: (player: AudioPlayer) -> (), -- player:Play() in the game
	isReady: (player: AudioPlayer) -> boolean, -- player.IsReady in the game
	ended: (player: AudioPlayer, callback: () -> ()) -> Disconnectable, -- player.Ended in the game
	fadeOut: ((copy: AudioPlayer, afterSeconds: number, seconds: number) -> ())?, -- fades the copy's Volume to 0 (a tween in the game)
	now: () -> number,
}
export type PlayOptions = {
	thud: number?, -- the flump's thud size (+20, +30, +40 or more)
	speed: number?, -- overrides the row's own speed (the second snort's 0.9)
	into: Instance?, -- a Just for you row wires here instead of to its bus (Music's faders)
}
export type LogRecord = { row: string, time: number, place: Vector3? }
export type Board = {
	play: (rowName: string, at: Vector3?, options: PlayOptions?) -> AudioPlayer?, -- the copy, nil when skipped
	stop: (rowName: string) -> (),
	music: Instance, -- the Music bus
	log: { LogRecord }, -- the last LOG_LIMIT plays, oldest first
	destroy: () -> (),
}

type Active = { copy: AudioPlayer, attachment: Attachment?, connection: Disconnectable }

local LOG_LIMIT = 200 -- plan 7, Task 3: "the last 200 plays"

local SoundBoard = {}

-- The spec's loudness for a thud: the biggest listed size that the thud reaches (a bigger thud than listed uses the biggest).
local function loudnessForThud(byThud: { [number]: number }, thud: number, fallback: number): number
	local bestSize = -1
	local loudness = fallback
	for size, value in byThud do
		if size <= thud and size > bestSize then
			bestSize = size
			loudness = value
		end
	end
	return loudness
end

local function speedFor(entry: SoundList.Entry): number
	local min, max = entry.speedMin, entry.speedMax
	if min ~= nil and max ~= nil then
		return min + math.random() * (max - min)
	end
	return entry.speed or 1
end

-- The two tunes are the only Just for you rows that loop.
local function isTune(entry: SoundList.Entry): boolean
	return entry.group == "JustForYou" and entry.loopStart ~= nil
end

function SoundBoard.start(deps: Deps): Board
	local made: { Instance } = {}
	local function build(instance: Instance, name: string, parent: Instance): Instance
		instance.Name = name
		instance.Parent = parent
		table.insert(made, instance)
		return instance
	end
	local function wire(from: Instance, to: Instance, parent: Instance)
		local item = Instance.new("Wire")
		item.SourceInstance = from
		item.TargetInstance = to
		item.Parent = parent
	end

	deps.root:SetAttribute("PlayCount", 0) -- the Play check's signals: how many plays, and the latest one
	local music = build(Instance.new("AudioFader"), "Music", deps.root)
	local effects = build(Instance.new("AudioFader"), "Effects", deps.root)
	wire(music, deps.output, deps.root)
	wire(effects, deps.output, deps.root)

	local templates: { [number]: AudioPlayer? } = {}
	for _, entry in SoundList.entries do
		if templates[entry.id] == nil then
			local template = Instance.new("AudioPlayer")
			template.Asset = `rbxassetid://{entry.id}`
			build(template, `File {entry.id}`, deps.root)
			templates[entry.id] = template
		end
	end

	local active: { [string]: { Active } } = {}
	local log: { LogRecord } = {}

	local function finish(rowName: string, item: Active)
		local list = active[rowName]
		local at = if list then table.find(list, item) else nil
		if list and at then
			table.remove(list, at)
		end
		item.connection:Disconnect()
		if item.attachment then
			item.attachment:Destroy()
		end
		item.copy:Destroy()
	end

	local function stop(rowName: string)
		local list = active[rowName]
		if list == nil then
			return
		end
		for _, item in table.clone(list) do
			finish(rowName, item)
		end
	end

	local function play(rowName: string, at: Vector3?, options: PlayOptions?): AudioPlayer?
		local entry = SoundList.byName(rowName)
		if entry == nil then
			return nil
		end
		local template = templates[entry.id]
		if template == nil or not deps.isReady(template) then
			return nil
		end
		local inWorld = entry.group ~= "JustForYou"
		if inWorld and at == nil then
			return nil
		end
		local list = active[rowName]
		if list == nil then
			list = {}
			active[rowName] = list
		end
		if entry.oneAtATime then
			stop(rowName)
		elseif #list >= Config.Audio.MaxCopies then
			return nil
		end

		local loudness = entry.loudness
		if entry.loudnessByThud ~= nil and options ~= nil and options.thud ~= nil then
			loudness = loudnessForThud(entry.loudnessByThud, options.thud, loudness)
		end
		local copy = template:Clone()
		copy.Name = `Copy {rowName}`
		copy.Volume = SoundList.playerVolume(loudness)
		local speed = (options and options.speed) or speedFor(entry)
		copy.PlaybackSpeed = speed
		copy.TimePosition = entry.fileStart
		if entry.loopStart ~= nil and entry.loopEnd ~= nil then
			copy.Looping = true
			copy.LoopRegion = NumberRange.new(entry.loopStart, entry.loopEnd)
		end
		if entry.fileEnd ~= nil then
			copy.PlaybackRegion = NumberRange.new(entry.fileStart, entry.fileEnd)
			local fadeOut = deps.fadeOut
			if entry.endFade ~= nil and fadeOut ~= nil then
				fadeOut(copy, (entry.fileEnd - entry.fileStart - entry.endFade) / speed, entry.endFade / speed)
			end
		end
		copy.Parent = deps.root

		local attachment: Attachment? = nil
		if inWorld then
			local place = Instance.new("Attachment")
			place.Parent = deps.worldParent
			place.WorldPosition = at :: Vector3 -- a world row without a place returned above
			local emitter = Instance.new("AudioEmitter")
			emitter.DistanceAttenuationMode = Enum.DistanceAttenuationMode.Custom
			emitter:SetDistanceAttenuation(
				if entry.group == "WholeValley" then Config.Audio.WholeValleyCurve else Config.Audio.NearbyCurve
			)
			emitter.Parent = place
			wire(copy, emitter, copy)
			attachment = place
		else
			wire(copy, (options and options.into) or (if isTune(entry) then music else effects), copy)
		end

		local item: Active = { copy = copy, attachment = attachment, connection = { Disconnect = function() end } }
		table.insert(list, item)
		item.connection = deps.ended(copy, function()
			finish(rowName, item)
		end)
		deps.startPlaying(copy)

		table.insert(log, { row = rowName, time = deps.now(), place = at })
		if #log > LOG_LIMIT then
			table.remove(log, 1)
		end
		local count: any = deps.root:GetAttribute("PlayCount")
		deps.root:SetAttribute("PlayCount", (if type(count) == "number" then count else 0) + 1)
		deps.root:SetAttribute("LastPlay", string.format("%s @ %.2f", rowName, deps.now()))
		return copy
	end

	local function destroy()
		for rowName in active do
			stop(rowName)
		end
		for _, instance in made do
			instance:Destroy()
		end
		table.clear(made)
	end

	return { play = play, stop = stop, music = music, log = log, destroy = destroy }
end

return SoundBoard
