--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Helpers = require(script.Parent.Helpers)
local flat = Helpers.flat

-- The places where eggs sit at home (Task 38). Each garden has a HomeSpots folder with 12 invisible parts, built by
-- tools/world/07-home-spots.luau: 1 to 6 on the pet pads, 7 to 12 in two short rows beside the incubator and the cash
-- chest. The top centre of a spot is where a home egg's bottom sits. These tests only READ the real world.
describe("the real world, home spots", function()
	local Workspace = game:GetService("Workspace")

	local SPOT_COUNT = 12
	local PAD_COUNT = 6
	local SPOT_SIZE = Vector3.new(2, 0.2, 2)
	-- An egg standing on a spot: the widest egg (Rare) is about 5.9 across and the tallest is 7.0, so this box holds any
	-- of them. It starts a little above the spot, so the spot's own thickness is not "in the way".
	local EGG_BOX = Vector3.new(6, 7, 6)
	local EGG_BOX_LIFT = 0.1
	local STAND_LIMIT = 0.3 -- studs: how far the ground may be from the top of a spot
	local MAX_SLOPE_DEGREES = 10
	local MIN_SPACING = 6.5 -- studs between the middles of two spots: even two Rare eggs don't touch
	local WALKWAY_HALF_WIDTH = 8 -- studs each side of the line from the gate into the garden that stay free of spots

	local function loadGardens(): { WorldIndex.Garden }
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local gardens, problems = WorldIndex.readGardens(world :: Instance)
		expect(problems).toEqual({})
		return gardens :: { WorldIndex.Garden }
	end

	-- The top centre of a spot: where a home egg's bottom sits.
	local function topOf(spot: BasePart): Vector3
		return spot.Position + spot.CFrame.UpVector * (spot.Size.Y / 2)
	end

	-- A ray that comes down onto the top of a spot, skipping everything a player walks through (flowers, stones).
	-- With `onlyThese` it can only hit those parts, so a pad's own walk surface can be found.
	local function groundBelow(top: Vector3, onlyThese: { Instance }?): RaycastResult?
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		if onlyThese then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = onlyThese
		end
		return Workspace:Raycast(top + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
	end

	it("every garden has 12 home spots: invisible, flat, anchored 2 by 0.2 by 2 parts that nothing touches", function()
		for _, garden in loadGardens() do
			expect({ garden = garden.index, spots = #garden.homeSpots }).toEqual({
				garden = garden.index,
				spots = SPOT_COUNT,
			})
			for number, spot in garden.homeSpots do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				expect({ label = label, name = spot.Name }).toEqual({ label = label, name = `HomeSpot_{number}` })
				expect({ label = label, parent = spot.Parent and spot.Parent.Name }).toEqual({
					label = label,
					parent = "HomeSpots",
				})
				expect({ label = label, size = spot.Size }).toEqual({ label = label, size = SPOT_SIZE })
				expect({ label = label, transparency = spot.Transparency }).toEqual({ label = label, transparency = 1 })
				expect({
					label = label,
					anchored = spot.Anchored,
					canCollide = spot.CanCollide,
					canQuery = spot.CanQuery,
					canTouch = spot.CanTouch,
					castShadow = spot.CastShadow,
				}).toEqual({
					label = label,
					anchored = true,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					castShadow = false,
				})
				-- it lies flat: its up direction is straight up
				expect({ label = label, flat = spot.CFrame.UpVector.Y > 0.9999 }).toEqual({ label = label, flat = true })
			end
		end
	end)

	it("home spots 1 to 6 each sit on their own pet pad, on its walk surface", function()
		for _, garden in loadGardens() do
			for number = 1, PAD_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local spot = garden.homeSpots[number]
				local pad = garden.petPads[number]
				local top = topOf(spot)
				-- inside the pad's footprint
				local boxCFrame, boxSize = pad:GetBoundingBox()
				local inPad = boxCFrame:PointToObjectSpace(top)
				expect({
					label = label,
					inside = math.abs(inPad.X) <= boxSize.X / 2 and math.abs(inPad.Z) <= boxSize.Z / 2,
				}).toEqual({ label = label, inside = true })
				-- the top is within 0.3 studs of what a ray that only hits this pad finds under it
				local onlyThisPad: { Instance } = { pad }
				local hit = groundBelow(top, onlyThisPad)
				expect({ label = label, found = hit ~= nil }).toEqual({ label = label, found = true })
				local gap = math.abs(top.Y - (hit :: RaycastResult).Position.Y)
				expect({ label = label, onSurface = gap <= STAND_LIMIT }).toEqual({ label = label, onSurface = true })
			end
		end
	end)

	it("home spots 7 to 12 are inside the garden box, on flat ground a player can stand on", function()
		local maxSlope = math.cos(math.rad(MAX_SLOPE_DEGREES))
		for _, garden in loadGardens() do
			for number = PAD_COUNT + 1, SPOT_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local top = topOf(garden.homeSpots[number])
				local local_ = garden.box.cframe:PointToObjectSpace(top)
				local half = garden.box.size / 2
				expect({
					label = label,
					inside = math.abs(local_.X) <= half.X
						and math.abs(local_.Y) <= half.Y
						and math.abs(local_.Z) <= half.Z,
				}).toEqual({ label = label, inside = true })
				local hit = groundBelow(top, nil)
				expect({ label = label, found = hit ~= nil }).toEqual({ label = label, found = true })
				local ground = hit :: RaycastResult
				expect({ label = label, near = math.abs(ground.Position.Y - top.Y) <= STAND_LIMIT }).toEqual({
					label = label,
					near = true,
				})
				expect({ label = label, flatEnough = ground.Normal.Y >= maxSlope }).toEqual({
					label = label,
					flatEnough = true,
				})
			end
		end
	end)

	it("no two home spots in a garden are closer than 6.5 studs", function()
		for _, garden in loadGardens() do
			for first = 1, SPOT_COUNT do
				for second = first + 1, SPOT_COUNT do
					local distance = (flat(garden.homeSpots[first].Position) - flat(garden.homeSpots[second].Position)).Magnitude
					expect({ garden = garden.index, first = first, second = second, apart = distance >= MIN_SPACING }).toEqual({
						garden = garden.index,
						first = first,
						second = second,
						apart = true,
					})
				end
			end
		end
	end)

	it("an egg standing on any home spot touches nothing solid", function()
		for _, garden in loadGardens() do
			for number, spot in garden.homeSpots do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local params = OverlapParams.new()
				params.RespectCanCollide = true
				-- An egg on a pad stands in the pad's dish, whose rim rises above the walk surface: its own pad is not "in the
				-- way" (every other pad is).
				if number <= PAD_COUNT then
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { garden.petPads[number] }
				end
				local eggBox = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + EGG_BOX_LIFT + EGG_BOX.Y / 2, 0)
				local touching: { string } = {}
				for _, part in Workspace:GetPartBoundsInBox(eggBox, EGG_BOX, params) do
					table.insert(touching, part:GetFullName())
				end
				expect({ label = label, touching = touching }).toEqual({ label = label, touching = {} })
			end
		end
	end)

	it("home spots 7 to 12 keep a clear walkway from the gate into the garden", function()
		for _, garden in loadGardens() do
			local gate = flat(garden.gate:GetPivot().Position)
			local centre = flat(garden.box.cframe.Position)
			local line = centre - gate
			for number = PAD_COUNT + 1, SPOT_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local fromGate = flat(garden.homeSpots[number].Position) - gate
				local along = math.clamp(fromGate:Dot(line) / line:Dot(line), 0, 1)
				local distance = (fromGate - line * along).Magnitude
				expect({ label = label, clear = distance >= WALKWAY_HALF_WIDTH }).toEqual({
					label = label,
					clear = true,
				})
			end
		end
	end)

	it("spots 7 to 12 are in the same places in every garden, measured from the garden's own box", function()
		local gardens = loadGardens()
		local first = gardens[1]
		for _, garden in gardens do
			for number = PAD_COUNT + 1, SPOT_COUNT do
				local label = `Plot_{garden.index}.HomeSpot_{number}`
				local mine = garden.box.cframe:PointToObjectSpace(garden.homeSpots[number].Position)
				local theirs = first.box.cframe:PointToObjectSpace(first.homeSpots[number].Position)
				expect({ label = label, same = (flat(mine) - flat(theirs)).Magnitude < 0.05 }).toEqual({
					label = label,
					same = true,
				})
			end
		end
	end)
end)
