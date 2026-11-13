--!strict
-- Plan 5 Task 22, Part 22-1, Step 1b (work/p5t22/22-scripts.md, "t22-legs", ruling 2): part A of the walk-area bot walk.
-- SERVER job: paste in Play after session-hold, then paste t22-legs-b. Builds the walk map, the walk area and the S, M and T
-- legs and keeps them in shared.T22Legs (items, counts, missing, area, helpers) for part B. Writes no instance.
-- Not in Play it returns "no Play:" before any require. Result also in the T22LegsAResult attribute on ReplicatedStorage.
-- Groups, in walking order: S star, M seam, T beard tip (B adds A arms, P belly pocket, O step-offs, X crossings).
local CHECK_ONLY = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
if CHECK_ONLY or not RunService:IsRunning() then
	return "no Play: nothing built (paste in Play)"
end
local requireModule: (Instance) -> any = require :: any
-- selene: allow(global_usage)
local store = shared :: any

type V3 = Vector3
type Spot = { id: number, position: V3 }
type Link = { kind: string, to: number }
type WalkMap = { spots: { [number]: Spot }, links: { [number]: { Link } }, spacing: number }
type Item = {
	n: number,
	kind: string,
	name: string,
	group: string,
	from: V3,
	to: V3,
	cross: boolean?,
	nest: string?,
	path: { V3 }?,
	back: { V3 }?,
}

local MARGIN, EDGE_BACK, STAR_MAX, SEAM_IN = 10, 1, 90, 1.5 -- studs
local REACH_FRACTION, WAIT_SECONDS, WALK = 0.75, 40, "Workspace.World.WalkSurfaces."
local NOT_WALK: { [string]: boolean } = { Slide = true, Climb = true, Jump = true, Drop = true }
local PATHS = [[
Workspace.World.Giant Workspace.World.WalkSurfaces Workspace.World.LandingSpots Workspace.World.Route
Workspace.World.EggSpots Workspace.World.Seam.Stitches Workspace.World.CuffWalk
Workspace.World.WalkSurfaces.BootRamp.Ramp_Walk Workspace.World.WalkSurfaces.RightBootRamp.Ramp_Walk
ServerScriptService.Server.World.PathCheck ServerScriptService.Server.World.WorldIndex
ServerScriptService.Server.Giant.Zones ReplicatedStorage.Shared.Config
]]

local function at(path: string): Instance?
	local node: Instance? = game
	for name in string.gmatch(path, "[^%.]+") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	return node
end

