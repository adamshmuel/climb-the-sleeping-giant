--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local GiantDirector = require(ServerScriptService.Server.Giant.GiantDirector)
local Helpers = require(script.Parent.Helpers)
local addPlayer = Helpers.addPlayer
local cleanUp = Helpers.cleanUp
local meter = Helpers.meter
local newHarness = Helpers.newHarness
local sample = Helpers.sample
local stepTimes = Helpers.stepTimes

afterEach(cleanUp)

describe("GiantDirector Meter writes", function()
	it("rounds the written Meter to 0.1", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", { tiptoe = true, carrying = "Uncommon" })
		harness.samples = { sample(1, "Belly", true, nil, nil, 9.6) }
		-- Belly 1.5 x walk 4 x Uncommon 1.5 x tiptoe 0.2 = 1.8 a second, minus 1.5 of drain.
		-- Each step is +0.03, so 10 steps end at 10.3; two steps end at 10.06, which shows as 10.1.
		stepTimes(harness, 2)
		expect(meter(harness)).toBe(10.1)
	end)

	it("writes Meter only when its rounded value changes", function()
		local harness = newHarness(10)
		addPlayer(harness, 1, "Mia", { tiptoe = true, carrying = "Uncommon" })
		harness.samples = { sample(1, "Belly", true, nil, nil, 9.6) }
		local writes = 0
		local connection = harness.state:GetAttributeChangedSignal("Meter"):Connect(function()
			writes += 1
		end)
		-- Each step is +0.03 (1.8 a second of noise, minus 1.5 of drain). Step 1 ends at 10.03, which still shows
		-- as 10.0: no write.
		stepTimes(harness, 1)
		task.wait()
		expect(writes).toBe(0)
		expect(meter(harness)).toBe(10)
		-- Step 2 ends at 10.06, which shows as 10.1: one write.
		stepTimes(harness, 1)
		task.wait()
		expect(writes).toBe(1)
		expect(meter(harness)).toBe(10.1)
		connection:Disconnect()
	end)

	it("does not write at all when nothing changes the meter", function()
		local harness = newHarness(0)
		local writes = 0
		local connection = harness.state:GetAttributeChangedSignal("Meter"):Connect(function()
			writes += 1
		end)
		stepTimes(harness, 10)
		task.wait()
		expect(writes).toBe(0)
		connection:Disconnect()
	end)
end)

-- A stand-in for Heartbeat: Connect, Fire and Disconnect, all in plain Luau.
local function newHeartbeat()
	local handlers: { (number) -> () } = {}
	return {
		Connect = function(_self: any, callback: (number) -> ())
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
		Fire = function(_self: any, dt: number)
			for _, handler in table.clone(handlers) do
				handler(dt)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

describe("GiantDirector.run", function()
	local function start(maxSteps: number)
		local steps = 0
		local heartbeat = newHeartbeat()
		local stop = GiantDirector.run({
			step = function()
				steps += 1
			end,
		}, heartbeat, Config.Tick.Seconds, maxSteps)
		return heartbeat, stop, function()
			return steps
		end
	end

	it("runs one step for every 0.1 seconds", function()
		local heartbeat, stop, steps = start(3)
		heartbeat:Fire(0.1)
		heartbeat:Fire(0.1)
		expect(steps()).toBe(2)
		stop()
	end)

	it("adds up short frames before it steps", function()
		local heartbeat, stop, steps = start(3)
		heartbeat:Fire(0.04)
		heartbeat:Fire(0.04)
		expect(steps()).toBe(0)
		heartbeat:Fire(0.04)
		expect(steps()).toBe(1)
		stop()
	end)

	it("runs at most 3 steps in one frame and drops the rest", function()
		local heartbeat, stop, steps = start(3)
		heartbeat:Fire(2)
		expect(steps()).toBe(3)
		heartbeat:Fire(0.05)
		expect(steps()).toBe(3)
		stop()
	end)

	it("stops stepping and disconnects when cleaned up", function()
		local heartbeat, stop, steps = start(3)
		expect(heartbeat:count()).toBe(1)
		stop()
		expect(heartbeat:count()).toBe(0)
		heartbeat:Fire(1)
		expect(steps()).toBe(0)
	end)
end)
