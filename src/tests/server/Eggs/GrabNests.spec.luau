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
local stops = GrabRig.stops

afterEach(GrabRig.cleanUp)

-- Task 7b: Grab runs on the nests. Bare spots (no nest part, no garden) get one slot fewer than they have spots.
type NestRig = {
	grab: Grab.Grab,
	spots: { WorldIndex.EggSpot },
	prompts: { [string]: any },
	standers: { FakePlayer }, -- everyone GetPlayers returns
	setTime: (seconds: number) -> (),
}

local function newNestRig(spots: { WorldIndex.EggSpot }): NestRig
	local prompts: { [string]: any } = {}
	local standers: { FakePlayer } = {}
	local time = START_TIME
	local grab = Grab.start({
		spots = spots,
		templates = { Common = newTemplate("Common"), Uncommon = newTemplate("Uncommon"), Rare = newTemplate("Rare") },
		carriedOffset = CFrame.new(0, 0.8, 1.9),
		carriedHeight = 4.2,
		players = {
			PlayerRemoving = newSignal(),
			GetPlayers = function()
				return standers :: any -- fake players carry more fields than Grab reads
			end,
		},
		heartbeat = newSignal(),
		grabMissed = function() end,
		now = function()
			return time
		end,
		random = Random.new(1),
		createPrompt = function(anchor: Attachment, _rarity: Config.RarityName): any
			local prompt = { Triggered = newSignal(), Enabled = true, Destroy = function() end }
			prompts[((anchor.Parent :: Instance).Parent :: Instance).Name] = prompt
			return prompt
		end,
	})
	table.insert(stops, function()
		grab:stop()
	end)
	return {
		grab = grab,
		spots = spots,
		prompts = prompts,
		standers = standers,
		setTime = function(seconds: number)
			time = seconds
		end,
	}
end

-- The names of the spots that show an egg, in order, joined with commas.
local function eggNames(rig: NestRig): string
	local names: { string } = {}
	for _, spot in rig.spots do
		if spot.model:FindFirstChild("Egg") ~= nil then
			table.insert(names, spot.name)
		end
	end
	return table.concat(names, ",")
end

-- The names of the spots whose prompt is on while no egg waits there, or off while one does.
local function promptMismatches(rig: NestRig): string
	local names: { string } = {}
	for _, spot in rig.spots do
		local hasEgg = spot.model:FindFirstChild("Egg") ~= nil
		if rig.prompts[spot.name].Enabled ~= hasEgg then
			table.insert(names, spot.name)
		end
	end
	return table.concat(names, ",")
end

-- Two Common nests 50 studs apart (so one slot): a player grabs the egg on Common_1, then stands `away` studs
-- (straight along the row) from Common_2, the only free nest.
local function grabThenStand(rig: NestRig, away: number): FakePlayer
	local player = newPlayer(1, rig.spots[1].promptAnchor.WorldPosition + Vector3.new(3, 0, 0))
	table.insert(rig.standers, player)
	rig.prompts.Common_1.Triggered:Fire(player)
	player.root.Position = rig.spots[2].cframe.Position - Vector3.new(away, 0, 0)
	return player
end

-- Config.Nests.PlayerDistance is the clear space round a new egg: 5 studs inside it blocks, 5 outside it is clear.
local NEAR = Config.Nests.PlayerDistance - 5
local FAR = Config.Nests.PlayerDistance + 5

