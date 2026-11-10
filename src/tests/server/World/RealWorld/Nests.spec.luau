--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local NestTable = require(ServerStorage.Tools.checks.NestTable)
local Helpers = require(script.Parent.Helpers)
local MockupNests = require(ServerStorage.Tests.server.World.MockupNests)
local realWorld = Helpers.realWorld

-- The 38 egg nests (plan 5 Task 12; spec 5 Rules 70, 71, 72 and 75 and the spot rules). Built by
-- tools/world/21b-nest-models.luau and tools/world/21-nests.luau. These tests only READ the real world. The spots they
-- are measured against are the ones in tools/checks/NestTable.luau (the style guide's nest map).
describe("the real world, the 38 nests", function()
	local WALK_LIMIT = 56 -- studs: Rule 75's 3.5-second walk from a garden's spawn spot

	-- Every model in World.EggSpots named Nest_..., by name.
	local function nestModels(): { [string]: Model }
		local folder = realWorld():FindFirstChild("EggSpots") :: Instance
		expect(folder).never.toBeNil()
		local models: { [string]: Model } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and string.sub(child.Name, 1, 5) == "Nest_" then
				models[child.Name] = child
			end
		end
		return models
	end

	-- Where a nest's egg sits: the top of its Base (the same point WorldIndex.readEggSpots reads).
	local function spotOf(model: Model): Vector3?
		local base = model:FindFirstChild("Base")
		if base == nil or not base:IsA("BasePart") then
			return nil
		end
		return (base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)).Position
	end

	-- The nearest point of a part's box to a point, as a distance (0 inside).
	local function boxDistance(part: BasePart, point: Vector3): number
		local localPoint = part.CFrame:PointToObjectSpace(point)
		local half = part.Size / 2
		local inside = Vector3.new(
			math.clamp(localPoint.X, -half.X, half.X),
			math.clamp(localPoint.Y, -half.Y, half.Y),
			math.clamp(localPoint.Z, -half.Z, half.Z)
		)
		return (localPoint - inside).Magnitude
	end

	local function spots(): { [string]: Vector3 }
		local found: { [string]: Vector3 } = {}
		for name, model in nestModels() do
			local spot = spotOf(model)
			if spot ~= nil then
				found[name] = spot
			end
		end
		return found
	end

	local function describeGap(name: string, other: string, gap: number): string
		return string.format("%s and %s are %.2f apart", name, other, gap)
	end

	it("there are 38 nests, and per rank Common 16, Uncommon 8, Rare 6, Epic 4, Legendary 4", function()
		local counts: { [string]: number } = {}
		local total = 0
		for _, model in nestModels() do
			local rank = model:GetAttribute("Rarity")
			counts[tostring(rank)] = (counts[tostring(rank)] or 0) + 1
			total += 1
		end
		local problems: { string } = {}
		for _, rank in Config.RarityOrder do
			local want = Config.Rarity[rank].Nests
			if (counts[rank] or 0) ~= want then
				table.insert(problems, `{rank}: {counts[rank] or 0} nests, expected {want}`)
			end
		end
		if total ~= #NestTable.NESTS then
			table.insert(problems, `{total} nests, expected {#NestTable.NESTS}`)
		end
		expect(problems).toEqual({})
	end)

	it("every nest is within 0.5 studs of its spot in the map", function()
		local models = nestModels()
		local problems: { string } = {}
		for _, nest in NestTable.NESTS do
			local model = models[nest.name]
			local spot = if model then spotOf(model) else nil
			if spot == nil then
				table.insert(problems, `{nest.name} is missing`)
			elseif (spot - nest.spot).Magnitude > 0.5 then
				table.insert(
					problems,
					string.format("%s is %.2f from its spot", nest.name, (spot - nest.spot).Magnitude)
				)
			end
		end
		expect(problems).toEqual({})
	end)

	it("every nest off the middle line has a twin of the same rank within 2 studs of its exact mirror", function()
		local models, found = nestModels(), spots()
		local problems: { string } = {}
		for name, model in models do
			local spot = found[name]
			if not spot or math.abs(spot.X) < 0.01 then
				continue
			end
			local twinName = model:GetAttribute("Twin")
			local twin = if type(twinName) == "string" then models[twinName] else nil
			local twinSpot = if type(twinName) == "string" then found[twinName] else nil
			if twin == nil or twinSpot == nil then
				table.insert(problems, `{name} has no twin ({tostring(twinName)})`)
				continue
			end
			local off = (twinSpot - Vector3.new(-spot.X, spot.Y, spot.Z)).Magnitude
			if twin:GetAttribute("Rarity") ~= model:GetAttribute("Rarity") or off > Config.Nests.TwinDistance then
				table.insert(problems, string.format("%s twin %s: %.2f from the mirror", name, twin.Name, off))
			end
		end
		expect(problems).toEqual({})
		expect((next(found))).never.toBeNil() -- a world with no nests has nothing to pass
	end)

	it("no nest is within 10 studs of his eyes", function()
		local giant = realWorld():FindFirstChild("Giant") :: Instance
		local eyes = giant:FindFirstChild("SleepEyes") :: Instance
		expect(eyes).never.toBeNil()
		local found = spots()
		expect((next(found))).never.toBeNil()
		local problems: { string } = {}
		for name, spot in found do
			for _, part in eyes:GetDescendants() do
				if part:IsA("BasePart") then
					local distance = boxDistance(part, spot)
					if distance < Config.Nests.EyeDistance then
						table.insert(problems, string.format("%s is %.1f from %s", name, distance, part.Name))
					end
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it(
		"each garden has 2 meadow nests, 8 studs apart, and each is a 56-stud walk or less from its spawn spot",
		function()
			local models, found = nestModels(), spots()
			local world = realWorld()
			local meadow: { [number]: { string } } = {}
			for name, model in models do
				local garden = model:GetAttribute("Garden")
				if type(garden) == "number" then
					meadow[garden] = meadow[garden] or {}
					table.insert(meadow[garden], name)
				end
			end
			local problems: { string } = {}
			for garden = 1, NestTable.GARDEN_COUNT do
				local mine: { string } = meadow[garden] or {}
				if #mine ~= 2 then
					table.insert(problems, `garden {garden} has {#mine} meadow nests`)
				end
				local plot = (world:FindFirstChild("Plots") :: Instance):FindFirstChild(`Plot_{garden}`) :: Instance
				local bridge = (world:FindFirstChild("Bridges") :: Instance):FindFirstChild(
						`PlankBridge_{garden}`
					) :: Model
				local spawnSpot = plot:FindFirstChild("SpawnSpot") :: BasePart
				-- The footprint route to a nest comes in Task 17, so the walk is spawn spot -> far end of the garden's
				-- bridge -> nest in a straight line each way.
				local boxCf, boxSize = bridge:GetBoundingBox()
				local axis = if boxSize.X >= boxSize.Z then boxCf.RightVector else boxCf.LookVector
				local half = math.max(boxSize.X, boxSize.Z) / 2
				local endA, endB = boxCf.Position + axis * half, boxCf.Position - axis * half
				local farEnd = if (endA - spawnSpot.Position).Magnitude > (endB - spawnSpot.Position).Magnitude
					then endA
					else endB
				for _, name in mine do
					local spot = found[name]
					if spot then
						local walk = (farEnd - spawnSpot.Position).Magnitude + (spot - farEnd).Magnitude
						if walk > WALK_LIMIT then
							table.insert(
								problems,
								string.format("%s is a %.1f stud walk from garden %d", name, walk, garden)
							)
						end
					end
				end
			end
			-- Every meadow nest keeps 8 studs from every other meadow nest, its garden's and the others'.
			local names: { string } = {}
			for _, list in meadow do
				for _, name in list do
					table.insert(names, name)
				end
			end
			table.sort(names)
			for i = 1, #names do
				for j = i + 1, #names do
					local a, b = found[names[i]], found[names[j]]
					if a and b and (a - b).Magnitude < Config.Nests.MeadowSpacing then
						table.insert(problems, describeGap(names[i], names[j], (a - b).Magnitude))
					end
				end
			end
			expect(problems).toEqual({})
		end
	)

	it(
		"the belly pocket keeps 6 studs from Rare egg 1, the lap fold from every nest, and each side's Rare nests apart",
		function()
			local found = spots()
			local problems: { string } = {}
			local rareOne = found[Config.Nests.RareEggOne]
			if not rareOne then
				table.insert(problems, `{Config.Nests.RareEggOne} (Rare egg 1) is missing`)
			end
			for _, side in { "Left", "Right" } do
				local pocket, fold = found[`Nest_BellyPocket_{side}`], found[`Nest_LapFold_{side}`]
				if not pocket or not fold then
					table.insert(problems, `the {side} belly pocket or lap fold is missing`)
					continue
				end
				local rareSpot = found[`Nest_LowerBelly_{side}`]
				-- 0.1 stud of slack on him (nests-map.md): 5.95 passes the 6 limit.
				if rareSpot and (pocket - rareSpot).Magnitude < Config.Nests.EggSpacing - 0.1 then
					table.insert(
						problems,
						describeGap(`Nest_BellyPocket_{side}`, `Nest_LowerBelly_{side}`, (pocket - rareSpot).Magnitude)
					)
				end
				for name, spot in found do
					if name ~= `Nest_LapFold_{side}` and (spot - fold).Magnitude < Config.Nests.EggSpacing then
						table.insert(problems, describeGap(`Nest_LapFold_{side}`, name, (spot - fold).Magnitude))
					end
				end
			end
			local rares: { [string]: { string } } = { Left = {}, Right = {} }
			for name, model in nestModels() do
				local side = if string.sub(name, -4) == "Left" then "Left" else "Right"
				if model:GetAttribute("Rarity") == "Rare" then
					table.insert(rares[side], name)
				end
			end
			for side, names in rares do
				if #names < 2 then
					table.insert(problems, `{side} has {#names} Rare nests, needs 2`)
				end
				for i = 1, #names do
					for j = i + 1, #names do
						local a, b = found[names[i]], found[names[j]]
						-- same 0.1 slack as the pocket check above (nests-map.md, veto 2026-11-10)
						if a and b and (a - b).Magnitude < Config.Nests.EggSpacing - 0.1 then
							table.insert(problems, describeGap(names[i], names[j], (a - b).Magnitude))
						end
					end
				end
			end
			expect(problems).toEqual({})
		end
	)

	it("no V1 egg spot and no glow ring is left, and every nest has a NestName", function()
		local folder = realWorld():FindFirstChild("EggSpots") :: Instance
		expect(folder).never.toBeNil()
		local problems: { string } = {}
		for _, child in folder:GetChildren() do
			if string.sub(child.Name, 1, 8) == "EggSpot_" then
				table.insert(problems, `V1 spot {child.Name} is left`)
			end
		end
		for _, descendant in folder:GetDescendants() do
			if descendant.Name == "GlowRing" then
				table.insert(problems, `glow ring {descendant:GetFullName()} is left`)
			end
		end
		local models = nestModels()
		for name, model in models do
			if type(model:GetAttribute("NestName")) ~= "string" then
				table.insert(problems, `{name} has no NestName`)
			end
		end
		if next(models) == nil then
			table.insert(problems, "no nest models")
		end
		expect(problems).toEqual({})
	end)

	-- Each belly pocket piece in World.NestArt sits within 0.1 studs of its source piece in the mockup (Task 16 cut the
	-- stitches to the pockets where they stand today, so a moved pocket would open a gap or cover a stitch).
	it("each belly pocket piece copied into NestArt sits within 0.1 studs of its source piece", function()
		local mockup = MockupNests.find() :: Instance
		expect(mockup).never.toBeNil()
		local sources = (mockup:FindFirstChild("Art") :: Instance):FindFirstChild("Pockets") :: Instance
		local nestArt = realWorld():FindFirstChild("NestArt") :: Instance
		expect(nestArt).never.toBeNil()
		local problems: { string } = {}
		for _, side in { "Left", "Right" } do
			local source = sources:FindFirstChild(`BellyPocket_{side}`) :: Instance
			local copy = nestArt:FindFirstChild(`BellyPocket_{side}`)
			if copy == nil then
				table.insert(problems, `NestArt has no BellyPocket_{side}`)
				continue
			end
			for _, piece in source:GetDescendants() do
				if not piece:IsA("BasePart") then
					continue
				end
				local nearest = math.huge
				for _, candidate in copy:GetDescendants() do
					if candidate:IsA("BasePart") and candidate.Name == piece.Name then
						nearest = math.min(nearest, (candidate.Position - piece.Position).Magnitude)
					end
				end
				if nearest > 0.1 then
					table.insert(
						problems,
						string.format("%s %s: nearest copy %.2f away", source.Name, piece.Name, nearest)
					)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	-- The mockup rule: a piece copied out of the mockup gets its real look back and is never solid, with no Mockup*
	-- attribute left (the mockup hides its parts with Transparency 1 and keeps the real values in those attributes).
	it("every NestArt piece has no Mockup attribute, Transparency 0 and CanCollide false", function()
		local nestArt = realWorld():FindFirstChild("NestArt") :: Instance
		expect(nestArt).never.toBeNil()
		local problems: { string } = {}
		local pieces = 0
		for _, piece in nestArt:GetDescendants() do
			for name in piece:GetAttributes() do
				if string.sub(name, 1, 6) == "Mockup" then
					table.insert(problems, `{piece:GetFullName()} still has {name}`)
				end
			end
			-- LedgeWalk* pieces are walk guides that stay invisible on purpose.
			if piece:IsA("BasePart") then
				pieces += 1
				if piece.Transparency ~= 0 and string.sub(piece.Name, 1, 9) ~= "LedgeWalk" then
					table.insert(problems, `{piece:GetFullName()} Transparency {piece.Transparency}`)
				end
				if piece.CanCollide then
					table.insert(problems, `{piece:GetFullName()} CanCollide is true`)
				end
			end
		end
		if pieces == 0 then
			table.insert(problems, "NestArt has no parts")
		end
		expect(problems).toEqual({})
	end)
end)
