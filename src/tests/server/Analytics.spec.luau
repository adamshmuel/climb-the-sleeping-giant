--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Analytics = require(ServerScriptService.Server.Analytics)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)

-- The two breakdown slots Roblox gives a custom event. Which one means what depends on the event.
local FIELD_ONE = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local FIELD_TWO = Enum.AnalyticsCustomFieldKeys.CustomField02.Name

-- Everything the fake AnalyticsService was asked to log, in order.
type Call = {
	method: string, -- "onboarding", "funnel" or "custom"
	player: any,
	step: number?,
	stepName: string?,
	funnelName: string?,
	sessionId: string?,
	eventName: string?,
	value: number?,
	fields: { [string]: string }?,
}

type FakePlayer = {
	UserId: number,
	Name: string,
	Character: any,
	CharacterAdded: Signal.Signal<any>,
	attributes: { [string]: any },
	GetAttribute: (self: any, name: string) -> any,
}

type Harness = {
	analytics: Analytics.Analytics,
	calls: { Call },
	warnings: { string },
	clock: number,
	list: { FakePlayer }, -- what GetPlayers returns, in this order
	failing: { [string]: boolean }, -- "onboarding", "funnel" or "custom": the fake service errors on that method
	playerAdded: Signal.Signal<any>,
	playerRemoving: Signal.Signal<any>,
	grabbed: Signal.Signal<any, any>,
	banked: Signal.Signal<any, any>,
	caught: Signal.Signal<any, any>,
	woke: Signal.Signal<string, number?, string>,
	slammed: Signal.Signal<number?, { number }>,
	idsMade: number,
}

local OWN_GARDEN_SPAWN_X = 100 -- garden N's spawn spot is at X = N * 100, Z = 0, so every garden is far from the others

local made: { Harness } = {}
local players: { FakePlayer } = {}

afterEach(function()
	for _, harness in made do
		harness.analytics:stop()
		harness.playerAdded:Destroy()
		harness.playerRemoving:Destroy()
		harness.grabbed:Destroy()
		harness.banked:Destroy()
		harness.caught:Destroy()
		harness.woke:Destroy()
		harness.slammed:Destroy()
	end
	table.clear(made)
	for _, player in players do
		player.CharacterAdded:Destroy()
	end
	table.clear(players)
end)

-- A player with a garden number (nil for none). Attributes are plain values, and the character is not there yet.
local function makePlayer(userId: number, plotIndex: number?): FakePlayer
	local player: FakePlayer = {
		UserId = userId,
		Name = `Player{userId}`,
		Character = nil,
		CharacterAdded = Signal.new(),
		attributes = { PlotIndex = plotIndex, EggsHome = 0 },
		GetAttribute = function(self: any, name: string): any
			return self.attributes[name]
		end,
	}
	table.insert(players, player)
	return player
end

