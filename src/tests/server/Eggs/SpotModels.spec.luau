--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local SpotModels = require(ServerScriptService.Server.Eggs.SpotModels)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}

afterEach(function()
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A fake egg model with one part. Its "Marker" attribute says which rarity it is, because Clone keeps attributes.
local function newTemplate(rarity: string, anchored: boolean): Model
	local model = Instance.new("Model")
	model.Name = rarity
	model:SetAttribute("Marker", rarity)
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 3, 2)
	part.Anchored = anchored
	part.Parent = model
	table.insert(madeInstances, model)
	return model
end

local function newTemplates(anchored: boolean): WorldIndex.EggTemplates
	return {
		Common = newTemplate("Common", anchored),
		Uncommon = newTemplate("Uncommon", anchored),
		Rare = newTemplate("Rare", anchored),
	}
end

-- A fake egg spot: a model with a Base part holding the prompt anchor, as in the real world.
local function newSpot(name: string, rarity: Config.RarityName, cframe: CFrame): WorldIndex.EggSpot
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Rarity", rarity)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Parent = model
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Parent = base
	table.insert(madeInstances, model)
	return { name = name, rarity = rarity, cframe = cframe, promptAnchor = anchor, model = model }
end

-- The egg models on a spot: its children other than the Base.
local function eggsOn(spot: WorldIndex.EggSpot): { Model }
	local eggs: { Model } = {}
	for _, child in spot.model:GetChildren() do
		if child:IsA("Model") then
			table.insert(eggs, child)
		end
	end
	return eggs
end

local leaned = CFrame.new(5, 6, 7) * CFrame.Angles(0.3, 0.2, 0)

