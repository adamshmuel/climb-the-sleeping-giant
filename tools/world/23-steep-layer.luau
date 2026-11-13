--!strict
-- World prep, plan 5 (egg nests and climbing) Task 15a: the smooth, invisible steep layer over his side and cuffs
-- (card work/p5t15/card.md Step 3; details work/p5t15/p5t15-tests.md "Script 23"; spec 5 Rule 80 "The seam shows where
-- walking ends" and section 5 "Steep face" 75 degrees).
-- What it does: where the cloth is steeper than the seam angle but a character still walks on it (steepList of
-- src/server/World/SlideProfile.luau, so the script and SteepLayer.spec read the slope one way), it adds thin invisible
-- solid pieces in the new folder Workspace.World.SteepLayer so the player slides off at the seam:
--   one piece per neighbouring pair of side rows (24 a side, z -38 to -14) and per neighbouring pair of cuff stations
--   (1, 1.5, 2, 2.5, 3: 4 a cuff). A piece is a 0.2-thick Part. Its face leans max(75, the chord angle of its places)
--   degrees from flat, outward from his body. It is pushed out along its face until the lowest of the 9 points on
--   its face (corners, edge middles, middle) is 0.1 clear of his skin (never through it). Then the cover is read at every
--   place the way SteepLayer.spec reads it (height of the face over the place along his skin's normal); if the largest is
--   over 1 stud, the pair is split in two (the upper half and the lower half of its places) and each half is placed the
--   same way. A split pair is stopped on if a half is still over 1 stud.
-- Names: Steep_<Left|Right>_z<z> and Steep_<Left|Right>Cuff_<a>-<b>; a split pair gets _top and _bottom.
-- Every piece: Transparency 1, CanCollide true, CanQuery true, CanTouch false, Anchored true, CastShadow false.
-- Worlds, checked before any change: World.Giant.body_and_cushion / left_arm / right_arm missing = STOP; a piece's name
-- (or its _top/_bottom) already there = that pair is skipped; every pair skipped = "already done".
-- Before any change it makes ServerStorage.WorldBackups.Plan5Task15 holding a copy of World.SteepLayer (if it is
-- there) and one marker folder for each of the three body pieces (their names only; the giant is not changed), in the
-- same call.
-- Rollback: delete World.SteepLayer (or clone the backup back).
-- Dry run (the default, nothing is made): `pcall(require(ServerStorage.Tools.world["23-steep-layer"]:Clone()))` through
-- execute_luau in Studio EDIT mode. To make the pieces, set `shared.Steep23Apply = true` first in the same paste.
-- The full report is in shared.Steep23Report (list of lines).

-- selene: allow(global_usage)
local CHECK_ONLY = shared.Steep23Apply ~= true

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SlideProfile = require(ServerScriptService.Server.World.SlideProfile)

local BACKUP_NAME = "Plan5Task15"
local FOLDER_NAME = "SteepLayer"
local THICKNESS = 0.2 -- studs (card: 0.2 thick)
local MIN_FACE_DEGREES = 75 -- spec 5, section 5 "Steep face"
local MAX_FACE_DEGREES = 89
local SKIN_GAP = 0.1 -- the lowest clearance of a piece's face over his skin
local SKIN_GAP_LEAST = 0.06 -- SteepLayer.spec wants more than 0.05
local FROM_OUTSIDE = 6 -- studs: the clearance rays start this far outside the face
local PAD = 0.1 -- studs: a piece reaches this far past its places on every side
local COVER_LIMIT = 1 -- studs (SteepLayer.spec: the layer stands at most this far over his skin along its normal)
local COVER_LEAST = -0.01
local SKIN = Color3.fromHex("e8b98f")
type Spot = { position: Vector3, skinNormal: Vector3 }
-- One neighbouring pair: its rows' places (steep-layer list) and its name.
type Pair = { name: string, first: { Spot }, second: { Spot }, skinParams: RaycastParams }
type Fit = {
	cframe: CFrame,
	size: Vector3,
	degrees: number,
	lowest: number, -- the lowest clearance of the 9 face points
	maxCover: number,
	minCover: number,
}

local report: { string } = {}
local function note(text: string)
	table.insert(report, text)
end

local function getMesh(giant: Instance, pieceName: string): MeshPart?
	local piece = giant:FindFirstChild(pieceName)
	local mesh = if piece ~= nil then piece:FindFirstChild(pieceName) else nil
	if mesh ~= nil and mesh:IsA("MeshPart") then
		return mesh
	end
	return nil
end

local function spotsOf(places: { SlideProfile.Place }, skinParams: RaycastParams): { Spot }
	local spots: { Spot } = {}
	for _, place in places do
		local hit = Workspace:Raycast(
			Vector3.new(place.position.X, SlideProfile.BODY_SLOPE_RAY_ABOVE, place.position.Z),
			Vector3.new(0, -SlideProfile.BODY_SLOPE_RAY_LENGTH, 0),
			skinParams
		)
		if hit == nil then
			error(`no skin under a place at {place.position}`)
		end
		table.insert(spots, { position = place.position, skinNormal = hit.Normal })
	end
	return spots
end

-- The way a patch faces: the flat part of his skin's normals, so it always points away from the body, downhill.
local function downhill(spots: { Spot }): Vector3?
	local sum = Vector3.zero
	for _, spot in spots do
		sum += Vector3.new(spot.skinNormal.X, 0, spot.skinNormal.Z)
	end
	if sum.Magnitude < 1e-3 then
		return nil
	end
	return sum.Unit
end

-- Fits one thin piece over `spots`. Returns nil when there is nothing to fit.
local function fit(spots: { Spot }, dir: Vector3, bodyParams: RaycastParams): Fit?
	if #spots == 0 then
		return nil
	end
	-- the chord: from the highest place to the lowest, measured along the slope's direction
	local top, low = spots[1].position, spots[1].position
	for _, spot in spots do
		if spot.position.Y > top.Y then
			top = spot.position
		end
		if spot.position.Y < low.Y then
			low = spot.position
		end
	end
	local run = (low - top):Dot(dir)
	local drop = top.Y - low.Y
	local chord = if drop > 0 then math.deg(math.atan2(drop, math.max(run, 1e-6))) else 0
	local degrees = math.clamp(math.max(MIN_FACE_DEGREES, chord), MIN_FACE_DEGREES, MAX_FACE_DEGREES)
	local sine, cosine = math.sin(math.rad(degrees)), math.cos(math.rad(degrees))
	local normal = Vector3.new(dir.X * sine, cosine, dir.Z * sine)
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local along = across:Cross(normal) -- across, normal, along are at right angles

	-- the plane normal:dot(X) = offset; first it touches the place that is farthest out along the normal
	local offset = -math.huge
	for _, spot in spots do
		offset = math.max(offset, normal:Dot(spot.position))
	end

	local size = Vector3.zero
	local face = Vector3.zero
	local lowest = 0
	for _ = 1, 8 do
		-- where a ray straight down from each place meets the plane, and the box that holds them all
		local minAcross, maxAcross, minAlong, maxAlong = math.huge, -math.huge, math.huge, -math.huge
		for _, spot in spots do
			local x, z = spot.position.X, spot.position.Z
			local meet = Vector3.new(x, (offset - normal.X * x - normal.Z * z) / normal.Y, z)
			minAcross, maxAcross = math.min(minAcross, meet:Dot(across)), math.max(maxAcross, meet:Dot(across))
			minAlong, maxAlong = math.min(minAlong, meet:Dot(along)), math.max(maxAlong, meet:Dot(along))
		end
		minAcross, maxAcross, minAlong, maxAlong = minAcross - PAD, maxAcross + PAD, minAlong - PAD, maxAlong + PAD
		size = Vector3.new(maxAcross - minAcross, THICKNESS, maxAlong - minAlong)
		face = across * ((minAcross + maxAcross) / 2) + along * ((minAlong + maxAlong) / 2) + normal * offset
		lowest = math.huge
		for _, sideways in { -1, 0, 1 } do
			for _, lengthways in { -1, 0, 1 } do
				local point = face + across * (sideways * size.X / 2) + along * (lengthways * size.Z / 2)
				local start = point + normal * FROM_OUTSIDE
				local hit = Workspace:Raycast(start, -normal * (FROM_OUTSIDE * 2), bodyParams)
				if hit ~= nil then
					lowest = math.min(lowest, (hit.Position - start).Magnitude - FROM_OUTSIDE)
				end
			end
		end
		if lowest == math.huge then
			local where = string.format("%.1f, %.1f, %.1f", face.X, face.Y, face.Z)
			local heading = string.format("%.2f, %.2f", dir.X, dir.Z)
			local lo, hi = top, low
			for _, spot in spots do
				lo = Vector3.new(math.min(lo.X, spot.position.X), 0, math.min(lo.Z, spot.position.Z))
				hi = Vector3.new(math.max(hi.X, spot.position.X), 0, math.max(hi.Z, spot.position.Z))
			end
			local span = string.format("x %.1f..%.1f z %.1f..%.1f y %.1f..%.1f", lo.X, hi.X, lo.Z, hi.Z, low.Y, top.Y)
			error(`no skin under a piece: face {where}, dir {heading}, {#spots} places, {span}`)
		end
		if math.abs(lowest - SKIN_GAP) < 0.005 then
			break
		end
		offset += SKIN_GAP - lowest
	end
	if lowest < SKIN_GAP_LEAST then
		error(`a piece cannot be placed clear of his skin (lowest clearance {lowest})`)
	end

	-- the cover, read the way SteepLayer.spec reads it
	local maxCover, minCover = -math.huge, math.huge
	for _, spot in spots do
		local x, z = spot.position.X, spot.position.Z
		local meet = Vector3.new(x, (offset - normal.X * x - normal.Z * z) / normal.Y, z)
		local height = (meet - spot.position):Dot(spot.skinNormal)
		maxCover, minCover = math.max(maxCover, height), math.min(minCover, height)
	end
	local center = face - normal * (THICKNESS / 2)
	return {
		cframe = CFrame.fromMatrix(center, across, normal, along),
		size = size,
		degrees = degrees,
		lowest = lowest,
		maxCover = maxCover,
		minCover = minCover,
	}
end

local function halves(list: { Spot }): ({ Spot }, { Spot })
	local upper: { Spot }, lower: { Spot } = {}, {}
	local cut = math.ceil(#list / 2)
	for index, spot in list do
		table.insert(if index <= cut then upper else lower, spot)
	end
	return upper, lower
end

local function merged(a: { Spot }, b: { Spot }): { Spot }
	local all: { Spot } = {}
	for _, spot in a do
		table.insert(all, spot)
	end
	for _, spot in b do
		table.insert(all, spot)
	end
	return all
end

type Planned = { name: string, fit: Fit, spots: { Spot } }

local function describeFit(name: string, result: Fit): string
	local face = string.format("%.1f", result.degrees)
	local clear = string.format("%.2f", result.lowest)
	local cover = string.format("%.2f to %.2f", result.minCover, result.maxCover)
	return `{name}: face {face} deg, clearance {clear}, cover {cover}`
end

-- A pair is there when a piece is named after it (its name, or its name and a part: _top, _bottom_top ...).
local function pairIsThere(layer: Instance?, name: string): boolean
	if layer == nil then
		return false
	end
	for _, child in layer:GetChildren() do
		if child.Name == name or string.sub(child.Name, 1, #name + 1) == `{name}_` then
			return true
		end
	end
	return false
end

local function within(result: Fit): boolean
	return result.maxCover <= COVER_LIMIT and result.minCover >= COVER_LEAST
end

local function coverText(result: Fit): string
	return string.format("%.2f to %.2f", result.minCover, result.maxCover)
end

-- Pieces for one half: one, or two quarters when the cover of the half is over the limit (no third split).
local function planHalf(
	name: string,
	a: { Spot },
	b: { Spot },
	dir: Vector3,
	bodyParams: RaycastParams
): ({ Planned }, string?)
	local all = merged(a, b)
	local result = fit(all, dir, bodyParams)
	if result == nil then
		return {}, nil
	end
	if within(result) then
		return { { name = name, fit = result, spots = all } }, nil
	end
	local aUpper, aLower = halves(a)
	local bUpper, bLower = halves(b)
	local upperSpots, lowerSpots = merged(aUpper, bUpper), merged(aLower, bLower)
	local upper, lower = fit(upperSpots, dir, bodyParams), fit(lowerSpots, dir, bodyParams)
	if upper == nil or lower == nil then
		return {}, `{name}: half {coverText(result)} and it can't be split`
	end
	if not within(upper) or not within(lower) then
		return {},
			`{name}: half {coverText(result)}, quarters {coverText(upper)} (upper) and {coverText(lower)} (lower)`
	end
	return {
		{ name = `{name}_top`, fit = upper, spots = upperSpots },
		{ name = `{name}_bottom`, fit = lower, spots = lowerSpots },
	},
		nil
end

-- Pieces for one pair: one, or two halves when the cover of one is over the limit, or quarters of a half still over.
-- Returns the pieces, an error text on a stop, and whether the pair was split.
local function plan(pair: Pair, bodyParams: RaycastParams): ({ Planned }, string?, boolean)
	local spots = merged(pair.first, pair.second)
	local dir = downhill(spots)
	if #spots == 0 then
		return {}, nil, false
	end
	if dir == nil then
		return {}, `{pair.name}: no direction down the slope`, false
	end
	local whole = fit(spots, dir, bodyParams)
	if whole == nil then
		return {}, nil, false
	end
	if within(whole) then
		return { { name = pair.name, fit = whole, spots = spots } }, nil, false
	end
	local firstUpper, firstLower = halves(pair.first)
	local secondUpper, secondLower = halves(pair.second)
	local topPieces, topProblem = planHalf(`{pair.name}_top`, firstUpper, secondUpper, dir, bodyParams)
	local bottomPieces, bottomProblem = planHalf(`{pair.name}_bottom`, firstLower, secondLower, dir, bodyParams)
	if topProblem ~= nil or bottomProblem ~= nil then
		return {}, topProblem or bottomProblem, true
	end
	if #topPieces == 0 or #bottomPieces == 0 then
		return {}, `{pair.name}: gap {coverText(whole)} and it can't be split`, false
	end
	local pieces: { Planned } = {}
	for _, piece in topPieces do
		table.insert(pieces, piece)
	end
	for _, piece in bottomPieces do
		table.insert(pieces, piece)
	end
	return pieces, nil, true
end

local function run23(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local giant = if world ~= nil then world:FindFirstChild("Giant") else nil
	if world == nil or giant == nil then
		return "STOP: Workspace.World.Giant is missing, nothing changed"
	end
	local bodyMesh = getMesh(giant, SlideProfile.SIDE_PIECE)
	local leftArm = getMesh(giant, "left_arm")
	local rightArm = getMesh(giant, "right_arm")
	if bodyMesh == nil or leftArm == nil or rightArm == nil then
		return "STOP: a body piece (body_and_cushion, left_arm, right_arm) is missing, nothing changed"
	end
	local started = os.clock()
	local existingLayer = world:FindFirstChild(FOLDER_NAME)

	-- every neighbouring pair, from the same lists SteepLayer.spec reads
	local bodyParams = RaycastParams.new()
	bodyParams.FilterType = Enum.RaycastFilterType.Include
	bodyParams.FilterDescendantsInstances = { bodyMesh, leftArm, rightArm }
	bodyParams.RespectCanCollide = false
	local pairs: { Pair } = {}

	local function sidePairs(label: string, line: { Vector3 }, towards: number)
		local skinParams = SlideProfile.onlyParams(bodyMesh)
		local samples = SlideProfile.sideSamples(line)
		local rows = SlideProfile.sideRows(samples, label:lower(), towards, bodyMesh)
		local spotLists: { { Spot } } = {}
		for index, row in rows do
			local places = SlideProfile.steepList(row)
			spotLists[index] = spotsOf(places, skinParams)
		end
		for index = 1, #rows - 1 do
			table.insert(pairs, {
				name = `Steep_{label}_z{samples[index].Z}`,
				first = spotLists[index],
				second = spotLists[index + 1],
				skinParams = skinParams,
			})
		end
	end

	local function cuffPairs(label: string, line: { Vector3 }, arm: MeshPart, strapStart: Vector3)
		local skinParams = SlideProfile.onlyParams(arm)
		local samples = SlideProfile.cuffSamples(line)
		local spotLists: { { Spot } } = {}
		for index, station in samples do
			local row =
				SlideProfile.cuffRow(skinParams, `{label:lower()} cuff, station {station.number}`, station, strapStart)
			local places = SlideProfile.steepList(row)
			spotLists[index] = spotsOf(places, skinParams)
		end
		for index = 1, #samples - 1 do
			table.insert(pairs, {
				name = `Steep_{label}Cuff_{samples[index].number}-{samples[index + 1].number}`,
				first = spotLists[index],
				second = spotLists[index + 1],
				skinParams = skinParams,
			})
		end
	end

	sidePairs("Left", SlideProfile.SEAM_LEFT, -1)
	task.wait()
	sidePairs("Right", SlideProfile.SEAM_RIGHT, 1)
	task.wait()
	cuffPairs("Left", SlideProfile.CUFF_LEFT, leftArm, SlideProfile.STRAP_START_LEFT)
	task.wait()
	cuffPairs("Right", SlideProfile.CUFF_RIGHT, rightArm, SlideProfile.STRAP_START_RIGHT)

	-- the plan: skip pairs that are already there, fit the rest
	local planned: { Planned } = {}
	local skipped, empty, splits = 0, 0, 0
	local stops: { string } = {}
	local largest, largestName = -math.huge, ""
	for _, pair in pairs do
		local there = pairIsThere(existingLayer, pair.name)
		if there then
			skipped += 1
		else
			local pieces, problem, split = plan(pair, bodyParams)
			if problem ~= nil then
				table.insert(stops, problem)
				note(`OVER: {problem}`)
			elseif #pieces == 0 then
				empty += 1
			else
				if split then
					splits += 1
					note(`split: {pair.name}`)
				end
				for _, piece in pieces do
					table.insert(planned, piece)
					note(describeFit(piece.name, piece.fit))
					if piece.fit.maxCover > largest then
						largest, largestName = piece.fit.maxCover, piece.name
					end
				end
			end
		end
		task.wait()
	end
	-- selene: allow(global_usage)
	shared.Steep23Report = report
	local largestText = string.format("%.2f", largest)
	local seconds = string.format("%.1f", os.clock() - started)
	local summary = `23-steep-layer: {#pairs} pairs, {#planned} pieces to make, {skipped} already there, {empty} with no places`
		.. `, {splits} split in two, largest cover {largestText} ({largestName}), {seconds} s`
	print(summary)
	if #stops > 0 then
		return `STOP: {#stops} pair(s) over the limit, nothing changed. First: {stops[1]}`
	end
	if #planned == 0 and skipped > 0 then
		return `already done ({skipped} pairs)`
	end
	if #planned == 0 then
		return `nothing to make: {summary}`
	end
	if CHECK_ONLY then
		return `DRY RUN (nothing made): {summary}`
	end

	-- the backup in the same call, before the first change
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		local folder = Instance.new("Folder")
		folder.Name = "WorldBackups"
		folder.Parent = ServerStorage
		backups = folder
	end
	local backupFolder = (backups :: Instance):FindFirstChild(BACKUP_NAME)
	if backupFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		folder.Parent = backups
		backupFolder = folder
	end
	if existingLayer ~= nil and (backupFolder :: Instance):FindFirstChild(`{FOLDER_NAME}_Before23`) == nil then
		local copy = existingLayer:Clone()
		copy.Name = `{FOLDER_NAME}_Before23`
		copy.Parent = backupFolder
	end
	for _, mesh in { bodyMesh, leftArm, rightArm } do
		local markerName = `Marker_{mesh.Name}`
		if (backupFolder :: Instance):FindFirstChild(markerName) == nil then
			local marker = Instance.new("Folder")
			marker.Name = markerName
			marker:SetAttribute("BackupOf", mesh:GetFullName())
			marker.Parent = backupFolder
		end
	end

	ChangeHistoryService:SetWaypoint("23-steep-layer: before")
	local layer: Instance
	if existingLayer == nil then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = world
		layer = folder
	else
		layer = existingLayer
	end
	for _, piece in planned do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Material = Enum.Material.SmoothPlastic
		part.Color = SKIN
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = piece.fit.size
		part.CFrame = piece.fit.cframe
		part.Parent = layer
	end
	ChangeHistoryService:SetWaypoint("23-steep-layer: after")
	return string.sub(`made {#planned} pieces in World.{FOLDER_NAME}: {summary}`, 1, 1000)
end

return run23
