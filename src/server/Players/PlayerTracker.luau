--!strict
-- Reads where each character really is, ten times a second: moving or standing still, which zone,
-- which garden, and whether a fall just ended with a thud. The server works this out itself; nothing here comes
-- from a client.

-- A step of more than this many studs between two ticks counts as moving (docs/architecture.md, section 3).
local MOVING_DISTANCE = 0.5
-- A step of more than this many studs in one tick is a teleport (a respawn, a bounce-off), not walking.
local TELEPORT_DISTANCE = 20
-- The speed is measured over this many seconds of real time. A whole second smooths out the bursts in which
-- positions arrive.
local SPEED_WINDOW_SECONDS = 1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LandingDetector = require(script.Parent.LandingDetector)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)
local Zones = require(script.Parent.Parent.Giant.Zones)

-- What the tracker reads about one player each tick, for the host to use.
export type Sample = {
	userId: number,
	position: Vector3,
	moving: boolean,
	-- Studs a second over the last 1 s of real time: along the slope while on the ground the whole time, across the
	-- ground (not up or down) after any time in the air, so jumps and falls never count as speed.
	groundSpeed: number,
	zone: Config.ZoneName,
	garden: number?,
	thudFrom: Config.ZoneName?, -- set on the tick a thud is due: the highest zone the fall (or hop) left
}

-- What the tracker needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = { UserId: number, Character: Model? }

export type Deps = {
	getPlayers: () -> { PlayerLike },
	zoneBoxes: { Zones.ZoneBox },
	gardens: { Zones.GardenBox },
	isGrounded: (character: Model) -> boolean, -- injected, so tests can fake it
	-- Where this character's jumps took off since the last time it was asked, oldest first (JumpWatcher).
	takeoffs: (character: Model) -> { Vector3 },
	now: () -> number, -- the clock in seconds (os.clock), injected so tests can set the time by hand
}

export type Tracker = { tick: (self: Tracker) -> { Sample } }

-- Where a character was at one moment, for measuring its speed.
type Reading = { time: number, position: Vector3, grounded: boolean }

-- What the tracker remembers about one player between ticks. A new character starts a new memory.
type Memory = {
	character: Model,
	lastPosition: Vector3?,
	landing: LandingDetector.State,
	readings: { Reading }, -- the last 1 s of readings, oldest first
}

-- How far below the feet the ground check still says "on the ground", in studs.
local GROUND_REACH = 0.5

local PlayerTracker = {}

-- The gardens' boxes in the shape Zones wants.
function PlayerTracker.gardenBoxes(gardens: { WorldIndex.Garden }): { Zones.GardenBox }
	local boxes: { Zones.GardenBox } = {}
	for _, garden in gardens do
		table.insert(boxes, { index = garden.index, cframe = garden.box.cframe, size = garden.box.size })
	end
	return boxes
end

-- Could a player stand on a surface with this normal (the direction it faces)? Only if its slope is no steeper
-- than `maxSlopeAngle` degrees (StarterPlayer.CharacterMaxSlopeAngle). Flat ground faces straight up (Y = 1),
-- a wall faces sideways (Y = 0), so the steepest allowed slope is the one whose normal has Y = cos(angle).
function PlayerTracker.isStandable(normal: Vector3, maxSlopeAngle: number): boolean
	return normal.Y >= math.cos(math.rad(maxSlopeAngle))
end

-- Is the character standing on something solid? A short ray goes straight down from the root part, a little
-- longer than the way to the feet. Only solid parts count (RespectCanCollide), so the invisible zone boxes
-- don't. Every character is left out, so one player standing on another's head is not "on the ground".
-- A surface too steep to stand on (his steep sides) is not ground either, so brushing past him is no landing.
function PlayerTracker.groundedByRay(character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return false
	end
	local excluded: { Instance } = { character }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(excluded, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.ExcludeInstances = excluded
	params.RespectCanCollide = true
	local length = humanoid.HipHeight + root.Size.Y / 2 + GROUND_REACH
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -length, 0), params)
	return hit ~= nil and PlayerTracker.isStandable(hit.Normal, StarterPlayer.CharacterMaxSlopeAngle)
