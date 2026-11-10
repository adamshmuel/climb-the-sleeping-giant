--!strict
-- A whole session for one brand-new player (V2 spec 1, Story D and Story E; .claude/rules/tdd.md, "Whole-session
-- tests"). Every piece is the real one: the giant's director (with its sleep meter and warnings), PlayerInfo reading
-- the player's attributes, and Banking bringing eggs home. Only these are stand-ins: the tracker (the test says
-- where the player stands each tick), the grab (the test puts the egg on the player's back) and the Players service.
-- The wiring is the same as `init.server.luau`: each tick banks first, then the director reads the player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Banking = require(ServerScriptService.Server.Eggs.Banking)
local Carry = require(ServerScriptService.Server.Eggs.Carry)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local PlayerInfo = require(ServerScriptService.Server.Players.PlayerInfo)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

type Sample = PlayerTracker.Sample

local USER_ID = 7
local PLOT_INDEX = 4 -- the garden this player owns
local PLAYER_NAME = "mia_climbs" -- the user name; the banner must show the display name instead
local DISPLAY_NAME = "Mia"

-- The clock when the session starts, and how far it moves each tick.
local START_CLOCK = 1000

local MEADOW_POINTS: { Vector3 } = { Vector3.new(0, 2, 100), Vector3.new(0, 2, -100) }
local LANDING_SPOTS: { WorldIndex.LandingSpot } = {
	{ index = 1, position = Vector3.new(-50, 2, 0) },
	{ index = 2, position = Vector3.new(50, 2, 0) },
}

-- Everything a test makes is cleaned up afterwards, so the real place is never changed.
local cleanups: { () -> () } = {}

afterEach(function()
	for _, cleanup in cleanups do
		cleanup()
	end
	table.clear(cleanups)
end)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
	}
end

type Session = {
	player: any, -- the stand-in player: attributes only, like the parts of a Player the server reads
	state: Folder, -- the GiantState folder
	director: GiantDirector.Director,
	banking: Banking.Banking,
	samples: { Sample }, -- where the player stands; the test changes it between ticks
	clock: number,
	calls: { string }, -- every warning in order: "60" for a plain mark, "85:FreeSave" for a replay
	spent: { number }, -- the user id of every spendSave call
	saves: { { userId: number, zone: Config.ZoneName } },
	wakes: { { name: string, wokenBy: number?, cause: string } },
	banked: { Config.RarityName },
}

local function newSession(): Session
	-- The player. A brand-new one: nothing earned, nothing saved, nothing carried.
	local attributes = Instance.new("Folder")
	attributes:SetAttribute("PlotIndex", PLOT_INDEX)
	local player = {
		UserId = USER_ID,
		Name = PLAYER_NAME,
		DisplayName = DISPLAY_NAME,
		Character = nil,
		CharacterAdded = newSignal(),
		CharacterRemoving = newSignal(),
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes:SetAttribute(name, value)
		end,
	}
	local players = {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function(_self: any): { any }
			return { player }
		end,
		GetPlayerByUserId = function(_self: any, userId: number): any
			if userId == USER_ID then
				return player
			end
			return nil
		end,
	}
	-- The grab: banking an egg takes it off the player's back and says what it was, like the real one.
	local grab = {
		bank = function(_self: any, who: any): (string?, Config.RarityName?)
			local rarity = who:GetAttribute("Carrying")
			if rarity == nil then
				return nil, nil
			end
			who:SetAttribute("Carrying", nil)
			return "Spot_1", rarity
		end,
		returnEgg = function(): (("back" | "gone")?, string?)
			return nil, nil
		end,
	}

	local state = Instance.new("Folder")
	state:SetAttribute("Meter", 0)
	state:SetAttribute("Phase", "Asleep")

	local session: Session
	session = {
		player = player,
		state = state,
		director = nil :: any,
		banking = Banking.start({ grab = grab, players = players :: any }),
		samples = {},
		clock = START_CLOCK,
		calls = {},
		spent = {},
		saves = {},
		wakes = {},
		banked = {},
	}
	session.banking.banked:Connect(function(_who: any, rarity: Config.RarityName)
		table.insert(session.banked, rarity)
	end)
	session.director = GiantDirector.new({
		-- The same order as the server: bank first, then the giant reads the player.
		tick = function()
			session.banking:check(session.samples)
			return session.samples
		end,
		players = function()
			return { PlayerInfo.fromPlayer(player) }
		end,
		state = state,
		fireWarning = function(mark: number, kind: "FreeSave"?)
			table.insert(session.calls, if kind == nil then tostring(mark) else `{mark}:{kind}`)
		end,
		now = function()
			return session.clock
		end,
		landingSpots = LANDING_SPOTS,
		bounce = function() end,
		gardens = {},
		meadowPoints = MEADOW_POINTS,
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
		-- Like the server: the used save stays on the player, never on the character.
		spendSave = function(userId: number)
			table.insert(session.spent, userId)
			player:SetAttribute("FreeSaveUsed", true)
		end,
	})
	session.director.woke:Connect(function(name: string, wokenBy: number?, cause: string)
		table.insert(session.wakes, { name = name, wokenBy = wokenBy, cause = cause })
	end)
	session.director.saved:Connect(function(userId: number, zone: Config.ZoneName)
		table.insert(session.saves, { userId = userId, zone = zone })
	end)
	table.insert(cleanups, function()
		session.director:destroy()
		session.banking:stop()
		state:Destroy()
		attributes:Destroy()
	end)
	return session
