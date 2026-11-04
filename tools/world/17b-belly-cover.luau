--!strict
-- World prep, plan 3 Task 6a2 Step 6 (work/t6/look-fix.md, code_lead's split ruling): the cover boards for the belly ramps.
-- A helper module of tools/world/17-belly-ramps.luau (it requires a clone of this module). It works the boards out on the
-- left ramp and lays them on both ramps; it changes nothing by itself except in `lay`.
--   plan(left, flat): per straight run of pieces (1 to 3, 4 to 10, 11 to the last) the fewest boards (at most 3) whose
--     every piece top is within 0.35 of the board top, ties to the smallest worst gap; each side as wide as his skin allows
--     (the skin line minus 0.3, 0 to 3), a later board that overlaps an earlier one 0.05 lower, and a board end or side
--     that rests deeper in his skin than SunkParts allows (0.3 on the end faces, 0.1 on the others) trimmed 0.1 at a time
--     (at most 1.0). Errors "nothing was changed. ..." when no plan fits.
--   lay(left, right, boards, deckColor, railPart, mirrorCf): the pieces go invisible (still solid) and each ramp gets a
--     Cover folder of look-only WoodPlanks boards; the right is the exact mirror of the left.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- The sink measure (SunkParts' own depth rule) is tools/checks/SinkDepth.luau; a clone, so an edited copy is read.
local SinkDepth = (require :: any)(
	ServerStorage:WaitForChild("Tools"):WaitForChild("checks"):WaitForChild("SinkDepth"):Clone()
)

local UP = Vector3.yAxis

local COVER_THICK = 0.4
local COVER_GAP_LIMIT = 0.35 -- code_lead's ruling: piece top minus board top, at each covered piece's centre
local COVER_MIN_WIDTH = 3.0
local COVER_MAX_BOARDS = 3
local COVER_SKIN_MARGIN = 0.3
local COVER_HALF_MAX = 3 -- never wider than the pieces
local COVER_ALONG = 0.5
local COVER_OUT = 0.25
local COVER_RAY_UP = 12
local COVER_DROP = 0.05
local COVER_TRIM_STEP = 0.1
local COVER_TRIM_MAX = 1.0

type Span = {
	first: number,
	last: number,
	a: Vector3,
	dir: Vector3,
	right: Vector3,
	up: Vector3,
	length: number,
	gaps: { number },
	halfP: number?,
	halfN: number?,
}
export type Board = {
	span: Span,
	halfP: number,
	halfN: number,
	trimA: number,
	trimB: number,
	drop: number,
	startHalfP: number,
	startHalfN: number,
}
type CharacterPart = { part: BasePart, params: RaycastParams, min: Vector3, max: Vector3 } -- as SinkDepth.CharacterPart

-- His visible body parts (SinkDepth), and one params object over all of them.
local function characterParts(): ({ CharacterPart }, RaycastParams)
	local list: { CharacterPart } = SinkDepth.characterParts("MainCharacter")
	local all: { Instance } = {}
	for _, c in list do
		table.insert(all, c.part)
	end
	local skin = RaycastParams.new()
	skin.FilterType = Enum.RaycastFilterType.Include
	skin.FilterDescendantsInstances = all
	return list, skin
end

local function pieceEnds(piece: BasePart): (Vector3, Vector3) -- the top's lower end, higher end
	local a = (piece.CFrame * CFrame.new(0, piece.Size.Y / 2, piece.Size.Z / 2)).Position
	local b = (piece.CFrame * CFrame.new(0, piece.Size.Y / 2, -piece.Size.Z / 2)).Position
	if a.Y < b.Y then
		return a, b
	end
	return b, a
end

-- One straight board over pieces first..last: the top line runs from the first piece's lower top end to the last piece's
-- higher top end. gaps[i] = piece top minus board top at that piece's centre.
local function newSpan(pieces: { BasePart }, first: number, last: number, flat: (Vector3) -> Vector3): Span
	local a = pieceEnds(pieces[first])
	local _, b = pieceEnds(pieces[last])
	local dir = (b - a).Unit
	local right = UP:Cross(dir).Unit
	local fd = flat(dir)
	local gaps: { number } = {}
	for i = first, last do
		local p = (pieces[i].CFrame * CFrame.new(0, pieces[i].Size.Y / 2, 0)).Position
		local s = flat(p - a):Dot(fd) / fd:Dot(fd)
		table.insert(gaps, p.Y - (a.Y + dir.Y * s))
	end
	return {
		first = first,
		last = last,
		a = a,
		dir = dir,
		right = right,
		up = dir:Cross(right),
		length = (b - a).Magnitude,
		gaps = gaps,
	}
end

-- The skin line each side: rays down from COVER_RAY_UP above the top line every COVER_OUT out, every COVER_ALONG along;
-- the first that hits his skin above the board's bottom. Half-width = the smallest skin line minus the margin, 0 to 3.
local function skinHalves(span: Span, skin: RaycastParams): (number, number)
	local least = { [1] = COVER_HALF_MAX + COVER_SKIN_MARGIN, [-1] = COVER_HALF_MAX + COVER_SKIN_MARGIN }
	local steps = math.ceil(span.length / COVER_ALONG)
	for k = 0, steps do
		local c = span.a + span.dir * math.min(k * COVER_ALONG, span.length)
		for _, side in { 1, -1 } do
			local o = COVER_OUT
			while o < least[side] - 0.0001 do
				local origin = c + span.right * (side * o) + Vector3.new(0, COVER_RAY_UP, 0)
				local hit = Workspace:Raycast(origin, Vector3.new(0, -(COVER_RAY_UP + COVER_THICK + 1), 0), skin)
				if hit ~= nil and hit.Position.Y > c.Y - COVER_THICK then
					least[side] = o
					break
				end
				o += COVER_OUT
			end
		end
	end
	local function half(v: number): number
		return math.clamp(v - COVER_SKIN_MARGIN, 0, COVER_HALF_MAX)
	end
	return half(least[1]), half(least[-1])
end

local function boardFrame(b: Board): (CFrame, Vector3)
	local len = b.span.length - b.trimA - b.trimB
	local top = b.span.a + b.span.dir * (b.trimA + len / 2) + b.span.right * ((b.halfP - b.halfN) / 2) - UP * b.drop
	return CFrame.fromMatrix(top - b.span.up * (COVER_THICK / 2), b.span.right, b.span.up),
		Vector3.new(b.halfP + b.halfN, COVER_THICK, len)
end

-- True when the plan view of board `late` overlaps board `early` (a corner), sampled every 0.2.
local function overlaps(early: Board, late: Board): boolean
	local cf, size = boardFrame(late)
	local ecf, esize = boardFrame(early)
	for x = -size.X / 2, size.X / 2, 0.1 do
		for z = -size.Z / 2, size.Z / 2, 0.1 do
			local q = ecf:PointToObjectSpace((cf * CFrame.new(x, 0, z)).Position)
			local inX = math.abs(q.X) < esize.X / 2 - 0.02
			local inZ = math.abs(q.Z) < esize.Z / 2 - 0.02
			if inX and inZ and math.abs(q.Y) < 0.6 then
				return true
			end
		end
	end
	return false
end

-- A later board that overlaps an earlier one sits 0.05 lower than it (0.05 more than the deepest it overlaps).
local function setDrops(boards: { Board })
	for k, b in boards do
		b.drop = 0
		for j = 1, k - 1 do
			if overlaps(boards[j], b) then
				b.drop = math.max(b.drop, boards[j].drop + COVER_DROP)
			end
		end
	end
end

local function boardWorst(b: Board): number
	local worst = 0
	for _, g in b.span.gaps do
		if math.abs(g + b.drop) > math.abs(worst) then
			worst = g + b.drop
		end
	end
	return worst
end

local function cutSets(lo: number, hi: number, count: number): { { number } }
	local sets: { { number } } = {}
	local function rec(start: number, left: number, acc: { number })
		if left == 0 then
			table.insert(sets, table.clone(acc))
			return
		end
		for cut = start, hi - left do
			table.insert(acc, cut)
			rec(cut + 1, left - 1, acc)
			table.remove(acc)
		end
	end
	rec(lo, count - 1, {})
	return sets
end

-- The fewest boards (up to 3) over pieces lo..hi where every piece is within the gap limit and every board is wide enough;
-- ties go to the smallest worst gap. Returns nil and the best numbers seen when none passes.
local function planRun(
	pieces: { BasePart },
	lo: number,
	hi: number,
	skin: RaycastParams,
	flat: (Vector3) -> Vector3
): ({ Board }?, string)
	local cache: { [string]: Span } = {}
	local function span(first: number, last: number): Span
		local key = `{first}_{last}`
		if cache[key] == nil then
			cache[key] = newSpan(pieces, first, last, flat)
		end
		return cache[key]
	end
	local note = ""
	for count = 1, COVER_MAX_BOARDS do
		local best: { Board }? = nil
		local bestWorst = math.huge
		for _, cuts in cutSets(lo, hi, count) do
			local boards: { Board } = {}
			local from, fits = lo, true
			for k = 1, count do
				local to = if k <= #cuts then cuts[k] else hi
				local sp = span(from, to)
				for _, g in sp.gaps do
					if math.abs(g) > COVER_GAP_LIMIT then
						fits = false
					end
				end
				if not fits then
					break
				end
				if sp.halfP == nil or sp.halfN == nil then
					sp.halfP, sp.halfN = skinHalves(sp, skin)
				end
				local hp, hn = sp.halfP :: number, sp.halfN :: number
				if hp + hn < COVER_MIN_WIDTH - 0.001 then
					fits = false
					break
				end
				table.insert(boards, {
					span = sp,
					halfP = hp,
					halfN = hn,
					trimA = 0,
					trimB = 0,
					drop = 0,
					startHalfP = hp,
					startHalfN = hn,
				})
				from = to + 1
			end
			if fits then
				setDrops(boards)
				local worst = 0
				for _, b in boards do
					worst = math.max(worst, math.abs(boardWorst(b)))
				end
				if worst <= COVER_GAP_LIMIT and worst < bestWorst then
					best, bestWorst = boards, worst
				end
			end
		end
		if best ~= nil then
			return best, ""
		end
		note ..= ` {count} boards: none fit;`
	end
	return nil, note
end

-- SunkParts' faces of a board (SinkDepth.faceDepths): the failing faces as { axis, sign } (axis 1 = across, 2 = up,
-- 3 = along) and the worst depth. SinkDepth's axis 3 is the board's LookVector; the trim below counts the sign along
-- ZVector (the other way), so that sign is flipped here.
local function sunkFaces(cf: CFrame, size: Vector3, chars: { CharacterPart }): ({ { number } }, number)
	local fails: { { number } } = {}
	local worst = 0
	for _, face in SinkDepth.faceDepths(cf, size, chars) do
		if face.failing > 0 then
			table.insert(fails, { face.axis, if face.axis == 3 then -face.sign else face.sign })
			worst = math.max(worst, face.worst)
		end
	end
	return fails, worst
end

-- Shortens the failing ends / narrows the failing sides 0.1 at a time (at most 1.0). Returns an error text, or nil.
local function trimBoard(b: Board, chars: { CharacterPart }): string?
	for _ = 1, 12 do
		local cf, size = boardFrame(b)
		local fails, worst = sunkFaces(cf, size, chars)
		if #fails == 0 then
			return nil
		end
		for _, f in fails do
			if f[1] == 3 then
				if f[2] == 1 then
					b.trimB += COVER_TRIM_STEP
				else
					b.trimA += COVER_TRIM_STEP
				end
			elseif f[1] == 1 then
				if f[2] == 1 then
					b.halfP = math.max(b.halfP - COVER_TRIM_STEP, 0)
				else
					b.halfN = math.max(b.halfN - COVER_TRIM_STEP, 0)
				end
			else
				return `top face of Board_{b.span.first}_{b.span.last} is sunk {string.format("%.2f", worst)}`
			end
		end
		local over = math.max(b.trimA, b.trimB, b.startHalfP - b.halfP, b.startHalfN - b.halfN)
		if over > COVER_TRIM_MAX + 0.001 then
			return `Board_{b.span.first}_{b.span.last} still sunk {string.format("%.2f", worst)} after {COVER_TRIM_MAX} trimmed`
		end
	end
	return `Board_{b.span.first}_{b.span.last} still sunk after 12 trims`
end

local function pieceList(ramp: Model): { BasePart }
	local list: { BasePart } = {}
	while true do
		local p = ramp:FindFirstChild("Piece" .. (#list + 1))
		if p == nil or not p:IsA("BasePart") then
			return list
		end
		table.insert(list, p)
	end
end

-- Works the boards out on the left ramp (no change to the world). Returns the boards and a summary.
local function plan(left: Model, flat: (Vector3) -> Vector3): ({ Board }, string)
	local pieces = pieceList(left)
	if #pieces < 11 then
		error(`nothing was changed. BellyRamp_Left has {#pieces} pieces, expected 16`)
	end
	local chars, skin = characterParts()
	if #chars == 0 then
		error("nothing was changed. no visible MainCharacter part found")
	end
	local all: { Board } = {}
	local lines: { string } = {}
	for _, run in { { 1, 3 }, { 4, 10 }, { 11, #pieces } } do
		local boards, note = planRun(pieces, run[1], run[2], skin, flat)
		if boards == nil then
			error(`nothing was changed. run {run[1]} to {run[2]} has no cut into {COVER_MAX_BOARDS} boards:{note}`)
		end
		for _, b in boards do
			local problem = trimBoard(b, chars)
			if problem ~= nil then
				error(`nothing was changed. {problem}`)
			end
			table.insert(all, b)
		end
	end
	setDrops(all)
	for _, b in all do
		if math.abs(boardWorst(b)) > COVER_GAP_LIMIT then
			error(
				`nothing was changed. Board_{b.span.first}_{b.span.last} gap {string.format("%.2f", boardWorst(b))} with its drop`
			)
		end
		local _, size = boardFrame(b)
		table.insert(
			lines,
			string.format(
				"Board_%d_%d len %.2f w %.2f (P %.2f, N %.2f) worst gap %+.2f drop %.2f trim %.1f/%.1f",
				b.span.first,
				b.span.last,
				size.Z,
				size.X,
				b.halfP,
				b.halfN,
				boardWorst(b),
				b.drop,
				b.trimA,
				b.trimB
			)
		)
		if size.X < COVER_MIN_WIDTH - 0.001 then
			error(
				`nothing was changed. Board_{b.span.first}_{b.span.last} is {string.format("%.2f", size.X)} wide after trims`
			)
		end
	end
	return all, table.concat(lines, "; ")
end

-- Lays the boards on the left, the exact mirror on the right. The pieces go invisible (still solid).
local function lay(
	left: Model,
	right: Model,
	boards: { Board },
	deckColor: Color3,
	railPart: (string, Vector3, CFrame, Color3, Enum.Material) -> Part,
	mirrorCf: (CFrame) -> CFrame
)
	for _, ramp in { left, right } do
		for _, piece in pieceList(ramp) do
			piece.Transparency = 1
		end
		local folder = Instance.new("Folder")
		folder.Name = "Cover"
		folder.Parent = ramp
	end
	for _, b in boards do
		local cf, size = boardFrame(b)
		local name = `Board_{b.span.first}_{b.span.last}`
		for side = 1, 2 do
			local ramp = if side == 1 then left else right
			local part =
				railPart(name, size, if side == 1 then cf else mirrorCf(cf), deckColor, Enum.Material.WoodPlanks)
			part.CastShadow = true
			part.Parent = ramp:FindFirstChild("Cover")
		end
	end
end

return { plan = plan, lay = lay }
