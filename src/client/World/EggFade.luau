--!strict
-- Eggs never hide the player (spec Rule 3, "Eggs wait in three zones", and the "Eggs never hide the player" row of the
-- style guide). On the belly the camera looks up the slope, and a 7-stud Rare egg standing between the camera and the
-- player covered the whole player. So an egg that waits on its spot and sits between the camera and the player's own
-- character turns 70% see-through. It fades in over 0.15 s, and back over 0.3 s once it no longer blocks.
-- The egg the player carries on their own back follows the same rule (V2, "Your own carried egg never hides you"): on
-- the belly path the low camera looks up the slope and that egg covered the player's head and body. It is a copy on the
-- character, named CarriedEgg, and it moves with the player, so its box is measured again every frame. Like a waiting egg
-- it is judged by the line from the camera to the avatar's head or to the middle of the body, but through a box at 75% of
-- the egg's size (an egg whose edge only grazes the line stays solid), it fades to 60% instead of 70% so it still reads
-- as an egg on a bright belly, and it waits 0.2 s with no line crossing before it starts back to solid (so it doesn't
-- flicker at the edge of the line).
-- Every part of the egg gets the same value, through LocalTransparencyModifier. The light, the sparkles and the label
-- are not parts, so they stay as they are.
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
	targets: () -> { Vector3 }, -- the points that must stay in sight, for waiting eggs and the carried egg: the player's head and root (empty without a living character)
	carried: () -> Model?, -- the egg the player carries on their back (the CarriedEgg model), or nil when there is none
	step: SignalLike, -- once per frame (RunService.RenderStepped)
	now: () -> number, -- a clock in seconds
}

-- How see-through a blocking egg gets (70%, as the style guide says): enough that the player shows through, little
-- enough that it still reads as an egg.
local SEE_THROUGH = 0.7
-- How see-through the carried egg gets (60%): it is small and close to the camera, and 70% almost erased it on a bright
-- belly, so it keeps a little more of its shell.
local CARRIED_SEE_THROUGH = 0.6
-- The share of each side of the carried egg's outer box used for the line test: the egg's rounded edge should not fade it
-- when it only grazes the line.
local CARRIED_BOX_SCALE = 0.75
-- Seconds to go from clear to fully faded: quick, so the player is never hidden for long.
local FADE_IN_SECONDS = 0.15
-- Seconds to go from fully faded back to clear: slower, so an egg at the edge of the line doesn't flicker.
local FADE_OUT_SECONDS = 0.3
-- Seconds the carried egg waits, with no line crossing it, before it starts back to solid: an egg at the edge of the line
-- doesn't flicker. A waiting egg has no wait.
local CARRIED_HOLD_SECONDS = 0.2

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

-- True when the character exists and its humanoid is alive, so no egg fades for a player who is not there.
local function isAlive(character: Model?): boolean
	if character == nil then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Where the named part of a living character is, or nil without that part.
local function positionOf(character: Model, name: string): Vector3?
	local part = character:FindFirstChild(name)
	if part ~= nil and part:IsA("BasePart") then
		return part.Position
	end
	return nil
end

-- The points of the player's own character that must stay in sight: the head and the root part. Nothing for a missing or
-- dead character.
function EggFade.targetsOf(character: Model?): { Vector3 }
	local points: { Vector3 } = {}
	if character == nil or not isAlive(character) then
		return points
	end
	for _, name in { "Head", "HumanoidRootPart" } do
		local position = positionOf(character, name)
		if position ~= nil then
			table.insert(points, position)
		end
	end
	return points
end

-- The eight corners of a box, as signs: multiply each by half the box's size to get the corner.
local CORNER_SIGNS: { Vector3 } = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}

-- The box around every part of a model, measured from where the parts are now, turned the way its first part is turned.
-- The carried egg needs this instead of Model:GetBoundingBox: it is welded to the character, so its parts move with the
-- player but the model's own pivot stays where the egg was put on, and GetBoundingBox measures around that old spot.
-- Nil when the model has no part.
local function boxOfParts(model: Model): (CFrame?, Vector3?)
	local first = model:FindFirstChildWhichIsA("BasePart", true)
	if first == nil then
		return nil, nil
	end
	local inverse = first.CFrame:Inverse()
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local half = descendant.Size / 2
			local toFirst = inverse * descendant.CFrame
			for _, sign in CORNER_SIGNS do
				local corner = toFirst * (sign * half)
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return first.CFrame * CFrame.new((low + high) / 2), high - low
end

