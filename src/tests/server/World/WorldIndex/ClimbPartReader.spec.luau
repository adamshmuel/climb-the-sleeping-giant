--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)

type Ladder = WorldIndex.Ladder

local MODELS = { "BeardLadder", "CapLadder", "BootLadder_Left", "BootLadder_Right" }
local ROUTE_POINTS = { "RoutePoint_LadderLeft_Foot", "RoutePoint_LadderRight_Foot" }

-- Builds a fake world: World.WalkSurfaces.<model>.Climb (an upright 10-stud TrussPart centred at (x, 20, 0)) for each
-- name in `models`, and World.Route with the two ladder foot points on the grass 3 studs out from the boot ladders.
local function makeWorld(models: { string }): Folder
	local world = Instance.new("Folder")
	world.Name = "World"
	local surfaces = Instance.new("Folder")
	surfaces.Name = "WalkSurfaces"
	surfaces.Parent = world
	for index, name in models do
		local model = Instance.new("Model")
		model.Name = name
		local truss = Instance.new("TrussPart")
		truss.Name = "Climb"
		truss.Size = Vector3.new(2, 2, 10)
		truss.CFrame = CFrame.new(index * 10, 20, 0) * CFrame.Angles(math.rad(90), 0, 0)
		truss.Anchored = true
		truss.Parent = model
		model.Parent = surfaces
	end
	local route = Instance.new("Folder")
	route.Name = "Route"
	route.Parent = world
	for _, name in ROUTE_POINTS do
		local point = Instance.new("Part")
		point.Name = name
		point.Position = if string.find(name, "Left", 1, true) ~= nil
			then Vector3.new(33, 2, 0)
			else Vector3.new(43, 2, 0)
		point.Parent = route
	end
	return world
end

local function byName(ladders: { Ladder }): { [string]: Ladder }
	local map: { [string]: Ladder } = {}
	for _, ladder in ladders do
		map[ladder.name] = ladder
	end
	return map
end

