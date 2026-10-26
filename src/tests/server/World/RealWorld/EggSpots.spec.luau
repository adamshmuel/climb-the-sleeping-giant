--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local SpotModels = require(ServerScriptService.Server.Eggs.SpotModels)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Helpers = require(script.Parent.Helpers)
local BODY_PIECES = Helpers.BODY_PIECES
local realWorld = Helpers.realWorld

-- The egg spots and the egg models (Task 16). They are built by tools/world/04-egg-spots.luau. These tests only READ
-- the real world and the real ServerStorage; they change nothing.
describe("the real world, egg spots", function()
	local Workspace = game:GetService("Workspace")
	local ServerStorage = game:GetService("ServerStorage")

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