local function job(): string
	local started = os.clock()
	local lost: { string } = {}
	for path in string.gmatch(PATHS, "%S+") do
		if at(path) == nil then
			table.insert(lost, path)
		end
	end
	if #lost > 0 then
		return `FIRED lookups: missing {table.concat(lost, ", ")}`
	end
	local giant = at("Workspace.World.Giant") :: Model
	local landings = (at("Workspace.World.LandingSpots") :: Instance):GetChildren()
	local route, eggSpots = at("Workspace.World.Route") :: Instance, at("Workspace.World.EggSpots") :: Instance
	local stitches, cuffWalk =
		at("Workspace.World.Seam.Stitches") :: Instance, at("Workspace.World.CuffWalk") :: Instance
	local PathCheck = requireModule(at("ServerScriptService.Server.World.PathCheck") :: Instance)
	local WorldIndex = requireModule(at("ServerScriptService.Server.World.WorldIndex") :: Instance)
	local Zones = requireModule(at("ServerScriptService.Server.Giant.Zones") :: Instance)
	local configModule = at("ReplicatedStorage.Shared.Config") :: Instance
	local Config = requireModule(configModule:Clone()) -- Edit cache: a clone
	local zoneBoxes = WorldIndex.loadZones(Workspace.World)

	-- The walk map's area, as server.luau (the giant's box and the landing spots, plus a margin).
	local boxCFrame, boxSize = giant:GetBoundingBox()
	local low, high = boxCFrame.Position - boxSize / 2, boxCFrame.Position + boxSize / 2
	local minX, minZ, maxX, maxZ, bottom = low.X, low.Z, high.X, high.Z, low.Y
	for _, landing in landings do
		if landing:IsA("PVInstance") then
			local p = landing:GetPivot().Position
			minX, maxX, bottom = math.min(minX, p.X), math.max(maxX, p.X), math.min(bottom, p.Y)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
	end
	local pathOptions = PathCheck.defaults(Workspace)
	pathOptions.boxIgnores = { at(WALK .. "BootRamp.Ramp_Walk"), at(WALK .. "RightBootRamp.Ramp_Walk") }
	local area = {
		min = Vector3.new(minX - MARGIN, bottom - 5, minZ - MARGIN),
		max = Vector3.new(maxX + MARGIN, high.Y + 5, maxZ + MARGIN),
	}
	local map = PathCheck.buildMap(pathOptions, area) :: WalkMap
	PathCheck.cleanup(pathOptions)

	-- The walk area: a flood over walk links from the start nest's spots, kept to the Belly zone (as WalkAreaFacts).
	local startNest = Config.Nests.RareEggOne :: string
	local center = (eggSpots:FindFirstChild(startNest) :: PVInstance):GetPivot().Position
	local mirror = Vector3.new(-center.X, center.Y, center.Z)
	local seen: { [number]: boolean } = {}
	local areaList: { Spot } = {}
	for _, spot in map.spots do
		local near = math.min((spot.position - center).Magnitude, (spot.position - mirror).Magnitude)
		if near <= 2 * map.spacing then
			seen[spot.id] = true
			table.insert(areaList, spot)
		end
	end
	local head = 1
	while head <= #areaList do
		local spot = areaList[head]
		head += 1
		local out: { Link }? = map.links[spot.id]
		if out ~= nil then
			for _, link in out do
				local target = map.spots[link.to]
				if
					not NOT_WALK[link.kind]
					and not seen[link.to]
					and Zones.zoneAt(target.position, zoneBoxes) == "Belly"
				then
					seen[link.to] = true
					table.insert(areaList, target)
				end
			end
		end
		if head % 4000 == 0 then
			task.wait()
		end
	end
	local reach = REACH_FRACTION * map.spacing
	local cells: { [string]: { Spot } } = {}
	for _, spot in areaList do
		local key = `{math.floor(spot.position.X / map.spacing)},{math.floor(spot.position.Z / map.spacing)}`
		cells[key] = cells[key] or {}
		table.insert(cells[key], spot)
	end
	local NONE: { Spot } = {}
	-- The area spot nearest to (x, z) within reach, preferring one near refY; nil when the area has none there.
	local function nearest(x: number, z: number, refY: number?): Spot?
		local best: Spot? = nil
		local bestScore = math.huge
		local cx, cz = math.floor(x / map.spacing), math.floor(z / map.spacing)
		for dx = -1, 1 do
			for dz = -1, 1 do
				for _, spot in cells[`{cx + dx},{cz + dz}`] or NONE do
					local flat = Vector3.new(spot.position.X - x, 0, spot.position.Z - z).Magnitude
					local score = flat + (if refY ~= nil then math.abs(spot.position.Y - refY) * 2 else 0)
					if flat <= reach and score < bestScore then
						best, bestScore = spot, score
					end
				end
			end
		end
		return best
	end
	-- The area spot with the lowest `cost` (a function of the spot), over the whole area.
	local function cheapest(cost: (Spot) -> number): Spot?
		local best: Spot? = nil
		local bestCost = math.huge
		for _, spot in areaList do
			local c = cost(spot)
			if c < bestCost then
				best, bestCost = spot, c
			end
		end
		return best
	end

	local items: { Item } = {}
	local counts: { [string]: number } = { S = 0, M = 0, T = 0, A = 0, P = 0, O = 0, X = 0 }
	local missing: { string } = {}
	local function add(group: string, kind: string, name: string, from: V3, to: V3): Item
		local item: Item = { n = #items + 1, kind = kind, name = name, group = group, from = from, to = to }
		table.insert(items, item)
		counts[group] += 1
		return item
	end
	local rays = RaycastParams.new()
	local function pointOf(name: string): V3?
		local part = route:FindFirstChild("RoutePoint_" .. name)
		if part == nil or not part:IsA("BasePart") then
			table.insert(missing, name)
			return nil
		end
		return part.Position
	end
	local function floorUnder(part: Instance?, name: string): V3?
		if part == nil or not part:IsA("BasePart") then
			table.insert(missing, name)
			return nil
		end
		local p = part.Position
		local hit = Workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), rays)
		return if hit ~= nil then hit.Position else p
	end

	-- S: 8 legs from Rare egg 1's nest outward every 45 degrees, to 1 stud inside the area's edge.
	local startSpot = nearest(center.X, center.Z, center.Y)
	local origin = if startSpot ~= nil then startSpot.position else center
	for deg = 0, 315, 45 do
		local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
		local reached: { Spot } = {}
		local y = origin.Y
		for d = 1, STAR_MAX do
			local spot = nearest(origin.X + dir.X * d, origin.Z + dir.Z * d, y)
			if spot == nil then
				break
			end
			y = spot.position.Y
			reached[d] = spot
		end
		local last = reached[math.max(#reached - EDGE_BACK, 1)]
		add("S", "up", `Star {deg} degrees`, origin, if last ~= nil then last.position else origin)
	end

	-- M: one leg along each half of the seam, SEAM_IN studs toward the middle of the stitch points, y from a down ray.
	for _, side in { -1, 1 } do
		local points: { V3 } = {}
		for _, part in stitches:GetDescendants() do
			if part:IsA("BasePart") and math.sign(part.Position.X) == side then
				local x = part.Position.X - side * SEAM_IN
				local hit = Workspace:Raycast(
					Vector3.new(x, part.Position.Y + 4, part.Position.Z),
					Vector3.new(0, -10, 0),
					rays
				)
				table.insert(
					points,
					Vector3.new(x, if hit ~= nil then hit.Position.Y else part.Position.Y, part.Position.Z)
				)
			end
		end
		table.sort(points, function(a, b)
			return a.Z < b.Z
		end)
		local half = if side < 0 then "left" else "right"
		if #points < 2 then
			table.insert(missing, `{half} stitches`)
			add("M", "up", `Seam {half}`, origin, origin)
		else
			add("M", "up", `Seam {half}`, points[1], points[#points])
		end
	end

	-- T: from the belly top to the area spot under the beard tip (flat (0, -14), belly height 60 to 70), and back.
	local top = pointOf("Belly_4")
	local topSpot = if top ~= nil then nearest(top.X, top.Z, top.Y) else nil
	local belly = if topSpot ~= nil then topSpot.position else origin
	local tip = cheapest(function(spot)
		return Vector3.new(spot.position.X, 0, spot.position.Z + 14).Magnitude
			+ (if spot.position.Y < 60 or spot.position.Y > 70 then 1000 else 0)
	end)
	local tipAt = if tip ~= nil then tip.position else origin
	add("T", "up", "Beard tip out", belly, tipAt)
	add("T", "down", "Beard tip back", tipAt, belly)

	store.T22Legs = {
		items = items,
		counts = counts,
		missing = missing,
		area = area,
		areaList = areaList,
		nearest = nearest,
		cheapest = cheapest,
		add = add,
		cleanup = function()
			PathCheck.cleanup(pathOptions)
		end,
		pathOptions = pathOptions,
		origin = origin,
		started = started,
		belly = belly,
		rays = rays,
		pointOf = pointOf,
		floorUnder = floorUnder,
		route = route,
		eggSpots = eggSpots,
		cuffWalk = cuffWalk,
	}
	local line = `S {counts.S}, M {counts.M}, T {counts.T}`
	return `t22-legs-a done: {line}; area {#areaList} spots, {string.format("%.0f", os.clock() - started)} s`
		.. (if #missing > 0 then `; missing {table.concat(missing, " | ")}` else "")
		.. "; stored in shared.T22Legs, paste t22-legs-b next"
end

local box: { result: string? } = { result = nil }
task.spawn(function()
	local ok, outcome = pcall(job)
	box.result = if ok then tostring(outcome) else "FIRED job error: " .. tostring(outcome)
	ReplicatedStorage:SetAttribute("T22LegsAResult", box.result)
end)
local waitStart = os.clock()
while box.result == nil and os.clock() - waitStart < WAIT_SECONDS do
	task.wait(0.25)
end
return string.sub(box.result or "still running: fetch the T22LegsAResult attribute on ReplicatedStorage", 1, 1000)
