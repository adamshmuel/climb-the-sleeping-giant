--!strict
-- What the closer-fit sections share: the body's meshes and snapshot, the closer-fit records and the rays that read a piece's surface, and the snapshots of the slot blocks and head parts.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local S2bHeadParts = require(script.Parent.S2bHeadParts)
local S2bHeadChecks = require(script.Parent.S2bHeadChecks)

local BODY_PIECE = Shared.BODY_PIECE
type Record = Shared.Record
local RAY_MARGIN = Shared.RAY_MARGIN
local AGREE_WITHIN = Shared.AGREE_WITHIN
local MOVED_AT_LEAST = Shared.MOVED_AT_LEAST
local READ_EVERY = Shared.READ_EVERY
local MAX_WAIT = Shared.MAX_WAIT
type FixedRay = Shared.FixedRay
local readRays = Shared.readRays
local largestDifference = Shared.largestDifference
type Piece = Shared.Piece
local describePlace = Shared.describePlace
local sameAs = Shared.sameAs
type HeadPart = S2bHeadParts.HeadPart
local FINAL_HEAD_PARTS_2H = S2bHeadChecks.FINAL_HEAD_PARTS_2H
local FINAL_HEAD_PARTS_2I = S2bHeadChecks.FINAL_HEAD_PARTS_2I
local FINAL_HEAD_PARTS_2J = S2bHeadChecks.FINAL_HEAD_PARTS_2J
local headProblems = S2bHeadChecks.headProblems

local FitShared = {}

