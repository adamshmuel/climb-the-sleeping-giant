--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(ServerScriptService.Server.Giant.Noise)
local LandingDetector = require(ServerScriptService.Server.Players.LandingDetector)

-- Under strict typing a plain local widens "Belly" to `string`, so each zone is declared with its type.
local MEADOW: Config.ZoneName = "Meadow"
local BOOTS: Config.ZoneName = "Boots"
local BELLY: Config.ZoneName = "Belly"

-- One 0.1 s tick of what the tracker sees: on standable ground or not, the up/down speed, the zone.
-- `takeoffs` lists the zones the character took off from since the last tick, oldest first (nil means none).
type Tick = { grounded: boolean, speed: number, zone: Config.ZoneName, takeoffs: { Config.ZoneName }? }

-- Appends `count` identical ticks to `ticks`.
local function add(ticks: { Tick }, count: number, grounded: boolean, speed: number, zone: Config.ZoneName)
	for _ = 1, count do
		table.insert(ticks, { grounded = grounded, speed = speed, zone = zone })
	end
end

-- Appends one tick on which the character jumped from the zone the tick is in.
local function addJump(ticks: { Tick }, grounded: boolean, speed: number, zone: Config.ZoneName)
	table.insert(ticks, { grounded = grounded, speed = speed, zone = zone, takeoffs = { zone } })
end

-- Appends one tick with the given take-off zones, which may differ from the zone the tick is in.
local function addTakeoffs(
	ticks: { Tick },
	grounded: boolean,
	speed: number,
	zone: Config.ZoneName,
	takeoffs: { Config.ZoneName }
)
	table.insert(ticks, { grounded = grounded, speed = speed, zone = zone, takeoffs = takeoffs })
end

-- One thud: the tick it came on (counting from 1) and its zone.
type Thud = { tick: number, zone: Config.ZoneName }

-- Feeds the ticks to a fall tracker that starts in `startZone`, and returns every thud with its tick, in order.
local function thudTicksFor(startZone: Config.ZoneName, ticks: { Tick }): { Thud }
	local state = LandingDetector.new(startZone)
	local thuds: { Thud } = {}
	for index, tick in ticks do
		local thud: Config.ZoneName?
		thud, state = LandingDetector.step(state, tick.grounded, tick.speed, tick.zone, tick.takeoffs or {})
		if thud ~= nil then
			table.insert(thuds, { tick = index, zone = thud })
		end
	end
	return thuds
end

-- The zone of every thud, in order.
local function thudsFor(startZone: Config.ZoneName, ticks: { Tick }): { Config.ZoneName }
	local zones: { Config.ZoneName } = {}
	for _, thud in thudTicksFor(startZone, ticks) do
		table.insert(zones, thud.zone)
	end
	return zones
end

