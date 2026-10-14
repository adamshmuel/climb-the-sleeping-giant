--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local HomeDisplay = require(ServerScriptService.Server.Eggs.HomeDisplay)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

describe("HomeDisplay.tagText", function()
	it("is nil with no eggs, so there is no tag", function()
		expect(HomeDisplay.tagText(0)).toBeNil()
	end)

	it("says '1 egg waiting' for one egg", function()
		expect(HomeDisplay.tagText(1)).toBe("1 egg waiting")
	end)

	it("says 'N eggs waiting' for two or more", function()
		expect(HomeDisplay.tagText(2)).toBe("2 eggs waiting")
		expect(HomeDisplay.tagText(13)).toBe("13 eggs waiting")
	end)
end)

describe("HomeDisplay.spotFor", function()
	it("gives the egg's own number from 1 to 12", function()
		expect(HomeDisplay.spotFor(1)).toBe(1)
		expect(HomeDisplay.spotFor(6)).toBe(6)
		expect(HomeDisplay.spotFor(7)).toBe(7)
		expect(HomeDisplay.spotFor(12)).toBe(12)
	end)

	it("gives nothing from the 13th egg on", function()
		expect(HomeDisplay.spotFor(13)).toBeNil()
		expect(HomeDisplay.spotFor(40)).toBeNil()
	end)

	it("gives nothing for 0, a negative count or a fraction", function()
		expect(HomeDisplay.spotFor(0)).toBeNil()
		expect(HomeDisplay.spotFor(-1)).toBeNil()
		expect(HomeDisplay.spotFor(2.5)).toBeNil()
	end)
end)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A tiny stand-in for a Roblox event.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

local EGG_HEIGHT = 5

-- A fake egg template: the pivot is at the bottom centre, and it holds everything a quiet copy must not have.
local function newTemplate(rarity: string): Model
	local model = Instance.new("Model")
	model.Name = rarity
	model:SetAttribute("Marker", rarity)
	local body = Instance.new("Model")
	body.Name = "body"
	body.Parent = model
	local geom = Instance.new("Part")
	geom.Name = "body_geom"
	geom.Size = Vector3.new(3, EGG_HEIGHT, 3)
	geom.CFrame = CFrame.new(0, EGG_HEIGHT / 2, 0)
	geom.Anchored = false
	geom.CanCollide = false
	geom.Parent = body
	model.WorldPivot = CFrame.new(0, 0, 0)

	local light = Instance.new("PointLight")
	light.Parent = geom
	local fx = Instance.new("Attachment")
	fx.Name = "FX"
	fx.Parent = geom
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Parent = fx
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Parent = geom
	local beamBottom = Instance.new("Attachment")
	beamBottom.Name = "BeamBottom"
	beamBottom.Parent = geom
	local beamTop = Instance.new("Attachment")
	beamTop.Name = "BeamTop"
	beamTop.Parent = geom
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamBottom
	beam.Attachment1 = beamTop
	beam.Parent = geom
	table.insert(madeInstances, model)
	return model
end

local function newTemplates(): WorldIndex.EggTemplates
	return { Common = newTemplate("Common"), Uncommon = newTemplate("Uncommon"), Rare = newTemplate("Rare") }
end

