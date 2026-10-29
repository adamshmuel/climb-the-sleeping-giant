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

describe("GiantDirector with a stuck carrier shaking in a gap", function()
	-- The whole session, with the real PlayerTracker feeding the director: a brand-new player carrying a Rare walks
	-- onto the belly, stops in a 1.6-stud gap, shakes while pressing, is held after the rescue, lets go and walks on.
	-- The Held flag is set on the player's info by hand (the rescue itself is Recovery's, tested on its own).
	it("the meter never rises while they shake in the gap and are held, and rises again once they walk on", function()
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(0, 5, 0)
		root.Parent = character

		local bellyBox: Zones.ZoneBox =
			{ zone = "Belly", cframe = CFrame.new(0, 0, 0), size = Vector3.new(500, 500, 500) }
		local time = 0
		local tracker = PlayerTracker.new({
			getPlayers = function()
				return { { UserId = 1, Character = character } }
			end,
			zoneBoxes = { bellyBox },
			gardens = {},
			isGrounded = function(_character: Model): boolean
				return true
			end,
			takeoffs = function(_character: Model): { Vector3 }
				return {}
			end,
			now = function()
				return time
			end,
		})

		local harness = newHarness(0)
		addPlayer(harness, 1, "Mia", { carrying = "Rare" })

		-- One tick: the body is at x, the tracker reads it, the director steps on it.
		local tickNumber = 0
		local function tickAt(x: number)
			tickNumber += 1
			time = tickNumber * 0.1
			root.Position = Vector3.new(x, 5, 0)
			harness.samples = tracker:tick()
			harness.director:step()
		end

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

		character:Destroy()
	end)
end)
