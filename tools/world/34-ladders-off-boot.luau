--!strict
-- World prep, plan 3 (gardens and ways up) Task 5b2: the boot ladders stand off the boot
-- (docs/plans/v2/egg-nests-and-climbing.md "5b2"; spec Rule 103 (Nothing sinks into a main character), Rule 37, Rule 15).
-- Card: work/t5b2/card.md; the numbers: work/t5b2/5b2-scripts.md section B.
-- What it does: moves BOTH whole BootLadder_* models 1.6 studs out from the boot (Climb, Look.Rail, Look.Rung: CFrame
-- + side x 1.6; Look.Hook: Size.Z 2.2 -> 3.8 and CFrame + side x 0.8, so the peg end stays; TopPad: Size.X 3.5 -> 5.1 and
-- Position.X + side x 0.8, so the inner edge stays; Look.Peg stays) and LandingSpot_7 from (54, -64) to (56, -62).
-- side = -1 left, 1 right. Before any change it clones both models and LandingSpot_7 into ServerStorage.WorldBackups.t5b2
-- (attribute BackupOf = the old full path; one already there is left alone) and sets a ChangeHistoryService waypoint.
-- Every part at its new value = "already done", nothing changes. A mix of old and new, a wrong count, an unknown part,
-- left and right that are not mirrors, or any failed dry-run measure = STOP, nothing changes.
-- Rollback: paste the clones back. CHECK_ONLY = true measures and prints only. Full report: shared.T5b2Report (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["34-ladders-off-boot"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local requireModule: (Instance) -> any = require :: any
-- The measure is tools/checks/SinkDepth.luau (a clone, so an edited copy is read).
local SinkDepth =
	requireModule(ServerStorage:WaitForChild("Tools"):WaitForChild("checks"):WaitForChild("SinkDepth"):Clone())
type CharacterPart = { part: BasePart, params: RaycastParams, min: Vector3, max: Vector3 } -- as SinkDepth.CharacterPart

local BACKUP_NAME = "t5b2"
local MAIN_TAG = "MainCharacter"
local SHIFT = 1.6 -- studs, whole ladder out
local HALF_SHIFT = 0.8 -- hook centre and pad centre
local TOL = 0.05
local STEP = 0.85 -- studs between the dense points along a face
local NEST = Vector3.new(28.5, 30.4, -64.5) -- |x|; the outer toe nest spot (spec 5)
local SPOT_OLD = Vector3.new(54, 1.9, -64)
local SPOT_NEW = Vector3.new(56, 1.9, -62)
local PLAIN_COUNTS: { [string]: number } = { Rail = 2, Rung = 21, Hook = 2, Peg = 2 }
local DENSE_KINDS = { "Rail", "Rung", "Hook", "Climb", "TopPad" }

type Op = {
	label: string,
	kind: string,
	side: number,
	part: BasePart,
	state: string, -- "old", "new", "keep" (a peg) or "?" (neither)
	planCF: CFrame,
	planSize: Vector3,
}

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

local function fmtV(v: Vector3): string
	return `({fmt(v.X)}, {fmt(v.Y)}, {fmt(v.Z)})`
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= TOL
end

-- The top and bottom end (by height) of a part, along its Z axis.
local function endsOf(part: BasePart): (Vector3, Vector3)
	local half = part.CFrame.LookVector * (part.Size.Z / 2)
	local a, b = part.Position + half, part.Position - half
	if a.Y >= b.Y then
		return a, b
	end
	return b, a
end

local function backup(roots: { Instance })
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	local folder = backups:FindFirstChild(BACKUP_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		folder.Parent = backups
	end
	for _, root in roots do
		local path = root:GetFullName()
		local have = false
		for _, saved in folder:GetChildren() do
			if saved:GetAttribute("BackupOf") == path and saved.Name == root.Name then
				have = true
			end
		end
		if not have then
			local copy = root:Clone()
			copy:SetAttribute("BackupOf", path)
			copy.Parent = folder
		end
	end
end

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.T5b2Report = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

local world = Workspace:WaitForChild("World")
local characters: { CharacterPart } = SinkDepth.characterParts(MAIN_TAG)
if #characters == 0 then
	return "STOP: no MainCharacter parts found; nothing changed"
end
local surfaces = world.WalkSurfaces

-- 1. Find and classify every part of both ladders. Every lookup prints "found N of M".
local ops: { Op } = {}
local models: { Model } = {}
for _, side in { -1, 1 } do
	local name = if side < 0 then "BootLadder_Left" else "BootLadder_Right"
	local model = surfaces:FindFirstChild(name)
	if model == nil or not model:IsA("Model") then
		return `STOP: {name} not found (found 0 of 1); nothing changed`
	end
	table.insert(models, model)
	local counts: { [string]: number } = {}
	local climb: BasePart? = nil
	local pad: BasePart? = nil
	for _, child in model:GetChildren() do
		if child.Name == "Climb" and child:IsA("BasePart") then
			climb = child
		elseif child.Name == "TopPad" and child:IsA("BasePart") then
			pad = child
		elseif child.Name == "Look" and child:IsA("Model") then
			for _, part in child:GetChildren() do
				if PLAIN_COUNTS[part.Name] ~= nil and part:IsA("BasePart") then
					counts[part.Name] = (counts[part.Name] or 0) + 1
					table.insert(ops, {
						label = `{name}.Look.{part.Name}`,
						kind = part.Name,
						side = side,
						part = part,
						state = "?",
						planCF = part.CFrame,
						planSize = part.Size,
					})
				else
					stop(`{name}.Look holds an unexpected {part.ClassName} {part.Name}`)
				end
			end
		else
			stop(`{name} holds an unexpected {child.ClassName} {child.Name}`)
		end
	end
	if climb == nil or pad == nil then
		return `STOP: {name} lacks Climb or TopPad; nothing changed`
	end
	table.insert(ops, {
		label = `{name}.Climb`,
		kind = "Climb",
		side = side,
		part = climb,
		state = "?",
		planCF = climb.CFrame,
		planSize = climb.Size,
	})
	table.insert(ops, {
		label = `{name}.TopPad`,
		kind = "TopPad",
		side = side,
		part = pad,
		state = "?",
		planCF = pad.CFrame,
		planSize = pad.Size,
	})
	local found = {}
	for kind, want in PLAIN_COUNTS do
		table.insert(found, `{kind} {counts[kind] or 0} of {want}`)
		if (counts[kind] or 0) ~= want then
			stop(`{name}: {kind} count {counts[kind] or 0}, want {want}`)
		end
	end
	table.sort(found)
	say(`found {name}: Climb 1 of 1, TopPad 1 of 1, {table.concat(found, ", ")}`)
end
local spot = world.LandingSpots:FindFirstChild("LandingSpot_7")
if spot == nil or not spot:IsA("BasePart") then
	return "STOP: LandingSpot_7 not found (found 0 of 1); nothing changed"
end
local spotNow = spot.Position
local spotState = if (spotNow - SPOT_OLD).Magnitude <= TOL
	then "old"
	elseif (spotNow - SPOT_NEW).Magnitude <= TOL then "new"
	else "?"

-- 2. The state of each part, absolute (the rungs follow their Climb).
local climbState: { [number]: string } = {}
for _, op in ops do
	local part = op.part
	local absX = math.abs(part.Position.X)
	if op.kind == "Climb" then
		local topEnd = endsOf(part)
		local sizeOk = near(part.Size.X, 2) and near(part.Size.Y, 2) and near(part.Size.Z, 34)
		if not sizeOk then
			stop(`{op.label} size {fmtV(part.Size)}, want 2 x 2 x 34`)
		end
		op.state = if near(math.abs(topEnd.X), 32.4) then "old" elseif near(math.abs(topEnd.X), 34.0) then "new" else "?"
		climbState[op.side] = op.state
	elseif op.kind == "Rail" then
		op.state = if near(absX, 40.5) then "old" elseif near(absX, 42.1) then "new" else "?"
	elseif op.kind == "Hook" then
		local alongX = math.abs(part.CFrame.LookVector.X) > 0.99
		if not alongX then
			stop(`{op.label} long axis is not along x`)
		end
		if near(part.Size.Z, 2.2) and near(absX, 30.9) then
			op.state = "old"
		elseif near(part.Size.Z, 3.8) and near(absX, 31.7) then
			op.state = "new"
		end
	elseif op.kind == "TopPad" then
		if not (near(part.Size.Y, 1) and near(part.Size.Z, 5)) then
			stop(`{op.label} size {fmtV(part.Size)}, want Y 1 and Z 5`)
		end
		if near(part.Size.X, 3.5) and near(absX, 30.75) then
			op.state = "old"
		elseif near(part.Size.X, 5.1) and near(absX, 31.55) then
			op.state = "new"
		end
	elseif op.kind == "Peg" then
		op.state = "keep"
	end
end
for _, op in ops do
	if op.kind == "Rung" then
		op.state = climbState[op.side] or "?"
	end
end
local states: { [string]: number } = {}
for _, op in ops do
	if op.state ~= "keep" then
		states[op.state] = (states[op.state] or 0) + 1
		if op.state == "?" then
			stop(`{op.label} at {fmtV(op.part.Position)} is at neither the old nor the new value`)
		end
	end
end
states[spotState] = (states[spotState] or 0) + 1
if spotState == "?" then
	stop(`LandingSpot_7 at {fmtV(spotNow)} is at neither (54, 1.9, -64) nor (56, 1.9, -62)`)
end
local allOld = (states.old or 0) == #ops - 4 + 1 and (states.new or 0) == 0
local allNew = (states.new or 0) == #ops - 4 + 1 and (states.old or 0) == 0
if not allOld and not allNew and #stops == 0 then
	stop(`a mix of old ({states.old or 0}) and new ({states.new or 0}) parts`)
end

-- 3. Left and right must be mirrors (x turned round, within 0.05).
local function sortedOf(side: number, kind: string): { Op }
	local list: { Op } = {}
	for _, op in ops do
		if op.side == side and op.kind == kind then
			table.insert(list, op)
		end
	end
	table.sort(list, function(a: Op, b: Op): boolean
		if not near(a.part.Position.Y, b.part.Position.Y) then
			return a.part.Position.Y < b.part.Position.Y
		end
		return a.part.Position.Z < b.part.Position.Z
	end)
	return list
end
local mirrorBad = 0
for _, kind in { "Climb", "TopPad", "Rail", "Rung", "Hook", "Peg" } do
	local left, right = sortedOf(-1, kind), sortedOf(1, kind)
	for index, l in left do
		local r = right[index]
		if
			r == nil
			or not near(l.part.Position.X, -r.part.Position.X)
			or not near(l.part.Position.Y, r.part.Position.Y)
			or not near(l.part.Position.Z, r.part.Position.Z)
			or (l.part.Size - r.part.Size).Magnitude > TOL
		then
			mirrorBad += 1
			if mirrorBad == 1 then
				stop(`left and right are not mirrors at {l.label} {fmtV(l.part.Position)}`)
			end
		end
	end
end
say(`mirror check: {mirrorBad} bad`)

-- 4. The planned values.
for _, op in ops do
	if op.state == "old" then
		local push = op.side * SHIFT
		if op.kind == "Hook" then
			op.planSize = Vector3.new(op.part.Size.X, op.part.Size.Y, 3.8)
			op.planCF = op.part.CFrame + Vector3.new(op.side * HALF_SHIFT, 0, 0)
		elseif op.kind == "TopPad" then
			op.planSize = Vector3.new(5.1, op.part.Size.Y, op.part.Size.Z)
			op.planCF = op.part.CFrame + Vector3.new(op.side * HALF_SHIFT, 0, 0)
		else
			op.planCF = op.part.CFrame + Vector3.new(push, 0, 0)
		end
	end
end
local spotPlan = if spotState == "old"
	then spot.CFrame.Rotation + Vector3.new(SPOT_NEW.X, spotNow.Y, SPOT_NEW.Z)
	else spot.CFrame
local spotAt = spotPlan.Position

-- Dry-run print 1: before -> after, per kind (first and last rung only).
local function planned(label: string, op: Op)
	say(
		`{label} {op.part.Name} {fmtV(op.part.Position)} -> {fmtV(op.planCF.Position)} size {fmtV(op.planSize)} [{op.state}]`
	)
end
for _, side in { -1, 1 } do
	local tag = if side < 0 then "L" else "R"
	local rungs = sortedOf(side, "Rung")
	for _, kind in { "Climb", "TopPad", "Rail", "Hook", "Peg" } do
		local first = sortedOf(side, kind)[1]
		if first ~= nil then
			planned(`1 {tag}`, first)
		end
	end
	if #rungs > 0 then
		planned(`1 {tag} first`, rungs[1])
		planned(`1 {tag} last`, rungs[#rungs])
	end
end
say(`1 Spot7 {fmtV(spotNow)} -> {fmtV(spotAt)} [{spotState}]`)

-- Dry-run print 2: truss top end, where its centre line crosses y 2, distance to the nest spot.
local giantParams = RaycastParams.new()
giantParams.FilterType = Enum.RaycastFilterType.Include
giantParams.FilterDescendantsInstances = { world.Giant }
for _, side in { -1, 1 } do
	local climb = sortedOf(side, "Climb")[1]
	if climb ~= nil then
		local half = climb.planCF.LookVector * (climb.planSize.Z / 2)
		local a, b = climb.planCF.Position + half, climb.planCF.Position - half
		local top, bottom = a, b
		if b.Y > a.Y then
			top, bottom = b, a
		end
		local dir = top - bottom
		local cross = top + dir * ((2 - top.Y) / dir.Y)
		local nest = Vector3.new(side * NEST.X, NEST.Y, NEST.Z)
		say(
			`2 {side} top end {fmtV(top)}, centre line crosses y 2 at x {fmt(cross.X)}, top end to nest {fmt(
				(top - nest).Magnitude
			)}`
		)
		if not (near(math.abs(top.X), 34.0) and math.abs(math.abs(cross.X) - 50.2) <= 0.5) then
			stop(`2 truss top end or foot crossing is off: top x {fmt(top.X)}, crossing x {fmt(cross.X)}`)
		end
		-- Dry-run print 3: the pad edges and the ray down on the giant.
		local pad = sortedOf(side, "TopPad")[1]
		if pad ~= nil then
			local lowX = pad.planCF.Position.X - pad.planSize.X / 2
			local highX = pad.planCF.Position.X + pad.planSize.X / 2
			local hit = Workspace:Raycast(Vector3.new(side * 29, 60, -64), Vector3.new(0, -80, 0), giantParams)
			local hitY = if hit ~= nil then hit.Position.Y else -1
			say(`3 {side} pad x edges {fmt(lowX)} to {fmt(highX)}, giant hit y at x {side * 29}: {fmt(hitY)}`)
			if hit == nil or hitY < 30.1 then
				stop(`3 giant ray at x {side * 29} hit y {fmt(hitY)}, want 30.1 or more`)
			end
		end
	end
end

-- Dry-run print 4: dense worst per kind, measured on the PLANNED frames.
type Dense = { worst: number, failing: number, total: number, count: number }
local dense: { [string]: Dense } = {}
for _, op in ops do
	if table.find(DENSE_KINDS, op.kind) ~= nil then
		local entry: Dense = dense[op.kind] or { worst = 0, failing = 0, total = 0, count = 0 }
		for _, face in SinkDepth.faceDepths(op.planCF, op.planSize, characters, STEP) do
			entry.failing += face.failing
			entry.total += face.total
			entry.worst = math.max(entry.worst, face.worst)
		end
		entry.count += 1
		dense[op.kind] = entry
	end
end
for _, kind in DENSE_KINDS do
	local entry = dense[kind]
	if entry ~= nil then
		say(
			`4 dense {kind}: {entry.count} parts, worst {fmt(entry.worst)}, {entry.failing} of {entry.total} points failing`
		)
		if entry.failing > 0 and (kind == "Rail" or kind == "Rung" or kind == "Hook") then
			stop(`4 dense {kind} fails: {entry.failing} of {entry.total}, worst {fmt(entry.worst)}`)
		end
	end
end

-- Dry-run print 5: the new spot.
local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function posOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end
local nearestEgg, nearestEggName = math.huge, ""
for _, child in world.EggSpots:GetChildren() do
	local at = posOf(child)
	if at ~= nil and flat(at, spotAt) < nearestEgg then
		nearestEgg, nearestEggName = flat(at, spotAt), child.Name
	end
end
local nearestSpot, nearestSpotName = math.huge, ""
for _, child in world.LandingSpots:GetChildren() do
	local at = posOf(child)
	if child ~= spot and at ~= nil and flat(at, spotAt) < nearestSpot then
		nearestSpot, nearestSpotName = flat(at, spotAt), child.Name
	end
end
local nearestFoot = math.huge
for _, op in ops do
	if op.kind == "Rail" then
		local half = op.planCF.LookVector * (op.planSize.Z / 2)
		local foot = op.planCF.Position - half
		if (op.planCF.Position + half).Y < foot.Y then
			foot = op.planCF.Position + half
		end
		nearestFoot = math.min(nearestFoot, flat(foot, spotAt))
	end
end
say(
	`5 spot {fmtV(spotAt)}: nearest egg spot {nearestEggName} {fmt(nearestEgg)}, nearest landing spot {nearestSpotName} {fmt(
		nearestSpot
	)}, nearest moved rail foot {fmt(nearestFoot)}`
)
if nearestEgg < 10 or nearestSpot < 10 or nearestFoot < 5 then
	stop(`5 spot distances: egg {fmt(nearestEgg)}, landing {fmt(nearestSpot)}, rail foot {fmt(nearestFoot)}`)
end
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
local ground = Workspace:Raycast(Vector3.new(spotAt.X, 30, spotAt.Z), Vector3.new(0, -60, 0), terrainParams)
if ground == nil then
	stop("5 no Terrain under the new spot")
else
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { spot }
	local function boxList(size: Vector3): { BasePart }
		local list: { BasePart } = {}
		for _, part in
			Workspace:GetPartBoundsInBox(CFrame.new(spotAt.X, ground.Position.Y + size.Y / 2, spotAt.Z), size, overlap)
		do
			if not part:IsA("Terrain") then
				table.insert(list, part)
			end
		end
		return list
	end
	local small, big = boxList(Vector3.new(4, 6, 4)), boxList(Vector3.new(5, 6, 5))
	local solid = 0
	for _, part in small do
		if part.CanCollide then
			solid += 1
			stop(`5 a CanCollide part in the 4 x 6 x 4 box above the spot: {part:GetFullName()}`)
		end
	end
	local names: { string } = {}
	for _, part in big do
		table.insert(names, `{part:GetFullName()}(cc={part.CanCollide})`)
	end
	say(`5 terrain y {fmt(ground.Position.Y)}; 4x6x4 box: {#small} parts, {solid} CanCollide; 5x6x5 box: {#big} parts`)
	for index, name in names do
		if index <= 8 then
			say(`5 box part: {name}`)
		end
	end
end
-- The designer's clear view behind the spot: no model whose middle is 1 to 12 studs behind it and within 3 to a side.
local outward = Vector3.new(spotAt.X, 0, spotAt.Z).Unit
local behind: { string } = {}
local checkedModels = 0
for _, folderName in { "Nature", "GiantsThings" } do
	local root = world:FindFirstChild(folderName)
	if root ~= nil then
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("Model") then
				local inside = false
				local up = descendant.Parent
				while up ~= nil and up ~= root do
					if up:IsA("Model") then
						inside = true
						break
					end
					up = up.Parent
				end
				if not inside then
					checkedModels += 1
					local middle = descendant:GetBoundingBox().Position
					local rel = Vector3.new(middle.X - spotAt.X, 0, middle.Z - spotAt.Z)
					local along = rel:Dot(outward)
					local sideways = math.abs(rel:Cross(outward).Y)
					if along >= 1 and along <= 12 and sideways <= 3 then
						table.insert(behind, `{descendant:GetFullName()} along {fmt(along)} side {fmt(sideways)}`)
					end
				end
			end
		end
	end
end
say(`5 view behind the spot: {checkedModels} models checked, {#behind} in the box`)
for index, text in behind do
	if index <= 6 then
		say(`5 behind: {text}`)
	end
end
if #behind > 0 then
	stop(`5 {#behind} model(s) stand in the clear view behind the spot, first: {behind[1]}`)
end

-- Dry-run print 6: the route point's gap to the closest moved rail.
local routePoint = world.Route:FindFirstChild("RoutePoint_Meadow_11")
if routePoint == nil or not routePoint:IsA("BasePart") then
	stop("6 RoutePoint_Meadow_11 not found")
else
	local gap = math.huge
	for _, op in ops do
		if op.kind == "Rail" and op.side == 1 then
			gap = math.min(gap, math.abs(op.planCF.Position.Z - routePoint.Position.Z))
		end
	end
	say(`6 RoutePoint_Meadow_11 {fmtV(routePoint.Position)}: z gap to the closest moved right rail {fmt(gap)}`)
end

-- Decide.
if #stops > 0 then
	return finish(`STOP: {#stops} stop(s), nothing changed; first: {stops[1]}`)
end
if allNew then
	return finish("already done: every ladder part and LandingSpot_7 is at its new value, nothing changed")
end
if CHECK_ONLY then
	return finish(`CHECK_ONLY: would move {#ops - 4} ladder parts and LandingSpot_7, no stop fired, changed nothing`)
end

local toBack: { Instance } = { models[1], models[2], spot }
backup(toBack)
ChangeHistoryService:SetWaypoint("34-ladders-off-boot: before")
for _, op in ops do
	if op.state == "old" then
		if op.kind == "Hook" or op.kind == "TopPad" then
			op.part.Size = op.planSize
		end
		op.part.CFrame = op.planCF
	end
end
spot.CFrame = spotPlan
ChangeHistoryService:SetWaypoint("34-ladders-off-boot: after")
return finish(`changed {#ops - 4} ladder parts and LandingSpot_7; backup in ServerStorage.WorldBackups.{BACKUP_NAME}`)
