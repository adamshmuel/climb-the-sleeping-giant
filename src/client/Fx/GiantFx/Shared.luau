--!strict
-- What more than one part of GiantFx needs: the shapes it takes, the shared names and numbers, the pure `smooth`, and the state `start` keeps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Config = require(ReplicatedStorage.Shared.Config)
local SlamFx = require(script.Parent.Parent.SlamFx)

local Shared = {}

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

-- The Warning remote, as far as this module uses it: it fires the mark (60 or 85), and at a free save (85, Net.FreeSaveKind).
export type WarningLike = { OnClientEvent: SignalLike }

-- What the Zs on the meter should show: the world Z Z Z's look now (`hidden` is the 85 warning and when he is awake).
export type Sign = "shown" | "faded" | "hidden" | "heavy"

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
	-- Told the sign at the start and each time it changes, at the moments the world Z Z Z change (the Zs on the meter).
	onSignsChanged: ((sign: Sign) -> ())?,
	-- Plays a sound by name (`at` is the place it comes from, or nil for no place). If left out, nothing plays.
	playSound: ((name: string, at: Vector3?) -> ())?,
}

-- What start gives back: `stop` puts every piece back as it was and disconnects everything.
export type Handle = {
	stop: () -> (),
	-- How many bubbles have their first look saved right now (for tests: a bubble that left the game has none).
	savedBubbleCount: () -> number,
}

-- How the bubble was before this module changed it, saved the first time it is placed (a bubble that streams out
-- and back in is a new instance, so it is saved again).
export type BubbleStart = {
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

-- Everything `start` keeps while it runs. Every part reads and writes this one table.
export type State = {
	trove: typeof(Trove.new()),
	stopped: boolean,

	-- Where each moved piece started (saved the first time it is seen), and the flags and transparencies that were
	-- there before this module changed them.
	startPivots: { [Model]: CFrame },
	-- The middle of each model's bounding box when its start pivot was saved (the arm's is where the swing aims from).
	startMiddles: { [Model]: Vector3 },
	startSliver: { [Instance]: number },
	startEnabled: { [Instance]: boolean },
	startLetter: { [Instance]: number },
	startOutline: { [Instance]: number },
	-- How the Z Z Z sign and the snore puff were before Heavy Sleep changed them.
	startSignSize: { [BillboardGui]: UDim2 },
	startSignOffset: { [BillboardGui]: Vector3 },
	startRate: { [ParticleEmitter]: number },
	startPuffSize: { [ParticleEmitter]: NumberSequence },
	-- How see-through each eye part was before the eyes were swapped.
	startLook: { [BasePart]: number },

	-- What is playing now: the time each started, or nil.
	flutterAt: number?,
	fadeAt: number?,
	-- When the snort started: its second burst is still to come until this is nil.
	snortAt: number?,
	-- The 85 bubble: when it popped in, and when it goes off (after its fade), or nil.
	bubbleAt: number?,
	bubbleUntil: number?,
	-- True from an 85 warning until the Z Z Z and puffs may come back.
	quiet: boolean,
	-- After a replayed 85: when its 3 seconds are over (the Z Z Z stay off until then), or nil. And when the Z Z Z came
	-- back after it, while the letters fade in, or nil.
	replayUntil: number?,
	fadeInAt: number?,
	stepConnection: RBXScriptConnection?,
	-- True from the moment Phase turned Awake until it left Awake.
	awake: boolean,
	-- The waking pose: how many seconds into it it was at `poseClock` (0 is at rest, poseSeconds is the full pose), and
	-- whether it is going forward (1), going back (-1) or standing still (0).
	poseAge: number,
	poseClock: number,
	poseDirection: number,
	-- The swing in progress: when its SlamWarning arrived (by deps.now) and where the slam lands, or nil.
	slamAt: number?,
	slamPoint: Vector3?,
	-- True from the moment Phase turned HeavySleep until it left. After it, the Z Z Z shrink: `shrinkAt` is when Heavy
	-- Sleep ended (by deps.now), or nil when they are not shrinking.
	heavy: boolean,
	shrinkAt: number?,
	-- The face on waking: when the "!" and the pop started (by deps.now), or nil. And how the "!" looked before it
	-- was shown (each piece's transparency and the gui's size), so the fade and the end can put it back.
	faceAt: number?,
	faceLook: { [Instance]: number },
	faceSize: { [BillboardGui]: UDim2 },

	-- How each bubble was before this module changed it.
	startBubble: { [BillboardGui]: BubbleStart },
	-- Watching each saved bubble, so its entry goes when the bubble leaves the game (it streams out on a phone).
	bubbleWatch: { [BillboardGui]: { RBXScriptConnection } },
}

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

