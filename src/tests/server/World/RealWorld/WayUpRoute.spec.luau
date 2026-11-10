--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
local Helpers = require(script.Parent.Helpers)
local NestRoute = require(script.Parent.NestRoute)
local loadRoute = Helpers.loadRoute
local realWorld = Helpers.realWorld

-- The footprint route to the four ways up (plan 3 Task 8c; spec Rule 35, "Every garden has a way up close by", and
-- Rule 45, "One way onto the belly", point 3). The route is built by tools/world/08-route/. These tests only READ the
-- real world.
describe("the real world, the route to the ways up", function()
	local WALK_SPEED = 16 -- studs per second: the default Humanoid.WalkSpeed, the speed Rule 35's limits are for
	local FOOT_TARGET = "WayUpFootForTest" -- a made-up target name, put on a copy of a way up's foot point

	local TIME_MARGIN = 0.3 -- seconds: Rule 35's fairness margin between mirror gardens

	local function pointsByName(points: { WorldIndex.RoutePoint }): { [string]: WorldIndex.RoutePoint }
		local byName: { [string]: WorldIndex.RoutePoint } = {}
		for _, point in points do
			byName[point.name] = point
		end
		return byName
	end

	-- The seconds a player at the spawn spot of `garden` walks to the foot of `wayUp`, along the route.
	local function walkSeconds(points: { WorldIndex.RoutePoint }, garden: number, wayUp: WorldIndex.WayUp): number?
		local copy: { WorldIndex.RoutePoint } = {}
		local spawnTarget = `Spawn_{garden}`
		local spawnPosition: Vector3? = nil
		for _, point in points do
			local entry = table.clone(point)
			if point.name == wayUp.foot.name then
				entry.target = FOOT_TARGET
			end
			if point.target == spawnTarget then
				spawnPosition = point.position
			end
			table.insert(copy, entry)
		end
		if spawnPosition == nil then
			return nil
		end
		local found = RouteGraph.find(RouteGraph.new(copy), spawnPosition, { FOOT_TARGET })
		if found == nil then
			return nil
		end
		return found.length / WALK_SPEED
	end

	local function readWaysUp(): { WorldIndex.WayUp }
		local waysUp, problems = WorldIndex.readWaysUp(realWorld())
		expect(problems).toEqual({})
		return waysUp :: { WorldIndex.WayUp }
	end

	it("every garden walks to its way up's foot within that way up's limit", function()
		local points = loadRoute()
		local over: { string } = {}
		local report: { string } = {}
		for _, wayUp in readWaysUp() do
			for position, garden in wayUp.gardens do
				local seconds = walkSeconds(points, garden, wayUp)
				local limit = wayUp.walkLimitSeconds[position]
				if seconds == nil then
					table.insert(over, `garden {garden} has no route to {wayUp.name}`)
				else
					table.insert(report, string.format("garden %d %.2f s (limit %.1f)", garden, seconds, limit))
					if seconds > limit then
						table.insert(
							over,
							string.format("garden %d to %s: %.2f s, limit %.1f", garden, wayUp.name, seconds, limit)
						)
					end
				end
			end
		end
		expect({ over = over }).toEqual({ over = {} })
		expect(#report).toBe(8)
	end)

	it("Rule 35's fairness pairs: gardens 1 and 8, and 2 and 7, walk within 0.3 s of each other", function()
		local points = loadRoute()
		local seconds: { [number]: number } = {}
		for _, wayUp in readWaysUp() do
			for _, garden in wayUp.gardens do
				local walked = walkSeconds(points, garden, wayUp)
				if walked ~= nil then
					seconds[garden] = walked
				end
			end
		end
		local over: { string } = {}
		for _, pair in { { 1, 8 }, { 2, 7 } } do
			local a, b = seconds[pair[1]], seconds[pair[2]]
			if a == nil or b == nil or math.abs(a - b) > TIME_MARGIN then
				table.insert(
					over,
					string.format(
						"gardens %d and %d: %s s and %s s",
						pair[1],
						pair[2],
						if a then string.format("%.2f", a) else "no route",
						if b then string.format("%.2f", b) else "no route"
					)
				)
			end
		end
		expect({ over = over }).toEqual({ over = {} })
	end)

	it("each of the four ways up has exactly one foot and one top on the route", function()
		local waysUp = readWaysUp()
		expect(#waysUp).toBe(4)
		local feet: { [string]: boolean } = {}
		local tops: { [string]: boolean } = {}
		for _, wayUp in waysUp do
			expect({ way = wayUp.name, foot = wayUp.foot ~= nil, top = wayUp.top ~= nil }).toEqual({
				way = wayUp.name,
				foot = true,
				top = true,
			})
			expect({ way = wayUp.name, sameEnd = wayUp.foot.name == wayUp.top.name }).toEqual({
				way = wayUp.name,
				sameEnd = false,
			})
			feet[wayUp.foot.name] = true
			tops[wayUp.top.name] = true
		end
		local footCount, topCount = 0, 0
		for _ in feet do
			footCount += 1
		end
		for _ in tops do
			topCount += 1
		end
		expect({ feet = footCount, tops = topCount }).toEqual({ feet = 4, tops = 4 })
	end)

	it("the landing's back point forks onto both belly ramps (Rule 45, point 3)", function()
		local byName = pointsByName(loadRoute())
		local back = byName["RoutePoint_Landing_Back"]
		expect({ found = back ~= nil }).toEqual({ found = true })
		local links: { [string]: boolean } = {}
		for _, name in back.neighbours do
			links[name] = true
		end
		expect({
			left = links["RoutePoint_BellyRampLeft_1"] == true,
			right = links["RoutePoint_BellyRampRight_1"] == true,
		}).toEqual({ left = true, right = true })
	end)

	-- Plan 5 Task 17, test 2. The nests that some garden's spawn point has no way to, as "nest (garden n)".
	local function unreachedNests(): { checked: number, unreached: { string } }
		local graph = RouteGraph.new(loadRoute())
		local spawns: { [number]: Vector3 } = {}
		for _, point in loadRoute() do
			local garden = if point.target then tonumber(string.match(point.target, "^Spawn_([1-8])$")) else nil
			if garden ~= nil then
				spawns[garden] = point.position
			end
		end
		local unreached: { string } = {}
		local nests = NestRoute.nests()
		for _, spot in nests do
			for garden = 1, 8 do
				if RouteGraph.find(graph, spawns[garden], { spot.name }) == nil then
					table.insert(unreached, `{spot.name} (garden {garden})`)
				end
			end
		end
		return { checked = #nests, unreached = unreached }
	end

	it("from every garden's spawn point the route finds a way to each of the 38 nests", function()
		expect(unreachedNests()).toEqual({ checked = 38, unreached = {} })
	end)

	-- Check D5 (spec 3): the way from the landing's back point to a lower belly nest goes up that side's belly ramp and
	-- never touches the other ramp. Returns which ramp points the way passes, e.g. { left = 3, right = 0 }.
	local function rampPointsPassed(nestName: string): { left: number, right: number }?
		local points = loadRoute()
		local byName = pointsByName(points)
		local back = byName["RoutePoint_Landing_Back"]
		if back == nil then
			return nil
		end
		local found = RouteGraph.find(RouteGraph.new(points), back.position, { nestName })
		if found == nil then
			return nil
		end
		local passed = { left = 0, right = 0 }
		for _, point in points do
			local side = if string.find(point.name, "^RoutePoint_BellyRampLeft_")
				then "left"
				elseif string.find(point.name, "^RoutePoint_BellyRampRight_") then "right"
				else nil
			if side ~= nil then
				for _, step in found.path do
					if (step - point.position).Magnitude < 0.01 then
						passed[side] += 1
						break
					end
				end
			end
		end
		return passed
	end

	it(
		"Check D5: from the landing's back point the way to the left lower belly nest goes up the left belly ramp only",
		function()
			local passed = rampPointsPassed("Nest_LowerBelly_Left")
			expect(passed ~= nil and passed.left > 0 and passed.right == 0).toBe(true)
		end
	)

	it(
		"Check D5: from the landing's back point the way to the right lower belly nest goes up the right belly ramp only",
		function()
			local passed = rampPointsPassed("Nest_LowerBelly_Right")
			expect(passed ~= nil and passed.right > 0 and passed.left == 0).toBe(true)
		end
	)

	-- Rule 36 (The lap planks), condition 3: standing on the deck, the lap fold's prompt and the knee pocket's prompt
	-- are within reach somewhere along it. The deck's standable top is found with rays every 0.5 studs and measured
	-- from 3 studs above it (NestRoute.standableTops; code_lead's ruling, 2026-11-10).
	local function closestDeckGap(side: string, nestName: string): number
		local anchorAt: Vector3? = nil
		for _, spot in NestRoute.nests() do
			if spot.name == nestName then
				anchorAt = spot.promptAnchor.WorldPosition
			end
		end
		local deck = (realWorld() :: any).WalkSurfaces[`LapPlank_{side}`].Deck
		if anchorAt == nil then
			return math.huge
		end
		return NestRoute.nearest(NestRoute.standableTops(deck), anchorAt)
	end

	it(
		"Rule 36: standing along each lap plank's deck, the lap fold and the knee pocket prompts are within 8 studs",
		function()
			local gaps: { [string]: number } = {}
			for _, side in { "Left", "Right" } do
				for _, place in { "LapFold", "KneePocket" } do
					local name = `Nest_{place}_{side}`
					gaps[name] = closestDeckGap(side, name)
				end
			end
			local over: { string } = {}
			for name, gap in gaps do
				if gap > NestRoute.ANCHOR_REACH then
					table.insert(over, string.format("%s: %.1f from the deck", name, gap))
				end
			end
			table.sort(over)
			expect({ over = over, count = 4 }).toEqual({ over = {}, count = 4 })
		end
	)

	-- Spec 5, belly pocket grab (15b): the pocket's route point stands on the belly top, not in the crease below the seam.
	-- The crease is 8.5 studs under the pocket (work/p5t15b/results.md, Case 3), so a point this close to the pocket's
	-- height is on the belly top.
	local BELLY_TOP_BELOW_POCKET = 5 -- studs: the most a belly-top point stands under the pocket's egg spot

	it("the belly pocket nests' route points stand on the belly top, not in the crease below the seam", function()
		local byTarget = NestRoute.pointsByTarget()
		local problems: { string } = {}
		for _, name in { "Nest_BellyPocket_Left", "Nest_BellyPocket_Right" } do
			local spot: WorldIndex.EggSpot? = nil
			for _, candidate in NestRoute.nests() do
				if candidate.name == name then
					spot = candidate
				end
			end
			local point = (byTarget[name] or {})[1]
			if point == nil or spot == nil then
				table.insert(problems, `{name}: no route point`)
			elseif point.position.Y < spot.cframe.Position.Y - BELLY_TOP_BELOW_POCKET then
				table.insert(
					problems,
					string.format(
						"%s: point at y %.1f, pocket at y %.1f",
						name,
						point.position.Y,
						spot.cframe.Position.Y
					)
				)
			end
		end
		expect({ problems = problems }).toEqual({ problems = {} })
	end)

	-- Spot rule 4: a nest grabbed from a plank is more than 8 studs from every belly ramp piece, so a player on the
	-- plank cannot reach into the belly by the prompt's reach.
	it("Spot rule 4: the lap fold and knee pocket nests are more than 8 studs from every belly ramp piece", function()
		local ramps = (realWorld() :: any).WalkSurfaces
		-- Only the standable tops count (NestRoute.standableTops), not the hidden Fill and Piece sides.
		local tops: { Vector3 } = {}
		for _, ramp in { ramps.BellyRamp_Left, ramps.BellyRamp_Right } do
			for _, spot in NestRoute.standableTops(ramp) do
				table.insert(tops, spot)
			end
		end
		expect(#tops > 0).toBe(true)
		local near: { string } = {}
		for _, spot in NestRoute.nests() do
			if string.find(spot.name, "^Nest_LapFold_") or string.find(spot.name, "^Nest_KneePocket_") then
				local gap = NestRoute.nearest(tops, spot.promptAnchor.WorldPosition)
				if gap <= NestRoute.ANCHOR_REACH then
					table.insert(near, string.format("%s is %.1f from a belly ramp top", spot.name, gap))
				end
			end
		end
		expect({ near = near }).toEqual({ near = {} })
	end)
end)
