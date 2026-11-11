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

	it("Roblox climbs at 70% of WalkSpeed", function()
		expect(Config.Movement.ClimbSpeedFactor).toBe(0.7)
	end)

	it("grabbing takes a 1 second hold within 8 studs, plus 2 studs for lag", function()
		expect(Config.Grab).toEqual({ HoldSeconds = 1, ReachStuds = 8, ReachToleranceStuds = 2 })
	end)

	it("rarities are listed Common, Uncommon, Rare, Epic, Legendary", function()
		expect(Config.RarityOrder).toEqual({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })
	end)

	it("refill times are 10, 30, 60, 60 and 60 seconds", function()
		expect(Config.Rarity.Common.RefillSeconds).toBe(10)
		expect(Config.Rarity.Uncommon.RefillSeconds).toBe(30)
		expect(Config.Rarity.Rare.RefillSeconds).toBe(60)
		expect(Config.Rarity.Epic.RefillSeconds).toBe(60)
		expect(Config.Rarity.Legendary.RefillSeconds).toBe(60)
	end)

	it("carrying slows you 0%, 5%, 10%, 10% and 10%", function()
		expect(Config.Rarity.Common.CarrySlowdown).toBe(0)
		expect(Config.Rarity.Uncommon.CarrySlowdown).toBe(0.05)
		expect(Config.Rarity.Rare.CarrySlowdown).toBe(0.1)
		expect(Config.Rarity.Epic.CarrySlowdown).toBe(0.1)
		expect(Config.Rarity.Legendary.CarrySlowdown).toBe(0.1)
	end)

	it("carrying multiplies noise by 1.25, 1.5, 2.5, 2.5 and 2.5", function()
		expect(Config.Rarity.Common.CarryNoise).toBe(1.25)
		expect(Config.Rarity.Uncommon.CarryNoise).toBe(1.5)
		expect(Config.Rarity.Rare.CarryNoise).toBe(2.5)
		expect(Config.Rarity.Epic.CarryNoise).toBe(2.5)
		expect(Config.Rarity.Legendary.CarryNoise).toBe(2.5)
	end)

	it("walking makes 4 noise a second and Tiptoe cuts it to 20%", function()
		expect(Config.Noise.WalkPerSecond).toBe(4)
		expect(Config.Noise.TiptoeFactor).toBe(0.2)
	end)

	it("climbing a ladder is 1.2 times as loud", function()
		expect(Config.Noise.LadderMultiplier).toBeCloseTo(1.2)
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

	it("a lone player drains the meter at 1.5 a second", function()
		expect(Config.Meter.SoloDrain).toBe(1.5)
	end)

	it("the drain is 1 per player, with no minimum", function()
		expect(Config.Meter.DrainPerPlayer).toBe(1)
		expect((Config.Meter :: any).DrainMinimum).toBe(nil)
	end)

	it("warnings come at 60 and 85 and re-arm 10 points lower", function()
		expect(Config.Meter.WarningMarks).toEqual({ 60, 85 })
		expect(Config.Meter.WarningRearmDrop).toBe(10)
	end)

	it("a free save drops the meter to 70", function()
		expect(Config.Meter.FreeSaveMeter).toBe(70)
	end)

	it("the replayed 85% warning after a free save lasts 3 seconds", function()
		expect(Config.Meter.FreeSaveWarningSeconds).toBe(3)
	end)

	it("the new-player cap of 84 and its 2 eggs are gone", function()
		expect((Config.Meter :: any).NewPlayerCap).toBe(nil)
		expect((Config.Meter :: any).NewPlayerEggsNeeded).toBe(nil)
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

	it(
		"footprints: 3.6 apart, redone every 0.25 s, lifted 0.05 (0.35 on ramp planks), 100 at most, stop 2 before a ladder",
		function()
			expect(Config.Footprints).toEqual({
				Spacing = 3.6,
				UpdateSeconds = 0.25,
				Lift = 0.05,
				RampLift = 0.35,
				MaxShown = 100,
				LadderStop = 2,
			})
		end
	)

	it("the four ways up, in garden order, with their gardens and walk limits", function()
		expect(Config.WaysUp).toEqual({
			{ Name = "Left boot ladder", Gardens = { 1, 2, 3 }, WalkLimitSeconds = { 7.5, 5, 4 } },
			{ Name = "Left ramp", Gardens = { 4 }, WalkLimitSeconds = { 4 } },
			{ Name = "Right ramp", Gardens = { 5 }, WalkLimitSeconds = { 4 } },
			{ Name = "Right boot ladder", Gardens = { 6, 7, 8 }, WalkLimitSeconds = { 4, 5, 7.5 } },
		})
	end)

	it("every garden 1 to 8 is in exactly one way up, with one walk limit each", function()
		local counts: { [number]: number } = {}
		for _, wayUp in Config.WaysUp do
			expect(#wayUp.WalkLimitSeconds).toBe(#wayUp.Gardens)
			for _, garden in wayUp.Gardens do
				counts[garden] = (counts[garden] or 0) + 1
			end
		end
		for garden = 1, 8 do
			expect(counts[garden]).toBe(1)
		end
	end)

	it("the ladders: four models, a 2-stud margin", function()
		expect(Config.Ladders).toEqual({
			Models = { "BeardLadder", "CapLadder", "BootLadder_Left", "BootLadder_Right" },
			NearStuds = 2,
		})
	end)

	it("the game loop ticks every 0.1 s", function()
		expect(Config.Tick.Seconds).toBe(0.1)
	end)

	it("the stuck scan's body size is a positive width and height", function()
		expect(type(Config.Stuck.BodyWidth)).toBe("number")
		expect(type(Config.Stuck.BodyHeight)).toBe("number")
		expect(Config.Stuck.BodyWidth > 0).toBe(true)
		expect(Config.Stuck.BodyHeight > 0).toBe(true)
	end)

	it("the stuck scan's grid is 2 studs apart", function()
		expect(Config.Stuck.ScanSpacing).toBe(2)
	end)

	it("a safe spot is checked every 0.5 s", function()
		expect(Config.Stuck.SafeSaveSeconds).toBe(0.5)
	end)

	it("the rescue distance is 4 studs", function()
		expect(Config.Stuck.RescueDistance).toBe(4)
	end)

	it("the stuck scan covers 10 studs of meadow around the giant", function()
		expect(Config.Stuck.ScanMargin).toBe(10)
	end)

	it("the stuck scan has a time limit of 120 seconds", function()
		expect(Config.Stuck.ScanSeconds).toBe(120)
	end)

	it("has the Reset and loop limits", function()
		expect(Config.Stuck.ResetCooldownSeconds).toBe(2)
		expect(Config.Stuck.LoopMoves).toBe(3)
		expect(Config.Stuck.LoopSeconds).toBe(30)
	end)

	it("has the stuck limits", function()
		expect(Config.Stuck.StuckSeconds).toBe(3)
		expect(Config.Stuck.StuckDistance).toBe(2)
		expect(Config.Stuck.PressChangesPerSecond).toBe(10)
	end)

	it("the egg slots add up to 19", function()
		local total = 0
		for _, rank in Config.RarityOrder do
			total += Config.Rarity[rank].Slots
		end
		expect(total).toBe(19)
	end)

	it("the nests add up to 38", function()
		local total = 0
		for _, rank in Config.RarityOrder do
			total += Config.Rarity[rank].Nests
		end
		expect(total).toBe(38)
	end)

	it("every rank has more nests than slots", function()
		for _, rank in Config.RarityOrder do
			expect(Config.Rarity[rank].Nests).toBeGreaterThan(Config.Rarity[rank].Slots)
		end
	end)

	it("slots are 8, 4, 4, 2 and 1", function()
		expect(Config.Rarity.Common.Slots).toBe(8)
		expect(Config.Rarity.Uncommon.Slots).toBe(4)
		expect(Config.Rarity.Rare.Slots).toBe(4)
		expect(Config.Rarity.Epic.Slots).toBe(2)
		expect(Config.Rarity.Legendary.Slots).toBe(1)
	end)

	it("nests are 16, 8, 6, 4 and 4", function()
		expect(Config.Rarity.Common.Nests).toBe(16)
		expect(Config.Rarity.Uncommon.Nests).toBe(8)
		expect(Config.Rarity.Rare.Nests).toBe(6)
		expect(Config.Rarity.Epic.Nests).toBe(4)
		expect(Config.Rarity.Legendary.Nests).toBe(4)
	end)

	it("the nest spacing and distance numbers match spec 5 section 5", function()
		expect(Config.Nests.EggSpacing).toBe(6)
		expect(Config.Nests.MeadowSpacing).toBe(8)
		expect(Config.Nests.PlayerDistance).toBe(15)
		expect(Config.Nests.RetrySeconds).toBe(1)
		expect(Config.Nests.TwinDistance).toBe(2)
		expect(Config.Nests.EyeDistance).toBe(10)
	end)

	it("the nest seam and walking-surface numbers match spec 5 section 5", function()
		expect(Config.Nests.SeamDegrees).toBe(65)
		expect(Config.Nests.SeamMatch).toBe(1)
		expect(Config.Nests.WalkSurfaceBelow).toBe(0.2)
		expect(Config.Nests.WalkSurfaceAbove).toBe(0.7)
		expect(Config.Nests.SeamHeight).toBe(12)
		expect(Config.Nests.ClimbableHeight).toBe(15)
	end)

	it("the nest timing and slide numbers match spec 5 section 5", function()
		expect(Config.Nests.BeamFadeSeconds).toBe(0.3)
		expect(Config.Nests.UnlockSeconds).toBe(0.5)
		expect(Config.Nests.ArmReturnSeconds).toBe(0.5)
		expect(Config.Nests.SlideTipSeconds).toBe(3)
		expect(Config.Nests.SlideDrop).toBe(5)
	end)

	it("the nest jump reach is 9 up, 10 across and a 5 stud body", function()
		expect(Config.Nests.Jump).toEqual({ Up = 9, Across = 10, BodyHeight = 5 })
	end)

	it("rare egg one is the lower belly left nest", function()
		expect(Config.Nests.RareEggOne).toBe("Nest_LowerBelly_Left")
	end)

	it("Config.Ranks holds the whole rank table, with the 10-stud body beam and its three zones", function()
		expect(Config.Ranks).toEqual({
			VisibleBelow = 0.5,
			FloatLimit = 0.2,
			SinkNestUpright = 0.3,
			SinkNestLeaning = 1.5,
			SinkEggUpright = 0.3,
			SinkEggLeaning = 1,
			EggInNest = 0.2,
			BodyBeamStuds = 10,
			BodyZones = { Belly = true, Beard = true, Nightcap = true },
		})
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
