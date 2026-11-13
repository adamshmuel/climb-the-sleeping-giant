--!strict
-- What more than one part of CameraFx needs: the shapes it takes, and the few helpers and numbers that two or more parts share.

local Shared = {}

-- The shapes this module needs, so tests can pass simple stand-ins.
export type CameraLike = {
	CFrame: CFrame,
	Focus: CFrame,
	CameraSubject: Instance?,
	CameraType: Enum.CameraType,
}

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type PlayerLike = {
	Character: Model?,
	CharacterAdded: { Connect: (self: any, callback: (Model) -> ()) -> ConnectionLike },
}

-- A camera that looks more than this many degrees away from the spawn view has been turned by the player. (Zooming
-- in or out keeps the look the same, so it is not turning.)
local TURNED_DEGREES = 2

-- A bounce look needs at least this much left-right length to point anywhere.
local MIN_FLAT_LOOK = 1e-3

-- After a catch (`caught`), the camera waits at most this many seconds for the character to arrive on the spawn spot: the
-- server moves them there and tells the device, and the two can arrive in either order. Used to wait for the spot itself
-- to stream in too (see `whenSpotIsThere`).
Shared.caughtWaitSeconds = 2

-- The angle in degrees between two look directions.
local function angleBetween(first: Vector3, second: Vector3): number
	local cosine = math.clamp(first.Unit:Dot(second.Unit), -1, 1)
	return math.deg(math.acos(cosine))
end

-- Humanoid.CameraOffset has two writers: the spawn view's raise ("height") and the wake shake ("shake"). Each one only
-- says its own part, and the offset on the Humanoid is always `base + height + shake`, so neither can undo the other: a
-- shake ends on the raise, and the raise's ease ends on 0 with no wiggle left. `base` is whatever offset the Humanoid had
-- before either of them touched it (0 in the game). Nothing is kept for a Humanoid once both parts are 0.
type OffsetParts = { base: Vector3, height: Vector3, shake: Vector3 }
local offsetParts: { [Humanoid]: OffsetParts } = setmetatable({}, { __mode = "k" }) :: any

local function partsOf(humanoid: Humanoid): OffsetParts
	local found = offsetParts[humanoid]
	if found ~= nil then
		return found
	end
	local made: OffsetParts = { base = humanoid.CameraOffset, height = Vector3.zero, shake = Vector3.zero }
	offsetParts[humanoid] = made
	return made
end

local function writeOffset(humanoid: Humanoid, parts: OffsetParts)
	humanoid.CameraOffset = parts.base + parts.height + parts.shake
	if parts.height == Vector3.zero and parts.shake == Vector3.zero then
		offsetParts[humanoid] = nil
	end
end

-- Sets the raise part of the offset (straight up), keeping the shake part.
local function setHeight(humanoid: Humanoid, height: Vector3)
	local parts = partsOf(humanoid)
	parts.height = height
	writeOffset(humanoid, parts)
end

-- Sets the shake part of the offset, keeping the raise part.
local function setShake(humanoid: Humanoid, shake: Vector3)
	local parts = partsOf(humanoid)
	parts.shake = shake
	writeOffset(humanoid, parts)
end

local function heightOf(humanoid: Humanoid): Vector3
	local parts = offsetParts[humanoid]
	return if parts ~= nil then parts.height else Vector3.zero
end

-- True when `look` can be used as a bounce look: a Vector3 with finite parts that points somewhere left-right (a look
-- straight up or down, or a zero one, has no direction to put the camera behind).
local function isUsableLook(look: unknown): boolean
	if typeof(look) ~= "Vector3" then
		return false
	end
	local vector = look :: Vector3
	for _, part in { vector.X, vector.Y, vector.Z } do
		if part - part ~= 0 then -- NaN and infinity both give NaN here
			return false
		end
	end
	return Vector2.new(vector.X, vector.Z).Magnitude >= MIN_FLAT_LOOK
end

-- True when `point` is a Vector3 with finite parts.
local function isUsablePoint(point: unknown): boolean
	if typeof(point) ~= "Vector3" then
		return false
	end
	local vector = point :: Vector3
	for _, part in { vector.X, vector.Y, vector.Z } do
		if part - part ~= 0 then -- NaN and infinity both give NaN here
			return false
		end
	end
	return true
end

Shared.TURNED_DEGREES = TURNED_DEGREES
Shared.MIN_FLAT_LOOK = MIN_FLAT_LOOK
Shared.angleBetween = angleBetween
Shared.setHeight = setHeight
Shared.setShake = setShake
Shared.heightOf = heightOf
Shared.isUsableLook = isUsableLook
Shared.isUsablePoint = isUsablePoint

return Shared
