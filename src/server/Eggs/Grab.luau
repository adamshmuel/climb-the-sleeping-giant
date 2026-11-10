--!strict
-- Grabbing eggs. Every egg spot (a nest) gets a hold prompt ("Hold to Grab"), on only while the nest's egg waits. When
-- a player's hold finishes, the server checks it again itself (a player's own device can't be trusted), and the first
-- player to pass gets the egg.
-- This module is the one owner of the EggSlots state: it runs the refills (an egg returns to a random clear nest of its
-- rank, Rules 70 to 78), and it gives later tasks (banking, catches, leaving) one place to return or bank an egg.
-- Everything it touches is passed in, so a test can give it fake spots, players, remotes and a fake clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local GiantDirector = require(script.Parent.Parent.Giant.GiantDirector)
local RateLimiter = require(script.Parent.Parent.Remotes.RateLimiter)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)
local Carry = require(script.Parent.Carry)
local EggSlots = require(script.Parent.EggSlots)
local SpotModels = require(script.Parent.SpotModels)

-- What Grab needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	Character: Model?,
	SetAttribute: (self: any, name: string, value: any) -> (),
}

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (any) -> ()) -> ConnectionLike,
}

-- A hold prompt as Grab uses it: the event for a finished hold, whether it shows (on while the nest's egg waits), and a
-- way to remove it.
export type PromptLike = {
	Triggered: SignalLike,
	Enabled: boolean,
	Destroy: (self: any) -> (),
}

-- Why an egg went back: a hand slam caught the carrier, or anything else (they died, reset or left).
export type ReturnReason = "Caught" | "Lost"

export type Deps = {
	spots: { WorldIndex.EggSpot },
	templates: WorldIndex.EggTemplates,
	-- How the egg sits on the back: from the root part to the egg's centre, and how tall it is (Carry.attachEgg).
	carriedOffset: CFrame,
	carriedHeight: number,
	-- PlayerRemoving: a player who leaves is forgotten.
	-- GetPlayers: where everyone stands, so a refill keeps clear of them.
	players: { PlayerRemoving: SignalLike, GetPlayers: (self: any) -> { PlayerLike } },
	-- How many eggs of each rank wait at once. Left out, Grab.slotsFor works it out from the spots.
	slotsPerRank: { [Config.RarityName]: number }?,
	-- Picks the nest of a refill. Left out, Random.new().
	random: Random?,
	-- Heartbeat, or a stand-in in tests. It drives the refill checks.
	heartbeat: GiantDirector.HeartbeatLike,
	-- Tells one player that someone else got the egg first (the GrabMissed remote).
	grabMissed: (player: PlayerLike) -> (),
	-- The shared server clock in seconds (Workspace:GetServerTimeNow()), so clients can read RefillAt as it is.
	now: () -> number,
	-- Makes the prompt on one anchor. Left out, Grab.createPrompt makes the real one; tests pass a fake.
	createPrompt: ((anchor: Attachment, rarity: Config.RarityName) -> PromptLike)?,
	-- The giant's phase, read on every step: the right cuff nests lock while it is Awake (Rule 100). Left out, it is
	-- always "Asleep" (nothing locks).
	phase: (() -> Config.Phase)?,
}

export type Grab = {
	-- Puts the player's carried egg back on its own nest (see EggSlots.returnEgg), takes it off their back and
	-- clears their Carrying attribute. Returns what happened and the nest's name, or nil if they carry nothing.
	-- `why` says why it went back ("Caught" for a hand slam; left out, it is "Lost") and goes to the `returned` signal.
	returnEgg: (self: Grab, player: PlayerLike, why: ReturnReason?) -> (("back" | "gone")?, string?),
	-- The player's carried egg leaves the world for their garden (see EggSlots.bank): it comes off their back and
	-- Carrying is cleared, but the egg's slot keeps counting down. Returns the nest's name and the egg's rarity, or nil.
	bank: (self: Grab, player: PlayerLike) -> (string?, Config.RarityName?),
	-- Fires after a grab succeeds (Carrying is set by then), with the player and the egg's rarity.
	-- Analytics listens to it.
	grabbed: Signal.Signal<PlayerLike, Config.RarityName>,
	-- Fires when a carried egg really went back (not when it was banked, and not for a player who carried nothing), after
	-- it is off their back: the player, the egg's rarity and why. Analytics listens to it.
	returned: Signal.Signal<PlayerLike, Config.RarityName, ReturnReason>,
	-- Fires once per refill, after the egg shows on its nest: the egg's rarity and how many seconds the refill waited
	-- after its countdown ended (0 on time, more when no nest was clear).
	refilled: Signal.Signal<Config.RarityName, number>,
	-- Notes that one of his fists just landed (the director's `slammed`). The right cuff nests stay locked for
	-- Config.Nests.ArmReturnSeconds after it, while his arm swings back.
	noteFist: (self: Grab) -> (),
	-- One refill check, and the lock check of the right cuff nests. The heartbeat calls it every 0.1 s; tests call it by
	-- hand.
	step: (self: Grab) -> (),
	-- Removes the prompts, the eggs on the spots and on backs, and every connection. Safe to call twice.
	stop: (self: Grab) -> (),
}

-- At most this many grabs per second from one player. A finished hold takes a second, so this is plenty,
-- and it keeps a cheater's flood of messages from costing the server anything.
local GRABS_PER_SECOND = 5
-- How often the refills are checked, in seconds, and the most checks one frame may run when the server lags.
local REFILL_CHECK_SECONDS = 0.1
local MAX_CHECKS_PER_FRAME = 3

local Grab = {}

-- How many eggs of each rank wait at once: Config.Rarity[rank].Slots. A rank with a bare spot (no nest part yet)
-- gets at most its spot count minus 1, so a refill always has a free nest besides the last one; a rank with no spots
-- gets 0. Task 12 removes the bare-spot allowance.
function Grab.slotsFor(spots: { WorldIndex.EggSpot }): { [Config.RarityName]: number }
	local counts: { [string]: number } = {}
	local hasBare: { [string]: boolean } = {}
	for _, spot in spots do
		counts[spot.rarity] = (counts[spot.rarity] or 0) + 1
		if spot.nest == nil then
			hasBare[spot.rarity] = true
		end
	end
	local slots: { [Config.RarityName]: number } = {}
	local ranks = Config.RarityOrder :: { Config.RarityName }
	for _, rank: Config.RarityName in ranks do
		local count = counts[rank] or 0
		local wanted = Config.Rarity[rank].Slots
		if count == 0 then
			wanted = 0
		elseif hasBare[rank] then
			wanted = math.min(wanted, count - 1)
		end
		slots[rank] = wanted
	end
	return slots
end

-- Is this grab allowed? `distance` is how far the player's root part is from the egg's prompt anchor
-- (math.huge if they have no root part). Returns true, or false and why: "dead", "too far" or "already carrying".
function Grab.check(alive: boolean, distance: number, carrying: boolean): (boolean, string?)
	if not alive then
		return false, "dead"
	end
	-- "not (a <= b)" also refuses NaN. The reach plus the lag allowance is the most the server accepts.
	if not (distance <= Config.Grab.ReachStuds + Config.Grab.ReachToleranceStuds) then
		return false, "too far"
	end
	if carrying then
		return false, "already carrying"
	end
	return true, nil
end

-- Makes the real hold prompt on an egg spot's anchor.
function Grab.createPrompt(anchor: Attachment, rarity: Config.RarityName): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = Config.Grab.HoldSeconds
	prompt.MaxActivationDistance = Config.Grab.ReachStuds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.ActionText = "Hold to Grab"
	prompt.ObjectText = `{rarity} egg`
	-- Our own look is drawn on every client (Hud/GrabPrompt), so Roblox draws nothing.
	prompt.Style = Enum.ProximityPromptStyle.Custom
	-- The egg itself stands in the line of sight to the anchor, so the line check would hide the prompt.
	-- The server checks the distance anyway.
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return prompt
end

-- Starts grabbing: shows an egg on every spot, puts a prompt on every anchor and starts the refill checks.
function Grab.start(deps: Deps): Grab
	-- The real ProximityPrompt fits PromptLike, but the checker can't see that through its event type.
	local createPrompt: (Attachment, Config.RarityName) -> PromptLike = deps.createPrompt or Grab.createPrompt :: any
	local trove = Trove.new()
	local stopped = false

	local definitions: { EggSlots.NestDefinition } = {}
	for _, spot in deps.spots do
		table.insert(
			definitions,
			{ name = spot.name, rank = spot.rarity, position = spot.cframe.Position, garden = spot.garden }
		)
	end
	local state = EggSlots.new(definitions, deps.slotsPerRank or Grab.slotsFor(deps.spots))
	local random = deps.random or Random.new()
	local function pick(count: number): number
		return random:NextInteger(1, count)
	end
	-- Each nest's prompt by name: on while the nest's egg waits, off while it is empty.
	local prompts: { [string]: PromptLike } = {}
	-- The nests on his right cuff, and whether they are locked now. A locked nest keeps its egg but its prompt is off.
	local cuffSpots: { WorldIndex.EggSpot } = {}
	for _, spot in deps.spots do
		if spot.ridesRightArm == true then
			table.insert(cuffSpots, spot)
		end
	end
	local cuffNames: { string } = {}
	for _, spot in cuffSpots do
		table.insert(cuffNames, spot.name)
	end
	local cuffLocked = false
	-- The lock's clock: whether the last step saw him Awake, when a step first saw him leave Awake, and the last fist.
	local sawAwake = false
	local leftAwakeAt: number? = nil
	local lastFistAt: number? = nil
	local spotModels = SpotModels.new(deps.spots, deps.templates)
	trove:Add(function()
		spotModels:destroy()
	end)
	local grabbed = Signal.new() :: Signal.Signal<PlayerLike, Config.RarityName>
	trove:Add(function()
		grabbed:Destroy()
	end)
	local returned = Signal.new() :: Signal.Signal<PlayerLike, Config.RarityName, ReturnReason>
	trove:Add(function()
		returned:Destroy()
	end)
	local refilled = Signal.new() :: Signal.Signal<Config.RarityName, number>
	trove:Add(function()
		refilled:Destroy()
	end)
	-- Each spot's rarity by name, so the egg that went back can be named (the server's own list, never the client's).
	local rarityOfSpot: { [string]: Config.RarityName } = {}
	for _, spot in deps.spots do
		rarityOfSpot[spot.name] = spot.rarity
	end
	local limiter = RateLimiter.new(GRABS_PER_SECOND, 1, deps.now)
	-- Everyone who carries an egg right now, so stop() can take every egg off every back.
	local carriers: { [number]: PlayerLike } = {}

	-- A nest's prompt is on only while its egg waits and the nest isn't locked.
	local function refreshPrompt(nestName: string)
		local view = EggSlots.nest(state, nestName) :: EggSlots.NestView
		prompts[nestName].Enabled = view.waiting and not view.locked
	end

	local function takeEggOffBack(player: PlayerLike)
		carriers[player.UserId] = nil
		player:SetAttribute("Carrying", nil)
		local character = player.Character
		if character ~= nil then
			Carry.detachEgg(character)
		end
	end
	trove:Add(function()
		for _, player in carriers do
			takeEggOffBack(player)
		end
	end)

	-- A player's finished hold on one spot.
	local function onTriggered(spot: WorldIndex.EggSpot, player: PlayerLike)
		if not limiter:allow(player.UserId) then
			return
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local alive = humanoid ~= nil and humanoid.Health > 0
		local distance = math.huge
		if root ~= nil and root:IsA("BasePart") then
			distance = (root.Position - spot.promptAnchor.WorldPosition).Magnitude
		end
		local carrying = EggSlots.carrying(state, player.UserId) ~= nil
		local ok = Grab.check(alive, distance, carrying)
		if not ok or character == nil then
			return
		end

		local taken, reason = EggSlots.take(state, spot.name, player.UserId, deps.now())
		if not taken then
			if reason == "no egg" then
				deps.grabMissed(player)
			end
			return
		end
		spotModels:hide(spot.name)
		prompts[spot.name].Enabled = false
		carriers[player.UserId] = player
		player:SetAttribute("Carrying", spot.rarity)
		Carry.attachEgg(character, deps.templates[spot.rarity], deps.carriedOffset, deps.carriedHeight)
		grabbed:Fire(player, spot.rarity)
	end

	for _, spot in deps.spots do
		local waiting = (EggSlots.nest(state, spot.name) :: EggSlots.NestView).waiting
		if waiting then
			spotModels:show(spot.name)
		else
			spotModels:hide(spot.name)
		end
		local prompt = createPrompt(spot.promptAnchor, spot.rarity)
		prompt.Enabled = waiting
		prompts[spot.name] = prompt
		local connection = prompt.Triggered:Connect(function(player)
			onTriggered(spot, player :: PlayerLike)
		end)
		trove:Add(function()
			connection:Disconnect()
			prompt:Destroy()
		end)
	end

	local removing = deps.players.PlayerRemoving:Connect(function(player)
		limiter:forget((player :: PlayerLike).UserId)
	end)
	trove:Add(function()
		removing:Disconnect()
	end)

	local function returnEgg(_self: Grab, player: PlayerLike, why: ReturnReason?): (("back" | "gone")?, string?)
		local result: ("back" | "gone")?, spotName: string? = EggSlots.returnEgg(state, player.UserId)
		if spotName == nil then
			return nil, nil
		end
		takeEggOffBack(player)
		if result == "back" then
			spotModels:show(spotName)
			refreshPrompt(spotName)
		end
		local rarity: Config.RarityName? = rarityOfSpot[spotName]
		if rarity ~= nil then
			local reason: ReturnReason = if why ~= nil then why else "Lost"
			returned:Fire(player, rarity, reason)
		end
		return result, spotName
	end

	local function bank(_self: Grab, player: PlayerLike): (string?, Config.RarityName?)
		local spotName: string?, rarity: Config.RarityName? = EggSlots.bank(state, player.UserId)
		if spotName == nil then
			return nil, nil
		end
		takeEggOffBack(player)
		return spotName, rarity
	end

	local function noteFist(_self: Grab)
		lastFistAt = deps.now()
	end

	-- Locks or unlocks the right cuff nests (Rule 100): locked while he is Awake, until UnlockSeconds after a step first
	-- saw him leave Awake, and until ArmReturnSeconds after the last fist. Only a change touches the nests.
	local function updateCuffLock(now: number)
		if #cuffNames == 0 then
			return
		end
		local phase: Config.Phase = if deps.phase ~= nil then deps.phase() else "Asleep"
		if phase == "Awake" then
			sawAwake = true
			leftAwakeAt = nil
		elseif sawAwake then
			sawAwake = false
			leftAwakeAt = now
		end
		local left = leftAwakeAt
		local fist = lastFistAt
		local locked = phase == "Awake"
			or (left ~= nil and now - left < Config.Nests.UnlockSeconds)
			or (fist ~= nil and now - fist < Config.Nests.ArmReturnSeconds)
		if locked == cuffLocked then
			return
		end
		cuffLocked = locked
		EggSlots.setLocked(state, cuffNames, locked)
		for _, spot in cuffSpots do
			spotModels:setLocked(spot.name, locked)
			refreshPrompt(spot.name)
		end
	end

	local function step(_self: Grab)
		updateCuffLock(deps.now())
		-- Where everyone stands: a new egg never lands within Config.Nests.PlayerDistance of a player (Rule 76).
		local playersAt: { Vector3 } = {}
		for _, player in deps.players:GetPlayers() do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") then
				table.insert(playersAt, root.Position)
			end
		end
		for _, refill in EggSlots.update(state, deps.now(), playersAt, pick) do
			spotModels:show(refill.nest)
			refreshPrompt(refill.nest)
			refilled:Fire(refill.rank, refill.waited)
		end
	end

	local function stop(_self: Grab)
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end

	local grab: Grab = {
		returnEgg = returnEgg,
		bank = bank,
		grabbed = grabbed,
		returned = returned,
		refilled = refilled,
		noteFist = noteFist,
		step = step,
		stop = stop,
	}

	trove:Add(GiantDirector.run(grab, deps.heartbeat, REFILL_CHECK_SECONDS, MAX_CHECKS_PER_FRAME))
	return grab
end

return Grab
