--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)

local function isDeepFrozen(value: any): boolean
	if type(value) ~= "table" then
		return true
	end
	if not table.isfrozen(value) then
		return false
	end
	for _, child in value do
		if not isDeepFrozen(child) then
			return false
		end
	end
	return true
end

describe("Config", function()
	it("walking speed is Roblox's normal 16", function()
		expect(Config.Movement.WalkSpeed).toBe(16)
	end)

	it("Tiptoe speed is 60%", function()
		expect(Config.Movement.TiptoeSpeedFactor).toBe(0.6)
	end)

	it("grabbing takes a 1 second hold within 8 studs, plus 2 studs for lag", function()
		expect(Config.Grab).toEqual({ HoldSeconds = 1, ReachStuds = 8, ReachToleranceStuds = 2 })
	end)

	it("rarities are listed Common, Uncommon, Rare", function()
		expect(Config.RarityOrder).toEqual({ "Common", "Uncommon", "Rare" })
	end)

	it("egg spots are 8 Common, 4 Uncommon and 4 Rare", function()
		expect(Config.Rarity.Common.Spots).toBe(8)
		expect(Config.Rarity.Uncommon.Spots).toBe(4)
		expect(Config.Rarity.Rare.Spots).toBe(4)
	end)

	it("refill times are 10, 30 and 60 seconds", function()
		expect(Config.Rarity.Common.RefillSeconds).toBe(10)
		expect(Config.Rarity.Uncommon.RefillSeconds).toBe(30)
		expect(Config.Rarity.Rare.RefillSeconds).toBe(60)
	end)

	it("carrying slows you 0%, 5% and 10%", function()
		expect(Config.Rarity.Common.CarrySlowdown).toBe(0)
		expect(Config.Rarity.Uncommon.CarrySlowdown).toBe(0.05)
		expect(Config.Rarity.Rare.CarrySlowdown).toBe(0.1)
	end)

	it("carrying multiplies noise by 1.25, 1.5 and 2.5", function()
		expect(Config.Rarity.Common.CarryNoise).toBe(1.25)
		expect(Config.Rarity.Uncommon.CarryNoise).toBe(1.5)
		expect(Config.Rarity.Rare.CarryNoise).toBe(2.5)
	end)

	it("walking makes 4 noise a second and Tiptoe cuts it to 20%", function()
		expect(Config.Noise.WalkPerSecond).toBe(4)
		expect(Config.Noise.TiptoeFactor).toBe(0.2)
	end)

	it("a jump landing makes a burst of 20 noise", function()
		expect(Config.Noise.JumpBurst).toBe(20)
	end)

	it("zone noise multipliers run from Meadow 0 (silent) to Nightcap 3", function()
		expect(Config.Noise.ZoneMultiplier).toEqual({ Meadow = 0, Boots = 1, Belly = 1.5, Beard = 2, Nightcap = 3 })
	end)

	it("the meter runs from 0 to 100", function()
		expect(Config.Meter.Max).toBe(100)
	end)

	it("the drain is 1 per player, with no minimum", function()
		expect(Config.Meter.DrainPerPlayer).toBe(1)
		expect((Config.Meter :: any).DrainMinimum).toBe(nil)
	end)

	it("warnings come at 60 and 85 and re-arm 10 points lower", function()
		expect(Config.Meter.WarningMarks).toEqual({ 60, 85 })
		expect(Config.Meter.WarningRearmDrop).toBe(10)
	end)

	it("the new-player limit is 84 until 2 eggs are home", function()
		expect(Config.Meter.NewPlayerCap).toBe(84)
		expect(Config.Meter.NewPlayerEggsNeeded).toBe(2)
	end)

	it("slams come every 2.5 s with a 1.5 s warning", function()
		expect(Config.Wake.SlamInterval).toBe(2.5)
		expect(Config.Wake.SlamWarningSeconds).toBe(1.5)
	end)

	it("the first slam warning comes 1 s after waking", function()
		expect(Config.Wake.FirstSlamWarningAt).toBe(1)
	end)

	it("the giant stays awake 15 s and the red circle is 30 studs wide", function()
		expect(Config.Wake.AwakeSeconds).toBe(15)
		expect(Config.Wake.SlamCircleDiameter).toBe(30)
	end)

	it("the banner shows 3 s and Heavy Sleep lasts 45 s", function()
		expect(Config.Wake.BannerSeconds).toBe(3)
		expect(Config.Wake.HeavySleepSeconds).toBe(45)
	end)

	it("the wake-up camera shake is 0.5 studs for 0.5 s", function()
		expect(Config.Wake.ShakeStuds).toBe(0.5)
		expect(Config.Wake.ShakeSeconds).toBe(0.5)
	end)

	it("a bounced player's camera looks 30 degrees up while floating", function()
		expect(Config.Wake.BounceCameraUpDegrees).toBe(30)
	end)

	it("a garden shows up to 12 eggs and the card shows 3 s", function()
		expect(Config.Home.EggsShown).toBe(12)
		expect(Config.Home.CardSeconds).toBe(3)
	end)

	it("labels hide beyond 75 studs and stay within 130 x 36 px with text up to 30 px", function()
		expect(Config.Labels).toEqual({ HideBeyondStuds = 75, MaxWidthPx = 130, MaxHeightPx = 36, MaxTextPx = 30 })
	end)

	it("players spawn 18 studs from their gate, camera up 36 degrees, easing back in 0.6 s", function()
		expect(Config.Spawn.StudsInFrontOfGate).toBe(18)
		expect(Config.Spawn.CameraTiltUpDegrees).toBe(36)
		expect(Config.Spawn.EaseBackSeconds).toBe(0.6)
	end)

	it("the spawn view raises the camera 1.5 studs and keeps the first egg at least 20 degrees off", function()
		expect(Config.Spawn.CameraRaiseStuds).toBe(1.5)
		expect(Config.Spawn.EggOffFacingDegrees).toBe(20)
	end)

	it("the spawn numbers are exactly these five", function()
		expect(Config.Spawn).toEqual({
			StudsInFrontOfGate = 18,
			CameraTiltUpDegrees = 36,
			EaseBackSeconds = 0.6,
			CameraRaiseStuds = 1.5,
			EggOffFacingDegrees = 20,
		})
	end)

	it("footprints: 3.6 apart, redone every 0.25 s, lifted 0.05 (0.35 on ramp planks), 100 at most", function()
		expect(Config.Footprints).toEqual({
			Spacing = 3.6,
			UpdateSeconds = 0.25,
			Lift = 0.05,
			RampLift = 0.35,
			MaxShown = 100,
		})
	end)

	it("the game loop ticks every 0.1 s", function()
		expect(Config.Tick.Seconds).toBe(0.1)
	end)

	it("Config can't be changed while the game runs", function()
		expect(function()
			(Config.Meter :: any).Max = 5
		end).toThrow()
	end)

	it("every table inside Config is frozen", function()
		expect(isDeepFrozen(Config)).toBe(true)
	end)
end)
