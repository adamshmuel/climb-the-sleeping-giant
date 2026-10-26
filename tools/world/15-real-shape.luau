--!strict
-- World prep, V2 stuck safety Task 19 onwards: the giant stands on his real shape, patched (docs/plans/v2/stuck-safety.md,
-- "How his real shape is patched"; Rule 20, One collision source).
-- Why: players must stand on the surface they see. His six body pieces first had Roblox's old collision shape, which
-- left 1332 spots where a player could get stuck. Roblox's closest match of the mesh players see (CollisionFidelity
-- PreciseConvexDecomposition) leaves about 436, and small patches and slide guards take care of the rest.
-- This file grows one section per task, each with fixed numbers, so a second run always says "already done":
--   1. His real shape (stuck safety Task 19): sets the six body pieces to PreciseConvexDecomposition.
--   2. Walk pieces (Task 24, this file's second section): V1's invisible walk pieces on his legs and belly sit on his
--      skin, or go. See "Section 2" below.
--   2b. Head (Task 25): his nose deck, his nightcap and both ladder ends sit on his skin. See "Section 2b" below.
--   2c. Zone over the nose rails (Task 25): the Beard_Ladder zone box grows 4 studs upward. See "Section 2c" below.
--   2d. Rail tops and the ladder slot (Task 25, Rulings 12 and 13): the 2 rails beside the nose become wedges with no
--       flat top, and one invisible LadderSlotBlock per side fills the slot beside the cap ladder. See "Section 2d" below.
--   2e. Beard ladder foot (Task 25, step 6b-1): the 2 beard rails grow 3.15 studs at their bottom end to touch his belly,
--       and one more rung goes in below the 16. See "Section 2e" below.
--   2f. His body follows his skin (Task 26, step 26-2): body_and_cushion becomes Tunable (the other five pieces stay
--       PreciseConvexDecomposition), and the beard ladder's climbing truss grows 2.0 studs at its bottom end. See
--       "Section 2f" below.
--   2f2. A closer fit (Task 26, step 26-4b): body_and_cushion, head_with_beard and nightcap become Tunable with
--       CollisionPrecision 1 (legs_and_boots and both arms stay PreciseConvexDecomposition until 2f5, the arms for good).
--       See "Section 2f2" below.
--   2f3. The slot blocks reach his closer skin (Task 26, step 26-4d2): both LadderSlotBlocks grow forward and down, from
--       1 x 12 x 4 to 1 x 17 x 6 (Ruling 7). See "Section 2f3" below.
--   2f4. The beard truss and the cap rails' part B (Task 26, step 26-4d4, Ruling 8): the beard ladder's invisible
--       climbing truss grows from 30 to 32 at its bottom end, and both part B SideRails end sooner (z 6.0 -> 2.5). See
--       "Section 2f4" below.
--   2f5. The legs' closer fit (Task 26, step 26-4f, Ruling 9): legs_and_boots becomes Tunable with CollisionPrecision 1
--       too (both arms stay PreciseConvexDecomposition). See "Section 2f5" below.
--   2f6. The beard truss's foot swings back (Task 26, step 26-6a1b, Ruling 12): the invisible climbing truss keeps its top
--       end and its 2 x 2 x 32 size, and its foot end moves 1.0 stud toward his beard, so a walker is only lifted where
--       he visibly touches the ladder. See "Section 2f6" below.
--   2g. Beard rails reach his drawn belly (Task 25, after the Task 26 ruling): each beard rail grows 2.75 studs at its
--       bottom end only, and one more rung, a copy of the lowest, goes in below the 17. See "Section 2g" below.
--   3a. The pillow's closer fit (Task 22, step 22-2): the pillow behind his head (World.GiantsThings.Pillow.body.body_geom)
--       becomes Tunable with CollisionPrecision 1, so a player stands on the pillow he sees. See "Section 3a" below.
--   3a2. Lit like before (Task 22, step 22-6d): the pillow's CastShadow becomes false, because the precise solid shape
--       shades the pillow itself and made it look dark navy and tan. See "Section 3a2" below.
--   3b. Patches (Task 22, step 22-9): 41 invisible blocks (Patch_Cave_<n>) in the new folder World.WalkSurfaces.Patches that
--       close off the cave under his cushion. See "Section 3b and 3c" below.
--   3c. The cave skirt (Task 22, step 22-9): 20 visible red blocks (CaveSkirt_<n>) in the new folder World.CaveSkirt across
--       the cave's mouth, solid for players. See "Section 3b and 3c" below.
--   4. Slide guards and small patches (Task 23, step 23-10): 3 invisible slide guards (SlideGuard_<Place>_<n>) in the new
--      folder World.WalkSurfaces.SlideGuards and 85 invisible small patches (Patch_<Place>_<n>) in the new folder
--      World.WalkSurfaces.SmallPatches. See "Section 4" below.
-- Section 1 does this:
--   - It refuses to run in Play: a running game can't change CollisionFidelity.
--   - It checks everything first. Each of the six body pieces (World.Giant.<piece>.<piece>, a MeshPart) must be there
--     with its recorded size and place, in the collision group Default, with CanCollide, CanQuery and CanTouch on. Any
--     difference stops the script with nothing changed and names what is wrong.
--   - It sets CollisionFidelity to PreciseConvexDecomposition on each piece that is not there yet. Nothing else about the
--     pieces changes. stray_bits_A, stray_bits_B, AwakeEyes and SleepEyes are left alone.
--   - It waits until Roblox has worked out the new shapes (it takes about 24 seconds): a few fixed rays per piece are sent
--     again every READ_EVERY seconds until two reads in a row agree, and (for a piece changed now) until its rays have
--     moved away from what they hit before the change. It gives up after MAX_WAIT seconds and says so.
--   - It reports how long the wait took.
-- Section 2 (stuck safety Task 24, "His walk pieces sit on his skin": legs and belly) does this:
--   - It checks everything first. In V1's world the 33 old pieces in World.WalkSurfaces (Boots_Walk 8, RightBoots_Walk 8, Belly_Walk 17)
--     must each match a recorded name, size and place (measured by hand in Studio on 2026-10-20), and there must be no
--     CrossingRamp_* part and no CrossingGuards folder. Any difference stops the script with nothing changed.
--   - It knows three worlds, each checked against fixed recorded numbers, and changes nothing on any difference:
--       (a) V1's world: all 33 old pieces are there (the saved place file still has them). They all go and the final
--           parts come in.
--       (b) The first run's world (an earlier version of this section ran in Studio): the step piece, CrossingRamp_Ankle
--           and its 2 guards are as recorded, and CrossingRamp_Knee (5 x 8.8 x 8.8) and Knee_Guard_1 and Knee_Guard_2 are
--           the first run's. Those three go (their old size and place are in the report) and the long knee ramp and its
--           2 guards come in.
--       (c) The final world: nothing is changed, and it says "already done".
--       (d) The final shape with the two knee guards on the material's own friction (the world after an earlier run of
--           this section): only their friction is set, and the report says so (Ruling 12).
--       Anything else stops with nothing changed. (a), (b) and (d) end in exactly the same world.
--   - Between two ChangeHistoryService waypoints it destroys the old pieces (each one's old size and place is in the
--     report) and puts in the new ones, all built away from the Workspace first:
--       * one fitted Boots_Walk "step piece" over the 1 stud step in the left boot top;
--       * CrossingRamp_Ankle and CrossingRamp_Knee: solid invisible wedges, 5 studs wide, at most 45 degrees, that sit flush
--         with the top of the wall they cross and are solid down into his skin (Rule 20, crossing ramps). The knee ramp is
--         one long wedge (Ruling 10) from his shin over the knee wall, the shelf and the steep band below Rare egg 1;
--       * the folder CrossingGuards with 2 invisible edge guards for each ramp, where the ramp's sides cross steep skin.
--     Nothing else in the place changes. The mockup folders are not touched.
--   - A second run finds the new parts exactly as recorded and says "already done".
--   - There is no third ramp (CrossingRamp_Steep): a separate 45 degree ramp flush with the top of the steep band under
--     Rare egg 1 would have to start over the knee wall (the strip of skin between the wall and the band is too narrow),
--     where nothing can hold it up. The knee ramp goes on over the band instead (Ruling 10).
-- Section 2b (stuck safety Task 25, "His nose deck, his nightcap and the ladder ends sit on his skin": his head) does this:
--   - Source: docs/plans/v2/stuck-safety.md, Task 25 and its Rulings 1 to 11 (Rule 20, One collision source; Rule 15, The
--     climb needs no jump; Rule 22, What counts as stuck). All numbers below are the plan's fixed final numbers.
--   - It refuses to run in Play, and it checks everything first: every head part under World.WalkSurfaces (Nose_Walk,
--     the 3 Nightcap_Walk, the folder ForeheadGuard, the models BeardLadder and CapLadder, 52 parts in all) must be
--     as recorded, with its recorded size, place, turn and settings.
--   - It knows two worlds, each checked against fixed recorded numbers, and changes nothing on any difference:
--       (a) V1's head (the saved place file and today's world): the 52 parts are exactly as measured in Studio on
--           2026-10-20. The change below is made.
--       (b) The final head: nothing is changed, and it says "already done". Part A may be this section's box or section
--           2d's wedge (with the 2 slot blocks); both count as the final head, and so does section 2e's longer beard
--           rails (31.85 instead of 28.70) with the 17th rung.
--       Anything else stops with nothing changed and names what differs.
--   - The change (between two ChangeHistoryService waypoints, new parts built away from the Workspace first):
--       * Nose_Walk and the 3 Nightcap_Walk go: his skin is walkable there (the nose top is under 65 degrees at body size
--         and the cap's slope is under 51), so players walk on it (Rule 20). The middle Guard of ForeheadGuard (the
--         slab, |x| under 7, rising 68.6 degrees) goes too; the four side Guards stay.
--       * V1's 2 SideRail go. 4 new invisible SideRail (2 per side) close the open nose top's sides, down into his skin:
--         part A on the nose (turned about +-14.6 degrees to follow the walkable edge) and part B beside the cap ladder.
--       * The cap ladder is re-made as shape B (the designer's pick): 71.5 degrees, 10 rungs 1.80 apart in the middle
--         of his face, from the bridge of his nose to the brim's top edge. Same rail, rung and truss as V1's, same names
--         and settings; truss 2 x 2 x 16.
--       * The beard ladder is shortened to 16 rungs, tilted to 65.3 degrees about its truss foot, and its truss and rails
--         are shortened, so its top lands on his nose. Its foot stays where it is.
--   - A second run finds the final head exactly as recorded and says "already done".
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It runs again safely: section 1 changes nothing when all six pieces are PreciseConvexDecomposition and their rays are
-- steady (body_and_cushion, head_with_beard and nightcap may be Tunable once sections 2f and 2f2 have run, legs_and_boots
-- once 2f5 has), and sections 2, 2b, 2c, 2d, 2e, 2f, 2f2, 2f3, 2f4, 2f5, 2f6, 2g, 3a, 3a2, 3b and 3c change nothing once their parts are there; all
-- say "already done". The place
-- file must be saved by Adam afterwards, because Roblox keeps the worked-out shapes with the place.

local Workspace = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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
type Record = { size: Vector3, position: Vector3 }
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

type FixedRay = { origin: Vector3, direction: Vector3 }

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

type Piece = { name: string, mesh: MeshPart, rays: { FixedRay }, changing: boolean, before: { number } }

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

local function sectionHisRealShape(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	local pieces, problems = findPieces()
	if #problems > 0 then
		error("nothing was changed. " .. table.concat(problems, "; "))
	end

	local changing: { Piece } = {}
	for _, piece in pieces do
		if piece.changing then
			table.insert(changing, piece)
		end
	end
	local lines: { string } = {}

	if #changing == 0 then
		local steady, seconds = waitForShapes(pieces)
		if not steady then
			error(
				string.format(
					"all six pieces are in their final shape, but their rays were still moving after %.0f seconds",
					seconds
				)
			)
		end
		return string.format(
			"already done: all six body pieces are in their final shape (PreciseConvexDecomposition, or Tunable for body_and_cushion, head_with_beard and nightcap after sections 2f and 2f2, and for legs_and_boots after section 2f5) and their rays are steady (two reads %d seconds apart, after %.1f seconds)",
			READ_EVERY,
			seconds
		)
	end

	for _, piece in pieces do
		piece.before = readRays(piece.mesh, piece.rays)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape: before")
	end)
	for _, piece in changing do
		piece.mesh.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
		table.insert(lines, `{piece.mesh:GetFullName()}: CollisionFidelity Default -> PreciseConvexDecomposition`)
	end
	local steady, seconds, moves = waitForShapes(pieces)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape: after")
	end)
	for _, piece in pieces do
		table.insert(
			lines,
			string.format(
				"%s: %d fixed rays; the largest move from before the change is %.2f studs%s",
				piece.name,
				#piece.rays,
				moves[piece.name],
				if piece.changing then "" else " (not changed now)"
			)
		)
	end
	if steady then
		table.insert(
			lines,
			string.format("Roblox worked out the shapes: the rays were steady after %.1f seconds of waiting", seconds)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shapes were not steady yet. Run the script again to wait further",
				seconds
			)
		)
	end
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2: walk pieces (stuck safety Task 24, legs and belly)
----------------------------------------------------------------------------------------------------------------------
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
local GUARD_FOLDER_NAME = "CrossingGuards"
local OLD_NAMES: { [string]: boolean } = { Boots_Walk = true, RightBoots_Walk = true, Belly_Walk = true }
local OLD_WIDTH = 10 -- every old piece is 10 x 1 x (its length)
local OLD_THICKNESS = 1
local SIZE_TOLERANCE = 0.005 -- studs: a recorded size or place closer than this is "the same"
local PLACE_TOLERANCE = 0.01
local ROTATION_TOLERANCE = 0.002 -- on each of the nine numbers of the turn

-- Each old piece as recorded: "name length x y z r00 r01 r02 r10 r11 r12 r20 r21 r22" (its length is the size's z; the
-- last twelve numbers are its place and turn, as CFrame.new takes them), sorted by name then z.
local OLD_ROWS: { string } = {
	"Belly_Walk 2.63714 -20.55339 28.80190 -51.33009 -0.83205 0.10679 -0.54432 0.00000 0.98129 0.19251 0.55470 0.16018 -0.81649",
	"Belly_Walk 2.64625 -19.55983 28.42834 -49.83974 -0.83205 0.11966 -0.54164 0.00000 0.97646 0.21572 0.55470 0.17949 -0.81246",
	"Belly_Walk 2.60734 -18.51970 28.15450 -48.27956 -0.83205 0.03941 -0.55330 0.00000 0.99747 0.07105 0.55470 0.05912 -0.82995",
	"Belly_Walk 3.05232 -17.33374 28.86391 -46.50061 -0.83205 -0.33252 -0.44399 0.00000 0.80041 -0.59946 0.55470 -0.49878 -0.66598",
	"Belly_Walk 5.26170 -15.75290 31.96929 -44.38826 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 5.26170 -14.14042 36.08291 -42.35990 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 5.26170 -12.52795 40.19652 -40.33154 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 5.26170 -10.91547 44.31013 -38.30317 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 5.26170 -9.30299 48.42375 -36.27481 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 5.26170 -7.69052 52.53736 -34.24645 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 5.26170 -6.07804 56.65098 -32.21809 -0.78279 -0.52653 -0.33167 0.00000 0.53298 -0.84613 0.62229 -0.66234 -0.41721",
	"Belly_Walk 3.44368 -4.41886 59.82449 -30.41886 -0.70711 -0.49561 -0.50435 0.00000 0.71326 -0.70090 0.70711 -0.49561 -0.50435",
	"Belly_Walk 2.95854 -3.30936 61.40738 -29.07914 -0.80000 -0.38128 -0.46328 0.00000 0.77213 -0.63547 0.60000 -0.50838 -0.61770",
	"Belly_Walk 2.95070 -2.31039 62.77148 -27.74719 -0.80000 -0.37922 -0.46496 0.00000 0.77494 -0.63203 0.60000 -0.50563 -0.61995",
	"Belly_Walk 2.86443 -1.32297 64.04406 -26.43063 -0.80000 -0.35406 -0.48440 0.00000 0.80733 -0.59011 0.60000 -0.47208 -0.64586",
	"Belly_Walk 2.54204 -1.00000 65.06923 -24.99575 -1.00000 0.00000 0.00000 0.00000 0.86106 -0.50850 0.00000 -0.50850 -0.86106",
	"Belly_Walk 2.53414 -1.00000 65.94527 -23.49910 -1.00000 0.00000 0.00000 0.00000 0.86498 -0.50180 0.00000 -0.50180 -0.86498",
	"Boots_Walk 2.80181 -24.00000 31.43743 -65.02125 -1.00000 0.00000 0.00000 0.00000 0.99910 0.04250 0.00000 0.04250 -0.99910",
	"Boots_Walk 2.81216 -24.00000 31.28702 -63.05489 -1.00000 0.00000 0.00000 0.00000 0.99396 0.10977 0.00000 0.10977 -0.99396",
	"Boots_Walk 2.82815 -24.00000 31.01215 -61.08301 -1.00000 0.00000 0.00000 0.00000 0.98612 0.16602 0.00000 0.16602 -0.98612",
	"Boots_Walk 2.89767 -24.00000 30.54381 -59.15079 -1.00000 0.00000 0.00000 0.00000 0.95344 0.30159 0.00000 0.30159 -0.95344",
	"Boots_Walk 2.49630 -23.65859 30.08246 -57.31719 -0.89443 0.06719 -0.44214 0.00000 0.98865 0.15024 0.44721 0.13437 -0.88428",
	"Boots_Walk 2.50512 -22.91541 29.80353 -55.83082 -0.89443 0.08082 -0.43985 0.00000 0.98354 0.18071 0.44721 0.16163 -0.87970",
	"Boots_Walk 2.51036 -22.16892 29.48301 -54.33783 -0.89443 0.08783 -0.43850 0.00000 0.98052 0.19640 0.44721 0.17567 -0.87701",
	"Boots_Walk 2.51036 -21.41892 29.14709 -52.83783 -0.89443 0.08783 -0.43850 0.00000 0.98052 0.19640 0.44721 0.17567 -0.87701",
	"RightBoots_Walk 2.80181 24.00000 31.41672 -65.02125 -1.00000 -0.00000 -0.00000 -0.00000 0.99910 0.04250 -0.00000 0.04250 -0.99910",
	"RightBoots_Walk 2.81216 24.00000 31.27374 -63.05489 -1.00000 -0.00000 -0.00000 -0.00000 0.99396 0.10977 -0.00000 0.10977 -0.99396",
	"RightBoots_Walk 2.82815 24.00000 31.01383 -61.08301 -1.00000 -0.00000 -0.00000 -0.00000 0.98612 0.16602 -0.00000 0.16602 -0.98612",
	"RightBoots_Walk 2.89767 24.00000 30.55252 -59.15079 -1.00000 -0.00000 -0.00000 -0.00000 0.95344 0.30159 -0.00000 0.30159 -0.95344",
	"RightBoots_Walk 2.49630 23.65859 30.01988 -57.31719 -0.89443 -0.06719 0.44214 -0.00000 0.98865 0.15024 -0.44721 0.13437 -0.88428",
	"RightBoots_Walk 2.50512 22.91541 29.75634 -55.83082 -0.89443 -0.08082 0.43985 -0.00000 0.98354 0.18071 -0.44721 0.16163 -0.87970",
	"RightBoots_Walk 2.51036 22.16892 29.45902 -54.33783 -0.89443 -0.08783 0.43850 -0.00000 0.98052 0.19640 -0.44721 0.17567 -0.87701",
	"RightBoots_Walk 2.51036 21.41892 29.14641 -52.83783 -0.89443 -0.08783 0.43850 -0.00000 0.98052 0.19640 -0.44721 0.17567 -0.87701",
}

type OldPiece = { name: string, length: number, cframe: CFrame }
local OLD_PIECES: { OldPiece } = {}
for _, row in OLD_ROWS do
	local fields = string.split(row, " ")
	local numbers: { number } = {}
	for index = 2, #fields do
		table.insert(numbers, tonumber(fields[index]) :: number)
	end
	table.insert(OLD_PIECES, {
		name = fields[1],
		length = numbers[1],
		cframe = CFrame.new(table.unpack(numbers, 2, 13)),
	})
end

-- The Part settings, copied from the old pieces (invisible, solid, found by rays, anchored) and from V1's steep guards.
-- Colors and materials are the old pieces' own; they are never seen.
local PIECE_COLOR = Color3.new(0.639216, 0.635294, 0.647059) -- Belly_Walk's
local BOOT_COLOR = Color3.new(1, 0.313726, 0.784314) -- Boots_Walk's
local GUARD_COLOR = Color3.new(0.639216, 0.635294, 0.647059) -- V1's SteepGuards'

