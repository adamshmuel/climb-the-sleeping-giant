--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Workspace = game:GetService("Workspace")

-- Plan 3, Task 4a (docs/plans/v2/gardens-and-ways-up.md): the two rope ladders on the boots.
-- Spec Rule 37 (Rope ladders on the boots) and Rule 15 (The climb needs no jump).
-- These tests only READ the real world. The world is built by tools/world/19-ways-up-ladders.luau.

local TOP_HEIGHT = 30.4 -- the outer toe nest height (spec 5's table): the ladder top is level with it
local FOOT_X = 49
local FOOT_Z = -64
local TOP_X = 32
local NEST_X = 28.5
local NEST_Z = -64.5
local SIDES = { -1, 1 }

local function sideName(side: number): string
	return if side < 0 then "BootLadder_Left" else "BootLadder_Right"
end

local function walkSurfaces(): Instance
	local world = Workspace:FindFirstChild("World")
	expect(world).never.toBeNil()
	local surfaces = (world :: Instance):FindFirstChild("WalkSurfaces")
	expect(surfaces).never.toBeNil()
	return surfaces :: Instance
end

local function ladderOf(side: number): Model
	local ladder = walkSurfaces():FindFirstChild(sideName(side))
	expect(ladder).never.toBeNil()
	return ladder :: Model
end

local function climbOf(side: number): TrussPart
	local climb = ladderOf(side):FindFirstChild("Climb")
	expect(climb).never.toBeNil()
	expect((climb :: Instance):IsA("TrussPart")).toBe(true)
	return climb :: TrussPart
end

-- The two ends of the truss's long axis (its Z axis), as {top, bottom}.
local function ends(climb: TrussPart): (Vector3, Vector3)
	local axis = climb.CFrame.LookVector
	if axis.Y < 0 then
		axis = -axis
	end
	local half = climb.Size.Z / 2
	return climb.Position + axis * half, climb.Position - axis * half
end

local function giantParams(): RaycastParams
	local world = Workspace:FindFirstChild("World") :: Instance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { (world :: any).Giant }
	return params
end

local function lookParts(side: number): { BasePart }
	local look = ladderOf(side):FindFirstChild("Look")
	expect(look).never.toBeNil()
	local parts: { BasePart } = {}
	for _, child in (look :: Instance):GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

local function allParts(side: number): { BasePart }
	local parts: { BasePart } = {}
	for _, d in ladderOf(side):GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

describe("the boot ladders (Task 4a)", function()
	it("each ladder has a 2 x 2 x n truss from the grass to the boot top (Rule 37, Rule 15)", function()
		for _, side in SIDES do
			local climb = climbOf(side)
			expect(climb.Size.X).toBe(2)
			expect(climb.Size.Y).toBe(2)
			expect(climb.Size.Z % 2).toBe(0)
			local top, bottom = ends(climb)
			expect(math.abs(top.X - side * TOP_X) <= 0.5).toBe(true)
			expect(math.abs(top.Z - FOOT_Z) <= 0.5).toBe(true)
			expect(math.abs(top.Y - TOP_HEIGHT) <= 0.1).toBe(true)
			expect(bottom.Y <= 2).toBe(true)
			-- where the centre line crosses y 2
			local t = (top.Y - 2) / (top.Y - bottom.Y)
			local foot = top + (bottom - top) * t
			expect(math.abs(foot.X - side * FOOT_X) <= 0.5).toBe(true)
			expect(math.abs(foot.Z - FOOT_Z) <= 0.5).toBe(true)
		end
	end)

	it("each ladder has a flat top pad level with the boot top that needs no jump (Rule 15)", function()
		for _, side in SIDES do
			local pad = ladderOf(side):FindFirstChild("TopPad")
			expect(pad).never.toBeNil()
			local part = pad :: BasePart
			expect(part.CanCollide).toBe(true)
			expect(math.abs(part.Position.Y + part.Size.Y / 2 - TOP_HEIGHT) <= 0.05).toBe(true)
			local outerX = side * 32.5
			local innerX = side * 29
			expect(math.abs(part.Position.X - (outerX + innerX) / 2) <= 0.1).toBe(true)
			expect(math.abs(part.Size.X - 3.5) <= 0.1).toBe(true)
			expect(math.abs(part.Position.Z - FOOT_Z) <= 0.1).toBe(true)
			expect(math.abs(part.Size.Z - 5) <= 0.1).toBe(true)
			-- the boot next to the pad's inner edge is at most 0.3 below it
			local hit = Workspace:Raycast(Vector3.new(innerX, 60, -64), Vector3.new(0, -80, 0), giantParams())
			expect(hit).never.toBeNil()
			expect((hit :: RaycastResult).Position.Y >= TOP_HEIGHT - 0.3).toBe(true)
			-- the truss's top end lies on the pad's outer edge
			local top = ends(climbOf(side))
			expect(math.abs(top.X - outerX) <= 0.5).toBe(true)
		end
	end)

	it("the ladder top is 3 to 4.5 studs from the outer toe nest spot (Rule 37)", function()
		for _, side in SIDES do
			local top = ends(climbOf(side))
			local distance = (top - Vector3.new(side * NEST_X, TOP_HEIGHT, NEST_Z)).Magnitude
			expect(distance >= 3).toBe(true)
			expect(distance <= 4.5).toBe(true)
		end
	end)

	it("each ladder looks like the beard ladder: 21 rungs, 2 rails, 2 hooks, 2 pegs (Rule 37)", function()
		local beard = (walkSurfaces() :: any).BeardLadder
		for _, side in SIDES do
			local counts: { [string]: number } = {}
			for _, part in lookParts(side) do
				counts[part.Name] = (counts[part.Name] or 0) + 1
				expect(part.Transparency < 1).toBe(true)
				if part.Name == "Rung" or part.Name == "Rail" then
					local reference = beard.Look[part.Name] :: BasePart
					expect(part.Material).toBe(reference.Material)
					expect(part.BrickColor).toBe(reference.BrickColor)
				end
			end
			expect(counts.Rung).toBe(21)
			expect(counts.Rail).toBe(2)
			expect(counts.Hook).toBe(2)
			expect(counts.Peg).toBe(2)
		end
	end)

	it("the right ladder is the left one turned round, part for part", function()
		-- Each of the right part's direction arrows is the left one's with x flipped (pointing either way along it).
		local function flipped(leftArrow: Vector3, rightArrow: Vector3): boolean
			local wanted = Vector3.new(-leftArrow.X, leftArrow.Y, leftArrow.Z)
			return (rightArrow - wanted).Magnitude <= 0.01 or (rightArrow + wanted).Magnitude <= 0.01
		end
		local function turnedRound(left: BasePart, right: BasePart): boolean
			return flipped(left.CFrame.RightVector, right.CFrame.RightVector)
				and flipped(left.CFrame.UpVector, right.CFrame.UpVector)
				and flipped(left.CFrame.LookVector, right.CFrame.LookVector)
		end
		local function mirrored(left: BasePart, rights: { BasePart }): boolean
			for _, right in rights do
				if
					right.Name == left.Name
					and (right.Size - left.Size).Magnitude <= 0.05
					and math.abs(right.Position.X + left.Position.X) <= 0.05
					and math.abs(right.Position.Y - left.Position.Y) <= 0.05
					and math.abs(right.Position.Z - left.Position.Z) <= 0.05
					and turnedRound(left, right)
				then
					return true
				end
			end
			return false
		end
		local rights = allParts(1)
		local lefts = allParts(-1)
		expect(#rights).toBe(#lefts)
		for _, left in lefts do
			expect(mirrored(left, rights)).toBe(true)
		end
	end)

	it("no leftover mockup marks, no trail glow, and the truss behaves like the beard's (Rule 37)", function()
		local beardClimb = (walkSurfaces() :: any).BeardLadder.Climb :: TrussPart
		for _, side in SIDES do
			for _, d in ladderOf(side):GetDescendants() do
				for name in d:GetAttributes() do
					expect(string.sub(name, 1, 6)).never.toBe("Mockup")
				end
				expect(d.Name).never.toBe("TrailGlow")
			end
			local climb = climbOf(side)
			expect(climb.CanCollide).toBe(beardClimb.CanCollide)
			expect(climb.CanQuery).toBe(beardClimb.CanQuery)
			expect(climb.CanTouch).toBe(beardClimb.CanTouch)
		end
	end)

	it("the ladders do not cover the uncommon egg spots (Rule 37)", function()
		local world = Workspace:FindFirstChild("World") :: Instance
		local spots = (world :: any).EggSpots
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { ladderOf(-1), ladderOf(1) }
		for _, name in { "EggSpot_Uncommon_1", "EggSpot_Uncommon_3" } do
			local spot = spots[name] :: Model
			local hit =
				Workspace:Raycast(spot:GetPivot().Position + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), params)
			expect(hit).toBeNil()
		end
	end)
end)

-- Plan 3, Task 4d: the beard and cap ladders get a Look model like the boot ladders (Rule 42, Footprints take the
-- quickest way: the glow covers only the visible ladder). The world is changed by tools/world/19-ways-up-ladders.luau.
describe("every ladder has a Look model (four d)", function()
	local LADDER_NAMES = { "BeardLadder", "CapLadder", "BootLadder_Left", "BootLadder_Right" }
	local MOVED_NAMES = { "BeardLadder", "CapLadder" }
	local SAME = 0.01

	it("each ladder has a Climb truss and a Look model of visible parts only (Rule 42)", function()
		for _, name in LADDER_NAMES do
			local ladder = walkSurfaces():FindFirstChild(name)
			expect(ladder).never.toBeNil()
			local climb = (ladder :: Instance):FindFirstChild("Climb")
			expect(climb).never.toBeNil()
			expect((climb :: Instance):IsA("TrussPart")).toBe(true)
			local look = (ladder :: Instance):FindFirstChild("Look")
			expect(look).never.toBeNil()
			expect((look :: Instance):IsA("Model")).toBe(true)
			expect(#(look :: Instance):GetChildren() > 0).toBe(true)
			for _, part in (look :: Instance):GetChildren() do
				expect(part:IsA("BasePart")).toBe(true)
				expect((part :: BasePart).Transparency < 1).toBe(true)
			end
			for _, part in (ladder :: Instance):GetChildren() do
				if part:IsA("BasePart") then
					expect(part.Name == "TopPad" or part.Name == "Climb").toBe(true)
				end
			end
		end
	end)

	it("nothing moved: the beard and cap rails and rungs match the backup (Rule 42)", function()
		local backups = game:GetService("ServerStorage"):FindFirstChild("WorldBackups")
		local backup = if backups ~= nil then backups:FindFirstChild("T4d") else nil
		expect(backup).never.toBeNil()
		for _, name in MOVED_NAMES do
			local old = (backup :: Instance):FindFirstChild(name)
			expect(old).never.toBeNil()
			local look = (walkSurfaces():FindFirstChild(name) :: Instance):FindFirstChild("Look")
			expect(look).never.toBeNil()
			local used: { [Instance]: boolean } = {}
			local checked = 0
			for _, was in (old :: Instance):GetChildren() do
				if was:IsA("BasePart") and (was.Name == "Rail" or was.Name == "Rung") then
					local match: BasePart? = nil
					for _, now in (look :: Instance):GetChildren() do
						if
							now:IsA("BasePart")
							and not used[now]
							and now.Name == was.Name
							and (now.Position - was.Position).Magnitude <= SAME
							and (now.Size - was.Size).Magnitude <= SAME
						then
							match = now
							break
						end
					end
					expect(match).never.toBeNil()
					local now = match :: BasePart
					used[now] = true
					expect(now.CanCollide).toBe(was.CanCollide)
					expect(now.BrickColor).toBe(was.BrickColor)
					expect(now.Material).toBe(was.Material)
					checked += 1
				end
			end
			expect(checked > 0).toBe(true)
		end
	end)
end)
