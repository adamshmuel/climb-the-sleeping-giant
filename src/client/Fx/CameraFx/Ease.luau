--!strict
-- The two easings (pitch back to normal, and the raise back to 0) and what decides when they run.

local TweenService = game:GetService("TweenService")

local Shared = require(script.Parent.Shared)
local View = require(script.Parent.View)

type CameraLike = Shared.CameraLike
local heightOf = Shared.heightOf
local setHeight = Shared.setHeight

local Ease = {}

-- The names of the render-step bindings that ease the camera back and ease its height back (a binding needs a name that
-- nothing else uses).
local EASE_BINDING_NAME = "CameraFxEaseBack"

-- The most times the spawn view is put back in the settle window (see `shouldReplace`).
local MAX_PLACEMENTS = 5

-- Render steps run in order of priority. One above Roblox's camera runs right after it, so what we write sticks and
-- the player's input is already in the camera we start from.
local AFTER_CAMERA_PRIORITY = Enum.RenderPriority.Camera.Value + 1

export type RunServiceLike = {
	BindToRenderStep: (self: any, name: string, priority: number, callback: (deltaTime: number) -> ()) -> (),
	UnbindFromRenderStep: (self: any, name: string) -> (),
}

-- Makes the function that runs a step every frame, right after Roblox's camera has moved the camera: it binds the step
-- to the render loop under a fixed name (`name`, or the camera ease's own) and gives back a function that unbinds it. Only
-- one step may be bound under a name at a time.
function Ease.renderBinder(runService: RunServiceLike, name: string?): (step: () -> ()) -> () -> ()
	local bindingName = name or EASE_BINDING_NAME
	return function(step: () -> ()): () -> ()
		runService:BindToRenderStep(bindingName, AFTER_CAMERA_PRIORITY, function()
			step()
		end)
		return function()
			runService:UnbindFromRenderStep(bindingName)
		end
	end
end

export type EaseBack = {
	run: (camera: CameraLike, seconds: number, endPitchDegrees: number) -> (),
	cancel: () -> (),
	isRunning: () -> boolean,
	lastLook: () -> Vector3?,
}

-- Makes something that eases the camera's pitch to `endPitchDegrees` over `seconds` (the time is read from `now`, not
-- counted in frames). `run` does not wait: it asks `bindAfterCamera` to run a step every frame, after Roblox's camera
-- (it gives back a function that stops that), and returns. The camera stays `Custom` the whole time. Each step:
--  * stops (and writes nothing) if someone else took the camera, or if `isTurning()` says the player is turning it:
--    Roblox's camera has already applied the turn this frame;
--  * otherwise writes the camera with only the pitch changed (`withPitch`), the last step writing exactly the end pitch.
-- `cancel` stops it at once. A camera that is not on Custom when `run` is called is left alone. `lastLook` is the look
-- the camera had when we last wrote it (nil when not running), for spotting a turn when the real turn signal is missing.
function Ease.newEaseBack(
	bindAfterCamera: (step: () -> ()) -> () -> (),
	now: () -> number,
	isTurning: () -> boolean
): EaseBack
	local unbind: (() -> ())? = nil
	local writtenLook: Vector3? = nil
	local runNumber = 0

	local function cancel()
		runNumber += 1
		writtenLook = nil
		local unbindNow = unbind
		unbind = nil
		if unbindNow then
			unbindNow()
		end
	end

	local function run(camera: CameraLike, seconds: number, endPitchDegrees: number)
		cancel() -- never two runs at once
		if camera.CameraType ~= Enum.CameraType.Custom then
			return
		end
		local thisRun = runNumber
		local startLook = camera.CFrame.LookVector
		local startPitch = View.pitchOf(startLook)
		local startTime = now()
		writtenLook = startLook

		local function step()
			if runNumber ~= thisRun then
				return
			end
			if camera.CameraType ~= Enum.CameraType.Custom or isTurning() then
				cancel()
				return
			end
			local alpha = if seconds > 0 then (now() - startTime) / seconds else 1
			local pitch = endPitchDegrees
			if alpha < 1 then
				local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				pitch = startPitch + (endPitchDegrees - startPitch) * eased
			end
			camera.CFrame = View.withPitch(camera.CFrame, camera.Focus.Position, pitch)
			if alpha >= 1 then
				cancel()
			else
				writtenLook = camera.CFrame.LookVector
			end
		end

		unbind = bindAfterCamera(step)
	end

	return {
		run = run,
		cancel = cancel,
		isRunning = function()
			return unbind ~= nil
		end,
		lastLook = function()
			return writtenLook
		end,
	}
