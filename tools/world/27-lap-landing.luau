--!strict
-- World prep, plan 3 (gardens and ways up) Task 5: the lap planks, the lap landing, the front apron and the guards
-- (docs/plans/v2/gardens-and-ways-up.md, "Task 5"; spec Rule 36 (The lap planks) and Rule 45 (One way onto the belly)
-- conditions 1, 2 and 6). Card: work/t5/card.md.
-- Why: the mockup planks and landing are only a picture. Players need two real wooden planks from the boot tops to a
-- flat landing in front of the belly, with invisible guards so nobody walks off an open edge.
-- What it does (everything lands in Workspace.World.WalkSurfaces):
--   * LapPlank_Left / _Right: the mockup planks moved so the boot end top is at (side 21.5, 29.6, -55.56) and the
--     landing end top at (side 5.05, 33.2, -54.5); each holds Deck, Cleats, Posts, 2 Ropes and an invisible EndGuard
--     over the boot drop (z -56.5 to -51);
--   * LapLanding: the mockup landing, 11.2 x 7, top 33.2, with Guards on the back and side edges (not on the plank ends
--     and not on the belly ramp line);
--   * LapApron: the ghost apron from the moved-planks mockup, 11.2 wide, z -59.1 to -53.5, top 33.2, with a front guard;
--   * RailGuard_Left / _Right: a tall invisible wall along each plank's inner rope;
--   * Boots_Walk is trimmed so it stops at x -21.5 (it overlapped the left plank's boot end);
--   * ToeGuard_Left / _Right: an invisible wall at the top of each boot's toe slope (x +-17.5 face, 1 thick, 12 tall, from
--     z -69 over SteepGuards.BootFront_* to the plank's outer rope line, z -59.8) so a player stepping off the boot top
--     can't walk down into the gap between his legs. Runs every time, before the "already done" check, and replaces an
--     older ToeGuard after cloning it into WorldBackups.t5-toeguard (work/t5/stepC-ruling.md, idea A);
--   * CrossingGuards.Ankle_Guard_1 (an old invisible wall) is cut down so it no longer pokes up through the left
--     plank's walkway. This runs every time, before the "already done" check, and is safe to run twice.
-- Before any change it clones every part it moves or changes into ServerStorage.WorldBackups.Plan3Task5 (an existing
-- one is left alone) and sets a ChangeHistoryService waypoint. Rollback: delete the new parts in WalkSurfaces and paste
-- the clones back. Worlds, checked before any change: LapPlank_Left and _Right both there = "already done"; none there =
-- build; anything else = stop. CHECK_ONLY = true runs the checks only and changes nothing.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau (or require a copy of it).

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local MockupNests: { find: () -> Instance? } = (require :: any)(ServerStorage.Tools.checks.MockupNests:Clone())
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "Plan3Task5"
local BOOT_END = Vector3.new(21.5, 29.6, -55.56) -- top-surface end centre on the boot (x gets the side's sign)
local LAND_END = Vector3.new(5.05, 33.2, -54.5) -- top-surface end centre on the landing
local DECK_TOP = 33.2
local DECK_THICK = 0.6
local EDGE_X = 5.6
local FRONT_Z = -59.1
local BACK_Z = -46.5
local DECK_WIDTH = 11.2
local GUARD_HEIGHT = 8
local GUARD_THICK = 0.3
local END_GUARD_Z0 = -56.5
local END_GUARD_Z1 = -51
local END_GUARD_OUT = 0.4 -- the end guard stands this far past the plank end, over the drop
local RAIL_TOP_ABOVE = 12
local PLANK_ENDS_Z0 = -50 -- the side edges between this and FRONT_Z + 0.1 are the plank ends: no guard
local PLANK_EDGE_X = 4.5 -- the ropes and posts stand on the deck edges (the deck is 9 wide)
local TOE_FACE_X = 17.5 -- the toe guard's boot-top face (x gets the side's sign)
local TOE_THICK = 1
local TOE_Z0 = -69 -- over SteepGuards.BootFront_*
local TOE_Z1 = -59.8 -- the plank's outer rope line (measured at |x| 17.5: z -59.81)
local TOE_BOTTOM = 26
local TOE_HEIGHT = 12
local TOE_BACKUP = "t5-toeguard"
local SAMPLE = 0.25
local UP = Vector3.new(0, 1, 0)
local SIDES = { { label = "Left", sign = -1 }, { label = "Right", sign = 1 } }

local function clearMockup(root: Instance)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, d in all do
		for name in d:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				d:SetAttribute(name, nil)
			end
		end
	end
end

local function decor(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
end

local function solid(part: BasePart)
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
end

local function newGuard(name: string, cf: CFrame, length: number, height: number, thick: number?): WedgePart
	local g = Instance.new("WedgePart")
	g.Name = name
	g.Size = Vector3.new(length, height, thick or GUARD_THICK)
	g.CFrame = cf
	g.Anchored = true
	g.Transparency = 1
	g.CastShadow = false
	solid(g)
	return g
end

-- Cuts the old Ankle_Guard_1 wall down so its top stays under the plank walkway. Backs it up first. Safe to run twice.
local function trimAnkleGuard(surfaces: Instance): string
	local guards = surfaces:FindFirstChild("CrossingGuards")
	local guard = if guards ~= nil then guards:FindFirstChild("Ankle_Guard_1") else nil
	if guard == nil or not guard:IsA("BasePart") then
		return "Ankle_Guard_1 not found"
	end
	local top = guard.Position.Y + guard.Size.Y / 2
	if top <= 29.5 then
		return `Ankle_Guard_1 already trimmed (top {string.format("%.2f", top)})`
	end
	if CHECK_ONLY then
		return `Ankle_Guard_1 would be trimmed (top {string.format("%.2f", top)})`
	end
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
	if folder:FindFirstChild("Ankle_Guard_1") == nil then
		guard:Clone().Parent = folder
	end
	local rotation = guard.CFrame.Rotation
	local x, z = guard.Position.X, guard.Position.Z
	guard.Size = Vector3.new(guard.Size.X, 5.35, guard.Size.Z)
	guard.CFrame = CFrame.new(x, 26.825, z) * rotation
	return `Ankle_Guard_1 trimmed (top was {string.format("%.2f", top)})`
end

-- True when the guard is already what addToeGuards would build: same size and CFrame (within 0.01).
local function sameGuard(old: Instance, cf: CFrame, size: Vector3): boolean
	if not old:IsA("BasePart") then
		return false
	end
	local c0, c1 = { old.CFrame:GetComponents() }, { cf:GetComponents() }
	for i = 1, 12 do
		if math.abs(c0[i] - c1[i]) > 0.01 then
			return false
		end
	end
	return (old.Size - size).Magnitude <= 0.01
end

-- Returns the t5-toeguard backup folder, making it (and WorldBackups) only when asked.
local function toeBackupFolder(): Instance
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	local folder = backups:FindFirstChild(TOE_BACKUP)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = TOE_BACKUP
		folder.Parent = backups
	end
	return folder
end

-- Builds ToeGuard_Left and _Right. A true mirror in x: the left runs the other way along z so its steep face
-- looks the same way as the right one's, seen from its own boot top. A guard that already has the right size and
-- CFrame is left alone. An older one is backed up (once per name) before it is replaced. Safe to run twice.
local function addToeGuards(surfaces: Instance): string
	if CHECK_ONLY then
		return "toe guards: not touched (CHECK_ONLY)"
	end
	local notes = {}
	for _, side in SIDES do
		local name = "ToeGuard_" .. side.label
		local cf = CFrame.fromMatrix(
			Vector3.new(side.sign * (TOE_FACE_X - TOE_THICK / 2), TOE_BOTTOM + TOE_HEIGHT / 2, (TOE_Z0 + TOE_Z1) / 2),
			Vector3.new(0, 0, -side.sign),
			Vector3.yAxis
		)
		local size = Vector3.new(TOE_Z1 - TOE_Z0, TOE_HEIGHT, TOE_THICK)
		local old = surfaces:FindFirstChild(name)
		local state = ""
		if old ~= nil and sameGuard(old, cf, size) then
			state = " (left alone)"
		else
			if old ~= nil then
				local folder = toeBackupFolder()
				if folder:FindFirstChild(name) == nil then
					old:Clone().Parent = folder
				end
				old:Destroy()
				state = " (replaced)"
			end
			newGuard(name, cf, TOE_Z1 - TOE_Z0, TOE_HEIGHT, TOE_THICK).Parent = surfaces
		end
		table.insert(notes, `{name} x {side.sign * TOE_FACE_X} z {TOE_Z0} to {TOE_Z1}{state}`)
	end
	return "toe guards: " .. table.concat(notes, ", ")
end

local function run(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local surfaces = if world ~= nil then world:FindFirstChild("WalkSurfaces") else nil
	local mockups = Workspace:FindFirstChild("Mockup_WaysUp")
	local nests = MockupNests.find()
	local build = if nests ~= nil then nests:FindFirstChild("RampBuild_CodeLead") else nil
	local moved = if build ~= nil then build:FindFirstChild("MovedLapPlanks") else nil
	local rampFolder = if build ~= nil then build:FindFirstChild("Ramps") else nil
	if surfaces == nil then
		error("nothing was changed. Workspace.World.WalkSurfaces is missing")
	end
	local trimNote = trimAnkleGuard(surfaces) .. ". " .. addToeGuards(surfaces)
	local existing = 0
	for _, side in SIDES do
		if surfaces:FindFirstChild("LapPlank_" .. side.label) ~= nil then
			existing += 1
		end
	end
	if existing == #SIDES then
		return "already done: both lap planks are in WalkSurfaces. " .. trimNote
	elseif existing ~= 0 then
		error("nothing was changed. only one lap plank is in WalkSurfaces, expected 0 or 2")
	end
	if mockups == nil or moved == nil or rampFolder == nil then
		error("nothing was changed. Mockup_WaysUp, Mockup_Nests.RampBuild_CodeLead.MovedLapPlanks or .Ramps is missing")
	end
	for _, name in { "LapLanding", "LapApron", "RailGuard_Left", "RailGuard_Right" } do
		if surfaces:FindFirstChild(name) ~= nil then
			error(`nothing was changed. WalkSurfaces.{name} is already there but the planks are not`)
		end
	end

	-- Checks before any change: every source part is there.
	local plankSources: { [string]: Model } = {}
	for _, side in SIDES do
		local model = mockups:FindFirstChild("LapPlank_" .. side.label)
		if model == nil or not model:IsA("Model") or model:FindFirstChild("Deck") == nil then
			error(`nothing was changed. Mockup_WaysUp.LapPlank_{side.label} or its Deck is missing`)
		end
		plankSources[side.label] = model :: Model
	end
	local landingSrc = mockups:FindFirstChild("LapLanding")
	local landingDeck = if landingSrc ~= nil then landingSrc:FindFirstChild("Deck") else nil
	local apronSrc = moved:FindFirstChild("LandingApron_Front")
	local bootsWalk = surfaces:FindFirstChild("Boots_Walk")
	if
		landingSrc == nil
		or not landingSrc:IsA("Model")
		or landingDeck == nil
		or not landingDeck:IsA("BasePart")
		or apronSrc == nil
		or not apronSrc:IsA("BasePart")
		or bootsWalk == nil
		or not bootsWalk:IsA("BasePart")
	then
		error("nothing was changed. the landing, the apron source (LandingApron_Front) or Boots_Walk is missing")
	end
	local ramps: { BasePart } = {}
	for _, d in rampFolder:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(ramps, d)
		end
	end
	if #ramps == 0 then
		error("nothing was changed. the belly ramp pieces (RampBuild_CodeLead.Ramps) are missing")
	end
	if CHECK_ONLY then
		return `checks passed: 2 plank sources, landing, apron source, Boots_Walk and {#ramps} ramp pieces found; nothing changed`
	end

	-- Backup first, in the same run as the change.
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = "WorldBackups"
		backups.Parent = ServerStorage
	end
	if backups:FindFirstChild(BACKUP_NAME) == nil then
		local folder = Instance.new("Folder")
		folder.Name = BACKUP_NAME
		local sourceList: { Instance } = { plankSources.Left, plankSources.Right, landingSrc, moved, bootsWalk }
		for _, source in sourceList do
			source:Clone().Parent = folder
		end
		folder.Parent = backups
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("27-lap-landing: before")
	end)

	local function nearRamp(x: number, z: number): boolean
		-- inside a ramp piece's own footprint (its size seen from above), not "near" it
		for _, piece in ramps do
			local l = piece.CFrame:PointToObjectSpace(Vector3.new(x, piece.Position.Y, z))
			if math.abs(l.X) <= piece.Size.X / 2 and math.abs(l.Z) <= piece.Size.Z / 2 then
				return true
			end
		end
		return false
	end

	-- Guard runs along one edge. axis "x": the edge runs along x at z = fixed. axis "z": along z at x = fixed.
	local function edgeGuards(
		parent: Instance,
		axis: string,
		fixed: number,
		from: number,
		to: number,
		skip: (number) -> boolean
	)
		local runStart: number? = nil
		local last = from
		local count = 0
		local function flush()
			if runStart == nil then
				return
			end
			count += 1
			local a, b = runStart - SAMPLE / 2, last + SAMPLE / 2
			local mid = (a + b) / 2
			local y = DECK_TOP + GUARD_HEIGHT / 2
			local cf = if axis == "x"
				then CFrame.fromMatrix(Vector3.new(mid, y, fixed), Vector3.xAxis, Vector3.yAxis)
				else CFrame.fromMatrix(Vector3.new(fixed, y, mid), Vector3.zAxis, Vector3.yAxis)
			newGuard(`{axis}Guard{count}`, cf, b - a, GUARD_HEIGHT).Parent = parent
			runStart = nil
		end
		local steps = math.floor((to - from) / SAMPLE + 1e-6)
		for i = 0, steps do
			local c = from + i * SAMPLE
			if skip(c) then
				flush()
			else
				if runStart == nil then
					runStart = c
				end
				last = c
			end
		end
		flush()
	end

	-- LapLanding (the mockup model, moved) and LapApron (the ghost, made real).
	local landing = landingSrc :: Model
	local deckL = landingDeck :: BasePart
	deckL.Size = Vector3.new(DECK_WIDTH, DECK_THICK, deckL.Size.Z)
	deckL.Position = Vector3.new(0, DECK_TOP - DECK_THICK / 2, deckL.Position.Z)
	deckL.Material = Enum.Material.WoodPlanks
	deckL.Transparency = 0
	solid(deckL)
	for _, c in landing:GetChildren() do
		if c:IsA("BasePart") and c.Name == "Cleat" then
			c.Size = Vector3.new(DECK_WIDTH + 0.2, c.Size.Y, c.Size.Z)
			decor(c)
		end
	end
	clearMockup(landing)
	local landingGuards = Instance.new("Folder")
	landingGuards.Name = "Guards"
	edgeGuards(landingGuards, "x", BACK_Z, -EDGE_X, EDGE_X, function(x)
		return nearRamp(x, BACK_Z)
	end)
	for _, side in SIDES do
		local folder = Instance.new("Folder")
		edgeGuards(folder, "z", side.sign * EDGE_X, FRONT_Z, BACK_Z, function(z)
			-- the plank ends are open, but the corner (the first sample) keeps a short stub
			return (z > FRONT_Z + 0.1 and z <= PLANK_ENDS_Z0) or nearRamp(side.sign * EDGE_X, z)
		end)
		for _, g in folder:GetChildren() do
			g.Name = side.label .. g.Name
			g.Parent = landingGuards
		end
		folder:Destroy()
	end
	landingGuards.Parent = landing
	landing.Parent = surfaces

	local apronPart = apronSrc :: BasePart
	local apron = Instance.new("Model")
	apron.Name = "LapApron"
	apronPart.Name = "Deck"
	apronPart.Size = Vector3.new(DECK_WIDTH, DECK_THICK, 5.6)
	apronPart.Position = Vector3.new(0, DECK_TOP - DECK_THICK / 2, (FRONT_Z + -53.5) / 2)
	apronPart.Material = Enum.Material.WoodPlanks
	apronPart.Color = deckL.Color
	apronPart.Transparency = 0
	solid(apronPart)
	apronPart.Parent = apron
	local apronGuards = Instance.new("Folder")
	apronGuards.Name = "Guards"
	edgeGuards(apronGuards, "x", FRONT_Z, -EDGE_X, EDGE_X, function()
		return false
	end)
	apronGuards.Parent = apron
	clearMockup(apron)
	apron.Parent = surfaces

	-- The planks.
	local made: { string } = {}
	for _, side in SIDES do
		local model = plankSources[side.label]
		local oldDeck = model:FindFirstChild("Deck") :: BasePart
		local bootEnd = Vector3.new(side.sign * BOOT_END.X, BOOT_END.Y, BOOT_END.Z)
		local landEnd = Vector3.new(side.sign * LAND_END.X, LAND_END.Y, LAND_END.Z)
		local length = (landEnd - bootEnd).Magnitude
		local a = (landEnd - bootEnd).Unit
		-- keep the old deck's local Z pointing the same way along the plank
		local zSign = if oldDeck.CFrame.ZVector:Dot(Vector3.new(-side.sign, 0, 0)) >= 0 then 1 else -1
		local zAxis = a * zSign
		local xAxis = UP:Cross(zAxis).Unit
		local yAxis = zAxis:Cross(xAxis)
		local centre = (bootEnd + landEnd) / 2 - yAxis * (DECK_THICK / 2)
		local frame = CFrame.fromMatrix(centre, xAxis, yAxis, zAxis)
		local ratio = length / oldDeck.Size.Z
		local oldCf = oldDeck.CFrame -- read once: the deck is moved in the loop below

		for _, d in model:GetChildren() do
			if d:IsA("BasePart") then
				local part = d :: BasePart
				local localCf = oldCf:ToObjectSpace(part.CFrame)
				local p = localCf.Position
				local onEdge = part.Name == "Post" or part.Name == "Rope"
				local px = if onEdge then (if p.X < 0 then -PLANK_EDGE_X else PLANK_EDGE_X) else p.X
				local pos = frame * Vector3.new(px, p.Y, p.Z * ratio)
				if part == oldDeck then
					part.Size = Vector3.new(part.Size.X, DECK_THICK, length)
					part.CFrame = frame
					part.Material = Enum.Material.WoodPlanks
					part.Transparency = 0
					solid(part)
				elseif part.Name == "Post" then
					part.CFrame = CFrame.new(pos)
					decor(part)
				elseif part.Name == "Rope" then
					part.Size = Vector3.new(part.Size.X, part.Size.Y, length)
					part.CFrame = CFrame.fromMatrix(pos, xAxis, yAxis, zAxis)
					decor(part)
				else
					part.CFrame = CFrame.new(pos) * (frame.Rotation * localCf.Rotation)
					decor(part)
				end
			end
		end
		-- the cframe above uses .Rotation of a full frame; Rope keeps the deck's rotation too
		clearMockup(model)
		model.Name = "LapPlank_" .. side.label

		-- end guard: past the boot end, over the drop, z -56.5 to -51
		local r = xAxis
		if r.Z < 0 then
			r = -r
		end
		local hDir = Vector3.new(a.X, 0, a.Z).Unit
		local lineOrigin = bootEnd - hDir * END_GUARD_OUT
		local t0 = (END_GUARD_Z0 - lineOrigin.Z) / r.Z
		local t1 = (END_GUARD_Z1 - lineOrigin.Z) / r.Z
		local endPos = lineOrigin + r * ((t0 + t1) / 2)
		local endGuardHeight = GUARD_HEIGHT + DECK_THICK -- top is 8 above the boot-end deck top
		local endCf = CFrame.fromMatrix(
			Vector3.new(endPos.X, bootEnd.Y - DECK_THICK + endGuardHeight / 2, endPos.Z),
			r,
			Vector3.yAxis
		)
		newGuard("EndGuard", endCf, t1 - t0, endGuardHeight).Parent = model
		model.Parent = surfaces

		-- rail guard along the inner rope (the one with the larger z)
		local inner: BasePart? = nil
		for _, c in model:GetChildren() do
			if c.Name == "Rope" and c:IsA("BasePart") and (inner == nil or c.Position.Z > inner.Position.Z) then
				inner = c
			end
		end
		if inner == nil then
			error("a rope is missing on " .. model.Name .. " (the planks are built, stop and check)")
		end
		local ropeA = (inner.CFrame * CFrame.new(0, 0, inner.Size.Z / 2)).Position
		local ropeB = (inner.CFrame * CFrame.new(0, 0, -inner.Size.Z / 2)).Position
		local runVec = Vector3.new(ropeA.X - ropeB.X, 0, ropeA.Z - ropeB.Z)
		local railBottom = bootEnd.Y - DECK_THICK
		local railTop = landEnd.Y + RAIL_TOP_ABOVE
		local railCf = CFrame.fromMatrix(
			Vector3.new(inner.Position.X, (railBottom + railTop) / 2, inner.Position.Z),
			runVec.Unit,
			Vector3.yAxis
		)
		local rail = newGuard("RailGuard_" .. side.label, railCf, runVec.Magnitude, railTop - railBottom)
		rail.Parent = surfaces
		table.insert(made, `{model.Name} (deck {string.format("%.2f", length)} long)`)
	end

	-- Boots_Walk stops at the plank's boot end (x -21.5): same -x edge, same top.
	local walk = bootsWalk :: BasePart
	local minX = walk.Position.X - walk.Size.X / 2
	local newSizeX = -BOOT_END.X - minX
	walk.Size = Vector3.new(newSizeX, walk.Size.Y, walk.Size.Z)
	walk.Position = Vector3.new(minX + newSizeX / 2, walk.Position.Y, walk.Position.Z)

	-- The ghost planks are not needed any more (the backup holds them).
	moved:Destroy()

	pcall(function()
		ChangeHistoryService:SetWaypoint("27-lap-landing: after")
	end)
	return "built 2 lap planks, the landing, the apron and 2 rail guards: "
		.. table.concat(made, "; ")
		.. `. {trimNote}`
		.. `. Backup: ServerStorage.WorldBackups.{BACKUP_NAME}`
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
