--!strict
-- The refill pop (spec Rule 77 and section 6, "A new egg appears"): when an empty nest gets its egg back, the egg grows
-- in (0, then 1.1 at 0.15 s, then 1.0 at 0.25 s) with its bottom staying on the nest, and a burst of gold stars rises
-- from the spot and is gone after 1.5 s. It plays for every player who sees the spot, so every device sees every refill.
-- A spot that is already full when this starts, or whose Waiting was not set before, plays nothing: only a spot seen
-- empty (Waiting false) and then full (Waiting true) pops. With Reduce Motion on, the egg is simply there, and the stars
-- are 14 still ones that do not move.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local SpotLabels = require(script.Parent.Parent.World.SpotLabels)

local EGG_NAME = "Egg"
local BASE_NAME = "Base"
local STARS_NAME = "RefillPop"

-- The grow-in: up to PEAK_SCALE by PEAK_SECONDS, then back to 1 by GROW_SECONDS (style guide, nests-art.md).
local PEAK_SCALE = 1.1
local PEAK_SECONDS = 0.15
local GROW_SECONDS = 0.25
-- Model:ScaleTo does not take 0, so the egg starts this small.
local MIN_SCALE = 0.01
-- The stars: how many, how high above the egg's bottom they start, and how long they stay.
local STARS_COUNT = 30
local STILL_STARS_COUNT = 14
local STARS_ABOVE_BOTTOM = 3.2
local STARS_SECONDS = 1.5
-- How long a refilled spot waits for its egg model to arrive before it plays the stars alone.
local EGG_WAIT_SECONDS = 1
-- A clock reading this close to a deadline counts as there, so a rounding speck never costs one more frame.
local CLOCK_TOLERANCE = 1e-6

local NestPop = {}

export type Deps = {
	root: Instance, -- holds the egg spots (Workspace.World.EggSpots)
	template: BasePart?, -- the stars: ReplicatedStorage.Assets.RefillPop (an invisible Part holding one ParticleEmitter)
	reducedMotion: () -> boolean, -- the player's Reduce Motion setting (GuiService.ReducedMotionEnabled)
	step: SpotLabels.SignalLike, -- once per frame (RunService.RenderStepped)
	now: () -> number, -- a clock in seconds
	emit: (emitter: ParticleEmitter, count: number) -> (), -- the real one is emitter:Emit(count)
}

-- One egg that is growing in: where its bottom must stay, and when it started.
type Grow = { egg: Model, bottom: Vector3, startedAt: number }

