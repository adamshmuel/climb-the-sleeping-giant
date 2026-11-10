--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeAll, afterAll =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeAll, JestGlobals.afterAll
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local WaysUpCheck = require(ServerScriptService.Server.World.WaysUpCheck)
local Helpers = require(script.Parent.Helpers)

-- The walk part of the ways-up check on the real world (plan 5 Task 18a Step 4; spec Rule 82, "No new way onto the belly"):
-- from each boot top, no walk, climb or slide route reaches the belly except through the lap landing, its apron and the
-- two belly ramps. It only READS the world. The map is the one work/t6c/6c-scripts.md section A2 counted: slope limit 78
-- (the steepest cloth players walked in Play), spacing 2, the ramp planks left out of the body box.
describe("the real world, the lap landing is the only way onto the belly", function()
	local SLOPE_LIMIT = 78 -- degrees
	local SPACING = 2 -- studs
	local AREA: PathCheck.Area = { min = Vector3.new(-40, 24, -68), max = Vector3.new(40, 56, -30) }
	-- The flat boot tops (EggSpots.spec LEFT/RIGHT_BOOT_TOP): where a player starts the climb to the belly.
	local BOOT_MIN_Z, BOOT_MAX_Z = -68, -60.4
	local LEFT_BOOT_X, RIGHT_BOOT_X = { -30, -16 }, { 16, 30 }
	-- The belly (the same test as section A2): on the giant, at the belly's back and top.
	local BELLY_MIN_Z, BELLY_MIN_Y = -44, 38

	local options: PathCheck.Options
	local map: PathCheck.WalkMap
	local giant: Instance
	local takenOut: { Instance } = {}
	local waysUp: { Instance } = {}

	local function isUnder(part: Instance, roots: { Instance }): boolean
		for _, root in roots do
			if part == root or part:IsDescendantOf(root) then
				return true
			end
		end
		return false
	end

	local function onBootTop(spot: PathCheck.Spot, xRange: { number }): boolean
		local at = spot.position
		return at.X >= xRange[1] and at.X <= xRange[2] and at.Z >= BOOT_MIN_Z and at.Z <= BOOT_MAX_Z
	end

	local function rulesFor(xRange: { number }): WaysUpCheck.Rules
		return {
			isSource = function(spot)
				return onBootTop(spot, xRange)
			end,
			isTakenOut = function(spot)
				return isUnder(spot.standsOn, takenOut)
			end,
			isBelly = function(spot)
				return spot.standsOn:IsDescendantOf(giant)
					and spot.position.Z >= BELLY_MIN_Z
					and spot.position.Y >= BELLY_MIN_Y
			end,
		}
	end

	-- Builds the walk map once for both sides (it takes a while).
	beforeAll(function()
		local world = Helpers.realWorld()
		local walkSurfaces = (world :: any).WalkSurfaces :: Instance
		giant = (world :: any).Giant :: Instance
		local rampLeft = walkSurfaces:FindFirstChild("BellyRamp_Left") :: Instance
		local rampRight = walkSurfaces:FindFirstChild("BellyRamp_Right") :: Instance
		takenOut = {
			walkSurfaces:FindFirstChild("LapLanding") :: Instance,
			walkSurfaces:FindFirstChild("LapApron") :: Instance,
			rampLeft,
			rampRight,
		}
		waysUp = {
			walkSurfaces:FindFirstChild("LapPlank_Left") :: Instance,
			walkSurfaces:FindFirstChild("LapPlank_Right") :: Instance,
			walkSurfaces:FindFirstChild("LapLanding") :: Instance,
			walkSurfaces:FindFirstChild("LapApron") :: Instance,
			rampLeft,
			rampRight,
		}
		options = PathCheck.defaults(Workspace)
		options.spacing = SPACING
		options.slopeAngle = SLOPE_LIMIT
		-- The ramp planks are left out of the body check: a player steps on or off a ramp over its edge by design.
		options.boxIgnores = { rampLeft, rampRight }
		map = PathCheck.buildMap(options, AREA)
	end)

	afterAll(function()
		pcall(PathCheck.cleanup, options)
	end)

	local function messages(problems: { WaysUpCheck.Problem }): { string }
		local lines: { string } = {}
		for _, item in problems do
			table.insert(lines, `{item.kind}: {item.detail}`)
		end
		return lines
	end

	local sides: { { name: string, xRange: { number } } } = {
		{ name = "left", xRange = LEFT_BOOT_X },
		{ name = "right", xRange = RIGHT_BOOT_X },
	}
	for _, entry in sides do
		local side, xRange = entry.name, entry.xRange
		it(`from the {side} boot top the control reaches the belly, so the flood works`, function()
			expect(#WaysUpCheck.bellyReached(map, rulesFor(xRange), false) > 0).toBe(true)
		end)

		it(`from the {side} boot top no route skips the lap landing`, function()
			expect(messages(WaysUpCheck.skipsLanding(map, rulesFor(xRange)))).toEqual({})
		end)

		it(`from the {side} boot top nothing reaches the belly with the landing out`, function()
			expect(#WaysUpCheck.bellyReached(map, rulesFor(xRange), true)).toBe(0)
		end)
	end

	-- Nothing invisible overhead (spec 3 Rule 45 point 2): over every walk-map spot on the lap planks, the landing, its
	-- apron and the two belly ramps, no solid part within 15 studs is see-through (Transparency 0.5 or more).
	local function waysUpSpots(): { Vector3 }
		local spots: { Vector3 } = {}
		for _, spot in map.spots do
			if isUnder(spot.standsOn, waysUp) then
				table.insert(spots, spot.position)
			end
		end
		return spots
	end

	it("the ways-up area has walk-map spots, so the overhead check is not empty", function()
		expect(#waysUpSpots() > 0).toBe(true)
	end)

	it("nothing invisible hangs over the ways-up area", function()
		expect(messages(WaysUpCheck.overheadProblems(Workspace, waysUpSpots(), {}))).toEqual({})
	end)
end)
