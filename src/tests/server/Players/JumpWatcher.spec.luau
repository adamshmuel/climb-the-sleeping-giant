--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local JumpWatcher = require(ServerScriptService.Server.Players.JumpWatcher)

local STATE = Enum.HumanoidStateType

-- A stand-in for a Roblox signal. It counts the connections that are still open.
type FakeSignal = {
	open: number,
	callbacks: { [number]: (...any) -> () },
	nextId: number,
	Connect: (self: FakeSignal, callback: (...any) -> ()) -> { Disconnect: (self: any) -> () },
	fire: (self: FakeSignal, ...any) -> (),
}

local function newSignal(): FakeSignal
	local signal: FakeSignal = {
		open = 0,
		callbacks = {},
		nextId = 1,
		Connect = function(self: FakeSignal, callback: (...any) -> ())
			local id = self.nextId
			self.nextId += 1
			self.callbacks[id] = callback
			self.open += 1
			return {
				Disconnect = function(_connection: any)
					if self.callbacks[id] ~= nil then
						self.callbacks[id] = nil
						self.open -= 1
					end
				end,
			}
		end,
		fire = function(self: FakeSignal, ...: any)
			for _, callback in table.clone(self.callbacks) do
				callback(...)
			end
		end,
	}
	return signal
end

-- A stand-in for a Player: a character (a model with no parent) and the signal for the next one.
type FakePlayer = { Character: Model?, CharacterAdded: FakeSignal }

local function newPlayer(character: Model?): FakePlayer
	return { Character = character, CharacterAdded = newSignal() }
end

-- A stand-in for the Players service, and a Humanoid state signal for each character.
type Rig = {
	players: any, -- stands in for the Players service (a comment, because its signals are fakes)
	list: { FakePlayer },
	added: FakeSignal,
	removing: FakeSignal,
	states: { [Model]: FakeSignal },
	stateChanged: (character: Model) -> any,
	positions: { [Model]: Vector3 }, -- where each character's root part is; a character with no entry has no root part
	rootPosition: (character: Model) -> Vector3?,
}

local function newRig(): Rig
	local list: { FakePlayer } = {}
	local added = newSignal()
	local removing = newSignal()
	local states: { [Model]: FakeSignal } = {}
	local positions: { [Model]: Vector3 } = {}
	return {
		players = {
			PlayerAdded = added,
			PlayerRemoving = removing,
			GetPlayers = function(_self: any)
				return list
			end,
		},
		list = list,
		added = added,
		removing = removing,
		states = states,
		stateChanged = function(character: Model)
			local signal = states[character]
			if signal == nil then
				signal = newSignal()
				states[character] = signal
			end
			return signal
		end,
		positions = positions,
		rootPosition = function(character: Model)
			return positions[character]
		end,
	}
end

local function start(rig: Rig): JumpWatcher.JumpWatcher
	return JumpWatcher.start({
		players = rig.players,
		stateChanged = rig.stateChanged,
		rootPosition = rig.rootPosition,
	})
end

-- A player with a character, already in the game.
local function addPlayerInGame(rig: Rig): (FakePlayer, Model)
	local character = Instance.new("Model")
	rig.positions[character] = Vector3.new(1, 2, 3)
	local player = newPlayer(character)
	table.insert(rig.list, player)
	return player, character
end

