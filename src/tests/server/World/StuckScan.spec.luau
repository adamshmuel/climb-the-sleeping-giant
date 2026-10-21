--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll, afterAll =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll, JestGlobals.afterAll

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Collisions = require(ServerScriptService.Server.Players.Collisions)

-- The stuck scan (V2 Rule 21, "The stuck scan runs on every test run", and Rule 22, "What counts as stuck"): it reads
-- the real world, builds the walk map of the giant and the meadow around him, and fails if even one spot has no way
-- out by walking, ladders and slides or drops. The V1 stuck spots are also checked by name. Nothing is changed or left
-- in the world: the body probe is removed in afterAll.

local SCAN_TIMEOUT_MS = 150000 -- Jest's limit for the build: more than the scan's own 120 seconds
local MAX_LINES = 300 -- most stuck spots written out one by one
local NEAR_GIANT = 10 -- studs: the farthest a "nearest part of the giant" is looked for
local BELOW_AND_ABOVE = 5 -- studs the scan area reaches below the lowest ground and above the giant
local FOREHEAD_POINT = Vector3.new(20, 104, 6) -- V1's stuck spot on the forehead
local GUARD_SIDE_X = 7 -- the side guard walls stand beyond this x on both sides of the forehead's middle
local DROP_FROM_ABOVE = 3 -- a named point with no spot near it is checked by casting down from this far above...
local DROP_LENGTH = 6 -- ...this far down
local ROUTE_NAMES = {
	"RoutePoint_Belly_1",
	"RoutePoint_Belly_2",
	"RoutePoint_Belly_3",
	"RoutePoint_Belly_4",
	"RoutePoint_Egg_Rare_1",
	"RoutePoint_Egg_Rare_2",
	"RoutePoint_Egg_Rare_3",
	"RoutePoint_Egg_Rare_4",
}

-- Three places inside the meadow ground under his chair (stuck safety Task 20). Each is a stuck spot from the stuck scan
-- after Task 19 (his real shape; the list of 436 spots, 2026-10-20): the spot stands on the underside of his chair
-- (body_and_cushion), more than half a stud under the meadow top (y 2). The scan used to count them because Roblox's
-- exact overlap check can't see the Terrain.
local UNDER_LEFT_ARMREST = Vector3.new(-28.8, -1.2, 9) -- the list's line "-28.8,-1.2,9.0|body_and_cushion|body_and_cushion"
local UNDER_RIGHT_ARMREST = Vector3.new(27.2, 0.6, 27) -- "27.2,0.6,27.0|body_and_cushion|body_and_cushion"
local FRONT_OF_CHAIR = Vector3.new(-30.8, 0.3, -15) -- "-30.8,0.3,-15.0|body_and_cushion|body_and_cushion": the lowest z
local NEAR_A_POINT = 1 -- studs: a named stuck spot sits on a grid column, so "a spot at that point" is one within this far
local LANDING_RAY_ABOVE = 3 -- the ground under a landing spot: a ray from this far above it...
local LANDING_RAY_LENGTH = 6 -- ...this far down

-- Stuck safety Task 25, test 6. PathCheck joins a ladder's foot and top to the nearest spot within two grid steps
-- (its CLIMB_REACH_STEPS, which is private). Spec 5's four Legendary nest points are on his cap: the brim pair is just
-- past the cap ladder's top, the side pair farther up the cap's front slope. A nest is reached when a spot within
-- NEST_REACH studs of its point can be walked to.
local LADDER_REACH_STEPS = 2
local NEST_REACH = 2 -- studs
local BRIM_NESTS: { [string]: Vector3 } = {
	["left brim nest"] = Vector3.new(-14, 117.1, 14),
	["right brim nest"] = Vector3.new(14, 117.1, 14),
}
local SIDE_NESTS: { [string]: Vector3 } = {
	["left side nest"] = Vector3.new(-17, 119, 28),
	["right side nest"] = Vector3.new(17, 119, 28),
}

type Landing = WorldIndex.LandingSpot

