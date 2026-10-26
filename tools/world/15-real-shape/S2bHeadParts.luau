--!strict
-- The head's records, shared by the sections that check or change it: the ladder numbers, V1's parts, the settings and every final list from sections 2b to 2f4.

local Shared = require(script.Parent.Shared)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME

local S2bHeadParts = {}

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

export type HeadSettings = {
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
export type HeadPart = { parent: string, name: string, size: Vector3, cframe: CFrame, shape: Enum.PartType? }

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

S2bHeadParts.HEAD_PARENTS = HEAD_PARENTS
S2bHeadParts.HEAD_WALK_NAMES = HEAD_WALK_NAMES
S2bHeadParts.COLOR_TOLERANCE = COLOR_TOLERANCE
S2bHeadParts.MIDDLE_GUARD_X = MIDDLE_GUARD_X
S2bHeadParts.CAP_LADDER_ANGLE = CAP_LADDER_ANGLE
S2bHeadParts.BEARD_LADDER_ANGLE = BEARD_LADDER_ANGLE
S2bHeadParts.RAIL_THICKNESS = RAIL_THICKNESS
S2bHeadParts.HEAD_SETTINGS = HEAD_SETTINGS
S2bHeadParts.V1_HEAD_PARTS = V1_HEAD_PARTS
S2bHeadParts.ladderCFrame = ladderCFrame
S2bHeadParts.NEW_HEAD_PARTS = NEW_HEAD_PARTS
S2bHeadParts.FINAL_HEAD_PARTS = FINAL_HEAD_PARTS
S2bHeadParts.PART_A_BEHIND_Z = PART_A_BEHIND_Z
S2bHeadParts.SLOT_BLOCK_NAME = SLOT_BLOCK_NAME
S2bHeadParts.PART_A_BEFORE_AFTER = PART_A_BEFORE_AFTER
S2bHeadParts.FINAL_HEAD_PARTS_2D = FINAL_HEAD_PARTS_2D
S2bHeadParts.SLOT_BLOCK_PARTS = SLOT_BLOCK_PARTS
S2bHeadParts.BEARD_RAIL_LONG_LENGTH = BEARD_RAIL_LONG_LENGTH
S2bHeadParts.BEARD_TOP_SLACK = BEARD_TOP_SLACK
S2bHeadParts.BEARD_RAIL_BEFORE_AFTER = BEARD_RAIL_BEFORE_AFTER
S2bHeadParts.FINAL_HEAD_PARTS_2E = FINAL_HEAD_PARTS_2E
S2bHeadParts.BEARD_LOWEST_RUNG = BEARD_LOWEST_RUNG
S2bHeadParts.BEARD_EXTRA_RUNG = BEARD_EXTRA_RUNG
S2bHeadParts.BEARD_TRUSS_EXTRA = BEARD_TRUSS_EXTRA
S2bHeadParts.BEARD_TRUSS_TOP_SLACK = BEARD_TRUSS_TOP_SLACK
S2bHeadParts.BEARD_TRUSS_BEFORE_AFTER = BEARD_TRUSS_BEFORE_AFTER
S2bHeadParts.FINAL_HEAD_PARTS_2F = FINAL_HEAD_PARTS_2F
S2bHeadParts.SLOT_BLOCK_BEFORE_AFTER = SLOT_BLOCK_BEFORE_AFTER
S2bHeadParts.FINAL_HEAD_PARTS_2G = FINAL_HEAD_PARTS_2G
S2bHeadParts.TRUSS_LONGER_EXTRA = TRUSS_LONGER_EXTRA
S2bHeadParts.TRUSS_LONGER_TOP_SLACK = TRUSS_LONGER_TOP_SLACK
S2bHeadParts.PART_B_BACK_BEFORE = PART_B_BACK_BEFORE
S2bHeadParts.PART_B_BACK_AFTER = PART_B_BACK_AFTER
S2bHeadParts.PART_B_BACK_MIN = PART_B_BACK_MIN
S2bHeadParts.PART_B_BACK_MAX = PART_B_BACK_MAX
S2bHeadParts.HEAD_CHANGES_2F4 = HEAD_CHANGES_2F4

return S2bHeadParts
