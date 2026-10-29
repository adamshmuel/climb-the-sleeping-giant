--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Recovery = require(ServerScriptService.Server.Players.Recovery)
local SafeSpots = require(ServerScriptService.Server.Players.SafeSpots)
local RecoveryRig = require(script.Parent.RecoveryRig)
local HIP_HEIGHT = RecoveryRig.HIP_HEIGHT
local ROOT_HEIGHT = RecoveryRig.ROOT_HEIGHT
local made = RecoveryRig.made
local makeCharacter = RecoveryRig.makeCharacter
local rootOf = RecoveryRig.rootOf
local newPlayer = RecoveryRig.newPlayer
local sampleAt = RecoveryRig.sampleAt
local newRig = RecoveryRig.newRig
type FakePlayer = RecoveryRig.FakePlayer
type Rig = RecoveryRig.Rig

afterEach(RecoveryRig.cleanUp)

describe("Recovery", function()
	it("saves a safe spot from each player's sample", function()
		local first = newPlayer(1, Vector3.new(0, 10, 0))
		local second = newPlayer(2, Vector3.new(50, 10, 0))
		local rig = newRig({ first, second })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.samples[2] = sampleAt(Vector3.new(50, 5, 0), Vector3.zAxis, rig.clock)

		rig.recovery:step()

		expect(rig.safeSpots:count(1)).toBe(1)
		expect(rig.safeSpots:count(2)).toBe(1)
		expect((rig.safeSpots:pick(2, Vector3.new(0, 5, 0)) :: SafeSpots.Spot).feet).toEqual(Vector3.new(50, 5, 0))
	end)

	it("a death on the giant keeps the safe spot picked before the spots are cleared", function()
		local player = newPlayer(1, Vector3.new(0, 20, 0))
		local oldCharacter = player.Character :: Model
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(1)

		rig.die(oldCharacter)
		local newCharacter = makeCharacter(Vector3.new(500, 5, 0))
		table.insert(made, newCharacter)
		player.Character = newCharacter
		player.CharacterAdded:Fire(newCharacter)

		local kept = rig.recovery:keptSpot(player :: any)
		expect(kept).never.toBeNil()
		expect((kept :: SafeSpots.Spot).feet).toEqual(Vector3.new(0, 5, 0))
		expect(rig.safeSpots:count(1)).toBe(0)
	end)

	it("forgets a player's spots when they leave", function()
		local player = newPlayer(1, Vector3.new(0, 20, 0))
		local oldCharacter = player.Character :: Model
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		rig.die(oldCharacter)
		expect(rig.recovery:keptSpot(player :: any)).never.toBeNil()

		rig.playerRemoving:Fire(player)

		expect(rig.safeSpots:count(1)).toBe(0)
		expect(rig.recovery:keptSpot(player :: any)).toBeNil()
	end)

	it("forgets a player's spots when they get a new character", function()
		local player = newPlayer(1, Vector3.new(0, 20, 0))
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(0, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(1)

		local newCharacter = makeCharacter(Vector3.new(500, 5, 0))
		table.insert(made, newCharacter)
		player.Character = newCharacter
		player.CharacterAdded:Fire(newCharacter)

		expect(rig.safeSpots:count(1)).toBe(0)
	end)

	it("moves a player to the newest safe spot 0.5 studs up, facing the saved way, with no speed", function()
		local player = newPlayer(1, Vector3.new(0, 30, 0))
		local character = player.Character :: Model
		rootOf(character).AssemblyLinearVelocity = Vector3.new(0, -30, 5)
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()

		local target = rig.recovery:moveBack(player :: any)

		-- feet + 0.5 + the hip height + half the root's height
		local expected = Vector3.new(10, 5 + 0.5 + HIP_HEIGHT + ROOT_HEIGHT / 2, 0)
		expect(target).never.toBeNil()
		expect(((target :: CFrame).Position - expected).Magnitude < 0.01).toBe(true)
		expect((rootOf(character).Position - expected).Magnitude < 0.01).toBe(true)
		expect((rootOf(character).CFrame.LookVector - Vector3.xAxis).Magnitude < 0.01).toBe(true)
		expect(rootOf(character).AssemblyLinearVelocity).toEqual(Vector3.zero)
	end)

	it("tells the tracker and fires Rescued with where they were and where they go", function()
		local player = newPlayer(7, Vector3.new(0, 30, 0))
		local rig = newRig({ player })
		rig.samples[7] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()

		local target = rig.recovery:moveBack(player :: any)

		expect(rig.moved).toEqual({ 7 })
		expect(#rig.rescues).toBe(1)
		expect(rig.rescues[1].player).toBe(player)
		expect(rig.rescues[1].from).toEqual(Vector3.new(0, 30, 0))
		expect(rig.rescues[1].to).toEqual(target)
		expect(rig.log).toEqual({ "moved", "rescued" }) -- the tracker is told first
	end)

	it("moves nobody when no safe spot is far enough", function()
		local player = newPlayer(1, Vector3.new(10, 6, 0))
		local character = player.Character :: Model
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(11, 5, 0), Vector3.xAxis, rig.clock) -- about 1.4 studs away
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(1)

		local target = rig.recovery:moveBack(player :: any)

		expect(target).toBeNil()
		expect(rootOf(character).Position).toEqual(Vector3.new(10, 6, 0))
		expect(#rig.moved).toBe(0)
		expect(#rig.rescues).toBe(0)
	end)

	-- A player on the giant with one safe spot 10 studs away, ready for a Reset.
	local function onGiantWithSpot(userId: number): (FakePlayer, Rig)
		local player = newPlayer(userId, Vector3.new(0, 30, 0))
		local rig = newRig({ player })
		rig.samples[userId] = sampleAt(Vector3.new(10, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		return player, rig
	end

	-- Puts the player back far from the spot, so the next Reset has a spot to move them to.
	local function putFar(player: FakePlayer)
		rootOf(player.Character :: Model).Position = Vector3.new(0, 30, 0)
	end

	it("a Reset on the giant while he sleeps moves the player back and keeps their egg", function()
		local player, rig = onGiantWithSpot(1)
		player:SetAttribute("Carrying", "Rare")

		rig.recovery:reset(player :: any)

		expect(#rig.rescues).toBe(1)
		expect(#rig.home).toBe(0)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
	end)

	it("a Reset with no safe spot far enough sends the player home", function()
		local player = newPlayer(1, Vector3.new(10, 6, 0))
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(11, 5, 0), Vector3.xAxis, rig.clock) -- about 1.4 studs away
		rig.recovery:step()

		rig.recovery:reset(player :: any)

		expect(rig.home).toEqual({ 1 })
		expect(#rig.rescues).toBe(0)
	end)

	it("a third move within 30 seconds sends the player home", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		expect(#rig.rescues).toBe(2)

		rig.recovery:reset(player :: any)

		expect(#rig.rescues).toBe(2)
		expect(rig.home).toEqual({ 1 })
	end)

	it("a Reset off the giant sends the player home", function()
		local player, rig = onGiantWithSpot(1)
		rig.where = { zone = "Meadow", onPillow = false }

		rig.recovery:reset(player :: any)

		expect(rig.home).toEqual({ 1 })
		expect(#rig.rescues).toBe(0)
	end)

	it("a Reset on the pillow moves the player back", function()
		local player, rig = onGiantWithSpot(1)
		rig.where = { zone = "Meadow", onPillow = true }

		rig.recovery:reset(player :: any)

		expect(#rig.rescues).toBe(1)
		expect(#rig.home).toBe(0)
	end)

	it("a Reset while the giant is awake sends the player home", function()
		local player, rig = onGiantWithSpot(1)
		rig.phase = "Awake"

		rig.recovery:reset(player :: any)

		expect(rig.home).toEqual({ 1 })
		expect(#rig.rescues).toBe(0)
	end)

	it("a Reset does nothing when the player has no living character", function()
		local player, rig = onGiantWithSpot(1)
		rig.where = nil

		rig.recovery:reset(player :: any)

		expect(#rig.home).toBe(0)
		expect(#rig.rescues).toBe(0)
	end)

	it("forgets a player's moves when they leave", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.playerRemoving:Fire(player)
		rig.recovery:step() -- the spot is saved again, as for a player who joined again

		rig.recovery:reset(player :: any)

		expect(#rig.rescues).toBe(3)
		expect(#rig.home).toBe(0)
	end)

	-- Presses to move at the start, then watches for `seconds` more without the body moving.
	local function pressAndWait(player: FakePlayer, rig: Rig, seconds: number)
		rig.recovery:setPressing(player :: any, true)
		rig.recovery:step()
		rig.clock += seconds
		rig.recovery:step()
	end

	it("a player pressing without moving for 3 seconds is moved back with their egg", function()
		local player, rig = onGiantWithSpot(1)
		player:SetAttribute("Carrying", "Rare")

		pressAndWait(player, rig, 3)

		expect(#rig.rescues).toBe(1)
		expect(#rig.home).toBe(0)
		expect(player:GetAttribute("Carrying")).toBe("Rare")
	end)

	it("a player pressing without moving for 2.9 seconds is not rescued yet", function()
		local player, rig = onGiantWithSpot(1)
		pressAndWait(player, rig, 2.9)
		expect(#rig.rescues).toBe(0)
	end)

	it("a player standing on the pillow who presses and doesn't move for 3 seconds is rescued", function()
		local player, rig = onGiantWithSpot(1)
		rig.where = { zone = "Meadow", onPillow = true }

		pressAndWait(player, rig, 3)

		expect(#rig.rescues).toBe(1)
		expect(#rig.home).toBe(0)
	end)

	it("a player in the Meadow off the pillow is never rescued", function()
		local player, rig = onGiantWithSpot(1)
		rig.where = { zone = "Meadow", onPillow = false }
		pressAndWait(player, rig, 10)
		expect(#rig.rescues).toBe(0)
	end)

	it("the giant being awake doesn't stop the rescue, and the egg stays", function()
		local player, rig = onGiantWithSpot(1)
		rig.phase = "Awake"
		player:SetAttribute("Carrying", "Epic")

		pressAndWait(player, rig, 3)

		expect(#rig.rescues).toBe(1)
		expect(player:GetAttribute("Carrying")).toBe("Epic")
	end)

	it("a rescue after two Resets within 30 seconds sends the player home", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		rig.recovery:reset(player :: any)
		putFar(player)
		rig.clock += 10
		expect(#rig.rescues).toBe(2)

		pressAndWait(player, rig, 3)

		expect(#rig.rescues).toBe(2)
		expect(rig.home).toEqual({ 1 })
	end)

	it("a rescue with no safe spot far enough sends the player home", function()
		local player = newPlayer(1, Vector3.new(10, 6, 0))
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(11, 5, 0), Vector3.xAxis, rig.clock) -- about 1.4 studs away

		pressAndWait(player, rig, 3)

		expect(rig.home).toEqual({ 1 })
		expect(#rig.rescues).toBe(0)
	end)

	it("a player in a red circle is not rescued", function()
		local player, rig = onGiantWithSpot(1)
		rig.inRedCircle = true
		pressAndWait(player, rig, 10)
		expect(#rig.rescues).toBe(0)
		expect(#rig.home).toBe(0)
	end)

	it("a player who is falling is not rescued", function()
		local player, rig = onGiantWithSpot(1)
		rig.falling = true
		pressAndWait(player, rig, 10)
		expect(#rig.rescues).toBe(0)
	end)

	it("a player floating down is not rescued", function()
		local player, rig = onGiantWithSpot(1)
		rig.floating = true
		pressAndWait(player, rig, 10)
		expect(#rig.rescues).toBe(0)
	end)

	it("a player without a living character is not rescued", function()
		local player, rig = onGiantWithSpot(1)
		rig.where = nil
		pressAndWait(player, rig, 10)
		expect(#rig.rescues).toBe(0)
		expect(#rig.home).toBe(0)
	end)

	it("pressing is forgotten when the character respawns", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:setPressing(player :: any, true)
		rig.recovery:step()
		player.CharacterAdded:Fire(player.Character)
		rig.clock += 3
		rig.recovery:step()
		expect(#rig.rescues).toBe(0)
	end)

	it("pressing is forgotten when the player leaves", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:setPressing(player :: any, true)
		rig.recovery:step()
		rig.playerRemoving:Fire(player)
		rig.clock += 3
		rig.recovery:step()
		expect(#rig.rescues).toBe(0)
	end)

	it("a rescue lands on the safe spot 5 studs away, not the one 3 studs away", function()
		-- The body's root is 3 studs above its feet. Measured root to feet, the 3-stud spot looks 4.24 away.
		local player = newPlayer(1, Vector3.new(0, 8, 0))
		local rig = newRig({ player })
		rig.samples[1] = sampleAt(Vector3.new(5, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		rig.clock += 1
		rig.samples[1] = sampleAt(Vector3.new(3, 5, 0), Vector3.xAxis, rig.clock)
		rig.recovery:step()
		expect(rig.safeSpots:count(1)).toBe(2)

		local target = rig.recovery:moveBack(player :: any)

		expect(target).never.toBeNil()
		expect(math.abs((target :: CFrame).Position.X - 5) < 0.01).toBe(true)
	end)

	it("a rescued player who keeps pressing doesn't move", function()
		local player, rig = onGiantWithSpot(1)

		pressAndWait(player, rig, 3)

		expect(#rig.rescues).toBe(1)
		expect(player:GetAttribute("Held")).toBe(true)
	end)

	it("after 'stopped' they walk again", function()
		local player, rig = onGiantWithSpot(1)
		pressAndWait(player, rig, 3)
		expect(player:GetAttribute("Held")).toBe(true)

		rig.recovery:setPressing(player :: any, false)

		expect(player:GetAttribute("Held")).toBeNil()
	end)

	it("a Reset that moves them back holds them the same way", function()
		local player, rig = onGiantWithSpot(1)
		rig.recovery:setPressing(player :: any, true)

		rig.recovery:reset(player :: any)

		expect(#rig.rescues).toBe(1)
		expect(player:GetAttribute("Held")).toBe(true)
	end)

	it("a rescued player who isn't pressing isn't held", function()
		local player, rig = onGiantWithSpot(1)

		rig.recovery:reset(player :: any) -- moved back, with nobody pressing

		expect(#rig.rescues).toBe(1)
		expect(player:GetAttribute("Held")).toBeNil()
	end)

	it("a new character ends the hold", function()
		local player, rig = onGiantWithSpot(1)
		pressAndWait(player, rig, 3)
		expect(player:GetAttribute("Held")).toBe(true)

		local newCharacter = makeCharacter(Vector3.new(500, 5, 0))
		table.insert(made, newCharacter)
		player.Character = newCharacter
		player.CharacterAdded:Fire(newCharacter)

		expect(player:GetAttribute("Held")).toBeNil()
	end)

	it(
		"stuck, rescued and held, keeps pressing 10 s with no second rescue, lets go, then can be rescued again",
		function()
			local player, rig = onGiantWithSpot(1)
			pressAndWait(player, rig, 3)
			expect(#rig.rescues).toBe(1)

			for _ = 1, 10 do
				rig.clock += 1
				rig.recovery:step()
			end
			expect(#rig.rescues).toBe(1)
			expect(#rig.home).toBe(0)
			expect(player:GetAttribute("Held")).toBe(true)

			rig.recovery:setPressing(player :: any, false)
			expect(player:GetAttribute("Held")).toBeNil()

			-- A second safe spot, far from where they stand now.
			rig.clock += 1
			rig.samples[1] = sampleAt(Vector3.new(-10, 5, 0), Vector3.xAxis, rig.clock)
			rig.recovery:step()
			pressAndWait(player, rig, 3)

			expect(#rig.rescues).toBe(2)
			expect(#rig.home).toBe(0) -- moved back again, not sent home
			expect(player:GetAttribute("Held")).toBe(true)
		end
	)

	it("finds the part under a player's feet", function()
		local floor = Instance.new("Part")
		floor.Anchored = true
		floor.Size = Vector3.new(20, 1, 20)
		floor.Position = Vector3.new(5000, 1000, 5000)
		floor.Parent = game:GetService("Workspace")
		table.insert(made, floor)
		local player = newPlayer(1, Vector3.new(5000, 1002, 5000))
		local character = player.Character :: Model
		character.Parent = game:GetService("Workspace")

		expect(Recovery.groundOf(player :: any)).toBe(floor)
	end)
end)
