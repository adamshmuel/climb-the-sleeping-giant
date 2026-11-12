--!strict
-- The server's side of the music button (plan 7 Task 17; spec 7 section 10, Rule 99). A client says "my music is on"
-- or "off" (SetMusic). The handler checks the message and tells Analytics only when the answer really changed.
--
-- The shape the code must have (Step 2 builds it), a copy of TiptoeHandler's:
--   MusicHandler.start(deps) -> stop
--   deps.remote   { OnServerEvent }  fires with the sender, then what they sent
--   deps.players  { PlayerRemoving }
--   deps.now      () -> number, a clock in seconds
--   deps.changed  Signal<number, boolean>: (UserId, on) fired once per real change. A player's first answer is
--                 compared with `true` (the music starts on), so a first `true` is no change.
-- Order per message: rate limit (5 per second), then boolean check, then compare with the last answer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Signal = require(ReplicatedStorage.Packages.Signal)
local MusicHandler = require(ServerScriptService.Server.Remotes.MusicHandler)

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

type FakePlayer = { UserId: number, Name: string }

local function newPlayer(userId: number): FakePlayer
	return { UserId = userId, Name = `Player{userId}` }
end

type Change = { userId: number, on: boolean }

type Rig = {
	remote: any,
	players: any,
	player: FakePlayer,
	changes: { Change },
	advance: (seconds: number) -> (),
	send: (sender: FakePlayer, ...any) -> (),
	stop: () -> (),
}

local stops: { () -> () } = {}
local signals: { any } = {}

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, signal in signals do
		signal:Destroy()
	end
	table.clear(signals)
end)

-- Starts the handler on a fake remote, a fake Players service and a clock the test moves by hand. `changes` lists
-- everything the `changed` signal fired.
local function newRig(): Rig
	local remote: any = { OnServerEvent = newSignal() }
	local players: any = { PlayerRemoving = newSignal() }
	local changed = Signal.new()
	table.insert(signals, changed)
	local changes: { Change } = {}
	changed:Connect(function(userId: number, on: boolean)
		table.insert(changes, { userId = userId, on = on })
	end)
	local time = 100
	local stop = MusicHandler.start({
		remote = remote,
		players = players,
		now = function(): number
			return time
		end,
		changed = changed,
	})
	table.insert(stops, stop)
	return {
		remote = remote,
		players = players,
		player = newPlayer(1),
		changes = changes,
		advance = function(seconds: number)
			time += seconds
		end,
		send = function(sender: FakePlayer, ...: any)
			remote.OnServerEvent:Fire(sender, ...)
		end,
		stop = stop,
	}
end

describe("MusicHandler: what a message may say", function()
	it("fires (UserId, false) for a first false", function()
		local rig = newRig()
		rig.send(rig.player, false)
		expect(#rig.changes).toBe(1)
		expect(rig.changes[1].userId).toBe(1)
		expect(rig.changes[1].on).toBe(false)
	end)

	it("fires nothing for a second false in a row", function()
		local rig = newRig()
		rig.send(rig.player, false)
		rig.send(rig.player, false)
		expect(#rig.changes).toBe(1)
	end)

	it("fires (UserId, true) for a true after a false", function()
		local rig = newRig()
		rig.send(rig.player, false)
		rig.send(rig.player, true)
		expect(#rig.changes).toBe(2)
		expect(rig.changes[2].userId).toBe(1)
		expect(rig.changes[2].on).toBe(true)
	end)

	it("fires nothing for a first true, because the music starts on", function()
		local rig = newRig()
		rig.send(rig.player, true)
		expect(#rig.changes).toBe(0)
	end)

	it("fires nothing for the number 1, the text 'off' or nothing at all", function()
		local rig = newRig()
		rig.send(rig.player, 1)
		rig.send(rig.player, "off")
		rig.send(rig.player, nil)
		rig.send(rig.player)
		expect(#rig.changes).toBe(0)
	end)

	it("keeps the last answer when a wrong message arrives between two", function()
		local rig = newRig()
		rig.send(rig.player, false)
		rig.send(rig.player, "on")
		rig.send(rig.player, false)
		expect(#rig.changes).toBe(1)
	end)

	it("keeps each player's last answer on their own", function()
		local rig = newRig()
		local other = newPlayer(2)
		rig.send(rig.player, false)
		rig.send(other, false)
		expect(#rig.changes).toBe(2)
		expect(rig.changes[2].userId).toBe(2)
	end)
end)

describe("MusicHandler: how often", function()
	it("ignores the 6th message within one second", function()
		local rig = newRig()
		-- Five messages: off, on, off, on, off (five changes). The 6th (on) would be a change, but is too many.
		for index = 1, 5 do
			rig.send(rig.player, index % 2 == 0)
		end
		expect(#rig.changes).toBe(5)
		rig.send(rig.player, true)
		expect(#rig.changes).toBe(5)
	end)

	it("works again one second later", function()
		local rig = newRig()
		for index = 1, 5 do
			rig.send(rig.player, index % 2 == 0)
		end
		rig.send(rig.player, true)
		expect(#rig.changes).toBe(5)
		rig.advance(1)
		rig.send(rig.player, true)
		expect(#rig.changes).toBe(6)
		expect(rig.changes[6].on).toBe(true)
	end)

	it("counts wrong messages too, so spam of any kind is limited", function()
		local rig = newRig()
		for _ = 1, 5 do
			rig.send(rig.player, "spam")
		end
		rig.send(rig.player, false)
		expect(#rig.changes).toBe(0)
	end)
end)

describe("MusicHandler.start: leaving and cleanup", function()
	it("forgets the last answer when the player leaves, so their next false fires again", function()
		local rig = newRig()
		rig.send(rig.player, false)
		rig.players.PlayerRemoving:Fire(rig.player)
		rig.send(rig.player, false)
		expect(#rig.changes).toBe(2)
		expect(rig.changes[2].on).toBe(false)
	end)

	it("stops listening when it is stopped, and stopping twice is safe", function()
		local rig = newRig()
		expect(rig.remote.OnServerEvent:count()).toBe(1)
		expect(rig.players.PlayerRemoving:count()).toBe(1)
		rig.stop()
		expect(function()
			rig.stop()
		end).never.toThrow()
		expect(rig.remote.OnServerEvent:count()).toBe(0)
		expect(rig.players.PlayerRemoving:count()).toBe(0)
		rig.send(rig.player, false)
		expect(#rig.changes).toBe(0)
	end)
end)
