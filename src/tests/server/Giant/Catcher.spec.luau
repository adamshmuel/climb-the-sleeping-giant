--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Catcher = require(ServerScriptService.Server.Giant.Catcher)

-- Characters and spawn spots are real instances that are never parented anywhere, so nothing is put in Workspace.
-- The root is 2 x 2 x 1 and the Humanoid's HipHeight is 2, so a player standing on a spot has the root's centre
-- 2 + 1 = 3 studs above the spot's top.
local REST_ABOVE_TOP = 3
-- The centre of his face is about here in the place.
local FACE_POINT = Vector3.new(0.95, 95.3, 0.01)

local madeInstances: { Instance } = {}
local catchers: { Catcher.Catcher } = {}

afterEach(function()
	for _, catcher in catchers do
		catcher:stop()
	end
	table.clear(catchers)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

type LogEntry = { what: string, rootPosition: Vector3?, userId: number }

type FakePlayer = {
	UserId: number,
	Character: Model?,
	root: BasePart?,
	egg: BasePart?,
	attributes: { [string]: any },
	attributeWrites: number, -- how many times anything called SetAttribute on the player
	GetAttribute: (self: any, name: string) -> any,
	SetAttribute: (self: any, name: string, value: any) -> (),
}

type Options = { noRoot: boolean?, noHumanoid: boolean?, noCharacter: boolean?, plotIndex: number? }

-- A player with a character: root (2 x 2 x 1) at `position`, a Humanoid with HipHeight 2, and a "CarriedEgg" part
-- welded to the root, like the egg on a carrier's back. Tiptoe is on, EggsHome is 3.
local function newPlayer(userId: number, position: Vector3, options: Options?): FakePlayer
	local player: FakePlayer
	player = {
		UserId = userId,
		Character = nil,
		root = nil,
		egg = nil,
		attributes = {
			PlotIndex = if options ~= nil and options.plotIndex ~= nil then options.plotIndex else 1,
			Tiptoe = true,
			EggsHome = 3,
			Carrying = "Rare",
		},
		attributeWrites = 0,
		GetAttribute = function(self: any, name: string): any
			return self.attributes[name]
		end,
		SetAttribute = function(self: any, name: string, value: any)
			self.attributeWrites += 1
			self.attributes[name] = value
		end,
	}
	if options ~= nil and options.noCharacter == true then
		return player
	end
	local character = Instance.new("Model")
	character.Name = `Character{userId}`
	table.insert(madeInstances, character)
	if options == nil or options.noHumanoid ~= true then
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 2
		humanoid.Parent = character
	end
	if options == nil or options.noRoot ~= true then
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = CFrame.new(position)
		root.Parent = character
		character.PrimaryPart = root
		local egg = Instance.new("Part")
		egg.Name = "CarriedEgg"
		egg.Size = Vector3.new(1, 1.5, 1)
		egg.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 1.5))
		egg.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = egg
		weld.Parent = egg
		player.root = root
		player.egg = egg
	end
	player.Character = character
	return player
end

-- A spawn spot like the real one: 6 x 1 x 6.
local function newSpot(position: Vector3): BasePart
	local spot = Instance.new("Part")
	spot.Size = Vector3.new(6, 1, 6)
	spot.CFrame = CFrame.new(position)
	table.insert(madeInstances, spot)
	return spot
end

local SPOT_ONE_POSITION = Vector3.new(-70, 1.5, 40)
local SPOT_TWO_POSITION = Vector3.new(60, 2.5, -45)

type Harness = {
	catcher: Catcher.Catcher,
	players: { [number]: FakePlayer },
	log: { LogEntry },
	returned: { number }, -- the user ids grab:returnEgg was called for
	caught: { number }, -- the user ids fireCaught was called for
	heardCaught: { { player: any, rarity: any, carryingThen: any } }, -- what the caught signal said, in order
	carrying: { [number]: boolean }, -- who still carries an egg (returnEgg gives nil to the others)
}

local function rootPositionOf(player: FakePlayer?): Vector3?
	if player ~= nil and player.root ~= nil then
		return (player.root :: BasePart).Position
	end
	return nil
end

