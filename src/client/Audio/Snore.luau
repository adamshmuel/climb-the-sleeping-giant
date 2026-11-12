--!strict
-- The snore (plan 7 Task 7; spec 7 Rule 90 "The snore follows his sleep"). It plays exactly while GiantFx says the snore
-- puffs show: GiantFx tells it "Normal", "Heavy" or "Off" (setPuffs). One copy of a snore row plays on an emitter at his
-- mouth, looping. Normal is the "Snore (loop)" row at full volume, half volume from 60% (after GiantFx's 2 s pause);
-- Heavy is the "Heavy Sleep snore (loop)" row. Off, or a change of row, ramps the old copy to silence over
-- Config.Audio.SnoreStopSeconds and then stops it. Each time the loop starts again it picks a new speed from the row's range.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local SoundBoard = require(script.Parent.SoundBoard)
local SoundList = require(script.Parent.SoundList)

export type Puffs = "Normal" | "Heavy" | "Off"
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> SoundBoard.Disconnectable,
}
export type Deps = {
	board: SoundBoard.Board,
	step: SignalLike, -- once per frame (RenderStepped)
	now: () -> number,
	meter: () -> number, -- the sleep meter, 0 to 100
	mouth: () -> Vector3?, -- World.Giant.AwakeMouth.Mouth.Position, nil while it isn't there
	random: () -> number, -- 0 to 1: the speed pick
	looped: (copy: AudioPlayer, callback: () -> ()) -> SoundBoard.Disconnectable, -- the copy's Looped event
}
export type Handle = { setPuffs: (puffs: Puffs) -> (), destroy: () -> () }

type Item = {
	row: string,
	copy: AudioPlayer,
	connection: SoundBoard.Disconnectable,
	fadeFrom: number?, -- the volume when the ramp began
	fadeStart: number?, -- the clock when the ramp began
}

local NORMAL_ROW = "Snore (loop)"
local HEAVY_ROW = "Heavy Sleep snore (loop)"
local LIGHT_FROM_METER = 60 -- spec section 5, "Snore at 60-84%"

local Snore = {}

local function rowFor(puffs: Puffs): string?
	if puffs == "Normal" then
		return NORMAL_ROW
	elseif puffs == "Heavy" then
		return HEAVY_ROW
	end
	return nil
end

function Snore.start(deps: Deps): Handle
	local wanted: string? = nil -- the row the puffs ask for now
	local current: Item? = nil -- the copy that should be heard
	local fading: { Item } = {}

	local function pickSpeed(item: Item)
		local entry = SoundList.byName(item.row)
		local min, max = entry and entry.speedMin, entry and entry.speedMax
		if min ~= nil and max ~= nil then
			item.copy.PlaybackSpeed = min + deps.random() * (max - min)
		end
	end

	local function volumeOf(row: string): number
		local entry = SoundList.byName(row)
		local volume = SoundList.playerVolume(if entry then entry.loudness else 0)
		if row == NORMAL_ROW and deps.meter() >= LIGHT_FROM_METER then
			volume *= Config.Audio.LightSnoreFactor
		end
		return volume
	end

	local function release(item: Item)
		item.connection:Disconnect()
		deps.board.stop(item.row)
	end

	-- The copy leaves the "current" place and ramps down.
	local function startFade(item: Item)
		item.fadeFrom = item.copy.Volume
		item.fadeStart = deps.now()
		table.insert(fading, item)
	end

	local function tryStart(row: string)
		local copy = deps.board.play(row, deps.mouth())
		if copy == nil then
			return
		end
		local item: Item = { row = row, copy = copy, connection = { Disconnect = function() end } }
		copy.Looping = true
		pickSpeed(item)
		copy.Volume = volumeOf(row)
		item.connection = deps.looped(copy, function()
			pickSpeed(item)
		end)
		current = item
	end

	local function onStep()
		local now = deps.now()
		for index = #fading, 1, -1 do
			local item = fading[index]
			local elapsed = now - (item.fadeStart :: number)
			if elapsed >= Config.Audio.SnoreStopSeconds then
				item.copy.Volume = 0
				table.remove(fading, index)
				release(item)
			else
				item.copy.Volume = (item.fadeFrom :: number) * (1 - elapsed / Config.Audio.SnoreStopSeconds)
			end
		end
		local row = wanted
		if row == nil then
			return
		end
		if current == nil then
			tryStart(row)
		else
			current.copy.Volume = volumeOf(row)
		end
	end

	local connection = deps.step:Connect(onStep)

	local function setPuffs(puffs: Puffs)
		local row = rowFor(puffs)
		if row == wanted then
			return
		end
		wanted = row
		local old = current
		if old ~= nil then
			current = nil
			startFade(old)
		end
	end

	local function destroy()
		connection:Disconnect()
		wanted = nil
		local all = table.clone(fading)
		if current ~= nil then
			table.insert(all, current)
		end
		table.clear(fading)
		current = nil
		for _, item in all do
			release(item)
		end
	end

	return { setPuffs = setPuffs, destroy = destroy }
end

return Snore