end

export type HeightEase = {
	run: (humanoid: Humanoid, seconds: number) -> (),
	cancel: () -> (),
	isRunning: () -> boolean,
}

-- Makes something that eases a Humanoid's raise down to exactly 0 over `seconds` (the time is read from `now`), with the
-- same Sine in-and-out curve as the tilt's ease. Like `newEaseBack`, `run` does not wait: it asks `bindAfterCamera` to run
-- a step every frame and returns. Unlike the tilt, a camera turn never stops it: the raise never changes where the camera
-- points, so it can't fight the player's turn. It runs from where the raise is now. `cancel` stops it where it is (it does
-- not change the raise); a raise that is already 0 starts nothing.
function Ease.newHeightEase(bindAfterCamera: (step: () -> ()) -> () -> (), now: () -> number): HeightEase
	local unbind: (() -> ())? = nil
	local runNumber = 0

	local function cancel()
		runNumber += 1
		local unbindNow = unbind
		unbind = nil
		if unbindNow then
			unbindNow()
		end
	end

	local function run(humanoid: Humanoid, seconds: number)
		cancel() -- never two runs at once
		local startHeight = heightOf(humanoid)
		if startHeight == Vector3.zero then
			return
		end
		local thisRun = runNumber
		local startTime = now()

		local function step()
			if runNumber ~= thisRun then
				return
			end
			local alpha = if seconds > 0 then (now() - startTime) / seconds else 1
			if alpha >= 1 then
				cancel()
				setHeight(humanoid, Vector3.zero)
				return
			end
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			setHeight(humanoid, startHeight * (1 - eased))
		end

		unbind = bindAfterCamera(step)
	end

	return {
		run = run,
		cancel = cancel,
		isRunning = function()
			return unbind ~= nil
		end,
	}
end

-- True when `state` (what an InputAction holds) is a Vector2 that is not zero: the player is turning the camera.
local function isTurningState(state: unknown): boolean
	return typeof(state) == "Vector2" and (state :: Vector2).Magnitude > 0
end

-- Looks for Roblox's camera input, `PlayerModule.InputContexts.CameraContext.CameraRotationAction`, under each
-- container in turn. It is an InputAction whose state is not zero exactly while the player turns the camera, by key,
-- mouse drag, touch drag or gamepad stick (zooming is another action). Returns the first one found.
local function findRotationAction(containers: { Instance? }): InputAction?
	for _, container in containers do
		local found: Instance? = container
		for _, name in { "PlayerModule", "InputContexts", "CameraContext", "CameraRotationAction" } do
			found = if found then found:FindFirstChild(name) else nil
		end
		if found and found:IsA("InputAction") then
			return found
		end
	end
	return nil
end

-- Makes the function that says whether the player is turning the camera right now: Roblox's camera input is looked up
-- once, here, and the function is true while its state is not zero. If it can't be found (Roblox moved it), the
-- function answers with `fallback` instead (the caller compares the look with the last one it wrote) and warns once.
-- `warnFn` and `readState` stand in for `warn` and `action:GetState()` in tests.
function Ease.rotationInput(
	containers: { Instance? },
	fallback: () -> boolean,
	warnFn: ((message: string) -> ())?,
	readState: ((action: InputAction) -> unknown)?
): () -> boolean
	local action = findRotationAction(containers)
	if action then
		local function readAction(found: InputAction): unknown
			return found:GetState()
		end
		local read: (InputAction) -> unknown = readAction
		if readState then
			read = readState
		end
		return function()
			return isTurningState(read(action))
		end
	end
	local warned = false
	return function()
		if not warned then
			warned = true
			local message = "CameraFx: CameraRotationAction was not found under PlayerModule.InputContexts.CameraContext. "
				.. "Spotting a camera turn by comparing the camera's look instead."
			if warnFn then
				warnFn(message)
			else
				warn(message)
			end
		end
		return fallback()
	end
end

-- Whether to put the spawn view back this frame: only inside the settle window, while under MAX_PLACEMENTS, when
-- the view jumped (the camera script moved it), and never while the player is turning the camera: a player's turn
-- is not a jump to undo.
function Ease.shouldReplace(inSettleWindow: boolean, placements: number, jumped: boolean, turning: boolean): boolean
	return inSettleWindow and placements < MAX_PLACEMENTS and jumped and not turning
end

return Ease
