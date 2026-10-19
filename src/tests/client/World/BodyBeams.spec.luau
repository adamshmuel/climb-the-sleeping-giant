--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local BodyBeams = require(Client.World.BodyBeams)

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

describe("BodyBeams.shouldShow", function()
	it("shows the beam when the camera is far away (40 studs)", function()
		expect(BodyBeams.shouldShow(40, false)).toBe(true)
	end)

	it("hides the beam when the camera is close (29 studs)", function()
		expect(BodyBeams.shouldShow(29, true)).toBe(false)
	end)

	it("hides the beam at exactly 30 studs", function()
		expect(BodyBeams.shouldShow(30, true)).toBe(false)
	end)

	it("keeps a hidden beam hidden at 33 studs", function()
		expect(BodyBeams.shouldShow(33, false)).toBe(false)
	end)

	it("keeps a shown beam shown at 33 studs", function()
		expect(BodyBeams.shouldShow(33, true)).toBe(true)
	end)

	it("keeps the last state at exactly 35 studs", function()
		expect(BodyBeams.shouldShow(35, false)).toBe(false)
		expect(BodyBeams.shouldShow(35, true)).toBe(true)
	end)

	it("shows a hidden beam again at 36 studs", function()
		expect(BodyBeams.shouldShow(36, false)).toBe(true)
	end)
end)

-- The zone boxes of the real world are parts with a Zone attribute inside World.Zones.
local function newZoneWorld(): Folder
	local world = made(Instance.new("Folder"))
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = world
	local function addBox(name: string, zone: string, cframe: CFrame, size: Vector3)
		local box = Instance.new("Part")
		box.Name = name
		box.CFrame = cframe
		box.Size = size
		box:SetAttribute("Zone", zone)
		box.Parent = zones
	end
	addBox("Belly_Body", "Belly", CFrame.new(0, 40, 0), Vector3.new(20, 20, 20))
	addBox("Boots_Legs", "Boots", CFrame.new(100, 30, 0), Vector3.new(20, 20, 20))
	-- A turned box: its corner reaches past the straight one.
	addBox(
		"Nightcap_Cap",
		"Nightcap",
		CFrame.new(0, 100, 0) * CFrame.Angles(0, math.rad(45), 0),
		Vector3.new(10, 10, 10)
	)
	return world
end

describe("BodyBeams.bodyReader", function()
	it("says a point inside a Belly box is on his body", function()
		local isOnBody = BodyBeams.bodyReader(newZoneWorld())
		expect(isOnBody(Vector3.new(5, 42, -5))).toBe(true)
	end)

	it("says a point inside a Nightcap box is on his body", function()
		local isOnBody = BodyBeams.bodyReader(newZoneWorld())
		expect(isOnBody(Vector3.new(0, 100, 0))).toBe(true)
	end)

	it("says a point inside a Boots box is not on his body", function()
		local isOnBody = BodyBeams.bodyReader(newZoneWorld())
		expect(isOnBody(Vector3.new(100, 30, 0))).toBe(false)
	end)

	it("says a point in no box (the meadow) is not on his body", function()
		local isOnBody = BodyBeams.bodyReader(newZoneWorld())
		expect(isOnBody(Vector3.new(300, 1, 300))).toBe(false)
	end)

	it("uses the box's turn", function()
		local isOnBody = BodyBeams.bodyReader(newZoneWorld())
		-- Turned 45 degrees, the 10-stud box reaches 7 studs along X; the straight one would stop at 5.
		expect(isOnBody(Vector3.new(6.5, 100, 0))).toBe(true)
		expect(isOnBody(Vector3.new(6.5, 100, 6.5))).toBe(false)
	end)

	it("answers nil (unknown) when the world has no zone boxes", function()
		local isOnBody = BodyBeams.bodyReader(made(Instance.new("Folder")))
		expect(isOnBody(Vector3.new(0, 40, 0))).toBeNil()
	end)

	it("answers nil (unknown) when the zone boxes are not here yet, and the right answer once they arrive", function()
		local world = made(Instance.new("Folder"))
		local isOnBody = BodyBeams.bodyReader(world)
		expect(isOnBody(Vector3.new(0, 40, 0))).toBeNil()
		local zones = Instance.new("Folder")
		zones.Name = "Zones"
		zones.Parent = world
		expect(isOnBody(Vector3.new(0, 40, 0))).toBeNil()
		local box = Instance.new("Part")
		box.CFrame = CFrame.new(0, 40, 0)
		box.Size = Vector3.new(20, 20, 20)
		box:SetAttribute("Zone", "Belly")
		box.Parent = zones
		expect(isOnBody(Vector3.new(0, 40, 0))).toBe(true)
	end)
end)

