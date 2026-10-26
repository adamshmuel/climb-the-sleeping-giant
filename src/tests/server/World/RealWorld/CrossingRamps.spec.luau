--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local WalkHelpers = require(script.Parent.WalkHelpers)
local describePoint = Helpers.describePoint
local GRID_INSET = WalkHelpers.GRID_INSET
local GRID_STEP = WalkHelpers.GRID_STEP
local WINDOW_ABOVE = WalkHelpers.WINDOW_ABOVE
local WINDOW_BELOW = WalkHelpers.WINDOW_BELOW
local WINDOW_SLACK = WalkHelpers.WINDOW_SLACK
local bodyParams = WalkHelpers.bodyParams
local bodySlopeAt = WalkHelpers.bodySlopeAt
local crossingRamps = WalkHelpers.crossingRamps
local skinUnder = WalkHelpers.skinUnder

describe("the real world, the walk pieces sit on his skin", function()
	local Workspace = game:GetService("Workspace")

	local MAX_RAMPS = 3
	local RAMP_NAMES: { [string]: boolean } = {
		CrossingRamp_Ankle = true,
		CrossingRamp_Knee = true,
		CrossingRamp_Steep = true,
	}
	local MAX_RAMP_DEGREES = 45
	-- The stretch crossing ramps may stand in: his left leg between the left boot top and Rare egg 1 (the stretch that
	-- plan 3, Task 6 removes). Rare egg 1's top is at (-12.5, 41.3, -40.3); the boot top's step is at z -60.4.
	local STRETCH_MIN = Vector3.new(-32, 24, -61)
	local STRETCH_MAX = Vector3.new(-8, 43, -38.5)
	local WALL_DEGREES = 70 -- a wall step is steeper than this...
	local WALL_RISE = 0.5 -- ...and rises more than this
	local STEEP_BODY_DEGREES = 65 -- or the body-size slope is this steep or more (the seam angle)
	local PROFILE_STEP = 0.1 -- studs between the places a span's profile is read

	local EDGE_ROW = 0.51 -- studs: the rows of a ramp top that count as its step-on and step-off edges

	-- Whether his skin has a wall or a steep band under a ramp's span: from `start` to `finish` (x and z only), along the
	-- middle and the two sides `halfWidth` out, a run of steps steeper than WALL_DEGREES that rises more than WALL_RISE
	-- studs, or a body-size slope of STEEP_BODY_DEGREES or more somewhere along the middle. A ramp where a fitted piece
	-- would do is not allowed (Rule 20: the exception is only for walls).
	local function spanHasWall(params: RaycastParams, start: Vector3, finish: Vector3, halfWidth: number): boolean
		local flat = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
		local length = flat.Magnitude
		local along = flat.Unit
		local across = Vector3.new(-along.Z, 0, along.X)
		local steps = math.max(1, math.floor(length / PROFILE_STEP))
		for _, side in { -1, 0, 1 } do
			local previous: number? = nil
			local run = 0
			for step = 0, steps do
				local at = Vector3.new(start.X, 0, start.Z)
					+ along * (length * step / steps)
					+ across * (side * halfWidth)
				local hit = Workspace:Raycast(Vector3.new(at.X, 200, at.Z), Vector3.new(0, -250, 0), params)
				local height = if hit then hit.Position.Y else nil
				if height ~= nil and previous ~= nil then
					local degrees = math.deg(math.atan2(math.abs(height - previous), length / steps))
					if degrees > WALL_DEGREES then
						run += math.abs(height - previous)
						if run > WALL_RISE then
							return true
						end
					else
						run = 0
					end
				end
				previous = height
			end
		end
		local count = math.max(1, math.floor(length))
		for step = 0, count do
			local at = Vector3.new(start.X, 0, start.Z) + along * (length * step / count)
			local slope = bodySlopeAt(params, at.X, at.Z)
			if slope ~= nil and slope >= STEEP_BODY_DEGREES then
				return true
			end
		end
		return false
	end

	-- A ramp's top: the points of a lattice 1 stud apart that lie on it, and the surface direction there. It is found by
	-- rays that see only the ramp, so it works for any shape of ramp that has a top.
	type RampTop = { points: { Vector3 }, middleNormal: Vector3, direction: Vector3, bottom: { number } }
	local function rampTop(ramp: BasePart): RampTop
		local params = RaycastParams.new()
		params.IncludeInstances = { ramp }
		params.RespectCanCollide = false
		local half = ramp.Size / 2
		local lowX, highX, lowZ, highZ, highY, lowY =
			math.huge, -math.huge, math.huge, -math.huge, -math.huge, math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = ramp.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					lowX, highX = math.min(lowX, corner.X), math.max(highX, corner.X)
					lowZ, highZ = math.min(lowZ, corner.Z), math.max(highZ, corner.Z)
					highY, lowY = math.max(highY, corner.Y), math.min(lowY, corner.Y)
				end
			end
		end
		local points: { Vector3 } = {}
		local bottom: { number } = {}
		local x = lowX + GRID_INSET
		while x <= highX - GRID_INSET + 1e-6 do
			local z = lowZ + GRID_INSET
			while z <= highZ - GRID_INSET + 1e-6 do
				local down =
					Workspace:Raycast(Vector3.new(x, highY + 1, z), Vector3.new(0, -(highY - lowY + 2), 0), params)
				if down ~= nil then
					table.insert(points, down.Position)
					-- the lowest the ramp reaches under this point: a ray up from far below, seeing only the ramp
					local up =
						Workspace:Raycast(Vector3.new(x, lowY - 1, z), Vector3.new(0, highY - lowY + 2, 0), params)
					table.insert(bottom, if up ~= nil then up.Position.Y else down.Position.Y)
				end
				z += GRID_STEP
			end
			x += GRID_STEP
		end
		local middle = Workspace:Raycast(
			Vector3.new(ramp.Position.X, highY + 1, ramp.Position.Z),
			Vector3.new(0, -(highY - lowY + 2), 0),
			params
		)
		local normal = if middle ~= nil then middle.Normal else Vector3.yAxis
		local direction = Vector3.new(normal.X, 0, normal.Z)
		return {
			points = points,
			middleNormal = normal,
			direction = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis,
			bottom = bottom,
		}
	end

	-- What is wrong with one crossing ramp, as short sentences (an empty list is a good ramp).
	local function rampProblems(params: RaycastParams, ramp: BasePart): { string }
		local problems: { string } = {}
		local top = rampTop(ramp)
		if #top.points == 0 then
			return { "no top was found" }
		end
		-- inside the stretch
		local at = ramp.Position
		if
			at.X < STRETCH_MIN.X
			or at.X > STRETCH_MAX.X
			or at.Y < STRETCH_MIN.Y
			or at.Y > STRETCH_MAX.Y
			or at.Z < STRETCH_MIN.Z
			or at.Z > STRETCH_MAX.Z
		then
			table.insert(
				problems,
				`stands at {describePoint(at)}, outside the stretch between the left boot top and Rare egg 1`
			)
		end
		-- no steeper than 45 degrees
		local degrees = math.deg(math.acos(math.clamp(top.middleNormal.Y, -1, 1)))
		if degrees > MAX_RAMP_DEGREES + 0.01 then
			table.insert(problems, string.format("its top is %.1f degrees (the most is %d)", degrees, MAX_RAMP_DEGREES))
		end
		-- the step-on and step-off edges are the first and last rows along the slope's direction
		local lowest, highest = math.huge, -math.huge
		for _, point in top.points do
			local along = point:Dot(top.direction)
			lowest, highest = math.min(lowest, along), math.max(highest, along)
		end
		for index, point in top.points do
			local along = point:Dot(top.direction)
			if along - lowest <= EDGE_ROW or highest - along <= EDGE_ROW then
				local hit = skinUnder(params, point)
				if hit == nil then
					table.insert(problems, `edge point {describePoint(point)} has no skin under it`)
				else
					local gap = point.Y - hit.Position.Y
					if gap > WINDOW_ABOVE + WINDOW_SLACK or gap < -WINDOW_BELOW - WINDOW_SLACK then
						table.insert(
							problems,
							string.format("edge point %s is %.2f studs from his skin", describePoint(point), gap)
						)
					end
				end
			end
			-- solid all the way down: its lowest point under this place is at or under his skin
			local skin = skinUnder(params, point)
			if skin ~= nil and top.bottom[index] > skin.Position.Y + WINDOW_SLACK then
				table.insert(
					problems,
					string.format(
						"under %s the ramp ends %.2f studs over his skin (a gap)",
						describePoint(point),
						top.bottom[index] - skin.Position.Y
					)
				)
			end
		end
		-- a wall or a steep band really is under its span
		local startPoint = ramp.Position - top.direction * ((highest - lowest) / 2)
		local finishPoint = ramp.Position + top.direction * ((highest - lowest) / 2)
		local crossWidth = math.min(ramp.Size.X, ramp.Size.Z) / 2
		if not spanHasWall(params, startPoint, finishPoint, math.max(crossWidth - 1, 0)) then
			table.insert(
				problems,
				"no wall and no steep band of his skin is under its span, so a fitted piece would do"
			)
		end
		return problems
	end

	it("there are at most 3 crossing ramps, named for the left leg's walls", function()
		local ramps = crossingRamps()
		local names: { string } = {}
		local unknown: { string } = {}
		for _, ramp in ramps do
			table.insert(names, ramp.Name)
			if not RAMP_NAMES[ramp.Name] then
				table.insert(unknown, ramp.Name)
			end
		end
		table.sort(names)
		expect(unknown).toEqual({})
		expect(#ramps <= MAX_RAMPS).toBe(true)
		-- his left leg has two walls (the boot's top edge and the knee), so both ramps must be there
		expect(table.find(names, "CrossingRamp_Ankle") ~= nil).toBe(true)
		expect(table.find(names, "CrossingRamp_Knee") ~= nil).toBe(true)
	end)

	it("a crossing ramp is invisible and solid, like the walk pieces", function()
		local wrong: { string } = {}
		local ramps = crossingRamps()
		expect(#ramps >= 2).toBe(true)
		for _, ramp in ramps do
			if
				ramp.Transparency ~= 1
				or not ramp.Anchored
				or not ramp.CanCollide
				or not ramp.CanQuery
				or not ramp.CanTouch
				or ramp.CollisionGroup ~= "Default"
			then
				table.insert(wrong, ramp.Name)
			end
		end
		expect(wrong).toEqual({})
	end)

	it("each crossing ramp is a short solid ramp at a wall", function()
		local params = bodyParams()
		local ramps = crossingRamps()
		expect(#ramps >= 2).toBe(true)
		local problems: { [string]: { string } } = {}
		for _, ramp in ramps do
			local found = rampProblems(params, ramp)
			if #found > 0 then
				problems[ramp.Name] = { table.unpack(found, 1, math.min(#found, 6)) }
			end
		end
		expect(problems).toEqual({})
	end)

	-- Proof that the wall part of the test above can fail: over the flat top of his left boot (the part above the step,
	-- no wall and no steep band) it says no, and over the boot's top edge it says yes.
	it("finds no wall under a span over the flat boot top, and finds the boot's top edge", function()
		local params = bodyParams()
		expect(spanHasWall(params, Vector3.new(-24, 0, -66), Vector3.new(-24, 0, -62), 1.5)).toBe(false)
		expect(spanHasWall(params, Vector3.new(-24, 0, -58), Vector3.new(-24, 0, -53), 1.5)).toBe(true)
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Edge guards (Ruling 7): the sides of a crossing ramp are guarded where they cross steep skin
	----------------------------------------------------------------------------------------------------------------
end)
