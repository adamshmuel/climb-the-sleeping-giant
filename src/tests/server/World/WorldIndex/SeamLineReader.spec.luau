--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- Builds a fake world with World.Seam.SeamLine and `count` points, with no parent. Point i sits at (i, 40, -i) and
-- points down (0, 0, -1), except the one named `noDown`, which has no Down attribute.
local function makeSeamWorld(count: number, noSeam: boolean?, noDown: string?): Folder
	local world = Instance.new("Folder")
	world.Name = "World"
	if noSeam then
		return world
	end
	local seam = Instance.new("Folder")
	seam.Name = "Seam"
	seam.Parent = world
	local line = Instance.new("Folder")
	line.Name = "SeamLine"
	line.Parent = seam
	for i = count, 1, -1 do -- built in reverse, so the sort is what puts them in order
		local part = Instance.new("Part")
		part.Name = `Line_Test_{string.format("%02d", i)}`
		part.Position = Vector3.new(i, 40, -i)
		if part.Name ~= noDown then
			part:SetAttribute("Down", Vector3.new(0, 0, -1))
		end
		part.Parent = line
	end
	return world
end

describe("SeamLineReader", function()
	it("reads 3 points with their positions and Down, sorted by name", function()
		local world = makeSeamWorld(3)
		local points, problems = WorldIndex.readSeamLine(world)
		expect(#problems).toBe(0)
		expect(points ~= nil and #points).toBe(3)
		local list = points :: { WorldIndex.SeamPoint }
		expect(list[1].position).toEqual(Vector3.new(1, 40, -1))
		expect(list[3].position).toEqual(Vector3.new(3, 40, -3))
		expect(list[2].down).toEqual(Vector3.new(0, 0, -1))
		world:Destroy()
	end)

	it("says the world is missing Seam", function()
		local world = makeSeamWorld(3, true)
		local points, problems = WorldIndex.readSeamLine(world)
		expect(points).toBe(nil)
		expect(problems).toEqual({ "World is missing Seam" })
		world:Destroy()
	end)

	it("names a point that has no Down", function()
		local world = makeSeamWorld(3, false, "Line_Test_02")
		local points, problems = WorldIndex.readSeamLine(world)
		expect(points).toBe(nil)
		expect(problems).toEqual({ "SeamLine.Line_Test_02 has no Down (a Vector3)" })
		world:Destroy()
	end)

	it("says SeamLine is empty", function()
		local world = makeSeamWorld(0)
		local _, problems = WorldIndex.readSeamLine(world)
		expect(problems).toEqual({ "SeamLine is empty" })
		world:Destroy()
	end)

	it("reads 52 points from the real world, each Down of length 1", function()
		local world = workspace:FindFirstChild("World")
		expect(world ~= nil).toBe(true)
		local points, problems = WorldIndex.readSeamLine(world :: Instance)
		expect(#problems).toBe(0)
		local list = points :: { WorldIndex.SeamPoint }
		expect(#list).toBe(52)
		local worst = 0
		for _, point in list do
			worst = math.max(worst, math.abs(point.down.Magnitude - 1))
		end
		expect(worst < 0.01).toBe(true)
	end)
end)
