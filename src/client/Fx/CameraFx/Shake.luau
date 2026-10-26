--!strict
-- The small screen shake when he wakes.

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

export type ShakeDeps = {
	giantState: Instance, -- ReplicatedStorage.GiantState: its Phase attribute says when he wakes
	player: PlayerLike, -- the local player: their character's Humanoid is shaken
	step: StepLike, -- once per frame (RenderStepped)
	now: () -> number, -- a clock in seconds (os.clock)
}

export type Shaker = {
	stop: () -> (), -- ends a shake in progress, puts the offset back and lets go of everything
}

-- Shakes the screen for 0.5 seconds each time Phase turns Awake. On every step it sets the shake part of the Humanoid's
-- CameraOffset to CameraFx.shakeOffset (the offset is then everything else it holds, such as the spawn view's raise, plus the
-- shake), and at the end it takes the shake off exactly and lets go of `step`. A new character ends the shake. No shake when
-- Phase is already Awake at the start (a player who joins during a wake-up).
function Shake.shakeOnWake(deps: ShakeDeps): Shaker
	local stopped = false
	local awake = deps.giantState:GetAttribute("Phase") == "Awake"
	local shaking: Humanoid? = nil
	local startedAt = 0
	local stepConnection: ConnectionLike? = nil

	-- Takes the shake off the shaken Humanoid's offset (what is left is the offset without the shake, including the spawn
	-- view's raise if there is one) and lets go of the step.
	local function endShake()
		if stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
		local humanoid = shaking
		if humanoid ~= nil then
			setShake(humanoid, Vector3.zero)
			shaking = nil
		end
	end

	local function onStep()
		local humanoid = shaking
		if humanoid == nil then
			endShake()
			return
		end
		local seconds = deps.now() - startedAt
		if seconds >= Config.Wake.ShakeSeconds then
			endShake()
		else
			setShake(humanoid, View.shakeOffset(seconds))
		end
	end

	local function beginShake()
		endShake()
		local character = deps.player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil then
			return
		end
		shaking = humanoid
		startedAt = deps.now()
		stepConnection = deps.step:Connect(onStep)
	end

	local phaseConnection = deps.giantState:GetAttributeChangedSignal("Phase"):Connect(function()
		if stopped then
			return
		end
		local nowAwake = deps.giantState:GetAttribute("Phase") == "Awake"
		if nowAwake and not awake then
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
			endShake()
		end,
	}
end

return Shake
