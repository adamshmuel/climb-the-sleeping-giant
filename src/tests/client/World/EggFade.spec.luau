--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local EggFade = require(Client.World.EggFade)

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

-- A value no fade ever produces (0.125 is exact in the 32-bit number a part stores, so it reads back unchanged). A test
-- writes it on a part to see later whether the fade wrote to that part again.
local SENTINEL = 0.125

describe("EggFade.blocks", function()
	-- The line of sight in these tests runs along Z, from the camera at z = -10 to the player at z = 10.
	local camera = Vector3.new(0, 0, -10)
	local player = Vector3.new(0, 0, 10)
	local size = Vector3.new(4, 4, 4)

	it("is true for a box halfway between the camera and the player", function()
		expect(EggFade.blocks(camera, player, CFrame.new(0, 0, 0), size)).toBe(true)
	end)

	it("is false for a box behind the camera", function()
		expect(EggFade.blocks(camera, player, CFrame.new(0, 0, -20), size)).toBe(false)
	end)

	it("is false for a box behind the player", function()
		expect(EggFade.blocks(camera, player, CFrame.new(0, 0, 20), size)).toBe(false)
	end)

	it("is false for a box beside the line", function()
		expect(EggFade.blocks(camera, player, CFrame.new(10, 0, 0), size)).toBe(false)
	end)

	it("is true when the camera sits inside the box", function()
		expect(EggFade.blocks(camera, player, CFrame.new(0, 0, -10), size)).toBe(true)
	end)

	it("is true for a box turned 30 degrees that the line only crosses because of the turn", function()
		-- A thin plank, 1 wide and 8 long, two studs to the side of the line. Straight, it misses (x 1.5 to 2.5).
		-- Turned 30 degrees about the up axis, its far end swings across the line.
		local plank = Vector3.new(1, 4, 8)
		expect(EggFade.blocks(camera, player, CFrame.new(2, 0, 0), plank)).toBe(false)
		expect(EggFade.blocks(camera, player, CFrame.new(2, 0, 0) * CFrame.Angles(0, math.rad(30), 0), plank)).toBe(
			true
		)
	end)

	it("is false for a box turned 30 degrees that the line only misses because of the turn", function()
		-- A plank 6 long and 1 thick, with the line 2.9 studs to the side. Straight, its end (x 3) is across the line.
		-- Turned 30 degrees, its end pulls in to x 2.85, short of the line.
		local plank = Vector3.new(6, 4, 1)
		local from = Vector3.new(2.9, 0, -10)
		local to = Vector3.new(2.9, 0, 10)
		expect(EggFade.blocks(from, to, CFrame.new(0, 0, 0), plank)).toBe(true)
		expect(EggFade.blocks(from, to, CFrame.Angles(0, math.rad(30), 0), plank)).toBe(false)
	end)
end)

