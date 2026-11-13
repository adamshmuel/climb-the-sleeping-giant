--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamFx = require(Client.Fx.SlamFx)
local Helpers = require(script.Parent.Helpers)
local POINT = Helpers.POINT
local UP = Helpers.UP
local cleanUp = Helpers.cleanUp
local countChildren = Helpers.countChildren
local expectNear = Helpers.expectNear
local newRig = Helpers.newRig
local newSignal = Helpers.newSignal
local stops = Helpers.stops
local theDust = Helpers.theDust
local theFist = Helpers.theFist
local warnAndBuild = Helpers.warnAndBuild

afterEach(cleanUp)

describe("SlamFx.start: housekeeping", function()
	it("keeps two slams apart by their numbers", function()
		local rig = newRig()
		local second = Vector3.new(-30, 2, 15)
		rig.warn(1, POINT, 1.5)
		rig.advance(1.0)
		rig.warn(2, second, 1.5)
		expect(#rig.circles()).toBe(2)
		rig.land(2, second) -- only the second one lands now
		expect(#rig.bursts).toBe(2)
		local dust = theDust(rig) :: Part
		expectNear(dust.Position, second + UP * 2) -- the dust starts 2 studs above its own slam's point
		expect(rig.step:count()).toBe(1)
	end)

	it("lets the first slam finish while the second goes on", function()
		local rig = newRig()
		local second = Vector3.new(-30, 2, 15)
		warnAndBuild(rig, 1, POINT, 1.5)
		rig.advance(1.0)
		warnAndBuild(rig, 2, second, 1.5)
		rig.advance(0.5) -- the first lands
		rig.advance(1.0) -- 1.0 after the first landing: the first is over, the second is still falling
		expect(#rig.circles()).toBe(1)
		expect(#rig.pieces() > 100).toBe(true)
		for _, piece in rig.pieces() do
			expect(
				(Vector3.new(piece.Position.X, 0, piece.Position.Z) - Vector3.new(second.X, 0, second.Z)).Magnitude < 16
			).toBe(true)
		end
		expect(rig.step:count()).toBe(1)
		rig.advance(1.5)
		rig.advance(1.5)
		expect(countChildren(rig)).toBe(0)
		expect(rig.step:count()).toBe(0)
	end)

	it("ignores a SlamLanded for a slam number it does not know", function()
		local rig = newRig()
		rig.land(99, POINT)
		expect(#rig.bursts).toBe(0)
		expect(rig.folder()).toBeNil()
		rig.warn(1, POINT, 1.5)
		rig.land(99, POINT)
		rig.advance(0.5)
		expect(#rig.bursts).toBe(0)
		expect(theDust(rig)).toBeNil()
		expect(#rig.circles()).toBe(1)
	end)

	it("draws nothing for a warning whose landing time has already passed", function()
		local rig = newRig()
		rig.warn(1, POINT, -0.5)
		expect(countChildren(rig)).toBe(0)
		expect(rig.step:count()).toBe(0)
		expect(#rig.normalCalls).toBe(0)
		rig.advance(1)
		expect(#rig.bursts).toBe(0)
	end)

	it("ignores a warning with the wrong kind of values", function()
		local rig = newRig()
		rig.slamWarning:Fire("one", POINT, rig.now() + 1.5)
		rig.slamWarning:Fire(1, "there", rig.now() + 1.5)
		rig.slamWarning:Fire(1, POINT, "soon")
		rig.slamWarning:Fire(1, POINT, 0 / 0)
		rig.slamLanded:Fire("one", POINT)
		expect(countChildren(rig)).toBe(0)
		expect(rig.step:count()).toBe(0)
	end)

	it("connects to the step once, however many slams are on screen", function()
		local rig = newRig()
		expect(rig.step:count()).toBe(0)
		rig.warn(1, POINT, 1.5)
		rig.warn(2, Vector3.new(1, 2, 3), 1.5)
		expect(rig.step:count()).toBe(1)
	end)

	it("starts again when a new slam comes after the step was let go", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		rig.advance(1.5)
		expect(rig.step:count()).toBe(0)
		rig.warn(2, POINT, 1.5)
		expect(rig.step:count()).toBe(1)
		expect(#rig.circles()).toBe(1)
	end)

	it("replaces the slam's pieces when a warning comes again with the same number", function()
		local rig = newRig()
		local newPoint = Vector3.new(50, 2, 50)
		warnAndBuild(rig, 1, POINT, 1.5)
		local oldCircle = rig.circles()[1]
		local oldPiece = rig.pieces()[1]
		warnAndBuild(rig, 1, newPoint, 1.5)
		expect(#rig.circles()).toBe(1)
		expect(oldCircle.Parent).toBeNil()
		expect(oldPiece.Parent).toBeNil()
		expect(#rig.pieces() > 100).toBe(true)
		for _, piece in rig.pieces() do
			expect(
				(Vector3.new(piece.Position.X, 0, piece.Position.Z) - Vector3.new(newPoint.X, 0, newPoint.Z)).Magnitude
					< 16
			).toBe(true)
		end
	end)

	it("stops building the old circle when a warning replaces it", function()
		local rig = newRig()
		local newPoint = Vector3.new(50, 2, 50)
		rig.warn(1, POINT, 1.5) -- the old circle is only partly built
		local before = #rig.hugCalls
		rig.warn(1, newPoint, 1.5)
		rig.settle()
		for index = before + 1, #rig.hugCalls do
			local origin = rig.hugCalls[index]
			expect((Vector3.new(origin.X, 0, origin.Z) - Vector3.new(newPoint.X, 0, newPoint.Z)).Magnitude < 22).toBe(
				true
			)
		end
	end)

	it("does not look at the giant's state: a slam already drawn finishes by itself", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		expect(#rig.bursts).toBe(2)
		expect(theFist(rig)).never.toBeNil()
	end)
end)

describe("SlamFx.start: stop", function()
	it("removes every part, the folder and every connection, in the middle of a slam", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		rig.advance(0.5) -- the fist is down, the circle is fading, the dust is flying
		expect(theDust(rig)).never.toBeNil()
		rig.stop()
		expect(#rig.parent:GetChildren()).toBe(0)
		expect(rig.step:count()).toBe(0)
		expect(rig.slamWarning:count()).toBe(0)
		expect(rig.slamLanded:count()).toBe(0)
	end)

	it("removes the circle and a falling fist too", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.1)
		expect(theFist(rig)).never.toBeNil()
		rig.stop()
		expect(#rig.parent:GetChildren()).toBe(0)
	end)

	it("stops building a circle that is half built, and casts no more rays", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		local casts = #rig.hugCalls
		expect(casts > 0).toBe(true)
		rig.stop()
		rig.advance(0)
		rig.advance(0)
		rig.advance(0)
		expect(#rig.hugCalls).toBe(casts)
		expect(#rig.parent:GetChildren()).toBe(0)
	end)

	it("can be stopped twice without an error", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.stop()
		rig.stop()
		expect(#rig.parent:GetChildren()).toBe(0)
	end)

	it("changes nothing on later warnings or steps", function()
		local rig = newRig()
		rig.stop()
		rig.warn(1, POINT, 1.5)
		rig.advance(2)
		expect(#rig.parent:GetChildren()).toBe(0)
		expect(rig.step:count()).toBe(0)
	end)
end)

describe("SlamFx.start: onCircle", function()
	it("gives onCircle the server's point once for each warning it accepts", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		expect(#rig.circleCalls).toBe(1)
		expectNear(rig.circleCalls[1], POINT)
		rig.advance(0.2)
		rig.advance(0.2)
		expect(#rig.circleCalls).toBe(1)
		local second = Vector3.new(-30, 2, 15)
		rig.warn(2, second, 1.5)
		expect(#rig.circleCalls).toBe(2)
		expectNear(rig.circleCalls[2], second)
	end)

	it("calls onCircle once the circle's first pieces are on screen", function()
		local rig = newRig()
		local piecesSeen = -1
		local watcher = SlamFx.start({
			slamWarning = { OnClientEvent = rig.slamWarning },
			slamLanded = { OnClientEvent = rig.slamLanded },
			fist = rig.template,
			parent = rig.parent,
			surfaceNormal = function(_point: Vector3)
				return UP
			end,
			castHug = function(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
				return origin + direction * 0.5, UP
			end,
			onCircle = function(_point: Vector3)
				piecesSeen = #rig.pieces()
			end,
			serverNow = function()
				return rig.now()
			end,
			step = newSignal(),
			burst = function(_emitter: ParticleEmitter, _count: number) end,
		})
		table.insert(stops, watcher.stop)
		rig.slamWarning:Fire(7, POINT, rig.now() + 1.5)
		expect(piecesSeen > 0).toBe(true)
	end)

	it("does not call onCircle for a warning it rejects", function()
		local rig = newRig()
		rig.slamWarning:Fire("one", POINT, rig.now() + 1.5)
		rig.slamWarning:Fire(1, "there", rig.now() + 1.5)
		rig.slamWarning:Fire(1, POINT, "soon")
		rig.slamWarning:Fire(1, POINT, 0 / 0)
		rig.warn(2, POINT, -0.5) -- the landing time has already passed
		expect(#rig.circleCalls).toBe(0)
	end)

	it("does not call onCircle after stop", function()
		local rig = newRig()
		rig.stop()
		rig.warn(1, POINT, 1.5)
		expect(#rig.circleCalls).toBe(0)
	end)
end)
