--!strict
-- Every game number from spec section 5 ("Numbers"), in one place.
-- The table is frozen all the way down, so nothing can change a number while the game runs.

export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type ZoneName = "Meadow" | "Boots" | "Belly" | "Beard" | "Nightcap"
-- The giant's phases. The sleep meter only moves while he is Asleep.
export type Phase = "Asleep" | "Awake" | "HeavySleep"

export type RarityConfig = {
	RefillSeconds: number,
	CarrySlowdown: number,
	CarryNoise: number,
	-- Eggs of this rank waiting at once, and the nests they can sit on (spec 5 section 5, rows "Egg slots per rank"
	-- and "Nests per rank"; Rule 71).
	Slots: number,
	Nests: number,
}

-- One way up from the gardens: its name, the gardens that use it, and each garden's walk limit (same order).
export type WayUpConfig = {
	Name: string,
	Gardens: { number },
	WalkLimitSeconds: { number },
}

export type Config = {
	Movement: {
		WalkSpeed: number,
		TiptoeSpeedFactor: number,
		ClimbSpeedFactor: number, -- Roblox climbs at 70% of WalkSpeed (docs, Humanoid.Climbing)
	},
	Grab: {
		HoldSeconds: number,
		ReachStuds: number,
		ReachToleranceStuds: number,
	},
	RarityOrder: { RarityName },
	Rarity: {
		Common: RarityConfig,
		Uncommon: RarityConfig,
		Rare: RarityConfig,
		Epic: RarityConfig,
		Legendary: RarityConfig,
	},
	Noise: {
		WalkPerSecond: number,
		TiptoeFactor: number,
		JumpBurst: number,
		LadderMultiplier: number, -- spec 3 Rule 39: climbing a ladder is a little louder
		-- Quiet ways down (spec core-heist Rule 8, "The set ways down must not thud"): how near a fall must start to a
		-- ladder, and how near the boot ladder's grass foot it must end. Play confirms them (plan 5 Task 26).
		QuietDrop: {
			TrussNear: number,
			TopNear: number,
			FootStuds: number,
		},
		ZoneMultiplier: {
			Meadow: number,
			Boots: number,
			Belly: number,
			Beard: number,
			Nightcap: number,
		},
	},
	Meter: {
		Max: number,
		DrainPerPlayer: number,
		SoloDrain: number,
		WarningMarks: { number },
		WarningRearmDrop: number,
		FreeSaveMeter: number,
		FreeSaveWarningSeconds: number,
	},
	Wake: {
		AwakeSeconds: number,
		FirstSlamWarningAt: number,
		SlamInterval: number,
		SlamWarningSeconds: number,
		SlamCircleDiameter: number,
		BannerSeconds: number,
		HeavySleepSeconds: number,
		ShakeStuds: number,
		ShakeSeconds: number,
		BounceCameraUpDegrees: number,
	},
	Home: {
		EggsShown: number,
		CardSeconds: number,
	},
	Labels: {
		HideBeyondStuds: number,
		MaxWidthPx: number,
		MaxHeightPx: number,
		MaxTextPx: number,
	},
	Spawn: {
		StudsInFrontOfGate: number,
		CameraTiltUpDegrees: number,
		EaseBackSeconds: number,
		CameraRaiseStuds: number,
		EggOffFacingDegrees: number,
	},
	Footprints: {
		Spacing: number,
		UpdateSeconds: number,
		Lift: number,
		RampLift: number,
		MaxShown: number,
		LadderStop: number,
	},
	Stuck: {
		BodyWidth: number,
		BodyHeight: number,
		ScanSpacing: number,
		ScanMargin: number,
		ScanSeconds: number,
		SafeSaveSeconds: number,
		RescueDistance: number,
		ResetCooldownSeconds: number,
		LoopMoves: number,
		LoopSeconds: number,
		StuckSeconds: number,
		StuckDistance: number,
		FallGraceSeconds: number,
		PressChangesPerSecond: number,
	},
	Tick: {
		Seconds: number,
	},
	-- The four wooden ladders (Rule 80): the only places the Climbing state is allowed. Models: names under
	-- World.WalkSurfaces. NearStuds: how close to a ladder's Climb part a body counts as at it.
	Ladders: {
		Models: { string },
		NearStuds: number,
	},
	WaysUp: { WayUpConfig },
	-- Egg nests: every number of spec 5 section 5 that the nest placement and its checks read (Rules 71 to 82).
	Nests: {
		EggSpacing: number,
		MeadowSpacing: number,
		PlayerDistance: number,
		RetrySeconds: number,
		TwinDistance: number,
		EyeDistance: number,
		SeamDegrees: number,
		SeamMatch: number,
		WalkSurfaceBelow: number,
		WalkSurfaceAbove: number,
		SeamHeight: number,
		ClimbableHeight: number,
		BeamFadeSeconds: number,
		UnlockSeconds: number,
		ArmReturnSeconds: number,
		SlideTipSeconds: number,
		SlideDrop: number,
		Jump: { Up: number, Across: number, BodyHeight: number },
		RareEggOne: string,
		PostClear: { HalfBase: number, Sideways: number, Vertical: number },
	},
	Ranks: {
		VisibleBelow: number,
		FloatLimit: number,
		SinkNestUpright: number,
		SinkNestLeaning: number,
		SinkEggUpright: number,
		SinkEggLeaning: number,
		EggInNest: number,
		BodyBeamStuds: number,
		BodyZones: { [string]: boolean },
		BandEdges: { Rare: number, Epic: number, Legendary: number },
		EdgeWarning: number,
		TiptoeLimit: number,
		ColourWords: { [RarityName]: string },
	},
}

