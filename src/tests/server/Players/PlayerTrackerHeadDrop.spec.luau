--!strict
-- Task 61d: what the tracker reports for a quiet drop from the cap (spec 5, Rule 8: Steps make noise), and a whole
-- session that walks off the cap landing carrying an egg (.claude/rules/tdd.md, "Whole-session tests").
-- The Humanoid state can't be faked on a character that isn't in the world, so the climb up the tie is covered by the
-- detector's own specs (LandingDetectorHeadDrop); here the player is already at the landing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(ServerScriptService.Server.Giant.Noise)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local TrackerRig = require(script.Parent.TrackerRig)

local NIGHTCAP: Config.ZoneName = "Nightcap"
local BELLY: Config.ZoneName = "Belly"

local TICK_SECONDS = 0.1
local LANDING = Vector3.new(-27.5, 113.5, 32) -- the tie's landing, in the Nightcap box below
local PILLOW = Vector3.new(-45.6, 54, 32) -- the pillow drop spot, in the Belly box below
local SHOULDER_Y = 57
local TIE_FOOT = Vector3.new(-38.7, 57.4, 32.45) -- the foot of the left cap tie, in the Belly box below

local zoneBoxes: { Zones.ZoneBox } = {
	{ zone = NIGHTCAP, cframe = CFrame.new(0, 120, 0), size = Vector3.new(200, 40, 200) }, -- y 100 to 140
	{ zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(200, 60, 200) }, -- y 20 to 80
}

type Rig = {
	step: (position: Vector3, grounded: boolean, verticalSpeed: number, climbing: boolean?) -> PlayerTracker.Sample,
	destroy: () -> (),
}

-- A tracker for one brand-new player's character, reading once per 0.1 s tick. `onPillow` is true below y 60.
-- `onCapTie` is the tracker's "is this spot on a cap tie" dep. `isClimbing` stands in for the Humanoid's Climbing state,
-- which a character that isn't in the running world can't be put into.
local function newRig(start: Vector3, onCapTie: boolean?): Rig
	local character = TrackerRig.makeCharacter(start)
	local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
	local time = 0
	local grounded = true
	local climbing = false
	local deps: any = {
		getPlayers = function()
			return players
		end,
		zoneBoxes = zoneBoxes,
		gardens = TrackerRig.noGardens,
		isGrounded = function(_character: Model): boolean
			return grounded
		end,
		takeoffs = function(_character: Model): { Vector3 }
			return {}
		end,
		now = function()
			return time
		end,
		onPillow = function(position: Vector3): boolean
			return position.Y < 60
		end,
		isClimbing = function(_character: Model): boolean
			return climbing
		end,
		onCapTie = if onCapTie == nil
			then nil
			else function(_position: Vector3): boolean
				return onCapTie
			end,
	}
	local tracker = PlayerTracker.new(deps)
	local root = TrackerRig.rootOf(character)
	return {
		step = function(
			position: Vector3,
			onGround: boolean,
			verticalSpeed: number,
			isClimbing: boolean?
		): PlayerTracker.Sample
			time += TICK_SECONDS
			grounded = onGround
			climbing = isClimbing == true
			root.Position = position
			root.AssemblyLinearVelocity = Vector3.new(0, verticalSpeed, 0)
			return tracker:tick()[1]
		end,
		destroy = function()
			character:Destroy()
		end,
	}
end

-- Rests at the landing, falls fast for 4 ticks, and rests 3 ticks at `endAt`. Returns every sample, in order.
local function walkOffAndFall(rig: Rig, endAt: Vector3): { PlayerTracker.Sample }
	local samples: { PlayerTracker.Sample } = {}
	for _ = 1, 2 do
		table.insert(samples, rig.step(LANDING, true, 0))
	end
	for i = 1, 4 do
		table.insert(samples, rig.step(LANDING:Lerp(endAt, i / 4), false, -20))
	end
	for _ = 1, 3 do
		table.insert(samples, rig.step(endAt, true, 0))
	end
	return samples
