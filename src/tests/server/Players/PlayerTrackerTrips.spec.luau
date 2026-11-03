--!strict
-- Task 61n: the trip count and the drop height the tracker keeps for each player (spec 5, section 10, the
-- "CapToCapFall" row). A trip counts up only when he reaches the cap by climbing a cap tie from below; a fall that
-- ends on the cap keeps the number. The Humanoid state can't be faked on a character that isn't in the world, so
-- `isClimbing` stands in for it, as in PlayerTrackerHeadDrop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local CapDrop = require(ServerScriptService.Server.Players.CapDrop)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local TrackerRig = require(script.Parent.TrackerRig)

local NIGHTCAP: Config.ZoneName = "Nightcap"
local BELLY: Config.ZoneName = "Belly"

local TICK_SECONDS = 0.1
local TIE_X = -38.7
local TIE_Z = 32.45
local PILLOW = Vector3.new(-45.6, 54, 32) -- the pillow drop spot, in the Belly box below
local LANDING = Vector3.new(-27.5, 113.5, 32) -- the tie's landing, in the Nightcap box below
local CAP_LOW = Vector3.new(-20, 105, 32) -- a lower spot on the cap, in the Nightcap box below
local TIE_TOP_Y = 112
local TIE_BOTTOM_Y = 58

local zoneBoxes: { Zones.ZoneBox } = {
	{ zone = NIGHTCAP, cframe = CFrame.new(0, 120, 0), size = Vector3.new(200, 40, 200) }, -- y 100 to 140
	{ zone = BELLY, cframe = CFrame.new(0, 50, 0), size = Vector3.new(200, 60, 200) }, -- y 20 to 80
}

local function onTie(position: Vector3): boolean
	return math.abs(position.X - TIE_X) < 0.5 and position.Y > 56 and position.Y < 113
end

type Rig = {
	step: (position: Vector3, grounded: boolean, verticalSpeed: number, climbing: boolean?) -> PlayerTracker.Sample,
	respawn: (position: Vector3) -> (),
	leave: () -> (),
	rejoin: (position: Vector3) -> (),
	destroy: () -> (),
}

-- A tracker for one brand-new player, reading once per 0.1 s tick. The tie is a thin strip at TIE_X.
local function newRig(start: Vector3): Rig
	local character = TrackerRig.makeCharacter(start)
	local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
	local present = true
	local time = 0
	local grounded = true
	local climbing = false
	local tracker = PlayerTracker.new({
		getPlayers = function()
			return if present then players else {}
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
		onCapTie = onTie,
	})
	local function swapCharacter(position: Vector3)
		character:Destroy()
		character = TrackerRig.makeCharacter(position)
		players[1].Character = character
	end
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
			local root = TrackerRig.rootOf(character)
			root.Position = position
			root.AssemblyLinearVelocity = Vector3.new(0, verticalSpeed, 0)
			return tracker:tick()[1]
		end,
		respawn = swapCharacter,
		leave = function()
			present = false
			tracker:tick()
		end,
		rejoin = function(position: Vector3)
			swapCharacter(position)
			present = true
		end,
		destroy = function()
			character:Destroy()
		end,
	}
end

-- Stands on the pillow, walks to the tie, climbs it and steps onto the landing. Returns the last sample.
local function climbOntoCap(rig: Rig): PlayerTracker.Sample
	for _ = 1, 3 do
		rig.step(PILLOW, true, 0)
	end
	for y = TIE_BOTTOM_Y, TIE_TOP_Y, 6 do
		rig.step(Vector3.new(TIE_X, y, TIE_Z), false, 3, true)
	end
	return rig.step(LANDING, true, 0)
end

-- Falls fast from `from` for 4 ticks and rests 3 ticks at `endAt`. Returns the last sample.
local function fallTo(rig: Rig, from: Vector3, endAt: Vector3): PlayerTracker.Sample
	for i = 1, 4 do
		rig.step(from:Lerp(endAt, i / 4), false, -20)
	end
	local last = rig.step(endAt, true, 0)
	for _ = 1, 2 do
		last = rig.step(endAt, true, 0)
	end
	return last
end

