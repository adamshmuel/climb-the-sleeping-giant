--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local RecoveryRig = require(script.Parent.RecoveryRig)
local made = RecoveryRig.made
local makeCharacter = RecoveryRig.makeCharacter
local rootOf = RecoveryRig.rootOf
local newPlayer = RecoveryRig.newPlayer
local sampleAt = RecoveryRig.sampleAt
local newRig = RecoveryRig.newRig
type FakePlayer = RecoveryRig.FakePlayer
type Rig = RecoveryRig.Rig

afterEach(RecoveryRig.cleanUp)

-- A death like the real game's: whereIs has no answer (no living character), the Humanoid dies, a new character is
-- made and arrives. Before the death the player is put far from the safe spot (as a fall would) and one tick saves
-- where they were. Spawning's arrival is waited out so any move after it has had its turn.
local SPAWN = Vector3.new(500, 5, 0)

-- The engine's order (Lesson 129): CharacterAdded fires first, and the new body is put into the world after that.
local function dieOnGiant(player: FakePlayer, rig: Rig): Model
	local where = rig.where
	rootOf(player.Character :: Model).Position = Vector3.new(0, 30, 0)
	rig.recovery:step()
	rig.where = nil
	rig.die(player.Character :: Model)
	local newCharacter = makeCharacter(SPAWN)
	table.insert(made, newCharacter)
	player.CharacterAdded:Fire(newCharacter)
	player.Character = newCharacter
	task.wait(0.1)
	rig.where = where
	return newCharacter
end

-- A brand-new player standing on the giant with one safe spot (10, 5, 0), saved by one tick.
local function newOnGiant(userId: number): (FakePlayer, Rig)
	local player = newPlayer(userId, Vector3.new(0, 30, 0))
	local rig = newRig({ player })
	rig.samples[userId] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
	rig.recovery:step()
	return player, rig
end

describe("Recovery, a death on the giant is V1 (Rule 25)", function()
	it("a death on the giant while he sleeps leaves the new body where it spawned", function()
		local player, rig = newOnGiant(1)
		player:SetAttribute("Carrying", "Rare")

		local newCharacter = dieOnGiant(player, rig)

		expect(#rig.moved).toBe(0)
		expect(rootOf(newCharacter).Position).toEqual(SPAWN)
	end)

	it("Recovery gives Banking no way to keep an egg through a death", function()
		local _player, rig = newOnGiant(1)

		expect((rig.recovery :: any).keepsEgg).toBeNil()
	end)

	it("a death while he's awake is V1: nobody is moved", function()
		local player, rig = newOnGiant(1)
		player:SetAttribute("Carrying", "Rare")
		rig.phase = "Awake"

		local newCharacter = dieOnGiant(player, rig)

		expect(#rig.moved).toBe(0)
		expect(#rig.rescues).toBe(0)
		expect(rootOf(newCharacter).Position).toEqual(SPAWN)
	end)

	it("a death in the Meadow is V1: nobody is moved", function()
		local player, rig = newOnGiant(1)
		player:SetAttribute("Carrying", "Rare")
		rig.where = { zone = "Meadow", onPillow = false }

		dieOnGiant(player, rig)

		expect(#rig.moved).toBe(0)
		expect(#rig.rescues).toBe(0)
	end)
end)
