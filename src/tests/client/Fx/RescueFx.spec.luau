--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local RescueFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.RescueFx)

local FROM = Vector3.new(10, 20, 30)
local TO = CFrame.new(-4, 8, 12) * CFrame.Angles(0, 1, 0)

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

type Emission = { part: string, emitter: string, count: number }

-- Starts the effect on a Folder with a fake clock and a spy on the emitters. A brand-new player stands for "me".
local function setup()
	local signal = newSignal()
	local parent = Instance.new("Folder")
	local emissions: { Emission } = {}
	local delays: { { seconds: number, fn: () -> () } } = {}
	local me = { Name = "Me" }
	local fx = RescueFx.start({
		rescued = signal :: any,
		parent = parent,
		after = function(seconds: number, fn: () -> ())
			table.insert(delays, { seconds = seconds, fn = fn })
		end,
		emit = function(emitter: ParticleEmitter, count: number)
			local owner = emitter.Parent
			table.insert(emissions, {
				part = if owner then owner.Name else "",
				emitter = emitter.Name,
				count = count,
			})
		end,
	})
	return {
		signal = signal,
		parent = parent,
		emissions = emissions,
		delays = delays,
		me = me,
		fx = fx,
	}
end

local function countFor(emissions: { Emission }, part: string, emitter: string): number?
	for _, emission in emissions do
		if emission.part == part and emission.emitter == emitter then
			return emission.count
		end
	end
	return nil
end

local function emitterOf(parent: Instance, part: string, name: string): ParticleEmitter
	local owner = parent:FindFirstChild(part) :: Instance
	return owner:FindFirstChild(name) :: ParticleEmitter
end

local function near(actual: Color3, expected: Color3): boolean
	return math.abs(actual.R - expected.R) < 0.01
		and math.abs(actual.G - expected.G) < 0.01
		and math.abs(actual.B - expected.B) < 0.01
end

