--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local RouteData = require(game:GetService("ReplicatedStorage").Shared.RouteData)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)
local NestRoute = require(script.Parent.NestRoute)
local RAY_START_ABOVE = Helpers.RAY_START_ABOVE
local STAND_LIMIT = Helpers.STAND_LIMIT
local describeVector = Helpers.describeVector
local flat = Helpers.flat
local groundRay = Helpers.groundRay
local loadRoute = Helpers.loadRoute
local realWorld = Helpers.realWorld

-- The footprint route and the landing spots (Task 23). They are built by tools/world/08-route/ (run Run.luau). These tests only
-- READ the real world.
describe("the real world, route and landing spots", function()
	local Workspace = game:GetService("Workspace")

	local GATE_OUTSIDE = 5.5 -- studs from the middle of a Safe Gate toward its spawn spot: just outside the arch
	local TARGET_REACH = 3 -- studs, across the ground, between a target point and the thing it stands at
	local MAX_LINK_LENGTH = 25 -- studs: short links follow the walk surfaces, with no corner-cutting

	local CLIMB_FOOT_REACH = 3 -- studs (flat): a ladder foot point is this close to the bottom of its ladder's Climb truss
	local CLIMB_FOOT_MAX_HEIGHT = 5 -- studs: a ladder foot point stands on the grass, not up the ladder

	local POINT_SIZE = Vector3.new(1, 0.2, 1)

	it("the route has no problems, and is a Model that always streams to players", function()
		local points, problems = WorldIndex.readRoute(realWorld())
		expect(problems).toEqual({})
		expect(points).never.toBeNil()
		local route = realWorld():FindFirstChild("Route") :: Model
		expect(route:IsA("Model")).toBe(true)
		expect(route.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Persistent)
	end)

	it(
		"every route point and landing spot is an invisible, anchored 1 by 0.2 by 1 part that nothing touches",
		function()
			local route = realWorld():FindFirstChild("Route") :: Instance
			local landing = realWorld():FindFirstChild("LandingSpots") :: Instance
			expect(route).never.toBeNil()
			expect(landing).never.toBeNil()
			local parts: { Instance } = {}
			for _, child in route:GetChildren() do
				table.insert(parts, child)
			end
			for _, child in landing:GetChildren() do
				table.insert(parts, child)
			end
			expect(#parts > 8).toBe(true)
			for _, instance in parts do
				local label = instance:GetFullName()
				expect({ label = label, isPart = instance:IsA("Part") }).toEqual({ label = label, isPart = true })
				local part = instance :: Part
				expect({ label = label, size = part.Size }).toEqual({ label = label, size = POINT_SIZE })
				expect({
					label = label,
					transparency = part.Transparency,
					anchored = part.Anchored,
					canCollide = part.CanCollide,
					canQuery = part.CanQuery,
					canTouch = part.CanTouch,
					castShadow = part.CastShadow,
				}).toEqual({
					label = label,
					transparency = 1,
					anchored = true,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					castShadow = false,
				})
			end
		end
	)

	it("every route point stands on ground a player walks on: its top is on the surface, and not in water", function()
		for _, point in loadRoute() do
			local hit = Workspace:Raycast(
				point.position + Vector3.new(0, RAY_START_ABOVE, 0),
				Vector3.new(0, -RAY_START_ABOVE - 2, 0),
				groundRay()
			)
			local label = `{point.name} {describeVector(point.position)}`
			expect({ label = label, found = hit ~= nil }).toEqual({ label = label, found = true })
			local ground = hit :: RaycastResult
			expect({ label = label, water = ground.Material == Enum.Material.Water }).toEqual({
				label = label,
				water = false,
			})
			expect({ label = label, onSurface = math.abs(ground.Position.Y - point.position.Y) <= STAND_LIMIT }).toEqual({
				label = label,
				onSurface = true,
			})
		end
	end)

	-- Plan 5 Task 17, test 1. A nest "has its point" when exactly one route point names it and that point is within
	-- NestRoute.ANCHOR_REACH studs of the nest's prompt anchor. Returns the nests checked and one line per failure.
	local function nestPointProblems(caps: boolean): { checked: number, problems: { string } }
		local byTarget = NestRoute.pointsByTarget()
		local problems: { string } = {}
		local nests = NestRoute.group(caps)
		for _, spot in nests do
			local found = byTarget[spot.name] or {}
			if #found ~= 1 then
				table.insert(problems, `{spot.name}: {#found} route points name it`)
			else
				local distance = (found[1].position - spot.promptAnchor.WorldPosition).Magnitude
				if distance > NestRoute.ANCHOR_REACH then
					table.insert(problems, string.format("%s: point %.1f from its anchor", spot.name, distance))
				end
			end
		end
		return { checked = #nests, problems = problems }
	end

	it(
		"each of the 34 nests the route reaches has exactly one route point, within 8 studs of its prompt anchor",
		function()
			expect(nestPointProblems(false)).toEqual({ checked = 34, problems = {} })
		end
	)

	it("ACCEPTED RED until 17c: each of the 4 cap nests has one route point within 8 studs", function()
		expect(nestPointProblems(true)).toEqual({ checked = 4, problems = {} })
	end)

	it("every Safe Gate has its own target point just outside the arch, and every spawn spot has its own", function()
		local gardens, problems = WorldIndex.readGardens(realWorld())
		expect(problems).toEqual({})
		local byTarget: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in loadRoute() do
			if point.target then
				byTarget[point.target] = point
			end
		end
		expect(#(gardens :: { WorldIndex.Garden })).toBe(8)
		for _, garden in gardens :: { WorldIndex.Garden } do
			local gatePoint = byTarget[`Gate_{garden.index}`]
			expect({ garden = garden.index, gate = gatePoint ~= nil }).toEqual({ garden = garden.index, gate = true })
			local gateMiddle = flat(garden.gate:GetPivot().Position)
			local towardSpawn = (flat(garden.spawnSpot.Position) - gateMiddle).Unit
			local outside = gateMiddle + towardSpawn * GATE_OUTSIDE
			local gateGap = (flat(gatePoint.position) - outside).Magnitude
			expect({ garden = garden.index, gateNear = gateGap <= TARGET_REACH }).toEqual({
				garden = garden.index,
				gateNear = true,
			})

			local spawnPoint = byTarget[`Spawn_{garden.index}`]
			expect({ garden = garden.index, spawn = spawnPoint ~= nil }).toEqual({ garden = garden.index, spawn = true })
			local spawnGap = (flat(spawnPoint.position) - flat(garden.spawnSpot.Position)).Magnitude
			expect({ garden = garden.index, spawnNear = spawnGap <= TARGET_REACH }).toEqual({
				garden = garden.index,
				spawnNear = true,
			})
		end
	end)

	it("the only targets are the nests, the 8 gates and the 8 spawn spots, each named by one point", function()
		local nestNames: { [string]: boolean } = {}
		for _, spot in NestRoute.nests() do
			nestNames[spot.name] = true
		end
		local unknown: { string } = {}
		local doubled: { string } = {}
		for target, points in NestRoute.pointsByTarget() do
			local isGate = string.match(target, "^Gate_[1-8]$") ~= nil
			local isSpawn = string.match(target, "^Spawn_[1-8]$") ~= nil
			if not (nestNames[target] or isGate or isSpawn) then
				table.insert(unknown, target)
			end
			if #points ~= 1 then
				table.insert(doubled, target)
			end
		end
		table.sort(unknown)
		table.sort(doubled)
		expect({ unknown = unknown, doubled = doubled }).toEqual({ unknown = {}, doubled = {} })
	end)

	it("every point can reach every other point: the route is one connected piece", function()
		local points = loadRoute()
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in points do
			byName[point.name] = point
		end
		local seen: { [string]: boolean } = { [points[1].name] = true }
		local queue = { points[1] }
		local head = 1
		while head <= #queue do
			local current = queue[head]
			head += 1
			for _, neighbourName in current.neighbours do
				if not seen[neighbourName] then
					seen[neighbourName] = true
					table.insert(queue, byName[neighbourName])
				end
			end
		end
		local unreached: { string } = {}
		for _, point in points do
			if not seen[point.name] then
				table.insert(unreached, point.name)
			end
		end
		expect(unreached).toEqual({})
	end)

	it("no link is longer than 25 studs", function()
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		local points = loadRoute()
		for _, point in points do
			byName[point.name] = point
		end
		for _, point in points do
			for _, neighbourName in point.neighbours do
				-- A climb link is a ladder: it runs the ladder's whole height, so the length limit is for walks only.
				if RouteData.isClimb(point, byName[neighbourName]) then
					continue
				end
				local length = (byName[neighbourName].position - point.position).Magnitude
				local label = `{point.name} to {neighbourName}`
				expect({ label = label, short = length <= MAX_LINK_LENGTH, length = length }).toEqual({
					label = label,
					short = true,
					length = length,
				})
			end
		end
	end)

	it("each climb link joins a foot on the grass at its ladder's truss to a top on that ladder's top pad", function()
		local walkSurfaces = (realWorld() :: any).WalkSurfaces
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		local points = loadRoute()
		for _, point in points do
			byName[point.name] = point
		end
		local climbs = 0
		for _, point in points do
			for _, neighbourName in point.neighbours do
				local other = byName[neighbourName]
				-- each climb link once, from the lower end
				if not RouteData.isClimb(point, other) or point.position.Y > other.position.Y then
					continue
				end
				climbs += 1
				local ladder = walkSurfaces:FindFirstChild(point.ladder :: string) :: Model
				local truss = ladder:FindFirstChild("Climb") :: TrussPart
				local pad = ladder:FindFirstChild("TopPad") :: BasePart
				-- the truss runs along its local Z: its lower end is the one with the lower Y
				local endA = (truss.CFrame * CFrame.new(0, 0, truss.Size.Z / 2)).Position
				local endB = (truss.CFrame * CFrame.new(0, 0, -truss.Size.Z / 2)).Position
				local bottom = if endA.Y < endB.Y then endA else endB
				local footGap = (flat(point.position) - flat(bottom)).Magnitude
				local padOffset = pad.CFrame:PointToObjectSpace(other.position)
				local label = `{point.name} to {neighbourName}`
				expect({
					label = label,
					footNearTruss = footGap <= CLIMB_FOOT_REACH,
					footOnGrass = point.position.Y < CLIMB_FOOT_MAX_HEIGHT,
					topOnPad = math.abs(padOffset.X) <= pad.Size.X / 2 and math.abs(padOffset.Z) <= pad.Size.Z / 2,
				}).toEqual({ label = label, footNearTruss = true, footOnGrass = true, topOnPad = true })
			end
		end
		expect(climbs).toBe(2) -- the two boot ladders
	end)

	it(
		"every link is walkable: ground under the whole way, not too steep, no water, and nothing solid in the way",
		function()
			local world = realWorld()
			-- Left out of the body check: the two ramp planks. A player steps on or off a ramp foot over its edge, which
			-- the body box touches by design (the edge stands 1 to 2 studs above the grass beside it).
			local rampPlanks: { Instance } = {
				(world :: any).WalkSurfaces.BootRamp.Ramp_Walk,
				(world :: any).WalkSurfaces.RightBootRamp.Ramp_Walk,
			}
			local options = PathCheck.defaults(Workspace)
			options.boxIgnores = rampPlanks
			-- Rule 23 (One walk check for everything): this check counts the meadow ground too, like the stuck scan.
			expect(options.terrain).toBe(Workspace.Terrain)

			local byName: { [string]: WorldIndex.RoutePoint } = {}
			local points = loadRoute()
			for _, point in points do
				byName[point.name] = point
			end
			local checked = 0
			local skipOptions: { [string]: any } = {}
			local problems: { [string]: string } = {}
			for _, point in points do
				for _, neighbourName in point.neighbours do
					if point.name < neighbourName then -- each link once
						-- A climb link is a ladder, not a walk: the climb test above checks it instead.
						if not RouteData.isClimb(point, byName[neighbourName]) then
							checked += 1
							-- RouteData.bodyBoxSkip names the parts a link leaves out of the body box
							local linkOptions = options
							local skipList = RouteData.bodyBoxSkip(point.name, neighbourName)
							if #skipList > 0 then
								local skipKey = table.concat(skipList, ",")
								if skipOptions[skipKey] == nil then
									local made = PathCheck.defaults(Workspace)
									local ignores: { Instance } = { rampPlanks[1], rampPlanks[2] }
									for _, part in RouteData.skipInstances(world, point.name, neighbourName) do
										table.insert(ignores, part)
									end
									made.boxIgnores = ignores
									skipOptions[skipKey] = made
								end
								linkOptions = skipOptions[skipKey]
							end
							-- A link the 17w Play walk proved (RouteData.isWalked) is not judged here, exactly as the world
							-- script (tools/world/08-route/RouteChecks.luau) leaves it out: ground, slope, body box and
							-- water (linkProblem is one call). Safe for water: walked links are 30 or more studs above
							-- the meadow.
							local problem = nil
							if not RouteData.isWalked(point.name, neighbourName) then
								problem =
									PathCheck.linkProblem(linkOptions, point.position, byName[neighbourName].position)
							end
							if problem ~= nil then
								problems[`{point.name} to {neighbourName}`] = problem
							end
						end
					end
				end
			end
			PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
			for _, skipped in skipOptions do
				PathCheck.cleanup(skipped)
			end
			expect(problems).toEqual({}) -- every link that fails, with why
			expect(checked > 50).toBe(true)
		end
	)

	-- Feet (x, z) the 17w Play walks traced, from work/p5t17/17w-note.md ("ARM-L PASS" and "ARM-R PASS" lines).
	local TRACED_FEET: { { number } } = {
		{ -5, -26 },
		{ -12, -21 },
		{ -15, -19 },
		{ -18, -17 },
		{ -22, -14 },
		{ -25, -12 },
		{ -28, -10 },
		{ -31, -8 },
		{ -33, -7 },
		{ -40, -4 },
		{ -43, -2 },
		{ -46, -1 },
		{ -48, 1 },
		{ -50, 2 },
		{ -55, 0 },
		{ -56, -3 },
		{ -56, -8 },
		{ 6, -26 },
		{ 9, -24 },
		{ 12, -21 },
		{ 16, -19 },
		{ 19, -16 },
		{ 23, -14 },
		{ 26, -12 },
		{ 31, -8 },
		{ 34, -6 },
		{ 37, -5 },
		{ 41, -3 },
		{ 44, -1 },
		{ 46, 1 },
		{ 48, 2 },
		{ 50, 3 },
		{ 55, -1 },
		{ 56, -4 },
		{ 56, -8 },
		-- 17b Step 5 walk W: Egg_Rare_4 to ArmRight_0, the feet the player stood on at the start and on arrival
		{ 2.5, -30.5 },
		{ 5.1, -27.2 },
	}
	-- Ends that are not on a traced foot on purpose (RouteData.luau, WALKED_LINKS comment): the cuff nests, which sit 2 to
	-- 3 studs from the ledge foot the walk crossed. They get the wider limit, not a skip.
	local OFF_FOOT_OK: { [string]: boolean } = {
		Nest_CuffFront_Left = true,
		Nest_CuffBack_Left = true,
		Nest_CuffFront_Right = true,
		Nest_CuffBack_Right = true,
	}
	local OFF_FOOT_LIMIT = 3.5 -- studs: the 4 cuff nests sit 2 to 3 studs from the ledge foot the walk crossed

	it("every walked link has both ends within 1 stud of a foot the 17w walks traced", function()
		local byShort: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in loadRoute() do
			byShort[string.gsub(point.name, "^RoutePoint_", "")] = point
		end
		local off: { string } = {}
		for _, link in RouteData.walkedLinks() do
			for _, name in link do
				local point = byShort[name]
				if point == nil then
					table.insert(off, `{name} is missing`)
				else
					local limit = if OFF_FOOT_OK[name] then OFF_FOOT_LIMIT else 1
					local nearest = math.huge
					for _, foot in TRACED_FEET do
						nearest = math.min(
							nearest,
							(Vector2.new(foot[1], foot[2]) - Vector2.new(point.position.X, point.position.Z)).Magnitude
						)
					end
					if nearest > limit then
						table.insert(off, `{name} is {nearest} studs from a traced foot`)
					end
				end
			end
		end
		expect(off).toEqual({})
		expect(#RouteData.walkedLinks() > 20).toBe(true)
	end)

	it("the walked links mirror on both sides: every Left link has its Right link", function()
		local links = RouteData.walkedLinks()
		local lefts = 0
		for _, link in links do
			if string.find(link[1], "Left", 1, true) or string.find(link[2], "Left", 1, true) then
				lefts += 1
				local mirrored = {}
				for _, name in link do
					table.insert(mirrored, (string.gsub(name, "Left", "Right")))
				end
				-- the right arm has one more point than the left (ArmRight_0 to 10, ArmLeft_1 to 9): arm points are
				-- matched by the strap links, which mirror exactly
				if string.find(mirrored[1] .. mirrored[2], "Arm", 1, true) == nil then
					expect(RouteData.isWalked(mirrored[1], mirrored[2])).toBe(true)
				end
			end
		end
		expect(lefts > 10).toBe(true)
	end)
end)
