--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Slams = require(ServerScriptService.Server.Giant.Slams)
local Zones = require(ServerScriptService.Server.Giant.Zones)

type Player = Slams.Player

-- His face is high up over the middle of the meadow. Gardens, points and players below sit around it.
local FACE = Vector3.new(0, 95, 0)
local CLEAR_DISTANCE = 16 -- the circle's radius plus the 1-stud margin

-- A player in the meadow who carries an egg unless told otherwise. Pass overrides in `changes`.
local function player(userId: number, x: number, z: number, changes: { [string]: any }?): Player
	local made: any = {
		userId = userId,
		position = Vector3.new(x, 5, z),
		carrying = true,
		inGarden = false,
		floating = false,
		landedAgo = nil,
	}
	if changes then
		for key, value in changes do
			made[key] = value
		end
	end
	return made :: Player
end

local function box(index: number, cframe: CFrame, size: Vector3): Zones.GardenBox
	return { index = index, cframe = cframe, size = size }
end

-- A garden whose west edge is at x = 70 and which spans z -30 to 30.
local function westGarden(): Zones.GardenBox
	return box(1, CFrame.new(100, 20, 0), Vector3.new(60, 40, 60))
end

-- How far (across the ground) a point is from the nearest point of a box's flat rectangle, worked out here on its own.
local function flatGapToBox(point: Vector3, garden: Zones.GardenBox): number
	local local_ = garden.cframe:PointToObjectSpace(point)
	local half = garden.size / 2
	local gapX = math.max(math.abs(local_.X) - half.X, 0)
	local gapZ = math.max(math.abs(local_.Z) - half.Z, 0)
	return math.sqrt(gapX * gapX + gapZ * gapZ)
end

local function isClear(point: Vector3, gardens: { Zones.GardenBox }): boolean
	for _, garden in gardens do
		if flatGapToBox(point, garden) < CLEAR_DISTANCE then
			return false
		end
	end
	return true
end

describe("Slams.pickTarget", function()
	it("the carrier nearest to him is the target", function()
		local target = Slams.pickTarget({ player(1, 100, 0), player(2, 40, 0), player(3, -70, 0) }, FACE, nil)
		expect(target and target.userId).toBe(2)
	end)

	it("height is ignored: a carrier near across the ground beats one farther but level with his face", function()
		-- Across the ground: 3 studs and 30 studs. In 3D the 3-stud carrier (on the meadow, 90 studs below his face) would
		-- be farther than the 30-stud one (high on his belly, level with his face).
		local onBelly = player(2, 30, 0, { position = Vector3.new(30, 95, 0) })
		local target = Slams.pickTarget({ onBelly, player(1, 3, 0) }, FACE, nil)
		expect(target and target.userId).toBe(1)
	end)

	it("a carrier high on the giant can be a target", function()
		local onHim = player(1, 20, 0, { position = Vector3.new(20, 60, 0) })
		local target = Slams.pickTarget({ onHim }, FACE, nil)
		expect(target and target.userId).toBe(1)
	end)

	it("a carrier who was the last target is skipped when another carrier can be targeted", function()
		local target = Slams.pickTarget({ player(1, 10, 0), player(2, 60, 0) }, FACE, 1)
		expect(target and target.userId).toBe(2)
	end)

	it("a lone carrier who was the last target is targeted again", function()
		local target = Slams.pickTarget({ player(1, 10, 0) }, FACE, 1)
		expect(target and target.userId).toBe(1)
	end)

	it("the last target is targeted again when the only other carrier is floating", function()
		local target = Slams.pickTarget({ player(1, 10, 0), player(2, 60, 0, { floating = true }) }, FACE, 1)
		expect(target and target.userId).toBe(1)
	end)

	it("a player still floating down is never a target, even if nearest", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { floating = true }), player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(2)
	end)

	it("a player in a garden is never a target, even if nearest", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { inGarden = true }), player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(2)
	end)

	it("a player who carries nothing is never a target, even if nearest", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { carrying = false }), player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(2)
	end)

	it("a player who landed a moment ago can still be a target (only floating players are skipped)", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { landedAgo = 0.2 }), player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(1)
	end)

	it("nobody fits: nil", function()
		local nobody = {
			player(1, 5, 0, { carrying = false }),
			player(2, 5, 0, { floating = true }),
			player(3, 5, 0, { inGarden = true }),
		}
		expect(Slams.pickTarget(nobody, FACE, nil)).toBeNil()
		expect(Slams.pickTarget({}, FACE, nil)).toBeNil()
	end)

	it("a tie in distance goes to the lower user id, whichever order the list comes in", function()
		-- Both are exactly 30 studs from him across the ground, on opposite sides.
		local low = player(4, 30, 0)
		local high = player(9, -30, 0)
		local lowFirst = Slams.pickTarget({ low, high }, FACE, nil)
		local highFirst = Slams.pickTarget({ high, low }, FACE, nil)
		expect(lowFirst and lowFirst.userId).toBe(4)
		expect(highFirst and highFirst.userId).toBe(4)
	end)

	it(
		"a tie between the other carriers still goes to the lower user id when the nearest was the last target",
		function()
			local players = { player(1, 10, 0), player(9, -30, 0), player(4, 30, 0) }
			local target = Slams.pickTarget(players, FACE, 1)
			expect(target and target.userId).toBe(4)
		end
	)