-- Why: Roblox's usual shape for his belly and chair piece (PreciseConvexDecomposition) bridges dips, so over much of his
-- belly a player stands 1 to 4.4 studs above the cloth they see. The shape called Tunable follows the mesh closer there
-- (measured in step 6b-1f: belly spots more than 0.2 above his skin go from 171 to 46). It is one mesh, so the chair side
-- gets worse (175 to 297); those spots are dealt with in later steps. His other five pieces stay PreciseConvexDecomposition,
-- because Tunable makes each of them worse. Rule 20 (One collision source), check 6 (His body stands where he's drawn).
-- Only a script can do it this way: AssetService:CreateMeshPartAsync makes a MeshPart with CollisionFidelity Tunable from
-- the piece's own mesh, and MeshPart:ApplyMesh copies its mesh, texture, fidelities, size and collision shape onto the
-- piece. In the Roblox docs, ApplyMesh overwrites MeshContent, TextureContent, RenderFidelity, CollisionFidelity,
-- FluidFidelity and MeshSize. Measured in step 6b-1f: it wipes TextureID, so it is put back at once.
-- The second change is the beard ladder's climbing truss `Climb`: 2.0 studs longer at its bottom end only, on the same
-- line (BEARD_TRUSS_EXTRA above; designer said yes, on condition the climb starts on the visible ladder).
-- It knows two worlds, and changes nothing on any difference:
--   (a) the world after 2e: body_and_cushion is PreciseConvexDecomposition, the truss is 28 long. The change is made.
--   (b) the world after 2f: body_and_cushion is Tunable and the truss is 30 long. It says "already done".
--   (c) anything else (including only one of the two changes): it stops with nothing changed and names what differs.
-- Before it touches the world it tries ApplyMesh on a clone away from the Workspace: every property of the clone must
-- match the piece except CollisionFidelity and CollisionPrecision (which follows the fidelity and must come out near
-- 0.36, the number measured in step 6b-1f), or nothing is changed. The change itself runs between two
-- ChangeHistoryService waypoints, and is checked again afterwards the same way. Then it waits until Roblox has worked
-- out the new shape (the same fixed rays as section 1, and the piece's rays must have moved).
local BODY_MESH_ID = "rbxassetid://126943333253304" -- as read in Studio Edit mode on 2026-10-20

local BODY_TEXTURE_ID = "rbxassetid://78855063453992"

local BODY_TUNABLE_PRECISION = 0.36 -- CollisionPrecision of the Tunable body in step 6b-1f

local BODY_PRECISION_SLACK = 0.02

local BODY_MAY_DIFFER: { [string]: boolean } = { CollisionFidelity = true, CollisionPrecision = true }

local BODY_COMPARED: { string } = {
	"Name",
	"Archivable",
	"Size",
	"CFrame",
	"Material",
	"MaterialVariant",
	"Color",
	"Transparency",
	"Reflectance",
	"CastShadow",
	"Anchored",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"CollisionGroup",
	"Massless",
	"Locked",
	"CustomPhysicalProperties",
	"MeshId",
	"MeshSize",
	"TextureID",
	"RenderFidelity",
	"FluidFidelity",
	"DoubleSided",
	"CollisionFidelity",
	"CollisionPrecision",
	"ChildCount",
	"AttributeCount",
}

-- Every property above that the piece can be asked for, plus how many children and attributes it has.
local function bodySnapshot(mesh: MeshPart): { [string]: any }
	local values: { [string]: any } = {}
	for _, name in BODY_COMPARED do
		local readable, value = pcall(function(): any
			return (mesh :: any)[name]
		end)
		if readable then
			values[name] = value
		end
	end
	values.ChildCount = #mesh:GetChildren()
	local attributes = 0
	for _ in mesh:GetAttributes() do
		attributes += 1
	end
	values.AttributeCount = attributes
	return values
end

-- The names of the compared values that differ between two snapshots, in the order of BODY_COMPARED.
local function bodyDifferences(first: { [string]: any }, second: { [string]: any }): { string }
	local names: { string } = {}
	for _, name in BODY_COMPARED do
		if first[name] ~= second[name] then
			table.insert(names, name)
		end
	end
	return names
end

local function unexpectedDifferences(names: { string }): { string }
	local unexpected: { string } = {}
	for _, name in names do
		if not BODY_MAY_DIFFER[name] then
			table.insert(unexpected, name)
		end
	end
	return unexpected
end

local function countValues(values: { [string]: any }): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

-- The two ends of a truss along its long side (its local z): the higher one first.
local function trussEnds(size: Vector3, cframe: CFrame): (Vector3, Vector3)
	local along = cframe.LookVector * (size.Z / 2)
	local first, second = cframe.Position + along, cframe.Position - along
	if first.Y >= second.Y then
		return first, second
	end
	return second, first
end

-- Why: with the belly and chair on the Tunable shape (section 2f) his solid shape still sits above his drawn skin in
-- places (check 6). code_lead measured on 2026-10-21 that CollisionPrecision 1, "closest to the visual mesh" (Roblox docs,
-- TriangleMeshPart), brings it within the limits on the belly and chair piece, the head and the nightcap. Only a script
-- can set it for the same reason as in 2f: ApplyMesh takes the shape and the precision of the MeshPart it is given.
-- It knows three worlds, and changes nothing on any difference:
--   (a) the world after 2f: body_and_cushion is Tunable at 0.36 (+-0.02), head_with_beard and nightcap are
--       PreciseConvexDecomposition, legs_and_boots and both arms are PreciseConvexDecomposition, and the 43 head parts
--       (with the 30 long beard truss) are as recorded. The change is made.
--   (b) the world after 2f2: all three are Tunable at 1.0 (+-0.01). It says "already done".
--   (c) anything else (including only one or two of the three done): it stops with nothing changed and names what differs.
-- For each of the three pieces, away from the Workspace (in a WorldModel in ServerStorage that is destroyed at the end,
-- also when something fails):
--   1. AssetService:CreateMeshPartAsync(Content.fromUri(MeshId), { CollisionFidelity = Tunable, the piece's Render- and
--      FluidFidelity }), placed where the piece is, at its size.
--   2. Its rays at the named points (below) are read until steady, then CollisionPrecision is set to 1, then it waits until
--      those rays move and are steady again (up to MAX_WAIT seconds, then it stops with nothing changed).
--   3. Dry run: ApplyMesh from it onto a clone of the piece, TextureID put back. The same 28 values as in 2f are compared
--      (everything but CollisionFidelity and CollisionPrecision must be equal) and the clone must be Tunable at 1.0.
-- Only when all three dry runs are right: between two ChangeHistoryService waypoints, ApplyMesh onto the three live pieces
-- and TextureID put back, then the same check on the live pieces, then it waits until Roblox has worked out the new shapes
-- (the fixed rays of section 1 plus the named points; each changed piece's rays must have moved).
-- Named points (x, z; a ray straight down from 1 stud over the piece's recorded top; code_lead's measure of 2026-10-21 and
-- the builder's of the same day, read with the piece alone in the ray):
--   body_and_cushion: (-40, 23) and (0, -24.5), where the chair and the belly drop 0.5 to 2.5 studs.
--   head_with_beard: (-26.8, 9.3): 92.25 on the Tunable 0.36 copy, 83.82 at precision 1, 84.83 on today's live piece.
--   nightcap: (0, 4.9): 115.25 on the Tunable 0.36 copy, 114.14 at precision 1, 114.65 on today's live piece.
local CLOSER_PRECISION = 1.0

local CLOSER_PRECISION_SLACK = 0.01

export type CloserFit = { name: string, meshId: string, textureId: string, points: { Vector2 } }

-- MeshId and TextureID as read in Studio Edit mode on 2026-10-21.
local CLOSER_FITS: { CloserFit } = {
	{
		name = BODY_PIECE,
		meshId = BODY_MESH_ID,
		textureId = BODY_TEXTURE_ID,
		points = { Vector2.new(-40, 23), Vector2.new(0, -24.5) },
	},
	{
		name = "head_with_beard",
		meshId = "rbxassetid://90514370492860",
		textureId = "rbxassetid://122798551915443",
		points = { Vector2.new(-26.8, 9.3) },
	},
	{
		name = "nightcap",
		meshId = "rbxassetid://114717524056185",
		textureId = "rbxassetid://115242442243733",
		points = { Vector2.new(0, 4.9) },
	},
}

-- The legs are PreciseConvexDecomposition until section 2f5 (Ruling 9, step 26-4f) makes them Tunable at 1.0: every
-- section after 2f2 accepts both (see stayingPieceProblem). The arms are PreciseConvexDecomposition for good.
local LEGS_PIECE = "legs_and_boots"

local SHAPE_PIECES_STAYING = { LEGS_PIECE, "left_arm", "right_arm" }

-- One ray straight down at each named point, from RAY_MARGIN over the piece's recorded top.
local function pointRays(record: Record, points: { Vector2 }): { FixedRay }
	local rays: { FixedRay } = {}
	for _, point in points do
		table.insert(rays, {
			origin = Vector3.new(point.X, record.position.Y + record.size.Y / 2 + RAY_MARGIN, point.Y),
			direction = Vector3.new(0, -(record.size.Y + 2 * RAY_MARGIN), 0),
		})
	end
	return rays
end

-- The height a ray's hit is at (its origin's height minus the distance read), or nil for a miss.
local function hitHeight(ray: FixedRay, distance: number): number?
	if distance < 0 then
		return nil
	end
	return ray.origin.Y - distance
end

local function pointsText(points: { Vector2 }): string
	local texts: { string } = {}
	for _, point in points do
		table.insert(texts, `({point.X}, {point.Y})`)
	end
	return table.concat(texts, " and ")
end

local function heightText(height: number?): string
	return if height == nil then "no hit" else string.format("%.2f", height)
end

-- Reads the staging copy's rays every READ_EVERY seconds until two reads in a row agree (and, when `baseline` is given,
-- until some ray has also moved more than MOVED_AT_LEAST away from it). Returns whether that happened, the seconds it
-- took, the largest move from the baseline, and the last read.
local function waitForSourceShape(
	world: WorldRoot,
	source: MeshPart,
	rays: { FixedRay },
	baseline: { number }?
): (boolean, number, number, { number })
	local started = os.clock()
	local previous = readRays(source, rays, world)
	local moved = 0
	while os.clock() - started < MAX_WAIT do
		task.wait(READ_EVERY)
		local current = readRays(source, rays, world)
		local agrees = largestDifference(previous, current) <= AGREE_WITHIN
		moved = if baseline == nil then 0 else largestDifference(baseline, current)
		previous = current
		if agrees and (baseline == nil or moved > MOVED_AT_LEAST) then
			return true, os.clock() - started, moved, current
		end
	end
	return false, os.clock() - started, moved, previous
end

local function isTunableAt(mesh: MeshPart, precision: number, slack: number): boolean
	return mesh.CollisionFidelity == Enum.CollisionFidelity.Tunable
		and math.abs(mesh.CollisionPrecision - precision) <= slack
end

-- The problem with one of the pieces in SHAPE_PIECES_STAYING, or nil when it is fine: PreciseConvexDecomposition, or for
-- the legs also Tunable at 1.0 (the world after section 2f5).
local function stayingPieceProblem(name: string, mesh: MeshPart): string?
	if mesh.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition then
		return nil
	end
	if name == LEGS_PIECE and isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
		return nil
	end
	return `{name}: CollisionFidelity is {mesh.CollisionFidelity.Name} at CollisionPrecision {string.format(
		"%.3f",
		mesh.CollisionPrecision
	)}, expected PreciseConvexDecomposition{if name == LEGS_PIECE then " or Tunable at 1.0 (after section 2f5)" else ""}`
end

local SLOT_EDGE_STEP_X = 0.1

local SLOT_EDGE_STEP_Z = 0.25

local SLOT_MAY_DIFFER: { [string]: boolean } = { Size = true, CFrame = true }

local SLOT_COMPARED: { string } = {
	"Name",
	"Archivable",
	"Size",
	"CFrame",
	"Shape",
	"Material",
	"Color",
	"Transparency",
	"Reflectance",
	"CastShadow",
	"Anchored",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"CollisionGroup",
	"Massless",
	"Locked",
	"CustomPhysicalProperties",
	"Parent",
	"ChildCount",
	"AttributeCount",
}

local function slotBlockSnapshot(block: BasePart): { [string]: any }
	local values: { [string]: any } = {}
	for _, name in SLOT_COMPARED do
		local readable, value = pcall(function(): any
			return (block :: any)[name]
		end)
		if readable then
			values[name] = value
		end
	end
	values.ChildCount = #block:GetChildren()
	local attributes = 0
	for _ in block:GetAttributes() do
		attributes += 1
	end
	values.AttributeCount = attributes
	return values
end

-- How far the skin of head_with_beard is above the block's bottom, at the worst point of the bottom face's four edges:
-- (the depth, where). Measured straight down from the block's top face. No skin under a point counts as -infinity.
local function slotBottomDepth(head: MeshPart, wide: HeadPart): (number, string)
	local centre, size = wide.cframe.Position, wide.size
	local topY, bottomY = centre.Y + size.Y / 2, centre.Y - size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { head }
	params.RespectCanCollide = false
	local worst, worstAt = math.huge, "nowhere"
	local function measure(x: number, z: number)
		local hit = Workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -(size.Y + 20), 0), params)
		local depth = if hit == nil then -math.huge else hit.Position.Y - bottomY
		if depth < worst then
			worst, worstAt = depth, string.format("x %.2f, z %.2f", x, z)
		end
	end
	local stepsX = math.round(size.X / SLOT_EDGE_STEP_X)
	local stepsZ = math.round(size.Z / SLOT_EDGE_STEP_Z)
	for index = 0, stepsX do
		local x = centre.X - size.X / 2 + size.X * index / stepsX
		measure(x, centre.Z - size.Z / 2)
		measure(x, centre.Z + size.Z / 2)
	end
	for index = 0, stepsZ do
		local z = centre.Z - size.Z / 2 + size.Z * index / stepsZ
		measure(centre.X - size.X / 2, z)
		measure(centre.X + size.X / 2, z)
	end
	return worst, worstAt
