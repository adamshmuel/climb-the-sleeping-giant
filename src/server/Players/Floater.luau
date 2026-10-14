--!strict
-- Floats each bounced player down onto their landing spot (Rule 12). The server moves the player to a point
-- FLOAT_HEIGHT studs above the spot, then a downward push lowers them straight down. Moving players to set
-- spots, instead of pushing them off the giant's body, means nobody can be flung or stuck in him.
-- It never touches the player's attributes (Carrying, Tiptoe, EggsHome) and never removes anything from the
-- character, so a carrier keeps their egg and Tiptoe stays on.
-- Everything it touches is passed in, so a test can give it fake players and a fake clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (any) -> ()) -> ConnectionLike,
}

-- What Floater needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	Character: Model?,
}

export type PlayersLike = {
	PlayerRemoving: SignalLike,
}

export type Deps = {
	players: PlayersLike,
	facePoint: Vector3, -- where bounced players turn to look: the centre of his face (Giant.SleepEyes)
	now: () -> number, -- a clock in seconds (os.clock), injected so a test can set the time by hand
}

export type Floater = {
	-- Turns the player to face his face (left-right only), moves them above `spot` and starts lowering them. Returns the
	-- flat look (a unit Vector3) they now face, or nil if it did nothing (no character, root or Humanoid, or destroyed).
	float: (self: Floater, player: PlayerLike, spot: WorldIndex.LandingSpot) -> Vector3?,
	-- One tick: lets go of every player who is low enough, whose float time is up, or who lost their character.
	step: (self: Floater) -> (),
	-- Is this player still being lowered? Task 29 never picks them as a slam target.
	isFloating: (self: Floater, userId: number) -> boolean,
	-- Seconds since this player's float touched down (see TOUCHDOWN_DROP_SECONDS), or nil if it hasn't in this wake-up: they
	-- never floated, the float ended because the character was gone, they left, or a new float has started. It can be
	-- a little below 0 just after the push lets go.
	landedAgo: (self: Floater, userId: number) -> number?,
	-- Removes every float and every connection. Safe to call twice.
	destroy: (self: Floater) -> (),
}

-- How far above standing height the player starts. High enough to clear the giant's body from anywhere on him.
local FLOAT_HEIGHT = 12
-- Studs a second the player is lowered. Slower than a thud's 10 studs a second, so the fall is gentle to watch.
local FLOAT_SPEED = 8
-- The push lets go this many studs above standing height, and gravity does the last bit. The server sees the player
-- late, so a push that waited to see them low would press them into the ground.
local FLOAT_END_ABOVE = 2.5
-- When the push should have reached FLOAT_END_ABOVE. The start and the end reach the player's device with the same
-- delay, so ending by time doesn't depend on ping.
local FLOAT_EXPECTED_SECONDS = (FLOAT_HEIGHT - FLOAT_END_ABOVE) / FLOAT_SPEED
-- The longest a float may last, in case something holds the player up.
local FLOAT_MAX_SECONDS = 4
-- The last FLOAT_END_ABOVE studs of the drop take about 0.16 s at Roblox's gravity. The player counts as touched down
-- this long after the push lets go: a little late, which errs on the player's side (the slams give a new arrival
-- time to look around).
local TOUCHDOWN_DROP_SECONDS = 0.25

-- The name of the attachment and the LinearVelocity, so they can be found.
local PART_NAME = "BounceFloat"

-- One player being lowered.
type Float = {
	player: PlayerLike,
	character: Model,
	root: BasePart,
	attachment: Attachment,
	velocity: LinearVelocity,
	restHeight: number, -- where the root sits when the player stands on the spot
	startedAt: number,
}

local Floater = {}

-- The direction from `spot` to `facePoint`, laid flat: left-right only, no tilt. A spot right under the face has no
-- direction, so it gets the world's forward. Catcher uses it too, to turn a caught player toward his face.
function Floater.flatDirection(spot: Vector3, facePoint: Vector3): Vector3
	local flat = Vector3.new(facePoint.X - spot.X, 0, facePoint.Z - spot.Z)
	if flat.Magnitude < 1e-3 then
		return -Vector3.zAxis
	end
	return flat.Unit
end

