--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Carry = require(ServerScriptService.Server.Eggs.Carry)

describe("Carry.speed", function()
	it("is 16 when walking with nothing on the back", function()
		expect(Carry.speed(false, nil)).toBe(16)
	end)

	it("is 9.6 with Tiptoe on", function()
		expect(Carry.speed(true, nil)).toBeCloseTo(9.6, 5)
	end)

	it("is 8.64 with Tiptoe on and a Rare egg on the back", function()
		expect(Carry.speed(true, "Rare")).toBeCloseTo(8.64, 5)
	end)

	it("is 16 when carrying a Common egg without Tiptoe (Common does not slow you down)", function()
		expect(Carry.speed(false, "Common")).toBe(16)
	end)

	it("is 15.2 when carrying an Uncommon egg without Tiptoe", function()
		expect(Carry.speed(false, "Uncommon")).toBeCloseTo(15.2, 5)
	end)

	it("is 14.4 when carrying a Rare egg without Tiptoe", function()
		expect(Carry.speed(false, "Rare")).toBeCloseTo(14.4, 5)
	end)
end)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal()
	local handlers: { (any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (any) -> ())
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
		Fire = function(_self: any, value: any)
			for _, handler in table.clone(handlers) do
				handler(value)
			end
		end,
	}
end

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

-- A character with a Humanoid at the normal walking speed. Nothing is parented anywhere.
local function newCharacter(): (Model, Humanoid)
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 16
	humanoid.Parent = character
	table.insert(madeInstances, character)
	return character, humanoid
end

type FakePlayer = {
	UserId: number,
	Name: string,
	Character: Model?,
	attributes: Folder,
	characterAdded: any,
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
	CharacterAdded: any,
}

-- A stand-in for a Player. Its attributes live on a Folder, so the attribute-changed signals are real.
local function newPlayer(userId: number, character: Model?): FakePlayer
	local attributes = Instance.new("Folder")
	table.insert(madeInstances, attributes)
	local characterAdded = newSignal()
	return {
		UserId = userId,
		Name = `Player{userId}`,
		Character = character,
		attributes = attributes,
		characterAdded = characterAdded,
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
		GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
			return attributes:GetAttributeChangedSignal(name)
		end,
		CharacterAdded = characterAdded,
	}
end

-- A fake Players service.
local function newPlayers(existing: { any })
	local list = existing
	return {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function(_self: any)
			return table.clone(list)
		end,
	}
end

-- Starts the speed watcher on a fake Players service and remembers how to stop it.
local function watch(players: any)
	local stop = Carry.watchSpeed(players)
	table.insert(stops, stop)
	return stop
end