end)

describe("Slams.clearOfGardens", function()
	it("a centre far from every garden comes back exactly unchanged", function()
		local centre = Vector3.new(0, 7, 120)
		local result = Slams.clearOfGardens(centre, { westGarden() }, FACE)
		expect(result == centre).toBe(true)
	end)

	it("a centre exactly 16 studs from a garden's edge is already clear and comes back unchanged", function()
		local centre = Vector3.new(54, 5, 0)
		local result = Slams.clearOfGardens(centre, { westGarden() }, FACE)
		expect(result == centre).toBe(true)
	end)

	it("a centre 10 studs outside a garden moves toward his face until its circle is 1 stud clear", function()
		-- The edge is at x = 70, so the centre starts at x = 60 and must end 16 studs from the edge, at x = 54.
		local result = Slams.clearOfGardens(Vector3.new(60, 5, 0), { westGarden() }, FACE)
		expect(math.abs(result.X - 54) <= 0.1).toBe(true)
		expect(result.X <= 54).toBe(true) -- clear, not short of clear
		expect(result.Z).toBe(0)
	end)

	it("a centre inside a garden is moved out across the ground", function()
		local result = Slams.clearOfGardens(Vector3.new(90, 5, 0), { westGarden() }, FACE)
		expect(isClear(result, { westGarden() })).toBe(true)
		expect(math.abs(result.X - 54) <= 0.1).toBe(true)
	end)

	it("between two gardens 14 studs apart it ends clear of both, moved only toward his face", function()
		-- Gardens at z = -37 and z = 37: their edges at z = -7 and z = 7 leave a gap of 14.
		local gardens = {
			box(1, CFrame.new(100, 20, -37), Vector3.new(60, 40, 60)),
			box(2, CFrame.new(100, 20, 37), Vector3.new(60, 40, 60)),
		}
		local start = Vector3.new(100, 5, 0)
		local result = Slams.clearOfGardens(start, gardens, FACE)
		expect(isClear(result, gardens)).toBe(true)
		-- He is straight west of the start, so only X changes and it only gets smaller.
		expect(result.Z).toBe(0)
		expect(result.Y).toBe(5)
		expect(result.X < start.X).toBe(true)
		-- It stopped as soon as it could: 0.1 studs back toward the start is not clear.
		expect(isClear(result + Vector3.new(0.1, 0, 0), gardens)).toBe(false)
	end)

	it("moves along the flat line to his face when he is not straight out from the edge", function()
		local start = Vector3.new(80, 5, 20)
		local face = Vector3.new(-20, 95, -20)
		local result = Slams.clearOfGardens(start, { westGarden() }, face)
		local moved = Vector3.new(result.X - start.X, 0, result.Z - start.Z)
		local toFace = Vector3.new(face.X - start.X, 0, face.Z - start.Z)
		expect(moved.Magnitude > 1).toBe(true)
		expect(moved.Unit:Dot(toFace.Unit) > 0.99999).toBe(true)
		expect(isClear(result, { westGarden() })).toBe(true)
	end)

	it("a garden turned 40 degrees is measured in its own space, not by its world-aligned bounds", function()
		local turned = box(1, CFrame.new(100, 20, 0) * CFrame.Angles(0, math.rad(40), 0), Vector3.new(80, 40, 20))
		-- (130, 5, 30) is inside the turned garden's world-aligned bounds but 32 studs from the garden itself.
		local corner = Vector3.new(130, 5, 30)
		local unchanged = Slams.clearOfGardens(corner, { turned }, FACE)
		expect(unchanged == corner).toBe(true)

		-- A centre inside the turned garden is moved out until it is clear in the garden's own space.
		local start = Vector3.new(120, 5, -10)
		local result = Slams.clearOfGardens(start, { turned }, FACE)
		expect(isClear(result, { turned })).toBe(true)
		local back = result + (start - result).Unit * 0.1 -- 0.1 studs back along the way it came
		expect(isClear(back, { turned })).toBe(false)
	end)

	it("when no step before his face is clear, the circle ends right under his face", function()
		-- One huge garden covers everything between the centre and his face (it cannot happen in the real world).
		local huge = box(1, CFrame.new(0, 20, 0), Vector3.new(1000, 40, 1000))
		local result = Slams.clearOfGardens(Vector3.new(100, 5, 0), { huge }, FACE)
		expect(result.X).toBe(0)
		expect(result.Z).toBe(0)
		expect(result.Y).toBe(5)
	end)

	it("a centre straight under his face has no way to move toward it and stays", function()
		local huge = box(1, CFrame.new(0, 20, 0), Vector3.new(1000, 40, 1000))
		local centre = Vector3.new(0, 5, 0)
		expect(Slams.clearOfGardens(centre, { huge }, FACE) == centre).toBe(true)
	end)

	it("the height never changes", function()
		local result = Slams.clearOfGardens(Vector3.new(60, 61.5, 0), { westGarden() }, FACE)
		expect(result.Y).toBe(61.5)
		expect(result.X < 60).toBe(true)
	end)
end)

