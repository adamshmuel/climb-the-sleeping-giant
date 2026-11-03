--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local WALL_MIN_DEGREES = Helpers.WALL_MIN_DEGREES
local firstLines = Helpers.firstLines
local realWorld = Helpers.realWorld
local sideRails = Helpers.sideRails
local wallDegrees = Helpers.wallDegrees

describe("the real world, zones and extras", function()
	-- Stuck safety Task 25, test 10 (plan Ruling 12). Between the cap ladder's invisible truss (|x| 1.0) and the cap part
	-- of the rails (part B, |x| 3.6) a body fits on his forehead. One invisible `LadderSlotBlock` per side, in
	-- ForeheadGuard, closes it. The rule is "no body fits anywhere in the slot", not today's list of spots, so the grid
	-- is 0.1 studs across (x) and 0.25 along (z): it also sees the thin opening on his right, at x 1.9. Task 26 (Ruling
	-- 7): his closer-fitting head leaves a 69 degree band of forehead in front of the blocks (z -2.75 to -2), so the
	-- box starts at z -2.75 and y 92.5, and each block grows forward and down to cover it. The box stays behind the
	-- nose top's walkable part (38 degrees, from about z -3.5).
	local SLOT_X_TENTHS_FROM = 10 -- |x| 1.0, in tenths of a stud
	local SLOT_X_TENTHS_TO = 36 -- |x| 3.6
	local SLOT_Z_QUARTERS_FROM = -11 -- z -2.75: the whole thin band of his forehead in front of the blocks
	local SLOT_Z_QUARTERS_TO = 12 -- z 3
	local SLOT_LOW_Y = 92.5 -- surfaces from this height (the band starts low, at y 94)...
	local SLOT_HIGH_Y = 107.5 -- ...up to this one
	local SLOT_RAY_START_Y = 112 -- above the cap's brim: the ray comes down through every layer
	local SLOT_MAX_LAYERS = 20
	local SLOT_BLOCK_NAME = "LadderSlotBlock"
	local SLOT_BLOCKS_PER_SIDE = 1

	-- Every place on one side of the slot where a body fits on a walkable surface that isn't the ladder's truss, as
	-- text.
	local function slotRoomSpots(options: PathCheck.Options, side: number): { string }
		local Workspace = game:GetService("Workspace")
		local spots: { string } = {}
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = Collisions.GROUP
		local steepest = math.cos(math.rad(game:GetService("StarterPlayer").CharacterMaxSlopeAngle))
		for xTenths = SLOT_X_TENTHS_FROM, SLOT_X_TENTHS_TO do
			for zQuarters = SLOT_Z_QUARTERS_FROM, SLOT_Z_QUARTERS_TO do
				local x, z = side * xTenths / 10, zQuarters / 4
				local y = SLOT_RAY_START_Y
				for _ = 1, SLOT_MAX_LAYERS do
					local hit = Workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, SLOT_LOW_Y - y, 0), params)
					if hit == nil then
						break
					end
					if
						hit.Position.Y <= SLOT_HIGH_Y
						and not hit.Instance:IsA("TrussPart")
						and hit.Normal.Y >= steepest
						and PathCheck.roomToStand(options, hit.Position, hit.Normal)
					then
						table.insert(
							spots,
							string.format(
								"(%.2f, %.2f, %.2f) on %s",
								hit.Position.X,
								hit.Position.Y,
								hit.Position.Z,
								hit.Instance.Name
							)
						)
					end
					y = hit.Position.Y - 0.01 -- on down, under this surface
				end
			end
		end
		return spots
	end

	-- What is wrong with the slot blocks: more than one a side, a block that is visible, see-through, loose or a
	-- touch trigger, or one that touches the cap ladder's rails and rungs.
	local function slotBlockProblems(world: WorldRoot, blocks: { BasePart }, ladderParts: { BasePart }): { string }
		local problems: { string } = {}
		local perSide: { [number]: number } = {}
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Include
		local ladderInstances: { Instance } = {}
		for _, ladderPart in ladderParts do
			table.insert(ladderInstances, ladderPart)
		end
		overlap.FilterDescendantsInstances = ladderInstances
		overlap.RespectCanCollide = false
		for _, block in blocks do
			local side = math.sign(block.Position.X)
			perSide[side] = (perSide[side] or 0) + 1
			if block.Transparency ~= 1 then
				table.insert(problems, `a block at x {block.Position.X} is visible`)
			end
			if not block.CanCollide then
				table.insert(problems, `a block at x {block.Position.X} is not solid`)
			end
			if not block.Anchored then
				table.insert(problems, `a block at x {block.Position.X} is not anchored`)
			end
			if block.Material ~= Enum.Material.SmoothPlastic then
				table.insert(problems, `a block at x {block.Position.X} is not SmoothPlastic`)
			end
			if block.CanTouch then
				table.insert(problems, `a block at x {block.Position.X} has CanTouch on`)
			end
			for _, touched in world:GetPartsInPart(block, overlap) do
				table.insert(problems, `a block at x {block.Position.X} touches the ladder's {touched.Name}`)
			end
		end
		for side, count in perSide do
			if count > SLOT_BLOCKS_PER_SIDE then
				table.insert(problems, `{count} blocks on side {side} (at most {SLOT_BLOCKS_PER_SIDE})`)
			end
		end
		table.sort(problems)
		return problems
	end

	local function slotBlocks(): { BasePart }
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local blocks: { BasePart } = {}
		for _, child in (guard :: Instance):GetChildren() do
			if child.Name == SLOT_BLOCK_NAME and child:IsA("BasePart") then
				table.insert(blocks, child)
			end
		end
		return blocks
	end

	local function ladderRailsAndRungs(): { BasePart }
		local ladder = (realWorld() :: any).WalkSurfaces.CapLadder :: Instance
		local parts: { BasePart } = {}
		for _, part in ladder:GetDescendants() do
			if part:IsA("BasePart") and (part.Name == "Rung" or part.Name == "Rail") then
				table.insert(parts, part)
			end
		end
		expect(#parts > 2).toBe(true)
		return parts
	end

	it("no body fits beside the cap ladder", function()
		local options = PathCheck.defaults(game:GetService("Workspace"))
		local left: { string } = {}
		local right: { string } = {}
		local ok, message = pcall(function()
			left = slotRoomSpots(options, -1)
			right = slotRoomSpots(options, 1)
		end)
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		if not ok then
			error(message)
		end
		local blockProblems = slotBlockProblems(game:GetService("Workspace"), slotBlocks(), ladderRailsAndRungs())
		expect({ left = firstLines(left), right = firstLines(right), blocks = firstLines(blockProblems) }).toEqual({
			left = { count = 0, first = {} },
			right = { count = 0, first = {} },
			blocks = { count = 0, first = {} },
		})
	end)

	-- The slot-block checks, shown on made-up parts in a WorldModel: a good block passes; a second block on a side, a
	-- visible, loose, touchable block and one that touches a rung are all named.
	it("the slot block checks notice a bad block", function()
		local world = Instance.new("WorldModel")
		world.Archivable = false
		world.Parent = game:GetService("ServerStorage")
		local ok, message = pcall(function()
			local function part(name: string, position: Vector3, size: Vector3): Part
				local made = Instance.new("Part")
				made.Name = name
				made.Size = size
				made.Position = position
				made.Anchored = true
				made.CanCollide = true
				made.CanTouch = false
				made.Transparency = 1
				made.Material = Enum.Material.SmoothPlastic
				made.Parent = world
				return made
			end
			local rung = part("Rung", Vector3.new(0, 0, 0), Vector3.new(5, 0.4, 0.4))
			local good = part(SLOT_BLOCK_NAME, Vector3.new(5, 0, 0), Vector3.new(1, 4, 4))
			expect(slotBlockProblems(world, { good }, { rung })).toEqual({})
			local second = part(SLOT_BLOCK_NAME, Vector3.new(7, 0, 0), Vector3.new(1, 4, 4))
			expect(#slotBlockProblems(world, { good, second }, { rung })).toBe(1)
			local bad = part(SLOT_BLOCK_NAME, Vector3.new(-5, 0, 0), Vector3.new(6, 4, 4))
			bad.Transparency = 0
			bad.CanCollide = false
			bad.Anchored = false
			bad.Material = Enum.Material.Wood
			bad.CanTouch = true
			expect(#slotBlockProblems(world, { bad }, { rung })).toBe(6)
		end)
		world:Destroy()
		if not ok then
			error(message)
		end
	end)

	-- Stuck safety Task 25, test 11 (plan Ruling 13). Part A of each side's rails (the SideRail whose centre is in front
	-- of z -5) must have no top a body can stand on. On a grid of at most 0.25 studs over its footprint, a ray straight
	-- down that sees only that part hits a face steeper than 75 degrees.
	local FRONT_RAIL_BEFORE_Z = -5 -- a SideRail whose centre is in front of this is part A
	local FRONT_RAIL_GRID = 0.25 -- studs, at most
	local FRONT_RAIL_RAY_ABOVE = 5

	local function frontRailTopProblems(world: WorldRoot, rail: BasePart): { string }
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { rail }
		params.RespectCanCollide = false
		local cellsX = math.ceil(rail.Size.X / FRONT_RAIL_GRID)
		local cellsZ = math.ceil(rail.Size.Z / FRONT_RAIL_GRID)
		local rays, flat, missed = 0, 0, 0
		local flattest = 90
		for cellX = 1, cellsX do
			for cellZ = 1, cellsZ do
				local localX = -rail.Size.X / 2 + (cellX - 0.5) * rail.Size.X / cellsX
				local localZ = -rail.Size.Z / 2 + (cellZ - 0.5) * rail.Size.Z / cellsZ
				local over = rail.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
				local top = rail.Position.Y + rail.Size.Y / 2
				local hit = world:Raycast(
					Vector3.new(over.X, top + FRONT_RAIL_RAY_ABOVE, over.Z),
					Vector3.new(0, -(rail.Size.Y + 2 * FRONT_RAIL_RAY_ABOVE), 0),
					params
				)
				rays += 1
				if hit == nil then
					missed += 1
				else
					local degrees = wallDegrees(hit.Normal)
					flattest = math.min(flattest, degrees)
					if degrees <= WALL_MIN_DEGREES then
						flat += 1
					end
				end
			end
		end
		if flat == 0 and missed == 0 then
			return {}
		end
		return {
			string.format(
				"%s at x %.1f: %d of %d rays hit a face of 75 degrees or less (flattest %.1f), %d hit nothing",
				rail.Name,
				rail.Position.X,
				flat,
				rays,
				flattest,
				missed
			),
		}
	end

	it("nobody can stand on the rails' front parts", function()
		local fronts: { BasePart } = {}
		for _, rail in sideRails() do
			if rail.Position.Z < FRONT_RAIL_BEFORE_Z then
				table.insert(fronts, rail)
			end
		end
		expect(#fronts).toBe(2)
		local problems: { string } = {}
		for _, rail in fronts do
			for _, line in frontRailTopProblems(game:GetService("Workspace"), rail) do
				table.insert(problems, line)
			end
		end
		expect(problems).toEqual({})
	end)

	-- The top-face check, shown on made-up parts in a WorldModel: a flat box is named, a wedge with one steep slope is not.
	it("the rail top check notices a flat top and accepts a steep slope", function()
		local world = Instance.new("WorldModel")
		world.Archivable = false
		world.Parent = game:GetService("ServerStorage")
		local ok, message = pcall(function()
			local box = Instance.new("Part")
			box.Anchored = true
			box.Size = Vector3.new(1.5, 27.5, 6.7)
			box.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(14.6), 0)
			box.Parent = world
			expect(#frontRailTopProblems(world, box)).toBe(1)
			local wedge = Instance.new("Part")
			wedge.Shape = Enum.PartType.Wedge
			wedge.Anchored = true
			wedge.Size = Vector3.new(6.7, 27.5, 1.5)
			wedge.CFrame = CFrame.new(20, 0, 0) * CFrame.Angles(0, math.rad(-75.4), 0)
			wedge.Parent = world
			expect(frontRailTopProblems(world, wedge)).toEqual({})
		end)
		world:Destroy()
		if not ok then
			error(message)
		end
	end)
end)
