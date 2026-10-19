--!strict
-- Logs the analytics events from spec section 10 ("Success signals"): records Roblox keeps of what players do, shown as
-- charts on the Creator Dashboard. It listens to the other modules (grabbed, banked, caught, woke, slammed), watches players
-- arrive and leave, and reads every player's place on the giant's tick, so no game module needs to know it exists.
-- Events are only sent from a published game's server; in Studio, Roblox prints one "event fired" line per call and
-- sends nothing.
-- Nothing a client sends is read: every value comes from the server's own signals and attributes.
-- Everything it touches is passed in, so a test can give it a fake AnalyticsService, fake players and real Signals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local PlayerInfo = require(script.Parent.Players.PlayerInfo)
local PlayerTracker = require(script.Parent.Players.PlayerTracker)

-- A Roblox event or a Signal, as far as Analytics uses it. (The connection it returns is typed `any`, because the checker
-- doesn't accept a connection with more fields than a narrow stand-in; Trove only needs to disconnect it.)
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> any,
}

-- What Analytics needs from AnalyticsService: only the three methods it calls. The real service fits, and tests pass
-- a fake that records every call.
export type ServiceLike = {
	LogOnboardingFunnelStepEvent: (self: any, player: any, step: number, stepName: string) -> (),
	LogFunnelStepEvent: (
		self: any,
		player: any,
		funnelName: string,
		funnelSessionId: string,
		step: number,
		stepName: string
	) -> (),
	LogCustomEvent: (
		self: any,
		player: any,
		eventName: string,
		value: number?,
		customFields: { [string]: string }?
	) -> (),
}

-- What Analytics needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Character: any,
	CharacterAdded: SignalLike,
	GetAttribute: (self: any, name: string) -> any,
}

export type PlayersLike = {
	PlayerAdded: SignalLike,
	PlayerRemoving: SignalLike,
	GetPlayers: (self: any) -> { PlayerLike },
	GetPlayerByUserId: (self: any, userId: number) -> PlayerLike?,
}

-- A garden's number and where its spawn spot is.
export type GardenSpot = {
	index: number,
	spawnPosition: Vector3,
}

export type Deps = {
	service: ServiceLike,
	players: PlayersLike,
	grabbed: SignalLike, -- Grab's signal: (player, rarity) after a successful grab
	banked: SignalLike, -- Banking's signal: (player, rarity) after EggsHome went up
	caught: SignalLike, -- Catcher's signal: (player, rarity of the lost egg)
	woke: SignalLike, -- the director's signal: (display name, waker's UserId or nil, cause)
	slammed: SignalLike, -- the director's signal: (UserId the slam was aimed at or nil, UserIds it caught) as the hand lands
	saved: SignalLike, -- the director's signal: (UserId, zone) when a player's free save is spent
	returned: SignalLike, -- Grab's signal: (player, rarity, "Caught" or "Lost") when a carried egg goes back
	gardens: { GardenSpot },
	now: () -> number, -- os.clock; it tells who has been in the server longest
	newId: () -> string, -- makes the session id of one heist (HttpService:GenerateGUID(false))
	warn: ((message: string) -> ())?, -- where a failed call is reported; the global warn if left out
}

