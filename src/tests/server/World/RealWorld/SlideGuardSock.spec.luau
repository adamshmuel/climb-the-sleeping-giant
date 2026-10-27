--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local Helpers = require(script.Parent.Helpers)
local SlideGuardHelpers = require(script.Parent.SlideGuardHelpers)
local inFakeWorld = Helpers.inFakeWorld
local startsWith = Helpers.startsWith
type Context = SlideGuardHelpers.Context
local addBoard = SlideGuardHelpers.addBoard
local addWall = SlideGuardHelpers.addWall
local fakeFolder = SlideGuardHelpers.fakeFolder
local guardCloseProblems = SlideGuardHelpers.guardCloseProblems
local guardProblems = SlideGuardHelpers.guardProblems

-- Task 37: the Sock's lip boards and skirts (SlideGuard_Sock_<n>). Two named exceptions in the slide guard checks, each
-- approved by product and designer on 2026-10-27 (work/handoff-p2-task35.md):
--   Row 3: a lip board reads the Sock's mesh (body_geom) as its cloth and its drawn skin. Every limit stays.
--   Row 4: a skirt under one of Task 32's plates (Patch_Sock_<n>) is read against that plate, so it has no Cloth or Skin
--   line, only while it sits inside the plate's footprint, with its top within 0.05 studs of the plate's bottom, and its
--   front no further out than the plate's front. A skirt that misses one keeps the strict check.
-- Both match only SlideGuard_Sock_<n> names, and the row 3 exception is off without a Sock in the context.
describe("the real world, slide guards: the Sock's boards", function()
	local BURIED_TOP = Vector3.new(0, 20, -0.3) -- a board's top end sunk 0.3 studs into the wall
	local STEEP_ENOUGH = 76 -- degrees: the guards' aim
	local GUARD_LENGTH = 6 -- studs

	local function clothOnly(cloth: { Instance }): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = cloth
		params.RespectCanCollide = false
		return params
	end

	-- A piece of cloth far from everything: his body, which a Sock board does not touch.
	local function addFarCloth(world: WorldModel): Part
		local far = Instance.new("Part")
		far.Name = "FarCloth"
		far.Size = Vector3.new(10, 10, 10)
		far.Position = Vector3.new(0, 500, 500)
		far.Anchored = true
		far.Parent = world
		return far
	end

	-- A context whose cloth is only `far`. With `sock`, the Sock's mesh reads at `sockSlope` degrees.
	local function contextFor(world: WorldModel, far: Part, sock: Part?, sockSlope: number): Context
		local context: Context = {
			world = world,
			clothParams = clothOnly({ far }),
			slopeAt = function(_point: Vector3, _normal: Vector3): number?
				return 80
			end,
			clothNameAt = function(_x: number, _z: number): string?
				return nil
			end,
			chairBoxes = {},
			beardPocketBoxes = {},
			solids = { far },
			needs = {},
		}
		if sock ~= nil then
			context.sock = {
				clothParams = clothOnly({ sock }),
				slopeAt = function(_point: Vector3, _normal: Vector3): number?
					return sockSlope
				end,
				solids = { sock },
			}
		end
		return context
	end

	-- The Sock's mesh as a wall named body_geom, and a steep board at its face named `name`.
	local function lipWorld(world: WorldModel, name: string): (Folder, Part)
		local geom = addWall(world)
		geom.Name = "body_geom"
		local folder = fakeFolder(world)
		local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
		board.Name = name
		return folder, geom
	end

	it("the slide guard check lets a Sock lip board stand on the Sock's mesh as its cloth", function()
		inFakeWorld(function(world)
			local folder, geom = lipWorld(world, "SlideGuard_Sock_1")
			local far = addFarCloth(world)
			-- Without the Sock in the context there is no cloth within reach: the strict check names it.
			expect(#startsWith(guardProblems(folder, contextFor(world, far, nil, 80)), "Cloth:")).toBe(1)
			expect(guardProblems(folder, contextFor(world, far, geom, 80))).toEqual({})
		end)
	end)

	it("the slide guard check names a Sock lip board on a Sock mesh under 65 degrees", function()
		inFakeWorld(function(world)
			local folder, geom = lipWorld(world, "SlideGuard_Sock_1")
			local problems = guardProblems(folder, contextFor(world, addFarCloth(world), geom, 50))
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the slide guard check keeps the strict cloth check for a board with another name", function()
		inFakeWorld(function(world)
			local folder, geom = lipWorld(world, "SlideGuard_Fake_1")
			local problems = guardProblems(folder, contextFor(world, addFarCloth(world), geom, 80))
			expect(#startsWith(problems, "Cloth:")).toBe(1)
		end)
	end)

	-- A made-up drawn skin: a big flat plane parallel to the board's outer face, `gap` studs behind it.
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

	it("the close-fit check lets a Sock lip board lie 0.8 studs out from the Sock's drawn skin", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			board.Name = "SlideGuard_Sock_1"
			local farSkin = skinBehind(board, 3)
			local sockSkin = skinBehind(board, 0.8)
			-- His skin is out of reach, so without the Sock's skin the strict check names it.
			expect(#startsWith(guardCloseProblems(folder, farSkin), "Skin:")).toBe(1)
			expect(guardCloseProblems(folder, farSkin, sockSkin)).toEqual({})
		end)
	end)

	it("the close-fit check names a Sock lip board 1.5 studs out from the Sock's drawn skin", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			board.Name = "SlideGuard_Sock_1"
			local problems = guardCloseProblems(folder, skinBehind(board, 3), skinBehind(board, 1.5))
			expect(#startsWith(problems, "Out:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the close-fit check keeps the strict skin check for a board with another name", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local board = addBoard(folder, BURIED_TOP, STEEP_ENOUGH, GUARD_LENGTH)
			local problems = guardCloseProblems(folder, skinBehind(board, 3), skinBehind(board, 0.8))
			expect(#startsWith(problems, "Skin:")).toBe(1)
		end)
	end)

	-- Row 4. A plate like Task 32's Patch_Sock_17 (2.5 wide, 6.786 tall, 0.25 thick) with its bottom at height 3.607, and a
	-- skirt wedge 1.25 wide, 1.712 tall and 0.25 thick turned like the real skirts (full height toward -z) under it.
	local PLATE_BOTTOM = 3.607
	local SKIRT_SIZE = Vector3.new(1.25, 1.712, 0.25)

	-- `skirtTop` is the skirt's top height, `skirtX` its middle's x, `thickness` its depth. Returns the guard folder.
	local function skirtWorld(
		world: WorldModel,
		skirtName: string,
		plateName: string,
		skirtTop: number,
		skirtX: number,
		thickness: number
	): Folder
		local plates = Instance.new("Folder")
		plates.Name = Helpers.SMALL_PATCHES_FOLDER
		plates.Parent = world
		local plate = Instance.new("Part")
		plate.Name = plateName
		plate.Size = Vector3.new(2.5, 6.786, 0.25)
		plate.Position = Vector3.new(0, PLATE_BOTTOM + 6.786 / 2, 0)
		plate.Anchored = true
		plate.Parent = plates
		local folder = fakeFolder(world)
		local skirt = Instance.new("WedgePart")
		skirt.Name = skirtName
		skirt.Size = Vector3.new(SKIRT_SIZE.X, SKIRT_SIZE.Y, thickness)
		skirt.CFrame = CFrame.new(skirtX, skirtTop - SKIRT_SIZE.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)
		skirt.Anchored = true
		skirt.CanCollide = true
		skirt.Parent = folder
		return folder
	end

	-- The Cloth and Skin lines the strict checks give a skirt, with his body and skin far away.
	local function clothAndSkinLines(world: WorldModel, folder: Folder): (number, number)
		local cloth = #startsWith(guardProblems(folder, contextFor(world, addFarCloth(world), nil, 80)), "Cloth:")
		local flatFar = DrawnSkin.new({
			{ a = Vector3.new(-20, 100, -20), b = Vector3.new(20, 100, -20), c = Vector3.new(20, 100, 20) },
		}, {})
		return cloth, #startsWith(guardCloseProblems(folder, flatFar), "Skin:")
	end

	it("the slide guard checks read a Sock skirt under a plate against that plate", function()
		inFakeWorld(function(world)
			local folder = skirtWorld(world, "SlideGuard_Sock_5", "Patch_Sock_1", PLATE_BOTTOM, 0.6, 0.25)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(0)
			expect(skin).toBe(0)
		end)
	end)

	it("the slide guard checks keep the strict check for a skirt 0.1 studs under the plate's bottom", function()
		inFakeWorld(function(world)
			local folder = skirtWorld(world, "SlideGuard_Sock_5", "Patch_Sock_1", PLATE_BOTTOM - 0.1, 0.6, 0.25)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(1)
			expect(skin).toBe(1)
		end)
	end)

	it("the slide guard checks keep the strict check for a skirt 0.1 studs up inside the plate", function()
		inFakeWorld(function(world)
			local folder = skirtWorld(world, "SlideGuard_Sock_5", "Patch_Sock_1", PLATE_BOTTOM + 0.1, 0.6, 0.25)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(1)
			expect(skin).toBe(1)
		end)
	end)

	it("the slide guard checks keep the strict check for a skirt that reaches past the plate's front", function()
		inFakeWorld(function(world)
			-- 0.6 thick on the same middle: 0.175 further out than the plate's 0.25 on both sides.
			local folder = skirtWorld(world, "SlideGuard_Sock_5", "Patch_Sock_1", PLATE_BOTTOM, 0.6, 0.6)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(1)
			expect(skin).toBe(1)
		end)
	end)

	it("the slide guard checks keep the strict check for a skirt outside the plate's footprint", function()
		inFakeWorld(function(world)
			local folder = skirtWorld(world, "SlideGuard_Sock_5", "Patch_Sock_1", PLATE_BOTTOM, 2, 0.25)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(1)
			expect(skin).toBe(1)
		end)
	end)

	it("the slide guard checks keep the strict check for a skirt under a plate that is not a Sock plate", function()
		inFakeWorld(function(world)
			local folder = skirtWorld(world, "SlideGuard_Sock_5", "Patch_Other_1", PLATE_BOTTOM, 0.6, 0.25)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(1)
			expect(skin).toBe(1)
		end)
	end)

	it("the slide guard checks keep the strict check for a skirt with another name", function()
		inFakeWorld(function(world)
			local folder = skirtWorld(world, "SlideGuard_Fake_5", "Patch_Sock_1", PLATE_BOTTOM, 0.6, 0.25)
			local cloth, skin = clothAndSkinLines(world, folder)
			expect(cloth).toBe(1)
			expect(skin).toBe(1)
		end)
	end)

	-- Ruling 47 (rows 3a to 3f, work/handoff-p2-task37.md): a lip board reads the Sock's cloth and drawn skin along its
	-- own flat face line, not straight down, because the Sock's lip is a thin upright curtain. These tests use a made-up
	-- curtain: Parts for its cloth and 2 triangles for each section of its drawn skin. The lip boards are thin upright
	-- wedges (like the real ones, whose top is an edge) standing on the grass at y 0 with the foot out in front.
	local LIP_HEIGHT = 5.5 -- studs: a tall lip. Its 1-stud grid has 6 rows, at heights 0.46, 1.38, 2.29 ... 5.04
	local LIP_LEAN = 0.06 -- studs the face leans back over the whole height (0.6 degrees from upright)

	-- A thin upright wedge `height` tall named SlideGuard_Sock_1, in a fresh guard folder. Its sloped face looks toward
	-- +z and a little up, and is `lean` studs further back at its top than at its foot. The face's middle is at z = 0.
	local function addLip(world: WorldModel, height: number, lean: number): (Folder, WedgePart)
		local folder = fakeFolder(world)
		local board = Instance.new("WedgePart")
		board.Name = "SlideGuard_Sock_1"
		board.Size = Vector3.new(4, height, lean)
		board.CFrame = CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.pi, 0)
		board.Anchored = true
		board.CanCollide = true
		board.Parent = folder
		return folder, board
	end

	-- The made-up Sock: a curtain 40 studs tall with its front face at z = frontZ, from `hem` up. With `step`, its
	-- upper part (from the height step.from) has its front at step.z instead (a hollow, like the Sock's mouth). Returns
	-- its cloth parts and its drawn skin.
	local function addCurtain(
		world: WorldModel,
		hem: number,
		frontZ: number,
		step: { from: number, z: number }?
	): ({ Instance }, DrawnSkin.Skin)
		local sections = { { hem, hem + 40, frontZ } }
		if step ~= nil then
			sections = { { hem, step.from, frontZ }, { step.from, hem + 40, step.z } }
		end
		local cloth: { Instance } = {}
		local triangles: { DrawnSkin.Triangle } = {}
		for _, section in sections do
			local bottom, top, z = section[1], section[2], section[3]
			local part = Instance.new("Part")
			part.Name = "body_geom"
			part.Size = Vector3.new(40, top - bottom, 0.2)
			part.Position = Vector3.new(0, (top + bottom) / 2, z - 0.1)
			part.Anchored = true
			part.Parent = world
			table.insert(cloth, part)
			local a, b = Vector3.new(-20, bottom, z), Vector3.new(20, bottom, z)
			local c, d = Vector3.new(20, top, z), Vector3.new(-20, top, z)
			table.insert(triangles, { a = a, b = b, c = c })
			table.insert(triangles, { a = a, b = c, c = d })
		end
		return cloth, DrawnSkin.new(triangles, {})
	end

	-- A context whose Sock cloth is `cloth`, with no slope reader of its own: the fan along the face reads the slope.
	local function sockContext(world: WorldModel, cloth: { Instance }): Context
		local context = contextFor(world, addFarCloth(world), nil, 80)
		context.sock = { clothParams = clothOnly(cloth), solids = cloth }
		return context
	end

	-- A big invisible plate like Task 32's, in the patch folder next to the guard folder, with its front face at z = frontZ.
	local function addPlate(world: WorldModel, frontZ: number): Part
		local plates = Instance.new("Folder")
		plates.Name = Helpers.SMALL_PATCHES_FOLDER
		plates.Parent = world
		local plate = Instance.new("Part")
		plate.Name = "Patch_Sock_1"
		plate.Size = Vector3.new(40, 40, 0.25)
		plate.Position = Vector3.new(0, 10, frontZ - 0.125)
		plate.Anchored = true
		plate.Parent = plates
		return plate
	end

	local NO_SKIN = DrawnSkin.new({}, {}) -- his own skin is never near the Sock's boards

	it("the lip board checks let a board 0.3 studs in front of an upright curtain pass", function()
		inFakeWorld(function(world)
			local folder, board = addLip(world, LIP_HEIGHT, LIP_LEAN)
			board.Position += Vector3.new(0, 0, 0.3)
			local cloth, skin = addCurtain(world, -1, 0)
			expect(guardProblems(folder, sockContext(world, cloth))).toEqual({})
			expect(guardCloseProblems(folder, NO_SKIN, skin)).toEqual({})
		end)
	end)

	it("the close-fit check names a lip board 1.2 studs in front of an upright curtain", function()
		inFakeWorld(function(world)
			local folder, board = addLip(world, LIP_HEIGHT, LIP_LEAN)
			board.Position += Vector3.new(0, 0, 1.2)
			local _, skin = addCurtain(world, -1, 0)
			local problems = guardCloseProblems(folder, NO_SKIN, skin)
			expect(#startsWith(problems, "Out:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the close-fit check leaves the points under knee height alone when the point above them passes", function()
		inFakeWorld(function(world)
			local folder, board = addLip(world, LIP_HEIGHT, LIP_LEAN)
			board.Position += Vector3.new(0, 0, 0.3)
			-- The curtain's hem is 1.6 above the grass: the two rows under 1.5 have no skin behind them.
			local _, skin = addCurtain(world, 1.6, 0)
			expect(guardCloseProblems(folder, NO_SKIN, skin)).toEqual({})
		end)
	end)

	it("the close-fit check reads the points under knee height too when the point above them finds no skin", function()
		inFakeWorld(function(world)
			local folder, board = addLip(world, LIP_HEIGHT, LIP_LEAN)
			board.Position += Vector3.new(0, 0, 0.3)
			-- Hem 2.6: the first row over knee height (2.29) has no skin, so the two rows under it are read as well:
			-- 3 rows of 4 points.
			local _, skin = addCurtain(world, 2.6, 0)
			local problems = guardCloseProblems(folder, NO_SKIN, skin)
			expect(#startsWith(problems, "Skin:")).toBe(1)
			expect(problems[1]).toContain("at 12 of 24 points")
		end)
	end)

	-- Where the curtain steps back: its lower part (under 3 studs) is 0.3 behind the board's face, its upper part is
	-- `upperZ` (the face's middle is at z = 0.3).
	local function steppedWorld(world: WorldModel, upperZ: number): (Folder, DrawnSkin.Skin)
		local folder, board = addLip(world, LIP_HEIGHT, LIP_LEAN)
		board.Position += Vector3.new(0, 0, 0.3)
		local _, skin = addCurtain(world, -1, 0, { from = 3, z = upperZ })
		return folder, skin
	end

	it("the close-fit check lets a lip board stand 1.6 studs out when a plate stands 0.2 studs behind it", function()
		inFakeWorld(function(world)
			local folder, skin = steppedWorld(world, -1.3)
			expect(#startsWith(guardCloseProblems(folder, NO_SKIN, skin), "Out:")).toBe(1) -- no plate: named
			addPlate(world, 0.3 - 0.2)
			expect(guardCloseProblems(folder, NO_SKIN, skin)).toEqual({})
		end)
	end)

	it("the close-fit check names a lip board 1.6 studs out when the plate stands 0.3 studs behind it", function()
		inFakeWorld(function(world)
			local folder, skin = steppedWorld(world, -1.3)
			addPlate(world, 0.3 - 0.3)
			local problems = guardCloseProblems(folder, NO_SKIN, skin)
			expect(#startsWith(problems, "Out:")).toBe(1)
			expect(problems[1]).toContain("at 12 of 24 points")
		end)
	end)

	it("the close-fit check names a lip board sunk 0.7 studs into the skin even with a plate behind it", function()
		inFakeWorld(function(world)
			local folder, skin = steppedWorld(world, 1)
			addPlate(world, 0.3 - 0.2)
			local problems = guardCloseProblems(folder, NO_SKIN, skin)
			expect(#startsWith(problems, "In:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the lip board checks read every point of a board that is all under knee height", function()
		inFakeWorld(function(world)
			local folder = addLip(world, 1.2, LIP_LEAN)
			-- Nothing behind it: with no knee band every point and every cloth spot is read and named.
			local cloth = addCurtain(world, 200, -500)
			local context = sockContext(world, cloth)
			expect(#startsWith(guardProblems(folder, context), "Cloth:")).toBe(1)
			local problems = guardCloseProblems(folder, NO_SKIN, NO_SKIN)
			expect(#startsWith(problems, "Skin:")).toBe(1)
			expect(problems[1]).toContain("at 8 of 8 points")
		end)
	end)

	it("the slide guard check reads the Sock's slope along the face and names a gentle one", function()
		inFakeWorld(function(world)
			local folder = addLip(world, 1.2, LIP_LEAN) -- all under knee height, so all 5 cloth spots are read
			-- A slab sloping 55 degrees from flat, its front face passing 0.5 studs behind the board's foot.
			local slab = Instance.new("Part")
			slab.Name = "body_geom"
			slab.Size = Vector3.new(40, 40, 0.2)
			slab.CFrame = CFrame.new(0, 0, -0.5) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, 0, -0.1)
			slab.Anchored = true
			slab.Parent = world
			local problems = guardProblems(folder, sockContext(world, { slab }))
			expect(#startsWith(problems, "Cloth:")).toBe(1)
			expect(problems[1]).toContain("under 65 degrees at 5 of 5 points")
			-- The same board in front of an upright curtain reads steep.
			slab.CFrame = CFrame.new(0, 0.6, -0.6)
			expect(guardProblems(folder, sockContext(world, { slab }))).toEqual({})
		end)
	end)

	-- Row 3c+: a board's foot may not lean out past its knee point by more than LEAN. A wedge whose face is `lean` studs
	-- further back over its 4.5 studs: its first point over knee height is 2.25 up, so the foot is `lean / 2` out from it.
	local function footLeans(world: WorldModel, past: number): Folder
		local folder = addLip(world, 4.5, past * 2)
		return folder
	end

	it("the lean check names a lip board whose foot leans out past the limit", function()
		inFakeWorld(function(world)
			local folder = footLeans(world, SlideGuardHelpers.LEAN + 0.05)
			local problems = SlideGuardHelpers.guardLeanProblems(folder)
			expect(#startsWith(problems, "Lean:")).toBe(1)
			expect(problems[1]).toContain("SlideGuard_Sock_1")
			expect(#problems).toBe(1)
		end)
	end)

	it("the lean check lets a lip board's foot lean out 0.01 studs under the limit", function()
		inFakeWorld(function(world)
			expect(SlideGuardHelpers.guardLeanProblems(footLeans(world, SlideGuardHelpers.LEAN - 0.01))).toEqual({})
		end)
	end)

	it("the plate rule never excuses a lip board with a flat top", function()
		inFakeWorld(function(world)
			local folder = fakeFolder(world)
			local block = Instance.new("Part")
			block.Name = "SlideGuard_Sock_1"
			block.Size = Vector3.new(4, 3, 1)
			block.Position = Vector3.new(0, 1.5, 0.8)
			block.Anchored = true
			block.Parent = folder
			addPlate(world, 1.1) -- 0.2 behind the block's front
			local cloth = addCurtain(world, -1, 0)
			local problems = guardProblems(folder, sockContext(world, cloth))
			expect(#startsWith(problems, "Steepness:")).toBe(1)
		end)
	end)
end)