type NewPart = {
	className: string,
	name: string,
	folder: string?,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	guard: boolean,
	slippery: boolean?, -- true: frictionless (Ruling 12), the two knee guards
}
-- Ruling 12: the long knee ramp's two guards have no friction, so a player cutting the corner to Rare egg 1 slides along
-- them instead of being held (density and elasticity are SmoothPlastic's own; friction 0 with weight 100 beats the
-- ground's friction when two surfaces meet; elasticity weight 1).
local SLIPPERY = PhysicalProperties.new(0.7, 0, 0.5, 100, 1)
-- The parts every state ends with: the step piece, the ankle ramp and its 2 guards.
local COMMON_PARTS: { NewPart } = {
	{
		className = "Part",
		name = "Boots_Walk",
		folder = nil,
		size = Vector3.new(4, 1, 2.86),
		cframe = CFrame.new(
			-23.06232,
			29.88834,
			-60.03928,
			0.99756,
			0.06463,
			-0.02643,
			-0.06983,
			0.92332,
			-0.37764,
			0,
			0.37856,
			0.92558
		),
		material = Enum.Material.SmoothPlastic,
		color = BOOT_COLOR,
		guard = false,
	},
	{
		className = "WedgePart",
		name = "CrossingRamp_Ankle",
		folder = nil,
		size = Vector3.new(5, 4.97009, 2.98633),
		cframe = CFrame.new(-21.1, 27.01, -54.2, -1, 0, 0, 0, 0.9703, -0.24192, 0, -0.24192, -0.9703),
		material = Enum.Material.Plastic,
		color = PIECE_COLOR,
		guard = false,
	},
	{
		className = "WedgePart",
		name = "Ankle_Guard_1",
		folder = GUARD_FOLDER_NAME,
		size = Vector3.new(1.4, 9.363, 1.2),
		cframe = CFrame.new(-18, 28.82844, -55.6, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		material = Enum.Material.SmoothPlastic,
		color = GUARD_COLOR,
		guard = true,
	},
	{
		className = "WedgePart",
		name = "Ankle_Guard_2",
		folder = GUARD_FOLDER_NAME,
		size = Vector3.new(1.4, 9.14, 1.2),
		cframe = CFrame.new(-24.2, 28.93986, -55.6, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		material = Enum.Material.SmoothPlastic,
		color = GUARD_COLOR,
		guard = true,
	},
}

-- The knee parts as the first run of this section left them (V1 steps replaced by the 8.8 stud ramp). Read from the live
-- world in Edit mode on 2026-10-20 (Ruling 10 replaces them by the long ramp below).
local FIRST_RUN_KNEE_PARTS: { NewPart } = {
	{
		className = "WedgePart",
		name = "CrossingRamp_Knee",
		folder = nil,
		size = Vector3.new(5, 8.8, 8.8),
		cframe = CFrame.new(-19.96617, 30.8, -45.25153, 0.85717, 0, 0.51504, 0, 1, 0, -0.51504, 0, 0.85717),
		material = Enum.Material.Plastic,
		color = PIECE_COLOR,
		guard = false,
	},
	{
		className = "WedgePart",
		name = "Knee_Guard_1",
		folder = GUARD_FOLDER_NAME,
		size = Vector3.new(2.1, 11.954, 1.2),
		cframe = CFrame.new(-20.87226, 33.71294, -40.74055, -0.51504, 0, 0.85717, 0, 1, 0, -0.85717, 0, -0.51504),
		material = Enum.Material.SmoothPlastic,
		color = GUARD_COLOR,
		guard = true,
	},
	{
		className = "WedgePart",
		name = "Knee_Guard_2",
		folder = GUARD_FOLDER_NAME,
		size = Vector3.new(2.1, 12.028, 1.2),
		cframe = CFrame.new(-15.55782, 33.67584, -43.93378, 0.51504, 0, -0.85717, 0, 1, 0, 0.85717, 0, 0.51504),
		material = Enum.Material.SmoothPlastic,
		color = GUARD_COLOR,
		guard = true,
	},
}
-- The long knee ramp (Ruling 10): one straight 45 degree wedge from his shin, over the knee wall, the shelf and the steep
-- band, to the band's top. Measured by hand on 2026-10-20: its foot is 0.12 below to 0.40 above his skin and its tip 0.04
-- below to 0.11 above (window -0.2 to 0.7), it floats at most 6.5 studs over his skin (limit 8.0), and it is 5 studs wide.
-- Its place is a centre, a turn about the vertical axis (34.7242 degrees) and a lean (13.5061 degrees), as recorded.
local LONG_RAMP_CENTRE = Vector3.new(-20.950339, 32.158617, -44.362957)
local LONG_RAMP_CFRAME = CFrame.new(LONG_RAMP_CENTRE)
	* CFrame.Angles(0, math.rad(34.7242), 0)
	* CFrame.Angles(math.rad(13.5061), 0, 0)
-- Each guard stands beside the ramp with its tall face toward it (1.2 studs deep, top a slope of 83.5 and 85.4 degrees).
local FINAL_KNEE_PARTS: { NewPart } = {
	{
		className = "WedgePart",
		name = "CrossingRamp_Knee",
		folder = nil,
		size = Vector3.new(5, 16.04426, 9.84885),
		cframe = LONG_RAMP_CFRAME,
		material = Enum.Material.Plastic,
		color = PIECE_COLOR,
		guard = false,
	},
	{
		className = "WedgePart",
		name = "Knee_Guard_1",
		folder = GUARD_FOLDER_NAME,
		size = Vector3.new(3.6, 10.497, 1.2),
		cframe = CFrame.new(-21.06816, 37.63763, -39.00312) * CFrame.Angles(0, math.rad(124.7242), 0),
		material = Enum.Material.SmoothPlastic,
		color = GUARD_COLOR,
		guard = true,
		slippery = true,
	},
	{
		className = "WedgePart",
		name = "Knee_Guard_2",
		folder = GUARD_FOLDER_NAME,
		size = Vector3.new(3.6, 14.984, 1.2),
		cframe = CFrame.new(-15.89017, 35.3941, -42.59177) * CFrame.Angles(0, math.rad(-55.2758), 0),
		material = Enum.Material.SmoothPlastic,
		color = GUARD_COLOR,
		guard = true,
		slippery = true,
	},
}

-- The final world: the common parts and the long knee ramp with its guards.
local FINAL_PARTS: { NewPart } = {}
for _, record in COMMON_PARTS do
	table.insert(FINAL_PARTS, record)
end
for _, record in FINAL_KNEE_PARTS do
	table.insert(FINAL_PARTS, record)
end

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

-- The settings every new part must have; returns what is wrong, or nil. `withFriction` says whether the slippery guards
-- must already be frictionless (false: they must still have the material's own friction, the state Ruling 12 starts from).
local function wrongSettings(part: BasePart, record: NewPart, withFriction: boolean): string?
	local wanted = {
		Transparency = 1,
		Anchored = true,
		CanCollide = true,
		CanQuery = true,
		CanTouch = not record.guard,
		CastShadow = not record.guard,
	}
	for property, value in wanted do
		if (part :: any)[property] ~= value then
			return `{property} is {(part :: any)[property]}, expected {value}`
		end
	end
	if part.CollisionGroup ~= "Default" then
		return `CollisionGroup is {part.CollisionGroup}, expected Default`
	end
	if not samePhysics(part, if record.slippery == true and withFriction then SLIPPERY else nil) then
		return `CustomPhysicalProperties are {tostring(part.CustomPhysicalProperties)}, expected {if record.slippery
					== true
				and withFriction
			then "friction 0 (weight 100)"
			else "the material's own (nil)"}`
	end
	return nil
end

-- Whether `parent` holds exactly the parts of `records` as recorded; returns what is wrong (empty when all is right).
local function partProblems(
	walk: Instance,
	guardFolder: Instance,
	records: { NewPart },
	withFriction: boolean
): { string }
	local problems: { string } = {}
	for _, record in records do
		local parent = if record.folder ~= nil then guardFolder else walk
		local candidates: { BasePart } = {}
		for _, child in parent:GetChildren() do
			if child.Name == record.name and child:IsA(record.className) then
				table.insert(candidates, child :: BasePart)
			end
		end
		if #candidates ~= 1 then
			table.insert(problems, `{record.name}: {#candidates} parts found, expected 1`)
		else
			local same, why = sameAs(candidates[1], record.size, record.cframe)
			if not same then
				table.insert(problems, `{record.name}: {why}`)
			end
			local wrong = wrongSettings(candidates[1], record, withFriction)
			if wrong ~= nil then
				table.insert(problems, `{record.name}: {wrong}`)
			end
		end
	end
	if #guardFolder:GetChildren() ~= 4 then
		table.insert(problems, `{GUARD_FOLDER_NAME} has {#guardFolder:GetChildren()} parts, expected 4`)
	end
	return problems
end

local function findPart(parent: Instance, record: NewPart): BasePart
	for _, child in parent:GetChildren() do
		if child.Name == record.name and child:IsA(record.className) then
			return child :: BasePart
		end
	end
	error(`{record.name} is missing`)
end

local function makePart(record: NewPart, parent: Instance)
	local part = Instance.new(record.className) :: BasePart
	part.Name = record.name
	part.Size = record.size
	part.CFrame = record.cframe
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = not record.guard
	part.CastShadow = not record.guard
	part.Material = record.material
	part.Color = record.color
	part.CollisionGroup = "Default"
	if record.slippery == true then
		part.CustomPhysicalProperties = SLIPPERY
	end
	part.Parent = parent
end

local function sectionWalkPieces(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	-- what stands in the folder now
	local oldFound: { BasePart } = {}
	local rampsFound: { BasePart } = {}
	for _, child in walk:GetChildren() do
		if child:IsA("BasePart") and OLD_NAMES[child.Name] then
			table.insert(oldFound, child)
		elseif child:IsA("BasePart") and child.Name:match("^CrossingRamp_") then
			table.insert(rampsFound, child)
		end
	end
	local guardFolder = walk:FindFirstChild(GUARD_FOLDER_NAME)

	-- Four states are known; anything else stops with nothing changed.
	--   (c) the final world: already done.
	--   (d) the final shape with the two knee guards still on the material's own friction (the world after an earlier
	--       run of this section): only their friction is set (Ruling 12).
	--   (b) the first run's world: the step piece, the ankle ramp and its guards are final, and the knee ramp and its two
	--       guards are the first-run ones. Those three go; the long ramp and its guards come in.
	--   (a) V1's world: all 33 old pieces, and nothing of the new work. All 33 go; the final parts come in.
	local fromFirstRun = false
	local problems: { string } = {}
	if #oldFound == 1 and #rampsFound == 2 and guardFolder ~= nil then
		local finalProblems = partProblems(walk, guardFolder, FINAL_PARTS, true)
		if #finalProblems == 0 then
			return string.format(
				"already done: the step piece, CrossingRamp_Ankle, the long CrossingRamp_Knee and the 4 guards (the 2 knee guards frictionless) are as recorded and none of the 33 old pieces is left (%d parts under World.WalkSurfaces, %d in all)",
				#walk:GetChildren(),
				#walk:GetDescendants()
			)
		end
		local firstRunRecords: { NewPart } = {}
		for _, record in COMMON_PARTS do
			table.insert(firstRunRecords, record)
		end
		for _, record in FIRST_RUN_KNEE_PARTS do
			table.insert(firstRunRecords, record)
		end
		-- (d) the final shape and settings with only the two knee guards' friction missing (Ruling 12): set only that
		if #partProblems(walk, guardFolder, FINAL_PARTS, false) == 0 then
			local lines: { string } = {}
			pcall(function()
				ChangeHistoryService:SetWaypoint("15-real-shape section 2 friction: before")
			end)
			for _, record in FINAL_PARTS do
				if record.slippery == true then
					findPart(guardFolder, record).CustomPhysicalProperties = SLIPPERY
				end
			end
			pcall(function()
				ChangeHistoryService:SetWaypoint("15-real-shape section 2 friction: after")
			end)
			table.insert(lines, "Knee_Guard_1 and Knee_Guard_2: friction 0 (was the material's)")
			table.insert(
				lines,
				string.format(
					"started from the final shape with plain knee guards; nothing else changed (%d parts under World.WalkSurfaces, %d in all)",
					#walk:GetChildren(),
					#walk:GetDescendants()
				)
			)
			return table.concat(lines, "\n")
		end
		local firstRunProblems = partProblems(walk, guardFolder, firstRunRecords, false)
		if #firstRunProblems == 0 then
			fromFirstRun = true
		else
			error(
				"nothing was changed. The new parts are neither the final ones ("
					.. table.concat(finalProblems, "; ")
					.. ") nor the first run's ("
					.. table.concat(firstRunProblems, "; ")
					.. ")"
			)
		end
	end

	-- V1's world: all 33 old pieces as recorded, and nothing of the new work.
	local matches: { BasePart } = {}
	if not fromFirstRun then
		if #rampsFound > 0 or guardFolder ~= nil then
			table.insert(
				problems,
				"a CrossingRamp_* part or the CrossingGuards folder is there, but the old pieces are too"
			)
		end
		if #oldFound ~= #OLD_PIECES then
			table.insert(problems, `{#oldFound} old pieces found, expected {#OLD_PIECES}`)
		end
		local taken: { [BasePart]: boolean } = {}
		for index, record in OLD_PIECES do
			local size = Vector3.new(OLD_WIDTH, OLD_THICKNESS, record.length)
			local found: BasePart? = nil
			for _, piece in oldFound do
				if not taken[piece] and piece.Name == record.name and piece.ClassName == "Part" then
					if sameAs(piece, size, record.cframe) then
						found = piece
						break
					end
				end
			end
			if found == nil then
				table.insert(
					problems,
					`old piece {index} ({record.name} at {describePlace(record.cframe)}) is not there as recorded`
				)
			else
				taken[found] = true
				matches[index] = found
			end
		end
		if #problems > 0 then
			error("nothing was changed. " .. table.concat(problems, "; "))
		end
	end

	-- Build the new parts away from the Workspace. From V1's world that is every final part; from the first run's world
	-- it is the long knee ramp and its 2 guards.
	local toBuild: { NewPart } = if fromFirstRun then FINAL_KNEE_PARTS else FINAL_PARTS
	local staging = Instance.new("Folder")
	staging.Name = "Task24Staging"
	staging.Archivable = false
	local stagedGuards = Instance.new("Folder")
	stagedGuards.Name = GUARD_FOLDER_NAME
	stagedGuards.Parent = staging
	for _, record in toBuild do
		makePart(record, if record.folder ~= nil then stagedGuards else staging)
	end

	local childrenBefore, descendantsBefore = #walk:GetChildren(), #walk:GetDescendants()
	local lines: { string } = {}
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2: before")
	end)
	if fromFirstRun then
		-- the first run's knee ramp and its 2 guards go (their old size and place are in the report)
		local liveGuards = guardFolder :: Instance
		for _, record in FIRST_RUN_KNEE_PARTS do
			local piece = findPart(if record.folder ~= nil then liveGuards else walk, record)
			table.insert(
				lines,
				string.format(
					"removed %s%s (first run): %.3f x %.3f x %.3f at %s",
					if record.folder ~= nil then `{record.folder}.` else "",
					record.name,
					piece.Size.X,
					piece.Size.Y,
					piece.Size.Z,
					describePlace(piece.CFrame)
				)
			)
			piece:Destroy()
		end
		for _, part in stagedGuards:GetChildren() do
			part.Parent = liveGuards
		end
		stagedGuards:Destroy()
		for _, part in staging:GetChildren() do
			part.Parent = walk
		end
	else
		for index, record in OLD_PIECES do
			local piece = matches[index]
			table.insert(
				lines,
				string.format(
					"removed %s %d: %.2f x %.2f x %.2f at %s",
					record.name,
					index,
					piece.Size.X,
					piece.Size.Y,
					piece.Size.Z,
					describePlace(piece.CFrame)
				)
			)
			piece:Destroy()
		end
		for _, part in staging:GetChildren() do
			if part ~= stagedGuards then
				part.Parent = walk
			end
		end
		stagedGuards.Parent = walk
	end
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2: after")
	end)
	for _, record in toBuild do
		table.insert(
			lines,
			string.format(
				"added %s%s: %s %.3f x %.3f x %.3f at %s",
				if record.folder ~= nil then `{record.folder}.` else "",
				record.name,
				record.className,
				record.size.X,
				record.size.Y,
				record.size.Z,
				describePlace(record.cframe)
			)
		)
	end
	local walkSurfaces = 0 -- what the test "no walk surface on the route is steeper than 60 degrees" counts
	for _, child in walk:GetChildren() do
		if child:IsA("BasePart") and (child.Name:match("_Walk$") or child.Name:match("^CrossingRamp_")) then
			walkSurfaces += 1
		end
	end
	for _, side in { "BootRamp", "RightBootRamp" } do
		local ramp = walk:FindFirstChild(side)
		if ramp ~= nil and ramp:FindFirstChild("Ramp_Walk") ~= nil then
			walkSurfaces += 1
		end
	end
	table.insert(
		lines,
		string.format(
			"started from %s; parts directly under World.WalkSurfaces: %d before, %d after; in all (with the folders' children): %d before, %d after",
			if fromFirstRun then "the first run's world" else "V1's world (33 old pieces)",
			childrenBefore,
			#walk:GetChildren(),
			descendantsBefore,
			#walk:GetDescendants()
		)
	)
	table.insert(
		lines,
		`walk surfaces on the route now (parts named *_Walk or CrossingRamp_*, plus the 2 ramp planks): {walkSurfaces} (ROUTE_SURFACE_COUNT in RealWorld.spec)`
	)
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2b: his head (stuck safety Task 25)
----------------------------------------------------------------------------------------------------------------------
-- Why: V1's nose deck (Nose_Walk) and nightcap pieces (Nightcap_Walk) stand over skin that is walkable at body size, the
-- middle of ForeheadGuard is a slab over the cap ladder's rungs, V1's two side rails leave the open nose top's sides
-- open, and both ladders end in the air next to his skin (Rule 20, One collision source; Rule 15, The climb needs no
-- jump). All numbers below are the plan's fixed final numbers (docs/plans/v2/stuck-safety.md, Task 25, Rulings 7 to 11).
-- Everything V1 has is recorded as measured in Studio Edit mode on 2026-10-20.
local HEAD_PARENTS = { WALK_FOLDER_NAME, "ForeheadGuard", "BeardLadder", "CapLadder" }
local HEAD_WALK_NAMES: { [string]: boolean } = { Nose_Walk = true, Nightcap_Walk = true }
local COLOR_TOLERANCE = 0.001
local MIDDLE_GUARD_X = 7 -- a Guard in ForeheadGuard with |x| under this is the middle slab, which goes
local CAP_LADDER_ANGLE = 71.5 -- degrees from flat
local BEARD_LADDER_ANGLE = 65.3
local RUNG_SIZE = Vector3.new(5.2, 0.45, 0.6)
local RAIL_THICKNESS = 0.45
local RAIL_SIDE = 2.4 -- each rail stands this far from the middle of the ladder

type HeadSettings = {
	className: string,
	material: Enum.Material,
	color: Color3,
	transparency: number,
	canCollide: boolean,
	canTouch: boolean,
	castShadow: boolean,
}
-- One head part: the folder or model it stands in (WalkSurfaces, ForeheadGuard, BeardLadder or CapLadder), its name, size
-- and place. `shape` (a Part's Shape) is checked only when it is given: the side rails say Block, and the wedge rails of
-- section 2d say Wedge.
type HeadPart = { parent: string, name: string, size: Vector3, cframe: CFrame, shape: Enum.PartType? }

-- The settings of V1's head parts (all anchored, in the collision group Default, found by rays, with the material's own
-- friction). The new parts are copies of V1's, so they have the same.
local GREY = Color3.new(0.639216, 0.635294, 0.647059)
local WOOD = Color3.new(0.768627, 0.54902, 0.360784)
local FABRIC = Color3.new(0.941176, 0.870588, 0.705882)
local function hiddenSettings(
	className: string,
	material: Enum.Material,
	canTouch: boolean,
	castShadow: boolean
): HeadSettings
	return {
		className = className,
		material = material,
		color = GREY,
		transparency = 1,
		canCollide = true,
		canTouch = canTouch,
		castShadow = castShadow,
	}
end
local function shownSettings(material: Enum.Material, color: Color3): HeadSettings
	return {
		className = "Part",
		material = material,
		color = color,
		transparency = 0,
		canCollide = false,
		canTouch = true,
		castShadow = true,
	}
end
local HEAD_SETTINGS: { [string]: HeadSettings } = {
	Nose_Walk = hiddenSettings("Part", Enum.Material.Plastic, true, true),
	Nightcap_Walk = hiddenSettings("Part", Enum.Material.Plastic, true, true),
	Guard = hiddenSettings("Part", Enum.Material.Plastic, true, true),
	SideRail = hiddenSettings("Part", Enum.Material.SmoothPlastic, false, false),
	LadderSlotBlock = hiddenSettings("Part", Enum.Material.SmoothPlastic, false, false), -- section 2d; same as SideRail
	Rung = shownSettings(Enum.Material.Wood, WOOD),
	Rail = shownSettings(Enum.Material.Fabric, FABRIC),
	Climb = hiddenSettings("TrussPart", Enum.Material.Plastic, true, true),
}

-- V1's head: "parent name sizeX sizeY sizeZ" and then the place and turn as CFrame.new takes them (x y z and the nine
-- turn numbers). Each ladder's rungs are one row (rung 0) and a step: the other rungs are 1.80 apart along the ladder.
local V1_HEAD_ROWS: { string } = {
	"WalkSurfaces Nose_Walk 12.00000 1.00000 12.60000 0.00000 99.74000 -4.30000 1.00000 0.00000 0.00000 0.00000 1.00000 0.00000 0.00000 0.00000 1.00000",
	"WalkSurfaces Nightcap_Walk 10.00000 1.00000 7.10498 2.95796 119.61134 12.49299 -0.16440 0.08408 -0.98280 0.00000 0.99636 0.08524 0.98639 0.01401 -0.16380",
	"WalkSurfaces Nightcap_Walk 10.00000 1.00000 7.26858 8.88081 118.60664 13.48013 -0.16440 0.23839 -0.95715 0.00000 0.97036 0.24168 0.98639 0.03973 -0.15953",
	"WalkSurfaces Nightcap_Walk 10.00000 1.00000 7.63302 14.85703 116.85796 14.95234 -0.31623 0.28594 -0.90457 0.00000 0.95350 0.30141 0.94868 0.09531 -0.30152",
	"ForeheadGuard Guard 13.50000 0.60000 20.28004 -24.00000 110.04790 5.39791 1.00000 0.00000 0.00000 0.00000 0.17365 0.98481 0.00000 -0.98481 0.17365",
	"ForeheadGuard Guard 12.00000 0.60000 20.49319 -12.75000 110.04790 1.16765 1.00000 0.00000 0.00000 0.00000 0.17365 0.98481 0.00000 -0.98481 0.17365",
	"ForeheadGuard Guard 13.50000 0.60000 21.26537 0.00000 110.10000 1.08687 -1.00000 0.00000 0.00000 0.00000 0.36479 -0.93109 0.00000 -0.93109 -0.36479",
	"ForeheadGuard Guard 12.00000 0.60000 20.49705 12.75000 110.04790 1.50328 1.00000 0.00000 0.00000 0.00000 0.17365 0.98481 0.00000 -0.98481 0.17365",
	"ForeheadGuard Guard 13.50000 0.60000 20.28390 24.00000 110.04790 5.77406 1.00000 0.00000 0.00000 0.00000 0.17365 0.98481 0.00000 -0.98481 0.17365",
	"ForeheadGuard SideRail 21.86000 1.00000 16.60000 -6.50000 110.57000 -2.30000 0.00000 -1.00000 0.00000 1.00000 0.00000 0.00000 0.00000 0.00000 1.00000",
	"ForeheadGuard SideRail 21.86000 1.00000 16.60000 6.50000 110.57000 -2.30000 0.00000 1.00000 0.00000 1.00000 0.00000 0.00000 0.00000 0.00000 -1.00000",
	"BeardLadder Rung 5.20000 0.45000 0.60000 0.00000 67.22169 -24.53335 -1.00000 0.00000 0.00000 0.00000 0.39176 -0.92007 0.00000 -0.92007 -0.39176",
	"BeardLadder Rail 36.20596 0.45000 0.45000 -2.40000 83.49591 -17.60381 0.00000 0.00000 -1.00000 0.92007 0.39176 0.00000 0.39176 -0.92007 0.00000",
	"BeardLadder Rail 36.20596 0.45000 0.45000 2.40000 83.49591 -17.60381 0.00000 0.00000 -1.00000 0.92007 0.39176 0.00000 0.39176 -0.92007 0.00000",
	"BeardLadder Climb 2.00000 2.00000 34.00000 0.00000 82.94113 -17.84003 -1.00000 0.00000 0.00000 0.00000 0.39176 -0.92007 0.00000 -0.92007 -0.39176",
	"CapLadder Rung 5.20000 0.45000 0.60000 0.00000 100.39385 -3.25597 -1.00000 0.00000 0.00000 0.00000 0.59132 -0.80644 0.00000 -0.80644 -0.59132",
	"CapLadder Rail 26.36713 0.45000 0.45000 -2.40000 110.97147 4.50000 0.00000 0.00000 -1.00000 0.80644 0.59132 0.00000 0.59132 -0.80644 0.00000",
	"CapLadder Rail 26.36713 0.45000 0.45000 2.40000 110.97147 4.50000 0.00000 0.00000 -1.00000 0.80644 0.59132 0.00000 0.59132 -0.80644 0.00000",
	"CapLadder Climb 2.00000 2.00000 26.00000 0.00000 110.97147 4.50000 -1.00000 0.00000 0.00000 0.00000 0.59132 -0.80644 0.00000 -0.80644 -0.59132",
}
-- V1's rungs: how many each ladder has, and where each is after the one below it.
local V1_RUNGS: { [string]: { count: number, step: Vector3 } } = {
	BeardLadder = { count = 20, step = Vector3.new(0, 1.65612, 0.70517) },
	CapLadder = { count = 15, step = Vector3.new(0, 1.45159, 1.06437) },
}

local function parseHeadRows(rows: { string }): { HeadPart }
	local parts: { HeadPart } = {}
	for _, row in rows do
		local fields = string.split(row, " ")
		local numbers: { number } = {}
		for index = 3, #fields do
			table.insert(numbers, tonumber(fields[index]) :: number)
		end
		local size = Vector3.new(numbers[1], numbers[2], numbers[3])
		local cframe = CFrame.new(table.unpack(numbers, 4, 15))
		local rungs = V1_RUNGS[fields[1]]
		if fields[2] == "Rung" and rungs ~= nil then
			for rung = 0, rungs.count - 1 do
				table.insert(parts, {
					parent = fields[1],
					name = "Rung",
					size = size,
					cframe = cframe + rungs.step * rung,
				})
			end
		else
			table.insert(parts, { parent = fields[1], name = fields[2], size = size, cframe = cframe })
		end
	end
	return parts
end
local V1_HEAD_PARTS: { HeadPart } = parseHeadRows(V1_HEAD_ROWS)

-- The turn of V1's rungs and trusses (`lengthAlong` false: their long side across the ladder) and rails (`lengthAlong`
-- true: their length along the ladder) for a ladder `angle` degrees from flat, tipping towards his face as it rises.
local function ladderCFrame(centre: Vector3, angle: number, lengthAlong: boolean): CFrame
	local rise = math.sin(math.rad(angle))
	local run = math.cos(math.rad(angle))
	local front = Vector3.new(0, run, -rise) -- square to the ladder, up and away from his face
	if lengthAlong then
		return CFrame.fromMatrix(centre, Vector3.new(0, rise, run), front, Vector3.new(-1, 0, 0))
	end
	return CFrame.fromMatrix(centre, Vector3.new(-1, 0, 0), front, Vector3.new(0, -rise, -run))
end

type LadderNumbers = {
	parent: string,
	angle: number,
	rungs: { { number } }, -- the middle of each rung: y, z (x is 0)
	trussLength: number,
	trussY: number,
	trussZ: number,
	railLength: number,
	railY: number,
	railZ: number,
}

-- The cap ladder, shape B (the designer's pick): 71.5 degrees, 10 rungs, its foot on the bridge of his nose and its top
-- on the brim's top edge. Truss 2 x 2 x 16, rails 16.6 long.
local CAP_LADDER: LadderNumbers = {
	parent = "CapLadder",
	angle = CAP_LADDER_ANGLE,
	rungs = {
		{ 93.800, -4.310 },
		{ 95.507, -3.739 },
		{ 97.214, -3.168 },
		{ 98.921, -2.597 },
		{ 100.628, -2.025 },
		{ 102.335, -1.454 },
		{ 104.042, -0.883 },
		{ 105.749, -0.312 },
		{ 107.456, 0.259 },
		{ 109.163, 0.830 },
	},
	trussLength = 16,
	trussY = 101.481,
	trussZ = -1.740,
	railLength = 16.6,
	railY = 101.387,
	railZ = -1.772,
}
-- The beard ladder at 65.3 degrees (turned about its truss foot, which stays at (0, 67.299, -24.501)): V1's rungs 0 to
-- 15 (the top 4 go), truss 2 x 2 x 28, rails 28.7 long.
local BEARD_LADDER: LadderNumbers = {
	parent = "BeardLadder",
	angle = BEARD_LADDER_ANGLE,
	rungs = {
		{ 67.223, -24.536 },
		{ 68.858, -23.784 },
		{ 70.494, -23.032 },
		{ 72.129, -22.280 },
		{ 73.764, -21.527 },
		{ 75.400, -20.775 },
		{ 77.035, -20.023 },
		{ 78.670, -19.271 },
		{ 80.306, -18.519 },
		{ 81.941, -17.767 },
		{ 83.576, -17.014 },
		{ 85.211, -16.262 },
		{ 86.847, -15.510 },
		{ 88.482, -14.758 },
		{ 90.117, -14.006 },
		{ 91.753, -13.254 },
	},
	trussLength = 28,
	trussY = 80.018,
	trussZ = -18.651,
	railLength = 28.7,
	railY = 79.882,
	railZ = -18.714,
}

local function ladderParts(ladder: LadderNumbers): { HeadPart }
	local parts: { HeadPart } = {}
	for _, rung in ladder.rungs do
		table.insert(parts, {
			parent = ladder.parent,
			name = "Rung",
			size = RUNG_SIZE,
			cframe = ladderCFrame(Vector3.new(0, rung[1], rung[2]), ladder.angle, false),
		})
	end
	for _, side in { -RAIL_SIDE, RAIL_SIDE } do
		table.insert(parts, {
			parent = ladder.parent,
			name = "Rail",
			size = Vector3.new(ladder.railLength, RAIL_THICKNESS, RAIL_THICKNESS),
			cframe = ladderCFrame(Vector3.new(side, ladder.railY, ladder.railZ), ladder.angle, true),
		})
	end
	table.insert(parts, {
		parent = ladder.parent,
		name = "Climb",
		size = Vector3.new(2, 2, ladder.trussLength),
		cframe = ladderCFrame(Vector3.new(0, ladder.trussY, ladder.trussZ), ladder.angle, false),
	})
	return parts
end

-- The 4 new side rails, 2 per side (invisible; they close the open nose top's sides, down into his skin, and run on
-- beside the cap ladder). Part A: on the nose, turned about the vertical to follow the walkable edge, y 79.5 to 107.0.
-- Part B: beside the cap ladder, no turn, y 87.5 to 121.5. A and B overlap 0.7 (right) and 0.8 (left) studs in z.
type SideRailNumbers = { size: Vector3, centre: Vector3, yaw: number }
local NEW_SIDE_RAILS: { SideRailNumbers } = {
	{ size = Vector3.new(1.5, 27.5, 6.7161), centre = Vector3.new(4.7409, 93.25, -9.9387), yaw = 14.574 },
	{ size = Vector3.new(1.5, 27.5, 6.7244), centre = Vector3.new(-4.8637, 93.25, -9.9421), yaw = -14.842 },
	{ size = Vector3.new(2, 34, 13.4), centre = Vector3.new(4.6, 104.5, -0.7), yaw = 0 },
	{ size = Vector3.new(2, 34, 13.4), centre = Vector3.new(-4.6, 104.5, -0.7), yaw = 0 },
}

-- Everything the final head adds: the 4 side rails and the two re-made ladders (the beard ladder is re-made at 65.3
-- degrees from its truss foot, its top 4 rungs gone).
local function newHeadParts(): { HeadPart }
	local parts: { HeadPart } = {}
	for _, rail in NEW_SIDE_RAILS do
		table.insert(parts, {
			parent = "ForeheadGuard",
			name = "SideRail",
			size = rail.size,
			cframe = CFrame.new(rail.centre) * CFrame.Angles(0, math.rad(rail.yaw), 0),
			shape = Enum.PartType.Block,
		})
	end
	for _, part in ladderParts(CAP_LADDER) do
		table.insert(parts, part)
	end
	for _, part in ladderParts(BEARD_LADDER) do
		table.insert(parts, part)
	end
	return parts
end
local NEW_HEAD_PARTS: { HeadPart } = newHeadParts()

-- The final head: V1's 4 side Guards stay (the middle slab goes), and everything above is new.
local FINAL_HEAD_PARTS: { HeadPart } = {}
for _, part in V1_HEAD_PARTS do
	if part.name == "Guard" and math.abs(part.cframe.X) >= MIDDLE_GUARD_X then
		table.insert(FINAL_HEAD_PARTS, part)
	end
end
for _, part in NEW_HEAD_PARTS do
	table.insert(FINAL_HEAD_PARTS, part)
end

-- The numbers of section 2d (stuck safety Task 25, Rulings 12 and 13, confirmed by step 5c-1). They stand here, before
-- section 2b's code, because 2b's check of its final head accepts the world after 2d too.
--   * Part A (the rail beside the nose, front of z -5) becomes a wedge: same centre and volume, the Size axes swapped
--     (x and z), turned a quarter turn about the upright axis (right side -90 degrees, left side +90) on top of its old
--     turn, so the upright face is the inner one and the outer side is one slope of about 87 degrees (no top to stand on).
--   * One LadderSlotBlock per side in ForeheadGuard, in the slot between the cap truss and part B (no turn).
local PART_A_BEHIND_Z = -5 -- a SideRail centred in front of this z is part A, behind it part B
local WEDGE_SIZE_RIGHT = Vector3.new(6.7161, 27.5, 1.5)
local WEDGE_SIZE_LEFT = Vector3.new(6.7244, 27.5, 1.5)
local SLOT_BLOCK_NAME = "LadderSlotBlock"
local SLOT_BLOCK_SIZE = Vector3.new(1.0, 12.0, 4.0)
local SLOT_BLOCK_CENTRES = { Vector3.new(3.2, 102.5, 1.0), Vector3.new(-3.2, 102.5, 1.0) }

-- Part A, before and after section 2d, side by side: [1] is the box record (as in FINAL_HEAD_PARTS), [2] the wedge.
local PART_A_BEFORE_AFTER: { { HeadPart } } = {}
-- The final head after section 2d: the wedge instead of each part A box, and the 2 slot blocks.
local FINAL_HEAD_PARTS_2D: { HeadPart } = {}
for _, part in FINAL_HEAD_PARTS do
	if part.name == "SideRail" and part.cframe.Z < PART_A_BEHIND_Z then
		local right = part.cframe.X > 0
		local wedge: HeadPart = {
			parent = part.parent,
			name = part.name,
			size = if right then WEDGE_SIZE_RIGHT else WEDGE_SIZE_LEFT,
			cframe = part.cframe * CFrame.Angles(0, math.rad(if right then -90 else 90), 0),
			shape = Enum.PartType.Wedge,
		}
		table.insert(PART_A_BEFORE_AFTER, { part, wedge })
		table.insert(FINAL_HEAD_PARTS_2D, wedge)
	else
		table.insert(FINAL_HEAD_PARTS_2D, part)
	end
end
local SLOT_BLOCK_PARTS: { HeadPart } = {}
for _, centre in SLOT_BLOCK_CENTRES do
	table.insert(SLOT_BLOCK_PARTS, {
		parent = "ForeheadGuard",
		name = SLOT_BLOCK_NAME,
		size = SLOT_BLOCK_SIZE,
		cframe = CFrame.new(centre),
		shape = Enum.PartType.Block,
	})
end
for _, part in SLOT_BLOCK_PARTS do
	table.insert(FINAL_HEAD_PARTS_2D, part)
end

-- The numbers of section 2e (stuck safety Task 25, step 6b-1 ruling; measured in step 6b-1a): the beard ladder's 2 rails
-- reach down to his belly, so they grow at their bottom end only (3.15 studs: 28.70 -> 31.85 long, the centre moves 1.575
-- down the ladder, the top end stays within 0.05), and one more rung, a copy of the lowest rung moved 1.80 down the
-- ladder, goes in. The truss, the foot point and the 16 rungs stay. Sections 2b and 2d accept this head as final too.
local BEARD_RAIL_LONG_LENGTH = 31.85
local BEARD_RAIL_LONG_Y = 78.4511
local BEARD_RAIL_LONG_Z = -19.3721
local BEARD_EXTRA_RUNG_CENTRE = Vector3.new(0, 65.5877, -25.2882)
local BEARD_TOP_SLACK = 0.05 -- how far a rail's top end may move

-- Each beard rail, before and after section 2e, side by side: [1] is the 28.70 record (as in FINAL_HEAD_PARTS_2D), [2] the
-- longer one. The head after section 2e: the longer rails and the extra rung.
local BEARD_RAIL_BEFORE_AFTER: { { HeadPart } } = {}
local FINAL_HEAD_PARTS_2E: { HeadPart } = {}
local beardLowestRung: HeadPart? = nil
for _, part in FINAL_HEAD_PARTS_2D do
	if part.parent == "BeardLadder" and part.name == "Rail" then
		local longer: HeadPart = {
			parent = part.parent,
			name = part.name,
			size = Vector3.new(BEARD_RAIL_LONG_LENGTH, RAIL_THICKNESS, RAIL_THICKNESS),
			cframe = ladderCFrame(
				Vector3.new(part.cframe.X, BEARD_RAIL_LONG_Y, BEARD_RAIL_LONG_Z),
				BEARD_LADDER_ANGLE,
				true
			),
		}
		table.insert(BEARD_RAIL_BEFORE_AFTER, { part, longer })
		table.insert(FINAL_HEAD_PARTS_2E, longer)
	else
		table.insert(FINAL_HEAD_PARTS_2E, part)
		if
			part.parent == "BeardLadder"
			and part.name == "Rung"
			and (beardLowestRung == nil or part.cframe.Y < beardLowestRung.cframe.Y)
		then
			beardLowestRung = part
		end
	end
end
if beardLowestRung == nil then
	error("the recorded beard ladder has no rung")
end
local BEARD_LOWEST_RUNG: HeadPart = beardLowestRung
local BEARD_EXTRA_RUNG: HeadPart = {
	parent = "BeardLadder",
	name = "Rung",
	size = RUNG_SIZE,
	cframe = ladderCFrame(BEARD_EXTRA_RUNG_CENTRE, BEARD_LADDER_ANGLE, false),
}
table.insert(FINAL_HEAD_PARTS_2E, BEARD_EXTRA_RUNG)

-- The numbers of section 2f (stuck safety Task 26; code_lead's ruling after step 6b-1f, designer's yes): the beard ladder's
-- climbing truss `Climb` grows 2.0 studs at its BOTTOM end only, on the same line (28 -> 30 long, the centre moves 1.0
-- down the ladder, the top end stays). It is invisible, so the look does not change. Why: once his belly is Tunable a
-- standing player's head is 0.28 studs under the truss's lowest corner, and the climb from his belly would fail.
-- Sections 2b, 2d and 2e accept this head as final too.
local BEARD_TRUSS_EXTRA = 2.0
local BEARD_TRUSS_TOP_SLACK = 0.05 -- how far the truss's top end may move
local BEARD_TRUSS_BEFORE_AFTER: { { HeadPart } } = {} -- [1] is the 28 record (as in FINAL_HEAD_PARTS_2E), [2] the 30 one
local FINAL_HEAD_PARTS_2F: { HeadPart } = {}
for _, part in FINAL_HEAD_PARTS_2E do
	if part.parent == "BeardLadder" and part.name == "Climb" then
		local longer: HeadPart = {
			parent = part.parent,
			name = part.name,
			-- A truss's long side is its local z, which points down the ladder: the centre moves BEARD_TRUSS_EXTRA / 2 that way.
			size = part.size + Vector3.new(0, 0, BEARD_TRUSS_EXTRA),
			cframe = part.cframe * CFrame.new(0, 0, BEARD_TRUSS_EXTRA / 2),
		}
		table.insert(BEARD_TRUSS_BEFORE_AFTER, { part, longer })
		table.insert(FINAL_HEAD_PARTS_2F, longer)
	else
		table.insert(FINAL_HEAD_PARTS_2F, part)
	end
end
if #BEARD_TRUSS_BEFORE_AFTER ~= 1 then
	error("the recorded beard ladder must have exactly one Climb truss")
end

-- Section 2f3 (Task 26, step 26-4d2, Ruling 7): each LadderSlotBlock grows forward and down, so it fills the thin band of
-- forehead his closer-fitting head leaves in front of it. The back end (z 3.0), the top (y 108.5), the inner face (|x| 2.7)
-- and the outer face (|x| 3.7) stay. The head with these wider blocks is FINAL_HEAD_PARTS_2G; the sections before 2f3
-- accept it as final too.
local SLOT_WIDE_SIZE = Vector3.new(1.0, 17.0, 6.0)
local SLOT_WIDE_CENTRES = { Vector3.new(3.2, 100.0, 0.0), Vector3.new(-3.2, 100.0, 0.0) }
local SLOT_BLOCK_BEFORE_AFTER: { { HeadPart } } = {} -- each is { the (1, 12, 4) record, the (1, 17, 6) record }
local FINAL_HEAD_PARTS_2G: { HeadPart } = {}
for _, part in FINAL_HEAD_PARTS_2F do
	if part.name == SLOT_BLOCK_NAME then
		local wide: HeadPart = {
			parent = part.parent,
			name = part.name,
			size = SLOT_WIDE_SIZE,
			cframe = CFrame.new(if part.cframe.X > 0 then SLOT_WIDE_CENTRES[1] else SLOT_WIDE_CENTRES[2]),
			shape = part.shape,
		}
		table.insert(SLOT_BLOCK_BEFORE_AFTER, { part, wide })
		table.insert(FINAL_HEAD_PARTS_2G, wide)
	else
		table.insert(FINAL_HEAD_PARTS_2G, part)
	end
end
if #SLOT_BLOCK_BEFORE_AFTER ~= 2 then
	error("the recorded head must have exactly two LadderSlotBlocks")
end

-- Section 2f4 (Task 26, step 26-4d4, Ruling 8): two invisible changes, so the walk check joins the ladders' ends again
-- after the closer fit.
--   * The beard ladder's climbing truss `Climb` grows from 30 to 32 at its BOTTOM end only, the same way as section 2f
--     (the centre moves 1.0 down the ladder, the top end stays within 0.05). Its foot goes from about (0, 65.48, -25.34)
--     to about (0, 63.66, -26.17). His belly under the ladder is 0.36 lower after the closer fit, so the walk check no
--     longer joined it to the ladder's foot.
--   * Both part B SideRails (beside the cap ladder, centred behind z -5) end at z 2.5 instead of 6.0; the front end
--     (z -7.4) stays. Size z 13.4 -> 9.9, centre z -0.70 -> -2.45. Allowed back end: 2.1 to 3.0, which keeps it at least
--     1 stud past the cap ladder rails' top end (Task 25's allowance). Why: part B walled the cap ladder's top into a
--     lane two grid columns wide, and the walk check could not join it to the brim nests.
-- The head with both changes is FINAL_HEAD_PARTS_2H; the sections before 2f4 accept it as final too.
local TRUSS_LONGER_EXTRA = 2.0 -- studs more at the bottom end: 30 -> 32
local TRUSS_LONGER_TOP_SLACK = 0.05 -- how far the truss's top end may move
local PART_B_BACK_BEFORE = 6.0
local PART_B_BACK_AFTER = 2.5
local PART_B_BACK_MIN = 2.1
local PART_B_BACK_MAX = 3.0
local HEAD_CHANGES_2F4: { { HeadPart } } = {} -- each is { the record before (as in 2G), the record after }
local FINAL_HEAD_PARTS_2H: { HeadPart } = {}
for _, part in FINAL_HEAD_PARTS_2G do
	if part.parent == "BeardLadder" and part.name == "Climb" then
		local longer: HeadPart = {
			parent = part.parent,
			name = part.name,
			-- The truss's long side is its local z, which points down the ladder: the centre moves that way by half.
			size = part.size + Vector3.new(0, 0, TRUSS_LONGER_EXTRA),
			cframe = part.cframe * CFrame.new(0, 0, TRUSS_LONGER_EXTRA / 2),
		}
		table.insert(HEAD_CHANGES_2F4, { part, longer })
		table.insert(FINAL_HEAD_PARTS_2H, longer)
	elseif part.parent == "ForeheadGuard" and part.name == "SideRail" and part.cframe.Z >= PART_A_BEHIND_Z then
		-- Part B has no turn, so its local z is the world z. The front end stays: the centre moves half the cut forward.
		local backEnd = part.cframe.Z + part.size.Z / 2
		if math.abs(backEnd - PART_B_BACK_BEFORE) > 0.01 then
			error(`the recorded part B must end at z {PART_B_BACK_BEFORE}, not {backEnd}`)
		end
		local cut = backEnd - PART_B_BACK_AFTER
		local shorter: HeadPart = {
			parent = part.parent,
			name = part.name,
			size = part.size - Vector3.new(0, 0, cut),
			cframe = part.cframe * CFrame.new(0, 0, -cut / 2),
			shape = part.shape,
		}
		table.insert(HEAD_CHANGES_2F4, { part, shorter })
		table.insert(FINAL_HEAD_PARTS_2H, shorter)
	else
		table.insert(FINAL_HEAD_PARTS_2H, part)
	end
