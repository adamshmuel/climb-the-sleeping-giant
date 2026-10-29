--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local TrackerRig = require(script.Parent.TrackerRig)
local makeCharacter = TrackerRig.makeCharacter
local rootOf = TrackerRig.rootOf
local groundSpeedRig = TrackerRig.groundSpeedRig
local readAt = TrackerRig.readAt

type Rig = TrackerRig.Rig

local TICK = 0.1

-- One tick at (x, y): grounded or in the air, moving up or down at `speed` studs a second. Returns the sample.
local function driveTick(
	rig: Rig,
	character: Model,
	tickNumber: number,
	x: number,
	y: number,
	grounded: boolean,
	speed: number
): PlayerTracker.Sample
	rig.setGrounded(grounded)
	rootOf(character).AssemblyLinearVelocity = Vector3.new(0, speed, 0)
	return readAt(rig, character, tickNumber * TICK, x, y)
end

describe("PlayerTracker moved and shaking", function()
	it("a moved player adds no walking noise on the next tick", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)
		for step = 0, 3 do
			readAt(rig, character, step * 0.1, step * 1, 5) -- a walk, a stud a tick
		end

		rig.tracker:moved(1)
		local sample = readAt(rig, character, 0.4, 4 + 1.5, 5) -- the move put them 1.5 studs on

		expect(sample.moving).toBe(false)
		expect(sample.groundSpeed).toBe(0)

		character:Destroy()
	end)

	it("a player moved during a fall makes no thud when they land", function()
		local character = makeCharacter(Vector3.new(0, 50, 0))
		local rig = groundSpeedRig(character)
		local root = rootOf(character)
		root.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
		for step = 1, 3 do
			expect(readAt(rig, character, step * 0.1, 0, 50).thudFrom).toBeNil() -- a fast fall has started
		end

		rig.tracker:moved(1) -- the move also stops all speed, as Recovery does
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rig.setGrounded(true)
		local thuds = 0
		for step = 4, 12 do
			if readAt(rig, character, step * 0.1, 8, 30).thudFrom ~= nil then
				thuds += 1
			end
		end

		expect(thuds).toBe(0)

		character:Destroy()
	end)

	it("a player shaking 0.6 studs back and forth every tick makes no walking noise", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		local noisyTicks = 0
		for step = 1, 20 do
			local sample = readAt(rig, character, step * 0.1, if step % 2 == 1 then 0.6 else 0, 5)
			if sample.moving then
				noisyTicks += 1
			end
		end

		expect(noisyTicks).toBe(0)

		character:Destroy()
	end)

	it("a tiptoer still counts as moving from the second step", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		local moving: { boolean } = {}
		for step = 0, 14 do
			table.insert(moving, readAt(rig, character, step * 0.1, step * 0.96, 5).moving)
		end

		expect(moving[1]).toBe(false) -- the first sample has no step before it
		expect(moving[2]).toBe(false) -- 0.96 studs is under the 1 stud trip
		for index = 3, 15 do
			expect(moving[index]).toBe(true)
		end

		character:Destroy()
	end)

	it("a body shaking in a 1.6-stud gap while pressing makes no walking noise", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		for step = 0, 19 do
			readAt(rig, character, step * 0.1, 0, 5) -- stands still for 2 seconds
		end
		local line = { 0.8, 1.6, 0.8, 0 } -- one point a tick, through the whole gap and back
		local noisyTicks = 0
		for shake = 1, 30 do
			local sample = readAt(rig, character, (19 + shake) * 0.1, line[(shake - 1) % 4 + 1], 5)
			if sample.moving then
				noisyTicks += 1
			end
		end

		expect(noisyTicks).toBe(0)

		character:Destroy()
	end)

	it("after standing still, a tiptoer counts as moving once 1.8 studs from where they stood", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		rig.setGrounded(true)

		for step = 0, 19 do
			readAt(rig, character, step * 0.1, 0, 5) -- stands still for 2 seconds
		end
		local moving: { boolean } = {}
		for walk = 1, 10 do
			table.insert(moving, readAt(rig, character, (19 + walk) * 0.1, walk * 0.96, 5).moving)
		end

		expect(moving[1]).toBe(false) -- 0.96 studs from where they stood
		for index = 2, 10 do
			expect(moving[index]).toBe(true) -- 1.92 studs and on
		end

		character:Destroy()
	end)

	it("a ladder climber still counts as moving", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)

		local moving: { boolean } = {}
		for step = 0, 14 do
			table.insert(moving, readAt(rig, character, step * 0.1, 0, 5 + step * 1.12).moving)
		end

		expect(moving[1]).toBe(false)
		for index = 2, 15 do
			expect(moving[index]).toBe(true)
		end

		character:Destroy()
	end)

	it(
		"after moved(), a body placed 0.5 studs up that falls and lands over the next ticks gives no thudFrom and no moving sample",
		function()
			local character = makeCharacter(Vector3.new(0, 5, 0))
			local rig = groundSpeedRig(character)
			local tickNumber = 0
			for _ = 1, 10 do
				tickNumber += 1
				driveTick(rig, character, tickNumber, 0, 5, true, 0) -- stands still
			end

			rig.tracker:moved(1)
			local samples: { PlayerTracker.Sample } = {}
			local dropHeights = { 5.5, 5.33, 5.17, 5.0 }
			for index, height in dropHeights do
				if index == 1 then
					rig.setTakeoffs({ Vector3.new(0, 5, 0) }) -- a late Jumping state
				end
				tickNumber += 1
				table.insert(samples, driveTick(rig, character, tickNumber, 9.8, height, false, -12))
			end
			for _ = 1, 6 do
				tickNumber += 1
				table.insert(samples, driveTick(rig, character, tickNumber, 9.8, 5, true, 0))
			end

			for _, sample in samples do
				expect(sample.thudFrom).toBeNil()
				expect(sample.moving).toBe(false)
			end

			character:Destroy()
		end
	)

	it("an old position arriving once after the move is not walking", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		local tickNumber = 0
		for _ = 1, 10 do
			tickNumber += 1
			driveTick(rig, character, tickNumber, 0, 5, true, 0)
		end

		rig.tracker:moved(1)
		local xs = { 9.8, 0, 9.8, 9.8, 9.8, 9.8, 9.8 }
		for _, x in xs do
			tickNumber += 1
			local sample = driveTick(rig, character, tickNumber, x, 5, true, 0)
			expect(sample.moving).toBe(false)
			expect(sample.groundSpeed).toBe(0)
		end

		character:Destroy()
	end)

	it("after a rescue settles, a real jump and landing still thuds", function()
		local character = makeCharacter(Vector3.new(0, 5, 0))
		local rig = groundSpeedRig(character)
		local tickNumber = 0
		for _ = 1, 10 do
			tickNumber += 1
			driveTick(rig, character, tickNumber, 0, 5, true, 0)
		end

		rig.tracker:moved(1)
		local thuds = 0
		local function count(sample: PlayerTracker.Sample)
			if sample.thudFrom ~= nil then
				thuds += 1
			end
		end
		for _ = 1, 5 do
			tickNumber += 1
			count(driveTick(rig, character, tickNumber, 9.8, 5, true, 0)) -- the rescue settles
		end
		rig.setTakeoffs({ Vector3.new(9.8, 5, 0) })
		for height = 1, 4 do
			tickNumber += 1
			count(driveTick(rig, character, tickNumber, 9.8, 5 + height, false, if height < 3 then 20 else -20))
		end
		for _ = 1, 4 do
			tickNumber += 1
			count(driveTick(rig, character, tickNumber, 9.8, 5, true, 0))
		end

		expect(thuds).toBe(1)

		character:Destroy()
	end)

	it("a moved body still falling 1.5 s after the move thuds when it lands", function()
		local character = makeCharacter(Vector3.new(0, 300, 0))
		local rig = groundSpeedRig(character)
		local tickNumber = 0
		local height = 300
		for _ = 1, 3 do
			tickNumber += 1
			height -= 4
			driveTick(rig, character, tickNumber, 0, height, false, -40) -- a fast fall has started
		end

		rig.tracker:moved(1)
		local thuds = 0
		local function count(sample: PlayerTracker.Sample)
			if sample.thudFrom ~= nil then
				thuds += 1
			end
		end
		for _ = 1, 20 do
			tickNumber += 1
			height -= 4
			count(driveTick(rig, character, tickNumber, 0, height, false, -40)) -- 2.0 s in the air
		end
		for _ = 1, 4 do
			tickNumber += 1
			count(driveTick(rig, character, tickNumber, 0, height, true, 0))
		end

		expect(thuds).toBe(1)

		character:Destroy()
	end)
end)
