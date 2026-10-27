--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local PlayerNeeds = require(game:GetService("ServerStorage").Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
local SlideGuardHelpers = require(script.Parent.SlideGuardHelpers)
local bodySizeSlopeAt = Helpers.bodySizeSlopeAt
local bodySizeSlopeAtCloth = Helpers.bodySizeSlopeAtCloth
local bodySizeSlopeFacing = Helpers.bodySizeSlopeFacing
local inFakeWorld = Helpers.inFakeWorld
local startsWith = Helpers.startsWith
type Box = SlideGuardHelpers.Box
type Context = SlideGuardHelpers.Context
type Need = SlideGuardHelpers.Need
local CHAIR_CLOTH = SlideGuardHelpers.CHAIR_CLOTH
local GUARD_FOLDER = SlideGuardHelpers.GUARD_FOLDER
local fakeFolder = SlideGuardHelpers.fakeFolder
local guardCloseProblems = SlideGuardHelpers.guardCloseProblems
local guardProblems = SlideGuardHelpers.guardProblems
local addBoard = SlideGuardHelpers.addBoard
local addWall = SlideGuardHelpers.addWall

-- Stuck safety Task 23, test 4 (docs/plans/v2/stuck-safety.md, Task 23 test 3 and product's condition 1): the slide
-- guards in World.WalkSurfaces.SlideGuards are steep enough to slide off, stand only on steep cloth (or the chair), and
-- stay clear of the places players need. The checker takes everything it reads as input, so the fake-world tests below
-- can prove that each rule bites.
describe("the real world, slide guards", function()
	local Workspace = game:GetService("Workspace")

	-- A thin sheet of made-up cloth 0.4 studs behind the board's back face, as big as the board and then some, so a ray in
	-- from the board's top face finds it within reach wherever the board stands.
	local function addClothBehind(world: WorldModel, board: Part): Part
		local sheet = Instance.new("Part")
		sheet.Name = "ClothBehind"
		sheet.Size = Vector3.new(board.Size.X + 2, board.Size.Y + 2, 0.2)
		sheet.CFrame = board.CFrame * CFrame.new(0, 0, -(board.Size.Z / 2 + 0.5))
		sheet.Anchored = true
		sheet.Parent = world
		return sheet
	end

	-- A filter that lets a ray hit only `cloth`.
	local function clothOnlyParams(cloth: { Instance }): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = cloth
		params.RespectCanCollide = false
		return params
	end

	local function fakeContext(world: WorldModel, wall: Part, slope: number, needs: { Need }): Context
		return {
			world = world,
			clothParams = clothOnlyParams({ wall }),
			slopeAt = function(_point: Vector3, _normal: Vector3): number?
				return slope
			end,
			clothNameAt = function(_x: number, _z: number): string?
				return CHAIR_CLOTH
			end,
			chairBoxes = {},
			beardPocketBoxes = {},
			solids = { wall },
			needs = needs,
		}
	end

	local BURIED_TOP = Vector3.new(0, 20, -0.3) -- a board's top end sunk 0.3 studs into the wall
	local OPEN_TOP = Vector3.new(0, 20, 5) -- a board's top end in open air
	local GUARD_LENGTH = 6 -- studs
	local STEEP_ENOUGH = 76 -- degrees: the guards' aim (Task 23, decision 4)
	local STEEP_CLOTH = 80 -- degrees: a fake cloth steeper than the 65 limit

	it("the slide guard check passes a steep board with its top sunk in the wall on steep cloth", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			-- A route point 5 studs off the board's face is far enough.
			local far = PlayerNeeds.pointNeed(
				"RoutePoint_Fake",
				board.Position + board.CFrame:VectorToWorldSpace(Vector3.zAxis) * 5
			)
			expect(guardProblems(folder, fakeContext(world, wall, STEEP_CLOTH, { far }))).toEqual({})
		end)
	end)

	it("the slide guard check names a board under 72 degrees steep", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, 60, GUARD_LENGTH)
			local context = fakeContext(world, wall, STEEP_CLOTH, {})
			context.clothParams = clothOnlyParams({ addClothBehind(world, board) })
			local problems = guardProblems(folder, context)
			expect(#startsWith(problems, "Steepness:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the slide guard check names a board with a flat top in the open", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, OPEN_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local context = fakeContext(world, wall, STEEP_CLOTH, {})
			context.clothParams = clothOnlyParams({ addClothBehind(world, board) })
			local problems = guardProblems(folder, context)
			expect(#startsWith(problems, "Steepness:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the slide guard check names a steep board on cloth under 65 degrees", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local problems = guardProblems(folder, fakeContext(world, wall, 40, {}))
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the slide guard check lets a board stand on gentle cloth that is the chair", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local context = fakeContext(world, wall, 40, {})
			context.chairBoxes = { { name = "chair", min = Vector3.new(-10, 0, -5), max = Vector3.new(10, 30, 5) } }
			expect(guardProblems(folder, context)).toEqual({})
		end)
	end)

	it("the slide guard check names a board on gentle legs_and_boots cloth inside a chair box", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local context = fakeContext(world, wall, 40, {})
			context.chairBoxes = { { name = "chair", min = Vector3.new(-10, 0, -5), max = Vector3.new(10, 30, 5) } }
			context.clothNameAt = function(_x: number, _z: number): string?
				return "legs_and_boots"
			end
			local problems = guardProblems(folder, context)
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it(
		"the slide guard check skips a face point buried in a solid, where a ray in would find gentle cloth deeper in",
		function()
			inFakeWorld(function(world)
				local wall = addWall(world)
				local folder = fakeFolder(world)
				addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
				-- A thin sheet of gentle cloth 1 stud inside the wall. The board's top corners are inside the wall too, and a
				-- ray in from there would find the sheet; they are buried, so they are skipped. The rest of the wall is steep.
				local sheet = Instance.new("Part")
				sheet.Name = "Sheet"
				sheet.Size = Vector3.new(60, 60, 0.2)
				sheet.Position = Vector3.new(0, 0, -1)
				sheet.Anchored = true
				sheet.Parent = world
				local context = fakeContext(world, wall, STEEP_CLOTH, {})
				context.clothParams = clothOnlyParams({ wall, sheet })
				context.slopeAt = function(point: Vector3, _normal: Vector3): number?
					return if point.Z < -0.5 then 40 else STEEP_CLOTH
				end
				expect(guardProblems(folder, context)).toEqual({})
			end)
		end
	)

	it("the slide guard check names a board that hangs past the end of the cloth, over open air", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local context = fakeContext(world, wall, STEEP_CLOTH, {})
			-- The cloth is only the part of the wall over y 17; the board's lower end (from y 14) hangs past its edge, with
			-- nothing within 2 studs behind it. The wall still counts as solid, so the board's top end is buried.
			local cloth = Instance.new("Part")
			cloth.Name = "Cloth"
			cloth.Size = Vector3.new(60, 20, 60)
			cloth.Position = Vector3.new(0, 27, -30)
			cloth.Anchored = true
			cloth.Parent = world
			context.clothParams = clothOnlyParams({ cloth })
			local problems = guardProblems(folder, context)
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	-- Ruling 13's exception, shown on a made-up wall of 50 degree cloth (the beard pocket's cloth is 50 to 57 degrees).
	local BEARD_POCKET_GUARD_NAME = "SlideGuard_BeardPocket_1"
	local POCKET_CLOTH_DEGREES = 50
	local BOX_AROUND_BOARD: Box = { name = "pocket", min = Vector3.new(-10, 10, -5), max = Vector3.new(10, 30, 5) }
	local BOX_FAR_FROM_BOARD: Box = { name = "far", min = Vector3.new(100, 10, -5), max = Vector3.new(120, 30, 5) }

	it("the slide guard check lets a beard pocket guard stand on 50 degree cloth inside a pocket box", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH).Name = BEARD_POCKET_GUARD_NAME
			local context = fakeContext(world, wall, POCKET_CLOTH_DEGREES, {})
			context.beardPocketBoxes = { BOX_FAR_FROM_BOARD, BOX_AROUND_BOARD }
			expect(guardProblems(folder, context)).toEqual({})
		end)
	end)

	it("the slide guard check names a beard pocket guard on 50 degree cloth outside the pocket boxes", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH).Name = BEARD_POCKET_GUARD_NAME
			local context = fakeContext(world, wall, POCKET_CLOTH_DEGREES, {})
			context.beardPocketBoxes = { BOX_FAR_FROM_BOARD }
			local problems = guardProblems(folder, context)
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the slide guard check names a guard with another name on 50 degree cloth inside a pocket box", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local context = fakeContext(world, wall, POCKET_CLOTH_DEGREES, {})
			context.beardPocketBoxes = { BOX_AROUND_BOARD }
			local problems = guardProblems(folder, context)
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the slide guard check names a beard pocket guard that shares only its name prefix", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH).Name = "SlideGuard_BeardPocketX_1"
			local context = fakeContext(world, wall, POCKET_CLOTH_DEGREES, {})
			context.beardPocketBoxes = { BOX_AROUND_BOARD }
			expect(#startsWith(guardProblems(folder, context), "Cloth:")).toBe(1)
		end)
	end)

	-- Ruling 16 (docs/specs/v2/research/decisions-plans.md, "Task 23: step 23-C1's questions, and the task split"): the
	-- exception needs the whole guard inside one box (all 8 corners of its bounding box), not only its middle.
	-- The board's middle (x 0) is inside both of these boxes' x range, but its corners (x -2 and 2) are not.
	local BOX_NARROWER_THAN_BOARD: Box = { name = "narrow", min = Vector3.new(-1, 10, -5), max = Vector3.new(1, 30, 5) }
	-- Each half of the board (x under 0, x over 0) lies inside one of these, so no single box holds all of it.
	local BOX_LEFT_HALF: Box = { name = "left half", min = Vector3.new(-10, 10, -5), max = Vector3.new(0, 30, 5) }
	local BOX_RIGHT_HALF: Box = { name = "right half", min = Vector3.new(0, 10, -5), max = Vector3.new(10, 30, 5) }

	it(
		"the slide guard check names a beard pocket guard whose middle is in a pocket box but a corner is outside",
		function()
			inFakeWorld(function(world)
				local wall = addWall(world)
				local folder = fakeFolder(world)
				addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH).Name = BEARD_POCKET_GUARD_NAME
				local context = fakeContext(world, wall, POCKET_CLOTH_DEGREES, {})
				context.beardPocketBoxes = { BOX_NARROWER_THAN_BOARD }
				local problems = guardProblems(folder, context)
				expect(#startsWith(problems, "Cloth:")).toBe(1)
				expect(#problems).toBe(1)
			end)
		end
	)

	it("the slide guard check names a beard pocket guard whose corners are in two different pocket boxes", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH).Name = BEARD_POCKET_GUARD_NAME
			local context = fakeContext(world, wall, POCKET_CLOTH_DEGREES, {})
			context.beardPocketBoxes = { BOX_LEFT_HALF, BOX_RIGHT_HALF }
			expect(#startsWith(guardProblems(folder, context), "Cloth:")).toBe(1)
		end)
	end)

	-- A made-up place for the roof search: a floor of `floorDegrees`, a flat roof 9 studs over it, and a high cap at 10
	-- degrees above both. The slope code looks in the Workspace, so the parts go in a far corner of it and are removed at
	-- once. `run` gets the rays' filter, the cloth point (where a ray down from over the floor's middle hits the floor)
	-- and the floor's outward direction there.
	local ROOF_TEST_X = 5000
	local ROOF_TEST_FLOOR_DEGREES = 56
	local ROOF_TEST_STEEP_DEGREES = 74
	local ROOF_TEST_CAP_DEGREES = 10
	local ROOF_TEST_ROOF_HEIGHT = 9 -- studs over the floor's middle
	local ROOF_TEST_CAP_HEIGHT = 40 -- studs over the floor's middle
	local ROOF_TEST_DROP_FROM = 24 -- studs: the ray down to the cloth point starts at this height
	-- `options` (all optional): roofHeight (studs over the floor's middle, instead of ROOF_TEST_ROOF_HEIGHT) and withCap
	-- (false leaves the high cap out, so a ray from above lands on the floor or the roof).
	type RoofWorldOptions = { roofHeight: number?, withCap: boolean? }
	local function inRoofWorld(
		withRoof: boolean,
		floorDegrees: number,
		run: (params: RaycastParams, point: Vector3, normal: Vector3) -> (),
		options: RoofWorldOptions?
	)
		local roofHeight = if options ~= nil and options.roofHeight ~= nil
			then options.roofHeight
			else ROOF_TEST_ROOF_HEIGHT
		local withCap = options == nil or options.withCap ~= false
		local trial = Instance.new("Folder")
		trial.Name = "RoofSearchTrial"
		trial.Archivable = false
		local function add(name: string, height: number, degrees: number, thickness: number)
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.new(40, thickness, 40)
			part.CFrame = CFrame.new(ROOF_TEST_X, 20 + height, 0) * CFrame.Angles(math.rad(degrees), 0, 0)
			part.Anchored = true
			part.Parent = trial
		end
		add("Floor", 0, floorDegrees, 1)
		if withCap then
			add("Cap", ROOF_TEST_CAP_HEIGHT, ROOF_TEST_CAP_DEGREES, 2)
		end
		if withRoof then
			add("Roof", roofHeight, 0, 1)
		end
		trial.Parent = Workspace
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { trial }
		params.RespectCanCollide = false
		local ok, message = pcall(function(): string?
			local hit = Workspace:Raycast(
				Vector3.new(ROOF_TEST_X, ROOF_TEST_DROP_FROM, 0),
				Vector3.new(0, -ROOF_TEST_DROP_FROM, 0),
				params
			)
			expect(hit).never.toBeNil()
			run(params, (hit :: RaycastResult).Position, (hit :: RaycastResult).Normal)
			return nil
		end)
		trial:Destroy()
		if not ok then
			error(message, 0)
		end
	end

	it("the roof search reads the floor's slope under a roof, where the read from above reads the cap", function()
		inRoofWorld(true, ROOF_TEST_FLOOR_DEGREES, function(params, point, normal)
			local underRoof = bodySizeSlopeAtCloth(params, point, normal)
			local fromAbove = bodySizeSlopeAt(params, point.X, point.Z)
			expect(underRoof).toBeCloseTo(ROOF_TEST_FLOOR_DEGREES, 0)
			expect(fromAbove).toBeCloseTo(ROOF_TEST_CAP_DEGREES, 0)
		end)
	end)

	-- Code_lead's ruling after step 23-8b.1 (Ruling 10): where the read from above lands on the cloth (its middle ray hits
	-- within CLOTH_MATCH studs of the cloth point), it stays exactly the read from above, as the seam test reads it.
	it(
		"the roof search reads exactly as before where there is no roof and the read from above lands on the cloth",
		function()
			inRoofWorld(false, ROOF_TEST_FLOOR_DEGREES, function(params, point, normal)
				local underRoof = bodySizeSlopeAtCloth(params, point, normal)
				local fromAbove = bodySizeSlopeAt(params, point.X, point.Z)
				expect(fromAbove).toBeCloseTo(ROOF_TEST_FLOOR_DEGREES, 0)
				expect(underRoof).toBe(fromAbove)
			end, { withCap = false })
		end
	)

	-- Ruling 10: a roof too high for the roof search (25 studs over the face) makes the read from above hit the roof,
	-- not the cloth. The middle ray lands far from the cloth point, so the facing read is used.
	local HIGH_ROOF_HEIGHT = 25 -- studs over the face: well past ROOF_SEARCH
	local HIGH_ROOF_FACE_DEGREES = 70
	it("a 70 degree face with a flat roof 25 studs above it reads 70 degrees", function()
		inRoofWorld(true, HIGH_ROOF_FACE_DEGREES, function(params, point, normal)
			expect(bodySizeSlopeAtCloth(params, point, normal)).toBeCloseTo(HIGH_ROOF_FACE_DEGREES, 0)
		end, { roofHeight = HIGH_ROOF_HEIGHT })
	end)

	local OPEN_FACE_DEGREES = 50
	it("a 50 degree open face reads 50 degrees from above, and the cloth read agrees", function()
		inRoofWorld(false, OPEN_FACE_DEGREES, function(params, point, normal)
			local fromAbove = bodySizeSlopeAt(params, point.X, point.Z)
			expect(fromAbove).toBeCloseTo(OPEN_FACE_DEGREES, 0)
			expect(bodySizeSlopeAtCloth(params, point, normal)).toBeCloseTo(OPEN_FACE_DEGREES, 0)
		end, { withCap = false })
	end)

	-- A 76 degree board whose upper part stands in front of a 50 degree open face (within the checker's 2 studs reach).
	-- The face is the cloth: the checker must still count the board's points there as gentle cloth. The board crosses
	-- the face 2.6 studs below its top end, where this short board ends. Every one of its 5 points is within 1.6 studs
	-- of the face, so each is a read of this face, and the first example names that read.
	local OPEN_BOARD_TOP = Vector3.new(ROOF_TEST_X, 22, 0.5) -- the board's top end centre
	local OPEN_BOARD_LENGTH = 2.6 -- studs
	it("a slide guard in front of a 50 degree open face still fails the Cloth check", function()
		inRoofWorld(false, OPEN_FACE_DEGREES, function(params, _point, _normal)
			local trial = params.FilterDescendantsInstances[1] :: Instance
			local folder = Instance.new("Folder")
			folder.Name = GUARD_FOLDER
			folder.Archivable = false
			folder.Parent = Workspace
			local ok, message = pcall(function(): string?
				addBoard(folder, OPEN_BOARD_TOP, STEEP_ENOUGH, OPEN_BOARD_LENGTH)
				local floor = trial:FindFirstChild("Floor") :: Part
				local context = fakeContext(Workspace :: any, floor, STEEP_CLOTH, {})
				context.world = Workspace
				context.clothParams = params
				context.slopeAt = function(point: Vector3, normal: Vector3): number?
					return bodySizeSlopeAtCloth(params, point, normal)
				end
				local cloth = startsWith(guardProblems(folder, context), "Cloth:")
				expect(#cloth).toBe(1)
				expect(cloth[1]).toContain("50 degrees at")
				return nil
			end)
			folder:Destroy()
			if not ok then
				error(message, 0)
			end
		end, { withCap = false })
	end)

	it("the facing read reads a 74 degree face under a flat overhang as 74 degrees", function()
		inRoofWorld(true, ROOF_TEST_STEEP_DEGREES, function(params, point, normal)
			expect(bodySizeSlopeFacing(params, point, normal)).toBeCloseTo(ROOF_TEST_STEEP_DEGREES, 0)
		end)
	end)

	it("the roof search reads a 74 degree face under a roof as 74 degrees", function()
		inRoofWorld(true, ROOF_TEST_STEEP_DEGREES, function(params, point, normal)
			expect(bodySizeSlopeAtCloth(params, point, normal)).toBeCloseTo(ROOF_TEST_STEEP_DEGREES, 0)
		end)
	end)

	it("the slide guard check names a board 1 stud from a place players need", function()
		inFakeWorld(function(world)
			local wall = addWall(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			-- The board is 0.5 thick, so 1 stud from its face is 1.25 studs from its middle along the face's direction.
			local near = PlayerNeeds.pointNeed(
				"RoutePoint_Fake",
				board.Position + board.CFrame:VectorToWorldSpace(Vector3.zAxis) * 1.25
			)
			local problems = guardProblems(folder, fakeContext(world, wall, STEEP_CLOTH, { near }))
			expect(#startsWith(problems, "Distance:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	-- A made-up drawn skin: a big flat plane parallel to the board's outer face, `gap` studs behind it along the face's
	-- direction. A negative gap puts the plane in front of the face, so the board is sunk into the skin.
	local function skinBehind(board: Part, gap: number): DrawnSkin.Skin
		local normal = board.CFrame:VectorToWorldSpace(Vector3.zAxis)
		local across = board.CFrame:VectorToWorldSpace(Vector3.xAxis)
		local along = board.CFrame:VectorToWorldSpace(Vector3.yAxis)
		local middle = board.CFrame:PointToWorldSpace(Vector3.new(0, 0, board.Size.Z / 2)) - normal * gap
		local function corner(sideways: number, lengthways: number): Vector3
			return middle + across * sideways + along * lengthways
		end
		local a, b, c, d = corner(-20, -10), corner(20, -10), corner(20, 10), corner(-20, 10)
		return DrawnSkin.new({ { a = a, b = b, c = c }, { a = a, b = c, c = d } }, {})
	end

	it("the close-fit check passes a board 0.8 studs out from the skin", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			expect(guardCloseProblems(folder, skinBehind(board, 0.8))).toEqual({})
		end)
	end)

	it("the close-fit check names a board 1.5 studs out from the skin", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local problems = guardCloseProblems(folder, skinBehind(board, 1.5))
			expect(#startsWith(problems, "Out:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the close-fit check names a board sunk 0.7 studs into the skin", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local problems = guardCloseProblems(folder, skinBehind(board, -0.7))
			expect(#startsWith(problems, "In:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the close-fit check names a board with no skin within reach", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local problems = guardCloseProblems(folder, skinBehind(board, 3))
			expect(#startsWith(problems, "Skin:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)
end)
