--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local EggSlots = require(ServerScriptService.Server.Eggs.EggSlots)

local NEST_SPACING = 10 -- studs between fake nests on x
-- Config is frozen through a generic helper, so its rank names read as plain strings here: say what they are.
local RANKS = Config.RarityOrder :: { Config.RarityName }

-- Each rank's Config nest count, named <Rank><n>, 10 studs apart on x. Slots come from Config.
local function newWorld()
	local nests: { EggSlots.NestDefinition } = {}
	local slotsPerRank: { [Config.RarityName]: number } = {}
	local x = 0
	for _, rank: Config.RarityName in RANKS do
		slotsPerRank[rank] = Config.Rarity[rank].Slots
		for n = 1, Config.Rarity[rank].Nests do
			table.insert(nests, { name = `{rank}{n}`, rank = rank, position = Vector3.new(x, 0, 0) })
			x += NEST_SPACING
		end
	end
	return nests, slotsPerRank
end

local function newState(): EggSlots.State
	local nests, slotsPerRank = newWorld()
	return EggSlots.new(nests, slotsPerRank)
end

local function pickFirst(_count: number): number
	return 1
end

local function isWaiting(state: EggSlots.State, nestName: string): boolean
	local view = EggSlots.nest(state, nestName)
	assert(view ~= nil, "no such nest: " .. nestName)
	return view.waiting
end

local function countWaiting(state: EggSlots.State, rank: Config.RarityName): number
	local count = 0
	for n = 1, Config.Rarity[rank].Nests do
		if isWaiting(state, `{rank}{n}`) then
			count += 1
		end
	end
	return count
end

describe("EggSlots.new", function()
	it("starts with 4 Rare eggs waiting on 4 different Rare nests and 2 Rare nests empty", function()
		local state = newState()
		local waitingNests: { [string]: boolean } = {}
		local waiting = 0
		local empty = 0
		for n = 1, Config.Rarity.Rare.Nests do
			local name = `Rare{n}`
			if isWaiting(state, name) then
				waitingNests[name] = true
				waiting += 1
			else
				empty += 1
			end
		end
		expect(waiting).toBe(4)
		expect(empty).toBe(2)
		local distinct = 0
		for _ in waitingNests do
			distinct += 1
		end
		expect(distinct).toBe(4)
	end)
end)

