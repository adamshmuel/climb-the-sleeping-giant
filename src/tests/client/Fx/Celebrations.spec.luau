--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local Celebrations = require(Client.Fx.Celebrations)
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

-- A player stand-in: only its PlotIndex attribute is read.
local function newPlayer(plotIndex: any): any
	local attributes = made(Instance.new("Folder"))
	attributes:SetAttribute("PlotIndex", plotIndex)
	return attributes
end

-- The caught puff's template as the place has it: an Attachment holding two emitters that are switched off.
local function newTemplate(): Attachment
	local template = made(Instance.new("Attachment"))
	template.Name = "CaughtPoof"
	for _, name in { "CaughtPoof", "CaughtCloud" } do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.Enabled = false
		emitter.Parent = template
	end
	return template
end

-- A spawn spot as the world has it: 6 x 1 x 6, so its top is half a stud above its middle.
local function newSpot(position: Vector3): Part
	local spot = made(Instance.new("Part"))
	spot.Name = "SpawnSpot"
	spot.Size = Vector3.new(6, 1, 6)
	spot.Position = position
	return spot
end

type Burst = { name: string, count: number, copy: Instance? }

type Rig = {
	anchor: Part,
	eggHome: any,
	caught: any,
	step: any,
	emits: { { plot: number, count: number } },
	bursts: { Burst },
	missingGates: { [number]: boolean },
	spots: { [number]: BasePart },
	template: Attachment,
	stop: () -> (),
	advance: (seconds: number) -> (),
	floaters: () -> { Attachment },
	puffs: () -> { Attachment },
}

local function newRig(noTemplate: boolean?): Rig
	local anchor = made(Instance.new("Part"))
	local eggHome = newSignal()
	local caught = newSignal()
	local step = newSignal()
	local emits: { { plot: number, count: number } } = {}
	local bursts: { Burst } = {}
	local missingGates: { [number]: boolean } = {}
	local spots: { [number]: BasePart } = {}
	local template = newTemplate()
	local clock = 100

	local stop = Celebrations.start({
		eggHome = { OnClientEvent = eggHome },
		findEmitter = function(plotIndex: number)
			if missingGates[plotIndex] then
				return nil
			end
			return {
				Emit = function(_self: any, count: number)
					table.insert(emits, { plot = plotIndex, count = count })
				end,
			}
		end,
		caught = { OnClientEvent = caught },
		findSpawnSpot = function(plotIndex: number)
			return spots[plotIndex]
		end,
		poofTemplate = if noTemplate then nil else template,
		burst = function(emitter: ParticleEmitter, count: number)
			table.insert(bursts, { name = emitter.Name, count = count, copy = emitter.Parent })
		end,
		anchorParent = anchor,
		step = step,
		now = function()
			return clock
		end,
	})
	table.insert(stops, stop)

	return {
		anchor = anchor,
		eggHome = eggHome,
		caught = caught,
		step = step,
		emits = emits,
		bursts = bursts,
		missingGates = missingGates,
		spots = spots,
		template = template,
		stop = stop,
		advance = function(seconds: number)
			clock += seconds
			step:Fire(seconds)
		end,
		floaters = function()
			local found: { Attachment } = {}
			for _, child in anchor:GetChildren() do
				if child:IsA("Attachment") and child.Name == "EggPlusOne" then
					table.insert(found, child)
				end
			end
			return found
		end,
		puffs = function()
			local found: { Attachment } = {}
			for _, child in anchor:GetChildren() do
				if child:IsA("Attachment") and child.Name == "CaughtPoof" then
					table.insert(found, child)
				end
			end
			return found
		end,
	}
end

local function billboardOf(attachment: Attachment): BillboardGui
	return attachment:FindFirstChildOfClass("BillboardGui") :: BillboardGui
end

