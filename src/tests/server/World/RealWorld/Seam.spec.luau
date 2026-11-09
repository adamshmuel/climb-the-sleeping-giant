--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)
local Helpers = require(script.Parent.Helpers)
local WalkAreaFacts = require(ServerStorage.Tests.server.World.StuckScan.WalkAreaFacts)

-- Plan 5 (docs/plans/v2/egg-nests-and-climbing.md) Task 16: the seam stitches in World.Seam. Spec 5 section 5, "Seam
-- match", and Rule 80 (The seam shows where walking ends). These tests only READ the real world. The pieces are laid by
-- tools/world/24-seam.luau on the style guide's seam table (docs/design/v2/style-guide/nests-map.md, "Where it is"),
-- which lives once in src/shared/SeamTable.luau (WalkAreaFacts.SEAM_TABLE points at it). Method: work/p5t16/stepback-decision.md (a numbers check, no Play walk).

local SIDES = { -1, 1 } -- his left is the negative x
local NO_TOUCH = { "CanCollide", "CanQuery", "CanTouch" }
local ACROSS_LIMIT = 0.5 -- studs: a stitch lies this close to the table line, across it (stop rule 1)
local POCKET_GAP = 3 -- studs: no stitch within this distance of any part of a belly pocket
local STRAP_GAP = 0.5 -- studs: no stitch or band piece within this distance of a cuff strap
local SKIN_RAY_ABOVE = 2 -- studs: a stitch's skin ray starts this far above it
local SKIN_MAX_UNDER = 0.3 -- studs: the skin lies at most this far under a stitch
local SEAMLINE_STEP = 2 -- studs between SeamLine points
local SEAMLINE_MARGIN = 0.5 -- studs: a point lies this close to each 2-stud mark
local DOWN_REACH = 2 -- studs: how far along Down the downhill check looks (measured: the cuff top is bumpy, it falls away by 2)
local DOWN_RAY_ABOVE = 3 -- studs: its ray starts this far above the point

local function sideName(side: number): string
	return if side < 0 then "L" else "R"
end

local function seamFolder(name: string): Folder
	local seam = Helpers.realWorld():FindFirstChild("Seam")
	expect(seam).never.toBeNil()
	local folder = (seam :: Instance):FindFirstChild(name)
	expect(folder).never.toBeNil()
	return folder :: Folder
end

local function partsIn(folder: Instance): { BasePart }
	local list: { BasePart } = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

local tableLine = WalkAreaFacts.seamLine
local flatDistanceToLine = WalkAreaFacts.flatDistanceToLine
local distanceToBox = WalkAreaFacts.distanceToBox

local function skinRay(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Helpers.realWorld():FindFirstChild("Giant") :: Instance }
	return params
end

local function marksAlong(line: { Vector3 }): { Vector3 }
	return WalkAreaFacts.marksAlong(line, SEAMLINE_STEP)
end

local function seamLinePoints(): { BasePart }
	return partsIn(seamFolder("SeamLine"))
end

