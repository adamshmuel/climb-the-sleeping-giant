--!strict
-- Where a slam's red circle is drawn (Rule 13: "on the surface where the target stands"). One ray goes straight down from
-- just above the circle's centre and the point it hits is sent to every device, so all of them draw the circle in the
-- same place. Catches still measure from the centre itself, not from this point.

-- The ray starts this far above the centre, so a centre that sits right on the ground still finds it.
local START_ABOVE = 1
-- How far down the ray looks.
local REACH = 50
-- A player's middle is about this far above their feet: the point used when the ray finds nothing.
local MIDDLE_ABOVE_FEET = 3

local SlamSurface = {}

-- The surface below `centre`: the first thing the ray finds that a player could stand on. Parts a player walks through
-- (meadow props that aren't solid) and anything in `ignore` (the players' characters) don't count. If the ray finds
-- nothing within 50 studs, the answer is 3 studs below the centre.
function SlamSurface.below(worldRoot: WorldRoot, centre: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = worldRoot:Raycast(centre + Vector3.new(0, START_ABOVE, 0), Vector3.new(0, -REACH, 0), params)
	if hit ~= nil then
		return hit.Position
	end
	return centre - Vector3.new(0, MIDDLE_ABOVE_FEET, 0)
end

return SlamSurface
