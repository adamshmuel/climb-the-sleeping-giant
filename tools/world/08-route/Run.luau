--!strict
-- World prep, task 23 (split into the folder tools/world/08-route in plan 3 Task 8a): the footprint route and the
-- landing spots (spec Rule 2, "Footprints show the way", Rule 12, "Waking bounces everyone off", and section 8, "Many
-- players land at once after the bounce-off"; Rule 43, "Landing spots on every side").
-- Why: footprints (Task 24) follow a map of the walkable ground, and the bounce-off (Tasks 26 and 27) needs places in
-- the meadow to put players down. Both are made here and checked by real-world tests.
-- Run in Studio EDIT mode: this file returns a function. Rojo syncs the folder into ServerStorage.Tools.world, and
-- `return require(game:GetService("ServerStorage").Tools.world["08-route"]:Clone().Run)()` runs it.
-- Files: RoutePlaces.luau (the numbers, hand points, links and landing places), RouteChecks.luau (planWorld and its
-- helpers) and this file (the comparison with what exists, and the build).
-- Every run plans and checks everything first, so a problem stops the script with nothing changed. Then:
--   * if World.Route and World.LandingSpots already match the plan, it says "already done" and changes nothing;
--   * if neither exists, it makes both;
--   * if both exist but differ from the plan, it builds the new ones away from the Workspace, then (between two
--     ChangeHistoryService waypoints) destroys the old ones and puts the new ones in, and reports what changed. Route
--     points and landing spots are made only by this script and nothing else refers to them, so replacing them is safe;
--   * if only one of the two exists, it stops with nothing changed.
-- With CHECK_ONLY = true it does the same planning and checks, prints the differences and changes nothing.
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
--
-- Workspace.World.Route is a Model (ModelStreamingMode Persistent: every client reads it for its own footprints) full
-- of route points, RoutePoint_<name>. Each point is an invisible, anchored 1 x 0.2 x 1 part that nothing can touch,
-- hit or see, level, with its TOP centre on the ground a player walks on. A point has:
--   * Neighbours: the names of the points it links to, separated by commas. Every link is listed on both ends.
--   * Target (only where it stands at something): the nest's model name ("Nest_Meadow_4b"), "Gate_<n>" or
--     "Spawn_<n>".
--   * Ladder, WayUpFoot, WayUpTop (Plan 3 Task 8c, only on the ends of a way up): the ladder part's name on both ends
--     of a boot ladder ("BootLadder_Left"), and the Config.WaysUp name on a way's foot and on its top. The numbers are
--     POINT_TAGS in RoutePlaces.luau. The link between a ladder's two ends is a climb (RouteData.isClimb): it is not
--     length or walk checked.
-- The points, in the order a player meets them:
--   * Spawn_n, Gate_n (5.5 studs outside the arch, toward the spawn spot) and the two ends of PlankBridge_n, for
--     each garden n;
--   * the meadow: each Common egg point (no Target), and Meadow_1 .. Meadow_18 between them (a ring in front of the giant, round
--     the sock and the teacup, never over water or through props), with a way past the ramp feet;
--   * each ramp: Foot, Low, High, Top (the top is on the boot);
--   * the nests (plan 5 Task 17a): one point each, named like the nest, with the nest as its Target (NEST_POINTS in
--     RoutePlaces.luau); the cap nests have none yet;
--   * the boot tops: the two Uncommon egg points of each boot (no Target);
--   * the walk to each boot ladder: Walk<n>_<k> and Ladder<Side>_InNorth / _InSouth / _RunIn / _Foot on the grass,
--     Ladder<Side>_Top on the boot (spec Rule 42: footprints take the quickest way; Rule 35);
--   * the lap: Plank<Side>_Out and _In on each lap plank, Landing_Back on the lap landing, then the fork (spec Rule 45
--     point 3): BellyRamp<Side>_1 .. _3 on each belly ramp. The left ramp goes on to Egg_Rare_1; the right one ends at
--     BellyRampRight_4 (a dead end);
--   * the belly path: Egg_Rare_1 .. Egg_Rare_3, Belly_4, Belly_Crest and Egg_Rare_4.
-- Workspace.World.LandingSpots is a Folder of LandingSpot_1 .. LandingSpot_<n>, the same kind of part, with its top
-- centre on the meadow grass around his feet.
--
-- Before it changes anything, the script checks (the same checks as the real-world tests in RealWorld.spec):
--   * every point has ground a player walks on under it, not water;
--   * every link (but a ladder's climb link) is at most 25 studs long and walkable (the shared check, src/server/World/PathCheck): sampled
--     every 2 studs, a ray from 3 studs above the line finds a solid, non-water surface within 4 studs, no steeper
--     than StarterPlayer.CharacterMaxSlopeAngle and no more than 1 stud from the line; and room for a player's body
--     (Config.Stuck: a box held 0.5 studs above the ground, tilted with it and turned to face the way it walks)
--     that touches nothing with CanCollide on, checked on the exact shape of every part, not its outer box.
--     Left out of the body check: the two ramp planks, whose edges a player touches when stepping on or off a ramp
--     foot;
--   * every link keeps clear of the props a player would walk through (every meadow prop has CanCollide off, so the
--     checks above never see them): at least 3 studs from every sunflower stem and at least 1 stud from the edge of
--     every bush or rock;
--   * every point can reach every other point;
--   * every landing spot is on flat grass, in the Meadow and in no garden, with a clear box above it (LANDING_BOX in
--     RoutePlaces) and open sky above, at least 10 studs from every other spot, within 110 studs of the giant's
--     middle, at least 10 studs from every nest (a bounced player must not land on an egg: the grab reach is 8),
--     and at least 5 studs from every sunflower stem and from the edge of every bush or rock. The nearest flower clump
--     is reported (designer wants none within 2.5 studs), but it does not stop the script.

-- When true: print the differences between the plan and the place, and change nothing.
local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Places = require(script.Parent.RoutePlaces)
local RouteChecks = require(script.Parent.RouteChecks)

local POINT_SIZE = Places.POINT_SIZE
local SAME_PLACE = Places.SAME_PLACE
local LINKS = Places.LINKS

type Plan = RouteChecks.Plan

local topOf = RouteChecks.topOf

-- An invisible, anchored, level part whose TOP centre is `top`. Nothing can touch, hit or see it.
local function makeMarker(name: string, top: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = POINT_SIZE
	part.CFrame = CFrame.new(top - Vector3.new(0, POINT_SIZE.Y / 2, 0))
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- What is in the place now, in the same terms as the plan: every route point (by its part name) with its top, its
-- neighbours (sorted) and its target, and the landing spots by number.
type ExistingPoint = {
	top: Vector3,
	neighbours: { string },
	target: string?,
	ladder: string?,
	wayUpFoot: string?,
	wayUpTop: string?,
}

-- A text attribute, or nil when it is missing or not text.
local function textAttribute(part: Instance, name: string): string?
	local value: any = part:GetAttribute(name)
	return if type(value) == "string" then value else nil
end
type Existing = {
	points: { [string]: ExistingPoint },
	landing: { [number]: Vector3 },
	odd: { string }, -- things that are not what the script makes (so the place does not match)
}

local function readExisting(route: Instance, landingFolder: Instance): Existing
	local existing: Existing = { points = {}, landing = {}, odd = {} }
	if not route:IsA("Model") or route.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		table.insert(existing.odd, "World.Route is not a Persistent Model")
	end
	for _, child in route:GetChildren() do
		if not child:IsA("BasePart") then
			table.insert(existing.odd, `World.Route.{child.Name} is not a part`)
			continue
		end
		local neighboursValue: any = child:GetAttribute("Neighbours")
		local targetValue: any = child:GetAttribute("Target")
		local neighbours: { string } = {}
		if type(neighboursValue) == "string" then
			for piece in string.gmatch(neighboursValue, "[^,]+") do
				table.insert(neighbours, (string.match(piece, "^%s*(.-)%s*$")) :: string)
			end
		end
		table.sort(neighbours)
		existing.points[child.Name] = {
			top = topOf(child),
			neighbours = neighbours,
			target = if type(targetValue) == "string" then targetValue else nil,
			ladder = textAttribute(child, "Ladder"),
			wayUpFoot = textAttribute(child, "WayUpFoot"),
			wayUpTop = textAttribute(child, "WayUpTop"),
		}
	end
	for _, child in landingFolder:GetChildren() do
		local number = string.match(child.Name, "^LandingSpot_(%d+)$")
		if number == nil or not child:IsA("BasePart") then
			table.insert(existing.odd, `World.LandingSpots.{child.Name} is not a LandingSpot_<n> part`)
			continue
		end
		existing.landing[tonumber(number) :: number] = topOf(child)
	end
	return existing
end

local function joinNames(names: { string }): string
	table.sort(names)
	return if #names == 0 then "none" else table.concat(names, ", ")
end

-- A point's name without the RoutePoint_ start.
local function bare(name: string): string
	local short = string.gsub(name, "^RoutePoint_", "")
	return short
end

local function shortPlace(position: Vector3): string
	return string.format("(%.1f, %.1f)", position.X, position.Z)
end

-- Every link as "A - B" (the shorter name first, no RoutePoint_ start), from a point -> neighbours table.
local function linkSet(neighboursOf: { [string]: { string } }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for name, list in neighboursOf do
		for _, other in list do
			local first, second = name, other
			if second < first then
				first, second = second, first
			end
			set[`{bare(first)} - {bare(second)}`] = true
		end
	end
	return set
end

-- Compares the place with the plan. Returns the report lines of what differs (empty if nothing does).
local function differences(plan: Plan, existing: Existing): { string }
	local lines: { string } = {}
	for _, text in existing.odd do
		table.insert(lines, `different: {text}`)
	end

	local planned: { [string]: ExistingPoint } = {}
	local plannedNeighbours: { [string]: { string } } = {}
	local existingNeighbours: { [string]: { string } } = {}
	for _, point in plan.points do
		local full = `RoutePoint_{point.name}`
		local names: { string } = {}
		for _, other in plan.neighbours[point.name] do
			table.insert(names, `RoutePoint_{other}`)
		end
		table.sort(names)
		planned[full] = {
			top = point.position,
			neighbours = names,
			target = point.target,
			ladder = point.ladder,
			wayUpFoot = point.wayUpFoot,
			wayUpTop = point.wayUpTop,
		}
		plannedNeighbours[full] = names
	end
	for name, point in existing.points do
		existingNeighbours[name] = point.neighbours
	end

	local added, moved, removed, retargeted, relisted, retagged = {}, {}, {}, {}, {}, {}
	for name, point in planned do
		local old = existing.points[name]
		if old == nil then
			table.insert(added, `{bare(name)} {shortPlace(point.top)}`)
			continue
		end
		if (old.top - point.top).Magnitude > SAME_PLACE then
			table.insert(moved, `{bare(name)} {shortPlace(old.top)} to {shortPlace(point.top)}`)
		end
		if old.target ~= point.target then
			table.insert(retargeted, bare(name))
		end
		if table.concat(old.neighbours, ",") ~= table.concat(point.neighbours, ",") then
			table.insert(relisted, bare(name))
		end
		if old.ladder ~= point.ladder or old.wayUpFoot ~= point.wayUpFoot or old.wayUpTop ~= point.wayUpTop then
			table.insert(retagged, bare(name))
		end
	end
	for name in existing.points do
		if planned[name] == nil then
			table.insert(removed, bare(name))
		end
	end

	local plannedLinks, existingLinks = linkSet(plannedNeighbours), linkSet(existingNeighbours)
	local linksAdded, linksRemoved = {}, {}
	for key in plannedLinks do
		if not existingLinks[key] then
			table.insert(linksAdded, key)
		end
	end
	for key in existingLinks do
		if not plannedLinks[key] then
			table.insert(linksRemoved, key)
		end
	end

	local landingMoved: { string } = {}
	for number, spot in plan.landing do
		local old: Vector3? = existing.landing[number]
		if old == nil then
			table.insert(landingMoved, `LandingSpot_{number} is new at {shortPlace(spot)}`)
		elseif (old - spot).Magnitude > SAME_PLACE then
			table.insert(landingMoved, `LandingSpot_{number} {shortPlace(old)} to {shortPlace(spot)}`)
		end
	end
	for number in existing.landing do
		local wanted: Vector3? = plan.landing[number]
		if wanted == nil then
			table.insert(landingMoved, `LandingSpot_{number} is no longer wanted`)
		end
	end
	table.sort(landingMoved)

	local function add(title: string, list: { string })
		if #list > 0 then
			table.insert(lines, `{title} ({#list}): {joinNames(list)}`)
		end
	end
	add("points added", added)
	add("points moved", moved)
	add("points removed", removed)
	add("points whose Target changed", retargeted)
	add("points whose Neighbours changed", relisted)
	add("points whose way-up tags changed", retagged)
	add("links added", linksAdded)
	add("links removed", linksRemoved)
	if #landingMoved > 0 then
		table.insert(lines, `landing spots moved ({#landingMoved}): {table.concat(landingMoved, "; ")}`)
	end
	return lines
end

-- Builds a whole new Route model and LandingSpots folder from the plan. Neither is in the Workspace yet.
local function buildNew(plan: Plan): (Model, Folder, number)
	local model = Instance.new("Model")
	model.Name = "Route"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local targets = 0
	for _, point in plan.points do
		local part = makeMarker(`RoutePoint_{point.name}`, point.position)
		local names: { string } = {}
		for _, other in plan.neighbours[point.name] do
			table.insert(names, `RoutePoint_{other}`)
		end
		part:SetAttribute("Neighbours", table.concat(names, ","))
		if point.target then
			part:SetAttribute("Target", point.target)
			targets += 1
		end
		if point.ladder then
			part:SetAttribute("Ladder", point.ladder)
		end
		if point.wayUpFoot then
			part:SetAttribute("WayUpFoot", point.wayUpFoot)
		end
		if point.wayUpTop then
			part:SetAttribute("WayUpTop", point.wayUpTop)
		end
		part.Parent = model
	end
	local folder = Instance.new("Folder")
	folder.Name = "LandingSpots"
	for number, spot in plan.landing do
		makeMarker(`LandingSpot_{number}`, spot).Parent = folder
	end
	return model, folder, targets
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing (run 01-gardens first)")
	end

	local oldRoute = world:FindFirstChild("Route")
	local oldLanding = world:FindFirstChild("LandingSpots")
	if (oldRoute == nil) ~= (oldLanding == nil) then
		error("World.Route or World.LandingSpots exists without the other. Nothing was changed.")
	end

	-- Check everything first, so a problem stops the script before anything changes.
	local plan = RouteChecks.planWorld(world)

	local changes: { string } = {}
	if oldRoute ~= nil and oldLanding ~= nil then
		changes = differences(plan, readExisting(oldRoute, oldLanding))
		if #changes == 0 then
			return "already done"
		end
	end
	if CHECK_ONLY then
		if oldRoute == nil then
			return "CHECK ONLY: World.Route and World.LandingSpots do not exist yet; nothing was changed"
		end
		return `CHECK ONLY (nothing was changed). differences:\n   {table.concat(changes, "\n   ")}`
	end

	-- Build the new ones completely before touching the old ones.
	local model, folder, targets = buildNew(plan)

	pcall(function()
		ChangeHistoryService:SetWaypoint("08-route: before")
	end)
	if oldRoute ~= nil and oldLanding ~= nil then
		oldRoute:Destroy()
		oldLanding:Destroy()
	end
	model.Parent = world
	folder.Parent = world
	pcall(function()
		ChangeHistoryService:SetWaypoint("08-route: after")
	end)

	local summary = string.format(
		"World.Route: %d points (%d at a target), %d links; World.LandingSpots: %d spots",
		#plan.points,
		targets,
		#LINKS,
		#plan.landing
	)
	if oldRoute == nil then
		return `made {summary}\n   {table.concat(plan.info, "\n   ")}`
	end
	local checks = table.concat(plan.info, "\n   ")
	return `updated {summary}\n   changes:\n   {table.concat(changes, "\n   ")}\n   checks:\n   {checks}`
end

return function(): string
	local ok, message = pcall(run)
	RouteChecks.cleanup() -- the body probe never stays in the Workspace, whatever happened
	if not ok then
		return "STOPPED WITH AN ERROR: " .. tostring(message)
	end
	return message
end
