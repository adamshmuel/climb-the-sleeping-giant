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

-- Builds a fake world that only has WalkSurfaces with the climb pieces named in `names`, with no parent.
local function makeClimbWorld(names: { string }): Folder
	local world = Instance.new("Folder")
	world.Name = "World"
	local walk = Instance.new("Folder")
	walk.Name = "WalkSurfaces"
	walk.Parent = world
	for _, name in names do
		local piece: Instance = if name == "SteepGuards" then Instance.new("Folder") else Instance.new("Part")
		piece.Name = name
		piece.Parent = walk
	end
	return world
end

describe("WorldIndex.readClimb", function()
	it("reads the climb pieces", function()
		local world = makeClimbWorld({ "RightBootRamp", "RightBoots_Walk", "SteepGuards", "BootRamp" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(problems).toEqual({})
		expect(climb).never.toBeNil()
		local pieces = climb :: WorldIndex.Climb
		expect(pieces.rightRamp.Name).toBe("RightBootRamp")
		expect(pieces.rightBootsWalk.Name).toBe("RightBoots_Walk")
		expect(pieces.steepGuards.Name).toBe("SteepGuards")
		world:Destroy()
	end)

	it("reports a missing right boot ramp", function()
		local world = makeClimbWorld({ "RightBoots_Walk", "SteepGuards" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(climb).toBeNil()
		expect(problems).toEqual({ "WalkSurfaces is missing RightBootRamp" })
		world:Destroy()
	end)

	it("reports a missing right boots path", function()
		local world = makeClimbWorld({ "RightBootRamp", "SteepGuards" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(climb).toBeNil()
		expect(problems).toEqual({ "WalkSurfaces is missing RightBoots_Walk" })
		world:Destroy()
	end)

	it("reports missing steep guards", function()
		local world = makeClimbWorld({ "RightBootRamp", "RightBoots_Walk" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(climb).toBeNil()
		expect(problems).toEqual({ "WalkSurfaces is missing SteepGuards" })
		world:Destroy()
	end)

	it("reports every missing piece, and a missing WalkSurfaces", function()
		local bare = makeClimbWorld({})
		local _, problems = WorldIndex.readClimb(bare)
		expect(problems).toEqual({
			"WalkSurfaces is missing RightBootRamp",
			"WalkSurfaces is missing RightBoots_Walk",
			"WalkSurfaces is missing SteepGuards",
		})
		bare:Destroy()
		local empty = Instance.new("Folder")
		local _, noWalkProblems = WorldIndex.readClimb(empty)
		expect(noWalkProblems).toEqual({ "World is missing WalkSurfaces" })
		empty:Destroy()
	end)
end)

describe("WorldIndex.loadClimb", function()
	it("returns the pieces of a good world, and errors with every problem of a bad one", function()
		local good = makeClimbWorld({ "RightBootRamp", "RightBoots_Walk", "SteepGuards" })
		expect(WorldIndex.loadClimb(good).steepGuards.Name).toBe("SteepGuards")
		good:Destroy()
		local bad = makeClimbWorld({ "RightBootRamp" })
		local ok, message = pcall(WorldIndex.loadClimb, bad)
		expect(ok).toBe(false)
		expect(message).toBe("WalkSurfaces is missing RightBoots_Walk\nWalkSurfaces is missing SteepGuards")
		bad:Destroy()
	end)
end)

-- Builds a fake world that only has EggSpots, with no parent. The spots are the 16 that the real world has:
-- 8 Common, 4 Uncommon and 4 Rare. Each is a Model with a Rarity, a Base and a PromptAnchor.
type SpotOptions = {
	skip: { string }?, -- spot names to leave out
	noRarity: { string }?, -- spot names built without the Rarity attribute
	rarity: { [string]: string }?, -- spot name -> Rarity value to write instead of the right one
	noBase: { string }?,
	noAnchor: { string }?,
	wrongBaseClass: { [string]: string }?, -- spot name -> class to build the Base as
	wrongAnchorClass: { [string]: string }?,
}

local function contains(list: { string }?, name: string): boolean
	return list ~= nil and table.find(list, name) ~= nil
end

local function makeSpotsWorld(options: SpotOptions?): Folder
	local opts: SpotOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	local folder = Instance.new("Folder")
	folder.Name = "EggSpots"
	folder.Parent = world
	local counts = { Common = 8, Uncommon = 4, Rare = 4 }
	local order = { "Common", "Uncommon", "Rare" }
	local number = 0
	for _, rarity in order do
		for index = counts[rarity], 1, -1 do -- built backwards on purpose: the reader must sort by name
			number += 1
			local name = `EggSpot_{rarity}_{index}`
			if contains(opts.skip, name) then
				continue
			end
			local spot = Instance.new("Model")
			spot.Name = name
			if not contains(opts.noRarity, name) then
				local written = if opts.rarity then opts.rarity[name] else nil
				spot:SetAttribute("Rarity", written or rarity)
			end
			if not contains(opts.noBase, name) then
				local baseClass = if opts.wrongBaseClass then opts.wrongBaseClass[name] else nil
				local base = Instance.new((baseClass or "Part") :: any)
				base.Name = "Base"
				if base:IsA("BasePart") then
					base.Size = Vector3.new(2, 0.2, 2)
					base.CFrame = CFrame.new(number * 10, 5, 0)
				end
				base.Parent = spot
				if not contains(opts.noAnchor, name) then
					local anchorClass = if opts.wrongAnchorClass then opts.wrongAnchorClass[name] else nil
					local anchor = Instance.new((anchorClass or "Attachment") :: any)
					anchor.Name = "PromptAnchor"
					anchor.Parent = base
				end
			end
			spot.Parent = folder
		end
	end
	return world
end

describe("WorldIndex.readEggSpots", function()
	it("reads 16 egg spots with the right rarities, in name order", function()
		local world = makeSpotsWorld()
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(problems).toEqual({})
		expect(spots).never.toBeNil()
		local list = spots :: { WorldIndex.EggSpot }
		expect(#list).toBe(16)
		local counts = { Common = 0, Uncommon = 0, Rare = 0 }
		local names: { string } = {}
		for _, spot in list do
			counts[spot.rarity] += 1
			table.insert(names, spot.name)
		end
		expect(counts).toEqual({ Common = 8, Uncommon = 4, Rare = 4 })
		local sorted = table.clone(names)
		table.sort(sorted)
		expect(names).toEqual(sorted)
		expect(list[1].name).toBe("EggSpot_Common_1")
		world:Destroy()
	end)

	it("gives each spot its model, the top centre of its Base and its prompt anchor", function()
		local world = makeSpotsWorld()
		local list = WorldIndex.loadEggSpots(world)
		local folder = (world :: any).EggSpots
		for _, spot in list do
			local model = folder[spot.name]
			expect(spot.model).toBe(model)
			expect(spot.promptAnchor).toBe(model.Base.PromptAnchor)
			-- the Base is 0.2 thick, so its top centre is 0.1 above its middle
			expect(spot.cframe).toEqual(model.Base.CFrame * CFrame.new(0, 0.1, 0))
		end
		world:Destroy()
	end)

	it("reports a missing EggSpots folder", function()
		local world = Instance.new("Folder")
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "World is missing EggSpots" })
		world:Destroy()
	end)

	it("reports a spot with no Rarity", function()
		local world = makeSpotsWorld({ noRarity = { "EggSpot_Rare_2" } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "EggSpots.EggSpot_Rare_2 has no Rarity" })
		world:Destroy()
	end)

	it("reports a spot with a Rarity that is not Common, Uncommon or Rare", function()
		local world = makeSpotsWorld({ rarity = { EggSpot_Uncommon_1 = "Epic" } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ 'EggSpots.EggSpot_Uncommon_1 has an unknown Rarity "Epic"' })
		world:Destroy()
	end)

	it("reports a spot with no Base", function()
		local world = makeSpotsWorld({ noBase = { "EggSpot_Common_3" } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "EggSpots.EggSpot_Common_3 is missing Base" })
		world:Destroy()
	end)

	it("reports a spot with no PromptAnchor", function()
		local world = makeSpotsWorld({ noAnchor = { "EggSpot_Common_3" } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "EggSpots.EggSpot_Common_3 is missing PromptAnchor" })
		world:Destroy()
	end)

	it("reports a Base or a PromptAnchor of the wrong class", function()
		local world = makeSpotsWorld({
			wrongBaseClass = { EggSpot_Rare_1 = "Folder" },
			wrongAnchorClass = { EggSpot_Rare_3 = "Part" },
		})
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({
			"EggSpots.EggSpot_Rare_1.Base must be a BasePart, not a Folder",
			"EggSpots.EggSpot_Rare_3.PromptAnchor must be an Attachment, not a Part",
		})
		world:Destroy()
	end)

	it("reports a child of EggSpots that is not a Model", function()
		local world = makeSpotsWorld()
		local extra = Instance.new("Part")
		extra.Name = "Foo"
		extra.Parent = (world :: any).EggSpots
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "EggSpots.Foo must be a Model, not a Part" })
		world:Destroy()
	end)

	it("reports the wrong number of spots of each rarity", function()
		local world = makeSpotsWorld({ skip = { "EggSpot_Uncommon_4" } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "EggSpots needs 8 Common, 4 Uncommon and 4 Rare spots, found 8, 3, 4" })
		world:Destroy()
	end)

	it("reports every problem, one per line, in name order", function()
		local world = makeSpotsWorld({
			noBase = { "EggSpot_Common_3" },
			noAnchor = { "EggSpot_Common_1" },
			skip = { "EggSpot_Rare_4", "EggSpot_Rare_3" },
		})
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({
			"EggSpots.EggSpot_Common_1 is missing PromptAnchor",
			"EggSpots.EggSpot_Common_3 is missing Base",
			"EggSpots needs 8 Common, 4 Uncommon and 4 Rare spots, found 8, 4, 2",
		})
		world:Destroy()
	end)
end)

describe("WorldIndex.loadEggSpots", function()
	it("returns the 16 spots of a good world, and errors with every problem of a bad one", function()
		local good = makeSpotsWorld()
		expect(#WorldIndex.loadEggSpots(good)).toBe(16)
		good:Destroy()

		local bad = makeSpotsWorld({ noRarity = { "EggSpot_Rare_2" }, noBase = { "EggSpot_Common_3" } })
		local ok, message = pcall(WorldIndex.loadEggSpots, bad)
		expect(ok).toBe(false)
		expect(message).toBe("EggSpots.EggSpot_Common_3 is missing Base\nEggSpots.EggSpot_Rare_2 has no Rarity")
		bad:Destroy()
	end)
end)

-- Builds a fake ServerStorage.Assets (no parent) with Eggs holding the templates named in `names`.
-- `skipEggs` leaves the Eggs folder out; `wrongClass` builds a template as a Part.
local function makeAssets(names: { string }, skipEggs: boolean?, wrongClass: string?): Folder
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	if skipEggs then
		return assets
	end
	local eggs = Instance.new("Folder")
	eggs.Name = "Eggs"
	eggs.Parent = assets
	for _, name in names do
		local template: Instance = if name == wrongClass then Instance.new("Part") else Instance.new("Model")
		template.Name = name
		template.Parent = eggs
	end
	return assets
end

describe("WorldIndex.readEggTemplates", function()
	it("reads the Common, Uncommon and Rare egg models", function()
		local assets = makeAssets({ "Rare", "Common", "Uncommon" })
		local templates, problems = WorldIndex.readEggTemplates(assets)
		expect(problems).toEqual({})
		expect(templates).never.toBeNil()
		local found = templates :: WorldIndex.EggTemplates
		expect(found.Common).toBe((assets :: any).Eggs.Common)
		expect(found.Uncommon).toBe((assets :: any).Eggs.Uncommon)
		expect(found.Rare).toBe((assets :: any).Eggs.Rare)
		assets:Destroy()
	end)

	it("reports a missing Eggs folder", function()
		local assets = makeAssets({}, true)
		local templates, problems = WorldIndex.readEggTemplates(assets)
		expect(templates).toBeNil()
		expect(problems).toEqual({ "Assets is missing Eggs" })
		assets:Destroy()
	end)

	it("reports each missing template and each of the wrong class", function()
		local assets = makeAssets({ "Common", "Rare" }, false, "Rare")
		local templates, problems = WorldIndex.readEggTemplates(assets)
		expect(templates).toBeNil()
		expect(problems).toEqual({
			"Assets.Eggs is missing Uncommon",
			"Assets.Eggs.Rare must be a Model, not a Part",
		})
		assets:Destroy()
	end)
end)

describe("WorldIndex.loadEggTemplates", function()
	it("returns the templates of good assets, and errors with every problem of bad ones", function()
		local good = makeAssets({ "Common", "Uncommon", "Rare" })
		expect(WorldIndex.loadEggTemplates(good).Rare.Name).toBe("Rare")
		good:Destroy()
		local bad = makeAssets({ "Uncommon" })
		local ok, message = pcall(WorldIndex.loadEggTemplates, bad)
		expect(ok).toBe(false)
		expect(message).toBe("Assets.Eggs is missing Common\nAssets.Eggs is missing Rare")
		bad:Destroy()
	end)
end)

-- Builds a fake world that only has a Route (Task 23) with a few points, with no parent. The route is a Model that
-- always streams to players, like the real one.
type RouteOptions = {
	noRoute: boolean?,
	routeClass: string?, -- build the Route as this class instead of a Model
	streaming: Enum.ModelStreamingMode?, -- instead of Persistent
	brokenLink: boolean?, -- the second point lists a neighbour that does not exist
}

local function makeRouteWorld(options: RouteOptions?): Folder
	local opts: RouteOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	if opts.noRoute then
		return world
	end
	local route: Instance = Instance.new((opts.routeClass or "Model") :: any)
	route.Name = "Route"
	if route:IsA("Model") then
		route.ModelStreamingMode = opts.streaming or Enum.ModelStreamingMode.Persistent
	end
	route.Parent = world
	local entries: { { name: string, top: Vector3, neighbours: string, target: string } } = {
		{
			name = "RoutePoint_Spawn_1",
			top = Vector3.new(0, 2, 0),
			neighbours = "RoutePoint_Egg_Common_1",
			target = "Spawn_1",
		},
		{
			name = "RoutePoint_Egg_Common_1",
			top = Vector3.new(20, 2, 0),
			neighbours = if opts.brokenLink then "RoutePoint_Spawn_1,RoutePoint_Nowhere" else "RoutePoint_Spawn_1",
			target = "EggSpot_Common_1",
		},
	}
	for _, entry in entries do
		local point = Instance.new("Part")
		point.Name = entry.name
		point.Size = Vector3.new(1, 0.2, 1)
		point.CFrame = CFrame.new(entry.top - Vector3.new(0, 0.1, 0))
		point:SetAttribute("Neighbours", entry.neighbours)
		point:SetAttribute("Target", entry.target)
		point.Parent = route
	end
	return world
end

describe("WorldIndex.readRoute", function()
	it("reads the route points: names, top centres, neighbours and targets", function()
		local world = makeRouteWorld()
		local points, problems = WorldIndex.readRoute(world)
		expect(problems).toEqual({})
		expect(points).never.toBeNil()
		local list = points :: { WorldIndex.RoutePoint }
		expect(#list).toBe(2)
		expect(list[1].name).toBe("RoutePoint_Egg_Common_1")
		expect(list[1].position).toEqual(Vector3.new(20, 2, 0))
		expect(list[1].neighbours).toEqual({ "RoutePoint_Spawn_1" })
		expect(list[1].target).toBe("EggSpot_Common_1")
		world:Destroy()
	end)

	it("reports a missing Route", function()
		local world = makeRouteWorld({ noRoute = true })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({ "World is missing Route" })
		world:Destroy()
	end)

	it("reports a Route that is not a Model", function()
		local world = makeRouteWorld({ routeClass = "Folder" })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({ "World.Route must be a Model, not a Folder" })
		world:Destroy()
	end)

	it("reports a Route that does not always stream to players", function()
		local world = makeRouteWorld({ streaming = Enum.ModelStreamingMode.Default })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({ "World.Route must have ModelStreamingMode Persistent, not Default" })
		world:Destroy()
	end)

	it("reports the problems that RouteData finds in the points", function()
		local world = makeRouteWorld({ brokenLink = true })
		local points, problems = WorldIndex.readRoute(world)
		expect(points).toBeNil()
		expect(problems).toEqual({
			"RoutePoint_Egg_Common_1 lists RoutePoint_Nowhere as a neighbour, but there is no such point",
		})
		world:Destroy()
	end)
end)

describe("WorldIndex.loadRoute", function()
	it("returns the points of a good world, and errors with every problem of a bad one", function()
		local good = makeRouteWorld()
		expect(#WorldIndex.loadRoute(good)).toBe(2)
		good:Destroy()
		local bad = makeRouteWorld({ brokenLink = true, streaming = Enum.ModelStreamingMode.Atomic })
		local ok, message = pcall(WorldIndex.loadRoute, bad)
		expect(ok).toBe(false)
		expect(message).toBe(
			"World.Route must have ModelStreamingMode Persistent, not Atomic\n"
				.. "RoutePoint_Egg_Common_1 lists RoutePoint_Nowhere as a neighbour, but there is no such point"
		)
		bad:Destroy()
		local noRoute = makeRouteWorld({ noRoute = true })
		local okMissing, missingMessage = pcall(WorldIndex.loadRoute, noRoute)
		expect(okMissing).toBe(false)
		expect(missingMessage).toBe("World is missing Route")
		noRoute:Destroy()
	end)
end)

-- Builds a fake world that only has LandingSpots (Task 23): spots 1 to 8, with no parent.
type LandingOptions = {
	skip: { number }?, -- spot numbers to leave out
	wrongClass: { [number]: string }?, -- spot number -> class to build it as
	extra: { string }?, -- names of unexpected children to add
	noFolder: boolean?,
}

local function makeLandingWorld(options: LandingOptions?): Folder
	local opts: LandingOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	if opts.noFolder then
		return world
	end
	local folder = Instance.new("Folder")
	folder.Name = "LandingSpots"
	folder.Parent = world
	for number = 8, 1, -1 do -- built backwards on purpose: the reader must give them back in order
		if opts.skip and table.find(opts.skip, number) then
			continue
		end
		local className = if opts.wrongClass and opts.wrongClass[number] then opts.wrongClass[number] else "Part"
		local spot = Instance.new(className :: any)
		spot.Name = `LandingSpot_{number}`
		if spot:IsA("BasePart") then
			spot.Size = Vector3.new(1, 0.2, 1)
			spot.CFrame = CFrame.new(number * 12, 1.9, -70) -- its top centre is 0.1 higher
		end
		spot.Parent = folder
	end
	local extra: { string } = opts.extra or {}
	for _, name in extra do
		local stray = Instance.new("Part")
		stray.Name = name
		stray.Parent = folder
	end
	return world
end

describe("WorldIndex.readLandingSpots", function()
	it("reads the 8 landing spots in order, each with the top centre of its part", function()
		local world = makeLandingWorld()
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(problems).toEqual({})
		expect(spots).never.toBeNil()
		local list = spots :: { WorldIndex.LandingSpot }
		expect(#list).toBe(8)
		for number, spot in list do
			expect(spot.index).toBe(number)
			expect(spot.position).toEqual(Vector3.new(number * 12, 2, -70))
		end
		world:Destroy()
	end)

	it("reports the missing spot when there are only 7", function()
		local world = makeLandingWorld({ skip = { 5 } })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "LandingSpots is missing LandingSpot_5" })
		world:Destroy()
	end)

	it("reports a spot of the wrong class", function()
		local world = makeLandingWorld({ wrongClass = { [3] = "Folder" } })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "LandingSpots.LandingSpot_3 must be a BasePart, not a Folder" })
		world:Destroy()
	end)

	it("reports a missing LandingSpots folder", function()
		local world = makeLandingWorld({ noFolder = true })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "World is missing LandingSpots" })
		world:Destroy()
	end)

	it("reports a child that is not one of the 8 spots", function()
		local world = makeLandingWorld({ extra = { "LandingSpot_9", "Stray" } })
		local spots, problems = WorldIndex.readLandingSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({
			"LandingSpots has an unexpected child LandingSpot_9",
			"LandingSpots has an unexpected child Stray",
		})
		world:Destroy()
	end)
end)

describe("WorldIndex.loadLandingSpots", function()
	it("returns the spots of a good world, and errors with every problem of a bad one", function()
		local good = makeLandingWorld()
		expect(#WorldIndex.loadLandingSpots(good)).toBe(8)
		good:Destroy()
		local bad = makeLandingWorld({ skip = { 2, 7 } })
		local ok, message = pcall(WorldIndex.loadLandingSpots, bad)
		expect(ok).toBe(false)
		expect(message).toBe("LandingSpots is missing LandingSpot_2\nLandingSpots is missing LandingSpot_7")
		bad:Destroy()
	end)
end)

-- Builds a fake world that only has Giant.SleepEyes (Task 27): a Model whose pivot is the point the eyes look from.
type FaceOptions = {
	noGiant: boolean?,
	noEyes: boolean?,
	eyesClass: string?,
}

local function makeFaceWorld(options: FaceOptions?): Folder
	local opts: FaceOptions = options or {}
	local world = Instance.new("Folder")
	world.Name = "World"
	if opts.noGiant then
		return world
	end
	local giant = Instance.new("Model")
	giant.Name = "Giant"
	giant.Parent = world
	if not opts.noEyes then
		local eyes = Instance.new((opts.eyesClass or "Model") :: any) :: Instance
		eyes.Name = "SleepEyes"
		if eyes:IsA("Model") then
			local part = Instance.new("Part")
			part.CFrame = CFrame.new(0.95, 95.3, 0.01)
			part.Parent = eyes
			eyes.PrimaryPart = part
			eyes:PivotTo(CFrame.new(0.95, 95.3, 0.01))
		end
		eyes.Parent = giant
	end
	return world
end

describe("WorldIndex.loadGiantFace", function()
	it("returns the pivot position of Giant.SleepEyes", function()
		local world = makeFaceWorld()
		local face = WorldIndex.loadGiantFace(world)
		expect(face.X).toBeCloseTo(0.95, 3)
		expect(face.Y).toBeCloseTo(95.3, 3)
		expect(face.Z).toBeCloseTo(0.01, 3)
		world:Destroy()
	end)

	it("stops the server with a clear message when the Giant is missing", function()
		local world = makeFaceWorld({ noGiant = true })
		local ok, message = pcall(WorldIndex.loadGiantFace, world)
		expect(ok).toBe(false)
		expect(message).toBe("World is missing Giant")
		world:Destroy()
	end)

	it("stops the server with a clear message when SleepEyes is missing", function()
		local world = makeFaceWorld({ noEyes = true })
		local ok, message = pcall(WorldIndex.loadGiantFace, world)
		expect(ok).toBe(false)
		expect(message).toBe("Giant is missing SleepEyes")
		world:Destroy()
	end)

	it("stops the server with a clear message when SleepEyes is not a Model", function()
		local world = makeFaceWorld({ eyesClass = "Folder" })
		local ok, message = pcall(WorldIndex.loadGiantFace, world)
		expect(ok).toBe(false)
		expect(message).toBe("Giant.SleepEyes must be a Model, not a Folder")
		world:Destroy()
	end)
end)
