--!strict
-- Plan 6 Task 22: whole-session test of the wake-up hunt (spec 6, Rules 60, 62 and 63, section 10; .claude/rules/tdd.md,
-- "Whole-session tests"). Wake-up 1: a new solo player banks a Common, he is woken on purpose, and the player stands
-- still in the meadow outside every garden. Wake-up 2: the player carries an Uncommon, is caught, gets no circle at the
-- door, then runs home dodging; a second player joins during it and is never targeted. Wake-up 3: the carrier is hunted
-- first, then the other player. Real: Banking, PlayerInfo, GiantDirector, GiantCycle, Slams, ShowSlam, Bonker, Catcher
-- and Analytics. Stand-ins: the tracker (the test says where each player stands), the grab, the Players service, the
-- AnalyticsService (Analytics/Helpers), a small fake meadow of show spots and the Bonker's timer (HuntRig). Wired like
-- `init.server.luau`: each tick banks first, then Analytics and the director read the players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Banking = require(ServerScriptService.Server.Eggs.Banking)
local Slams = require(ServerScriptService.Server.Giant.Slams)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Helpers = require(script.Parent.Parent.Analytics.Helpers)
local HuntRig = require(script.Parent.HuntRig)

type Sample = PlayerTracker.Sample
type Slam = { target: number?, kind: string, caught: { number }, bonked: { number } }

local USER_ID = 7
local PLOT = 1
local SECOND_ID = 8
local SECOND_PLOT = 2
local START_CLOCK = 1000
local TICK = Config.Tick.Seconds
local COMMON: Config.RarityName = "Common"
local UNCOMMON: Config.RarityName = "Uncommon"
local SLAM_COUNT = #Config.Wake.SlamWarningTimes
local HEAVY_SLEEP_ENDS = Config.Wake.AwakeSeconds + Config.Wake.HeavySleepSeconds
local SLAM_TIMES = Config.Wake.SlamWarningTimes
local LANDS_AFTER = Config.Wake.SlamWarningSeconds
local CIRCLE_RADIUS = Config.Wake.SlamCircleDiameter / 2
-- Where the first player stands in the meadow, outside every garden, and the one garden (its box, gate and spawn spot).
local PLAYER_AT = Vector3.new(80, 3, 40)
local GARDEN_BOX = CFrame.new(130, 3, 40)
local GARDEN_SIZE = Vector3.new(40, 20, 40)
local GATE = Vector3.new(110, 3, 40)
local HOME = Vector3.new(130, 3, 40)
-- The door (where a catch puts the carrier, outside the fence) and the second player's meadow spot: 30 studs from the
-- door and 20 from the first player's meadow spot, so a circle on one never covers the other.
local DOOR = Vector3.new(90, 3, 40)
local SECOND_AT = Vector3.new(60, 3, 40)
-- A runner who dodges a circle on the door steps out of it toward the gate (circle radius plus the garden margin), then
-- goes home.
local DODGE_AT = DOOR + Vector3.new(CIRCLE_RADIUS + Config.Wake.SlamGardenMarginStuds, 0, 0)
-- The fake meadow: a ring of show spots around the player, at the middle of the show distance band. Some fall inside
-- the garden or too near its fence, so ShowSlam has to leave them out.
local SPOT_COUNT = 8
local SPOT_RING_STUDS = (Config.Wake.ShowSlamNearStuds + Config.Wake.ShowSlamFarStuds) / 2

local cleanups: { () -> () } = {}

afterEach(function()
	for _, cleanup in cleanups do
		cleanup()
	end
	table.clear(cleanups)
	Helpers.cleanUp()
end)

local function spotRing(): { Vector3 }
	local spots = {}
	for index = 0, SPOT_COUNT - 1 do
		local angle = index * 2 * math.pi / SPOT_COUNT
		table.insert(
			spots,
			Vector3.new(
				PLAYER_AT.X + SPOT_RING_STUDS * math.cos(angle),
				2,
				PLAYER_AT.Z + SPOT_RING_STUDS * math.sin(angle)
			)
		)
	end
	return spots
end

