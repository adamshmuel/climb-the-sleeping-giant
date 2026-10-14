--!strict
-- Grabbing eggs. Every egg spot gets a hold prompt ("Hold to Grab"). When a player's hold finishes, the server
-- checks it again itself (a player's own device can't be trusted), and the first player to pass gets the egg.
-- This module is the one owner of the EggSpots state: it runs the refills, and it gives later tasks (banking,
-- catches, leaving) one place to return or bank an egg.
-- Everything it touches is passed in, so a test can give it fake spots, players, remotes and a fake clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local GiantDirector = require(script.Parent.Parent.Giant.GiantDirector)
local RateLimiter = require(script.Parent.Parent.Remotes.RateLimiter)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)
local Carry = require(script.Parent.Carry)
local EggSpots = require(script.Parent.EggSpots)
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

-- A hold prompt as Grab uses it: the event for a finished hold, and a way to remove it.
export type PromptLike = {
	Triggered: SignalLike,
	Destroy: (self: any) -> (),
}

export type Deps = {
	spots: { WorldIndex.EggSpot },
	templates: WorldIndex.EggTemplates,
	-- How the egg sits on the back: from the root part to the egg's centre, and how tall it is (Carry.attachEgg).
	carriedOffset: CFrame,
	carriedHeight: number,
	-- Only PlayerRemoving is used: a player who leaves is forgotten.
	players: { PlayerRemoving: SignalLike },
	-- Heartbeat, or a stand-in in tests. It drives the refill checks.
	heartbeat: GiantDirector.HeartbeatLike,
	-- Tells one player that someone else got the egg first (the GrabMissed remote).
	grabMissed: (player: PlayerLike) -> (),
	-- The shared server clock in seconds (Workspace:GetServerTimeNow()), so clients can read RefillAt as it is.
	now: () -> number,
	-- Makes the prompt on one anchor. Left out, Grab.createPrompt makes the real one; tests pass a fake.
	createPrompt: ((anchor: Attachment, rarity: Config.RarityName) -> PromptLike)?,
}

export type Grab = {
	-- Puts the player's carried egg back on its own spot (see EggSpots.returnEgg), takes it off their back and
	-- clears their Carrying attribute. Returns what happened and the spot's name, or nil if they carry nothing.
	returnEgg: (self: Grab, player: PlayerLike) -> (("back" | "gone")?, string?),
	-- The player's carried egg leaves the world for their garden (see EggSpots.bank): it comes off their back and
	-- Carrying is cleared, but the spot keeps counting down. Returns the spot's name and the egg's rarity, or nil.
	bank: (self: Grab, player: PlayerLike) -> (string?, Config.RarityName?),
	-- Fires after a grab succeeds (Carrying is set by then), with the player and the egg's rarity. Analytics listens to it.
	grabbed: Signal.Signal<PlayerLike, Config.RarityName>,
	-- One refill check. The heartbeat calls it every 0.1 s; tests call it by hand.
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

	local definitions: { EggSpots.SpotDefinition } = {}
	for _, spot in deps.spots do
		table.insert(definitions, { name = spot.name, rarity = spot.rarity })
	end
	local state = EggSpots.new(definitions)
	local spotModels = SpotModels.new(deps.spots, deps.templates)
	trove:Add(function()
		spotModels:destroy()
	end)
	local grabbed = Signal.new() :: Signal.Signal<PlayerLike, Config.RarityName>
	trove:Add(function()
		grabbed:Destroy()
	end)
	local limiter = RateLimiter.new(GRABS_PER_SECOND, 1, deps.now)
	-- Everyone who carries an egg right now, so stop() can take every egg off every back.
	local carriers: { [number]: PlayerLike } = {}

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
		local carrying = EggSpots.carrying(state, player.UserId) ~= nil
		local ok = Grab.check(alive, distance, carrying)
		if not ok or character == nil then
			return
		end

		local taken, reason = EggSpots.take(state, spot.name, player.UserId, deps.now())
		if not taken then
			if reason == "no egg" then
				deps.grabMissed(player)
			end
			return
		end
		local view = EggSpots.spot(state, spot.name)
		spotModels:hide(spot.name, if view then view.refillAt else nil)
		carriers[player.UserId] = player
		player:SetAttribute("Carrying", spot.rarity)
		Carry.attachEgg(character, deps.templates[spot.rarity], deps.carriedOffset, deps.carriedHeight)
		grabbed:Fire(player, spot.rarity)
	end

	for _, spot in deps.spots do
		spotModels:show(spot.name)
		local prompt = createPrompt(spot.promptAnchor, spot.rarity)
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

	local function returnEgg(_self: Grab, player: PlayerLike): (("back" | "gone")?, string?)
		local result: ("back" | "gone")?, spotName: string? = EggSpots.returnEgg(state, player.UserId)
		if spotName == nil then
			return nil, nil
		end
		takeEggOffBack(player)
		if result == "back" then
			spotModels:show(spotName)
		end
		return result, spotName
	end

	local function bank(_self: Grab, player: PlayerLike): (string?, Config.RarityName?)
		local spotName: string?, rarity: Config.RarityName? = EggSpots.bank(state, player.UserId)
		if spotName == nil then
			return nil, nil
		end
		takeEggOffBack(player)
		return spotName, rarity
	end

	local function step(_self: Grab)
		for _, spotName in EggSpots.update(state, deps.now()) do
			spotModels:show(spotName)
		end
	end

	local function stop(_self: Grab)
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end

	local grab: Grab = { returnEgg = returnEgg, bank = bank, grabbed = grabbed, step = step, stop = stop }

	trove:Add(GiantDirector.run(grab, deps.heartbeat, REFILL_CHECK_SECONDS, MAX_CHECKS_PER_FRAME))
	return grab
end

return Grab
