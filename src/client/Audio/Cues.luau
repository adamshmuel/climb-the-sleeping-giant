--!strict
-- Cues (plan 7 Tasks 8-9): the name of a sound place in the game's code ("Snort1", "WakeRoar") to the sound board's row, the
-- speed it plays at, how long it waits and whether it fades. Pure: no sound is made here. A name that gives nothing (a place
-- a later task connects, or a row that is not in the list: Rule 92's no-yawn fallback) is nil.
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
-- caught whoosh (just for you, so it has no place).
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
}

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
