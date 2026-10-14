--!strict
-- World prep, task 7, part A: the invisible zone boxes (Boots, Belly, Beard, Nightcap).
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every box is checked before it is made, so a second run changes nothing and says "already done".
-- (A box that exists but differs from the plan is updated, and the report says UPDATED.)
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
-- The Meadow has no box: a player in no box is in the Meadow.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local report: { string } = {}
local function say(line: string)
	table.insert(report, line)
end

-- The corners of a part, in world space.
local function cornersOf(part: BasePart): { Vector3 }
	local half = part.Size / 2
	local corners: { Vector3 } = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(corners, part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
			end
		end
	end
	return corners
end

local function partsNamed(folder: Instance, name: string): { BasePart }
	local found: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child.Name == name and child:IsA("BasePart") then
			table.insert(found, child)
		end
	end
	return found
end

local function run(): any
	pcall(function()
		ChangeHistoryService:SetWaypoint("02-zones: before")
	end)

	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local walk = world:FindFirstChild("WalkSurfaces")
	if walk == nil then
		error("World.WalkSurfaces must exist")
	end
	-- The mockup eggs (World.Eggs) are gone after tools/world/04-egg-spots.luau. They are only needed to place the
	-- Boots_TopRight box the first time.
	local eggs = world:FindFirstChild("Eggs")

	local zones = world:FindFirstChild("Zones")
	if zones == nil then
		zones = Instance.new("Folder")
		zones.Name = "Zones"
		zones.Parent = world
		say("created World.Zones")
	end
	local zonesFolder = zones :: Instance

	-- Makes one box. If a box with that name is already there and matches, nothing changes; if it is there but
	-- has a different place, size or zone, it is updated to match.
	local function makeBox(name: string, zone: string, cframe: CFrame, size: Vector3)
		local existing = zonesFolder:FindFirstChild(name)
		if existing and existing:IsA("BasePart") then
			local same = existing.Size:FuzzyEq(size, 0.01)
				and existing.CFrame.Position:FuzzyEq(cframe.Position, 0.01)
				and existing:GetAttribute("Zone") == zone
			if same then
				say(`{name}: already done`)
			else
				existing.Size = size
				existing.CFrame = cframe
				existing:SetAttribute("Zone", zone)
				say(
					string.format(
						"%s (%s): UPDATED, size %.1f x %.1f x %.1f at (%.1f, %.1f, %.1f)",
						name,
						zone,
						size.X,
						size.Y,
						size.Z,
						cframe.X,
						cframe.Y,
						cframe.Z
					)
				)
			end
			return
		end
		local box = Instance.new("Part")
		box.Name = name
		box.Anchored = true
		box.Transparency = 1
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		box.Size = size
		box.CFrame = cframe
		box:SetAttribute("Zone", zone)
		box.Parent = zonesFolder
		say(
			string.format(
				"%s (%s): made, size %.1f x %.1f x %.1f at (%.1f, %.1f, %.1f)",
				name,
				zone,
				size.X,
				size.Y,
				size.Z,
				cframe.X,
				cframe.Y,
				cframe.Z
			)
		)
	end

	-- BOOTS 1: the left boot ramp. A box turned like the ramp, from just under its surface to 8 studs above it,
	-- and 1.5 studs wider each side, so the grass beside the ramp foot stays Meadow.
	local ramp = (walk:FindFirstChild("BootRamp") :: Instance):FindFirstChild("Ramp_Walk") :: BasePart
	makeBox("Boots_Ramp", "Boots", ramp.CFrame * CFrame.new(0, 3.8, 0), Vector3.new(ramp.Size.X + 3, 9, ramp.Size.Z))

	-- BOOTS 2: the left boot top, around the Boots_Walk pieces (5 studs more each side, 4 more along).
	local bootPieces = partsNamed(walk, "Boots_Walk")
	if #bootPieces == 0 then
		error("no Boots_Walk pieces found")
	end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, piece in bootPieces do
		for _, corner in cornersOf(piece) do
			lo = Vector3.new(math.min(lo.X, corner.X), math.min(lo.Y, corner.Y), math.min(lo.Z, corner.Z))
			hi = Vector3.new(math.max(hi.X, corner.X), math.max(hi.Y, corner.Y), math.max(hi.Z, corner.Z))
		end
	end
	lo = lo - Vector3.new(5, 6, 4)
	hi = hi + Vector3.new(5, 8, 4)
	makeBox("Boots_TopLeft", "Boots", CFrame.new((lo + hi) / 2), hi - lo)

	-- BOOTS 3: the right boot top, around the Uncommon egg on it (Egg_Boot2). Once that egg has moved to the art
	-- library, the box that was made around it is already there and stays as it is.
	local boot2Egg = if eggs then eggs:FindFirstChild("Egg_Boot2") else nil
	if boot2Egg then
		local boot2 = (boot2Egg :: Model):GetPivot().Position
		makeBox("Boots_TopRight", "Boots", CFrame.new(boot2.X, 32, boot2.Z - 2), Vector3.new(20, 16, 24))
	elseif zonesFolder:FindFirstChild("Boots_TopRight") then
		say("Boots_TopRight: already done (the mockup egg is gone, so the box stays as it is)")
	else
		error("Boots_TopRight is missing and the mockup egg Egg_Boot2 is gone, so it can't be made")
	end

	-- BELLY: a box turned along the belly path, tall enough to hold the climb, 9 studs wider each side and 2
	-- longer each end (and 1 below to 8 above its surface), so stepping off the path is still Belly. The first pieces of the path run over his knees
	-- (heights 29 to 39), which are Boots ("Boots and Knees"), so the box only holds pieces that lie entirely above height 40.
	local bellyPieces: { BasePart } = {}
	for _, piece in partsNamed(walk, "Belly_Walk") do
		local lowest = math.huge
		for _, corner in cornersOf(piece) do
			lowest = math.min(lowest, corner.Y)
		end
		if lowest >= 40 then
			table.insert(bellyPieces, piece)
		end
	end
	if #bellyPieces == 0 then
		error("no Belly_Walk pieces found on his belly")
	end
	table.sort(bellyPieces, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	local from, to = bellyPieces[1].Position, bellyPieces[#bellyPieces].Position
	local frame = CFrame.lookAt(Vector3.zero, Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit)
	local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, piece in bellyPieces do
		for _, corner in cornersOf(piece) do
			local inFrame = frame:PointToObjectSpace(corner)
			minX, maxX = math.min(minX, inFrame.X), math.max(maxX, inFrame.X)
			minY, maxY = math.min(minY, inFrame.Y), math.max(maxY, inFrame.Y)
			minZ, maxZ = math.min(minZ, inFrame.Z), math.max(maxZ, inFrame.Z)
		end
	end
	minX, maxX, minY, maxY, minZ, maxZ = minX - 9, maxX + 9, minY - 1, maxY + 8, minZ - 2, maxZ + 2
	makeBox(
		"Belly_Path",
		"Belly",
		frame * CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2),
		Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	)

	-- BEARD: the beard ladder, the beard around it, and the nose pad. From the foot of the ladder
	-- (height 66) up to just above the nose pad (107), along his beard and over the pad (art-list.md, "Walk surfaces").
	makeBox("Beard_Ladder", "Beard", CFrame.new(0, 86.5, -12), Vector3.new(24, 41, 32))

	-- NIGHTCAP: the cap ladder above the nose, the path along the cap and the top of the cap (height 106 up).
	makeBox("Nightcap_Top", "Nightcap", CFrame.new(6, 118, 13), Vector3.new(40, 24, 34))

	-- THE REST OF HIM. A player can stand on any part of his body, not only on the route, so these boxes cover
	-- everything the 4-stud grid test of RealWorld.spec finds (rays down onto his body and the walk surfaces).
	-- Where boxes overlap, the higher zone wins. Every bottom is at least 9 studs up, so the meadow stays Meadow.
	-- Boots: his legs and boots.
	makeBox("Boots_Legs", "Boots", CFrame.new(0, 28, -43.5), Vector3.new(80, 32, 53))
	-- Belly: his body, the red cushion and both arms. His belly front is a V between his knees (the legs fill the
	-- flanks from z -46 to -22), so the front is built from narrow strips that follow the V, and the main box
	-- only starts behind it. That keeps his legs and knees Boots (the idea's "Boots and Knees" zone).
	makeBox("Belly_Body", "Belly", CFrame.new(0, 39.5, 26), Vector3.new(120, 61, 84))
	makeBox("Belly_Mid", "Belly", CFrame.new(0, 39.5, -21), Vector3.new(68, 61, 14))
	-- the low edge of the cushion sticks out wider than the legs at this height
	makeBox("Belly_MidLow", "Belly", CFrame.new(0, 15.5, -21), Vector3.new(88, 13, 14))
	makeBox("Belly_FrontA", "Belly", CFrame.new(0, 39.5, -42), Vector3.new(28, 61, 4))
	makeBox("Belly_FrontB", "Belly", CFrame.new(0, 39.5, -38), Vector3.new(44, 61, 4))
	makeBox("Belly_FrontC", "Belly", CFrame.new(0, 39.5, -34), Vector3.new(52, 61, 4))
	makeBox("Belly_FrontD", "Belly", CFrame.new(0, 39.5, -30), Vector3.new(60, 61, 4))
	-- Beard: his head, face and beard, up to height 99 where the nightcap starts. It reaches 12 studs in front of his
	-- face (z -26) so the steep guards standing there are inside it too.
	makeBox("Beard_Head", "Beard", CFrame.new(0, 85.5, 5), Vector3.new(100, 27, 62))
	-- His brow, between the nose pad and the cap (the forehead guard): Beard up to height 106, Nightcap above it.
	makeBox("Beard_Brow", "Beard", CFrame.new(0, 103, -5), Vector3.new(104, 8, 18))
	makeBox("Nightcap_Brow", "Nightcap", CFrame.new(0, 118, -3), Vector3.new(104, 24, 14))
	-- Nightcap: the cap over his head (from height 99, and behind z 3 so the nose pad stays Beard), and its tail.
	makeBox("Nightcap_Cap", "Nightcap", CFrame.new(0, 114.5, 21.5), Vector3.new(104, 31, 37))
	makeBox("Nightcap_Tail", "Nightcap", CFrame.new(0, 101, 53), Vector3.new(104, 58, 34))

	pcall(function()
		ChangeHistoryService:SetWaypoint("02-zones: after")
	end)
	return nil
end

local ok, message = pcall(run)
if not ok then
	say("STOPPED WITH AN ERROR: " .. tostring(message))
end
return table.concat(report, "\n")
