--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
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

	-- Counts per rank and the approved places are Nests.spec's tests now (plan 5 Task 12); this one keeps the zone rule
	-- for the meadow nests.
	it("every meadow nest is in the Meadow zone and in no garden", function()
		local commons = ofRarity(loadSpots(), "Common")
		expect(#commons).toBe(16)
		for _, spot in commons do
			local base = spot.model:FindFirstChild("Base") :: BasePart
			for _, point in { spot.cframe.Position, base.Position } do
				local place = locate(point)
				expect({ spot = spot.name, zone = place.zone, garden = place.garden }).toEqual({
					spot = spot.name,
					zone = "Meadow",
					garden = nil,
				})
			end
		end
	end)

	-- 0.1 stud of slack on him (nests-map.md): 5.95 passes the 6 limit.
	it("no two nests are closer than 6 studs (within 0.1)", function()
		local spots = loadSpots()
		local tooClose = {}
		for first = 1, #spots do
			for second = first + 1, #spots do
				local distance = (spots[first].cframe.Position - spots[second].cframe.Position).Magnitude
				if distance < Config.Nests.EggSpacing - 0.1 then
					table.insert(tooClose, `{spots[first].name} and {spots[second].name}: {distance}`)
				end
			end
		end
		expect(tooClose).toEqual({})
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

	local BOOT_NESTS: { [string]: { string } } = {
		Left = { "Nest_BootToeInner_Left", "Nest_BootToeOuter_Left" },
		Right = { "Nest_BootToeInner_Right", "Nest_BootToeOuter_Right" },
	}

	it("the four boot-toe nests each stand on their own boot top", function()
		local byName: { [string]: WorldIndex.EggSpot } = {}
		for _, spot in loadSpots() do
			byName[spot.name] = spot
		end
		local result: { [string]: boolean } = {}
		local want: { [string]: boolean } = {}
		for side, names in BOOT_NESTS do
			for _, name in names do
				local at = byName[name].cframe.Position
				result[name] =
					standsInside(if side == "Left" then LEFT_BOOT_TOP else RIGHT_BOOT_TOP, at.X, at.Z, EGG_BOOT_INSET)
				want[name] = true
			end
		end
		expect(result).toEqual(want)
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
	it("the four boot-toe nests touch the boot top", function()
		local byName: { [string]: WorldIndex.EggSpot } = {}
		for _, spot in loadSpots() do
			byName[spot.name] = spot
		end
		local params = bodyParams()
		for _, name in
			{ "Nest_BootToeInner_Left", "Nest_BootToeOuter_Left", "Nest_BootToeInner_Right", "Nest_BootToeOuter_Right" }
		do
			local top = byName[name].cframe.Position
			local hit = Workspace:Raycast(top + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
			expect({ spot = name, skinFound = hit ~= nil }).toEqual({ spot = name, skinFound = true })
			local gap = top.Y - (hit :: RaycastResult).Position.Y
			expect({ spot = name, touches = gap <= 0.2 and gap >= -0.3 }).toEqual({ spot = name, touches = true })
		end
	end)

	it("each garden has its own 2 meadow nests near its spawn spot, beyond its plank bridge", function()
		local commons = ofRarity(loadSpots(), "Common")
		local world = realWorld()
		for _, garden in loadGardens() do
			local spawn = garden.spawnSpot.Position
			local mine = {}
			for _, spot in commons do
				if spot.garden == garden.index then
					table.insert(mine, spot)
				end
			end
			expect({ garden = garden.index, nests = #mine }).toEqual({ garden = garden.index, nests = 2 })
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
			for _, spot in mine do
				local distance = (spot.cframe.Position - spawn).Magnitude
				-- a few seconds' walk: between 15 and 80 studs in a straight line (the walk crosses the bridge)
				expect({ nest = spot.name, farEnough = distance >= 15, closeEnough = distance <= 80 }).toEqual({
					nest = spot.name,
					farEnough = true,
					closeEnough = true,
				})
				local pastEnd = (spot.cframe.Position - farEnd) * Vector3.new(1, 0, 1)
				expect({
					nest = spot.name,
					beyondTheBridge = pastEnd:Dot(direction) > 4,
					near = pastEnd.Magnitude <= 30,
				}).toEqual({
					nest = spot.name,
					beyondTheBridge = true,
					near = true,
				})
			end
		end
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

	-- A piece (or fill) of a belly ramp counts as a walk surface (plan 3 Task 6a).
	local function isBellyRampPiece(part: Instance): boolean
		return part:FindFirstAncestor("BellyRamp_Left") ~= nil or part:FindFirstAncestor("BellyRamp_Right") ~= nil
	end

	-- How far the spot is from the nearest place a character can stand, and what that place is.
	-- A character can stand on: the meadow's grass (Terrain with a flat top, not water), or the top face of a walk
	-- surface (a part named *_Walk, or a piece of a belly ramp (plan 3 Task 6a), which is solid and no steeper than the
	-- project's slope limit of 70 degrees, the same limit Humanoids use). The distance goes from the top of the spot's Base to the nearest point of
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
		-- distance from `top` to the nearest point of the part's top face
		local function nearestOn(part: BasePart): number
			local local_ = part.CFrame:PointToObjectSpace(top)
			local half = part.Size / 2
			local nearest = part.CFrame:PointToWorldSpace(
				Vector3.new(math.clamp(local_.X, -half.X, half.X), half.Y, math.clamp(local_.Z, -half.Z, half.Z))
			)
			return (nearest - top).Magnitude
		end
		for _, part in (realWorld() :: any).WalkSurfaces:GetDescendants() do
			if
				part:IsA("BasePart")
				and part.CanCollide
				and (string.match(part.Name, "_Walk$") ~= nil or isBellyRampPiece(part))
				and part.CFrame.UpVector.Y >= limit
			then
				local distance = nearestOn(part)
				if distance < best then
					best, kind = distance, "walk surface"
				end
			end
		end
		-- The cuff ledges (plan 5 Task 12): World.CuffWalk's collidable parts are walk surfaces too.
		for _, part in (realWorld() :: any).CuffWalk:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide and part.CFrame.UpVector.Y >= limit then
				local distance = nearestOn(part)
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

	it(
		"ServerStorage.Assets.Eggs has a fully anchored egg for each of the five ranks, and no nest has a glow ring",
		function()
			local assets = ServerStorage:FindFirstChild("Assets")
			expect(assets).never.toBeNil()
			local templates, problems = WorldIndex.readEggTemplates(assets :: Instance)
			expect(problems).toEqual({})
			for _, rarity in Config.RarityOrder do
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
				-- the look kept from the mockup: a light, sparkles and the rarity label (and a beam above Uncommon)
				expect(egg:FindFirstChildWhichIsA("PointLight", true)).never.toBeNil()
				expect(egg:FindFirstChildWhichIsA("ParticleEmitter", true)).never.toBeNil()
				local label = egg:FindFirstChild("Label", true)
				expect(label).never.toBeNil()
				expect(((label :: Instance):FindFirstChildWhichIsA("TextLabel") :: TextLabel).Text).toBe(rarity)
				expect(egg:FindFirstChildWhichIsA("Beam", true) ~= nil).toBe(
					rarity ~= "Common" and rarity ~= "Uncommon"
				)
			end
			for _, spot in loadSpots() do
				expect({ spot = spot.name, ring = spot.model:FindFirstChild("GlowRing") ~= nil }).toEqual({
					spot = spot.name,
					ring = false,
				})
			end
		end
	)

	it("each egg model's pivot is at the bottom centre of the egg", function()
		local templates = WorldIndex.loadEggTemplates(ServerStorage:FindFirstChild("Assets") :: Instance)
		for _, rarity in Config.RarityOrder do
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

	local function loadTemplates(): { [string]: Model }
		local templates = WorldIndex.loadEggTemplates(ServerStorage:FindFirstChild("Assets") :: Instance)
		return templates :: any
	end

	local function eggHeight(egg: Model): number
		local _, boxSize = egg:GetBoundingBox()
		return boxSize.Y
	end

	it("the Epic and Legendary eggs wear their rank colour (Rule 51)", function()
		local templates = loadTemplates()
		local wanted: { [string]: string } = { Epic = "5E3CFF", Legendary = "FFA51F" }
		for rarity, hex in wanted do
			local appearance = templates[rarity]:FindFirstChildWhichIsA("SurfaceAppearance", true)
			expect(appearance).never.toBeNil()
			local want = Color3.fromHex(hex)
			local got = (appearance :: SurfaceAppearance).Color
			expect({
				egg = rarity,
				r = math.abs(got.R - want.R) <= 1 / 255,
				g = math.abs(got.G - want.G) <= 1 / 255,
				b = math.abs(got.B - want.B) <= 1 / 255,
			}).toEqual({ egg = rarity, r = true, g = true, b = true })
		end
	end)

	it("the Epic and Legendary eggs are as tall as the Rare egg, within 5 percent", function()
		local templates = loadTemplates()
		local rare = eggHeight(templates.Rare)
		for _, rarity in { "Epic", "Legendary" } do
			local height = eggHeight(templates[rarity])
			expect({ egg = rarity, close = math.abs(height - rare) <= rare * 0.05 }).toEqual({
				egg = rarity,
				close = true,
			})
		end
	end)

	it("no egg template keeps a Halo or a Mockup attribute, and the Epic and Legendary eggs show", function()
		local templates = loadTemplates()
		for _, rarity in Config.RarityOrder do
			local egg = templates[rarity]
			local everything: { Instance } = egg:GetDescendants()
			table.insert(everything, egg)
			for _, item in everything do
				expect({ item = item:GetFullName(), halo = item.Name == "Halo" }).toEqual({
					item = item:GetFullName(),
					halo = false,
				})
				for name in item:GetAttributes() do
					expect({ item = item:GetFullName(), mockup = string.sub(name, 1, 6) == "Mockup" }).toEqual({
						item = item:GetFullName(),
						mockup = false,
					})
				end
			end
		end
		for _, rarity in { "Epic", "Legendary" } do
			local largest: BasePart? = nil
			for _, item in templates[rarity]:GetDescendants() do
				if item:IsA("BasePart") then
					local size = item.Size
					if
						largest == nil
						or size.X * size.Y * size.Z > largest.Size.X * largest.Size.Y * largest.Size.Z
					then
						largest = item
					end
				end
			end
			expect(largest).never.toBeNil()
			expect({ egg = rarity, shows = (largest :: BasePart).Transparency < 0.5 }).toEqual({
				egg = rarity,
				shows = true,
			})
		end
	end)

	it("the Epic and Legendary lights, sparkles and beams are on like the Rare's", function()
		local templates = loadTemplates()
		for _, className in { "PointLight", "ParticleEmitter", "Beam" } do
			local rareItem = templates.Rare:FindFirstChildWhichIsA(className, true)
			expect(rareItem).never.toBeNil()
			local rareEnabled = (rareItem :: any).Enabled
			for _, rarity in { "Epic", "Legendary" } do
				for _, item in templates[rarity]:GetDescendants() do
					if item:IsA(className) then
						expect({ item = item:GetFullName(), enabled = (item :: any).Enabled }).toEqual({
							item = item:GetFullName(),
							enabled = rareEnabled,
						})
					end
				end
			end
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
		end
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