describe("Carry.watchSpeed", function()
	it("slows the Humanoid to 9.6 when Tiptoe turns on and back to 16 when it turns off", function()
		local character, humanoid = newCharacter()
		local player = newPlayer(1, character)
		watch(newPlayers({ player }))
		player.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(humanoid.WalkSpeed).toBeCloseTo(9.6, 5)
		player.attributes:SetAttribute("Tiptoe", false)
		task.wait()
		expect(humanoid.WalkSpeed).toBe(16)
	end)

	it("adds the slowdown of the egg on the back", function()
		local character, humanoid = newCharacter()
		local player = newPlayer(1, character)
		watch(newPlayers({ player }))
		player.attributes:SetAttribute("Tiptoe", true)
		player.attributes:SetAttribute("Carrying", "Rare")
		task.wait()
		expect(humanoid.WalkSpeed).toBeCloseTo(8.64, 5)
		player.attributes:SetAttribute("Tiptoe", false)
		task.wait()
		expect(humanoid.WalkSpeed).toBeCloseTo(14.4, 5)
	end)

	it("sets the speed at once for a player whose Tiptoe is already on", function()
		local character, humanoid = newCharacter()
		local player = newPlayer(1, character)
		player.attributes:SetAttribute("Tiptoe", true)
		watch(newPlayers({ player }))
		expect(humanoid.WalkSpeed).toBeCloseTo(9.6, 5)
	end)

	it("keeps Tiptoe's speed on a new character after a respawn", function()
		local firstCharacter, firstHumanoid = newCharacter()
		local player = newPlayer(1, firstCharacter)
		watch(newPlayers({ player }))
		player.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(firstHumanoid.WalkSpeed).toBeCloseTo(9.6, 5)

		local secondCharacter, secondHumanoid = newCharacter() -- Roblox gives the new Humanoid speed 16
		player.Character = secondCharacter
		player.characterAdded:Fire(secondCharacter)
		expect(secondHumanoid.WalkSpeed).toBeCloseTo(9.6, 5)
	end)

	it("sets the speed when the Humanoid arrives a moment after the character", function()
		local player = newPlayer(1, nil)
		watch(newPlayers({ player }))
		player.attributes:SetAttribute("Tiptoe", true)
		local character = Instance.new("Model")
		table.insert(madeInstances, character)
		player.Character = character
		player.characterAdded:Fire(character)
		local humanoid = Instance.new("Humanoid")
		humanoid.WalkSpeed = 16
		humanoid.Parent = character
		task.wait()
		expect(humanoid.WalkSpeed).toBeCloseTo(9.6, 5)
	end)

	it("watches a player who joins later", function()
		local players = newPlayers({})
		watch(players)
		local character, humanoid = newCharacter()
		local player = newPlayer(2, character)
		players.PlayerAdded:Fire(player)
		player.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(humanoid.WalkSpeed).toBeCloseTo(9.6, 5)
	end)

	it("treats a Tiptoe value that is not exactly true as off", function()
		local character, humanoid = newCharacter()
		local player = newPlayer(1, character)
		watch(newPlayers({ player }))
		player.attributes:SetAttribute("Tiptoe", "yes")
		task.wait()
		expect(humanoid.WalkSpeed).toBe(16)
	end)

	it("changes only that player's Humanoid", function()
		local characterOne, humanoidOne = newCharacter()
		local characterTwo, humanoidTwo = newCharacter()
		local one = newPlayer(1, characterOne)
		local two = newPlayer(2, characterTwo)
		watch(newPlayers({ one, two }))
		one.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(humanoidOne.WalkSpeed).toBeCloseTo(9.6, 5)
		expect(humanoidTwo.WalkSpeed).toBe(16)
	end)

	it("stops watching a player who leaves", function()
		local players = newPlayers({})
		watch(players)
		local character, humanoid = newCharacter()
		local player = newPlayer(1, character)
		players.PlayerAdded:Fire(player)
		players.PlayerRemoving:Fire(player)
		player.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(humanoid.WalkSpeed).toBe(16)
		player.characterAdded:Fire(character)
		expect(humanoid.WalkSpeed).toBe(16)
	end)

	it("stops watching everyone when it is stopped", function()
		local character, humanoid = newCharacter()
		local player = newPlayer(1, character)
		local players: any = newPlayers({ player })
		local stop = Carry.watchSpeed(players)
		stop()
		player.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(humanoid.WalkSpeed).toBe(16)
		local later, laterHumanoid = newCharacter()
		local laterPlayer = newPlayer(3, later)
		players.PlayerAdded:Fire(laterPlayer)
		laterPlayer.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(laterHumanoid.WalkSpeed).toBe(16)
	end)
end)

-- A fake egg template as the real ones are built: pivot at the bottom centre, a label, sparkles, a light and (on a
-- Rare) a beam. It is bigger than the carried size and already scaled, like the real ones.
local function newEggTemplate(): Model
	local template = Instance.new("Model")
	template.Name = "Rare"
	local body = Instance.new("Part")
	body.Name = "body_geom"
	body.Size = Vector3.new(4, 7, 4)
	body.CFrame = CFrame.new(0, 3.5, 0) -- the egg's bottom sits on the pivot
	body.Anchored = true
	body.Parent = template
	local cap = Instance.new("Part")
	cap.Name = "cap"
	cap.Size = Vector3.new(2, 1, 2)
	cap.CFrame = CFrame.new(0, 3.5, 0)
	cap.Anchored = true
	cap.Parent = template
	template.WorldPivot = CFrame.new(0, 0, 0)

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Parent = body
	local light = Instance.new("PointLight")
	light.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Parent = body
	local beamBottom = Instance.new("Attachment")
	beamBottom.Name = "BeamBottom"
	beamBottom.Parent = body
	local beamTop = Instance.new("Attachment")
	beamTop.Name = "BeamTop"
	beamTop.Parent = body
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamBottom
	beam.Attachment1 = beamTop
	beam.Parent = body
	template:ScaleTo(1.5)
	table.insert(madeInstances, template)
	return template
end

-- A character with a HumanoidRootPart that is turned and away from the origin, so a wrong position or turn shows.
local function newCharacterWithRoot(): (Model, BasePart)
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(10, 3, -4) * CFrame.Angles(0, 1.1, 0)
	root.Parent = character
	table.insert(madeInstances, character)
	return character, root
end

local CARRIED_OFFSET = CFrame.new(0, 0.8, 1.9)
local CARRIED_HEIGHT = 4.2

local function eggOn(character: Model): Model
	return character:FindFirstChild("CarriedEgg") :: Model
end

