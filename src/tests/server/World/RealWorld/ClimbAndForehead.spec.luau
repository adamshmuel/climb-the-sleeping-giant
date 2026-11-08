--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)
local locator = Helpers.locator
local realWorld = Helpers.realWorld

describe("the real world, zones and extras", function()
	it("the real world passes the climb check", function()
		local climb, problems = WorldIndex.readClimb(realWorld())
		expect(problems).toEqual({})
		expect(climb).never.toBeNil()
	end)

	it("the right boot ramp is in the Boots zone and its foot is on the meadow", function()
		local world, locate = locator()
		local ramp = ((world :: any).WalkSurfaces.RightBootRamp :: Instance):FindFirstChild("Ramp_Walk") :: BasePart
		expect(ramp).never.toBeNil()
		local lowEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, ramp.Size.Z / 2))
		local highEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, -ramp.Size.Z / 2))
		local foot, top = lowEnd, highEnd
		if lowEnd.Y > highEnd.Y then
			foot, top = highEnd, lowEnd
		end
		local up = ramp.CFrame.UpVector * 3.3 -- the top of the planks, then a player's root height
		-- points along the ramp, from just above its foot to its top, are all Boots
		for _, fraction in { 0.1, 0.3, 0.5, 0.7, 0.9, 1 } do
			expect(locate(foot:Lerp(top, fraction) + up).zone).toBe("Boots")
		end
		-- the foot is on the grass (the ground there is Terrain at about height 2; the stream bed is below 0)
		local terrain = RaycastParams.new()
		terrain.FilterType = Enum.RaycastFilterType.Include
		terrain.FilterDescendantsInstances = { workspace.Terrain }
		local ground = workspace:Raycast(Vector3.new(foot.X, 100, foot.Z), Vector3.new(0, -200, 0), terrain)
		expect(ground).never.toBeNil()
		expect((ground :: RaycastResult).Position.Y > 1).toBe(true)
		expect(math.abs((ground :: RaycastResult).Position.Y - foot.Y) < 1).toBe(true)
		-- grass 4 studs beside the foot stays Meadow
		local beside = foot + ramp.CFrame.RightVector * (ramp.Size.X / 2 + 4) + Vector3.new(0, 3, 0)
		expect(locate(beside)).toEqual({ zone = "Meadow", garden = nil })
		-- the ramp is at least 9 studs wide and no steeper than 45 degrees along its length
		expect(ramp.Size.X >= 9).toBe(true)
		local rise = top.Y - foot.Y
		expect(math.deg(math.asin(rise / (top - foot).Magnitude)) <= 45).toBe(true)
	end)

	-- Rule 8 (Steps make noise): the left ramp counts as the giant from just above its foot to its top.
	it("the left boot ramp is in the Boots zone from just above its foot to its top", function()
		local world, locate = locator()
		local ramp = (world :: any).WalkSurfaces.BootRamp.Ramp_Walk :: BasePart
		local lowEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, ramp.Size.Z / 2))
		local highEnd = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, -ramp.Size.Z / 2))
		local foot, top = lowEnd, highEnd
		if lowEnd.Y > highEnd.Y then
			foot, top = highEnd, lowEnd
		end
		local up = ramp.CFrame.UpVector * 3.3 -- the top of the planks, then a player's root height
		for _, fraction in { 0.1, 0.3, 0.5, 0.7, 0.9, 1 } do
			local zone = locate(foot:Lerp(top, fraction) + up).zone
			expect({ fraction = fraction, zone = zone }).toEqual({ fraction = fraction, zone = "Boots" })
		end
	end)

	-- Check B3 (fair for every garden): the walk from a garden to the ramp's foot must be silent. A zone box over a
	-- meadow path would make one garden's walk louder than another's. The first place along a link that is not in
	-- the Meadow zone is reported (a garden counts as Meadow here, because a garden always reports the Meadow).
	it("every meadow route link stays in the Meadow", function()
		local world, locate = locator()
		local points, problems = WorldIndex.readRoute(world)
		expect(problems).toEqual({})
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in points :: { WorldIndex.RoutePoint } do
			byName[point.name] = point
		end
		local up = Vector3.new(0, 3, 0) -- a player's root is about 3 studs above their feet
		local checked: { [string]: boolean } = {}
		local linksChecked = 0
		local bad: { string } = {}
		for _, point in points :: { WorldIndex.RoutePoint } do
			for _, neighbourName in point.neighbours do
				local neighbour = byName[neighbourName]
				local first, second = point.name, neighbourName
				if second < first then
					first, second = second, first
				end
				local key = `{first} - {second}`
				if neighbour == nil or checked[key] then
					continue
				end
				checked[key] = true
				if locate(point.position + up).zone ~= "Meadow" or locate(neighbour.position + up).zone ~= "Meadow" then
					continue -- a link that starts or ends on the giant is not a meadow link
				end
				linksChecked += 1
				local length = (neighbour.position - point.position).Magnitude
				local steps = math.ceil(length)
				for step = 0, steps do
					local place = point.position:Lerp(neighbour.position, step / steps) + up
					local zone = locate(place).zone
					if zone ~= "Meadow" then
						table.insert(bad, `{key}: {zone} at {step / steps * length} studs of {length}`)
						break
					end
				end
			end
		end
		expect(linksChecked > 20).toBe(true)
		expect(bad).toEqual({})
	end)

	-- How steep a part's top face is, in degrees from flat.
	local function slopeOf(part: BasePart): number
		return math.deg(math.acos(math.clamp(math.abs(part.CFrame.UpVector.Y), 0, 1)))
	end

	-- The count that tools/world/15-real-shape.luau section 2 reported it leaves (2026-10-20): the step piece (Boots_Walk 1),
	-- CrossingRamp_Ankle and CrossingRamp_Knee, the 2 ramp planks, Nose_Walk 1 and Nightcap_Walk 3 (9 in all).
	-- Stuck safety Task 25 (plan section 2b of tools/world/15-real-shape.luau) took away 4 of them: Nose_Walk and the 3
	-- Nightcap_Walk pieces. Plan 3 Task 6b took away the 2 crossing ramps (CrossingRamp_Ankle and CrossingRamp_Knee). The 3
	-- left are the 2 ramp planks (Ramp_Walk) and the step piece (Boots_Walk 1).
	local ROUTE_SURFACE_COUNT = 3

	it("no walk surface on the route is steeper than 60 degrees", function()
		local walk = (realWorld() :: any).WalkSurfaces :: Instance
		-- the two ramps, and every piece named *_Walk (the ladders, trusses and guards are not walked on)
		local surfaces: { BasePart } = {}
		for _, rampName in { "BootRamp", "RightBootRamp" } do
			local ramp = walk:FindFirstChild(rampName)
			local planks = if ramp then ramp:FindFirstChild("Ramp_Walk") else nil
			expect(planks).never.toBeNil()
			table.insert(surfaces, planks :: BasePart)
		end
		for _, piece in walk:GetChildren() do
			if piece:IsA("BasePart") and string.match(piece.Name, "_Walk$") then
				table.insert(surfaces, piece)
			end
		end
		-- The exact number of walk surfaces, so the test still fails if one goes missing (stuck safety Task 24, Ruling 5).
		-- Before Task 24 it was 39: the 2 ramp planks, 33 legs and belly pieces (Boots_Walk 8, RightBoots_Walk 8,
		-- Belly_Walk 17), Nose_Walk 1 and Nightcap_Walk 3. Task 24 made it the number its world script reports; Task 25
		-- changes it again for the head.
		expect(#surfaces).toBe(ROUTE_SURFACE_COUNT)
		local tooSteep = {}
		for _, surface in surfaces do
			if slopeOf(surface) > 60 then
				table.insert(
					tooSteep,
					string.format(
						"%s at (%.0f, %.0f, %.0f): %.0f degrees",
						surface.Name,
						surface.Position.X,
						surface.Position.Y,
						surface.Position.Z,
						slopeOf(surface)
					)
				)
			end
		end
		table.sort(tooSteep)
		expect(tooSteep).toEqual({})
	end)

	it("every steep guard is steeper than 75 degrees", function()
		local guards = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("SteepGuards")
		expect(guards).never.toBeNil()
		local slabs = (guards :: Instance):GetChildren()
		expect(#slabs >= 20).toBe(true) -- face, beard front, both cap sides, both boot fronts
		local wrong = {}
		for _, slab in slabs do
			local part = slab :: BasePart
			local solidAndInvisible = part:IsA("BasePart")
				and part.Transparency == 1
				and part.CanCollide
				and part.Anchored
			if not solidAndInvisible or slopeOf(part) <= 75 then
				table.insert(
					wrong,
					string.format(
						"%s at (%.0f, %.0f, %.0f)",
						part.Name,
						part.Position.X,
						part.Position.Y,
						part.Position.Z
					)
				)
			end
		end
		expect(wrong).toEqual({})
	end)

	-- Stuck safety Task 25 (game_creator's yes): V1's invisible middle forehead slab goes. The visible cap ladder is the
	-- only way from his nose to his cap. The four side walls (|x| over 7) stay.
	it("the middle forehead slab is gone", function()
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local middle = {}
		for _, child in (guard :: Instance):GetChildren() do
			if child:IsA("BasePart") and child.Name == "Guard" and math.abs(child.Position.X) < 7 then
				table.insert(middle, string.format("Guard at x %.1f, size x %.1f", child.Position.X, child.Size.X))
			end
		end
		expect(middle).toEqual({})
	end)

	it("the forehead slabs beside the cap ladder are steeper than 75 degrees", function()
		local guard = ((realWorld() :: any).WalkSurfaces :: Instance):FindFirstChild("ForeheadGuard")
		expect(guard).never.toBeNil()
		local slabs = (guard :: Instance):GetChildren()
		expect(#slabs >= 5).toBe(true)
		local wrong = {}
		local beside = 0
		for _, slab in slabs do
			local part = slab :: BasePart
			-- only the four side walls count: the middle slab is gone (stuck safety Task 25, game_creator's yes), and
			-- the side rails are upright rails, not slabs
			if part:IsA("BasePart") and part.Name == "Guard" and math.abs(part.Position.X) > 7 then
				beside += 1
				local solidAndInvisible = part.Transparency == 1 and part.CanCollide and part.Anchored
				if not solidAndInvisible or slopeOf(part) <= 75 then
					table.insert(
						wrong,
						string.format("%s at x %.0f: %.1f degrees", part.Name, part.Position.X, slopeOf(part))
					)
				end
			end
		end
		expect(beside >= 4).toBe(true)
		expect(wrong).toEqual({})
	end)

	it("the slope limit is 70", function()
		-- set in default.project.json: Roblox's own limit is 89, which lets players walk up almost anything
		expect(game:GetService("StarterPlayer").CharacterMaxSlopeAngle).toBe(70)
	end)

	it("phone auto-jump is off", function()
		-- set in default.project.json: an automatic hop on the giant thuds and can wake him
		expect(game:GetService("StarterPlayer").AutoJumpEnabled).toBe(false)
	end)

	it("the 7 props behind the landing spots are out of the meadow (designer's clear view)", function()
		-- The bounce camera sat inside these props (style guide, "Clear view behind each landing spot"). The middle is
		-- the middle of the model's bounding box, x and z. tools/world/10-clear-landing-views.luau moves them.
		local removedProps: { { name: string, x: number, z: number } } = {
			{ name = "Nature_Sunflower", x = 51.7, z = -96.9 },
			{ name = "Nature_Sunflower", x = -50.3, z = -70.7 },
			{ name = "Nature_Sunflower", x = -52.9, z = -62.4 },
			{ name = "Nature_Sunflower", x = -60.2, z = -59.0 },
			{ name = "Nature_Sunflower", x = 47.7, z = -72.0 },
			{ name = "Inno_White_Flowers", x = -56.6, z = -62.9 },
			{ name = "Inno_Yellow_Flowers", x = 52.6, z = -59.8 },
		}
		local nature = (realWorld() :: any).Nature :: Instance
		local artLibrary = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		local removedNature = if artLibrary then artLibrary:FindFirstChild("RemovedNature") else nil
		expect(nature).never.toBeNil()
		expect(removedNature).never.toBeNil()

		local function countAt(folder: Instance, entry: { name: string, x: number, z: number }): number
			local count = 0
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child.Name == entry.name then
					local middle = child:GetBoundingBox().Position
					if (Vector3.new(middle.X, 0, middle.Z) - Vector3.new(entry.x, 0, entry.z)).Magnitude <= 0.5 then
						count += 1
					end
				end
			end
			return count
		end

		local found = {}
		local expected = {}
		for _, entry in removedProps do
			local label = string.format("%s at (%.1f, %.1f)", entry.name, entry.x, entry.z)
			table.insert(found, {
				prop = label,
				inMeadow = countAt(nature, entry),
				inRemovedNature = countAt(removedNature :: Instance, entry),
			})
			table.insert(expected, { prop = label, inMeadow = 0, inRemovedNature = 1 })
		end
		-- Nothing else was taken away. (One yellow flower, 24 down to 23, stood in the way of the moved teacup and
		-- went to RemovedNature too: tools/world/02b-garden-extras.luau step 3, Tasks 4e3 and 4f.)
		local left: { [string]: number } = { Nature_Sunflower = 0, Inno_White_Flowers = 0, Inno_Yellow_Flowers = 0 }
		for _, child in nature:GetChildren() do
			if child:IsA("Model") and left[child.Name] ~= nil then
				left[child.Name] += 1
			end
		end
		expect({ props = found, left = left }).toEqual({
			props = expected,
			left = { Nature_Sunflower = 23, Inno_White_Flowers = 21, Inno_Yellow_Flowers = 23 },
		})
	end)
end)
