--!strict
-- World build, V2 stuck safety Task 61w (spec Rule 101, Ladders hold you; Rule 15, The climb needs no jump; Rule 20, One
-- collision source). Builds one walkway: a railed plank path from the giant's arm to the foot of a cap tie. It ends in a
-- short chute that points straight at the tie's outer face, so a player arrives facing the side that climbs first time.
-- The shape is designer's final one (work/red-flag-61a/designer-angle.md and designer-walkway-outer-end.md). The numbers
-- are copied into this script, so those files can go away. The right side is the left mirrored in x (z stays the same),
-- and it sits 0.1 to 0.2 higher because the right pillow does (the same rise as in script 20).
-- What it builds, into Workspace.World.WalkSurfaces.Walkway<Side> (a model):
--   The carriers (Transparency 1, no shadow, anchored, solid): they are the only parts that hold the player up or in.
--     Deck_Run      the run, 6 wide, from his arm at (35, 9) to the landing at (46.1, 28); it reaches 0.3 behind the start;
--     Deck_Corner   fills the small wedge where the run's end edge meets the landing;
--     Deck_Landing  the landing, |x| 43.1 to 49.1, z 27.5 to 34.95;
--     Deck_Chute    the chute, centred on z 31.95, 4.4 wide; it ends 0.04 before the 39.1 line (so a ray at 39.1 never grazes
--                   its end face) and reaches 2 studs into the landing, so its long side is along x (the tests read that);
--     Wall_RunOuter, Wall_RunInner, Wall_LandingOuter, Wall_LandingCap, Wall_LandingInner, Wall_ChuteA, Wall_ChuteB
--                   one wall per rail, from 0.3 below the deck to 3.1 above it.
--   Everything the player sees is a soft white cloud (Task 61x, spec Rule 101 cloud-path text): look only balls (no collision,
--   no query, no touch). Cloud_Floor_<deck>_NN (4.6 to 5.6 across, tops 0.05 over the deck), Cloud_Under_<deck>_NN (a shade ball
--   under each floor ball) and Cloud_Side_<wall>_NN (two rows beside each wall, pushed outward
--   from the wall: a lower row of 2.6 to 3.0 balls and an upper row of 2.0 to 2.4 balls whose tops sit 3.1 over the deck).
-- Check mode is the default (Lesson 166): with no attribute `Apply` set to true on the clone, it only checks and says
-- "CHECK ONLY: passed, would build WalkwayLeft". Attributes on the clone:
--   Apply = true   make the change;   Side = "Left" (default) or "Right";   Undo = true (with Apply) destroys Walkway<Side>.
-- Three worlds, all decided before any change:
--   1. no walkway: build it;
--   2. the walkway is built with every carrier above: "already done", nothing changes;
--   3. the walkway is there but a carrier is missing: it stops, changes nothing and says what is missing (Undo still works).
-- Run in Studio EDIT mode by requiring a clone of ServerStorage.Tools.world["21-walkways"] (Lesson 190).
-- Adam saves the place file at Gate 4. Run twice, it changes nothing the second time.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

type SideInfo = { sign: number, runStartY: number, deckY: number }
local SIDES: { [string]: SideInfo } = {
	Left = { sign = -1, runStartY = 54.9, deckY = 56.4 },
	Right = { sign = 1, runStartY = 55.1, deckY = 56.5 },
}

local CARRIER_NAMES = {
	"Deck_Run",
	"Deck_Corner",
	"Deck_Landing",
	"Deck_Chute",
	"Wall_RunOuter",
	"Wall_RunInner",
	"Wall_LandingOuter",
	"Wall_LandingCap",
	"Wall_LandingInner",
	"Wall_ChuteA",
	"Wall_ChuteB",
}

-- All x numbers are |x|; the side's sign is put in when a part is placed.
local RUN_START_X, RUN_START_Z = 35, 9
local RUN_END_X, RUN_END_Z = 46.1, 28
local RUN_WIDTH, RUN_BACK = 6, 0.3
local LANDING_X0, LANDING_X1, LANDING_Z0, LANDING_Z1 = 43.1, 49.1, 27.5, 34.95
local CORNER_X0, CORNER_X1, CORNER_Z0, CORNER_Z1 = 46.8, 48.8, 26.5, 27.5
local CHUTE_X0, CHUTE_X1, CHUTE_DECK_X0, CHUTE_DECK_X1 = 39.1, 43.1, 39.06, 45.1
local CHUTE_Z, CHUTE_WIDTH = 31.95, 4.4
local CHUTE_RAIL_END_X = 39.6
local DECK_THICK = 0.5 + 0.1
local RAIL_THICK = 0.5
local WALL_DROP, WALL_HIGH = 0.3, 3.4
local RUN_RAIL_OFFSET = RUN_WIDTH / 2 - RAIL_THICK / 2

