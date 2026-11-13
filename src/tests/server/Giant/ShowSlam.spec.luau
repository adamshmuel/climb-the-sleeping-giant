--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local ShowSlam = require(ServerScriptService.Server.Giant.ShowSlam)
local Slams = require(ServerScriptService.Server.Giant.Slams)
local Zones = require(ServerScriptService.Server.Giant.Zones)

type Player = Slams.Player

-- His face is high up over the middle of the meadow. The spots, players and gates below sit around it.
local FACE = Vector3.new(0, 95, 0)
local RADIUS = Config.Wake.SlamCircleDiameter / 2 -- 15
local MARGIN = RADIUS + 1 -- 16: the circle's radius plus a 1-stud margin

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

local function spot(x: number, z: number): Vector3
	return Vector3.new(x, 0.5, z)
end

-- A flat grid of meadow spots, every 10 studs from -150 to 150.
local function grid(): { Vector3 }
	local spots = {}
	for x = -150, 150, 10 do
		for z = -150, 150, 10 do
			table.insert(spots, spot(x, z))
		end
	end
	return spots
end

local function flat(a: Vector3, b: Vector3): number
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end

-- Flat distance from a point to the stretch from a to b (the stretch only, worked out here on its own).
local function distanceToStretch(point: Vector3, a: Vector3, b: Vector3): number
	local ax, az, bx, bz = a.X, a.Z, b.X, b.Z
	local dx, dz = bx - ax, bz - az
	local lengthSquared = dx * dx + dz * dz
	local t = 0
	if lengthSquared > 0 then
		t = math.clamp(((point.X - ax) * dx + (point.Z - az) * dz) / lengthSquared, 0, 1)
	end
	return math.sqrt((point.X - (ax + t * dx)) ^ 2 + (point.Z - (az + t * dz)) ^ 2)
end

local function pickFirst(_count: number): number
	return 1
end

local function pickLast(count: number): number
	return count
end

local PICKS: { (number) -> number } = { pickFirst, pickLast }

local function show(
	spots: { Vector3 },
	players: { Player },
	protected: { Player },
	gates: { [number]: Vector3 },
	gardens: { Zones.GardenBox },
	landingSpots: { Vector3 },
	pick: (number) -> number,
	circleDiameter: number?
): Vector3?
	return ShowSlam.pickShow(spots, players, protected, gates, gardens, landingSpots, FACE, pick, circleDiameter)
end

