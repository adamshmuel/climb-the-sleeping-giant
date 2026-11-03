--!strict
-- World build, V2 stuck safety Task 61 (spec section 5: "Cap tie width" and "Landing at each tie's top"; Rule 101, Ladders
-- hold you; Rule 20, One collision source). Builds one cap tie: a striped strap that hangs from the widest point of the
-- giant's head, leans back onto his nightcap, and ends in a folded landing you can stand on. The route comes from
-- designer's measured table (work/ear-ladders/tie-route-table.md). The look (colours, materials, knot and stripe shapes)
-- is the look designer approved in the c3 mockup. The numbers are copied into this script, so the mockup can go away.
-- Product's ruling 2a: the invisible guard plate in the tie's way, SteepGuards.CapSide<Side>_28, is removed whole. It is
-- moved (never destroyed) to ServerStorage.WorldBackups.CapTies, which is the undo. Rojo leaves WorldBackups alone.
-- Task 61a builds Side = "Left" (minus x). Task 61b builds "Right": the left tie mirrored, with its foot raised by the right
-- pillow's rise (0.16) and its top rows fitted to the right cap (see SIDES.Right).
-- What it builds, into Workspace.World.WalkSurfaces.CapTie<Side> (a model):
--   Strap_01...  the strap, one part per row of the route table (look only: 2.7 along z, 0.6 thick);
--   Stripe_NN    red bands on the strap (look only: no collision, no query);
--   Climb_NN     the knots, one every 2 studs of height (look only, 2.7 along z);
--   PomPom       the ball at the foot, resting on the pillow (look only: no collision, no query, so it never blocks the climb start);
--   Landing      the 6 by 6 fold, lying on the cap (46 degrees, every bottom edge within 0.5 of it), with Trim_NN along its sides;
--   ShelfWedge   a hidden solid wedge between the rails that fills the shelf at the foot of WalkStrip_04 (Task 61a fix).
--   The hidden climb (Transparency 1, no shadow, anchored; Task 61a, the gate's script A numbers; Lesson 153: together
--   they are as wide as the strap, z 30.65 to 33.35). Everything the player sees is look only, and these carry him:
--   ClimbTrussUp_1, _2     TrussParts from the pillow floor (y 56.38) to y 84.38, outer face x -37.10;
--   ClimbTrussLean_1, _2   TrussParts from y 84.5 to y 100, leaning 4.6 degrees toward his head, outer face x -37.10 to -35.85;
--   WalkStrip_04, _05      solid copies of the top two strap pieces, 0.3 longer, to walk the last stretch (the strap ends under the fold);
--   Rail_04_A/B, _05_A/B   low walls each side of WalkStrip_04 and _05, inner faces z 30.65 and 33.35.
-- Check mode is the default (Lesson 166): with no attribute `Apply` set to true on the clone, it only checks and says
-- "CHECK ONLY: passed, would build CapTieLeft and move CapSideLeft_28". Attributes on the clone:
--   Apply = true   make the change;   Side = "Left" (default) or "Right";   Undo = true (with Apply) take it back.
-- Four worlds, all decided before any change:
--   1. no tie and the plate is in SteepGuards (not in the backup): build the tie and move the plate;
--   2. the tie is built with all 11 hidden climb pieces and the plate is in the backup: "already done", nothing changes;
--   3. the tie is built without them (the old build) and the plate is in the backup: check mode says "old build: run with
--      Undo, then Apply"; Apply alone stops with nothing changed;
--   4. anything else: it stops with nothing changed, and says why.
-- Run in Studio EDIT mode by requiring a clone of ServerStorage.Tools.world["20-cap-ties"] (Lesson 190).
-- Adam saves the place file at Gate 4. Run twice, it changes nothing the second time.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUPS_NAME = "WorldBackups"
local FOLDER_NAME = "CapTies"
local TIE_Z = 32 -- the tie's centre line along z
local STRAP_WIDTH = 2.7 -- along z
local STRAP_THICK = 0.6 -- along x
local STRAP_OVERLAP = 0.05 -- each segment is this much longer than its row, so two segments never leave a gap
local KNOT_FIRST_Y, KNOT_LAST_Y, KNOT_GAP = 61, 109, 2
local KNOT_THICK, KNOT_HEIGHT = 0.8, 0.5 -- the knot stands 0.1 proud of the strap on each face
local STRIPE_FIRST_Y, STRIPE_GAP, STRIPE_LENGTH = 61, 4, 2.05
local MIN_PIECE = 0.1 -- a band piece shorter than this is dropped
local POMPOM_SIZE = 3.2
local WALK_FROM_Y, RAILS_TO_Y, WALK_EXTRA = 100, 110, 0.3 -- the walk strip covers the rows from y 100; rails to y 110
local RAIL_SIZE_X, RAIL_SIZE_Z, RAIL_SHIFT_X, RAIL_SHIFT_Z = 2.1, 0.5, 0.75, 1.6
local TRUSS_Z_OFFSET = 0.35 -- each truss pair stands this far each side of the tie's centre line
local UP_LENGTH, LEAN_LENGTH = 28, 16
local LANDING_SIZE = 6
local LANDING_THICK = 0.6
local LANDING_TILT = math.rad(46) -- the cap rises about 47 degrees under the fold; measured fit, 2026-11-02
-- |x| and y, at z 32, of the fold's BOTTOM face's outer (low) edge: 0.22 above the cap, every bottom edge within 0.47 of it
-- (measured on the left side with rays; the right side is measured in Task 61b).
local LANDING_OUTER = Vector2.new(30.0, 108.85)
-- The shelf wedge's low outer corner (the leaning truss top's outer edge) and its high end (on the strip face): |x| and y.
local WEDGE_OUTER = Vector2.new(35.84, 100.2)
local WEDGE_INNER = Vector2.new(35.0, 101.45)
local TRIM_THICK, TRIM_LENGTH = 0.62, 6