local function format(position: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
end

-- The part's full name without the leading "Workspace.".
local function shortName(part: Instance): string
	return (string.gsub(part:GetFullName(), "^Workspace%.", ""))
end

-- The area to scan: the giant's box grown to hold every landing spot, then `margin` studs of meadow on each side in x
-- and z. In y: BELOW_AND_ABOVE below the lowest of the giant's bottom and the landing spots, to BELOW_AND_ABOVE above
-- the giant's top. A landing spot outside the area could never be reached, so the area must hold all of them.
local function scanArea(giant: Model, landings: { Landing }, margin: number): PathCheck.Area
	local boxCFrame, boxSize = giant:GetBoundingBox()
	local low = boxCFrame.Position - boxSize / 2
	local high = boxCFrame.Position + boxSize / 2
	local minX, minZ, maxX, maxZ = low.X, low.Z, high.X, high.Z
	local bottom = low.Y
	for _, landing in landings do
		minX = math.min(minX, landing.position.X)
		maxX = math.max(maxX, landing.position.X)
		minZ = math.min(minZ, landing.position.Z)
		maxZ = math.max(maxZ, landing.position.Z)
		bottom = math.min(bottom, landing.position.Y)
	end
	return {
		min = Vector3.new(minX - margin, bottom - BELOW_AND_ABOVE, minZ - margin),
		max = Vector3.new(maxX + margin, high.Y + BELOW_AND_ABOVE, maxZ + margin),
	}
end

-- How far `position` is from the nearest point of the part's box (in the part's own space).
local function distanceToBox(part: BasePart, position: Vector3): number
	local inside = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	local nearest = Vector3.new(
		math.clamp(inside.X, -half.X, half.X),
		math.clamp(inside.Y, -half.Y, half.Y),
		math.clamp(inside.Z, -half.Z, half.Z)
	)
	return (inside - nearest).Magnitude
end

-- The part of the giant a stuck spot is on (if it stands on one), or else the part whose box is nearest within
-- NEAR_GIANT studs. nil when none is that close.
local function nearestGiantPart(giantParts: { BasePart }, giant: Model, spotOn: BasePart, position: Vector3): BasePart?
	if spotOn:IsDescendantOf(giant) then
		return spotOn
	end
	local best: BasePart? = nil
	local bestDistance = NEAR_GIANT
	for _, part in giantParts do
		local distance = distanceToBox(part, position)
		if distance <= bestDistance then
			best = part
			bestDistance = distance
		end
	end
	return best
end

-- The piece of the giant (his direct child model, such as legs_and_boots) that a part belongs to, or nil when it is not
-- inside the giant.
local function pieceOf(giant: Model, part: BasePart?): string?
	if part == nil then
		return nil
	end
	local at: Instance = part
	while at.Parent ~= nil and at.Parent ~= giant do
		at = at.Parent
	end
	if at.Parent == giant then
		return at.Name
	end
	return nil
end

-- The line of the report that a stuck spot counts for. A spot standing on a part of the pillow (World.GiantsThings.Pillow)
-- has a line of its own, "Pillow", and is not counted for the giant piece nearest to it. Any other spot counts for the
-- piece of the part it stands on, else of the nearest part of the giant.
local PILLOW_LABEL = "Pillow"
local function labelOf(giant: Model, pillow: Instance?, spotOn: BasePart, nearest: BasePart?): string?
	if pillow ~= nil and spotOn:IsDescendantOf(pillow) then
		return PILLOW_LABEL
	end
	return pieceOf(giant, nearest)
end

