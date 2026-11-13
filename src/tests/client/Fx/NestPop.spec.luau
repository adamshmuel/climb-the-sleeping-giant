--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local NestPop = require(StarterPlayer.StarterPlayerScripts.Client.Fx.NestPop)

local BASE_TOP = 10 -- the egg's bottom sits here
local EGG_HEIGHT = 6
local STARS_ABOVE_BOTTOM = 3.2 -- spec section 6, "A new egg appears" (the card's decision: above the egg's bottom)

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

type Emission = { count: number, speedMin: number, speedMax: number, rotSpeedMax: number, acceleration: Vector3 }

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

local function newTemplate(): BasePart
	local shell = Instance.new("Part")
	shell.Name = "SparkleShell"
	shell.Size = Vector3.new(7, 7, 7)
	shell.Anchored = true
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Speed = NumberRange.new(5, 9)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Parent = shell
	return made(shell)
end

-- A spot like a real one: a Base and an Egg model (a 3 x 6 x 3 block) whose bottom sits on the Base's top.
local function newSpot(waiting: boolean?): Model
	local spot = Instance.new("Model")
	spot.Name = "EggSpot_Common_1"
	spot:SetAttribute("Rarity", "Common")
	if waiting ~= nil then
		spot:SetAttribute("Waiting", waiting)
	end
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(2, 0.2, 2)
	base.Anchored = true
	base.CFrame = CFrame.new(0, BASE_TOP - 0.1, 0)
	base.Parent = spot
	local egg = Instance.new("Model")
	egg.Name = "Egg"
	local body = Instance.new("Part")
	body.Size = Vector3.new(3, EGG_HEIGHT, 3)
	body.Anchored = true
	body.CFrame = CFrame.new(0, BASE_TOP + EGG_HEIGHT / 2, 0)
	body.Parent = egg
	egg.Parent = spot
	return made(spot)
end

local function eggOf(spot: Model): Model
	return spot:FindFirstChild("Egg") :: Model
end

local function bottomY(egg: Model): number
	local cf, size = egg:GetBoundingBox()
	return cf.Position.Y - size.Y / 2
end

-- Starts the pop on a Folder of spots with a fake clock, a fake frame signal and a spy on the emitters.
local function setup(spot: Model?, reduced: boolean?, withTemplate: boolean?)
	local root = made(Instance.new("Folder"))
	if spot ~= nil then
		spot.Parent = root
	end
	local step = newSignal()
	local clock = { now = 100 }
	local emissions: { Emission } = {}
	local stop = NestPop.start({
		root = root,
		template = if withTemplate == false then nil else newTemplate(),
		reducedMotion = function()
			return reduced == true
		end,
		step = step :: any,
		now = function()
			return clock.now
		end,
		emit = function(emitter: ParticleEmitter, count: number)
			table.insert(emissions, {
				count = count,
				speedMin = emitter.Speed.Min,
				speedMax = emitter.Speed.Max,
				rotSpeedMax = emitter.RotSpeed.Max,
				acceleration = emitter.Acceleration,
			})
		end,
	})
	table.insert(stops, stop)
	return {
		emissions = emissions,
		advance = function(seconds: number)
			clock.now += seconds
			step:Fire(seconds)
		end,
		set = function(target: Model, value: boolean?)
			target:SetAttribute("Waiting", value)
			task.wait()
		end,
	}
end

describe("NestPop.scaleAt", function()
	it("is 0 at 0 s, 1.1 at 0.15 s and 1.0 at 0.25 s", function()
		expect(NestPop.scaleAt(0)).toBeCloseTo(0, 3)
		expect(NestPop.scaleAt(0.15)).toBeCloseTo(1.1, 3)
		expect(NestPop.scaleAt(0.25)).toBeCloseTo(1.0, 3)
	end)

	it("stays at 1 after 0.25 s", function()
		expect(NestPop.scaleAt(0.4)).toBe(1)
		expect(NestPop.scaleAt(5)).toBe(1)
	end)
end)

describe("NestPop.start", function()
	it("plays one pop when Waiting goes from false to true", function()
		local spot = newSpot(false)
		local run = setup(spot)
		run.set(spot, true)
		expect(#run.emissions).toBe(1)
		expect(run.emissions[1].count).toBe(30)
		expect(spot:FindFirstChild("RefillPop")).never.toBeNil()
	end)

	it("plays none for a spot that is already waiting when it starts", function()
		local spot = newSpot(true)
		local run = setup(spot)
		run.advance(0.1)
		expect(#run.emissions).toBe(0)
		expect(spot:FindFirstChild("RefillPop")).toBeNil()
	end)

	it("plays none when Waiting goes from nil to true", function()
		local spot = newSpot(nil)
		local run = setup(spot)
		run.set(spot, true)
		expect(#run.emissions).toBe(0)
		expect(spot:FindFirstChild("RefillPop")).toBeNil()
	end)

	it("puts the stars 3.2 studs above the egg's bottom and removes them after 1.5 s", function()
		local spot = newSpot(false)
		local run = setup(spot)
		run.set(spot, true)
		local stars = spot:FindFirstChild("RefillPop") :: BasePart
		expect(stars.Position.Y).toBeCloseTo(BASE_TOP + STARS_ABOVE_BOTTOM, 2)
		run.advance(1.4)
		expect(spot:FindFirstChild("RefillPop")).never.toBeNil()
		run.advance(0.2)
		expect(spot:FindFirstChild("RefillPop")).toBeNil()
	end)

	it("grows the egg in 0 to 1.1 to 1.0 with its bottom moving at most 0.05 studs", function()
		local spot = newSpot(false)
		local egg = eggOf(spot)
		local run = setup(spot)
		run.set(spot, true)
		expect(egg:GetScale() <= 0.3).toBe(true)
		local worstDrift = math.abs(bottomY(egg) - BASE_TOP)
		local biggest = egg:GetScale()
		for _ = 1, 5 do
			run.advance(0.05)
			worstDrift = math.max(worstDrift, math.abs(bottomY(egg) - BASE_TOP))
			biggest = math.max(biggest, egg:GetScale())
		end
		expect(biggest).toBeCloseTo(1.1, 1)
		expect(egg:GetScale()).toBeCloseTo(1, 3)
		expect(worstDrift <= 0.05).toBe(true)
	end)

	it("under Reduce Motion emits 14 still stars and leaves the egg at full size at once", function()
		local spot = newSpot(false)
		local egg = eggOf(spot)
		local run = setup(spot, true)
		run.set(spot, true)
		expect(#run.emissions).toBe(1)
		local emission = run.emissions[1]
		expect(emission.count).toBe(14)
		expect(emission.speedMin).toBe(0)
		expect(emission.speedMax).toBe(0)
		expect(emission.rotSpeedMax).toBe(0)
		expect(emission.acceleration).toEqual(Vector3.zero)
		expect(egg:GetScale()).toBeCloseTo(1, 3)
		run.advance(0.1)
		expect(egg:GetScale()).toBeCloseTo(1, 3)
	end)
end)
