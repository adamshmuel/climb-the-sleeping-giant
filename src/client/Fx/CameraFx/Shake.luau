--!strict
-- The screen shake when he wakes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Shared = require(script.Parent.Shared)
local View = require(script.Parent.View)

type ConnectionLike = Shared.ConnectionLike
type PlayerLike = Shared.PlayerLike
local setShake = Shared.setShake

local Shake = {}

export type StepLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

type EventLike = { Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection }

type RemoteLike = { OnClientEvent: EventLike }

export type ShakeDeps = {
	giantState: Instance, -- ReplicatedStorage.GiantState: its Phase attribute says when he wakes
	player: PlayerLike, -- the local player: their character's Humanoid is shaken
	step: StepLike, -- once per frame (RenderStepped)
	now: () -> number, -- a clock in seconds (os.clock)
	-- Optional (Task 14): without them it is the wake shake alone.
	slamWarning: RemoteLike?, -- SlamWarning(slam number, point, landsAt on the server clock)
	slamLanded: RemoteLike?, -- SlamLanded(slam number, point)
	serverNow: (() -> number)?, -- the server's clock, to compare with landsAt
	reducedMotion: (() -> boolean)?, -- true when the player asked for less motion
	playSound: ((name: string, at: Vector3?) -> ())?, -- plays a named sound once
}

export type Shaker = {
	stop: () -> (), -- ends a shake in progress, puts the offset back and lets go of everything
}

type PendingSlam = { number: number, point: Vector3, landsAt: number }