local function newHarness(): Harness
	local harness: Harness = {
		catcher = nil :: any,
		players = {},
		log = {},
		returned = {},
		caught = {},
		heardCaught = {},
		carrying = {},
	}
	local gardens = {
		{ index = 1, spawnSpot = newSpot(SPOT_ONE_POSITION) },
		{ index = 2, spawnSpot = newSpot(SPOT_TWO_POSITION) },
	}
	harness.catcher = Catcher.new({
		players = {
			GetPlayerByUserId = function(_self: any, userId: number)
				return harness.players[userId]
			end,
		},
		grab = {
			returnEgg = function(_self: any, player: any): (("back" | "gone")?, string?)
				table.insert(harness.returned, player.UserId)
				table.insert(harness.log, {
					what = "returnEgg",
					rootPosition = rootPositionOf(harness.players[player.UserId]),
					userId = player.UserId,
				})
				if harness.carrying[player.UserId] == false then
					return nil, nil
				end
				-- The real Grab clears Carrying when it takes the egg back. (Written straight into the table, so the
				-- "never touches" test below still counts only SetAttribute calls.)
				harness.players[player.UserId].attributes.Carrying = nil
				return "back", "Egg_Common_1"
			end,
		},
		-- Only index and spawnSpot are used, so the stand-ins have nothing else.
		gardens = gardens :: any,
		facePoint = FACE_POINT,
		fireCaught = function(player: any)
			table.insert(harness.caught, player.UserId)
			table.insert(harness.log, {
				what = "Caught",
				rootPosition = rootPositionOf(harness.players[player.UserId]),
				userId = player.UserId,
			})
		end,
	})
	harness.catcher.caught:Connect(function(player, rarity)
		table.insert(
			harness.heardCaught,
			{ player = player, rarity = rarity, carryingThen = player:GetAttribute("Carrying") }
		)
	end)
	table.insert(catchers, harness.catcher)
	return harness
end

local function add(harness: Harness, player: FakePlayer): FakePlayer
	harness.players[player.UserId] = player
	return player
end

local function rootOf(player: FakePlayer): BasePart
	return player.root :: BasePart
end

