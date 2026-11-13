--!strict
-- What more than one section of the world script needs from the start of the file and from the walk pieces: the six body pieces' records, the rays that read their shape, how to wait for it, and the checks and builders for the walk parts.

local Workspace = game:GetService("Workspace")

local Shared = {}

local PIECE_NAMES = { "legs_and_boots", "body_and_cushion", "left_arm", "right_arm", "head_with_beard", "nightcap" }

-- The belly and chair piece: after section 2f it is Tunable (the other five stay PreciseConvexDecomposition), and
-- section 1 accepts that and leaves it alone.
local BODY_PIECE = "body_and_cushion"

-- The four pieces that end up Tunable: section 2f gives the belly and chair piece the first Tunable shape, section 2f2
-- (the closer fit) gives it, the head and the nightcap CollisionPrecision 1, and section 2f5 gives the legs the same.
-- Section 1 accepts Tunable for them and leaves them alone (both arms stay PreciseConvexDecomposition).
local CLOSER_FIT_PIECES: { [string]: boolean } = {
	legs_and_boots = true,
	body_and_cushion = true,
	head_with_beard = true,
	nightcap = true,
}

-- Each body piece as recorded by hand in Studio Edit mode on 2026-10-20 (all CollisionFidelity Default, group Default).
-- A live size or place that differs by more than RECORD_TOLERANCE studs is not the piece these numbers belong to.
export type Record = { size: Vector3, position: Vector3 }

local RECORDS: { [string]: Record } = {
	legs_and_boots = {
		size = Vector3.new(75.36635, 39.49615, 86.80042),
		position = Vector3.new(0.10107, 16.74808, -24.95072),
	},
	body_and_cushion = {
		size = Vector3.new(117.64268, 73.37317, 116.49847),
		position = Vector3.new(-0.00176, 33.69648, 9.96119),
	},
	left_arm = {
		size = Vector3.new(37.76285, 51.4045, 30.83275),
		position = Vector3.new(-37.73672, 35.05844, -1.19125),
	},
	right_arm = {
		size = Vector3.new(37.49444, 51.63819, 30.80338),
		position = Vector3.new(37.47129, 34.98576, -1.1528),
	},
	head_with_beard = {
		size = Vector3.new(91.33508, 71.77839, 80.78034),
		position = Vector3.new(-0.0668, 83.20127, 21.08331),
	},
	nightcap = {
		size = Vector3.new(102.5489, 64.15547, 67.58839),
		position = Vector3.new(0.02109, 90.92226, 34.55848),
	},
}

local RECORD_TOLERANCE = 0.01

-- The fixed rays of one piece, as fractions of its size from its middle: straight down from just above its top, and
-- level along x from just outside its low-x side. 16 of each, 32 in all.
local RAY_FRACTIONS = { -0.3, -0.1, 0.1, 0.3 }

local RAY_MARGIN = 1 -- studs outside the piece where each ray starts

-- Two reads agree when no ray differs by more than this.
local AGREE_WITHIN = 0.01

-- A piece changed now must have at least one ray that moved by more than this from before the change, or Roblox has
-- not started to apply the new shape yet.
local MOVED_AT_LEAST = 0.01

local READ_EVERY = 2 -- seconds between two reads

local MAX_WAIT = 120 -- seconds

export type FixedRay = { origin: Vector3, direction: Vector3 }

local function fixedRays(record: Record): { FixedRay }
	local rays: { FixedRay } = {}
	local size, middle = record.size, record.position
	for _, fractionA in RAY_FRACTIONS do
		for _, fractionB in RAY_FRACTIONS do
			table.insert(rays, {
				origin = middle + Vector3.new(fractionA * size.X, size.Y / 2 + RAY_MARGIN, fractionB * size.Z),
				direction = Vector3.new(0, -(size.Y + 2 * RAY_MARGIN), 0),
			})
		end
	end
	for _, fractionA in RAY_FRACTIONS do
		for _, fractionB in RAY_FRACTIONS do
			table.insert(rays, {
				origin = middle + Vector3.new(-(size.X / 2 + RAY_MARGIN), fractionA * size.Y, fractionB * size.Z),
				direction = Vector3.new(size.X + 2 * RAY_MARGIN, 0, 0),
			})
		end
	end
	return rays