export type Analytics = {
	-- One tick of the giant (after Banking's check): opens a heist for a player who left the garden, and ends one whose
	-- egg is gone.
	check: (self: Analytics, samples: { PlayerTracker.Sample }) -> (),
	-- Removes every connection. Safe to call twice.
	stop: (self: Analytics) -> (),
}

-- The onboarding funnel (Roblox's chart of how many new players reach each first step). Roblox keeps each player's first
-- time at each step. The step numbers and names are the spec's.
local ONBOARDING_SPAWNED = 1
local ONBOARDING_SPAWNED_NAME = "Spawned"
local ONBOARDING_GRABBED = 2
local ONBOARDING_GRABBED_NAME = "First egg grabbed"
local ONBOARDING_FIRST_HOME = 3
local ONBOARDING_FIRST_HOME_NAME = "First egg home"
local ONBOARDING_SECOND_HOME = 4
local ONBOARDING_SECOND_HOME_NAME = "Second egg home"
local ONBOARDING_FIRST_UNCOMMON = 5
local ONBOARDING_FIRST_UNCOMMON_NAME = "First Uncommon home"
local ONBOARDING_FIRST_RARE = 6
local ONBOARDING_FIRST_RARE_NAME = "First Rare home"

-- The "Heist" funnel: one run from leaving the garden to bringing an egg home. The funnel name is the chart's title.
local HEIST_FUNNEL = "Heist"
local HEIST_LEFT_GARDEN = 1
local HEIST_LEFT_GARDEN_NAME = "Left garden"
local HEIST_GRABBED = 2
local HEIST_GRABBED_NAME = "Grabbed"
local HEIST_HOME = 3
local HEIST_HOME_NAME = "Home"

-- Studs across the ground (height ignored) from their own spawn spot before a player without an egg counts as having left
-- the garden. The spawn spot is itself outside the garden box, so standing on it must not count.
local LEFT_GARDEN_STUDS = 10

-- The custom events. Each has up to three breakdown slots, and the slots mean different things on different events:
--   "EggHome":        CustomField01 = the egg's rarity, CustomField02 = the garden number ("1" to "8").
--   "PlayerCaught":   CustomField01 = the lost egg's rarity (no other slot).
--   "GiantWoke":      CustomField01 = the server size ("1", "2-4" or "5-8"), CustomField02 = what filled the meter,
--                     CustomField03 = who woke him ("New" = no Rare home yet, "Veteran", or "Nobody" if nobody can be named).
--   "Slam":           CustomField01 = the result ("Caught", "Missed" or "Empty"), CustomField02 = the server size.
--   "FreeSaveUsed":   CustomField01 = where ("Boots", "Belly" or "Higher"; "Meadow" would be a bug), CustomField02 = the
--                     player's eggs home ("0", "1" or "2+"), CustomField03 = the egg they carried ("None" or its rarity).
--   "FreeSaveResult": CustomField01 = how that egg's heist ended ("Home", "Woke him", "Caught" or "Lost"), valued at the
--                     seconds since the save (no other slot).
-- So never read one chart's slot as another's.
local FIELD_ONE = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local FIELD_TWO = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local FIELD_THREE = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local EVENT_EGG_HOME = "EggHome"
local EVENT_GIANT_WOKE = "GiantWoke"
local EVENT_PLAYER_CAUGHT = "PlayerCaught"
local EVENT_SLAM = "Slam" -- one per hand slam, valued at the number of players it caught
local EVENT_FREE_SAVE_USED = "FreeSaveUsed" -- one per free save
local EVENT_FREE_SAVE_RESULT = "FreeSaveResult" -- one per save by a carrier, valued at the seconds since the save
-- Every event of these counts once, so the value is 1 (except "GiantWoke", valued at the number of players, "Slam",
-- valued at the number of players it caught, and "FreeSaveResult", valued at the seconds since the save).
local EVENT_VALUE = 1

-- "GiantWoke" server sizes, from the number of players. The spec's three buckets.
local SIZE_ONE = "1"
local SIZE_SMALL = "2-4"
local SIZE_FULL = "5-8"
local SMALL_FROM = 2
local FULL_FROM = 5

-- What "GiantWoke" says when nobody can be named, so the wake is still counted.
local CAUSE_WAKER_LEFT = "Waker left"

-- Who woke him, for the third "GiantWoke" slot.
local WAKER_NEW = "New" -- no Rare home yet: still a new player
local WAKER_VETERAN = "Veteran"
local WAKER_NOBODY = "Nobody" -- nobody can be named, or the waker left

-- "FreeSaveUsed": where the save happened. The Beard and the Nightcap are both "Higher".
local WHERE_HIGHER = "Higher"
local whereByZone: { [string]: string } = {
	Boots = "Boots",
	Belly = "Belly",
	Beard = WHERE_HIGHER,
	Nightcap = WHERE_HIGHER,
}
-- "FreeSaveUsed": the player's eggs home, in the spec's three buckets, and what they carried when they carried nothing.
local EGGS_NONE = "0"
local EGGS_ONE = "1"
local EGGS_TWO_OR_MORE = "2+"
local CARRYING_NONE = "None"

-- "FreeSaveResult": how the saved egg's heist ended.
local RESULT_HOME = "Home"
local RESULT_WOKE_HIM = "Woke him"
local RESULT_CAUGHT = "Caught"
local RESULT_LOST = "Lost"

-- What a "Slam" did, as the chart's result breakdown says it.
-- It caught at least one carrier, whoever it was aimed at (this is the number the success target counts):
local SLAM_CAUGHT = "Caught"
-- It was aimed at a carrier and caught nobody (the carrier ran, or the circle was dodged):
local SLAM_MISSED = "Missed"
-- It was aimed at nobody (no carrier was outside the gardens) and caught nobody, so it is left out of the success target:
local SLAM_EMPTY = "Empty"

-- The names of the three service methods, for the warning when one fails.
local METHOD_ONBOARDING = "LogOnboardingFunnelStepEvent"
local METHOD_FUNNEL = "LogFunnelStepEvent"
local METHOD_CUSTOM = "LogCustomEvent"

-- One heist that is open: its session id, and the last step logged (1, 2 or 3).
type Heist = { id: string, step: number }

-- Everything remembered about one player this visit. It is made when they arrive and dropped when they leave.
type Record = {
	player: PlayerLike,
	joinedAt: number, -- os.clock when Analytics saw them arrive
	joinOrder: number, -- breaks a tie between two arrivals at the same time
	onboardingDone: { [number]: boolean }, -- the onboarding steps already logged
	heist: Heist?,
	savedAt: number?, -- os.clock at a save by a carrier whose "FreeSaveResult" is not logged yet
	cleanup: () -> (),
}

local Analytics = {}

-- The "GiantWoke" server size for this many players.
function Analytics.serverSize(playerCount: number): string
	if playerCount >= FULL_FROM then
		return SIZE_FULL
	elseif playerCount >= SMALL_FROM then
		return SIZE_SMALL
	end
	return SIZE_ONE
end

-- A number from a player's attribute, or nil if it holds anything else.
local function numberFrom(value: any): number?
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

function Analytics.start(deps: Deps): Analytics
	local service = deps.service
	local players = deps.players
	local warnFn: (message: string) -> () = deps.warn or warn
	local trove = Trove.new()
	local stopped = false

	local records: { [number]: Record } = {}
	local arrivals = 0

	-- Where each garden's spawn spot is, by garden number.
	local spawnPositions: { [number]: Vector3? } = {}
	for _, garden in deps.gardens do
		spawnPositions[garden.index] = garden.spawnPosition
	end

	-- A call into the service that errors must not break the game: it is caught, and warned about once per method.
	local warned: { [string]: boolean } = {}
	local function safely(methodName: string, call: () -> ())
		local ok, problem = pcall(call :: () -> any)
		if not ok and not warned[methodName] then
			warned[methodName] = true
			warnFn(`[Analytics] {methodName} failed: {tostring(problem)}`)
		end
	end

	local function logOnboarding(record: Record, step: number, stepName: string)
		if record.onboardingDone[step] then
			return
		end
		record.onboardingDone[step] = true
		safely(METHOD_ONBOARDING, function()
			service:LogOnboardingFunnelStepEvent(record.player, step, stepName)
		end)
	end

	local function logHeistStep(record: Record, heist: Heist, step: number, stepName: string)
		heist.step = step
		safely(METHOD_FUNNEL, function()
			service:LogFunnelStepEvent(record.player, HEIST_FUNNEL, heist.id, step, stepName)
		end)
	end

	local function logCustom(player: PlayerLike, eventName: string, value: number, fields: { [string]: string })
		safely(METHOD_CUSTOM, function()
			service:LogCustomEvent(player, eventName, value, fields)
		end)
	end

	local function openHeist(): Heist
		return { id = deps.newId(), step = 0 }
	end

	-- Is this player carrying an egg right now? Their Carrying attribute is set by Grab and cleared by Grab.
	local function carries(player: PlayerLike): boolean
		return player:GetAttribute("Carrying") ~= nil
	end

	local function onSpawned(record: Record)
		logOnboarding(record, ONBOARDING_SPAWNED, ONBOARDING_SPAWNED_NAME)
	end

	local function watchPlayer(player: PlayerLike)
		if records[player.UserId] ~= nil then
			return -- already watched
		end
		arrivals += 1
		local playerTrove = Trove.new()
		local record: Record = {
			player = player,
			joinedAt = deps.now(),
			joinOrder = arrivals,
			onboardingDone = {},
			heist = nil,
			savedAt = nil,
			cleanup = function()
				playerTrove:Destroy()
			end,
		}
		records[player.UserId] = record
		playerTrove:Add(player.CharacterAdded:Connect(function()
			if not stopped then
				onSpawned(record)
			end
		end))
		if player.Character ~= nil then
			onSpawned(record)
		end
	end

	-- Ends the open "FreeSaveResult" of this player (if there is one) with this outcome. The first outcome closes it, so
	-- nothing later logs again.
	local function closeFreeSave(record: Record, outcome: string)
		local savedAt = record.savedAt
		if savedAt == nil then
			return
		end
		record.savedAt = nil
		logCustom(record.player, EVENT_FREE_SAVE_RESULT, deps.now() - savedAt, { [FIELD_ONE] = outcome })
	end

	local function forgetPlayer(player: PlayerLike)
		local record = records[player.UserId]
		if record ~= nil then
			-- Banking sends the egg back on leaving too, but its handler may run after this one, so a still-open result
			-- ends here as lost.
			closeFreeSave(record, RESULT_LOST)
			records[player.UserId] = nil
			record.cleanup()
		end
	end

	trove:Add(players.PlayerAdded:Connect(function(player: PlayerLike)
		if not stopped then
			watchPlayer(player)
		end
	end))
	trove:Add(players.PlayerRemoving:Connect(function(player: PlayerLike)
		forgetPlayer(player)
	end))
	trove:Add(function()
		for userId, record in records do
			records[userId] = nil
			record.cleanup()
		end
	end)
	for _, player in players:GetPlayers() do
		watchPlayer(player)
	end

	trove:Add(deps.grabbed:Connect(function(player: PlayerLike, _rarity: Config.RarityName)
		local record = records[player.UserId]
		if stopped or record == nil then
			return
		end
		logOnboarding(record, ONBOARDING_GRABBED, ONBOARDING_GRABBED_NAME)
		-- A grab with a heist still open at step 2 or later means the earlier egg was lost without a check noticing.
		local open = record.heist
		local heist: Heist = if open == nil or open.step >= HEIST_GRABBED then openHeist() else open
		record.heist = heist
		logHeistStep(record, heist, HEIST_GRABBED, HEIST_GRABBED_NAME)
	end))

	trove:Add(deps.banked:Connect(function(player: PlayerLike, rarity: Config.RarityName)
		local record = records[player.UserId]
		if stopped or record == nil then
			return
		end
		-- Banking has already raised EggsHome, so 1 is the first egg home and 2 the second.
		local eggsHome = numberFrom(player:GetAttribute("EggsHome"))
		if eggsHome == 1 then
			logOnboarding(record, ONBOARDING_FIRST_HOME, ONBOARDING_FIRST_HOME_NAME)
		elseif eggsHome == 2 then
			logOnboarding(record, ONBOARDING_SECOND_HOME, ONBOARDING_SECOND_HOME_NAME)
		end
		if rarity == "Uncommon" then
			logOnboarding(record, ONBOARDING_FIRST_UNCOMMON, ONBOARDING_FIRST_UNCOMMON_NAME)
		elseif Rarity.isRareOrRarer(rarity) then
			logOnboarding(record, ONBOARDING_FIRST_RARE, ONBOARDING_FIRST_RARE_NAME)
		end
		closeFreeSave(record, RESULT_HOME)

		local heist = record.heist
		if heist ~= nil then
			record.heist = nil
			logHeistStep(record, heist, HEIST_HOME, HEIST_HOME_NAME)
		end

		local fields: { [string]: string } = { [FIELD_ONE] = rarity }
		local garden = numberFrom(player:GetAttribute("PlotIndex"))
		if garden ~= nil then
			fields[FIELD_TWO] = tostring(garden)
		end
		logCustom(player, EVENT_EGG_HOME, EVENT_VALUE, fields)
	end))

	-- A carried egg went back. Catcher gives the reason "Caught" before it fires `caught`, so a catch is never taken for a
	-- lost egg, whichever handler runs first.
	trove:Add(deps.returned:Connect(function(player: PlayerLike, _rarity: Config.RarityName, why: string)
		local record = records[player.UserId]
		if stopped or record == nil then
			return
		end
		closeFreeSave(record, if why == "Caught" then RESULT_CAUGHT else RESULT_LOST)
	end))

	-- A free save was spent. Everything is read now, from the server's own attributes: where they were, their eggs home
	-- and what they carry. A save by a carrier also opens the "FreeSaveResult" that the egg's heist will close.
	trove:Add(deps.saved:Connect(function(userId: number, zone: string)
		local record = records[userId]
		if stopped or record == nil then
			return
		end
		local player = record.player
		local eggsHome = numberFrom(player:GetAttribute("EggsHome")) or 0
		local eggsBucket = if eggsHome >= 2 then EGGS_TWO_OR_MORE elseif eggsHome == 1 then EGGS_ONE else EGGS_NONE
		local carrying = PlayerInfo.fromPlayer(player).carrying
		logCustom(player, EVENT_FREE_SAVE_USED, EVENT_VALUE, {
			[FIELD_ONE] = whereByZone[zone] or zone,
			[FIELD_TWO] = eggsBucket,
			[FIELD_THREE] = carrying or CARRYING_NONE,
		})
		-- A second save would replace the open one (the spec gives each player one save).
		record.savedAt = if carrying ~= nil then deps.now() else nil
	end))

	trove:Add(deps.caught:Connect(function(player: PlayerLike, rarity: Config.RarityName)
		local record = records[player.UserId]
		if stopped or record == nil then
			return
		end
		record.heist = nil
		logCustom(player, EVENT_PLAYER_CAUGHT, EVENT_VALUE, { [FIELD_ONE] = rarity })
	end))

	-- The player who has been in the server longest: the earliest arrival Analytics saw. Players already there when it
	-- started count in GetPlayers order, because they all arrived in that one pass.
	local function longestInServer(): PlayerLike?
		local best: Record? = nil
		for _, record in records do
			if
				best == nil
				or record.joinedAt < best.joinedAt
				or (record.joinedAt == best.joinedAt and record.joinOrder < best.joinOrder)
			then
				best = record
			end
		end
		if best == nil then
			return nil
		end
		return best.player
	end

	trove:Add(deps.woke:Connect(function(_name: string, wokenBy: number?, cause: string)
		if stopped then
			return
		end
		local count = #players:GetPlayers()
		if count == 0 then
			return
		end
		local waker: PlayerLike? = nil
		if wokenBy ~= nil then
			waker = players:GetPlayerByUserId(wokenBy)
		end
		local reported = cause
		local who = WAKER_NOBODY
		if waker == nil then
			-- Nobody can be named, or the waker is gone: the player here longest carries it, so no wake goes missing.
			waker = longestInServer()
			reported = CAUSE_WAKER_LEFT
		else
			who = if PlayerInfo.fromPlayer(waker).rareHome then WAKER_VETERAN else WAKER_NEW
			-- The waker's own noise woke him, so a save they were carrying on ends here.
			local wakerRecord = records[waker.UserId]
			if wakerRecord ~= nil then
				closeFreeSave(wakerRecord, RESULT_WOKE_HIM)
			end
		end
		if waker == nil then
			return
		end
		logCustom(waker, EVENT_GIANT_WOKE, count, {
			[FIELD_ONE] = Analytics.serverSize(count),
			[FIELD_TWO] = reported,
			[FIELD_THREE] = who,
		})
	end))

	-- "Slam": once per slam, as the hand lands. The result comes from what the hand did. It is logged on the target, if
	-- they are still here; otherwise on the first caught player still here (an empty-meadow slam that a carrier walked
	-- under), otherwise on the player who has been here longest, so no slam goes missing.
	trove:Add(deps.slammed:Connect(function(target: number?, caught: { number })
		if stopped then
			return
		end
		local count = #players:GetPlayers()
		if count == 0 then
			return
		end
		local result = SLAM_EMPTY
		if #caught > 0 then
			result = SLAM_CAUGHT
		elseif target ~= nil then
			result = SLAM_MISSED
		end
		local logOn: PlayerLike? = nil
		if target ~= nil then
			logOn = players:GetPlayerByUserId(target)
		else
			for _, userId in caught do
				logOn = players:GetPlayerByUserId(userId)
				if logOn ~= nil then
					break
				end
			end
		end
		if logOn == nil then
			logOn = longestInServer()
		end
		if logOn == nil then
			return
		end
		logCustom(logOn, EVENT_SLAM, #caught, {
			[FIELD_ONE] = result,
			[FIELD_TWO] = Analytics.serverSize(count),
		})
	end))

	-- Has this player left the garden for a heist? They must be outside their own garden and more than
	-- LEFT_GARDEN_STUDS across the ground from their own spawn spot.
	local function hasLeftGarden(record: Record, sample: PlayerTracker.Sample): boolean
		local plotIndex = numberFrom(record.player:GetAttribute("PlotIndex"))
		if plotIndex == nil or sample.garden == plotIndex then
			return false
		end
		local spawnPosition = spawnPositions[plotIndex]
		if spawnPosition == nil then
			return false
		end
		local across = Vector3.new(sample.position.X - spawnPosition.X, 0, sample.position.Z - spawnPosition.Z)
		return across.Magnitude > LEFT_GARDEN_STUDS
	end

	local function check(_self: Analytics, samples: { PlayerTracker.Sample })
		if stopped then
			return
		end
		for _, sample in samples do
			local record = records[sample.userId]
			if record ~= nil then
				local carrying = carries(record.player)
				local heist = record.heist
				-- An egg that is gone without a catch or banking (the carrier died) ends the heist.
				if heist ~= nil and heist.step >= HEIST_GRABBED and not carrying then
					record.heist = nil
					heist = nil
				end
				if heist == nil and not carrying and hasLeftGarden(record, sample) then
					local opened = openHeist()
					record.heist = opened
					logHeistStep(record, opened, HEIST_LEFT_GARDEN, HEIST_LEFT_GARDEN_NAME)
				end
			end
		end
	end

	local function stop(_self: Analytics)
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end

	return { check = check, stop = stop }
end

return Analytics
