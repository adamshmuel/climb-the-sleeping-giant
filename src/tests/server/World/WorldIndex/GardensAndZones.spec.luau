--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

type PlotOptions = {
	missing: { string }?, -- paths left out of the plot, for example "SpawnSpot" or "Dressing.PetPad4"
	wrongClass: { [string]: string }?, -- path -> class to build instead, for example SpawnSpot = "Part"
}

-- What every complete plot holds: path, class.
local function plotParts(): { { string } }
	local parts = {
		{ "SafeGate", "Model" },
		{ "SafeGate.SignFace", "Part" },
		{ "SafeGate.SignFace.SurfaceGui", "SurfaceGui" },
		{ "SafeGate.SignFace.SurfaceGui.TextLabel", "TextLabel" },
		{ "SafeGate.SignFaceBack", "Part" },
		{ "SafeGate.SignFaceBack.SurfaceGui", "SurfaceGui" },
		{ "SafeGate.SignFaceBack.SurfaceGui.TextLabel", "TextLabel" },
		{ "SpawnSpot", "SpawnLocation" },
		{ "GardenVolume", "Part" },
		{ "Dressing", "Folder" },
		{ "Dressing.Incubator1", "Model" },
	}
	for pad = 1, 6 do
		table.insert(parts, { `Dressing.PetPad{pad}`, "Model" })
	end
	-- The 12 home spots (Task 38), made from 12 down to 1 on purpose: the reader must give them back in order.
	table.insert(parts, { "HomeSpots", "Folder" })
	for spot = 12, 1, -1 do
		table.insert(parts, { `HomeSpots.HomeSpot_{spot}`, "Part" })
	end
	return parts
end

