--!strict
-- The camera at spawn: behind the player, facing the way they face, tilted up. Set once at every spawn.
-- Then, on the player's first move, if they have not turned the camera, it eases back to Roblox's normal view so the
-- footprints show on the walk (spec Rule 1, "Spawn facing the giant"). After that the player controls the camera:
-- nothing here holds it.
--
-- The camera is never held: while the ease runs it stays `Custom`, so Roblox's own camera keeps listening to the
-- player (a camera turn must work at once, with keys, mouse and touch). The ease only changes the pitch, every frame,
-- right after Roblox's camera has moved the camera, and stops the moment the player turns.
--
-- At every spawn, also after a catch, two more things happen (spec Rule 1, "Spawn facing the giant"):
--  * the player and the camera turn away from the first egg when it would sit behind the player (`awayFromEgg`, used by
--    `watch`), so the egg, its label and the footprints show beside them;
--  * the camera sits 1.5 studs higher while the spawn view is placed. That is Humanoid.CameraOffset, which Roblox's camera
--    adds to the point it follows, so the camera and that point move together and the look direction never changes. It
--    eases back to 0 from the first move or the first camera turn, whichever comes first.
--
-- The small screen shake when he wakes (spec Rule 12, "Waking bounces everyone off") is here too: shakeOnWake moves
-- Humanoid.CameraOffset for 0.5 seconds, never by more than 0.5 studs, the same way, so the shake is never mistaken for
-- the player turning the camera. The raise and the shake both write Humanoid.CameraOffset, so a single writer adds them
-- up (see `setHeight` and `setShake`): neither can undo the other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local CameraFx = {}

-- The shapes this module needs, so tests can pass simple stand-ins.
export type CameraLike = {
	CFrame: CFrame,
	Focus: CFrame,
	CameraSubject: Instance?,
	CameraType: Enum.CameraType,
}

export type ConnectionLike = { Disconnect: (self: any) -> () }

export type PlayerLike = {
	Character: Model?,
	CharacterAdded: { Connect: (self: any, callback: (Model) -> ()) -> ConnectionLike },
}

-- The shake's pace: how many times a second it goes left and right, and up and down. Two different numbers, so the
-- shake looks like a rumble and not like a circle.
local SHAKE_SIDEWAYS_HERTZ = 18
local SHAKE_UPDOWN_HERTZ = 23

-- Seconds to wait for the camera to start following a new character, before giving up.
local FOLLOW_TIMEOUT = 5

-- After setting the spawn view, the normal camera may still be starting up and move the view. For this many
-- seconds we check every frame, and set the spawn view again if the view jumped (at most MAX_PLACEMENTS times).
local SETTLE_SECONDS = 2
local MAX_PLACEMENTS = 5

-- Roblox's normal camera looks 15 degrees down at spawn. The spawn view is this plus the tilt up.
local NORMAL_PITCH_DEGREES = -15
-- A view that turns more than this many degrees in one frame was moved by the camera script, not the player.
local JUMP_DEGREES = 15
-- A camera that looks more than this many degrees away from the spawn view has been turned by the player. (Zooming
-- in or out keeps the look the same, so it is not turning.)
local TURNED_DEGREES = 2

-- A bounce look needs at least this much left-right length to point anywhere.
local MIN_FLAT_LOOK = 1e-3
-- Two flat looks (unit vectors) closer than this are the same look: no turn is needed.
local TURN_TOLERANCE = 1e-6

-- The name of the server's downward push on a bounced player (Floater.luau, PART_NAME). While it is on the root, the
-- player is still floating.
local BOUNCE_PUSH_NAME = "BounceFloat"
-- A bounced player is counted as landed after this many seconds even if the landing was not seen.
local LANDING_TIMEOUT = 5

-- A red slam circle under a player on the low bounce camera starts the ease at once (see `circleAt`). It counts as under
-- them when it is within the circle's radius of the root, measured flat, and within a few studs up or down of their feet.
local CIRCLE_REACH = Config.Wake.SlamCircleDiameter / 2
local FEET_BELOW_ROOT = 3 -- a character's feet are this far under the HumanoidRootPart
local CIRCLE_HEIGHT_REACH = 6

-- After a catch (`caught`), the camera waits at most this many seconds for the character to arrive on the spawn spot: the
-- server moves them there and tells the device, and the two can arrive in either order. Used to wait for the spot itself
-- to stream in too (see `whenSpotIsThere`).
CameraFx.caughtWaitSeconds = 2
-- The character counts as on the spawn spot when its root is within this many studs of the spot's top centre, measured
-- flat (X and Z): the server stands them on the top, so a few studs covers the server's rounding and a late position.
local CAUGHT_ARRIVAL_STUDS = 4

-- The names of the render-step bindings that ease the camera back and ease its height back (a binding needs a name that
-- nothing else uses).
local EASE_BINDING_NAME = "CameraFxEaseBack"
local HEIGHT_BINDING_NAME = "CameraFxHeightEase"
-- Render steps run in order of priority. One above Roblox's camera runs right after it, so what we write sticks and
-- the player's input is already in the camera we start from.
local AFTER_CAMERA_PRIORITY = Enum.RenderPriority.Camera.Value + 1

