--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Recovery = require(ServerScriptService.Server.Players.Recovery)
local SafeSpots = require(ServerScriptService.Server.Players.SafeSpots)

local MAX_SLOPE = 70 -- the same number as StarterPlayer.CharacterMaxSlopeAngle
local HIP_HEIGHT = 2
local ROOT_HEIGHT = 2

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

-- A character with no parent (unless a test needs a death), a root part and a Humanoid.
local function makeCharacter(rootPosition: Vector3): Model
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, ROOT_HEIGHT, 1)
	root.Position = rootPosition
	root.Parent = character
	character.PrimaryPart = root
	return character
end

local function rootOf(character: Model): BasePart
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

type FakePlayer = { UserId: number, Character: Model?, CharacterAdded: any }

type Rig = {
	recovery: Recovery.Recovery,
	safeSpots: SafeSpots.SafeSpots,
	playerAdded: any,
	playerRemoving: any,
	moved: { number }, -- the user ids the tracker was told about, in order
	log: { string }, -- "moved" and "rescued", in the order they happened
	rescues: { { player: FakePlayer, from: Vector3, to: CFrame } },
	samples: { [number]: SafeSpots.Sample }, -- what each player's sample is right now
	clock: number,
	die: (character: Model) -> (), -- what the character's Humanoid.Died does in the real game
}

local rigs: { Rig } = {}
local made: { Instance } = {}

-- A brand-new player: one living character far from every spot, nothing saved.
local function newPlayer(userId: number, rootPosition: Vector3): FakePlayer
	local character = makeCharacter(rootPosition)
	table.insert(made, character)
	return { UserId = userId, Character = character, CharacterAdded = newSignal() }
end

-- A sample of a player standing on flat ground at `feet`, facing `facing`.
local function sampleAt(feet: Vector3, facing: Vector3, now: number): SafeSpots.Sample
	return {
		now = now,
		feet = feet,
		facing = facing,
		groundNormal = Vector3.yAxis,
		state = Enum.HumanoidStateType.Running,
		floating = false,
		hasRoom = function()
			return true
		end,
	}
end

local function newRig(players: { FakePlayer }): Rig
	local rig: Rig = {
		recovery = nil :: any,
		safeSpots = SafeSpots.new(MAX_SLOPE),
		playerAdded = newSignal(),
		playerRemoving = newSignal(),
		moved = {},
		log = {},
		rescues = {},
		samples = {},
		clock = 100,
		die = nil :: any,
	}
	-- A Humanoid only dies inside the world, and tests never change the place, so a death is injected.
	local deaths: { [Model]: () -> () } = {}
	rig.die = function(character: Model)
		local callback = deaths[character]
		if callback ~= nil then
			callback()
		end
	end
	rig.recovery = Recovery.start({
		players = {
			GetPlayers = function(_self: any)
				return players
			end,
			PlayerAdded = rig.playerAdded,
			PlayerRemoving = rig.playerRemoving,
		} :: any,
		safeSpots = rig.safeSpots,
		tracker = {
			moved = function(_self: any, userId: number)
				table.insert(rig.moved, userId)
				table.insert(rig.log, "moved")
			end,
		},
		sampleOf = function(player: any, _now: number): SafeSpots.Sample?
			return rig.samples[player.UserId]
		end,
		fireRescued = function(player: any, from: Vector3, to: CFrame)
			table.insert(rig.rescues, { player = player, from = from, to = to })
			table.insert(rig.log, "rescued")
		end,
		now = function()
			return rig.clock
		end,
		died = function(character: Model, callback: () -> ())
			deaths[character] = callback
			return {
				Disconnect = function()
					deaths[character] = nil
				end,
			}
		end,
	})
	table.insert(rigs, rig)
	return rig
end

afterEach(function()
	for _, rig in rigs do
		rig.recovery:destroy()
	end
	table.clear(rigs)
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end)