describe("EggSlots.take", function()
	it("starts a 60-second countdown for a Rare slot", function()
		local state = newState()
		local ok = EggSlots.take(state, "Rare1", 1, 100)
		expect(ok).toBe(true)
		expect(EggSlots.update(state, 159.9, {}, pickFirst)).toEqual({})
		expect(#EggSlots.update(state, 160, {}, pickFirst)).toBe(1)
	end)

	it("starts a 60-second countdown for an Epic slot", function()
		local state = newState()
		local ok = EggSlots.take(state, "Epic1", 1, 100)
		expect(ok).toBe(true)
		expect(EggSlots.update(state, 159.9, {}, pickFirst)).toEqual({})
		expect(#EggSlots.update(state, 160, {}, pickFirst)).toBe(1)
	end)

	it("fails with no egg when the nest is empty", function()
		local state = newState()
		local ok, reason = EggSlots.take(state, "Rare5", 1, 0)
		expect(ok).toBe(false)
		expect(reason).toBe("no egg")
	end)

	it("fails with already carrying when the player carries an egg", function()
		local state = newState()
		EggSlots.take(state, "Rare1", 1, 0)
		local ok, reason = EggSlots.take(state, "Rare2", 1, 0)
		expect(ok).toBe(false)
		expect(reason).toBe("already carrying")
	end)

	it("fails with unknown nest when the name is not a nest", function()
		local ok, reason = EggSlots.take(newState(), "Nope", 1, 0)
		expect(ok).toBe(false)
		expect(reason).toBe("unknown nest")
	end)
end)

describe("EggSlots.bank and carrying", function()
	it("give the nest and rank while carrying, then nil", function()
		local state = newState()
		EggSlots.take(state, "Rare1", 1, 0)
		expect(EggSlots.carrying(state, 1)).toBe("Rare")
		local nestName, rank = EggSlots.bank(state, 1)
		expect(nestName).toBe("Rare1")
		expect(rank).toBe("Rare")
		expect(EggSlots.carrying(state, 1)).toBe(nil)
		local nestAgain, rankAgain = EggSlots.bank(state, 1)
		expect(nestAgain).toBe(nil)
		expect(rankAgain).toBe(nil)
	end)
end)

-- One rank with its nests on the x axis at the given x values, named <Rank><n> in the order given.
local function lineWorld(rank: Config.RarityName, xs: { number }, slots: number): EggSlots.State
	local nests: { EggSlots.NestDefinition } = {}
	for n, x in xs do
		table.insert(nests, { name = `{rank}{n}`, rank = rank, position = Vector3.new(x, 0, 0) })
	end
	return EggSlots.new(nests, { [rank] = slots })
end

-- Six Rare nests 20 studs apart (x 0 to 100): far enough that spacing never decides, only players and the taken nest.
local WIDE_RARE = { 0, 20, 40, 60, 80, 100 }
local RARE_REFILL = Config.Rarity.Rare.RefillSeconds

describe("EggSlots.update where the new egg lands", function()
	it("puts the new egg on neither the nest it was taken from nor a nest with a player 5 studs away", function()
		local state = lineWorld("Rare", WIDE_RARE, 4)
		EggSlots.take(state, "Rare1", 1, 0)
		local refills = EggSlots.update(state, RARE_REFILL, { Vector3.new(80, 0, 5) }, pickFirst)
		expect(#refills).toBe(1)
		expect(refills[1].nest).toBe("Rare6")
		expect(refills[1].rank).toBe("Rare")
		expect(refills[1].waited).toBe(0)
		expect(isWaiting(state, "Rare1")).toBe(false)
		expect(isWaiting(state, "Rare5")).toBe(false)
		local view = EggSlots.nest(state, "Rare6")
		expect(view ~= nil and view.rank).toBe("Rare")
	end)

	it("picks among exactly the allowed nests, so each of 3 comes up once", function()
		local expected = { "Rare4", "Rare5", "Rare6" }
		for k = 1, 3 do
			local state = lineWorld("Rare", WIDE_RARE, 3)
			EggSlots.take(state, "Rare1", 1, 0)
			local offered = 0
			local refills = EggSlots.update(state, RARE_REFILL, {}, function(count: number): number
				offered = count
				return k
			end)
			expect(offered).toBe(3)
			expect(#refills).toBe(1)
			expect(refills[1].nest).toBe(expected[k])
		end
	end)

	it("waits while every free nest has a player within 15 studs, then lands at the 1-second try", function()
		local state = lineWorld("Rare", WIDE_RARE, 4)
		EggSlots.take(state, "Rare1", 1, 0)
		local crowd = { Vector3.new(90, 0, 0) } -- 10 studs from Rare5 (x 80) and Rare6 (x 100)
		expect(#EggSlots.update(state, RARE_REFILL, crowd, pickFirst)).toBe(0)
		expect(isWaiting(state, "Rare5")).toBe(false)
		expect(isWaiting(state, "Rare6")).toBe(false)
		expect(#EggSlots.update(state, RARE_REFILL + 0.5, {}, pickFirst)).toBe(0)
		local refills = EggSlots.update(state, RARE_REFILL + Config.Nests.RetrySeconds, {}, pickFirst)
		expect(#refills).toBe(1)
		expect(refills[1].nest).toBe("Rare5")
		expect(refills[1].waited).toBe(Config.Nests.RetrySeconds)
	end)

	it("keeps the second of two due slots off the first one's nest and 6 studs away from it", function()
		-- Rare5 and Rare6 are 4 studs apart. Players stand on Rare1 to Rare4, so only those two are open.
		local state = lineWorld("Rare", { 0, 20, 40, 60, 80, 84 }, 2)
		EggSlots.take(state, "Rare1", 1, 0)
		EggSlots.take(state, "Rare2", 2, 0)
		local players = { Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), Vector3.new(40, 0, 0), Vector3.new(60, 0, 0) }
		local refills = EggSlots.update(state, RARE_REFILL, players, pickFirst)
		expect(#refills).toBe(1)
		expect(refills[1].nest).toBe("Rare5")
		expect(isWaiting(state, "Rare6")).toBe(false)
	end)

	it("keeps a second Epic egg off the left cuff's nest that is 5.5 studs from the first", function()
		-- Epic1 and Epic3 are the left cuff, 5.5 apart. Epic2 and Epic4 are on the right cuff, far away.
		local state = lineWorld("Epic", { 0, 100, 5.5, 200 }, 2)
		expect(isWaiting(state, "Epic1")).toBe(true)
		expect(isWaiting(state, "Epic2")).toBe(true)
		EggSlots.take(state, "Epic2", 1, 0)
		local refills = EggSlots.update(state, Config.Rarity.Epic.RefillSeconds, {}, pickFirst)
		expect(#refills).toBe(1)
		expect(refills[1].nest).toBe("Epic4")
		expect(isWaiting(state, "Epic3")).toBe(false)
	end)

	it("allows a nest exactly 6 studs from a waiting egg and exactly 15 studs from a player", function()
		local state = lineWorld("Rare", { 0, 6, 12 }, 2)
		EggSlots.take(state, "Rare1", 1, 0)
		-- Rare3 is 6 from the egg on Rare2; the player is 15 above Rare3 (distances are 3D).
		local refills = EggSlots.update(state, RARE_REFILL, { Vector3.new(12, 15, 0) }, pickFirst)
		expect(#refills).toBe(1)
		expect(refills[1].nest).toBe("Rare3")
	end)
end)

describe("EggSlots.new spacing", function()
	it("never starts eggs on two nests 4 studs apart", function()
		local state = lineWorld("Rare", { 0, 4, 20 }, 2)
		expect(isWaiting(state, "Rare1")).toBe(true)
		expect(isWaiting(state, "Rare2")).toBe(false)
		expect(isWaiting(state, "Rare3")).toBe(true)
	end)
end)

describe("EggSlots over a long random run", function()
	it("never has more eggs waiting plus carried from a live countdown than slots", function()
		local rng = Random.new(7)
		local state = newState()
		local nests, _ = newWorld()
		local now = 0
		-- The rank and countdown end of each player's carried egg, kept by the test itself.
		local liveCarried: { [number]: { rank: Config.RarityName, endsAt: number } } = {}
		local function pick(count: number): number
			return rng:NextInteger(1, count)
		end
		for step = 1, 1000 do
			local action = rng:NextInteger(1, 3)
			if action == 1 then
				local playerId = rng:NextInteger(1, 5)
				local nest = nests[rng:NextInteger(1, #nests)]
				local ok = EggSlots.take(state, nest.name, playerId, now)
				if ok then
					liveCarried[playerId] = { rank = nest.rank, endsAt = now + Config.Rarity[nest.rank].RefillSeconds }
				end
			elseif action == 2 then
				local playerId = rng:NextInteger(1, 5)
				EggSlots.bank(state, playerId)
				liveCarried[playerId] = nil
			else
				now += rng:NextNumber() * 30
				EggSlots.update(state, now, {}, pick)
			end
			for _, rank: Config.RarityName in RANKS do
				local live = 0
				for _, carried in liveCarried do
					if carried.rank == rank and now < carried.endsAt then
						live += 1
					end
				end
				local total = countWaiting(state, rank) + live
				if total > Config.Rarity[rank].Slots then
					error(`step {step}: {rank} has {total} eggs, slots {Config.Rarity[rank].Slots}`)
				end
			end
		end
	end)
end)
