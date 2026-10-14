--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamCircle = require(Client.Fx.SlamCircle)
local SlamFx = require(Client.Fx.SlamFx)
local Theme = require(Client.Hud.Theme)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A tiny stand-in for a RemoteEvent's OnClientEvent or RenderStepped: Connect, Fire and Disconnect, in plain Luau.
local function newSignal(): any
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

local UP = Vector3.new(0, 1, 0)
local SLOPE_58 = Vector3.new(math.sin(math.rad(58)), math.cos(math.rad(58)), 0)

local function expectNear(actual: Vector3, expected: Vector3, tolerance: number?)
	local margin = tolerance or 1e-3
	expect((actual - expected).Magnitude < margin).toBe(true)
end

describe("SlamFx constants", function()
	it("keeps the fist down for 0.4 seconds, for the giant's arm to read", function()
		expect(SlamFx.FIST_DOWN_SECONDS).toBe(0.4)
	end)
end)

describe("Theme slam colours", function()
	it("has the style guide's gold and red for the slam circle", function()
		expect(Theme.slamGold == Color3.fromHex("FFC93C")).toBe(true)
		expect(Theme.slamRed == Color3.fromHex("E0233A")).toBe(true)
	end)

	it("keeps the slam red apart from the banner's red, which stays FF3B4E", function()
		expect(Theme.bannerRed == Color3.fromHex("FF3B4E")).toBe(true)
		expect(Theme.slamRed == Theme.bannerRed).toBe(false)
	end)
end)

describe("SlamFx.fistHeight", function()
	it("is nil before the fist appears, 0.6 seconds before the landing", function()
		expect(SlamFx.fistHeight(-0.61)).toBeNil()
		expect(SlamFx.fistHeight(-5)).toBeNil()
	end)

	it("starts 45 studs up, 0.6 seconds before the landing", function()
		expect(SlamFx.fistHeight(-0.6)).toBe(45)
	end)

	it("touches the surface at the landing", function()
		expect(SlamFx.fistHeight(0)).toBeCloseTo(0, 2)
	end)

	it("stays down from the landing until 0.4 seconds after it", function()
		expect(SlamFx.fistHeight(0.2)).toBeCloseTo(0, 2)
		expect(SlamFx.fistHeight(0.4)).toBeCloseTo(0, 2)
	end)

	it("is 45 studs up again 0.8 seconds after the landing", function()
		expect(SlamFx.fistHeight(0.8)).toBeCloseTo(45, 2)
	end)

	it("is nil once it has lifted away", function()
		expect(SlamFx.fistHeight(0.81)).toBeNil()
		expect(SlamFx.fistHeight(3)).toBeNil()
	end)

	it("falls faster and faster: the last tenth of a second drops more than the first", function()
		local first = (SlamFx.fistHeight(-0.6) :: number) - (SlamFx.fistHeight(-0.5) :: number)
		local last = (SlamFx.fistHeight(-0.1) :: number) - (SlamFx.fistHeight(0) :: number)
		expect(last > first).toBe(true)
	end)

	it("lifts slowly at first: 45 times the square of how far through the lift it is", function()
		expect(SlamFx.fistHeight(0.6)).toBeCloseTo(45 * 0.25, 2)
		local first = (SlamFx.fistHeight(0.5) :: number) - (SlamFx.fistHeight(0.4) :: number)
		local last = (SlamFx.fistHeight(0.8) :: number) - (SlamFx.fistHeight(0.7) :: number)
		expect(last > first).toBe(true)
	end)
end)

describe("SlamFx.circleTransparency", function()
	it("is 0, solid, until the fist starts to lift, 0.4 seconds after the landing", function()
		expect(SlamFx.circleTransparency(-1.5)).toBe(0)
		expect(SlamFx.circleTransparency(0)).toBe(0)
		expect(SlamFx.circleTransparency(0.39)).toBe(0)
		expect(SlamFx.circleTransparency(0.4)).toBe(0)
	end)

	it("fades in a straight line to see-through over the next 0.3 seconds", function()
		expect(SlamFx.circleTransparency(0.55)).toBeCloseTo(0.5, 3)
		expect(SlamFx.circleTransparency(0.7)).toBeCloseTo(1, 3)
	end)

	it("is nil once the circle is gone", function()
		expect(SlamFx.circleTransparency(0.71)).toBeNil()
		expect(SlamFx.circleTransparency(5)).toBeNil()
	end)
end)

-- The fist as the place has it: a model whose pivot is not at its bottom and that is turned a little, with parts
-- that are NOT yet anchored, solid or touchable, so a test can see the module switch them.
local FIST_TURN = CFrame.Angles(0, math.rad(40), 0)