describe("PlayerTracker trip count", function()
	it("climbing a cap tie from the pillow onto the cap counts trip 1", function()
		local rig = newRig(PILLOW)

		expect(climbOntoCap(rig).trip).toBe(1)

		rig.destroy()
	end)

	it("walking about on the cap stays trip 1", function()
		local rig = newRig(PILLOW)
		climbOntoCap(rig)

		local last = rig.step(LANDING, true, 0)
		for i = 1, 6 do
			last = rig.step(LANDING + Vector3.new(2 * i, 0, 0), true, 0)
		end

		expect(last.trip).toBe(1)

		rig.destroy()
	end)

	it("a no-jump fall from a cap tie onto the cap keeps the trip number", function()
		local rig = newRig(PILLOW)
		climbOntoCap(rig) -- trip 1, then he climbs back down the tie from the cap, never grounded below
		for y = TIE_TOP_Y, 108, -2 do
			rig.step(Vector3.new(TIE_X, y, TIE_Z), false, -3, true)
		end

		local last = fallTo(rig, Vector3.new(TIE_X, 108, TIE_Z), CAP_LOW)

		expect(last.drop ~= nil and CapDrop.isCapToCap(last.drop)).toBe(true)
		expect(last.trip).toBe(1)

		rig.destroy()
	end)

	it("a no-jump fall from a tie's landing onto the cap keeps the trip number", function()
		local rig = newRig(PILLOW)
		climbOntoCap(rig)
		rig.step(LANDING, true, 0)

		local last = fallTo(rig, LANDING, CAP_LOW)

		expect(last.drop ~= nil and CapDrop.isCapToCap(last.drop)).toBe(true)
		expect(last.trip).toBe(1)

		rig.destroy()
	end)

	it("going back down to the pillow and climbing a tie onto the cap again counts trip 2", function()
		local rig = newRig(PILLOW)
		climbOntoCap(rig)
		rig.step(LANDING, true, 0)

		local last = climbOntoCap(rig)

		expect(last.trip).toBe(2)

		rig.destroy()
	end)

	it("standing on the cap without a tie climb from below counts no trip", function()
		local rig = newRig(LANDING)
		local last = rig.step(LANDING, true, 0)
		for _ = 1, 3 do
			last = rig.step(CAP_LOW, true, 0)
		end

		expect(last.trip).toBe(0)

		rig.destroy()
	end)

	it("a new character keeps the trip count", function()
		local rig = newRig(PILLOW)
		climbOntoCap(rig)

		rig.respawn(PILLOW)
		local last = rig.step(PILLOW, true, 0)

		expect(last.trip).toBe(1)

		rig.destroy()
	end)

	it("a player who leaves has the count cleared", function()
		local rig = newRig(PILLOW)
		climbOntoCap(rig)

		rig.leave()
		rig.rejoin(LANDING)
		local last = rig.step(LANDING, true, 0)

		expect(last.trip).toBe(0)

		rig.destroy()
	end)
end)

describe("PlayerTracker drop height", function()
	it("a drop sample carries its height from the highest point since rest", function()
		local rig = newRig(LANDING)
		rig.step(LANDING, true, 0)
		rig.step(LANDING, true, 0)

		local last = fallTo(rig, LANDING, CAP_LOW)

		expect(last.drop).never.toBeNil()
		expect(last.dropHeight).toBeCloseTo(LANDING.Y - CAP_LOW.Y, 5)

		rig.destroy()
	end)
end)

describe("PlayerTracker whole session over the trips", function()
	it("a new player climbs on, drops onto the cap, goes down, climbs again and walks off the landing", function()
		local rig = newRig(PILLOW)

		expect(climbOntoCap(rig).trip).toBe(1)
		for y = TIE_TOP_Y, 108, -2 do
			rig.step(Vector3.new(TIE_X, y, TIE_Z), false, -3, true)
		end
		local dropped = fallTo(rig, Vector3.new(TIE_X, 108, TIE_Z), CAP_LOW)
		expect(dropped.drop ~= nil and CapDrop.isCapToCap(dropped.drop)).toBe(true)
		expect(dropped.dropHeight).toBeGreaterThan(0)
		expect(dropped.trip).toBe(1)

		expect(rig.step(PILLOW, true, 0).trip).toBe(1) -- back down to the pillow
		expect(climbOntoCap(rig).trip).toBe(2)
		local last = rig.step(LANDING, true, 0)
		for i = 1, 4 do
			last = rig.step(LANDING + Vector3.new(2 * i, 0, 0), true, 0)
		end
		expect(last.trip).toBe(2)
		expect(last.zone).toBe(NIGHTCAP)

		rig.destroy()
	end)
end)