-- The normal camera places itself behind the player on its first frame, then eases its distance out
-- over about a quarter of a second. We only set the spawn view once it has settled, or its first update
-- would undo it.
local STEADY_FRAMES = 3
local STEADY_DISTANCE_CHANGE = 0.05 -- studs the camera may still move in or out between frames
local STEADY_FOCUS_TO_HEAD = 3 -- studs: the camera must be looking at the player's head

-- The view a player gets at spawn: behind the character, looking the way the character faces, at
-- `pitchDegrees` (positive is up), `distance` studs from the point it looks at.
function CameraFx.spawnView(focus: Vector3, characterLook: Vector3, distance: number, pitchDegrees: number): CFrame
	local flatLook = Vector3.new(characterLook.X, 0, characterLook.Z).Unit
	local look = (CFrame.lookAt(Vector3.zero, flatLook) * CFrame.Angles(math.rad(pitchDegrees), 0, 0)).LookVector
	return CFrame.lookAt(focus - look * distance, focus)
end

-- True when the normal camera has settled behind the player: it looks at the head and has stopped
-- zooming. `distance` is the camera's distance from its focus now, `previousDistance` one frame ago.
function CameraFx.isSteady(previousDistance: number, distance: number, focusToHead: number): boolean
	return math.abs(distance - previousDistance) < STEADY_DISTANCE_CHANGE and focusToHead < STEADY_FOCUS_TO_HEAD
end

-- Puts the camera at the spawn view: behind the character, looking the way it faces, at `pitchDegrees`,
-- around the camera's own focus and at the distance it has now.
function CameraFx.placeCamera(camera: CameraLike, characterLook: Vector3, pitchDegrees: number)
	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	camera.CFrame = CameraFx.spawnView(focus, characterLook, distance, pitchDegrees)
end

export type ViewSetter = {
	apply: (camera: CameraLike, characterLook: Vector3, pitchDegrees: number) -> (),
	release: () -> (),
}

-- Makes something that sets the spawn view so it sticks. Setting `Camera.CFrame` alone is not enough: on
-- phones the normal camera script keeps its own left-right direction and puts it back over ours on the next
-- frame. The camera scripts leave the camera alone while `CameraType` is Scriptable, and start again from the
-- camera's CFrame when it goes back to Custom. So `apply` switches to Scriptable, sets the view, lets one frame
-- pass (`waitFrame` waits for it), then switches back to Custom. `release` gives the camera back as Custom at once,
-- for when the work is cancelled in the middle of that frame.
function CameraFx.newViewSetter(waitFrame: () -> ()): ViewSetter
	local heldCamera: CameraLike? = nil

	local function release()
		if heldCamera then
			heldCamera.CameraType = Enum.CameraType.Custom
			heldCamera = nil
		end
	end

	local function apply(camera: CameraLike, characterLook: Vector3, pitchDegrees: number)
		if camera.CameraType ~= Enum.CameraType.Custom then
			-- Someone else controls the camera: set the view and leave its type alone.
			CameraFx.placeCamera(camera, characterLook, pitchDegrees)
			return
		end
		heldCamera = camera
		camera.CameraType = Enum.CameraType.Scriptable
		CameraFx.placeCamera(camera, characterLook, pitchDegrees)
		waitFrame()
		release()
	end

	return { apply = apply, release = release }
end

-- The angle in degrees between two look directions.
local function angleBetween(first: Vector3, second: Vector3): number
	local cosine = math.clamp(first.Unit:Dot(second.Unit), -1, 1)
	return math.deg(math.acos(cosine))
end

-- True when the view turned suddenly between two frames (the two look directions are given). That is
-- the normal camera undoing our view. A player turning the camera moves it a few degrees a frame at most.
function CameraFx.viewJumped(previousLook: Vector3, currentLook: Vector3): boolean
	return angleBetween(previousLook, currentLook) > JUMP_DEGREES
end

-- How far a look points up, in degrees. Negative is down.
function CameraFx.pitchOf(look: Vector3): number
	return math.deg(math.asin(math.clamp(look.Unit.Y, -1, 1)))
end

-- True when the player has turned the camera: it looks more than TURNED_DEGREES away from the spawn view.
function CameraFx.hasTurned(spawnLook: Vector3, currentLook: Vector3): boolean
	return angleBetween(spawnLook, currentLook) > TURNED_DEGREES
end

-- What to do this frame while waiting for the player's first move. A player who turned the camera keeps their own
-- view, even if they are also moving: "stop". Otherwise, the first move starts the ease-back: "ease".
function CameraFx.firstMove(moving: boolean, turned: boolean): "wait" | "ease" | "stop"
	if turned then
		return "stop"
	end
	return if moving then "ease" else "wait"
end

-- An egg this close to dead ahead (in degrees) counts as dead ahead, so it goes to the left and never flickers between
-- the two sides.
local DEAD_AHEAD_DEGREES = 0.01
-- An egg this close to the limit (in degrees) counts as exactly on it, which is far enough off.
local LIMIT_SLACK_DEGREES = 1e-6

