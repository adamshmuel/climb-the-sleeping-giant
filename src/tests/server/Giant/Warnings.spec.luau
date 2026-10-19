--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Warnings = require(ServerScriptService.Server.Giant.Warnings)

-- Under strict typing a plain local widens "Asleep" to `string`, so each phase is declared with its type.
local ASLEEP: Config.Phase = "Asleep"
local AWAKE: Config.Phase = "Awake"
local HEAVY_SLEEP: Config.Phase = "HeavySleep"

describe("Warnings.new", function()
	it("both warnings start armed", function()
		local state = Warnings.new()
		expect(state[60]).toBe(true)
		expect(state[85]).toBe(true)
	end)
end)

describe("Warnings.update", function()
	it("rising past 60 fires the 60 warning", function()
		local fired = Warnings.update(Warnings.new(), 55, 62, ASLEEP)
		expect(fired).toEqual({ 60 })
	end)

	it("reaching exactly 60 counts as rising past it", function()
		local fired = Warnings.update(Warnings.new(), 59.9, 60, ASLEEP)
		expect(fired).toEqual({ 60 })
	end)

	it("staying above 60 doesn't fire it again", function()
		local fired = Warnings.update(Warnings.new(), 62, 65, ASLEEP)
		expect(fired).toEqual({})
	end)

	it("hovering around 60 fires it only once", function()
		local state = Warnings.new()
		local readings = { 59, 61, 59, 61, 58, 62 }
		local total = 0
		for index = 2, #readings do
			local fired
			fired, state = Warnings.update(state, readings[index - 1], readings[index], ASLEEP)
			total += #fired
		end
		expect(total).toBe(1)
	end)

	it("falling to 50 re-arms the 60 warning", function()
		local _, state = Warnings.update(Warnings.new(), 55, 62, ASLEEP)
		_, state = Warnings.update(state, 62, 50, ASLEEP)
		local fired = Warnings.update(state, 50, 62, ASLEEP)
		expect(fired).toEqual({ 60 })
	end)

	it("falling only to 51 doesn't re-arm it", function()
		local _, state = Warnings.update(Warnings.new(), 55, 62, ASLEEP)
		_, state = Warnings.update(state, 62, 51, ASLEEP)
		local fired = Warnings.update(state, 51, 62, ASLEEP)
		expect(fired).toEqual({})
	end)

	it("the 85 warning fires once and re-arms at 75 or lower", function()
		local fired, state = Warnings.update(Warnings.new(), 80, 86, ASLEEP)
		expect(fired).toEqual({ 85 })
		fired, state = Warnings.update(state, 86, 90, ASLEEP)
		expect(fired).toEqual({})
		fired, state = Warnings.update(state, 90, 76, ASLEEP)
		fired, state = Warnings.update(state, 76, 88, ASLEEP)
		expect(fired).toEqual({})
		fired, state = Warnings.update(state, 88, 75, ASLEEP)
		fired, state = Warnings.update(state, 75, 86, ASLEEP)
		expect(fired).toEqual({ 85 })
	end)

	it("one big jump past both marks fires 60 then 85", function()
		local fired = Warnings.update(Warnings.new(), 50, 90, ASLEEP)
		expect(fired).toEqual({ 60, 85 })
	end)

	it("nothing fires while he is Awake or in Heavy Sleep", function()
		expect((Warnings.update(Warnings.new(), 50, 90, AWAKE))).toEqual({})
		expect((Warnings.update(Warnings.new(), 50, 90, HEAVY_SLEEP))).toEqual({})
	end)

	it("the drop to 0 after Heavy Sleep re-arms both warnings", function()
		local both = { [60] = false, [85] = false }
		local _, state = Warnings.update(both, 100, 0, HEAVY_SLEEP)
		local fired = Warnings.update(state, 0, 90, ASLEEP)
		expect(fired).toEqual({ 60, 85 })
	end)

	it("update doesn't change the state it was given", function()
		local state = Warnings.new()
		Warnings.update(state, 50, 90, ASLEEP)
		expect(state).toEqual({ [60] = true, [85] = true })
		local disarmed = { [60] = false, [85] = false }
		Warnings.update(disarmed, 100, 0, HEAVY_SLEEP)
		expect(disarmed).toEqual({ [60] = false, [85] = false })
	end)
end)

describe("Warnings.freeSave", function()
	local WINDOW = Config.Meter.FreeSaveWarningSeconds

	it("a pass of 85 inside the 3 seconds after a save fires nothing", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local fired = Warnings.update(state, 80, 86, ASLEEP, 100 + WINDOW - 0.1)
		expect(fired).toEqual({})
	end)

	it("a pass of 85 inside the window still uses up the 85 mark", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local _, after = Warnings.update(state, 80, 86, ASLEEP, 101)
		expect(after[85]).toBe(false)
		-- After the window, a new pass of 85 without a fall to 75 in between: the mark is still used up.
		local fired = Warnings.update(after, 80, 86, ASLEEP, 110)
		expect(fired).toEqual({})
	end)

	it("after the window, a fall to 75 and a new pass of 85 fires 85 again", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local _, after = Warnings.update(state, 80, 86, ASLEEP, 101)
		local _, fallen = Warnings.update(after, 86, 75, ASLEEP, 104)
		local fired = Warnings.update(fallen, 75, 86, ASLEEP, 105)
		expect(fired).toEqual({ 85 })
	end)

	it("a pass of 85 exactly when the window ends fires the warning", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local fired = Warnings.update(state, 80, 86, ASLEEP, 100 + WINDOW)
		expect(fired).toEqual({ 85 })
	end)

	it("the 60 mark still fires inside the window", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local fired = Warnings.update(state, 55, 62, ASLEEP, 101)
		expect(fired).toEqual({ 60 })
	end)

	it("a pass of 60 and 85 together inside the window fires only 60", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local fired = Warnings.update(state, 50, 90, ASLEEP, 101)
		expect(fired).toEqual({ 60 })
	end)

	it("freeSave doesn't change the state it was given", function()
		local state = Warnings.new()
		Warnings.freeSave(state, 100)
		expect(state).toEqual({ [60] = true, [85] = true })
	end)

	it("without a clock reading, nothing is quieted", function()
		local state = Warnings.freeSave(Warnings.new(), 100)
		local fired = Warnings.update(state, 80, 86, ASLEEP)
		expect(fired).toEqual({ 85 })
	end)
end)
