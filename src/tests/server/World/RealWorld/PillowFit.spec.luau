--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

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
