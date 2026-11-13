--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Point = Helpers.Point
local HALF_SOLE = Helpers.HALF_SOLE
local LIFT = Helpers.LIFT
local SIT_HEIGHT = Helpers.SIT_HEIGHT
local UPDATE_SECONDS = Helpers.UPDATE_SECONDS
local cleanUp = Helpers.cleanUp
local expectNear = Helpers.expectNear
local made = Helpers.made
local newRig = Helpers.newRig
local pivotsAlong = Helpers.pivotsAlong

afterEach(cleanUp)

-- The gap on the boot-ramp planks, where the cleats (0.295 studs tall) would cut through a footprint lower than this.
local RAMP_LIFT = 0.35

describe("Footprints.start: lying on the ground", function()
	it("asks the ground finder about the route position of each footprint, ignoring its own copies", function()
		local rig = newRig()
		expect(#rig.groundCalls).toBe(6)
		local call = rig.groundCalls[1]
		expect(call.ignore).toBe(rig.folder())
		-- The route position, which is on the route line (y = 0), not 3 studs above: the finder adds the 3.
		expect(call.position.Y).toBeCloseTo(0, 3)
	end)

	it("sits LIFT above flat ground", function()
		local rig = newRig()
		rig.ground.find = function(position: Vector3)
			return Vector3.new(position.X, 7, position.Z), Vector3.new(0, 1, 0)
		end
		rig.advance(UPDATE_SECONDS)
		for _, pivot in pivotsAlong(rig.shown(), "X", true) do
			expect(pivot.Position.Y).toBeCloseTo(7 + SIT_HEIGHT, 3)
		end
	end)

	-- How far a footprint's bottom is above `hit`, measured along `up`. The pivot is at the middle of the sole.
	local function gapAbove(pivot: CFrame, hit: Vector3, up: Vector3): number
		return (pivot.Position - hit):Dot(up) - HALF_SOLE
	end

	it("sits RAMP_LIFT above a boot-ramp plank", function()
		local rig = newRig()
		local plank = made(Instance.new("Part"))
		plank.Name = "Ramp_Walk"
		-- The plank rises 1 stud for every 2 studs toward +X, with its normal leaning toward -X.
		local normal = Vector3.new(-1, 2, 0).Unit
		rig.ground.find = function(position: Vector3)
			return Vector3.new(position.X, position.X / 2, position.Z), normal, plank
		end
		rig.advance(UPDATE_SECONDS)
		local pivot = pivotsAlong(rig.shown(), "X", true)[1]
		-- 20 studs along X: the plank is 10 high there.
		expect(gapAbove(pivot, Vector3.new(20, 10, 0), normal)).toBeCloseTo(RAMP_LIFT, 3)
	end)

	it("sits LIFT above any other part, and above ground whose part is not given", function()
		local rig = newRig()
		local rock = made(Instance.new("Part"))
		rock.Name = "Rock"
		local normal = Vector3.new(-1, 2, 0).Unit
		local function slope(position: Vector3): Vector3
			return Vector3.new(position.X, position.X / 2, position.Z)
		end
		rig.ground.find = function(position: Vector3)
			return slope(position), normal, rock
		end
		rig.advance(UPDATE_SECONDS)
		expect(gapAbove(pivotsAlong(rig.shown(), "X", true)[1], Vector3.new(20, 10, 0), normal)).toBeCloseTo(LIFT, 3)
		rig.ground.find = function(position: Vector3)
			return slope(position), normal
		end
		rig.advance(UPDATE_SECONDS)
		expect(gapAbove(pivotsAlong(rig.shown(), "X", true)[1], Vector3.new(20, 10, 0), normal)).toBeCloseTo(LIFT, 3)
	end)

	it("uses LIFT on the route line when the ramp plank is too far below it", function()
		local rig = newRig()
		local plank = made(Instance.new("Part"))
		plank.Name = "Ramp_Walk"
		rig.ground.find = function(position: Vector3)
			return Vector3.new(position.X, -2, position.Z), Vector3.new(0, 1, 0), plank
		end
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expect(#pivots).toBe(6)
		for _, pivot in pivots do
			expect(pivot.Position.Y).toBeCloseTo(SIT_HEIGHT, 3)
		end
	end)

	it("tilts with the ground and keeps the toes pointing the way to walk", function()
		local rig = newRig()
		-- The ground rises 1 stud for every 2 studs toward +X: a slope with the normal leaning toward -X.
		local normal = Vector3.new(-1, 2, 0).Unit
		rig.ground.find = function(position: Vector3)
			return Vector3.new(position.X, position.X / 2, position.Z), normal
		end
		rig.feet.value = Vector3.new(0, 0, 0.5)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		local first = pivots[1]
		expectNear(first.UpVector, normal)
		-- 20 studs along X: the ground is 10 high there. The pivot sits SIT_HEIGHT above it along the normal.
		expectNear(first.Position, Vector3.new(20, 10, 0) + normal * SIT_HEIGHT)
		-- Toes point along +X, flattened onto the slope: they climb with it.
		local walk = (Vector3.new(1, 0, 0) - normal * normal.X).Unit
		expectNear(first.LookVector, walk)
	end)

	it("sits on the route line when there is no ground", function()
		local rig = newRig()
		rig.ground.find = function(_position: Vector3)
			return nil, nil
		end
		rig.feet.value = Vector3.new(0, 0, 0.5)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expect(#pivots).toBe(6)
		expectNear(pivots[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
		expectNear(pivots[1].LookVector, Vector3.new(1, 0, 0))
	end)

	it("sits on the route line when the ground is far below it, like the stream bed under a gap in a bridge", function()
		local rig = newRig()
		rig.ground.find = function(position: Vector3)
			return Vector3.new(position.X, -4, position.Z), Vector3.new(0, 1, 0)
		end
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expect(#pivots).toBe(6)
		for _, pivot in pivots do
			expect(pivot.Position.Y).toBeCloseTo(SIT_HEIGHT, 3)
		end
	end)

	it("still lies on ground a little below the route line, as a slope can be", function()
		local rig = newRig()
		rig.ground.find = function(position: Vector3)
			return Vector3.new(position.X, -1, position.Z), Vector3.new(0, 1, 0)
		end
		rig.advance(UPDATE_SECONDS)
		for _, pivot in pivotsAlong(rig.shown(), "X", true) do
			expect(pivot.Position.Y).toBeCloseTo(-1 + SIT_HEIGHT, 3)
		end
	end)

	it("follows a ramp: the toes point up the slope", function()
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "T" }, target = nil },
			{ name = "T", position = Vector3.new(10, 5, 0), neighbours = { "S" }, target = "EggSpot_Common_1" },
		}
		local rig = newRig({ points = points, waiting = { "EggSpot_Common_1" } })
		-- The ground is the ramp itself: it rises 5 in 10, and its normal leans toward -X.
		local normal = Vector3.new(-5, 10, 0).Unit
		rig.ground.find = function(position: Vector3)
			return position, normal
		end
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expectNear(pivots[1].Position, Vector3.new(10, 5, 0) + normal * SIT_HEIGHT)
		expectNear(pivots[1].UpVector, normal)
		expectNear(pivots[1].LookVector, Vector3.new(10, 5, 0).Unit)
	end)

	it("keeps the toes along the horizontal part of the way when there is no ground", function()
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "T" }, target = nil },
			{ name = "T", position = Vector3.new(10, 5, 0), neighbours = { "S" }, target = "EggSpot_Common_1" },
		}
		local rig = newRig({ points = points, waiting = { "EggSpot_Common_1" } })
		rig.ground.find = function(_position: Vector3)
			return nil, nil
		end
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expectNear(pivots[1].Position, Vector3.new(10, 5 + SIT_HEIGHT, 0))
		expectNear(pivots[1].LookVector, Vector3.new(1, 0, 0))
	end)
end)

