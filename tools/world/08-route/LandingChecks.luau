--!strict
-- World prep, task 23 (split into a folder in plan 3 Task 8a): the landing-spot checks of the route script. RouteChecks
-- calls planLanding last, after the route itself is planned and checked. The checks and the order of their messages
-- are the ones the old single file had.
local Workspace = game:GetService("Workspace")

local Places = require(script.Parent.RoutePlaces)

local PLOT_COUNT = Places.PLOT_COUNT
local LANDING_SPACING = Places.LANDING_SPACING
local LANDING_REACH = Places.LANDING_REACH
local LANDING_BOX = Places.LANDING_BOX
local LANDING_BOX_LIFT = Places.LANDING_BOX_LIFT
local LANDING_MIN_NORMAL_Y = Places.LANDING_MIN_NORMAL_Y
local PROP_LANDING_CLEARANCE = Places.PROP_LANDING_CLEARANCE
local EGG_LANDING_CLEARANCE = Places.EGG_LANDING_CLEARANCE
local LADDER_FOOT_CLEARANCE = Places.LADDER_FOOT_CLEARANCE
local FLOWER_LANDING_CLEARANCE = Places.FLOWER_LANDING_CLEARANCE
local SKY_RAY_LENGTH = Places.SKY_RAY_LENGTH
local LANDING_PLACES = Places.LANDING_PLACES

export type Stem = { name: string, x: number, z: number }
export type Circle = { name: string, x: number, z: number, radius: number, top: number? }

-- What RouteChecks hands over: the world's folders, the props it found, the egg places, and its two ground helpers.
export type Context = {
	plots: Instance,
	zones: Instance,
	giant: Model,
	ladderFeet: { { name: string, position: Vector3 } }, -- the two boot ladder feet (route points tagged Ladder and WayUpFoot)
	eggPlaces: { { name: string, position: Vector3 } },
	stems: { Stem },
	circles: { Circle },
	flowerParts: { BasePart },
	groundAt: (x: number, z: number, heightHint: number, label: string) -> RaycastResult,
	flat: (vector: Vector3) -> Vector3,
	problem: (line: string) -> (), -- RouteChecks collects every line and stops once at the end
}

-- True if `point` is inside the box of `part` (a zone box or a garden volume).
local function insideBox(part: BasePart, point: Vector3): boolean
	local local_ = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

-- The distance, across the ground, from (x, z) to the nearest edge of a part (0 if it is under the part).
local function distanceToPart(part: BasePart, x: number, z: number): number
	local inside = part.CFrame:PointToObjectSpace(Vector3.new(x, part.Position.Y, z))
	local half = part.Size / 2
	return Vector3.new(math.max(math.abs(inside.X) - half.X, 0), 0, math.max(math.abs(inside.Z) - half.Z, 0)).Magnitude
end