-- Shakes the screen for Config.Wake.WakeShakeSeconds each time Phase turns Awake, and for Config.Wake.SlamShakeSeconds when a
-- slam lands (SlamWarning stores it, SlamLanded or the server clock reaching landsAt lands it, whichever comes first).
-- On every step it sets the shake part of the Humanoid's CameraOffset (the offset is then everything else it holds, such
-- as the spawn view's raise, plus the shake), and at the end it takes the shake off exactly. The step is connected only
-- while a slam is pending or a shake runs. One shake at a time: a new one replaces one still fading. A new character ends
-- the shake. No shake when Phase is already Awake at the start (a player who joins during a wake-up).
function Shake.shakeOnWake(deps: ShakeDeps): Shaker
	local stopped = false
	local awake = deps.giantState:GetAttribute("Phase") == "Awake"
	local shaking: Humanoid? = nil
	local startedAt = 0 -- on the local clock (deps.now)
	local shakeLength = 0
	local shakeOffsetAt: (number) -> Vector3 = View.shakeOffset
	local stepConnection: ConnectionLike? = nil
	local pending: { PendingSlam } = {}

	-- Connects the step while something needs it (a pending slam or a running shake), lets go of it otherwise.
	local function refreshStep(onStep: () -> ())
		local wanted = not stopped and (shaking ~= nil or #pending > 0)
		if wanted and stepConnection == nil then
			stepConnection = deps.step:Connect(onStep)
		elseif not wanted and stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end

	local onStep: () -> () = function() end

	-- Takes the shake off the shaken Humanoid's offset (what is left is the offset without the shake, including the spawn
	-- view's raise if there is one).
	local function endShake()
		local humanoid = shaking
		if humanoid ~= nil then
			setShake(humanoid, Vector3.zero)
			shaking = nil
		end
		refreshStep(onStep)
	end

	local function startShake(humanoid: Humanoid, at: number, length: number, offsetAt: (number) -> Vector3)
		local previous = shaking
		if previous ~= nil and previous ~= humanoid then
			setShake(previous, Vector3.zero)
		end
		shaking = humanoid
		startedAt = at
		shakeLength = length
		shakeOffsetAt = offsetAt
		refreshStep(onStep)
	end

	local function reduced(): boolean
		local read = deps.reducedMotion
		return read ~= nil and read()
	end

	local function localHumanoid(): Humanoid?
		local character = deps.player.Character
		return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	end

	-- A slam lands: it shakes from `at` (local clock) by how far it is across the ground from the player's root part.
	local function landSlam(slam: PendingSlam, at: number)
		if reduced() or deps.now() - at >= Config.Wake.SlamShakeSeconds then
			return
		end
		local character = deps.player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = localHumanoid()
		if humanoid == nil or root == nil or not root:IsA("BasePart") then
			return
		end
		local across = Vector3.new(root.Position.X - slam.point.X, 0, root.Position.Z - slam.point.Z).Magnitude
		if View.slamShakeStuds(across) <= 0 then
			return
		end
		startShake(humanoid, at, Config.Wake.SlamShakeSeconds, function(seconds: number): Vector3
			return View.slamShakeOffset(seconds, across)
		end)
	end

	onStep = function()
		if stopped then
			return
		end
		local serverNow = deps.serverNow
		if serverNow ~= nil and #pending > 0 then
			local serverTime = serverNow()
			local i = 1
			while i <= #pending do
				local slam = pending[i]
				if serverTime >= slam.landsAt then
					table.remove(pending, i)
					-- Start on the local clock, measured back from landsAt on the server's: the clocks are never mixed.
					landSlam(slam, deps.now() - (serverTime - slam.landsAt))
				else
					i += 1
				end
			end
		end
		local humanoid = shaking
		if humanoid == nil then
			refreshStep(onStep)
			return
		end
		local seconds = deps.now() - startedAt
		if seconds >= shakeLength then
			endShake()
		else
			setShake(humanoid, shakeOffsetAt(seconds))
		end
	end

	local function beginShake()
		endShake()
		-- Reduce Motion is read here, at the start of each wake shake: on means no offset and no step connection.
		local humanoid = if reduced() then nil else localHumanoid()
		if humanoid == nil then
			return
		end
		startShake(humanoid, deps.now(), Config.Wake.WakeShakeSeconds, View.shakeOffset)
	end

	local function isGoodNumber(value: any): boolean
		return typeof(value) == "number" and value == value and math.abs(value) < math.huge
	end

	local function onWarning(number: any, point: any, landsAt: any)
		if stopped or not isGoodNumber(number) or typeof(point) ~= "Vector3" or not isGoodNumber(landsAt) then
			return
		end
		if not (point.Magnitude < math.huge) or reduced() then
			return
		end
		for i, old in pending do
			if old.number == number then
				table.remove(pending, i)
				break
			end
		end
		table.insert(pending, { number = number, point = point, landsAt = landsAt })
		refreshStep(onStep)
	end

	local function onLanded(number: any)
		if stopped then
			return
		end
		for i, slam in pending do
			if slam.number == number then
				table.remove(pending, i)
				landSlam(slam, deps.now())
				break
			end
		end
		refreshStep(onStep)
	end

	local warningConnection: RBXScriptConnection? = nil
	if deps.slamWarning ~= nil then
		warningConnection = deps.slamWarning.OnClientEvent:Connect(onWarning)
	end
	local landedConnection: RBXScriptConnection? = nil
	if deps.slamLanded ~= nil then
		landedConnection = deps.slamLanded.OnClientEvent:Connect(onLanded)
	end

	local phaseConnection = deps.giantState:GetAttributeChangedSignal("Phase"):Connect(function()
		if stopped then
			return
		end
		local nowAwake = deps.giantState:GetAttribute("Phase") == "Awake"
		if nowAwake and not awake then
			table.clear(pending) -- a slam warned about before the wake never lands
			-- The rumble plays once per wake, with Reduce Motion on and with no character (not for a join mid-wake, not for slams).
			if deps.playSound ~= nil then
				deps.playSound("WakeRumble", nil)
			end
			beginShake()
		end
		awake = nowAwake
	end)
	local characterConnection = deps.player.CharacterAdded:Connect(function(_character: Model)
		endShake()
	end)

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			phaseConnection:Disconnect()
			characterConnection:Disconnect()
			if warningConnection ~= nil then
				warningConnection:Disconnect()
			end
			if landedConnection ~= nil then
				landedConnection:Disconnect()
			end
			table.clear(pending)
			endShake()
		end,
	}
end

return Shake
