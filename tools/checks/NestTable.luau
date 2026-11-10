--!strict
-- The 38 egg nests (plan 5 Task 12): where each one is, its rank, its twin and how its straw nest leans. Jest-free and
-- service-free, so the world script (tools/world/21b-nest-models.luau, run through execute_luau), the measure job and the
-- tests (Nests.spec) read the same copy.
-- Spots: docs/design/v2/style-guide/nests-map.md, "Common: 16 meadow nests" and "On him: 22 nests" (knee pocket at
-- y 27.1 / 27.2 on his skin, designer ruling 2026-11-10). Gardens 5 to 8 mirror gardens 4 to 1 (x turned positive).
-- Leans: the straw nests in ServerStorage.ArtLibrary.Mockup_Nests.Art.Nests (designer), as YXZ Euler degrees (x, y, z), read 2026-11-10.

export type Nest = {
	name: string, -- Nest_<Place>_<Side>, or Nest_Meadow_<garden><a|b>
	rank: string, -- the target rank (Rule 70)
	spot: Vector3, -- where the egg's bottom sits
	twin: string, -- its mirror twin's name
	garden: number?, -- meadow nests only
	ridesRightArm: boolean?, -- right cuff nests only
	lean: Vector3, -- degrees, YXZ, of the straw nest (0 = level)
}

local NestTable = {}

-- Studs between a nest's spot and the pivot of its straw nest, along the nest's own up (the spec: one stud above the spot).
NestTable.NEST_LIFT = 1

type OnHim = {
	place: string,
	rank: string,
	left: Vector3,
	right: Vector3,
	leanLeft: Vector3,
	leanRight: Vector3,
	arm: boolean?,
}

local ON_HIM: { OnHim } = {
	{
		place = "BootToeOuter",
		rank = "Uncommon",
		left = Vector3.new(-26.5, 30.75, -62.5),
		right = Vector3.new(26.5, 30.7, -62.5),
		leanLeft = Vector3.new(-0.3, -0.1, 19.6),
		leanRight = Vector3.new(0.9, -0.3, -18.4),
	},
	{
		place = "BootToeInner",
		rank = "Uncommon",
		left = Vector3.new(-20.0, 30.5, -62.5),
		right = Vector3.new(20.0, 30.6, -62.5),
		leanLeft = Vector3.new(-1.9, 0.4, -13.3),
		leanRight = Vector3.new(-1.4, -0.4, 14.4),
	},
	{
		place = "KneePocket",
		rank = "Uncommon",
		left = Vector3.new(-15, 27.1, -47.5),
		right = Vector3.new(15, 27.2, -47.5),
		leanLeft = Vector3.zero,
		leanRight = Vector3.zero,
	},
	{
		place = "LapFold",
		rank = "Uncommon",
		left = Vector3.new(-13.5, 27.4, -62.5),
		right = Vector3.new(13.5, 27.6, -62.5),
		leanLeft = Vector3.new(9.8, 5.1, -36.8),
		leanRight = Vector3.new(0, 12.3, 35.7),
	},
	{
		place = "LowerBelly",
		rank = "Rare",
		left = Vector3.new(-12.5, 41.3, -40.3),
		right = Vector3.new(12.5, 41.2, -40.3),
		leanLeft = Vector3.new(-26.1, -7.3, 16.1),
		leanRight = Vector3.new(-26.1, 7.3, -16.1),
	},
	{
		place = "BeardFold",
		rank = "Rare",
		left = Vector3.new(-7.5, 46.5, -38.5),
		right = Vector3.new(7.5, 47.0, -38.5),
		leanLeft = Vector3.new(-49.4, -15.9, 33.9),
		leanRight = Vector3.new(-50, 15.3, -32.1),
	},
	{
		place = "BellyPocket",
		rank = "Rare",
		left = Vector3.new(-16, 44.6, -36.5),
		right = Vector3.new(16, 45.1, -36.5),
		leanLeft = Vector3.zero,
		leanRight = Vector3.zero,
	},
	{
		place = "CuffFront",
		rank = "Epic",
		left = Vector3.new(-56.1, 32.5, -11.5),
		right = Vector3.new(56.0, 32.5, -11.5),
		leanLeft = Vector3.zero,
		leanRight = Vector3.zero,
		arm = true,
	},
	{
		place = "CuffBack",
		rank = "Epic",
		left = Vector3.new(-57.51, 32.5, -5.545),
		right = Vector3.new(57.41, 32.5, -5.545),
		leanLeft = Vector3.zero,
		leanRight = Vector3.zero,
		arm = true,
	},
	{
		place = "CapBrim",
		rank = "Legendary",
		left = Vector3.new(-14, 117.1, 14),
		right = Vector3.new(14, 116.7, 14),
		leanLeft = Vector3.new(-18.1, -8.4, 25.5),
		leanRight = Vector3.new(-18.0, 8.3, -25.4),
	},
	{
		place = "CapSide",
		rank = "Legendary",
		left = Vector3.new(-17, 119.0, 28),
		right = Vector3.new(17, 119.0, 28),
		leanLeft = Vector3.new(-3.1, -1.4, 24.5),
		leanRight = Vector3.new(-4.0, 1.9, -24.9),
	},
}

