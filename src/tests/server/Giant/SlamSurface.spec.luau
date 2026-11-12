--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Slams = require(ServerScriptService.Server.Giant.Slams)
local SlamSurface = require(ServerScriptService.Server.Giant.SlamSurface)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- A little world far from the map. Every part is anchored and solid (CanCollide on), so only the ignore list and the
-- slope rule decide what the ray meets. The pad's top face is at ORIGIN.Y.
local ORIGIN = Vector3.new(3000, 100, 3000)
local PAD_TOP = ORIGIN.Y
local CENTRE = ORIGIN + Vector3.new(0, 30, 0)

local made: { Instance } = {}

local function track<T>(instance: T & Instance): T
	table.insert(made, instance)
	return instance
end

afterEach(function()
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, className: string?): Part
	local p = Instance.new(className or "Part") :: Part
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function newFolder(): Folder
	local folder = track(Instance.new("Folder"))
	folder.Name = "SlamSurfaceSpec"
	folder.Parent = Workspace
	return folder
end

local function pad(folder: Folder)
	part(folder, "Pad", Vector3.new(40, 1, 40), CFrame.new(ORIGIN - Vector3.new(0, 0.5, 0)))
end

-- A slope: a flat plank turned `degrees` about Z, its middle `height` above the pad. The ray at x = 0 meets its top face.
local function slope(folder: Folder, degrees: number, height: number): Part
	return part(
		folder,
		"Slope",
		Vector3.new(6, 1, 6),
		CFrame.new(ORIGIN + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(degrees))
	)
end

