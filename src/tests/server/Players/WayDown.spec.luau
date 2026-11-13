--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LandingDetector = require(ServerScriptService.Server.Players.LandingDetector)
local WayDown = require(ServerScriptService.Server.Players.WayDown)

type Ladder = WayDown.Ladder
type Fall = WayDown.Fall
type ZoneName = Config.ZoneName

local NIGHTCAP: { ZoneName } = { "Nightcap" }
local BEARD: { ZoneName } = { "Beard" }
local BOOTS: { ZoneName } = { "Boots" }
local HEAD_ZONES: { ZoneName } = { "Nightcap", "Beard" }
local FOOT = Config.Noise.QuietDrop.FootStuds

-- The four ladders (world table in work/p5t26/26-design.md; ends from the truss centres and lengths).
local ladders: { Ladder } = {
	{ name = "BeardLadder", kind = "head", foot = Vector3.new(0, 63, -25), top = Vector3.new(0, 93, -13) },
	{ name = "CapLadder", kind = "head", foot = Vector3.new(0, 94, -4), top = Vector3.new(0, 109, 0.6) },
	{
		name = "BootLadder_Left",
		kind = "boot",
		foot = Vector3.new(-51.3, 1, -64),
		top = Vector3.new(-33.5, 30.2, -64),
		ground = Vector3.new(-51.3, 2, -64),
	},
	{
		name = "BootLadder_Right",
		kind = "boot",
		foot = Vector3.new(51.3, 1, -64),
		top = Vector3.new(33.5, 30.2, -64),
		ground = Vector3.new(51.3, 2, -64),
	},
}

local END_ZONES: { ZoneName } = { "Beard", "Belly", "Boots", "Meadow" }

local function lineMid(ladder: Ladder): Vector3
	return (ladder.foot + ladder.top) / 2
end

type Extra = { zones: { ZoneName }?, endPosition: Vector3?, passedBelow: boolean?, jumped: boolean? }

local function fall(firstAirborne: Vector3, endZone: ZoneName, extra: Extra?): Fall
	local e: Extra = extra or {}
	local zones: { [ZoneName]: boolean } = {}
	local seen: { ZoneName } = e.zones or {}
	for _, zone in seen do
		zones[zone :: ZoneName] = true
	end
	return {
		firstAirborne = firstAirborne,
		zones = zones,
		endZone = endZone,
		endPosition = e.endPosition or firstAirborne,
		passedBelow = e.passedBelow == true,
		jumped = e.jumped == true,
	}
end

describe("WayDown.isSet, the head ladders", function()
	it("is quiet off the cap's top onto the nose top, and not when it ends in the Meadow", function()
		local atTop = Vector3.new(0, 108, 0.5)
		expect(WayDown.isSet(fall(atTop, "Beard", { zones = NIGHTCAP }), ladders)).toBe(true)
		expect(WayDown.isSet(fall(atTop, "Meadow", { zones = NIGHTCAP }), ladders)).toBe(false)
	end)

	it("is quiet off the cap ladder's side and off the right brim nest, onto the nose top", function()
		local capLadder = ladders[2]
		local sideStart = lineMid(capLadder) + Vector3.new(1, 0, 0)
		expect(WayDown.isSet(fall(sideStart, "Beard", { zones = NIGHTCAP }), ladders)).toBe(true)
		local brimNest = Vector3.new(6, 108, 0)
		expect(WayDown.isSet(fall(brimNest, "Beard", { zones = NIGHTCAP }), ladders)).toBe(true)
	end)

	it("is quiet letting go of the beard ladder onto the belly path, and walking off the nose front", function()
		local beardLadder = ladders[1]
		local letGo = lineMid(beardLadder) + Vector3.new(0.5, 0, 0)
		expect(WayDown.isSet(fall(letGo, "Belly", { zones = BEARD }), ladders)).toBe(true)
		local noseFront = Vector3.new(0, 93, -5)
		expect(WayDown.isSet(fall(noseFront, "Belly", { zones = BEARD }), ladders)).toBe(true)
	end)

	it("is not quiet when the beard run ends in the Boots", function()
		local noseFront = Vector3.new(0, 93, -5)
		expect(WayDown.isSet(fall(noseFront, "Boots", { zones = BEARD }), ladders)).toBe(false)
	end)

	it("is not quiet for a jump from the nose top, the cap or a ladder, wherever it ends", function()
		local starts = { Vector3.new(0, 93, -5), Vector3.new(0, 108, 0.5), lineMid(ladders[1]), lineMid(ladders[2]) }
		for _, start in starts do
			for _, endZone in END_ZONES do
				local jumpFall = fall(start, endZone :: ZoneName, { zones = HEAD_ZONES, jumped = true })
				expect(WayDown.isSet(jumpFall, ladders)).toBe(false)
			end
		end
	end)

	it("is not quiet for a head fall that passed below the seam line and ends on the belly", function()
		local slide = fall(Vector3.new(0, 93, -5), "Belly", { zones = BEARD, passedBelow = true })
		expect(WayDown.isSet(slide, ladders)).toBe(false)
	end)
end)

describe("WayDown.isSet, the boot ladders", function()
	it("is quiet letting go of each boot ladder and landing 5 studs from its foot", function()
		for _, index in { 3, 4 } do
			local ladder = ladders[index]
			local ground = ladder.ground :: Vector3
			local landed = ground + Vector3.new(0, 0, 5)
			expect(WayDown.isSet(fall(lineMid(ladder), "Meadow", { zones = BOOTS, endPosition = landed }), ladders)).toBe(
				true
			)
		end
	end)

	it("is not quiet for a fall off the boot that began 2 studs beside the ladder line", function()
		local ladder = ladders[3]
		local ground = ladder.ground :: Vector3
		local beside = lineMid(ladder) + Vector3.new(0, 0, 2)
		expect(WayDown.isSet(fall(beside, "Meadow", { zones = BOOTS, endPosition = ground }), ladders)).toBe(false)
	end)

	it("is not quiet for a let-go that lands 9 studs from the foot", function()
		local ladder = ladders[3]
		local ground = ladder.ground :: Vector3
		local far = ground + Vector3.new(0, 0, FOOT + 1)
		expect(WayDown.isSet(fall(lineMid(ladder), "Meadow", { zones = BOOTS, endPosition = far }), ladders)).toBe(
			false
		)
	end)
end)

describe("The belly's raised strip", function()
	it("starts no fall for a 3.8-stud drop of 2 air ticks, so there is no thud", function()
		local state = LandingDetector.new("Belly")
		local ticks = {
			{ grounded = true, speed = 0 },
			{ grounded = false, speed = -4 },
			{ grounded = false, speed = -30 },
			{ grounded = true, speed = 0 },
			{ grounded = true, speed = 0 },
			{ grounded = true, speed = 0 },
		}
		for _, tick in ticks do
			local thud
			thud, state = LandingDetector.step(state, tick.grounded, tick.speed, "Belly", {})
			expect(thud).toBe(nil)
		end
	end)
end)