type Rig = {
	root: Folder,
	step: any,
	view: { camera: CFrame? },
	addEgg: (spotName: string, position: Vector3, withBeam: boolean) -> (Model, Beam?),
	addBeam: (egg: Model, enabled: boolean?) -> Beam,
	advance: () -> (),
	stop: () -> (),
}

-- Stand-in for the zone check: eggs from y = 40 up are "on his body" (the belly is y 40 to 70, the boots y 30 and the
-- meadow y 0 in these tests).
local function onBodyByHeight(position: Vector3): boolean?
	return position.Y >= 40
end

-- Starts BodyBeams on fake egg spots, a fake camera and a fake frame signal.
local function newRig(isOnBody: (Vector3) -> boolean?): Rig
	local root = made(Instance.new("Folder"))
	local step = newSignal()
	local view: { camera: CFrame? } = { camera = CFrame.new(0, 0, 0) }
	local beamsOn = BodyBeams.start({
		root = root,
		isOnBody = isOnBody,
		camera = function()
			return view.camera
		end,
		step = step,
	})
	table.insert(stops, beamsOn.stop)

	local function addBeam(egg: Model, enabled: boolean?): Beam
		local body = egg:FindFirstChild("Body") :: BasePart
		local bottom = Instance.new("Attachment")
		bottom.Name = "BeamBottom"
		bottom.Parent = body
		local top = Instance.new("Attachment")
		top.Name = "BeamTop"
		top.Parent = body
		local beam = Instance.new("Beam")
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.Enabled = enabled ~= false
		beam.Parent = body
		task.wait()
		return beam
	end

	return {
		root = root,
		step = step,
		view = view,
		addEgg = function(spotName: string, position: Vector3, withBeam: boolean): (Model, Beam?)
			local spot = made(Instance.new("Model"))
			spot.Name = spotName
			spot.Parent = root
			local egg = Instance.new("Model")
			egg.Name = "Egg"
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Anchored = true
			body.Position = position
			body.Parent = egg
			egg.PrimaryPart = body
			egg.Parent = spot
			task.wait()
			return egg, if withBeam then addBeam(egg, true) else nil
		end,
		addBeam = addBeam,
		advance = function()
			step:Fire()
		end,
		stop = beamsOn.stop,
	}
end

-- The camera sits `studs` studs east of the point.
local function cameraAway(point: Vector3, studs: number): CFrame
	return CFrame.new(point + Vector3.new(studs, 0, 0))
end

local BELLY = Vector3.new(0, 50, 0)
local BOOT = Vector3.new(0, 30, 0)
local MEADOW = Vector3.new(0, 0, 0)

