--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local SMALL_PATCHES_FOLDER = Helpers.SMALL_PATCHES_FOLDER
local inFakeWorld = Helpers.inFakeWorld
local startsWith = Helpers.startsWith

-- Stuck safety Task 23 (code_lead's ruling after step 23-8b.1, Ruling 11): a meadow prop (the Sock) can have a small
-- ramp that replaces a step between the prop and the grass, `Ramp_<Place>_<n>` in World.WalkSurfaces.SmallPatches. It
-- is not a patch on his skin (Rule 20 is about him), so Task 22's patch test leaves it alone and this test checks it.
describe("the real world, ramps on meadow props", function()
	local Workspace = game:GetService("Workspace")

	local RAMP_PLACES = { "Sock" } -- places that must have a ramp
	local RAMP_PATTERN = "^Ramp_(%w+)_%d+$" -- Ramp_<Place>_<n>
	local PATCH_PATTERN = "^Patch_%w+_%d+$" -- Patch_<Place>_<n>
	local BLOCK_PATTERN = "^Block_%w+_%d+$" -- Block_<Place>_<n>: a sealing block, read by the hang test
	local MAX_RAMP_DEGREES = 45 -- the crossing ramps' limit: a player walks up it without a jump
	local MAX_EDGE_GAP = 0.2 -- studs: the gap to the prop's surface, and to the ground where the ramp meets it
	local STEP_HEIGHT = 1.4 -- studs: the most the ramp's top may stand over the ground (the step it replaces)
	local STEP_SLACK = 0.05 -- studs: rounding in the numbers written into the world
	local SAMPLE_SPACING = 0.25 -- studs: the grid of rays down over the ramp's top
	local EDGE_INSET = 0.05 -- studs: the grid starts this far inside the ramp's box
	local TOP_EDGE_BAND = 0.05 -- studs: a sample within this of the highest one is on the top edge
	local RAY_START_ABOVE = 1.5 -- studs: a ray to the prop or the ground starts this far over the ramp's top
	local RAY_LENGTH = 8 -- studs
	local FLAT_DEGREES_SLACK = 0.01

	type Sample = { position: Vector3, normal: Vector3 }

	local function boxCorners(part: BasePart): { Vector3 }
		local corners: { Vector3 } = {}
		for _, signX in { -1, 1 } do
			for _, signY in { -1, 1 } do
				for _, signZ in { -1, 1 } do
					table.insert(
						corners,
						part.CFrame:PointToWorldSpace(
							Vector3.new(signX * part.Size.X / 2, signY * part.Size.Y / 2, signZ * part.Size.Z / 2)
						)
					)
				end
			end
		end
		return corners
	end

	-- Where rays down hit the ramp's top: a grid over the ramp's box, SAMPLE_SPACING apart.
	local function topSamples(world: WorldRoot, ramp: BasePart): { Sample }
		local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, corner in boxCorners(ramp) do
			low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
			high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { ramp }
		params.RespectCanCollide = false
		local samples: { Sample } = {}
		local x = low.X + EDGE_INSET
		while x <= high.X - EDGE_INSET do
			local z = low.Z + EDGE_INSET
			while z <= high.Z - EDGE_INSET do
				local hit =
					world:Raycast(Vector3.new(x, high.Y + 1, z), Vector3.new(0, -(high.Y - low.Y + 2), 0), params)
				if hit ~= nil then
					table.insert(samples, { position = hit.Position, normal = hit.Normal })
				end
				z += SAMPLE_SPACING
			end
			x += SAMPLE_SPACING
		end
		return samples
	end

	-- The height of the first surface under (x, z) that a ray from `fromY` meets, with the filter given; nil when none.
	local function surfaceHeight(
		world: WorldRoot,
		filterType: Enum.RaycastFilterType,
		filter: { Instance },
		x: number,
		z: number,
		fromY: number
	): number?
		local params = RaycastParams.new()
		params.FilterType = filterType
		params.FilterDescendantsInstances = filter
		params.RespectCanCollide = false
		local hit = world:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -RAY_LENGTH, 0), params)
		return if hit ~= nil then hit.Position.Y else nil
	end

	-- The checker. Returns its problems as sentences, each starting with the name of its rule; none means the ramps
	-- pass. `props` maps a place name ("Sock") to the prop it belongs to; `places` are the places that must have a ramp.
	local function rampProblems(
		world: WorldRoot,
		folder: Instance?,
		props: { [string]: Instance },
		places: { string }
	): { string }
		local problems: { string } = {}
		local ramps: { BasePart } = {}
		if folder ~= nil then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") and string.match(descendant.Name, RAMP_PATTERN) ~= nil then
					table.insert(ramps, descendant)
				end
			end
		end
		-- (a) Place: every named place has its ramp
		for _, place in places do
			local found = false
			for _, ramp in ramps do
				if string.match(ramp.Name, RAMP_PATTERN) == place then
					found = true
				end
			end
			if not found then
				table.insert(
					problems,
					`Place: {place} has no ramp (Ramp_{place}_<n> in World.WalkSurfaces.{SMALL_PATCHES_FOLDER})`
				)
			end
		end
		for _, ramp in ramps do
			local place = string.match(ramp.Name, RAMP_PATTERN) :: string
			local prop: Instance? = props[place]
			if prop == nil then
				table.insert(problems, `Prop: {ramp.Name} names the place {place}, which has no prop`)
				continue
			end
			local samples = topSamples(world, ramp)
			if #samples == 0 then
				table.insert(problems, `Top: no ray down finds the top of {ramp.Name}`)
				continue
			end
			-- (b) Slope: the top is walkable
			local steepest = 0
			local highest = -math.huge
			for _, sample in samples do
				steepest = math.max(steepest, math.deg(math.acos(math.clamp(sample.normal.Y, -1, 1))))
				highest = math.max(highest, sample.position.Y)
			end
			if steepest > MAX_RAMP_DEGREES + FLAT_DEGREES_SLACK then
				table.insert(
					problems,
					`Slope: {ramp.Name} slopes up to {string.format("%.1f", steepest)} degrees (wanted at most {MAX_RAMP_DEGREES})`
				)
			end
			-- (c) Prop: along the top edge the ramp meets the prop's surface
			local edgePoints, edgeMissing, edgeBad = 0, 0, 0
			local lowestGap, highestGap = math.huge, -math.huge
			local propFilter = { prop }
			for _, sample in samples do
				if sample.position.Y >= highest - TOP_EDGE_BAND then
					edgePoints += 1
					local propY = surfaceHeight(
						world,
						Enum.RaycastFilterType.Include,
						propFilter,
						sample.position.X,
						sample.position.Z,
						sample.position.Y + RAY_START_ABOVE
					)
					if propY == nil then
						edgeMissing += 1
					else
						local gap = sample.position.Y - propY
						lowestGap, highestGap = math.min(lowestGap, gap), math.max(highestGap, gap)
						if math.abs(gap) > MAX_EDGE_GAP then
							edgeBad += 1
						end
					end
				end
			end
			if edgeMissing > 0 or edgeBad > 0 then
				table.insert(
					problems,
					`Prop: the top edge of {ramp.Name} is off the surface of {prop.Name} at {edgeMissing + edgeBad} of {edgePoints} points ({edgeMissing} with no surface under it; gaps {string.format(
						"%.2f",
						lowestGap
					)} to {string.format("%.2f", highestGap)}, wanted -{MAX_EDGE_GAP} to {MAX_EDGE_GAP})`
				)
			end
			-- (d) Height, Ground, Buried: against the meadow ground (what is under the ramp, with the prop and ramps left out)
			local groundFilter: { Instance } = { ramp, prop }
			if folder ~= nil then
				groundFilter = { folder, prop }
			end
			local bottom = math.huge
			for _, corner in boxCorners(ramp) do
				bottom = math.min(bottom, corner.Y)
			end
			local tallest = -math.huge
			local closest = math.huge
			local floating = 0
			local unreadable = 0
			for _, sample in samples do
				local groundY = surfaceHeight(
					world,
					Enum.RaycastFilterType.Exclude,
					groundFilter,
					sample.position.X,
					sample.position.Z,
					sample.position.Y + RAY_START_ABOVE
				)
				if groundY == nil then
					unreadable += 1
				else
					tallest = math.max(tallest, sample.position.Y - groundY)
					closest = math.min(closest, math.abs(sample.position.Y - groundY))
					if bottom > groundY + STEP_SLACK then
						floating += 1
					end
				end
			end
			if unreadable > 0 then
				table.insert(
					problems,
					`Ground: no meadow ground under {ramp.Name} at {unreadable} of {#samples} points`
				)
			end
			if tallest > STEP_HEIGHT + STEP_SLACK then
				table.insert(
					problems,
					`Height: the top of {ramp.Name} stands up to {string.format("%.2f", tallest)} studs over the ground (wanted at most {STEP_HEIGHT})`
				)
			end
			if closest > MAX_EDGE_GAP then
				table.insert(
					problems,
					`Ground: the top of {ramp.Name} never comes within {MAX_EDGE_GAP} studs of the ground (closest {string.format(
						"%.2f",
						closest
					)})`
				)
			end
			if floating > 0 then
				table.insert(
					problems,
					`Buried: the bottom of {ramp.Name} is above the ground at {floating} of {#samples} points`
				)
			end
		end
		return problems
	end

	-- Every part of the small patches folder is named Patch_<Place>_<n>, Ramp_<Place>_<n> or Block_<Place>_<n>, so each
	-- one is read by a test: Task 22's patch test, the ramp test, or (for a Block_ part) the hang test, which reads it as
	-- a "patch" row with that prefix (ClimbingHangs.spec.luau).
	local function nameProblems(folder: Instance?): { string }
		local problems: { string } = {}
		if folder ~= nil then
			for _, descendant in folder:GetDescendants() do
				if
					descendant:IsA("BasePart")
					and string.match(descendant.Name, PATCH_PATTERN) == nil
					and string.match(descendant.Name, RAMP_PATTERN) == nil
					and string.match(descendant.Name, BLOCK_PATTERN) == nil
				then
					table.insert(
						problems,
						`Name: {descendant.Name} is not Patch_<Place>_<n>, Ramp_<Place>_<n> or Block_<Place>_<n>, so no test reads it`
					)
				end
			end
		end
		return problems
	end

	-- A made-up meadow: ground with its top at height 0; a prop, a block whose top is at `propTop` and whose front face is
	-- at z -1.9, and the ramp: a wedge `rampTop` high at z -2 (its thick end, against the prop's front) sloping down
	-- `degrees` toward +z, 4 wide, bottom `lift` over height -1. The folder holds the ramp.
	local RAMP_TOP = 1.2
	local function makeMeadow(
		world: WorldModel,
		propTop: number,
		rampTop: number,
		degrees: number,
		lift: number
	): (Folder, { [string]: Instance })
		local ground = Instance.new("Part")
		ground.Name = "Ground"
		ground.Size = Vector3.new(40, 10, 40)
		ground.Position = Vector3.new(0, -5, 0)
		ground.Anchored = true
		ground.Parent = world
		local prop = Instance.new("Part")
		prop.Name = "Prop"
		prop.Size = Vector3.new(10, propTop + 3, 6.1)
		prop.Position = Vector3.new(0, propTop - (propTop + 3) / 2, -1.9 - 3.05)
		prop.Anchored = true
		prop.Parent = world
		local folder = Instance.new("Folder")
		folder.Name = SMALL_PATCHES_FOLDER
		folder.Parent = world
		local height = rampTop + 1 -- from height -1 to the top
		local length = height / math.tan(math.rad(degrees))
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp_Sock_1"
		ramp.Size = Vector3.new(4, height, length)
		-- the thick end faces -z (toward the prop): the wedge's local +Z side is its full-height side
		ramp.CFrame = CFrame.fromMatrix(
			Vector3.new(0, -1 + lift + height / 2, -2 + length / 2),
			-Vector3.xAxis, -- up (y) crossed with back (-z)
			Vector3.yAxis,
			-Vector3.zAxis
		)
		ramp.Anchored = true
		ramp.Parent = folder
		return folder, { Sock = prop }
	end

	it("the ramp check passes a 40 degree ramp that meets the prop and the ground", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP, RAMP_TOP, 40, 0)
			expect(rampProblems(world, folder, props, RAMP_PLACES)).toEqual({})
		end)
	end)

	it("the ramp check names a ramp steeper than 45 degrees", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP, RAMP_TOP, 50, 0)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Slope:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the ramp check names a ramp that stands 0.5 studs off the prop's surface", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP + 0.5, RAMP_TOP, 40, 0)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Prop:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the ramp check names a ramp that floats over the ground", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP + 2, RAMP_TOP, 40, 2)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Ground:")).toBe(1)
			expect(#startsWith(problems, "Buried:")).toBe(1)
		end)
	end)

	it("the ramp check names a ramp whose top is higher than the step it replaces", function()
		inFakeWorld(function(world)
			-- The prop's top and the ramp's top are both 1.7 over the ground: they meet, but the step was 1.4.
			local folder, props = makeMeadow(world, 1.7, 1.7, 40, 0)
			local problems = rampProblems(world, folder, props, RAMP_PLACES)
			expect(#startsWith(problems, "Height:")).toBe(1)
			expect(#problems).toBe(1)
		end)
	end)

	it("the ramp check names a place with no ramp", function()
		inFakeWorld(function(world)
			local folder, props = makeMeadow(world, RAMP_TOP, RAMP_TOP, 40, 0)
			local problems = rampProblems(world, folder, props, { "Sock", "Boot" })
			expect(#problems).toBe(1)
			expect((string.find(problems[1], "Place: Boot", 1, true))).never.toBeNil()
		end)
	end)

	it("the ramp check names a ramp whose place has no prop", function()
		inFakeWorld(function(world)
			local folder = makeMeadow(world, RAMP_TOP, RAMP_TOP, 40, 0)
			local problems = rampProblems(world, folder, {}, {})
			expect(#startsWith(problems, "Prop:")).toBe(1)
		end)
	end)

	it("the name check passes Patch_ and Ramp_ names", function()
		inFakeWorld(function(world)
			local folder = Instance.new("Folder")
			folder.Parent = world
			for _, name in { "Patch_Notch_1", "Patch_ChairFoot_12", "Ramp_Sock_1" } do
				local part = Instance.new("Part")
				part.Name = name
				part.Parent = folder
			end
			expect(nameProblems(folder)).toEqual({})
		end)
	end)

	it("the name check passes a sealing block named Block_<Place>_<n>, such as Block_R141_1", function()
		inFakeWorld(function(world)
			local folder = Instance.new("Folder")
			folder.Parent = world
			for _, name in { "Patch_Notch_1", "Block_R141_1" } do
				local part = Instance.new("Part")
				part.Name = name
				part.Parent = folder
			end
			expect(nameProblems(folder)).toEqual({})
		end)
	end)

	it("the name check names a part called Block_1", function()
		inFakeWorld(function(world)
			local folder = Instance.new("Folder")
			folder.Parent = world
			for _, name in { "Patch_Notch_1", "Block_1", "Patch_Notch", "Ramp_1" } do
				local part = Instance.new("Part")
				part.Name = name
				part.Parent = folder
			end
			local problems = nameProblems(folder)
			expect(#problems).toBe(3)
			expect((string.find(problems[1], "Block_1", 1, true))).never.toBeNil()
		end)
	end)

	it("ramps on meadow props are walkable and flush", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local things = (world :: Instance):FindFirstChild("GiantsThings")
		expect(things).never.toBeNil()
		local props: { [string]: Instance } = {}
		for _, place in RAMP_PLACES do
			local prop = (things :: Instance):FindFirstChild(place)
			expect(prop).never.toBeNil()
			props[place] = prop :: Instance
		end
		local problems =
			rampProblems(Workspace, (walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER), props, RAMP_PLACES)
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)

	it("every part in the small patches folder is named as a patch or a ramp", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local walk = (world :: Instance):FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local problems = nameProblems((walk :: Instance):FindFirstChild(SMALL_PATCHES_FOLDER))
		if #problems > 0 then
			error("\n" .. table.concat(problems, "\n"), 0)
		end
	end)
end)
