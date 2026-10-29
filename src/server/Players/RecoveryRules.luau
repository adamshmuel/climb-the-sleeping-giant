--!strict
-- What a Reset does (Rules 25 to 33), as pure rules: no services, no clock. On the giant while he sleeps, a Reset moves
-- the player back to a safe spot. Awake, off the giant, or after too many recent moves, it sends the player home.
-- "On the giant" is any noise zone but the Meadow, or standing on the pillow (which lies in the Meadow zone). The Reset
-- and the rescue both ask `onGiant`, so they never disagree about where a player is.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Choice = "MoveBack" | "Home"

local RecoveryRules = {}

function RecoveryRules.onGiant(zone: Config.ZoneName, onPillow: boolean): boolean
	return zone ~= "Meadow" or onPillow
end

-- Only the moves of the last `LoopSeconds` (a move exactly that old still counts).
function RecoveryRules.recent(moves: { number }, now: number): { number }
	local kept = {}
	for _, at in moves do
		if now - at <= Config.Stuck.LoopSeconds then
			table.insert(kept, at)
		end
	end
	return kept
end

-- Whether one more move now would be the `LoopMoves`-th within `LoopSeconds` (Rule 29): a loop.
local function wouldLoop(recentMoves: { number }, now: number): boolean
	return #RecoveryRules.recent(recentMoves, now) >= Config.Stuck.LoopMoves - 1
end

function RecoveryRules.resetChoice(onGiant: boolean, phase: Config.Phase, recentMoves: { number }, now: number): Choice
	if not onGiant or phase == "Awake" then
		return "Home"
	end
	-- This move would be the next one: with `LoopMoves - 1` recent moves already, it is the third.
	if wouldLoop(recentMoves, now) then
		return "Home"
	end
	return "MoveBack"
end

-- A rescue (Rule 28) works in every giant phase: the player is awake and stuck, not asleep and hiding. A loop still
-- sends the player home. Rescues and Resets count together, so both pass the same recent moves.
function RecoveryRules.rescueChoice(recentMoves: { number }, now: number): Choice
	if wouldLoop(recentMoves, now) then
		return "Home"
	end
	return "MoveBack"
end

return RecoveryRules