end
if #HEAD_CHANGES_2F4 ~= 3 then
	error("the recorded head must have exactly one Climb truss and two part B SideRails")
end

-- Section 2f6 (Task 26, step 26-6a1b, Ruling 12): the beard truss's foot end swings back toward his beard.
--   * Why: the truss is 2 studs thick and its centre line runs along the visible rails, so its front face stood 1 stud out
--     from the rungs. Its front-bottom edge was 1.05 studs in front of the rails' foot, and a walker crossing in front of
--     the ladder's foot was lifted off his cloth. The climb must start only where a player visibly touches the ladder.
--   * What: the top end stays within 0.05; the foot end moves TRUSS_SWING studs toward his beard, along the truss's own
--     "back" direction (minus its UpVector), and the truss turns about its top end by about 1.8 degrees. It stays
--     2 x 2 x 32. Nothing visible changes. Allowed swing: 0.85 to 1.0 (code_lead measured on 2026-10-21: at 0.75 a walker
--     crossing at z -27 was still lifted; the front-bottom edge must be no more than 0.3 south of the rails' foot).
--   * Chosen on a copy of the world (a WorldModel in ServerStorage) with the real walk check: 1.0 passes the ladder-join
--     check, the bite check, the ladder-end check and the belly-top climb check (overlap 3.30, limit 1.0).
-- The head with this change is FINAL_HEAD_PARTS_2I; the sections before 2f6 accept it as final too.
local TRUSS_SWING = 1.0 -- studs the foot end moves toward his beard
local TRUSS_SWING_MIN = 0.85
local TRUSS_SWING_MAX = 1.0
local TRUSS_SWING_SLACK = 0.01 -- rounding in the written numbers
local TRUSS_SWING_TOP_SLACK = 0.05 -- how far the truss's top end may move

-- The truss's place after its foot end swings back by `swing` studs: the top end stays, the length stays.
local function swungTrussCFrame(size: Vector3, cframe: CFrame, swing: number): CFrame
	local top = cframe:PointToWorldSpace(Vector3.new(0, 0, -size.Z / 2))
	local foot = cframe:PointToWorldSpace(Vector3.new(0, 0, size.Z / 2))
	local down = (foot - top).Unit
	-- the truss's UpVector faces away from his beard, so the foot goes the other way
	local newDown = ((foot - cframe.UpVector * swing) - top).Unit
	local turn = CFrame.fromAxisAngle(down:Cross(newDown).Unit, math.acos(math.clamp(down:Dot(newDown), -1, 1)))
	local newFoot = top + newDown * size.Z
	return CFrame.new((top + newFoot) / 2) * (turn * cframe.Rotation)
end

local HEAD_CHANGES_2F6: { { HeadPart } } = {} -- each is { the record before (as in 2H), the record after }
local FINAL_HEAD_PARTS_2I: { HeadPart } = {}
for _, part in FINAL_HEAD_PARTS_2H do
	if part.parent == "BeardLadder" and part.name == "Climb" then
		local swung: HeadPart = {
			parent = part.parent,
			name = part.name,
			size = part.size,
			cframe = swungTrussCFrame(part.size, part.cframe, TRUSS_SWING),
		}
		table.insert(HEAD_CHANGES_2F6, { part, swung })
		table.insert(FINAL_HEAD_PARTS_2I, swung)
	else
		table.insert(FINAL_HEAD_PARTS_2I, part)
	end
end
if #HEAD_CHANGES_2F6 ~= 1 then
	error("the recorded head must have exactly one Climb truss")
end

-- Section 2g (Task 25, after the Task 26 ruling; measured in Task 25's resumed step 1 on his drawn skin, DrawnSkin):
--   * Why: the beard rails' lowest corners are still 2.4 to 2.7 studs over his drawn belly. Each rail grows BELLY_RAIL_EXTRA
--     studs at its bottom end only (31.85 -> 34.60 long, the centre moves half of that down the same line, the top end stays
--     within 0.05, the turn stays), so its lowest corner lies between 0.3 into the skin and 0.2 above it (0.16 above on
--     one rail, 0.02 into it on the other), and the deepest sink along the added length is 0.171 and 0.024.
--   * One more rung, a copy of today's lowest rung (section 2e's extra rung), goes BELLY_RUNG_STEP studs further down the
--     ladder: 1.64 studs from the drawn skin and touching none of his six pieces. A second extra rung would sink in.
--   * The head with this change is FINAL_HEAD_PARTS_2J; the sections before 2g accept it as final too.
local BELLY_RAIL_EXTRA = 2.75 -- studs more at each rail's bottom end
local BELLY_RAIL_EXTRA_SLACK = 0.01
local BELLY_RAIL_LENGTH = 34.60
local BELLY_RAIL_Y = 77.2019
local BELLY_RAIL_Z = -19.9467
local BELLY_RUNG_CENTRE = Vector3.new(0, 63.952, -26.040)
local BELLY_RUNG_STEP = 1.80 -- studs between two rungs along the ladder
local BELLY_RUNG_STEP_SLACK = 0.01
local BELLY_TURN_SLACK = 0.00001 -- on the dot product of a rail's axes before and after: it must not turn
local BELLY_TOP_SLACK = 0.05 -- how far a rail's top end may move

local BEARD_RAIL_BELLY_BEFORE_AFTER: { { HeadPart } } = {} -- each is { the 31.85 rail (as in 2I), the 34.60 one }
local FINAL_HEAD_PARTS_2J: { HeadPart } = {}
local beardLowRung: HeadPart? = nil -- today's lowest rung: the lowest Rung of the head after 2f6
for _, part in FINAL_HEAD_PARTS_2I do
	if part.parent == "BeardLadder" and part.name == "Rung" then
		if beardLowRung == nil or part.cframe.Y < beardLowRung.cframe.Y then
			beardLowRung = part
		end
	end
end
for _, part in FINAL_HEAD_PARTS_2I do
	if part.parent == "BeardLadder" and part.name == "Rail" then
		local longer: HeadPart = {
			parent = part.parent,
			name = part.name,
			size = Vector3.new(BELLY_RAIL_LENGTH, RAIL_THICKNESS, RAIL_THICKNESS),
			cframe = ladderCFrame(Vector3.new(part.cframe.X, BELLY_RAIL_Y, BELLY_RAIL_Z), BEARD_LADDER_ANGLE, true),
		}
		table.insert(BEARD_RAIL_BELLY_BEFORE_AFTER, { part, longer })
		table.insert(FINAL_HEAD_PARTS_2J, longer)
	else
		table.insert(FINAL_HEAD_PARTS_2J, part)
	end
end
if #BEARD_RAIL_BELLY_BEFORE_AFTER ~= 2 or beardLowRung == nil then
	error("the recorded head must have exactly two beard Rails and at least one beard Rung")
end
local BEARD_LOW_RUNG: HeadPart = beardLowRung -- today's lowest rung (section 2e's extra rung)
local BEARD_BELLY_RUNG: HeadPart = {
	parent = "BeardLadder",
	name = "Rung",
	size = BEARD_LOW_RUNG.size,
	cframe = ladderCFrame(BELLY_RUNG_CENTRE, BEARD_LADDER_ANGLE, false),
}
table.insert(FINAL_HEAD_PARTS_2J, BEARD_BELLY_RUNG)

-- What is wrong with a head part's settings, or nil.
local function headSettingsProblem(part: BasePart, settings: HeadSettings): string?
	if part.ClassName ~= settings.className then
		return `is a {part.ClassName}, expected a {settings.className}`
	end
	if part.Material ~= settings.material then
		return `Material is {part.Material.Name}, expected {settings.material.Name}`
	end
	if
		math.abs(part.Color.R - settings.color.R) > COLOR_TOLERANCE
		or math.abs(part.Color.G - settings.color.G) > COLOR_TOLERANCE
		or math.abs(part.Color.B - settings.color.B) > COLOR_TOLERANCE
	then
		return "Color differs from the recorded color"
	end
	local wanted = {
		Transparency = settings.transparency,
		Anchored = true,
		CanCollide = settings.canCollide,
		CanQuery = true,
		CanTouch = settings.canTouch,
		CastShadow = settings.castShadow,
	}
	for property, value in wanted do
		if (part :: any)[property] ~= value then
			return `{property} is {(part :: any)[property]}, expected {value}`
		end
	end
	if part.CollisionGroup ~= "Default" then
		return `CollisionGroup is {part.CollisionGroup}, expected Default`
	end
	if samePhysics(part, nil) == false then
		return "CustomPhysicalProperties are set, expected the material's own (nil)"
	end
	return nil
end

-- Whether his head holds exactly the `records` as recorded (size, place, turn and settings); returns what is wrong
-- (empty when all is right). Each of WalkSurfaces (only its Nose_Walk and Nightcap_Walk), ForeheadGuard, BeardLadder and
-- CapLadder must hold exactly the recorded number of parts.
local function headProblems(walk: Instance, records: { HeadPart }): { string }
	local problems: { string } = {}
	for _, parentName in HEAD_PARENTS do
		local box = if parentName == WALK_FOLDER_NAME then walk else walk:FindFirstChild(parentName)
		if box == nil then
			table.insert(problems, `{parentName} is missing`)
			continue
		end
		local wanted: { HeadPart } = {}
		for _, record in records do
			if record.parent == parentName then
				table.insert(wanted, record)
			end
		end
		local present = 0
		for _, child in box:GetChildren() do
			if parentName ~= WALK_FOLDER_NAME or HEAD_WALK_NAMES[child.Name] then
				present += 1
			end
		end
		if present ~= #wanted then
			table.insert(problems, `{parentName} holds {present} head parts, recorded {#wanted}`)
		end
		local used: { [Instance]: boolean } = {}
		for _, record in wanted do
			local found: BasePart? = nil
			for _, child in box:GetChildren() do
				if not used[child] and child.Name == record.name and child:IsA("BasePart") then
					if sameAs(child, record.size, record.cframe) then
						found = child
						break
					end
				end
			end
			if found == nil then
				table.insert(
					problems,
					`{parentName}.{record.name}: nothing at {describePlace(record.cframe)} with size {tostring(
						record.size
					)}`
				)
			else
				used[found] = true
				if record.shape ~= nil and found:IsA("Part") and found.Shape ~= record.shape then
					table.insert(
						problems,
						`{parentName}.{record.name} at {describePlace(record.cframe)}: Shape is {found.Shape.Name}, expected {record.shape.Name}`
					)
				end
				local wrong = headSettingsProblem(found, HEAD_SETTINGS[record.name])
				if wrong ~= nil then
					table.insert(problems, `{parentName}.{record.name} at {describePlace(record.cframe)}: {wrong}`)
				end
			end
		end
	end
	return problems
end

-- What is wrong with the head after section 2f, whether the slot blocks are still (1, 12, 4) or already (1, 17, 6) (section
-- 2f3), and whether section 2f4 (truss 32, shorter part B) has run or not. Empty means one of the three final heads is
-- there.
local function headProblemsEitherSlot(walk: Instance): { string }
	local problems = headProblems(walk, FINAL_HEAD_PARTS_2F)
	if #problems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		return {}
	end
	if #problems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		return {}
	end
	if #problems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		return {}
	end
	if #problems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		return {}
	end
	return problems
end

-- The first few problems as one line.
local function someProblems(problems: { string }): string
	local shown: { string } = {}
	for index = 1, math.min(#problems, 5) do
		table.insert(shown, problems[index])
	end
	local text = table.concat(shown, "; ")
	if #problems > 5 then
		text ..= `; and {#problems - 5} more`
	end
	return text
end

local function countParts(records: { HeadPart }, parent: string): number
	local count = 0
	for _, record in records do
		if record.parent == parent then
			count += 1
		end
	end
	return count
end

-- Which of V1's own parts each kind of new part is a copy of (same class, material, colour and settings).
local TEMPLATE_BOX: { [string]: string } = {
	SideRail = "ForeheadGuard",
	Rung = "CapLadder",
	Rail = "CapLadder",
	Climb = "CapLadder",
}
local NEW_HEAD_BOXES = { "ForeheadGuard", "BeardLadder", "CapLadder" }

-- Every head part that goes: Nose_Walk, the 3 Nightcap_Walk, the middle Guard, V1's 2 SideRail and every part of both
-- ladders (both are re-made).
local function oldHeadParts(walk: Instance): { BasePart }
	local old: { BasePart } = {}
	for _, child in walk:GetChildren() do
		if HEAD_WALK_NAMES[child.Name] and child:IsA("BasePart") then
			table.insert(old, child)
		end
	end
	local forehead = walk:FindFirstChild("ForeheadGuard")
	if forehead ~= nil then
		for _, child in forehead:GetChildren() do
			if child:IsA("BasePart") then
				if
					child.Name == "SideRail" or (child.Name == "Guard" and math.abs(child.Position.X) < MIDDLE_GUARD_X)
				then
					table.insert(old, child)
				end
			end
		end
	end
	for _, boxName in { "CapLadder", "BeardLadder" } do
		local box = walk:FindFirstChild(boxName)
		if box ~= nil then
			for _, child in box:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(old, child)
				end
			end
		end
	end
	return old
end

-- The change: build the new parts away from the Workspace (copies of V1's own SideRail, Rung, Rail and Climb), check
-- them, then between two waypoints remove the old parts and put the new ones in. Returns the report.
local function changeHead(walk: Instance): string
	-- What goes, counted first: V1 had 52 head parts, the final head keeps its 4 side Guards.
	local old = oldHeadParts(walk)
	local expectedOld = #V1_HEAD_PARTS - (#FINAL_HEAD_PARTS - #NEW_HEAD_PARTS)
	if #old ~= expectedOld then
		error(`nothing was changed. {#old} head parts would go, expected {expectedOld}`)
	end

	-- V1's own parts are the templates.
	local templates: { [string]: BasePart } = {}
	for name, boxName in TEMPLATE_BOX do
		local box = walk:FindFirstChild(boxName)
		local template: BasePart? = nil
		if box ~= nil then
			for _, child in box:GetChildren() do
				if child.Name == name and child:IsA("BasePart") then
					template = child
					break
				end
			end
		end
		if template == nil then
			error(`nothing was changed. No {boxName}.{name} to copy`)
		end
		templates[name] = template
	end

	-- Build every new part away from the Workspace and check it.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging"
	staging.Archivable = false
	local stagedBoxes: { [string]: Folder } = {}
	for _, boxName in NEW_HEAD_BOXES do
		local folder = Instance.new("Folder")
		folder.Name = boxName
		folder.Parent = staging
		stagedBoxes[boxName] = folder
	end
	local problems: { string } = {}
	for _, record in NEW_HEAD_PARTS do
		local copy = templates[record.name]:Clone() :: BasePart
		copy.Size = record.size
		copy.CFrame = record.cframe
		copy.Parent = stagedBoxes[record.parent]
		local same, why = sameAs(copy, record.size, record.cframe)
		if not same then
			table.insert(problems, `{record.parent}.{record.name}: {why}`)
		end
		local wrong = headSettingsProblem(copy, HEAD_SETTINGS[record.name])
		if wrong ~= nil then
			table.insert(problems, `{record.parent}.{record.name}: {wrong}`)
		end
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The new parts are not right: " .. someProblems(problems))
	end

	-- The report's lines for what goes (old size and place).
	local lines: { string } = {}
	local before: { [string]: number } = {}
	for _, boxName in HEAD_PARENTS do
		local box = if boxName == WALK_FOLDER_NAME then walk else walk:FindFirstChild(boxName)
		before[boxName] = if box ~= nil then #box:GetChildren() else 0
	end
	for _, part in old do
		local boxName = if part.Parent ~= nil then part.Parent.Name else "?"
		table.insert(
			lines,
			string.format(
				"removed %s.%s: %.3f x %.3f x %.3f at %s",
				boxName,
				part.Name,
				part.Size.X,
				part.Size.Y,
				part.Size.Z,
				describePlace(part.CFrame)
			)
		)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2b: before")
	end)
	local changed, whyNot = pcall(function()
		for _, part in old do
			part:Destroy()
		end
		for _, boxName in NEW_HEAD_BOXES do
			local liveBox = walk:FindFirstChild(boxName)
			if liveBox == nil then
				error(`{boxName} is missing`)
			end
			for _, part in stagedBoxes[boxName]:GetChildren() do
				part.Parent = liveBox
			end
		end
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2b: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2b: before") and tell code_lead`
		)
	end

	-- Check the result against the recorded final head.
	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS)
	if #afterProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(afterProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end

	-- The report's lines for what was added: every side rail, truss and rail, and each ladder's first and last rung.
	local rungsTotal: { [string]: number } = {}
	for _, record in NEW_HEAD_PARTS do
		if record.name == "Rung" then
			rungsTotal[record.parent] = (rungsTotal[record.parent] or 0) + 1
		end
	end
	local rungsSeen: { [string]: number } = {}
	for _, record in NEW_HEAD_PARTS do
		local show = true
		if record.name == "Rung" then
			local seen = (rungsSeen[record.parent] or 0) + 1
			rungsSeen[record.parent] = seen
			show = seen == 1 or seen == rungsTotal[record.parent]
		end
		if show then
			table.insert(
				lines,
				string.format(
					"added %s.%s: %s %.3f x %.3f x %.3f at %s",
					record.parent,
					record.name,
					HEAD_SETTINGS[record.name].className,
					record.size.X,
					record.size.Y,
					record.size.Z,
					describePlace(record.cframe)
				)
			)
		end
	end
	for _, boxName in { "BeardLadder", "CapLadder" } do
		table.insert(lines, `{boxName}: {rungsTotal[boxName]} rungs added (the first and the last are listed above)`)
	end
	table.insert(
		lines,
		string.format(
			"head parts removed: %d; added: %d; kept (the 4 side Guards): %d",
			#old,
			#NEW_HEAD_PARTS,
			#FINAL_HEAD_PARTS - #NEW_HEAD_PARTS
		)
	)
	for _, boxName in HEAD_PARENTS do
		local box = if boxName == WALK_FOLDER_NAME then walk else walk:FindFirstChild(boxName)
		local now = if box ~= nil then #box:GetChildren() else 0
		table.insert(lines, `{boxName}: {before[boxName]} children before, {now} after`)
	end
	return table.concat(lines, "\n")
end

local function sectionHead(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	-- Two worlds are known; anything else stops with nothing changed.
	--   (b) the final head: already done. Part A may be the box (this section's own result) or section 2d's wedge, and
	--       then the 2 slot blocks are there too.
	--   (a) V1's head: all 52 parts as recorded. The change is made.
	local finalProblems = headProblems(walk, FINAL_HEAD_PARTS)
	local finalRecords = FINAL_HEAD_PARTS
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2D) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2D
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2E) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2E
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2F) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2F
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2G
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2H
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2I
	end
	if #finalProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		finalProblems = {}
		finalRecords = FINAL_HEAD_PARTS_2J
	end
	if #finalProblems == 0 then
		return string.format(
			"already done: his head is the final one (%d recorded head parts: ForeheadGuard %d, BeardLadder %d at %.1f degrees, CapLadder %d at %.1f degrees; Nose_Walk, Nightcap_Walk and the middle Guard are gone; part A is %s)",
			#finalRecords,
			countParts(finalRecords, "ForeheadGuard"),
			countParts(finalRecords, "BeardLadder"),
			BEARD_LADDER_ANGLE,
			countParts(finalRecords, "CapLadder"),
			CAP_LADDER_ANGLE,
			if finalRecords == FINAL_HEAD_PARTS
				then "the box"
				elseif finalRecords == FINAL_HEAD_PARTS_2D then "section 2d's wedge, with the 2 slot blocks"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2E
				then "section 2d's wedge, with the 2 slot blocks, and the beard rails are section 2e's longer ones"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2F
				then "section 2d's wedge, with the 2 slot blocks, section 2e's longer beard rails and section 2f's longer truss"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2G
				then "section 2d's wedge, section 2e's longer beard rails, section 2f's longer truss and section 2f3's wider slot blocks"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2H
				then "section 2d's wedge, section 2e's longer beard rails, section 2f4's 32 long truss, section 2f3's wider slot blocks and section 2f4's shorter part B"
				elseif
					finalRecords == FINAL_HEAD_PARTS_2I
				then "section 2d's wedge, section 2e's longer beard rails, section 2f4's 32 long truss turned by section 2f6, section 2f3's wider slot blocks and section 2f4's shorter part B"
				else "section 2d's wedge, section 2g's 34.60 long beard rails and extra rung, section 2f4's 32 long truss turned by section 2f6, section 2f3's wider slot blocks and section 2f4's shorter part B"
		)
	end
	local v1Problems = headProblems(walk, V1_HEAD_PARTS)
	if #v1Problems > 0 then
		error(
			"nothing was changed. His head is neither V1's ("
				.. someProblems(v1Problems)
				.. ") nor the final one ("
				.. someProblems(finalProblems)
				.. ")"
		)
	end
	return changeHead(walk)
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2c: the zone over the nose rails (stuck safety Task 25, step 4 ruling)
----------------------------------------------------------------------------------------------------------------------
-- Why: the tops of the new side rails beside the open nose top stand at y 107, so a player on one stands at y 110. The
-- Beard_Ladder zone box (it holds the nose top) stops at y 107, so those two spots (+-4, 110, -11) were in no giant zone.
-- The box grows upward by 4 studs, to y 111 (1 stud to spare). Nothing else changes: its foot (y 66), its width and depth,
-- its place across and along, its Beard zone and every other zone box stay. Where the box now reaches above y 107 and
-- z -10 or further back, the higher Nightcap_Brow zone already wins, so no other spot changes zone.
-- Recorded as measured in Studio Edit mode on 2026-10-20.
local ZONE_BOX_NAME = "Beard_Ladder"
local ZONE_BOX_BEFORE_SIZE = Vector3.new(24, 41, 32)
local ZONE_BOX_BEFORE_POSITION = Vector3.new(0, 86.5, -12)
local ZONE_BOX_AFTER_SIZE = Vector3.new(24, 45, 32)
local ZONE_BOX_AFTER_POSITION = Vector3.new(0, 88.5, -12)

-- Is the box this size and place, and not turned? An empty string means yes.
local function zoneBoxProblem(box: BasePart, size: Vector3, position: Vector3): string
	if (box.Size - size).Magnitude > RECORD_TOLERANCE then
		return string.format("size is %.2f, %.2f, %.2f", box.Size.X, box.Size.Y, box.Size.Z)
	end
	if (box.Position - position).Magnitude > RECORD_TOLERANCE then
		return string.format("place is %.2f, %.2f, %.2f", box.Position.X, box.Position.Y, box.Position.Z)
	end
	local turned = box.CFrame.RightVector:Dot(Vector3.xAxis) < 0.9999
		or box.CFrame.UpVector:Dot(Vector3.yAxis) < 0.9999
		or box.CFrame.LookVector:Dot(Vector3.zAxis) > -0.9999
	if turned then
		return "it is turned"
	end
	return ""
end

