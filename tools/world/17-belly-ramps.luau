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
-- Task 6a2 (look): the pieces stay invisible and solid; each ramp gets a Rails folder (one look-only rope per span between
-- posts, posts read from LapPlank_Left: a rope is dropped when the ray at either end finds his skin above it; a post needs
-- a ray down from 6 above its foot to hit the ramp's own piece or fill first) and a Cover folder of look-only wood boards
-- laid level with the walk (Step 6 of work/t6/look-fix.md, code_lead's split ruling): one straight board per straight
-- run, the run 4 to 10 cut into the fewest boards (at most 3) whose every piece top is within 0.35 of the board top, each
-- side as wide as his skin allows (the skin line minus 0.3), a later board at a corner 0.05 lower, and an end that rests
-- more than 0.3 inside his skin (SunkParts' own measure) shortened 0.1 at a time. Both are worked out on the left ramp,
-- the right gets the exact mirror. Worlds: ramps with visible pieces and Rails, no Cover = clone both into
-- ServerStorage.WorldBackups.t6a2-step6 and "updated cover"; invisible pieces and both Covers = "already done"; no
-- ramps = build all, the rails and the cover.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau (or require a copy of it).

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local MockupNests: { find: () -> Instance? } = (require :: any)(ServerStorage.Tools.checks.MockupNests:Clone())
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- The cover boards live in tools/world/17b-belly-cover.luau (a clone is required so an edited copy is always read).
local coverModule = ServerStorage:WaitForChild("Tools"):WaitForChild("world"):WaitForChild("17b-belly-cover")
local coverCopy = coverModule:Clone() :: ModuleScript
local Cover = (require :: any)(coverCopy)

local BACKUP_NAME = "Plan3Task6"
local COVER_BACKUP = "t6a2-step6"
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
local ROPE_OUT = 2.85 -- rope and post centre line, from the ramp's centre line (spec 3, Task 6a2)
-- Post stations per side and one straight rope between neighbours (designer's verdict work/t6/look-verdict-6a2.md, item 2).
-- No rail over the landing deck, and the P side has no rail at all: posts 6 and 12 stand inside his skin, so a lone post
-- 10 would be left (designer, work/t6/look-verdict-6a2.md, Step 4 again).
-- Post 16 dropped: it stood inside Rare egg 1's nest rim (p3t13 post fix).
local POST_STATIONS: { [string]: { number } } = { N = { 6, 7, 10, 13 }, P = {} }
local ROPE_SAMPLES = 4 -- rays along a span rope
local RAIL_RAY_UP = 6

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
	local nests = MockupNests.find()
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

local function backupFolder(name: string): Folder
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	local folder = backups:FindFirstChild(name)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
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

type Look = {
	deckColor: Color3,
	ropeColor: Color3,
	ropeMaterial: Enum.Material,
	ropeSize: Vector3,
	ropeHeight: number,
	postColor: Color3,
	postMaterial: Enum.Material,
	postSize: Vector3,
	postHeight: number,
}

-- The look of the planks, ropes and posts, read from LapPlank_Left (heights are along the deck's own up, above its top).
local function readLook(surfaces: Instance): Look
	local plank = surfaces:FindFirstChild("LapPlank_Left")
	local deck = if plank ~= nil then plank:FindFirstChild("Deck") else nil
	local rope = if plank ~= nil then plank:FindFirstChild("Rope") else nil
	local post = if plank ~= nil then plank:FindFirstChild("Post") else nil
	if deck == nil or rope == nil or post == nil or not deck:IsA("BasePart") then
		error("nothing was changed. LapPlank_Left.Deck, Rope or Post is missing")
	end
	local d, r, p = deck :: BasePart, rope :: BasePart, post :: BasePart
	return {
		deckColor = d.Color,
		ropeColor = r.Color,
		ropeMaterial = r.Material,
		ropeSize = Vector3.new(r.Size.X, r.Size.Y, 1),
		ropeHeight = d.CFrame:ToObjectSpace(r.CFrame).Position.Y - d.Size.Y / 2,
		postColor = p.Color,
		postMaterial = p.Material,
		postSize = p.Size,
		postHeight = d.CFrame:ToObjectSpace(p.CFrame).Position.Y - d.Size.Y / 2,
	}
end

local function mirrorX(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

-- The reflection of a box's frame across x = 0 (one axis is turned round, so the frame stays right-handed).
local function mirrorCf(cf: CFrame): CFrame
	return CFrame.fromMatrix(mirrorX(cf.Position), -mirrorX(cf.XVector), mirrorX(cf.YVector), mirrorX(cf.ZVector))
end

local function railPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Lays the rails on the left ramp by the ray rules, then the exact mirror on the right. Returns the summary.
local function layRails(surfaces: Instance, left: Model, right: Model, look: Look): string
	local leftRails, rightRails = Instance.new("Folder"), Instance.new("Folder")
	leftRails.Name, rightRails.Name = "Rails", "Rails"
	leftRails.Parent, rightRails.Parent = left, right
	local extra: { Instance } = { leftRails, rightRails }
	local guards = surfaces:FindFirstChild("RampEdgeGuards")
	if guards ~= nil then
		table.insert(extra, guards)
	end
	local params = groundParams(extra)
	local ropes, posts = 0, 0
	local dropped: { string } = {}
	local under: { string } = {}
	for _, tag in { "N", "P" } do
		local s = if tag == "P" then 1 else -1
		local stations = POST_STATIONS[tag]
		local feet: { [number]: Vector3? } = {}
		for _, i in stations do
			local piece = left:FindFirstChild("Piece" .. i) :: BasePart?
			if piece == nil then
				table.insert(dropped, `post {i}{tag} (no piece)`)
				continue
			end
			local foot = (piece.CFrame * CFrame.new(s * ROPE_OUT, THICK / 2, -piece.Size.Z / 2 + 0.25)).Position
			local hit = Workspace:Raycast(foot + Vector3.new(0, RAIL_RAY_UP, 0), Vector3.new(0, -20, 0), params)
			if hit == nil or not hit.Instance:IsDescendantOf(left) then
				table.insert(dropped, `post {i}{tag} ({if hit ~= nil then hit.Instance.Name else "none"})`)
				continue
			end
			local dirFlat = flat(piece.CFrame.LookVector).Unit
			local cf = CFrame.fromMatrix(foot + UP * look.postHeight, UP:Cross(dirFlat).Unit, UP)
			local name = `Post_{i}_{tag}`
			railPart(name, look.postSize, cf, look.postColor, look.postMaterial).Parent = leftRails
			railPart(name, look.postSize, mirrorCf(cf), look.postColor, look.postMaterial).Parent = rightRails
			feet[i] = foot
			posts += 1
		end
		for k = 1, #stations - 1 do
			local a, b = stations[k], stations[k + 1]
			local footA, footB = feet[a], feet[b]
			if footA == nil or footB == nil then
				table.insert(dropped, `rope {a}-{b}{tag} (a post is missing)`)
				continue
			end
			local pa, pb = footA + UP * look.ropeHeight, footB + UP * look.ropeHeight
			local blocked: string? = nil
			for n = 0, ROPE_SAMPLES do
				local pt = pa:Lerp(pb, n / ROPE_SAMPLES)
				local hit =
					Workspace:Raycast(pt + Vector3.new(0, RAIL_RAY_UP, 0), Vector3.new(0, -4 * RAIL_RAY_UP, 0), params)
				if hit ~= nil and hit.Position.Y > pt.Y then
					if not hit.Instance:IsDescendantOf(left) and blocked == nil then
						blocked = hit.Instance.Name
					elseif hit.Instance:IsDescendantOf(left) then
						table.insert(under, `{a}-{b}{tag} under {hit.Instance.Name}`)
					end
				end
			end
			if blocked ~= nil then
				table.insert(dropped, `rope {a}-{b}{tag} (skin or other ramp: {blocked})`)
				continue
			end
			local cf = CFrame.lookAt((pa + pb) / 2, pb)
			local size = Vector3.new(look.ropeSize.X, look.ropeSize.Y, (pb - pa).Magnitude)
			local name = `Rope_{a}_{b}_{tag}`
			railPart(name, size, cf, look.ropeColor, look.ropeMaterial).Parent = leftRails
			railPart(name, size, mirrorCf(cf), look.ropeColor, look.ropeMaterial).Parent = rightRails
			ropes += 1
		end
	end
	return `ropes {ropes}, posts {posts} per ramp; dropped: {if #dropped == 0
		then "none"
		else table.concat(dropped, ", ")}; span samples under own ramp: {if #under == 0
		then "none"
		else table.concat(under, ", ")}`
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
	local existing, covered, visible = 0, 0, 0
	for _, side in SIDES do
		local ramp = surfaces:FindFirstChild("BellyRamp_" .. side.label)
		if ramp ~= nil then
			existing += 1
			if ramp:FindFirstChild("Cover") ~= nil and ramp:FindFirstChild("Rails") ~= nil then
				covered += 1
			end
			local piece1 = ramp:FindFirstChild("Piece1")
			if piece1 ~= nil and piece1:IsA("BasePart") and piece1.Transparency < 1 then
				visible += 1
			end
		end
	end
	local look = readLook(surfaces)
	if existing == #SIDES and surfaces:FindFirstChild("RampEdgeGuards") ~= nil then
		if covered == #SIDES and visible == 0 then
			return "already done: both belly ramps have invisible pieces, span-rope Rails and a Cover of wood boards, and RampEdgeGuards is in WalkSurfaces"
		elseif covered ~= 0 or visible ~= #SIDES then
			error("nothing was changed. the ramps are half way (some covered, some hidden), expected none or all")
		end
		for _, side in SIDES do
			if (surfaces:FindFirstChild("BellyRamp_" .. side.label) :: Instance):FindFirstChild("Rails") == nil then
				error("nothing was changed. a visible ramp has no Rails folder")
			end
		end
		local leftRamp = surfaces:FindFirstChild("BellyRamp_Left") :: Model
		local rightRamp = surfaces:FindFirstChild("BellyRamp_Right") :: Model
		-- the boards are worked out first: nothing is changed when no plan fits
		local boards, summary = Cover.plan(leftRamp, flat)
		if CHECK_ONLY then
			return `checks passed: {summary}; nothing changed`
		end
		local backup = backupFolder(COVER_BACKUP)
		for _, ramp in { leftRamp, rightRamp } do
			if backup:FindFirstChild(ramp.Name) == nil then
				ramp:Clone().Parent = backup
			end
		end
		pcall(function()
			ChangeHistoryService:SetWaypoint("17-belly-ramps cover: before")
		end)
		Cover.lay(leftRamp, rightRamp, boards, look.deckColor, railPart, mirrorCf)
		pcall(function()
			ChangeHistoryService:SetWaypoint("17-belly-ramps cover: after")
		end)
		return `updated cover: {summary}. Backup: ServerStorage.WorldBackups.{COVER_BACKUP}`
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
	local folder = backupFolder(BACKUP_NAME)
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
	table.insert(notes, layRails(surfaces, models[1], models[2], look))
	local boards, coverSummary = Cover.plan(models[1], flat)
	Cover.lay(models[1], models[2], boards, look.deckColor, railPart, mirrorCf)
	table.insert(notes, coverSummary)

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