end

-- Where the player stands for one tick.
local function at(zone: Config.ZoneName, moving: boolean, groundSpeed: number, garden: number?): Sample
	return {
		userId = USER_ID,
		position = Vector3.zero,
		moving = moving,
		groundSpeed = groundSpeed,
		zone = zone,
		garden = garden,
		thudFrom = nil,
		falling = false,
		moveGrace = false,
		onStitchedEdge = false,
	}
end

local WALKING_SPEED = Config.Movement.WalkSpeed

local function step(session: Session)
	session.clock += Config.Tick.Seconds
	session.director:step()
end

local function meterOf(session: Session): number
	return session.state:GetAttribute("Meter") :: number
end

local function asleep(session: Session): boolean
	return session.state:GetAttribute("Phase") == "Asleep"
end

-- Steps `count` ticks with the player standing at `sample`, and returns the highest meter seen on the way.
local function stepFor(session: Session, count: number, sample: Sample): number
	session.samples = { sample }
	local peak = meterOf(session)
	for _ = 1, count do
		step(session)
		peak = math.max(peak, meterOf(session))
	end
	return peak
end

-- Walks on the belly with no Tiptoe, tick by tick, until `stopWhen` says stop (or `limit` ticks pass). The meter is
-- checked on every tick: while he sleeps and the player walks on him, it must never sit still (spec section 10).
-- Returns how many ticks it took.
local function walkOnBellyUntil(session: Session, limit: number, stopWhen: () -> boolean): number
	session.samples = { at("Belly", true, WALKING_SPEED, nil) }
	local previous = meterOf(session)
	for tick = 1, limit do
		step(session)
		expect(meterOf(session)).never.toBe(previous)
		previous = meterOf(session)
		if stopWhen() then
			return tick
		end
	end
	return limit
end

-- Brings the carried egg to the player's own garden and checks the tick banks it.
local function walkHome(session: Session)
	stepFor(session, 1, at("Meadow", true, WALKING_SPEED, PLOT_INDEX))
end

