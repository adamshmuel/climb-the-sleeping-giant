--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Layout)
local SpotModels = require(ServerScriptService.Server.Eggs.SpotModels)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local CameraFx = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Fx.CameraFx)
local GiantFx = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Fx.GiantFx)

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

		-- the middle of the belly path
		local bellyPieces = {}
		for _, piece in walk:GetChildren() do
			if piece.Name == "Belly_Walk" then
				table.insert(bellyPieces, piece)
			end
		end
		table.sort(bellyPieces, function(a, b)
			return (a :: BasePart).Position.Y < (b :: BasePart).Position.Y
		end)
		local bellyMiddle = bellyPieces[math.ceil(#bellyPieces / 2)] :: BasePart
		expect(locate(bellyMiddle.Position + up).zone).toBe("Belly")

		-- the beard ladder's middle, and the top of the nose pad
		local ladderCenter = walk.BeardLadder:GetBoundingBox().Position
		expect(locate(ladderCenter).zone).toBe("Beard")
		local nose = walk.Nose_Walk :: BasePart
		expect(locate(nose.Position + Vector3.new(0, nose.Size.Y / 2, 0) + up).zone).toBe("Beard")

		-- the middle of the nightcap path
		local capPieces = {}
		for _, piece in walk:GetChildren() do
			if piece.Name == "Nightcap_Walk" then
				table.insert(capPieces, piece)
			end
		end
		expect(locate((capPieces[math.ceil(#capPieces / 2)] :: BasePart).Position + up).zone).toBe("Nightcap")

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
		expect(world.GiantFX.MumbleAnchor.Mumble.Enabled).toBe(false)
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
			if piece:IsA("BasePart") and string.match(piece.Name, "_Walk$") then
				table.insert(surfaces, piece)
			end
		end
		expect(#surfaces > 30).toBe(true)
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

	it("the forehead slabs beside the cap ladder are steeper than 75 degrees", function()
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local slabs = (guard :: Instance):GetChildren()
		expect(#slabs >= 5).toBe(true)
		local wrong = {}
		local beside = 0
		for _, slab in slabs do
			local part = slab :: BasePart
			-- the middle slab stays under the cap ladder, so players can climb beside the ladder to the cap path
			if part:IsA("BasePart") and math.abs(part.Position.X) > 7 then
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

	-- The two invisible side rails stand on both sides of the nose pad, so nobody can step off the pad onto the
	-- ledge and into the slot between the forehead walls and his cheeks. They are built by tools/world/03b-forehead.luau.
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

	local function isInsidePart(part: BasePart, point: Vector3): boolean
		local localPoint = part.CFrame:PointToObjectSpace(point)
		local half = part.Size / 2
		return math.abs(localPoint.X) <= half.X
			and math.abs(localPoint.Y) <= half.Y
			and math.abs(localPoint.Z) <= half.Z
	end

	it("two smooth side rails stand on both sides of the nose pad", function()
		local rails = sideRails()
		expect(#rails).toBe(2)
		local pad = (realWorld() :: any).WalkSurfaces.Nose_Walk :: BasePart
		local padTop = pad.Position.Y + pad.Size.Y / 2
		for index, rail in rails do
			local side = if index == 1 then -1 else 1
			expect(rail.Position.X * side > pad.Size.X / 2).toBe(true) -- outside the pad
			expect(rail.Position.X * side < pad.Size.X / 2 + 2).toBe(true) -- right beside it
			expect(rail.Transparency).toBe(1)
			expect(rail.CanCollide).toBe(true)
			expect(rail.Anchored).toBe(true)
			expect(slopeOf(rail) > 75).toBe(true)
			-- the rail covers the whole pad, front to back, and rises from the pad to the cap path
			for _, z in { pad.Position.Z - pad.Size.Z / 2 + 0.5, pad.Position.Z, pad.Position.Z + pad.Size.Z / 2 } do
				for _, y in { padTop + 0.5, padTop + 8, padTop + 19 } do
					expect({ z = z, y = y, covered = isInsidePart(rail, Vector3.new(rail.Position.X, y, z)) }).toEqual({
						z = z,
						y = y,
						covered = true,
					})
				end
			end
		end
	end)

	it("the side rails run along both edges of the middle forehead slab", function()
		local rails = sideRails()
		expect(#rails).toBe(2)
		local guard = (realWorld() :: any).WalkSurfaces.ForeheadGuard :: Instance
		local middle = {}
		for _, child in guard:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Guard" and math.abs(child.Position.X) <= 7 then
				table.insert(middle, child)
			end
		end
		expect(#middle).toBe(1)
		local slab = middle[1] :: BasePart
		-- the slab's two long edges, sampled from its foot to its top: each point must stand inside a rail, so
		-- a player on the slab can only walk up it or back down, never off its side
		local uncovered = {}
		for fraction = 0, 1, 0.1 do
			for _, side in { -1, 1 } do
				local edge = slab.CFrame:PointToWorldSpace(
					Vector3.new(side * (slab.Size.X / 2 - 0.2), slab.Size.Y / 2, (fraction - 0.5) * slab.Size.Z)
				)
				if not isInsidePart(rails[if edge.X < 0 then 1 else 2], edge) then
					table.insert(uncovered, string.format("(%.1f, %.1f, %.1f)", edge.X, edge.Y, edge.Z))
				end
			end
		end
		expect(uncovered).toEqual({})
	end)

	it("no wall sticks out in front of the edges of the middle forehead slab", function()
		-- Where a side wall started inside the middle slab's width, it stood in front of the slab's surface and made
		-- a step that a player walking up the slab could wedge against. The walls must start where the slab ends.
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local middleHalfWidth = 0
		for _, child in (guard :: Instance):GetChildren() do
			if child:IsA("BasePart") and child.Name == "Guard" and math.abs(child.Position.X) <= 7 then
				middleHalfWidth = child.Size.X / 2
			end
		end
		expect(middleHalfWidth > 0).toBe(true)
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

	it("a player on the nose pad cannot walk off its sides", function()
		-- Rays go sideways from just beside the cap ladder, over the open part of the pad (in front of the forehead) and above it. A see-through part (the
		-- ladder's rails, the invisible eyes) is not a wall, so the ray looks past it.
		local pad = (realWorld() :: any).WalkSurfaces.Nose_Walk :: BasePart
		local padTop = pad.Position.Y + pad.Size.Y / 2
		local open = {}
		for _, direction in { -1, 1 } do
			for z = pad.Position.Z - pad.Size.Z / 2 + 1, pad.Position.Z + 1, 2 do
				for y = padTop + 1, padTop + 11, 2 do
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
					if wallAt == nil or math.abs(wallAt) > pad.Size.X / 2 + 2 then
						table.insert(open, string.format("side %d at (z %.0f, y %.0f)", direction, z, y))
					end
				end
			end
		end
		expect(open).toEqual({})
	end)

	it("the slope limit is 70", function()
		-- set in default.project.json: Roblox's own limit is 89, which lets players walk up almost anything
		expect(game:GetService("StarterPlayer").CharacterMaxSlopeAngle).toBe(70)
	end)

	it("phone auto-jump is off", function()
		-- set in default.project.json: an automatic hop on the giant thuds and can wake him
		expect(game:GetService("StarterPlayer").AutoJumpEnabled).toBe(false)
	end)

	-- The highest point of any part of a ladder (its rails, rungs and the climbable truss).
	local function ladderTop(ladder: Instance): (number, Vector3)
		local highest, where = -math.huge, Vector3.zero
		for _, part in ladder:GetDescendants() do
			if part:IsA("BasePart") then
				local half = part.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner =
								part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							if corner.Y > highest then
								highest, where = corner.Y, corner
							end
						end
					end
				end
			end
		end
		return highest, where
	end

	it("the beard ladder's top is level with the nose pad", function()
		local walk = (realWorld() :: any).WalkSurfaces
		local top = ladderTop(walk.BeardLadder)
		local pad = walk.Nose_Walk :: BasePart
		local padTop = pad.Position.Y + pad.Size.Y / 2
		expect(math.abs(top - padTop) <= 0.3).toBe(true)
	end)

	it("the cap ladder's top meets the cap path", function()
		local walk = (realWorld() :: any).WalkSurfaces
		local top, where = ladderTop(walk.CapLadder)
		-- the cap path piece the top of the ladder reaches (the ladder ends over its length)
		local meets: BasePart? = nil
		for _, piece in walk:GetChildren() do
			if piece.Name == "Nightcap_Walk" and piece:IsA("BasePart") then
				local halfLength = piece.Size.Z / 2
				if math.abs(piece.Position.Z - where.Z) <= halfLength + 1 then
					meets = piece
				end
			end
		end
		expect(meets).never.toBeNil()
		local pathTop = (meets :: BasePart).Position.Y + (meets :: BasePart).Size.Y / 2
		-- a climber steps off the top of the ladder onto the path: the ladder may end a little above it, never below it
		expect(top >= pathTop - 0.3 and top <= pathTop + 2).toBe(true)
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
			EggSpot_Uncommon_2 = { -21.5, -55.5 },
			EggSpot_Uncommon_3 = { 26, -61.5 },
			EggSpot_Uncommon_4 = { 21.5, -55 },
			EggSpot_Rare_1 = { -12.5, -40.3 },
			EggSpot_Rare_2 = { -11.2, -34.8 },
			EggSpot_Rare_3 = { -8.1, -30.7 },
			EggSpot_Rare_4 = { 2.5, -29.5 },
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
			local expectedKind = if spot.rarity == "Common" then "grass" else "walk surface"
			expect({ spot = spot.name, kind = kind, reachable = distance <= 8 }).toEqual({
				spot = spot.name,
				kind = expectedKind,
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
	local SAMPLE_STEP = 2 -- studs between the places checked along a link
	local RAY_START_ABOVE = 3 -- the ground ray starts this far above the line...
	local RAY_LENGTH = 4 -- ...and reaches this far down
	local MAX_OFF_LINE = 1 -- studs: how far the ground may be from the line (a line above the ground is corner-cutting)
	local BODY_BOX = Vector3.new(2, 4, 2) -- a player's body
	local BODY_LIFT = 0.5 -- studs: the box is held this far above the ground
	local GIANT_SWEEP_HEIGHTS = { 1, 2.5, 4 } -- studs above the ground: the giant is checked with rays at these heights
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
			local maxSlope = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
			-- Left out of the box check, because its bounding box is far bigger than the thing's shape:
			--   * the giant: a few huge meshes whose boxes cover the belly path and the ramps, so the box can't tell his skin
			--     from a wall;
			--   * the teacup: its box is turned and covers the end of bridge 6, 25 studs from the cup itself.
			-- Both get rays along the way at body height instead (below).
			-- Also left out: the two ramp planks. A player steps on or off a ramp foot over its edge, which the box
			-- touches by design (the edge stands 1 to 2 studs above the grass beside it).
			local giant = (world :: any).Giant :: Instance
			local teacup = (world :: any).GiantsThings.Teacup :: Instance
			local rampPlanks: { Instance } = {
				(world :: any).WalkSurfaces.BootRamp.Ramp_Walk,
				(world :: any).WalkSurfaces.RightBootRamp.Ramp_Walk,
			}
			local boxIgnores: { Instance } = { giant, teacup, rampPlanks[1], rampPlanks[2] }
			local giantRays = RaycastParams.new()
			giantRays.RespectCanCollide = true
			giantRays.FilterType = Enum.RaycastFilterType.Include
			giantRays.FilterDescendantsInstances = { giant, teacup }
			local boxParams = OverlapParams.new()
			boxParams.RespectCanCollide = true
			boxParams.FilterType = Enum.RaycastFilterType.Exclude
			boxParams.FilterDescendantsInstances = boxIgnores

			-- Returns what is wrong with walking from `from` to `to`, or nil.
			local function walkProblem(from: Vector3, to: Vector3): string?
				local length = (to - from).Magnitude
				local steps = math.max(1, math.ceil(length / SAMPLE_STEP))
				local direction = (to - from).Unit
				local previous: { position: Vector3, normal: Vector3 }? = nil
				for step = 0, steps do
					local onLine = from:Lerp(to, step / steps)
					local where = describeVector(onLine)
					local hit = Workspace:Raycast(
						onLine + Vector3.new(0, RAY_START_ABOVE, 0),
						Vector3.new(0, -RAY_LENGTH, 0),
						groundRay()
					)
					if hit == nil then
						return `no ground at {where}`
					end
					if hit.Material == Enum.Material.Water then
						return `water at {where}`
					end
					if hit.Normal.Y < maxSlope then
						return `too steep at {where} ({hit.Instance.Name})`
					end
					if math.abs(hit.Position.Y - onLine.Y) > MAX_OFF_LINE then
						return `the ground is {hit.Position.Y - onLine.Y} studs off the line at {where} ({hit.Instance.Name})`
					end
					-- the body box, held 0.5 studs above the ground and tilted with it
					local normal = hit.Normal
					local along = direction - normal * direction:Dot(normal)
					if along.Magnitude < 1e-3 then
						along = Vector3.xAxis
					end
					local across = along.Unit:Cross(normal)
					local boxCFrame =
						CFrame.fromMatrix(hit.Position + normal * (BODY_LIFT + BODY_BOX.Y / 2), across, normal)
					local touching = Workspace:GetPartBoundsInBox(boxCFrame, BODY_BOX, boxParams)
					if #touching > 0 then
						return `{touching[1]:GetFullName()} is in the way at {where}`
					end
					-- the giant and the teacup, with rays at body height between this place and the last one
					if previous then
						for _, height in GIANT_SWEEP_HEIGHTS do
							local start = previous.position + previous.normal * height
							local finish = hit.Position + normal * height
							if Workspace:Raycast(start, finish - start, giantRays) then
								return `the giant or the teacup is in the way at {where}, {height} studs up`
							end
						end
					end
					previous = { position = hit.Position, normal = normal }
				end
				return nil
			end

			local byName: { [string]: WorldIndex.RoutePoint } = {}
			local points = loadRoute()
			for _, point in points do
				byName[point.name] = point
			end
			local checked = 0
			for _, point in points do
				for _, neighbourName in point.neighbours do
					if point.name < neighbourName then -- each link once
						checked += 1
						local label = `{point.name} to {neighbourName}`
						expect({ label = label, problem = walkProblem(point.position, byName[neighbourName].position) }).toEqual({
							label = label,
							problem = nil,
						})
					end
				end
			end
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
