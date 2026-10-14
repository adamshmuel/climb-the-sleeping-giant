--!strict
-- The hand slams on screen (spec Rule 13, "Hand slams hunt egg carriers", and the "Awake" row of section 6). The server
-- tells every player about each slam with two remotes, and each device draws it for itself:
--   * SlamWarning(slam number, the point on the surface, landsAt on the server's clock) comes 1.5 seconds before the
--     landing. It starts a red circle with a gold rim on the surface where the target stands. The circle is made of
--     small pieces that hug the surface under it (SlamCircle works out where each piece goes), so it follows his body,
--     the boot ramps, the bridges and the meadow ground. Building it takes a few frames: at most 1,000 rays a frame.
--   * 0.6 seconds before landsAt a big cartoon fist appears 45 studs up and falls onto the circle, faster and faster.
--     It stays down 0.4 seconds, then lifts away over 0.4 seconds more.
--   * At the landing, a big white puff and gold sparkles burst from 2 studs above the point. The circle is solid until
--     0.4 seconds after the landing, then fades away over 0.3 seconds.
--   * SlamLanded(slam number, the same point) comes on the server's landing tick. If it arrives before landsAt is
--     reached on this device, the landing starts then, and everything after it is counted from that moment.
-- The server decides who is caught; this module only draws. It never looks at the giant's Phase: the server sends no
-- new warnings once he sleeps, and a slam that is already drawn finishes by itself.
-- Everything it touches is passed in, so a test can give it stand-ins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Theme = require(script.Parent.Parent.Hud.Theme)
local SlamCircle = require(script.Parent.SlamCircle)

local SlamFx = {}

-- The fist's timeline, in seconds, counted from the landing (negative is before it).
SlamFx.FIST_FALL_SECONDS = 0.6 -- it appears this long before the landing
SlamFx.FIST_DOWN_SECONDS = 0.4 -- it stays down this long
SlamFx.FIST_LIFT_SECONDS = 0.4 -- it lifts away this long
SlamFx.FIST_DROP_HEIGHT = 45 -- studs above the surface where it appears and where it ends
SlamFx.CIRCLE_FADE_SECONDS = 0.3 -- the circle fades this long, once the fist starts to lift

local FALL_SECONDS = SlamFx.FIST_FALL_SECONDS
local DOWN_SECONDS = SlamFx.FIST_DOWN_SECONDS
local LIFT_SECONDS = SlamFx.FIST_LIFT_SECONDS
local DROP_HEIGHT = SlamFx.FIST_DROP_HEIGHT
local FADE_SECONDS = SlamFx.CIRCLE_FADE_SECONDS
-- A clock only has so many digits: a time a hair outside a range still counts as inside it.
local CLOCK_MARGIN = 1e-6

-- The circle is solid until the fist lifts, then it fades.
local CIRCLE_TRANSPARENCY = 0
-- How many rays all the circles being built may cast in one frame, together. A thousand rays take a few milliseconds,
-- so this keeps a frame short; a circle on level ground is finished in two or three frames.
SlamFx.RAYS_A_FRAME = 1000
local RAYS_A_FRAME = SlamFx.RAYS_A_FRAME
-- The ray that finds the circle's middle (and which way the circle faces) starts above the point and looks a little way down.
local MIDDLE_RAY_START_ABOVE = 1
local MIDDLE_RAY_LENGTH = 4

local FOLDER_NAME = "SlamFx"
local CIRCLE_NAME = "SlamCircle"
local RED_PIECE_NAME = "SlamRedPiece"
local GOLD_PIECE_NAME = "SlamGoldPiece"
local FIST_NAME = "SlamFist"
local DUST_PART_NAME = "SlamDustAnchor"
-- The parts the circle lies on, by name (see huggableParts).
local RAMP_PLANK_NAME = "Ramp_Walk"
local BRIDGE_PLANK_NAME = "Plank"
local DUST_NAME = "SlamDust"
local SPARKLES_NAME = "SlamSparkles"

local DUST_COUNT = 36
local SPARKLES_COUNT = 40
-- The dust starts this far above the circle, along the surface's normal, so a puff isn't half buried in the grass.
local DUST_ABOVE_SURFACE = 2
-- The longest a dust particle lives, which is how long the dust part stays.
local DUST_LIFETIME = NumberRange.new(0.9, 1.3)
local SPARKLES_LIFETIME = NumberRange.new(0.5, 0.9)
-- The ray that finds the surface's slope: it starts above the point and looks a little way down.
local NORMAL_RAY_START_ABOVE = 1
local NORMAL_RAY_LENGTH = 2

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

-- A remote, as far as this module uses it.
export type RemoteLike = { OnClientEvent: SignalLike }

export type PlayersLike = {
	GetPlayers: (self: any) -> { { Character: Model? } },
}

-- A ray that finds what the circle lies on: gives where it hit and the surface's normal there, or nil twice for no hit.
export type CastHug = (origin: Vector3, direction: Vector3) -> (Vector3?, Vector3?)

export type Deps = {
	slamWarning: RemoteLike, -- (slam number, the point on the surface, landsAt on the server's clock)
	slamLanded: RemoteLike, -- (slam number, the same point)
	fist: Model, -- the template: ReplicatedStorage.Assets.SlamFist
	parent: Instance, -- where the folder of parts goes (Workspace)
	surfaceNormal: (point: Vector3) -> Vector3, -- which way the surface under the point faces
	serverNow: () -> number, -- the server's clock (Workspace:GetServerTimeNow)
	step: SignalLike, -- once per frame (RenderStepped)
	burst: (emitter: ParticleEmitter, count: number) -> (), -- emits that many particles at once
	castHug: CastHug,
	refreshHug: (() -> ())?,
	onCircle: (point: Vector3) -> (),
}

-- What start gives back: `stop` removes everything and disconnects everything.
export type Handle = {
	stop: () -> (),
}

-- How many studs the bottom of the fist is above the surface, `secondsFromLanding` after the landing (negative is
-- before it), or nil when there is no fist. It falls faster and faster, stays down, then lifts slowly at first.
function SlamFx.fistHeight(secondsFromLanding: number): number?
	if secondsFromLanding < -FALL_SECONDS - CLOCK_MARGIN then
		return nil
	end
	if secondsFromLanding <= 0 then
		local through = math.clamp((secondsFromLanding + FALL_SECONDS) / FALL_SECONDS, 0, 1)
		return DROP_HEIGHT * (1 - through * through)
	end
	if secondsFromLanding <= DOWN_SECONDS then
		return 0
	end
	local lifted = secondsFromLanding - DOWN_SECONDS
	if lifted > LIFT_SECONDS + CLOCK_MARGIN then
		return nil
	end
	local through = math.clamp(lifted / LIFT_SECONDS, 0, 1)
	return DROP_HEIGHT * through * through
end

-- How see-through the circle is, `secondsFromLanding` after the landing: 0 (solid) while the fist is down (and before),
-- then a straight line to fully see-through over the next 0.3 seconds, then nil: the circle is gone.
function SlamFx.circleTransparency(secondsFromLanding: number): number?
	if secondsFromLanding <= DOWN_SECONDS then
		return CIRCLE_TRANSPARENCY
	end
	local fading = secondsFromLanding - DOWN_SECONDS
	if fading > FADE_SECONDS + CLOCK_MARGIN then
		return nil
	end
	return CIRCLE_TRANSPARENCY + (1 - CIRCLE_TRANSPARENCY) * math.clamp(fading / FADE_SECONDS, 0, 1)
end

-- The real way to find which way the surface under a point faces: one ray from a stud above the point, two studs
-- down. It sees only what a player can stand on, and goes through every player's character and the folder of parts.
-- If nothing is hit, the surface counts as level.
function SlamFx.workspaceSurfaceNormal(
	workspace: Workspace,
	players: PlayersLike,
	parent: Instance
): (point: Vector3) -> Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	return function(point: Vector3): Vector3
		local filter: { Instance } = {}
		for _, player in players:GetPlayers() do
			if player.Character ~= nil then
				table.insert(filter, player.Character)
			end
		end
		local folder = parent:FindFirstChild(FOLDER_NAME)
		if folder ~= nil then
			table.insert(filter, folder)
		end
		params.FilterDescendantsInstances = filter
		local result = workspace:Raycast(
			point + Vector3.new(0, NORMAL_RAY_START_ABOVE, 0),
			Vector3.new(0, -NORMAL_RAY_LENGTH, 0),
			params
		)
		if result == nil then
			return Vector3.yAxis
		end
		return result.Normal
	end
end

-- The parts of his body a circle lies on (not his right arm, which moves during slams).
local GIANT_SOLID_NAMES = { "body_and_cushion", "head_with_beard", "legs_and_boots", "nightcap", "left_arm" }

-- Everything a circle may lie on, as single parts: the meadow and the stream (the Terrain), his body, the two boot
-- ramps' planks and every bridge plank. The list is of single parts, never folders, because a filter takes every
-- descendant: a folder would bring in the bridges' posts and ropes and the invisible planks players walk on. The
-- bridges stream in and out, so a new list is made for every warning (see workspaceCastHug).
function SlamFx.huggableParts(workspace: Workspace, world: Instance): { Instance }
	local list: { Instance } = { workspace.Terrain }
	local giant = world:FindFirstChild("Giant")
	if giant ~= nil then
		for _, name in GIANT_SOLID_NAMES do
			local body = giant:FindFirstChild(name)
			if body ~= nil then
				if body:IsA("BasePart") then
					table.insert(list, body)
				end
				for _, descendant in body:GetDescendants() do
					if descendant:IsA("BasePart") then
						table.insert(list, descendant)
					end
				end
			end
		end
	end
	local walkSurfaces = world:FindFirstChild("WalkSurfaces")
	if walkSurfaces ~= nil then
		for _, descendant in walkSurfaces:GetDescendants() do
			if descendant.Name == RAMP_PLANK_NAME and descendant:IsA("BasePart") then
				table.insert(list, descendant)
			end
		end
	end
	local bridges = world:FindFirstChild("Bridges")
	if bridges ~= nil then
		for _, descendant in bridges:GetDescendants() do
			if descendant.Name == BRIDGE_PLANK_NAME and descendant:IsA("BasePart") then
				table.insert(list, descendant)
			end
		end
	end
	return list
end

-- The real ray for the circle. It sees only what `huggableParts` lists, and only what a player can stand on, and it sees
-- the stream's water (so on a bridge the circle lies on the planks and on the water, not on the stream bed). So the
-- rays go through players, eggs, flowers, rocks, trees, the sock and the other props, the invisible walk planks and
-- guards, and the circle's own pieces. Gives the ray and a `refresh` that makes the list again: call it once for each
-- warning, before the circle's first ray. If it was never called, the first ray makes the list.
function SlamFx.workspaceCastHug(workspace: Workspace, world: Instance): (CastHug, () -> ())
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.RespectCanCollide = true
	params.IgnoreWater = false
	local listed = false

	local function refresh()
		params.FilterDescendantsInstances = SlamFx.huggableParts(workspace, world)
		listed = true
	end

	local function cast(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
		if not listed then
			refresh()
		end
		local result = workspace:Raycast(origin, direction, params)
		if result == nil then
			return nil, nil
		end
		return result.Position, result.Normal
	end

	return cast, refresh
end

-- One slam on screen.
type Slam = {
	point: Vector3,
	normal: Vector3, -- which way the surface under the point faces, from the warning
	landsAt: number, -- when the server says the hand lands
	landTime: number, -- what the fist, the fade and the dust are counted from: landsAt, or when SlamLanded came first
	landed: boolean,
	circle: Folder?, -- the folder of the circle's pieces
	pieces: { Part }, -- every piece made so far
	transparency: number, -- what the pieces are now (new pieces start with it)
	builder: SlamCircle.Builder?, -- still working out pieces, until the circle is finished
	fist: Model?,
	dust: Part?,
}

-- Makes one piece of the circle: a thin Neon block that cannot be touched, collided with or hit by a ray.
local function makePiece(piece: SlamCircle.Piece, transparency: number, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = if piece.gold then GOLD_PIECE_NAME else RED_PIECE_NAME
	part.Shape = Enum.PartType.Block
	part.Size = piece.size
	part.Color = if piece.gold then Theme.slamGold else Theme.slamRed
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = piece.cframe
	part.Parent = parent
	return part
end

-- A big white cloud that spreads out across the circle.
local function makeDustEmitter(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = DUST_NAME
	emitter.Enabled = false
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 8),
		NumberSequenceKeypoint.new(1, 16),
	})
	emitter.Lifetime = DUST_LIFETIME
	emitter.Speed = NumberRange.new(20, 32)
	emitter.SpreadAngle = Vector2.new(85, 85)
	emitter.Drag = 4
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.LightInfluence = 1
	emitter.LightEmission = 0.2
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

-- Gold sparkles that jump up from the point.
local function makeSparklesEmitter(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = SPARKLES_NAME
	emitter.Enabled = false
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Theme.slamGold)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- Each sparkle gets one size, between 0.8 and 1.4 studs (1.1, give or take 0.3), for its whole life.
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1, 0.3),
		NumberSequenceKeypoint.new(1, 1.1, 0.3),
	})
	emitter.Lifetime = SPARKLES_LIFETIME
	emitter.Speed = NumberRange.new(24, 44)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -50, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