-- A fake garden: a plot folder with a Dressing folder holding an incubator (a base and a taller dome) and a
-- HomeSpots folder with 12 flat spots, each turned by `turn` radians.
local SPOT_TOP_Y = 8
local INCUBATOR_TOP_Y = 14
local function newGarden(index: number, origin: Vector3, turn: number): WorldIndex.Garden
	local plot = Instance.new("Folder")
	plot.Name = `Plot_{index}`
	table.insert(madeInstances, plot)
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	dressing.Parent = plot
	local incubator = Instance.new("Model")
	incubator.Name = "Incubator1"
	incubator.Parent = dressing
	local base = Instance.new("Part")
	base.Name = "base"
	base.Size = Vector3.new(7, 2, 7)
	base.CFrame = CFrame.new(origin + Vector3.new(0, 6.5, 0))
	base.Anchored = true
	base.Parent = incubator
	local dome = Instance.new("Part")
	dome.Name = "glass_dome"
	dome.Size = Vector3.new(6, 6, 6)
	dome.CFrame = CFrame.new(origin + Vector3.new(0, INCUBATOR_TOP_Y - 3, 0))
	dome.Anchored = true
	dome.Parent = incubator

	local spotsFolder = Instance.new("Folder")
	spotsFolder.Name = "HomeSpots"
	spotsFolder.Parent = plot
	local spots: { BasePart } = {}
	for number = 1, 12 do
		local spot = Instance.new("Part")
		spot.Name = `HomeSpot_{number}`
		spot.Size = Vector3.new(2, 0.2, 2)
		spot.CFrame = CFrame.new(origin + Vector3.new(number * 10, SPOT_TOP_Y - 0.1, 0)) * CFrame.Angles(0, turn, 0)
		spot.Anchored = true
		spot.Parent = spotsFolder
		table.insert(spots, spot)
	end
	local garden = { index = index, incubator = incubator, homeSpots = spots }
	return garden :: any
end

type FakePlayer = {
	UserId: number,
	Name: string,
	GetAttribute: (self: any, name: string) -> any,
	SetAttribute: (self: any, name: string, value: any) -> (),
}

local function newPlayer(userId: number, plotIndex: any, eggsHome: any): FakePlayer
	local attributes = Instance.new("Folder")
	table.insert(madeInstances, attributes)
	attributes:SetAttribute("PlotIndex", plotIndex)
	attributes:SetAttribute("EggsHome", eggsHome)
	return {
		UserId = userId,
		Name = `Player{userId}`,
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes:SetAttribute(name, value)
		end,
	}
end

type Fired = { player: any, rarity: any, position: Vector3 }

type Rig = {
	gardens: { WorldIndex.Garden },
	banked: any,
	playersService: any,
	fired: { Fired },
	handle: HomeDisplay.Handle,
	-- Pretends this player banked an egg: raises EggsHome by one, then fires `banked`.
	bank: (player: FakePlayer, rarity: string) -> (),
}

local function newRig(): Rig
	local gardens = { newGarden(1, Vector3.new(0, 0, 0), 0), newGarden(2, Vector3.new(0, 0, 100), 0.5) }
	local banked = newSignal()
	local playersService = { PlayerRemoving = newSignal() }
	local fired: { Fired } = {}
	local handle = HomeDisplay.start({
		gardens = gardens,
		templates = newTemplates(),
		banked = banked,
		players = playersService,
		fireEggHome = function(player, rarity, position)
			table.insert(fired, { player = player, rarity = rarity, position = position })
		end,
	})
	table.insert(stops, function()
		handle:stop()
	end)
	return {
		gardens = gardens,
		banked = banked,
		playersService = playersService,
		fired = fired,
		handle = handle,
		bank = function(player, rarity)
			local count = player:GetAttribute("EggsHome")
			player:SetAttribute("EggsHome", (if type(count) == "number" then count else 0) + 1)
			banked:Fire(player, rarity)
		end,
	}
end

local function homeEggsFolder(garden: WorldIndex.Garden): Instance?
	return ((garden.homeSpots[1].Parent :: Instance).Parent :: Instance):FindFirstChild("HomeEggs")
end

local function homeEgg(garden: WorldIndex.Garden, number: number): Model?
	local folder = homeEggsFolder(garden)
	if folder == nil then
		return nil
	end
	local egg = folder:FindFirstChild(`HomeEgg_{number}`)
	return if egg ~= nil and egg:IsA("Model") then egg else nil
end

local function countHomeEggs(garden: WorldIndex.Garden): number
	local folder = homeEggsFolder(garden)
	if folder == nil then
		return 0
	end
	local total = 0
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			total += 1
		end
	end
	return total
end

-- The tag: the BillboardGui named "EggTag" somewhere under the garden's plot.
local function tagOf(garden: WorldIndex.Garden): BillboardGui?
	local plot = (garden.homeSpots[1].Parent :: Instance).Parent :: Instance
	local found = plot:FindFirstChild("EggTag", true)
	return if found ~= nil and found:IsA("BillboardGui") then found else nil
end

