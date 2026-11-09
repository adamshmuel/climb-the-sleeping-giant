--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local PlayerNeeds = require(ServerStorage.Tests.server.World.PlayerNeeds)
local Helpers = require(script.Parent.Helpers)
type ClosedFacts = Helpers.ClosedFacts
type ClosedSpot = Helpers.ClosedSpot
type Place = Helpers.Place
type RareFacts = Helpers.RareFacts
type RareSpot = Helpers.RareSpot
local CLOSED_RAY_LENGTH = Helpers.CLOSED_RAY_LENGTH
local CLOSED_TILT_DEGREES = Helpers.CLOSED_TILT_DEGREES
local RARE_MATCH = Helpers.RARE_MATCH
local RARE_PROOF = Helpers.RARE_PROOF
local closedBrokenConditions = Helpers.closedBrokenConditions
local closedRayDirections = Helpers.closedRayDirections
local escapingRays = Helpers.escapingRays
local linkedInto = Helpers.linkedInto
local placesInHollow = Helpers.placesInHollow
local rareBrokenConditions = Helpers.rareBrokenConditions
local rareSpot = Helpers.rareSpot
local unlistedSpots = Helpers.unlistedSpots
local unlistedStuck = Helpers.unlistedStuck

-- Stuck safety Task 23, test 1's made-up-world tests: the rare-spot check must be able to fail. The made-up world has
-- one place players need at its centre, a Meadow zone below y 0, and a list of positions the walk map reaches.
describe("the rare-spot check on a made-up world", function()
	local PLACE = Vector3.new(0, 0, 0)

	local function madeUpFacts(reached: { Vector3 }): RareFacts
		return {
			isMeadow = function(position: Vector3): boolean
				return position.Y < 0
			end,
			distanceToPlace = function(position: Vector3): number
				return (position - PLACE).Magnitude
			end,
			reachedFromPlaces = function(position: Vector3): boolean
				for _, spot in reached do
					if (spot - position).Magnitude <= RARE_MATCH then
						return true
					end
				end
				return false
			end,
		}
	end

	local function listed(name: string, position: Vector3): RareSpot
		return { name = name, group = 1, position = position, proof = RARE_PROOF }
	end

	local function has(text: string, part: string): boolean
		return string.find(text, part, 1, true) ~= nil
	end

	it("a stuck spot that is not on the rare list fails", function()
		local onList = Vector3.new(0, 30, 0)
		local notOnList = Vector3.new(4, 30, 4)
		local unlisted = unlistedSpots({ onList, notOnList }, { listed("Rare_Made_Up_1", onList) })
		expect(unlisted).toEqual({ 2 })
	end)

	it("a listed rare spot within 12 studs of a place players need fails", function()
		local near = madeUpFacts({})
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 11.9, 0)) }, near)
		expect(#problems).toBe(1)
		expect(has(problems[1], "Rare_Made_Up_1")).toBe(true)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
		-- Just past 12 studs, nothing is wrong.
		expect(rareBrokenConditions({ listed("Rare_Made_Up_2", Vector3.new(0, 12.1, 0)) }, near)).toEqual({})
	end)

	-- The places players need come from a made-up world: a model with a WalkSurfaces folder, and the seam's folder.
	-- Nothing else (no route, egg spots or landing spots).
	local function factsFromMadeUpWorld(build: (world: Model) -> ()): RareFacts
		local world = Instance.new("Model")
		world.Name = "MadeUpPlacesWorld"
		build(world)
		local needs = PlayerNeeds.build(world, {}, {}, {})
		world:Destroy()
		return {
			isMeadow = function(): boolean
				return false
			end,
			distanceToPlace = function(position: Vector3): number
				return PlayerNeeds.nearestDistance(needs, position)
			end,
			reachedFromPlaces = function(): boolean
				return false
			end,
		}
	end

	local function addPiece(parent: Instance, name: string, position: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(4, 1, 10)
		part.Position = position
		part.Parent = parent
	end

	local function folderIn(parent: Instance, name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end

	it("a listed rare spot within 12 studs of a Belly_Walk piece fails", function()
		local facts = factsFromMadeUpWorld(function(world)
			addPiece(folderIn(world, "WalkSurfaces"), "Belly_Walk", Vector3.new(0, 50, 0))
		end)
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 60, 0)) }, facts)
		expect(#problems).toBe(1)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
		-- 20 studs from the piece's top is far enough.
		expect(rareBrokenConditions({ listed("Rare_Made_Up_2", Vector3.new(0, 71, 0)) }, facts)).toEqual({})
	end)

	it("a listed rare spot within 12 studs of a cuff ledge fails", function()
		local facts = factsFromMadeUpWorld(function(world)
			folderIn(world, "WalkSurfaces")
			addPiece(folderIn(world, "CuffWalk"), "Ledge_1", Vector3.new(0, 50, 0))
		end)
		-- The piece is 1 stud thick, so its top is at 50.5: 10 studs below this spot.
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 60.5, 0)) }, facts)
		expect(#problems).toBe(1)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
		-- 20 studs from the piece's top is far enough.
		expect(rareBrokenConditions({ listed("Rare_Made_Up_2", Vector3.new(0, 71, 0)) }, facts)).toEqual({})
	end)

	it("a listed rare spot within 12 studs of a seam piece fails", function()
		local facts = factsFromMadeUpWorld(function(world)
			addPiece(folderIn(world, "Seam"), "Stitch_1", Vector3.new(0, 50, 0))
		end)
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, 60, 0)) }, facts)
		expect(#problems).toBe(1)
		expect(has(problems[1], "studs from a place players need")).toBe(true)
	end)

	it("a steep-layer piece is not a place players need, and steepLayer still returns it", function()
		local world = Instance.new("Model")
		world.Name = "MadeUpSteepWorld"
		addPiece(folderIn(world, "SteepLayer"), "Steep_Made_Up_1", Vector3.new(0, 50, 0))
		local needs = PlayerNeeds.build(world, {}, {}, {})
		local steep = PlayerNeeds.steepLayer(world)
		world:Destroy()
		for _, need in needs do
			expect(has(need.name, "SteepLayer")).toBe(false)
		end
		expect(#steep).toBe(1)
		expect(has(steep[1].name, "SteepLayer Steep_Made_Up_1")).toBe(true)
	end)

	it("a listed rare spot the walk map reaches from the places fails", function()
		local spot = Vector3.new(0, 30, 0)
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", spot) }, madeUpFacts({ spot }))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Rare_Made_Up_1")).toBe(true)
		expect(has(problems[1], "walk map reaches it")).toBe(true)
	end)

	it("a listed rare spot in the Meadow zone fails", function()
		local problems = rareBrokenConditions({ listed("Rare_Made_Up_1", Vector3.new(0, -30, 0)) }, madeUpFacts({}))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Rare_Made_Up_1")).toBe(true)
		expect(has(problems[1], "Meadow zone")).toBe(true)
	end)

	it("a listed rare spot that meets all three passes", function()
		local spot = Vector3.new(0, 30, 0)
		local elsewhere = Vector3.new(0, 20, 0)
		expect(rareBrokenConditions({ listed("Rare_Made_Up_1", spot) }, madeUpFacts({ elsewhere }))).toEqual({})
		expect(unlistedSpots({ spot }, { listed("Rare_Made_Up_1", spot) })).toEqual({})
	end)
