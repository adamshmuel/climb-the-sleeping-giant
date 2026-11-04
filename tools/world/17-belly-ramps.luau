--!strict
-- World prep, plan 3 (gardens and ways up) Task 6a: the two belly ramps and their edge guards
-- (docs/plans/v2/gardens-and-ways-up.md, "Task 6" and its split lines; spec Rule 45 (One way onto the belly) and
-- Rule 15 (The climb needs no jump)). Card: work/t6/handoff.md.
-- Why: the mockup ramps are only a picture. Players need two real ramps from the lap landing up onto his belly, with
-- invisible edge guards where the skin beside the ramp is too steep to stand on.
-- What it does (everything lands in Workspace.World.WalkSurfaces):
--   * BellyRamp_Left / _Right: one invisible solid piece (5 wide, 0.6 thick, level across) per station pair of the
--     16 LeftStations of Mockup_Nests.RampBuild_CodeLead (the right ramp is the exact mirror), pieces lengthened at the
--     bends so the outer corners close, plus one last piece up the same 45 degree line until its top meets his skin;
--     under each piece an invisible solid Fill block down to the deck or his skin (its top is under the piece, so it
--     adds no step);
--   * RampEdgeGuards: invisible solid WedgeParts (0.3 thick, vertical face toward the ramp) on an edge line wherever
--     the edge rays find steep skin (normal Y 0.342 or less) or open air. Not over the landing deck, not from the belly
--     join (z -40.3) on, not where the skin beside the ramp is walkable (those stretches are printed for Task 6c);
--   * EggSpot_Rare_1 and RoutePoint_Egg_Rare_1 are lifted straight up (the measured gap, at most 0.55) so the egg's Base
--     sits on the ramp.
-- Before any change it clones LapLanding, EggSpot_Rare_1 and RoutePoint_Egg_Rare_1 into
-- ServerStorage.WorldBackups.Plan3Task6 (an existing one is left alone). Rollback: delete BellyRamp_*, RampEdgeGuards
-- and paste the clones back. Worlds, checked before any change: both ramps there = "already done"; none = build; anything
-- else = stop. CHECK_ONLY = true runs the checks only and changes nothing.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau (or require a copy of it).

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "Plan3Task6"
local WIDTH = 6
local HALF = WIDTH / 2
local THICK = 0.6
local DECK_BACK_Z = -46.5
local DECK_EDGE_X = 5.6
local JOIN_Z = -40.3 -- from here on the ramp joins the belly: no guard
local STEEP_NORMAL_Y = 0.342
local GUARD_THICK = 0.3
local GUARD_ABOVE = 8
local FACE_IN = 0.25 -- the inner face sits this far inside the edge line (ruling: 2.2 to 2.5 from the centre line)
local GUARD_BELOW = 1.5
local EDGE_STEP = 0.5
local EDGE_OUT = 0.3
local END_Z_MIN, END_Z_MAX = -39.85, -39.55
local MAX_LIFT = 0.55 -- code_lead ruling (work/t6/egg-lift-ruling.md): lift = the measured gap, cap 0.55
local FILL_DEPTH_CAP = 3
local BEND_MIN = math.rad(1)
local GROUP_BEND = math.rad(1.5) -- a heading change over this starts a new straight run for the guards
local UP = Vector3.new(0, 1, 0)
local SIDES = { { label = "Left", sign = 1 }, { label = "Right", sign = -1 } }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function clearMockup(root: Instance)
	for _, d in root:GetDescendants() do
		for name in d:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				d:SetAttribute(name, nil)
			end
		end
	end
end

local function solid(part: BasePart)
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	part.CastShadow = false
end

local function newGuard(name: string, cf: CFrame, length: number, height: number): WedgePart
	local g = Instance.new("WedgePart")
	g.Name = name
	g.Size = Vector3.new(length, height, GUARD_THICK)
	g.CFrame = cf
	solid(g)
	return g
end

local function groundParams(extra: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip: { Instance } = {}
	for _, child in Workspace:GetChildren() do
		if string.sub(child.Name, 1, 7) == "Mockup_" then
			table.insert(skip, child)
		end
	end
	if extra ~= nil then
		for _, e in extra do
			table.insert(skip, e)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

local function readStations(): { Vector3 }
	local source: Instance? = nil
	local nests = Workspace:FindFirstChild("Mockup_Nests")
	if nests ~= nil then
		source = nests:FindFirstChild("RampBuild_CodeLead", true)
	end
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	if source == nil and library ~= nil then
		source = library:FindFirstChild("RampBuild_CodeLead", true)
	end
	if source == nil then
		error("nothing was changed. RampBuild_CodeLead (the LeftStations) is missing")
	end
	local text = (source :: Instance):GetAttribute("LeftStations")
	if typeof(text) ~= "string" then
		error("nothing was changed. RampBuild_CodeLead has no LeftStations text")
	end
	local list: { Vector3 } = {}
	for record in string.gmatch(text :: string, "[^;]+") do
		local x, y, z = string.match(record, "(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)")
		table.insert(list, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number))
	end
	if #list < 2 then
		error("nothing was changed. LeftStations has fewer than 2 stations")
	end
	return list
