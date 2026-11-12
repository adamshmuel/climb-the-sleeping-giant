--!strict
-- Moments (plan 7 Task 9; spec 7 Rule 92 "The wake-up is loud", Rule 88 "Reduce Motion changes no sound", Rule 86 "8
-- boings"): the named sound places and the players' Floating boings. Silent: the board is a recorder (or the real board
-- over fake engine deps, as SoundBoard.spec does), and "after" is a list the test runs by hand.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)
local Moments = require(StarterPlayer.StarterPlayerScripts.Client.Audio.Moments)
local SoundBoard = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundBoard)
local Helpers = require(script.Parent.Parent.Fx.CameraFx.Helpers)

local PRECISION = 2
local PLACE = Vector3.new(40, 5, -30)
local BOING = 'Bounce-off "boing"'

type Call = { row: string, at: Vector3?, options: SoundBoard.PlayOptions? }
type Later = { seconds: number, callback: () -> () }

type Rig = {
	handle: Moments.Handle,
	players: Folder,
	played: { Call },
	stopped: { string },
	later: { Later },
	positions: { [Instance]: Vector3 },
	localPlayer: Instance,
	eggHome: BindableEvent,
	eggPop: BindableEvent,
	thud: BindableEvent,
	addPlayer: (position: Vector3?) -> Instance,
	setFloating: (player: Instance, floating: boolean) -> (),
}

local made: { Instance } = {}
local handles: { Moments.Handle } = {}

afterEach(function()
	for _, handle in handles do
		handle.destroy()
	end
	table.clear(handles)
	for _, item in made do
		item:Destroy()
	end
	table.clear(made)
end)

-- Moments over a recording board. `board` replaces the recorder (the real board, for the cap test).
local function newRig(board: Moments.Board?, carryingAtStart: string?): Rig
	local players = Instance.new("Folder")
	table.insert(made, players)
	-- Plan 7 Task 11: the local player (a stand-in with a Carrying attribute) and the EggHome remote (a BindableEvent).
	local localPlayer = Instance.new("Folder")
	table.insert(made, localPlayer)
	localPlayer:SetAttribute("Carrying", carryingAtStart)
	local eggHome = Instance.new("BindableEvent")
	table.insert(made, eggHome)
	local eggPop = Instance.new("BindableEvent") -- plan 7 Task 12: the EggPop remote
	table.insert(made, eggPop)
	local thud = Instance.new("BindableEvent") -- plan 7 Task 13: the Thud remote
	table.insert(made, thud)
	local played: { Call } = {}
	local stopped: { string } = {}
	local later: { Later } = {}
	local positions: { [Instance]: Vector3 } = {}
	local recorder: Moments.Board = {
		play = function(rowName: string, at: Vector3?, options: SoundBoard.PlayOptions?)
			table.insert(played, { row = rowName, at = at, options = options })
			return nil
		end,
		stop = function(rowName: string)
			table.insert(stopped, rowName)
		end,
	}
	local handle = Moments.start({
		board = board or recorder,
		after = function(seconds: number, callback: () -> ())
			table.insert(later, { seconds = seconds, callback = callback })
		end,
		playerList = players,
		localPlayer = localPlayer,
		rootOf = function(player: Instance): Vector3?
			return positions[player]
		end,
	})
	table.insert(handles, handle)
	local hearEggHome = (handle :: any).hearEggHome
	if hearEggHome ~= nil then
		hearEggHome({ OnClientEvent = eggHome.Event })
	end
	local hearEggPop = (handle :: any).hearEggPop
	if hearEggPop ~= nil then
		hearEggPop({ OnClientEvent = eggPop.Event })
	end
	local hearThud = (handle :: any).hearThud
	if hearThud ~= nil then
		hearThud({ OnClientEvent = thud.Event })
	end
	local function addPlayer(position: Vector3?): Instance
		local player = Instance.new("Folder")
		player.Parent = players
		if position ~= nil then
			positions[player] = position
		end
		return player
	end
	return {
		handle = handle,
		players = players,
		played = played,
		stopped = stopped,
		later = later,
		positions = positions,
		localPlayer = localPlayer,
		eggHome = eggHome,
		eggPop = eggPop,
		thud = thud,
		addPlayer = addPlayer,
		setFloating = function(player: Instance, floating: boolean)
			player:SetAttribute("Floating", floating)
			task.wait() -- attribute changes reach listeners a moment after they are set
		end,
	}
end

local function runLater(rig: Rig)
	for _, item in table.clone(rig.later) do
		item.callback()
	end
end

