--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SlideWatch = require(ServerScriptService.Server.Players.SlideWatch)

type SeamPoint = SlideWatch.SeamPoint
type Reading = SlideWatch.Reading
type Extra = { falling: boolean?, thudFrom: string?, moveGrace: boolean?, onStitchedEdge: boolean? }

local MATCH = Config.Nests.SeamMatch
local ACROSS = 4 -- SlideWatch's local "across" limit (card, "The decision")
local USER = 7

-- Fake seam: 3 points down one belly side (downhill is -Z), 6 along a cuff rim (downhill is +Z).
local seam: { SeamPoint } = {}
for i = 0, 2 do
	table.insert(seam, { position = Vector3.new(0, 40, -3 * i), down = Vector3.new(0, 0, -1) })
end
for i = 0, 5 do
	table.insert(seam, { position = Vector3.new(30 + 3 * i, 20, 0), down = Vector3.new(0, 0, 1) })
end

local function reading(position: Vector3, extra: Extra?): Reading
	local e: Extra = extra or {}
	return {
		userId = USER,
		position = position,
		falling = e.falling == true,
		thudFrom = e.thudFrom,
		moveGrace = e.moveGrace == true,
		onStitchedEdge = e.onStitchedEdge == true,
	}
end

type Fakes = { tips: number, slides: { number }, floating: boolean, watch: any }

local function newFakes(): Fakes
	local fakes = { tips = 0, slides = {}, floating = false } :: any
	fakes.watch = SlideWatch.new({
		seam = seam,
		floating = function(_userId: number): boolean
			return fakes.floating
		end,
		fireTip = function(_userId: number)
			fakes.tips += 1
		end,
		onSlide = function(_userId: number, slideNumber: number)
			table.insert(fakes.slides, slideNumber)
		end,
	})
	return fakes
end

-- One whole fall: a walking tick at `start`, falling ticks along `path`, then the thud tick at `finish`.
local function fall(
	fakes: Fakes,
	start: Vector3,
	path: { Vector3 },
	finish: Vector3,
	startStitched: boolean?,
	graceAt: number?
)
	fakes.watch:check({ reading(start, { onStitchedEdge = startStitched }) })
	for i, point in path do
		fakes.watch:check({ reading(point, { falling = true, moveGrace = graceAt == i }) })
	end
	fakes.watch:check({ reading(finish, { thudFrom = "Hard" }) })
end

-- The belly side: start behind the seam at (0, y, 5), pass below it at z -10, land `drop` lower at z -12.
local function bellyFall(fakes: Fakes, drop: number, graceAt: number?)
	local y = 60
	fall(
		fakes,
		Vector3.new(0, y, 5),
		{ Vector3.new(0, y - 1, 5), Vector3.new(0, y - 2, -10) },
		Vector3.new(0, y - drop, -12),
		false,
		graceAt
	)
end

describe("SlideWatch slide cases", function()
	it("counts a fall that passes below the seam and ends 20 studs lower", function()
		local fakes = newFakes()
		bellyFall(fakes, 20)
		expect(fakes.slides).toEqual({ 1 })
	end)

	it("counts a fall below the seam that ends 8 studs lower", function()
		local fakes = newFakes()
		bellyFall(fakes, 8)
		expect(fakes.slides).toEqual({ 1 })
	end)

	it("ignores a fall below the seam that ends 4 studs lower", function()
		local fakes = newFakes()
		bellyFall(fakes, 4)
		expect(#fakes.slides).toBe(0)
	end)

	it("counts a fall that began on a stitched edge and ends 6 studs lower, never below the seam", function()
		local fakes = newFakes()
		fall(fakes, Vector3.new(100, 60, 100), { Vector3.new(100, 58, 100) }, Vector3.new(100, 54, 100), true)
		expect(fakes.slides).toEqual({ 1 })
	end)

	it("ignores a fall that began off the stitched edge, never below the seam, 1 stud lower", function()
		local fakes = newFakes()
		fall(fakes, Vector3.new(100, 60, 100), { Vector3.new(100, 59.5, 100) }, Vector3.new(100, 59, 100), false)
		expect(#fakes.slides).toBe(0)
	end)

	it("ignores a jump off the belly front: 8 studs lower, never below the seam, not on a stitched edge", function()
		local fakes = newFakes()
		fall(fakes, Vector3.new(100, 60, 100), { Vector3.new(100, 58, 100) }, Vector3.new(100, 52, 100), false)
		expect(#fakes.slides).toBe(0)
	end)

	it("counts a jump from the walk area that lands below the seam 8 studs lower", function()
		local fakes = newFakes()
		fall(
			fakes,
			Vector3.new(0, 48, 5),
			{ Vector3.new(0, 50, 5), Vector3.new(0, 44, -4) },
			Vector3.new(0, 40, -12),
			false
		)
		expect(fakes.slides).toEqual({ 1 })
	end)

	it("ignores a jump that lands below the seam only 1 stud lower", function()
		local fakes = newFakes()
		fall(
			fakes,
			Vector3.new(0, 41, 5),
			{ Vector3.new(0, 43, 5), Vector3.new(0, 41, -9) },
			Vector3.new(0, 40, -12),
			false
		)
		expect(#fakes.slides).toBe(0)
	end)

	it("throws the fall away when moveGrace is true on any tick", function()
		local fakes = newFakes()
		bellyFall(fakes, 20, 2)
		expect(#fakes.slides).toBe(0)
	end)

	it("throws the fall away when the player is floating", function()
		local fakes = newFakes()
		fakes.floating = true
		bellyFall(fakes, 20)
		expect(#fakes.slides).toBe(0)
	end)
end)

describe("SlideWatch.belowSeam", function()
	it("is below when 2 studs past a seam point downhill", function()
		expect(SlideWatch.belowSeam(Vector3.new(0, 10, -8), seam, MATCH, ACROSS)).toBe(true)
	end)

	it("is not below when 0.5 studs past a seam point", function()
		expect(SlideWatch.belowSeam(Vector3.new(0, 10, -6.5), seam, MATCH, ACROSS)).toBe(false)
	end)

	it("is not below when 6 studs across from every point", function()
		expect(SlideWatch.belowSeam(Vector3.new(6, 10, -2), seam, MATCH, ACROSS)).toBe(false)
	end)
end)

describe("SlideWatch tip", function()
	it("fires the tip only on the first slide and counts every slide", function()
		local fakes = newFakes()
		for _ = 1, 3 do
			bellyFall(fakes, 20)
		end
		expect(fakes.slides).toEqual({ 1, 2, 3 })
		expect(fakes.tips).toBe(1)
	end)

	it("treats a new slide after forget as a first slide", function()
		local fakes = newFakes()
		bellyFall(fakes, 20)
		fakes.watch:forget(USER)
		bellyFall(fakes, 20)
		expect(fakes.slides).toEqual({ 1, 1 })
		expect(fakes.tips).toBe(2)
	end)
end)