local function sectionZone(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local zones = if world ~= nil then world:FindFirstChild("Zones") else nil
	local found = if zones ~= nil then zones:FindFirstChild(ZONE_BOX_NAME) else nil
	if found == nil or not found:IsA("BasePart") then
		error(`World.Zones.{ZONE_BOX_NAME} is missing`)
	end
	local box = found :: BasePart
	if box:GetAttribute("Zone") ~= "Beard" then
		error(`nothing was changed. World.Zones.{ZONE_BOX_NAME} is not a Beard zone box`)
	end

	-- Two worlds are known; anything else stops with nothing changed.
	--   (b) the grown box: already done.
	--   (a) V1's box: it grows.
	local afterProblem = zoneBoxProblem(box, ZONE_BOX_AFTER_SIZE, ZONE_BOX_AFTER_POSITION)
	if afterProblem == "" then
		return string.format(
			"already done: World.Zones.%s is the grown box (size %.0f, %.0f, %.0f at %.1f, %.1f, %.1f, so it reaches up to y %.1f)",
			ZONE_BOX_NAME,
			box.Size.X,
			box.Size.Y,
			box.Size.Z,
			box.Position.X,
			box.Position.Y,
			box.Position.Z,
			box.Position.Y + box.Size.Y / 2
		)
	end
	local beforeProblem = zoneBoxProblem(box, ZONE_BOX_BEFORE_SIZE, ZONE_BOX_BEFORE_POSITION)
	if beforeProblem ~= "" then
		error(
			`nothing was changed. World.Zones.{ZONE_BOX_NAME} is neither the old box ({beforeProblem}) nor the grown one ({afterProblem})`
		)
	end

	ChangeHistoryService:SetWaypoint("15-real-shape section 2c: before")
	box.Size = ZONE_BOX_AFTER_SIZE
	box.CFrame = CFrame.new(ZONE_BOX_AFTER_POSITION)
	ChangeHistoryService:SetWaypoint("15-real-shape section 2c: after")
	local stillProblem = zoneBoxProblem(box, ZONE_BOX_AFTER_SIZE, ZONE_BOX_AFTER_POSITION)
	if stillProblem ~= "" then
		error(`World.Zones.{ZONE_BOX_NAME} did not become the grown box: {stillProblem}`)
	end
	return string.format(
		"grown: World.Zones.%s was size 24, 41, 32 at 0, 86.5, -12 (up to y 107) and is now size 24, 45, 32 at 0, 88.5, -12 (up to y 111)",
		ZONE_BOX_NAME
	)
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2d: rail tops and the ladder slot (stuck safety Task 25, Rulings 12 and 13, steps 5b and 5c)
----------------------------------------------------------------------------------------------------------------------
-- Why: step 5b's second grid found stuck spots the first missed.
--   * Ruling 13: the flat top of each rail beside the nose (part A, 1.5 wide) holds a body. Part A becomes a wedge: its
--     inner face stays upright and full height, its outer side is one slope of about 87 degrees, so it has no top.
--   * Ruling 12: between the cap ladder's truss (|x| 1.0) and the cap part of the rails (part B, |x| 3.6) is a 2.6 wide
--     slot under the brim where a body fits on his forehead. One invisible LadderSlotBlock per side fills it.
-- The numbers are at the top of this file's head data (PART_A_*, WEDGE_SIZE_*, SLOT_BLOCK_*), as confirmed by step 5c-1.
-- It knows three worlds, and changes nothing on any difference:
--   (a) the world after 2b and 2c: part A boxes, no LadderSlotBlock. The change below is made.
--   (b) the world after 2d: part A wedges and the 2 blocks. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- The change (between two ChangeHistoryService waypoints): part A gets its Shape, Size and CFrame set in place; the 2
-- blocks are copies of part B (a SideRail), built away from the Workspace first, then parented to ForeheadGuard.
local function sectionRailTops(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local guardBox = walk:FindFirstChild("ForeheadGuard")
	if guardBox == nil then
		error("World.WalkSurfaces.ForeheadGuard is missing")
	end

	local afterRecords = FINAL_HEAD_PARTS_2D
	local afterProblems = headProblems(walk, afterRecords)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2E) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2E
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2F) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2F
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2G
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2H
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2I
		afterProblems = {}
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterRecords = FINAL_HEAD_PARTS_2J
		afterProblems = {}
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: the 2 part A rails are wedges and ForeheadGuard holds the 2 %s (%d recorded head parts)",
			SLOT_BLOCK_NAME,
			#afterRecords
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after sections 2b and 2c ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2d ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live part A rails (the check above found each one) and part B, whose settings the blocks copy.
	local liveRails: { Part } = {}
	for _, pair in PART_A_BEFORE_AFTER do
		local found: Part? = nil
		for _, child in guardBox:GetChildren() do
			if child.Name == pair[1].name and child:IsA("Part") and sameAs(child, pair[1].size, pair[1].cframe) then
				found = child
				break
			end
		end
		if found == nil then
			error(`nothing was changed. No part A SideRail at {describePlace(pair[1].cframe)} to turn into a wedge`)
		end
		table.insert(liveRails, found)
	end
	local template: Part? = nil
	for _, child in guardBox:GetChildren() do
		if child.Name == "SideRail" and child:IsA("Part") and child.Shape == Enum.PartType.Block then
			if child.Position.Z > PART_A_BEHIND_Z then
				template = child
				break
			end
		end
	end
	if template == nil then
		error("nothing was changed. No part B SideRail in ForeheadGuard to copy for the blocks")
	end

	-- Build the blocks away from the Workspace and check them.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging2d"
	staging.Archivable = false
	local problems: { string } = {}
	for _, record in SLOT_BLOCK_PARTS do
		local block = template:Clone()
		block.Name = record.name
		block.Size = record.size
		block.CFrame = record.cframe
		block.Parent = staging
		local same, why = sameAs(block, record.size, record.cframe)
		if not same then
			table.insert(problems, `{record.name}: {why}`)
		end
		local wrong = headSettingsProblem(block, HEAD_SETTINGS[record.name])
		if wrong ~= nil then
			table.insert(problems, `{record.name}: {wrong}`)
		end
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The blocks are not right: " .. someProblems(problems))
	end

	-- The report's lines for part A (old size and place), taken before the change.
	local lines: { string } = {}
	for index, rail in liveRails do
		local wedge = PART_A_BEFORE_AFTER[index][2]
		table.insert(
			lines,
			string.format(
				"part A at x %.2f: box %.4f x %.4f x %.4f at %s -> wedge %.4f x %.4f x %.4f at %s (same centre)",
				rail.Position.X,
				rail.Size.X,
				rail.Size.Y,
				rail.Size.Z,
				describePlace(rail.CFrame),
				wedge.size.X,
				wedge.size.Y,
				wedge.size.Z,
				describePlace(wedge.cframe)
			)
		)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2d: before")
	end)
	local changed, whyNot = pcall(function()
		for index, rail in liveRails do
			local wedge = PART_A_BEFORE_AFTER[index][2]
			rail.Shape = Enum.PartType.Wedge
			rail.Size = wedge.size
			rail.CFrame = wedge.cframe
		end
		for _, block in staging:GetChildren() do
			block.Parent = guardBox
		end
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2d: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2d: before") and tell code_lead`
		)
	end

	-- Check the result against the recorded final head.
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2D)
	if #stillProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	for _, record in SLOT_BLOCK_PARTS do
		table.insert(
			lines,
			string.format(
				"added ForeheadGuard.%s: %.1f x %.1f x %.1f at %s",
				record.name,
				record.size.X,
				record.size.Y,
				record.size.Z,
				describePlace(record.cframe)
			)
		)
	end
	table.insert(
		lines,
		string.format(
			"ForeheadGuard now holds %d children (%d recorded head parts)",
			#guardBox:GetChildren(),
			countParts(FINAL_HEAD_PARTS_2D, "ForeheadGuard")
		)
	)
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2e: the beard ladder's foot (stuck safety Task 25, step 6b-1 ruling)
----------------------------------------------------------------------------------------------------------------------
-- Why: designer asked that the beard ladder's visible rails reach down to touch his belly. Each rail gets 3.15 studs
-- longer at its bottom end only (its top end stays), and one more rung, a copy of the lowest rung, goes 1.80 further
-- down the ladder. The truss, the foot point and the 16 rungs don't move. Rails and rungs are not solid (CanCollide off),
-- so nothing new can be stood on. The numbers are BEARD_RAIL_LONG_* and BEARD_EXTRA_RUNG_CENTRE above, from step 6b-1a.
-- It knows three worlds, and changes nothing on any difference:
--   (a) the world after 2d: beard rails 28.70 long and 16 rungs. The change below is made.
--   (b) the world after 2e: beard rails 31.85 long and 17 rungs. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- The change (between two ChangeHistoryService waypoints): the 2 live rails get their Size and CFrame set in place; the
-- extra rung is a copy of the lowest live rung, built away from the Workspace first, then parented to BeardLadder.
local function sectionBeardFoot(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local beardBox = walk:FindFirstChild("BeardLadder")
	if beardBox == nil then
		error("World.WalkSurfaces.BeardLadder is missing")
	end

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2E)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2F) == 0 then
		afterProblems = {} -- the world after section 2f: the same rails and rung, with the longer truss
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2G) == 0 then
		afterProblems = {} -- the world after section 2f3: the same, with the wider slot blocks
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		afterProblems = {} -- the world after section 2f4: the same, with the 32 long truss and the shorter part B
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterProblems = {} -- the world after section 2f6: the same, with the truss's foot swung back
	end
	local longerStill = false
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the rails are longer still and one more rung is in
		longerStill = true
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: the 2 beard rails are %.2f long%s and BeardLadder holds the extra rung (%d recorded head parts)",
			BEARD_RAIL_LONG_LENGTH,
			if longerStill then " (section 2g has made them longer still)" else "",
			#FINAL_HEAD_PARTS_2E
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2D)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2d ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2e ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The numbers must keep each rail's top end where it is (within BEARD_TOP_SLACK), or nothing is changed.
	local lines: { string } = {}
	for _, pair in BEARD_RAIL_BEFORE_AFTER do
		local oldTop = pair[1].cframe.Position + pair[1].cframe.RightVector * (pair[1].size.X / 2)
		local newTop = pair[2].cframe.Position + pair[2].cframe.RightVector * (pair[2].size.X / 2)
		if (oldTop - newTop).Magnitude > BEARD_TOP_SLACK then
			error(
				`nothing was changed. The beard rail at x {pair[1].cframe.X} would move its top end by {(
					oldTop - newTop
				).Magnitude} studs`
			)
		end
	end

	-- The live rails (the check above found each one) and the lowest live rung, whose settings the extra rung copies.
	local liveRails: { Part } = {}
	for _, pair in BEARD_RAIL_BEFORE_AFTER do
		local found: Part? = nil
		for _, child in beardBox:GetChildren() do
			if child.Name == pair[1].name and child:IsA("Part") and sameAs(child, pair[1].size, pair[1].cframe) then
				found = child
				break
			end
		end
		if found == nil then
			error(`nothing was changed. No beard Rail at {describePlace(pair[1].cframe)} to make longer`)
		end
		table.insert(liveRails, found)
	end
	local template: Part? = nil
	for _, child in beardBox:GetChildren() do
		if child.Name == BEARD_LOWEST_RUNG.name and child:IsA("Part") then
			if sameAs(child, BEARD_LOWEST_RUNG.size, BEARD_LOWEST_RUNG.cframe) then
				template = child
				break
			end
		end
	end
	if template == nil then
		error("nothing was changed. The lowest beard Rung is not there to copy for the extra rung")
	end

	-- Build the extra rung away from the Workspace and check it.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging2e"
	staging.Archivable = false
	local extra = template:Clone()
	extra.Name = BEARD_EXTRA_RUNG.name
	extra.Size = BEARD_EXTRA_RUNG.size
	extra.CFrame = BEARD_EXTRA_RUNG.cframe
	extra.Parent = staging
	local problems: { string } = {}
	local same, why = sameAs(extra, BEARD_EXTRA_RUNG.size, BEARD_EXTRA_RUNG.cframe)
	if not same then
		table.insert(problems, `{BEARD_EXTRA_RUNG.name}: {why}`)
	end
	local wrong = headSettingsProblem(extra, HEAD_SETTINGS[BEARD_EXTRA_RUNG.name])
	if wrong ~= nil then
		table.insert(problems, `{BEARD_EXTRA_RUNG.name}: {wrong}`)
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The extra rung is not right: " .. someProblems(problems))
	end

	-- The report's lines for the rails (old and new size and place), taken before the change.
	for index, rail in liveRails do
		local longer = BEARD_RAIL_BEFORE_AFTER[index][2]
		table.insert(
			lines,
			string.format(
				"beard Rail at x %.2f: %.4f x %.4f x %.4f at %s -> %.4f x %.4f x %.4f at %s (bottom end only; top end stays)",
				rail.Position.X,
				rail.Size.X,
				rail.Size.Y,
				rail.Size.Z,
				describePlace(rail.CFrame),
				longer.size.X,
				longer.size.Y,
				longer.size.Z,
				describePlace(longer.cframe)
			)
		)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2e: before")
	end)
	local changed, whyNot = pcall(function()
		for index, rail in liveRails do
			local longer = BEARD_RAIL_BEFORE_AFTER[index][2]
			rail.Size = longer.size
			rail.CFrame = longer.cframe
		end
		extra.Parent = beardBox
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2e: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2e: before") and tell code_lead`
		)
	end

	-- Check the result against the recorded final head.
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2E)
	if #stillProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		string.format(
			"added BeardLadder.%s: %.2f x %.2f x %.2f at %s (a copy of the lowest rung, 1.80 further down)",
			BEARD_EXTRA_RUNG.name,
			BEARD_EXTRA_RUNG.size.X,
			BEARD_EXTRA_RUNG.size.Y,
			BEARD_EXTRA_RUNG.size.Z,
			describePlace(BEARD_EXTRA_RUNG.cframe)
		)
	)
	table.insert(
		lines,
		string.format(
			"BeardLadder now holds %d children (%d recorded head parts)",
			#beardBox:GetChildren(),
			countParts(FINAL_HEAD_PARTS_2E, "BeardLadder")
		)
	)
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2f: his body follows his skin (stuck safety Task 26, step 26-2)
----------------------------------------------------------------------------------------------------------------------
-- Why: Roblox's usual shape for his belly and chair piece (PreciseConvexDecomposition) bridges dips, so over much of his
-- belly a player stands 1 to 4.4 studs above the cloth they see. The shape called Tunable follows the mesh closer there
-- (measured in step 6b-1f: belly spots more than 0.2 above his skin go from 171 to 46). It is one mesh, so the chair side
-- gets worse (175 to 297); those spots are dealt with in later steps. His other five pieces stay PreciseConvexDecomposition,
-- because Tunable makes each of them worse. Rule 20 (One collision source), check 6 (His body stands where he's drawn).
-- Only a script can do it this way: AssetService:CreateMeshPartAsync makes a MeshPart with CollisionFidelity Tunable from
-- the piece's own mesh, and MeshPart:ApplyMesh copies its mesh, texture, fidelities, size and collision shape onto the
-- piece. In the Roblox docs, ApplyMesh overwrites MeshContent, TextureContent, RenderFidelity, CollisionFidelity,
-- FluidFidelity and MeshSize. Measured in step 6b-1f: it wipes TextureID, so it is put back at once.
-- The second change is the beard ladder's climbing truss `Climb`: 2.0 studs longer at its bottom end only, on the same
-- line (BEARD_TRUSS_EXTRA above; designer said yes, on condition the climb starts on the visible ladder).
-- It knows two worlds, and changes nothing on any difference:
--   (a) the world after 2e: body_and_cushion is PreciseConvexDecomposition, the truss is 28 long. The change is made.
--   (b) the world after 2f: body_and_cushion is Tunable and the truss is 30 long. It says "already done".
--   (c) anything else (including only one of the two changes): it stops with nothing changed and names what differs.
-- Before it touches the world it tries ApplyMesh on a clone away from the Workspace: every property of the clone must
-- match the piece except CollisionFidelity and CollisionPrecision (which follows the fidelity and must come out near
-- 0.36, the number measured in step 6b-1f), or nothing is changed. The change itself runs between two
-- ChangeHistoryService waypoints, and is checked again afterwards the same way. Then it waits until Roblox has worked
-- out the new shape (the same fixed rays as section 1, and the piece's rays must have moved).
local BODY_MESH_ID = "rbxassetid://126943333253304" -- as read in Studio Edit mode on 2026-10-20
local BODY_TEXTURE_ID = "rbxassetid://78855063453992"
local BODY_TUNABLE_PRECISION = 0.36 -- CollisionPrecision of the Tunable body in step 6b-1f
local BODY_PRECISION_SLACK = 0.02
local BODY_MAY_DIFFER: { [string]: boolean } = { CollisionFidelity = true, CollisionPrecision = true }
local BODY_COMPARED: { string } = {
	"Name",
	"Archivable",
	"Size",
	"CFrame",
	"Material",
	"MaterialVariant",
	"Color",
	"Transparency",
	"Reflectance",
	"CastShadow",
	"Anchored",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"CollisionGroup",
	"Massless",
	"Locked",
	"CustomPhysicalProperties",
	"MeshId",
	"MeshSize",
	"TextureID",
	"RenderFidelity",
	"FluidFidelity",
	"DoubleSided",
	"CollisionFidelity",
	"CollisionPrecision",
	"ChildCount",
	"AttributeCount",
}

-- Every property above that the piece can be asked for, plus how many children and attributes it has.
local function bodySnapshot(mesh: MeshPart): { [string]: any }
	local values: { [string]: any } = {}
	for _, name in BODY_COMPARED do
		local readable, value = pcall(function(): any
			return (mesh :: any)[name]
		end)
		if readable then
			values[name] = value
		end
	end
	values.ChildCount = #mesh:GetChildren()
	local attributes = 0
	for _ in mesh:GetAttributes() do
		attributes += 1
	end
	values.AttributeCount = attributes
	return values
end

-- The names of the compared values that differ between two snapshots, in the order of BODY_COMPARED.
local function bodyDifferences(first: { [string]: any }, second: { [string]: any }): { string }
	local names: { string } = {}
	for _, name in BODY_COMPARED do
		if first[name] ~= second[name] then
			table.insert(names, name)
		end
	end
	return names
end

local function unexpectedDifferences(names: { string }): { string }
	local unexpected: { string } = {}
	for _, name in names do
		if not BODY_MAY_DIFFER[name] then
			table.insert(unexpected, name)
		end
	end
	return unexpected
end

local function countValues(values: { [string]: any }): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

-- The two ends of a truss along its long side (its local z): the higher one first.
local function trussEnds(size: Vector3, cframe: CFrame): (Vector3, Vector3)
	local along = cframe.LookVector * (size.Z / 2)
	local first, second = cframe.Position + along, cframe.Position - along
	if first.Y >= second.Y then
		return first, second
	end
	return second, first
end

local function sectionBodyFollowsSkin(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local found: Piece? = nil
	for _, piece in pieces do
		if piece.name == BODY_PIECE then
			found = piece
		end
	end
	if found == nil then
		error(`nothing was changed. {BODY_PIECE} is missing`)
	end
	local body: Piece = found
	local mesh = body.mesh
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local beardBox = walk:FindFirstChild("BeardLadder")
	if beardBox == nil then
		error("World.WalkSurfaces.BeardLadder is missing")
	end

	-- What never changes: the mesh and the texture as recorded, and the other five pieces on PreciseConvexDecomposition
	-- (the head, the nightcap and the legs may already be Tunable once sections 2f2 and 2f5 have run).
	local problems: { string } = {}
	local headOrCapTunable = false
	if mesh.MeshId ~= BODY_MESH_ID then
		table.insert(problems, `{BODY_PIECE}: MeshId is {mesh.MeshId}, recorded {BODY_MESH_ID}`)
	end
	if mesh.TextureID ~= BODY_TEXTURE_ID then
		table.insert(problems, `{BODY_PIECE}: TextureID is {mesh.TextureID}, recorded {BODY_TEXTURE_ID}`)
	end
	for _, piece in pieces do
		if piece.name ~= BODY_PIECE then
			local pieceFidelity = piece.mesh.CollisionFidelity
			if CLOSER_FIT_PIECES[piece.name] and pieceFidelity == Enum.CollisionFidelity.Tunable then
				headOrCapTunable = true
			elseif pieceFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
				table.insert(
					problems,
					`{piece.name}: CollisionFidelity is {pieceFidelity.Name}, expected PreciseConvexDecomposition`
				)
			end
		end
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	local trussPair = BEARD_TRUSS_BEFORE_AFTER[1]
	local fidelity = mesh.CollisionFidelity
	local afterProblems = headProblemsEitherSlot(walk)
	-- The Tunable body is at 0.36 (after 2f) or at 1.0 (after the closer fit, section 2f2): both count as done here.
	local bodyPrecision = mesh.CollisionPrecision
	local bodyPrecisionKnown = math.abs(bodyPrecision - BODY_TUNABLE_PRECISION) <= BODY_PRECISION_SLACK
		or math.abs(bodyPrecision - 1) <= 0.01
	if fidelity == Enum.CollisionFidelity.Tunable and bodyPrecisionKnown and #afterProblems == 0 then
		return string.format(
			"already done: %s is Tunable (collision precision %.2f) with its mesh and texture as recorded, the other five pieces are PreciseConvexDecomposition (or Tunable for the head, the nightcap and the legs after sections 2f2 and 2f5), and the beard truss is %.0f long, or 32 after section 2f4 (%d recorded head parts)",
			BODY_PIECE,
			mesh.CollisionPrecision,
			trussPair[2].size.Z,
			#FINAL_HEAD_PARTS_2F
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2E)
	if fidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition or headOrCapTunable or #beforeProblems > 0 then
		error(
			`nothing was changed. His body and head are neither the world after section 2e ({BODY_PIECE} {fidelity.Name} at {string.format(
				"%.2f",
				bodyPrecision
			)}, head or nightcap Tunable: {headOrCapTunable}, head: {someProblems(beforeProblems)}) nor the world after 2f (head: {someProblems(
				afterProblems
			)})`
		)
	end

	-- The live truss, and the numbers that must hold for the longer one: top end stays, bottom end moves BEARD_TRUSS_EXTRA.
	local truss: TrussPart? = nil
	for _, child in beardBox:GetChildren() do
		if
			child.Name == "Climb"
			and child:IsA("TrussPart")
			and sameAs(child, trussPair[1].size, trussPair[1].cframe)
		then
			truss = child
			break
		end
	end
	if truss == nil then
		error("nothing was changed. No beard Climb truss as recorded to make longer")
	end
	local oldTop, oldBottom = trussEnds(trussPair[1].size, trussPair[1].cframe)
	local newTop, newBottom = trussEnds(trussPair[2].size, trussPair[2].cframe)
	if (oldTop - newTop).Magnitude > BEARD_TRUSS_TOP_SLACK then
		error(`nothing was changed. The longer truss would move its top end by {(oldTop - newTop).Magnitude} studs`)
	end
	if math.abs((oldBottom - newBottom).Magnitude - BEARD_TRUSS_EXTRA) > 0.01 or newBottom.Y >= oldBottom.Y then
		error("nothing was changed. The longer truss's bottom end is not 2.0 studs further down the same line")
	end

	-- Dry run: ApplyMesh on a clone, away from the Workspace. Nothing in the world changes if it is not right.
	local staging = Instance.new("Folder")
	staging.Name = "Task26Staging2f"
	staging.Archivable = false
	local made, madeOrWhy = pcall(function(): MeshPart
		return AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
			CollisionFidelity = Enum.CollisionFidelity.Tunable,
			RenderFidelity = mesh.RenderFidelity,
			FluidFidelity = mesh.FluidFidelity,
		})
	end)
	if not made then
		staging:Destroy()
		error("nothing was changed. CreateMeshPartAsync failed: " .. tostring(madeOrWhy))
	end
	local source = madeOrWhy :: MeshPart
	source.Parent = staging
	local trial = mesh:Clone()
	trial.Parent = staging
	local wiped = false
	local trialOk, trialWhy = pcall(function()
		trial:ApplyMesh(source)
		wiped = trial.TextureID ~= BODY_TEXTURE_ID
		trial.TextureID = BODY_TEXTURE_ID
	end)
	local before = bodySnapshot(mesh)
	local trialSnapshot = bodySnapshot(trial)
	local trialPrecision = trial.CollisionPrecision
	local trialFidelity = trial.CollisionFidelity
	if not trialOk then
		staging:Destroy()
		error("nothing was changed. ApplyMesh failed on the clone: " .. tostring(trialWhy))
	end
	local trialDifferences = unexpectedDifferences(bodyDifferences(before, trialSnapshot))
	if #trialDifferences > 0 then
		staging:Destroy()
		error(
			"nothing was changed. ApplyMesh on the clone changed more than the collision: "
				.. table.concat(trialDifferences, ", ")
		)
	end
	if trialFidelity ~= Enum.CollisionFidelity.Tunable then
		staging:Destroy()
		error(`nothing was changed. The clone's CollisionFidelity is {trialFidelity.Name}, expected Tunable`)
	end
	if math.abs(trialPrecision - BODY_TUNABLE_PRECISION) > BODY_PRECISION_SLACK then
		staging:Destroy()
		error(
			string.format(
				"nothing was changed. The clone's CollisionPrecision is %.3f, step 6b-1f measured %.2f",
				trialPrecision,
				BODY_TUNABLE_PRECISION
			)
		)
	end

	-- The report's lines, and the rays read before the change.
	local lines: { string } = {}
	local oldPrecision = mesh.CollisionPrecision
	for _, piece in pieces do
		piece.changing = piece.name == BODY_PIECE
		piece.before = readRays(piece.mesh, piece.rays)
	end
	table.insert(
		lines,
		string.format(
			"beard Climb truss: %.0f x %.0f x %.0f at %s -> %.0f x %.0f x %.0f at %s; top end moved %.3f studs; foot (bottom end) %s -> %s, %.2f studs lower",
			trussPair[1].size.X,
			trussPair[1].size.Y,
			trussPair[1].size.Z,
			describePlace(trussPair[1].cframe),
			trussPair[2].size.X,
			trussPair[2].size.Y,
			trussPair[2].size.Z,
			describePlace(trussPair[2].cframe),
			(oldTop - newTop).Magnitude,
			describePlace(CFrame.new(oldBottom)),
			describePlace(CFrame.new(newBottom)),
			oldBottom.Y - newBottom.Y
		)
	)

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f: before")
	end)
	local changed, whyNot = pcall(function()
		mesh:ApplyMesh(source)
		mesh.TextureID = BODY_TEXTURE_ID
		truss.Size = trussPair[2].size
		truss.CFrame = trussPair[2].cframe
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f: before") and tell code_lead`
		)
	end

	-- Check the result the same way as the clone, and the head against the recorded final head.
	local afterDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(mesh)))
	if #afterDifferences > 0 or mesh.CollisionFidelity ~= Enum.CollisionFidelity.Tunable then
		error(
			"the body was changed, but the check afterwards found it differs from before in: "
				.. table.concat(afterDifferences, ", ")
				.. `; CollisionFidelity is {mesh.CollisionFidelity.Name}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2F)
	if #stillProblems > 0 then
		error(
			"the truss was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		string.format(
			"%s: CollisionFidelity PreciseConvexDecomposition -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after (size, place, turn, material, color, collision group and flags, mesh, texture, fidelities, children, attributes): only CollisionFidelity and CollisionPrecision differ",
			mesh:GetFullName(),
			oldPrecision,
			mesh.CollisionPrecision,
			if wiped then "wiped" else "did not wipe",
			mesh.TextureID,
			countValues(before)
		)
	)
	table.insert(
		lines,
		"legs_and_boots, left_arm, right_arm, head_with_beard and nightcap stay PreciseConvexDecomposition"
	)

	-- Wait until Roblox has worked out the new shape (the body's rays must have moved).
	local steady, seconds, moves = waitForShapes(pieces)
	if steady then
		table.insert(
			lines,
			string.format(
				"Roblox worked out the shape: the rays were steady after %.1f seconds of waiting; the body's largest ray move is %.2f studs",
				seconds,
				moves[BODY_PIECE]
			)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shape was not steady yet (the body's largest ray move is %.2f studs). Run the script again to wait further",
				seconds,
				moves[BODY_PIECE]
			)
		)
	end
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2f2: a closer fit (stuck safety Task 26, step 26-4b)
----------------------------------------------------------------------------------------------------------------------
-- Why: with the belly and chair on the Tunable shape (section 2f) his solid shape still sits above his drawn skin in
-- places (check 6). code_lead measured on 2026-10-21 that CollisionPrecision 1, "closest to the visual mesh" (Roblox docs,
-- TriangleMeshPart), brings it within the limits on the belly and chair piece, the head and the nightcap. Only a script
-- can set it for the same reason as in 2f: ApplyMesh takes the shape and the precision of the MeshPart it is given.
-- It knows three worlds, and changes nothing on any difference:
--   (a) the world after 2f: body_and_cushion is Tunable at 0.36 (+-0.02), head_with_beard and nightcap are
--       PreciseConvexDecomposition, legs_and_boots and both arms are PreciseConvexDecomposition, and the 43 head parts
--       (with the 30 long beard truss) are as recorded. The change is made.
--   (b) the world after 2f2: all three are Tunable at 1.0 (+-0.01). It says "already done".
--   (c) anything else (including only one or two of the three done): it stops with nothing changed and names what differs.
-- For each of the three pieces, away from the Workspace (in a WorldModel in ServerStorage that is destroyed at the end,
-- also when something fails):
--   1. AssetService:CreateMeshPartAsync(Content.fromUri(MeshId), { CollisionFidelity = Tunable, the piece's Render- and
--      FluidFidelity }), placed where the piece is, at its size.
--   2. Its rays at the named points (below) are read until steady, then CollisionPrecision is set to 1, then it waits until
--      those rays move and are steady again (up to MAX_WAIT seconds, then it stops with nothing changed).
--   3. Dry run: ApplyMesh from it onto a clone of the piece, TextureID put back. The same 28 values as in 2f are compared
--      (everything but CollisionFidelity and CollisionPrecision must be equal) and the clone must be Tunable at 1.0.
-- Only when all three dry runs are right: between two ChangeHistoryService waypoints, ApplyMesh onto the three live pieces
-- and TextureID put back, then the same check on the live pieces, then it waits until Roblox has worked out the new shapes
-- (the fixed rays of section 1 plus the named points; each changed piece's rays must have moved).
-- Named points (x, z; a ray straight down from 1 stud over the piece's recorded top; code_lead's measure of 2026-10-21 and
-- the builder's of the same day, read with the piece alone in the ray):
--   body_and_cushion: (-40, 23) and (0, -24.5), where the chair and the belly drop 0.5 to 2.5 studs.
--   head_with_beard: (-26.8, 9.3): 92.25 on the Tunable 0.36 copy, 83.82 at precision 1, 84.83 on today's live piece.
--   nightcap: (0, 4.9): 115.25 on the Tunable 0.36 copy, 114.14 at precision 1, 114.65 on today's live piece.
local CLOSER_PRECISION = 1.0
local CLOSER_PRECISION_SLACK = 0.01
local STAGING_NAME = "Task26Staging2f2"

type CloserFit = { name: string, meshId: string, textureId: string, points: { Vector2 } }
-- MeshId and TextureID as read in Studio Edit mode on 2026-10-21.
local CLOSER_FITS: { CloserFit } = {
	{
		name = BODY_PIECE,
		meshId = BODY_MESH_ID,
		textureId = BODY_TEXTURE_ID,
		points = { Vector2.new(-40, 23), Vector2.new(0, -24.5) },
	},
	{
		name = "head_with_beard",
		meshId = "rbxassetid://90514370492860",
		textureId = "rbxassetid://122798551915443",
		points = { Vector2.new(-26.8, 9.3) },
	},
	{
		name = "nightcap",
		meshId = "rbxassetid://114717524056185",
		textureId = "rbxassetid://115242442243733",
		points = { Vector2.new(0, 4.9) },
	},
}
-- The legs are PreciseConvexDecomposition until section 2f5 (Ruling 9, step 26-4f) makes them Tunable at 1.0: every
-- section after 2f2 accepts both (see stayingPieceProblem). The arms are PreciseConvexDecomposition for good.
local LEGS_PIECE = "legs_and_boots"
local SHAPE_PIECES_STAYING = { LEGS_PIECE, "left_arm", "right_arm" }

-- One ray straight down at each named point, from RAY_MARGIN over the piece's recorded top.
local function pointRays(record: Record, points: { Vector2 }): { FixedRay }
	local rays: { FixedRay } = {}
	for _, point in points do
		table.insert(rays, {
			origin = Vector3.new(point.X, record.position.Y + record.size.Y / 2 + RAY_MARGIN, point.Y),
			direction = Vector3.new(0, -(record.size.Y + 2 * RAY_MARGIN), 0),
		})
	end
	return rays
end

-- The height a ray's hit is at (its origin's height minus the distance read), or nil for a miss.
local function hitHeight(ray: FixedRay, distance: number): number?
	if distance < 0 then
		return nil
	end
	return ray.origin.Y - distance
end

local function pointsText(points: { Vector2 }): string
	local texts: { string } = {}
	for _, point in points do
		table.insert(texts, `({point.X}, {point.Y})`)
	end
	return table.concat(texts, " and ")
end

local function heightText(height: number?): string
	return if height == nil then "no hit" else string.format("%.2f", height)
end

-- Reads the staging copy's rays every READ_EVERY seconds until two reads in a row agree (and, when `baseline` is given,
-- until some ray has also moved more than MOVED_AT_LEAST away from it). Returns whether that happened, the seconds it
-- took, the largest move from the baseline, and the last read.
local function waitForSourceShape(
	world: WorldRoot,
	source: MeshPart,
	rays: { FixedRay },
	baseline: { number }?
): (boolean, number, number, { number })
	local started = os.clock()
	local previous = readRays(source, rays, world)
	local moved = 0
	while os.clock() - started < MAX_WAIT do
		task.wait(READ_EVERY)
		local current = readRays(source, rays, world)
		local agrees = largestDifference(previous, current) <= AGREE_WITHIN
		moved = if baseline == nil then 0 else largestDifference(baseline, current)
		previous = current
		if agrees and (baseline == nil or moved > MOVED_AT_LEAST) then
			return true, os.clock() - started, moved, current
		end
	end
	return false, os.clock() - started, moved, previous
end

local function isTunableAt(mesh: MeshPart, precision: number, slack: number): boolean
	return mesh.CollisionFidelity == Enum.CollisionFidelity.Tunable
		and math.abs(mesh.CollisionPrecision - precision) <= slack
end

-- The problem with one of the pieces in SHAPE_PIECES_STAYING, or nil when it is fine: PreciseConvexDecomposition, or for
-- the legs also Tunable at 1.0 (the world after section 2f5).
local function stayingPieceProblem(name: string, mesh: MeshPart): string?
	if mesh.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition then
		return nil
	end
	if name == LEGS_PIECE and isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		return nil
	end
	return `{name}: CollisionFidelity is {mesh.CollisionFidelity.Name} at CollisionPrecision {string.format(
		"%.3f",
		mesh.CollisionPrecision
	)}, expected PreciseConvexDecomposition{if name == LEGS_PIECE then " or Tunable at 1.0 (after section 2f5)" else ""}`
end

type Prepared = {
	fit: CloserFit,
	piece: Piece,
	source: MeshPart,
	before: { [string]: any },
	oldFidelity: string,
	oldPrecision: number,
	wiped: boolean,
	sourceMove: number,
	sourceSeconds: number,
	firstPointRay: number,
}

-- The dry runs, then the change, then the wait. Everything it makes lives in `staging`, which the caller destroys.
local function changeToCloserFit(
	staging: WorldModel,
	pieces: { Piece },
	byName: { [string]: Piece },
	walk: Instance
): string
	local lines: { string } = {}
	local prepared: { Prepared } = {}
	for _, fit in CLOSER_FITS do
		local piece = byName[fit.name]
		local mesh = piece.mesh
		local made, madeOrWhy = pcall(function(): MeshPart
			return AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
				CollisionFidelity = Enum.CollisionFidelity.Tunable,
				RenderFidelity = mesh.RenderFidelity,
				FluidFidelity = mesh.FluidFidelity,
			})
		end)
		if not made then
			error(`nothing was changed. CreateMeshPartAsync failed for {fit.name}: {tostring(madeOrWhy)}`)
		end
		local source = madeOrWhy :: MeshPart
		source.Anchored = true
		source.Size = mesh.Size
		source.CFrame = mesh.CFrame
		source.Parent = staging

		local rays = pointRays(RECORDS[fit.name], fit.points)
		local baselineSteady, _, _, baseline = waitForSourceShape(staging, source, rays, nil)
		if not baselineSteady then
			error(
				`nothing was changed. The copy of {fit.name} never settled at its first precision within {MAX_WAIT} seconds`
			)
		end
		(source :: any).CollisionPrecision = CLOSER_PRECISION
		local moved, seconds, movedBy = waitForSourceShape(staging, source, rays, baseline)
		if not moved then
			error(
				string.format(
					"nothing was changed. The copy of %s did not change its shape within %d seconds of CollisionPrecision 1 (largest ray move %.3f studs)",
					fit.name,
					MAX_WAIT,
					movedBy
				)
			)
		end

		-- Dry run on a clone.
		local trial = mesh:Clone()
		trial.Parent = staging
		local wiped = false
		local trialOk, trialWhy = pcall(function()
			trial:ApplyMesh(source)
			wiped = trial.TextureID ~= fit.textureId
			trial.TextureID = fit.textureId
		end)
		if not trialOk then
			error(`nothing was changed. ApplyMesh failed on the clone of {fit.name}: {tostring(trialWhy)}`)
		end
		local before = bodySnapshot(mesh)
		local trialDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(trial)))
		if #trialDifferences > 0 then
			error(
				`nothing was changed. ApplyMesh on the clone of {fit.name} changed more than the collision: {table.concat(
					trialDifferences,
					", "
				)}`
			)
		end
		if not isTunableAt(trial, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			error(
				string.format(
					"nothing was changed. The clone of %s is %s at CollisionPrecision %.3f, expected Tunable at 1.0",
					fit.name,
					trial.CollisionFidelity.Name,
					trial.CollisionPrecision
				)
			)
		end
		trial:Destroy()
		table.insert(prepared, {
			fit = fit,
			piece = piece,
			source = source,
			before = before,
			oldFidelity = mesh.CollisionFidelity.Name,
			oldPrecision = mesh.CollisionPrecision,
			wiped = wiped,
			sourceMove = movedBy,
			sourceSeconds = seconds,
			firstPointRay = 0,
		})
	end

	-- The rays read before the change: section 1's fixed rays and the named points, on all six pieces.
	for _, item in prepared do
		item.piece.changing = true
		item.firstPointRay = #item.piece.rays + 1
		for _, ray in pointRays(RECORDS[item.fit.name], item.fit.points) do
			table.insert(item.piece.rays, ray)
		end
	end
	for _, piece in pieces do
		piece.before = readRays(piece.mesh, piece.rays)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f2: before")
	end)
	local changed, whyNot = pcall(function()
		for _, item in prepared do
			item.piece.mesh:ApplyMesh(item.source)
			item.piece.mesh.TextureID = item.fit.textureId
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f2: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f2: before") and tell code_lead`
		)
	end

	-- The same check on the live pieces, and what must not have moved.
	for _, item in prepared do
		local mesh = item.piece.mesh
		local differences = unexpectedDifferences(bodyDifferences(item.before, bodySnapshot(mesh)))
		if #differences > 0 or not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			error(
				string.format(
					"%s was changed, but the check afterwards found it is %s at CollisionPrecision %.3f and differs from before in: %s. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead",
					item.fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision,
					table.concat(differences, ", ")
				)
			)
		end
		table.insert(
			lines,
			string.format(
				"%s: CollisionFidelity %s -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after: only CollisionFidelity and CollisionPrecision differ. The staging copy's ray at %s moved %.2f studs after CollisionPrecision 1 (steady after %.1f seconds)",
				mesh:GetFullName(),
				item.oldFidelity,
				item.oldPrecision,
				mesh.CollisionPrecision,
				if item.wiped then "wiped" else "did not wipe",
				mesh.TextureID,
				countValues(item.before),
				pointsText(item.fit.points),
				item.sourceMove,
				item.sourceSeconds
			)
		)
	end
	local stillProblems = headProblemsEitherSlot(walk)
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(stillProblems, stayingProblem)
		end
	end
	if #stillProblems > 0 then
		error(
			"the pieces were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(lines, "legs_and_boots, left_arm and right_arm stay PreciseConvexDecomposition")

	-- Wait until Roblox has worked out the new shapes: every changed piece's rays must have moved.
	local steady, seconds, moves = waitForShapes(pieces)
	for _, item in prepared do
		local name = item.fit.name
		local now = readRays(item.piece.mesh, item.piece.rays)
		for offset, point in item.fit.points do
			local index = item.firstPointRay + offset - 1
			local ray = item.piece.rays[index]
			table.insert(
				lines,
				`{name} at ({point.X}, {point.Y}): the live piece's top was {heightText(
					hitHeight(ray, item.piece.before[index])
				)}, is {heightText(hitHeight(ray, now[index]))}`
			)
		end
		table.insert(lines, string.format("%s: largest ray move from before the change %.2f studs", name, moves[name]))
	end
	if steady then
		table.insert(
			lines,
			string.format("Roblox worked out the shapes: the rays were steady after %.1f seconds of waiting", seconds)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shapes were not steady yet, or a changed piece's rays did not move. Run the script again to wait further, and if it is the same, STOP and tell code_lead",
				seconds
			)
		)
	end
	return table.concat(lines, "\n")
