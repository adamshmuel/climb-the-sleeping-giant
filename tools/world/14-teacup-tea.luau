--!strict
-- World prep, V2 stuck safety Task 6: the teacup's bowl (docs/plans/v2/stuck-safety.md, "Task 6").
-- Why: the teacup's bowl is open on top, so a player who gets in is wedged (the 4 stuck spots of the Task 18 review). The
-- fix is Roblox's smooth wrap (CollisionFidelity Hull), which fills the bowl up to its rim. Then a player can stand on
-- top of the filled bowl, so designer asked for some tea to stand over (docs/specs/v2/research/decisions-plans.md,
-- "Stuck safety Task 18: the teacup's bowl" and "Stuck safety Task 6: the tea on a tilted rim").
-- What it does:
--   1. Sets World.GiantsThings.Teacup.body.body_geom to CollisionFidelity Hull. Accepted side effect: the gap between
--      the cup and its handle becomes a small invisible wall.
--   2. Adds World.GiantsThings.Teacup.Tea: one flat tea-brown disc inside the bowl, tilted like the cup's rim (the rim is
--      not level: it tilts 8.8 degrees, highest to the west/north-west). CanCollide, CanQuery and CanTouch are off, so
--      the smooth wrap stays the only thing players stand on.
--   3. Colours the Tea TEA_COLOUR (tea brown, #9C5E34). A Tea that is already there in an earlier colour (the named
--      list EARLIER_TEA_COLOURS) is only recoloured. A Tea in any other colour stops the script with nothing changed.
--   The cup itself does not change: same mesh, colours, size and place.
-- The numbers below were MEASURED BY HAND on 2026-10-19, in Studio Edit mode, before the cup became Hull (once it is
-- Hull the inside of the bowl can't be measured again). The tea is built from these recorded numbers. While the cup
-- is still Default, the script also measures the rim again, live, and stops with nothing changed if the cup is not the
-- one the numbers were measured on.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when the cup is
-- Hull, one Tea is there and it is TEA_COLOUR it changes nothing and says "already done". The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- The cup, as measured: body_geom's size and place, and how close the live values must be.
local CUP_SIZE = Vector3.new(33.928, 22.193, 34)
local CUP_POSITION = Vector3.new(76, 12.097, -58)
local CUP_TOLERANCE = 0.01

-- The rim, as measured. Rays straight down onto the cup's own mesh (RespectCanCollide off, only the cup in the filter),
-- outwards from (76, -58) every 0.1 studs from 6 to 16 studs, at 72 angles 5 degrees apart. The rim crest of each angle
-- is its highest hit. The rim plane is the least-squares plane through the 72 crest points:
--   y = RIM_SLOPE_X * x + RIM_SLOPE_Z * z + RIM_BASE
local RIM_SLOPE_X = -0.134338
local RIM_SLOPE_Z = -0.077725
local RIM_BASE = 26.486
-- The crest point that sits farthest below the plane is this far under it. Measured at 69.55, 20.3291, -46.8283.
local WORST_BELOW = 0.45336
-- The tea's top is this far under the rim plane: WORST_BELOW plus 0.1, so the tea is at least 0.1 under every crest point.
local TEA_DROP = 0.5534

-- The inside of the bowl at the tea's height: a circle fitted to the wall found by rays down along 72 angles, measured
-- in the tea's own plane. Its centre (on the tea's top plane) and its radius.
local CIRCLE_CENTRE_X = 77.3985
local CIRCLE_CENTRE_Z = -57.1986
local CIRCLE_RADIUS = 11.941
-- The tea reaches this far past the inside wall, so its edge tucks into the cup and no empty bowl shows.
local TEA_EDGE_EXTRA = 0.3
local TEA_RADIUS = CIRCLE_RADIUS + TEA_EDGE_EXTRA
local TEA_THICKNESS = 0.4
-- The tea's edge must stay at least this far inside the cup's outer wall, all the way round (measured sideways).
local OUTER_WALL_MARGIN = 0.2
-- Tea brown. The first colour, #C8874A, showed as gold in the game's warm light (too close to the cash gold and the
-- footprint yellow), so designer asked for a darker brown at the Task 6 review.
local TEA_COLOUR = Color3.fromHex("9C5E34")
-- Colours the Tea had before, so a Tea already in the world is recoloured instead of stopping the script.
local EARLIER_TEA_COLOURS: { Color3 } = {
	Color3.fromHex("C8874A"), -- round 1 (2026-10-19): showed as gold in the warm light
}