local function firstAndLastNumber(sequence: NumberSequence): (number, number)
	return sequence.Keypoints[1].Value, sequence.Keypoints[#sequence.Keypoints].Value
end

local function firstAndLastColor(sequence: ColorSequence): (Color3, Color3)
	return sequence.Keypoints[1].Value, sequence.Keypoints[#sequence.Keypoints].Value
end

local function close(actual: number, expected: number): boolean
	return math.abs(actual - expected) < 1e-3
end

describe("RescueFx", function()
	local current: any = nil

	afterEach(function()
		if current ~= nil then
			current.fx.destroy()
			current.parent:Destroy()
			current = nil
		end
	end)

	it("one Rescued makes a puff where the player was and one where they are now", function()
		current = setup()
		current.signal:Fire(current.me, FROM, TO)
		local old = current.parent:FindFirstChild("RescuePuff_Old") :: Part
		local new = current.parent:FindFirstChild("RescuePuff_New") :: Part
		expect(old).never.toBeNil()
		expect(new).never.toBeNil()
		expect((old.Position - FROM).Magnitude < 0.01).toBe(true)
		expect((new.Position - TO.Position).Magnitude < 0.01).toBe(true)
	end)

	it("the old spot's puff emits 22 cloud and 14 sparkles, the landing's 30 and 18", function()
		current = setup()
		current.signal:Fire(current.me, FROM, TO)
		expect(#current.emissions).toBe(4)
		expect(countFor(current.emissions, "RescuePuff_Old", "Cloud")).toBe(22)
		expect(countFor(current.emissions, "RescuePuff_Old", "Sparkles")).toBe(14)
		expect(countFor(current.emissions, "RescuePuff_New", "Cloud")).toBe(30)
		expect(countFor(current.emissions, "RescuePuff_New", "Sparkles")).toBe(18)
	end)

	it("the puffs use the style guide's look", function()
		current = setup()
		current.signal:Fire(current.me, FROM, TO)
		local parent: Instance = current.parent
		local defaults = Instance.new("ParticleEmitter")
		for _, partName in { "RescuePuff_Old", "RescuePuff_New" } do
			local part = parent:FindFirstChild(partName) :: Part
			expect(part.Anchored).toBe(true)
			expect(part.Transparency).toBe(1)
			expect(part.CanCollide).toBe(false)
			expect(part.CanQuery).toBe(false)
			expect(part.CanTouch).toBe(false)

			local cloud = emitterOf(parent, partName, "Cloud")
			local sparkles = emitterOf(parent, partName, "Sparkles")
			expect(cloud.Rate).toBe(0)
			expect(sparkles.Rate).toBe(0)

			expect(cloud.Texture).toBe("rbxasset://textures/particles/smoke_main.dds")
			local cloudFrom, cloudTo = firstAndLastColor(cloud.Color)
			expect(near(cloudFrom, Color3.fromHex("E6EAFF"))).toBe(true)
			expect(near(cloudTo, Color3.fromHex("9AA8F5"))).toBe(true)
			local cloudSizeFrom, cloudSizeTo = firstAndLastNumber(cloud.Size)
			expect(close(cloudSizeFrom, 2.5) and close(cloudSizeTo, 6)).toBe(true)
			local cloudSeeFrom, cloudSeeTo = firstAndLastNumber(cloud.Transparency)
			expect(close(cloudSeeFrom, 0.05) and close(cloudSeeTo, 1)).toBe(true)
			expect(cloud.Lifetime).toBe(NumberRange.new(0.5, 0.8))
			expect(cloud.Speed).toBe(NumberRange.new(5, 9))
			expect(cloud.Drag).toBe(4)
			expect(cloud.LightEmission).toBe(0)
			expect(cloud.ZOffset).toBe(0)

			expect(sparkles.Texture).toBe("rbxasset://textures/particles/sparkles_main.dds")
			local sparkleFrom, sparkleTo = firstAndLastColor(sparkles.Color)
			expect(near(sparkleFrom, Color3.fromHex("FFC93C"))).toBe(true)
			expect(near(sparkleTo, Color3.fromHex("FFC93C"))).toBe(true)
			local sparkleSizeFrom, sparkleSizeTo = firstAndLastNumber(sparkles.Size)
			expect(close(sparkleSizeFrom, 1.4) and close(sparkleSizeTo, 0.5)).toBe(true)
			expect(sparkles.Transparency).toBe(defaults.Transparency)
			expect(sparkles.Lifetime).toBe(NumberRange.new(0.6, 0.9))
			expect(sparkles.Speed).toBe(NumberRange.new(6, 10))
			expect(sparkles.Drag).toBe(0)
			expect(close(sparkles.LightEmission, 0.6)).toBe(true)
			expect(sparkles.ZOffset).toBe(2)
		end
		defaults:Destroy()

		local landing = parent:FindFirstChild("RescuePuff_New") :: Part
		local old = parent:FindFirstChild("RescuePuff_Old") :: Part
		expect(old.Size).toBe(Vector3.new(1, 1, 1))
		expect(landing.Size).toBe(Vector3.new(3, 4, 3))
		for _, name in { "Cloud", "Sparkles" } do
			local emitter = emitterOf(parent, "RescuePuff_New", name)
			expect(emitter.Shape).toBe(Enum.ParticleEmitterShape.Cylinder)
			expect(emitter.ShapeInOut).toBe(Enum.ParticleEmitterShapeInOut.Outward)
		end
	end)

	it("both puffs are gone after 1 second", function()
		current = setup()
		current.signal:Fire(current.me, FROM, TO)
		expect(#current.parent:GetChildren()).toBe(2)
		expect(#current.delays > 0).toBe(true)
		for _, delay in current.delays do
			expect(delay.seconds <= 1).toBe(true)
		end
		local pending: { { seconds: number, fn: () -> () } } = table.clone(current.delays)
		for _, delay in pending do
			delay.fn()
		end
		expect(#current.parent:GetChildren()).toBe(0)
	end)

	it("a rescue of another player makes the puffs too", function()
		current = setup()
		current.signal:Fire({ Name = "Someone else" }, FROM, TO)
		expect(current.parent:FindFirstChild("RescuePuff_Old")).never.toBeNil()
		expect(current.parent:FindFirstChild("RescuePuff_New")).never.toBeNil()
		expect(#current.emissions).toBe(4)
	end)

	it("a Rescued with the wrong kinds of values makes nothing", function()
		current = setup()
		current.signal:Fire(current.me, "not a vector", TO)
		current.signal:Fire(current.me, FROM, Vector3.new(1, 2, 3))
		current.signal:Fire(current.me, nil, nil)
		current.signal:Fire(current.me, 5, {})
		expect(#current.parent:GetChildren()).toBe(0)
		expect(#current.emissions).toBe(0)
	end)

	it("after destroy, a Rescued makes nothing", function()
		current = setup()
		current.fx.destroy()
		current.signal:Fire(current.me, FROM, TO)
		expect(#current.parent:GetChildren()).toBe(0)
		expect(#current.emissions).toBe(0)
	end)
end)
