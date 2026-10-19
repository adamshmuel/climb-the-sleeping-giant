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
local SlamFx = require(script.Parent.SlamFx)

local GiantFx = {}

-- The names of the things a warning does, in the order the style guide lists them.
local FLUTTER = "flutterEyelids"
local FADE_LETTERS = "fadeLetters"
local STOP_LETTERS = "stopLetters"
local STOP_PUFFS = "stopPuffs"
local MUMBLE = "mumbleBubble"
local SNORT = "snortNose"
local GLOW = "tiptoeGlow"
local TIP = "standStillTip"

local PLAN_60: { string } = table.freeze({ FLUTTER, FADE_LETTERS })
local PLAN_85: { string } = table.freeze({ STOP_LETTERS, STOP_PUFFS, MUMBLE, SNORT, GLOW, TIP })
local PLAN_NONE: { string } = table.freeze({})

GiantFx.flutterSeconds = 0.5 -- one flutter: 0.25 s up, 0.25 s down
GiantFx.flutterCount = 2
GiantFx.snortPuffs = 20 -- the puffs in each of the two snort bursts (style guide, "The snort")
GiantFx.snortGapSeconds = 0.5 -- the second burst comes this long after the first
GiantFx.fadeSeconds = 2 -- the Z Z Z fade, all in all
GiantFx.fadeEdgeSeconds = 0.2 -- the way down to half and the way back
GiantFx.fadeTo = 0.5 -- half see-through
GiantFx.fadeInSeconds = 0.2 -- the letters of the Z Z Z come back from fully see-through over this long, after a replay
GiantFx.comeBackAtMeter = 75
GiantFx.poseSeconds = 0.5 -- the head tip and the fist raise, on waking and on going back to sleep
-- Heavy Sleep: how much bigger the Z Z Z sign is (designer: 2.5 times, because the style guide asks for "much bigger").
GiantFx.heavyLetterScale = 2.5
-- How many times as many snore puffs come per second (spec: 3 times as many).
GiantFx.heavyPuffRateScale = 3
-- How much bigger each snore puff is (art list: 1.6 times).
GiantFx.heavyPuffSizeScale = 1.6
-- How long the Z Z Z take to shrink back when Heavy Sleep ends (the same 0.5 s as the waking pose).
GiantFx.heavyShrinkSeconds = 0.5
-- The corner of the sign that stays put when it grows, as a direction from its middle: left (-1) and bottom (-1), so
-- the letters grow up and to the right and never down over his face.
GiantFx.heavyFixedCorner = Vector2.new(-1, -1)
GiantFx.slamSwingSeconds = 0.5 -- the arm swings out toward the target, and later back, over this long
-- The arm holds out until the fist starts to lift (the warning time plus the time the fist stays down), then comes
-- back. The whole swing lasts until then plus the swing back.
GiantFx.slamHoldUntil = Config.Wake.SlamWarningSeconds + SlamFx.FIST_DOWN_SECONDS
GiantFx.slamSeconds = GiantFx.slamHoldUntil + GiantFx.slamSwingSeconds

-- How long his arm is, in studs. It never reaches the target (the separate fist does the slam), so this is how far from
-- his shoulder the arm's path is checked against his body, and how far the fixed pose is from the shoulder.
GiantFx.armLength = 50
-- The fixed pose of the slam swing, for targets the arm can't point at without going through his body: this many degrees
-- raised forward from hanging straight down, then this many degrees out to his right.
GiantFx.slamFixedForwardDegrees = 70
GiantFx.slamFixedOutDegrees = 25
-- The slam swing is checked at these shares of the way to the target: a quarter, half, three quarters and all of it.
local SWING_CHECK_SHARES: { number } = table.freeze({ 0.25, 0.5, 0.75, 1 })
-- The piece of the giant that is the arm itself, which the arm's path doesn't count as his body.
local ARM_NAME = "right_arm"

-- What each warning does. Any other mark does nothing.
function GiantFx.warningPlan(mark: any): { string }
	if mark == 60 then
		return PLAN_60
	elseif mark == 85 then
		return PLAN_85
	end
	return PLAN_NONE
end

-- Smooth start and finish: 0 to 1 over `t` from 0 to 1.
local function smooth(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- How far into the waking pose it is, from 0 (at rest) to 1 (the full pose), `seconds` after it started. It starts and
-- finishes smoothly, like the warnings.
function GiantFx.poseShare(seconds: number): number
	return smooth(seconds / GiantFx.poseSeconds)
end

-- How big the Z Z Z sign is, from 0 (its normal size) to 1 (full Heavy Sleep size), `seconds` after Heavy Sleep ended.
local function heavyLetterShare(seconds: number): number
	return 1 - smooth(seconds / GiantFx.heavyShrinkSeconds)
end

-- The size and the StudsOffset of a sign that normally has `size` and `offset`, `share` of the way to the Heavy Sleep
-- size. Both parts of the size grow (the studs and the pixels), and the offset moves so that the fixed corner stays
-- where it was: the sign's middle moves half of the growth away from that corner. Only the studs count for that.
local function heavySign(size: UDim2, offset: Vector3, share: number): (UDim2, Vector3)
	if share <= 0 then
		return size, offset
	end
	local factor = 1 + (GiantFx.heavyLetterScale - 1) * share
	local grown =
		UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
	local corner = GiantFx.heavyFixedCorner
	local moveX = -corner.X * (grown.X.Scale - size.X.Scale) / 2
	local moveY = -corner.Y * (grown.Y.Scale - size.Y.Scale) / 2
	return grown, offset + Vector3.new(moveX, moveY, 0)
end

-- A puff size curve with every value and every envelope (the random spread) `scale` times bigger.
local function scaledPuffSize(sequence: NumberSequence, scale: number): NumberSequence
	local keypoints: { NumberSequenceKeypoint } = {}
	for _, keypoint in sequence.Keypoints do
		table.insert(
			keypoints,
			NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale)
		)
	end
	return NumberSequence.new(keypoints)
end

