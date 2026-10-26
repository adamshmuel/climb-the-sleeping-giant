--!strict
-- The spawn watch: sets the view at every spawn, puts it back if the camera script moves it, starts the eases and handles bounce and catch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)

local Shared = require(script.Parent.Shared)
local WatchTypes = require(script.Parent.WatchTypes)
local Ease = require(script.Parent.Ease)
local View = require(script.Parent.View)

type CameraLike = Shared.CameraLike
type PlayerLike = Shared.PlayerLike
local TURNED_DEGREES = Shared.TURNED_DEGREES
local angleBetween = Shared.angleBetween
local isUsableLook = Shared.isUsableLook
local isUsablePoint = Shared.isUsablePoint
local setHeight = Shared.setHeight
type WatchParts = WatchTypes.WatchParts
type TrailChange = WatchTypes.TrailChange
type Watcher = WatchTypes.Watcher

local Watch = {}

-- Seconds to wait for the camera to start following a new character, before giving up.
local FOLLOW_TIMEOUT = 5

-- After setting the spawn view, the normal camera may still be starting up and move the view. For this many
-- seconds we check every frame, and set the spawn view again if the view jumped (at most MAX_PLACEMENTS times).
local SETTLE_SECONDS = 2

-- Roblox's normal camera looks 15 degrees down at spawn. The spawn view is this plus the tilt up.
local NORMAL_PITCH_DEGREES = -15

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

-- The character counts as on the spawn spot when its root is within this many studs of the spot's top centre, measured
-- flat (X and Z): the server stands them on the top, so a few studs covers the server's rounding and a late position.
local CAUGHT_ARRIVAL_STUDS = 4

-- The name of the render-step binding that eases the camera's height back.
local HEIGHT_BINDING_NAME = "CameraFxHeightEase"

-- The normal camera places itself behind the player on its first frame, then eases its distance out
-- over about a quarter of a second. We only set the spawn view once it has settled, or its first update
-- would undo it.
local STEADY_FRAMES = 3

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
function Watch.watch(
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
	local setter = View.newViewSetter(frameWait)
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
	local easer = Ease.newEaseBack(realParts.bindAfterCamera or Ease.renderBinder(RunService), clock, function()
		return activeTurning()
	end)
	-- The raise of the camera: the ease that takes it back to 0, and the Humanoid that carries it now (if any).
	local heightEaser =
		Ease.newHeightEase(realParts.bindHeight or Ease.renderBinder(RunService, HEIGHT_BINDING_NAME), clock)
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
		local isTurning = Ease.rotationInput(
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
			if Ease.shouldReplace(clock() < settleEnd, placements, View.viewJumped(previousLook, look), turning) then
				-- The camera script moved the view in one frame: set ours again.
				setter.apply(camera, getLook(), pitchDegrees)
				placements += 1
				look = camera.CFrame.LookVector
				viewLook = look
			end
			previousLook = look
			local decision = View.firstMove(
				hasLanded() and readMoveDirection(humanoid).Magnitude > 0,
				View.hasTurned(viewLook, look) or turning
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
		local turnedLook = View.awayFromEgg(look, root.Position, egg, Config.Spawn.EggOffFacingDegrees)
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
				steadyFrames = if View.isSteady(previousDistance, distance, focusToHead) then steadyFrames + 1 else 0
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
		if waiting.isTurning() or View.hasTurned(waiting.viewLook(), waiting.camera.CFrame.LookVector) then
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
			local deadline = clock() + Shared.caughtWaitSeconds
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

return Watch
