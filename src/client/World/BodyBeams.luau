--!strict
-- Beams on his body hide up close (V2 setup 5; style guide: "Beams on his body hide up close").
-- On the belly path the light columns of the nearby Rare eggs washed the screen white and hid the player. So on each
-- player's own screen, the beam of a waiting egg that sits on his body (Belly, Beard or Nightcap, not the boots and not
-- the meadow) turns off when the camera comes within 30 studs of the egg, and on again beyond 35 studs. Between the two
-- the beam keeps its last state, so it never flickers at the edge. Up close the egg's colour, glow, sparkles and rank
-- word still show its rank (spec Rule 52, "The rank shows everywhere").
-- Beam.Enabled is set on this device only: the server's beams are never touched, so other players see theirs as before.
-- How the client knows an egg is on his body: the zone boxes the server also uses (World.Zones, parts with a Zone
-- attribute) replicate to every client, and an egg whose spot lies inside a Belly, Beard or Nightcap box is on his body.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)

local BodyBeams = {}

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

export type Deps = {
	root: Instance, -- holds the egg spots (Workspace.World.EggSpots)
	isOnBody: (position: Vector3) -> boolean?, -- true on his body, false on the boots or in the meadow, nil when not known yet
	camera: () -> CFrame?, -- where the camera is now (nil when there is none)
	step: SignalLike, -- once per frame (RunService.RenderStepped)
}

-- Starting values from designer's style guide ("Beams on his body hide up close"), not yet proven by a test of the hiding
-- itself. If a light column still shows in Play, raise both by 10 (designer's rule).
-- The beam turns off when the camera is this close to the egg, in studs (30 studs counts as close).
local HIDE_WITHIN_STUDS = 30
-- The beam turns on again when the camera is farther than this, in studs. The gap stops a flicker at the edge.
local SHOW_BEYOND_STUDS = 35

local EGG_NAME = "Egg"
local ZONES_NAME = "Zones"

-- Should the beam be on at this distance? `wasShown` is the state it had before: between the two distances it stays as
-- it was.
function BodyBeams.shouldShow(distance: number, wasShown: boolean): boolean
	if distance <= HIDE_WITHIN_STUDS then
		return false
	end
	if distance > SHOW_BEYOND_STUDS then
		return true
	end
	return wasShown
end

-- Reads the zone boxes in `world.Zones` each time it is asked (the boxes stream in and out with the player, so nothing
-- is kept). True when the position is inside a Belly, Beard or Nightcap box, false when it is not, and nil while the
-- world has no zone boxes here yet, so the caller can leave a beam as it is rather than guess.
function BodyBeams.bodyReader(world: Instance): (Vector3) -> boolean?
	return function(position: Vector3): boolean?
		local zones = world:FindFirstChild(ZONES_NAME)
		if zones == nil then
			return nil
		end
		local sawBox = false
		for _, box in zones:GetChildren() do
			local zone: any = box:GetAttribute("Zone")
			if box:IsA("BasePart") and type(zone) == "string" then
				sawBox = true
				if Config.Ranks.BodyZones[zone] then
					local local_ = box.CFrame:PointToObjectSpace(position)
					local half = box.Size / 2
					if
						math.abs(local_.X) <= half.X
						and math.abs(local_.Y) <= half.Y
						and math.abs(local_.Z) <= half.Z
					then
						return true
					end
				end
			end
		end
		return if sawBox then false else nil
	end
end

-- One waiting egg and its beams.
type Entry = {
	egg: Model,
	shown: boolean, -- whether its beams are on now (true: they have their own value)
	beams: { [Beam]: boolean }, -- each beam and the Enabled value it had before this module touched it
	cleanup: () -> (), -- disconnects what follows this egg
}

-- Hides or shows the beams of the waiting eggs under `deps.root`. Returns `stop`, which puts every beam back to its own
-- value and disconnects everything.
function BodyBeams.start(deps: Deps): { stop: () -> () }
	local trove = Trove.new()
	local stopped = false
	local entries: { [Model]: Entry } = {}
	local spotCleanups: { [Instance]: () -> () } = {}

	-- Puts every beam of the egg on its own value (shown) or off (hidden).
	local function apply(entry: Entry)
		for beam, own in entry.beams do
			beam.Enabled = if entry.shown then own else false
		end
	end

	local function untrackEgg(egg: Instance)
		local entry = entries[egg :: Model]
		if entry ~= nil then
			entries[egg :: Model] = nil
			entry.shown = true
			apply(entry)
			entry.cleanup()
		end
	end

	local function trackEgg(egg: Instance)
		if stopped or not egg:IsA("Model") or egg.Name ~= EGG_NAME or entries[egg] ~= nil then
			return
		end
		local eggTrove = Trove.new()
		local entry: Entry = {
			egg = egg,
			shown = true,
			beams = {},
			cleanup = function()
				eggTrove:Destroy()
			end,
		}
		entries[egg] = entry
		-- A beam is noted with the value it has now, then given the egg's current state (it may arrive after the egg did).
		local function trackBeam(beam: Beam)
			if entry.beams[beam] == nil then
				entry.beams[beam] = beam.Enabled
				if not entry.shown then
					beam.Enabled = false
				end
			end
		end
		eggTrove:Add(egg.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("Beam") then
				trackBeam(descendant)
			end
		end))
		eggTrove:Add(egg.DescendantRemoving:Connect(function(descendant: Instance)
			if descendant:IsA("Beam") then
				entry.beams[descendant] = nil
			end
		end))
		for _, descendant in egg:GetDescendants() do
			if descendant:IsA("Beam") then
				trackBeam(descendant)
			end
		end
	end

	local function trackSpot(spot: Instance)
		if stopped or not spot:IsA("Model") or spotCleanups[spot] ~= nil then
			return
		end
		local spotTrove = Trove.new()
		spotCleanups[spot] = function()
			spotTrove:Destroy()
		end
		spotTrove:Add(spot.ChildAdded:Connect(trackEgg))
		spotTrove:Add(spot.ChildRemoved:Connect(untrackEgg))
		for _, child in spot:GetChildren() do
			trackEgg(child)
		end
	end

	local function untrackSpot(spot: Instance)
		local cleanupSpot = spotCleanups[spot]
		if cleanupSpot == nil then
			return
		end
		spotCleanups[spot] = nil
		cleanupSpot()
		for egg in entries do
			if egg.Parent == spot then
				untrackEgg(egg)
			end
		end
	end

	local function onStep()
		local cameraCFrame = deps.camera()
		if cameraCFrame == nil then
			return
		end
		for _, entry in entries do
			local position = entry.egg:GetPivot().Position
			local distance = (cameraCFrame.Position - position).Magnitude
			local shown: boolean
			if distance > SHOW_BEYOND_STUDS then
				-- Far away every beam is on, whether the egg is on his body or not, so there is nothing to look up.
				shown = true
			else
				local onBody = deps.isOnBody(position)
				if onBody == nil then
					continue
				end
				shown = if onBody then BodyBeams.shouldShow(distance, entry.shown) else true
			end
			if shown ~= entry.shown then
				entry.shown = shown
				apply(entry)
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
		for egg in entries do
			untrackEgg(egg)
		end
		for spot in spotCleanups do
			untrackSpot(spot)
		end
	end

	return { stop = stop }
end

return BodyBeams
