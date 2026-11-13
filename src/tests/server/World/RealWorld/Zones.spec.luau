--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local CameraFx = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Fx.CameraFx)
local Helpers = require(script.Parent.Helpers)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local BODY_PIECES = Helpers.BODY_PIECES
local locator = Helpers.locator
local realWorld = Helpers.realWorld

-- More read-only checks of the real world. The zone boxes are built by tools/world/02-zones.luau, and the
-- garden extras, prop moves, Z Z Z and sky by tools/world/02b-garden-extras.luau.
describe("the real world, zones and extras", function()
	it("the real world passes the zone check", function()
		local boxes, problems = WorldIndex.readZones(realWorld())
		expect(problems).toEqual({})
		expect(boxes).never.toBeNil()
	end)

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

	it("nothing solid blocks the view from any spawn spot to his face", function()
		local world = realWorld()
		local giant = (world :: any).Giant :: Model
		local emitter = (world :: any).GiantFX.SnoreEmitter :: BasePart

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

			-- what we must see: both eyelids, the nose and the bottom of his beard
			local targets: { [string]: Vector3 } = {
				LeftLid = (giant :: any).SleepEyes.LeftLid:GetPivot().Position,
				RightLid = (giant :: any).SleepEyes.RightLid:GetPivot().Position,
				Nose = emitter.Position,
				BeardBottom = beardBottom,
			}

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
		local world = locator()
		local spots = standableSpots(world)
		expect(#spots > 500).toBe(true) -- the grid really found his body
		local zoneBoxes = WorldIndex.readZones(world) :: { Zones.ZoneBox }
		local ladders = WorldIndex.readLadders(world) :: { Zones.LadderBox }
		local misses = {}
		for _, spot in spots do
			-- a spot inside a ladder box counts as the climber's zone says (Zones.locateClimber, off the ground)
			if Zones.locateClimber(spot, false, zoneBoxes, {}, ladders).zone == "Meadow" then
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
end)
