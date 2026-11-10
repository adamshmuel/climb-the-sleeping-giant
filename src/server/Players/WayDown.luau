--!strict
-- Says whether a fall is one of the set ways down, which make no thud (spec core-heist Rule 8). Pure: it is given
-- the fall as it was seen and the ladders, and touches no players, parts or clocks.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Ladder = {
	name: string,
	kind: "head" | "boot",
	foot: Vector3,
	top: Vector3,
	ground: Vector3?, -- boot ladders: the route point on the grass at the foot
}

export type Fall = {
	firstAirborne: Vector3,
	zones: { [Config.ZoneName]: boolean }, -- every zone seen on a falling tick
	endZone: Config.ZoneName,
	endPosition: Vector3,
	passedBelow: boolean, -- the fall passed below the seam line (a slide)
	jumped: boolean,
}

local NIGHTCAP: Config.ZoneName = "Nightcap"
local BEARD: Config.ZoneName = "Beard"

local WayDown = {}

-- Distance from `point` to the line segment foot-top.
local function distanceToLine(point: Vector3, foot: Vector3, top: Vector3): number
	local along = top - foot
	local lengthSquared = along:Dot(along)
	local t = if lengthSquared > 0 then math.clamp((point - foot):Dot(along) / lengthSquared, 0, 1) else 0
	return (point - (foot + along * t)).Magnitude
end

-- "Near a ladder": the fall began close to the ladder's line, or close to its top.
local function isNear(point: Vector3, ladder: Ladder): boolean
	local near = Config.Noise.QuietDrop
	return distanceToLine(point, ladder.foot, ladder.top) <= near.TrussNear
		or (point - ladder.top).Magnitude <= near.TopNear
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- True when the fall is one of the set ways down, which make no thud. A fall with a jump, or one that slid below the
-- seam line, never is. Off his head it is quiet when it ends on the nose top or the belly; off a boot ladder when it
-- ends on the grass near that ladder's foot.
function WayDown.isSet(fall: Fall, ladders: { Ladder }): boolean
	if fall.jumped or fall.passedBelow then
		return false
	end
	local nearHead = false
	for _, ladder in ladders do
		if ladder.kind == "head" and isNear(fall.firstAirborne, ladder) then
			nearHead = true
		elseif ladder.kind == "boot" and isNear(fall.firstAirborne, ladder) then
			local ground = ladder.ground
			if
				ground ~= nil
				and fall.endZone == "Meadow"
				and flatDistance(fall.endPosition, ground) <= Config.Noise.QuietDrop.FootStuds
			then
				return true
			end
		end
	end
	if nearHead or fall.zones[NIGHTCAP] == true or fall.zones[BEARD] == true then
		return fall.endZone == "Beard" or fall.endZone == "Belly"
	end
	return false
end

return WayDown