describe("LandingDetector.step", function()
	it("standing still never thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 20, true, 0, BELLY)
		expect(#thudsFor(BELLY, ticks)).toBe(0)
	end)

	it("a jump on the belly that lands back on the belly gives one Belly thud", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 2, false, 30, BELLY) -- going up
		add(ticks, 2, false, -20, BELLY) -- coming down fast
		add(ticks, 5, true, 0, BELLY) -- back on the belly
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
	end)

	it(
		"a jump off the belly that slides down his side, touches a boot ledge and stops in the meadow gives one Belly thud",
		function()
			local ticks: { Tick } = {}
			add(ticks, 2, true, 0, BELLY)
			add(ticks, 3, false, -25, BELLY) -- in the air
			add(ticks, 1, true, -20, BELLY) -- slides down his 65 degree side
			add(ticks, 2, true, -15, BOOTS) -- touches a boot ledge, still going down
			add(ticks, 3, false, -20, BOOTS) -- drops off the ledge
			add(ticks, 5, true, 0, MEADOW) -- stops in the meadow
			expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
		end
	)

	it("a fall from the belly that stops on a boot top gives one Belly thud", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 4, false, -25, BELLY)
		add(ticks, 5, true, 0, BOOTS)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
	end)

	it("a jump in the meadow returns Meadow, which makes no noise", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, MEADOW)
		add(ticks, 2, false, 30, MEADOW)
		add(ticks, 2, false, -25, MEADOW)
		add(ticks, 5, true, 0, MEADOW)
		local thuds = thudsFor(MEADOW, ticks)
		expect(thuds).toEqual({ MEADOW })
		expect(Noise.jumpBurst(thuds[1], nil)).toBe(0)
	end)

	it("one missed ground check while walking down a slope is not a fall", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, -4, BELLY)
		add(ticks, 1, false, -20, BELLY) -- the ground check missed once
		add(ticks, 5, true, 0, BELLY)
		expect(#thudsFor(BELLY, ticks)).toBe(0)
	end)

	it("stepping off the belly path without jumping gives one Belly thud", function()
		local ticks: { Tick } = {}
		add(ticks, 5, true, 0, BELLY) -- resting on the path
		add(ticks, 4, true, -15, BELLY) -- sliding down his side, still on the ground
		add(ticks, 1, false, -15, BELLY) -- one tick in the air
		add(ticks, 1, true, -12, BOOTS) -- a boot slope
		add(ticks, 2, false, -25, BOOTS) -- the drop
		add(ticks, 2, false, -25, MEADOW)
		add(ticks, 5, true, 0, MEADOW)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
	end)

	it("a meadow jump beside his body that rises into a Belly box gives a Meadow thud", function()
		local ticks: { Tick } = {}
		add(ticks, 5, true, 0, MEADOW)
		add(ticks, 2, false, 30, BELLY) -- going up, inside the Belly box
		add(ticks, 1, false, 0, BELLY)
		add(ticks, 3, false, -25, MEADOW) -- coming down fast
		add(ticks, 5, true, 0, MEADOW)
		local thuds = thudsFor(MEADOW, ticks)
		expect(thuds).toEqual({ MEADOW })
		expect(Noise.jumpBurst(thuds[1], nil)).toBe(0)
	end)

	it("a jump from a boot top that lands up on the belly gives a Boots thud", function()
		local ticks: { Tick } = {}
		add(ticks, 5, true, 0, BOOTS)
		add(ticks, 2, false, 30, BOOTS)
		add(ticks, 2, false, -25, BELLY)
		add(ticks, 5, true, 0, BELLY)
		expect(thudsFor(BOOTS, ticks)).toEqual({ BOOTS })
	end)

	it("walking down from the belly onto a boot top, resting, then jumping off gives a Boots thud", function()
		local ticks: { Tick } = {}
		add(ticks, 5, true, 0, BELLY)
		add(ticks, 3, true, -15, BELLY) -- walking down the path
		add(ticks, 3, true, -15, BOOTS)
		add(ticks, 3, true, 0, BOOTS) -- rests on the boot top
		add(ticks, 4, false, -25, BOOTS) -- jumps off
		add(ticks, 5, true, 0, MEADOW)
		expect(thudsFor(BELLY, ticks)).toEqual({ BOOTS })
	end)

	it("climbing up a ladder never thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 30, false, 16, BELLY) -- on the ladder, going up at walking pace
		add(ticks, 5, true, 0, BELLY)
		expect(#thudsFor(BELLY, ticks)).toBe(0)
	end)

	it("climbing slowly down never thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 30, false, -5, BELLY)
		add(ticks, 5, true, 0, BELLY)
		expect(#thudsFor(BELLY, ticks)).toBe(0)
	end)

	it("a thud is reported once, not again while standing", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 5, false, -25, BELLY)
		add(ticks, 30, true, 0, BELLY) -- standing for three seconds afterwards
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
	end)

	it("a short hop that never falls faster than 10 makes no thud", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		for _, speed in { 8, 4, 0, -4, -8, -10 } do
			add(ticks, 1, false, speed, BELLY)
		end
		add(ticks, 5, true, 0, BELLY)
		expect(#thudsFor(BELLY, ticks)).toBe(0)
	end)
end)

describe("LandingDetector.step with a jump", function()
	it("an uphill jump that is in the air for only 2 ticks gives one Belly thud", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY) -- the jump, still on the ground this tick
		add(ticks, 1, false, 5, BELLY) -- the ground rises under them, so they are barely in the air
		add(ticks, 1, false, -3, BELLY)
		add(ticks, 3, true, 0, BELLY)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
	end)

	it("a jump in the meadow returns Meadow, which makes no noise", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, MEADOW)
		addJump(ticks, true, 0, MEADOW)
		add(ticks, 2, false, 3, MEADOW)
		add(ticks, 3, true, 0, MEADOW)
		local thuds = thudsFor(MEADOW, ticks)
		expect(thuds).toEqual({ MEADOW })
		expect(Noise.jumpBurst(thuds[1], nil)).toBe(0)
	end)

	it("a jump made on the ground raises the zone by the zone of that tick", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, MEADOW)
		addJump(ticks, true, 0, BELLY)
		add(ticks, 1, false, 4, BELLY)
		add(ticks, 3, true, 0, BELLY)
		expect(thudsFor(MEADOW, ticks)).toEqual({ BELLY })
	end)

	it("a jump from a boot top where they had just come to rest gives a Boots thud, not a Belly one", function()
		local ticks: { Tick } = {}
		add(ticks, 5, true, 0, BELLY)
		add(ticks, 3, true, -15, BELLY) -- walking down the path
		add(ticks, 3, true, -15, BOOTS)
		add(ticks, 2, true, 0, BOOTS)
		addJump(ticks, true, 0, BOOTS) -- the jump is the third tick at rest, which forgets the Belly
		add(ticks, 1, false, 4, BOOTS)
		add(ticks, 3, true, 0, BOOTS)
		expect(thudsFor(BELLY, ticks)).toEqual({ BOOTS })
	end)

	it("a jump seen first on a tick in the air still thuds the highest zone so far", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, false, 5, MEADOW) -- the box of another zone reaches out over the air
		add(ticks, 1, false, -3, MEADOW)
		add(ticks, 3, true, 0, MEADOW)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY })
	end)

	it("a jump seen in the air never raises the zone by the zone of that tick", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, MEADOW)
		addTakeoffs(ticks, false, 5, BELLY, { MEADOW }) -- took off from the meadow; only the air above it is in the Belly box
		add(ticks, 1, false, -3, MEADOW)
		add(ticks, 3, true, 0, MEADOW)
		local thuds = thudsFor(MEADOW, ticks)
		expect(thuds).toEqual({ MEADOW })
		expect(Noise.jumpBurst(thuds[1], nil)).toBe(0)
	end)

	it("a second jump during a jump's fall makes the first jump thud when it lands, so two thuds in all", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY)
		add(ticks, 1, false, 5, BELLY)
		addJump(ticks, false, 2, BELLY) -- jumps again while the first fall is still going
		add(ticks, 1, false, -3, BELLY)
		add(ticks, 3, true, 0, BELLY)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY, BELLY })
	end)

	it("a jump during a fast fall that began without a jump thuds the fall, then the jump, so two thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 3, false, -25, BELLY) -- the fall has started
		addJump(ticks, false, -25, BELLY)
		add(ticks, 3, true, 0, BELLY)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY, BELLY })
	end)

	it("two jumps with a landing between them give two thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY)
		add(ticks, 1, false, 3, BELLY)
		add(ticks, 3, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY)
		add(ticks, 1, false, 3, BELLY)
		add(ticks, 3, true, 0, BELLY)
		expect(thudsFor(BELLY, ticks)).toEqual({ BELLY, BELLY })
	end)

	it("walking down a slope at 9 studs a second with no jump never thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 5, true, 0, BELLY)
		add(ticks, 10, false, -9, BELLY)
		add(ticks, 5, true, 0, BELLY)
		expect(#thudsFor(BELLY, ticks)).toBe(0)
	end)
end)

