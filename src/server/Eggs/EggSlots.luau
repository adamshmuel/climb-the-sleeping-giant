--!strict
-- The egg slots of every rank: how many eggs of a rank wait at once, and which nest each one sits on (Rule 71).
-- Pure logic: no Instances, no services. The clock is passed in as a number (seconds), so tests control time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type NestDefinition = { name: string, rank: Config.RarityName, position: Vector3 }

-- What a caller may read about one nest. There is no refill time: an empty nest shows no timer (Rule 77).
export type NestView = { waiting: boolean, rank: Config.RarityName }

-- One egg of a rank. While it waits it sits on a nest; after a take it counts down to a refill (refillAt).
type Slot = {
	rank: Config.RarityName,
	refillAt: number?,
}

type Nest = {
	name: string,
	rank: Config.RarityName,
	position: Vector3,
	-- The slot whose egg waits here, or nil when the nest is empty.
	slot: Slot?,
}

-- An egg a player carries. It remembers the slot it came from.
type Carried = {
	nest: string,
	rank: Config.RarityName,
	slot: Slot,
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

-- Every slot starts with its egg waiting: slot i of a rank sits on that rank's i-th nest, in the order given.
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
		local rankNests = byRank[rank] or {}
		assert(#rankNests >= count, `{rank} has {count} slots but only {#rankNests} nests`)
		for i = 1, count do
			local slot: Slot = { rank = rank, refillAt = nil }
			rankNests[i].slot = slot
			table.insert(state.slots, slot)
		end
	end
	return state
end

-- The player grabs the egg on a nest. Fails with a reason when the nest is unknown, the player already carries an
-- egg, or the nest has no egg waiting. On success the nest is empty, its slot's refill countdown starts now, and the
-- player carries the egg.
function EggSlots.take(state: State, nestName: string, playerId: number, now: number): (boolean, string?)
	local nest = state.nests[nestName]
	if nest == nil then
		return false, "unknown nest"
	end
	if state.carried[playerId] ~= nil then
		return false, "already carrying"
	end
	local slot = nest.slot
	if slot == nil then
		return false, "no egg"
	end
	nest.slot = nil
	slot.refillAt = now + Config.Rarity[nest.rank].RefillSeconds
	state.carried[playerId] = { nest = nestName, rank = nest.rank, slot = slot }
	return true, nil
end

-- Refills every slot whose countdown has ended and returns the nest names, in slot order. A slot refills even if the
-- player who took its egg is still carrying it. Its allowed nests are its rank's nests with no egg waiting, in the
-- order given; pick(count) chooses one (1 to count). With no allowed nest the slot stays due. _playersAt is unused
-- until Task 3.
function EggSlots.update(
	state: State,
	now: number,
	_playersAt: { Vector3 },
	pick: (count: number) -> number
): { string }
	local refilled: { string } = {}
	for _, slot in state.slots do
		local refillAt = slot.refillAt
		if refillAt ~= nil and now >= refillAt then
			local allowed: { Nest } = {}
			for _, name in state.order do
				local nest = state.nests[name]
				if nest.rank == slot.rank and nest.slot == nil then
					table.insert(allowed, nest)
				end
			end
			if #allowed > 0 then
				local index = pick(#allowed)
				assert(allowed[index] ~= nil, `pick returned {index} for {#allowed} nests`)
				allowed[index].slot = slot
				slot.refillAt = nil
				table.insert(refilled, allowed[index].name)
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
	return { waiting = nest.slot ~= nil, rank = nest.rank }
end

return EggSlots
