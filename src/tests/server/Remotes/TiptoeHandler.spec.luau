--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local TiptoeHandler = require(ServerScriptService.Server.Remotes.TiptoeHandler)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau. Fire passes on any
-- number of values, like the real OnServerEvent (the sender first, then what they sent).
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

type FakePlayer = {
	UserId: number,
	Name: string,
	attributes: { [string]: any },
	SetAttribute: (self: any, name: string, value: any) -> (),
	GetAttribute: (self: any, name: string) -> any,
}

local function newPlayer(userId: number): FakePlayer
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		Name = `Player{userId}`,
		attributes = attributes,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
	}
end

type Rig = {
	remote: any,
	players: any,
	player: FakePlayer,
	advance: (seconds: number) -> (),
	send: (sender: FakePlayer, ...any) -> (),
	stop: () -> (),
}

local stops: { () -> () } = {}

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
end)

-- Starts the handler on a fake remote, a fake Players service and a clock the test moves by hand.
local function newRig(): Rig
	local remote: any = { OnServerEvent = newSignal() }
	local players: any = { PlayerRemoving = newSignal() }
	local time = 100
	local stop = TiptoeHandler.start({
		remote = remote,
		players = players,
		now = function(): number
			return time
		end,
	})
	table.insert(stops, stop)
	return {
		remote = remote,
		players = players,
		player = newPlayer(1),
		advance = function(seconds: number)
			time += seconds
		end,
		send = function(sender: FakePlayer, ...: any)
			remote.OnServerEvent:Fire(sender, ...)
		end,
		stop = stop,
	}
end

describe("TiptoeHandler: what a message may say", function()
	it("sets the sender's Tiptoe to true when they send true", function()
		local rig = newRig()
		rig.send(rig.player, true)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
	end)

	it("sets it back to false when they send false", function()
		local rig = newRig()
		rig.send(rig.player, true)
		rig.send(rig.player, false)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(false)
	end)

	it("ignores the text 'yes'", function()
		local rig = newRig()
		rig.send(rig.player, "yes")
		expect(rig.player:GetAttribute("Tiptoe")).toBeNil()
	end)

	it("ignores the number 1", function()
		local rig = newRig()
		rig.send(rig.player, 1)
		expect(rig.player:GetAttribute("Tiptoe")).toBeNil()
	end)

	it("ignores a message with nothing in it", function()
		local rig = newRig()
		rig.send(rig.player, true)
		rig.send(rig.player, nil)
		rig.send(rig.player)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
	end)

	it("ignores a table", function()
		local rig = newRig()
		rig.send(rig.player, { true })
		rig.send(rig.player, {})
		expect(rig.player:GetAttribute("Tiptoe")).toBeNil()
	end)

	it("ignores NaN (a number that is not a number)", function()
		local rig = newRig()
		rig.send(rig.player, 0 / 0)
		expect(rig.player:GetAttribute("Tiptoe")).toBeNil()
	end)

	it("leaves Tiptoe as it was when a wrong message arrives", function()
		local rig = newRig()
		rig.send(rig.player, true)
		rig.send(rig.player, "no")
		rig.send(rig.player, 0)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
	end)
end)

describe("TiptoeHandler: whose Tiptoe changes", function()
	it("changes only the sender's own Tiptoe", function()
		local rig = newRig()
		local other = newPlayer(2)
		other:SetAttribute("Tiptoe", false)
		rig.send(rig.player, true)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
		expect(other:GetAttribute("Tiptoe")).toBe(false)
	end)

	it("never changes another player's Tiptoe, even if the message names one", function()
		local rig = newRig()
		local other = newPlayer(2)
		rig.send(rig.player, true, other)
		rig.send(rig.player, other, true)
		expect(other:GetAttribute("Tiptoe")).toBeNil()
	end)
end)

describe("TiptoeHandler: how often", function()
	it("ignores the 6th message within one second", function()
		local rig = newRig()
		-- Five messages: on, off, on, off, on. The 6th (off) must be ignored.
		for index = 1, 5 do
			rig.send(rig.player, index % 2 == 1)
		end
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
		rig.send(rig.player, false)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
	end)

	it("works again one second later", function()
		local rig = newRig()
		for index = 1, 5 do
			rig.send(rig.player, index % 2 == 1)
		end
		rig.send(rig.player, false)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
		rig.advance(1)
		rig.send(rig.player, false)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(false)
	end)

	it("counts wrong messages too, so spam of any kind is limited", function()
		local rig = newRig()
		for _ = 1, 5 do
			rig.send(rig.player, "spam")
		end
		rig.send(rig.player, true)
		expect(rig.player:GetAttribute("Tiptoe")).toBeNil()
	end)

	it("limits each player on their own", function()
		local rig = newRig()
		local other = newPlayer(2)
		for _ = 1, 5 do
			rig.send(rig.player, true)
		end
		rig.send(other, true)
		expect(other:GetAttribute("Tiptoe")).toBe(true)
	end)

	it("gives a player who left and came back a fresh allowance", function()
		local rig = newRig()
		for index = 1, 5 do
			rig.send(rig.player, index % 2 == 1)
		end
		rig.send(rig.player, false)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(true)
		rig.players.PlayerRemoving:Fire(rig.player)
		rig.send(rig.player, false)
		expect(rig.player:GetAttribute("Tiptoe")).toBe(false)
	end)
end)

describe("TiptoeHandler.start: cleanup", function()
	it("stops listening when it is stopped", function()
		local rig = newRig()
		expect(rig.remote.OnServerEvent:count()).toBe(1)
		expect(rig.players.PlayerRemoving:count()).toBe(1)
		rig.stop()
		expect(rig.remote.OnServerEvent:count()).toBe(0)
		expect(rig.players.PlayerRemoving:count()).toBe(0)
		rig.send(rig.player, true)
		expect(rig.player:GetAttribute("Tiptoe")).toBeNil()
	end)
end)
