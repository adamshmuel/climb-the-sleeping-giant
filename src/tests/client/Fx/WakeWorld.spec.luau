--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local WakeWorld = require(StarterPlayer.StarterPlayerScripts.Client.Fx.WakeWorld)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local BIRD_COUNT = 24
local DUST_COUNT = 7
local FRAME = 1 / 60
-- Config.Wake gives the numbers; the flap angle is the module's own local (design 13, "Flap").
local SPEED = Config.Wake.BirdSpeedStuds
local FLAP_ANGLE = 0.6
-- The flight direction is (outward 0.8, up 0.6): design 13, "Flight".
local OUTWARD = 0.8
local UP = 0.6
local WING_OFFSET = 2 -- the template wings sit this far left and right of the body

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
	}
end

local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- One template bird like the real ones: a Body and a left and a right Wing, all anchored, with its pivot on the Body.
-- With wingFirst, it is like the real WakeBirds: no PrimaryPart, and a Wing comes before the Body in the children.
local function newBird(position: Vector3, wingFirst: boolean?): Model
	local bird = Instance.new("Model")
	bird.Name = "Bird"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CFrame = CFrame.new(position)
	if not wingFirst then
		body.Parent = bird
	end
	for _, side in { -1, 1 } do
		local wing = Instance.new("Part")
		wing.Name = "Wing"
		wing.Anchored = true
		wing.CFrame = CFrame.new(position + Vector3.new(side * WING_OFFSET, 0, 0))
		wing.Parent = bird
		if wingFirst and body.Parent == nil then
			body.Parent = bird
		end
	end
	if not wingFirst then
		bird.PrimaryPart = body
	end
	return bird
end