end

-- The ramp's top height under a flat point: nearest point on the centre polyline, height lerped along its segment.
local function heightAt(verts: { Vector3 }, p: Vector3): number
	local best, bestY = math.huge, verts[1].Y
	for i = 1, #verts - 1 do
		local a, b = flat(verts[i]), flat(verts[i + 1])
		local ab = b - a
		local t = math.clamp((flat(p) - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (flat(p) - (a + ab * t)).Magnitude
		if d < best then
			best = d
			bestY = verts[i].Y + (verts[i + 1].Y - verts[i].Y) * t
		end
	end
	return bestY
end

-- Where the last piece ends: the horizontal distance past the last station at which the 45 degree line meets his skin.
local function lastPieceLength(last: Vector3, dir: Vector3, params: RaycastParams): (number, number)
	local h = flat(dir).Unit
	local slope = dir.Y / flat(dir).Magnitude
	local measured = 0
	for i = 0, 80 do
		local s = i * 0.025
		local p = last + h * s
		local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 20, p.Z), Vector3.new(0, -40, 0), params)
		if hit ~= nil and hit.Position.Y >= last.Y + slope * s - 0.02 then
			measured = s
			break
		end
	end
	local sMin = (END_Z_MIN - last.Z) / h.Z
	local sMax = (END_Z_MAX - last.Z) / h.Z
	return math.clamp(measured, sMin, sMax), measured
end

type Edge = { a: Vector3, b: Vector3, out: Vector3, ia: number, ib: number }

-- Straight runs of the centre line (heading changes over GROUP_BEND start a new one): the edge line of each run, per
-- side, from miter point to miter point.
local function edgeRuns(verts: { Vector3 }, sideSign: number): { Edge }
	local n = #verts
	local perp: { Vector3 } = {}
	for i = 1, n - 1 do
		local d = flat(verts[i + 1] - verts[i]).Unit
		perp[i] = Vector3.new(d.Z, 0, -d.X)
	end
	local function miter(k: number): Vector3
		local pa = perp[math.max(k - 1, 1)]
		local pb = perp[math.min(k, n - 1)]
		return (pa + pb) / (1 + pa:Dot(pb)) * HALF * sideSign
	end
	local runs: { Edge } = {}
	local start = 1
	for k = 2, n do
		local boundary = k == n
		if not boundary then
			local da, db = flat(verts[k] - verts[k - 1]).Unit, flat(verts[k + 1] - verts[k]).Unit
			boundary = math.acos(math.clamp(da:Dot(db), -1, 1)) > GROUP_BEND
		end
		if boundary then
			local a, b = verts[start] + miter(start), verts[k] + miter(k)
			local dir = flat(b - a).Unit
			table.insert(runs, {
				a = Vector3.new(a.X, 0, a.Z),
				b = Vector3.new(b.X, 0, b.Z),
				out = Vector3.new(dir.Z, 0, -dir.X) * sideSign,
				ia = start,
				ib = k,
			})
			start = k
		end
	end
	return runs
end

type Stretch = { s0: number, s1: number, why: string }

-- Rays down every EDGE_STEP along one run's edge line (EDGE_OUT outside it): the stretches that need a guard.
local function classify(verts: { Vector3 }, run: Edge, params: RaycastParams, walkable: { string }): { Stretch }
	local len = (run.b - run.a).Magnitude
	local dir = (run.b - run.a).Unit
	local stretches: { Stretch } = {}
	local open: Stretch? = nil
	local steps = math.ceil(len / EDGE_STEP)
	for i = 0, steps do
		local s = math.min(i * EDGE_STEP, len)
		local q = run.a + dir * s + run.out * EDGE_OUT
		local why: string? = nil
		local noGuard = q.Z >= JOIN_Z or (q.Z < DECK_BACK_Z and math.abs(q.X) < DECK_EDGE_X)
		if not noGuard then
			local top = heightAt(verts, q)
			local hit = Workspace:Raycast(Vector3.new(q.X, top + GUARD_ABOVE, q.Z), Vector3.new(0, -18, 0), params)
			if hit == nil then
				why = "open air"
			elseif hit.Normal.Y <= STEEP_NORMAL_Y then
				why = "steep " .. hit.Instance.Name
			else
				table.insert(walkable, string.format("(%.1f,%.1f) %s", q.X, q.Z, hit.Instance.Name))
			end
		end
		if why ~= nil then
			if open == nil then
				open = { s0 = s, s1 = s, why = why }
			else
				open.s1 = s
			end
		elseif open ~= nil then
			table.insert(stretches, open)
			open = nil
		end
	end
	if open ~= nil then
		table.insert(stretches, open)
	end
	return stretches