type Session = {
	player: Helpers.FakePlayer,
	harness: Helpers.Harness,
	rig: HuntRig.Rig,
	samples: { Sample },
	clock: number,
	slams: { Slam },
	centres: { [number]: Vector3 },
	players: { Helpers.FakePlayer }, -- everyone in the server now
	joined: { [number]: number }, -- when each player joined, in the test clock
	appeared: { [number]: number }, -- when a catch last put each player at the door, in the test clock
	addPlayer: (userId: number, plot: number) -> Helpers.FakePlayer,
}

-- A fake player the way Banking, PlayerInfo and the Bonker need one: they write attributes (Helpers' player only reads
-- them), Banking watches CharacterRemoving and reads the character's Humanoid.
local function makeBody(userId: number, plot: number): (Helpers.FakePlayer, Model)
	local player = Helpers.makePlayer(userId, plot)
	local loose = player :: any
	loose.SetAttribute = function(self: any, name: string, value: any)
		self.attributes[name] = value
	end
	loose.CharacterRemoving = Signal.new()
	local body = Instance.new("Model")
	Instance.new("Humanoid").Parent = body
	loose.Character = body
	return player, body
end

local function newSession(): Session
	local harness = Helpers.newHarness()
	local player, firstBody = makeBody(USER_ID, PLOT)
	Helpers.enter(harness, player)
	player.Character = firstBody -- Helpers.enter gives a plain table; Banking reads the Humanoid
	local session: Session = {
		player = player,
		harness = harness,
		rig = nil :: any,
		samples = {},
		clock = START_CLOCK,
		slams = {},
		centres = {},
		players = { player },
		joined = { [USER_ID] = START_CLOCK },
		appeared = {},
		addPlayer = nil :: any,
	}
	local function find(userId: number): any
		for _, who in session.players do
			if who.UserId == userId then
				return who
			end
		end
		return nil
	end
	local service = {
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
		GetPlayers = function(_self: any): { any }
			return table.clone(session.players)
		end,
		GetPlayerByUserId = function(_self: any, userId: number): any
			return find(userId)
		end,
	}
	local grab = {
		bank = function(_self: any, who: any): (string?, Config.RarityName?)
			local rarity = who:GetAttribute("Carrying")
			if rarity == nil then
				return nil, nil
			end
			who:SetAttribute("Carrying", nil)
			return "Spot_1", rarity
		end,
		-- A catch puts the egg back on its spot: the carrier's hands are empty again.
		returnEgg = function(_self: any, who: any): (("back" | "gone")?, string?)
			if who:GetAttribute("Carrying") == nil then
				return nil, nil
			end
			who:SetAttribute("Carrying", nil)
			return "back", "Spot_1"
		end,
		noteFist = function() end,
	}
	local banking = Banking.start({ grab = grab, players = service :: any })
	banking.banked:Connect(function(who: any, rarity: Config.RarityName)
		harness.banked:Fire(who, rarity)
	end)
	session.rig = HuntRig.start({
		list = function()
			return table.clone(session.players)
		end,
		service = service,
		tick = function()
			banking:check(session.samples)
			harness.analytics:check(session.samples)
			return session.samples
		end,
		now = function()
			return session.clock
		end,
		grab = grab,
		plot = PLOT,
		home = HOME,
		gardens = { { index = PLOT, cframe = GARDEN_BOX, size = GARDEN_SIZE } },
		showSpots = spotRing(),
		-- The second player's own garden is not built here: his gate is the same one.
		gates = { [USER_ID] = GATE, [SECOND_ID] = GATE },
		joinedAt = function(userId: number)
			return session.joined[userId]
		end,
		appearedAt = function(userId: number)
			return session.appeared[userId]
		end,
		onWarning = function(slam: number, centre: Vector3)
			session.centres[slam] = centre
		end,
	})
	local director = session.rig.director
	director.woke:Connect(function(...)
		harness.woke:Fire(...)
	end)
	director.slammed:Connect(function(target: number?, kind: string, caught: { number }, bonked: { number })
		table.insert(session.slams, { target = target, kind = kind, caught = caught, bonked = bonked })
		for _, userId in caught do
			session.appeared[userId] = session.clock -- init.server.luau: a catch puts them at the door
		end
		harness.slammed:Fire(target, kind, caught, bonked)
	end)
	session.rig.catcher.caught:Connect(function(who: any, rarity: Config.RarityName)
		harness.caught:Fire(who, rarity)
	end)
	session.rig.bonker.bonked:Connect(function(who: any)
		harness.bonked:Fire(who)
	end)
	local bodies = { firstBody }
	-- A new player joins the server now (their join time is the test clock), standing in a character with a Humanoid.
	session.addPlayer = function(userId: number, plot: number): Helpers.FakePlayer
		local joiner, body = makeBody(userId, plot)
		table.insert(bodies, body)
		table.insert(session.players, joiner)
		session.joined[userId] = session.clock
		Helpers.join(harness, joiner)
		service.PlayerAdded:Fire(joiner)
		return joiner
	end
	table.insert(cleanups, function()
		session.rig.stop()
		banking:stop()
		for _, body in bodies do
			body:Destroy()
		end
	end)
	return session
