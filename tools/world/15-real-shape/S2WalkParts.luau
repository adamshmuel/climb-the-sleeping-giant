--!strict
-- The walk pieces' records and checks that only the walk-pieces section uses (its numbers, the old pieces it replaces and the parts it builds).

local Shared = require(script.Parent.Shared)

local GUARD_COLOR = Shared.GUARD_COLOR
local sameAs = Shared.sameAs
local samePhysics = Shared.samePhysics

local S2WalkParts = {}

local GUARD_FOLDER_NAME = "CrossingGuards"

local OLD_NAMES: { [string]: boolean } = { Boots_Walk = true, RightBoots_Walk = true, Belly_Walk = true }

local OLD_WIDTH = 10 -- every old piece is 10 x 1 x (its length)

local OLD_THICKNESS = 1

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

export type NewPart = {
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

S2WalkParts.GUARD_FOLDER_NAME = GUARD_FOLDER_NAME
S2WalkParts.OLD_NAMES = OLD_NAMES
S2WalkParts.OLD_WIDTH = OLD_WIDTH
S2WalkParts.OLD_THICKNESS = OLD_THICKNESS
S2WalkParts.OLD_PIECES = OLD_PIECES
S2WalkParts.SLIPPERY = SLIPPERY
S2WalkParts.COMMON_PARTS = COMMON_PARTS
S2WalkParts.FIRST_RUN_KNEE_PARTS = FIRST_RUN_KNEE_PARTS
S2WalkParts.FINAL_KNEE_PARTS = FINAL_KNEE_PARTS
S2WalkParts.FINAL_PARTS = FINAL_PARTS
S2WalkParts.partProblems = partProblems
S2WalkParts.findPart = findPart
S2WalkParts.makePart = makePart

return S2WalkParts
