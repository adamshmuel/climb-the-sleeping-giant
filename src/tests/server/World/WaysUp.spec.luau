--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Workspace = game:GetService("Workspace")

-- Plan 3, Task 4a (docs/plans/v2/gardens-and-ways-up.md): the two rope ladders on the boots.
-- Spec Rule 37 (Rope ladders on the boots) and Rule 15 (The climb needs no jump).
-- These tests only READ the real world. The world is built by tools/world/19-ways-up-ladders.luau.

local TOP_HEIGHT = 30.4 -- the outer toe nest height (spec 5's table): the ladder top is level with it
local FOOT_X = 50.6 -- 5b2 moved: product's addendum, spec 3 line 86
local FOOT_Z = -64
local TOP_X = 33.6
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
			local outerX = side * 34.1
			local innerX = side * 29
			expect(math.abs(part.Position.X - (outerX + innerX) / 2) <= 0.1).toBe(true)
			expect(math.abs(part.Size.X - 5.1) <= 0.1).toBe(true)
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

	it("the ladder top is 5 to 6 studs from the outer toe nest spot (Rule 37)", function()
		for _, side in SIDES do
			local top = ends(climbOf(side))
			local distance = (top - Vector3.new(side * NEST_X, TOP_HEIGHT, NEST_Z)).Magnitude
			expect(distance >= 5).toBe(true)
			expect(distance <= 6).toBe(true)
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

-- Tasks 4e3 and 4f (docs/plans/v2/gardens-and-ways-up.md): the Sock and the Teacup stand beside the outer walks.
-- Spec Rule 35 (Every garden has a way up close by). A walk check ray respects collision, and moving a prop
-- moves its helper parts too.
describe("the outer walks are clear of the giant's things (four e three)", function()
	local WALK_CASES =
		{ { plot = 1, side = -1 }, { plot = 2, side = -1 }, { plot = 7, side = 1 }, { plot = 8, side = 1 } }
	local WALK_HEIGHTS = { 1, 3 }
	local WALK_SIDES = { -5, 0, 5 } -- a corridor 10 studs wide
	local FRONT_OF_LADDER = 4
	local HELPER_SAME = 0.05
	local SOCK_HELPERS: { { folder: string, name: string } } = { { folder = "SmallPatches", name = "Ramp_Sock_1" } }
	for i = 1, 25 do
		table.insert(SOCK_HELPERS, { folder = "SmallPatches", name = "Patch_Sock_" .. i })
	end
	for i = 1, 8 do
		table.insert(SOCK_HELPERS, { folder = "SlideGuards", name = "SlideGuard_Sock_" .. i })
	end

	local function worldFolder(name: string): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local found = (world :: Instance):FindFirstChild(name)
		expect(found).never.toBeNil()
		return found :: Instance
	end

	local function thingsFolder(): Instance
		return worldFolder("GiantsThings")
	end

	it("nothing in GiantsThings stands on the walk from each outer spawn to its boot ladder (Rule 35)", function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { thingsFolder() }
		params.RespectCanCollide = true
		for _, case in WALK_CASES do
			local plot = worldFolder("Plots"):FindFirstChild("Plot_" .. case.plot) :: Instance
			expect(plot).never.toBeNil()
			local spawn = plot:FindFirstChild("SpawnSpot") :: BasePart
			expect(spawn).never.toBeNil()
			local top, bottom = ends(climbOf(case.side))
			local outward = Vector3.new(bottom.X - top.X, 0, bottom.Z - top.Z).Unit
			local goal = Vector3.new(bottom.X, 0, bottom.Z) + outward * FRONT_OF_LADDER
			local start = Vector3.new(spawn.Position.X, 0, spawn.Position.Z)
			local across = goal - start
			local sideways = Vector3.new(-across.Z, 0, across.X).Unit
			local groundY = spawn.Position.Y + spawn.Size.Y / 2
			for _, offset in WALK_SIDES do
				for _, height in WALK_HEIGHTS do
					local origin = start + sideways * offset + Vector3.new(0, groundY + height, 0)
					local hit = Workspace:Raycast(origin, across, params)
					local hitName = if hit ~= nil then hit.Instance:GetFullName() else nil
					expect(hitName).toBeNil() -- plot case.plot, side offset, height: what the walk bumps into
				end
			end
		end
	end)

	it("every Sock helper keeps its place on the Sock when the Sock moves", function()
		local backups = game:GetService("ServerStorage"):FindFirstChild("WorldBackups")
		local backup = if backups ~= nil then backups:FindFirstChild("T4e3") else nil
		expect(backup).never.toBeNil()
		local oldSock = (backup :: Instance):FindFirstChild("Sock") :: Model
		expect(oldSock).never.toBeNil()
		local liveSock = thingsFolder():FindFirstChild("Sock") :: Model
		expect(liveSock).never.toBeNil()
		for _, helper in SOCK_HELPERS do
			local was = (backup :: Instance):FindFirstChild(helper.name) :: BasePart
			expect(was).never.toBeNil()
			local now = (walkSurfaces():FindFirstChild(helper.folder) :: Instance):FindFirstChild(
					helper.name
				) :: BasePart
			expect(now).never.toBeNil()
			local wasOffset = oldSock:GetPivot():ToObjectSpace(was.CFrame)
			local nowOffset = liveSock:GetPivot():ToObjectSpace(now.CFrame)
			expect((wasOffset.Position - nowOffset.Position).Magnitude <= HELPER_SAME).toBe(true)
		end
	end)

	it("from the Sock no giant or pillow surface is a jump away (game_creator's jump reach rule)", function()
		local sock = thingsFolder():FindFirstChild("Sock") :: Model
		expect(sock).never.toBeNil()
		local sockParams = RaycastParams.new()
		sockParams.FilterType = Enum.RaycastFilterType.Include
		sockParams.FilterDescendantsInstances = { sock }
		sockParams.RespectCanCollide = true
		local near = OverlapParams.new()
		near.FilterType = Enum.RaycastFilterType.Include
		near.FilterDescendantsInstances = { worldFolder("Giant"), thingsFolder():FindFirstChild("Pillow") :: Instance }
		near.RespectCanCollide = true
		local boxCFrame, boxSize = sock:GetBoundingBox()
		local step = 3
		local checked = 0
		local x = boxCFrame.X - boxSize.X / 2
		while x <= boxCFrame.X + boxSize.X / 2 do
			local z = boxCFrame.Z - boxSize.Z / 2
			while z <= boxCFrame.Z + boxSize.Z / 2 do
				local hit = Workspace:Raycast(
					Vector3.new(x, boxCFrame.Y + boxSize.Y / 2 + 1, z),
					Vector3.new(0, -boxSize.Y - 2, 0),
					sockParams
				)
				if hit ~= nil and hit.Normal.Y > 0.6 then
					checked += 1
					-- the band 0.5 to 7.2 studs above this standing spot, 10 studs across each way
					local band = CFrame.new(hit.Position + Vector3.new(0, 3.85, 0))
					local parts = Workspace:GetPartBoundsInBox(band, Vector3.new(20, 6.7, 20), near)
					local name = if #parts > 0 then parts[1]:GetFullName() else nil
					expect(name).toBeNil()
				end
				z += step
			end
			x += step
		end
		expect(checked > 0).toBe(true)
	end)
end)

-- Plan 3, Task 5 (docs/plans/v2/gardens-and-ways-up.md, "Task 5"): the lap planks, landing, apron and rail guards.
-- Spec Rule 36 (The lap planks) and conditions 1, 2 and 6 of Rule 45 (One way onto the belly). These tests only READ
-- the real world. The world is built by tools/world/27-lap-landing.luau.
describe("the lap planks, landing and apron (task five)", function()
	local BOOT_END = Vector3.new(21.5, 29.6, -55.56)
	local LAND_END = Vector3.new(5.05, 33.2, -54.5)
	local DECK_TOP = 33.2
	local EDGE_X = 5.6
	local FRONT_Z = -59.1
	local BACK_Z = -46.5

	local function piece(name: string): Instance
		local found = walkSurfaces():FindFirstChild(name)
		expect(found).never.toBeNil()
		return found :: Instance
	end

	local function deckOf(model: string): BasePart
		local deck = piece(model):FindFirstChild("Deck")
		expect(deck).never.toBeNil()
		return deck :: BasePart
	end

	-- The deck's top-surface end centres, as (lower end, higher end).
	local function topEnds(deck: BasePart): (Vector3, Vector3)
		local a = (deck.CFrame * CFrame.new(0, deck.Size.Y / 2, deck.Size.Z / 2)).Position
		local b = (deck.CFrame * CFrame.new(0, deck.Size.Y / 2, -deck.Size.Z / 2)).Position
		if a.Y < b.Y then
			return a, b
		end
		return b, a
	end

	local function includeParams(instances: { Instance }): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = instances
		return params
	end

	-- What a walking player stands on: solid parts only, mockups skipped.
	local function groundParams(): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		local skip: { Instance } = {}
		for _, child in Workspace:GetChildren() do
			if string.sub(child.Name, 1, 7) == "Mockup_" then
				table.insert(skip, child)
			end
		end
		params.FilterDescendantsInstances = skip
		return params
	end

	local function down(x: number, z: number, params: RaycastParams): RaycastResult?
		return Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), params)
	end

	local function sideLabel(side: number): string
		return if side < 0 then "Left" else "Right"
	end

	local function planks(): { Model }
		return { piece("LapPlank_Left") :: Model, piece("LapPlank_Right") :: Model }
	end

	local function landingGuards(): { Instance }
		local list: { Instance } = {}
		for _, name in { "LapLanding", "LapApron" } do
			local guards = piece(name):FindFirstChild("Guards")
			expect(guards).never.toBeNil()
			for _, g in (guards :: Instance):GetChildren() do
				table.insert(list, g)
			end
		end
		for _, plank in planks() do
			local g = plank:FindFirstChild("EndGuard")
			expect(g).never.toBeNil()
			table.insert(list, g :: Instance)
		end
		return list
	end

	local function slopeDegrees(wedge: BasePart): number
		return math.deg(math.atan2(wedge.Size.Y, wedge.Size.Z))
	end

	it(
		"puts each lap plank's ends on their spots, at least 9 wide, climbing 9 to 13 degrees, turned about 4",
		function()
			for _, side in SIDES do
				local deck = deckOf("LapPlank_" .. sideLabel(side))
				local low, high = topEnds(deck)
				expect((low - Vector3.new(side * BOOT_END.X, BOOT_END.Y, BOOT_END.Z)).Magnitude <= 0.2).toBe(true)
				expect((high - Vector3.new(side * LAND_END.X, LAND_END.Y, LAND_END.Z)).Magnitude <= 0.2).toBe(true)
				expect(deck.Size.X >= 9 - 0.01).toBe(true)
				local d = high - low
				local climb = math.deg(math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude))
				expect(climb >= 9 and climb <= 13).toBe(true)
				local turn = math.deg(math.atan2(math.abs(d.Z), math.abs(d.X)))
				expect(turn >= 3 and turn <= 5).toBe(true)
			end
		end
	)

	it(
		"makes the landing 11.2 by 5.8 and the apron 11.2 wide, both with the top at 33.2, and each plank end lies on them",
		function()
			local landing = deckOf("LapLanding")
			expect(math.abs(landing.Size.X - 11.2) <= 0.05 and math.abs(landing.Size.Z - 5.8) <= 0.05).toBe(true)
			expect(math.abs(landing.Position.X) <= 0.05 and math.abs(landing.Position.Z + 50.6) <= 0.05).toBe(true) -- spec line 88 (landing 11.2 x 5.8, centre z -50.6; Rule 103 skin line)
			expect(math.abs(landing.Position.Y + landing.Size.Y / 2 - DECK_TOP) <= 0.05).toBe(true)
			local apron = deckOf("LapApron")
			expect(math.abs(apron.Size.X - 11.2) <= 0.05).toBe(true)
			expect(math.abs(apron.Position.Y + apron.Size.Y / 2 - DECK_TOP) <= 0.05).toBe(true)
			expect(math.abs(apron.Position.Z + apron.Size.Z / 2 - -53.5) <= 0.05).toBe(true) -- its back edge, z -53.5
			expect(math.abs(apron.Position.Z - apron.Size.Z / 2 - -59.1) <= 0.05).toBe(true) -- its front edge, z -59.1
			local params = includeParams({ landing, apron })
			for _, side in SIDES do
				local plank = deckOf("LapPlank_" .. sideLabel(side))
				-- the plank's landing end: its two corners, nudged 0.2 in along the plank
				for _, sx in { -1, 1 } do
					local corner = (plank.CFrame * CFrame.new(sx * (plank.Size.X / 2 - 0.05), 0, 0)).Position
					local _, high = topEnds(plank)
					local middle = (plank.CFrame * CFrame.new(0, 0, 0)).Position
					local toEnd = Vector3.new(high.X - middle.X, 0, high.Z - middle.Z).Unit
					local spot = Vector3.new(corner.X, 0, corner.Z) + toEnd * (plank.Size.Z / 2 - 0.2)
					expect(down(spot.X, spot.Z, params)).never.toBeNil()
				end
			end
		end
	)

	it("guards every open edge of the landing and the apron except the plank ends and the belly ramp line", function()
		local guards = landingGuards()
		local params = includeParams(guards)
		for _, g in guards do
			local wedge = g :: BasePart
			expect(wedge:IsA("WedgePart")).toBe(true)
			local top = wedge.Position.Y + wedge.Size.Y / 2
			if wedge.Name == "EndGuard" then
				local endDeck = (wedge.Parent :: Instance):FindFirstChild("Deck") :: BasePart
				local bootEnd = topEnds(endDeck)
				expect(top >= bootEnd.Y + 8 - 0.1).toBe(true)
			else
				expect(top >= DECK_TOP + 8 - 0.1).toBe(true)
			end
			expect(slopeDegrees(wedge) > 75).toBe(true)
		end
		-- the belly ramps cross the landing edge at fixed measured spots: back edge |x| >= 1.25, side edges z >= -49.25
		local function onRampLine(x: number, z: number): boolean
			if z == BACK_Z then
				return math.abs(x) >= 1.25
			end
			return z >= -49.25
		end
		local open: { string } = {}
		local function check(x: number, z: number, outX: number, outZ: number)
			local origin = Vector3.new(x - outX * 0.4, DECK_TOP + 2, z - outZ * 0.4)
			if Workspace:Raycast(origin, Vector3.new(outX, 0, outZ), params) == nil then
				table.insert(open, string.format("(%.1f, %.1f)", x, z))
			end
		end
		for x = -EDGE_X, EDGE_X, 0.5 do
			if not onRampLine(x, BACK_Z) then
				check(x, BACK_Z, 0, 1)
			end
			check(x, FRONT_Z, 0, -1)
		end
		for z = FRONT_Z, BACK_Z, 0.5 do
			for _, side in SIDES do
				local planksEnd = z >= -59 and z <= -50
				if not planksEnd and not onRampLine(side * EDGE_X, z) then
					check(side * EDGE_X, z, side, 0)
				end
			end
		end
		expect(#open).toBe(0)
		if #open > 0 then
			error("unguarded edge spots: " .. table.concat(open, " "))
		end
		-- each plank's end guard covers the part over the boot drop (z -56.3 to -51.3) but not the step-off strip
		for _, plank in planks() do
			local deck = plank:FindFirstChild("Deck") :: BasePart
			local low = topEnds(deck)
			local localEnd = deck.CFrame:PointToObjectSpace(low)
			local sign = if localEnd.Z >= 0 then 1 else -1
			local endParams = includeParams({ plank:FindFirstChild("EndGuard") :: Instance })
			for xl = -4.5, 4.5, 0.25 do
				local at = deck.CFrame * CFrame.new(xl, deck.Size.Y / 2 + 2, sign * (deck.Size.Z / 2 - 0.5))
				local out = (deck.CFrame * CFrame.new(xl, deck.Size.Y / 2 + 2, sign * (deck.Size.Z / 2 + 1))).Position
					- at.Position
				local hit = Workspace:Raycast(at.Position, out, endParams)
				local z = at.Position.Z
				if z >= -56.3 and z <= -51.3 then
					expect(hit).never.toBeNil()
				elseif z >= -58.5 and z <= -56.8 then
					expect(hit).toBeNil()
				end
			end
		end
	end)

	it("stands each rail guard on its plank's inner rope rail, 12 tall, steep, ending at the landing", function()
		for _, side in SIDES do
			local plank = piece("LapPlank_" .. sideLabel(side))
			local rope: BasePart? = nil
			for _, c in plank:GetChildren() do
				if c.Name == "Rope" and c:IsA("BasePart") and (rope == nil or c.Position.Z > rope.Position.Z) then
					rope = c
				end
			end
			expect(rope).never.toBeNil()
			local inner = rope :: BasePart
			local guard = piece("RailGuard_" .. sideLabel(side)) :: BasePart
			expect(guard:IsA("WedgePart")).toBe(true)
			local flat = Vector2.new(guard.Position.X - inner.Position.X, guard.Position.Z - inner.Position.Z)
			expect(flat.Magnitude <= 0.2).toBe(true)
			-- the rope, its posts and the guard stand on the deck edges (deck is 9 wide), the guard on the body side
			local deck = plank:FindFirstChild("Deck") :: BasePart
			local function edgeX(part: BasePart): number
				return deck.CFrame:PointToObjectSpace(part.Position).X
			end
			local bodyEdgeX = if (deck.CFrame * CFrame.new(4.5, 0, 0)).Position.Z
					> (deck.CFrame * CFrame.new(-4.5, 0, 0)).Position.Z
				then 4.5
				else -4.5
			expect(math.abs(edgeX(guard) - bodyEdgeX) <= 0.2).toBe(true)
			for _, c in plank:GetChildren() do
				if (c.Name == "Rope" or c.Name == "Post") and c:IsA("BasePart") then
					expect(math.abs(math.abs(edgeX(c)) - 4.5) <= 0.2).toBe(true)
				end
			end
			local lowEnd, highEnd = topEnds(plank:FindFirstChild("Deck") :: BasePart)
			expect(math.abs(guard.Position.Y + guard.Size.Y / 2 - (highEnd.Y + 12)) <= 0.3).toBe(true)
			expect(math.abs(guard.Position.Y - guard.Size.Y / 2 - (lowEnd.Y - 0.6)) <= 0.5).toBe(true)
			expect(slopeDegrees(guard) > 75).toBe(true)
			-- the guard's end nearest the middle lies within 0.5 of the rope's landing end
			local guardTips = {
				(guard.CFrame * CFrame.new(guard.Size.X / 2, 0, 0)).Position,
				(guard.CFrame * CFrame.new(-guard.Size.X / 2, 0, 0)).Position,
			}
			local nearest = if math.abs(guardTips[1].X) < math.abs(guardTips[2].X) then guardTips[1] else guardTips[2]
			local ropeHigh = (inner.CFrame * CFrame.new(0, 0, inner.Size.Z / 2)).Position
			local ropeOther = (inner.CFrame * CFrame.new(0, 0, -inner.Size.Z / 2)).Position
			if math.abs(ropeOther.X) < math.abs(ropeHigh.X) then
				ropeHigh = ropeOther
			end
			expect(Vector2.new(nearest.X - ropeHigh.X, nearest.Z - ropeHigh.Z).Magnitude <= 0.5).toBe(true)
		end
	end)

	it("leaves egg spots 2 and 4 uncovered and reachable from each boot top with no jump", function()
		local covers: { Instance } = {}
		for _, name in
			{ "LapPlank_Left", "LapPlank_Right", "LapLanding", "LapApron", "RailGuard_Left", "RailGuard_Right" }
		do
			table.insert(covers, piece(name))
		end
		local world = Workspace:FindFirstChild("World") :: Instance
		local spots = {
			{ name = "EggSpot_Uncommon_2", side = -1 },
			{ name = "EggSpot_Uncommon_4", side = 1 },
		}
		for _, spot in spots do
			local part = (world :: any).EggSpots:FindFirstChild(spot.name)
			expect(part).never.toBeNil()
			local pos = (part :: PVInstance):GetPivot().Position
			expect(down(pos.X, pos.Z, includeParams(covers))).toBeNil()
			local from = Vector2.new(spot.side * 22.2, -60)
			local to = Vector2.new(pos.X, pos.Z)
			local steps = math.ceil((to - from).Magnitude / 0.5)
			local prev: number? = nil
			for i = 0, steps do
				local p = from:Lerp(to, i / steps)
				local hit = down(p.X, p.Y, groundParams())
				expect(hit).never.toBeNil()
				local y = (hit :: RaycastResult).Position.Y
				if prev ~= nil and y - prev > 1 then
					error(`step of {y - prev} up at ({p.X}, {p.Y}) on the way to {spot.name}`)
				end
				prev = y
			end
		end
	end)

	it("rests each plank's boot end on the boot top with no step over 0.3 on the step-off strip", function()
		for _, side in SIDES do
			local deck = deckOf("LapPlank_" .. sideLabel(side))
			local low = topEnds(deck)
			for z = -58.5, -56.7, 0.3 do
				local boot = down(side * (BOOT_END.X + 0.7), z, groundParams())
				local onDeck = down(side * (BOOT_END.X - 0.5), z, groundParams())
				expect(boot).never.toBeNil()
				expect(onDeck).never.toBeNil()
				local step = math.abs((boot :: RaycastResult).Position.Y - (onDeck :: RaycastResult).Position.Y)
				if step > 0.3 then
					error(`step of {step} at z {z} on the {sideLabel(side)} boot (deck end y {low.Y})`)
				end
			end
		end
		local step = walkSurfaces():FindFirstChild("Boots_Walk") :: BasePart
		expect(step.Position.X + step.Size.X / 2 <= -21.5 + 0.05).toBe(true)
	end)

	it("makes the planks, the landing and the apron solid, and their decks visible wood", function()
		for _, name in { "LapPlank_Left", "LapPlank_Right", "LapLanding", "LapApron" } do
			local deck = deckOf(name)
			expect(deck.CanCollide).toBe(true)
			expect(deck.CanQuery).toBe(true)
			expect(deck.Transparency).toBe(0)
			expect(deck.Material).toBe(Enum.Material.WoodPlanks)
		end
	end)

	it("has no mockup attributes on any piece it took, and every deck and guard is solid", function()
		local roots: { Instance } = {}
		for _, name in
			{
				"LapPlank_Left",
				"LapPlank_Right",
				"LapLanding",
				"LapApron",
				"RailGuard_Left",
				"RailGuard_Right",
			}
		do
			table.insert(roots, piece(name))
		end
		for _, root in roots do
			local all = root:GetDescendants()
			table.insert(all, root)
			for _, d in all do
				for attribute in d:GetAttributes() do
					if string.sub(attribute, 1, 6) == "Mockup" then
						error(`{d:GetFullName()} still has {attribute}`)
					end
				end
				if
					d:IsA("BasePart")
					and (
						d.Name == "Deck"
						or d.Name == "EndGuard"
						or d.Parent ~= nil and d.Parent.Name == "Guards"
						or string.sub(d.Name, 1, 9) == "RailGuard"
					)
				then
					expect(d.CanCollide).toBe(true)
					expect(d.CanQuery).toBe(true)
				end
			end
		end
	end)

	it("nothing solid sticks up through a lap plank's walkway", function()
		local params = groundParams()
		local bad: { string } = {}
		for _, plank in planks() do
			local deck = plank:FindFirstChild("Deck") :: BasePart
			local halfLength = deck.Size.Z / 2
			-- the high end (local -Z) overlaps the landing and apron on purpose, so its last stud is theirs
			local lz = -halfLength + 1
			while lz <= halfLength do
				for lx = -4.2, 4.2, 0.5 do
					local top = deck.CFrame * CFrame.new(lx, deck.Size.Y / 2, lz)
					local origin = top.Position + Vector3.new(0, 8, 0)
					local hit = Workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
					if hit == nil or hit.Instance ~= deck then
						local name = if hit then hit.Instance:GetFullName() else "nothing"
						table.insert(bad, string.format("%s at (%.1f, %.1f)", name, top.Position.X, top.Position.Z))
					end
				end
				lz += 0.5
			end
		end
		if #bad > 0 then
			error(#bad .. " walkway spots blocked: " .. table.concat(bad, "; ", 1, math.min(#bad, 4)))
		end
		expect(#bad).toBe(0)
	end)

	it("a toe guard walls each boot top off from the toe slope and meets its neighbours", function()
		local params = groundParams()
		local bad: { string } = {}
		local steep = walkSurfaces():FindFirstChild("SteepGuards") :: Instance
		local backWall = { [-1] = "BootFront_-18.4", [1] = "BootFront_13" }
		local function halfZ(part: BasePart): number -- half the part's reach along z
			local c = part.CFrame
			return (
				math.abs(c.RightVector.Z) * part.Size.X
				+ math.abs(c.UpVector.Z) * part.Size.Y
				+ math.abs(c.LookVector.Z) * part.Size.Z
			) / 2
		end
		for _, side in SIDES do
			local guard = piece("ToeGuard_" .. sideLabel(side)) :: BasePart
			local guardLo, guardHi = guard.Position.Z - halfZ(guard), guard.Position.Z + halfZ(guard)
			local z = -68.5
			while z <= -60 do -- every boot-top spot from the back wall to the plank: a wall, not the toe slope
				local top = down(side * 22, z, params)
				for _, up in { 0.5, 3 } do
					local from = Vector3.new(side * 22, (top :: RaycastResult).Position.Y + up, z)
					local hit = Workspace:Raycast(from, Vector3.new(side * -14, 0, 0), params)
					if hit == nil or (hit.Instance ~= guard and hit.Instance.Parent ~= steep) then
						table.insert(bad, string.format("%s: open at z %.1f, %.1f up", sideLabel(side), z, up))
					end
				end
				z += 0.5
			end
			local back = steep:FindFirstChild(backWall[side]) :: BasePart
			if guardLo > back.Position.Z + halfZ(back) + 1 then
				table.insert(bad, sideLabel(side) .. ": gap to " .. back.Name)
			end
			local outer: BasePart? = nil
			for _, c in piece("LapPlank_" .. sideLabel(side)):GetChildren() do
				local best = outer
				if c:IsA("BasePart") and c.Name == "Rope" and (best == nil or c.Position.Z < best.Position.Z) then
					outer = c
				end
			end
			if (outer :: BasePart).Position.Z - halfZ(outer :: BasePart) - guardHi > 1 then
				table.insert(bad, sideLabel(side) .. ": gap to the plank's outer rope")
			end
		end
		if #bad > 0 then
			error(#bad .. " toe problems: " .. table.concat(bad, "; ", 1, math.min(#bad, 4)))
		end
		expect(#bad).toBe(0)
	end)

	it("a player walks from the boot ladder top up the plank", function()
		local params = groundParams()
		local problems: { string } = {}

		-- one walk: a list of (x, z) points, each with the way it faces
		local function walk(label: string, points: { Vector3 }, forward: { Vector3 }, plankDeck: BasePart)
			local lastY: number? = nil
			local lastWasDeck = false
			for i, at in points do
				local hit = down(at.X, at.Z, params)
				if hit == nil then
					table.insert(problems, string.format("%s: no floor at (%.1f, %.1f)", label, at.X, at.Z))
					return
				end
				local onDeck = hit.Instance == plankDeck
				local y = hit.Position.Y
				if lastY ~= nil then
					local limit = if onDeck and not lastWasDeck then 0.3 else 1.0
					if y - lastY > limit then
						table.insert(
							problems,
							string.format(
								"%s: step up %.2f at (%.1f, %.1f) onto %s",
								label,
								y - lastY,
								at.X,
								at.Z,
								hit.Instance.Name
							)
						)
						return
					end
				end
				if hit.Normal.Y < 0.6 then
					table.insert(
						problems,
						string.format("%s: steep floor %.2f at (%.1f, %.1f)", label, hit.Normal.Y, at.X, at.Z)
					)
					return
				end
				local shin = Workspace:Raycast(hit.Position + Vector3.new(0, 1.5, 0), forward[i], params)
				if shin ~= nil and shin.Normal.Y < 0.6 then
					table.insert(
						problems,
						string.format(
							"%s: shin blocked by %s at (%.1f, %.1f)",
							label,
							shin.Instance:GetFullName(),
							at.X,
							at.Z
						)
					)
					return
				end
				lastY = y
				lastWasDeck = onDeck
			end
		end

		for _, side in SIDES do
			local plank = piece("LapPlank_" .. sideLabel(side))
			local deck = plank:FindFirstChild("Deck") :: BasePart
			-- the route over the boot top: every 0.5 stud along the corner points
			local corners = {
				Vector3.new(29 * side, 0, -64),
				Vector3.new(22.5 * side, 0, -61.5),
				Vector3.new(22 * side, 0, -57.5),
				Vector3.new(21.5 * side, 0, -57.5),
			}
			local points: { Vector3 } = {}
			local forward: { Vector3 } = {}
			for c = 1, #corners - 1 do
				local delta = corners[c + 1] - corners[c]
				local dir = delta.Unit
				local steps = math.ceil(delta.Magnitude / 0.5)
				for k = 0, steps - 1 do
					table.insert(points, corners[c] + dir * (delta.Magnitude * k / steps))
					table.insert(forward, dir)
				end
			end
			table.insert(points, corners[#corners])
			table.insert(forward, forward[#forward])
			walk(sideLabel(side) .. " boot top", points, forward, deck)

			-- three lanes up the deck, low end to high end
			local low, high = topEnds(deck)
			local dir = Vector3.new(high.X - low.X, 0, high.Z - low.Z).Unit
			local length = Vector3.new(high.X - low.X, 0, high.Z - low.Z).Magnitude
			for _, lx in { -3, 0, 3 } do
				local laneOffset = deck.CFrame.RightVector * lx
				local lanePoints: { Vector3 } = {}
				local laneForward: { Vector3 } = {}
				local t = 0.5
				while t <= length - 0.5 do
					local p = low + dir * t + Vector3.new(laneOffset.X, 0, laneOffset.Z)
					table.insert(lanePoints, p)
					table.insert(laneForward, dir)
					t += 0.5
				end
				walk(sideLabel(side) .. " lane " .. lx, lanePoints, laneForward, deck)
			end
		end
		if #problems > 0 then
			error(table.concat(problems, "; "))
		end
		expect(#problems).toBe(0)
	end)
end)
