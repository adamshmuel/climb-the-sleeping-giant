--!strict
-- World prep, task 3: gardens and spawn spots.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every step checks first, so a second run changes nothing and says "already done".
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
-- It does not require anything from src, and it never touches Lighting or Terrain.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Numbers from spec section 5 and the Task 3 handoff (same values as src/shared/Config.luau).
local STUDS_IN_FRONT_OF_GATE = 18
local SPAWN_SPOT_SIZE = Vector3.new(6, 1, 6)
local RAY_START_ABOVE = 50
local RAY_LENGTH = 200
local GARDEN_BELOW_GROUND = 5
local GARDEN_ABOVE_GROUND = 35
local SLAM_FIST_WIDTH = 22
local PLOT_COUNT = 8
local MOCK_SPAWN_MAX_DISTANCE = 2
local MOCK_SPAWN_MAX_DEGREES = 5

local report: { string } = {}
local function say(line: string)
	table.insert(report, line)
end

local function getOrCreateFolder(parent: Instance, name: string): (Folder, boolean)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing, false
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder, true
end

local function describeCFrame(cframe: CFrame): string
	return string.format("(%.3f, %.3f, %.3f)", cframe.X, cframe.Y, cframe.Z)
end

local function run(): any
	pcall(function()
		ChangeHistoryService:SetWaypoint("01-gardens: before")
	end)

	----------------------------------------------------------------------------------------------
	-- Step 1: World
	----------------------------------------------------------------------------------------------
	local mockup = Workspace:FindFirstChild("Mockup_StealTheGiantsEggs")
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		local oldWorld = if mockup then mockup:FindFirstChild("World") else nil
		if oldWorld == nil then
			error("Step 1: there is no Workspace.World and no Mockup_StealTheGiantsEggs.World to move")
		end
		oldWorld.Parent = Workspace
		world = oldWorld
		say("1 World: moved Mockup_StealTheGiantsEggs.World to Workspace.World")
	else
		say("1 World: already done")
	end
	local worldFolder = world :: Instance

	----------------------------------------------------------------------------------------------
	-- Step 2: Art library (kept for later specs, not drawn in the game)
	----------------------------------------------------------------------------------------------
	local artLibrary, artCreated = getOrCreateFolder(ServerStorage, "ArtLibrary")
	local step2: { string } = {}
	if artCreated then
		table.insert(step2, "created ServerStorage.ArtLibrary")
	end
	if mockup then
		for _, name in { "_Generated", "Library" } do
			local item = mockup:FindFirstChild(name)
			if item then
				item.Parent = artLibrary
				table.insert(step2, `moved {name} ({#item:GetChildren()} items)`)
			end
		end
	end
	local eggsFolder = worldFolder:FindFirstChild("Eggs")
	if eggsFolder then
		local laterEggs, laterCreated = getOrCreateFolder(artLibrary, "LaterEggs")
		if laterCreated then
			table.insert(step2, "created ArtLibrary.LaterEggs")
		end
		for _, name in { "Egg_Beard1", "Egg_Nightcap1", "Egg_Dream_DeepSleepOnly" } do
			local egg = eggsFolder:FindFirstChild(name)
			if egg then
				egg.Parent = laterEggs
				table.insert(step2, `moved Eggs.{name} to LaterEggs`)
			end
		end
	end
	if mockup then
		if #mockup:GetChildren() == 0 then
			mockup:Destroy()
			table.insert(step2, "deleted the empty Mockup_StealTheGiantsEggs")
		else
			table.insert(step2, `LEFT Mockup_StealTheGiantsEggs: it still holds {#mockup:GetChildren()} items`)
		end
	end
	say("2 Art library: " .. (if #step2 > 0 then table.concat(step2, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- Step 3: Templates the game copies
	----------------------------------------------------------------------------------------------
	local replicatedAssets, repCreated = getOrCreateFolder(ReplicatedStorage, "Assets")
	local serverAssets, serverCreated = getOrCreateFolder(ServerStorage, "Assets")
	local step3: { string } = {}
	if repCreated then
		table.insert(step3, "created ReplicatedStorage.Assets")
	end
	if serverCreated then
		table.insert(step3, "created ServerStorage.Assets")
	end

	-- Footprint: one sole plus its toes, so the template is a whole footprint.
	if replicatedAssets:FindFirstChild("Footprint") == nil then
		local guide = worldFolder:FindFirstChild("GuideFootprints")
		if guide == nil then
			error("Step 3: Footprint template is missing and World.GuideFootprints is gone")
		end
		local steps = guide:GetChildren()
		local sole = steps[1] :: BasePart
		local footprint = Instance.new("Model")
		footprint.Name = "Footprint"
		local soleCopy = sole:Clone()
		soleCopy.Name = "Sole"
		soleCopy.Parent = footprint
		footprint.PrimaryPart = soleCopy
		local toeCount = 0
		for index = 2, 4 do
			local toe = steps[index] :: BasePart
			if toe.Size.X < sole.Size.X and (toe.Position - sole.Position).Magnitude < 3 then
				local toeCopy = toe:Clone()
				toeCopy.Name = "Toe" .. index - 1
				toeCopy.Parent = footprint
				toeCount += 1
			end
		end
		footprint:PivotTo(CFrame.new(0, 0, 0))
		footprint.Parent = replicatedAssets
		table.insert(step3, `Footprint: 1 sole + {toeCount} toes, centred on the sole at the origin`)
	end

	-- CaughtPoof: the attachment with its 2 particle emitters.
	if replicatedAssets:FindFirstChild("CaughtPoof") == nil then
		local mockSpawn = worldFolder:FindFirstChild("MockSpawn")
		local template = if mockSpawn then mockSpawn:FindFirstChild("CaughtPoofTemplate") else nil
		if template == nil then
			error("Step 3: CaughtPoof template is missing and MockSpawn.CaughtPoofTemplate is gone")
		end
		local poof = template:Clone()
		poof.Name = "CaughtPoof"
		poof.Parent = replicatedAssets
		table.insert(step3, `CaughtPoof: copied with {#poof:GetChildren()} particle emitters`)
	end

	-- SlamFist: the generated hand, scaled to 22 studs wide, fixed in place.
	if replicatedAssets:FindFirstChild("SlamFist") == nil then
		local generated = artLibrary:FindFirstChild("_Generated")
		local hand = if generated then generated:FindFirstChild("Giant_SlamHand") else nil
		if hand == nil then
			error("Step 3: SlamFist template is missing and ArtLibrary._Generated.Giant_SlamHand is gone")
		end
		local fist = hand:Clone() :: Model
		fist.Name = "SlamFist"
		local before = fist:GetExtentsSize()
		fist:ScaleTo(fist:GetScale() * SLAM_FIST_WIDTH / math.max(before.X, before.Z))
		for _, part in fist:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		fist.Parent = replicatedAssets
		local after = fist:GetExtentsSize()
		table.insert(
			step3,
			string.format(
				"SlamFist: %.1fx%.1fx%.1f scaled to %.1fx%.1fx%.1f",
				before.X,
				before.Y,
				before.Z,
				after.X,
				after.Y,
				after.Z
			)
		)
	end
	say("3 Templates: " .. (if #step3 > 0 then table.concat(step3, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- Step 4: Where a carried egg sits on a player (measured on the stand-in players)
	----------------------------------------------------------------------------------------------
	if serverAssets:GetAttribute("CarriedEggOffset") == nil then
		local players = worldFolder:FindFirstChild("OtherPlayers")
		if players == nil then
			error("Step 4: CarriedEggOffset is not stored and World.OtherPlayers is gone")
		end
		local standIns = players:GetChildren()
		table.sort(standIns, function(a, b)
			return a.Name < b.Name
		end)
		local stored = false
		local step4: { string } = {}
		for _, standIn in standIns do
			local egg = standIn:FindFirstChild("CarriedEgg")
			local root = standIn:FindFirstChild("HumanoidRootPart")
			if egg and egg:IsA("Model") and root and root:IsA("BasePart") then
				local offset = root.CFrame:ToObjectSpace(egg:GetPivot())
				local height = egg:GetExtentsSize().Y
				local rarity = tostring(egg:GetAttribute("Rarity") or "?")
				table.insert(
					step4,
					string.format(
						"%s (%s): offset (%.3f, %.3f, %.3f), height %.3f%s",
						standIn.Name,
						rarity,
						offset.X,
						offset.Y,
						offset.Z,
						height,
						if stored then "" else " <- stored"
					)
				)
				if not stored then
					serverAssets:SetAttribute("CarriedEggOffset", offset)
					serverAssets:SetAttribute("CarriedEggHeight", height)
					stored = true
				end
			end
		end
		if not stored then
			error("Step 4: no stand-in player carries an egg")
		end
		say("4 Carried egg (sits behind the player, Z+ in the root part's space): " .. table.concat(step4, "; "))
	else
		say("4 Carried egg: already done")
	end

	----------------------------------------------------------------------------------------------
	-- Step 5: remember the designer's tested spawn for the check in step 7
	----------------------------------------------------------------------------------------------
	local oldSpawnCFrame: CFrame? = nil
	local mockSpawnPart = worldFolder:FindFirstChild("MockSpawn")
	if mockSpawnPart and mockSpawnPart:IsA("BasePart") then
		oldSpawnCFrame = mockSpawnPart.CFrame
		say("5 MockSpawn: remembered " .. describeCFrame(mockSpawnPart.CFrame))
	else
		say("5 MockSpawn: already gone")
	end

	----------------------------------------------------------------------------------------------
	-- Step 6: remove mock-only pieces, and set the later-spec decoration aside
	----------------------------------------------------------------------------------------------
	local step6: { string } = {}
	for _, name in { "OtherPlayers", "WanderingPets", "MockSpawn", "GuideFootprints" } do
		local item = worldFolder:FindFirstChild(name)
		if item then
			item:Destroy()
			table.insert(step6, `deleted {name}`)
		end
	end
	local plotsFolder = worldFolder:FindFirstChild("Plots")
	if plotsFolder == nil then
		error("Step 6: World.Plots is missing")
	end
	local laterSpecs = getOrCreateFolder(artLibrary, "LaterSpecs")
	for index = 1, PLOT_COUNT do
		local plot = plotsFolder:FindFirstChild(`Plot_{index}`)
		local dressing = if plot then plot:FindFirstChild("Dressing") else nil
		if dressing then
			local moved: { string } = {}
			local shelf = getOrCreateFolder(laterSpecs, `Plot_{index}`)
			local function setAside(item: Instance, newName: string?)
				if newName then
					item.Name = newName
				end
				table.insert(moved, item.Name .. " [" .. item.ClassName .. "]")
				item.Parent = shelf
			end
			-- Pets (their "+$/s" tags are inside them and move with them).
			for _, child in dressing:GetChildren() do
				if string.match(child.Name, "^Pet_") then
					setAside(child)
				end
			end
			-- Coin and gem piles.
			for _, child in dressing:GetChildren() do
				if string.match(child.Name, "^Coins%d") or string.find(child.Name, "Gem") then
					setAside(child)
				end
			end
			-- Any tag or timer still left in the decoration (the hatch timers).
			for _, descendant in dressing:GetDescendants() do
				if descendant:IsA("BillboardGui") then
					local owner: Instance = descendant
					while owner.Parent ~= dressing and owner.Parent ~= nil do
						owner = owner.Parent
					end
					setAside(descendant, `{owner.Name}_{descendant.Name}`)
				end
			end
			if #moved > 0 then
				table.insert(step6, `Plot_{index} set aside: {table.concat(moved, ", ")}`)
			end
		end
	end
	say("6 Mock-only pieces: " .. (if #step6 > 0 then table.concat(step6, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- Step 7: a spawn spot in each garden, 18 studs in front of the Safe Gate, facing the giant
	----------------------------------------------------------------------------------------------
	local giant = worldFolder:FindFirstChild("Giant")
	if giant == nil or not giant:IsA("Model") then
		error("Step 7: World.Giant is missing")
	end
	local giantPosition = giant:GetPivot().Position
	local step7: { string } = {}
	local nearestDistance: number? = nil
	local nearestIndex = 0
	local nearestSpot: SpawnLocation? = nil
	for index = 1, PLOT_COUNT do
		local plot = plotsFolder:FindFirstChild(`Plot_{index}`)
		if plot == nil or plot:FindFirstChild("SpawnSpot") then
			continue
		end
		local gate = plot:FindFirstChild("SafeGate")
		local centre = plot:GetAttribute("CenterCFrame")
		if gate == nil or not gate:IsA("Model") or typeof(centre) ~= "CFrame" then
			error(`Step 7: Plot_{index} needs a SafeGate model and a CenterCFrame attribute`)
		end
		local gatePosition = gate:GetPivot().Position
		local toGiant = Vector3.new(giantPosition.X - gatePosition.X, 0, giantPosition.Z - gatePosition.Z).Unit
		local flatSpot = gatePosition + toGiant * STUDS_IN_FRONT_OF_GATE

		local spot = Instance.new("SpawnLocation")
		spot.Name = "SpawnSpot"
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { spot }
		local origin = Vector3.new(flatSpot.X, centre.Y + RAY_START_ABOVE, flatSpot.Z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -RAY_LENGTH, 0), rayParams)
		if hit == nil then
			spot:Destroy()
			error(`Step 7: no ground found under the spawn spot of Plot_{index}`)
		end
		-- The top face is 0.5 above the ground, so the centre of a 1-stud-thick spot is at the ground.
		local position = Vector3.new(flatSpot.X, hit.Position.Y, flatSpot.Z)
		spot.Neutral = true
		spot.Duration = 0
		spot.Anchored = true
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Size = SPAWN_SPOT_SIZE
		spot.CFrame = CFrame.lookAt(position, Vector3.new(giantPosition.X, position.Y, giantPosition.Z))
		spot.Parent = plot
		table.insert(
			step7,
			string.format(
				"Plot_%d at (%.2f, %.2f, %.2f) on %s",
				index,
				position.X,
				position.Y,
				position.Z,
				hit.Instance.Name
			)
		)

		if oldSpawnCFrame then
			local distance = (oldSpawnCFrame.Position - spot.Position).Magnitude
			if nearestDistance == nil or distance < nearestDistance then
				nearestDistance = distance
				nearestIndex = index
				nearestSpot = spot
			end
		end
	end
	-- The designer's tested spawn was for the plot nearest it: the new spot there must match it.
	if oldSpawnCFrame and nearestSpot and nearestDistance then
		local dot = oldSpawnCFrame.LookVector:Dot(nearestSpot.CFrame.LookVector)
		local degrees = math.deg(math.acos(math.clamp(dot, -1, 1)))
		local passed = nearestDistance <= MOCK_SPAWN_MAX_DISTANCE and degrees <= MOCK_SPAWN_MAX_DEGREES
		table.insert(
			step7,
			string.format(
				"MockSpawn check on Plot_%d: %.2f studs apart, %.2f degrees apart, %s",
				nearestIndex,
				nearestDistance,
				degrees,
				if passed then "OK" else "FAILED"
			)
		)
	end
	say("7 Spawn spots: " .. (if #step7 > 0 then table.concat(step7, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- Step 8: an invisible garden box around each garden
	----------------------------------------------------------------------------------------------
	local step8: { string } = {}
	for index = 1, PLOT_COUNT do
		local plot = plotsFolder:FindFirstChild(`Plot_{index}`)
		if plot == nil or plot:FindFirstChild("GardenVolume") then
			continue
		end
		local centre = plot:GetAttribute("CenterCFrame")
		if typeof(centre) ~= "CFrame" then
			error(`Step 8: Plot_{index} has no CenterCFrame attribute`)
		end
		-- Measure every part of the fences and the gate in the plot's own rotation.
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		local partCount = 0
		local measured: { Instance } = {}
		for _, child in plot:GetChildren() do
			if child.Name == "Fence" or child.Name == "SafeGate" then
				table.insert(measured, child)
			end
		end
		for _, piece in measured do
			for _, part in piece:GetDescendants() do
				if part:IsA("BasePart") then
					partCount += 1
					local half = part.Size / 2
					for _, sx in { -1, 1 } do
						for _, sy in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local corner =
									part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
								local inPlot = centre:PointToObjectSpace(corner)
								minX, maxX = math.min(minX, inPlot.X), math.max(maxX, inPlot.X)
								minZ, maxZ = math.min(minZ, inPlot.Z), math.max(maxZ, inPlot.Z)
							end
						end
					end
				end
			end
		end
		if partCount == 0 then
			error(`Step 8: Plot_{index} has no fence or gate parts to measure`)
		end
		local height = GARDEN_BELOW_GROUND + GARDEN_ABOVE_GROUND
		local volume = Instance.new("Part")
		volume.Name = "GardenVolume"
		volume.Anchored = true
		volume.Transparency = 1
		volume.CanCollide = false
		volume.CanQuery = false
		volume.CanTouch = false
		volume.CastShadow = false
		volume.Size = Vector3.new(maxX - minX, height, maxZ - minZ)
		-- The plot's ground is the centre's Y. The box runs from 5 below it to 35 above it.
		volume.CFrame = centre * CFrame.new((minX + maxX) / 2, height / 2 - GARDEN_BELOW_GROUND, (minZ + maxZ) / 2)
		volume.Parent = plot
		table.insert(
			step8,
			string.format(
				"Plot_%d %.1f x %.1f x %.1f (from %d parts)",
				index,
				volume.Size.X,
				volume.Size.Y,
				volume.Size.Z,
				partCount
			)
		)
	end
	say("8 Garden boxes: " .. (if #step8 > 0 then table.concat(step8, "; ") else "already done"))

	----------------------------------------------------------------------------------------------
	-- Step 9: the giant and the gates always reach the player (streaming)
	----------------------------------------------------------------------------------------------
	local step9: { string } = {}
	if giant.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		giant.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		table.insert(step9, "Giant")
	end
	for index = 1, PLOT_COUNT do
		local plot = plotsFolder:FindFirstChild(`Plot_{index}`)
		local gate = if plot then plot:FindFirstChild("SafeGate") else nil
		if gate and gate:IsA("Model") and gate.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
			gate.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			table.insert(step9, `Plot_{index}.SafeGate`)
		end
	end
	say("9 Streaming: " .. (if #step9 > 0 then "set Persistent on " .. table.concat(step9, ", ") else "already done"))

	pcall(function()
		ChangeHistoryService:SetWaypoint("01-gardens: after")
	end)
	return nil
end

local ok, message = pcall(run)
if not ok then
	say("STOPPED WITH AN ERROR: " .. tostring(message))
end
return table.concat(report, "\n")