-- Starts the slams. Returns a handle whose `stop` removes everything this module made.
function SlamFx.start(deps: Deps): Handle
	local trove = Trove.new()
	local stopped = false
	local slams: { [number]: Slam } = {}
	local folder: Folder? = nil
	local stepConnection: RBXScriptConnection? = nil
	-- The rays cast at a warning (counted in the frame's budget) that the next step must leave out, so a warning and the
	-- step that follows it in the same frame together stay inside one frame's rays.
	local raysSpentAtWarning = 0
	local dustSeconds = math.max(DUST_LIFETIME.Max, SPARKLES_LIFETIME.Max)

	-- Where the fist's bottom sits compared with its pivot, and how the template is turned. The bottom is the lowest
	-- corner of the bounding box, and the fist is centred over the point by the middle of that box.
	local templatePivot = deps.fist:GetPivot()
	local boxCFrame, boxSize = deps.fist:GetBoundingBox()
	local lowest = math.huge
	for _, sideX in { -1, 1 } do
		for _, sideY in { -1, 1 } do
			for _, sideZ in { -1, 1 } do
				local corner = boxCFrame:PointToWorldSpace(
					Vector3.new(sideX * boxSize.X / 2, sideY * boxSize.Y / 2, sideZ * boxSize.Z / 2)
				)
				lowest = math.min(lowest, corner.Y)
			end
		end
	end
	local bottomCentre = Vector3.new(boxCFrame.Position.X, lowest, boxCFrame.Position.Z)
	local pivotToBottom = bottomCentre - templatePivot.Position
	local fistTurn = templatePivot.Rotation

	local function ensureFolder(): Folder
		local existing = folder
		if existing ~= nil then
			return existing
		end
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = deps.parent
		folder = made
		return made
	end

	-- Takes the circle away (the folder takes every piece with it) and stops working out more pieces.
	local function destroyCircle(slam: Slam)
		slam.builder = nil
		table.clear(slam.pieces)
		if slam.circle ~= nil then
			slam.circle:Destroy()
			slam.circle = nil
		end
	end

	local function destroySlam(slam: Slam)
		destroyCircle(slam)
		local others: { Instance? } = { slam.fist, slam.dust }
		for _, other in others do
			if other ~= nil then
				other:Destroy()
			end
		end
		slam.fist = nil
		slam.dust = nil
	end

	-- Makes the parts for new pieces, in the slam's circle folder.
	local function addPieces(slam: Slam, pieces: { SlamCircle.Piece })
		local circle = slam.circle
		if circle == nil then
			return
		end
		for _, piece in pieces do
			table.insert(slam.pieces, makePiece(piece, slam.transparency, circle))
		end
	end

	-- Works out more of a slam's circle with at most `raysAllowed` rays. Gives how many rays it cast.
	local function build(slam: Slam, raysAllowed: number): number
		local builder = slam.builder
		if builder == nil then
			return 0
		end
		local before = builder.raysUsed()
		local result = builder.step(raysAllowed)
		addPieces(slam, result.pieces)
		if result.finished then
			slam.builder = nil
		end
		return builder.raysUsed() - before
	end

	local function disconnectStep()
		if stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end

	-- The landing: the dust and sparkles burst, and the times after it are counted from `landTime`.
	local function land(slam: Slam, landTime: number)
		slam.landed = true
		slam.landTime = landTime
		local dust = Instance.new("Part")
		dust.Name = DUST_PART_NAME
		dust.Size = Vector3.new(1, 1, 1)
		dust.Transparency = 1
		dust.Anchored = true
		dust.CanCollide = false
		dust.CanQuery = false
		dust.CanTouch = false
		dust.CastShadow = false
		-- Upright (no turn), so the puffs go up whatever the slope; 2 studs up along the surface's normal.
		dust.CFrame = CFrame.new(slam.point + slam.normal * DUST_ABOVE_SURFACE)
		dust.Parent = ensureFolder()
		slam.dust = dust
		deps.burst(makeDustEmitter(dust), DUST_COUNT)
		deps.burst(makeSparklesEmitter(dust), SPARKLES_COUNT)
	end

	-- Makes the slam's fist: a copy of the template with every part anchored, not solid, not hit by rays and not
	-- touchable.
	local function makeFist(slam: Slam): Model
		local copy = deps.fist:Clone()
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		copy.Name = FIST_NAME
		copy.Parent = ensureFolder()
		slam.fist = copy
		return copy
	end

	-- Puts the fist, the circle and the dust of one slam where they belong at `now`. Gives true when the slam is over.
	local function update(slam: Slam, now: number): boolean
		if not slam.landed and now >= slam.landsAt then
			land(slam, slam.landsAt)
		end
		local seconds = now - slam.landTime

		local height = SlamFx.fistHeight(seconds)
		if height ~= nil then
			local fist = slam.fist or makeFist(slam)
			fist:PivotTo(CFrame.new(slam.point + Vector3.new(0, height, 0) - pivotToBottom) * fistTurn)
		else
			local gone = slam.fist
			if gone ~= nil then
				gone:Destroy()
				slam.fist = nil
			end
		end

		local transparency = SlamFx.circleTransparency(seconds)
		if transparency ~= nil then
			if transparency ~= slam.transparency then
				slam.transparency = transparency
				for _, piece in slam.pieces do
					piece.Transparency = transparency
				end
			end
		else
			destroyCircle(slam)
		end

		if slam.dust ~= nil and seconds >= dustSeconds then
			slam.dust:Destroy()
			slam.dust = nil
		end

		return slam.landed and slam.circle == nil and slam.fist == nil and slam.dust == nil
	end

	local function onStep(_deltaTime: number?)
		if stopped then
			return
		end
		local now = deps.serverNow()
		-- This frame's rays, less what the warnings that came in the same frame already used.
		local raysLeft = math.max(0, RAYS_A_FRAME - raysSpentAtWarning)
		raysSpentAtWarning = 0
		local numbers: { number } = {}
		for number in slams do
			table.insert(numbers, number)
		end
		table.sort(numbers)
		for _, number in numbers do
			local slam = slams[number]
			if slam ~= nil then
				-- Pieces first, then the fist and the fade: a piece made now already has this frame's see-through-ness.
				if raysLeft > 0 and SlamFx.circleTransparency(now - slam.landTime) ~= nil then
					raysLeft -= build(slam, raysLeft)
				end
				if update(slam, now) then
					slams[number] = nil
				end
			end
		end
		if next(slams) == nil then
			disconnectStep()
		end
	end

	local function connectStep()
		if stepConnection == nil then
			stepConnection = deps.step:Connect(onStep)
		end
	end

	local function onWarning(number: any, point: any, landsAt: any)
		if stopped or type(number) ~= "number" or typeof(point) ~= "Vector3" or type(landsAt) ~= "number" then
			return
		end
		-- A time that isn't a number (NaN) is never equal to itself.
		if number ~= number or landsAt ~= landsAt then
			return
		end
		local now = deps.serverNow()
		if landsAt <= now then
			return
		end
		local earlier = slams[number]
		if earlier ~= nil then
			destroySlam(earlier)
		end
		local normal = deps.surfaceNormal(point)
		-- The dust is placed along the normal, so it needs a length of 1 (and a level surface if there is no direction).
		local up = if normal.Magnitude > 1e-6 then normal.Unit else Vector3.yAxis
		local circle = Instance.new("Folder")
		circle.Name = CIRCLE_NAME
		circle.Parent = ensureFolder()
		local slam: Slam = {
			point = point,
			normal = up,
			landsAt = landsAt,
			landTime = landsAt,
			landed = false,
			circle = circle,
			pieces = {},
			transparency = CIRCLE_TRANSPARENCY,
		}
		-- One ray finds the circle's middle and which way it faces. If it finds nothing, the circle is centred on the
		-- point and faces straight up (its pieces still find their own surface).
		if deps.refreshHug ~= nil then
			deps.refreshHug()
		end
		local middle, circleUp = point, Vector3.yAxis
		local hit, hitNormal =
			deps.castHug(point + Vector3.new(0, MIDDLE_RAY_START_ABOVE, 0), Vector3.new(0, -MIDDLE_RAY_LENGTH, 0))
		if hit ~= nil and hitNormal ~= nil and hitNormal.Magnitude > 1e-6 then
			middle, circleUp = hit, hitNormal.Unit
		end
		slam.builder = SlamCircle.new(middle, circleUp, deps.castHug)
		slams[number] = slam
		connectStep()
		-- The first pieces at once, so the circle shows on this very frame (the middle ray was one of the rays).
		raysSpentAtWarning += 1 + build(slam, RAYS_A_FRAME - 1)
		deps.onCircle(point)
	end

	-- The server says the hand landed. If this device hasn't reached landsAt yet, the landing starts now.
	local function onLanded(number: any, _point: any)
		if stopped or type(number) ~= "number" then
			return
		end
		local slam = slams[number]
		if slam == nil or slam.landed then
			return
		end
		local now = deps.serverNow()
		land(slam, now)
		update(slam, now)
	end

	trove:Add(function()
		disconnectStep()
		for _, slam in slams do
			destroySlam(slam)
		end
		table.clear(slams)
		if folder ~= nil then
			folder:Destroy()
			folder = nil
		end
	end)
	trove:Add(deps.slamWarning.OnClientEvent:Connect(onWarning))
	trove:Add(deps.slamLanded.OnClientEvent:Connect(onLanded))

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			trove:Destroy()
		end,
	}
end

return SlamFx
