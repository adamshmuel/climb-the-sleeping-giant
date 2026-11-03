--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Analytics = require(ServerScriptService.Server.Analytics)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)

-- The three breakdown slots Roblox gives a custom event. Which one means what depends on the event.
local FIELD_ONE = Enum.AnalyticsCustomFieldKeys.CustomField01.Name

local FIELD_TWO = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local FIELD_THREE = Enum.AnalyticsCustomFieldKeys.CustomField03.Name

-- Everything the fake AnalyticsService was asked to log, in order.
export type Call = {
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

export type FakePlayer = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Character: any,
	CharacterAdded: Signal.Signal<any>,
	attributes: { [string]: any },
	GetAttribute: (self: any, name: string) -> any,
}

export type Harness = {
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
	saved: Signal.Signal<number, Config.ZoneName>,
	returned: Signal.Signal<any, any, string>,
	unstuck: Signal.Signal<any, string, string>, -- (player, how, zone)
	idsMade: number,
}

local OWN_GARDEN_SPAWN_X = 100 -- garden N's spawn spot is at X = N * 100, Z = 0, so every garden is far from the others

local made: { Harness } = {}

local players: { FakePlayer } = {}

local function cleanUp()
	for _, harness in made do
		harness.analytics:stop()
		harness.playerAdded:Destroy()
		harness.playerRemoving:Destroy()
		harness.grabbed:Destroy()
		harness.banked:Destroy()
		harness.caught:Destroy()
		harness.woke:Destroy()
		harness.slammed:Destroy()
		harness.saved:Destroy()
		harness.returned:Destroy()
		harness.unstuck:Destroy()
	end
	table.clear(made)
	for _, player in players do
		player.CharacterAdded:Destroy()
	end
	table.clear(players)
end

-- A player with a garden number (nil for none). Attributes are plain values, and the character is not there yet.
local function makePlayer(userId: number, plotIndex: number?): FakePlayer
	local player: FakePlayer = {
		UserId = userId,
		Name = `Player{userId}`,
		DisplayName = `Player{userId}`,
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
		saved = Signal.new(),
		returned = Signal.new(),
		unstuck = Signal.new(),
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
		saved = harness.saved,
		returned = harness.returned,
		unstuck = harness.unstuck,
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

return {
	FIELD_ONE = FIELD_ONE,
	FIELD_TWO = FIELD_TWO,
	FIELD_THREE = FIELD_THREE,
	OWN_GARDEN_SPAWN_X = OWN_GARDEN_SPAWN_X,
	awayFromHome = awayFromHome,
	bank = bank,
	callsOf = callsOf,
	catch = catch,
	cleanUp = cleanUp,
	enter = enter,
	grab = grab,
	join = join,
	leave = leave,
	makePlayer = makePlayer,
	newHarness = newHarness,
	players = players,
	sampleOf = sampleOf,
	serverOf = serverOf,
	spawnCharacter = spawnCharacter,
}