-- The turn about `shoulder` that swings the arm toward a target: it turns the direction `from` toward the direction
-- (toward - shoulder) by `share` of the angle between them. At share 0 it is the identity, and at share 1 `from` points
-- exactly at the target. Put it in front of the arm's other turns: slamTurn * armRaise * start. Directions that are
-- already the same turn nothing; exactly opposite directions turn about any axis at right angles to `from`; a target
-- on the shoulder itself, or no `from`, turn nothing.
function GiantFx.slamTurn(shoulder: Vector3, from: Vector3, toward: Vector3, share: number): CFrame
	local aim = toward - shoulder
	if from.Magnitude < 1e-6 or aim.Magnitude < 1e-6 or share == 0 then
		return CFrame.identity
	end
	local start = from.Unit
	local goal = aim.Unit
	local cross = start:Cross(goal)
	local angle = math.atan2(cross.Magnitude, start:Dot(goal))
	local axis: Vector3
	if cross.Magnitude > 1e-6 then
		axis = cross.Unit
	elseif angle > math.pi / 2 then
		-- Exactly opposite: any axis at right angles to `from` will do.
		local helper = if math.abs(start.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		axis = start:Cross(helper).Unit
	else
		return CFrame.identity
	end
	return CFrame.new(shoulder) * CFrame.fromAxisAngle(axis, angle * share) * CFrame.new(-shoulder)
end

-- How far out the arm is swung, from 0 (raised, as after waking) to 1 (pointing at the target), `seconds` after the
-- SlamWarning arrived. It swings out over 0.5 seconds with the same smooth easing as the pose, stays out until the fist
-- starts to lift, comes back over 0.5 seconds, and is 0 for good after that.
function GiantFx.slamShare(seconds: number): number
	if seconds <= 0 then
		return 0
	elseif seconds < GiantFx.slamSwingSeconds then
		return smooth(seconds / GiantFx.slamSwingSeconds)
	elseif seconds <= GiantFx.slamHoldUntil then
		return 1
	end
	return 1 - smooth((seconds - GiantFx.slamHoldUntil) / GiantFx.slamSwingSeconds)
end

-- The point the arm aims at in the fixed pose: GiantFx.armLength studs from `shoulder`, 70 degrees raised forward and 25
-- degrees out to his right. The directions are in the giant's own axes (he faces -Z, his right is +X), so they turn with
-- `giantPivot`: hanging straight down, raised `forward` degrees toward the front, then `out` degrees toward his right.
function GiantFx.slamFixedAim(shoulder: Vector3, giantPivot: CFrame): Vector3
	local forward = math.rad(GiantFx.slamFixedForwardDegrees)
	local out = math.rad(GiantFx.slamFixedOutDegrees)
	local direction = Vector3.new(math.sin(out), -math.cos(forward) * math.cos(out), -math.sin(forward) * math.cos(out))
	return shoulder + giantPivot:VectorToWorldSpace(direction) * GiantFx.armLength
end

-- Where the arm aims at a slam: `point` if the arm's straight line from `shoulder` stays clear of his body through the
-- whole swing, otherwise `fixedAim`. The swing is checked at a quarter, half, three quarters and all of the way: for
-- each, `isClear` is asked about the direction the arm's own direction `from` points in after that much of the turn.
function GiantFx.slamAim(
	shoulder: Vector3,
	from: Vector3,
	point: Vector3,
	fixedAim: Vector3,
	isClear: (shoulder: Vector3, direction: Vector3) -> boolean
): Vector3
	for _, share in SWING_CHECK_SHARES do
		local direction = GiantFx.slamTurn(shoulder, from, point, share):VectorToWorldSpace(from)
		if not isClear(shoulder, direction) then
			return fixedAim
		end
	end
	return point
end

-- The real way to ask whether the arm's path is clear: one ray from the shoulder along the direction, as long as the
-- arm, that sees only the giant's own pieces except the right arm. It looks at the giant's pieces each time, because
-- they can stream in and out on a player's device. With no giant there is no arm to move, so the path counts as clear.
function GiantFx.workspaceArmClear(
	workspace: WorldRoot,
	world: Instance
): (shoulder: Vector3, direction: Vector3) -> boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	return function(shoulder: Vector3, direction: Vector3): boolean
		local giant = world:FindFirstChild("Giant")
		if giant == nil or direction.Magnitude < 1e-6 then
			return true
		end
		local body: { Instance } = {}
		for _, piece in giant:GetChildren() do
			if piece.Name ~= ARM_NAME then
				table.insert(body, piece)
			end
		end
		params.FilterDescendantsInstances = body
		return workspace:Raycast(shoulder, direction.Unit * GiantFx.armLength, params) == nil
	end
end

-- The turn that tips the head `share` of the way: put it in front of a piece's start pivot (turn * start). The head
-- turns about the X axis through `pivot`, by `tiltDegrees` times `share`.
function GiantFx.headTurn(pivot: Vector3, tiltDegrees: number, share: number): CFrame
	return CFrame.new(pivot) * CFrame.Angles(math.rad(tiltDegrees * share), 0, 0) * CFrame.new(-pivot)
end

-- The turn that raises the right arm `share` of the way: put it in front of the arm's start pivot. The arm turns about
-- `shoulder`, around the axis of the rotation CFrame.Angles(x, y, z) (`raiseDegreesXZ` holds x, y and z in degrees: the
-- same axis the wake-up raise uses), by that rotation's own angle times `share`. At share 1 it is exactly the full raise.
function GiantFx.armRaise(shoulder: Vector3, raiseDegreesXZ: Vector3, share: number): CFrame
	local full = CFrame.Angles(math.rad(raiseDegreesXZ.X), math.rad(raiseDegreesXZ.Y), math.rad(raiseDegreesXZ.Z))
	local axis, angle = full:ToAxisAngle()
	if angle == 0 then
		return CFrame.identity
	end
	return CFrame.new(shoulder) * CFrame.fromAxisAngle(axis, angle * share) * CFrame.new(-shoulder)
end

-- How far up a flutter is, from 0 (down) to 1 (all the way up), `seconds` after the warning started.
-- Two up-and-down movements, 0.25 s up and 0.25 s down each, with no pause. After the last one it is 0 for good.
function GiantFx.lift(seconds: number): number
	local total = GiantFx.flutterSeconds * GiantFx.flutterCount
	if seconds <= 0 or seconds >= total then
		return 0
	end
	local half = GiantFx.flutterSeconds / 2
	local inside = (seconds % GiantFx.flutterSeconds) / half -- 0 to 2 within one movement
	if inside <= 1 then
		return smooth(inside)
	end
	return smooth(2 - inside)
end

-- How many studs a lid is lifted `seconds` after a 60 warning started, for a lid that lifts `flutterLift` studs.
function GiantFx.flutterLift(seconds: number, flutterLift: number): number
	return flutterLift * GiantFx.lift(seconds)
end

-- How see-through a Z letter or its outline is `seconds` after a 60 warning started, if it normally has `normal`.
-- It goes to half over the first 0.2 s, holds, and comes back over the last 0.2 s. After 2 s it is `normal` again.
function GiantFx.fadedTransparency(normal: number, seconds: number): number
	local total = GiantFx.fadeSeconds
	local edge = GiantFx.fadeEdgeSeconds
	if seconds <= 0 or seconds >= total then
		return normal
	end
	local share = 1
	if seconds < edge then
		share = seconds / edge
	elseif seconds > total - edge then
		share = (total - seconds) / edge
	end
	return normal + (GiantFx.fadeTo - normal) * share
end

-- How see-through a Z letter or its outline is `seconds` after the Z Z Z came back at the end of a replayed warning, if
-- it normally has `normal`. It starts fully see-through (1), comes back evenly over 0.2 s, and is `normal` after that.
function GiantFx.fadedInTransparency(normal: number, seconds: number): number
	if seconds >= GiantFx.fadeInSeconds then
		return normal
	end
	local share = math.max(seconds, 0) / GiantFx.fadeInSeconds
	return 1 + (normal - 1) * share
end

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

-- The Warning remote, as far as this module uses it: it fires the mark (60 or 85), and at a free save (85, Net.FreeSaveKind).
export type WarningLike = { OnClientEvent: SignalLike }

export type Deps = {
	world: Instance, -- Workspace.World
	warning: WarningLike, -- the Warning remote
	slamWarning: WarningLike, -- the SlamWarning remote
	giantState: Instance, -- ReplicatedStorage.GiantState: the attributes Meter and Phase
	step: SignalLike, -- once per frame, for the motion (RenderStepped)
	now: () -> number, -- a clock in seconds (os.clock)
	armClear: (shoulder: Vector3, direction: Vector3) -> boolean, -- is the arm's path clear of his body?
	-- Sends `count` puffs out of an emitter at once. If left out, it is the emitter's own Emit.
	burst: ((emitter: ParticleEmitter, count: number) -> ())?,
	-- Clears every puff an emitter has sent out, at once. If left out, it is the emitter's own Clear.
	clear: ((emitter: ParticleEmitter) -> ())?,
	isPhone: () -> boolean, -- is this a phone screen? (asked each time, so a new window size counts)
	cameraRight: () -> Vector3, -- the current camera's RightVector (its Z says which side of his nose the bubble goes)
	reducedMotion: () -> boolean, -- GuiService.ReducedMotionEnabled: the bubble just appears and goes
}

-- What start gives back: `stop` puts every piece back as it was and disconnects everything.
export type Handle = {
	stop: () -> (),
	-- How many bubbles have their first look saved right now (for tests: a bubble that left the game has none).
	savedBubbleCount: () -> number,
}

local LID_NAMES = { "LeftLid", "RightLid" }
-- The pieces that tip forward with the head.
local HEAD_PIECE_NAMES = { "head_with_beard", "nightcap" }
-- The attributes on the giant that say where and how far the pieces turn.
local HEAD_PIVOT_ATTRIBUTE = "Awake_HeadPivot"
local HEAD_TILT_ATTRIBUTE = "Awake_HeadTiltDeg"
local SHOULDER_ATTRIBUTE = "Awake_RightShoulderPivot"
local RAISE_ATTRIBUTE = "Awake_RightArmRaiseDegXZ"
-- The part attribute that marks the awake eyes that show when he wakes.
local SHOWN_WHEN_AWAKE = "ShownWhenAwake"

-- Starts the warnings on the giant.
function GiantFx.start(deps: Deps): Handle
	local trove = Trove.new()
	local stopped = false

	-- Where each moved piece started (saved the first time it is seen), and the flags and transparencies that were
	-- there before this module changed them.
	local startPivots: { [Model]: CFrame } = {}
	-- The middle of each model's bounding box when its start pivot was saved (the arm's is where the swing aims from).
	local startMiddles: { [Model]: Vector3 } = {}
	local startSliver: { [Instance]: number } = {}
	local startEnabled: { [Instance]: boolean } = {}
	local startLetter: { [Instance]: number } = {}
	local startOutline: { [Instance]: number } = {}
	-- How the Z Z Z sign and the snore puff were before Heavy Sleep changed them.
	local startSignSize: { [BillboardGui]: UDim2 } = {}
	local startSignOffset: { [BillboardGui]: Vector3 } = {}
	local startRate: { [ParticleEmitter]: number } = {}
	local startPuffSize: { [ParticleEmitter]: NumberSequence } = {}
	-- How see-through each eye part was before the eyes were swapped.
	local startLook: { [BasePart]: number } = {}

	-- What is playing now: the time each started, or nil.
	local flutterAt: number? = nil
	local fadeAt: number? = nil
	-- When the snort started: its second burst is still to come until this is nil.
	local snortAt: number? = nil
	-- The 85 bubble: when it popped in, and when it goes off (after its fade), or nil.
	local bubbleAt: number? = nil
	local bubbleUntil: number? = nil
	-- True from an 85 warning until the Z Z Z and puffs may come back.
	local quiet = false
	-- After a replayed 85: when its 3 seconds are over (the Z Z Z stay off until then), or nil. And when the Z Z Z came
	-- back after it, while the letters fade in, or nil.
	local replayUntil: number? = nil
	local fadeInAt: number? = nil
	local stepConnection: RBXScriptConnection? = nil
	-- True from the moment Phase turned Awake until it left Awake.
	local awake = false
	-- The waking pose: how many seconds into it it was at `poseClock` (0 is at rest, poseSeconds is the full pose), and
	-- whether it is going forward (1), going back (-1) or standing still (0).
	local poseAge = 0
	local poseClock = 0
	local poseDirection = 0
	-- The swing in progress: when its SlamWarning arrived (by deps.now) and where the slam lands, or nil.
	local slamAt: number? = nil
	local slamPoint: Vector3? = nil
	-- True from the moment Phase turned HeavySleep until it left. After it, the Z Z Z shrink: `shrinkAt` is when Heavy
	-- Sleep ended (by deps.now), or nil when they are not shrinking.
	local heavy = false
	local shrinkAt: number? = nil

	-- Looking things up each time, because the parts of GiantFX can stream in and out on a player's device.
	local function child(parent: Instance?, name: string): any
		if parent == nil then
			return nil
		end
		return parent:FindFirstChild(name)
	end

	local function giant(): any
		return child(deps.world, "Giant")
	end

	local function fx(): any
		return child(deps.world, "GiantFX")
	end

	local function lids(): { Model }
		local found: { Model } = {}
		local eyes = child(giant(), "SleepEyes")
		for _, name in LID_NAMES do
			local lid = child(eyes, name)
			if lid ~= nil and lid:IsA("Model") then
				table.insert(found, lid)
			end
		end
		return found
	end

	local function arm(): Model?
		local found = child(giant(), "right_arm")
		if found ~= nil and found:IsA("Model") then
			return found
		end
		return nil
	end

	local function floatingZ(): BillboardGui?
		local found = child(child(fx(), "SnoreEmitter"), "FloatingZ")
		if found ~= nil and found:IsA("BillboardGui") then
			return found
		end
		return nil
	end

	local function snorePuff(): ParticleEmitter?
		local found = child(child(fx(), "SnoreEmitter"), "SnorePuff")
		if found ~= nil and found:IsA("ParticleEmitter") then
			return found
		end
		return nil
	end

	local function snortPuff(): ParticleEmitter?
		local found = child(child(fx(), "SnortNose"), "SnortPuff")
		if found ~= nil and found:IsA("ParticleEmitter") then
			return found
		end
		return nil
	end

	local function bubble(): BillboardGui?
		local found = child(child(fx(), "SnoreEmitter"), "Warning85Bubble")
		if found ~= nil and found:IsA("BillboardGui") then
			return found
		end
		return nil
	end

	-- How the bubble was before this module changed it, saved the first time it is placed (a bubble that streams out
	-- and back in is a new instance, so it is saved again).
	type BubbleStart = {
		size: UDim2,
		studsOffset: Vector3,
		sizeOffset: Vector2,
		textScaled: boolean,
		textWrapped: boolean,
		textSize: number,
		tailPosition: UDim2,
		background: { [GuiObject]: number },
		text: { [TextLabel]: number },
		stroke: { [UIStroke]: number },
	}
	local startBubble: { [BillboardGui]: BubbleStart } = {}
	-- Watching each saved bubble, so its entry goes when the bubble leaves the game (it streams out on a phone).
	local bubbleWatch: { [BillboardGui]: { RBXScriptConnection } } = {}

	local function forgetBubble(gui: BillboardGui)
		startBubble[gui] = nil
		local watching = bubbleWatch[gui]
		if watching ~= nil then
			bubbleWatch[gui] = nil
			for _, connection in watching do
				connection:Disconnect()
			end
		end
	end

	local function watchBubble(gui: BillboardGui)
		local function onLeft()
			if not gui:IsDescendantOf(deps.world) then
				forgetBubble(gui)
			end
		end
		-- Destroying fires while the bubble is still in the world, so it forgets at once.
		bubbleWatch[gui] = {
			gui.AncestryChanged:Connect(onLeft),
			gui.Destroying:Connect(function()
				forgetBubble(gui)
			end),
		}
	end

	-- The pieces of the bubble: the pill, its words and the tail (found by name each time).
	local function bubbleWords(gui: BillboardGui): TextLabel?
		local found = child(child(gui, "Frame"), "TextLabel")
		if found ~= nil and found:IsA("TextLabel") then
			return found
		end
		return nil
	end

	local function bubbleTail(gui: BillboardGui): GuiObject?
		local found = child(gui, "Tail")
		if found ~= nil and found:IsA("GuiObject") then
			return found
		end
		return nil
	end

	local function bubbleStartOf(gui: BillboardGui): BubbleStart
		local saved = startBubble[gui]
		if saved ~= nil then
			return saved
		end
		local words = bubbleWords(gui)
		local tail = bubbleTail(gui)
		local made: BubbleStart = {
			size = gui.Size,
			studsOffset = gui.StudsOffset,
			sizeOffset = gui.SizeOffset,
			textScaled = if words ~= nil then words.TextScaled else false,
			textWrapped = if words ~= nil then words.TextWrapped else false,
			textSize = if words ~= nil then words.TextSize else 0,
			tailPosition = if tail ~= nil then tail.Position else UDim2.new(),
			background = {},
			text = {},
			stroke = {},
		}
		for _, piece in gui:GetDescendants() do
			if piece:IsA("TextLabel") then
				made.text[piece] = piece.TextTransparency
			end
			if piece:IsA("GuiObject") then
				made.background[piece] = piece.BackgroundTransparency
			elseif piece:IsA("UIStroke") then
				made.stroke[piece] = piece.Transparency
			end
		end
		startBubble[gui] = made
		watchBubble(gui)
		return made
	end

	-- Makes every part of the bubble `fade` of the way from its own look to fully see-through (0 is its own look).
	local function paintBubble(gui: BillboardGui, fade: number)
		local start = bubbleStartOf(gui)
		for piece, look in start.background do
			piece.BackgroundTransparency = look + (1 - look) * fade
		end
		for piece, look in start.text do
			piece.TextTransparency = look + (1 - look) * fade
		end
		for piece, look in start.stroke do
			piece.Transparency = look + (1 - look) * fade
		end
	end

	-- Sets the bubble's size, side, pop and fade for `now`: `now - bubbleAt` seconds after it popped in.
	local function placeBubble(gui: BillboardGui, now: number)
		local at = bubbleAt
		if at == nil then
			return
		end
		bubbleStartOf(gui)
		local seconds = now - at
		local reduced = deps.reducedMotion()
		local look = Bubble85.size(deps.isPhone())
		local scale = Bubble85.popScale(seconds, reduced)
		gui.Size = UDim2.fromOffset(math.round(look.size.X.Offset * scale), math.round(look.size.Y.Offset * scale))
		local side = Bubble85.side(deps.cameraRight().Z)
		gui.StudsOffset = side.studsOffset
		gui.SizeOffset = side.sizeOffset
		local words = bubbleWords(gui)
		if words ~= nil then
			-- One line at a fixed font size; during the pop the words grow with the bubble.
			words.TextScaled = false
			words.TextWrapped = false
			words.TextSize = math.max(1, math.round(look.textSize * scale))
		end
		local tail = bubbleTail(gui)
		if tail ~= nil then
			tail.Position = Bubble85.tailPosition(side.tailRight)
		end
		paintBubble(gui, Bubble85.fade(seconds, reduced))
	end

	-- Puts the bubble's size, side, words and look back as they were before this module changed them.
	local function restoreBubble(gui: BillboardGui?)
		if gui == nil then
			return
		end
		local start = startBubble[gui]
		if start == nil then
			return
		end
		gui.Size = start.size
		gui.StudsOffset = start.studsOffset
		gui.SizeOffset = start.sizeOffset
		local words = bubbleWords(gui)
		if words ~= nil then
			words.TextScaled = start.textScaled
			words.TextWrapped = start.textWrapped
			words.TextSize = start.textSize
		end
		local tail = bubbleTail(gui)
		if tail ~= nil then
			tail.Position = start.tailPosition
		end
		paintBubble(gui, 0)
	end

	-- The pivot a model had before any motion of this module, saved the first time.
	local function startPivotOf(model: Model): CFrame
		local saved: CFrame? = startPivots[model]
		if saved == nil then
			saved = model:GetPivot()
			startPivots[model] = saved :: CFrame
			startMiddles[model] = (model:GetBoundingBox()).Position
		end
		return saved :: CFrame
	end

	-- Turns something on or off, remembering how it was before.
	local function setEnabled(target: Instance, on: boolean)
		local piece: any = target
		if startEnabled[target] == nil then
			startEnabled[target] = piece.Enabled
		end
		piece.Enabled = on
	end

	local function restoreEnabled(target: Instance?)
		local was: boolean? = if target ~= nil then startEnabled[target] else nil
		if target ~= nil and was ~= nil then
			local piece: any = target
			piece.Enabled = was
		end
	end

	-- Every Z letter with its outline, and the transparencies they normally have (saved the first time).
	local function letters(): { { label: TextLabel, outline: UIStroke? } }
		local found: { { label: TextLabel, outline: UIStroke? } } = {}
		local sign = floatingZ()
		if sign == nil then
			return found
		end
		for _, label in sign:GetChildren() do
			if label:IsA("TextLabel") then
				if startLetter[label] == nil then
					startLetter[label] = label.TextTransparency
				end
				local outline = label:FindFirstChildOfClass("UIStroke")
				if outline ~= nil and startOutline[outline] == nil then
					startOutline[outline] = outline.Transparency
				end
				table.insert(found, { label = label, outline = outline })
			end
		end
		return found
	end

	-- Paints every letter and outline `seconds` into the fade, or back to normal when `seconds` is nil.
	local function paintLetters(seconds: number?)
		for _, letter in letters() do
			local normal = startLetter[letter.label]
			letter.label.TextTransparency = if seconds == nil
				then normal
				else GiantFx.fadedTransparency(normal, seconds)
			local outline = letter.outline
			if outline ~= nil then
				local normalOutline = startOutline[outline]
				outline.Transparency = if seconds == nil
					then normalOutline
					else GiantFx.fadedTransparency(normalOutline, seconds)
			end
		end
	end

	-- Paints every letter and outline `seconds` into the fade-in after a replay, or back to normal when `seconds` is nil.
	local function paintFadeIn(seconds: number?)
		for _, letter in letters() do
			local normal = startLetter[letter.label]
			letter.label.TextTransparency = if seconds == nil
				then normal
				else GiantFx.fadedInTransparency(normal, seconds)
			local outline = letter.outline
			if outline ~= nil then
				local normalOutline = startOutline[outline]
				outline.Transparency = if seconds == nil
					then normalOutline
					else GiantFx.fadedInTransparency(normalOutline, seconds)
			end
		end
	end

	-- How big the sign is now: 1 in Heavy Sleep, falling to 0 over the shrink after it, then 0.
	local function letterShare(now: number): number
		if heavy then
			return 1
		elseif shrinkAt ~= nil then
			return heavyLetterShare(now - shrinkAt)
		end
		return 0
	end

	-- Sizes the Z Z Z sign for `now`, from the size it had before Heavy Sleep touched it (saved the first time). A sign
	-- that was never touched and has nothing to change is left alone.
	local function placeSign(now: number)
		local sign = floatingZ()
		if sign == nil then
			return
		end
		local share = letterShare(now)
		local oldSize: UDim2? = startSignSize[sign]
		local oldOffset: Vector3? = startSignOffset[sign]
		local savedSize: UDim2 = if oldSize ~= nil then oldSize else sign.Size
		local savedOffset: Vector3 = if oldOffset ~= nil then oldOffset else sign.StudsOffset
		if oldSize == nil or oldOffset == nil then
			if share <= 0 then
				return
			end
			startSignSize[sign] = savedSize
			startSignOffset[sign] = savedOffset
		end
		sign.Size, sign.StudsOffset = heavySign(savedSize, savedOffset, share)
	end

	-- Gives the puff its Heavy Sleep rate and size, or its saved ones. The puffs change at once, not over time.
	local function placePuff()
		local puff = snorePuff()
		if puff == nil then
			return
		end
		if startRate[puff] == nil then
			if not heavy then
				return
			end
			startRate[puff] = puff.Rate
			startPuffSize[puff] = puff.Size
		end
		if heavy then
			puff.Rate = startRate[puff] * GiantFx.heavyPuffRateScale
			puff.Size = scaledPuffSize(startPuffSize[puff], GiantFx.heavyPuffSizeScale)
		else
			puff.Rate = startRate[puff]
			puff.Size = startPuffSize[puff]
		end
	end

	-- Puts the Z Z Z and the puffs, and the bubble, in the state they should be in now. It is safe to call it again
	-- and again: a part that streams in later gets the same state.
	local function applyState()
		placeSign(deps.now())
		placePuff()
		local sign = floatingZ()
		if sign ~= nil then
			if quiet or awake then
				setEnabled(sign, false)
			else
				restoreEnabled(sign)
			end
		end
		local puff = snorePuff()
		if puff ~= nil then
			if quiet or awake then
				setEnabled(puff, false)
			else
				restoreEnabled(puff)
			end
		end
		local gui = bubble()
		if gui ~= nil then
			if bubbleUntil ~= nil and not awake then
				placeBubble(gui, deps.now())
				setEnabled(gui, true)
			else
				restoreEnabled(gui)
			end
		end
	end

	-- Places the lids `seconds` into a flutter: each lifted by its own FlutterLift, measured from where it started,
	-- with the white slice showing while it is up. At 0 or after the flutter it is exactly at the start.
	local function placeLids(seconds: number)
		for _, lid in lids() do
			local start = startPivotOf(lid)
			local own: any = lid:GetAttribute("FlutterLift")
			local lift = GiantFx.flutterLift(seconds, if type(own) == "number" then own else 0)
			lid:PivotTo(if lift == 0 then start else start + Vector3.new(0, lift, 0))
			local sliver = lid:FindFirstChild("Sliver")
			if sliver ~= nil and sliver:IsA("BasePart") then
				if startSliver[sliver] == nil then
					startSliver[sliver] = sliver.Transparency
				end
				sliver.Transparency = if lift > 0 then 0 else startSliver[sliver]
			end
		end
	end

	-- One snort burst, from the nose as it is now: it streams in and out on a player's device, so it is looked up each
	-- time, and a burst is skipped (with no error) while it isn't there.
	local function snortBurst()
		local emitter = snortPuff()
		if emitter == nil then
			return
		end
		if deps.burst ~= nil then
			deps.burst(emitter, GiantFx.snortPuffs)
		else
			emitter:Emit(GiantFx.snortPuffs)
		end
	end

	-- Clears the snort cloud at once, from the nose as it is now (skipped, with no error, while it isn't there). The
	-- puffs of a burst live about 2.3 seconds, so at a wake they would still cover his open eyes.
	local function clearSnort()
		local emitter = snortPuff()
		if emitter == nil then
			return
		end
		if deps.clear ~= nil then
			deps.clear(emitter)
		else
			emitter:Clear()
		end
	end

	-- The seconds into the pose at `now`.
	local function poseAgeAt(now: number): number
		return math.clamp(poseAge + poseDirection * (now - poseClock), 0, GiantFx.poseSeconds)
	end

	-- Everything that tips with the head: the head, the nightcap, both lids and the awake eyes.
	local function headPieces(): { Model }
		local found: { Model } = {}
		for _, name in HEAD_PIECE_NAMES do
			local piece = child(giant(), name)
			if piece ~= nil and piece:IsA("Model") then
				table.insert(found, piece)
			end
		end
		for _, lid in lids() do
			table.insert(found, lid)
		end
		local eyes = child(giant(), "AwakeEyes")
		if eyes ~= nil and eyes:IsA("Model") then
			table.insert(found, eyes)
		end
		return found
	end

	-- The arm's direction in the full raise: from the shoulder to the middle of the arm's bounding box, measured when the
	-- arm's start pivot was saved. The slam swing turns this direction toward the target.
	local function raisedDirection(rightArm: Model, shoulder: Vector3, raise: Vector3): Vector3?
		startPivotOf(rightArm)
		local middle: Vector3? = startMiddles[rightArm]
		if middle == nil then
			return nil
		end
		return GiantFx.armRaise(shoulder, raise, 1):PointToWorldSpace(middle) - shoulder
	end

	-- Puts the right arm `share` of the way into the waking pose (0 is at rest, 1 is the full raise), swung toward the
	-- slam that is in progress, if any, at `now`. The swing is scaled by `share`, so as the pose goes back to rest the
	-- swing goes with it. At share 0 the arm is exactly on its start pivot. If the giant's numbers are missing, the arm
	-- stays where it is.
	local function placeRightArm(share: number, now: number)
		local model = giant()
		local rightArm = arm()
		if model == nil or rightArm == nil then
			return
		end
		local shoulder: any = model:GetAttribute(SHOULDER_ATTRIBUTE)
		local raise: any = model:GetAttribute(RAISE_ATTRIBUTE)
		local start = startPivotOf(rightArm)
		if share <= 0 or typeof(shoulder) ~= "Vector3" or typeof(raise) ~= "Vector3" then
			rightArm:PivotTo(start)
			return
		end
		local raised = GiantFx.armRaise(shoulder, raise, share)
		local swing = if slamAt ~= nil then GiantFx.slamShare(now - slamAt) else 0
		local target = slamPoint
		local from = raisedDirection(rightArm, shoulder, raise)
		if swing > 0 and target ~= nil and from ~= nil then
			rightArm:PivotTo(GiantFx.slamTurn(shoulder, from, target, swing * share) * raised * start)
		else
			rightArm:PivotTo(raised * start)
		end
	end

	-- Puts the head pieces and the right arm `age` seconds into the pose, each from its start pivot. At 0 they are
	-- exactly on their start pivots. A piece whose numbers are missing on the giant stays where it is.
	local function placePose(age: number, now: number)
		local model = giant()
		if model == nil then
			return
		end
		local share = GiantFx.poseShare(age)
		local pivot: any = model:GetAttribute(HEAD_PIVOT_ATTRIBUTE)
		local tilt: any = model:GetAttribute(HEAD_TILT_ATTRIBUTE)
		local headTurn: CFrame? = nil
		if share > 0 and typeof(pivot) == "Vector3" and type(tilt) == "number" then
			headTurn = GiantFx.headTurn(pivot, tilt, share)
		end
		for _, piece in headPieces() do
			local start = startPivotOf(piece)
			piece:PivotTo(if headTurn ~= nil then headTurn * start else start)
		end
		placeRightArm(share, now)
	end

	-- Swaps the eyes: awake eyes (the parts marked ShownWhenAwake) show and the sleeping eyes hide, or the other way
	-- round. Each part's own transparency is saved the first time, and comes back when the eyes swap back.
	local function setEyes(awakeLook: boolean)
		local sleeping = child(giant(), "SleepEyes")
		if sleeping ~= nil then
			for _, part in sleeping:GetDescendants() do
				if part:IsA("BasePart") then
					if startLook[part] == nil then
						startLook[part] = part.Transparency
					end
					part.Transparency = if awakeLook then 1 else startLook[part]
				end
			end
		end
		local waking = child(giant(), "AwakeEyes")
		if waking ~= nil then
			for _, part in waking:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute(SHOWN_WHEN_AWAKE) == true then
					if startLook[part] == nil then
						startLook[part] = part.Transparency
					end
					part.Transparency = if awakeLook then 0 else startLook[part]
				end
			end
		end
	end

	-- Puts every eye part back to the transparency it had before the eyes were swapped.
	local function restoreEyes()
		for part, look in startLook do
			part.Transparency = look
		end
		table.clear(startLook)
	end

	-- True when the meter or the phase lets the Z Z Z and puffs come back: Heavy Sleep, or asleep with the meter at 75 or less.
	local function mayComeBack(): boolean
		local phase = deps.giantState:GetAttribute("Phase")
		local meter = deps.giantState:GetAttribute("Meter")
		return phase == "HeavySleep"
			or (phase == "Asleep" and type(meter) == "number" and meter <= GiantFx.comeBackAtMeter)
	end

	-- The 3 seconds of a replayed warning are over at `now`. If the meter lets them, the Z Z Z and puffs come back and the
	-- letters fade in. If not, they stay off until the meter falls (onGiantStateChanged), as after a plain 85.
	local function endReplay(now: number)
		if quiet and mayComeBack() then
			quiet = false
			fadeInAt = now
			applyState()
			paintFadeIn(0)
		end
	end

	local function disconnectStep()
		if stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end

	-- Moves everything that is moving, and finishes what is over. When nothing is left, it lets go of `step`.
	local function onStep()
		if stopped then
			return
		end
		local now = deps.now()
		if flutterAt ~= nil then
			local seconds = now - flutterAt
			local total = GiantFx.flutterSeconds * GiantFx.flutterCount
			if seconds >= total then
				flutterAt = nil
				placeLids(0)
			else
				placeLids(seconds)
			end
		end
		if snortAt ~= nil and now - snortAt >= GiantFx.snortGapSeconds then
			snortAt = nil
			snortBurst()
		end
		if fadeAt ~= nil then
			local seconds = now - fadeAt
			if seconds >= GiantFx.fadeSeconds then
				fadeAt = nil
				paintLetters(nil)
			else
				paintLetters(seconds)
			end
		end
		if bubbleUntil ~= nil then
			if now >= bubbleUntil then
				bubbleAt = nil
				bubbleUntil = nil
				applyState()
			else
				local gui = bubble()
				if gui ~= nil then
					placeBubble(gui, now)
				end
			end
		end
		if replayUntil ~= nil and now >= replayUntil then
			replayUntil = nil
			endReplay(now)
		end
		if fadeInAt ~= nil then
			local seconds = now - fadeInAt
			if seconds >= GiantFx.fadeInSeconds then
				fadeInAt = nil
				paintFadeIn(nil)
			else
				paintFadeIn(seconds)
			end
		end
		if shrinkAt ~= nil then
			if now - shrinkAt >= GiantFx.heavyShrinkSeconds then
				shrinkAt = nil
			end
			placeSign(now)
		end
		if poseDirection ~= 0 then
			local age = poseAgeAt(now)
			placePose(age, now)
			if (poseDirection > 0 and age >= GiantFx.poseSeconds) or (poseDirection < 0 and age <= 0) then
				poseAge = age
				poseClock = now
				poseDirection = 0
			end
		elseif slamAt ~= nil then
			placeRightArm(GiantFx.poseShare(poseAge), now)
		end
		if slamAt ~= nil and now - slamAt >= GiantFx.slamSeconds then
			slamAt = nil
			slamPoint = nil
		end
		if
			flutterAt == nil
			and snortAt == nil
			and fadeAt == nil
			and bubbleUntil == nil
			and replayUntil == nil
			and fadeInAt == nil
			and poseDirection == 0
			and slamAt == nil
			and shrinkAt == nil
		then
			disconnectStep()
		end
	end

	-- Listens to `step` while something plays.
	local function connectStep()
		if stepConnection == nil then
			stepConnection = deps.step:Connect(onStep)
		end
	end

	local function onWarning(mark: any, kind: any)
		-- Once he is awake (or while he settles back), the warnings are over: a late one must not start a flutter.
		if stopped or awake or poseDirection ~= 0 then
			return
		end
		-- Only a plain warning (no second value) and the free save's replay count. Anything else is ignored.
		if kind ~= nil and kind ~= Net.FreeSaveKind then
			return
		end
		local plan = GiantFx.warningPlan(mark)
		if table.find(plan, FLUTTER) ~= nil then
			flutterAt = deps.now()
		end
		if table.find(plan, FADE_LETTERS) ~= nil then
			fadeAt = deps.now()
		end
		if table.find(plan, STOP_LETTERS) ~= nil then
			quiet = true
			-- A new 85 ends a fade-in that was playing: the Z Z Z go off again with their own look.
			if fadeInAt ~= nil then
				fadeInAt = nil
				paintFadeIn(nil)
			end
			if kind == Net.FreeSaveKind then
				letters() -- saves the letters' own look before anything paints them
				replayUntil = deps.now() + Config.Meter.FreeSaveWarningSeconds
			else
				replayUntil = nil
			end
		end
		if table.find(plan, MUMBLE) ~= nil then
			-- Every 85, plain or replayed, pops the bubble in from the start.
			local popAt = deps.now()
			bubbleAt = popAt
			bubbleUntil = popAt + Bubble85.showSeconds(deps.reducedMotion())
		end
		if table.find(plan, SNORT) ~= nil then
			-- A new 85 starts the snort over: a burst now, and the second one after this one (not after the old one).
			snortAt = deps.now()
			snortBurst()
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
		local model = giant()
		local rightArm = arm()
		if model == nil or rightArm == nil then
			return point
		end
		local shoulder: any = model:GetAttribute(SHOULDER_ATTRIBUTE)
		local raise: any = model:GetAttribute(RAISE_ATTRIBUTE)
		if typeof(shoulder) ~= "Vector3" or typeof(raise) ~= "Vector3" then
			return point
		end
		local from = raisedDirection(rightArm, shoulder, raise)
		if from == nil then
			return point
		end
		local fixed = GiantFx.slamFixedAim(shoulder, model:GetPivot())
		return GiantFx.slamAim(shoulder, from, point, fixed, deps.armClear)
	end

	-- A slam is coming: the arm starts to swing toward the point. Only while he is awake. A new warning replaces the
	-- swing before it (in the game, each swing ends before the next warning).
	local function onSlamWarning(_slam: any, point: any, _landsAt: any)
		if stopped or not awake or typeof(point) ~= "Vector3" then
			return
		end
		slamAt = deps.now()
		slamPoint = slamAimAt(point)
		connectStep()
	end

	-- Starts the pose going forward (1) or back (-1) from wherever it is now.
	local function startPose(direction: number)
		local now = deps.now()
		poseAge = poseAgeAt(now)
		poseClock = now
		poseDirection = direction
		connectStep()
	end

	-- He woke: the warnings stop at once, the snort cloud is cleared, the eyes swap, the bubble, the Z Z Z and the puffs go off,
	-- and the pose starts.
	local function onWake()
		awake = true
		if flutterAt ~= nil then
			flutterAt = nil
			placeLids(0)
		end
		snortAt = nil
		clearSnort()
		if fadeAt ~= nil then
			fadeAt = nil
			paintLetters(nil)
		end
		bubbleAt = nil
		bubbleUntil = nil
		replayUntil = nil
		if fadeInAt ~= nil then
			fadeInAt = nil
			paintFadeIn(nil)
		end
		setEyes(true)
		applyState()
		startPose(1)
	end

	-- He is no longer awake: the eyes swap back at once and the pose goes back.
	local function onSleepAgain()
		awake = false
		setEyes(false)
		applyState()
		startPose(-1)
	end

	-- The Z Z Z and puffs come back when the meter has fallen to 75 while he sleeps, or when he is in Heavy Sleep.
	local function onGiantStateChanged()
		-- During the 3 seconds of a replayed warning nothing comes back; endReplay decides when they are over.
		if stopped or not quiet or replayUntil ~= nil then
			return
		end
		if mayComeBack() then
			quiet = false
			applyState()
		end
	end

	-- Puts the saved start back on every piece.
	local function restoreAll()
		disconnectStep()
		flutterAt = nil
		snortAt = nil
		fadeAt = nil
		bubbleAt = nil
		bubbleUntil = nil
		replayUntil = nil
		fadeInAt = nil
		quiet = false
		awake = false
		poseDirection = 0
		slamAt = nil
		slamPoint = nil
		placeLids(0)
		for piece, start in startPivots do
			piece:PivotTo(start)
		end
		table.clear(startMiddles)
		restoreEyes()
		paintLetters(nil)
		restoreEnabled(floatingZ())
		restoreEnabled(snorePuff())
		restoreEnabled(bubble())
		for gui in startBubble do
			restoreBubble(gui)
		end
		for gui in table.clone(bubbleWatch) do
			forgetBubble(gui)
		end
		table.clear(startBubble)
		table.clear(startPivots)
		heavy = false
		shrinkAt = nil
		for sign, size in startSignSize do
			sign.Size = size
			sign.StudsOffset = startSignOffset[sign]
		end
		table.clear(startSignSize)
		table.clear(startSignOffset)
		for puff, rate in startRate do
			puff.Rate = rate
			puff.Size = startPuffSize[puff]
		end
		table.clear(startRate)
		table.clear(startPuffSize)
	end
	trove:Add(restoreAll)

	trove:Add(deps.warning.OnClientEvent:Connect(onWarning))
	trove:Add(deps.slamWarning.OnClientEvent:Connect(onSlamWarning))
	-- A change of Phase may start or end the wake-up, and then the Z Z Z rules above are checked as well.
	local function onPhaseChanged()
		if stopped then
			return
		end
		local nowHeavy = deps.giantState:GetAttribute("Phase") == "HeavySleep"
		if nowHeavy and not heavy then
			-- Big at once, also in the middle of a shrink.
			heavy = true
			shrinkAt = nil
			applyState()
		elseif not nowHeavy and heavy then
			-- The puffs are normal at once; the Z Z Z shrink from where they are.
			heavy = false
			shrinkAt = deps.now()
			applyState()
			connectStep()
		end
		local nowAwake = deps.giantState:GetAttribute("Phase") == "Awake"
		if nowAwake and not awake then
			onWake()
		elseif not nowAwake and awake then
			onSleepAgain()
		end
		onGiantStateChanged()
	end
	trove:Add(deps.giantState:GetAttributeChangedSignal("Meter"):Connect(onGiantStateChanged))
	trove:Add(deps.giantState:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged))

	-- A player who joins in Heavy Sleep sees the big look at once.
	if deps.giantState:GetAttribute("Phase") == "HeavySleep" then
		heavy = true
		applyState()
	end

	-- A player who joins while he is awake sees the full pose at once, with no motion.
	if deps.giantState:GetAttribute("Phase") == "Awake" then
		awake = true
		setEyes(true)
		applyState()
		poseAge = GiantFx.poseSeconds
		placePose(poseAge, deps.now())
	end

	-- A part of GiantFX that streams in later gets the state it should have now.
	local function onFxAdded(_added: Instance)
		if not stopped then
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
	trove:Add(function()
		if fxConnection ~= nil then
			fxConnection:Disconnect()
			fxConnection = nil
		end
	end)
	local existing = fx()
	if existing ~= nil then
		watchFx(existing)
	else
		trove:Add(deps.world.ChildAdded:Connect(function(added: Instance)
			if added.Name == "GiantFX" then
				watchFx(added)
				onFxAdded(added)
			end
		end))
	end

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			trove:Destroy()
		end,
		savedBubbleCount = function(): number
			local count = 0
			for _ in startBubble do
				count += 1
			end
			return count
		end,
	}
end

return GiantFx
