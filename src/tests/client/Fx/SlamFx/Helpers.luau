--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local Client = StarterPlayer.StarterPlayerScripts.Client
local SlamFx = require(Client.Fx.SlamFx)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}

local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

local function cleanUp()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end

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

local BASE_CLOCK = 1024

local POINT = Vector3.new(10, 2, -20)

type Burst = { name: string, count: number, parent: Instance?, emitter: ParticleEmitter }

export type Rig = {
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

return {
	BASE_CLOCK = BASE_CLOCK,
	POINT = POINT,
	SLOPE_58 = SLOPE_58,
	UP = UP,
	cleanUp = cleanUp,
	countChildren = countChildren,
	expectNear = expectNear,
	made = made,
	newRig = newRig,
	newSignal = newSignal,
	stops = stops,
	theDust = theDust,
	theFist = theFist,
	transparencyOfPieces = transparencyOfPieces,
	warnAndBuild = warnAndBuild,
}