describe("SpotModels.show", function()
	it("puts exactly one egg of the spot's rarity on the spot", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Rare_1")
		local eggs = eggsOn(spot)
		expect(#eggs).toBe(1)
		expect(eggs[1]:GetAttribute("Marker")).toBe("Rare")
	end)

	it("puts the egg at the spot's position, leaning with the spot", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Rare_1")
		local pivot = eggsOn(spot)[1]:GetPivot()
		expect((pivot.Position - leaned.Position).Magnitude < 0.001).toBe(true)
		expect((pivot.LookVector - leaned.LookVector).Magnitude < 0.001).toBe(true)
		expect((pivot.UpVector - leaned.UpVector).Magnitude < 0.001).toBe(true)
	end)

	it("copies the template and leaves the template itself alone", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local templates = newTemplates(true)
		local models = SpotModels.new({ spot }, templates)
		models:show("EggSpot_Common_1")
		expect(eggsOn(spot)[1]).never.toBe(templates.Common)
		expect(templates.Common.Parent).toBeNil()
	end)

	it("keeps the egg inside the spot's own model, so it streams with the spot", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		expect(eggsOn(spot)[1].Parent).toBe(spot.model)
	end)

	it("never leaves two eggs on a spot when shown twice", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		models:show("EggSpot_Common_1")
		expect(#eggsOn(spot)).toBe(1)
	end)

	it("anchors every part of the egg, even if the template was not anchored", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(false))
		models:show("EggSpot_Common_1")
		for _, descendant in eggsOn(spot)[1]:GetDescendants() do
			if descendant:IsA("BasePart") then
				expect(descendant.Anchored).toBe(true)
			end
		end
	end)

	it("sets Waiting to true and clears RefillAt", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		spot.model:SetAttribute("Waiting", false)
		spot.model:SetAttribute("RefillAt", 123)
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		expect(spot.model:GetAttribute("Waiting")).toBe(true)
		expect(spot.model:GetAttribute("RefillAt")).toBeNil()
	end)

	it("only changes the spot it is asked about", function()
		local one = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local two = newSpot("EggSpot_Uncommon_1", "Uncommon", CFrame.new(9, 5, 0))
		local models = SpotModels.new({ one, two }, newTemplates(true))
		models:show("EggSpot_Uncommon_1")
		expect(#eggsOn(one)).toBe(0)
		expect(one.model:GetAttribute("Waiting")).toBeNil()
		expect(eggsOn(two)[1]:GetAttribute("Marker")).toBe("Uncommon")
	end)

	it("refuses a spot it does not know", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		expect(function()
			models:show("EggSpot_Nope")
		end).toThrow("unknown egg spot")
	end)
end)

describe("SpotModels.hide", function()
	it("removes the egg from the spot", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		models:hide("EggSpot_Common_1")
		expect(#eggsOn(spot)).toBe(0)
	end)

	it("writes Waiting false and no RefillAt, even if an old caller still passes a time", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		-- Task 7b: hide takes only the name now. A caller built for the old signature must not put a timer on the nest.
		local hideWithTime = models.hide :: any
		hideWithTime(models, "EggSpot_Common_1", 110)
		expect(spot.model:GetAttribute("Waiting")).toBe(false)
		expect(spot.model:GetAttribute("RefillAt")).toBeNil()
	end)

	it("keeps the spot's Base and its prompt anchor", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		models:hide("EggSpot_Common_1")
		expect(spot.model:FindFirstChild("Base")).never.toBeNil()
		expect(spot.promptAnchor.Parent).never.toBeNil()
	end)

	it("does nothing wrong when the spot has no egg", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:hide("EggSpot_Common_1")
		expect(#eggsOn(spot)).toBe(0)
		expect(spot.model:GetAttribute("Waiting")).toBe(false)
	end)

	it("lets the egg be shown again afterwards", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		models:hide("EggSpot_Common_1")
		models:show("EggSpot_Common_1")
		expect(#eggsOn(spot)).toBe(1)
		expect(spot.model:GetAttribute("Waiting")).toBe(true)
		expect(spot.model:GetAttribute("RefillAt")).toBeNil()
	end)
end)

-- A fake egg like the real templates: a body part holding a light, sparkles and a label, and (the Rare) a beam
-- between two attachments.
local function newLookingTemplate(rarity: string, withBeam: boolean): Model
	local model = newTemplate(rarity, true)
	local body = model:FindFirstChildOfClass("Part") :: Part
	local light = Instance.new("PointLight")
	light.Parent = body
	local fx = Instance.new("Attachment")
	fx.Name = "FX"
	fx.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Parent = fx
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Parent = body
	if withBeam then
		local bottom = Instance.new("Attachment")
		bottom.Name = "BeamBottom"
		bottom.Parent = body
		local top = Instance.new("Attachment")
		top.Name = "BeamTop"
		top.Position = Vector3.new(0, 26, 0) -- the real Rare template's beam is about 26 studs long
		if rarity == "Legendary" then
			-- the real Legendary template's beam leans about 18 degrees (read in Studio, 13c Step A)
			top.Position = Vector3.new(-0.186, 0.951, -0.248).Unit * 26
		end
		top.Parent = body
		local beam = Instance.new("Beam")
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.Parent = body
	end
	return model
end

local function newLookingTemplates(): WorldIndex.EggTemplates
	return {
		Common = newLookingTemplate("Common", false),
		Uncommon = newLookingTemplate("Uncommon", false),
		Rare = newLookingTemplate("Rare", true),
		Epic = newLookingTemplate("Epic", true),
		Legendary = newLookingTemplate("Legendary", true),
	}
end

-- A meadow spot: like newSpot, plus a flat glow ring.
local function newMeadowSpot(name: string): WorldIndex.EggSpot
	local spot = newSpot(name, "Common", CFrame.new(0, 5, 0))
	local ring = Instance.new("Part")
	ring.Name = "GlowRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.35
	ring.Parent = spot.model
	return spot
end

local function ringOf(spot: WorldIndex.EggSpot): Part
	return spot.model:FindFirstChild("GlowRing") :: Part
end

local function countOf(root: Instance, className: string): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA(className) then
			count += 1
		end
	end
	return count
end

describe("SpotModels: how a spot looks", function()
	it("names the two ring transparencies: 0.6 with an egg, 0.85 without", function()
		expect(SpotModels.WAITING_RING_TRANSPARENCY).toBe(0.6)
		expect(SpotModels.EMPTY_RING_TRANSPARENCY).toBe(0.85)
	end)

	it("makes the ring 60% see-through when an egg is shown", function()
		local spot = newMeadowSpot("EggSpot_Common_1")
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:show("EggSpot_Common_1")
		expect(ringOf(spot).Transparency).toBeCloseTo(0.6, 5)
	end)

	it("hide leaves the GlowRing alone", function()
		local spot = newMeadowSpot("EggSpot_Common_1")
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:hide("EggSpot_Common_1")
		expect(ringOf(spot).Transparency).toBeCloseTo(0.35, 5)
	end)

	it("makes the ring 60% see-through again when the egg comes back", function()
		local spot = newMeadowSpot("EggSpot_Common_1")
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:show("EggSpot_Common_1")
		models:hide("EggSpot_Common_1")
		models:show("EggSpot_Common_1")
		expect(ringOf(spot).Transparency).toBeCloseTo(0.6, 5)
	end)

	it("leaves no sparkles, light or beam on an empty spot", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:show("EggSpot_Rare_1")
		models:hide("EggSpot_Rare_1")
		expect(countOf(spot.model, "ParticleEmitter")).toBe(0)
		expect(countOf(spot.model, "Light")).toBe(0)
		expect(countOf(spot.model, "Beam")).toBe(0)
	end)

	it("keeps the egg's light, sparkles and beam, but not its label, when an egg is shown", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:show("EggSpot_Rare_1")
		expect(countOf(spot.model, "BillboardGui")).toBe(0)
		expect(countOf(spot.model, "PointLight")).toBe(1)
		expect(countOf(spot.model, "ParticleEmitter")).toBe(1)
		expect(countOf(spot.model, "Beam")).toBe(1)
	end)

	it("takes the label off the egg's copy only, not off the template", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local templates = newLookingTemplates()
		local models = SpotModels.new({ spot }, templates)
		models:show("EggSpot_Common_1")
		expect(countOf(templates.Common, "BillboardGui")).toBe(1)
	end)

	it("shows and hides eggs on a spot that has no ring", function()
		local spot = newSpot("EggSpot_Uncommon_1", "Uncommon", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:show("EggSpot_Uncommon_1")
		expect(#eggsOn(spot)).toBe(1)
		models:hide("EggSpot_Uncommon_1")
		expect(#eggsOn(spot)).toBe(0)
		expect(spot.model:FindFirstChild("GlowRing")).toBeNil()
	end)
end)

describe("SpotModels.setLocked", function()
	it("writes the Locked attribute true, and false again", function()
		local spot = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:setLocked("EggSpot_Common_1", true)
		expect(spot.model:GetAttribute("Locked")).toBe(true)
		models:setLocked("EggSpot_Common_1", false)
		expect(spot.model:GetAttribute("Locked")).toBe(false)
	end)
end)

describe("SpotModels.destroy", function()
	it("removes every egg it showed", function()
		local one = newSpot("EggSpot_Common_1", "Common", CFrame.new(0, 5, 0))
		local two = newSpot("EggSpot_Rare_1", "Rare", CFrame.new(9, 5, 0))
		local models = SpotModels.new({ one, two }, newTemplates(true))
		models:show("EggSpot_Common_1")
		models:show("EggSpot_Rare_1")
		models:destroy()
		expect(#eggsOn(one)).toBe(0)
		expect(#eggsOn(two)).toBe(0)
	end)
end)

-- Rule 85: a meadow spot's invisible EggPost (a folder of parts) is solid only while its egg waits and no player is near.
local POST_AT = CFrame.new(0, 5, 0)
local CLEAR = Config.Nests.PostClear
local NEAR_PLAYER = Vector3.new(CLEAR.HalfBase + CLEAR.Sideways - 0.5, 5, 0) -- inside the clear check's sideways reach
local FAR_PLAYER = Vector3.new(CLEAR.HalfBase + CLEAR.Sideways + 0.5, 5, 0) -- outside it

-- A spot with an EggPost of 2 parts, both not solid to begin with.
local function newPostSpot(): (WorldIndex.EggSpot, { BasePart })
	local spot = newSpot("EggSpot_Common_1", "Common", POST_AT)
	local post = Instance.new("Folder")
	post.Name = "EggPost"
	local parts: { BasePart } = {}
	for n = 1, 2 do
		local part = Instance.new("Part")
		part.Name = `Wedge{n}`
		part.CanCollide = false
		part.Parent = post
		table.insert(parts, part)
	end
	post.Parent = spot.model
	return spot, parts
end

local function allSolid(parts: { BasePart }, solid: boolean): boolean
	for _, part in parts do
		if part.CanCollide ~= solid then
			return false
		end
	end
	return true
end

describe("SpotModels EggPost (Rule 85)", function()
	it("show makes the post solid when no player is close", function()
		local spot, parts = newPostSpot()
		SpotModels.new({ spot }, newTemplates(true)):show("EggSpot_Common_1", { FAR_PLAYER })
		expect(allSolid(parts, true)).toBe(true)
	end)

	it("show makes the post solid when it is not told where players are", function()
		local spot, parts = newPostSpot()
		SpotModels.new({ spot }, newTemplates(true)):show("EggSpot_Common_1")
		expect(allSolid(parts, true)).toBe(true)
	end)

	it("show leaves the post not solid while a player is close", function()
		local spot, parts = newPostSpot()
		SpotModels.new({ spot }, newTemplates(true)):show("EggSpot_Common_1", { NEAR_PLAYER })
		expect(allSolid(parts, false)).toBe(true)
	end)

	it("hide makes a solid post not solid", function()
		local spot, parts = newPostSpot()
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1")
		models:hide("EggSpot_Common_1")
		expect(allSolid(parts, false)).toBe(true)
	end)

	it("step turns a blocked post solid once the player has moved away, and not before", function()
		local spot, parts = newPostSpot()
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1", { NEAR_PLAYER })
		models:step({ NEAR_PLAYER })
		expect(allSolid(parts, false)).toBe(true)
		models:step({ FAR_PLAYER })
		expect(allSolid(parts, true)).toBe(true)
	end)

	it("step does not make a post solid after hide took its egg away", function()
		local spot, parts = newPostSpot()
		local models = SpotModels.new({ spot }, newTemplates(true))
		models:show("EggSpot_Common_1", { NEAR_PLAYER })
		models:hide("EggSpot_Common_1")
		models:step({})
		expect(allSolid(parts, false)).toBe(true)
	end)
end)

-- The beam on an egg on his body is 10 studs long, and 15 for the Legendary egg (spec 4 section 6; Config.Ranks.BodyBeamStuds
-- and LegendaryBeamStuds). The fake Rare, Epic and Legendary beams are 26 studs (newLookingTemplate), so a
-- shortened clone is easy to tell from an untouched one.
local function beamLength(root: Instance): number
	local beam = root:FindFirstChildWhichIsA("Beam", true) :: Beam
	local a0 = beam.Attachment0 :: Attachment
	local a1 = beam.Attachment1 :: Attachment
	return (a1.WorldPosition - a0.WorldPosition).Magnitude
end

local function zoneStub(zone: Config.ZoneName): (Vector3) -> Config.ZoneName
	return function(_position: Vector3): Config.ZoneName
		return zone
	end
end

describe("SpotModels: the beam on his body (10 studs; 15 for the Legendary egg)", function()
	for _, zone in { "Belly", "Beard", "Nightcap" } do
		it(`shortens the shown egg's beam to 10 studs in the {zone}`, function()
			local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
			local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub(zone :: Config.ZoneName))
			models:show("EggSpot_Rare_1")
			expect(beamLength(spot.model)).toBeCloseTo(10, 2)
		end)
	end

	for _, zone in { "Meadow", "Boots" } do
		it(`keeps the beam's 26 studs in the {zone}`, function()
			local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
			local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub(zone :: Config.ZoneName))
			models:show("EggSpot_Rare_1")
			expect(beamLength(spot.model)).toBeCloseTo(26, 2)
		end)
	end

	it("keeps the beam's 26 studs when no zoneOf is given", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local models = SpotModels.new({ spot }, newLookingTemplates())
		models:show("EggSpot_Rare_1")
		expect(beamLength(spot.model)).toBeCloseTo(26, 2)
	end)

	it("leaves the template's own beam at 26 studs after a show on the belly", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local templates = newLookingTemplates()
		local models = SpotModels.new({ spot }, templates, zoneStub("Belly"))
		models:show("EggSpot_Rare_1")
		expect(beamLength(templates.Rare)).toBeCloseTo(26, 2)
	end)

	it("shows an Uncommon egg with no beam on the belly without an error and without a beam", function()
		local spot = newSpot("EggSpot_Uncommon_1", "Uncommon", leaned)
		local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub("Belly"))
		models:show("EggSpot_Uncommon_1")
		expect(#eggsOn(spot)).toBe(1)
		expect(countOf(spot.model, "Beam")).toBe(0)
	end)

	it("shortens the second clone too, when the egg is hidden and shown again", function()
		local spot = newSpot("EggSpot_Rare_1", "Rare", leaned)
		local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub("Belly"))
		models:show("EggSpot_Rare_1")
		models:hide("EggSpot_Rare_1")
		models:show("EggSpot_Rare_1")
		expect(countOf(spot.model, "Beam")).toBe(1)
		expect(beamLength(spot.model)).toBeCloseTo(10, 2)
	end)

	it("gives 10 studs on a flat spot and on a leaning spot", function()
		local flat = newSpot("EggSpot_Rare_1", "Rare", CFrame.new(0, 5, 0))
		local tilted = newSpot("EggSpot_Rare_2", "Rare", leaned)
		local models = SpotModels.new({ flat, tilted }, newLookingTemplates(), zoneStub("Belly"))
		models:show("EggSpot_Rare_1")
		models:show("EggSpot_Rare_2")
		expect(beamLength(flat.model)).toBeCloseTo(10, 2)
		expect(beamLength(tilted.model)).toBeCloseTo(10, 2)
	end)

	-- Where the beam's end sits compared with its start, in the world.
	local function beamRise(root: Instance): Vector3
		local beam = root:FindFirstChildWhichIsA("Beam", true) :: Beam
		local a0 = beam.Attachment0 :: Attachment
		local a1 = beam.Attachment1 :: Attachment
		return a1.WorldPosition - a0.WorldPosition
	end

	for _, zone in { "Belly", "Beard", "Nightcap" } do
		it(`gives the Legendary egg a 15-stud beam in the {zone}`, function()
			local spot = newSpot("EggSpot_Legendary_1", "Legendary", CFrame.new(5, 6, 7))
			local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub(zone :: Config.ZoneName))
			models:show("EggSpot_Legendary_1")
			expect(beamLength(spot.model)).toBeCloseTo(15, 2)
		end)

		it(`points the Legendary egg's beam straight up in the {zone}`, function()
			local spot = newSpot("EggSpot_Legendary_1", "Legendary", CFrame.new(5, 6, 7))
			local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub(zone :: Config.ZoneName))
			models:show("EggSpot_Legendary_1")
			local rise = beamRise(spot.model)
			expect(rise.Y).toBeGreaterThan(0)
			expect(rise.X).toBeCloseTo(0, 2)
			expect(rise.Z).toBeCloseTo(0, 2)
		end)
	end

	for _, rarity in { "Rare", "Epic" } do
		it(`keeps a {rarity} egg's beam at 10 studs on the Nightcap`, function()
			local name = `EggSpot_{rarity}_1`
			local spot = newSpot(name, rarity :: Config.RarityName, leaned)
			local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub("Nightcap"))
			models:show(name)
			expect(beamLength(spot.model)).toBeCloseTo(10, 2)
		end)
	end

	for _, zone in { "Meadow", "Boots" } do
		it(`keeps the Legendary egg's beam at 26 studs in the {zone}`, function()
			local spot = newSpot("EggSpot_Legendary_1", "Legendary", leaned)
			local models = SpotModels.new({ spot }, newLookingTemplates(), zoneStub(zone :: Config.ZoneName))
			models:show("EggSpot_Legendary_1")
			expect(beamLength(spot.model)).toBeCloseTo(26, 2)
		end)
	end

	it("leaves the Legendary template's own beam at 26 studs after a show on the Nightcap", function()
		local spot = newSpot("EggSpot_Legendary_1", "Legendary", leaned)
		local templates = newLookingTemplates()
		local models = SpotModels.new({ spot }, templates, zoneStub("Nightcap"))
		models:show("EggSpot_Legendary_1")
		expect(beamLength(templates.Legendary)).toBeCloseTo(26, 2)
	end)
end)