local function newFistTemplate(): Model
	local fist = made(Instance.new("Model"))
	fist.Name = "SlamFist"
	local body = Instance.new("Model")
	body.Name = "body"
	body.Parent = fist
	local geometry = Instance.new("Part")
	geometry.Name = "body_geom"
	geometry.Size = Vector3.new(20, 28, 22)
	geometry.CFrame = CFrame.new(300, 100, 40) * FIST_TURN
	geometry.Anchored = false
	geometry.CanCollide = true
	geometry.CanQuery = true
	geometry.CanTouch = true
	geometry.Parent = body
	local knuckle = Instance.new("Part")
	knuckle.Name = "knuckle"
	knuckle.Size = Vector3.new(4, 4, 4)
	knuckle.CFrame = CFrame.new(300, 90, 40) * FIST_TURN
	knuckle.Anchored = false
	knuckle.CanCollide = true
	knuckle.CanQuery = true
	knuckle.CanTouch = true
	knuckle.Parent = body
	fist.WorldPivot = CFrame.new(310, 120, 45) * FIST_TURN
	return fist
end

local function bottomOf(model: Model): number
	local cframe, size = model:GetBoundingBox()
	return cframe.Position.Y - size.Y / 2
end

local function centreOf(model: Model): Vector3
	return (model:GetBoundingBox()).Position
end

local BASE_CLOCK = 1024
local POINT = Vector3.new(10, 2, -20)
local RAYS_A_FRAME = 1000

type Burst = { name: string, count: number, parent: Instance?, emitter: ParticleEmitter }

