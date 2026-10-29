--!strict
-- Remembers where each player last stood safely, so a rescue or a Reset on the giant has a good place to
-- go back to. Pure: keys are UserIds, time and the room check are passed in, no Roblox services.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- A new spot must be this many studs from the newest one, so standing still doesn't fill the list.
local MIN_GAP = 1
-- How many spots a player keeps (the newest). Players can't see this number.
local KEEP = 40
-- The facing used when a player has stood still since joining and has no spot yet.
local DEFAULT_FACING = Vector3.new(0, 0, -1)
-- A walking direction shorter than this counts as standing still.
local MIN_FACING = 0.01

export type Spot = { feet: Vector3, facing: Vector3 }

export type Sample = {
	now: number,
	feet: Vector3,
	facing: Vector3,
	groundNormal: Vector3?,
	state: Enum.HumanoidStateType,
	floating: boolean,
	hasRoom: () -> boolean,
}

type Player = {
	spots: { Spot }, -- oldest first
	lastCheck: number?,
}

type State = {
	minGroundY: number,
	players: { [number]: Player },
}

local SafeSpots = {}
SafeSpots.__index = SafeSpots

export type SafeSpots = typeof(setmetatable({} :: State, SafeSpots))

-- maxSlopeAngle: the steepest ground a player can walk on, in degrees (StarterPlayer.CharacterMaxSlopeAngle).
function SafeSpots.new(maxSlopeAngle: number): SafeSpots
	return setmetatable({
		minGroundY = math.cos(math.rad(maxSlopeAngle)),
		players = {},
	}, SafeSpots)
end

local function playerOf(self: SafeSpots, userId: number): Player
	local player = self.players[userId]
	if not player then
		player = { spots = {}, lastCheck = nil }
		self.players[userId] = player
	end
	return player :: Player
end

local function flatFacing(facing: Vector3, newest: Spot?): Vector3
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < MIN_FACING then
		return if newest then newest.facing else DEFAULT_FACING
	end
	return flat.Unit
end

-- Checks one sample, cheapest test first. Returns true when a spot was saved.
function SafeSpots.sample(self: SafeSpots, userId: number, sample: Sample): boolean
	local player = playerOf(self, userId)
	local last = player.lastCheck
	if last ~= nil and sample.now - last < Config.Stuck.SafeSaveSeconds then
		return false
	end
	player.lastCheck = sample.now

	if sample.state ~= Enum.HumanoidStateType.Running and sample.state ~= Enum.HumanoidStateType.RunningNoPhysics then
		return false
	end
	if sample.floating then
		return false
	end
	local normal = sample.groundNormal
	if normal == nil or normal.Y < self.minGroundY then
		return false
	end
	local spots = player.spots
	local newest = spots[#spots]
	if newest and (sample.feet - newest.feet).Magnitude < MIN_GAP then
		return false
	end
	if not sample.hasRoom() then
		return false
	end

	table.insert(spots, { feet = sample.feet, facing = flatFacing(sample.facing, newest) })
	if #spots > KEEP then
		table.remove(spots, 1)
	end
	return true
end

-- The newest spot at least RescueDistance studs from `from`, as a copy, or nil when there is none.
function SafeSpots.pick(self: SafeSpots, userId: number, from: Vector3): Spot?
	local player = self.players[userId]
	if not player then
		return nil
	end
	for i = #player.spots, 1, -1 do
		local spot = player.spots[i]
		if (spot.feet - from).Magnitude >= Config.Stuck.RescueDistance then
			return { feet = spot.feet, facing = spot.facing }
		end
	end
	return nil
end

-- The last saved spot, as a copy, whatever its distance from the feet, or nil when there is none.
function SafeSpots.newest(self: SafeSpots, userId: number): Spot?
	local player = self.players[userId]
	local spot = if player then player.spots[#player.spots] else nil
	if spot == nil then
		return nil
	end
	return { feet = spot.feet, facing = spot.facing }
end

function SafeSpots.count(self: SafeSpots, userId: number): number
	local player = self.players[userId]
	return if player then #player.spots else 0
end

-- Drops a player's spots and the time of their last check.
function SafeSpots.forget(self: SafeSpots, userId: number)
	self.players[userId] = nil
end

return SafeSpots