describe("Carry.attachEgg", function()
	it("makes the egg the carried height tall", function()
		local character = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		expect(math.abs(eggOn(character):GetExtentsSize().Y - CARRIED_HEIGHT) < 0.05).toBe(true)
	end)

	it("puts the centre of the egg at the offset from the root part, turned with the root part", function()
		local character, root = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		local centre = eggOn(character):GetBoundingBox()
		local wanted = root.CFrame * CARRIED_OFFSET
		expect((centre.Position - wanted.Position).Magnitude < 0.05).toBe(true)
		expect((centre.LookVector - wanted.LookVector).Magnitude < 0.01).toBe(true)
	end)

	it("unanchors every part and makes it massless and unable to collide, be hit by a ray or touch", function()
		local character = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		local parts = 0
		for _, descendant in eggOn(character):GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
				expect(descendant.Anchored).toBe(false)
				expect(descendant.Massless).toBe(true)
				expect(descendant.CanCollide).toBe(false)
				expect(descendant.CanQuery).toBe(false)
				expect(descendant.CanTouch).toBe(false)
			end
		end
		expect(parts).toBe(2)
	end)

	it("welds every part to the root part", function()
		local character, root = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		for _, descendant in eggOn(character):GetDescendants() do
			if descendant:IsA("BasePart") then
				local welds = 0
				for _, child in descendant:GetChildren() do
					if child:IsA("WeldConstraint") then
						welds += 1
						expect(child.Part0).toBe(root)
						expect(child.Part1).toBe(descendant)
						expect(child.Enabled).toBe(true)
					end
				end
				expect(welds).toBe(1)
			end
		end
	end)

	it("keeps the egg's light and sparkles but not its label or beam", function()
		local character = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		local egg = eggOn(character)
		expect(#egg:GetDescendants() > 0).toBe(true)
		local found: { [string]: number } = {}
		for _, descendant in egg:GetDescendants() do
			found[descendant.ClassName] = (found[descendant.ClassName] or 0) + 1
		end
		expect(found.PointLight).toBe(1)
		expect(found.ParticleEmitter).toBe(1)
		expect(found.BillboardGui).toBeNil()
		expect(found.Beam).toBeNil()
	end)

	it("copies the template and leaves the template itself alone", function()
		local character = newCharacterWithRoot()
		local template = newEggTemplate()
		local scaleBefore = template:GetScale()
		local egg = Carry.attachEgg(character, template, CARRIED_OFFSET, CARRIED_HEIGHT)
		expect(egg).never.toBe(template)
		expect(template.Parent).toBeNil()
		expect(template:GetScale()).toBe(scaleBefore)
		expect((template:FindFirstChild("body_geom") :: Part).Anchored).toBe(true)
	end)

	it("puts the egg inside the character, named CarriedEgg, and returns it", function()
		local character = newCharacterWithRoot()
		local egg = Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		expect(egg).toBe(eggOn(character))
		expect((egg :: Model).Parent).toBe(character)
	end)

	it("never leaves two eggs on one back", function()
		local character = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		local count = 0
		for _, child in character:GetChildren() do
			if child.Name == "CarriedEgg" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)

	it("does nothing for a character that has no root part", function()
		local character = Instance.new("Model")
		table.insert(madeInstances, character)
		local egg = Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		expect(egg).toBeNil()
		expect(#character:GetChildren()).toBe(0)
	end)
end)

describe("Carry.detachEgg", function()
	it("takes the egg off the back", function()
		local character = newCharacterWithRoot()
		Carry.attachEgg(character, newEggTemplate(), CARRIED_OFFSET, CARRIED_HEIGHT)
		Carry.detachEgg(character)
		expect(character:FindFirstChild("CarriedEgg")).toBeNil()
		expect(#character:GetChildren()).toBe(1) -- only the root part is left
	end)

	it("does nothing wrong when there is no egg", function()
		local character = newCharacterWithRoot()
		Carry.detachEgg(character)
		expect(#character:GetChildren()).toBe(1)
	end)
end)

describe("Carry.readCarriedEggLook", function()
	local function newAssets(attributes: { [string]: any }): Instance
		local assets = Instance.new("Folder")
		for name, value in attributes do
			assets:SetAttribute(name, value)
		end
		table.insert(madeInstances, assets)
		return assets
	end

	it("reads the offset and the height from the attributes", function()
		local assets = newAssets({ CarriedEggOffset = CFrame.new(0, 0.8, 1.9), CarriedEggHeight = 4.2 })
		local offset, height = Carry.readCarriedEggLook(assets)
		expect((offset.Position - Vector3.new(0, 0.8, 1.9)).Magnitude < 0.001).toBe(true)
		expect(height).toBe(4.2)
	end)

	it("stops with a clear message when the offset is missing", function()
		local assets = newAssets({ CarriedEggHeight = 4.2 })
		expect(function()
			Carry.readCarriedEggLook(assets)
		end).toThrow("CarriedEggOffset")
	end)

	it("stops with a clear message when the height is not a positive number", function()
		local assets = newAssets({ CarriedEggOffset = CFrame.new(), CarriedEggHeight = 0 })
		expect(function()
			Carry.readCarriedEggLook(assets)
		end).toThrow("CarriedEggHeight")
	end)
end)
