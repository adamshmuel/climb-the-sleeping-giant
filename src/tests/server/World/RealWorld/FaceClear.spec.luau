--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local realWorld = Helpers.realWorld

-- Remove face ladders task (Task 60), spec Rule 20 (One collision source), Rule 24 (A bot walks every way), Rule 101
-- (Ladders hold you). The ladders on the giant's face hid his sleeping face, the first view a new player sees.
-- The face box: the joined bounding boxes of the old BeardLadder and CapLadder, measured before they were moved
-- (2026-11-02): x -5.5 to 5.5, y 56.0 to 128.68, z -29.0 to 18.25, plus 1 stud on every side.
local FACE_BOX_MIN = Vector3.new(-6.5, 55.0, -30.0)
local FACE_BOX_MAX = Vector3.new(6.5, 129.68, 19.25)

-- Parts of these folders are not "in front of his face": his own body, his effects, and the zone boxes (invisible).
local LEFT_OUT = { "Giant", "GiantFX", "Zones" }

local function inFaceBox(point: Vector3): boolean
	return point.X >= FACE_BOX_MIN.X
		and point.X <= FACE_BOX_MAX.X
		and point.Y >= FACE_BOX_MIN.Y
		and point.Y <= FACE_BOX_MAX.Y
		and point.Z >= FACE_BOX_MIN.Z
		and point.Z <= FACE_BOX_MAX.Z
end

describe("the real world, his face", function()
	it("nothing climbable or visible stands in front of his face", function()
		local world = realWorld()
		local problems: { string } = {}

		local walkSurfaces = world:FindFirstChild("WalkSurfaces")
		expect(walkSurfaces).never.toBeNil()
		for _, name in { "BeardLadder", "CapLadder" } do
			if (walkSurfaces :: Instance):FindFirstChild(name) ~= nil then
				table.insert(problems, `WalkSurfaces.{name} is still on his face`)
			end
		end

		local leftOut: { Instance } = {}
		for _, name in LEFT_OUT do
			local folder = world:FindFirstChild(name)
			if folder ~= nil then
				table.insert(leftOut, folder)
			end
		end
		for _, part in world:GetDescendants() do
			if not part:IsA("BasePart") then
				continue
			end
			local skip = false
			for _, folder in leftOut do
				if part:IsDescendantOf(folder) then
					skip = true
					break
				end
			end
			if skip or not inFaceBox(part.Position) then
				continue
			end
			if part:IsA("TrussPart") or part.Transparency < 1 then
				table.insert(problems, `{part:GetFullName()} stands in front of his face`)
			end
		end

		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n", 1, math.min(#problems, 10)), 0)
		end
	end)
end)