end

local function sampleAt(userId: number, garden: number?, position: Vector3): Sample
	return {
		userId = userId,
		position = position,
		moving = false,
		groundSpeed = 0,
		zone = "Meadow",
		garden = garden,
		thudFrom = nil,
		falling = false,
		moveGrace = false,
		onStitchedEdge = false,
	}
end

-- One tick of the clock with the players standing as `session.samples` says.
local function tick(session: Session)
	session.clock += TICK
	session.harness.clock = session.clock
	session.rig.director:step()
	session.rig.runDue()
end

local function phaseOf(session: Session): any
	return session.rig.state:GetAttribute("Phase")
end

-- He is woken on purpose: the meter goes to the wake line, and the next tick he wakes. Returns when (the test clock).
local function wakeUp(session: Session): number
	session.rig.state:SetAttribute("Meter", Config.Meter.Max)
	tick(session)
	expect(phaseOf(session)).toBe("Awake")
	return session.clock
end

-- Ticks until he is Asleep again. Before each tick `behave(seconds since he woke)` says where everyone stands.
local function playOut(session: Session, wokeAt: number, behave: (elapsed: number) -> ())
	local left = math.ceil(HEAVY_SLEEP_ENDS / TICK) + 20
	while phaseOf(session) ~= "Asleep" do
		behave(session.clock - wokeAt)
		tick(session)
		left -= 1
		expect(left).toBeGreaterThan(0) -- Heavy Sleep must end on the clock
	end
end

-- "target|kind|caught|bonked" of one slam, so a failure shows both lines.
local function line(target: number?, kind: string, caught: { number }, bonked: { number }): string
	return `{tostring(target)}|{kind}|caught {table.concat(caught, ",")}|bonked {table.concat(bonked, ",")}`
end

local function lineOf(slam: Slam): string
	return line(slam.target, slam.kind, slam.caught, slam.bonked)
end

