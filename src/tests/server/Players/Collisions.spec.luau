--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Collisions = require(ServerScriptService.Server.Players.Collisions)

-- A stand-in for PhysicsService that records what it is asked to do.
local function newPhysics(alreadyRegistered: boolean?)
	local physics = {
		registered = alreadyRegistered or false,
		registerCalls = 0,
		collidable = {} :: { [string]: boolean },
	}
	function physics.IsCollisionGroupRegistered(self: any, _name: string): boolean
		return self.registered
	end
	function physics.RegisterCollisionGroup(self: any, _name: string)
		self.registered = true
		self.registerCalls += 1
	end
	function physics.CollisionGroupSetCollidable(self: any, first: string, second: string, collidable: boolean)
		self.collidable[`{first}|{second}`] = collidable
	end
	return physics
end

describe("Collisions.setupGroup", function()
	it("registers the Players group once", function()
		local physics = newPhysics(false)
		Collisions.setupGroup(physics)
		expect(physics.registerCalls).toBe(1)
		Collisions.setupGroup(physics)
		expect(physics.registerCalls).toBe(1)
	end)

	it("players don't collide with players", function()
		local physics = newPhysics(false)
		Collisions.setupGroup(physics)
		expect(physics.collidable["Players|Players"]).toBe(false)
	end)
end)

-- A fake character: a model with a few parts, no parent. Destroy it after the test.
local function newCharacter(): Model
	local character = Instance.new("Model")
	for _, name in { "HumanoidRootPart", "Head", "LeftArm" } do
		local part = Instance.new("Part")
		part.Name = name
		part.Parent = character
	end
	return character
end

describe("Collisions.addCharacter", function()
	it("puts every part of a character in the Players group", function()
		local character = newCharacter()
		local cleanup = Collisions.addCharacter(character)
		for _, part in character:GetChildren() do
			expect((part :: BasePart).CollisionGroup).toBe("Players")
		end
		cleanup()
		character:Destroy()
	end)

	it("puts parts added later in the Players group", function()
		local character = newCharacter()
		local cleanup = Collisions.addCharacter(character)
		local accessory = Instance.new("Model")
		local handle = Instance.new("Part")
		handle.Parent = accessory
		accessory.Parent = character -- an accessory arrives with a part inside it
		task.wait() -- Roblox runs DescendantAdded handlers after the current code yields
		expect(handle.CollisionGroup).toBe("Players")
		cleanup()
		character:Destroy()
	end)

	it("stops watching a character after cleanup", function()
		local character = newCharacter()
		local cleanup = Collisions.addCharacter(character)
		cleanup()
		local lateGuest = Instance.new("Part")
		lateGuest.Parent = character
		task.wait()
		expect(lateGuest.CollisionGroup).toBe("Default")
		character:Destroy()
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

local function newPlayer(character: Model?)
	return { Character = character, CharacterAdded = newSignal() }
end

local function newPlayers(existing: { any })
	return {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function(_self: any)
			return table.clone(existing)
		end,
	}
end

describe("Collisions.start", function()
	it("handles players who are already in the game and new ones", function()
		local physics = newPhysics(false)
		local firstCharacter = newCharacter()
		local first = newPlayer(firstCharacter)
		local players = newPlayers({ first })
		local stop = Collisions.start(players :: any, physics)

		-- the group is set up, and the player who was already here is in it
		expect(physics.collidable["Players|Players"]).toBe(false)
		expect((firstCharacter:FindFirstChild("Head") :: BasePart).CollisionGroup).toBe("Players")

		-- a player who joins later, and gets a character after that
		local joiner = newPlayer(nil)
		players.PlayerAdded:Fire(joiner)
		local joinerCharacter = newCharacter()
		joiner.CharacterAdded:Fire(joinerCharacter)
		expect((joinerCharacter:FindFirstChild("Head") :: BasePart).CollisionGroup).toBe("Players")

		-- a respawn: the new character is handled, and the old one is no longer watched
		local respawned = newCharacter()
		first.CharacterAdded:Fire(respawned)
		expect((respawned:FindFirstChild("Head") :: BasePart).CollisionGroup).toBe("Players")
		local lateGuest = Instance.new("Part")
		lateGuest.Parent = firstCharacter
		task.wait()
		expect(lateGuest.CollisionGroup).toBe("Default")

		stop()
		for _, model in { firstCharacter, joinerCharacter, respawned } do
			model:Destroy()
		end
	end)

	it("stops watching a player who leaves", function()
		local physics = newPhysics(false)
		local player = newPlayer(nil)
		local players = newPlayers({ player })
		local stop = Collisions.start(players :: any, physics)
		players.PlayerRemoving:Fire(player)
		local character = newCharacter()
		player.CharacterAdded:Fire(character)
		expect((character:FindFirstChild("Head") :: BasePart).CollisionGroup).toBe("Default")
		stop()
		character:Destroy()
	end)
end)
