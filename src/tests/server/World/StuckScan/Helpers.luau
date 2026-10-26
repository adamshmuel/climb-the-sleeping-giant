--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- Stuck safety Task 25, test 6. PathCheck joins a ladder's foot and top to the nearest spot within two grid steps
-- (its CLIMB_REACH_STEPS, which is private). Spec 5's four Legendary nest points are on his cap: the brim pair is just
-- past the cap ladder's top, the side pair farther up the cap's front slope. A nest is reached when a spot within
-- NEST_REACH studs of its point can be walked to.
local LADDER_REACH_STEPS = 2

local NEST_REACH = 2 -- studs

export type Landing = WorldIndex.LandingSpot

local function format(position: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
end

-- Stuck safety Task 23, test 1 (spec Rule 22, "Rare spots left to the rescue", conditions 1 to 3). A stuck spot is left
-- to the rescue instead of fixed only if all hold: it is on the giant, not in the Meadow zone; it is more than
-- MUST_FIX_DISTANCE studs from every place players need; and the walk map can't reach it from those places. The scan
-- fails on any stuck spot that is not on this list, and on any listed spot that breaks one of the three.
local RARE_PROOF =
	"rescue proof: Task 12 (3 of 3, one try in the Climbing pose); re-measured against the real walk area in plan 5, Task 15"

local MUST_FIX_DISTANCE = 12 -- studs (spec section 5, "Must-fix distance")

local RARE_MATCH = 0.25 -- studs: a stuck spot is "the listed spot" when it is this close (the list is rounded to 0.1)

export type StuckSpot = { id: number, position: Vector3, standsOn: BasePart }

export type RareSpot = { name: string, group: number, position: Vector3, proof: string }

-- What the check needs to know about the world, so a made-up world can answer for the tests.
export type RareFacts = {
	isMeadow: (position: Vector3) -> boolean,
	distanceToPlace: (position: Vector3) -> number, -- to the nearest place players need
	reachedFromPlaces: (position: Vector3) -> boolean,
}

local function rareSpot(name: string, group: number, x: number, y: number, z: number): RareSpot
	return { name = name, group = group, position = Vector3.new(x, y, z), proof = RARE_PROOF }
end

local function closedSpot(name: string, piece: string, x: number, y: number, z: number): ClosedSpot
	return { name = name, position = Vector3.new(x, y, z), piece = piece }
end

-- The closed hollows (step 23-S2, t23/sort-23-S2.txt; code_lead's Ruling 8). Each is a stuck spot inside a hollow that
-- no body can enter without passing through his skin, so it is not fixed and not left to the rescue: it is listed by name
-- here, and test 1 fails if it opens, if a link leads into it from outside, or if a place players need lies inside it.
-- The 17-ray closed check (escapingRays) decides, so a spot that fails it is not listed here and stays a stuck spot to fix.
local CLOSED_SPOTS: { ClosedSpot } = {
	-- Inside the Sock (its piece is the Sock model, not a giant piece).
	closedSpot("Closed_Sock_1", "Sock", -68.8, 6.0, -67.0),
	closedSpot("Closed_Sock_2", "Sock", -68.8, 3.0, -63.0),
	closedSpot("Closed_Sock_3", "Sock", -68.8, 2.9, -61.0),
	closedSpot("Closed_Sock_4", "Sock", -66.8, 5.0, -63.0),
	closedSpot("Closed_Sock_5", "Sock", -66.8, 5.1, -61.0),
	-- Inside the beard.
	closedSpot("Closed_Beard_1", "head_with_beard", 3.2, 73.8, 17.0),
	closedSpot("Closed_Beard_2", "head_with_beard", 5.2, 74.2, 13.0),
	-- Inside his left arm.
	closedSpot("Closed_LeftArm_1", "left_arm", -48.8, 29.9, -9.0),
	closedSpot("Closed_LeftArm_2", "left_arm", -48.8, 30.0, -7.0),
	closedSpot("Closed_LeftArm_3", "left_arm", -48.8, 29.5, -1.0),
	closedSpot("Closed_LeftArm_4", "left_arm", -46.8, 27.6, -9.0),
	closedSpot("Closed_LeftArm_5", "left_arm", -46.8, 27.7, -7.0),
	closedSpot("Closed_LeftArm_6", "left_arm", -46.8, 27.8, -5.0),
	closedSpot("Closed_LeftArm_7", "left_arm", -46.8, 27.9, -3.0),
	closedSpot("Closed_LeftArm_8", "left_arm", -44.8, 25.4, -5.0),
	closedSpot("Closed_LeftArm_9", "left_arm", -44.8, 25.5, -3.0),
	closedSpot("Closed_LeftArm_10", "left_arm", -42.8, 24.7, -11.0),
	closedSpot("Closed_LeftArm_11", "left_arm", -42.8, 31.7, -1.0),
	closedSpot("Closed_LeftArm_12", "left_arm", -40.8, 28.8, -11.0),
	closedSpot("Closed_LeftArm_13", "left_arm", -40.8, 28.1, -9.0),
	closedSpot("Closed_LeftArm_14", "left_arm", -40.8, 27.3, -7.0),
	closedSpot("Closed_LeftArm_15", "left_arm", -40.8, 26.5, -5.0),
	closedSpot("Closed_LeftArm_16", "left_arm", -40.8, 25.7, -3.0),
	closedSpot("Closed_LeftArm_17", "left_arm", -38.8, 31.0, -11.0),
	closedSpot("Closed_LeftArm_18", "left_arm", -38.8, 30.2, -9.0),
	closedSpot("Closed_LeftArm_19", "left_arm", -38.8, 29.4, -7.0),
	closedSpot("Closed_LeftArm_20", "left_arm", -38.8, 28.6, -5.0),
	closedSpot("Closed_LeftArm_21", "left_arm", -38.8, 31.8, -3.0),
	-- Inside his right arm.
	closedSpot("Closed_RightArm_1", "right_arm", 39.2, 29.8, -1.0),
	closedSpot("Closed_RightArm_2", "right_arm", 41.2, 27.8, -11.0),
	closedSpot("Closed_RightArm_3", "right_arm", 41.2, 27.4, -9.0),
	closedSpot("Closed_RightArm_4", "right_arm", 41.2, 27.0, -7.0),
	closedSpot("Closed_RightArm_5", "right_arm", 41.2, 26.5, -5.0),
	closedSpot("Closed_RightArm_6", "right_arm", 43.2, 28.7, -11.0),
	closedSpot("Closed_RightArm_7", "right_arm", 45.2, 28.6, -11.0),
	closedSpot("Closed_RightArm_8", "right_arm", 45.2, 25.3, -3.0),
	closedSpot("Closed_RightArm_9", "right_arm", 45.2, 25.8, -1.0),
	closedSpot("Closed_RightArm_10", "right_arm", 47.2, 25.0, -5.0),
	closedSpot("Closed_RightArm_11", "right_arm", 47.2, 26.9, -3.0),
	closedSpot("Closed_RightArm_12", "right_arm", 47.2, 27.4, -1.0),
	closedSpot("Closed_RightArm_13", "right_arm", 49.2, 28.5, -3.0),
	closedSpot("Closed_RightArm_14", "right_arm", 49.2, 29.0, -1.0),
}

-- The indexes of the stuck spots that are not on the rare list.
local function unlistedSpots(positions: { Vector3 }, rare: { RareSpot }): { number }
	local unlisted: { number } = {}
	for index, position in positions do
		local found = false
		for _, spot in rare do
			if (spot.position - position).Magnitude <= RARE_MATCH then
				found = true
				break
			end
		end
		if not found then
			table.insert(unlisted, index)
		end
	end
	return unlisted
end

-- One line for each listed spot that breaks condition 1, 2 or 3.
local function rareBrokenConditions(rare: { RareSpot }, facts: RareFacts): { string }
	local problems: { string } = {}
	for _, spot in rare do
		local where = `{spot.name} at {format(spot.position)}`
		if facts.isMeadow(spot.position) then
			table.insert(problems, `{where}: in the Meadow zone, so the rescue does not cover it (condition 1)`)
		end
		local distance = facts.distanceToPlace(spot.position)
		if distance <= MUST_FIX_DISTANCE then
			table.insert(
				problems,
				string.format(
					"%s: %.1f studs from a place players need, at most %g (condition 2)",
					where,
					distance,
					MUST_FIX_DISTANCE
				)
			)
		end
		if facts.reachedFromPlaces(spot.position) then
			table.insert(problems, `{where}: the walk map reaches it from the places players need (condition 3)`)
		end
	end
	return problems
end

-- Stuck safety Task 23, test 1 (spec Rule 22, "A closed void"; code_lead's Ruling 8 after step 23-S2). A hollow inside
-- his body (or the Sock) that no body can enter without passing through solid is not a stuck spot. The scan lists each
-- one by name and fails if it ever opens. A hollow is closed when, from 2.5 studs over the feet (1 stud over them under
-- a roof lower than 2.8), all 17 rays of 40 studs hit a solid piece of the giant or the Sock: 8 level (every 45
-- degrees), 8 tilted 45 degrees upward on the same headings, and 1 straight up. Two more things fail the test: a walk-map
-- link of any kind (walk, climb or slide; a drop is a slide) that leads into a listed spot from a spot that is not
-- listed, and a place players need (route point, egg spot or landing spot) inside a listed hollow.
local CLOSED_RAY_LENGTH = 40 -- studs

local CLOSED_ABOVE = 2.5 -- studs over the feet where the rays start...

local CLOSED_ABOVE_LOW_ROOF = 1 -- ...or this far under a roof lower than CLOSED_LOW_ROOF

local CLOSED_LOW_ROOF = 2.8 -- studs over the feet

local CLOSED_ROOF_START = 0.05 -- the roof is measured by a ray straight up from this far over the feet

local CLOSED_HEADINGS = 8 -- every 45 degrees

local CLOSED_TILT_DEGREES = 45

local CLOSED_HOLLOW_EYE = 1 -- studs: a line between a spot and a place is cast from this far over each

type Cast = (origin: Vector3, direction: Vector3) -> RaycastResult?

export type ClosedSpot = { name: string, position: Vector3, piece: string }

export type Place = { name: string, position: Vector3 }

-- What the check needs to know about the world, so a made-up world can answer for the tests.
export type ClosedFacts = {
	escapingRays: (position: Vector3) -> number, -- of the 17 rays, how many do not hit a solid piece
	linkedFromOutside: (position: Vector3) -> boolean,
	placeInside: (position: Vector3) -> string?, -- the name of a place players need that lies in this spot's hollow
}

-- The 17 rays, each as a vector of CLOSED_RAY_LENGTH studs.
local function closedRayDirections(): { Vector3 }
	local tilt = math.rad(CLOSED_TILT_DEGREES)
	local directions: { Vector3 } = {}
	for index = 0, CLOSED_HEADINGS - 1 do
		local heading = math.rad(index * 360 / CLOSED_HEADINGS)
		table.insert(directions, Vector3.new(math.cos(heading), 0, math.sin(heading)) * CLOSED_RAY_LENGTH)
		table.insert(
			directions,
			Vector3.new(math.cos(heading) * math.cos(tilt), math.sin(tilt), math.sin(heading) * math.cos(tilt))
				* CLOSED_RAY_LENGTH
		)
	end
	table.insert(directions, Vector3.new(0, CLOSED_RAY_LENGTH, 0))
	return directions
end

-- How many of the 17 rays from `feet` do not hit a solid piece (`isSolid` says which pieces are solid). The rays start
-- 2.5 studs over the feet, or 1 stud over them under a roof lower than 2.8: higher than that, the start would be inside
-- the roof, and a ray that starts inside a piece skips the whole piece.
local function escapingRays(feet: Vector3, cast: Cast, isSolid: (Instance) -> boolean): number
	local roof = cast(feet + Vector3.new(0, CLOSED_ROOF_START, 0), Vector3.new(0, CLOSED_RAY_LENGTH, 0))
	local roofHeight = if roof ~= nil then roof.Distance + CLOSED_ROOF_START else math.huge
	local above = if roofHeight < CLOSED_LOW_ROOF then CLOSED_ABOVE_LOW_ROOF else CLOSED_ABOVE
	local origin = feet + Vector3.new(0, above, 0)
	local escaping = 0
	for _, direction in closedRayDirections() do
		local hit = cast(origin, direction)
		if hit == nil or not isSolid(hit.Instance) then
			escaping += 1
		end
	end
	return escaping
end

-- The spots of `inside` that a link from a spot not in `inside` leads into.
local function linkedInto(links: { [number]: { PathCheck.Link } }, inside: { [number]: boolean }): { [number]: boolean }
	local into: { [number]: boolean } = {}
	for from, outgoing in links do
		if not inside[from] then
			for _, link in outgoing do
				if inside[link.to] then
					into[link.to] = true
				end
			end
		end
	end
	return into
end

-- The names of the places that lie in the hollow of `spot`. A hollow is one body of air, so a place with a clear line to
-- the spot (nothing solid between them, cast from CLOSED_HOLLOW_EYE studs over each) is in it. A place farther than
-- CLOSED_RAY_LENGTH studs is left out: no hollow is that big.
local function placesInHollow(spot: Vector3, places: { Place }, cast: Cast): { string }
	local eye = Vector3.new(0, CLOSED_HOLLOW_EYE, 0)
	local inside: { string } = {}
	for _, place in places do
		local along = (place.position + eye) - (spot + eye)
		if along.Magnitude <= CLOSED_RAY_LENGTH and cast(spot + eye, along) == nil then
			table.insert(inside, place.name)
		end
	end
	return inside
end

-- One line for each listed closed spot that has opened, is linked into from outside, or holds a place players need.
local function closedBrokenConditions(closed: { ClosedSpot }, facts: ClosedFacts): { string }
	local problems: { string } = {}
	for _, spot in closed do
		local where = `{spot.name} at {format(spot.position)} ({spot.piece})`
		local escaping = facts.escapingRays(spot.position)
		if escaping > 0 then
			table.insert(
				problems,
				`{where}: {escaping} of 17 rays leave the hollow, so it has opened and must be fixed or sorted again`
			)
		end
		if facts.linkedFromOutside(spot.position) then
			table.insert(problems, `{where}: a walk-map link leads into it from a spot outside the hollow`)
		end
		local place = facts.placeInside(spot.position)
		if place ~= nil then
			table.insert(problems, `{where}: {place}, a place players need, lies inside its hollow`)
		end
	end
	return problems
end

-- A closed spot written as a rare-list entry, so the one list-matching rule serves both lists.
local function closedAsRare(closed: { ClosedSpot }): { RareSpot }
	local asRare: { RareSpot } = {}
	for _, spot in closed do
		table.insert(asRare, { name = spot.name, group = 0, position = spot.position, proof = "closed hollow" })
	end
	return asRare
end

-- The indexes of the stuck spots that are on neither the rare list nor the closed list.
local function unlistedStuck(positions: { Vector3 }, rare: { RareSpot }, closed: { ClosedSpot }): { number }
	local notRare = unlistedSpots(positions, rare)
	local rest: { Vector3 } = {}
	for _, index in notRare do
		table.insert(rest, positions[index])
	end
	local unlisted: { number } = {}
	for _, restIndex in unlistedSpots(rest, closedAsRare(closed)) do
		table.insert(unlisted, notRare[restIndex])
	end
	return unlisted
end

return {
	CLOSED_RAY_LENGTH = CLOSED_RAY_LENGTH,
	CLOSED_SPOTS = CLOSED_SPOTS,
	CLOSED_TILT_DEGREES = CLOSED_TILT_DEGREES,
	LADDER_REACH_STEPS = LADDER_REACH_STEPS,
	NEST_REACH = NEST_REACH,
	RARE_MATCH = RARE_MATCH,
	RARE_PROOF = RARE_PROOF,
	closedBrokenConditions = closedBrokenConditions,
	closedRayDirections = closedRayDirections,
	escapingRays = escapingRays,
	format = format,
	linkedInto = linkedInto,
	placesInHollow = placesInHollow,
	rareBrokenConditions = rareBrokenConditions,
	rareSpot = rareSpot,
	unlistedSpots = unlistedSpots,
	unlistedStuck = unlistedStuck,
}
