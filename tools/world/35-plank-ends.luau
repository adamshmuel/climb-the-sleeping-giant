--!strict
-- World prep, plan 3 (gardens and ways up) Task 6b: V1's left crossing ramps go, and a plank-wood board closes each lap
-- plank's boot end (docs/plans/v2/gardens-and-ways-up.md Task 6; spec Rule 45, Rule 36, Rule 103).
-- Card: work/t6b/card.md; the numbers: work/t6b/6b-scripts.md sections B, R2, R3 and F.
-- Run after 15-real-shape: a rerun of 15 brings back the crossing ramps.
-- What it does: clones CrossingRamp_Ankle, CrossingRamp_Knee and CrossingGuards into ServerStorage.WorldBackups.t6b
-- (attribute BackupOf = the old full path), destroys them, and builds WalkSurfaces.PlankEnd_Left and PlankEnd_Right, each
-- a Model of Board_<n> parts: boards only (branch N, 2026-11-08), no fill. A strip is 1.5 wide, halved down to 0.375, as
-- thick as the Deck, Color and Material read from that side's Deck, outer face flush with the deck's boot-end face, top at
-- the deck bottom, bottom down to his skin. A board is CanCollide, CanQuery and CanTouch false.
-- Columns with no skin under the boot-end face (the deck hangs past the boot's edge) get no board ("overhang", R2).
-- One shared mirrored layout (R3): both sides use the finer split of each strip; each bottom follows its own skin.
-- A face may sink up to 0.3 only on the face flush with the deck's boot-end face; any other face halves down to 0.375 and
-- stops if it still sinks over its limit.
-- F2: a 0.375 strip may sink 0.3 on any face (STOP over 0.3); each such piece prints "sink 0.3 rule". A layout piece built
-- on one side only is allowed when it is one 0.375 piece next to that side's overhang ("one side only"); any other is a STOP.
-- Every piece in place = "already done". A mix, a wrong count, decks that are not mirrors, a face sinking past its limit,
-- more than 4 overhang columns or an overhang column between two columns with skin = STOP, nothing changes.
-- Rollback: paste the clones back and delete PlankEnd_Left and PlankEnd_Right.
-- CHECK_ONLY = true measures and prints only (it puts temporary pieces in the Workspace and takes them out in the same
-- call). Full report: shared.T6bReport (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["35-plank-ends"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local requireModule: (Instance) -> any = require :: any
-- The measure is tools/checks/SinkDepth.luau (a clone, so an edited copy is read).
local SinkDepth =
	requireModule(ServerStorage:WaitForChild("Tools"):WaitForChild("checks"):WaitForChild("SinkDepth"):Clone())
type CharacterPart = { part: BasePart, params: RaycastParams, min: Vector3, max: Vector3 } -- as SinkDepth.CharacterPart

-- The one shared walk check (src/server/World/PathCheck), loaded fresh: a clone placed next to the original, removed again.
local PathCheck: any
do
	local original = ServerScriptService.Server.World.PathCheck :: ModuleScript
	local clone = original:Clone()
	clone.Parent = original.Parent
	local loaded, result = pcall(require, clone)
	clone:Destroy()
	if not loaded then
		error(`PathCheck did not load: {result}`)
	end
	PathCheck = result
end

local BACKUP_NAME = "t6b"
local MAIN_TAG = "MainCharacter"
local TOL = 0.05
local COLUMN_STEP = 1.5 -- studs across the deck: the strip width
local HALF_WIDTH = 4.5 -- the deck's half width the strips run to
local MIN_STRIP = 0.375
local MAX_OVERHANG = 4 -- most overhang strips (1.5 wide) per side
local FLUSH_LIMIT = 0.3 -- studs a face may sink when it is flush with the deck's boot-end face
local RAY_LENGTH = 20
local ROUTE_NEAR = 12 -- studs: Route links this close to a new piece are walk-checked
local DRY_FOLDER = "T6bDry"

type Board = { cf: CFrame, size: Vector3, u: number, buried: number, worst: number, failing: number, ruled: number }
type Leaf = { u: number, w: number, board: Board?, missing: number }
type Spot = { u: number, w: number, strip: number }
type Piece = { cf: CFrame, size: Vector3, name: string }

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

local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.T6bReport = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

-- The mirror of a frame across x = 0 (M * cf * M with M = diag(-1, 1, 1)): a proper rotation again.
local function mirrorCF(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Distance from a point to a box (its frame and size); 0 inside.
local function boxDistance(cf: CFrame, size: Vector3, point: Vector3): number
	local at = cf:PointToObjectSpace(point)
	local half = size / 2
	local nearest = Vector3.new(
		math.clamp(at.X, -half.X, half.X),
		math.clamp(at.Y, -half.Y, half.Y),
		math.clamp(at.Z, -half.Z, half.Z)
	)
	return (at - nearest).Magnitude
end

local function nearestPiece(pieces: { Piece }, point: Vector3): (number, string)
	local best, name = math.huge, "none"
	for _, piece in pieces do
		local distance = boxDistance(piece.cf, piece.size, point)
		if distance < best then
			best, name = distance, piece.name
		end
	end
	return best, name
end

local world = Workspace:WaitForChild("World")
local surfaces = world:WaitForChild("WalkSurfaces")
local characters: { CharacterPart } = SinkDepth.characterParts(MAIN_TAG)
if #characters == 0 then
	return "STOP: no MainCharacter parts found; nothing changed"
end
local skinParts: { Instance } = {}
for _, character in characters do
	table.insert(skinParts, character.part)
end
local skinParams = RaycastParams.new()
skinParams.FilterType = Enum.RaycastFilterType.Include
skinParams.FilterDescendantsInstances = skinParts
skinParams.RespectCanCollide = false

-- 1. What is in the world now: the 3 things that go, the 2 decks, the 2 new models.
local rampAnkle = surfaces:FindFirstChild("CrossingRamp_Ankle")
local rampKnee = surfaces:FindFirstChild("CrossingRamp_Knee")
local guards = surfaces:FindFirstChild("CrossingGuards")
local removeList: { Instance } = {}
for _, found in { rampAnkle, rampKnee, guards } do
	if found ~= nil then
		table.insert(removeList, found)
	end
end
local models = { surfaces:FindFirstChild("PlankEnd_Left"), surfaces:FindFirstChild("PlankEnd_Right") }
local modelCount = (if models[1] ~= nil then 1 else 0) + (if models[2] ~= nil then 1 else 0)
local deckLeft = (surfaces:FindFirstChild("LapPlank_Left") :: Instance?)
	and surfaces.LapPlank_Left:FindFirstChild("Deck") :: BasePart?
local deckRight = (surfaces:FindFirstChild("LapPlank_Right") :: Instance?)
	and surfaces.LapPlank_Right:FindFirstChild("Deck") :: BasePart?
if deckLeft == nil or deckRight == nil then
	return "STOP: LapPlank_Left.Deck or LapPlank_Right.Deck not found; nothing changed"
end
local decks: { BasePart } = { deckLeft, deckRight }
local isDone = #removeList == 0 and modelCount == 2
if not isDone and not (#removeList == 3 and modelCount == 0) then
	return `STOP: a mix: {#removeList} of 3 old parts and {modelCount} of 2 new models are in the world; nothing changed`
end
say(
	`1 to remove: {#removeList} of 3 found (CrossingRamp_Ankle, CrossingRamp_Knee, CrossingGuards); models in place {modelCount} of 2`
)
for _, found in removeList do
	if found:IsA("BasePart") then
		say(`1   {found.Name} {found.ClassName} size {fmtV(found.Size)} at {fmtV(found.Position)}`)
	else
		say(`1   {found.Name} {found.ClassName} with {#found:GetChildren()} children`)
	end
end

-- 2. The two decks must be mirrors.
do
	local a = { deckLeft.CFrame:GetComponents() }
	local b = { mirrorCF(deckRight.CFrame):GetComponents() }
	local worst = 0
	for index = 1, 12 do
		worst = math.max(worst, math.abs(a[index] - b[index]))
	end
	local sizeGap = (deckLeft.Size - deckRight.Size).Magnitude
	say(`2 decks: left size {fmtV(deckLeft.Size)}, right mirror gap {fmt(worst)}, size gap {fmt(sizeGap)}`)
	if worst > TOL or sizeGap > TOL then
		stop(`the two decks are not mirrors (gap {fmt(worst)}, size gap {fmt(sizeGap)})`)
	end
end

-- Where the skin lies under the deck at distance s from its boot end and across offset u: the distance down the deck's
-- own down direction from the deck bottom, nil when none within RAY_LENGTH.
local function skinDepth(deck: BasePart, u: number, s: number): number?
	local origin = deck.CFrame:PointToWorldSpace(Vector3.new(u, -deck.Size.Y / 2, deck.Size.Z / 2 - s))
	local hit = Workspace:Raycast(origin, -deck.CFrame.UpVector * RAY_LENGTH, skinParams)
	if hit == nil then
		return nil
	end
	return hit.Distance
end

-- One strip (centre u, width w) across the boot-end face: its height is the deepest of its 3 skin samples, so no open
-- height. nil and the number of samples with no skin when any sample finds none.
local function evalStrip(deck: BasePart, u: number, width: number): (Board?, number)
	local thick, length = deck.Size.Y, deck.Size.Z
	local depths: { number } = {}
	local missing = 0
	for _, offset in { -width / 2 + 0.02, 0, width / 2 - 0.02 } do
		local depth = skinDepth(deck, u + offset, thick / 2)
		if depth == nil then
			missing += 1
		else
			table.insert(depths, depth)
		end
	end
	if missing > 0 then
		return nil, missing
	end
	local height = math.max(depths[1], depths[2], depths[3])
	local cf = deck.CFrame * CFrame.new(u, -thick / 2 - height / 2, length / 2 - thick / 2)
	local size = Vector3.new(width, height, thick)
	local worst, failing, ruled = 0, 0, 0
	local isMinStrip = width <= MIN_STRIP + 0.001
	for _, face in SinkDepth.faceDepths(cf, size, characters, nil) do
		worst = math.max(worst, face.worst)
		-- axis 3 is the frame's LookVector (the deck's -Z), so sign -1 is the outer face, flush with the boot-end face
		if face.axis == 3 and face.sign == -1 then
			if face.worst > FLUSH_LIMIT then
				failing += face.failing
			end
		elseif isMinStrip and face.failing > 0 then
			-- F2: a strip already at the smallest width may sink up to FLUSH_LIMIT on any face
			if face.worst > FLUSH_LIMIT then
				failing += face.failing
			else
				ruled = math.max(ruled, face.worst)
			end
		else
			failing += face.failing
		end
	end
	local board: Board = {
		cf = cf,
		size = size,
		u = u,
		buried = height - math.min(depths[1], depths[2], depths[3]),
		worst = worst,
		failing = failing,
		ruled = ruled,
	}
	return board, 0
end

-- Splits a strip in halves where a face sinks or a sample finds no skin; a strip with no skin at all is overhang at once.
local function planStrip(deck: BasePart, u: number, width: number, leaves: { Leaf })
	local board, missing = evalStrip(deck, u, width)
	if board ~= nil and board.failing == 0 then
		table.insert(leaves, { u = u, w = width, board = board, missing = 0 })
		return
	end
	if missing < 3 and width / 2 >= MIN_STRIP - 0.001 then
		planStrip(deck, u - width / 4, width / 2, leaves)
		planStrip(deck, u + width / 4, width / 2, leaves)
		return
	end
	table.insert(leaves, { u = u, w = width, board = board, missing = missing })
end

-- 3. One shared layout (R3): each strip is split as fine as the finer of the two sides needs; the right side's strip at
-- -u is the left strip's mirror. Then each piece is measured on its own side's skin.
local layout: { Spot } = {}
for strip = 0, 5 do
	local uLeft = -HALF_WIDTH + COLUMN_STEP / 2 + strip * COLUMN_STEP
	local leavesLeft: { Leaf } = {}
	local leavesRight: { Leaf } = {}
	planStrip(deckLeft, uLeft, COLUMN_STEP, leavesLeft)
	planStrip(deckRight, -uLeft, COLUMN_STEP, leavesRight)
	local width = COLUMN_STEP
	for _, leaf in leavesLeft do
		width = math.min(width, leaf.w)
	end
	for _, leaf in leavesRight do
		width = math.min(width, leaf.w)
	end
	local count = math.floor(COLUMN_STEP / width + 0.5)
	for index = 0, count - 1 do
		table.insert(layout, { u = uLeft - COLUMN_STEP / 2 + width / 2 + index * width, w = width, strip = strip })
	end
end

local sideNames = { "left", "right" }
local sideBoards: { { Board? } } = { {}, {} }
local overhangStrips = { 0, 0 }
for sideIndex, label in sideNames do
	local deck = decks[sideIndex]
	local list = sideBoards[sideIndex]
	local sign = if sideIndex == 1 then 1 else -1 -- the right side's local u is the left's turned round
	local stripHasBoard: { [number]: boolean } = {}
	for index, spot in layout do
		local board = evalStrip(deck, sign * spot.u, spot.w)
		list[index] = board
		if board ~= nil then
			stripHasBoard[spot.strip] = true
			if board.failing > 0 then
				stop(`{label}: strip u={fmt(sign * spot.u)} w={fmt(spot.w)} still sinks {fmt(board.worst)}`)
			end
		end
	end
	for strip = 0, 5 do
		if not stripHasBoard[strip] then
			overhangStrips[sideIndex] += 1
		end
	end
	if overhangStrips[sideIndex] > MAX_OVERHANG then
		stop(`{label}: {overhangStrips[sideIndex]} overhang strips, more than {MAX_OVERHANG}`)
	end
	-- an overhang piece with skin on both sides of it (across the deck) is a gap in the middle of the boot end
	local firstSkin, lastSkin = math.huge, -math.huge
	for index = 1, #layout do
		if list[index] ~= nil then
			firstSkin, lastSkin = math.min(firstSkin, index), math.max(lastSkin, index)
		end
	end
	for index = 1, #layout do
		if list[index] == nil and index > firstSkin and index < lastSkin then
			stop(`{label}: overhang piece {index} (u={fmt(sign * layout[index].u)}) lies between two pieces with skin`)
		end
	end
end

-- The layout's pieces on the left, and the right's own, as the plan will build them.
local built: { [string]: { Piece } } = { left = {}, right = {} }
local boardsOf: { [string]: { Board } } = { left = {}, right = {} }
local overhangLines: { string } = {}
for sideIndex, label in sideNames do
	for index, spot in layout do
		local board = sideBoards[sideIndex][index]
		if board ~= nil then
			table.insert(boardsOf[label], board)
			table.insert(built[label], { cf = board.cf, size = board.size, name = `Board_{#built[label] + 1}` })
		else
			table.insert(
				overhangLines,
				`3   {label} overhang: no board at u={fmt((if sideIndex == 1 then 1 else -1) * spot.u)} w={fmt(spot.w)}`
			)
		end
	end
end
-- The right side is the left's mirror in footprint and top: its own boards differ only in how far down they go. Pieces are
-- paired by layout index (F2). One piece built on one side only is allowed: one MIN_STRIP piece next to that side's
-- overhang (the other deck hangs past the boot there).
local oneSideCount = { 0, 0 }
for index, spot in layout do
	local one, other = sideBoards[1][index], sideBoards[2][index]
	if one ~= nil and other ~= nil then
		local leftTop = mirrorCF(one.cf * CFrame.new(0, one.size.Y / 2, 0)).Position
		local rightTop = (other.cf * CFrame.new(0, other.size.Y / 2, 0)).Position
		if (leftTop - rightTop).Magnitude > TOL or math.abs(one.size.X - other.size.X) > TOL then
			stop(`layout piece {index} (u={fmt(spot.u)}) on the right is not the left's mirror in footprint and top`)
		end
	elseif one ~= nil or other ~= nil then
		local sideIndex = if one ~= nil then 1 else 2
		local sign = if sideIndex == 1 then 1 else -1
		local board = (if one ~= nil then one else other) :: Board
		local nextToOverhang = sideBoards[sideIndex][index - 1] == nil and index > 1
			or sideBoards[sideIndex][index + 1] == nil and index < #layout
		oneSideCount[sideIndex] += 1
		if math.abs(board.size.X - MIN_STRIP) > TOL or not nextToOverhang or oneSideCount[sideIndex] > 1 then
			stop(`{sideNames[sideIndex]}: layout piece {index} (u={fmt(sign * spot.u)}) is built on one side only`)
		else
			say(`3   one side only: {sideNames[sideIndex]} u={fmt(sign * spot.u)}`)
		end
	end
	for sideIndex, label in sideNames do
		local board = sideBoards[sideIndex][index]
		if board ~= nil and board.ruled > 0 then
			say(
				`3   sink 0.3 rule: {label} u={fmt((if sideIndex == 1 then 1 else -1) * spot.u)} worst {fmt(board.ruled)}`
			)
		end
	end
end
local addCount = #built.left + #built.right
local allPieces: { Piece } = {}
for _, label in sideNames do
	for _, piece in built[label] do
		table.insert(allPieces, { cf = piece.cf, size = piece.size, name = `{label} {piece.name}` })
	end
end
say(
	`3 plan: {#layout} layout pieces, left {#built.left} boards, right {#built.right} boards, overhang strips left {overhangStrips[1]} right {overhangStrips[2]}; will add {addCount} parts plus 2 models`
)
for _, text in overhangLines do
	say(text)
end

-- 4. The dry run builds the pieces temporarily in the Workspace (and the old ramps are ignored, as after the removal).
local ignoredParts: { BasePart } = {}
for _, found in removeList do
	if found:IsA("BasePart") then
		table.insert(ignoredParts, found)
	end
	for _, part in found:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(ignoredParts, part)
		end
	end
end

-- Every Route link near a new piece, walk-checked: the problems keyed by link.
local function routeProblems(options: any): ({ [string]: string }, number, number)
	local problems: { [string]: string } = {}
	local checked, unresolved = 0, 0
	local route = world:FindFirstChild("Route")
	if route == nil then
		return problems, 0, 0
	end
	local pointOf: { [string]: BasePart } = {}
	for _, child in route:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 11) == "RoutePoint_" then
			pointOf[string.sub(child.Name, 12)] = child
		end
	end
	for name, point in pointOf do
		local list = point:GetAttribute("Neighbours")
		if type(list) == "string" then
			for _, other in string.split(list, ",") do
				local trimmed = (string.gsub(other, "^%s+", ""))
				trimmed = (string.gsub(trimmed, "%s+$", ""))
				local key = (string.gsub(trimmed, "^RoutePoint_", ""))
				local target: BasePart? = pointOf[key]
				if target == nil then
					unresolved += 1
				elseif name < key then
					local near =
						math.min((nearestPiece(allPieces, point.Position)), (nearestPiece(allPieces, target.Position)))
					if near <= ROUTE_NEAR then
						checked += 1
						local problem = PathCheck.linkProblem(options, point.Position, target.Position)
						if problem ~= nil then
							problems[`{name}-{key}`] = problem
						end
					end
				end
			end
		end
	end
	return problems, checked, unresolved
end

local pieceLines: { string } = {}
local eggLines: { string } = {}
local routeLines: { string } = {}
local runError: string? = nil

local dryFolder = Instance.new("Folder")
dryFolder.Name = DRY_FOLDER
dryFolder.Archivable = false
local saved: { [BasePart]: { boolean } } = {}
for _, part in ignoredParts do
	saved[part] = { part.CanCollide, part.CanQuery }
	part.CanCollide = false
	part.CanQuery = false
end
local options = PathCheck.defaults(Workspace)
local okRun, message = pcall(function()
	for _, label in sideNames do
		for index, board in boardsOf[label] do
			local piece = built[label][index]
			table.insert(
				pieceLines,
				`3 {label} {piece.name}: centre {fmtV(piece.cf.Position)}, size {fmtV(piece.size)}, sliver {fmt(
					board.buried
				)}, worst sink {fmt(board.worst)}`
			)
		end
	end

	-- The route links now (no boards), the baseline.
	local before = routeProblems(options)

	-- Build every piece temporarily, the way the real run would.
	for _, label in sideNames do
		local deck = if label == "left" then deckLeft else deckRight
		for _, piece in built[label] do
			local part = Instance.new("Part")
			part.Name = `{label} {piece.name}`
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CFrame = piece.cf
			part.Size = piece.size
			part.Color = deck.Color
			part.Material = deck.Material
			part.Parent = dryFolder
		end
	end
	dryFolder.Parent = Workspace

	-- 4. The two Uncommon egg spots: how close is the nearest new piece.
	for _, name in { "EggSpot_Uncommon_2", "EggSpot_Uncommon_4" } do
		local spot = Workspace:FindFirstChild(name, true)
		if spot ~= nil and spot:IsA("BasePart") then
			local distance, closest = nearestPiece(allPieces, spot.Position)
			table.insert(eggLines, `4 {name} {fmtV(spot.Position)}: closest new piece {closest} at {fmt(distance)}`)
		else
			table.insert(eggLines, `4 {name} not found`)
		end
	end

	-- 5. Route links near a new piece: the problems the boards add.
	local after, checked, unresolved = routeProblems(options)
	local added = 0
	for key, problem in after do
		if before[key] == nil then
			added += 1
			table.insert(routeLines, `5   NEW problem {key}: {problem}`)
		end
	end
	table.insert(
		routeLines,
		1,
		`5 Route links near a new piece: {checked} checked ({unresolved} neighbours unresolved), problems with the boards that were not there before: {added}`
	)
end)
dryFolder:Destroy()
PathCheck.cleanup(options)
for part, state in saved do
	part.CanCollide = state[1]
	part.CanQuery = state[2]
end
if not okRun then
	runError = tostring(message)
	stop(`the dry run failed: {runError}`)
end

for _, text in pieceLines do
	say(text)
end
for _, text in eggLines do
	say(text)
end
for _, text in routeLines do
	say(text)
end

-- Decide.
local head =
	`boards {#built.left}+{#built.right}, overhang strips {overhangStrips[1]}+{overhangStrips[2]}, layout {#layout}`
if #stops > 0 then
	return finish(`STOP: {#stops} stop(s), nothing changed; {head}; first: {stops[1]}`)
end
if isDone then
	return finish("already done: every plank end piece is in place, nothing changed")
end
if CHECK_ONLY then
	return finish(`CHECK_ONLY: would remove 3 parts and add {addCount} parts, no stop fired, changed nothing; {head}`)
end

-- 6. Change the world (after the backup and a waypoint).
local backups = ServerStorage:FindFirstChild("WorldBackups")
if backups == nil then
	local folder = Instance.new("Folder")
	folder.Name = "WorldBackups"
	folder.Parent = ServerStorage
	backups = folder
end
local backupFolder = backups:FindFirstChild(BACKUP_NAME)
if backupFolder == nil then
	local folder = Instance.new("Folder")
	folder.Name = BACKUP_NAME
	folder.Parent = backups
	backupFolder = folder
end
for _, found in removeList do
	local path = found:GetFullName()
	local have = false
	for _, kept in backupFolder:GetChildren() do
		if kept:GetAttribute("BackupOf") == path and kept.Name == found.Name then
			have = true
		end
	end
	if not have then
		local copy = found:Clone()
		copy:SetAttribute("BackupOf", path)
		copy.Parent = backupFolder
	end
end
ChangeHistoryService:SetWaypoint("35-plank-ends: before")
for _, found in removeList do
	found:Destroy()
end
for sideIndex, label in sideNames do
	local deck = decks[sideIndex]
	local model = Instance.new("Model")
	model.Name = if label == "left" then "PlankEnd_Left" else "PlankEnd_Right"
	for _, piece in built[label] do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = piece.size
		part.CFrame = piece.cf
		part.Color = deck.Color
		part.Material = deck.Material
		part.Parent = model
	end
	model.Parent = surfaces
end
ChangeHistoryService:SetWaypoint("35-plank-ends: after")
return finish(`changed: removed 3 parts, added {addCount} parts; backup in ServerStorage.WorldBackups.{BACKUP_NAME}`)
