--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local EggSpots = require(ServerScriptService.Server.Eggs.EggSpots)

-- One spot of each rarity, plus a second Common spot.
local function newState()
	return EggSpots.new({
		{ name = "Common1", rarity = "Common" },
		{ name = "Common2", rarity = "Common" },
		{ name = "Uncommon1", rarity = "Uncommon" },
		{ name = "Rare1", rarity = "Rare" },
	})
end

local function isWaiting(state: EggSpots.State, spotName: string): boolean
	local view = EggSpots.spot(state, spotName)
	assert(view ~= nil, "no such spot: " .. spotName)
	return view.waiting
end

describe("EggSpots.new", function()
	it("starts every spot with its egg waiting and no countdown", function()
		local state = newState()
		for _, name in { "Common1", "Common2", "Uncommon1", "Rare1" } do
			local view = EggSpots.spot(state, name)
			expect(view).toEqual({ waiting = true, refillAt = nil })
		end
	end)

	it("knows nothing about a spot that does not exist", function()
		expect(EggSpots.spot(newState(), "Nope")).toBe(nil)
	end)
end)

describe("EggSpots.take", function()
	it("puts the spot's egg on the player's back and empties the spot", function()
		local state = newState()
		local ok, reason = EggSpots.take(state, "Uncommon1", 7, 100)
		expect(ok).toBe(true)
		expect(reason).toBe(nil)
		expect(EggSpots.carrying(state, 7)).toBe("Uncommon")
		expect(isWaiting(state, "Uncommon1")).toBe(false)
	end)

	it("starts the refill countdown at the grab", function()
		local state = newState()
		EggSpots.take(state, "Rare1", 7, 100)
		expect((EggSpots.spot(state, "Rare1") :: EggSpots.SpotView).refillAt).toBe(160)
	end)

	it("refuses a second take of the same egg, and the first taker keeps it", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 50)
		local ok, reason = EggSpots.take(state, "Common1", 2, 50)
		expect(ok).toBe(false)
		expect(reason).toBe("no egg")
		expect(EggSpots.carrying(state, 1)).toBe("Common")
		expect(EggSpots.carrying(state, 2)).toBe(nil)
	end)

	it("refuses a player who already carries an egg, and leaves the other spot untouched", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 50)
		local ok, reason = EggSpots.take(state, "Rare1", 1, 51)
		expect(ok).toBe(false)
		expect(reason).toBe("already carrying")
		expect(EggSpots.carrying(state, 1)).toBe("Common")
		expect(isWaiting(state, "Rare1")).toBe(true)
	end)

	it("refuses a spot that does not exist", function()
		local ok, reason = EggSpots.take(newState(), "Nope", 1, 0)
		expect(ok).toBe(false)
		expect(reason).toBe("unknown spot")
	end)
end)

describe("EggSpots.update", function()
	local cases = {
		{ spot = "Common1", seconds = 10 },
		{ spot = "Uncommon1", seconds = 30 },
		{ spot = "Rare1", seconds = 60 },
	}
	for _, case in cases do
		it(`refills a taken {case.spot} after {case.seconds} seconds, and not 0.1 seconds before`, function()
			local state = newState()
			EggSpots.take(state, case.spot, 1, 200)
			expect(EggSpots.update(state, 200 + case.seconds - 0.1)).toEqual({})
			expect(isWaiting(state, case.spot)).toBe(false)
			expect(EggSpots.update(state, 200 + case.seconds)).toEqual({ case.spot })
			expect(isWaiting(state, case.spot)).toBe(true)
			expect((EggSpots.spot(state, case.spot) :: EggSpots.SpotView).refillAt).toBe(nil)
		end)
	end

	it("names a refilled spot only once", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		expect(EggSpots.update(state, 10)).toEqual({ "Common1" })
		expect(EggSpots.update(state, 11)).toEqual({})
	end)

	it("refills even though the player who took the egg is still carrying it", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.update(state, 10)
		expect(EggSpots.carrying(state, 1)).toBe("Common")
		expect(isWaiting(state, "Common1")).toBe(true)
	end)

	it("lists every spot that finished in the same step", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.take(state, "Common2", 2, 0)
		expect(EggSpots.update(state, 10)).toEqual({ "Common1", "Common2" })
	end)

	it("lets a new player take the egg once the spot refilled", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.update(state, 10)
		local ok = EggSpots.take(state, "Common1", 2, 10)
		expect(ok).toBe(true)
		expect((EggSpots.spot(state, "Common1") :: EggSpots.SpotView).refillAt).toBe(20)
	end)
end)