end

-- Section 2f4: the beard truss 32 long and the cap rails' part B ends sooner (stuck safety Task 26, step 26-4d4, Ruling 8)
-- Why: after the closer fit (section 2f2) his belly under the beard ladder is 0.36 lower, so the walk check no longer
-- joined the ladder's foot to his belly (the nearest spot was 4.23 away, a climb link reaches 4.0). And part B of the rails
-- walled the cap ladder's top into a lane two grid columns wide, straight into the drawn lip at the back of the brim, so
-- no walk reached the brim's nest points. Both changes are invisible.
-- What it does:
--   - It refuses to run in Play.
--   - It checks everything first and changes nothing on any difference: the 3 closer-fit pieces are Tunable at
--     CollisionPrecision 1, legs and arms are PreciseConvexDecomposition (the legs may also be Tunable at 1.0 once section
--     2f5 has run), and the head is either section 2f3's (before:
--     truss 2 x 2 x 30, both part B SideRails 2 x 34 x 13.4 ending at z 6.0; the change is made) or the final one
--     (after: truss 2 x 2 x 32, part B 2 x 34 x 9.9 ending at z 2.5: "already done").
--   - Before the change, for each part: the truss's top end stays within 0.05 and its bottom end moves 2.0 down the same
--     line; each part B keeps its front end (z -7.4) and its back end ends between z 2.1 and 3.0.
--   - It sets Size and CFrame of the 3 parts and nothing else (it compares every other value before and after), with
--     waypoints before and after, and checks the head again.
--   - It prints before and after for each part.
local HEAD_CHANGE_COMPARED: { string } = table.clone(SLOT_COMPARED)
table.insert(HEAD_CHANGE_COMPARED, "Style") -- a truss's own look; nil on a Part

