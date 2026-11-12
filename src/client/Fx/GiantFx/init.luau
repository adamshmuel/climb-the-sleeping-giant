--!strict
-- The warnings on the giant himself (spec Rule 10, "He warns before he wakes", and the "60% warning" and "85% warning"
-- rows of section 6). The server fires Warning with 60 or 85 when the meter rises past that mark. Then, on each
-- player's own device, this module moves its own copy of the giant. The server never moves him.
--   * 60: his eyelids flutter twice (each lid lifts and a white slice of eye shows), and the floating Z Z Z hold still
--     and fade to half for 2 seconds.
--   * 85: the Z Z Z and the snore puffs stop, a bubble beside his nose (World.GiantFX.SnoreEmitter.Warning85Bubble)
--     says "Mmm... my eggs..." for 3 seconds and fades out over 0.3 more, and he snorts twice from his nose: a burst of
--     20 puffs, and another 0.5 seconds later. Nothing he sleeps on moves (spec Rule 100, "Nothing you stand on moves
--     while he sleeps"), so his arm stays still. The Z Z Z and puffs come back when the meter falls to 75 (and he is
--     asleep), or when he goes into Heavy Sleep.
--     The bubble has a fixed size on the screen (Bubble85 holds the maths: the sizes, the side, the pop and the fade).
--     Each frame while it shows, this module sets its size from isPhone, its side from the camera's RightVector.Z, and
--     its pop and fade from the time. All three inputs are read each time, never once at the start.
-- A free save (spec Rule 17, "A free save replays the 85% warning") fires Warning with (85, Net.FreeSaveKind). The 85
-- plan plays again from the start (the snort too: a burst now, and the second 0.5 seconds after this one), and the Z Z Z
-- and puffs stay off until Config.Meter.FreeSaveWarningSeconds have
-- passed. Then, if the meter is at 75 or less, they come back and the letters fade in over 0.2 seconds, like the way
-- back of the 60 fade. Otherwise they wait for the meter to fall to 75, as after a plain 85. Any other second value
-- is ignored, like a wrong mark.
-- The Tiptoe button's glow and the tip "Stand still or tiptoe!" belong to TiptoeButton and Messages. warningPlan
-- lists them anyway, so the whole warning is in one place.
-- The waking pose (spec Rule 12, "Waking bounces everyone off"): when GiantState's Phase turns Awake, the warnings stop
-- at once, his eyes swap (the sleeping eyes hide, the awake eyes show), and over 0.5 seconds his head tips forward
-- (head, nightcap, lids and awake eyes together) and his right fist goes up. The bubble, the Z Z Z and the
-- puffs are off for as long as he is awake. When Phase leaves Awake the eyes swap back at once and the head and the
-- arm go back over 0.5 seconds. A player who joins while he is awake sees the full pose at once.
-- The slam swing (spec section 6, "Awake" row): each SlamWarning makes his right arm swing toward the target over 0.5
-- seconds, hold there while the fist falls and lands, and swing back to the raised pose over 0.5 seconds, ending 0.1
-- seconds before the next warning. It is counted from when the warning arrived on this device. A warning that arrives
-- while he isn't awake does nothing, and the swing is scaled by the waking pose, so going back to sleep takes it back.
-- The arm never goes inside his body: when the warning arrives, four rays along the arm's path (at a quarter, half, three
-- quarters and all of the swing) check that the straight line to the target stays clear of him. If it does, the arm
-- points at the target. If not (targets on his left, on his belly, in front of his left boot), it goes to one fixed pose,
-- about 70 degrees forward and 25 degrees out to his right. It is decided once per warning, so it never flips mid-swing.
-- Heavy Sleep (spec Rule 14, "Heavy Sleep after waking", and the "Heavy Sleep" row of section 6): while Phase is
-- HeavySleep the Z Z Z sign is 2.5 times its size and the snore puffs come 3 times as often and 1.6 times bigger. The
-- sign grows around its bottom-left corner, so it grows up and to the right, away from his face. When Heavy Sleep ends the
-- Z Z Z shrink back over 0.5 seconds with the same smooth easing as the pose, and the puffs are normal at once. The normal
-- look is always what the place had (saved the first time, like everything else here), never a number in code, and a
-- part that streams in gets the look for the phase at that moment. Off is off: the quiet and awake rules above win.
-- Pieces are always placed from the pivot they had at the start (saved once), never by adding to where they are now, so
-- a second flutter can never leave them out of place. The motion needs no tween: it runs on `step` and
-- connects to it only while something is moving.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Bubble85 = require(script.Parent.Bubble85)
local Shared = require(script.Shared)
local Motion = require(script.Motion)
local Find = require(script.Find)
local BubbleLook = require(script.BubbleLook)
local SleepSigns = require(script.SleepSigns)
local Pose = require(script.Pose)
local Ride = require(script.Ride)
local WakeFace = require(script.WakeFace)