end

local function sectionCloserFit(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local byName: { [string]: Piece } = {}
	for _, piece in pieces do
		byName[piece.name] = piece
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	-- What never changes: each mesh and texture as recorded, the three staying pieces, the head parts and the 30 long truss.
	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if mesh.MeshId ~= fit.meshId then
			table.insert(problems, `{fit.name}: MeshId is {mesh.MeshId}, recorded {fit.meshId}`)
		end
		if mesh.TextureID ~= fit.textureId then
			table.insert(problems, `{fit.name}: TextureID is {mesh.TextureID}, recorded {fit.textureId}`)
		end
	end
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(problems, stayingProblem)
		end
	end
	for _, problem in headProblemsEitherSlot(walk) do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	-- Which world is it?
	local done: { string } = {}
	local notDone: { string } = {}
	local unknown: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		local isBefore = if fit.name == BODY_PIECE
			then isTunableAt(mesh, BODY_TUNABLE_PRECISION, BODY_PRECISION_SLACK)
			else mesh.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition
		if isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(done, fit.name)
		elseif isBefore then
			table.insert(notDone, fit.name)
		else
			table.insert(
				unknown,
				string.format(
					"%s is %s at CollisionPrecision %.3f",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	if #unknown > 0 or (#done > 0 and #notDone > 0) then
		error(
			`nothing was changed. His body pieces are neither the world after section 2f nor the world after 2f2 (done: {table.concat(
				done,
				", "
			)}; not done: {table.concat(notDone, ", ")}; unknown: {table.concat(unknown, "; ")})`
		)
	end
	if #done == #CLOSER_FITS then
		return string.format(
			"already done: %s are Tunable at CollisionPrecision %.2f, with their mesh and texture as recorded, left_arm and right_arm are PreciseConvexDecomposition (so is legs_and_boots, until section 2f5 makes it Tunable at 1.0), and the head parts (%d recorded, with the 30 long beard truss, or 32 after section 2f4) are as recorded",
			table.concat(done, ", "),
			CLOSER_PRECISION,
			#FINAL_HEAD_PARTS_2F
		)
	end

	-- The staging WorldModel: a leftover from a stopped run goes first, and it is destroyed whatever happens.
	local leftover = ServerStorage:FindFirstChild(STAGING_NAME)
	if leftover ~= nil then
		leftover:Destroy()
	end
	local staging = Instance.new("WorldModel")
	staging.Name = STAGING_NAME
	staging.Archivable = false
	staging.Parent = ServerStorage
	local ok, result = pcall(changeToCloserFit, staging, pieces, byName, walk)
	staging:Destroy()
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

-- Section 2f3: the slot blocks reach his closer skin (stuck safety Task 26, step 26-4d2, Ruling 7)
-- Why: with his head at CollisionPrecision 1 (section 2f2), a thin 69 degree band of forehead in front of the two
-- LadderSlotBlocks has room for a body (5 spots on his left). Each block grows forward and down to fill it. They are
-- invisible and fill a slot nobody should stand in.
-- What it does:
--   - It refuses to run in Play.
--   - It checks everything first and changes nothing on any difference:
--       the 3 closer-fit pieces are Tunable at CollisionPrecision 1, legs and arms are PreciseConvexDecomposition (the
--       legs may also be Tunable at 1.0 once section 2f5 has run), and
--       the head is either the recorded one with both blocks 1 x 12 x 4 at (+-3.2, 102.5, 1.0) (before: the change is
--       made) or the recorded one with both blocks 1 x 17 x 6 at (+-3.2, 100.0, 0.0) (after: "already done").
--   - Before the change, for each new block: the front face is between z -3.25 and -2.75, and every bottom edge is at
--     least 0.5 studs inside his skin (the top of head_with_beard, measured straight down from the block's top at
--     every 0.1 studs across and 0.25 studs along each edge).
--   - It sets Size and CFrame of the two blocks and nothing else (it compares every other value before and after), with
--     waypoints before and after, and checks the head again.
--   - It prints before and after for each block.
local SLOT_FRONT_Z_FROM = -3.25
local SLOT_FRONT_Z_TO = -2.75
local SLOT_BOTTOM_INSIDE = 0.5
local SLOT_EDGE_STEP_X = 0.1
local SLOT_EDGE_STEP_Z = 0.25
local SLOT_SKIN_PIECE = "head_with_beard"
local SLOT_MAY_DIFFER: { [string]: boolean } = { Size = true, CFrame = true }
local SLOT_COMPARED: { string } = {
	"Name",
	"Archivable",
	"Size",
	"CFrame",
	"Shape",
	"Material",
	"Color",
	"Transparency",
	"Reflectance",
	"CastShadow",
	"Anchored",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"CollisionGroup",
	"Massless",
	"Locked",
	"CustomPhysicalProperties",
	"Parent",
	"ChildCount",
	"AttributeCount",
}

local function slotBlockSnapshot(block: BasePart): { [string]: any }
	local values: { [string]: any } = {}
	for _, name in SLOT_COMPARED do
		local readable, value = pcall(function(): any
			return (block :: any)[name]
		end)
		if readable then
			values[name] = value
		end
	end
	values.ChildCount = #block:GetChildren()
	local attributes = 0
	for _ in block:GetAttributes() do
		attributes += 1
	end
	values.AttributeCount = attributes
	return values
end

local function slotBlockDifferences(first: { [string]: any }, second: { [string]: any }): { string }
	local names: { string } = {}
	for _, name in SLOT_COMPARED do
		if first[name] ~= second[name] then
			table.insert(names, name)
		end
	end
	return names
end

-- How far the skin of head_with_beard is above the block's bottom, at the worst point of the bottom face's four edges:
-- (the depth, where). Measured straight down from the block's top face. No skin under a point counts as -infinity.
local function slotBottomDepth(head: MeshPart, wide: HeadPart): (number, string)
	local centre, size = wide.cframe.Position, wide.size
	local topY, bottomY = centre.Y + size.Y / 2, centre.Y - size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { head }
	params.RespectCanCollide = false
	local worst, worstAt = math.huge, "nowhere"
	local function measure(x: number, z: number)
		local hit = Workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -(size.Y + 20), 0), params)
		local depth = if hit == nil then -math.huge else hit.Position.Y - bottomY
		if depth < worst then
			worst, worstAt = depth, string.format("x %.2f, z %.2f", x, z)
		end
	end
	local stepsX = math.round(size.X / SLOT_EDGE_STEP_X)
	local stepsZ = math.round(size.Z / SLOT_EDGE_STEP_Z)
	for index = 0, stepsX do
		local x = centre.X - size.X / 2 + size.X * index / stepsX
		measure(x, centre.Z - size.Z / 2)
		measure(x, centre.Z + size.Z / 2)
	end
	for index = 0, stepsZ do
		local z = centre.Z - size.Z / 2 + size.Z * index / stepsZ
		measure(centre.X - size.X / 2, z)
		measure(centre.X + size.X / 2, z)
	end
	return worst, worstAt
end

local function sectionSlotBlocks(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local byName: { [string]: Piece } = {}
	for _, piece in pieces do
		byName[piece.name] = piece
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local guardBox = walk:FindFirstChild("ForeheadGuard")
	if guardBox == nil then
		error("World.WalkSurfaces.ForeheadGuard is missing")
	end

	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(
				problems,
				string.format(
					"%s is %s at CollisionPrecision %.3f, expected Tunable at 1.0 (section 2f2)",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(problems, stayingProblem)
		end
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2G)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2H) == 0 then
		afterProblems = {} -- the world after section 2f4: the same blocks, with the 32 long truss and the shorter part B
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterProblems = {} -- the world after section 2f6: the same, with the truss's foot swung back
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the same, with the longer beard rails and the extra rung
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: both %s are 1 x 17 x 6 at (+-3.2, 100.0, 0.0) and the head parts (%d recorded) are as recorded",
			SLOT_BLOCK_NAME,
			#FINAL_HEAD_PARTS_2G
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2F)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2f3 ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live blocks, and the checks on what they would become.
	local head = byName[SLOT_SKIN_PIECE].mesh
	local live: { Part } = {}
	local lines: { string } = {}
	for _, pair in SLOT_BLOCK_BEFORE_AFTER do
		local found: Part? = nil
		for _, child in guardBox:GetChildren() do
			if child.Name == SLOT_BLOCK_NAME and child:IsA("Part") and sameAs(child, pair[1].size, pair[1].cframe) then
				if not table.find(live, child) then
					found = child
					break
				end
			end
		end
		if found == nil then
			error(`nothing was changed. No {SLOT_BLOCK_NAME} at {describePlace(pair[1].cframe)} to make bigger`)
		end
		table.insert(live, found)
		local wide = pair[2]
		local frontZ = wide.cframe.Z - wide.size.Z / 2
		if frontZ < SLOT_FRONT_Z_FROM or frontZ > SLOT_FRONT_Z_TO then
			error(`nothing was changed. The front face of the block at x {wide.cframe.X} would be at z {frontZ}`)
		end
		local depth, where = slotBottomDepth(head, wide)
		table.insert(
			lines,
			string.format(
				"block at x %+.1f: front face z %.2f -> %.2f; bottom y %.2f -> %.2f; its bottom edges sit at least %.2f studs inside his skin (worst at %s)",
				wide.cframe.X,
				pair[1].cframe.Z - pair[1].size.Z / 2,
				frontZ,
				pair[1].cframe.Y - pair[1].size.Y / 2,
				wide.cframe.Y - wide.size.Y / 2,
				depth,
				where
			)
		)
		if depth < SLOT_BOTTOM_INSIDE then
			error(
				string.format(
					"nothing was changed. The bottom edge of the block at x %+.1f would be only %.2f studs inside his skin (worst at %s), needs %.1f",
					wide.cframe.X,
					depth,
					where,
					SLOT_BOTTOM_INSIDE
				)
			)
		end
	end

	local before: { { [string]: any } } = {}
	for _, block in live do
		table.insert(before, slotBlockSnapshot(block))
		local old = block
		table.insert(
			lines,
			string.format(
				"before: %s x %+.1f is %.1f x %.1f x %.1f at %s",
				SLOT_BLOCK_NAME,
				old.Position.X,
				old.Size.X,
				old.Size.Y,
				old.Size.Z,
				describePlace(old.CFrame)
			)
		)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f3: before")
	end)
	local changed, whyNot = pcall(function()
		for index, block in live do
			local wide = SLOT_BLOCK_BEFORE_AFTER[index][2]
			block.Size = wide.size
			block.CFrame = wide.cframe
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f3: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f3: before") and tell code_lead`
		)
	end
	for index, block in live do
		local unexpected: { string } = {}
		for _, name in slotBlockDifferences(before[index], slotBlockSnapshot(block)) do
			if not SLOT_MAY_DIFFER[name] then
				table.insert(unexpected, name)
			end
		end
		if #unexpected > 0 then
			error(
				"a block was changed, but the check afterwards found it differs from before in: "
					.. table.concat(unexpected, ", ")
					.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
			)
		end
		table.insert(
			lines,
			string.format(
				"after: %s x %+.1f is %.1f x %.1f x %.1f at %s; %d values compared before and after: only Size and CFrame differ",
				SLOT_BLOCK_NAME,
				block.Position.X,
				block.Size.X,
				block.Size.Y,
				block.Size.Z,
				describePlace(block.CFrame),
				countValues(before[index])
			)
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2G)
	if #stillProblems > 0 then
		error(
			"the blocks were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		`ForeheadGuard now holds {#guardBox:GetChildren()} children ({countParts(FINAL_HEAD_PARTS_2G, "ForeheadGuard")} recorded head parts)`
	)
	return table.concat(lines, "\n")
end

-- Section 2f4: the beard truss 32 long and the cap rails' part B ends sooner (stuck safety Task 26, step 26-4d4, Ruling 8)
-- Why: after the closer fit (section 2f2) his belly under the beard ladder is 0.36 lower, so the walk check no longer
-- joined the ladder's foot to his belly (the nearest spot was 4.23 away, a climb link reaches 4.0). And part B of the rails
-- walled the cap ladder's top into a lane two grid columns wide, straight into the drawn lip at the back of the brim, so
-- no walk reached the brim's nest points. Both changes are invisible.
-- What it does:
--   - It refuses to run in Play.
--   - It checks everything first and changes nothing on any difference: the 3 closer-fit pieces are Tunable at
--     CollisionPrecision 1, legs and arms are PreciseConvexDecomposition (the legs may also be Tunable at 1.0 once section
--     2f5 has run), and the head is either section 2f3's (before:
--     truss 2 x 2 x 30, both part B SideRails 2 x 34 x 13.4 ending at z 6.0; the change is made) or the final one
--     (after: truss 2 x 2 x 32, part B 2 x 34 x 9.9 ending at z 2.5: "already done").
--   - Before the change, for each part: the truss's top end stays within 0.05 and its bottom end moves 2.0 down the same
--     line; each part B keeps its front end (z -7.4) and its back end ends between z 2.1 and 3.0.
--   - It sets Size and CFrame of the 3 parts and nothing else (it compares every other value before and after), with
--     waypoints before and after, and checks the head again.
--   - It prints before and after for each part.
local HEAD_CHANGE_COMPARED: { string } = table.clone(SLOT_COMPARED)
table.insert(HEAD_CHANGE_COMPARED, "Style") -- a truss's own look; nil on a Part

local function headPartSnapshot(part: BasePart): { [string]: any }
	local values = slotBlockSnapshot(part)
	local readable, style = pcall(function(): any
		return (part :: any).Style
	end)
	if readable then
		values.Style = style
	end
	return values
end

local function headPartDifferences(first: { [string]: any }, second: { [string]: any }): { string }
	local names: { string } = {}
	for _, name in HEAD_CHANGE_COMPARED do
		if first[name] ~= second[name] then
			table.insert(names, name)
		end
	end
	return names
end

-- The live part for a recorded head part (not one already taken), or nil.
local function liveHeadPart(walk: Instance, record: HeadPart, taken: { BasePart }): BasePart?
	local box = walk:FindFirstChild(record.parent)
	if box == nil then
		return nil
	end
	for _, child in box:GetChildren() do
		if
			child.Name == record.name
			and child:IsA("BasePart")
			and not table.find(taken, child)
			and sameAs(child, record.size, record.cframe)
		then
			return child
		end
	end
	return nil
end

-- One line about a head part: its size and place, and for a truss its foot, for a rail its front and back ends (z).
local function headPartText(size: Vector3, cframe: CFrame, isTruss: boolean): string
	local text = string.format("%.2f x %.2f x %.2f at %s", size.X, size.Y, size.Z, describePlace(cframe))
	if isTruss then
		local top, foot = trussEnds(size, cframe)
		return text .. `; top end {describePlace(CFrame.new(top))}, foot {describePlace(CFrame.new(foot))}`
	end
	return text .. string.format("; z from %.2f to %.2f", cframe.Z - size.Z / 2, cframe.Z + size.Z / 2)
end