-- One egg and what it needs to fade.
type Entry = {
	spot: Instance?, -- the egg spot a waiting egg sits on (nil for the carried egg)
	egg: Model,
	boxCFrame: CFrame?, -- the egg's bounding box: read once for a waiting egg (it is anchored and never moves)
	boxSize: Vector3?,
	seeThrough: number, -- how see-through the egg gets when fully faded
	hold: number, -- seconds with no line crossing before a faded egg starts back to solid (0 for a waiting egg)
	clearFor: number, -- seconds in a row with no line crossing (0 after any frame where one crosses)
	progress: number, -- 0 clear to 1 fully faded
	reassert: boolean, -- true for the carried egg: its fade is written again every frame while it is faded (see `advance`)
	written: number, -- the value last put on the parts, so a part is only written when it changes
	cleanup: () -> (), -- disconnects what follows this egg
}

-- Fades the waiting eggs under `deps.root` that block the view of the player. Returns `stop`, which puts every egg back
-- to clear and disconnects everything.
function EggFade.start(deps: Deps): { stop: () -> () }
	local trove = Trove.new()
	local stopped = false
	local entries: { [Model]: Entry } = {}
	local carriedEntry: Entry? = nil
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

	-- Starts following one egg, clear. `spot` is the egg spot it waits on, or nil for the carried egg.
	local function newEntry(spot: Instance?, egg: Model): Entry
		local eggTrove = Trove.new()
		local entry: Entry = {
			spot = spot,
			egg = egg,
			boxCFrame = nil,
			boxSize = nil,
			seeThrough = if spot == nil then CARRIED_SEE_THROUGH else SEE_THROUGH,
			hold = if spot == nil then CARRIED_HOLD_SECONDS else 0,
			clearFor = 0,
			progress = 0,
			reassert = spot == nil,
			written = 0,
			cleanup = function()
				eggTrove:Destroy()
			end,
		}
		-- A part that arrives while the egg is faded joins in at the same value.
		eggTrove:Add(egg.DescendantAdded:Connect(function(descendant: Instance)
			if entry.written ~= 0 and descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = entry.written
			end
		end))
		return entry
	end

	local function trackEgg(spot: Instance, egg: Instance)
		if stopped or not egg:IsA("Model") or egg.Name ~= EGG_NAME or entries[egg] ~= nil then
			return
		end
		entries[egg] = newEntry(spot, egg)
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

	-- Moves one egg's fade on by `seconds`, towards faded while it blocks and towards clear while it does not. An egg
	-- with a hold starts back only after the hold has passed with no line crossing; the time past the hold in this frame
	-- already counts as fade-back.
	local function advance(entry: Entry, cameraPosition: Vector3?, targets: { Vector3 }, seconds: number)
		if isBlocking(entry, cameraPosition, targets) then
			entry.clearFor = 0
			entry.progress = math.min(1, entry.progress + seconds / FADE_IN_SECONDS)
		else
			entry.clearFor += seconds
			local fadeBackSeconds = math.clamp(entry.clearFor - entry.hold, 0, seconds)
			entry.progress = math.max(0, entry.progress - fadeBackSeconds / FADE_OUT_SECONDS)
		end
		if entry.progress < SNAP then
			entry.progress = 0
		elseif entry.progress > 1 - SNAP then
			entry.progress = 1
		end
		local value = entry.progress * entry.seeThrough
		-- The carried egg is inside the player's character, so Roblox's own camera scripts also write its
		-- LocalTransparencyModifier: 1 when the camera zooms in close, and back to 0 when it zooms out. While the egg is
		-- faded, its value is written again every frame, so the camera's 0 never leaves it covering the player. While it
		-- is clear, nothing is written, and the camera keeps its say.
		if value ~= entry.written or (entry.reassert and value ~= 0) then
			write(entry, value)
		end
	end

	-- Follows the egg the player carries: a new CarriedEgg starts clear, and one that is gone is forgotten. The carried
	-- egg moves with the player, so its box is measured again on every frame (only while it has a part to measure).
	local function followCarried()
		local model = deps.carried()
		local old = carriedEntry
		if old ~= nil and old.egg ~= model then
			old.cleanup()
			carriedEntry = nil
		end
		if model == nil then
			return
		end
		local entry = carriedEntry or newEntry(nil, model)
		carriedEntry = entry
		local boxCFrame, boxSize = boxOfParts(model)
		entry.boxCFrame = boxCFrame
		entry.boxSize = if boxSize ~= nil then boxSize * CARRIED_BOX_SCALE else nil
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
			advance(entry, cameraPosition, targets, seconds)
		end
		followCarried()
		if carriedEntry ~= nil then
			advance(carriedEntry, cameraPosition, targets, seconds)
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
		local entry = carriedEntry
		if entry ~= nil then
			carriedEntry = nil
			if entry.written ~= 0 then
				write(entry, 0)
			end
			entry.cleanup()
		end
	end

	return { stop = stop }
end

return EggFade
