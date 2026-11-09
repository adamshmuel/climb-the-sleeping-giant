--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Helpers = require(script.Parent.Helpers)
local RAY_START_ABOVE = Helpers.RAY_START_ABOVE
local STAND_LIMIT = Helpers.STAND_LIMIT
local describeVector = Helpers.describeVector
local flat = Helpers.flat
local groundRay = Helpers.groundRay
local loadRoute = Helpers.loadRoute
local realWorld = Helpers.realWorld

describe("the real world, route and landing spots", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")
	local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)

	local LANDING_COUNT = 8
	local LANDING_SPACING = 10
	local LANDING_REACH = 110 -- studs, across the ground, from the giant's middle
	local LANDING_BOX = Vector3.new(4, 6, 4) -- a standing player with room around
	local LANDING_BOX_LIFT = 0.1
	local STEM_LINK_CLEARANCE = 3 -- studs, across the ground, between a route link and a sunflower stem
	local EDGE_LINK_CLEARANCE = 1 -- studs between a route link and the edge of a bush or rock (half a player's width)
	local PROP_LANDING_CLEARANCE = 5 -- studs between a landing spot and a stem, or the edge of a bush or rock
	local EGG_LANDING_CLEARANCE = 10 -- studs between a landing spot and every egg spot (the grab reach is 8)

	-- The meadow props a player walks straight through (their CanCollide is off, so the solid-part checks never see
	-- them). designer owns which props count. The same list and the same circles are in tools/world/08-route/RoutePlaces.luau.
	--   * a sunflower: the position of its Stem part;
	--   * a bush or rock: a circle at the middle of the model's bounding box, as wide as half its smaller side.
	-- Ground cover (flowers, ferns, grass tufts, clovers, water lilies) is left out: a player may walk over it. Trees
	-- have solid trunks, which the solid-part checks already see. Workspace.World.FarTrees is left out.
	local SOLID_LOOKING_PROPS: { [string]: boolean } = {
		Nature_Bush = true,
		Nature_BerryBush = true,
		Nature_FloweringBush = true,
		GateBush = true,
		Nature_MossyBoulder = true,
		Nature_MediumRock = true,
		Nature_Stump = true,
		Inno_Mushroom_02 = true,
		Inno_Mushroom_03 = true,
	}

	local function loadLandingSpots(): { WorldIndex.LandingSpot }
		local spots, problems = WorldIndex.readLandingSpots(realWorld())
		expect(problems).toEqual({})
		return spots :: { WorldIndex.LandingSpot }
	end

	type Stem = { name: string, x: number, z: number }
	type Circle = { name: string, x: number, z: number, radius: number }

	-- Every sunflower stem and every bush or rock circle under Workspace.World (FarTrees left out).
	local function collectProps(world: Instance): ({ Stem }, { Circle })
		local stems: { Stem } = {}
		local circles: { Circle } = {}
		for _, instance in world:GetDescendants() do
			if not instance:IsA("Model") then
				continue
			end
			local isSunflower = instance.Name == "Nature_Sunflower"
			if not isSunflower and not SOLID_LOOKING_PROPS[instance.Name] then
				continue
			end
			if instance:FindFirstAncestor("FarTrees") ~= nil then
				continue
			end
			if isSunflower then
				local stem = instance:FindFirstChild("Stem")
				expect({ sunflower = instance:GetFullName(), hasStem = stem ~= nil and stem:IsA("BasePart") }).toEqual({
					sunflower = instance:GetFullName(),
					hasStem = true,
				})
				local position = (stem :: BasePart).Position
				table.insert(stems, { name = instance.Name, x = position.X, z = position.Z })
			else
				local boxCFrame, boxSize = instance:GetBoundingBox()
				table.insert(circles, {
					name = instance.Name,
					x = boxCFrame.Position.X,
					z = boxCFrame.Position.Z,
					radius = math.min(boxSize.X, boxSize.Z) / 2,
				})
			end
		end
		return stems, circles
	end

	-- The shortest distance, across the ground, from a point to the line between two points.
	local function distanceToLink(x: number, z: number, from: Vector3, to: Vector3): number
		local point = Vector3.new(x, 0, z)
		local start, finish = flat(from), flat(to)
		local along = finish - start
		local fraction = math.clamp((point - start):Dot(along) / along:Dot(along), 0, 1)
		return (point - (start + along * fraction)).Magnitude
	end

	it("there are 8 landing spots, in the Meadow and in no garden, on ground a player can stand on", function()
		local world = realWorld()
		local zoneBoxes, zoneProblems = WorldIndex.readZones(world)
		expect(zoneProblems).toEqual({})
		local gardens, gardenProblems = WorldIndex.readGardens(world)
		expect(gardenProblems).toEqual({})
		local gardenBoxes = PlayerTracker.gardenBoxes(gardens :: { WorldIndex.Garden })
		local maxSlope = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
		local spots = loadLandingSpots()
		expect(#spots).toBe(LANDING_COUNT)
		for _, spot in spots do
			local label = `LandingSpot_{spot.index} {describeVector(spot.position)}`
			-- both its feet and its root (about 3 studs up) are in the Meadow, and in no garden
			for _, height in { 0, 3 } do
				local place =
					Zones.locate(spot.position + Vector3.new(0, height, 0), zoneBoxes :: { Zones.ZoneBox }, gardenBoxes)
				expect({ label = label, height = height, place = place }).toEqual({
					label = label,
					height = height,
					place = { zone = "Meadow", garden = nil },
				})
			end
			local hit = Workspace:Raycast(
				spot.position + Vector3.new(0, RAY_START_ABOVE, 0),
				Vector3.new(0, -RAY_START_ABOVE - 2, 0),
				groundRay()
			)
			expect({ label = label, found = hit ~= nil }).toEqual({ label = label, found = true })
			local ground = hit :: RaycastResult
			expect({ label = label, water = ground.Material == Enum.Material.Water }).toEqual({
				label = label,
				water = false,
			})
			expect({ label = label, onGround = math.abs(ground.Position.Y - spot.position.Y) <= STAND_LIMIT }).toEqual({
				label = label,
				onGround = true,
			})
			expect({ label = label, standable = ground.Normal.Y >= maxSlope }).toEqual({
				label = label,
				standable = true,
			})
		end
	end)

	it("every landing spot has room for a standing player: a 4 by 6 by 4 box above it touches no solid part", function()
		local params = OverlapParams.new()
		params.RespectCanCollide = true
		for _, spot in loadLandingSpots() do
			local label = `LandingSpot_{spot.index} {describeVector(spot.position)}`
			local box = CFrame.new(spot.position + Vector3.new(0, LANDING_BOX_LIFT + LANDING_BOX.Y / 2, 0))
			local touching: { string } = {}
			for _, part in Workspace:GetPartBoundsInBox(box, LANDING_BOX, params) do
				table.insert(touching, part:GetFullName())
			end
			expect({ label = label, touching = touching }).toEqual({ label = label, touching = {} })
		end
	end)

	it("landing spots are at least 10 studs apart, and all within 110 studs of the giant's middle", function()
		local spots = loadLandingSpots()
		local giantMiddle = flat((realWorld() :: any).Giant:GetPivot().Position)
		for first = 1, #spots do
			local distance = (flat(spots[first].position) - giantMiddle).Magnitude
			expect({ spot = first, close = distance <= LANDING_REACH, distance = distance }).toEqual({
				spot = first,
				close = true,
				distance = distance,
			})
			for second = first + 1, #spots do
				local apart = (flat(spots[first].position) - flat(spots[second].position)).Magnitude
				expect({ first = first, second = second, apart = apart >= LANDING_SPACING, distance = apart }).toEqual({
					first = first,
					second = second,
					apart = true,
					distance = apart,
				})
			end
		end
	end)

	it("every route link stays clear of sunflower stems, bushes and rocks", function()
		local stems, circles = collectProps(realWorld())
		expect(#stems > 0).toBe(true)
		expect(#circles > 0).toBe(true)
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		local points = loadRoute()
		for _, point in points do
			byName[point.name] = point
		end
		local problems: { string } = {}
		for _, point in points do
			for _, neighbourName in point.neighbours do
				if point.name < neighbourName then -- each link once
					local from, to = point.position, byName[neighbourName].position
					for _, stem in stems do
						local distance = distanceToLink(stem.x, stem.z, from, to)
						if distance < STEM_LINK_CLEARANCE then
							table.insert(
								problems,
								string.format(
									"%s to %s passes %.1f studs from a sunflower stem at (%.1f, %.1f)",
									point.name,
									neighbourName,
									distance,
									stem.x,
									stem.z
								)
							)
						end
					end
					for _, circle in circles do
						local gap = distanceToLink(circle.x, circle.z, from, to) - circle.radius
						if gap < EDGE_LINK_CLEARANCE then
							table.insert(
								problems,
								string.format(
									"%s to %s passes %.1f studs from the edge of a %s at (%.1f, %.1f)",
									point.name,
									neighbourName,
									gap,
									circle.name,
									circle.x,
									circle.z
								)
							)
						end
					end
				end
			end
		end
		table.sort(problems)
		expect(problems).toEqual({})
	end)

	it("every landing spot has open sky above it: nothing is over the spot", function()
		for _, spot in loadLandingSpots() do
			local label = `LandingSpot_{spot.index} {describeVector(spot.position)}`
			local hit = Workspace:Raycast(spot.position + Vector3.new(0, LANDING_BOX_LIFT, 0), Vector3.new(0, 300, 0))
			expect({ label = label, over = hit and hit.Instance:GetFullName() }).toEqual({ label = label, over = nil })
		end
	end)

	it("landing spots are at least 10 studs from every egg spot", function()
		local eggSpots, eggProblems = WorldIndex.readEggSpots(realWorld())
		expect(eggProblems).toEqual({})
		local problems: { string } = {}
		for _, landing in loadLandingSpots() do
			for _, egg in eggSpots :: { WorldIndex.EggSpot } do
				local distance = (flat(landing.position) - flat(egg.cframe.Position)).Magnitude
				if distance < EGG_LANDING_CLEARANCE then
					table.insert(
						problems,
						string.format("LandingSpot_%d is %.1f studs from %s", landing.index, distance, egg.name)
					)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("landing spots stay clear of sunflower stems, bushes and rocks", function()
		local stems, circles = collectProps(realWorld())
		expect(#stems > 0).toBe(true)
		expect(#circles > 0).toBe(true)
		local problems: { string } = {}
		for _, landing in loadLandingSpots() do
			local spot = flat(landing.position)
			for _, stem in stems do
				local distance = (spot - Vector3.new(stem.x, 0, stem.z)).Magnitude
				if distance < PROP_LANDING_CLEARANCE then
					table.insert(
						problems,
						string.format(
							"LandingSpot_%d is %.1f studs from a sunflower stem at (%.1f, %.1f)",
							landing.index,
							distance,
							stem.x,
							stem.z
						)
					)
				end
			end
			for _, circle in circles do
				local gap = (spot - Vector3.new(circle.x, 0, circle.z)).Magnitude - circle.radius
				if gap < PROP_LANDING_CLEARANCE then
					table.insert(
						problems,
						string.format(
							"LandingSpot_%d is %.1f studs from the edge of a %s at (%.1f, %.1f)",
							landing.index,
							gap,
							circle.name,
							circle.x,
							circle.z
						)
					)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("the route has the meadow points designer placed, and the links round the props", function()
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in loadRoute() do
			byName[point.name] = point
		end
		local placed: { [string]: { number } } = {
			Meadow_14 = { 102, -22 },
			Meadow_16 = { 106, -6 },
			Meadow_17 = { 103, 4 },
			Meadow_18 = { 64, -84 },
			Meadow_4 = { -57, -68 },
			Meadow_6 = { -18, -75 },
		}
		local names: { string } = {}
		for name in placed do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local point = byName[`RoutePoint_{name}`]
			expect({ name = name, found = point ~= nil }).toEqual({ name = name, found = true })
			local where = placed[name]
			local gap = (flat(point.position) - Vector3.new(where[1], 0, where[2])).Magnitude
			expect({ name = name, within = gap <= 0.5, gap = gap }).toEqual({ name = name, within = true, gap = gap })
		end

		local function linked(first: string, second: string): boolean
			local point = byName[`RoutePoint_{first}`]
			return point ~= nil and table.find(point.neighbours, `RoutePoint_{second}`) ~= nil
		end
		local wanted = {
			{ "Egg_Common_7", "Meadow_14" },
			{ "Meadow_14", "Meadow_16" },
			{ "Meadow_16", "Meadow_17" },
			{ "Meadow_17", "Meadow_15" },
			{ "Bridge6_Giant", "Meadow_18" },
			{ "Meadow_18", "Egg_Common_6" },
		}
		for _, pair in wanted do
			expect({ first = pair[1], second = pair[2], linked = linked(pair[1], pair[2]) }).toEqual({
				first = pair[1],
				second = pair[2],
				linked = true,
			})
		end
		local gone = { { "Meadow_14", "Meadow_15" }, { "Bridge6_Giant", "Egg_Common_6" } }
		for _, pair in gone do
			expect({ first = pair[1], second = pair[2], linked = linked(pair[1], pair[2]) }).toEqual({
				first = pair[1],
				second = pair[2],
				linked = false,
			})
		end
	end)

	it("the landing spots are at the approved places", function()
		-- Spot 2 is a stud and a half from (-43, -96) and spot 3 a stud from (52, -92): the first had a flower clump
		-- 2.3 studs away, the second stands on a 22 degree slope (the rule says flat grass). Spot 8 is a stud west of
		-- (50, -54), where a flower clump was 2.4 studs away. Spots 5 and 7 moved off the boot ladder feet (Gardens and
		-- ways up); the spec's x -62 and 62 touch the sock and the teacup, so they are the nearest clear spots, measured.
		local approved: { { number } } = {
			{ -45, -79 },
			{ -42, -97 },
			{ 52, -91 },
			{ 48, -80 },
			{ -58, -64 },
			{ -50, -54 },
			{ 56, -62 }, -- 5b2 moved: product's addendum, spec 3 line 93
			{ 49, -54 },
		}
		local spots = loadLandingSpots()
		expect(#spots).toBe(#approved)
		for _, spot in spots do
			local where = approved[spot.index]
			local gap = (flat(spot.position) - Vector3.new(where[1], 0, where[2])).Magnitude
			expect({ spot = spot.index, within = gap <= 0.5, gap = gap }).toEqual({
				spot = spot.index,
				within = true,
				gap = gap,
			})
		end
	end)

	it("has a face point the bounced players turn to (Giant.SleepEyes), high on the front of his head", function()
		local face, problems = WorldIndex.readGiantFace(realWorld())
		expect(problems).toEqual({})
		local point = face :: Vector3
		expect(point.Y > 90 and point.Y < 100).toBe(true)
		expect(math.abs(point.X) < 5 and math.abs(point.Z) < 5).toBe(true)
	end)
end)
