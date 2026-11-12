--!strict
-- Where a slam's red circle is drawn (Rule 13: "on the surface where the target stands"). One ray goes straight down from
-- just above the circle's centre and the point it hits is sent to every device, so all of them draw the circle in the
-- same place. Catches still measure from the centre itself, not from this point.

local Zones = require(script.Parent.Zones)

-- The ray starts this far above the centre, so a centre that sits right on the ground still finds it.
local START_ABOVE = 1
-- How far down the ray looks.
local REACH = 50
-- A player's middle is about this far above their feet: the point used when the ray finds nothing.
local MIDDLE_ABOVE_FEET = 3
-- No steeper than a player can stand on (spec 3 Check C4): a hit on a surface steeper than this is skipped.
local MAX_SLOPE_DEGREES = 70
-- How many steep parts one ray may skip before the fallback applies.
local MAX_SKIPS = 8

local SlamSurface = {}

-- The surface below `centre`: the first thing the ray finds that a player could stand on. Parts a player walks through
-- (meadow props that aren't solid), anything in `ignore` (the players' characters, the ladders) and surfaces steeper
-- than MAX_SLOPE_DEGREES don't count: the ray goes on past a steep one, up to MAX_SKIPS times. If the ray finds
-- nothing within 50 studs, the answer is 3 studs below the centre. The caller's `ignore` list is never changed.
function SlamSurface.below(worldRoot: WorldRoot, centre: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local filter = table.clone(ignore)
	local minNormalY = math.cos(math.rad(MAX_SLOPE_DEGREES))
	local start = centre + Vector3.new(0, START_ABOVE, 0)
	for _ = 1, MAX_SKIPS do
		params.FilterDescendantsInstances = filter
		local hit = worldRoot:Raycast(start, Vector3.new(0, -REACH, 0), params)
		if hit == nil then
			break
		end
		if hit.Normal.Y >= minNormalY then
			return hit.Position
		end
		table.insert(filter, hit.Instance)
	end
	return centre - Vector3.new(0, MIDDLE_ABOVE_FEET, 0)
end

-- The whole model (the Climb truss and every visible piece) of each ladder box, so a slam's ray never lands on a
-- ladder. A name that has no model in `walkSurfaces` is skipped.
function SlamSurface.ladderParts(walkSurfaces: Instance, ladders: { Zones.LadderBox }): { Instance }
	local models: { Instance } = {}
	for _, box in ladders do
		local model = walkSurfaces:FindFirstChild(box.ladder)
		if model ~= nil then
			table.insert(models, model)
		end
	end
	return models
end

return SlamSurface
