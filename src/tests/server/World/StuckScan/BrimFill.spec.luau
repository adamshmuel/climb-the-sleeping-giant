--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local PlayerNeeds = require(ServerStorage.Tests.server.World.PlayerNeeds)
local BrimPlaces = require(ServerStorage.Tools.world["15-real-shape"].BrimPlaces)
local WalkFacts = require(script.Parent.WalkFacts)
local LADDER_NAMES = PlayerNeeds.LADDER_NAMES

-- Stuck safety Task 54: the two hidden blocks that fill most of the crease under the cap's edge, beside the Legendary brim
-- nests. The limits are product's (work/t28/product-ruling.md, lines 187 to 192); the sizes and places come from BrimPlaces.
-- Every test is red until the blocks are in the world (the world script, section 4b).
local GAP_LIMIT = 1.0 -- studs: the most open space left under the cap's edge over a block's top
local CREASE_NEEDED = 4 -- crease points closed per side, out of 5 (it passes only if Play shows no wedge there)
local NEST_CLEARANCE = 2 -- studs: no walk-map spot on a block this close to a nest point
local GRID = { -0.5, -0.25, 0, 0.25, 0.5 } -- the block's test points, as fractions of its size on each axis
local SKY_HEIGHT = 170 -- rays down start here...
local SKY_REACH = 120 -- ...and look this far
local ROOF_REACH = 20 -- a ray up from the skin looks this far for the cap
local ROOM_NEEDED = 2 -- studs between the skin and the cap's roof for a crease point to count
local SCAN_TIMEOUT_MS = 150000

-- The measure's walk-map area (work/t54/measure-5.luau lines 161 to 178): the forehead and the cap.
local AREA_X_MIN, AREA_X_MAX, AREA_Z_MIN, AREA_Z_MAX, AREA_Y_MIN = -30, 30, -8, 42, 85

-- The crease feet points the measure checked (work/t54/measure-5.luau lines 201 to 210): label, x, y, z.
local CREASE_FEET: { { any } } = {
	{ "+W1", 11.3, 113.8, 11.9 },
	{ "+W2", 10.3, 115.1, 16.9 },
	{ "+z10", 11.6, 113.9, 10.0 },
	{ "+z14.4", 10.8, 113.7, 14.4 },
	{ "+z19", 9.9, 116.0, 19.0 },
	{ "-W1", -11.3, 113.8, 11.9 },
	{ "-W2", -10.3, 114.8, 16.9 },
	{ "-z10", -11.6, 113.9, 10.0 },
	{ "-z14.4", -10.8, 113.7, 14.4 },
	{ "-z19", -9.9, 116.0, 19.0 },
}

type Parts = {
	head: BasePart,
	cap: BasePart,
	patch: BasePart,
	ladders: { Instance },
	leaveAlone: { Instance },
	headParams: RaycastParams,
	capParams: RaycastParams,
}

type MapFacts = { map: PathCheck.WalkMap, tops: { [string]: number? } }

