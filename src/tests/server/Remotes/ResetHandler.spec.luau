--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local ResetHandler = require(ServerScriptService.Server.Remotes.ResetHandler)

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
	}
end

type FakePlayer = { UserId: number }

type Rig = {
	reset: { number }, -- the user ids that were reset, in order
	advance: (seconds: number) -> (),
	send: (sender: FakePlayer, ...any) -> (),
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
	local reset: { number } = {}
	local time = 100
	table.insert(
		stops,
		ResetHandler.start({
			remote = remote,
			players = { PlayerRemoving = newSignal() } :: any,
			reset = function(player: any)
				table.insert(reset, player.UserId)
			end,
			now = function(): number
				return time
			end,
		})
	)
	return {
		reset = reset,
		advance = function(seconds: number)
			time += seconds
		end,
		send = function(sender: FakePlayer, ...: any)
			remote.OnServerEvent:Fire(sender, ...)
		end,
	}
end

describe("ResetHandler", function()
	it("a Reset request resets the player who sent it", function()
		local rig = newRig()
		rig.send({ UserId = 7 }, "anything", 5)
		expect(rig.reset).toEqual({ 7 })
	end)

	it("a second request within 2 seconds is ignored", function()
		local rig = newRig()
		rig.send({ UserId = 7 })
		rig.advance(1.9)
		rig.send({ UserId = 7 })
		expect(rig.reset).toEqual({ 7 })
	end)

	it("a request 2 seconds later is accepted", function()
		local rig = newRig()
		rig.send({ UserId = 7 })
		rig.advance(2)
		rig.send({ UserId = 7 })
		expect(rig.reset).toEqual({ 7, 7 })
	end)

	it("one player's request does not use up another player's turn", function()
		local rig = newRig()
		rig.send({ UserId = 7 })
		rig.send({ UserId = 8 })
		expect(rig.reset).toEqual({ 7, 8 })
	end)
end)
