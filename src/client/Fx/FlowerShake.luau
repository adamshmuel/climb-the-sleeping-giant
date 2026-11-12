--!strict
-- The flowers shake (spec 6, Rule 69 "The world reacts", section 5 "Flower shake"): when a hand slam lands, every flower
-- whose middle is inside the slam circle tips away from the landing about its base and wobbles back in 0.5 s. A flower
-- outside the circle never moves. Reduce Motion is ignored on purpose (the spec says so). Each device does this for itself
-- from the same SlamLanded remote SlamFx listens to; nothing here goes to the server.
--
-- A flower is any Model with the attribute ShakesOnSlam == true (marked by the world build). The flowers near a landing are
-- found with a part search (streaming adds and removes parts, so nothing is cached); each hit part walks up to its marked
-- Model. A second slam on a flower that is still shaking starts again from the first start pivot, so a flower always ends
-- exactly where it began.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Config = require(ReplicatedStorage.Shared.Config)
local SpotLabels = require(script.Parent.Parent.World.SpotLabels)

local FlowerShake = {}

-- The designer's start values (spec 6 table, "Flower shake"): the first tip, how long until it peaks, how long it all takes.
FlowerShake.PEAK_DEGREES = 12
FlowerShake.PEAK_SECONDS = 0.08
FlowerShake.SHAKE_SECONDS = 0.5
-- The two smaller wobbles back: (seconds, degrees). Before the first peak the angle rises from 0; after the last it falls to 0.
local WOBBLES: { { number } } = { { 0.2, -6 }, { 0.33, 3 } }
-- The part search reaches this much past the circle, only to find flowers whose parts stick out; the circle test decides.
local SEARCH_MARGIN = 4
local MARK = "ShakesOnSlam"
local UP = Vector3.yAxis
-- A flower closer than this (flat) to the landing has no side to lean away from, so it leans toward +X.
local NO_SIDE_STUDS = 1e-4

export type PartsNear = (point: Vector3, radius: number) -> { BasePart }

export type Deps = {
	slamLanded: { OnClientEvent: SpotLabels.SignalLike }, -- (slam number, the point)
	step: SpotLabels.SignalLike, -- once per frame (RunService.RenderStepped)
	now: () -> number, -- a clock in seconds
	partsNear: PartsNear, -- the parts within a radius of a point (the real one is workspace:GetPartBoundsInRadius)
}

export type Handle = { destroy: () -> () }

-- Smooth from one key to the next (slow at both ends), so every key is a true peak or a true zero.
local function ease(alpha: number): number
	return (1 - math.cos(math.pi * alpha)) / 2
end

-- The tip in degrees `seconds` after the landing: 0 at 0, the peak at PEAK_SECONDS, two smaller wobbles back (opposite side,
-- then the same side again), and exactly 0 from SHAKE_SECONDS on.
function FlowerShake.angle(seconds: number): number
	if seconds <= 0 or seconds >= FlowerShake.SHAKE_SECONDS then
		return 0
	end
	local keys: { { number } } = { { 0, 0 }, { FlowerShake.PEAK_SECONDS, FlowerShake.PEAK_DEGREES } }
	for _, wobble in WOBBLES do
		table.insert(keys, wobble)
	end
	table.insert(keys, { FlowerShake.SHAKE_SECONDS, 0 })
	for i = 1, #keys - 1 do
		local from, to = keys[i], keys[i + 1]
		if seconds < to[1] then
			return from[2] + (to[2] - from[2]) * ease((seconds - from[1]) / (to[1] - from[1]))
		end
	end
	return 0
end

-- The start pivot tipped by `degrees` about the base point. The axis lies flat, at right angles to the line from the centre
-- to the base, so a positive angle leans away from the centre. At 0 degrees it is the start pivot itself.
function FlowerShake.pose(startPivot: CFrame, base: Vector3, centre: Vector3, degrees: number): CFrame
	if degrees == 0 then
		return startPivot
	end
	local away = Vector3.new(base.X - centre.X, 0, base.Z - centre.Z)
	away = if away.Magnitude < NO_SIDE_STUDS then Vector3.xAxis else away.Unit
	local axis = UP:Cross(away)
	return CFrame.new(base) * CFrame.fromAxisAngle(axis, math.rad(degrees)) * CFrame.new(-base) * startPivot
end

-- The marked flower a part belongs to: its nearest ancestor that is a Model with ShakesOnSlam == true.
local function flowerOf(part: Instance): Model?
	local node: Instance? = part.Parent
	while node ~= nil do
		if node:IsA("Model") and node:GetAttribute(MARK) == true then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Every marked flower with a part within `searchRadius` of `point`, each one once.
function FlowerShake.find(partsNear: PartsNear, point: Vector3, searchRadius: number): { Model }
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in partsNear(point, searchRadius) do
		local flower = flowerOf(part)
		if flower ~= nil and not seen[flower] then
			seen[flower] = true
			table.insert(found, flower)
		end
	end
	return found
end

-- One flower that is shaking now.
type Shake = { startPivot: CFrame, base: Vector3, centre: Vector3, startedAt: number }

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The middle of the flower's bottom face (its bounding box).
local function baseOf(flower: Model): Vector3
	local box, size = flower:GetBoundingBox()
	return box.Position - box.UpVector * (size.Y / 2)
end

function FlowerShake.start(deps: Deps): Handle
	local trove = Trove.new()
	local radius = Config.Wake.SlamCircleDiameter / 2
	local shaking: { [Model]: Shake } = {}
	local stepConnection: SpotLabels.ConnectionLike? = nil

	local function stopStepping()
		if stepConnection ~= nil then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end

	local function onStep()
		local now = deps.now()
		for flower, shake in shaking do
			if flower.Parent == nil then
				shaking[flower] = nil
			else
				local seconds = now - shake.startedAt
				if seconds >= FlowerShake.SHAKE_SECONDS then
					flower:PivotTo(shake.startPivot)
					shaking[flower] = nil
				else
					flower:PivotTo(
						FlowerShake.pose(shake.startPivot, shake.base, shake.centre, FlowerShake.angle(seconds))
					)
				end
			end
		end
		if next(shaking) == nil then
			stopStepping()
		end
	end

	local function onLanded(_slamNumber: any, point: any)
		if typeof(point) ~= "Vector3" then
			return
		end
		local landedAt = deps.now()
		for _, flower in FlowerShake.find(deps.partsNear, point, radius + SEARCH_MARGIN) do
			local old = shaking[flower]
			-- A flower that is still shaking starts again from where it first began, never from where it is tipped now.
			local startPivot = if old then old.startPivot else flower:GetPivot()
			if flatDistance(startPivot.Position, point) <= radius then
				shaking[flower] = {
					startPivot = startPivot,
					base = if old then old.base else baseOf(flower),
					centre = point,
					startedAt = landedAt,
				}
			end
		end
		if next(shaking) ~= nil and stepConnection == nil then
			stepConnection = deps.step:Connect(onStep)
		end
	end

	trove:Add(deps.slamLanded.OnClientEvent:Connect(onLanded))

	local function destroy()
		stopStepping()
		for flower, shake in shaking do
			if flower.Parent ~= nil then
				flower:PivotTo(shake.startPivot)
			end
		end
		table.clear(shaking)
		trove:Destroy()
	end
	return { destroy = destroy }
end

return FlowerShake