local function newHarness(present: { FakePlayer }?): Harness
	local harness: Harness = {
		analytics = nil :: any,
		calls = {},
		warnings = {},
		clock = 0,
		list = if present ~= nil then table.clone(present) else {},
		failing = {},
		playerAdded = Signal.new(),
		playerRemoving = Signal.new(),
		grabbed = Signal.new(),
		banked = Signal.new(),
		caught = Signal.new(),
		woke = Signal.new(),
		slammed = Signal.new(),
		idsMade = 0,
	}
	local function record(method: string, call: Call)
		if harness.failing[method] then
			error("the fake service fails on " .. method)
		end
		table.insert(harness.calls, call)
	end
	local service = {
		LogOnboardingFunnelStepEvent = function(_self: any, player: any, step: number, stepName: string)
			record("onboarding", { method = "onboarding", player = player, step = step, stepName = stepName })
		end,
		LogFunnelStepEvent = function(
			_self: any,
			player: any,
			funnelName: string,
			sessionId: string,
			step: number,
			stepName: string
		)
			record("funnel", {
				method = "funnel",
				player = player,
				funnelName = funnelName,
				sessionId = sessionId,
				step = step,
				stepName = stepName,
			})
		end,
		LogCustomEvent = function(
			_self: any,
			player: any,
			eventName: string,
			value: number?,
			fields: { [string]: string }?
		)
			record(
				"custom",
				{ method = "custom", player = player, eventName = eventName, value = value, fields = fields }
			)
		end,
	}
	local gardens = {}
	for index = 1, 8 do
		table.insert(gardens, { index = index, spawnPosition = Vector3.new(index * OWN_GARDEN_SPAWN_X, 10, 0) })
	end
	harness.analytics = Analytics.start({
		service = service,
		players = {
			PlayerAdded = harness.playerAdded,
			PlayerRemoving = harness.playerRemoving,
			GetPlayers = function(_self: any): any
				return table.clone(harness.list)
			end,
			GetPlayerByUserId = function(_self: any, userId: number): any
				for _, player in harness.list do
					if player.UserId == userId then
						return player
					end
				end
				return nil
			end,
		},
		grabbed = harness.grabbed,
		banked = harness.banked,
		caught = harness.caught,
		woke = harness.woke,
		slammed = harness.slammed,
		gardens = gardens,
		now = function()
			return harness.clock
		end,
		newId = function()
			harness.idsMade += 1
			return `heist-{harness.idsMade}`
		end,
		warn = function(message: string)
			table.insert(harness.warnings, message)
		end,
	})
	table.insert(made, harness)
	return harness
end

-- The player joins the server (at the end of GetPlayers, or at the front if `atFront`).
local function join(harness: Harness, player: FakePlayer, atFront: boolean?)
	if atFront == true then
		table.insert(harness.list, 1, player)
	else
		table.insert(harness.list, player)
	end
	harness.playerAdded:Fire(player)
end

-- The player's character appears (a first spawn or a respawn).
local function spawnCharacter(player: FakePlayer)
	player.Character = {}
	player.CharacterAdded:Fire(player.Character)
end

local function leave(harness: Harness, player: FakePlayer)
	harness.playerRemoving:Fire(player)
	local at = table.find(harness.list, player)
	if at ~= nil then
		table.remove(harness.list, at)
	end
end

-- Joins and spawns in one go.
local function enter(harness: Harness, player: FakePlayer)
	join(harness, player)
	spawnCharacter(player)
end

local function grab(harness: Harness, player: FakePlayer, rarity: Config.RarityName)
	player.attributes.Carrying = rarity
	harness.grabbed:Fire(player, rarity)
end

-- Banking's order: Carrying is cleared and EggsHome goes up, then `banked` fires.
local function bank(harness: Harness, player: FakePlayer)
	local rarity = player.attributes.Carrying
	player.attributes.Carrying = nil
	player.attributes.EggsHome += 1
	harness.banked:Fire(player, rarity)
end

local function catch(harness: Harness, player: FakePlayer)
	local rarity = player.attributes.Carrying
	player.attributes.Carrying = nil
	harness.caught:Fire(player, rarity)
end

-- Where a player is for the tick: `garden` is the garden box they stand in (nil in the meadow), and `x`, `z` and `y`
-- the position.
local function sampleOf(player: FakePlayer, garden: number?, x: number, z: number, y: number?): PlayerTracker.Sample
	return {
		userId = player.UserId,
		position = Vector3.new(x, y or 3, z),
		moving = false,
		groundSpeed = 0,
		zone = "Meadow",
		garden = garden,
		thudFrom = nil,
	}
end

-- A sample of a player outside everything, this many studs along X from their own spawn spot.
local function awayFromHome(player: FakePlayer, studs: number, y: number?): PlayerTracker.Sample
	local plot = player.attributes.PlotIndex :: number
	return sampleOf(player, nil, plot * OWN_GARDEN_SPAWN_X + studs, 0, y)
end

local function callsOf(harness: Harness, method: string, player: FakePlayer?): { Call }
	local found: { Call } = {}
	for _, call in harness.calls do
		if call.method == method and (player == nil or call.player == player) then
			table.insert(found, call)
		end
	end
	return found
end

