--!strict
-- Shared set-up for the Recovery specs: fake players and characters, and a Recovery wired to fakes whose clock,
-- phase, position and deaths the test sets by hand. Call RecoveryRig.cleanUp in afterEach.
local ServerScriptService = game:GetService("ServerScriptService")

local Recovery = require(ServerScriptService.Server.Players.Recovery)
local SafeSpots = require(ServerScriptService.Server.Players.SafeSpots)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

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

export type FakePlayer = {
	UserId: number,
	Character: Model?,
	CharacterAdded: any,
	attributes: { [string]: any },
	GetAttribute: (self: any, name: string) -> any,
	SetAttribute: (self: any, name: string, value: any) -> (),
}

export type Rig = {
	recovery: Recovery.Recovery,
	safeSpots: SafeSpots.SafeSpots,
	playerAdded: any,
	playerRemoving: any,
	moved: { number }, -- the user ids the tracker was told about, in order
	log: { string }, -- "moved", "rescued" and "home", in the order they happened
	rescues: { { player: FakePlayer, from: Vector3, to: CFrame } },
	samples: { [number]: SafeSpots.Sample }, -- what each player's sample is right now
	clock: number,
	where: { zone: Config.ZoneName, onPillow: boolean }?, -- what whereIs answers (nil: no living character)
	phase: Config.Phase, -- what the giant's phase is right now
	home: { number }, -- the user ids sent home, in order
	falling: boolean, -- what the falling check answers for every player
	floating: boolean, -- what the floating-down check answers for every user id
	inRedCircle: boolean, -- what the red-circle check answers for every position
	die: (character: Model) -> (), -- what the character's Humanoid.Died does in the real game
}

local rigs: { Rig } = {}
local made: { Instance } = {}

-- A brand-new player: one living character far from every spot, nothing saved.
local function newPlayer(userId: number, rootPosition: Vector3): FakePlayer
	local character = makeCharacter(rootPosition)
	table.insert(made, character)
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		Character = character,
		CharacterAdded = newSignal(),
		attributes = attributes,
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
	}
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
		where = { zone = "Belly", onPillow = false },
		phase = "Asleep",
		home = {},
		falling = false,
		floating = false,
		inRedCircle = false,
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
		whereIs = function(_player: any)
			return rig.where
		end,
		phase = function()
			return rig.phase
		end,
		sendHome = function(player: any)
			table.insert(rig.home, player.UserId)
			table.insert(rig.log, "home")
		end,
		falling = function(_player: any)
			return rig.falling
		end,
		floating = function(_userId: number)
			return rig.floating
		end,
		inRedCircle = function(_position: Vector3)
			return rig.inRedCircle
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

-- Destroys every Recovery and every character the rig made.
local function cleanUp()
	for _, rig in rigs do
		rig.recovery:destroy()
	end
	table.clear(rigs)
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end

return {
	HIP_HEIGHT = HIP_HEIGHT,
	ROOT_HEIGHT = ROOT_HEIGHT,
	made = made,
	newSignal = newSignal,
	makeCharacter = makeCharacter,
	rootOf = rootOf,
	newPlayer = newPlayer,
	sampleAt = sampleAt,
	newRig = newRig,
	cleanUp = cleanUp,
}