local FLUTTER = Shared.FLUTTER
local FADE_LETTERS = Shared.FADE_LETTERS
local STOP_LETTERS = Shared.STOP_LETTERS
local MUMBLE = Shared.MUMBLE
local SNORT = Shared.SNORT
local SHOULDER_ATTRIBUTE = Shared.SHOULDER_ATTRIBUTE
local RAISE_ATTRIBUTE = Shared.RAISE_ATTRIBUTE

local GiantFx = {}

export type SignalLike = Shared.SignalLike
export type WarningLike = Shared.WarningLike
export type Deps = Shared.Deps
export type Handle = Shared.Handle
export type Sign = Shared.Sign

GiantFx.flutterSeconds = Shared.flutterSeconds
GiantFx.flutterCount = Shared.flutterCount
GiantFx.snortPuffs = Shared.snortPuffs
GiantFx.snortGapSeconds = Shared.snortGapSeconds
GiantFx.fadeSeconds = Shared.fadeSeconds
GiantFx.fadeEdgeSeconds = Shared.fadeEdgeSeconds
GiantFx.fadeTo = Shared.fadeTo
GiantFx.fadeInSeconds = Shared.fadeInSeconds
GiantFx.comeBackAtMeter = Shared.comeBackAtMeter
GiantFx.poseSeconds = Shared.poseSeconds
GiantFx.headTipSeconds = Shared.headTipSeconds
GiantFx.heavyLetterScale = Shared.heavyLetterScale
GiantFx.heavyPuffRateScale = Shared.heavyPuffRateScale
GiantFx.heavyPuffSizeScale = Shared.heavyPuffSizeScale
GiantFx.heavyShrinkSeconds = Shared.heavyShrinkSeconds
GiantFx.heavyFixedCorner = Shared.heavyFixedCorner
GiantFx.slamSwingSeconds = Shared.slamSwingSeconds
GiantFx.slamHoldUntil = Shared.slamHoldUntil
GiantFx.slamSeconds = Shared.slamSeconds
GiantFx.armLength = Shared.armLength
GiantFx.slamFixedForwardDegrees = Shared.slamFixedForwardDegrees
GiantFx.slamFixedOutDegrees = Shared.slamFixedOutDegrees

GiantFx.warningPlan = Motion.warningPlan
GiantFx.poseShare = Motion.poseShare
GiantFx.headShare = Motion.headShare
GiantFx.slamTurn = Motion.slamTurn
GiantFx.slamShare = Motion.slamShare
GiantFx.slamFixedAim = Motion.slamFixedAim
GiantFx.slamAim = Motion.slamAim
GiantFx.workspaceArmClear = Motion.workspaceArmClear
GiantFx.headTurn = Motion.headTurn
GiantFx.armRaise = Motion.armRaise
GiantFx.lift = Motion.lift
GiantFx.flutterLift = Motion.flutterLift
GiantFx.fadedTransparency = Motion.fadedTransparency
GiantFx.fadedInTransparency = Motion.fadedInTransparency

