--!strict
-- Drops the thud of a fall that is one of the set ways down (spec core-heist Rule 8, plan 5 Task 26a). It follows
-- every player's fall tick by tick: where it began (the last position that was not part of a fall), the zones it
-- crossed, whether it passed below the seam line, and whether any tick of it had a jump. On the tick a thud is due
-- it asks `WayDown.isSet`; if yes it clears `thudFrom` and sets `quiet`. It runs after `PlayerTracker.tick` and
-- before the watches that read `thudFrom`. Pure: it reads and edits the samples it is given.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerTracker = require(script.Parent.PlayerTracker)
local SlideWatch = require(script.Parent.SlideWatch)
local WayDown = require(script.Parent.WayDown)

export type Deps = { ladders: { WayDown.Ladder }, seam: { SlideWatch.SeamPoint } }
export type Watch = {
	check: (self: any, samples: { PlayerTracker.Sample }) -> (),
	forget: (self: any, userId: number) -> (),
}

type PlayerState = {
	lastPosition: Vector3?, -- position on the last tick that was not part of a fall
	inFall: boolean,
	firstAirborne: Vector3,
	zones: { [Config.ZoneName]: boolean },
	passedBelow: boolean,
	jumped: boolean,
}

local QuietDrops = {}

local function newState(): PlayerState
	return {
		lastPosition = nil,
		inFall = false,
		firstAirborne = Vector3.zero,
		zones = {},
		passedBelow = false,
		jumped = false,
	}
end

function QuietDrops.new(deps: Deps): Watch
	local states: { [number]: PlayerState } = {}

	local function checkOne(sample: PlayerTracker.Sample)
		local state = states[sample.userId]
		if state == nil then
			state = newState()
			states[sample.userId] = state
		end
		if sample.falling and not state.inFall then
			state.inFall = true
			state.firstAirborne = state.lastPosition or sample.position
			state.zones = {}
			state.passedBelow = false
			state.jumped = false
		end
		if state.inFall then
			state.zones[sample.zone] = true
			if SlideWatch.pointBelowSeam(sample.position, deps.seam) then
				state.passedBelow = true
			end
			if sample.jumped == true then
				state.jumped = true
			end
			if sample.thudFrom ~= nil then
				local fall: WayDown.Fall = {
					firstAirborne = state.firstAirborne,
					zones = state.zones,
					endZone = sample.zone,
					endPosition = sample.position,
					passedBelow = state.passedBelow,
					jumped = state.jumped,
				}
				if WayDown.isSet(fall, deps.ladders) then
					sample.thudFrom = nil
					sample.quiet = true
				end
				state.inFall = false
			elseif not sample.falling then
				state.inFall = false
			end
		end
		if not state.inFall then
			state.lastPosition = sample.position
		end
	end

	local watch = {} :: Watch
	function watch.check(_self: any, samples: { PlayerTracker.Sample })
		for _, sample in samples do
			checkOne(sample)
		end
	end
	function watch.forget(_self: any, userId: number)
		states[userId] = nil
	end
	return watch
end

return QuietDrops