-- How the live measuring works (the same as the hand measuring above).
local RING_CENTRE_X = 76
local RING_CENTRE_Z = -58
local RING_ANGLE_STEP = 5 -- degrees
local RING_FROM = 6 -- studs from the ring centre
local RING_TO = 16
local RING_STEP = 0.1
local WALL_STEP = 0.02
local RAY_START_HEIGHT = 40
local RAY_LENGTH = 60
local OUTSIDE_DISTANCE = 40 -- studs from the tea's middle where the sideways rays start
local SLOPE_TOLERANCE = 0.002
local HEIGHT_TOLERANCE = 0.05
local CIRCLE_TOLERANCE = 0.05

type Crest = { angle: number, x: number, y: number, z: number, radius: number }
type Measured = {
	slopeX: number,
	slopeZ: number,
	base: number,
	worstBelow: number,
	centre: Vector2, -- the circle's middle, in the tea plane's own sideways and up-slope directions
	radius: number,
}

-- Solves a 3 by 3 system given as three rows of four numbers (the last is the answer side).
local function solve3(rows: { { number } }): (number, number, number)
	for pivot = 1, 3 do
		local divisor = rows[pivot][pivot]
		for column = pivot, 4 do
			rows[pivot][column] /= divisor
		end
		for other = 1, 3 do
			if other ~= pivot then
				local factor = rows[other][pivot]
				for column = pivot, 4 do
					rows[other][column] -= factor * rows[pivot][column]
				end
			end
		end
	end
	return rows[1][4], rows[2][4], rows[3][4]
end

-- The straight-down direction of the tea's top plane: the normal of y = slopeX * x + slopeZ * z + base, and two
-- directions in the plane.
local function planeDirections(slopeX: number, slopeZ: number): (Vector3, Vector3, Vector3)
	local normal = Vector3.new(-slopeX, 1, -slopeZ).Unit
	local sideways = Vector3.new(0, 1, 0):Cross(normal).Unit
	local upSlope = normal:Cross(sideways)
	return normal, sideways, upSlope
end

