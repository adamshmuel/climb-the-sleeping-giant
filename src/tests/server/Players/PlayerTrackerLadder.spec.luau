--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local TrackerRig = require(script.Parent.TrackerRig)

-- A Boots ladder box 6 wide and 36 tall, whose foot is at y = 2 (centre (0, 20, 0)). No zone boxes: outside the
-- ladder box every place is the Meadow.
local ladderBoxes: { Zones.LadderBox } = {
	{ ladder = "TestLadder", zone = "Boots", cframe = CFrame.new(0, 20, 0), size = Vector3.new(6, 36, 6) },
}
local boxes: TrackerRig.Boxes = { ladderBoxes = ladderBoxes }
local HALFWAY = Vector3.new(0, 20, 0)

describe("PlayerTracker ladder", function()
	it("a sample in a ladder box off the ground says onLadder", function()
		local character = TrackerRig.makeCharacter(HALFWAY)
		local rig = TrackerRig.groundSpeedRig(character, boxes)
		rig.setGrounded(false)
		local climbing = TrackerRig.readAt(rig, character, 0, HALFWAY.X, HALFWAY.Y)
		expect(climbing.onLadder).toBe(true)
		expect(climbing.ladder).toBe("TestLadder")
		expect(climbing.zone).toBe("Boots")
		rig.setGrounded(true)
		local standing = TrackerRig.readAt(rig, character, 0.1, HALFWAY.X, HALFWAY.Y)
		expect(standing.onLadder).toBe(false)
		expect(standing.ladder).toBeNil()
		expect(standing.zone).toBe("Meadow")
		character:Destroy()
	end)

	it("a jump off a Boots ladder halfway thuds as Boots", function()
		local character = TrackerRig.makeCharacter(Vector3.new(0, 2, 0))
		local rig = TrackerRig.groundSpeedRig(character, boxes)
		rig.setGrounded(true)
		TrackerRig.readAt(rig, character, 0, 0, 2) -- on the grass at the foot
		rig.setGrounded(false)
		for i = 1, 5 do
			TrackerRig.readAt(rig, character, i * 0.1, 0, 2 + i * 3) -- climbing
		end
		rig.setTakeoffs({ HALFWAY })
		TrackerRig.readAt(rig, character, 0.6, HALFWAY.X, HALFWAY.Y)
		local thud: string? = nil
		for i = 7, 9 do
			rig.setGrounded(false)
			TrackerRig.readAt(rig, character, i * 0.1, 0, 10)
		end
		rig.setGrounded(true)
		for i = 10, 14 do
			local sample = TrackerRig.readAt(rig, character, i * 0.1, 0, 2)
			thud = thud or sample.thudFrom
		end
		expect(thud).toBe("Boots")
		character:Destroy()
	end)

	it("a climber resting on the rungs (grounded, not standing) is on the ladder in the box's zone", function()
		local character = TrackerRig.makeCharacter(HALFWAY)
		local rig = TrackerRig.groundSpeedRig(character, boxes)
		rig.setGrounded(true) -- the ground ray hits the leaning rungs
		rig.setStanding(false) -- but those are a ladder's rungs, not ground
		local resting = TrackerRig.readAt(rig, character, 0, HALFWAY.X, HALFWAY.Y)
		expect(resting.onLadder).toBe(true)
		expect(resting.ladder).toBe("TestLadder")
		expect(resting.zone).toBe("Boots")
		character:Destroy()
	end)

	it("letting go of a ladder after resting on its rungs makes no thud", function()
		local character = TrackerRig.makeCharacter(Vector3.new(0, 2, 0))
		local root = TrackerRig.rootOf(character)
		local rig = TrackerRig.groundSpeedRig(character, boxes)
		rig.setGrounded(true)
		rig.setStanding(true)
		TrackerRig.readAt(rig, character, 0, 0, 2) -- on the grass at the foot
		rig.setStanding(false)
		for i = 1, 5 do
			TrackerRig.readAt(rig, character, i * 0.1, 0, 2 + i * 3) -- resting on the rungs, going up
		end
		rig.setGrounded(false)
		root.AssemblyLinearVelocity = Vector3.new(0, -15, 0) -- falling fast (over LandingDetector's FAST_FALL of 10)
		for i = 6, 9 do
			TrackerRig.readAt(rig, character, i * 0.1, 0, 17 - (i - 5) * 3) -- let go, falling
		end
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rig.setGrounded(true)
		rig.setStanding(true)
		local thud: string? = nil
		for i = 10, 14 do
			local sample = TrackerRig.readAt(rig, character, i * 0.1, 0, 2) -- back on the grass
			thud = thud or sample.thudFrom
		end
		-- A let-go drop must make no thud (spec 3 Check C5). A Meadow landing is silent (Noise.jumpBurst gives 0
		-- for Meadow), so the only wrong answer is the ladder's own zone, Boots.
		expect(thud).never.toBe("Boots")
		character:Destroy()
	end)
end)

describe("PlayerTracker.standingByRay", function()
	it("does not count a TrussPart as ground", function()
		-- Like BootLadder_Left.Climb: a 2 x 2 x 10 truss leaning 60 degrees, so its climbing face has normal Y = 0.5.
		-- That is flatter than StarterPlayer.CharacterMaxSlopeAngle allows, so groundedByRay calls it ground.
		local centre = Vector3.new(5000, 100, 5000)
		local truss = Instance.new("TrussPart")
		truss.Anchored = true
		truss.Size = Vector3.new(2, 10, 2)
		truss.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(30))
		truss.Parent = workspace
		local faceNormal = truss.CFrame.RightVector -- the +X face, which faces up and out
		local character = TrackerRig.makeCharacter(centre + faceNormal * (1 + 1.2)) -- 1.2 studs off the face
		-- A real body's ground ray is 3.5 studs (HipHeight 2 + half a 2-stud root + GROUND_REACH 0.5); the bare test body's is 1.
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.HipHeight = 2
		TrackerRig.rootOf(character).Size = Vector3.new(2, 2, 1)
		local groundByRay = PlayerTracker.groundedByRay(character)
		local standing = PlayerTracker.standingByRay(character)
		truss:Destroy()
		character:Destroy()
		expect(groundByRay).toBe(true)
		expect(standing).toBe(false)
	end)
end)
