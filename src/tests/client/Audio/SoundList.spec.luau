--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local SoundList = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundList)

-- Float numbers like 0.2 * 2 compare to about 0.01 (luau.md, "Test first").
local PRECISION = 2

type Row = {
	name: string,
	id: number,
	maker: string,
	group: string,
	loudness: number,
	speed: number?,
	length: number,
}

local function row(
	name: string,
	id: number,
	maker: string,
	group: string,
	loudness: number,
	speed: number?,
	length: number
): Row
	return { name = name, id = id, maker = maker, group = group, loudness = loudness, speed = speed, length = length }
end

local PSE = "ProSoundEffects"
local APM = "APMOfficial"
local RBX = "Roblox"
local YOU = "JustForYou"
local VALLEY = "WholeValley"
local NEAR = "Nearby"

-- Spec 7 section 5, "Every sound" (30 rows, in table order). Lengths: research/decisions-audio.md section 2, with
-- the round 1 rows for the snort, the yawn (Tired 13) and the cheer. A row with a speed range has speed nil here.
local EXPECTED: { Row } = {
	row("Calm tune (loop)", 9045117358, APM, YOU, 0.2, 1, 130.1),
	row("Chase tune (loop)", 9042777456, APM, YOU, 0.3, 1, 104.3),
	row("Snore (loop)", 9114663574, PSE, VALLEY, 0.8, nil, 5.7),
	row("Heavy Sleep snore (loop)", 9114663574, PSE, VALLEY, 0.9, nil, 5.7),
	row("85% snort (two)", 9114663574, PSE, VALLEY, 1.0, 1, 5.7),
	row('"Mmm..." mumble', 9114628818, PSE, VALLEY, 0.9, 1, 2.1),
	row('"!" sting', 1848272916, APM, YOU, 0.35, 1, 2.6),
	row("Cartoon roar (no words)", 9114624494, PSE, VALLEY, 0.8, 0.8, 2.1),
	row("Rumble", 9114221327, PSE, YOU, 1.4, 1, 4.3),
	row("Birds flapping", 9113444620, PSE, VALLEY, 2.3, 1, 2.1),
	row("Z Z Z popping", 9113537815, PSE, VALLEY, 0.4, 1, 1.0),
	row('Bounce-off "boing"', 12222124, RBX, NEAR, 0.5, 1, 0.6),
	row('Circle warning "whoosh"', 9120733724, PSE, NEAR, 1.1, 1, 1.5),
	row("Fist thud", 9113480915, PSE, VALLEY, 0.95, 0.8, 1.1),
	row("Bonk", 9113496949, PSE, NEAR, 1.0, 1, 0.75),
	row("Bonk twinkle", 9116394876, PSE, NEAR, 2.6, 1, 2.0),
	row('Caught "whoosh"', 15675024286, RBX, YOU, 0.55, 1, 0.85),
	row('Egg "pop"', 15675055424, RBX, NEAR, 0.5, 1, 2.7),
	row("Big yawn", 9116304896, PSE, VALLEY, 2.1, 0.8, 0.95),
	row("Grab pluck", 9126163250, PSE, YOU, 1.0, 1, 1.1),
	row("Grab shimmer", 9116395089, PSE, YOU, 3.8, 1, 2.5),
	row("Sparkle pop", 9116394876, PSE, NEAR, 2.6, 1, 2.0),
	row("Egg home toot", 9117241247, PSE, YOU, 0.8, 1, 1.1),
	row("Egg home, Rare: happy hit", 1848287311, APM, YOU, 0.3, 1, 2.7),
	row("Egg home, Epic and Legendary: fanfare", 1842335078, APM, YOU, 1.9, 1, 3.2),
	row("Egg home, Legendary: children's cheer", 1841221347, APM, YOU, 0.55, 1, 2.9),
	row('Thud "flump"', 9113819689, PSE, NEAR, 0.5, 1, 0.6),
	row("Tiptoe click", 15675059323, RBX, YOU, 0.4, 1, 0.4),
	row('Rescue "poof"', 9116406610, PSE, NEAR, 0.6, 1, 1.2),
	row("Music button click", 15675059323, RBX, YOU, 0.4, 1, 0.4),
}

