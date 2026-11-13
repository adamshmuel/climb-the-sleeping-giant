--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

local DUST_COUNT = 7
local BIRD_COUNT = 24

local function add(className: string, name: string, parent: Instance): Instance
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- Builds a complete fake world (World.Giant with AwakeMouth and the marked right arm, World.GiantFX with BangAnchor and
-- WakeDust) and a fake Assets folder (WakeBirds), as plan 6 Task 10 moves them in. `skip` names one piece to leave out:
-- AwakeMouth, Bang, ZPop, RightArmRest, or "DustSpot" / "Bird" to leave out one of the 7 spots / 24 birds.
local function makeWorld(skip: string?): (Folder, Folder)
	local world = Instance.new("Folder")
	world.Name = "World"
	local giant = add("Model", "Giant", world)
	if skip ~= "AwakeMouth" then
		local mouth = add("Model", "AwakeMouth", giant)
		add("Part", "Mouth", mouth)
		add("Part", "Tongue", mouth)
	end
	local arm = add("Model", "right_arm", giant)
	local armMesh = add("MeshPart", "right_arm", arm)
	if skip ~= "RightArmRest" then
		armMesh:SetAttribute("RightArmRest", true)
	end
	local fx = add("Folder", "GiantFX", world)
	local anchor = add("Part", "BangAnchor", fx)
	if skip ~= "Bang" then
		add("BillboardGui", "Bang", anchor)
	end
	if skip ~= "ZPop" then
		add("BillboardGui", "ZPop", anchor)
	end
	local dust = add("Folder", "WakeDust", fx)
	for _ = 1, if skip == "DustSpot" then DUST_COUNT - 1 else DUST_COUNT do
		local spot = add("Part", "DustSpot", dust)
		add("ParticleEmitter", "WakeDust", spot)
	end
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	local birds = add("Folder", "WakeBirds", assets)
	for _ = 1, if skip == "Bird" then BIRD_COUNT - 1 else BIRD_COUNT do
		add("Model", "Bird", birds)
	end
	return world, assets
end

local function problemsOf(skip: string?): { string }
	local world, assets = makeWorld(skip)
	local pieces, problems = WorldIndex.readWakePieces(world, assets)
	expect(pieces).toBeNil()
	return problems
end

describe("WorldIndex.readWakePieces", function()
	it("gives no problem for a complete world", function()
		local world, assets = makeWorld(nil)
		local pieces, problems = WorldIndex.readWakePieces(world, assets)
		expect(problems).toEqual({})
		expect(pieces).never.toBeNil()
		expect(#(pieces :: WorldIndex.WakePieces).dustSpots).toBe(DUST_COUNT)
		expect(#(pieces :: WorldIndex.WakePieces).birds).toBe(BIRD_COUNT)
	end)

	local cases = {
		{ skip = "AwakeMouth", named = "Giant.AwakeMouth" },
		{ skip = "Bang", named = "GiantFX.BangAnchor.Bang" },
		{ skip = "ZPop", named = "GiantFX.BangAnchor.ZPop" },
		{ skip = "DustSpot", named = "GiantFX.WakeDust" },
		{ skip = "Bird", named = "Assets.WakeBirds" },
		{ skip = "RightArmRest", named = "RightArmRest" },
	}
	for _, case in cases do
		it(`names the problem when {case.skip} is missing`, function()
			local problems = problemsOf(case.skip)
			expect(#problems).toBe(1)
			expect((string.find(problems[1], case.named, 1, true))).never.toBeNil()
		end)
	end
end)