-- The steps of the onboarding calls, as "1 Spawned" lines, so one expect shows the whole list.
local function onboardingLines(harness: Harness, player: FakePlayer?): { string }
	local lines: { string } = {}
	for _, call in callsOf(harness, "onboarding", player) do
		table.insert(lines, `{call.step} {call.stepName}`)
	end
	return lines
end

local function heistLines(harness: Harness, player: FakePlayer?): { string }
	local lines: { string } = {}
	for _, call in callsOf(harness, "funnel", player) do
		table.insert(lines, `{call.sessionId} {call.step} {call.stepName}`)
	end
	return lines
end

describe("Analytics onboarding", function()
	it("logs step 1 'Spawned' when a new player's character appears", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].method).toBe("onboarding")
		expect(harness.calls[1].player).toBe(mia)
		expect(harness.calls[1].step).toBe(1)
		expect(harness.calls[1].stepName).toBe("Spawned")
	end)

	it("logs nothing for a player who has joined but has no character yet", function()
		local harness = newHarness()
		join(harness, makePlayer(1, 1))
		expect(harness.calls).toEqual({})
	end)

	it("logs step 1 for a player already in the game, with a character, when it starts", function()
		local mia = makePlayer(1, 1)
		mia.Character = {}
		local harness = newHarness({ mia })
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned" })
	end)

	it("waits for the character of a player already in the game who has none yet", function()
		local mia = makePlayer(1, 1)
		local harness = newHarness({ mia })
		expect(harness.calls).toEqual({})
		spawnCharacter(mia)
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned" })
	end)

	it("does not log step 1 again when the player respawns", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		spawnCharacter(mia)
		spawnCharacter(mia)
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned" })
	end)

	it("logs step 2 'First egg grabbed' on the first grab and not on the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Common")
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned", "2 First egg grabbed", "3 First egg home" })
	end)

	it("logs step 3 'First egg home' for the first banked egg and step 4 'Second egg home' for the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned", "2 First egg grabbed", "3 First egg home" })
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"4 Second egg home",
		})
	end)

	it("logs nothing more for the third egg home", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		for _ = 1, 3 do
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		expect(#onboardingLines(harness, mia)).toBe(4)
	end)

	it("logs step 5 'First Uncommon home' for the first Uncommon and not the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"4 Second egg home",
			"5 First Uncommon home",
		})
	end)

	it("logs step 6 'First Rare home' for the first Rare and not the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		for _ = 1, 2 do
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		grab(harness, mia, "Rare")
		bank(harness, mia)
		grab(harness, mia, "Rare")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"4 Second egg home",
			"6 First Rare home",
		})
	end)

	it("logs steps 3 and 5 together when the first egg home is an Uncommon", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"5 First Uncommon home",
		})
	end)

	it("logs a step once even if the egg count reads the same again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		mia.attributes.EggsHome = 0
		grab(harness, mia, "Common")
		bank(harness, mia)
		local count = 0
		for _, line in onboardingLines(harness, mia) do
			if line == "3 First egg home" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)

	it("counts each player's steps on their own", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		local bo = makePlayer(2, 2)
		enter(harness, mia)
		enter(harness, bo)
		grab(harness, mia, "Common")
		grab(harness, bo, "Common")
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned", "2 First egg grabbed" })
		expect(onboardingLines(harness, bo)).toEqual({ "1 Spawned", "2 First egg grabbed" })
	end)

	it("logs step 1 again for a player who leaves and comes back, because it is a new visit", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		leave(harness, mia)
		local miaAgain = makePlayer(1, 1)
		enter(harness, miaAgain)
		grab(harness, miaAgain, "Common")
		expect(onboardingLines(harness, miaAgain)).toEqual({ "1 Spawned", "2 First egg grabbed" })
	end)

	it("ignores an event for a player it is not tracking", function()
		local harness = newHarness()
		local stranger = makePlayer(9, 1)
		grab(harness, stranger, "Common")
		bank(harness, stranger)
		catch(harness, stranger)
		expect(harness.calls).toEqual({})
	end)
end)

