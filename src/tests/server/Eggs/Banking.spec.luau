--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Banking = require(ServerScriptService.Server.Eggs.Banking)
local Grab = require(ServerScriptService.Server.Eggs.Grab)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

describe("Banking.shouldBank", function()
	it("is true for a carrier inside their own garden", function()
		expect(Banking.shouldBank("Rare", 4, 4)).toBe(true)
	end)

	it("is false inside someone else's garden", function()
		expect(Banking.shouldBank("Rare", 5, 4)).toBe(false)
	end)

	it("is false out in the meadow (no garden)", function()
		expect(Banking.shouldBank("Rare", nil, 4)).toBe(false)
	end)

	it("is false for a player who carries nothing", function()
		expect(Banking.shouldBank(nil, 4, 4)).toBe(false)
	end)

	it("is false for a player with no PlotIndex", function()
		expect(Banking.shouldBank("Rare", 4, nil)).toBe(false)
	end)
end)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
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
		count = function(_self: any): number
			return #handlers
		end,
	}
end

type FakePlayer = {
	UserId: number,
	Name: string,
	Character: Model?,
	CharacterAdded: any,
	CharacterRemoving: any,
	root: BasePart,
	humanoid: Humanoid,
	SetAttribute: (self: any, name: string, value: any) -> (),
	GetAttribute: (self: any, name: string) -> any,
}

-- A character with a living Humanoid and a root part at `position`.
local function newCharacter(position: Vector3): (Model, Humanoid, BasePart)
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = character
	table.insert(madeInstances, character)
	return character, humanoid, root
end

-- A fake player with a living character. Its attributes live on a Folder.
local function newPlayer(userId: number, position: Vector3): FakePlayer
	local attributes = Instance.new("Folder")
	table.insert(madeInstances, attributes)
	local character, humanoid, root = newCharacter(position)
	return {
		UserId = userId,
		Name = `Player{userId}`,
		Character = character,
		CharacterAdded = newSignal(),
		CharacterRemoving = newSignal(),
		root = root,
		humanoid = humanoid,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes:SetAttribute(name, value)
		end,
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
	}
end

-- A fake Players service that holds fake players.
type FakePlayers = {
	PlayerAdded: any,
	PlayerRemoving: any,
	GetPlayers: (self: any) -> { FakePlayer },
	GetPlayerByUserId: (self: any, userId: number) -> FakePlayer?,
	add: (player: FakePlayer) -> (),
	remove: (player: FakePlayer) -> (),
}

local function newPlayers(): FakePlayers
	local list: { FakePlayer } = {}
	local players: FakePlayers
	players = {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function(_self: any): { FakePlayer }
			return table.clone(list)
		end,
		GetPlayerByUserId = function(_self: any, userId: number): FakePlayer?
			for _, player in list do
				if player.UserId == userId then
					return player
				end
			end
			return nil
		end,
		add = function(player: FakePlayer)
			table.insert(list, player)
			players.PlayerAdded:Fire(player)
		end,
		remove = function(player: FakePlayer)
			players.PlayerRemoving:Fire(player)
			local at = table.find(list, player)
			if at then
				table.remove(list, at)
			end
		end,
	}
	return players
end

local function startBanking(grab: any, players: FakePlayers): Banking.Banking
	local banking = Banking.start({ grab = grab, players = players :: any })
	table.insert(stops, function()
		banking:stop()
	end)
	return banking
end

local function sample(userId: number, garden: number?): PlayerTracker.Sample
	return {
		userId = userId,
		position = Vector3.zero,
		moving = false,
		groundSpeed = 0,
		zone = "Meadow",
		garden = garden,
		thudFrom = nil,
	}
end

-- A fake Grab for the check tests. bank() behaves like the real one: a carrier's Carrying is cleared and the
-- spot name and rarity come back; a player who carries nothing gets nil.
type FakeGrab = {
	bank: (self: any, player: any) -> (string?, Config.RarityName?),
	returnEgg: (self: any, player: any) -> (("back" | "gone")?, string?),
	banked: { any },
}