function Floater.start(deps: Deps): Floater
	local trove = Trove.new()
	local stopped = false
	local floats: { [number]: Float } = {}
	-- When each player's last float touched down (on `deps.now`'s clock). Only a float that ended on its own is here.
	local touchdowns: { [number]: number } = {}

	-- Removes the push and its attachment, and forgets the player. Safe if the character is already gone.
	-- `landed` is true when the float ended by itself (low enough, or its time was up): that starts the touchdown time.
	local function release(userId: number, landed: boolean)
		local existing = floats[userId]
		if existing == nil then
			return
		end
		floats[userId] = nil
		if landed then
			touchdowns[userId] = deps.now() + TOUCHDOWN_DROP_SECONDS
		else
			touchdowns[userId] = nil
		end
		existing.velocity:Destroy()
		existing.attachment:Destroy()
	end

	local function float(_self: Floater, player: PlayerLike, spot: WorldIndex.LandingSpot): Vector3?
		if stopped then
			return nil
		end
		local character = player.Character
		if character == nil then
			return nil
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")
		-- The Humanoid's own RootPart is nil outside Workspace, so both are found by name.
		if root == nil or not root:IsA("BasePart") or humanoid == nil or not humanoid:IsA("Humanoid") then
			return nil
		end

		-- A second float for the same player replaces the first. A new float means the last touchdown no longer counts.
		release(player.UserId, false)
		touchdowns[player.UserId] = nil

		local restHeight = spot.position.Y + humanoid.HipHeight + root.Size.Y / 2
		local above = Vector3.new(spot.position.X, restHeight + FLOAT_HEIGHT, spot.position.Z)
		local look = Floater.flatDirection(spot.position, deps.facePoint)
		local target = CFrame.lookAt(above, above + look)
		-- Moves the whole character, not only the root: whatever hangs on the character (a carried egg) keeps its place.
		character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		local attachment = Instance.new("Attachment")
		attachment.Name = PART_NAME
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = PART_NAME
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.VectorVelocity = Vector3.new(0, -FLOAT_SPEED, 0)
		velocity.ForceLimitsEnabled = false
		velocity.Parent = root

		floats[player.UserId] = {
			player = player,
			character = character,
			root = root,
			attachment = attachment,
			velocity = velocity,
			restHeight = restHeight,
			startedAt = deps.now(),
		}
		return look
	end

	-- The players that are floating now, in a list, so `release` can change `floats` while we go through it.
	local function floatingUserIds(): { number }
		local ids: { number } = {}
		for userId in floats do
			table.insert(ids, userId)
		end
		return ids
	end

	-- A float is over if its character is gone or replaced (a respawn), or its root is no longer in the character.
	local function characterGone(existing: Float): boolean
		return existing.player.Character ~= existing.character or existing.root.Parent ~= existing.character
	end

	local function step(_self: Floater)
		if stopped then
			return
		end
		local now = deps.now()
		for _, userId in floatingUserIds() do
			local existing = floats[userId]
			if existing == nil then
				continue
			end
			if characterGone(existing) then
				release(userId, false)
			elseif
				existing.root.Position.Y <= existing.restHeight + FLOAT_END_ABOVE
				or now - existing.startedAt >= FLOAT_EXPECTED_SECONDS
				or now - existing.startedAt >= FLOAT_MAX_SECONDS
			then
				release(userId, true)
			end
		end
	end

	local function isFloating(_self: Floater, userId: number): boolean
		return floats[userId] ~= nil
	end

	local function landedAgo(_self: Floater, userId: number): number?
		local touchdown = touchdowns[userId]
		if touchdown == nil then
			return nil
		end
		return deps.now() - touchdown
	end

	local function destroy(_self: Floater)
		if stopped then
			return
		end
		stopped = true
		for _, userId in floatingUserIds() do
			release(userId, false)
		end
		table.clear(touchdowns)
		trove:Destroy()
	end

	trove:Add(deps.players.PlayerRemoving:Connect(function(player: any)
		local userId = (player :: PlayerLike).UserId
		release(userId, false)
		touchdowns[userId] = nil
	end))

	return { float = float, step = step, isFloating = isFloating, landedAgo = landedAgo, destroy = destroy }
end

return Floater
