--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)

-- Bonker is required inside each test, so a missing module turns each test red on its own.
local requireModule: (Instance) -> any = require :: any
local function loadBonker(): any
	return requireModule(ServerScriptService.Server.Giant.Bonker)
end

-- The bonk lasts the three tumble parts together (Config.Wake, spec section 5 "Tumble time").
local BONK_SECONDS = Config.Wake.TumbleDownSeconds + Config.Wake.TumbleStillSeconds + Config.Wake.TumbleUpSeconds

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
		count = function(): number
			return #handlers
		end,
	}
end

type Timer = { seconds: number, callback: () -> (), cancelled: boolean, fired: boolean }

-- A fake delay: it records every timer and never runs one by itself. A test fires it by hand.
local function newDelay()
	local timers: { Timer } = {}
	local function delay(seconds: number, callback: () -> ()): () -> ()
		local timer: Timer = { seconds = seconds, callback = callback, cancelled = false, fired = false }
		table.insert(timers, timer)
		return function()
			timer.cancelled = true
		end
	end
	local function fire(timer: Timer)
		if not timer.cancelled then
			timer.fired = true
			timer.callback()
		end
	end
	return delay, timers, fire
end

local madeInstances: { Instance } = {}
local bonkers: { any } = {}

afterEach(function()
	for _, bonker in bonkers do
		if bonker.destroy ~= nil then
			bonker:destroy()
		end
	end
	table.clear(bonkers)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A player with a character whose root is at `position`. Its attributes live in a table. Nothing is parented anywhere.
local function newPlayer(userId: number, position: Vector3)
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = character
	table.insert(madeInstances, character)
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		Name = `Player{userId}`,
		Character = character,
		root = root,
		attributes = attributes,
		CharacterAdded = newSignal(),
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
	}
end

local function newBonker()
	local players = { PlayerRemoving = newSignal() }
	local delay, timers, fire = newDelay()
	local bonker = loadBonker().new({ players = players, delay = delay })
	table.insert(bonkers, bonker)
	return bonker, players, timers, fire
end

describe("Bonker", function()
	it("marks a ground bonk 'Ground' and clears it after the delay it asked for", function()
		local bonker, _players, timers, fire = newBonker()
		local player = newPlayer(1, Vector3.new(0, 5, 0))
		bonker:bonk(player, false)
		expect(player.attributes.Bonked).toBe("Ground")
		expect(#timers).toBe(1)
		expect(timers[1].seconds).toBeCloseTo(BONK_SECONDS, 5)
		fire(timers[1])
		expect(player.attributes.Bonked).toBe(nil)
	end)

	it("marks a bonk on a climber 'Ladder'", function()
		local bonker = newBonker()
		local player = newPlayer(1, Vector3.new(0, 5, 0))
		bonker:bonk(player, true)
		expect(player.attributes.Bonked).toBe("Ladder")
	end)

	it("never moves the bonked player's root", function()
		local bonker, _players, timers, fire = newBonker()
		local start = Vector3.new(3, 40, -7)
		local player = newPlayer(1, start)
		bonker:bonk(player, true)
		expect((player.root.Position - start).Magnitude).toBeCloseTo(0, 3)
		fire(timers[1])
		expect((player.root.Position - start).Magnitude).toBeCloseTo(0, 3)
	end)

	it("cancels the timer and leaves nothing behind when the player leaves mid-bonk", function()
		local bonker, players, timers = newBonker()
		local player = newPlayer(1, Vector3.new(0, 5, 0))
		bonker:bonk(player, false)
		players.PlayerRemoving:Fire(player)
		expect(timers[1].cancelled).toBe(true)
		expect(player.attributes.Bonked).toBe(nil)
		expect(player.CharacterAdded.count()).toBe(0)
	end)

	it("clears Bonked at once on a new character", function()
		local bonker, _players, timers = newBonker()
		local player = newPlayer(1, Vector3.new(0, 5, 0))
		bonker:bonk(player, false)
		player.CharacterAdded:Fire(Instance.new("Model"))
		expect(player.attributes.Bonked).toBe(nil)
		expect(timers[1].cancelled).toBe(true)
	end)

	it("starts no second timer and fires bonked once for a bonk while bonked", function()
		local bonker, _players, timers = newBonker()
		local player = newPlayer(1, Vector3.new(0, 5, 0))
		local fired = 0
		bonker.bonked:Connect(function()
			fired += 1
		end)
		bonker:bonk(player, false)
		bonker:bonk(player, true)
		expect(#timers).toBe(1)
		expect(fired).toBe(1)
		expect(player.attributes.Bonked).toBe("Ground")
	end)
end)
