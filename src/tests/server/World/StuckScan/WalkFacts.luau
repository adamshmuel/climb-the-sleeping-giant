--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local PlayerNeeds = require(game:GetService("ServerStorage").Tests.server.World.PlayerNeeds)
local LADDER_REACH_STEPS = Helpers.LADDER_REACH_STEPS
local NEST_REACH = Helpers.NEST_REACH

-- Stuck safety Task 22, test 5: nobody walks into the cave under the cushion. The walk map has no link over the hump,
-- so this test walks a body itself, from named starts, half a stud at a time.
-- The cave's box (step 22-8f's pass rule): x -21 to 21, y 16 to 44, z 45.5 to 60. Feet inside it fail the test.
local CAVE_BOX_MIN = Vector3.new(-21, 16, 45.5)

local CAVE_BOX_MAX = Vector3.new(21, 44, 60)

local CAVE_WALK_STEP = 0.5 -- studs along the heading at a time...

local CAVE_WALK_STEPS = 20 -- ...for 10 studs

local CAVE_START_RAY_ABOVE = 3 -- a start is put on the ground a ray finds from this far above it...

local CAVE_START_RAY_LENGTH = 12 -- ...this far down; no ground there means nobody stands on that point

local CAVE_STEP_RAY_ABOVE = 3 -- each step finds the ground with a ray from this far above the feet...

local CAVE_STEP_RAY_LENGTH = 60 -- ...down to the ground, however far (a fall is a lower step)

local CAVE_FALL_DROP = 1 -- studs: ground lower than this under the next step is a fall

local CAVE_FALL_CARRY = 3 -- studs: a falling body goes on this far along the heading, to find where it lands

-- A steep ramp ahead holds a body higher than the feet: half the body's width times the steepest slope's tangent
-- (tan 70 degrees is 2.75). The body is tried held up this far in half-stud steps, and half a stud off the line.
local CAVE_BODY_MAX_LIFT = 2.5

local CAVE_BODY_LIFT_STEP = 0.5

local CAVE_BODY_NUDGES = { 0, 0.25, -0.25, 0.5, -0.5 }

