--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local WaysUpCheck = require(ServerScriptService.Server.World.WaysUpCheck)
local PillowWayUp = require(ServerStorage.Tests.server.World.StuckScan.PillowWayUp)

-- The jump part of the ways-up check on small made-up worlds (plan 5 Task 18a Step 2). Each test builds its world in a
-- WorldModel in ServerStorage (as WalkAreaCheck.spec.luau does) and destroys it afterwards. A pad's top is y = 0.
describe("WaysUpCheck jump part, walk area rule", function()
	local world: WorldModel
	local PAD_POINT = Vector3.new(0, 0, 0)

	local function addBox(name: string, center: Vector3, size: Vector3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.CFrame = CFrame.new(center)
		part.Parent = world
		return part
	end

	local function check(point: Vector3, spot: Vector3): { WaysUpCheck.Problem }
		local input: WaysUpCheck.JumpInput = {
			surfaces = { { name = "Pad", points = { point } } },
			walkArea = { spot },
			ignore = {},
			trusses = {},
			nests = {},
			stands = {},
		}
		return WaysUpCheck.jumpProblems(world, input)
	end

	local function checkParts(trusses: { BasePart }, nests: { Vector3 }, stands: { Vector3 }?): { WaysUpCheck.Problem }
		local input: WaysUpCheck.JumpInput = {
			surfaces = { { name = "Pad", points = { PAD_POINT } } },
			walkArea = {},
			ignore = {},
			trusses = trusses,
			nests = nests,
			stands = stands or {},
		}
		return WaysUpCheck.jumpProblems(world, input)
	end

	-- A truss 4 tall whose lowest corner is `lowest` studs above the pad, `x` studs along.
	local function addTruss(lowest: number, x: number): Part
		return addBox("Truss", Vector3.new(x, lowest + 2, 0), Vector3.new(2, 4, 2))
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Parent = ServerStorage
		addBox("Pad", Vector3.new(0, -0.5, 0), Vector3.new(2, 1, 2))
	end)

	afterEach(function()
		world:Destroy()
	end)

	it("fails a walk spot 10 above a pad and 4 across", function()
		local problems = check(PAD_POINT, Vector3.new(4, 10, 0))
		expect(#problems).toBe(1)
		expect(problems[1].kind).toBe("walk area")
		expect(problems[1].detail).toContain("Pad")
		expect(problems[1].detail).toContain(tostring(Vector3.new(4, 10, 0)))
	end)

	it("fails a walk spot 10 above a slope walked onto from the pad", function()
		-- The slope's top is about 4.8 high at x = 3; the pad point is the only named surface point.
		local slope = addBox("Slope", Vector3.new(0, 2.5, 0), Vector3.new(12, 1, 12))
		slope.CFrame = CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(30))
		local problems = check(Vector3.new(-6, 0, 0), Vector3.new(3, 15, 0))
		expect(#problems).toBe(1)
		expect(problems[1].kind).toBe("walk area")
	end)

	it(
		"fails when a ray on the pad alone sees 13 above but another solid part under the spot is 10 below it",
		function()
			addBox("Step", Vector3.new(4, 1.5, 0), Vector3.new(2, 3, 2)) -- top at y = 3
			local problems = check(PAD_POINT, Vector3.new(4, 13, 0))
			expect(#problems).toBe(1)
			expect(problems[1].kind).toBe("walk area")
		end
	)

	it("passes a walk spot 13 above the pad", function()
		expect(#check(PAD_POINT, Vector3.new(4, 13, 0))).toBe(0)
	end)

	it("passes a walk spot 10 above but more than 10 across", function()
		expect(#check(PAD_POINT, Vector3.new(11, 10, 0))).toBe(0)
	end)

	it("fails a stray truss 12 above a pad and within 10 across", function()
		local truss = addTruss(12, 5)
		local problems = checkParts({ truss }, {})
		expect(#problems).toBe(1)
		expect(problems[1].kind).toBe("climbable")
		expect(problems[1].detail).toContain("Pad")
		expect(problems[1].detail).toContain("Truss")
	end)

	it("passes a truss 16 above, and a truss 12 above but 30 across", function()
		expect(#checkParts({ addTruss(16, 5) }, {})).toBe(0)
		expect(#checkParts({ addTruss(12, 30) }, {})).toBe(0)
	end)

	-- A ledge at (8, 3, 0): from the pad point a jump rises 3 and crosses 8, inside the jump reach (Config.Nests.Jump).
	local LEDGE = Vector3.new(8, 3, 0)

	it("fails a nest 7 studs from a ledge a jump lands on", function()
		local problems = checkParts({}, { Vector3.new(15, 3, 0) }, { LEDGE })
		expect(#problems).toBe(1)
		expect(problems[1].kind).toBe("nest")
	end)

	it("passes a nest 7 studs from the top of a jump with nothing to stand on near it", function()
		-- The nest sits where the old reach volume (flat radius 11) would have flagged it; no stand is within 8 of it.
		expect(#checkParts({}, { Vector3.new(18, 0, 0) }, {})).toBe(0)
		expect(#checkParts({}, { Vector3.new(18, 0, 0) }, { Vector3.new(60, 0, 0) })).toBe(0)
	end)

	it("passes a nest 9 studs from a ledge a jump lands on", function()
		expect(#checkParts({}, { Vector3.new(17, 3, 0) }, { LEDGE })).toBe(0)
	end)

	it("names the surface and the spot in the message of every kind", function()
		local walk = check(PAD_POINT, Vector3.new(4, 10, 0))
		local truss = checkParts({ addTruss(12, 5) }, {})
		local nest = checkParts({}, { Vector3.new(15, 3, 0) }, { LEDGE })
		for _, problems in { walk, truss, nest } do
			expect(problems[1].detail).toContain("Pad")
			expect(problems[1].detail).toContain(tostring(PAD_POINT))
		end
	end)

	it("keeps the jump helpers' answers through PillowWayUp", function()
		expect(PillowWayUp.jumpReaches).toBe(WaysUpCheck.jumpReaches)
		expect(PillowWayUp.apexBetween).toBe(WaysUpCheck.apexBetween)
		expect(WaysUpCheck.jumpReaches(Vector3.zero, Vector3.new(5, 4, 0), 7.2, 196.2, 16)).toBe(true)
		expect(WaysUpCheck.jumpReaches(Vector3.zero, Vector3.new(0, 8, 0), 7.2, 196.2, 16)).toBe(false)
		expect(WaysUpCheck.apexBetween(Vector3.zero, Vector3.new(4, 2, 0), 6)).toBe(Vector3.new(2, 5, 0))
	end)
end)

describe("WaysUpCheck.reachedByJump", function()
	local START = Vector3.new(0, 0, 0)

	it("leaves out a guard top 14 studs above every start", function()
		local kept = WaysUpCheck.reachedByJump({ START, Vector3.new(30, 0, 0) }, { Vector3.new(2, 14, 0) })
		expect(#kept).toBe(0)
	end)

	it("keeps a guard top 5 above and 4 across", function()
		local top = Vector3.new(4, 5, 0)
		local kept = WaysUpCheck.reachedByJump({ START }, { top, Vector3.new(2, 14, 0) })
		expect(#kept).toBe(1)
		expect(kept[1]).toBe(top)
	end)
end)
