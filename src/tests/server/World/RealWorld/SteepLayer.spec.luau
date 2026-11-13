--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)
local Helpers = require(script.Parent.Helpers)
local MockupNests = require(ServerStorage.Tests.server.World.MockupNests)
local bodyMesh = Helpers.bodyMesh

-- Plan 5 Task 15a (spec 5 Rule 80 "The seam shows where walking ends", section 5 "Steep face" 75 degrees): a smooth,
-- invisible steep layer covers the cloth that is steeper than the seam but that a character still walks on, so the
-- player slides off at the seam. These tests READ the world: World.SteepLayer, against the slide list that
-- SlideProfile.steepList gives for the side walks (every whole z from -38 to -14) and the cuff walks (stations 1 to 3
-- and the midpoints). A part's outward face is its top face (its UpVector), and its thickness is its Size.Y.
describe("the real world, the steep layer", function()
	local COVER_ABOVE = 5 -- studs: the cover ray starts this high above a place...
	local COVER_REACH = 10 -- ...and looks this far down
	local COVER_LIMIT = 1 -- studs: the layer may stand this far over his skin (along the skin's normal)
	local MARGIN = 0.005 -- studs: rounding in the numbers written into the world
	local OTHER_ROW_TOLERANCE = 0.01 -- studs: a piece may stand this much higher at another row's place (no player sees it)
	local SKIN_CLEAR = 0.05 -- studs: a face point must be this far clear of his skin
	local FROM_OUTSIDE = 3 -- studs: the skin ray starts this far outside the face
	local STEEP_FACE_DEGREES = 75 -- spec 5, section 5 "Steep face"
	local CUFF_BY_THE_STRAP = { 4, 5 } -- the cuff stations with no steep layer
	local STATION_CLEAR = 2 -- studs (flat): no steep piece this close to those stations
	local SIDE_PIECE = SlideProfile.SIDE_PIECE

	-- One walk of the slide list: its name, his piece, and the places that need the layer.
	type Entry = { name: string, piece: MeshPart, places: { SlideProfile.Place } }

	local function sideEntries(line: { Vector3 }, sideName: string, towards: number): { Entry }
		local piece = bodyMesh(SIDE_PIECE)
		local entries: { Entry } = {}
		for _, row in SlideProfile.sideRows(SlideProfile.sideSamples(line), sideName, towards, piece) do
			local places = SlideProfile.steepList(row)
			table.insert(entries, { name = row.name, piece = piece, places = places })
		end
		return entries
	end

	local function cuffEntries(line: { Vector3 }, cuffName: string, pieceName: string, strapStart: Vector3): { Entry }
		local piece = bodyMesh(pieceName)
		local params = SlideProfile.onlyParams(piece)
		local entries: { Entry } = {}
		for _, station in SlideProfile.cuffSamples(line) do
			local row = SlideProfile.cuffRow(params, `{cuffName} cuff, station {station.number}`, station, strapStart)
			local places = SlideProfile.steepList(row)
			table.insert(entries, { name = row.name, piece = piece, places = places })
		end
		return entries
	end

	-- Computed once: the walks read thousands of rays.
	local measured: { Entry }? = nil
	local function entries(): { Entry }
		if measured == nil then
			local all: { Entry } = {}
			for _, group in
				{
					sideEntries(SlideProfile.SEAM_LEFT, "left", -1),
					sideEntries(SlideProfile.SEAM_RIGHT, "right", 1),
					cuffEntries(SlideProfile.CUFF_LEFT, "left", "left_arm", SlideProfile.STRAP_START_LEFT),
					cuffEntries(SlideProfile.CUFF_RIGHT, "right", "right_arm", SlideProfile.STRAP_START_RIGHT),
				}
			do
				for _, entry in group do
					table.insert(all, entry)
				end
			end
			measured = all
		end
		return measured :: { Entry }
	end

	local function steepLayer(): Instance?
		local world = Workspace:FindFirstChild("World")
		return if world == nil then nil else world:FindFirstChild("SteepLayer")
	end

	local function layerParts(): { BasePart }
		local parts: { BasePart } = {}
		local layer = steepLayer()
		if layer ~= nil then
			for _, descendant in layer:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end
		end
		return parts
	end

	-- Whether `part` is a piece of the pair that row `rowName` belongs to. Rows are named
	-- "left side, z -35" and "left cuff, station 1.5" (SlideProfile); pieces Steep_Left_z-35_top and
	-- Steep_LeftCuff_1-1.5 (tools/world/23-steep-layer.luau). A side piece covers rows z and z + 1.
	local function ownsRow(partName: string, rowName: string): boolean
		local side, z = string.match(rowName, "^(%a+) side, z (%-?[%d%.]+)$")
		if side ~= nil then
			local pieceSide, pieceZ = string.match(partName, "^Steep_(%a+)_z(%-?%d+)")
			local row, base = tonumber(z), tonumber(pieceZ)
			return pieceSide ~= nil
				and string.lower(pieceSide) == side
				and row ~= nil
				and base ~= nil
				and (row == base or row == base + 1)
		end
		local cuffSide, station = string.match(rowName, "^(%a+) cuff, station ([%d%.]+)$")
		if cuffSide ~= nil then
			local pieceSide, first, second = string.match(partName, "^Steep_(%a+)Cuff_([%d%.]+)%-([%d%.]+)")
			local row = tonumber(station)
			return pieceSide ~= nil
				and string.lower(pieceSide) == cuffSide
				and row ~= nil
				and (row == tonumber(first) or row == tonumber(second))
		end
		return false
	end

	local function describePoint(point: Vector3): string
		return string.format("(%.1f, %.1f, %.1f)", point.X, point.Y, point.Z)
	end

	local function flat(a: Vector3, b: Vector3): number
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	it("the steep layer exists", function()
		expect(#layerParts()).toBeGreaterThan(0)
	end)

	it("every place on the slide list is covered within a stud", function()
		local layer = steepLayer()
		local coverParams = RaycastParams.new()
		coverParams.FilterType = Enum.RaycastFilterType.Include
		coverParams.FilterDescendantsInstances = if layer == nil then {} else { layer }
		coverParams.RespectCanCollide = false
		local total = 0
		local bad: { string } = {}
		for _, entry in entries() do
			local skinParams = SlideProfile.onlyParams(entry.piece)
			for _, place in entry.places do
				total += 1
				local reason: string? = nil
				local hit = Workspace:Raycast(
					place.position + Vector3.new(0, COVER_ABOVE, 0),
					Vector3.new(0, -COVER_REACH, 0),
					coverParams
				)
				local skin = Workspace:Raycast(
					Vector3.new(place.position.X, SlideProfile.BODY_SLOPE_RAY_ABOVE, place.position.Z),
					Vector3.new(0, -SlideProfile.BODY_SLOPE_RAY_LENGTH, 0),
					skinParams
				)
				if hit == nil then
					reason = "nothing there"
				elseif skin == nil then
					reason = "no skin there"
				else
					local height = (hit.Position - place.position):Dot(skin.Normal)
					-- a piece's own places keep the 1-stud limit; at another row's place it may stand OTHER_ROW_TOLERANCE higher
					local limit = COVER_LIMIT + MARGIN
					if not ownsRow(hit.Instance.Name, entry.name) then
						limit += OTHER_ROW_TOLERANCE
					end
					if height < -MARGIN or height > limit then
						reason = string.format("%.2f studs over his skin", height)
					end
				end
				if reason ~= nil then
					table.insert(bad, `{entry.name} {describePoint(place.position)}: {reason}`)
				end
			end
		end
		expect(total).toBeGreaterThan(0)
		if #bad > 0 then
			error(`{#bad} of {total} places uncovered, first: {table.concat(bad, "; ")}`, 0)
		end
	end)

	it("no steep piece goes through his skin", function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { bodyMesh(SIDE_PIECE), bodyMesh("left_arm"), bodyMesh("right_arm") }
		params.RespectCanCollide = false
		local bad: { string } = {}
		for _, part in layerParts() do
			local normal = part.CFrame.UpVector
			local face = part.Position + normal * (part.Size.Y / 2)
			for _, across in { -1, 0, 1 } do
				for _, along in { -1, 0, 1 } do
					local point = face
						+ part.CFrame.RightVector * (across * part.Size.X / 2)
						+ part.CFrame.LookVector * (along * part.Size.Z / 2)
					local hit =
						Workspace:Raycast(point + normal * FROM_OUTSIDE, -normal * (FROM_OUTSIDE + SKIN_CLEAR), params)
					if hit ~= nil then
						table.insert(bad, `{part.Name} {describePoint(point)}`)
					end
				end
			end
		end
		if #bad > 0 then
			error(`{#bad} face points are not clear of his skin, first: {table.concat(bad, "; ")}`, 0)
		end
	end)

	it("every steep face slips", function()
		local floorNormalY = math.cos(math.rad(STEEP_FACE_DEGREES))
		local bad: { string } = {}
		for _, part in layerParts() do
			local cframe = part.CFrame
			if cframe.UpVector.Y > floorNormalY + MARGIN then
				table.insert(bad, `{part.Name}: face {math.deg(math.acos(cframe.UpVector.Y))} degrees from flat`)
			end
			-- the thin edges: the highest one is the part's top edge (allowed); no other edge may lean up past the face limit
			local edgeHeights: { number } = {}
			for _, edge in { cframe.RightVector, -cframe.RightVector, cframe.LookVector, -cframe.LookVector } do
				table.insert(edgeHeights, edge.Y)
			end
			table.sort(edgeHeights, function(a, b)
				return a > b
			end)
			if edgeHeights[2] > floorNormalY + MARGIN then
				table.insert(bad, `{part.Name}: a second edge faces up`)
			end
		end
		if #bad > 0 then
			error(`{#bad} steep faces are too flat, first: {table.concat(bad, "; ")}`, 0)
		end
	end)

	it("no steep piece at cuff points 4 and 5 or in the strap mouth", function()
		local avoid: { { at: Vector3, within: number, name: string } } = {}
		for _, line in { SlideProfile.CUFF_LEFT, SlideProfile.CUFF_RIGHT } do
			for _, number in CUFF_BY_THE_STRAP do
				table.insert(avoid, { at = line[number], within = STATION_CLEAR, name = `cuff point {number}` })
			end
		end
		for _, start in { SlideProfile.STRAP_START_LEFT, SlideProfile.STRAP_START_RIGHT } do
			table.insert(avoid, { at = start, within = SlideProfile.STRAP_GAP, name = "a strap start" })
		end
		local bad: { string } = {}
		for _, part in layerParts() do
			for _, spot in avoid do
				if flat(part.Position, spot.at) <= spot.within then
					table.insert(bad, `{part.Name} is within {spot.within} of {spot.name}`)
				end
			end
		end
		if #bad > 0 then
			error(`{#bad} steep pieces by the strap, first: {table.concat(bad, "; ")}`, 0)
		end
	end)

	-- The belly pockets' ledges (ArtLibrary.Mockup_Nests.Art.Pockets.BellyPocket_<side>.LedgeWalk) are walk area; a steep piece may
	-- not stand up past one. A 21 by 21 ray grid over each ledge top, from above, against the steep layer only.
	it("no steep piece rises above a belly pocket ledge", function()
		local GRID = 21
		local LEDGE_ABOVE = 5 -- studs: the rays start this far over the ledge top
		local LEDGE_REACH = 20 -- studs: ...and look this far down
		local LEDGE_SLACK = 0.2 -- studs: a steep piece may stand this near the ledge top
		local layer = steepLayer()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = if layer == nil then {} else { layer }
		params.RespectCanCollide = false
		local nests = MockupNests.find()
		local pockets = if nests == nil then nil else nests:FindFirstChild("Art")
		pockets = if pockets == nil then nil else pockets:FindFirstChild("Pockets")
		local bad: { string } = {}
		local ledgeCount = 0
		local rayCount = 0
		for _, side in { "Left", "Right" } do
			local pocket = if pockets == nil then nil else pockets:FindFirstChild(`BellyPocket_{side}`)
			local ledge = if pocket == nil then nil else pocket:FindFirstChild("LedgeWalk")
			if ledge ~= nil and ledge:IsA("BasePart") then
				ledgeCount += 1
				local top = ledge.Position.Y + ledge.Size.Y / 2
				local worst = 0
				local over = 0
				for column = 0, GRID - 1 do
					for row = 0, GRID - 1 do
						local local_ = Vector3.new(
							(column / (GRID - 1) - 0.5) * ledge.Size.X,
							ledge.Size.Y / 2,
							(row / (GRID - 1) - 0.5) * ledge.Size.Z
						)
						local point = ledge.CFrame:PointToWorldSpace(local_)
						rayCount += 1
						local hit = Workspace:Raycast(
							Vector3.new(point.X, top + LEDGE_ABOVE, point.Z),
							Vector3.new(0, -LEDGE_REACH, 0),
							params
						)
						if hit ~= nil and hit.Position.Y > top - LEDGE_SLACK then
							over += 1
							worst = math.max(worst, hit.Position.Y - top)
						end
					end
				end
				if over > 0 then
					table.insert(bad, `{side} ledge: {over} rays hit a steep piece up to {worst} over its top`)
				end
			end
		end
		expect(ledgeCount).toBe(2)
		expect(rayCount).toBe(2 * GRID * GRID)
		if #bad > 0 then
			error(table.concat(bad, "; "), 0)
		end
	end)

	it("every steep piece is invisible, solid and anchored", function()
		local bad: { string } = {}
		for _, part in layerParts() do
			if
				part.Transparency ~= 1
				or not part.CanCollide
				or not part.CanQuery
				or part.CanTouch
				or not part.Anchored
				or part.CastShadow
			then
				table.insert(bad, part.Name)
			end
		end
		if #bad > 0 then
			error(`{#bad} steep pieces are not invisible, solid and anchored, first: {table.concat(bad, "; ")}`, 0)
		end
	end)
end)