local function headPartSnapshot(part: BasePart): { [string]: any }
	local values = slotBlockSnapshot(part)
	local readable, style = pcall(function(): any
		return (part :: any).Style
	end)
	if readable then
		values.Style = style
	end
	return values
end

local function headPartDifferences(first: { [string]: any }, second: { [string]: any }): { string }
	local names: { string } = {}
	for _, name in HEAD_CHANGE_COMPARED do
		if first[name] ~= second[name] then
			table.insert(names, name)
		end
	end
	return names
end

-- The live part for a recorded head part (not one already taken), or nil.
local function liveHeadPart(walk: Instance, record: HeadPart, taken: { BasePart }): BasePart?
	local box = walk:FindFirstChild(record.parent)
	if box == nil then
		return nil
	end
	for _, child in box:GetChildren() do
		if
			child.Name == record.name
			and child:IsA("BasePart")
			and not table.find(taken, child)
			and sameAs(child, record.size, record.cframe)
		then
			return child
		end
	end
	return nil
end

-- One line about a head part: its size and place, and for a truss its foot, for a rail its front and back ends (z).
local function headPartText(size: Vector3, cframe: CFrame, isTruss: boolean): string
	local text = string.format("%.2f x %.2f x %.2f at %s", size.X, size.Y, size.Z, describePlace(cframe))
	if isTruss then
		local top, foot = trussEnds(size, cframe)
		return text .. `; top end {describePlace(CFrame.new(top))}, foot {describePlace(CFrame.new(foot))}`
	end
	return text .. string.format("; z from %.2f to %.2f", cframe.Z - size.Z / 2, cframe.Z + size.Z / 2)