describe("Analytics Heist funnel", function()
	it("logs steps 1, 2 and 3 in order with one session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed", "heist-1 3 Home" })
		local calls = callsOf(harness, "funnel", mia)
		expect(calls[1].funnelName).toBe("Heist")
		expect(calls[2].funnelName).toBe("Heist")
		expect(calls[3].funnelName).toBe("Heist")
		expect(calls[1].player).toBe(mia)
	end)

	it("asks for one new session id for each heist, not for each step", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(harness.idsMade).toBe(1)
	end)

	it("gives the next heist a new session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		for _ = 1, 2 do
			harness.analytics:check({ awayFromHome(mia, 11) })
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-1 3 Home",
			"heist-2 1 Left garden",
			"heist-2 2 Grabbed",
			"heist-2 3 Home",
		})
	end)

	it("keeps each player's heist on its own session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		local bo = makePlayer(2, 2)
		enter(harness, mia)
		enter(harness, bo)
		harness.analytics:check({ awayFromHome(mia, 11), awayFromHome(bo, 11) })
		grab(harness, bo, "Common")
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed" })
		expect(heistLines(harness, bo)).toEqual({ "heist-2 1 Left garden", "heist-2 2 Grabbed" })
	end)

	it("logs step 1 only once while the heist is open: out, back home, out again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		harness.analytics:check({ awayFromHome(mia, 30) })
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X, 0) })
		harness.analytics:check({ awayFromHome(mia, 12) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("keeps the same heist when the player walks home without an egg and then grabs", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X, 0) })
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed" })
	end)

	it("logs no step 1 while the player carries an egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		mia.attributes.Carrying = "Common"
		harness.analytics:check({ awayFromHome(mia, 50) })
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("logs no step 1 at exactly 10 studs from the spawn spot, and logs it just past 10", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 10) })
		expect(heistLines(harness, mia)).toEqual({})
		harness.analytics:check({ awayFromHome(mia, 10.1) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("measures the 10 studs across the ground only, ignoring height", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 5, 200) })
		expect(heistLines(harness, mia)).toEqual({})
		harness.analytics:check({ awayFromHome(mia, 11, 2) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("logs no step 1 while the player stands in their own garden, however far from the spawn spot", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X + 60, 0) })
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("counts another player's garden as outside their own", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, 2, 2 * OWN_GARDEN_SPAWN_X, 0) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("logs no step 1 for a player who has no garden", function()
		local harness = newHarness()
		local mia = makePlayer(1, nil)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, nil, 500, 500) })
		harness.analytics:check({ sampleOf(mia, 3, 500, 500) }) -- standing in someone else's garden
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("logs no step 1 for a player whose garden number has no spawn spot", function()
		local harness = newHarness()
		local mia = makePlayer(1, 9)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, nil, 500, 500) })
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("ignores a sample of a player it is not tracking", function()
		local harness = newHarness()
		local stranger = makePlayer(9, 1)
		harness.analytics:check({ awayFromHome(stranger, 50) })
		expect(harness.calls).toEqual({})
		expect(harness.idsMade).toBe(0)
	end)

	it("opens a heist at a grab with no heist open and logs step 2 only", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 2 Grabbed" })
		bank(harness, mia)
		expect(heistLines(harness, mia)).toEqual({ "heist-1 2 Grabbed", "heist-1 3 Home" })
	end)

	it("ends the heist at a catch, so the next grab uses a new session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		catch(harness, mia)
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 2 Grabbed",
		})
	end)

	it("starts a new heist with its own step 1 after a catch, when the player leaves the garden again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		catch(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 40) })
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 1 Left garden",
		})
	end)

	it("ends the heist when the egg is lost another way: Carrying is gone at the next check", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		mia.attributes.Carrying = nil -- the carrier died
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X, 0) })
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 2 Grabbed",
		})
	end)

	it("starts a new heist with its own step 1 when the egg was lost and the player is outside again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		mia.attributes.Carrying = nil -- the carrier died
		harness.analytics:check({ awayFromHome(mia, 40) })
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 1 Left garden",
		})
	end)

	it("does not end the heist at a check while the player still carries the egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		harness.analytics:check({ awayFromHome(mia, 40) })
		harness.analytics:check({ awayFromHome(mia, 60) })
		bank(harness, mia)
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed", "heist-1 3 Home" })
	end)

	it("does not end a heist that has not reached step 2 when the player carries nothing at a check", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		harness.analytics:check({ awayFromHome(mia, 12) })
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed" })
	end)

	it("starts a new heist when a grab comes while an earlier one is still open at step 2", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		mia.attributes.Carrying = nil -- lost with no check in between
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 2 Grabbed", "heist-2 2 Grabbed" })
	end)

	it("forgets an open heist when the player leaves", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		leave(harness, mia)
		local miaAgain = makePlayer(1, 1)
		enter(harness, miaAgain)
		grab(harness, miaAgain, "Common")
		expect(heistLines(harness, miaAgain)).toEqual({ "heist-2 2 Grabbed" })
	end)
