--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local RankGlow = require(Client.World.RankGlow)
local RankGlowView = require(Client.World.RankGlowView)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

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

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal(): any
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

local EGG_POSITION = Vector3.new(0, 50, 0)
-- A rank-1 egg is 6.2 studs tall (Uncommon halo 12.4) and a Rare one 7 (halo 14): the test eggs use these heights.
local HEIGHT_OF: { [string]: number } = { Uncommon = 6.2, Rare = 7, Epic = 7.5, Legendary = 8, Common = 6 }

type Rig = {
	root: Folder,
	step: any,
	view: { camera: CFrame? },
	addSpot: (rank: string, withEgg: boolean) -> (Model, Model?),
	addEgg: (spot: Model, rank: string) -> Model,
	at: (distance: number) -> (),
	frame: () -> (),
}

local function newRig(): Rig
	local root = made(Instance.new("Folder"))
	local step = newSignal()
	local view: { camera: CFrame? } = { camera = nil }

	local function addEgg(spot: Model, rank: string): Model
		local egg = Instance.new("Model")
		egg.Name = "Egg"
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Anchored = true
		body.Size = Vector3.new(4, HEIGHT_OF[rank], 4)
		body.Position = EGG_POSITION
		body.Parent = egg
		egg.PrimaryPart = body
		egg.Parent = spot
		task.wait()
		return egg
	end

	local rig: Rig
	rig = {
		root = root,
		step = step,
		view = view,
		addSpot = function(rank: string, withEgg: boolean): (Model, Model?)
			local spot = made(Instance.new("Model"))
			spot.Name = "Spot"
			spot:SetAttribute("Rarity", rank)
			spot.Parent = root
			return spot, if withEgg then addEgg(spot, rank) else nil
		end,
		addEgg = addEgg,
		at = function(distance: number)
			view.camera = CFrame.new(EGG_POSITION + Vector3.new(distance, 0, 0))
			step:Fire()
		end,
		frame = function()
			step:Fire()
		end,
	}
	return rig
end

local function start(rig: Rig)
	local glow = RankGlowView.start({
		root = rig.root,
		camera = function()
			return rig.view.camera
		end,
		step = rig.step,
	})
	table.insert(stops, glow.stop)
	return glow
end

local function haloOf(egg: Model): BillboardGui?
	local body = egg.PrimaryPart :: BasePart
	return body:FindFirstChild("Halo") :: BillboardGui?
end

local function ringsOf(halo: BillboardGui): { Frame }
	local rings: { Frame } = {}
	for _, child in halo:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rings, child)
		end
	end
	return rings
end

local RANKS = { "Uncommon", "Rare", "Epic", "Legendary" }

