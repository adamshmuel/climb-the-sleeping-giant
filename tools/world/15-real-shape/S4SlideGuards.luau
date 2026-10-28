--!strict

----------------------------------------------------------------------------------------------------------------------
-- Section 4: slide guards and small patches (stuck safety Task 23, step 23-10; Rule 20, One collision source)
----------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Shared)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)
local FolderShared = require(script.Parent.FolderShared)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local GUARD_COLOR = Shared.GUARD_COLOR
local sameAs = Shared.sameAs
local someProblems = S2bHeadChecks.someProblems
type FolderRecord = FolderShared.FolderRecord
type FolderSpec = FolderShared.FolderSpec
local countsText = FolderShared.countsText
local folderProblems = FolderShared.folderProblems
local makeFolder = FolderShared.makeFolder
local childrenNamed = FolderShared.childrenNamed

-- Why: after sections 3b and 3c a few small places still trap a player: a steep island on the cushion's back, a notch
-- beside the cushion, two beard pockets, a groove under his nightcap's brim and a wedge slot under his head's side
-- overhang. 88 invisible parts, measured in steps 23-8 to 23-C3 (files t23/trial-parts.txt, fix-b.txt and fix-c.txt)
-- and accepted by code_lead's Rulings 12 to 18 (docs/specs/v2/research/decisions-plans.md):
--   - 3 slide guards, named SlideGuard_<Place>_<n>, in the new folder World.WalkSurfaces.SlideGuards. Each is a WedgePart
--     with a face 76 degrees steep, so a player slides off the steep island instead of standing on it.
--   - 85 small patches, named Patch_<Place>_<n>, in the new folder World.WalkSurfaces.SmallPatches: the 39 notch boxes
--     and the 46 boxes that fill the groove and the slot. (Section 3b's folder Patches is not touched: it holds only
--     what section 3b recorded.)
-- Task 29 (step 29-5, Rulings 25 and 26) added 6 more small patches, Patch_Forehead_1 to Patch_Forehead_6 (try T6; rows
-- forehead|1|... of work/t29/candidates.txt), a sealed fill under the forehead plate. Task 34 (Rulings 30 and 31) takes
-- them out again: they stood where players walk along his skin, and no trim of them cleared the walking band.
-- Task 32 (step 32-4, Rulings 24, 32 and 33) adds the Sock's way out: Ramp_Sock_1 (a wedge) and 19 sealed fill boxes,
-- Patch_Sock_1 to Patch_Sock_19, all in SmallPatches (variant 1 of work/t32/cands-2b.txt: the fill's west end cut 2
-- slices and its east end cut 2).
-- Task 37 (step 37-3, Ruling 47) adds the Sock's lip boards: 8 invisible boards, SlideGuard_Sock_1 to SlideGuard_Sock_8,
-- in SlideGuards (6 lip boards, and 2 skirts that stand under Task 35's boxes), and 6 more sealed boxes,
-- Patch_Sock_20 to Patch_Sock_25, in SmallPatches (rows board|2|... of work/t36/cands.txt, as tried in Play in Task 36).
-- Some of them are turned, so they are written with `turned`.
-- Task 33 adds one more small patch, Patch_Forehead_1: a sealed box under V1's forehead plate (the slot at (11.2, 98.2, 1);
-- numbers from work/t33/box.txt), 12.7 studs tall with its top at y 101.4, clear of the band where players walk. The beard
-- wedge at (-6.8, 81.5, -11) gets no box: it is accepted for now (spec Rule 22, "Accepted for now: the beard wedge"), and
-- the later spec "Launch polish: Beard wedge" brings its fix. SlideGuard_ForeheadBand_1 and SlideGuard_BeardPocket_1 are
-- not made.
-- Task 48 adds one more small patch, Block_R141_1: an invisible 6 x 6 x 8 box, turned 25 degrees so it
-- follows the giant's slanted skin (Lesson 56), at (56.8, 5, -1.6) inside the flowering bush that
-- tools/world/16-meadow-bush.luau places in front of R-141's notch at the giant's foot on the meadow. Meadow bushes have no
-- collision, so the box is what players meet. It is named Block_, so the patch tests (which read only Patch_ blocks) skip it,
-- and it lives here because this script owns the SmallPatches folder and counts its parts (Lesson 55).
-- So this section makes 124 parts (11 guards and 113 small patches).
-- Every part has the steep guards' settings (step 22-0): Transparency 1, CanCollide, CanQuery, CanTouch off, CastShadow
-- off, SmoothPlastic, collision group Default, Anchored, Archivable on (Archivable on, so the place file keeps them).
-- It knows seven worlds, and changes nothing on any difference:
--   (a) before: neither folder is there (and no part named like these stands anywhere in World). Both folders are made,
--       with all 123 parts.
--   (b) after Task 23 only: both folders hold exactly the 88 recorded parts, each within the file's size and place
--       tolerance, with its settings. The 20 Sock parts of Task 32 and Task 37's 14 parts are added.
--   (c) T6 as built in 29-6A: Task 23's 88 parts and the 6 forehead boxes, all as recorded. Exactly the 6 forehead boxes
--       are removed, the 20 Sock parts and Task 37's 14 parts are added, and nothing else is changed.
--   (d) after Task 32: 108 parts as recorded. Task 37's 14 parts and Task 33's box are added.
--   (e) after Task 37: all 122 parts as recorded. Task 33's one box is added.
--   (f) after Task 33: all 123 parts as recorded. Task 48's box is added.
--   (g) after Task 48: all 124 parts as recorded. It says "already done".
--   Anything else (for example only some of the 6 forehead boxes, only some of the Sock parts, or Task 37's boxes
--   without its boards) stops with nothing changed and names what differs.
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

	-- A part turned any way: its size, its centre and the 9 numbers of its turn (row by row, as CFrame.new takes them).
	local function turned(name: string, className: string, size: Vector3, centre: Vector3, r: { number }): FolderRecord
		return {
			name = name,
			className = className,
			size = size,
			cframe = CFrame.new(centre.X, centre.Y, centre.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]),
			place = placeOf(name),
		}
	end

	-- Measured in steps 23-8b and 23-C1 (fix-b.txt, trial-parts.txt); BeardPocket_1 and ForeheadBand_1 went to Tasks 29 and 33.
	local GUARDS: { FolderRecord } = {
		wedge("SlideGuard_Cushion_1", 2.4, 6.016, 1.5, -16.4, 22.462, 40.36, 0, -1),
		wedge("SlideGuard_BeardPocket_2", 2.4, 2.232, 0.556, 7.208, 81.432, -11.009, 0.6615, -0.7499),
		wedge("SlideGuard_BeardPocket_3", 2.4, 3.396, 0.847, 9.207, 77.726, -13.01, 0.579, -0.8153),
	}
	-- Measured in steps 23-8b (the notch, refit B, Ruling 12) and 23-C2 (the groove and the slot, Ruling 17). The notch is
	-- 39 boxes, the groove 18 and the slot 28. The Sock's parts are PATCHES_32 and PATCHES_37 below and the forehead fill is Task 33's.
	local PATCHES_23: { FolderRecord } = {
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

	-- Task 29, step 29-5 (Rulings 25 and 26): the forehead band's fill, try T6: 6 boxes, one per 0.25 stud slice in z,
	-- copied from the rows forehead|1|... of work/t29/candidates.txt (checked equal by a script). Task 34 takes them out
	-- (Rulings 30 and 31): they are only here to recognise the world T6 as built in 29-6A and to remove exactly these 6.
	local PATCHES_29: { FolderRecord } = {
		block("Patch_Forehead_1", 0.75, 1.882, 0.25, 7, 99.265, 0),
		block("Patch_Forehead_2", 4.25, 2.503, 0.25, 8.75, 100.261, 0.25),
		block("Patch_Forehead_3", 4.5, 6.573, 0.25, 8.875, 99.644, 0.5),
		block("Patch_Forehead_4", 4, 6.533, 0.25, 8.625, 101.082, 0.75),
		block("Patch_Forehead_5", 3.5, 6.756, 0.25, 8.625, 102.388, 1),
		block("Patch_Forehead_6", 1.25, 6.741, 0.25, 7.75, 103.813, 1.25),
	}
	local PATCHES_T6: { FolderRecord } = table.clone(PATCHES_23) -- the small patches of the world T6 as built in 29-6A
	table.move(PATCHES_29, 1, #PATCHES_29, #PATCHES_T6 + 1, PATCHES_T6)

	-- Task 32, step 32-4: the Sock's way out, variant 1 of work/t32/cands-2b.txt (T6 r9 v1z, west cut 2 slices, east cut 2;
	-- rows sock|1|... , checked equal by a script): the ramp, then 19 fill boxes, one per 0.25 stud slice in z.
	local PATCHES_32: { FolderRecord } = {
		wedge("Ramp_Sock_1", 3, 2.4, 2.86, -68.8, 2.2, -42.87, 0, 1),
		block("Patch_Sock_1", 1.25, 1.389, 0.25, -68, 6.974, -47.25),
		block("Patch_Sock_2", 4, 1.878, 0.25, -69.125, 6.967, -47),
		block("Patch_Sock_3", 6.25, 2.405, 0.25, -70.25, 6.954, -46.75),
		block("Patch_Sock_4", 8, 2.907, 0.25, -70.875, 6.954, -46.5),
		block("Patch_Sock_5", 8.25, 3.396, 0.25, -71, 6.948, -46.25),
		block("Patch_Sock_6", 8.5, 3.981, 0.25, -70.875, 6.978, -46),
		block("Patch_Sock_7", 8.75, 4.65, 0.25, -71, 6.974, -45.75),
		block("Patch_Sock_8", 9, 5.304, 0.25, -70.875, 6.973, -45.5),
		block("Patch_Sock_9", 9.25, 5.969, 0.25, -71, 6.971, -45.25),
		block("Patch_Sock_10", 9.5, 6.656, 0.25, -70.875, 6.971, -45),
		block("Patch_Sock_11", 4.25, 6.598, 0.25, -73.75, 6.965, -44.75),
		block("Patch_Sock_12", 2.75, 6.764, 0.25, -67.5, 6.924, -44.75),
		block("Patch_Sock_13", 3.5, 6.587, 0.25, -74.125, 6.962, -44.5),
		block("Patch_Sock_14", 1, 5.355, 0.25, -66.375, 6.937, -44.5),
		block("Patch_Sock_15", 3, 6.797, 0.25, -74.375, 6.959, -44.25),
		block("Patch_Sock_16", 1.25, 6.66, 0.25, -66.25, 6.916, -44.25),
		block("Patch_Sock_17", 2.5, 6.786, 0.25, -74.875, 6.955, -44),
		block("Patch_Sock_18", 1.75, 6.359, 0.25, -75.5, 6.961, -43.75),
		block("Patch_Sock_19", 1.5, 6.237, 0.25, -75.625, 6.909, -43.5),
	}
	local PATCHES_AFTER32: { FolderRecord } = table.clone(PATCHES_23) -- the small patches after Task 32 (today's world)
	table.move(PATCHES_32, 1, #PATCHES_32, #PATCHES_AFTER32 + 1, PATCHES_AFTER32)

	-- Task 37, step 37-3: the Sock's lip boards and the boxes tried with them (rows board|2|... of work/t36/cands.txt, checked
	-- equal by a script): 6 sealed boxes for SmallPatches, then 8 invisible boards for SlideGuards.
	local PATCHES_37: { FolderRecord } = {
		block("Patch_Sock_20", 1.25, 3.237, 2, -77, 3.469, -44.125),
		block("Patch_Sock_21", 0.5, 1.762, 0.75, -76.125, 2.731, -43.75),
		block("Patch_Sock_22", 1, 1.761, 1.75, -75.375, 2.73, -44.25),
		block("Patch_Sock_23", 1.75, 3.909, 1, -64.75, 3.805, -45.125),
		turned(
			"Patch_Sock_24",
			"Part",
			Vector3.new(1.5, 8.15, 1.7473),
			Vector3.new(-77.1611, 5.925, -47.6056),
			{ 0.940861, 0, -0.338793, 0, 1, 0, 0.338793, 0, 0.940861 }
		),
		turned(
			"Patch_Sock_25",
			"Part",
			Vector3.new(1.5, 8.15, 2.6852),
			Vector3.new(-76.5882, 5.925, -49.6067),
			{ 0.972144, 0, -0.234384, 0, 1, 0, 0.234384, 0, 0.972144 }
		),
	}
	local GUARDS_37: { FolderRecord } = {
		turned(
			"SlideGuard_Sock_1",
			"WedgePart",
			Vector3.new(0.678, 6.5, 0.18),
			Vector3.new(-77.9256, 5.25, -43.2765),
			{ -0.796162, 0, 0.605083, 0, 1, 0, -0.605083, 0, -0.796162 }
		),
		turned(
			"SlideGuard_Sock_2",
			"WedgePart",
			Vector3.new(0.3532, 6.5, 0.15),
			Vector3.new(-77.6132, 5.25, -43.0841),
			{ -0.987441, 0, 0.157991, 0, 1, 0, -0.157991, 0, -0.987441 }
		),
		turned(
			"SlideGuard_Sock_3",
			"WedgePart",
			Vector3.new(1.3514, 6.5, 0.11),
			Vector3.new(-76.8776, 5.25, -43.0749),
			{ -0.99885, 0, -0.047945, 0, 1, 0, 0.047945, 0, -0.99885 }
		),
		turned(
			"SlideGuard_Sock_4",
			"WedgePart",
			Vector3.new(1.3532, 8, 0.18),
			Vector3.new(-75.6315, 6, -43.1848),
			{ -0.997418, 0, -0.071814, 0, 1, 0, 0.071814, 0, -0.997418 }
		),
		turned(
			"SlideGuard_Sock_5",
			"WedgePart",
			Vector3.new(1.25, 1.712, 0.25),
			Vector3.new(-74.25, 2.706, -44),
			{ -1, 0, 0, 0, 1, 0, 0, 0, -1 }
		),
		turned(
			"SlideGuard_Sock_6",
			"WedgePart",
			Vector3.new(0.75, 1.736, 0.25),
			Vector3.new(-66.375, 2.718, -44.25),
			{ -1, 0, 0, 0, 1, 0, 0, 0, -1 }
		),
		turned(
			"SlideGuard_Sock_7",
			"WedgePart",
			Vector3.new(1.6133, 7, 0.16),
			Vector3.new(-65.2606, 5.5, -44.1393),
			{ -0.991228, 0, -0.132164, 0, 1, 0, 0.132164, 0, -0.991228 }
		),
		turned(
			"SlideGuard_Sock_8",
			"WedgePart",
			Vector3.new(0.6436, 6.5, 0.21),
			Vector3.new(-64.3277, 5.25, -44.395),
			{ -0.842271, 0, -0.539054, 0, 1, 0, 0.539054, 0, -0.842271 }
		),
	}
	local PATCHES_AFTER37: { FolderRecord } = table.clone(PATCHES_AFTER32) -- the small patches after Task 37
	table.move(PATCHES_37, 1, #PATCHES_37, #PATCHES_AFTER37 + 1, PATCHES_AFTER37)
	-- Task 33: the forehead slot's first box (work/t33/box.txt, its Patch_Forehead_1 line; its top is y 101.4). Worlds built
	-- before Task 33b hold this one.
	local PATCHES_33_FIRST: { FolderRecord } = {
		block("Patch_Forehead_1", 3.0, 12.7, 3.4, 11.2, 95.05, 1.1),
	}
	local PATCHES_FINAL: { FolderRecord } = table.clone(PATCHES_AFTER37) -- the small patches after Task 33
	table.move(PATCHES_33_FIRST, 1, #PATCHES_33_FIRST, #PATCHES_FINAL + 1, PATCHES_FINAL)
	-- Task 33b: the same box reshaped, its -z face at z -0.3 (work/t33b/measure.md line 25; only sizeZ and z changed).
	local PATCHES_33: { FolderRecord } = {
		block("Patch_Forehead_1", 3.0, 12.7, 3.10, 11.2, 95.05, 1.25),
	}
	-- Task 48: the box inside the meadow bush at R-141's notch (work/t48/designer-bush.md, item 4; fixed numbers in the handoff).
	local PATCHES_48: { FolderRecord } = {
		turned(
			"Block_R141_1",
			"Part",
			Vector3.new(6, 6, 8),
			Vector3.new(56.8, 5, -1.6),
			{ 0.9063, 0, 0.4226, 0, 1, 0, -0.4226, 0, 0.9063 }
		),
	}
	local PATCHES_ALL: { FolderRecord } = table.clone(PATCHES_FINAL) -- the small patches after Task 48 (the first box)
	table.move(PATCHES_48, 1, #PATCHES_48, #PATCHES_ALL + 1, PATCHES_ALL)
	local PATCHES_TARGET: { FolderRecord } = table.clone(PATCHES_AFTER37) -- the small patches after Task 33b (today's world)
	table.move(PATCHES_33, 1, #PATCHES_33, #PATCHES_TARGET + 1, PATCHES_TARGET)
	table.move(PATCHES_48, 1, #PATCHES_48, #PATCHES_TARGET + 1, PATCHES_TARGET)
	-- The worlds whose guard folder already holds all 11 guards (Task 37 adds the boards and the 6 boxes together).
	local HAS_ALL_GUARDS: { [string]: boolean } = { task37 = true, task33 = true, task48 = true, task33b = true }
	local GUARDS_FINAL: { FolderRecord } = table.clone(GUARDS) -- the guards after Task 37
	table.move(GUARDS_37, 1, #GUARDS_37, #GUARDS_FINAL + 1, GUARDS_FINAL)

	local function slideGeometry(part: BasePart, recorded: FolderRecord): { string }
		local same, why = sameAs(part, recorded.size, recorded.cframe)
		return if same then {} else { why }
	end
	local SLIDE_SPEC: FolderSpec = { look = PART_LOOK, color = nil, geometry = slideGeometry }

	-- Which of this section's worlds a WalkSurfaces folder holds, read from its two folders only: "before" (neither
	-- folder), "task23" (the 88 parts, no forehead box), "t6" (the 88 parts and the 6 forehead boxes), "task32" (108
	-- parts), "task37" (122 parts), "task33" (123 parts), "task48" (all 124 parts) or "task33b" (124 parts, the forehead box
	-- reshaped by Task 33b: today's world) or "other", with what differs. The guard folder holds either the 3 older guards
	-- or all 11, and it has to match the small patches (the 6 new boxes come with the 8 boards).
	local function worldOf(walk: Instance): (string, { string })
		local problems: { string } = {}
		for _, folderName in { GUARD_FOLDER, SMALL_FOLDER } do
			if childrenNamed(walk, folderName) > 1 then
				table.insert(
					problems,
					`World.WalkSurfaces has {childrenNamed(walk, folderName)} folders called {folderName}`
				)
			end
		end
		local guardFolder = walk:FindFirstChild(GUARD_FOLDER)
		local smallFolder = walk:FindFirstChild(SMALL_FOLDER)
		if guardFolder == nil and smallFolder == nil and #problems == 0 then
			return "before", problems
		end
		if (guardFolder == nil) ~= (smallFolder == nil) then
			table.insert(problems, `only one of the folders {GUARD_FOLDER} and {SMALL_FOLDER} is there`)
		end
		-- "old": Task 23's 3 guards. "new": all 11 (the 8 Sock boards of Task 37 too).
		local guardsAre = "other"
		if guardFolder ~= nil then
			local oldProblems = folderProblems(guardFolder, GUARDS, SLIDE_SPEC)
			local newProblems = folderProblems(guardFolder, GUARDS_FINAL, SLIDE_SPEC)
			if #oldProblems == 0 then
				guardsAre = "old"
			elseif #newProblems == 0 then
				guardsAre = "new"
			else
				local hasBoard = false
				for _, recorded in GUARDS_37 do
					hasBoard = hasBoard or guardFolder:FindFirstChild(recorded.name) ~= nil
				end
				local nearerGuards = if hasBoard then newProblems else oldProblems
				for _, text in nearerGuards do
					table.insert(problems, `4 {text}`)
				end
			end
		end
		local kind = "other"
		if smallFolder ~= nil then
			local t6Problems = folderProblems(smallFolder, PATCHES_T6, SLIDE_SPEC)
			local task23Problems = folderProblems(smallFolder, PATCHES_23, SLIDE_SPEC)
			local task32Problems = folderProblems(smallFolder, PATCHES_AFTER32, SLIDE_SPEC)
			local task37Problems = folderProblems(smallFolder, PATCHES_AFTER37, SLIDE_SPEC)
			local task33Problems = folderProblems(smallFolder, PATCHES_FINAL, SLIDE_SPEC)
			local task48Problems = folderProblems(smallFolder, PATCHES_ALL, SLIDE_SPEC)
			local task33bProblems = folderProblems(smallFolder, PATCHES_TARGET, SLIDE_SPEC)
			if #t6Problems == 0 then
				kind = "t6"
			elseif #task23Problems == 0 then
				kind = "task23"
			elseif #task32Problems == 0 then
				kind = "task32"
			elseif #task37Problems == 0 then
				kind = "task37"
			elseif #task33Problems == 0 then
				kind = "task33"
			elseif #task48Problems == 0 then
				kind = "task48"
			elseif #task33bProblems == 0 then
				kind = "task33b"
			else
				-- None: name what differs from the world it is nearest to. A folder with any of Task 37's boxes is read
				-- against the final world (with Task 48's box) or the one before it; else one with any Sock part against the world after Task 32; else one with
				-- some forehead boxes against the T6 world (so the missing box is named); one with none, against Task 23's.
				local function hasAny(records: { FolderRecord }): boolean
					for _, recorded in records do
						if smallFolder:FindFirstChild(recorded.name) ~= nil then
							return true
						end
					end
					return false
				end
				local nearer = if hasAny(PATCHES_37)
					then (if hasAny(PATCHES_48)
						then task33bProblems
						elseif hasAny(PATCHES_33) then task33Problems
						else task37Problems)
					elseif hasAny(PATCHES_32) then task32Problems
					elseif hasAny(PATCHES_29) then t6Problems
					else task23Problems
				for _, text in nearer do
					table.insert(problems, `4 {text}`)
				end
			end
			if guardsAre ~= "other" and (HAS_ALL_GUARDS[kind] == true) ~= (guardsAre == "new") and #problems == 0 then
				table.insert(
					problems,
					`the small patches are "{kind}" but the guards are {guardsAre} (Task 37 adds both folders' parts together)`
				)
			end
		end
		if #problems > 0 then
			return "other", problems
		end
		return kind, problems
	end

	-- The small patches a world still needs: the 20 Sock parts of Task 32 (unless it has them: every world from "task32"
	-- on), Task 37's 6 boxes (unless it has them: "task37" and later), the reshaped forehead box of Task 33b (unless it
	-- is "task33b"; "task33" and "task48" first lose their first box, see changeWalk) and Task 48's bush box (unless
	-- it has it: "task48", "task33b").
	local function smallToAdd(kind: string): { FolderRecord }
		local list: { FolderRecord } = {}
		if kind ~= "task32" and not HAS_ALL_GUARDS[kind] then
			table.move(PATCHES_32, 1, #PATCHES_32, #list + 1, list)
		end
		if not HAS_ALL_GUARDS[kind] then
			table.move(PATCHES_37, 1, #PATCHES_37, #list + 1, list)
		end
		if kind ~= "task33b" then
			table.move(PATCHES_33, 1, #PATCHES_33, #list + 1, list)
		end
		if kind ~= "task48" and kind ~= "task33b" then
			table.move(PATCHES_48, 1, #PATCHES_48, #list + 1, list)
		end
		return list
	end
	-- Parts made away from the Workspace, then put into a folder.
	local function addParts(folder: Instance, records: { FolderRecord })
		local staging = makeFolder("Staging", records, PART_LOOK, GUARD_COLOR)
		for _, part in staging:GetChildren() do
			part.Parent = folder
		end
		staging:Destroy()
	end

	-- What each world needs. "before": both folders are built away from the Workspace, then put in. Otherwise "t6" has
	-- exactly the 6 forehead boxes destroyed first, then every older world gets the parts it misses: the Sock's 20 parts
	-- (unless it is "task32", "task37" or "task33"), Task 37's 6 boxes (unless it is "task37" or "task33"), Task 33's
	-- forehead box (unless it is "task33") and Task 48's bush box in SmallPatches, and the 8 Sock boards in SlideGuards (unless it is "task37" or
	-- "task33", which have them). The parts it already
	-- has stay as they are, except the first forehead box of Task 33 ("task33", "task48"): it is destroyed first, and the
	-- reshaped one of Task 33b takes its place.
	local function changeWalk(walk: Instance, kind: string)
		if kind == "before" then
			local newGuards = makeFolder(GUARD_FOLDER, GUARDS_FINAL, PART_LOOK, GUARD_COLOR)
			local newPatches = makeFolder(SMALL_FOLDER, PATCHES_TARGET, PART_LOOK, GUARD_COLOR)
			newGuards.Parent = walk
			newPatches.Parent = walk
		else
			local smallFolder = walk:FindFirstChild(SMALL_FOLDER) :: Instance
			if kind == "t6" then
				for _, recorded in PATCHES_29 do
					(smallFolder:FindFirstChild(recorded.name) :: Instance):Destroy()
				end
			elseif kind == "task33" or kind == "task48" then
				for _, recorded in PATCHES_33_FIRST do
					(smallFolder:FindFirstChild(recorded.name) :: Instance):Destroy()
				end
			end
			addParts(smallFolder, smallToAdd(kind))
			if not HAS_ALL_GUARDS[kind] then
				addParts(walk:FindFirstChild(GUARD_FOLDER) :: Instance, GUARDS_37)
			end
		end
	end

	-- Which world is it?
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild(WALK_FOLDER_NAME) else nil
	if world == nil or walk == nil then
		error("nothing was changed. World.WalkSurfaces is missing")
	end
	local kind, problems = worldOf(walk)
	local homeOf: { [string]: string } = {} -- recorded name -> the name of the folder it belongs in
	for _, recorded in GUARDS_FINAL do
		homeOf[recorded.name] = GUARD_FOLDER
	end
	for _, recorded in PATCHES_T6 do
		homeOf[recorded.name] = SMALL_FOLDER
	end
	for _, recorded in PATCHES_32 do
		homeOf[recorded.name] = SMALL_FOLDER
	end
	for _, recorded in PATCHES_37 do
		homeOf[recorded.name] = SMALL_FOLDER
	end
	for _, recorded in PATCHES_33 do
		homeOf[recorded.name] = SMALL_FOLDER
	end
	for _, recorded in PATCHES_48 do
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
	if #problems > 0 then
		error(
			`nothing was changed. This is none of the eight worlds section 4 knows (before, after Task 23 only, T6 as built in 29-6A, after Task 32, after Task 37, after Task 33, after Task 48, after Task 33b): {someProblems(
				problems
			)}`
		)
	end
	local guardsText = countsText(GUARDS_FINAL)
	local patchesText = countsText(PATCHES_TARGET)
	if kind == "task33b" then
		return `already done: World.WalkSurfaces.SlideGuards holds {guardsText} and World.WalkSurfaces.SmallPatches holds {patchesText}, all as recorded`
	end

	-- The change itself, between two waypoints.
	local descendantsBefore = #world:GetDescendants()
	local addedSmall = if kind == "before" then #PATCHES_TARGET else #smallToAdd(kind)
	pcall(function()
		ChangeHistoryService:SetWaypoint("15-real-shape section 4: before")
	end)
	local changed, whyNot = pcall(function()
		changeWalk(walk, kind)
		return nil
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
	local afterKind, wrong = worldOf(walk)
	if afterKind ~= "task33b" then
		table.insert(wrong, `the world reads as "{afterKind}", expected "task33b"`)
	end
	if #wrong > 0 then
		error(
			`the change was made, but the check afterwards found: {someProblems(wrong)}. Undo it in Studio (Ctrl+Z, back to the waypoint) and tell code_lead`
		)
	end
	local addedGuards = if HAS_ALL_GUARDS[kind] then 0 else #GUARDS_37 -- "task37" has its 8 boards already
	local removedText = if kind == "t6"
		then `removed the {#PATCHES_29} forehead boxes, `
		elseif kind == "task33" or kind == "task48" then "replaced Task 33's first forehead box, "
		else ""
	return string.format(
		"%s; World now has %d descendants (%d before). Guards: %s. Small patches: %s",
		if kind == "before"
			then "made World.WalkSurfaces.SlideGuards and World.WalkSurfaces.SmallPatches"
			else `{removedText}added {addedSmall} small patches to World.WalkSurfaces.SmallPatches and {addedGuards} guards to World.WalkSurfaces.SlideGuards`,
		#world:GetDescendants(),
		descendantsBefore,
		guardsText,
		patchesText
	)
end

return sectionSlideGuards