end)

describe("Analytics EggHome", function()
	it("logs a Rare banked from garden 8 with value 1, the rarity and the garden number", function()
		local harness = newHarness()
		local mia = makePlayer(1, 8)
		enter(harness, mia)
		grab(harness, mia, "Rare")
		bank(harness, mia)
		local events = callsOf(harness, "custom", mia)
		expect(#events).toBe(1)
		expect(events[1].eventName).toBe("EggHome")
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Rare")
		expect((events[1].fields :: any)[FIELD_TWO]).toBe("8")
		expect(type((events[1].fields :: any)[FIELD_TWO])).toBe("string")
	end)

	it("logs one EggHome for every banked egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 3)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		local events = callsOf(harness, "custom", mia)
		expect(#events).toBe(2)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Common")
		expect((events[2].fields :: any)[FIELD_ONE]).toBe("Uncommon")
		expect((events[2].fields :: any)[FIELD_TWO]).toBe("3")
	end)
end)

-- A server of `count` players, user ids 1 to `count` in the order they joined. Returns the harness and the players.
local function serverOf(count: number): (Harness, { FakePlayer })
	local harness = newHarness()
	local all: { FakePlayer } = {}
	for index = 1, count do
		local player = makePlayer(index, index)
		enter(harness, player)
		table.insert(all, player)
	end
	table.clear(harness.calls)
	return harness, all
end

describe("Analytics GiantWoke", function()
	it("logs once on the player who woke him, valued at the number of players, with the server size", function()
		local harness, all = serverOf(3)
		harness.woke:Fire("Bo", all[2].UserId, "Jump on him")
		expect(#harness.calls).toBe(1)
		local call = harness.calls[1]
		expect(call.method).toBe("custom")
		expect(call.player).toBe(all[2])
		expect(call.eventName).toBe("GiantWoke")
		expect(call.value).toBe(3)
		expect((call.fields :: any)[FIELD_ONE]).toBe("2-4")
		expect((call.fields :: any)[FIELD_TWO]).toBe("Jump on him")
	end)

	for _, row in
		{
			{ count = 1, size = "1" },
			{ count = 2, size = "2-4" },
			{ count = 4, size = "2-4" },
			{ count = 5, size = "5-8" },
			{ count = 8, size = "5-8" },
		}
	do
		local count, size = row.count, row.size
		it(`calls a server of {count} players "{size}"`, function()
			local harness, all = serverOf(count)
			harness.woke:Fire("Name", all[1].UserId, "Walking")
			expect(harness.calls[1].value).toBe(count)
			expect((harness.calls[1].fields :: any)[FIELD_ONE]).toBe(size)
		end)
	end

	for _, cause in { "Walking", "Jump on him", "Jump off" } do
		it(`passes the director's cause "{cause}" through`, function()
			local harness, all = serverOf(2)
			harness.woke:Fire("Name", all[1].UserId, cause)
			expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe(cause)
		end)
	end

	it("logs on the player who joined first, with 'Waker left', when nobody is named", function()
		local harness, all = serverOf(3)
		harness.woke:Fire("", nil, "Waker left")
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[1])
		expect(harness.calls[1].value).toBe(3)
		expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe("Waker left")
	end)

	it("says 'Waker left' when nobody is named, whatever cause came with it", function()
		local harness, _all = serverOf(2)
		harness.woke:Fire("", nil, "Walking")
		expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe("Waker left")
	end)

	it("takes the player who joined first by join time, even when that is not first in GetPlayers", function()
		local harness = newHarness()
		local early = makePlayer(1, 1)
		local late = makePlayer(2, 2)
		harness.clock = 10
		enter(harness, early)
		harness.clock = 50
		enter(harness, late)
		-- GetPlayers happens to list the newest player first.
		harness.list = { late, early }
		table.clear(harness.calls)
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls[1].player).toBe(early)
	end)

	it("counts players already there when it starts in GetPlayers order, before anyone who joins later", function()
		local first = makePlayer(1, 1)
		local second = makePlayer(2, 2)
		local harness = newHarness({ second, first })
		local late = makePlayer(3, 3)
		harness.clock = 5
		enter(harness, late)
		table.clear(harness.calls)
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls[1].player).toBe(second)
	end)

	it("skips a player who has left when it looks for the one who has been there longest", function()
		local harness, all = serverOf(3)
		leave(harness, all[1])
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls[1].player).toBe(all[2])
		expect(harness.calls[1].value).toBe(2)
	end)

	it("logs 'Waker left' on the player who joined first when the named waker has left", function()
		local harness, all = serverOf(3)
		local gone = all[3]
		leave(harness, gone)
		harness.woke:Fire("Cy", gone.UserId, "Jump on him")
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[1])
		expect(harness.calls[1].value).toBe(2)
		expect((harness.calls[1].fields :: any)[FIELD_TWO]).toBe("Waker left")
	end)

	it("logs nothing when there is no player in the server", function()
		local harness, all = serverOf(2)
		leave(harness, all[1])
		leave(harness, all[2])
		harness.woke:Fire("", nil, "Waker left")
		expect(harness.calls).toEqual({})
	end)

	it("logs again on the next wake", function()
		local harness, all = serverOf(2)
		harness.woke:Fire("Ann", all[1].UserId, "Walking")
		harness.woke:Fire("Bo", all[2].UserId, "Jump off")
		expect(#harness.calls).toBe(2)
		expect(harness.calls[1].player).toBe(all[1])
		expect(harness.calls[2].player).toBe(all[2])
	end)

	it("logs one event per wake, not one for each player", function()
		local harness, all = serverOf(5)
		harness.woke:Fire("Ann", all[1].UserId, "Walking")
		expect(#harness.calls).toBe(1)
	end)
end)

describe("Analytics Slam", function()
	-- The one "Slam" call the harness got, with its fields read as text.
	local function onlySlam(harness: Harness): (Call, string, string)
		expect(#harness.calls).toBe(1)
		local call = harness.calls[1]
		expect(call.method).toBe("custom")
		expect(call.eventName).toBe("Slam")
		local fields = call.fields :: { [string]: string }
		return call, fields[FIELD_ONE], fields[FIELD_TWO]
	end

	it("logs 'Caught' with value 1 on the target, with the result and the server size", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[2].UserId, { all[2].UserId })
		local call, result, size = onlySlam(harness)
		expect(call.player).toBe(all[2])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
		expect(size).toBe("2-4")
	end)

	it("logs 'Missed' with value 0 on the target when a slam aimed at a carrier caught nobody", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(all[3].UserId, {})
		local call, result, size = onlySlam(harness)
		expect(call.player).toBe(all[3])
		expect(call.value).toBe(0)
		expect(result).toBe("Missed")
		expect(size).toBe("2-4")
	end)

	it("values the event at the number of players the slam caught", function()
		local harness, all = serverOf(4)
		harness.slammed:Fire(all[1].UserId, { all[1].UserId, all[3].UserId })
		local call, result = onlySlam(harness)
		expect(call.value).toBe(2)
		expect(result).toBe("Caught")
	end)

	it("logs 'Empty' with value 0 on the player here longest when nobody was the target", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(nil, {})
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(0)
		expect(result).toBe("Empty")
	end)

	it("picks the longest-in-server player for an 'Empty' slam by join time, not by place in GetPlayers", function()
		local harness = newHarness()
		local early = makePlayer(1, 1)
		local late = makePlayer(2, 2)
		harness.clock = 10
		enter(harness, early)
		harness.clock = 50
		enter(harness, late)
		harness.list = { late, early }
		table.clear(harness.calls)
		harness.slammed:Fire(nil, {})
		local call = onlySlam(harness)
		expect(call.player).toBe(early)
	end)

	it("logs on the player here longest, with the same result, when the target has left", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(all[3].UserId, {})
		local call, result, size = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(0)
		expect(result).toBe("Missed")
		expect(size).toBe("2-4")
	end)

	it("logs 'Caught' on the player here longest when the target left but the slam caught someone else", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(all[3].UserId, { all[2].UserId })
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
	end)

	it("logs 'Caught' on the caught player when an empty-meadow slam caught a carrier who walked under it", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(nil, { all[3].UserId })
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[3])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
	end)

	it("logs an empty-meadow slam that caught two on the first caught player", function()
		local harness, all = serverOf(3)
		harness.slammed:Fire(nil, { all[3].UserId, all[2].UserId })
		local call = onlySlam(harness)
		expect(call.player).toBe(all[3])
		expect(call.value).toBe(2)
	end)

	it("skips a caught player who has left, and logs on the next caught player still here", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(nil, { all[3].UserId, all[2].UserId })
		local call = onlySlam(harness)
		expect(call.player).toBe(all[2])
	end)

	it("logs 'Caught' on the player here longest when every player an empty-meadow slam caught has left", function()
		local harness, all = serverOf(3)
		leave(harness, all[3])
		harness.slammed:Fire(nil, { all[3].UserId })
		local call, result = onlySlam(harness)
		expect(call.player).toBe(all[1])
		expect(call.value).toBe(1)
		expect(result).toBe("Caught")
	end)

	for _, row in { { count = 1, size = "1" }, { count = 4, size = "2-4" }, { count = 5, size = "5-8" } } do
		local count, size = row.count, row.size
		it(`calls a server of {count} players "{size}"`, function()
			local harness, all = serverOf(count)
			harness.slammed:Fire(all[1].UserId, {})
			local _call, _result, logged = onlySlam(harness)
			expect(logged).toBe(size)
		end)
	end

	it("logs nothing when there is no player in the server", function()
		local harness, all = serverOf(2)
		leave(harness, all[1])
		leave(harness, all[2])
		harness.slammed:Fire(nil, {})
		harness.slammed:Fire(all[1].UserId, { all[2].UserId })
		expect(harness.calls).toEqual({})
	end)

	it("logs one event for each slam", function()
		local harness, all = serverOf(2)
		harness.slammed:Fire(all[1].UserId, { all[1].UserId })
		harness.slammed:Fire(all[2].UserId, {})
		harness.slammed:Fire(nil, {})
		expect(#harness.calls).toBe(3)
		expect((harness.calls[1].fields :: any)[FIELD_ONE]).toBe("Caught")
		expect((harness.calls[2].fields :: any)[FIELD_ONE]).toBe("Missed")
		expect((harness.calls[3].fields :: any)[FIELD_ONE]).toBe("Empty")
	end)

	it("goes on and logs the next slam when the service fails", function()
		local harness, all = serverOf(2)
		harness.failing.custom = true
		expect(function()
			harness.slammed:Fire(all[1].UserId, { all[1].UserId })
		end).never.toThrow()
		harness.failing.custom = false
		harness.slammed:Fire(all[2].UserId, {})
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].player).toBe(all[2])
		expect(#harness.warnings).toBe(1)
	end)

	it("logs nothing after stop", function()
		local harness, all = serverOf(2)
		harness.analytics:stop()
		harness.slammed:Fire(all[1].UserId, { all[1].UserId })
		harness.slammed:Fire(nil, {})
		expect(harness.calls).toEqual({})
	end)
end)

