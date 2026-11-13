--!strict
-- Judges whether a fall is a slide (plan 5 "Decisions", row "What counts as a slide"; spec Rule 84). Pure: it
-- reads Vector3s and Config only. A slide is a fall with a thud that ends at least `SlideDrop` studs lower than it
-- began, and either passed below the seam or began on a stitched edge. The root position stands in for the feet.
-- `check` takes one tick (one reading per player). Only a player's first slide fires the tip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type SeamPoint = { position: Vector3, down: Vector3 }
export type Reading = {
	userId: number,
	position: Vector3,
	falling: boolean,
	thudFrom: string?,
	moveGrace: boolean,
	onStitchedEdge: boolean,
}
export type Deps = {
	seam: { SeamPoint },
	floating: (userId: number) -> boolean,
	fireTip: (userId: number) -> (),
	onSlide: ((userId: number, slideNumber: number) -> ())?, -- every slide that ends; 1 = first
}
export type Watch = { check: (self: any, readings: { Reading }) -> (), forget: (self: any, userId: number) -> () }

type PlayerState = {
	slides: number,
	lastPosition: Vector3?, -- position on the last tick that was not part of a fall
	lastStitched: boolean,
	inFall: boolean,
	startY: number,
	startStitched: boolean,
	passedBelow: boolean,
	thrownAway: boolean,
}

local ACROSS = 4 -- studs a point may be to the side of a seam point's line and still count as below it (card "The decision")

local SlideWatch = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- True when the closest seam point (flat) is passed by more than `match` studs along its Down, within `across` sideways.
function SlideWatch.belowSeam(point: Vector3, seam: { SeamPoint }, match: number, across: number): boolean
	local closest: SeamPoint? = nil
	local closestDistance = math.huge
	for _, seamPoint in seam do
		local distance = flat(point - seamPoint.position).Magnitude
		if distance < closestDistance then
			closest = seamPoint
			closestDistance = distance
		end
	end
	if closest == nil then
		return false
	end
	local offset = flat(point - closest.position)
	local down = flat(closest.down)
	local along = offset:Dot(down)
	local sideways = (offset - down * along).Magnitude
	return along > match and sideways <= across
end

-- True when `point` is below the seam line, by the config's match and this watch's own across limit.
function SlideWatch.pointBelowSeam(point: Vector3, seam: { SeamPoint }): boolean
	return SlideWatch.belowSeam(point, seam, Config.Nests.SeamMatch, ACROSS)
end

local function newState(): PlayerState
	return {
		slides = 0,
		lastPosition = nil,
		lastStitched = false,
		inFall = false,
		startY = 0,
		startStitched = false,
		passedBelow = false,
		thrownAway = false,
	}
end

function SlideWatch.new(deps: Deps): Watch
	local states: { [number]: PlayerState } = {}

	local function endFall(userId: number, state: PlayerState, reading: Reading)
		local drop = state.startY - reading.position.Y
		local counts = not state.thrownAway
			and drop >= Config.Nests.SlideDrop
			and (state.passedBelow or state.startStitched)
		state.inFall = false
		state.lastPosition = reading.position
		state.lastStitched = reading.onStitchedEdge
		if not counts then
			return
		end
		state.slides += 1
		if state.slides == 1 then
			deps.fireTip(userId)
		end
		if deps.onSlide ~= nil then
			deps.onSlide(userId, state.slides)
		end
	end

	local function checkOne(reading: Reading)
		local userId = reading.userId
		local state = states[userId]
		if state == nil then
			state = newState()
			states[userId] = state
		end
		if reading.falling and not state.inFall then
			local from = state.lastPosition or reading.position
			state.inFall = true
			state.startY = from.Y
			state.startStitched = state.lastStitched
			state.passedBelow = false
			state.thrownAway = false
		end
		if state.inFall then
			if reading.moveGrace or deps.floating(userId) then
				state.thrownAway = true
			end
			if SlideWatch.pointBelowSeam(reading.position, deps.seam) then
				state.passedBelow = true
			end
			if reading.thudFrom ~= nil then
				endFall(userId, state, reading)
			elseif not reading.falling then
				state.inFall = false -- the fall ended with no thud
				state.lastPosition = reading.position
				state.lastStitched = reading.onStitchedEdge
			end
			return
		end
		state.lastPosition = reading.position
		state.lastStitched = reading.onStitchedEdge
	end

	local watch = {} :: Watch
	function watch.check(_self: any, readings: { Reading })
		for _, reading in readings do
			checkOne(reading)
		end
	end
	function watch.forget(_self: any, userId: number)
		states[userId] = nil
	end
	return watch
end

return SlideWatch
