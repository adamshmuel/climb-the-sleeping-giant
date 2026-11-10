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
	removing: any, -- the PlayerRemoving signal: Fire(player) after taking them out of `standers`
	setTime: (seconds: number) -> (),
	setPhase: (phase: Config.Phase) -> (), -- what the `phase` dep reads (Task 7c); starts at "Asleep"
}

-- `slots` is the slotsPerRank dep; left out, Grab works it out from the spots.
local function newNestRig(spots: { WorldIndex.EggSpot }, slots: { [Config.RarityName]: number }?): NestRig
	local prompts: { [string]: any } = {}
	local standers: { FakePlayer } = {}
	local removing = newSignal()
	local time = START_TIME
	local phase: Config.Phase = "Asleep"
	local deps: Grab.Deps = {
		spots = spots,
		slotsPerRank = slots,
		templates = { Common = newTemplate("Common"), Uncommon = newTemplate("Uncommon"), Rare = newTemplate("Rare") },
		carriedOffset = CFrame.new(0, 0.8, 1.9),
		carriedHeight = 4.2,
		players = {
			PlayerRemoving = removing,
			GetPlayers = function()
				return standers :: any -- fake players carry more fields than Grab reads
			end,
		},
		heartbeat = newSignal(),
		grabMissed = function() end,
		now = function()
			return time
		end,
		phase = function(): Config.Phase
			return phase
		end,
		random = Random.new(1),
		createPrompt = function(anchor: Attachment, _rarity: Config.RarityName): any
			local prompt = { Triggered = newSignal(), Enabled = true, Destroy = function() end }
			prompts[((anchor.Parent :: Instance).Parent :: Instance).Name] = prompt
			return prompt
		end,
	}
	local grab = Grab.start(deps)
	table.insert(stops, function()
		grab:stop()
	end)
	return {
		grab = grab,
		spots = spots,
		prompts = prompts,
		standers = standers,
		removing = removing,
		setTime = function(seconds: number)
			time = seconds
		end,
		setPhase = function(value: Config.Phase)
			phase = value
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

-- Task 7c: the right cuff nests (ridesRightArm) lock while he is awake. Two Common cuff nests, both with an egg.
local CUFF_SLOTS: { [Config.RarityName]: number } = { Common = 2, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0 }
-- A fist that lands this long after the phase left Awake (a binary fraction, so the clock sums stay exact).
local FIST_AFTER_LEAVE = 0.25

local function newCuffSpot(name: string, x: number): WorldIndex.EggSpot
	local spot = newSpot(name, "Common", x)
	spot.ridesRightArm = true
	return spot
end

local function newCuffRig(): NestRig
	return newNestRig({ newCuffSpot("Common_1", 0), newCuffSpot("Common_2", 50) }, CUFF_SLOTS)
end

-- Sets the clock and the phase, then runs one step (the step is where the lock is checked).
local function stepAt(rig: NestRig, seconds: number, phase: Config.Phase)
	rig.setTime(seconds)
	rig.setPhase(phase)
	rig.grab:step()
end

-- The names of the nests whose prompt is on, joined with commas.
local function promptsOn(rig: NestRig): string
	local names: { string } = {}
	for _, spot in rig.spots do
		if rig.prompts[spot.name].Enabled then
			table.insert(names, spot.name)
		end
	end
	return table.concat(names, ",")
end

-- A new player stands 3 studs from nest `index` and fires its prompt.
local function grabAt(rig: NestRig, index: number): FakePlayer
	local player = newPlayer(index, rig.spots[index].promptAnchor.WorldPosition + Vector3.new(3, 0, 0))
	rig.prompts[rig.spots[index].name].Triggered:Fire(player)
	return player
end

describe("Grab on the right cuff nests", function()
	it("turns both prompts off while he is awake, and refuses a grab there", function()
		local rig = newCuffRig()
		local grabbedCount = 0
		rig.grab.grabbed:Connect(function()
			grabbedCount += 1
		end)
		expect(promptsOn(rig)).toBe("Common_1,Common_2") -- asleep: both can be grabbed
		stepAt(rig, START_TIME + 1, "Awake")
		expect(promptsOn(rig)).toBe("")
		local player = grabAt(rig, 1) -- Common_1 still holds its egg, but is locked
		expect(player:GetAttribute("Carrying")).toBeNil()
		expect(eggOnBack(player)).toBeNil()
		expect(grabbedCount).toBe(0)
		expect(eggNames(rig)).toBe("Common_1,Common_2")
	end)

	it("stays locked until UnlockSeconds after the phase leaves Awake, then unlocks", function()
		local rig = newCuffRig()
		local leftAt = START_TIME + 10
		stepAt(rig, START_TIME + 1, "Awake")
		stepAt(rig, leftAt, "HeavySleep") -- the first step that sees it leave
		stepAt(rig, leftAt + Config.Nests.UnlockSeconds - 0.1, "HeavySleep")
		expect(promptsOn(rig)).toBe("")
		expect(eggOnBack(grabAt(rig, 1))).toBeNil() -- refused
		stepAt(rig, leftAt + Config.Nests.UnlockSeconds, "HeavySleep") -- strict "less than": exactly UnlockSeconds is open
		expect(promptsOn(rig)).toBe("Common_1,Common_2")
		expect(eggOnBack(grabAt(rig, 2))).never.toBeNil()
	end)

	it("stays locked until ArmReturnSeconds after the last fist, even when UnlockSeconds has passed", function()
		local rig = newCuffRig()
		local leftAt = START_TIME + 10
		local fistAt = leftAt + FIST_AFTER_LEAVE
		-- The fist is closer than ArmReturnSeconds to the moment UnlockSeconds ends, so the fist is what holds the lock.
		expect(fistAt + Config.Nests.ArmReturnSeconds > leftAt + Config.Nests.UnlockSeconds).toBe(true)
		stepAt(rig, START_TIME + 1, "Awake")
		stepAt(rig, leftAt, "HeavySleep")
		rig.setTime(fistAt)
		rig.grab:noteFist()
		stepAt(rig, leftAt + Config.Nests.UnlockSeconds, "HeavySleep")
		expect(promptsOn(rig)).toBe("") -- the phase part is done, the arm is not
		stepAt(rig, fistAt + Config.Nests.ArmReturnSeconds, "HeavySleep")
		expect(promptsOn(rig)).toBe("Common_1,Common_2")
	end)

	it("unlocks once the phase leaves Awake even when the last player has left", function()
		local rig = newCuffRig()
		local player = newPlayer(1, rig.spots[1].promptAnchor.WorldPosition + Vector3.new(3, 0, 0))
		table.insert(rig.standers, player)
		stepAt(rig, START_TIME + 1, "Awake")
		table.remove(rig.standers, 1)
		rig.removing:Fire(player)
		stepAt(rig, START_TIME + 2, "Awake")
		expect(promptsOn(rig)).toBe("") -- nobody is there, and it stays locked while he is awake
		local leftAt = START_TIME + 10
		stepAt(rig, leftAt, "Asleep")
		stepAt(rig, leftAt + Config.Nests.UnlockSeconds, "Asleep")
		expect(promptsOn(rig)).toBe("Common_1,Common_2")
	end)

	it("keeps the prompt off for an egg lost back to a locked nest, until the unlock", function()
		local rig = newCuffRig()
		local player = grabAt(rig, 1) -- asleep: grabbed, Common_1 is empty
		expect(rig.prompts.Common_1.Enabled).toBe(false)
		stepAt(rig, START_TIME + 1, "Awake")
		rig.grab:returnEgg(player, "Lost")
		expect(eggNames(rig)).toBe("Common_1,Common_2") -- the egg sits there again
		expect(promptsOn(rig)).toBe("")
		local leftAt = START_TIME + 10
		stepAt(rig, leftAt, "HeavySleep")
		stepAt(rig, leftAt + Config.Nests.UnlockSeconds, "HeavySleep")
		expect(promptsOn(rig)).toBe("Common_1,Common_2")
	end)
end)