local function find(name: string): SoundList.Entry
	local entry = SoundList.byName(name)
	if entry == nil then
		error(`no sound named {name}`)
	end
	return entry
end

-- The volume a curve gives at a distance: straight lines between its points, flat beyond the first and last.
local function curveAt(curve: { [number]: number }, distance: number): number
	local keys: { number } = {}
	for key in curve do
		table.insert(keys, key)
	end
	table.sort(keys)
	if distance <= keys[1] then
		return curve[keys[1]]
	end
	for i = 2, #keys do
		local from, to = keys[i - 1], keys[i]
		if distance <= to then
			local share = (distance - from) / (to - from)
			return curve[from] + (curve[to] - curve[from]) * share
		end
	end
	return curve[keys[#keys]]
end

describe("SoundList", function()
	it("has 30 rows and 26 different files", function()
		expect(#SoundList.entries).toBe(30)
		local ids: { [number]: boolean } = {}
		local different = 0
		for _, entry in SoundList.entries do
			if not ids[entry.id] then
				ids[entry.id] = true
				different += 1
			end
		end
		expect(different).toBe(26)
	end)

	it("every row matches its row in spec section 5", function()
		for index, expected in EXPECTED do
			local entry = SoundList.entries[index]
			expect(entry ~= nil).toBe(true)
			expect(entry.name).toBe(expected.name)
			expect(entry.id).toBe(expected.id)
			expect(entry.maker).toBe(expected.maker)
			expect(entry.group).toBe(expected.group)
			expect(entry.loudness).toBeCloseTo(expected.loudness, PRECISION)
			expect(entry.length).toBeCloseTo(expected.length, PRECISION)
			if expected.speed ~= nil then
				expect(entry.speed).toBeCloseTo(expected.speed, PRECISION)
			else
				expect(entry.speed).toBe(nil)
			end
		end
	end)

	it("the snore speeds come from Config.Audio", function()
		local snore = find("Snore (loop)")
		expect(snore.speedMin).toBeCloseTo(Config.Audio.SnoreSpeed.Min, PRECISION)
		expect(snore.speedMax).toBeCloseTo(Config.Audio.SnoreSpeed.Max, PRECISION)
		local heavy = find("Heavy Sleep snore (loop)")
		expect(heavy.speedMin).toBeCloseTo(Config.Audio.HeavySleepSnoreSpeed.Min, PRECISION)
		expect(heavy.speedMax).toBeCloseTo(Config.Audio.HeavySleepSnoreSpeed.Max, PRECISION)
	end)

	it("every maker is Roblox, ProSoundEffects or APMOfficial (Rule 85)", function()
		local allowed = { Roblox = true, ProSoundEffects = true, APMOfficial = true }
		for _, entry in SoundList.entries do
			expect(allowed[entry.maker]).toBe(true)
		end
	end)

	it("every row has one of the three hearing groups (Rule 86)", function()
		local allowed = { JustForYou = true, WholeValley = true, Nearby = true }
		for _, entry in SoundList.entries do
			expect(allowed[entry.group]).toBe(true)
		end
	end)

	it("the flump has three loudnesses: 0.5, 0.7 and 0.85", function()
		local flump = find('Thud "flump"')
		expect(flump.loudnessByThud).toEqual({ [20] = 0.5, [30] = 0.7, [40] = 0.85 })
	end)

	it("only the mumble and the snort play one at a time (Rule 91)", function()
		local oneAtATime: { string } = {}
		for _, entry in SoundList.entries do
			if entry.oneAtATime == true then
				table.insert(oneAtATime, entry.name)
			end
		end
		table.sort(oneAtATime)
		expect(oneAtATime).toEqual({ '"Mmm..." mumble', "85% snort (two)" })
	end)

	it("the yawn's file is neither the roar's nor the mumble's (Rule 92)", function()
		local yawn = find("Big yawn")
		expect(yawn.id).never.toBe(find("Cartoon roar (no words)").id)
		expect(yawn.id).never.toBe(find('"Mmm..." mumble').id)
	end)

	it("the snort is the snore file from 3.46 to 3.86 s with a 0.05 s fade, and ends before the file does", function()
		local snort = find("85% snort (two)")
		expect(snort.id).toBe(find("Snore (loop)").id)
		expect(snort.fileStart).toBeCloseTo(3.46, PRECISION)
		expect(snort.fileEnd).toBeCloseTo(3.86, PRECISION)
		expect(snort.endFade).toBeCloseTo(0.05, PRECISION)
		expect(snort.fileEnd :: number).toBeLessThan(snort.length)
	end)

	it("the second snort is a touch deeper: speed 0.9", function()
		expect(find("85% snort (two)").secondSpeed).toBeCloseTo(0.9, PRECISION)
	end)

	it("the calm tune loops from 0.05 to 127.7 s and the chase tune from 0.3 to 102.35 s", function()
		local calm = find("Calm tune (loop)")
		expect(calm.loopStart).toBeCloseTo(0.05, PRECISION)
		expect(calm.loopEnd).toBeCloseTo(127.7, PRECISION)
		local chase = find("Chase tune (loop)")
		expect(chase.loopStart).toBeCloseTo(0.3, PRECISION)
		expect(chase.loopEnd).toBeCloseTo(102.35, PRECISION)
		expect(chase.fileStart).toBeCloseTo(0.3, PRECISION)
	end)

	it("every loop part and file part sits inside its file", function()
		for _, entry in SoundList.entries do
			if entry.loopStart ~= nil and entry.loopEnd ~= nil then
				expect(entry.loopStart).toBeLessThan(entry.loopEnd)
				expect(entry.loopEnd).toBeLessThanOrEqual(entry.length)
			end
			expect(entry.fileStart).toBeLessThan(entry.length)
		end
	end)
end)

describe("SoundList.playerVolume", function()
	it("doubles the spec's number: 0.2 gives 0.4 and 3.8 gives 7.6", function()
		expect(SoundList.playerVolume(0.2)).toBeCloseTo(0.4, PRECISION)
		expect(SoundList.playerVolume(3.8)).toBeCloseTo(7.6, PRECISION)
	end)

	it("every converted volume is above 0 and at most 10", function()
		for _, entry in SoundList.entries do
			local volume = SoundList.playerVolume(entry.loudness)
			expect(volume).toBeGreaterThan(0)
			expect(volume).toBeLessThanOrEqual(10)
			local steps: { [number]: number } = entry.loudnessByThud or {}
			for _, step in steps do
				local converted = SoundList.playerVolume(step)
				expect(converted).toBeGreaterThan(0)
				expect(converted).toBeLessThanOrEqual(10)
			end
		end
	end)
end)

describe("the hearing curves", function()
	it("Whole valley: 1 at 60 studs, at least a third at 200, 0.2 at 1,000", function()
		local curve = Config.Audio.WholeValleyCurve
		expect(curveAt(curve, 60)).toBeCloseTo(1, PRECISION)
		expect(curveAt(curve, 200)).toBeGreaterThanOrEqual(1 / 3)
		expect(curveAt(curve, 1000)).toBeCloseTo(0.2, PRECISION)
	end)

	it("Nearby: 1 at 10 studs and 0 at 80", function()
		local curve = Config.Audio.NearbyCurve
		expect(curveAt(curve, 10)).toBeCloseTo(1, PRECISION)
		expect(curveAt(curve, 80)).toBeCloseTo(0, PRECISION)
	end)
end)

describe("SoundList.byName", function()
	it("finds a row by its name", function()
		local found = SoundList.byName("Bonk")
		expect(found).never.toBe(nil)
		expect((found :: SoundList.Entry).id).toBe(9113496949)
	end)

	it("gives nil for a name that is not in the list", function()
		expect(SoundList.byName("No such sound")).toBeNil()
	end)
end)