describe("EggSpots.returnEgg", function()
	it("puts the egg back on its spot while the spot is still counting down, and stops the countdown", function()
		local state = newState()
		EggSpots.take(state, "Rare1", 1, 100)
		local result, spotName = EggSpots.returnEgg(state, 1)
		expect(result).toBe("back")
		expect(spotName).toBe("Rare1")
		expect(EggSpots.spot(state, "Rare1")).toEqual({ waiting = true, refillAt = nil })
		expect(EggSpots.carrying(state, 1)).toBe(nil)
	end)

	it("refills nothing at the old refill time after an egg sat back", function()
		local state = newState()
		EggSpots.take(state, "Rare1", 1, 100)
		EggSpots.returnEgg(state, 1)
		expect(EggSpots.update(state, 160)).toEqual({})
		expect(isWaiting(state, "Rare1")).toBe(true)
	end)

	it("lets the egg that sat back be taken again, with a fresh countdown from the new grab", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.returnEgg(state, 1)
		local ok = EggSpots.take(state, "Common1", 2, 5)
		expect(ok).toBe(true)
		expect((EggSpots.spot(state, "Common1") :: EggSpots.SpotView).refillAt).toBe(15)
		expect(EggSpots.update(state, 10)).toEqual({})
	end)

	it("lets the same player take an egg again after theirs went back", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.returnEgg(state, 1)
		expect((EggSpots.take(state, "Common2", 1, 2))).toBe(true)
	end)

	it("makes the returned egg disappear when its spot already refilled, and the spot still holds one egg", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.update(state, 10)
		local result, spotName = EggSpots.returnEgg(state, 1)
		expect(result).toBe("gone")
		expect(spotName).toBe("Common1")
		expect(EggSpots.spot(state, "Common1")).toEqual({ waiting = true, refillAt = nil })
		expect(EggSpots.carrying(state, 1)).toBe(nil)
		-- Exactly one egg to take, then nothing.
		expect((EggSpots.take(state, "Common1", 2, 12))).toBe(true)
		expect((EggSpots.take(state, "Common1", 3, 12))).toBe(false)
	end)

	it(
		"puts the egg back on a spot that was refilled and taken again by someone else, and stops that countdown",
		function()
			local state = newState()
			EggSpots.take(state, "Common1", 1, 0)
			EggSpots.update(state, 10)
			EggSpots.take(state, "Common1", 2, 11)
			-- Player 1's old egg goes back to the spot that is counting down; the spot is waiting again.
			local result = EggSpots.returnEgg(state, 1)
			expect(result).toBe("back")
			expect(isWaiting(state, "Common1")).toBe(true)
			-- Player 2 still carries the egg they took, and returning it now makes it disappear.
			expect((EggSpots.returnEgg(state, 2))).toBe("gone")
		end
	)

	it("does nothing and returns nil for a player who carries nothing", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		local result, spotName = EggSpots.returnEgg(state, 2)
		expect(result).toBe(nil)
		expect(spotName).toBe(nil)
		expect(isWaiting(state, "Common1")).toBe(false)
		expect(EggSpots.carrying(state, 1)).toBe("Common")
	end)

	it("returns nil the second time for the same player", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.returnEgg(state, 1)
		expect((EggSpots.returnEgg(state, 1))).toBe(nil)
	end)
end)

describe("EggSpots.bank", function()
	it("takes the egg to the garden: the player carries nothing, and the answer names the spot and rarity", function()
		local state = newState()
		EggSpots.take(state, "Uncommon1", 1, 100)
		local spotName, rarity = EggSpots.bank(state, 1)
		expect(spotName).toBe("Uncommon1")
		expect(rarity).toBe("Uncommon")
		expect(EggSpots.carrying(state, 1)).toBe(nil)
	end)

	it("keeps the spot counting down as it was", function()
		local state = newState()
		EggSpots.take(state, "Uncommon1", 1, 100)
		EggSpots.bank(state, 1)
		expect(EggSpots.spot(state, "Uncommon1")).toEqual({ waiting = false, refillAt = 130 })
		expect(EggSpots.update(state, 129.9)).toEqual({})
		expect(EggSpots.update(state, 130)).toEqual({ "Uncommon1" })
	end)

	it("lets the player carry another egg afterwards", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		EggSpots.bank(state, 1)
		expect((EggSpots.take(state, "Common2", 1, 1))).toBe(true)
	end)

	it("does nothing and returns nil for a player who carries nothing", function()
		local state = newState()
		EggSpots.take(state, "Common1", 1, 0)
		local spotName, rarity = EggSpots.bank(state, 2)
		expect(spotName).toBe(nil)
		expect(rarity).toBe(nil)
		expect(EggSpots.spot(state, "Common1")).toEqual({ waiting = false, refillAt = 10 })
		expect(EggSpots.carrying(state, 1)).toBe("Common")
	end)
end)

