--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Grab = require(ServerScriptService.Server.Eggs.Grab)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local GrabRig = require(script.Parent.GrabRig)

type FakePlayer = GrabRig.FakePlayer

local newSignal = GrabRig.newSignal
local newTemplate = GrabRig.newTemplate
local newSpot = GrabRig.newSpot
local newPlayer = GrabRig.newPlayer
local eggOnBack = GrabRig.eggOnBack
local START_TIME = GrabRig.START_TIME

describe("Grab.check", function()
	it("accepts a living player close to the egg who carries nothing", function()
		local ok, reason = Grab.check(true, 3, false)
		expect(ok).toBe(true)
		expect(reason).toBeNil()
	end)

	it("accepts a player exactly 10 studs away (reach 8 plus 2 for lag)", function()
		local ok = Grab.check(true, 10, false)
		expect(ok).toBe(true)
	end)

	it("refuses a player 10.1 studs away", function()
		local ok, reason = Grab.check(true, 10.1, false)
		expect(ok).toBe(false)
		expect(reason).toBe("too far")
	end)

	it("refuses a dead player", function()
		local ok, reason = Grab.check(false, 1, false)
		expect(ok).toBe(false)
		expect(reason).toBe("dead")
	end)

	it("refuses a player who already carries an egg", function()
		local ok, reason = Grab.check(true, 1, true)
		expect(ok).toBe(false)
		expect(reason).toBe("already carrying")
	end)

	it("refuses a player whose distance is not a real number", function()
		local ok = Grab.check(true, 0 / 0, false)
		expect(ok).toBe(false)
	end)
end)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances = GrabRig.madeInstances
local stops = GrabRig.stops

afterEach(GrabRig.cleanUp)

describe("Grab.createPrompt", function()
	it("makes a one second, 8 stud, E key hold prompt that says what it grabs", function()
		local base = Instance.new("Part")
		local anchor = Instance.new("Attachment")
		anchor.Parent = base
		table.insert(madeInstances, base)
		local prompt = Grab.createPrompt(anchor, "Uncommon")
		expect(prompt.Parent).toBe(anchor)
		expect(prompt.HoldDuration).toBe(Config.Grab.HoldSeconds)
		expect(prompt.HoldDuration).toBe(1)
		expect(prompt.MaxActivationDistance).toBe(Config.Grab.ReachStuds)
		expect(prompt.MaxActivationDistance).toBe(8)
		expect(prompt.KeyboardKeyCode).toBe(Enum.KeyCode.E)
		expect(prompt.ActionText).toBe("Hold to Grab")
		expect(prompt.ObjectText).toBe("Uncommon egg")
		expect(prompt.Style).toBe(Enum.ProximityPromptStyle.Custom)
		expect(prompt.RequiresLineOfSight).toBe(false)
	end)
end)

type FakePrompt = { Triggered: any, Enabled: boolean, destroyed: boolean, Destroy: (self: any) -> () }

type Rig = {
	grab: Grab.Grab,
	spots: { [string]: WorldIndex.EggSpot },
	prompts: { [string]: FakePrompt },
	missed: { any }, -- the players GrabMissed was fired to, in order
	players: any,
	heartbeat: any,
	setTime: (seconds: number) -> (),
	trigger: (spotName: string, player: FakePlayer) -> (),
	-- A player standing on the spot (3 studs from its prompt anchor).
	playerAt: (userId: number, spotName: string) -> FakePlayer,
}

