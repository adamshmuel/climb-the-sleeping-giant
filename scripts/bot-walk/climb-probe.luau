--!strict
-- Task 22p Step 1: the climb probe (plan 5). Paste in the Play CLIENT once per zone slice, then again to read it.
-- Walks a 4-stud grid under his beard and along both flanks; lists every Climbing state away from the 4 ladders.
-- (no hold: Edit only) CHECK_ONLY = true is the Edit dry run: it counts points, sets nothing, needs no hold.
-- In Play, held() runs before every point. Nothing is left behind: no bind, the test truss destroyed in a pcall.
local CHECK_ONLY = true
local ZONE = "Beard" -- "Beard", "SideL", "SideR" or "Cup"
local FIRST, LAST = 1, 160 -- the slice of the zone's points this paste walks
local SHOW_FROM = 1 -- reading: the first climb row shown (5 rows per read)
local RERUN = false -- true: walk this slice again (a slice that lost 5 percent or more)
local STOP = false -- true: stop a run and destroy the test truss
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ROOT_OFFSET = 3.225 -- Config.luau line 170: the ground is this far under the root's middle
local REACH, PRESS_SECONDS, SETTLE_SECONDS = 3, 1, 2 -- studs for the 8 wall rays; seconds
local LADDER_NEAR = 3 -- studs: a climb this close to a ladder's Climb part is a real ladder
local MIN_FLOOR_Y = 0.65 -- StartCheck.luau HOLD_MIN_NORMAL_Y: flatter than this is a floor
local MAX_FAR, MAX_BELOW = 20, 3 -- "lost": over 20 studs from the start, or lower than start - 3
local TRUSS_NAME = "ProbeTestTruss"
local WALK = "Workspace.World.WalkSurfaces."
local LADDERS = { "BeardLadder", "CapLadder", "BootLadder_Left", "BootLadder_Right" }
-- Measured in Edit: head_with_beard x -46..46 y 47..119 z -19..61; body_and_cushion x -59..59 y -3..70 z -48..68. Beard: the belly under the beard (holds (-14,67,-14)). Sides and Cup: the meadow.
type Zone = { x: { number }, z: { number }, y: { number } }
local ZONES: { [string]: Zone } = {
	Beard = { x = { -30, 30 }, z = { -34, -6 }, y = { 40, 80 } },
	SideL = { x = { -66, -58 }, z = { -60, 40 }, y = { -1, 8 } },
	SideR = { x = { 58, 66 }, z = { -60, 40 }, y = { -1, 8 } },
	Cup = { x = { 56, 98 }, z = { 8, 52 }, y = { -1, 8 } },
}
type Point = { label: string, feet: Vector3 }

local function at(path: string): Instance?
	local node: Instance? = game
	for name in string.gmatch(path, "[^%.]+") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	return node
end
local function v(p: Vector3): string
	return string.format("(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
end
local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
pcall(function()
	rayParams.CollisionGroup = "Players" -- Collisions.GROUP; not registered in Edit, hence the pcall
end)

local function floorAt(x: number, z: number, zone: Zone): RaycastResult?
	local y = zone.y[2]
	for _ = 1, 4 do
		local hit = Workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, zone.y[1] - y, 0), rayParams)
		if hit == nil or hit.Normal.Y >= MIN_FLOOR_Y then
			return hit
		end
		y = hit.Position.Y - 0.05
	end
	return nil
end

local function buildPoints(name: string): { Point }
	local zone, points = ZONES[name], {}
	for x = zone.x[1], zone.x[2], 4 do
		for z = zone.z[1], zone.z[2], 4 do
			local hit = floorAt(x, z, zone)
			if hit then
				table.insert(points, { label = `{name}_{#points + 1}`, feet = hit.Position })
			end
		end
	end
	return points
end

-- True when the spot is within LADDER_NEAR of one of the 4 ladders' Climb parts (box distance).
local function nearLadder(p: Vector3): boolean
	for _, name in LADDERS do
		local part = at(WALK .. name .. ".Climb")
		if part and part:IsA("BasePart") then
			local rel, half = part.CFrame:PointToObjectSpace(p), part.Size / 2
			if (rel - rel:Max(-half):Min(half)).Magnitude <= LADDER_NEAR then
				return true
			end
		end
	end
	return false
