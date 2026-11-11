--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local GiantFx = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Fx.GiantFx)
local RouteGraph = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.World.RouteGraph)
local Helpers = require(script.Parent.Helpers)
local loadRoute = Helpers.loadRoute
local realWorld = Helpers.realWorld

-- The pieces the giant's waking pose moves (Task 28): where the head and the right arm turn, and the awake eyes.
describe("the real world, the giant's awake pieces", function()
	local function giant(): Model
		local world = game:GetService("Workspace"):FindFirstChild("World")
		expect(world).never.toBeNil()
		local found = (world :: Instance):FindFirstChild("Giant")
		expect(found).never.toBeNil()
		return found :: Model
	end

	it("has the head's turn point and tip, the head, the nightcap and the right arm, and 8 awake eye parts", function()
		local model = giant()
		expect(typeof(model:GetAttribute("Awake_HeadPivot"))).toBe("Vector3")
		expect(typeof(model:GetAttribute("Awake_HeadTiltDeg"))).toBe("number")
		expect(typeof(model:GetAttribute("Awake_RightShoulderPivot"))).toBe("Vector3")
		expect(typeof(model:GetAttribute("Awake_RightArmRaiseDegXZ"))).toBe("Vector3")
		for _, name in { "head_with_beard", "nightcap", "right_arm" } do
			local piece = model:FindFirstChild(name)
			expect(piece).never.toBeNil()
			expect((piece :: Instance):IsA("Model")).toBe(true)
		end
		local eyes = model:FindFirstChild("AwakeEyes")
		expect(eyes).never.toBeNil()
		local shown = 0
		for _, part in (eyes :: Instance):GetDescendants() do
			if part:IsA("BasePart") then
				expect(part:GetAttribute("ShownWhenAwake")).toBe(true)
				shown += 1
			end
		end
		expect(shown).toBe(8)
	end)
end)