describe("Catcher.catch", function()
	it("sends a caught carrier's egg back, then moves them, then fires Caught, in that order", function()
		local harness = newHarness()
		local start = Vector3.new(10, 3, 10)
		local player = add(harness, newPlayer(1, start, { plotIndex = 1 }))
		harness.catcher:catch(1)
		expect(#harness.log).toBe(2)
		expect(harness.log[1].what).toBe("returnEgg")
		expect(harness.log[1].userId).toBe(1)
		-- The egg went back while the player still stood where they were caught.
		expect((harness.log[1].rootPosition :: Vector3).X).toBeCloseTo(start.X, 3)
		expect((harness.log[1].rootPosition :: Vector3).Z).toBeCloseTo(start.Z, 3)
		expect(harness.log[2].what).toBe("Caught")
		expect(harness.log[2].userId).toBe(1)
		-- Caught fired after the move.
		expect((harness.log[2].rootPosition :: Vector3).X).toBeCloseTo(SPOT_ONE_POSITION.X, 3)
		expect((harness.log[2].rootPosition :: Vector3).Z).toBeCloseTo(SPOT_ONE_POSITION.Z, 3)
		expect(rootOf(player).Position.X).toBeCloseTo(SPOT_ONE_POSITION.X, 3)
	end)

	it("stands the root on the top of their own spawn spot", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.new(10, 3, 10), { plotIndex = 1 }))
		harness.catcher:catch(1)
		local position = rootOf(player).Position
		-- The spot's top is 0.5 above its middle (it is 1 stud thick).
		local expectedHeight = SPOT_ONE_POSITION.Y + 0.5 + REST_ABOVE_TOP
		expect(math.abs(position.Y - expectedHeight) <= 0.01).toBe(true)
		expect(position.X).toBeCloseTo(SPOT_ONE_POSITION.X, 3)
		expect(position.Z).toBeCloseTo(SPOT_ONE_POSITION.Z, 3)
	end)

	it("uses the spawn spot whose garden number is the player's PlotIndex", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(7, Vector3.new(10, 3, 10), { plotIndex = 2 }))
		harness.catcher:catch(7)
		local position = rootOf(player).Position
		expect(position.X).toBeCloseTo(SPOT_TWO_POSITION.X, 3)
		expect(position.Z).toBeCloseTo(SPOT_TWO_POSITION.Z, 3)
		expect(math.abs(position.Y - (SPOT_TWO_POSITION.Y + 0.5 + REST_ABOVE_TOP)) <= 0.01).toBe(true)
	end)

	it("turns them to face him, left-right only, however they were tipped", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.new(10, 3, 10), { plotIndex = 1 }))
		local root = rootOf(player)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, 10))
			* CFrame.Angles(math.rad(30), 0, 0)
		harness.catcher:catch(1)
		local expected = Vector3.new(FACE_POINT.X - SPOT_ONE_POSITION.X, 0, FACE_POINT.Z - SPOT_ONE_POSITION.Z).Unit
		local look = root.CFrame.LookVector
		expect(root.CFrame.UpVector.Y).toBeCloseTo(1, 3)
		expect(look.Y).toBeCloseTo(0, 3)
		expect(look.X).toBeCloseTo(expected.X, 3)
		expect(look.Z).toBeCloseTo(expected.Z, 3)
	end)

	it("stops any speed they had", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.new(10, 3, 10), { plotIndex = 1 }))
		local root = rootOf(player)
		root.AssemblyLinearVelocity = Vector3.new(5, -60, 3)
		root.AssemblyAngularVelocity = Vector3.new(1, 2, 3)
		harness.catcher:catch(1)
		expect(root.AssemblyLinearVelocity).toEqual(Vector3.zero)
		expect(root.AssemblyAngularVelocity).toEqual(Vector3.zero)
	end)

	it("moves the whole character, so a part welded to it keeps its place", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.new(10, 3, 10), { plotIndex = 1 }))
		local root = rootOf(player)
		local egg = player.egg :: BasePart
		local before = root.CFrame:ToObjectSpace(egg.CFrame)
		harness.catcher:catch(1)
		local after = root.CFrame:ToObjectSpace(egg.CFrame)
		expect(after.Position.X).toBeCloseTo(before.Position.X, 3)
		expect(after.Position.Y).toBeCloseTo(before.Position.Y, 3)
		expect(after.Position.Z).toBeCloseTo(before.Position.Z, 3)
		expect(egg.Parent).toBe(player.Character)
	end)

	it("never touches Tiptoe, EggsHome or PlotIndex", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.new(10, 3, 10), { plotIndex = 2 }))
		harness.catcher:catch(1)
		expect(player.attributeWrites).toBe(0)
		expect(player.attributes.Tiptoe).toBe(true)
		expect(player.attributes.EggsHome).toBe(3)
		expect(player.attributes.PlotIndex).toBe(2)
	end)

	it("fires Caught with that player", function()
		local harness = newHarness()
		add(harness, newPlayer(1, Vector3.new(10, 3, 10)))
		add(harness, newPlayer(2, Vector3.new(20, 3, 10)))
		harness.catcher:catch(2)
		expect(harness.caught).toEqual({ 2 })
		expect(harness.returned).toEqual({ 2 })
	end)

	it("does nothing more when the player carries nothing any more: no move, no Caught", function()
		local harness = newHarness()
		local start = Vector3.new(10, 3, 10)
		local player = add(harness, newPlayer(1, start))
		harness.carrying[1] = false
		harness.catcher:catch(1)
		expect(harness.returned).toEqual({ 1 })
		expect(harness.caught).toEqual({})
		expect(rootOf(player).Position.X).toBeCloseTo(start.X, 3)
		expect(rootOf(player).Position.Z).toBeCloseTo(start.Z, 3)
	end)

	it("does nothing for an unknown user id", function()
		local harness = newHarness()
		add(harness, newPlayer(1, Vector3.new(10, 3, 10)))
		harness.catcher:catch(99)
		expect(harness.returned).toEqual({})
		expect(harness.caught).toEqual({})
	end)

	it("returns the egg and fires Caught for a player with no character, and moves nothing", function()
		local harness = newHarness()
		add(harness, newPlayer(1, Vector3.zero, { noCharacter = true }))
		harness.catcher:catch(1)
		expect(harness.returned).toEqual({ 1 })
		expect(harness.caught).toEqual({ 1 })
	end)

	it("returns the egg and fires Caught for a character with no HumanoidRootPart, and moves nothing", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.zero, { noRoot = true }))
		harness.catcher:catch(1)
		expect(harness.returned).toEqual({ 1 })
		expect(harness.caught).toEqual({ 1 })
		expect((player.Character :: Model):GetPivot().Position).toEqual(Vector3.zero)
	end)

	it("returns the egg and fires Caught for a character with no Humanoid, and moves nothing", function()
		local harness = newHarness()
		local start = Vector3.new(10, 3, 10)
		local player = add(harness, newPlayer(1, start, { noHumanoid = true }))
		harness.catcher:catch(1)
		expect(harness.returned).toEqual({ 1 })
		expect(harness.caught).toEqual({ 1 })
		expect(rootOf(player).Position.X).toBeCloseTo(start.X, 3)
	end)

	it("returns the egg and fires Caught, but moves nothing, when PlotIndex names no garden", function()
		local harness = newHarness()
		local start = Vector3.new(10, 3, 10)
		local player = add(harness, newPlayer(1, start, { plotIndex = 9 }))
		harness.catcher:catch(1)
		expect(harness.returned).toEqual({ 1 })
		expect(harness.caught).toEqual({ 1 })
		expect(rootOf(player).Position.X).toBeCloseTo(start.X, 3)
		expect(rootOf(player).Position.Z).toBeCloseTo(start.Z, 3)
	end)

	it("returns the egg and fires Caught, but moves nothing, when the player has no PlotIndex", function()
		local harness = newHarness()
		local start = Vector3.new(10, 3, 10)
		local player = add(harness, newPlayer(1, start))
		player.attributes.PlotIndex = nil
		harness.catcher:catch(1)
		expect(harness.caught).toEqual({ 1 })
		expect(rootOf(player).Position.X).toBeCloseTo(start.X, 3)
	end)
