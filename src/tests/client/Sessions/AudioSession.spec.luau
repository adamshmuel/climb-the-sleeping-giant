--!strict
-- A whole session with sound (plan 7 Task 18, Steps 2 to 4). One real SoundBoard with Music, Snore, Moments, Footsteps and
-- the music button over it, one fake clock (AudioRig). The `it`s run in order on one session: a player joins at 10% and
-- plays on through a grab, a bank, a boot jump, 60%, Tiptoe, 85%, a free save, a Rare bank, the wake-up, a bonk, a catch,
-- the lie-down, the music button off and a second wake. Each beat checks the sounds it played and the screen partner it
-- showed at the same clock. The last `it`s check the whole session: the board log, the 3-copies cap, the partners and
-- that nothing was wired to a real speaker.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(ServerScriptService.Server.Giant.Noise)
local SoundList = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundList)
local Cues = require(StarterPlayer.StarterPlayerScripts.Client.Audio.Cues)
local AudioRig = require(script.Parent.AudioRig)

local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll = JestGlobals.beforeAll, JestGlobals.afterAll

local TIME_DIGITS = 3 -- a clock time is checked to a thousandth of a second (1000.3 - 1000 comes out a hair off)
local BOOT_JUMP_NOISE = Noise.jumpBurst("Boots") -- what a boot jump sends with the Thud remote (GiantDirector sends this)
local BIRDS_DELAY = (Cues.forName("WakeBirds") :: Cues.Cue).delay :: number
local ZZZ_DELAY = (Cues.forName("ZzzPop") :: Cues.Cue).delay :: number
local MOMENT_LAG = ZZZ_DELAY -- the longest cue delay (Z Z Z popping): its partner shows at most this long before the sound

local function rowsOf(beat: AudioRig.Beat): { string }
	local rows: { string } = {}
	for _, record in beat.plays do
		table.insert(rows, record.row)
	end
	return rows
end

local function timesOf(beat: AudioRig.Beat, row: string): { number }
	local times: { number } = {}
	for _, record in beat.plays do
		if record.row == row then
			table.insert(times, record.time)
		end
	end
	return times
end

local function playerVolume(row: string): number
	local entry = SoundList.byName(row)
	return SoundList.playerVolume(if entry then entry.loudness else 0)
end

