--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Layout)
local SpotModels = require(ServerScriptService.Server.Eggs.SpotModels)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local CameraFx = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Fx.CameraFx)
local GiantFx = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Fx.GiantFx)
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local PlayerNeeds = require(game:GetService("ServerStorage").Tests.server.World.PlayerNeeds)

-- Check 6's limits (stuck safety spec, Rule 20) and its sideways search, in one place. "his solid body sits where he's
-- drawn" and "the patches" both use them, so the two can never drift apart.
local ABOVE_LIMIT = 0.2 -- studs: a solid shape may be this far over his drawn skin...
local BELOW_LIMIT = 0.3 -- studs: ...and this far under it
local LIMIT_SLACK = 0.001 -- studs: rounding in the numbers written into the world
local SKIN_SEARCH_ABOVE = 1 -- studs: the drawn skin is read up to this far over the solid shape (not the skin of a floor above)
local SKIN_SIDE_REACH = 0.3 -- studs: the drawn skin is also read this far sideways of a point (never the solid shape)
local SKIN_SIDE_STEPS = 3 -- the sideways reads are SKIN_SIDE_REACH / SKIN_SIDE_STEPS = 0.1 studs apart, inside a circle

-- His slope at body size (designer's rule), in one place so "his slide line is the seam" and the slide-guard tests
-- (stuck safety Task 23) read it the same way. Moved here from the seam test unchanged (Task 23, decision 6).
local BODY_SLOPE_REACH = 2 -- 25 rays 1 stud apart on a 4 by 4 stud square around the place
local BODY_SLOPE_RAY_ABOVE = 150 -- the rays start this high...
local BODY_SLOPE_RAY_LENGTH = 250 -- ...and look this far down

-- The steepness in degrees of the flat plane that best fits 25 rays straight down on a 4 by 4 stud square around
-- (x, z). Gives the height of the middle ray too. Nil when a ray misses (the square reaches past what `params` sees).
-- The grid is even, so the best-fit plane comes from two sums.
local function bodySizeSlopeAt(params: RaycastParams, x: number, z: number): (number?, number?)
	local sumX, sumZ, middleY = 0, 0, 0
	for offsetX = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
		for offsetZ = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
			local hit = game:GetService("Workspace"):Raycast(
				Vector3.new(x + offsetX, BODY_SLOPE_RAY_ABOVE, z + offsetZ),
				Vector3.new(0, -BODY_SLOPE_RAY_LENGTH, 0),
				params
			)
			if hit == nil then
				return nil, nil
			end
			sumX += offsetX * hit.Position.Y
			sumZ += offsetZ * hit.Position.Y
			if offsetX == 0 and offsetZ == 0 then
				middleY = hit.Position.Y
			end
		end
	end
	-- for offsets -2 to 2 the sum of offset squared over the grid is 5 columns of (4 + 1 + 0 + 1 + 4) = 50
	local squares = (2 * BODY_SLOPE_REACH + 1)
		* (BODY_SLOPE_REACH * (BODY_SLOPE_REACH + 1) * (2 * BODY_SLOPE_REACH + 1) / 3)
	local normal = Vector3.new(-sumX / squares, 1, -sumZ / squares).Unit
	return math.deg(math.acos(math.clamp(normal.Y, -1, 1))), middleY
end

-- Helpers the describe blocks below share. Each is written once, here.
local BODY_PIECES = { "legs_and_boots", "body_and_cushion", "left_arm", "right_arm", "head_with_beard", "nightcap" }
local SMALL_PATCHES_FOLDER = "SmallPatches" -- World.WalkSurfaces.SmallPatches (Task 23, decision 3)

local function describePoint(point: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", point.X, point.Y, point.Z)
end

-- A face of a patch in its own space: where its middle is, which way it faces, and the two directions it spreads in
-- with half its length in each.
type Face = { center: Vector3, normal: Vector3, u: Vector3, uHalf: number, v: Vector3, vHalf: number }

-- The faces of a block (six) or a wedge (five: its bottom, back, two sides and sloped top), as DrawnSkin draws them.
local function facesOf(patch: BasePart): { Face }
	local half = patch.Size / 2
	local x, y, z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	local faces: { Face } = {
		{ center = -y * half.Y, normal = -y, u = x, uHalf = half.X, v = z, vHalf = half.Z },
		{ center = x * half.X, normal = x, u = y, uHalf = half.Y, v = z, vHalf = half.Z },
		{ center = -x * half.X, normal = -x, u = y, uHalf = half.Y, v = z, vHalf = half.Z },
		{ center = z * half.Z, normal = z, u = x, uHalf = half.X, v = y, vHalf = half.Y },
	}
	if patch:IsA("WedgePart") then
		local slope = Vector3.new(0, patch.Size.Y, patch.Size.Z)
		table.insert(faces, {
			center = Vector3.zero,
			normal = Vector3.new(0, patch.Size.Z, -patch.Size.Y).Unit,
			u = x,
			uHalf = half.X,
			v = slope.Unit,
			vHalf = slope.Magnitude / 2,
		})
	else
		table.insert(faces, { center = y * half.Y, normal = y, u = x, uHalf = half.X, v = z, vHalf = half.Z })
		table.insert(faces, { center = -z * half.Z, normal = -z, u = x, uHalf = half.X, v = y, vHalf = half.Y })
	end
	return faces
end

-- Runs `run` with a made-up WorldModel that is destroyed afterwards, even when `run` fails.
local function inFakeWorld(run: (world: WorldModel) -> ())
	local world = Instance.new("WorldModel")
	world.Archivable = false
	world.Parent = game:GetService("ServerStorage")
	local ok, message = pcall(function(): string?
		run(world)
		return nil
	end)
	world:Destroy()
	if not ok then
		error(message, 0)
	end
end

local function startsWith(problems: { string }, prefix: string): { string }
	local found: { string } = {}
	for _, problem in problems do
		if string.sub(problem, 1, #prefix) == prefix then
			table.insert(found, problem)
		end
	end
	return found
end

-- A place under a roof (a crevice, the underside of a chair arm) can't be read by rays from y 150: they hit whatever is
-- on top. So a cloth point with a face that points down within ROOF_SEARCH studs above it (the search starts CLOTH_LIFT
-- over the point) is read square to its face instead: `bodySizeSlopeFacing`.
local ROOF_SEARCH = 10 -- studs: how far up to look for a roof
local CLOTH_LIFT = 0.5 -- studs: the roof search starts this far over the cloth point under a place

-- The same best-fit plane, read square to a face instead of straight down (code_lead's ruling after step 23-8a, round 1,
-- point 2b): on a face of 70 to 80 degrees a 4 by 4 stud square read from above spans up to 11 studs of height, so the
-- rays from above start inside him. These 25 rays form the same 5 by 5 grid, 1 stud apart, in the plane square to
-- `normal` (the face's outward direction). They start FACING_OUT studs out from `point` and aim back along `normal`,
-- FACING_OUT + FACING_IN studs long. The plane fitted to where they hit has its steepness from straight up returned.
-- Nil when a ray misses.
local FACING_OUT = 2 -- studs: the rays start this far out from the cloth point...
local FACING_IN = 2 -- ...and look this far in past it
local function bodySizeSlopeFacing(params: RaycastParams, point: Vector3, normal: Vector3): number?
	local out = normal.Unit
	local side = out:Cross(Vector3.yAxis)
	local across = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local along = out:Cross(across)
	local sumAcross, sumAlong = 0, 0
	for offsetAcross = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
		for offsetAlong = -BODY_SLOPE_REACH, BODY_SLOPE_REACH do
			local origin = point + out * FACING_OUT + across * offsetAcross + along * offsetAlong
			local hit = game:GetService("Workspace"):Raycast(origin, -out * (FACING_OUT + FACING_IN), params)
			if hit == nil then
				return nil
			end
			local height = (hit.Position - point):Dot(out) -- how far the hit lies out from the plane through `point`
			sumAcross += offsetAcross * height
			sumAlong += offsetAlong * height
		end
	end
	-- the same sum as bodySizeSlopeAt's: for offsets -2 to 2 the sum of offset squared over the grid is 50
	local squares = (2 * BODY_SLOPE_REACH + 1)
		* (BODY_SLOPE_REACH * (BODY_SLOPE_REACH + 1) * (2 * BODY_SLOPE_REACH + 1) / 3)
	local planeNormal = (out - across * (sumAcross / squares) - along * (sumAlong / squares)).Unit
	return math.deg(math.acos(math.clamp(planeNormal.Y, -1, 1)))
end

-- A roof higher than ROOF_SEARCH (code_lead's ruling after step 23-8b.1, Ruling 10) makes the read from above hit the
-- roof, not the cloth: its middle ray lands far from the cloth point. If it lands more than CLOTH_MATCH studs from the
-- cloth point's height, it didn't read the cloth, so the facing read is used. Where it does land on the cloth, the read
-- from above stands, as the seam test reads it (the 65 degree line is read the same way).
local CLOTH_MATCH = 0.5 -- studs: the most the middle ray's height may differ from the cloth point's height

-- His slope at body size at a cloth point (with the face's outward direction there): where a roof lies within ROOF_SEARCH
-- studs above the point (a crevice, the underside of a chair arm), or the read from above didn't land on the cloth
-- (CLOTH_MATCH), the facing read; otherwise exactly bodySizeSlopeAt's read from above, as the seam test reads it.
local function bodySizeSlopeAtCloth(params: RaycastParams, point: Vector3, normal: Vector3): number?
	local roof = game:GetService("Workspace")
		:Raycast(point + Vector3.new(0, CLOTH_LIFT, 0), Vector3.new(0, ROOF_SEARCH, 0), params)
	if roof ~= nil and roof.Normal.Y < 0 then
		return bodySizeSlopeFacing(params, point, normal)
	end
	local fromAbove, middleHeight = bodySizeSlopeAt(params, point.X, point.Z)
	if middleHeight ~= nil and math.abs(middleHeight - point.Y) > CLOTH_MATCH then
		return bodySizeSlopeFacing(params, point, normal)
	end
	return fromAbove
end

local function outsideLimits(gap: number): boolean
	return gap ~= gap or gap > ABOVE_LIMIT + LIMIT_SLACK or gap < -BELOW_LIMIT - LIMIT_SLACK
end

-- The gap to the drawn skin within SKIN_SIDE_REACH studs sideways of (x, z) that fits the limits and is the closest to
-- zero, or nil when no skin there fits. `solidY` is the solid shape's height at the point.
local function sidewaysFit(reader: DrawnSkin.Skin, x: number, z: number, solidY: number): number?
	local best: number? = nil
	local step = SKIN_SIDE_REACH / SKIN_SIDE_STEPS
	for i = -SKIN_SIDE_STEPS, SKIN_SIDE_STEPS do
		for j = -SKIN_SIDE_STEPS, SKIN_SIDE_STEPS do
			if i * i + j * j <= SKIN_SIDE_STEPS * SKIN_SIDE_STEPS then
				local drawn = reader.heightAt(x + i * step, z + j * step, solidY + SKIN_SEARCH_ABOVE)
				if drawn ~= nil then
					local gap = solidY - drawn
					if not outsideLimits(gap) and (best == nil or math.abs(gap) < math.abs(best)) then
						best = gap
					end
				end
			end
		end
	end
	return best
end

-- These tests only READ the real world (Workspace.World). They change nothing.
-- The world is built by tools/world/01-gardens.luau.
describe("the real world", function()
	local function isInside(box: WorldIndex.Box, point: Vector3): boolean
		local local_ = box.cframe:PointToObjectSpace(point)
		local half = box.size / 2
		return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
	end

	local function flat(vector: Vector3): Vector3
		return Vector3.new(vector.X, 0, vector.Z)
	end

	-- Fails the test with a clear message if the world is missing or broken.
	local function loadRealGardens(): ({ WorldIndex.Garden }, Instance)
		local world = game:GetService("Workspace"):FindFirstChild("World")
		expect(world).never.toBeNil()
		local gardens, problems = WorldIndex.readGardens(world :: Instance)
		expect(problems).toEqual({})
		return gardens :: { WorldIndex.Garden }, world :: Instance
	end

	it("the real world passes the garden check", function()
		local gardens = loadRealGardens()
		expect(#gardens).toBe(8)
	end)

	it("each spawn spot is 18 studs in front of its gate", function()
		local gardens = loadRealGardens()
		for _, garden in gardens do
			local distance = (flat(garden.spawnSpot.Position) - flat(garden.gate:GetPivot().Position)).Magnitude
			expect(math.abs(distance - 18) <= 0.5).toBe(true)
			expect(isInside(garden.box, garden.spawnSpot.Position)).toBe(false)
		end
	end)

	it("each spawn spot faces the giant", function()
		local gardens, world = loadRealGardens()
		local giant = (world :: any).Giant :: Model
		for _, garden in gardens do
			local toGiant = flat(giant:GetPivot().Position - garden.spawnSpot.Position).Unit
			local look = flat(garden.spawnSpot.CFrame.LookVector).Unit
			expect(look:Dot(toGiant) > 0.99).toBe(true)
		end
	end)

	it("each garden box holds its own gate and pads", function()
		local gardens = loadRealGardens()
		for _, garden in gardens do
			expect(isInside(garden.box, garden.gate:GetPivot().Position)).toBe(true)
			for _, petPad in garden.petPads do
				expect(isInside(garden.box, petPad:GetPivot().Position)).toBe(true)
			end
		end
	end)
end)

-- More read-only checks of the real world. The zone boxes are built by tools/world/02-zones.luau, and the
-- garden extras, prop moves, Z Z Z and sky by tools/world/02b-garden-extras.luau.
describe("the real world, zones and extras", function()
	local function realWorld(): Instance
		local world = game:GetService("Workspace"):FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

	it("the real world passes the zone check", function()
		local boxes, problems = WorldIndex.readZones(realWorld())
		expect(problems).toEqual({})
		expect(boxes).never.toBeNil()
	end)

	-- Where a point is, using the real zone boxes and the real garden boxes.
	local function locator(): (Instance, (Vector3) -> any)
		local world = realWorld()
		local zoneBoxes, zoneProblems = WorldIndex.readZones(world)
		expect(zoneProblems).toEqual({})
		local gardens, gardenProblems = WorldIndex.readGardens(world)
		expect(gardenProblems).toEqual({})
		local gardenBoxes = {}
		for _, garden in gardens :: { WorldIndex.Garden } do
			table.insert(gardenBoxes, { index = garden.index, cframe = garden.box.cframe, size = garden.box.size })
		end
		return world,
			function(point: Vector3)
				return Zones.locate(point, zoneBoxes :: { Zones.ZoneBox }, gardenBoxes)
			end
	end

	it("the real world puts these points in the right zones", function()
		local world, locate = locator()
		local walk = (world :: any).WalkSurfaces
		local up = Vector3.new(0, 3, 0) -- a player's root is about 3 studs above the surface

		-- every spawn spot is Meadow and in no garden (the egg spots have their own test, "each in its zone")
		for _, garden in WorldIndex.loadGardens(world) do
			expect(locate(garden.spawnSpot.Position + up)).toEqual({ zone = "Meadow", garden = nil })
		end

		-- the left boot ramp: grass 4 studs beside its foot is Meadow, its middle is Boots
		local ramp = walk.BootRamp.Ramp_Walk :: BasePart
		local lowEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, ramp.Size.Z / 2))
		local highEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, -ramp.Size.Z / 2))
		local foot = if lowEnd.Y < highEnd.Y then lowEnd else highEnd
		local beside = foot + ramp.CFrame.RightVector * (ramp.Size.X / 2 + 4) + up
		expect(locate(beside)).toEqual({ zone = "Meadow", garden = nil })
		expect(locate(ramp.Position + ramp.CFrame.UpVector * 3).zone).toBe("Boots")

		-- the middle of the belly path: the middle one (the 9th of 17, counting up) of V1's Belly_Walk pieces, which stuck safety
		-- Task 24 took away. Its place is written down from before that task (World.WalkSurfaces, measured 2026-10-20).
		local bellyMiddle = Vector3.new(-9.303, 48.424, -36.275)
		expect(locate(bellyMiddle + up).zone).toBe("Belly")

		-- the beard ladder's middle
		local ladderCenter = walk.BeardLadder:GetBoundingBox().Position
		expect(locate(ladderCenter).zone).toBe("Beard")

		-- the top of his nose. Fixed named points (stuck safety Task 25 took V1's walk pieces away; measured 2026-10-20):
		-- the top of V1's nose deck, Nose_Walk (centre (0, 99.74, -4.3), 1 stud thick), and the middle of the new open
		-- nose top, his skin at x 0, z -8.5 (y 94.24).
		local oldDeckTop = Vector3.new(0, 99.74 + 0.5, -4.3)
		local noseTopMiddle = Vector3.new(0, 94.24, -8.5)
		expect(locate(oldDeckTop + up).zone).toBe("Beard")
		expect(locate(noseTopMiddle + up).zone).toBe("Beard")

		-- the cap top. V1's three Nightcap_Walk pieces stood at these centres (the middle one is the 2nd); a player on the
		-- cap where they were is in the Nightcap zone.
		local oldCapPieces = {
			Vector3.new(2.958, 119.6113, 12.493),
			Vector3.new(14.857, 116.858, 14.9523), -- the middle piece
			Vector3.new(8.8808, 118.6066, 13.4801),
		}
		for _, centre in oldCapPieces do
			expect(locate(centre + up).zone).toBe("Nightcap")
		end

		-- the centre of each garden is that garden
		for _, garden in WorldIndex.loadGardens(world) do
			expect(locate(garden.box.cframe.Position)).toEqual({ zone = "Meadow", garden = garden.index })
		end
	end)

	it("every garden has exactly one incubator, and no egg sits in it", function()
		for _, garden in WorldIndex.loadGardens(realWorld()) do
			local dressing = garden.incubator.Parent :: Instance
			local incubators = 0
			for _, child in dressing:GetChildren() do
				if string.match(child.Name, "^Incubator%d+$") then
					incubators += 1
				end
			end
			expect({ garden = garden.index, incubators = incubators }).toEqual({ garden = garden.index, incubators = 1 })
			local eggs = {}
			for _, part in garden.incubator:GetDescendants() do
				if string.find(string.lower(part.Name), "egg", 1, true) then
					table.insert(eggs, part:GetFullName())
				end
			end
			expect({ garden = garden.index, eggs = eggs }).toEqual({ garden = garden.index, eggs = {} })
		end
	end)

	it("the Z Z Z float just above his face and the sky has no stars", function()
		local emitter = (realWorld() :: any).GiantFX.SnoreEmitter :: BasePart
		local floatingZ = emitter:FindFirstChild("FloatingZ") :: BillboardGui
		expect(floatingZ.StudsOffset).toEqual(Vector3.new(14, 8, 2))
		-- the size stays as it was (a billboard sized by scale is measured in studs: 16 x 16)
		expect(floatingZ.Size).toEqual(UDim2.fromScale(16, 16))
		local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
		expect(sky).never.toBeNil()
		expect((sky :: Sky).StarCount).toBe(0)
	end)

	it("the giant has every piece GiantFx moves for his warnings", function()
		local world = realWorld() :: any
		for _, lidName in { "LeftLid", "RightLid" } do
			local lid = world.Giant.SleepEyes[lidName] :: Model
			expect(lid:IsA("Model")).toBe(true)
			expect(lid:GetAttribute("FlutterLift")).toBe(1.4)
			local sliver = lid:FindFirstChild("Sliver")
			expect(sliver).never.toBeNil()
			expect((sliver :: BasePart).Transparency).toBe(1)
		end
		expect(world.Giant.right_arm:IsA("Model")).toBe(true)
		expect(typeof(world.Giant:GetAttribute("Awake_RightShoulderPivot"))).toBe("Vector3")
		local floatingZ = world.GiantFX.SnoreEmitter.FloatingZ :: BillboardGui
		local letters = 0
		for _, letter in floatingZ:GetChildren() do
			if letter:IsA("TextLabel") then
				letters += 1
				expect(letter:FindFirstChildOfClass("UIStroke")).never.toBeNil()
			end
		end
		expect(letters).toBe(3)
		expect(world.GiantFX.SnoreEmitter.SnorePuff:IsA("ParticleEmitter")).toBe(true)
		expect(world.GiantFX.SnoreEmitter.Warning85Bubble.Enabled).toBe(false)
	end)

	-- The camera a player gets at spawn: spot top + 4.5 studs, the spot's look direction, 12.5 away, at Roblox's
	-- normal 15 degrees down plus the tilt up from Config.
	local function spawnCameraFor(spot: BasePart): CFrame
		local focus = spot.Position + Vector3.new(0, spot.Size.Y / 2 + 4.5, 0)
		return CameraFx.spawnView(focus, spot.CFrame.LookVector, 12.5, -15 + Config.Spawn.CameraTiltUpDegrees)
	end

	-- The centre of each Z letter, in the world, for a player looking through `camera`. The billboard is drawn
	-- facing this camera. Its offset is measured in the camera's own directions, and each letter sits inside the
	-- billboard (its Scale size is in studs, 16 x 16). Also gives each letter's height in studs.
	type Letter = { name: string, centre: Vector3, heightStuds: number }
	local function letterCentres(camera: CFrame, emitter: BasePart, floatingZ: BillboardGui): { Letter }
		local centreOfBillboard = emitter.Position + camera:VectorToWorldSpace(floatingZ.StudsOffset)
		local letters: { Letter } = {}
		for _, letter in floatingZ:GetChildren() do
			if letter:IsA("TextLabel") then
				local right = (letter.Position.X.Scale + letter.Size.X.Scale / 2 - 0.5) * floatingZ.Size.X.Scale
				local up = (0.5 - letter.Position.Y.Scale - letter.Size.Y.Scale / 2) * floatingZ.Size.Y.Scale
				table.insert(letters, {
					name = `Z{#letters + 1}`,
					centre = centreOfBillboard + camera.RightVector * right + camera.UpVector * up,
					heightStuds = letter.Size.Y.Scale * floatingZ.Size.Y.Scale,
				})
			end
		end
		return letters
	end

	-- Pure maths: how many pixels down from the top of a screen `screenHeight` pixels tall a world point appears,
	-- for a camera at `camera` with Roblox's normal 70 degree vertical field of view.
	local function screenYOf(camera: CFrame, point: Vector3, screenHeight: number): number
		local inCamera = camera:PointToObjectSpace(point)
		local pixelsPerUnitAtOneStud = (screenHeight / 2) / math.tan(math.rad(70 / 2))
		return screenHeight / 2 - inCamera.Y / -inCamera.Z * pixelsPerUnitAtOneStud
	end

	it("screenYOf puts the view's middle at half the height and the top of the 70 degree view at 0", function()
		local camera = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
		expect(screenYOf(camera, Vector3.new(0, 0, -50), 390)).toBeCloseTo(195, 3)
		local topOfView = Vector3.new(0, 10 * math.tan(math.rad(35)), -10)
		expect(screenYOf(camera, topOfView, 390)).toBeCloseTo(0, 3)
	end)

	it("nothing solid blocks the view from any spawn spot to his face", function()
		local world = realWorld()
		local giant = (world :: any).Giant :: Model
		local emitter = (world :: any).GiantFX.SnoreEmitter :: BasePart
		local floatingZ = emitter:FindFirstChild("FloatingZ") :: BillboardGui

		-- A hit on an invisible or non-colliding part is not solid, so we look past it. His own body is not a
		-- blocker either: from the side, his head hides his far eye, which is how a side view works. Only things
		-- standing in the world (props, trees, bushes) can block the view.
		local function isSolid(part: BasePart): boolean
			return part.Transparency < 1 and part.CanCollide and not part:IsDescendantOf(giant)
		end

		-- Is the line from `from` to `target` clear? A hit within 4 studs of the target counts as reaching it.
		local function blockerOnLine(from: Vector3, target: Vector3): string?
			local ignore: { Instance } = {}
			for _ = 1, 50 do
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = ignore
				local hit = workspace:Raycast(from, target - from, params)
				if hit == nil or (hit.Position - target).Magnitude <= 4 then
					return nil
				end
				if isSolid(hit.Instance) then
					return hit.Instance:GetFullName()
				end
				table.insert(ignore, hit.Instance)
			end
			return "too many see-through parts in the way"
		end

		-- The bottom of his beard: the foot of the beard ladder (it runs up his beard), 5 studs up the slope.
		local ladderCenter, ladderSize = (world :: any).WalkSurfaces.BeardLadder:GetBoundingBox()
		local beardBottom = ladderCenter.Position
			- ladderCenter.LookVector * (ladderSize.Z / 2)
			+ ladderCenter.LookVector * 5

		local blocked = {}
		for _, garden in WorldIndex.loadGardens(world) do
			local spot = garden.spawnSpot
			local camera = spawnCameraFor(spot)

			-- what we must see: both eyelids, the nose, the bottom of his beard, and each of the three Z's
			local targets: { [string]: Vector3 } = {
				LeftLid = (giant :: any).SleepEyes.LeftLid:GetPivot().Position,
				RightLid = (giant :: any).SleepEyes.RightLid:GetPivot().Position,
				Nose = emitter.Position,
				BeardBottom = beardBottom,
			}
			local letters = letterCentres(camera, emitter, floatingZ)
			for _, letter in letters do
				targets[letter.name] = letter.centre
			end
			expect(#letters).toBe(3)

			for name, point in targets do
				local blocker = blockerOnLine(camera.Position, point)
				if blocker then
					table.insert(blocked, `Plot_{garden.index} cannot see {name}: blocked by {blocker}`)
				end
			end
		end
		table.sort(blocked)
		expect(blocked).toEqual({})
	end)

	-- Stuck safety Task 25 (designer 5 and 7): the cap ladder must not hide either closed eye from where a player spawns.
	-- The eyes are the lid and the lashes of SleepEyes.LeftLid and RightLid (they have no collision and no query, so
	-- rays go through them). Sample points lie on the faces of every visible eye part. A point is seen when no part of
	-- his six body pieces stands between the spawn camera and it. The ladder covers a seen point when the straight line
	-- from the camera to it passes through a visible ladder part. That line test is plain maths, so a copy of the ladder
	-- outside the Workspace can be checked too.
	local EYE_POINTS_PER_SIDE = 4 -- sample points along each side of each face of an eye part
	local EYE_MARGIN = 0.05 -- studs: a body hit this close to a point still means the point is seen

	local function eyeSamplePoints(world: any): { Vector3 }
		local points: { Vector3 } = {}
		for _, lidName in { "LeftLid", "RightLid" } do
			for _, part in world.Giant.SleepEyes[lidName]:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local half = { part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2 }
					for axis = 1, 3 do
						local other1 = if axis == 1 then 2 else 1
						local other2 = if axis == 3 then 2 else 3
						for _, sign in { -1, 1 } do
							for first = 0, EYE_POINTS_PER_SIDE - 1 do
								for second = 0, EYE_POINTS_PER_SIDE - 1 do
									local local_ = { 0, 0, 0 }
									local_[axis] = sign * half[axis]
									local_[other1] = (first / (EYE_POINTS_PER_SIDE - 1) * 2 - 1) * half[other1]
									local_[other2] = (second / (EYE_POINTS_PER_SIDE - 1) * 2 - 1) * half[other2]
									table.insert(
										points,
										part.CFrame:PointToWorldSpace(Vector3.new(local_[1], local_[2], local_[3]))
									)
								end
							end
						end
					end
				end
			end
		end
		return points
	end

	-- The sample points a camera at `camera` really sees.
	local function seenEyePoints(camera: CFrame, world: any): { Vector3 }
		local bodies: { Instance } = {}
		for _, name in BODY_PIECES do
			table.insert(bodies, world.Giant[name][name])
		end
		local params = RaycastParams.new()
		params.IncludeInstances = bodies
		params.RespectCanCollide = false
		local seen: { Vector3 } = {}
		for _, point in eyeSamplePoints(world) do
			local offset = point - camera.Position
			local hit = game:GetService("Workspace"):Raycast(camera.Position, offset, params)
			if hit == nil or hit.Distance >= offset.Magnitude - EYE_MARGIN then
				table.insert(seen, point)
			end
		end
		return seen
	end

	-- Does the straight line from `from` to `to` pass through the box of `part`?
	local function lineThroughBox(from: Vector3, to: Vector3, part: BasePart): boolean
		local start = part.CFrame:PointToObjectSpace(from)
		local move = part.CFrame:PointToObjectSpace(to) - start
		local starts = { start.X, start.Y, start.Z }
		local moves = { move.X, move.Y, move.Z }
		local halves = { part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2 }
		local entry, exit = 0, 1
		for axis = 1, 3 do
			if math.abs(moves[axis]) < 1e-9 then
				if math.abs(starts[axis]) > halves[axis] then
					return false
				end
			else
				local near = (-halves[axis] - starts[axis]) / moves[axis]
				local far = (halves[axis] - starts[axis]) / moves[axis]
				entry = math.max(entry, math.min(near, far))
				exit = math.min(exit, math.max(near, far))
				if entry > exit then
					return false
				end
			end
		end
		return true
	end

	-- How many of the points `ladder` covers, seen from `camera`.
	local function pointsCoveredBy(ladder: Instance, camera: CFrame, points: { Vector3 }): number
		local parts: { BasePart } = {}
		for _, descendant in ladder:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				table.insert(parts, descendant)
			end
		end
		local covered = 0
		for _, point in points do
			local stop = point - (point - camera.Position).Unit * EYE_MARGIN
			for _, part in parts do
				if lineThroughBox(camera.Position, stop, part) then
					covered += 1
					break
				end
			end
		end
		return covered
	end

	it("the cap ladder does not cover his closed eyes from any spawn spot", function()
		local world = realWorld() :: any
		local ladder = world.WalkSurfaces.CapLadder :: Instance
		local problems = {}
		for _, garden in WorldIndex.loadGardens(world) do
			local camera = spawnCameraFor(garden.spawnSpot)
			local seen = seenEyePoints(camera, world)
			if #seen == 0 then
				table.insert(problems, `Plot_{garden.index} sees no point of his eyes, so the check proves nothing`)
			end
			local covered = pointsCoveredBy(ladder, camera, seen)
			if covered > 0 then
				table.insert(
					problems,
					`Plot_{garden.index}: the cap ladder covers {covered} of {#seen} seen points of his closed eyes`
				)
			end
		end
		table.sort(problems)
		expect(problems).toEqual({})
	end)

	it("the eye check notices a copy of the cap ladder moved in front of an eye", function()
		local world = realWorld() :: any
		local garden = WorldIndex.loadGardens(world)[1]
		local camera = spawnCameraFor(garden.spawnSpot)
		local seen = seenEyePoints(camera, world)
		expect(#seen > 0).toBe(true)
		-- the copy is never parented, so it is never in the Workspace; its middle goes 80% of the way to a seen point
		local copy = world.WalkSurfaces.CapLadder:Clone() :: Model
		local middle = copy:GetBoundingBox().Position
		local target = camera.Position:Lerp(seen[1], 0.8)
		copy:PivotTo(copy:GetPivot() + (target - middle))
		local covered = pointsCoveredBy(copy, camera, seen)
		copy:Destroy()
		expect(covered > 0).toBe(true)
	end)

	it("the Z Z Z sit below the sleep meter from every spawn spot, on phones and computers", function()
		local world = realWorld()
		local emitter = (world :: any).GiantFX.SnoreEmitter :: BasePart
		local floatingZ = emitter:FindFirstChild("FloatingZ") :: BillboardGui

		-- The meter grows to 110% at its pulse, downward from its top edge (SleepMeterUi's PULSE_SCALE).
		local PULSE_SCALE = 1.1
		local screens: { [string]: Vector2 } = { phone = Vector2.new(750, 390), computer = Vector2.new(1280, 720) }

		local tooHigh = {}
		for screenName, screen in screens do
			local meter = Layout.forScreen(screen).meter
			local meterBottom = meter.topOffset + meter.height * PULSE_SCALE
			for _, garden in WorldIndex.loadGardens(world) do
				local camera = spawnCameraFor(garden.spawnSpot)
				for _, letter in letterCentres(camera, emitter, floatingZ) do
					-- the letter is drawn facing the camera, so its top edge is half its height up the camera's up
					local top = letter.centre + camera.UpVector * (letter.heightStuds / 2)
					local y = screenYOf(camera, top, screen.Y)
					if y <= meterBottom then
						table.insert(
							tooHigh,
							`Plot_{garden.index} {letter.name} at {string.format("%.1f", y)} px ({screenName})`
						)
					end
				end
			end
		end
		table.sort(tooHigh)
		expect(tooHigh).toEqual({})
	end)

	-- Every place a player can stand on the giant: straight-down rays on a 4-stud grid onto his body and the
	-- walk surfaces, keeping the hits that are more than 8 studs up. Each one is checked 3 studs above the hit.
	local function standableSpots(world: Instance): { Vector3 }
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { (world :: any).Giant, (world :: any).WalkSurfaces }
		local spots = {}
		for x = -60, 60, 4 do
			for z = -75, 70, 4 do
				local hit = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -300, 0), params)
				if hit and hit.Position.Y > 8 then
					table.insert(spots, hit.Position + Vector3.new(0, 3, 0))
				end
			end
		end
		return spots
	end

	it("every place a player can stand on the giant is in a giant zone", function()
		local world, locate = locator()
		local spots = standableSpots(world)
		expect(#spots > 500).toBe(true) -- the grid really found his body
		local misses = {}
		for _, spot in spots do
			if locate(spot).zone == "Meadow" then
				table.insert(misses, string.format("(%d, %d, %d)", spot.X, spot.Y, spot.Z))
			end
		end
		expect({ missed = #misses, ofSpots = #spots }).toEqual({ missed = 0, ofSpots = #spots })
	end)

	it("the meadow around his feet is not in a giant zone", function()
		local world, locate = locator()
		-- a rectangle 5 studs outside the box around his whole body, at ground level (3 studs up for the player's root)
		local box, size = (world :: any).Giant:GetBoundingBox()
		local halfX, halfZ = size.X / 2 + 5, size.Z / 2 + 5
		local terrain = RaycastParams.new()
		terrain.FilterType = Enum.RaycastFilterType.Include
		terrain.FilterDescendantsInstances = { workspace.Terrain }
		local ring: { Vector2 } = {}
		for x = -halfX, halfX, 4 do
			table.insert(ring, Vector2.new(box.X + x, box.Z - halfZ))
			table.insert(ring, Vector2.new(box.X + x, box.Z + halfZ))
		end
		for z = -halfZ, halfZ, 4 do
			table.insert(ring, Vector2.new(box.X - halfX, box.Z + z))
			table.insert(ring, Vector2.new(box.X + halfX, box.Z + z))
		end
		local inAZone = {}
		for _, point in ring do
			local hit = workspace:Raycast(Vector3.new(point.X, 250, point.Y), Vector3.new(0, -300, 0), terrain)
			expect(hit).never.toBeNil()
			local place = locate((hit :: RaycastResult).Position + Vector3.new(0, 3, 0))
			if place.zone ~= "Meadow" or place.garden ~= nil then
				table.insert(inAZone, string.format("(%d, %d)", point.X, point.Y))
			end
		end
		expect(#ring > 60).toBe(true)
		expect(inAZone).toEqual({})
	end)

	it("each part of the giant is in its own zone", function()
		local world, locate = locator()
		local giant = (world :: any).Giant :: Model
		-- the zone each piece of him belongs to (the pieces not listed here, like the hidden eyes, are skipped)
		local zoneOfPiece = {
			legs_and_boots = "Boots",
			body_and_cushion = "Belly",
			left_arm = "Belly",
			right_arm = "Belly",
			head_with_beard = "Beard",
			nightcap = "Nightcap",
		}
		-- the same 4-stud grid as above, but the rays only hit the giant's own pieces
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { giant }
		local total = 0
		local wrong = 0
		local wrongLegs = 0
		local wrongByPiece: { [string]: { [string]: number } } = {}
		for x = -60, 60, 4 do
			for z = -75, 70, 4 do
				local hit = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -300, 0), params)
				if hit and hit.Position.Y > 8 then
					-- which piece of him did the ray hit?
					local piece: Instance = hit.Instance
					while piece.Parent ~= giant and piece.Parent ~= nil do
						piece = piece.Parent
					end
					local expected = (zoneOfPiece :: { [string]: string })[piece.Name]
					if expected then
						total += 1
						local actual = locate(hit.Position + Vector3.new(0, 3, 0)).zone
						if actual ~= expected then
							wrong += 1
							if piece.Name == "legs_and_boots" then
								wrongLegs += 1
							end
							local counts = wrongByPiece[piece.Name] or {}
							counts[actual] = (counts[actual] or 0) + 1
							wrongByPiece[piece.Name] = counts
						end
					end
				end
			end
		end
		expect(total > 500).toBe(true)
		-- small overlaps at the edges between pieces are fine: at most 3% of the points, and at most 5 leg points
		local report = { total = total, wrong = wrong, wrongLegs = wrongLegs, wrongByPiece = wrongByPiece }
		expect(if wrong <= total * 0.03 and wrongLegs <= 5 then "ok" else report).toBe("ok")
	end)

	-- The climb pieces of Task 8 (the right ramp, the belly path, the steep guards) are built by tools/world/03-climb.luau.
	it("the real world passes the climb check", function()
		local climb, problems = WorldIndex.readClimb(realWorld())
		expect(problems).toEqual({})
		expect(climb).never.toBeNil()
	end)

	it("the right boot ramp is in the Boots zone and its foot is on the meadow", function()
		local world, locate = locator()
		local ramp = ((world :: any).WalkSurfaces.RightBootRamp :: Instance):FindFirstChild("Ramp_Walk") :: BasePart
		expect(ramp).never.toBeNil()
		local lowEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, ramp.Size.Z / 2))
		local highEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, -ramp.Size.Z / 2))
		local foot, top = lowEnd, highEnd
		if lowEnd.Y > highEnd.Y then
			foot, top = highEnd, lowEnd
		end
		local up = ramp.CFrame.UpVector * 3.3 -- the top of the planks, then a player's root height
		-- points along the ramp, from just above its foot to its top, are all Boots
		for _, fraction in { 0.1, 0.3, 0.5, 0.7, 0.9, 1 } do
			expect(locate(foot:Lerp(top, fraction) + up).zone).toBe("Boots")
		end
		-- the foot is on the grass (the ground there is Terrain at about height 2; the stream bed is below 0)
		local terrain = RaycastParams.new()
		terrain.FilterType = Enum.RaycastFilterType.Include
		terrain.FilterDescendantsInstances = { workspace.Terrain }
		local ground = workspace:Raycast(Vector3.new(foot.X, 100, foot.Z), Vector3.new(0, -200, 0), terrain)
		expect(ground).never.toBeNil()
		expect((ground :: RaycastResult).Position.Y > 1).toBe(true)
		expect(math.abs((ground :: RaycastResult).Position.Y - foot.Y) < 1).toBe(true)
		-- grass 4 studs beside the foot stays Meadow
		local beside = foot + ramp.CFrame.RightVector * (ramp.Size.X / 2 + 4) + Vector3.new(0, 3, 0)
		expect(locate(beside)).toEqual({ zone = "Meadow", garden = nil })
		-- the ramp is at least 9 studs wide and no steeper than 45 degrees along its length
		expect(ramp.Size.X >= 9).toBe(true)
		local rise = top.Y - foot.Y
		expect(math.deg(math.asin(rise / (top - foot).Magnitude)) <= 45).toBe(true)
	end)

	-- Rule 8 (Steps make noise): the left ramp counts as the giant from just above its foot to its top.
	it("the left boot ramp is in the Boots zone from just above its foot to its top", function()
		local world, locate = locator()
		local ramp = (world :: any).WalkSurfaces.BootRamp.Ramp_Walk :: BasePart
		local lowEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, ramp.Size.Z / 2))
		local highEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, -ramp.Size.Z / 2))
		local foot, top = lowEnd, highEnd
		if lowEnd.Y > highEnd.Y then
			foot, top = highEnd, lowEnd
		end
		local up = ramp.CFrame.UpVector * 3.3 -- the top of the planks, then a player's root height
		for _, fraction in { 0.1, 0.3, 0.5, 0.7, 0.9, 1 } do
			local zone = locate(foot:Lerp(top, fraction) + up).zone
			expect({ fraction = fraction, zone = zone }).toEqual({ fraction = fraction, zone = "Boots" })
		end
	end)

	-- Stuck safety Task 24, Ruling 5: a player standing on a crossing ramp is in the Boots zone, as on V1's path there
	-- (the ankle ramp, the knee ramp and the steep-band ramp all stand on his left leg below Rare egg 1).
	it("a player standing on each crossing ramp is in the Boots zone", function()
		local Workspace = game:GetService("Workspace")
		local world, locate = locator()
		local walk = (world :: any).WalkSurfaces :: Instance
		local found: { string } = {}
		for _, rampName in { "CrossingRamp_Ankle", "CrossingRamp_Knee" } do
			local ramp = walk:FindFirstChild(rampName)
			expect({ ramp = rampName, exists = ramp ~= nil }).toEqual({ ramp = rampName, exists = true })
		end
		local wrong: { string } = {}
		for _, ramp in walk:GetChildren() do
			if ramp:IsA("BasePart") and string.match(ramp.Name, "^CrossingRamp_") then
				table.insert(found, ramp.Name)
				-- the middle of its top, then a player's root height above it
				local params = RaycastParams.new()
				params.IncludeInstances = { ramp }
				params.RespectCanCollide = false
				local top = Workspace:Raycast(ramp.Position + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), params)
				expect({ ramp = ramp.Name, topFound = top ~= nil }).toEqual({ ramp = ramp.Name, topFound = true })
				local zone = locate((top :: RaycastResult).Position + Vector3.new(0, 3, 0)).zone
				if zone ~= "Boots" then
					table.insert(wrong, `{ramp.Name}: {zone}`)
				end
			end
		end
		expect(wrong).toEqual({})
		expect(#found >= 2).toBe(true)
	end)

	-- Check B3 (fair for every garden): the walk from a garden to the ramp's foot must be silent. A zone box over a
	-- meadow path would make one garden's walk louder than another's. The first place along a link that is not in
	-- the Meadow zone is reported (a garden counts as Meadow here, because a garden always reports the Meadow).
	it("every meadow route link stays in the Meadow", function()
		local world, locate = locator()
		local points, problems = WorldIndex.readRoute(world)
		expect(problems).toEqual({})
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in points :: { WorldIndex.RoutePoint } do
			byName[point.name] = point
		end
		local up = Vector3.new(0, 3, 0) -- a player's root is about 3 studs above their feet
		local checked: { [string]: boolean } = {}
		local linksChecked = 0
		local bad: { string } = {}
		for _, point in points :: { WorldIndex.RoutePoint } do
			for _, neighbourName in point.neighbours do
				local neighbour = byName[neighbourName]
				local first, second = point.name, neighbourName
				if second < first then
					first, second = second, first
				end
				local key = `{first} - {second}`
				if neighbour == nil or checked[key] then
					continue
				end
				checked[key] = true
				if locate(point.position + up).zone ~= "Meadow" or locate(neighbour.position + up).zone ~= "Meadow" then
					continue -- a link that starts or ends on the giant is not a meadow link
				end
				linksChecked += 1
				local length = (neighbour.position - point.position).Magnitude
				local steps = math.ceil(length)
				for step = 0, steps do
					local place = point.position:Lerp(neighbour.position, step / steps) + up
					local zone = locate(place).zone
					if zone ~= "Meadow" then
						table.insert(bad, `{key}: {zone} at {step / steps * length} studs of {length}`)
						break
					end
				end
			end
		end
		expect(linksChecked > 20).toBe(true)
		expect(bad).toEqual({})
	end)

	-- How steep a part's top face is, in degrees from flat.
	local function slopeOf(part: BasePart): number
		return math.deg(math.acos(math.clamp(math.abs(part.CFrame.UpVector.Y), 0, 1)))
	end

	-- The count that tools/world/15-real-shape.luau section 2 reported it leaves (2026-10-20): the step piece (Boots_Walk 1),
	-- CrossingRamp_Ankle and CrossingRamp_Knee, the 2 ramp planks, Nose_Walk 1 and Nightcap_Walk 3 (9 in all).
	-- Stuck safety Task 25 (plan section 2b of tools/world/15-real-shape.luau) took away 4 of them: Nose_Walk and the 3
	-- Nightcap_Walk pieces. The 5 left are the 2 ramp planks (Ramp_Walk), the step piece (Boots_Walk 1), CrossingRamp_Ankle
	-- and CrossingRamp_Knee.
	local ROUTE_SURFACE_COUNT = 5

	it("no walk surface on the route is steeper than 60 degrees", function()
		local walk = (realWorld() :: any).WalkSurfaces :: Instance
		-- the two ramps, and every piece named *_Walk (the ladders, trusses and guards are not walked on)
		local surfaces: { BasePart } = {}
		for _, rampName in { "BootRamp", "RightBootRamp" } do
			local ramp = walk:FindFirstChild(rampName)
			local planks = if ramp then ramp:FindFirstChild("Ramp_Walk") else nil
			expect(planks).never.toBeNil()
			table.insert(surfaces, planks :: BasePart)
		end
		for _, piece in walk:GetChildren() do
			if
				piece:IsA("BasePart")
				and (string.match(piece.Name, "_Walk$") or string.match(piece.Name, "^CrossingRamp_"))
			then
				table.insert(surfaces, piece)
			end
		end
		-- The exact number of walk surfaces, so the test still fails if one goes missing (stuck safety Task 24, Ruling 5).
		-- Before Task 24 it was 39: the 2 ramp planks, 33 legs and belly pieces (Boots_Walk 8, RightBoots_Walk 8,
		-- Belly_Walk 17), Nose_Walk 1 and Nightcap_Walk 3. Task 24 made it the number its world script reports; Task 25
		-- changes it again for the head.
		expect(#surfaces).toBe(ROUTE_SURFACE_COUNT)
		local tooSteep = {}
		for _, surface in surfaces do
			if slopeOf(surface) > 60 then
				table.insert(
					tooSteep,
					string.format(
						"%s at (%.0f, %.0f, %.0f): %.0f degrees",
						surface.Name,
						surface.Position.X,
						surface.Position.Y,
						surface.Position.Z,
						slopeOf(surface)
					)
				)
			end
		end
		table.sort(tooSteep)
		expect(tooSteep).toEqual({})
	end)

	it("every steep guard is steeper than 75 degrees", function()
		local guards = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("SteepGuards")
		expect(guards).never.toBeNil()
		local slabs = (guards :: Instance):GetChildren()
		expect(#slabs >= 20).toBe(true) -- face, beard front, both cap sides, both boot fronts
		local wrong = {}
		for _, slab in slabs do
			local part = slab :: BasePart
			local solidAndInvisible = part:IsA("BasePart")
				and part.Transparency == 1
				and part.CanCollide
				and part.Anchored
			if not solidAndInvisible or slopeOf(part) <= 75 then
				table.insert(
					wrong,
					string.format(
						"%s at (%.0f, %.0f, %.0f)",
						part.Name,
						part.Position.X,
						part.Position.Y,
						part.Position.Z
					)
				)
			end
		end
		expect(wrong).toEqual({})
	end)

	-- Stuck safety Task 25 (game_creator's yes): V1's invisible middle forehead slab goes. The visible cap ladder is the
	-- only way from his nose to his cap. The four side walls (|x| over 7) stay.
	it("the middle forehead slab is gone", function()
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local middle = {}
		for _, child in (guard :: Instance):GetChildren() do
			if child:IsA("BasePart") and child.Name == "Guard" and math.abs(child.Position.X) < 7 then
				table.insert(middle, string.format("Guard at x %.1f, size x %.1f", child.Position.X, child.Size.X))
			end
		end
		expect(middle).toEqual({})
	end)

	it("the forehead slabs beside the cap ladder are steeper than 75 degrees", function()
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local slabs = (guard :: Instance):GetChildren()
		expect(#slabs >= 5).toBe(true)
		local wrong = {}
		local beside = 0
		for _, slab in slabs do
			local part = slab :: BasePart
			-- only the four side walls count: the middle slab is gone (stuck safety Task 25, game_creator's yes), and
			-- the side rails are upright rails, not slabs
			if part:IsA("BasePart") and part.Name == "Guard" and math.abs(part.Position.X) > 7 then
				beside += 1
				local solidAndInvisible = part.Transparency == 1 and part.CanCollide and part.Anchored
				if not solidAndInvisible or slopeOf(part) <= 75 then
					table.insert(
						wrong,
						string.format("%s at x %.0f: %.1f degrees", part.Name, part.Position.X, slopeOf(part))
					)
				end
			end
		end
		expect(beside >= 4).toBe(true)
		expect(wrong).toEqual({})
	end)

	-- The invisible side rails close both sides of the open top of his nose, and run beside the cap ladder, so nobody can
	-- step off the nose onto the ledge and into the slot between the forehead walls and his cheeks. V1's pair was built
	-- by tools/world/03b-forehead.luau; stuck safety Task 25 (tools/world/15-real-shape.luau section 2b) replaces it
	-- with up to two parts per side.
	local function sideRails(): { BasePart }
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local rails: { BasePart } = {}
		for _, child in (guard :: Instance):GetChildren() do
			if child.Name == "SideRail" and child:IsA("BasePart") then
				table.insert(rails, child)
			end
		end
		table.sort(rails, function(a, b)
			return a.Position.X < b.Position.X
		end)
		return rails
	end

	-- The open top of his nose, row by row (stuck safety Task 25, test 7). Source: measured read-only in step 2b-3 on
	-- 2026-10-20, with rays that see only his six body pieces. `middle` is the height of his skin at x 0. `right` and
	-- `left` are the walkable half-width on each side, read sideways (plan Task 25, Ruling 1): going out from x 0, the
	-- first place where the sideways tilt of the body-size plane (25 rays on a 4 by 4 stud square) reaches 65 degrees,
	-- or where the skin steps more than 0.5 studs. At z -4.5 there is no edge out to 14 studs, so the row records 3.6,
	-- the inner face of the cap part of the rails.
	type NoseRow = { z: number, middle: number, right: number, left: number }
	local NOSE_ROWS: { NoseRow } = {
		{ z = -12.5, middle = 92.04, right = 2.6, left = 2.9 },
		{ z = -11.5, middle = 93.11, right = 3.5, left = 3.4 },
		{ z = -10.5, middle = 93.79, right = 3.5, left = 3.4 },
		{ z = -9.5, middle = 94.08, right = 3.8, left = 3.7 },
		{ z = -8.5, middle = 94.24, right = 4.5, left = 4.4 },
		{ z = -7.5, middle = 94.17, right = 4.8, left = 5.7 },
		{ z = -6.5, middle = 94.05, right = 5.7, left = 5.7 },
		{ z = -5.5, middle = 93.84, right = 5.7, left = 5.4 },
		{ z = -4.5, middle = 93.35, right = 3.6, left = 3.6 },
	}
	local RAIL_PAST_EDGE = 1.0 -- studs: a rail's inner face is at most this far past the row's walkable edge
	local RAIL_HEIGHTS = { 0.5, 3, 8 } -- studs over his skin at x 0: where the sideways rays go
	local RAIL_REACH = 14 -- studs: how far a sideways ray looks for a rail
	local RAIL_GAP_ALLOWED = 0.2 -- studs: his skin may be this far under a rail's bottom (Ruling 10)
	local RAIL_SKIN_RAY_ABOVE = 30
	local RAIL_SLOT_STEP = 0.25 -- studs between the places a slot is looked for
	local RAIL_MAX_PARTS_PER_SIDE = 2
	local WALL_MIN_DEGREES = 75
	local MAX_PROBLEM_LINES = 8

	-- A ray that sees only his six body pieces.
	local function bodyRayParams(): RaycastParams
		local giant = (realWorld() :: any).Giant :: Instance
		local meshes: { Instance } = {}
		for _, name in BODY_PIECES do
			table.insert(meshes, (giant:FindFirstChild(name) :: Instance):FindFirstChild(name) :: Instance)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = meshes
		params.RespectCanCollide = false
		return params
	end

	-- A ray that sees only the side rails.
	local function railParams(rails: { BasePart }): RaycastParams
		local instances: { Instance } = {}
		for _, rail in rails do
			table.insert(instances, rail)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = instances
		params.RespectCanCollide = false
		return params
	end

	-- A sideways ray from the middle of a row, `over` studs over his skin, that sees only the side rails.
	local function railHit(rails: { BasePart }, row: NoseRow, side: number, over: number): RaycastResult?
		local params = railParams(rails)
		return game:GetService("Workspace")
			:Raycast(Vector3.new(0, row.middle + over, row.z), Vector3.new(side * RAIL_REACH, 0, 0), params)
	end

	local function wallDegrees(normal: Vector3): number
		return math.deg(math.acos(math.clamp(math.abs(normal.Y), 0, 1)))
	end

	local function firstLines(lines: { string }): { count: number, first: { string } }
		local first: { string } = {}
		for index = 1, math.min(#lines, MAX_PROBLEM_LINES) do
			table.insert(first, lines[index])
		end
		return { count = #lines, first = first }
	end

	-- Rule 20 (One collision source): the rails are not a shelf. At each row, a ray straight down from 30 studs above,
	-- at the rail's bottom inner edge and its bottom outer edge, finds his skin no lower than 0.2 studs under the
	-- rail's bottom (Ruling 10: a ray that starts inside his mesh can't hit it, so the old ray up from inside missed).
	local function railGapProblems(skinParams: RaycastParams, hit: RaycastResult, label: string): { string }
		local problems: { string } = {}
		local rail = hit.Instance :: BasePart
		local bottom = rail.Position.Y - rail.Size.Y / 2
		local inner = Vector3.new(hit.Position.X, bottom, hit.Position.Z)
		local localNormal = rail.CFrame:VectorToObjectSpace(hit.Normal)
		local thickness = math.abs(localNormal.X) * rail.Size.X
			+ math.abs(localNormal.Y) * rail.Size.Y
			+ math.abs(localNormal.Z) * rail.Size.Z
		local outer = inner + Vector3.new(-hit.Normal.X, 0, -hit.Normal.Z).Unit * thickness
		local edges: { { name: string, point: Vector3 } } = {
			{ name = "inner", point = inner },
			{ name = "outer", point = outer },
		}
		for _, edge in edges do
			local edgeName, point = edge.name, edge.point
			local skin = game:GetService("Workspace"):Raycast(
				point + Vector3.new(0, RAIL_SKIN_RAY_ABOVE, 0),
				Vector3.new(0, -2 * RAIL_SKIN_RAY_ABOVE, 0),
				skinParams
			)
			if skin == nil then
				table.insert(problems, `{label}: no skin under the rail's bottom {edgeName} edge`)
			elseif skin.Position.Y < bottom - RAIL_GAP_ALLOWED then
				table.insert(
					problems,
					string.format(
						"%s: his skin is %.2f studs under the rail's bottom %s edge (gap allowed %.1f)",
						label,
						bottom - skin.Position.Y,
						edgeName,
						RAIL_GAP_ALLOWED
					)
				)
			end
		end
		return problems
	end

	-- No slot: between the row's walkable edge and the rail's inner face, no place where a standing body fits (the shared
	-- walk check's own test, with the rails in the world).
	local function railSlotProblems(
		options: PathCheck.Options,
		skinParams: RaycastParams,
		row: NoseRow,
		side: number,
		edge: number,
		railX: number,
		label: string
	): { string }
		local problems: { string } = {}
		local limit = math.cos(math.rad(game:GetService("StarterPlayer").CharacterMaxSlopeAngle))
		local x = edge
		while x < railX - 0.01 do
			local skin = game:GetService("Workspace")
				:Raycast(Vector3.new(side * x, 200, row.z), Vector3.new(0, -250, 0), skinParams)
			if
				skin ~= nil
				and skin.Normal.Y >= limit
				and skin.Material ~= Enum.Material.Water
				and PathCheck.roomToStand(options, skin.Position, skin.Normal)
			then
				table.insert(
					problems,
					string.format("%s: a body fits at x %.2f between the edge and the rail", label, side * x)
				)
				break
			end
			x += RAIL_SLOT_STEP
		end
		return problems
	end

	it("smooth side rails close both sides of the nose top", function()
		local rails = sideRails()
		local problems: { string } = {}
		local counts = { left = 0, right = 0 }
		for _, rail in rails do
			local name =
				string.format("SideRail at (%.1f, %.1f, %.1f)", rail.Position.X, rail.Position.Y, rail.Position.Z)
			if rail.Position.X < 0 then
				counts.left += 1
			else
				counts.right += 1
			end
			if rail.Transparency ~= 1 or not rail.CanCollide or not rail.Anchored then
				table.insert(problems, `{name} is not invisible, solid and anchored`)
			end
			if rail.Material ~= Enum.Material.SmoothPlastic then
				table.insert(problems, `{name} is not smooth (SmoothPlastic)`)
			end
		end
		if counts.left < 1 or counts.left > RAIL_MAX_PARTS_PER_SIDE then
			table.insert(problems, `{counts.left} rail parts on his left (1 to {RAIL_MAX_PARTS_PER_SIDE} allowed)`)
		end
		if counts.right < 1 or counts.right > RAIL_MAX_PARTS_PER_SIDE then
			table.insert(problems, `{counts.right} rail parts on his right (1 to {RAIL_MAX_PARTS_PER_SIDE} allowed)`)
		end

		-- At every row, from the middle: sideways rays at 0.5, 3 and 8 studs over his skin hit a rail (steeper than 75
		-- degrees) no more than 1.0 stud past the row's walkable edge; no gap under it; no slot beside it.
		local skinParams = bodyRayParams()
		local options = PathCheck.defaults(game:GetService("Workspace"))
		local ok, message = pcall(function()
			for _, row in NOSE_ROWS do
				for _, side in { -1, 1 } do
					local edge = if side < 0 then row.left else row.right
					local label = string.format("row z %.1f, %s", row.z, if side < 0 then "left" else "right")
					for _, over in RAIL_HEIGHTS do
						local hit = railHit(rails, row, side, over)
						if hit == nil then
							table.insert(problems, `{label}: no rail {over} studs over his skin`)
						else
							local face = math.abs(hit.Position.X)
							if face > edge + RAIL_PAST_EDGE then
								table.insert(
									problems,
									string.format(
										"%s: the rail at %g studs over his skin is %.2f studs past the edge (%.1f), at most %.1f",
										label,
										over,
										face - edge,
										edge,
										RAIL_PAST_EDGE
									)
								)
							end
							if wallDegrees(hit.Normal) <= WALL_MIN_DEGREES then
								table.insert(
									problems,
									string.format(
										"%s: the rail face is %.1f degrees steep, needs over %d",
										label,
										wallDegrees(hit.Normal),
										WALL_MIN_DEGREES
									)
								)
							end
						end
					end
					local low = railHit(rails, row, side, RAIL_HEIGHTS[1])
					if low ~= nil then
						for _, line in railGapProblems(skinParams, low, label) do
							table.insert(problems, line)
						end
						for _, line in
							railSlotProblems(options, skinParams, row, side, edge, math.abs(low.Position.X), label)
						do
							table.insert(problems, line)
						end
					end
				end
			end
		end)
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		if not ok then
			error(message)
		end
		expect(firstLines(problems)).toEqual({ count = 0, first = {} })
	end)

	-- Proof that the gap and slot checks can fail. A test rail (invisible, Archivable off, destroyed in the test, like the
	-- body probe) beside row z -9.5 whose bottom is 1 stud over his skin has a gap under it, and one whose bottom is 25
	-- studs inside him has none. A slot is found on the nose top at z -8.5 when the rail is 3 studs out and the edge is
	-- taken as 0.5, and none when the rail stands at the edge.
	it("the rail checks notice a gap under a rail and a slot beside it", function()
		local row = NOSE_ROWS[4]
		local skinParams = bodyRayParams()
		local options = PathCheck.defaults(game:GetService("Workspace"))
		local rail = Instance.new("Part")
		rail.Name = "SideRailGapTestRail"
		rail.Size = Vector3.new(1.5, 40, 4)
		rail.Anchored = true
		rail.Transparency = 1
		rail.Archivable = false
		local raised: { string } = {}
		local sunk: { string } = {}
		local slotFound: { string } = {}
		local slotNone: { string } = {}
		local ok, message = pcall(function()
			local function problemsFor(bottom: number): { string }
				rail.CFrame = CFrame.new(5, bottom + 20, row.z)
				rail.Parent = game:GetService("Workspace")
				local hit = railHit({ rail }, row, 1, 3)
				if hit == nil then
					return { "the test rail was not hit" }
				end
				return railGapProblems(skinParams, hit, "test")
			end
			raised = problemsFor(row.middle + 1)
			sunk = problemsFor(row.middle - 25)
			local flatRow = NOSE_ROWS[5]
			slotFound = railSlotProblems(options, skinParams, flatRow, 1, 0.5, 3.0, "test")
			slotNone = railSlotProblems(options, skinParams, flatRow, 1, flatRow.right, flatRow.right, "test")
		end)
		rail:Destroy()
		PathCheck.cleanup(options)
		if not ok then
			error(message)
		end
		expect(#raised > 0).toBe(true)
		expect(sunk).toEqual({})
		expect(#slotFound).toBe(1)
		expect(slotNone).toEqual({})
	end)

	it("the side rails run along both sides of the cap ladder", function()
		local rails = sideRails()
		local ladder = (realWorld() :: any).WalkSurfaces.CapLadder :: Instance
		local rungs: { BasePart } = {}
		for _, part in ladder:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Rung" then
				table.insert(rungs, part)
			end
		end
		expect(#rungs > 2).toBe(true)
		table.sort(rungs, function(a, b)
			return a.Position.Y < b.Position.Y
		end)
		-- up the ladder, and "out" from it: the direction a climber's body is from the rungs (toward his front)
		local up = (rungs[#rungs].Position - rungs[1].Position).Unit
		local out = Vector3.new(0, up.Z, -up.Y)
		local params = railParams(rails)
		-- at every rung, sideways rays from the rung's end, 1 and 3 studs out from the ladder, each hit a rail within 4.5
		-- studs: a climber can only go up or down, never step off the ladder's side
		local open = {}
		for _, rung in rungs do
			for _, side in { -1, 1 } do
				for _, distance in { 1, 3 } do
					local start = rung.Position + Vector3.new(side * rung.Size.X / 2, 0, 0) + out * distance
					local hit = game:GetService("Workspace"):Raycast(start, Vector3.new(side * 4.5, 0, 0), params)
					if hit == nil then
						table.insert(
							open,
							string.format(
								"no rail beside the rung at (%.1f, %.1f, %.1f), side %d, %d studs out",
								rung.Position.X,
								rung.Position.Y,
								rung.Position.Z,
								side,
								distance
							)
						)
					end
				end
			end
		end
		expect(firstLines(open)).toEqual({ count = 0, first = {} })
	end)

	it("no wall sticks out in front of the edges of the middle forehead slab", function()
		-- Where a side wall started inside the middle slab's width, it stood in front of the slab's surface and made
		-- a step that a player walking up the slab could wedge against. The walls must start where the slab ends.
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		-- Task 25: the middle slab is gone, so its half width is the fixed number the walls were built against:
		-- MIDDLE_HALF_WIDTH in tools/world/03b-forehead.luau (the slab was 13.5 wide).
		local middleHalfWidth = 6.75
		local inside = {}
		for _, child in (guard :: Instance):GetChildren() do
			if child:IsA("BasePart") and child.Name == "Guard" and math.abs(child.Position.X) > 7 then
				local innerEdge = math.abs(child.Position.X) - child.Size.X / 2
				if innerEdge < middleHalfWidth - 0.05 then
					table.insert(
						inside,
						string.format("%s at x %.1f starts at %.2f", child.Name, child.Position.X, innerEdge)
					)
				end
			end
		end
		expect(inside).toEqual({})
	end)

	it("a player on the nose top cannot walk off its sides", function()
		-- Rays go sideways from just beside the cap ladder, at every row of the open top of his nose (NOSE_ROWS) and from
		-- 1 to 11 studs over it. A see-through part (the ladder's rails, the invisible eyes) is not a wall, so the ray
		-- looks past it. The first wall must be no more than 1.0 stud past the row's walkable edge.
		local open = {}
		for _, row in NOSE_ROWS do
			for _, direction in { -1, 1 } do
				local edge = if direction < 0 then row.left else row.right
				local z = row.z
				for y = row.middle + 1, row.middle + 11, 2 do
					local ignore: { Instance } = {}
					local wallAt: number? = nil
					for _ = 1, 20 do
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = ignore
						local hit = workspace:Raycast(
							Vector3.new(direction * 3, y, z),
							Vector3.new(direction * 12, 0, 0),
							params
						)
						if hit == nil then
							break
						end
						if hit.Instance.CanCollide then
							wallAt = hit.Position.X
							break
						end
						table.insert(ignore, hit.Instance)
					end
					if wallAt == nil or math.abs(wallAt) > edge + RAIL_PAST_EDGE then
						table.insert(open, string.format("side %d at (z %.1f, y %.1f)", direction, z, y))
					end
				end
			end
		end
		expect(firstLines(open)).toEqual({ count = 0, first = {} })
	end)

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

	it("the slope limit is 70", function()
		-- set in default.project.json: Roblox's own limit is 89, which lets players walk up almost anything
		expect(game:GetService("StarterPlayer").CharacterMaxSlopeAngle).toBe(70)
	end)

	it("phone auto-jump is off", function()
		-- set in default.project.json: an automatic hop on the giant thuds and can wake him
		expect(game:GetService("StarterPlayer").AutoJumpEnabled).toBe(false)
	end)

	it("the 7 props behind the landing spots are out of the meadow (designer's clear view)", function()
		-- The bounce camera sat inside these props (style guide, "Clear view behind each landing spot"). The middle is
		-- the middle of the model's bounding box, x and z. tools/world/10-clear-landing-views.luau moves them.
		local removedProps: { { name: string, x: number, z: number } } = {
			{ name = "Nature_Sunflower", x = 51.7, z = -96.9 },
			{ name = "Nature_Sunflower", x = -50.3, z = -70.7 },
			{ name = "Nature_Sunflower", x = -52.9, z = -62.4 },
			{ name = "Nature_Sunflower", x = -60.2, z = -59.0 },
			{ name = "Nature_Sunflower", x = 47.7, z = -72.0 },
			{ name = "Inno_White_Flowers", x = -56.6, z = -62.9 },
			{ name = "Inno_Yellow_Flowers", x = 52.6, z = -59.8 },
		}
		local nature = (realWorld() :: any).Nature :: Instance
		local artLibrary = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		local removedNature = if artLibrary then artLibrary:FindFirstChild("RemovedNature") else nil
		expect(nature).never.toBeNil()
		expect(removedNature).never.toBeNil()

		local function countAt(folder: Instance, entry: { name: string, x: number, z: number }): number
			local count = 0
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child.Name == entry.name then
					local middle = child:GetBoundingBox().Position
					if (Vector3.new(middle.X, 0, middle.Z) - Vector3.new(entry.x, 0, entry.z)).Magnitude <= 0.5 then
						count += 1
					end
				end
			end
			return count
		end

		local found = {}
		local expected = {}
		for _, entry in removedProps do
			local label = string.format("%s at (%.1f, %.1f)", entry.name, entry.x, entry.z)
			table.insert(found, {
				prop = label,
				inMeadow = countAt(nature, entry),
				inRemovedNature = countAt(removedNature :: Instance, entry),
			})
			table.insert(expected, { prop = label, inMeadow = 0, inRemovedNature = 1 })
		end
		-- Nothing else was taken away.
		local left: { [string]: number } = { Nature_Sunflower = 0, Inno_White_Flowers = 0, Inno_Yellow_Flowers = 0 }
		for _, child in nature:GetChildren() do
			if child:IsA("Model") and left[child.Name] ~= nil then
				left[child.Name] += 1
			end
		end
		expect({ props = found, left = left }).toEqual({
			props = expected,
			left = { Nature_Sunflower = 23, Inno_White_Flowers = 21, Inno_Yellow_Flowers = 24 },
		})
	end)
end)

-- The egg spots and the egg models (Task 16). They are built by tools/world/04-egg-spots.luau. These tests only READ
-- the real world and the real ServerStorage; they change nothing.
describe("the real world, egg spots", function()
	local Workspace = game:GetService("Workspace")
	local ServerStorage = game:GetService("ServerStorage")

	local function realWorld(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

	local function loadSpots(): { WorldIndex.EggSpot }
		local spots, problems = WorldIndex.readEggSpots(realWorld())
		expect(problems).toEqual({})
		return spots :: { WorldIndex.EggSpot }
	end

	local function loadGardens(): { WorldIndex.Garden }
		local gardens, problems = WorldIndex.readGardens(realWorld())
		expect(problems).toEqual({})
		return gardens :: { WorldIndex.Garden }
	end

	-- Where a point is, using the real zone boxes and the real garden boxes.
	local function locate(point: Vector3): Zones.Place
		local world = realWorld()
		local zoneBoxes, zoneProblems = WorldIndex.readZones(world)
		expect(zoneProblems).toEqual({})
		local gardenBoxes: { Zones.GardenBox } = {}
		for _, garden in loadGardens() do
			table.insert(gardenBoxes, { index = garden.index, cframe = garden.box.cframe, size = garden.box.size })
		end
		return Zones.locate(point, zoneBoxes :: { Zones.ZoneBox }, gardenBoxes)
	end

	local function ofRarity(spots: { WorldIndex.EggSpot }, rarity: string): { WorldIndex.EggSpot }
		local found = {}
		for _, spot in spots do
			if spot.rarity == rarity then
				table.insert(found, spot)
			end
		end
		return found
	end

	it("the real world has 8, 4 and 4 egg spots, each in its zone", function()
		local spots = loadSpots()
		expect({
			Common = #ofRarity(spots, "Common"),
			Uncommon = #ofRarity(spots, "Uncommon"),
			Rare = #ofRarity(spots, "Rare"),
		}).toEqual({ Common = 8, Uncommon = 4, Rare = 4 })
		local zoneOf = { Common = "Meadow", Uncommon = "Boots", Rare = "Belly" }
		for _, spot in spots do
			-- the top of the Base (where the egg sits), and the middle of the Base, are both in the spot's zone
			local base = spot.model:FindFirstChild("Base") :: BasePart
			for _, point in { spot.cframe.Position, base.Position } do
				local place = locate(point)
				-- Common spots are in the meadow and in no garden; the others are in no garden either
				expect({ spot = spot.name, zone = place.zone, garden = place.garden }).toEqual({
					spot = spot.name,
					zone = zoneOf[spot.rarity],
					garden = nil,
				})
			end
		end
	end)

	it("no two egg spots are closer than 6 studs", function()
		local spots = loadSpots()
		local tooClose = {}
		for first = 1, #spots do
			for second = first + 1, #spots do
				local distance = (spots[first].cframe.Position - spots[second].cframe.Position).Magnitude
				if distance < 6 then
					table.insert(tooClose, `{spots[first].name} and {spots[second].name}: {distance}`)
				end
			end
		end
		expect(tooClose).toEqual({})
	end)

	-- The designer and product approved these 16 places (x, z) after playing with eggs on them. A spot that drifts
	-- or is moved by mistake fails here. Change this table only when both approve a new place.
	it("every egg spot is at its approved place", function()
		local approved: { [string]: { number } } = {
			EggSpot_Common_1 = { -94, 1 },
			EggSpot_Common_2 = { -88, -32 },
			EggSpot_Common_3 = { -54, -86 },
			EggSpot_Common_4 = { -36, -85 },
			EggSpot_Common_5 = { 36, -85 },
			EggSpot_Common_6 = { 59, -73 },
			EggSpot_Common_7 = { 88, -32 },
			EggSpot_Common_8 = { 93, 12 },
			EggSpot_Uncommon_1 = { -26, -62.5 },
			EggSpot_Uncommon_2 = { -19.5, -62 }, -- moved in stuck safety Task 24 from (-21.5, -55.5), with all three owners' yes
			EggSpot_Uncommon_3 = { 26, -61.5 },
			EggSpot_Uncommon_4 = { 19.5, -62 }, -- moved in stuck safety Task 24 from (21.5, -55), with all three owners' yes
			EggSpot_Rare_1 = { -12.5, -40.3 },
			EggSpot_Rare_2 = { -11.2, -34.8 },
			EggSpot_Rare_3 = { -8.1, -30.7 },
			EggSpot_Rare_4 = { 2.5, -30.5 }, -- moved in stuck safety Task 25 from (2.5, -29.5), clear of the longer beard rail, with game_creator's and designer's yes
		}
		local spots = loadSpots()
		expect(#spots).toBe(16)
		local off = {}
		for _, spot in spots do
			local place = approved[spot.name]
			if place == nil then
				table.insert(off, `{spot.name} is not in the approved list`)
				continue
			end
			local top = spot.cframe.Position
			local miss = (Vector2.new(top.X, top.Z) - Vector2.new(place[1], place[2])).Magnitude
			if miss > 0.5 then
				table.insert(off, `{spot.name} is at ({top.X}, {top.Z}), approved ({place[1]}, {place[2]})`)
			end
		end
		expect(off).toEqual({})
	end)

	local SKIN_REACH = 0.3 -- studs: a spot's Base top may be this far from his skin (the egg spot test's own limit)
	-- A ray that sees only his six body pieces.
	local function bodyParams(): RaycastParams
		local giant = (realWorld() :: any).Giant :: Instance
		local meshes: { Instance } = {}
		for _, name in BODY_PIECES do
			table.insert(meshes, (giant:FindFirstChild(name) :: Instance):FindFirstChild(name) :: Instance)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = meshes
		params.RespectCanCollide = false
		return params
	end

	-- Stuck safety Task 24 (game_creator's condition): the two Uncommon eggs that moved stand on the flat top of the SAME
	-- boot as before: egg 2 on the left boot, egg 4 on the right. The flat top is the part above the 1 stud step in the boot
	-- top, from the toe to the step. Measured in Studio on 2026-10-20 (the boot top's skin is level there to within 1.5
	-- studs; the step is at z -60.4, the toe's front edge at z -68, x where the skin is above y 29).
	type Outline = { minX: number, maxX: number, minZ: number, maxZ: number }
	local LEFT_BOOT_TOP: Outline = { minX = -30, maxX = -16, minZ = -68, maxZ = -60.4 }
	local RIGHT_BOOT_TOP: Outline = { minX = 16, maxX = 30, minZ = -68, maxZ = -60.4 }
	local EGG_BOOT_INSET = 1.5 -- studs: a moved egg is at least this far in from every edge of its boot top

	local function standsInside(outline: Outline, x: number, z: number, inset: number): boolean
		return x >= outline.minX + inset
			and x <= outline.maxX - inset
			and z >= outline.minZ + inset
			and z <= outline.maxZ - inset
	end

	it("a moved egg spot stays on the same part of him: Uncommon egg 2 and 4 each on their own boot top", function()
		local byName: { [string]: WorldIndex.EggSpot } = {}
		for _, spot in loadSpots() do
			byName[spot.name] = spot
		end
		local egg2 = byName.EggSpot_Uncommon_2.cframe.Position
		local egg4 = byName.EggSpot_Uncommon_4.cframe.Position
		expect({
			egg2OnLeftBoot = standsInside(LEFT_BOOT_TOP, egg2.X, egg2.Z, EGG_BOOT_INSET),
			egg4OnRightBoot = standsInside(RIGHT_BOOT_TOP, egg4.X, egg4.Z, EGG_BOOT_INSET),
		}).toEqual({ egg2OnLeftBoot = true, egg4OnRightBoot = true })
	end)

	-- Proof that the test above can fail: an egg moved to the other boot is not on this boot's top.
	it("tells one boot top from the other", function()
		expect(standsInside(LEFT_BOOT_TOP, -19.5, -62, EGG_BOOT_INSET)).toBe(true)
		expect(standsInside(LEFT_BOOT_TOP, 19.5, -62, EGG_BOOT_INSET)).toBe(false) -- egg 2 moved to the right boot
		expect(standsInside(RIGHT_BOOT_TOP, -19.5, -62, EGG_BOOT_INSET)).toBe(false) -- egg 4 moved to the left boot
		expect(standsInside(LEFT_BOOT_TOP, -21.5, -55.5, EGG_BOOT_INSET)).toBe(false) -- egg 2's old place, on the boot's edge
	end)

	-- designer: each moved egg touches the boot top: its Base top is at most 0.2 studs over his skin and sinks into it at
	-- most 0.3 studs.
	it("the two moved Uncommon eggs touch the boot top", function()
		local byName: { [string]: WorldIndex.EggSpot } = {}
		for _, spot in loadSpots() do
			byName[spot.name] = spot
		end
		local params = bodyParams()
		for _, name in { "EggSpot_Uncommon_2", "EggSpot_Uncommon_4" } do
			local top = byName[name].cframe.Position
			local hit = Workspace:Raycast(top + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
			expect({ spot = name, skinFound = hit ~= nil }).toEqual({ spot = name, skinFound = true })
			local gap = top.Y - (hit :: RaycastResult).Position.Y
			expect({ spot = name, touches = gap <= 0.2 and gap >= -0.3 }).toEqual({ spot = name, touches = true })
		end
	end)

	it("each garden has its own Common egg near its spawn spot", function()
		local commons = ofRarity(loadSpots(), "Common")
		local gardens = loadGardens()
		local world = realWorld()
		local nearestName: { [string]: number } = {}
		for _, garden in gardens do
			local spawn = garden.spawnSpot.Position
			local nearest: WorldIndex.EggSpot? = nil
			local nearestDistance = math.huge
			for _, spot in commons do
				local distance = (spot.cframe.Position - spawn).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = spot, distance
				end
			end
			local spot = nearest :: WorldIndex.EggSpot
			-- a few seconds' walk: between 15 and 80 studs in a straight line (the walk crosses the bridge)
			expect({ garden = garden.index, farEnough = nearestDistance >= 15, closeEnough = nearestDistance <= 80 }).toEqual({
				garden = garden.index,
				farEnough = true,
				closeEnough = true,
			})
			nearestName[spot.name] = (nearestName[spot.name] or 0) + 1

			-- the spot is past the far end of this garden's plank bridge, not on the bridge itself:
			-- the bridge's far end is the plank farthest from the spawn spot, and its direction runs away from the spawn
			local planks = {}
			for _, plank in (world :: any).Bridges[`PlankBridge_{garden.index}`]:GetChildren() do
				if plank.Name == "Plank" then
					table.insert(planks, plank)
				end
			end
			table.sort(planks, function(a, b)
				return (a.Position - spawn).Magnitude < (b.Position - spawn).Magnitude
			end)
			local farEnd = planks[#planks].Position
			local direction = ((farEnd - planks[1].Position) * Vector3.new(1, 0, 1)).Unit
			local pastEnd = (spot.cframe.Position - farEnd) * Vector3.new(1, 0, 1)
			expect({ garden = garden.index, beyondTheBridge = pastEnd:Dot(direction) > 4 }).toEqual({
				garden = garden.index,
				beyondTheBridge = true,
			})
			expect(pastEnd.Magnitude <= 30).toBe(true)
		end
		-- all 8 gardens have a different nearest Common spot
		local different = 0
		for _, count in nearestName do
			expect(count).toBe(1)
			different += 1
		end
		expect(different).toBe(8)
	end)

	-- A ray straight down from `from`, `length` studs long, that ignores everything a player walks through
	-- (parts with CanCollide off, like the glow rings, invisible zone boxes and the eggs).
	local function solidBelow(from: Vector3, length: number): RaycastResult?
		local ignore: { Instance } = {}
		for _ = 1, 40 do
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			local hit = Workspace:Raycast(from, Vector3.new(0, -length, 0), params)
			if hit == nil or hit.Instance.CanCollide then
				return hit
			end
			table.insert(ignore, hit.Instance)
		end
		return nil
	end

	-- How far the spot is from the nearest place a character can stand, and what that place is.
	-- A character can stand on: the meadow's grass (Terrain with a flat top, not water), or the top face of a walk
	-- surface (a part named *_Walk, which is solid and no steeper than the project's slope limit of 70 degrees,
	-- the same limit Humanoids use). The distance goes from the top of the spot's Base to the nearest point of
	-- that top face, so a spot ON a walk surface is 0 away and a spot beside it is as far as the gap.
	local function nearestStandingPlace(top: Vector3): (number, string)
		local best, kind = math.huge, "nowhere"
		local grass = solidBelow(top + Vector3.new(0, 3, 0), 4)
		if
			grass
			and grass.Instance == Workspace.Terrain
			and grass.Normal.Y > 0.95
			and grass.Material ~= Enum.Material.Water
		then
			best, kind = (grass.Position - top).Magnitude, "grass"
		end
		-- His own skin (stuck safety Task 24, Ruling 5): where the invisible walk pieces were taken away, a spot stands on
		-- the skin itself. It counts only when a ray down hits one of his six body pieces (not a guard, patch or plank) and
		-- the Base top is within SKIN_REACH of it: the same 0.3 studs a route point may be from the ground.
		local bodyHit = Workspace:Raycast(top + Vector3.new(0, 3, 0), Vector3.new(0, -4, 0), bodyParams())
		if bodyHit ~= nil and math.abs(bodyHit.Position.Y - top.Y) <= SKIN_REACH then
			local distance = math.abs(bodyHit.Position.Y - top.Y)
			if distance < best then
				best, kind = distance, "his skin"
			end
		end
		local limit = math.cos(math.rad(game:GetService("StarterPlayer").CharacterMaxSlopeAngle))
		for _, part in (realWorld() :: any).WalkSurfaces:GetDescendants() do
			if
				part:IsA("BasePart")
				and part.CanCollide
				and string.match(part.Name, "_Walk$")
				and part.CFrame.UpVector.Y >= limit
			then
				local local_ = part.CFrame:PointToObjectSpace(top)
				local half = part.Size / 2
				local nearest = part.CFrame:PointToWorldSpace(
					Vector3.new(math.clamp(local_.X, -half.X, half.X), half.Y, math.clamp(local_.Z, -half.Z, half.Z))
				)
				local distance = (nearest - top).Magnitude
				if distance < best then
					best, kind = distance, "walk surface"
				end
			end
		end
		return best, kind
	end

	it("every egg spot sits on solid ground and can be reached", function()
		local spots = loadSpots()
		for _, spot in spots do
			local top = spot.cframe.Position
			-- a ray from 3 studs above the top of the Base, 4 studs long, hits something solid
			local hit = solidBelow(top + Vector3.new(0, 3, 0), 4)
			expect({ spot = spot.name, solid = hit ~= nil }).toEqual({ spot = spot.name, solid = true })
			-- and a character can reach it by walking and climbing: the grab reach is 8 studs
			local distance, kind = nearestStandingPlace(top)
			-- Uncommon and Rare spots stand on an invisible walk piece or, where the pieces were taken away, on his skin
			local kindIsRight = if spot.rarity == "Common"
				then kind == "grass"
				else (kind == "walk surface" or kind == "his skin")
			expect({ spot = spot.name, kind = kind, kindIsRight = kindIsRight, reachable = distance <= 8 }).toEqual({
				spot = spot.name,
				kind = kind,
				kindIsRight = true,
				reachable = true,
			})
		end
	end)

	local function hasGlowRing(spot: Model): boolean
		return spot:FindFirstChild("GlowRing") ~= nil
	end

	it(
		"ServerStorage.Assets.Eggs has a fully anchored Common, Uncommon and Rare egg, and only the Common's spot has a glow ring",
		function()
			local assets = ServerStorage:FindFirstChild("Assets")
			expect(assets).never.toBeNil()
			local templates, problems = WorldIndex.readEggTemplates(assets :: Instance)
			expect(problems).toEqual({})
			for _, rarity in { "Common", "Uncommon", "Rare" } do
				local egg: Model = (templates :: any)[rarity]
				expect(egg:GetAttribute("Rarity")).toBe(rarity)
				local parts = 0
				for _, part in egg:GetDescendants() do
					if part:IsA("BasePart") then
						parts += 1
						expect({ part = part:GetFullName(), anchored = part.Anchored, collides = part.CanCollide }).toEqual({
							part = part:GetFullName(),
							anchored = true,
							collides = false,
						})
					end
				end
				expect(parts > 0).toBe(true)
				-- the glow ring belongs to the spot, not to the egg
				expect(egg:FindFirstChild("GlowRing", true)).toBeNil()
				-- the look kept from the mockup: a light, sparkles and the rarity label (and a beam for the Rare only)
				expect(egg:FindFirstChildWhichIsA("PointLight", true)).never.toBeNil()
				expect(egg:FindFirstChildWhichIsA("ParticleEmitter", true)).never.toBeNil()
				local label = egg:FindFirstChild("Label", true)
				expect(label).never.toBeNil()
				expect(((label :: Instance):FindFirstChildWhichIsA("TextLabel") :: TextLabel).Text).toBe(rarity)
				expect(egg:FindFirstChildWhichIsA("Beam", true) ~= nil).toBe(rarity == "Rare")
			end
			for _, spot in loadSpots() do
				expect({ spot = spot.name, ring = hasGlowRing(spot.model) }).toEqual({
					spot = spot.name,
					ring = spot.rarity == "Common",
				})
			end
		end
	)

	it("each egg model's pivot is at the bottom centre of the egg", function()
		local templates = WorldIndex.loadEggTemplates(ServerStorage:FindFirstChild("Assets") :: Instance)
		for _, rarity in { "Common", "Uncommon", "Rare" } do
			local egg: Model = (templates :: any)[rarity]
			local boxCFrame, boxSize = egg:GetBoundingBox()
			local pivot = egg:GetPivot()
			local bottom = boxCFrame.Position.Y - boxSize.Y / 2
			expect({ egg = rarity, offBottom = math.abs(pivot.Position.Y - bottom) < 0.05 }).toEqual({
				egg = rarity,
				offBottom = true,
			})
			expect({
				egg = rarity,
				offCentre = (pivot.Position * Vector3.new(1, 0, 1) - boxCFrame.Position * Vector3.new(1, 0, 1)).Magnitude
					< 0.05,
			}).toEqual({
				egg = rarity,
				offCentre = true,
			})
			-- the model stands straight in its own space, so the spot decides how it leans
			expect(pivot.Rotation:FuzzyEq(CFrame.new(), 0.001)).toBe(true)
		end
	end)

	it("every egg spot has a hidden Base, a prompt anchor about 2 studs up and always streams in", function()
		for _, spot in loadSpots() do
			local base = spot.model:FindFirstChild("Base") :: BasePart
			expect({
				spot = spot.name,
				size = base.Size,
				anchored = base.Anchored,
				invisible = base.Transparency == 1,
				collides = base.CanCollide,
				queried = base.CanQuery,
				touched = base.CanTouch,
				streaming = spot.model.ModelStreamingMode,
			}).toEqual({
				spot = spot.name,
				size = Vector3.new(2, 0.2, 2),
				anchored = true,
				invisible = true,
				collides = false,
				queried = false,
				touched = false,
				streaming = Enum.ModelStreamingMode.Persistent,
			})
			local up = spot.promptAnchor.Position.Y
			expect({ spot = spot.name, aboutTwoUp = up >= 1.5 and up <= 2.5 }).toEqual({
				spot = spot.name,
				aboutTwoUp = true,
			})
			-- a meadow spot's ring lies flat on the grass, centred on the Base, solid to nothing
			local ring = spot.model:FindFirstChild("GlowRing") :: BasePart?
			if ring then
				local flatOffset = (ring.Position - spot.cframe.Position) * Vector3.new(1, 0, 1)
				expect({
					spot = spot.name,
					centred = flatOffset.Magnitude < 0.1,
					anchored = ring.Anchored,
					collides = ring.CanCollide,
				}).toEqual({
					spot = spot.name,
					centred = true,
					anchored = true,
					collides = false,
				})
				-- a flat disc: the thin side points up
				expect(math.abs(ring.CFrame.RightVector.Y) > 0.99).toBe(true)
				expect(math.abs(ring.Position.Y - spot.cframe.Position.Y) < 0.3).toBe(true)
			end
		end
	end)

	-- Made by tools/world/06-glow-rings.luau: designer's look for the ring under a waiting Common egg (spec section 6).
	it("every meadow glow ring is 6.5 studs wide, warm gold, 60% see-through and Neon, flat on the grass", function()
		local rings = 0
		for _, spot in loadSpots() do
			local ring = spot.model:FindFirstChild("GlowRing") :: Part?
			if spot.rarity == "Common" then
				expect({ spot = spot.name, hasRing = ring ~= nil }).toEqual({ spot = spot.name, hasRing = true })
				local part = ring :: Part
				rings += 1
				-- X is the ring's thickness, Y and Z its width
				local size = part.Size
				expect({
					spot = spot.name,
					sized = math.abs(size.X - 0.2) < 0.01
						and math.abs(size.Y - 6.5) < 0.01
						and math.abs(size.Z - 6.5) < 0.01,
					color = part.Color:ToHex(),
					transparent = math.abs(part.Transparency - SpotModels.WAITING_RING_TRANSPARENCY) < 0.001,
					material = part.Material,
				}).toEqual({
					spot = spot.name,
					sized = true,
					color = "ffe08a",
					transparent = true,
					material = Enum.Material.Neon,
				})
				-- still centred on its spot, with its thin side up, on the grass
				local flatOffset = (part.Position - spot.cframe.Position) * Vector3.new(1, 0, 1)
				expect(flatOffset.Magnitude < 0.1).toBe(true)
				expect(math.abs(part.CFrame.RightVector.Y) > 0.99).toBe(true)
				expect(math.abs(part.Position.Y - spot.cframe.Position.Y) < 0.3).toBe(true)
			else
				-- the boots and the belly have no ring
				expect({ spot = spot.name, hasRing = ring ~= nil }).toEqual({ spot = spot.name, hasRing = false })
			end
		end
		expect(rings).toBe(8)
	end)

	it("no egg stands inside a prop", function()
		local world = realWorld()
		local templates = WorldIndex.loadEggTemplates(ServerStorage:FindFirstChild("Assets") :: Instance)
		-- the space an egg takes up, from its own template (its pivot is its bottom centre, so the box starts there)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {
			Workspace.Terrain,
			(world :: any).Zones,
			(world :: any).EggSpots,
			(world :: any).GiantFX,
		}
		local inside: { string } = {}
		for _, spot in loadSpots() do
			local _, size = (templates :: any)[spot.rarity]:GetBoundingBox()
			local box = spot.cframe * CFrame.new(0, size.Y / 2, 0)
			for _, part in Workspace:GetPartBoundsInBox(box, size, params) do
				-- the giant himself and the invisible walk surfaces are what an egg sits on; anything else you can
				-- see (a flower, a rock, a ramp rail, the beard ladder) must not touch the egg
				if part.Transparency < 1 and not part:IsDescendantOf((world :: any).Giant) then
					table.insert(inside, `{spot.name} touches {part:GetFullName()}`)
				end
			end
		end
		expect(inside).toEqual({})
	end)

	it("the mockup eggs are kept in ServerStorage.ArtLibrary.MockupEggs and none are left in the world", function()
		expect((realWorld() :: Instance):FindFirstChild("Eggs")).toBeNil()
		local library = ServerStorage:FindFirstChild("ArtLibrary") :: Instance
		local mockups = library:FindFirstChild("MockupEggs")
		expect(mockups).never.toBeNil()
		local names = {}
		for _, egg in (mockups :: Instance):GetChildren() do
			table.insert(names, egg.Name)
		end
		table.sort(names)
		expect(names).toEqual({
			"Egg_Belly1",
			"Egg_Boot1",
			"Egg_Boot2",
			"Egg_Meadow1",
			"Egg_Meadow2",
			"Egg_Meadow3",
			"Egg_Meadow4",
		})
	end)

	-- The values come from designer's look check in Play: a 4.2 studs tall egg hid the whole head, so the carried
	-- egg is 3.6 studs tall and its middle sits 0.1 studs below the root part, 1.75 studs behind it.
	it("a carried egg is 3.6 studs tall and sits low enough to show the head", function()
		local assets = ServerStorage:FindFirstChild("Assets") :: Instance
		expect(assets).never.toBeNil()
		local height = assets:GetAttribute("CarriedEggHeight") :: number
		local offset = assets:GetAttribute("CarriedEggOffset") :: CFrame
		expect(typeof(height)).toBe("number")
		expect(typeof(offset)).toBe("CFrame")
		expect(math.abs(height - 3.6) < 0.001).toBe(true)
		expect((offset.Position - Vector3.new(0, -0.1, 1.75)).Magnitude < 0.001).toBe(true)
		-- the top of a standard character's head is 1.85 studs above its root part
		local HEAD_TOP_ABOVE_ROOT = 1.85
		expect(offset.Position.Y + height / 2 < HEAD_TOP_ABOVE_ROOT).toBe(true)
	end)
end)

-- The places where eggs sit at home (Task 38). Each garden has a HomeSpots folder with 12 invisible parts, built by
-- tools/world/07-home-spots.luau: 1 to 6 on the pet pads, 7 to 12 in two short rows beside the incubator and the cash
-- chest. The top centre of a spot is where a home egg's bottom sits. These tests only READ the real world.
describe("the real world, home spots", function()
	local Workspace = game:GetService("Workspace")

	local SPOT_COUNT = 12
	local PAD_COUNT = 6
	local SPOT_SIZE = Vector3.new(2, 0.2, 2)
	-- An egg standing on a spot: the widest egg (Rare) is about 5.9 across and the tallest is 7.0, so this box holds any
	-- of them. It starts a little above the spot, so the spot's own thickness is not "in the way".
	local EGG_BOX = Vector3.new(6, 7, 6)
	local EGG_BOX_LIFT = 0.1
	local STAND_LIMIT = 0.3 -- studs: how far the ground may be from the top of a spot
	local MAX_SLOPE_DEGREES = 10
	local MIN_SPACING = 6.5 -- studs between the middles of two spots: even two Rare eggs don't touch
	local WALKWAY_HALF_WIDTH = 8 -- studs each side of the line from the gate into the garden that stay free of spots

	local function loadGardens(): { WorldIndex.Garden }
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local gardens, problems = WorldIndex.readGardens(world :: Instance)
		expect(problems).toEqual({})
		return gardens :: { WorldIndex.Garden }
	end

	-- The top centre of a spot: where a home egg's bottom sits.
	local function topOf(spot: BasePart): Vector3
		return spot.Position + spot.CFrame.UpVector * (spot.Size.Y / 2)
	end

	local function flat(vector: Vector3): Vector3
		return Vector3.new(vector.X, 0, vector.Z)
	end

	-- A ray that comes down onto the top of a spot, skipping everything a player walks through (flowers, stones).
	-- With `onlyThese` it can only hit those parts, so a pad's own walk surface can be found.
	local function groundBelow(top: Vector3, onlyThese: { Instance }?): RaycastResult?
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		if onlyThese then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = onlyThese
		end
		return Workspace:Raycast(top + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
	end

	it("every garden has 12 home spots: invisible, flat, anchored 2 by 0.2 by 2 parts that nothing touches", function()
		for _, garden in loadGardens() do
			expect({ garden = garden.index, spots = #garden.homeSpots }).toEqual({
				garden = garden.index,
				spots = SPOT_COUNT,
			})
			for number, spot in garden.homeSpots do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				expect({ label = label, name = spot.Name }).toEqual({ label = label, name = `HomeSpot_{number}` })
				expect({ label = label, parent = spot.Parent and spot.Parent.Name }).toEqual({
					label = label,
					parent = "HomeSpots",
				})
				expect({ label = label, size = spot.Size }).toEqual({ label = label, size = SPOT_SIZE })
				expect({ label = label, transparency = spot.Transparency }).toEqual({ label = label, transparency = 1 })
				expect({
					label = label,
					anchored = spot.Anchored,
					canCollide = spot.CanCollide,
					canQuery = spot.CanQuery,
					canTouch = spot.CanTouch,
					castShadow = spot.CastShadow,
				}).toEqual({
					label = label,
					anchored = true,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					castShadow = false,
				})
				-- it lies flat: its up direction is straight up
				expect({ label = label, flat = spot.CFrame.UpVector.Y > 0.9999 }).toEqual({ label = label, flat = true })
			end
		end
	end)

	it("home spots 1 to 6 each sit on their own pet pad, on its walk surface", function()
		for _, garden in loadGardens() do
			for number = 1, PAD_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local spot = garden.homeSpots[number]
				local pad = garden.petPads[number]
				local top = topOf(spot)
				-- inside the pad's footprint
				local boxCFrame, boxSize = pad:GetBoundingBox()
				local inPad = boxCFrame:PointToObjectSpace(top)
				expect({
					label = label,
					inside = math.abs(inPad.X) <= boxSize.X / 2 and math.abs(inPad.Z) <= boxSize.Z / 2,
				}).toEqual({ label = label, inside = true })
				-- the top is within 0.3 studs of what a ray that only hits this pad finds under it
				local onlyThisPad: { Instance } = { pad }
				local hit = groundBelow(top, onlyThisPad)
				expect({ label = label, found = hit ~= nil }).toEqual({ label = label, found = true })
				local gap = math.abs(top.Y - (hit :: RaycastResult).Position.Y)
				expect({ label = label, onSurface = gap <= STAND_LIMIT }).toEqual({ label = label, onSurface = true })
			end
		end
	end)

	it("home spots 7 to 12 are inside the garden box, on flat ground a player can stand on", function()
		local maxSlope = math.cos(math.rad(MAX_SLOPE_DEGREES))
		for _, garden in loadGardens() do
			for number = PAD_COUNT + 1, SPOT_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local top = topOf(garden.homeSpots[number])
				local local_ = garden.box.cframe:PointToObjectSpace(top)
				local half = garden.box.size / 2
				expect({
					label = label,
					inside = math.abs(local_.X) <= half.X
						and math.abs(local_.Y) <= half.Y
						and math.abs(local_.Z) <= half.Z,
				}).toEqual({ label = label, inside = true })
				local hit = groundBelow(top, nil)
				expect({ label = label, found = hit ~= nil }).toEqual({ label = label, found = true })
				local ground = hit :: RaycastResult
				expect({ label = label, near = math.abs(ground.Position.Y - top.Y) <= STAND_LIMIT }).toEqual({
					label = label,
					near = true,
				})
				expect({ label = label, flatEnough = ground.Normal.Y >= maxSlope }).toEqual({
					label = label,
					flatEnough = true,
				})
			end
		end
	end)

	it("no two home spots in a garden are closer than 6.5 studs", function()
		for _, garden in loadGardens() do
			for first = 1, SPOT_COUNT do
				for second = first + 1, SPOT_COUNT do
					local distance = (flat(garden.homeSpots[first].Position) - flat(garden.homeSpots[second].Position)).Magnitude
					expect({ garden = garden.index, first = first, second = second, apart = distance >= MIN_SPACING }).toEqual({
						garden = garden.index,
						first = first,
						second = second,
						apart = true,
					})
				end
			end
		end
	end)

	it("an egg standing on any home spot touches nothing solid", function()
		for _, garden in loadGardens() do
			for number, spot in garden.homeSpots do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local params = OverlapParams.new()
				params.RespectCanCollide = true
				-- An egg on a pad stands in the pad's dish, whose rim rises above the walk surface: its own pad is not "in the
				-- way" (every other pad is).
				if number <= PAD_COUNT then
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { garden.petPads[number] }
				end
				local eggBox = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + EGG_BOX_LIFT + EGG_BOX.Y / 2, 0)
				local touching: { string } = {}
				for _, part in Workspace:GetPartBoundsInBox(eggBox, EGG_BOX, params) do
					table.insert(touching, part:GetFullName())
				end
				expect({ label = label, touching = touching }).toEqual({ label = label, touching = {} })
			end
		end
	end)

	it("home spots 7 to 12 keep a clear walkway from the gate into the garden", function()
		for _, garden in loadGardens() do
			local gate = flat(garden.gate:GetPivot().Position)
			local centre = flat(garden.box.cframe.Position)
			local line = centre - gate
			for number = PAD_COUNT + 1, SPOT_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local fromGate = flat(garden.homeSpots[number].Position) - gate
				local along = math.clamp(fromGate:Dot(line) / line:Dot(line), 0, 1)
				local distance = (fromGate - line * along).Magnitude
				expect({ label = label, clear = distance >= WALKWAY_HALF_WIDTH }).toEqual({
					label = label,
					clear = true,
				})
			end
		end
	end)

	it("spots 7 to 12 are in the same places in every garden, measured from the garden's own box", function()
		local gardens = loadGardens()
		local first = gardens[1]
		for _, garden in gardens do
			for number = PAD_COUNT + 1, SPOT_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local mine = garden.box.cframe:PointToObjectSpace(garden.homeSpots[number].Position)
				local theirs = first.box.cframe:PointToObjectSpace(first.homeSpots[number].Position)
				expect({ label = label, same = (flat(mine) - flat(theirs)).Magnitude < 0.05 }).toEqual({
					label = label,
					same = true,
				})
			end
		end
	end)
end)

-- The footprint route and the landing spots (Task 23). They are built by tools/world/08-route.luau. These tests only
-- READ the real world.
describe("the real world, route and landing spots", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")
	local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)

	local GATE_OUTSIDE = 5.5 -- studs from the middle of a Safe Gate toward its spawn spot: just outside the arch
	local TARGET_REACH = 3 -- studs, across the ground, between a target point and the thing it stands at
	local MAX_LINK_LENGTH = 25 -- studs: short links follow the walk surfaces, with no corner-cutting
	local RAY_START_ABOVE = 3 -- studs: a ground ray starts this far above the place it checks
	local STAND_LIMIT = 0.3 -- studs: how far a point's top may be from the ground under it
	local POINT_SIZE = Vector3.new(1, 0.2, 1)
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
	-- them). designer owns which props count. The same list and the same circles are in tools/world/08-route.luau.
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

	local function realWorld(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

	local function flat(vector: Vector3): Vector3
		return Vector3.new(vector.X, 0, vector.Z)
	end

	local function loadRoute(): { WorldIndex.RoutePoint }
		local points, problems = WorldIndex.readRoute(realWorld())
		expect(problems).toEqual({})
		return points :: { WorldIndex.RoutePoint }
	end

	local function loadLandingSpots(): { WorldIndex.LandingSpot }
		local spots, problems = WorldIndex.readLandingSpots(realWorld())
		expect(problems).toEqual({})
		return spots :: { WorldIndex.LandingSpot }
	end

	-- What a player stands on: a ray down that skips everything with CanCollide off (flowers, ropes, cleats).
	local function groundRay(): RaycastParams
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		return params
	end

	local function describeVector(vector: Vector3): string
		return string.format("(%.1f, %.1f, %.1f)", vector.X, vector.Y, vector.Z)
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
		-- (50, -54), where a flower clump was 2.4 studs away.
		local approved: { { number } } = {
			{ -45, -79 },
			{ -42, -97 },
			{ 52, -91 },
			{ 48, -80 },
			{ -48, -64 },
			{ -50, -54 },
			{ 46, -64 },
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
end)

-- The spots where he slams when nobody can be targeted (Slams.pickEmpty): the meadow route points. A spot fits when its
-- 15-stud circle stays 1 stud clear of every garden and covers no landing spot. This only READS the world.
describe("the real world, slam spots", function()
	local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
	local Slams = require(ServerScriptService.Server.Giant.Slams)
	local MEADOW_POINTS_NEEDED = 8
	local COVERED_DISTANCE = Config.Wake.SlamCircleDiameter / 2

	local function realWorld(): Instance
		local world = game:GetService("Workspace"):FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

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

	local function realWorld(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

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

	-- Measured in the place: the ray from y = 50 first meets his belly (body_and_cushion) at y = 40.64. Players stand on
	-- the invisible Belly_Walk 0.005 lower, so the circle is drawn where they stand, within a small margin.
	it("finds the belly's surface, about 8 studs under the belly standing spot", function()
		realWorld()
		local hit = SlamSurface.below(Workspace, BELLY_SPOT, {})
		expect(hit.Y).toBeGreaterThan(40)
		expect(hit.Y).toBeLessThan(49)
		expect(math.abs(hit.Y - 40.64) <= 0.5).toBe(true)
		expect(hit.X).toBeCloseTo(BELLY_SPOT.X, 1)
		expect(hit.Z).toBeCloseTo(BELLY_SPOT.Z, 1)
	end)

	it("sends the centre 3 studs lower when the ray finds nothing, far below the map", function()
		realWorld()
		local centre = Vector3.new(0, -500, 0)
		expect(SlamSurface.below(Workspace, centre, {})).toEqual(centre - Vector3.new(0, 3, 0))
	end)

	it("skips what is in the ignore list: without the giant the belly spot's ray lands lower", function()
		local world = realWorld()
		local giant = (world :: any).Giant :: Model
		local withGiant = SlamSurface.below(Workspace, BELLY_SPOT, {})
		local withoutGiant = SlamSurface.below(Workspace, BELLY_SPOT, { giant })
		expect(withoutGiant.Y).toBeLessThan(withGiant.Y)
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

-- The two name faces on each garden's gate sign. They are thin, almost invisible parts with a SurfaceGui and a
-- TextLabel. The board is not its own part: it is part of the gate's one mesh (SafeGate.body.body_geom), so the
-- board has to be found with rays. They are placed by tools/world/11-sign-faces.luau.
describe("the real world, the garden sign faces", function()
	local FACE_WIDTH = 4.4
	local FACE_HEIGHT = 1.6
	local FACE_THICKNESS = 0.05
	local GAP = 0.35 -- studs from the board's furthest point on the face's side to the face's middle
	local GAP_TOLERANCE = 0.02
	local GRID_STEP = 0.2
	local RAY_START = 15 -- studs out from the face before the ray travels back toward the board
	-- Where the front face's middle sits across the gate mesh and up it (the mesh's own X and Y), the same for all 8
	-- gardens. Only the depth is allowed to change.
	local MIDDLE_ACROSS = -0.0058
	local MIDDLE_UP = 4.225

	local function gardens(): { { number: number, gate: Model, mesh: MeshPart, front: Part, back: Part } }
		local world = game:GetService("Workspace"):FindFirstChild("World")
		expect(world).never.toBeNil()
		local plots = (world :: Instance):FindFirstChild("Plots")
		expect(plots).never.toBeNil()
		local found = {}
		for number = 1, 8 do
			local plot = (plots :: Instance):FindFirstChild(`Plot_{number}`)
			expect(plot).never.toBeNil()
			local gate = (plot :: Instance):FindFirstChild("SafeGate")
			expect(gate).never.toBeNil()
			local mesh = (gate :: Instance):FindFirstChild("body")
			expect(mesh).never.toBeNil()
			local geometry = (mesh :: Instance):FindFirstChild("body_geom")
			expect(geometry).never.toBeNil()
			local front = (gate :: Instance):FindFirstChild("SignFace")
			local back = (gate :: Instance):FindFirstChild("SignFaceBack")
			expect(front).never.toBeNil()
			expect(back).never.toBeNil()
			table.insert(found, {
				number = number,
				gate = gate :: Model,
				mesh = geometry :: MeshPart,
				front = front :: Part,
				back = back :: Part,
			})
		end
		return found
	end

	-- How far (in studs) a face's middle is out from the mesh's furthest point on the face's own side. The rays start
	-- RAY_START studs out from the face and travel straight at the mesh, on a grid over the face's rectangle. Each ray
	-- keeps the first hit (the one nearest the face's side). The furthest point is the largest depth of those hits.
	local function gapToBoard(face: BasePart, mesh: MeshPart): number
		local out = face.CFrame.LookVector
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { mesh }
		local columns = math.round(face.Size.X / GRID_STEP)
		local rows = math.round(face.Size.Y / GRID_STEP)
		local furthest = -math.huge
		local hits = 0
		for column = 0, columns do
			for row = 0, rows do
				local across = -face.Size.X / 2 + column * face.Size.X / columns
				local up = -face.Size.Y / 2 + row * face.Size.Y / rows
				local from = face.CFrame:PointToWorldSpace(Vector3.new(across, up, 0)) + out * RAY_START
				local hit = game:GetService("Workspace"):Raycast(from, -out * (RAY_START * 2), params)
				if hit then
					hits += 1
					furthest = math.max(furthest, hit.Position:Dot(out))
				end
			end
		end
		expect(hits > 0).toBe(true)
		return face.Position:Dot(out) - furthest
	end

	it("makes both faces 4.4 by 1.6 studs and keeps them thin", function()
		for _, garden in gardens() do
			for _, face in { garden.front, garden.back } do
				local size = face.Size
				local text = `garden {garden.number} {face.Name} {size.X}, {size.Y}, {size.Z}`
				local fits = math.abs(size.X - FACE_WIDTH) < 0.001
					and math.abs(size.Y - FACE_HEIGHT) < 0.001
					and math.abs(size.Z - FACE_THICKNESS) < 0.001
				expect(`{text} {fits}`).toBe(`{text} true`)
			end
		end
	end)

	it("keeps the front face's middle across the board and up and down, and its facing", function()
		for _, garden in gardens() do
			local local_ = garden.mesh.CFrame:PointToObjectSpace(garden.front.Position)
			local text = `garden {garden.number} front across {local_.X} up {local_.Y}`
			local kept = math.abs(local_.X - MIDDLE_ACROSS) < 0.01 and math.abs(local_.Y - MIDDLE_UP) < 0.01
			expect(`{text} {kept}`).toBe(`{text} true`)
			-- Faces out of the front of the gate, the same way as the mesh.
			expect(garden.front.CFrame.LookVector:Dot(garden.mesh.CFrame.LookVector) > 0.9999).toBe(true)
		end
	end)

	it("keeps the back face behind the front face, with the same middle, facing the other way", function()
		for _, garden in gardens() do
			local inFront = garden.front.CFrame:PointToObjectSpace(garden.back.Position)
			local text = `garden {garden.number} back in the front face's space {inFront.X}, {inFront.Y}`
			expect(`{text} {math.abs(inFront.X) < 0.01 and math.abs(inFront.Y) < 0.01}`).toBe(`{text} true`)
			expect(garden.front.CFrame.LookVector:Dot(garden.back.CFrame.LookVector) < -0.9999).toBe(true)
			expect((garden.front.CFrame.UpVector - garden.back.CFrame.UpVector).Magnitude < 0.001).toBe(true)
			-- Behind the front face means a positive object-space Z (the face looks out of its own negative Z).
			expect(inFront.Z > 1).toBe(true)
		end
	end)

	it("puts each face 0.35 studs out from the board's furthest point on its own side", function()
		for _, garden in gardens() do
			for _, face in { garden.front, garden.back } do
				local gap = gapToBoard(face, garden.mesh)
				local text = `garden {garden.number} {face.Name} is {string.format("%.3f", gap)} studs out`
				expect(`{text} {math.abs(gap - GAP) <= GAP_TOLERANCE}`).toBe(`{text} true`)
			end
		end
	end)

	it("sees a face that is moved 0.1 studs out of place", function()
		-- A scratch copy (never put in the world): first set right by the ray rule, then moved 0.1 studs.
		local garden = gardens()[1]
		for _, face in { garden.front, garden.back } do
			local scratch = face:Clone()
			scratch.Size = Vector3.new(FACE_WIDTH, FACE_HEIGHT, FACE_THICKNESS)
			scratch.CFrame = scratch.CFrame * CFrame.new(0, 0, gapToBoard(scratch, garden.mesh) - GAP)
			expect(math.abs(gapToBoard(scratch, garden.mesh) - GAP) <= GAP_TOLERANCE).toBe(true)
			local right = scratch.CFrame
			scratch.CFrame = right * CFrame.new(0, 0, -0.1) -- 0.1 studs further out
			expect(math.abs(gapToBoard(scratch, garden.mesh) - GAP) <= GAP_TOLERANCE).toBe(false)
			scratch.CFrame = right * CFrame.new(0, 0, 0.1) -- 0.1 studs further in
			expect(math.abs(gapToBoard(scratch, garden.mesh) - GAP) <= GAP_TOLERANCE).toBe(false)
			scratch:Destroy()
		end
	end)

	it("sizes each canvas to the face, so the words are not stretched", function()
		for _, garden in gardens() do
			for _, face in { garden.front, garden.back } do
				local surface = face:FindFirstChild("SurfaceGui")
				expect(surface).never.toBeNil()
				local gui = surface :: SurfaceGui
				local text = `garden {garden.number} {face.Name} canvas {gui.CanvasSize.X}, {gui.CanvasSize.Y}`
				local right = math.abs(gui.CanvasSize.X - face.Size.X * gui.PixelsPerStud) < 0.5
					and math.abs(gui.CanvasSize.Y - face.Size.Y * gui.PixelsPerStud) < 0.5
				expect(`{text} {right}`).toBe(`{text} true`)
				expect(gui.Face).toBe(Enum.NormalId.Front)
				expect(gui.SizingMode).toBe(Enum.SurfaceGuiSizingMode.FixedSize)
				local label = gui:FindFirstChild("TextLabel")
				expect(label).never.toBeNil()
				local textLabel = label :: TextLabel
				expect(textLabel.TextScaled).toBe(true)
				expect(textLabel.TextWrapped).toBe(true)
				expect(textLabel.Size).toEqual(UDim2.fromScale(1, 1))
			end
		end
	end)
end)

-- Designer's mockup folders (Workspace.Mockup_*) are not part of the game. tools/world/11a-mockups-hands-off.luau
-- makes every part in them not solid, not found by ray or box checks and not touchable, after saving each part's own
-- three values as attributes so nothing designer set is lost.
describe("the real world, the mockup folders", function()
	local function mockupParts(): { BasePart }
		local found: { BasePart } = {}
		for _, child in game:GetService("Workspace"):GetChildren() do
			if string.sub(child.Name, 1, 7) == "Mockup_" then
				if child:IsA("BasePart") then
					table.insert(found, child)
				end
				for _, descendant in child:GetDescendants() do
					if descendant:IsA("BasePart") then
						table.insert(found, descendant)
					end
				end
			end
		end
		return found
	end

	-- A short list of full names, so a failure names the parts (and does not print thousands of lines).
	local function names(parts: { BasePart }): { string }
		local list: { string } = {}
		for index, part in parts do
			if index > 10 then
				table.insert(list, `... and {#parts - 10} more`)
				break
			end
			table.insert(list, part:GetFullName())
		end
		return list
	end

	it("nothing in a mockup folder is solid, found by ground checks or touchable", function()
		local on: { BasePart } = {}
		for _, part in mockupParts() do
			if part.CanCollide or part.CanQuery or part.CanTouch then
				table.insert(on, part)
			end
		end
		expect(names(on)).toEqual({})
	end)

	it("every part in a mockup folder kept its own three values as attributes", function()
		local missing: { BasePart } = {}
		for _, part in mockupParts() do
			for _, attribute in { "MockupCanCollide", "MockupCanQuery", "MockupCanTouch" } do
				if typeof(part:GetAttribute(attribute)) ~= "boolean" then
					table.insert(missing, part)
					break
				end
			end
		end
		expect(names(missing)).toEqual({})
	end)
end)

-- Nothing in designer's mockup folders (Workspace.Mockup_*) may show in Play: they are mockup pieces, not the game.
-- tools/world/11b-mockups-out-of-sight.luau makes every part, decal and texture fully see-through, switches off every
-- label, screen and effect, and hides the name of every avatar, after saving each old value as an attribute
-- (MockupTransparency, MockupEnabled or MockupDisplayDistanceType), so designer can show a mockup again for a shot.
describe("the real world, the mockup folders are out of sight", function()
	local SWITCHED_CLASSES = {
		"BillboardGui",
		"SurfaceGui",
		"Beam",
		"Trail",
		"ParticleEmitter",
		"PointLight",
		"SpotLight",
		"SurfaceLight",
		"Fire",
		"Smoke",
		"Sparkles",
		"Highlight",
	}

	local function isSwitched(instance: Instance): boolean
		for _, className in SWITCHED_CLASSES do
			if instance:IsA(className) then
				return true
			end
		end
		return false
	end

	-- A title, the count and the first 3 full names, so a failure names the objects (and does not print thousands).
	local function describeList(title: string, found: { string }): { string }
		local list: { string } = {}
		if #found == 0 then
			return list
		end
		table.insert(list, `{title}: {#found}`)
		for index, path in found do
			if index > 3 then
				break
			end
			table.insert(list, `  {path}`)
		end
		return list
	end

	it("nothing in a mockup folder shows in Play", function()
		local visible: { string } = {}
		local switchedOn: { string } = {}
		local namesShown: { string } = {}
		local missingSaved: { string } = {}
		for _, folder in game:GetService("Workspace"):GetChildren() do
			if string.sub(folder.Name, 1, 7) ~= "Mockup_" then
				continue
			end
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
					local thing = descendant :: BasePart
					if thing.Transparency ~= 1 then
						table.insert(visible, descendant:GetFullName())
					elseif typeof(descendant:GetAttribute("MockupTransparency")) ~= "number" then
						table.insert(missingSaved, descendant:GetFullName())
					end
				elseif isSwitched(descendant) then
					if (descendant :: any).Enabled then
						table.insert(switchedOn, descendant:GetFullName())
					elseif typeof(descendant:GetAttribute("MockupEnabled")) ~= "boolean" then
						table.insert(missingSaved, descendant:GetFullName())
					end
				elseif descendant:IsA("Humanoid") then
					if descendant.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
						table.insert(namesShown, descendant:GetFullName())
					elseif typeof(descendant:GetAttribute("MockupDisplayDistanceType")) ~= "string" then
						table.insert(missingSaved, descendant:GetFullName())
					end
				end
			end
		end
		local problems: { string } = {}
		for _, line in describeList("parts, decals and textures still visible", visible) do
			table.insert(problems, line)
		end
		for _, line in describeList("labels, screens and effects still on", switchedOn) do
			table.insert(problems, line)
		end
		for _, line in describeList("avatars still showing a name or health bar", namesShown) do
			table.insert(problems, line)
		end
		for _, line in describeList("hidden without a saved value", missingSaved) do
			table.insert(problems, line)
		end
		expect(problems).toEqual({})
	end)
end)

-- Mockup avatars (models with a Humanoid, used to show a player's size in mockup shots) must not stand in the world.
-- A character's body parts are solid again in Play, even with CanCollide off in Edit, so an invisible avatar on a
-- spawn spot or a way up blocks or lifts a real player. tools/world/11c-mockup-avatars-away.luau moves each one to
-- ServerStorage.ArtLibrary.MockupAvatars.<its mockup folder>, so designer can bring one back for a shot.
describe("the real world, no mockup avatar stands in a player's way", function()
	local Workspace = game:GetService("Workspace")

	it("no mockup avatar is left in the Workspace", function()
		local left: { string } = {}
		for _, folder in Workspace:GetChildren() do
			if string.sub(folder.Name, 1, 7) ~= "Mockup_" then
				continue
			end
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("Humanoid") then
					table.insert(left, descendant:GetFullName())
				end
			end
		end
		table.sort(left)
		expect(left).toEqual({})
	end)

	it(
		"the six mockup avatars wait in ServerStorage.ArtLibrary.MockupAvatars, each in its mockup folder's name",
		function()
			local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
			expect(library).never.toBeNil()
			local avatars = (library :: Instance):FindFirstChild("MockupAvatars")
			expect(avatars).never.toBeNil()
			local found: { string } = {}
			for _, descendant in (avatars :: Instance):GetDescendants() do
				if descendant:IsA("Humanoid") then
					table.insert(found, (descendant.Parent :: Instance):GetFullName())
				end
			end
			table.sort(found)
			local base = "ServerStorage.ArtLibrary.MockupAvatars."
			expect(found).toEqual({
				base .. "Mockup_EggRanks.Avatar",
				base .. "Mockup_LadderSlam.Avatar",
				base .. "Mockup_Nests.Avatar",
				base .. "Mockup_Rescue.Avatar",
				base .. "Mockup_WakeUp.Avatar",
				base .. "Mockup_WaysUp.Avatar",
			})
		end
	)

	it("a moved avatar keeps its Mockup attributes", function()
		local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		expect(library).never.toBeNil()
		local avatars = (library :: Instance):FindFirstChild("MockupAvatars")
		expect(avatars).never.toBeNil()
		local without: { string } = {}
		for _, descendant in (avatars :: Instance):GetDescendants() do
			local lacksSaved = false
			if descendant:IsA("BasePart") then
				lacksSaved = typeof(descendant:GetAttribute("MockupTransparency")) ~= "number"
			elseif descendant:IsA("Humanoid") then
				lacksSaved = typeof(descendant:GetAttribute("MockupDisplayDistanceType")) ~= "string"
			end
			if lacksSaved then
				table.insert(without, descendant:GetFullName())
			end
		end
		table.sort(without)
		expect(without).toEqual({})
	end)
end)

-- The 85% warning's world pieces (V2 new-player safety, Task 7). tools/world/12-warning85.luau moves designer's tested
-- snort nose and bubble out of Workspace.Mockup_Warning85 into World.GiantFX, gives them their saved values back and
-- sends the rest of the mockup to ServerStorage.ArtLibrary. The tested values are in docs/design/v2/style-guide.md,
-- "The 85% warning: tested values (2026-10-19)".
describe("the real world, the 85% warning pieces", function()
	local Workspace = game:GetService("Workspace")

	local function giantFx(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local fx = (world :: Instance):FindFirstChild("GiantFX")
		expect(fx).never.toBeNil()
		return fx :: Instance
	end

	-- The names of every Mockup* attribute left on an instance, as a list, so a failure names them.
	local function mockupAttributes(instance: Instance): { string }
		local found: { string } = {}
		for name in instance:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				table.insert(found, name)
			end
		end
		table.sort(found)
		return found
	end

	local function sequenceText(keypoints: { NumberSequenceKeypoint }): string
		local parts: { string } = {}
		for _, keypoint in keypoints do
			table.insert(parts, `{string.format("%.2f", keypoint.Time)}:{string.format("%.2f", keypoint.Value)}`)
		end
		return table.concat(parts, ",")
	end

	it("the snort nose sits at his nose tip, 2 by 0.4 by 2, untouchable, with the tested puff", function()
		local nose = giantFx():FindFirstChild("SnortNose")
		expect(nose).never.toBeNil()
		local part = nose :: BasePart
		expect(part:IsA("BasePart")).toBe(true)
		expect((part.Position - Vector3.new(0, 89, -14)).Magnitude < 0.01).toBe(true)
		expect((part.Size - Vector3.new(2, 0.4, 2)).Magnitude < 0.01).toBe(true)
		expect(part.CanCollide).toBe(false)
		expect(part.CanQuery).toBe(false)
		expect(part.CanTouch).toBe(false)
		expect(part.Transparency).toBe(1)
		expect(part.Anchored).toBe(true)
		-- the top face points out and up from his face
		expect((part.CFrame.UpVector - Vector3.new(0, 0.5, -0.87)).Magnitude < 0.01).toBe(true)
		expect(mockupAttributes(part)).toEqual({})

		local puff = part:FindFirstChild("SnortPuff")
		expect(puff).never.toBeNil()
		local emitter = puff :: ParticleEmitter
		expect(emitter:IsA("ParticleEmitter")).toBe(true)
		expect(mockupAttributes(emitter)).toEqual({})
		expect(emitter.Enabled).toBe(false)
		expect(emitter.Rate).toBe(0)
		expect(emitter.EmissionDirection).toBe(Enum.NormalId.Top)
		expect(emitter.Texture).toBe("rbxasset://textures/particles/smoke_main.dds")
		local colour = emitter.Color.Keypoints[1].Value
		expect(math.abs(colour.R - 0.921569) < 0.001 and math.abs(colour.G - 0.960784) < 0.001 and colour.B == 1).toBe(
			true
		)
		expect(sequenceText(emitter.Size.Keypoints)).toBe("0.00:6.00,1.00:20.00")
		expect(emitter.Speed).toEqual(NumberRange.new(18, 24))
		expect(emitter.SpreadAngle).toEqual(Vector2.new(25, 25))
		expect(emitter.Drag).toBe(2)
		expect(emitter.Lifetime).toEqual(NumberRange.new(1.2, 1.8))
		expect(sequenceText(emitter.Transparency.Keypoints)).toBe("0.00:0.10,0.60:0.40,1.00:1.00")
		expect(math.abs(emitter.LightEmission - 0.3) < 0.001).toBe(true)
		expect(math.abs(emitter.LightInfluence - 0.6) < 0.001).toBe(true)
	end)

	it("the 85% bubble waits, off, in the Z Z Z emitter, with its words and its tail", function()
		local snore = giantFx():FindFirstChild("SnoreEmitter")
		expect(snore).never.toBeNil()
		local bubble = (snore :: Instance):FindFirstChild("Warning85Bubble")
		expect(bubble).never.toBeNil()
		local gui = bubble :: BillboardGui
		expect(gui:IsA("BillboardGui")).toBe(true)
		expect(gui.Enabled).toBe(false)
		expect(mockupAttributes(gui)).toEqual({})
		local frame = gui:FindFirstChild("Frame")
		expect(frame).never.toBeNil()
		local words = (frame :: Instance):FindFirstChild("TextLabel")
		expect(words).never.toBeNil()
		expect((words :: TextLabel).Text).toBe("Mmm... my eggs...")
		local tail = gui:FindFirstChild("Tail")
		expect(tail).never.toBeNil()
		expect((tail :: Instance):IsA("Frame")).toBe(true)
		-- no Mockup* attribute left on any piece of the bubble
		for _, piece in gui:GetDescendants() do
			expect(`{piece:GetFullName()} {table.concat(mockupAttributes(piece), ",")}`).toBe(`{piece:GetFullName()} `)
		end
		-- it draws at the Z Z Z spot (the emitter), never at a part that left for the library
		expect(gui.Adornee).toBeNil()
	end)

	it("nothing named MumbleAnchor is left in the Workspace: the old bubble went to the library", function()
		local left: { string } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == "MumbleAnchor" then
				table.insert(left, descendant:GetFullName())
			end
		end
		expect(left).toEqual({})
	end)

	it("the 85% bubble has no stale Note attribute left", function()
		local snore = giantFx():FindFirstChild("SnoreEmitter")
		expect(snore).never.toBeNil()
		local bubble = (snore :: Instance):FindFirstChild("Warning85Bubble")
		expect(bubble).never.toBeNil()
		expect((bubble :: Instance):GetAttribute("Note")).toBeNil()
	end)

	it("nothing named Mockup_Warning85 is left in the Workspace", function()
		local left: { string } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == "Mockup_Warning85" then
				table.insert(left, descendant:GetFullName())
			end
		end
		expect(left).toEqual({})
	end)

	it("every part of his eyelids is not solid and not found by checks, so nobody can stand on a lid", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local giant = (world :: Instance):FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local eyes = (giant :: Instance):FindFirstChild("SleepEyes")
		expect(eyes).never.toBeNil()
		local solid: { string } = {}
		local count = 0
		for _, descendant in (eyes :: Instance):GetDescendants() do
			if descendant:IsA("BasePart") then
				count += 1
				if descendant.CanCollide or descendant.CanQuery then
					table.insert(solid, descendant:GetFullName())
				end
			end
		end
		expect(count > 0).toBe(true)
		expect(solid).toEqual({})
	end)
end)

-- The teacup's bowl (V2 stuck safety, Task 6). The cup's bowl is open on top, so a player who got in was wedged (the
-- 4 stuck spots of the Task 18 review). tools/world/14-teacup-tea.luau sets the cup's collision to Hull (Roblox's smooth
-- wrap, which fills the bowl up to its rim) and adds the tea: one flat brown disc just below the rim, so a player
-- standing on top of the filled bowl stands over something they can see. The tea is tilted like the cup, because the
-- cup's rim is not level (designer, docs/specs/v2/research/decisions-plans.md, "Stuck safety Task 6: the tea on a tilted
-- rim").
describe("the real world, the teacup's bowl", function()
	local Workspace = game:GetService("Workspace")

	-- MEASURED BY HAND on 2026-10-19, in Studio Edit mode, before the cup became Hull (once it is Hull the inside of the
	-- bowl can't be measured again). The method: rays straight down onto the cup's own mesh (RespectCanCollide off,
	-- only the cup in the filter), outwards from (76, -58) every 0.1 studs from 6 to 16 studs, at 72 angles 5 degrees
	-- apart. The rim crest of each angle is its highest hit. The rim plane is the least-squares plane through the 72
	-- crest points: y = RIM_SLOPE_X * x + RIM_SLOPE_Z * z + RIM_BASE. It tilts the rim 8.8 degrees, highest to the
	-- west/north-west (lowest crest 18.35, highest on the bowl 23.0).
	local RIM_SLOPE_X = -0.134338
	local RIM_SLOPE_Z = -0.077725
	local RIM_BASE = 26.486
	-- The crest point that sits farthest below the plane (the worst one), 0.45336 studs under it.
	local WORST_RIM_X = 69.55
	local WORST_RIM_Z = -46.8283
	local WORST_RIM_Y = 20.3291
	-- The tea's top is this far under the rim plane: the worst point's distance plus 0.1 (designer).
	local TEA_DROP = 0.5534
	-- The circle fitted to the inside of the bowl at the tea's height (the wall found by rays down along 72 angles
	-- in the tea's own plane): its centre, on the tea's top plane, and its radius. The tea's radius is that plus 0.3,
	-- so its edge tucks into the cup wall (designer).
	local CIRCLE_CENTRE_X = 77.3985
	local CIRCLE_CENTRE_Z = -57.1986
	local CIRCLE_RADIUS = 11.941
	local TEA_RADIUS = CIRCLE_RADIUS + 0.3
	local TEA_THICKNESS = 0.4
	local TEA_COLOUR = Color3.fromHex("9C5E34")
	-- A player's feet over the tea, measured straight down from the feet to the tea's top (designer).
	local FEET_NEAREST = 0.4
	local FEET_FARTHEST = 1.0
	local TOLERANCE = 0.02

	local function teacup(): Model
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local things = (world :: Instance):FindFirstChild("GiantsThings")
		expect(things).never.toBeNil()
		local cup = (things :: Instance):FindFirstChild("Teacup")
		expect(cup).never.toBeNil()
		return cup :: Model
	end

	local function cupMesh(): MeshPart
		local mesh = teacup():FindFirstChild("body_geom", true)
		expect(mesh).never.toBeNil()
		return mesh :: MeshPart
	end

	-- Every part named Tea in the teacup.
	local function teaParts(): { BasePart }
		local found: { BasePart } = {}
		for _, descendant in teacup():GetDescendants() do
			if descendant.Name == "Tea" and descendant:IsA("BasePart") then
				table.insert(found, descendant)
			end
		end
		return found
	end

	-- The one tea part, or a failed test.
	local function tea(): Part
		local parts = teaParts()
		expect(#parts).toBe(1)
		return parts[1] :: Part
	end

	-- The tea's own top: the point in the middle of its top face, and the direction that face points (its X axis,
	-- because Roblox's cylinder stands along X).
	local function teaTop(part: BasePart): (Vector3, Vector3)
		local up = part.CFrame.RightVector
		return part.Position + up * (part.Size.X / 2), up
	end

	-- The height of the tea's top surface straight above or below (x, z).
	local function teaTopHeightAt(part: BasePart, x: number, z: number): number
		local point, up = teaTop(part)
		return point.Y - (up.X * (x - point.X) + up.Z * (z - point.Z)) / up.Y
	end

	local function rimPlaneHeight(x: number, z: number): number
		return RIM_SLOPE_X * x + RIM_SLOPE_Z * z + RIM_BASE
	end

	it("the teacup's collision is the smooth wrap", function()
		expect(cupMesh().CollisionFidelity).toBe(Enum.CollisionFidelity.Hull)
	end)

	-- The stuck scan's standing places in the bowl, found with rays down onto the cup's own mesh on 2026-10-19 (before the
	-- cup became Hull): each is where a ray lands and the ground's slope there. The first four are the stuck spots of the
	-- Task 18 review (the scan listed them rounded to 0.1). The last is the bottom of the bowl, near the cup's middle.
	-- A standing body fits at every one of them today; the box tilts with the slope, as the scan's does.
	it("no standing body fits in the teacup's bowl", function()
		local options = PathCheck.defaults(Workspace)
		local spots: { { name: string, feet: Vector3, up: Vector3 } } = {
			{
				name = "stuck spot 1",
				feet = Vector3.new(69.2, 11.6036, -61),
				up = Vector3.new(0.8267, 0.5524, -0.1065).Unit,
			},
			{
				name = "stuck spot 2",
				feet = Vector3.new(69.2, 11.7288, -59),
				up = Vector3.new(0.6058, 0.7956, 0.0002).Unit,
			},
			{
				name = "stuck spot 3",
				feet = Vector3.new(69.2, 11.7282, -57),
				up = Vector3.new(0.6058, 0.7956, 0.0002).Unit,
			},
			{
				name = "stuck spot 4",
				feet = Vector3.new(69.2, 11.7276, -55),
				up = Vector3.new(0.6058, 0.7956, 0.0002).Unit,
			},
			{
				name = "bottom of the bowl",
				feet = Vector3.new(75, 6.0759, -58),
				up = Vector3.new(0.1949, 0.9799, -0.0424).Unit,
			},
		}
		local fitting: { string } = {}
		for _, spot in spots do
			if PathCheck.roomToStand(options, spot.feet, spot.up) then
				table.insert(fitting, spot.name)
			end
		end
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		expect(fitting).toEqual({})
	end)

	it("there is exactly one Tea part in the teacup", function()
		expect(#teaParts()).toBe(1)
	end)

	it("the tea is tea brown, smooth plastic and not see-through", function()
		local part = tea()
		expect(part.Color).toEqual(TEA_COLOUR)
		expect(part.Material).toBe(Enum.Material.SmoothPlastic)
		expect(part.Transparency).toBe(0)
	end)

	it("the tea is a round disc", function()
		local part = tea()
		expect(part:IsA("Part")).toBe(true)
		expect(part.Shape).toBe(Enum.PartType.Cylinder)
	end)

	it("nobody bumps into the tea, finds it with a check or touches it, and it stays put", function()
		local part = tea()
		expect(part.CanCollide).toBe(false)
		expect(part.CanQuery).toBe(false)
		expect(part.CanTouch).toBe(false)
		expect(part.Anchored).toBe(true)
	end)

	it("the tea is 0.4 studs thick and as wide as the bowl's inside plus 0.3 studs each side", function()
		local part = tea()
		expect(math.abs(part.Size.X - TEA_THICKNESS) < TOLERANCE).toBe(true)
		expect(math.abs(part.Size.Y - TEA_RADIUS * 2) < TOLERANCE).toBe(true)
		expect(math.abs(part.Size.Z - TEA_RADIUS * 2) < TOLERANCE).toBe(true)
	end)

	it("the tea lies in the same tilt as the cup's rim", function()
		local part = tea()
		local expected = Vector3.new(-RIM_SLOPE_X, 1, -RIM_SLOPE_Z).Unit
		expect((part.CFrame.RightVector - expected).Magnitude < 0.001).toBe(true)
	end)

	it("the tea's middle is the fitted circle's middle and its top is 0.5534 studs under the rim plane", function()
		local part = tea()
		local point = teaTop(part)
		expect(math.abs(point.X - CIRCLE_CENTRE_X) < TOLERANCE).toBe(true)
		expect(math.abs(point.Z - CIRCLE_CENTRE_Z) < TOLERANCE).toBe(true)
		local planeHeight = rimPlaneHeight(point.X, point.Z)
		expect(math.abs(planeHeight - TEA_DROP - point.Y) < TOLERANCE).toBe(true)
	end)

	it("the tea never shows above the rim: it is at least 0.1 studs under the worst rim point", function()
		local part = tea()
		-- the worst crest point is 0.45336 under the plane; the tea's top is 0.1 under it
		local gap = WORST_RIM_Y - teaTopHeightAt(part, WORST_RIM_X, WORST_RIM_Z)
		expect(gap >= 0.1 - 0.001).toBe(true)
	end)

	it("a player on top of the filled bowl stands 0.4 to 1.0 studs over the tea, west, middle and east", function()
		local part = tea()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { teacup() }
		params.RespectCanCollide = true -- sees only what a player bumps into
		local points: { [string]: Vector3 } = {
			west = Vector3.new(68, 0, -58),
			middle = Vector3.new(76, 0, -58),
			east = Vector3.new(86, 0, -58),
		}
		local bad: { string } = {}
		for name, point in points do
			local hit = Workspace:Raycast(Vector3.new(point.X, 60, point.Z), Vector3.new(0, -80, 0), params)
			if hit == nil then
				table.insert(bad, `{name}: the ray hit nothing`)
			else
				local feetOver = hit.Position.Y - teaTopHeightAt(part, point.X, point.Z)
				if feetOver < FEET_NEAREST or feetOver > FEET_FARTHEST then
					table.insert(bad, `{name}: feet {string.format("%.2f", feetOver)} studs over the tea`)
				end
			end
		end
		table.sort(bad)
		expect(bad).toEqual({})
	end)
end)

-- Stuck safety Task 19: his real shape (docs/plans/v2/stuck-safety.md, "How his real shape is patched"). The giant's six
-- body pieces keep Roblox's closest collision match of the mesh players see (tools/world/15-real-shape.luau), so the
-- surface players stand on is the skin they see. The pieces stay in the normal collision group, so players, every check
-- and the camera all meet the same surface. These tests only READ the world.
describe("the real world, his real shape", function()
	local Workspace = game:GetService("Workspace")

	local function bodyMesh(pieceName: string): MeshPart
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local giant = (world :: Instance):FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local piece = (giant :: Instance):FindFirstChild(pieceName)
		expect(piece).never.toBeNil()
		local mesh = (piece :: Instance):FindFirstChild(pieceName)
		expect(mesh).never.toBeNil()
		expect((mesh :: Instance):IsA("MeshPart")).toBe(true)
		return mesh :: MeshPart
	end

	-- Task 26 ("Ruling after step 26-3", and Ruling 9 after step 26-4e): the belly and chair, the legs, the head and the
	-- nightcap use the closer fit (Tunable at CollisionPrecision 1). Both arms keep Roblox's Precise shape.
	local CLOSER_FIT_PIECES: { [string]: boolean } = {
		legs_and_boots = true,
		body_and_cushion = true,
		head_with_beard = true,
		nightcap = true,
	}
	local CLOSER_FIT_PRECISION = 0.99

	it("his six body pieces use his real shape", function()
		local wrong: { string } = {}
		for _, pieceName in BODY_PIECES do
			local mesh = bodyMesh(pieceName)
			local wanted = if CLOSER_FIT_PIECES[pieceName]
				then Enum.CollisionFidelity.Tunable
				else Enum.CollisionFidelity.PreciseConvexDecomposition
			local precisionOk = not CLOSER_FIT_PIECES[pieceName] or mesh.CollisionPrecision >= CLOSER_FIT_PRECISION
			if mesh.CollisionFidelity ~= wanted or not precisionOk then
				local precisionText = string.format("%.2f", mesh.CollisionPrecision)
				local wantedText = wanted.Name
				if CLOSER_FIT_PIECES[pieceName] then
					wantedText ..= " with CollisionPrecision at least 0.99"
				end
				table.insert(
					wrong,
					`{pieceName}: CollisionFidelity is {mesh.CollisionFidelity.Name}, CollisionPrecision {precisionText}, wanted {wantedText}`
				)
			end
			if not (mesh.CanCollide and mesh.CanQuery and mesh.CanTouch) then
				table.insert(
					wrong,
					`{pieceName}: CanCollide {mesh.CanCollide}, CanQuery {mesh.CanQuery}, CanTouch {mesh.CanTouch}`
				)
			end
			if mesh.CollisionGroup ~= "Default" then
				table.insert(wrong, `{pieceName}: CollisionGroup is {mesh.CollisionGroup}`)
			end
		end
		expect(wrong).toEqual({})
	end)
end)

-- Stuck safety Task 26: his solid shape sits on his drawn skin (docs/plans/v2/stuck-safety.md, Task 26; spec 2 Rule 20,
-- "One collision source", check 6). His solid shape is what a player stands on. His drawn skin is the mesh Roblox
-- paints, plus any shirt folds (see DrawnSkin). Wherever a player can stand on his six body pieces, the solid shape may
-- be at most 0.2 studs above the drawn skin and 0.3 studs below it. These tests only READ the world (the two "can fail"
-- tests move one spot in memory, or one clone of the truss, and destroy it again).
describe("the real world, his solid body sits where he's drawn", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")

	local GRID_STEP = 1 -- studs: the spots checked are this far apart, on a grid over the whole giant
	local MAX_SURFACES = 200 -- most surfaces one column can have (a safety stop, as in PathCheck)
	local RAY_RESTART = 0.01 -- studs: the next ray down a column starts this far below the last surface it hit
	local COLUMNS_PER_YIELD = 200 -- the scan lets Studio breathe this often
	local SPOT_RAY_ABOVE = 3 -- studs: a spot's ray starts this far over it
	local SPOT_RAY_BELOW = 5 -- studs: ...and the spot is "on his body" if the ray hits it within this far under it
	local MAX_EXAMPLES = 3 -- most examples written out for each piece
	local BUILD_TIMEOUT_MS = 60000 -- reading the six meshes takes a few seconds
	local TEST_TIMEOUT_MS = 60000
	-- Task 24's belly-top climb: a player stands here (x, z) and walks into the beard ladder's climbing truss, `Climb`.
	-- It is where V1's truss foot is.
	local BELLY_TOP_X = 0
	local BELLY_TOP_Z = -24.5
	local MIN_TRUSS_OVERLAP = 1 -- studs: a standing player's head reaches this far into the truss
	local FOOTPRINT_STEP = 0.25 -- studs between the places under a standing player's body that are read

	local skin: DrawnSkin.Skin = nil :: any

	local function realWorld(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

	local function bodyMeshes(): { MeshPart }
		local giant = realWorld():FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local meshes: { MeshPart } = {}
		for _, name in BODY_PIECES do
			local model = (giant :: Instance):FindFirstChild(name)
			expect(model).never.toBeNil()
			local mesh = (model :: Instance):FindFirstChild(name)
			expect(mesh).never.toBeNil()
			expect((mesh :: Instance):IsA("MeshPart")).toBe(true)
			table.insert(meshes, mesh :: MeshPart)
		end
		return meshes
	end

	-- The shirt folds: soft blocks and wedges in World.Giant.ShirtFolds that players pass through (none until Task 26
	-- adds them).
	local function shirtFolds(): { BasePart }
		local giant = realWorld():FindFirstChild("Giant")
		local folder = if giant then giant:FindFirstChild("ShirtFolds") else nil
		local folds: { BasePart } = {}
		if folder then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(folds, descendant)
				end
			end
		end
		return folds
	end

	-- A ray that sees only his solid shape (the six body pieces).
	local function bodyParams(meshes: { MeshPart }): RaycastParams
		local included: { Instance } = {}
		for _, mesh in meshes do
			table.insert(included, mesh)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = included
		params.RespectCanCollide = false
		return params
	end

	-- The box that holds all of the given parts, as (lowest corner, highest corner).
	local function boundsOf(parts: { MeshPart }): (Vector3, Vector3)
		local low = Vector3.new(math.huge, math.huge, math.huge)
		local high = -low
		for _, part in parts do
			local right, up, look = part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector
			local size = part.Size
			local reach = Vector3.new(
				(math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z) / 2,
				(math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z) / 2,
				(math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z) / 2
			)
			low = low:Min(part.Position - reach)
			high = high:Max(part.Position + reach)
		end
		return low, high
	end

	-- gap: solid shape height minus drawn skin height straight under the spot. sideways: only set when that gap is outside
	-- the limits but the drawn skin within SKIN_SIDE_REACH studs sideways fits them (product's measuring rule, check 6):
	-- then it is the gap to that skin. (The limits and the search are at the top of this file.)
	type Gap = { piece: string, position: Vector3, gap: number, sideways: number? }

	-- A spot fails outright when neither the skin under it nor the skin within SKIN_SIDE_REACH sideways fits the limits.
	local function failsOutright(entry: Gap): boolean
		return outsideLimits(entry.gap) and entry.sideways == nil
	end

	-- A spot passes only because of the sideways search when the skin under it does not fit but the skin beside it does.
	local function passesBySideways(entry: Gap): boolean
		return outsideLimits(entry.gap) and entry.sideways ~= nil
	end

	-- Every place a player can stand on his body, on a 1-stud grid over the giant. It follows the game's own walk map
	-- (PathCheck.findSpots): a ray down each column through every surface of his six pieces; a surface counts when its
	-- slope is under the walking limit and a player's body fits standing on it (PathCheck.roomToStand), which also drops
	-- the faces hidden inside his solid shape. `gap` is NaN where no drawn skin is under the spot at all.
	local function standableGaps(): ({ Gap }, number)
		local meshes = bodyMeshes()
		local params = bodyParams(meshes)
		local low, high = boundsOf(meshes)
		local options = PathCheck.defaults(Workspace)
		local walkable = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
		local gaps: { Gap } = {}
		local columns = 0
		for x = math.floor(low.X) + GRID_STEP / 2, high.X, GRID_STEP do
			for z = math.floor(low.Z) + GRID_STEP / 2, high.Z, GRID_STEP do
				local startY = high.Y + 1
				for _ = 1, MAX_SURFACES do
					local hit =
						Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -(startY - low.Y + 1), 0), params)
					if hit == nil then
						break
					end
					if hit.Normal.Y >= walkable and PathCheck.roomToStand(options, hit.Position, hit.Normal) then
						local drawn = skin.heightAt(x, z, hit.Position.Y + SKIN_SEARCH_ABOVE)
						local gap = if drawn == nil then 0 / 0 else hit.Position.Y - drawn
						table.insert(gaps, {
							piece = hit.Instance.Name,
							position = hit.Position,
							gap = gap,
							sideways = if outsideLimits(gap) then sidewaysFit(skin, x, z, hit.Position.Y) else nil,
						})
					end
					startY = hit.Position.Y - RAY_RESTART
				end
				columns += 1
				if columns % COLUMNS_PER_YIELD == 0 then
					task.wait()
				end
			end
		end
		PathCheck.cleanup(options)
		return gaps, #gaps
	end

	local allGaps: { Gap } = {}
	local allSpots = 0

	-- How many spots pass only because of the sideways search, and the worst of them (the one furthest outside the
	-- limits straight under it), as a sentence for the report.
	local function sidewaysSummary(gaps: { Gap }): string
		local count = 0
		local worst: Gap? = nil
		local worstOutside = -1
		for _, entry in gaps do
			if passesBySideways(entry) then
				count += 1
				local outside = if entry.gap ~= entry.gap
					then math.huge
					elseif entry.gap > 0 then entry.gap - ABOVE_LIMIT
					else -BELOW_LIMIT - entry.gap
				if outside > worstOutside then
					worstOutside = outside
					worst = entry
				end
			end
		end
		if worst == nil then
			return `none pass only because of the {SKIN_SIDE_REACH}-stud sideways search`
		end
		local example = worst :: Gap
		return `{count} more pass only because of the {SKIN_SIDE_REACH}-stud sideways search (worst: {describePoint(
			example.position
		)} is {string.format("%+.2f", example.gap)} over the skin under it and {string.format(
			"%+.2f",
			example.sideways :: number
		)} over the skin beside it)`
	end

	beforeAll(function()
		skin = DrawnSkin.fromWorld(bodyMeshes(), shirtFolds())
		allGaps, allSpots = standableGaps()
	end, BUILD_TIMEOUT_MS)

	type PieceTally = {
		over: number,
		under: number,
		noSkin: number,
		worstOver: Gap?,
		worstUnder: Gap?,
		examples: { string },
	}

	-- The problems, one line per piece that has any, with its worst spots and the first few.
	local function gapProblems(gaps: { Gap }): { string }
		local tallies: { [string]: PieceTally } = {}
		for _, entry in gaps do
			if failsOutright(entry) then
				local tally = tallies[entry.piece]
				if tally == nil then
					tally = { over = 0, under = 0, noSkin = 0, examples = {} }
					tallies[entry.piece] = tally
				end
				local current = tally :: PieceTally
				if entry.gap ~= entry.gap then
					current.noSkin += 1
				elseif entry.gap > 0 then
					current.over += 1
					if current.worstOver == nil or entry.gap > (current.worstOver :: Gap).gap then
						current.worstOver = entry
					end
				else
					current.under += 1
					if current.worstUnder == nil or entry.gap < (current.worstUnder :: Gap).gap then
						current.worstUnder = entry
					end
				end
				if #current.examples < MAX_EXAMPLES then
					table.insert(
						current.examples,
						`{describePoint(entry.position)} {string.format("%+.2f", entry.gap)}`
					)
				end
			end
		end
		local problems: { string } = {}
		for _, name in BODY_PIECES do
			local tally = tallies[name]
			if tally then
				local parts: { string } = {}
				if tally.over > 0 then
					local worst = tally.worstOver :: Gap
					table.insert(
						parts,
						`{tally.over} over (worst {string.format("%+.2f", worst.gap)} at {describePoint(worst.position)})`
					)
				end
				if tally.under > 0 then
					local worst = tally.worstUnder :: Gap
					table.insert(
						parts,
						`{tally.under} under (worst {string.format("%+.2f", worst.gap)} at {describePoint(
							worst.position
						)})`
					)
				end
				if tally.noSkin > 0 then
					table.insert(parts, `{tally.noSkin} with no drawn skin under them`)
				end
				table.insert(
					problems,
					`{name}: {table.concat(parts, ", ")}; first: {table.concat(tally.examples, ", ")}`
				)
			end
		end
		return problems
	end

	it("his solid shape is at most 0.2 over and 0.3 under his drawn skin everywhere a player can stand", function()
		expect(allSpots > 1000).toBe(true) -- the grid really found his body
		local bad = 0
		for _, entry in allGaps do
			if failsOutright(entry) then
				bad += 1
			end
		end
		local summary = `{bad} of {allSpots} standable spots fail outright; {sidewaysSummary(allGaps)}`
		print("check 6: " .. summary) -- both counts show even when the test passes
		local problems = gapProblems(allGaps)
		if #problems > 0 then
			table.insert(problems, 1, summary)
		end
		expect(problems).toEqual({})
	end, TEST_TIMEOUT_MS)

	-- Proof that the sideways search bites (product's measuring rule, check 6). A made-up skin has a step: flat at height
	-- 1 for x under 0 and flat at height 0 from x 0 on. A spot 0.2 from the step, with the solid shape 1.1 high, is far
	-- above the low skin under it but fits the high skin beside it, so it passes by the sideways search. A spot 0.5 from
	-- the step has no fitting skin within 0.3, and a spot with the solid shape 3 high fits nowhere.
	describe("the sideways search", function()
		local function flat(x0: number, x1: number, height: number): { DrawnSkin.Triangle }
			local a, b = Vector3.new(x0, height, -10), Vector3.new(x1, height, -10)
			local c, d = Vector3.new(x1, height, 10), Vector3.new(x0, height, 10)
			return { { a = a, b = b, c = c }, { a = a, b = c, c = d } }
		end

		local function steppedSkin(): DrawnSkin.Skin
			local triangles = flat(-10, 0, 1)
			for _, triangle in flat(0, 10, 0) do
				table.insert(triangles, triangle)
			end
			return DrawnSkin.new(triangles, {})
		end

		it("passes a spot whose own skin is far below but whose skin 0.2 beside it fits", function()
			local reader = steppedSkin()
			expect(outsideLimits(1.1 - (reader.heightAt(0.2, 0, 2) :: number))).toBe(true)
			local gap = sidewaysFit(reader, 0.2, 0, 1.1)
			expect(gap).never.toBeNil()
			expect(math.abs((gap :: number) - 0.1) < 0.001).toBe(true)
		end)

		it("fails a spot with no fitting skin within 0.3 sideways", function()
			expect(sidewaysFit(steppedSkin(), 0.5, 0, 1.1)).toBeNil()
		end)

		it("fails a spot whose solid shape is too high for any skin beside it", function()
			expect(sidewaysFit(steppedSkin(), 0.2, 0, 3)).toBeNil()
		end)

		it("counts a spot only once: outright failure and sideways pass are separate", function()
			local entry: Gap = { piece = "x", position = Vector3.zero, gap = 1.1, sideways = 0.1 }
			expect(passesBySideways(entry)).toBe(true)
			expect(failsOutright(entry)).toBe(false)
			entry.sideways = nil
			expect(passesBySideways(entry)).toBe(false)
			expect(failsOutright(entry)).toBe(true)
		end)
	end)

	-- Proof that the method reads his skin right: his left arm's solid shape follows its skin to 0.13 studs (measured
	-- in Task 25), so every standable spot on it must read within the limits. A wrong mapping of the mesh into the world
	-- (a turned, mirrored or mis-scaled skin) would fail this at once.
	it("reads the drawn skin of his left arm where its solid shape is", function()
		local checked = 0
		local outside: { string } = {}
		for _, entry in allGaps do
			if entry.piece == "left_arm" then
				checked += 1
				if failsOutright(entry) and #outside < MAX_EXAMPLES then
					table.insert(outside, `{describePoint(entry.position)} {string.format("%+.2f", entry.gap)}`)
				end
			end
		end
		expect(checked > 50).toBe(true)
		expect(outside).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Eggs, footprints and landing spots on his drawn skin
	----------------------------------------------------------------------------------------------------------------

	type Spot = { name: string, position: Vector3 }

	-- Every egg spot (the top of its Base), footprint route point and landing spot. Nests are added by plan 5.
	local function worldSpots(): { Spot }
		local world = realWorld()
		local spots: { Spot } = {}
		local eggSpots, eggProblems = WorldIndex.readEggSpots(world)
		expect(eggProblems).toEqual({})
		for _, spot in eggSpots :: { WorldIndex.EggSpot } do
			table.insert(spots, { name = spot.name, position = spot.cframe.Position })
		end
		local route, routeProblems = WorldIndex.readRoute(world)
		expect(routeProblems).toEqual({})
		for _, point in route :: { WorldIndex.RoutePoint } do
			table.insert(spots, { name = `route point {point.name}`, position = point.position })
		end
		local landings, landingProblems = WorldIndex.readLandingSpots(world)
		expect(landingProblems).toEqual({})
		for _, landing in landings :: { WorldIndex.LandingSpot } do
			table.insert(spots, { name = `LandingSpot_{landing.index}`, position = landing.position })
		end
		return spots
	end

	-- The spots that are on his body, and the problems with those. A spot is on his body when the first thing a player
	-- would stand on under it (a ray that sees what the Players group collides with) is one of his six pieces, within
	-- a few studs. A spot on a crossing ramp or a ladder is not: those float over his skin by design.
	local function spotProblems(spots: { Spot }): ({ string }, number)
		local meshes = bodyMeshes()
		local ground = RaycastParams.new()
		ground.RespectCanCollide = true
		ground.CollisionGroup = Collisions.GROUP
		local problems: { string } = {}
		local onBody = 0
		for _, spot in spots do
			local start = spot.position + Vector3.new(0, SPOT_RAY_ABOVE, 0)
			local hit = Workspace:Raycast(start, Vector3.new(0, -(SPOT_RAY_ABOVE + SPOT_RAY_BELOW), 0), ground)
			if hit and table.find(meshes, hit.Instance :: any) ~= nil then
				onBody += 1
				local drawn = skin.heightAt(spot.position.X, spot.position.Z, start.Y)
				if drawn == nil then
					table.insert(problems, `{spot.name} {describePoint(spot.position)}: no drawn skin under it`)
				else
					local gap = spot.position.Y - drawn
					if outsideLimits(gap) then
						table.insert(
							problems,
							`{spot.name} {describePoint(spot.position)}: {string.format("%+.2f", gap)} from his drawn skin`
						)
					end
				end
			end
		end
		return problems, onBody
	end

	it("eggs, footprints and landing spots on his body sit on his drawn skin", function()
		local problems, onBody = spotProblems(worldSpots())
		expect(onBody > 5).toBe(true) -- the Rare eggs, the belly route and the boots, at least
		expect(problems).toEqual({})
	end, TEST_TIMEOUT_MS)

	-- Proof that the test above can fail: one spot that passes, moved 0.5 studs up, and then 0.5 studs down.
	it("the spot check notices a spot 0.5 studs too high or too low", function()
		local sound: Spot? = nil
		for _, spot in worldSpots() do
			local problems, onBody = spotProblems({ spot })
			if onBody == 1 and #problems == 0 then
				sound = spot
				break
			end
		end
		expect(sound).never.toBeNil()
		local original = sound :: Spot
		local higher = spotProblems({ { name = original.name, position = original.position + Vector3.new(0, 0.5, 0) } })
		local lower = spotProblems({ { name = original.name, position = original.position - Vector3.new(0, 0.5, 0) } })
		expect({ higher = #higher, lower = #lower }).toEqual({ higher = 1, lower = 1 })
	end, TEST_TIMEOUT_MS)

	----------------------------------------------------------------------------------------------------------------
	-- The beard ladder is within reach of a player standing on his belly top
	----------------------------------------------------------------------------------------------------------------

	local function beardTruss(): BasePart
		local walk = realWorld():FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local ladder = (walk :: Instance):FindFirstChild("BeardLadder")
		expect(ladder).never.toBeNil()
		local truss = (ladder :: Instance):FindFirstChild("Climb")
		expect(truss).never.toBeNil()
		return truss :: BasePart
	end

	-- Where his solid shape is at the belly-top spot: the height a player's feet stand at.
	local function bellyTopStandY(): number
		local meshes = bodyMeshes()
		local low, high = boundsOf(meshes)
		local hit = Workspace:Raycast(
			Vector3.new(BELLY_TOP_X, high.Y + 1, BELLY_TOP_Z),
			Vector3.new(0, -(high.Y - low.Y + 2), 0),
			bodyParams(meshes)
		)
		expect(hit).never.toBeNil()
		return (hit :: RaycastResult).Position.Y
	end

	-- How far a player's head, standing with feet at `standY`, reaches into the truss: the top of the body minus the
	-- lowest point of the truss anywhere over the body's footprint. Negative: the head is under the truss.
	local function trussOverlap(truss: BasePart, standY: number): number
		local solid = DrawnSkin.solidOf(truss)
		local half = Config.Stuck.BodyWidth / 2
		local lowest = math.huge
		for dx = -half, half, FOOTPRINT_STEP do
			for dz = -half, half, FOOTPRINT_STEP do
				local bottom = DrawnSkin.columnSpan(solid, BELLY_TOP_X + dx, BELLY_TOP_Z + dz)
				if bottom ~= nil then
					lowest = math.min(lowest, bottom)
				end
			end
		end
		return standY + Config.Stuck.BodyHeight - lowest
	end

	it("a player on his belly top can grab the beard ladder: his head reaches 1 stud into its truss", function()
		local overlap = trussOverlap(beardTruss(), bellyTopStandY())
		expect({ overlap = overlap, reaches = overlap >= MIN_TRUSS_OVERLAP }).toEqual({
			overlap = overlap,
			reaches = true,
		})
	end)

	-- Proof that the test above can fail: the same truss 3 studs higher is out of reach.
	it("the truss check notices a truss 3 studs too high", function()
		local standY = bellyTopStandY()
		local raised = beardTruss():Clone()
		raised.CFrame = raised.CFrame + Vector3.new(0, 3, 0)
		local realOverlap = trussOverlap(beardTruss(), standY)
		local raisedOverlap = trussOverlap(raised, standY)
		raised:Destroy()
		expect(realOverlap >= MIN_TRUSS_OVERLAP).toBe(true)
		expect(raisedOverlap < MIN_TRUSS_OVERLAP).toBe(true)
	end)
end)

-- Stuck safety Task 24: V1's invisible walk pieces on his legs and belly sit on his skin (docs/plans/v2/stuck-safety.md,
-- Task 24; spec 2 Rule 20, "One collision source", checks 2 and 4). A walk piece is an invisible board that players walk
-- on. Its whole top must lie 0.2 studs below to 0.7 studs above his skin, checked about every stud. Where a near-vertical
-- wall of his skin cannot be fitted (his left boot's top edge and his knee), a short solid crossing ramp joins the path
-- instead, held to the same window only along the two edges where players step on and off. These tests only READ the
-- world (the two "can fail" tests build one test part far from the map and destroy it again).
describe("the real world, the walk pieces sit on his skin", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")

	local WALK_NAMES: { [string]: boolean } = { Boots_Walk = true, RightBoots_Walk = true, Belly_Walk = true }
	-- Stuck safety Task 25: the head's invisible walk pieces (V1's nose deck and its three nightcap pieces). His real
	-- skin is walkable there, so the task removes them all; the walk-piece test below checks any that are left.
	local HEAD_WALK_NAMES: { [string]: boolean } = { Nose_Walk = true, Nightcap_Walk = true }
	-- Source: tools/world/15-real-shape.luau section 2b removes all four (stuck safety Task 25, "What changes" 1 and 2).
	local EXPECTED_HEAD_WALK_PIECES = 0
	local WINDOW_BELOW = 0.2 -- studs: a walk top may be this far under his skin
	local WINDOW_ABOVE = 0.7 -- studs: ...and this far over it
	local WINDOW_SLACK = 0.001 -- studs: rounding in the numbers written into the world
	local GRID_STEP = 1 -- studs: the points checked on a top are at most this far apart
	local GRID_INSET = 0.5 -- studs: ...and this far in from every edge, with both inner edges included
	local RAY_ABOVE = 12
	local RAY_LENGTH = 24
	local MAX_EXAMPLES = 3 -- most examples written out for each piece
	local MAX_RAMPS = 3
	local RAMP_NAMES: { [string]: boolean } = {
		CrossingRamp_Ankle = true,
		CrossingRamp_Knee = true,
		CrossingRamp_Steep = true,
	}
	local MAX_RAMP_DEGREES = 45
	-- The stretch crossing ramps may stand in: his left leg between the left boot top and Rare egg 1 (the stretch that
	-- plan 3, Task 6 removes). Rare egg 1's top is at (-12.5, 41.3, -40.3); the boot top's step is at z -60.4.
	local STRETCH_MIN = Vector3.new(-32, 24, -61)
	local STRETCH_MAX = Vector3.new(-8, 43, -38.5)
	local WALL_DEGREES = 70 -- a wall step is steeper than this...
	local WALL_RISE = 0.5 -- ...and rises more than this
	local STEEP_BODY_DEGREES = 65 -- or the body-size slope is this steep or more (the seam angle)
	local PROFILE_STEP = 0.1 -- studs between the places a span's profile is read
	local BODY_PATCH_REACH = 2 -- the body-size slope: 25 rays 1 stud apart on a 4 by 4 stud square
	local SLOT_REACH = 8 -- studs: how far under a piece a slot is looked for
	local EDGE_ROW = 0.51 -- studs: the rows of a ramp top that count as its step-on and step-off edges

	local function realWorld(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return world :: Instance
	end

	local function walkFolder(): Instance
		local walk = realWorld():FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		return walk :: Instance
	end

	-- His six body pieces.
	local function bodyInstances(): { Instance }
		local giant = realWorld():FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local meshes: { Instance } = {}
		for _, name in BODY_PIECES do
			local model = (giant :: Instance):FindFirstChild(name)
			expect(model).never.toBeNil()
			local mesh = (model :: Instance):FindFirstChild(name)
			expect(mesh).never.toBeNil()
			table.insert(meshes, mesh :: Instance)
		end
		return meshes
	end

	-- A ray that sees only his six body pieces.
	local function bodyParams(): RaycastParams
		local params = RaycastParams.new()
		params.IncludeInstances = bodyInstances()
		params.RespectCanCollide = false
		return params
	end

	-- The places along one side of a top: GRID_INSET in from both edges, at most GRID_STEP apart, both inner edges included.
	local function axisPoints(extent: number): { number }
		local span = extent - 2 * GRID_INSET
		if span <= 0 then
			return { 0 }
		end
		local count = math.ceil(span / GRID_STEP)
		local points: { number } = {}
		for index = 0, count do
			table.insert(points, -span / 2 + span * index / count)
		end
		return points
	end

	-- The grid of a flat piece's top, in world space.
	local function topGrid(cframe: CFrame, size: Vector3): { Vector3 }
		local points: { Vector3 } = {}
		for _, x in axisPoints(size.X) do
			for _, z in axisPoints(size.Z) do
				table.insert(points, cframe:PointToWorldSpace(Vector3.new(x, size.Y / 2, z)))
			end
		end
		return points
	end

	-- Where his skin is under `point`: a ray straight down from RAY_ABOVE over it, RAY_LENGTH long.
	local function skinUnder(params: RaycastParams, point: Vector3): RaycastResult?
		return Workspace:Raycast(point + Vector3.new(0, RAY_ABOVE, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
	end

	local function walkPieces(): { BasePart }
		local pieces: { BasePart } = {}
		for _, piece in walkFolder():GetChildren() do
			if piece:IsA("BasePart") and WALK_NAMES[piece.Name] then
				table.insert(pieces, piece)
			end
		end
		return pieces
	end

	local function headWalkPieces(): { BasePart }
		local pieces: { BasePart } = {}
		for _, piece in walkFolder():GetChildren() do
			if piece:IsA("BasePart") and HEAD_WALK_NAMES[piece.Name] then
				table.insert(pieces, piece)
			end
		end
		return pieces
	end

	local function crossingRamps(): { BasePart }
		local ramps: { BasePart } = {}
		for _, piece in walkFolder():GetChildren() do
			if piece:IsA("BasePart") and string.match(piece.Name, "^CrossingRamp_") then
				table.insert(ramps, piece)
			end
		end
		return ramps
	end

	it("the invisible walk pieces sit on his skin", function()
		local params = bodyParams()
		local over, under, noSkin, total = 0, 0, 0, 0
		local examples: { string } = {}
		local checkedPieces: { BasePart } = walkPieces()
		local headPieces: { BasePart } = headWalkPieces()
		for _, piece in headPieces do
			table.insert(checkedPieces, piece)
		end
		for _, piece in checkedPieces do
			local shown = 0
			for _, point in topGrid(piece.CFrame, piece.Size) do
				total += 1
				local problem: string? = nil
				local hit = skinUnder(params, point)
				if hit == nil then
					noSkin += 1
					problem = `no skin within {RAY_ABOVE} studs`
				else
					local gap = point.Y - hit.Position.Y
					if gap > WINDOW_ABOVE + WINDOW_SLACK then
						over += 1
						problem = string.format("%.2f studs over his skin (the most is %g)", gap, WINDOW_ABOVE)
					elseif gap < -WINDOW_BELOW - WINDOW_SLACK then
						under += 1
						problem =
							string.format("his skin pokes %.2f studs through (the most is %g)", -gap, WINDOW_BELOW)
					end
				end
				if problem ~= nil and shown < MAX_EXAMPLES then
					shown += 1
					table.insert(examples, `{piece.Name} at {describePoint(point)}: {problem}`)
				end
			end
		end
		expect(total > 0).toBe(true)
		expect({
			headPieces = #headPieces,
			over = over,
			under = under,
			noSkin = noSkin,
			examples = examples,
		}).toEqual({
			headPieces = EXPECTED_HEAD_WALK_PIECES,
			over = 0,
			under = 0,
			noSkin = 0,
			examples = {},
		})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Ladder ends (stuck safety Task 25, test 2)
	----------------------------------------------------------------------------------------------------------------

	local END_BELOW = 0.3 -- studs: a ladder's end may be this far under the ground a climber steps onto...
	local END_ABOVE = 0.7 -- studs: ...and this far over it
	local END_PAST = 1 -- studs: at a top, the ground is read this far past the end, along the ladder's flat direction
	local END_RAY_ABOVE = 2 -- studs: the ground ray starts this far over the highest (or lowest) point of the ladder
	local END_TOUCH = 0.5 -- studs: an end rung is this close to his skin or closer

	-- The ladder's centre line is its truss, `Climb`: the longest side of the truss runs up the ladder.
	type LadderAxis = { foot: Vector3, top: Vector3, up: Vector3, flat: Vector3, back: Vector3 }

	local function ladderAxis(ladder: Instance): LadderAxis
		local truss = ladder:FindFirstChild("Climb")
		expect(truss).never.toBeNil()
		local part = truss :: BasePart
		local size = part.Size
		local length = math.max(size.X, size.Y, size.Z)
		local up = if size.X == length
			then part.CFrame.RightVector
			elseif size.Y == length then part.CFrame.UpVector
			else part.CFrame.LookVector
		if up.Y < 0 then
			up = -up
		end
		local flatPart = Vector3.new(up.X, 0, up.Z)
		local flat = flatPart.Unit
		-- "back" is toward his face: along the flat direction and tilted down, square to the ladder.
		local back = (flat * up.Y - Vector3.yAxis * flatPart.Magnitude).Unit
		return {
			foot = part.Position - up * length / 2,
			top = part.Position + up * length / 2,
			up = up,
			flat = flat,
			back = back,
		}
	end

	-- The highest (or lowest) point of any part of a ladder: its rails, rungs and the climbable truss.
	local function ladderExtreme(ladder: Instance, highest: boolean): number
		local extreme = if highest then -math.huge else math.huge
		for _, part in ladder:GetDescendants() do
			if part:IsA("BasePart") then
				local half = part.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner =
								part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							extreme = if highest then math.max(extreme, corner.Y) else math.min(extreme, corner.Y)
						end
					end
				end
			end
		end
		return extreme
	end

	-- The rung at the top (or foot) end of a ladder: the one farthest along (or against) the ladder's up direction.
	local function endRung(ladder: Instance, axis: LadderAxis, atTop: boolean): BasePart
		local found: BasePart? = nil
		local best = 0
		for _, child in ladder:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Rung" then
				local along = child.Position:Dot(axis.up) * (if atTop then 1 else -1)
				if found == nil or along > best then
					found, best = child, along
				end
			end
		end
		expect(found).never.toBeNil()
		return found :: BasePart
	end

	-- How far from the rung's surface, in `direction`, his skin is (nil when it is farther than `length`, default a stud).
	local function skinDistance(params: RaycastParams, rung: BasePart, direction: Vector3, length: number?): number?
		local cframe = rung.CFrame
		local half = rung.Size / 2
		local reach = half.X * math.abs(cframe.RightVector:Dot(direction))
			+ half.Y * math.abs(cframe.UpVector:Dot(direction))
			+ half.Z * math.abs(cframe.LookVector:Dot(direction))
		local hit = Workspace:Raycast(rung.Position + direction * reach, direction * (length or 1), params)
		return if hit then hit.Distance else nil
	end

	-- The ends of the ladders a climber steps on or off: the beard ladder's top, and the cap ladder's foot and top.
	-- Each end sits 0.3 studs under to 0.7 over the ground it meets, and its end rung touches his skin without being
	-- inside him (designer 3, 6 and 8).
	it("the ladder ends meet the walk surface, and each end rung touches him without sinking in", function()
		local walk = walkFolder()
		-- the ground a climber steps onto: his skin, or a head walk piece that is still there
		local ground = bodyParams()
		local included = bodyInstances()
		for _, piece in headWalkPieces() do
			table.insert(included, piece)
		end
		ground.IncludeInstances = included
		local overlap = OverlapParams.new()
		overlap.IncludeInstances = bodyInstances()
		overlap.RespectCanCollide = false
		local touching = bodyParams()

		local ends: { { label: string, ladder: string, atTop: boolean } } = {
			{ label = "beard ladder top", ladder = "BeardLadder", atTop = true },
			{ label = "cap ladder foot", ladder = "CapLadder", atTop = false },
			{ label = "cap ladder top", ladder = "CapLadder", atTop = true },
		}
		local problems: { string } = {}
		for _, ladderEnd in ends do
			local ladder = walk:FindFirstChild(ladderEnd.ladder)
			expect(ladder).never.toBeNil()
			local axis = ladderAxis(ladder :: Instance)
			local endHeight = ladderExtreme(ladder :: Instance, ladderEnd.atTop)
			local readAt = if ladderEnd.atTop then axis.top + axis.flat * END_PAST else axis.foot
			local hit = Workspace:Raycast(
				Vector3.new(readAt.X, endHeight + END_RAY_ABOVE, readAt.Z),
				Vector3.new(0, -2 * END_RAY_ABOVE - 6, 0),
				ground
			)
			if hit == nil then
				table.insert(problems, `{ladderEnd.label}: no ground found at {describePoint(readAt)}`)
			else
				local gap = endHeight - hit.Position.Y
				if gap > END_ABOVE + WINDOW_SLACK or gap < -END_BELOW - WINDOW_SLACK then
					table.insert(
						problems,
						string.format(
							"%s: the end is %+.2f studs from the ground at %s (it must be %g under to %g over)",
							ladderEnd.label,
							gap,
							describePoint(hit.Position),
							END_BELOW,
							END_ABOVE
						)
					)
				end
			end

			local rung = endRung(ladder :: Instance, axis, ladderEnd.atTop)
			local inside = Workspace:GetPartsInPart(rung, overlap)
			if #inside > 0 then
				table.insert(problems, `{ladderEnd.label}: its end rung is inside {inside[1].Name}`)
			end
			local down = skinDistance(touching, rung, Vector3.new(0, -1, 0))
			local behind = skinDistance(touching, rung, axis.back)
			local nearest = math.min(down or math.huge, behind or math.huge)
			if nearest > END_TOUCH + WINDOW_SLACK then
				table.insert(
					problems,
					string.format(
						"%s: its end rung is %s from his skin (it must touch within %g)",
						ladderEnd.label,
						if nearest == math.huge then "more than a stud" else string.format("%.2f studs", nearest),
						END_TOUCH
					)
				)
			end
		end
		expect(problems).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- The ladders sit close to him and keep their look (stuck safety Task 25, tests 3 and 4)
	----------------------------------------------------------------------------------------------------------------

	local RAIL_END_REACH = 0.5 -- studs: a rail may touch his skin this close to either of its ends, and no farther in
	local RAIL_TOUCH_GAP = 0.05 -- studs: a rail this close to his skin, or inside it, is touching
	local RAIL_STEP = 0.25 -- studs between the places along a rail that are checked
	local RAIL_RAY_FRONT = 3 -- studs: the ray that finds his skin behind a rail starts this far in front of the rail
	local CAP_MIN_DEGREES = 68 -- the cap ladder is this steep or steeper...
	local CAP_MAX_DEGREES = 72 -- ...and this steep or flatter (designer, shape B)
	local CAP_MIDDLE_REACH = 2 -- studs: the cap ladder's middle rung is this close to his face or closer
	local MIDDLE_TIE = 0.05 -- studs: two rungs this close to the middle are both "the middle rung"

	local function ladderParts(ladder: Instance, name: string): { BasePart }
		local found: { BasePart } = {}
		for _, child in ladder:GetChildren() do
			if child:IsA("BasePart") and child.Name == name then
				table.insert(found, child)
			end
		end
		return found
	end

	-- The direction a part's longest side runs, and that length.
	local function longSide(part: BasePart): (Vector3, number)
		local size = part.Size
		local length = math.max(size.X, size.Y, size.Z)
		local direction = if size.X == length
			then part.CFrame.RightVector
			elseif size.Y == length then part.CFrame.UpVector
			else part.CFrame.LookVector
		return direction, length
	end

	-- How far behind a rail's back face his skin starts, `along` studs from the rail's middle: negative when the rail is
	-- inside him, nil when his skin is more than a couple of studs away. The ray starts in front of the rail, so a
	-- rail that is buried still finds the skin in front of it.
	local function railGap(
		params: RaycastParams,
		rail: BasePart,
		direction: Vector3,
		back: Vector3,
		along: number
	): number?
		local cframe = rail.CFrame
		local half = rail.Size / 2
		local reach = half.X * math.abs(cframe.RightVector:Dot(back))
			+ half.Y * math.abs(cframe.UpVector:Dot(back))
			+ half.Z * math.abs(cframe.LookVector:Dot(back))
		local origin = rail.Position + direction * along - back * (reach + RAIL_RAY_FRONT)
		local hit = Workspace:Raycast(origin, back * (2 * reach + RAIL_RAY_FRONT + 2), params)
		return if hit then hit.Distance - (2 * reach + RAIL_RAY_FRONT) else nil
	end

	-- The rails of one ladder that touch his skin farther than RAIL_END_REACH from their ends: one line for each.
	local function railTouchProblems(
		params: RaycastParams,
		ladderName: string,
		ladder: Instance,
		back: Vector3
	): { string }
		local problems: { string } = {}
		for _, rail in ladderParts(ladder, "Rail") do
			local direction, length = longSide(rail)
			local touches = 0
			local first: Vector3? = nil
			for step = 0, math.ceil(length / RAIL_STEP) do
				local distance = math.min(step * RAIL_STEP, length)
				if math.min(distance, length - distance) > RAIL_END_REACH then
					local along = distance - length / 2
					local gap = railGap(params, rail, direction, back, along)
					if gap ~= nil and gap <= RAIL_TOUCH_GAP then
						touches += 1
						first = first or (rail.Position + direction * along)
					end
				end
			end
			if touches > 0 then
				table.insert(
					problems,
					string.format(
						"%s: a rail touches his skin at %d places away from its ends (the first near %s)",
						ladderName,
						touches,
						describePoint(first :: Vector3)
					)
				)
			end
		end
		return problems
	end

	-- The ladders sit on his face: no rung sinks into him, a rail touches him only within 0.5 studs of its ends, and the
	-- cap ladder is 68 to 72 degrees steep with its middle rung within 2 studs of his face (designer 4 and 8).
	it("no rung sinks into him, and the cap ladder stays close to his face", function()
		local walk = walkFolder()
		local overlap = OverlapParams.new()
		overlap.IncludeInstances = bodyInstances()
		overlap.RespectCanCollide = false
		local params = bodyParams()
		local problems: { string } = {}

		for _, ladderName in { "BeardLadder", "CapLadder" } do
			local ladder = walk:FindFirstChild(ladderName)
			expect(ladder).never.toBeNil()
			local axis = ladderAxis(ladder :: Instance)

			local sunk = 0
			local firstSunk: Vector3? = nil
			for _, rung in ladderParts(ladder :: Instance, "Rung") do
				if #Workspace:GetPartsInPart(rung, overlap) > 0 then
					sunk += 1
					firstSunk = firstSunk or rung.Position
				end
			end
			if sunk > 0 then
				table.insert(
					problems,
					`{ladderName}: {sunk} rungs are inside him (the first at {describePoint(firstSunk :: Vector3)})`
				)
			end

			for _, line in railTouchProblems(params, ladderName, ladder :: Instance, axis.back) do
				table.insert(problems, line)
			end
		end

		local cap = walk:FindFirstChild("CapLadder")
		expect(cap).never.toBeNil()
		local capAxis = ladderAxis(cap :: Instance)
		local degrees = math.deg(math.asin(capAxis.up.Y))
		if degrees < CAP_MIN_DEGREES or degrees > CAP_MAX_DEGREES then
			table.insert(
				problems,
				string.format(
					"CapLadder: it is %.1f degrees steep (it must be %g to %g)",
					degrees,
					CAP_MIN_DEGREES,
					CAP_MAX_DEGREES
				)
			)
		end

		-- the middle rung (or rungs, when two are equally near the middle) looks back at his face along the ladder's back
		local middle = (capAxis.foot + capAxis.top) / 2
		local rungs = ladderParts(cap :: Instance, "Rung")
		local nearestToMiddle = math.huge
		for _, rung in rungs do
			nearestToMiddle = math.min(nearestToMiddle, math.abs((rung.Position - middle):Dot(capAxis.up)))
		end
		for _, rung in rungs do
			if math.abs((rung.Position - middle):Dot(capAxis.up)) <= nearestToMiddle + MIDDLE_TIE then
				local distance = skinDistance(params, rung, capAxis.back, CAP_MIDDLE_REACH)
				if distance == nil then
					table.insert(
						problems,
						`CapLadder: its middle rung at {describePoint(rung.Position)} is more than {CAP_MIDDLE_REACH} studs from his face`
					)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	-- What V1's ladders look like. Source: the V1 ladders as recorded before Task 25 (the state note's "STEP 1a" block,
	-- read again from the open place on 2026-10-20). Rails are cylinders 0.45 across, rungs are blocks, the truss is the
	-- invisible climbable part.
	type PartLook = {
		className: string,
		shape: Enum.PartType?,
		material: Enum.Material,
		color: string,
		transparency: number,
		canCollide: boolean,
		canQuery: boolean,
		canTouch: boolean,
	}
	local RAIL_LOOK: PartLook = {
		className = "Part",
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Fabric,
		color = "f0deb4",
		transparency = 0,
		canCollide = false,
		canQuery = true,
		canTouch = true,
	}
	local RUNG_LOOK: PartLook = {
		className = "Part",
		shape = Enum.PartType.Block,
		material = Enum.Material.Wood,
		color = "c48c5c",
		transparency = 0,
		canCollide = false,
		canQuery = true,
		canTouch = true,
	}
	local TRUSS_LOOK: PartLook = {
		className = "TrussPart",
		shape = nil,
		material = Enum.Material.Plastic,
		color = "a3a2a5",
		transparency = 1,
		canCollide = true,
		canQuery = true,
		canTouch = true,
	}
	local RAIL_THICKNESS = 0.45 -- studs: a rail is 0.45 by 0.45 across (its length changes)
	local RUNG_SIZE = Vector3.new(5.2, 0.45, 0.6)
	local TRUSS_WIDTH = 2 -- studs: a truss is 2 by 2 across and a multiple of 2 long (Roblox docs, TrussPart)
	local RUNG_SPACING = 1.8 -- studs between rung centres...
	local SPACING_SLACK = 0.05 -- ...give or take this much
	-- The foot of the beard ladder's truss. V1 built it at (0, 67.299, -24.501). Task 26 (his solid body sits where he's
	-- drawn) makes the truss 2.0 studs longer at its bottom end, on the same line, with its top end unchanged (designer
	-- said yes, on condition the climb starts on the visible ladder): the foot is now 2.0 lower along the ladder,
	-- 16 studs from the truss centre (0, 80.018, -18.651) at 65.3 degrees, which is (0, 65.482, -25.337). Invisible, so
	-- the look does not change. Task 26 Ruling 8: the truss grows 2.0 studs more at its bottom end (30 -> 32 long), so
	-- the foot is 18 studs from that centre: (0, 63.665, -26.173). Task 26 Ruling 12: the foot end swings 1.0 stud back
	-- toward his beard (top end unchanged, still 32 long), so the foot is (0, 63.261, -25.258).
	local BEARD_FOOT = Vector3.new(0, 63.261, -25.258)
	-- ...and its lowest rung's middle: designer's change after the side views (the rails reach his belly), now two
	-- rungs 1.8 studs down the ladder each from V1's lowest rung, which was at (0, 67.2230, -24.5360). The second sits
	-- in open air 1.64 studs from his drawn skin (measured on 2026-10-21, Task 25 step 1); a third would sink into him.
	local BEARD_LOWEST_RUNG = Vector3.new(0, 63.952, -26.040)
	local FOOT_SLACK = 0.05 -- studs the beard ladder's foot and lowest rung may move
	local LOOK_SLACK = 0.001 -- studs: rounding in the sizes written into the world

	local function lookProblems(part: BasePart, look: PartLook, label: string, problems: { string })
		local function wrong(what: string, got: any, want: any)
			table.insert(problems, `{label}: {what} is {got}, it must be {want}`)
		end
		if part.ClassName ~= look.className then
			wrong("its kind", part.ClassName, look.className)
		end
		if look.shape ~= nil and part:IsA("Part") and part.Shape ~= look.shape then
			wrong("its shape", part.Shape.Name, look.shape.Name)
		end
		if part.Material ~= look.material then
			wrong("its material", part.Material.Name, look.material.Name)
		end
		if part.Color:ToHex():lower() ~= look.color then
			wrong("its colour", part.Color:ToHex():lower(), look.color)
		end
		if part.Transparency ~= look.transparency then
			wrong("its transparency", part.Transparency, look.transparency)
		end
		if part.CanCollide ~= look.canCollide then
			wrong("CanCollide", part.CanCollide, look.canCollide)
		end
		if part.CanQuery ~= look.canQuery then
			wrong("CanQuery", part.CanQuery, look.canQuery)
		end
		if part.CanTouch ~= look.canTouch then
			wrong("CanTouch", part.CanTouch, look.canTouch)
		end
	end

	-- Every way a ladder differs from V1's look: sizes across, colour, material, see-through and collision settings,
	-- a truss a multiple of 2 long, rungs evenly spaced and, for the beard ladder, a foot and lowest rung where V1 had them.
	-- Takes the ladder as an argument so the test below can check a damaged copy.
	local function ladderLookProblems(ladder: Instance, ladderName: string): { string }
		local problems: { string } = {}
		for _, rail in ladderParts(ladder, "Rail") do
			lookProblems(rail, RAIL_LOOK, `{ladderName} rail`, problems)
			if
				math.abs(rail.Size.Y - RAIL_THICKNESS) > LOOK_SLACK
				or math.abs(rail.Size.Z - RAIL_THICKNESS) > LOOK_SLACK
			then
				table.insert(
					problems,
					`{ladderName} rail: it is {rail.Size.Y} by {rail.Size.Z} across, it must be 0.45`
				)
			end
		end
		local rungs = ladderParts(ladder, "Rung")
		for _, rung in rungs do
			lookProblems(rung, RUNG_LOOK, `{ladderName} rung`, problems)
			if (rung.Size - RUNG_SIZE).Magnitude > LOOK_SLACK then
				table.insert(problems, `{ladderName} rung: its size is {rung.Size}, it must be {RUNG_SIZE}`)
			end
		end
		local trusses = ladderParts(ladder, "Climb")
		if #trusses ~= 1 then
			table.insert(problems, `{ladderName}: it has {#trusses} Climb parts, it must have 1`)
		end
		for _, truss in trusses do
			lookProblems(truss, TRUSS_LOOK, `{ladderName} truss`, problems)
			local half = truss.Size.Z / 2
			if
				math.abs(truss.Size.X - TRUSS_WIDTH) > LOOK_SLACK
				or math.abs(truss.Size.Y - TRUSS_WIDTH) > LOOK_SLACK
				or truss.Size.Z < TRUSS_WIDTH - LOOK_SLACK
				or math.abs(half - math.round(half)) > LOOK_SLACK
			then
				table.insert(
					problems,
					`{ladderName} truss: its size is {truss.Size}, it must be 2 by 2 by a multiple of 2`
				)
			end
		end

		-- rungs evenly spaced, in order along the ladder
		if #trusses == 1 and #rungs > 1 then
			local axis = ladderAxis(ladder)
			table.sort(rungs, function(a: BasePart, b: BasePart): boolean
				return a.Position:Dot(axis.up) < b.Position:Dot(axis.up)
			end)
			local badSpacing = 0
			local worst = 0
			for index = 2, #rungs do
				local spacing = (rungs[index].Position - rungs[index - 1].Position).Magnitude
				if math.abs(spacing - RUNG_SPACING) > SPACING_SLACK then
					badSpacing += 1
					worst = if math.abs(spacing - RUNG_SPACING) > math.abs(worst - RUNG_SPACING) then spacing else worst
				end
			end
			if badSpacing > 0 then
				table.insert(
					problems,
					string.format(
						"%s: %d rung gaps are not %g apart (the worst is %.2f)",
						ladderName,
						badSpacing,
						RUNG_SPACING,
						worst
					)
				)
			end

			if ladderName == "BeardLadder" then
				if (axis.foot - BEARD_FOOT).Magnitude > FOOT_SLACK then
					table.insert(problems, `BeardLadder: its foot moved to {describePoint(axis.foot)}`)
				end
				if (rungs[1].Position - BEARD_LOWEST_RUNG).Magnitude > FOOT_SLACK then
					table.insert(problems, `BeardLadder: its lowest rung moved to {describePoint(rungs[1].Position)}`)
				end
			end
		end
		return problems
	end

	-- Both ladders keep their look, whatever their length or tilt (designer 3).
	it("both ladders keep their look", function()
		local walk = walkFolder()
		local problems: { string } = {}
		for _, ladderName in { "BeardLadder", "CapLadder" } do
			local ladder = walk:FindFirstChild(ladderName)
			expect(ladder).never.toBeNil()
			for _, line in ladderLookProblems(ladder :: Instance, ladderName) do
				table.insert(problems, line)
			end
		end
		expect(problems).toEqual({})
	end)

	-- The check above is not a rubber stamp: a copy of the beard ladder (outside the Workspace) with one rung moved
	-- 0.3 studs along the ladder is reported, and the copy is thrown away.
	it("the look check notices one rung moved 0.3 studs", function()
		local original = walkFolder():FindFirstChild("BeardLadder")
		expect(original).never.toBeNil()
		local copy = (original :: Instance):Clone()
		local rungs = ladderParts(copy, "Rung")
		local axis = ladderAxis(copy)
		local moved = rungs[#rungs // 2]
		moved.CFrame += axis.up * 0.3
		local problems = ladderLookProblems(copy, "BeardLadder copy")
		copy:Destroy()
		expect(#problems).toBeGreaterThan(0)
		expect(problems[1]).toContain("rung gaps are not")
	end)

	-- Designer's change after the side views (stuck safety Task 25, "Ruling after step 6b-1"): the beard ladder's visible
	-- rails reach down to his belly. Each rail's lowest corners are at most 0.2 studs above his skin and at most 0.3
	-- studs into it (a ray straight down from 1 stud over the corner, seeing only his body), and each rail's top end has
	-- not moved from where V1 and Task 25's tilt put it.
	local BEARD_RAIL_TOPS = { Vector3.new(-2.4, 92.919, -12.717), Vector3.new(2.4, 92.919, -12.717) } -- source: step 6b-1a
	local BEARD_RAIL_TOP_SLACK = 0.05 -- studs the top end may move
	local BEARD_RAIL_ABOVE = 0.2 -- studs: the lowest corner may be this far over his skin
	local BEARD_RAIL_INTO = 0.3 -- studs: ...and this far into it
	local BEARD_CORNER_RAY_ABOVE = 1 -- studs: the drawn skin is looked for from this far over the corner

	-- What is wrong with each beard ladder rail's bottom end and top end, as short sentences (empty is good).
	local function beardRailProblems(ladder: Instance, skin: DrawnSkin.Skin): { string }
		local problems: { string } = {}
		local rails = ladderParts(ladder, "Rail")
		if #rails ~= 2 then
			return { `the beard ladder has {#rails} rails, it must have 2` }
		end
		table.sort(rails, function(a: BasePart, b: BasePart): boolean
			return a.Position.X < b.Position.X
		end)
		local axis = ladderAxis(ladder)
		for index, rail in rails do
			local direction, length = longSide(rail)
			if direction:Dot(axis.up) < 0 then
				direction = -direction
			end
			local half = rail.Size / 2
			-- the top end's middle must not have moved
			local top = rail.Position + direction * length / 2
			local moved = (top - BEARD_RAIL_TOPS[index]).Magnitude
			if moved > BEARD_RAIL_TOP_SLACK then
				table.insert(problems, `rail {index}: its top end moved {string.format("%.2f", moved)} studs`)
			end
			-- the corners of the bottom end, lowest first
			local corners: { Vector3 } = {}
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = rail.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						if (corner - rail.Position):Dot(direction) < 0 then
							table.insert(corners, corner)
						end
					end
				end
			end
			table.sort(corners, function(a: Vector3, b: Vector3): boolean
				return a.Y < b.Y
			end)
			for cornerIndex = 1, #corners do
				local corner = corners[cornerIndex]
				if corner.Y - corners[1].Y > WINDOW_SLACK then
					break
				end
				-- the drawn skin (not his solid shape) under the corner, looked for from 1 stud over it
				local skinHeight = skin.heightAt(corner.X, corner.Z, corner.Y + BEARD_CORNER_RAY_ABOVE)
				if skinHeight == nil then
					table.insert(
						problems,
						`rail {index}: no drawn skin under its lowest corner {describePoint(corner)}`
					)
				else
					local gap = corner.Y - skinHeight -- positive: over his skin, negative: into it
					if gap > BEARD_RAIL_ABOVE + WINDOW_SLACK or gap < -BEARD_RAIL_INTO - WINDOW_SLACK then
						table.insert(
							problems,
							`rail {index}: its lowest corner {describePoint(corner)} is {string.format("%.2f", gap)} studs over his skin, it must be between -0.3 and 0.2`
						)
					end
				end
			end
		end
		return problems
	end

	it("the beard ladder's rails reach his belly", function()
		local ladder = walkFolder():FindFirstChild("BeardLadder")
		expect(ladder).never.toBeNil()
		-- measured against the skin that is DRAWN (the mesh triangles plus any shirt folds), as designer asked
		local meshes: { MeshPart } = {}
		for _, name in BODY_PIECES do
			local piece = ((realWorld() :: any).Giant :: Instance):FindFirstChild(name)
			table.insert(meshes, (piece :: Instance):FindFirstChild(name) :: MeshPart)
		end
		local folds: { BasePart } = {}
		local foldFolder = ((realWorld() :: any).Giant :: Instance):FindFirstChild("ShirtFolds")
		if foldFolder then
			for _, descendant in foldFolder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(folds, descendant)
				end
			end
		end
		local skin = DrawnSkin.fromWorld(meshes, folds)
		expect(beardRailProblems(ladder :: Instance, skin)).toEqual({})
	end, 60000) -- reading the six meshes takes a few seconds

	-- Task 26, Ruling 12 (designer's test for the hidden climbing truss: a player may only grab it where he visibly
	-- touches the ladder). The truss is 2 studs thick and its centre line runs along the visible rails, so its front
	-- face stands 1 stud out from the rungs: a walker crossing in front of the ladder's foot was lifted off his cloth.
	-- The truss's top end stays where it is and its foot end swings back toward his beard, still 2 by 2 by 32.
	local BEARD_TRUSS_TOP = Vector3.new(0, 92.7371, -12.8009) -- the truss's top end, as Ruling 8 left it
	local BEARD_TRUSS_TOP_SLACK = 0.05 -- studs the top end may move
	local BEARD_TRUSS_FRONT_BOTTOM_MIN_Z = -26.33 -- the front-bottom edge is no more than 0.3 south of the rails' foot
	local BEARD_TRUSS_FRONT_BOTTOM_MAX_Y = 64.1
	local BEARD_TRUSS_BEHIND_MIN = 0.5 -- studs: the truss's foot point is at least this far behind the rails' foot plane

	-- What is wrong with the beard ladder's climbing truss, as short sentences (empty is good).
	local function beardTrussStartProblems(ladder: Instance): { string }
		local problems: { string } = {}
		local truss = ladder:FindFirstChild("Climb")
		expect(truss).never.toBeNil()
		local part = truss :: BasePart
		local sizes = { part.Size.X, part.Size.Y, part.Size.Z }
		table.sort(sizes)
		if
			math.abs(sizes[1] - TRUSS_WIDTH) > LOOK_SLACK
			or math.abs(sizes[2] - TRUSS_WIDTH) > LOOK_SLACK
			or math.abs(sizes[3] - 32) > LOOK_SLACK
		then
			table.insert(problems, `the truss is {part.Size}, it must be 2 by 2 by 32`)
		end

		local axis = ladderAxis(ladder)
		local moved = (axis.top - BEARD_TRUSS_TOP).Magnitude
		if moved > BEARD_TRUSS_TOP_SLACK then
			table.insert(problems, `the truss's top end moved {string.format("%.2f", moved)} studs`)
		end

		-- the front of the truss faces away from his beard; its front-bottom edge is half a thickness in front of the foot
		local front = -axis.back
		local frontBottom = axis.foot + front * (TRUSS_WIDTH / 2)
		if frontBottom.Z < BEARD_TRUSS_FRONT_BOTTOM_MIN_Z - WINDOW_SLACK then
			table.insert(
				problems,
				`the truss's front-bottom edge is at z {string.format("%.2f", frontBottom.Z)}, it must be {BEARD_TRUSS_FRONT_BOTTOM_MIN_Z} or more (toward his beard)`
			)
		end
		if frontBottom.Y > BEARD_TRUSS_FRONT_BOTTOM_MAX_Y + WINDOW_SLACK then
			table.insert(
				problems,
				`the truss's front-bottom edge is at y {string.format("%.2f", frontBottom.Y)}, it must be {BEARD_TRUSS_FRONT_BOTTOM_MAX_Y} or less`
			)
		end

		-- the rails' foot plane: square to the ladder, through the middle of the two rails' lower ends
		local rails = ladderParts(ladder, "Rail")
		if #rails ~= 2 then
			table.insert(problems, `the beard ladder has {#rails} rails, it must have 2`)
			return problems
		end
		local railsFoot = Vector3.zero
		for _, rail in rails do
			local direction, length = longSide(rail)
			if direction:Dot(axis.up) < 0 then
				direction = -direction
			end
			railsFoot += (rail.Position - direction * length / 2) / 2
		end
		local behind = -(axis.foot - railsFoot):Dot(front)
		if behind < BEARD_TRUSS_BEHIND_MIN - WINDOW_SLACK then
			table.insert(
				problems,
				`the truss's foot point is {string.format("%.2f", behind)} studs behind the rails' foot plane, it must be at least {BEARD_TRUSS_BEHIND_MIN}`
			)
		end
		return problems
	end

	it("the beard truss starts at the visible ladder's foot", function()
		local ladder = walkFolder():FindFirstChild("BeardLadder")
		expect(ladder).never.toBeNil()
		expect(beardTrussStartProblems(ladder :: Instance)).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Crossing ramps
	----------------------------------------------------------------------------------------------------------------

	-- His body-size slope at (x, z) in degrees: the plane that best fits 25 rays straight down on a 4 by 4 stud square
	-- (designer's rule, as in the seam test). nil when a ray misses him.
	local function bodySlopeAt(params: RaycastParams, x: number, z: number): number?
		local sumX, sumZ = 0, 0
		for offsetX = -BODY_PATCH_REACH, BODY_PATCH_REACH do
			for offsetZ = -BODY_PATCH_REACH, BODY_PATCH_REACH do
				local hit =
					Workspace:Raycast(Vector3.new(x + offsetX, 200, z + offsetZ), Vector3.new(0, -250, 0), params)
				if hit == nil then
					return nil
				end
				sumX += offsetX * hit.Position.Y
				sumZ += offsetZ * hit.Position.Y
			end
		end
		local squares = (2 * BODY_PATCH_REACH + 1)
			* (BODY_PATCH_REACH * (BODY_PATCH_REACH + 1) * (2 * BODY_PATCH_REACH + 1) / 3)
		local normal = Vector3.new(-sumX / squares, 1, -sumZ / squares).Unit
		return math.deg(math.acos(math.clamp(normal.Y, -1, 1)))
	end

	-- Whether his skin has a wall or a steep band under a ramp's span: from `start` to `finish` (x and z only), along the
	-- middle and the two sides `halfWidth` out, a run of steps steeper than WALL_DEGREES that rises more than WALL_RISE
	-- studs, or a body-size slope of STEEP_BODY_DEGREES or more somewhere along the middle. A ramp where a fitted piece
	-- would do is not allowed (Rule 20: the exception is only for walls).
	local function spanHasWall(params: RaycastParams, start: Vector3, finish: Vector3, halfWidth: number): boolean
		local flat = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
		local length = flat.Magnitude
		local along = flat.Unit
		local across = Vector3.new(-along.Z, 0, along.X)
		local steps = math.max(1, math.floor(length / PROFILE_STEP))
		for _, side in { -1, 0, 1 } do
			local previous: number? = nil
			local run = 0
			for step = 0, steps do
				local at = Vector3.new(start.X, 0, start.Z)
					+ along * (length * step / steps)
					+ across * (side * halfWidth)
				local hit = Workspace:Raycast(Vector3.new(at.X, 200, at.Z), Vector3.new(0, -250, 0), params)
				local height = if hit then hit.Position.Y else nil
				if height ~= nil and previous ~= nil then
					local degrees = math.deg(math.atan2(math.abs(height - previous), length / steps))
					if degrees > WALL_DEGREES then
						run += math.abs(height - previous)
						if run > WALL_RISE then
							return true
						end
					else
						run = 0
					end
				end
				previous = height
			end
		end
		local count = math.max(1, math.floor(length))
		for step = 0, count do
			local at = Vector3.new(start.X, 0, start.Z) + along * (length * step / count)
			local slope = bodySlopeAt(params, at.X, at.Z)
			if slope ~= nil and slope >= STEEP_BODY_DEGREES then
				return true
			end
		end
		return false
	end

	-- A ramp's top: the points of a lattice 1 stud apart that lie on it, and the surface direction there. It is found by
	-- rays that see only the ramp, so it works for any shape of ramp that has a top.
	type RampTop = { points: { Vector3 }, middleNormal: Vector3, direction: Vector3, bottom: { number } }
	local function rampTop(ramp: BasePart): RampTop
		local params = RaycastParams.new()
		params.IncludeInstances = { ramp }
		params.RespectCanCollide = false
		local half = ramp.Size / 2
		local lowX, highX, lowZ, highZ, highY, lowY =
			math.huge, -math.huge, math.huge, -math.huge, -math.huge, math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = ramp.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					lowX, highX = math.min(lowX, corner.X), math.max(highX, corner.X)
					lowZ, highZ = math.min(lowZ, corner.Z), math.max(highZ, corner.Z)
					highY, lowY = math.max(highY, corner.Y), math.min(lowY, corner.Y)
				end
			end
		end
		local points: { Vector3 } = {}
		local bottom: { number } = {}
		local x = lowX + GRID_INSET
		while x <= highX - GRID_INSET + 1e-6 do
			local z = lowZ + GRID_INSET
			while z <= highZ - GRID_INSET + 1e-6 do
				local down =
					Workspace:Raycast(Vector3.new(x, highY + 1, z), Vector3.new(0, -(highY - lowY + 2), 0), params)
				if down ~= nil then
					table.insert(points, down.Position)
					-- the lowest the ramp reaches under this point: a ray up from far below, seeing only the ramp
					local up =
						Workspace:Raycast(Vector3.new(x, lowY - 1, z), Vector3.new(0, highY - lowY + 2, 0), params)
					table.insert(bottom, if up ~= nil then up.Position.Y else down.Position.Y)
				end
				z += GRID_STEP
			end
			x += GRID_STEP
		end
		local middle = Workspace:Raycast(
			Vector3.new(ramp.Position.X, highY + 1, ramp.Position.Z),
			Vector3.new(0, -(highY - lowY + 2), 0),
			params
		)
		local normal = if middle ~= nil then middle.Normal else Vector3.yAxis
		local direction = Vector3.new(normal.X, 0, normal.Z)
		return {
			points = points,
			middleNormal = normal,
			direction = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis,
			bottom = bottom,
		}
	end

	-- What is wrong with one crossing ramp, as short sentences (an empty list is a good ramp).
	local function rampProblems(params: RaycastParams, ramp: BasePart): { string }
		local problems: { string } = {}
		local top = rampTop(ramp)
		if #top.points == 0 then
			return { "no top was found" }
		end
		-- inside the stretch
		local at = ramp.Position
		if
			at.X < STRETCH_MIN.X
			or at.X > STRETCH_MAX.X
			or at.Y < STRETCH_MIN.Y
			or at.Y > STRETCH_MAX.Y
			or at.Z < STRETCH_MIN.Z
			or at.Z > STRETCH_MAX.Z
		then
			table.insert(
				problems,
				`stands at {describePoint(at)}, outside the stretch between the left boot top and Rare egg 1`
			)
		end
		-- no steeper than 45 degrees
		local degrees = math.deg(math.acos(math.clamp(top.middleNormal.Y, -1, 1)))
		if degrees > MAX_RAMP_DEGREES + 0.01 then
			table.insert(problems, string.format("its top is %.1f degrees (the most is %d)", degrees, MAX_RAMP_DEGREES))
		end
		-- the step-on and step-off edges are the first and last rows along the slope's direction
		local lowest, highest = math.huge, -math.huge
		for _, point in top.points do
			local along = point:Dot(top.direction)
			lowest, highest = math.min(lowest, along), math.max(highest, along)
		end
		for index, point in top.points do
			local along = point:Dot(top.direction)
			if along - lowest <= EDGE_ROW or highest - along <= EDGE_ROW then
				local hit = skinUnder(params, point)
				if hit == nil then
					table.insert(problems, `edge point {describePoint(point)} has no skin under it`)
				else
					local gap = point.Y - hit.Position.Y
					if gap > WINDOW_ABOVE + WINDOW_SLACK or gap < -WINDOW_BELOW - WINDOW_SLACK then
						table.insert(
							problems,
							string.format("edge point %s is %.2f studs from his skin", describePoint(point), gap)
						)
					end
				end
			end
			-- solid all the way down: its lowest point under this place is at or under his skin
			local skin = skinUnder(params, point)
			if skin ~= nil and top.bottom[index] > skin.Position.Y + WINDOW_SLACK then
				table.insert(
					problems,
					string.format(
						"under %s the ramp ends %.2f studs over his skin (a gap)",
						describePoint(point),
						top.bottom[index] - skin.Position.Y
					)
				)
			end
		end
		-- a wall or a steep band really is under its span
		local startPoint = ramp.Position - top.direction * ((highest - lowest) / 2)
		local finishPoint = ramp.Position + top.direction * ((highest - lowest) / 2)
		local crossWidth = math.min(ramp.Size.X, ramp.Size.Z) / 2
		if not spanHasWall(params, startPoint, finishPoint, math.max(crossWidth - 1, 0)) then
			table.insert(
				problems,
				"no wall and no steep band of his skin is under its span, so a fitted piece would do"
			)
		end
		return problems
	end

	it("there are at most 3 crossing ramps, named for the left leg's walls", function()
		local ramps = crossingRamps()
		local names: { string } = {}
		local unknown: { string } = {}
		for _, ramp in ramps do
			table.insert(names, ramp.Name)
			if not RAMP_NAMES[ramp.Name] then
				table.insert(unknown, ramp.Name)
			end
		end
		table.sort(names)
		expect(unknown).toEqual({})
		expect(#ramps <= MAX_RAMPS).toBe(true)
		-- his left leg has two walls (the boot's top edge and the knee), so both ramps must be there
		expect(table.find(names, "CrossingRamp_Ankle") ~= nil).toBe(true)
		expect(table.find(names, "CrossingRamp_Knee") ~= nil).toBe(true)
	end)

	it("a crossing ramp is invisible and solid, like the walk pieces", function()
		local wrong: { string } = {}
		local ramps = crossingRamps()
		expect(#ramps >= 2).toBe(true)
		for _, ramp in ramps do
			if
				ramp.Transparency ~= 1
				or not ramp.Anchored
				or not ramp.CanCollide
				or not ramp.CanQuery
				or not ramp.CanTouch
				or ramp.CollisionGroup ~= "Default"
			then
				table.insert(wrong, ramp.Name)
			end
		end
		expect(wrong).toEqual({})
	end)

	it("each crossing ramp is a short solid ramp at a wall", function()
		local params = bodyParams()
		local ramps = crossingRamps()
		expect(#ramps >= 2).toBe(true)
		local problems: { [string]: { string } } = {}
		for _, ramp in ramps do
			local found = rampProblems(params, ramp)
			if #found > 0 then
				problems[ramp.Name] = { table.unpack(found, 1, math.min(#found, 6)) }
			end
		end
		expect(problems).toEqual({})
	end)

	-- Proof that the wall part of the test above can fail: over the flat top of his left boot (the part above the step,
	-- no wall and no steep band) it says no, and over the boot's top edge it says yes.
	it("finds no wall under a span over the flat boot top, and finds the boot's top edge", function()
		local params = bodyParams()
		expect(spanHasWall(params, Vector3.new(-24, 0, -66), Vector3.new(-24, 0, -62), 1.5)).toBe(false)
		expect(spanHasWall(params, Vector3.new(-24, 0, -58), Vector3.new(-24, 0, -53), 1.5)).toBe(true)
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Edge guards (Ruling 7): the sides of a crossing ramp are guarded where they cross steep skin
	----------------------------------------------------------------------------------------------------------------

	local GUARD_FOLDER = "CrossingGuards" -- kept apart from V1's SteepGuards, so plan 3, Task 6 removes it with the ramps
	local SIDE_REACH = 2 -- studs beside a ramp's side that are looked at
	local SIDE_LOOK_STEP = 0.25
	local STEEP_SKIN_DEGREES = 70 -- skin this steep, or steeper, beside a side needs a guard...
	local STEEP_SKIN_RISE = 0.5 -- ...if it rises more than this within one look step
	local GUARD_RAY_HEIGHTS = { 1, 3, 4.2 } -- studs over the ramp top: a body is 4.3 tall, so 4.2 is its top
	local GUARD_SIDE_INSET = 0.3 -- studs: the sideways ray starts this far inside the side
	local GUARD_NEAR = 1 -- studs: a guard stands within this far of the side
	local NO_FLAT_TOP_DEGREES = 72 -- every face of a guard that looks up is at least this steep
	local MAX_GUARDS_PER_RAMP = 2
	local GUARD_FOOTPRINT_STEP = 0.25

	-- His skin's height at (x, z), or nil.
	local function skinHeightAt(params: RaycastParams, x: number, z: number): number?
		local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -250, 0), params)
		return if hit ~= nil then hit.Position.Y else nil
	end

	-- Whether his skin at (x, z) is steep: its local slope (read ±0.25 studs around the place) is over STEEP_SKIN_DEGREES
	-- and it rises more than STEEP_SKIN_RISE within that look, or its body-size slope is STEEP_SKIN_DEGREES or more.
	local function steepSkinAt(params: RaycastParams, x: number, z: number): boolean
		local reach = SIDE_LOOK_STEP
		local east = skinHeightAt(params, x + reach, z)
		local west = skinHeightAt(params, x - reach, z)
		local north = skinHeightAt(params, x, z + reach)
		local south = skinHeightAt(params, x, z - reach)
		if east ~= nil and west ~= nil and north ~= nil and south ~= nil then
			local gradientX = (east - west) / (2 * reach)
			local gradientZ = (north - south) / (2 * reach)
			local degrees = math.deg(math.atan(math.sqrt(gradientX * gradientX + gradientZ * gradientZ)))
			local rise = math.max(math.abs(east - west), math.abs(north - south))
			if degrees > STEEP_SKIN_DEGREES and rise > STEEP_SKIN_RISE then
				return true
			end
		end
		local body = bodySlopeAt(params, x, z)
		return body ~= nil and body >= STEEP_SKIN_DEGREES
	end

	type SidePoint = { base: Vector3, top: number, outward: Vector3, steep: boolean }

	-- The points along both long sides of a ramp, every 1 stud from 0.5 in from the ends: the place on the side edge, the
	-- ramp's top height there, the direction away from the ramp, and whether steep skin lies beside it (out to SIDE_REACH).
	local function sidePoints(params: RaycastParams, ramp: BasePart): { SidePoint }
		local rampParams = RaycastParams.new()
		rampParams.IncludeInstances = { ramp }
		rampParams.RespectCanCollide = false
		local half = ramp.Size / 2
		-- the ramp's own long direction on the ground, and its side direction (a pitch or yaw only, so both are level)
		local right = Vector3.new(ramp.CFrame.RightVector.X, 0, ramp.CFrame.RightVector.Z).Unit
		local topNormal = Workspace:Raycast(ramp.Position + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), rampParams)
		local ascent = Vector3.zAxis
		if topNormal ~= nil then
			ascent = -Vector3.new(topNormal.Normal.X, 0, topNormal.Normal.Z).Unit
		end
		local lowest, highest = math.huge, -math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = ramp.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					local along = corner:Dot(ascent)
					lowest, highest = math.min(lowest, along), math.max(highest, along)
				end
			end
		end
		local centreAlong = ramp.Position:Dot(ascent)
		local foot = ramp.Position - ascent * (centreAlong - lowest)
		local points: { SidePoint } = {}
		local reach = 0.5
		while reach <= highest - lowest - 0.5 + 1e-6 do
			for _, side in { -1, 1 } do
				local outward = right * side
				local base = foot + ascent * reach + outward * (half.X - 0.05)
				local top = Workspace:Raycast(Vector3.new(base.X, 200, base.Z), Vector3.new(0, -250, 0), rampParams)
				if top ~= nil then
					local steep = false
					for look = SIDE_LOOK_STEP, SIDE_REACH + 1e-6, SIDE_LOOK_STEP do
						local beside = base + outward * look
						if steepSkinAt(params, beside.X, beside.Z) then
							steep = true
							break
						end
					end
					table.insert(points, { base = base, top = top.Position.Y, outward = outward, steep = steep })
				end
			end
			reach += 1
		end
		return points
	end

	-- What is wrong with the guards of one ramp: at every side point with steep skin beside it, a sideways ray from 1, 3
	-- and 4.2 studs over the ramp top (starting just inside the side, seeing only `guards`) must hit a guard within
	-- GUARD_NEAR of the side. Returns the problems and how many side points needed a guard.
	local function guardProblems(params: RaycastParams, ramp: BasePart, guards: { BasePart }): ({ string }, number)
		local problems: { string } = {}
		local guardParams = RaycastParams.new()
		local included: { Instance } = {}
		for _, guard in guards do
			table.insert(included, guard)
		end
		guardParams.IncludeInstances = included
		guardParams.RespectCanCollide = false
		local needed = 0
		for _, point in sidePoints(params, ramp) do
			if point.steep then
				needed += 1
				for _, height in GUARD_RAY_HEIGHTS do
					local inside = point.base - point.outward * GUARD_SIDE_INSET
					local start = Vector3.new(inside.X, point.top + height, inside.Z)
					local hit = Workspace:Raycast(start, point.outward * (GUARD_SIDE_INSET + GUARD_NEAR), guardParams)
					if hit == nil then
						table.insert(
							problems,
							string.format(
								"%s: no guard beside the side at %s, %g studs over the ramp",
								ramp.Name,
								describePoint(point.base),
								height
							)
						)
					end
				end
			end
		end
		return problems, needed
	end

	local function crossingGuards(): { BasePart }
		local folder = walkFolder():FindFirstChild(GUARD_FOLDER)
		expect(folder).never.toBeNil()
		local guards: { BasePart } = {}
		for _, guard in (folder :: Instance):GetChildren() do
			expect(guard:IsA("BasePart")).toBe(true)
			table.insert(guards, guard :: BasePart)
		end
		return guards
	end

	it("each crossing ramp's sides are guarded where they cross steep skin", function()
		local params = bodyParams()
		local guards = crossingGuards()
		local problems: { string } = {}
		local neededByRamp: { [string]: number } = {}
		for _, ramp in crossingRamps() do
			local found, needed = guardProblems(params, ramp, guards)
			neededByRamp[ramp.Name] = needed
			for index = 1, math.min(#found, 6) do
				table.insert(problems, found[index])
			end
		end
		-- the check is not empty: his ankle and knee walls have steep skin beside the ramps' sides
		expect((neededByRamp.CrossingRamp_Ankle or 0) > 0).toBe(true)
		expect((neededByRamp.CrossingRamp_Knee or 0) > 0).toBe(true)
		expect(problems).toEqual({})
	end)

	it(
		"every crossing guard is invisible, solid, has no flat top, reaches down to his skin, and there are at most 2 per ramp",
		function()
			local params = bodyParams()
			local wrong: { string } = {}
			local guards = crossingGuards()
			expect(#guards >= 2).toBe(true)
			for _, guard in guards do
				if
					guard.Transparency ~= 1
					or not guard.Anchored
					or not guard.CanCollide
					or not guard.CanQuery
					or guard.CollisionGroup ~= "Default"
				then
					table.insert(wrong, `{guard.Name}: not invisible, anchored and solid`)
				end
				local onlyGuard = RaycastParams.new()
				onlyGuard.IncludeInstances = { guard }
				onlyGuard.RespectCanCollide = false
				-- the footprint of the guard (its bounding box seen from above), read every GUARD_FOOTPRINT_STEP studs
				local half = guard.Size / 2
				local lowX, highX, lowZ, highZ, highY, lowY =
					math.huge, -math.huge, math.huge, -math.huge, -math.huge, math.huge
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner =
								guard.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							lowX, highX = math.min(lowX, corner.X), math.max(highX, corner.X)
							lowZ, highZ = math.min(lowZ, corner.Z), math.max(highZ, corner.Z)
							highY, lowY = math.max(highY, corner.Y), math.min(lowY, corner.Y)
						end
					end
				end
				local flatTop, gap, hitsCount = 0, 0, 0
				local x = lowX + GUARD_FOOTPRINT_STEP / 2
				while x <= highX do
					local z = lowZ + GUARD_FOOTPRINT_STEP / 2
					while z <= highZ do
						local down = Workspace:Raycast(
							Vector3.new(x, highY + 1, z),
							Vector3.new(0, -(highY - lowY + 2), 0),
							onlyGuard
						)
						if down ~= nil then
							hitsCount += 1
							if down.Normal.Y > math.cos(math.rad(NO_FLAT_TOP_DEGREES)) then
								flatTop += 1
							end
							local up = Workspace:Raycast(
								Vector3.new(x, lowY - 1, z),
								Vector3.new(0, highY - lowY + 2, 0),
								onlyGuard
							)
							local skin = skinHeightAt(params, x, z)
							if up ~= nil and skin ~= nil and up.Position.Y > skin + WINDOW_SLACK then
								gap += 1
							end
						end
						z += GUARD_FOOTPRINT_STEP
					end
					x += GUARD_FOOTPRINT_STEP
				end
				if hitsCount == 0 then
					table.insert(wrong, `{guard.Name}: no top was found`)
				end
				if flatTop > 0 then
					table.insert(
						wrong,
						`{guard.Name}: {flatTop} places on top are flatter than {NO_FLAT_TOP_DEGREES} degrees`
					)
				end
				if gap > 0 then
					table.insert(wrong, `{guard.Name}: {gap} places have a gap under it, over his skin`)
				end
			end
			-- Every guard is named for the ramp it guards ("Ankle_Guard_1" for CrossingRamp_Ankle), and a ramp has at most
			-- MAX_GUARDS_PER_RAMP of them. (Where a guard really stands is checked by the test above, which looks for it.)
			local countByRamp: { [string]: number } = {}
			for _, guard in guards do
				local rampName = string.match(guard.Name, "^(%a+)_Guard_%d+$")
				if rampName == nil or walkFolder():FindFirstChild("CrossingRamp_" .. rampName) == nil then
					table.insert(wrong, `{guard.Name}: not named for a crossing ramp ("Ankle_Guard_1")`)
				else
					countByRamp[rampName] = (countByRamp[rampName] or 0) + 1
				end
			end
			for rampName, count in countByRamp do
				if count > MAX_GUARDS_PER_RAMP then
					table.insert(wrong, `CrossingRamp_{rampName}: {count} guards (the most is {MAX_GUARDS_PER_RAMP})`)
				end
			end
			expect(wrong).toEqual({})
		end
	)

	-- Proof that the guard test can fail: the real ankle ramp, looked at with no guards, has places that need one, and
	-- the same ramp with its real guards has none. (The first is the "a test ramp with a steep side and no guard fails"
	-- check: the ramp stands over a side that is known to be steep, and nothing guards it.)
	it("finds a missing guard beside the ankle ramp's steep side, and none when the guards are there", function()
		local params = bodyParams()
		local ankle = walkFolder():FindFirstChild("CrossingRamp_Ankle")
		expect(ankle).never.toBeNil()
		local without, needed = guardProblems(params, ankle :: BasePart, {})
		expect(needed > 0).toBe(true)
		expect(#without).toBe(needed * #GUARD_RAY_HEIGHTS)
		local with = guardProblems(params, ankle :: BasePart, crossingGuards())
		expect(with).toEqual({})
	end)

	-- Ruling 12: a player cutting the corner to Rare egg 1 pressed against the end of Knee_Guard_2 and the 68 degree skin
	-- past it and stood still. The guard's friction held them, so both knee guards are frictionless (the ankle guards keep
	-- the material's own friction). Walking into them still stops the player: friction does not change a wall.
	it("the long knee ramp's guards let a player slide along them", function()
		local kneeGuards: { BasePart } = {}
		for _, guard in crossingGuards() do
			if guard.Name:match("^Knee_Guard_%d+$") then
				table.insert(kneeGuards, guard)
			end
		end
		expect(#kneeGuards).toBe(2)
		for _, guard in kneeGuards do
			local physics = guard.CustomPhysicalProperties
			expect(physics).never.toBeNil()
			expect((physics :: PhysicalProperties).Friction).toBe(0)
			expect((physics :: PhysicalProperties).FrictionWeight).toBe(100)
		end
	end)

	----------------------------------------------------------------------------------------------------------------
	-- No slot under a walk piece (product's check 2)
	----------------------------------------------------------------------------------------------------------------

	-- The places on the ground under a piece where a standing body fits: under each point of its top, a ray from just
	-- under the piece goes down SLOT_REACH studs; a walkable surface with room for a body (the shared walk check's own
	-- test, with the piece in the world) is a slot a player could stand in.
	local function slotsUnder(options: PathCheck.Options, piece: BasePart): { string }
		local limit = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
		local slots: { string } = {}
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { piece }
		for _, point in topGrid(piece.CFrame, piece.Size) do
			local below = point - piece.CFrame.UpVector * (piece.Size.Y + 0.05)
			local hit = Workspace:Raycast(below, Vector3.new(0, -SLOT_REACH, 0), params)
			if hit ~= nil and hit.Normal.Y >= limit and hit.Material ~= Enum.Material.Water then
				if PathCheck.roomToStand(options, hit.Position, hit.Normal) then
					table.insert(slots, `a body fits at {describePoint(hit.Position)} under {piece.Name}`)
				end
			end
		end
		return slots
	end

	it("no slot under a walk piece or a crossing ramp", function()
		local options = PathCheck.defaults(Workspace)
		local slots: { string } = {}
		local checked = 0
		local ok, message = pcall(function()
			local all: { BasePart } = walkPieces()
			for _, ramp in crossingRamps() do
				table.insert(all, ramp)
			end
			for _, piece in all do
				checked += 1
				local found = slotsUnder(options, piece)
				for index = 1, math.min(#found, MAX_EXAMPLES) do
					table.insert(slots, found[index])
				end
			end
		end)
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		expect(ok).toBe(true)
		if not ok then
			error(message)
		end
		expect(checked > 0).toBe(true)
		expect(slots).toEqual({})
	end)

	-- Proof that the slot test can fail: a test board raised 6 studs over the flat boot top has a slot under it (a body is
	-- 4.3 studs tall, so a 3 stud gap would not be one), and the same board 0.3 studs over his skin has none. The board
	-- stands over the boot top for a moment, with Archivable off, and is destroyed in the test, like the body probe.
	it("sees a slot under a board raised 6 studs, and none under a board resting on his skin", function()
		local params = bodyParams()
		local flatPoint = Vector3.new(-24, 0, -64)
		local skin = skinUnder(params, Vector3.new(flatPoint.X, 40, flatPoint.Z))
		expect(skin).never.toBeNil()
		local floor = (skin :: RaycastResult).Position.Y
		local options = PathCheck.defaults(Workspace)
		local board = Instance.new("Part")
		board.Name = "WalkPieceSlotTestBoard"
		board.Size = Vector3.new(8, 1, 8)
		board.Anchored = true
		board.Transparency = 1
		board.Archivable = false
		local raised: { string } = {}
		local resting: { string } = {}
		local ok, message = pcall(function()
			board.CFrame = CFrame.new(flatPoint.X, floor + 6.5, flatPoint.Z)
			board.Parent = Workspace
			raised = slotsUnder(options, board)
			board.CFrame = CFrame.new(flatPoint.X, floor + 0.3 - 0.5, flatPoint.Z)
			resting = slotsUnder(options, board)
		end)
		board:Destroy()
		PathCheck.cleanup(options)
		if not ok then
			error(message)
		end
		expect(#raised > 0).toBe(true)
		expect(resting).toEqual({})
	end)
end)

-- Stuck safety Task 21: his slide line is the seam (docs/plans/v2/stuck-safety.md, Task 21; spec 2 Rule 20, "One
-- collision source", check 3). A player slides below spec 5's seam and doesn't above it, within the 1-stud seam match.
-- So where his real shape turns steeper than 65 degrees must lie within 1 stud of the style guide's seam line, side by
-- side and along each cuff's rim. If it doesn't, designer moves the stitched seam art to the real line (the style
-- guide's table and rim line); the numbers below are then copied from the style guide again, never fitted to the
-- result. These tests only READ the world.
describe("the real world, his slide line is the seam", function()
	local Workspace = game:GetService("Workspace")

	-- Spec 5 (docs/specs/v2/egg-nests-and-climbing.md), section 5: "Seam angle" 65 degrees (the walk area is under it,
	-- and the seam sits where his side gets steeper) and "Seam match" 1 stud (the walk area's edge lies within 1 stud
	-- of the seam's stitches).
	local SEAM_ANGLE_DEGREES = 65
	local SEAM_MATCH = 1
	-- Cloth up to this steep is cloth a character still walks on in Play. The steepest body-size slope a character still
	-- walked on in Play (stuck safety Task 21 round 3, 2026-10-20): the highest slope at the last walking frame before
	-- the slip, over the six side walk-offs, rounded up (77.6 became 78). Plan 5's steep layer lists the places up to here.
	local SLIP_DEGREES = 78

	-- The style guide's seam line (docs/design/v2/style-guide.md, "The seam: where walking ends", the table "Along his
	-- side"): (x, y, z) of each point on his left and on his right, from z -38 to z -14.
	local SEAM_LEFT: { Vector3 } = {
		Vector3.new(-16.5, 41.7, -38),
		Vector3.new(-18.5, 42.9, -36),
		Vector3.new(-20.5, 43.9, -34),
		Vector3.new(-22.5, 44.5, -32),
		Vector3.new(-24.5, 44.6, -30),
		Vector3.new(-26, 45.2, -28),
		Vector3.new(-29, 45.4, -24),
		Vector3.new(-31, 45.6, -20),
		Vector3.new(-32, 46.8, -16),
		Vector3.new(-32.5, 47, -14),
	}
	local SEAM_RIGHT: { Vector3 } = {
		Vector3.new(15, 43.4, -38),
		Vector3.new(17.5, 44.4, -36),
		Vector3.new(20, 44.7, -34),
		Vector3.new(22, 45.3, -32),
		Vector3.new(24.5, 44.8, -30),
		Vector3.new(26, 45.2, -28),
		Vector3.new(29, 45.6, -24),
		Vector3.new(30.5, 46.7, -20),
		Vector3.new(31.5, 47.6, -16),
		Vector3.new(31.5, 48.9, -14),
	}
	-- The same guide, on his arms (docs/design/v2/style-guide.md, "The seam: where walking ends", the cuff table, moved
	-- 2026-10-20): the five points of the outer rim of each white cuff, front to back. Each point is a station, copied as
	-- written; his left has the negative x.
	local CUFF_LEFT: { Vector3 } = {
		Vector3.new(-46.0, 39.25, -13.0),
		Vector3.new(-50.5, 39.0, -10.2),
		Vector3.new(-52.75, 39.3, -5.75),
		Vector3.new(-51.2, 39.25, -0.6),
		Vector3.new(-49.5, 39.25, 4.0),
	}
	local CUFF_RIGHT: { Vector3 } = {
		Vector3.new(46.0, 39.25, -13.0),
		Vector3.new(50.5, 39.0, -10.2),
		Vector3.new(52.75, 39.3, -5.75),
		Vector3.new(51.2, 39.25, -0.6),
		Vector3.new(49.5, 39.25, 4.0),
	}
	-- Where the strap to the cuff pockets starts (style guide, "The Epic cuff pockets", the table of the strap's parts,
	-- row "Strap top": "Joins the walkable back of the cuff top at about (-52, 38.3, 3.8)"; the seam section's cuff
	-- note only says the strap starts near point 5), and how wide it is (spec 5,
	-- docs/specs/v2/egg-nests-and-climbing.md, "A 6.2-wide strap"). The strap is walk area, so a station within half its
	-- width of its start is still measured and shown, but never counts as a fail.
	local STRAP_START_LEFT = Vector3.new(-52, 38.3, 3.8)
	local STRAP_START_RIGHT = Vector3.new(52, 38.3, 3.8)
	local STRAP_WIDTH = 6.2
	local STRAP_GAP = STRAP_WIDTH / 2
	-- The seam lies on one piece: the side table on body_and_cushion, each cuff rim on its arm.
	local SIDE_PIECE = "body_and_cushion"

	-- How the real line is found.
	local STEP = 0.25 -- studs between the places a walk looks at
	local PAST_THE_LINE = 6 -- studs a walk goes on past the first place steeper than the seam angle
	local SIDE_REACH = 80 -- studs: the farthest a walk from his middle goes before giving up
	local CUFF_BACK = 4 -- studs a cuff walk starts on the sleeve's top side of the rim
	local CUFF_REACH = 40 -- studs: the farthest a cuff walk goes past the rim before giving up

	type Place = { offset: number, position: Vector3, slope: number }
	-- One walk: where the style guide says the line is, the first place steeper than the seam angle (nil if none), and
	-- every place on the walk that is steeper than the seam angle (the list later keeps only those up to SLIP_DEGREES).
	-- `lastSeen` is the last place whose whole square of rays hit his piece. `ranOff` says how the walk stopped: true when
	-- a ray of the next square missed his piece (the square reached past the edge, the rays ran out), false when the walk
	-- reached its full length. `onCuff` rows are the ones where the end of his arm counts as a place where walking ends.
	type Row = {
		name: string,
		guide: Vector3,
		first: Place?,
		steeperThanSeam: { Place },
		lastSeen: Place?,
		ranOff: boolean,
		onCuff: boolean,
		byStrap: boolean,
		strapStart: Vector3?,
	}

	local function bodyMesh(pieceName: string): MeshPart
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local giant = (world :: Instance):FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local piece = (giant :: Instance):FindFirstChild(pieceName)
		expect(piece).never.toBeNil()
		local mesh = (piece :: Instance):FindFirstChild(pieceName)
		expect(mesh).never.toBeNil()
		expect((mesh :: Instance):IsA("MeshPart")).toBe(true)
		return mesh :: MeshPart
	end

	-- A ray that sees only this one piece of him.
	local function onlyParams(piece: Instance): RaycastParams
		local params = RaycastParams.new()
		params.IncludeInstances = { piece }
		params.RespectCanCollide = false
		return params
	end

	-- His slope at body size around (x, z): the file's one body-size slope code (moved to the top of the file).
	local slopeAt = bodySizeSlopeAt

	-- Walks from `origin` (x and z only) along `direction` (flat, length 1), STEP studs at a time, from `fromOffset` to
	-- `toOffset`. Finds the first place steeper than the seam angle, keeps going PAST_THE_LINE studs, and keeps every
	-- place on the way that is steeper than the seam angle.
	local function walk(
		name: string,
		guide: Vector3,
		params: RaycastParams,
		origin: Vector3,
		direction: Vector3,
		fromOffset: number,
		toOffset: number,
		onCuff: boolean
	): Row
		local row: Row = {
			name = name,
			guide = guide,
			first = nil,
			steeperThanSeam = {},
			lastSeen = nil,
			ranOff = false,
			onCuff = onCuff,
			byStrap = false,
		}
		local stopAt = toOffset
		local count = math.floor((toOffset - fromOffset) / STEP + 0.5)
		for index = 0, count do
			local offset = fromOffset + index * STEP
			if offset > stopAt then
				break
			end
			local x, z = origin.X + direction.X * offset, origin.Z + direction.Z * offset
			local slope, y = slopeAt(params, x, z)
			if slope == nil or y == nil then
				row.ranOff = true -- the square reaches past the edge of the piece: his top ends here
				break
			end
			local place: Place = { offset = offset, position = Vector3.new(x, y, z), slope = slope }
			row.lastSeen = place
			if slope > SEAM_ANGLE_DEGREES then
				if row.first == nil then
					row.first = place
					stopAt = offset + PAST_THE_LINE
				end
				table.insert(row.steeperThanSeam, place)
			end
		end
		return row
	end

	-- The 5 stations of a cuff are the style guide's 5 points. At each one, the rim's direction is the average of the two
	-- flat rim pieces that meet there (stations 1 and 5 have only one piece).
	local function cuffStations(line: { Vector3 }): { { position: Vector3, along: Vector3 } }
		local stations: { { position: Vector3, along: Vector3 } } = {}
		for index, point in line do
			local sum = Vector3.zero
			if index > 1 then
				sum += Vector3.new(point.X - line[index - 1].X, 0, point.Z - line[index - 1].Z).Unit
			end
			if index < #line then
				sum += Vector3.new(line[index + 1].X - point.X, 0, line[index + 1].Z - point.Z).Unit
			end
			table.insert(stations, { position = point, along = sum.Unit })
		end
		return stations
	end

	local function sideRows(line: { Vector3 }, sideName: string, towards: number): { Row }
		local params = onlyParams(bodyMesh(SIDE_PIECE))
		local rows: { Row } = {}
		for _, point in line do
			table.insert(
				rows,
				walk(
					`{sideName} side, z {point.Z}`,
					point,
					params,
					Vector3.new(0, 0, point.Z),
					Vector3.new(towards, 0, 0),
					0,
					SIDE_REACH,
					false
				)
			)
		end
		return rows
	end

	local function cuffRows(line: { Vector3 }, cuffName: string, pieceName: string, strapStart: Vector3): { Row }
		local params = onlyParams(bodyMesh(pieceName))
		local rows: { Row } = {}
		for number, station in cuffStations(line) do
			-- across the rim, flat, at right angles to the rim line; the sleeve's top side is the side where his skin
			-- is higher 4 studs from the station, so a walk starts there and goes outward
			local across = Vector3.new(-station.along.Z, 0, station.along.X)
			local _, heightOne =
				slopeAt(params, station.position.X + across.X * CUFF_BACK, station.position.Z + across.Z * CUFF_BACK)
			local _, heightTwo =
				slopeAt(params, station.position.X - across.X * CUFF_BACK, station.position.Z - across.Z * CUFF_BACK)
			local outward = if (heightOne or -math.huge) > (heightTwo or -math.huge) then -across else across
			local row = walk(
				`{cuffName} cuff, station {number}`,
				station.position,
				params,
				station.position,
				outward,
				-CUFF_BACK,
				CUFF_REACH,
				true
			)
			-- by the strap: within half the strap's width of where it starts, flat across the ground
			row.byStrap = Vector3.new(station.position.X - strapStart.X, 0, station.position.Z - strapStart.Z).Magnitude
				<= STRAP_GAP
			row.strapStart = strapStart
			table.insert(rows, row)
		end
		return rows
	end

	local function format(position: Vector3): string
		return string.format("(%.2f, %.2f, %.2f)", position.X, position.Y, position.Z)
	end

	-- Where walking ends on this walk, and what it was. Everywhere it is the first place steeper than the seam angle (a
	-- 65 degree turn). On a cuff, if there is none and the walk ran off his arm, it is the last place the square still fit
	-- (the end of his arm: his arm is a rounded tube that may end before it gets that steep). Nil when the walk reached
	-- its full length with neither, or measured no place at all.
	local TURN = `{SEAM_ANGLE_DEGREES}° turn`
	local ARM_END = "end of his arm"
	local function whereWalkingEnds(row: Row): (Place?, string?)
		if row.first ~= nil then
			return row.first, TURN
		end
		if row.onCuff and row.ranOff and row.lastSeen ~= nil then
			return row.lastSeen, ARM_END
		end
		return nil, nil
	end

	-- How far the place where walking ends is from the style guide's point, flat across the ground, or nil if the walk
	-- has none.
	local function apart(row: Row): number?
		local place = whereWalkingEnds(row)
		if place == nil then
			return nil
		end
		return Vector3.new(place.position.X - row.guide.X, 0, place.position.Z - row.guide.Z).Magnitude
	end

	local function describeRow(row: Row): string
		local note = if row.byStrap then "  (by the strap (walk area): not counted)" else ""
		local place, kind = whereWalkingEnds(row)
		local distance = apart(row)
		if place == nil or kind == nil or distance == nil then
			local last = row.lastSeen
			local ended = if last == nil
				then "no place was measured"
				else if row.ranOff
					then string.format(
						"the walk ran out of his piece at %s (%.1f degrees there), %.2f studs from the style guide",
						format(last.position),
						last.slope,
						Vector3.new(last.position.X - row.guide.X, 0, last.position.Z - row.guide.Z).Magnitude
					)
					else "the walk reached its full length without a turn"
			local wanted = if row.onCuff then `a {TURN} or the end of his arm` else `a {TURN}`
			return `{row.name}: the style guide says {format(row.guide)}; walking never ends at {wanted} ({ended})  <-- NO PLACE PAST {SEAM_ANGLE_DEGREES}{note}`
		end
		return string.format(
			"%s: the style guide says %s; walking ends at the %s at %s (%.1f degrees there): %.2f studs apart%s%s",
			row.name,
			format(row.guide),
			kind,
			format(place.position),
			place.slope,
			distance,
			if distance <= SEAM_MATCH then "" else "  <-- TOO FAR",
			note
		)
	end

	local function failures(rows: { Row }): { string }
		local lines: { string } = {}
		for _, row in rows do
			local distance = apart(row)
			if not row.byStrap and (distance == nil or distance > SEAM_MATCH) then
				table.insert(lines, describeRow(row))
			end
		end
		return lines
	end

	-- The message of a failing check: the places that fail first, then every place with its distance.
	local function report(rows: { Row }): string
		local bad = failures(rows)
		local all: { string } = {}
		for _, row in rows do
			table.insert(all, "  " .. describeRow(row))
		end
		return `\n{#bad} of {#rows} are not within {SEAM_MATCH} stud of the style guide's line (where walking ends, either a {TURN} or the end of his arm, is within {SEAM_MATCH} stud of the line):\n  {table.concat(
			bad,
			"\n  "
		)}\nevery place measured:\n{table.concat(all, "\n")}`
	end

	-- For plan 5's steep layer: the lines that list one walk's cloth that is steeper than the seam angle but that a
	-- character still walks on in Play (no steeper than SLIP_DEGREES, and only up to the first place that is). One line a
	-- walk, or "none".
	local STRAP_MOUTH_TAG = "(strap mouth: walk area, no steep layer)"
	local ARM_NOTE = " (past the end of his arm this test can't measure: plan 5, Task 15 uses the Play walk-off)"

	local function describeWalkedOn(row: Row): { string }
		local _, kind = whereWalkingEnds(row)
		local distance = apart(row)
		local howFar = if kind == nil or distance == nil
			then "no place where walking ends"
			else string.format("walking ends at the %s, %.2f studs from the guide", kind, distance)
		if row.byStrap then
			howFar ..= ", by the strap (walk area): not counted"
		end
		-- a cuff walk that ran off his arm can't be measured past the end of his arm
		local armNote = if row.onCuff and row.ranOff then ARM_NOTE else ""
		-- cloth in the strap's mouth (within half the strap's width of where it starts) is walk area: plan 5 leaves it out
		local forSteepLayer: { Place } = {}
		local inTheMouth: { Place } = {}
		for _, place in row.steeperThanSeam do
			local start = row.strapStart
			if place.slope > SLIP_DEGREES then
				break -- a character slips here in Play: this and everything farther on is not cloth they walk on
			end
			if
				start ~= nil
				and Vector3.new(place.position.X - start.X, 0, place.position.Z - start.Z).Magnitude <= STRAP_GAP
			then
				table.insert(inTheMouth, place)
			else
				table.insert(forSteepLayer, place)
			end
		end
		local function listLine(places: { Place }, tag: string): string
			return string.format(
				"%s (%s): %d places from %s to %s (%.1f to %.1f studs along the walk)%s%s",
				row.name,
				howFar,
				#places,
				format(places[1].position),
				format(places[#places].position),
				places[1].offset,
				places[#places].offset,
				tag,
				armNote
			)
		end
		local lines: { string } = {}
		if #forSteepLayer > 0 then
			table.insert(lines, listLine(forSteepLayer, ""))
		elseif #inTheMouth == 0 then
			table.insert(lines, `{row.name} ({howFar}): none{armNote}`)
		end
		if #inTheMouth > 0 then
			table.insert(lines, listLine(inTheMouth, " " .. STRAP_MOUTH_TAG))
		end
		return lines
	end

	-- Computed once: the walks read thousands of rays.
	local measured: { left: { Row }, right: { Row }, leftCuff: { Row }, rightCuff: { Row } }? = nil
	local function measure()
		if measured == nil then
			measured = {
				left = sideRows(SEAM_LEFT, "left", -1),
				right = sideRows(SEAM_RIGHT, "right", 1),
				leftCuff = cuffRows(CUFF_LEFT, "left", "left_arm", STRAP_START_LEFT),
				rightCuff = cuffRows(CUFF_RIGHT, "right", "right_arm", STRAP_START_RIGHT),
			}
		end
		return measured :: { left: { Row }, right: { Row }, leftCuff: { Row }, rightCuff: { Row } }
	end

	it("on his sides, he turns steeper than the seam angle within the seam match of the style guide's line", function()
		local rows: { Row } = {}
		for _, row in measure().left do
			table.insert(rows, row)
		end
		for _, row in measure().right do
			table.insert(rows, row)
		end
		expect(#rows).toBe(20)
		if #failures(rows) > 0 then
			error(report(rows), 0)
		end
	end)

	it(
		"on his cuffs, where walking ends, either a 65° turn or the end of his arm, is within 1 stud of the line",
		function()
			local rows: { Row } = {}
			for _, row in measure().leftCuff do
				table.insert(rows, row)
			end
			for _, row in measure().rightCuff do
				table.insert(rows, row)
			end
			expect(#rows).toBe(#CUFF_LEFT + #CUFF_RIGHT)
			-- the strap's gap must not swallow more of the line if the table or the strap moves
			local stationsInTheGap: { string } = {}
			for _, row in rows do
				if row.byStrap then
					table.insert(stationsInTheGap, row.name)
				end
			end
			expect(stationsInTheGap).toEqual({ "left cuff, station 5", "right cuff, station 5" })
			if #failures(rows) > 0 then
				error(report(rows), 0)
			end
		end
	)

	-- The end of his arm only counts on a cuff, and only when the walk really ran off his arm: a walk that reached its
	-- full length, or measured nothing, still fails. (Made-up walks; the world is not read.)
	it("counts the end of his arm only for a cuff walk that ran off his arm", function()
		local lastPlace: Place = { offset = 3, position = Vector3.new(0.75, 39, 0), slope = 40 }
		local function walkLike(changes: { onCuff: boolean?, ranOff: boolean?, lastSeen: Place?, first: Place? }): Row
			local row: Row = {
				name = "made-up walk",
				guide = Vector3.zero,
				first = changes.first,
				steeperThanSeam = {},
				lastSeen = changes.lastSeen,
				ranOff = changes.ranOff == true,
				onCuff = changes.onCuff == true,
				byStrap = false,
			}
			return row
		end
		-- a cuff walk that ran off his arm: the last place the square fit counts, with its distance
		local ranOffCuff = walkLike({ onCuff = true, ranOff = true, lastSeen = lastPlace })
		expect(apart(ranOffCuff)).toBe(0.75)
		expect(describeRow(ranOffCuff)).toContain("end of his arm")
		-- a cuff walk that reached its full length with no turn: no place
		expect(apart(walkLike({ onCuff = true, ranOff = false, lastSeen = lastPlace }))).toBeNil()
		-- a cuff walk that measured no place at all: no place
		expect(apart(walkLike({ onCuff = true, ranOff = true, lastSeen = nil }))).toBeNil()
		-- a side walk that ran off his piece: the end of his piece is not a place where walking ends
		expect(apart(walkLike({ onCuff = false, ranOff = true, lastSeen = lastPlace }))).toBeNil()
		-- a real 65° turn wins over the end of his arm
		local turn: Place = { offset = 1, position = Vector3.new(0.5, 39, 0), slope = 66 }
		local withTurn = walkLike({ onCuff = true, ranOff = true, lastSeen = lastPlace, first = turn })
		expect(apart(withTurn)).toBe(0.5)
		expect(describeRow(withTurn)).toContain("65° turn")
	end)

	-- A station by the strap is measured and shown, but never counts as a fail. (A made-up walk that finds no place.)
	it("shows a station by the strap as not counted, even if it finds no place", function()
		local byTheStrap: Row = {
			name = "made-up station",
			guide = Vector3.zero,
			first = nil,
			steeperThanSeam = {},
			lastSeen = nil,
			ranOff = false,
			onCuff = true,
			byStrap = true,
		}
		local elsewhere: Row = table.clone(byTheStrap)
		elsewhere.byStrap = false
		expect(failures({ byTheStrap })).toEqual({})
		expect(#failures({ elsewhere })).toBe(1)
		expect(describeRow(byTheStrap)).toContain("by the strap (walk area): not counted")
	end)

	-- The list for plan 5 stops where a character really slips in Play: at the first place steeper than SLIP_DEGREES,
	-- not at any gentler place farther on. (A made-up row: places at 66, 72, 79 and then 70 degrees.)
	it("lists only the cloth a character still walks on in Play, up to SLIP_DEGREES", function()
		local gentle: Place = { offset = 1, position = Vector3.new(-20, 43, -36), slope = 66 }
		local steep: Place = { offset = 2, position = Vector3.new(-21, 42, -36), slope = 72 }
		local slipping: Place = { offset = 3, position = Vector3.new(-22, 41, -36), slope = 79 }
		-- a gentler place farther on, past the steeper stretch: the character has already slipped by then
		local pastTheSlip: Place = { offset = 4, position = Vector3.new(-23, 30, -36), slope = 70 }
		local row: Row = {
			name = "made-up side",
			guide = Vector3.zero,
			first = gentle,
			steeperThanSeam = { gentle, steep, slipping, pastTheSlip },
			lastSeen = pastTheSlip,
			ranOff = false,
			onCuff = false,
			byStrap = false,
		}
		local text = table.concat(describeWalkedOn(row), "\n")
		expect(text).toContain("2 places")
		expect(text).toContain(format(gentle.position))
		expect(text).toContain(format(steep.position))
		expect(text).never.toContain(format(slipping.position))
		expect(text).never.toContain(format(pastTheSlip.position))
	end)

	-- A cuff row that ran off his arm can't see past the end of his arm, so its list line says plan 5 uses the Play
	-- walk-off there. (Made-up rows.)
	it("says on a cuff row that ran off his arm that the list can't see past the end of his arm", function()
		local place: Place = { offset = 1, position = Vector3.new(50, 39, -6), slope = 66 }
		local function cuffRow(ranOff: boolean, onCuff: boolean): Row
			return {
				name = "made-up row",
				guide = Vector3.zero,
				first = place,
				steeperThanSeam = { place },
				lastSeen = place,
				ranOff = ranOff,
				onCuff = onCuff,
				byStrap = false,
			}
		end
		local note = "past the end of his arm this test can't measure: plan 5, Task 15 uses the Play walk-off"
		expect(table.concat(describeWalkedOn(cuffRow(true, true)), "\n")).toContain(note)
		expect(table.concat(describeWalkedOn(cuffRow(false, true)), "\n")).never.toContain(note)
		expect(table.concat(describeWalkedOn(cuffRow(true, false)), "\n")).never.toContain(note)
	end)

	-- Cloth under the game's own slope limit never slips, so the list must reach at least that steep.
	it("never lists below the steepest slope the game lets a player stand on", function()
		expect(SLIP_DEGREES).toBeGreaterThanOrEqual(game:GetService("StarterPlayer").CharacterMaxSlopeAngle)
	end)

	-- A place in the strap's mouth is walk area, not cloth for the steep layer: the list says so, so plan 5 never covers
	-- the strap's way in. (A made-up walk.)
	it("tags cloth in the strap's mouth as walk area in the list for plan 5", function()
		local strapStart = Vector3.new(52, 38.3, 3.8)
		local inTheMouth: Place = { offset = 5, position = Vector3.new(50, 38, 4), slope = 67 }
		local outside: Place = { offset = 6, position = Vector3.new(48, 38, -6), slope = 68 }
		local row: Row = {
			name = "made-up cuff",
			guide = Vector3.zero,
			first = nil,
			steeperThanSeam = { inTheMouth, outside },
			lastSeen = nil,
			ranOff = false,
			onCuff = true,
			byStrap = false,
			strapStart = strapStart,
		}
		local lines = describeWalkedOn(row)
		local tag = STRAP_MOUTH_TAG
		local tagged, untagged = {}, {}
		for _, line in lines do
			table.insert(if string.find(line, tag, 1, true) then tagged else untagged, line)
		end
		-- the place in the mouth is on a tagged line alone; the other place is on a plain line alone
		expect(#tagged).toBe(1)
		expect(tagged[1]).toContain(format(inTheMouth.position))
		expect(tagged[1]).never.toContain(format(outside.position))
		expect(#untagged).toBe(1)
		expect(untagged[1]).toContain(format(outside.position))
		expect(untagged[1]).never.toContain(format(inTheMouth.position))
	end)

	-- For plan 5's steep layer: the cloth that is steeper than the seam angle but that a character still walks on in Play
	-- (up to SLIP_DEGREES), found on every walk. It never fails; it writes one line a walk.
	it(
		"lists the cloth below the seam that a character still walks on in Play (up to SLIP_DEGREES degrees), for plan 5's steep layer",
		function()
			local all: { Row } = {}
			for _, group in { measure().left, measure().right, measure().leftCuff, measure().rightCuff } do
				for _, row in group do
					table.insert(all, row)
				end
			end
			local lines: { string } = {}
			for _, row in all do
				for _, line in describeWalkedOn(row) do
					table.insert(lines, line)
				end
			end
			print(
				`Seam: where walking ends on every walk, and the cloth below the seam that a character still walks on in Play (steeper than {SEAM_ANGLE_DEGREES} and up to SLIP_DEGREES, {SLIP_DEGREES} degrees), for plan 5's steep layer\n`
					.. table.concat(lines, "\n")
			)
			expect(#all).toBe(20 + #CUFF_LEFT + #CUFF_RIGHT)
		end
	)
end)

-- Stuck safety Task 22, test 2 (docs/plans/v2/stuck-safety.md, "Ruling 1"): the pillow gets the closer fit, the same as
-- his body, so the solid shape players stand on is the pillow they see. Only its collision settings change: its
-- texture, size and place stay as they were. These tests only READ the world.
describe("the real world, the pillow's closer fit", function()
	local Workspace = game:GetService("Workspace")

	local CLOSER_FIT_PRECISION = 0.99
	-- Measured in step 22-0 (before the change). The numbers were printed to six places.
	local PILLOW_TEXTURE_ID = "rbxassetid://138710597423165" -- measured in step 22-0
	local PILLOW_SIZE = Vector3.new(95.004646, 91.194412, 35.748734) -- measured in step 22-0
	local PILLOW_CFRAME =
		CFrame.new(0.142862, 79.860550, 52.141579, 1, 0, 0, 0, 0.939693, 0.342020, 0, -0.342020, 0.939692) -- measured in step 22-0
	local SAME_WITHIN = 0.001 -- studs, or a rotation number: the step 22-0 numbers have six places
	-- The look of the ArtLibrary original (ServerStorage.ArtLibrary._Generated.Pillow.body.body_geom), read in step 22-6c.
	local PILLOW_COLOR = Color3.fromRGB(163, 162, 165)
	local PILLOW_MATERIAL = Enum.Material.Plastic
	local PILLOW_MATERIAL_VARIANT = ""
	local PILLOW_TRANSPARENCY = 0
	local PILLOW_REFLECTANCE = 0

	it("the pillow stands on its closer fit", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local mesh = (world :: any).GiantsThings.Pillow.body.body_geom :: MeshPart
		local wrong: { string } = {}
		if mesh.CollisionFidelity ~= Enum.CollisionFidelity.Tunable then
			table.insert(wrong, `CollisionFidelity is {mesh.CollisionFidelity.Name}, wanted Tunable`)
		end
		if mesh.CollisionPrecision < CLOSER_FIT_PRECISION then
			table.insert(
				wrong,
				`CollisionPrecision is {mesh.CollisionPrecision}, wanted at least {CLOSER_FIT_PRECISION}`
			)
		end
		if mesh.TextureID ~= PILLOW_TEXTURE_ID then
			table.insert(wrong, `TextureID is {mesh.TextureID}, wanted {PILLOW_TEXTURE_ID}`)
		end
		if (mesh.Size - PILLOW_SIZE).Magnitude > SAME_WITHIN then
			table.insert(wrong, `Size is {mesh.Size}, wanted {PILLOW_SIZE}`)
		end
		local now = { mesh.CFrame:GetComponents() }
		local before = { PILLOW_CFRAME:GetComponents() }
		for index = 1, #before do
			if math.abs(now[index] - before[index]) > SAME_WITHIN then
				table.insert(wrong, `CFrame is {mesh.CFrame}, wanted {PILLOW_CFRAME} (number {index} differs)`)
				break
			end
		end
		expect(wrong).toEqual({})
	end)

	-- The precise solid shape shades the piece itself in Roblox's lighting, so the pillow looked dark navy and tan
	-- instead of light blue and cream. Step 22-6a and 22-6b checked his four pieces: they stay light, so only the pillow
	-- turns its shadow off. The look values must stay the ArtLibrary original's.
	it("the closer-fit pieces keep their look", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local mesh = (world :: any).GiantsThings.Pillow.body.body_geom :: MeshPart
		local wrong: { string } = {}
		if mesh.CastShadow then
			table.insert(wrong, "CastShadow is true, wanted false (the solid shape shades the pillow itself)")
		end
		if mesh.Color ~= PILLOW_COLOR then
			table.insert(wrong, `Color is {mesh.Color}, wanted {PILLOW_COLOR}`)
		end
		if mesh.Material ~= PILLOW_MATERIAL then
			table.insert(wrong, `Material is {mesh.Material.Name}, wanted {PILLOW_MATERIAL.Name}`)
		end
		if mesh.MaterialVariant ~= PILLOW_MATERIAL_VARIANT then
			table.insert(wrong, `MaterialVariant is '{mesh.MaterialVariant}', wanted '{PILLOW_MATERIAL_VARIANT}'`)
		end
		if mesh.Transparency ~= PILLOW_TRANSPARENCY then
			table.insert(wrong, `Transparency is {mesh.Transparency}, wanted {PILLOW_TRANSPARENCY}`)
		end
		if mesh.Reflectance ~= PILLOW_REFLECTANCE then
			table.insert(wrong, `Reflectance is {mesh.Reflectance}, wanted {PILLOW_REFLECTANCE}`)
		end
		if mesh.TextureID ~= PILLOW_TEXTURE_ID then
			table.insert(wrong, `TextureID is {mesh.TextureID}, wanted {PILLOW_TEXTURE_ID}`)
		end
		expect(wrong).toEqual({})
	end)
end)

-- Stuck safety Task 22, test 3 (docs/plans/v2/stuck-safety.md, "Ruling 4: flush for a filled pocket"): the patches are
-- invisible solid blocks in World.WalkSurfaces.Patches that fill the cracks and pockets in his shape. A patch inside a
-- sealed pocket has no surface a player can reach, so the check measures only what a player can reach:
--   Folder:   the folder exists and holds at least one patch.
--   Settings: every patch has the settings of V1's steep guards.
--   Tops:     wherever a ray straight down meets a patch first, that point is within check 6's limits of his drawn skin.
--   Sides:    no ray from 3 studs outside a side face, toward the face, meets the patch first. Rays that start under the
--             grass don't count.
-- The checker is a function over a world, a folder and a drawn skin, so two made-up worlds can prove it bites.
describe("the real world, the patches", function()
	local Workspace = game:GetService("Workspace")

	-- The steep guards' settings, measured in step 22-0 (all 30 guards are identical). A patch is a Part or a WedgePart.
	local GUARD_TRANSPARENCY = 1 -- measured in step 22-0
	local GUARD_CAN_COLLIDE = true -- measured in step 22-0
	local GUARD_CAN_QUERY = true -- measured in step 22-0
	local GUARD_CAN_TOUCH = false -- measured in step 22-0
	local GUARD_CAST_SHADOW = false -- measured in step 22-0
	local GUARD_MATERIAL = Enum.Material.SmoothPlastic -- measured in step 22-0
	local GUARD_COLLISION_GROUP = "Default" -- measured in step 22-0
	local GUARD_ANCHORED = true -- measured in step 22-0
	local GUARD_ARCHIVABLE = true -- measured in step 22-0

	-- Check 6's limits and its sideways search (outsideLimits, sidewaysFit) are the ones at the top of this file.

	local GRID_STEP = 1 -- studs: the rays are this far apart over each face
	local RAY_OUTSIDE = 3 -- studs: a ray starts this far above a top, or outside a side
	local RAY_MARGIN = 0.5 -- studs: ...and reaches this far past the face
	local MIN_TOP_NORMAL = 0.1 -- a face counts as a top only when it faces up at least this much
	local PROBE_SIZE = 0.2 -- studs: the ball that tests whether a side ray starts inside a solid
	local GRASS_RAY_ABOVE = 500 -- studs: the grass is found by a ray down from this far over the start of a side ray
	local PROBE_NAME = "PatchSideProbe"
	-- The scan's body (Config.Stuck, and PathCheck's lift): a box BODY_WIDTH wide and deep that starts BODY_LIFT above the
	-- feet and ends BODY_HEIGHT above them. A top counts only where this body has room to stand on it. A side ray counts
	-- only where this body has room to stand beside the face, with the face point at the bottom, middle or top of the box.
	local BODY_WIDTH = Config.Stuck.BodyWidth -- studs
	local BODY_HEIGHT = Config.Stuck.BodyHeight -- studs: from the feet to the top of the head
	local BODY_LIFT = 0.5 -- studs: PathCheck's lift of the box above the feet (a player steps over less than that)
	local FOOT_GAP = 0.1 -- studs: a foot beside a face is this far past half a body's width from it
	local POINT_FROM_BOX_END = 0.6 -- studs: the face point is this far inside the box's bottom, or its top
	local MIN_FLAT_SIDE = 1e-3 -- a face whose outward direction is flatter than this has no sideways direction
	local BOX_HEIGHT = BODY_HEIGHT - BODY_LIFT
	local POINT_ABOVE_BOX_BOTTOM = { POINT_FROM_BOX_END, BOX_HEIGHT / 2, BOX_HEIGHT - POINT_FROM_BOX_END }
	local EXAMPLES_SHOWN = 3 -- most points written out for each problem line
	local BUILD_TIMEOUT_MS = 60000 -- reading the six meshes takes a few seconds
	local TEST_TIMEOUT_MS = 60000

	-- The points of a 1-stud grid over a face, in world space.
	local function gridOver(patch: BasePart, face: Face): { Vector3 }
		local points: { Vector3 } = {}
		local uCount = math.max(1, math.round(2 * face.uHalf / GRID_STEP))
		local vCount = math.max(1, math.round(2 * face.vHalf / GRID_STEP))
		for i = 1, uCount do
			for j = 1, vCount do
				local u = ((i - 0.5) / uCount * 2 - 1) * face.uHalf
				local v = ((j - 0.5) / vCount * 2 - 1) * face.vHalf
				table.insert(points, patch.CFrame:PointToWorldSpace(face.center + face.u * u + face.v * v))
			end
		end
		return points
	end

	local function describeDirection(direction: Vector3): string
		return string.format("(%.0f, %.0f, %.0f)", direction.X, direction.Y, direction.Z)
	end

	-- Whether a body fits standing beside a face. Three feet are tried: each is the face point moved out along the face's
	-- flat outward direction, and lowered so that the point is near the bottom, the middle or the top of the body box.
	local function bodyFitsBeside(options: PathCheck.Options, point: Vector3, outward: Vector3): boolean
		local flat = Vector3.new(outward.X, 0, outward.Z)
		local away = if flat.Magnitude > MIN_FLAT_SIDE then flat.Unit else outward
		local beside = point + away * (BODY_WIDTH / 2 + FOOT_GAP)
		for _, above in POINT_ABOVE_BOX_BOTTOM do
			local feet = Vector3.new(beside.X, point.Y - BODY_LIFT - above, beside.Z)
			if PathCheck.roomToStand(options, feet) then
				return true
			end
		end
		return false
	end

	-- The checker. Returns its problems as sentences, each starting with the name of its rule; none means the patches
	-- pass. `world` is the Workspace, or a made-up WorldModel. A top counts only where a body can stand on it, and a side
	-- only where a body can stand beside it (see BODY_WIDTH). Use patchProblems, which cleans up when a check throws.
	-- `smallFolder` (Task 23, Ruling 11) is World.WalkSurfaces.SmallPatches: only its `Patch_<Place>_<n>` blocks are read
	-- like the patches; its `Ramp_<Place>_<n>` blocks have their own test.
	local SMALL_PATCH_PREFIX = "Patch_"
	local function runPatchChecks(
		world: WorldRoot,
		folder: Instance?,
		skin: DrawnSkin.Skin,
		smallFolder: Instance?
	): { string }
		-- (a) Folder
		local patches: { BasePart } = {}
		if folder ~= nil then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(patches, descendant)
				end
			end
		end
		if smallFolder ~= nil then
			for _, descendant in smallFolder:GetDescendants() do
				if
					descendant:IsA("BasePart")
					and string.sub(descendant.Name, 1, #SMALL_PATCH_PREFIX) == SMALL_PATCH_PREFIX
				then
					table.insert(patches, descendant)
				end
			end
		end
		if #patches == 0 then
			return { "Folder: World.WalkSurfaces.Patches is missing or holds no patch" }
		end

		local problems: { string } = {}
		-- The body rule's settings, made once per run (the body check keeps a probe of its own in the world).
		local options = PathCheck.defaults(world)
		-- A ray sees what a player bumps into.
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = Collisions.GROUP
		-- A ray that sees only the grass.
		local grassOnly = RaycastParams.new()
		grassOnly.FilterType = Enum.RaycastFilterType.Include
		grassOnly.FilterDescendantsInstances = { Workspace.Terrain }
		-- A small ball that is moved to the start of each side ray: a start inside a solid has nothing to reach the patch
		-- from, so that ray doesn't count. It is made once per run and destroyed at the end.
		local probe = Instance.new("Part")
		probe.Name = PROBE_NAME
		probe.Shape = Enum.PartType.Ball
		probe.Size = Vector3.one * PROBE_SIZE
		probe.Anchored = true
		probe.CanCollide = false
		probe.CanQuery = true
		probe.Archivable = false
		probe.Parent = world
		local insideCheck = OverlapParams.new()
		insideCheck.RespectCanCollide = true
		insideCheck.CollisionGroup = Collisions.GROUP
		insideCheck.FilterType = Enum.RaycastFilterType.Exclude
		insideCheck.FilterDescendantsInstances = { probe, folder :: Instance }

		for _, patch in patches do
			-- (b) Settings
			local wrong: { string } = {}
			if not (patch.ClassName == "Part" or patch.ClassName == "WedgePart") then
				table.insert(wrong, `class {patch.ClassName}`)
			end
			if patch.Transparency ~= GUARD_TRANSPARENCY then
				table.insert(wrong, `Transparency {patch.Transparency}`)
			end
			if patch.CanCollide ~= GUARD_CAN_COLLIDE then
				table.insert(wrong, `CanCollide {patch.CanCollide}`)
			end
			if patch.CanQuery ~= GUARD_CAN_QUERY then
				table.insert(wrong, `CanQuery {patch.CanQuery}`)
			end
			if patch.CanTouch ~= GUARD_CAN_TOUCH then
				table.insert(wrong, `CanTouch {patch.CanTouch}`)
			end
			if patch.CastShadow ~= GUARD_CAST_SHADOW then
				table.insert(wrong, `CastShadow {patch.CastShadow}`)
			end
			if patch.Material ~= GUARD_MATERIAL then
				table.insert(wrong, `Material {patch.Material.Name}`)
			end
			if patch.CollisionGroup ~= GUARD_COLLISION_GROUP then
				table.insert(wrong, `CollisionGroup {patch.CollisionGroup}`)
			end
			if patch.Anchored ~= GUARD_ANCHORED then
				table.insert(wrong, `Anchored {patch.Anchored}`)
			end
			if patch.Archivable ~= GUARD_ARCHIVABLE then
				table.insert(wrong, `Archivable {patch.Archivable}`)
			end
			if #wrong > 0 then
				table.insert(
					problems,
					`Settings: {patch.Name} differs from the steep guards: {table.concat(wrong, ", ")}`
				)
			end

			-- The top face faces up the most, the bottom face the least; the others are sides.
			local faces = facesOf(patch)
			local topIndex, bottomIndex = 1, 1
			for index, face in faces do
				local up = patch.CFrame:VectorToWorldSpace(face.normal).Y
				if up > patch.CFrame:VectorToWorldSpace(faces[topIndex].normal).Y then
					topIndex = index
				end
				if up < patch.CFrame:VectorToWorldSpace(faces[bottomIndex].normal).Y then
					bottomIndex = index
				end
			end

			-- (c) Tops
			local topNormal = patch.CFrame:VectorToWorldSpace(faces[topIndex].normal)
			if topNormal.Y >= MIN_TOP_NORMAL then
				local met, bad = 0, 0
				local examples: { string } = {}
				for _, point in gridOver(patch, faces[topIndex]) do
					local hit = world:Raycast(
						point + Vector3.new(0, RAY_OUTSIDE, 0),
						Vector3.new(0, -(RAY_OUTSIDE + RAY_MARGIN), 0),
						params
					)
					if
						hit ~= nil
						and hit.Instance == patch
						and PathCheck.roomToStand(options, hit.Position, hit.Normal)
					then
						met += 1
						local drawn = skin.heightAt(hit.Position.X, hit.Position.Z, hit.Position.Y + SKIN_SEARCH_ABOVE)
						local gap = if drawn == nil then 0 / 0 else hit.Position.Y - drawn
						if
							outsideLimits(gap)
							and sidewaysFit(skin, hit.Position.X, hit.Position.Z, hit.Position.Y) == nil
						then
							bad += 1
							if #examples < EXAMPLES_SHOWN then
								local gapText = if gap ~= gap
									then "no drawn skin under it"
									else string.format("%+.2f", gap)
								table.insert(examples, `{describePoint(hit.Position)} {gapText}`)
							end
						end
					end
				end
				if bad > 0 then
					table.insert(
						problems,
						`Tops: {patch.Name}: {bad} of {met} points a player can reach are not within {ABOVE_LIMIT} over or {BELOW_LIMIT} under his drawn skin, such as {table.concat(
							examples,
							", "
						)}`
					)
				end
			end

			-- (d) Sides
			for index, face in faces do
				if index ~= topIndex and index ~= bottomIndex then
					local outward = patch.CFrame:VectorToWorldSpace(face.normal)
					local met, total = 0, 0
					local examples: { string } = {}
					for _, point in gridOver(patch, face) do
						local start = point + outward * RAY_OUTSIDE
						local grass = world:Raycast(
							start + Vector3.new(0, GRASS_RAY_ABOVE, 0),
							Vector3.new(0, -GRASS_RAY_ABOVE - 1000, 0),
							grassOnly
						)
						probe.Position = start
						local insideSolid = #world:GetPartsInPart(probe, insideCheck) > 0
						-- a start under the grass or inside a solid doesn't count
						if not insideSolid and (grass == nil or grass.Position.Y <= start.Y) then
							total += 1
							local hit = world:Raycast(start, -outward * (RAY_OUTSIDE + RAY_MARGIN), params)
							if hit ~= nil and hit.Instance == patch and bodyFitsBeside(options, point, outward) then
								met += 1
								if #examples < EXAMPLES_SHOWN then
									table.insert(examples, describePoint(hit.Position))
								end
							end
						end
					end
					if met > 0 then
						table.insert(
							problems,
							`Sides: {patch.Name}, the side facing {describeDirection(outward)}: {met} of {total} rays from {RAY_OUTSIDE} studs outside meet the patch first, with room for a body beside it, such as {table.concat(
								examples,
								", "
							)}`
						)
					end
				end
			end
		end
		probe:Destroy()
		PathCheck.cleanup(options)
		return problems
	end

	-- runPatchChecks, with its two probes (this one's ball and the body check's box) taken out of the world even when a
	-- check throws.
	local function patchProblems(
		world: WorldRoot,
		folder: Instance?,
		skin: DrawnSkin.Skin,
		smallFolder: Instance?
	): { string }
		local ok, result = pcall(runPatchChecks, world, folder, skin, smallFolder)
		if not ok then
			for _, child in world:GetChildren() do
				if child.Name == PROBE_NAME then
					child:Destroy()
				end
			end
			PathCheck.cleanup(PathCheck.defaults(world))
			error(result, 0)
		end
		return result
	end

	-- A flat drawn skin at height 10 made of two triangles, 40 studs square.
	local function flatSkin(): DrawnSkin.Skin
		local a, b = Vector3.new(-20, 10, -20), Vector3.new(20, 10, -20)
		local c, d = Vector3.new(20, 10, 20), Vector3.new(-20, 10, 20)
		return DrawnSkin.new({ { a = a, b = b, c = c }, { a = a, b = c, c = d } }, {})
	end

	-- A patch with the steep guards' settings, in a folder inside the world (Patches, or `folderName`).
	local function addPatch(
		world: WorldModel,
		name: string,
		position: Vector3,
		size: Vector3,
		folderName: string?
	): Part
		local wanted = folderName or "Patches"
		local folder: Instance? = world:FindFirstChild(wanted)
		if folder == nil then
			local made = Instance.new("Folder")
			made.Name = wanted
			made.Parent = world
			folder = made
		end
		local patch = Instance.new("Part")
		patch.Name = name
		patch.Size = size
		patch.Position = position
		patch.Transparency = GUARD_TRANSPARENCY
		patch.CanCollide = GUARD_CAN_COLLIDE
		patch.CanQuery = GUARD_CAN_QUERY
		patch.CanTouch = GUARD_CAN_TOUCH
		patch.CastShadow = GUARD_CAST_SHADOW
		patch.Material = GUARD_MATERIAL
		patch.CollisionGroup = GUARD_COLLISION_GROUP
		patch.Anchored = GUARD_ANCHORED
		patch.Archivable = GUARD_ARCHIVABLE
		patch.Parent = folder
		return patch
	end

	local function addWall(world: WorldModel, position: Vector3, size: Vector3)
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Size = size
		wall.Position = position
		wall.Anchored = true
		wall.CanCollide = true
		wall.Parent = world
	end

	it("the patch check names a block that stands up in the open", function()
		inFakeWorld(function(world)
			addPatch(world, "Patch_Test_1", Vector3.new(0, 10, 0), Vector3.new(4, 2, 4)) -- its top is at height 11
			local problems = patchProblems(world, world:FindFirstChild("Patches"), flatSkin())
			local tops = startsWith(problems, "Tops:")
			expect(#tops).toBe(1)
			expect((string.find(tops[1], "Patch_Test_1", 1, true))).never.toBeNil()
		end)
	end)

	it("the patch check names only the open side of a block sunk under the skin", function()
		inFakeWorld(function(world)
			-- Its top is at height 9.9, 0.1 under the skin: fine. Walls touch three of its four sides.
			addPatch(world, "Patch_Test_2", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4))
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6)) -- the -X side
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6)) -- the +X side
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1)) -- the -Z side
			local problems = patchProblems(world, world:FindFirstChild("Patches"), flatSkin())
			expect(#startsWith(problems, "Tops:")).toBe(0)
			local sides = startsWith(problems, "Sides:")
			expect(#sides).toBe(1)
			expect((string.find(sides[1], "(0, 0, 1)", 1, true))).never.toBeNil() -- the +Z side, the one left open
			expect(#problems).toBe(1)
		end)
	end)

	it("the patch check ignores side rays that start inside a solid", function()
		inFakeWorld(function(world)
			-- The same block under the skin and the same three walls...
			addPatch(world, "Patch_Test_3", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4))
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1))
			-- ...and a solid 4 studs thick on the +Z side, so every side ray on that face starts inside it.
			addWall(world, Vector3.new(0, 9, 4), Vector3.new(4, 6, 4))
			expect(patchProblems(world, world:FindFirstChild("Patches"), flatSkin())).toEqual({})
		end)
	end)

	it("the patch check skips a top no body can stand on", function()
		inFakeWorld(function(world)
			-- The first test's block: its top is at height 11, in the open...
			addPatch(world, "Patch_Test_4", Vector3.new(0, 10, 0), Vector3.new(4, 2, 4))
			-- ...under a ceiling 3 studs thick. Its underside (12.5) is 1.5 over the block's top, and it reaches 1 stud
			-- past the block on every side. A body is taller than 1.5, so none stands on the block, and every top ray
			-- starts inside the ceiling.
			addWall(world, Vector3.new(0, 14, 0), Vector3.new(6, 3, 6))
			local problems = patchProblems(world, world:FindFirstChild("Patches"), flatSkin())
			expect(#startsWith(problems, "Tops:")).toBe(0)
		end)
	end)

	it("the patch check skips a side no body can touch", function()
		inFakeWorld(function(world)
			-- The second test's block under the skin and its three walls...
			addPatch(world, "Patch_Test_5", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4)) -- top 9.9, bottom 7.9
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1))
			-- ...and on the open +Z side a floor (top at the block's bottom, 7.9) and a ceiling (underside 0.1 over the
			-- block's top, 10). Both reach 6 studs out and are 6 wide, 1 stud wider than the block on each side. The slot
			-- between them is 2.1 tall: too low for a body to stand in or beside.
			addWall(world, Vector3.new(0, 7.4, 5), Vector3.new(6, 1, 6))
			addWall(world, Vector3.new(0, 10.5, 5), Vector3.new(6, 1, 6))
			expect(patchProblems(world, world:FindFirstChild("Patches"), flatSkin())).toEqual({})
		end)
	end)

	it("the patch check counts a neighbouring patch as solid", function()
		inFakeWorld(function(world)
			-- Two blocks, side by side, 0.1 under the skin. They share a face at x = 0.
			addPatch(world, "Patch_Test_6", Vector3.new(-2, 8.9, 0), Vector3.new(4, 2, 4))
			addPatch(world, "Patch_Test_7", Vector3.new(2, 8.9, 0), Vector3.new(4, 2, 4))
			-- Walls close their outer sides: -X, +X, and one long wall each on -Z and +Z.
			addWall(world, Vector3.new(-4.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(4.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(10, 6, 1))
			addWall(world, Vector3.new(0, 9, 2.5), Vector3.new(10, 6, 1))
			expect(patchProblems(world, world:FindFirstChild("Patches"), flatSkin())).toEqual({})
		end)
	end)

	-- Task 23 (Ruling 11): World.WalkSurfaces.SmallPatches holds Task 23's flush patches (`Patch_<Place>_<n>`, read here
	-- like the patches of Task 22) and its ramps on meadow props (`Ramp_<Place>_<n>`, read by their own test below).
	it("the patch check also reads the Patch_ blocks of the small patches folder", function()
		inFakeWorld(function(world)
			addPatch(world, "Patch_Test_8", Vector3.new(0, 10, 0), Vector3.new(4, 2, 4), SMALL_PATCHES_FOLDER) -- top at height 11
			local problems = patchProblems(world, nil, flatSkin(), world:FindFirstChild(SMALL_PATCHES_FOLDER))
			local tops = startsWith(problems, "Tops:")
			expect(#tops).toBe(1)
			expect((string.find(tops[1], "Patch_Test_8", 1, true))).never.toBeNil()
		end)
	end)

	it("the patch check leaves a Ramp_ block of the small patches folder alone", function()
		inFakeWorld(function(world)
			-- The sealed block of the third test, in Patches, with its four walls: it passes.
			addPatch(world, "Patch_Test_3", Vector3.new(0, 8.9, 0), Vector3.new(4, 2, 4))
			addWall(world, Vector3.new(-2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(2.5, 9, 0), Vector3.new(1, 6, 6))
			addWall(world, Vector3.new(0, 9, -2.5), Vector3.new(6, 6, 1))
			addWall(world, Vector3.new(0, 9, 4), Vector3.new(4, 6, 4))
			-- A ramp in the open in SmallPatches would fail Tops if it were read.
			addPatch(world, "Ramp_Test_1", Vector3.new(12, 10, 12), Vector3.new(4, 2, 4), SMALL_PATCHES_FOLDER)
			local problems = patchProblems(
				world,
				world:FindFirstChild("Patches"),
				flatSkin(),
				world:FindFirstChild(SMALL_PATCHES_FOLDER)
			)
			expect(problems).toEqual({})
		end)
	end)

	it("patches sit on his drawn skin, or are sealed inside him", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walkSurfaces = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walkSurfaces).never.toBeNil()
		local giant = (world :: Instance):FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local meshes: { MeshPart } = {}
		for _, name in BODY_PIECES do
			local piece = (giant :: Instance):FindFirstChild(name)
			expect(piece).never.toBeNil()
			table.insert(meshes, (piece :: Instance):FindFirstChild(name) :: MeshPart)
		end
		local skin = DrawnSkin.fromWorld(meshes, {})
		local problems = patchProblems(
			Workspace,
			(walkSurfaces :: Instance):FindFirstChild("Patches"),
			skin,
			(walkSurfaces :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER)
		)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, BUILD_TIMEOUT_MS + TEST_TIMEOUT_MS)
end)

-- Stuck safety Task 22, test 6 (docs/plans/v2/stuck-safety.md, code_lead's panel ruling after the rule C rerun): the
-- cave's mouth is closed by a visible skirt of 20 blocks in World.CaveSkirt. What a player sees is what the player bumps
-- into (Rule 20, One collision source), so the skirt is drawn, solid, and wears designer's look.
describe("the real world, the cave skirt", function()
	local Workspace = game:GetService("Workspace")
	local PhysicsService = game:GetService("PhysicsService")

	local SKIRT_BLOCKS = 20 -- panel ruling: the 20 lid blocks of the final cave blocks
	local CAVE_CAP_Y = 47.0 -- studs: panel ruling: every skirt top is at or under this, so the free spots keep their room
	local TOP_SLACK = 0.001 -- studs: rounding in the numbers written into the world
	-- designer on the cave skirt's look, decisions-plans.md. If designer switches to the shaded red #8A1C22, only the
	-- colour changes.
	local SKIRT_MATERIAL = Enum.Material.SmoothPlastic
	local SKIRT_COLOR = Color3.fromRGB(194, 56, 62) -- #C2383E
	local SKIRT_CAST_SHADOW = false

	it("the cave skirt is drawn and solid", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local folder = (world :: Instance):FindFirstChild("CaveSkirt")
		expect(folder).never.toBeNil()

		local blocks: { BasePart } = {}
		for _, child in (folder :: Instance):GetChildren() do
			if child:IsA("BasePart") then
				table.insert(blocks, child)
			end
		end
		expect(#blocks).toBe(SKIRT_BLOCKS)

		local problems: { string } = {}
		for _, block in blocks do
			local name = block.Name
			if block.Transparency ~= 0 then
				table.insert(problems, `Visible: {name} has Transparency {block.Transparency}, not 0`)
			end
			if not block.CanCollide then
				table.insert(problems, `Solid: {name} has CanCollide off`)
			end
			if not block.CanQuery then
				table.insert(problems, `Solid: {name} has CanQuery off`)
			end
			if not block.CanTouch then
				table.insert(problems, `Solid: {name} has CanTouch off`)
			end
			if not block.Anchored then
				table.insert(problems, `Solid: {name} is not anchored`)
			end
			if not PhysicsService:CollisionGroupsAreCollidable(Collisions.GROUP, block.CollisionGroup) then
				table.insert(
					problems,
					`Solid: {name} is in collision group {block.CollisionGroup}, which players walk through`
				)
			end
			if block.Material ~= SKIRT_MATERIAL then
				table.insert(problems, `Look: {name} has Material {block.Material.Name}`)
			end
			if block.Color ~= SKIRT_COLOR then
				table.insert(problems, `Look: {name} has Color {tostring(block.Color)}, not {tostring(SKIRT_COLOR)}`)
			end
			if block.MaterialVariant ~= "" then
				table.insert(problems, `Look: {name} has MaterialVariant "{block.MaterialVariant}"`)
			end
			if block.CastShadow ~= SKIRT_CAST_SHADOW then
				table.insert(problems, `Look: {name} has CastShadow {tostring(block.CastShadow)}`)
			end
			for _, child in block:GetDescendants() do
				if child:IsA("Decal") or child:IsA("SurfaceAppearance") then
					table.insert(problems, `Look: {name} has a {child.ClassName} called {child.Name}`)
				end
			end
			local top = block.Position.Y + block.Size.Y / 2
			if top > CAVE_CAP_Y + TOP_SLACK then
				table.insert(problems, `Top: {name} top is {top}, over {CAVE_CAP_Y}`)
			end
		end
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)
end)

-- Stuck safety Task 23, test 4 (docs/plans/v2/stuck-safety.md, Task 23 test 3 and product's condition 1): the slide
-- guards in World.WalkSurfaces.SlideGuards are steep enough to slide off, stand only on steep cloth (or the chair), and
-- stay clear of the places players need. The checker takes everything it reads as input, so the fake-world tests below
-- can prove that each rule bites.
describe("the real world, slide guards", function()
	local Workspace = game:GetService("Workspace")

	local GUARD_FOLDER = "SlideGuards" -- World.WalkSurfaces.SlideGuards (stuck safety Task 23, decision 3)
	local BUILD_TIMEOUT_MS = 60000 -- reading the seven meshes takes a few seconds
	local TEST_TIMEOUT_MS = 60000

	type Box = { name: string, min: Vector3, max: Vector3 }
	type Need = PlayerNeeds.Need
	type Context = {
		world: WorldRoot, -- the world the guards are in (the probe ball goes here)
		clothParams: RaycastParams, -- what a ray from a guard's face, aimed in at the cloth, may hit: the cloth only
		-- his body-size slope at a cloth point, given the direction the guard's top face points there (so a place under a
		-- roof is read square to the face), or nil when it can't be read: a ray missed
		slopeAt: (point: Vector3, normal: Vector3) -> number?,
		clothNameAt: (x: number, z: number) -> string?, -- the name of the cloth piece on top at (x, z), or nil with none
		chairBoxes: { Box }, -- body_and_cushion cloth inside any of these counts as the chair
		-- a guard named like BEARD_POCKET_GUARD_PATTERN with all 8 corners inside one of these skips the Cloth check
		beardPocketBoxes: { Box },
		solids: { Instance }, -- what a buried face or a buried corner is buried in
		needs: { Need }, -- the places players need, and the seam
	}

	-- Product's condition 1 (docs/specs/v2/research/decisions-plans.md, "product on slide guards in the Belly zone") and
	-- the plan's Task 23 test 3.
	local MIN_GUARD_DEGREES = 72 -- a guard's faces that face up are at least this steep (V1's guards are 75 to 80)
	local MAX_UP_NORMAL_Y = math.cos(math.rad(MIN_GUARD_DEGREES)) -- a face this steep has an up-direction of at most this
	local UP_FACE_MIN = 0.001 -- a face counts as facing up when its up-direction is more than this
	local NORMAL_SLACK = 1e-6 -- rounding in a face's direction
	local MIN_CLOTH_DEGREES = 65 -- a guard stands on cloth this steep or more (spec 5, "Seam angle", the body-size slope)
	local KEEP_AWAY = 2 -- studs from every place players need, the seam and spec 5's steep layer
	local BURY_STEP = 1 -- studs between the points checked on a face that faces up too flat
	local SURFACE_STEP = 0.5 -- studs between the points of a guard's surface, for the distance to a walk piece
	local SEGMENT_STEP = 0.25 -- studs between the points checked along a route link
	local PROBE_SIZE = 0.2 -- studs: the ball that tests whether a point is inside a solid
	local PROBE_NAME = "SlideGuardProbe"
	local EXAMPLES_SHOWN = 3
	-- The chair is part of this cloth piece's mesh, so only this cloth can be the chair (code_lead's ruling after 23-3).
	-- His arms on the chair arms are in legs_and_boots and must be 65 degrees or steeper like any other cloth.
	local CHAIR_CLOTH = "body_and_cushion"
	-- Cloth under a guard is looked for from the 4 corners and the middle of its top face, this far in (code_lead's ruling
	-- after step 23-8a, round 1, point 2a). With no cloth within reach the guard hangs over open air.
	local CLOTH_REACH = 2 -- studs
	-- Ruling 13 (docs/specs/v2/research/decisions-plans.md, "Task 23: the beard pocket and the decision table", approved by
	-- product on 2026-10-26): the three beard pocket spots sit on cloth of 50 to 57 degrees with no walk out, so a small
	-- guard there may stand on cloth gentler than MIN_CLOTH_DEGREES. The exception needs both the name and a box.
	local BEARD_POCKET_GUARD_PATTERN = "^SlideGuard_BeardPocket_%d+$"
	local BEARD_POCKET_BOXES: { Box } = {
		{ name = "beard pocket, left", min = Vector3.new(-9.8, 77.5, -14), max = Vector3.new(-3.8, 85.5, -8) },
		{ name = "beard pocket, right", min = Vector3.new(4.2, 73.3, -16), max = Vector3.new(12.2, 85.1, -8) },
	}

	-- The points of a grid over a face, `step` studs apart at most, in world space.
	local function pointsOver(guard: BasePart, face: Face, step: number): { Vector3 }
		local points: { Vector3 } = {}
		local uCount = math.max(1, math.ceil(2 * face.uHalf / step - 1e-9))
		local vCount = math.max(1, math.ceil(2 * face.vHalf / step - 1e-9))
		for i = 1, uCount do
			for j = 1, vCount do
				local u = ((i - 0.5) / uCount * 2 - 1) * face.uHalf
				local v = ((j - 0.5) / vCount * 2 - 1) * face.vHalf
				table.insert(points, guard.CFrame:PointToWorldSpace(face.center + face.u * u + face.v * v))
			end
		end
		return points
	end

	-- The face a player slides down: of the faces that face up, the biggest (a steep board's end faces are small). A
	-- guard with no face up uses the one that faces the most up.
	local function topFaceOf(guard: BasePart): Face
		local faces = facesOf(guard)
		local best: Face = faces[1]
		local anyUp = false
		local bestArea = -1
		local bestUp = -math.huge
		for _, face in faces do
			local up = guard.CFrame:VectorToWorldSpace(face.normal).Y
			if up > UP_FACE_MIN then
				local area = face.uHalf * face.vHalf
				if not anyUp or area > bestArea then
					best = face
					bestArea = area
				end
				anyUp = true
			elseif not anyUp and up > bestUp then
				best = face
				bestUp = up
			end
		end
		return best
	end

	local function insideAnyBox(point: Vector3, boxes: { Box }): boolean
		for _, box in boxes do
			if
				point.X >= box.min.X
				and point.X <= box.max.X
				and point.Y >= box.min.Y
				and point.Y <= box.max.Y
				and point.Z >= box.min.Z
				and point.Z <= box.max.Z
			then
				return true
			end
		end
		return false
	end

	-- True when all 8 corners of the part's bounding box are inside one single box of `boxes` (Ruling 16).
	local function insideOneBox(part: BasePart, boxes: { Box }): boolean
		local half = part.Size / 2
		for _, box in boxes do
			local allInside = true
			for _, signX in { -1, 1 } do
				for _, signY in { -1, 1 } do
					for _, signZ in { -1, 1 } do
						local corner = part.CFrame * Vector3.new(signX * half.X, signY * half.Y, signZ * half.Z)
						if not insideAnyBox(corner, { box }) then
							allInside = false
						end
					end
				end
			end
			if allInside then
				return true
			end
		end
		return false
	end

	-- The nearest the guard comes to a place players need. `surface` gives the points of the guard's surface (made once).
	local function distanceToNeed(guard: BasePart, surface: () -> { Vector3 }, need: Need): number
		if need.kind == "point" then
			return PlayerNeeds.distanceToBox(need.a, guard.CFrame, guard.Size)
		elseif need.kind == "segment" then
			local to = need.b :: Vector3
			local length = (to - need.a).Magnitude
			local best = math.huge
			local steps = math.max(1, math.ceil(length / SEGMENT_STEP))
			for i = 0, steps do
				local point = need.a:Lerp(to, i / steps)
				best = math.min(best, PlayerNeeds.distanceToBox(point, guard.CFrame, guard.Size))
			end
			return best
		end
		local part = need.part :: BasePart
		-- Far apart for sure: skip the point-by-point measure.
		local reach = guard.Size.Magnitude / 2 + part.Size.Magnitude / 2 + KEEP_AWAY
		if (guard.Position - part.Position).Magnitude > reach then
			return math.huge
		end
		local best = math.huge
		for _, point in surface() do
			best = math.min(best, PlayerNeeds.distanceToBox(point, part.CFrame, part.Size))
		end
		return best
	end

	-- Every problem with the guards in `folder`, one line for each guard and kind of problem. Kinds:
	--   Folder: the folder is missing or holds no guard.
	--   Steepness: a face that faces up is flatter than MIN_GUARD_DEGREES and is not buried in a solid.
	--   Cloth: at a corner or the middle of the sloped top face, the cloth behind the guard (found by a ray in, up to
	--     CLOTH_REACH studs) is gentler than MIN_CLOTH_DEGREES (or there is none within reach) and the point is not
	--     buried in a solid and is not the chair (body_and_cushion cloth only). Ruling 13's exception: a guard named
	--     SlideGuard_BeardPocket_<n> with all 8 corners inside one beard pocket box is not checked for Cloth at all.
	--   Distance: the guard comes within KEEP_AWAY studs of a place players need, the seam or the steep layer.
	local function guardProblems(folder: Instance?, context: Context): { string }
		local guards: { BasePart } = {}
		if folder ~= nil then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(guards, child)
				end
			end
		end
		if #guards == 0 then
			return { `Folder: World.WalkSurfaces.{GUARD_FOLDER} is missing or holds no guard` }
		end

		local problems: { string } = {}
		-- A small ball that is moved onto each point of a flat face: a point inside a solid is buried. It is made once and
		-- destroyed at the end, even when a check throws.
		local probe = Instance.new("Part")
		probe.Name = PROBE_NAME
		probe.Shape = Enum.PartType.Ball
		probe.Size = Vector3.one * PROBE_SIZE
		probe.Anchored = true
		probe.CanCollide = false
		probe.CanQuery = true
		probe.Archivable = false
		probe.Parent = context.world
		local inside = OverlapParams.new()
		inside.FilterType = Enum.RaycastFilterType.Include
		inside.FilterDescendantsInstances = context.solids
		inside.RespectCanCollide = false

		local ok, message = pcall(function(): string?
			for _, guard in guards do
				-- Steepness: one line for the first open face that faces up too flat.
				for _, face in facesOf(guard) do
					local normal = guard.CFrame:VectorToWorldSpace(face.normal)
					if normal.Y > UP_FACE_MIN and normal.Y > MAX_UP_NORMAL_Y + NORMAL_SLACK then
						local open: Vector3? = nil
						for _, point in pointsOver(guard, face, BURY_STEP) do
							probe.Position = point
							if #context.world:GetPartsInPart(probe, inside) == 0 then
								open = point
								break
							end
						end
						if open ~= nil then
							local degrees = math.deg(math.acos(math.clamp(normal.Y, -1, 1)))
							table.insert(
								problems,
								`Steepness: {guard.Name} has a face {string.format("%.0f", degrees)} degrees from flat that faces up, open at {describePoint(
									open
								)} (wanted at least {MIN_GUARD_DEGREES}, or buried)`
							)
							break
						end
					end
				end

				-- Cloth: the 4 corners and the middle of the sloped top face. From each, a ray goes in along the face's
				-- negative direction, up to CLOTH_REACH studs; its hit is the cloth point. None within reach means the
				-- guard hangs over open air.
				local top = topFaceOf(guard)
				local topNormal = guard.CFrame:VectorToWorldSpace(top.normal)
				local spots: { Vector3 } = { guard.CFrame:PointToWorldSpace(top.center) }
				for _, sideways in { -1, 1 } do
					for _, lengthways in { -1, 1 } do
						local corner = top.center + top.u * (sideways * top.uHalf) + top.v * (lengthways * top.vHalf)
						table.insert(spots, guard.CFrame:PointToWorldSpace(corner))
					end
				end
				local gentle = 0
				local example: string? = nil
				for _, spot in spots do
					-- A point buried in his solid shape or the pillow is skipped (decision 4 buries a guard's top end). The
					-- chair exception counts only for the chair's own cloth, never for another piece.
					probe.Position = spot
					local buried = #context.world:GetPartsInPart(probe, inside) > 0
					local chair = insideAnyBox(spot, context.chairBoxes)
						and context.clothNameAt(spot.X, spot.Z) == CHAIR_CLOTH
					if not buried and not chair then
						local hit = context.world:Raycast(spot, -topNormal * CLOTH_REACH, context.clothParams)
						local slope = if hit ~= nil then context.slopeAt(hit.Position, topNormal) else nil
						if slope == nil or slope < MIN_CLOTH_DEGREES then
							gentle += 1
							if example == nil then
								example = if hit == nil
									then `no cloth within {CLOTH_REACH} studs in from {describePoint(spot)}`
									elseif slope == nil then `the slope can't be read at {describePoint(
										hit.Position
									)}`
									else `{string.format("%.0f", slope)} degrees at {describePoint(hit.Position)}`
							end
						end
					end
				end
				-- Ruling 13 and Ruling 16: a beard pocket guard (by name) with all 8 corners in one pocket box skips this check.
				local pocketGuard = string.match(guard.Name, BEARD_POCKET_GUARD_PATTERN) ~= nil
					and insideOneBox(guard, context.beardPocketBoxes)
				if gentle > 0 and not pocketGuard then
					table.insert(
						problems,
						`Cloth: {guard.Name} stands on cloth under {MIN_CLOTH_DEGREES} degrees at {gentle} of {#spots} points, for example {example :: string}`
					)
				end

				-- Distance: the closest few places players need.
				local surface: { Vector3 }? = nil
				local function guardSurface(): { Vector3 }
					if surface == nil then
						local all: { Vector3 } = {}
						for _, face in facesOf(guard) do
							for _, point in pointsOver(guard, face, SURFACE_STEP) do
								table.insert(all, point)
							end
						end
						surface = all
					end
					return surface :: { Vector3 }
				end
				local near: { { name: string, distance: number } } = {}
				for _, need in context.needs do
					local distance = distanceToNeed(guard, guardSurface, need)
					if distance < KEEP_AWAY then
						table.insert(near, { name = need.name, distance = distance })
					end
				end
				if #near > 0 then
					table.sort(near, function(a, b)
						return a.distance < b.distance
					end)
					local shown: { string } = {}
					for index = 1, math.min(#near, EXAMPLES_SHOWN) do
						table.insert(shown, `{near[index].name} ({string.format("%.2f", near[index].distance)})`)
					end
					table.insert(
						problems,
						`Distance: {guard.Name} is within {KEEP_AWAY} studs of {#near} places, nearest {table.concat(
							shown,
							", "
						)}`
					)
				end
			end
			return nil
		end)
		probe:Destroy()
		if not ok then
			error(message, 0)
		end
		return problems
	end

	-- Stuck safety Task 23, test 5 (docs/plans/v2/stuck-safety.md, "slide guards lie close to what players see"). A guard
	-- is invisible, so the player sees the skin under it: a guard far out from the skin looks like a float, and a guard
	-- sunk deep into it hides its slide. On a 1-stud grid over each guard's top face, the guard stays within these
	-- distances of the drawn skin. The distance is measured straight out from the face, because a guard is steep: a gap
	-- measured straight down would read 3 to 4 times too big.
	local GRID_STEP = 1 -- studs between the points on a guard's top face
	local MAX_OUT = 1 -- studs a guard may stand out from the drawn skin around it
	local MAX_IN = 0.5 -- studs a guard may sink into the drawn skin
	local GAP_SLACK = 0.001 -- studs: rounding in the numbers written into the world
	local GAP_REACH = 2 -- studs: the skin is looked for this far out from a point and this far in
	local GAP_MARCH = 0.05 -- studs between the reads along that line
	local SKIN_WINDOW = 4 -- studs: the skin is read up to this far over a read point (a sunk steep face has skin well over it)

	-- How far the point is out from the drawn skin, measured along `normal` (the face's outward direction): positive when
	-- the skin lies behind the point, negative when the point is sunk into the skin. Nil when no skin crosses the line
	-- within GAP_REACH either way.
	local function gapToSkin(skin: DrawnSkin.Skin, point: Vector3, normal: Vector3): number?
		local function over(along: number): number?
			local at = point + normal * along
			local height = skin.heightAt(at.X, at.Z, at.Y + SKIN_WINDOW)
			return if height ~= nil then at.Y - height else nil
		end
		local startValue = over(0)
		if startValue == 0 then
			return 0
		end
		local lastAlong: { [number]: number } = { [-1] = 0, [1] = 0 }
		local lastValue: { [number]: number? } = { [-1] = startValue, [1] = startValue }
		for step = 1, math.floor(GAP_REACH / GAP_MARCH + 0.5) do
			for _, direction in { -1, 1 } do
				local along = direction * step * GAP_MARCH
				local value = over(along)
				local before = lastValue[direction]
				if value ~= nil then
					if before ~= nil and (before > 0) ~= (value > 0) then
						local fraction = before / (before - value)
						return -(lastAlong[direction] + (along - lastAlong[direction]) * fraction)
					end
					lastValue[direction] = value
					lastAlong[direction] = along
				end
			end
		end
		return nil
	end

	-- Every problem with how close the guards in `folder` lie to `skin`, one line for each guard and kind of problem:
	--   Folder: the folder is missing or holds no guard.
	--   Top: a guard has no face that faces up.
	--   Out: the guard stands out from the skin by more than MAX_OUT at some points.
	--   In: the guard sinks into the skin by more than MAX_IN at some points.
	--   Skin: no drawn skin within GAP_REACH of some points.
	local function guardCloseProblems(folder: Instance?, skin: DrawnSkin.Skin): { string }
		local guards: { BasePart } = {}
		if folder ~= nil then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(guards, child)
				end
			end
		end
		if #guards == 0 then
			return { `Folder: World.WalkSurfaces.{GUARD_FOLDER} is missing or holds no guard` }
		end

		local problems: { string } = {}
		for _, guard in guards do
			-- The top face: the biggest face that faces up.
			local top: Face? = nil
			local topNormal = Vector3.yAxis
			for _, face in facesOf(guard) do
				local normal = guard.CFrame:VectorToWorldSpace(face.normal)
				if normal.Y > UP_FACE_MIN and (top == nil or face.uHalf * face.vHalf > top.uHalf * top.vHalf) then
					top = face
					topNormal = normal
				end
			end
			if top == nil then
				table.insert(problems, `Top: {guard.Name} has no face that faces up`)
				continue
			end

			local points = pointsOver(guard, top, GRID_STEP)
			local tooFar, worstOut, outExample = 0, 0, nil :: Vector3?
			local tooDeep, worstIn, inExample = 0, 0, nil :: Vector3?
			local missing, missingExample = 0, nil :: Vector3?
			for _, point in points do
				local gap = gapToSkin(skin, point, topNormal)
				if gap == nil then
					missing += 1
					missingExample = missingExample or point
				elseif gap > MAX_OUT + GAP_SLACK then
					tooFar += 1
					if gap > worstOut then
						worstOut, outExample = gap, point
					end
				elseif gap < -MAX_IN - GAP_SLACK then
					tooDeep += 1
					if -gap > worstIn then
						worstIn, inExample = -gap, point
					end
				end
			end
			if tooFar > 0 then
				table.insert(
					problems,
					`Out: {guard.Name} stands up to {string.format("%.2f", worstOut)} studs out from the drawn skin at {tooFar} of {#points} points (wanted at most {MAX_OUT}), worst at {describePoint(
						outExample :: Vector3
					)}`
				)
			end
			if tooDeep > 0 then
				table.insert(
					problems,
					`In: {guard.Name} sinks up to {string.format("%.2f", worstIn)} studs into the drawn skin at {tooDeep} of {#points} points (wanted at most {MAX_IN}), worst at {describePoint(
						inExample :: Vector3
					)}`
				)
			end
			if missing > 0 then
				table.insert(
					problems,
					`Skin: {guard.Name} has no drawn skin within {GAP_REACH} studs at {missing} of {#points} points, for example at {describePoint(
						missingExample :: Vector3
					)}`
				)
			end
		end
		return problems
	end

	-- A solid wall: everything at z 0 or less, from y -30 to 30.
	local function addWall(world: WorldModel): Part
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Size = Vector3.new(60, 60, 60)
		wall.Position = Vector3.new(0, 0, -30)
		wall.Anchored = true
		wall.CanCollide = true
		wall.Parent = world
		return wall
	end

	-- A thin board `length` studs long and 4 wide. Its big faces slope `degrees` from flat, facing +z and up. Its top end
	-- centre is at `topEnd`; the board leans down and out toward +z from there.
	local function addBoard(folder: Folder, topEnd: Vector3, degrees: number, length: number): Part
		local fromVertical = math.rad(90 - degrees)
		local board = Instance.new("Part")
		board.Name = "SlideGuard_Fake_1"
		board.Size = Vector3.new(4, length, 0.5)
		board.CFrame = CFrame.new(topEnd) * CFrame.Angles(-fromVertical, 0, 0) * CFrame.new(0, -length / 2, 0)
		board.Anchored = true
		board.CanCollide = true
		board.Parent = folder
		return board
	end

	local function fakeFolder(world: WorldModel): Folder
		local folder = Instance.new("Folder")
		folder.Name = GUARD_FOLDER
		folder.Parent = world
		return folder
	end

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

	-- The real world's inputs. The cloth is his six pieces and the pillow. The chair is part of the body_and_cushion mesh
	-- and the legs_and_boots mesh, so it is named by boxes: the chair's two sides, from the start list's "chair's side"
	-- groups and the plan's chair-arm boxes (t22/start-list-task23.md; plan Task 23, "the 10 small spots").
	-- PLACEHOLDER: these boxes are a guess, to be replaced in step 23-8b by boxes measured from the drawn mesh (seat, sides
	-- and arms only).
	local CHAIR_BOXES: { Box } = {
		{ name = "chair, right side", min = Vector3.new(14, 5, -10), max = Vector3.new(38, 22, 42) },
		{ name = "chair, left side", min = Vector3.new(-38, 5, -10), max = Vector3.new(-14, 22, 42) },
	}
	local function clothParts(world: Instance): { Instance }
		local parts: { Instance } = {}
		local giant = world:FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		for _, name in BODY_PIECES do
			local piece = (giant :: Instance):FindFirstChild(name)
			expect(piece).never.toBeNil()
			local mesh = (piece :: Instance):FindFirstChild(name)
			expect(mesh).never.toBeNil()
			table.insert(parts, mesh :: Instance)
		end
		local things = world:FindFirstChild("GiantsThings")
		local pillow = if things then things:FindFirstChild("Pillow") else nil
		local body = if pillow then pillow:FindFirstChild("body") else nil
		local geometry = if body then body:FindFirstChild("body_geom") else nil
		expect(geometry).never.toBeNil()
		table.insert(parts, geometry :: Instance)
		return parts
	end

	-- Every place players need and the seam: the one list in PlayerNeeds, which the stuck scan's rare-spot check reads too.
	-- Both ladders' trusses must exist, so a missing ladder can't hide as a shorter list.
	local function realNeeds(world: Instance): { Need }
		local needs = PlayerNeeds.fromWorld(world)
		local names: { [string]: boolean } = {}
		for _, need in needs do
			names[need.name] = true
		end
		for _, ladderName in { "BeardLadder", "CapLadder" } do
			expect(names[`{ladderName} foot`]).toBe(true)
			expect(names[`{ladderName} top`]).toBe(true)
		end
		return needs
	end

	it("slide guards stay off the walk area and out of players' way", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local cloth = clothParts(world :: Instance)
		local clothOnly = RaycastParams.new()
		clothOnly.FilterType = Enum.RaycastFilterType.Include
		clothOnly.FilterDescendantsInstances = cloth
		clothOnly.RespectCanCollide = false
		local context: Context = {
			world = Workspace,
			clothParams = clothOnly,
			slopeAt = function(point: Vector3, normal: Vector3): number?
				return bodySizeSlopeAtCloth(clothOnly, point, normal)
			end,
			clothNameAt = function(x: number, z: number): string?
				local hit = Workspace:Raycast(
					Vector3.new(x, BODY_SLOPE_RAY_ABOVE, z),
					Vector3.new(0, -BODY_SLOPE_RAY_LENGTH, 0),
					clothOnly
				)
				return if hit then hit.Instance.Name else nil
			end,
			chairBoxes = CHAIR_BOXES,
			beardPocketBoxes = BEARD_POCKET_BOXES,
			solids = cloth,
			needs = realNeeds(world :: Instance),
		}
		local problems = guardProblems((walk :: Instance):FindFirstChild(GUARD_FOLDER), context)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, TEST_TIMEOUT_MS)

	it("slide guards lie close to what players see", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		-- What players see: his six pieces, the pillow, and any shirt folds (none until Task 26 adds them).
		local meshes: { MeshPart } = {}
		for _, mesh in clothParts(world :: Instance) do
			table.insert(meshes, mesh :: MeshPart)
		end
		local giant = (world :: Instance):FindFirstChild("Giant")
		local foldFolder = if giant then giant:FindFirstChild("ShirtFolds") else nil
		local folds: { BasePart } = {}
		if foldFolder ~= nil then
			for _, descendant in foldFolder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(folds, descendant)
				end
			end
		end
		local skin = DrawnSkin.fromWorld(meshes, folds)
		local problems = guardCloseProblems((walk :: Instance):FindFirstChild(GUARD_FOLDER), skin)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end, BUILD_TIMEOUT_MS + TEST_TIMEOUT_MS)

	-- Test 6 (Task 23): every place where a player hung in Climbing on foot has its fix. A hang place is fixed in one of
	-- two ways, as code_lead ruled after step 23-6 (decision 2 and its notch ruling):
	--   "patch": the hang root lies inside a part of World.WalkSurfaces.SmallPatches named <prefix><n> (a sealed fill);
	--   "guard": the root hangs in the air beside a face, so a ray down from above it would hit the ground. Instead, 8 flat
	--   rays (every 45 degrees) go out from the root up to HANG_FACE_REACH studs, ignoring the guards; the nearest hit on
	--   the part named `face` is the face point. A ray from the root to that face point must then hit a part of
	--   World.WalkSurfaces.SlideGuards before the face (code_lead's ruling after step 23-7, point 4).
	-- Later hang places (from the steep-spot batches in step 23-15) join the list by a ruling, one Edit each.
	local HANG_FACE_REACH = 3 -- studs: the flat rays look this far out from a hang root
	local HANG_FACE_DIRECTIONS = 8 -- how many flat directions they cover, evenly round
	local HANG_FACE_RAY_STRETCH = 1.05 -- the root-to-face ray looks 5% past the face point, so a face hit at the point still counts
	type HangPlace = { name: string, kind: "patch" | "guard", root: Vector3, prefix: string, face: string? }
	local NOTCH_PATCH_PREFIX = "Patch_Notch_"
	local FOREHEAD_PATCH_PREFIX = "Patch_Forehead_"
	-- Task 29: the forehead band's fill, chosen try T6 (6 boxes, `forehead|1|...` rows of work/t29/candidates.txt, one
	-- box per 0.25 stud slice in z). The old stuck spot (11.2, 98.2, 1) sits just outside the boxes, so the root is the
	-- middle of the fill's column nearest to it: x 11.0, z 0.5 (box 3, which spans x 6.625 to 11.125, y 96.36 to 102.93).
	-- The test shows that the slot under the plate is filled there.
	local FOREHEAD_FILL_ROOT = Vector3.new(11.0, 99.644, 0.5)
	-- Where the characters ended up hanging (steps 23-5 and 23-6, Play on the computer): the five notch walks W03, W04,
	-- W08, W09 and W14, and the pillow's spot 1 (35.2, 75.4, 65) after its slide down the +x/+z face. Spots 2 and 3 of
	-- the pillow never hung and get no fix.
	local HANG_PLACES: { HangPlace } = {
		{ name = "notch, walk 3", kind = "patch", root = Vector3.new(-5.3, 21.7, 39.1), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 4", kind = "patch", root = Vector3.new(2.3, 22.6, 39.8), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 8", kind = "patch", root = Vector3.new(-5.3, 21.6, 39.0), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 9", kind = "patch", root = Vector3.new(2.6, 22.6, 39.8), prefix = NOTCH_PATCH_PREFIX },
		{ name = "notch, walk 14", kind = "patch", root = Vector3.new(-1.1, 22.2, 39.7), prefix = NOTCH_PATCH_PREFIX },
		{
			name = "pillow spot 1",
			kind = "guard",
			root = Vector3.new(42.0, 45.8, 72.2),
			prefix = "",
			face = "body_geom", -- the pillow's mesh part (World.GiantsThings.Pillow.body.body_geom)
		},
		{ name = "forehead band", kind = "patch", root = FOREHEAD_FILL_ROOT, prefix = FOREHEAD_PATCH_PREFIX },
	}

	-- Whether a point is inside a block or a wedge (the sloped half only). Any other shape counts as not inside: a patch
	-- of another shape can't be proven to hold the point.
	local function pointInsidePart(part: BasePart, point: Vector3): boolean
		local isBlock = part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Block)
		if not isBlock then
			return false
		end
		local at = part.CFrame:PointToObjectSpace(point)
		local half = part.Size / 2
		if math.abs(at.X) > half.X or math.abs(at.Y) > half.Y or math.abs(at.Z) > half.Z then
			return false
		end
		if part:IsA("WedgePart") then
			-- The sloped face runs from the bottom front edge (-y, -z) up to the top back edge (+y, +z), facing up and
			-- toward -z (the same face as `facesOf` draws). The solid half is under it.
			local slopeNormal = Vector3.new(0, part.Size.Z, -part.Size.Y)
			return slopeNormal:Dot(at - Vector3.new(0, -half.Y, -half.Z)) <= 0
		end
		return true
	end

	-- One line per hang place that has no fix. `guards` and `patches` are the two folders (nil when missing); `world` is
	-- the world the ray looks in.
	local function hangPlaceProblems(
		places: { HangPlace },
		guards: Instance?,
		patches: Instance?,
		world: WorldRoot
	): { string }
		local problems: { string } = {}
		-- A ray sees what a player bumps into.
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = Collisions.GROUP
		for _, place in places do
			if place.kind == "patch" then
				local fixed = false
				if patches ~= nil then
					for _, child in patches:GetChildren() do
						if
							child:IsA("BasePart")
							and string.sub(child.Name, 1, #place.prefix) == place.prefix
							and pointInsidePart(child, place.root)
						then
							fixed = true
							break
						end
					end
				end
				if not fixed then
					table.insert(
						problems,
						`Patch: {place.name} at {describePoint(place.root)} is not inside a part named {place.prefix}<n> in {SMALL_PATCHES_FOLDER}`
					)
				end
			else
				-- Step 1: find the face. The flat rays ignore the guards, so the face point is found whether or not a guard
				-- already stands there.
				local faceParams = RaycastParams.new()
				faceParams.RespectCanCollide = true
				faceParams.CollisionGroup = Collisions.GROUP
				if guards ~= nil then
					faceParams.FilterType = Enum.RaycastFilterType.Exclude
					faceParams.FilterDescendantsInstances = { guards }
				end
				local facePoint: Vector3? = nil
				local faceDistance = math.huge
				for index = 0, HANG_FACE_DIRECTIONS - 1 do
					local angle = index * 2 * math.pi / HANG_FACE_DIRECTIONS
					local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) * HANG_FACE_REACH
					local faceHit = world:Raycast(place.root, direction, faceParams)
					if faceHit ~= nil and faceHit.Instance.Name == place.face then
						local distance = (faceHit.Position - place.root).Magnitude
						if distance < faceDistance then
							faceDistance = distance
							facePoint = faceHit.Position
						end
					end
				end
				if facePoint == nil then
					table.insert(
						problems,
						`Guard: {place.name} at {describePoint(place.root)}: no face of a part named {place.face} within {HANG_FACE_REACH} studs`
					)
				else
					-- Step 2: a guard must stand between the root and the face point.
					local toFace = (facePoint - place.root) * HANG_FACE_RAY_STRETCH
					local hit = world:Raycast(place.root, toFace, params)
					if hit == nil then
						table.insert(
							problems,
							`Guard: {place.name}: a ray from {describePoint(place.root)} to the face at {describePoint(
								facePoint
							)} hits nothing, so no slide guard is there`
						)
					elseif guards == nil or not hit.Instance:IsDescendantOf(guards) then
						table.insert(
							problems,
							`Guard: {place.name}: a ray from {describePoint(place.root)} to the face at {describePoint(
								facePoint
							)} first hits {hit.Instance:GetFullName()}, not a part of {GUARD_FOLDER}`
						)
					end
				end
			end
		end
		return problems
	end

	local function fakePatchFolder(world: WorldModel): Folder
		local folder = Instance.new("Folder")
		folder.Name = SMALL_PATCHES_FOLDER
		folder.Parent = world
		return folder
	end

	-- A block patch 4 studs on every side, centred at the origin.
	local function addPatch(folder: Folder, name: string, wedge: boolean): BasePart
		local patch: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		patch.Name = name
		patch.Size = Vector3.new(4, 4, 4)
		patch.CFrame = CFrame.new(0, 0, 0)
		patch.Anchored = true
		patch.CanCollide = true
		patch.Parent = folder
		return patch
	end

	local function patchPlace(root: Vector3): HangPlace
		return { name = "made-up notch", kind = "patch", root = root, prefix = NOTCH_PATCH_PREFIX }
	end

	it("the hang place check passes a root inside a block patch with the right name", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", false)
			expect(hangPlaceProblems({ patchPlace(Vector3.new(1.5, -1.5, 1.5)) }, nil, patches, world)).toEqual({})
		end)
	end)

	it("the hang place check names a root outside every patch", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", false)
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(5, 0, 0)) }, nil, patches, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check names a root in the empty half of a wedge patch", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", true)
			-- A wedge is solid under its slope, which rises from the bottom front edge (-y, -z) to the top back edge
			-- (+y, +z): the top front corner is empty air.
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(0, 1.5, -1.5)) }, nil, patches, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check passes a root in the solid half of a wedge patch", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Notch_1", true)
			expect(hangPlaceProblems({ patchPlace(Vector3.new(0, -1.5, 1.5)) }, nil, patches, world)).toEqual({})
		end)
	end)

	it("the hang place check names a root inside a patch with another name", function()
		inFakeWorld(function(world)
			local patches = fakePatchFolder(world)
			addPatch(patches, "Patch_Other_1", false)
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(0, 0, 0)) }, nil, patches, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	-- A made-up pillow: a block named body_geom, 4 studs on every side, its -x face at x 1. The hang root sits at the
	-- origin, 1 stud out from that face, in the air.
	local FAKE_FACE_NAME = "body_geom"
	local function addFakePillow(parent: Instance, centre: Vector3): Part
		local pillow = Instance.new("Part")
		pillow.Name = FAKE_FACE_NAME
		pillow.Size = Vector3.new(4, 4, 4)
		pillow.Position = centre
		pillow.Anchored = true
		pillow.CanCollide = true
		pillow.Parent = parent
		return pillow
	end

	-- A thin guard board lying across the path from the root to the face, at x 0.6.
	local function addFakeGuard(parent: Instance, name: string, x: number): Part
		local board = Instance.new("Part")
		board.Name = name
		board.Size = Vector3.new(0.2, 4, 4)
		board.Position = Vector3.new(x, 0, 0)
		board.Anchored = true
		board.CanCollide = true
		board.Parent = parent
		return board
	end

	local function guardPlace(): HangPlace
		return {
			name = "made-up pillow",
			kind = "guard",
			root = Vector3.new(0, 0, 0),
			prefix = "",
			face = FAKE_FACE_NAME,
		}
	end

	it("the hang place check passes a root with a slide guard in front of the face", function()
		inFakeWorld(function(world)
			local guards = fakeFolder(world)
			addFakePillow(world, Vector3.new(3, 0, 0))
			addFakeGuard(guards, "SlideGuard_Fake_1", 0.6)
			expect(hangPlaceProblems({ guardPlace() }, guards, nil, world)).toEqual({})
		end)
	end)

	it(
		"the hang place check names a root whose face has no guard in front, even with a guard under the root",
		function()
			inFakeWorld(function(world)
				local guards = fakeFolder(world)
				addFakePillow(world, Vector3.new(3, 0, 0))
				-- A guard right under the root, where the old ray down would have found it, but not between root and face.
				addFakeGuard(guards, "SlideGuard_Fake_1", 0).Position = Vector3.new(0, -1, 0)
				local problems = hangPlaceProblems({ guardPlace() }, guards, nil, world)
				expect(#startsWith(problems, "Guard:")).toBe(1)
				expect(#problems).toBe(1)
			end)
		end
	)

	it("the hang place check names a root with no pillow face within reach", function()
		inFakeWorld(function(world)
			local guards = fakeFolder(world)
			addFakePillow(world, Vector3.new(30, 0, 0))
			addFakeGuard(guards, "SlideGuard_Fake_1", 0.6)
			local problems = hangPlaceProblems({ guardPlace() }, guards, nil, world)
			expect(#startsWith(problems, "Guard:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check names a guard buried behind the face", function()
		inFakeWorld(function(world)
			local guards = fakeFolder(world)
			addFakePillow(world, Vector3.new(3, 0, 0))
			addFakeGuard(guards, "SlideGuard_Fake_1", 2)
			local problems = hangPlaceProblems({ guardPlace() }, guards, nil, world)
			expect(#startsWith(problems, "Guard:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the hang place check names every place when both fix folders are missing", function()
		inFakeWorld(function(world)
			addFakePillow(world, Vector3.new(3, 0, 0))
			local problems = hangPlaceProblems({ patchPlace(Vector3.new(0, 0, 0)), guardPlace() }, nil, nil, world)
			expect(#startsWith(problems, "Patch:")).toBe(1)
			expect(#startsWith(problems, "Guard:")).toBe(1)
			expect(#problems).toBe(2)
		end)
	end)

	it("every known Climbing hang place has its fix", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local problems = hangPlaceProblems(
			HANG_PLACES,
			(walk :: Instance):FindFirstChild(GUARD_FOLDER),
			(walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER),
			Workspace
		)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)
end)

-- Stuck safety Task 23 (code_lead's ruling after step 23-8b.1, Ruling 11): a meadow prop (the Sock) can have a small
-- ramp that replaces a step between the prop and the grass, `Ramp_<Place>_<n>` in World.WalkSurfaces.SmallPatches. It
-- is not a patch on his skin (Rule 20 is about him), so Task 22's patch test leaves it alone and this test checks it.
describe("the real world, ramps on meadow props", function()
	local Workspace = game:GetService("Workspace")

	local RAMP_PLACES = { "Sock" } -- places that must have a ramp
	local RAMP_PATTERN = "^Ramp_(%w+)_%d+$" -- Ramp_<Place>_<n>
	local PATCH_PATTERN = "^Patch_%w+_%d+$" -- Patch_<Place>_<n>
	local MAX_RAMP_DEGREES = 45 -- the crossing ramps' limit: a player walks up it without a jump
	local MAX_EDGE_GAP = 0.2 -- studs: the gap to the prop's surface, and to the ground where the ramp meets it
	local STEP_HEIGHT = 1.4 -- studs: the most the ramp's top may stand over the ground (the step it replaces)
	local STEP_SLACK = 0.05 -- studs: rounding in the numbers written into the world
	local SAMPLE_SPACING = 0.25 -- studs: the grid of rays down over the ramp's top
	local EDGE_INSET = 0.05 -- studs: the grid starts this far inside the ramp's box
	local TOP_EDGE_BAND = 0.05 -- studs: a sample within this of the highest one is on the top edge
	local RAY_START_ABOVE = 1.5 -- studs: a ray to the prop or the ground starts this far over the ramp's top
	local RAY_LENGTH = 8 -- studs
	local FLAT_DEGREES_SLACK = 0.01

	type Sample = { position: Vector3, normal: Vector3 }

	local function boxCorners(part: BasePart): { Vector3 }
		local corners: { Vector3 } = {}
		for _, signX in { -1, 1 } do
			for _, signY in { -1, 1 } do
				for _, signZ in { -1, 1 } do
					table.insert(
						corners,
						part.CFrame:PointToWorldSpace(
							Vector3.new(signX * part.Size.X / 2, signY * part.Size.Y / 2, signZ * part.Size.Z / 2)
						)
					)
				end
			end
		end
		return corners
	end

	-- Where rays down hit the ramp's top: a grid over the ramp's box, SAMPLE_SPACING apart.
	local function topSamples(world: WorldRoot, ramp: BasePart): { Sample }
		local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, corner in boxCorners(ramp) do
			low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
			high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { ramp }
		params.RespectCanCollide = false
		local samples: { Sample } = {}
		local x = low.X + EDGE_INSET
		while x <= high.X - EDGE_INSET do
			local z = low.Z + EDGE_INSET
			while z <= high.Z - EDGE_INSET do
				local hit =
					world:Raycast(Vector3.new(x, high.Y + 1, z), Vector3.new(0, -(high.Y - low.Y + 2), 0), params)
				if hit ~= nil then
					table.insert(samples, { position = hit.Position, normal = hit.Normal })
				end
				z += SAMPLE_SPACING
			end
			x += SAMPLE_SPACING
		end
		return samples
	end

	-- The height of the first surface under (x, z) that a ray from `fromY` meets, with the filter given; nil when none.
	local function surfaceHeight(
		world: WorldRoot,
		filterType: Enum.RaycastFilterType,
		filter: { Instance },
		x: number,
		z: number,
		fromY: number
	): number?
		local params = RaycastParams.new()
		params.FilterType = filterType
		params.FilterDescendantsInstances = filter
		params.RespectCanCollide = false
		local hit = world:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -RAY_LENGTH, 0), params)
		return if hit ~= nil then hit.Position.Y else nil
	end

	-- The checker. Returns its problems as sentences, each starting with the name of its rule; none means the ramps
	-- pass. `props` maps a place name ("Sock") to the prop it belongs to; `places` are the places that must have a ramp.
	local function rampProblems(
		world: WorldRoot,
		folder: Instance?,
		props: { [string]: Instance },
		places: { string }
	): { string }
		local problems: { string } = {}
		local ramps: { BasePart } = {}
		if folder ~= nil then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") and string.match(descendant.Name, RAMP_PATTERN) ~= nil then
					table.insert(ramps, descendant)
				end
			end
		end
		-- (a) Place: every named place has its ramp
		for _, place in places do
			local found = false
			for _, ramp in ramps do
				if string.match(ramp.Name, RAMP_PATTERN) == place then
					found = true
				end
			end
			if not found then
				table.insert(
					problems,
					`Place: {place} has no ramp (Ramp_{place}_<n> in World.WalkSurfaces.{SMALL_PATCHES_FOLDER})`
				)
			end
		end
		for _, ramp in ramps do
			local place = string.match(ramp.Name, RAMP_PATTERN) :: string
			local prop: Instance? = props[place]
			if prop == nil then
				table.insert(problems, `Prop: {ramp.Name} names the place {place}, which has no prop`)
				continue
			end
			local samples = topSamples(world, ramp)
			if #samples == 0 then
				table.insert(problems, `Top: no ray down finds the top of {ramp.Name}`)
				continue
			end
			-- (b) Slope: the top is walkable
			local steepest = 0
			local highest = -math.huge
			for _, sample in samples do
				steepest = math.max(steepest, math.deg(math.acos(math.clamp(sample.normal.Y, -1, 1))))
				highest = math.max(highest, sample.position.Y)
			end
			if steepest > MAX_RAMP_DEGREES + FLAT_DEGREES_SLACK then
				table.insert(
					problems,
					`Slope: {ramp.Name} slopes up to {string.format("%.1f", steepest)} degrees (wanted at most {MAX_RAMP_DEGREES})`
				)
			end
			-- (c) Prop: along the top edge the ramp meets the prop's surface
			local edgePoints, edgeMissing, edgeBad = 0, 0, 0
			local lowestGap, highestGap = math.huge, -math.huge
			local propFilter = { prop }
			for _, sample in samples do
				if sample.position.Y >= highest - TOP_EDGE_BAND then
					edgePoints += 1
					local propY = surfaceHeight(
						world,
						Enum.RaycastFilterType.Include,
						propFilter,
						sample.position.X,
						sample.position.Z,
						sample.position.Y + RAY_START_ABOVE
					)
					if propY == nil then
						edgeMissing += 1
					else
						local gap = sample.position.Y - propY
						lowestGap, highestGap = math.min(lowestGap, gap), math.max(highestGap, gap)
						if math.abs(gap) > MAX_EDGE_GAP then
							edgeBad += 1
						end
					end
				end
			end
			if edgeMissing > 0 or edgeBad > 0 then
				table.insert(
					problems,
					`Prop: the top edge of {ramp.Name} is off the surface of {prop.Name} at {edgeMissing + edgeBad} of {edgePoints} points ({edgeMissing} with no surface under it; gaps {string.format(
						"%.2f",
						lowestGap
					)} to {string.format("%.2f", highestGap)}, wanted -{MAX_EDGE_GAP} to {MAX_EDGE_GAP})`
				)
			end
			-- (d) Height, Ground, Buried: against the meadow ground (what is under the ramp, with the prop and ramps left out)
			local groundFilter: { Instance } = { ramp, prop }
			if folder ~= nil then
				groundFilter = { folder, prop }
			end
			local bottom = math.huge
			for _, corner in boxCorners(ramp) do
				bottom = math.min(bottom, corner.Y)
			end
			local tallest = -math.huge
			local closest = math.huge
			local floating = 0
			local unreadable = 0
			for _, sample in samples do
				local groundY = surfaceHeight(
					world,
					Enum.RaycastFilterType.Exclude,
					groundFilter,
					sample.position.X,
					sample.position.Z,
					sample.position.Y + RAY_START_ABOVE
				)
				if groundY == nil then
					unreadable += 1
				else
					tallest = math.max(tallest, sample.position.Y - groundY)
					closest = math.min(closest, math.abs(sample.position.Y - groundY))
					if bottom > groundY + STEP_SLACK then
						floating += 1
					end
				end
			end
			if unreadable > 0 then
				table.insert(
					problems,
					`Ground: no meadow ground under {ramp.Name} at {unreadable} of {#samples} points`
				)
			end
			if tallest > STEP_HEIGHT + STEP_SLACK then
				table.insert(
					problems,
					`Height: the top of {ramp.Name} stands up to {string.format("%.2f", tallest)} studs over the ground (wanted at most {STEP_HEIGHT})`
				)
			end
			if closest > MAX_EDGE_GAP then
				table.insert(
					problems,
					`Ground: the top of {ramp.Name} never comes within {MAX_EDGE_GAP} studs of the ground (closest {string.format(
						"%.2f",
						closest
					)})`
				)
			end
			if floating > 0 then
				table.insert(
					problems,
					`Buried: the bottom of {ramp.Name} is above the ground at {floating} of {#samples} points`
				)
			end
		end
		return problems
	end

	-- Every part of the small patches folder is named Patch_<Place>_<n> or Ramp_<Place>_<n>, so each one is read by
	-- either Task 22's patch test or the ramp test.
	local function nameProblems(folder: Instance?): { string }
		local problems: { string } = {}
		if folder ~= nil then
			for _, descendant in folder:GetDescendants() do
				if
					descendant:IsA("BasePart")
					and string.match(descendant.Name, PATCH_PATTERN) == nil
					and string.match(descendant.Name, RAMP_PATTERN) == nil
				then
					table.insert(
						problems,
						`Name: {descendant.Name} is neither Patch_<Place>_<n> nor Ramp_<Place>_<n>, so no test reads it`
					)
				end
			end
		end
		return problems
	end

	-- A made-up meadow: ground with its top at height 0; a prop, a block whose top is at `propTop` and whose front face is
	-- at z -1.9, and the ramp: a wedge `rampTop` high at z -2 (its thick end, against the prop's front) sloping down
	-- `degrees` toward +z, 4 wide, bottom `lift` over height -1. The folder holds the ramp.
	local RAMP_TOP = 1.2
	local function makeMeadow(
		world: WorldModel,
		propTop: number,
		rampTop: number,
		degrees: number,
		lift: number
	): (Folder, { [string]: Instance })
		local ground = Instance.new("Part")
		ground.Name = "Ground"
		ground.Size = Vector3.new(40, 10, 40)
		ground.Position = Vector3.new(0, -5, 0)
		ground.Anchored = true
		ground.Parent = world
		local prop = Instance.new("Part")
		prop.Name = "Prop"
		prop.Size = Vector3.new(10, propTop + 3, 6.1)
		prop.Position = Vector3.new(0, propTop - (propTop + 3) / 2, -1.9 - 3.05)
		prop.Anchored = true
		prop.Parent = world
		local folder = Instance.new("Folder")
		folder.Name = SMALL_PATCHES_FOLDER
		folder.Parent = world
		local height = rampTop + 1 -- from height -1 to the top
		local length = height / math.tan(math.rad(degrees))
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp_Sock_1"
		ramp.Size = Vector3.new(4, height, length)
		-- the thick end faces -z (toward the prop): the wedge's local +Z side is its full-height side
		ramp.CFrame = CFrame.fromMatrix(
			Vector3.new(0, -1 + lift + height / 2, -2 + length / 2),
			-Vector3.xAxis, -- up (y) crossed with back (-z)
			Vector3.yAxis,
			-Vector3.zAxis
		)
		ramp.Anchored = true
		ramp.Parent = folder
		return folder, { Sock = prop }
	end

	it("the ramp check passes a 40 degree ramp that meets the prop and the ground", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP, RAMP_TOP, 40, 0)
			expect(rampProblems(world, folder, props, RAMP_PLACES)).toEqual({})
		end)
	end)

	it("the ramp check names a ramp steeper than 45 degrees", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP, RAMP_TOP, 50, 0)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Slope:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the ramp check names a ramp that stands 0.5 studs off the prop's surface", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP + 0.5, RAMP_TOP, 40, 0)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Prop:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the ramp check names a ramp that floats over the ground", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP + 2, RAMP_TOP, 40, 2)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Ground:")).toBe(1)
			expect(#startsWith(problems, "Buried:")).toBe(1)
		end)
	end)

	it("the ramp check names a ramp whose top is higher than the step it replaces", function()
		inFakeWorld(function(world)
			-- The prop's top and the ramp's top are both 1.7 over the ground: they meet, but the step was 1.4.
			local folder, props = makeMeadow(world, 1.7, 1.7, 40, 0)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Height:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the ramp check names a place with no ramp", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP, RAMP_TOP, 40, 0)
			local problems = rampProblems(world, folder, props, { "Sock", "Boot" })
			expect(#problems).toBe(1)
			expect((string.find(problems[1], "Place: Boot", 1, true))).never.toBeNil()
		end)
	end)

	it("the ramp check names a ramp whose place has no prop", function()
		inFakeWorld(function(world)
			local folder = makeMeadow(world, RAMP_TOP, RAMP_TOP, 40, 0)
			local problems = rampProblems(world, folder, {}, {})
			expect(#startsWith(problems, "Prop:")).toBe(1)
		end)
	end)

	it("the name check passes Patch_ and Ramp_ names", function()
		inFakeWorld(function(world)
			local folder = Instance.new("Folder")
			folder.Parent = world
			for _, name in { "Patch_Notch_1", "Patch_ChairFoot_12", "Ramp_Sock_1" } do
				local part = Instance.new("Part")
				part.Name = name
				part.Parent = folder
			end
			expect(nameProblems(folder)).toEqual({})
		end)
	end)

	it("the name check names a part called Block_1", function()
		inFakeWorld(function(world)
			local folder = Instance.new("Folder")
			folder.Parent = world
			for _, name in { "Patch_Notch_1", "Block_1", "Patch_Notch", "Ramp_1" } do
				local part = Instance.new("Part")
				part.Name = name
				part.Parent = folder
			end
			local problems = nameProblems(folder)
			expect(#problems).toBe(3)
			expect((string.find(problems[1], "Block_1", 1, true))).never.toBeNil()
		end)
	end)

	it("ramps on meadow props are walkable and flush", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local things = (world :: Instance):FindFirstChild("GiantsThings")
		expect(things).never.toBeNil()
		local props: { [string]: Instance } = {}
		for _, place in RAMP_PLACES do
			local prop = (things :: Instance):FindFirstChild(place)
			expect(prop).never.toBeNil()
			props[place] = prop :: Instance
		end
		local problems =
			rampProblems(Workspace, (walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER), props, RAMP_PLACES)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("every part in the small patches folder is named as a patch or a ramp", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local problems = nameProblems((walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER))
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)
end)