-- Checks every landing place and returns the spots (ground tops) and the report lines about the nearest flower clumps.
-- Every failed check goes to context.problem (a line starting "landing:") and the checks go on; a missing world part stops at once.
local function planLanding(context: Context): ({ Vector3 }, { string })
	local groundAt, flat, problem = context.groundAt, context.flat, context.problem
	local eggPlaces, stems, circles, flowerParts =
		context.eggPlaces, context.stems, context.circles, context.flowerParts

	local zoneBoxes: { BasePart } = {}
	for _, child in context.zones:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(zoneBoxes, child)
		end
	end
	local gardenBoxes: { BasePart } = {}
	for index = 1, PLOT_COUNT do
		local volume = (context.plots:FindFirstChild(`Plot_{index}`) :: Instance):FindFirstChild("GardenVolume")
		if volume == nil or not volume:IsA("BasePart") then
			error(`Plot_{index} has no GardenVolume part`)
		end
		table.insert(gardenBoxes, volume)
	end
	local ladderFeet = context.ladderFeet
	if #ladderFeet ~= 2 then
		error(`landing: found {#ladderFeet} boot ladder feet in the route, not 2`)
	end
	local giantMiddle = flat(context.giant:GetPivot().Position)
	local boxParams = OverlapParams.new()
	boxParams.RespectCanCollide = true
	local landing: { Vector3 } = {}
	local flowerReport: { string } = {}
	for number, place in LANDING_PLACES do
		local label = `LandingSpot_{number}`
		local ground = groundAt(place[1], place[2], 2, label)
		if ground.Instance ~= Workspace.Terrain then
			problem(`landing: {label}: not on the grass (found {ground.Instance:GetFullName()})`)
		end
		if ground.Normal.Y < LANDING_MIN_NORMAL_Y then
			problem(`landing: {label}: the grass is not flat enough here`)
		end
		local spot = ground.Position
		for _, height in { 0, 3 } do -- its feet and its root
			local probe = spot + Vector3.new(0, height, 0)
			for _, box in zoneBoxes do
				if insideBox(box, probe) then
					problem(`landing: {label}: inside the zone box {box.Name}, so not Meadow`)
				end
			end
			for _, box in gardenBoxes do
				if insideBox(box, probe) then
					problem(`landing: {label}: inside a garden ({box.Parent and box.Parent.Name})`)
				end
			end
		end
		local boxCFrame = CFrame.new(spot + Vector3.new(0, LANDING_BOX_LIFT + LANDING_BOX.Y / 2, 0))
		local touching = Workspace:GetPartBoundsInBox(boxCFrame, LANDING_BOX, boxParams)
		if #touching > 0 then
			problem(`landing: {label}: a standing player would touch {touching[1]:GetFullName()}`)
		end
		if (flat(spot) - giantMiddle).Magnitude > LANDING_REACH then
			problem(`landing: {label}: more than {LANDING_REACH} studs from the giant's middle`)
		end
		for _, foot in ladderFeet do
			local distance = (flat(spot) - flat(foot.position)).Magnitude
			if distance < LADDER_FOOT_CLEARANCE then
				problem(
					`landing: {label}: only {string.format("%.1f", distance)} studs from the ladder foot {foot.name} (the least is {LADDER_FOOT_CLEARANCE})`
				)
			end
		end
		for other, otherSpot in landing do
			if (flat(spot) - flat(otherSpot)).Magnitude < LANDING_SPACING then
				problem(`landing: {label} is closer than {LANDING_SPACING} studs to LandingSpot_{other}`)
			end
		end
		if Workspace:Raycast(spot + Vector3.new(0, LANDING_BOX_LIFT, 0), Vector3.new(0, SKY_RAY_LENGTH, 0)) then
			problem(`landing: {label}: something is over it (no open sky)`)
		end
		for _, egg in eggPlaces do
			local distance = (flat(spot) - flat(egg.position)).Magnitude
			if distance < EGG_LANDING_CLEARANCE then
				problem(
					`landing: {label}: only {string.format("%.1f", distance)} studs from {egg.name} (the least is {EGG_LANDING_CLEARANCE})`
				)
			end
		end
		for _, stem in stems do
			local distance = (flat(spot) - Vector3.new(stem.x, 0, stem.z)).Magnitude
			if distance < PROP_LANDING_CLEARANCE then
				problem(
					string.format(
						"landing: %s: only %.1f studs from a sunflower stem at (%.1f, %.1f) (the least is %g)",
						label,
						distance,
						stem.x,
						stem.z,
						PROP_LANDING_CLEARANCE
					)
				)
			end
		end
		for _, circle in circles do
			local gap = (flat(spot) - Vector3.new(circle.x, 0, circle.z)).Magnitude - circle.radius
			if gap < PROP_LANDING_CLEARANCE then
				problem(
					string.format(
						"landing: %s: only %.1f studs from the edge of a %s at (%.1f, %.1f) (the least is %g)",
						label,
						gap,
						circle.name,
						circle.x,
						circle.z,
						PROP_LANDING_CLEARANCE
					)
				)
			end
		end
		local nearestFlower = math.huge
		for _, part in flowerParts do
			nearestFlower = math.min(nearestFlower, distanceToPart(part, spot.X, spot.Z))
		end
		table.insert(
			flowerReport,
			string.format(
				"%s: nearest flower clump %.1f studs%s",
				label,
				nearestFlower,
				if nearestFlower < FLOWER_LANDING_CLEARANCE then " (CLOSER THAN 2.5, designer decides)" else ""
			)
		)
		table.insert(landing, spot)
	end
	return landing, flowerReport
end

return {
	planLanding = planLanding,
}