-- Starts Grab on fake spots (two of each rank: Common_1/2, Uncommon_1/2, Rare_1/2), fake prompts, a fake clock, a
-- fake Players service and a fake GrabMissed remote. Each rank gets one slot fewer than it has spots (GrabRig.oneFreeSlots), so each
-- rank has one egg, on its _1 spot; the _2 spot starts empty and is where the refill lands.
local function newRig(): Rig
	local spotList = {
		newSpot("Common_1", "Common", 0),
		newSpot("Common_2", "Common", 50),
		newSpot("Uncommon_1", "Uncommon", 100),
		newSpot("Uncommon_2", "Uncommon", 200),
		newSpot("Rare_1", "Rare", 150),
		newSpot("Rare_2", "Rare", 250),
	}
	local spots: { [string]: WorldIndex.EggSpot } = {}
	for _, spot in spotList do
		spots[spot.name] = spot
	end
	local prompts: { [string]: FakePrompt } = {}
	local missed: { any } = {}
	local time = START_TIME
	local players: any = {
		PlayerRemoving = newSignal(),
		GetPlayers = function()
			return {}
		end,
	}
	local heartbeat: any = newSignal()
	local grab = Grab.start({
		spots = spotList,
		slotsPerRank = GrabRig.oneFreeSlots(spotList),
		templates = { Common = newTemplate("Common"), Uncommon = newTemplate("Uncommon"), Rare = newTemplate("Rare") },
		carriedOffset = CFrame.new(0, 0.8, 1.9),
		carriedHeight = 4.2,
		players = players,
		heartbeat = heartbeat,
		grabMissed = function(player)
			table.insert(missed, player)
		end,
		now = function()
			return time
		end,
		createPrompt = function(anchor: Attachment, _rarity: Config.RarityName): any
			local prompt: FakePrompt = {
				Triggered = newSignal(),
				Enabled = true,
				destroyed = false,
				Destroy = function(self: any)
					self.destroyed = true
				end,
			}
			prompts[((anchor.Parent :: Instance).Parent :: Instance).Name] = prompt
			return prompt
		end,
	})
	table.insert(stops, function()
		grab:stop()
	end)
	local rig: Rig
	rig = {
		grab = grab,
		spots = spots,
		prompts = prompts,
		missed = missed,
		players = players,
		heartbeat = heartbeat,
		setTime = function(seconds: number)
			time = seconds
		end,
		trigger = function(spotName: string, player: FakePlayer)
			prompts[spotName].Triggered:Fire(player)
		end,
		playerAt = function(userId: number, spotName: string): FakePlayer
			local anchor = spots[spotName].promptAnchor.WorldPosition
			return newPlayer(userId, anchor + Vector3.new(3, 0, 0))
		end,
	}
	return rig
end

local function eggOnSpot(rig: Rig, spotName: string): Instance?
	return rig.spots[spotName].model:FindFirstChild("Egg")
end