-- Smooth start and finish: 0 to 1 over `t` from 0 to 1.
local function smooth(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- The attributes on the giant that say where and how far the pieces turn.
local SHOULDER_ATTRIBUTE = "Awake_RightShoulderPivot"
local RAISE_ATTRIBUTE = "Awake_RightArmRaiseDegXZ"

Shared.flutterSeconds = 0.5 -- one flutter: 0.25 s up, 0.25 s down
Shared.flutterCount = 2
Shared.snortPuffs = 20 -- the puffs in each of the two snort bursts (style guide, "The snort")
Shared.snortGapSeconds = 0.5 -- the second burst comes this long after the first
Shared.fadeSeconds = 2 -- the Z Z Z fade, all in all
Shared.fadeEdgeSeconds = 0.2 -- the way down to half and the way back
Shared.fadeTo = 0.5 -- half see-through
Shared.fadeInSeconds = 0.2 -- the letters of the Z Z Z come back from fully see-through over this long, after a replay
Shared.comeBackAtMeter = 75
Shared.poseSeconds = 0.5 -- the fist raise on waking, and the head tip and the fist on going back to sleep
-- The head tips forward this fast on waking (spec Rule 66); it goes back over poseSeconds. Never a second number.
Shared.headTipSeconds = Config.Wake.HeadTipSeconds
-- Heavy Sleep: how much bigger the Z Z Z sign is (designer: 2.5 times, because the style guide asks for "much bigger").
Shared.heavyLetterScale = 2.5
-- How many times as many snore puffs come per second (spec: 3 times as many).
Shared.heavyPuffRateScale = 3
-- How much bigger each snore puff is (art list: 1.6 times).
Shared.heavyPuffSizeScale = 1.6
-- How long the Z Z Z take to shrink back when Heavy Sleep ends (the same 0.5 s as the waking pose).
Shared.heavyShrinkSeconds = 0.5
-- The corner of the sign that stays put when it grows, as a direction from its middle: left (-1) and bottom (-1), so
-- the letters grow up and to the right and never down over his face.
Shared.heavyFixedCorner = Vector2.new(-1, -1)
Shared.slamSwingSeconds = 0.5 -- the arm swings out toward the target, and later back, over this long
-- The arm holds out until the fist starts to lift (the warning time plus the time the fist stays down), then comes
-- back. The whole swing lasts until then plus the swing back.
Shared.slamHoldUntil = Config.Wake.SlamWarningSeconds + SlamFx.FIST_DOWN_SECONDS
Shared.slamSeconds = Shared.slamHoldUntil + Shared.slamSwingSeconds

-- How long his arm is, in studs. It never reaches the target (the separate fist does the slam), so this is how far from
-- his shoulder the arm's path is checked against his body, and how far the fixed pose is from the shoulder.
Shared.armLength = 50
-- The fixed pose of the slam swing, for targets the arm can't point at without going through his body: this many degrees
-- raised forward from hanging straight down, then this many degrees out to his right.
Shared.slamFixedForwardDegrees = 70
Shared.slamFixedOutDegrees = 25

Shared.FLUTTER = FLUTTER
Shared.FADE_LETTERS = FADE_LETTERS
Shared.STOP_LETTERS = STOP_LETTERS
Shared.MUMBLE = MUMBLE
Shared.SNORT = SNORT
Shared.PLAN_60 = PLAN_60
Shared.PLAN_85 = PLAN_85
Shared.PLAN_NONE = PLAN_NONE
Shared.smooth = smooth
Shared.SHOULDER_ATTRIBUTE = SHOULDER_ATTRIBUTE
Shared.RAISE_ATTRIBUTE = RAISE_ATTRIBUTE

return Shared
