--!strict
-- The state of every egg spot: waiting, or counting down to refill after its egg was taken.
-- Pure logic: no Instances, no services. The clock is passed in as a number (seconds), so tests control time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type SpotDefinition = { name: string, rarity: Config.RarityName }

-- What a caller may read about one spot. refillAt is only there while the spot is counting down.
export type SpotView = { waiting: boolean, refillAt: number? }

type Spot = {
	name: string,
	rarity: Config.RarityName,
	waiting: boolean,
	refillAt: number?,
}

export type State = {
	spots: { [string]: Spot },
	-- Spot names in the order they were given, so results always come out in the same order.
	order: { string },
	-- The spot each player's carried egg came from. A player carries at most one egg.
	carried: { [number]: string },
}

local EggSpots = {}

-- Every spot starts with its egg waiting.
function EggSpots.new(definitions: { SpotDefinition }): State
	local state: State = { spots = {}, order = {}, carried = {} }
	for _, definition in definitions do
		assert(state.spots[definition.name] == nil, `duplicate egg spot: {definition.name}`)
		assert(Config.Rarity[definition.rarity] ~= nil, `unknown rarity: {definition.rarity}`)
		state.spots[definition.name] = {
			name = definition.name,
			rarity = definition.rarity,
			waiting = true,
			refillAt = nil,
		}
		table.insert(state.order, definition.name)
	end
	return state
end

-- The player grabs the egg on a spot. Fails with a reason when the spot is unknown, the player already carries an
-- egg, or the spot has no egg waiting (someone got it first). On success the spot is empty and its refill
-- countdown starts now.
function EggSpots.take(state: State, spotName: string, playerId: number, now: number): (boolean, string?)
	local spot = state.spots[spotName]
	if spot == nil then
		return false, "unknown spot"
	end
	if state.carried[playerId] ~= nil then
		return false, "already carrying"
	end
	if not spot.waiting then
		return false, "no egg"
	end
	spot.waiting = false
	spot.refillAt = now + Config.Rarity[spot.rarity].RefillSeconds
	state.carried[playerId] = spotName
	return true, nil
end

-- Refills every spot whose countdown has ended and returns their names. A spot refills even if someone stands on it
-- or the player who took its egg is still carrying it.
function EggSpots.update(state: State, now: number): { string }
	local refilled: { string } = {}
	for _, name in state.order do
		local spot = state.spots[name]
		local refillAt = spot.refillAt
		if not spot.waiting and refillAt ~= nil and now >= refillAt then
			spot.waiting = true
			spot.refillAt = nil
			table.insert(refilled, name)
		end
	end
	return refilled
end

-- The player's carried egg goes back to its own spot. Used when they leave, reset, fall out of the world or are
-- caught. Returns what happened and the spot's name, or nil if the player carries nothing.
--   "back": the spot was still counting down, so the egg sits on it again, the countdown stops and the spot is
--           waiting.
--   "gone": the spot already refilled, so the returned egg disappears (the spot pops) and the spot keeps its one egg.
function EggSpots.returnEgg(state: State, playerId: number): (("back" | "gone")?, string?)
	local spotName = state.carried[playerId]
	if spotName == nil then
		return nil, nil
	end
	state.carried[playerId] = nil
	local spot = state.spots[spotName]
	if spot.waiting then
		return "gone", spotName
	end
	spot.waiting = true
	spot.refillAt = nil
	return "back", spotName
end

-- The player's carried egg leaves the game world for their garden. The spot keeps counting down as it was.
-- Returns the spot's name and the egg's rarity, or nil if the player carries nothing.
function EggSpots.bank(state: State, playerId: number): (string?, Config.RarityName?)
	local spotName = state.carried[playerId]
	if spotName == nil then
		return nil, nil
	end
	state.carried[playerId] = nil
	return spotName, state.spots[spotName].rarity
end

-- A copy of what one spot looks like right now, or nil if there is no such spot.
function EggSpots.spot(state: State, spotName: string): SpotView?
	local spot = state.spots[spotName]
	if spot == nil then
		return nil
	end
	return { waiting = spot.waiting, refillAt = spot.refillAt }
end

-- The rarity of the egg this player carries, or nil if they carry nothing.
function EggSpots.carrying(state: State, playerId: number): Config.RarityName?
	local spotName = state.carried[playerId]
	if spotName == nil then
		return nil
	end
	return state.spots[spotName].rarity
end

return EggSpots
