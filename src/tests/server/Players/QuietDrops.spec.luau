--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local QuietDrops = require(ServerScriptService.Server.Players.QuietDrops)
local WayDown = require(ServerScriptService.Server.Players.WayDown)

type ZoneName = Config.ZoneName
-- One tick of one player: where the root is, the zone, whether a fall is under way, and what the tracker flagged.
type Tick = { position: Vector3, zone: ZoneName, falling: boolean, thudFrom: ZoneName?, jumped: boolean? }

-- Ladders as WayDown wants them (the real ones are read from the world; these stand in at the same shape).
local LADDERS: { WayDown.Ladder } = {
	{ name = "CapLadder", kind = "head", foot = Vector3.new(0, 94, -4), top = Vector3.new(0, 109, -2) },
	{ name = "BeardLadder", kind = "head", foot = Vector3.new(0, 63, -25), top = Vector3.new(0, 93, -6) },
	{
		name = "BootLadder_Left",
		kind = "boot",
		foot = Vector3.new(-50, 2, -64),
		top = Vector3.new(-34, 30, -64),
		ground = Vector3.new(-51.3, 2, -64),
	},
}
-- A seam line along the belly's front edge: "below" it is +Z, passed by more than Config.Nests.SeamMatch.
local SEAM = { { position = Vector3.new(0, 60, 0), down = Vector3.new(0, 0, 1) } }

local function sampleOf(userId: number, tick: Tick): PlayerTracker.Sample
	return {
		userId = userId,
		position = tick.position,
		moving = true,
		groundSpeed = 11.5,
		zone = tick.zone,
		garden = nil,
		thudFrom = tick.thudFrom,
		falling = tick.falling,
		jumped = tick.jumped,
		moveGrace = false,
		onStitchedEdge = false,
	}
end

-- Feeds the ticks to a watch one by one and returns the last sample after the watch has seen it.
local function play(watch: QuietDrops.Watch, ticks: { Tick }, userId: number?): PlayerTracker.Sample
	local last: PlayerTracker.Sample = sampleOf(userId or 1, ticks[1])
	for _, tick in ticks do
		last = sampleOf(userId or 1, tick)
		watch:check({ last })
	end
	return last
end

local function newWatch(): QuietDrops.Watch
	return QuietDrops.new({ ladders = LADDERS, seam = SEAM })
end

local function stand(position: Vector3, zone: ZoneName): Tick
	return { position = position, zone = zone, falling = false }
end

local function air(position: Vector3, zone: ZoneName, jumped: boolean?): Tick
	return { position = position, zone = zone, falling = true, jumped = jumped }
end

local function land(position: Vector3, zone: ZoneName, from: ZoneName, jumped: boolean?): Tick
	return { position = position, zone = zone, falling = false, thudFrom = from, jumped = jumped }
end

local CAP_TOP = Vector3.new(0, 108, -2)
local NOSE = Vector3.new(0, 97, 0)

describe("QuietDrops cap ladder", function()
	it("drops the thud and sets quiet on a fall from the cap's top onto the nose top", function()
		local watch = newWatch()
		local last = play(watch, {
			stand(CAP_TOP, "Nightcap"),
			air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap"),
			air(CAP_TOP - Vector3.new(0, 8, 0), "Nightcap"),
			land(NOSE, "Beard", "Nightcap"),
		})
		expect(last.thudFrom).toBe(nil)
		expect(last.quiet).toBe(true)
		expect(last.moving).toBe(true)
		expect(last.groundSpeed).toBe(11.5)
	end)

	it("keeps the thud on the same fall when it ends in the Meadow", function()
		local watch = newWatch()
		local last = play(watch, {
			stand(CAP_TOP, "Nightcap"),
			air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap"),
			land(Vector3.new(0, 3, 40), "Meadow", "Nightcap"),
		})
		expect(last.thudFrom).toBe("Nightcap")
		expect(last.quiet).toBe(nil)
	end)
end)

