--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local Collisions = require(ServerScriptService.Server.Players.Collisions)

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