local function sectionTrussAndPartB(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local byName: { [string]: Piece } = {}
	for _, piece in pieces do
		byName[piece.name] = piece
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(
				problems,
				string.format(
					"%s is %s at CollisionPrecision %.3f, expected Tunable at 1.0 (section 2f2)",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(problems, stayingProblem)
		end
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		afterProblems = {} -- the world after section 2f6: the same, with the truss's foot swung back
	end
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the same, with the longer beard rails and the extra rung
	end
	if #afterProblems == 0 then
		return string.format(
			"already done: the beard truss is 2 x 2 x 32 and both part B SideRails end at z %.1f (%d recorded head parts)",
			PART_B_BACK_AFTER,
			#FINAL_HEAD_PARTS_2H
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2G)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f3 ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2f4 ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live parts, and the numbers that must hold for what they would become.
	local live: { BasePart } = {}
	local lines: { string } = {}
	for _, pair in HEAD_CHANGES_2F4 do
		local old, new = pair[1], pair[2]
		local found = liveHeadPart(walk, old, live)
		if found == nil then
			error(`nothing was changed. No {old.parent}.{old.name} at {describePlace(old.cframe)} to change`)
		end
		table.insert(live, found)
		if
			old.cframe.LookVector:Dot(new.cframe.LookVector) < 0.99999
			or old.cframe.UpVector:Dot(new.cframe.UpVector) < 0.99999
		then
			error(`nothing was changed. The new {old.parent}.{old.name} would be turned differently`)
		end
		if old.name == "Climb" then
			local oldTop, oldFoot = trussEnds(old.size, old.cframe)
			local newTop, newFoot = trussEnds(new.size, new.cframe)
			if (oldTop - newTop).Magnitude > TRUSS_LONGER_TOP_SLACK then
				error(
					`nothing was changed. The longer truss would move its top end by {(oldTop - newTop).Magnitude} studs`
				)
			end
			if math.abs((oldFoot - newFoot).Magnitude - TRUSS_LONGER_EXTRA) > 0.01 or newFoot.Y >= oldFoot.Y then
				error("nothing was changed. The longer truss's foot is not 2.0 studs further down the same line")
			end
		else
			local oldFront, oldBack = old.cframe.Z - old.size.Z / 2, old.cframe.Z + old.size.Z / 2
			local newFront, newBack = new.cframe.Z - new.size.Z / 2, new.cframe.Z + new.size.Z / 2
			if math.abs(oldFront - newFront) > 0.01 then
				error(
					`nothing was changed. The shorter part B at x {new.cframe.X} would move its front end to z {newFront}`
				)
			end
			if
				math.abs(oldBack - PART_B_BACK_BEFORE) > 0.01
				or newBack < PART_B_BACK_MIN
				or newBack > PART_B_BACK_MAX
			then
				error(
					`nothing was changed. Part B at x {new.cframe.X} would end at z {newBack} (now {oldBack}), needs {PART_B_BACK_MIN} to {PART_B_BACK_MAX}`
				)
			end
			if
				math.abs(old.cframe.X - new.cframe.X) > 0.001
				or math.abs(old.cframe.Y - new.cframe.Y) > 0.001
				or math.abs(old.size.X - new.size.X) > 0.001
				or math.abs(old.size.Y - new.size.Y) > 0.001
			then
				error(`nothing was changed. Part B at x {new.cframe.X} would change in more than its length`)
			end
		end
		table.insert(lines, `before: {old.parent}.{old.name} {headPartText(old.size, old.cframe, old.name == "Climb")}`)
	end

	local before: { { [string]: any } } = {}
	for _, part in live do
		table.insert(before, headPartSnapshot(part))
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f4: before")
	end)
	local changed, whyNot = pcall(function()
		for index, part in live do
			local new = HEAD_CHANGES_2F4[index][2]
			part.Size = new.size
			part.CFrame = new.cframe
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f4: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f4: before") and tell code_lead`
		)
	end
	for index, part in live do
		local unexpected: { string } = {}
		for _, name in headPartDifferences(before[index], headPartSnapshot(part)) do
			if not SLOT_MAY_DIFFER[name] then
				table.insert(unexpected, name)
			end
		end
		if #unexpected > 0 then
			error(
				"a part was changed, but the check afterwards found it differs from before in: "
					.. table.concat(unexpected, ", ")
					.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
			)
		end
		local pair = HEAD_CHANGES_2F4[index]
		table.insert(
			lines,
			`after: {pair[1].parent}.{pair[1].name} {headPartText(part.Size, part.CFrame, pair[1].name == "Climb")}; {countValues(
				before[index]
			)} values compared before and after: only Size and CFrame differ`
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #stillProblems > 0 then
		error(
			"the parts were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		`ForeheadGuard holds {#(walk:FindFirstChild("ForeheadGuard") :: Instance):GetChildren()} children ({countParts(
			FINAL_HEAD_PARTS_2H,
			"ForeheadGuard"
		)} recorded head parts), BeardLadder {#(walk:FindFirstChild("BeardLadder") :: Instance):GetChildren()} ({countParts(
			FINAL_HEAD_PARTS_2H,
			"BeardLadder"
		)} recorded)`
	)
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2f5: the legs' closer fit (stuck safety Task 26, step 26-4f, Ruling 9)
----------------------------------------------------------------------------------------------------------------------
-- Why: after the closer fit on his belly, head and nightcap (section 2f2) one spot on his right knee is still too far over
-- his drawn skin (check 6: +0.33 at (24.5, 27.7, -40.5)). code_lead measured on 2026-10-21 that legs_and_boots made with
-- AssetService:CreateMeshPartAsync as Tunable at CollisionPrecision 1 has no such spot, and the ray at (24.5, -40.5) goes
-- from 27.66 to 27.34. It is built like section 2f2, for one piece. It knows three worlds, and changes nothing on any
-- difference:
--   (a) before: legs_and_boots is PreciseConvexDecomposition; the belly, head and nightcap are Tunable at 1.0 (+-0.01); both
--       arms are PreciseConvexDecomposition; the head parts are the final ones of section 2f4 (truss 32 long). The change
--       is made.
--   (b) after: legs_and_boots is Tunable at 1.0 (+-0.01) with the same other pieces and head. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- The change: away from the Workspace (a WorldModel in ServerStorage, destroyed at the end whatever happens) it makes the
-- legs with CreateMeshPartAsync (Tunable, the piece's Render- and FluidFidelity) at the piece's size and place, reads the
-- ray at the named point (24.5, -40.5) until steady, sets CollisionPrecision 1 and waits until that ray moves and is
-- steady again (up to MAX_WAIT seconds, then it stops with nothing changed). Dry run: ApplyMesh onto a clone, TextureID put
-- back, the same 28 values as in 2f2 compared (only CollisionFidelity and CollisionPrecision may differ), the clone must be
-- Tunable at 1.0. Only then, between two ChangeHistoryService waypoints: ApplyMesh onto the live legs, TextureID put back,
-- the same check on the live piece, and a wait until Roblox has worked out the new shape (the fixed rays of section 1 plus
-- the named point; the legs' rays must have moved).
local LEGS_STAGING_NAME = "Task26Staging2f5"
-- MeshId and TextureID as read in Studio Edit mode on 2026-10-21.
local LEGS_FIT: CloserFit = {
	name = LEGS_PIECE,
	meshId = "rbxassetid://119193072671044",
	textureId = "rbxassetid://86759773050605",
	points = { Vector2.new(24.5, -40.5) },
}
local ARM_PIECES = { "left_arm", "right_arm" }

-- Everything section 2f5 needs to be true about the rest of his body, before and after: the belly, head and nightcap
-- Tunable at 1.0, the arms PreciseConvexDecomposition, the head parts final (section 2f4).
local function restOfHisBodyProblems(byName: { [string]: Piece }, walk: Instance): { string }
	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(
				problems,
				string.format(
					"%s is %s at CollisionPrecision %.3f, expected Tunable at 1.0 (section 2f2)",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	for _, name in ARM_PIECES do
		local armProblem = stayingPieceProblem(name, byName[name].mesh)
		if armProblem ~= nil then
			table.insert(problems, armProblem)
		end
	end
	local headFindings = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #headFindings > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		headFindings = {} -- section 2f6 has run: the same head with the truss's foot swung back
	end
	if #headFindings > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		headFindings = {} -- section 2g has run: the same head with the longer beard rails and the extra rung
	end
	for _, problem in headFindings do
		table.insert(problems, problem)
	end
	return problems
end

-- The dry run, then the change, then the wait. Everything it makes lives in `staging`, which the caller destroys.
local function changeLegsToCloserFit(
	staging: WorldModel,
	pieces: { Piece },
	byName: { [string]: Piece },
	walk: Instance
): string
	local lines: { string } = {}
	local piece = byName[LEGS_PIECE]
	local mesh = piece.mesh
	local made, madeOrWhy = pcall(function(): MeshPart
		return AssetService:CreateMeshPartAsync(Content.fromUri(mesh.MeshId), {
			CollisionFidelity = Enum.CollisionFidelity.Tunable,
			RenderFidelity = mesh.RenderFidelity,
			FluidFidelity = mesh.FluidFidelity,
		})
	end)
	if not made then
		error(`nothing was changed. CreateMeshPartAsync failed for {LEGS_PIECE}: {tostring(madeOrWhy)}`)
	end
	local source = madeOrWhy :: MeshPart
	source.Anchored = true
	source.Size = mesh.Size
	source.CFrame = mesh.CFrame
	source.Parent = staging

	local rays = pointRays(RECORDS[LEGS_PIECE], LEGS_FIT.points)
	local baselineSteady, _, _, baseline = waitForSourceShape(staging, source, rays, nil)
	if not baselineSteady then
		error(
			`nothing was changed. The copy of {LEGS_PIECE} never settled at its first precision within {MAX_WAIT} seconds`
		)
	end
	(source :: any).CollisionPrecision = CLOSER_PRECISION
	local moved, sourceSeconds, sourceMove = waitForSourceShape(staging, source, rays, baseline)
	if not moved then
		error(
			string.format(
				"nothing was changed. The copy of %s did not change its shape within %d seconds of CollisionPrecision 1 (largest ray move %.3f studs)",
				LEGS_PIECE,
				MAX_WAIT,
				sourceMove
			)
		)
	end

	-- Dry run on a clone.
	local trial = mesh:Clone()
	trial.Parent = staging
	local wiped = false
	local trialOk, trialWhy = pcall(function()
		trial:ApplyMesh(source)
		wiped = trial.TextureID ~= LEGS_FIT.textureId
		trial.TextureID = LEGS_FIT.textureId
	end)
	if not trialOk then
		error(`nothing was changed. ApplyMesh failed on the clone of {LEGS_PIECE}: {tostring(trialWhy)}`)
	end
	local before = bodySnapshot(mesh)
	local trialDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(trial)))
	if #trialDifferences > 0 then
		error(
			`nothing was changed. ApplyMesh on the clone of {LEGS_PIECE} changed more than the collision: {table.concat(
				trialDifferences,
				", "
			)}`
		)
	end
	if not isTunableAt(trial, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		error(
			string.format(
				"nothing was changed. The clone of %s is %s at CollisionPrecision %.3f, expected Tunable at 1.0",
				LEGS_PIECE,
				trial.CollisionFidelity.Name,
				trial.CollisionPrecision
			)
		)
	end
	trial:Destroy()
	local oldFidelity = mesh.CollisionFidelity.Name
	local oldPrecision = mesh.CollisionPrecision

	-- The rays read before the change: section 1's fixed rays and the named point, on all six pieces.
	piece.changing = true
	local firstPointRay = #piece.rays + 1
	for _, ray in pointRays(RECORDS[LEGS_PIECE], LEGS_FIT.points) do
		table.insert(piece.rays, ray)
	end
	for _, each in pieces do
		each.before = readRays(each.mesh, each.rays)
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f5: before")
	end)
	local changed, whyNot = pcall(function()
		mesh:ApplyMesh(source)
		mesh.TextureID = LEGS_FIT.textureId
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f5: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f5: before") and tell code_lead`
		)
	end

	-- The same check on the live piece, and what must not have moved.
	local differences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(mesh)))
	if #differences > 0 or not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		error(
			string.format(
				"%s was changed, but the check afterwards found it is %s at CollisionPrecision %.3f and differs from before in: %s. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead",
				LEGS_PIECE,
				mesh.CollisionFidelity.Name,
				mesh.CollisionPrecision,
				table.concat(differences, ", ")
			)
		)
	end
	table.insert(
		lines,
		string.format(
			"%s: CollisionFidelity %s -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after: only CollisionFidelity and CollisionPrecision differ. The staging copy's ray at %s moved %.2f studs after CollisionPrecision 1 (steady after %.1f seconds)",
			mesh:GetFullName(),
			oldFidelity,
			oldPrecision,
			mesh.CollisionPrecision,
			if wiped then "wiped" else "did not wipe",
			mesh.TextureID,
			countValues(before),
			pointsText(LEGS_FIT.points),
			sourceMove,
			sourceSeconds
		)
	)
	local stillProblems = restOfHisBodyProblems(byName, walk)
	if #stillProblems > 0 then
		error(
			"the legs were changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		"the belly, head and nightcap stay Tunable at 1.0, left_arm and right_arm stay PreciseConvexDecomposition, the head parts are as recorded"
	)

	-- Wait until Roblox has worked out the new shape: the legs' rays must have moved.
	local steady, seconds, moves = waitForShapes(pieces)
	local now = readRays(mesh, piece.rays)
	for offset, point in LEGS_FIT.points do
		local index = firstPointRay + offset - 1
		local ray = piece.rays[index]
		table.insert(
			lines,
			`{LEGS_PIECE} at ({point.X}, {point.Y}): the live piece's top was {heightText(
				hitHeight(ray, piece.before[index])
			)}, is {heightText(hitHeight(ray, now[index]))}`
		)
	end
	table.insert(
		lines,
		string.format("%s: largest ray move from before the change %.2f studs", LEGS_PIECE, moves[LEGS_PIECE])
	)
	if steady then
		table.insert(
			lines,
			string.format("Roblox worked out the shape: the rays were steady after %.1f seconds of waiting", seconds)
		)
	else
		table.insert(
			lines,
			string.format(
				"TIMED OUT after %.0f seconds: the shape was not steady yet, or the legs' rays did not move. Run the script again to wait further, and if it is the same, STOP and tell code_lead",
				seconds
			)
		)
	end
	return table.concat(lines, "\n")
end

local function sectionLegsCloserFit(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local byName: { [string]: Piece } = {}
	for _, piece in pieces do
		byName[piece.name] = piece
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	-- What never changes: the legs' mesh and texture as recorded, and the rest of his body as after sections 2f2 to 2f4.
	local legs = byName[LEGS_PIECE].mesh
	local problems: { string } = {}
	if legs.MeshId ~= LEGS_FIT.meshId then
		table.insert(problems, `{LEGS_PIECE}: MeshId is {legs.MeshId}, recorded {LEGS_FIT.meshId}`)
	end
	if legs.TextureID ~= LEGS_FIT.textureId then
		table.insert(problems, `{LEGS_PIECE}: TextureID is {legs.TextureID}, recorded {LEGS_FIT.textureId}`)
	end
	for _, problem in restOfHisBodyProblems(byName, walk) do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	-- Which world is it?
	if isTunableAt(legs, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		return string.format(
			"already done: %s is Tunable at CollisionPrecision %.2f with its mesh and texture as recorded, the belly, head and nightcap are Tunable at 1.0, left_arm and right_arm are PreciseConvexDecomposition, and the head parts (%d recorded, truss 32 long) are as recorded",
			LEGS_PIECE,
			legs.CollisionPrecision,
			#FINAL_HEAD_PARTS_2H
		)
	end
	if legs.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
		error(
			string.format(
				"nothing was changed. %s is %s at CollisionPrecision %.3f: neither the world before section 2f5 (PreciseConvexDecomposition) nor the world after it (Tunable at 1.0)",
				LEGS_PIECE,
				legs.CollisionFidelity.Name,
				legs.CollisionPrecision
			)
		)
	end

	-- The staging WorldModel: a leftover from a stopped run goes first, and it is destroyed whatever happens.
	local leftover = ServerStorage:FindFirstChild(LEGS_STAGING_NAME)
	if leftover ~= nil then
		leftover:Destroy()
	end
	local staging = Instance.new("WorldModel")
	staging.Name = LEGS_STAGING_NAME
	staging.Archivable = false
	staging.Parent = ServerStorage
	local ok, result = pcall(changeLegsToCloserFit, staging, pieces, byName, walk)
	staging:Destroy()
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2f6: the beard truss's foot swings back toward his beard (stuck safety Task 26, step 26-6a1b, Ruling 12)
----------------------------------------------------------------------------------------------------------------------
-- Why: the climbing truss is 2 studs thick and its centre line runs along the visible rails, so its front face stood 1
-- stud out from the rungs and a walker crossing in front of the ladder's foot was lifted off his cloth (designer: a player
-- may only grab it where he visibly touches the ladder). The numbers are at TRUSS_SWING above. It is invisible.
-- What it does:
--   - It refuses to run in Play.
--   - It checks everything first and changes nothing on any difference: the 3 closer-fit pieces are Tunable at
--     CollisionPrecision 1, the legs and arms are as section 2f5 leaves them, and the head is either section 2f4's (before:
--     the truss 2 x 2 x 32 as it is; the change is made) or the final one (after: the truss's foot swung back by
--     TRUSS_SWING: "already done").
--   - Before the change: the truss's top end stays within 0.05; its foot end moves 0.85 to 1.0 studs along minus its
--     UpVector (and hardly at all along its length); it turns only about its own X axis.
--   - It sets the CFrame of that one part and nothing else (it compares every other value before and after, Size
--     included), with waypoints before and after, and checks the head again.
--   - It prints before and after: size, place, top end, foot and front-bottom edge (the foot plus UpVector times 1).
local TRUSS_HALF_THICKNESS = 1.0 -- studs: half of the truss's 2 stud thickness
local TRUSS_ALONG_SLACK = 0.05 -- studs: the foot may move this far along the truss's length (a turn shortens it a little)
local TRUSS_TURN_SLACK = 0.00001 -- on the dot product of the truss's X axis before and after: the turn is about it

-- One line about the truss: size, place, top end, foot and front-bottom edge.
local function trussSwingText(size: Vector3, cframe: CFrame): string
	local _, foot = trussEnds(size, cframe)
	local frontBottom = foot + cframe.UpVector * TRUSS_HALF_THICKNESS
	return headPartText(size, cframe, true)
		.. string.format("; front-bottom edge y %.3f, z %.3f", frontBottom.Y, frontBottom.Z)
end

local function sectionTrussSwing(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local pieces, pieceProblems = findPieces()
	if #pieceProblems > 0 then
		error("nothing was changed. " .. table.concat(pieceProblems, "; "))
	end
	local byName: { [string]: Piece } = {}
	for _, piece in pieces do
		byName[piece.name] = piece
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end

	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(
				problems,
				string.format(
					"%s is %s at CollisionPrecision %.3f, expected Tunable at 1.0 (section 2f2)",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	for _, name in SHAPE_PIECES_STAYING do
		local stayingProblem = stayingPieceProblem(name, byName[name].mesh)
		if stayingProblem ~= nil then
			table.insert(problems, stayingProblem)
		end
	end
	if #problems > 0 then
		error("nothing was changed. " .. someProblems(problems))
	end

	local pair = HEAD_CHANGES_2F6[1]
	local old, new = pair[1], pair[2]
	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2I)
	if #afterProblems > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		afterProblems = {} -- the world after section 2g: the same truss, with the longer beard rails and the extra rung
	end
	if #afterProblems == 0 then
		local swungTruss = liveHeadPart(walk, new, {})
		return "already done: the beard truss's foot is swung back ("
			.. (if swungTruss ~= nil then trussSwingText(swungTruss.Size, swungTruss.CFrame) else "not found")
			.. `; {#FINAL_HEAD_PARTS_2I} recorded head parts)`
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f4 ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2f6 ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The live truss, and the numbers that must hold for what it would become.
	local live = liveHeadPart(walk, old, {})
	if live == nil then
		error(`nothing was changed. No BeardLadder.Climb at {describePlace(old.cframe)} to change`)
	end
	if (old.size - new.size).Magnitude > SIZE_TOLERANCE then
		error("nothing was changed. The swung truss would have another size")
	end
	local oldTop, oldFoot = trussEnds(old.size, old.cframe)
	local newTop, newFoot = trussEnds(new.size, new.cframe)
	if (oldTop - newTop).Magnitude > TRUSS_SWING_TOP_SLACK then
		error(`nothing was changed. The swung truss would move its top end by {(oldTop - newTop).Magnitude} studs`)
	end
	local moved = newFoot - oldFoot
	local towardBeard = -moved:Dot(old.cframe.UpVector)
	local alongLength = moved:Dot(old.cframe.LookVector)
	if
		towardBeard < TRUSS_SWING_MIN
		or towardBeard > TRUSS_SWING_MAX + TRUSS_SWING_SLACK
		or math.abs(alongLength) > TRUSS_ALONG_SLACK
	then
		error(
			string.format(
				"nothing was changed. The swung truss's foot would move %.3f studs toward his beard and %.3f along its length; it must move %g to %g and hardly along",
				towardBeard,
				alongLength,
				TRUSS_SWING_MIN,
				TRUSS_SWING_MAX
			)
		)
	end
	if math.abs(new.cframe.RightVector:Dot(old.cframe.RightVector) - 1) > TRUSS_TURN_SLACK then
		error("nothing was changed. The swung truss would turn about another axis than its own X axis")
	end

	local lines: { string } = {
		`before: BeardLadder.Climb {trussSwingText(old.size, old.cframe)}`,
	}
	local before = headPartSnapshot(live)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f6: before")
	end)
	local changed, whyNot = pcall(function()
		live.CFrame = new.cframe
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2f6: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2f6: before") and tell code_lead`
		)
	end
	local unexpected: { string } = {}
	for _, name in headPartDifferences(before, headPartSnapshot(live)) do
		if name ~= "CFrame" then
			table.insert(unexpected, name)
		end
	end
	if #unexpected > 0 then
		error(
			"the truss was changed, but the check afterwards found it differs from before in: "
				.. table.concat(unexpected, ", ")
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	local liveTop = trussEnds(live.Size, live.CFrame)
	local topMoved = string.format("%.4f", (oldTop - liveTop).Magnitude)
	local footMoved = string.format("%.3f", towardBeard)
	table.insert(
		lines,
		`after: BeardLadder.Climb {trussSwingText(live.Size, live.CFrame)}; the top end moved {topMoved} studs and the foot {footMoved} toward his beard; {countValues(
			before
		)} values compared before and after: only CFrame differs`
	)
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2I)
	if #stillProblems > 0 then
		error(
			"the truss was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		`ForeheadGuard holds {#(walk:FindFirstChild("ForeheadGuard") :: Instance):GetChildren()} children, BeardLadder {#(
			walk:FindFirstChild("BeardLadder") :: Instance
		):GetChildren()} ({#FINAL_HEAD_PARTS_2I} recorded head parts in all)`
	)
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 2g: the beard rails reach his drawn belly (stuck safety Task 25, after the Task 26 ruling)
----------------------------------------------------------------------------------------------------------------------
-- Why: designer asked that the beard ladder's visible rails touch his belly. The rails of section 2e still end 2.4 to 2.7
-- studs over his drawn belly, measured on his drawn skin (DrawnSkin). Each rail gets BELLY_RAIL_EXTRA (2.75) studs longer
-- at its bottom end only (its top end stays, its turn and thickness stay), and one more rung, a copy of today's lowest
-- rung, goes BELLY_RUNG_STEP (1.80) studs further down the ladder. Rails and rungs are not solid (CanCollide off), so
-- nothing new can be stood on. The numbers are the BELLY_* constants above.
-- What it does:
--   - It refuses to run in Play.
--   - It knows two worlds and changes nothing on any difference:
--       (a) the world after 2f6: beard rails 31.85 long and 17 rungs (FINAL_HEAD_PARTS_2I). The change below is made.
--       (b) the world after 2g: beard rails 34.60 long and 18 rungs (FINAL_HEAD_PARTS_2J). It says "already done".
--       (c) anything else: it stops with nothing changed and names what differs.
--   - Before the change, for each rail: its top end stays within 0.05, its bottom end moves 2.75 (within 0.01) along the
--     same line, it keeps its thickness and its turn. The extra rung has the lowest rung's size and turn and stands 1.80
--     (within 0.01) further down the same line.
--   - The extra rung is built away from the Workspace first (a clone of the lowest live rung), then parented to
--     BeardLadder. The 2 live rails get their Size and CFrame set in place and nothing else (it compares every other
--     value before and after), with waypoints before and after, and checks the head again.
--   - It prints before and after for each rail and the added rung.
-- One line about a beard rail: size, place, ends z, and its lowest end.
local function railBellyText(size: Vector3, cframe: CFrame): string
	local bottom = cframe.Position - cframe.RightVector * (size.X / 2)
	return headPartText(size, cframe, false) .. string.format("; bottom end y %.4f, z %.4f", bottom.Y, bottom.Z)
end

local function sectionBeardBelly(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if walk == nil then
		error("World.WalkSurfaces is missing")
	end
	local beardBox = walk:FindFirstChild("BeardLadder")
	if beardBox == nil then
		error("World.WalkSurfaces.BeardLadder is missing")
	end

	local afterProblems = headProblems(walk, FINAL_HEAD_PARTS_2J)
	if #afterProblems == 0 then
		local lowestRung = liveHeadPart(walk, BEARD_BELLY_RUNG, {})
		return string.format(
			"already done: the 2 beard rails are %.2f long and BeardLadder holds the extra rung at %s (%d recorded head parts)",
			BELLY_RAIL_LENGTH,
			if lowestRung ~= nil then describePlace(lowestRung.CFrame) else "(not found)",
			#FINAL_HEAD_PARTS_2J
		)
	end
	local beforeProblems = headProblems(walk, FINAL_HEAD_PARTS_2I)
	if #beforeProblems > 0 then
		error(
			"nothing was changed. His head is neither the world after section 2f6 ("
				.. someProblems(beforeProblems)
				.. ") nor the world after 2g ("
				.. someProblems(afterProblems)
				.. ")"
		)
	end

	-- The numbers must do what the ruling says, or nothing is changed.
	local axis: Vector3 = BEARD_RAIL_BELLY_BEFORE_AFTER[1][1].cframe.RightVector -- up the ladder
	for _, pair in BEARD_RAIL_BELLY_BEFORE_AFTER do
		local old, new = pair[1], pair[2]
		local oldTop = old.cframe.Position + old.cframe.RightVector * (old.size.X / 2)
		local newTop = new.cframe.Position + new.cframe.RightVector * (new.size.X / 2)
		if (oldTop - newTop).Magnitude > BELLY_TOP_SLACK then
			error(
				`nothing was changed. The beard rail at x {old.cframe.X} would move its top end by {(oldTop - newTop).Magnitude} studs`
			)
		end
		local oldBottom = old.cframe.Position - old.cframe.RightVector * (old.size.X / 2)
		local newBottom = new.cframe.Position - new.cframe.RightVector * (new.size.X / 2)
		local moved = newBottom - oldBottom
		local down = -moved:Dot(old.cframe.RightVector)
		local sideways = (moved + old.cframe.RightVector * down).Magnitude
		if math.abs(down - BELLY_RAIL_EXTRA) > BELLY_RAIL_EXTRA_SLACK or sideways > BELLY_RAIL_EXTRA_SLACK then
			error(
				string.format(
					"nothing was changed. The beard rail at x %.2f would grow %.3f studs down its line and %.3f sideways, expected %g and 0",
					old.cframe.X,
					down,
					sideways,
					BELLY_RAIL_EXTRA
				)
			)
		end
		if
			math.abs(old.size.Y - new.size.Y) > SIZE_TOLERANCE
			or math.abs(old.size.Z - new.size.Z) > SIZE_TOLERANCE
			or new.cframe.RightVector:Dot(old.cframe.RightVector) < 1 - BELLY_TURN_SLACK
			or new.cframe.UpVector:Dot(old.cframe.UpVector) < 1 - BELLY_TURN_SLACK
			or new.cframe.LookVector:Dot(old.cframe.LookVector) < 1 - BELLY_TURN_SLACK
		then
			error(`nothing was changed. The beard rail at x {old.cframe.X} would change its thickness or turn`)
		end
	end
	local stepMoved = BEARD_LOW_RUNG.cframe.Position - BEARD_BELLY_RUNG.cframe.Position
	local stepAlong = stepMoved:Dot(axis)
	local stepSideways = (stepMoved - axis * stepAlong).Magnitude
	if
		math.abs(stepAlong - BELLY_RUNG_STEP) > BELLY_RUNG_STEP_SLACK
		or stepSideways > BELLY_RUNG_STEP_SLACK
		or (BEARD_BELLY_RUNG.size - BEARD_LOW_RUNG.size).Magnitude > SIZE_TOLERANCE
		or BEARD_BELLY_RUNG.cframe.RightVector:Dot(BEARD_LOW_RUNG.cframe.RightVector) < 1 - BELLY_TURN_SLACK
		or BEARD_BELLY_RUNG.cframe.UpVector:Dot(BEARD_LOW_RUNG.cframe.UpVector) < 1 - BELLY_TURN_SLACK
	then
		error(
			string.format(
				"nothing was changed. The extra rung would stand %.3f studs down the line and %.3f sideways from the lowest rung, expected %g and 0 (same size and turn)",
				stepAlong,
				stepSideways,
				BELLY_RUNG_STEP
			)
		)
	end

	-- The live rails (each found by its recorded size and place) and the lowest live rung, whose settings the extra rung copies.
	local liveRails: { Part } = {}
	local taken: { BasePart } = {}
	for _, pair in BEARD_RAIL_BELLY_BEFORE_AFTER do
		local found = liveHeadPart(walk, pair[1], taken)
		if found == nil or not found:IsA("Part") then
			error(`nothing was changed. No beard Rail at {describePlace(pair[1].cframe)} to make longer`)
		end
		table.insert(taken, found)
		table.insert(liveRails, found)
	end
	local template = liveHeadPart(walk, BEARD_LOW_RUNG, {})
	if template == nil or not template:IsA("Part") then
		error("nothing was changed. The lowest beard Rung is not there to copy for the extra rung")
	end

	-- Build the extra rung away from the Workspace and check it.
	local staging = Instance.new("Folder")
	staging.Name = "Task25Staging2g"
	staging.Archivable = false
	local extra = template:Clone()
	extra.Name = BEARD_BELLY_RUNG.name
	extra.Size = BEARD_BELLY_RUNG.size
	extra.CFrame = BEARD_BELLY_RUNG.cframe
	extra.Parent = staging
	local problems: { string } = {}
	local same, why = sameAs(extra, BEARD_BELLY_RUNG.size, BEARD_BELLY_RUNG.cframe)
	if not same then
		table.insert(problems, `{BEARD_BELLY_RUNG.name}: {why}`)
	end
	local wrong = headSettingsProblem(extra, HEAD_SETTINGS[BEARD_BELLY_RUNG.name])
	if wrong ~= nil then
		table.insert(problems, `{BEARD_BELLY_RUNG.name}: {wrong}`)
	end
	if #problems > 0 then
		staging:Destroy()
		error("nothing was changed. The extra rung is not right: " .. someProblems(problems))
	end

	-- The report's lines for the rails (old place), taken before the change.
	local lines: { string } = {}
	local before: { { [string]: any } } = {}
	for index, rail in liveRails do
		table.insert(before, headPartSnapshot(rail))
		table.insert(
			lines,
			`before: BeardLadder.Rail at x {string.format("%.2f", rail.Position.X)}: {railBellyText(
				rail.Size,
				rail.CFrame
			)}`
		)
		if index == #liveRails then
			table.insert(lines, `before: BeardLadder holds {#beardBox:GetChildren()} children`)
		end
	end

	-- The change itself, between two waypoints.
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2g: before")
	end)
	local changed, whyNot = pcall(function()
		for index, rail in liveRails do
			local longer = BEARD_RAIL_BELLY_BEFORE_AFTER[index][2]
			rail.Size = longer.size
			rail.CFrame = longer.cframe
		end
		extra.Parent = beardBox
	end)
	staging:Destroy()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 2g: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 2g: before") and tell code_lead`
		)
	end

	-- Every other value of each rail is as before.
	for index, rail in liveRails do
		local unexpected: { string } = {}
		for _, name in headPartDifferences(before[index], headPartSnapshot(rail)) do
			if not SLOT_MAY_DIFFER[name] then
				table.insert(unexpected, name)
			end
		end
		if #unexpected > 0 then
			error(
				"a rail was changed, but the check afterwards found it differs from before in: "
					.. table.concat(unexpected, ", ")
					.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
			)
		end
		table.insert(
			lines,
			`after: BeardLadder.Rail at x {string.format("%.2f", rail.Position.X)}: {railBellyText(
				rail.Size,
				rail.CFrame
			)}; {countValues(before[index])} values compared before and after: only Size and CFrame differ`
		)
	end
	local stillProblems = headProblems(walk, FINAL_HEAD_PARTS_2J)
	if #stillProblems > 0 then
		error(
			"the head was changed, but the check afterwards found: "
				.. someProblems(stillProblems)
				.. ". Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead"
		)
	end
	table.insert(
		lines,
		string.format(
			"added BeardLadder.%s: %.2f x %.2f x %.2f at %s (a copy of the lowest rung, 1.80 further down)",
			BEARD_BELLY_RUNG.name,
			BEARD_BELLY_RUNG.size.X,
			BEARD_BELLY_RUNG.size.Y,
			BEARD_BELLY_RUNG.size.Z,
			describePlace(BEARD_BELLY_RUNG.cframe)
		)
	)
	table.insert(
		lines,
		string.format(
			"BeardLadder now holds %d children (%d recorded head parts in all)",
			#beardBox:GetChildren(),
			#FINAL_HEAD_PARTS_2J
		)
	)
	return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- Section 3a: the pillow's closer fit (stuck safety Task 22, step 22-2; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------
