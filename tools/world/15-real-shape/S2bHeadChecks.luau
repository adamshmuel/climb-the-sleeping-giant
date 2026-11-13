--!strict
-- The head's later final lists (sections 2f4 to 2g) and the checks that compare the live head parts with them.

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)

local WALK_FOLDER_NAME = Shared.WALK_FOLDER_NAME
local describePlace = Shared.describePlace
local sameAs = Shared.sameAs
local samePhysics = Shared.samePhysics
local HEAD_PARENTS = S2bHeadParts.HEAD_PARENTS
local HEAD_WALK_NAMES = S2bHeadParts.HEAD_WALK_NAMES
local COLOR_TOLERANCE = S2bHeadParts.COLOR_TOLERANCE
local BEARD_LADDER_ANGLE = S2bHeadParts.BEARD_LADDER_ANGLE
local RAIL_THICKNESS = S2bHeadParts.RAIL_THICKNESS
type HeadSettings = S2bHeadParts.HeadSettings
type HeadPart = S2bHeadParts.HeadPart
local HEAD_SETTINGS = S2bHeadParts.HEAD_SETTINGS
local ladderCFrame = S2bHeadParts.ladderCFrame
local PART_A_BEHIND_Z = S2bHeadParts.PART_A_BEHIND_Z
local FINAL_HEAD_PARTS_2F = S2bHeadParts.FINAL_HEAD_PARTS_2F
local FINAL_HEAD_PARTS_2G = S2bHeadParts.FINAL_HEAD_PARTS_2G
local TRUSS_LONGER_EXTRA = S2bHeadParts.TRUSS_LONGER_EXTRA
local PART_B_BACK_BEFORE = S2bHeadParts.PART_B_BACK_BEFORE
local PART_B_BACK_AFTER = S2bHeadParts.PART_B_BACK_AFTER
local HEAD_CHANGES_2F4 = S2bHeadParts.HEAD_CHANGES_2F4

local S2bHeadChecks = {}

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

S2bHeadChecks.FINAL_HEAD_PARTS_2H = FINAL_HEAD_PARTS_2H
S2bHeadChecks.TRUSS_SWING_MIN = TRUSS_SWING_MIN
S2bHeadChecks.TRUSS_SWING_MAX = TRUSS_SWING_MAX
S2bHeadChecks.TRUSS_SWING_SLACK = TRUSS_SWING_SLACK
S2bHeadChecks.TRUSS_SWING_TOP_SLACK = TRUSS_SWING_TOP_SLACK
S2bHeadChecks.HEAD_CHANGES_2F6 = HEAD_CHANGES_2F6
S2bHeadChecks.FINAL_HEAD_PARTS_2I = FINAL_HEAD_PARTS_2I
S2bHeadChecks.BELLY_RAIL_EXTRA = BELLY_RAIL_EXTRA
S2bHeadChecks.BELLY_RAIL_EXTRA_SLACK = BELLY_RAIL_EXTRA_SLACK
S2bHeadChecks.BELLY_RAIL_LENGTH = BELLY_RAIL_LENGTH
S2bHeadChecks.BELLY_RUNG_STEP = BELLY_RUNG_STEP
S2bHeadChecks.BELLY_RUNG_STEP_SLACK = BELLY_RUNG_STEP_SLACK
S2bHeadChecks.BELLY_TURN_SLACK = BELLY_TURN_SLACK
S2bHeadChecks.BELLY_TOP_SLACK = BELLY_TOP_SLACK
S2bHeadChecks.BEARD_RAIL_BELLY_BEFORE_AFTER = BEARD_RAIL_BELLY_BEFORE_AFTER
S2bHeadChecks.FINAL_HEAD_PARTS_2J = FINAL_HEAD_PARTS_2J
S2bHeadChecks.BEARD_LOW_RUNG = BEARD_LOW_RUNG
S2bHeadChecks.BEARD_BELLY_RUNG = BEARD_BELLY_RUNG
S2bHeadChecks.headSettingsProblem = headSettingsProblem
S2bHeadChecks.headProblems = headProblems
S2bHeadChecks.headProblemsEitherSlot = headProblemsEitherSlot
S2bHeadChecks.someProblems = someProblems
S2bHeadChecks.countParts = countParts

return S2bHeadChecks