end

-- How far each fixed ray travels before it hits the piece (-1 for a miss). The Include filter holds this piece alone, so
-- nothing else can answer, and RespectCanCollide is off, so only the piece's own shape counts.
-- `world` is the Workspace unless a WorldModel holding the piece is given (section 2f2 reads its staging copies there).
local function readRays(mesh: MeshPart, rays: { FixedRay }, world: WorldRoot?): { number }
	local root: WorldRoot = world or Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mesh }
	params.RespectCanCollide = false
	local distances: { number } = {}
	for _, ray in rays do
		local hit = root:Raycast(ray.origin, ray.direction, params)
		table.insert(distances, if hit == nil then -1 else (hit.Position - ray.origin).Magnitude)
	end
	return distances
end

-- The largest difference between two reads of the same rays.
local function largestDifference(first: { number }, second: { number }): number
	local largest = 0
	for index, value in first do
		largest = math.max(largest, math.abs(value - second[index]))
	end
	return largest
end

export type Piece = { name: string, mesh: MeshPart, rays: { FixedRay }, changing: boolean, before: { number } }

-- Finds the six pieces and checks each against its record. Returns the pieces, or a list of what is wrong.
local function findPieces(): ({ Piece }, { string })
	local problems: { string } = {}
	local pieces: { Piece } = {}
	local world = Workspace:FindFirstChild("World")
	local giant = if world ~= nil then world:FindFirstChild("Giant") else nil
	if giant == nil then
		table.insert(problems, "World.Giant is missing")
		return pieces, problems
	end
	for _, name in PIECE_NAMES do
		local model = giant:FindFirstChild(name)
		local mesh = if model ~= nil then model:FindFirstChild(name) else nil
		if mesh == nil or not mesh:IsA("MeshPart") then
			table.insert(problems, `World.Giant.{name}.{name} is missing or is not a MeshPart`)
			continue
		end
		local record = RECORDS[name]
		local fullName = mesh:GetFullName()
		if (mesh.Size - record.size).Magnitude > RECORD_TOLERANCE then
			table.insert(problems, `{fullName}: size is {mesh.Size}, recorded {record.size}`)
		end
		if (mesh.Position - record.position).Magnitude > RECORD_TOLERANCE then
			table.insert(problems, `{fullName}: position is {mesh.Position}, recorded {record.position}`)
		end
		if mesh.CollisionGroup ~= "Default" then
			table.insert(problems, `{fullName}: CollisionGroup is {mesh.CollisionGroup}, expected Default`)
		end
		if not mesh.CanCollide or not mesh.CanQuery or not mesh.CanTouch then
			table.insert(
				problems,
				`{fullName}: CanCollide {mesh.CanCollide}, CanQuery {mesh.CanQuery}, CanTouch {mesh.CanTouch}; all three must be on`
			)
		end
		local tunableCloserFit = CLOSER_FIT_PIECES[name] == true
			and mesh.CollisionFidelity == Enum.CollisionFidelity.Tunable
		if
			mesh.CollisionFidelity ~= Enum.CollisionFidelity.Default
			and mesh.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition
			and not tunableCloserFit
		then
			table.insert(
				problems,
				`{fullName}: CollisionFidelity is {mesh.CollisionFidelity.Name}, expected Default or PreciseConvexDecomposition{if CLOSER_FIT_PIECES[name]
					then " or Tunable (after section 2f, 2f2 or 2f5)"
					else ""}`
			)
		end
		table.insert(pieces, {
			name = name,
			mesh = mesh,
			rays = fixedRays(record),
			changing = mesh.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition
				and not tunableCloserFit,
			before = {},
		})
	end
	return pieces, problems
end

