--!strict
-- The clear check of a meadow egg's post (Rule 85): a nest is "not clear" while a player root is within
-- Config.Nests.PostClear's HalfBase + Sideways studs flat, or its Vertical studs up or down. Pure: no Instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PostClear = {}

-- True when any root in `playersAt` is close enough to `nestAt` to block the nest's post.
function PostClear.blocked(nestAt: Vector3, playersAt: { Vector3 }): boolean
	local clear = Config.Nests.PostClear
	local sideways = clear.HalfBase + clear.Sideways
	for _, playerAt in playersAt do
		local offset = playerAt - nestAt
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if flat <= sideways and math.abs(offset.Y) <= clear.Vertical then
			return true
		end
	end
	return false
end

return PostClear