describe("EggSpots keeps every egg in exactly one place", function()
	local SPOT_NAMES = { "Common1", "Common2", "Uncommon1", "Rare1" }
	local PLAYER_IDS = { 1, 2, 3 }
	local STEPS = 1500

	it("holds through a long scripted run of takes, updates, returns and banks", function()
		local state = newState()

		-- A small fixed pseudo-random generator, so the run is the same every time.
		local seed = 12345
		local function random(limit: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % limit + 1
		end

		-- Our own count of eggs, kept from the answers the module gives.
		-- Every spot starts with one egg. A refill makes an egg; a "gone" return destroys one.
		local created = #SPOT_NAMES
		local destroyed = 0
		local banked = 0
		local carriedFrom: { [number]: string } = {}
		local seen = { back = 0, gone = 0, banks = 0, refills = 0, refused = 0, taken = 0 }
		local now = 0

		local function checkEveryEggIsInOnePlace(step: number)
			local waiting = 0
			for _, spotName in SPOT_NAMES do
				local view = EggSpots.spot(state, spotName) :: EggSpots.SpotView
				-- A spot holds at most one egg: it is either waiting (no countdown) or empty (counting down).
				expect(view.waiting).toBe(view.refillAt == nil)
				if view.waiting then
					waiting += 1
				end
			end
			local carriers = 0
			for _, playerId in PLAYER_IDS do
				local rarity = EggSpots.carrying(state, playerId)
				local from = carriedFrom[playerId]
				-- One egg at most per player, and it is the egg of the spot we saw them take.
				expect(rarity ~= nil).toBe(from ~= nil)
				if from ~= nil then
					carriers += 1
				end
			end
			-- Waiting on a spot, or on a player's back, or banked: all eggs added up, nothing lost, nothing doubled.
			if waiting + carriers + banked ~= created - destroyed then
				error(
					`step {step}: {waiting} waiting + {carriers} carried + {banked} banked ~= {created} - {destroyed}`
				)
			end
		end

		for step = 1, STEPS do
			local action = random(10)
			local playerId = PLAYER_IDS[random(#PLAYER_IDS)]
			if action <= 4 then
				local spotName = SPOT_NAMES[random(#SPOT_NAMES)]
				local view = EggSpots.spot(state, spotName) :: EggSpots.SpotView
				local shouldWork = view.waiting and carriedFrom[playerId] == nil
				local ok = EggSpots.take(state, spotName, playerId, now)
				expect(ok).toBe(shouldWork)
				if ok then
					carriedFrom[playerId] = spotName
					seen.taken += 1
				else
					seen.refused += 1
				end
			elseif action <= 6 then
				now += random(40) - 1
				local refilled = EggSpots.update(state, now)
				created += #refilled
				seen.refills += #refilled
			elseif action <= 8 then
				local result, spotName = EggSpots.returnEgg(state, playerId)
				if carriedFrom[playerId] == nil then
					expect(result).toBe(nil)
				else
					expect(spotName).toBe(carriedFrom[playerId])
					if result == "gone" then
						destroyed += 1
						seen.gone += 1
					else
						expect(result).toBe("back")
						seen.back += 1
					end
					carriedFrom[playerId] = nil
				end
			else
				local spotName = EggSpots.bank(state, playerId)
				if carriedFrom[playerId] == nil then
					expect(spotName).toBe(nil)
				else
					expect(spotName).toBe(carriedFrom[playerId])
					banked += 1
					seen.banks += 1
					carriedFrom[playerId] = nil
				end
			end
			checkEveryEggIsInOnePlace(step)
		end

		-- The run must really have met every kind of event, or the checks above prove little.
		expect(seen.taken).toBeGreaterThan(50)
		expect(seen.refused).toBeGreaterThan(50)
		expect(seen.refills).toBeGreaterThan(50)
		expect(seen.back).toBeGreaterThan(20)
		expect(seen.gone).toBeGreaterThan(5)
		expect(seen.banks).toBeGreaterThan(20)
	end)
end)
