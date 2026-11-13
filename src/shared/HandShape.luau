--!strict
-- The shape under the giant's hand (spec 6, Rule 13): a circle across the ground, from just under the surface the
-- circle lands on to well above it. The server's hit test and the client's slam effect read this one shape.

local Config = require(script.Parent.Config)

local HandShape = {}

-- Whether a point is under the hand: within the circle's radius across the ground, and from Config.Wake.HandBelowStuds
-- under `surfaceY` to Config.Wake.HandAboveStuds over it. `surfaceY` is the surface under the point, not the circle's.
function HandShape.contains(position: Vector3, centre: Vector3, surfaceY: number): boolean
	local dx = position.X - centre.X
	local dz = position.Z - centre.Z
	local radius = Config.Wake.SlamCircleDiameter / 2
	if math.sqrt(dx * dx + dz * dz) > radius then
		return false
	end
	local height = position.Y - surfaceY
	return height >= -Config.Wake.HandBelowStuds and height <= Config.Wake.HandAboveStuds
end

return HandShape
