--!strict
-- World prep, plan 3 (gardens and ways up) Task 7: the ladder boxes and the reshaped belly zone boxes
-- (docs/plans/v2/gardens-and-ways-up.md Task 7; spec Rules 36, 39, 40, 45). Card: work/p3t7/7-card.md; the numbers and the
-- decision table: work/p3t7/7-scripts.md sections A to D.
-- What it does (real run):
--   1. Copies World.Zones (Belly_Path included) into ServerStorage.WorldBackups.p3t7, in the same call as the change.
--   2. Builds World.LadderBoxes: four invisible, not-solid boxes (LadderBox_BootLadder_Left, _Right, _BeardLadder,
--      _CapLadder), each with the truss's own CFrame and size 6 x 6 x (truss length + 2), attributes Ladder and Zone.
--      Zone is Boots for both boot ladders; for the beard and cap ladders it is the zone the V1 boxes give at the ladder's
--      lowest point, so the higher-of rule leaves their zones as before.
--   3. Removes Belly_Path (left side only: it made the two ramps differ) and cuts Belly_FrontA's front edge to z -40.43.
--      Table D: if Belly_Path's removal breaks a check, the script stops (the cut-and-mirror fix is not in this script).
--   4. Adds 4 upright boxes to World.Zones (table D row 2, product's addendum in work/p3t7/zone-ruling.md): Belly_FrontCentre,
--      Boots_RampLeft, Boots_RampRight and Belly_FrontTip. The cut left belly spots in front of z -40.43 in no box.
--      The backup WorldBackups.p3t7 is never remade for them: it already holds the original boxes.
-- It stops, changing nothing, when any check on the planned boxes fails. Run after 02-zones and 17-belly-ramps; never run
-- 02-zones again: it would bring back both boxes as they were.
-- CHECK_ONLY = true measures and prints only. A second real run says "already done" for every box.
-- Rollback: paste WorldBackups.p3t7.Zones back over World.Zones and delete World.LadderBoxes.
-- Report: shared.P3T7Report (list of lines); the call returns the first 1000 characters.
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["18-ladder-boxes-and-zones"]:Clone())` through execute_luau.

local CHECK_ONLY = true

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "p3t7"
local UP = Vector3.new(0, 3, 0) -- a player's root is 3 studs above the surface (floor point + 3)
local CUT_Z = -40.43 -- the plane between ramp Piece15 (z about -40.56) and Rare egg 1's spot (top of its tilted Base, z -40.30): 0.13 each side
local MIN_MARGIN = 0.1 -- studs a station and the egg spot must keep from the plane (table D)
local BOX_SIDE = 6 -- the climber is within 3 studs of the truss axis
local BOX_EXTRA = 2 -- 1 stud past each end of the truss
local TOL = 0.01
local LADDERS = { "BootLadder_Left", "BootLadder_Right", "BeardLadder", "CapLadder" }
-- Table D row 2: the 4 boxes that fill the part of the old Belly_FrontA in front of CUT_Z. Each is { name, zone, min, max }
-- (x, y, z corners). Mirror pair Boots_RampLeft / Boots_RampRight covers the two ramp corridors (x 8 to 15.5).
local FRONT_Y_MIN, FRONT_Y_MAX = 9, 70
local FRONT_Z_MIN = -44
local CORRIDOR_X_MIN, CORRIDOR_X_MAX = 8, 15.5 -- |x| of the two ramp corridors; the only place a spot may change zone
local FRONT_BOXES: { { name: string, zone: string, min: Vector3, max: Vector3 } } = {
	{
		name = "Belly_FrontCentre",
		zone = "Belly",
		min = Vector3.new(-8, FRONT_Y_MIN, FRONT_Z_MIN),
		max = Vector3.new(8, FRONT_Y_MAX, CUT_Z),
	},
	{
		name = "Boots_RampLeft",
		zone = "Boots",
		min = Vector3.new(-CORRIDOR_X_MAX, FRONT_Y_MIN, FRONT_Z_MIN),
		max = Vector3.new(-CORRIDOR_X_MIN, FRONT_Y_MAX, CUT_Z),
	},
	{
		name = "Boots_RampRight",
		zone = "Boots",
		min = Vector3.new(CORRIDOR_X_MIN, FRONT_Y_MIN, FRONT_Z_MIN),
		max = Vector3.new(CORRIDOR_X_MAX, FRONT_Y_MAX, CUT_Z),
	},
	{
		name = "Belly_FrontTip",
		zone = "Belly",
		min = Vector3.new(-4, 43, -46),
		max = Vector3.new(4, 50, FRONT_Z_MIN),
	},
}
-- The zones up the beard and cap ladders, lowest point first, read in Edit before any change (7-scripts.md E).
local TRUSS_RUNS: { [string]: string } = {
	BeardLadder = "Belly x2, Beard x15",
	CapLadder = "Beard x7, Nightcap x2",
}

type Box = { name: string, zone: string, cframe: CFrame, size: Vector3 }
type Point = { label: string, position: Vector3 }

local lines: { string } = {}
local stops: { string } = {}

local function say(text: string)
	table.insert(lines, text)
end

local function stop(text: string)
	table.insert(stops, text)
	table.insert(lines, `STOP: {text}`)
end

local function fmt(n: number): string
	return string.format("%.2f", n)
end

-- A line for the short answer: it goes first in the returned text (the call cuts the text at 1000 characters) and into the report.
local keyLines: { string } = {}
local function key(text: string)
	table.insert(keyLines, text)
	table.insert(lines, text)
end

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P3T7Report = lines
	return string.sub(`{head}\n{table.concat(keyLines, "\n")}\n{table.concat(lines, "\n")}`, 1, 1000)
end

-- A module of the game, loaded fresh: a clone placed next to the original, removed again.
local function loadFresh(original: ModuleScript): any
	local clone = original:Clone()
	clone.Parent = original.Parent
	local loaded, result = pcall(require, clone)
	clone:Destroy()
	if not loaded then
		error(`{original.Name} did not load: {result}`)
	end
	return result
end

local Server = ServerScriptService:WaitForChild("Server") :: Instance
local Zones = loadFresh(Server:WaitForChild("Giant"):WaitForChild("Zones") :: ModuleScript)
local WorldIndex = loadFresh(Server:WaitForChild("World"):WaitForChild("WorldIndex") :: ModuleScript)

local function readBoxes(folder: Instance): { Box }
	local boxes: { Box } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(boxes, {
				name = child.Name,
				zone = child:GetAttribute("Zone") :: string,
				cframe = child.CFrame,
				size = child.Size,
			})
		end
	end
	return boxes
end

-- The rule "which zone a climber is in": the higher of the zone boxes' zone and any ladder box's zone.
local function climberZone(point: Vector3, zoneBoxes: { Box }, ladderBoxes: { Box }): string
	local zone: string = Zones.zoneAt(point, zoneBoxes)
	for _, box in ladderBoxes do
		if Zones.isInside(point, box.cframe, box.size) then
			zone = Zones.higher(zone, box.zone)
		end
	end
	return zone
end

-- "Boots x11, Belly x4": the zones of a list of points, runs of the same zone counted.
local function runs(zones: { string }): string
	local parts: { string } = {}
	local last, count = "", 0
	for _, zone in zones do
		if zone == last then
			count += 1
		else
			if count > 0 then
				table.insert(parts, `{last} x{count}`)
			end
			last, count = zone, 1
		end
	end
	if count > 0 then
		table.insert(parts, `{last} x{count}`)
	end
	return table.concat(parts, ", ")
end

local function mirror(point: Vector3): Vector3
	return Vector3.new(-point.X, point.Y, point.Z)
end

-- The truss points of a ladder, lowest first (a point every 2 studs; a truss's length is its Z).
local function trussPoints(climb: TrussPart): { Vector3 }
	local points: { Vector3 } = {}
	local half = climb.Size.Z / 2
	local along = -half
	while along <= half + 0.001 do
		table.insert(points, climb.CFrame:PointToWorldSpace(Vector3.new(0, 0, along)))
		along += 2
	end
	table.sort(points, function(a, b)
		return a.Y < b.Y
	end)
	return points
end

local function same(box: BasePart, want: Box): boolean
	return box.Size:FuzzyEq(want.size, TOL)
		and box.CFrame.Position:FuzzyEq(want.cframe.Position, TOL)
		and box:GetAttribute("Zone") == want.zone
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	local walk = world and world:FindFirstChild("WalkSurfaces")
	local zonesFolder = world and world:FindFirstChild("Zones")
	if world == nil or walk == nil or zonesFolder == nil then
		stop("World, World.WalkSurfaces or World.Zones is missing")
		return finish("STOPPED")
	end
	local ladderFolder = world:FindFirstChild("LadderBoxes")
	local currentBoxes = readBoxes(zonesFolder)
	say(
		`CHECK_ONLY = {CHECK_ONLY}; {#currentBoxes} zone boxes now; LadderBoxes folder {if ladderFolder
			then "there"
			else "absent"}`
	)

	-- the ladders: found by full path, each with a TrussPart named Climb
	local climbs: { [string]: TrussPart } = {}
	for _, name in LADDERS do
		local model = walk:FindFirstChild(name)
		local climb = model and model:FindFirstChild("Climb")
		if climb == nil or not climb:IsA("TrussPart") then
			stop(`{name}.Climb is missing`)
		else
			climbs[name] = climb
		end
	end
	if #stops > 0 then
		return finish("STOPPED")
	end

	-- The ladder boxes as they should be. A zone of an existing box is kept (a rerun cannot recompute it).
	local wantLadder: { Box } = {}
	for _, name in LADDERS do
		local climb = climbs[name]
		local existing = ladderFolder and ladderFolder:FindFirstChild(`LadderBox_{name}`)
		local zone: string
		if existing then
			zone = existing:GetAttribute("Zone") :: string
		elseif string.sub(name, 1, 4) == "Boot" then
			zone = "Boots"
		else
			zone = Zones.zoneAt(trussPoints(climb)[1], currentBoxes) -- the zone the V1 boxes give at the lowest point
		end
		table.insert(wantLadder, {
			name = `LadderBox_{name}`,
			zone = zone,
			cframe = climb.CFrame,
			size = Vector3.new(BOX_SIDE, BOX_SIDE, climb.Size.Z + BOX_EXTRA),
		})
	end

	-- The zone boxes as they should be: Belly_Path gone, Belly_FrontA's front edge at CUT_Z.
	local wantZone: { Box } = {}
	local pathThere, cutDone = false, false
	local frontNames: { [string]: boolean } = {}
	for _, front in FRONT_BOXES do
		frontNames[front.name] = true
	end
	for _, box in currentBoxes do
		if box.name == "Belly_Path" then
			pathThere = true
		elseif box.name == "Belly_FrontA" then
			local back = box.cframe.Position.Z + box.size.Z / 2
			if math.abs(back - box.size.Z - CUT_Z) < TOL then
				cutDone = true
				table.insert(wantZone, box)
			elseif box.size.Z <= back - CUT_Z then
				stop(`Belly_FrontA is {fmt(box.size.Z)} deep, not deeper than the cut ({fmt(back - CUT_Z)})`)
			else
				local depth = back - CUT_Z
				local cut = {
					name = box.name,
					zone = box.zone,
					-- the front edge (lower z) moves back by (size - depth), so the centre moves back by half of it
					cframe = box.cframe + Vector3.new(0, 0, (box.size.Z - depth) / 2),
					size = Vector3.new(box.size.X, box.size.Y, depth),
				}
				table.insert(wantZone, cut)
			end
		elseif not frontNames[box.name] then -- the front boxes are added below, as planned
			table.insert(wantZone, box)
		end
	end
	say(
		`cut plan: Belly_Path {if pathThere then "removed" else "already gone"}; Belly_FrontA {if cutDone
			then "already cut"
			else `front edge to z {CUT_Z}`}`
	)
	-- the 4 front boxes (upright: the CFrame is a plain position)
	local wantFront: { Box } = {}
	for _, front in FRONT_BOXES do
		local box: Box = {
			name = front.name,
			zone = front.zone,
			cframe = CFrame.new((front.min + front.max) / 2),
			size = front.max - front.min,
		}
		table.insert(wantFront, box)
		table.insert(wantZone, box)
	end
	local frontToAdd = 0
	for _, box in wantFront do
		local existing = zonesFolder:FindFirstChild(box.name)
		if existing == nil or not existing:IsA("BasePart") or not same(existing, box) then
			frontToAdd += 1
		end
	end
	say(`front boxes: {frontToAdd} of {#wantFront} to add (plan: 4 on the first run, 0 after)`)

	-- The points the checks use
	local eggSpots = WorldIndex.readEggSpots(world)
	local route = WorldIndex.readRoute(world)
	if eggSpots == nil or route == nil then
		stop("the egg spots or the route could not be read")
		return finish("STOPPED")
	end
	local v1Points: { Point } = {}
	for _, spot in eggSpots do
		local base = spot.model:FindFirstChild("Base") :: BasePart
		table.insert(v1Points, { label = `{spot.name} top`, position = spot.cframe.Position })
		table.insert(v1Points, { label = `{spot.name} base`, position = base.Position })
	end
	for _, point in route do
		table.insert(
			v1Points,
			{ label = (string.gsub(point.name, "^RoutePoint_", "")), position = point.position + UP }
		)
	end
	local noLadder: { Box } = {}
	local beforeZones: { string } = {}
	for _, point in v1Points do
		table.insert(
			beforeZones,
			climberZone(point.position, currentBoxes, if ladderFolder then readBoxes(ladderFolder) else noLadder)
		)
	end
	say(`before table: {#eggSpots} egg spots x2 points + {#route} route points = {#v1Points} points`)

	-- Table B: the ramp stations now and after the plan, the ladder feet, Rare egg 1
	local rare1: Vector3? = nil
	for _, spot in eggSpots do
		if spot.name == "EggSpot_Rare_1" then
			rare1 = spot.cframe.Position
		end
	end
	local rampFails: { string } = {}
	for _, ramp in { "BellyRamp_Left", "BellyRamp_Right" } do
		local now: { string } = {}
		local after: { string } = {}
		for index = 1, 16 do
			local piece = (walk:FindFirstChild(ramp) :: Instance):FindFirstChild(`Piece{index}`) :: BasePart?
			if piece == nil then
				stop(`{ramp}.Piece{index} is missing`)
				continue
			end
			local point = piece.Position + UP
			local zoneNow = climberZone(point, currentBoxes, noLadder)
			local zoneAfter = climberZone(point, wantZone, wantLadder)
			table.insert(now, zoneNow)
			table.insert(after, zoneAfter)
			if index <= 15 and zoneAfter ~= "Boots" then
				table.insert(rampFails, `{ramp}.Piece{index}={zoneAfter}`)
			end
			if zoneAfter ~= climberZone(mirror(point), wantZone, wantLadder) then
				table.insert(rampFails, `{ramp}.Piece{index} differs from its mirror`)
			end
			if index == 15 then
				say(`{ramp}.Piece15 is {fmt(math.abs(point.Z - CUT_Z))} from the cut`)
			end
			if index >= 12 and index <= 15 and math.abs(point.Z - CUT_Z) < MIN_MARGIN then
				table.insert(rampFails, `{ramp}.Piece{index} is {fmt(math.abs(point.Z - CUT_Z))} from the cut`)
			end
		end
		say(`table B {ramp} now: {runs(now)}`)
		say(`table B {ramp} after: {runs(after)}`)
	end
	if rare1 == nil then
		stop("EggSpot_Rare_1 is missing")
	else
		local rare = rare1 :: Vector3
		local egg, egg2 = climberZone(rare, wantZone, wantLadder), climberZone(mirror(rare), wantZone, wantLadder)
		say(`Rare egg 1 after: {egg}, its mirror {egg2}; {fmt(math.abs(rare.Z - CUT_Z))} from the cut`)
		if egg ~= "Belly" or egg2 ~= "Belly" or math.abs(rare.Z - CUT_Z) < MIN_MARGIN then
			table.insert(rampFails, "Rare egg 1 or its mirror is not Belly, or too near the cut")
		end
	end
	if #rampFails > 0 then
		stop(`stations: {table.concat(rampFails, "; ")}`)
	end

	-- every V1 egg spot and route point keeps its zone
	local changed: { string } = {}
	for index, point in v1Points do
		local after = climberZone(point.position, wantZone, wantLadder)
		if after ~= beforeZones[index] then
			table.insert(changed, `{point.label} {beforeZones[index]}>{after}`)
		end
	end
	say(`V1 points that change zone: {#changed}`)
	if #changed > 0 then
		stop(`V1 points change zone (table D, no change allowed): {table.concat(changed, "; ")}`)
	end

	-- The whole giant, every stud (the Zones.spec stand-spot rule on a 1-stud grid: Giant and WalkSurfaces hits above y 8,
	-- point = hit + 3 up). The old boxes are the V1 boxes in the backup. Table D row 2: no spot becomes Meadow, and a spot
	-- may change zone only inside the two ramp corridors (|x| 8 to 15.5, z -44 to the cut).
	local giant = world:FindFirstChild("Giant")
	local backupRoot = ServerStorage:FindFirstChild("WorldBackups")
	local backupMine = backupRoot and backupRoot:FindFirstChild(BACKUP_NAME)
	local backupZones = backupMine and backupMine:FindFirstChild("Zones")
	if giant == nil or backupZones == nil then
		stop("World.Giant or WorldBackups.p3t7.Zones is missing: the whole-giant check cannot run")
	else
		local oldBoxes = readBoxes(backupZones)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { giant, walk }
		local spots, changedCount, outsideCount, newMeadow, allMeadow = 0, 0, 0, 0, 0
		local outsideList: { string } = {}
		local meadowList: { string } = {}
		for x = -60, 60 do
			for z = -75, 70 do
				local hit = Workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -300, 0), params)
				if hit == nil or hit.Position.Y <= 8 then
					continue
				end
				spots += 1
				local point = hit.Position + UP
				local before = Zones.zoneAt(point, oldBoxes)
				local after = Zones.zoneAt(point, wantZone)
				local label = `({fmt(point.X)}, {fmt(point.Y)}, {fmt(point.Z)})`
				if climberZone(point, wantZone, wantLadder) == "Meadow" then
					allMeadow += 1
				end
				if after == "Meadow" and before ~= "Meadow" then
					newMeadow += 1
					table.insert(meadowList, label)
				end
				if before ~= after then
					changedCount += 1
					local ax = math.abs(point.X)
					local inCorridor = ax >= CORRIDOR_X_MIN - TOL
						and ax <= CORRIDOR_X_MAX + TOL
						and point.Z >= FRONT_Z_MIN - TOL
						and point.Z <= CUT_Z + TOL
					if not inCorridor then
						outsideCount += 1
						table.insert(outsideList, `{label} {before}>{after}`)
					end
				end
			end
		end
		key(
			`giant spots {spots}: zone changed {changedCount} (code_lead expects 44), outside the corridors {outsideCount}, new Meadow {newMeadow}`
		)
		say(`spots in no zone (zone boxes + ladder boxes), old Meadow too: {allMeadow}`)
		if newMeadow > 0 then
			stop(`{newMeadow} spots become Meadow: {table.concat(meadowList, " ", 1, math.min(#meadowList, 6))}`)
		end
		if outsideCount > 0 then
			stop(
				`{outsideCount} spots outside the corridors change zone: {table.concat(
					outsideList,
					"; ",
					1,
					math.min(#outsideList, 6)
				)}`
			)
		end
	end

	-- the ladders: the truss points and the grass at each boot ladder's foot
	for _, name in LADDERS do
		local zones: { string } = {}
		for _, point in trussPoints(climbs[name]) do
			table.insert(zones, climberZone(point, wantZone, wantLadder))
		end
		local got = runs(zones)
		say(`{name} truss points, lowest first: {got}`)
		local wantRuns = TRUSS_RUNS[name] or `Boots x{#zones}`
		if got ~= wantRuns then
			stop(`{name} truss zones are {got}, not {wantRuns}`)
		end
		if string.sub(name, 1, 4) == "Boot" then
			local foot = trussPoints(climbs[name])[1]
			local grass = Vector3.new(foot.X, 2, foot.Z)
			local grassZone: string = Zones.zoneAt(grass, wantZone)
			say(`{name} foot grass {grass}: {grassZone} (zone boxes alone)`)
			if grassZone ~= "Meadow" then
				stop(`{name} foot grass is {grassZone}, not Meadow`)
			end
		end
	end

	if #stops > 0 then
		return finish("STOPPED: nothing changed")
	end
	if CHECK_ONLY then
		return finish("DRY RUN OK: nothing changed")
	end

	-- THE CHANGE, with its backup in the same call
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		local made = Instance.new("Folder")
		made.Name = "WorldBackups"
		made.Parent = ServerStorage
		backups = made
	end
	local done = true
	local mine = (backups :: Instance):FindFirstChild(BACKUP_NAME)
	if mine == nil and (pathThere or not cutDone) then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		zonesFolder:Clone().Parent = folder
		folder.Parent = backups
		say(`backup: ServerStorage.WorldBackups.{BACKUP_NAME}.Zones ({#zonesFolder:GetChildren()} boxes)`)
	end
	local path = zonesFolder:FindFirstChild("Belly_Path")
	if path then
		path:Destroy()
		done = false
		say("Belly_Path: removed")
	else
		say("Belly_Path: already done")
	end
	for _, want in wantZone do
		local part = zonesFolder:FindFirstChild(want.name) :: BasePart
		if want.name == "Belly_FrontA" and not same(part, want) then
			part.Size = want.size
			part.CFrame = want.cframe
			done = false
			say(`Belly_FrontA: cut to {fmt(want.size.Z)} deep at z {fmt(want.cframe.Z)}`)
		elseif want.name == "Belly_FrontA" then
			say("Belly_FrontA: already done")
		end
	end
	-- the 4 front boxes: a clone of the cut Belly_FrontA (same look and flags as the other zone boxes), resized
	local template = zonesFolder:FindFirstChild("Belly_FrontA") :: BasePart
	for _, want in wantFront do
		local existing = zonesFolder:FindFirstChild(want.name)
		if existing and existing:IsA("BasePart") and same(existing, want) then
			say(`{want.name}: already done`)
			continue
		end
		if existing then
			existing:Destroy()
		end
		local box = template:Clone()
		box.Name = want.name
		box.Size = want.size
		box.CFrame = want.cframe
		box:SetAttribute("Zone", want.zone)
		box.Parent = zonesFolder
		done = false
		say(`{want.name}: built, {want.zone}, centre {fmt(want.cframe.X)}, {fmt(want.cframe.Y)}, {fmt(want.cframe.Z)}`)
	end
	local folder = ladderFolder
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = "LadderBoxes"
		made.Parent = world
		folder = made
	end
	for _, want in wantLadder do
		local existing = (folder :: Instance):FindFirstChild(want.name)
		if existing and existing:IsA("BasePart") and same(existing, want) then
			say(`{want.name}: already done`)
			continue
		end
		if existing then
			existing:Destroy()
		end
		local box = Instance.new("Part")
		box.Name = want.name
		box.Anchored = true
		box.Transparency = 1
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		box.Size = want.size
		box.CFrame = want.cframe
		box:SetAttribute("Ladder", string.gsub(want.name, "^LadderBox_", ""))
		box:SetAttribute("Zone", want.zone)
		box.Parent = folder
		done = false
		say(`{want.name}: built, {want.zone}, size {fmt(want.size.X)} x {fmt(want.size.Y)} x {fmt(want.size.Z)}`)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("18-ladder-boxes-and-zones: after")
	end)
	return finish(if done then "already done" else "changed: see lines")
end

local ok, result = pcall(run)
if not ok then
	say(`STOPPED WITH AN ERROR: {result}`)
	return finish("ERROR")
end
return result