local function close(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 0.01
end

describe("ClimbPartReader", function()
	it("reads four ladders with their kind, foot and top, and the ground of the boot ones", function()
		local world = makeWorld(MODELS)
		local ladders, problems = WorldIndex.readClimbParts(world)
		expect(problems).toEqual({})
		local list = ladders :: { Ladder }
		expect(#list).toBe(4)
		local map = byName(list)
		local beard = map["BeardLadder"]
		expect(beard.kind).toBe("head")
		expect(close(beard.foot, Vector3.new(10, 15, 0))).toBe(true)
		expect(close(beard.top, Vector3.new(10, 25, 0))).toBe(true)
		expect(beard.ground).toBe(nil)
		expect(map["CapLadder"].kind).toBe("head")
		local left = map["BootLadder_Left"]
		expect(left.kind).toBe("boot")
		expect(close(left.foot, Vector3.new(30, 15, 0))).toBe(true)
		expect(close(left.top, Vector3.new(30, 25, 0))).toBe(true)
		expect(close(left.ground :: Vector3, Vector3.new(33, 2, 0))).toBe(true)
		expect(close(map["BootLadder_Right"].ground :: Vector3, Vector3.new(43, 2, 0))).toBe(true)
		world:Destroy()
	end)

	it("names a missing ladder model", function()
		local world = makeWorld({ "BeardLadder", "CapLadder", "BootLadder_Left" })
		local ladders, problems = WorldIndex.readClimbParts(world)
		expect(ladders).toBe(nil)
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "BootLadder_Right", 1, true) ~= nil).toBe(true)
		world:Destroy()
	end)

	it("reads the real world: two head and two boot ladders, each boot ground near its foot", function()
		local world = Workspace:FindFirstChild("World")
		expect(world ~= nil).toBe(true)
		local ladders, problems = WorldIndex.readClimbParts(world :: Instance)
		expect(problems).toEqual({})
		local list = ladders :: { Ladder }
		expect(#list).toBe(4)
		local heads, boots = 0, 0
		for _, ladder in list do
			if ladder.kind == "head" then
				heads += 1
			else
				boots += 1
				local ground = ladder.ground :: Vector3
				local flat = Vector3.new(ground.X - ladder.foot.X, 0, ground.Z - ladder.foot.Z)
				expect(flat.Magnitude <= 8).toBe(true)
			end
		end
		expect(heads).toBe(2)
		expect(boots).toBe(2)
		local surfaces = (world :: Instance):FindFirstChild("WalkSurfaces") :: Instance
		for _, name in MODELS do
			local climb = (surfaces:FindFirstChild(name) :: Instance):FindFirstChild("Climb") :: BasePart
			expect(climb.CanCollide).toBe(true)
		end
	end)
end)

-- Adds World.LadderBoxes to a fake world: one box per entry, each with the given attributes (a nil one is left off).
local function addLadderBoxes(world: Folder, entries: { { name: string, ladder: string?, zone: string? } })
	local folder = Instance.new("Folder")
	folder.Name = "LadderBoxes"
	folder.Parent = world
	for _, entry in entries do
		local box = Instance.new("Part")
		box.Name = entry.name
		box.Size = Vector3.new(6, 6, 36)
		box.CFrame = CFrame.new(10, 20, 0)
		box:SetAttribute("Ladder", entry.ladder)
		box:SetAttribute("Zone", entry.zone)
		box.Parent = folder
	end
end

local function hasLine(problems: { string }, ...: string): boolean
	for _, line in problems do
		local all = true
		for _, part in { ... } do
			if string.find(line, part, 1, true) == nil then
				all = false
			end
		end
		if all then
			return true
		end
	end
	return false
end

describe("readLadders", function()
	it("names each missing ladder model, Climb part and attribute", function()
		local world = makeWorld({ "BeardLadder", "CapLadder", "BootLadder_Left" })
		-- CapLadder keeps its model but loses its Climb part
		local capModel = (world:FindFirstChild("WalkSurfaces") :: Instance):FindFirstChild("CapLadder") :: Instance
		local capClimb = capModel:FindFirstChild("Climb") :: Instance
		capClimb:Destroy()
		addLadderBoxes(world, {
			{ name = "LadderBox_NoLadder", ladder = nil, zone = "Boots" },
			{ name = "LadderBox_NoZone", ladder = "BeardLadder", zone = nil },
			{ name = "LadderBox_BadZone", ladder = "BeardLadder", zone = "Attic" },
			{ name = "LadderBox_NoModel", ladder = "BootLadder_Right", zone = "Boots" },
			{ name = "LadderBox_NoClimb", ladder = "CapLadder", zone = "Beard" },
		})
		local boxes, problems = WorldIndex.readLadders(world)
		expect(boxes).toBe(nil)
		expect(#problems).toBe(5)
		expect(hasLine(problems, "LadderBox_NoLadder", "Ladder")).toBe(true)
		expect(hasLine(problems, "LadderBox_NoZone", "Zone")).toBe(true)
		expect(hasLine(problems, "LadderBox_BadZone", "Attic")).toBe(true)
		expect(hasLine(problems, "BootLadder_Right")).toBe(true)
		expect(hasLine(problems, "CapLadder", "Climb")).toBe(true)
		local noFolder = makeWorld(MODELS)
		local none, noFolderProblems = WorldIndex.readLadders(noFolder)
		expect(none).toBe(nil)
		expect(hasLine(noFolderProblems, "LadderBoxes")).toBe(true)
		world:Destroy()
		noFolder:Destroy()
	end)

	it("readLadders finds the 4 real ladder boxes", function()
		local world = Workspace:FindFirstChild("World") :: Instance
		local boxes, problems = WorldIndex.readLadders(world)
		expect(problems).toEqual({})
		local list = boxes :: { Zones.LadderBox }
		expect(#list).toBe(4)
		local folder = world:FindFirstChild("LadderBoxes") :: Instance
		for _, box in list do
			local found = folder:FindFirstChild("LadderBox_" .. box.ladder)
			expect(found).never.toBeNil()
			local part = found :: BasePart
			expect(box.zone).toBe(part:GetAttribute("Zone"))
			expect(box.size).toBe(part.Size)
			expect(box.cframe).toBe(part.CFrame)
		end
	end)
end)
