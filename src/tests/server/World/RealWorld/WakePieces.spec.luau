--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Helpers = require(script.Parent.Helpers)
local realWorld = Helpers.realWorld

-- Plan 6 Task 10: the wake pieces moved from Workspace.Mockup_WakeUp into the real world (docs/plans/v2/wake-up.md).
local MOUTH_AT = Vector3.new(0, 80.3, -15.6) -- work/p6t10/10-design.md, hand-checked at the asleep pose
local TONGUE_AT = Vector3.new(0, 77.0, -16.7)
local POSITION_MARGIN = 0.1 -- studs
local FLOWER_NAMES: { [string]: boolean } = {
	Nature_Sunflower = true,
	Nature_FlowerPatch = true,
	Inno_Pink_Flowers = true,
	Inno_Yellow_Flowers = true,
	Inno_Blue_Flowers = true,
	Inno_White_Flowers = true,
}
local MIN_FLOWERS = 100
local BIRD_COUNT = 24

local function find(parent: Instance, names: { string }): Instance
	local current = parent
	for _, name in names do
		local found = current:FindFirstChild(name)
		expect(found).never.toBeNil()
		current = found :: Instance
	end
	return current
end

local function hasMockupAttribute(instance: Instance): boolean
	for name in instance:GetAttributes() do
		if string.sub(name, 1, 6) == "Mockup" then
			return true
		end
	end
	return false
end

-- The moved pieces: the mouth, the bang anchor, the dust folder and the bird folder.
local function movedPieces(): { Instance }
	local world = realWorld()
	return {
		find(world, { "Giant", "AwakeMouth" }),
		find(world, { "GiantFX", "BangAnchor" }),
		find(world, { "GiantFX", "WakeDust" }),
		find(ReplicatedStorage, { "Assets", "WakeBirds" }),
	}
end

describe("the real world, the wake pieces", function()
	it("has the mouth and tongue at the asleep pose", function()
		local mouth = find(realWorld(), { "Giant", "AwakeMouth", "Mouth" }) :: BasePart
		local tongue = find(realWorld(), { "Giant", "AwakeMouth", "Tongue" }) :: BasePart
		expect((mouth.Position - MOUTH_AT).Magnitude < POSITION_MARGIN).toBe(true)
		expect((tongue.Position - TONGUE_AT).Magnitude < POSITION_MARGIN).toBe(true)
	end)

	it("has no mouth part that collides, is queried or is touched", function()
		local mouth = find(realWorld(), { "Giant", "AwakeMouth" })
		local count = 0
		for _, part in mouth:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				expect(part.CanCollide).toBe(false)
				expect(part.CanQuery).toBe(false)
				expect(part.CanTouch).toBe(false)
			end
		end
		expect(count).toBeGreaterThan(0)
	end)

	it("marks the flower models under World and nothing else with ShakesOnSlam", function()
		local world = realWorld()
		local marked = 0
		for _, instance in game:GetDescendants() do
			if instance:GetAttribute("ShakesOnSlam") ~= nil then
				marked += 1
				expect(instance:IsA("Model")).toBe(true)
				expect(instance:IsDescendantOf(world)).toBe(true)
				expect(FLOWER_NAMES[instance.Name]).toBe(true)
			end
		end
		expect(marked).toBeGreaterThanOrEqual(MIN_FLOWERS)
	end)

	it("has no Mockup_WakeUp left in the Workspace", function()
		expect(Workspace:FindFirstChild("Mockup_WakeUp")).toBeNil()
	end)

	it("has 24 visible birds and no Mockup attribute on a moved piece", function()
		local birds = find(ReplicatedStorage, { "Assets", "WakeBirds" })
		expect(#birds:GetChildren()).toBe(BIRD_COUNT)
		for _, part in birds:GetDescendants() do
			if part:IsA("BasePart") then
				expect(part.Transparency).toBe(0)
			end
		end
		for _, piece in movedPieces() do
			expect(hasMockupAttribute(piece)).toBe(false)
			for _, descendant in piece:GetDescendants() do
				expect(hasMockupAttribute(descendant)).toBe(false)
			end
		end
	end)

	it("marks exactly one part RightArmRest, the right arm's mesh", function()
		local marked: { Instance } = {}
		for _, instance in game:GetDescendants() do
			if instance:GetAttribute("RightArmRest") == true then
				table.insert(marked, instance)
			end
		end
		expect(#marked).toBe(1)
		expect(marked[1]).toBe(find(realWorld(), { "Giant", "right_arm", "right_arm" }))
	end)
end)
