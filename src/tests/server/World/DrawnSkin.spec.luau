--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)

-- The helper that measures the skin a player sees (stuck safety Task 26). These tests use made-up triangles and parts,
-- never the giant. The tests that ask Roblox itself build one part far from the map and destroy it again.
describe("DrawnSkin", function()
	local Workspace = game:GetService("Workspace")
	local FAR = Vector3.new(4000, 4000, 4000)

	local function triangle(a: Vector3, b: Vector3, c: Vector3): DrawnSkin.Triangle
		return { a = a, b = b, c = c }
	end

	local function newBlock(size: Vector3, cframe: CFrame): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size
		part.CFrame = cframe
		return part
	end

	local function newWedge(size: Vector3, cframe: CFrame): WedgePart
		local part = Instance.new("WedgePart")
		part.Anchored = true
		part.Size = size
		part.CFrame = cframe
		return part
	end

	-- The top of a part according to Roblox: a ray straight down from far above, at (x, z).
	local function robloxTop(part: BasePart, x: number, z: number): number?
		local previous = part.Parent
		part.Parent = Workspace
		local hit = Workspace:Raycast(Vector3.new(x, FAR.Y + 100, z), Vector3.new(0, -200, 0))
		part.Parent = previous
		return if hit and hit.Instance == part then hit.Position.Y else nil
	end

	describe("triangles", function()
		it("reads the height of a sloping triangle between its corners", function()
			-- the plane y = x over the triangle (0,0) (4,0) (0,4)
			local skin = DrawnSkin.new({
				triangle(Vector3.new(0, 0, 0), Vector3.new(4, 4, 0), Vector3.new(0, 0, 4)),
			})
			expect(skin.heightAt(1, 1)).toBeCloseTo(1, 5)
			expect(skin.heightAt(2, 1)).toBeCloseTo(2, 5)
		end)

		it("finds nothing outside every triangle", function()
			local skin = DrawnSkin.new({
				triangle(Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), Vector3.new(0, 0, 4)),
			})
			expect(skin.heightAt(3, 3)).toBeNil() -- past the long edge
			expect(skin.heightAt(-1, 1)).toBeNil()
			expect(skin.heightAt(100, 100)).toBeNil() -- no cell there at all
		end)

		it("takes the highest surface when two lie over each other", function()
			local skin = DrawnSkin.new({
				triangle(Vector3.new(0, 1, 0), Vector3.new(4, 1, 0), Vector3.new(0, 1, 4)),
				triangle(Vector3.new(0, 3, 0), Vector3.new(4, 3, 0), Vector3.new(0, 3, 4)),
			})
			expect(skin.heightAt(1, 1)).toBeCloseTo(3, 5)
		end)

		it("takes the highest surface at or under a ceiling", function()
			local skin = DrawnSkin.new({
				triangle(Vector3.new(0, 1, 0), Vector3.new(4, 1, 0), Vector3.new(0, 1, 4)),
				triangle(Vector3.new(0, 7, 0), Vector3.new(4, 7, 0), Vector3.new(0, 7, 4)),
			})
			expect(skin.heightAt(1, 1, 5)).toBeCloseTo(1, 5)
			expect(skin.heightAt(1, 1, 0.5)).toBeNil()
		end)

		it("ignores a wall seen edge-on", function()
			local skin = DrawnSkin.new({
				triangle(Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), Vector3.new(0, 9, 0)),
			})
			expect(skin.heightAt(1, 0)).toBeNil()
		end)

		it("finds a triangle that crosses several grid cells from any cell it covers", function()
			local skin = DrawnSkin.new({
				triangle(Vector3.new(-9, 2, -9), Vector3.new(9, 2, -9), Vector3.new(0, 2, 9)),
			})
			expect(skin.heightAt(-7, -8)).toBeCloseTo(2, 5)
			expect(skin.heightAt(6, -8)).toBeCloseTo(2, 5)
			expect(skin.heightAt(0, 8)).toBeCloseTo(2, 5)
		end)
	end)

	-- Task 37 (3b): the Sock's lip is an upright curtain, which a straight-down read can't see. A line read gives the
	-- distance to the nearest triangle a straight line meets, in any direction.
	describe("a line along a flat direction", function()
		-- An upright triangle in the plane z = 5: corners (0,0,5), (8,0,5), (0,8,5).
		local function curtain(z: number): DrawnSkin.Triangle
			return triangle(Vector3.new(0, 0, z), Vector3.new(8, 0, z), Vector3.new(0, 8, z))
		end

		it("reads the distance to an upright triangle along a flat line", function()
			local skin = DrawnSkin.new({ curtain(5) })
			expect(skin.distanceAlong(Vector3.new(2, 2, 0), Vector3.zAxis, 10)).toBeCloseTo(5, 5)
			expect(skin.distanceAlong(Vector3.new(2, 2, 9), -Vector3.zAxis, 10)).toBeCloseTo(4, 5)
		end)

		it("finds nothing past the triangle's edge or beyond the reach", function()
			local skin = DrawnSkin.new({ curtain(5) })
			expect(skin.distanceAlong(Vector3.new(7, 7, 0), Vector3.zAxis, 10)).toBeNil() -- past the long edge
			expect(skin.distanceAlong(Vector3.new(2, 2, 0), Vector3.zAxis, 4)).toBeNil() -- 5 away, reach 4
			expect(skin.distanceAlong(Vector3.new(2, 2, 6), Vector3.zAxis, 10)).toBeNil() -- the triangle is behind
		end)

		it("takes the nearer of two triangles on the line", function()
			local skin = DrawnSkin.new({ curtain(5), curtain(3), curtain(8) })
			expect(skin.distanceAlong(Vector3.new(2, 2, 0), Vector3.zAxis, 10)).toBeCloseTo(3, 5)
		end)
	end)

	describe("shirt folds", function()
		it("reads the top of a block", function()
			local part = newBlock(Vector3.new(4, 2, 4), CFrame.new(10, 5, 10))
			local skin = DrawnSkin.fromWorld({}, { part })
			part:Destroy()
			expect(skin.heightAt(10, 10)).toBeCloseTo(6, 5)
			expect(skin.heightAt(11.9, 8.1)).toBeCloseTo(6, 5)
			expect(skin.heightAt(12.1, 10)).toBeNil()
		end)

		it("reads a turned block like Roblox does", function()
			local cframe = CFrame.new(FAR) * CFrame.Angles(math.rad(20), math.rad(35), math.rad(50))
			local part = newBlock(Vector3.new(6, 3, 5), cframe)
			local solid = DrawnSkin.solidOf(part)
			local checked = 0
			for x = -2.5, 2.5, 0.5 do
				for z = -2.5, 2.5, 0.5 do
					local expected = robloxTop(part, FAR.X + x, FAR.Z + z)
					local _, top = DrawnSkin.columnSpan(solid, FAR.X + x, FAR.Z + z)
					if expected ~= nil then
						checked += 1
						expect(top).toBeCloseTo(expected, 3)
					else
						expect(top).toBeNil()
					end
				end
			end
			part:Destroy()
			expect(checked > 10).toBe(true)
		end)

		it("reads a wedge like Roblox does: full height on its +Z side, nothing at its -Z side", function()
			local part = newWedge(Vector3.new(4, 6, 8), CFrame.new(FAR))
			local solid = DrawnSkin.solidOf(part)
			for _, z in { -3.9, -2, 0, 2, 3.9 } do
				local expected = robloxTop(part, FAR.X, FAR.Z + z)
				local _, top = DrawnSkin.columnSpan(solid, FAR.X, FAR.Z + z)
				expect(expected).never.toBeNil()
				expect(top).toBeCloseTo(expected :: number, 3)
			end
			part:Destroy()
		end)

		it("reads a turned wedge like Roblox does", function()
			local cframe = CFrame.new(FAR) * CFrame.Angles(math.rad(15), math.rad(130), math.rad(-25))
			local part = newWedge(Vector3.new(5, 4, 7), cframe)
			local solid = DrawnSkin.solidOf(part)
			local checked = 0
			for x = -3, 3, 0.5 do
				for z = -3, 3, 0.5 do
					local expected = robloxTop(part, FAR.X + x, FAR.Z + z)
					local _, top = DrawnSkin.columnSpan(solid, FAR.X + x, FAR.Z + z)
					if expected ~= nil then
						checked += 1
						expect(top).toBeCloseTo(expected, 3)
					else
						expect(top).toBeNil()
					end
				end
			end
			part:Destroy()
			expect(checked > 10).toBe(true)
		end)

		it("gives a column's lowest and highest point", function()
			local solid = DrawnSkin.solidOf(newBlock(Vector3.new(4, 2, 4), CFrame.new(0, 5, 0)))
			local low, high = DrawnSkin.columnSpan(solid, 1, 1)
			expect(low).toBeCloseTo(4, 5)
			expect(high).toBeCloseTo(6, 5)
			local missLow, missHigh = DrawnSkin.columnSpan(solid, 3, 0)
			expect(missLow).toBeNil()
			expect(missHigh).toBeNil()
		end)

		it("takes a fold at or under a ceiling, and the skin under it when the ceiling cuts the fold", function()
			local part = newBlock(Vector3.new(4, 2, 4), CFrame.new(0, 5, 0))
			local skin = DrawnSkin.new({
				triangle(Vector3.new(-9, 1, -9), Vector3.new(9, 1, -9), Vector3.new(0, 1, 9)),
			}, { DrawnSkin.solidOf(part) })
			part:Destroy()
			expect(skin.heightAt(0, 0)).toBeCloseTo(6, 5)
			expect(skin.heightAt(0, 0, 7)).toBeCloseTo(6, 5)
			expect(skin.heightAt(0, 0, 5.5)).toBeCloseTo(1, 5) -- the ceiling is inside the fold
		end)

		it("refuses a fold that is not a block or a wedge", function()
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			expect(function()
				DrawnSkin.fromWorld({}, { ball })
			end).toThrow("only blocks and wedges")
			local truss = Instance.new("TrussPart")
			expect(function()
				DrawnSkin.fromWorld({}, { truss })
			end).toThrow("shirt fold")
			ball:Destroy()
			truss:Destroy()
		end)
	end)

	it("counts what it holds", function()
		local part = newBlock(Vector3.new(1, 1, 1), CFrame.new(0, 0, 0))
		local skin = DrawnSkin.new({
			triangle(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)),
		}, { DrawnSkin.solidOf(part) })
		part:Destroy()
		expect({ skin.triangleCount, skin.solidCount }).toEqual({ 1, 1 })
	end)
end)