end
local DIRECTIONS: { Vector3 } = {} -- 8 compass directions
for k = 0, 7 do
	table.insert(DIRECTIONS, Vector3.new(math.cos(math.rad(k * 45)), 0, math.sin(math.rad(k * 45))))
end
-- The first wall within reach round a spot: a ray at the feet and one at the root, steeper than a floor.
local function firstWall(feet: Vector3, only: Vector3?): RaycastResult?
	local dirs: { Vector3 } = if only then { only } else DIRECTIONS
	for _, dir in dirs do
		for _, lift in { 0.5, ROOT_OFFSET } do
			local hit = Workspace:Raycast(feet + Vector3.new(0, lift, 0), dir * REACH, rayParams)
			if hit and hit.Normal.Y < MIN_FLOOR_Y then
				return hit
			end
		end
	end
	return nil
end

local function destroyTruss()
	pcall(game.Destroy, Workspace:FindFirstChild(TRUSS_NAME) :: any)
end
if CHECK_ONLY then
	local out, found = {}, {}
	for _, name in LADDERS do
		table.insert(found, if at(WALK .. name .. ".Climb") then name else "MISSING " .. name)
	end
	table.insert(out, `{#found} ladder paths: {table.concat(found, " ")}`)
	for name, zone in ZONES do
		local points = buildPoints(name)
		table.insert(out, `{name} box x{zone.x[1]}..{zone.x[2]} z{zone.z[1]}..{zone.z[2]}: {#points} points`)
	end
	local spot, b = floorAt(-14, -14, ZONES.Beard), ZONES.Beard
	local inside = b.x[1] <= -14 and -14 <= b.x[2] and b.z[1] <= -14 and -14 <= b.z[2] and b.y[1] <= 67 and 67 <= b.y[2]
	table.insert(out, `beard box holds (-14,67,-14): {inside}, floor there {if spot then v(spot.Position) else "none"}`)
	table.insert(out, "no Play: nothing set")
	return string.sub(table.concat(out, "\n"), 1, 1000)
end

-- selene: allow(global_usage)
local sh: any = shared
sh.T22pReport = sh.T22pReport or { zones = {} }
if STOP then
	sh.T22pStop = true
	destroyTruss()
	return "stopped: flag set, ProbeTestTruss destroyed"
end
local key = `{ZONE}_{FIRST}`
local zones: { [string]: any } = sh.T22pReport.zones
local old = zones[key]

