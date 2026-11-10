--!strict
-- The egg slots of every rank: how many eggs of a rank wait at once, and which nest each one sits on (Rule 71).
-- Pure logic: no Instances, no services. The clock is passed in as a number (seconds), so tests control time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- `garden` is a garden index, set only on meadow nests (Rule 75). A rank is a meadow rank when all its nests have one.
export type NestDefinition = { name: string, rank: Config.RarityName, position: Vector3, garden: number? }

-- What a caller may read about one nest. There is no refill time: an empty nest shows no timer (Rule 77).
-- `locked` is true while the nest is on his raised arm: no grab and no refill (Rule 100).
export type NestView = { waiting: boolean, rank: Config.RarityName, locked: boolean }

-- What `update` reports for each egg it placed: the nest, its rank, and how many seconds after the countdown ended it
-- landed (0 on time, more when no nest was allowed at first).
export type Refill = { nest: string, rank: Config.RarityName, waited: number }

-- One egg of a rank. While it waits it sits on a nest; after a take it counts down to a refill.
type Slot = {
	rank: Config.RarityName,
	-- When the slot next tries to place its egg: the countdown's end, then every retry. nil while the egg waits.
	refillAt: number?,
	-- When the countdown ended. Stays the same across retries, so `waited` can be worked out. nil while the egg waits.
	dueAt: number?,
	-- The nest the egg was last taken from. The new egg never lands there. nil before the first take.
	lastNest: string?,
	-- The garden this slot belongs to (a meadow slot), or nil. Its egg only ever sits on that garden's 2 nests.
	garden: number?,
	-- How many times this slot's egg has been taken. A carried egg remembers the value at its take (Rule 78).
	takes: number,
}

type Nest = {
	name: string,
	rank: Config.RarityName,
	position: Vector3,
	garden: number?,
	-- True while the nest is locked (see `setLocked`).
	locked: boolean,
	-- The slot whose egg waits here, or nil when the nest is empty.
	slot: Slot?,
}

-- An egg a player carries. It remembers the slot it came from.
type Carried = {
	nest: string,
	rank: Config.RarityName,
	slot: Slot,
	-- The slot's take counter at the moment this egg was taken.
	takes: number,
}

export type State = {
	nests: { [string]: Nest },
	-- Nest names in the order they were given, so results always come out in the same order.
	order: { string },
	-- Every slot, in the order of Config.RarityOrder, then slot number.
	slots: { Slot },
	-- The egg each player carries. A player carries at most one egg.
	carried: { [number]: Carried },
}

local EggSlots = {}

-- The nests of a rank where a new egg may land, in the order given (Rules 74, 76 and 100): no egg waiting, not locked,
-- not `lastNest`, at least Config.Nests.EggSpacing studs from every waiting egg, and at least Config.Nests.PlayerDistance studs from
-- every player. A distance equal to the limit is allowed. Distances are 3D. A locked nest's waiting egg still counts
-- for the spacing.
local function allowedNests(state: State, rank: Config.RarityName, lastNest: string?, playersAt: { Vector3 }): { Nest }
	local allowed: { Nest } = {}
	for _, name in state.order do
		local nest = state.nests[name]
		local clear = nest.rank == rank and nest.slot == nil and not nest.locked and name ~= lastNest
		if clear then
			for _, other in state.nests do
				if other.slot ~= nil and (other.position - nest.position).Magnitude < Config.Nests.EggSpacing then
					clear = false
					break
				end
			end
		end
		if clear then
			for _, playerAt in playersAt do
				if (playerAt - nest.position).Magnitude < Config.Nests.PlayerDistance then
					clear = false
					break
				end
			end
		end
		if clear then
			table.insert(allowed, nest)
		end
	end
	return allowed
end