local CREAM = Color3.fromHex("f4eee6")
local RED = Color3.fromHex("c8283c")

type Rows = { { number } } -- { height y, strap centre |x| }
type Climb = { upX: number, upY: number, leanX: number, leanY: number, leanRise: number, leanRun: number }
type SideInfo = { sign: number, route: Rows, pomPomY: number, landingRise: number, climb: Climb? }

-- The hidden climb pieces every built tie must have (left side).
local HIDDEN_NAMES = {
	"ClimbTrussUp_1",
	"ClimbTrussUp_2",
	"ClimbTrussLean_1",
	"ClimbTrussLean_2",
	"WalkStrip_04",
	"WalkStrip_05",
	"ShelfWedge",
	"Rail_04_A",
	"Rail_04_B",
	"Rail_05_A",
	"Rail_05_B",
}

-- The route table, per side. Left is minus x.
local SIDES: { [string]: SideInfo } = {
	Left = {
		sign = -1,
		pomPomY = 58.4,
		landingRise = 0,
		climb = { upX = 36.1, upY = 70.38, leanX = 35.478, leanY = 92.202, leanRise = 15.5, leanRun = 1.247 },
		route = { { 60, 36.7 }, { 90, 36.7 }, { 95, 36.3 }, { 100, 35.3 }, { 105, 33.2 }, { 110, 29.9 } },
	},
	-- The right cap reaches farther out than the left's mirror (measured 2026-11-03: +0.31 at y 95 and 100, +0.34 at y 102,
	-- +0.24 at y 105, 0.00 at y 110; the fold sits 0.09 higher), so these rows and the lean top differ from the left's.
	Right = {
		sign = 1,
		landingRise = 0.09,
		pomPomY = 58.56, -- 58.4 + r, r = 0.16: the right pillow is 0.16 higher than the left (Task 61b, Step 1)
		climb = { upX = 36.1, upY = 70.54, leanX = 35.628, leanY = 92.202, leanRise = 15.5, leanRun = 0.947 },
		route = { { 60, 36.7 }, { 90, 36.7 }, { 95, 36.6 }, { 100, 35.6 }, { 105, 33.45 }, { 110, 29.9 } },
	},
}

-- true: run every lookup and guard, then stop before any change (Lesson 166). The default. A clone with the attribute
-- `Apply` set to true switches it off for that run.
local CHECK_ONLY = true