-- The least-squares circle through points given as (u, v): its middle and radius.
local function fitCircle(points: { Vector2 }): (Vector2, number)
	local su, sv, suu, svv, suv, sw, suw, svw = 0, 0, 0, 0, 0, 0, 0, 0
	for _, point in points do
		local w = point.X * point.X + point.Y * point.Y
		su += point.X
		sv += point.Y
		suu += point.X * point.X
		svv += point.Y * point.Y
		suv += point.X * point.Y
		sw += w
		suw += point.X * w
		svw += point.Y * w
	end
	local a, b, c = solve3({
		{ suu, suv, su, suw },
		{ suv, svv, sv, svw },
		{ su, sv, #points, sw },
	})
	local middle = Vector2.new(a / 2, b / 2)
	return middle, math.sqrt(c + middle.X * middle.X + middle.Y * middle.Y)
end

local function cupRays(cup: MeshPart): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { cup }
	params.RespectCanCollide = false
	return params
end

-- Measures the rim and the inside of the bowl live. Only works while the cup is not Hull.
local function measure(cup: MeshPart): Measured
	local params = cupRays(cup)
	local function heightAt(x: number, z: number): number
		local hit = Workspace:Raycast(Vector3.new(x, RAY_START_HEIGHT, z), Vector3.new(0, -RAY_LENGTH, 0), params)
		if hit then
			return hit.Position.Y
		end
		return -1
	end

	-- 1. The 72 rim crest points.
	local crests: { Crest } = {}
	local ringSteps = math.floor((RING_TO - RING_FROM) / RING_STEP + 0.5)
	for index = 0, 360 / RING_ANGLE_STEP - 1 do
		local angle = math.rad(index * RING_ANGLE_STEP)
		local best = Vector3.new(0, -1, 0)
		local bestRadius = 0
		for step = 0, ringSteps do
			local radius = RING_FROM + step * RING_STEP
			local x = RING_CENTRE_X + math.cos(angle) * radius
			local z = RING_CENTRE_Z + math.sin(angle) * radius
			local y = heightAt(x, z)
			if y > best.Y then
				best = Vector3.new(x, y, z)
				bestRadius = radius
			end
		end
		table.insert(crests, { angle = angle, x = best.X, y = best.Y, z = best.Z, radius = bestRadius })
	end

	-- 2. The rim plane: least squares through the crest points.
	local sx, sz, sy, sxx, szz, sxz, sxy, szy = 0, 0, 0, 0, 0, 0, 0, 0
	for _, crest in crests do
		sx += crest.x
		sz += crest.z
		sy += crest.y
		sxx += crest.x * crest.x
		szz += crest.z * crest.z
		sxz += crest.x * crest.z
		sxy += crest.x * crest.y
		szy += crest.z * crest.y
	end
	local slopeX, slopeZ, base = solve3({
		{ sxx, sxz, sx, sxy },
		{ sxz, szz, sz, szy },
		{ sx, sz, #crests, sy },
	})
	local worstBelow = 0
	for _, crest in crests do
		worstBelow = math.max(worstBelow, slopeX * crest.x + slopeZ * crest.z + base - crest.y)
	end

	-- 3. The wall at the tea's height, along each angle: the first radius where the cup's surface reaches the tea's
	-- top. Then the circle through those points, in the tea plane.
	local drop = worstBelow + 0.1
	local _, sideways, upSlope = planeDirections(slopeX, slopeZ)
	local wallPoints: { Vector2 } = {}
	for _, crest in crests do
		local wallSteps = math.floor((crest.radius - RING_FROM) / WALL_STEP)
		for step = 0, wallSteps do
			local radius = RING_FROM + step * WALL_STEP
			local x = RING_CENTRE_X + math.cos(crest.angle) * radius
			local z = RING_CENTRE_Z + math.sin(crest.angle) * radius
			local teaTop = slopeX * x + slopeZ * z + base - drop
			if heightAt(x, z) >= teaTop then
				local point = Vector3.new(x, teaTop, z)
				table.insert(wallPoints, Vector2.new(point:Dot(sideways), point:Dot(upSlope)))
				break
			end
		end
	end
	local centre, radius = fitCircle(wallPoints)
	return {
		slopeX = slopeX,
		slopeZ = slopeZ,
		base = base,
		worstBelow = worstBelow,
		centre = centre,
		radius = radius,
	}
end

-- The tea's top plane as built from the recorded numbers.
local function teaTopY(x: number, z: number): number
	return RIM_SLOPE_X * x + RIM_SLOPE_Z * z + RIM_BASE - TEA_DROP
end

-- What is wrong when the live measuring does not match the recorded numbers, or nil.
local function measuredProblem(measured: Measured): string?
	local problems: { string } = {}
	if
		math.abs(measured.slopeX - RIM_SLOPE_X) > SLOPE_TOLERANCE
		or math.abs(measured.slopeZ - RIM_SLOPE_Z) > SLOPE_TOLERANCE
		or math.abs(measured.base - RIM_BASE) > HEIGHT_TOLERANCE
	then
		table.insert(
			problems,
			string.format(
				"the rim plane is y = %.4f x + %.4f z + %.3f, not the recorded %.4f, %.4f, %.3f",
				measured.slopeX,
				measured.slopeZ,
				measured.base,
				RIM_SLOPE_X,
				RIM_SLOPE_Z,
				RIM_BASE
			)
		)
	end
	if math.abs(measured.worstBelow - WORST_BELOW) > HEIGHT_TOLERANCE then
		table.insert(
			problems,
			string.format(
				"the worst crest point is %.3f under the plane, not the recorded %.3f",
				measured.worstBelow,
				WORST_BELOW
			)
		)
	end
	-- The recorded circle middle, in the same plane directions as the live one.
	local _, sideways, upSlope = planeDirections(RIM_SLOPE_X, RIM_SLOPE_Z)
	local recorded = Vector3.new(CIRCLE_CENTRE_X, teaTopY(CIRCLE_CENTRE_X, CIRCLE_CENTRE_Z), CIRCLE_CENTRE_Z)
	local recordedMiddle = Vector2.new(recorded:Dot(sideways), recorded:Dot(upSlope))
	if
		(measured.centre - recordedMiddle).Magnitude > CIRCLE_TOLERANCE
		or math.abs(measured.radius - CIRCLE_RADIUS) > CIRCLE_TOLERANCE
	then
		table.insert(
			problems,
			string.format(
				"the inside circle's radius is %.3f, not the recorded %.3f, or its middle has moved",
				measured.radius,
				CIRCLE_RADIUS
			)
		)
	end
	if #problems == 0 then
		return nil
	end
	return table.concat(problems, "; ")
end

-- How close the tea's edge comes to the cup's outer wall, all the way round: from the edge at the tea's top and at its
-- bottom, a ray sideways from far outside back to the tea's middle; the margin is how much wall-to-edge is left.
-- Returns the smallest margin (nil when a ray finds no wall at all).
local function outerWallMargin(cup: MeshPart): number?
	local params = cupRays(cup)
	local normal, sideways, upSlope = planeDirections(RIM_SLOPE_X, RIM_SLOPE_Z)
	local topMiddle = Vector3.new(CIRCLE_CENTRE_X, teaTopY(CIRCLE_CENTRE_X, CIRCLE_CENTRE_Z), CIRCLE_CENTRE_Z)
	local smallest = math.huge
	for degrees = 0, 355, RING_ANGLE_STEP do
		local angle = math.rad(degrees)
		local top = topMiddle + TEA_RADIUS * (math.cos(angle) * sideways + math.sin(angle) * upSlope)
		for _, edge in { top, top - TEA_THICKNESS * normal } do
			local outward = Vector3.new(edge.X - topMiddle.X, 0, edge.Z - topMiddle.Z)
			local edgeDistance = outward.Magnitude
			local direction = outward.Unit
			local start = Vector3.new(topMiddle.X, edge.Y, topMiddle.Z) + direction * OUTSIDE_DISTANCE
			local hit = Workspace:Raycast(start, -direction * (OUTSIDE_DISTANCE * 2), params)
			if hit == nil then
				return nil
			end
			local wallDistance = Vector3.new(hit.Position.X - topMiddle.X, 0, hit.Position.Z - topMiddle.Z).Magnitude
			smallest = math.min(smallest, wallDistance - edgeDistance)
		end
	end
	return smallest
end

-- Builds the tea from the recorded numbers.
local function makeTea(teacup: Model): Part
	local normal = Vector3.new(-RIM_SLOPE_X, 1, -RIM_SLOPE_Z).Unit
	local topMiddle = Vector3.new(CIRCLE_CENTRE_X, teaTopY(CIRCLE_CENTRE_X, CIRCLE_CENTRE_Z), CIRCLE_CENTRE_Z)
	-- Roblox's cylinder stands along its X axis, so X is the direction the tea's top faces.
	local across = normal:Cross(Vector3.new(0, 0, 1)).Unit
	local tea = Instance.new("Part")
	tea.Name = "Tea"
	tea.Shape = Enum.PartType.Cylinder
	tea.Size = Vector3.new(TEA_THICKNESS, TEA_RADIUS * 2, TEA_RADIUS * 2)
	tea.CFrame = CFrame.fromMatrix(topMiddle - normal * (TEA_THICKNESS / 2), normal, across)
	tea.Anchored = true
	tea.CanCollide = false
	tea.CanQuery = false
	tea.CanTouch = false
	tea.Color = TEA_COLOUR
	tea.Material = Enum.Material.SmoothPlastic
	tea.Transparency = 0
	tea.Parent = teacup
	return tea
end

local function run(): string
	-- Check everything first, so a problem stops the script before anything changes.
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local things = world:FindFirstChild("GiantsThings")
	local teacup = if things then things:FindFirstChild("Teacup") else nil
	if teacup == nil or not teacup:IsA("Model") then
		error("Workspace.World.GiantsThings.Teacup is missing or is not a Model")
	end
	local body = teacup:FindFirstChild("body")
	local cupInstance = if body then body:FindFirstChild("body_geom") else nil
	if cupInstance == nil or not cupInstance:IsA("MeshPart") then
		error("Workspace.World.GiantsThings.Teacup.body.body_geom is missing or is not a MeshPart")
	end
	local cup = cupInstance :: MeshPart

	if (cup.Size - CUP_SIZE).Magnitude > CUP_TOLERANCE or (cup.Position - CUP_POSITION).Magnitude > CUP_TOLERANCE then
		error(
			`the cup is not the one the numbers were measured on: size {cup.Size}, place {cup.Position}, expected size {CUP_SIZE}, place {CUP_POSITION}`
		)
	end

	local teas: { Instance } = {}
	for _, descendant in teacup:GetDescendants() do
		if descendant.Name == "Tea" then
			table.insert(teas, descendant)
		end
	end
	if #teas > 1 then
		error(`more than one Tea in the teacup: {#teas}`)
	end
	if #teas == 1 and not teas[1]:IsA("Part") then
		error("the Tea in the teacup is not a Part")
	end
	local needsHull = cup.CollisionFidelity ~= Enum.CollisionFidelity.Hull
	local needsTea = #teas == 0
	-- A Tea already there must be TEA_COLOUR or one of the earlier colours; any other colour is not ours to touch.
	local needsRecolour = false
	if #teas == 1 then
		local existing = teas[1] :: Part
		if existing.Color:ToHex() ~= TEA_COLOUR:ToHex() then
			local isEarlier = false
			for _, earlier in EARLIER_TEA_COLOURS do
				if existing.Color:ToHex() == earlier:ToHex() then
					isEarlier = true
				end
			end
			if not isEarlier then
				error(`the Tea is the colour #{existing.Color:ToHex()}, which is not a colour this script knows`)
			end
			needsRecolour = true
		end
	end
	if not needsHull and not needsTea and not needsRecolour then
		return "already done"
	end
	local lines: { string } = {}

	if needsHull then
		if cup.CollisionFidelity ~= Enum.CollisionFidelity.Default then
			error(`the cup's CollisionFidelity is {cup.CollisionFidelity}, expected Default or Hull`)
		end
		-- The cup is still Default, so the rim can be measured live. The recorded numbers must still match it.
		local measured = measure(cup)
		local problem = measuredProblem(measured)
		if problem ~= nil then
			error(problem)
		end
		table.insert(
			lines,
			string.format(
				"live rim check matches the recorded numbers: plane y = %.4f x + %.4f z + %.3f, worst crest %.3f under it, inside circle radius %.3f",
				measured.slopeX,
				measured.slopeZ,
				measured.base,
				measured.worstBelow,
				measured.radius
			)
		)
	elseif needsTea then
		table.insert(
			lines,
			"the cup is already Hull, so the rim can't be measured again: the tea is built from the recorded numbers"
		)
	end
	if needsTea then
		-- The tea's edge must stay inside the cup's outer wall. Needs the cup's real outer wall, so before Hull.
		if needsHull then
			local margin = outerWallMargin(cup)
			if margin == nil then
				error("a sideways ray found no outer wall: the tea's edge would be outside the cup")
			end
			if margin < OUTER_WALL_MARGIN then
				error(
					string.format(
						"the tea's edge comes within %.2f studs of the outer wall (the least allowed is %.2f): make TEA_EDGE_EXTRA smaller",
						margin,
						OUTER_WALL_MARGIN
					)
				)
			end
			table.insert(
				lines,
				string.format("the tea's edge stays %.2f studs inside the outer wall at its closest", margin)
			)
		end
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("14-teacup-tea: before")
	end)

	if needsHull then
		cup.CollisionFidelity = Enum.CollisionFidelity.Hull
		table.insert(lines, `{cup:GetFullName()}: CollisionFidelity Default -> Hull`)
	end
	if needsTea then
		local tea = makeTea(teacup)
		table.insert(
			lines,
			string.format(
				"made %s: Cylinder %.3f thick, %.3f wide, middle of its top at (%.3f, %.3f, %.3f), tilted 8.8 degrees like the rim",
				tea:GetFullName(),
				tea.Size.X,
				tea.Size.Y,
				CIRCLE_CENTRE_X,
				teaTopY(CIRCLE_CENTRE_X, CIRCLE_CENTRE_Z),
				CIRCLE_CENTRE_Z
			)
		)
	end

	if needsRecolour then
		local existing = teas[1] :: Part
		local before = existing.Color
		existing.Color = TEA_COLOUR
		table.insert(lines, `{existing:GetFullName()}: colour #{before:ToHex()} -> #{TEA_COLOUR:ToHex()}`)
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("14-teacup-tea: after")
	end)
	return table.concat(lines, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
