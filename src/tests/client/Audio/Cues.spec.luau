--!strict
-- Cues (plan 7 Task 8): each sound place's name to the board's row and speed.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Cues = require(StarterPlayer.StarterPlayerScripts.Client.Audio.Cues)
local SoundList = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundList)

local PRECISION = 2

describe("Cues.forName", function()
	it("gives Snort1 the snort row at speed 1", function()
		local cue = Cues.forName("Snort1")
		expect(cue).never.toBe(nil)
		local found = cue :: Cues.Cue
		expect(found.row).toBe("85% snort (two)")
		expect(found.speed).toBeCloseTo(1, PRECISION)
	end)

	it("gives Snort2 the snort row at the row's second speed, 0.9", function()
		local found = Cues.forName("Snort2") :: Cues.Cue
		expect(found.row).toBe("85% snort (two)")
		expect(found.speed).toBeCloseTo(0.9, PRECISION)
		local row = SoundList.byName(found.row) :: SoundList.Entry
		expect(found.speed).toBeCloseTo(row.secondSpeed :: number, PRECISION)
	end)

	it("gives Mumble the mumble row", function()
		local found = Cues.forName("Mumble") :: Cues.Cue
		expect(found.row).toBe('"Mmm..." mumble')
		expect(SoundList.byName(found.row)).never.toBe(nil)
	end)

	it("gives every other name nothing", function()
		expect(Cues.forName("NoSuchPlace")).toBe(nil)
		expect(Cues.forName("")).toBe(nil)
		expect(Cues.forName("snort1")).toBe(nil)
	end)
end)