-- The flat look to use at the spawn view, so the first egg (where the footprints lead) never hides behind the player. All
-- of it is measured flat (X and Z): `look` is the way the player faces, `from` is where they stand and `egg` is the egg.
--  * An egg that sits `degrees` or more from `look` changes nothing: `look` flattened is returned.
--  * Otherwise the look turns away from the egg just enough that the egg sits exactly `degrees` off, on the side it was
--    already on. An egg dead ahead (within 0.01 degrees) ends up on the left.
--  * An egg at the player's own place has no direction, so it changes nothing.
-- "Left" is how Roblox names it: a look of `CFrame.lookAt(...)` has its RightVector on the right.
-- The result is flat and has length 1.
function CameraFx.awayFromEgg(look: Vector3, from: Vector3, egg: Vector3, degrees: number): Vector3
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local toEgg = Vector3.new(egg.X - from.X, 0, egg.Z - from.Z)
	if toEgg.Magnitude < MIN_FLAT_LOOK then
		return flatLook
	end
	local right = flatLook:Cross(Vector3.yAxis)
	-- Where the egg sits now: degrees to the right of the look (negative is left).
	local eggSide = math.deg(math.atan2(toEgg:Dot(right), toEgg:Dot(flatLook)))
	if math.abs(eggSide) >= degrees - LIMIT_SLACK_DEGREES then
		return flatLook
	end
	-- The side the egg must end on: the one it is on, and the left when it is dead ahead.
	local endSide = if eggSide > DEAD_AHEAD_DEGREES then degrees else -degrees
	-- Turning the look to the right by `turn` degrees moves the egg that much to the left of it.
	local turn = math.rad(eggSide - endSide)
	return flatLook * math.cos(turn) + right * math.sin(turn)
end

-- The camera's CFrame with only the pitch changed to `pitchDegrees` (positive is up). The left-right direction comes
-- from `current` and so does the distance from `focus`, and the result looks at `focus`. Roblox's camera owns the
-- yaw, the distance and the focus (the follow camera on phones turns by itself, the player zooms, and the camera
-- pulls in when something is in the way), so they are read from it on every frame and never remembered.
function CameraFx.withPitch(current: CFrame, focus: Vector3, pitchDegrees: number): CFrame
	local distance = (current.Position - focus).Magnitude
	return CameraFx.spawnView(focus, current.LookVector, distance, pitchDegrees)
end

-- How far the camera's point is moved `seconds` after he woke: left-right and up-down (never forward or back), fading
-- out over Config.Wake.ShakeSeconds. It is exactly zero before 0 and from the end on, and its length is never more
-- than Config.Wake.ShakeStuds (the two waves together can reach the square root of 2, so they are scaled by it).
function CameraFx.shakeOffset(seconds: number): Vector3
	local total = Config.Wake.ShakeSeconds
	if seconds <= 0 or seconds >= total then
		return Vector3.zero
	end
	local scale = Config.Wake.ShakeStuds * (1 - seconds / total) / math.sqrt(2)
	return Vector3.new(
		math.sin(2 * math.pi * SHAKE_SIDEWAYS_HERTZ * seconds),
		math.sin(2 * math.pi * SHAKE_UPDOWN_HERTZ * seconds),
		0
	) * scale
end

export type RunServiceLike = {
	BindToRenderStep: (self: any, name: string, priority: number, callback: (deltaTime: number) -> ()) -> (),
	UnbindFromRenderStep: (self: any, name: string) -> (),
}

