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

describe("Cues.forName (Plan 7 Task 10: every slam is heard)", function()
	it("gives the four slam names their rows", function()
		local expected: { [string]: string } = {
			SlamCircle = 'Circle warning "whoosh"',
			SlamThud = "Fist thud",
			Bonk = "Bonk",
			Caught = 'Caught "whoosh"',
		}
		for name, row in expected do
			local found = Cues.forName(name)
			expect(found).never.toBe(nil)
			expect((found :: Cues.Cue).row).toBe(row)
			expect(SoundList.byName(row)).never.toBe(nil)
		end
	end)

	it("plays the thud at its row's own speed, 0.8", function()
		local found = Cues.forName("SlamThud") :: Cues.Cue
		local row = SoundList.byName(found.row) :: SoundList.Entry
		expect(row.speed).toBeCloseTo(0.8, PRECISION)
		expect(found.speed).toBe(nil)
	end)

	it("gives the bonk the twinkle as an extra row", function()
		local found = Cues.forName("Bonk") :: Cues.Cue
		expect(found.also).toEqual({ "Bonk twinkle" })
		expect(SoundList.byName("Bonk twinkle")).never.toBe(nil)
	end)

	it("keeps the bonk and leaves the twinkle out when the twinkle row is gone", function()
		local function withoutTwinkle(name: string): SoundList.Entry?
			if name == "Bonk twinkle" then
				return nil
			end
			return SoundList.byName(name)
		end
		local found = Cues.forName("Bonk", withoutTwinkle)
		expect(found).never.toBe(nil)
		local cue = found :: Cues.Cue
		expect(cue.row).toBe("Bonk")
		expect(table.find(cue.also or {}, "Bonk twinkle")).toBe(nil)
	end)
end)

local RANKS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local PLUCK = "Grab pluck"
local SHIMMER = "Grab shimmer"
local TOOT = "Egg home toot"
local HAPPY = "Egg home, Rare: happy hit"
local FANFARE = "Egg home, Epic and Legendary: fanfare"
local CHEER = "Egg home, Legendary: children's cheer"

-- Plan 7 Task 11 (Rule 95): the grab and egg-home sounds, grander for rarer eggs.
describe("Cues.grabName", function()
	it("gives Common and Uncommon the plain grab", function()
		expect(Cues.grabName("Common")).toBe("Grab")
		expect(Cues.grabName("Uncommon")).toBe("Grab")
	end)

	it("gives Rare, Epic and Legendary the shimmering grab", function()
		expect(Cues.grabName("Rare")).toBe("GrabShimmer")
		expect(Cues.grabName("Epic")).toBe("GrabShimmer")
		expect(Cues.grabName("Legendary")).toBe("GrabShimmer")
	end)

	it("gives a name that is not a rank, nil and a number nothing", function()
		expect(Cues.grabName("Shiny")).toBe(nil)
		expect(Cues.grabName(nil)).toBe(nil)
		expect(Cues.grabName(5)).toBe(nil)
	end)
end)

describe("Cues.homeName", function()
	it("gives Common and Uncommon the plain home toot", function()
		expect(Cues.homeName("Common")).toBe("Home")
		expect(Cues.homeName("Uncommon")).toBe("Home")
	end)

	it("gives Rare, Epic and Legendary their own names", function()
		expect(Cues.homeName("Rare")).toBe("HomeRare")
		expect(Cues.homeName("Epic")).toBe("HomeEpic")
		expect(Cues.homeName("Legendary")).toBe("HomeLegendary")
	end)

	it("gives a name that is not a rank, nil and a number nothing", function()
		expect(Cues.homeName("Shiny")).toBe(nil)
		expect(Cues.homeName(nil)).toBe(nil)
		expect(Cues.homeName(5)).toBe(nil)
	end)

	it("gives every rank a name that plays a cue", function()
		for _, rank in RANKS do
			local name = Cues.homeName(rank)
			expect(name).never.toBe(nil)
			expect(Cues.forName(name :: string)).never.toBe(nil)
			expect(Cues.forName(Cues.grabName(rank) :: string)).never.toBe(nil)
		end
	end)
end)

describe("Cues.forName (grab and egg home)", function()
	it("gives Grab the pluck at the row's own speed and no extra row", function()
		local found = Cues.forName("Grab") :: Cues.Cue
		expect(found.row).toBe(PLUCK)
		expect(found.speed).toBe(nil)
		expect(found.also).toBe(nil)
	end)

	it("gives GrabShimmer the pluck and the shimmer", function()
		local found = Cues.forName("GrabShimmer") :: Cues.Cue
		expect(found.row).toBe(PLUCK)
		expect(found.speed).toBe(nil)
		expect(found.also).toEqual({ SHIMMER })
	end)

	it("gives Home the toot alone", function()
		local found = Cues.forName("Home") :: Cues.Cue
		expect(found.row).toBe(TOOT)
		expect(found.speed).toBe(nil)
		expect(found.also).toBe(nil)
	end)

	it("gives HomeRare the toot and the happy hit", function()
		local found = Cues.forName("HomeRare") :: Cues.Cue
		expect(found.row).toBe(TOOT)
		expect(found.also).toEqual({ HAPPY })
	end)

	it("gives HomeEpic the toot and the fanfare", function()
		local found = Cues.forName("HomeEpic") :: Cues.Cue
		expect(found.row).toBe(TOOT)
		expect(found.also).toEqual({ FANFARE })
	end)

	it("gives HomeLegendary the toot, the fanfare and the cheer", function()
		local found = Cues.forName("HomeLegendary") :: Cues.Cue
		expect(found.row).toBe(TOOT)
		expect(found.also).toEqual({ FANFARE, CHEER })
	end)
end)

describe("Cues.forName (the egg pop)", function()
	it("gives SparklePop the Sparkle pop row at the row's own speed and no extra row", function()
		local found = Cues.forName("SparklePop") :: Cues.Cue
		expect(found.row).toBe("Sparkle pop")
		expect(found.speed).toBe(nil)
		expect(found.also).toBe(nil)
		expect(SoundList.byName(found.row)).never.toBe(nil)
	end)

	it('gives EggPop the Egg "pop" row at the row\'s own speed and no extra row', function()
		local found = Cues.forName("EggPop") :: Cues.Cue
		expect(found.row).toBe('Egg "pop"')
		expect(found.speed).toBe(nil)
		expect(found.also).toBe(nil)
		expect(SoundList.byName(found.row)).never.toBe(nil)
	end)
end)

describe("Cues.forName (the thud)", function()
	it('gives Thud the Thud "flump" row at the row\'s own speed and no extra row', function()
		local found = Cues.forName("Thud") :: Cues.Cue
		expect(found.row).toBe('Thud "flump"')
		expect(found.speed).toBe(nil)
		expect(found.also).toBe(nil)
		expect(SoundList.byName(found.row)).never.toBe(nil)
	end)
end)

describe("Cues.forName (the rescue poof)", function()
	it('gives RescuePoof the Rescue "poof" row at the row\'s own speed and no extra row', function()
		local found = Cues.forName("RescuePoof") :: Cues.Cue
		expect(found.row).toBe('Rescue "poof"')
		expect(found.speed).toBe(nil)
		expect(found.also).toBe(nil)
		expect(SoundList.byName(found.row)).never.toBe(nil)
	end)
end)
