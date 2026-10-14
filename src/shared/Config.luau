--!strict
-- Every game number from spec section 5 ("Numbers"), in one place.
-- The table is frozen all the way down, so nothing can change a number while the game runs.

export type RarityName = "Common" | "Uncommon" | "Rare"
export type ZoneName = "Meadow" | "Boots" | "Belly" | "Beard" | "Nightcap"
-- The giant's phases. The sleep meter only moves while he is Asleep.
export type Phase = "Asleep" | "Awake" | "HeavySleep"

export type RarityConfig = {
	Spots: number,
	RefillSeconds: number,
	CarrySlowdown: number,
	CarryNoise: number,
}

export type Config = {
	Movement: {
		WalkSpeed: number,
		TiptoeSpeedFactor: number,
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
	},
	Noise: {
		WalkPerSecond: number,
		TiptoeFactor: number,
		JumpBurst: number,
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
		WarningMarks: { number },
		WarningRearmDrop: number,
		NewPlayerCap: number,
		NewPlayerEggsNeeded: number,
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
	},
	Tick: {
		Seconds: number,
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
	Movement = { WalkSpeed = 16, TiptoeSpeedFactor = 0.6 },
	Grab = { HoldSeconds = 1, ReachStuds = 8, ReachToleranceStuds = 2 },
	RarityOrder = { "Common", "Uncommon", "Rare" },
	Rarity = {
		Common = { Spots = 8, RefillSeconds = 10, CarrySlowdown = 0, CarryNoise = 1.25 },
		Uncommon = { Spots = 4, RefillSeconds = 30, CarrySlowdown = 0.05, CarryNoise = 1.5 },
		Rare = { Spots = 4, RefillSeconds = 60, CarrySlowdown = 0.1, CarryNoise = 2.5 },
	},
	Noise = {
		WalkPerSecond = 4,
		TiptoeFactor = 0.2,
		JumpBurst = 20,
		ZoneMultiplier = { Meadow = 0, Boots = 1, Belly = 1.5, Beard = 2, Nightcap = 3 },
	},
	Meter = {
		Max = 100,
		DrainPerPlayer = 1,
		WarningMarks = { 60, 85 },
		WarningRearmDrop = 10,
		NewPlayerCap = 84,
		NewPlayerEggsNeeded = 2,
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
	Footprints = { Spacing = 3.6, UpdateSeconds = 0.25, Lift = 0.05, RampLift = 0.35, MaxShown = 100 },
	Tick = { Seconds = 0.1 },
}

return deepFreeze(config)
