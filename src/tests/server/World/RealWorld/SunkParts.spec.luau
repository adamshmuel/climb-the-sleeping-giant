--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

-- Plan "gardens-and-ways-up", Task 6d (product's sink ruling, item 2): no visible part sinks into a main character.
-- A wooden ladder or plank swallowed by the giant looks broken. The test only READS the world.
--
-- Method (code_lead's ruling, work/t6d/method-ruling.md, 2026-11-04). Every visible character part has its own
-- RaycastParams. A face point is tested only against the character parts whose world box holds it. Against one such part:
-- 26 outward rays (20 studs) hit nothing, and at least 20 of 26 inward rays hit it = the point is INSIDE that part, and
-- its depth is the shortest inward hit (the distance to his skin). The point's depth is the largest over those parts.
-- (Rays are filtered to one part because a point sunk in one part is often near another, and that other part would hide
-- it.) There is no "covered" check: a part under a fold with no air gap is inside the fold's part, so this catches it.
-- A point fails when its depth is over the limit: 0.3 studs on a part's two end faces (across its longest axis, where a
-- plank rests on him), 0.1 on every other face (Rule 103). The face whose world normal points down (Y under -0.7) is
-- skipped: that face rests on him.
--
-- Accepted by name (the part is nailed in or sunk on purpose):
--   BootLadder_*.Look.Peg: designer's ruling, 2026-11-04: pegs are nailed in. Rails, rungs and hooks keep the limit.
--   World.GiantsThings.Pillow: stuck safety Task 41: the pillow is sunk under his head by design.
--   World.Nature.Inno_Yellow_Flowers: designer's ruling, 2026-11-04: 0.22 studs is fine.
-- Not accepted (they stay red until Task 5b): Inno_White_Flowers and Nature_GrassTuft.
describe("the real world, no part sinks into a main character", function()
	local MAIN_CHARACTER_TAG = "MainCharacter"
	local NEAR = 6 -- studs: a candidate's box, grown this much, meets a character part's box
	local RAY_LENGTH = 20 -- studs, every ray
	local INSIDE_MIN_HITS = 20 -- of the 26 inward rays
	local FACE_INSET = 0.95 -- studs: the 3 x 3 points on a face stay this far from its edges
	local END_LIMIT = 0.3 -- studs, on a part's two end faces
	local OTHER_LIMIT = 0.1 -- studs, on every other face
	local DOWN_FACE_Y = -0.7 -- a face whose world normal Y is under this rests on him and is skipped
	local INVISIBLE = 0.99 -- transparency from here up is not visible
	local MAX_LINES = 60

	local ACCEPTED_PATHS: { string } = {
		"%.BootLadder_[^.]+%.Look%.Peg%.$", -- designer: pegs are nailed in
		"^Workspace%.World%.GiantsThings%.Pillow%.", -- stuck safety Task 41
		"^Workspace%.World%.Nature%.Inno_Yellow_Flowers%.", -- designer: 0.22 studs is fine
	}

	local DIRECTIONS: { Vector3 } = {}
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					table.insert(DIRECTIONS, Vector3.new(x, y, z).Unit)
				end
			end
		end
	end

	local function isAccepted(part: BasePart): boolean
		local path = part:GetFullName()
		for _, pattern in ACCEPTED_PATHS do
			if string.find(path .. ".", pattern) ~= nil then
				return true
			end
		end
		return false
	end

	local function isVisible(part: BasePart): boolean
		return part.Transparency < INVISIBLE
	end

	local function boxOf(part: BasePart): (Vector3, Vector3)
		local extent = Vector3.new(
			math.abs(part.CFrame.RightVector.X) * part.Size.X / 2
				+ math.abs(part.CFrame.UpVector.X) * part.Size.Y / 2
				+ math.abs(part.CFrame.LookVector.X) * part.Size.Z / 2,
			math.abs(part.CFrame.RightVector.Y) * part.Size.X / 2
				+ math.abs(part.CFrame.UpVector.Y) * part.Size.Y / 2
				+ math.abs(part.CFrame.LookVector.Y) * part.Size.Z / 2,
			math.abs(part.CFrame.RightVector.Z) * part.Size.X / 2
				+ math.abs(part.CFrame.UpVector.Z) * part.Size.Y / 2
				+ math.abs(part.CFrame.LookVector.Z) * part.Size.Z / 2
		)
		return part.Position - extent, part.Position + extent
	end

	local function boxesMeet(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3, grow: number): boolean
		return minA.X - grow <= maxB.X
			and maxA.X + grow >= minB.X
			and minA.Y - grow <= maxB.Y
			and maxA.Y + grow >= minB.Y
			and minA.Z - grow <= maxB.Z
			and maxA.Z + grow >= minB.Z
	end

	type CharacterPart = { part: BasePart, params: RaycastParams, min: Vector3, max: Vector3 }

	local function holds(box: CharacterPart, point: Vector3): boolean
		return point.X >= box.min.X
			and point.X <= box.max.X
			and point.Y >= box.min.Y
			and point.Y <= box.max.Y
			and point.Z >= box.min.Z
			and point.Z <= box.max.Z
	end

	-- How deep the point sits inside this one character part, or nil when it is not inside it.
	local function depthInside(params: RaycastParams, point: Vector3): number?
		for _, direction in DIRECTIONS do
			if Workspace:Raycast(point, direction * RAY_LENGTH, params) ~= nil then
				return nil
			end
		end
		local hits = 0
		local shallowest = math.huge
		for _, direction in DIRECTIONS do
			local result = Workspace:Raycast(point + direction * RAY_LENGTH, -direction * RAY_LENGTH, params)
			if result ~= nil then
				hits += 1
				shallowest = math.min(shallowest, RAY_LENGTH - result.Distance)
			end
		end
		if hits >= INSIDE_MIN_HITS then
			return shallowest
		end
		return nil
	end

	-- The largest depth over the character parts whose box holds the point (0 when it is inside none).
	local function measure(characters: { CharacterPart }, point: Vector3): number
		local deepest = 0
		for _, box in characters do
			if holds(box, point) then
				local depth = depthInside(box.params, point)
				if depth ~= nil and depth > deepest then
					deepest = depth
				end
			end
		end
		return deepest
	end

	-- "(x, y, z)" to 0.1 studs: several parts share a path (the rungs), so the position tells them apart.
	local function roundedPosition(position: Vector3): string
		return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
	end

	type Failure = { path: string, position: Vector3, worst: number, failing: number, total: number }

	local function checkPart(characters: { CharacterPart }, part: BasePart): Failure?
		local size = part.Size
		local longest = 1
		if size.Y > size.X and size.Y >= size.Z then
			longest = 2
		elseif size.Z > size.X and size.Z > size.Y then
			longest = 3
		end
		local axes = { part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector }
		local sizes = { size.X, size.Y, size.Z }
		local failure: Failure =
			{ path = part:GetFullName(), position = part.Position, worst = 0, failing = 0, total = 0 }
		for axis = 1, 3 do
			for _, sign in { -1, 1 } do
				local normal = axes[axis] * sign
				if normal.Y >= DOWN_FACE_Y then
					local limit = if axis == longest then END_LIMIT else OTHER_LIMIT
					local others = {}
					for other = 1, 3 do
						if other ~= axis then
							table.insert(others, other)
						end
					end
					local reachA = math.max(0, sizes[others[1]] / 2 - FACE_INSET)
					local reachB = math.max(0, sizes[others[2]] / 2 - FACE_INSET)
					local middle = part.Position + normal * (sizes[axis] / 2)
					for a = -1, 1 do
						for b = -1, 1 do
							local point = middle + axes[others[1]] * (a * reachA) + axes[others[2]] * (b * reachB)
							local depth = measure(characters, point)
							failure.total += 1
							if depth > limit then
								failure.failing += 1
								failure.worst = math.max(failure.worst, depth)
							end
						end
					end
				end
			end
		end
		if failure.failing > 0 then
			return failure
		end
		return nil
	end

	it("no visible part sinks into a main character", function()
		local tagged: { Model } = {}
		for _, instance in CollectionService:GetTagged(MAIN_CHARACTER_TAG) do
			if instance:IsA("Model") then
				table.insert(tagged, instance)
			end
		end
		expect(#tagged).toBeGreaterThan(0)

		local characters: { CharacterPart } = {}
		for _, model in tagged do
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") and isVisible(descendant) then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { descendant }
					local low, high = boxOf(descendant)
					table.insert(characters, { part = descendant, params = params, min = low, max = high })
				end
			end
		end

		local failures: { Failure } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant:IsA("Terrain") and isVisible(descendant) then
				local insideCharacter = false
				for _, model in tagged do
					if descendant:IsDescendantOf(model) then
						insideCharacter = true
					end
				end
				if not insideCharacter and not isAccepted(descendant) then
					local low, high = boxOf(descendant)
					for _, box in characters do
						if boxesMeet(low, high, box.min, box.max, NEAR) then
							local failure = checkPart(characters, descendant)
							if failure ~= nil then
								table.insert(failures, failure)
							end
							break
						end
					end
				end
			end
		end

		table.sort(failures, function(left: Failure, right: Failure): boolean
			if left.path ~= right.path then
				return left.path < right.path
			end
			return roundedPosition(left.position) < roundedPosition(right.position)
		end)
		local lines: { string } = {}
		for index, failure in failures do
			if index > MAX_LINES then
				table.insert(lines, `... and {#failures - MAX_LINES} more`)
				break
			end
			table.insert(
				lines,
				string.format(
					"%s @ %s: worst %.2f, %d of %d points",
					failure.path,
					roundedPosition(failure.position),
					failure.worst,
					failure.failing,
					failure.total
				)
			)
		end
		expect(table.concat(lines, "\n")).toBe("")
	end)
end)