end

local function backupFolder(): Folder
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
	return folder :: Folder
end

local function makePiece(name: string, a: Vector3, b: Vector3, ext0: number, ext1: number): Part
	local d = (b - a).Unit
	local r = UP:Cross(d).Unit
	local u = d:Cross(r)
	local a2, b2 = a - d * ext0, b + d * ext1
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(WIDTH, THICK, (b2 - a2).Magnitude)
	part.CFrame = CFrame.fromMatrix((a2 + b2) / 2 - u * (THICK / 2), r, u)
	solid(part)
	return part
end

-- The block under a piece: flat top just under the piece's lowest bottom corner, down to the skin or deck below.
local function makeFill(name: string, piece: BasePart, params: RaycastParams): Part?
	local low, high = math.huge, -math.huge
	local corners: { Vector3 } = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local bottom = (piece.CFrame * CFrame.new(sx * HALF, -THICK / 2, sz * piece.Size.Z / 2)).Position
			local top = (piece.CFrame * CFrame.new(sx * HALF, THICK / 2, sz * piece.Size.Z / 2)).Position
			low = math.min(low, bottom.Y)
			high = math.max(high, top.Y)
			table.insert(corners, bottom)
		end
	end
	table.insert(corners, piece.Position)
	local ground = math.huge
	for _, c in corners do
		local hit = Workspace:Raycast(Vector3.new(c.X, high + 3, c.Z), Vector3.new(0, -60, 0), params)
		if hit ~= nil then
			ground = math.min(ground, hit.Position.Y)
		end
	end
	local top = low - 0.02
	local bottom = math.max(ground - 0.2, top - FILL_DEPTH_CAP)
	if ground == math.huge or top - bottom < 0.15 then
		return nil
	end
	local look = flat(piece.CFrame.LookVector)
	local lengthH = piece.Size.Z * look.Magnitude
	local r = UP:Cross(look.Unit).Unit
	local fill = Instance.new("Part")
	fill.Name = name
	fill.Size = Vector3.new(WIDTH, top - bottom, lengthH)
	fill.CFrame = CFrame.fromMatrix(Vector3.new(piece.Position.X, (top + bottom) / 2, piece.Position.Z), r, UP)
	solid(fill)
	return fill
end

local function buildRamp(label: string, verts: { Vector3 }, params: RaycastParams): (Model, string)
	local model = Instance.new("Model")
	model.Name = "BellyRamp_" .. label
	local count = #verts
	local fills = 0
	for i = 1, count - 1 do
		local function ext(k: number): number
			if k <= 1 or k >= count then
				return 0
			end
			local da, db = flat(verts[k] - verts[k - 1]).Unit, flat(verts[k + 1] - verts[k]).Unit
			local bend = math.acos(math.clamp(da:Dot(db), -1, 1))
			if bend < BEND_MIN then
				return 0
			end
			return HALF * math.tan(bend / 2) + 0.03
		end
		local piece = makePiece("Piece" .. i, verts[i], verts[i + 1], ext(i), ext(i + 1))
		piece.Parent = model
		local fill = makeFill("Fill" .. i, piece, params)
		if fill ~= nil then
			fill.Parent = model
			fills += 1
		end
	end
	return model, `{label}: {count - 1} pieces, {fills} fills`
end