end)

describe("Catcher caught signal", function()
	it("fires after Caught with the player and the rarity of the egg they lost", function()
		local harness = newHarness()
		local player = add(harness, newPlayer(1, Vector3.new(10, 3, 10)))
		player.attributes.Carrying = "Uncommon"
		harness.catcher:catch(1)
		expect(#harness.heardCaught).toBe(1)
		expect(harness.heardCaught[1].player).toBe(player)
		expect(harness.heardCaught[1].rarity).toBe("Uncommon")
		-- The egg was already taken off their back when the signal fired.
		expect(harness.heardCaught[1].carryingThen).toBeNil()
		expect(harness.log[#harness.log].what).toBe("Caught")
	end)

	it("says Rare for a Rare and Common for a Common", function()
		local harness = newHarness()
		local rare = add(harness, newPlayer(1, Vector3.new(10, 3, 10)))
		local common = add(harness, newPlayer(2, Vector3.new(20, 3, 10)))
		rare.attributes.Carrying = "Rare"
		common.attributes.Carrying = "Common"
		harness.catcher:catch(1)
		harness.catcher:catch(2)
		expect(harness.heardCaught[1].rarity).toBe("Rare")
		expect(harness.heardCaught[2].rarity).toBe("Common")
	end)

	it("fires nothing for a player who carries nothing", function()
		local harness = newHarness()
		add(harness, newPlayer(1, Vector3.new(10, 3, 10)))
		harness.carrying[1] = false
		harness.catcher:catch(1)
		expect(harness.heardCaught).toEqual({})
	end)

	it("fires nothing for an unknown user id", function()
		local harness = newHarness()
		harness.catcher:catch(99)
		expect(harness.heardCaught).toEqual({})
	end)

	it("still fires for a player with no character", function()
		local harness = newHarness()
		add(harness, newPlayer(1, Vector3.zero, { noCharacter = true }))
		harness.catcher:catch(1)
		expect(#harness.heardCaught).toBe(1)
	end)

	it("is destroyed by stop, and stop can be called twice", function()
		local harness = newHarness()
		local connection = harness.catcher.caught:Connect(function() end)
		expect(connection.Connected).toBe(true)
		harness.catcher:stop()
		harness.catcher:stop()
		expect(connection.Connected).toBe(false)
	end)
end)
