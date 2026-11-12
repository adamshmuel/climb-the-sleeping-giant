--!strict
-- Every sound of spec 7 section 5 ("Every sound"): its file, maker, hearing group, the spec's loudness, speed, where it
-- starts, its loop part and its measured length. Pure: no sound object is made here.
-- Lengths are designer's measurements (research/decisions-audio.md section 2; the round 1 rows replace it for the
-- snort, the yawn and the cheer). A file shared by several rows (the snore, the twinkle, the click) has one length.
-- The spec keeps its own loudness numbers; playerVolume converts them for AudioPlayer (plan 7, "The loudness scale").
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Maker = "Roblox" | "ProSoundEffects" | "APMOfficial"
export type Group = "JustForYou" | "WholeValley" | "Nearby"
export type Entry = {
	name: string,
	id: number,
	maker: Maker,
	group: Group,
	-- The spec's loudness (not yet doubled). The flump's is its +20 thud one; loudnessByThud lists all three.
	loudness: number,
	-- Thud size (+20, +30, +40 or more) -> spec loudness (Rule 96). Only the flump has it.
	loudnessByThud: { [number]: number }?,
	-- One fixed speed, or a random speed between speedMin and speedMax (picked each time the loop starts).
	speed: number?,
	speedMin: number?,
	speedMax: number?,
	secondSpeed: number?, -- the second of two plays at its own speed (the second snort)
	fileStart: number, -- seconds into the file where playing starts
	fileEnd: number?, -- seconds into the file where it stops, for a cut of a file (the snort)
	endFade: number?, -- seconds of fade at the end of a cut, so it doesn't click
	loopStart: number?, -- the loop part, in seconds into the file
	loopEnd: number?,
	length: number, -- the whole file, in seconds
	oneAtATime: boolean?, -- a new play stops the old one first (Rule 91)
}

local PSE: Maker = "ProSoundEffects"
local APM: Maker = "APMOfficial"
local RBX: Maker = "Roblox"
local YOU: Group = "JustForYou"
local VALLEY: Group = "WholeValley"
local NEAR: Group = "Nearby"

local SNORE_ID = 9114663574
local SNORE_LENGTH = 5.7
local TWINKLE_ID = 9116394876
local CLICK_ID = 15675059323

local function entry(name: string, id: number, maker: Maker, group: Group, loudness: number, length: number): Entry
	return {
		name = name,
		id = id,
		maker = maker,
		group = group,
		loudness = loudness,
		speed = 1,
		fileStart = 0,
		length = length,
	}
end

local calm = entry("Calm tune (loop)", 9045117358, APM, YOU, 0.2, 130.1)
calm.fileStart = 0.05 -- the sound runs from 0.05 s; the nearly silent last 2.3 s are skipped
calm.loopStart = 0.05
calm.loopEnd = 127.7

local chase = entry("Chase tune (loop)", 9042777456, APM, YOU, 0.3, 104.3)
chase.fileStart = 0.3 -- every wake-up starts 0.3 s in
chase.loopStart = 0.3
chase.loopEnd = 102.35

local snore = entry("Snore (loop)", SNORE_ID, PSE, VALLEY, 0.8, SNORE_LENGTH)
snore.speed = nil
snore.speedMin = Config.Audio.SnoreSpeed.Min
snore.speedMax = Config.Audio.SnoreSpeed.Max

local heavy = entry("Heavy Sleep snore (loop)", SNORE_ID, PSE, VALLEY, 0.9, SNORE_LENGTH)
heavy.speed = nil
heavy.speedMin = Config.Audio.HeavySleepSnoreSpeed.Min
heavy.speedMax = Config.Audio.HeavySleepSnoreSpeed.Max

-- A cut of the snore file: its short second breath, with a short fade so it doesn't click.
local snort = entry("85% snort (two)", SNORE_ID, PSE, VALLEY, 1.0, SNORE_LENGTH)
snort.secondSpeed = 0.9
snort.fileStart = 3.46
snort.fileEnd = 3.86
snort.endFade = 0.05
snort.oneAtATime = true

local mumble = entry('"Mmm..." mumble', 9114628818, PSE, VALLEY, 0.9, 2.1)
mumble.oneAtATime = true

local roar = entry("Cartoon roar (no words)", 9114624494, PSE, VALLEY, 0.8, 2.1)
roar.speed = 0.8

local fistThud = entry("Fist thud", 9113480915, PSE, VALLEY, 0.95, 1.1)
fistThud.speed = 0.8

local yawn = entry("Big yawn", 9116304896, PSE, VALLEY, 2.1, 0.95)
yawn.speed = 0.8

local flump = entry('Thud "flump"', 9113819689, PSE, NEAR, 0.5, 0.6)
flump.loudnessByThud = { [20] = 0.5, [30] = 0.7, [40] = 0.85 }

local SoundList = {}

-- The spec's rows, in table order.
SoundList.entries = {
	calm,
	chase,
	snore,
	heavy,
	snort,
	mumble,
	entry('"!" sting', 1848272916, APM, YOU, 0.35, 2.6),
	roar,
	entry("Rumble", 9114221327, PSE, YOU, 1.4, 4.3),
	entry("Birds flapping", 9113444620, PSE, VALLEY, 2.3, 2.1),
	entry("Z Z Z popping", 9113537815, PSE, VALLEY, 0.4, 1.0),
	entry('Bounce-off "boing"', 12222124, RBX, NEAR, 0.5, 0.6),
	entry('Circle warning "whoosh"', 9120733724, PSE, NEAR, 1.1, 1.5),
	fistThud,
	entry("Bonk", 9113496949, PSE, NEAR, 1.0, 0.75),
	entry("Bonk twinkle", TWINKLE_ID, PSE, NEAR, 2.6, 2.0),
	entry('Caught "whoosh"', 15675024286, RBX, YOU, 0.55, 0.85),
	entry('Egg "pop"', 15675055424, RBX, NEAR, 0.5, 2.7),
	yawn,
	entry("Grab pluck", 9126163250, PSE, YOU, 1.0, 1.1),
	entry("Grab shimmer", 9116395089, PSE, YOU, 3.8, 2.5),
	entry("Sparkle pop", TWINKLE_ID, PSE, NEAR, 2.6, 2.0),
	entry("Egg home toot", 9117241247, PSE, YOU, 0.8, 1.1),
	entry("Egg home, Rare: happy hit", 1848287311, APM, YOU, 0.3, 2.7),
	entry("Egg home, Epic and Legendary: fanfare", 1842335078, APM, YOU, 1.9, 3.2),
	entry("Egg home, Legendary: children's cheer", 1841221347, APM, YOU, 0.55, 2.9),
	flump,
	entry("Tiptoe click", CLICK_ID, RBX, YOU, 0.4, 0.4),
	entry('Rescue "poof"', 9116406610, PSE, NEAR, 0.6, 1.2),
	entry("Music button click", CLICK_ID, RBX, YOU, 0.4, 0.4),
} :: { Entry }

-- The AudioPlayer volume for a spec loudness: twice the number (the spec's scale is the old Sound's, where 0.5 plays a
-- file as recorded; AudioPlayer's 1.0 does). The biggest, 3.8, becomes 7.6; the limit is 10.
function SoundList.playerVolume(specLoudness: number): number
	return specLoudness * 2
end

return SoundList