-- Why: the pillow behind his head (World.GiantsThings.Pillow.body.body_geom) has Roblox's usual collision shape
-- (CollisionFidelity Default), which sits above the pillow players see in places: 35 of the 287 stuck spots are on it.
-- CollisionPrecision 1 on the Tunable shape ("closest to the visual mesh", Roblox docs, TriangleMeshPart) follows the
-- pillow's drawn surface much closer, and a pillow is a plain MeshPart, so it is done the way section 2f2 does it:
-- AssetService:CreateMeshPartAsync makes a Tunable copy, CollisionPrecision 1 is set on the copy, and MeshPart:ApplyMesh
-- takes its shape onto the pillow. ApplyMesh wipes TextureID (measured in step 6b-1f), so it is put back at once.
-- It knows two worlds, and changes nothing on any difference:
--   (a) before: the pillow is CollisionFidelity Default, with its MeshId, TextureID, Size and CFrame as recorded in step
--       22-0 (below). The change is made.
--   (b) after: the pillow is Tunable at CollisionPrecision 1.0 (+-0.01), with the same MeshId, TextureID, Size and
--       CFrame. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- Away from the Workspace (in a WorldModel in ServerStorage that is destroyed at the end, also when something fails):
--   1. The Tunable copy is made, given the pillow's Size and CFrame, and its 7 rays (below) are read until steady.
--   2. CollisionPrecision is set to 1, and it waits until the rays move and are steady again (up to MAX_WAIT seconds,
--      then it stops with nothing changed).
--   3. Dry run: ApplyMesh from the copy onto a clone of the pillow, TextureID put back. The same 28 values as in 2f are
--      compared (only CollisionFidelity and CollisionPrecision may differ) and the clone must be Tunable at 1.0.
-- Only then, between two ChangeHistoryService waypoints: ApplyMesh onto the live pillow and TextureID put back, the same
-- check on the live pillow, and a wait until its rays have moved and are steady.
-- Rays: straight down from y 140 at 7 points (x, z), reading the pillow alone, as in step 22-0 (heights before the change):
--   (0, 50) 116.0, (0, 66) 93.8, (20, 66) 90.3, (-20, 66) 90.1, (0, 72) 77.5, (17, 41) 119.6, (-17, 41) 119.8.
-- No earlier section reads the pillow, so all of them still say "already done" after this one has run.
local function sectionPillowCloserFit(): string
	if RunService:IsRunning() then
		error("a running game can't change CollisionFidelity: stop Play and run this in Edit mode")
	end
	-- As recorded in step 22-0 (Studio Edit mode, 2026-10-21).
	local PATH = { "World", "GiantsThings", "Pillow", "body", "body_geom" }
	local MESH_ID = "rbxassetid://106761089887672"
	local TEXTURE_ID = "rbxassetid://138710597423165"
	local SIZE = Vector3.new(95.004646, 91.194412, 35.748734)
	local CFRAME = CFrame.new(0.142862, 79.86055, 52.141579, 1, 0, 0, 0, 0.939693, 0.34202, 0, -0.34202, 0.939692)
	local PLACE_TOLERANCE_STUDS = 0.01 -- on the size and the middle
	local TURN_TOLERANCE_NUMBER = 0.001 -- on each of the nine numbers of the turn
	local PILLOW_PRECISION = 1.0
	local PILLOW_PRECISION_SLACK = 0.01
	local RAY_FROM_Y = 140
	local RAY_LENGTH = 150
	local RAY_POINTS = {
		Vector2.new(0, 50),
		Vector2.new(0, 66),
		Vector2.new(20, 66),
		Vector2.new(-20, 66),
		Vector2.new(0, 72),
		Vector2.new(17, 41),
		Vector2.new(-17, 41),
	}
	local PILLOW_STAGING_NAME = "Task22Staging3a"

	local node: Instance? = Workspace
	for _, name in PATH do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	if node == nil or not node:IsA("MeshPart") then
		error(`nothing was changed. {table.concat(PATH, ".")} (a MeshPart) is missing`)
	end
	local pillow: MeshPart = node

	local rays: { FixedRay } = {}
	for _, point in RAY_POINTS do
		table.insert(rays, {
			origin = Vector3.new(point.X, RAY_FROM_Y, point.Y),
			direction = Vector3.new(0, -RAY_LENGTH, 0),
		})
	end
	local function raysText(distances: { number }): string
		local texts: { string } = {}
		for index, ray in rays do
			table.insert(
				texts,
				`({RAY_POINTS[index].X}, {RAY_POINTS[index].Y}) {heightText(hitHeight(ray, distances[index]))}`
			)
		end
		return table.concat(texts, "; ")
	end
	local function stateText(mesh: MeshPart): string
		return string.format(
			"CollisionFidelity %s, CollisionPrecision %.2f, TextureID %s",
			mesh.CollisionFidelity.Name,
			mesh.CollisionPrecision,
			mesh.TextureID
		)
	end

	-- What never changes: the mesh, the texture, the size and the place as recorded.
	local problems: { string } = {}
	if pillow.MeshId ~= MESH_ID then
		table.insert(problems, `MeshId is {pillow.MeshId}, recorded {MESH_ID}`)
	end
	if pillow.TextureID ~= TEXTURE_ID then
		table.insert(problems, `TextureID is {pillow.TextureID}, recorded {TEXTURE_ID}`)
	end
	if (pillow.Size - SIZE).Magnitude > PLACE_TOLERANCE_STUDS then
		table.insert(problems, `Size is {pillow.Size}, recorded {SIZE}`)
	end
	if (pillow.CFrame.Position - CFRAME.Position).Magnitude > PLACE_TOLERANCE_STUDS then
		table.insert(problems, `its middle is {pillow.CFrame.Position}, recorded {CFRAME.Position}`)
	end
	local nowTurn = { pillow.CFrame:GetComponents() }
	local recordedTurn = { CFRAME:GetComponents() }
	for index = 4, 12 do
		if math.abs(nowTurn[index] - recordedTurn[index]) > TURN_TOLERANCE_NUMBER then
			table.insert(problems, `its turn differs from the recorded one (number {index - 3} of 9)`)
			break
		end
	end
	if #problems > 0 then
		error(`nothing was changed. The pillow is not the one recorded in step 22-0: {someProblems(problems)}`)
	end

	-- Which world is it?
	if isTunableAt(pillow, PILLOW_PRECISION, PILLOW_PRECISION_SLACK) then
		return `already done: the pillow is Tunable at CollisionPrecision {string.format(
			"%.2f",
			pillow.CollisionPrecision
		)}, with its mesh, texture, size and place as recorded. {stateText(pillow)}. Its rays now: {raysText(
			readRays(pillow, rays)
		)}`
	end
	if pillow.CollisionFidelity ~= Enum.CollisionFidelity.Default then
		error(
			`nothing was changed. The pillow is neither the world before nor the world after section 3a: {stateText(
				pillow
			)}`
		)
	end

	local function changePillow(staging: WorldModel): string
		local oldPrecision = pillow.CollisionPrecision
		local lines: { string } = {}
		table.insert(lines, `before: {stateText(pillow)}`)
		local beforeLive = readRays(pillow, rays)
		table.insert(lines, `before: the live pillow's rays: {raysText(beforeLive)}`)

		local made, madeOrWhy = pcall(function(): MeshPart
			return AssetService:CreateMeshPartAsync(Content.fromUri(pillow.MeshId), {
				CollisionFidelity = Enum.CollisionFidelity.Tunable,
				RenderFidelity = pillow.RenderFidelity,
				FluidFidelity = pillow.FluidFidelity,
			})
		end)
		if not made then
			error(`nothing was changed. CreateMeshPartAsync failed for the pillow: {tostring(madeOrWhy)}`)
		end
		local source = madeOrWhy :: MeshPart
		source.Anchored = true
		source.Size = pillow.Size
		source.CFrame = pillow.CFrame
		source.Parent = staging

		local baselineSteady, _, _, baseline = waitForSourceShape(staging, source, rays, nil)
		if not baselineSteady then
			error(
				`nothing was changed. The copy of the pillow never settled at its first precision within {MAX_WAIT} seconds`
			)
		end
		(source :: any).CollisionPrecision = PILLOW_PRECISION
		local moved, seconds, movedBy = waitForSourceShape(staging, source, rays, baseline)
		if not moved then
			error(
				string.format(
					"nothing was changed. The copy of the pillow did not change its shape within %d seconds of CollisionPrecision 1 (largest ray move %.3f studs)",
					MAX_WAIT,
					movedBy
				)
			)
		end

		-- Dry run on a clone.
		local trial = pillow:Clone()
		trial.Parent = staging
		local wiped = false
		local trialOk, trialWhy = pcall(function()
			trial:ApplyMesh(source)
			wiped = trial.TextureID ~= TEXTURE_ID
			trial.TextureID = TEXTURE_ID
		end)
		if not trialOk then
			error(`nothing was changed. ApplyMesh failed on the clone of the pillow: {tostring(trialWhy)}`)
		end
		local before = bodySnapshot(pillow)
		local trialDifferences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(trial)))
		if #trialDifferences > 0 then
			error(
				`nothing was changed. ApplyMesh on the clone of the pillow changed more than the collision: {table.concat(
					trialDifferences,
					", "
				)}`
			)
		end
		if not isTunableAt(trial, PILLOW_PRECISION, PILLOW_PRECISION_SLACK) then
			error(
				string.format(
					"nothing was changed. The clone of the pillow is %s at CollisionPrecision %.3f, expected Tunable at 1.0",
					trial.CollisionFidelity.Name,
					trial.CollisionPrecision
				)
			)
		end
		trial:Destroy()

		-- The change itself, between two waypoints.
		pcall(function()
			ChangeHistoryService:SetWaypoint("15-real-shape section 3a: before")
		end)
		local changed, whyNot = pcall(function()
			pillow:ApplyMesh(source)
			pillow.TextureID = TEXTURE_ID
		end)
		pcall(function()
			ChangeHistoryService:SetWaypoint("15-real-shape section 3a: after")
		end)
		if not changed then
			error(
				`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3a: before") and tell code_lead`
			)
		end

		-- The same check on the live pillow.
		local differences = unexpectedDifferences(bodyDifferences(before, bodySnapshot(pillow)))
		if #differences > 0 or not isTunableAt(pillow, PILLOW_PRECISION, PILLOW_PRECISION_SLACK) then
			error(
				string.format(
					"the pillow was changed, but the check afterwards found it is %s at CollisionPrecision %.3f and differs from before in: %s. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead",
					pillow.CollisionFidelity.Name,
					pillow.CollisionPrecision,
					table.concat(differences, ", ")
				)
			)
		end
		table.insert(
			lines,
			string.format(
				"CollisionFidelity Default -> Tunable; CollisionPrecision %.2f -> %.2f; ApplyMesh %s TextureID and it was put back (%s); %d values compared before and after: only CollisionFidelity and CollisionPrecision differ. The staging copy's rays moved %.2f studs after CollisionPrecision 1 (steady after %.1f seconds)",
				oldPrecision,
				pillow.CollisionPrecision,
				if wiped then "wiped" else "did not wipe",
				pillow.TextureID,
				countValues(before),
				movedBy,
				seconds
			)
		)

		-- Wait until Roblox has worked out the new shape: the live pillow's rays must have moved and be steady.
		local steady, waited, liveMoved, now = waitForSourceShape(Workspace, pillow, rays, beforeLive)
		table.insert(lines, `after: {stateText(pillow)}`)
		table.insert(lines, `after: the live pillow's rays: {raysText(now)}`)
		table.insert(
			lines,
			string.format("largest ray move on the live pillow from before the change: %.2f studs", liveMoved)
		)
		if steady then
			table.insert(
				lines,
				string.format("Roblox worked out the shape: the rays were steady after %.1f seconds of waiting", waited)
			)
		else
			table.insert(
				lines,
				string.format(
					"TIMED OUT after %.0f seconds: the shape was not steady yet, or the pillow's rays did not move. Run the script again to wait further, and if it is the same, STOP and tell code_lead",
					waited
				)
			)
		end
		return table.concat(lines, "\n")
	end

	-- The staging WorldModel: a leftover from a stopped run goes first, and it is destroyed whatever happens.
	local leftover = ServerStorage:FindFirstChild(PILLOW_STAGING_NAME)
	if leftover ~= nil then
		leftover:Destroy()
	end
	local staging = Instance.new("WorldModel")
	staging.Name = PILLOW_STAGING_NAME
	staging.Archivable = false
	staging.Parent = ServerStorage
	local ok, result = pcall(changePillow, staging)
	staging:Destroy()
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

----------------------------------------------------------------------------------------------------------------------
-- Section 3a2: lit like before (stuck safety Task 22, step 22-6d; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------
-- Why: after its closer collision fit (Tunable, CollisionPrecision 1) the pillow looked dark navy and tan instead of
-- light blue and cream gingham. Nothing was lost: Color, Material, MaterialVariant, Transparency, Reflectance and TextureID
-- are all still the ArtLibrary original's. The precise solid shape shades the pillow itself in Roblox's lighting, and
-- CastShadow false puts the light look back (step 22-6a and 22-6b: the nightcap, head, body and legs keep CastShadow true,
-- because they stayed light; only the pieces in LIT_PIECES below change). The cost: the pillow no longer drops a shadow on
-- the grass (designer judges that in step 22-6g).
-- It knows two worlds, and changes nothing on any difference:
--   (a) before: each listed piece is Tunable at CollisionPrecision 1.0 (+-0.01) with CastShadow true. CastShadow is set to
--       false, and nothing else is touched.
--   (b) after: each listed piece is Tunable at CollisionPrecision 1.0 (+-0.01) with CastShadow false. It says "already
--       done".
--   (c) anything else (a piece missing or not the recorded one, not Tunable at 1.0, or some pieces before and some
--       after): it stops with nothing changed and names what differs.
-- The change runs between two ChangeHistoryService waypoints, and every value the pillow-style snapshot compares (the 28
-- values of section 2f) is checked again afterwards: only CastShadow may differ.
local function sectionLitLikeBefore(): string
	if RunService:IsRunning() then
		error("a running game can't be checked like this: stop Play and run this in Edit mode")
	end
	-- The listed pieces, as recorded in step 22-0 (Studio Edit mode, 2026-10-21).
	local LIT_PIECES = {
		{
			label = "the pillow",
			path = { "World", "GiantsThings", "Pillow", "body", "body_geom" },
			meshId = "rbxassetid://106761089887672",
			textureId = "rbxassetid://138710597423165",
		},
	}
	local LIT_PRECISION = 1.0
	local LIT_PRECISION_SLACK = 0.01
	local LIT_MAY_DIFFER = "CastShadow"

	local pieces: { { label: string, mesh: MeshPart } } = {}
	for _, listed in LIT_PIECES do
		local node: Instance? = Workspace
		for _, name in listed.path do
			node = if node ~= nil then node:FindFirstChild(name) else nil
		end
		if node == nil or not node:IsA("MeshPart") then
			error(`nothing was changed. {table.concat(listed.path, ".")} (a MeshPart) is missing`)
		end
		local mesh: MeshPart = node
		if mesh.MeshId ~= listed.meshId or mesh.TextureID ~= listed.textureId then
			error(
				`nothing was changed. {listed.label} is not the one recorded: MeshId {mesh.MeshId}, TextureID {mesh.TextureID}`
			)
		end
		table.insert(pieces, { label = listed.label, mesh = mesh })
	end

	local function pieceText(label: string, mesh: MeshPart): string
		return string.format(
			"%s: CollisionFidelity %s, CollisionPrecision %.2f, CastShadow %s",
			label,
			mesh.CollisionFidelity.Name,
			mesh.CollisionPrecision,
			tostring(mesh.CastShadow)
		)
	end

	-- Which world is it?
	local before: { string } = {}
	local after: { string } = {}
	local other: { string } = {}
	local allTexts: { string } = {}
	for _, piece in pieces do
		table.insert(allTexts, pieceText(piece.label, piece.mesh))
		if not isTunableAt(piece.mesh, LIT_PRECISION, LIT_PRECISION_SLACK) then
			table.insert(other, `{piece.label} is not Tunable at CollisionPrecision {LIT_PRECISION}`)
		elseif piece.mesh.CastShadow then
			table.insert(before, piece.label)
		else
			table.insert(after, piece.label)
		end
	end
	if #other > 0 then
		error(
			`nothing was changed. This is neither the world before nor the world after section 3a2: {someProblems(other)}`
		)
	end
	if #before > 0 and #after > 0 then
		error(`nothing was changed. Some pieces are lit like before and some are not: {table.concat(allTexts, "; ")}`)
	end
	if #after == #pieces then
		return `already done: {table.concat(allTexts, "; ")}`
	end

	-- The change itself, between two waypoints: CastShadow false on each listed piece, and nothing else.
	local snapshots: { { [string]: any } } = {}
	for _, piece in pieces do
		table.insert(snapshots, bodySnapshot(piece.mesh))
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3a2: before")
	end)
	local changed, whyNot = pcall(function()
		for _, piece in pieces do
			piece.mesh.CastShadow = false
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3a2: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3a2: before") and tell code_lead`
		)
	end

	-- The same check afterwards: only CastShadow may differ, and it must now be false.
	local wrong: { string } = {}
	local valuesCompared = 0
	for index, piece in pieces do
		valuesCompared += countValues(snapshots[index])
		for _, name in bodyDifferences(snapshots[index], bodySnapshot(piece.mesh)) do
			if name ~= LIT_MAY_DIFFER then
				table.insert(wrong, `{piece.label}: {name} changed`)
			end
		end
		if piece.mesh.CastShadow then
			table.insert(wrong, `{piece.label}: CastShadow is still true`)
		end
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	local afterTexts: { string } = {}
	for _, piece in pieces do
		table.insert(afterTexts, pieceText(piece.label, piece.mesh))
	end
	return string.format(
		"CastShadow true -> false on %d piece(s); %d values compared before and after: only CastShadow differs. Before: %s. After: %s",
		#pieces,
		valuesCompared,
		table.concat(allTexts, "; "),
		table.concat(afterTexts, "; ")
	)
end

----------------------------------------------------------------------------------------------------------------------
-- Shared by sections 3b, 3c and 4: a folder of recorded parts (made, and checked against the record)
----------------------------------------------------------------------------------------------------------------------
-- One part as recorded. `place` is the small place it belongs to (only used to count parts per place in a message).
type FolderRecord = { name: string, className: string, size: Vector3, cframe: CFrame, place: string }
-- What a section asks of its folders: the look every part has, the colour to check (nil: not checked), and how that
-- section compares size, place and turn (it returns what differs; empty when all is right).
type FolderSpec = {
	look: { [string]: any },
	color: Color3?,
	geometry: (part: BasePart, recorded: FolderRecord) -> { string },
}
local SHOWN_MATERIAL = Enum.Material.SmoothPlastic

local function colorText(color: Color3): string
	return `{math.round(color.R * 255)}, {math.round(color.G * 255)}, {math.round(color.B * 255)}`
end

local function countsText(records: { FolderRecord }): string
	local perPlace: { [string]: number } = {}
	for _, recorded in records do
		perPlace[recorded.place] = (perPlace[recorded.place] or 0) + 1
	end
	local texts: { string } = {}
	for place, count in perPlace do
		table.insert(texts, `{place} {count}`)
	end
	table.sort(texts)
	return `{#records} parts (per place: {table.concat(texts, ", ")})`
end

-- What is wrong with a folder that should hold exactly `records` with this spec; the list is empty when all is right.
local function folderProblems(folder: Instance, records: { FolderRecord }, spec: FolderSpec): { string }
	local problems: { string } = {}
	if not folder:IsA("Folder") then
		table.insert(problems, `{folder.Name} is a {folder.ClassName}, not a Folder`)
	end
	if #folder:GetChildren() ~= #records then
		table.insert(problems, `{folder.Name} holds {#folder:GetChildren()} children, expected {#records}`)
	end
	for _, recorded in records do
		local found: { Instance } = {}
		for _, child in folder:GetChildren() do
			if child.Name == recorded.name then
				table.insert(found, child)
			end
		end
		if #found ~= 1 or found[1].ClassName ~= recorded.className then
			table.insert(problems, `{recorded.name}: {#found} found, expected 1 {recorded.className}`)
			continue
		end
		local part = found[1] :: BasePart
		local wrong: { string } = spec.geometry(part, recorded)
		for property, value in spec.look do
			if (part :: any)[property] ~= value then
				table.insert(wrong, `{property} is {tostring((part :: any)[property])}, expected {tostring(value)}`)
			end
		end
		if part.Material ~= SHOWN_MATERIAL then
			table.insert(wrong, `Material is {part.Material.Name}`)
		end
		if part.CollisionGroup ~= "Default" then
			table.insert(wrong, `CollisionGroup is {part.CollisionGroup}, expected Default`)
		end
		if part.MaterialVariant ~= "" then
			table.insert(wrong, `MaterialVariant is "{part.MaterialVariant}"`)
		end
		if not samePhysics(part, nil) then
			table.insert(wrong, "CustomPhysicalProperties are set")
		end
		if #part:GetChildren() > 0 then
			table.insert(wrong, `it has {#part:GetChildren()} children`)
		end
		if spec.color ~= nil and colorText(part.Color) ~= colorText(spec.color) then
			table.insert(wrong, `Color is {colorText(part.Color)}, expected {colorText(spec.color)}`)
		end
		if #wrong > 0 then
			table.insert(problems, `{recorded.name}: {table.concat(wrong, ", ")}`)
		end
	end
	return problems
end

-- A new folder with all `records`, built away from the Workspace.
local function makeFolder(name: string, records: { FolderRecord }, look: { [string]: any }, color: Color3): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, recorded in records do
		local part = Instance.new(recorded.className) :: BasePart
		part.Name = recorded.name
		part.Size = recorded.size
		part.CFrame = recorded.cframe
		for property, value in look do
			(part :: any)[property] = value
		end
		part.Material = SHOWN_MATERIAL
		part.Color = color
		part.CollisionGroup = "Default"
		part.Parent = folder
	end
	return folder
end

local function childrenNamed(parent: Instance, name: string): number
	local count = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			count += 1
		end
	end
	return count
end

----------------------------------------------------------------------------------------------------------------------
-- Section 3b and 3c: the cave's patches and the cave skirt (stuck safety Task 22, step 22-9; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------
-- Why: under his cushion there is a cave (x -21 to 21, y 16 to 44, z 45.5 to 60) where a body fits and can get stuck.
-- It is closed off with 61 blocks, all measured in step 22-8e (the lid), 22-8f2 and 22-8h2 on trial copies, and made into
-- the final numbers in step 22-8e6 (files t22/patches.txt and t22/skirt.txt):
--   3b. 41 invisible patches (strips and the fill behind the skirt), named Patch_Cave_<n>, in the new folder
--       World.WalkSurfaces.Patches. They have the steep guards' settings (step 22-0): Transparency 1, CanCollide, CanQuery,
--       CanTouch off, CastShadow off, SmoothPlastic, collision group Default, Anchored.
--   3c. 20 visible blocks, the cave skirt, named CaveSkirt_<n>, in the new folder World.CaveSkirt (the panel ruling after
--       the rule C rerun: what players see is what they bump into). They are in collision group Default, so players bump
--       into them, and have designer's look: SmoothPlastic, #C2383E, no MaterialVariant, no texture, CastShadow off.
-- None of the 61 blocks is turned. The small places went to Task 23, so every block here is in the cave.
-- It knows three worlds for each folder, and changes nothing on any difference:
--   (a) before: the folder is missing (and no block named like these stands anywhere in World). The folder is made.
--   (b) after: the folder holds exactly its blocks, each within 0.01 studs of the recorded size and place, unturned, with
--       its settings. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- Both folders are checked before anything is changed. The change runs between two ChangeHistoryService waypoints, with
-- the folders built away from the Workspace first, and is checked again afterwards.
local function sectionFolderRecords(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local PATCH_FOLDER_NAME = "Patches" -- under World.WalkSurfaces
	local SKIRT_FOLDER_NAME = "CaveSkirt" -- under World
	local PATCH_NAME_PATTERN = "^Patch_Cave_%d+$"
	local SKIRT_NAME_PATTERN = "^CaveSkirt_%d+$"
	local CAVE_PLACE = "cave" -- the small places went to Task 23
	local TURN_TOLERANCE = 0.001 -- how far a block's axes may differ from unturned
	-- The steep guards' settings, measured in step 22-0 (all 30 identical): Part, Transparency 1, CanCollide, CanQuery,
	-- CanTouch off, CastShadow off, SmoothPlastic, group Default, Anchored, Archivable.
	local PATCH_LOOK: { [string]: any } = {
		Transparency = 1,
		CanCollide = true,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		Anchored = true,
		Archivable = true,
	}
	-- designer on the cave skirt's look, decisions-plans.md (the same named values as the test "the cave skirt is drawn and
	-- solid"). CanTouch is on, because players bump into it like any wall.
	local SKIRT_LOOK: { [string]: any } = {
		Transparency = 0,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = false,
		Anchored = true,
		Archivable = true,
	}
	local SKIRT_COLOR = Color3.fromRGB(194, 56, 62) -- #C2383E

	-- One block as recorded: name, size, then place of the middle (measured in step 22-8e, final numbers of step 22-8h2).
	local function block(
		name: string,
		sizeX: number,
		sizeY: number,
		sizeZ: number,
		x: number,
		y: number,
		z: number
	): FolderRecord
		return {
			name = name,
			className = "Part",
			size = Vector3.new(sizeX, sizeY, sizeZ),
			cframe = CFrame.new(x, y, z),
			place = CAVE_PLACE,
		}
	end
	-- Measured in step 22-8e. The strips across the cave (1 to 14), the front fill (15 to 28) and the upper fill (29 to 41).
	local PATCHES: { FolderRecord } = {
		block("Patch_Cave_1", 1, 5.88, 10, -21.5, 23.2241, 54.5),
		block("Patch_Cave_2", 1, 7.199, 10, -20.5, 24.0633, 54.5),
		block("Patch_Cave_3", 1, 8.498, 10, -19.5, 24.8899, 54.5),
		block("Patch_Cave_4", 2, 9.826, 10, -18, 25.701, 54.5),
		block("Patch_Cave_5", 3, 11.695, 10, -15.5, 26.9302, 54.5),
		block("Patch_Cave_6", 4, 13.425, 10, -12, 28.169, 54.5),
		block("Patch_Cave_7", 20, 14.995, 10, 0, 29.3433, 54.5),
		block("Patch_Cave_8", 4, 13.447, 10, 12, 28.1801, 54.5),
		block("Patch_Cave_9", 3, 11.925, 10, 15.5, 27.0445, 54.5),
		block("Patch_Cave_10", 1, 10.926, 10, 17.5, 26.3978, 54.5),
		block("Patch_Cave_11", 1, 9.618, 10, 18.5, 25.597, 54.5),
		block("Patch_Cave_12", 1, 8.344, 10, 19.5, 24.813, 54.5),
		block("Patch_Cave_13", 1, 7.109, 10, 20.5, 24.0166, 54.5),
		block("Patch_Cave_14", 1, 5.801, 10, 21.5, 23.1721, 54.5),
		block("Patch_Cave_15", 1, 6.267, 1.25, -22.5, 18.6844, 46.375),
		block("Patch_Cave_16", 1, 9.04, 1.25, -21.5, 20.5378, 46.375),
		block("Patch_Cave_17", 1.5, 12.14, 1.25, -20.25, 22.287, 46.375),
		block("Patch_Cave_18", 2, 14.922, 1.25, -18.5, 23.9393, 46.375),
		block("Patch_Cave_19", 3, 17.572, 1.25, -16, 25.5651, 46.375),
		block("Patch_Cave_20", 4, 19.556, 1.25, -12.5, 26.9531, 46.375),
		block("Patch_Cave_21", 5.5, 21.716, 1.25, -7.75, 28.4458, 46.375),
		block("Patch_Cave_22", 13.5, 22.513, 1.25, 1.75, 29.0119, 46.375),
		block("Patch_Cave_23", 4, 20.36, 1.25, 10.5, 27.5913, 46.375),
		block("Patch_Cave_24", 3.5, 18.089, 1.25, 14.25, 26.042, 46.375),
		block("Patch_Cave_25", 2.5, 15.688, 1.25, 17.25, 24.473, 46.375),
		block("Patch_Cave_26", 1.5, 12.957, 1.25, 19.25, 22.882, 46.375),
		block("Patch_Cave_27", 1.5, 10.123, 1.25, 20.75, 21.1903, 46.375),
		block("Patch_Cave_28", 2.5, 7.636, 1.25, 22.75, 18.7765, 46.375),
		block("Patch_Cave_29", 1.5, 6.109, 2.5, -22.25, 20.2355, 48.25),
		block("Patch_Cave_30", 2, 9.414, 2.5, -20.5, 22.254, 48.25),
		block("Patch_Cave_31", 1.5, 12.427, 2.5, -18.75, 24.1907, 48.25),
		block("Patch_Cave_32", 2.5, 14.239, 2.5, -16.75, 25.3243, 48.25),
		block("Patch_Cave_33", 3, 16.123, 2.5, -14, 26.6201, 48.25),
		block("Patch_Cave_34", 4, 17.816, 2.5, -10.5, 27.8161, 48.25),
		block("Patch_Cave_35", 16.5, 19.433, 2.5, -0.25, 28.9634, 48.25),
		block("Patch_Cave_36", 4, 17.888, 2.5, 10, 27.9019, 48.25),
		block("Patch_Cave_37", 3, 16.136, 2.5, 13.5, 26.6851, 48.25),
		block("Patch_Cave_38", 3, 14.001, 2.5, 16.5, 25.2057, 48.25),
		block("Patch_Cave_39", 2, 11.237, 2.5, 19, 23.5209, 48.25),
		block("Patch_Cave_40", 2, 8.238, 2.5, 21, 21.5745, 48.25),
		block("Patch_Cave_41", 2, 6.335, 2.5, 23, 19.9084, 48.25),
	}
	-- Measured in step 22-8e, fronts pulled back in steps 22-8f2 and 22-8h2. Every top is at or under y 47.0.
	local SKIRT: { FolderRecord } = {
		block("CaveSkirt_1", 4.897, 21.639, 4, -20.9486, 34.9456, 43.75),
		block("CaveSkirt_2", 3.2, 21.036, 1.15, -17.5, 36.482, 45.175),
		block("CaveSkirt_3", 2.2, 21.027, 1.15, -15, 36.4865, 45.175),
		block("CaveSkirt_4", 3.2, 12.6, 1.15, -12.5, 32.2861, 45.175),
		block("CaveSkirt_5", 3.2, 14.925, 1.15, -9.5, 33.4485, 45.175),
		block("CaveSkirt_6", 1.2, 16.872, 1.15, -7.5, 34.3831, 45.175),
		block("CaveSkirt_7", 2.2, 17.476, 1.15, -6, 34.6501, 45.175),
		block("CaveSkirt_8", 2.2, 17.864, 1.15, -4, 34.7739, 45.175),
		block("CaveSkirt_9", 8.2, 19.206, 1, 1, 34.9274, 45.25),
		block("CaveSkirt_10", 2.2, 17.81, 1.5, 6, 34.8866, 45),
		block("CaveSkirt_11", 1.2, 17.382, 2, 7.5, 34.7313, 44.75),
		block("CaveSkirt_12", 1.2, 16.482, 2.5, 8.5, 34.2877, 44.5),
		block("CaveSkirt_13", 1.2, 15.574, 3, 9.5, 34.0488, 44.25),
		block("CaveSkirt_14", 1.2, 15.291, 2.5, 10.5, 33.5423, 44.5),
		block("CaveSkirt_15", 1.2, 14.706, 3, 11.5, 33.1006, 44.25),
		block("CaveSkirt_16", 1.2, 17.931, 3.5, 12.5, 34.5616, 44),
		block("CaveSkirt_17", 1.2, 21.818, 4, 13.5, 36.0911, 43.75),
		block("CaveSkirt_18", 1.2, 22.236, 4.5, 14.5, 35.882, 43.5),
		block("CaveSkirt_19", 4.2, 27.562, 4.5, 17, 33.219, 43.5),
		block("CaveSkirt_20", 5.558, 23.473, 5.25, 21.279, 31.175, 43.125),
	}

	local function largestGap(difference: Vector3): number
		return math.max(math.abs(difference.X), math.abs(difference.Y), math.abs(difference.Z))
	end
	-- Size, place and turn, with this section's own tolerances.
	local function caveGeometry(part: BasePart, recorded: FolderRecord): { string }
		local wrong: { string } = {}
		local sizeGap = largestGap(part.Size - recorded.size)
		if sizeGap > PLACE_TOLERANCE then
			table.insert(wrong, `size is off by {string.format("%.3f", sizeGap)}`)
		end
		local placeGap = largestGap(part.Position - recorded.cframe.Position)
		if placeGap > PLACE_TOLERANCE then
			table.insert(wrong, `place is off by {string.format("%.3f", placeGap)}`)
		end
		local cframe = part.CFrame
		if
			(cframe.XVector - Vector3.xAxis).Magnitude > TURN_TOLERANCE
			or (cframe.YVector - Vector3.yAxis).Magnitude > TURN_TOLERANCE
			or (cframe.ZVector - Vector3.zAxis).Magnitude > TURN_TOLERANCE
		then
			table.insert(wrong, "it is turned")
		end
		return wrong
	end
	local PATCH_SPEC: FolderSpec = { look = PATCH_LOOK, color = nil, geometry = caveGeometry }
	local SKIRT_SPEC: FolderSpec = { look = SKIRT_LOOK, color = SKIRT_COLOR, geometry = caveGeometry }

	-- Which world is it?
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if world == nil or walk == nil then
		error("nothing was changed. World.WalkSurfaces is missing")
	end
	local patchFolder = walk:FindFirstChild(PATCH_FOLDER_NAME)
	local skirtFolder = world:FindFirstChild(SKIRT_FOLDER_NAME)
	local problems: { string } = {}
	if childrenNamed(walk, PATCH_FOLDER_NAME) > 1 then
		table.insert(problems, `World.WalkSurfaces has {childrenNamed(walk, PATCH_FOLDER_NAME)} folders called Patches`)
	end
	if childrenNamed(world, SKIRT_FOLDER_NAME) > 1 then
		table.insert(problems, `World has {childrenNamed(world, SKIRT_FOLDER_NAME)} folders called CaveSkirt`)
	end
	local strays: { string } = {}
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BasePart") then
			local likePatch = string.match(descendant.Name, PATCH_NAME_PATTERN) ~= nil
			local likeSkirt = string.match(descendant.Name, SKIRT_NAME_PATTERN) ~= nil
			if (likePatch and descendant.Parent ~= patchFolder) or (likeSkirt and descendant.Parent ~= skirtFolder) then
				table.insert(strays, descendant:GetFullName())
			end
		end
	end
	if #strays > 0 then
		table.insert(
			problems,
			`{#strays} parts named like the patches or the skirt stand outside their folders: {someProblems(strays)}`
		)
	end
	if patchFolder ~= nil then
		for _, text in folderProblems(patchFolder, PATCHES, PATCH_SPEC) do
			table.insert(problems, `3b {text}`)
		end
	end
	if skirtFolder ~= nil then
		for _, text in folderProblems(skirtFolder, SKIRT, SKIRT_SPEC) do
			table.insert(problems, `3c {text}`)
		end
	end
	if #problems > 0 then
		error(
			`nothing was changed. This is neither the world before nor the world after sections 3b and 3c: {someProblems(
				problems
			)}`
		)
	end
	local patchesText = countsText(PATCHES)
	local skirtText = countsText(SKIRT)
	if patchFolder ~= nil and skirtFolder ~= nil then
		return `already done: World.WalkSurfaces.Patches holds {patchesText} and World.CaveSkirt holds {skirtText}, all as recorded`
	end

	-- The change itself: build what is missing away from the Workspace, then put it in between two waypoints.
	local newPatches: Folder? = if patchFolder == nil
		then makeFolder(PATCH_FOLDER_NAME, PATCHES, PATCH_LOOK, GUARD_COLOR)
		else nil
	local newSkirt: Folder? = if skirtFolder == nil
		then makeFolder(SKIRT_FOLDER_NAME, SKIRT, SKIRT_LOOK, SKIRT_COLOR)
		else nil
	local descendantsBefore = #world:GetDescendants()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3b: before")
	end)
	local changed, whyNot = pcall(function()
		if newPatches ~= nil then
			newPatches.Parent = walk
		end
		if newSkirt ~= nil then
			newSkirt.Parent = world
		end
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 3b: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 3b: before") and tell code_lead`
		)
	end

	-- The same check afterwards, on the live folders.
	local wrong: { string } = {}
	local livePatches = walk:FindFirstChild(PATCH_FOLDER_NAME)
	local liveSkirt = world:FindFirstChild(SKIRT_FOLDER_NAME)
	if livePatches == nil then
		table.insert(wrong, "World.WalkSurfaces.Patches is missing")
	else
		for _, text in folderProblems(livePatches, PATCHES, PATCH_SPEC) do
			table.insert(wrong, `3b {text}`)
		end
	end
	if liveSkirt == nil then
		table.insert(wrong, "World.CaveSkirt is missing")
	else
		for _, text in folderProblems(liveSkirt, SKIRT, SKIRT_SPEC) do
			table.insert(wrong, `3c {text}`)
		end
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	return string.format(
		"made %s%s%s; World now has %d descendants (%d before). Patches: %s. Skirt: %s",
		if newPatches ~= nil then "World.WalkSurfaces.Patches" else "",
		if newPatches ~= nil and newSkirt ~= nil then " and " else "",
		if newSkirt ~= nil then "World.CaveSkirt" else "",
		#world:GetDescendants(),
		descendantsBefore,
		patchesText,
		skirtText
	)