-- The six slams since `from` landed once each and match `expected` (target kind and result).
local function expectSlams(session: Session, from: number, expected: { string })
	expect(#session.slams - from).toBe(SLAM_COUNT)
	local got = {}
	for number = 1, SLAM_COUNT do
		table.insert(got, lineOf(session.slams[from + number]))
	end
	expect(table.concat(got, " ; ")).toBe(table.concat(expected, " ; "))
end

-- Where the first player stands while he is hunted in wake-ups 2 and 3: in the meadow until a catch, then at the door
-- (no circle at them for DoorSeconds), then stepping out of the circle they are aimed at, then home in the garden.
local function carrierSample(session: Session, wokeAt: number, elapsed: number): Sample
	local caughtAt = session.appeared[USER_ID]
	if caughtAt == nil or caughtAt < wokeAt then
		return sampleAt(USER_ID, nil, PLAYER_AT)
	end
	-- Slam 3 is aimed at the door once the door seconds are over; the runner steps out after its warning is up, and is
	-- home once it has landed.
	if elapsed >= SLAM_TIMES[3] + LANDS_AFTER + TICK then
		return sampleAt(USER_ID, PLOT, HOME)
	elseif elapsed >= SLAM_TIMES[3] + 2 * TICK then
		return sampleAt(USER_ID, nil, DODGE_AT)
	end
	return sampleAt(USER_ID, nil, DOOR)
end

local function checkBand(session: Session, slam: number, near: Vector3)
	local distance = Slams.flatDistance(session.centres[slam], near)
	expect(distance).toBeGreaterThanOrEqual(Config.Wake.ShowSlamNearStuds)
	expect(distance).toBeLessThanOrEqual(Config.Wake.ShowSlamFarStuds)
end

-- The meadow's empty-meadow slams (nobody to aim at, no show: every player is home or a late joiner).
local EMPTY = line(nil, "None", {}, {})

describe("wake-up session", function()
	it(
		"wake-ups 1 to 3: a still solo player is bonked; a carrier is caught, left alone at the door and runs home; a late joiner is spared, then hunted",
		function()
			local session = newSession()
			local harness, player, rig = session.harness, session.player, session.rig

			-- The player joins, banks a Common in their garden, and is not asked for anything else.
			Helpers.grab(harness, player, COMMON)
			session.samples = { sampleAt(USER_ID, PLOT, HOME) }
			tick(session)
			expect(player.attributes.EggsHome).toBe(1)
			expect(player.attributes.Carrying).toBeNil()
			expect(phaseOf(session)).toBe("Asleep")
			table.clear(harness.calls)

			-- WAKE-UP 1: he is woken on purpose. The player stands still in the meadow, outside every garden.
			session.samples = { sampleAt(USER_ID, nil, PLAYER_AT) }
			local wokeAt = wakeUp(session)
			expect(#rig.bounced).toBe(0) -- a player in the meadow is never bounced

			-- Plays the wake-up through Awake and Heavy Sleep, to the tick before Heavy Sleep ends.
			local lastHeavyTick = math.floor((HEAVY_SLEEP_ENDS - TICK) / TICK)
			for _ = 1, lastHeavyTick do
				tick(session)
			end
			expect(phaseOf(session)).toBe("HeavySleep")
			-- (e) Heavy Sleep ends on the clock: within a tick of it, he is Asleep at 0.
			for _ = 1, 3 do
				tick(session)
			end
			expect(session.clock - wokeAt).toBeGreaterThanOrEqual(HEAVY_SLEEP_ENDS)
			expect(phaseOf(session)).toBe("Asleep")
			expect(rig.state:GetAttribute("Meter")).toBe(0)

			-- All six slams landed, once each.
			expect(#session.slams).toBe(SLAM_COUNT)
			local withTarget = 0
			for number, slam in session.slams do
				if slam.target ~= nil then
					withTarget += 1
				end
				expect(#slam.caught).toBe(0) -- carrying nothing, nobody was caught
				if number % 2 == 1 then
					-- (a) Slams 1, 3 and 5 aim at the player, kind "No egg", and bonk them.
					expect(slam.target).toBe(USER_ID)
					expect(slam.kind).toBe("No egg")
					expect(slam.bonked).toEqual({ USER_ID })
				else
					-- (b) Slams 2, 4 and 6 are show slams: nobody aimed at, nobody bonked, the centre inside the band.
					expect(slam.target).toBeNil()
					expect(slam.kind).toBe("None")
					expect(#slam.bonked).toBe(0)
					checkBand(session, number, PLAYER_AT)
				end
			end
			-- (c) At least half of the six slams have a target.
			expect(withTarget * 2).toBeGreaterThanOrEqual(SLAM_COUNT)
			-- Never pushed: no bounce, no catch, and the bonk mark is gone again.
			expect(#rig.bounced).toBe(0)
			expect(player.attributes.Bonked).toBeNil()

			-- (d) Analytics logged one "Slam" per slam and one "Bonked" per bonk.
			expect(#Helpers.eventsNamed(harness, "Slam", player)).toBe(SLAM_COUNT)
			expect(#Helpers.eventsNamed(harness, "Bonked", player)).toBe(SLAM_COUNT / 2)

			-- WAKE-UP 2: the player carries an Uncommon into the meadow and he is woken again.
			local from2 = #session.slams
			Helpers.grab(harness, player, UNCOMMON)
			session.samples = { sampleAt(USER_ID, nil, PLAYER_AT) }
			wokeAt = wakeUp(session)
			local joinAt = SLAM_TIMES[2] + LANDS_AFTER + 2 * TICK -- after slam 2 has landed, before slam 3's warning
			local second: Helpers.FakePlayer? = nil
			playOut(session, wokeAt, function(elapsed: number)
				if second == nil and elapsed >= joinAt then
					second = session.addPlayer(SECOND_ID, SECOND_PLOT)
				end
				session.samples = { carrierSample(session, wokeAt, elapsed) }
				if second ~= nil then
					table.insert(session.samples, sampleAt(SECOND_ID, nil, SECOND_AT))
				end
			end)
			expect(second).never.toBeNil()
			expect(session.joined[SECOND_ID]).toBeGreaterThan(wokeAt) -- he joined during this wake-up
			-- The catch put the egg back: the carrier's hands are empty and their banked egg stays banked.
			expect(player.attributes.Carrying).toBeNil()
			expect(player.attributes.EggsHome).toBe(1)
			-- The door window: slam 2's warning falls inside it, slam 3's after it.
			local appeared = session.appeared[USER_ID] - wokeAt
			expect(appeared + Config.Wake.DoorSeconds).toBeGreaterThan(SLAM_TIMES[2] + TICK)
			expect(appeared + Config.Wake.DoorSeconds).toBeLessThanOrEqual(SLAM_TIMES[3])
			-- Slam 1 catches the carrier. Slam 2 (no circle at the door) is a show slam. Slam 3 aims at the runner, not at
			-- the late joiner (who stands nearer to him), and misses: they have stepped out. Then he is home, the joiner
			-- is never aimed at, and the last three slams land on empty meadow.
			expectSlams(session, from2, {
				line(USER_ID, "Carrier", { USER_ID }, {}),
				line(nil, "None", {}, {}),
				line(USER_ID, "No egg", {}, {}),
				EMPTY,
				EMPTY,
				EMPTY,
			})
			checkBand(session, 2, DOOR)
			for number = 1, SLAM_COUNT do
				local slam = session.slams[from2 + number]
				expect(slam.target).never.toBe(SECOND_ID)
				expect(table.find(slam.bonked, SECOND_ID)).toBeNil()
			end
			expect(#rig.bounced).toBe(0)

			-- WAKE-UP 3: the carrier picks an egg up again and both players stand in the meadow.
			local from3 = #session.slams
			Helpers.grab(harness, player, UNCOMMON)
			session.samples = { sampleAt(USER_ID, nil, PLAYER_AT), sampleAt(SECOND_ID, nil, SECOND_AT) }
			wokeAt = wakeUp(session)
			playOut(session, wokeAt, function(elapsed: number)
				session.samples = { carrierSample(session, wokeAt, elapsed), sampleAt(SECOND_ID, nil, SECOND_AT) }
			end)
			-- The carrier is hunted first and caught. Slam 2 goes to the other player, who is now a target (the carrier is
			-- at the door), slam 3 to the carrier again once the door seconds are over (they step out and it misses), slam
			-- 4 to the other player, slam 5 is a show slam near him (the slam before bonked him), slam 6 aims at him again.
			expectSlams(session, from3, {
				line(USER_ID, "Carrier", { USER_ID }, {}),
				line(SECOND_ID, "No egg", {}, { SECOND_ID }),
				line(USER_ID, "No egg", {}, {}),
				line(SECOND_ID, "No egg", {}, { SECOND_ID }),
				line(nil, "None", {}, {}),
				line(SECOND_ID, "No egg", {}, { SECOND_ID }),
			})
			checkBand(session, 5, SECOND_AT)
			expect(rig.state:GetAttribute("Meter")).toBe(0)
			expect(#rig.bounced).toBe(0)
		end
	)
end)
