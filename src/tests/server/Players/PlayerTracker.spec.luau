--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Zones = require(ServerScriptService.Server.Giant.Zones)

-- Under strict typing a plain local widens "Belly" to `string`, so each zone is declared with its type.
local BELLY: Config.ZoneName = "Belly"

-- A character with no parent, so the test never changes the place. Destroy it when the test is done.
local function makeCharacter(position: Vector3, health: number?): Model
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = health or 100
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Position = position
	root.Parent = character
	return character
end

local function rootOf(character: Model): BasePart
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

local noZones: { Zones.ZoneBox } = {}
local noGardens: { Zones.GardenBox } = {}
local neverGrounded = function(_character: Model): boolean
	return false
end
local neverTookOff = function(_character: Model): { Vector3 }
	return {}
end
local function zeroClock(): number
	return 0
end

describe("PlayerTracker.isMoving", function()
	it("moving more than 0.5 studs in a tick is moving", function()
		expect(PlayerTracker.isMoving(Vector3.new(0, 0, 0), Vector3.new(0.6, 0, 0))).toBe(true)
	end)

	it("moving 0.5 studs or less is standing still", function()
		expect(PlayerTracker.isMoving(Vector3.new(0, 0, 0), Vector3.new(0.5, 0, 0))).toBe(false)
		expect(PlayerTracker.isMoving(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0))).toBe(false)
	end)

	it("climbing straight up counts as moving", function()
		expect(PlayerTracker.isMoving(Vector3.new(0, 10, 0), Vector3.new(0, 10.8, 0))).toBe(true)
	end)

	it("a jump of more than 20 studs in a tick is a teleport, not moving", function()
		expect(PlayerTracker.isMoving(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0))).toBe(true)
		expect(PlayerTracker.isMoving(Vector3.new(0, 0, 0), Vector3.new(20.5, 0, 0))).toBe(false)
	end)

	it("the first sample of a new character is not moving", function()
		expect(PlayerTracker.isMoving(nil, Vector3.new(5, 5, 5))).toBe(false)
	end)
end)

-- The surface normal of a slope that is `degrees` steep (0 = flat ground, 90 = a wall).
local function slopeNormal(degrees: number): Vector3
	local radians = math.rad(degrees)
	return Vector3.new(math.sin(radians), math.cos(radians), 0)
end

local MAX_SLOPE = 70 -- the same number as StarterPlayer.CharacterMaxSlopeAngle

describe("PlayerTracker.isStandable", function()
	it("flat ground is standable", function()
		expect(PlayerTracker.isStandable(slopeNormal(0), MAX_SLOPE)).toBe(true)
	end)

	it("a 60 degree slope is standable", function()
		expect(PlayerTracker.isStandable(slopeNormal(60), MAX_SLOPE)).toBe(true)
	end)

	it("an 80 degree slope is not standable", function()
		expect(PlayerTracker.isStandable(slopeNormal(80), MAX_SLOPE)).toBe(false)
	end)

	it("a wall is not standable", function()
		expect(PlayerTracker.isStandable(slopeNormal(90), MAX_SLOPE)).toBe(false)
	end)
end)

