--!strict
-- The flat pillow's recorded size and place, and the turn check, shared by sections 3a and 3d so the numbers live in one place.

local PillowPlaces = {}

-- Stuck safety Task 41: the pillow laid flat (its thin side straight up). Task 42 sank it 1 stud more, so the cushion's
-- front edge has room again (designer, 2026-10-27). The place Task 41 left it at is kept, so the sections can move it on.
PillowPlaces.FLAT_SIZE = Vector3.new(120, 46, 30)
PillowPlaces.FLAT_CFRAME = CFrame.new(0.142862, 45.594, 40) * CFrame.Angles(-math.pi / 2, 0, 0)
PillowPlaces.TASK_41_FLAT_CFRAME = CFrame.new(0.142862, 46.594, 40) * CFrame.Angles(-math.pi / 2, 0, 0)

-- True when the nine numbers of the two turns (components 4 to 12) each differ by no more than the tolerance.
function PillowPlaces.sameTurn(a: CFrame, b: CFrame, tolerance: number): boolean
	local first = { a:GetComponents() }
	local second = { b:GetComponents() }
	for index = 4, 12 do
		if math.abs(first[index] - second[index]) > tolerance then
			return false
		end
	end
	return true
end

return PillowPlaces