if old ~= nil and not RERUN then
	local lines = { `{key} point {old.i}/{old.total} stopped {old.stopped}` }
	table.insert(lines, `ladder {old.ladders}, climbs {#old.climbs}, lost {#old.lost}, void {old.voids}; {old.test}`)
	table.insert(lines, table.concat(old.climbs, "\n", SHOW_FROM, math.min(#old.climbs, SHOW_FROM + 4)))
	table.insert(lines, if old.done then "end of report" else "fetch again")
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

-- Copied from scripts/studio/session-hold.luau (the run check), in one expression.
local function held(): (boolean, string)
	local rs = game:GetService("ReplicatedStorage")
	local beat, phase = rs:GetAttribute("TrialHoldBeat"), rs:GetAttribute("TrialHoldPhase")
	local fresh = type(beat) == "number" and Workspace:GetServerTimeNow() - beat <= 2
	return fresh and phase == "Asleep", if fresh then "phase " .. tostring(phase) else "no fresh beat"
end
if not held() then
	return "STOP: giant not held (paste scripts/studio/session-hold.luau on the Server first)"
end
local all, points = buildPoints(ZONE), {}
for index = FIRST, math.min(LAST, #all) do
	table.insert(points, all[index])
end
assert(#points > 0, `{key} has no points ({#all} in the zone)`)
local report: any = { total = #points, i = 0, done = false, climbs = {}, lost = {}, ladders = 0, voids = 0, test = "" }
zones[key] = report
sh.T22pStop = false
local curFound: string? = nil
local function runAll()
	local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local curDir, curLabel = Vector3.zero, ""
	humanoid.AutoJumpEnabled = false
	local function place(feet: Vector3): boolean
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(CFrame.new(feet + Vector3.new(0, ROOT_OFFSET, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
		local waited = 0
		while waited < 3 and humanoid.FloorMaterial == Enum.Material.Air do
			waited += task.wait()
		end
		return humanoid.FloorMaterial ~= Enum.Material.Air
	end
	local connection = humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Climbing and curFound == nil then
			local hit = Workspace:Raycast(root.Position, curDir * REACH, rayParams)
			local part = if hit then hit.Instance:GetFullName() else "no hit"
			curFound = `{curLabel} root{v(root.Position)} {part}`
		end
	end)
	local function press(dir: Vector3)
		curDir = dir
		local began = os.clock()
		while os.clock() - began < PRESS_SECONDS and curFound == nil and not sh.T22pStop do
			humanoid:MoveTo(root.Position + dir * 6) -- controls left on, never Move
			task.wait()
		end
		humanoid:MoveTo(root.Position)
	end
	local function leg(point: Point): (string, string)
		curFound, curLabel = nil, point.label
		if not place(point.feet) then
			return "lost", "air"
		end
		task.wait(SETTLE_SECONDS)
		for _, dir in DIRECTIONS do
			if firstWall(point.feet, dir) and not sh.T22pStop then
				press(dir)
				if curFound or (flat(root.Position - point.feet).Magnitude > 1 and not place(point.feet)) then
					break
				end
			end
		end
		local feet = root.Position - Vector3.new(0, ROOT_OFFSET, 0)
		if curFound and nearLadder(root.Position) then
			return "ladder", "within 3 studs of a ladder"
		elseif curFound then
			return "climb", curFound
		end
		local far, drop = (feet - point.feet).Magnitude, point.feet.Y - feet.Y
		return if far > MAX_FAR or drop > MAX_BELOW then "lost" else "free",
			string.format("far %.1f drop %.1f", far, drop)
	end
	local function runPoint(point: Point)
		local ready, why, tries = held(), "", 0
		while not ready and tries < 5 do
			tries += 1
			task.wait(1)
			ready, why = held()
		end
		if not ready then
			report.voids += 1
			report.test = `{report.test}; void: {why}`
			return
		end
		local outcome, detail = leg(point)
		if outcome == "lost" then
			outcome, detail = leg(point) -- retried once from the start, never counted as a pass
		end
		if outcome == "lost" then
			table.insert(report.lost, `{point.label} {detail}`)
		elseif outcome == "ladder" then
			report.ladders += 1
		elseif outcome == "climb" then
			table.insert(report.climbs, detail)
		end
	end
	-- Input check: the first open start (no wall in reach); it must hold still 2 s, then a 1 s walk moves 8 studs.
	local free: Point? = nil
	for index = 1, math.min(10, #points) do
		free = free or if firstWall(points[index].feet) then nil else points[index]
	end
	if free == nil or not place(free.feet) then
		report.stopped = "INPUT DEAD (no open start for the free walk)"
		return
	end
	task.wait(SETTLE_SECONDS)
	local settled = root.Position
	press(DIRECTIONS[1])
	local drift, moved = flat(settled - free.feet).Magnitude, flat(root.Position - settled).Magnitude
	report.test = string.format("input drift %.1f walk %.1f studs", drift, moved)
	if drift > 1 or moved < 8 then
		report.stopped = "INPUT DEAD (drift over 1 stud, or under 8 studs in 1 s)"
		return
	end
	-- Test leg (Beard only): a Client-made truss against the first wall; it must be listed as a climb.
	for _, point in points do
		local wall = if ZONE == "Beard" then firstWall(point.feet) else nil
		if wall then
			local truss = Instance.new("TrussPart")
			truss.Name = TRUSS_NAME
			truss.Size = Vector3.new(2, 6, 2)
			truss.Anchored = true
			truss.Position = Vector3.new(wall.Position.X, point.feet.Y + 3, wall.Position.Z) + flat(wall.Normal)
			truss.Parent = Workspace
			local outcome = leg({ label = "TEST", feet = point.feet })
			destroyTruss()
			report.test = `{report.test}; test truss {v(truss.Position)} {outcome} (a climb is listed)`
			break
		end
	end
	for index, point in points do
		if sh.T22pStop then
			report.stopped = "stop flag"
			break
		end
		report.i = index
		runPoint(point)
	end
	connection:Disconnect()
end

task.spawn(function()
	local ok, failure = (pcall :: any)(runAll)
	if not ok then
		report.stopped = tostring(failure)
	end
	destroyTruss()
	report.done = true
end)
return `started {key}: {#points} of {#all} points, ends in about {#points * 5 + 20} s`