local function stopped(reason: string): never
	error(`STOPPED, nothing changed: {reason}`, 0)
end

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Fabric
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape ~= nil then
		part.Shape = shape
	end
	return part
end

local function lookOnly(part: Part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- A hidden climbing piece: invisible, no shadow, anchored, solid.
local function hide(part: Part): Part
	part.Transparency = 1
	part.CastShadow = false
	part.Anchored = true
	return part
end

-- The strap centre |x| at height y, along the route's straight rows.
local function lineX(route: Rows, y: number): number
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		if y >= a[1] and y <= b[1] then
			return a[2] + (b[2] - a[2]) * (y - a[1]) / (b[1] - a[1])
		end
	end
	return route[#route][2]
end

-- A part that lies along the strap from row to row: its length (Y) runs from (x1, y1) to (x2, y2) in the x-y plane.
local function alongStrap(sign: number, x1: number, y1: number, x2: number, y2: number): (CFrame, number)
	local dx, dy = sign * (x2 - x1), y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local middle = Vector3.new(sign * (x1 + x2) / 2, (y1 + y2) / 2, TIE_Z)
	return CFrame.new(middle) * CFrame.Angles(0, 0, math.atan2(-dx, dy)), length
end

local function newTruss(name: string, length: number, cframe: CFrame): TrussPart
	local truss = Instance.new("TrussPart")
	truss.Name = name
	truss.Size = Vector3.new(2, length, 2)
	truss.CFrame = cframe
	truss.Anchored = true
	truss.Transparency = 1
	truss.CastShadow = false
	return truss
end

local function build(tie: Model, info: SideInfo, climb: Climb)
	local sign, route = info.sign, info.route
	-- The hidden climb: two pairs of trusses side by side across the strap's width, upright to y 84.38, then leaning.
	local leanAngle = sign * math.atan2(climb.leanRun, climb.leanRise) -- toward his head (x 0)
	for number, side in { -1, 1 } do
		local z = TIE_Z + side * TRUSS_Z_OFFSET
		newTruss(`ClimbTrussUp_{number}`, UP_LENGTH, CFrame.new(sign * climb.upX, climb.upY, z)).Parent = tie
		local lean = CFrame.new(sign * climb.leanX, climb.leanY, z) * CFrame.Angles(0, 0, leanAngle)
		newTruss(`ClimbTrussLean_{number}`, LEAN_LENGTH, lean).Parent = tie
	end
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local cframe, length = alongStrap(sign, a[2], a[1], b[2], b[1])
		local strap = newPart(
			string.format("Strap_%02d", index),
			Vector3.new(STRAP_THICK, length + STRAP_OVERLAP, STRAP_WIDTH),
			cframe,
			CREAM
		)
		lookOnly(strap)
		strap.Parent = tie
		if a[1] >= WALK_FROM_Y then
			local strip = hide(
				newPart(
					string.format("WalkStrip_%02d", index),
					Vector3.new(STRAP_THICK, length + STRAP_OVERLAP + WALK_EXTRA, STRAP_WIDTH),
					cframe,
					CREAM
				)
			)
			strip.Parent = tie
			if b[1] <= RAILS_TO_Y then
				for letter, side in { A = -1, B = 1 } :: { [string]: number } do
					local rail = hide(
						newPart(
							string.format("Rail_%02d_%s", index, letter),
							Vector3.new(RAIL_SIZE_X, strip.Size.Y, RAIL_SIZE_Z),
							cframe * CFrame.new(sign * RAIL_SHIFT_X, 0, side * RAIL_SHIFT_Z),
							CREAM
						)
					)
					rail.Parent = tie
				end
			end
		end
	end

	-- The shelf wedge: solid, between the rails (z 30.65 to 33.35). A WedgePart is full height on its local +Z side, so local
	-- +Z points toward his head. Its top runs from the truss top's outer edge up to the strip face with no step.
	local wedge = Instance.new("WedgePart")
	wedge.Name = "ShelfWedge"
	wedge.Size = Vector3.new(STRAP_WIDTH, WEDGE_INNER.Y - WEDGE_OUTER.Y, WEDGE_OUTER.X - WEDGE_INNER.X)
	local wedgeCentre =
		Vector3.new(sign * (WEDGE_OUTER.X + WEDGE_INNER.X) / 2, (WEDGE_OUTER.Y + WEDGE_INNER.Y) / 2, TIE_Z)
	wedge.CFrame = CFrame.fromMatrix(wedgeCentre, Vector3.new(0, 0, sign), Vector3.yAxis, Vector3.new(-sign, 0, 0))
	wedge.Anchored = true
	wedge.Transparency = 1
	wedge.CastShadow = false
	wedge.Parent = tie

	-- Red bands, every STRIPE_GAP studs of height. Each band is clipped to the strap's ends and split at every row corner,
	-- one piece per row, so it follows the strap round each bend. Pieces shorter than MIN_PIECE are dropped (a sliver).
	local stripeIndex = 0
	local y = STRIPE_FIRST_Y
	while y <= KNOT_LAST_Y + 1 do
		local bandLow = math.max(y - STRIPE_LENGTH / 2, route[1][1])
		local bandHigh = math.min(y + STRIPE_LENGTH / 2, route[#route][1])
		for index = 1, #route - 1 do
			local low = math.max(bandLow, route[index][1])
			local high = math.min(bandHigh, route[index + 1][1])
			if high - low >= MIN_PIECE then
				local cframe, length = alongStrap(sign, lineX(route, low), low, lineX(route, high), high)
				stripeIndex += 1
				local stripe = newPart(
					string.format("Stripe_%02d", stripeIndex),
					Vector3.new(STRAP_THICK + 0.02, length, STRAP_WIDTH),
					cframe,
					RED
				)
				lookOnly(stripe)
				stripe.Parent = tie
			end
		end
		y += STRIPE_GAP
	end

	local knotIndex = 0
	y = KNOT_FIRST_Y
	while y <= KNOT_LAST_Y do
		knotIndex += 1
		local knot = newPart(
			string.format("Climb_%02d", knotIndex),
			Vector3.new(KNOT_THICK, KNOT_HEIGHT, STRAP_WIDTH),
			CFrame.new(sign * lineX(route, y), y, TIE_Z),
			CREAM
		)
		lookOnly(knot)
		knot.Parent = tie
		y += KNOT_GAP
	end

	local pomPom = newPart(
		"PomPom",
		Vector3.new(POMPOM_SIZE, POMPOM_SIZE, POMPOM_SIZE),
		CFrame.new(sign * route[1][2], info.pomPomY, TIE_Z),
		CREAM,
		Enum.PartType.Ball
	)
	lookOnly(pomPom)
	pomPom.Parent = tie

	-- The fold lies on the cap. LANDING_OUTER is its bottom face's outer (low) edge. It rises toward his head (toward x 0).
	local rotation = CFrame.Angles(0, 0, if sign < 0 then LANDING_TILT else -LANDING_TILT)
	local towardHead = rotation.RightVector * -sign
	local bottomOuter = Vector3.new(sign * LANDING_OUTER.X, LANDING_OUTER.Y + info.landingRise, TIE_Z)
	local bottomCentre = bottomOuter + towardHead * (LANDING_SIZE / 2)
	local centre = bottomCentre + rotation.UpVector * (LANDING_THICK / 2)
	local landingCFrame = CFrame.new(centre) * rotation
	local landing = newPart("Landing", Vector3.new(LANDING_SIZE, LANDING_THICK, LANDING_SIZE), landingCFrame, RED)
	landing.Parent = tie
	for index, side in { -1, 1 } do
		local trim = newPart(
			string.format("Trim_%02d", index),
			Vector3.new(TRIM_LENGTH, TRIM_THICK, 0.6),
			landingCFrame * CFrame.new(0, 0, side * (LANDING_SIZE / 2 - 0.3)),
			CREAM
		)
		lookOnly(trim)
		trim.Parent = tie
	end
end

local function run(): string
	if RunService:IsRunning() then
		stopped("Play is on, this job runs in Edit")
	end
	local apply = script:GetAttribute("Apply") == true or not CHECK_ONLY
	local undo = script:GetAttribute("Undo") == true
	local sideName = script:GetAttribute("Side")
	if sideName == nil then
		sideName = "Left"
	end
	local info = SIDES[sideName :: string]
	if info == nil then
		stopped(`Side must be "Left" or "Right", not {tostring(sideName)}`)
	end
	local climb = info.climb
	if climb == nil then
		stopped(`the {sideName} side's climb is measured in Task 61b`)
	end
	local tieName = `CapTie{sideName}`
	local plateName = `CapSide{sideName}_28`
	local backupPath = `ServerStorage.{BACKUPS_NAME}.{FOLDER_NAME}`

	local world = Workspace:FindFirstChild("World")
	local walkSurfaces = if world then world:FindFirstChild("WalkSurfaces") else nil
	if walkSurfaces == nil then
		stopped("Workspace.World.WalkSurfaces is missing (lost input)")
	end
	local guards = (walkSurfaces :: Instance):FindFirstChild("SteepGuards")
	if guards == nil then
		stopped("Workspace.World.WalkSurfaces.SteepGuards is missing (lost input)")
	end
	local backups = ServerStorage:FindFirstChild(BACKUPS_NAME)
	local backup = if backups then backups:FindFirstChild(FOLDER_NAME) else nil

	local tie = (walkSurfaces :: Instance):FindFirstChild(tieName)
	local plateHere = (guards :: Instance):FindFirstChild(plateName)
	local plateThere = if backup then backup:FindFirstChild(plateName) else nil
	if plateHere ~= nil and plateThere ~= nil then
		stopped(`{plateName} is in SteepGuards and in {backupPath}`)
	end
	if plateHere ~= nil and not plateHere:IsA("BasePart") then
		stopped(`{plateName} is a {plateHere.ClassName}, not a part`)
	end

	local built = tie ~= nil and plateThere ~= nil and plateHere == nil
	local complete = built
	if built then
		for _, name in HIDDEN_NAMES do
			if (tie :: Instance):FindFirstChild(name) == nil then
				complete = false
			end
		end
	end
	local fresh = tie == nil and plateHere ~= nil and plateThere == nil
	if not built and not fresh then
		stopped(
			`{tieName} is {if tie then "built" else "missing"}, {plateName} is {if plateHere
				then "in SteepGuards"
				else "not in SteepGuards"} and {if plateThere then "in" else "not in"} {backupPath}`
		)
	end

	if undo then
		if not built then
			stopped(`nothing to undo: {tieName} is not built with {plateName} in {backupPath}`)
		end
		if not apply then
			return `CHECK ONLY: passed, would destroy {tieName} and move {plateName} back to SteepGuards`
		end
		local recording = ChangeHistoryService:TryBeginRecording("Undo cap tie")
		local tieToRemove = tie :: Instance
		local plateToReturn = plateThere :: Instance
		tieToRemove:Destroy()
		plateToReturn.Parent = guards
		if recording ~= nil then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		return `undone: destroyed {tieName} and moved {plateName} back to SteepGuards`
	end

	if built and not complete then
		if apply then
			stopped(`{tieName} is an old build: run with Undo, then Apply`)
		end
		return `CHECK ONLY: passed, {tieName} is an old build: run with Undo, then Apply`
	end
	if built then
		return `already done: {tieName} is built with its hidden climb and {plateName} is in {backupPath}`
	end
	if not apply then
		return `CHECK ONLY: passed, would build {tieName} and move {plateName}`
	end

	-- Build the model first, still detached, so a build error leaves no folders and no open recording.
	local model = Instance.new("Model")
	model.Name = tieName
	build(model, info, climb :: Climb)
	local recording = ChangeHistoryService:TryBeginRecording("Build cap tie")
	local parent: Instance? = backups
	if parent == nil then
		local made = Instance.new("Folder")
		made.Name = BACKUPS_NAME
		made.Parent = ServerStorage
		parent = made
	end
	local folder: Instance? = backup
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = parent
		folder = made
	end
	model.Parent = walkSurfaces
	local plateToMove = plateHere :: Instance
	plateToMove.Parent = folder
	if recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return `built {tieName} ({#model:GetChildren()} parts) and moved {plateName} to {backupPath}`
end

local ok, message = pcall(run)
if not ok then
	return tostring(message)
end
return message