-- The real board over fake engine deps: nothing is heard (SoundBoard.spec's rig, smaller).
type RealRig = { board: SoundBoard.Board, started: { AudioPlayer }, root: Folder, worldParent: Part }
local function newRealBoard(): RealRig
	local root = Instance.new("Folder")
	local output = Instance.new("AudioFader")
	local worldParent = Instance.new("Part")
	table.insert(made, root)
	table.insert(made, output)
	table.insert(made, worldParent)
	local started: { AudioPlayer } = {}
	local board = SoundBoard.start({
		root = root,
		output = output,
		worldParent = worldParent,
		startPlaying = function(player: AudioPlayer)
			table.insert(started, player)
		end,
		isReady = function(_player: AudioPlayer): boolean
			return true
		end,
		ended = function(_player: AudioPlayer, _callback: () -> ())
			return { Disconnect = function() end }
		end,
		fadeOut = function(_copy: AudioPlayer, _afterSeconds: number, _seconds: number) end,
		now = function(): number
			return 0
		end,
	})
	return { board = board, started = started, root = root, worldParent = worldParent }
end

describe("Moments.play (the wake sounds)", function()
	it("plays the sting at once, with no place", function()
		local rig = newRig()
		rig.handle.play("WakeEyes", nil)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe('"!" sting')
		expect(rig.played[1].at).toBe(nil)
		expect(#rig.later).toBe(0)
	end)

	it("plays the roar at once, at the place it is given", function()
		local rig = newRig()
		rig.handle.play("WakeRoar", PLACE)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe("Cartoon roar (no words)")
		expect(rig.played[1].at).toEqual(PLACE)
	end)

	it("plays the rumble at once with a 1 second fade", function()
		local rig = newRig()
		rig.handle.play("WakeRumble", nil)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe("Rumble")
		local options = rig.played[1].options :: SoundBoard.PlayOptions
		local fade = options.fade :: { after: number, seconds: number }
		expect(fade.after).toBeCloseTo(0, PRECISION)
		expect(fade.seconds).toBeCloseTo(1, PRECISION)
	end)

	it("holds the birds back 0.2 seconds and the Z Z Z pop 0.3 seconds, through the clock it is given", function()
		local rig = newRig()
		rig.handle.play("WakeBirds", nil)
		rig.handle.play("ZzzPop", PLACE)
		expect(#rig.played).toBe(0)
		expect(#rig.later).toBe(2)
		expect(rig.later[1].seconds).toBeCloseTo(0.2, PRECISION)
		expect(rig.later[2].seconds).toBeCloseTo(0.3, PRECISION)
		runLater(rig)
		expect(#rig.played).toBe(2)
		expect(rig.played[1].row).toBe("Birds flapping")
		expect(rig.played[2].row).toBe("Z Z Z popping")
		expect(rig.played[2].at).toEqual(PLACE) -- the place given at the call, not lost in the wait
	end)

	it("plays the yawn at the mouth it is given", function()
		local rig = newRig()
		rig.handle.play("LieDown", PLACE)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe("Big yawn")
		expect(rig.played[1].at).toEqual(PLACE)
	end)

	it("plays nothing for a name that gives no cue", function()
		local rig = newRig()
		rig.handle.play("NoSuchPlace", PLACE)
		expect(#rig.played).toBe(0)
		expect(#rig.later).toBe(0)
	end)

	it("keeps Task 8's snort: its name still plays at the speed Cues gives it", function()
		local rig = newRig()
		rig.handle.play("Snort2", nil)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe("85% snort (two)")
		local options = rig.played[1].options :: SoundBoard.PlayOptions
		expect(options.speed).toBeCloseTo(0.9, PRECISION)
	end)
end)

describe("Moments.stop", function()
	it("stops the row the name gives, and nothing for a name with no cue", function()
		local rig = newRig()
		rig.handle.stop("Mumble")
		expect(rig.stopped).toEqual({ '"Mmm..." mumble' })
		rig.handle.stop("NoSuchPlace")
		expect(#rig.stopped).toBe(1)
	end)
end)

describe("Moments: the boings", function()
	it("plays one boing at a player's root when their Floating turns true", function()
		local rig = newRig()
		local player = rig.addPlayer(PLACE)
		rig.setFloating(player, true)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe(BOING)
		expect(rig.played[1].at).toEqual(PLACE)
	end)

	it("plays nothing when Floating turns false, or when the player has no root", function()
		local rig = newRig()
		local player = rig.addPlayer(PLACE)
		rig.setFloating(player, true)
		rig.setFloating(player, false)
		expect(#rig.played).toBe(1)
		local rootless = rig.addPlayer(nil)
		rig.setFloating(rootless, true)
		expect(#rig.played).toBe(1)
	end)

	it("hears a player who joins later", function()
		local rig = newRig()
		local late = rig.addPlayer(PLACE + Vector3.new(5, 0, 0))
		rig.setFloating(late, true)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].at).toEqual(PLACE + Vector3.new(5, 0, 0))
	end)

	it("hears players who were there before it started", function()
		local players = Instance.new("Folder")
		table.insert(made, players)
		local early = Instance.new("Folder")
		early.Parent = players
		local played: { Call } = {}
		local handle = Moments.start({
			board = {
				play = function(rowName: string, at: Vector3?, options: SoundBoard.PlayOptions?)
					table.insert(played, { row = rowName, at = at, options = options })
					return nil
				end,
				stop = function(_rowName: string) end,
			},
			after = function(_seconds: number, _callback: () -> ()) end,
			playerList = players,
			rootOf = function(_player: Instance): Vector3?
				return PLACE
			end,
			localPlayer = players,
		})
		table.insert(handles, handle)
		early:SetAttribute("Floating", true)
		task.wait()
		expect(#played).toBe(1)
	end)

	it("lets 8 players floating at once give 3 boings, the board's cap (Rule 86)", function()
		local real = newRealBoard()
		local rig = newRig(real.board)
		local list: { Instance } = {}
		for index = 1, 8 do
			table.insert(list, rig.addPlayer(PLACE + Vector3.new(index * 4, 0, 0)))
		end
		for _, player in list do
			player:SetAttribute("Floating", true)
		end
		task.wait()
		expect(#real.started).toBe(Config.Audio.MaxCopies)
		expect(Config.Audio.MaxCopies).toBe(3)
	end)

	it("stops listening to a player who has left the list", function()
		local rig = newRig()
		local player = rig.addPlayer(PLACE)
		task.wait() -- the list's ChildAdded reaches us a moment after the player is added
		player.Parent = nil
		task.wait() -- and so does ChildRemoved
		rig.setFloating(player, true)
		expect(#rig.played).toBe(0)
	end)

	it("stops listening after destroy", function()
		local rig = newRig()
		local player = rig.addPlayer(PLACE)
		rig.handle.destroy()
		rig.setFloating(player, true)
		expect(#rig.played).toBe(0)
	end)
end)

describe("Moments: Reduce Motion changes no sound (Rule 88)", function()
	-- The wake rumble goes through the wake shake's hook, which runs with Reduce Motion on and off.
	local function rumbleCalls(reduced: boolean): { Call }
		local rig = newRig()
		local state = Instance.new("Folder")
		state:SetAttribute("Phase", "Asleep")
		table.insert(made, state)
		local deps: CameraFx.ShakeDeps = {
			giantState = state,
			player = { Character = nil, CharacterAdded = Helpers.newSignal() } :: any,
			step = Helpers.newSignal(),
			now = function()
				return 0
			end,
			reducedMotion = function()
				return reduced
			end,
			playSound = rig.handle.play,
		}
		local shaker = CameraFx.shakeOnWake(deps)
		state:SetAttribute("Phase", "Awake")
		task.wait()
		shaker.stop()
		return rig.played
	end

	it("plays the same rumble, with the same fade, with Reduce Motion on as off", function()
		local off = rumbleCalls(false)
		local on = rumbleCalls(true)
		expect(#off).toBe(1)
		expect(off[1].row).toBe("Rumble")
		expect(on).toEqual(off)
	end)
end)

-- Plan 7 Task 10 (Rule 94, Every slam is heard): the slam, bonk and caught sounds.
local WHOOSH = 'Circle warning "whoosh"'
local THUD = "Fist thud"
local BONK = "Bonk"
local TWINKLE = "Bonk twinkle"
local CAUGHT = 'Caught "whoosh"'

describe("Moments: every slam is heard (Rule 94)", function()
	it("plays one whoosh at the point for a slam circle, at once", function()
		local rig = newRig()
		rig.handle.play("SlamCircle", PLACE)
		expect(#rig.played).toBe(1)
		expect(rig.played[1].row).toBe(WHOOSH)
		expect(rig.played[1].at).toEqual(PLACE)
		expect(#rig.later).toBe(0)
	end)

	it("plays one thud at the point for a slam landing, at the row's own speed 0.8", function()
		local real = newRealBoard()
		local rig = newRig(real.board)
		rig.handle.play("SlamThud", PLACE)
		expect(#real.started).toBe(1)
		expect(real.started[1].Name).toBe(`Copy {THUD}`)
		expect(real.started[1].PlaybackSpeed).toBeCloseTo(0.8, PRECISION)
		expect(#real.board.log).toBe(1)
		expect(real.board.log[1].row).toBe(THUD)
		expect(real.board.log[1].place).toEqual(PLACE)
	end)

	it("plays one bonk and one twinkle at the same place in the same frame", function()
		local rig = newRig()
		rig.handle.play("Bonk", PLACE)
		expect(#rig.played).toBe(2)
		expect(rig.played[1].row).toBe(BONK)
		expect(rig.played[2].row).toBe(TWINKLE)
		expect(rig.played[1].at).toEqual(PLACE)
		expect(rig.played[2].at).toEqual(PLACE)
		expect(#rig.later).toBe(0)
	end)

	it("plays the bonk and the twinkle through the real board, one copy each, at the place", function()
		local real = newRealBoard()
		local rig = newRig(real.board)
		rig.handle.play("Bonk", PLACE)
		expect(#real.started).toBe(2)
		expect(#real.board.log).toBe(2)
		expect(real.board.log[1].row).toBe(BONK)
		expect(real.board.log[2].row).toBe(TWINKLE)
		expect(real.board.log[1].place).toEqual(PLACE)
		expect(real.board.log[2].place).toEqual(PLACE)
		expect(real.board.log[1].time).toBe(real.board.log[2].time)
	end)

	it("plays one caught whoosh with no sound place", function()
		local real = newRealBoard()
		local rig = newRig(real.board)
		rig.handle.play("Caught", nil)
		expect(#real.started).toBe(1)
		expect(real.started[1].Name).toBe(`Copy {CAUGHT}`)
		expect(real.board.log[1].place).toBe(nil)
		expect(#real.worldParent:GetChildren()).toBe(0)
	end)

	it("wires every slam copy away from the music bus, and the caught copy to the effects bus", function()
		local real = newRealBoard()
		local rig = newRig(real.board)
		rig.handle.play("SlamCircle", PLACE)
		rig.handle.play("SlamThud", PLACE)
		rig.handle.play("Bonk", PLACE)
		rig.handle.play("Caught", nil)
		local effects = real.root:FindFirstChild("Effects")
		expect(effects).never.toBe(nil)
		expect(#real.started).toBe(5)
		for _, copy in real.started do
			for _, wire in copy:GetChildren() do
				if wire:IsA("Wire") then
					expect(wire.TargetInstance).never.toBe(real.board.music)
				end
			end
		end
		local caughtWire = real.started[5]:FindFirstChildWhichIsA("Wire")
		expect(caughtWire).never.toBe(nil)
		expect((caughtWire :: Wire).TargetInstance).toBe(effects)
	end)
end)

-- Plan 7 Task 11 (Rule 95): the grab sound when the local player picks an egg up, the egg-home sounds when one is banked.
-- Both are just for you: no sound place. A row's copy is made by the real board, so the recorder lists rows and places.
local PLUCK = "Grab pluck"
local SHIMMER = "Grab shimmer"
local TOOT = "Egg home toot"
local HAPPY = "Egg home, Rare: happy hit"
local FANFARE = "Egg home, Epic and Legendary: fanfare"
local CHEER = "Egg home, Legendary: children's cheer"

local function rows(rig: Rig): { string }
	local names: { string } = {}
	for _, call in rig.played do
		table.insert(names, call.row)
	end
	return names
end

local function pick(rig: Rig, rank: string?)
	rig.localPlayer:SetAttribute("Carrying", rank)
	task.wait() -- attribute changes reach listeners a moment after they are set
end

describe("Moments (the grab sound)", function()
	it("plays one pluck when the local player picks up a Common egg", function()
		local rig = newRig()
		pick(rig, "Common")
		expect(rows(rig)).toEqual({ PLUCK })
		expect(rig.played[1].at).toBe(nil)
	end)

	it("plays the pluck and the shimmer in the same frame for a Rare egg", function()
		local rig = newRig()
		pick(rig, "Rare")
		expect(rows(rig)).toEqual({ PLUCK, SHIMMER })
		expect(rig.played[1].at).toBe(nil)
		expect(rig.played[2].at).toBe(nil)
		expect(#rig.later).toBe(0)
	end)

	it("plays nothing when another player's Carrying changes", function()
		local rig = newRig()
		local other = rig.addPlayer(Vector3.new(1, 2, 3))
		other:SetAttribute("Carrying", "Rare")
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing for a Carrying that was already set at the start", function()
		local rig = newRig(nil, "Rare")
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing after destroy", function()
		local rig = newRig()
		rig.handle.destroy()
		pick(rig, "Common")
		expect(#rig.played).toBe(0)
	end)
end)

describe("Moments.hearEggHome (the egg-home sounds)", function()
	local EXPECTED: { [string]: { string } } = {
		Common = { TOOT },
		Uncommon = { TOOT },
		Rare = { TOOT, HAPPY },
		Epic = { TOOT, FANFARE },
		Legendary = { TOOT, FANFARE, CHEER },
	}

	for _, rank in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		it(`plays exactly the {rank} egg-home rows in one frame with no place`, function()
			local rig = newRig()
			rig.eggHome:Fire(rig.localPlayer, rank, Vector3.new(0, 0, 0))
			task.wait()
			expect(rows(rig)).toEqual(EXPECTED[rank])
			for _, call in rig.played do
				expect(call.at).toBe(nil)
			end
			expect(#rig.later).toBe(0)
		end)
	end

	it("plays nothing for another player's egg home", function()
		local rig = newRig()
		local other = rig.addPlayer(Vector3.new(1, 2, 3))
		rig.eggHome:Fire(other, "Legendary", Vector3.new(0, 0, 0))
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing after destroy", function()
		local rig = newRig()
		rig.handle.destroy()
		rig.eggHome:Fire(rig.localPlayer, "Legendary", Vector3.new(0, 0, 0))
		task.wait()
		expect(#rig.played).toBe(0)
	end)
end)

-- Plan 7 Task 12 (Rules 94 and 95): the sparkle pop when an egg refills, the egg's "pop" when a lost egg goes back or is gone.
-- Both play at the position the server sends (Nearby rows).
describe("Moments.hearEggPop (the egg pops)", function()
	local SPARKLE = "Sparkle pop"
	local EGG_POP = 'Egg "pop"'

	it("plays one Sparkle pop at the position for a Refill", function()
		local rig = newRig()
		rig.eggPop:Fire(PLACE, "Refill")
		task.wait()
		expect(rows(rig)).toEqual({ SPARKLE })
		expect(rig.played[1].at).toEqual(PLACE)
	end)

	for _, kind in { "Back", "Gone" } do
		it(`plays one Egg "pop" at the position for {kind}`, function()
			local rig = newRig()
			rig.eggPop:Fire(PLACE, kind)
			task.wait()
			expect(rows(rig)).toEqual({ EGG_POP })
			expect(rig.played[1].at).toEqual(PLACE)
		end)
	end

	it("plays nothing for a kind that is not Refill, Back or Gone", function()
		local rig = newRig()
		rig.eggPop:Fire(PLACE, "Boom")
		rig.eggPop:Fire(PLACE, 5)
		rig.eggPop:Fire(PLACE, nil)
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing when the position is not a Vector3", function()
		local rig = newRig()
		rig.eggPop:Fire("far away", "Refill")
		rig.eggPop:Fire(nil, "Back")
		rig.eggPop:Fire(5, "Gone")
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing after destroy", function()
		local rig = newRig()
		rig.handle.destroy()
		rig.eggPop:Fire(PLACE, "Refill")
		task.wait()
		expect(#rig.played).toBe(0)
	end)
end)

-- Plan 7 Task 13 (Rules 96 and 84): your own thuds are heard. The flump plays at the position the server sends, and the
-- board gets the thud size (options.thud) to pick its loudness.
describe("Moments.hearThud (the flump)", function()
	local FLUMP = 'Thud "flump"'

	for _, noise in { 20, 30, 40, 60 } do
		it(`plays one flump at the position with options.thud {noise}`, function()
			local rig = newRig()
			rig.thud:Fire(PLACE, noise)
			task.wait()
			expect(rows(rig)).toEqual({ FLUMP })
			expect(rig.played[1].at).toEqual(PLACE)
			expect((rig.played[1].options :: any).thud).toBe(noise)
		end)
	end

	it("plays nothing when the position is not a Vector3", function()
		local rig = newRig()
		rig.thud:Fire("far away", 20)
		rig.thud:Fire(nil, 30)
		rig.thud:Fire(5, 40)
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing when the noise is not a finite number above 0", function()
		local rig = newRig()
		rig.thud:Fire(PLACE, "big")
		rig.thud:Fire(PLACE, 0)
		rig.thud:Fire(PLACE, -5)
		rig.thud:Fire(PLACE, 0 / 0)
		rig.thud:Fire(PLACE, math.huge)
		rig.thud:Fire(PLACE, nil)
		task.wait()
		expect(#rig.played).toBe(0)
	end)

	it("plays nothing after destroy", function()
		local rig = newRig()
		rig.handle.destroy()
		rig.thud:Fire(PLACE, 20)
		task.wait()
		expect(#rig.played).toBe(0)
	end)
end)
