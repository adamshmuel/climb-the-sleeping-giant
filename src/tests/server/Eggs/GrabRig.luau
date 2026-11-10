--!strict
-- Shared set-up for the Grab specs: a fake signal, fake egg templates, spots and players, and the clean-up that
-- destroys everything a test made. Call GrabRig.cleanUp in afterEach.
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function cleanUp()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
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

local function newTemplate(rarity: string): Model
	local model = Instance.new("Model")
	model.Name = rarity
	local part = Instance.new("Part")
	part.Name = "body_geom"
	part.Size = Vector3.new(3, 5, 3)
	part.CFrame = CFrame.new(0, 2.5, 0)
	part.Anchored = true
	part.Parent = model
	model.WorldPivot = CFrame.new(0, 0, 0)
	table.insert(madeInstances, model)
	return model
end

-- A fake egg spot: a model with a Base part holding the prompt anchor 2 studs above it, as in the real world.
local function newSpot(name: string, rarity: Config.RarityName, x: number): WorldIndex.EggSpot
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Rarity", rarity)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(2, 0.2, 2)
	base.Anchored = true
	base.CFrame = CFrame.new(x, 0, 0)
	base.Parent = model
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, 2, 0)
	anchor.Parent = base
	table.insert(madeInstances, model)
	return {
		name = name,
		rarity = rarity,
		cframe = CFrame.new(x, 0.1, 0),
		promptAnchor = anchor,
		model = model,
	}
end

export type FakePlayer = {
	UserId: number,
	Name: string,
	Character: Model?,
	attributes: Folder,
	root: BasePart,
	humanoid: Humanoid,
	SetAttribute: (self: any, name: string, value: any) -> (),
	GetAttribute: (self: any, name: string) -> any,
}

-- A fake player with a living character standing at `position`. Its attributes live on a Folder.
local function newPlayer(userId: number, position: Vector3): FakePlayer
	local attributes = Instance.new("Folder")
	table.insert(madeInstances, attributes)
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = character
	table.insert(madeInstances, character)
	return {
		UserId = userId,
		Name = `Player{userId}`,
		Character = character,
		attributes = attributes,
		root = root,
		humanoid = humanoid,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes:SetAttribute(name, value)
		end,
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
	}
end

local START_TIME = 1000

local function eggOnBack(player: FakePlayer): Instance?
	return (player.Character :: Model):FindFirstChild("CarriedEgg")
end

-- The slotsPerRank dep that leaves one nest of every rank empty (spots minus one, never below 0), so a refill has
-- somewhere to land in a test with a few spots. Grab.slotsFor gives a rank its Config slots instead (Task 12).
local function oneFreeSlots(spots: { WorldIndex.EggSpot }): { [Config.RarityName]: number }
	local slots: { [Config.RarityName]: number } = {}
	for _, spot in spots do
		local before = slots[spot.rarity]
		slots[spot.rarity] = if before == nil then 0 else before + 1 -- the first spot of a rank is the free one
	end
	return slots
end

return {
	oneFreeSlots = oneFreeSlots,
	madeInstances = madeInstances,
	stops = stops,
	cleanUp = cleanUp,
	newSignal = newSignal,
	newTemplate = newTemplate,
	newSpot = newSpot,
	newPlayer = newPlayer,
	START_TIME = START_TIME,
	eggOnBack = eggOnBack,
}