-- How many nests of `rarity` show a waiting egg (their model's Waiting attribute is true).
local function waitingCount(rig: Rig, rarity: string): number
	local count = 0
	for _, spot in rig.spots do
		if spot.model:GetAttribute("Rarity") == rarity and spot.model:GetAttribute("Waiting") == true then
			count += 1
		end
	end
	return count
end

describe("Grab.start", function()
	it("puts a prompt on every spot's prompt anchor", function()
		local rig = newRig()
		local count = 0
		for _ in rig.prompts do
			count += 1
		end
		expect(count).toBe(6)
	end)

	it("makes a real hold prompt on every anchor when no prompt maker is given", function()
		local spot = newSpot("Common_1", "Common", 0)
		local grab = Grab.start({
			spots = { spot },
			templates = {
				Common = newTemplate("Common"),
				Uncommon = newTemplate("Uncommon"),
				Rare = newTemplate("Rare"),
			},
			carriedOffset = CFrame.new(0, 0.8, 1.9),
			carriedHeight = 4.2,
			players = {
				PlayerRemoving = newSignal(),
				GetPlayers = function()
					return {}
				end,
			} :: any,
			heartbeat = newSignal() :: any,
			grabMissed = function() end,
			now = function()
				return START_TIME
			end,
		})
		local prompt = spot.promptAnchor:FindFirstChildOfClass("ProximityPrompt")
		expect(prompt).never.toBeNil()
		expect((prompt :: ProximityPrompt).HoldDuration).toBe(1)
		grab:stop()
		expect(spot.promptAnchor:FindFirstChildOfClass("ProximityPrompt")).toBeNil()
	end)

	it("shows an egg on each rank's first spot at the start, with Waiting true, and leaves the others empty", function()
		local rig = newRig()
		for name, spot in rig.spots do
			local hasEgg = string.sub(name, -2) == "_1"
			expect(eggOnSpot(rig, name) ~= nil).toBe(hasEgg)
			expect(spot.model:GetAttribute("Waiting")).toBe(hasEgg)
			expect(spot.model:GetAttribute("RefillAt")).toBeNil()
		end
	end)

	it("gives the egg to the first hold that finishes: it goes on the back and Carrying is set", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		expect(player:GetAttribute("Carrying")).toBe("Common")
		expect(eggOnBack(player)).never.toBeNil()
		expect(#rig.missed).toBe(0)
	end)

	it("empties the spot and shows no countdown", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		local model = rig.spots.Common_1.model
		expect(eggOnSpot(rig, "Common_1")).toBeNil()
		expect(model:GetAttribute("Waiting")).toBe(false)
		expect(model:GetAttribute("RefillAt")).toBeNil()
	end)

	it("uses the refill time of the egg's rarity", function()
		local rig = newRig()
		local uncommonBefore = waitingCount(rig, "Uncommon")
		local rareBefore = waitingCount(rig, "Rare")
		rig.trigger("Uncommon_1", rig.playerAt(1, "Uncommon_1"))
		rig.trigger("Rare_1", rig.playerAt(2, "Rare_1"))
		local uncommonSeconds = Config.Rarity.Uncommon.RefillSeconds
		local rareSeconds = Config.Rarity.Rare.RefillSeconds
		rig.setTime(START_TIME + uncommonSeconds - 0.1)
		rig.grab:step()
		expect(waitingCount(rig, "Uncommon")).toBe(uncommonBefore - 1)
		rig.setTime(START_TIME + uncommonSeconds)
		rig.grab:step()
		expect(waitingCount(rig, "Uncommon")).toBe(uncommonBefore)
		rig.setTime(START_TIME + rareSeconds - 0.1)
		rig.grab:step()
		expect(waitingCount(rig, "Rare")).toBe(rareBefore - 1)
		rig.setTime(START_TIME + rareSeconds)
		rig.grab:step()
		expect(waitingCount(rig, "Rare")).toBe(rareBefore)
	end)

	it("carries the rarity of the spot that was grabbed", function()
		local rig = newRig()
		local uncommon = rig.playerAt(1, "Uncommon_1")
		local rare = rig.playerAt(2, "Rare_1")
		rig.trigger("Uncommon_1", uncommon)
		rig.trigger("Rare_1", rare)
		expect(uncommon:GetAttribute("Carrying")).toBe("Uncommon")
		expect(rare:GetAttribute("Carrying")).toBe("Rare")
	end)

	it("tells the second player 'missed' and changes nothing else", function()
		local rig = newRig()
		local first = rig.playerAt(1, "Common_1")
		local second = rig.playerAt(2, "Common_1")
		rig.trigger("Common_1", first)
		rig.trigger("Common_1", second)
		expect(#rig.missed).toBe(1)
		expect(rig.missed[1]).toBe(second)
		expect(second:GetAttribute("Carrying")).toBeNil()
		expect(eggOnBack(second)).toBeNil()
		expect(first:GetAttribute("Carrying")).toBe("Common")
		expect(eggOnBack(first)).never.toBeNil()
		expect(rig.spots.Common_1.model:GetAttribute("RefillAt")).toBeNil()
	end)

	it("lets the player who missed grab another egg", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		rig.setTime(START_TIME + Config.Rarity.Common.RefillSeconds)
		rig.grab:step() -- the refill puts the egg on Common_2
		local second = rig.playerAt(2, "Common_2")
		rig.trigger("Common_1", second) -- too far: second stands at Common_2, 50 studs away
		rig.trigger("Common_2", second)
		expect(second:GetAttribute("Carrying")).toBe("Common")
	end)

	it("sends no 'missed' to a player who is too far, dead or already carrying", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1")) -- Common_1 is now empty

		local tooFar = rig.playerAt(2, "Common_1")
		tooFar.root.Position = rig.spots.Common_1.promptAnchor.WorldPosition + Vector3.new(10.1, 0, 0)
		rig.trigger("Common_1", tooFar)

		local dead = rig.playerAt(3, "Common_1")
		dead.humanoid.Health = 0
		rig.trigger("Common_1", dead)

		local carrier = rig.playerAt(4, "Uncommon_1")
		rig.trigger("Uncommon_1", carrier)
		carrier.root.Position = rig.spots.Common_1.promptAnchor.WorldPosition
		rig.trigger("Common_1", carrier)

		expect(#rig.missed).toBe(0)
	end)

	it("refuses a player too far away, a dead player and a player who already carries", function()
		local rig = newRig()

		local tooFar = rig.playerAt(1, "Common_1")
		tooFar.root.Position = rig.spots.Common_1.promptAnchor.WorldPosition + Vector3.new(10.1, 0, 0)
		rig.trigger("Common_1", tooFar)
		expect(tooFar:GetAttribute("Carrying")).toBeNil()

		local dead = rig.playerAt(2, "Common_1")
		dead.humanoid.Health = 0
		rig.trigger("Common_1", dead)
		expect(dead:GetAttribute("Carrying")).toBeNil()

		local carrier = rig.playerAt(3, "Uncommon_1")
		rig.trigger("Uncommon_1", carrier)
		carrier.root.Position = rig.spots.Common_1.promptAnchor.WorldPosition
		rig.trigger("Common_1", carrier)
		expect(carrier:GetAttribute("Carrying")).toBe("Uncommon") -- still the Uncommon egg, not a second one
		expect(eggOnSpot(rig, "Common_1")).never.toBeNil() -- nothing was taken from Common_1
		expect(rig.spots.Common_1.model:GetAttribute("Waiting")).toBe(true)
	end)

	it("takes a grab from exactly 10 studs away", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		player.root.Position = rig.spots.Common_1.promptAnchor.WorldPosition + Vector3.new(0, 0, 10)
		rig.trigger("Common_1", player)
		expect(player:GetAttribute("Carrying")).toBe("Common")
	end)

	it("ignores a player who has no character", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		player.Character = nil
		rig.trigger("Common_1", player)
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(#rig.missed).toBe(0)
		expect(eggOnSpot(rig, "Common_1")).never.toBeNil()
	end)

	it("ignores a sixth grab from one player within one second", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1")) -- empties Common_1
		local pest = rig.playerAt(2, "Common_1")
		for _ = 1, 6 do
			rig.trigger("Common_1", pest)
		end
		expect(#rig.missed).toBe(5)
	end)

	it("answers that player again once the second is over", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		local pest = rig.playerAt(2, "Common_1")
		for _ = 1, 6 do
			rig.trigger("Common_1", pest)
		end
		rig.setTime(START_TIME + 1)
		rig.trigger("Common_1", pest)
		expect(#rig.missed).toBe(6)
	end)

	it("counts the limit for each player on their own", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		local pest = rig.playerAt(2, "Common_1")
		for _ = 1, 6 do
			rig.trigger("Common_1", pest)
		end
		local other = rig.playerAt(3, "Common_1")
		rig.trigger("Common_1", other)
		expect(#rig.missed).toBe(6)
		expect(rig.missed[6]).toBe(other)
	end)

	it("forgets a player's limit when they leave", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		local pest = rig.playerAt(2, "Common_1")
		for _ = 1, 5 do
			rig.trigger("Common_1", pest)
		end
		rig.players.PlayerRemoving:Fire(pest)
		rig.trigger("Common_1", pest)
		expect(#rig.missed).toBe(6)
	end)
end)

describe("Grab refills", function()
	it("shows the taken Common egg again 10 seconds later on the other Common nest, and not before", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		rig.setTime(START_TIME + 9.9)
		rig.grab:step()
		expect(eggOnSpot(rig, "Common_2")).toBeNil()
		expect(rig.spots.Common_2.model:GetAttribute("Waiting")).toBe(false)
		rig.setTime(START_TIME + 10)
		rig.grab:step()
		expect(eggOnSpot(rig, "Common_2")).never.toBeNil()
		expect(rig.spots.Common_2.model:GetAttribute("Waiting")).toBe(true)
		expect(rig.spots.Common_2.model:GetAttribute("RefillAt")).toBeNil()
		expect(eggOnSpot(rig, "Common_1")).toBeNil() -- the taken nest stays empty
	end)

	it("lets the next player grab a refilled spot", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		rig.setTime(START_TIME + 10)
		rig.grab:step()
		local second = rig.playerAt(2, "Common_2")
		rig.trigger("Common_2", second)
		expect(second:GetAttribute("Carrying")).toBe("Common")
		expect(#rig.missed).toBe(0)
	end)

	it("is checked on the server's heartbeat, every 0.1 seconds", function()
		local rig = newRig()
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		rig.setTime(START_TIME + 10)
		rig.heartbeat:Fire(0.05) -- not yet 0.1 seconds
		expect(eggOnSpot(rig, "Common_2")).toBeNil()
		rig.heartbeat:Fire(0.05)
		expect(eggOnSpot(rig, "Common_2")).never.toBeNil()
	end)
end)

describe("Grab returnEgg", function()
	it("takes the egg off the back and puts it on its spot while the spot is still counting down", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		local result, spotName = rig.grab:returnEgg(player)
		expect(result).toBe("back")
		expect(spotName).toBe("Common_1")
		expect(eggOnBack(player)).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(eggOnSpot(rig, "Common_1")).never.toBeNil()
		expect(rig.spots.Common_1.model:GetAttribute("Waiting")).toBe(true)
		expect(rig.spots.Common_1.model:GetAttribute("RefillAt")).toBeNil()
	end)

	it("makes the returned egg vanish when its spot already refilled, so the spot keeps its one egg", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.setTime(START_TIME + 10)
		rig.grab:step()
		local result = rig.grab:returnEgg(player)
		expect(result).toBe("gone")
		expect(eggOnBack(player)).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
		local eggs = 0
		for _, spotName in { "Common_1", "Common_2" } do
			for _, child in rig.spots[spotName].model:GetChildren() do
				if child.Name == "Egg" then
					eggs += 1
				end
			end
		end
		expect(eggs).toBe(1) -- the refill's egg on Common_2; the returned one is gone
		expect(eggOnSpot(rig, "Common_1")).toBeNil()
	end)

	it("does nothing for a player who carries nothing", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		local result, spotName = rig.grab:returnEgg(player)
		expect(result).toBeNil()
		expect(spotName).toBeNil()
		expect(eggOnSpot(rig, "Common_1")).never.toBeNil()
	end)

	it("lets the player grab again afterwards", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.grab:returnEgg(player)
		rig.trigger("Common_1", player)
		expect(player:GetAttribute("Carrying")).toBe("Common")
	end)
end)

describe("Grab bank", function()
	it("takes the egg off the back, clears Carrying and says which egg it was", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Uncommon_1")
		rig.trigger("Uncommon_1", player)
		local spotName, rarity = rig.grab:bank(player)
		expect(spotName).toBe("Uncommon_1")
		expect(rarity).toBe("Uncommon")
		expect(eggOnBack(player)).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
	end)

	it("leaves the spot empty with no countdown, and the egg still comes back", function()
		local rig = newRig()
		local before = waitingCount(rig, "Uncommon")
		local player = rig.playerAt(1, "Uncommon_1")
		rig.trigger("Uncommon_1", player)
		rig.grab:bank(player)
		expect(eggOnSpot(rig, "Uncommon_1")).toBeNil()
		expect(rig.spots.Uncommon_1.model:GetAttribute("Waiting")).toBe(false)
		expect(rig.spots.Uncommon_1.model:GetAttribute("RefillAt")).toBeNil()
		local seconds = Config.Rarity.Uncommon.RefillSeconds
		rig.setTime(START_TIME + seconds - 0.1)
		rig.grab:step()
		expect(waitingCount(rig, "Uncommon")).toBe(before - 1)
		rig.setTime(START_TIME + seconds)
		rig.grab:step()
		expect(waitingCount(rig, "Uncommon")).toBe(before)
	end)

	it("does nothing for a player who carries nothing", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		local spotName, rarity = rig.grab:bank(player)
		expect(spotName).toBeNil()
		expect(rarity).toBeNil()
	end)

	it("lets the player grab again afterwards", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.grab:bank(player)
		rig.setTime(START_TIME + Config.Rarity.Common.RefillSeconds)
		rig.grab:step() -- the refill puts the egg on Common_2
		player.root.Position = rig.spots.Common_2.promptAnchor.WorldPosition
		rig.trigger("Common_2", player)
		expect(player:GetAttribute("Carrying")).toBe("Common")
	end)
end)

describe("Grab grabbed signal", function()
	it("fires once with the player and the egg's rarity on a good grab, after Carrying is set", function()
		local rig = newRig()
		local heard: { { player: any, rarity: any, carryingThen: any } } = {}
		rig.grab.grabbed:Connect(function(player, rarity)
			table.insert(
				heard,
				{ player = player, rarity = rarity, carryingThen = (player :: any):GetAttribute("Carrying") }
			)
		end)
		local player = rig.playerAt(1, "Uncommon_1")
		rig.trigger("Uncommon_1", player)
		expect(#heard).toBe(1)
		expect(heard[1].player).toBe(player)
		expect(heard[1].rarity).toBe("Uncommon")
		expect(heard[1].carryingThen).toBe("Uncommon")
	end)

	it("does not fire for a grab that is refused or missed", function()
		local rig = newRig()
		local count = 0
		rig.grab.grabbed:Connect(function()
			count += 1
		end)
		rig.trigger("Common_1", rig.playerAt(1, "Common_1")) -- the one good grab
		expect(count).toBe(1)
		rig.trigger("Common_1", rig.playerAt(2, "Common_1")) -- missed: the egg is gone
		local tooFar = rig.playerAt(3, "Common_2")
		tooFar.root.Position = rig.spots.Common_2.promptAnchor.WorldPosition + Vector3.new(10.1, 0, 0)
		rig.trigger("Common_2", tooFar)
		local dead = rig.playerAt(4, "Common_2")
		dead.humanoid.Health = 0
		rig.trigger("Common_2", dead)
		expect(count).toBe(1)
	end)

	it("is destroyed when Grab stops", function()
		local rig = newRig()
		local connection = rig.grab.grabbed:Connect(function() end)
		expect(connection.Connected).toBe(true)
		rig.grab:stop()
		expect(connection.Connected).toBe(false)
	end)
end)

describe("Grab returned signal", function()
	it("fires once with the player, the egg's rarity and 'Lost' when an egg goes back with no reason given", function()
		local rig = newRig()
		local heard: { { player: any, rarity: any, why: any, carryingThen: any } } = {}
		rig.grab.returned:Connect(function(player, rarity, why)
			table.insert(
				heard,
				{ player = player, rarity = rarity, why = why, carryingThen = (player :: any):GetAttribute("Carrying") }
			)
		end)
		local player = rig.playerAt(1, "Uncommon_1")
		rig.trigger("Uncommon_1", player)
		rig.grab:returnEgg(player)
		expect(#heard).toBe(1)
		expect(heard[1].player).toBe(player)
		expect(heard[1].rarity).toBe("Uncommon")
		expect(heard[1].why).toBe("Lost")
		-- It fires after the egg is off their back.
		expect(heard[1].carryingThen).toBeNil()
	end)

	it("says 'Caught' when returnEgg is asked with that reason", function()
		local rig = newRig()
		local whys: { any } = {}
		rig.grab.returned:Connect(function(_player, _rarity, why)
			table.insert(whys, why)
		end)
		local player = rig.playerAt(1, "Rare_1")
		rig.trigger("Rare_1", player)
		rig.grab:returnEgg(player, "Caught")
		expect(whys).toEqual({ "Caught" })
	end)

	it("fires for an egg that vanishes because its spot already refilled", function()
		local rig = newRig()
		local count = 0
		rig.grab.returned:Connect(function()
			count += 1
		end)
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.setTime(START_TIME + 10)
		rig.grab:step()
		rig.grab:returnEgg(player)
		expect(count).toBe(1)
	end)

	it("does not fire for a player who carries nothing", function()
		local rig = newRig()
		local count = 0
		rig.grab.returned:Connect(function()
			count += 1
		end)
		rig.grab:returnEgg(rig.playerAt(1, "Common_1"))
		rig.grab:returnEgg(rig.playerAt(2, "Common_1"), "Caught")
		expect(count).toBe(0)
	end)

	it("does not fire when an egg is banked", function()
		local rig = newRig()
		local count = 0
		rig.grab.returned:Connect(function()
			count += 1
		end)
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.grab:bank(player)
		expect(count).toBe(0)
	end)

	it("is destroyed when Grab stops", function()
		local rig = newRig()
		local connection = rig.grab.returned:Connect(function() end)
		expect(connection.Connected).toBe(true)
		rig.grab:stop()
		expect(connection.Connected).toBe(false)
	end)
end)

-- Plan 7 Task 12 (Rules 94 and 95): `popped` fires (position, kind) so every device can play the egg's sound at the nest.
describe("Grab popped", function()
	type Pop = { position: Vector3, kind: string }

	local function listen(rig: Rig): { Pop }
		local pops: { Pop } = {}
		rig.grab.popped:Connect(function(position: Vector3, kind: string)
			table.insert(pops, { position = position, kind = kind })
		end)
		return pops
	end

	it("fires one Refill at the refilled nest's position after the refill", function()
		local rig = newRig()
		local pops = listen(rig)
		rig.trigger("Common_1", rig.playerAt(1, "Common_1"))
		rig.setTime(START_TIME + 9.9)
		rig.grab:step()
		expect(#pops).toBe(0)
		rig.setTime(START_TIME + 10)
		rig.grab:step()
		expect(#pops).toBe(1)
		expect(pops[1].kind).toBe("Refill")
		expect(pops[1].position).toEqual(rig.spots.Common_2.cframe.Position)
	end)

	it("fires Back at the nest when a returned egg finds its nest free", function()
		local rig = newRig()
		local pops = listen(rig)
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.grab:returnEgg(player)
		expect(#pops).toBe(1)
		expect(pops[1].kind).toBe("Back")
		expect(pops[1].position).toEqual(rig.spots.Common_1.cframe.Position)
	end)

	it("fires Gone at the old nest when the slot already refilled", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		rig.setTime(START_TIME + 10)
		rig.grab:step()
		local pops = listen(rig) -- listens after the refill, so only the return counts
		rig.grab:returnEgg(player)
		expect(#pops).toBe(1)
		expect(pops[1].kind).toBe("Gone")
		expect(pops[1].position).toEqual(rig.spots.Common_1.cframe.Position)
	end)

	it("fires nothing for a player who carries nothing", function()
		local rig = newRig()
		local pops = listen(rig)
		rig.grab:returnEgg(rig.playerAt(1, "Common_1"))
		expect(#pops).toBe(0)
	end)

	it("is destroyed when Grab stops", function()
		local rig = newRig()
		local connection = rig.grab.popped:Connect(function() end)
		expect(connection.Connected).toBe(true)
		rig.grab:stop()
		expect(connection.Connected).toBe(false)
	end)
end)

describe("Grab.stop", function()
	it("disconnects, destroys the prompts and removes every egg, on the spots and on backs", function()
		local rig = newRig()
		local player = rig.playerAt(1, "Common_1")
		rig.trigger("Common_1", player)
		local promptOne = rig.prompts.Common_1
		rig.grab:stop()
		expect(promptOne.destroyed).toBe(true)
		expect(promptOne.Triggered:count()).toBe(0)
		expect(rig.players.PlayerRemoving:count()).toBe(0)
		expect(rig.heartbeat:count()).toBe(0)
		for name in rig.spots do
			expect(eggOnSpot(rig, name)).toBeNil()
		end
		expect(eggOnBack(player)).toBeNil()
		expect(player:GetAttribute("Carrying")).toBeNil()
	end)

	it("can be called twice", function()
		local rig = newRig()
		rig.grab:stop()
		rig.grab:stop()
		expect(rig.heartbeat:count()).toBe(0)
	end)
end)
