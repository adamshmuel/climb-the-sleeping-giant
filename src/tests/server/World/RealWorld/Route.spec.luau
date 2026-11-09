--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)
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

	it("every egg spot has its own target point, standing within 3 studs of the top of the spot's Base", function()
		local spots, problems = WorldIndex.readEggSpots(realWorld())
		expect(problems).toEqual({})
		local byTarget: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in loadRoute() do
			if point.target then
				byTarget[point.target] = point
			end
		end
		expect(#(spots :: { WorldIndex.EggSpot })).toBe(16)
		for _, spot in spots :: { WorldIndex.EggSpot } do
			local point = byTarget[spot.name]
			expect({ spot = spot.name, found = point ~= nil }).toEqual({ spot = spot.name, found = true })
			local distance = (flat(point.position) - flat(spot.cframe.Position)).Magnitude
			expect({ spot = spot.name, near = distance <= TARGET_REACH, distance = distance }).toEqual({
				spot = spot.name,
				near = true,
				distance = distance,
			})
		end
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

	it("the only targets are the 16 egg spots, the 8 gates and the 8 spawn spots", function()
		local count = 0
		for _, point in loadRoute() do
			if point.target then
				count += 1
				local isEgg = string.match(point.target, "^EggSpot_%a+_%d+$") ~= nil
				local isGate = string.match(point.target, "^Gate_[1-8]$") ~= nil
				local isSpawn = string.match(point.target, "^Spawn_[1-8]$") ~= nil
				expect({ target = point.target, known = isEgg or isGate or isSpawn }).toEqual({
					target = point.target,
					known = true,
				})
			end
		end
		expect(count).toBe(32)
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
			local problems: { [string]: string } = {}
			for _, point in points do
				for _, neighbourName in point.neighbours do
					if point.name < neighbourName then -- each link once
						checked += 1
						local problem = PathCheck.linkProblem(options, point.position, byName[neighbourName].position)
						if problem ~= nil then
							problems[`{point.name} to {neighbourName}`] = problem
						end
					end
				end
			end
			PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
			expect(problems).toEqual({}) -- every link that fails, with why
			expect(checked > 50).toBe(true)
		end
	)
end)
