--!strict
-- V2 stuck safety, Task 58 (Rule 24, a bot walks every way; Rule 20, one collision source): a ladder can be climbed
-- across the whole width the player sees. Today each ladder has one 2 stud truss under rails and rungs 5.2 studs wide, so a
-- push a little off the line let go (Lesson 153). The world script tools/world/17-ladder-width.luau adds 2 side trusses
-- (`ClimbSide`) and 2 side walls (`SideWall`) to each ladder.
-- Ladders are found by kind, never by name: every solid TrussPart in the Workspace is grouped by the model it sits in,
-- and the group's rails are the BaseParts named `Rail` in the same model.
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WalkHelpers = require(script.Parent.WalkHelpers)
local longSide = WalkHelpers.longSide

local SIDE_TRUSS = "ClimbSide"
local SIDE_WALL = "SideWall"
local RAIL = "Rail"
local WALL_INNER_FACE = 3.2 -- studs from the centre truss to the wall's inner face
local WALL_FACE_SLACK = 0.1 -- studs the inner face may be off
local WALL_LENGTH_SLACK = 0.05 -- studs the wall may differ from the centre truss in length
local TRUSS_GAP_MIN = 0.01 -- studs: a wall never touches a truss
local COVER_SLACK = 0.01 -- studs: rounding when trusses are placed edge to edge
local WORLD_UP = Vector3.new(0, 1, 0)
local WALL_MIDDLE_OUT = 1.5 -- studs: a wall's middle is this far from the middle line toward the climber
local WALL_MIDDLE_SLACK = 0.1 -- studs

type Ladder = {
	model: Instance,
	trusses: { BasePart }, -- every solid truss in the model
	centres: { BasePart }, -- the trusses that are not side trusses (a ladder has exactly 1)
	rails: { BasePart },
	walls: { BasePart },
}

-- How far a part reaches either side of its middle along `direction` (a unit vector).
local function halfExtent(part: BasePart, direction: Vector3): number
	local size = part.Size
	local cframe = part.CFrame
	return (
		math.abs(cframe.RightVector:Dot(direction)) * size.X
		+ math.abs(cframe.UpVector:Dot(direction)) * size.Y
		+ math.abs(cframe.LookVector:Dot(direction)) * size.Z
	) / 2
end

local function childrenNamed(model: Instance, name: string): { BasePart }
	local found: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

-- Every solid TrussPart under `root`, grouped by its model. Returns the ladders (groups with rails beside them) and the
-- full names of solid trusses that have no rails beside them.
local function scan(root: Instance): ({ Ladder }, { string })
	local groups: { [Instance]: { BasePart } } = {}
	local order: { Instance } = {}
	for _, instance in root:GetDescendants() do
		if instance:IsA("TrussPart") and instance.CanCollide then
			local model = instance.Parent :: Instance
			if groups[model] == nil then
				groups[model] = {}
				table.insert(order, model)
			end
			table.insert(groups[model], instance)
		end
	end
	local ladders: { Ladder } = {}
	local unrailed: { string } = {}
	for _, model in order do
		local trusses = groups[model]
		local rails = childrenNamed(model, RAIL)
		if #rails == 0 then
			for _, truss in trusses do
				table.insert(unrailed, truss:GetFullName())
			end
		else
			local centres: { BasePart } = {}
			for _, truss in trusses do
				if truss.Name ~= SIDE_TRUSS then
					table.insert(centres, truss)
				end
			end
			table.insert(ladders, {
				model = model,
				trusses = trusses,
				centres = centres,
				rails = rails,
				walls = childrenNamed(model, SIDE_WALL),
			})
		end
	end
	return ladders, unrailed
end

-- The centre truss, the way up the ladder and the way across it (flat, square to the way up).
local function frameOf(ladder: Ladder): (BasePart, Vector3, number, Vector3)
	local centre = ladder.centres[1]
	local up, length = longSide(centre)
	local across = WORLD_UP:Cross(up).Unit
	return centre, up, length, across
end

local function offsetOf(part: BasePart, centre: BasePart, across: Vector3): number
	return (part.Position - centre.Position):Dot(across)
end

-- Rule 20: the solid trusses together reach at least the rails' outer edges, on both sides, with no gap between them.
local function coverProblems(ladder: Ladder): { string }
	local name = ladder.model:GetFullName()
	if #ladder.centres ~= 1 then
		return { `{name}: it has {#ladder.centres} centre trusses, it must have 1` }
	end
	local centre, _, _, across = frameOf(ladder)
	local outer = 0
	for _, rail in ladder.rails do
		outer = math.max(outer, math.abs(offsetOf(rail, centre, across)) + halfExtent(rail, across))
	end
	local spans: { { number } } = {}
	for _, truss in ladder.trusses do
		local offset = offsetOf(truss, centre, across)
		local half = halfExtent(truss, across)
		table.insert(spans, { offset - half, offset + half })
	end
	table.sort(spans, function(a, b)
		return a[1] < b[1]
	end)
	local problems: { string } = {}
	local reached = spans[1][2]
	if spans[1][1] > -outer + COVER_SLACK then
		table.insert(
			problems,
			`{name}: the trusses start {spans[1][1]} studs from the middle, the rails reach {-outer}`
		)
	end
	for index = 2, #spans do
		if spans[index][1] > reached + COVER_SLACK then
			table.insert(problems, `{name}: a gap in the trusses from {reached} to {spans[index][1]} studs across`)
		end
		reached = math.max(reached, spans[index][2])
	end
	if reached < outer - COVER_SLACK then
		table.insert(problems, `{name}: the trusses end {reached} studs from the middle, the rails reach {outer}`)
	end
	return problems
