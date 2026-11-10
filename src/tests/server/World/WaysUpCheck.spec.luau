--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WaysUpCheck = require(ServerScriptService.Server.World.WaysUpCheck)

-- The walk part of the ways-up check on hand-made walk maps (plan 5 Task 18a Step 1). A map is a few spots with links;
-- the parts they stand on are never in the world, so no WorldModel is needed. A spot's role comes from its id.
local SOURCE, SIDE, LANDING, BELLY = 1, 2, 3, 4
local UP = Vector3.new(0, 1, 0)

type Route = { to: number, kind: PathCheck.LinkKind }
local NO_ROUTES: { Route } = {}

local function makeMap(links: { [number]: { Route } }): PathCheck.WalkMap
	local spots: { PathCheck.Spot } = {}
	for id = SOURCE, BELLY do
		spots[id] = { id = id, position = Vector3.new(id * 10, 0, 0), up = UP, standsOn = Instance.new("Part") }
	end
	local full: { [number]: { PathCheck.Link } } = {}
	for id = SOURCE, BELLY do
		full[id] = {}
		for _, link in links[id] or NO_ROUTES do
			table.insert(full[id], { to = link.to, kind = link.kind, length = 10, seconds = 1 })
		end
	end
	return { spacing = 1, spots = spots, links = full, columns = {}, origin = Vector3.zero, countX = 1, countZ = 1 }
end

local rules: WaysUpCheck.Rules = {
	isSource = function(spot)
		return spot.id == SOURCE
	end,
	isTakenOut = function(spot)
		return spot.id == LANDING
	end,
	isBelly = function(spot)
		return spot.id == BELLY
	end,
}

local function walk(to: number): { to: number, kind: PathCheck.LinkKind }
	return { to = to, kind = "Walk" }
end

describe("WaysUpCheck walk part", function()
	it("fails a second route round a wall that skips the landing", function()
		-- source -> landing -> belly, and source -> side -> belly (no landing on it)
		local map =
			makeMap({ [SOURCE] = { walk(LANDING), walk(SIDE) }, [LANDING] = { walk(BELLY) }, [SIDE] = { walk(BELLY) } })
		local problems = WaysUpCheck.skipsLanding(map, rules)
		expect(#problems).toBe(1)
		expect(problems[1].kind).toBe("skips the landing")
		expect(problems[1].detail).toContain(tostring(map.spots[BELLY].position))
	end)

	it("passes when the wall is closed", function()
		local map = makeMap({ [SOURCE] = { walk(LANDING), walk(SIDE) }, [LANDING] = { walk(BELLY) }, [SIDE] = {} })
		expect(#WaysUpCheck.skipsLanding(map, rules)).toBe(0)
	end)

	it("passes when the only route goes through the landing, and the control still reaches the belly", function()
		local map = makeMap({ [SOURCE] = { walk(LANDING) }, [LANDING] = { walk(BELLY) } })
		expect(#WaysUpCheck.bellyReached(map, rules, false)).toBe(1)
		expect(#WaysUpCheck.bellyReached(map, rules, true)).toBe(0)
		expect(#WaysUpCheck.skipsLanding(map, rules)).toBe(0)
	end)

	it("returns a control problem when no route reaches the belly at all", function()
		local map = makeMap({ [SOURCE] = { walk(SIDE) } })
		local problems = WaysUpCheck.skipsLanding(map, rules)
		expect(#problems).toBe(1)
		expect(problems[1].kind).toBe("control")
	end)

	it("counts a Slide link and a Climb link as routes", function()
		for _, kind in { "Slide", "Climb" } do
			local map = makeMap({
				[SOURCE] = { walk(LANDING), { to = SIDE, kind = kind :: PathCheck.LinkKind } },
				[LANDING] = { walk(BELLY) },
				[SIDE] = { { to = BELLY, kind = kind :: PathCheck.LinkKind } },
			})
			local problems = WaysUpCheck.skipsLanding(map, rules)
			expect(#problems).toBe(1)
			expect(problems[1].kind).toBe("skips the landing")
		end
	end)
end)
