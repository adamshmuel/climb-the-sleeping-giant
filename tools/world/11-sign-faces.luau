--!strict
-- World prep, task 48: the garden sign reads from both sides (spec section 2, "the first 60 seconds", and Rule 5,
-- "Bring it home"; the "Garden sign" row of the style guide; review problem 4).
-- Why: the sign's two name faces (SafeGate.SignFace and SafeGate.SignFaceBack) were 7.4 x 2.2 studs and only 0.44
-- studs apart, so the back face sat inside the gate's board and the sign was blank from inside the garden. The front
-- text was also a little wider than the board.
-- What it does, for all 8 gardens (Workspace.World.Plots.Plot_1 to Plot_8): both faces become 4.4 x 1.6 studs (the
-- thickness stays 0.05) with the same middle across the board and up and down. Each face's middle is moved so it sits
-- 0.35 studs out from the board's furthest point on its own side. The board is not its own part: it is part of the
-- gate's one mesh (SafeGate.body.body_geom). So that point is found with rays: on a grid every 0.2 studs over the
-- face's rectangle, a ray is cast straight at the mesh from the face's side, and the first hit of each ray is kept.
-- The furthest of those hits is the board's furthest point. Each SurfaceGui's CanvasSize becomes the face size times
-- PixelsPerStud (220 x 80 at 50), so the words are not stretched.
-- Run in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks everything first, so a problem stops the script with nothing changed. It runs again safely: when nothing
-- differs it changes nothing and says "already done". It only changes the two faces and their canvases in each garden.
-- It never touches the mesh or anything else. The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLOT_COUNT = 8
local FACE_SIZE = Vector3.new(4.4, 1.6, 0.05)
local GAP = 0.35 -- studs from the board's furthest point on the face's side to the face's middle
local GRID_STEP = 0.2
local RAY_START = 15 -- studs out from the face before the ray travels back toward the board
local NO_CHANGE_STUDS = 0.005 -- a face closer than this to its place is already right

type Face = { plot: string, name: string, part: Part, gui: SurfaceGui, mesh: MeshPart }

-- Studs from the board's furthest point (on the face's side) to a face of this size at this place, along the way the
-- face looks. Positive means the face is out in front of the board.
local function gapToBoard(cframe: CFrame, size: Vector3, mesh: MeshPart): number
	local out = cframe.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mesh }
	local columns = math.round(size.X / GRID_STEP)
	local rows = math.round(size.Y / GRID_STEP)
	local furthest = -math.huge
	local hits = 0
	for column = 0, columns do
		for row = 0, rows do
			local across = -size.X / 2 + column * size.X / columns
			local up = -size.Y / 2 + row * size.Y / rows
			local from = cframe:PointToWorldSpace(Vector3.new(across, up, 0)) + out * RAY_START
			local hit = Workspace:Raycast(from, -out * (RAY_START * 2), params)
			if hit then
				hits += 1
				furthest = math.max(furthest, hit.Position:Dot(out))
			end
		end
	end
	if hits == 0 then
		error("no ray hit the gate's mesh")
	end
	return cframe.Position:Dot(out) - furthest
end

local function describe(part: Part): string
	local p = part.Position
	local s = part.Size
	return string.format("at (%.3f, %.3f, %.3f) size %.2f x %.2f x %.2f", p.X, p.Y, p.Z, s.X, s.Y, s.Z)
end

local function run(): string
	-- Check everything first, so a problem stops the script before anything changes.
	local world = Workspace:FindFirstChild("World")
	local plots = if world then world:FindFirstChild("Plots") else nil
	if plots == nil then
		error("Workspace.World.Plots is missing")
	end
	local faces: { Face } = {}
	for number = 1, PLOT_COUNT do
		local plotName = `Plot_{number}`
		local plot = plots:FindFirstChild(plotName)
		local gate = if plot then plot:FindFirstChild("SafeGate") else nil
		if gate == nil then
			error(`{plotName}.SafeGate is missing`)
		end
		local body = gate:FindFirstChild("body")
		local mesh = if body then body:FindFirstChild("body_geom") else nil
		if mesh == nil or not mesh:IsA("MeshPart") then
			error(`{plotName}.SafeGate.body.body_geom must be a MeshPart`)
		end
		for _, name in { "SignFace", "SignFaceBack" } do
			local part = gate:FindFirstChild(name)
			if part == nil or not part:IsA("Part") then
				error(`{plotName}.SafeGate.{name} must be a Part`)
			end
			local gui = part:FindFirstChild("SurfaceGui")
			if gui == nil or not gui:IsA("SurfaceGui") then
				error(`{plotName}.SafeGate.{name}.SurfaceGui must be a SurfaceGui`)
			end
			table.insert(faces, { plot = plotName, name = name, part = part, gui = gui, mesh = mesh })
		end
	end

	-- Work out what each face needs. Nothing is changed yet.
	type Change = { face: Face, newSize: Vector3, newCFrame: CFrame, newCanvas: Vector2 }
	local changes: { Change } = {}
	for _, face in faces do
		local part = face.part
		local gap = gapToBoard(part.CFrame, FACE_SIZE, face.mesh)
		local shift = GAP - gap -- studs to move out (negative: in)
		local newCanvas = Vector2.new(FACE_SIZE.X * face.gui.PixelsPerStud, FACE_SIZE.Y * face.gui.PixelsPerStud)
		local sizeDiffers = (part.Size - FACE_SIZE).Magnitude > 0.001
		local placeDiffers = math.abs(shift) > NO_CHANGE_STUDS
		local canvasDiffers = (face.gui.CanvasSize - newCanvas).Magnitude > 0.5
		if sizeDiffers or placeDiffers or canvasDiffers then
			table.insert(changes, {
				face = face,
				newSize = FACE_SIZE,
				newCFrame = part.CFrame + part.CFrame.LookVector * shift,
				newCanvas = newCanvas,
			})
		end
	end

	if #changes == 0 then
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("11-sign-faces: before")
	end)
	local report: { string } = {}
	for _, change in changes do
		local part = change.face.part
		local before = describe(part)
		local oldCanvas = change.face.gui.CanvasSize
		part.Size = change.newSize
		part.CFrame = change.newCFrame
		change.face.gui.CanvasSize = change.newCanvas
		table.insert(
			report,
			string.format(
				"%s %s: was %s, canvas %d x %d; now %s, canvas %d x %d",
				change.face.plot,
				change.face.name,
				before,
				oldCanvas.X,
				oldCanvas.Y,
				describe(part),
				change.newCanvas.X,
				change.newCanvas.Y
			)
		)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("11-sign-faces: after")
	end)
	table.insert(report, `{#changes} faces changed`)
	return table.concat(report, "\n")
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