-- Builds one fake plot with no parent. Everything in it can be found by name.
local function makePlot(index: number, options: PlotOptions?): Model
	local missing: { [string]: boolean } = {}
	local wrongClass: { [string]: string } = {}
	if options then
		local missingPaths: { string } = options.missing or {}
		for _, path in missingPaths do
			missing[path] = true
		end
		wrongClass = options.wrongClass or wrongClass
	end

	local plot = Instance.new("Model")
	plot.Name = `Plot_{index}`
	for _, part in plotParts() do
		local path, className = part[1], part[2]
		-- Skip a piece that is missing, or that sits inside a missing piece.
		local skip = false
		local walked = ""
		for segment in string.gmatch(path, "[^.]+") do
			walked = if walked == "" then segment else walked .. "." .. segment
			if missing[walked] then
				skip = true
			end
		end
		if skip then
			continue
		end
		local instance = Instance.new((wrongClass[path] or className) :: any)
		local parent: Instance = plot
		local names: { string } = {}
		for segment in string.gmatch(path, "[^.]+") do
			table.insert(names, segment)
		end
		instance.Name = names[#names]
		for step = 1, #names - 1 do
			parent = parent:FindFirstChild(names[step]) :: Instance
		end
		instance.Parent = parent
		if path == "GardenVolume" and instance:IsA("BasePart") then
			instance.Size = Vector3.new(60 + index, 20, 70)
		end
	end
	return plot
end

-- Builds a fake world with no parent. Plots are created in order 8..1 on purpose.
local function makeWorld(plotOptions: { [number]: PlotOptions }?, plotCount: number?): Folder
	local world = Instance.new("Folder")
	world.Name = "World"
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = world
	for index = plotCount or 8, 1, -1 do
		makePlot(index, plotOptions and plotOptions[index]).Parent = plots
	end
	return world
end

describe("WorldIndex.readGardens", function()
	it("reads 8 complete gardens in number order", function()
		local world = makeWorld()
		local gardens, problems = WorldIndex.readGardens(world)
		expect(problems).toEqual({})
		expect(gardens).never.toBeNil()
		local list = gardens :: { WorldIndex.Garden }
		expect(#list).toBe(8)
		for index, garden in list do
			expect(garden.index).toBe(index)
		end
		local plot1 = (world :: any).Plots.Plot_1
		expect(list[1].gate).toBe(plot1.SafeGate)
		expect(list[1].spawnSpot).toBe(plot1.SpawnSpot)
		expect(list[1].incubator).toBe(plot1.Dressing.Incubator1)
		expect(#list[1].petPads).toBe(6)
		expect(#list[1].signLabels).toBe(2)
		expect(list[1].signLabels[1]).toBe(plot1.SafeGate.SignFace.SurfaceGui.TextLabel)
		expect(list[1].signLabels[2]).toBe(plot1.SafeGate.SignFaceBack.SurfaceGui.TextLabel)
		for pad = 1, 6 do
			expect(list[1].petPads[pad]).toBe(plot1.Dressing[`PetPad{pad}`])
		end
		expect(#list[1].homeSpots).toBe(12)
		expect(list[3].box.size).toEqual(Vector3.new(63, 20, 70))
		expect(list[3].box.cframe).toEqual((world :: any).Plots.Plot_3.GardenVolume.CFrame)
		world:Destroy()
	end)

	it("reports a garden with no spawn spot", function()
		local world = makeWorld({ [3] = { missing = { "SpawnSpot" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_3 is missing SpawnSpot" })
		world:Destroy()
	end)

	it("reports a wrong class", function()
		local world = makeWorld({ [2] = { wrongClass = { SpawnSpot = "Part" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_2.SpawnSpot must be a SpawnLocation, not a Part" })
		world:Destroy()
	end)

	it("reports a missing pet pad", function()
		local world = makeWorld({ [5] = { missing = { "Dressing.PetPad4" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_5 is missing Dressing.PetPad4" })
		world:Destroy()
	end)

	it("gives each garden its 12 home spots, in order", function()
		local world = makeWorld()
		local gardens = WorldIndex.loadGardens(world)
		for _, garden in gardens do
			local folder = (world :: any).Plots[`Plot_{garden.index}`].HomeSpots
			expect(#garden.homeSpots).toBe(12)
			for number = 1, 12 do
				expect(garden.homeSpots[number]).toBe(folder[`HomeSpot_{number}`])
			end
		end
		world:Destroy()
	end)

	it("reports a garden with no HomeSpots folder as one problem", function()
		local world = makeWorld({ [3] = { missing = { "HomeSpots" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_3 is missing HomeSpots" })
		world:Destroy()
	end)

	it("reports a missing home spot", function()
		local world = makeWorld({ [3] = { missing = { "HomeSpots.HomeSpot_7" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_3 is missing HomeSpots.HomeSpot_7" })
		world:Destroy()
	end)

	it("reports a home spot of the wrong class", function()
		local world = makeWorld({ [2] = { wrongClass = { ["HomeSpots.HomeSpot_5"] = "Folder" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_2.HomeSpots.HomeSpot_5 must be a BasePart, not a Folder" })
		world:Destroy()
	end)

	it("reports every missing home spot, in order", function()
		local world = makeWorld({ [6] = { missing = { "HomeSpots.HomeSpot_12", "HomeSpots.HomeSpot_1" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_6 is missing HomeSpots.HomeSpot_1", "Plot_6 is missing HomeSpots.HomeSpot_12" })
		world:Destroy()
	end)

	it("reports too few gardens", function()
		local world = makeWorld(nil, 7)
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plots has 7 gardens, needs 8" })
		world:Destroy()
	end)

	it("reports every problem, not just the first", function()
		local broken: { [number]: PlotOptions } = {
			[2] = { wrongClass = { SafeGate = "Part" } },
			[6] = { missing = { "GardenVolume", "Dressing.Incubator1" } },
		}
		local world = makeWorld(broken)
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({
			"Plot_2.SafeGate must be a Model, not a Part",
			"Plot_6 is missing GardenVolume",
			"Plot_6 is missing Dressing.Incubator1",
		})
		world:Destroy()
	end)

	it("reports a missing gate sign label", function()
		local broken: { [number]: PlotOptions } = {
			[3] = { missing = { "SafeGate.SignFaceBack.SurfaceGui.TextLabel" } },
		}
		local world = makeWorld(broken)
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_3 is missing SafeGate.SignFaceBack.SurfaceGui.TextLabel" })
		world:Destroy()
	end)

	it("reports a gate sign label of the wrong class", function()
		local broken: { [number]: PlotOptions } = {
			[6] = { wrongClass = { ["SafeGate.SignFace.SurfaceGui.TextLabel"] = "Frame" } },
		}
		local world = makeWorld(broken)
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_6.SafeGate.SignFace.SurfaceGui.TextLabel must be a TextLabel, not a Frame" })
		world:Destroy()
	end)

	it("reports a missing Plots folder", function()
		local world = Instance.new("Folder")
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "World is missing Plots" })
		world:Destroy()
	end)

	it("reports an unexpected child of Plots", function()
		local world = makeWorld()
		local extra = Instance.new("Folder")
		extra.Name = "Plot_9"
		extra.Parent = (world :: any).Plots
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plots has an unexpected child Plot_9" })
		world:Destroy()
	end)

	it("reports two plots with the same number", function()
		local world = makeWorld()
		local twin = Instance.new("Model")
		twin.Name = "Plot_2"
		twin.Parent = (world :: any).Plots
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plots has 2 children named Plot_2" })
		world:Destroy()
	end)

	it("reports a plot with no Dressing folder", function()
		local world = makeWorld({ [4] = { missing = { "Dressing" } } })
		local gardens, problems = WorldIndex.readGardens(world)
		expect(gardens).toBeNil()
		expect(problems).toEqual({ "Plot_4 is missing Dressing" })
		world:Destroy()
	end)
end)

describe("WorldIndex.loadGardens", function()
	it("returns the 8 gardens of a complete world", function()
		local world = makeWorld()
		local gardens = WorldIndex.loadGardens(world)
		expect(#gardens).toBe(8)
		world:Destroy()
	end)

	it("errors with all problems", function()
		local broken: { [number]: PlotOptions } = {
			[1] = { missing = { "SpawnSpot" } },
			[7] = { wrongClass = { GardenVolume = "Model" } },
		}
		local world = makeWorld(broken)
		local ok, message = pcall(WorldIndex.loadGardens, world)
		expect(ok).toBe(false)
		expect(message).toBe("Plot_1 is missing SpawnSpot\nPlot_7.GardenVolume must be a BasePart, not a Model")
		world:Destroy()
	end)
end)

-- Builds a fake world that only has a Zones folder, with no parent. Each entry is one box:
-- its name, its Zone attribute (nil leaves the attribute off) and the class to build.
type ZoneEntry = { name: string, zone: string?, className: string? }

local function defaultZoneEntries(): { ZoneEntry }
	return {
		{ name = "Boots_Ramp", zone = "Boots" },
		{ name = "Belly_Path", zone = "Belly" },
		{ name = "Beard_Ladder", zone = "Beard" },
		{ name = "Nightcap_Top", zone = "Nightcap" },
	}
end

local function makeZonesWorld(entries: { ZoneEntry }): Folder
	local world = Instance.new("Folder")
	world.Name = "World"
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = world
	for index, entry in entries do
		local box = Instance.new((entry.className or "Part") :: any)
		box.Name = entry.name
		if box:IsA("BasePart") then
			box.CFrame = CFrame.new(index * 10, 0, 0)
			box.Size = Vector3.new(index, 2, 3)
		end
		if entry.zone then
			box:SetAttribute("Zone", entry.zone)
		end
		box.Parent = zones
	end
	return world
end

describe("WorldIndex.readZones", function()
	it("reads the zone boxes", function()
		local world = makeZonesWorld(defaultZoneEntries())
		local boxes, problems = WorldIndex.readZones(world)
		expect(problems).toEqual({})
		expect(boxes).never.toBeNil()
		local list = boxes :: { any }
		expect(#list).toBe(4)
		local zonesSeen: { string } = {}
		for _, box in list do
			table.insert(zonesSeen, box.zone)
		end
		table.sort(zonesSeen)
		expect(zonesSeen).toEqual({ "Beard", "Belly", "Boots", "Nightcap" })
		-- Belly_Path is the 2nd entry: centre x = 20, size (2, 2, 3)
		for _, box in list do
			if box.zone == "Belly" then
				expect(box.cframe).toEqual(CFrame.new(20, 0, 0))
				expect(box.size).toEqual(Vector3.new(2, 2, 3))
			end
		end
		world:Destroy()
	end)

	it("reports a missing Zones folder", function()
		local world = Instance.new("Folder")
		local boxes, problems = WorldIndex.readZones(world)
		expect(boxes).toBeNil()
		expect(problems).toEqual({ "World is missing Zones" })
		world:Destroy()
	end)

	it("reports a zone with no box", function()
		local entries = defaultZoneEntries()
		table.remove(entries, 1) -- no Boots box
		table.remove(entries, 2) -- no Beard box (the list moved up by one)
		local world = makeZonesWorld(entries)
		local boxes, problems = WorldIndex.readZones(world)
		expect(boxes).toBeNil()
		expect(problems).toEqual({ "Zones has no Boots box", "Zones has no Beard box" })
		world:Destroy()
	end)

	it("reports a zone box of the wrong class", function()
		local entries = defaultZoneEntries()
		table.insert(entries, { name = "Foo", zone = "Belly", className = "Model" })
		local world = makeZonesWorld(entries)
		local boxes, problems = WorldIndex.readZones(world)
		expect(boxes).toBeNil()
		expect(problems).toEqual({ "Zones.Foo must be a BasePart, not a Model" })
		world:Destroy()
	end)

	it("reports an unknown Zone value, and a missing one", function()
		local entries = defaultZoneEntries()
		table.insert(entries, { name = "Foo", zone = "Sky" })
		table.insert(entries, { name = "NoAttribute", zone = nil })
		table.insert(entries, { name = "MeadowBox", zone = "Meadow" }) -- the Meadow is "in no box", so it is not allowed
		local world = makeZonesWorld(entries)
		local boxes, problems = WorldIndex.readZones(world)
		expect(boxes).toBeNil()
		expect(problems).toEqual({
			'Zones.Foo has an unknown Zone "Sky"',
			'Zones.MeadowBox has an unknown Zone "Meadow"',
			'Zones.NoAttribute has an unknown Zone "nil"',
		})
		world:Destroy()
	end)
end)

describe("WorldIndex.loadZones", function()
	it("returns the boxes of a good world, and errors with every problem of a bad one", function()
		local good = makeZonesWorld(defaultZoneEntries())
		expect(#WorldIndex.loadZones(good)).toBe(4)
		good:Destroy()

		local entries = defaultZoneEntries()
		table.remove(entries, 1) -- no Boots box
		table.insert(entries, { name = "Foo", zone = "Sky" })
		local bad = makeZonesWorld(entries)
		local ok, message = pcall(WorldIndex.loadZones, bad)
		expect(ok).toBe(false)
		expect(message).toBe('Zones.Foo has an unknown Zone "Sky"\nZones has no Boots box')
		bad:Destroy()
	end)
end)