-- Freezes a table and every table inside it.
local function deepFreeze<T>(value: T): T
	if type(value) == "table" then
		for _, child in value :: any do
			deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

local config: Config = {
	Movement = {
		WalkSpeed = 16,
		TiptoeSpeedFactor = 0.6,
		ClimbSpeedFactor = 0.7, -- Roblox climbs at 70% of WalkSpeed (docs, Humanoid.Climbing)
	},
	Grab = { HoldSeconds = 1, ReachStuds = 8, ReachToleranceStuds = 2 },
	RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
	Rarity = {
		Common = { RefillSeconds = 10, CarrySlowdown = 0, CarryNoise = 1.25, Slots = 8, Nests = 16 },
		Uncommon = { RefillSeconds = 30, CarrySlowdown = 0.05, CarryNoise = 1.5, Slots = 4, Nests = 8 },
		Rare = { RefillSeconds = 60, CarrySlowdown = 0.1, CarryNoise = 2.5, Slots = 4, Nests = 6 },
		-- Epic and Legendary carry like a Rare (spec 4, Rule 49).
		Epic = { RefillSeconds = 60, CarrySlowdown = 0.1, CarryNoise = 2.5, Slots = 2, Nests = 4 },
		Legendary = { RefillSeconds = 60, CarrySlowdown = 0.1, CarryNoise = 2.5, Slots = 1, Nests = 4 },
	},
	Noise = {
		WalkPerSecond = 4,
		TiptoeFactor = 0.2,
		JumpBurst = 20,
		LadderMultiplier = 1.2,
		QuietDrop = { TrussNear = 1.5, TopNear = 2, FootStuds = 8 },
		ZoneMultiplier = { Meadow = 0, Boots = 1, Belly = 1.5, Beard = 2, Nightcap = 3 },
	},
	Meter = {
		Max = 100,
		DrainPerPlayer = 1,
		SoloDrain = 1.5, -- V2: one player alone drains faster (spec 1, section 5)
		WarningMarks = { 60, 85 },
		WarningRearmDrop = 10,
		FreeSaveMeter = 70, -- where a free save drops the meter (spec 1, Rule 11)
		FreeSaveWarningSeconds = 3, -- how long the replayed 85% warning shows; a pass of 85 meanwhile fires nothing (Rule 17)
	},
	Wake = {
		AwakeSeconds = 15,
		FirstSlamWarningAt = 1.0,
		SlamInterval = 2.5,
		SlamWarningSeconds = 1.5,
		SlamCircleDiameter = 30,
		BannerSeconds = 3,
		HeavySleepSeconds = 45,
		ShakeStuds = 0.5,
		ShakeSeconds = 0.5,
		-- A bounced player's camera pitch while floating, measured from level (up is positive). The spawn view's is 21.
		BounceCameraUpDegrees = 30,
	},
	Home = { EggsShown = 12, CardSeconds = 3 },
	Labels = { HideBeyondStuds = 75, MaxWidthPx = 130, MaxHeightPx = 36, MaxTextPx = 30 },
	-- CameraTiltUpDegrees: how far the camera tilts up from Roblox's normal view at spawn. EaseBackSeconds: how long it
	-- takes to ease back to the normal view, once the player's first move. CameraRaiseStuds: how much higher the camera
	-- sits during the spawn view. EggOffFacingDegrees: the spawn view turns the player until the first egg is at least
	-- this many degrees off the way they face.
	Spawn = {
		StudsInFrontOfGate = 18,
		CameraTiltUpDegrees = 36,
		EaseBackSeconds = 0.6,
		CameraRaiseStuds = 1.5,
		EggOffFacingDegrees = 20,
	},
	-- Spacing: studs between footprints. UpdateSeconds: how often the way is worked out again. Lift: studs between the
	-- ground and the bottom of a footprint. RampLift: the same gap on the boot-ramp planks, so the cleats (cross-strips
	-- 0.3 studs tall) don't cut through the footprints. MaxShown: how many copies are kept (no way needs more than 70).
	-- LadderStop: studs before a ladder's foot point where a walk run of footprints stops. The foot is 1 stud out from
	-- the bottom rung and the run-in point 3 out (tools/world/08-route/RoutePlaces.luau, "the ways up"), so the last
	-- footprint is 3 studs in front of the rung (spec 3 Rule 42: 2 to 4).
	Footprints = {
		Spacing = 3.6,
		UpdateSeconds = 0.25,
		Lift = 0.05,
		RampLift = 0.35,
		MaxShown = 100,
		LadderStop = 2,
	},
	-- Spec section 5, "Scan body size": the solid part of a standard player's body, measured in Play on 2026-10-19 (R15,
	-- every body scale 1). Only HumanoidRootPart (2 x 2 x 1), UpperTorso and LowerTorso collide, on the Server and the
	-- Client alike; the head, arms, hands, legs and feet do not. Together they are 2.0 wide, 1.05 to 1.09 deep and
	-- 4.225 tall from the ground (the ground is 3.225 below the root part's middle). BodyWidth is the larger of width
	-- and depth, because a player turns to face where it walks, so either side can lead. Both are rounded up to 0.1.
	-- ScanSpacing (spec section 5, "Scan grid spacing"): studs between the spots of the walk map. 2 is the body's
	-- width, so two next spots' bodies touch and nothing narrower than a body slips between them. If a full scan runs
	-- over the 2-minute limit, product's trigger is 3.
	-- ScanMargin: studs of meadow the stuck scan covers around the giant's box.
	-- ScanSeconds: the scan's time limit, build plus search (spec section 5, "Scan grid spacing").
	-- SafeSaveSeconds (spec section 5, "Safe spot saved every"): seconds between a player's safe-spot checks.
	-- RescueDistance (spec section 5, "Rescue distance"): studs a rescue spot must be from where the player is stuck.
	-- ResetCooldownSeconds (Rule 25): the shortest time between two Reset requests from one player.
	-- LoopMoves and LoopSeconds (Rule 29): this many moves back within this many seconds send the player home instead.
	-- StuckSeconds (spec section 5, "Stuck time"): seconds of pressing to move without getting anywhere before a rescue.
	-- StuckDistance (spec section 5, "Stuck distance"): the body moving less than this many studs in that time is stuck.
	-- FallGraceSeconds (spec section 5, "Fall grace"): a fall shorter than this doesn't start the stuck time over.
	-- PressChangesPerSecond (spec section 5, "Pressing changes"): how many times a second one player may tell the
	-- server they started or stopped pressing to move.
	Stuck = {
		BodyWidth = 2,
		BodyHeight = 4.3,
		ScanSpacing = 2,
		ScanMargin = 10,
		ScanSeconds = 120,
		SafeSaveSeconds = 0.5,
		RescueDistance = 4,
		ResetCooldownSeconds = 2,
		LoopMoves = 3,
		LoopSeconds = 30,
		StuckSeconds = 3,
		StuckDistance = 2,
		FallGraceSeconds = 0.25,
		PressChangesPerSecond = 10,
	},
	Tick = { Seconds = 0.1 },
	Ladders = {
		Models = { "BeardLadder", "CapLadder", "BootLadder_Left", "BootLadder_Right" },
		NearStuds = 2, -- at walk speed 16 one 0.1 s tick moves 1.6 studs, so 2 is a margin a player can't feel
	},
	-- The four ways up from the gardens to the first boot top (Rule 35 and section 5, "The four ways up and their
	-- gardens"), in garden order. Name: the value of the route points' WayUpFoot and WayUpTop attributes. Gardens: the
	-- gardens that use it. WalkLimitSeconds: the longest walk from each of those gardens to the way up's foot (one number
	-- per garden, same order).
	WaysUp = {
		{ Name = "Left boot ladder", Gardens = { 1, 2, 3 }, WalkLimitSeconds = { 7.5, 5, 4 } },
		{ Name = "Left ramp", Gardens = { 4 }, WalkLimitSeconds = { 4 } },
		{ Name = "Right ramp", Gardens = { 5 }, WalkLimitSeconds = { 4 } },
		{ Name = "Right boot ladder", Gardens = { 6, 7, 8 }, WalkLimitSeconds = { 4, 5, 7.5 } },
	},
	Nests = {
		EggSpacing = 6, -- studs between a new egg on him and every waiting egg (row "Egg spacing")
		MeadowSpacing = 8, -- studs between a garden's 2 meadow nests and other gardens' meadow nests (row "Egg spacing")
		PlayerDistance = 15, -- studs between a new egg on him and every player (row "Player distance")
		RetrySeconds = 1, -- seconds between tries when no nest is allowed (row "Retry when no nest is allowed")
		TwinDistance = 2, -- studs a twin may be from the exact mirror spot (row "Twin distance")
		EyeDistance = 10, -- studs a nest keeps from his eyes (row "Spacing from his eyes")
		SeamDegrees = 65, -- the walk area is under this many degrees from level (row "Seam angle")
		SeamMatch = 1, -- studs the walk area's edge may be from the seam's stitches (row "Seam match")
		WalkSurfaceBelow = 0.2, -- studs the walk surface may sit below the visible surface (row "Walk surface over what you see")
		WalkSurfaceAbove = 0.7, -- studs the walk surface may sit above the visible surface (row "Walk surface over what you see")
		SeamHeight = 12, -- studs the walk area's edge sits above every jump surface in reach (row "Seam height")
		ClimbableHeight = 15, -- studs a climbable part's lowest point sits above every jump surface (row "Climbable-part height")
		BeamFadeSeconds = 0.3, -- seconds the right cuff beam fades out and back in (row "Right cuff beam while he's awake")
		UnlockSeconds = 0.5, -- seconds after the phase leaves Awake before the right cuff nests unlock (plan 5 Decisions)
		ArmReturnSeconds = 0.5, -- seconds his arm takes to swing back; plan 6 may raise it (plan 5 Decisions)
		SlideTipSeconds = 3, -- seconds the slide tip shows, once per session (row "Slide tip")
		SlideDrop = 5, -- studs a fall must end lower than it began to count as a slide (Rule 84; plan 5 Decisions)
		-- A jump reaches 9 studs up and 10 across, from a body 5 studs tall (plan 5 Decisions row "The jump reach").
		Jump = { Up = 9, Across = 10, BodyHeight = 5 },
		RareEggOne = "Nest_LowerBelly_Left", -- the nest of Rare egg 1 (Rule 45; plan 5 Decisions)
		-- A meadow nest is "not clear" when a player root is within HalfBase + Sideways studs flat or Vertical studs up
		-- or down (Rule 85; fix 2 Decisions "Clear check"). HalfBase is the post's half base: 0.4 of the Common egg's
		-- width (measured 5.46 studs in Step 3, so 2.185, rounded to 2.2). tools/world/21-nests.luau builds the posts from it.
		PostClear = { HalfBase = 2.2, Sideways = 1.5, Vertical = 6 },
	},
	-- What an egg or nest sits on (spec 4 Rule 59 and section 5 rows "Visible surface", "Float limit", "Sink limit").
	Ranks = {
		VisibleBelow = 0.5, -- a part at or above this see-through share (0 to 1) is not a visible surface
		FloatLimit = 0.2, -- studs an egg or nest may sit above its visible surface
		SinkNestUpright = 0.3, -- studs an upright nest may sink into its surface
		SinkNestLeaning = 1.5, -- studs a leaning nest may sink into its surface
		SinkEggUpright = 0.3, -- studs an upright bare egg may sink into its surface
		SinkEggLeaning = 1, -- studs a leaning bare egg may sink into its surface
		EggInNest = 0.2, -- studs an egg's bottom may be off its nest's seat (checked in Step 6b)
		BodyBeamStuds = 10, -- studs: length of the beam of a waiting egg on his body (spec 4 section 6)
		BodyZones = { Belly = true, Beard = true, Nightcap = true }, -- the zones that are his body; boots and meadow keep V1's beam
		BandEdges = { Rare = 40, Epic = 85, Legendary = 130 }, -- the score where each rank starts (spec 4 Rule 50); an edge takes the higher rank
		EdgeWarning = 3, -- a score this close to an edge, above or below, is flagged as a close call (Rule 56)
		TiptoeLimit = 60, -- a Tiptoe peak at or over this fails the nest (Rule 54)
		ColourWords = {
			Common = "cream white",
			Uncommon = "leaf green",
			Rare = "sky blue",
			Epic = "purple",
			Legendary = "gold",
		}, -- the glow colour of each rank, in words the report prints (Rule 51)
	},
}

return deepFreeze(config)
