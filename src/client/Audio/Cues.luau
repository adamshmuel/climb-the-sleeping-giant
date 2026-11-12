--!strict
-- Cues (plan 7 Tasks 8-9): the name of a sound place in the game's code ("Snort1", "WakeRoar") to the sound board's row, the
-- speed it plays at, how long it waits and whether it fades. Pure: no sound is made here. A name that gives nothing (a place
-- a later task connects, or a row that is not in the list: Rule 92's no-yawn fallback) is nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local SoundList = require(script.Parent.SoundList)

local Cues = {}

export type Cue = {
	row: string,
	speed: number?,
	delay: number?,
	fade: { after: number, seconds: number }?,
	also: { string }?, -- extra rows played with it, at the same place (a row not in the list is left out)
}

local SNORT_ROW = "85% snort (two)"
local MUMBLE_ROW = '"Mmm..." mumble'

-- Rule 92: the wake-up sounds, the boing (Rule 86), and Rule 94's slams: the whoosh, the thud, the bonk with its twinkle, the
-- caught whoosh (just for you, so it has no place). Plan 7 Task 11 (Rule 95): the grab and the egg-home sounds, grander for
-- rarer eggs. All six are just for you and play at the rows' own speeds.
local PLUCK_ROW = "Grab pluck"
local TOOT_ROW = "Egg home toot"
local HAPPY_ROW = "Egg home, Rare: happy hit"
local FANFARE_ROW = "Egg home, Epic and Legendary: fanfare"
local CHEER_ROW = "Egg home, Legendary: children's cheer"

local FIXED: { [string]: Cue } = {
	Mumble = { row = MUMBLE_ROW },
	WakeEyes = { row = '"!" sting' },
	WakeRoar = { row = "Cartoon roar (no words)" },
	WakeRumble = { row = "Rumble", fade = { after = 0, seconds = 1 } },
	WakeBirds = { row = "Birds flapping", delay = 0.2 },
	ZzzPop = { row = "Z Z Z popping", delay = 0.3 },
	LieDown = { row = "Big yawn" },
	Boing = { row = 'Bounce-off "boing"' },
	SlamCircle = { row = 'Circle warning "whoosh"' },
	SlamThud = { row = "Fist thud" }, -- the row's own speed (0.8) is used
	Bonk = { row = "Bonk", also = { "Bonk twinkle" } },
	Caught = { row = 'Caught "whoosh"' },
	Grab = { row = PLUCK_ROW },
	GrabShimmer = { row = PLUCK_ROW, also = { "Grab shimmer" } },
	Home = { row = TOOT_ROW },
	HomeRare = { row = TOOT_ROW, also = { HAPPY_ROW } },
	HomeEpic = { row = TOOT_ROW, also = { FANFARE_ROW } },
	HomeLegendary = { row = TOOT_ROW, also = { FANFARE_ROW, CHEER_ROW } },
}

local HOME_NAMES: { [string]: string } = {
	Common = "Home",
	Uncommon = "Home",
	Rare = "HomeRare",
	Epic = "HomeEpic",
	Legendary = "HomeLegendary",
}

-- The sound place for grabbing an egg of this rarity: the shimmer joins from Rare up. Anything that isn't a rarity name
-- (or isn't a string) gives nil, so nothing plays.
function Cues.grabName(rank: any): string?
	if type(rank) ~= "string" or not table.find(Config.RarityOrder, rank) then
		return nil
	end
	return if Rarity.isRareOrRarer(rank) then "GrabShimmer" else "Grab"
end

-- The sound place for an egg of this rarity coming home, or nil for anything that isn't a rarity name.
function Cues.homeName(rank: any): string?
	if type(rank) ~= "string" then
		return nil
	end
	return HOME_NAMES[rank]
end

function Cues.forName(name: string, byName: ((string) -> SoundList.Entry?)?): Cue?
	local find: (string) -> SoundList.Entry? = byName or SoundList.byName
	local cue: Cue? = nil
	if name == "Snort1" then
		cue = { row = SNORT_ROW, speed = 1 }
	elseif name == "Snort2" then
		local row = find(SNORT_ROW)
		cue = { row = SNORT_ROW, speed = if row ~= nil then row.secondSpeed else nil }
	else
		cue = FIXED[name]
	end
	if cue == nil or find(cue.row) == nil then
		return nil
	end
	local found = table.clone(cue)
	if cue.also ~= nil then
		local kept: { string } = {}
		for _, row in cue.also do
			if find(row) ~= nil then
				table.insert(kept, row)
			end
		end
		found.also = kept
	end
	return found
end

return Cues
