--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local BODY_PIECES = Helpers.BODY_PIECES
local WALL_MIN_DEGREES = Helpers.WALL_MIN_DEGREES
local firstLines = Helpers.firstLines
local realWorld = Helpers.realWorld
local sideRails = Helpers.sideRails
local wallDegrees = Helpers.wallDegrees

describe("the real world, zones and extras", function()
	-- The open top of his nose, row by row (stuck safety Task 25, test 7). Source: measured read-only in step 2b-3 on
	-- 2026-10-20, with rays that see only his six body pieces. `middle` is the height of his skin at x 0. `right` and
	-- `left` are the walkable half-width on each side, read sideways (plan Task 25, Ruling 1): going out from x 0, the
	-- first place where the sideways tilt of the body-size plane (25 rays on a 4 by 4 stud square) reaches 65 degrees,
	-- or where the skin steps more than 0.5 studs. At z -4.5 there is no edge out to 14 studs, so the row records 3.6,
	-- the inner face of the cap part of the rails.
	type NoseRow = { z: number, middle: number, right: number, left: number }
	local NOSE_ROWS: { NoseRow } = {
		{ z = -12.5, middle = 92.04, right = 2.6, left = 2.9 },
		{ z = -11.5, middle = 93.11, right = 3.5, left = 3.4 },
		{ z = -10.5, middle = 93.79, right = 3.5, left = 3.4 },
		{ z = -9.5, middle = 94.08, right = 3.8, left = 3.7 },
		{ z = -8.5, middle = 94.24, right = 4.5, left = 4.4 },
		{ z = -7.5, middle = 94.17, right = 4.8, left = 5.7 },
		{ z = -6.5, middle = 94.05, right = 5.7, left = 5.7 },
		{ z = -5.5, middle = 93.84, right = 5.7, left = 5.4 },
		{ z = -4.5, middle = 93.35, right = 3.6, left = 3.6 },
	}
	local RAIL_PAST_EDGE = 1.0 -- studs: a rail's inner face is at most this far past the row's walkable edge
	local RAIL_HEIGHTS = { 0.5, 3, 8 } -- studs over his skin at x 0: where the sideways rays go
	local RAIL_REACH = 14 -- studs: how far a sideways ray looks for a rail
	local RAIL_GAP_ALLOWED = 0.2 -- studs: his skin may be this far under a rail's bottom (Ruling 10)
	local RAIL_SKIN_RAY_ABOVE = 30
	local RAIL_SLOT_STEP = 0.25 -- studs between the places a slot is looked for
	local RAIL_MAX_PARTS_PER_SIDE = 2

	-- A ray that sees only his six body pieces.
	local function bodyRayParams(): RaycastParams
		local giant = (realWorld() :: any).Giant :: Instance
		local meshes: { Instance } = {}
		for _, name in BODY_PIECES do
			table.insert(meshes, (giant:FindFirstChild(name) :: Instance):FindFirstChild(name) :: Instance)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = meshes
		params.RespectCanCollide = false
		return params
	end

	-- A ray that sees only the side rails.
	local function railParams(rails: { BasePart }): RaycastParams
		local instances: { Instance } = {}
		for _, rail in rails do
			table.insert(instances, rail)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = instances
		params.RespectCanCollide = false
		return params
	end

	-- A sideways ray from the middle of a row, `over` studs over his skin, that sees only the side rails.
	local function railHit(rails: { BasePart }, row: NoseRow, side: number, over: number): RaycastResult?
		local params = railParams(rails)
		return game:GetService("Workspace")
			:Raycast(Vector3.new(0, row.middle + over, row.z), Vector3.new(side * RAIL_REACH, 0, 0), params)
	end

	-- Rule 20 (One collision source): the rails are not a shelf. At each row, a ray straight down from 30 studs above,
	-- at the rail's bottom inner edge and its bottom outer edge, finds his skin no lower than 0.2 studs under the
	-- rail's bottom (Ruling 10: a ray that starts inside his mesh can't hit it, so the old ray up from inside missed).
	local function railGapProblems(skinParams: RaycastParams, hit: RaycastResult, label: string): { string }
		local problems: { string } = {}
		local rail = hit.Instance :: BasePart
		local bottom = rail.Position.Y - rail.Size.Y / 2
		local inner = Vector3.new(hit.Position.X, bottom, hit.Position.Z)
		local localNormal = rail.CFrame:VectorToObjectSpace(hit.Normal)
		local thickness = math.abs(localNormal.X) * rail.Size.X
			+ math.abs(localNormal.Y) * rail.Size.Y
			+ math.abs(localNormal.Z) * rail.Size.Z
		local outer = inner + Vector3.new(-hit.Normal.X, 0, -hit.Normal.Z).Unit * thickness
		local edges: { { name: string, point: Vector3 } } = {
			{ name = "inner", point = inner },
			{ name = "outer", point = outer },
		}
		for _, edge in edges do
			local edgeName, point = edge.name, edge.point
			local skin = game:GetService("Workspace"):Raycast(
				point + Vector3.new(0, RAIL_SKIN_RAY_ABOVE, 0),
				Vector3.new(0, -2 * RAIL_SKIN_RAY_ABOVE, 0),
				skinParams
			)
			if skin == nil then
				table.insert(problems, `{label}: no skin under the rail's bottom {edgeName} edge`)
			elseif skin.Position.Y < bottom - RAIL_GAP_ALLOWED then
				table.insert(
					problems,
					string.format(
						"%s: his skin is %.2f studs under the rail's bottom %s edge (gap allowed %.1f)",
						label,
						bottom - skin.Position.Y,
						edgeName,
						RAIL_GAP_ALLOWED
					)
				)
			end
		end
		return problems
	end

	-- No slot: between the row's walkable edge and the rail's inner face, no place where a standing body fits (the shared
	-- walk check's own test, with the rails in the world).
	local function railSlotProblems(
		options: PathCheck.Options,
		skinParams: RaycastParams,
		row: NoseRow,
		side: number,
		edge: number,
		railX: number,
		label: string
	): { string }
		local problems: { string } = {}
		local limit = math.cos(math.rad(game:GetService("StarterPlayer").CharacterMaxSlopeAngle))
		local x = edge
		while x < railX - 0.01 do
			local skin = game:GetService("Workspace")
				:Raycast(Vector3.new(side * x, 200, row.z), Vector3.new(0, -250, 0), skinParams)
			if
				skin ~= nil
				and skin.Normal.Y >= limit
				and skin.Material ~= Enum.Material.Water
				and PathCheck.roomToStand(options, skin.Position, skin.Normal)
			then
				table.insert(
					problems,
					string.format("%s: a body fits at x %.2f between the edge and the rail", label, side * x)
				)
				break
			end
			x += RAIL_SLOT_STEP
		end
		return problems
	end

	it("smooth side rails close both sides of the nose top", function()
		local rails = sideRails()
		local problems: { string } = {}
		local counts = { left = 0, right = 0 }
		for _, rail in rails do
			local name =
				string.format("SideRail at (%.1f, %.1f, %.1f)", rail.Position.X, rail.Position.Y, rail.Position.Z)
			if rail.Position.X < 0 then
				counts.left += 1
			else
				counts.right += 1
			end
			if rail.Transparency ~= 1 or not rail.CanCollide or not rail.Anchored then
				table.insert(problems, `{name} is not invisible, solid and anchored`)
			end
			if rail.Material ~= Enum.Material.SmoothPlastic then
				table.insert(problems, `{name} is not smooth (SmoothPlastic)`)
			end
		end
		if counts.left < 1 or counts.left > RAIL_MAX_PARTS_PER_SIDE then
			table.insert(problems, `{counts.left} rail parts on his left (1 to {RAIL_MAX_PARTS_PER_SIDE} allowed)`)
		end
		if counts.right < 1 or counts.right > RAIL_MAX_PARTS_PER_SIDE then
			table.insert(problems, `{counts.right} rail parts on his right (1 to {RAIL_MAX_PARTS_PER_SIDE} allowed)`)
		end

		-- At every row, from the middle: sideways rays at 0.5, 3 and 8 studs over his skin hit a rail (steeper than 75
		-- degrees) no more than 1.0 stud past the row's walkable edge; no gap under it; no slot beside it.
		local skinParams = bodyRayParams()
		local options = PathCheck.defaults(game:GetService("Workspace"))
		local ok, message = pcall(function()
			for _, row in NOSE_ROWS do
				for _, side in { -1, 1 } do
					local edge = if side < 0 then row.left else row.right
					local label = string.format("row z %.1f, %s", row.z, if side < 0 then "left" else "right")
					for _, over in RAIL_HEIGHTS do
						local hit = railHit(rails, row, side, over)
						if hit == nil then
							table.insert(problems, `{label}: no rail {over} studs over his skin`)
						else
							local face = math.abs(hit.Position.X)
							if face > edge + RAIL_PAST_EDGE then
								table.insert(
									problems,
									string.format(
										"%s: the rail at %g studs over his skin is %.2f studs past the edge (%.1f), at most %.1f",
										label,
										over,
										face - edge,
										edge,
										RAIL_PAST_EDGE
									)
								)
							end
							if wallDegrees(hit.Normal) <= WALL_MIN_DEGREES then
								table.insert(
									problems,
									string.format(
										"%s: the rail face is %.1f degrees steep, needs over %d",
										label,
										wallDegrees(hit.Normal),
										WALL_MIN_DEGREES
									)
								)
							end
						end
					end
					local low = railHit(rails, row, side, RAIL_HEIGHTS[1])
					if low ~= nil then
						for _, line in railGapProblems(skinParams, low, label) do
							table.insert(problems, line)
						end
						for _, line in
							railSlotProblems(options, skinParams, row, side, edge, math.abs(low.Position.X), label)
						do
							table.insert(problems, line)
						end
					end
				end
			end
		end)
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		if not ok then
			error(message)
		end
		expect(firstLines(problems)).toEqual({ count = 0, first = {} })
	end)

	-- Proof that the gap and slot checks can fail. A test rail (invisible, Archivable off, destroyed in the test, like the
	-- body probe) beside row z -9.5 whose bottom is 1 stud over his skin has a gap under it, and one whose bottom is 25
	-- studs inside him has none. A slot is found on the nose top at z -8.5 when the rail is 3 studs out and the edge is
	-- taken as 0.5, and none when the rail stands at the edge.
	it("the rail checks notice a gap under a rail and a slot beside it", function()
		local row = NOSE_ROWS[4]
		local skinParams = bodyRayParams()
		local options = PathCheck.defaults(game:GetService("Workspace"))
		local rail = Instance.new("Part")
		rail.Name = "SideRailGapTestRail"
		rail.Size = Vector3.new(1.5, 40, 4)
		rail.Anchored = true
		rail.Transparency = 1
		rail.Archivable = false
		local raised: { string } = {}
		local sunk: { string } = {}
		local slotFound: { string } = {}
		local slotNone: { string } = {}
		local ok, message = pcall(function()
			local function problemsFor(bottom: number): { string }
				rail.CFrame = CFrame.new(5, bottom + 20, row.z)
				rail.Parent = game:GetService("Workspace")
				local hit = railHit({ rail }, row, 1, 3)
				if hit == nil then
					return { "the test rail was not hit" }
				end
				return railGapProblems(skinParams, hit, "test")
			end
			raised = problemsFor(row.middle + 1)
			sunk = problemsFor(row.middle - 25)
			local flatRow = NOSE_ROWS[5]
			slotFound = railSlotProblems(options, skinParams, flatRow, 1, 0.5, 3.0, "test")
			slotNone = railSlotProblems(options, skinParams, flatRow, 1, flatRow.right, flatRow.right, "test")
		end)
		rail:Destroy()
		PathCheck.cleanup(options)
		if not ok then
			error(message)
		end
		expect(#raised > 0).toBe(true)
		expect(sunk).toEqual({})
		expect(#slotFound).toBe(1)
		expect(slotNone).toEqual({})
	end)

	it("the side rails run along both sides of the cap ladder", function()
		local rails = sideRails()
		local ladder = (realWorld() :: any).WalkSurfaces.CapLadder :: Instance
		local rungs: { BasePart } = {}
		for _, part in ladder:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Rung" then
				table.insert(rungs, part)
			end
		end
		expect(#rungs > 2).toBe(true)
		table.sort(rungs, function(a, b)
			return a.Position.Y < b.Position.Y
		end)
		-- up the ladder, and "out" from it: the direction a climber's body is from the rungs (toward his front)
		local up = (rungs[#rungs].Position - rungs[1].Position).Unit
		local out = Vector3.new(0, up.Z, -up.Y)
		local params = railParams(rails)
		-- at every rung, sideways rays from the rung's end, 1 and 3 studs out from the ladder, each hit a rail within 4.5
		-- studs: a climber can only go up or down, never step off the ladder's side
		local open = {}
		for _, rung in rungs do
			for _, side in { -1, 1 } do
				for _, distance in { 1, 3 } do
					local start = rung.Position + Vector3.new(side * rung.Size.X / 2, 0, 0) + out * distance
					local hit = game:GetService("Workspace"):Raycast(start, Vector3.new(side * 4.5, 0, 0), params)
					if hit == nil then
						table.insert(
							open,
							string.format(
								"no rail beside the rung at (%.1f, %.1f, %.1f), side %d, %d studs out",
								rung.Position.X,
								rung.Position.Y,
								rung.Position.Z,
								side,
								distance
							)
						)
					end
				end
			end
		end
		expect(firstLines(open)).toEqual({ count = 0, first = {} })
	end)

	it("no wall sticks out in front of the edges of the middle forehead slab", function()
		-- Where a side wall started inside the middle slab's width, it stood in front of the slab's surface and made
		-- a step that a player walking up the slab could wedge against. The walls must start where the slab ends.
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		-- Task 25: the middle slab is gone, so its half width is the fixed number the walls were built against:
		-- MIDDLE_HALF_WIDTH in tools/world/03b-forehead.luau (the slab was 13.5 wide).
		local middleHalfWidth = 6.75
		local inside = {}
		for _, child in (guard :: Instance):GetChildren() do
			if child:IsA("BasePart") and child.Name == "Guard" and math.abs(child.Position.X) > 7 then
				local innerEdge = math.abs(child.Position.X) - child.Size.X / 2
				if innerEdge < middleHalfWidth - 0.05 then
					table.insert(
						inside,
						string.format("%s at x %.1f starts at %.2f", child.Name, child.Position.X, innerEdge)
					)
				end
			end
		end
		expect(inside).toEqual({})
	end)

	it("a player on the nose top cannot walk off its sides", function()
		-- Rays go sideways from just beside the cap ladder, at every row of the open top of his nose (NOSE_ROWS) and from
		-- 1 to 11 studs over it. A see-through part (the ladder's rails, the invisible eyes) is not a wall, so the ray
		-- looks past it. The first wall must be no more than 1.0 stud past the row's walkable edge.
		local open = {}
		for _, row in NOSE_ROWS do
			for _, direction in { -1, 1 } do
				local edge = if direction < 0 then row.left else row.right
				local z = row.z
				for y = row.middle + 1, row.middle + 11, 2 do
					local ignore: { Instance } = {}
					local wallAt: number? = nil
					for _ = 1, 20 do
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = ignore
						local hit = workspace:Raycast(
							Vector3.new(direction * 3, y, z),
							Vector3.new(direction * 12, 0, 0),
							params
						)
						if hit == nil then
							break
						end
						if hit.Instance.CanCollide then
							wallAt = hit.Position.X
							break
						end
						table.insert(ignore, hit.Instance)
					end
					if wallAt == nil or math.abs(wallAt) > edge + RAIL_PAST_EDGE then
						table.insert(open, string.format("side %d at (z %.1f, y %.1f)", direction, z, y))
					end
				end
			end
		end
		expect(firstLines(open)).toEqual({ count = 0, first = {} })
	end)
end)