end

-- MeshId and TextureID as read in Studio Edit mode on 2026-10-21.
local LEGS_FIT: CloserFit = {
	name = LEGS_PIECE,
	meshId = "rbxassetid://119193072671044",
	textureId = "rbxassetid://86759773050605",
	points = { Vector2.new(24.5, -40.5) },
}

local ARM_PIECES = { "left_arm", "right_arm" }

-- Everything section 2f5 needs to be true about the rest of his body, before and after: the belly, head and nightcap
-- Tunable at 1.0, the arms PreciseConvexDecomposition, the head parts final (section 2f4).
local function restOfHisBodyProblems(byName: { [string]: Piece }, walk: Instance): { string }
	local problems: { string } = {}
	for _, fit in CLOSER_FITS do
		local mesh = byName[fit.name].mesh
		if not isTunableAt(mesh, CLOSER_PRECISION, CLOSER_PRECISION_SLACK) then
			table.insert(
				problems,
				string.format(
					"%s is %s at CollisionPrecision %.3f, expected Tunable at 1.0 (section 2f2)",
					fit.name,
					mesh.CollisionFidelity.Name,
					mesh.CollisionPrecision
				)
			)
		end
	end
	for _, name in ARM_PIECES do
		local armProblem = stayingPieceProblem(name, byName[name].mesh)
		if armProblem ~= nil then
			table.insert(problems, armProblem)
		end
	end
	local headFindings = headProblems(walk, FINAL_HEAD_PARTS_2H)
	if #headFindings > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2I) == 0 then
		headFindings = {} -- section 2f6 has run: the same head with the truss's foot swung back
	end
	if #headFindings > 0 and #headProblems(walk, FINAL_HEAD_PARTS_2J) == 0 then
		headFindings = {} -- section 2g has run: the same head with the longer beard rails and the extra rung
	end
	for _, problem in headFindings do
		table.insert(problems, problem)
	end
	return problems
