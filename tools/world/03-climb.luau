--!strict
-- World prep, task 8: the climb. Right boot ramp, a smooth belly path, level ladder tops and the steep guards.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every step checks first, so a second run changes nothing and says "already done".
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
-- Nothing is deleted except the 10 steep belly pieces it replaces, and each one is written in the report first.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local report: { string } = {}
local function say(line: string)
	table.insert(report, line)
end

-- The left-right mirror of a CFrame (x becomes -x). The giant's two boots are almost mirror images.
local function mirror(cframe: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function slopeOf(part: BasePart): number
	return math.deg(math.acos(math.clamp(math.abs(part.CFrame.UpVector.Y), 0, 1)))
end

-- Height of the giant's surface straight under (x, z), or nil.
local function giantHeightAt(giant: Instance, x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { giant }
	local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else nil
end

local function groundHeightAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else nil
end

local function topCornerY(part: BasePart): number
	local half = part.Size / 2
	local highest = -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				highest = math.max(
					highest,
					part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y
				)
			end
		end
	end
	return highest
end

local function run(): any
	pcall(function()
		ChangeHistoryService:SetWaypoint("03-climb: before")
	end)

	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local walk = world:FindFirstChild("WalkSurfaces")
	local giant = world:FindFirstChild("Giant")
	local zones = world:FindFirstChild("Zones")
	if walk == nil or giant == nil or zones == nil then
		error("World.WalkSurfaces, World.Giant and World.Zones must exist (run 02-zones first)")
	end

	----------------------------------------------------------------------------------------------
	-- 1. The right boot ramp: the left ramp turned into its mirror image, then checked against the real boot
	----------------------------------------------------------------------------------------------
	local leftRamp = walk:FindFirstChild("BootRamp") :: Model
	local rightRamp = walk:FindFirstChild("RightBootRamp")
	if rightRamp == nil then
		local copy = leftRamp:Clone()
		copy.Name = "RightBootRamp"
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = mirror(part.CFrame)
			end
		end
		copy.Parent = walk
		rightRamp = copy
		local planks = copy:FindFirstChild("Ramp_Walk") :: BasePart
		local low = planks.CFrame:PointToWorldSpace(Vector3.new(0, planks.Size.Y / 2, planks.Size.Z / 2))
		local high = planks.CFrame:PointToWorldSpace(Vector3.new(0, planks.Size.Y / 2, -planks.Size.Z / 2))
		local foot, top = low, high
		if low.Y > high.Y then
			foot, top = high, low
		end
		local bootTop = giantHeightAt(giant, top.X, top.Z - 2) -- 2 studs onto the boot
		local ground = groundHeightAt(foot.X, foot.Z)
		say(
			string.format(
				"1 Right ramp: mirrored copy of BootRamp. Planks %.1f wide, slope %.1f degrees. Foot surface (%.1f, %.2f, %.1f), ground there %s. Top surface (%.1f, %.2f, %.1f), boot surface 2 studs on %s.",
				planks.Size.X,
				slopeOf(planks),
				foot.X,
				foot.Y,
				foot.Z,
				if ground then string.format("%.2f", ground) else "none",
				top.X,
				top.Y,
				top.Z,
				if bootTop then string.format("%.2f", bootTop) else "none"
			)
		)
	else
		say("1 Right ramp: already done")
	end

	----------------------------------------------------------------------------------------------
	-- 2. The right boot top path (RightBoots_Walk): the left pieces mirrored and fitted to the real right boot
	----------------------------------------------------------------------------------------------
	local step2: { string } = {}
	if walk:FindFirstChild("RightBoots_Walk") == nil then
		local biggestFix = 0
		local count = 0
		for _, piece in walk:GetChildren() do
			if piece.Name == "Boots_Walk" and piece:IsA("BasePart") then
				local copy = piece:Clone()
				copy.Name = "RightBoots_Walk"
				local moved = mirror(piece.CFrame)
				-- the right boot is not exactly the same height as the left, so keep the piece the same distance
				-- above the surface it lies on
				local leftSurface = giantHeightAt(giant, piece.Position.X, piece.Position.Z)
				local rightSurface = giantHeightAt(giant, moved.X, moved.Z)
				if leftSurface and rightSurface then
					local fix = rightSurface - leftSurface
					biggestFix = math.max(biggestFix, math.abs(fix))
					moved = moved + Vector3.new(0, fix, 0)
				end
				copy.CFrame = moved
				copy.Parent = walk
				count += 1
			end
		end
		table.insert(
			step2,
			string.format("%d pieces made, the biggest height correction %.2f studs", count, biggestFix)
		)
	end
	say("2 Right boot path: " .. (if #step2 > 0 then table.concat(step2, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- 3. Its Boots zone box, hugging the ramp like the left one
	----------------------------------------------------------------------------------------------
	local rightPlanks = (rightRamp :: Instance):FindFirstChild("Ramp_Walk") :: BasePart
	if zones:FindFirstChild("Boots_RightRamp") == nil then
		local box = Instance.new("Part")
		box.Name = "Boots_RightRamp"
		box.Anchored = true
		box.Transparency = 1
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		box.Size = Vector3.new(rightPlanks.Size.X + 3, 9, rightPlanks.Size.Z)
		box.CFrame = rightPlanks.CFrame * CFrame.new(0, 3.8, 0)
		box:SetAttribute("Zone", "Boots")
		box.Parent = zones
		say("3 Boots zone box for the right ramp: made")
	else
		say("3 Boots zone box for the right ramp: already done")
	end

	----------------------------------------------------------------------------------------------
	-- 4. The belly path: one even slope instead of the steep middle (pieces 5 to 14)
	----------------------------------------------------------------------------------------------
	local belly: { BasePart } = {}
	for _, piece in walk:GetChildren() do
		if piece.Name == "Belly_Walk" and piece:IsA("BasePart") then
			table.insert(belly, piece)
		end
	end
	table.sort(belly, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	local steepest = 0
	for _, piece in belly do
		steepest = math.max(steepest, slopeOf(piece))
	end
	if steepest <= 60 then
		say(string.format("4 Belly path: already done (steepest piece %.1f degrees)", steepest))
	else
		if #belly ~= 20 then
			error(`4 Belly path: expected the 20 original pieces, found {#belly}`)
		end
		local function topEnds(piece: BasePart): (Vector3, Vector3)
			local centre = piece.Position + piece.CFrame.UpVector * (piece.Size.Y / 2)
			local along = piece.CFrame.LookVector
			if along.Y < 0 then
				along = -along
			end
			return centre - along * piece.Size.Z / 2, centre + along * piece.Size.Z / 2
		end
		local _, startPoint = topEnds(belly[4]) -- the top of piece 4
		local endPoint, _ = topEnds(belly[15]) -- the start of piece 15
		local line = endPoint - startPoint
		local lineSlope = math.deg(math.asin(line.Y / line.Magnitude))
		if lineSlope >= 60 then
			error(string.format("4 Belly path: the even slope would be %.1f degrees, which is not under 60", lineSlope))
		end
		local lines: { string } = {}
		for index = 5, 14 do
			local old = belly[index]
			table.insert(
				lines,
				string.format(
					"old %d pos (%.2f, %.2f, %.2f) size (%.1f, %.1f, %.2f) slope %.1f",
					index,
					old.Position.X,
					old.Position.Y,
					old.Position.Z,
					old.Size.X,
					old.Size.Y,
					old.Size.Z,
					slopeOf(old)
				)
			)
		end
		say("4 Belly path, pieces removed (kept in this report): " .. table.concat(lines, "; "))
		local template = belly[4]
		local pieceCount = 7
		local segment = line.Magnitude / pieceCount
		local direction = line.Unit
		for step = 0, pieceCount - 1 do
			local from = startPoint + direction * (segment * step)
			local middle = from + direction * (segment / 2)
			local slab = template:Clone()
			slab.Name = "Belly_Walk"
			slab.Size = Vector3.new(template.Size.X, template.Size.Y, segment + 0.4) -- 0.4 overlap, so there is no crack
			local aim = CFrame.lookAt(middle, middle + direction)
			slab.CFrame = aim - aim.UpVector * (slab.Size.Y / 2) -- its top face lies on the line
			slab.Parent = walk
		end
		for index = 5, 14 do
			belly[index]:Destroy()
		end
		say(
			string.format(
				"4 Belly path: 10 steep pieces replaced by %d slabs on one even slope of %.1f degrees (line length %.2f, %.1f wide)",
				pieceCount,
				lineSlope,
				line.Magnitude,
				template.Size.X
			)
		)
	end

	----------------------------------------------------------------------------------------------
	-- 5. The beard ladder's top level with the nose pad (its rails stopped 0.45 short)
	----------------------------------------------------------------------------------------------
	local beardLadder = walk:FindFirstChild("BeardLadder")
	local nosePad = walk:FindFirstChild("Nose_Walk") :: BasePart
	if beardLadder == nil then
		error("WalkSurfaces.BeardLadder is missing")
	end
	local padTop = nosePad.Position.Y + nosePad.Size.Y / 2
	local ladderTop = -math.huge
	for _, part in beardLadder:GetDescendants() do
		if part:IsA("BasePart") then
			ladderTop = math.max(ladderTop, topCornerY(part))
		end
	end
	if math.abs(ladderTop - padTop) <= 0.1 then
		say(string.format("5 Beard ladder top: already done (%.2f, pad %.2f)", ladderTop, padTop))
	else
		local lengthened = 0
		for _, part in beardLadder:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Rail" and math.abs(topCornerY(part) - ladderTop) < 0.05 then
				local along = part.CFrame.RightVector -- the rail's long side is its X axis
				if along.Y < 0 then
					along = -along
				end
				local extra = (padTop - ladderTop) / along.Y
				part.Size = Vector3.new(part.Size.X + extra, part.Size.Y, part.Size.Z)
				part.CFrame = part.CFrame + along * (extra / 2)
				lengthened += 1
			end
		end
		say(
			string.format(
				"5 Beard ladder top: %d rails lengthened, from %.2f to level with the nose pad (%.2f)",
				lengthened,
				ladderTop,
				padTop
			)
		)
	end

	----------------------------------------------------------------------------------------------
	-- 6. The steep guards: smooth, invisible, steeper than 75 degrees
	----------------------------------------------------------------------------------------------
	if walk:FindFirstChild("SteepGuards") then
		say("6 Steep guards: already done")
	else
		local guards = Instance.new("Folder")
		guards.Name = "SteepGuards"
		local made = 0
		-- One slab. It covers `tangentFrom` to `tangentTo` along the surface (x for fronts, z for sides) and the
		-- heights yLow to yHigh, facing outward `out` (a horizontal direction), leaning `slope` degrees from flat.
		-- Its front face is placed in front of every point of the giant that the strip finds, so a player meets
		-- the smooth slab first and never the bumpy skin.
		local function slab(
			name: string,
			out: Vector3,
			tangentFrom: number,
			tangentTo: number,
			yLow: number,
			yHigh: number,
			slope: number
		)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { giant }
			local theta = math.rad(slope)
			local cotangent = if slope >= 90 then 0 else 1 / math.tan(theta)
			local tangentAxis = out:Cross(Vector3.yAxis)
			local anchor = -math.huge
			local samples = 0
			for _, tangent in { tangentFrom, (tangentFrom + tangentTo) / 2, tangentTo } do
				local y = yLow
				while y <= yHigh + 0.001 do
					local origin = tangentAxis * tangent + Vector3.new(0, y, 0) + out * 150
					local hit = Workspace:Raycast(origin, -out * 300, params)
					if hit then
						samples += 1
						local outward = hit.Position:Dot(out)
						anchor = math.max(anchor, outward + (y - yLow) * cotangent + 0.6)
					end
					y += 2
				end
			end
			if samples == 0 then
				return
			end
			local yMiddle = (yLow + yHigh) / 2
			local faceOutward = anchor - (yMiddle - yLow) * cotangent
			local tangentMiddle = (tangentFrom + tangentTo) / 2
			local normal = out * math.sin(theta) + Vector3.yAxis * math.cos(theta)
			local upSlope = -out * math.cos(theta) + Vector3.yAxis * math.sin(theta)
			local facePoint = tangentAxis * tangentMiddle + out * faceOutward + Vector3.new(0, yMiddle, 0)
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.Transparency = 1
			part.CanCollide = true
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Size = Vector3.new(math.abs(tangentTo - tangentFrom) + 0.6, 1, (yHigh - yLow) / math.sin(theta))
			part.CFrame = CFrame.fromMatrix(facePoint - normal * 0.5, tangentAxis, normal, upSlope)
			part.Parent = guards
			made += 1
		end

		local front = Vector3.new(0, 0, -1)
		local leftSide = Vector3.new(-1, 0, 0)
		local rightSide = Vector3.new(1, 0, 0)
		-- the front of the beard beside the ladder (the ladder is 5 wide, so strips start 4 studs from the middle)
		for _, strip in { { 4, 12 }, { 12, 20 }, { 20, 28 } } do
			slab(`BeardFront_R{strip[1]}`, front, strip[1], strip[2], 68, 92, 80)
			slab(`BeardFront_L{strip[1]}`, front, -strip[2], -strip[1], 68, 92, 80)
		end
		-- his face below the forehead guard (cheeks and mouth), beside the nose pad (the pad is 12 wide)
		for _, strip in { { 6.5, 14 }, { 14, 22 }, { 22, 30 } } do
			slab(`Face_R{strip[1]}`, front, strip[1], strip[2], 92, 106, 80)
			slab(`Face_L{strip[1]}`, front, -strip[2], -strip[1], 92, 106, 80)
		end
		-- the sides of the nightcap, in strips along his length
		for start = 12, 60, 8 do
			-- (the left side's along-axis points toward -z, so its strips are given as negative numbers)
			slab(`CapSideLeft_{start}`, leftSide, -(start + 8), -start, 84, 112, 80)
			slab(`CapSideRight_{start}`, rightSide, start, start + 8, 84, 112, 80)
		end
		-- the fronts of both boots, beside the ramps (the ramps are 9 wide, so the walls start 1 stud outside them)
		for _, strip in { { -35, -29.6 }, { -18.4, -13 }, { 13, 18.4 }, { 29.6, 35 } } do
			slab(`BootFront_{strip[1]}`, front, strip[1], strip[2], 3, 33, 90)
		end
		guards.Parent = walk
		say(string.format("6 Steep guards: %d slabs made (beard front, face, cap sides, boot fronts)", made))
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("03-climb: after")
	end)
	return nil
end

local ok, message = pcall(run)
if not ok then
	say("STOPPED WITH AN ERROR: " .. tostring(message))
end
return table.concat(report, "\n")