describe("A brand-new player's whole session", function()
	it("joins, banks two Commons, takes the free save with a Rare, tiptoes home, then wakes him for real", function()
		local session = newSession()
		local player = session.player
		local tiptoeSpeed = Carry.speed(true, "Rare")

		-- 1. Joins. Two Commons from the silent meadow: the meter doesn't move, and the player is still new (Check E2).
		for _ = 1, 2 do
			player:SetAttribute("Carrying", "Common")
			stepFor(session, 30, at("Meadow", true, WALKING_SPEED, nil))
			walkHome(session)
		end
		expect(session.banked).toEqual({ "Common", "Common" })
		expect(player:GetAttribute("EggsHome")).toBe(2)
		expect(meterOf(session)).toBe(0)
		expect(asleep(session)).toBe(true)
		expect(player:GetAttribute("RareHome")).never.toBe(true)
		expect(PlayerInfo.fromPlayer(player).rareHome).toBe(false)
		expect(PlayerInfo.fromPlayer(player).freeSaveUsed).toBe(false)
		expect(session.calls).toEqual({})

		-- 2. Climbs, grabs the Rare at Rare_1 and keeps walking on the belly with no Tiptoe: the 60% warning, the 85%
		-- warning, then the free save (the first would-be wake). Every tick the meter moves.
		player:SetAttribute("Carrying", "Rare")
		stepFor(session, 20, at("Meadow", true, WALKING_SPEED, nil))
		walkOnBellyUntil(session, 600, function()
			return #session.spent > 0 or not asleep(session)
		end)
		expect(meterOf(session)).toBe(70)
		expect(asleep(session)).toBe(true)
		expect(session.spent).toEqual({ USER_ID })
		expect(session.saves).toEqual({ { userId = USER_ID, zone = "Belly" } })
		expect(session.calls).toEqual({ "60", "85", "85:FreeSave" })
		expect(player:GetAttribute("FreeSaveUsed")).toBe(true)
		expect(PlayerInfo.fromPlayer(player).freeSaveUsed).toBe(true)
		expect(PlayerInfo.fromPlayer(player).rareHome).toBe(false)

		-- 3. One more second of walking (the time a child needs to react), then a tiptoe straight home (Check D2).
		-- He never wakes. The meter passes 85 again while the replayed warning still shows, so nothing is fired.
		walkOnBellyUntil(session, 10, function()
			return false
		end)
		local peak = meterOf(session)
		player:SetAttribute("Tiptoe", true)
		peak = math.max(peak, stepFor(session, 40, at("Belly", true, tiptoeSpeed, nil))) -- 4 seconds on the belly
		peak = math.max(peak, stepFor(session, 80, at("Boots", true, tiptoeSpeed, nil))) -- 8 seconds on the boots
		peak = math.max(peak, stepFor(session, 30, at("Meadow", true, tiptoeSpeed, nil)))
		expect(peak).toBeGreaterThanOrEqual(92)
		expect(peak).toBeLessThanOrEqual(96)
		expect(asleep(session)).toBe(true)
		expect(session.wakes).toEqual({})
		expect(session.calls).toEqual({ "60", "85", "85:FreeSave" })
		stepFor(session, 1, at("Meadow", true, tiptoeSpeed, PLOT_INDEX))
		expect(session.banked).toEqual({ "Common", "Common", "Rare" })
		expect(player:GetAttribute("EggsHome")).toBe(3)
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(player:GetAttribute("RareHome")).toBe(true)
		expect(PlayerInfo.fromPlayer(player).rareHome).toBe(true) -- a veteran now
		expect(asleep(session)).toBe(true)
		expect(session.wakes).toEqual({})

		-- 4. Rests until the meter is low, climbs again with a second Rare and fills the meter: he wakes. The save is
		-- already used, so none is spent, there is no second replay, and the banner names this player.
		player:SetAttribute("Tiptoe", false)
		stepFor(session, 600, at("Meadow", false, 0, PLOT_INDEX))
		expect(meterOf(session)).toBeLessThan(20)
		player:SetAttribute("Carrying", "Rare")
		walkOnBellyUntil(session, 600, function()
			return not asleep(session)
		end)
		expect(session.state:GetAttribute("Phase")).toBe("Awake")
		expect(session.state:GetAttribute("WokenBy")).toBe(DISPLAY_NAME)
		expect(session.wakes).toEqual({ { name = DISPLAY_NAME, wokenBy = USER_ID, cause = "Walking" } })
		expect(session.spent).toEqual({ USER_ID })
		expect(session.saves).toEqual({ { userId = USER_ID, zone = "Belly" } })
		expect(session.calls).toEqual({ "60", "85", "85:FreeSave", "60", "85" })
	end)
end)