end

describe("PlayerTracker quiet drop", function()
	it("a walk-off from the landing onto the pillow gives no thud on any tick", function()
		local rig = newRig(LANDING)

		for _, sample in walkOffAndFall(rig, PILLOW) do
			expect(sample.thudFrom).toBeNil()
		end

		rig.destroy()
	end)

	it("the tick the fall ends carries the drop and says it ended on the pillow", function()
		local rig = newRig(LANDING)

		local samples = walkOffAndFall(rig, PILLOW)
		local last = samples[#samples] :: any

		expect(last.drop).toEqual({ from = NIGHTCAP, to = BELLY, jumped = false, thudded = false })
		expect(last.onPillow).toBe(true)

		rig.destroy()
	end)

	it("a quiet drop adds no thud noise, so only the carried egg's walking noise is heard", function()
		local rig = newRig(LANDING)
		local bursts = 0
		for _, sample in walkOffAndFall(rig, PILLOW) do
			if sample.thudFrom ~= nil then
				bursts += Noise.jumpBurst(sample.thudFrom, sample.garden)
			end
		end

		expect(bursts).toBe(0)

		rig.destroy()
	end)
end)

describe("PlayerTracker whole session over the cap drop", function()
	it("a new player carrying an egg walks off the landing, drops and walks home over his shoulder", function()
		local carrying: Config.RarityName? = "Common" -- takes an egg at the nest before walking off
		local rig = newRig(LANDING)
		local samples = walkOffAndFall(rig, PILLOW)
		-- walks home over his shoulder: 2 studs a tick along the shoulder, in the Belly box
		for i = 1, 8 do
			table.insert(samples, rig.step(Vector3.new(-28 + 2 * i, SHOULDER_Y, -4), true, 0))
		end

		local bursts, walking, expectedWalking = 0, 0, 0
		for _, sample in samples do
			if sample.thudFrom ~= nil then
				bursts += Noise.jumpBurst(sample.thudFrom, sample.garden)
			end
			walking += Noise.perSecond({
				zone = sample.zone,
				garden = sample.garden,
				moving = sample.moving,
				tiptoe = false,
				carrying = carrying,
			}) * TICK_SECONDS
			if sample.moving then
				expectedWalking += Config.Noise.WalkPerSecond * Config.Noise.ZoneMultiplier[sample.zone] * Config.Rarity.Common.CarryNoise * TICK_SECONDS
			end
		end

		expect(bursts).toBe(0)
		expect(carrying).toBe("Common") -- nothing in a quiet drop takes the egg
		expect(walking).toBeCloseTo(expectedWalking, 5)
		expect(samples[#samples].zone).toBe(BELLY)
		expect(expectedWalking).toBeGreaterThan(0) -- he was heard walking home: the walk is not free

		rig.destroy()
	end)
end)

describe("PlayerTracker quiet drop from a cap tie", function()
	it("a climber on a cap tie who lets go low and lands on the pillow gets a quiet drop sample", function()
		local rig = newRig(TIE_FOOT, true)
		local samples: { PlayerTracker.Sample } = {}
		for i = 1, 3 do
			table.insert(samples, rig.step(TIE_FOOT + Vector3.new(0, i, 0), false, 5, true))
		end
		for i = 1, 4 do
			table.insert(samples, rig.step((TIE_FOOT + Vector3.new(0, 3, 0)):Lerp(PILLOW, i / 4), false, -20))
		end
		for _ = 1, 3 do
			table.insert(samples, rig.step(PILLOW, true, 0))
		end

		for _, sample in samples do
			expect(sample.thudFrom).toBeNil()
		end
		local last = samples[#samples] :: any
		expect(last.drop).toEqual({ from = BELLY, to = BELLY, jumped = false, thudded = false })
		expect(last.onPillow).toBe(true)

		rig.destroy()
	end)
end)
