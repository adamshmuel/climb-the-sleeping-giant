--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
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
		joinedThisWake = false,
		bonkedLast = false,
		appearedAgo = nil,
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

	it("a carrier is the target even when a player with no egg is nearer to him", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { carrying = false }), player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(2)
	end)

	it("a solo player with no egg in the meadow is the target", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { carrying = false }) }, FACE, nil)
		expect(target and target.userId).toBe(1)
	end)

	it("when the carrier is in a garden, the player with no egg is next", function()
		local carrier = player(1, 80, 0, { inGarden = true })
		local target = Slams.pickTarget({ carrier, player(2, 5, 0, { carrying = false }) }, FACE, nil)
		expect(target and target.userId).toBe(2)
	end)

	it("two players with no egg: the nearer first, and the other when the nearer was the last target", function()
		local near = player(1, 10, 0, { carrying = false })
		local far = player(2, 60, 0, { carrying = false })
		local first = Slams.pickTarget({ far, near }, FACE, nil)
		local afterNear = Slams.pickTarget({ far, near }, FACE, 1)
		local afterFar = Slams.pickTarget({ far, near }, FACE, 2)
		expect(first and first.userId).toBe(1)
		expect(afterNear and afterNear.userId).toBe(2)
		expect(afterFar and afterFar.userId).toBe(1)
	end)

	it("a player who appeared at the door less than DoorSeconds ago is not a target, at DoorSeconds is", function()
		local almost = player(1, 5, 0, { appearedAgo = Config.Wake.DoorSeconds - 0.1 })
		local exactly = player(1, 5, 0, { appearedAgo = Config.Wake.DoorSeconds })
		local other = player(2, 80, 0)
		local early = Slams.pickTarget({ almost, other }, FACE, nil)
		local ready = Slams.pickTarget({ exactly, other }, FACE, nil)
		expect(early and early.userId).toBe(2)
		expect(ready and ready.userId).toBe(1)
	end)

	it("a player who joined this wake-up is never a target", function()
		local joined = player(1, 5, 0, { joinedThisWake = true })
		local target = Slams.pickTarget({ joined, player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(2)
		expect(Slams.pickTarget({ joined }, FACE, nil)).toBeNil()
	end)

	it("a player the last slam bonked is skipped, and is the target again when not bonked", function()
		local other = player(2, 80, 0)
		local skipped = Slams.pickTarget({ player(1, 5, 0, { bonkedLast = true }), other }, FACE, nil)
		local again = Slams.pickTarget({ player(1, 5, 0, { bonkedLast = false }), other }, FACE, nil)
		expect(skipped and skipped.userId).toBe(2)
		expect(again and again.userId).toBe(1)
	end)

	it("a player in a garden or floating is never a target, with or without an egg", function()
		local nobody = {
			player(1, 5, 0, { inGarden = true }),
			player(2, 5, 0, { floating = true }),
			player(3, 5, 0, { inGarden = true, carrying = false }),
			player(4, 5, 0, { floating = true, carrying = false }),
		}
		expect(Slams.pickTarget(nobody, FACE, nil)).toBeNil()
	end)

	it("a player who landed a moment ago can still be a target (only floating players are skipped)", function()
		local target = Slams.pickTarget({ player(1, 5, 0, { landedAgo = 0.2 }), player(2, 80, 0) }, FACE, nil)
		expect(target and target.userId).toBe(1)
	end)

	it("nobody fits: nil", function()
		local nobody = {
			player(1, 5, 0, { joinedThisWake = true }),
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
		local players = { player(1, 0, 0, { carrying = false, joinedThisWake = true }) }
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

describe("Slams.inCircle", function()
	local centre = Vector3.new(0, 40, 0)

	it("is true on the circle's edge, across the ground", function()
		local radius = Config.Wake.SlamCircleDiameter / 2
		expect(Slams.inCircle(Vector3.new(radius, 40, 0), centre)).toBe(true)
		expect(Slams.inCircle(Vector3.new(radius + 0.5, 40, 0), centre)).toBe(false)
	end)

	it("is false for someone far above the circle", function()
		expect(Slams.inCircle(Vector3.new(0, 70, 0), centre)).toBe(false)
	end)
end)

describe("Slams.hits", function()
	local centre = Vector3.new(-50, 40, 20)
	local circle = { centre = centre, point = Vector3.new(-50, 0, 20) }
	local function surfaceUnder(_position: Vector3): number
		return 0
	end
	local function at(userId: number, height: number, changes: { [string]: any }?): Player
		local made: any = player(userId, -50, 20, changes)
		made.position = Vector3.new(-50, height, 20)
		return made :: Player
	end

	it("a carrier 30 studs over the surface is caught, 46 studs over is not hit", function()
		expect(Slams.hits({ at(1, 30) }, circle, surfaceUnder)).toEqual({ caught = { 1 }, bonked = {} })
		expect(Slams.hits({ at(1, 46) }, circle, surfaceUnder)).toEqual({ caught = {}, bonked = {} })
	end)

	it("a player with no egg inside the circle is bonked, not caught", function()
		expect(Slams.hits({ at(1, 5, { carrying = false }) }, circle, surfaceUnder)).toEqual({
			caught = {},
			bonked = { 1 },
		})
	end)

	it("a carrier and a player with no egg in one circle: one is caught, one is bonked", function()
		local players = { at(7, 5, { carrying = false }), at(3, 5) }
		expect(Slams.hits(players, circle, surfaceUnder)).toEqual({ caught = { 3 }, bonked = { 7 } })
	end)

	it("a player 2 studs under the surface point (under a bridge) is not hit", function()
		expect(Slams.hits({ at(1, -2), at(2, -2, { carrying = false }) }, circle, surfaceUnder)).toEqual({
			caught = {},
			bonked = {},
		})
	end)

	it("a player 15 studs from the centre is hit, 15.1 studs is not", function()
		local edge: any = player(1, -35, 20, { carrying = false })
		edge.position = Vector3.new(-35, 5, 20)
		local outside: any = player(2, -34.9, 20, { carrying = false })
		outside.position = Vector3.new(-34.9, 5, 20)
		expect(Slams.hits({ edge, outside }, circle, surfaceUnder)).toEqual({ caught = {}, bonked = { 1 } })
	end)

	it("a player in a garden or floating is never hit", function()
		expect(Slams.hits({ at(1, 5, { inGarden = true }), at(2, 5, { floating = true }) }, circle, surfaceUnder)).toEqual({
			caught = {},
			bonked = {},
		})
	end)

	it("a player who landed 1.4 s ago is not hit, 1.5 s ago is hit", function()
		expect(Slams.hits({ at(1, 5, { landedAgo = 1.4 }) }, circle, surfaceUnder)).toEqual({ caught = {}, bonked = {} })
		expect(Slams.hits({ at(1, 5, { landedAgo = 1.5 }) }, circle, surfaceUnder)).toEqual({
			caught = { 1 },
			bonked = {},
		})
	end)
end)

-- Rules 62 and 63: who the director plans a protected warning for. A player the engine would hit for free is
-- protected, because a circle aimed at them would land before they could move.
describe("Slams.isProtected", function()
	it("a player the slam before bonked is protected", function()
		expect(Slams.isProtected(player(1, 0, 60, { carrying = false, bonkedLast = true }))).toBe(true)
	end)

	it("a player who appeared at the door less than the door seconds ago is protected", function()
		local justBefore = Config.Wake.DoorSeconds - 0.1
		expect(Slams.isProtected(player(1, 0, 60, { carrying = false, appearedAgo = justBefore }))).toBe(true)
	end)

	it("a player who appeared exactly the door seconds ago is no longer protected", function()
		local changes = { carrying = false, appearedAgo = Config.Wake.DoorSeconds }
		expect(Slams.isProtected(player(1, 0, 60, changes))).toBe(false)
	end)

	it("a player who never appeared and wasn't bonked is not protected", function()
		expect(Slams.isProtected(player(1, 0, 60, { carrying = false }))).toBe(false)
	end)

	it("a floating player is not protected even at the door", function()
		local changes = { carrying = false, appearedAgo = 0.5, floating = true }
		expect(Slams.isProtected(player(1, 0, 60, changes))).toBe(false)
	end)

	it("a bonked player who is back in a garden is not protected", function()
		local changes = { carrying = false, bonkedLast = true, inGarden = true }
		expect(Slams.isProtected(player(1, 0, 60, changes))).toBe(false)
	end)

	it("a player who joined during this wake-up is not protected", function()
		local changes = { carrying = false, bonkedLast = true, appearedAgo = 0.5, joinedThisWake = true }
		expect(Slams.isProtected(player(1, 0, 60, changes))).toBe(false)
	end)
end)

-- Rule 60, the ladder grace: for a short time after a player first touches a ladder in a wake-up, no circle is aimed at
-- them, and the director plans a show slam instead of a warning at them (like the door and the bonk).
describe("Slams ladder grace", function()
	it("a player in their grace is not picked and the next player is", function()
		local near = player(1, 0, 60, { inLadderGrace = true })
		local far = player(2, 0, 100)
		local picked = Slams.pickTarget({ near, far }, FACE, nil)
		expect(if picked ~= nil then picked.userId else nil).toBe(2)
	end)

	it("a player is picked again once they are past their grace", function()
		local inGrace = player(1, 0, 60, { inLadderGrace = true })
		local past = player(1, 0, 60, { inLadderGrace = false })
		local far = player(2, 0, 100)
		local whileInGrace = Slams.pickTarget({ inGrace, far }, FACE, nil)
		local afterGrace = Slams.pickTarget({ past, far }, FACE, nil)
		expect(if whileInGrace ~= nil then whileInGrace.userId else nil).toBe(2)
		expect(if afterGrace ~= nil then afterGrace.userId else nil).toBe(1)
	end)

	it("a player in their grace is protected", function()
		expect(Slams.isProtected(player(1, 0, 60, { carrying = false, inLadderGrace = true }))).toBe(true)
	end)

	it("a floating or in-garden player in their grace is still not protected (the exits come first)", function()
		expect(Slams.isProtected(player(1, 0, 60, { inLadderGrace = true, floating = true }))).toBe(false)
		expect(Slams.isProtected(player(1, 0, 60, { inLadderGrace = true, inGarden = true }))).toBe(false)
		expect(Slams.isProtected(player(1, 0, 60, { inLadderGrace = true, joinedThisWake = true }))).toBe(false)
	end)
end)
