--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Helpers = require(script.Parent.Helpers)
local addPlayer = Helpers.addPlayer
local cleanUp = Helpers.cleanUp
local meter = Helpers.meter
local newHarness = Helpers.newHarness

afterEach(cleanUp)

-- A brand-new player carrying a Rare, with the real PlayerTracker feeding the director. The test sets by hand whether
-- the body is on the ground, how fast it goes up or down, and the take-offs the next tick reports.
type Scene = {
	character: Model,
	harness: Helpers.Harness,
	tracker: PlayerTracker.Tracker,
	setGrounded: (grounded: boolean) -> (),
	setSpeed: (studsPerSecond: number) -> (),
	setTakeoffs: (positions: { Vector3 }) -> (),
	-- One tick: the body is at (x, y), the tracker reads it, the director steps on it.
	tickAt: (x: number, y: number?) -> (),
}

local function newScene(): Scene
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = character

	local bellyBox: Zones.ZoneBox = { zone = "Belly", cframe = CFrame.new(0, 0, 0), size = Vector3.new(500, 500, 500) }
	local time = 0
	local grounded = true
	local speed = 0
	local pendingTakeoffs: { Vector3 } = {}
	local tracker = PlayerTracker.new({
		getPlayers = function()
			return { { UserId = 1, Character = character } }
		end,
		zoneBoxes = { bellyBox },
		gardens = {},
		isGrounded = function(_character: Model): boolean
			return grounded
		end,
		takeoffs = function(_character: Model): { Vector3 }
			local handedOut = pendingTakeoffs
			pendingTakeoffs = {}
			return handedOut
		end,
		now = function()
			return time
		end,
	})

	local harness = newHarness(0)
	addPlayer(harness, 1, "Mia", { carrying = "Rare" })

	local tickNumber = 0
	return {
		character = character,
		harness = harness,
		tracker = tracker,
		setGrounded = function(value: boolean)
			grounded = value
		end,
		setSpeed = function(value: number)
			speed = value
		end,
		setTakeoffs = function(positions: { Vector3 })
			pendingTakeoffs = positions
		end,
		tickAt = function(x: number, y: number?)
			tickNumber += 1
			time = tickNumber * 0.1
			root.Position = Vector3.new(x, y or 5, 0)
			root.AssemblyLinearVelocity = Vector3.new(0, speed, 0)
			harness.samples = tracker:tick()
			harness.director:step()
		end,
	}
end

describe("GiantDirector with a stuck carrier shaking in a gap", function()
	-- The whole session, with the real PlayerTracker feeding the director: a brand-new player carrying a Rare walks
	-- onto the belly, stops in a 1.6-stud gap, shakes while pressing, is held after the rescue, lets go and walks on.
	-- The Held flag is set on the player's info by hand (the rescue itself is Recovery's, tested on its own).
	it("the meter never rises while they shake in the gap and are held, and rises again once they walk on", function()
		local scene = newScene()
		local harness, tickAt = scene.harness, scene.tickAt

		for step = 0, 10 do
			tickAt(step) -- a walk, a stud a tick, onto the belly
		end
		local atTheStop = meter(harness)
		expect(atTheStop).toBeGreaterThan(0) -- the guard: this rig does make walking noise

		-- From the stop to the let-go the meter must never go up.
		local previous = atTheStop
		local rises = 0
		local function quietTick(x: number)
			tickAt(x)
			local now = meter(harness)
			if now > previous then
				rises += 1
			end
			previous = now
		end
		for _ = 1, 20 do
			quietTick(10) -- stands still for 2 seconds in the gap
		end
		local line = { 0.8, 1.6, 0.8, 0 } -- one point a tick through the gap, while pressing
		for shake = 1, 30 do
			quietTick(10 + line[(shake - 1) % 4 + 1])
		end
		harness.infos[1].held = true -- rescued: stands still, still pressing
		for _ = 1, 10 do
			quietTick(10)
		end
		harness.infos[1].held = false -- lets go

		expect(rises).toBe(0)

		local atLetGo = meter(harness)
		for step = 1, 10 do
			tickAt(10 + step) -- walks on
		end
		expect(meter(harness)).toBeGreaterThan(atLetGo)

		scene.character:Destroy()
	end)

	it("the rescue's drop onto the safe spot never raises the meter, and walking on still does", function()
		local scene = newScene()
		local harness, tickAt = scene.harness, scene.tickAt

		for step = 0, 10 do
			tickAt(step) -- a walk, a stud a tick, onto the belly
		end
		local atTheStop = meter(harness)
		expect(atTheStop).toBeGreaterThan(0) -- the guard: this rig does make walking noise

		-- From the stop to the let-go the meter must never go up.
		local previous = atTheStop
		local rises = 0
		local function quietTick(x: number, y: number?)
			tickAt(x, y)
			local now = meter(harness)
			if now > previous then
				rises += 1
			end
			previous = now
		end
		for _ = 1, 30 do
			quietTick(10) -- stands still for 3 seconds
		end

		harness.infos[1].held = true -- rescued
		scene.tracker:moved(1)
		local dropHeights = { 5.5, 5.33, 5.17, 5.0 }
		for index, height in dropHeights do
			scene.setGrounded(false)
			scene.setSpeed(-12) -- over the fast-fall limit, as a device's late physics can report
			if index == 1 then
				scene.setTakeoffs({ Vector3.new(10, 5, 0) }) -- a late Jumping state
			end
			quietTick(19.8, height)
		end
		scene.setGrounded(true)
		scene.setSpeed(0)
		quietTick(10, 5) -- the device's old position arrives once more
		for _ = 1, 10 do
			quietTick(19.8, 5) -- held, still pressing
		end
		harness.infos[1].held = false -- lets go

		expect(rises).toBe(0)

		local atLetGo = meter(harness)
		for step = 1, 10 do
			tickAt(19.8 + step) -- walks on
		end
		expect(meter(harness)).toBeGreaterThan(atLetGo)

		scene.character:Destroy()
	end)
end)
