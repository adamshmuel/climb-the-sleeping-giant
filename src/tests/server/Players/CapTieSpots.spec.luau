--!strict
-- Task 61h: which cap tie (if any) a spot is on (spec 5, Rule 8: Steps make noise). The tracker asks this only while a
-- player is climbing, so a climb on a cap tie counts as "from the head" at any height.
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local CapTieSpots = require(ServerScriptService.Server.Players.CapTieSpots)

local MARGIN_NEAR = 1.5 -- a climbing root sits about 1 to 1.5 studs off a truss face
local MARGIN_FAR = 5

-- A walk-surfaces folder with a left tie of one truss-sized part at the origin (2 by 28 by 2), and no right tie unless
-- `withRight` says so (then a right tie part 40 studs along x). The caller destroys the folder.
local function makeSurfaces(withRight: boolean): Folder
	local surfaces = Instance.new("Folder")
	local left = Instance.new("Model")
	left.Name = "CapTieLeft"
	local leftPart = Instance.new("Part")
	leftPart.Size = Vector3.new(2, 28, 2)
	leftPart.CFrame = CFrame.new(0, 70, 0)
	leftPart.Parent = left
	left.Parent = surfaces
	if withRight then
		local right = Instance.new("Model")
		right.Name = "CapTieRight"
		local rightPart = Instance.new("Part")
		rightPart.Size = Vector3.new(2, 28, 2)
		rightPart.CFrame = CFrame.new(40, 70, 0)
		rightPart.Parent = right
		right.Parent = surfaces
	end
	return surfaces
end

describe("CapTieSpots", function()
	it("a spot 1.5 studs off a left tie part is on the Left tie", function()
		local surfaces = makeSurfaces(false)
		local boxes = CapTieSpots.boxes(surfaces)

		expect(CapTieSpots.sideAt(boxes, Vector3.new(1 + MARGIN_NEAR, 70, 0))).toBe("Left")

		surfaces:Destroy()
	end)

	it("a spot 5 studs off every tie part is on no tie", function()
		local surfaces = makeSurfaces(true)
		local boxes = CapTieSpots.boxes(surfaces)

		expect(CapTieSpots.sideAt(boxes, Vector3.new(1 + MARGIN_FAR, 70, 0))).toBeNil()
		expect(CapTieSpots.sideAt(boxes, Vector3.new(20, 70, 0))).toBeNil()

		surfaces:Destroy()
	end)

	it("a missing right tie is skipped", function()
		local surfaces = makeSurfaces(false)
		local boxes = CapTieSpots.boxes(surfaces)

		expect(#boxes).toBe(1)
		expect(boxes[1].side).toBe("Left")

		surfaces:Destroy()
	end)
end)