describe("Footprints.start: a way that runs straight up", function()
	it("lies flat on the ground with its toes along +X, since the way gives no direction on the ground", function()
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "T" }, target = nil },
			{ name = "T", position = Vector3.new(0, 8, 0), neighbours = { "S" }, target = "EggSpot_Common_1" },
		}
		local rig = newRig({ points = points, waiting = { "EggSpot_Common_1" } })
		local shown = rig.shown()
		expect(#shown > 0).toBe(true)
		for _, model in shown do
			local pivot = model:GetPivot()
			expectNear(pivot.UpVector, Vector3.new(0, 1, 0))
			expectNear(pivot.LookVector, Vector3.new(1, 0, 0))
		end
	end)
end)

describe("Footprints.start: respawning", function()
	it("starts again from the new character's feet, with nothing left from the old one", function()
		local rig = newRig()
		rig.feet.value = nil -- the old character is gone
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
		-- The new character appears 10 studs along the way.
		rig.feet.value = Vector3.new(10, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		-- Only footprints between the new character and E1: 20, 16.4, 12.8 (10 studs of way, 3 footprints).
		expect(#pivots).toBe(3)
		expectNear(pivots[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
		expectNear(pivots[3].Position, Vector3.new(12.8, SIT_HEIGHT, 0))
	end)
end)
