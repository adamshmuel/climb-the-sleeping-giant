--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local SinkDepth = require(ServerStorage.Tools.checks.SinkDepth)

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
--   World.Nature.Nature_FloweringBush: R-141 bush, designer and product, 2026-11-04 (stuck safety Task 48).
-- BootLadder_* rows: Task 5b2 moved both whole ladders 1.6 out (5b2 moved).
describe("the real world, no part sinks into a main character", function()
	local MAIN_CHARACTER_TAG = "MainCharacter"
	local NEAR = 6 -- studs: a candidate's box, grown this much, meets a character part's box
	local MAX_LINES = 60

	local ACCEPTED_PATHS: { string } = {
		"%.BootLadder_[^.]+%.Look%.Peg%.$", -- designer: pegs are nailed in
		"^Workspace%.World%.GiantsThings%.Pillow%.", -- stuck safety Task 41
		"^Workspace%.World%.Nature%.Inno_Yellow_Flowers%.", -- designer: 0.22 studs is fine
		"^Workspace%.World%.Nature%.Nature_FloweringBush%.", -- R-141 bush, stuck safety Task 48: designer and product, 2026-11-04: it reads as a plant, and moving it reopens a stuck pocket
	}

	type AcceptedFace = { axis: number, sign: number, limit: number }

	-- By full path: one face of one part, up to its own limit. Every other face of the part keeps the normal limit.
	local ACCEPTED_FACES: { [string]: AcceptedFace } = {
		-- product, 2026-11-04, Task 5b1: body-side face only, up to 0.3 (spec Rule 103, line 257); measured 0.21 on 3 of 9 points, behind the rope rail
		["Workspace.World.WalkSurfaces.LapPlank_Left.Deck"] = { axis = 1, sign = -1, limit = 0.3 },
	}

	-- By full path: every face of one part, up to its own limit.
	local ACCEPTED_PARTS: { [string]: number } = {
		-- ruling F2: 0.3 studs on any face; measured X+ 0.28 (9 of 9 points), Z- 0.115 (3 of 9)
		["Workspace.World.WalkSurfaces.PlankEnd_Right.Board_1"] = 0.3,
	}

	type PatternLimit = { pattern: string, limit: number }

	-- By path pattern: every face of each matching part, up to its own limit (for parts whose names repeat).
	-- Task 15e3, designer's sink ruling (work/p5t15e3/sink-ruling.md, 2026-11-09): the cuff strap is sewn into his cuff
	-- by design. Its inner edge runs under the white cuff in one seam. Measured worst: Strap 0.79, RolledEdge 1.03, Stitch 0.29.
	local ACCEPTED_PATTERN_LIMITS: { PatternLimit } = {
		{ pattern = "^Workspace%.World%.CuffArt%.CuffStrap_[LR]%a+%.Strap$", limit = 0.85 },
		{ pattern = "^Workspace%.World%.CuffArt%.CuffStrap_[LR]%a+%.RolledEdge$", limit = 1.1 },
		{ pattern = "^Workspace%.World%.CuffArt%.CuffStrap_[LR]%a+%.Stitch$", limit = 0.3 },
	}

	local function partLimitOf(path: string): number?
		local limit = ACCEPTED_PARTS[path]
		if limit ~= nil then
			return limit
		end
		for _, entry in ACCEPTED_PATTERN_LIMITS do
			if string.find(path, entry.pattern) ~= nil then
				return entry.limit
			end
		end
		return nil
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

	local function boxesMeet(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3, grow: number): boolean
		return minA.X - grow <= maxB.X
			and maxA.X + grow >= minB.X
			and minA.Y - grow <= maxB.Y
			and maxA.Y + grow >= minB.Y
			and minA.Z - grow <= maxB.Z
			and maxA.Z + grow >= minB.Z
	end

	-- "(x, y, z)" to 0.1 studs: several parts share a path (the rungs), so the position tells them apart.
	local function roundedPosition(position: Vector3): string
		return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
	end

	type Failure = { path: string, position: Vector3, worst: number, failing: number, total: number }

	local function checkPart(characters: { SinkDepth.CharacterPart }, part: BasePart): Failure?
		local failure: Failure =
			{ path = part:GetFullName(), position = part.Position, worst = 0, failing = 0, total = 0 }
		local acceptedFace = ACCEPTED_FACES[failure.path]
		local partLimit = partLimitOf(failure.path)
		for _, face in SinkDepth.faceDepths(part.CFrame, part.Size, characters) do
			if partLimit ~= nil and face.worst <= partLimit then
				continue
			end
			if
				acceptedFace ~= nil
				and face.axis == acceptedFace.axis
				and face.sign == acceptedFace.sign
				and face.worst <= acceptedFace.limit
			then
				continue
			end
			failure.total += face.total
			failure.failing += face.failing
			failure.worst = math.max(failure.worst, face.worst)
		end
		if failure.failing > 0 then
			return failure
		end
		return nil
	end

	it("every boot ladder rail, rung and hook stands off him at points every 0.85 studs (Rule 103)", function()
		local characters = SinkDepth.characterParts(MAIN_CHARACTER_TAG)
		local walkSurfaces = Workspace.World.WalkSurfaces
		local lines: { string } = {}
		for _, name in { "BootLadder_Left", "BootLadder_Right" } do
			local ladder = walkSurfaces:FindFirstChild(name)
			expect(ladder).never.toBeNil()
			local look = (ladder :: Instance):FindFirstChild("Look")
			expect(look).never.toBeNil()
			local checked = 0
			for _, part in (look :: Instance):GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "Peg" then
					checked += 1
					local row = { worst = 0, failing = 0, total = 0 }
					for _, face in SinkDepth.faceDepths(part.CFrame, part.Size, characters, 0.85) do
						row.failing += face.failing
						row.total += face.total
						row.worst = math.max(row.worst, face.worst)
					end
					if row.failing > 0 then
						table.insert(
							lines,
							string.format(
								"%s @ %s: worst %.2f, %d of %d points",
								part:GetFullName(),
								roundedPosition(part.Position),
								row.worst,
								row.failing,
								row.total
							)
						)
					end
				end
			end
			expect(checked).toBe(25) -- 21 Rung, 2 Rail, 2 Hook
		end
		expect(table.concat(lines, "\n")).toBe("")
	end)

	it("no visible part sinks into a main character", function()
		local tagged: { Model } = {}
		for _, instance in CollectionService:GetTagged(MAIN_CHARACTER_TAG) do
			if instance:IsA("Model") then
				table.insert(tagged, instance)
			end
		end
		expect(#tagged).toBeGreaterThan(0)

		local characters = SinkDepth.characterParts(MAIN_CHARACTER_TAG)

		local failures: { Failure } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant:IsA("Terrain") and SinkDepth.isVisible(descendant) then
				local insideCharacter = false
				for _, model in tagged do
					if descendant:IsDescendantOf(model) then
						insideCharacter = true
					end
				end
				if not insideCharacter and not isAccepted(descendant) then
					local low, high = SinkDepth.boxOf(descendant)
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
