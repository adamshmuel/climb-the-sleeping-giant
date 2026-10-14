--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Footprints = require(StarterPlayer.StarterPlayerScripts.Client.World.Footprints)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)

local SPACING = 3.6
local UPDATE_SECONDS = 0.25
local LIFT = 0.05
-- The gap on the boot-ramp planks, where the cleats (0.295 studs tall) would cut through a footprint lower than this.
local RAMP_LIFT = 0.35
local MAX_SHOWN = 100
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

type Point = { name: string, position: Vector3, neighbours: { string }, target: string? }

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

type Rig = {
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

describe("Footprints.start: the way to an egg", function()
	it("shows the way to the nearest waiting egg", function()
		local rig = newRig()
		-- E1 is 20 studs away: footprints at 20, 16.4, 12.8, 9.2, 5.6 and 2 studs along +X, toes pointing +X.
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expect(#pivots).toBe(6)
		for index, pivot in pivots do
			expectNear(pivot.Position, Vector3.new(20 - (index - 1) * SPACING, SIT_HEIGHT, 0))
			expectNear(pivot.LookVector, Vector3.new(1, 0, 0))
		end
	end)

	it("leads to the nearest egg by walking distance, not the nearest in a straight line", function()
		-- A wall: E1 is 20 studs from S in a straight line, but the only way there goes 60 studs round.
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E2", "U" }, target = nil },
			{ name = "U", position = Vector3.new(0, 0, 30), neighbours = { "S", "V" }, target = nil },
			{ name = "V", position = Vector3.new(20, 0, 30), neighbours = { "U", "E1" }, target = nil },
			{ name = "E1", position = Vector3.new(20, 0, 0), neighbours = { "V" }, target = "EggSpot_Common_1" },
			{ name = "E2", position = Vector3.new(0, 0, -40), neighbours = { "S" }, target = "EggSpot_Common_2" },
		}
		local rig = newRig({ points = points })
		-- E2 is 40 studs away along -Z; E1 is 80 by the route.
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
		expectNear(pivots[1].LookVector, Vector3.new(0, 0, -1))
	end)

	it("leaves out an egg that is not waiting", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it("moves on to the next egg when the first one is taken", function()
		local rig = newRig()
		expect(#rig.shown()).toBe(6)
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		-- E2 is 40 studs away along -Z: footprints at 40, 36.4, ... 4 studs, toes pointing -Z.
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expect(#pivots).toBe(12)
		for index, pivot in pivots do
			expectNear(pivot.Position, Vector3.new(0, SIT_HEIGHT, -40 + (index - 1) * SPACING))
			expectNear(pivot.LookVector, Vector3.new(0, 0, -1))
		end
	end)

	it("goes back to an egg when it is waiting again", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		rig.setWaiting("EggSpot_Common_1", true)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("shows nothing when no egg is waiting", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.setWaiting("EggSpot_Common_2", false)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
	end)

	it("shows nothing when an egg spot has no route point", function()
		local rig = newRig({ waiting = { "EggSpot_Common_9" } })
		expect(#rig.shown()).toBe(0)
	end)

	it("shows nothing without a character, and shows the way again when the character is back", function()
		local rig = newRig()
		rig.feet.value = nil
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("shows nothing when the player has no garden number", function()
		local rig = newRig({ noPlot = true })
		expect(#rig.shown()).toBe(0)
	end)

	it("shows nothing at the start when there is no character yet", function()
		local rig = newRig({ noCharacter = true })
		expect(#rig.shown()).toBe(0)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)
end)

describe("Footprints.start: carrying an egg", function()
	it("shows the way to the player's own Safe Gate", function()
		local rig = newRig()
		rig.player:SetAttribute("Carrying", "Common")
		rig.advance(UPDATE_SECONDS)
		-- Gate_3 is 20 studs along -X.
		local pivots = pivotsAlong(rig.shown(), "X", false)
		expect(#pivots).toBe(6)
		for index, pivot in pivots do
			expectNear(pivot.Position, Vector3.new(-20 + (index - 1) * SPACING, SIT_HEIGHT, 0))
			expectNear(pivot.LookVector, Vector3.new(-1, 0, 0))
		end
	end)

	it("leads home even if no egg is waiting", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.setWaiting("EggSpot_Common_2", false)
		rig.player:SetAttribute("Carrying", "Rare")
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("leads to the gate of the player's own garden, not another one", function()
		local rig = newRig()
		rig.player:SetAttribute("Carrying", "Common")
		rig.player:SetAttribute("PlotIndex", 4) -- there is no Gate_4 in the fake route
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
	end)

	it("turns back to the eggs when the player has banked", function()
		local rig = newRig()
		rig.player:SetAttribute("Carrying", "Common")
		rig.advance(UPDATE_SECONDS)
		rig.player:SetAttribute("Carrying", nil)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expectNear(pivots[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
	end)

	it("shows nothing while carrying and the garden number is missing", function()
		local rig = newRig({ noPlot = true })
		rig.player:SetAttribute("Carrying", "Common")
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
	end)
end)

describe("Footprints.start: how often it looks again", function()
	it("works the way out again only every 0.25 seconds", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(0.1)
		-- Not yet: the footprints still lead to E1.
		expectNear(pivotsAlong(rig.shown(), "X", true)[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
		rig.advance(0.1)
		expectNear(pivotsAlong(rig.shown(), "X", true)[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
		rig.advance(0.05)
		-- 0.25 s have passed: now they lead to E2.
		expectNear(pivotsAlong(rig.shown(), "Z", false)[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it("keeps the footprints ahead where they are while the player walks along the way", function()
		local rig = newRig()
		local before = pivotsAlong(rig.shown(), "X", true)
		rig.feet.value = Vector3.new(1, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local after = pivotsAlong(rig.shown(), "X", true)
		expect(#after).toBe(#before)
		for index, pivot in before do
			expectNear(after[index].Position, pivot.Position)
		end
	end)

	it("takes away only the footprint the player has walked past", function()
		local rig = newRig()
		local before = pivotsAlong(rig.shown(), "X", true)
		-- The last footprint is at x = 2. At x = 3 the player has passed it.
		rig.feet.value = Vector3.new(3, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local after = pivotsAlong(rig.shown(), "X", true)
		expect(#after).toBe(#before - 1)
		for index, pivot in after do
			expectNear(pivot.Position, before[index].Position)
		end
	end)
end)

describe("Footprints.start: the copies", function()
	it("switches off touching, bumping, being found by rays and shadows on every part, and anchors them", function()
		local rig = newRig()
		local models = rig.shown()
		expect(#models > 0).toBe(true)
		for _, model in models do
			local parts = 0
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					parts += 1
					expect(descendant.CanCollide).toBe(false)
					expect(descendant.CanQuery).toBe(false)
					expect(descendant.CanTouch).toBe(false)
					expect(descendant.CastShadow).toBe(false)
					expect(descendant.Anchored).toBe(true)
				end
			end
			expect(parts).toBe(2)
		end
	end)

	it("never changes the template itself", function()
		local rig = newRig()
		local sole = rig.template:FindFirstChild("Sole") :: Part
		expect(sole.CanTouch).toBe(true)
		expect(sole.CanQuery).toBe(true)
		expect(rig.template.Parent).toBeNil()
	end)

	it("never shows more than 100 at once, and keeps the ones nearest the player", function()
		-- 500 studs from the player to the egg is 139 footprints.
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E1" }, target = nil },
			{ name = "E1", position = Vector3.new(500, 0, 0), neighbours = { "S" }, target = "EggSpot_Common_1" },
		}
		local rig = newRig({ points = points, waiting = { "EggSpot_Common_1" } })
		local pivots = pivotsAlong(rig.shown(), "X", false)
		expect(#pivots).toBe(MAX_SHOWN)
		-- 500 - 138 * 3.6 = 3.2 is the footprint nearest the player.
		expect(pivots[1].Position.X).toBeCloseTo(3.2, 3)
	end)

	it("reuses its copies instead of making new ones on every update", function()
		local rig = newRig()
		local seen: { [Model]: boolean } = {}
		for _, model in rig.shown() do
			seen[model] = true
		end
		-- Walk and come back several times: the same copies show again each time.
		for round = 1, 4 do
			rig.feet.value = Vector3.new(if round % 2 == 0 then 0 else 8, 0, 0)
			rig.advance(UPDATE_SECONDS)
			for _, model in rig.shown() do
				expect(seen[model]).toBe(true)
			end
		end
	end)

	it("hides a copy it does not need and shows it again later", function()
		local rig = newRig()
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local fewer = #rig.shown()
		expect(fewer < 6).toBe(true)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)
end)

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

-- The Transparency of every part of every footprint that shows now.
local function shownTransparencies(rig: Rig): { number }
	local values: { number } = {}
	for _, model in rig.shown() do
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(values, descendant.Transparency)
			end
		end
	end
	return values
end

-- Every part of every footprint that shows now has this Transparency (and there is at least one).
local function expectAllTransparency(rig: Rig, expected: number)
	local values = shownTransparencies(rig)
	expect(#values > 0).toBe(true)
	for _, value in values do
		expect(value).toBeCloseTo(expected, 3)
	end
end

describe("Footprints.start: hiding during a bounce", function()
	it("hide makes every footprint fully see-through at once", function()
		local rig = newRig()
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 0)
		rig.handle.hide()
		expect(#rig.shown()).toBe(6) -- still laid on the way, just not to be seen
		expectAllTransparency(rig, 1)
	end)

	it("footprints laid while hidden are hidden too", function()
		-- No character yet, so no copy has been made.
		local rig = newRig({ noCharacter = true })
		rig.handle.hide()
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 6 new copies are laid
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1)
		-- Copies the pool takes out of sight and shows again are hidden too.
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown() < 6).toBe(true)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1)
	end)

	it("keeps working out the way while hidden, so the trail is right when it comes back", function()
		local rig = newRig()
		rig.handle.hide()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		-- E2 is 40 studs along -Z now: 12 footprints.
		expect(#rig.shown()).toBe(12)
		rig.handle.show()
		expectAllTransparency(rig, 0)
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it(
		"fadeIn brings them back evenly: half see-through at half the time, normal at the end, and never past it",
		function()
			local rig = newRig()
			rig.handle.hide()
			rig.handle.fadeIn(0.6)
			expectAllTransparency(rig, 1)
			rig.advance(0.15)
			expectAllTransparency(rig, 0.75)
			rig.advance(0.15) -- 0.3 s of 0.6
			expectAllTransparency(rig, 0.5)
			rig.advance(0.3) -- 0.6 s
			expectAllTransparency(rig, 0)
			rig.advance(0.4) -- 1.0 s
			expectAllTransparency(rig, 0)
			rig.advance(5)
			expectAllTransparency(rig, 0)
		end
	)

	it("copies laid during a fade match the fade", function()
		-- No character yet, so no copy has been made: the copies laid during the fade are all new.
		local rig = newRig({ noCharacter = true })
		rig.handle.hide()
		rig.handle.fadeIn(1.2)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 0.25 of 1.2 s
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1 - UPDATE_SECONDS / 1.2)
		-- Copies the pool takes out of sight and shows again during the fade match it too.
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 0.5 s
		expect(#rig.shown() < 6).toBe(true)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 0.75 s
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1 - 0.75 / 1.2)
	end)

	it("the fade ends on each part's own see-through", function()
		local rig = newRig({ soleTransparency = 0.2 })
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		for _, model in rig.shown() do
			-- Halfway between its own 0.2 and 1 is 0.6; the toe goes from 0 to 1, so 0.5.
			expect((model:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.6, 3)
			expect((model:FindFirstChild("Toe1") :: Part).Transparency).toBeCloseTo(0.5, 3)
		end
		rig.advance(0.3)
		for _, model in rig.shown() do
			expect((model:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
			expect((model:FindFirstChild("Toe1") :: Part).Transparency).toBeCloseTo(0, 3)
		end
		rig.advance(1)
		for _, model in rig.shown() do
			expect((model:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
		end
	end)

	it("show brings them back at once, and hide during a fade hides at once", function()
		local rig = newRig()
		rig.handle.hide()
		rig.handle.show()
		expectAllTransparency(rig, 0)

		-- show during a fade ends the fade
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		expectAllTransparency(rig, 0.5)
		rig.handle.show()
		expectAllTransparency(rig, 0)
		rig.advance(0.1)
		expectAllTransparency(rig, 0)

		-- hide during a fade stops the fade
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		rig.handle.hide()
		expectAllTransparency(rig, 1)
		rig.advance(0.5)
		expectAllTransparency(rig, 1)
	end)

	it("fadeIn while already shown changes nothing", function()
		local rig = newRig()
		rig.handle.fadeIn(0.6)
		expectAllTransparency(rig, 0)
		rig.advance(0.3)
		expectAllTransparency(rig, 0)
	end)

	it("a second fadeIn during a fade does not jump back to hidden", function()
		local rig = newRig()
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		rig.handle.fadeIn(0.6)
		rig.advance(0.1)
		expectAllTransparency(rig, 1 - 0.4 / 0.6) -- the first fade carries on
	end)

	it("hiding never changes the template", function()
		local rig = newRig({ soleTransparency = 0.2 })
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		expect((rig.template:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
		expect((rig.template:FindFirstChild("Toe1") :: Part).Transparency).toBeCloseTo(0, 3)
		rig.handle.hide()
		expect((rig.template:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
		expect(rig.template.Parent).toBeNil()
	end)

	it("does nothing, and does not error, after stop", function()
		local rig = newRig()
		rig.handle.stop()
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.handle.show()
		rig.advance(UPDATE_SECONDS)
		expect(rig.folder()).toBeNil()
	end)
end)

describe("Footprints.start: stopping", function()
	it("destroys every copy and the holder, hidden ones too, and disconnects", function()
		local rig = newRig()
		local everyone: { Model } = {}
		for _, model in rig.shown() do
			table.insert(everyone, model)
		end
		-- Some copies are hidden by now.
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown() < #everyone).toBe(true)
		local holder = rig.folder() :: Folder

		expect(rig.step:count()).toBe(1)
		rig.handle.stop()

		expect(rig.step:count()).toBe(0)
		expect(rig.folder()).toBeNil()
		expect(holder.Parent).toBeNil()
		for _, model in everyone do
			-- A destroyed instance has its parent locked.
			local ok = pcall(function()
				model.Parent = rig.parent
			end)
			expect(ok).toBe(false)
		end
	end)

	it("does nothing on later steps and can be stopped twice", function()
		local rig = newRig()
		rig.handle.stop()
		rig.advance(UPDATE_SECONDS)
		rig.handle.stop()
		expect(rig.folder()).toBeNil()
	end)

	it("makes no second holder when started again on the same parent", function()
		local rig = newRig()
		local second = Footprints.start({
			points = defaultPoints(),
			root = rig.root,
			player = {
				GetAttribute = function(_self: any, name: string): any
					return rig.player:GetAttribute(name)
				end,
			},
			feet = function()
				return Vector3.new(0, 0, 0)
			end,
			ground = function(position: Vector3, _ignore: Instance)
				return position, Vector3.new(0, 1, 0)
			end,
			template = rig.template,
			parent = rig.parent,
			step = newSignal(),
			now = function()
				return 0
			end,
		})
		table.insert(stops, second.stop)
		local holders = 0
		for _, child in rig.parent:GetChildren() do
			if child.Name == "Footprints" then
				holders += 1
			end
		end
		expect(holders).toBe(1)
	end)
end)

describe("Footprints.feetOf", function()
	local function newCharacter(hipHeight: number): Model
		local character = made(Instance.new("Model"))
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = CFrame.new(10, 8, 5)
		root.Anchored = true
		root.Parent = character
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = hipHeight
		humanoid.Parent = character
		return character
	end

	it("is nil without a character", function()
		expect(Footprints.feetOf(nil)).toBeNil()
	end)

	it("is nil for a character without a root part", function()
		local character = made(Instance.new("Model"))
		expect(Footprints.feetOf(character)).toBeNil()
	end)

	it("is the point on the ground under the root part: half its height plus the hip height below it", function()
		local feet = Footprints.feetOf(newCharacter(2))
		expect(feet).never.toBeNil()
		-- 8 - 1 (half the root part) - 2 (the legs) = 5.
		expectNear(feet :: Vector3, Vector3.new(10, 5, 5))
	end)

	it("is nil for a character that has died", function()
		local character = newCharacter(2)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0
		expect(Footprints.feetOf(character)).toBeNil()
	end)
end)

describe("Footprints.workspaceGround", function()
	local function newFloor(topY: number): Part
		local floor = made(Instance.new("Part"))
		floor.Anchored = true
		floor.Size = Vector3.new(40, 2, 40)
		floor.CFrame = CFrame.new(1000, topY - 1, 1000)
		floor.Parent = Workspace
		return floor
	end

	local noPlayers = {
		GetPlayers = function(_self: any)
			return {}
		end,
	}

	it("finds the ground under a position, with its slope", function()
		newFloor(0)
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit, normal = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expectNear(hit :: Vector3, Vector3.new(1000, 0, 1000))
		expectNear(normal :: Vector3, Vector3.new(0, 1, 0))
	end)

	it("starts 3 studs above the position, so ground a little higher than the route line is still found", function()
		newFloor(2)
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(2, 3)
	end)

	it("gives the part it hit as a third value", function()
		local floor = newFloor(0)
		floor.Name = "Ramp_Walk"
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit, normal, part = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect(normal).never.toBeNil()
		expect(part).toBe(floor)
	end)

	it("gives no part where there is no ground", function()
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local _hit, _normal, part = ground(Vector3.new(5000, 0, 5000), made(Instance.new("Folder")))
		expect(part).toBeNil()
	end)

	it("ignores a part that can't be collided with, such as a bush", function()
		local floor = newFloor(0)
		local bush = made(Instance.new("Part"))
		bush.Anchored = true
		bush.CanCollide = false
		bush.Size = Vector3.new(4, 2, 4)
		bush.CFrame = CFrame.new(1000, 1.5, 1000)
		bush.Parent = Workspace
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(floor.Position.Y + 1, 3)
	end)

	it("ignores every player's character", function()
		newFloor(0)
		local character = made(Instance.new("Model"))
		local body = Instance.new("Part")
		body.Anchored = true
		body.Size = Vector3.new(4, 2, 4)
		body.CFrame = CFrame.new(1000, 1.5, 1000)
		body.Parent = character
		character.Parent = Workspace
		local players = {
			GetPlayers = function(_self: any)
				return { { Character = character } }
			end,
		}
		local ground = Footprints.workspaceGround(Workspace, players)
		local hit = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(0, 3)
	end)

	it("ignores the footprints themselves", function()
		newFloor(0)
		local holder = made(Instance.new("Folder"))
		local copy = Instance.new("Part")
		copy.Anchored = true
		copy.CanQuery = true
		copy.Size = Vector3.new(1.5, 0.15, 2.7)
		copy.CFrame = CFrame.new(1000, 0.1, 1000)
		copy.Parent = holder
		holder.Parent = Workspace
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit = ground(Vector3.new(1000, 0, 1000), holder)
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(0, 3)
	end)

	it("gives nothing where there is no ground", function()
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit, normal = ground(Vector3.new(5000, 0, 5000), made(Instance.new("Folder")))
		expect(hit).toBeNil()
		expect(normal).toBeNil()
	end)
end)

describe("Footprints.firstEgg", function()
	-- The fake route's egg spots stand where their route points are: EggSpot_Common_1 20 studs along +X, EggSpot_Common_2 40
	-- studs along -Z. (The rig makes them as empty models at the origin, so each test puts them in place.)
	local function placeSpots(rig: Rig)
		local first = rig.root:FindFirstChild("EggSpot_Common_1") :: Model?
		if first then
			first:PivotTo(CFrame.new(20, 1, 0))
		end
		local second = rig.root:FindFirstChild("EggSpot_Common_2") :: Model?
		if second then
			second:PivotTo(CFrame.new(0, 1, -40))
		end
	end

	local function asked(rig: Rig, points: { Point }?, feet: Vector3?): Vector3?
		return Footprints.firstEgg(RouteGraph.new(points or defaultPoints()), rig.root, rig.player :: any, feet)
	end

	it("is the place of the nearest waiting egg", function()
		local rig = newRig()
		placeSpots(rig)
		local egg = asked(rig, nil, Vector3.new(0, 0, 0))
		expect(egg).never.toBeNil()
		expectNear(egg :: Vector3, Vector3.new(20, 1, 0))
	end)

	it("is the other egg when the nearest one is not waiting", function()
		local rig = newRig()
		placeSpots(rig)
		rig.setWaiting("EggSpot_Common_1", false)
		local egg = asked(rig, nil, Vector3.new(0, 0, 0))
		expect(egg).never.toBeNil()
		expectNear(egg :: Vector3, Vector3.new(0, 1, -40))
	end)

	it("is nil when no egg is waiting", function()
		local rig = newRig()
		placeSpots(rig)
		rig.setWaiting("EggSpot_Common_1", false)
		rig.setWaiting("EggSpot_Common_2", false)
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("is nil while the player carries an egg, because the trail leads home then", function()
		local rig = newRig()
		placeSpots(rig)
		rig.player:SetAttribute("Carrying", "Common")
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("is nil for a player with no garden number", function()
		local rig = newRig({ noPlot = true })
		placeSpots(rig)
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("is nil without feet (no character)", function()
		local rig = newRig()
		placeSpots(rig)
		expect(asked(rig, nil, nil)).toBeNil()
	end)

	it("is nil when the waiting egg has no route point", function()
		local rig = newRig({ waiting = { "EggSpot_Common_9" } })
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("picks the egg with the shortest walk, not the nearest in a straight line, like the trail", function()
		-- The wall route of an earlier test: E1 is 20 studs away in a straight line but 80 by the route, E2 is 40.
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E2", "U" }, target = nil },
			{ name = "U", position = Vector3.new(0, 0, 30), neighbours = { "S", "V" }, target = nil },
			{ name = "V", position = Vector3.new(20, 0, 30), neighbours = { "U", "E1" }, target = nil },
			{ name = "E1", position = Vector3.new(20, 0, 0), neighbours = { "V" }, target = "EggSpot_Common_1" },
			{ name = "E2", position = Vector3.new(0, 0, -40), neighbours = { "S" }, target = "EggSpot_Common_2" },
		}
		local rig = newRig({ points = points })
		placeSpots(rig)
		local egg = asked(rig, points, Vector3.new(0, 0, 0))
		expect(egg).never.toBeNil()
		expectNear(egg :: Vector3, Vector3.new(0, 1, -40))
	end)

	it("is the egg the trail leads to, from several places along the route", function()
		local rig = newRig()
		placeSpots(rig)
		for _, feet in { Vector3.new(0, 0, 0), Vector3.new(15, 0, 0), Vector3.new(0, 0, -30), Vector3.new(-10, 0, 5) } do
			rig.feet.value = feet
			rig.advance(UPDATE_SECONDS)
			local egg = asked(rig, nil, feet) :: Vector3
			expect(egg).never.toBeNil()
			-- The trail lays its first footprint at the target, so one footprint stands on the egg's own spot.
			local nearest = math.huge
			for _, model in rig.shown() do
				local position = model:GetPivot().Position
				nearest = math.min(nearest, Vector2.new(position.X - egg.X, position.Z - egg.Z).Magnitude)
			end
			expect(nearest < 0.01).toBe(true)
		end
	end)
end)
