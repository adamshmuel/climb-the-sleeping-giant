--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
local Helpers = require(script.Parent.Helpers)
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
end)
