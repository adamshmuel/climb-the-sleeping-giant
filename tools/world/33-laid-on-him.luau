--!strict
-- World prep, plan 3 (gardens and ways up) Task 5b1: plank, deck and meadow flowers laid on him
-- (docs/plans/v2/gardens-and-ways-up.md, "Task 6", "5b1"; spec Rule 103 (Nothing sinks into a main character)).
-- Card: work/t5b/card.md; the decision table: work/t5b/5b1-scripts.md.
-- Why: wood and flowers swallowed by the giant's body look broken. Four parts sink deeper than the Rule 103 limit.
-- What it does, for each of the four parts (Workspace.World): measures the DENSE worst depth (points every 0.85 studs along
-- each tested face, 3 across, SinkDepth.depth, so the test's own measure), then
--   * LapLanding.Deck (belly face): narrows that deck at that one face by the worst depth
--     + 0.1, rounded up to 0.1 (the far face stays put). Stops when the trim is over 1.2 studs;
--   * White_Flower_01, White_Flower_03 (the two flowers within 6 studs of him) and the Nature_GrassTuft at about
--     (16.3, -67.2): moves the part (the whole tuft model for the grass) flat away from his skin by the worst depth + 0.3.
--     The way is the shortest inward ray of the deepest point, turned round, with y set to 0. Stops when the move is over
--     2 studs, when the new spot is within 5 studs of a landing spot or an egg spot, or inside a garden.
-- LapPlank_Left.Deck is accepted by name (product, Rule 103, 2026-11-04: body-side face only, up to 0.3) and is never changed.
-- Nature_FloweringBush (MeadowBushR141) is never touched. It also prints the predicted worst after each change.
-- Before any change it clones every part it changes into ServerStorage.WorldBackups.t5b (one already there is left alone)
-- and sets a ChangeHistoryService waypoint. Rollback: paste the clones back (attribute BackupOf = the old full path).
-- Worlds, checked before any change: all four found and every one already clear = "already done"; a part missing or any
-- stop = nothing changed. CHECK_ONLY = true measures and prints only.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau (or require a copy of it).

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local requireModule: (Instance) -> any = require :: any
-- The measure is tools/checks/SinkDepth.luau (a clone, so an edited copy is read).
local SinkDepth =
	requireModule(ServerStorage:WaitForChild("Tools"):WaitForChild("checks"):WaitForChild("SinkDepth"):Clone())

local BACKUP_NAME = "t5b"
local MAIN_TAG = "MainCharacter"
local STEP = 0.85 -- studs between the dense points along a face
local NEAR = 6 -- studs: a flower within this of his box is a candidate
local TRIM_EXTRA = 0.1
local MOVE_EXTRA = 0.3
local MOVE_MAX = 2
local SPOT_CLEAR = 5 -- studs from a landing spot or an egg spot
local GRASS_AT = Vector3.new(16.3, 0, -67.2)
local GRASS_RADIUS = 3

type CharacterPart = { part: BasePart, params: RaycastParams, min: Vector3, max: Vector3 }
type Item = {
	label: string,
	part: BasePart,
	root: Instance, -- what is backed up and moved: the part, or the tuft model
	axis: number?, -- trim items: the one tested face (1 = Right, 3 = Look) and its sign
	sign: number?,
	maxChange: number,
	worst: number,
	failing: number,
	total: number,
	point: Vector3?,
	trim: number,
	move: Vector3,
	stop: string?,
	after: number,
}

local DIRECTIONS: { Vector3 } = {}
for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			if x ~= 0 or y ~= 0 or z ~= 0 then
				table.insert(DIRECTIONS, Vector3.new(x, y, z).Unit)
			end
		end
	end
end

local function fmt(n: number): string
	return string.format("%.2f", n)
end

-- The dense worst depth over the wanted faces of a box (cf, size). Same limits and 3 x 3 inset as SinkDepth.faceDepths,
-- but the points along a face are STEP apart. Returns worst (0 when under the limit), failing, total, deepest point.
local function measure(
	cf: CFrame,
	size: Vector3,
	axis: number?,
	sign: number?,
	characters: { CharacterPart }
): (number, number, number, Vector3?)
	local longest = 1
	if size.Y > size.X and size.Y >= size.Z then
		longest = 2
	elseif size.Z > size.X and size.Z > size.Y then
		longest = 3
	end
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local sizes = { size.X, size.Y, size.Z }
	local worst, failing, total = 0, 0, 0
	local point: Vector3? = nil
	for faceAxis = 1, 3 do
		for _, faceSign in { -1, 1 } do
			local normal = axes[faceAxis] * faceSign
			local wanted = if axis == nil then true else faceAxis == axis and faceSign == sign
			if wanted and normal.Y >= SinkDepth.DOWN_FACE_Y then
				local limit = if faceAxis == longest then SinkDepth.END_LIMIT else SinkDepth.OTHER_LIMIT
				local others = {}
				for other = 1, 3 do
					if other ~= faceAxis then
						table.insert(others, other)
					end
				end
				local reachA = math.max(0, sizes[others[1]] / 2 - SinkDepth.FACE_INSET)
				local reachB = math.max(0, sizes[others[2]] / 2 - SinkDepth.FACE_INSET)
				local alongAxis, acrossAxis, along, across = others[1], others[2], reachA, reachB
				if reachB > reachA then
					alongAxis, acrossAxis, along, across = others[2], others[1], reachB, reachA
				end
				local middle = cf.Position + normal * (sizes[faceAxis] / 2)
				local intervals = math.ceil(2 * along / STEP)
				for i = 0, intervals do
					local a = if intervals == 0 then 0 else -along + 2 * along * i / intervals
					for b = -1, 1 do
						local p = middle + axes[alongAxis] * a + axes[acrossAxis] * (b * across)
						local depth = SinkDepth.depth(characters, p)
						total += 1
						if depth > limit then
							failing += 1
							if depth > worst then
								worst = depth
								point = p
							end
						end
					end
				end
			end
		end
	end
	return worst, failing, total, point
end

-- The way out of his body from a point: the shortest inward ray of the part it sits deepest in, turned round, y = 0.
local function wayOut(characters: { CharacterPart }, point: Vector3): Vector3?
	local deepest, holder = 0, nil
	for _, box in characters do
		local d = SinkDepth.depth({ box }, point)
		if d > deepest then
			deepest, holder = d, box
		end
	end
	if holder == nil then
		return nil
	end
	local shortest = math.huge
	local out: Vector3? = nil
	for _, direction in DIRECTIONS do
		local hit = Workspace:Raycast(
			point + direction * SinkDepth.RAY_LENGTH,
			-direction * SinkDepth.RAY_LENGTH,
			holder.params
		)
		if hit ~= nil and SinkDepth.RAY_LENGTH - hit.Distance < shortest then
			shortest = SinkDepth.RAY_LENGTH - hit.Distance
			out = direction
		end
	end
	if out == nil then
		return nil
	end
	local flat = Vector3.new(out.X, 0, out.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	return flat.Unit
end

-- A reason the new spot is not allowed (near a landing spot or an egg spot, inside a garden), or nil.
local function blockedAt(world: Instance, spot: Vector3): string?
	for _, folderName in { "LandingSpots", "EggSpots" } do
		local folder = world:FindFirstChild(folderName)
		if folder ~= nil then
			for _, child in folder:GetChildren() do
				if child:IsA("PVInstance") and (child:GetPivot().Position - spot).Magnitude < SPOT_CLEAR then
					return `within {SPOT_CLEAR} studs of {child:GetFullName()}`
				end
			end
		end
	end
	local plots = world:FindFirstChild("Plots")
	if plots ~= nil then
		for _, plot in plots:GetChildren() do
			local volume = plot:FindFirstChild("GardenVolume")
			if volume ~= nil and volume:IsA("BasePart") then
				local local3 = volume.CFrame:PointToObjectSpace(spot)
				local half = volume.Size / 2
				if math.abs(local3.X) <= half.X and math.abs(local3.Y) <= half.Y and math.abs(local3.Z) <= half.Z then
					return `inside {plot.Name}.GardenVolume`
				end
			end
		end
	end
	return nil
end

local function newItem(
	label: string,
	part: BasePart,
	root: Instance,
	axis: number?,
	sign: number?,
	maxChange: number
): Item
	return {
		label = label,
		part = part,
		root = root,
		axis = axis,
		sign = sign,
		maxChange = maxChange,
		worst = 0,
		failing = 0,
		total = 0,
		point = nil,
		trim = 0,
		move = Vector3.zero,
		stop = nil,
		after = 0,
	}
end

-- The CFrame and size a part would have after the item's planned change.
local function changed(item: Item): (CFrame, Vector3)
	local part = item.part
	if item.axis ~= nil and item.sign ~= nil then
		local sizes = { part.Size.X, part.Size.Y, part.Size.Z }
		sizes[item.axis] -= item.trim
		local shift = Vector3.zero
		if item.axis == 1 then
			shift = Vector3.new(-item.sign * item.trim / 2, 0, 0)
		else
			shift = Vector3.new(0, 0, item.sign * item.trim / 2) -- axis 3 is the LookVector, local -Z
		end
		return part.CFrame * CFrame.new(shift), Vector3.new(sizes[1], sizes[2], sizes[3])
	end
	return part.CFrame + item.move, part.Size
end

local function plan(item: Item, world: Instance, characters: { CharacterPart })
	item.worst, item.failing, item.total, item.point =
		measure(item.part.CFrame, item.part.Size, item.axis, item.sign, characters)
	if item.worst == 0 then
		return
	end
	if item.axis ~= nil then
		item.trim = math.ceil((item.worst + TRIM_EXTRA) * 10 - 1e-6) / 10
		if item.trim > item.maxChange then
			item.stop = `trim {fmt(item.trim)} is over {item.maxChange}`
		end
	else
		local direction = if item.point ~= nil then wayOut(characters, item.point) else nil
		if direction == nil then
			item.stop = "no flat way out"
			return
		end
		item.move = direction * (item.worst + MOVE_EXTRA)
		if item.move.Magnitude > item.maxChange then
			item.stop = `move {fmt(item.move.Magnitude)} is over {item.maxChange}`
			return
		end
		item.stop = blockedAt(world, item.part.Position + item.move)
	end
	if item.stop == nil then
		local cf, size = changed(item)
		item.after = (measure(cf, size, item.axis, item.sign, characters))
		if item.after > 0 then
			item.stop = `the change leaves {fmt(item.after)} sunk`
		end
	end
end

local function row(item: Item): string
	local what = if item.worst == 0
		then "clear"
		elseif item.axis ~= nil then `trim {fmt(item.trim)}`
		else `move ({fmt(item.move.X)}, 0, {fmt(item.move.Z)})`
	local stop = if item.stop ~= nil then ` STOP {item.stop}` else ""
	return `{item.label} | {item.part.ClassName} cc={item.part.CanCollide} | dense worst {fmt(item.worst)} `
		.. `({item.failing}/{item.total}) | {what} | after {fmt(item.after)}{stop}`
end

local function backup(items: { Item })
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
	for _, item in items do
		local path = item.root:GetFullName()
		local have = false
		for _, saved in folder:GetChildren() do
			if saved:GetAttribute("BackupOf") == path and saved.Name == item.root.Name then
				have = true
			end
		end
		if not have then
			local copy = item.root:Clone()
			copy:SetAttribute("BackupOf", path)
			copy.Parent = folder
		end
	end
end

local function finish(lines: { string }, head: string): string
	return string.sub(head .. "\n" .. table.concat(lines, "\n"), 1, 1000)
end

local world = Workspace:WaitForChild("World")
local characters: { CharacterPart } = SinkDepth.characterParts(MAIN_TAG)
if #characters == 0 then
	return "STOP: no MainCharacter parts found; nothing changed"
end

-- Find the four parts. Every lookup prints "found N of M".
local items: { Item } = {}
local surfaces = world.WalkSurfaces
local landing = surfaces:FindFirstChild("LapLanding")
local landingDeck = if landing ~= nil then landing:FindFirstChild("Deck") else nil
if landingDeck ~= nil and landingDeck:IsA("BasePart") then
	table.insert(items, newItem("LapLanding.Deck", landingDeck, landingDeck, 3, -1, 1.2))
end
local flowers = 0
for _, folder in world.Nature:GetChildren() do
	if folder.Name == "Inno_White_Flowers" then
		for _, name in { "White_Flower_01", "White_Flower_03" } do
			local flower = folder:FindFirstChild(name)
			if flower ~= nil and flower:IsA("BasePart") then
				local low, high = SinkDepth.boxOf(flower)
				for _, box in characters do
					if
						low.X - NEAR <= box.max.X
						and high.X + NEAR >= box.min.X
						and low.Y - NEAR <= box.max.Y
						and high.Y + NEAR >= box.min.Y
						and low.Z - NEAR <= box.max.Z
						and high.Z + NEAR >= box.min.Z
					then
						-- Only the flowers that really sink count: the others near him are fine as they are.
						local worst = measure(flower.CFrame, flower.Size, nil, nil, characters)
						if worst > 0 then
							flowers += 1
							table.insert(items, newItem(name, flower, flower, nil, nil, MOVE_MAX))
						end
						break
					end
				end
			end
		end
	end
end
local tufts = 0
for _, tuft in world.Nature:GetChildren() do
	if tuft.Name == "Nature_GrassTuft" and tuft:IsA("Model") then
		local grass = tuft:FindFirstChild("Grass")
		if grass ~= nil and grass:IsA("BasePart") then
			local flat = Vector3.new(grass.Position.X - GRASS_AT.X, 0, grass.Position.Z - GRASS_AT.Z)
			-- Like the flowers: only a tuft that still sinks counts; after the move it is clear, so a rerun finds none.
			if flat.Magnitude <= GRASS_RADIUS and measure(grass.CFrame, grass.Size, nil, nil, characters) > 0 then
				tufts += 1
				table.insert(items, newItem("GrassTuft.Grass", grass, tuft, nil, nil, MOVE_MAX))
			end
		end
	end
end
local found = `found decks {#items - flowers - tufts} of 1, flowers {flowers} of 2, grass {tufts} of 1`
-- A rerun after the move: the flowers and the tuft left his body, so only the backup tells it was done.
local backups = ServerStorage:FindFirstChild("WorldBackups")
local rerun = flowers == 0 and tufts == 0 and backups ~= nil and backups:FindFirstChild(BACKUP_NAME) ~= nil
if not rerun and (#items ~= 4 or flowers ~= 2 or tufts ~= 1) then
	return `STOP: {found}; nothing changed`
end

local lines: { string } = {}
local stops = 0
local sunk = 0
for _, item in items do
	plan(item, world, characters)
	table.insert(lines, row(item))
	if item.stop ~= nil then
		stops += 1
	end
	if item.worst > 0 then
		sunk += 1
	end
end
if stops > 0 then
	return finish(lines, `STOP: {stops} stop(s), nothing changed ({found})`)
end
if sunk == 0 then
	return finish(lines, "already done: all four parts clear, nothing changed")
end
if CHECK_ONLY then
	return finish(lines, `CHECK_ONLY: would change {sunk} of 4 ({found}), changed nothing`)
end

local toChange: { Item } = {}
for _, item in items do
	if item.worst > 0 then
		table.insert(toChange, item)
	end
end
backup(toChange)
ChangeHistoryService:SetWaypoint("33-laid-on-him: before")
for _, item in toChange do
	if item.axis ~= nil then
		local cf, size = changed(item)
		item.part.Size = size
		item.part.CFrame = cf
	elseif item.root:IsA("Model") then
		item.root:PivotTo(item.root:GetPivot() + item.move)
	else
		item.part.CFrame = item.part.CFrame + item.move
	end
end
ChangeHistoryService:SetWaypoint("33-laid-on-him: after")
local resultLines: { string } = {}
for _, item in items do
	local worst, failing, total = measure(item.part.CFrame, item.part.Size, item.axis, item.sign, characters)
	table.insert(resultLines, `{item.label} | now dense worst {fmt(worst)} ({failing}/{total}) | was {fmt(item.worst)}`)
end
return finish(resultLines, `changed {sunk} of 4, backup in ServerStorage.WorldBackups.{BACKUP_NAME}`)