describe("Analytics PlayerCaught", function()
	it("logs with value 1 and the lost egg's rarity", function()
		local harness = newHarness()
		local mia = makePlayer(1, 4)
		enter(harness, mia)
		table.clear(harness.calls)
		grab(harness, mia, "Uncommon")
		table.clear(harness.calls)
		catch(harness, mia)
		local events = callsOf(harness, "custom", mia)
		expect(#events).toBe(1)
		expect(events[1].eventName).toBe("PlayerCaught")
		expect(events[1].value).toBe(1)
		expect((events[1].fields :: any)[FIELD_ONE]).toBe("Uncommon")
		expect((events[1].fields :: any)[FIELD_TWO]).toBeNil()
	end)
end)

describe("Analytics when the service fails", function()
	it("goes on and still logs the other events of the same moment", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.failing.onboarding = true
		grab(harness, mia, "Common")
		expect(function()
			bank(harness, mia)
		end).never.toThrow()
		-- Step 3 failed, and EggHome was still logged.
		expect(callsOf(harness, "custom", mia)[1].eventName).toBe("EggHome")
	end)

	it("goes on with a check when the service fails, and logs the next event", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.failing.funnel = true
		expect(function()
			harness.analytics:check({ awayFromHome(mia, 11) })
		end).never.toThrow()
		harness.failing.funnel = false
		grab(harness, mia, "Common")
		expect(#callsOf(harness, "funnel", mia)).toBe(1)
		expect(callsOf(harness, "funnel", mia)[1].step).toBe(2)
	end)

	it("warns once with the method name, not for every failure", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.failing.custom = true
		for _ = 1, 3 do
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		expect(#harness.warnings).toBe(1)
		expect((string.find(harness.warnings[1], "LogCustomEvent", 1, true))).never.toBeNil()
	end)

	it("warns once for each method that fails", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		harness.failing.onboarding = true
		harness.failing.funnel = true
		join(harness, mia)
		spawnCharacter(mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		expect(#harness.warnings).toBe(2)
	end)
end)

describe("Analytics.stop", function()
	it("logs nothing after stop, whatever happens", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		table.clear(harness.calls)
		harness.analytics:stop()
		grab(harness, mia, "Common")
		bank(harness, mia)
		catch(harness, mia)
		harness.woke:Fire("Mia", 1, "Walking")
		harness.analytics:check({ awayFromHome(mia, 50) })
		enter(harness, makePlayer(2, 2))
		spawnCharacter(mia)
		expect(harness.calls).toEqual({})
	end)

	it("removes every connection it made, and can be called twice", function()
		local mia = makePlayer(1, 1)
		local harness = newHarness({ mia })
		expect(#harness.playerAdded:GetConnections()).toBe(1)
		expect(#harness.playerRemoving:GetConnections()).toBe(1)
		expect(#harness.grabbed:GetConnections()).toBe(1)
		expect(#harness.banked:GetConnections()).toBe(1)
		expect(#harness.caught:GetConnections()).toBe(1)
		expect(#harness.woke:GetConnections()).toBe(1)
		expect(#harness.slammed:GetConnections()).toBe(1)
		expect(#mia.CharacterAdded:GetConnections()).toBe(1)
		harness.analytics:stop()
		harness.analytics:stop()
		expect(#harness.playerAdded:GetConnections()).toBe(0)
		expect(#harness.playerRemoving:GetConnections()).toBe(0)
		expect(#harness.grabbed:GetConnections()).toBe(0)
		expect(#harness.banked:GetConnections()).toBe(0)
		expect(#harness.caught:GetConnections()).toBe(0)
		expect(#harness.woke:GetConnections()).toBe(0)
		expect(#harness.slammed:GetConnections()).toBe(0)
		expect(#mia.CharacterAdded:GetConnections()).toBe(0)
	end)

	it("removes a player's character connection when the player leaves", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		expect(#mia.CharacterAdded:GetConnections()).toBe(1)
		leave(harness, mia)
		expect(#mia.CharacterAdded:GetConnections()).toBe(0)
	end)
end)