describe("a whole session with sound", function()
	local session: AudioRig.Session

	beforeAll(function()
		session = AudioRig.new()
	end)

	afterAll(function()
		session.destroy()
	end)

	it("join at 10%: the calm tune fades in and the snore plays", function()
		local midFade = -1
		local beat = session.beat("join at 10%", function()
			session.snorePuffs("Normal")
			session.advance(0.5)
			midFade = session.calmFader().Volume
			session.advance(1.0)
		end)
		expect(#timesOf(beat, "Calm tune (loop)")).toBe(1)
		expect(midFade > 0 and midFade < 1).toBe(true)
		expect(session.calmFader().Volume).toBeCloseTo(1, 2)
		local snores = timesOf(beat, "Snore (loop)")
		expect(#snores).toBe(1)
		expect(beat.screens[1].screen).toBe("The snore puffs")
		-- The puffs show at once; the snore loop starts on the next frame step (Snore.onStep), 0.1 s later at most.
		expect(snores[1] - beat.screens[1].at).toBeLessThanOrEqual(0.1 + 1e-6)
		expect(snores[1] >= beat.screens[1].at).toBe(true)
		expect(#session.liveCopies("Snore (loop)")).toBe(1)
	end)

	it("grab a Common: the pluck plays with the carry pill", function()
		local beat = session.beat("grab Common", function()
			session.grab("Common")
		end)
		expect(table.find(rowsOf(beat), "Grab pluck") ~= nil).toBe(true)
		expect(beat.screens[1].screen).toBe("The carry pill")
		expect(beat.screens[1].at).toBeCloseTo(timesOf(beat, "Grab pluck")[1], TIME_DIGITS)
	end)

	it("bank a Common: the toot plays with the Safe card, and no Rare hit", function()
		local beat = session.beat("bank Common", function()
			session.bank("Common")
		end)
		local rows = rowsOf(beat)
		expect(table.find(rows, "Egg home toot") ~= nil).toBe(true)
		expect(table.find(rows, "Egg home, Rare: happy hit")).toBe(nil)
		expect(beat.screens[1].screen).toBe('The "Safe!" card, the confetti')
		expect(beat.screens[1].at).toBeCloseTo(timesOf(beat, "Egg home toot")[1], TIME_DIGITS)
	end)

	it("a boot jump: the flump plays with the meter jumping", function()
		local beat = session.beat("boot jump", function()
			session.thud(BOOT_JUMP_NOISE)
		end)
		expect(table.find(rowsOf(beat), 'Thud "flump"') ~= nil).toBe(true)
		expect(beat.screens[1].screen).toBe("The meter jumping")
		expect(beat.screens[1].at).toBeCloseTo(timesOf(beat, 'Thud "flump"')[1], TIME_DIGITS)
		-- The noise really picks the loudness: the copy's Volume is the flump's loudness for this noise.
		local flump = SoundList.byName('Thud "flump"')
		local byThud = if flump then flump.loudnessByThud else nil
		expect(byThud ~= nil and byThud[BOOT_JUMP_NOISE] ~= nil).toBe(true)
		local copy = session.started[#session.started]
		expect(copy.Name).toBe('Copy Thud "flump"')
		expect(copy.Volume).toBeCloseTo(SoundList.playerVolume((byThud :: { [number]: number })[BOOT_JUMP_NOISE]), 3)
	end)

	it("60%: the snore pauses 2 s then comes back at half, the music goes half and muffled", function()
		local snoreAt20 = -1
		local live: { AudioPlayer } = {}
		local beat = session.beat("60%", function()
			session.setMeter(Config.Meter.WarningMarks[1])
			session.snorePuffs("Off")
			session.after(2, function()
				session.snorePuffs("Normal")
			end)
			session.advance(0.2)
			live = session.liveCopies("Snore (loop)")
			session.advance(1.5) -- 1.7 s into the pause
			snoreAt20 = #session.liveCopies("Snore (loop)")
			session.advance(1.3) -- 3.0 s: the music has settled
		end)
		expect(#live).toBe(0)
		expect(snoreAt20).toBe(0)
		local back = session.liveCopies("Snore (loop)")
		expect(#back).toBe(1)
		expect(back[1].Volume).toBeCloseTo(playerVolume("Snore (loop)") * Config.Audio.LightSnoreFactor, 2)
		expect(#timesOf(beat, "Snore (loop)")).toBe(1)
		expect(session.calmFader().Volume).toBeCloseTo(Config.Audio.ThinnedMusicFactor, 2)
		expect(session.muffle().Frequency).toBeCloseTo(Config.Audio.MuffledCutoffHz, -1)
	end)

	it("Tiptoe on: the click plays with the button and the footsteps go quiet", function()
		local beat = session.beat("Tiptoe on", function()
			session.tiptoe(true)
		end)
		expect(table.find(rowsOf(beat), "Tiptoe click") ~= nil).toBe(true)
		expect(beat.screens[1].screen).toBe("The Tiptoe button")
		expect(beat.screens[1].at).toBeCloseTo(timesOf(beat, "Tiptoe click")[1], TIME_DIGITS)
		expect(session.clips.running.Volume).toBeCloseTo(session.footstepVolume * Config.Audio.TiptoeFootstepFactor, 2)
		expect(session.clips.climbing.Volume).toBeCloseTo(session.footstepVolume * Config.Audio.TiptoeFootstepFactor, 2)
	end)

	it("85%: the snore stops in 0.1 s, two snorts, the music silent by 1 s, the mumble at 1 s", function()
		local snore = session.liveCopies("Snore (loop)")[1]
		local t0 = session.now()
		local calmAtOneSecond = -1
		local beat = session.beat("85%", function()
			session.warn85(90)
			session.advance(1.0)
			calmAtOneSecond = session.calmFader().Volume
			session.advance(0.6)
		end)
		local gone = session.endedAt(snore)
		expect(gone ~= nil).toBe(true)
		expect((gone :: number) - t0).toBeLessThanOrEqual(Config.Audio.SnoreStopSeconds + 1e-6)
		local snorts = timesOf(beat, "85% snort (two)")
		expect(#snorts).toBe(2)
		expect(snorts[1]).toBeCloseTo(t0 + Config.Audio.WarningTimes.SnortOne, TIME_DIGITS)
		expect(snorts[2]).toBeCloseTo(t0 + Config.Audio.WarningTimes.SnortTwo, TIME_DIGITS)
		local mumble = timesOf(beat, '"Mmm..." mumble')
		expect(#mumble).toBe(1)
		expect(mumble[1]).toBeCloseTo(t0 + Config.Audio.WarningTimes.Mumble, TIME_DIGITS)
		expect(calmAtOneSecond).toBeCloseTo(0, 2)
		expect(#session.liveCopies("Snore (loop)")).toBe(0)
		local shown: { string } = {}
		for _, item in beat.screens do
			table.insert(shown, `{item.screen}`)
		end
		expect(shown).toEqual({ "The snore puffs", "The snort puffs", "The snort puffs", "The bubble" })
		expect(beat.screens[2].at).toBeCloseTo(snorts[1], TIME_DIGITS)
		expect(beat.screens[3].at).toBeCloseTo(snorts[2], TIME_DIGITS)
		expect(beat.screens[4].at).toBeCloseTo(mumble[1], TIME_DIGITS)
	end)

	it("a free save: the snorts and the mumble play again and the snore stays off", function()
		local t0 = session.now()
		local beat = session.beat("free save", function()
			session.warn85(70)
			session.advance(1.6)
		end)
		local snorts = timesOf(beat, "85% snort (two)")
		expect(#snorts).toBe(2)
		expect(snorts[1]).toBeCloseTo(t0, TIME_DIGITS)
		expect(#timesOf(beat, '"Mmm..." mumble')).toBe(1)
		expect(#session.liveCopies("Snore (loop)")).toBe(0)
		expect(#timesOf(beat, "Snore (loop)")).toBe(0)
	end)

	it("bank a Rare: the toot and the happy hit play, and no row ever had more than 3 copies", function()
		session.beat("grab Rare", function()
			session.grab("Rare")
		end)
		local beat = session.beat("bank Rare", function()
			session.bank("Rare")
		end)
		local rows = rowsOf(beat)
		expect(table.find(rows, "Egg home toot") ~= nil).toBe(true)
		expect(table.find(rows, "Egg home, Rare: happy hit") ~= nil).toBe(true)
		expect(beat.screens[1].screen).toBe('The "Safe!" card, the confetti')
		expect(session.overCap()).toEqual({})
	end)

	-- Every effect of a wake, with the screen place it shows with. Run twice (the second time with the music off).
	local function wakeUp(): number
		local t0 = session.now()
		session.wake()
		session.sound('The red "!"', "WakeEyes")
		session.sound("His open mouth", "WakeRoar", session.places.mouth)
		session.sound("The shake", "WakeRumble")
		session.sound("The birds", "WakeBirds", session.places.birds)
		session.sound("The Z Z Z bubble pop", "ZzzPop", session.places.bubble)
		session.bounce(8)
		session.advance(Config.Audio.ChaseStartSeconds + Config.Audio.MusicFadeSeconds + 0.2) -- the chase starts, then fades in
		return t0
	end
	local function expectWakeEffects(beat: AudioRig.Beat, t0: number)
		for _, row in { '"!" sting', "Cartoon roar (no words)", "Rumble" } do
			expect(timesOf(beat, row)).toEqual({ beat.plays[1].time })
		end
		expect(timesOf(beat, '"!" sting')[1]).toBeCloseTo(t0, TIME_DIGITS)
		expect(timesOf(beat, "Birds flapping")[1]).toBeCloseTo(t0 + BIRDS_DELAY, TIME_DIGITS)
		expect(timesOf(beat, "Z Z Z popping")[1]).toBeCloseTo(t0 + ZZZ_DELAY, TIME_DIGITS)
		expect(#timesOf(beat, 'Bounce-off "boing"')).toBe(Config.Audio.MaxCopies) -- 8 bounced, 3 heard
		expect(beat.live['Bounce-off "boing"']).toBe(Config.Audio.MaxCopies)
	end

	it("he wakes: sting, roar, rumble, birds, Z Z Z, three boings for eight bounced, the chase tune at 1 s", function()
		local t0 = -1
		local beat = session.beat("wake", function()
			t0 = wakeUp()
		end)
		expectWakeEffects(beat, t0)
		local chase = timesOf(beat, "Chase tune (loop)")
		expect(#chase).toBe(1)
		local after = chase[1] - t0
		expect(
			after >= Config.Audio.ChaseStartSeconds - 1e-6
				and after <= Config.Audio.ChaseStartSeconds + session.stepSeconds + 1e-6
		).toBe(true)
		expect(session.chaseFader().Volume).toBeCloseTo(1, 2)
		expect(session.calmFader().Volume).toBeCloseTo(0, 2)
	end)

	it("a bonk: the bonk and its twinkle play with the tumble and the stars", function()
		local beat = session.beat("bonk", function()
			session.sound("The tumble and the stars", "Bonk", session.places.home)
		end)
		expect(rowsOf(beat)).toEqual({ "Bonk", "Bonk twinkle" })
		expect(beat.screens[1].screen).toBe("The tumble and the stars")
		expect(beat.screens[1].at).toBeCloseTo(timesOf(beat, "Bonk")[1], TIME_DIGITS)
	end)

	it("grabbed then caught: the pluck, the whoosh with the Caught card, the egg pops back", function()
		local grabbed = session.beat("grab in the chase", function()
			session.grab("Common")
		end)
		expect(table.find(rowsOf(grabbed), "Grab pluck") ~= nil).toBe(true)
		local beat = session.beat("caught", function()
			session.caught()
			session.eggPopsBack()
		end)
		expect(rowsOf(beat)).toEqual({ 'Caught "whoosh"', 'Egg "pop"' })
		expect(beat.screens[1].screen).toBe('The "Caught!" card')
		expect(beat.screens[2].screen).toBe("The refill pop's stars (back)")
		expect(beat.screens[2].at).toBeCloseTo(timesOf(beat, 'Egg "pop"')[1], TIME_DIGITS)
	end)

	it("he lies down: the yawn, the Heavy Sleep snore, the calm tune back and the chase tune gone", function()
		local beat = session.beat("lies down", function()
			session.sound("He lies down, the Heavy Sleep Z Z Z", "LieDown", session.places.mouth)
			session.lieDown()
			session.snorePuffs("Heavy")
			session.advance(4)
		end)
		expect(table.find(rowsOf(beat), "Big yawn") ~= nil).toBe(true)
		expect(#timesOf(beat, "Heavy Sleep snore (loop)")).toBe(1)
		expect(#session.liveCopies("Heavy Sleep snore (loop)")).toBe(1)
		expect(session.calmFader().Volume).toBeCloseTo(1, 2)
		expect(session.chaseFader().Volume).toBeCloseTo(0, 2)
		expect(#session.liveCopies("Chase tune (loop)")).toBe(0)
	end)

	it("the music button off: the click plays, the server is told, the bus is silent", function()
		local beat = session.beat("music off", function()
			session.tapMusicButton()
		end)
		expect(rowsOf(beat)).toEqual({ "Music button click" })
		expect(beat.screens[1].screen).toBe("The button changing")
		expect(session.sends).toEqual({ false })
		expect((session.board.music :: AudioFader).Volume).toBe(0)
	end)

	it("a second wake with the music off: every effect plays and the music bus stays silent", function()
		session.snorePuffs("Off")
		local t0 = -1
		local beat = session.beat("second wake", function()
			t0 = wakeUp()
		end)
		expectWakeEffects(beat, t0)
		expect(#timesOf(beat, "Heavy Sleep snore (loop)")).toBe(0)
		expect(#session.liveCopies("Heavy Sleep snore (loop)")).toBe(0)
		-- No chase tune is heard: the button keeps the whole music bus at 0. The chase copy still starts, and its wires
		-- lead (copy, chase fader, muffle filter) into that bus, so it is silent only because the bus is.
		local chase = session.liveCopies("Chase tune (loop)")
		expect(#chase).toBe(1)
		local nextOf: { [Instance]: { Instance } } = {}
		local roots: { Instance } = { session.root, session.worldParent }
		for _, top in roots do
			for _, item in top:GetDescendants() do
				if item:IsA("Wire") then
					local from: Instance? = item.SourceInstance
					local to: Instance? = item.TargetInstance
					if from ~= nil and to ~= nil then
						local list: { Instance } = nextOf[from] or {}
						table.insert(list, to)
						nextOf[from] = list
					end
				end
			end
		end
		local seen: { [Instance]: boolean } = { [chase[1]] = true }
		local queue: { Instance } = { chase[1] }
		local reachesBus = false
		while #queue > 0 do
			local at = table.remove(queue, 1) :: Instance
			if at == session.board.music then
				reachesBus = true
				break
			end
			local targets: { Instance } = nextOf[at] or {}
			for _, target in targets do
				if not seen[target] then
					seen[target] = true
					table.insert(queue, target)
				end
			end
		end
		expect(reachesBus).toBe(true)
		expect((session.board.music :: AudioFader).Volume).toBe(0)
		expect(session.sends).toEqual({ false })
	end)

	-- The checks over the whole session.
	local PARTNER_OF: { [string]: string } = {
		["Chase tune (loop)"] = 'His waking face, "RUN HOME!", the red edges',
		["Snore (loop)"] = "The snore puffs",
		["Heavy Sleep snore (loop)"] = "The snore puffs",
		["85% snort (two)"] = "The snort puffs",
		['"Mmm..." mumble'] = "The bubble",
		['"!" sting'] = 'The red "!"',
		["Cartoon roar (no words)"] = "His open mouth",
		["Rumble"] = "The shake",
		["Birds flapping"] = "The birds",
		["Z Z Z popping"] = "The Z Z Z bubble pop",
		['Bounce-off "boing"'] = "The float",
		["Big yawn"] = "He lies down, the Heavy Sleep Z Z Z",
		["Bonk"] = "The tumble and the stars",
		["Bonk twinkle"] = "The tumble and the stars",
		['Caught "whoosh"'] = 'The "Caught!" card',
		["Grab pluck"] = "The carry pill",
		["Grab shimmer"] = "The carry pill",
		["Egg home toot"] = 'The "Safe!" card, the confetti',
		["Egg home, Rare: happy hit"] = 'The "Safe!" card, the confetti',
		['Egg "pop"'] = "The refill pop's stars (back)",
		['Thud "flump"'] = "The meter jumping",
		["Tiptoe click"] = "The Tiptoe button",
		["Music button click"] = "The button changing",
	} -- "Calm tune (loop)" is left out: the meter is on screen all the time
	local LATE: { [string]: number } = { ["Chase tune (loop)"] = Config.Audio.ChaseStartSeconds } -- it starts 1 s later

	it("check 1, moments: the beats saw exactly what the board played, in time order, only real rows", function()
		local seen = 0
		for _, item in session.beats do
			seen += #item.plays
		end
		expect(#session.board.log).toBe(seen)
		expect(session.root:GetAttribute("PlayCount")).toBe(seen)
		local last = -math.huge
		for _, record in session.board.log do
			expect(SoundList.byName(record.row) ~= nil).toBe(true)
			expect(record.time >= last).toBe(true)
			last = record.time
		end
	end)

	it("check 2, 3 copies: no row ever had more than the cap", function()
		expect(session.overCap()).toEqual({})
	end)

	it("check 3, partners: every sound had its screen partner, shown no later than it", function()
		local missing: { string } = {}
		for _, item in session.beats do
			for _, record in item.plays do
				local partner = PARTNER_OF[record.row]
				if partner == nil then
					if record.row ~= "Calm tune (loop)" then
						table.insert(missing, `{item.name}: {record.row} has no partner`)
					end
					continue
				end
				local lag = LATE[record.row] or MOMENT_LAG
				local shown = false
				for _, screen in item.screens do
					local wait = record.time - screen.at
					if screen.screen == partner and wait >= -1e-6 and wait <= lag + 1e-6 then
						shown = true
					end
				end
				if not shown then
					table.insert(missing, `{item.name}: {record.row} was not shown with "{partner}"`)
				end
			end
		end
		expect(missing).toEqual({})
	end)

	it("check 4, no speaker: nothing in the rig was wired to an AudioDeviceOutput", function()
		local wires, toSpeaker = session.wires()
		expect(wires > 0).toBe(true) -- the scan did see the rig's wires
		expect(toSpeaker).toBe(0)
	end)
end)
