--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local expect = JestGlobals.expect
local Footprints = require(StarterPlayer.StarterPlayerScripts.Client.World.Footprints)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)

local UPDATE_SECONDS = 0.25

local LIFT = 0.05

-- The template's sole is 0.15 studs thick and its pivot is at the sole's centre, so the bottom of a footprint is
-- 0.075 below its pivot.
local HALF_SOLE = 0.075

local SIT_HEIGHT = LIFT + HALF_SOLE

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

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
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

local function expectNear(actual: Vector3, expected: Vector3)
	expect(actual.X).toBeCloseTo(expected.X, 3)
	expect(actual.Y).toBeCloseTo(expected.Y, 3)
	expect(actual.Z).toBeCloseTo(expected.Z, 3)
end

-- A footprint like the real template: a Model whose PrimaryPart is a flat sole (1.5 x 0.15 x 2.73), plus a toe that
-- is not anchored. Everything starts out the way the real template is, with touching switched ON.
local function newTemplate(soleTransparency: number?): Model
	local model = made(Instance.new("Model"))
	model.Name = "Footprint"
	local sole = Instance.new("Part")
	sole.Name = "Sole"
	sole.Size = Vector3.new(1.5, 0.15, 2.73)
	sole.Anchored = true
	sole.CanCollide = true
	sole.CanQuery = true
	sole.CanTouch = true
	sole.CastShadow = true
	sole.Transparency = soleTransparency or 0
	sole.Parent = model
	local toe = Instance.new("Part")
	toe.Name = "Toe1"
	toe.Size = Vector3.new(0.45, 0.15, 0.55)
	toe.CFrame = sole.CFrame * CFrame.new(0, 0, -1.5)
	toe.Anchored = false
	toe.CanCollide = true
	toe.CanQuery = true
	toe.CanTouch = true
	toe.CastShadow = true
	toe.Parent = model
	model.PrimaryPart = sole
	return model
end

export type Point = RouteGraph.Point

-- The fake route: a spawn point S in the middle with three arms.
--   E1 is 20 studs along +X (the nearest egg), E2 is 40 studs along -Z, and G3 (Gate_3) is 20 studs along -X.
local function defaultPoints(): { Point }
	return {
		{ name = "E1", position = Vector3.new(20, 0, 0), neighbours = { "S" }, target = "EggSpot_Common_1" },
		{ name = "E2", position = Vector3.new(0, 0, -40), neighbours = { "S" }, target = "EggSpot_Common_2" },
		{ name = "G3", position = Vector3.new(-20, 0, 0), neighbours = { "S" }, target = "Gate_3" },
		{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E1", "E2", "G3" }, target = "Spawn_1" },
	}
end

type GroundCall = { position: Vector3, ignore: Instance }

type Options = {
	points: { Point }?,
	waiting: { string }?,
	noPlot: boolean?,
	noCharacter: boolean?,
	soleTransparency: number?, -- how see-through the template's sole is (the toe stays at 0)
}

export type Rig = {
	parent: Folder,
	root: Folder,
	player: Folder,
	step: any,
	clock: { now: number },
	feet: { value: Vector3? },
	groundCalls: { GroundCall },
	-- Flat ground at height 0 unless a test sets this. A finder may give the part it hit as a third value.
	ground: { find: (position: Vector3) -> (Vector3?, Vector3?, Instance?) },
	template: Model,
	handle: Footprints.Handle,
	setWaiting: (spotName: string, waiting: boolean) -> (),
	advance: (seconds: number) -> (),
	-- The footprints that show now.
	shown: () -> { Model },
	folder: () -> Folder?,
}

local function newRig(options: Options?): Rig
	local settings = (options or {}) :: Options
	local parent = made(Instance.new("Folder"))
	local root = made(Instance.new("Folder"))
	local waitingNames: { string } = settings.waiting or { "EggSpot_Common_1", "EggSpot_Common_2" }
	for _, name in waitingNames do
		local spot = Instance.new("Model")
		spot.Name = name
		spot:SetAttribute("Waiting", true)
		spot.Parent = root
	end
	local player = made(Instance.new("Folder"))
	if not settings.noPlot then
		player:SetAttribute("PlotIndex", 3)
	end
	local fakePlayer = {
		GetAttribute = function(_self: any, name: string): any
			return player:GetAttribute(name)
		end,
	}
	local step = newSignal()
	local clock = { now = 100 }
	local feet: { value: Vector3? } = { value = if settings.noCharacter then nil else Vector3.new(0, 0, 0) }
	local groundCalls: { GroundCall } = {}
	local ground = {
		find = function(position: Vector3): (Vector3?, Vector3?, Instance?)
			return Vector3.new(position.X, 0, position.Z), Vector3.new(0, 1, 0)
		end,
	}
	local template = newTemplate(settings.soleTransparency)

	local handle = Footprints.start({
		points = settings.points or defaultPoints(),
		root = root,
		player = fakePlayer,
		feet = function()
			return feet.value
		end,
		ground = function(position: Vector3, ignore: Instance)
			table.insert(groundCalls, { position = position, ignore = ignore })
			return ground.find(position)
		end,
		template = template,
		parent = parent,
		step = step,
		now = function()
			return clock.now
		end,
	})
	table.insert(stops, handle.stop)

	local function folder(): Folder?
		return parent:FindFirstChild("Footprints") :: Folder?
	end
	return {
		parent = parent,
		root = root,
		player = player,
		step = step,
		clock = clock,
		feet = feet,
		groundCalls = groundCalls,
		ground = ground,
		template = template,
		handle = handle,
		setWaiting = function(spotName: string, waiting: boolean)
			(root:FindFirstChild(spotName) :: Instance):SetAttribute("Waiting", waiting)
		end,
		advance = function(seconds: number)
			clock.now += seconds
			step:Fire()
		end,
		shown = function(): { Model }
			local models: { Model } = {}
			local holder = folder()
			if holder then
				for _, child in holder:GetChildren() do
					if child:IsA("Model") then
						table.insert(models, child)
					end
				end
			end
			return models
		end,
		folder = folder,
	}
end

-- The footprints' pivot positions, nearest the highest X (or the lowest, `descending` false) first.
local function pivotsAlong(models: { Model }, axis: "X" | "Z", descending: boolean): { CFrame }
	local function pick(pivot: CFrame): number
		return if axis == "X" then pivot.Position.X else pivot.Position.Z
	end
	local pivots: { CFrame } = {}
	for _, model in models do
		table.insert(pivots, model:GetPivot())
	end
	table.sort(pivots, function(a, b)
		if descending then
			return pick(a) > pick(b)
		end
		return pick(a) < pick(b)
	end)
	return pivots
end

return {
	HALF_SOLE = HALF_SOLE,
	LIFT = LIFT,
	SIT_HEIGHT = SIT_HEIGHT,
	UPDATE_SECONDS = UPDATE_SECONDS,
	cleanUp = cleanUp,
	defaultPoints = defaultPoints,
	expectNear = expectNear,
	made = made,
	newRig = newRig,
	newSignal = newSignal,
	pivotsAlong = pivotsAlong,
	stops = stops,
}
