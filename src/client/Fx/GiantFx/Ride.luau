--!strict
-- The right cuff rides his arm (spec Rule 100, "Nothing you stand on moves while he sleeps", and Story F). Every part
-- marked RidesRightArm (or inside a model marked so) moves by exactly the arm's own move: the arm's pivot now, times the
-- inverse of the arm's start pivot, times the part's own start CFrame. The server never moves them. The start CFrame is
-- saved the first time a part is seen (an egg that appears later is at rest on arrival). The beams in those eggs fade
-- to see-through while he is awake and come back once the arm is down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shared = require(script.Parent.Shared)

local MARK = "RidesRightArm"

local Ride = {}

export type Rider = {
	-- Puts every riding part on `move` times its start; nil puts each exactly on its start.
	place: (move: CFrame?) -> (),
	-- Moves the beam fade on to `now`.
	update: (now: number) -> (),
	-- True while a beam is still fading.
	busy: () -> boolean,
	-- The beams are fully faded at once (he is awake when this starts).
	snap: () -> (),
	-- Puts everything back as it was and disconnects.
	destroy: () -> (),
}

function Ride.new(state: Shared.State, deps: Shared.Deps): Rider
	local world = deps.world
	local starts: { [BasePart]: CFrame } = {}
	local beams: { [Beam]: NumberSequence } = {}
	local lastMove: CFrame? = nil
	-- How faded the beams are (0 is their own look, 1 is fully see-through), where that is heading, and the last clock.
	local share = 0
	local heading = 0
	local lastNow: number? = nil
	local connections: { RBXScriptConnection } = {}

	-- True when the instance, or an ancestor under the world, is marked.
	local function rides(instance: Instance): boolean
		local current: Instance? = instance
		while current ~= nil and current ~= world do
			if current:GetAttribute(MARK) == true then
				return true
			end
			current = current.Parent
		end
		return false
	end

	local function paintBeam(beam: Beam, original: NumberSequence)
		if share <= 0 then
			beam.Transparency = original
			return
		end
		local keypoints: { NumberSequenceKeypoint } = {}
		for _, keypoint in original.Keypoints do
			table.insert(
				keypoints,
				NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value + (1 - keypoint.Value) * share)
			)
		end
		beam.Transparency = NumberSequence.new(keypoints)
	end

	local function paintBeams()
		for beam, original in beams do
			paintBeam(beam, original)
		end
	end

	local function place(move: CFrame?)
		lastMove = move
		for part, start in starts do
			part.CFrame = if move == nil then start else move * start
		end
	end

	local function track(instance: Instance)
		if instance:IsA("BasePart") then
			local knownStart: CFrame? = starts[instance]
			if knownStart == nil and rides(instance) then
				starts[instance] = instance.CFrame
				local move = lastMove
				if move ~= nil then
					instance.CFrame = move * instance.CFrame
				end
			end
		elseif instance:IsA("Beam") then
			local knownLook: NumberSequence? = beams[instance]
			if knownLook == nil and rides(instance) then
				beams[instance] = instance.Transparency
				paintBeam(instance, instance.Transparency)
			end
		end
	end

	local function forget(instance: Instance)
		if instance:IsA("BasePart") then
			starts[instance] = nil
		elseif instance:IsA("Beam") then
			beams[instance] = nil
		end
	end

	-- Whether the beams should be faded now: while he is awake and while the arm is still coming down.
	local function wanted(): number
		return if state.awake or state.poseDirection ~= 0 then 1 else 0
	end

	local function update(now: number)
		local previous = lastNow
		lastNow = now
		if next(beams) == nil then
			-- Nothing to fade: no need to step on, and a beam that arrives later starts at the right look.
			share = wanted()
			heading = share
			return
		end
		if previous ~= nil and share ~= heading then
			local step = (now - previous) / Config.Nests.BeamFadeSeconds
			if heading > share then
				share = math.min(heading, share + step)
			else
				share = math.max(heading, share - step)
			end
			paintBeams()
		end
		heading = wanted()
	end

	local function snap()
		share = 1
		heading = 1
		paintBeams()
	end

	local function restore()
		share = 0
		heading = 0
		lastNow = nil
		lastMove = nil
		for part, start in starts do
			part.CFrame = start
		end
		for beam, original in beams do
			beam.Transparency = original
		end
	end

	-- One scan now; after that the world tells us what comes and goes.
	for _, descendant in world:GetDescendants() do
		track(descendant)
	end
	table.insert(connections, world.DescendantAdded:Connect(track))
	table.insert(connections, world.DescendantRemoving:Connect(forget))

	return {
		place = place,
		update = update,
		busy = function(): boolean
			return share ~= heading or wanted() ~= heading
		end,
		snap = snap,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			restore()
			table.clear(starts)
			table.clear(beams)
		end,
	}
end

return Ride