describe("PlayerTracker.gardenBoxes", function()
	it("keeps each garden's number and box", function()
		-- Only the number and the box matter here, so the other parts of a garden are left out.
		local gardens = {
			{ index = 1, box = { cframe = CFrame.new(1, 2, 3), size = Vector3.new(4, 5, 6) } },
			{ index = 2, box = { cframe = CFrame.new(7, 8, 9), size = Vector3.new(1, 1, 1) } },
		} :: any

		local boxes = PlayerTracker.gardenBoxes(gardens)

		expect(#boxes).toBe(2)
		expect(boxes[1]).toEqual({ index = 1, cframe = CFrame.new(1, 2, 3), size = Vector3.new(4, 5, 6) })
		expect(boxes[2].index).toBe(2)
	end)
end)

describe("PlayerTracker tick", function()
	it("tick reports the zone and garden of each living player", function()
		local inGarden = makeCharacter(Vector3.new(100, 5, 0))
		local onBelly = makeCharacter(Vector3.new(0, 50, 0))
		local inMeadow = makeCharacter(Vector3.new(-100, 5, 0))
		local players: { PlayerTracker.PlayerLike } = {
			{ UserId = 1, Character = inGarden },
			{ UserId = 2, Character = onBelly },
			{ UserId = 3, Character = inMeadow },
		}
		local zoneBoxes: { Zones.ZoneBox } = {
			{ zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(20, 20, 20) },
		}
		local gardens: { Zones.GardenBox } = {
			{ index = 3, cframe = CFrame.new(100, 5, 0), size = Vector3.new(30, 20, 30) },
		}
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = zoneBoxes,
			gardens = gardens,
			isGrounded = neverGrounded,
			takeoffs = neverTookOff,
			now = zeroClock,
		})

		local samples = tracker:tick()

		expect(#samples).toBe(3)
		expect(samples[1].userId).toBe(1)
		expect(samples[1].zone).toBe("Meadow")
		expect(samples[1].garden).toBe(3)
		expect(samples[2].zone).toBe("Belly")
		expect(samples[2].garden).toBe(nil)
		expect(samples[3].zone).toBe("Meadow")
		expect(samples[3].garden).toBe(nil)
		expect(samples[2].position).toBe(Vector3.new(0, 50, 0))

		inGarden:Destroy()
		onBelly:Destroy()
		inMeadow:Destroy()
	end)

	it("a player whose character is dead or missing is skipped", function()
		local dead = makeCharacter(Vector3.new(0, 5, 0), 0)
		local noRoot = Instance.new("Model")
		Instance.new("Humanoid").Parent = noRoot
		local alive = makeCharacter(Vector3.new(0, 5, 0))
		local players: { PlayerTracker.PlayerLike } = {
			{ UserId = 1, Character = dead },
			{ UserId = 2, Character = nil },
			{ UserId = 3, Character = noRoot },
			{ UserId = 4, Character = alive },
		}
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = noZones,
			gardens = noGardens,
			isGrounded = neverGrounded,
			takeoffs = neverTookOff,
			now = zeroClock,
		})

		local samples = tracker:tick()

		expect(#samples).toBe(1)
		expect(samples[1].userId).toBe(4)

		dead:Destroy()
		noRoot:Destroy()
		alive:Destroy()
	end)

	it("a character that moved more than 0.5 studs since the last tick is moving", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = noZones,
			gardens = noGardens,
			isGrounded = neverGrounded,
			takeoffs = neverTookOff,
			now = zeroClock,
		})

		expect(tracker:tick()[1].moving).toBe(false) -- the first sample has no previous position
		rootOf(character).Position = Vector3.new(1, 5, 0)
		expect(tracker:tick()[1].moving).toBe(true)
		expect(tracker:tick()[1].moving).toBe(false) -- stayed put

		character:Destroy()
	end)

	it("a respawned character starts with no previous position", function()
		local first = makeCharacter(Vector3.new(0, 5, 0))
		local second = makeCharacter(Vector3.new(3, 5, 0))
		local player: PlayerTracker.PlayerLike = { UserId = 1, Character = first }
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return { player }
			end,
			zoneBoxes = noZones,
			gardens = noGardens,
			isGrounded = neverGrounded,
			takeoffs = neverTookOff,
			now = zeroClock,
		})

		tracker:tick()
		player.Character = second

		expect(tracker:tick()[1].moving).toBe(false)

		first:Destroy()
		second:Destroy()
	end)

	it("a player who leaves is forgotten", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local player: PlayerTracker.PlayerLike = { UserId = 1, Character = character }
		local present = true
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return if present then { player } else {}
			end,
			zoneBoxes = noZones,
			gardens = noGardens,
			isGrounded = neverGrounded,
			takeoffs = neverTookOff,
			now = zeroClock,
		})

		tracker:tick()
		present = false
		expect(#tracker:tick()).toBe(0)
		present = true
		rootOf(character).Position = Vector3.new(5, 5, 0) -- moved while they were away

		expect(tracker:tick()[1].moving).toBe(false)

		character:Destroy()
	end)

	it("tick reports thudFrom from the fall tracker", function()
		local character = makeCharacter(Vector3.new(0, 50, 0))
		local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
		local grounded = false
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = { { zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(100, 100, 100) } },
			gardens = noGardens,
			isGrounded = function(_character: Model): boolean
				return grounded
			end,
			takeoffs = neverTookOff,
			now = zeroClock,
		})
		local root = rootOf(character)

		-- three ticks falling fast, so the fall starts
		root.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
		for _ = 1, 3 do
			expect(tracker:tick()[1].thudFrom).toBeNil()
		end
		-- back on the ground and still: the fall ends after three resting ticks
		grounded = true
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		expect(tracker:tick()[1].thudFrom).toBeNil()
		expect(tracker:tick()[1].thudFrom).toBeNil()
		expect(tracker:tick()[1].thudFrom).toBe(BELLY)
		expect(tracker:tick()[1].thudFrom).toBeNil() -- only once

		character:Destroy()
	end)
