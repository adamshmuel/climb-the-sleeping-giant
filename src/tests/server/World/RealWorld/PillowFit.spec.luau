--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)

-- Stuck safety Task 22, test 2 (docs/plans/v2/stuck-safety.md, "Ruling 1"): the pillow gets the closer fit, the same as
-- his body, so the solid shape players stand on is the pillow they see. Only its collision settings change.
-- Stuck safety Task 41: the pillow is laid flat and sunk under his head (size 120 x 46 x 30). These tests only READ the
-- world.
describe("the real world, the pillow's closer fit", function()
	local Workspace = game:GetService("Workspace")

	local CLOSER_FIT_PRECISION = 0.99
	-- Measured in step 22-0 (before the change). The numbers were printed to six places.
	local PILLOW_TEXTURE_ID = "rbxassetid://138710597423165" -- measured in step 22-0
	-- The look of the ArtLibrary original (ServerStorage.ArtLibrary._Generated.Pillow.body.body_geom), read in step 22-6c.
	local PILLOW_COLOR = Color3.fromRGB(163, 162, 165)
	local PILLOW_MATERIAL = Enum.Material.Plastic
	local PILLOW_MATERIAL_VARIANT = ""
	local PILLOW_TRANSPARENCY = 0
	local PILLOW_REFLECTANCE = 0

	local function pillowMesh(): MeshPart
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return (world :: any).GiantsThings.Pillow.body.body_geom :: MeshPart
	end

	it("the pillow stands on its closer fit", function()
		local mesh = pillowMesh()
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
		expect(wrong).toEqual({})
	end)

	-- The precise solid shape shades the piece itself in Roblox's lighting, so the pillow looked dark navy and tan
	-- instead of light blue and cream. Step 22-6a and 22-6b checked his four pieces: they stay light, so only the pillow
	-- turns its shadow off. The look values must stay the ArtLibrary original's.
	it("the closer-fit pieces keep their look", function()
		local mesh = pillowMesh()
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

	-- Task 41, test 1. Measured in step 1 on a clone (work/t41/state.md): 120 wide x 46 deep x 30 thick, its thin side
	-- (its own Z axis) pointing up, centred at x 0.14 with no turn, and sunk until the nightcap is 1.0 stud above it.
	local PILLOW_FLAT_SIZE = Vector3.new(120, 46, 30)
	local PILLOW_FLAT_POSITION = Vector3.new(0.14, 45.594, 40)
	local SIZE_WITHIN = 0.5
	local PLACE_WITHIN = 0.1
	local FLAT_WITHIN_DEGREES = 5

	it("the pillow lies flat under his head at its new size", function()
		local mesh = pillowMesh()
		local wrong: { string } = {}
		local sizeOff = (mesh.Size - PILLOW_FLAT_SIZE):Abs()
		if math.max(sizeOff.X, sizeOff.Y, sizeOff.Z) > SIZE_WITHIN then
			table.insert(wrong, `Size is {mesh.Size}, wanted {PILLOW_FLAT_SIZE} within {SIZE_WITHIN}`)
		end
		local tilt = math.deg(mesh.CFrame.ZVector:Angle(Vector3.yAxis))
		if tilt > FLAT_WITHIN_DEGREES then
			table.insert(
				wrong,
				`its thin side is {string.format("%.1f", tilt)} degrees from straight up, wanted at most {FLAT_WITHIN_DEGREES}`
			)
		end
		if (mesh.Position - PILLOW_FLAT_POSITION).Magnitude > PLACE_WITHIN then
			table.insert(wrong, `Position is {mesh.Position}, wanted {PILLOW_FLAT_POSITION} within {PLACE_WITHIN}`)
		end
		expect(wrong).toEqual({})
	end)

	local function halfExtents(mesh: MeshPart): Vector3
		local size = mesh.Size
		return (
			mesh.CFrame.XVector:Abs() * size.X
			+ mesh.CFrame.YVector:Abs() * size.Y
			+ mesh.CFrame.ZVector:Abs() * size.Z
		) / 2
	end

	-- Task 41, test 2. Two things: no nightcap part touches the pillow or comes within 1 stud of it (up and slanted-up
	-- rays from the pillow's drawn top), and rays from behind and below, aimed at his head's lowest point, meet the pillow
	-- before any nightcap part (Lesson 21: a ray starts only where a small ball overlaps nothing).
	local CAP_GAP_MIN = 1.0
	local HEAD_LOWEST = Vector3.new(2.5, 47.3, 23.5) -- his head's lowest underside point, measured in step 1

	it("no part of the nightcap comes out of the pillow", function()
		local mesh = pillowMesh()
		local world = Workspace:FindFirstChild("World")
		local caps: { Instance } = {}
		for _, part in (world :: any).Giant.nightcap:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(caps, part)
			end
		end
		local problems: { string } = {}
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Include
		overlap.FilterDescendantsInstances = caps
		local overlapping = Workspace:GetPartsInPart(mesh, overlap)
		if #overlapping > 0 then
			table.insert(problems, `{#overlapping} nightcap part(s) overlap the pillow`)
		end
		local onPillow = RaycastParams.new()
		onPillow.FilterType = Enum.RaycastFilterType.Include
		onPillow.FilterDescendantsInstances = { mesh }
		local onCap = RaycastParams.new()
		onCap.FilterType = Enum.RaycastFilterType.Include
		onCap.FilterDescendantsInstances = caps
		local half = halfExtents(mesh)
		local directions = { Vector3.new(0, 1, 0), Vector3.new(0, 1, 0.7).Unit, Vector3.new(0, 1, -0.7).Unit }
		local nearest = math.huge
		local x = -half.X
		while x <= half.X do
			local z = -half.Z
			while z <= half.Z do
				local down = Workspace:Raycast(
					Vector3.new(mesh.Position.X + x, 400, mesh.Position.Z + z),
					Vector3.new(0, -800, 0),
					onPillow
				)
				if down ~= nil then
					local start = down.Position + Vector3.new(0, 0.05, 0)
					for _, direction in directions do
						local up = Workspace:Raycast(start, direction * 60, onCap)
						if up ~= nil then
							nearest = math.min(nearest, up.Distance + 0.05)
						end
					end
				end
				z += 3
			end
			x += 3
		end
		if nearest < CAP_GAP_MIN then
			table.insert(
				problems,
				`the nearest nightcap part is {string.format("%.2f", nearest)} studs above the pillow, wanted at least {CAP_GAP_MIN}`
			)
		end
		local both = RaycastParams.new()
		both.FilterType = Enum.RaycastFilterType.Include
		both.FilterDescendantsInstances = { mesh, table.unpack(caps) }
		local ball = OverlapParams.new()
		ball.FilterType = Enum.RaycastFilterType.Include
		ball.FilterDescendantsInstances = { mesh, table.unpack(caps) }
		local backZ = mesh.Position.Z + half.Z + 40
		local notRead = 0
		for _, y in { 10, 20, 30, 40, 50, 60 } do
			for sideways = -48, 48, 12 do
				local aim = Vector3.new(HEAD_LOWEST.X + sideways * 0.25, HEAD_LOWEST.Y, HEAD_LOWEST.Z)
				local origin = Vector3.new(sideways, y, backZ)
				local direction = (aim - origin).Unit
				local moved = 0
				while #Workspace:GetPartBoundsInRadius(origin, 0.2, ball) > 0 and moved < 10 do
					origin -= direction
					moved += 1
				end
				if #Workspace:GetPartBoundsInRadius(origin, 0.2, ball) > 0 then
					notRead += 1
				else
					local hit = Workspace:Raycast(origin, direction * 250, both)
					if hit == nil or hit.Instance ~= mesh then
						table.insert(
							problems,
							`a ray from behind at x {sideways}, y {y} meets {if hit == nil
								then "nothing"
								else hit.Instance.Name} before the pillow`
						)
					end
				end
			end
		end
		if notRead > 0 then
			table.insert(problems, `{notRead} rays were not read: their start stayed inside a part`)
		end
		expect(problems).toEqual({})
	end)

	-- Task 41, test 5: the pillow makes Belly noise (game_creator, 2026-10-27: the Belly box stays where it is and the
	-- pillow's top counts as Belly, x1.5, one step down from the nightcap's x3). A list of the points that are not in
	-- the Belly zone, or that are in a garden, as short lines. Checked on the real pillow and, to prove it can fail, on
	-- a made-up box.
	local function notBelly(points: { Vector3 }, boxes: { Zones.ZoneBox }, gardens: { Zones.GardenBox }): { string }
		local bad: { string } = {}
		for _, point in points do
			local place = Zones.locate(point, boxes, gardens)
			if place.zone ~= "Belly" or place.garden ~= nil then
				table.insert(bad, `({point.X}, {point.Y}, {point.Z}) is {place.zone}, garden {place.garden}`)
			end
		end
		local lines: { string } = { `{#bad} of {#points} points are not plain Belly` }
		for index = 1, math.min(#bad, 3) do
			table.insert(lines, bad[index])
		end
		return if #bad == 0 then {} else lines
	end

	it("the pillow makes Belly noise", function()
		local mesh = pillowMesh()
		local world = Workspace:FindFirstChild("World") :: Instance
		local boxes = WorldIndex.loadZones(world)
		local gardens: { Zones.GardenBox } = {}
		for _, garden in WorldIndex.loadGardens(world) do
			table.insert(gardens, { index = garden.index, cframe = garden.box.cframe, size = garden.box.size })
		end
		local half = halfExtents(mesh)
		local onPillow = RaycastParams.new()
		onPillow.FilterType = Enum.RaycastFilterType.Include
		onPillow.FilterDescendantsInstances = { mesh }
		local top: { Vector3 } = {}
		local STEP = 4
		local x = -half.X
		while x <= half.X do
			local z = -half.Z
			while z <= half.Z do
				local hit = Workspace:Raycast(
					Vector3.new(mesh.Position.X + x, 400, mesh.Position.Z + z),
					Vector3.new(0, -800, 0),
					onPillow
				)
				if hit ~= nil then
					table.insert(top, hit.Position + Vector3.new(0, 0.5, 0))
				end
				z += STEP
			end
			x += STEP
		end
		expect(#top).toBeGreaterThan(0)
		expect(notBelly(top, boxes, {})).toEqual({})
		expect(#gardens).toBeGreaterThan(0)
		expect(notBelly(top, boxes, gardens)).toEqual({})
	end)

	it("the Belly check notices a nightcap box over the pillow", function()
		local nightcapOnly: { Zones.ZoneBox } = {
			{ zone = "Nightcap", cframe = CFrame.new(0, 5, 0), size = Vector3.new(20, 20, 20) },
		}
		local bellyOnly: { Zones.ZoneBox } = {
			{ zone = "Belly", cframe = CFrame.new(0, 5, 0), size = Vector3.new(20, 20, 20) },
		}
		expect(#notBelly({ Vector3.new(0, 4, 0) }, nightcapOnly, {})).toBeGreaterThan(0)
		expect(notBelly({ Vector3.new(0, 4, 0) }, bellyOnly, {})).toEqual({})
	end)

	-- Task 41, test 7: kept green before and after. The nightcap and the noise zone boxes keep their places and sizes
	-- (Lesson 2): as read in step 1 (2026-10-27). The cap ladder is not covered here: no part is named for it.
	local NIGHTCAP_SIZE = Vector3.new(102.5489, 64.1555, 67.5884)
	local NIGHTCAP_POSITION = Vector3.new(0.0211, 90.9223, 34.5585)
	local ZONE_BOXES: { { zone: string, position: Vector3, size: Vector3 } } = {
		{ zone = "Beard", position = Vector3.new(0, 103, -5), size = Vector3.new(104, 8, 18) },
		{ zone = "Beard", position = Vector3.new(0, 85.5, 5), size = Vector3.new(100, 27, 62) },
		{ zone = "Beard", position = Vector3.new(0, 88.5, -12), size = Vector3.new(24, 45, 32) },
		{ zone = "Belly", position = Vector3.new(0, 39.5, 26), size = Vector3.new(120, 61, 84) },
		{ zone = "Belly", position = Vector3.new(0, 39.5, -42), size = Vector3.new(28, 61, 4) },
		{ zone = "Belly", position = Vector3.new(0, 39.5, -38), size = Vector3.new(44, 61, 4) },
		{ zone = "Belly", position = Vector3.new(0, 39.5, -34), size = Vector3.new(52, 61, 4) },
		{ zone = "Belly", position = Vector3.new(0, 39.5, -30), size = Vector3.new(60, 61, 4) },
		{ zone = "Belly", position = Vector3.new(0, 39.5, -21), size = Vector3.new(68, 61, 14) },
		{ zone = "Belly", position = Vector3.new(0, 15.5, -21), size = Vector3.new(88, 13, 14) },
		{
			zone = "Belly",
			position = Vector3.new(-4.951, 57.916, -30.567),
			size = Vector3.new(29.5653, 34.1960, 27.9457),
		},
		{ zone = "Boots", position = Vector3.new(0, 28, -43.5), size = Vector3.new(80, 32, 53) },
		{ zone = "Boots", position = Vector3.new(-24, 19.495, -86.721), size = Vector3.new(12, 9, 47.8740) },
		{ zone = "Boots", position = Vector3.new(24, 19.495, -86.721), size = Vector3.new(12, 9, 47.8740) },
		{
			zone = "Boots",
			position = Vector3.new(-22.676, 31.203, -57.928),
			size = Vector3.new(22.6475, 17.5862, 25.0290),
		},
		{ zone = "Boots", position = Vector3.new(21, 32, -52), size = Vector3.new(20, 16, 24) },
		{ zone = "Nightcap", position = Vector3.new(0, 118, -3), size = Vector3.new(104, 24, 14) },
		{ zone = "Nightcap", position = Vector3.new(0, 114.5, 21.5), size = Vector3.new(104, 31, 37) },
		{ zone = "Nightcap", position = Vector3.new(0, 101, 53), size = Vector3.new(104, 58, 34) },
		{ zone = "Nightcap", position = Vector3.new(6, 118, 13), size = Vector3.new(40, 24, 34) },
	}

	it("the nightcap and the noise zone boxes keep their places and sizes", function()
		local world = Workspace:FindFirstChild("World") :: Instance
		local wrong: { string } = {}
		local cap = (world :: any).Giant.nightcap.nightcap :: BasePart
		if (cap.Size - NIGHTCAP_SIZE).Magnitude > 0.01 or (cap.Position - NIGHTCAP_POSITION).Magnitude > 0.01 then
			table.insert(
				wrong,
				`the nightcap is {cap.Size} at {cap.Position}, wanted {NIGHTCAP_SIZE} at {NIGHTCAP_POSITION}`
			)
		end
		local boxes = WorldIndex.loadZones(world)
		if #boxes ~= #ZONE_BOXES then
			table.insert(wrong, `{#boxes} zone boxes, wanted {#ZONE_BOXES}`)
		end
		for _, want in ZONE_BOXES do
			local found = false
			for _, box in boxes do
				if
					box.zone == want.zone
					and (box.cframe.Position - want.position).Magnitude < 0.01
					and (box.size - want.size).Magnitude < 0.01
				then
					found = true
					break
				end
			end
			if not found then
				table.insert(wrong, `no {want.zone} box of size {want.size} at {want.position}`)
			end
		end
		expect(wrong).toEqual({})
	end)
end)
