--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local HandShape = require(ReplicatedStorage.Shared.HandShape)

local function contains(position: Vector3, centre: Vector3, surfaceY: number): boolean
	return HandShape.contains(position, centre, surfaceY)
end

describe("HandShape.contains", function()
	local centre = Vector3.new(10, 40, -20)
	local surfaceY = 4

	it("a point 30 studs over the surface inside the circle is in, 46 studs over is out", function()
		expect(contains(Vector3.new(10, surfaceY + 30, -20), centre, surfaceY)).toBe(true)
		expect(contains(Vector3.new(10, surfaceY + 46, -20), centre, surfaceY)).toBe(false)
	end)

	it("the height band runs from 1 stud under the surface to 45 studs over it, edges included", function()
		expect(contains(Vector3.new(10, surfaceY - Config.Wake.HandBelowStuds, -20), centre, surfaceY)).toBe(true)
		expect(contains(Vector3.new(10, surfaceY + Config.Wake.HandAboveStuds, -20), centre, surfaceY)).toBe(true)
	end)

	it("a point 2 studs under the surface (under a bridge) is out", function()
		expect(contains(Vector3.new(10, surfaceY - 2, -20), centre, surfaceY)).toBe(false)
	end)

	it("15 studs from the centre across the ground is in, 15.1 is out", function()
		expect(contains(Vector3.new(25, surfaceY, -20), centre, surfaceY)).toBe(true)
		expect(contains(Vector3.new(25.1, surfaceY, -20), centre, surfaceY)).toBe(false)
	end)

	it("the distance across the ground ignores the circle's own height", function()
		expect(contains(Vector3.new(10, surfaceY, -5), Vector3.new(10, 200, -20), surfaceY)).toBe(true)
	end)
end)