end

FitShared.BODY_MESH_ID = BODY_MESH_ID
FitShared.BODY_TEXTURE_ID = BODY_TEXTURE_ID
FitShared.BODY_TUNABLE_PRECISION = BODY_TUNABLE_PRECISION
FitShared.BODY_PRECISION_SLACK = BODY_PRECISION_SLACK
FitShared.bodySnapshot = bodySnapshot
FitShared.bodyDifferences = bodyDifferences
FitShared.unexpectedDifferences = unexpectedDifferences
FitShared.countValues = countValues
FitShared.trussEnds = trussEnds
FitShared.CLOSER_PRECISION = CLOSER_PRECISION
FitShared.CLOSER_PRECISION_SLACK = CLOSER_PRECISION_SLACK
FitShared.CLOSER_FITS = CLOSER_FITS
FitShared.LEGS_PIECE = LEGS_PIECE
FitShared.SHAPE_PIECES_STAYING = SHAPE_PIECES_STAYING
FitShared.pointRays = pointRays
FitShared.hitHeight = hitHeight
FitShared.pointsText = pointsText
FitShared.heightText = heightText
FitShared.waitForSourceShape = waitForSourceShape
FitShared.isTunableAt = isTunableAt
FitShared.stayingPieceProblem = stayingPieceProblem
FitShared.SLOT_MAY_DIFFER = SLOT_MAY_DIFFER
FitShared.SLOT_COMPARED = SLOT_COMPARED
FitShared.slotBlockSnapshot = slotBlockSnapshot
FitShared.slotBottomDepth = slotBottomDepth
FitShared.headPartSnapshot = headPartSnapshot
FitShared.headPartDifferences = headPartDifferences
FitShared.liveHeadPart = liveHeadPart
FitShared.headPartText = headPartText
FitShared.LEGS_FIT = LEGS_FIT
FitShared.restOfHisBodyProblems = restOfHisBodyProblems

return FitShared