-- Stuck safety Task 22, test 5 (product's condition on the cave lid): nobody walks into the cave under the cushion.
-- The test walks a body from each named start, half a stud along a heading at a time, up to 10 studs. Each step
-- finds the ground with a ray straight down from above the feet (players' collision group), and the feet go there,
-- down any drop. A step ends the walk when no body fits there (PathCheck.bodyFits). The walker is meant to be
-- generous: it goes anywhere a player can and a few places a player can't (a steep ramp holds the body higher, and
-- a body can stand half a stud off the line), so it may fail by mistake but never pass by mistake.
local function bodyFitsNear(feet: Vector3, heading: Vector3, options: PathCheck.Options): boolean
	local lift = 0
	while lift <= CAVE_BODY_MAX_LIFT + 1e-6 do
		for _, dx in CAVE_BODY_NUDGES do
			for _, dz in CAVE_BODY_NUDGES do
				if PathCheck.bodyFits(options, feet + Vector3.new(dx, lift, dz), nil, heading) then
					return true
				end
			end
		end
		lift += CAVE_BODY_LIFT_STEP
	end
	return false
end

local function insideCave(feet: Vector3): boolean
	return feet.X >= CAVE_BOX_MIN.X
		and feet.X <= CAVE_BOX_MAX.X
		and feet.Y >= CAVE_BOX_MIN.Y
		and feet.Y <= CAVE_BOX_MAX.Y
		and feet.Z >= CAVE_BOX_MIN.Z
		and feet.Z <= CAVE_BOX_MAX.Z
end

-- Walks from `start` along `headingDegrees`. Returns where the feet were inside the cave's box, or nil. `stood` says
-- whether the start had ground under it.
local function walkTowardCave(
	start: Vector3,
	headingDegrees: number,
	ray: RaycastParams,
	options: PathCheck.Options
): (Vector3?, boolean)
	local radians = math.rad(headingDegrees)
	local heading = Vector3.new(math.sin(radians), 0, math.cos(radians))
	local first = Workspace:Raycast(
		start + Vector3.new(0, CAVE_START_RAY_ABOVE, 0),
		Vector3.new(0, -CAVE_START_RAY_LENGTH, 0),
		ray
	)
	if first == nil then
		return nil, false
	end
	local feet = first.Position
	for _ = 1, CAVE_WALK_STEPS do
		local ahead = feet + heading * CAVE_WALK_STEP
		local function groundAt(point: Vector3): RaycastResult?
			return Workspace:Raycast(
				Vector3.new(point.X, feet.Y + CAVE_STEP_RAY_ABOVE, point.Z),
				Vector3.new(0, -CAVE_STEP_RAY_LENGTH, 0),
				ray
			)
		end
		local ground = groundAt(ahead)
		if ground == nil then
			return nil, true
		end
		local landing: RaycastResult? = nil
		if ground.Position.Y < feet.Y - CAVE_FALL_DROP then
			-- A fall: the body goes on along the heading while it drops, and lands where a body fits.
			local carried = 0
			while carried <= CAVE_FALL_CARRY + 1e-6 do
				local found = groundAt(ahead + heading * carried)
				if found ~= nil and bodyFitsNear(found.Position, heading, options) then
					landing = found
					break
				end
				carried += CAVE_WALK_STEP
			end
		elseif bodyFitsNear(ground.Position, heading, options) then
			landing = ground
		end
		if landing == nil then
			return nil, true
		end
		feet = landing.Position
		if insideCave(feet) then
			return feet, true
		end
	end
	return nil, true
end

-- The walk-map spots at the foot and the top of a cap tie (PlayerNeeds.tieEnds), found the way PathCheck joins them:
-- the nearest spot within two grid steps. nil when there is none.
local function ladderEndSpots(ladderName: string, map: PathCheck.WalkMap, world: Instance): (number?, number?)
	local ladder = (world :: any).WalkSurfaces:FindFirstChild(ladderName) :: Instance?
	expect(ladder).never.toBeNil()
	local foot, top = PlayerNeeds.tieEnds(ladder :: Instance)
	expect(foot).never.toBeNil()
	expect(top).never.toBeNil()
	local reach = LADDER_REACH_STEPS * map.spacing
	return PathCheck.nearestSpot(map, foot :: Vector3, reach), PathCheck.nearestSpot(map, top :: Vector3, reach)
end

-- Whether a climb link goes from one spot to another.
local function hasClimbLink(from: number, to: number, map: PathCheck.WalkMap): boolean
	local links: { PathCheck.Link } = map.links[from] or {}
	for _, link in links do
		if link.to == to and link.kind == "Climb" then
			return true
		end
	end
	return false
end

-- Whether a player can get from one spot to any of `goals` by walking alone: no climb, no slide, no jump.
local function canWalk(from: number, goals: { number }, map: PathCheck.WalkMap): boolean
	return PathCheck.route(map, from, goals, { allow = { Walk = true } }) ~= nil
end

-- Every spot within NEST_REACH studs of a nest point.
local function spotsNearNest(point: Vector3, map: PathCheck.WalkMap): { number }
	local found: { number } = {}
	for _, spot in map.spots do
		if (spot.position - point).Magnitude <= NEST_REACH then
			table.insert(found, spot.id)
		end
	end
	return found
end

local function sortedNames(points: { [string]: Vector3 }): { string }
	local names: { string } = {}
	for name in points do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return {
	walkTowardCave = walkTowardCave,
	ladderEndSpots = ladderEndSpots,
	hasClimbLink = hasClimbLink,
	canWalk = canWalk,
	spotsNearNest = spotsNearNest,
	sortedNames = sortedNames,
}