describe("Slams.pickEmpty", function()
	local first = function(_count: number): number
		return 1
	end

	-- Meadow points far from the garden at x = 70 to 130, from the west and north of him.
	local P1 = Vector3.new(-200, 5, 0)
	local P2 = Vector3.new(-100, 5, 0)
	local P3 = Vector3.new(0, 5, 100)
	local P4 = Vector3.new(0, 5, -100)

	it("returns the point the pick chooses among those that fit, in meadowPoints order", function()
		local asked: { number } = {}
		local function pickLast(count: number): number
			table.insert(asked, count)
			return count
		end
		expect(Slams.pickEmpty({ P1, P2, P3 }, {}, {}, {}, nil, pickLast) == P3).toBe(true)
		expect(asked).toEqual({ 3 })
		local function pickSecond(_count: number): number
			return 2
		end
		expect(Slams.pickEmpty({ P1, P2, P3 }, {}, {}, {}, nil, pickSecond) == P2).toBe(true)
	end)

	it("leaves out a point whose circle is near a garden", function()
		-- (60, 5, 0) is 10 studs from the garden's edge, so a circle there would touch it.
		local result = Slams.pickEmpty({ Vector3.new(60, 5, 0), P2 }, {}, {}, { westGarden() }, nil, first)
		expect(result == P2).toBe(true)
	end)

	it("leaves out a point with a landing spot within 15 studs across the ground", function()
		-- The spot is 80 studs lower than the point, and 10 studs away across the ground.
		local spots = { Vector3.new(-100, -75, 10) }
		local result = Slams.pickEmpty({ P2, P3 }, {}, spots, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("keeps a point with a landing spot 15.5 studs away", function()
		local spots = { Vector3.new(-100, 5, 15.5) }
		local result = Slams.pickEmpty({ P2, P3 }, {}, spots, {}, nil, first)
		expect(result == P2).toBe(true)
	end)

	it("leaves out a point with a landing spot exactly 15 studs away", function()
		local spots = { Vector3.new(-100, 5, 15) }
		local result = Slams.pickEmpty({ P2, P3 }, {}, spots, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("leaves out a point with a player exactly 15 studs away", function()
		local result = Slams.pickEmpty({ P2, P3 }, { player(1, -100, 15) }, {}, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("leaves out a point with a carrier within 15 studs", function()
		local result = Slams.pickEmpty({ P2, P3 }, { player(1, -100, 10) }, {}, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("leaves out a point with a player who carries nothing within 15 studs", function()
		local result = Slams.pickEmpty({ P2, P3 }, { player(1, -100, 10, { carrying = false }) }, {}, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("leaves out a point with a floating player within 15 studs", function()
		local result = Slams.pickEmpty({ P2, P3 }, { player(1, -100, 10, { floating = true }) }, {}, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("a player high above a point still counts: height is ignored", function()
		local high = player(1, -100, 10, { position = Vector3.new(-100, 70, 10) })
		local result = Slams.pickEmpty({ P2, P3 }, { high }, {}, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("leaves out the centre of the slam before when another point fits", function()
		local result = Slams.pickEmpty({ P1, P2 }, {}, {}, {}, P1, first)
		expect(result == P2).toBe(true)
		local second = Slams.pickEmpty({ P1, P2 }, {}, {}, {}, P2, first)
		expect(second == P1).toBe(true)
	end)

	it("returns the centre of the slam before when it is the only point that fits", function()
		local players = { player(1, -100, 5) } -- stands on P2, so only P1 fits
		local result = Slams.pickEmpty({ P1, P2 }, players, {}, {}, P1, first)
		expect(result == P1).toBe(true)
	end)

	it("when players stand on every point, returns the garden-clear point farthest from its nearest player", function()
		-- Nearest player to P1 is 8 studs away, to P2 5, to P3 12, to P4 3. P4 is the nearest to 3, P3 the farthest.
		local players = {
			player(1, -200, 8),
			player(2, -100, 5),
			player(3, 12, 100),
			player(4, 0, -97, { carrying = false }),
		}
		local result = Slams.pickEmpty({ P1, P2, P3, P4 }, players, {}, {}, nil, first)
		expect(result == P3).toBe(true)
	end)

	it("when nothing fits, a point inside a garden is never chosen even if its players are far", function()
		local inGarden = Vector3.new(90, 5, 0) -- no player is near it, but it is in the garden
		local players = { player(1, -100, 5), player(2, -200, 5) }
		local result = Slams.pickEmpty({ inGarden, P1, P2 }, players, {}, { westGarden() }, nil, first)
		-- P1 and P2 both have a player on them; P1's is 5 away, P2's is 5 away: the first of the two wins.
		expect(result == P1).toBe(true)
	end)

	it(
		"when nothing fits, landing spots do not matter to the fallback: the point farthest from the players wins",
		function()
			local spots = { Vector3.new(-100, 5, 0), Vector3.new(0, 5, 100) }
			local players = { player(1, -100, 9), player(2, 0, 106) }
			-- Both points are covered by a landing spot and have a player 9 and 6 studs away.
			local result = Slams.pickEmpty({ P2, P3 }, players, spots, {}, nil, first)
			expect(result == P2).toBe(true)
		end
	)

	it("errors with a clear message when no point is clear of the gardens", function()
		expect(function()
			Slams.pickEmpty({ Vector3.new(90, 5, 0), Vector3.new(60, 5, 0) }, {}, {}, { westGarden() }, nil, first)
		end).toThrow("Slams.pickEmpty: no meadow point is clear of the gardens")
		expect(function()
			Slams.pickEmpty({}, {}, {}, {}, nil, first)
		end).toThrow("Slams.pickEmpty: no meadow point is clear of the gardens")
	end)
end)

describe("Slams.plan", function()
	local first = function(_count: number): number
		return 1
	end
	local meadow = { Vector3.new(-200, 5, 0), Vector3.new(-100, 5, 0) }

	it("a carrier near a garden gives a pushed circle with that carrier's user id", function()
		local result = Slams.plan({ player(7, 60, 0) }, FACE, { westGarden() }, meadow, {}, nil, nil, first)
		expect(result.target).toBe(7)
		expect(math.abs(result.centre.X - 54) <= 0.1).toBe(true)
		expect(result.centre.Y).toBe(5)
		expect(result.centre.Z).toBe(0)
	end)

	it("a carrier far from every garden gets a circle right on them", function()
		local standing = Vector3.new(-30, 9, 20)
		local result = Slams.plan(
			{ player(7, 0, 0, { position = standing }) },
			FACE,
			{ westGarden() },
			meadow,
			{},
			nil,
			nil,
			first
		)
		expect(result.target).toBe(7)
		expect(result.centre == standing).toBe(true)
	end)

	it("no carrier gives an empty-meadow circle with no target", function()
		local players = { player(1, 0, 0, { carrying = false }) }
		local result = Slams.plan(players, FACE, { westGarden() }, meadow, {}, nil, nil, first)
		expect(result.target).toBeNil()
		expect(result.centre == meadow[1]).toBe(true)
	end)

	it("passes the last target on: the other carrier is aimed at", function()
		local result = Slams.plan({ player(1, 10, 0), player(2, -60, 0) }, FACE, {}, meadow, {}, 1, nil, first)
		expect(result.target).toBe(2)
	end)

	it("passes the last centre on: an empty slam does not repeat it", function()
		local result = Slams.plan({}, FACE, {}, meadow, {}, nil, meadow[1], first)
		expect(result.centre == meadow[2]).toBe(true)
	end)

	it("a lone carrier still gets a circle when no meadow point fits", function()
		-- Nothing is clear of the gardens for the empty slam, but a target needs no meadow point.
		local result = Slams.plan(
			{ player(3, 60, 0) },
			FACE,
			{ westGarden() },
			{ Vector3.new(90, 5, 0) },
			{},
			nil,
			nil,
			first
		)
		expect(result.target).toBe(3)
	end)
end)

describe("Slams.caught", function()
	local centre = Vector3.new(-50, 5, 20)

	it("a carrier exactly 15 studs away across the ground is caught", function()
		expect(Slams.caught({ player(1, -35, 20) }, centre)).toEqual({ 1 })
	end)

	it("a carrier 15.1 studs away across the ground is not caught", function()
		expect(Slams.caught({ player(1, -34.9, 20) }, centre)).toEqual({})
	end)

	it("the distance is measured across the ground in both directions", function()
		-- 10 across in X and 10 in Z is 14.14 studs, caught; 11 and 11 is 15.56, not caught.
		expect(Slams.caught({ player(1, -40, 30) }, centre)).toEqual({ 1 })
		expect(Slams.caught({ player(2, -39, 31) }, centre)).toEqual({})
	end)

	it("a carrier 9 studs above the centre is caught, 11 studs above is not", function()
		expect(Slams.caught({ player(1, -50, 20, { position = Vector3.new(-50, 14, 20) }) }, centre)).toEqual({ 1 })
		expect(Slams.caught({ player(2, -50, 20, { position = Vector3.new(-50, 16, 20) }) }, centre)).toEqual({})
	end)

	it("the distance across the ground ignores height: 14 studs across and 9 studs up is caught", function()
		-- In 3D this carrier would be 16.6 studs away, outside the 15-stud circle.
		expect(Slams.caught({ player(1, -36, 20, { position = Vector3.new(-36, 14, 20) }) }, centre)).toEqual({ 1 })
	end)

	it("a carrier 9 studs below the centre is caught, 11 studs below is not", function()
		expect(Slams.caught({ player(1, -50, 20, { position = Vector3.new(-50, -4, 20) }) }, centre)).toEqual({ 1 })
		expect(Slams.caught({ player(2, -50, 20, { position = Vector3.new(-50, -6, 20) }) }, centre)).toEqual({})
	end)

	it("a carrier exactly 10 studs above the centre is caught", function()
		expect(Slams.caught({ player(1, -50, 20, { position = Vector3.new(-50, 15, 20) }) }, centre)).toEqual({ 1 })
	end)

	it("a player who carries nothing is not caught", function()
		expect(Slams.caught({ player(1, -50, 20, { carrying = false }) }, centre)).toEqual({})
	end)

	it("a floating carrier is not caught", function()
		expect(Slams.caught({ player(1, -50, 20, { floating = true }) }, centre)).toEqual({})
	end)

	it("a carrier in a garden is not caught", function()
		expect(Slams.caught({ player(1, -50, 20, { inGarden = true }) }, centre)).toEqual({})
	end)

	it("several carriers inside are all caught, in list order, and the target need not be one of them", function()
		local players = { player(9, -45, 20), player(2, -50, 25), player(5, 100, 100), player(4, -55, 15) }
		expect(Slams.caught(players, centre)).toEqual({ 9, 2, 4 })
	end)

	it("nobody is caught when nobody is inside", function()
		expect(Slams.caught({ player(1, 100, 100) }, centre)).toEqual({})
		expect(Slams.caught({}, centre)).toEqual({})
	end)

	it("a carrier who landed 1.4 s ago is not caught", function()
		expect(Slams.caught({ player(1, -50, 20, { landedAgo = 1.4 }) }, centre)).toEqual({})
	end)

	it("a carrier who landed exactly 1.5 s ago is caught", function()
		expect(Slams.caught({ player(1, -50, 20, { landedAgo = 1.5 }) }, centre)).toEqual({ 1 })
	end)

	it("a carrier who landed long ago, or never floated, is caught", function()
		expect(Slams.caught({ player(1, -50, 20, { landedAgo = 12 }) }, centre)).toEqual({ 1 })
		expect(Slams.caught({ player(2, -50, 20, { landedAgo = nil }) }, centre)).toEqual({ 2 })
	end)

	it("a guarded carrier does not stop the others in the same circle from being caught", function()
		local players =
			{ player(1, -50, 20, { landedAgo = 0.3 }), player(2, -48, 20), player(3, -52, 20, { landedAgo = 0 }) }
		expect(Slams.caught(players, centre)).toEqual({ 2 })
	end)
end)