describe("RankGlowView.start", function()
	it("gives a waiting Uncommon, Rare, Epic and Legendary egg one halo of 12 round rings", function()
		local rig = newRig()
		local eggs: { [string]: Model } = {}
		for _, rank in RANKS do
			local _, egg = rig.addSpot(rank, true)
			eggs[rank] = egg :: Model
		end
		start(rig)
		for _, rank in RANKS do
			local halos = 0
			for _, child in (eggs[rank].PrimaryPart :: BasePart):GetChildren() do
				if child.Name == "Halo" then
					halos += 1
				end
			end
			expect(halos).toBe(1)
			local rings = ringsOf(haloOf(eggs[rank]) :: BillboardGui)
			expect(#rings).toBe(12)
			for _, ring in rings do
				local corner = ring:FindFirstChildOfClass("UICorner") :: UICorner
				expect(corner.CornerRadius).toEqual(UDim.new(0.5, 0))
			end
		end
	end)

	it("sizes and places the halo from the egg: twice its height, behind it, not on top", function()
		local rig = newRig()
		local _, uncommon = rig.addSpot("Uncommon", true)
		local _, rare = rig.addSpot("Rare", true)
		start(rig)
		local uncommonHalo = haloOf(uncommon :: Model) :: BillboardGui
		local rareHalo = haloOf(rare :: Model) :: BillboardGui
		expect(uncommonHalo.Size.X.Scale).toBeCloseTo(12.4, 2)
		expect(rareHalo.Size.X.Scale).toBeCloseTo(14, 2)
		expect(rareHalo.Size.Y.Scale).toBeCloseTo(14, 2)
		expect(rareHalo.StudsOffset).toEqual(Vector3.new(0, 0, -1.5))
		expect(rareHalo.AlwaysOnTop).toBe(false)
		expect(rareHalo.LightInfluence).toBe(0)
		expect(rareHalo.Brightness).toBe(2.5)
		expect(rareHalo.Adornee).toBe((rare :: Model).PrimaryPart)
	end)

	it("gives no halo to a Common egg or an empty spot, and removes it when the egg is destroyed", function()
		local rig = newRig()
		local _, common = rig.addSpot("Common", true)
		rig.addSpot("Rare", false)
		local _, rare = rig.addSpot("Rare", true)
		start(rig)
		expect(haloOf(common :: Model)).toBe(nil)
		local body = (rare :: Model).PrimaryPart :: BasePart
		expect(haloOf(rare :: Model)).never.toBe(nil)
		local rareEgg = rare :: Model
		rareEgg:Destroy()
		task.wait()
		expect(body:FindFirstChild("Halo")).toBe(nil)
		rig.at(80)
	end)

	it("gives a halo to an egg already there at start and to one that arrives later", function()
		local rig = newRig()
		local _, early = rig.addSpot("Epic", true)
		local lateSpot = rig.addSpot("Legendary", false)
		start(rig)
		expect(haloOf(early :: Model)).never.toBe(nil)
		local late = rig.addEgg(lateSpot, "Legendary")
		expect(haloOf(late)).never.toBe(nil)
	end)

	it("hides the halo at 50 studs and fades the rings in: about half at 65, full at 80", function()
		local rig = newRig()
		local _, egg = rig.addSpot("Rare", true)
		start(rig)
		local halo = haloOf(egg :: Model) :: BillboardGui
		local strength = RankGlow.strength("Rare")
		rig.at(50)
		expect(halo.Enabled).toBe(false)
		rig.at(65)
		expect(halo.Enabled).toBe(true)
		for _, ring in ringsOf(halo) do
			expect(ring.BackgroundTransparency).toBeCloseTo(1 - strength * 0.5, 3)
		end
		rig.at(80)
		for _, ring in ringsOf(halo) do
			expect(ring.BackgroundTransparency).toBeCloseTo(1 - strength, 3)
		end
	end)

	it("fades smoothly from 50 to 80 studs: never more solid on the way in, never a pop over 0.01 a stud", function()
		local rig = newRig()
		local _, egg = rig.addSpot("Legendary", true)
		start(rig)
		local ring = ringsOf(haloOf(egg :: Model) :: BillboardGui)[1]
		rig.at(50)
		local last = ring.BackgroundTransparency
		local worstStep = 0
		local rises = 0
		for distance = 51, 80 do
			rig.at(distance)
			local now = ring.BackgroundTransparency
			if now > last + 1e-6 then
				rises += 1
			end
			worstStep = math.max(worstStep, math.abs(now - last))
			last = now
		end
		expect(rises).toBe(0)
		expect(worstStep).toBeLessThan(0.01)
		-- Starts out invisible and ends solid, so the sweep above is not an empty pass.
		expect(last).toBeLessThan(1)
	end)

	it("grows with the rank: Legendary at least as solid as Epic, Rare more than Uncommon (at 80 studs)", function()
		local rig = newRig()
		local solid: { [string]: number } = {}
		local eggs: { [string]: Model } = {}
		for _, rank in RANKS do
			local _, egg = rig.addSpot(rank, true)
			eggs[rank] = egg :: Model
		end
		start(rig)
		rig.at(80)
		for _, rank in RANKS do
			solid[rank] = 1 - ringsOf(haloOf(eggs[rank]) :: BillboardGui)[1].BackgroundTransparency
		end
		expect(solid.Uncommon).toBeGreaterThan(0)
		expect(solid.Legendary).toBeGreaterThanOrEqual(solid.Epic - 1e-6)
		expect(solid.Rare).toBeGreaterThan(solid.Uncommon)
	end)

	it("switches the halos off and raises no error when there is no camera", function()
		local rig = newRig()
		local _, egg = rig.addSpot("Rare", true)
		start(rig)
		local halo = haloOf(egg :: Model) :: BillboardGui
		rig.at(80)
		expect(halo.Enabled).toBe(true)
		rig.view.camera = nil
		rig.frame()
		expect(halo.Enabled).toBe(false)
	end)

	it("gives no halo to a carried egg: not outside root, and not a CarriedEgg model even under a spot", function()
		local rig = newRig()
		local spot = rig.addSpot("Rare", false)
		start(rig)
		-- The real carried egg is named CarriedEgg and sits on the character (Carry.luau, CARRIED_EGG_NAME), never under
		-- root. One fake is outside root, one with the same name sits under a Rare spot: neither may get a halo.
		local outside = made(Instance.new("Model"))
		outside.Name = "CarriedEgg"
		local outsideBody = Instance.new("Part")
		outsideBody.Name = "Body"
		outsideBody.Parent = outside
		outside.PrimaryPart = outsideBody
		outside.Parent = workspace
		local under = Instance.new("Model")
		under.Name = "CarriedEgg"
		local underBody = Instance.new("Part")
		underBody.Name = "Body"
		underBody.Parent = under
		under.PrimaryPart = underBody
		under.Parent = spot
		task.wait()
		rig.at(80)
		expect(outside:FindFirstChild("Halo", true)).toBe(nil)
		expect(under:FindFirstChild("Halo", true)).toBe(nil)
	end)

	it("destroys every halo and lets go of the frame signal on stop", function()
		local rig = newRig()
		local _, one = rig.addSpot("Uncommon", true)
		local _, two = rig.addSpot("Legendary", true)
		local glow = start(rig)
		expect(haloOf(one :: Model)).never.toBe(nil)
		expect(haloOf(two :: Model)).never.toBe(nil)
		expect(rig.step:count()).toBeGreaterThan(0)
		glow.stop()
		expect(haloOf(one :: Model)).toBe(nil)
		expect(haloOf(two :: Model)).toBe(nil)
		expect(rig.step:count()).toBe(0)
	end)
end)