-- The egg's size at `t` seconds after the pop: 0 at the start, 1.1 at 0.15 s, 1.0 at 0.25 s, and 1 after that.
function NestPop.scaleAt(t: number): number
	if t <= 0 then
		return 0
	end
	if t < PEAK_SECONDS then
		local eased = TweenService:GetValue(t / PEAK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		return PEAK_SCALE * eased
	end
	if t < GROW_SECONDS then
		local alpha = (t - PEAK_SECONDS) / (GROW_SECONDS - PEAK_SECONDS)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		return PEAK_SCALE + (1 - PEAK_SCALE) * eased
	end
	return 1
end

-- The middle of the bottom of a model's box, or nothing when the model has no parts yet.
local function bottomPoint(model: Model): Vector3?
	local box, size = model:GetBoundingBox()
	if size.Y <= 0 then
		return nil
	end
	return box:PointToWorldSpace(Vector3.new(0, -size.Y / 2, 0))
end

local function readWaiting(spot: Instance): boolean?
	local value: any = spot:GetAttribute("Waiting")
	if type(value) == "boolean" then
		return value
	end
	return nil
end

-- Watches every egg spot under `deps.root` and pops the ones that refill. Returns a function that stops it all.
function NestPop.start(deps: Deps): () -> ()
	local trove = Trove.new()
	local stopped = false
	local warned = false
	local tracked: { [Instance]: typeof(Trove.new()) } = {}
	local lastWaiting: { [Instance]: boolean? } = {}
	local grows: { [Instance]: Grow } = {}
	local waiters: { [Instance]: number } = {} -- spots waiting for their egg model, and until when
	local starsEnd: { [BasePart]: number } = {} -- the stars on show, and when each one goes

	-- Sets the egg's size for `t` seconds into the grow-in, then moves it so its bottom is back where it was.
	local function apply(grow: Grow, t: number)
		local scale = if t >= GROW_SECONDS - CLOCK_TOLERANCE then 1 else math.max(MIN_SCALE, NestPop.scaleAt(t))
		grow.egg:ScaleTo(scale)
		local bottom = bottomPoint(grow.egg)
		if bottom ~= nil then
			grow.egg:PivotTo(grow.egg:GetPivot() + (grow.bottom - bottom))
		end
	end

	-- Ends a spot's grow-in at once, leaving the egg at full size.
	local function finishGrow(spot: Instance)
		local grow = grows[spot]
		if grow ~= nil then
			grows[spot] = nil
			if grow.egg.Parent ~= nil then
				apply(grow, GROW_SECONDS)
			end
		end
	end

	local function startGrow(spot: Instance, egg: Model, bottom: Vector3?)
		if bottom == nil then
			return
		end
		local grow: Grow = { egg = egg, bottom = bottom, startedAt = deps.now() }
		grows[spot] = grow
		apply(grow, 0)
	end

	-- The stars: a copy of the template, `STARS_ABOVE_BOTTOM` studs above where the egg's bottom is (or would be).
	local function playStars(spot: Model, bottom: Vector3?, still: boolean)
		local template = deps.template
		if template == nil then
			if not warned then
				warned = true
				warn("NestPop: no RefillPop template, so the refill plays the grow-in only")
			end
			return
		end
		local start = bottom
		if start == nil then
			local base = spot:FindFirstChild(BASE_NAME)
			if base ~= nil and base:IsA("BasePart") then
				start = base.Position + Vector3.new(0, base.Size.Y / 2, 0)
			else
				start = spot:GetPivot().Position
			end
		end
		local stars = template:Clone()
		stars.Name = STARS_NAME
		stars.CanCollide = false
		stars.CanQuery = false
		stars.CanTouch = false
		stars.CFrame = CFrame.new((start :: Vector3) + Vector3.new(0, STARS_ABOVE_BOTTOM, 0))
		local emitter = stars:FindFirstChildWhichIsA("ParticleEmitter")
		if emitter == nil then
			stars:Destroy()
			if not warned then
				warned = true
				warn("NestPop: the RefillPop template has no ParticleEmitter")
			end
			return
		end
		if still then
			emitter.Speed = NumberRange.new(0)
			emitter.RotSpeed = NumberRange.new(0)
			emitter.Acceleration = Vector3.zero
		end
		stars.Parent = spot
		starsEnd[stars] = deps.now() + STARS_SECONDS
		deps.emit(emitter, if still then STILL_STARS_COUNT else STARS_COUNT)
	end

	local function pop(spot: Model)
		finishGrow(spot)
		local still = deps.reducedMotion()
		local found = spot:FindFirstChild(EGG_NAME)
		local egg = if found ~= nil and found:IsA("Model") then found else nil
		local bottom = if egg ~= nil then bottomPoint(egg) else nil
		playStars(spot, bottom, still)
		if still then
			return
		end
		if egg ~= nil then
			startGrow(spot, egg, bottom)
		else
			waiters[spot] = deps.now() + EGG_WAIT_SECONDS
		end
	end

	local function track(child: Instance)
		if stopped or not child:IsA("Model") or tracked[child] ~= nil then
			return
		end
		local spot = child
		local spotTrove = Trove.new()
		tracked[spot] = spotTrove
		lastWaiting[spot] = readWaiting(spot)
		spotTrove:Add(spot:GetAttributeChangedSignal("Waiting"):Connect(function()
			local before = lastWaiting[spot]
			local after = readWaiting(spot)
			lastWaiting[spot] = after
			if before == false and after == true then
				pop(spot)
			end
		end))
		spotTrove:Add(spot.ChildAdded:Connect(function(added: Instance)
			if waiters[spot] ~= nil and added.Name == EGG_NAME and added:IsA("Model") then
				waiters[spot] = nil
				startGrow(spot, added, bottomPoint(added))
			end
		end))
	end

	local function untrack(child: Instance)
		local spotTrove = tracked[child]
		if spotTrove ~= nil then
			tracked[child] = nil
			lastWaiting[child] = nil
			waiters[child] = nil
			finishGrow(child)
			spotTrove:Destroy()
		end
	end

	local function onStep()
		local now = deps.now()
		for spot, grow in grows do
			if grow.egg.Parent == nil then
				grows[spot] = nil
			else
				local t = now - grow.startedAt
				apply(grow, t)
				if t >= GROW_SECONDS - CLOCK_TOLERANCE then
					grows[spot] = nil
				end
			end
		end
		for spot, deadline in waiters do
			if now >= deadline - CLOCK_TOLERANCE then
				waiters[spot] = nil
			end
		end
		for stars, endsAt in starsEnd do
			if now >= endsAt - CLOCK_TOLERANCE then
				starsEnd[stars] = nil
				stars:Destroy()
			end
		end
	end

	for _, child in deps.root:GetChildren() do
		track(child)
	end
	trove:Add(deps.root.ChildAdded:Connect(track))
	trove:Add(deps.root.ChildRemoved:Connect(untrack))
	trove:Add(deps.step:Connect(onStep))
	trove:Add(function()
		for spot in tracked do
			untrack(spot)
		end
		for stars in starsEnd do
			stars:Destroy()
		end
		table.clear(starsEnd)
	end)

	return function()
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end
end

return NestPop
