--!strict
-- The world reacts to the wake (spec Rule 69): when the giant's Phase turns "Awake", 24 birds fly off behind him for
-- BirdSeconds and are gone. Each flies in a straight line at a constant speed, out from the valley's middle and up, so
-- none ever crosses to his face side. The wings flap on the same clock. A second wake clears the first birds and spawns
-- 24 new ones. A wake that was already on when this started plays nothing. It plays with Reduce Motion on too, so it
-- never reads that setting. Each of the 7 dust spots on his body also gives one puff at the wake.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Config = require(ReplicatedStorage.Shared.Config)
local SpotLabels = require(script.Parent.Parent.World.SpotLabels)

local PHASE = "Phase"
local AWAKE = "Awake"
local BIRD_SOUND = "WakeBirds"
local WING_NAME = "Wing"
-- A bird's direction is this much outward (horizontally, away from the valley's middle) and this much up: 0.8^2 + 0.6^2 = 1.
local OUTWARD_SHARE = 0.8
local UP_SHARE = 0.6
-- How far a wing swings from flat each way, in radians.
local FLAP_ANGLE = 0.6
-- A clock reading this close to a deadline counts as there.
local CLOCK_TOLERANCE = 1e-6

local WakeWorld = {}

export type Deps = {
	giantState: Instance, -- holds the Phase attribute ("Awake" is the wake)
	birds: Instance, -- the template folder of Bird models (ReplicatedStorage.Assets.WakeBirds)
	dust: Instance, -- the folder of dust spots, each with one ParticleEmitter (Workspace.World.GiantFX.WakeDust)
	parent: Instance, -- where the flying birds go (Workspace.World.GiantFX)
	step: SpotLabels.SignalLike, -- once per frame (RunService.RenderStepped)
	now: () -> number, -- a clock in seconds
	emit: (emitter: ParticleEmitter, count: number) -> (), -- the real one is emitter:Emit(count)
	playSound: ((name: string, at: Vector3?) -> ())?, -- plays a named sound (plan 7); nothing without it
}

-- One wing: the part, where it rests relative to the body, and which side it is on (-1 left, 1 right).
type Wing = { part: BasePart, rest: CFrame, side: number }
-- One flying bird: the copy, where it began, which way it goes, and its body and wings.
type Flight = { model: Model, start: CFrame, direction: Vector3, body: BasePart, wings: { Wing } }

-- The way a bird at `position` flies: out from the middle (x 0, z 0) and up. A bird exactly at the middle goes +Z.
local function directionFrom(position: Vector3): Vector3
	local flat = Vector3.new(position.X, 0, position.Z)
	local outward = if flat.Magnitude > CLOCK_TOLERANCE then flat.Unit else Vector3.new(0, 0, 1)
	return outward * OUTWARD_SHARE + Vector3.new(0, UP_SHARE, 0)
end

-- Makes a flying copy of one template bird, or nil when it has no body to follow.
local function newFlight(template: Instance): Flight?
	if not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	-- The real birds have no PrimaryPart and their parts come in any order: the body is the first part that is not a wing.
	local body = model.PrimaryPart
	if body == nil then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= WING_NAME then
				body = part
				break
			end
		end
	end
	if body == nil then
		model:Destroy()
		return nil
	end
	local wings: { Wing } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			if part.Name == WING_NAME then
				local rest = body.CFrame:ToObjectSpace(part.CFrame)
				local side = if rest.Position.X < 0 then -1 else 1
				table.insert(wings, { part = part, rest = rest, side = side })
			end
		end
	end
	local start = model:GetPivot()
	return { model = model, start = start, direction = directionFrom(start.Position), body = body, wings = wings }
end

-- Watches the Phase and flies the birds at each wake. Returns a function that stops it all.
function WakeWorld.start(deps: Deps): () -> ()
	local trove = Trove.new()
	local stopped = false
	local flights: { Flight } = {}
	local startedAt = 0

	local function clearBirds()
		for _, flight in flights do
			flight.model:Destroy()
		end
		table.clear(flights)
	end

	-- Where the birds are `t` seconds after the wake: straight on at a constant speed, wings flapping.
	local function place(t: number)
		local flapAngle = FLAP_ANGLE * math.sin(2 * math.pi * Config.Wake.BirdFlapsPerSecond * t)
		for _, flight in flights do
			flight.model:PivotTo(flight.start + flight.direction * (Config.Wake.BirdSpeedStuds * t))
			local bodyCFrame = flight.body.CFrame
			for _, wing in flight.wings do
				wing.part.CFrame = bodyCFrame * wing.rest * CFrame.Angles(0, 0, wing.side * flapAngle)
			end
		end
	end

	local function wake()
		clearBirds()
		startedAt = deps.now()
		local centre = Vector3.zero
		for _, template in deps.birds:GetChildren() do
			local flight = newFlight(template)
			if flight ~= nil then
				table.insert(flights, flight)
				centre += flight.start.Position
				flight.model.Parent = deps.parent
			end
		end
		for _, emitter in deps.dust:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				deps.emit(emitter, Config.Wake.DustBurst)
			end
		end
		if deps.playSound ~= nil and #flights > 0 then
			deps.playSound(BIRD_SOUND, centre / #flights)
		end
	end

	trove:Add(deps.giantState:GetAttributeChangedSignal(PHASE):Connect(function()
		if not stopped and deps.giantState:GetAttribute(PHASE) == AWAKE then
			wake()
		end
	end))

	trove:Add(deps.step:Connect(function()
		if #flights == 0 then
			return
		end
		local t = deps.now() - startedAt
		if t >= Config.Wake.BirdSeconds - CLOCK_TOLERANCE then
			clearBirds()
		else
			place(t)
		end
	end))

	return function()
		if stopped then
			return
		end
		stopped = true
		clearBirds()
		trove:Destroy()
	end
end

return WakeWorld