describe("Recovery", function()
	it("saves a safe spot from each player's sample", function()
		local first = newPlayer(1, Vector3.new(0, 10, 0))
		local second = newPlayer(2, Vector3.new(50, 10, 0))
		local rig = newRig({ first, second })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.samples[2] = sampleAt(Vector3.new(50, 5, 0), Vector3.zAxis, rig.clock)

		rig.recovery:step()

		expect(rig.safeSpots:count(1)).toBe(1)
		expect(rig.safeSpots:count(2)).toBe(1)
		expect((rig.safeSpots:pick(2, Vector3.new(0, 5, 0)) :: SafeSpots.Spot).feet).toEqual(Vector3.new(50, 5, 0))
	end)

	it("a death on the giant keeps the safe spot picked before the spots are cleared", function()
		local player = newPlayer(1, Vector3.new(0, 20, 0))
		local oldCharacter = player.Character :: Model
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(1)

		rig.die(oldCharacter)
		local newCharacter = makeCharacter(Vector3.new(500, 5, 0))
		table.insert(made, newCharacter)
		player.Character = newCharacter
		player.CharacterAdded:Fire(newCharacter)

		local kept = rig.recovery:keptSpot(player :: any)
		expect(kept).never.toBeNil()
		expect((kept :: SafeSpots.Spot).feet).toEqual(Vector3.new(0, 5, 0))
		expect(rig.safeSpots:count(1)).toBe(0)
	end)

	it("forgets a player's spots when they leave", function()
		local player = newPlayer(1, Vector3.new(0, 20, 0))
		local oldCharacter = player.Character :: Model
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		rig.die(oldCharacter)
		expect(rig.recovery:keptSpot(player :: any)).never.toBeNil()

		rig.playerRemoving:Fire(player)

		expect(rig.safeSpots:count(1)).toBe(0)
		expect(rig.recovery:keptSpot(player :: any)).toBeNil()
	end)

	it("forgets a player's spots when they get a new character", function()
		local player = newPlayer(1, Vector3.new(0, 20, 0))
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(1)

		local newCharacter = makeCharacter(Vector3.new(500, 5, 0))
		table.insert(made, newCharacter)
		player.Character = newCharacter
		player.CharacterAdded:Fire(newCharacter)

		expect(rig.safeSpots:count(1)).toBe(0)
	end)

	it("moves a player to the newest safe spot 0.5 studs up, facing the saved way, with no speed", function()
		local player = newPlayer(1, Vector3.new(0, 30, 0))
		local character = player.Character :: Model
		rootOf(character).AssemblyLinearVelocity = Vector3.new(0, -30, 5)
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()

		local target = rig.recovery:moveBack(player :: any)

		-- feet + 0.5 + the hip height + half the root's height
		local expected = Vector3.new(10, 5 + 0.5 + HIP_HEIGHT + ROOT_HEIGHT / 2, 0)
		expect(target).never.toBeNil()
		expect(((target :: CFrame).Position - expected).Magnitude < 0.01).toBe(true)
		expect((rootOf(character).Position - expected).Magnitude < 0.01).toBe(true)
		expect((rootOf(character).CFrame.LookVector - Vector3.xAxis).Magnitude < 0.01).toBe(true)
		expect(rootOf(character).AssemblyLinearVelocity).toEqual(Vector3.zero)
	end)

	it("tells the tracker and fires Rescued with where they were and where they go", function()
		local player = newPlayer(7, Vector3.new(0, 30, 0))
		local rig = newRig({ player })
		rig.samples[7] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()

		local target = rig.recovery:moveBack(player :: any)

		expect(rig.moved).toEqual({ 7 })
		expect(#rig.rescues).toBe(1)
		expect(rig.rescues[1].player).toBe(player)
		expect(rig.rescues[1].from).toEqual(Vector3.new(0, 30, 0))
		expect(rig.rescues[1].to).toEqual(target)
		expect(rig.log).toEqual({ "moved", "rescued" }) -- the tracker is told first
	end)

	it("moves nobody when no safe spot is far enough", function()
		local player = newPlayer(1, Vector3.new(10, 6, 0))
		local character = player.Character :: Model
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(11, 5, 0), Vector3.xAxis, rig.clock) -- about 1.4 studs away
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(1)

		local target = rig.recovery:moveBack(player :: any)

		expect(target).toBeNil()
		expect(rootOf(character).Position).toEqual(Vector3.new(10, 6, 0))
		expect(#rig.moved).toBe(0)
		expect(#rig.rescues).toBe(0)
	end)
end)