-- The cloud look (designer's C2 values, work/t61x/designer-step1.md, with the side height fixed by code_lead).
local CLOUD_WHITE = Color3.fromRGB(252, 252, 255)
local CLOUD_SHADE = Color3.fromRGB(214, 228, 250)
local CLOUD_SEED = 7
local FLOOR_SIZE_MIN, FLOOR_SIZE_MAX, FLOOR_LIFT = 4.6, 5.6, 0.05
local SHADE_SCALE, SHADE_DROP = 0.8, 1.1
-- Side balls (designer's Step 5b values): two rows beside each wall, pushed outward from the wall's centre plane.
local SIDE_LOWER_MIN, SIDE_LOWER_MAX, SIDE_LOWER_OUT, SIDE_LOWER_CENTRE = 2.6, 3.0, 1.2, 1.0
local SIDE_UPPER_MIN, SIDE_UPPER_MAX, SIDE_UPPER_OUT, SIDE_UPPER_TOP = 2.0, 2.4, 1.4, 3.1
local SIDE_STEP = 1.9
local CHUTE_ROW_START_X = 40.7 -- the chute walls' balls start here, so the last ball clears the cap tie's pom-pom

-- true: run every lookup and guard, then stop before any change (Lesson 166). The default. A clone with the attribute
-- `Apply` set to true switches it off for that run.
local CHECK_ONLY = true

local function stopped(reason: string): never
	error(`STOPPED, nothing changed: {reason}`, 0)
end

local function newPart(model: Model, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- A carrier: invisible, no shadow, anchored, solid.
local function carrier(model: Model, name: string, size: Vector3, cframe: CFrame)
	local part = newPart(model, name, size, cframe)
	part.Transparency = 1
	part.CastShadow = false
end

-- A part the player sees: a cloud ball, no collision, no query, no touch.
local function cloud(model: Model, name: string, diameter: number, color: Color3, cframe: CFrame)
	local part = newPart(model, name, Vector3.one * diameter, cframe)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function build(model: Model, info: SideInfo)
	local sign, deckY = info.sign, info.deckY
	local function at(x: number, y: number, z: number): Vector3
		return Vector3.new(sign * x, y, z)
	end
	-- A flat slab with its top at `top`, over |x| x0 to x1 and z z0 to z1.
	local function slab(x0: number, x1: number, z0: number, z1: number, top: number, thick: number): (Vector3, CFrame)
		return Vector3.new(x1 - x0, thick, z1 - z0), CFrame.new(sign * (x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2)
	end

	-- The run: cf0 sits on the deck's top line at the start and looks along the run (so -z of cf0 is "forward").
	local runStart = at(RUN_START_X, info.runStartY, RUN_START_Z)
	local runEnd = at(RUN_END_X, deckY, RUN_END_Z)
	local cf0 = CFrame.lookAt(runStart, runEnd)
	local runLength = (runEnd - runStart).Magnitude
	local outer = if cf0.RightVector.X * sign > 0 then 1 else -1 -- the local x direction that leads away from the middle

	-- Carriers.
	carrier(
		model,
		"Deck_Run",
		Vector3.new(RUN_WIDTH, DECK_THICK, runLength + RUN_BACK),
		cf0 * CFrame.new(0, -DECK_THICK / 2, -(runLength - RUN_BACK) / 2)
	)
	carrier(model, "Deck_Corner", slab(CORNER_X0, CORNER_X1, CORNER_Z0, CORNER_Z1, deckY, DECK_THICK))
	carrier(model, "Deck_Landing", slab(LANDING_X0, LANDING_X1, LANDING_Z0, LANDING_Z1, deckY, DECK_THICK))
	carrier(
		model,
		"Deck_Chute",
		slab(CHUTE_DECK_X0, CHUTE_DECK_X1, CHUTE_Z - CHUTE_WIDTH / 2, CHUTE_Z + CHUTE_WIDTH / 2, deckY, DECK_THICK)
	)

	-- Walls: a hidden carrier on each rail line. `flatRail` is over |x| x0..x1 and z z0..z1.
	local function flatRail(wallName: string, x0: number, x1: number, z0: number, z1: number)
		local middle = Vector3.new(sign * (x0 + x1) / 2, 0, (z0 + z1) / 2)
		local width, depth = x1 - x0, z1 - z0
		carrier(
			model,
			wallName,
			Vector3.new(width, WALL_HIGH, depth),
			CFrame.new(middle + Vector3.new(0, deckY - WALL_DROP + WALL_HIGH / 2, 0))
		)
	end
	local half = RAIL_THICK / 2
	flatRail("Wall_LandingOuter", 48.75 - half, 48.75 + half, CORNER_Z0, LANDING_Z1)
	flatRail("Wall_LandingCap", LANDING_X0, 48.75 + half, 34.6 - half, 34.6 + half)
	flatRail("Wall_LandingInner", 43.45 - half, 43.45 + half, 28.1, 29.95)
	flatRail("Wall_ChuteA", CHUTE_RAIL_END_X, CHUTE_X1, 29.95 - half, 29.95 + half)
	flatRail("Wall_ChuteB", CHUTE_RAIL_END_X, CHUTE_X1, 33.95 - half, 33.95 + half)
	local runRails: { { label: string, offset: number } } = {
		{ label = "Outer", offset = outer * RUN_RAIL_OFFSET },
		{ label = "Inner", offset = -outer * RUN_RAIL_OFFSET },
	}
	for _, rail in runRails do
		local label, offset = rail.label, rail.offset
		local line = cf0 * CFrame.new(offset, 0, -runLength / 2)
		carrier(
			model,
			`Wall_Run{label}`,
			Vector3.new(RAIL_THICK, WALL_HIGH, runLength),
			line * CFrame.new(0, WALL_HIGH / 2 - WALL_DROP, 0)
		)
	end

	-- Clouds. One Random per walkway, so the left and right come out the same.
	local random = Random.new(CLOUD_SEED)
	local floorCount: { [string]: number } = {}
	-- A floor ball, and its shade ball under it. `base` is on the deck's top face and its up is the deck's up.
	local function floorBall(deck: string, base: CFrame)
		local size = random:NextNumber(FLOOR_SIZE_MIN, FLOOR_SIZE_MAX)
		local number = (floorCount[deck] or 0) + 1
		floorCount[deck] = number
		local centre = base * CFrame.new(0, FLOOR_LIFT - size / 2, 0)
		cloud(model, string.format("Cloud_Floor_%s_%02d", deck, number), size, CLOUD_WHITE, centre)
		cloud(
			model,
			string.format("Cloud_Under_%s_%02d", deck, number),
			size * SHADE_SCALE,
			CLOUD_SHADE,
			centre * CFrame.new(0, -SHADE_DROP, 0)
		)
	end
	-- Floor balls of the run: 2 across, every 2.3 along.
	local runCount = math.ceil(runLength / 2.3)
	for i = 1, runCount do
		for _, across in { -2.0, 2.0 } do
			floorBall("Run", cf0 * CFrame.new(across, 0, -(i - 0.5) * runLength / runCount))
		end
	end
	-- The landing: 3 across (x), every 1.15 along z.
	local landingCount = math.ceil((LANDING_Z1 - LANDING_Z0) / 1.15)
	for i = 1, landingCount do
		for _, across in { -2.75, 0, 2.75 } do
			local z = LANDING_Z0 + (i - 0.5) * (LANDING_Z1 - LANDING_Z0) / landingCount
			floorBall("Landing", CFrame.new(at(46.1 + across, deckY, z)))
		end
	end
	-- The chute: 2 across (z), every 1.15 along x.
	local chuteCount = math.ceil((CHUTE_X1 - CHUTE_X0) / 1.15)
	for i = 1, chuteCount do
		for _, across in { -1.2, 1.2 } do
			local x = CHUTE_X0 + (i - 0.5) * (CHUTE_X1 - CHUTE_X0) / chuteCount
			floorBall("Chute", CFrame.new(at(x, deckY, CHUTE_Z + across)))
		end
	end
	floorBall("Corner", CFrame.new(at((CORNER_X0 + CORNER_X1) / 2, deckY, (CORNER_Z0 + CORNER_Z1) / 2)))

	-- Two rows of side balls along a wall line, pushed outward from the wall's centre plane (away from the deck's middle)
	-- so the floor strip stays clear. `length` is the wall's length; `outward` is the push direction in `baseAt`'s frame;
	-- `baseAt(distance)` is the deck's top face on the line, `distance` studs along the row.
	-- Lower row: n balls, 2.6 to 3.0 across, centre 1.0 up. Upper row: n + 1 balls, 2.0 to 2.4 across, top 3.1 up,
	-- nested between the lower ones and ending on the wall ends.
	local function sideRow(wall: string, length: number, outward: Vector3, baseAt: (number) -> CFrame)
		local count = math.max(2, math.ceil(length / SIDE_STEP))
		local step = length / count
		local number = 0
		local lowerSizes: { number } = {}
		for i = 1, count do
			lowerSizes[i] = random:NextNumber(SIDE_LOWER_MIN, SIDE_LOWER_MAX)
		end
		local upperSizes: { number } = {}
		for j = 1, count + 1 do
			upperSizes[j] = random:NextNumber(SIDE_UPPER_MIN, SIDE_UPPER_MAX)
		end
		for i = 1, count do
			number += 1
			local size = lowerSizes[i]
			local base = baseAt((i - 0.5) * step)
			cloud(
				model,
				string.format("Cloud_Side_%s_%02d", wall, number),
				size,
				CLOUD_WHITE,
				base * CFrame.new(outward * SIDE_LOWER_OUT + Vector3.new(0, SIDE_LOWER_CENTRE, 0))
			)
		end
		for j = 1, count + 1 do
			number += 1
			local size = upperSizes[j]
			local base = baseAt((j - 1) * step)
			cloud(
				model,
				string.format("Cloud_Side_%s_%02d", wall, number),
				size,
				CLOUD_WHITE,
				base * CFrame.new(outward * SIDE_UPPER_OUT + Vector3.new(0, SIDE_UPPER_TOP - size / 2, 0))
			)
		end
	end
	for _, rail in runRails do
		local line = cf0 * CFrame.new(rail.offset, 0, 0)
		sideRow(`Run{rail.label}`, runLength, Vector3.new(math.sign(rail.offset), 0, 0), function(distance)
			return line * CFrame.new(0, 0, -distance)
		end)
	end
	sideRow("LandingOuter", LANDING_Z1 - CORNER_Z0, Vector3.new(sign, 0, 0), function(distance)
		return CFrame.new(at(48.75, deckY, CORNER_Z0 + distance))
	end)
	sideRow("LandingCap", 48.75 + half - LANDING_X0, Vector3.new(0, 0, 1), function(distance)
		return CFrame.new(at(LANDING_X0 + distance, deckY, 34.6))
	end)
	sideRow("LandingInner", 29.95 - 28.1, Vector3.new(-sign, 0, 0), function(distance)
		return CFrame.new(at(43.45, deckY, 28.1 + distance))
	end)
	for _, chuteWall in { { name = "ChuteA", z = 29.95, out = -1 }, { name = "ChuteB", z = 33.95, out = 1 } } do
		local outward = Vector3.new(0, 0, chuteWall.out)
		sideRow(chuteWall.name, CHUTE_X1 - CHUTE_ROW_START_X, outward, function(distance)
			return CFrame.new(at(CHUTE_ROW_START_X + distance, deckY, chuteWall.z))
		end)
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
	local name = `Walkway{sideName}`

	local world = Workspace:FindFirstChild("World")
	local walkSurfaces = if world then world:FindFirstChild("WalkSurfaces") else nil
	if walkSurfaces == nil then
		stopped("Workspace.World.WalkSurfaces is missing (lost input)")
	end
	if (walkSurfaces :: Instance):FindFirstChild(`CapTie{sideName}`) == nil then
		stopped(`CapTie{sideName} is missing: the walkway ends at its foot (lost input)`)
	end
	local existing = (walkSurfaces :: Instance):FindFirstChild(name)
	if existing ~= nil and not existing:IsA("Model") then
		stopped(`{name} is a {existing.ClassName}, not a model`)
	end

	if undo then
		if existing == nil then
			stopped(`nothing to undo: {name} is not built`)
		end
		if not apply then
			return `CHECK ONLY: passed, would destroy {name}`
		end
		local recording = ChangeHistoryService:TryBeginRecording("Undo walkway")
		local toDestroy = existing :: Instance
		toDestroy:Destroy()
		if recording ~= nil then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		return `undone: destroyed {name}`
	end

	if existing ~= nil then
		local missing: { string } = {}
		for _, carrierName in CARRIER_NAMES do
			if existing:FindFirstChild(carrierName) == nil then
				table.insert(missing, carrierName)
			end
		end
		if #missing > 0 then
			stopped(`{name} is part built, missing {table.concat(missing, ", ")}: run with Undo, then Apply`)
		end
		return `already done: {name} is built with all {#CARRIER_NAMES} carriers`
	end
	if not apply then
		return `CHECK ONLY: passed, would build {name}`
	end

	-- Build the model first, still detached, so a build error leaves nothing behind and no open recording.
	local model = Instance.new("Model")
	model.Name = name
	build(model, info)
	local recording = ChangeHistoryService:TryBeginRecording("Build walkway")
	model.Parent = walkSurfaces
	if recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	local carriers, looks = 0, 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and (part :: BasePart).Transparency == 1 then
			carriers += 1
		else
			looks += 1
		end
	end
	return `built {name}: {carriers} hidden carriers and {looks} seen parts`
end

local ok, message = pcall(run)
if not ok then
	return tostring(message)
end
return message