local function tagLabel(tag: BillboardGui): TextLabel
	return tag:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel
end

-- Is the tag there and showing?
local function tagShows(garden: WorldIndex.Garden): boolean
	local tag = tagOf(garden)
	return tag ~= nil and tag.Enabled
end

describe("HomeDisplay: eggs on the home spots", function()
	it("stands the first banked egg on home spot 1, with its bottom on the spot's top", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		rig.bank(player, "Common")
		local egg = homeEgg(rig.gardens[1], 1)
		expect(egg).never.toBeNil()
		local cf, size = (egg :: Model):GetBoundingBox()
		local spot = rig.gardens[1].homeSpots[1]
		local spotTop = spot.Position.Y + spot.Size.Y / 2
		expect(math.abs(cf.Position.Y - size.Y / 2 - spotTop) < 0.01).toBe(true)
		expect(math.abs(cf.Position.X - spot.Position.X) < 0.01).toBe(true)
		expect(math.abs(cf.Position.Z - spot.Position.Z) < 0.01).toBe(true)
	end)

	it("copies the egg of the banked rarity", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		rig.bank(player, "Uncommon")
		expect((homeEgg(rig.gardens[1], 1) :: Model):GetAttribute("Marker")).toBe("Uncommon")
	end)

	it("turns the egg like the spot", function()
		local rig = newRig()
		local player = newPlayer(1, 2, 0)
		rig.bank(player, "Common")
		local egg = homeEgg(rig.gardens[2], 1) :: Model
		local spot = rig.gardens[2].homeSpots[1]
		local _, eggYaw, _ = egg:GetPivot():ToOrientation()
		local _, spotYaw, _ = spot.CFrame:ToOrientation()
		expect(math.abs(eggYaw - spotYaw) < 0.001).toBe(true)
	end)

	it("puts eggs 2 to 6 on spots 2 to 6 and egg 7 on spot 7", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		for number = 1, 7 do
			rig.bank(player, "Common")
			local egg = homeEgg(rig.gardens[1], number)
			expect(egg).never.toBeNil()
			local spot = rig.gardens[1].homeSpots[number]
			local cf = (egg :: Model):GetBoundingBox()
			expect(math.abs(cf.Position.X - spot.Position.X) < 0.01).toBe(true)
		end
		expect(countHomeEggs(rig.gardens[1])).toBe(7)
	end)

	it("keeps the eggs in a HomeEggs folder in the garden's plot", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		local folder = homeEggsFolder(rig.gardens[1])
		expect(folder).never.toBeNil()
		expect((folder :: Instance).ClassName).toBe("Folder")
		expect((folder :: Instance).Parent).toBe((rig.gardens[1].homeSpots[1].Parent :: Instance).Parent)
	end)

	it("leaves no BillboardGui, Beam, light or particles on a home egg", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		for _, rarity in { "Common", "Uncommon", "Rare" } do
			rig.bank(player, rarity)
		end
		for number = 1, 3 do
			local egg = homeEgg(rig.gardens[1], number) :: Model
			for _, descendant in egg:GetDescendants() do
				expect(descendant:IsA("BillboardGui")).toBe(false)
				expect(descendant:IsA("Beam")).toBe(false)
				expect(descendant:IsA("Light")).toBe(false)
				expect(descendant:IsA("ParticleEmitter")).toBe(false)
				expect(descendant.Name).never.toBe("BeamBottom")
				expect(descendant.Name).never.toBe("BeamTop")
			end
		end
	end)

	it("anchors every part of a home egg and turns its collisions off", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		local egg = homeEgg(rig.gardens[1], 1) :: Model
		local partCount = 0
		for _, descendant in egg:GetDescendants() do
			if descendant:IsA("BasePart") then
				partCount += 1
				expect(descendant.Anchored).toBe(true)
				expect(descendant.CanCollide).toBe(false)
			end
		end
		expect(partCount > 0).toBe(true)
	end)

	it("adds no model from the 13th egg on", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		for _ = 1, 13 do
			rig.bank(player, "Common")
		end
		expect(countHomeEggs(rig.gardens[1])).toBe(12)
		expect(homeEgg(rig.gardens[1], 13)).toBeNil()
	end)

	it("changes nothing in another player's garden", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		expect(countHomeEggs(rig.gardens[2])).toBe(0)
		expect(tagOf(rig.gardens[2])).toBeNil()
	end)

	it("changes nothing for a player with no valid PlotIndex", function()
		local rig = newRig()
		rig.bank(newPlayer(1, nil, 0), "Common")
		rig.bank(newPlayer(2, "one", 0), "Common")
		rig.bank(newPlayer(3, 99, 0), "Common")
		expect(countHomeEggs(rig.gardens[1])).toBe(0)
		expect(countHomeEggs(rig.gardens[2])).toBe(0)
		expect(#rig.fired).toBe(0)
	end)

	it("ignores a player whose EggsHome is not a whole number of at least 1", function()
		local rig = newRig()
		rig.banked:Fire(newPlayer(1, 1, 0), "Common")
		rig.banked:Fire(newPlayer(2, 1, 1.5), "Common")
		rig.banked:Fire(newPlayer(3, 1, "many"), "Common")
		expect(countHomeEggs(rig.gardens[1])).toBe(0)
		expect(#rig.fired).toBe(0)
	end)

	it("ignores a rarity it has no egg for", function()
		local rig = newRig()
		rig.banked:Fire(newPlayer(1, 1, 1), "Legendary")
		expect(countHomeEggs(rig.gardens[1])).toBe(0)
		expect(#rig.fired).toBe(0)
	end)
end)

describe("HomeDisplay: the tag", function()
	it("has no tag showing before the first egg", function()
		local rig = newRig()
		expect(tagShows(rig.gardens[1])).toBe(false)
	end)

	it("shows '1 egg waiting' after the first egg", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		local tag = tagOf(rig.gardens[1]) :: BillboardGui
		expect(tag.Enabled).toBe(true)
		expect(tagLabel(tag).Text).toBe("1 egg waiting")
	end)

	it("updates with each egg", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		rig.bank(player, "Common")
		rig.bank(player, "Common")
		expect(tagLabel(tagOf(rig.gardens[1]) :: BillboardGui).Text).toBe("2 eggs waiting")
	end)

	it("says '13 eggs waiting' with the 13th egg", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		for _ = 1, 13 do
			rig.bank(player, "Common")
		end
		expect(tagLabel(tagOf(rig.gardens[1]) :: BillboardGui).Text).toBe("13 eggs waiting")
	end)

	it("floats about 3 studs above the top of the incubator, on its middle", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		local tag = tagOf(rig.gardens[1]) :: BillboardGui
		local adornee = tag.Adornee :: BasePart
		expect(adornee).never.toBeNil()
		expect(adornee:IsDescendantOf(rig.gardens[1].incubator)).toBe(true)
		local position = adornee.Position + tag.StudsOffsetWorldSpace
		expect(math.abs(position.Y - (INCUBATOR_TOP_Y + 3)) < 0.01).toBe(true)
		expect(math.abs(position.X - 0) < 0.01).toBe(true)
		expect(math.abs(position.Z - 0) < 0.01).toBe(true)
		expect(tag.StudsOffset).toBe(Vector3.zero)
	end)

	it("looks like the +$ tag: gold words, an Ink outline, no panel", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		local tag = tagOf(rig.gardens[1]) :: BillboardGui
		local label = tagLabel(tag)
		expect(label.TextColor3).toBe(Color3.fromHex("FFE27A"))
		expect(label.FontFace.Family).toBe(Font.fromEnum(Enum.Font.FredokaOne).Family)
		expect(label.BackgroundTransparency).toBe(1)
		local stroke = label:FindFirstChildWhichIsA("UIStroke") :: UIStroke
		expect(stroke).never.toBeNil()
		expect(stroke.Color).toBe(Color3.fromHex("2B2340"))
	end)

	it("shrinks with distance and is not drawn over the world", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		local tag = tagOf(rig.gardens[1]) :: BillboardGui
		-- 13 x 3.2 studs: big enough to read at a glance from the gate (designer's look check).
		expect(tag.Size.X.Scale).toBe(13)
		expect(math.abs(tag.Size.Y.Scale - 3.2) < 0.001).toBe(true) -- stored as a 32-bit number
		expect(tag.Size.X.Offset).toBe(0)
		expect(tag.Size.Y.Offset).toBe(0)
		expect(tag.AlwaysOnTop).toBe(false)
		expect(tag.LightInfluence).toBe(0)
		expect(tag.MaxDistance).toBe(120)
		local label = tagLabel(tag)
		expect(label.TextScaled).toBe(true)
		local constraint = label:FindFirstChildWhichIsA("UITextSizeConstraint") :: UITextSizeConstraint
		expect(constraint.MinTextSize).toBe(14)
		expect(constraint.MaxTextSize).toBe(32)
	end)
end)

describe("HomeDisplay: EggHome", function()
	it("is fired once per egg with the player, the rarity and the egg's top position", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		rig.bank(player, "Uncommon")
		expect(#rig.fired).toBe(1)
		expect(rig.fired[1].player).toBe(player)
		expect(rig.fired[1].rarity).toBe("Uncommon")
		local spot = rig.gardens[1].homeSpots[1]
		local expected = Vector3.new(spot.Position.X, SPOT_TOP_Y + EGG_HEIGHT, spot.Position.Z)
		expect((rig.fired[1].position - expected).Magnitude < 0.01).toBe(true)
	end)

	it("is fired for the 13th egg with the tag's position and no new egg", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		for _ = 1, 13 do
			rig.bank(player, "Common")
		end
		expect(#rig.fired).toBe(13)
		local tag = tagOf(rig.gardens[1]) :: BillboardGui
		local tagPosition = (tag.Adornee :: BasePart).Position + tag.StudsOffsetWorldSpace
		expect((rig.fired[13].position - tagPosition).Magnitude < 0.01).toBe(true)
	end)
end)

describe("HomeDisplay: leaving and stopping", function()
	it("takes a leaving player's eggs away and hides their tag", function()
		local rig = newRig()
		local leaver = newPlayer(1, 1, 0)
		local stayer = newPlayer(2, 2, 0)
		rig.bank(leaver, "Common")
		rig.bank(leaver, "Common")
		rig.bank(stayer, "Common")
		rig.playersService.PlayerRemoving:Fire(leaver)
		expect(countHomeEggs(rig.gardens[1])).toBe(0)
		expect(tagShows(rig.gardens[1])).toBe(false)
		expect(countHomeEggs(rig.gardens[2])).toBe(1)
		expect(tagShows(rig.gardens[2])).toBe(true)
	end)

	it("lets the next owner of the garden start empty", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		rig.playersService.PlayerRemoving:Fire({ UserId = 1 })
		local next = newPlayer(3, 1, 0)
		rig.bank(next, "Rare")
		expect(countHomeEggs(rig.gardens[1])).toBe(1)
		expect((homeEgg(rig.gardens[1], 1) :: Model):GetAttribute("Marker")).toBe("Rare")
		expect(tagLabel(tagOf(rig.gardens[1]) :: BillboardGui).Text).toBe("1 egg waiting")
	end)

	it("does nothing when a player with no eggs leaves", function()
		local rig = newRig()
		rig.bank(newPlayer(1, 1, 0), "Common")
		rig.playersService.PlayerRemoving:Fire({ UserId = 77 })
		expect(countHomeEggs(rig.gardens[1])).toBe(1)
	end)

	it("removes every connection, egg and tag when stopped", function()
		local rig = newRig()
		local player = newPlayer(1, 1, 0)
		rig.bank(player, "Common")
		rig.bank(newPlayer(2, 2, 0), "Common")
		rig.handle:stop()
		expect(rig.banked:count()).toBe(0)
		expect(rig.playersService.PlayerRemoving:count()).toBe(0)
		for _, garden in rig.gardens do
			expect(countHomeEggs(garden)).toBe(0)
			expect(tagOf(garden)).toBeNil()
			expect(homeEggsFolder(garden)).toBeNil()
		end
	end)

	it("can be stopped twice", function()
		local rig = newRig()
		rig.handle:stop()
		rig.handle:stop()
	end)
end)