describe("Seam stitches (Task 16)", function()
	it("no seam part can be hit, stood on or touched", function()
		local offenders: { string } = {}
		local count = 0
		local seam = Helpers.realWorld():FindFirstChild("Seam")
		expect(seam).never.toBeNil()
		for _, part in partsIn(seam :: Instance) do
			count += 1
			for _, property in NO_TOUCH do
				if (part :: any)[property] ~= false then
					table.insert(offenders, `{part:GetFullName()} {property}`)
				end
			end
			if not part.Anchored then
				table.insert(offenders, `{part:GetFullName()} not anchored`)
			end
		end
		expect(table.concat(offenders, ", ")).toBe("")
		expect(count).toBeGreaterThan(0)
	end)

	it("the stitches follow the seam table within 0.5 studs and keep 3 studs from the belly pockets", function()
		local stitches = partsIn(seamFolder("Stitches"))
		local pockets = WalkAreaFacts.artFolder():FindFirstChild("Pockets") :: Instance
		expect(pockets).never.toBeNil()
		local off: { string } = {}
		local perSide: { [number]: number } = { [-1] = 0, [1] = 0 }
		for _, stitch in stitches do
			local side = if stitch.Position.X < 0 then -1 else 1
			perSide[side] += 1
			local across = flatDistanceToLine(stitch.Position, tableLine(side))
			if across > ACROSS_LIMIT then
				table.insert(
					off,
					`{sideName(side)} z{string.format("%.1f", stitch.Position.Z)} across {string.format("%.2f", across)}`
				)
			end
			local pocket = pockets:FindFirstChild(`BellyPocket_{if side < 0 then "Left" else "Right"}`) :: Instance
			for _, piece in partsIn(pocket) do
				local gap = distanceToBox(piece, stitch.Position)
				if gap < POCKET_GAP - 0.01 then
					table.insert(
						off,
						`{sideName(side)} z{string.format("%.1f", stitch.Position.Z)} {string.format("%.2f", gap)} from {piece.Name}`
					)
					break
				end
			end
		end
		expect(table.concat(off, ", ")).toBe("")
		expect(perSide[-1]).toBeGreaterThan(0)
		expect(perSide[1]).toBeGreaterThan(0)
	end)

	it("each stitch sits on his skin", function()
		local params = skinRay()
		local off: { string } = {}
		for _, stitch in partsIn(seamFolder("Stitches")) do
			local start = stitch.Position + Vector3.new(0, SKIN_RAY_ABOVE, 0)
			local hit = Workspace:Raycast(start, Vector3.new(0, -(SKIN_RAY_ABOVE + 2), 0), params)
			local under = if hit ~= nil then stitch.Position.Y - hit.Position.Y else nil
			if under == nil or under < -0.05 or under > SKIN_MAX_UNDER then
				table.insert(
					off,
					`({string.format("%.1f, %.1f, %.1f", stitch.Position.X, stitch.Position.Y, stitch.Position.Z)}) under {if under
							== nil
						then "no skin"
						else string.format("%.2f", under)}`
				)
			end
		end
		expect(table.concat(off, ", ")).toBe("")
	end)

	it("no stitch or band piece lies across a cuff strap", function()
		local straps: { BasePart } = {}
		local art = Helpers.realWorld():FindFirstChild("CuffArt") :: Instance
		expect(art).never.toBeNil()
		for _, name in { "CuffStrap_Left", "CuffStrap_Right" } do
			for _, part in partsIn(art:FindFirstChild(name) :: Instance) do
				table.insert(straps, part)
			end
		end
		expect(#straps).toBeGreaterThan(0)
		local off: { string } = {}
		for _, folderName in { "Stitches", "HemBand" } do
			for _, piece in partsIn(seamFolder(folderName)) do
				for _, strap in straps do
					if distanceToBox(strap, piece.Position) < STRAP_GAP then
						table.insert(off, `{folderName} z{string.format("%.1f", piece.Position.Z)} on {strap.Name}`)
						break
					end
				end
			end
		end
		expect(table.concat(off, ", ")).toBe("")
	end)

	it("SeamLine has a point every 2 studs on both sides and both cuff rims, and Down points downhill", function()
		local points = seamLinePoints()
		expect(#points).toBeGreaterThan(0)
		local lines: { { name: string, marks: { Vector3 } } } = {}
		for _, side in SIDES do
			table.insert(lines, { name = `belly {sideName(side)}`, marks = marksAlong(tableLine(side)) })
		end
		table.insert(lines, { name = "cuff L", marks = marksAlong(SlideProfile.CUFF_LEFT) })
		table.insert(lines, { name = "cuff R", marks = marksAlong(SlideProfile.CUFF_RIGHT) })
		local missing: { string } = {}
		for _, line in lines do
			for _, mark in line.marks do
				local near = false
				for _, point in points do
					if
						(Vector3.new(point.Position.X, 0, point.Position.Z) - Vector3.new(mark.X, 0, mark.Z)).Magnitude
						<= SEAMLINE_MARGIN
					then
						near = true
						break
					end
				end
				if not near then
					table.insert(
						missing,
						`{line.name} x{string.format("%.1f", mark.X)} z{string.format("%.1f", mark.Z)}`
					)
				end
			end
		end
		expect(table.concat(missing, ", ")).toBe("")

		local params = skinRay()
		local uphill: { string } = {}
		for _, point in points do
			local down = point:GetAttribute("Down")
			if
				typeof(down) ~= "Vector3"
				or math.abs((down :: Vector3).Magnitude - 1) > 0.01
				or (down :: Vector3).Y ~= 0
			then
				table.insert(uphill, `{point.Name} Down not a flat unit vector`)
			else
				local across = point.Position + (down :: Vector3) * DOWN_REACH
				local start = across + Vector3.new(0, DOWN_RAY_ABOVE, 0)
				local hit = Workspace:Raycast(start, Vector3.new(0, -(DOWN_RAY_ABOVE + 20), 0), params)
				if hit == nil or hit.Position.Y >= point.Position.Y then
					table.insert(
						uphill,
						`{point.Name} ({string.format(
							"%.1f, %.1f, %.1f",
							point.Position.X,
							point.Position.Y,
							point.Position.Z
						)}) not lower`
					)
				end
			end
		end
		expect(table.concat(uphill, ", ")).toBe("")
	end)

	it("the walk-area check reads only the stitch dashes as the seam", function()
		-- A made-up world: dashes under Seam.Stitches count; the band, the seam line and a stray part do not.
		local world = Instance.new("Folder")
		local seam = Instance.new("Folder")
		seam.Name = "Seam"
		seam.Parent = world
		for _, name in { "Stitches", "HemBand", "SeamLine" } do
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = seam
		end
		local function addPart(parent: Instance, x: number)
			local part = Instance.new("Part")
			part.Position = Vector3.new(x, 0, 0)
			part.Parent = parent
		end
		addPart(seam:FindFirstChild("Stitches") :: Instance, 1)
		addPart(seam:FindFirstChild("Stitches") :: Instance, 2)
		addPart(seam:FindFirstChild("HemBand") :: Instance, 3)
		addPart(seam:FindFirstChild("SeamLine") :: Instance, 4)
		addPart(seam, 5)
		local read = WalkAreaFacts.stitchPositions(world)
		expect(read).never.toBeNil()
		expect(#(read :: { Vector3 })).toBe(2)
		world:Destroy()
		-- The real world: exactly the dashes of World.Seam.Stitches, and there are some.
		local real = WalkAreaFacts.stitchPositions(Helpers.realWorld())
		expect(real).never.toBeNil()
		expect(#(real :: { Vector3 })).toBe(#partsIn(seamFolder("Stitches")))
		expect(#(real :: { Vector3 })).toBeGreaterThan(0)
	end)
end)
