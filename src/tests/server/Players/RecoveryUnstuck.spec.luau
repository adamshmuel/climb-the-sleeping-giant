--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local RecoveryRig = require(script.Parent.RecoveryRig)
local rootOf = RecoveryRig.rootOf
local newPlayer = RecoveryRig.newPlayer
local sampleAt = RecoveryRig.sampleAt
local newRig = RecoveryRig.newRig
type FakePlayer = RecoveryRig.FakePlayer
type Rig = RecoveryRig.Rig

afterEach(RecoveryRig.cleanUp)

-- What Unstuck told, in order.
type Told = { player: FakePlayer, how: string, zone: string }

describe("Recovery Unstuck", function()
	-- A brand-new player on the giant with one safe spot 10 studs away, and a spy on Unstuck. Unstuck also writes
	-- "unstuck" into the rig's log, so the order against the move and the send home can be read.
	local function onGiantWithSpot(userId: number): (FakePlayer, Rig, { Told })
		local player = newPlayer(userId, Vector3.new(0, 30, 0))
		local rig = newRig({ player })
		local told: { Told } = {}
		rig.recovery.unstuck:Connect(function(who: FakePlayer, how: string, zone: string)
			table.insert(told, { player = who, how = how, zone = zone })
			table.insert(rig.log, "unstuck")
		end)
		rig.samples[userId] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		return player, rig, told
	end

	-- Puts the player back far from the spot, so the next move has a spot to go to.
	local function putFar(player: FakePlayer)
		rootOf(player.Character :: Model).Position = Vector3.new(0, 30, 0)
	end

	-- Presses to move at the start, then watches for `seconds` more without the body moving.
	local function pressAndWait(player: FakePlayer, rig: Rig, seconds: number)
		rig.recovery:setPressing(player :: any, true)
		rig.recovery:step()
		rig.clock += seconds
		rig.recovery:step()
	end

	it("a rescue tells Unstuck: Rescue and the zone", function()
		local player, rig, told = onGiantWithSpot(1)

		pressAndWait(player, rig, 3)

		expect(#rig.rescues).toBe(1)
		expect(#told).toBe(1)
		expect(told[1].player).toBe(player)
		expect(told[1].how).toBe("Rescue")
		expect(told[1].zone).toBe("Belly")
	end)

	it("a rescue with no spot far enough goes home and tells Rescue", function()
		local player = newPlayer(1, Vector3.new(10, 6, 0))
		local rig = newRig({ player })
		local told: { Told } = {}
		rig.recovery.unstuck:Connect(function(who: FakePlayer, how: string, zone: string)
			table.insert(told, { player = who, how = how, zone = zone })
		end)
		rig.samples[1] = sampleAt(Vector3.new(11, 5, 0), Vector3.xAxis, rig.clock) -- about 1.4 studs away
		rig.recovery:step()

		pressAndWait(player, rig, 3)

		expect(rig.home).toEqual({ 1 })
		expect(#told).toBe(1)
		expect(told[1].how).toBe("Rescue")
		expect(told[1].zone).toBe("Belly")
	end)

	it("a rescue that is the loop's third move tells Loop home", function()
		local player, rig, told = onGiantWithSpot(1)
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		table.clear(told)

		pressAndWait(player, rig, 3)

		expect(rig.home).toEqual({ 1 })
		expect(#told).toBe(1)
		expect(told[1].how).toBe("Loop home")
		expect(told[1].zone).toBe("Belly")
	end)

	it("a Reset on the sleeping giant tells Unstuck: Reset on giant", function()
		local player, rig, told = onGiantWithSpot(1)

		rig.recovery:reset(player :: any)

		expect(#rig.rescues).toBe(1)
		expect(#told).toBe(1)
		expect(told[1].player).toBe(player)
		expect(told[1].how).toBe("Reset on giant")
		expect(told[1].zone).toBe("Belly")
	end)

	it("a Reset on the giant while he is awake tells Reset on giant", function()
		local player, rig, told = onGiantWithSpot(1)
		rig.phase = "Awake"

		rig.recovery:reset(player :: any)

		expect(rig.home).toEqual({ 1 })
		expect(#told).toBe(1)
		expect(told[1].how).toBe("Reset on giant")
		expect(told[1].zone).toBe("Belly")
	end)

	it("a Reset on the giant that is the loop's third move tells Loop home", function()
		local player, rig, told = onGiantWithSpot(1)
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		table.clear(told)

		rig.recovery:reset(player :: any)

		expect(rig.home).toEqual({ 1 })
		expect(#told).toBe(1)
		expect(told[1].how).toBe("Loop home")
		expect(told[1].zone).toBe("Belly")
	end)

	it("a Reset off the giant tells nothing", function()
		local player, rig, told = onGiantWithSpot(1)
		rig.where = { zone = "Meadow", onPillow = false }

		rig.recovery:reset(player :: any)

		expect(rig.home).toEqual({ 1 })
		expect(#told).toBe(0)
		-- A spy that works at all: the same player, on the giant, is told about.
		rig.where = { zone = "Belly", onPillow = false }
		rig.phase = "Awake"
		rig.recovery:reset(player :: any)
		expect(#told).toBe(1)
	end)

	it("Unstuck is told before the move and before the send home", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:reset(player :: any) -- a move back
		expect(rig.log).toEqual({ "unstuck", "moved", "rescued" })

		local other, otherRig = onGiantWithSpot(2)
		otherRig.phase = "Awake"
		otherRig.recovery:reset(other :: any) -- a send home
		expect(otherRig.log).toEqual({ "unstuck", "home" })
	end)
end)