describe("ShowSlam.pickShow", function()
	-- One protected player at the middle, their gate 30 studs west.
	local solo = player(1, 0, 0, { bonkedLast = true })
	local soloGate = Vector3.new(-30, 5, 0)

	it("1. a solo player just bonked: the spot is 35 to 45 studs from them", function()
		for _, pick in PICKS do
			local result = show(grid(), { solo }, { solo }, { [1] = soloGate }, {}, {}, pick)
			expect(result).never.toBe(nil)
			local distance = flat(result :: Vector3, solo.position)
			expect(distance >= Config.Wake.ShowSlamNearStuds).toBe(true)
			expect(distance <= Config.Wake.ShowSlamFarStuds).toBe(true)
		end
	end)

	it(
		"2. it is never within 16 studs of the stretch to their gate; a spot 20 studs past the gate is allowed",
		function()
			local gate = Vector3.new(-20, 5, 0)
			for _, pick in PICKS do
				local result = show(grid(), { solo }, { solo }, { [1] = gate }, {}, {}, pick)
				expect(result).never.toBe(nil)
				expect(distanceToStretch(result :: Vector3, solo.position, gate) >= MARGIN).toBe(true)
			end
			-- 40 studs from them, 20 past the gate on the same line: the line past the gate doesn't count.
			local past = spot(-40, 0)
			expect(show({ past }, { solo }, { solo }, { [1] = gate }, {}, {}, pickFirst)).toBe(past)
			-- 35 studs from them, 15 from the gate: inside the margin, and nothing else fits to 60 studs.
			local tooClose = spot(-35, 0)
			expect(show({ tooClose }, { solo }, { solo }, { [1] = gate }, {}, {}, pickFirst)).toBe(nil)
		end
	)

	it("2b. with a circle 40 studs wide the margin is 21 studs", function()
		local gate = Vector3.new(-20, 5, 0)
		local past = spot(-40, 0) -- 20 past the gate: allowed at 30 wide (margin 16), not at 40 wide (margin 21)
		local sideways = spot(0, 40) -- 40 studs from the stretch
		local spots = { past, sideways }
		expect(show(spots, { solo }, { solo }, { [1] = gate }, {}, {}, pickFirst, 30)).toBe(past)
		expect(show(spots, { solo }, { solo }, { [1] = gate }, {}, {}, pickFirst, 40)).toBe(sideways)
	end)

	it("3. it never covers another player, a landing spot or a garden", function()
		local box: Zones.GardenBox = { index = 1, cframe = CFrame.new(100, 20, 0), size = Vector3.new(60, 40, 60) }
		local bonked = player(1, 40, 0, { bonkedLast = true })
		local other = player(2, 40, 40)
		local gate = Vector3.new(72, 5, 0)
		local landing = spot(40, -40)
		local onOther = spot(40, 40) -- 40 from them, on the other player
		local onLanding = landing -- 40 from them, on the landing spot
		local inGarden = spot(78, 15) -- 40.8 from them, inside the garden, 16.2 from the stretch
		local good = spot(5, 0) -- 35 from them, clear of everything
		local spots = { onOther, onLanding, inGarden, good }
		for _, pick in PICKS do
			expect(show(spots, { bonked, other }, { bonked }, { [1] = gate }, { box }, { landing }, pick)).toBe(good)
		end
	end)

	it("4. two protected players, one just bonked: near the bonked one, off both lines home", function()
		local bonked = player(1, -40, 0, { bonkedLast = true })
		local second = player(2, 40, 0)
		local gates = { [1] = Vector3.new(-40, 5, -30), [2] = Vector3.new(40, 5, 30) }
		for _, pick in PICKS do
			local result = show(grid(), { bonked, second }, { bonked, second }, gates, {}, {}, pick)
			expect(result).never.toBe(nil)
			local at = result :: Vector3
			local distance = flat(at, bonked.position)
			expect(distance >= Config.Wake.ShowSlamNearStuds).toBe(true)
			expect(distance <= Config.Wake.ShowSlamFarStuds).toBe(true)
			expect(distanceToStretch(at, bonked.position, gates[1]) >= MARGIN).toBe(true)
			expect(distanceToStretch(at, second.position, gates[2]) >= MARGIN).toBe(true)
		end
	end)

	it("5. nobody bonked, two protected: near the one closer to the anchor", function()
		local far = player(1, -60, 0)
		local near = player(2, 30, 0)
		local gates = { [1] = Vector3.new(-60, 5, -30), [2] = Vector3.new(30, 5, 30) }
		for _, pick in PICKS do
			local result = show(grid(), { far, near }, { far, near }, gates, {}, {}, pick)
			expect(result).never.toBe(nil)
			local distance = flat(result :: Vector3, near.position)
			expect(distance >= Config.Wake.ShowSlamNearStuds).toBe(true)
			expect(distance <= Config.Wake.ShowSlamFarStuds).toBe(true)
		end
	end)

	it("6. the ring is full: the closest suiting spot out to 60; none to 60: nil", function()
		local gate = Vector3.new(0, 5, -20)
		local landing = spot(0, 40) -- the only ring spot is covered by a landing spot
		local ringSpot = spot(0, 40)
		local at50 = spot(50, 0)
		local at55 = spot(-55, 0)
		local at70 = spot(0, -70)
		local tooNear = spot(20, 0) -- 20 studs: fits every other rule, but under the near limit of 35, never picked
		expect(
			show(
				{ tooNear, ringSpot, at55, at70, at50 },
				{ solo },
				{ solo },
				{ [1] = gate },
				{},
				{ landing },
				pickFirst
			)
		).toBe(at50)
		expect(
			show(
				{ tooNear, ringSpot, at70, spot(-100, 0) },
				{ solo },
				{ solo },
				{ [1] = gate },
				{},
				{ landing },
				pickFirst
			)
		).toBe(nil)
	end)

	it("7. a solo protected player in a garden: nil", function()
		local inside = player(1, 100, 0, { bonkedLast = true, inGarden = true })
		local gate = Vector3.new(72, 5, 0)
		expect(show(grid(), { inside }, { inside }, { [1] = gate }, {}, {}, pickFirst)).toBe(nil)
	end)
end)
