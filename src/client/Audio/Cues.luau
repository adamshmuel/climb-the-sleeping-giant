--!strict
-- Cues (plan 7 Task 8): the name of a sound place in the game's code ("Snort1", "Mumble") to the sound board's row and the
-- speed it plays at. Pure: no sound is made here. A name that gives nothing yet (a place a later task connects) is nil.
local SoundList = require(script.Parent.SoundList)

local Cues = {}

export type Cue = { row: string, speed: number? }

local SNORT_ROW = "85% snort (two)"
local MUMBLE_ROW = '"Mmm..." mumble'

function Cues.forName(name: string): Cue?
	if name == "Snort1" then
		return { row = SNORT_ROW, speed = 1 }
	elseif name == "Snort2" then
		local row = SoundList.byName(SNORT_ROW)
		return { row = SNORT_ROW, speed = if row ~= nil then row.secondSpeed else nil }
	elseif name == "Mumble" then
		return { row = MUMBLE_ROW }
	end
	return nil
end

return Cues