describe("the stuck scan on the real world", function()
	local world: Instance
	local options: PathCheck.Options
	local landings: { Landing } = {}
	local area: PathCheck.Area
	local map: PathCheck.WalkMap
	local stuck: { { id: number, position: Vector3, standsOn: BasePart } } = {}
	local stuckIds: { [number]: boolean } = {}
	local landingExits: { number } = {} -- the walk-map spot nearest each landing spot
	local exits: { number } = {} -- the landing exits plus the meadow ground on the area's outer edge
	local edgeExits: { number } = {}
	local buildAndSearchSeconds = 0

	local function giantModel(): Model
		return (world :: any).Giant :: Model
	end

	-- Builds the walk map once for all the tests (it takes tens of seconds) and finds the stuck spots.
	beforeAll(function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		world = found :: Instance
		landings = WorldIndex.loadLandingSpots(world)
		area = scanArea(giantModel(), landings, Config.Stuck.ScanMargin)

		-- The two ramp planks are left out of the body check: a player steps on or off a ramp foot over its edge,
		-- which the body box touches by design (the same as the route test in RealWorld.spec).
		options = PathCheck.defaults(Workspace)
		options.boxIgnores = {
			(world :: any).WalkSurfaces.BootRamp.Ramp_Walk,
			(world :: any).WalkSurfaces.RightBootRamp.Ramp_Walk,
		}

		local started = os.clock()
		map = PathCheck.buildMap(options, area)
		for _, landing in landings do
			local id = PathCheck.nearestSpot(map, landing.position, 2 * map.spacing)
			if id ~= nil then
				table.insert(landingExits, id)
			end
		end
		-- The open meadow on the area's outer edge is a Meadow exit: the world goes on past it (spec, "Meadow exit"). Only
		-- the Terrain counts, not the sock, the teacup or a bridge that happen to cross the edge.
		edgeExits = PathCheck.edgeSpots(map, { Workspace.Terrain })
		for _, id in landingExits do
			table.insert(exits, id)
		end
		for _, id in edgeExits do
			table.insert(exits, id)
		end
		stuck = PathCheck.stuckSpots(map, exits)
		buildAndSearchSeconds = os.clock() - started
		for _, spot in stuck do
			stuckIds[spot.id] = true
		end
	end, SCAN_TIMEOUT_MS)

	afterAll(function()
		if options ~= nil then
			pcall(PathCheck.cleanup, options) -- takes the body probe out of the Workspace, whatever the result
		end
	end)

	-- A named V1 point passes if every walk-map spot within one grid step of it reaches an exit. With no spot that
	-- close, it passes only if no body fits there. Returns why it failed, or nil.
	local function namedPointProblem(name: string, point: Vector3): string?
		local anySpot = false
		for _, spot in map.spots do
			if (spot.position - point).Magnitude <= map.spacing then
				anySpot = true
				if stuckIds[spot.id] then
					return `{name} at {format(point)}: the spot at {format(spot.position)} has no route to a meadow exit`
				end
			end
		end
		if anySpot then
			return nil
		end
		local params = RaycastParams.new()
		local hit =
			Workspace:Raycast(point + Vector3.new(0, DROP_FROM_ABOVE, 0), Vector3.new(0, -DROP_LENGTH, 0), params)
		if hit == nil then
			return nil
		end
		if PathCheck.roomToStand(options, hit.Position, hit.Normal) then
			return `{name}: a body fits at {format(hit.Position)} but the walk map has no spot there`
		end
		return nil
	end

	-- Every map spot behind one of the four side guard walls of the forehead: inside the wall's x range and height
	-- range, and with a larger z than the wall's middle. Each is a slot a player could step into.
	local function foreheadSlotProblems(): { string }
		local problems: { string } = {}
		local guards = (world :: any).WalkSurfaces.ForeheadGuard :: Instance
		for _, wall in guards:GetChildren() do
			if wall:IsA("BasePart") and wall.Name == "Guard" and math.abs(wall.Position.X) > GUARD_SIDE_X then
				local lowX, highX, lowY, highY = math.huge, -math.huge, math.huge, -math.huge
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner = wall.CFrame:PointToWorldSpace(
								Vector3.new(wall.Size.X / 2 * sx, wall.Size.Y / 2 * sy, wall.Size.Z / 2 * sz)
							)
							lowX, highX = math.min(lowX, corner.X), math.max(highX, corner.X)
							lowY, highY = math.min(lowY, corner.Y), math.max(highY, corner.Y)
						end
					end
				end
				for _, spot in map.spots do
					local at = spot.position
					if
						at.X >= lowX
						and at.X <= highX
						and at.Y >= lowY
						and at.Y <= highY
						and at.Z > wall.Position.Z
						and stuckIds[spot.id]
					then
						table.insert(
							problems,
							`forehead slot behind the side wall at x {string.format("%.1f", wall.Position.X)}: the spot at {format(
								at
							)} has no route to a meadow exit`
						)
					end
				end
			end
		end
		return problems
	end

	-- Every named V1 stuck spot that fails, with the reason.
	local function namedProblems(): { string }
		local problems: { string } = {}
		local forehead = namedPointProblem("forehead point", FOREHEAD_POINT)
		if forehead ~= nil then
			table.insert(problems, forehead)
		end
		local points = WorldIndex.loadRoute(world)
		local byName: { [string]: Vector3 } = {}
		for _, point in points do
			byName[point.name] = point.position
		end
		for _, name in ROUTE_NAMES do
			local position: Vector3? = byName[name]
			if position == nil then
				table.insert(problems, `{name} is missing from World.Route`)
			else
				local problem = namedPointProblem(name, position)
				if problem ~= nil then
					table.insert(problems, problem)
				end
			end
		end
		for _, problem in foreheadSlotProblems() do
			table.insert(problems, problem)
		end
		return problems
	end

	-- The stuck spots as text: a summary, then one line each (at most MAX_LINES).
	local function stuckReport(): { string }
		local giantParts: { BasePart } = {}
		for _, descendant in giantModel():GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(giantParts, descendant)
			end
		end
		local pillowFolder = world:FindFirstChild("GiantsThings")
		local pillow: Instance? = if pillowFolder ~= nil then pillowFolder:FindFirstChild("Pillow") else nil
		local counts: { [string]: number } = {}
		local lines: { string } = {}
		for _, spot in stuck do
			local nearest = nearestGiantPart(giantParts, giantModel(), spot.standsOn, spot.position)
			local nearestName = if nearest ~= nil then shortName(nearest) else `none within {NEAR_GIANT} studs`
			local pieceName = labelOf(giantModel(), pillow, spot.standsOn, nearest) or `none within {NEAR_GIANT} studs`
			counts[pieceName] = (counts[pieceName] or 0) + 1
			if #lines < MAX_LINES then
				table.insert(
					lines,
					`{format(spot.position)} on {shortName(spot.standsOn)}, nearest giant part: {nearestName}`
				)
			end
		end
		local names: { string } = {}
		for name in counts do
			table.insert(names, name)
		end
		table.sort(names, function(a, b)
			if counts[a] ~= counts[b] then
				return counts[a] > counts[b]
			end
			return a < b
		end)
		local report: { string } = {
			`{#stuck} stuck spots. Count by giant piece (the piece of the part a spot stands on, else of the nearest part; the pillow has its own line), largest first:`,
		}
		for _, name in names do
			table.insert(report, `  {counts[name]}  {name}`)
		end
		table.insert(report, "Each stuck spot (position, the part it stands on, nearest giant part):")
		for _, line in lines do
			table.insert(report, `  {line}`)
		end
		if #stuck > #lines then
			table.insert(report, `  ...and {#stuck - #lines} more`)
		end
		return report
	end

	it("every landing spot has a walk-map spot within two grid steps", function()
		for _, landing in landings do
			local id = PathCheck.nearestSpot(map, landing.position, 2 * map.spacing)
			if id == nil then
				error(
					`LandingSpot_{landing.index} at {format(landing.position)} has no walk-map spot within two grid steps`,
					0
				)
			end
		end
		expect(#landingExits).toBe(#landings)
	end)

	it("the real options carry the meadow ground, and a fake world's carry none", function()
		expect(options.terrain).toBe(Workspace.Terrain)
		local fake = Instance.new("WorldModel")
		expect(PathCheck.defaults(fake).terrain).toBeNil()
		fake:Destroy()
	end)

	it("no spot inside the meadow ground under his chair", function()
		local named: { [string]: Vector3 } = {
			["under the left armrest"] = UNDER_LEFT_ARMREST,
			["under the right armrest"] = UNDER_RIGHT_ARMREST,
			["the front of the chair"] = FRONT_OF_CHAIR,
		}
		local problems: { string } = {}
		for name, point in named do
			local fits, inTheWay = PathCheck.roomToStand(options, point)
			if fits then
				table.insert(problems, `{name} {format(point)}: a body "fits" inside the ground`)
			elseif inTheWay ~= Workspace.Terrain then
				table.insert(problems, `{name} {format(point)}: the part in the way is not the Terrain`)
			end
			local spot = PathCheck.nearestSpot(map, point, NEAR_A_POINT)
			if spot ~= nil then
				table.insert(
					problems,
					`{name} {format(point)}: the walk map has a spot at {format(map.spots[spot].position)}`
				)
			end
		end
		table.sort(problems)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("every landing spot still has room to stand and a spot", function()
		local problems: { string } = {}
		-- The ground under a landing spot is what a player bumps into, like every ground ray in PathCheck (Rule 23): a
		-- flower or a rope with CanCollide off is not ground.
		local ground = RaycastParams.new()
		ground.RespectCanCollide = true
		ground.CollisionGroup = Collisions.GROUP
		for _, landing in landings do
			local hit = Workspace:Raycast(
				landing.position + Vector3.new(0, LANDING_RAY_ABOVE, 0),
				Vector3.new(0, -LANDING_RAY_LENGTH, 0),
				ground
			)
			if hit == nil then
				table.insert(problems, `LandingSpot_{landing.index} at {format(landing.position)}: no ground under it`)
			else
				if not PathCheck.roomToStand(options, hit.Position, hit.Normal) then
					table.insert(
						problems,
						`LandingSpot_{landing.index} at {format(hit.Position)}: no room for a body to stand`
					)
				end
				if PathCheck.nearestSpot(map, hit.Position, map.spacing) == nil then
					table.insert(
						problems,
						`LandingSpot_{landing.index} at {format(hit.Position)}: no walk-map spot within one grid step`
					)
				end
			end
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
		expect(#landings).toBe(8)
	end)

	it("the giant has no stuck spots, and the V1 stuck spots stay fixed", function()
		local problems: { string } = {}
		if #stuck > 0 then
			for _, line in stuckReport() do
				table.insert(problems, line)
			end
		end
		local named = namedProblems()
		if #named > 0 then
			table.insert(problems, "Named V1 stuck spots that failed:")
			for _, problem in named do
				table.insert(problems, `  {problem}`)
			end
		end
		if buildAndSearchSeconds > Config.Stuck.ScanSeconds then
			table.insert(
				problems,
				string.format(
					"The scan took %.1f seconds, over the %g second limit.",
					buildAndSearchSeconds,
					Config.Stuck.ScanSeconds
				)
			)
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	----------------------------------------------------------------------------------------------------------------
	-- The ladders join their ends on the real walk map (stuck safety Task 25, test 6)
	----------------------------------------------------------------------------------------------------------------

	-- The walk-map spots at the foot and the top of a ladder's solid Climb truss, found the way PathCheck joins them:
	-- the end of the truss's longest side, and the nearest spot within two grid steps. nil when there is none.
	local function ladderEndSpots(ladderName: string): (number?, number?)
		local ladder = (world :: any).WalkSurfaces:FindFirstChild(ladderName) :: Instance?
		expect(ladder).never.toBeNil()
		local truss = (ladder :: Instance):FindFirstChild("Climb") :: BasePart?
		expect(truss).never.toBeNil()
		local size = (truss :: BasePart).Size
		local half = if size.X >= size.Y and size.X >= size.Z
			then Vector3.new(size.X / 2, 0, 0)
			elseif size.Y >= size.Z then Vector3.new(0, size.Y / 2, 0)
			else Vector3.new(0, 0, size.Z / 2)
		local endA = (truss :: BasePart).CFrame:PointToWorldSpace(half)
		local endB = (truss :: BasePart).CFrame:PointToWorldSpace(-half)
		local foot, top = endA, endB
		if endB.Y < endA.Y then
			foot, top = endB, endA
		end
		local reach = LADDER_REACH_STEPS * map.spacing
		return PathCheck.nearestSpot(map, foot, reach), PathCheck.nearestSpot(map, top, reach)
	end

	-- Whether a climb link goes from one spot to another.
	local function hasClimbLink(from: number, to: number): boolean
		local links: { PathCheck.Link } = map.links[from] or {}
		for _, link in links do
			if link.to == to and link.kind == "Climb" then
				return true
			end
		end
		return false
	end

	-- Whether a player can get from one spot to any of `goals` by walking alone: no climb, no slide, no jump.
	local function canWalk(from: number, goals: { number }): boolean
		return PathCheck.route(map, from, goals, { allow = { Walk = true } }) ~= nil
	end

	-- Every spot within NEST_REACH studs of a nest point.
	local function spotsNearNest(point: Vector3): { number }
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

	-- Rule 15 (The climb needs no jump), designer 9 and game_creator 1 and 2: the beard ladder joins his belly top to
	-- his nose top and the cap ladder joins his nose top to his cap, by climb links. A walk joins the beard ladder's top
	-- to the cap ladder's foot across the nose top, and the cap ladder's top to both brim nest points with no jump. The
	-- two side nest points are only reported, as "reached" or "not reached".
	it("each ladder joins its two ends on the real walk map", function()
		local problems: { string } = {}
		local beardFoot, beardTop = ladderEndSpots("BeardLadder")
		local capFoot, capTop = ladderEndSpots("CapLadder")
		for label, spot in
			{
				["beard ladder foot"] = beardFoot,
				["beard ladder top"] = beardTop,
				["cap ladder foot"] = capFoot,
				["cap ladder top"] = capTop,
			}
		do
			if spot == nil then
				table.insert(problems, `{label}: no walk-map spot within {LADDER_REACH_STEPS} grid steps`)
			end
		end
		if #problems == 0 then
			if not hasClimbLink(beardFoot :: number, beardTop :: number) then
				table.insert(problems, "no climb link joins the beard ladder's foot to its top")
			end
			if not hasClimbLink(capFoot :: number, capTop :: number) then
				table.insert(problems, "no climb link joins the cap ladder's foot to its top")
			end
			if not canWalk(beardTop :: number, { capFoot :: number }) then
				table.insert(
					problems,
					"no walk joins the beard ladder's top to the cap ladder's foot across the nose top"
				)
			end
			for _, name in sortedNames(BRIM_NESTS) do
				local near = spotsNearNest(BRIM_NESTS[name])
				if #near == 0 then
					table.insert(problems, `{name}: no walk-map spot within {NEST_REACH} studs of it`)
				elseif not canWalk(capTop :: number, near) then
					table.insert(problems, `{name}: no walk from the cap ladder's top reaches it`)
				end
			end
			local report: { string } = {}
			for _, name in sortedNames(SIDE_NESTS) do
				local near = spotsNearNest(SIDE_NESTS[name])
				local reached = #near > 0 and canWalk(capTop :: number, near)
				table.insert(report, `{name}: {if reached then "reached" else "not reached"}`)
			end
			print(
				`[Task 25 test 6] side nest points from the cap ladder's top by walking: {table.concat(report, ", ")}`
			)
		end
		expect(problems).toEqual({})
	end)

	-- The check above must be able to fail: two spots no ladder joins have no climb link, and no walk gets from his
	-- belly to his nose without the beard ladder.
	it("the ladder link check notices two spots no ladder joins", function()
		local beardFoot, beardTop = ladderEndSpots("BeardLadder")
		local capFoot, capTop = ladderEndSpots("CapLadder")
		expect(beardFoot).never.toBeNil()
		expect(capTop).never.toBeNil()
		expect(hasClimbLink(beardFoot :: number, capTop :: number)).toBe(false)
		expect(hasClimbLink(beardTop :: number, capFoot :: number)).toBe(false)
		expect(canWalk(beardFoot :: number, { capFoot :: number })).toBe(false)
	end)

	it("the scan finishes within the time limit", function()
		expect(buildAndSearchSeconds).toBeLessThanOrEqual(Config.Stuck.ScanSeconds)
	end)
end)