describe("Grab on the nests", function()
	it("turns an empty nest's prompt off, and on again at the refill", function()
		local rig = newNestRig({
			newSpot("Common_1", "Common", 0),
			newSpot("Common_2", "Common", 50),
			newSpot("Common_3", "Common", 100),
		})
		expect(promptMismatches(rig)).toBe("") -- Common_3 starts empty, so its prompt starts off
		rig.prompts.Common_1.Triggered:Fire(
			newPlayer(1, rig.spots[1].promptAnchor.WorldPosition + Vector3.new(3, 0, 0))
		)
		expect(rig.prompts.Common_1.Enabled).toBe(false)
		expect(promptMismatches(rig)).toBe("")
		rig.setTime(START_TIME + Config.Rarity.Common.RefillSeconds)
		rig.grab:step()
		expect(eggNames(rig)).toBe("Common_2,Common_3") -- the refill took the only free nest that was not the last one
		expect(rig.prompts.Common_3.Enabled).toBe(true)
		expect(promptMismatches(rig)).toBe("")
	end)

	it("refuses a grab fired on an empty nest: no egg, no Carrying, no grabbed", function()
		local rig = newNestRig({ newSpot("Common_1", "Common", 0), newSpot("Common_2", "Common", 50) })
		local grabbedCount = 0
		rig.grab.grabbed:Connect(function()
			grabbedCount += 1
		end)
		local player = newPlayer(1, rig.spots[2].promptAnchor.WorldPosition + Vector3.new(3, 0, 0))
		rig.prompts.Common_2.Triggered:Fire(player) -- Common_2 holds no egg
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(eggOnBack(player)).toBeNil()
		expect(grabbedCount).toBe(0)
		expect(eggNames(rig)).toBe("Common_1")
	end)

	it("waits to refill while a player stands near the only free nest, and refills once they move away", function()
		local rig = newNestRig({ newSpot("Common_1", "Common", 0), newSpot("Common_2", "Common", 50) })
		local player = grabThenStand(rig, NEAR)
		local due = START_TIME + Config.Rarity.Common.RefillSeconds
		rig.setTime(due)
		rig.grab:step()
		expect(eggNames(rig)).toBe("")
		player.root.Position = rig.spots[2].cframe.Position - Vector3.new(FAR, 0, 0)
		rig.setTime(due + Config.Nests.RetrySeconds)
		rig.grab:step()
		expect(eggNames(rig)).toBe("Common_2")
	end)

	it("fires refilled once, with the rank and the seconds the refill waited, after the egg shows", function()
		local rig = newNestRig({ newSpot("Common_1", "Common", 0), newSpot("Common_2", "Common", 50) })
		local fired: { { rank: string, waited: number, eggs: string } } = {}
		rig.grab.refilled:Connect(function(rank: string, waited: number)
			table.insert(fired, { rank = rank, waited = waited, eggs = eggNames(rig) })
		end)
		local player = grabThenStand(rig, NEAR)
		local due = START_TIME + Config.Rarity.Common.RefillSeconds
		rig.setTime(due)
		rig.grab:step()
		expect(#fired).toBe(0)
		player.root.Position = rig.spots[2].cframe.Position - Vector3.new(FAR, 0, 0)
		rig.setTime(due + Config.Nests.RetrySeconds)
		rig.grab:step()
		expect(#fired).toBe(1)
		expect(fired[1].rank).toBe("Common")
		expect(fired[1].waited).toBe(Config.Nests.RetrySeconds)
		expect(fired[1].eggs).toBe("Common_2")
	end)

	it("slotsFor caps a rank of bare spots at its spot count minus one, and never above its Config slots", function()
		local slots: any = Grab.slotsFor({ -- read by name; the type checker can't index its rank-keyed map
			newSpot("Common_1", "Common", 0),
			newSpot("Common_2", "Common", 50),
			newSpot("Common_3", "Common", 100),
			newSpot("Uncommon_1", "Uncommon", 150),
			newSpot("Epic_1", "Epic", 200),
			newSpot("Epic_2", "Epic", 250),
			newSpot("Epic_3", "Epic", 300),
			newSpot("Epic_4", "Epic", 350),
		})
		expect(slots.Common).toBe(2) -- 3 spots, Config allows 8
		expect(slots.Uncommon).toBe(0) -- 1 spot
		expect(slots.Epic).toBe(Config.Rarity.Epic.Slots) -- 4 spots allow 3, Config allows 2
	end)
end)
