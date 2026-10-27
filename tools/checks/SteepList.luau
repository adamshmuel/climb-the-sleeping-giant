--!strict
-- The steep list (stuck safety Task 45, step 1): every spot on the walk map where a player could slide or hang, as data.
-- Steep: a spot on the giant's cloth that leans 45 degrees or more. Wall: a flatter cloth spot with a face leaning more
-- than the walking limit within 2 studs. Guard: the top middle of each slide guard. Pure given its inputs; the only
-- world it reads is the one the giant lives in, through rays.
export type Spot = { position: Vector3, up: Vector3, standsOn: BasePart }
export type Entry = { kind: "guard" | "steep" | "wall", position: Vector3, slope: number }
export type Counts = { cloth: number, steep: number, wall: number, guards: number, total: number }
export type Options = { giant: Instance, guards: { BasePart }, climbLimit: number, rayParams: RaycastParams }

local CLOTH_NAME = "body_and_cushion"
local STEEP_FROM = 45 -- degrees
-- Rays and Vector3 are 32-bit, so a 45 degree `up` comes back as 44.99999 degrees; a thousandth of a degree covers that.
local EPSILON = 1e-3
local RAY_DIRECTIONS = 8
local RAY_DISTANCES = { 1, 2 } -- studs out from the spot
local RAY_ABOVE = 2
local RAY_LENGTH = 7 -- so the ray ends 5 below the spot

local SteepList = {}

-- Degrees between a direction and straight up.
local function slopeOf(direction: Vector3): number
	return math.deg(math.acos(math.clamp(direction.Unit.Y, -1, 1)))
end

-- The steepest face under the 16 rays round a spot, in degrees (0 when nothing is hit).
local function steepestAround(world: WorldRoot, position: Vector3, rayParams: RaycastParams): number
	local steepest = 0
	local down = Vector3.new(0, -RAY_LENGTH, 0)
	for step = 0, RAY_DIRECTIONS - 1 do
		local angle = math.rad(step * 360 / RAY_DIRECTIONS)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		for _, distance in RAY_DISTANCES do
			local origin = position + direction * distance + Vector3.new(0, RAY_ABOVE, 0)
			local hit = world:Raycast(origin, down, rayParams)
			if hit then
				steepest = math.max(steepest, slopeOf(hit.Normal))
			end
		end
	end
	return steepest
end

local function roundedSlope(entry: Entry): number
	return math.floor(entry.slope / EPSILON + 0.5)
end

function SteepList.build(spots: { Spot }, options: Options): { list: { Entry }, counts: Counts }
	local world = options.giant:FindFirstAncestorWhichIsA("WorldRoot") or game:GetService("Workspace")
	local counts: Counts = { cloth = 0, steep = 0, wall = 0, guards = 0, total = 0 }
	local others: { Entry } = {}

	for _, spot in spots do
		if spot.standsOn.Name == CLOTH_NAME and spot.standsOn:IsDescendantOf(options.giant) then
			counts.cloth += 1
			local slope = slopeOf(spot.up)
			if slope >= STEEP_FROM - EPSILON then
				counts.steep += 1
				table.insert(others, { kind = "steep", position = spot.position, slope = slope })
			else
				local around = steepestAround(world, spot.position, options.rayParams)
				if around > options.climbLimit then
					counts.wall += 1
					table.insert(others, { kind = "wall", position = spot.position, slope = around })
				end
			end
		end
	end

	table.sort(others, function(a: Entry, b: Entry): boolean
		local slopeA, slopeB = roundedSlope(a), roundedSlope(b)
		if slopeA ~= slopeB then
			return slopeA > slopeB
		end
		if a.position.X ~= b.position.X then
			return a.position.X < b.position.X
		end
		return a.position.Z < b.position.Z
	end)

	local guards = table.clone(options.guards)
	table.sort(guards, function(a: BasePart, b: BasePart): boolean
		return a.Name < b.Name
	end)
	local list: { Entry } = {}
	for _, guard in guards do
		table.insert(
			list,
			{ kind = "guard", position = (guard.CFrame * Vector3.new(0, guard.Size.Y / 2, 0)), slope = 0 }
		)
	end
	counts.guards = #guards
	for _, entry in others do
		table.insert(list, entry)
	end
	counts.total = #list
	return { list = list, counts = counts }
end

return SteepList