-- A ladder model like the real ones: a TrussPart named Climb and rungs, all standing over the ray.
local function ladder(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	part(model, "Climb", Vector3.new(2, 10, 2), CFrame.new(ORIGIN + Vector3.new(0, 6, 0)), "TrussPart")
	for i = 1, 3 do
		part(model, `Rung{i}`, Vector3.new(4, 0.4, 0.4), CFrame.new(ORIGIN + Vector3.new(0, 2 * i, 0)))
	end
	return model
end

local function box(name: string): Zones.LadderBox
	return { ladder = name, zone = "Boots", cframe = CFrame.new(ORIGIN), size = Vector3.new(4, 10, 4) }
end

describe("SlamSurface.below", function()
	it("the point is on the pad when a Climb truss and a rung stand over it", function()
		local folder = newFolder()
		pad(folder)
		local surfaces = Instance.new("Folder")
		surfaces.Name = "WalkSurfaces"
		surfaces.Parent = folder
		ladder(surfaces, "TestLadder")
		local ignore = SlamSurface.ladderParts(surfaces, { box("TestLadder") })
		local point = SlamSurface.below(Workspace, CENTRE, ignore)
		expect(point.Y).toBeCloseTo(PAD_TOP, 2)
	end)

	it("without the ladder parts the same ray stops on the truss", function()
		local folder = newFolder()
		pad(folder)
		ladder(folder, "TestLadder")
		local point = SlamSurface.below(Workspace, CENTRE, {})
		expect(point.Y > PAD_TOP + 1).toBe(true)
	end)

	it("a 75 degree slope over a flat pad gives the pad", function()
		local folder = newFolder()
		pad(folder)
		slope(folder, 75, 8)
		local point = SlamSurface.below(Workspace, CENTRE, {})
		expect(point.Y).toBeCloseTo(PAD_TOP, 2)
	end)

	it("a 60 degree slope is still stood on", function()
		local folder = newFolder()
		pad(folder)
		slope(folder, 60, 8)
		local point = SlamSurface.below(Workspace, CENTRE, {})
		-- The ray at x = 0 meets the top face 0.5 / cos(60 degrees) = 1 stud above the plank's middle.
		expect(point.Y).toBeCloseTo(PAD_TOP + 8 + 0.5 / math.cos(math.rad(60)), 2)
	end)

	it("all steep parts and nothing under gives the old fallback", function()
		local folder = newFolder()
		for i = 0, 8 do
			part(
				folder,
				`Steep{i}`,
				Vector3.new(6, 1, 6),
				CFrame.new(ORIGIN + Vector3.new(0, 5 + 2 * i, 0)) * CFrame.Angles(0, 0, math.rad(75))
			)
		end
		local point = SlamSurface.below(Workspace, CENTRE, {})
		-- The old fallback: 3 studs under the centre (MIDDLE_ABOVE_FEET in SlamSurface).
		expect(point.Y).toBeCloseTo(CENTRE.Y - 3, 2)
		expect(point.X).toBeCloseTo(CENTRE.X, 2)
	end)

	it("the caller's ignore list is not changed", function()
		local folder = newFolder()
		pad(folder)
		slope(folder, 75, 8)
		local marker = Instance.new("Folder")
		marker.Name = "Marker"
		marker.Parent = folder
		local ignore: { Instance } = { marker }
		SlamSurface.below(Workspace, CENTRE, ignore)
		expect(#ignore).toBe(1)
		expect(ignore[1]).toBe(marker)
	end)
end)

describe("SlamSurface.ladderParts", function()
	it("gives the model for each box and skips a missing name", function()
		local folder = newFolder()
		local one = ladder(folder, "LadderOne")
		local two = ladder(folder, "LadderTwo")
		local found = SlamSurface.ladderParts(folder, { box("LadderOne"), box("NoSuchLadder"), box("LadderTwo") })
		expect(#found).toBe(2)
		expect(found[1]).toBe(one)
		expect(found[2]).toBe(two)
	end)
end)

-- A circle whose point is `rise` over the pad and whose centre is on the same line (the circle's middle, drawn on a
-- curved surface that is higher in the middle than at the edge).
local function circleOver(rise: number): Slams.HandCircle
	local point = ORIGIN + Vector3.new(0, rise, 0)
	return { centre = point + Vector3.new(0, 3, 0), point = point }
end

-- 4b: the surface under a player, found by `under`, decides whether the hand hits them (Slams.underHand).
describe("SlamSurface.under (4b: the edge of a curved surface)", function()
	local EDGE = Vector3.new(10, 0, 0)

	local function hitAt(circle: Slams.HandCircle, footAbovePad: number): boolean
		local position = ORIGIN + EDGE + Vector3.new(0, footAbovePad, 0)
		local surface = SlamSurface.under(Workspace, circle, position, {})
		return Slams.underHand(position, circle, surface)
	end

	it("the pad 6 studs under the circle's point is the surface under a player on the edge", function()
		local folder = newFolder()
		pad(folder)
		local surface = SlamSurface.under(Workspace, circleOver(6), ORIGIN + EDGE + Vector3.new(0, 3, 0), {})
		expect(surface).toBeCloseTo(PAD_TOP, 2)
	end)

	it("a player on the edge, 6 under the centre, is hit", function()
		local folder = newFolder()
		pad(folder)
		expect(hitAt(circleOver(6), 3)).toBe(true)
	end)

	it("a player 40 studs over the edge is hit", function()
		local folder = newFolder()
		pad(folder)
		expect(hitAt(circleOver(6), 40)).toBe(true)
	end)

	it("a player 2 studs under the edge surface is not hit", function()
		local folder = newFolder()
		pad(folder)
		expect(hitAt(circleOver(6), -2)).toBe(false)
	end)

	it("nothing under the ray gives the circle's own point height", function()
		local circle = circleOver(6)
		local surface = SlamSurface.under(Workspace, circle, ORIGIN + EDGE + Vector3.new(0, 3, 0), {})
		expect(surface).toBeCloseTo(circle.point.Y, 2)
	end)
end)

-- 4c: `under` looks at what a player can stand on, like `below`.
describe("SlamSurface.under (4c: ladders and steep parts)", function()
	it("skips a ladder model in ignore and a 75 degree part", function()
		local folder = newFolder()
		pad(folder)
		slope(folder, 75, 8)
		local surfaces = Instance.new("Folder")
		surfaces.Name = "WalkSurfaces"
		surfaces.Parent = folder
		ladder(surfaces, "TestLadder")
		local ignore = SlamSurface.ladderParts(surfaces, { box("TestLadder") })
		local circle = circleOver(1)
		local surface = SlamSurface.under(Workspace, circle, ORIGIN + Vector3.new(0, 3, 0), ignore)
		expect(surface).toBeCloseTo(PAD_TOP, 2)
	end)

	it("starts above the circle by the hand's reach and does not change the ignore list", function()
		local folder = newFolder()
		pad(folder)
		-- A plank HandAboveStuds - 1 over the circle's point: the ray starts over it and stands on it.
		local circle = circleOver(1)
		local plankY = circle.point.Y + Config.Wake.HandAboveStuds - 1
		part(folder, "HighPlank", Vector3.new(6, 1, 6), CFrame.new(ORIGIN.X, plankY - 0.5, ORIGIN.Z))
		local marker = Instance.new("Folder")
		marker.Name = "Marker"
		marker.Parent = folder
		local ignore: { Instance } = { marker }
		local surface = SlamSurface.under(Workspace, circle, ORIGIN + Vector3.new(0, 3, 0), ignore)
		expect(surface).toBeCloseTo(plankY, 2)
		expect(#ignore).toBe(1)
	end)
end)