local function run(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local surfaces = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	local landing = if surfaces ~= nil then surfaces:FindFirstChild("LapLanding") else nil
	local eggSpots = if world ~= nil then world:FindFirstChild("EggSpots") else nil
	local spot = if eggSpots ~= nil then eggSpots:FindFirstChild("EggSpot_Rare_1") else nil
	local routes = if world ~= nil then world:FindFirstChild("Route") else nil
	local routePoint = if routes ~= nil then routes:FindFirstChild("RoutePoint_Egg_Rare_1") else nil
	if surfaces == nil or landing == nil or spot == nil or routePoint == nil then
		error("nothing was changed. WalkSurfaces, LapLanding, EggSpot_Rare_1 or RoutePoint_Egg_Rare_1 is missing")
	end
	local existing = 0
	for _, side in SIDES do
		if surfaces:FindFirstChild("BellyRamp_" .. side.label) ~= nil then
			existing += 1
		end
	end
	if existing == #SIDES and surfaces:FindFirstChild("RampEdgeGuards") ~= nil then
		return "already done: both belly ramps and RampEdgeGuards are in WalkSurfaces"
	elseif existing ~= 0 or surfaces:FindFirstChild("RampEdgeGuards") ~= nil then
		error("nothing was changed. only part of the belly ramps is in WalkSurfaces, expected none or all")
	end
	local stations = readStations()
	local base = spot:FindFirstChild("Base")
	if base == nil or not base:IsA("BasePart") or not routePoint:IsA("BasePart") then
		error("nothing was changed. EggSpot_Rare_1.Base or the route point is not a part")
	end
	if CHECK_ONLY then
		return `checks passed: {#stations} stations, landing, egg spot and route point found; nothing changed`
	end

	-- Backup first, in the same run as the change.
	local folder = backupFolder()
	for _, item in { landing, spot, routePoint } do
		if folder:FindFirstChild(item.Name) == nil then
			item:Clone().Parent = folder
		end
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("17-belly-ramps: before")
	end)

	local params = groundParams()
	local last = stations[#stations]
	local dir = (last - stations[#stations - 1]).Unit
	local endS, measured = lastPieceLength(last, dir, params)
	local endPoint = last + dir * (endS / flat(dir).Magnitude)
	local notes: { string } = {}
	table.insert(notes, string.format("last piece ends z %.2f (skin meets at %.2f along)", endPoint.Z, measured))

	local leftVerts = table.clone(stations)
	table.insert(leftVerts, endPoint)
	local guards = Instance.new("Folder")
	guards.Name = "RampEdgeGuards"
	local models: { Model } = {}
	local walkable: { string } = {}
	for _, side in SIDES do
		local verts: { Vector3 } = {}
		for _, v in leftVerts do
			table.insert(verts, Vector3.new(v.X * side.sign, v.Y, v.Z))
		end
		-- Edge rays first, before any ramp part exists.
		local guardCount = 0
		for _, sideSign in { 1, -1 } do
			for _, run2 in edgeRuns(verts, sideSign) do
				local len = (run2.b - run2.a).Magnitude
				local dirE = (run2.b - run2.a).Unit
				for _, st in classify(verts, run2, params, walkable) do
					local s0, s1 = math.max(st.s0 - EDGE_STEP, 0), math.min(st.s1 + EDGE_STEP, len)
					if dirE.Z > 0.01 then
						s1 = math.min(s1, (JOIN_Z - run2.a.Z) / dirE.Z) -- ruling 4: never past the belly join
					end
					local pa, pb = run2.a + dirE * s0, run2.a + dirE * s1
					local lo, hi = math.huge, -math.huge
					for i = 0, 10 do
						local h = heightAt(verts, pa:Lerp(pb, i / 10))
						lo, hi = math.min(lo, h), math.max(hi, h)
					end
					local bottom, top = lo - GUARD_BELOW, hi + GUARD_ABOVE
					local inward = -run2.out
					-- the guard stands just outside the edge, its vertical face (local +Z) on the edge line
					local mid = (pa + pb) / 2 + run2.out * (GUARD_THICK / 2 - FACE_IN)
					local cf =
						CFrame.fromMatrix(Vector3.new(mid.X, (bottom + top) / 2, mid.Z), UP:Cross(inward).Unit, UP)
					guardCount += 1
					newGuard(`{side.label}Edge{guardCount}`, cf, (pb - pa).Magnitude, top - bottom).Parent = guards
					table.insert(
						notes,
						string.format("%s guard %d: %s, s %.1f to %.1f", side.label, guardCount, st.why, s0, s1)
					)
				end
			end
		end
		local model, text = buildRamp(side.label, verts, params)
		table.insert(models, model)
		table.insert(notes, text)
	end

	for _, model in models do
		clearMockup(model)
		model.Parent = surfaces
	end
	guards.Parent = surfaces

	-- Rare egg 1: lift it so its Base sits on the ramp (at most MAX_LIFT).
	local include = RaycastParams.new()
	include.FilterType = Enum.RaycastFilterType.Include
	include.FilterDescendantsInstances = { models[1] }
	local hit = Workspace:Raycast(base.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), include)
	if hit == nil then
		table.insert(notes, "egg: no ramp under Rare egg 1, not lifted")
	else
		local gap = hit.Position.Y - (base.Position.Y - base.Size.Y / 2)
		local lift = math.max(gap, 0)
		if lift > MAX_LIFT then
			table.insert(notes, string.format("egg: gap %.3f is over %.2f, NOT lifted", gap, MAX_LIFT))
			lift = 0
		elseif lift > 0 then
			local model = spot :: Model
			local point = routePoint :: BasePart
			model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
			point.Position += Vector3.new(0, lift, 0)
		end
		if gap <= MAX_LIFT then
			table.insert(notes, string.format("egg: gap %.3f, lifted %.3f", gap, lift))
		end
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("17-belly-ramps: after")
	end)
	return "built both belly ramps and their edge guards. "
		.. table.concat(notes, "; ")
		.. `. Walkable edge samples: {#walkable}. Backup: ServerStorage.WorldBackups.{BACKUP_NAME}`
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