local function fmt(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

local function includeParams(list: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	return params
end

local function findPath(root: Instance?, names: { string }): Instance?
	local current = root
	for _, name in names do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local cachedParts: Parts? = nil

-- The parts the checks measure against (World.Giant's head and nightcap, the leave-alone parts). Fails by name if one is missing.
local function worldParts(): Parts
	if cachedParts then
		return cachedParts
	end
	local world = Workspace:FindFirstChild("World")
	local head = findPath(world, { "Giant", "head_with_beard", "head_with_beard" })
	local cap = findPath(world, { "Giant", "nightcap", "nightcap" })
	local patch = findPath(world, { "WalkSurfaces", "SmallPatches", "Patch_Forehead_1" })
	local ladders: { Instance } = {}
	for _, ladderName in LADDER_NAMES do
		local tie = findPath(world, { "WalkSurfaces", ladderName })
		if tie then
			table.insert(ladders, tie)
		end
	end
	local guardFolder = findPath(world, { "WalkSurfaces", "ForeheadGuard" })
	if not (head and cap and patch and #ladders == #LADDER_NAMES and guardFolder) then
		error("a part the brim checks measure against is missing from the world")
	end
	local leave: { Instance } = { patch }
	for _, tie in ladders do
		table.insert(leave, tie)
	end
	for _, child in guardFolder:GetChildren() do
		if child.Name == "Guard" or child.Name == "SideRail" then
			table.insert(leave, child)
		end
	end
	local parts: Parts = {
		head = head :: BasePart,
		cap = cap :: BasePart,
		patch = patch :: BasePart,
		ladders = ladders,
		leaveAlone = leave,
		headParams = includeParams({ head }),
		capParams = includeParams({ cap }),
	}
	cachedParts = parts
	return parts
end

local function getBlock(name: string): BasePart
	local found = findPath(Workspace:FindFirstChild("World"), { "WalkSurfaces", name })
	if found == nil or not found:IsA("BasePart") then
		error("no " .. name .. " in World.WalkSurfaces yet")
	end
	return found
end

local function skinY(parts: Parts, x: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, SKY_HEIGHT, z), Vector3.new(0, -SKY_REACH, 0), parts.headParams)
	return hit and hit.Position.Y
end

local function capTopY(parts: Parts, x: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, SKY_HEIGHT, z), Vector3.new(0, -SKY_REACH, 0), parts.capParams)
	return hit and hit.Position.Y
end

local function roofY(parts: Parts, x: number, y: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, ROOF_REACH, 0), parts.capParams)
	return hit and hit.Position.Y
end

local function inside(point: Vector3, size: Vector3): boolean
	return math.abs(point.X) <= size.X / 2 + 1e-3
		and math.abs(point.Y) <= size.Y / 2 + 1e-3
		and math.abs(point.Z) <= size.Z / 2 + 1e-3
end

local function sameCFrame(a: CFrame, b: CFrame, tolerance: number): boolean
	local first, second = { a:GetComponents() }, { b:GetComponents() }
	for index = 1, 12 do
		if math.abs(first[index] - second[index]) > tolerance then
			return false
		end
	end
	return true
end

type BlockScan = { topBad: { string }, bottomBad: { string }, airBad: { string }, maxGap: number, maxGapAt: string }

-- The measure's geometry check (measure-5.luau lines 355 to 401) on a 5 x 5 x 5 grid of points through the block.
local function scanBlock(parts: Parts, block: BasePart): BlockScan
	local scan: BlockScan = { topBad = {}, bottomBad = {}, airBad = {}, maxGap = 0, maxGapAt = "none" }
	local cf, size = block.CFrame, block.Size
	for _, fx in GRID do
		for _, fy in GRID do
			for _, fz in GRID do
				local p = cf:PointToWorldSpace(Vector3.new(fx * size.X, fy * size.Y, fz * size.Z))
				local label = string.format("%s at (%g, %g, %g) of the block", fmt(p), fx, fy, fz)
				local skin = skinY(parts, p.X, p.Z)
				local capTop = capTopY(parts, p.X, p.Z)
				if fy == 0.5 then
					if capTop == nil or capTop < p.Y + 0.1 then
						table.insert(scan.topBad, label .. ": the cap is not over it")
					end
					local from = p - Vector3.new(0, 2, 0)
					local hit = Workspace:Raycast(from, Vector3.new(0, 12, 0), parts.capParams)
					local gap = if hit then math.max(0, hit.Position.Y - from.Y - 2) else 99
					if gap > scan.maxGap then
						scan.maxGap, scan.maxGapAt = gap, label
					end
				end
				if fy == -0.5 and (skin == nil or p.Y > skin) then
					table.insert(scan.bottomBad, label .. ": not sunk into his skin")
				end
				if (skin == nil or p.Y > skin + 0.05) and (capTop == nil or capTop < p.Y) then
					table.insert(scan.airBad, label .. ": in open air")
				end
			end
		end
	end
	return scan
end

local function reach(map: PathCheck.WalkMap, starts: { number }, allowClimb: boolean): { [number]: boolean }
	local seen: { [number]: boolean } = {}
	local queue: { number } = {}
	for _, id in starts do
		if not seen[id] then
			seen[id] = true
			table.insert(queue, id)
		end
	end
	local index = 1
	while index <= #queue do
		local id = queue[index]
		index += 1
		local links: { PathCheck.Link } = map.links[id] or {}
		for _, link in links do
			if (allowClimb or link.kind ~= "Climb") and not seen[link.to] then
				seen[link.to] = true
				table.insert(queue, link.to)
			end
		end
	end
	return seen
end

local function spotsOn(map: PathCheck.WalkMap, part: BasePart): { PathCheck.Spot }
	local found: { PathCheck.Spot } = {}
	for _, spot in map.spots do
		if spot.standsOn == part then
			table.insert(found, spot)
		end
	end
	return found
end

local function mapArea(world: Instance): PathCheck.Area
	local giant = (world :: any).Giant :: Model
	local boxCFrame, boxSize = giant:GetBoundingBox()
	local low, high = boxCFrame.Position - boxSize / 2, boxCFrame.Position + boxSize / 2
	local minX, minZ = low.X, low.Z
	for _, landing in WorldIndex.loadLandingSpots(world) do
		minX = math.min(minX, landing.position.X)
		minZ = math.min(minZ, landing.position.Z)
	end
	local spacing = Config.Stuck.ScanSpacing
	local originX, originZ = minX - Config.Stuck.ScanMargin, minZ - Config.Stuck.ScanMargin
	return {
		min = Vector3.new(
			originX + spacing * math.floor((AREA_X_MIN - originX) / spacing),
			AREA_Y_MIN,
			originZ + spacing * math.floor((AREA_Z_MIN - originZ) / spacing)
		),
		max = Vector3.new(AREA_X_MAX, high.Y + 5, AREA_Z_MAX),
	}
end

describe("the hidden brim blocks", function()
	-- Tests 6 to 9 share one walk map, built once. With a block missing there is nothing to measure, so the map is not built.
	local facts: MapFacts? = nil

	beforeAll(function()
		local world = Workspace:FindFirstChild("World")
		if world == nil then
			return
		end
		for _, place in BrimPlaces.BLOCKS do
			if findPath(world, { "WalkSurfaces", place.name }) == nil then
				return
			end
		end
		local options = PathCheck.defaults(Workspace)
		options.boxIgnores = {
			(world :: any).WalkSurfaces.BootRamp.Ramp_Walk,
			(world :: any).WalkSurfaces.RightBootRamp.Ramp_Walk,
		}
		local map = PathCheck.buildMap(options, mapArea(world))
		local tops: { [string]: number? } = {}
		for _, ladderName in LADDER_NAMES do
			local _, top = WalkFacts.ladderEndSpots(ladderName, map, world)
			tops[ladderName] = top
		end
		facts = { map = map, tops = tops }
	end, SCAN_TIMEOUT_MS)

	-- Throws "no BrimFill_..." while a block is missing, so a missing block is the only reason these tests are red.
	local function needFacts(): MapFacts
		for _, place in BrimPlaces.BLOCKS do
			getBlock(place.name)
		end
		if facts == nil then
			error("the walk map was not built")
		end
		return facts
	end

	it("puts both brim blocks in World.WalkSurfaces at their recorded places, invisible and solid", function()
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			local block = getBlock(place.name)
			local walkSurfaces = (Workspace :: any).World.WalkSurfaces
			local count = 0
			for _, child in walkSurfaces:GetChildren() do
				if child.Name == place.name then
					count += 1
				end
			end
			local tolerance = BrimPlaces.POSITION_TOLERANCE
			if count ~= 1 then
				table.insert(problems, place.name .. ": " .. count .. " of 1 in World.WalkSurfaces")
			end
			if (block.Size - place.size).Magnitude > tolerance then
				table.insert(problems, place.name .. ": size " .. fmt(block.Size) .. " is not " .. fmt(place.size))
			end
			if not sameCFrame(block.CFrame, place.cframe, tolerance) then
				table.insert(
					problems,
					place.name .. ": place " .. fmt(block.Position) .. " is not " .. fmt(place.cframe.Position)
				)
			end
			if
				block.Transparency ~= 1
				or not block.Anchored
				or not block.CanCollide
				or not block.CanQuery
				or block.CanTouch
			then
				table.insert(
					problems,
					place.name .. ": must be invisible, anchored, collide on, query on and touch off"
				)
			end
		end
		expect(problems).toEqual({})
	end)

	it("hides each brim block: the top under the cap, the bottom sunk into his skin, no point in open air", function()
		local parts = worldParts()
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			local scan = scanBlock(parts, getBlock(place.name))
			for _, list in { scan.topBad, scan.bottomBad, scan.airBad } do
				for _, line in list do
					table.insert(problems, place.name .. " " .. line)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("leaves a gap of at most 1.0 stud under the cap's edge over each block's top", function()
		local parts = worldParts()
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			local scan = scanBlock(parts, getBlock(place.name))
			if scan.maxGap > GAP_LIMIT then
				table.insert(
					problems,
					string.format("%s: gap %.2f studs at %s", place.name, scan.maxGap, scan.maxGapAt)
				)
			end
		end
		expect(problems).toEqual({})
	end)

	it("closes at least 4 of 5 crease points on each side, and names every open point", function()
		local parts = worldParts()
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			local block = getBlock(place.name)
			local closed, total = 0, 0
			local open: { string } = {}
			for _, feet in CREASE_FEET do
				local x, y, z = feet[2] :: number, feet[3] :: number, feet[4] :: number
				if (if x > 0 then 1 else -1) == place.side then
					total += 1
					local skin = skinY(parts, x, z)
					local roof = if skin then roofY(parts, x, skin + 0.05, z) else nil
					if skin == nil or roof == nil or roof - skin < ROOM_NEEDED then
						table.insert(
							open,
							string.format("%s %s: no skin or no roof over it", feet[1], fmt(Vector3.new(x, y, z)))
						)
					else
						local low = Vector3.new(x, skin + 1, z)
						local mid = Vector3.new(x, (skin + roof) / 2, z)
						local lowIn = inside(block.CFrame:PointToObjectSpace(low), block.Size)
						local midIn = inside(block.CFrame:PointToObjectSpace(mid), block.Size)
						if lowIn and midIn then
							closed += 1
						else
							local missed = if not lowIn and not midIn
								then "low and middle"
								elseif not lowIn then "low"
								else "middle"
							table.insert(
								open,
								string.format(
									"%s %s: the %s test point missed",
									feet[1],
									fmt(Vector3.new(x, y, z)),
									missed
								)
							)
						end
					end
				end
			end
			if #open > 0 then
				print(
					string.format(
						"%s: %d of %d crease points closed; open: %s",
						place.name,
						closed,
						total,
						table.concat(open, "; ")
					)
				)
			end
			if closed < CREASE_NEEDED then
				table.insert(
					problems,
					string.format("%s: %d of %d closed; open: %s", place.name, closed, total, table.concat(open, "; "))
				)
			end
		end
		expect(problems).toEqual({})
	end)

	it("overlaps none of the leave-alone parts (guards, side rails, cap ladder, forehead patch)", function()
		local parts = worldParts()
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Include
		overlap.FilterDescendantsInstances = parts.leaveAlone
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			for _, hit in Workspace:GetPartsInPart(getBlock(place.name), overlap) do
				table.insert(problems, place.name .. " overlaps " .. hit:GetFullName())
			end
		end
		expect(problems).toEqual({})
	end)

	it("still reaches the brim nests from each cap tie's top, and every side nest too", function()
		local found = needFacts()
		local problems: { string } = {}
		for _, ladderName in LADDER_NAMES do
			local top = found.tops[ladderName]
			for _, nest in PlayerNeeds.NESTS do
				local near = WalkFacts.spotsNearNest(nest.position, found.map)
				if top == nil then
					table.insert(problems, `{nest.name}: the {ladderName} top has no walk-map spot`)
				elseif #near == 0 then
					table.insert(problems, nest.name .. ": no walk-map spot near it")
				elseif not WalkFacts.canWalk(top, near, found.map) then
					table.insert(problems, `{nest.name}: not reached on foot from the {ladderName} top`)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("puts no walk-map spot on a brim block within 2 studs of a nest point", function()
		local found = needFacts()
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			for _, spot in spotsOn(found.map, getBlock(place.name)) do
				for _, nest in PlayerNeeds.NESTS do
					local distance = (spot.position - nest.position).Magnitude
					if distance <= NEST_CLEARANCE then
						table.insert(
							problems,
							string.format(
								"%s: spot %s is %.2f studs from the %s",
								place.name,
								fmt(spot.position),
								distance,
								nest.name
							)
						)
					end
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("gives every walk-map spot on a brim block a way out onto the cap, the head or the forehead patch", function()
		local found = needFacts()
		local parts = worldParts()
		local exits: { [Instance]: boolean } = { [parts.cap] = true, [parts.head] = true, [parts.patch] = true }
		local problems: { string } = {}
		for _, place in BrimPlaces.BLOCKS do
			for _, spot in spotsOn(found.map, getBlock(place.name)) do
				local seen = reach(found.map, { spot.id }, true)
				local out = false
				for id in seen do
					if exits[found.map.spots[id].standsOn] then
						out = true
						break
					end
				end
				if not out then
					table.insert(problems, place.name .. ": no way out from the spot at " .. fmt(spot.position))
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("adds no cap spot that can be walked to from the forehead (Rule 82)", function()
		local found = needFacts()
		local parts = worldParts()
		local starts: { number } = {}
		for _, spot in found.map.spots do
			if spot.standsOn == parts.head or spot.standsOn == parts.patch then
				table.insert(starts, spot.id)
			end
		end
		local problems: { string } = {}
		for id in reach(found.map, starts, false) do
			local spot = found.map.spots[id]
			if spot.standsOn == parts.cap then
				table.insert(problems, "a cap spot at " .. fmt(spot.position) .. " is reached from the forehead")
			end
		end
		expect(problems).toEqual({})
	end)
end)
