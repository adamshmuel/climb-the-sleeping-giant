--!strict
-- Hand slams (Rules 6 and 13): who a slam aims at, where its red circle goes so it never touches a garden, and who it
-- catches. Pure maths: it is given players, gardens and points and returns the answers. It reads no instances and no
-- clock, and the random pick is passed in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HandShape = require(ReplicatedStorage.Shared.HandShape)
local Zones = require(script.Parent.Zones)

export type Player = {
	userId: number,
	position: Vector3, -- the character's middle
	carrying: boolean,
	inGarden: boolean,
	floating: boolean, -- still floating down after the bounce-off
	landedAgo: number?, -- seconds since the bounce-off float touched down, nil if it hasn't in this wake-up
	joinedThisWake: boolean?, -- true: joined after he woke, never a target
	appearedAgo: number?, -- seconds since a catch or a new character put them at the door, nil = never appeared
	bonkedLast: boolean?, -- true: the slam before bonked them, not a target now
	inLadderGrace: boolean?, -- true: still inside their ladder grace (Rule 60), not a target now
}
-- A slam's circle as the hit test sees it: the hand's centre and the surface point it lands on.
export type HandCircle = { centre: Vector3, point: Vector3 }
export type Circle = { centre: Vector3, target: number? } -- target is the user id aimed at, nil for an empty-meadow slam

-- A jump is about 7 studs high; a circle on the meadow must not catch someone high up on the giant above it.
local HEIGHT_LIMIT = 10
-- How far a pushed circle moves each try. The result is never more than this much further than it had to move.
local PUSH_STEP = 0.1

local Slams = {}

local function circleRadius(): number
	return Config.Wake.SlamCircleDiameter / 2
end

-- The distance across the ground only: players on his belly are high up and the circle is on the surface below them.
local function flatDistance(a: Vector3, b: Vector3): number
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end
Slams.flatDistance = flatDistance

-- Whether a point is inside a slam's circle: within its radius across the ground, and not high above or below it.
-- The catch and the rescue's red-circle guard both use this one test.
function Slams.inCircle(point: Vector3, centre: Vector3): boolean
	return flatDistance(point, centre) <= circleRadius() and math.abs(point.Y - centre.Y) <= HEIGHT_LIMIT
end

-- The distance across the ground from a point to the nearest point of a garden's flat rectangle, worked out in the
-- garden's own space (gardens are level, turned about the vertical only). Inside the rectangle it is 0.
local function gapToGarden(point: Vector3, garden: Zones.GardenBox): number
	local local_ = garden.cframe:PointToObjectSpace(point)
	local half = garden.size / 2
	local gapX = math.max(math.abs(local_.X) - half.X, 0)
	local gapZ = math.max(math.abs(local_.Z) - half.Z, 0)
	return math.sqrt(gapX * gapX + gapZ * gapZ)
end

-- Does a circle at this centre stand at least Config.Wake.SlamGardenMarginStuds outside every garden?
local function isClearOfGardens(centre: Vector3, gardens: { Zones.GardenBox }): boolean
	local needed = circleRadius() + Config.Wake.SlamGardenMarginStuds
	for _, garden in gardens do
		if gapToGarden(centre, garden) < needed then
			return false
		end
	end
	return true
end

-- Could this player be aimed at? On the ground (not floating), outside the gardens, not someone who joined after he woke,
-- not bonked by the slam before, not still inside their ladder grace (Rule 60), and not still at the door (less than
-- DoorSeconds since they appeared there).
-- Whether they carry an egg does not matter here: carriers are preferred in pickTarget.
local function canBeTargeted(player: Player): boolean
	if
		player.floating
		or player.inGarden
		or player.joinedThisWake == true
		or player.bonkedLast == true
		or player.inLadderGrace == true
	then
		return false
	end
	local appearedAgo = player.appearedAgo
	return appearedAgo == nil or appearedAgo >= Config.Wake.DoorSeconds
end

-- Would a circle aimed at this player land before they could move? Yes for a player the slam before bonked, for one
-- still inside their ladder grace (Rule 60), and for one who appeared at the door less than DoorSeconds ago (Rules 62
-- and 63). The director then plans a show slam
-- instead of a warning at them. Players on the ground outside the gardens only; a late joiner is never aimed at.
function Slams.isProtected(player: Player): boolean
	if player.floating or player.inGarden or player.joinedThisWake == true then
		return false
	end
	if player.bonkedLast == true or player.inLadderGrace == true then
		return true
	end
	local appearedAgo = player.appearedAgo
	return appearedAgo ~= nil and appearedAgo < Config.Wake.DoorSeconds
end

-- Carriers first: the target is picked from the players who carry an egg, and only when none can be aimed at, from the
-- others. Inside that group it is the player nearest to him across the ground, skipping the last target if anyone else in
-- the group can be aimed at. A tie goes to the lower user id, so the answer does not depend on the order of the list.
function Slams.pickTarget(players: { Player }, giantFace: Vector3, lastTarget: number?): Player?
	local carriers: { Player } = {}
	local others: { Player } = {}
	for _, player in players do
		if canBeTargeted(player) then
			table.insert(if player.carrying then carriers else others, player)
		end
	end
	local group: { Player } = if #carriers > 0 then carriers else others

	local othersThanLast = 0
	for _, player in group do
		if player.userId ~= lastTarget then
			othersThanLast += 1
		end
	end

	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in group do
		if player.userId == lastTarget and othersThanLast > 0 then
			continue
		end
		local distance = flatDistance(player.position, giantFace)
		if best == nil or distance < bestDistance or (distance == bestDistance and player.userId < best.userId) then
			best = player
			bestDistance = distance
		end
	end
	return best
