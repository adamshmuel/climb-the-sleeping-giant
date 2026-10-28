--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local SafeSpots = require(ServerScriptService.Server.Players.SafeSpots)

local USER = 1001

-- A good sample (flat ground, walking, room to stand). Each test changes only what it checks.
local function sample(overrides: { [string]: any }?): SafeSpots.Sample
	local s: any = {
		now = 0,
		feet = Vector3.new(0, 5, 0),
		facing = Vector3.new(0, 0, -1),
		groundNormal = Vector3.new(0, 1, 0),
		state = Enum.HumanoidStateType.Running,
		floating = false,
		hasRoom = function()
			return true
		end,
	}
	if overrides then
		for key, value in overrides do
			s[key] = value
		end
	end
	return s :: SafeSpots.Sample
end

-- A ground surface direction tilted by this many degrees from flat.
local function tilted(degrees: number): Vector3
	local rad = math.rad(degrees)
	return Vector3.new(math.sin(rad), math.cos(rad), 0)
end

describe("SafeSpots", function()
	it("saves a spot on flat ground with room", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample())).toBe(true)
		expect(spots:count(USER)).toBe(1)
	end)

	it("saves nothing while falling", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ state = Enum.HumanoidStateType.Freefall }))).toBe(false)
		expect(spots:count(USER)).toBe(0)
	end)

	it("saves nothing while jumping", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ state = Enum.HumanoidStateType.Jumping }))).toBe(false)
	end)

	it("saves nothing while climbing a ladder", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ state = Enum.HumanoidStateType.Climbing }))).toBe(false)
	end)

	it("saves nothing while floating down", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ floating = true }))).toBe(false)
	end)

	it("saves nothing without room for the body", function()
		local spots = SafeSpots.new(70)
		local no = function()
			return false
		end
		expect(spots:sample(USER, sample({ hasRoom = no }))).toBe(false)
	end)

	it("saves nothing with no ground under the feet", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ groundNormal = Vector3.zero }))).toBe(false)
		local noGround: any = sample({ now = 1 })
		noGround.groundNormal = nil -- the helper can't pass nil through its overrides table
		expect(spots:sample(USER, noGround)).toBe(false)
	end)

	it("saves on 69 degree ground but not on 71", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ groundNormal = tilted(71) }))).toBe(false)
		expect(spots:sample(2, sample({ groundNormal = tilted(69) }))).toBe(true)
	end)

	it("checks at most once every half second", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ now = 10 }))).toBe(true)
		expect(spots:sample(USER, sample({ now = 10.3, feet = Vector3.new(5, 5, 0) }))).toBe(false)
		expect(spots:sample(USER, sample({ now = 10.5, feet = Vector3.new(5, 5, 0) }))).toBe(true)
	end)

	it("saves nothing under 1 stud from the last spot", function()
		local spots = SafeSpots.new(70)
		expect(spots:sample(USER, sample({ now = 0 }))).toBe(true)
		expect(spots:sample(USER, sample({ now = 1, feet = Vector3.new(0.9, 5, 0) }))).toBe(false)
		expect(spots:sample(USER, sample({ now = 2, feet = Vector3.new(1.1, 5, 0) }))).toBe(true)
	end)

	it("doesn't run the room check when nothing would be saved", function()
		local spots = SafeSpots.new(70)
		local calls = 0
		local counting = function()
			calls += 1
			return true
		end
		spots:sample(USER, sample({ now = 0 }))
		spots:sample(USER, sample({ now = 1, state = Enum.HumanoidStateType.Freefall, hasRoom = counting }))
		spots:sample(USER, sample({ now = 2, feet = Vector3.new(0.5, 5, 0), hasRoom = counting }))
		expect(calls).toBe(0)
	end)

	it("keeps the newest 40 spots", function()
		local spots = SafeSpots.new(70)
		-- The first spot is far away (x = 100); the next 40 zigzag between x = 0 and x = 1.1.
		spots:sample(USER, sample({ now = 1, feet = Vector3.new(100, 5, 0) }))
		for i = 2, 41 do
			local x = if i % 2 == 0 then 0 else 1.1
			spots:sample(USER, sample({ now = i, feet = Vector3.new(x, 5, 0) }))
		end
		expect(spots:count(USER)).toBe(40)
		-- Standing at x = 0, every kept spot is under 4 studs away. Only the dropped first spot was far.
		expect(spots:pick(USER, Vector3.new(0, 5, 0))).toBe(nil)
	end)

	it("saves the facing flat and keeps the last one when standing", function()
		local spots = SafeSpots.new(70)
		spots:sample(USER, sample({ now = 0, facing = Vector3.new(1, 1, 0) }))
		spots:sample(USER, sample({ now = 1, feet = Vector3.new(10, 5, 0), facing = Vector3.zero }))
		local picked = spots:pick(USER, Vector3.new(100, 5, 0)) :: SafeSpots.Spot
		expect(picked.feet.X).toBeCloseTo(10, 3)
		expect(picked.facing.X).toBeCloseTo(1, 3)
		expect(picked.facing.Y).toBeCloseTo(0, 3)
		expect(picked.facing.Z).toBeCloseTo(0, 3)
		local first = spots:pick(USER, Vector3.new(10, 5, 0)) :: SafeSpots.Spot
		expect(first.facing.X).toBeCloseTo(1, 3)
	end)

	it("returns the newest spot at least 4 studs away", function()
		local spots = SafeSpots.new(70)
		for i = 0, 3 do
			spots:sample(USER, sample({ now = i, feet = Vector3.new(i * 2, 5, 0) }))
		end
		local picked = spots:pick(USER, Vector3.new(6.5, 5, 0))
		expect(picked ~= nil).toBe(true)
		expect((picked :: SafeSpots.Spot).feet.X).toBeCloseTo(2, 3)
	end)

	it("picks nothing when no spot is 4 studs away", function()
		local spots = SafeSpots.new(70)
		spots:sample(USER, sample())
		expect(spots:pick(USER, Vector3.new(3, 5, 0))).toBe(nil)
	end)

	it("picks nothing for a player with no spots", function()
		local spots = SafeSpots.new(70)
		expect(spots:pick(USER, Vector3.new(50, 5, 0))).toBe(nil)
	end)

	it("forget removes a player's spots", function()
		local spots = SafeSpots.new(70)
		spots:sample(USER, sample())
		spots:forget(USER)
		expect(spots:count(USER)).toBe(0)
		expect(spots:pick(USER, Vector3.new(50, 5, 0))).toBe(nil)
	end)

	it("keeps players' spots apart", function()
		local spots = SafeSpots.new(70)
		spots:sample(1, sample({ feet = Vector3.new(0, 5, 0) }))
		spots:sample(2, sample({ feet = Vector3.new(20, 5, 0) }))
		spots:forget(1)
		expect(spots:count(1)).toBe(0)
		expect(spots:count(2)).toBe(1)
		local picked = spots:pick(2, Vector3.new(50, 5, 0)) :: SafeSpots.Spot
		expect(picked.feet.X).toBeCloseTo(20, 3)
	end)
end)
