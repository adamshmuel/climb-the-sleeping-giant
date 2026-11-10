--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

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
		local world = makeClimbWorld({ "RightBootRamp", "SteepGuards", "BootRamp" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(problems).toEqual({})
		expect(climb).never.toBeNil()
		local pieces = climb :: WorldIndex.Climb
		expect(pieces.rightRamp.Name).toBe("RightBootRamp")
		expect(pieces.steepGuards.Name).toBe("SteepGuards")
		world:Destroy()
	end)

	-- Stuck safety Task 24 took V1's invisible walk pieces off the right boot top: players walk on his skin there.
	it("does not ask for a RightBoots_Walk piece", function()
		local world = makeClimbWorld({ "RightBootRamp", "SteepGuards" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(problems).toEqual({})
		expect(climb).never.toBeNil()
		world:Destroy()
	end)

	it("reports a missing right boot ramp", function()
		local world = makeClimbWorld({ "SteepGuards" })
		local climb, problems = WorldIndex.readClimb(world)
		expect(climb).toBeNil()
		expect(problems).toEqual({ "WalkSurfaces is missing RightBootRamp" })
		world:Destroy()
	end)

	it("reports missing steep guards", function()
		local world = makeClimbWorld({ "RightBootRamp" })
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
		local good = makeClimbWorld({ "RightBootRamp", "SteepGuards" })
		expect(WorldIndex.loadClimb(good).steepGuards.Name).toBe("SteepGuards")
		good:Destroy()
		local bad = makeClimbWorld({})
		local ok, message = pcall(WorldIndex.loadClimb, bad)
		expect(ok).toBe(false)
		expect(message).toBe("WalkSurfaces is missing RightBootRamp\nWalkSurfaces is missing SteepGuards")
		bad:Destroy()
	end)
end)

-- Builds a fake world that only has EggSpots, with no parent. The spots are the 16 that the real world has:
-- 8 Common, 4 Uncommon and 4 Rare (`counts` builds any other mix, a missing rank has none). Each is a Model with a
-- Rarity, a Base and a PromptAnchor.
type SpotOptions = {
	counts: { [string]: number }?, -- rank -> how many spots to build, instead of 8, 4, 4
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
	local counts: { [string]: number } = opts.counts or { Common = 8, Uncommon = 4, Rare = 4 }
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local number = 0
	for _, rarity in order do
		for index = counts[rarity] or 0, 1, -1 do -- built backwards on purpose: the reader must sort by name
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

	it("reports a spot with a Rarity that is not one of the five ranks", function()
		local world = makeSpotsWorld({ rarity = { EggSpot_Uncommon_1 = "Mythic" } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ 'EggSpots.EggSpot_Uncommon_1 has an unknown Rarity "Mythic"' })
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

	it("accepts any number of spots of any rank: 9 Common and 1 Epic give 10 spots", function()
		local world = makeSpotsWorld({ counts = { Common = 9, Epic = 1 } })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(problems).toEqual({})
		expect(spots).never.toBeNil()
		expect(#(spots :: { any })).toBe(10)
		world:Destroy()
	end)

	it("rejects a folder with no spots", function()
		local world = makeSpotsWorld({ counts = {} })
		local spots, problems = WorldIndex.readEggSpots(world)
		expect(spots).toBeNil()
		expect(problems).toEqual({ "EggSpots has no spots" })
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