-- Garden 1 to 4 meadow nests (his left, x negative), nest A then B, as (x, z) at y 2.
local MEADOW: { { a: Vector2, b: Vector2 } } = {
	{ a = Vector2.new(-99.0, 3.8), b = Vector2.new(-98.3, 12.8) },
	{ a = Vector2.new(-89.6, -42.5), b = Vector2.new(-93.4, -33.3) },
	{ a = Vector2.new(-61.6, -82.9), b = Vector2.new(-68.7, -77.5) },
	{ a = Vector2.new(-15.5, -101.3), b = Vector2.new(-32.5, -99.0) },
}
NestTable.MEADOW_Y = 2
NestTable.GARDEN_COUNT = 8

local function build(): ({ Nest }, { [string]: Nest })
	local list: { Nest } = {}
	local byName: { [string]: Nest } = {}
	local function add(nest: Nest)
		table.insert(list, nest)
		byName[nest.name] = nest
	end
	for garden = 1, NestTable.GARDEN_COUNT do
		local mirrored = garden > 4
		local row = MEADOW[if mirrored then 9 - garden else garden]
		local twinGarden = 9 - garden
		for _, letter in { "a", "b" } do
			local xz = if letter == "a" then row.a else row.b
			local x = if mirrored then -xz.X else xz.X
			add({
				name = `Nest_Meadow_{garden}{letter}`,
				rank = "Common",
				spot = Vector3.new(x, NestTable.MEADOW_Y, xz.Y),
				twin = `Nest_Meadow_{twinGarden}{letter}`,
				garden = garden,
				lean = Vector3.zero,
			})
		end
	end
	for _, row in ON_HIM do
		add({
			name = `Nest_{row.place}_Left`,
			rank = row.rank,
			spot = row.left,
			twin = `Nest_{row.place}_Right`,
			lean = row.leanLeft,
		})
		add({
			name = `Nest_{row.place}_Right`,
			rank = row.rank,
			spot = row.right,
			twin = `Nest_{row.place}_Left`,
			ridesRightArm = if row.arm then true else nil,
			lean = row.leanRight,
		})
	end
	return list, byName
end

NestTable.NESTS, NestTable.BY_NAME = build()

-- Where the straw nest's pivot goes: the spot, tilted by the nest's lean, NEST_LIFT studs up along the nest's own up.
function NestTable.nestPivot(nest: Nest): CFrame
	local lean = nest.lean
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(lean.X), math.rad(lean.Y), math.rad(lean.Z))
	return CFrame.new(nest.spot) * rotation * CFrame.new(0, NestTable.NEST_LIFT, 0)
end

return NestTable