local function newFakeGrab(): FakeGrab
	local grab: FakeGrab
	grab = {
		banked = {},
		bank = function(_self: any, player: any): (string?, Config.RarityName?)
			local rarity = player:GetAttribute("Carrying")
			if rarity == nil then
				return nil, nil
			end
			table.insert(grab.banked, player)
			player:SetAttribute("Carrying", nil)
			return "Spot_1", rarity
		end,
		returnEgg = function(): (("back" | "gone")?, string?)
			return nil, nil
		end,
	}
	return grab
end

-- Collects what the banked signal says.
local function watchBanked(banking: Banking.Banking): { { player: any, rarity: Config.RarityName } }
	local events: { { player: any, rarity: Config.RarityName } } = {}
	local connection = banking.banked:Connect(function(player, rarity)
		table.insert(events, { player = player, rarity = rarity })
	end)
	table.insert(stops, function()
		connection:Disconnect()
	end)
	return events
end

local function carrier(players: FakePlayers, userId: number, rarity: string, plotIndex: number): FakePlayer
	local player = newPlayer(userId, Vector3.zero)
	player:SetAttribute("Carrying", rarity)
	player:SetAttribute("PlotIndex", plotIndex)
	players.add(player)
	return player
end

describe("Banking check", function()
	it("banks a carrier standing in their own garden: EggsHome 0 to 1, banked fires once with the rarity", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local events = watchBanked(banking)
		local player = carrier(players, 1, "Rare", 4)
		player:SetAttribute("EggsHome", 0)

		banking:check({ sample(1, 4) })
		task.wait()

		expect(player:GetAttribute("EggsHome")).toBe(1)
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(#events).toBe(1)
		expect(events[1].player).toBe(player)
		expect(events[1].rarity).toBe("Rare")
	end)

	it("counts a first egg for a player who has no EggsHome yet", function()
		local players = newPlayers()
		local banking = startBanking(newFakeGrab(), players)
		local player = carrier(players, 1, "Common", 2)
		banking:check({ sample(1, 2) })
		expect(player:GetAttribute("EggsHome")).toBe(1)
	end)

	it("adds to the eggs already home", function()
		local players = newPlayers()
		local banking = startBanking(newFakeGrab(), players)
		local player = carrier(players, 1, "Uncommon", 2)
		player:SetAttribute("EggsHome", 3)
		banking:check({ sample(1, 2) })
		expect(player:GetAttribute("EggsHome")).toBe(4)
	end)

	it("does not bank a carrier inside someone else's garden", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local events = watchBanked(banking)
		local player = carrier(players, 1, "Rare", 4)
		banking:check({ sample(1, 5) })
		task.wait()
		expect(#grab.banked).toBe(0)
		expect(#events).toBe(0)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
		expect(player:GetAttribute("EggsHome")).toBeNil()
	end)

	it("does not bank a carrier out in the meadow", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local player = carrier(players, 1, "Rare", 4)
		banking:check({ sample(1, nil) })
		expect(#grab.banked).toBe(0)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
	end)

	it("does not bank a player who carries nothing", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local events = watchBanked(banking)
		local player = newPlayer(1, Vector3.zero)
		player:SetAttribute("PlotIndex", 4)
		players.add(player)
		banking:check({ sample(1, 4) })
		task.wait()
		expect(#events).toBe(0)
		expect(player:GetAttribute("EggsHome")).toBeNil()
	end)

	it("does not bank a carrier who has no PlotIndex", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local player = newPlayer(1, Vector3.zero)
		player:SetAttribute("Carrying", "Rare")
		players.add(player)
		banking:check({ sample(1, 4) })
		expect(#grab.banked).toBe(0)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
	end)

	it("does not bank a Carrying value that is not a rarity", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local player = carrier(players, 1, "Diamond", 4)
		banking:check({ sample(1, 4) })
		expect(#grab.banked).toBe(0)
		expect(player:GetAttribute("EggsHome")).toBeNil()
	end)

	it("does not bank again on the next tick", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local events = watchBanked(banking)
		local player = carrier(players, 1, "Rare", 4)
		banking:check({ sample(1, 4) })
		banking:check({ sample(1, 4) })
		task.wait()
		expect(player:GetAttribute("EggsHome")).toBe(1)
		expect(#events).toBe(1)
	end)

	it("banks every carrier at home in the same tick, and only them", function()
		local players = newPlayers()
		local banking = startBanking(newFakeGrab(), players)
		local home = carrier(players, 1, "Rare", 1)
		local away = carrier(players, 2, "Common", 2)
		local also = carrier(players, 3, "Common", 3)
		banking:check({ sample(1, 1), sample(2, 1), sample(3, 3) })
		expect(home:GetAttribute("EggsHome")).toBe(1)
		expect(away:GetAttribute("EggsHome")).toBeNil()
		expect(also:GetAttribute("EggsHome")).toBe(1)
	end)

	it("skips a sample for a player who is no longer in the game", function()
		local players = newPlayers()
		local banking = startBanking(newFakeGrab(), players)
		expect(function()
			banking:check({ sample(99, 4) })
		end).never.toThrow()
	end)

	it("adds no egg when the grab had nothing to bank", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		grab.bank = function(): (string?, Config.RarityName?)
			return nil, nil
		end
		local banking = startBanking(grab, players)
		local events = watchBanked(banking)
		local player = carrier(players, 1, "Rare", 4)
		banking:check({ sample(1, 4) })
		task.wait()
		expect(player:GetAttribute("EggsHome")).toBeNil()
		expect(#events).toBe(0)
	end)
end)

-- A fake spot: a model with a Base part holding the prompt anchor 2 studs above it, as in the real world.
local function newSpot(name: string, rarity: Config.RarityName, x: number): WorldIndex.EggSpot
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Rarity", rarity)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(2, 0.2, 2)
	base.Anchored = true
	base.CFrame = CFrame.new(x, 0, 0)
	base.Parent = model
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, 2, 0)
	anchor.Parent = base
	table.insert(madeInstances, model)
	return {
		name = name,
		rarity = rarity,
		cframe = CFrame.new(x, 0.1, 0),
		promptAnchor = anchor,
		model = model,
	}
end

local function newTemplate(rarity: string): Model
	local model = Instance.new("Model")
	model.Name = rarity
	local part = Instance.new("Part")
	part.Name = "body_geom"
	part.Size = Vector3.new(3, 5, 3)
	part.CFrame = CFrame.new(0, 2.5, 0)
	part.Anchored = true
	part.Parent = model
	model.WorldPivot = CFrame.new(0, 0, 0)
	table.insert(madeInstances, model)
	return model
end

local START_TIME = 1000

type Rig = {
	grab: Grab.Grab,
	banking: Banking.Banking,
	players: FakePlayers,
	spots: { [string]: WorldIndex.EggSpot },
	prompts: { [string]: any },
	setTime: (seconds: number) -> (),
	-- A player standing 3 studs from the spot, added to the fake Players service.
	playerAt: (userId: number, spotName: string) -> FakePlayer,
	grabAt: (spotName: string, player: FakePlayer) -> (),
}

-- The real Grab on four fake spots, a fake clock and fake prompts, with Banking started on top of it. When
-- `before` is given, it runs after Grab starts but before Banking does (to add players that are already there).
local function newRig(before: ((rig: Rig) -> ())?): Rig
	local spotList = {
		newSpot("Common_1", "Common", 0),
		newSpot("Common_2", "Common", 50),
		newSpot("Rare_1", "Rare", 150),
	}
	local spots: { [string]: WorldIndex.EggSpot } = {}
	for _, spot in spotList do
		spots[spot.name] = spot
	end
	local prompts: { [string]: any } = {}
	local time = START_TIME
	local players = newPlayers()
	local grab = Grab.start({
		spots = spotList,
		templates = { Common = newTemplate("Common"), Uncommon = newTemplate("Uncommon"), Rare = newTemplate("Rare") },
		carriedOffset = CFrame.new(0, 0.8, 1.9),
		carriedHeight = 4.2,
		players = players :: any,
		heartbeat = newSignal() :: any,
		grabMissed = function() end,
		now = function()
			return time
		end,
		createPrompt = function(anchor: Attachment, _rarity: Config.RarityName): any
			local prompt = {
				Triggered = newSignal(),
				Destroy = function() end,
			}
			prompts[((anchor.Parent :: Instance).Parent :: Instance).Name] = prompt
			return prompt
		end,
	})
	table.insert(stops, function()
		grab:stop()
	end)
	local rig: Rig = {
		grab = grab,
		banking = nil :: any,
		players = players,
		spots = spots,
		prompts = prompts,
		setTime = function(seconds: number)
			time = seconds
		end,
		playerAt = function(userId: number, spotName: string): FakePlayer
			local anchor = spots[spotName].promptAnchor.WorldPosition
			local player = newPlayer(userId, anchor + Vector3.new(3, 0, 0))
			players.add(player)
			return player
		end,
		grabAt = function(spotName: string, player: FakePlayer)
			prompts[spotName].Triggered:Fire(player)
		end,
	}
	if before then
		before(rig)
	end
	rig.banking = startBanking(grab, players)
	return rig
end

local function eggOnSpot(rig: Rig, spotName: string): Instance?
	return rig.spots[spotName].model:FindFirstChild("Egg")
end

local function eggsOnSpot(rig: Rig, spotName: string): number
	local count = 0
	for _, child in rig.spots[spotName].model:GetChildren() do
		if child.Name == "Egg" then
			count += 1
		end
	end
	return count
end

local function eggOnBack(player: FakePlayer): Instance?
	return (player.Character :: Model):FindFirstChild("CarriedEgg")
end

-- A new life: a fresh character, announced the way Roblox does it.
local function respawn(player: FakePlayer)
	local character, humanoid, root = newCharacter(Vector3.zero)
	player.Character = character
	player.humanoid = humanoid
	player.root = root
	player.CharacterAdded:Fire(character)
end

describe("Banking sends a carried egg back", function()
	it("puts the egg back on its spot when the carrier's Humanoid dies", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		rig.grabAt("Rare_1", player)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
		expect(eggOnSpot(rig, "Rare_1")).toBeNil()

		player.humanoid.Health = 0
		task.wait()

		expect(eggOnSpot(rig, "Rare_1")).never.toBeNil()
		expect(rig.spots.Rare_1.model:GetAttribute("Waiting")).toBe(true)
		expect(rig.spots.Rare_1.model:GetAttribute("RefillAt")).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(eggOnBack(player)).toBeNil()
	end)

	it("lets the carrier grab again after the respawn", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		rig.grabAt("Rare_1", player)
		player.humanoid.Health = 0
		task.wait()

		respawn(player)
		player.root.Position = rig.spots.Rare_1.promptAnchor.WorldPosition + Vector3.new(3, 0, 0)
		rig.grabAt("Rare_1", player)

		expect(player:GetAttribute("Carrying")).toBe("Rare")
		expect(eggOnBack(player)).never.toBeNil()
		expect(eggOnSpot(rig, "Rare_1")).toBeNil()
	end)

	it("sends nothing back twice when the dead character is then removed", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		rig.grabAt("Rare_1", player)
		player.humanoid.Health = 0
		task.wait()
		player.CharacterRemoving:Fire(player.Character)
		expect(eggsOnSpot(rig, "Rare_1")).toBe(1)
	end)

	it("makes the egg disappear, leaving one egg on the spot, when the spot already refilled", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.grabAt("Common_1", player)
		rig.setTime(START_TIME + 10)
		rig.grab:step() -- the Common refilled while it was carried
		expect(eggsOnSpot(rig, "Common_1")).toBe(1)

		player.humanoid.Health = 0
		task.wait()

		expect(eggsOnSpot(rig, "Common_1")).toBe(1)
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(eggOnBack(player)).toBeNil()
	end)

	it("puts the egg back when the character is removed without dying", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		rig.grabAt("Rare_1", player)

		player.CharacterRemoving:Fire(player.Character)

		expect(eggOnSpot(rig, "Rare_1")).never.toBeNil()
		expect(rig.spots.Rare_1.model:GetAttribute("RefillAt")).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
	end)

	it("puts the egg back when the carrier leaves the game", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		rig.grabAt("Rare_1", player)

		rig.players.remove(player)

		expect(eggOnSpot(rig, "Rare_1")).never.toBeNil()
		expect(rig.spots.Rare_1.model:GetAttribute("RefillAt")).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
	end)

	it("watches players and characters that were already there when it started", function()
		local early: FakePlayer? = nil
		local rig = newRig(function(made)
			early = made.playerAt(1, "Rare_1")
		end)
		local player = early :: FakePlayer
		rig.grabAt("Rare_1", player)

		player.humanoid.Health = 0
		task.wait()

		expect(eggOnSpot(rig, "Rare_1")).never.toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
	end)

	it("watches a player who joins later, and each new character after a respawn", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		respawn(player) -- a second life
		player.root.Position = rig.spots.Rare_1.promptAnchor.WorldPosition + Vector3.new(3, 0, 0)
		rig.grabAt("Rare_1", player)

		player.humanoid.Health = 0 -- dies as the new character
		task.wait()

		expect(eggOnSpot(rig, "Rare_1")).never.toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
	end)

	it("changes nothing when a player who carries nothing dies or leaves", function()
		local rig = newRig()
		local other = rig.playerAt(2, "Rare_1")
		rig.grabAt("Rare_1", other) -- someone else carries the Rare
		local empty = rig.playerAt(1, "Common_1")

		expect(function()
			empty.humanoid.Health = 0
			task.wait()
			empty.CharacterRemoving:Fire(empty.Character)
			rig.players.remove(empty)
		end).never.toThrow()

		expect(other:GetAttribute("Carrying")).toBe("Rare")
		expect(eggOnBack(other)).never.toBeNil()
		expect(eggOnSpot(rig, "Rare_1")).toBeNil()
		expect(eggsOnSpot(rig, "Common_1")).toBe(1)
	end)

	it("only sends back the egg of the player who died, not another carrier's", function()
		local rig = newRig()
		local first = rig.playerAt(1, "Rare_1")
		local second = rig.playerAt(2, "Common_1")
		rig.grabAt("Rare_1", first)
		rig.grabAt("Common_1", second)

		first.humanoid.Health = 0
		task.wait()

		expect(eggOnSpot(rig, "Rare_1")).never.toBeNil()
		expect(second:GetAttribute("Carrying")).toBe("Common")
		expect(eggOnSpot(rig, "Common_1")).toBeNil()
	end)
end)

describe("Banking stop", function()
	it("disconnects everything: a death or a leave after stop sends nothing back", function()
		local rig = newRig()
		local died = rig.playerAt(1, "Rare_1")
		local left = rig.playerAt(2, "Common_1")
		local removed = rig.playerAt(3, "Common_2")
		rig.grabAt("Rare_1", died)
		rig.grabAt("Common_1", left)
		rig.grabAt("Common_2", removed)

		rig.banking:stop()

		died.humanoid.Health = 0
		task.wait()
		rig.players.remove(left)
		removed.CharacterRemoving:Fire(removed.Character)

		expect(eggOnSpot(rig, "Rare_1")).toBeNil()
		expect(eggOnSpot(rig, "Common_1")).toBeNil()
		expect(eggOnSpot(rig, "Common_2")).toBeNil()
		expect(died:GetAttribute("Carrying")).toBe("Rare")
		expect(rig.players.PlayerAdded:count()).toBe(0)
		expect(rig.players.PlayerRemoving:count()).toBe(1) -- only Grab's own is left
		expect(died.CharacterAdded:count()).toBe(0)
		expect(removed.CharacterRemoving:count()).toBe(0)
	end)

	it("can be called twice", function()
		local rig = newRig()
		rig.banking:stop()
		expect(function()
			rig.banking:stop()
		end).never.toThrow()
	end)

	it("banks nothing after stop", function()
		local players = newPlayers()
		local grab = newFakeGrab()
		local banking = startBanking(grab, players)
		local player = carrier(players, 1, "Rare", 4)
		banking:stop()
		banking:check({ sample(1, 4) })
		expect(#grab.banked).toBe(0)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
	end)

	it("forgets a player who leaves, so nothing stays connected to them", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Rare_1")
		expect(player.CharacterAdded:count()).toBe(1)
		rig.players.remove(player)
		expect(player.CharacterAdded:count()).toBe(0)
		expect(player.CharacterRemoving:count()).toBe(0)
	end)
end)