end

-- Moves a circle's centre toward his face across the ground (keeping its height) by the smallest distance that leaves it
-- clear of every garden, in steps of PUSH_STEP. A centre that is already clear comes back unchanged. If no step before
-- his face is clear (it cannot happen in the real world), the answer is the point under his face.
function Slams.clearOfGardens(centre: Vector3, gardens: { Zones.GardenBox }, giantFace: Vector3): Vector3
	if isClearOfGardens(centre, gardens) then
		return centre
	end
	local toFace = Vector3.new(giantFace.X - centre.X, 0, giantFace.Z - centre.Z)
	local distance = toFace.Magnitude
	if distance < 1e-6 then
		return centre
	end
	local direction = toFace / distance
	for step = 1, math.ceil(distance / PUSH_STEP) do
		local candidate = centre + direction * math.min(step * PUSH_STEP, distance)
		if isClearOfGardens(candidate, gardens) then
			return candidate
		end
	end
	return centre + direction * distance
end

local function nearestPlayerDistance(point: Vector3, players: { Player }): number
	local nearest = math.huge
	for _, player in players do
		nearest = math.min(nearest, flatDistance(point, player.position))
	end
	return nearest
end

-- Where he slams when nobody can be targeted: one of the meadow points whose circle is clear of the gardens, covers no
-- landing spot and has no player in it (anyone, carrying or not, floating too). The slam before is left out if another
-- point fits. `pick(count)` chooses one of the `count` points that fit (1 to count). If none fits, the garden-clear
-- point whose nearest player is farthest away.
function Slams.pickEmpty(
	meadowPoints: { Vector3 },
	players: { Player },
	landingSpots: { Vector3 },
	gardens: { Zones.GardenBox },
	lastCentre: Vector3?,
	pick: (count: number) -> number
): Vector3
	local radius = circleRadius()
	local clearOfGardens: { Vector3 } = {}
	local fitting: { Vector3 } = {}
	for _, point in meadowPoints do
		if not isClearOfGardens(point, gardens) then
			continue
		end
		table.insert(clearOfGardens, point)
		local covered = nearestPlayerDistance(point, players) <= radius
		for _, spot in landingSpots do
			if flatDistance(point, spot) <= radius then
				covered = true
			end
		end
		if not covered then
			table.insert(fitting, point)
		end
	end

	if #clearOfGardens == 0 then
		error("Slams.pickEmpty: no meadow point is clear of the gardens", 0)
	end

	if #fitting > 0 then
		local choices: { Vector3 } = {}
		for _, point in fitting do
			if point ~= lastCentre then
				table.insert(choices, point)
			end
		end
		if #choices == 0 then
			choices = fitting
		end
		return choices[pick(#choices)]
	end

	local best = clearOfGardens[1]
	local bestDistance = nearestPlayerDistance(best, players)
	for index = 2, #clearOfGardens do
		local distance = nearestPlayerDistance(clearOfGardens[index], players)
		if distance > bestDistance then
			best = clearOfGardens[index]
			bestDistance = distance
		end
	end
	return best
end

-- The next slam's circle: on the chosen carrier (pushed out of the gardens), or on an empty meadow spot.
function Slams.plan(
	players: { Player },
	giantFace: Vector3,
	gardens: { Zones.GardenBox },
	meadowPoints: { Vector3 },
	landingSpots: { Vector3 },
	lastTarget: number?,
	lastCentre: Vector3?,
	pick: (count: number) -> number
): Circle
	local target = Slams.pickTarget(players, giantFace, lastTarget)
	if target then
		return { centre = Slams.clearOfGardens(target.position, gardens, giantFace), target = target.userId }
	end
	return { centre = Slams.pickEmpty(meadowPoints, players, landingSpots, gardens, lastCentre, pick), target = nil }
end

-- Whether the hand can never touch this player: in a garden, floating down after the bounce-off, or touched down less
-- than SlamWarningSeconds ago (they could not steer the fall, so they get the same warning as everyone).
local function neverHit(player: Player): boolean
	if player.floating or player.inGarden then
		return true
	end
	local landedAgo = player.landedAgo
	return landedAgo ~= nil and landedAgo < Config.Wake.SlamWarningSeconds
end

-- Whether a position is under the hand: inside the circle across the ground, from just under the surface below it to
-- high over it (`surfaceUnder` is that surface's height).
function Slams.underHand(position: Vector3, circle: HandCircle, surfaceUnder: number): boolean
	return HandShape.contains(position, circle.centre, surfaceUnder)
end

-- Everyone the hand hits, in the players' list order: carriers are caught, everyone else is bonked. `surfaceUnder` gives
-- the height of the surface under a position.
function Slams.hits(
	players: { Player },
	circle: HandCircle,
	surfaceUnder: (position: Vector3) -> number
): { caught: { number }, bonked: { number } }
	local caught: { number } = {}
	local bonked: { number } = {}
	for _, player in players do
		if neverHit(player) or not Slams.underHand(player.position, circle, surfaceUnder(player.position)) then
			continue
		end
		table.insert(if player.carrying then caught else bonked, player.userId)
	end
	return { caught = caught, bonked = bonked }
end

return Slams
