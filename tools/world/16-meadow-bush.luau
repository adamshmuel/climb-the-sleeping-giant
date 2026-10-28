--!strict
-- World prep, V2 stuck safety Task 48: a bush in front of R-141's notch (docs/plans/v2/stuck-safety/2d-hangs-and-finish.md,
-- "Task 48"; designer's choice in work/t48/designer-bush.md, "Designer answer 2").
-- Why: R-141 is a pocket about 5 studs deep at the giant's foot on the meadow, on the way to the boot ramps. Players walk
-- into it and hang in Climbing, and the rescue doesn't reach the meadow (spec Rule 22), so the pocket is closed instead.
-- What it does: the bush (a Nature_FloweringBush marked with the attribute MeadowBushR141 = true) is set to scale 3
-- (Model:ScaleTo, which is absolute) and moved so the centre of its leaves (the MeshPart "Foliage") is at FOLIAGE_AT, over the
-- invisible box Block_R141_1 (made by S4SlideGuards in tools/world/15-real-shape, which owns the SmallPatches folder:
-- Lesson 55). Meadow bushes have no collision, so that box is the solid part.
-- Three worlds, checked before any change:
--   1. no marked bush: copies the Nature_FloweringBush that stands within 3 studs of (88, 6, -21), then scales and moves it;
--   2. a marked bush still at the old record (bounding box middle x 58.5, z -1, bottom y 2): scales and moves it;
--   3. a marked bush at scale 3 with its leaves in place: "already done", nothing changes.
-- Anything else stops with nothing changed. The message starts with how much changed (Lesson 58): "copied 1 bush",
-- "scaled 1 bush" or "already done".
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau (or require a copy of it). The place
-- file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BUSH_NAME = "Nature_FloweringBush"
local MARK = "MeadowBushR141"
local SOURCE_AT = Vector3.new(88, 6, -21) -- the existing bush's place (its bounding box middle)
local SOURCE_REACH = 3 -- studs: how close the source's middle must be to SOURCE_AT
local SCALE = 3 -- Model:ScaleTo is absolute, so it doesn't matter what the copy's scale is now
local SCALE_SAME = 0.001 -- how close GetScale() must be to SCALE to count as "as recorded"
local FOLIAGE_AT = Vector3.new(56.8, 7.7, -1.6) -- where the centre of the leaves (MeshPart "Foliage") goes
local FOLIAGE_SAME = 0.05 -- studs: how close the leaves' centre must be to FOLIAGE_AT
local OLD_X = 58.5 -- the old record: bounding box middle, x
local OLD_Z = -1 -- the old record: bounding box middle, z
local OLD_BOTTOM = 2 -- the old record: bounding box bottom, y
local OLD_SAME = 0.05 -- studs: how close a marked bush must be to the old record
local LEAVES_BOTTOM_MIN = 0.5 -- the leaves' bottom must end between these (designer expects about 1)
local LEAVES_BOTTOM_MAX = 1.5

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Where a bush's bounding box middle is, and the y of its bottom.
local function boxOf(bush: Model): (Vector3, number)
	local boxCFrame, boxSize = bush:GetBoundingBox()
	return boxCFrame.Position, boxCFrame.Position.Y - boxSize.Y / 2
end

local function foliageOf(bush: Model): BasePart
	local leaves = bush:FindFirstChild("Foliage", true)
	if leaves == nil or not leaves:IsA("BasePart") then
		error(`nothing was changed. {bush:GetFullName()} has no Foliage part`)
	end
	return leaves
end

local function leavesBottom(leaves: BasePart): number
	return leaves.Position.Y - leaves.Size.Y / 2
end

local function run(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local nature = if world ~= nil then world:FindFirstChild("Nature") else nil
	if nature == nil then
		error("nothing was changed. Workspace.World.Nature is missing")
	end

	local marked: { Model } = {}
	local sources: { Model } = {}
	for _, instance in nature:GetDescendants() do
		if instance:IsA("Model") and instance.Name == BUSH_NAME then
			if instance:GetAttribute(MARK) == true then
				table.insert(marked, instance)
			elseif (flat(instance:GetBoundingBox().Position) - flat(SOURCE_AT)).Magnitude <= SOURCE_REACH then
				table.insert(sources, instance)
			end
		end
	end
	if #marked > 1 then
		error(`nothing was changed. {#marked} bushes carry the attribute {MARK}, expected 0 or 1`)
	end

	-- Which world is it? (Nothing has changed until this is decided.)
	local bush: Model
	local verb: string
	if #marked == 1 then
		bush = marked[1]
		local leaves = foliageOf(bush)
		if
			math.abs(bush:GetScale() - SCALE) <= SCALE_SAME
			and (leaves.Position - FOLIAGE_AT).Magnitude <= FOLIAGE_SAME
		then
			return string.format(
				"already done: %s is at scale %.3f, its leaves' centre (%.2f, %.2f, %.2f), leaves' bottom y %.2f",
				bush:GetFullName(),
				bush:GetScale(),
				leaves.Position.X,
				leaves.Position.Y,
				leaves.Position.Z,
				leavesBottom(leaves)
			)
		end
		local middle, bottom = boxOf(bush)
		local awayFromOld = (flat(middle) - Vector3.new(OLD_X, 0, OLD_Z)).Magnitude
		if awayFromOld > OLD_SAME or math.abs(bottom - OLD_BOTTOM) > OLD_SAME then
			error(
				`nothing was changed. The bush marked {MARK} is at ({middle.X}, {bottom}, {middle.Z}) (middle x, bottom y, middle z) and scale {bush:GetScale()}, neither the old record nor the new one`
			)
		end
		verb = "scaled"
	else
		if #sources ~= 1 then
			error(
				`nothing was changed. {#sources} {BUSH_NAME} models stand within {SOURCE_REACH} studs of the source place, expected 1`
			)
		end
		bush = sources[1]:Clone()
		bush:SetAttribute(MARK, true)
		verb = "copied"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("16-meadow-bush: before")
	end)
	bush:ScaleTo(SCALE)
	local leaves = foliageOf(bush)
	bush:PivotTo(bush:GetPivot() + (FOLIAGE_AT - leaves.Position))
	if verb == "copied" then
		bush.Parent = sources[1].Parent
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("16-meadow-bush: after")
	end)

	local bottom = leavesBottom(leaves)
	if
		math.abs(bush:GetScale() - SCALE) > SCALE_SAME
		or (leaves.Position - FOLIAGE_AT).Magnitude > FOLIAGE_SAME
		or bottom < LEAVES_BOTTOM_MIN
		or bottom > LEAVES_BOTTOM_MAX
	then
		error(
			`the bush was {verb} but stands wrong: scale {bush:GetScale()}, leaves' centre {leaves.Position}, leaves' bottom y {bottom}. Undo it in Studio (Ctrl+Z, back to the waypoint "16-meadow-bush: before") and tell code_lead`
		)
	end
	return string.format(
		"%s 1 bush: %s at scale %.3f, its leaves' centre (%.2f, %.2f, %.2f), leaves' bottom y %.2f",
		verb,
		bush:GetFullName(),
		bush:GetScale(),
		leaves.Position.X,
		leaves.Position.Y,
		leaves.Position.Z,
		bottom
	)
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
