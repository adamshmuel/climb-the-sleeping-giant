--!strict
-- Eggs never hide the player (spec Rule 3, "Eggs wait in three zones", and the "Eggs never hide the player" row of the
-- style guide). On the belly the camera looks up the slope, and a 7-stud Rare egg standing between the camera and the
-- player covered the whole player. So an egg that waits on its spot and sits between the camera and the player's own
-- character turns 70% see-through. It fades in over 0.15 s, and back over 0.3 s once it no longer blocks.
-- Every part of the egg gets the same value, through LocalTransparencyModifier. The light, the sparkles and the label
-- are not parts, so they stay as they are. Carried eggs are copies on the character, never under the egg spots, so
-- they are never touched.
-- LocalTransparencyModifier is local to this device: the server's parts stay at 0 and other players never see it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local EggFade = {}

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

export type Deps = {
	root: Instance, -- holds the egg spots (Workspace.World.EggSpots)
	camera: () -> CFrame?, -- where the camera is now (nil when there is none)
	targets: () -> { Vector3 }, -- the points that must stay in sight: the player's head and root (empty without a living character)
	step: SignalLike, -- once per frame (RunService.RenderStepped)
	now: () -> number, -- a clock in seconds
}

-- How see-through a blocking egg gets (70%, as the style guide says): enough that the player shows through, little
-- enough that it still reads as an egg.
local SEE_THROUGH = 0.7
-- Seconds to go from clear to fully faded: quick, so the player is never hidden for long.
local FADE_IN_SECONDS = 0.15
-- Seconds to go from fully faded back to clear: slower, so an egg at the edge of the line doesn't flicker.
local FADE_OUT_SECONDS = 0.3

local EGG_NAME = "Egg"
-- A fade this close to clear or to fully faded counts as there, so a clock that is off by a hair never leaves a speck
-- of see-through behind. It is far too small to see.
local SNAP = 1e-6
-- Lines closer to parallel with a box face than this are treated as parallel (no division by almost nothing).
local PARALLEL = 1e-9

-- Where the line (start + direction * t) is inside the slab between -half and half on one axis, as a range of t.
-- Narrows `enter` and `leave` (the part of 0 to 1 still inside the box so far). The first answer is false when nothing
-- is left.
local function narrow(
	start: number,
	direction: number,
	half: number,
	enter: number,
	leave: number
): (boolean, number, number)
	if math.abs(direction) < PARALLEL then
		return math.abs(start) <= half, enter, leave
	end
	local first = (-half - start) / direction
	local second = (half - start) / direction
	local newEnter = math.max(enter, math.min(first, second))
	local newLeave = math.min(leave, math.max(first, second))
	return newEnter <= newLeave, newEnter, newLeave
end

-- True when the straight segment from `from` (the camera) to `to` (a point on the player) passes through the box. The
-- box may be turned: the segment is moved into the box's own frame, where the box is straight. It is a segment, not an
-- endless line, so a box behind the camera or behind the player is not between them.
function EggFade.blocks(from: Vector3, to: Vector3, boxCFrame: CFrame, boxSize: Vector3): boolean
	local inverse = boxCFrame:Inverse()
	local start = inverse * from
	local direction = inverse * to - start
	local half = boxSize / 2
	local inside, enter, leave = narrow(start.X, direction.X, half.X, 0, 1)
	if not inside then
		return false
	end
	inside, enter, leave = narrow(start.Y, direction.Y, half.Y, enter, leave)
	if not inside then
		return false
	end
	inside = narrow(start.Z, direction.Z, half.Z, enter, leave)
	return inside
end

-- The points of the player's own character that must stay in sight: the head and the root part. Nothing for a missing or
-- dead character, so no egg fades for a player who is not there.
function EggFade.targetsOf(character: Model?): { Vector3 }
	local points: { Vector3 } = {}
	if character == nil then
		return points
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return points
	end
	for _, name in { "Head", "HumanoidRootPart" } do
		local part = character:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			table.insert(points, part.Position)
		end
	end
	return points
end

-- One waiting egg and what it needs to fade.
type Entry = {
	spot: Instance,
	egg: Model,
	boxCFrame: CFrame?, -- the egg's bounding box, read once (eggs are anchored and never move)
	boxSize: Vector3?,
	progress: number, -- 0 clear to 1 fully faded
	written: number, -- the value last put on the parts, so a part is only written when it changes
	cleanup: () -> (), -- disconnects what follows this egg
}

