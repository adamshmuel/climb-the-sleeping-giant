--!strict
-- The route check for the ways up the giant (plan 3, Task 9; spec 3 Rules 15, 43 and 45): a walk-and-climb route (no
-- jump, no slide) from the foot of a boot way up to Rare egg 1, through the lap landing. The route tests are in
-- OnTheGiant.spec, describe "the ways up on a route map with even rows", on their own even-row route map. The guard
-- runs on the scan map.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local WalkFacts = require(script.Parent.WalkFacts)

local LANDING_GROW = 1 -- studs: a step's spot counts as "in the lap landing" this far outside its box

-- Every piece of the climb that must lie inside the scan area, and the landing's name.
local PIECES = {
	"BootLadder_Left",
	"BootLadder_Right",
	"BootRamp",
	"RightBootRamp",
	"LapPlank_Left",
	"LapPlank_Right",
	"LapLanding",
	"LapApron",
	"BellyRamp_Left",
	"BellyRamp_Right",
}

local ALLOWED = { Walk = true, Climb = true }
local RAMPS = { BootRamp = true, RightBootRamp = true }

local WaysUpRoutes = {}

WaysUpRoutes.PIECES = PIECES

-- The box the route tests build their even-row map over: the boots, the lap, the belly, up to the nose (the ways up and
-- Rare egg 1 lie inside it; piecesOutside checks that).
WaysUpRoutes.ROUTE_AREA = { min = Vector3.new(-69, -8, -104), max = Vector3.new(69, 70, 0) } :: PathCheck.Area

-- The box the egg-reach check builds its map over: the whole giant and the meadow around him, reaching every nest. Same
-- corner parity as ROUTE_AREA (the cells line up), so a row runs along z -58, the only boot-to-lap-plank lane.
WaysUpRoutes.EGG_AREA = { min = Vector3.new(-105, -8, -104), max = Vector3.new(105, 125, 40) } :: PathCheck.Area

-- Each Config.WaysUp name to the piece in World.WalkSurfaces that is its way up, and whether that piece is a ladder.
WaysUpRoutes.PIECE_OF = {
	["Left boot ladder"] = { piece = "BootLadder_Left", isLadder = true },
	["Left ramp"] = { piece = "BootRamp", isLadder = false },
	["Right ramp"] = { piece = "RightBootRamp", isLadder = false },
	["Right boot ladder"] = { piece = "BootLadder_Right", isLadder = true },
} :: { [string]: { piece: string, isLadder: boolean } }

local function piece(world: Instance, name: string): Model?
	local surfaces = (world :: any).WalkSurfaces :: Instance
	return surfaces:FindFirstChild(name) :: Model?
end

-- The two ends of a ramp's walking plank: the ends of its longest side (the way ladderEndSpots finds a truss end).
local function rampEnds(ramp: Model): (Vector3?, Vector3?)
	local plank = ramp:FindFirstChild("Ramp_Walk") :: BasePart?
	if plank == nil then
		return nil, nil
	end
	local size = plank.Size
	local half = if size.X >= size.Y and size.X >= size.Z
		then Vector3.new(size.X / 2, 0, 0)
		elseif size.Y >= size.Z then Vector3.new(0, size.Y / 2, 0)
		else Vector3.new(0, 0, size.Z / 2)
	return plank.CFrame:PointToWorldSpace(half), plank.CFrame:PointToWorldSpace(-half)
end

-- The lower end of a ramp's walking plank.
local function rampFoot(ramp: Model): Vector3?
	local endA, endB = rampEnds(ramp)
	if endA == nil or endB == nil then
		return nil
	end
	return if endA.Y <= endB.Y then endA else endB
end

-- The walk-map spot at the foot of a way up: a ladder's by ladderEndSpots, a ramp's by its lower end.
function WaysUpRoutes.startSpot(name: string, isLadder: boolean, map: PathCheck.WalkMap, world: Instance): number?
	if isLadder then
		local foot = WalkFacts.ladderEndSpots(name, map, world)
		return foot
	end
	local ramp = piece(world, name)
	local foot = if ramp ~= nil then rampFoot(ramp) else nil
	if foot == nil then
		return nil
	end
	return PathCheck.nearestSpot(map, foot, Helpers.LADDER_REACH_STEPS * map.spacing)
end

local function insideBox(point: Vector3, boxCFrame: CFrame, boxSize: Vector3): boolean
	local local3 = boxCFrame:PointToObjectSpace(point)
	local half = boxSize / 2 + Vector3.new(LANDING_GROW, LANDING_GROW, LANDING_GROW)
	return math.abs(local3.X) <= half.X and math.abs(local3.Y) <= half.Y and math.abs(local3.Z) <= half.Z
end

-- "ok", or a message that starts with the way up's name and how many spots its walk-and-climb search reached.
function WaysUpRoutes.routeProblem(name: string, isLadder: boolean, map: PathCheck.WalkMap, world: Instance): string
	local start = WaysUpRoutes.startSpot(name, isLadder, map, world)
	if start == nil then
		return `{name}: 0 spots reached, no walk-map spot at its foot`
	end
	local nest = (world :: any).EggSpots:FindFirstChild(Config.Nests.RareEggOne) :: Model?
	local landing = piece(world, "LapLanding")
	if nest == nil or landing == nil then
		return `{name}: 0 spots reached, Rare egg 1's nest or the lap landing is missing`
	end
	local goals = WalkFacts.spotsNearNest(nest:GetPivot().Position, map)
	local searched = PathCheck.costsFrom(map, start, { allow = ALLOWED })
	local reached = 0
	for _ in searched.costs do
		reached += 1
	end
	local route = PathCheck.route(map, start, goals, { allow = ALLOWED })
	if route == nil then
		return `{name}: {reached} spots reached, no route to Rare egg 1 ({#goals} goal spots)`
	end
	local boxCFrame, boxSize = landing:GetBoundingBox()
	for _, step in route.steps do
		if insideBox(map.spots[step.to].position, boxCFrame, boxSize) then
			return "ok"
		end
	end
	return `{name}: {reached} spots reached, the route to Rare egg 1 skips the lap landing`
end

local function outsideArea(point: Vector3, area: PathCheck.Area): boolean
	return point.X < area.min.X
		or point.Y < area.min.Y
		or point.Z < area.min.Z
		or point.X > area.max.X
		or point.Y > area.max.Y
		or point.Z > area.max.Z
end

-- True when a corner of the piece's bounding box is outside `area`. A ramp is judged by the two ends of its walking
-- plank only (its box is mostly railings and air).
local function isOutside(found: Model, isRamp: boolean, area: PathCheck.Area): boolean
	if isRamp then
		local endA, endB = rampEnds(found)
		return endA == nil or endB == nil or outsideArea(endA, area) or outsideArea(endB, area)
	end
	local boxCFrame, boxSize = found:GetBoundingBox()
	local half = boxSize / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				if
					outsideArea(boxCFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)), area)
				then
					return true
				end
			end
		end
	end
	return false
end

-- The names of the climb pieces that are not inside `area` (empty when all are).
function WaysUpRoutes.piecesOutside(world: Instance, area: PathCheck.Area): { string }
	local outside: { string } = {}
	for _, name in PIECES do
		local found = piece(world, name)
		if found == nil then
			table.insert(outside, `{name} (missing)`)
		elseif isOutside(found, RAMPS[name] == true, area) then
			table.insert(outside, name)
		end
	end
	return outside
end

return WaysUpRoutes