end)

-- Stuck safety Task 23, test 1's closed-void tests on a made-up world: the closed check must be able to fail. The made-up
-- world is a hollow box of walls in a WorldModel (it answers rays like the real Workspace). The inside of the box is
-- 12 studs wide in x and z, and its floor's top is y 0, where the feet stand.
describe("the closed-void check on a made-up world", function()
	local HALF = 6 -- studs: half the inside width
	local WALL = 1 -- studs thick
	local world: WorldModel

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Name = "ClosedVoidTestWorld"
		world.Archivable = false -- a test world is never saved with the place, even if a test crashes
		world.Parent = ServerStorage
	end)

	afterEach(function()
		local made = world :: WorldModel? -- nil if the first beforeEach failed before it made the world
		if made ~= nil then
			made:Destroy()
		end
	end)

	local function wall(name: string, size: Vector3, center: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.Position = center
		part.Parent = world
	end

	-- A hollow box with a floor, a roof and four side walls (the walls overlap at the corners, so there is no gap).
	-- `height` is the inside height. `leaveOut` names a side that gets no wall: "+x", "-x", "+z" or "-z".
	local function hollowBox(height: number, leaveOut: string?)
		local across = 2 * (HALF + WALL)
		local tall = height + 2 * WALL
		local middle = height / 2
		wall("Floor", Vector3.new(across, WALL, across), Vector3.new(0, -WALL / 2, 0))
		wall("Roof", Vector3.new(across, WALL, across), Vector3.new(0, height + WALL / 2, 0))
		local out = HALF + WALL / 2
		if leaveOut ~= "+x" then
			wall("SideEast", Vector3.new(WALL, tall, across), Vector3.new(out, middle, 0))
		end
		if leaveOut ~= "-x" then
			wall("SideWest", Vector3.new(WALL, tall, across), Vector3.new(-out, middle, 0))
		end
		if leaveOut ~= "+z" then
			wall("SideSouth", Vector3.new(across, tall, WALL), Vector3.new(0, middle, out))
		end
		if leaveOut ~= "-z" then
			wall("SideNorth", Vector3.new(across, tall, WALL), Vector3.new(0, middle, -out))
		end
	end

	local function cast(origin: Vector3, direction: Vector3): RaycastResult?
		return world:Raycast(origin, direction)
	end

	local function inWorld(instance: Instance): boolean
		return instance:IsDescendantOf(world)
	end

	local function link(to: number): PathCheck.Link
		return { to = to, kind = "Walk", length = 1, seconds = 1 }
	end

	local function closedAt(name: string, position: Vector3): ClosedSpot
		return { name = name, position = position, piece = "made_up_piece" }
	end

	local function has(text: string, part: string): boolean
		return string.find(text, part, 1, true) ~= nil
	end

	-- What a world with these answers says about one listed spot.
	local function facts(escaping: number, linked: boolean, place: string?): ClosedFacts
		return {
			escapingRays = function(): number
				return escaping
			end,
			linkedFromOutside = function(): boolean
				return linked
			end,
			placeInside = function(): string?
				return place
			end,
		}
	end

	it("the closed check casts 8 level, 8 tilted and 1 straight up ray of 40 studs", function()
		local level, tilted, up = 0, 0, 0
		local directions = closedRayDirections()
		for _, direction in directions do
			expect(math.abs(direction.Magnitude - CLOSED_RAY_LENGTH) < 1e-6).toBe(true)
			if math.abs(direction.Y) < 1e-6 then
				level += 1
			elseif math.abs(direction.Y - CLOSED_RAY_LENGTH) < 1e-6 then
				up += 1
			elseif math.abs(direction.Y - CLOSED_RAY_LENGTH * math.sin(math.rad(CLOSED_TILT_DEGREES))) < 1e-6 then
				tilted += 1
			end
		end
		expect({ #directions, level, tilted, up }).toEqual({ 17, 8, 8, 1 })
	end)

	it("a sealed box has no ray that gets out", function()
		hollowBox(12, nil)
		expect(escapingRays(Vector3.zero, cast, inWorld)).toBe(0)
	end)

	it("a box with one open side lets the rays toward that side out", function()
		hollowBox(12, "+x")
		-- The level ray and the tilted ray on heading 0 (toward +x) leave. The tilted ray on each diagonal still
		-- meets a side wall, because the box is 12 tall.
		expect(escapingRays(Vector3.zero, cast, inWorld)).toBe(2)
	end)

	it("under a roof lower than 2.8 studs the rays start 1 stud over the feet", function()
		-- The roof's underside is 2.2 over the feet and the roof is 1 thick, so a start 2.5 over the feet would be
		-- inside the roof, and every ray that goes up would get out above it.
		hollowBox(2.2, nil)
		expect(escapingRays(Vector3.zero, cast, inWorld)).toBe(0)
	end)

	it("a place inside the hollow is found, and a place behind a wall is not", function()
		hollowBox(12, nil)
		local places: { Place } = {
			{ name = "Inside_EggSpot", position = Vector3.new(3, 0, 3) },
			{ name = "Outside_RoutePoint", position = Vector3.new(20, 0, 0) },
		}
		expect(placesInHollow(Vector3.zero, places, cast)).toEqual({ "Inside_EggSpot" })
	end)

	it("a place in the open air beside an open box is in the same air", function()
		hollowBox(12, "+x")
		local places: { Place } = { { name = "Outside_LandingSpot", position = Vector3.new(20, 0, 0) } }
		expect(placesInHollow(Vector3.zero, places, cast)).toEqual({ "Outside_LandingSpot" })
	end)

	it("a link from outside into the hollow is found, and a link inside it is not", function()
		local inside = { [2] = true, [3] = true }
		expect(linkedInto({ [1] = { link(2) }, [2] = { link(3) }, [4] = { link(3) } }, inside)).toEqual({
			[2] = true,
			[3] = true,
		})
		expect(linkedInto({ [2] = { link(3) }, [3] = { link(2) } }, inside)).toEqual({})
	end)

	it("a listed closed spot that has opened fails", function()
		local problems = closedBrokenConditions({ closedAt("Closed_Made_Up_1", Vector3.zero) }, facts(2, false, nil))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Closed_Made_Up_1")).toBe(true)
		expect(has(problems[1], "2 of 17 rays")).toBe(true)
	end)

	it("a listed closed spot that a link from outside leads into fails", function()
		local problems = closedBrokenConditions({ closedAt("Closed_Made_Up_1", Vector3.zero) }, facts(0, true, nil))
		expect(#problems).toBe(1)
		expect(has(problems[1], "Closed_Made_Up_1")).toBe(true)
		expect(has(problems[1], "link")).toBe(true)
	end)

	it("a listed closed spot with a place players need inside its hollow fails", function()
		local problems = closedBrokenConditions(
			{ closedAt("Closed_Made_Up_1", Vector3.zero) },
			facts(0, false, "RoutePoint_Made_Up")
		)
		expect(#problems).toBe(1)
		expect(has(problems[1], "Closed_Made_Up_1")).toBe(true)
		expect(has(problems[1], "RoutePoint_Made_Up")).toBe(true)
	end)

	it("a listed closed spot that is still closed, unlinked and empty passes", function()
		expect(closedBrokenConditions({ closedAt("Closed_Made_Up_1", Vector3.zero) }, facts(0, false, nil))).toEqual({})
	end)

	it("a stuck spot on the closed list is not unlisted, and one on neither list is", function()
		local onRare = Vector3.new(0, 30, 0)
		local onClosed = Vector3.new(4, 30, 4)
		local onNeither = Vector3.new(8, 30, 8)
		local unlisted = unlistedStuck(
			{ onRare, onClosed, onNeither },
			{ rareSpot("Rare_Made_Up_1", 1, 0, 30, 0) },
			{ closedAt("Closed_Made_Up_1", onClosed) },
			{}
		)
		expect(unlisted).toEqual({ 3 })
	end)

	-- Spec Rule 22, "Accepted for now: the beard wedge", condition 1: the scan fails if any other spot joins it.
	it("a stuck spot on the accepted-for-now list is not unlisted, and one a grid step beside it is", function()
		local accepted = Helpers.ACCEPTED_FOR_NOW[1].position
		local beside = accepted + Vector3.new(2, 0, 0) -- the scan's grid step is 2 studs
		local unlisted = unlistedStuck({ accepted, beside }, {}, {}, Helpers.ACCEPTED_FOR_NOW)
		expect(unlisted).toEqual({ 2 })
	end)
end)