type Rig = {
	parent: Folder,
	template: Model,
	slamWarning: any,
	slamLanded: any,
	step: any,
	stop: () -> (),
	bursts: { Burst },
	normalCalls: { Vector3 },
	hugCalls: { Vector3 }, -- the origin of every castHug ray
	refreshCalls: { number }, -- how many castHug rays had been cast each time refreshHug was called
	circleCalls: { Vector3 }, -- every point onCircle was given
	setNormal: (normal: Vector3) -> (), -- which way surfaceNormal (the dust's) says the ground faces
	setSurface: (point: Vector3, normal: Vector3) -> (), -- the plane castHug finds
	setSurfaceMissing: (missing: boolean) -> (),
	setBumpy: (bumpy: boolean) -> (), -- every 9th ray misses, so the circle keeps failing and needs thousands of rays
	advance: (seconds: number) -> (),
	settle: () -> (),
	now: () -> number,
	warn: (slam: number, point: Vector3, secondsAhead: number) -> number,
	land: (slam: number, point: Vector3) -> (),
	folder: () -> Folder?,
	parts: (name: string) -> { Part },
	circles: () -> { Folder },
	pieces: () -> { Part },
}

local function newRig(): Rig
	local parent = made(Instance.new("Folder"))
	local template = newFistTemplate()
	local slamWarning = newSignal()
	local slamLanded = newSignal()
	local step = newSignal()
	local clock = BASE_CLOCK
	local bursts: { Burst } = {}
	local normalCalls: { Vector3 } = {}
	local hugCalls: { Vector3 } = {}
	local refreshCalls: { number } = {}
	local circleCalls: { Vector3 } = {}
	local normal = UP
	-- The ground castHug finds: a plane through POINT, level unless a test says otherwise. All the test points are at
	-- height 2, so a level plane at that height is under every one of them.
	local surfacePoint = POINT
	local surfaceNormal = UP
	local surfaceMissing = false
	local bumpy = false

	local handle = SlamFx.start({
		slamWarning = { OnClientEvent = slamWarning },
		slamLanded = { OnClientEvent = slamLanded },
		fist = template,
		parent = parent,
		surfaceNormal = function(point: Vector3)
			table.insert(normalCalls, point)
			return normal
		end,
		castHug = function(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
			table.insert(hugCalls, origin)
			if surfaceMissing or (bumpy and #hugCalls % 9 == 0) then
				return nil, nil
			end
			local along = direction:Dot(surfaceNormal)
			if along >= 0 then
				return nil, nil
			end
			local through = (surfacePoint - origin):Dot(surfaceNormal) / along
			if through < 0 or through > 1 then
				return nil, nil
			end
			return origin + direction * through, surfaceNormal
		end,
		refreshHug = function()
			table.insert(refreshCalls, #hugCalls)
		end,
		onCircle = function(point: Vector3)
			table.insert(circleCalls, point)
		end,
		serverNow = function()
			return clock
		end,
		step = step,
		burst = function(emitter: ParticleEmitter, count: number)
			table.insert(bursts, { name = emitter.Name, count = count, parent = emitter.Parent, emitter = emitter })
		end,
	})
	table.insert(stops, handle.stop)

	local function folder(): Folder?
		local found = parent:FindFirstChild("SlamFx")
		if found ~= nil and found:IsA("Folder") then
			return found
		end
		return nil
	end

	local function advance(seconds: number)
		clock += seconds
		step:Fire(seconds)
	end

	return {
		parent = parent,
		template = template,
		slamWarning = slamWarning,
		slamLanded = slamLanded,
		step = step,
		stop = handle.stop,
		bursts = bursts,
		normalCalls = normalCalls,
		hugCalls = hugCalls,
		refreshCalls = refreshCalls,
		circleCalls = circleCalls,
		setNormal = function(newNormal: Vector3)
			normal = newNormal
		end,
		setSurface = function(point: Vector3, newNormal: Vector3)
			surfacePoint = point
			surfaceNormal = newNormal.Unit
		end,
		setSurfaceMissing = function(missing: boolean)
			surfaceMissing = missing
		end,
		setBumpy = function(isBumpy: boolean)
			bumpy = isBumpy
		end,
		advance = advance,
		-- Lets the circle finish building without time passing: steps until a step casts no more rays.
		settle = function()
			for _ = 1, 40 do
				local before = #hugCalls
				step:Fire(0)
				if #hugCalls == before and before > 0 then
					local again = #hugCalls
					step:Fire(0)
					if #hugCalls == again then
						return
					end
				end
			end
		end,
		now = function()
			return clock
		end,
		warn = function(slam: number, point: Vector3, secondsAhead: number): number
			local landsAt = clock + secondsAhead
			slamWarning:Fire(slam, point, landsAt)
			return landsAt
		end,
		land = function(slam: number, point: Vector3)
			slamLanded:Fire(slam, point)
		end,
		folder = folder,
		parts = function(name: string): { Part }
			local found: { Part } = {}
			local slams = folder()
			if slams ~= nil then
				for _, child in slams:GetChildren() do
					if child.Name == name and child:IsA("Part") then
						table.insert(found, child)
					end
				end
			end
			return found
		end,
		circles = function(): { Folder }
			local found: { Folder } = {}
			local slams = folder()
			if slams ~= nil then
				for _, child in slams:GetChildren() do
					if child.Name == "SlamCircle" and child:IsA("Folder") then
						table.insert(found, child)
					end
				end
			end
			return found
		end,
		pieces = function(): { Part }
			local found: { Part } = {}
			local slams = folder()
			if slams ~= nil then
				for _, descendant in slams:GetDescendants() do
					if
						(descendant.Name == "SlamRedPiece" or descendant.Name == "SlamGoldPiece")
						and descendant:IsA("Part")
					then
						table.insert(found, descendant)
					end
				end
			end
			return found
		end,
	}
end

-- A slam's circle, finished building: warns and lets the rest of the pieces come.
local function warnAndBuild(rig: Rig, slam: number, point: Vector3, secondsAhead: number): number
	local landsAt = rig.warn(slam, point, secondsAhead)
	rig.settle()
	return landsAt
end

local function theFist(rig: Rig): Model?
	local slams = rig.folder()
	if slams == nil then
		return nil
	end
	local found = slams:FindFirstChild("SlamFist")
	if found ~= nil and found:IsA("Model") then
		return found
	end
	return nil
end

local function theDust(rig: Rig): Part?
	return rig.parts("SlamDustAnchor")[1]
end

local function countChildren(rig: Rig): number
	local slams = rig.folder()
	return if slams ~= nil then #slams:GetChildren() else 0
end

-- Every piece has this transparency (or false if they differ, or there are none).
local function transparencyOfPieces(rig: Rig): number | boolean
	local pieces = rig.pieces()
	if #pieces == 0 then
		return false
	end
	local first = pieces[1].Transparency
	for _, piece in pieces do
		if math.abs(piece.Transparency - first) > 1e-6 then
			return false
		end
	end
	return first
end

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

describe("SlamFx.start: the fist", function()
	it("is not there before 0.6 seconds ahead of the landing", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(0.5)
		expect(theFist(rig)).toBeNil()
		rig.advance(0.39)
		expect(theFist(rig)).toBeNil()
	end)

	it("appears 0.6 seconds before the landing, with its bottom 45 studs straight above the point", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(0.9)
		local fist = theFist(rig) :: Model
		expect(fist).never.toBeNil()
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y + 45, 1)
		expect(centreOf(fist).X).toBeCloseTo(POINT.X, 2)
		expect(centreOf(fist).Z).toBeCloseTo(POINT.Z, 2)
	end)

	it("falls faster and faster, following the fall curve", function()
		local rig = newRig()
		local landsAt = rig.warn(1, POINT, 1.5)
		rig.advance(0.9)
		rig.advance(0.3) -- 0.3 before the landing
		local fist = theFist(rig) :: Model
		local expected = SlamFx.fistHeight(rig.now() - landsAt) :: number
		expect(expected > 0 and expected < 45).toBe(true)
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y + expected, 1)
	end)

	it("touches the point at the landing time", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y, 1)
		expect(centreOf(fist).X).toBeCloseTo(POINT.X, 2)
		expect(centreOf(fist).Z).toBeCloseTo(POINT.Z, 2)
	end)

	it("stays down for 0.4 seconds, then lifts, and is destroyed after 0.8 seconds", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		rig.advance(0.35)
		expect(bottomOf(theFist(rig) :: Model)).toBeCloseTo(POINT.Y, 1)
		rig.advance(0.25) -- 0.6 s after the landing
		expect(bottomOf(theFist(rig) :: Model)).toBeCloseTo(POINT.Y + 45 * 0.25, 0)
		rig.advance(0.25) -- 0.85 s
		expect(theFist(rig)).toBeNil()
	end)

	it("is a copy: the template stays where it was and is not put in the world", function()
		local rig = newRig()
		local before = rig.template:GetPivot()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		expect(fist).never.toBeNil()
		expect(fist).never.toBe(rig.template)
		expect(rig.template.Parent).toBeNil()
		expect(rig.template:GetPivot() == before).toBe(true)
		local geometry = rig.template:FindFirstChild("body_geom", true) :: Part
		expect(geometry.Anchored).toBe(false)
	end)

	it("makes every part of the copy anchored, not solid, not hit by rays and not touchable", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		local count = 0
		for _, part in fist:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				expect(part.Anchored).toBe(true)
				expect(part.CanCollide).toBe(false)
				expect(part.CanQuery).toBe(false)
				expect(part.CanTouch).toBe(false)
			end
		end
		expect(count).toBe(2)
	end)

	it("stays upright and keeps the template's turn, even when the circle is tilted", function()
		local rig = newRig()
		rig.setNormal(SLOPE_58)
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local fist = theFist(rig) :: Model
		local want = rig.template:GetPivot().Rotation
		local got = fist:GetPivot().Rotation
		expectNear(got.XVector, want.XVector)
		expectNear(got.YVector, want.YVector)
		expectNear(got.ZVector, want.ZVector)
		expect(bottomOf(fist)).toBeCloseTo(POINT.Y, 1)
	end)
end)

describe("SlamFx.start: the landing", function()
	it("bursts the dust 36 and the sparkles 40, once, when the landing time comes", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.25)
		expect(#rig.bursts).toBe(0)
		rig.advance(0.25)
		expect(#rig.bursts).toBe(2)
		expect(rig.bursts[1].name).toBe("SlamDust")
		expect(rig.bursts[1].count).toBe(36)
		expect(rig.bursts[2].name).toBe("SlamSparkles")
		expect(rig.bursts[2].count).toBe(40)
		rig.advance(0.1)
		rig.advance(0.1)
		expect(#rig.bursts).toBe(2)
	end)

	it(
		"makes an invisible, untouchable part 2 studs above the point for the two emitters, and no dust before the landing",
		function()
			local rig = newRig()
			rig.warn(1, POINT, 1.5)
			rig.advance(1.25)
			expect(theDust(rig)).toBeNil()
			rig.advance(0.25)
			local dust = theDust(rig) :: Part
			expect(dust).never.toBeNil()
			expectNear(dust.Position, POINT + UP * 2)
			expect(dust.Size == Vector3.new(1, 1, 1)).toBe(true)
			expect(dust.Transparency).toBe(1)
			expect(dust.Anchored).toBe(true)
			expect(dust.CanCollide).toBe(false)
			expect(dust.CanQuery).toBe(false)
			expect(dust.CanTouch).toBe(false)
			expect(rig.bursts[1].parent).toBe(dust)
			expect(rig.bursts[2].parent).toBe(dust)
		end
	)

	it("makes the dust a white smoke and the sparkles gold, both off until they are told to burst", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local smoke, sparkles = rig.bursts[1].emitter, rig.bursts[2].emitter
		expect(smoke.Texture).toBe("rbxasset://textures/particles/smoke_main.dds")
		expect(sparkles.Texture).toBe("rbxasset://textures/particles/sparkles_main.dds")
		expect(smoke.Enabled).toBe(false)
		expect(sparkles.Enabled).toBe(false)
		expect(sparkles.Color.Keypoints[1].Value == Theme.slamGold).toBe(true)
		expect(sparkles.Color.Keypoints[#sparkles.Color.Keypoints].Value == Theme.slamGold).toBe(true)
		expect(smoke.Color.Keypoints[1].Value == Color3.new(1, 1, 1)).toBe(true)
	end)

	it("puts the dust part 2 studs above the point along a slope's normal too, and keeps it upright", function()
		local rig = newRig()
		rig.setNormal(SLOPE_58)
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local dust = theDust(rig) :: Part
		expectNear(dust.Position, POINT + SLOPE_58 * 2)
		-- Upright: the puffs go up, whatever the slope.
		expectNear(dust.CFrame.XVector, Vector3.xAxis)
		expectNear(dust.CFrame.YVector, UP)
		expectNear(dust.CFrame.ZVector, Vector3.zAxis)
	end)

	it("puts the dust part 2 studs above the point even for a normal that is not 1 long or has no direction", function()
		local longRig = newRig()
		longRig.setNormal(Vector3.new(0, 5, 0))
		longRig.warn(1, POINT, 1.5)
		longRig.advance(1.5)
		expectNear((theDust(longRig) :: Part).Position, POINT + UP * 2)
		local noneRig = newRig()
		noneRig.setNormal(Vector3.zero)
		noneRig.warn(1, POINT, 1.5)
		noneRig.advance(1.5)
		expectNear((theDust(noneRig) :: Part).Position, POINT + UP * 2)
	end)

	it("keeps the dust part upright on level ground", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local dust = theDust(rig) :: Part
		expectNear(dust.CFrame.YVector, UP)
		expectNear(dust.CFrame.XVector, Vector3.xAxis)
	end)

	-- The emitters as they are at the landing, for the look tests below.
	local function emittersAtLanding(): (ParticleEmitter, ParticleEmitter)
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		return rig.bursts[1].emitter, rig.bursts[2].emitter
	end

	it("makes the dust pure white all through its life", function()
		local smoke = emittersAtLanding()
		expect(smoke.Name).toBe("SlamDust")
		for _, keypoint in smoke.Color.Keypoints do
			expect(keypoint.Value == Color3.fromHex("FFFFFF")).toBe(true)
		end
	end)

	it("makes each dust puff grow from 8 to 16 studs", function()
		local smoke = emittersAtLanding()
		local size = smoke.Size.Keypoints
		expect(#size).toBe(2)
		expect(size[1].Time).toBe(0)
		expect(size[1].Value).toBeCloseTo(8, 3)
		expect(size[2].Time).toBe(1)
		expect(size[2].Value).toBeCloseTo(16, 3)
	end)

	it("makes the dust 5% see-through at the start and fully clear at the end", function()
		local smoke = emittersAtLanding()
		local clear = smoke.Transparency.Keypoints
		expect(#clear).toBe(2)
		expect(clear[1].Time).toBe(0)
		expect(clear[1].Value).toBeCloseTo(0.05, 3)
		expect(clear[2].Time).toBe(1)
		expect(clear[2].Value).toBeCloseTo(1, 3)
	end)

	it("gives each dust puff a life of 0.9 to 1.3 seconds", function()
		local smoke = emittersAtLanding()
		expect(smoke.Lifetime.Min).toBeCloseTo(0.9, 3)
		expect(smoke.Lifetime.Max).toBeCloseTo(1.3, 3)
	end)

	it("throws the dust out at 20 to 32 studs a second", function()
		local smoke = emittersAtLanding()
		expect(smoke.Speed.Min).toBeCloseTo(20, 3)
		expect(smoke.Speed.Max).toBeCloseTo(32, 3)
	end)

	it("spreads the dust 85 degrees each way", function()
		local smoke = emittersAtLanding()
		expect(smoke.SpreadAngle == Vector2.new(85, 85)).toBe(true)
	end)

	it("slows the dust down with a drag of 4", function()
		local smoke = emittersAtLanding()
		expect(smoke.Drag).toBeCloseTo(4, 3)
	end)

	it("gives the dust a light emission of 0.2", function()
		local smoke = emittersAtLanding()
		expect(smoke.LightEmission).toBeCloseTo(0.2, 3)
	end)

	it("gives each sparkle one size for its whole life: 1.1 studs, from start to end", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Name).toBe("SlamSparkles")
		local size = sparkles.Size.Keypoints
		expect(#size).toBe(2)
		expect(size[1].Time).toBe(0)
		expect(size[2].Time).toBe(1)
		expect(size[1].Value).toBeCloseTo(1.1, 3)
		expect(size[2].Value).toBeCloseTo(1.1, 3)
	end)

	it("makes the sparkles vary by 0.3 studs either way, so they run from 0.8 to 1.4 studs", function()
		local _, sparkles = emittersAtLanding()
		for _, keypoint in sparkles.Size.Keypoints do
			expect(keypoint.Envelope).toBeCloseTo(0.3, 3)
		end
	end)

	it("gives the sparkles full light emission", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.LightEmission).toBeCloseTo(1, 3)
	end)

	it("keeps the sparkles' speed of 24 to 44", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Speed.Min).toBeCloseTo(24, 3)
		expect(sparkles.Speed.Max).toBeCloseTo(44, 3)
	end)

	it("keeps the sparkles' spread of 40 degrees", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.SpreadAngle == Vector2.new(40, 40)).toBe(true)
	end)

	it("keeps the sparkles' gravity", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Acceleration == Vector3.new(0, -50, 0)).toBe(true)
	end)

	it("keeps the sparkles' life of 0.5 to 0.9 seconds", function()
		local _, sparkles = emittersAtLanding()
		expect(sparkles.Lifetime.Min).toBeCloseTo(0.5, 3)
		expect(sparkles.Lifetime.Max).toBeCloseTo(0.9, 3)
	end)

	it("keeps the dust part until 1.3 seconds after the landing, the longest life", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		rig.advance(1.25)
		expect(theDust(rig)).never.toBeNil()
		rig.advance(0.1)
		expect(theDust(rig)).toBeNil()
	end)

	it("gives the particles a short life, gone within about a second", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		expect(#rig.bursts).toBe(2)
		for _, burst in rig.bursts do
			expect(burst.emitter.Lifetime.Max <= 1.3).toBe(true)
			expect(burst.emitter.Lifetime.Min > 0).toBe(true)
		end
	end)

	it("lands at once when SlamLanded comes before the landing time, and puts the fist on the point", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.2) -- 0.3 s before the landing time
		expect(#rig.bursts).toBe(0)
		expect(bottomOf(theFist(rig) :: Model) > POINT.Y + 1).toBe(true)
		rig.land(1, POINT)
		expect(#rig.bursts).toBe(2)
		rig.advance(0)
		expect(bottomOf(theFist(rig) :: Model)).toBeCloseTo(POINT.Y, 1)
		expect(theDust(rig)).never.toBeNil()
	end)

	it("counts the fade and the lift from the moment SlamLanded came", function()
		local rig = newRig()
		warnAndBuild(rig, 1, POINT, 1.5)
		rig.advance(1.2)
		rig.land(1, POINT)
		rig.advance(0.55) -- 0.55 s after the landing, though the landing time is still 0.25 s away
		expect(transparencyOfPieces(rig) :: number).toBeCloseTo(0.5, 2)
		rig.advance(0.2) -- 0.75 s: the circle is gone, the fist is lifting
		expect(#rig.pieces()).toBe(0)
		expect(theFist(rig)).never.toBeNil()
		rig.advance(0.1) -- 0.85 s
		expect(theFist(rig)).toBeNil()
	end)

	it("bursts only once when SlamLanded and the landing time both come", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.2)
		rig.land(1, POINT)
		rig.advance(0.5)
		rig.land(1, POINT)
		rig.advance(0.5)
		expect(#rig.bursts).toBe(2)
	end)

	it("does not burst twice when the landing time passes first and SlamLanded comes after it", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.6)
		expect(#rig.bursts).toBe(2)
		rig.land(1, POINT)
		rig.advance(0.1)
		expect(#rig.bursts).toBe(2)
	end)

	it(
		"keeps the circle solid until 0.4 seconds after the landing, half see-through at 0.55 and gone by 0.7",
		function()
			local rig = newRig()
			warnAndBuild(rig, 1, POINT, 1.5)
			rig.advance(1.5)
			rig.advance(0.4)
			expect(transparencyOfPieces(rig) :: number).toBeCloseTo(0, 6)
			rig.advance(0.15)
			expect(transparencyOfPieces(rig) :: number).toBeCloseTo(0.5, 2)
			rig.advance(0.16)
			expect(#rig.pieces()).toBe(0)
			expect(#rig.circles()).toBe(0)
		end
	)

	it("destroys the dust part once its longest particle has lived out its time", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.advance(1.5)
		local life = math.max(rig.bursts[1].emitter.Lifetime.Max, rig.bursts[2].emitter.Lifetime.Max)
		rig.advance(life - 0.05)
		expect(theDust(rig)).never.toBeNil()
		rig.advance(0.1)
		expect(theDust(rig)).toBeNil()
	end)

	it("leaves the folder empty and lets go of the step when the slam is over", function()
		local rig = newRig()
		rig.warn(1, POINT, 1.5)
		rig.settle()
		expect(rig.step:count()).toBe(1)
		rig.advance(1.5)
		rig.advance(0.9)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(rig.folder()).never.toBeNil()
		expect(countChildren(rig)).toBe(0)
		expect(rig.step:count()).toBe(0)
	end)
end)

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

describe("SlamFx.huggableParts and workspaceCastHug", function()
	-- A little world far from the map, built like the real one: the meadow's Terrain stays the real one (empty here).
	-- Every part is solid (CanCollide on) so only the list decides what a ray meets.
	local ORIGIN = Vector3.new(3000, 100, 3000)

	local function newWorld(): Folder
		local world = made(Instance.new("Folder"))
		world.Name = "World"
		world.Parent = Workspace
		return world
	end

	local function add(parent: Instance, name: string, size: Vector3, position: Vector3, className: string?): Part
		local part = Instance.new(className or "Part") :: Part
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = size
		part.Position = ORIGIN + position
		part.Parent = parent
		return part
	end

	local function folderIn(parent: Instance, name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end

	local function modelIn(parent: Instance, name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent
		return model
	end

	-- Everything the real world has that matters, each thing at its own place along x (top faces at y = 5 unless said).
	type Scene = {
		world: Folder,
		bridge: Model,
		plank: Part,
		cast: SlamFx.CastHug,
		refresh: () -> (),
	}

	local function newScene(): Scene
		local world = newWorld()
		local giant = modelIn(world, "Giant")
		local function giantPart(name: string, x: number): Part
			local model = modelIn(giant, name)
			return add(model, name, Vector3.new(10, 10, 10), Vector3.new(x, 0, 0)) -- top at 5
		end
		giantPart("body_and_cushion", 0)
		giantPart("head_with_beard", 20)
		giantPart("legs_and_boots", 40)
		giantPart("nightcap", 60)
		giantPart("left_arm", 80)
		giantPart("right_arm", 100)
		local walk = folderIn(world, "WalkSurfaces")
		add(modelIn(walk, "BootRamp"), "Ramp_Walk", Vector3.new(10, 10, 10), Vector3.new(120, 0, 0))
		add(modelIn(walk, "RightBootRamp"), "Ramp_Walk", Vector3.new(10, 10, 10), Vector3.new(140, 0, 0))
		-- An invisible solid plank on top of the body, like the ones players walk on.
		local belly = add(walk, "Belly_Walk", Vector3.new(10, 1, 10), Vector3.new(0, 5.5, 0))
		belly.Transparency = 1
		local bridges = folderIn(world, "Bridges")
		local bridge = modelIn(bridges, "PlankBridge_1")
		local plank = add(bridge, "Plank", Vector3.new(10, 1, 10), Vector3.new(160, 4.5, 0))
		add(bridge, "Post", Vector3.new(2, 8, 2), Vector3.new(180, 4, 0))
		add(bridge, "Rope", Vector3.new(10, 1, 10), Vector3.new(200, 4.5, 0))
		local things = folderIn(world, "GiantsThings")
		add(things, "Teacup", Vector3.new(10, 10, 10), Vector3.new(220, 0, 0))
		local nature = folderIn(world, "Nature")
		add(nature, "TreeTrunk", Vector3.new(10, 10, 10), Vector3.new(240, 0, 0))
		local cast, refresh = SlamFx.workspaceCastHug(Workspace, world)
		return { world = world, bridge = bridge, plank = plank, cast = cast, refresh = refresh }
	end

	-- Casts straight down at the place `x` along the row and gives the height of what it hit, or nil.
	local function hitHeight(scene: Scene, x: number): number?
		local position = scene.cast(ORIGIN + Vector3.new(x, 30, 0), Vector3.new(0, -60, 0))
		return if position ~= nil then position.Y - ORIGIN.Y else nil
	end

	it("hits his body_and_cushion, head, legs, nightcap and left arm", function()
		local scene = newScene()
		for _, x in { 0, 20, 40, 60, 80 } do
			local height = hitHeight(scene, x)
			expect(height).never.toBeNil()
			expect(math.abs((height :: number) - 5) < 1e-3).toBe(true)
		end
	end)

	it("hits a Ramp_Walk and a bridge Plank", function()
		local scene = newScene()
		expect(math.abs((hitHeight(scene, 120) :: number) - 5) < 1e-3).toBe(true)
		expect(math.abs((hitHeight(scene, 140) :: number) - 5) < 1e-3).toBe(true)
		expect(math.abs((hitHeight(scene, 160) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("gives the normal of what it hits", function()
		local scene = newScene()
		local _, normal = scene.cast(ORIGIN + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0))
		expect(normal).never.toBeNil()
		expectNear(normal :: Vector3, UP)
	end)

	it("goes through his right arm, which moves during slams", function()
		local scene = newScene()
		expect(hitHeight(scene, 100)).toBeNil()
	end)

	it("goes through a bridge Post and a Rope", function()
		local scene = newScene()
		expect(hitHeight(scene, 180)).toBeNil()
		expect(hitHeight(scene, 200)).toBeNil()
	end)

	it("goes through an invisible walk plank on top of his body, and hits the body under it", function()
		local scene = newScene()
		-- The plank's top is at 6; the body's at 5.
		expect(math.abs((hitHeight(scene, 0) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("goes through props: a solid part in GiantsThings and a tree trunk", function()
		local scene = newScene()
		expect(hitHeight(scene, 220)).toBeNil()
		expect(hitHeight(scene, 240)).toBeNil()
	end)

	it("goes through a character model standing on the body", function()
		local scene = newScene()
		local character = made(Instance.new("Model"))
		character.Name = "SomeoneStanding"
		add(character, "HumanoidRootPart", Vector3.new(4, 5, 2), Vector3.new(0, 8, 0))
		character.Parent = Workspace
		expect(math.abs((hitHeight(scene, 0) :: number) - 5) < 1e-3).toBe(true)
	end)

	it("hits only what is on the list, not a part that is not under the Giant, WalkSurfaces or Bridges", function()
		local scene = newScene()
		scene.refresh()
		local extra = add(scene.world, "SolidCrate", Vector3.new(10, 10, 10), Vector3.new(260, 0, 0))
		expect(extra.CanCollide).toBe(true)
		expect(hitHeight(scene, 260)).toBeNil()
	end)

	it("goes through a part that can't be collided with, even one on the list", function()
		local scene = newScene()
		scene.plank.CanCollide = false
		expect(hitHeight(scene, 160)).toBeNil()
	end)

	it("lists the Terrain, the five body parts, the two ramps and the planks, and nothing else", function()
		local scene = newScene()
		local list = SlamFx.huggableParts(Workspace, scene.world)
		expect(table.find(list, Workspace.Terrain)).never.toBeNil()
		local names: { string } = {}
		for _, instance in list do
			if instance ~= Workspace.Terrain then
				table.insert(names, instance.Name)
			end
		end
		table.sort(names)
		expect(table.concat(names, ",")).toBe(
			"Plank,Ramp_Walk,Ramp_Walk,body_and_cushion,head_with_beard,left_arm,legs_and_boots,nightcap"
		)
	end)

	it("lists single parts, never the Bridges or WalkSurfaces folders or the Giant", function()
		local scene = newScene()
		for _, instance in SlamFx.huggableParts(Workspace, scene.world) do
			expect(instance:IsA("BasePart")).toBe(true)
		end
	end)

	it("builds its list once for each refresh, not for each ray", function()
		local scene = newScene()
		expect(hitHeight(scene, 160)).never.toBeNil()
		local newPlank = add(scene.bridge, "Plank", Vector3.new(10, 1, 10), Vector3.new(280, 4.5, 0))
		expect(newPlank.CanCollide).toBe(true)
		expect(hitHeight(scene, 280)).toBeNil() -- a bridge that streamed in since the list was made is not on it yet
		scene.refresh()
		expect(hitHeight(scene, 280)).never.toBeNil()
	end)

	it("builds the list at the first ray when it was never refreshed", function()
		local world = newWorld()
		local bridge = modelIn(folderIn(world, "Bridges"), "PlankBridge_1")
		add(bridge, "Plank", Vector3.new(10, 1, 10), Vector3.new(0, 4.5, 0))
		local cast = SlamFx.workspaceCastHug(Workspace, world)
		local position = cast(ORIGIN + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0))
		expect(position).never.toBeNil()
	end)

	it("copes with a world that has no Giant, WalkSurfaces or Bridges", function()
		local world = newWorld()
		local list = SlamFx.huggableParts(Workspace, world)
		expect(#list).toBe(1) -- the Terrain
	end)

	it("sets the ray up to see only collidable parts, on a list, and to see water", function()
		local seen: { RaycastParams } = {}
		local fakeWorkspace: any = {
			Terrain = Workspace.Terrain,
			Raycast = function(_self: any, _origin: Vector3, _direction: Vector3, params: RaycastParams)
				table.insert(seen, params)
				return nil
			end,
		}
		local world = newWorld()
		local cast = SlamFx.workspaceCastHug(fakeWorkspace, world)
		cast(Vector3.zero, Vector3.new(0, -1, 0))
		expect(seen[1].FilterType).toBe(Enum.RaycastFilterType.Include)
		expect(seen[1].RespectCanCollide).toBe(true)
		expect(seen[1].IgnoreWater).toBe(false)
	end)
end)

describe("SlamFx.workspaceSurfaceNormal", function()
	-- A tilted floor far away from anything else, and a tool that lists the players' characters.
	local function newSlope(): Part
		local floor = made(Instance.new("Part"))
		floor.Anchored = true
		floor.Size = Vector3.new(60, 2, 60)
		floor.CFrame = CFrame.new(2000, 0, 2000) * CFrame.Angles(0, 0, math.rad(20))
		floor.Parent = Workspace
		return floor
	end

	local noPlayers: any = {
		GetPlayers = function(_self: any)
			return {}
		end,
	}

	it("gives the normal of the surface just under the point", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0)) -- the middle of the top face
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("gives straight up when nothing is under the point", function()
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(Vector3.new(5000, 0, 5000)), UP)
	end)

	it("goes through a part that can't be collided with, such as a bush", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0))
		local bush = made(Instance.new("Part"))
		bush.Anchored = true
		bush.CanCollide = false
		bush.Size = Vector3.new(6, 1, 6)
		bush.CFrame = CFrame.new(point + Vector3.new(0, 0.3, 0))
		bush.Parent = Workspace
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, made(Instance.new("Folder")))
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("goes through every player's character", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0))
		local character = made(Instance.new("Model"))
		local body = Instance.new("Part")
		body.Anchored = true
		body.Size = Vector3.new(6, 0.5, 6)
		body.CFrame = CFrame.new(point + Vector3.new(0, 0.5, 0)) -- level, so a hit would give straight up
		body.Parent = character
		character.Parent = Workspace
		local players: any = {
			GetPlayers = function(_self: any)
				local list: { any } = { { Character = character }, { Character = nil } }
				return list
			end,
		}
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, players, made(Instance.new("Folder")))
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("goes through SlamFx's own folder", function()
		local floor = newSlope()
		local point = floor.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0))
		local folder = made(Instance.new("Folder"))
		folder.Name = "SlamFx"
		folder.Parent = Workspace
		local disc = Instance.new("Part")
		disc.Anchored = true
		disc.Size = Vector3.new(6, 0.5, 6)
		disc.CFrame = CFrame.new(point + Vector3.new(0, 0.5, 0)) -- level, so a hit would give straight up
		disc.Parent = folder
		local normalOf = SlamFx.workspaceSurfaceNormal(Workspace, noPlayers, Workspace)
		expectNear(normalOf(point), floor.CFrame.YVector, 1e-3)
	end)

	it("starts one stud above the point and looks only two studs down", function()
		local calls: { { origin: Vector3, direction: Vector3 } } = {}
		local fakeWorkspace: any = {
			Raycast = function(_self: any, origin: Vector3, direction: Vector3, _params: RaycastParams)
				table.insert(calls, { origin = origin, direction = direction })
				return nil
			end,
		}
		local normalOf = SlamFx.workspaceSurfaceNormal(fakeWorkspace, noPlayers, made(Instance.new("Folder")))
		normalOf(Vector3.new(3, 4, 5))
		expect(#calls).toBe(1)
		expectNear(calls[1].origin, Vector3.new(3, 5, 5))
		expectNear(calls[1].direction, Vector3.new(0, -2, 0))
	end)

	it("only sees parts that can collide, and leaves out characters and the folder", function()
		local seen: { RaycastParams } = {}
		local fakeWorkspace: any = {
			Raycast = function(_self: any, _origin: Vector3, _direction: Vector3, params: RaycastParams)
				table.insert(seen, params)
				return nil
			end,
		}
		local character = made(Instance.new("Model"))
		local parent = made(Instance.new("Folder"))
		local folder = Instance.new("Folder")
		folder.Name = "SlamFx"
		folder.Parent = parent
		local players: any = {
			GetPlayers = function(_self: any)
				return { { Character = character } }
			end,
		}
		SlamFx.workspaceSurfaceNormal(fakeWorkspace, players, parent)(Vector3.zero)
		local params = seen[1]
		expect(params.RespectCanCollide).toBe(true)
		expect(params.FilterType).toBe(Enum.RaycastFilterType.Exclude)
		expect(table.find(params.FilterDescendantsInstances, character)).never.toBeNil()
		expect(table.find(params.FilterDescendantsInstances, folder)).never.toBeNil()
	end)
end)
