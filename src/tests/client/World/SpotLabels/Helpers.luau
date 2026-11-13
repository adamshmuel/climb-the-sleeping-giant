--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)

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

type Rig = {
	parent: Folder,
	root: Folder,
	step: any,
	clock: { now: number },
	addSpot: (name: string, rarity: string, baseCFrame: CFrame?) -> Model,
	set: (spot: Model, name: string, value: any) -> (),
	labels: () -> { BillboardGui },
	labelOf: (spot: Model) -> BillboardGui?,
	textOf: (spot: Model) -> TextLabel,
	advance: (seconds: number) -> (),
	stop: () -> (),
}

-- A fake egg spot like the real ones: a Model with a Rarity and a flat Base part (2 x 0.2 x 2) whose top is where
-- the egg's bottom sits. `waiting`: nil leaves Waiting unset.
local function newSpotModel(name: string, rarity: string, baseCFrame: CFrame): Model
	local model = made(Instance.new("Model"))
	model.Name = name
	model:SetAttribute("Rarity", rarity)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(2, 0.2, 2)
	base.CFrame = baseCFrame
	base.Anchored = true
	base.Parent = model
	return model
end

-- A fake egg on a spot: a model with one part that is `height` studs tall (its extents are what the label reads).
local function addEgg(spot: Model, height: number): Model
	local egg = Instance.new("Model")
	egg.Name = "Egg"
	local part = Instance.new("Part")
	part.Size = Vector3.new(3, height, 3)
	part.Parent = egg
	egg.Parent = spot
	task.wait()
	return egg
end

-- Starts the labels on a fake player screen, fake egg spots, a fake clock and a fake frame signal.
local function newRig(view: SpotLabels.View?): Rig
	local parent = made(Instance.new("Folder"))
	local root = made(Instance.new("Folder"))
	local step = newSignal()
	local clock = { now = 100 }
	local stop = SpotLabels.start({
		parent = parent,
		root = root,
		now = function()
			return clock.now
		end,
		step = step,
		view = view,
	})
	table.insert(stops, stop)

	local function labels(): { BillboardGui }
		local found: { BillboardGui } = {}
		for _, descendant in parent:GetDescendants() do
			if descendant:IsA("BillboardGui") and descendant.Name == "SpotLabel" then
				table.insert(found, descendant)
			end
		end
		return found
	end
	local function labelOf(spot: Model): BillboardGui?
		for _, gui in labels() do
			if gui.Adornee == spot:FindFirstChild("Base") then
				return gui
			end
		end
		return nil
	end
	return {
		parent = parent,
		root = root,
		step = step,
		clock = clock,
		addSpot = function(name: string, rarity: string, baseCFrame: CFrame?): Model
			local spot = newSpotModel(name, rarity, baseCFrame or CFrame.new(0, 10, 0))
			spot.Parent = root
			task.wait()
			return spot
		end,
		set = function(spot: Model, attribute: string, value: any)
			spot:SetAttribute(attribute, value)
			task.wait()
		end,
		labels = labels,
		labelOf = labelOf,
		textOf = function(spot: Model): TextLabel
			return (labelOf(spot) :: BillboardGui):FindFirstChildOfClass("TextLabel") :: TextLabel
		end,
		advance = function(seconds: number)
			clock.now += seconds
			step:Fire(seconds)
		end,
		stop = stop,
	}
end

-- A rectangle on the screen, in pixels, from the top left corner.
local function rect(x: number, y: number, width: number, height: number): SpotLabels.Rect
	return { x = x, y = y, width = width, height = height }
end

-- A stand-in for the screen: the rectangle (and distance) each spot's label has this moment, and the meter's box.
type FakeScreen = {
	view: SpotLabels.View,
	places: { [string]: { rect: SpotLabels.Rect, distance: number } },
	meter: SpotLabels.Rect?,
	pill: SpotLabels.Rect?, -- the RUN HOME! pill's box, or nothing
	calls: number, -- how many times a label was measured
	measured: { [string]: number }, -- how many times each spot's label was measured
	centres: { [string]: Vector3 }, -- where each spot's label was said to be centred, in the world, at its last measuring
}

local function newScreen(): FakeScreen
	local screen: FakeScreen = {
		places = {},
		meter = nil,
		pill = nil,
		calls = 0,
		measured = {},
		centres = {},
		view = nil :: any,
	}
	screen.view = {
		words = function(gui: BillboardGui, _text: TextLabel, centre: Vector3)
			local spot = (gui.Adornee :: Instance).Parent :: Instance
			screen.calls += 1
			screen.centres[spot.Name] = centre
			screen.measured[spot.Name] = (screen.measured[spot.Name] or 0) + 1
			local place = screen.places[spot.Name]
			if place == nil then
				return nil
			end
			return place.rect, place.distance
		end,
		meter = function()
			return screen.meter
		end,
		pill = function()
			return screen.pill
		end,
	}
	return screen
end

local function seeThrough(rig: Rig, spot: Model): number
	return rig.textOf(spot).TextTransparency
end

local function outlineSeeThrough(rig: Rig, spot: Model): number
	return (rig.textOf(spot):FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency
end

-- Two waiting Rare spots whose labels overlap on the screen. Rare_1 is the nearer one.
local function overlappingRares(screen: FakeScreen): (Rig, Model, Model)
	local rig = newRig(screen.view)
	local near = rig.addSpot("EggSpot_Rare_1", "Rare")
	local far = rig.addSpot("EggSpot_Rare_2", "Rare")
	screen.places["EggSpot_Rare_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
	screen.places["EggSpot_Rare_2"] = { rect = rect(330, 210, 80, 30), distance = 20 }
	rig.set(near, "Waiting", true)
	rig.set(far, "Waiting", true)
	return rig, near, far
end

return {
	addEgg = addEgg,
	cleanUp = cleanUp,
	made = made,
	newRig = newRig,
	newScreen = newScreen,
	newSignal = newSignal,
	newSpotModel = newSpotModel,
	outlineSeeThrough = outlineSeeThrough,
	overlappingRares = overlappingRares,
	rect = rect,
	seeThrough = seeThrough,
	stops = stops,
}
