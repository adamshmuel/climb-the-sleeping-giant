--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach

local Spawning = require(ServerScriptService.Server.Players.Spawning)

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

-- A fake Players service. Nothing is parented anywhere.
local function newPlayers(existing: { any }?)
	local list: { any } = existing or {}
	return {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function(_self: any)
			return table.clone(list)
		end,
		list = list,
	}
end

type FakePlayer = {
	UserId: number,
	DisplayName: string,
	Character: Model?,
	RespawnLocation: SpawnLocation?,
	attributes: { [string]: any },
	loadCount: number,
	kickMessage: string?,
	SetAttribute: (self: any, name: string, value: any) -> (),
	LoadCharacter: (self: any) -> (),
	Kick: (self: any, message: string?) -> (),
}

local function newPlayer(userId: number, displayName: string, hasCharacter: boolean?): FakePlayer
	local player: FakePlayer = {
		UserId = userId,
		DisplayName = displayName,
		Character = if hasCharacter then Instance.new("Model") else nil,
		RespawnLocation = nil,
		attributes = {},
		loadCount = 0,
		kickMessage = nil,
		SetAttribute = function(self: any, name: string, value: any)
			self.attributes[name] = value
		end,
		LoadCharacter = function(self: any)
			self.loadCount += 1
		end,
		Kick = function(self: any, message: string?)
			self.kickMessage = message
		end,
	}
	return player
end

-- Fake gardens: just a spawn spot and two sign labels each, with no parent.
local function newGardens(count: number): { any }
	local gardens = {}
	for index = 1, count do
		local front, back = Instance.new("TextLabel"), Instance.new("TextLabel")
		front.Text = "Old name"
		back.Text = "Old name"
		table.insert(gardens, {
			index = index,
			spawnSpot = Instance.new("SpawnLocation"),
			signLabels = { front, back },
		})
	end
	return gardens
end

local function signsOf(garden: any): string
	return `{garden.signLabels[1].Text}|{garden.signLabels[2].Text}`
end

describe("Spawning.signText", function()
	it("writes the player's name on the sign", function()
		expect(Spawning.signText("Leo")).toBe("Leo's Garden")
	end)
end)

describe("Spawning.start", function()
	local gardens: { any }
	local players: any
	local stop: (() -> ())?

	beforeEach(function()
		gardens = newGardens(8)
		players = newPlayers()
		stop = nil
	end)

	afterEach(function()
		if stop then
			stop()
		end
		for _, garden in gardens do
			garden.spawnSpot:Destroy()
			garden.signLabels[1]:Destroy()
			garden.signLabels[2]:Destroy()
		end
	end)

	it("gives a new player the first garden and spawns them on its spot", function()
		stop = Spawning.start(gardens :: any, players)
		local leo = newPlayer(1001, "Leo")
		players.PlayerAdded:Fire(leo)
		expect(leo.attributes.PlotIndex).toBe(1)
		expect(leo.RespawnLocation).toBe(gardens[1].spawnSpot)
	end)

	it("writes the player's name on both sides of their gate sign", function()
		stop = Spawning.start(gardens :: any, players)
		players.PlayerAdded:Fire(newPlayer(1001, "Leo"))
		expect(signsOf(gardens[1])).toBe("Leo's Garden|Leo's Garden")
	end)

	it("leaves the sign of an empty garden blank", function()
		stop = Spawning.start(gardens :: any, players)
		expect(signsOf(gardens[3])).toBe("|")
	end)

	it("handles players who were already in the game", function()
		local mia = newPlayer(1002, "Mia")
		players = newPlayers({ mia })
		stop = Spawning.start(gardens :: any, players)
		expect(mia.attributes.PlotIndex).toBe(1)
		expect(signsOf(gardens[1])).toBe("Mia's Garden|Mia's Garden")
	end)

	it("respawns a player whose character already appeared somewhere else", function()
		local mia = newPlayer(1002, "Mia", true)
		players = newPlayers({ mia })
		stop = Spawning.start(gardens :: any, players)
		expect(mia.loadCount).toBe(1)
	end)

	it("does not respawn a player who has no character yet", function()
		stop = Spawning.start(gardens :: any, players)
		local leo = newPlayer(1001, "Leo")
		players.PlayerAdded:Fire(leo)
		expect(leo.loadCount).toBe(0)
	end)

	it("sends the next player to the next garden", function()
		stop = Spawning.start(gardens :: any, players)
		players.PlayerAdded:Fire(newPlayer(1001, "Leo"))
		local zoe = newPlayer(1003, "Zoe")
		players.PlayerAdded:Fire(zoe)
		expect(zoe.attributes.PlotIndex).toBe(2)
		expect(zoe.RespawnLocation).toBe(gardens[2].spawnSpot)
	end)

	it("kicks a ninth player with the full-valley message", function()
		stop = Spawning.start(gardens :: any, players)
		for userId = 1, 8 do
			players.PlayerAdded:Fire(newPlayer(userId, `P{userId}`))
		end
		local ninth = newPlayer(9, "Late")
		players.PlayerAdded:Fire(ninth)
		expect(ninth.kickMessage).toBe("This valley is full. Please join another server.")
		expect(ninth.attributes.PlotIndex).toBeNil()
	end)

	it("frees the garden and blanks its sign when the player leaves", function()
		stop = Spawning.start(gardens :: any, players)
		local leo = newPlayer(1001, "Leo")
		players.PlayerAdded:Fire(leo)
		players.PlayerRemoving:Fire(leo)
		expect(signsOf(gardens[1])).toBe("|")
		local zoe = newPlayer(1003, "Zoe")
		players.PlayerAdded:Fire(zoe)
		expect(zoe.attributes.PlotIndex).toBe(1)
		expect(signsOf(gardens[1])).toBe("Zoe's Garden|Zoe's Garden")
	end)

	it("does not touch other gardens when a kicked player is removed", function()
		stop = Spawning.start(gardens :: any, players)
		for userId = 1, 8 do
			players.PlayerAdded:Fire(newPlayer(userId, `P{userId}`))
		end
		local ninth = newPlayer(9, "Late")
		players.PlayerAdded:Fire(ninth)
		players.PlayerRemoving:Fire(ninth)
		expect(signsOf(gardens[1])).toBe("P1's Garden|P1's Garden")
		expect(signsOf(gardens[8])).toBe("P8's Garden|P8's Garden")
	end)

	it("stops listening when stopped", function()
		local stopNow = Spawning.start(gardens :: any, players)
		stopNow()
		local leo = newPlayer(1001, "Leo")
		players.PlayerAdded:Fire(leo)
		expect(leo.attributes.PlotIndex).toBeNil()
	end)
end)