-- The glowing footprint the client copies (ReplicatedStorage.Assets.Footprint) lives in the place file, not in Rojo.
-- It is changed by tools/world/09-footprint-colour.luau.
describe("the real world, footprints", function()
	local SIZE_MARGIN = 0.001 -- sizes are stored as 32-bit numbers
	-- Every part of the template, with its size.
	local expectedParts: { [string]: Vector3 } = {
		Sole = Vector3.new(1.5, 0.15, 2.1),
		Toe1 = Vector3.new(0.45, 0.15, 0.55),
		Toe2 = Vector3.new(0.45, 0.15, 0.55),
		Toe3 = Vector3.new(0.45, 0.15, 0.55),
	}

	it("the footprint template is neon #FFD43B on its sole and 3 toes, at its old size", function()
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local template = if assets then assets:FindFirstChild("Footprint") else nil
		expect(template).never.toBeNil()
		local seen: { [string]: { neon: boolean, colour: string, sizeOk: boolean } } = {}
		local count = 0
		for _, child in (template :: Instance):GetChildren() do
			count += 1
			local expectedSize: Vector3? = expectedParts[child.Name]
			if child:IsA("BasePart") and expectedSize ~= nil then
				seen[child.Name] = {
					neon = child.Material == Enum.Material.Neon,
					colour = child.Color:ToHex():upper(),
					sizeOk = (child.Size - expectedSize).Magnitude < SIZE_MARGIN,
				}
			end
		end
		local expected: { [string]: { neon: boolean, colour: string, sizeOk: boolean } } = {}
		for name in expectedParts do
			expected[name] = { neon = true, colour = "FFD43B", sizeOk = true }
		end
		expect(count).toBe(4)
		expect(seen).toEqual(expected)
	end)

	it("the boot-ramp planks: footprints at RampLift clear every cleat", function()
		local Workspace = game:GetService("Workspace")
		-- The footprint code lifts a footprint by RampLift when the ground ray hits a part named Ramp_Walk. Only the
		-- two boot ramps may have such a part, and their cleats must not reach that high or be solid.
		local planks: { BasePart } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == "Ramp_Walk" and descendant:IsA("BasePart") then
				table.insert(planks, descendant)
			end
		end
		local names: { string } = {}
		for _, plank in planks do
			table.insert(names, plank:GetFullName())
		end
		table.sort(names)
		expect(names).toEqual({
			"Workspace.World.WalkSurfaces.BootRamp.Ramp_Walk",
			"Workspace.World.WalkSurfaces.RightBootRamp.Ramp_Walk",
		})

		local problems: { string } = {}
		local cleatCount = 0
		for _, plank in planks do
			local up = plank.CFrame.UpVector
			local plankTop = plank.Size.Y / 2
			for _, cleat in (plank.Parent :: Instance):GetDescendants() do
				if cleat.Name == "Cleat" and cleat:IsA("BasePart") then
					cleatCount += 1
					if cleat.CanCollide then
						table.insert(problems, `{cleat:GetFullName()} is solid`)
					end
					-- The cleat's highest point above the plank's middle, measured along the plank's up direction.
					local half = cleat.Size / 2
					local highest = -math.huge
					for _, sx in { -1, 1 } do
						for _, sy in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local corner =
									cleat.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
								highest = math.max(highest, (corner - plank.Position):Dot(up))
							end
						end
					end
					if highest >= plankTop + Config.Footprints.RampLift then
						table.insert(
							problems,
							`{cleat:GetFullName()} reaches {highest - plankTop} studs above the plank`
						)
					end
				end
			end
		end
		expect(cleatCount > 0).toBe(true)
		expect(problems).toEqual({})
	end)

	-- Task 13: the quickest way, on the real route. The footprints are laid by RouteGraph.way, so these read the real
	-- route points and gardens and work the way out the same way the client does.
	local function wayUpOf(garden: number): string
		for _, wayUp in Config.WaysUp do
			if table.find(wayUp.Gardens, garden) then
				return wayUp.Name
			end
		end
		error(`no way up for garden {garden}`)
	end

	local function feetOf(garden: WorldIndex.Garden): Vector3
		return garden.spawnSpot.Position + Vector3.new(0, garden.spawnSpot.Size.Y / 2, 0)
	end

	local function passes(path: { Vector3 }, position: Vector3): boolean
		for _, point in path do
			if (point - position).Magnitude < 0.05 then
				return true
			end
		end
		return false
	end

	it("each garden's way to Rare egg 1 goes up its own way up (Config.WaysUp)", function()
		local points = loadRoute()
		local graph = RouteGraph.new(points)
		local gardens = WorldIndex.readGardens(realWorld()) :: { WorldIndex.Garden }
		local wrong: { string } = {}
		local lines: { string } = {}
		for _, garden in gardens do
			local name = wayUpOf(garden.index)
			local found = RouteGraph.find(graph, feetOf(garden), { "Nest_LowerBelly_Left", "Nest_LowerBelly_Right" })
			expect(found).never.toBeNil()
			local path = (found :: RouteGraph.Found).path
			local missing: { string } = {}
			for _, point in points do
				-- the way up's foot, and for a ladder its top too: the path has to pass both
				if (point.wayUpFoot == name or point.wayUpTop == name) and not passes(path, point.position) then
					table.insert(missing, point.name)
				end
			end
			table.insert(lines, `garden {garden.index}: {name}, to {(found :: RouteGraph.Found).target}`)
			if #missing > 0 then
				table.insert(wrong, `garden {garden.index} ({name}) misses {table.concat(missing, ", ")}`)
			end
		end
		print(table.concat(lines, "\n"))
		expect(wrong).toEqual({})
	end)

	it("a footprint way ends 2 studs short of every ladder it enters and has no footprint on the ladder", function()
		local points = loadRoute()
		local graph = RouteGraph.new(points)
		local gardens = WorldIndex.readGardens(realWorld()) :: { WorldIndex.Garden }
		local targets: { string } = {}
		for _, point in points do
			if point.target ~= nil then
				table.insert(targets, point.target)
			end
		end
		local problems: { string } = {}
		local entered: { [string]: boolean } = {}
		local minToLadder = math.huge
		for _, garden in gardens do
			for _, target in targets do
				local found = RouteGraph.find(graph, feetOf(garden), { target })
				if found == nil then
					continue
				end
				local steps = RouteGraph.place(found, Config.Footprints.Spacing, Config.Footprints.LadderStop)
				local runLength = 0
				for i = 1, #found.path - 1 do
					local from, to = found.path[i], found.path[i + 1]
					if not found.climbs[i] then
						runLength += (to - from).Magnitude
						continue
					end
					local nearest = math.huge
					for _, step in steps do
						nearest = math.min(nearest, (step.position - from).Magnitude)
						local along = (to - from)
						local t = (step.position - from):Dot(along) / along:Dot(along)
						-- only a footprint beside the ladder's length counts: one past either end is on the ground or the pad
						if t > 0.02 and t < 0.98 then
							minToLadder = math.min(minToLadder, (step.position - (from + along * t)).Magnitude)
						end
					end
					-- a run shorter than 3 studs may hold no footprint; only a longer run must end 1 to 3 studs short
					if runLength >= 3 and (nearest < 1 or nearest > 3) then
						table.insert(problems, `garden {garden.index} to {target}: {nearest} studs from the foot`)
					end
					if runLength >= 3 then
						entered[`{from.X}, {from.Y}, {from.Z}`] = true
					end
					runLength = 0
				end
			end
		end
		local count = 0
		for _ in entered do
			count += 1
		end
		print(
			`{count} ladder feet entered after a run of 3 studs or more; nearest footprint to any ladder link: {minToLadder}`
		)
		expect({ entered = count > 0, clearOfLadders = minToLadder > 0.5, problems = problems }).toEqual({
			entered = true,
			clearOfLadders = true,
			problems = {},
		})
	end)
end)

