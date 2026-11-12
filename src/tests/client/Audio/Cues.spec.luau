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

	it("gives each wake name its row, with its delay and fade", function()
		local expected: { [string]: { row: string, delay: number?, fade: { after: number, seconds: number }? } } = {
			WakeEyes = { row = '"!" sting' },
			WakeRoar = { row = "Cartoon roar (no words)" },
			WakeRumble = { row = "Rumble", fade = { after = 0, seconds = 1 } },
			WakeBirds = { row = "Birds flapping", delay = 0.2 },
			ZzzPop = { row = "Z Z Z popping", delay = 0.3 },
			LieDown = { row = "Big yawn" },
			Boing = { row = 'Bounce-off "boing"' },
		}
		for name, want in expected do
			local found = Cues.forName(name)
			expect(found).never.toBe(nil)
			local cue = found :: Cues.Cue
			expect(cue.row).toBe(want.row)
			expect(SoundList.byName(cue.row)).never.toBe(nil)
			expect(cue.delay).toEqual(want.delay)
			expect(cue.fade).toEqual(want.fade)
		end
	end)

	it("gives LieDown nothing when the yawn row is not in the list (Rule 92's fallback)", function()
		local function withoutYawn(rowName: string): SoundList.Entry?
			if rowName == "Big yawn" then
				return nil
			end
			return SoundList.byName(rowName)
		end
		expect(Cues.forName("LieDown", withoutYawn)).toBe(nil)
		expect(Cues.forName("WakeRoar", withoutYawn)).never.toBe(nil) -- other rows still found
	end)
end)
