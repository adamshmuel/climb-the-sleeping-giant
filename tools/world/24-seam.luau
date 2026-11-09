--!strict
-- World build, plan 5 Task 16: the seam stitches (spec 5 section 5 "Seam match", Rule 80 "The seam shows where walking ends";
-- card work/p5t16/16-card.md, method work/p5t16/stepback-decision.md).
-- What it does: lays World.Seam on the style guide's seam table (SeamTable.TABLE, from
-- docs/design/v2/style-guide/nests-map.md, "Where it is"), on both sides of his belly:
--   Stitches  - cream dashes 0.5 x 0.12 x 1.55 (Z long, pitch 2.2), laid flat on his skin along the table line.
--   HemBand   - a blue band 1.2 x 0.1 x 0.56 every 0.5 studs, centred 1 stud down-slope (outward) of the line.
--   SeamLine  - invisible 0.2 studs cubes every 2 studs along each table line and each cuff rim (SlideProfile.CUFF_LEFT and
--               _RIGHT, at the cuff's own y). Attribute Down = flat unit Vector3 pointing outward (downhill) across the line.
-- Every piece is anchored with CanCollide, CanQuery and CanTouch off (nothing can be hit, stood on or touched).
-- Skipped on purpose: a stitch or band piece within 3 studs of a belly pocket part on its side, or within 0.5 studs of a
-- cuff strap (the counts of skipped pieces are printed).
-- STOP (nothing changed): World, Giant, Mockup_Nests.Art.Pockets or a pocket missing; a ray from above misses the skin; any
-- stitch more than 0.5 studs across from the table line (stop rule 1: a stitch never moves off the table); the counts not
-- as planned (EXPECTED); World.Seam there but not complete (a partial copy).
-- World.Seam complete (3 folders, the planned counts) = "already done".
-- A real run first creates ServerStorage.WorldBackups.p5t16 (and clones World.Seam into it when there is one).
-- CHECK_ONLY = true counts and prints only (nothing is created). Full report: shared.T16Report (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["24-seam"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- The seam table and its line helpers (seamLine, flatDistanceToLine, distanceToBox, marksAlong) live once in
-- src/shared/SeamTable.luau (Jest-free, so execute_luau can require it); WalkAreaFacts and Seam.spec read the same module.
local SeamTable = require(ReplicatedStorage.Shared.SeamTable)
local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)

-- Filled after the check-only run (plan: the counts the check printed). nil = the check has not been done yet.
local EXPECTED: { stitches: number, band: number, seamLine: number }? = { stitches = 20, band = 94, seamLine = 52 }

local STITCH_SIZE = Vector3.new(0.5, 0.12, 1.55)
local STITCH_PITCH = 2.2
local BAND_SIZE = Vector3.new(1.2, 0.1, 0.56)
local BAND_STEP = 0.5
local BAND_OFFSET = 1 -- studs down-slope of the line
local POINT_SIZE = 0.2
local POINT_STEP = 2
local POCKET_GAP = 3
local STRAP_GAP = 0.5
local ACROSS_LIMIT = 0.5
local SKIN_LIFT = 0.03 -- studs: a piece's underside lies this far above the skin (no flicker, no gap)
local RAY_FROM_Y = 80
local RAY_LENGTH = 120
local SIDES = { -1, 1 }

local report: { string } = {}

local function finish(text: string): string
	-- selene: allow(global_usage)
	shared.T16Report = report
	return text
end

local function sideName(side: number): string
	return if side < 0 then "L" else "R"
end

-- Where a flat line is at arc length s: the flat position and the flat unit tangent.
local function walk(line: { Vector3 }, s: number): (Vector3, Vector3)
	local left = s
	for index = 1, #line - 1 do
		local a = Vector3.new(line[index].X, 0, line[index].Z)
		local b = Vector3.new(line[index + 1].X, 0, line[index + 1].Z)
		local length = (b - a).Magnitude
		if left <= length or index == #line - 1 then
			local tangent = (b - a).Unit
			return a + tangent * math.min(left, length), tangent
		end
		left -= length
	end
	error("empty line")
end

local function flatLength(line: { Vector3 }): number
	local total = 0
	for index = 1, #line - 1 do
		total += Vector3.new(line[index + 1].X - line[index].X, 0, line[index + 1].Z - line[index].Z).Magnitude
	end
	return total
end

-- The flat unit vector across a tangent that points away from his middle (the sign of the side's x).
local function outwardOf(tangent: Vector3, side: number): Vector3
	local across = Vector3.new(tangent.Z, 0, -tangent.X)
	if across.X * side < 0 then
		across = -across
	end
	return across
end

type Piece = {
	folder: string,
	name: string,
	cframe: CFrame,
	size: Vector3,
	color: string?,
	point: Vector3?,
	down: Vector3?,
}

local function run24(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local giant = if world ~= nil then world:FindFirstChild("Giant") else nil
	if world == nil or giant == nil then
		return finish("STOP: Workspace.World or World.Giant is missing, nothing changed")
	end
	local nests = Workspace:FindFirstChild("Mockup_Nests")
	local art = if nests ~= nil then nests:FindFirstChild("Art") else nil
	local pocketsFolder = if art ~= nil then art:FindFirstChild("Pockets") else nil
	if pocketsFolder == nil then
		return finish("STOP: Workspace.Mockup_Nests.Art.Pockets is missing, nothing changed")
	end
	local strapParts: { BasePart } = {}
	local cuffArt = world:FindFirstChild("CuffArt")
	if cuffArt == nil then
		return finish("STOP: World.CuffArt is missing, nothing changed")
	end
	for _, name in { "CuffStrap_Left", "CuffStrap_Right" } do
		local model = cuffArt:FindFirstChild(name)
		if model == nil then
			return finish(`STOP: World.CuffArt.{name} is missing, nothing changed`)
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(strapParts, item)
			end
		end
	end
	local pocketParts: { [number]: { BasePart } } = {}
	for _, side in SIDES do
		local pocket = pocketsFolder:FindFirstChild(`BellyPocket_{if side < 0 then "Left" else "Right"}`)
		if pocket == nil then
			return finish(
				`STOP: Mockup_Nests.Art.Pockets.BellyPocket_{if side < 0 then "Left" else "Right"} is missing, nothing changed`
			)
		end
		local list: { BasePart } = {}
		for _, item in pocket:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(list, item)
			end
		end
		pocketParts[side] = list
	end

	local existing = world:FindFirstChild("Seam")
	if existing ~= nil then
		local counts: { [string]: number } = {}
		for _, name in { "Stitches", "HemBand", "SeamLine" } do
			local folder = existing:FindFirstChild(name)
			if folder == nil then
				return finish(`STOP: World.Seam is there but {name} is missing, nothing changed`)
			end
			counts[name] = #folder:GetChildren()
		end
		if
			EXPECTED ~= nil
			and counts.Stitches == EXPECTED.stitches
			and counts.HemBand == EXPECTED.band
			and counts.SeamLine == EXPECTED.seamLine
		then
			return finish("already done")
		end
		return finish(
			`STOP: World.Seam is there but incomplete or not as planned ({counts.Stitches}/{counts.HemBand}/{counts.SeamLine}), nothing changed`
		)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { giant }
	local function skin(flat: Vector3): RaycastResult?
		return Workspace:Raycast(Vector3.new(flat.X, RAY_FROM_Y, flat.Z), Vector3.new(0, -RAY_LENGTH, 0), params)
	end

	local function nearPocketOrStrap(side: number, point: Vector3): boolean
		for _, part in pocketParts[side] do
			if SeamTable.distanceToBox(part, point) < POCKET_GAP then
				return true
			end
		end
		for _, part in strapParts do
			if SeamTable.distanceToBox(part, point) < STRAP_GAP then
				return true
			end
		end
		return false
	end

	-- A flat dash laid on the skin at a flat place with the long axis along the tangent; nil when the ray misses.
	local function lay(flat: Vector3, tangent: Vector3, size: Vector3): (CFrame?, Vector3?)
		local hit = skin(flat)
		if hit == nil then
			return nil, nil
		end
		local normal = hit.Normal
		local along = (tangent - normal * tangent:Dot(normal)).Unit
		local centre = hit.Position + normal * (size.Y / 2 + SKIN_LIFT)
		return CFrame.fromMatrix(centre, normal:Cross(along), normal, along), hit.Position
	end

	local pieces: { Piece } = {}
	local counts = { stitches = 0, band = 0, seamLine = 0 }
	local skipped = { stitches = 0, band = 0 }
	local worstAcross = 0
	local worstCuffGap = 0
	local worstCuffAt = ""
	for _, side in SIDES do
		local line = SeamTable.seamLine(side)
		local total = flatLength(line)
		-- Stitches: the first dash starts at the line's start; centres every pitch.
		local index = 0
		local s = STITCH_SIZE.Z / 2
		while s + STITCH_SIZE.Z / 2 <= total + 1e-6 do
			local flat, tangent = walk(line, s)
			local cframe = lay(flat, tangent, STITCH_SIZE)
			if cframe == nil then
				return finish(
					`STOP: no skin under stitch {sideName(side)} at s {string.format("%.1f", s)}, nothing changed`
				)
			end
			local across = SeamTable.flatDistanceToLine(cframe.Position, line)
			worstAcross = math.max(worstAcross, across)
			if across > ACROSS_LIMIT then
				return finish(
					`STOP: stitch {sideName(side)} z{string.format("%.1f", cframe.Position.Z)} is {string.format(
						"%.2f",
						across
					)} across from the table (limit {ACROSS_LIMIT}); a stitch never moves, nothing changed`
				)
			end
			if nearPocketOrStrap(side, cframe.Position) then
				skipped.stitches += 1
			else
				index += 1
				counts.stitches += 1
				table.insert(pieces, {
					folder = "Stitches",
					name = `Stitch_{sideName(side)}_{string.format("%02d", index)}`,
					cframe = cframe,
					size = STITCH_SIZE,
					color = "FFF4DC",
				})
			end
			s += STITCH_PITCH
		end
		-- Hem band: every BAND_STEP, centred BAND_OFFSET outward of the line.
		index = 0
		local b = BAND_SIZE.Z / 2
		while b <= total do
			local flat, tangent = walk(line, b)
			local bandFlat = flat + outwardOf(tangent, side) * BAND_OFFSET
			local cframe = lay(bandFlat, tangent, BAND_SIZE)
			if cframe == nil then
				return finish(
					`STOP: no skin under band {sideName(side)} at s {string.format("%.1f", b)}, nothing changed`
				)
			end
			if nearPocketOrStrap(side, cframe.Position) then
				skipped.band += 1
			else
				index += 1
				counts.band += 1
				table.insert(pieces, {
					folder = "HemBand",
					name = `Band_{sideName(side)}_{string.format("%03d", index)}`,
					cframe = cframe,
					size = BAND_SIZE,
					color = "2F7FD0",
				})
			end
			b += BAND_STEP
		end
	end

	-- SeamLine: belly lines (on the skin) and cuff rims (at the cuff's own y).
	local function addPoints(label: string, side: number, marks: { Vector3 }, onSkin: boolean): string?
		for index, mark in marks do
			local before = marks[math.max(index - 1, 1)]
			local after = marks[math.min(index + 1, #marks)]
			local tangent = Vector3.new(after.X - before.X, 0, after.Z - before.Z).Unit
			local position = mark
			local hit = skin(Vector3.new(mark.X, 0, mark.Z))
			if onSkin then
				if hit == nil then
					return `STOP: no skin under SeamLine {label} point {index}, nothing changed`
				end
				position = hit.Position
			elseif hit ~= nil then
				local gap = math.abs(hit.Position.Y - mark.Y)
				if gap > worstCuffGap then
					worstCuffGap = gap
					worstCuffAt = `{label} point {index} cuff y {mark.Y} skin y {string.format("%.2f", hit.Position.Y)}`
				end
			end
			counts.seamLine += 1
			table.insert(pieces, {
				folder = "SeamLine",
				name = `Line_{label}_{string.format("%02d", index)}`,
				cframe = CFrame.new(position),
				size = Vector3.new(POINT_SIZE, POINT_SIZE, POINT_SIZE),
				down = outwardOf(tangent, side),
			})
		end
		return nil
	end
	for _, side in SIDES do
		local failure =
			addPoints(`Belly{sideName(side)}`, side, SeamTable.marksAlong(SeamTable.seamLine(side), POINT_STEP), true)
		if failure ~= nil then
			return finish(failure)
		end
	end
	local cuffs = {
		{ label = "CuffL", side = -1, line = SlideProfile.CUFF_LEFT },
		{ label = "CuffR", side = 1, line = SlideProfile.CUFF_RIGHT },
	}
	for _, cuff in cuffs do
		local failure = addPoints(cuff.label, cuff.side, SeamTable.marksAlong(cuff.line, POINT_STEP), false)
		if failure ~= nil then
			return finish(failure)
		end
	end

	local summary =
		`stitches {counts.stitches} (skipped {skipped.stitches}), band {counts.band} (skipped {skipped.band}), seamLine {counts.seamLine}; worst stitch across {string.format(
			"%.3f",
			worstAcross
		)}; worst cuff y vs skin {string.format("%.2f", worstCuffGap)} ({worstCuffAt})`
	table.insert(report, summary)
	print(`24-seam: will place {summary}`)
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: {summary}`)
	end
	if EXPECTED == nil then
		return finish(`STOP: EXPECTED is not filled yet (run CHECK_ONLY first), nothing changed | {summary}`)
	end
	if counts.stitches ~= EXPECTED.stitches or counts.band ~= EXPECTED.band or counts.seamLine ~= EXPECTED.seamLine then
		return finish(
			`STOP: counts {counts.stitches}/{counts.band}/{counts.seamLine} are not the plan {EXPECTED.stitches}/{EXPECTED.band}/{EXPECTED.seamLine}, nothing changed`
		)
	end

	-- The backup folder is made in the same call as the world change.
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	local backup = (backups :: Instance):FindFirstChild("p5t16")
	if backup == nil then
		backup = Instance.new("Folder")
		backup.Name = "p5t16"
		backup.Parent = backups
	end

	ChangeHistoryService:SetWaypoint("24-seam: before")
	local seam = Instance.new("Folder")
	seam.Name = "Seam"
	local folders: { [string]: Folder } = {}
	for _, name in { "Stitches", "HemBand", "SeamLine" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = seam
		folders[name] = folder
	end
	for _, piece in pieces do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Size = piece.size
		part.CFrame = piece.cframe
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if piece.color ~= nil then
			part.Material = Enum.Material.Fabric
			part.Color = Color3.fromHex(piece.color)
		else
			part.Transparency = 1
		end
		if piece.down ~= nil then
			part:SetAttribute("Down", piece.down)
		end
		part.Parent = folders[piece.folder]
	end
	seam.Parent = world
	ChangeHistoryService:SetWaypoint("24-seam: after")

	local checkOk = #folders.Stitches:GetChildren() == counts.stitches
		and #folders.HemBand:GetChildren() == counts.band
		and #folders.SeamLine:GetChildren() == counts.seamLine
	if not checkOk then
		return finish("placed, but the check of the counts failed")
	end
	return finish(`placed {summary}`)
end

return run24()
