--!strict
-- Shared set-up for the PlayerTracker specs: a bare character, and a tracker for it with a clock, a "standing on
-- the ground" switch and a take-off list that the test sets by hand.
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Zones = require(ServerScriptService.Server.Giant.Zones)

local TrackerRig = {}

TrackerRig.noZones = {} :: { Zones.ZoneBox }
TrackerRig.noGardens = {} :: { Zones.GardenBox }

-- A character with no parent, so the test never changes the place. Destroy it when the test is done.
function TrackerRig.makeCharacter(position: Vector3, health: number?): Model
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

function TrackerRig.rootOf(character: Model): BasePart
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

-- A tracker for one character, with a clock, a "standing on the ground" switch and a take-off list the test sets by hand.
export type Rig = {
	tracker: PlayerTracker.Tracker,
	setTime: (seconds: number) -> (),
	setGrounded: (grounded: boolean) -> (),
	-- Take-offs handed out once on the next tick, then none.
	setTakeoffs: (positions: { Vector3 }) -> (),
}

function TrackerRig.groundSpeedRig(character: Model): Rig
	local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
	local time = 0
	local grounded = false
	local pendingTakeoffs: { Vector3 } = {}
	local tracker = PlayerTracker.new({
		getPlayers = function()
			return players
		end,
		zoneBoxes = TrackerRig.noZones,
		gardens = TrackerRig.noGardens,
		isGrounded = function(_character: Model): boolean
			return grounded
		end,
		takeoffs = function(_character: Model): { Vector3 }
			local handedOut = pendingTakeoffs
			pendingTakeoffs = {}
			return handedOut
		end,
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
		setTakeoffs = function(positions: { Vector3 })
			pendingTakeoffs = positions
		end,
	}
end

-- Puts the character at `x` across and `y` up, then reads the tracker once at `seconds`.
function TrackerRig.readAt(rig: Rig, character: Model, seconds: number, x: number, y: number): PlayerTracker.Sample
	rig.setTime(seconds)
	TrackerRig.rootOf(character).Position = Vector3.new(x, y, 0)
	return rig.tracker:tick()[1]
end

return TrackerRig