-- Makes the function that runs a step every frame, right after Roblox's camera has moved the camera: it binds the step
-- to the render loop under a fixed name (`name`, or the camera ease's own) and gives back a function that unbinds it. Only
-- one step may be bound under a name at a time.
function CameraFx.renderBinder(runService: RunServiceLike, name: string?): (step: () -> ()) -> () -> ()
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
function CameraFx.newEaseBack(
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
		local startPitch = CameraFx.pitchOf(startLook)
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
			camera.CFrame = CameraFx.withPitch(camera.CFrame, camera.Focus.Position, pitch)
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

-- Humanoid.CameraOffset has two writers: the spawn view's raise ("height") and the wake shake ("shake"). Each one only
-- says its own part, and the offset on the Humanoid is always `base + height + shake`, so neither can undo the other: a
-- shake ends on the raise, and the raise's ease ends on 0 with no wiggle left. `base` is whatever offset the Humanoid had
-- before either of them touched it (0 in the game). Nothing is kept for a Humanoid once both parts are 0.
type OffsetParts = { base: Vector3, height: Vector3, shake: Vector3 }
local offsetParts: { [Humanoid]: OffsetParts } = setmetatable({}, { __mode = "k" }) :: any

local function partsOf(humanoid: Humanoid): OffsetParts
	local found = offsetParts[humanoid]
	if found ~= nil then
		return found
	end
	local made: OffsetParts = { base = humanoid.CameraOffset, height = Vector3.zero, shake = Vector3.zero }
	offsetParts[humanoid] = made
	return made
end

local function writeOffset(humanoid: Humanoid, parts: OffsetParts)
	humanoid.CameraOffset = parts.base + parts.height + parts.shake
	if parts.height == Vector3.zero and parts.shake == Vector3.zero then
		offsetParts[humanoid] = nil
	end
end

-- Sets the raise part of the offset (straight up), keeping the shake part.
local function setHeight(humanoid: Humanoid, height: Vector3)
	local parts = partsOf(humanoid)
	parts.height = height
	writeOffset(humanoid, parts)
end

-- Sets the shake part of the offset, keeping the raise part.
local function setShake(humanoid: Humanoid, shake: Vector3)
	local parts = partsOf(humanoid)
	parts.shake = shake
	writeOffset(humanoid, parts)
end

local function heightOf(humanoid: Humanoid): Vector3
	local parts = offsetParts[humanoid]
	return if parts ~= nil then parts.height else Vector3.zero
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
function CameraFx.newHeightEase(bindAfterCamera: (step: () -> ()) -> () -> (), now: () -> number): HeightEase
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
function CameraFx.rotationInput(
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
function CameraFx.shouldReplace(inSettleWindow: boolean, placements: number, jumped: boolean, turning: boolean): boolean
	return inSettleWindow and placements < MAX_PLACEMENTS and jumped and not turning
end

-- True when `look` can be used as a bounce look: a Vector3 with finite parts that points somewhere left-right (a look
-- straight up or down, or a zero one, has no direction to put the camera behind).
local function isUsableLook(look: unknown): boolean
	if typeof(look) ~= "Vector3" then
		return false
	end
	local vector = look :: Vector3
	for _, part in { vector.X, vector.Y, vector.Z } do
		if part - part ~= 0 then -- NaN and infinity both give NaN here
			return false
		end
	end
	return Vector2.new(vector.X, vector.Z).Magnitude >= MIN_FLAT_LOOK
end

-- True when `point` is a Vector3 with finite parts.
local function isUsablePoint(point: unknown): boolean
	if typeof(point) ~= "Vector3" then
		return false
	end
	local vector = point :: Vector3
	for _, part in { vector.X, vector.Y, vector.Z } do
		if part - part ~= 0 then -- NaN and infinity both give NaN here
			return false
		end
	end
	return true
end

-- The top centre of a spawn spot: its middle, half its height up.
local function topOfSpot(spot: BasePart): Vector3
	return spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
end

-- Calls `onFound` with the top centre of the spot `find()` gives, as soon as the spot is there: at once, or when it
-- streams in, waiting a frame at a time for at most CameraFx.caughtWaitSeconds. After that it gives up and calls nothing.
-- Gives back a function that cancels the wait (safe to call at any time, and twice). `waitFrame` and `now` stand in for the
-- render step and `os.clock` in tests.
function CameraFx.whenSpotIsThere(
	find: () -> BasePart?,
	onFound: (top: Vector3) -> (),
	waitFrame: (() -> ())?,
	now: (() -> number)?
): () -> ()
	local clock = now or os.clock
	local frameWait = waitFrame or function()
		RunService.RenderStepped:Wait()
	end
	local thread: thread? = nil
	local finished = false
	local deadline = clock() + CameraFx.caughtWaitSeconds
	local started = task.spawn(function()
		while true do
			local spot = find()
			if spot ~= nil then
				finished = true
				onFound(topOfSpot(spot))
				return
			end
			if clock() >= deadline then
				finished = true
				return
			end
			frameWait()
		end
	end)
	if not finished then
		thread = started
	end
	return function()
		local running = thread
		thread = nil
		if running ~= nil and coroutine.status(running) ~= "dead" then
			task.cancel(running)
		end
	end
end

export type WatchParts = {
	-- Runs a step every frame after Roblox's camera (default: `renderBinder(RunService)`).
	bindAfterCamera: ((step: () -> ()) -> () -> ())?,
	-- Where to look for Roblox's camera input (default: StarterPlayer and the player's PlayerScripts).
	containers: { Instance? }?,
	-- Reads the camera input's state (default: `action:GetState()`).
	readState: ((action: InputAction) -> unknown)?,
	-- Reads the Humanoid's MoveDirection (default: `humanoid.MoveDirection`).
	moveDirection: ((humanoid: Humanoid) -> Vector3)?,
	-- Reads the Humanoid's FloorMaterial (default: `humanoid.FloorMaterial`).
	floorMaterial: ((humanoid: Humanoid) -> Enum.Material)?,
	-- Where the egg the footprints lead to is, or nil when they lead to none (default: no finder, so nobody is ever turned).
	firstEgg: (() -> Vector3?)?,
	-- Turns the character about the vertical to face `look`, keeping its root where it is (default: `PivotTo`).
	turnCharacter: ((character: Model, look: Vector3) -> ())?,
	-- Runs a step every frame for the raise's ease (default: `renderBinder(RunService, "CameraFxHeightEase")`).
	bindHeight: ((step: () -> ()) -> () -> ())?,
}

-- What the footprint trail is told after a bounce: "hide" when the bounce is accepted, "fadeIn" at the first move after
-- landing, and "show" (at once, no fade) when the character is replaced while the trail is hidden.
export type TrailChange = "hide" | "fadeIn" | "show"

export type Watcher = {
	stop: () -> (),
	-- Snaps the camera behind the character along `look`, for a player who was just bounced off the giant.
	bounce: (look: Vector3) -> (),
	-- Tells `listener` what the footprint trail should do (see TrailChange). A listener added while the trail is hidden
	-- is told "hide" at once. Gives back a function that removes the listener.
	onTrail: (listener: (change: TrailChange) -> ()) -> () -> (),
	-- A red slam circle has appeared at `point`. See the long comment on `watch`.
	circleAt: (point: Vector3) -> (),
	-- The player was caught and sent home to the spawn spot whose top centre is `spot`. See the long comment on `watch`.
	caught: (spot: Vector3) -> (),
}

-- On every character the player gets (and the one they already have), waits until the camera follows
-- it, lets the normal camera settle behind it, then sets the spawn view. Then it watches for the first thing the
-- player does, once per frame, until one of these happens (and then stops watching for good):
--  * they turn the camera: they keep their own view;
--  * they move without having turned it: the camera eases back to Roblox's normal view over `easeBackSeconds`
--    (the ease then runs on its own, bound to the render loop);
--  * the character changes, or `stop` is called.
-- The spawn view is never set while the player is turning the camera, so a turn is never dropped or undone.
--
-- The first egg (spec Rule 1, "Spawn facing the giant"): right before the spawn view is placed (and after a catch, the same),
-- `parts.firstEgg` says where the egg the footprints lead to is. If it sits less than Config.Spawn.EggOffFacingDegrees from
-- the way the root faces, the character is turned (`parts.turnCharacter`) as `awayFromEgg` says, and the view is placed along
-- the new look. No egg, no finder, or a player who is already turning the camera: no turn. A bounce never turns anyone.
-- The raise: while the spawn view (spawn or catch) is placed, Humanoid.CameraOffset is Config.Spawn.CameraRaiseStuds up. It
-- eases back to 0 over `easeBackSeconds` from the first move or the first camera turn, whichever comes first. A camera turn
-- stops the tilt's ease, but never this one. Whatever cancels the spawn view (a bounce, a catch, a new character, `stop`)
-- puts the raise straight back to 0, and a catch raises it again at the spot.
--
-- `bounce(look)` is the same thing for a player the server just bounced off the giant (spec Rule 12): the server tells
-- the device which way the player now faces, `look`. Whatever the watcher was doing is cancelled. The camera is placed
-- behind the character along `look`, Config.Wake.BounceCameraUpDegrees up, and kept there. It waits for the landing
-- (moves during the float do not count), and then the first move without a camera turn eases back like at spawn.
-- A `look` that is not a finite Vector3 with a left-right part is ignored.
--
-- The footprint trail (spec Rule 2): a bounce that is accepted tells the `onTrail` listeners "hide". Then a wait of its
-- own, not the camera's job (it goes on when the camera's wait stops because the player turned the camera), tells them
-- "fadeIn" on the first move after the landing, and ends. A new bounce restarts it, and a new character or `stop` ends
-- it (a new character, while the trail is hidden, tells them "show").
--
-- `circleAt(point)` (spec Rule 12, "Waking bounces everyone off"): a red slam circle has just appeared at `point`. From the
-- low bounce camera the circle cannot be seen, so a player who has landed and has not moved or turned the camera yet
-- gets the same ease as at the first move, at once, if the point is under them (see CIRCLE_REACH). The camera's wait for
-- the first move ends then (no second ease later); the footprint trail's wait goes on. Anywhere else it does nothing.
--
-- `caught(spot)` (spec Rule 13, "Hand slams hunt egg carriers", and the "Caught" row of section 6): the player was caught
-- and the server is putting them on their own spawn spot, whose top centre is `spot`, turned to face him. It is the spawn
-- view again. Whatever the watcher was doing is cancelled, like `bounce` does: a spawn wait, a bounce wait (so a later
-- `circleAt` does nothing, and no second ease ever runs) or a running ease. The footprint trail is left alone: its own wait
-- goes on. Then it waits, a frame at a time and for at most CameraFx.caughtWaitSeconds, until the character's root is on the
-- spot (the remote and the move can arrive in either order). If it never arrives, nothing more happens and Roblox's camera
-- stays. When it arrives, the camera is placed behind the root's look at the spawn tilt, at the player's own zoom distance,
-- held through the settle window, never placed while they turn the camera, and the first move without a turn eases it back
-- to 15 degrees down: exactly `showView` as at spawn. A `spot` that is not a finite Vector3 is ignored.
--
-- `parts` replaces the real pieces in tests. Returns the watcher.
function CameraFx.watch(
	player: PlayerLike,
	getCamera: () -> CameraLike?,
	degreesUp: number,
	easeBackSeconds: number,
	waitFrame: (() -> ())?,
	now: (() -> number)?,
	parts: WatchParts?
): Watcher
	local currentThread: thread? = nil
	local stopped = false
	local frameWait = waitFrame or function()
		RunService.RenderStepped:Wait()
	end
	local clock = now or os.clock
	local realParts: WatchParts = parts or {}
	local function ownMoveDirection(humanoid: Humanoid): Vector3
		return humanoid.MoveDirection
	end
	local function ownFloorMaterial(humanoid: Humanoid): Enum.Material
		return humanoid.FloorMaterial
	end
	local readMoveDirection: (Humanoid) -> Vector3 = realParts.moveDirection or ownMoveDirection
	local readFloorMaterial: (Humanoid) -> Enum.Material = realParts.floorMaterial or ownFloorMaterial
	local setter = CameraFx.newViewSetter(frameWait)
	local function ownTurn(character: Model, look: Vector3)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return
		end
		-- The whole character turns about the root's place (the way the server's Catcher does it), so whatever hangs on the
		-- character, like a carried egg, keeps its place.
		local target = CFrame.lookAt(root.Position, root.Position + look)
		character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
	end
	local turnCharacter: (Model, Vector3) -> () = realParts.turnCharacter or ownTurn
	-- The turn signal of the current character. The ease asks whichever one is current.
	local activeTurning: () -> boolean = function()
		return false
	end
	local easer = CameraFx.newEaseBack(realParts.bindAfterCamera or CameraFx.renderBinder(RunService), clock, function()
		return activeTurning()
	end)
	-- The raise of the camera: the ease that takes it back to 0, and the Humanoid that carries it now (if any).
	local heightEaser =
		CameraFx.newHeightEase(realParts.bindHeight or CameraFx.renderBinder(RunService, HEIGHT_BINDING_NAME), clock)
	local raisedHumanoid: Humanoid? = nil

	-- The footprint trail: who listens, whether it is hidden now, and the thread that waits for the first move after
	-- landing (one at a time).
	local trailListeners: { { call: (change: TrailChange) -> () } } = {}
	local trailHidden = false
	local trailThread: thread? = nil

	-- The camera's wait for the first move after a bounce, while it runs (nil otherwise, also at spawn): what `circleAt`
	-- needs to know, and a flag that ends the wait.
	local bounceWait: {
		camera: CameraLike,
		humanoid: Humanoid,
		root: BasePart,
		isTurning: () -> boolean,
		hasLanded: () -> boolean,
		viewLook: () -> Vector3,
		circleStarted: boolean,
	}? =
		nil

	local function tellTrail(change: TrailChange)
		for _, entry in table.clone(trailListeners) do
			entry.call(change)
		end
	end

	local function cancelTrailWait()
		if trailThread then
			task.cancel(trailThread)
			trailThread = nil
		end
	end

	-- Puts the raise straight back to 0 and ends its ease.
	local function dropHeight()
		heightEaser.cancel()
		local humanoid = raisedHumanoid
		raisedHumanoid = nil
		if humanoid ~= nil then
			setHeight(humanoid, Vector3.zero)
		end
	end

	local function cancelCurrent()
		if currentThread then
			task.cancel(currentThread)
			currentThread = nil
		end
		setter.release()
		easer.cancel()
		dropHeight()
		bounceWait = nil
	end

	-- Runs `job` as the watcher's one piece of work. It is the thread `cancelCurrent` cancels, until it ends.
	local function startJob(job: () -> ())
		local thread = task.spawn(function()
			job()
			if currentThread == coroutine.running() then
				currentThread = nil
			end
		end)
		if coroutine.status(thread) ~= "dead" then
			currentThread = thread
		end
	end

	-- The real turn signal (looked up now, once for this job). If it can't be found, a turn is a look that is not the
	-- one the ease wrote last.
	local function startTurnSignal(camera: CameraLike): () -> boolean
		local isTurning = CameraFx.rotationInput(
			realParts.containers
				or { StarterPlayer, Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts") },
			function()
				local written = easer.lastLook()
				return written ~= nil and angleBetween(written, camera.CFrame.LookVector) > TURNED_DEGREES
			end,
			nil,
			realParts.readState
		)
		activeTurning = isTurning
		return isTurning
	end

	-- The spawn and the bounce share these steps. Places the camera at `pitchDegrees` along `getLook()`, checks that it
	-- held (for a short while, a jump of the view is undone), then waits for the player's first move once
	-- `hasLanded()` is true, and eases the camera back to Roblox's normal view. A player who is turning the camera, or
	-- who turns it at any time before the first move, keeps their own view and nothing more happens.
	local function showView(
		camera: CameraLike,
		humanoid: Humanoid,
		isTurning: () -> boolean,
		getLook: () -> Vector3,
		pitchDegrees: number,
		hasLanded: () -> boolean,
		bounceRoot: BasePart?
	)
		-- A player who is already turning the camera keeps their own view: it is not placed, and we stop watching.
		if isTurning() then
			return
		end
		-- The spawn view (spawn and catch, not the bounce) also raises the camera while it is placed.
		local isSpawnView = bounceRoot == nil
		if isSpawnView then
			raisedHumanoid = humanoid
			setHeight(humanoid, Vector3.new(0, Config.Spawn.CameraRaiseStuds, 0))
		end
		setter.apply(camera, getLook(), pitchDegrees)
		local placements = 1
		-- The view we set last: the player has turned the camera when it looks away from this.
		local viewLook = camera.CFrame.LookVector
		local previousLook = viewLook
		local settleEnd = clock() + SETTLE_SECONDS
		-- After a bounce, `circleAt` can start the ease; it also ends this wait (the loop sees the flag).
		local waiting = if bounceRoot ~= nil
			then {
				camera = camera,
				humanoid = humanoid,
				root = bounceRoot,
				isTurning = isTurning,
				hasLanded = hasLanded,
				viewLook = function(): Vector3
					return viewLook
				end,
				circleStarted = false,
			}
			else nil
		bounceWait = waiting
		while true do
			frameWait()
			if waiting ~= nil and waiting.circleStarted then
				break
			end
			local turning = isTurning()
			local look = camera.CFrame.LookVector
			if
				CameraFx.shouldReplace(
					clock() < settleEnd,
					placements,
					CameraFx.viewJumped(previousLook, look),
					turning
				)
			then
				-- The camera script moved the view in one frame: set ours again.
				setter.apply(camera, getLook(), pitchDegrees)
				placements += 1
				look = camera.CFrame.LookVector
				viewLook = look
			end
			previousLook = look
			local decision = CameraFx.firstMove(
				hasLanded() and readMoveDirection(humanoid).Magnitude > 0,
				CameraFx.hasTurned(viewLook, look) or turning
			)
			if decision == "ease" then
				easer.run(camera, easeBackSeconds, NORMAL_PITCH_DEGREES)
			end
			if decision ~= "wait" then
				-- The first move or the first camera turn, whichever comes first, takes the raise back too.
				if isSpawnView then
					heightEaser.run(humanoid, easeBackSeconds)
				end
				break
			end
		end
		if bounceWait == waiting then
			bounceWait = nil
		end
	end

	-- Says when a bounced player has landed: they have been seen floating (the server's push on the root, or in the
	-- air), and now both are over. Without the first part, the state from before the float (standing on the giant)
	-- would count as a landing. After LANDING_TIMEOUT seconds it says yes anyway, so a player never waits for ever.
	local function newLandingCheck(humanoid: Humanoid, root: BasePart): () -> boolean
		local startedAt = clock()
		local sawFloat = false
		-- True while the player is floating: the server's push is on the root, or they are in the air.
		local function floating(): boolean
			for _, child in root:GetChildren() do
				if child.Name == BOUNCE_PUSH_NAME and child:IsA("LinearVelocity") then
					return true
				end
			end
			return readFloorMaterial(humanoid) == Enum.Material.Air
		end
		sawFloat = floating() -- the push usually reaches the device before the remote does
		return function(): boolean
			local isFloating = floating()
			if isFloating then
				sawFloat = true
			end
			if clock() - startedAt >= LANDING_TIMEOUT then
				return true
			end
			return sawFloat and not isFloating
		end
	end

	-- Hides the trail and waits, one frame at a time, for the first move after landing (same landing rules as the
	-- camera's), then tells the listeners to fade it in. Whatever it was waiting for before is cancelled.
	local function hideTrailUntilFirstMove(humanoid: Humanoid, root: BasePart)
		cancelTrailWait()
		trailHidden = true
		tellTrail("hide")
		local hasLanded = newLandingCheck(humanoid, root)
		local thread = task.spawn(function()
			repeat
				frameWait()
			until hasLanded() and readMoveDirection(humanoid).Magnitude > 0
			if trailThread == coroutine.running() then
				trailThread = nil
			end
			trailHidden = false
			tellTrail("fadeIn")
		end)
		if coroutine.status(thread) ~= "dead" then
			trailThread = thread
		end
	end

	-- Right before the spawn view is placed: if the first egg would sit less than Config.Spawn.EggOffFacingDegrees from the way
	-- the root faces, turns the character until it sits that far off (see `awayFromEgg`). Nothing happens without a finder, without
	-- an egg, or for a player who is already turning the camera (their view is not placed either).
	local function turnAwayFromFirstEgg(character: Model, root: BasePart, isTurning: () -> boolean)
		local findEgg = realParts.firstEgg
		if findEgg == nil then
			return
		end
		local egg = findEgg()
		if egg == nil or not isUsablePoint(egg) or isTurning() then
			return
		end
		local look = root.CFrame.LookVector
		if not isUsableLook(look) then
			return
		end
		local flatLook = Vector3.new(look.X, 0, look.Z).Unit
		local turnedLook = CameraFx.awayFromEgg(look, root.Position, egg, Config.Spawn.EggOffFacingDegrees)
		if (turnedLook - flatLook).Magnitude > TURN_TOLERANCE then
			turnCharacter(character, turnedLook)
		end
	end

	local function onCharacter(character: Model)
		cancelCurrent()
		if trailHidden then
			cancelTrailWait()
			trailHidden = false
			tellTrail("show")
		end
		startJob(function()
			local humanoid = character:WaitForChild("Humanoid", FOLLOW_TIMEOUT)
			local deadline = os.clock() + FOLLOW_TIMEOUT
			local camera = getCamera()
			while camera and humanoid and camera.CameraSubject ~= humanoid and os.clock() < deadline do
				task.wait()
				camera = getCamera()
			end
			if camera == nil or humanoid == nil or camera.CameraSubject ~= humanoid then
				return
			end
			-- Wait until the normal camera has placed itself behind the player and stopped zooming.
			local steadyFrames = 0
			local previousDistance = -1
			local steadyDeadline = os.clock() + FOLLOW_TIMEOUT
			while steadyFrames < STEADY_FRAMES and os.clock() < steadyDeadline do
				task.wait()
				local head = character:FindFirstChild("Head")
				local focusToHead = if head and head:IsA("BasePart")
					then (head.Position - camera.Focus.Position).Magnitude
					else math.huge
				local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
				steadyFrames = if CameraFx.isSteady(previousDistance, distance, focusToHead)
					then steadyFrames + 1
					else 0
				previousDistance = distance
			end
			local isTurning = startTurnSignal(camera)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") or not humanoid:IsA("Humanoid") then
				return
			end
			local rootPart = root
			local function rootLook(): Vector3
				return rootPart.CFrame.LookVector
			end
			-- Nothing to wait for at spawn: the first move counts at once.
			local function alwaysLanded(): boolean
				return true
			end
			turnAwayFromFirstEgg(character, rootPart, isTurning)
			showView(camera, humanoid, isTurning, rootLook, NORMAL_PITCH_DEGREES + degreesUp, alwaysLanded, nil)
		end)
	end

	local function onBounce(look: Vector3)
		if stopped or not isUsableLook(look) then
			return
		end
		local character = player.Character
		local camera = getCamera()
		if character == nil or camera == nil then
			return
		end
		local humanoid = character:FindFirstChild("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if
			humanoid == nil
			or not humanoid:IsA("Humanoid")
			or root == nil
			or not root:IsA("BasePart")
			or camera.CameraSubject ~= humanoid
		then
			return
		end
		cancelCurrent()
		hideTrailUntilFirstMove(humanoid, root)
		local function bounceLook(): Vector3
			return look
		end
		startJob(function()
			local isTurning = startTurnSignal(camera)
			showView(
				camera,
				humanoid,
				isTurning,
				bounceLook,
				Config.Wake.BounceCameraUpDegrees,
				newLandingCheck(humanoid, root),
				root
			)
		end)
	end

	local function onCircle(point: Vector3)
		local waiting = bounceWait
		if stopped or waiting == nil or not isUsablePoint(point) then
			return
		end
		local rootPosition = waiting.root.Position
		local flatDistance = Vector2.new(point.X - rootPosition.X, point.Z - rootPosition.Z).Magnitude
		local feet = rootPosition.Y - FEET_BELOW_ROOT
		if flatDistance > CIRCLE_REACH or math.abs(point.Y - feet) > CIRCLE_HEIGHT_REACH then
			return
		end
		-- Only a player who has landed, and has neither moved nor turned the camera yet (the wait loop is still running).
		if not waiting.hasLanded() or readMoveDirection(waiting.humanoid).Magnitude > 0 then
			return
		end
		if waiting.isTurning() or CameraFx.hasTurned(waiting.viewLook(), waiting.camera.CFrame.LookVector) then
			return
		end
		waiting.circleStarted = true
		bounceWait = nil
		easer.run(waiting.camera, easeBackSeconds, NORMAL_PITCH_DEGREES)
	end

	local function onCaught(spot: Vector3)
		if stopped or not isUsablePoint(spot) then
			return
		end
		local character = player.Character
		local camera = getCamera()
		if character == nil or camera == nil then
			return
		end
		local humanoid = character:FindFirstChild("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if
			humanoid == nil
			or not humanoid:IsA("Humanoid")
			or root == nil
			or not root:IsA("BasePart")
			or camera.CameraSubject ~= humanoid
		then
			return
		end
		cancelCurrent()
		-- A second job at a time: this replaces the bounce's or the spawn's. The trail's own wait is not touched.
		local rootPart = root
		local function rootLook(): Vector3
			return rootPart.CFrame.LookVector
		end
		-- Nothing to wait for after the move: the first move counts at once.
		local function alwaysLanded(): boolean
			return true
		end
		startJob(function()
			local isTurning = startTurnSignal(camera)
			local deadline = clock() + CameraFx.caughtWaitSeconds
			while true do
				local position = rootPart.Position
				if Vector2.new(position.X - spot.X, position.Z - spot.Z).Magnitude <= CAUGHT_ARRIVAL_STUDS then
					break
				end
				if clock() >= deadline then
					return
				end
				frameWait()
			end
			turnAwayFromFirstEgg(character, rootPart, isTurning)
			showView(camera, humanoid, isTurning, rootLook, NORMAL_PITCH_DEGREES + degreesUp, alwaysLanded, nil)
		end)
	end

	local connection = player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	return {
		stop = function()
			stopped = true
			connection:Disconnect()
			cancelCurrent()
			cancelTrailWait()
			trailHidden = false
			table.clear(trailListeners)
		end,
		bounce = onBounce,
		circleAt = onCircle,
		caught = onCaught,
		onTrail = function(listener: (change: TrailChange) -> ()): () -> ()
			if stopped then
				return function() end
			end
			local entry = { call = listener }
			table.insert(trailListeners, entry)
			if trailHidden then
				listener("hide")
			end
			return function()
				local at = table.find(trailListeners, entry)
				if at then
					table.remove(trailListeners, at)
				end
			end
		end,
	}
end

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
function CameraFx.shakeOnWake(deps: ShakeDeps): Shaker
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
			setShake(humanoid, CameraFx.shakeOffset(seconds))
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

return CameraFx
