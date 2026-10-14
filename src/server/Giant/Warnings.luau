--!strict
-- The giant's warning marks. Pure maths: it is given numbers and returns numbers.
-- The marks and the re-arm drop come from Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type State = { [number]: boolean } -- per mark: true = armed (it can fire)

local Warnings = {}

function Warnings.new(): State
	local state: State = {}
	for _, mark in Config.Meter.WarningMarks do
		state[mark] = true
	end
	return state
end

function Warnings.update(state: State, previousValue: number, value: number, phase: Config.Phase): ({ number }, State)
	local fired: { number } = {}
	local newState = table.clone(state)
	for _, mark in Config.Meter.WarningMarks do
		if value <= mark - Config.Meter.WarningRearmDrop then
			newState[mark] = true
		elseif phase == "Asleep" and newState[mark] and previousValue < mark and mark <= value then
			table.insert(fired, mark)
			newState[mark] = false
		end
	end
	return fired, newState
end

return Warnings
