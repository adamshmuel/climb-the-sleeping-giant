--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)
local flat = Helpers.flat

-- These tests only READ the real world (Workspace.World). They change nothing.
-- The world is built by tools/world/01-gardens.luau.
describe("the real world", function()
	local function isInside(box: WorldIndex.Box, point: Vector3): boolean
		local local_ = box.cframe:PointToObjectSpace(point)
		local half = box.size / 2
		return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
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