describe("QuietDrops beard ladder", function()
	local LET_GO = Vector3.new(0, 78, -15.5) -- on the line from the ladder's foot to its top
	it("is quiet for a let-go that ends on the belly", function()
		local watch = newWatch()
		local last = play(watch, {
			stand(LET_GO, "Beard"),
			air(LET_GO - Vector3.new(0, 5, 0), "Beard"),
			land(Vector3.new(0, 63, -20), "Belly", "Beard"),
		})
		expect(last.thudFrom).toBe(nil)
		expect(last.quiet).toBe(true)
	end)

	it("keeps the thud when the same let-go ends in the Boots", function()
		local watch = newWatch()
		local last = play(watch, {
			stand(LET_GO, "Beard"),
			air(LET_GO - Vector3.new(0, 5, 0), "Beard"),
			land(Vector3.new(30, 30, -60), "Boots", "Beard"),
		})
		expect(last.thudFrom).toBe("Beard")
	end)

	it("keeps the thud on a fall that passed below the seam line before it ended on the belly", function()
		local watch = newWatch()
		local last = play(watch, {
			stand(LET_GO, "Beard"),
			air(Vector3.new(0, 70, 20), "Beard"),
			land(Vector3.new(0, 63, -20), "Belly", "Beard"),
		})
		expect(last.thudFrom).toBe("Beard")
		expect(last.quiet).toBe(nil)
	end)
end)

describe("QuietDrops boot ladder", function()
	local ON_LADDER = Vector3.new(-42, 16, -64) -- on the line from the foot to the top
	local function letGo(endX: number): PlayerTracker.Sample
		return play(newWatch(), {
			stand(ON_LADDER, "Boots"),
			air(ON_LADDER - Vector3.new(0, 6, 0), "Boots"),
			land(Vector3.new(endX, 2, -64), "Meadow", "Boots"),
		})
	end

	it("is quiet for a let-go that lands 5 studs from the ladder's ground point", function()
		local last = letGo(-51.3 + 5)
		expect(last.thudFrom).toBe(nil)
		expect(last.quiet).toBe(true)
	end)

	it("keeps the thud for a let-go that lands 9 studs from the ladder's ground point", function()
		expect(letGo(-51.3 + 9).thudFrom).toBe("Boots")
	end)

	it("keeps the thud for a fall off the boot that began 2 studs beside the ladder line", function()
		local beside = ON_LADDER + Vector3.new(0, 0, 2)
		local last = play(newWatch(), {
			stand(beside, "Boots"),
			air(beside - Vector3.new(0, 6, 0), "Boots"),
			land(Vector3.new(-51.3 + 5, 2, -64), "Meadow", "Boots"),
		})
		expect(last.thudFrom).toBe("Boots")
	end)
end)

describe("QuietDrops jumps", function()
	it("keeps the thud when the fall began with a jump", function()
		local last = play(newWatch(), {
			stand(CAP_TOP, "Nightcap"),
			air(CAP_TOP + Vector3.new(0, 2, 0), "Nightcap", true),
			air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap", true),
			land(NOSE, "Beard", "Nightcap", false),
		})
		expect(last.thudFrom).toBe("Nightcap")
		expect(last.quiet).toBe(nil)
	end)

	it("keeps the thud when the jump is owed on the tick the fall lands", function()
		local last = play(newWatch(), {
			stand(CAP_TOP, "Nightcap"),
			air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap"),
			land(NOSE, "Beard", "Nightcap", true),
		})
		expect(last.thudFrom).toBe("Nightcap")
	end)
end)

describe("QuietDrops.forget", function()
	it("clears the user, so a thud with no fall on record stays", function()
		local watch = newWatch()
		play(watch, { stand(CAP_TOP, "Nightcap"), air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap") })
		watch:forget(1)
		local last = play(watch, { land(NOSE, "Beard", "Nightcap") })
		expect(last.thudFrom).toBe("Nightcap")
	end)

	it("keeps each user's fall apart when two fall in the same ticks", function()
		local watch = newWatch()
		local one = {
			stand(CAP_TOP, "Nightcap"),
			air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap"),
			land(NOSE, "Beard", "Nightcap"),
		}
		local two = {
			stand(CAP_TOP, "Nightcap"),
			air(CAP_TOP - Vector3.new(0, 4, 0), "Nightcap"),
			land(Vector3.new(0, 3, 40), "Meadow", "Nightcap"),
		}
		local first, second = sampleOf(1, one[1]), sampleOf(2, two[1])
		for i = 1, 3 do
			first, second = sampleOf(1, one[i]), sampleOf(2, two[i])
			watch:check({ first, second })
		end
		expect(first.quiet).toBe(true)
		expect(second.thudFrom).toBe("Nightcap")
	end)
end)