describe("LandingDetector.step with Jump held down", function()
	it(
		"three hops with no tick on the ground between them give three Belly thuds, two at the next take-offs",
		function()
			local ticks: { Tick } = {}
			add(ticks, 2, true, 0, BELLY) -- ticks 1 and 2
			addJump(ticks, true, 0, BELLY) -- tick 3: the first hop
			add(ticks, 4, false, 3, BELLY) -- ticks 4 to 7: in the air
			addJump(ticks, false, 5, BELLY) -- tick 8: the second hop
			add(ticks, 4, false, 3, BELLY) -- ticks 9 to 12
			addJump(ticks, false, 5, BELLY) -- tick 13: the third hop
			add(ticks, 4, false, 3, BELLY) -- ticks 14 to 17
			add(ticks, 5, true, 0, BELLY) -- ticks 18 to 22: a rest
			expect(thudTicksFor(BELLY, ticks)).toEqual({
				{ tick = 8, zone = BELLY },
				{ tick = 13, zone = BELLY },
				{ tick = 20, zone = BELLY }, -- the third tick at rest
			})
		end
	)

	it("three hops with one tick on the ground between them give three Belly thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY) -- ticks 1 and 2
		addJump(ticks, true, 0, BELLY) -- tick 3
		add(ticks, 3, false, 3, BELLY) -- ticks 4 to 6
		add(ticks, 1, true, 0, BELLY) -- tick 7: the one tick on the ground
		addJump(ticks, true, 0, BELLY) -- tick 8
		add(ticks, 3, false, 3, BELLY) -- ticks 9 to 11
		add(ticks, 1, true, 0, BELLY) -- tick 12
		addJump(ticks, true, 0, BELLY) -- tick 13
		add(ticks, 3, false, 3, BELLY) -- ticks 14 to 16
		add(ticks, 5, true, 0, BELLY) -- ticks 17 to 21
		expect(thudTicksFor(BELLY, ticks)).toEqual({
			{ tick = 8, zone = BELLY },
			{ tick = 13, zone = BELLY },
			{ tick = 19, zone = BELLY },
		})
	end)

	it("hopping off him thuds for the hop that left him and not for the meadow hops after it", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY) -- tick 3: Belly hop
		add(ticks, 3, false, 3, BELLY)
		addJump(ticks, false, 5, BELLY) -- tick 7: Belly hop, the first one landed
		add(ticks, 3, false, 3, BELLY)
		addTakeoffs(ticks, false, 5, MEADOW, { MEADOW }) -- tick 11: leaves him from the meadow edge; the second Belly hop landed
		add(ticks, 3, false, 3, MEADOW)
		addJump(ticks, false, 5, MEADOW) -- tick 15: a meadow hop
		add(ticks, 3, false, 3, MEADOW)
		addJump(ticks, false, 5, MEADOW) -- tick 19: another meadow hop
		add(ticks, 3, false, 3, MEADOW)
		add(ticks, 5, true, 0, MEADOW) -- a rest in the meadow
		local thuds = thudsFor(BELLY, ticks)
		expect(thuds).toEqual({ BELLY, BELLY, MEADOW, MEADOW, MEADOW })
		local noise: { number } = {}
		for _, zone: Config.ZoneName in thuds do
			table.insert(noise, Noise.jumpBurst(zone, nil))
		end
		expect(noise).toEqual({ 30, 30, 0, 0, 0 })
	end)

	it(
		"a fast fall without a jump thuds at the take-off of a jump on landing, and the jump thuds when it lands",
		function()
			local ticks: { Tick } = {}
			add(ticks, 2, true, 0, BELLY)
			add(ticks, 3, false, -25, BELLY) -- ticks 3 to 5: a fast fall
			addTakeoffs(ticks, true, -5, BOOTS, { BOOTS }) -- tick 6: lands on a boot top and jumps with no rest between
			add(ticks, 2, false, 3, BOOTS)
			add(ticks, 4, true, 0, BOOTS)
			expect(thudTicksFor(BELLY, ticks)).toEqual({
				{ tick = 6, zone = BELLY }, -- the fall, from its own highest zone
				{ tick = 11, zone = BOOTS }, -- the jump, from its take-off zone alone
			})
		end
	)

	it("a slow slide without a jump makes no thud of its own when a jump follows: only the jump thuds", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		add(ticks, 3, false, -5, BELLY) -- ticks 3 to 5: a slow fall, under the 10 studs a second
		addTakeoffs(ticks, true, 0, BOOTS, { BOOTS }) -- tick 6
		add(ticks, 1, false, 3, BOOTS)
		add(ticks, 4, true, 0, BOOTS)
		expect(thudTicksFor(BELLY, ticks)).toEqual({ { tick = 10, zone = BOOTS } })
	end)

	it("two take-offs on one tick while a jump's fall is under way give two thuds on two ticks in a row", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY) -- tick 3
		add(ticks, 2, false, 3, BELLY)
		addTakeoffs(ticks, false, 5, BELLY, { BOOTS, MEADOW }) -- tick 6: two take-offs seen at once
		add(ticks, 2, false, 3, MEADOW) -- ticks 7 and 8
		add(ticks, 3, true, 0, MEADOW)
		expect(thudTicksFor(BELLY, ticks)).toEqual({
			{ tick = 6, zone = BELLY }, -- the first jump landed
			{ tick = 7, zone = BOOTS }, -- the second jump landed too: owed one tick
			{ tick = 11, zone = MEADOW }, -- the last jump, at rest
		})
	end)

	it("thuds that pile up come out one a tick, in the order they were due, before any new one", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY) -- tick 3
		add(ticks, 2, false, 3, BELLY)
		addTakeoffs(ticks, false, 5, BELLY, { BOOTS, MEADOW }) -- tick 6: one thud now, one owed
		addTakeoffs(ticks, false, 5, MEADOW, { BELLY }) -- tick 7: one more is due, behind the owed one
		add(ticks, 1, false, 3, BELLY) -- tick 8
		add(ticks, 3, true, 0, BELLY)
		expect(thudTicksFor(BELLY, ticks)).toEqual({
			{ tick = 6, zone = BELLY },
			{ tick = 7, zone = BOOTS },
			{ tick = 8, zone = MEADOW },
			{ tick = 11, zone = BELLY },
		})
	end)

	it("a jump's zone is its take-off zone, not the zone of the tick it is seen on", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, MEADOW)
		addTakeoffs(ticks, false, 5, MEADOW, { BELLY }) -- seen over the meadow, but it took off from the belly
		add(ticks, 1, false, -3, MEADOW)
		add(ticks, 3, true, 0, MEADOW)
		expect(thudsFor(MEADOW, ticks)).toEqual({ BELLY })
	end)

	it("a jump right after a hop landed starts from its own take-off zone, not the zone before", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY) -- tick 3: a Belly hop
		add(ticks, 3, false, 3, BELLY)
		add(ticks, 1, true, 0, BOOTS) -- tick 7: lands on a boot top
		addJump(ticks, true, 0, BOOTS) -- tick 8: hops again from the boot top
		add(ticks, 2, false, 3, BOOTS)
		add(ticks, 3, true, 0, BOOTS)
		expect(thudTicksFor(BELLY, ticks)).toEqual({
			{ tick = 8, zone = BELLY },
			{ tick = 13, zone = BOOTS }, -- not Belly
		})
	end)

	it("4 take-offs a tick for 10 ticks never leave more than 4 thuds waiting, and the oldest are kept", function()
		local state = LandingDetector.new(BELLY)
		local mostWaiting = 0
		local zones: { Config.ZoneName } = { BELLY, BOOTS, MEADOW, BELLY }
		local returned: { Config.ZoneName } = {}
		for _ = 1, 10 do
			local thud: Config.ZoneName?
			thud, state = LandingDetector.step(state, false, 5, BELLY, zones)
			mostWaiting = math.max(mostWaiting, #state.owed)
			if thud ~= nil then
				table.insert(returned, thud)
			end
		end
		expect(mostWaiting).toBe(4)
		-- A tick of 4 take-offs with a jump-fall under way makes 4 thuds: one is returned, the rest wait (3 at most).
		-- Once 4 are waiting, the newest are dropped, so the first tick's thuds come out before any later ones.
		expect(#returned).toBe(10)
		expect(returned[1]).toBe(BELLY)
	end)

	it("a held-Jump run that ends on the ground thuds its last hop once, on the third tick at rest", function()
		local ticks: { Tick } = {}
		add(ticks, 2, true, 0, BELLY)
		addJump(ticks, true, 0, BELLY) -- tick 3
		add(ticks, 3, false, 3, BELLY)
		addJump(ticks, false, 5, BELLY) -- tick 7
		add(ticks, 30, true, 0, BELLY) -- standing for three seconds afterwards: ticks 8 to 37
		expect(thudTicksFor(BELLY, ticks)).toEqual({
			{ tick = 7, zone = BELLY },
			{ tick = 10, zone = BELLY },
		})
	end)
end)
