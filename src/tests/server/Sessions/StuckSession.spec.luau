--!strict
-- A whole stuck session for one brand-new player (V2 stuck-safety, Layer 4 together; .claude/rules/tdd.md, "Whole-session
-- tests"). The real Recovery, RecoveryRules, SafeSpots, StuckWatch, Banking and GiantDirector run together. Only these
-- are stand-ins: the tracker (the test says where the player stands each tick), the grab (the test puts the Rare on
-- the player's back and a send home puts it back on its spot), the clock and the Players service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Banking = require(ServerScriptService.Server.Eggs.Banking)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local PlayerInfo = require(ServerScriptService.Server.Players.PlayerInfo)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local RecoveryRig = require(script.Parent.Parent.Players.RecoveryRig)

type Sample = PlayerTracker.Sample
type Rig = RecoveryRig.Rig

local USER_ID = 7
local START_FEET = Vector3.new(0, 60, 0) -- where the belly climb starts
local FORWARD = Vector3.new(-0.63, 0, -0.78) -- the way the player walks
local STRIDE = 1.6 -- studs per tick at walking speed
local ROOT_LIFT = Vector3.new(0, RecoveryRig.HIP_HEIGHT + RecoveryRig.ROOT_HEIGHT / 2, 0)
local TICK = Config.Tick.Seconds
local LANDING_SPOTS: { any } = {
	{ index = 1, position = Vector3.new(-50, 2, 0) },
	{ index = 2, position = Vector3.new(50, 2, 0) },
}

type Session = {
	player: any,
	rig: Rig,
	state: Folder,
	director: GiantDirector.Director,
	banking: Banking.Banking,
	clock: number,
	hows: { string }, -- what Unstuck told, in order
	rareOnSpot: boolean, -- the Rare is on its own spot (true until the player grabs it)
	samples: { Sample }, -- where the player stands; the test changes it every tick
	handled: number, -- how many sends home were already carried out
}

local cleanups: { () -> () } = {}

afterEach(function()
	for _, cleanup in cleanups do
		cleanup()
	end
	table.clear(cleanups)
	RecoveryRig.cleanUp()
end)

local function rootOf(s: Session): BasePart
	return RecoveryRig.rootOf(s.player.Character)
end

local function feetOf(s: Session): Vector3
	return rootOf(s).Position - ROOT_LIFT
end

local function newSession(): Session
	local player: any = RecoveryRig.newPlayer(USER_ID, START_FEET + ROOT_LIFT)
	player.Name = "mia_climbs"
	player.DisplayName = "Mia"
	player.CharacterRemoving = RecoveryRig.newSignal()
	local state = Instance.new("Folder")
	state:SetAttribute("Meter", 0)
	state:SetAttribute("Phase", "Asleep")
	local rig = RecoveryRig.newRig({ player })
	local session: Session
	session = {
		player = player,
		rig = rig,
		state = state,
		director = nil :: any,
		banking = nil :: any,
		clock = rig.clock,
		hows = {},
		rareOnSpot = true,
		samples = {},
		handled = 0,
	}
	local grab = {
		bank = function(): (string?, Config.RarityName?)
			return nil, nil
		end,
		-- Like the real one: the carried egg goes off the back and onto its own spot.
		returnEgg = function(_self: any, who: any): (("back" | "gone")?, string?)
			if who:GetAttribute("Carrying") == nil then
				return nil, nil
			end
			who:SetAttribute("Carrying", nil)
			session.rareOnSpot = true
			return "back", "EggSpot_Rare_1"
		end,
	}
	session.banking = Banking.start({
		grab = grab,
		players = {
			PlayerAdded = RecoveryRig.newSignal(),
			PlayerRemoving = RecoveryRig.newSignal(),
			GetPlayers = function(_self: any): { any }
				return { player }
			end,
			GetPlayerByUserId = function(_self: any, userId: number): any
				return if userId == USER_ID then player else nil
			end,
		} :: any,
	})
	session.director = GiantDirector.new({
		tick = function()
			return session.samples
		end,
		players = function()
			return { PlayerInfo.fromPlayer(player) }
		end,
		state = state,
		fireWarning = function() end,
		now = function()
			return session.clock
		end,
		landingSpots = LANDING_SPOTS,
		bounce = function() end,
		gardens = {},
		meadowPoints = { Vector3.new(0, 2, 100), Vector3.new(0, 2, -100) },
		face = Vector3.new(0, 95, 0),
		floating = function()
			return false
		end,
		landedAgo = function()
			return nil
		end,
		pick = function()
			return 1
		end,
		surfaceBelow = function(centre: Vector3): Vector3
			return centre - Vector3.new(0, 3, 0)
		end,
		fireSlamWarning = function() end,
		fireSlamLanded = function() end,
		catch = function() end,
		joinedAt = function()
			return nil
		end,
		appearedAt = function()
			return nil
		end,
		showSpots = {},
		gates = {},
		bonk = function() end,
		onLadder = function()
			return false
		end,
		spendSave = function(userId: number)
			expect(userId).toBe(USER_ID)
			player:SetAttribute("FreeSaveUsed", true)
		end,
	})
	rig.recovery.unstuck:Connect(function(_who: any, how: string, _zone: string)
		table.insert(session.hows, how)
	end)
	table.insert(cleanups, function()
		session.director:destroy()
		session.banking:stop()
		state:Destroy()
	end)
	return session
end

local function meterOf(s: Session): number
	return s.state:GetAttribute("Meter") :: number
end

local function phaseOf(s: Session): Config.Phase
	return s.state:GetAttribute("Phase") :: Config.Phase
end

-- One tick: the clock moves, the spots are saved and the watch runs (Recovery), then the giant reads the player.
-- Returns how much the meter moved on this tick.
local function tick(s: Session, moving: boolean): number
	local before = meterOf(s)
	s.clock += TICK
	s.rig.clock = s.clock
	s.rig.samples[USER_ID] = RecoveryRig.sampleAt(feetOf(s), FORWARD, s.clock)
	s.rig.recovery:step()
	local sample: Sample = {
		userId = USER_ID,
		position = Vector3.zero,
		moving = moving,
		groundSpeed = if moving then Config.Movement.WalkSpeed else 0,
		zone = "Belly",
		garden = nil,
		thudFrom = nil,
		falling = false,
		moveGrace = false,
		onStitchedEdge = false,
	}
	s.samples = { sample }
	s.director:step()
	return meterOf(s) - before
end

local function walk(s: Session, ticks: number)
	for _ = 1, ticks do
		rootOf(s).Position += FORWARD * STRIDE
		tick(s, true)
	end
end

local function stand(s: Session, ticks: number)
	for _ = 1, ticks do
		tick(s, false)
	end
end

local function grabRare(s: Session)
	expect(s.rareOnSpot).toBe(true)
	s.rareOnSpot = false
	s.player:SetAttribute("Carrying", "Rare")
end

-- Carries out the sends home the rig counted: the character is removed (Banking puts the egg back) and a new one
-- stands at the start of the climb.
local function settleHomes(s: Session)
	while s.handled < #s.rig.home do
		s.handled += 1
		s.player.CharacterRemoving:Fire(s.player.Character)
		local character = RecoveryRig.makeCharacter(START_FEET + ROOT_LIFT)
		table.insert(RecoveryRig.made, character)
		s.player.Character = character
		s.player.CharacterAdded:Fire(character)
	end
end

local function reset(s: Session)
	s.rig.phase = if phaseOf(s) == "Awake" then "Awake" else "Asleep"
	s.rig.recovery:reset(s.player)
	settleHomes(s)
end

describe("A brand-new player's stuck session", function()
	it(
		"a brand-new player's stuck session: rescued, Reset back, sent home by the loop, grabs again, and a Reset while he's awake sends them home",
		function()
			local s = newSession()
			local rig = s.rig
			local firstCharacter = s.player.Character

			-- 1. Grabs the Rare and climbs the belly; a spot is saved every half second.
			grabRare(s)
			walk(s, 30)
			expect(rig.safeSpots:count(USER_ID)).toBeGreaterThanOrEqual(5)
			expect(phaseOf(s)).toBe("Asleep")

			-- 2. Wedged and pressing: not rescued at 2.9 s, rescued by 3 s plus one tick (Rule 28).
			local wedged = feetOf(s)
			local meterBeforeWedge = meterOf(s)
			rig.recovery:setPressing(s.player, true)
			local deltas: { number } = {}
			for _ = 1, 30 do
				table.insert(deltas, tick(s, false))
			end
			expect(#rig.rescues).toBe(0)
			for _ = 1, 2 do
				if #rig.rescues == 0 then
					table.insert(deltas, tick(s, false))
				end
			end
			expect(#rig.rescues).toBe(1)
			expect((feetOf(s) - wedged).Magnitude).toBeGreaterThanOrEqual(Config.Stuck.RescueDistance) -- Rule 27
			expect(s.player:GetAttribute("Carrying")).toBe("Rare") -- Rule 30
			expect(s.player.Character).toBe(firstCharacter)
			-- Rule 31: the wedge and the rescue add or remove nothing beyond the normal solo drain. The shown meter is rounded
			-- to 0.1 at both ends, so it may be off by up to 0.1. The smallest noise Rule 31 forbids (tiptoe walking with a
			-- Rare on the belly, 0.3 a tick) is bigger than that.
			local expected = meterBeforeWedge - Config.Meter.SoloDrain * TICK * #deltas
			expect(expected).toBeGreaterThan(1) -- the drain never reaches 0, so the check means something
			expect(math.abs(meterOf(s) - expected)).toBeLessThan(0.11)
			for _ = 1, 10 do
				tick(s, false)
			end
			expect(#rig.rescues).toBe(1) -- held still: no second rescue while he keeps pressing
			expect(s.player:GetAttribute("Held")).toBe(true)
			rig.recovery:setPressing(s.player, false)
			expect(s.player:GetAttribute("Held")).toBeNil()

			-- 3. Stands on for 31 s, so the rescue no longer counts. Reset: moved back, same character, keeps the Rare.
			stand(s, 310)
			reset(s)
			expect(#rig.rescues).toBe(2)
			expect(s.player.Character).toBe(firstCharacter)
			expect(s.player:GetAttribute("Carrying")).toBe("Rare")

			-- 4. Reset again 2.5 s later: moved back, keeps the Rare.
			stand(s, 25)
			reset(s)
			expect(#rig.rescues).toBe(3)
			expect(s.player:GetAttribute("Carrying")).toBe("Rare")

			-- 5. A third Reset 2.5 s later is a loop (Rule 29): sent home.
			stand(s, 25)
			reset(s)
			expect(#rig.home).toBe(1)
			expect(#rig.rescues).toBe(3)
			expect(s.player:GetAttribute("Carrying")).toBeNil()
			expect(s.rareOnSpot).toBe(true) -- Rule 30: the Rare is back on its spot

			-- 6. After the respawn, grabs the Rare again and climbs again.
			expect(s.player.Character).never.toBe(firstCharacter)
			grabRare(s)
			walk(s, 30)
			expect(rig.safeSpots:count(USER_ID)).toBeGreaterThanOrEqual(5)
			expect(s.player:GetAttribute("Carrying")).toBe("Rare")

			-- 7. He wakes through the director's own path. A Reset while he is awake sends the player home.
			local ticks = 0
			while phaseOf(s) == "Asleep" and ticks < 600 do
				walk(s, 1)
				ticks += 1
			end
			expect(phaseOf(s)).toBe("Awake")
			reset(s)
			expect(#rig.home).toBe(2)
			expect(s.player:GetAttribute("Carrying")).toBeNil()
			expect(s.rareOnSpot).toBe(true)

			-- 8. Unstuck was told five times, in order (spec section 10).
			expect(s.hows).toEqual({ "Rescue", "Reset on giant", "Reset on giant", "Loop home", "Reset on giant" })
		end
	)
end)