end

----------------------------------------------------------------------------------------------------------------------
-- Section 4: slide guards and small patches (stuck safety Task 23, step 23-10; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------
-- Why: after sections 3b and 3c a few small places still trap a player: a steep island on the cushion's back, a notch
-- beside the cushion, two beard pockets, a groove under his nightcap's brim and a wedge slot under his head's side
-- overhang. 88 invisible parts, measured in steps 23-8 to 23-C3 (files t23/trial-parts.txt, fix-b.txt and fix-c.txt)
-- and accepted by code_lead's Rulings 12 to 18 (docs/specs/v2/research/decisions-plans.md):
--   - 3 slide guards, named SlideGuard_<Place>_<n>, in the new folder World.WalkSurfaces.SlideGuards. Each is a WedgePart
--     with a face 76 degrees steep, so a player slides off the steep island instead of standing on it.
--   - 85 small patches, named Patch_<Place>_<n>, in the new folder World.WalkSurfaces.SmallPatches: the 39 notch boxes
--     and the 46 boxes that fill the groove and the slot. (Section 3b's folder Patches is not touched: it holds only
--     what section 3b recorded.)
-- Three places moved to Task 29 (Ruling 18) and are not made here: SlideGuard_ForeheadBand_1, SlideGuard_BeardPocket_1
-- and Ramp_Sock_1.
-- Every part has the steep guards' settings (step 22-0): Transparency 1, CanCollide, CanQuery, CanTouch off, CastShadow
-- off, SmoothPlastic, collision group Default, Anchored, Archivable on (Archivable on, so the place file keeps them).
-- It knows three worlds, and changes nothing on any difference:
--   (a) before: neither folder is there (and no part named like these stands anywhere in World). The folders are made.
--   (b) after: both folders hold exactly the recorded parts, each within the file's size and place tolerance, with its
--       settings. It says "already done".
--   (c) anything else: it stops with nothing changed and names what differs.
-- Both folders are checked before anything is changed. The change runs between two ChangeHistoryService waypoints, with
-- the folders built away from the Workspace first, and is checked again afterwards.
local function sectionSlideGuards(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local GUARD_FOLDER = "SlideGuards" -- under World.WalkSurfaces
	local SMALL_FOLDER = "SmallPatches" -- under World.WalkSurfaces
	-- A part named like this (or like any recorded name) may stand in World only inside one of the two folders.
	local STRAY_PREFIX = "SlideGuard_"
	local PART_LOOK: { [string]: any } = {
		Transparency = 1,
		CanCollide = true,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		Anchored = true,
		Archivable = true,
	}

	-- "<Place>" of "SlideGuard_<Place>_<n>" or "Patch_<Place>_<n>".
	local function placeOf(name: string): string
		return string.match(name, "^%a+_(%a+)_%d+$") or name
	end
	-- A block, unturned.
	local function block(
		name: string,
		sizeX: number,
		sizeY: number,
		sizeZ: number,
		x: number,
		y: number,
		z: number
	): FolderRecord
		return {
			name = name,
			className = "Part",
			size = Vector3.new(sizeX, sizeY, sizeZ),
			cframe = CFrame.new(x, y, z),
			place = placeOf(name),
		}
	end
	-- A wedge whose sloped face looks toward (outwardX, outwardZ) and leans up toward the giant. A WedgePart is full
	-- height on its local +Z side, so local +Z points into the body: the opposite of outward.
	local function wedge(
		name: string,
		sizeX: number,
		sizeY: number,
		sizeZ: number,
		x: number,
		y: number,
		z: number,
		outwardX: number,
		outwardZ: number
	): FolderRecord
		local intoBody = -Vector3.new(outwardX, 0, outwardZ).Unit
		return {
			name = name,
			className = "WedgePart",
			size = Vector3.new(sizeX, sizeY, sizeZ),
			cframe = CFrame.fromMatrix(Vector3.new(x, y, z), -intoBody:Cross(Vector3.yAxis), Vector3.yAxis, intoBody),
			place = placeOf(name),
		}
	end

	-- Measured in steps 23-8b and 23-C1 (fix-b.txt, trial-parts.txt); BeardPocket_1 and ForeheadBand_1 went to Task 29.
	local GUARDS: { FolderRecord } = {
		wedge("SlideGuard_Cushion_1", 2.4, 6.016, 1.5, -16.4, 22.462, 40.36, 0, -1),
		wedge("SlideGuard_BeardPocket_2", 2.4, 2.232, 0.556, 7.208, 81.432, -11.009, 0.6615, -0.7499),
		wedge("SlideGuard_BeardPocket_3", 2.4, 3.396, 0.847, 9.207, 77.726, -13.01, 0.579, -0.8153),
	}
	-- Measured in steps 23-8b (the notch, refit B, Ruling 12) and 23-C2 (the groove and the slot, Ruling 17). The notch is
	-- 39 boxes, the groove 18 and the slot 28. Ramp_Sock_1 went to Task 29.
	local PATCHES: { FolderRecord } = {
		block("Patch_Notch_1", 0.25, 5.6, 0.25, -10.75, 26.224, 41.25),
		block("Patch_Notch_2", 0.25, 6.141, 0.5, -10.5, 25.599, 41.125),
		block("Patch_Notch_3", 0.25, 6.326, 0.75, -10.25, 25.68, 41.25),
		block("Patch_Notch_4", 0.25, 5.866, 0.75, -10, 25.557, 41.25),
		block("Patch_Notch_5", 0.25, 7.024, 1.25, -9.75, 25.152, 41.25),
		block("Patch_Notch_6", 0.25, 7.555, 1.75, -9.5, 24.344, 41),
		block("Patch_Notch_7", 0.25, 8.109, 2.25, -9.25, 24.226, 41),
		block("Patch_Notch_8", 0.25, 8.284, 2.5, -9, 24.298, 41.125),
		block("Patch_Notch_9", 0.25, 7.998, 2.75, -8.75, 23.753, 41),
		block("Patch_Notch_10", 0.25, 8.486, 3.25, -8.5, 23.596, 41),
		block("Patch_Notch_11", 0.25, 6.827, 2, -8.25, 22.751, 40.375),
		block("Patch_Notch_12", 0.25, 6.984, 2, -8, 22.427, 40.125),
		block("Patch_Notch_13", 0.25, 6.969, 2.25, -7.75, 22.018, 40),
		block("Patch_Notch_14", 0.5, 6.801, 2.5, -7.375, 21.595, 39.875),
		block("Patch_Notch_15", 0.5, 6.845, 2.75, -6.875, 21.207, 39.75),
		block("Patch_Notch_16", 0.5, 6.56, 2.75, -6.375, 21.087, 39.75),
		block("Patch_Notch_17", 0.25, 6.221, 2.5, -6, 20.94, 39.625),
		block("Patch_Notch_18", 0.25, 6.082, 2.75, -5.75, 20.882, 39.75),
		block("Patch_Notch_19", 1.75, 6.576, 2.75, -4.75, 20.573, 39.5),
		block("Patch_Notch_20", 0.75, 6.234, 2.75, -3.5, 20.482, 39.5),
		block("Patch_Notch_21", 0.5, 6.224, 3, -2.875, 20.511, 39.625),
		block("Patch_Notch_22", 0.25, 6.229, 2.75, -2.5, 20.536, 39.5),
		block("Patch_Notch_23", 1.25, 6.414, 3, -1.75, 20.64, 39.625),
		block("Patch_Notch_24", 0.25, 6.474, 3, -1, 20.697, 39.625),
		block("Patch_Notch_25", 0.75, 6.597, 3.25, -0.5, 20.719, 39.75),
		block("Patch_Notch_26", 0.25, 8.212, 3.75, 0, 21.515, 40),
		block("Patch_Notch_27", 0.5, 8.286, 3.5, 0.375, 21.535, 39.875),
		block("Patch_Notch_28", 3, 6.992, 3, 2.125, 20.786, 39.625),
		block("Patch_Notch_29", 0.25, 7.032, 3, 3.75, 20.797, 39.625),
		block("Patch_Notch_30", 0.25, 7.141, 2.75, 4, 20.843, 39.5),
		block("Patch_Notch_31", 0.75, 6.776, 2.5, 4.5, 21.247, 39.625),
		block("Patch_Notch_32", 0.5, 6.937, 2.75, 5.125, 21.31, 39.75),
		block("Patch_Notch_33", 0.25, 8.252, 3.75, 5.5, 21.96, 40.25),
		block("Patch_Notch_34", 0.5, 6.685, 2.5, 5.875, 21.623, 39.875),
		block("Patch_Notch_35", 0.25, 6.441, 2.25, 6.25, 21.905, 40),
		block("Patch_Notch_36", 0.25, 6.626, 2.5, 6.5, 21.962, 40.125),
		block("Patch_Notch_37", 0.25, 6.362, 2.25, 6.75, 22.234, 40.25),
		block("Patch_Notch_38", 0.5, 6.271, 2, 7.125, 22.556, 40.375),
		block("Patch_Notch_39", 0.25, 6.007, 1.75, 7.5, 22.828, 40.5),
		block("Patch_Groove_1", 0.75, 6.63, 0.25, 1.75, 114.766, 9),
		block("Patch_Groove_2", 2.5, 6.843, 0.25, -2.625, 114.789, 9.25),
		block("Patch_Groove_3", 1.75, 6.591, 0.25, 1.25, 114.936, 9.25),
		block("Patch_Groove_4", 3.5, 6.867, 0.25, -2.125, 114.962, 9.5),
		block("Patch_Groove_5", 2.5, 6.509, 0.25, 1.125, 115.066, 9.5),
		block("Patch_Groove_6", 6.5, 6.831, 0.25, -0.875, 115.062, 9.75),
		block("Patch_Groove_7", 6.75, 6.767, 0.5, -0.75, 115.19, 10.125),
		block("Patch_Groove_8", 7, 6.628, 1.25, -0.875, 115.399, 11),
		block("Patch_Groove_9", 6.75, 5.813, 0.5, -0.75, 115.833, 11.875),
		block("Patch_Groove_10", 6.5, 5.516, 0.25, -0.875, 115.995, 12.25),
		block("Patch_Groove_11", 6.25, 5.34, 0.25, -0.75, 116.096, 12.5),
		block("Patch_Groove_12", 6, 5.199, 0.25, -0.875, 116.18, 12.75),
		block("Patch_Groove_13", 5.75, 5.022, 0.25, -0.75, 116.282, 13),
		block("Patch_Groove_14", 5.25, 4.846, 0.25, -0.75, 116.384, 13.25),
		block("Patch_Groove_15", 4.75, 4.686, 0.25, -0.75, 116.477, 13.5),
		block("Patch_Groove_16", 4.25, 4.55, 0.25, -0.75, 116.57, 13.75),
		block("Patch_Groove_17", 3.75, 4.423, 0.25, -0.75, 116.661, 14),
		block("Patch_Groove_18", 2.5, 4.27, 0.25, -0.875, 116.751, 14.25),
		block("Patch_Slot_1", 0.25, 7.903, 2.25, 19, 55.121, 6.75),
		block("Patch_Slot_2", 0.25, 8.645, 4.25, 19.25, 55.467, 7),
		block("Patch_Slot_3", 0.25, 8.85, 5, 19.5, 55.746, 7.125),
		block("Patch_Slot_4", 0.25, 8.88, 5.5, 19.75, 56.113, 7.125),
		block("Patch_Slot_5", 0.25, 9.189, 6.25, 20, 56.341, 7.25),
		block("Patch_Slot_6", 0.5, 9.257, 7.5, 20.375, 56.727, 7.125),
		block("Patch_Slot_7", 0.5, 9.325, 8.5, 20.875, 56.84, 7.375),
		block("Patch_Slot_8", 0.5, 9.449, 9.25, 21.375, 56.957, 7.5),
		block("Patch_Slot_9", 0.5, 9.584, 10, 21.875, 57.081, 7.625),
		block("Patch_Slot_10", 0.5, 10.173, 10.75, 22.375, 57.019, 7.75),
		block("Patch_Slot_11", 0.75, 10.551, 11.25, 23, 57.188, 7.75),
		block("Patch_Slot_12", 0.5, 10.996, 11.5, 23.625, 57.391, 7.875),
		block("Patch_Slot_13", 0.5, 10.598, 11.5, 24.125, 58.02, 7.875),
		block("Patch_Slot_14", 0.5, 10.379, 11.5, 24.625, 58.539, 7.875),
		block("Patch_Slot_15", 0.25, 4.169, 0.5, 24.75, 58.178, 15.875),
		block("Patch_Slot_16", 0.25, 7.922, 13.5, 25, 60.021, 8.875),
		block("Patch_Slot_17", 0.25, 8.186, 13, 25.25, 60.12, 8.625),
		block("Patch_Slot_18", 0.25, 8.783, 13, 25.5, 60.122, 8.625),
		block("Patch_Slot_19", 0.25, 9.412, 13, 25.75, 60.14, 8.625),
		block("Patch_Slot_20", 0.25, 8.089, 7.5, 26, 60.6, 5.875),
		block("Patch_Slot_21", 0.25, 9.359, 4.25, 26, 59.685, 13.25),
		block("Patch_Slot_22", 0.25, 8.053, 6.75, 26.25, 60.417, 5.75),
		block("Patch_Slot_23", 0.25, 8.728, 2.25, 26.25, 59.073, 14.25),
		block("Patch_Slot_24", 0.5, 8.429, 6.25, 26.625, 60.425, 6),
		block("Patch_Slot_25", 0.5, 8.469, 5.75, 27.125, 60.45, 5.75),
		block("Patch_Slot_26", 0.25, 6.339, 0.25, 27.5, 59.812, 4),
		block("Patch_Slot_27", 0.25, 6.438, 0.25, 27.5, 60.36, 6),
		block("Patch_Slot_28", 0.25, 7.662, 0.25, 27.5, 60.889, 8),
	}

	local function slideGeometry(part: BasePart, recorded: FolderRecord): { string }
		local same, why = sameAs(part, recorded.size, recorded.cframe)
		return if same then {} else { why }
	end
	local SLIDE_SPEC: FolderSpec = { look = PART_LOOK, color = nil, geometry = slideGeometry }

	-- Which world is it?
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if world == nil or walk == nil then
		error("nothing was changed. World.WalkSurfaces is missing")
	end
	local guardFolder = walk:FindFirstChild(GUARD_FOLDER)
	local smallFolder = walk:FindFirstChild(SMALL_FOLDER)
	local problems: { string } = {}
	for _, folderName in { GUARD_FOLDER, SMALL_FOLDER } do
		if childrenNamed(walk, folderName) > 1 then
			table.insert(
				problems,
				`World.WalkSurfaces has {childrenNamed(walk, folderName)} folders called {folderName}`
			)
		end
	end
	if (guardFolder == nil) ~= (smallFolder == nil) then
		table.insert(problems, `only one of the folders {GUARD_FOLDER} and {SMALL_FOLDER} is there`)
	end
	local homeOf: { [string]: string } = {} -- recorded name -> the name of the folder it belongs in
	for _, recorded in GUARDS do
		homeOf[recorded.name] = GUARD_FOLDER
	end
	for _, recorded in PATCHES do
		homeOf[recorded.name] = SMALL_FOLDER
	end
	local strays: { string } = {}
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BasePart") then
			local home = homeOf[descendant.Name]
			if home ~= nil or string.sub(descendant.Name, 1, #STRAY_PREFIX) == STRAY_PREFIX then
				local parent = descendant.Parent
				local inHome = parent ~= nil
					and parent.Parent == walk
					and (
						parent.Name == home
						or (home == nil and (parent.Name == GUARD_FOLDER or parent.Name == SMALL_FOLDER))
					)
				if not inHome then
					table.insert(strays, descendant:GetFullName())
				end
			end
		end
	end
	if #strays > 0 then
		table.insert(
			problems,
			`{#strays} parts named like the guards or the small patches stand outside their folders: {someProblems(
				strays
			)}`
		)
	end
	if guardFolder ~= nil then
		for _, text in folderProblems(guardFolder, GUARDS, SLIDE_SPEC) do
			table.insert(problems, `4 {text}`)
		end
	end
	if smallFolder ~= nil then
		for _, text in folderProblems(smallFolder, PATCHES, SLIDE_SPEC) do
			table.insert(problems, `4 {text}`)
		end
	end
	if #problems > 0 then
		error(
			`nothing was changed. This is neither the world before nor the world after section 4: {someProblems(
				problems
			)}`
		)
	end
	local guardsText = countsText(GUARDS)
	local patchesText = countsText(PATCHES)
	if guardFolder ~= nil and smallFolder ~= nil then
		return `already done: World.WalkSurfaces.SlideGuards holds {guardsText} and World.WalkSurfaces.SmallPatches holds {patchesText}, all as recorded`
	end

	-- The change itself: build both folders away from the Workspace, then put them in between two waypoints.
	local newGuards = makeFolder(GUARD_FOLDER, GUARDS, PART_LOOK, GUARD_COLOR)
	local newPatches = makeFolder(SMALL_FOLDER, PATCHES, PART_LOOK, GUARD_COLOR)
	local descendantsBefore = #world:GetDescendants()
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 4: before")
	end)
	local changed, whyNot = pcall(function()
		newGuards.Parent = walk
		newPatches.Parent = walk
	end)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 4: after")
	end)
	if not changed then
		error(
			`the change stopped half way ({tostring(whyNot)}). Undo it in Studio (Ctrl+Z, back to the waypoint "15-real-shape section 4: before") and tell code_lead`
		)
	end

	-- The same check afterwards, on the live folders.
	local wrong: { string } = {}
	local liveGuards = walk:FindFirstChild(GUARD_FOLDER)
	local liveSmall = walk:FindFirstChild(SMALL_FOLDER)
	if liveGuards == nil then
		table.insert(wrong, "World.WalkSurfaces.SlideGuards is missing")
	else
		for _, text in folderProblems(liveGuards, GUARDS, SLIDE_SPEC) do
			table.insert(wrong, `4 {text}`)
		end
	end
	if liveSmall == nil then
		table.insert(wrong, "World.WalkSurfaces.SmallPatches is missing")
	else
		for _, text in folderProblems(liveSmall, PATCHES, SLIDE_SPEC) do
			table.insert(wrong, `4 {text}`)
		end
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	return string.format(
		"made World.WalkSurfaces.SlideGuards and World.WalkSurfaces.SmallPatches; World now has %d descendants (%d before). Guards: %s. Small patches: %s",
		#world:GetDescendants(),
		descendantsBefore,
		guardsText,
		patchesText
	)
end

local ok, message = pcall(sectionHisRealShape)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
local okWalk, walkMessage = pcall(sectionWalkPieces)
if not okWalk then
	return "SECTION 1: " .. message .. "\nSTOPPED WITH AN ERROR in section 2: " .. tostring(walkMessage)
end
local okHead, headMessage = pcall(sectionHead)
if not okHead then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSTOPPED WITH AN ERROR in section 2b: "
		.. tostring(headMessage)
end
local okZone, zoneMessage = pcall(sectionZone)
if not okZone then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSTOPPED WITH AN ERROR in section 2c: "
		.. tostring(zoneMessage)
end
local okRails, railsMessage = pcall(sectionRailTops)
if not okRails then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSTOPPED WITH AN ERROR in section 2d: "
		.. tostring(railsMessage)
end
local okFoot, footMessage = pcall(sectionBeardFoot)
if not okFoot then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSTOPPED WITH AN ERROR in section 2e: "
		.. tostring(footMessage)
end
local okBody, bodyMessage = pcall(sectionBodyFollowsSkin)
if not okBody then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSTOPPED WITH AN ERROR in section 2f: "
		.. tostring(bodyMessage)
end
local okCloser, closerMessage = pcall(sectionCloserFit)
if not okCloser then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSTOPPED WITH AN ERROR in section 2f2: "
		.. tostring(closerMessage)
end
local okSlot, slotMessage = pcall(sectionSlotBlocks)
if not okSlot then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSTOPPED WITH AN ERROR in section 2f3: "
		.. tostring(slotMessage)
end
local okTruss, trussMessage = pcall(sectionTrussAndPartB)
if not okTruss then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSTOPPED WITH AN ERROR in section 2f4: "
		.. tostring(trussMessage)
end
local okLegs, legsMessage = pcall(sectionLegsCloserFit)
if not okLegs then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSTOPPED WITH AN ERROR in section 2f5: "
		.. tostring(legsMessage)
end
local okSwing, swingMessage = pcall(sectionTrussSwing)
if not okSwing then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSECTION 2f5: "
		.. legsMessage
		.. "\nSTOPPED WITH AN ERROR in section 2f6: "
		.. tostring(swingMessage)
end
local okBelly, bellyMessage = pcall(sectionBeardBelly)
if not okBelly then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSECTION 2f5: "
		.. legsMessage
		.. "\nSECTION 2f6: "
		.. swingMessage
		.. "\nSTOPPED WITH AN ERROR in section 2g: "
		.. tostring(bellyMessage)
end
local okPillow, pillowMessage = pcall(sectionPillowCloserFit)
if not okPillow then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSECTION 2f5: "
		.. legsMessage
		.. "\nSECTION 2f6: "
		.. swingMessage
		.. "\nSECTION 2g: "
		.. bellyMessage
		.. "\nSTOPPED WITH AN ERROR in section 3a: "
		.. tostring(pillowMessage)
end
local okLit, litMessage = pcall(sectionLitLikeBefore)
if not okLit then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSECTION 2f5: "
		.. legsMessage
		.. "\nSECTION 2f6: "
		.. swingMessage
		.. "\nSECTION 2g: "
		.. bellyMessage
		.. "\nSECTION 3a: "
		.. pillowMessage
		.. "\nSTOPPED WITH AN ERROR in section 3a2: "
		.. tostring(litMessage)
end
local okCave, caveMessage = pcall(sectionFolderRecords)
if not okCave then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSECTION 2f5: "
		.. legsMessage
		.. "\nSECTION 2f6: "
		.. swingMessage
		.. "\nSECTION 2g: "
		.. bellyMessage
		.. "\nSECTION 3a: "
		.. pillowMessage
		.. "\nSECTION 3a2: "
		.. litMessage
		.. "\nSTOPPED WITH AN ERROR in sections 3b and 3c: "
		.. tostring(caveMessage)
end
local okGuards, guardsMessage = pcall(sectionSlideGuards)
if not okGuards then
	return "SECTION 1: "
		.. message
		.. "\nSECTION 2: "
		.. walkMessage
		.. "\nSECTION 2b: "
		.. headMessage
		.. "\nSECTION 2c: "
		.. zoneMessage
		.. "\nSECTION 2d: "
		.. railsMessage
		.. "\nSECTION 2e: "
		.. footMessage
		.. "\nSECTION 2f: "
		.. bodyMessage
		.. "\nSECTION 2f2: "
		.. closerMessage
		.. "\nSECTION 2f3: "
		.. slotMessage
		.. "\nSECTION 2f4: "
		.. trussMessage
		.. "\nSECTION 2f5: "
		.. legsMessage
		.. "\nSECTION 2f6: "
		.. swingMessage
		.. "\nSECTION 2g: "
		.. bellyMessage
		.. "\nSECTION 3a: "
		.. pillowMessage
		.. "\nSECTION 3a2: "
		.. litMessage
		.. "\nSECTIONS 3b and 3c: "
		.. caveMessage
		.. "\nSTOPPED WITH AN ERROR in section 4: "
		.. tostring(guardsMessage)
end
return "SECTION 1 (his real shape): "
	.. message
	.. "\n\nSECTION 2 (walk pieces): "
	.. walkMessage
	.. "\n\nSECTION 2b (his head): "
	.. headMessage
	.. "\n\nSECTION 2c (zone over the nose rails): "
	.. zoneMessage
	.. "\n\nSECTION 2d (rail tops and the ladder slot): "
	.. railsMessage
	.. "\n\nSECTION 2e (the beard ladder's foot): "
	.. footMessage
	.. "\n\nSECTION 2f (his body follows his skin): "
	.. bodyMessage
	.. "\n\nSECTION 2f2 (a closer fit): "
	.. closerMessage
	.. "\n\nSECTION 2f3 (the slot blocks reach his closer skin): "
	.. slotMessage
	.. "\n\nSECTION 2f4 (the beard truss 32 long, part B ends sooner): "
	.. trussMessage
	.. "\n\nSECTION 2f5 (the legs' closer fit): "
	.. legsMessage
	.. "\n\nSECTION 2f6 (the beard truss's foot swings back): "
	.. swingMessage
	.. "\n\nSECTION 2g (the beard rails reach his drawn belly): "
	.. bellyMessage
	.. "\n\nSECTION 3a (the pillow's closer fit): "
	.. pillowMessage
	.. "\n\nSECTION 3a2 (lit like before): "
	.. litMessage
	.. "\n\nSECTIONS 3b and 3c (the cave's patches and the cave skirt): "
	.. caveMessage
	.. "\n\nSECTION 4 (slide guards and small patches): "
	.. guardsMessage
