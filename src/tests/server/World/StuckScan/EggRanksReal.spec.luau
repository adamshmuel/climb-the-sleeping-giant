--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll = JestGlobals.beforeAll, JestGlobals.afterAll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local EggRanks = require(ServerScriptService.Server.World.EggRanks)
local EggRanksReport = require(ServerScriptService.Server.World.EggRanksReport)
local NestSeat = require(ServerScriptService.Server.World.NestSeat)
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local ReachCheck = require(ServerScriptService.Server.World.ReachCheck)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local SleepMeter = require(ServerScriptService.Server.Giant.SleepMeter)
local GiantPlaces = require(script.Parent.GiantPlaces)
local RealReach = require(script.Parent.RealReach)
local WaysUpRoutes = require(script.Parent.WaysUpRoutes)

type EggTool = {
	check: (input: any) -> (string, EggRanks.RunResult, { EggRanksReport.ReportRow }),
}

local SLIDE_GUARD_REACH = 2 -- studs: no scored step stands this close to a slide guard (game_creator, stuck safety Task 23)

-- Plan 4, Task 9b (spec 4 Rules 46, 54, 55, 59) on the real world: the egg check on all 38 nests, on its own even-row
-- walk map over WaysUpRoutes.EGG_AREA (the stuck scan's rows miss the lap planks). The setup is RealReach's, the
-- search is ReachCheck's, the judging is EggRanks', and the text is the egg-ranks tool's. The report and the seconds the
-- check took are printed for the review (the scan's seconds plus these must stay under 2 minutes, spec section 5).
describe("the egg check on the real world", function()
	local options: PathCheck.Options? = nil
	local setup: RealReach.Setup? = nil
	local world: Instance? = nil
	local spotCount = 0
	local spotProblems: { string } = {}
	local rows: { EggRanksReport.ReportRow } = {}
	local result: EggRanks.RunResult? = nil
	local results: { ReachCheck.NestResult } = {}
	local seconds = math.huge

	beforeAll(function()
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		world = found :: Instance
		local started = os.clock()
		local built = RealReach.build(found :: Instance, WaysUpRoutes.EGG_AREA, WaysUpRoutes.EGG_FINE_BOXES)
		setup = built
		options = built.options
		local reach: ReachCheck.Options = {
			map = built.map,
			feet = built.feet,
			gardens = RealReach.gardens(built, found :: Instance),
			zoneOf = built.zoneOf,
			rareFrom = Config.Ranks.BandEdges.Rare,
		}

		local eggSpots, problems = WorldIndex.readEggSpots(found :: Instance)
		spotProblems = problems
		-- The look parts rays skip (CanQuery false) that a player can see: a nest may sit on one (NestSeat, Rule 59).
		local lookParts: { BasePart } = {}
		for _, part in (found :: Instance):GetDescendants() do
			if part:IsA("BasePart") and not part.CanQuery and part.Transparency < Config.Ranks.VisibleBelow then
				table.insert(lookParts, part)
			end
		end
		local toolNests: { any } = {}
		for _, eggSpot in (eggSpots or {}) :: { WorldIndex.EggSpot } do
			local base = eggSpot.model:FindFirstChild("Base") :: BasePart
			table.insert(toolNests, {
				name = eggSpot.nestName,
				input = { name = eggSpot.name, position = eggSpot.cframe.Position, inMeadow = eggSpot.garden ~= nil },
				worldRank = eggSpot.rarity,
				seat = NestSeat.seatOf(eggSpot.nest, base, eggSpot.cframe.Position, { eggSpot.model }, lookParts),
			})
		end
		spotCount = #toolNests

		local tool = require(ServerStorage.Tools.report["egg-ranks"]) :: any
		local text: string
		text, result, rows = (tool :: EggTool).check({
			options = reach,
			world = Workspace,
			header = {
				date = os.date("%Y-%m-%d"),
				drain = SleepMeter.drainPerSecond(1),
				surfaceWords = { Terrain = "Grass" },
			},
			nests = toolNests,
		})
		seconds = os.clock() - started
		for index, row in rows do
			results[index] = row.reach
		end
		print("EGG RANKS REPORT")
		print(text)
		print(`EGG CHECK SECONDS {string.format("%.1f", seconds)}`)
	end, GiantPlaces.SCAN_TIMEOUT_MS)

	afterAll(function()
		if options ~= nil then
			PathCheck.cleanup(options)
		end
	end)

	-- Every scored nest's up and down routes.
	local function scoredRoutes(): { PathCheck.Route }
		local routes: { PathCheck.Route } = {}
		for _, nest in results do
			if nest.up ~= nil and nest.down ~= nil then
				table.insert(routes, nest.up)
				table.insert(routes, nest.down)
			end
		end
		return routes
	end

	it("every nest is in the egg check", function()
		expect(spotProblems).toEqual({})
		expect(spotCount).toBe(38)
		expect(#rows).toBe(38)
	end)

	-- The cuff nests players reach by walking; plan 5 Task 22's bot walk scores them, so the egg check leaves them out here
	-- (plan 5 Task 19a, card Step 4).
	local SCORED_BY_BOT_WALK: { [string]: boolean } = {
		["Cuff Back (Left)"] = true,
		["Cuff Back (Right)"] = true,
		["Cuff Front (Left)"] = true,
		["Cuff Front (Right)"] = true,
	}

	it("every nest left to the bot walk is in the run", function()
		local inRun: { [string]: boolean } = {}
		for _, row in rows do
			inRun[row.name or ""] = true
		end
		local missing: { string } = {}
		for name in SCORED_BY_BOT_WALK do
			if not inRun[name] then
				table.insert(missing, name)
			end
		end
		table.sort(missing)
		expect(missing).toEqual({})
	end)

	it("every nest passes the rank check (Rule 54)", function()
		local failures: { string } = {}
		for _, failure in (result :: EggRanks.RunResult).failures do
			if SCORED_BY_BOT_WALK[failure.name] then
				continue
			end
			table.insert(
				failures,
				`{failure.name} ({failure.rank}, score {string.format("%.1f", failure.score)}): {table.concat(
					failure.reasons,
					"; "
				)}`
			)
		end
		expect(failures).toEqual({})
	end)

	-- Plan 4, Task 9c: the far ends of the climb are reached on the egg map. Each target needs at least one map spot that
	-- stands on it (or under it) and that a foot reaches by walking and climbing (the egg check's own search).
	it("the far ends of the climb are reached on the egg map", function()
		local built = setup :: RealReach.Setup
		local allowed: PathCheck.AllowedKinds = { Walk = true, Climb = true }
		local searches: { [string]: PathCheck.Search } = {}
		for _, foot in built.feet do
			searches[foot.name] = PathCheck.costsFrom(built.map, foot.spot, { allow = allowed })
		end
		local function find(path: string): Instance?
			local at: Instance? = world
			for _, name in string.split(path, ".") do
				at = if at then at:FindFirstChild(name) else nil
			end
			return at
		end
		local targets: { { path: string, from: string? } } = {
			{ path = "Giant.nightcap.nightcap" },
			-- Cuff ledges: players reach them (plan 5 Task 13b, 5 of 5 round trips); plan 5 Task 22's bot walk scores them
			-- (Task 9d ruling).
			{ path = "WalkSurfaces.LapPlank_Left", from = "Left ramp" },
			{ path = "WalkSurfaces.LapPlank_Right", from = "Right ramp" },
		}
		local misses: { string } = {}
		for _, target in targets do
			local part = find(target.path)
			if part == nil then
				table.insert(misses, `{target.path}: not in the world`)
				continue
			end
			local onIt, reached = 0, 0
			for _, spot in built.map.spots do
				if spot.standsOn == part or spot.standsOn:IsDescendantOf(part) then
					onIt += 1
					for name, search in searches do
						if (target.from == nil or target.from == name) and search.costs[spot.id] ~= nil then
							reached += 1
							break
						end
					end
				end
			end
			if reached == 0 then
				table.insert(misses, `{target.path}: {onIt} spots on it, none reached from {target.from or "any foot"}`)
			end
		end
		expect(misses).toEqual({})
	end)

	it("no scored route stands on the cave skirt", function()
		local skirt = (world :: Instance):FindFirstChild("CaveSkirt")
		expect(RealReach.standsOnSkirt((setup :: RealReach.Setup).map, skirt, scoredRoutes())).toBe(0)
	end)

	it("no scored route step is within 2 studs of a slide guard", function()
		local map = (setup :: RealReach.Setup).map
		local spotsById: { [number]: PathCheck.Spot } = {}
		for _, spot in map.spots do
			spotsById[spot.id] = spot
		end
		local guards: { BasePart } = {}
		local folder = ((world :: any).WalkSurfaces :: Instance):FindFirstChild("SlideGuards")
		expect(folder).never.toBeNil()
		for _, guard in (folder :: Instance):GetChildren() do
			if guard:IsA("BasePart") then
				table.insert(guards, guard)
			end
		end
		expect(#guards > 0).toBe(true)
		local near: { string } = {}
		local named: { [string]: boolean } = {}
		for _, route in scoredRoutes() do
			for _, step in route.steps do
				for _, id in { step.from, step.to } do
					local spot = spotsById[id]
					for _, guard in guards do
						local inGuard = guard.CFrame:PointToObjectSpace(spot.position)
						local half = guard.Size / 2
						local clamped = Vector3.new(
							math.clamp(inGuard.X, -half.X, half.X),
							math.clamp(inGuard.Y, -half.Y, half.Y),
							math.clamp(inGuard.Z, -half.Z, half.Z)
						)
						local distance = (inGuard - clamped).Magnitude
						local label = `step spot {id} is {string.format("%.1f", distance)} from {guard.Name}`
						if distance <= SLIDE_GUARD_REACH and not named[label] then
							named[label] = true
							table.insert(near, label)
						end
					end
				end
			end
		end
		expect(near).toEqual({})
	end)

	it("the egg check finishes within 2 minutes", function()
		expect(seconds).toBeLessThan(120)
	end)
end)
