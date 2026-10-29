--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local PressingHandler = require(ServerScriptService.Server.Remotes.PressingHandler)

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
type Change = { userId: number, on: boolean }

type Rig = {
	changes: { Change }, -- what setPressing was told, in order
	advance: (seconds: number) -> (),
	send: (sender: FakePlayer, ...any) -> (),
	leave: (player: FakePlayer) -> (),
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
	local removing = newSignal()
	local changes: { Change } = {}
	local time = 100
	table.insert(
		stops,
		PressingHandler.start({
			remote = remote,
			players = { PlayerRemoving = removing } :: any,
			setPressing = function(player: any, on: boolean)
				table.insert(changes, { userId = player.UserId, on = on })
			end,
			now = function(): number
				return time
			end,
		})
	)
	return {
		changes = changes,
		advance = function(seconds: number)
			time += seconds
		end,
		send = function(sender: FakePlayer, ...: any)
			remote.OnServerEvent:Fire(sender, ...)
		end,
		leave = function(player: FakePlayer)
			removing:Fire(player)
		end,
	}
end

describe("PressingHandler", function()
	it("a true or false sets the sender's pressing", function()
		local rig = newRig()
		rig.send({ UserId = 7 }, true)
		rig.send({ UserId = 7 }, false)
		expect(rig.changes).toEqual({ { userId = 7, on = true }, { userId = 7, on = false } })
	end)

	it("anything but a boolean is ignored", function()
		local rig = newRig()
		rig.send({ UserId = 7 })
		rig.send({ UserId = 7 }, 1)
		rig.send({ UserId = 7 }, "true")
		rig.send({ UserId = 7 }, {})
		rig.send({ UserId = 7 }, nil)
		expect(#rig.changes).toBe(0)
	end)

	it("the 11th change within 1 second is ignored", function()
		local rig = newRig()
		for i = 1, 11 do
			rig.send({ UserId = 7 }, i % 2 == 1)
		end
		expect(#rig.changes).toBe(10)
	end)

	it("changes are accepted again after a second", function()
		local rig = newRig()
		for i = 1, 11 do
			rig.send({ UserId = 7 }, i % 2 == 1)
		end
		rig.advance(1)
		rig.send({ UserId = 7 }, true)
		expect(#rig.changes).toBe(11)
	end)

	it("one player's changes don't use up another player's turns", function()
		local rig = newRig()
		for _ = 1, 11 do
			rig.send({ UserId = 7 }, true)
		end
		rig.send({ UserId = 8 }, true)
		expect(rig.changes[#rig.changes]).toEqual({ userId = 8, on = true })
	end)

	it("forgets a player who leaves", function()
		local rig = newRig()
		for _ = 1, 10 do
			rig.send({ UserId = 7 }, true)
		end
		rig.leave({ UserId = 7 })
		rig.send({ UserId = 7 }, false)
		expect(#rig.changes).toBe(11)
	end)
end)