describe("BodyBeams.start", function()
	it("turns off the beam of a Rare on the belly with the camera 20 studs away", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
	end)

	it("leaves the beam of a belly egg on with the camera 40 studs away", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = cameraAway(BELLY, 40)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("leaves the beam of a boot egg on with the camera 20 studs away", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Uncommon_1", BOOT, true)
		rig.view.camera = cameraAway(BOOT, 20)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("leaves the beam of a meadow egg on with the camera 20 studs away", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Common_1", MEADOW, true)
		rig.view.camera = cameraAway(MEADOW, 20)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("keeps a hidden beam hidden between 30 and 35 studs, and shows it beyond 35", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		rig.view.camera = cameraAway(BELLY, 33)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
		rig.view.camera = cameraAway(BELLY, 36)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("keeps a shown beam shown between 30 and 35 studs on the way in, and hides it within 30", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = cameraAway(BELLY, 40)
		rig.advance()
		rig.view.camera = cameraAway(BELLY, 33)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
		rig.view.camera = cameraAway(BELLY, 29)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
	end)

	it("measures from the camera, not from anything else", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		-- 20 studs straight above the egg is still within 30.
		rig.view.camera = CFrame.new(BELLY + Vector3.new(0, 20, 0))
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
	end)

	it("hides each egg by its own distance", function()
		local rig = newRig(onBodyByHeight)
		local near = Vector3.new(0, 45, 0)
		local far = Vector3.new(100, 45, 0)
		local _, nearBeam = rig.addEgg("Rare_1", near, true)
		local _, farBeam = rig.addEgg("Rare_2", far, true)
		rig.view.camera = cameraAway(near, 10)
		rig.advance()
		expect((nearBeam :: Beam).Enabled).toBe(false)
		expect((farBeam :: Beam).Enabled).toBe(true)
	end)

	it("turns off every beam of an egg that has two", function()
		local rig = newRig(onBodyByHeight)
		local egg, first = rig.addEgg("Rare_1", BELLY, true)
		local second = rig.addBeam(egg, true)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		expect((first :: Beam).Enabled).toBe(false)
		expect(second.Enabled).toBe(false)
	end)

	it("gives an egg that streams in late the right state at once", function()
		local rig = newRig(onBodyByHeight)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
	end)

	it("hides a beam that streams in late into an egg that is already hidden", function()
		local rig = newRig(onBodyByHeight)
		local egg = rig.addEgg("Rare_1", BELLY, false)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		local beam = rig.addBeam(egg, true)
		expect(beam.Enabled).toBe(false)
	end)

	it("tracks an egg put on a spot that was added after the start", function()
		local rig = newRig(onBodyByHeight)
		rig.view.camera = cameraAway(BELLY, 20)
		local _, beam = rig.addEgg("Rare_4", BELLY, true)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
	end)

	it("puts the beam back to on when the egg is not on his body after all", function()
		local onBody = true
		local rig = newRig(function(_position: Vector3): boolean?
			return onBody
		end)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(false)
		onBody = false
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("changes nothing while it does not know where the egg is", function()
		local rig = newRig(function(_position: Vector3): boolean?
			return nil
		end)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("changes nothing without a camera", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.view.camera = nil
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
	end)

	it("does not fail on an egg with no beam", function()
		local rig = newRig(onBodyByHeight)
		rig.addEgg("Common_1", BELLY, false)
		rig.view.camera = cameraAway(BELLY, 20)
		expect(function()
			rig.advance()
		end).never.toThrow()
	end)

	it("puts every beam back to its own value on stop", function()
		local rig = newRig(onBodyByHeight)
		local _, hiddenOne = rig.addEgg("Rare_1", BELLY, true)
		local _, hiddenTwo = rig.addEgg("Rare_2", Vector3.new(40, 45, 0), true)
		-- Between the two eggs, about 20 studs from each.
		rig.view.camera = CFrame.new(20, 47, 0)
		rig.advance()
		expect((hiddenOne :: Beam).Enabled).toBe(false)
		expect((hiddenTwo :: Beam).Enabled).toBe(false)
		rig.stop()
		expect((hiddenOne :: Beam).Enabled).toBe(true)
		expect((hiddenTwo :: Beam).Enabled).toBe(true)
	end)

	it("puts a beam that was off on its own back to off on stop", function()
		local rig = newRig(onBodyByHeight)
		local egg = rig.addEgg("Rare_1", BELLY, false)
		local beam = rig.addBeam(egg, false)
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		rig.view.camera = cameraAway(BELLY, 40)
		rig.advance()
		expect(beam.Enabled).toBe(false)
		rig.stop()
		expect(beam.Enabled).toBe(false)
	end)

	it("does nothing after stop, and a second stop is harmless", function()
		local rig = newRig(onBodyByHeight)
		local _, beam = rig.addEgg("Rare_1", BELLY, true)
		rig.stop()
		rig.view.camera = cameraAway(BELLY, 20)
		rig.advance()
		expect((beam :: Beam).Enabled).toBe(true)
		expect(function()
			rig.stop()
		end).never.toThrow()
		expect(rig.step:count()).toBe(0)
	end)

	it("lets go of the frame signal on stop", function()
		local rig = newRig(onBodyByHeight)
		expect(rig.step:count()).toBe(1)
		rig.stop()
		expect(rig.step:count()).toBe(0)
	end)
end)
