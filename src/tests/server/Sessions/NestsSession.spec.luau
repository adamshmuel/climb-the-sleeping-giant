--!strict
-- A whole session with egg nests for one brand-new player (plan 5, Task 21; .claude/rules/tdd.md, "Whole-session
-- tests"). The real Config, EggSlots (inside Grab), Grab, Banking and GrabRig's fakes run together; test B adds the
-- real GiantDirector, Catcher, Noise and SleepMeter. Stand-ins: the tracker (the test says where the player stands
-- and in which zone every tick), the hold prompts, the clock and a random that always picks the first allowed nest.
-- Fake nests sit in a row along x (see NESTS).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterAll = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterAll

local Config = require(ReplicatedStorage.Shared.Config)
local Banking = require(ServerScriptService.Server.Eggs.Banking)
local Catcher = require(ServerScriptService.Server.Giant.Catcher)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local Grab = require(ServerScriptService.Server.Eggs.Grab)
local Noise = require(ServerScriptService.Server.Giant.Noise)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local SleepMeter = require(ServerScriptService.Server.Giant.SleepMeter)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local GiantRig = require(script.Parent.GiantRig)
local GrabRig = require(script.Parent.Parent.Eggs.GrabRig)

type Rank = Config.RarityName
type Sample = PlayerTracker.Sample

local USER_ID = 7
local PLOT = 1
local HOME = Vector3.new(0, 3, 500) -- the player's root inside garden 1 (far from every nest)
local TICKS_PER_SECOND = 10

-- Name, rank, x along the row, garden (meadow nests only), right cuff (Epic only). Rare nests are 60 studs apart, more
-- than the 40 the card wants, so Config.Nests.PlayerDistance (15) can be seen. Epic: left cuff and right cuff.
local NESTS: { { name: string, rank: Rank, x: number, garden: number?, cuff: boolean? } } = {
	{ name = "Common_1a", rank = "Common", x = 0, garden = PLOT },
	{ name = "Common_1b", rank = "Common", x = 20, garden = PLOT },
	{ name = "Uncommon_1a", rank = "Uncommon", x = 100, garden = PLOT },
	{ name = "Uncommon_1b", rank = "Uncommon", x = 120, garden = PLOT },
	{ name = "Rare_1", rank = "Rare", x = 200 },
	{ name = "Rare_2", rank = "Rare", x = 260 },
	{ name = "Rare_3", rank = "Rare", x = 320 },
	{ name = "Epic_LeftCuff", rank = "Epic", x = 400 },
	{ name = "Epic_RightCuff", rank = "Epic", x = 440, cuff = true },
}
-- How many eggs of each rank wait at once: one per garden for the meadow ranks, 1 Rare, 2 Epic.
local SLOTS: { [Rank]: number } = { Common = 1, Uncommon = 1, Rare = 1, Epic = 2 }

type RefillLine = { rank: Rank, waited: number, tick: number, nest: string? }

type Session = {
	player: any,
	players: any, -- the fake Players service
	grab: Grab.Grab,
	banking: Banking.Banking,
	spots: { WorldIndex.EggSpot },
	spotByName: { [string]: WorldIndex.EggSpot },
	prompts: { [string]: any },
	ticks: number, -- 0.1 s steps since the session began
	garden: number?, -- the garden the tracker reports for the player (nil in the meadow)
	banked: { Rank }, -- every rank Banking banked, in order
	refillLog: { RefillLine }, -- one line per `Grab.refilled`: the "EggRefill" the analytics hook would log
	eggsAtLastTick: { [string]: boolean }, -- which nests showed an egg at the end of the last tick
	lastNest: { [string]: string }, -- the nest each rank's last egg was taken from
	carriedFrom: string?, -- the nest of the egg the player carries now
	zone: Config.ZoneName, -- the zone the tracker reports for the player
	moving: boolean, -- does the tracker say the player walks?
	-- Test B only (startGiant): the giant's state folder, the director and catcher, what the catcher took, the tick of
	-- the last fist, and the nests a catch put an egg back on this tick (a returned egg is not a refill).
	state: Folder?,
	director: GiantDirector.Director?,
	catcher: Catcher.Catcher?,
	caught: { Rank },
	fistTick: number?,
	returnedNow: { [string]: boolean },
}

local cleanups: { () -> () } = {}

afterAll(function()
	for _, cleanup in cleanups do
		cleanup()
	end
	table.clear(cleanups)
	GrabRig.cleanUp()
end)

local function clockOf(s: Session): number
	return GrabRig.START_TIME + s.ticks / TICKS_PER_SECOND
end

local function fail(s: Session, text: string)
	error(`tick {s.ticks} ({clockOf(s) - GrabRig.START_TIME} s): {text}`, 0)
end

local function rootOf(s: Session): BasePart
	return (s.player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
end

local function hasEgg(spot: WorldIndex.EggSpot): boolean
	return spot.model:FindFirstChild("Egg") ~= nil
end

-- The nests that show an egg, joined with commas, in the order of NESTS.
local function eggsOut(s: Session): string
	local names: { string } = {}
	for _, spot in s.spots do
		if hasEgg(spot) then
			table.insert(names, spot.name)
		end
	end
	return table.concat(names, ",")
end

-- The nests whose prompt is on (a hold would work), joined with commas.
local function promptsOn(s: Session): string
	local names: { string } = {}
	for _, spot in s.spots do
		if s.prompts[spot.name].Enabled == true then
			table.insert(names, spot.name)
		end
	end
	return table.concat(names, ",")
end

-- The refill lines that are of `rank`.
local function refillLog(s: Session, rank: Rank): { RefillLine }
	local lines: { RefillLine } = {}
	for _, line in s.refillLog do
		if line.rank == rank then
			table.insert(lines, line)
		end
	end
	return lines
end

-- The checks that run on every tick. They need no setup per test; a failure names the rule it broke.
local function checkSession(s: Session, before: { [string]: boolean }, logBefore: number)
	-- No rank has more eggs on nests than it has slots.
	local counts: { [string]: number } = {}
	for _, spot in s.spots do
		if hasEgg(spot) then
			counts[spot.rarity] = (counts[spot.rarity] or 0) + 1
		end
	end
	for rank, count in counts do
		if count > (SLOTS[rank :: Rank] or 0) then
			fail(s, `{rank} has {count} eggs out but only {SLOTS[rank :: Rank]} slots ({eggsOut(s)})`)
		end
	end
	-- No empty nest's prompt is on (Rule 77).
	for _, spot in s.spots do
		if s.prompts[spot.name].Enabled == true and not hasEgg(spot) then
			fail(s, `{spot.name} has no egg but its prompt is on`)
		end
	end
	-- Every egg that appeared this tick is one refill, and has one refill line (the "EggRefill").
	local appeared: { WorldIndex.EggSpot } = {}
	for _, spot in s.spots do
		if hasEgg(spot) and not before[spot.name] then
			table.insert(appeared, spot)
		end
	end
	local lines = #s.refillLog - logBefore
	if lines ~= #appeared then
		fail(s, `{#appeared} eggs appeared but {lines} EggRefill lines were logged ({eggsOut(s)})`)
	end
	for index, spot in appeared do
		local line = s.refillLog[logBefore + index]
		if line.rank ~= spot.rarity then
			fail(s, `EggRefill said {line.rank} but the egg appeared on {spot.name} ({spot.rarity})`)
		end
		line.nest = spot.name
		-- A rank off the meadow never refills on the nest it was taken from, nor within the player distance of a
		-- player (Rules 74 and 76).
		if spot.garden == nil then
			if spot.name == s.lastNest[spot.rarity] then
				fail(s, `{spot.rarity} refilled on the nest it was taken from: {spot.name}`)
			end
			local away = (spot.cframe.Position - rootOf(s).Position).Magnitude
			if away < Config.Nests.PlayerDistance then
				fail(
					s,
					`{spot.name} refilled {away} studs from a player, inside the {Config.Nests.PlayerDistance}-stud rule`
				)
			end
		end
	end
	for _, spot in s.spots do
		s.eggsAtLastTick[spot.name] = hasEgg(spot)
	end
end

local function sampleOf(s: Session): Sample
	return {
		userId = USER_ID,
		position = rootOf(s).Position,
		moving = s.moving,
		groundSpeed = if s.moving then Config.Movement.WalkSpeed else 0,
		zone = s.zone,
		garden = s.garden,
		thudFrom = nil,
		falling = false,
		moveGrace = false,
		onStitchedEdge = false,
	}
end

-- One 0.1 s step: the clock moves, the giant (test B) reads the player, Grab checks its locks and refills, Banking
-- reads where the player stands, the checks run.
local function tick(s: Session)
	local before = table.clone(s.eggsAtLastTick)
	local logBefore = #s.refillLog
	s.ticks += 1
	if s.director ~= nil then
		s.director:step()
	end
	s.grab:step()
	s.banking:check({ sampleOf(s) })
	for name in s.returnedNow do
		before[name] = true
	end
	table.clear(s.returnedNow)
	checkSession(s, before, logBefore)
end

local function advance(s: Session, seconds: number)
	for _ = 1, math.round(seconds * TICKS_PER_SECOND) do
		tick(s)
	end
end

local function newSession(): Session
	local spots: { WorldIndex.EggSpot } = {}
	local spotByName: { [string]: WorldIndex.EggSpot } = {}
	for _, nest in NESTS do
		local spot = GrabRig.newSpot(nest.name, nest.rank, nest.x)
		spot.garden = nest.garden
		spot.ridesRightArm = nest.cuff
		table.insert(spots, spot)
		spotByName[nest.name] = spot
	end
	local player: any = GrabRig.newPlayer(USER_ID, HOME)
	player.DisplayName = "Mia"
	player.CharacterAdded = GrabRig.newSignal()
	player.CharacterRemoving = GrabRig.newSignal()
	player:SetAttribute("PlotIndex", PLOT)
	local players = {
		PlayerAdded = GrabRig.newSignal(),
		PlayerRemoving = GrabRig.newSignal(),
		GetPlayers = function(_self: any): { any }
			return { player }
		end,
		GetPlayerByUserId = function(_self: any, userId: number): any
			return if userId == USER_ID then player else nil
		end,
	}
	local prompts: { [string]: any } = {}
	local s: Session
	-- A random that always picks the first allowed nest, so a refill lands where the rules put the first choice.
	local firstChoice = {
		NextInteger = function(_self: any, low: number, _high: number): number
			return low
		end,
	}
	local deps: Grab.Deps = {
		spots = spots,
		slotsPerRank = SLOTS,
		templates = {
			Common = GrabRig.newTemplate("Common"),
			Uncommon = GrabRig.newTemplate("Uncommon"),
			Rare = GrabRig.newTemplate("Rare"),
			Epic = GrabRig.newTemplate("Epic"),
		},
		carriedOffset = CFrame.new(0, 0.8, 1.9),
		carriedHeight = 4.2,
		players = players :: any,
		heartbeat = GrabRig.newSignal(),
		grabMissed = function() end,
		now = function()
			return clockOf(s)
		end,
		phase = function(): Config.Phase
			local state = s.state
			return if state ~= nil then state:GetAttribute("Phase") :: Config.Phase else "Asleep"
		end,
		random = firstChoice :: any,
		createPrompt = function(anchor: Attachment, _rank: Rank): any
			local prompt = { Triggered = GrabRig.newSignal(), Enabled = true, Destroy = function() end }
			prompts[((anchor.Parent :: Instance).Parent :: Instance).Name] = prompt
			return prompt
		end,
	}
	local grab = Grab.start(deps)
	local banking = Banking.start({ grab = grab, players = players :: any })
	s = {
		player = player,
		players = players,
		grab = grab,
		banking = banking,
		spots = spots,
		spotByName = spotByName,
		prompts = prompts,
		ticks = 0,
		garden = PLOT,
		banked = {},
		refillLog = {},
		eggsAtLastTick = {},
		lastNest = {},
		carriedFrom = nil,
		zone = "Meadow",
		moving = false,
		state = nil,
		director = nil,
		catcher = nil,
		caught = {},
		fistTick = nil,
		returnedNow = {},
	}
	grab.returned:Connect(function(_who: any, rank: Rank, _why: string)
		for _, spot in spots do
			if spot.rarity == rank and hasEgg(spot) and not s.eggsAtLastTick[spot.name] then
				s.returnedNow[spot.name] = true
			end
		end
	end)
	banking.banked:Connect(function(_who: any, rank: Rank)
		table.insert(s.banked, rank)
	end)
	grab.refilled:Connect(function(rank: Rank, waited: number)
		table.insert(s.refillLog, { rank = rank, waited = waited, tick = s.ticks, nest = nil })
	end)
	for _, spot in spots do
		s.eggsAtLastTick[spot.name] = hasEgg(spot)
	end
	table.insert(cleanups, function()
		banking:stop()
		grab:stop()
	end)
	return s
end

-- The player walks to a nest (3 studs from its prompt, in the meadow), holds, and the grab goes through. Checks that
-- the egg on their back is the nest's rank.
local function grabAt(s: Session, nestName: string)
	local spot = s.spotByName[nestName]
	rootOf(s).Position = spot.promptAnchor.WorldPosition + Vector3.new(3, 0, 0)
	s.garden = nil
	tick(s)
	expect(hasEgg(spot)).toBe(true)
	s.prompts[nestName].Triggered:Fire(s.player)
	if s.player:GetAttribute("Carrying") ~= spot.rarity then
		fail(s, `grab at {nestName}: Carrying is {s.player:GetAttribute("Carrying")}, wanted {spot.rarity}`)
	end
	s.lastNest[spot.rarity] = nestName
	s.carriedFrom = nestName
	expect(hasEgg(spot)).toBe(false)
	expect(s.prompts[nestName].Enabled).toBe(false)
end

-- The player walks home and Banking takes the egg. Checks the banked rank is the rank of the nest it came from.
local function bankAtGarden(s: Session): Rank
	local from = s.carriedFrom :: string
	local wanted = s.spotByName[from].rarity
	local count = #s.banked
	rootOf(s).Position = HOME
	s.garden = PLOT
	tick(s)
	if #s.banked ~= count + 1 then
		fail(s, `banking {from}: {#s.banked - count} eggs banked, wanted 1`)
	end
	local rank = s.banked[#s.banked]
	if rank ~= wanted then
		fail(s, `egg from {from} banked as {rank}, but the nest's rank is {wanted}`)
	end
	s.carriedFrom = nil
	expect(s.player:GetAttribute("Carrying")).toBe(nil)
	return s.banked[#s.banked]
end

-- Test B: starts the real giant (GiantRig). A catch puts the tracker stand-in back in the garden, as the tracker would.
local function startGiant(s: Session)
	local rig = GiantRig.start({
		player = s.player,
		service = s.players,
		sample = function()
			return sampleOf(s)
		end,
		now = function()
			return clockOf(s)
		end,
		grab = s.grab,
		plot = PLOT,
		home = HOME,
		onCaught = function(rank: string)
			table.insert(s.caught, rank :: Rank)
			s.garden, s.zone, s.moving = PLOT, "Meadow", false
		end,
		onFist = function()
			s.fistTick = s.ticks
		end,
	})
	s.state, s.director, s.catcher = rig.state, rig.director, rig.catcher
	table.insert(cleanups, rig.stop)
end

local function meterOf(s: Session): number
	return (s.state :: Folder):GetAttribute("Meter") :: number
end

local function phaseOf(s: Session): string
	return (s.state :: Folder):GetAttribute("Phase") :: string
end

-- The meter after `ticks` ticks should have risen by the Belly walk noise (carrying `rank`, or nothing) minus the
-- solo drain. Noise, SleepMeter and Config give the rate; the rounding to 0.1 at both ends is the margin.
local function expectMeterRise(s: Session, rank: Rank?, ticks: number)
	local noise = Noise.perSecond({ zone = "Belly", garden = nil, moving = true, tiptoe = false, carrying = rank })
	local perTick = (noise - SleepMeter.drainPerSecond(1)) * Config.Tick.Seconds
	local from = meterOf(s)
	for _ = 1, ticks do
		tick(s)
	end
	local risen = meterOf(s) - from
	if math.abs(risen - perTick * ticks) > 0.11 then
		fail(s, `meter rose {risen} in {ticks} ticks, Belly rate says {perTick * ticks} (carrying {rank})`)
	end
end

describe("NestsSession", function()
	it("A: a new player banks a Common, an Uncommon and a Rare, and each refills where the rules say", function()
		local s = newSession()
		-- Join: every rank starts with its eggs out, and only those nests' prompts are on.
		expect(eggsOut(s)).toBe("Common_1a,Uncommon_1a,Rare_1,Epic_LeftCuff,Epic_RightCuff")
		expect(promptsOn(s)).toBe(eggsOut(s))
		advance(s, 1)
		expect(#s.refillLog).toBe(0)

		-- Meadow Common: the next Common pops on the garden's other nest 10 s after the grab.
		grabAt(s, "Common_1a")
		expect(bankAtGarden(s)).toBe("Common")
		advance(s, 9.4) -- 9.5 s after the grab
		expect((eggsOut(s):find("Common_1b", 1, true))).toBe(nil)
		advance(s, 1) -- 10.5 s
		expect(eggsOut(s)).toBe("Common_1b,Uncommon_1a,Rare_1,Epic_LeftCuff,Epic_RightCuff")
		expect(#refillLog(s, "Common")).toBe(1)
		expect((refillLog(s, "Common")[1]).waited).toBeLessThan(0.2)

		-- Uncommon: banked, and back 30 s later on the garden's other nest.
		grabAt(s, "Uncommon_1a")
		expect(bankAtGarden(s)).toBe("Uncommon")
		advance(s, 28.9)
		expect((eggsOut(s):find("Uncommon_1b", 1, true))).toBe(nil)
		advance(s, 1.5)
		expect((eggsOut(s):find("Uncommon_1b", 1, true))).never.toBe(nil)
		expect(#refillLog(s, "Uncommon")).toBe(1)

		-- Rare: banked, then the player stands 10 studs from Rare_2. The refill 60 s later skips Rare_1 (it was taken
		-- there) and Rare_2 (a player is inside the 15 studs), so it lands on Rare_3.
		grabAt(s, "Rare_1")
		expect(bankAtGarden(s)).toBe("Rare")
		local near = s.spotByName.Rare_2.cframe.Position + Vector3.new(10, 2, 0)
		expect((near - s.spotByName.Rare_2.cframe.Position).Magnitude).toBeLessThan(Config.Nests.PlayerDistance)
		rootOf(s).Position = near
		s.garden = nil
		advance(s, 58.5)
		expect(#refillLog(s, "Rare")).toBe(0)
		advance(s, 2)
		expect(#refillLog(s, "Rare")).toBe(1)
		local line = refillLog(s, "Rare")[1]
		expect(line.nest).toBe("Rare_3")
		expect(line.waited).toBeLessThan(0.2)
		expect(hasEgg(s.spotByName.Rare_1)).toBe(false)
		expect(hasEgg(s.spotByName.Rare_2)).toBe(false)
		expect(s.player:GetAttribute("EggsHome")).toBe(3)
		expect(table.concat(s.banked, ",")).toBe("Common,Uncommon,Rare")
		expect(#s.refillLog).toBe(3)
	end)

	it(
		"B: the right-cuff Epic wakes him, a catch sends it back to a locked nest, and it opens after he sleeps",
		function()
			local s = newSession()
			startGiant(s)
			local cuff = s.spotByName.Epic_RightCuff
			-- A Rare first: the player is no longer new, so the full meter wakes him instead of a free save.
			grabAt(s, "Rare_1")
			expect(bankAtGarden(s)).toBe("Rare")
			expect(s.player:GetAttribute("RareHome")).toBe(true)

			-- The cuff is on his body: every step there counts as Belly (the zone the tracker stand-in reports).
			s.zone, s.moving = "Belly", true
			expect(Noise.perSecond({ zone = "Belly", garden = nil, moving = true, tiptoe = false })).toBeGreaterThan(
				Noise.perSecond({ zone = "Meadow", garden = nil, moving = true, tiptoe = false })
			)
			rootOf(s).Position = cuff.promptAnchor.WorldPosition + Vector3.new(3, 0, 0)
			s.garden = nil
			tick(s) -- the first tick from 0 only adds noise: the drain has nothing to take
			expectMeterRise(s, nil, 20)
			grabAt(s, "Epic_RightCuff")
			expectMeterRise(s, "Epic", 10)

			-- Carrying the Epic, walking on: the meter fills and he wakes.
			for _ = 1, 300 do
				tick(s)
				if phaseOf(s) == "Awake" then
					break
				end
			end
			if phaseOf(s) ~= "Awake" then
				fail(s, `meter {meterOf(s)} after 30 s: he never woke`)
			end
			expect((s.state :: Folder):GetAttribute("WokenBy")).toBe("Mia")
			s.moving = false

			-- The first slam is aimed at the carrier and catches them: the egg is back on its own nest, which stays locked.
			for _ = 1, 100 do
				if #s.caught > 0 then
					break
				end
				tick(s)
			end
			if #s.caught ~= 1 or s.caught[1] ~= "Epic" then
				fail(s, `caught {table.concat(s.caught, ",")} (wanted one Epic) while {phaseOf(s)}`)
			end
			expect(hasEgg(cuff)).toBe(true)
			expect(s.prompts.Epic_RightCuff.Enabled).toBe(false)
			expect(s.player:GetAttribute("Carrying")).toBe(nil)
			local home = rootOf(s).Position
			expect(math.sqrt((home.X - HOME.X) ^ 2 + (home.Z - HOME.Z) ^ 2)).toBeLessThan(0.5)
			expect(#refillLog(s, "Epic")).toBe(0)

			-- The wake-up runs. The nest opens a set time after he leaves Awake, and a set time after the last fist,
			-- whichever is later (Grab.updateCuffLock: Config.Nests.UnlockSeconds and ArmReturnSeconds). Checked one tick
			-- before and one tick after that tick, so the float edge never decides.
			for _ = 1, 300 do
				tick(s)
				if phaseOf(s) ~= "Awake" then
					break
				end
			end
			expect(phaseOf(s)).toBe("HeavySleep")
			local sleepTick = s.ticks
			tick(s) -- a fist may land on the same tick he leaves Awake: read the last fist after it
			local unlockTick = math.max(
				sleepTick + math.round(Config.Nests.UnlockSeconds * TICKS_PER_SECOND),
				(s.fistTick :: number) + math.round(Config.Nests.ArmReturnSeconds * TICKS_PER_SECOND)
			)
			while s.ticks < unlockTick - 1 do
				tick(s)
			end
			if s.prompts.Epic_RightCuff.Enabled ~= false then
				fail(s, `cuff nest open at tick {s.ticks}, locked until {unlockTick} (he left Awake at {sleepTick})`)
			end
			tick(s)
			tick(s)
			if s.prompts.Epic_RightCuff.Enabled ~= true then
				fail(s, `cuff nest still locked at tick {s.ticks}, open from {unlockTick} (fist {s.fistTick})`)
			end

			-- Take it again and bank it.
			s.zone = "Belly"
			grabAt(s, "Epic_RightCuff")
			expect(bankAtGarden(s)).toBe("Epic")
			expect(table.concat(s.banked, ",")).toBe("Rare,Epic")
			expect(s.player:GetAttribute("EggsHome")).toBe(2)
			expect(#s.caught).toBe(1)
		end
	)
end)
