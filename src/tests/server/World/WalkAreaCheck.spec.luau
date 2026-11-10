--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)
local WalkAreaCheck = require(ServerScriptService.Server.World.WalkAreaCheck)
local WalkAreaFacts = require(ServerStorage.Tests.server.World.StuckScan.WalkAreaFacts)

-- The walk-area checks on small made-up worlds (plan 5 Task 14). Each test builds its world in a WorldModel in
-- ServerStorage (as PathCheck/WalkMap.spec.luau does) and destroys it afterwards. The ground's top is at y = 0.
-- Task 15g: the repaired checks (gap filter, floating filter, and WalkAreaFacts.artTopUnder / isCutGap / skipRampSpot).
type Skip = (Vector3) -> boolean
local gapsSkipping = WalkAreaCheck.gaps
local floatSkipping = WalkAreaCheck.floatingOrSunk

describe("WalkAreaCheck", function()
	local FLOOR_AREA: PathCheck.Area = { min = Vector3.new(-20, -12, -20), max = Vector3.new(20, 12, 20) }

	local world: WorldModel
	local options: PathCheck.Options

	local function addBox(name: string, min: Vector3, max: Vector3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = max - min
		part.CFrame = CFrame.new((min + max) / 2)
		part.Parent = world
		return part
	end

	-- A look-only floor: seen, but nothing stands on it (the walk map skips it).
	local function addVisibleFloor(topY: number): Part
		local part = addBox("VisibleFloor", Vector3.new(-20, topY - 1, -20), Vector3.new(20, topY, 20))
		part.CanCollide = false
		return part
	end

	-- A solid floor nobody sees.
	local function addInvisibleBox(name: string, min: Vector3, max: Vector3): Part
		local part = addBox(name, min, max)
		part.Transparency = 1
		return part
	end

	-- A 1 stud thick, 40 wide slab whose top surface starts at (startX, startY) and goes down toward +x at `degrees`
	-- from level, `length` studs along the surface. Returns the point its top surface ends at.
	local function addSlab(name: string, startX: number, startY: number, degrees: number, length: number): Vector3
		local direction = Vector3.new(math.cos(math.rad(degrees)), -math.sin(math.rad(degrees)), 0)
		local normal = Vector3.new(math.sin(math.rad(degrees)), math.cos(math.rad(degrees)), 0)
		local start = Vector3.new(startX, startY, 0)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(length, 1, 40)
		part.CFrame = CFrame.fromMatrix(start + direction * (length / 2) - normal * 0.5, direction, normal)
		part.Parent = world
		return start + direction * length
	end

	-- A slab tilted `degrees` around the middle, up toward -x, 12 studs across.
	local function addTilted(degrees: number): Part
		local part = Instance.new("Part")
		part.Name = "Tilted"
		part.Anchored = true
		part.Size = Vector3.new(12, 1, 12)
		part.CFrame = CFrame.Angles(0, 0, math.rad(degrees))
		part.Parent = world
		return part
	end

	local function ids(map: PathCheck.WalkMap): { number }
		local all = {}
		for _, spot in map.spots do
			table.insert(all, spot.id)
		end
		return all
	end

	it("the seam angle is the one number in Config.Nests", function()
		expect(WalkAreaCheck.SEAM_DEGREES).toBe(Config.Nests.SeamDegrees)
	end)

	local function countKind(problems: { WalkAreaCheck.Problem }, kind: string): number
		local count = 0
		for _, problem in problems do
			if problem.kind == kind then
				count += 1
			end
		end
		return count
	end

	-- The height of the first thing the eye sees going down: look-only and solid parts count, invisible ones don't.
	local function visibleHeightAt(x: number, z: number, maxY: number): number?
		local y = maxY
		for _ = 1, 8 do
			local hit = world:Raycast(Vector3.new(x, y, z), Vector3.new(0, -100, 0))
			if hit == nil then
				return nil
			end
			if (hit.Instance :: BasePart).Transparency < 1 then
				return hit.Position.Y
			end
			y = hit.Position.Y - 0.01
		end
		return nil
	end

	local function notOnSkin(_part: BasePart): boolean
		return false
	end

	-- Sample points every 2 studs over the visible floor (y = 0), from -18 to 18.
	local function floorSamples(): { Vector3 }
		local samples = {}
		for x = -18, 18, 2 do
			for z = -18, 18, 2 do
				table.insert(samples, Vector3.new(x, 0, z))
			end
		end
		return samples
	end

	-- An invisible solid floor (top y = 0) with a square hole from -3 to 3 in x and z, or whole when `hole` is false.
	local function addWalkFloor(hole: boolean)
		if not hole then
			addInvisibleBox("WalkFloor", Vector3.new(-20, -1, -20), Vector3.new(20, 0, 20))
			return
		end
		addInvisibleBox("WalkNorth", Vector3.new(-20, -1, 3), Vector3.new(20, 0, 20))
		addInvisibleBox("WalkSouth", Vector3.new(-20, -1, -20), Vector3.new(20, 0, -3))
		addInvisibleBox("WalkWest", Vector3.new(-20, -1, -3), Vector3.new(-3, 0, 3))
		addInvisibleBox("WalkEast", Vector3.new(3, -1, -3), Vector3.new(20, 0, 3))
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "WalkAreaCheckTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		options = PathCheck.defaults(world)
		world.Parent = ServerStorage
	end)

	afterEach(function()
		local made = world :: WorldModel? -- nil if the first beforeEach failed before it made the world
		if made ~= nil then
			made:Destroy()
		end
		pcall(PathCheck.cleanup, options)
	end)

	it("a 60 degree slope is walk area", function()
		addTilted(60)
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(WalkAreaCheck.tooSteep(map, ids(map))).toEqual({})
	end)

	it("a 66 degree slope fails too steep", function()
		options.slopeAngle = 70
		addTilted(66)
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(countKind(WalkAreaCheck.tooSteep(map, ids(map)), "too steep") > 0).toBe(true)
	end)

	it("an invisible plank 0.5 above a visible floor stands", function()
		addVisibleFloor(0)
		addInvisibleBox("Plank", Vector3.new(-6, -0.5, -6), Vector3.new(6, 0.5, 6))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(WalkAreaCheck.floatingOrSunk(map, ids(map), visibleHeightAt, notOnSkin)).toEqual({})
	end)

	it("an invisible plank 1.0 above a visible floor floats", function()
		addVisibleFloor(0)
		addInvisibleBox("Plank", Vector3.new(-6, 0, -6), Vector3.new(6, 1, 6))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(countKind(WalkAreaCheck.floatingOrSunk(map, ids(map), visibleHeightAt, notOnSkin), "floating") > 0).toBe(
			true
		)
	end)

	it("a visible floor 0.4 above an invisible plank sinks the feet", function()
		addVisibleFloor(0.4)
		addInvisibleBox("Plank", Vector3.new(-6, -1, -6), Vector3.new(6, 0, 6))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(countKind(WalkAreaCheck.floatingOrSunk(map, ids(map), visibleHeightAt, notOnSkin), "sunk") > 0).toBe(
			true
		)
	end)

	it("a hole in the walk floor is a gap named by its point", function()
		addVisibleFloor(0)
		addWalkFloor(true)
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local problems = WalkAreaCheck.gaps(map, ids(map), floorSamples())
		local named = false
		for _, problem in problems do
			if problem.kind == "gap" and (problem.position - Vector3.new(0, 0, 0)).Magnitude < 0.5 then
				named = true
			end
		end
		expect(named).toBe(true)
	end)

	it("a whole walk floor has no gap", function()
		addVisibleFloor(0)
		addWalkFloor(false)
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(WalkAreaCheck.gaps(map, ids(map), floorSamples())).toEqual({})
	end)

	it("a spot outside the Belly fails the zone", function()
		addInvisibleBox("WalkFloor", Vector3.new(-20, -1, -20), Vector3.new(20, 0, 20))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local expected = 0
		for _, spot in map.spots do
			if spot.position.X > 10 then
				expected += 1
			end
		end
		local problems = WalkAreaCheck.zones(map, ids(map), function(position: Vector3): string
			return if position.X > 10 then "Meadow" else "Belly"
		end)
		local allOutside = true
		for _, problem in problems do
			if problem.kind ~= "zone" or problem.position.X <= 10 then
				allOutside = false
			end
		end
		expect(expected > 0).toBe(true)
		expect(#problems).toBe(expected)
		expect(allOutside).toBe(true)
	end)

	it("the walk area keeps walk links only", function()
		addBox("Floor", Vector3.new(-20, -1, -20), Vector3.new(20, 0, 20))
		addBox("Shelf", Vector3.new(-3, 7, -9), Vector3.new(9, 8, 9))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local start = PathCheck.nearestSpot(map, Vector3.new(0, 8, 0), 1)
		assert(start ~= nil, "no spot on the shelf")
		local inArea: { [number]: boolean } = {}
		for _, id in
			WalkAreaCheck.walkArea(map, { start }, function(_position: Vector3): boolean
				return true
			end, function(_spot: PathCheck.Spot): boolean
				return false
			end)
		do
			inArea[id] = true
		end
		local upperMissing, lowerIn = 0, 0
		for _, spot in map.spots do
			if spot.position.Y > 4 and not inArea[spot.id] then
				upperMissing += 1
			elseif spot.position.Y <= 4 and inArea[spot.id] then
				lowerIn += 1
			end
		end
		expect(inArea[start]).toBe(true)
		expect(upperMissing).toBe(0)
		expect(lowerIn).toBe(0)
	end)

	it("a stitch at the slip edge matches", function()
		addBox("Floor", Vector3.new(-20, -1, -20), Vector3.new(0, 0, 20)) -- ends at x = 0, where the slab starts
		addSlab("Face", 0, 0, 80, 30)
		local stitch = Vector3.new(0.2, -0.2 * math.tan(math.rad(80)), 0)
		expect(WalkAreaCheck.seamMatch(world, { stitch }, nil)).toEqual({})
	end)

	it("a stitch 2 studs inside the walk edge fails the seam match", function()
		addBox("Floor", Vector3.new(-20, -1, -20), Vector3.new(0, 0, 20)) -- ends at x = 0, where the slab starts
		local edge = addSlab("Walkable", 0, 0, 60, 4)
		addSlab("Face", edge.X, edge.Y, 80, 30)
		local stitch = Vector3.new(0.2, -0.2 * math.tan(math.rad(60)), 0)
		expect(countKind(WalkAreaCheck.seamMatch(world, { stitch }, nil), "seam match") > 0).toBe(true)
	end)

	it("no seam built is one seam match problem", function()
		local problems = WalkAreaCheck.seamMatch(world, nil, nil)
		expect(#problems).toBe(1)
		expect(countKind(problems, "seam match")).toBe(1)
	end)

	-- Task 15g B1 (15c row 8): art that rays skip (CanQuery off) is measured by its shape (CFrame and Size).
	it("art under a walk piece is measured by its shape even when rays skip it", function()
		local artTopUnder = WalkAreaFacts.artTopUnder
		local art = addBox("Art", Vector3.new(-6, -1, -6), Vector3.new(6, 0, 6))
		art.CanCollide = false
		art.CanQuery = false
		addInvisibleBox("Piece", Vector3.new(-6, -0.7, -6), Vector3.new(6, 0.3, 6)) -- its top is 0.3 above the art
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		expect(artTopUnder({ art }, 0, 0, 1)).toBeCloseTo(0, 2)
		expect(artTopUnder({ art }, 12, 0, 1)).toBeNil()
		local function seen(x: number, z: number, maxY: number): number?
			return artTopUnder({ art }, x, z, maxY)
		end
		expect(floatSkipping(map, ids(map), seen, notOnSkin)).toEqual({})
	end)

	-- A gap needs no walk-area spot near it, so an empty area makes every sample a gap unless the filter cuts it.
	local function gapCount(samples: { Vector3 }, cut: Skip?): number
		addInvisibleBox("WalkFloor", Vector3.new(-20, -1, -20), Vector3.new(20, 0, 20))
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		return #gapsSkipping(map, {}, samples, cut)
	end

	-- The seam's own numbers (SlideProfile.SEAM_LEFT / SEAM_RIGHT, style guide "Along his side"); one stud of x is
	-- `sign` outboard. Only stitches south of z -20, where the body rule ends.
	local function seamSamples(outboard: boolean): { Vector3 }
		local samples = {}
		for _, side in
			{ { points = SlideProfile.SEAM_LEFT, sign = -1 }, { points = SlideProfile.SEAM_RIGHT, sign = 1 } }
		do
			for _, point in side.points do
				if point.Z < -20 then
					local shift = if outboard then 3 else -3
					table.insert(
						samples,
						Vector3.new(point.X + side.sign * shift, point.Y - (if outboard then 3 else 0), point.Z)
					)
				end
			end
		end
		return samples
	end

	-- Task 15g B2 (Q1): a gap below the seam is not counted.
	it("a gap below the seam is not counted", function()
		local isCutGap = WalkAreaFacts.isCutGap
		local samples = seamSamples(true)
		expect(#samples > 0).toBe(true)
		expect(gapCount(samples, isCutGap)).toBe(0)
	end)

	it("a gap above the seam is counted", function()
		local isCutGap = WalkAreaFacts.isCutGap
		local samples = seamSamples(false)
		expect(#samples > 0).toBe(true)
		expect(gapCount(samples, isCutGap)).toBe(#samples)
	end)

	-- Task 15g B3 (Q1): his chest north of z -20, between x -22 and 22, is not walk area; south of z -20 it still is.
	it("a gap on his chest north of z -20 is not counted", function()
		local isCutGap = WalkAreaFacts.isCutGap
		local chest = { Vector3.new(0, 50, -10), Vector3.new(10, 60, -5), Vector3.new(-10, 60, -12) }
		expect(gapCount(chest, isCutGap)).toBe(0)
	end)

	it("a gap on his body south of z -20 is counted", function()
		local isCutGap = WalkAreaFacts.isCutGap
		expect(gapCount({ Vector3.new(0, 50, -25) }, isCutGap)).toBe(1)
	end)

	-- Task 15g B4 (row 4): ramp spots. A BellyRamp_* folder holds Piece<n> walk pieces, Fill<n> blocks and a Cover
	-- folder of boards that are drawn but have no collision, so the check never sees them as the surface.
	local function addRamp(): Folder
		local ramp = Instance.new("Folder")
		ramp.Name = "BellyRamp_Left"
		ramp.Parent = world
		return ramp
	end

	local function addRampPiece(ramp: Folder, name: string, top: number): Part
		local piece = addInvisibleBox(name, Vector3.new(-6, top - 1, -6), Vector3.new(6, top, 6))
		piece.Parent = ramp
		return piece
	end

	-- The visible skin 1 stud under the piece: a spot on the piece is 1 stud above what is drawn.
	local function rampFloats(skip: (PathCheck.Spot) -> boolean): { WalkAreaCheck.Problem }
		addVisibleFloor(-1)
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		expect(#map.spots > 0).toBe(true)
		return floatSkipping(map, ids(map), visibleHeightAt, notOnSkin, skip)
	end

	local function rampSkip(covers: { BasePart }): (PathCheck.Spot) -> boolean
		local skipRampSpot = WalkAreaFacts.skipRampSpot
		return function(spot: PathCheck.Spot): boolean
			return skipRampSpot(spot, covers)
		end
	end

	it("a ramp spot over its Cover board is not a float", function()
		local skip = rampSkip({})
		local ramp = addRamp()
		addRampPiece(ramp, "Piece1", 0)
		local cover = Instance.new("Folder")
		cover.Name = "Cover"
		cover.Parent = ramp
		local board = addBox("Board1", Vector3.new(-6, -1.1, -6), Vector3.new(6, -0.1, 6)) -- top 0.1 under the feet
		board.CanCollide = false
		board.CanQuery = false
		board.Parent = cover
		expect(rampFloats(rampSkip({ board }))).toEqual({})
		expect(skip).never.toBeNil()
	end)

	it("a ramp spot over bare skin is a float", function()
		local skip = rampSkip({})
		local ramp = addRamp()
		addRampPiece(ramp, "Piece1", 0)
		expect(countKind(rampFloats(skip), "floating") > 0).toBe(true)
	end)

	it("a ramp curb spot is skipped", function()
		local skip = rampSkip({})
		local ramp = addRamp()
		addRampPiece(ramp, "Curb1", 0)
		expect(rampFloats(skip)).toEqual({})
	end)

	it("a ramp top piece with no board over it that stands on its Fill piece is not a float", function()
		local skip = rampSkip({})
		local ramp = addRamp()
		addRampPiece(ramp, "Piece13", 0)
		local fill = addInvisibleBox("Fill13", Vector3.new(-6, -3, -6), Vector3.new(6, -0.2, 6))
		fill.Parent = ramp
		expect(rampFloats(skip)).toEqual({})
	end)

	-- Task 15g close (review findings 1-2): a pair spot is skipped only when no Cover board lies under it at any height.
	-- A drawn board 0.9 under the feet is the wrong height (the pass band is 0.7), so the spot floats.
	local function addWrongHeightBoard(ramp: Folder): Part
		local cover = Instance.new("Folder")
		cover.Name = "Cover"
		cover.Parent = ramp
		local board = addBox("Board1", Vector3.new(-6, -1.9, -6), Vector3.new(6, -0.9, 6)) -- top 0.9 under the feet
		board.CanCollide = false
		board.CanQuery = false
		board.Parent = cover
		return board
	end

	it("a ramp piece on its Fill with a Cover board 0.9 under the feet is a float", function()
		local ramp = addRamp()
		addRampPiece(ramp, "Piece13", 0)
		addInvisibleBox("Fill13", Vector3.new(-6, -3, -6), Vector3.new(6, -0.2, 6)).Parent = ramp
		local board = addWrongHeightBoard(ramp)
		expect(countKind(rampFloats(rampSkip({ board })), "floating") > 0).toBe(true)
	end)

	it("a Fill spot with a Cover board 0.9 under the feet is a float", function()
		local ramp = addRamp()
		addInvisibleBox("Fill13", Vector3.new(-6, -3, -6), Vector3.new(6, 0, 6)).Parent = ramp
		addInvisibleBox("Piece13", Vector3.new(8, -1, -6), Vector3.new(14, 0, 6)).Parent = ramp
		local board = addWrongHeightBoard(ramp)
		expect(countKind(rampFloats(rampSkip({ board })), "floating") > 0).toBe(true)
	end)

	-- Task 15g close (product, 17:13): gaps and too steep are checked on made-up worlds and by Task 15e's walks.
	it("the real-world message leaves out gap and too steep", function()
		local found: { WalkAreaCheck.Problem } = {
			{ kind = "gap", position = Vector3.new(1, 2, 3), detail = "gap" },
			{ kind = "too steep", position = Vector3.new(4, 5, 6), detail = "steep" },
		}
		expect(WalkAreaFacts.message(found, 5)).toBe(WalkAreaFacts.message({}, 5))
	end)

	it("a map spot at the mirror of the start egg spot is a start", function()
		local eggSpots = Instance.new("Folder")
		eggSpots.Name = "EggSpots"
		eggSpots.Parent = world
		local eggSpot = Instance.new("Model")
		eggSpot.Name = Config.Nests.RareEggOne -- the start egg spot (WalkAreaFacts START_EGG_SPOT)
		eggSpot.Parent = eggSpots
		local marker = Instance.new("Part")
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Position = Vector3.new(-12, 0, -6)
		marker.Parent = eggSpot
		addWalkFloor(false)
		local map = PathCheck.buildMap(options, FLOOR_AREA)
		local mirror = Vector3.new(12, 0, -6) -- WalkAreaFacts.startIds: the start egg spot with x flipped
		local nearest: PathCheck.Spot? = nil
		for _, spot in map.spots do
			if nearest == nil or (spot.position - mirror).Magnitude < (nearest.position - mirror).Magnitude then
				nearest = spot
			end
		end
		expect(nearest).never.toBeNil()
		local startIds = (WalkAreaFacts :: any).startIds
		expect(startIds).never.toBeNil()
		expect(table.find(startIds(world, map), (nearest :: PathCheck.Spot).id)).never.toBeNil()
	end)
end)
