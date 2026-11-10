--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)
local loadRoute = Helpers.loadRoute
local realWorld = Helpers.realWorld

-- What the nest route tests share (plan 5 Task 17): the 38 nests, which of them the route reaches in 17a, and the route
-- points that name them. Route.spec and WayUpRoute.spec both read it.
local NestRoute = {}

-- Studs from a nest's route point to its prompt anchor (plan 5 Task 17, test 1).
NestRoute.ANCHOR_REACH = 8

-- The 4 cap nests: the route reaches them in Task 17c, so the tests that name them stay red until then.
function NestRoute.isCap(nestName: string): boolean
	return string.match(nestName, "^Nest_Cap") ~= nil
end

-- Every nest in World.EggSpots, in name order.
function NestRoute.nests(): { WorldIndex.EggSpot }
	local spots, problems = WorldIndex.readEggSpots(realWorld())
	expect(problems).toEqual({})
	return spots :: { WorldIndex.EggSpot }
end

-- The nests of one group: the 4 cap nests (`caps` true) or the other 34.
function NestRoute.group(caps: boolean): { WorldIndex.EggSpot }
	local picked: { WorldIndex.EggSpot } = {}
	for _, spot in NestRoute.nests() do
		if NestRoute.isCap(spot.name) == caps then
			table.insert(picked, spot)
		end
	end
	return picked
end

-- Every route point that names a target, by target name (a list, so two points on one target show up).
function NestRoute.pointsByTarget(): { [string]: { WorldIndex.RoutePoint } }
	local byTarget: { [string]: { WorldIndex.RoutePoint } } = {}
	for _, point in loadRoute() do
		if point.target then
			local list = byTarget[point.target] or {}
			byTarget[point.target] = list
			table.insert(list, point)
		end
	end
	return byTarget
end

-- The nearest point of a part's box to a point, as a distance (0 inside).
function NestRoute.boxDistance(part: BasePart, point: Vector3): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local inside = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - inside).Magnitude
end

-- The most a surface may lean and still be one a player stands on: its up-pointing normal must be above this (the
-- plan 5 Task 17 ruling, code_lead 2026-11-10).
NestRoute.STANDABLE_NORMAL_Y = 0.75
-- Studs between the rays that find the standable top, and how high above the top a player's reach starts.
NestRoute.GRID = 0.5
NestRoute.REACH_LIFT = 3

local function boxOf(instance: Instance): (Vector3, Vector3)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local function take(part: BasePart)
		local half = part.Size / 2
		local rotation = part.CFrame.Rotation
		for _, corner in
			{
				Vector3.new(half.X, half.Y, half.Z),
				Vector3.new(-half.X, half.Y, half.Z),
				Vector3.new(half.X, -half.Y, half.Z),
				Vector3.new(half.X, half.Y, -half.Z),
				Vector3.new(-half.X, -half.Y, half.Z),
				Vector3.new(-half.X, half.Y, -half.Z),
				Vector3.new(half.X, -half.Y, -half.Z),
				Vector3.new(-half.X, -half.Y, -half.Z),
			}
		do
			local at = part.Position + rotation * corner
			low = Vector3.new(math.min(low.X, at.X), math.min(low.Y, at.Y), math.min(low.Z, at.Z))
			high = Vector3.new(math.max(high.X, at.X), math.max(high.Y, at.Y), math.max(high.Z, at.Z))
		end
	end
	if instance:IsA("BasePart") then
		take(instance)
	end
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			take(part)
		end
	end
	return low, high
end

-- Every spot of the standable top of `root` (a part or a model): downward rays on a 0.5-stud grid that hit only `root`,
-- where the hit surface's normal points up past STANDABLE_NORMAL_Y. Each spot is lifted REACH_LIFT studs, the height
-- from which a player's hand reaches a prompt (plan 5 Task 17 ruling).
function NestRoute.standableTops(root: Instance): { Vector3 }
	local low, high = boxOf(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { root }
	local spots: { Vector3 } = {}
	local startY = high.Y + 5
	local length = high.Y - low.Y + 10
	local x = low.X
	while x <= high.X do
		local z = low.Z
		while z <= high.Z do
			local hit = workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -length, 0), params)
			if hit and hit.Normal.Y > NestRoute.STANDABLE_NORMAL_Y then
				table.insert(spots, hit.Position + Vector3.new(0, NestRoute.REACH_LIFT, 0))
			end
			z += NestRoute.GRID
		end
		x += NestRoute.GRID
	end
	return spots
end

-- The nearest of `spots` to `at`, in studs (math.huge with none).
function NestRoute.nearest(spots: { Vector3 }, at: Vector3): number
	local closest = math.huge
	for _, spot in spots do
		closest = math.min(closest, (spot - at).Magnitude)
	end
	return closest
end

return NestRoute
