--!strict
-- The giant's warning marks. Pure maths: it is given numbers and returns numbers.
-- The marks and the re-arm drop come from Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Per mark: true = armed (it can fire). `quietUntil` is the clock reading when a free save's replayed 85% warning ends
-- (Rule 17); until then a pass of 85 fires nothing.
export type State = { [number]: boolean, quietUntil: number? }

local Warnings = {}

-- The mark a free save replays.
Warnings.FREE_SAVE_MARK = 85

function Warnings.new(): State
	local state: State = {}
	for _, mark in Config.Meter.WarningMarks do
		state[mark] = true
	end
	return state
end

-- A free save happened at `now`: for Config.Meter.FreeSaveWarningSeconds a pass of 85 fires nothing, because the save
-- already replays that warning. The pass still uses up the mark, so it fires again only after the meter falls to 75.
function Warnings.freeSave(state: State, now: number): State
	local newState = table.clone(state)
	newState.quietUntil = now + Config.Meter.FreeSaveWarningSeconds
	return newState
end

-- `now` is the clock reading for this step. Without it, no quiet window applies.
function Warnings.update(
	state: State,
	previousValue: number,
	value: number,
	phase: Config.Phase,
	now: number?
): ({ number }, State)
	local fired: { number } = {}
	local newState = table.clone(state)
	local quietUntil = state.quietUntil
	local quiet = quietUntil ~= nil and now ~= nil and now < quietUntil
	for _, mark in Config.Meter.WarningMarks do
		if value <= mark - Config.Meter.WarningRearmDrop then
			newState[mark] = true
		elseif phase == "Asleep" and newState[mark] and previousValue < mark and mark <= value then
			-- Only the 85 mark goes quiet; the 60 mark is never affected.
			if not (quiet and mark == Warnings.FREE_SAVE_MARK) then
				table.insert(fired, mark)
			end
			newState[mark] = false
		end
	end
	return fired, newState
end

return Warnings