-- 24 birds behind him (z 46 to 100, like the world's), spread across x, with one exactly on the centre line.
local function newBirdFolder(wingFirst: boolean?): (Folder, { Vector3 })
	local folder = made(Instance.new("Folder"))
	local pivots: { Vector3 } = {}
	for i = 1, BIRD_COUNT do
		local position = Vector3.new(-90 + (i - 1) * (180 / (BIRD_COUNT - 1)), 50 + (i % 5) * 9, 46 + (i % 7) * 9)
		if i == 13 then
			position = Vector3.new(0, 70, 60)
		end
		newBird(position, wingFirst).Parent = folder
		table.insert(pivots, position)
	end
	return folder, pivots
end

local function newDust(): (Folder, { ParticleEmitter })
	local folder = made(Instance.new("Folder"))
	local emitters: { ParticleEmitter } = {}
	for i = 1, DUST_COUNT do
		local spot = Instance.new("Part")
		spot.Name = "DustSpot"
		spot.Anchored = true
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "WakeDust"
		emitter.Enabled = false
		emitter.Parent = spot
		spot.Position = Vector3.new(i, 80, 0)
		spot.Parent = folder
		table.insert(emitters, emitter)
	end
	return folder, emitters
end

local function flyingBirds(parent: Instance): { Model }
	local found: { Model } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Model") and child.Name == "Bird" then
			table.insert(found, child)
		end
	end
	return found
end

type Burst = { emitter: ParticleEmitter, count: number }
type Sound = { name: string, at: Vector3? }

-- Starts the module on fake parts with a fake clock and frame signal, recording every burst and sound.
local function setup(withSound: boolean?, wingFirst: boolean?)
	local giantState = made(Instance.new("Folder"))
	giantState:SetAttribute("Phase", "Asleep")
	local template, pivots = newBirdFolder(wingFirst)
	local dust, emitters = newDust()
	local parent = made(Instance.new("Folder"))
	local step = newSignal()
	local clock = { now = 100 }
	local bursts: { Burst } = {}
	local sounds: { Sound } = {}
	local stop = WakeWorld.start({
		giantState = giantState,
		birds = template,
		dust = dust,
		parent = parent,
		step = step :: any,
		now = function()
			return clock.now
		end,
		emit = function(emitter: ParticleEmitter, count: number)
			table.insert(bursts, { emitter = emitter, count = count })
		end,
		playSound = if withSound == false
			then nil
			else function(name: string, at: Vector3?)
				table.insert(sounds, { name = name, at = at })
			end,
	})
	table.insert(stops, stop)
	local rig = {
		parent = parent,
		pivots = pivots,
		emitters = emitters,
		bursts = bursts,
		sounds = sounds,
		stop = stop,
	}
	-- Phase changes reach the module a moment later (attribute signals are deferred), so each waits one frame.
	function rig.wake()
		giantState:SetAttribute("Phase", "Awake")
		task.wait()
	end
	function rig.sleep()
		giantState:SetAttribute("Phase", "Asleep")
		task.wait()
	end
	function rig.advance(seconds: number)
		clock.now += seconds
		step:Fire(seconds)
	end
	function rig.advanceFrames(frames: number)
		for _ = 1, frames do
			rig.advance(FRAME)
		end
	end
	return rig
end

local function burstsOf(rig: any, emitter: ParticleEmitter): number
	local n = 0
	for _, burst in rig.bursts do
		if burst.emitter == emitter then
			n += 1
		end
	end
	return n
end

local function pivotsOf(birds: { Model }): { Vector3 }
	local positions: { Vector3 } = {}
	for _, bird in birds do
		table.insert(positions, bird:GetPivot().Position)
	end
	return positions
end

-- The first Wing in `bird` whose rest side matches `side` (-1 left, 1 right), as its angle about the body's Z axis away
-- from where the template put it.
local function wingAngle(bird: Model, side: number): number
	local body = bird:FindFirstChild("Body") :: BasePart
	for _, child in bird:GetChildren() do
		if child.Name == "Wing" and child:IsA("BasePart") then
			local relative = body.CFrame:ToObjectSpace(child.CFrame)
			-- A rest wing sits at (side * WING_OFFSET, 0, 0); a flapped one is that, turned about the body's Z axis.
			if math.sign(relative.Position.X) == side then
				local _x, _y, z = relative:ToEulerAnglesXYZ()
				return z
			end
		end
	end
	error(`no wing on side {side}`)
end

describe("WakeWorld", function()
	it("has 24 birds under the parent at the wake", function()
		local rig = setup()
		rig.wake()
		expect(#flyingBirds(rig.parent)).toBe(BIRD_COUNT)
	end)

	it("flies each bird 45 studs, up 27 and 36 farther from the middle, never toward his face, in 1.5 s", function()
		local rig = setup()
		rig.wake()
		local birds = flyingBirds(rig.parent)
		local starts = pivotsOf(birds)
		rig.advanceFrames(90)
		local worstDistance, worstUp, worstOut, lowestZ = 0, 0, 0, math.huge
		for i, bird in birds do
			local now = bird:GetPivot().Position
			local start = starts[i]
			worstDistance = math.max(worstDistance, math.abs((now - start).Magnitude - SPEED * 1.5))
			worstUp = math.max(worstUp, math.abs(now.Y - start.Y - UP * SPEED * 1.5))
			local outNow = Vector3.new(now.X, 0, now.Z).Magnitude
			local outStart = Vector3.new(start.X, 0, start.Z).Magnitude
			worstOut = math.max(worstOut, math.abs(outNow - outStart - OUTWARD * SPEED * 1.5))
			lowestZ = math.min(lowestZ, now.Z - start.Z)
		end
		expect(#birds).toBe(BIRD_COUNT)
		expect(worstDistance).toBeLessThan(0.01)
		expect(worstUp).toBeLessThan(0.01)
		expect(worstOut).toBeLessThan(0.01)
		expect(lowestZ).toBeGreaterThanOrEqual(0)
	end)

	it("flaps each wing 0.6 rad one way at 0.0625 s, the other way at 0.1875 s and back to flat at 0.25 s", function()
		local rig = setup()
		rig.wake()
		local bird = flyingBirds(rig.parent)[1]
		rig.advance(0.0625)
		local rightUp, leftUp = wingAngle(bird, 1), wingAngle(bird, -1)
		rig.advance(0.125)
		local rightDown, leftDown = wingAngle(bird, 1), wingAngle(bird, -1)
		rig.advance(0.0625)
		local rightBack, leftBack = wingAngle(bird, 1), wingAngle(bird, -1)
		expect(math.abs(rightUp)).toBeCloseTo(FLAP_ANGLE, 2)
		expect(math.abs(leftUp)).toBeCloseTo(FLAP_ANGLE, 2)
		expect(rightDown).toBeCloseTo(-rightUp, 2)
		expect(leftDown).toBeCloseTo(-leftUp, 2)
		expect(rightBack).toBeCloseTo(0, 2)
		expect(leftBack).toBeCloseTo(0, 2)
	end)

	it("gives each of the 7 dust spots one burst of 20 at the wake and no more at 1.5 s", function()
		local rig = setup()
		rig.wake()
		rig.advanceFrames(90)
		for _, emitter in rig.emitters do
			expect(burstsOf(rig, emitter)).toBe(1)
		end
		for _, burst in rig.bursts do
			expect(burst.count).toBe(Config.Wake.DustBurst)
		end
		expect(#rig.bursts).toBe(DUST_COUNT)
	end)

	it("has no bird left at 3 s and one frame", function()
		local rig = setup()
		rig.wake()
		rig.advanceFrames(181)
		expect(#flyingBirds(rig.parent)).toBe(0)
	end)

	it("spawns 24 birds and 7 more bursts at a second wake, never 48 birds at once", function()
		local rig = setup()
		rig.wake()
		rig.advanceFrames(30)
		rig.sleep()
		rig.wake()
		expect(#flyingBirds(rig.parent)).toBe(BIRD_COUNT)
		expect(#rig.bursts).toBe(DUST_COUNT * 2)
	end)

	it("leaves no birds after stop, and a later wake does nothing", function()
		local rig = setup()
		rig.wake()
		rig.advanceFrames(30)
		rig.stop()
		expect(#flyingBirds(rig.parent)).toBe(0)
		rig.sleep()
		rig.wake()
		expect(#flyingBirds(rig.parent)).toBe(0)
		expect(#rig.bursts).toBe(DUST_COUNT)
	end)

	it("plays WakeBirds once per wake at a point inside the birds' area", function()
		local rig = setup()
		rig.wake()
		expect(#rig.sounds).toBe(1)
		expect(rig.sounds[1].name).toBe("WakeBirds")
		local at = rig.sounds[1].at :: Vector3
		local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
		for _, pivot in rig.pivots do
			low = low:Min(pivot)
			high = high:Max(pivot)
		end
		expect(at.X >= low.X and at.X <= high.X).toBe(true)
		expect(at.Y >= low.Y and at.Y <= high.Y).toBe(true)
		expect(at.Z >= low.Z and at.Z <= high.Z).toBe(true)
		rig.sleep()
		rig.wake()
		expect(#rig.sounds).toBe(2)
	end)

	it("still flies the birds when there is no playSound", function()
		local rig = setup(false)
		rig.wake()
		rig.advanceFrames(30)
		expect(#flyingBirds(rig.parent)).toBe(BIRD_COUNT)
	end)

	it("plays the birds and the dust with no Reduce Motion setting given (the module never reads one)", function()
		local rig = setup()
		rig.wake()
		expect(#flyingBirds(rig.parent)).toBe(BIRD_COUNT)
		expect(#rig.bursts).toBe(DUST_COUNT)
	end)

	it(
		"keeps each wing at its rest distance from the body when the bird has no PrimaryPart and a Wing comes first",
		function()
			local rig = setup(false, true)
			rig.wake()
			local birds = flyingBirds(rig.parent)
			local worst = 0
			for _ = 1, 10 do
				rig.advanceFrames(6)
				for _, bird in birds do
					local body = bird:FindFirstChild("Body") :: BasePart
					for _, child in bird:GetChildren() do
						if child.Name == "Wing" and child:IsA("BasePart") then
							worst = math.max(worst, math.abs((child.Position - body.Position).Magnitude - WING_OFFSET))
						end
					end
				end
			end
			expect(#birds).toBe(BIRD_COUNT)
			expect(worst).toBeLessThan(0.01)
		end
	)
end)