describe("Celebrations.float", function()
	it("has no rise and is fully visible at the start", function()
		local state = Celebrations.float(0)
		expect(state.rise).toBe(0)
		expect(state.transparency).toBe(0)
	end)

	it("has risen 3 studs and is fully see-through at the end", function()
		local state = Celebrations.float(1)
		expect(state.rise).toBe(3)
		expect(state.transparency).toBe(1)
	end)

	it("keeps rising and fading as time passes", function()
		local last = Celebrations.float(0)
		for step = 1, 10 do
			local state = Celebrations.float(step / 10)
			expect(state.rise > last.rise).toBe(true)
			expect(state.transparency > last.transparency).toBe(true)
			last = state
		end
	end)

	it("stays at its first values before the start and its last values after the end", function()
		expect(Celebrations.float(-0.5).rise).toBe(0)
		expect(Celebrations.float(-0.5).transparency).toBe(0)
		expect(Celebrations.float(2).rise).toBe(3)
		expect(Celebrations.float(2).transparency).toBe(1)
	end)
end)

describe("Celebrations.emitterInWorld", function()
	local function buildWorld(plotName: string): (Folder, ParticleEmitter)
		local world = made(Instance.new("Folder"))
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = world
		local plot = Instance.new("Folder")
		plot.Name = plotName
		plot.Parent = plots
		local gate = Instance.new("Model")
		gate.Name = "SafeGate"
		gate.Parent = plot
		local source = Instance.new("Part")
		source.Name = "ConfettiSource"
		source.Parent = gate
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SafeConfetti"
		emitter.Parent = source
		return world, emitter
	end

	it("finds the confetti emitter on a garden's Safe Gate", function()
		local world, emitter = buildWorld("Plot_2")
		expect(Celebrations.emitterInWorld(world)(2)).toBe(emitter)
	end)

	it("gives nothing for a garden that is not there", function()
		local world = buildWorld("Plot_2")
		expect(Celebrations.emitterInWorld(world)(3)).toBeNil()
	end)

	it("gives nothing when the world has no Plots", function()
		local world = made(Instance.new("Folder"))
		expect(Celebrations.emitterInWorld(world)(1)).toBeNil()
	end)

	it("gives nothing when the gate has no emitter", function()
		local world, emitter = buildWorld("Plot_1")
		emitter:Destroy()
		expect(Celebrations.emitterInWorld(world)(1)).toBeNil()
	end)
end)

