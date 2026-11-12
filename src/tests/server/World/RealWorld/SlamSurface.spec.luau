--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local SlamSurface = require(ServerScriptService.Server.Giant.SlamSurface)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- The circle under a player standing where his raised right arm rests (spec 5 section 8): the real arm is the part
-- marked RightArmRest, found the way the server finds it (WorldIndex.loadWakePieces).
describe("the real world, a circle under the giant's raised right arm", function()
	local function realArm(): BasePart
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		-- The wake pieces (the birds) live in ReplicatedStorage.Assets; ServerStorage.Assets holds the eggs.
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
		expect(assets).never.toBeNil()
		return WorldIndex.loadWakePieces(world :: Instance, assets :: Instance).rightArm
	end

	-- Just above the top of the arm's box, over its middle (the same point for both tests).
	local function centreOver(arm: BasePart): Vector3
		return arm.Position + Vector3.new(0, arm.Size.Y / 2 + 1, 0)
	end

	it("lands on the arm's own surface asleep and is the 3-stud fallback awake", function()
		local arm = realArm()
		local centre = centreOver(arm)
		-- A plain ray down from the same start `below` uses (SlamSurface.START_ABOVE = 1, REACH = 50).
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		local hit = Workspace:Raycast(centre + Vector3.new(0, 1, 0), Vector3.new(0, -50, 0), params)
		expect(hit).never.toBeNil()
		expect((hit :: RaycastResult).Instance).toBe(arm)
		local armHit = (hit :: RaycastResult).Position.Y
		local asleep = SlamSurface.below(Workspace, centre, SlamSurface.rayIgnore({}, arm, false))
		-- Asleep: the arm's own height, well below the fallback. On a failure the message shows the numbers first.
		local near = math.abs(asleep.Y - armHit) <= 0.5 and armHit < centre.Y - 3 - 1
		expect(if near then "ok" else `asleep {asleep.Y} armHit {armHit} fallback {centre.Y - 3}`).toBe("ok")
		-- Awake: the arm is skipped and nothing walkable lies below within reach, so the answer is centre minus 3.
		local awake = SlamSurface.below(Workspace, centre, SlamSurface.rayIgnore({}, arm, true))
		expect(awake.Y).toBeCloseTo(centre.Y - 3, 2)
	end)
end)