end

-- Did the character move since the last tick? The distance is measured in 3D, so climbing straight up counts.
function PlayerTracker.isMoving(previous: Vector3?, current: Vector3): boolean
	if previous == nil then
		return false
	end
	local distance = (current - previous).Magnitude
	return distance > MOVING_DISTANCE and distance <= TELEPORT_DISTANCE
end

-- Adds a reading and drops the ones older than the window. A step of more than TELEPORT_DISTANCE (a respawn, a
-- bounce-off) clears the list first, so a teleport never counts as speed.
local function recordReading(memory: Memory, time: number, position: Vector3, grounded: boolean)
	local last = memory.lastPosition
	if last ~= nil and (position - last).Magnitude > TELEPORT_DISTANCE then
		table.clear(memory.readings)
	end
	table.insert(memory.readings, { time = time, position = position, grounded = grounded })
	while #memory.readings > 1 and time - memory.readings[1].time > SPEED_WINDOW_SECONDS do
		table.remove(memory.readings, 1)
	end
end

-- Studs a second from the oldest kept reading to the newest. If the character was on the ground in every reading,
-- the whole distance along the slope counts (up or down), so a steep path is not a way to hide speed. If it was in
-- the air in any of them (a jump or a fall), only the distance across the ground counts, so falling never counts as
-- speed. 0 when there is no older reading or no time has passed between them (three ticks in one frame all share
-- one time).
local function groundSpeedOf(readings: { Reading }): number
	local oldest = readings[1]
	local newest = readings[#readings]
	local seconds = newest.time - oldest.time
	if seconds <= 0 then
		return 0
	end
	local allGrounded = true
	for _, reading in readings do
		if not reading.grounded then
			allGrounded = false
			break
		end
	end
	local moved = newest.position - oldest.position
	if not allGrounded then
		moved = Vector3.new(moved.X, 0, moved.Z)
	end
	return moved.Magnitude / seconds
end

-- The root part of a character that is alive and complete, or nil.
local function livingRoot(character: Model?): BasePart?
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

function PlayerTracker.new(deps: Deps): Tracker
	local memories: { [number]: Memory } = {}

	local function tick(_self: Tracker): { Sample }
		local samples: { Sample } = {}
		local players = deps.getPlayers()
		local present: { [number]: boolean } = {}
		for _, player in players do
			present[player.UserId] = true
		end
		for userId in memories do
			if not present[userId] then
				memories[userId] = nil -- they left, so forget them
			end
		end
		for _, player in players do
			local character = player.Character
			local root = livingRoot(character)
			if character and root then
				local place = Zones.locate(root.Position, deps.zoneBoxes, deps.gardens)
				local memory = memories[player.UserId]
				if memory == nil or memory.character ~= character then
					memory = {
						character = character,
						lastPosition = nil,
						landing = LandingDetector.new(place.zone),
						readings = {},
					}
					memories[player.UserId] = memory
				end
				local moving = PlayerTracker.isMoving(memory.lastPosition, root.Position)
				local grounded = deps.isGrounded(character)
				recordReading(memory, deps.now(), root.Position, grounded)
				memory.lastPosition = root.Position
				local takeoffZones: { Config.ZoneName } = {}
				for _, position in deps.takeoffs(character) do
					table.insert(takeoffZones, Zones.locate(position, deps.zoneBoxes, deps.gardens).zone)
				end
				local thudFrom: Config.ZoneName?
				thudFrom, memory.landing = LandingDetector.step(
					memory.landing,
					grounded,
					root.AssemblyLinearVelocity.Y,
					place.zone,
					takeoffZones
				)
				table.insert(samples, {
					userId = player.UserId,
					position = root.Position,
					moving = moving,
					groundSpeed = groundSpeedOf(memory.readings),
					zone = place.zone,
					garden = place.garden,
					thudFrom = thudFrom,
				})
			end
		end
		return samples
	end
	return { tick = tick }
end

return PlayerTracker