describe("EggFade.targetsOf", function()
	-- A fake character: a model with a humanoid, a head and a root part.
	local function newCharacter(health: number, withHead: boolean): Model
		local character = made(Instance.new("Model"))
		local humanoid = Instance.new("Humanoid")
		humanoid.Health = health
		humanoid.Parent = character
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(1, 2, 3)
		root.Parent = character
		if withHead then
			local head = Instance.new("Part")
			head.Name = "Head"
			head.Position = Vector3.new(1, 4, 3)
			head.Parent = character
		end
		return character
	end

	it("gives the head and the root of a living character", function()
		local points = EggFade.targetsOf(newCharacter(100, true))
		expect(#points).toBe(2)
		expect(points[1]).toEqual(Vector3.new(1, 4, 3))
		expect(points[2]).toEqual(Vector3.new(1, 2, 3))
	end)

	it("gives only the root when the head is missing", function()
		local points = EggFade.targetsOf(newCharacter(100, false))
		expect(#points).toBe(1)
		expect(points[1]).toEqual(Vector3.new(1, 2, 3))
	end)

	it("gives nothing without a character", function()
		expect(#EggFade.targetsOf(nil)).toBe(0)
	end)

	it("gives nothing for a dead character", function()
		expect(#EggFade.targetsOf(newCharacter(0, true))).toBe(0)
	end)
end)

type Rig = {
	root: Folder,
	step: any,
	clock: { now: number },
	view: { camera: CFrame?, targets: { Vector3 } },
	addSpot: (name: string) -> Model,
	addEgg: (spot: Model, position: Vector3) -> Model,
	advance: (seconds: number) -> (),
	stop: () -> (),
}

-- A fake egg like the real ones: Egg > body (a model) > body_geom (a mesh), where body_geom holds the light, the sparkles
-- and the label. A second part sits next to body_geom, so a test can see that every part is set, not only one.
local function newEggModel(position: Vector3): Model
	local egg = Instance.new("Model")
	egg.Name = "Egg"
	local body = Instance.new("Model")
	body.Name = "body"
	body.Parent = egg
	local geometry = Instance.new("MeshPart")
	geometry.Name = "body_geom"
	geometry.Anchored = true
	geometry.Size = Vector3.new(2, 2, 2)
	geometry.CFrame = CFrame.new(position)
	geometry.Parent = body
	local extra = Instance.new("Part")
	extra.Name = "extra"
	extra.Anchored = true
	extra.Size = Vector3.new(1, 1, 1)
	extra.CFrame = CFrame.new(position)
	extra.Parent = body
	local light = Instance.new("PointLight")
	light.Parent = geometry
	local attachment = Instance.new("Attachment")
	attachment.Name = "FX"
	attachment.Parent = geometry
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Parent = attachment
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Parent = geometry
	local words = Instance.new("TextLabel")
	words.Text = "Common"
	words.Parent = gui
	return egg
end

-- Starts the fade on fake egg spots, a fake camera, a fake player, a fake clock and a fake frame signal. The camera
-- starts at z = -20 and the player (head and root) at the origin, so an egg at z = -10 sits between them.
local function newRig(): Rig
	local root = made(Instance.new("Folder"))
	local step = newSignal()
	local clock = { now = 100 }
	local view: { camera: CFrame?, targets: { Vector3 } } = {
		camera = CFrame.new(0, 0, -20),
		targets = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 0) },
	}
	local fade = EggFade.start({
		root = root,
		camera = function()
			return view.camera
		end,
		targets = function()
			return view.targets
		end,
		step = step,
		now = function()
			return clock.now
		end,
	})
	table.insert(stops, fade.stop)
	return {
		root = root,
		step = step,
		clock = clock,
		view = view,
		addSpot = function(name: string): Model
			local spot = made(Instance.new("Model"))
			spot.Name = name
			spot.Parent = root
			task.wait()
			return spot
		end,
		addEgg = function(spot: Model, position: Vector3): Model
			local egg = newEggModel(position)
			egg.Parent = spot
			task.wait()
			return egg
		end,
		advance = function(seconds: number)
			clock.now += seconds
			step:Fire()
		end,
		stop = fade.stop,
	}
end

local BLOCKING = Vector3.new(0, 0, -10)

-- The part the tests read: the egg's mesh.
local function bodyOf(egg: Model): BasePart
	return egg:FindFirstChild("body_geom", true) :: BasePart
end

describe("EggFade.start", function()
	it("fades a blocking egg in to exactly 0.7 in 0.15 seconds", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.15)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
	end)

	it("is about half way in after 0.075 seconds", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.075)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.35, 5)
	end)

	it("reaches 0.7 over many small frames, and never goes past it", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		for _ = 1, 30 do
			rig.advance(1 / 60)
			expect(bodyOf(egg).LocalTransparencyModifier <= 0.7).toBe(true)
		end
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.7, 5)
	end)

	it("fades back to exactly 0 in 0.3 seconds once the egg no longer blocks", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.15)
		rig.view.camera = CFrame.new(50, 0, -20)
		rig.advance(0.15)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.35, 5)
		rig.advance(0.15)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(0)
	end)

	it("turns back from half way at the fade-out pace", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.075)
		rig.view.camera = CFrame.new(50, 0, -20)
		rig.advance(0.075)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.175, 5)
		rig.advance(0.075)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(0)
	end)

	it("never writes to an egg that never blocks, and it stays at 0", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), Vector3.new(50, 0, -10))
		bodyOf(egg).LocalTransparencyModifier = SENTINEL
		rig.advance(0.2)
		rig.advance(0.2)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(SENTINEL)
	end)

	it("does not write again while the value stays the same", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.15)
		bodyOf(egg).LocalTransparencyModifier = SENTINEL
		rig.advance(0.1)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(SENTINEL)
	end)

	it("blocks when only the head is behind the egg", function()
		local rig = newRig()
		rig.view.camera = CFrame.new(0, 0, -20)
		rig.view.targets = { Vector3.new(0, 5, 0), Vector3.new(0, 0, 0) }
		-- The egg is high: the line from the camera to the head crosses it, the line to the root does not.
		local egg = rig.addEgg(rig.addSpot("Spot"), Vector3.new(0, 2.5, -10))
		rig.advance(0.15)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
	end)

	it("blocks when only the root is behind the egg", function()
		local rig = newRig()
		rig.view.camera = CFrame.new(0, 0, -20)
		rig.view.targets = { Vector3.new(0, 5, 0), Vector3.new(0, 0, 0) }
		-- The egg is low: the line from the camera to the root crosses it, the line to the head does not.
		local egg = rig.addEgg(rig.addSpot("Spot"), Vector3.new(0, 0, -10))
		rig.advance(0.15)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
	end)

	it("fades only the egg that is in the way", function()
		local rig = newRig()
		local inTheWay = rig.addEgg(rig.addSpot("Near"), BLOCKING)
		local beside = rig.addEgg(rig.addSpot("Far"), Vector3.new(30, 0, -10))
		rig.advance(0.15)
		expect(bodyOf(inTheWay).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
		expect(bodyOf(beside).LocalTransparencyModifier).toBe(0)
	end)

	it("sets every part of the egg, and leaves the light, the sparkles and the label alone", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		local geometry = bodyOf(egg)
		local extra = egg:FindFirstChild("extra", true) :: Part
		local light = geometry:FindFirstChildOfClass("PointLight") :: PointLight
		local sparkles = geometry:FindFirstChild("Sparkles", true) :: ParticleEmitter
		local gui = geometry:FindFirstChildOfClass("BillboardGui") :: BillboardGui
		local words = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
		local before = {
			brightness = light.Brightness,
			enabled = light.Enabled,
			sparklesTransparency = sparkles.Transparency,
			sparklesEnabled = sparkles.Enabled,
			guiEnabled = gui.Enabled,
			text = words.Text,
			textTransparency = words.TextTransparency,
		}
		rig.advance(0.15)
		expect(geometry.LocalTransparencyModifier).toBeCloseTo(0.7, 7)
		expect(extra.LocalTransparencyModifier).toBeCloseTo(0.7, 7)
		expect(light.Brightness).toBe(before.brightness)
		expect(light.Enabled).toBe(before.enabled)
		expect(sparkles.Transparency).toEqual(before.sparklesTransparency)
		expect(sparkles.Enabled).toBe(before.sparklesEnabled)
		expect(gui.Enabled).toBe(before.guiEnabled)
		expect(words.Text).toBe(before.text)
		expect(words.TextTransparency).toBe(before.textTransparency)
	end)

	it("gives a part that arrives while the egg is faded the same see-through", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.15)
		local late = Instance.new("Part")
		late.Anchored = true
		late.Parent = egg:FindFirstChild("body") :: Model
		task.wait()
		expect(late.LocalTransparencyModifier).toBeCloseTo(0.7, 7)
	end)

	it("forgets an egg that goes away, and the next egg on that spot starts clear", function()
		local rig = newRig()
		local spot = rig.addSpot("Spot")
		local first = rig.addEgg(spot, BLOCKING)
		rig.advance(0.075)
		first.Parent = nil
		task.wait()
		bodyOf(first).LocalTransparencyModifier = SENTINEL
		rig.advance(0.01)
		expect(bodyOf(first).LocalTransparencyModifier).toBe(SENTINEL)

		local second = rig.addEgg(spot, BLOCKING)
		expect(bodyOf(second).LocalTransparencyModifier).toBe(0)
		rig.advance(0.015)
		expect(bodyOf(second).LocalTransparencyModifier).toBeCloseTo(0.07, 5)
		first:Destroy()
	end)

	it("follows a spot that is added later", function()
		local rig = newRig()
		rig.advance(0.05)
		local egg = rig.addEgg(rig.addSpot("Late"), BLOCKING)
		rig.advance(0.15)
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
	end)

	it("follows an egg that is there before the fade starts", function()
		local root = made(Instance.new("Folder"))
		local spot = Instance.new("Model")
		spot.Parent = root
		local egg = newEggModel(BLOCKING)
		egg.Parent = spot
		local step = newSignal()
		local clock = { now = 5 }
		local fade = EggFade.start({
			root = root,
			camera = function()
				return CFrame.new(0, 0, -20)
			end,
			targets = function()
				return { Vector3.new(0, 0, 0) }
			end,
			step = step,
			now = function()
				return clock.now
			end,
		})
		table.insert(stops, fade.stop)
		clock.now += 0.15
		step:Fire()
		expect(bodyOf(egg).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
	end)

	it("blocks nothing without a character, and a faded egg fades back", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.15)
		rig.view.targets = {}
		rig.advance(0.3)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(0)
	end)

	it("blocks nothing from the start when there is no character", function()
		local rig = newRig()
		rig.view.targets = {}
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		bodyOf(egg).LocalTransparencyModifier = SENTINEL
		rig.advance(0.5)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(SENTINEL)
	end)

	it("blocks nothing without a camera, and a faded egg fades back", function()
		local rig = newRig()
		local egg = rig.addEgg(rig.addSpot("Spot"), BLOCKING)
		rig.advance(0.15)
		rig.view.camera = nil
		rig.advance(0.3)
		expect(bodyOf(egg).LocalTransparencyModifier).toBe(0)
	end)

	it("stop puts every egg back to 0", function()
		local rig = newRig()
		local first = rig.addEgg(rig.addSpot("One"), BLOCKING)
		local second = rig.addEgg(rig.addSpot("Two"), BLOCKING)
		rig.advance(0.15)
		expect(bodyOf(first).LocalTransparencyModifier).toBeCloseTo(0.7, 7)
		rig.stop()
		expect(bodyOf(first).LocalTransparencyModifier).toBe(0)
		expect(bodyOf(second).LocalTransparencyModifier).toBe(0)
	end)

	it("stop disconnects: the frame signal has no listeners and a new egg is left alone", function()
		local rig = newRig()
		local spot = rig.addSpot("Spot")
		rig.addEgg(spot, BLOCKING)
		expect(rig.step:count()).toBe(1)
		rig.stop()
		expect(rig.step:count()).toBe(0)
		local later = rig.addEgg(spot, BLOCKING)
		bodyOf(later).LocalTransparencyModifier = SENTINEL
		rig.advance(0.2)
		expect(bodyOf(later).LocalTransparencyModifier).toBe(SENTINEL)
	end)

	it("stop can be called twice", function()
		local rig = newRig()
		rig.stop()
		rig.stop()
		expect(rig.step:count()).toBe(0)
	end)
end)
