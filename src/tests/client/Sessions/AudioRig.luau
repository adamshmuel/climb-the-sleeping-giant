--!strict
-- The rig for the whole-session sound test (plan 7 Task 18). One real SoundBoard over fake engine deps (SoundBoard.spec's
-- rig, smaller: nothing is heard) with Music, Snore, Moments, Footsteps and the music button started over it. They share one
-- fake clock, one giant state and one player. Cues and MusicMix are pure and are used through Moments and Music.
--   * advance(seconds) moves the clock in 0.1 s steps; each step fires `step`, then runs the delayed calls that are due.
--   * The stand-ins for the screen places (the snore puffs, the bubble, the carry pill, ...) record
--     { screen = <what the screen shows with the sound>, at = clock } when they call their sound place (the "On screen
--     with it" column of docs/plans/v2/audio.md, "Every sound, and what the screen shows with it").
--   * beat(name, action) runs one beat and gives back what it played, what the screen showed and how many copies of each
--     row were live (the 3-copies check), then ends every live copy that does not loop, so the cap never skips a later beat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Client = StarterPlayer.StarterPlayerScripts.Client
local Footsteps = require(Client.Audio.Footsteps)
local MusicButton = require(Client.Hud.MusicButton)
local Moments = require(Client.Audio.Moments)
local Music = require(Client.Audio.Music)
local Snore = require(Client.Audio.Snore)
local SoundBoard = require(Client.Audio.SoundBoard)

local AudioRig = {}

local START = 1000 -- the clock when the session starts (as Music.spec)
local DT = 0.1 -- one step of the fake clock
local ROUNDING = 1e-6 -- 1000.3 - 1000 comes out a hair off; closer than this to a time counts as on it
local MOUTH = Vector3.new(0, 80, -40) -- his mouth (Snore.spec's constant)
local NOSE = Vector3.new(0, 82, -42) -- the tip of his nose
local HOME = Vector3.new(0, 5, 0) -- where this player stands
local CLEAR_ROW_PREFIX = "Copy " -- SoundBoard names each copy "Copy <row>"
local FOOTSTEP_VOLUME = 0.6 -- a footstep clip's own Volume
local TOPBAR = { minX = 164, height = 58 } -- the top bar's rectangle (MusicButton.spec's)

-- Places in the valley the stand-ins play at.
local PLACES = {
	mouth = MOUTH,
	home = HOME,
	birds = Vector3.new(0, 120, -40), -- the middle of the flock
	bubble = Vector3.new(0, 95, -40), -- above his head
}

export type Screen = { screen: string, at: number }
export type Beat = {
	name: string,
	plays: { SoundBoard.LogRecord }, -- what the board played during the beat, oldest first
	screens: { Screen }, -- what the screen showed during the beat
	live: { [string]: number }, -- copies of each row playing at the end of the beat, before they are ended
}
export type Session = {
	board: SoundBoard.Board,
	root: Folder,
	output: AudioFader,
	worldParent: Part,
	giant: Folder, -- Phase, Meter, PhaseEndsAt
	player: Folder, -- this device's player: InGarden, Carrying, Tiptoe, Floating
	players: Folder, -- every player (this one too)
	positions: { [Instance]: Vector3 },
	started: { AudioPlayer }, -- every copy the board started, in order
	screens: { Screen }, -- everything the screen showed, in order
	beats: { Beat },
	sends: { boolean }, -- what the music button told the server
	clips: { running: AudioPlayer, climbing: AudioPlayer },
	music: Music.Handle,
	snore: Snore.Handle,
	moments: Moments.Handle,
	footsteps: Footsteps.Handle,
	button: MusicButton.Handle,
	footstepVolume: number, -- the Running and Climbing clips' own Volume
	stepSeconds: number, -- one step of the fake clock
	places: { mouth: Vector3, home: Vector3, birds: Vector3, bubble: Vector3 },
	now: () -> number,
	advance: (seconds: number) -> (),
	after: (seconds: number, callback: () -> ()) -> (),
	beat: (name: string, action: () -> ()) -> Beat,
	endedAt: (copy: AudioPlayer) -> number?, -- the clock when the copy went away, nil while it is there
	liveCopies: (row: string) -> { AudioPlayer },
	overCap: () -> { string }, -- "<beat>: <row> <count>" for each beat that had more copies of a row than the cap
	calmFader: () -> AudioFader,
	chaseFader: () -> AudioFader,
	muffle: () -> AudioFilter,
	-- Screen-place stand-ins:
	setMeter: (meter: number) -> (),
	snorePuffs: (puffs: Snore.Puffs) -> (), -- "The snore puffs"
	warn85: (meterAfter: number) -> (), -- the warning: puffs off, snort at 0 s and 0.5 s, mumble at 1.0 s
	grab: (rank: string) -> (), -- "The carry pill"
	bank: (rank: string) -> (), -- "The \"Safe!\" card, the confetti"
	thud: (noise: number) -> (), -- "The meter jumping"
	tiptoe: (on: boolean) -> (), -- "The Tiptoe button"
	tapMusicButton: () -> (), -- "The button changing"
	-- Wake-up to the end:
	sound: (partner: string, name: string, at: Vector3?) -> (), -- a screen place shows its partner, then calls its sound place
	wake: () -> (), -- "His waking face": Phase turns Awake (PhaseEndsAt first, as the server writes them)
	bounce: (count: number) -> (), -- `count` players float, "The float" for each (they land first if they floated before)
	lieDown: () -> (), -- the Phase turns HeavySleep and the meter drops
	caught: () -> (), -- 'The "Caught!" card': the whoosh plays and the egg leaves the carrier
	eggPopsBack: () -> (), -- "The refill pop's stars (back)": the egg pops back on its nest
	wires: () -> (number, number), -- wires seen in the rig, and how many of them went to an AudioDeviceOutput
	destroy: () -> (),
}

local function settle()
	task.wait() -- attribute changes and BindableEvents reach their listeners a moment after they are set or fired
end

function AudioRig.new(): Session
	local made: { Instance } = {}
	local function make<T>(instance: T & Instance): T
		table.insert(made, instance)
		return instance
	end

	-- The clock, and the delayed calls that follow it.
	local ticks = 0
	local function now(): number
		return START + ticks * DT
	end
	type Later = { due: number, callback: () -> () }
	local later: { Later } = {}
	local function after(seconds: number, callback: () -> ())
		table.insert(later, { due = now() + seconds, callback = callback })
	end
	local function runDue()
		local index = 1
		while index <= #later do
			local item = later[index]
			if item.due <= now() + ROUNDING then
				table.remove(later, index)
				item.callback()
			else
				index += 1
			end
		end
	end

	-- The real board over fake engine deps.
	local root = make(Instance.new("Folder"))
	local output = make(Instance.new("AudioFader"))
	local worldParent = make(Instance.new("Part"))
	local wiresSeen = 0
	local wiresToSpeaker = 0
	local function noteWire(item: Instance)
		if item:IsA("Wire") then
			wiresSeen += 1
			local target: Instance? = item.TargetInstance
			if target ~= nil and target:IsA("AudioDeviceOutput") then
				wiresToSpeaker += 1
			end
		end
	end
	root.DescendantAdded:Connect(noteWire)
	worldParent.DescendantAdded:Connect(noteWire)
	local started: { AudioPlayer } = {}
	local rowOf: { [AudioPlayer]: string } = {}
	local endedCallbacks: { [AudioPlayer]: () -> () } = {}
	local endedAtMap: { [AudioPlayer]: number } = {}
	local board = SoundBoard.start({
		root = root,
		output = output,
		worldParent = worldParent,
		startPlaying = function(copy: AudioPlayer)
			table.insert(started, copy)
			rowOf[copy] = string.sub(copy.Name, #CLEAR_ROW_PREFIX + 1)
		end,
		isReady = function(_copy: AudioPlayer): boolean
			return true
		end,
		ended = function(copy: AudioPlayer, callback: () -> ())
			endedCallbacks[copy] = callback
			return {
				Disconnect = function()
					endedCallbacks[copy] = nil
				end,
			}
		end,
		fadeOut = function(_copy: AudioPlayer, _afterSeconds: number, _seconds: number) end,
		now = now,
	})

	-- The shared state: the giant, this player and everybody.
	local giant = make(Instance.new("Folder"))
	giant:SetAttribute("Phase", "Asleep")
	giant:SetAttribute("Meter", 10)
	local players = make(Instance.new("Folder"))
	local player = make(Instance.new("Folder"))
	player:SetAttribute("InGarden", 0)
	player.Parent = players
	local positions: { [Instance]: Vector3 } = { [player] = HOME }

	-- A fake character: the Running and Climbing clips under a HumanoidRootPart.
	local character = make(Instance.new("Model"))
	local characterRoot = Instance.new("Part")
	characterRoot.Name = "HumanoidRootPart"
	characterRoot.Parent = character
	local function newClip(name: string): AudioPlayer
		local clip = Instance.new("AudioPlayer")
		clip.Name = name
		clip.Volume = FOOTSTEP_VOLUME
		clip.Parent = characterRoot
		return clip
	end
	local clips = { running = newClip("Running"), climbing = newClip("Climbing") }
	local characterAdded = make(Instance.new("BindableEvent"))

	-- The signals: the real Signal for the frame step and for the 85% warning; a BindableEvent's Event where the dep wants
	-- an RBXScriptConnection.
	local step = Signal.new()
	local warning = Signal.new()
	-- Music and Snore want only `Connect`; this shows the real Signal's Connect and nothing else.
	local function connectOnly(signal: typeof(step)): Music.SignalLike
		return {
			Connect = function(_self: any, callback: (...any) -> ()): SoundBoard.Disconnectable
				return signal:Connect(callback)
			end,
		}
	end
	local eggHome = make(Instance.new("BindableEvent"))
	local eggPop = make(Instance.new("BindableEvent"))
	local thudRemote = make(Instance.new("BindableEvent"))
	local rescued = make(Instance.new("BindableEvent"))

	local music = Music.start({
		board = board,
		root = root,
		step = connectOnly(step),
		giantState = giant,
		player = player,
		warning = { OnClientEvent = connectOnly(warning) },
		serverNow = now,
		hasCharacter = function(): boolean
			return true
		end,
	})
	local snore = Snore.start({
		board = board,
		step = connectOnly(step),
		now = now,
		meter = function(): number
			local meter = giant:GetAttribute("Meter")
			return if type(meter) == "number" then meter else 0
		end,
		mouth = function(): Vector3?
			return MOUTH
		end,
		random = function(): number
			return 0.5
		end,
		looped = function(_copy: AudioPlayer, _callback: () -> ()): SoundBoard.Disconnectable
			return { Disconnect = function() end } -- nothing here ever loops back round
		end,
	})
	local moments = Moments.start({
		board = board,
		after = after,
		playerList = players,
		localPlayer = player,
		rootOf = function(who: Instance): Vector3?
			return positions[who]
		end,
	})
	moments.hearEggHome({ OnClientEvent = eggHome.Event })
	moments.hearEggPop({ OnClientEvent = eggPop.Event })
	moments.hearThud({ OnClientEvent = thudRemote.Event })
	moments.hearRescued({ OnClientEvent = rescued.Event })
	local footsteps = Footsteps.start({
		player = {
			Character = character,
			CharacterAdded = characterAdded.Event,
			GetAttribute = function(_self: any, name: string): any
				return player:GetAttribute(name)
			end,
			GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
				return player:GetAttributeChangedSignal(name)
			end,
		},
		names = { "Running", "Climbing" },
		playClick = function()
			board.play("Tiptoe click")
		end,
	})
	local sends: { boolean } = {}
	local hud = make(Instance.new("Folder"))
	local button = MusicButton.start({
		parent = hud,
		topbar = {
			get = function()
				return TOPBAR
			end,
			connect = function(_callback: () -> ()): () -> ()
				return function() end
			end,
		},
		hudLeft = function(): number
			return 0
		end,
		music = music,
		send = function(on: boolean)
			table.insert(sends, on)
		end,
		click = function()
			board.play("Music button click")
		end,
	})
	settle() -- Moments' and Footsteps' listeners are connected

	-- The steps of the clock.
	local function noteEnded()
		for _, copy in started do
			if endedAtMap[copy] == nil and copy.Parent == nil then
				endedAtMap[copy] = now()
			end
		end
	end
	local function advance(seconds: number)
		for _ = 1, math.round(seconds / DT) do
			ticks += 1
			step:Fire(DT)
			runDue()
			noteEnded()
		end
	end

	local function liveCopies(row: string): { AudioPlayer }
		local found: { AudioPlayer } = {}
		for _, copy in started do
			if rowOf[copy] == row and copy.Parent ~= nil then
				table.insert(found, copy)
			end
		end
		return found
	end

	local screens: { Screen } = {}
	local function show(screen: string)
		table.insert(screens, { screen = screen, at = now() })
	end

	local beats: { Beat } = {}
	local function beat(name: string, action: () -> ()): Beat
		local playsBefore = root:GetAttribute("PlayCount") :: number
		local screensBefore = #screens
		action()
		noteEnded()
		local count = (root:GetAttribute("PlayCount") :: number) - playsBefore
		local plays: { SoundBoard.LogRecord } = {}
		for index = #board.log - count + 1, #board.log do
			table.insert(plays, board.log[index])
		end
		local shown: { Screen } = {}
		for index = screensBefore + 1, #screens do
			table.insert(shown, screens[index])
		end
		-- The 3-copies check counts the copies that are playing now; then every copy that doesn't loop ends.
		local live: { [string]: number } = {}
		for _, copy in started do
			if copy.Parent ~= nil then
				live[rowOf[copy]] = (live[rowOf[copy]] or 0) + 1
			end
		end
		for _, copy in table.clone(started) do
			local callback = endedCallbacks[copy]
			if copy.Parent ~= nil and not copy.Looping and callback ~= nil then
				callback()
			end
		end
		noteEnded()
		local result: Beat = { name = name, plays = plays, screens = shown, live = live }
		table.insert(beats, result)
		return result
	end

	local function overCap(): { string }
		local found: { string } = {}
		for _, item in beats do
			for row, count in item.live do
				if count > Config.Audio.MaxCopies then
					table.insert(found, `{item.name}: {row} {count}`)
				end
			end
		end
		return found
	end

	-- Screen-place stand-ins: each shows its partner, then calls its sound place.
	local function snorePuffs(puffs: Snore.Puffs)
		show("The snore puffs")
		snore.setPuffs(puffs)
	end
	local function warn85(meterAfter: number)
		giant:SetAttribute("Meter", meterAfter)
		warning:Fire(Config.Meter.WarningMarks[2])
		snorePuffs("Off")
		show("The snort puffs")
		moments.play("Snort1", NOSE)
		after(Config.Audio.WarningTimes.SnortTwo, function()
			show("The snort puffs")
			moments.play("Snort2", NOSE)
		end)
		after(Config.Audio.WarningTimes.Mumble, function()
			show("The bubble")
			moments.play("Mumble", MOUTH)
		end)
	end
	local function grab(rank: string)
		show("The carry pill")
		player:SetAttribute("Carrying", rank)
		settle()
	end
	local function bank(rank: string)
		show('The "Safe!" card, the confetti')
		eggHome:Fire(player, rank, HOME)
		player:SetAttribute("Carrying", nil)
		settle()
	end
	local function thud(noise: number)
		show("The meter jumping")
		thudRemote:Fire(HOME, noise)
		settle()
	end
	local function tiptoe(on: boolean)
		show("The Tiptoe button")
		player:SetAttribute("Tiptoe", on)
		settle()
	end
	local function tapMusicButton()
		show("The button changing")
		button.toggle()
	end

	-- Wake-up to the end.
	local function sound(partner: string, name: string, at: Vector3?)
		show(partner)
		moments.play(name, at)
	end
	local function wake()
		show('His waking face, "RUN HOME!", the red edges')
		giant:SetAttribute("Meter", 100)
		giant:SetAttribute("PhaseEndsAt", now() + Config.Wake.AwakeSeconds)
		giant:SetAttribute("Phase", "Awake")
	end
	local bouncers: { Folder } = {}
	local function bounce(count: number)
		for _, other in bouncers do
			other:SetAttribute("Floating", false) -- they landed since the last bounce
		end
		while #bouncers < count do
			local other = make(Instance.new("Folder"))
			other:SetAttribute("Floating", false)
			positions[other] = HOME + Vector3.new(#bouncers * 4, 0, 0)
			other.Parent = players
			table.insert(bouncers, other)
		end
		settle() -- the new players are heard
		for index = 1, count do
			show("The float")
			bouncers[index]:SetAttribute("Floating", true)
		end
		settle()
	end
	local function lieDown()
		giant:SetAttribute("PhaseEndsAt", nil)
		giant:SetAttribute("Meter", 0)
		giant:SetAttribute("Phase", "HeavySleep")
	end
	local function caught()
		show('The "Caught!" card')
		moments.play("Caught", nil)
		player:SetAttribute("Carrying", nil)
		settle()
	end
	local function eggPopsBack()
		show("The refill pop's stars (back)")
		eggPop:Fire(HOME, "Back")
		settle()
	end

	local function destroy()
		button.stop()
		footsteps.destroy()
		moments.destroy()
		snore.destroy()
		music.destroy()
		board.destroy()
		step:Destroy()
		warning:Destroy()
		for _, instance in made do
			instance:Destroy()
		end
		table.clear(made)
	end

	return {
		board = board,
		root = root,
		output = output,
		worldParent = worldParent,
		giant = giant,
		player = player,
		players = players,
		positions = positions,
		started = started,
		screens = screens,
		beats = beats,
		sends = sends,
		clips = clips,
		music = music,
		snore = snore,
		moments = moments,
		footsteps = footsteps,
		button = button,
		footstepVolume = FOOTSTEP_VOLUME,
		stepSeconds = DT,
		places = PLACES,
		now = now,
		advance = advance,
		after = after,
		beat = beat,
		endedAt = function(copy: AudioPlayer): number?
			return endedAtMap[copy]
		end,
		liveCopies = liveCopies,
		overCap = overCap,
		calmFader = function(): AudioFader
			return root:FindFirstChild("CalmFader") :: AudioFader
		end,
		chaseFader = function(): AudioFader
			return root:FindFirstChild("ChaseFader") :: AudioFader
		end,
		muffle = function(): AudioFilter
			return root:FindFirstChild("Muffle") :: AudioFilter
		end,
		setMeter = function(meter: number)
			giant:SetAttribute("Meter", meter)
		end,
		snorePuffs = snorePuffs,
		warn85 = warn85,
		grab = grab,
		bank = bank,
		thud = thud,
		tiptoe = tiptoe,
		tapMusicButton = tapMusicButton,
		sound = sound,
		wake = wake,
		bounce = bounce,
		lieDown = lieDown,
		caught = caught,
		eggPopsBack = eggPopsBack,
		wires = function(): (number, number)
			return wiresSeen, wiresToSpeaker
		end,
		destroy = destroy,
	}
end

return AudioRig
