--!strict
-- World prep, plan 5 Task 15e2: the 12 invisible cuff curbs get a steep top (spec 5 section 5 "Edge curbs", "Steep face",
-- Rule 79; rulings work/p5t15e/float-decision.md and float-verdict.md; card work/p5t15e2/15e2-card.md).
-- Why: a curb's flat top (0.4 to 0.5 wide) held a body standing on it, 1.26 to 2.1 over the walk top, so it floated.
-- What it does: each of the 12 Parts in Workspace.World.CuffWalk (CurbFar, CurbSide, StrapCurbInboard, StrapCurbTop,
-- FlapCurbUphill, FlapCurbEnd; _Left and _Right) is replaced, in place, by one WedgePart of the same name, parent, size
-- (the thin side is the wedge's depth), attributes, Transparency 1 and solid settings. Its vertical face is on the outboard
-- (drop) side, so the wall line (the old top) stays; its slope falls toward the walk piece, so a body that lands on it
-- slips onto the walk, never over the drop. The slope's face is at least 75 degrees from level (atan(height / depth)).
-- Where it faces: found by rays down beside the curb onto the walk pieces (the side with the walk piece close under the
-- top is inboard). The wedge keeps the curb's own frame when that is steep enough; a leaning curb whose lean would
-- flatten the slope (FlapCurbUphill) stands upright on its old centre instead.
-- STOP (nothing changed, the name is reported): a curb missing; no walk piece beside it (or the same distance both
-- sides); no frame gives a slope of 75 or more with the wall line at or above the old top (less 0.05); a mix of wedges
-- and flat curbs. All 12 already wedges = "already done".
-- Before any change it clones the 12 curbs into ServerStorage.WorldBackups.p5t15eCurbs, in the same call.
-- Rollback: delete the 12 wedges and paste the clones back (attribute BackupOf = the old full path).
-- Note: 22-cuff-walk.luau builds the flat curbs again if it is re-run; run 23c after it.
-- CHECK_ONLY = true measures and prints only (nothing is created). Full report: shared.T15e2Report (list of lines).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["23c-curb-tops"]:Clone())` through execute_luau.

local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "p5t15eCurbs"
local KINDS = { "CurbFar", "CurbSide", "StrapCurbInboard", "StrapCurbTop", "FlapCurbUphill", "FlapCurbEnd" }
local SIDES = { "Left", "Right" }
local MIN_STEEPNESS = 75 -- degrees from level (spec 5 "Steep face")
local WALL_MARGIN = 0.05 -- studs: the new wall line may sit this far under the old top
local SIDE_OFFSETS = { 0.3, 0.6, 1.0, 1.4 } -- studs from the curb's thin face where the walk rays go down
local DROP_MIN = 0.3 -- studs: a walk hit this far or more under the old top counts as the walk beside the curb...
local DROP_MAX = 3.5 -- ...and no more than this far under it
local MAX_RAISE = 0.5 -- the most an "upright, raised" wedge grows at its top to meet the old wall line
local SAMPLES = 4 -- rays down along a curb's long axis to find its old top...
local SAMPLE_SPAN = 0.9 -- ...over this share of its length
local RAY_ABOVE = 1
local RAY_LENGTH = 8

type Plan = {
	old: BasePart,
	size: Vector3,
	cframe: CFrame,
	steepness: number,
	wallLine: number,
	oldTop: number,
	frame: string,
	inboardOffset: number,
}

local report: { string } = {}

local function note(line: string)
	table.insert(report, line)
end

local function onlyParams(parts: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	return params
end

local function horizontal(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z).Unit
end

-- The steepness of the wedge's slope face (degrees from level) and its world normal, for a frame and size.
local function slopeOf(cf: CFrame, size: Vector3): (number, Vector3)
	local normal = cf:VectorToWorldSpace(Vector3.new(0, size.Z, -size.Y).Unit)
	return math.deg(math.acos(math.clamp(normal.Y, -1, 1))), normal
end

-- The highest world y of the wedge's vertical face (its wall line).
local function wallLineOf(cf: CFrame, size: Vector3): number
	local top = -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local point = cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, size.Z / 2))
			top = math.max(top, point.Y)
		end
	end
	return top
end

-- Which of the angles puts the wedge's +Z (the vertical face) most outboard; returns the CFrame turned that way.
local function turnedOutboard(base: CFrame, angles: { number }, outboard: Vector3): CFrame
	local best = base * CFrame.Angles(0, angles[1], 0)
	local bestDot = -math.huge
	for _, angle in angles do
		local turned = base * CFrame.Angles(0, angle, 0)
		local dot = turned:VectorToWorldSpace(Vector3.new(0, 0, 1)):Dot(outboard)
		if dot > bestDot then
			bestDot = dot
			best = turned
		end
	end
	return best
end

local function getBackupFolder(): Instance
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
	return backupFolder :: Instance
end

-- One curb's plan, or a STOP line.
local function planCurb(curb: BasePart, walkParams: RaycastParams): (Plan?, string?)
	local cf = curb.CFrame
	local size = curb.Size
	local topHit = Workspace:Raycast(cf.Position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), onlyParams({ curb }))
	if topHit == nil then
		return nil, `STOP: {curb.Name} was not hit from above`
	end
	local thinIsX = size.X < size.Z
	local thin = if thinIsX then size.X else size.Z
	-- The old top: its highest point along the curb's long axis (a curb pitched along its length is higher at one end).
	local oldTop = topHit.Position.Y
	local longLength = if thinIsX then size.Z else size.X
	for step = 0, SAMPLES do
		local along = (step / SAMPLES - 0.5) * longLength * SAMPLE_SPAN
		local local3 = if thinIsX then Vector3.new(0, 0, along) else Vector3.new(along, 0, 0)
		local origin = cf:PointToWorldSpace(local3) + Vector3.new(0, 10, 0)
		local sampleHit = Workspace:Raycast(origin, Vector3.new(0, -20, 0), onlyParams({ curb }))
		if sampleHit ~= nil then
			oldTop = math.max(oldTop, sampleHit.Position.Y)
		end
	end
	local axis = horizontal(cf:VectorToWorldSpace(if thinIsX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)))

	-- Inboard: the side where a walk piece is close under the top, at the smaller distance.
	local nearest: { [number]: number } = { [1] = math.huge, [-1] = math.huge }
	for _, sign in { 1, -1 } do
		for _, offset in SIDE_OFFSETS do
			local point = cf.Position + axis * (sign * (thin / 2 + offset))
			local start = Vector3.new(point.X, oldTop + RAY_ABOVE, point.Z)
			local hit = Workspace:Raycast(start, Vector3.new(0, -RAY_LENGTH, 0), walkParams)
			local drop = if hit == nil then math.huge else oldTop - hit.Position.Y
			if drop >= DROP_MIN and drop <= DROP_MAX then
				nearest[sign] = math.min(nearest[sign], offset)
			end
		end
	end
	if nearest[1] == nearest[-1] then
		return nil, `STOP: {curb.Name} inboard side is unclear (walk beside it: +{nearest[1]} and -{nearest[-1]})`
	end
	local inboardSign = if nearest[1] < nearest[-1] then 1 else -1
	local outboard = -axis * inboardSign
	local inboardOffset = math.min(nearest[1], nearest[-1])

	local angles = if thinIsX then { math.pi / 2, -math.pi / 2 } else { 0, math.pi }
	local newSize = if thinIsX then Vector3.new(size.Z, size.Y, size.X) else size
	local _, yaw = cf:ToOrientation()
	-- In order: the curb's own frame with both end faces steep too, upright on the old centre, then the own frame with
	-- the end faces as they were (a curb pitched along its length: its two triangle ends keep the old pitch).
	local upright = CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0)
	-- "upright, raised": the upright wedge made taller at its top (bottom kept) until its wall line meets the old top.
	local frames: { { name: string, base: CFrame, endsSteep: boolean, raise: boolean } } = {
		{ name = "own frame", base = cf, endsSteep = true, raise = false },
		{ name = "upright", base = upright, endsSteep = true, raise = false },
		{ name = "upright, raised", base = upright, endsSteep = true, raise = true },
		{ name = "own frame, old ends", base = cf, endsSteep = false, raise = false },
	}
	local maxEndNormalY = math.cos(math.rad(MIN_STEEPNESS)) + 1e-4
	local lastWhy = ""
	for _, frame in frames do
		local framePos = frame.base
		local frameSize = newSize
		if frame.raise then
			local deficit = oldTop - wallLineOf(turnedOutboard(frame.base, angles, outboard), newSize)
			if deficit > 0 and deficit <= MAX_RAISE then
				frameSize = newSize + Vector3.new(0, deficit, 0)
				framePos = frame.base + Vector3.new(0, deficit / 2, 0)
			end
		end
		local turned = turnedOutboard(framePos, angles, outboard)
		local steepness, normal = slopeOf(turned, frameSize)
		local wall = wallLineOf(turned, frameSize)
		local facesInboard = normal.Y > 0 and normal:Dot(-outboard) > 0
		local endsOk = not frame.endsSteep or math.abs(turned.XVector.Y) <= maxEndNormalY
		if steepness >= MIN_STEEPNESS and wall >= oldTop - WALL_MARGIN and facesInboard and endsOk then
			return {
				old = curb,
				size = frameSize,
				cframe = turned,
				steepness = steepness,
				wallLine = wall,
				oldTop = oldTop,
				frame = frame.name,
				inboardOffset = inboardOffset,
			},
				nil
		end
		lastWhy =
			`{frame.name}: {string.format("%.1f", steepness)} deg, wall {string.format("%.2f", wall)} vs old top {string.format(
				"%.2f",
				oldTop
			)}`
	end
	return nil, `STOP: {curb.Name} has no frame with a slope of {MIN_STEEPNESS}+ and the wall line held ({lastWhy})`
end

local function finish(text: string): string
	-- selene: allow(global_usage)
	shared.T15e2Report = report
	return text
end

local function run23c(): string
	if RunService:IsRunning() then
		error("a running game can't be changed: stop Play and run this in Edit mode")
	end
	local world = Workspace:FindFirstChild("World")
	local cuffWalk = if world ~= nil then world:FindFirstChild("CuffWalk") else nil
	if cuffWalk == nil then
		return finish("STOP: Workspace.World.CuffWalk is missing (run 22-cuff-walk first), nothing changed")
	end

	local curbs: { BasePart } = {}
	local wedges = 0
	for _, kind in KINDS do
		for _, side in SIDES do
			local found = cuffWalk:FindFirstChild(`{kind}_{side}`)
			if found == nil or not found:IsA("BasePart") then
				return finish(`STOP: World.CuffWalk.{kind}_{side} is missing, nothing changed`)
			end
			if found:IsA("WedgePart") then
				wedges += 1
			end
			table.insert(curbs, found)
		end
	end
	if wedges == #curbs then
		return finish("already done")
	elseif wedges > 0 then
		return finish(`STOP: {wedges} of {#curbs} curbs are wedges already (a mix), nothing changed`)
	end

	local walkParts: { Instance } = {}
	for _, child in cuffWalk:GetChildren() do
		if child:IsA("BasePart") and not string.find(child.Name, "Curb", 1, true) then
			table.insert(walkParts, child)
		end
	end
	local walkParams = onlyParams(walkParts)

	local plans: { Plan } = {}
	local leftCount, rightCount = 0, 0
	for _, curb in curbs do
		local plan, stop = planCurb(curb, walkParams)
		if plan == nil then
			return finish(stop :: string)
		end
		table.insert(plans, plan)
		if string.sub(curb.Name, -5) == "_Left" then
			leftCount += 1
		else
			rightCount += 1
		end
		note(
			`{curb.Name} {plan.frame}, slope {string.format("%.1f", plan.steepness)} deg, wall {string.format(
				"%.2f",
				plan.wallLine
			)} (old top {string.format("%.2f", plan.oldTop)}), walk at +{plan.inboardOffset}`
		)
	end
	local summary = `{#plans} curbs ({leftCount} Left, {rightCount} Right)`
	print(`23c-curb-tops: will replace {#plans} curbs (plan: 12)`)
	if #plans ~= 12 or leftCount ~= 6 or rightCount ~= 6 then
		return finish(`STOP: {summary}, the plan is 12 (6 and 6), nothing changed`)
	end
	if CHECK_ONLY then
		return finish(
			`CHECK_ONLY: would replace {summary}, no stop fired, changed nothing | {table.concat(report, " | ")}`
		)
	end

	-- Backup in the same call.
	local backupFolder = getBackupFolder()
	local backups = 0
	for _, curb in curbs do
		if backupFolder:FindFirstChild(curb.Name) == nil then
			local copy = curb:Clone()
			copy:SetAttribute("BackupOf", curb:GetFullName())
			copy.Parent = backupFolder
		end
		if backupFolder:FindFirstChild(curb.Name) ~= nil then
			backups += 1
		end
	end
	if backups ~= #curbs then
		return finish(`STOP: only {backups} of {#curbs} backups made, nothing changed`)
	end

	ChangeHistoryService:SetWaypoint("23c-curb-tops: before")
	local verified = 0
	for _, plan in plans do
		local old = plan.old
		local wedge = Instance.new("WedgePart")
		wedge.Name = old.Name
		wedge.Anchored = old.Anchored
		wedge.CanCollide = old.CanCollide
		wedge.CanQuery = old.CanQuery
		wedge.CanTouch = old.CanTouch
		wedge.CastShadow = old.CastShadow
		wedge.Transparency = old.Transparency
		wedge.Material = old.Material
		wedge.Color = old.Color
		wedge.CollisionGroup = old.CollisionGroup
		wedge.TopSurface = Enum.SurfaceType.Smooth
		wedge.BottomSurface = Enum.SurfaceType.Smooth
		wedge.Size = plan.size
		wedge.CFrame = plan.cframe
		for attributeName, value in old:GetAttributes() do
			wedge:SetAttribute(attributeName, value)
		end
		for _, tag in CollectionService:GetTags(old) do
			CollectionService:AddTag(wedge, tag)
		end
		local parent = old.Parent
		old:Destroy()
		wedge.Parent = parent
		local hit =
			Workspace:Raycast(wedge.Position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), onlyParams({ wedge }))
		if hit ~= nil and hit.Normal.Y <= math.cos(math.rad(MIN_STEEPNESS)) + 1e-4 then
			verified += 1
		end
	end
	ChangeHistoryService:SetWaypoint("23c-curb-tops: after")
	return finish(`replaced {summary}; backups {backups}; verified {verified}/{#plans} | {table.concat(report, " | ")}`)
end

return run23c()