-- Reads every piece's rays again every READ_EVERY seconds until two reads in a row agree on every piece, and every piece
-- that was changed now has moved away from its "before" read. Returns whether it settled, the seconds it took, and for each
-- piece the largest move from its "before" read.
local function waitForShapes(pieces: { Piece }): (boolean, number, { [string]: number })
	local started = os.clock()
	local moves: { [string]: number } = {}
	local previous: { [string]: { number } } = {}
	for _, piece in pieces do
		previous[piece.name] = readRays(piece.mesh, piece.rays)
		moves[piece.name] = largestDifference(piece.before, previous[piece.name])
	end
	while os.clock() - started < MAX_WAIT do
		task.wait(READ_EVERY)
		local steady = true
		for _, piece in pieces do
			local current = readRays(piece.mesh, piece.rays)
			if largestDifference(previous[piece.name], current) > AGREE_WITHIN then
				steady = false
			end
			previous[piece.name] = current
			moves[piece.name] = largestDifference(piece.before, current)
			if piece.changing and moves[piece.name] <= MOVED_AT_LEAST then
				steady = false
			end
		end
		if steady then
			return true, os.clock() - started, moves
		end
	end
	return false, os.clock() - started, moves
end

-- Why: V1's invisible walk pieces were placed 0.7 studs over his old, rough collision shape and float up to several studs
-- over his real one (designer, 2026-10-20: players seem to walk on air). Where his own skin is walkable the pieces go and
-- players walk on his skin; where it is not, a fitted piece or a crossing ramp joins the path (Rule 20, One collision
-- source; docs/plans/v2/stuck-safety.md, Task 24, Rulings 1 to 9). All numbers below were measured by hand in Studio
-- Edit mode on 2026-10-20 with rays that see only his six body pieces.
--   * The step piece: the left boot top has a 1 stud step (z -60.4 to -59.6, his skin 30.7 down to 29.75). The shared walk
--     check stops at a step over 0.5 studs, so one board stays there, fitted to his skin: tilted 22 degrees to follow the
--     step and 4 degrees across. Every point of its top (a grid 1 stud apart, 0.5 in from the edges) is -0.07 to 0.31 studs
--     from his skin (the window is -0.2 to 0.7) and its two ends are within 0.15 studs of the skin outside them.
--   * CrossingRamp_Ankle crosses the boot's top edge (a wall 4.3 studs high over 1 stud). A wedge 5 wide, 45 degrees, its
--     top flush with the boot top at the lip. Its bottom is tilted 14 degrees to follow the shin, which rises away from
--     the wall, so the wedge is solid down into his skin everywhere. Top edges: -0.15 to 0.63 studs from his skin.
--     It floats at most 2.9 studs over the shin, under the wall's lip.
--   * CrossingRamp_Knee (first run, replaced): square to the knee wall (31 degrees about the vertical), 5 x 8.8 x 8.8,
--     top edges -0.12 to 0.14 studs from his skin, floating at most 5.5 studs over the shin. It ended below the steep
--     band under Rare egg 1, so it could not reach the egg. Its numbers stay in FIRST_RUN_KNEE_PARTS.
--   * CrossingRamp_Knee (final, Ruling 10): one straight 45 degree wedge, 5 wide, 16.04 x 9.85 long, turned 34.72 degrees
--     about the vertical and leaning 13.51. Its foot is on the shin (0.12 below to 0.40 above his skin along the edge, and
--     1 stud clear of the ankle ramp) and its tip is flush with the top of the steep band (0.04 below to 0.11 above), at
--     (-17.2, 38.9, -38.9). It floats at most 6.5 studs over his skin, at the knee wall's foot (limit 8.0).
--   * The guards: a thin wedge standing on each ramp side where the skin beside it is steeper than 70 degrees (the walls
--     themselves), 1.2 studs deep, its top a slope of 82 to 85 degrees so nobody can stand on it, from his skin up to
--     4.5 studs over the ramp top (the long ramp's: 3.6 studs long, covering 9.2 to 12.8 studs up the ramp). Same
--     settings as V1's steep guards. Two for each ramp.
--   * The knee guards' friction (Ruling 12): both have CustomPhysicalProperties (0.7, 0, 0.5, 100, 1), friction 0. A
--     player cutting the corner to Rare egg 1 was held against Knee_Guard_2's end and the 68 degree skin past it; with
--     friction 0 they slide along the guard and reach the egg. Walking into a guard still stops the player. The ankle
--     guards keep the material's own friction.
--   * Belly_Walk 8 goes (V1's board over the bend: the centre line is 58 to 61 degrees, only a corner of its 10 wide board
--     is 66), and every piece on the bare shin, the knee's far side and the belly path up to Rare egg 2. All of
--     RightBoots_Walk goes: the right boot top is flat (21 to 31 degrees).
local WALK_FOLDER_NAME = "WalkSurfaces"

local SIZE_TOLERANCE = 0.005 -- studs: a recorded size or place closer than this is "the same"

local PLACE_TOLERANCE = 0.01

local ROTATION_TOLERANCE = 0.002 -- on each of the nine numbers of the turn

local GUARD_COLOR = Color3.new(0.639216, 0.635294, 0.647059) -- V1's SteepGuards'

local function describePlace(cframe: CFrame): string
	local position = cframe.Position
	return string.format("(%.2f, %.2f, %.2f)", position.X, position.Y, position.Z)
end

-- Whether a part has the recorded size and place (`why` says what differs when it does not).
local function sameAs(part: BasePart, size: Vector3, cframe: CFrame): (boolean, string)
	if (part.Size - size).Magnitude > SIZE_TOLERANCE then
		return false, string.format("size %s, recorded %s", tostring(part.Size), tostring(size))
	end
	if (part.Position - cframe.Position).Magnitude > PLACE_TOLERANCE then
		return false, string.format("place %s, recorded %s", describePlace(part.CFrame), describePlace(cframe))
	end
	local live, recorded = { part.CFrame:GetComponents() }, { cframe:GetComponents() }
	for index = 4, 12 do
		if math.abs(live[index] - recorded[index]) > ROTATION_TOLERANCE then
			return false, "turn differs from the recorded turn"
		end
	end
	return true, ""
end

-- Whether a part's CustomPhysicalProperties are `wanted` (nil means the material's own).
local function samePhysics(part: BasePart, wanted: PhysicalProperties?): boolean
	local live = part.CustomPhysicalProperties
	if not live or not wanted then
		return not live and not wanted
	end
	return math.abs(live.Density - wanted.Density) < 0.001
		and math.abs(live.Friction - wanted.Friction) < 0.001
		and math.abs(live.Elasticity - wanted.Elasticity) < 0.001
		and math.abs(live.FrictionWeight - wanted.FrictionWeight) < 0.001
		and math.abs(live.ElasticityWeight - wanted.ElasticityWeight) < 0.001
end

Shared.BODY_PIECE = BODY_PIECE
Shared.CLOSER_FIT_PIECES = CLOSER_FIT_PIECES
Shared.RECORDS = RECORDS
Shared.RECORD_TOLERANCE = RECORD_TOLERANCE
Shared.RAY_MARGIN = RAY_MARGIN
Shared.AGREE_WITHIN = AGREE_WITHIN
Shared.MOVED_AT_LEAST = MOVED_AT_LEAST
Shared.READ_EVERY = READ_EVERY
Shared.MAX_WAIT = MAX_WAIT
Shared.readRays = readRays
Shared.largestDifference = largestDifference
Shared.findPieces = findPieces
Shared.waitForShapes = waitForShapes
Shared.WALK_FOLDER_NAME = WALK_FOLDER_NAME
Shared.SIZE_TOLERANCE = SIZE_TOLERANCE
Shared.PLACE_TOLERANCE = PLACE_TOLERANCE
Shared.GUARD_COLOR = GUARD_COLOR
Shared.describePlace = describePlace
Shared.sameAs = sameAs
Shared.samePhysics = samePhysics

return Shared