describe("JumpWatcher", function()
	it("a character whose state changes to Jumping took off from its root position, once", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)

		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		expect(watcher:took(character)).toEqual({ Vector3.new(1, 2, 3) })
		expect(watcher:took(character)).toEqual({})
		watcher:stop()
		character:Destroy()
	end)

	it("Freefall, Landed and Running do not count as a jump", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)

		rig.states[character]:fire(STATE.Jumping, STATE.Freefall)
		rig.states[character]:fire(STATE.Freefall, STATE.Landed)
		rig.states[character]:fire(STATE.Landed, STATE.Running)
		rig.states[character]:fire(STATE.Running, STATE.Climbing)

		expect(#watcher:took(character)).toBe(0)
		watcher:stop()
		character:Destroy()
	end)

	it("a jump after the last took counts again", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)

		rig.states[character]:fire(STATE.Running, STATE.Jumping)
		expect(#watcher:took(character)).toBe(1)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)
		expect(#watcher:took(character)).toBe(1)
		watcher:stop()
		character:Destroy()
	end)

	it("two jumps before took give both take-off positions, oldest first, then an empty list", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)

		rig.positions[character] = Vector3.new(10, 0, 0)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)
		rig.positions[character] = Vector3.new(20, 0, 0)
		rig.states[character]:fire(STATE.Freefall, STATE.Jumping)

		expect(watcher:took(character)).toEqual({ Vector3.new(10, 0, 0), Vector3.new(20, 0, 0) })
		expect(watcher:took(character)).toEqual({})
		watcher:stop()
		character:Destroy()
	end)

	it("a jump with no root position adds nothing", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)

		rig.positions[character] = nil
		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		expect(watcher:took(character)).toEqual({})
		watcher:stop()
		character:Destroy()
	end)

	it("keeps at most 4 take-offs between two calls and drops the 5th and later", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)

		for index = 1, 6 do
			rig.positions[character] = Vector3.new(index, 0, 0)
			rig.states[character]:fire(STATE.Running, STATE.Jumping)
		end

		expect(watcher:took(character)).toEqual({
			Vector3.new(1, 0, 0),
			Vector3.new(2, 0, 0),
			Vector3.new(3, 0, 0),
			Vector3.new(4, 0, 0),
		})
		rig.states[character]:fire(STATE.Running, STATE.Jumping)
		expect(#watcher:took(character)).toBe(1) -- after a call there is room again
		watcher:stop()
		character:Destroy()
	end)

	it("the list it hands out is the caller's own: changing it changes nothing later", function()
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local watcher = start(rig)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		local first = watcher:took(character)
		table.insert(first, Vector3.new(9, 9, 9))

		expect(watcher:took(character)).toEqual({})
		watcher:stop()
		character:Destroy()
	end)

	it("a character the watcher has never seen has not jumped", function()
		local rig = newRig()
		local watcher = start(rig)
		local stranger = Instance.new("Model")

		expect(#watcher:took(stranger)).toBe(0)
		watcher:stop()
		stranger:Destroy()
	end)

	it("a jump is remembered for its own character only", function()
		local rig = newRig()
		local _first, firstCharacter = addPlayerInGame(rig)
		local _second, secondCharacter = addPlayerInGame(rig)
		local watcher = start(rig)

		rig.states[secondCharacter]:fire(STATE.Running, STATE.Jumping)

		expect(#watcher:took(firstCharacter)).toBe(0)
		expect(#watcher:took(secondCharacter)).toBe(1)
		watcher:stop()
		firstCharacter:Destroy()
		secondCharacter:Destroy()
	end)

	it("a player who joins later with a character is watched", function()
		local rig = newRig()
		local watcher = start(rig)
		local character = Instance.new("Model")
		rig.positions[character] = Vector3.new(1, 2, 3)
		local player = newPlayer(character)

		table.insert(rig.list, player)
		rig.added:fire(player)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		expect(#watcher:took(character)).toBe(1)
		watcher:stop()
		character:Destroy()
	end)

	it("a character that arrives later is watched", function()
		local rig = newRig()
		local player = newPlayer(nil)
		table.insert(rig.list, player)
		local watcher = start(rig)
		local character = Instance.new("Model")
		rig.positions[character] = Vector3.new(1, 2, 3)

		player.CharacterAdded:fire(character)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		expect(#watcher:took(character)).toBe(1)
		watcher:stop()
		character:Destroy()
	end)

	it("a new character starts unmarked and the old one's connection is gone", function()
		local rig = newRig()
		local player, oldCharacter = addPlayerInGame(rig)
		local watcher = start(rig)
		rig.states[oldCharacter]:fire(STATE.Running, STATE.Jumping) -- jumped, then died before took
		local newCharacter = Instance.new("Model")
		rig.positions[newCharacter] = Vector3.new(1, 2, 3)

		player.CharacterAdded:fire(newCharacter)

		expect(rig.states[oldCharacter].open).toBe(0)
		expect(#watcher:took(oldCharacter)).toBe(0)
		expect(#watcher:took(newCharacter)).toBe(0)
		rig.states[newCharacter]:fire(STATE.Running, STATE.Jumping)
		expect(#watcher:took(newCharacter)).toBe(1)
		watcher:stop()
		oldCharacter:Destroy()
		newCharacter:Destroy()
	end)

	it("a player who leaves is forgotten and nothing stays connected", function()
		local rig = newRig()
		local player, character = addPlayerInGame(rig)
		local watcher = start(rig)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		rig.removing:fire(player)

		expect(#watcher:took(character)).toBe(0)
		expect(rig.states[character].open).toBe(0)
		expect(player.CharacterAdded.open).toBe(0)
		watcher:stop()
		character:Destroy()
	end)

	it("a character without a Humanoid signal is never marked and causes no error", function()
		local watcher = JumpWatcher.start({
			players = newRig().players,
			stateChanged = function(_character: Model)
				return nil
			end,
			rootPosition = function(_character: Model)
				return Vector3.zero
			end,
		})
		local rig = newRig()
		local _player, character = addPlayerInGame(rig)
		local lonely = JumpWatcher.start({
			players = rig.players,
			stateChanged = function(_character: Model)
				return nil
			end,
			rootPosition = rig.rootPosition,
		})

		expect(#lonely:took(character)).toBe(0)
		lonely:stop()
		watcher:stop()
		character:Destroy()
	end)

	it("a signal that arrives after its character was replaced is not connected", function()
		local rig = newRig()
		local player, oldCharacter = addPlayerInGame(rig)
		local lateSignal = newSignal()
		local waiting: thread? = nil
		local watcher = JumpWatcher.start({
			players = rig.players,
			stateChanged = function(character: Model)
				if character == oldCharacter then
					waiting = coroutine.running()
					coroutine.yield() -- the Humanoid has not arrived yet
					return lateSignal
				end
				return rig.stateChanged(character)
			end,
			rootPosition = rig.rootPosition,
		})
		local newCharacter = Instance.new("Model")

		player.CharacterAdded:fire(newCharacter) -- replaced before the Humanoid arrived
		task.spawn(waiting :: thread)

		expect(lateSignal.open).toBe(0)
		watcher:stop()
		oldCharacter:Destroy()
		newCharacter:Destroy()
	end)

	it("stop disconnects everything and forgets every jump", function()
		local rig = newRig()
		local player, character = addPlayerInGame(rig)
		local watcher = start(rig)
		rig.states[character]:fire(STATE.Running, STATE.Jumping)

		watcher:stop()

		expect(rig.added.open).toBe(0)
		expect(rig.removing.open).toBe(0)
		expect(player.CharacterAdded.open).toBe(0)
		expect(rig.states[character].open).toBe(0)
		expect(#watcher:took(character)).toBe(0)
		character:Destroy()
	end)
end)

describe("JumpWatcher.rootPositionOf", function()
	it("gives the position of the HumanoidRootPart", function()
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(4, 5, 6)
		root.Parent = character

		expect(JumpWatcher.rootPositionOf(character)).toEqual(Vector3.new(4, 5, 6))

		character:Destroy()
	end)

	it("gives nil for a character without a HumanoidRootPart", function()
		local character = Instance.new("Model")

		expect(JumpWatcher.rootPositionOf(character)).toBeNil()

		character:Destroy()
	end)
end)
