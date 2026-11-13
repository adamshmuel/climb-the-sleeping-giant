--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SoundCheck = require(ServerStorage.Tools.play.SoundCheck)

-- Gate 4 sound check (plan 7 Task 19, Rule 99): `run` plays the moments in order with one recording fake, so nothing needs
-- a world. Each beat reads the recorded calls.
describe("SoundCheck.run", function()
	local SPOT_POSITION = Vector3.new(10, 5, 20)
	local SPOT_SIZE = Vector3.new(2, 0.2, 2)
	local ROOT = CFrame.new(1, 2, 3)

	type Rig = { deps: SoundCheck.Deps, calls: { string }, logs: { string }, plotAsked: { number } }

	-- A recording fake: every call writes one text line into `calls`, in the order it happened.
	local function newRig(phase: string, hasSpot: boolean, hasRoot: boolean): Rig
		local calls: { string } = {}
		local logs: { string } = {}
		local plotAsked: { number } = {}
		local spot = { Position = SPOT_POSITION, Size = SPOT_SIZE }
		local player = {
			Name = "Tester",
			GetAttribute = function(_self: any, name: string): any
				if name == "PlotIndex" then
					return 3
				end
				return nil
			end,
		}
		local deps: SoundCheck.Deps = {
			player = player,
			homeSpot = function(plotIndex: number): BasePart?
				table.insert(plotAsked, plotIndex)
				if hasSpot then
					return spot :: any
				end
				return nil
			end,
			rootCFrame = function(): CFrame?
				if hasRoot then
					return ROOT
				end
				return nil
			end,
			phase = function(): string
				return phase
			end,
			fireEggHome = function(_player: any, rarity: string, position: Vector3)
				table.insert(calls, `egg {rarity} {position.X},{position.Y},{position.Z}`)
			end,
			fireWarning = function(mark: number, kind: string)
				table.insert(calls, `warning {mark} {kind}`)
			end,
			fireRescued = function(_player: any, from: Vector3, to: CFrame)
				table.insert(calls, `rescued {from.X},{from.Y},{from.Z} to {to.X},{to.Y},{to.Z}`)
			end,
			setMeter = function(value: number)
				table.insert(calls, `meter {value}`)
			end,
			wait = function(seconds: number)
				table.insert(calls, `wait {seconds}`)
			end,
			log = function(line: string)
				table.insert(logs, line)
			end,
		}
		return { deps = deps, calls = calls, logs = logs, plotAsked = plotAsked }
	end

	-- The recorded calls without the waits.
	local function withoutWaits(calls: { string }): { string }
		local out: { string } = {}
		for _, line in calls do
			if string.sub(line, 1, 4) ~= "wait" then
				table.insert(out, line)
			end
		end
		return out
	end

	it("plays an egg home of each rank in order at the top of the player's HomeSpot_1", function()
		local rig = newRig("Asleep", true, true)
		SoundCheck.run(rig.deps)
		local top = SPOT_POSITION + Vector3.new(0, SPOT_SIZE.Y / 2, 0)
		local expected: { string } = {}
		for _, rarity in Config.RarityOrder do
			table.insert(expected, `egg {rarity} {top.X},{top.Y},{top.Z}`)
		end
		local played = withoutWaits(rig.calls)
		local eggs: { string } = {}
		for index = 1, #expected do
			table.insert(eggs, played[index] or "missing")
		end
		expect(eggs).toEqual(expected)
		expect(rig.plotAsked).toEqual({ 3 })
	end)

	it("plays a free save: the 85 warning with the free-save kind", function()
		local rig = newRig("Asleep", true, true)
		SoundCheck.run(rig.deps)
		expect(table.find(rig.calls, `warning 85 {Net.FreeSaveKind}`) ~= nil).toBe(true)
	end)

	it("plays a rescue from and to where the player stands", function()
		local rig = newRig("Asleep", true, true)
		SoundCheck.run(rig.deps)
		expect(table.find(rig.calls, "rescued 1,2,3 to 1,2,3") ~= nil).toBe(true)
	end)

	it("wakes the giant by filling the meter, only while he is asleep", function()
		local asleep = newRig("Asleep", true, true)
		SoundCheck.run(asleep.deps)
		expect(table.find(asleep.calls, `meter {Config.Meter.Max}`) ~= nil).toBe(true)

		local awake = newRig("Awake", true, true)
		SoundCheck.run(awake.deps)
		expect(table.find(awake.calls, `meter {Config.Meter.Max}`) == nil).toBe(true)
		local logged = false
		for _, line in awake.logs do
			if string.find(line, "wake", 1, true) ~= nil and string.find(line, "Awake", 1, true) ~= nil then
				logged = true
			end
		end
		expect(logged).toBe(true)
	end)
end)