-- The spots where he slams when nobody can be targeted (Slams.pickEmpty): the meadow route points. A spot fits when its
-- 15-stud circle stays 1 stud clear of every garden and covers no landing spot. This only READS the world.
describe("the real world, slam spots", function()
	local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
	local Slams = require(ServerScriptService.Server.Giant.Slams)
	local MEADOW_POINTS_NEEDED = 8
	local COVERED_DISTANCE = Config.Wake.SlamCircleDiameter / 2

	local function flatDistance(a: Vector3, b: Vector3): number
		return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
	end

	-- Every meadow route point, the garden boxes, the landing spots and his face, read from the real world.
	local function load(): ({ WorldIndex.RoutePoint }, { Zones.GardenBox }, { Vector3 }, Vector3)
		local world = realWorld()
		local meadow: { WorldIndex.RoutePoint } = {}
		for _, point in WorldIndex.loadRoute(world) do
			if string.match(point.name, "^RoutePoint_Meadow_%d+$") then
				table.insert(meadow, point)
			end
		end
		local boxes = PlayerTracker.gardenBoxes(WorldIndex.loadGardens(world))
		local landing: { Vector3 } = {}
		for _, spot in WorldIndex.loadLandingSpots(world) do
			table.insert(landing, spot.position)
		end
		return meadow, boxes, landing, WorldIndex.loadGiantFace(world)
	end

	it("has the 18 meadow route points", function()
		local meadow = load()
		expect(#meadow).toBe(18)
	end)

	it(`at least {MEADOW_POINTS_NEEDED} meadow points fit as empty-slam spots`, function()
		local meadow, boxes, landing, face = load()
		local fits: { string } = {}
		local misses: { string } = {}
		for _, point in meadow do
			local reasons: { string } = {}
			if Slams.clearOfGardens(point.position, boxes, face) ~= point.position then
				table.insert(reasons, "its circle touches a garden")
			end
			for index, spot in landing do
				if flatDistance(point.position, spot) <= COVERED_DISTANCE then
					table.insert(reasons, `it covers landing spot {index}`)
				end
			end
			if #reasons == 0 then
				table.insert(fits, point.name)
			else
				table.insert(misses, `{point.name}: {table.concat(reasons, ", ")}`)
			end
		end
		if #fits < MEADOW_POINTS_NEEDED then
			local list = table.concat(misses, "\n")
			error(`only {#fits} meadow points fit, {MEADOW_POINTS_NEEDED} are needed. These do not:\n{list}`, 0)
		end
	end)

	it("Slams.pickEmpty finds a spot with no players, and it is one of the meadow points", function()
		local meadow, boxes, landing, _face = load()
		local positions: { Vector3 } = {}
		for _, point in meadow do
			table.insert(positions, point.position)
		end
		for pickIndex = 1, 3 do
			local chosen = Slams.pickEmpty(positions, {}, landing, boxes, nil, function(count: number): number
				return math.min(pickIndex, count)
			end)
			expect(table.find(positions, chosen)).never.toBeNil()
		end
	end)
end)

-- Where each slam's red circle is drawn: the surface a ray finds under the circle's centre (SlamSurface.below). This only
-- READS the world.
describe("the real world, slam surface", function()
	local SlamSurface = require(ServerScriptService.Server.Giant.SlamSurface)
	local Workspace = game:GetService("Workspace")

	-- The standing spot on his belly where the touchdown-guard check starts (docs/plans/core-heist.md, Task 30).
	local BELLY_SPOT = Vector3.new(-12.7, 49, -40.6)

	it("finds the ground within 0.5 studs of every meadow route point, from a player's middle height", function()
		local world = realWorld()
		local problems: { string } = {}
		local checked = 0
		for _, point in WorldIndex.loadRoute(world) do
			if string.match(point.name, "^RoutePoint_Meadow_%d+$") then
				checked += 1
				local hit = SlamSurface.below(Workspace, point.position + Vector3.new(0, 3, 0), {})
				if math.abs(hit.Y - point.position.Y) > 0.5 then
					table.insert(
						problems,
						`{point.name}: the surface is at y = {hit.Y}, the point is at y = {point.position.Y}`
					)
				end
			end
		end
		expect(checked).toBe(18)
		expect(problems).toEqual({})
	end)

	-- Measured in the place (code_lead, 2026-11-04): the ray from y = 49 now meets BellyRamp_Left.Piece15 at y = 41.46,
	-- where players stand since plan 3 Task 6a, so the circle is drawn where they stand, within a small margin.
	it("finds the belly's surface, about 8 studs under the belly standing spot", function()
		realWorld()
		local hit = SlamSurface.below(Workspace, BELLY_SPOT, {})
		expect(hit.Y).toBeGreaterThan(40)
		expect(hit.Y).toBeLessThan(49)
		expect(math.abs(hit.Y - 41.46) <= 0.5).toBe(true)
		expect(hit.X).toBeCloseTo(BELLY_SPOT.X, 1)
		expect(hit.Z).toBeCloseTo(BELLY_SPOT.Z, 1)
	end)

	it("sends the centre 3 studs lower when the ray finds nothing, far below the map", function()
		realWorld()
		local centre = Vector3.new(0, -500, 0)
		expect(SlamSurface.below(Workspace, centre, {})).toEqual(centre - Vector3.new(0, 3, 0))
	end)

	it("without the ramp and the giant, the belly spot's ray lands lower", function()
		local world = realWorld()
		local giant = (world :: any).Giant :: Model
		local ramp = ((world :: any).WalkSurfaces :: Instance):FindFirstChild("BellyRamp_Left")
		expect(ramp).never.toBeNil()
		local withoutRamp = SlamSurface.below(Workspace, BELLY_SPOT, { ramp :: Instance })
		local withoutBoth = SlamSurface.below(Workspace, BELLY_SPOT, { ramp :: Instance, giant })
		expect(withoutBoth.Y).toBeLessThan(withoutRamp.Y)
	end)

	it("falls to the meadow when the giant and the walk surfaces are both ignored", function()
		local world = realWorld()
		local giant = (world :: any).Giant :: Model
		local walkSurfaces = (world :: any).WalkSurfaces :: Instance
		local hit = SlamSurface.below(Workspace, BELLY_SPOT, { giant, walkSurfaces })
		expect(hit.Y).toBeLessThan(10)
		expect(hit.Y).toBeGreaterThan(-1)
	end)
end)

-- Where his right arm may swing at a slam (Task 31, review round 1). These tests only READ the real world: they cast
-- rays and change nothing.
describe("the real world, the slam arm and his body", function()
	local Workspace = game:GetService("Workspace")

	local function realGiant(): (Model, Instance)
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local found = (world :: Instance):FindFirstChild("Giant")
		expect(found).never.toBeNil()
		return found :: Model, world :: Instance
	end

	-- The shoulder, and the arm's direction in the full raise, exactly as GiantFx works them out.
	local function armNumbers(giant: Model): (Vector3, Vector3)
		local shoulder = giant:GetAttribute("Awake_RightShoulderPivot")
		local raise = giant:GetAttribute("Awake_RightArmRaiseDegXZ")
		expect(typeof(shoulder)).toBe("Vector3")
		expect(typeof(raise)).toBe("Vector3")
		local arm = giant:FindFirstChild("right_arm")
		expect(arm).never.toBeNil()
		local middle = ((arm :: Model):GetBoundingBox()).Position
		local from = GiantFx.armRaise(shoulder :: Vector3, raise :: Vector3, 1):PointToWorldSpace(middle)
			- shoulder :: Vector3
		return shoulder :: Vector3, from
	end

	local function describeVector(vector: Vector3): string
		return `({vector.X}, {vector.Y}, {vector.Z})`
	end

	it("sends the arm to the fixed pose for targets on his left, on his belly and in front of his left boot", function()
		local giant, world = realGiant()
		local shoulder, from = armNumbers(giant)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		local fixed = GiantFx.slamFixedAim(shoulder, giant:GetPivot())
		for _, point in
			{
				Vector3.new(-97, 2, 1),
				Vector3.new(-50, 2, -54),
				Vector3.new(-12.7, 41, -40.6),
				Vector3.new(2, 2, -80),
			}
		do
			local aim = GiantFx.slamAim(shoulder, from, point, fixed, clear)
			expect(`{describeVector(point)} {aim == fixed}`).toBe(`{describeVector(point)} true`)
		end
	end)

	it("lets the arm point straight at targets on his right side", function()
		local giant, world = realGiant()
		local shoulder, from = armNumbers(giant)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		local fixed = GiantFx.slamFixedAim(shoulder, giant:GetPivot())
		for _, point in
			{
				Vector3.new(94, 2, 4),
				Vector3.new(30.5, 1.8, -101),
				Vector3.new(22, 2, -80),
				Vector3.new(106, 1.7, -6),
			}
		do
			local aim = GiantFx.slamAim(shoulder, from, point, fixed, clear)
			expect(`{describeVector(point)} {aim == point}`).toBe(`{describeVector(point)} true`)
		end
	end)

	it("keeps the fixed pose clear of his body at a quarter, half, three quarters and all of its swing", function()
		local giant, world = realGiant()
		local shoulder, from = armNumbers(giant)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		local fixed = GiantFx.slamFixedAim(shoulder, giant:GetPivot())
		for _, share in { 0.25, 0.5, 0.75, 1 } do
			local direction = GiantFx.slamTurn(shoulder, from, fixed, share):VectorToWorldSpace(from)
			expect(`share {share} {clear(shoulder, direction)}`).toBe(`share {share} true`)
		end
	end)

	it("sees his body at all: a ray from the shoulder straight into his chest is not clear", function()
		local giant, world = realGiant()
		local shoulder = giant:GetAttribute("Awake_RightShoulderPivot") :: Vector3
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		-- Toward the middle of his body, to his left.
		expect(clear(shoulder, Vector3.new(-1, -0.2, 0))).toBe(false)
	end)
end)
