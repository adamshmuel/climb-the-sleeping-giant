--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamCircle = require(Client.Fx.SlamCircle)
local SlamFx = require(Client.Fx.SlamFx)
local Theme = require(Client.Hud.Theme)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local BASE_CLOCK = Helpers.BASE_CLOCK
local POINT = Helpers.POINT
local SLOPE_58 = Helpers.SLOPE_58
local UP = Helpers.UP
local cleanUp = Helpers.cleanUp
local expectNear = Helpers.expectNear
local made = Helpers.made
local newRig = Helpers.newRig
local newSignal = Helpers.newSignal
local stops = Helpers.stops
local transparencyOfPieces = Helpers.transparencyOfPieces
local warnAndBuild = Helpers.warnAndBuild

afterEach(cleanUp)

local RAYS_A_FRAME = 1000

describe("SlamFx.start: the red circle", function()
	it("makes nothing until a warning comes", function()
		local rig = newRig()
		rig.advance(0.5)
		expect(rig.folder()).toBeNil()
		expect(rig.step:count()).toBe(0)
	end)

	it(
		"makes a SlamFx folder under the parent, with a SlamCircle folder of red and gold pieces, on a warning",
		function()
			local rig = newRig()
			rig.warn(1, POINT, 1.5)
			expect(rig.folder()).never.toBeNil()
			expect(#rig.circles()).toBe(1)
			expect(#rig.pieces() > 0).toBe(true)
			for _, piece in rig.pieces() do
				expect((piece.Parent :: Instance).Name).toBe("SlamCircle")
			end
			rig.settle()
			local red, gold = 0, 0
			for _, piece in rig.pieces() do
				if piece.Name == "SlamRedPiece" then
					red += 1
				else
					gold += 1
				end
			end
			expect(red > 80).toBe(true)
			expect(gold > 20).toBe(true)
		end
	)

	it("makes no part named SlamGold or SlamRed, whatever surface castHug reports", function()
		for _, setUp in
			{
				function(_rig: Rig) end,
				function(rig: Rig)
					rig.setSurface(POINT, SLOPE_58)
				end,
				function(rig: Rig)
					rig.setSurfaceMissing(true)
				end,
			}
		do
			local rig = newRig()
			setUp(rig)
			warnAndBuild(rig, 1, POINT, 1.5)
			rig.advance(0.2)
			local slams = rig.folder()
			expect(slams).never.toBeNil()
			expect((slams :: Folder):FindFirstChild("SlamGold", true)).toBeNil()
			expect((slams :: Folder):FindFirstChild("SlamRed", true)).toBeNil()
		end
	end)

	it("paints the red pieces slamRed and the gold pieces slamGold", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		local red, gold = 0, 0
		for _, piece in rig.pieces() do
			if piece.Name == "SlamRedPiece" then
				red += 1
				expect(piece.Color == Theme.slamRed).toBe(true)
			else
				gold += 1
				expect(piece.Color == Theme.slamGold).toBe(true)
			end
		end
		expect(red > 0 and gold > 0).toBe(true)
	end)

	it("makes every piece a Neon block, solid, with no shadow", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		expect(#rig.pieces() > 100).toBe(true)
		for _, piece in rig.pieces() do
			expect(piece.Shape).toBe(Enum.PartType.Block)
			expect(piece.Material).toBe(Enum.Material.Neon)
			expect(piece.Transparency).toBe(0)
			expect(piece.CastShadow).toBe(false)
		end
	end)

	it("makes every piece anchored and untouchable: no collision, no ray hits, no touch events", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		expect(#rig.pieces() > 100).toBe(true)
		for _, piece in rig.pieces() do
			expect(piece.Anchored).toBe(true)
			expect(piece.CanCollide).toBe(false)
			expect(piece.CanQuery).toBe(false)
			expect(piece.CanTouch).toBe(false)
		end
	end)

	it("asks for the surface under the point (for the dust), once", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(0.5)
		expect(#rig.normalCalls).toBe(1)
		expectNear(rig.normalCalls[1], POINT)
	end)

	it("finds the circle's middle with one ray from 1 stud above the point, 4 studs straight down", function()
		local calls: { { origin: Vector3, direction: Vector3 } } = {}
		local rig = newRig()
		-- A second rig whose castHug records the rays, to see the first one.
		local parent = made(Instance.new("Folder"))
		local handle = SlamFx.start({
			slamWarning = { OnClientEvent = rig.slamWarning },
			slamLanded = { OnClientEvent = rig.slamLanded },
			fist = rig.template,
			parent = parent,
			surfaceNormal = function(_point: Vector3)
				return UP
			end,
			castHug = function(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
				table.insert(calls, { origin = origin, direction = direction })
				return nil, nil
			end,
			onCircle = function(_point: Vector3) end,
			serverNow = function()
				return BASE_CLOCK
			end,
			step = newSignal(),
			burst = function(_emitter: ParticleEmitter, _count: number) end,
		})
		table.insert(stops, handle.stop)
		rig.warn(1, POINT, 1.5)
		expect(#calls > 0).toBe(true)
		expectNear(calls[1].origin, POINT + Vector3.new(0, 1, 0))
		expectNear(calls[1].direction, Vector3.new(0, -4, 0))
	end)

	it("lies on what castHug finds: pieces tilted to a slope's normal, 0.11 to 0.12 above it", function()
		local rig = newRig()
		rig.setSurface(POINT, SLOPE_58)
		warnAndBuild(rig, 1, POINT, 1.5)
		expect(#rig.pieces() > 100).toBe(true)
		for _, piece in rig.pieces() do
			expectNear(piece.CFrame.YVector, SLOPE_58, 1e-3)
			local top = piece.Position + piece.CFrame.YVector * (piece.Size.Y / 2)
			local height = (top - POINT):Dot(SLOPE_58)
			expect(math.abs(height - (if piece.Name == "SlamGoldPiece" then 0.11 else 0.12)) < 1e-3).toBe(true)
		end
	end)

	it("faces the way the surface under the point faces, so a slope needs no stretched pieces", function()
		local rig = newRig()
		rig.setSurface(POINT, SLOPE_58)
		warnAndBuild(rig, 1, POINT, 1.5)
		-- Facing the slope, every cell is one piece. Facing straight up, the pieces would have to be longer than the cells
		-- (the ground leans away from the circle) and most would be split.
		expect(#rig.pieces()).toBe(#SlamCircle.layout())
	end)

	it("puts the circle's middle piece over the point when the surface is level", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		local nearest = math.huge
		for _, piece in rig.pieces() do
			nearest = math.min(
				nearest,
				(Vector3.new(piece.Position.X, 0, piece.Position.Z) - Vector3.new(POINT.X, 0, POINT.Z)).Magnitude
			)
		end
		expect(nearest < 0.01).toBe(true)
	end)

	it("makes no pieces, and still shows the fist, where there is no surface at all", function()
		local rig = newRig()
		rig.setSurfaceMissing(true)
		rig.warn(1, POINT, 1.5)
		rig.settle()
		expect(#rig.pieces()).toBe(0)
		expect(rig.step:count()).toBe(1) -- the slam is still on screen: the fist comes
	end)

	it(
		"centres the circle on the point when the middle ray finds nothing, and the pieces find the ground themselves",
		function()
			local rig = newRig()
			-- The ground is 5 studs under the point: the middle ray (which reaches 3 studs below it) misses, but a piece's ray
			-- (which reaches 6 studs below the circle's plane) finds it.
			rig.setSurface(POINT - Vector3.new(0, 5, 0), UP)
			warnAndBuild(rig, 1, POINT, 1.5)
			expect(#rig.pieces() > 100).toBe(true)
			local nearest = math.huge
			for _, piece in rig.pieces() do
				-- The piece's middle is 0.085 (gold) or 0.095 (red) above the ground.
				expect(math.abs(piece.Position.Y - (POINT.Y - 5 + 0.09)) < 0.02).toBe(true)
				nearest = math.min(
					nearest,
					(Vector3.new(piece.Position.X, 0, piece.Position.Z) - Vector3.new(POINT.X, 0, POINT.Z)).Magnitude
				)
			end
			expect(nearest < 0.5).toBe(true)
		end
	)

	it("stays solid while the fist falls and while it is down", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		rig.advance(1.0)
		expect(transparencyOfPieces(rig)).toBe(0)
		rig.advance(0.5) -- the landing
		rig.advance(0.3)
		expect(transparencyOfPieces(rig)).toBe(0)
	end)

	it("asks for the surfaces it hugs once for each warning, before the circle's first ray", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		expect(#rig.refreshCalls).toBe(1)
		expect(rig.refreshCalls[1]).toBe(0)
		rig.settle()
		rig.advance(0.5)
		expect(#rig.refreshCalls).toBe(1)
		rig.warn(2, POINT, 1.5)
		expect(#rig.refreshCalls).toBe(2)
	end)
end)

describe("SlamFx.start: building the circle over a few frames", function()
	it("makes the first pieces at once, when the warning arrives", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		expect(#rig.pieces() > 50).toBe(true)
	end)

	it("casts at most 1,000 rays at the warning", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		expect(#rig.hugCalls > 0).toBe(true)
		expect(#rig.hugCalls <= RAYS_A_FRAME).toBe(true)
	end)

	it("casts at most 1,000 rays in each later frame", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		local frames = 0
		for _ = 1, 6 do
			local before = #rig.hugCalls
			rig.advance(1 / 60)
			expect(#rig.hugCalls - before <= RAYS_A_FRAME).toBe(true)
			if #rig.hugCalls > before then
				frames += 1
			end
		end
		expect(frames > 0).toBe(true)
	end)

	it("casts at most 1,000 rays in each later frame, even for a circle that needs thousands", function()
		local rig = newRig()
		rig.setBumpy(true)
		rig.warn(1, POINT, 1.5)
		expect(#rig.hugCalls <= RAYS_A_FRAME).toBe(true)
		local frames = 1
		for _ = 1, 12 do
			local before = #rig.hugCalls
			rig.advance(1 / 60)
			expect(#rig.hugCalls - before <= RAYS_A_FRAME).toBe(true)
			if #rig.hugCalls > before then
				frames += 1
			end
		end
		expect(frames >= 6).toBe(true) -- it really did go on over several frames
	end)

	it("gives up on a circle that keeps failing after 8,000 rays", function()
		local rig = newRig()
		rig.setBumpy(true)
		rig.warn(1, POINT, 1.5)
		for _ = 1, 20 do
			rig.advance(1 / 60)
		end
		expect(#rig.hugCalls <= 8000 + 1).toBe(true) -- the middle ray and at most 8,000 for the pieces
		expect(#rig.hugCalls > 7000).toBe(true)
	end)

	it("shares one frame's 1,000 rays between the warning and the step that comes right after it", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(0)
		expect(#rig.hugCalls <= RAYS_A_FRAME).toBe(true)
		rig.advance(0)
		expect(#rig.hugCalls <= 2 * RAYS_A_FRAME).toBe(true)
	end)

	it("finishes a circle on level ground within three frames, and then casts nothing more", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		for _ = 1, 3 do
			rig.advance(1 / 60)
		end
		local total = #rig.hugCalls
		expect(#rig.pieces() > 100).toBe(true)
		rig.advance(1 / 60)
		rig.advance(1 / 60)
		expect(#rig.hugCalls).toBe(total)
	end)

	it("shares the 1,000 rays of a frame between two circles that are building together", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.warn(2, Vector3.new(-30, 2, 15), 1.5)
		rig.advance(0)
		local before = #rig.hugCalls
		rig.advance(0)
		expect(#rig.hugCalls - before <= RAYS_A_FRAME).toBe(true)
		rig.advance(0)
		expect(#rig.circles()).toBe(2)
	end)
end)