-- Starts the warnings on the giant.
function GiantFx.start(deps: Deps): Handle
	local state: Shared.State = {
		trove = Trove.new(),
		stopped = false,
		startPivots = {},
		startMiddles = {},
		startSliver = {},
		startEnabled = {},
		startLetter = {},
		startOutline = {},
		startSignSize = {},
		startSignOffset = {},
		startRate = {},
		startPuffSize = {},
		startLook = {},
		flutterAt = nil,
		fadeAt = nil,
		snortAt = nil,
		bubbleAt = nil,
		bubbleUntil = nil,
		quiet = false,
		replayUntil = nil,
		fadeInAt = nil,
		stepConnection = nil,
		awake = false,
		poseAge = 0,
		poseClock = 0,
		poseDirection = 0,
		slamAt = nil,
		slamPoint = nil,
		slamStart = nil,
		awakeEndsAt = nil,
		heavy = false,
		shrinkAt = nil,
		faceAt = nil,
		faceLook = {},
		faceSize = {},
		startBubble = {},
		bubbleWatch = {},
	}

	local find = Find.new(deps)
	local bubbleLook = BubbleLook.new(state, deps, find)
	local sleepSigns = SleepSigns.new(state, deps, find)
	local ride = Ride.new(state, deps)
	state.trove:Add(ride.destroy)
	local pose = Pose.new(state, find, ride)
	local wakeFace = WakeFace.new(state, deps, find)

	-- The look of the Z Z Z now, told to the Zs on the meter whenever it differs from the last one told.
	local lastSign: Shared.Sign? = nil
	local function notifySigns()
		local sign: Shared.Sign = "shown"
		if state.quiet or state.awake then
			sign = "hidden"
		elseif state.heavy then
			sign = "heavy"
		elseif state.fadeAt ~= nil then
			sign = "faded"
		end
		if sign ~= lastSign then
			lastSign = sign
			local tell = deps.onSignsChanged
			if tell ~= nil then
				tell(sign)
			end
		end
	end

	-- Puts the Z Z Z and the puffs, and the bubble, in the state they should be in now. It is safe to call it again
	-- and again: a part that streams in later gets the same state.
	local function applyState()
		sleepSigns.placeSign(deps.now())
		sleepSigns.placePuff()
		local sign = find.floatingZ()
		if sign ~= nil then
			if state.quiet or state.awake then
				sleepSigns.setEnabled(sign, false)
			else
				sleepSigns.restoreEnabled(sign)
			end
		end
		local puff = find.snorePuff()
		if puff ~= nil then
			if state.quiet or state.awake then
				sleepSigns.setEnabled(puff, false)
			else
				sleepSigns.restoreEnabled(puff)
			end
		end
		local gui = find.bubble()
		if gui ~= nil then
			if state.bubbleUntil ~= nil and not state.awake then
				bubbleLook.placeBubble(gui, deps.now())
				sleepSigns.setEnabled(gui, true)
			else
				sleepSigns.restoreEnabled(gui)
			end
		end
		notifySigns()
	end

	-- True when the meter or the phase lets the Z Z Z and puffs come back: Heavy Sleep, or asleep with the meter at 75 or less.
	local function mayComeBack(): boolean
		local phase = deps.giantState:GetAttribute("Phase")
		local meter = deps.giantState:GetAttribute("Meter")
		return phase == "HeavySleep"
			or (phase == "Asleep" and type(meter) == "number" and meter <= Shared.comeBackAtMeter)
	end

	-- The 3 seconds of a replayed warning are over at `now`. If the meter lets them, the Z Z Z and puffs come back and the
	-- letters fade in. If not, they stay off until the meter falls (onGiantStateChanged), as after a plain 85.
	local function endReplay(now: number)
		if state.quiet and mayComeBack() then
			state.quiet = false
			state.fadeInAt = now
			applyState()
			sleepSigns.paintFadeIn(0)
		end
	end

	local function disconnectStep()
		if state.stepConnection ~= nil then
			state.stepConnection:Disconnect()
			state.stepConnection = nil
		end
	end

	-- Moves everything that is moving, and finishes what is over. When nothing is left, it lets go of `step`.
	local function onStep()
		if state.stopped then
			return
		end
		local now = deps.now()
		if state.flutterAt ~= nil then
			local seconds = now - state.flutterAt
			local total = Shared.flutterSeconds * Shared.flutterCount
			if seconds >= total then
				state.flutterAt = nil
				pose.placeLids(0)
			else
				pose.placeLids(seconds)
			end
		end
		if state.snortAt ~= nil and now - state.snortAt >= Shared.snortGapSeconds then
			state.snortAt = nil
			sleepSigns.snortBurst()
		end
		if state.fadeAt ~= nil then
			local seconds = now - state.fadeAt
			if seconds >= Shared.fadeSeconds then
				state.fadeAt = nil
				sleepSigns.paintLetters(nil)
				notifySigns()
			else
				sleepSigns.paintLetters(seconds)
			end
		end
		if state.bubbleUntil ~= nil then
			if now >= state.bubbleUntil then
				state.bubbleAt = nil
				state.bubbleUntil = nil
				applyState()
			else
				local gui = find.bubble()
				if gui ~= nil then
					bubbleLook.placeBubble(gui, now)
				end
			end
		end
		if state.replayUntil ~= nil and now >= state.replayUntil then
			state.replayUntil = nil
			endReplay(now)
		end
		if state.fadeInAt ~= nil then
			local seconds = now - state.fadeInAt
			if seconds >= Shared.fadeInSeconds then
				state.fadeInAt = nil
				sleepSigns.paintFadeIn(nil)
			else
				sleepSigns.paintFadeIn(seconds)
			end
		end
		if state.shrinkAt ~= nil then
			if now - state.shrinkAt >= Shared.heavyShrinkSeconds then
				state.shrinkAt = nil
			end
			sleepSigns.placeSign(now)
		end
		if state.poseDirection ~= 0 then
			local age = pose.poseAgeAt(now)
			pose.placePose(age, now)
			if (state.poseDirection > 0 and age >= Shared.poseSeconds) or (state.poseDirection < 0 and age <= 0) then
				state.poseAge = age
				state.poseClock = now
				state.poseDirection = 0
			end
		elseif state.slamAt ~= nil then
			pose.placeRightArm(Motion.poseShare(state.poseAge), now)
		end
		if state.slamAt ~= nil and now - state.slamAt >= Shared.slamSeconds then
			state.slamAt = nil
			state.slamPoint = nil
			state.slamStart = nil
		end
		if state.faceAt ~= nil then
			wakeFace.update(now)
		end
		ride.update(now)
		if
			state.flutterAt == nil
			and state.snortAt == nil
			and state.fadeAt == nil
			and state.bubbleUntil == nil
			and state.replayUntil == nil
			and state.fadeInAt == nil
			and state.poseDirection == 0
			and state.slamAt == nil
			and state.shrinkAt == nil
			and state.faceAt == nil
			and not ride.busy()
		then
			disconnectStep()
		end
	end

	-- Listens to `step` while something plays.
	local function connectStep()
		if state.stepConnection == nil then
			state.stepConnection = deps.step:Connect(onStep)
		end
	end

	local function onWarning(mark: any, kind: any)
		-- Once he is awake (or while he settles back), the warnings are over: a late one must not start a flutter.
		if state.stopped or state.awake or state.poseDirection ~= 0 then
			return
		end
		-- Only a plain warning (no second value) and the free save's replay count. Anything else is ignored.
		if kind ~= nil and kind ~= Net.FreeSaveKind then
			return
		end
		local plan = Motion.warningPlan(mark)
		if table.find(plan, FLUTTER) ~= nil then
			state.flutterAt = deps.now()
		end
		if table.find(plan, FADE_LETTERS) ~= nil then
			state.fadeAt = deps.now()
		end
		if table.find(plan, STOP_LETTERS) ~= nil then
			state.quiet = true
			-- A new 85 ends a fade-in that was playing: the Z Z Z go off again with their own look.
			if state.fadeInAt ~= nil then
				state.fadeInAt = nil
				sleepSigns.paintFadeIn(nil)
			end
			if kind == Net.FreeSaveKind then
				sleepSigns.letters() -- saves the letters' own look before anything paints them
				state.replayUntil = deps.now() + Config.Meter.FreeSaveWarningSeconds
			else
				state.replayUntil = nil
			end
		end
		if table.find(plan, MUMBLE) ~= nil then
			-- Every 85, plain or replayed, pops the bubble in from the start.
			local popAt = deps.now()
			state.bubbleAt = popAt
			state.bubbleUntil = popAt + Bubble85.showSeconds(deps.reducedMotion())
		end
		if table.find(plan, SNORT) ~= nil then
			-- A new 85 starts the snort over: a burst now, and the second one after this one (not after the old one).
			state.snortAt = deps.now()
			sleepSigns.snortBurst()
		end
		if #plan > 0 then
			applyState()
			connectStep()
		end
	end

	-- Where the arm aims for a slam at `point`, decided once when the warning arrives: at the point itself if the arm's
	-- straight line stays clear of his body through the whole swing, otherwise the fixed pose. If the giant's numbers are
	-- missing, the point (the arm stays where it is then, as it does for the raise).
	local function slamAimAt(point: Vector3): Vector3
		local model = find.giant()
		local rightArm = find.arm()
		if model == nil or rightArm == nil then
			return point
		end
		local shoulder: any = model:GetAttribute(SHOULDER_ATTRIBUTE)
		local raise: any = model:GetAttribute(RAISE_ATTRIBUTE)
		if typeof(shoulder) ~= "Vector3" or typeof(raise) ~= "Vector3" then
			return point
		end
		local from = pose.raisedDirection(rightArm, shoulder, raise)
		if from == nil then
			return point
		end
		-- A swing still out: the arm points where that swing has it now, and the new path starts from there.
		if state.slamStart ~= nil then
			from = state.slamStart:VectorToWorldSpace(from)
		end
		local fixed = Motion.slamFixedAim(shoulder, model:GetPivot())
		return Motion.slamAim(shoulder, from, point, fixed, deps.armClear)
	end

	-- A slam is coming: the arm starts to swing toward the point. Only while he is awake. A new warning while the swing
	-- before it is still out takes the arm on from where it is (slamStart), so it never jumps.
	local function onSlamWarning(_slam: any, point: any, _landsAt: any)
		if state.stopped or not state.awake or typeof(point) ~= "Vector3" then
			return
		end
		local now = deps.now()
		state.slamStart = if state.slamAt ~= nil then pose.slamTurnAt(now) else nil
		state.slamAt = now
		state.slamPoint = slamAimAt(point)
		connectStep()
	end

	-- Starts the pose going forward (1) or back (-1) from wherever it is now.
	local function startPose(direction: number)
		local now = deps.now()
		state.poseAge = pose.poseAgeAt(now)
		state.poseClock = now
		state.poseDirection = direction
		connectStep()
	end

	-- The end of his awake time on the server's clock, read from PhaseEndsAt (which the server writes before Awake), or nil.
	local function readAwakeEnd(): number?
		local ends = deps.giantState:GetAttribute("PhaseEndsAt")
		return if type(ends) == "number" then ends else nil
	end

	-- He woke: the warnings stop at once, the snort cloud is cleared, the eyes swap, the bubble, the Z Z Z and the puffs go off,
	-- and the pose starts.
	local function onWake()
		state.awake = true
		state.awakeEndsAt = readAwakeEnd()
		if state.flutterAt ~= nil then
			state.flutterAt = nil
			pose.placeLids(0)
		end
		state.snortAt = nil
		sleepSigns.clearSnort()
		if state.fadeAt ~= nil then
			state.fadeAt = nil
			sleepSigns.paintLetters(nil)
		end
		state.bubbleAt = nil
		state.bubbleUntil = nil
		state.replayUntil = nil
		if state.fadeInAt ~= nil then
			state.fadeInAt = nil
			sleepSigns.paintFadeIn(nil)
		end
		pose.setEyes(true)
		applyState()
		startPose(1)
		wakeFace.start(deps.now())
		ride.update(deps.now())
	end

	-- He is no longer awake: the eyes swap back at once and the pose goes back.
	local function onSleepAgain()
		state.awake = false
		pose.setEyes(false)
		wakeFace.finish(true)
		applyState()
		startPose(-1)
		-- A device that hears of this late counts the lateness as already gone: the arm is back at rest on the server's time.
		local endsAt = state.awakeEndsAt
		state.awakeEndsAt = nil
		if endsAt ~= nil then
			local late = deps.serverNow() - endsAt
			if late > 0 then
				state.poseClock -= late
			end
		end
		ride.update(deps.now())
	end

	-- The Z Z Z and puffs come back when the meter has fallen to 75 while he sleeps, or when he is in Heavy Sleep.
	local function onGiantStateChanged()
		-- During the 3 seconds of a replayed warning nothing comes back; endReplay decides when they are over.
		if state.stopped or not state.quiet or state.replayUntil ~= nil then
			return
		end
		if mayComeBack() then
			state.quiet = false
			applyState()
		end
	end

	-- Puts the saved start back on every piece.
	local function restoreAll()
		disconnectStep()
		state.flutterAt = nil
		state.snortAt = nil
		state.fadeAt = nil
		state.bubbleAt = nil
		state.bubbleUntil = nil
		state.replayUntil = nil
		state.fadeInAt = nil
		state.quiet = false
		state.awake = false
		state.poseDirection = 0
		state.slamAt = nil
		state.slamPoint = nil
		state.slamStart = nil
		state.awakeEndsAt = nil
		wakeFace.finish(false)
		pose.placeLids(0)
		for piece, start in state.startPivots do
			piece:PivotTo(start)
		end
		table.clear(state.startMiddles)
		pose.restoreEyes()
		sleepSigns.paintLetters(nil)
		sleepSigns.restoreEnabled(find.floatingZ())
		sleepSigns.restoreEnabled(find.snorePuff())
		sleepSigns.restoreEnabled(find.bubble())
		for gui in state.startBubble do
			bubbleLook.restoreBubble(gui)
		end
		for gui in table.clone(state.bubbleWatch) do
			bubbleLook.forgetBubble(gui)
		end
		table.clear(state.startBubble)
		table.clear(state.startPivots)
		state.heavy = false
		state.shrinkAt = nil
		for sign, size in state.startSignSize do
			sign.Size = size
			sign.StudsOffset = state.startSignOffset[sign]
		end
		table.clear(state.startSignSize)
		table.clear(state.startSignOffset)
		for puff, rate in state.startRate do
			puff.Rate = rate
			puff.Size = state.startPuffSize[puff]
		end
		table.clear(state.startRate)
		table.clear(state.startPuffSize)
	end
	state.trove:Add(restoreAll)

	state.trove:Add(deps.warning.OnClientEvent:Connect(onWarning))
	state.trove:Add(deps.slamWarning.OnClientEvent:Connect(onSlamWarning))
	-- A change of Phase may start or end the wake-up, and then the Z Z Z rules above are checked as well.
	local function onPhaseChanged()
		if state.stopped then
			return
		end
		local nowHeavy = deps.giantState:GetAttribute("Phase") == "HeavySleep"
		if nowHeavy and not state.heavy then
			-- Big at once, also in the middle of a shrink.
			state.heavy = true
			state.shrinkAt = nil
			applyState()
		elseif not nowHeavy and state.heavy then
			-- The puffs are normal at once; the Z Z Z shrink from where they are.
			state.heavy = false
			state.shrinkAt = deps.now()
			applyState()
			connectStep()
		end
		local nowAwake = deps.giantState:GetAttribute("Phase") == "Awake"
		if nowAwake and not state.awake then
			onWake()
		elseif not nowAwake and state.awake then
			onSleepAgain()
		end
		onGiantStateChanged()
	end
	state.trove:Add(deps.giantState:GetAttributeChangedSignal("Meter"):Connect(onGiantStateChanged))
	state.trove:Add(deps.giantState:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged))

	-- A player who joins in Heavy Sleep sees the big look at once.
	if deps.giantState:GetAttribute("Phase") == "HeavySleep" then
		state.heavy = true
		applyState()
	end

	-- A player who joins while he is awake sees the full pose at once, with no motion.
	if deps.giantState:GetAttribute("Phase") == "Awake" then
		state.awake = true
		state.awakeEndsAt = readAwakeEnd()
		pose.setEyes(true)
		applyState()
		state.poseAge = Shared.poseSeconds
		pose.placePose(state.poseAge, deps.now())
		ride.snap()
	end

	notifySigns() -- the Zs on the meter start with the look he has now

	-- A part of GiantFX that streams in later gets the state it should have now.
	local function onFxAdded(_added: Instance)
		if not state.stopped then
			applyState()
		end
	end
	local watchedFx: Instance? = nil
	local fxConnection: RBXScriptConnection? = nil
	local function watchFx(folder: Instance)
		if watchedFx ~= nil then
			return
		end
		watchedFx = folder
		fxConnection = folder.DescendantAdded:Connect(onFxAdded)
	end
	state.trove:Add(function()
		if fxConnection ~= nil then
			fxConnection:Disconnect()
			fxConnection = nil
		end
	end)
	local existing = find.fx()
	if existing ~= nil then
		watchFx(existing)
	else
		state.trove:Add(deps.world.ChildAdded:Connect(function(added: Instance)
			if added.Name == "GiantFX" then
				watchFx(added)
				onFxAdded(added)
			end
		end))
	end

	return {
		stop = function()
			if state.stopped then
				return
			end
			state.stopped = true
			state.trove:Destroy()
		end,
		savedBubbleCount = function(): number
			local count = 0
			for _ in state.startBubble do
				count += 1
			end
			return count
		end,
	}
end

return GiantFx