-- A meadow rank (Rule 75): one slot per garden, starting on that garden's first nest in the order given. Every garden
-- has exactly 2 nests, and the slot count is the number of gardens. No spacing applies.
local function placeMeadowSlots(state: State, rank: Config.RarityName, rankNests: { Nest }, count: number)
	local gardens: { number } = {}
	local byGarden: { [number]: { Nest } } = {}
	for _, nest in rankNests do
		local garden = nest.garden :: number
		if byGarden[garden] == nil then
			byGarden[garden] = {}
			table.insert(gardens, garden)
		end
		table.insert(byGarden[garden], nest)
	end
	for _, garden in gardens do
		assert(#byGarden[garden] == 2, `{rank} garden {garden} has {#byGarden[garden]} nests, wanted 2`)
	end
	assert(count == #gardens, `{rank} has {count} slots but {#gardens} gardens`)
	for _, garden in gardens do
		local slot: Slot = { rank = rank, refillAt = nil, dueAt = nil, lastNest = nil, garden = garden, takes = 0 }
		byGarden[garden][1].slot = slot
		table.insert(state.slots, slot)
	end
end

-- Every slot starts with its egg waiting: slot i of a rank sits on the next nest of that rank, in the order given,
-- that is at least Config.Nests.EggSpacing studs from every egg already placed. A rank that can't fit all its slots
-- asserts. A rank whose nests all have a garden is a meadow rank (`placeMeadowSlots`); one that mixes garden and
-- no-garden nests asserts.
function EggSlots.new(nests: { NestDefinition }, slotsPerRank: { [Config.RarityName]: number }): State
	local state: State = { nests = {}, order = {}, slots = {}, carried = {} }
	local byRank: { [string]: { Nest } } = {}
	for _, definition in nests do
		assert(state.nests[definition.name] == nil, `duplicate egg nest: {definition.name}`)
		assert(Config.Rarity[definition.rank] ~= nil, `unknown rarity: {definition.rank}`)
		local nest: Nest = {
			name = definition.name,
			rank = definition.rank,
			position = definition.position,
			garden = definition.garden,
			locked = false,
			slot = nil,
		}
		state.nests[definition.name] = nest
		table.insert(state.order, definition.name)
		local list = byRank[definition.rank] or {}
		table.insert(list, nest)
		byRank[definition.rank] = list
	end
	for rank in slotsPerRank do
		assert(Config.Rarity[rank] ~= nil, `unknown rarity: {rank}`)
	end
	local ranks = Config.RarityOrder :: { Config.RarityName }
	for _, rank: Config.RarityName in ranks do
		local count = slotsPerRank[rank] or 0
		local rankNests: { Nest } = byRank[rank] or {}
		local withGarden = 0
		for _, nest in rankNests do
			if nest.garden ~= nil then
				withGarden += 1
			end
		end
		assert(withGarden == 0 or withGarden == #rankNests, `{rank} mixes garden nests and nests with no garden`)
		if withGarden > 0 then
			placeMeadowSlots(state, rank, rankNests, count)
			continue
		end
		assert(#rankNests >= count, `{rank} has {count} slots but only {#rankNests} nests`)
		for i = 1, count do
			local slot: Slot = { rank = rank, refillAt = nil, dueAt = nil, lastNest = nil, garden = nil, takes = 0 }
			local first = allowedNests(state, rank, nil, {})[1]
			assert(first ~= nil, `{rank} has {#rankNests} nests but only room for {i - 1} of {count} slots`)
			first.slot = slot
			table.insert(state.slots, slot)
		end
	end
	return state
end

-- Locks or unlocks each named nest (Rule 100). Only nests on him lock: asserts on an unknown name or a meadow nest
-- (one with a garden). A waiting egg stays on its nest when it locks.
function EggSlots.setLocked(state: State, nestNames: { string }, locked: boolean)
	for _, name in nestNames do
		local nest = state.nests[name]
		assert(nest ~= nil, `unknown egg nest: {name}`)
		assert(nest.garden == nil, `meadow nest {name} can't lock`)
		nest.locked = locked
	end
end

-- The player grabs the egg on a nest. Fails with a reason when the nest is unknown, the player already carries an
-- egg, the nest is locked, or the nest has no egg waiting, checked in that order. On success the nest is empty, its slot's refill countdown starts now, and the
-- player carries the egg.
function EggSlots.take(state: State, nestName: string, playerId: number, now: number): (boolean, string?)
	local nest = state.nests[nestName]
	if nest == nil then
		return false, "unknown nest"
	end
	if state.carried[playerId] ~= nil then
		return false, "already carrying"
	end
	if nest.locked then
		return false, "locked"
	end
	local slot = nest.slot
	if slot == nil then
		return false, "no egg"
	end
	nest.slot = nil
	slot.refillAt = now + Config.Rarity[nest.rank].RefillSeconds
	slot.dueAt = slot.refillAt
	slot.lastNest = nestName
	slot.takes += 1
	state.carried[playerId] = { nest = nestName, rank = nest.rank, slot = slot, takes = slot.takes }
	return true, nil
end

-- The other nest of a meadow slot's garden: the garden's nest of the slot's rank that is not `lastNest` (Rule 75). It is
-- empty, because the garden's one egg was taken from `lastNest`. Another rank may use the same garden number.
local function otherGardenNest(state: State, slot: Slot): Nest
	for _, name in state.order do
		local nest = state.nests[name]
		if nest.garden == slot.garden and nest.rank == slot.rank and name ~= slot.lastNest then
			assert(nest.slot == nil, `garden {slot.garden}'s other nest {name} is not empty`)
			return nest
		end
	end
	error(`garden {slot.garden} has no other nest than {slot.lastNest}`)
end

-- Refills every slot whose countdown has ended and returns the eggs it placed, in slot order. A slot refills even if
-- the player who took its egg is still carrying it. Its allowed nests are described at `allowedNests`; pick(count)
-- chooses one (1 to count). Eggs placed earlier in the same call count as waiting eggs. With no allowed nest the slot
-- stays due and tries again at now + Config.Nests.RetrySeconds, never sooner; the checks never relax.
-- A meadow slot (it has a garden, Rule 75) skips all that: its egg goes on its garden's other nest at the countdown's
-- end, with no spacing check, no player check, no wait, and `pick` is not called.
function EggSlots.update(state: State, now: number, playersAt: { Vector3 }, pick: (count: number) -> number): { Refill }
	local refilled: { Refill } = {}
	for _, slot in state.slots do
		local refillAt = slot.refillAt
		local dueAt = slot.dueAt
		if refillAt ~= nil and dueAt ~= nil and now >= refillAt and slot.garden ~= nil then
			local chosen = otherGardenNest(state, slot)
			chosen.slot = slot
			slot.refillAt = nil
			slot.dueAt = nil
			table.insert(refilled, { nest = chosen.name, rank = slot.rank, waited = now - dueAt })
		elseif refillAt ~= nil and dueAt ~= nil and now >= refillAt then
			local allowed = allowedNests(state, slot.rank, slot.lastNest, playersAt)
			if #allowed > 0 then
				local index = pick(#allowed)
				local chosen = allowed[index]
				assert(chosen ~= nil, `pick returned {index} for {#allowed} nests`)
				chosen.slot = slot
				slot.refillAt = nil
				slot.dueAt = nil
				table.insert(refilled, { nest = chosen.name, rank = slot.rank, waited = now - dueAt })
			else
				slot.refillAt = now + Config.Nests.RetrySeconds
			end
		end
	end
	return refilled
end

-- The player's carried egg leaves the game world for their garden. Its slot keeps counting down as it was.
-- Returns the nest's name and the egg's rank, or nil if the player carries nothing.
function EggSlots.bank(state: State, playerId: number): (string?, Config.RarityName?)
	local carried = state.carried[playerId]
	if carried == nil then
		return nil, nil
	end
	state.carried[playerId] = nil
	return carried.nest, carried.rank
end

-- The player's carried egg is lost (Rule 78) and leaves them. Returns the result and the nest it was taken from, or
-- nil, nil when they carry nothing.
-- "gone": the slot's new egg is already out (it sits on a nest, or was taken again after this egg), or another slot's
-- egg now sits on this nest. In the second case the slot's countdown keeps running as it was.
-- "back": otherwise the egg waits on its nest again, and the slot's countdown and any retry stop. No spacing check and
-- no player check.
function EggSlots.returnEgg(state: State, playerId: number): (("back" | "gone")?, string?)
	local carried = state.carried[playerId]
	if carried == nil then
		return nil, nil
	end
	state.carried[playerId] = nil
	local slot = carried.slot
	local nest = state.nests[carried.nest]
	local slotIsOut = slot.takes ~= carried.takes
	if not slotIsOut then
		for _, other in state.nests do
			if other.slot == slot then
				slotIsOut = true
				break
			end
		end
	end
	if slotIsOut or nest.slot ~= nil then
		return "gone", carried.nest
	end
	nest.slot = slot
	slot.refillAt = nil
	slot.dueAt = nil
	return "back", carried.nest
end

-- The rank of the egg this player carries, or nil if they carry nothing.
function EggSlots.carrying(state: State, playerId: number): Config.RarityName?
	local carried = state.carried[playerId]
	if carried == nil then
		return nil
	end
	return carried.rank
end

-- A copy of what one nest looks like right now, or nil if there is no such nest.
function EggSlots.nest(state: State, nestName: string): NestView?
	local nest = state.nests[nestName]
	if nest == nil then
		return nil
	end
	return { waiting = nest.slot ~= nil, rank = nest.rank, locked = nest.locked }
end

return EggSlots