-- Fades the waiting eggs under `deps.root` that block the view of the player. Returns `stop`, which puts every egg back
-- to clear and disconnects everything.
function EggFade.start(deps: Deps): { stop: () -> () }
	local trove = Trove.new()
	local stopped = false
	local entries: { [Model]: Entry } = {}
	local spotCleanups: { [Instance]: () -> () } = {}
	local lastTime = deps.now()

	-- Puts the value on every part of the egg.
	local function write(entry: Entry, value: number)
		entry.written = value
		for _, descendant in entry.egg:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = value
			end
		end
	end

	-- Reads the egg's box once, as soon as the egg has a part to measure.
	local function readBox(entry: Entry)
		if entry.egg:FindFirstChildWhichIsA("BasePart", true) == nil then
			return
		end
		entry.boxCFrame, entry.boxSize = entry.egg:GetBoundingBox()
	end

	local function untrackEgg(egg: Instance)
		local entry = entries[egg :: Model]
		if entry ~= nil then
			entries[egg :: Model] = nil
			entry.cleanup()
		end
	end

	local function trackEgg(spot: Instance, egg: Instance)
		if stopped or not egg:IsA("Model") or egg.Name ~= EGG_NAME or entries[egg] ~= nil then
			return
		end
		local eggTrove = Trove.new()
		local entry: Entry = {
			spot = spot,
			egg = egg,
			boxCFrame = nil,
			boxSize = nil,
			progress = 0,
			written = 0,
			cleanup = function()
				eggTrove:Destroy()
			end,
		}
		entries[egg] = entry
		-- A part that arrives while the egg is faded joins in at the same value.
		eggTrove:Add(egg.DescendantAdded:Connect(function(descendant: Instance)
			if entry.written ~= 0 and descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = entry.written
			end
		end))
	end

	local function trackSpot(spot: Instance)
		if stopped or not spot:IsA("Model") or spotCleanups[spot] ~= nil then
			return
		end
		local spotTrove = Trove.new()
		spotCleanups[spot] = function()
			spotTrove:Destroy()
		end
		spotTrove:Add(spot.ChildAdded:Connect(function(child: Instance)
			trackEgg(spot, child)
		end))
		spotTrove:Add(spot.ChildRemoved:Connect(untrackEgg))
		for _, child in spot:GetChildren() do
			trackEgg(spot, child)
		end
	end

	local function untrackSpot(spot: Instance)
		local cleanupSpot = spotCleanups[spot]
		if cleanupSpot == nil then
			return
		end
		spotCleanups[spot] = nil
		cleanupSpot()
		for egg, entry in entries do
			if entry.spot == spot then
				untrackEgg(egg)
			end
		end
	end

	-- True when the view from the camera to any target point passes through the egg.
	local function isBlocking(entry: Entry, cameraPosition: Vector3?, targets: { Vector3 }): boolean
		local boxCFrame, boxSize = entry.boxCFrame, entry.boxSize
		if cameraPosition == nil or boxCFrame == nil or boxSize == nil then
			return false
		end
		for _, target in targets do
			if EggFade.blocks(cameraPosition, target, boxCFrame, boxSize) then
				return true
			end
		end
		return false
	end

	local function onStep()
		local now = deps.now()
		local seconds = math.max(0, now - lastTime)
		lastTime = now
		local cameraCFrame = deps.camera()
		local cameraPosition = if cameraCFrame ~= nil then cameraCFrame.Position else nil
		local targets = deps.targets()
		for _, entry in entries do
			if entry.boxSize == nil then
				readBox(entry)
			end
			if isBlocking(entry, cameraPosition, targets) then
				entry.progress = math.min(1, entry.progress + seconds / FADE_IN_SECONDS)
			else
				entry.progress = math.max(0, entry.progress - seconds / FADE_OUT_SECONDS)
			end
			if entry.progress < SNAP then
				entry.progress = 0
			elseif entry.progress > 1 - SNAP then
				entry.progress = 1
			end
			local value = entry.progress * SEE_THROUGH
			if value ~= entry.written then
				write(entry, value)
			end
		end
	end

	for _, spot in deps.root:GetChildren() do
		trackSpot(spot)
	end
	trove:Add(deps.root.ChildAdded:Connect(trackSpot))
	trove:Add(deps.root.ChildRemoved:Connect(untrackSpot))
	trove:Add(deps.step:Connect(onStep))

	local function stop()
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
		for egg, entry in entries do
			if entry.written ~= 0 then
				write(entry, 0)
			end
			untrackEgg(egg)
		end
		for spot in spotCleanups do
			untrackSpot(spot)
		end
	end

	return { stop = stop }
end

return EggFade