end)

-- A tracker for one character, with a clock and a "standing on the ground" switch the test sets by hand.
type Rig = {
	tracker: PlayerTracker.Tracker,
	setTime: (seconds: number) -> (),
	setGrounded: (grounded: boolean) -> (),
}

local function groundSpeedRig(character: Model): Rig
	local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
	local time = 0
	local grounded = false
	local tracker = PlayerTracker.new({
		getPlayers = function()
			return players
		end,
		zoneBoxes = noZones,
		gardens = noGardens,
		isGrounded = function(_character: Model): boolean
			return grounded
		end,
		takeoffs = neverTookOff,
		now = function()
			return time
		end,
	})
	return {
		tracker = tracker,
		setTime = function(seconds: number)
			time = seconds
		end,
		setGrounded = function(value: boolean)
			grounded = value
		end,
	}
end

describe("PlayerTracker groundSpeed", function()
	it("a character that moved 4.8 studs across the ground in 0.5 s goes 9.6 studs a second", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.5)
		rootOf(character).Position = Vector3.new(4.8, 5, 0)

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(9.6, 5)

		character:Destroy()
	end)

	it("a character that only stands still goes 0 studs a second", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.5)

		expect(rig.tracker:tick()[1].groundSpeed).toBe(0)

		character:Destroy()
	end)

	it("the first sample of a new character goes 0 studs a second", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		expect(rig.tracker:tick()[1].groundSpeed).toBe(0)

		character:Destroy()
	end)

	it("a character climbing straight up in the air goes 0 studs a second across the ground", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.5)
		rootOf(character).Position = Vector3.new(0, 10, 0)

		expect(rig.tracker:tick()[1].groundSpeed).toBe(0)

		character:Destroy()
	end)

	it("only the distance across the ground counts when a character moves sideways and up", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.5)
		rootOf(character).Position = Vector3.new(3, 9, 4) -- 5 studs across the ground, 4 up

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(10, 5)

		character:Destroy()
	end)

	it("a teleport of more than 20 studs goes 0 studs a second", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.1)
		rootOf(character).Position = Vector3.new(50, 5, 0)

		expect(rig.tracker:tick()[1].groundSpeed).toBe(0)

		character:Destroy()
	end)

	it("a teleport does not raise the speed of the ticks after it", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.1)
		rootOf(character).Position = Vector3.new(50, 5, 0)
		rig.tracker:tick()
		rig.setTime(0.2)
		rootOf(character).Position = Vector3.new(50.96, 5, 0) -- 0.96 studs in 0.1 s after landing

		-- Positions are stored as 32-bit numbers, so far from the origin they are only exact to about 4 decimals.
		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(9.6, 3)

		character:Destroy()
	end)

	it("three ticks at the same clock time after a lag still give the real speed", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rig.setTime(0.5)
		rootOf(character).Position = Vector3.new(4.8, 5, 0)
		-- the server fell behind and runs three ticks in one frame: same time, same position
		local first = rig.tracker:tick()[1].groundSpeed
		local second = rig.tracker:tick()[1].groundSpeed
		local third = rig.tracker:tick()[1].groundSpeed

		expect(first).toBeCloseTo(9.6, 5)
		expect(second).toBeCloseTo(9.6, 5)
		expect(third).toBeCloseTo(9.6, 5)

		character:Destroy()
	end)

	it("ticks that all happen at the same clock time give 0, not a divide by zero", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick()
		rootOf(character).Position = Vector3.new(4.8, 5, 0)
		local speed = rig.tracker:tick()[1].groundSpeed

		expect(speed).toBe(0)

		character:Destroy()
	end)

	it("a reading 0.9 s old is still kept", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick() -- t = 0 at x = 0
		rig.setTime(0.9)
		rootOf(character).Position = Vector3.new(9, 5, 0)

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(10, 5)

		character:Destroy()
	end)

	it("a reading older than 1 s is dropped, so an old burst of speed is forgotten", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.tracker:tick() -- t = 0 at x = 0
		rig.setTime(0.1)
		rootOf(character).Position = Vector3.new(10, 5, 0) -- a fast burst
		rig.tracker:tick()
		-- then standing still for a long time
		for step = 2, 12 do
			rig.setTime(step * 0.1)
			rig.tracker:tick()
		end

		-- at t = 1.2 the oldest kept reading is from t = 0.2, when the character was already at x = 10
		expect(rig.tracker:tick()[1].groundSpeed).toBe(0)

		character:Destroy()
	end)

	it("walking up a slope on the ground counts the whole way along it", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		rig.tracker:tick()
		rig.setTime(1)
		rootOf(character).Position = Vector3.new(6, 13, 0) -- 6 across, 8 up

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(10, 5)

		character:Destroy()
	end)

	it("walking down a slope on the ground counts the whole way along it", function()
		local character = makeCharacter(Vector3.new(0, 13, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		rig.tracker:tick()
		rig.setTime(1)
		rootOf(character).Position = Vector3.new(6, 5, 0) -- 6 across, 8 down

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(10, 5)

		character:Destroy()
	end)

	it("a fall counts only the distance across the ground", function()
		local character = makeCharacter(Vector3.new(0, 35, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		rig.tracker:tick() -- standing on the ground at the start
		rig.setGrounded(false)
		-- ten ticks of 0.1 s, each 0.3 across and 3 down, all in the air
		for step = 1, 10 do
			rig.setTime(step * 0.1)
			rootOf(character).Position = Vector3.new(step * 0.3, 35 - step * 3, 0)
			rig.tracker:tick()
		end

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(3, 4)

		character:Destroy()
	end)

	it("one tick in the air makes the whole window count across the ground only", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		rig.setGrounded(true)
		rig.tracker:tick() -- t = 0 on the ground
		rig.setGrounded(false)
		rig.setTime(0.5)
		rootOf(character).Position = Vector3.new(3, 9, 0) -- a jump: 3 across, 4 up
		rig.tracker:tick()
		rig.setGrounded(true)
		rig.setTime(1)
		rootOf(character).Position = Vector3.new(6, 13, 0) -- back on the ground: 6 across, 8 up in total

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(6, 5)

		character:Destroy()
	end)

	it("climbing straight up on the ground counts as speed", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		rig.tracker:tick()
		rig.setTime(1)
		rootOf(character).Position = Vector3.new(0, 15, 0)

		expect(rig.tracker:tick()[1].groundSpeed).toBeCloseTo(10, 5)

		character:Destroy()
	end)

	it("a respawned character starts again at 0 studs a second", function()
		local first = makeCharacter(Vector3.new(0, 5, 0))
		local second = makeCharacter(Vector3.new(3, 5, 0))
		local player: PlayerTracker.PlayerLike = { UserId = 1, Character = first }
		local time = 0
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return { player }
			end,
			zoneBoxes = noZones,
			gardens = noGardens,
			isGrounded = neverGrounded,
			takeoffs = neverTookOff,
			now = function()
				return time
			end,
		})

		tracker:tick()
		time = 0.5
		rootOf(first).Position = Vector3.new(4.8, 5, 0)
		tracker:tick()
		player.Character = second
		time = 0.6

		expect(tracker:tick()[1].groundSpeed).toBe(0)

		first:Destroy()
		second:Destroy()
	end)
end)

describe("PlayerTracker jumps", function()
	it("asks once per living character per tick where it took off", function()
		local alive = makeCharacter(Vector3.new(0, 50, 0))
		local alsoAlive = makeCharacter(Vector3.new(5, 50, 0))
		local dead = makeCharacter(Vector3.new(9, 50, 0), 0)
		local players: { PlayerTracker.PlayerLike } = {
			{ UserId = 1, Character = alive },
			{ UserId = 2, Character = alsoAlive },
			{ UserId = 3, Character = dead },
			{ UserId = 4, Character = nil },
		}
		local asked: { [Model]: number } = {}
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = noZones,
			gardens = noGardens,
			isGrounded = neverGrounded,
			takeoffs = function(character: Model): { Vector3 }
				asked[character] = (asked[character] or 0) + 1
				return {}
			end,
			now = zeroClock,
		})

		tracker:tick()
		tracker:tick()
		tracker:tick()

		expect(asked[alive]).toBe(3)
		expect(asked[alsoAlive]).toBe(3)
		expect(asked[dead]).toBeNil()

		alive:Destroy()
		alsoAlive:Destroy()
		dead:Destroy()
	end)

	it("a jumped character's sample gets thudFrom once it comes to rest, with no tick in the air at all", function()
		local character = makeCharacter(Vector3.new(0, 50, 0))
		local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
		local takeoffsNow: { Vector3 } = {}
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = { { zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(100, 100, 100) } },
			gardens = noGardens,
			isGrounded = function(_character: Model): boolean
				return true -- the ground rises as fast as they do, so the ground check never says "in the air"
			end,
			takeoffs = function(_character: Model): { Vector3 }
				local answer = takeoffsNow
				takeoffsNow = {}
				return answer
			end,
			now = zeroClock,
		})
		local root = rootOf(character)

		takeoffsNow = { Vector3.new(0, 50, 0) }
		expect(tracker:tick()[1].thudFrom).toBeNil() -- the jump
		root.AssemblyLinearVelocity = Vector3.new(0, 6, 0) -- still going up the slope
		expect(tracker:tick()[1].thudFrom).toBeNil()
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		expect(tracker:tick()[1].thudFrom).toBeNil()
		expect(tracker:tick()[1].thudFrom).toBeNil()
		expect(tracker:tick()[1].thudFrom).toBe(BELLY)
		expect(tracker:tick()[1].thudFrom).toBeNil() -- only once

		character:Destroy()
	end)

	it("turns a take-off position into its zone, and a take-off inside a garden box is Meadow", function()
		-- The character stands far from every box, so only the take-off positions can give a zone.
		local character = makeCharacter(Vector3.new(500, 5, 500))
		local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
		local zoneBoxes: { Zones.ZoneBox } = {
			{ zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(100, 100, 100) },
		}
		local gardens: { Zones.GardenBox } = {
			{ index = 3, cframe = CFrame.new(30, 50, 0), size = Vector3.new(40, 40, 40) }, -- inside the Belly box
		}
		local takeoffsNow: { Vector3 } = {}
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = zoneBoxes,
			gardens = gardens,
			isGrounded = function(_character: Model): boolean
				return true
			end,
			takeoffs = function(_character: Model): { Vector3 }
				local answer = takeoffsNow
				takeoffsNow = {}
				return answer
			end,
			now = zeroClock,
		})
		local function thudAfterRest(): Config.ZoneName?
			tracker:tick()
			tracker:tick()
			return tracker:tick()[1].thudFrom
		end

		takeoffsNow = { Vector3.new(0, 50, 0) } -- inside the Belly box
		tracker:tick() -- the take-off
		expect(thudAfterRest()).toBe(BELLY)

		takeoffsNow = { Vector3.new(30, 50, 0) } -- inside the garden, which is also inside the Belly box
		tracker:tick()
		expect(thudAfterRest()).toBe("Meadow")

		character:Destroy()
	end)

	it("a held-Jump run, with the ground check never saying in the air, gives one thudFrom per hop", function()
		local character = makeCharacter(Vector3.new(0, 50, 0))
		local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
		local hopsOnTicks: { [number]: boolean } = { [1] = true, [3] = true, [5] = true }
		local tickNumber = 0
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return players
			end,
			zoneBoxes = { { zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(100, 100, 100) } },
			gardens = noGardens,
			isGrounded = function(_character: Model): boolean
				return true
			end,
			takeoffs = function(_character: Model): { Vector3 }
				return if hopsOnTicks[tickNumber] then { Vector3.new(0, 50, 0) } else {}
			end,
			now = zeroClock,
		})

		local thuds: { number } = {}
		for index = 1, 12 do
			tickNumber = index
			if tracker:tick()[1].thudFrom == BELLY then
				table.insert(thuds, index)
			end
		end

		expect(thuds).toEqual({ 3, 5, 8 }) -- the first two at the next take-offs, the last at rest

		character:Destroy()
	end)
end)
