--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local Helpers = require(script.Parent.Helpers)
local WalkHelpers = require(script.Parent.WalkHelpers)
local BODY_PIECES = Helpers.BODY_PIECES
local describePoint = Helpers.describePoint
local realWorld = Helpers.realWorld
local WINDOW_SLACK = WalkHelpers.WINDOW_SLACK
local ladderAxis = WalkHelpers.ladderAxis
local ladderParts = WalkHelpers.ladderParts
local longSide = WalkHelpers.longSide
local walkFolder = WalkHelpers.walkFolder

describe("the real world, the walk pieces sit on his skin", function()
	-- What V1's ladders look like. Source: the V1 ladders as recorded before Task 25 (the state note's "STEP 1a" block,
	-- read again from the open place on 2026-10-20). Rails are cylinders 0.45 across, rungs are blocks, the truss is the
	-- invisible climbable part.
	type PartLook = {
		className: string,
		shape: Enum.PartType?,
		material: Enum.Material,
		color: string,
		transparency: number,
		canCollide: boolean,
		canQuery: boolean,
		canTouch: boolean,
	}
	local RAIL_LOOK: PartLook = {
		className = "Part",
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Fabric,
		color = "f0deb4",
		transparency = 0,
		canCollide = false,
		canQuery = true,
		canTouch = true,
	}
	local RUNG_LOOK: PartLook = {
		className = "Part",
		shape = Enum.PartType.Block,
		material = Enum.Material.Wood,
		color = "c48c5c",
		transparency = 0,
		canCollide = false,
		canQuery = true,
		canTouch = true,
	}
	local TRUSS_LOOK: PartLook = {
		className = "TrussPart",
		shape = nil,
		material = Enum.Material.Plastic,
		color = "a3a2a5",
		transparency = 1,
		canCollide = true,
		canQuery = true,
		canTouch = true,
	}
	local RAIL_THICKNESS = 0.45 -- studs: a rail is 0.45 by 0.45 across (its length changes)
	local RUNG_SIZE = Vector3.new(5.2, 0.45, 0.6)
	local TRUSS_WIDTH = 2 -- studs: a truss is 2 by 2 across and a multiple of 2 long (Roblox docs, TrussPart)
	local RUNG_SPACING = 1.8 -- studs between rung centres...
	local SPACING_SLACK = 0.05 -- ...give or take this much
	-- The foot of the beard ladder's truss. V1 built it at (0, 67.299, -24.501). Task 26 (his solid body sits where he's
	-- drawn) makes the truss 2.0 studs longer at its bottom end, on the same line, with its top end unchanged (designer
	-- said yes, on condition the climb starts on the visible ladder): the foot is now 2.0 lower along the ladder,
	-- 16 studs from the truss centre (0, 80.018, -18.651) at 65.3 degrees, which is (0, 65.482, -25.337). Invisible, so
	-- the look does not change. Task 26 Ruling 8: the truss grows 2.0 studs more at its bottom end (30 -> 32 long), so
	-- the foot is 18 studs from that centre: (0, 63.665, -26.173). Task 26 Ruling 12: the foot end swings 1.0 stud back
	-- toward his beard (top end unchanged, still 32 long), so the foot is (0, 63.261, -25.258).
	local BEARD_FOOT = Vector3.new(0, 63.261, -25.258)
	-- ...and its lowest rung's middle: designer's change after the side views (the rails reach his belly), now two
	-- rungs 1.8 studs down the ladder each from V1's lowest rung, which was at (0, 67.2230, -24.5360). The second sits
	-- in open air 1.64 studs from his drawn skin (measured on 2026-10-21, Task 25 step 1); a third would sink into him.
	local BEARD_LOWEST_RUNG = Vector3.new(0, 63.952, -26.040)
	local FOOT_SLACK = 0.05 -- studs the beard ladder's foot and lowest rung may move
	local LOOK_SLACK = 0.001 -- studs: rounding in the sizes written into the world

	local function lookProblems(part: BasePart, look: PartLook, label: string, problems: { string })
		local function wrong(what: string, got: any, want: any)
			table.insert(problems, `{label}: {what} is {got}, it must be {want}`)
		end
		if part.ClassName ~= look.className then
			wrong("its kind", part.ClassName, look.className)
		end
		if look.shape ~= nil and part:IsA("Part") and part.Shape ~= look.shape then
			wrong("its shape", part.Shape.Name, look.shape.Name)
		end
		if part.Material ~= look.material then
			wrong("its material", part.Material.Name, look.material.Name)
		end
		if part.Color:ToHex():lower() ~= look.color then
			wrong("its colour", part.Color:ToHex():lower(), look.color)
		end
		if part.Transparency ~= look.transparency then
			wrong("its transparency", part.Transparency, look.transparency)
		end
		if part.CanCollide ~= look.canCollide then
			wrong("CanCollide", part.CanCollide, look.canCollide)
		end
		if part.CanQuery ~= look.canQuery then
			wrong("CanQuery", part.CanQuery, look.canQuery)
		end
		if part.CanTouch ~= look.canTouch then
			wrong("CanTouch", part.CanTouch, look.canTouch)
		end
	end

	-- Every way a ladder differs from V1's look: sizes across, colour, material, see-through and collision settings,
	-- a truss a multiple of 2 long, rungs evenly spaced and, for the beard ladder, a foot and lowest rung where V1 had them.
	-- Takes the ladder as an argument so the test below can check a damaged copy.
	local function ladderLookProblems(ladder: Instance, ladderName: string): { string }
		local problems: { string } = {}
		for _, rail in ladderParts(ladder, "Rail") do
			lookProblems(rail, RAIL_LOOK, `{ladderName} rail`, problems)
			if
				math.abs(rail.Size.Y - RAIL_THICKNESS) > LOOK_SLACK
				or math.abs(rail.Size.Z - RAIL_THICKNESS) > LOOK_SLACK
			then
				table.insert(
					problems,
					`{ladderName} rail: it is {rail.Size.Y} by {rail.Size.Z} across, it must be 0.45`
				)
			end
		end
		local rungs = ladderParts(ladder, "Rung")
		for _, rung in rungs do
			lookProblems(rung, RUNG_LOOK, `{ladderName} rung`, problems)
			if (rung.Size - RUNG_SIZE).Magnitude > LOOK_SLACK then
				table.insert(problems, `{ladderName} rung: its size is {rung.Size}, it must be {RUNG_SIZE}`)
			end
		end
		local trusses = ladderParts(ladder, "Climb")
		if #trusses ~= 1 then
			table.insert(problems, `{ladderName}: it has {#trusses} Climb parts, it must have 1`)
		end
		for _, truss in trusses do
			lookProblems(truss, TRUSS_LOOK, `{ladderName} truss`, problems)
			local half = truss.Size.Z / 2
			if
				math.abs(truss.Size.X - TRUSS_WIDTH) > LOOK_SLACK
				or math.abs(truss.Size.Y - TRUSS_WIDTH) > LOOK_SLACK
				or truss.Size.Z < TRUSS_WIDTH - LOOK_SLACK
				or math.abs(half - math.round(half)) > LOOK_SLACK
			then
				table.insert(
					problems,
					`{ladderName} truss: its size is {truss.Size}, it must be 2 by 2 by a multiple of 2`
				)
			end
		end

		-- rungs evenly spaced, in order along the ladder
		if #trusses == 1 and #rungs > 1 then
			local axis = ladderAxis(ladder)
			table.sort(rungs, function(a: BasePart, b: BasePart): boolean
				return a.Position:Dot(axis.up) < b.Position:Dot(axis.up)
			end)
			local badSpacing = 0
			local worst = 0
			for index = 2, #rungs do
				local spacing = (rungs[index].Position - rungs[index - 1].Position).Magnitude
				if math.abs(spacing - RUNG_SPACING) > SPACING_SLACK then
					badSpacing += 1
					worst = if math.abs(spacing - RUNG_SPACING) > math.abs(worst - RUNG_SPACING) then spacing else worst
				end
			end
			if badSpacing > 0 then
				table.insert(
					problems,
					string.format(
						"%s: %d rung gaps are not %g apart (the worst is %.2f)",
						ladderName,
						badSpacing,
						RUNG_SPACING,
						worst
					)
				)
			end

			if ladderName == "BeardLadder" then
				if (axis.foot - BEARD_FOOT).Magnitude > FOOT_SLACK then
					table.insert(problems, `BeardLadder: its foot moved to {describePoint(axis.foot)}`)
				end
				if (rungs[1].Position - BEARD_LOWEST_RUNG).Magnitude > FOOT_SLACK then
					table.insert(problems, `BeardLadder: its lowest rung moved to {describePoint(rungs[1].Position)}`)
				end
			end
		end
		return problems
	end

	it("both ladders keep their look", function()
		local walk = walkFolder()
		local problems: { string } = {}
		for _, ladderName in { "BeardLadder", "CapLadder" } do
			local ladder = walk:FindFirstChild(ladderName)
			expect(ladder).never.toBeNil()
			for _, line in ladderLookProblems(ladder :: Instance, ladderName) do
				table.insert(problems, line)
			end
		end
		expect(problems).toEqual({})
	end)

	-- The check above is not a rubber stamp: a copy of the beard ladder (outside the Workspace) with one rung moved
	-- 0.3 studs along the ladder is reported, and the copy is thrown away.
	it("the look check notices one rung moved 0.3 studs", function()
		local original = walkFolder():FindFirstChild("BeardLadder")
		expect(original).never.toBeNil()
		local copy = (original :: Instance):Clone()
		local rungs = ladderParts(copy, "Rung")
		local axis = ladderAxis(copy)
		local moved = rungs[#rungs // 2]
		moved.CFrame += axis.up * 0.3
		local problems = ladderLookProblems(copy, "BeardLadder copy")
		copy:Destroy()
		expect(#problems).toBeGreaterThan(0)
		expect(problems[1]).toContain("rung gaps are not")
	end)

	-- Designer's change after the side views (stuck safety Task 25, "Ruling after step 6b-1"): the beard ladder's visible
	-- rails reach down to his belly. Each rail's lowest corners are at most 0.2 studs above his skin and at most 0.3
	-- studs into it (a ray straight down from 1 stud over the corner, seeing only his body), and each rail's top end has
	-- not moved from where V1 and Task 25's tilt put it.
	local BEARD_RAIL_TOPS = { Vector3.new(-2.4, 92.919, -12.717), Vector3.new(2.4, 92.919, -12.717) } -- source: step 6b-1a
	local BEARD_RAIL_TOP_SLACK = 0.05 -- studs the top end may move
	local BEARD_RAIL_ABOVE = 0.2 -- studs: the lowest corner may be this far over his skin
	local BEARD_RAIL_INTO = 0.3 -- studs: ...and this far into it
	local BEARD_CORNER_RAY_ABOVE = 1 -- studs: the drawn skin is looked for from this far over the corner

	-- What is wrong with each beard ladder rail's bottom end and top end, as short sentences (empty is good).
	local function beardRailProblems(ladder: Instance, skin: DrawnSkin.Skin): { string }
		local problems: { string } = {}
		local rails = ladderParts(ladder, "Rail")
		if #rails ~= 2 then
			return { `the beard ladder has {#rails} rails, it must have 2` }
		end
		table.sort(rails, function(a: BasePart, b: BasePart): boolean
			return a.Position.X < b.Position.X
		end)
		local axis = ladderAxis(ladder)
		for index, rail in rails do
			local direction, length = longSide(rail)
			if direction:Dot(axis.up) < 0 then
				direction = -direction
			end
			local half = rail.Size / 2
			-- the top end's middle must not have moved
			local top = rail.Position + direction * length / 2
			local moved = (top - BEARD_RAIL_TOPS[index]).Magnitude
			if moved > BEARD_RAIL_TOP_SLACK then
				table.insert(problems, `rail {index}: its top end moved {string.format("%.2f", moved)} studs`)
			end
			-- the corners of the bottom end, lowest first
			local corners: { Vector3 } = {}
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = rail.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						if (corner - rail.Position):Dot(direction) < 0 then
							table.insert(corners, corner)
						end
					end
				end
			end
			table.sort(corners, function(a: Vector3, b: Vector3): boolean
				return a.Y < b.Y
			end)
			for cornerIndex = 1, #corners do
				local corner = corners[cornerIndex]
				if corner.Y - corners[1].Y > WINDOW_SLACK then
					break
				end
				-- the drawn skin (not his solid shape) under the corner, looked for from 1 stud over it
				local skinHeight = skin.heightAt(corner.X, corner.Z, corner.Y + BEARD_CORNER_RAY_ABOVE)
				if skinHeight == nil then
					table.insert(
						problems,
						`rail {index}: no drawn skin under its lowest corner {describePoint(corner)}`
					)
				else
					local gap = corner.Y - skinHeight -- positive: over his skin, negative: into it
					if gap > BEARD_RAIL_ABOVE + WINDOW_SLACK or gap < -BEARD_RAIL_INTO - WINDOW_SLACK then
						table.insert(
							problems,
							`rail {index}: its lowest corner {describePoint(corner)} is {string.format("%.2f", gap)} studs over his skin, it must be between -0.3 and 0.2`
						)
					end
				end
			end
		end
		return problems
	end

	it("the beard ladder's rails reach his belly", function()
		local ladder = walkFolder():FindFirstChild("BeardLadder")
		expect(ladder).never.toBeNil()
		-- measured against the skin that is DRAWN (the mesh triangles plus any shirt folds), as designer asked
		local meshes: { MeshPart } = {}
		for _, name in BODY_PIECES do
			local piece = ((realWorld() :: any).Giant :: Instance):FindFirstChild(name)
			table.insert(meshes, (piece :: Instance):FindFirstChild(name) :: MeshPart)
		end
		local folds: { BasePart } = {}
		local foldFolder = ((realWorld() :: any).Giant :: Instance):FindFirstChild("ShirtFolds")
		if foldFolder then
			for _, descendant in foldFolder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(folds, descendant)
				end
			end
		end
		local skin = DrawnSkin.fromWorld(meshes, folds)
		expect(beardRailProblems(ladder :: Instance, skin)).toEqual({})
	end, 60000) -- reading the six meshes takes a few seconds

	-- Task 26, Ruling 12 (designer's test for the hidden climbing truss: a player may only grab it where he visibly
	-- touches the ladder). The truss is 2 studs thick and its centre line runs along the visible rails, so its front
	-- face stands 1 stud out from the rungs: a walker crossing in front of the ladder's foot was lifted off his cloth.
	-- The truss's top end stays where it is and its foot end swings back toward his beard, still 2 by 2 by 32.
	local BEARD_TRUSS_TOP = Vector3.new(0, 92.7371, -12.8009) -- the truss's top end, as Ruling 8 left it
	local BEARD_TRUSS_TOP_SLACK = 0.05 -- studs the top end may move
	local BEARD_TRUSS_FRONT_BOTTOM_MIN_Z = -26.33 -- the front-bottom edge is no more than 0.3 south of the rails' foot
	local BEARD_TRUSS_FRONT_BOTTOM_MAX_Y = 64.1
	local BEARD_TRUSS_BEHIND_MIN = 0.5 -- studs: the truss's foot point is at least this far behind the rails' foot plane

	-- What is wrong with the beard ladder's climbing truss, as short sentences (empty is good).
	local function beardTrussStartProblems(ladder: Instance): { string }
		local problems: { string } = {}
		local truss = ladder:FindFirstChild("Climb")
		expect(truss).never.toBeNil()
		local part = truss :: BasePart
		local sizes = { part.Size.X, part.Size.Y, part.Size.Z }
		table.sort(sizes)
		if
			math.abs(sizes[1] - TRUSS_WIDTH) > LOOK_SLACK
			or math.abs(sizes[2] - TRUSS_WIDTH) > LOOK_SLACK
			or math.abs(sizes[3] - 32) > LOOK_SLACK
		then
			table.insert(problems, `the truss is {part.Size}, it must be 2 by 2 by 32`)
		end

		local axis = ladderAxis(ladder)
		local moved = (axis.top - BEARD_TRUSS_TOP).Magnitude
		if moved > BEARD_TRUSS_TOP_SLACK then
			table.insert(problems, `the truss's top end moved {string.format("%.2f", moved)} studs`)
		end

		-- the front of the truss faces away from his beard; its front-bottom edge is half a thickness in front of the foot
		local front = -axis.back
		local frontBottom = axis.foot + front * (TRUSS_WIDTH / 2)
		if frontBottom.Z < BEARD_TRUSS_FRONT_BOTTOM_MIN_Z - WINDOW_SLACK then
			table.insert(
				problems,
				`the truss's front-bottom edge is at z {string.format("%.2f", frontBottom.Z)}, it must be {BEARD_TRUSS_FRONT_BOTTOM_MIN_Z} or more (toward his beard)`
			)
		end
		if frontBottom.Y > BEARD_TRUSS_FRONT_BOTTOM_MAX_Y + WINDOW_SLACK then
			table.insert(
				problems,
				`the truss's front-bottom edge is at y {string.format("%.2f", frontBottom.Y)}, it must be {BEARD_TRUSS_FRONT_BOTTOM_MAX_Y} or less`
			)
		end

		-- the rails' foot plane: square to the ladder, through the middle of the two rails' lower ends
		local rails = ladderParts(ladder, "Rail")
		if #rails ~= 2 then
			table.insert(problems, `the beard ladder has {#rails} rails, it must have 2`)
			return problems
		end
		local railsFoot = Vector3.zero
		for _, rail in rails do
			local direction, length = longSide(rail)
			if direction:Dot(axis.up) < 0 then
				direction = -direction
			end
			railsFoot += (rail.Position - direction * length / 2) / 2
		end
		local behind = -(axis.foot - railsFoot):Dot(front)
		if behind < BEARD_TRUSS_BEHIND_MIN - WINDOW_SLACK then
			table.insert(
				problems,
				`the truss's foot point is {string.format("%.2f", behind)} studs behind the rails' foot plane, it must be at least {BEARD_TRUSS_BEHIND_MIN}`
			)
		end
		return problems
	end

	it("the beard truss starts at the visible ladder's foot", function()
		local ladder = walkFolder():FindFirstChild("BeardLadder")
		expect(ladder).never.toBeNil()
		expect(beardTrussStartProblems(ladder :: Instance)).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Crossing ramps
	----------------------------------------------------------------------------------------------------------------
end)