describe("Celebrations: the confetti", function()
	it("bursts 160 from the gate of the garden the player's PlotIndex names", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(2), "Common", Vector3.new(0, 5, 0))
		expect(#rig.emits).toBe(1)
		expect(rig.emits[1].plot).toBe(2)
		expect(rig.emits[1].count).toBe(160)
	end)

	it("bursts for any player, each from their own gate", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(2), "Common", Vector3.new(0, 5, 0))
		rig.eggHome:Fire(newPlayer(7), "Rare", Vector3.new(50, 5, 0))
		expect(#rig.emits).toBe(2)
		expect(rig.emits[2].plot).toBe(7)
	end)

	it("does nothing, and does not error, when the gate is missing", function()
		local rig = newRig()
		rig.missingGates[2] = true
		rig.eggHome:Fire(newPlayer(2), "Common", Vector3.new(0, 5, 0))
		expect(#rig.emits).toBe(0)
	end)

	it("does nothing when the player has no garden number (or a wrong one)", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(nil), "Common", Vector3.new(0, 5, 0))
		rig.eggHome:Fire(newPlayer("two"), "Common", Vector3.new(0, 5, 0))
		rig.eggHome:Fire(newPlayer(2.5), "Common", Vector3.new(0, 5, 0))
		expect(#rig.emits).toBe(0)
	end)

	it("still shows +1 egg when the gate is missing", function()
		local rig = newRig()
		rig.missingGates[2] = true
		rig.eggHome:Fire(newPlayer(2), "Common", Vector3.new(0, 5, 0))
		expect(#rig.floaters()).toBe(1)
	end)
end)

describe("Celebrations: +1 egg", function()
	it("is made at the given position, in gold words with an Ink outline and no panel", function()
		local rig = newRig()
		local position = Vector3.new(10, 8, -4)
		rig.eggHome:Fire(newPlayer(1), "Common", position)
		local floaters = rig.floaters()
		expect(#floaters).toBe(1)
		expect(floaters[1].WorldPosition).toBe(position)

		local gui = billboardOf(floaters[1])
		expect(gui.Adornee).toBe(floaters[1])
		local label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
		expect(label.Text).toBe("+1 egg")
		expect(label.TextColor3 == Theme.gold).toBe(true)
		expect(label.BackgroundTransparency).toBe(1)
		expect(label.FontFace == Theme.font).toBe(true)
		local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.ink).toBe(true)
	end)

	it("is a big studs-sized sign drawn on top of the world, 12 x 3.6 studs with text between 18 and 44 px", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(1), "Common", Vector3.new(0, 5, 0))
		local gui = billboardOf(rig.floaters()[1])
		expect(gui.Size).toBe(UDim2.fromScale(12, 3.6))
		expect(gui.AlwaysOnTop).toBe(true)
		expect(gui.LightInfluence).toBe(0)
		expect(gui.MaxDistance).toBe(120)
		expect(Celebrations.startLift).toBe(2)
		local label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		expect(limit.MinTextSize).toBe(18)
		expect(limit.MaxTextSize).toBe(44)
	end)

	it("starts visible and low, and floats up and fades as time passes", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(1), "Common", Vector3.new(0, 5, 0))
		local gui = billboardOf(rig.floaters()[1])
		local label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
		local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke

		rig.advance(0.5)
		local half = Celebrations.float(0.5)
		expect(gui.StudsOffsetWorldSpace.X).toBe(0)
		expect(gui.StudsOffsetWorldSpace.Z).toBe(0)
		expect(math.abs(gui.StudsOffsetWorldSpace.Y - Celebrations.startLift - half.rise) < 0.001).toBe(true)
		expect(math.abs(label.TextTransparency - half.transparency) < 0.001).toBe(true)
		expect(math.abs(stroke.Transparency - half.transparency) < 0.001).toBe(true)
	end)

	it("is still there just before 1 second and gone after 1 second", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(1), "Common", Vector3.new(0, 5, 0))
		rig.advance(0.9)
		expect(#rig.floaters()).toBe(1)
		rig.advance(0.1)
		expect(#rig.floaters()).toBe(0)
	end)

	it("can have several floating at once, each on its own clock", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(1), "Common", Vector3.new(0, 5, 0))
		rig.advance(0.6)
		rig.eggHome:Fire(newPlayer(2), "Rare", Vector3.new(40, 5, 0))
		expect(#rig.floaters()).toBe(2)
		rig.advance(0.5)
		expect(#rig.floaters()).toBe(1)
		rig.advance(0.5)
		expect(#rig.floaters()).toBe(0)
	end)

	it("is shown for every player's egg", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(5), "Uncommon", Vector3.new(80, 5, 20))
		expect(#rig.floaters()).toBe(1)
	end)

	it("is not made when the position is not a Vector3", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(1), "Common", nil)
		rig.eggHome:Fire(newPlayer(1), "Common", "here")
		expect(#rig.floaters()).toBe(0)
	end)
end)

describe("Celebrations.start", function()
	it("removes every +1 egg and stops listening when stopped", function()
		local rig = newRig()
		rig.eggHome:Fire(newPlayer(1), "Common", Vector3.new(0, 5, 0))
		rig.eggHome:Fire(newPlayer(2), "Common", Vector3.new(30, 5, 0))
		expect(#rig.floaters()).toBe(2)
		rig.stop()
		expect(#rig.floaters()).toBe(0)
		expect(#rig.anchor:GetChildren()).toBe(0)
		expect(rig.eggHome:count()).toBe(0)
		expect(rig.step:count()).toBe(0)
	end)

	it("does nothing for an egg that comes home after it was stopped", function()
		local rig = newRig()
		rig.stop()
		rig.eggHome:Fire(newPlayer(1), "Common", Vector3.new(0, 5, 0))
		expect(#rig.floaters()).toBe(0)
		expect(#rig.emits).toBe(0)
	end)

	it("can be stopped twice", function()
		local rig = newRig()
		rig.stop()
		rig.stop()
		expect(#rig.anchor:GetChildren()).toBe(0)
	end)
end)

describe("Celebrations.spawnSpotInWorld", function()
	local function buildWorld(plotName: string, spotName: string): (Folder, Part)
		local world = made(Instance.new("Folder"))
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = world
		local plot = Instance.new("Folder")
		plot.Name = plotName
		plot.Parent = plots
		local spot = Instance.new("Part")
		spot.Name = spotName
		spot.Parent = plot
		return world, spot
	end

	it("finds Plots.Plot_4.SpawnSpot for garden 4", function()
		local world, spot = buildWorld("Plot_4", "SpawnSpot")
		expect(Celebrations.spawnSpotInWorld(world)(4)).toBe(spot)
	end)

	it("gives nothing for a garden that is not there", function()
		local world = buildWorld("Plot_4", "SpawnSpot")
		expect(Celebrations.spawnSpotInWorld(world)(5)).toBeNil()
	end)

	it("gives nothing when the garden has no spawn spot", function()
		local world = buildWorld("Plot_4", "Something")
		expect(Celebrations.spawnSpotInWorld(world)(4)).toBeNil()
	end)

	it("gives nothing when the world has no Plots", function()
		local world = made(Instance.new("Folder"))
		expect(Celebrations.spawnSpotInWorld(world)(4)).toBeNil()
	end)

	it("looks again on every call, so a spot that streams in later is found", function()
		local world = made(Instance.new("Folder"))
		local find = Celebrations.spawnSpotInWorld(world)
		expect(find(4)).toBeNil()
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = world
		local plot = Instance.new("Folder")
		plot.Name = "Plot_4"
		plot.Parent = plots
		local spot = Instance.new("Part")
		spot.Name = "SpawnSpot"
		spot.Parent = plot
		expect(find(4)).toBe(spot)
	end)
end)

describe("Celebrations: the caught star puff", function()
	it("puts one copy of the template at the top of the player's own spawn spot plus 3 studs", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(4))
		local puffs = rig.puffs()
		expect(#puffs).toBe(1)
		expect(puffs[1]).never.toBe(rig.template)
		-- the spot's middle is at 5, its top at 5.5, and the puff stands 3 studs above that
		expect(puffs[1].WorldPosition).toBe(Vector3.new(10, 8.5, -20))
	end)

	it("bursts 30 stars and 15 smoke puffs from the copy, once each", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(4))
		expect(#rig.bursts).toBe(2)
		local counts: { [string]: number } = {}
		for _, burst in rig.bursts do
			counts[burst.name] = burst.count
			expect(burst.copy).toBe(rig.puffs()[1])
		end
		expect(counts.CaughtPoof).toBe(30)
		expect(counts.CaughtCloud).toBe(15)
	end)

	it("is placed at the spot of the player who was caught, not at the spot of the local player", function()
		local rig = newRig()
		rig.spots[1] = newSpot(Vector3.new(0, 5, 0))
		rig.spots[8] = newSpot(Vector3.new(100, 5, 100))
		rig.caught:Fire(newPlayer(8))
		expect(rig.puffs()[1].WorldPosition).toBe(Vector3.new(100, 8.5, 100))
	end)

	it("leaves the template as it was: still switched off and still in its place", function()
		local rig = newRig()
		local home = made(Instance.new("Folder"))
		rig.template.Parent = home
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(4))
		expect(rig.template.Parent).toBe(home)
		expect(rig.template.WorldPosition).toBe(Vector3.zero)
		for _, emitter in rig.template:GetChildren() do
			expect((emitter :: ParticleEmitter).Enabled).toBe(false)
		end
		expect(#rig.template:GetChildren()).toBe(2)
	end)

	it("makes a second copy for a second catch, each on its own spot", function()
		local rig = newRig()
		rig.spots[2] = newSpot(Vector3.new(10, 5, 0))
		rig.spots[6] = newSpot(Vector3.new(-10, 5, 0))
		rig.caught:Fire(newPlayer(2))
		rig.caught:Fire(newPlayer(6))
		expect(#rig.puffs()).toBe(2)
		expect(#rig.bursts).toBe(4)
	end)

	it("makes no puff for something that is not an Instance", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(nil)
		rig.caught:Fire("Leo")
		rig.caught:Fire(4)
		rig.caught:Fire({
			GetAttribute = function()
				return 4
			end,
		})
		expect(#rig.puffs()).toBe(0)
		expect(#rig.bursts).toBe(0)
	end)

	it("makes no puff for a player with no garden number (or a wrong one)", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(nil))
		rig.caught:Fire(newPlayer("4"))
		rig.caught:Fire(newPlayer(4.5))
		rig.caught:Fire(newPlayer(0))
		expect(#rig.puffs()).toBe(0)
		expect(#rig.bursts).toBe(0)
	end)

	it("makes no puff, and does not error, when the garden's spawn spot is not there", function()
		local rig = newRig()
		rig.caught:Fire(newPlayer(4))
		expect(#rig.puffs()).toBe(0)
		expect(#rig.bursts).toBe(0)
	end)

	it("makes no puff when there is no template, and the egg celebrations still work", function()
		local rig = newRig(true)
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(4))
		expect(#rig.puffs()).toBe(0)
		expect(#rig.bursts).toBe(0)
		rig.eggHome:Fire(newPlayer(4), "Common", Vector3.new(0, 5, 0))
		expect(#rig.floaters()).toBe(1)
		expect(#rig.emits).toBe(1)
	end)

	it("is still there 2.9 seconds after the burst and gone 3.1 seconds after", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(4))
		rig.advance(2.9)
		expect(#rig.puffs()).toBe(1)
		rig.advance(0.2)
		expect(#rig.puffs()).toBe(0)
	end)

	it("counts each copy's 3 seconds from its own burst", function()
		local rig = newRig()
		rig.spots[2] = newSpot(Vector3.new(10, 5, 0))
		rig.spots[6] = newSpot(Vector3.new(-10, 5, 0))
		rig.caught:Fire(newPlayer(2))
		rig.advance(2)
		rig.caught:Fire(newPlayer(6))
		rig.advance(1.5) -- 3.5 s after the first burst, 1.5 s after the second
		expect(#rig.puffs()).toBe(1)
		rig.advance(1.6) -- 3.1 s after the second
		expect(#rig.puffs()).toBe(0)
	end)

	it("is removed with everything else when stopped, and later catches do nothing", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.caught:Fire(newPlayer(4))
		rig.caught:Fire(newPlayer(4))
		expect(#rig.puffs()).toBe(2)
		rig.stop()
		expect(#rig.puffs()).toBe(0)
		expect(#rig.anchor:GetChildren()).toBe(0)
		expect(rig.caught:count()).toBe(0)
		rig.caught:Fire(newPlayer(4))
		expect(#rig.puffs()).toBe(0)
		expect(#rig.bursts).toBe(4)
	end)

	it("does not touch the +1 egg floaters", function()
		local rig = newRig()
		rig.spots[4] = newSpot(Vector3.new(10, 5, -20))
		rig.eggHome:Fire(newPlayer(4), "Common", Vector3.new(0, 5, 0))
		rig.caught:Fire(newPlayer(4))
		expect(#rig.floaters()).toBe(1)
		expect(#rig.puffs()).toBe(1)
	end)
end)
