--!strict
-- The spawn view and the small pure helpers about where the camera looks (spawn view, steady check, turn checks, shake offset, spawn spot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Shared = require(script.Parent.Shared)

type CameraLike = Shared.CameraLike
local MIN_FLAT_LOOK = Shared.MIN_FLAT_LOOK
local TURNED_DEGREES = Shared.TURNED_DEGREES
local angleBetween = Shared.angleBetween

local View = {}

-- The shake's pace: how many times a second it goes left and right, and up and down. Two different numbers, so the
-- shake looks like a rumble and not like a circle.
local SHAKE_SIDEWAYS_HERTZ = 18
local SHAKE_UPDOWN_HERTZ = 23

-- A view that turns more than this many degrees in one frame was moved by the camera script, not the player.
local JUMP_DEGREES = 15

-- The normal camera places itself behind the player on its first frame, then eases its distance out
-- over about a quarter of a second. We only set the spawn view once it has settled, or its first update
-- would undo it.
local STEADY_DISTANCE_CHANGE = 0.05 -- studs the camera may still move in or out between frames
local STEADY_FOCUS_TO_HEAD = 3 -- studs: the camera must be looking at the player's head

-- The view a player gets at spawn: behind the character, looking the way the character faces, at
-- `pitchDegrees` (positive is up), `distance` studs from the point it looks at.
function View.spawnView(focus: Vector3, characterLook: Vector3, distance: number, pitchDegrees: number): CFrame
	local flatLook = Vector3.new(characterLook.X, 0, characterLook.Z).Unit
	local look = (CFrame.lookAt(Vector3.zero, flatLook) * CFrame.Angles(math.rad(pitchDegrees), 0, 0)).LookVector
	return CFrame.lookAt(focus - look * distance, focus)
end

-- True when the normal camera has settled behind the player: it looks at the head and has stopped
-- zooming. `distance` is the camera's distance from its focus now, `previousDistance` one frame ago.
function View.isSteady(previousDistance: number, distance: number, focusToHead: number): boolean
	return math.abs(distance - previousDistance) < STEADY_DISTANCE_CHANGE and focusToHead < STEADY_FOCUS_TO_HEAD
end

-- Puts the camera at the spawn view: behind the character, looking the way it faces, at `pitchDegrees`,
-- around the camera's own focus and at the distance it has now.
function View.placeCamera(camera: CameraLike, characterLook: Vector3, pitchDegrees: number)
	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	camera.CFrame = View.spawnView(focus, characterLook, distance, pitchDegrees)
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
function View.newViewSetter(waitFrame: () -> ()): ViewSetter
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
			View.placeCamera(camera, characterLook, pitchDegrees)
			return
		end
		heldCamera = camera
		camera.CameraType = Enum.CameraType.Scriptable
		View.placeCamera(camera, characterLook, pitchDegrees)
		waitFrame()
		release()
	end

	return { apply = apply, release = release }
end

-- True when the view turned suddenly between two frames (the two look directions are given). That is
-- the normal camera undoing our view. A player turning the camera moves it a few degrees a frame at most.
function View.viewJumped(previousLook: Vector3, currentLook: Vector3): boolean
	return angleBetween(previousLook, currentLook) > JUMP_DEGREES
end

-- How far a look points up, in degrees. Negative is down.
function View.pitchOf(look: Vector3): number
	return math.deg(math.asin(math.clamp(look.Unit.Y, -1, 1)))
end

-- True when the player has turned the camera: it looks more than TURNED_DEGREES away from the spawn view.
function View.hasTurned(spawnLook: Vector3, currentLook: Vector3): boolean
	return angleBetween(spawnLook, currentLook) > TURNED_DEGREES
end

-- What to do this frame while waiting for the player's first move. A player who turned the camera keeps their own
-- view, even if they are also moving: "stop". Otherwise, the first move starts the ease-back: "ease".
function View.firstMove(moving: boolean, turned: boolean): "wait" | "ease" | "stop"
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
function View.awayFromEgg(look: Vector3, from: Vector3, egg: Vector3, degrees: number): Vector3
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
function View.withPitch(current: CFrame, focus: Vector3, pitchDegrees: number): CFrame
	local distance = (current.Position - focus).Magnitude
	return View.spawnView(focus, current.LookVector, distance, pitchDegrees)
end

-- How far the camera's point is moved `seconds` after he woke: left-right and up-down (never forward or back), fading
-- out over Config.Wake.ShakeSeconds. It is exactly zero before 0 and from the end on, and its length is never more
-- than Config.Wake.ShakeStuds (the two waves together can reach the square root of 2, so they are scaled by it).
function View.shakeOffset(seconds: number): Vector3
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

-- The top centre of a spawn spot: its middle, half its height up.
local function topOfSpot(spot: BasePart): Vector3
	return spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
end

-- Calls `onFound` with the top centre of the spot `find()` gives, as soon as the spot is there: at once, or when it
-- streams in, waiting a frame at a time for at most CameraFx.caughtWaitSeconds. After that it gives up and calls nothing.
-- Gives back a function that cancels the wait (safe to call at any time, and twice). `waitFrame` and `now` stand in for the
-- render step and `os.clock` in tests.
function View.whenSpotIsThere(
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
	local deadline = clock() + Shared.caughtWaitSeconds
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

return View