end

-- Rule 20: one SideWall on each side, solid, fully clear, as long as the centre truss, its inner face 3.2 studs out and
-- clear of every truss.
local function wallProblems(ladder: Ladder): { string }
	local name = ladder.model:GetFullName()
	if #ladder.centres ~= 1 then
		return { `{name}: it has {#ladder.centres} centre trusses, it must have 1` }
	end
	local centre, up, length, across = frameOf(ladder)
	local problems: { string } = {}
	local perSide = { [-1] = 0, [1] = 0 }
	for _, wall in ladder.walls do
		local offset = offsetOf(wall, centre, across)
		local side = if offset >= 0 then 1 else -1
		perSide[side] += 1
		local label = `{wall:GetFullName()} ({if side > 0 then "right" else "left"} side)`
		if not wall.CanCollide then
			table.insert(problems, `{label}: it does not collide`)
		end
		if wall.Transparency ~= 1 then
			table.insert(problems, `{label}: its transparency is {wall.Transparency}, it must be 1`)
		end
		local wallLength = halfExtent(wall, up) * 2
		if math.abs(wallLength - length) > WALL_LENGTH_SLACK then
			table.insert(problems, `{label}: it is {wallLength} studs long, the centre truss is {length}`)
		end
		local innerFace = math.abs(offset) - halfExtent(wall, across)
		if math.abs(innerFace - WALL_INNER_FACE) > WALL_FACE_SLACK then
			table.insert(problems, `{label}: its inner face is {innerFace} studs out, it must be {WALL_INNER_FACE}`)
		end
		for _, truss in ladder.trusses do
			local edge = offsetOf(truss, centre, across) * side + halfExtent(truss, across)
			if innerFace - edge < TRUSS_GAP_MIN then
				table.insert(problems, `{label}: it touches {truss:GetFullName()} (gap {innerFace - edge} studs)`)
			end
		end
	end
	for _, side in { -1, 1 } do
		if perSide[side] ~= 1 then
			table.insert(
				problems,
				`{name}: it has {perSide[side]} {SIDE_WALL} parts on its {if side > 0 then "right" else "left"} side, it must have 1`
			)
		end
	end
	return problems
end

-- The way from the ladder's middle line toward the climber: square to the way up, away from his body. Same formula as
-- WalkHelpers.ladderAxis: "back" is toward his body (along the flat direction, tilted down), the climber is the other way.
local function climberSide(centre: BasePart): Vector3
	local up = longSide(centre)
	if up.Y < 0 then
		up = -up
	end
	local flatPart = Vector3.new(up.X, 0, up.Z)
	local back = (flatPart.Unit * up.Y - WORLD_UP * flatPart.Magnitude).Unit
	return -back
end

local function realLadders(): ({ Ladder }, { string })
	return scan(Workspace)
end

describe("the real world, every ladder can be climbed across its whole width", function()
	it("finds the beard ladder and the cap ladder by their kind", function()
		local ladders = realLadders()
		expect(#ladders).toBeGreaterThanOrEqual(2)
	end)

	it("the solid trusses cover the rails' outer width with no gap", function()
		local ladders = realLadders()
		local problems: { string } = {}
		for _, ladder in ladders do
			for _, problem in coverProblems(ladder) do
				table.insert(problems, problem)
			end
		end
		expect(problems).toEqual({})
	end)

	it("each ladder has one clear solid side wall on each side, 3.2 studs out and clear of the trusses", function()
		local ladders = realLadders()
		local problems: { string } = {}
		for _, ladder in ladders do
			for _, problem in wallProblems(ladder) do
				table.insert(problems, problem)
			end
		end
		expect(problems).toEqual({})
	end)

	it("each side wall's middle sits on the climber's side, about 1.5 studs out", function()
		local ladders = realLadders()
		local problems: { string } = {}
		for _, ladder in ladders do
			if #ladder.centres == 1 then
				local centre = ladder.centres[1]
				local toClimber = climberSide(centre)
				if #ladder.walls ~= 2 then
					table.insert(
						problems,
						`{ladder.model:GetFullName()}: it has {#ladder.walls} {SIDE_WALL} parts, it must have 2`
					)
				end
				for _, wall in ladder.walls do
					local out = (wall.Position - centre.Position):Dot(toClimber)
					if math.abs(out - WALL_MIDDLE_OUT) > WALL_MIDDLE_SLACK then
						table.insert(
							problems,
							`{wall:GetFullName()}: its middle is {out} studs toward the climber, it must be {WALL_MIDDLE_OUT}`
						)
					end
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("no solid truss stands without rails beside it", function()
		local _, unrailed = realLadders()
		expect(unrailed).toEqual({})
	end)

	it("a solid truss with no rails is reported by its full name", function()
		local folder = Instance.new("Folder")
		folder.Name = "TrussTrial"
		local lonely = Instance.new("TrussPart")
		lonely.Name = "Lonely"
		lonely.CanCollide = true
		lonely.Parent = folder
		local ladders, unrailed = scan(folder)
		folder:Destroy()
		expect(#ladders).toBe(0)
		expect(unrailed).toEqual({ "TrussTrial.Lonely" })
	end)
end)
