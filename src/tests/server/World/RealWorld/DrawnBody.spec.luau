--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local Collisions = require(ServerScriptService.Server.Players.Collisions)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local DrawnSkin = require(game:GetService("ServerStorage").Tests.server.World.DrawnSkin)
local Helpers = require(script.Parent.Helpers)
local ABOVE_LIMIT = Helpers.ABOVE_LIMIT
local BELOW_LIMIT = Helpers.BELOW_LIMIT
local BODY_PIECES = Helpers.BODY_PIECES
local SKIN_SEARCH_ABOVE = Helpers.SKIN_SEARCH_ABOVE
local SKIN_SIDE_REACH = Helpers.SKIN_SIDE_REACH
local describePoint = Helpers.describePoint
local outsideLimits = Helpers.outsideLimits
local realWorld = Helpers.realWorld
local sidewaysFit = Helpers.sidewaysFit

-- Stuck safety Task 26: his solid shape sits on his drawn skin (docs/plans/v2/stuck-safety.md, Task 26; spec 2 Rule 20,
-- "One collision source", check 6). His solid shape is what a player stands on. His drawn skin is the mesh Roblox
-- paints, plus any shirt folds (see DrawnSkin). Wherever a player can stand on his six body pieces, the solid shape may
-- be at most 0.2 studs above the drawn skin and 0.3 studs below it. These tests only READ the world (the two "can fail"
-- tests move one spot in memory, or one clone of the truss, and destroy it again).
describe("the real world, his solid body sits where he's drawn", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")

	local GRID_STEP = 1 -- studs: the spots checked are this far apart, on a grid over the whole giant
	local MAX_SURFACES = 200 -- most surfaces one column can have (a safety stop, as in PathCheck)
	local RAY_RESTART = 0.01 -- studs: the next ray down a column starts this far below the last surface it hit
	local COLUMNS_PER_YIELD = 200 -- the scan lets Studio breathe this often
	local SPOT_RAY_ABOVE = 3 -- studs: a spot's ray starts this far over it
	local SPOT_RAY_BELOW = 5 -- studs: ...and the spot is "on his body" if the ray hits it within this far under it
	local MAX_EXAMPLES = 3 -- most examples written out for each piece
	local BUILD_TIMEOUT_MS = 60000 -- reading the six meshes takes a few seconds
	local TEST_TIMEOUT_MS = 60000
	-- Task 24's belly-top climb: a player stands here (x, z) and walks into the beard ladder's climbing truss, `Climb`.
	-- It is where V1's truss foot is.
	local BELLY_TOP_X = 0
	local BELLY_TOP_Z = -24.5
	local MIN_TRUSS_OVERLAP = 1 -- studs: a standing player's head reaches this far into the truss
	local FOOTPRINT_STEP = 0.25 -- studs between the places under a standing player's body that are read

	local skin: DrawnSkin.Skin = nil :: any

	local function bodyMeshes(): { MeshPart }
		local giant = realWorld():FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local meshes: { MeshPart } = {}
		for _, name in BODY_PIECES do
			local model = (giant :: Instance):FindFirstChild(name)
			expect(model).never.toBeNil()
			local mesh = (model :: Instance):FindFirstChild(name)
			expect(mesh).never.toBeNil()
			expect((mesh :: Instance):IsA("MeshPart")).toBe(true)
			table.insert(meshes, mesh :: MeshPart)
		end
		return meshes
	end

	-- The shirt folds: soft blocks and wedges in World.Giant.ShirtFolds that players pass through (none until Task 26
	-- adds them).
	local function shirtFolds(): { BasePart }
		local giant = realWorld():FindFirstChild("Giant")
		local folder = if giant then giant:FindFirstChild("ShirtFolds") else nil
		local folds: { BasePart } = {}
		if folder then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(folds, descendant)
				end
			end
		end
		return folds
	end

	-- A ray that sees only his solid shape (the six body pieces).
	local function bodyParams(meshes: { MeshPart }): RaycastParams
		local included: { Instance } = {}
		for _, mesh in meshes do
			table.insert(included, mesh)
		end
		local params = RaycastParams.new()
		params.IncludeInstances = included
		params.RespectCanCollide = false
		return params
	end

	-- The box that holds all of the given parts, as (lowest corner, highest corner).
	local function boundsOf(parts: { MeshPart }): (Vector3, Vector3)
		local low = Vector3.new(math.huge, math.huge, math.huge)
		local high = -low
		for _, part in parts do
			local right, up, look = part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector
			local size = part.Size
			local reach = Vector3.new(
				(math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z) / 2,
				(math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z) / 2,
				(math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z) / 2
			)
			low = low:Min(part.Position - reach)
			high = high:Max(part.Position + reach)
		end
		return low, high
	end

	-- gap: solid shape height minus drawn skin height straight under the spot. sideways: only set when that gap is outside
	-- the limits but the drawn skin within SKIN_SIDE_REACH studs sideways fits them (product's measuring rule, check 6):
	-- then it is the gap to that skin. (The limits and the search are at the top of this file.)
	type Gap = { piece: string, position: Vector3, gap: number, sideways: number? }

	-- A spot fails outright when neither the skin under it nor the skin within SKIN_SIDE_REACH sideways fits the limits.
	local function failsOutright(entry: Gap): boolean
		return outsideLimits(entry.gap) and entry.sideways == nil
	end

	-- A spot passes only because of the sideways search when the skin under it does not fit but the skin beside it does.
	local function passesBySideways(entry: Gap): boolean
		return outsideLimits(entry.gap) and entry.sideways ~= nil
	end

	-- Every place a player can stand on his body, on a 1-stud grid over the giant. It follows the game's own walk map
	-- (PathCheck.findSpots): a ray down each column through every surface of his six pieces; a surface counts when its
	-- slope is under the walking limit and a player's body fits standing on it (PathCheck.roomToStand), which also drops
	-- the faces hidden inside his solid shape. `gap` is NaN where no drawn skin is under the spot at all.
	local function standableGaps(): ({ Gap }, number)
		local meshes = bodyMeshes()
		local params = bodyParams(meshes)
		local low, high = boundsOf(meshes)
		local options = PathCheck.defaults(Workspace)
		local walkable = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
		local gaps: { Gap } = {}
		local columns = 0
		for x = math.floor(low.X) + GRID_STEP / 2, high.X, GRID_STEP do
			for z = math.floor(low.Z) + GRID_STEP / 2, high.Z, GRID_STEP do
				local startY = high.Y + 1
				for _ = 1, MAX_SURFACES do
					local hit =
						Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -(startY - low.Y + 1), 0), params)
					if hit == nil then
						break
					end
					if hit.Normal.Y >= walkable and PathCheck.roomToStand(options, hit.Position, hit.Normal) then
						local drawn = skin.heightAt(x, z, hit.Position.Y + SKIN_SEARCH_ABOVE)
						local gap = if drawn == nil then 0 / 0 else hit.Position.Y - drawn
						table.insert(gaps, {
							piece = hit.Instance.Name,
							position = hit.Position,
							gap = gap,
							sideways = if outsideLimits(gap) then sidewaysFit(skin, x, z, hit.Position.Y) else nil,
						})
					end
					startY = hit.Position.Y - RAY_RESTART
				end
				columns += 1
				if columns % COLUMNS_PER_YIELD == 0 then
					task.wait()
				end
			end
		end
		PathCheck.cleanup(options)
		return gaps, #gaps
	end

	local allGaps: { Gap } = {}
	local allSpots = 0

	-- How many spots pass only because of the sideways search, and the worst of them (the one furthest outside the
	-- limits straight under it), as a sentence for the report.
	local function sidewaysSummary(gaps: { Gap }): string
		local count = 0
		local worst: Gap? = nil
		local worstOutside = -1
		for _, entry in gaps do
			if passesBySideways(entry) then
				count += 1
				local outside = if entry.gap ~= entry.gap
					then math.huge
					elseif entry.gap > 0 then entry.gap - ABOVE_LIMIT
					else -BELOW_LIMIT - entry.gap
				if outside > worstOutside then
					worstOutside = outside
					worst = entry
				end
			end
		end
		if worst == nil then
			return `none pass only because of the {SKIN_SIDE_REACH}-stud sideways search`
		end
		local example = worst :: Gap
		return `{count} more pass only because of the {SKIN_SIDE_REACH}-stud sideways search (worst: {describePoint(
			example.position
		)} is {string.format("%+.2f", example.gap)} over the skin under it and {string.format(
			"%+.2f",
			example.sideways :: number
		)} over the skin beside it)`
	end

	beforeAll(function()
		skin = DrawnSkin.fromWorld(bodyMeshes(), shirtFolds())
		allGaps, allSpots = standableGaps()
	end, BUILD_TIMEOUT_MS)

	type PieceTally = {
		over: number,
		under: number,
		noSkin: number,
		worstOver: Gap?,
		worstUnder: Gap?,
		examples: { string },
	}

	-- The problems, one line per piece that has any, with its worst spots and the first few.
	local function gapProblems(gaps: { Gap }): { string }
		local tallies: { [string]: PieceTally } = {}
		for _, entry in gaps do
			if failsOutright(entry) then
				local tally = tallies[entry.piece]
				if tally == nil then
					tally = { over = 0, under = 0, noSkin = 0, examples = {} }
					tallies[entry.piece] = tally
				end
				local current = tally :: PieceTally
				if entry.gap ~= entry.gap then
					current.noSkin += 1
				elseif entry.gap > 0 then
					current.over += 1
					if current.worstOver == nil or entry.gap > (current.worstOver :: Gap).gap then
						current.worstOver = entry
					end
				else
					current.under += 1
					if current.worstUnder == nil or entry.gap < (current.worstUnder :: Gap).gap then
						current.worstUnder = entry
					end
				end
				if #current.examples < MAX_EXAMPLES then
					table.insert(
						current.examples,
						`{describePoint(entry.position)} {string.format("%+.2f", entry.gap)}`
					)
				end
			end
		end
		local problems: { string } = {}
		for _, name in BODY_PIECES do
			local tally = tallies[name]
			if tally then
				local parts: { string } = {}
				if tally.over > 0 then
					local worst = tally.worstOver :: Gap
					table.insert(
						parts,
						`{tally.over} over (worst {string.format("%+.2f", worst.gap)} at {describePoint(worst.position)})`
					)
				end
				if tally.under > 0 then
					local worst = tally.worstUnder :: Gap
					table.insert(
						parts,
						`{tally.under} under (worst {string.format("%+.2f", worst.gap)} at {describePoint(
							worst.position
						)})`
					)
				end
				if tally.noSkin > 0 then
					table.insert(parts, `{tally.noSkin} with no drawn skin under them`)
				end
				table.insert(
					problems,
					`{name}: {table.concat(parts, ", ")}; first: {table.concat(tally.examples, ", ")}`
				)
			end
		end
		return problems
	end

	it("his solid shape is at most 0.2 over and 0.3 under his drawn skin everywhere a player can stand", function()
		expect(allSpots > 1000).toBe(true) -- the grid really found his body
		local bad = 0
		for _, entry in allGaps do
			if failsOutright(entry) then
				bad += 1
			end
		end
		local summary = `{bad} of {allSpots} standable spots fail outright; {sidewaysSummary(allGaps)}`
		print("check 6: " .. summary) -- both counts show even when the test passes
		local problems = gapProblems(allGaps)
		if #problems > 0 then
			table.insert(problems, 1, summary)
		end
		expect(problems).toEqual({})
	end, TEST_TIMEOUT_MS)

	-- Proof that the sideways search bites (product's measuring rule, check 6). A made-up skin has a step: flat at height
	-- 1 for x under 0 and flat at height 0 from x 0 on. A spot 0.2 from the step, with the solid shape 1.1 high, is far
	-- above the low skin under it but fits the high skin beside it, so it passes by the sideways search. A spot 0.5 from
	-- the step has no fitting skin within 0.3, and a spot with the solid shape 3 high fits nowhere.
	describe("the sideways search", function()
		local function flat(x0: number, x1: number, height: number): { DrawnSkin.Triangle }
			local a, b = Vector3.new(x0, height, -10), Vector3.new(x1, height, -10)
			local c, d = Vector3.new(x1, height, 10), Vector3.new(x0, height, 10)
			return { { a = a, b = b, c = c }, { a = a, b = c, c = d } }
		end

		local function steppedSkin(): DrawnSkin.Skin
			local triangles = flat(-10, 0, 1)
			for _, triangle in flat(0, 10, 0) do
				table.insert(triangles, triangle)
			end
			return DrawnSkin.new(triangles, {})
		end

		it("passes a spot whose own skin is far below but whose skin 0.2 beside it fits", function()
			local reader = steppedSkin()
			expect(outsideLimits(1.1 - (reader.heightAt(0.2, 0, 2) :: number))).toBe(true)
			local gap = sidewaysFit(reader, 0.2, 0, 1.1)
			expect(gap).never.toBeNil()
			expect(math.abs((gap :: number) - 0.1) < 0.001).toBe(true)
		end)

		it("fails a spot with no fitting skin within 0.3 sideways", function()
			expect(sidewaysFit(steppedSkin(), 0.5, 0, 1.1)).toBeNil()
		end)

		it("fails a spot whose solid shape is too high for any skin beside it", function()
			expect(sidewaysFit(steppedSkin(), 0.2, 0, 3)).toBeNil()
		end)

		it("counts a spot only once: outright failure and sideways pass are separate", function()
			local entry: Gap = { piece = "x", position = Vector3.zero, gap = 1.1, sideways = 0.1 }
			expect(passesBySideways(entry)).toBe(true)
			expect(failsOutright(entry)).toBe(false)
			entry.sideways = nil
			expect(passesBySideways(entry)).toBe(false)
			expect(failsOutright(entry)).toBe(true)
		end)
	end)

	-- Proof that the method reads his skin right: his left arm's solid shape follows its skin to 0.13 studs (measured
	-- in Task 25), so every standable spot on it must read within the limits. A wrong mapping of the mesh into the world
	-- (a turned, mirrored or mis-scaled skin) would fail this at once.
	it("reads the drawn skin of his left arm where its solid shape is", function()
		local checked = 0
		local outside: { string } = {}
		for _, entry in allGaps do
			if entry.piece == "left_arm" then
				checked += 1
				if failsOutright(entry) and #outside < MAX_EXAMPLES then
					table.insert(outside, `{describePoint(entry.position)} {string.format("%+.2f", entry.gap)}`)
				end
			end
		end
		expect(checked > 50).toBe(true)
		expect(outside).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Eggs, footprints and landing spots on his drawn skin
	----------------------------------------------------------------------------------------------------------------

	type Spot = { name: string, position: Vector3 }

	-- Every egg spot (the top of its Base), footprint route point and landing spot. Nests are added by plan 5.
	local function worldSpots(): { Spot }
		local world = realWorld()
		local spots: { Spot } = {}
		local eggSpots, eggProblems = WorldIndex.readEggSpots(world)
		expect(eggProblems).toEqual({})
		for _, spot in eggSpots :: { WorldIndex.EggSpot } do
			table.insert(spots, { name = spot.name, position = spot.cframe.Position })
		end
		local route, routeProblems = WorldIndex.readRoute(world)
		expect(routeProblems).toEqual({})
		for _, point in route :: { WorldIndex.RoutePoint } do
			table.insert(spots, { name = `route point {point.name}`, position = point.position })
		end
		local landings, landingProblems = WorldIndex.readLandingSpots(world)
		expect(landingProblems).toEqual({})
		for _, landing in landings :: { WorldIndex.LandingSpot } do
			table.insert(spots, { name = `LandingSpot_{landing.index}`, position = landing.position })
		end
		return spots
	end

	-- The spots that are on his body, and the problems with those. A spot is on his body when the first thing a player
	-- would stand on under it (a ray that sees what the Players group collides with) is one of his six pieces, within
	-- a few studs. A spot on a crossing ramp or a ladder is not: those float over his skin by design.
	local function spotProblems(spots: { Spot }): ({ string }, number)
		local meshes = bodyMeshes()
		local ground = RaycastParams.new()
		ground.RespectCanCollide = true
		ground.CollisionGroup = Collisions.GROUP
		local problems: { string } = {}
		local onBody = 0
		for _, spot in spots do
			local start = spot.position + Vector3.new(0, SPOT_RAY_ABOVE, 0)
			local hit = Workspace:Raycast(start, Vector3.new(0, -(SPOT_RAY_ABOVE + SPOT_RAY_BELOW), 0), ground)
			if hit and table.find(meshes, hit.Instance :: any) ~= nil then
				onBody += 1
				local drawn = skin.heightAt(spot.position.X, spot.position.Z, start.Y)
				if drawn == nil then
					table.insert(problems, `{spot.name} {describePoint(spot.position)}: no drawn skin under it`)
				else
					local gap = spot.position.Y - drawn
					if outsideLimits(gap) then
						table.insert(
							problems,
							`{spot.name} {describePoint(spot.position)}: {string.format("%+.2f", gap)} from his drawn skin`
						)
					end
				end
			end
		end
		return problems, onBody
	end

	it("eggs, footprints and landing spots on his body sit on his drawn skin", function()
		local problems, onBody = spotProblems(worldSpots())
		expect(onBody > 5).toBe(true) -- the Rare eggs, the belly route and the boots, at least
		expect(problems).toEqual({})
	end, TEST_TIMEOUT_MS)

	-- Proof that the test above can fail: one spot that passes, moved 0.5 studs up, and then 0.5 studs down.
	it("the spot check notices a spot 0.5 studs too high or too low", function()
		local sound: Spot? = nil
		for _, spot in worldSpots() do
			local problems, onBody = spotProblems({ spot })
			if onBody == 1 and #problems == 0 then
				sound = spot
				break
			end
		end
		expect(sound).never.toBeNil()
		local original = sound :: Spot
		local higher = spotProblems({ { name = original.name, position = original.position + Vector3.new(0, 0.5, 0) } })
		local lower = spotProblems({ { name = original.name, position = original.position - Vector3.new(0, 0.5, 0) } })
		expect({ higher = #higher, lower = #lower }).toEqual({ higher = 1, lower = 1 })
	end, TEST_TIMEOUT_MS)

	----------------------------------------------------------------------------------------------------------------
	-- The beard ladder is within reach of a player standing on his belly top
	----------------------------------------------------------------------------------------------------------------

	local function beardTruss(): BasePart
		local walk = realWorld():FindFirstChild("WalkSurfaces")
		expect(walk).never.toBeNil()
		local ladder = (walk :: Instance):FindFirstChild("BeardLadder")
		expect(ladder).never.toBeNil()
		local truss = (ladder :: Instance):FindFirstChild("Climb")
		expect(truss).never.toBeNil()
		return truss :: BasePart
	end

	-- Where his solid shape is at the belly-top spot: the height a player's feet stand at.
	local function bellyTopStandY(): number
		local meshes = bodyMeshes()
		local low, high = boundsOf(meshes)
		local hit = Workspace:Raycast(
			Vector3.new(BELLY_TOP_X, high.Y + 1, BELLY_TOP_Z),
			Vector3.new(0, -(high.Y - low.Y + 2), 0),
			bodyParams(meshes)
		)
		expect(hit).never.toBeNil()
		return (hit :: RaycastResult).Position.Y
	end

	-- How far a player's head, standing with feet at `standY`, reaches into the truss: the top of the body minus the
	-- lowest point of the truss anywhere over the body's footprint. Negative: the head is under the truss.
	local function trussOverlap(truss: BasePart, standY: number): number
		local solid = DrawnSkin.solidOf(truss)
		local half = Config.Stuck.BodyWidth / 2
		local lowest = math.huge
		for dx = -half, half, FOOTPRINT_STEP do
			for dz = -half, half, FOOTPRINT_STEP do
				local bottom = DrawnSkin.columnSpan(solid, BELLY_TOP_X + dx, BELLY_TOP_Z + dz)
				if bottom ~= nil then
					lowest = math.min(lowest, bottom)
				end
			end
		end
		return standY + Config.Stuck.BodyHeight - lowest
	end

	it("a player on his belly top can grab the beard ladder: his head reaches 1 stud into its truss", function()
		local overlap = trussOverlap(beardTruss(), bellyTopStandY())
		expect({ overlap = overlap, reaches = overlap >= MIN_TRUSS_OVERLAP }).toEqual({
			overlap = overlap,
			reaches = true,
		})
	end)

	-- Proof that the test above can fail: the same truss 3 studs higher is out of reach.
	it("the truss check notices a truss 3 studs too high", function()
		local standY = bellyTopStandY()
		local raised = beardTruss():Clone()
		raised.CFrame = raised.CFrame + Vector3.new(0, 3, 0)
		local realOverlap = trussOverlap(beardTruss(), standY)
		local raisedOverlap = trussOverlap(raised, standY)
		raised:Destroy()
		expect(realOverlap >= MIN_TRUSS_OVERLAP).toBe(true)
		expect(raisedOverlap < MIN_TRUSS_OVERLAP).toBe(true)
	end)
end)
