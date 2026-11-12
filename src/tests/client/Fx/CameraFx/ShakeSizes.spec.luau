--!strict
-- Task 14: the wake shake (1.5 studs for 1 s) and the slam shake (up to 1 stud for 0.4 s, by distance). Spec Rule 65.
-- Frames use powers of two (1/256, 1/16, 0.125 ...) so the clock adds up exactly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)
local Helpers = require(script.Parent.Helpers)

local SAVED = Vector3.new(0, 1, 0)
local SAMPLE = 1 / 256
local WAKE_STUDS = Config.Wake.WakeShakeStuds
local WAKE_SECONDS = Config.Wake.WakeShakeSeconds
local SLAM_SECONDS = Config.Wake.SlamShakeSeconds
local LANDS_IN = 1.5 -- how long after the warning the slam lands, on the server clock

describe("CameraFx.shakeOffset (the wake shake)", function()
	it("is never more than 1.5 studs long, before, during and after", function()
		local t = -0.1
		while t <= 1.2 do
			expect(CameraFx.shakeOffset(t).Magnitude <= WAKE_STUDS + 1e-4).toBe(true)
			t += SAMPLE
		end
	end)

	it("reaches at least 1.2 studs at its biggest", function()
		local biggest = 0
		local t = 0
		while t < WAKE_SECONDS do
			biggest = math.max(biggest, CameraFx.shakeOffset(t).Magnitude)
			t += SAMPLE
		end
		expect(biggest >= 1.2).toBe(true)
	end)

	it("is exactly zero from 1.0 s on", function()
		expect(CameraFx.shakeOffset(WAKE_SECONDS) == Vector3.zero).toBe(true)
		expect(CameraFx.shakeOffset(WAKE_SECONDS + 0.5) == Vector3.zero).toBe(true)
	end)

	it("is not zero at 0.99 s", function()
		expect(CameraFx.shakeOffset(0.99) == Vector3.zero).toBe(false)
	end)
end)

describe("CameraFx.slamShakeStuds and slamShakeOffset", function()
	it("gives 1 stud within 15 studs, half at 37.5 and none from 60", function()
		expect(CameraFx.slamShakeStuds(0)).toBeCloseTo(1, 5)
		expect(CameraFx.slamShakeStuds(10)).toBeCloseTo(1, 5)
		expect(CameraFx.slamShakeStuds(15)).toBeCloseTo(1, 5)
		expect(CameraFx.slamShakeStuds(37.5)).toBeCloseTo(0.5, 5)
		expect(CameraFx.slamShakeStuds(60)).toBeCloseTo(0, 5)
		expect(CameraFx.slamShakeStuds(75)).toBeCloseTo(0, 5)
	end)

	it("never moves more than slamShakeStuds, at 10 and 37.5 studs", function()
		for _, distance in { 10, 37.5 } do
			local cap = CameraFx.slamShakeStuds(distance)
			local t = -0.1
			while t <= 0.5 do
				expect(CameraFx.slamShakeOffset(t, distance).Magnitude <= cap + 1e-4).toBe(true)
				t += SAMPLE
			end
		end
	end)

	it("is exactly zero from 0.4 s on", function()
		expect(CameraFx.slamShakeOffset(SLAM_SECONDS, 10) == Vector3.zero).toBe(true)
		expect(CameraFx.slamShakeOffset(SLAM_SECONDS + 0.5, 10) == Vector3.zero).toBe(true)
	end)

	it("reaches at least 0.8 studs at its biggest, 10 studs away", function()
		local biggest = 0
		local t = 0
		while t < SLAM_SECONDS do
			biggest = math.max(biggest, CameraFx.slamShakeOffset(t, 10).Magnitude)
			t += SAMPLE
		end
		expect(biggest >= 0.8).toBe(true)
	end)
end)

type Rig = {
	state: Folder,
	humanoid: Humanoid,
	step: any,
	warning: any,
	landed: any,
	handle: CameraFx.Shaker,
	flags: { reduced: boolean },
	sounds: { string },
	setPhase: (phase: string) -> (),
	advance: (seconds: number) -> (),
	warn: (number: number, point: Vector3, landsIn: number) -> (),
	slam: (number: number, point: Vector3) -> (), -- warning, then the landing at once
	biggestAfter: (seconds: number) -> number,
	offset: () -> Vector3,
	serverNow: () -> number,
}

type RigOptions = {
	startPhase: string?,
	character: string?, -- "root" (default), "rootFirst", "noRoot" or "none"
	rootAt: Vector3?,
	reduced: boolean?,
	noSound: boolean?,
	clockStart: number?,
}

describe("CameraFx.shakeOnWake, the sizes and the slam", function()
	local madeInstances: { Instance } = {}
	local stops: { () -> () } = {}

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

	-- Copies the real character: a Humanoid and a Part named HumanoidRootPart, no PrimaryPart, either order.
	local function newCharacter(options: RigOptions): (Model, Humanoid)
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.CameraOffset = SAVED
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = options.rootAt or Vector3.zero
		local kind = options.character or "root"
		if kind == "rootFirst" then
			root.Parent = character
		end
		humanoid.Parent = character
		if kind == "root" then
			root.Parent = character
		end
		if kind ~= "root" and kind ~= "rootFirst" then
			root:Destroy()
		end
		table.insert(madeInstances, character)
		return character, humanoid
	end

	local function newRig(options: RigOptions?): Rig
		local opts: RigOptions = options or {}
		local state = Instance.new("Folder")
		state:SetAttribute("Phase", opts.startPhase or "Asleep")
		table.insert(madeInstances, state)
		local character, humanoid = newCharacter(opts)
		local player = {
			Character = if opts.character == "none" then nil else character,
			CharacterAdded = Helpers.newSignal(),
		}
		local step = Helpers.newSignal()
		local warning = Helpers.newSignal()
		local landed = Helpers.newSignal()
		local flags = { reduced = opts.reduced == true }
		local sounds: { string } = {}
		local clock = opts.clockStart or 50
		local server = 1000
		local deps: CameraFx.ShakeDeps = {
			giantState = state,
			player = player :: any,
			step = step,
			now = function()
				return clock
			end,
			slamWarning = { OnClientEvent = warning :: any },
			slamLanded = { OnClientEvent = landed :: any },
			serverNow = function()
				return server
			end,
			reducedMotion = function()
				return flags.reduced
			end,
			playSound = if opts.noSound == true
				then nil
				else function(name: string)
					table.insert(sounds, name)
				end,
		}
		local handle = CameraFx.shakeOnWake(deps)
		table.insert(stops, handle.stop)
		local rig: Rig
		rig = {
			state = state,
			humanoid = humanoid,
			step = step,
			warning = warning,
			landed = landed,
			handle = handle,
			flags = flags,
			sounds = sounds,
			setPhase = function(phase: string)
				state:SetAttribute("Phase", phase)
				task.wait() -- attribute changes reach listeners a moment after they are set
			end,
			advance = function(seconds: number)
				clock += seconds
				server += seconds
				step:Fire(seconds)
			end,
			warn = function(number: number, point: Vector3, landsIn: number)
				warning:Fire(number, point, server + landsIn)
			end,
			slam = function(number: number, point: Vector3)
				warning:Fire(number, point, server + LANDS_IN)
				landed:Fire(number, point)
			end,
			biggestAfter = function(seconds: number): number
				local biggest = 0
				for _ = 1, math.round(seconds / SAMPLE) do
					rig.advance(SAMPLE)
					biggest = math.max(biggest, (humanoid.CameraOffset - SAVED).Magnitude)
				end
				return biggest
			end,
			offset = function(): Vector3
				return humanoid.CameraOffset - SAVED
			end,
			serverNow = function()
				return server
			end,
		}
		return rig
	end

	local function near(first: Vector3, second: Vector3): boolean
		return (first - second).Magnitude < 1e-4
	end

	local POINT_10 = Vector3.new(10, 0, 0) -- 10 studs from a root at the origin
	local POINT_20 = Vector3.new(0, 0, -20)

	describe("the landing", function()
		it("shakes on the frame after SlamLanded, even before landsAt", function()
			local rig = newRig()
			rig.warn(1, POINT_10, LANDS_IN)
			rig.advance(0.125)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			rig.landed:Fire(1, POINT_10)
			rig.advance(0.0625)
			expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.slamShakeOffset(0.0625, 10))).toBe(true)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
		end)

		it("shakes on the first frame with serverNow at or past landsAt when no SlamLanded comes", function()
			local rig = newRig()
			rig.warn(1, POINT_10, LANDS_IN)
			rig.advance(0.5)
			rig.advance(0.5)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			-- 1.5625 s after the warning: 0.0625 s past landsAt, so the shake is 0.0625 s old on this frame.
			rig.advance(0.5625)
			expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.slamShakeOffset(0.0625, 10))).toBe(true)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
		end)

		it("shakes once: landsAt passing after SlamLanded does not start a second shake", function()
			local rig = newRig()
			rig.warn(1, POINT_10, 0.25)
			rig.landed:Fire(1, POINT_10)
			rig.advance(0.125)
			expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.slamShakeOffset(0.125, 10))).toBe(true)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
			-- landsAt (0.25 s) passes here, 0.375 s into the one shake.
			rig.advance(0.25)
			expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.slamShakeOffset(0.375, 10))).toBe(true)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
		end)
	end)

	describe("the distance", function()
		it("counts across the ground only: 50 studs higher and 10 across still shakes full", function()
			-- Both child orders of the fake character (the real one comes in any order).
			for _, kind in { "root", "rootFirst" } do
				local rig = newRig({ rootAt = Vector3.new(0, 50, 0), character = kind })
				rig.slam(1, POINT_10)
				expect(rig.biggestAfter(0.5) >= 0.8).toBe(true)
			end
		end)

		it("falls off with the distance: about half at 37.5, nothing and no step at 60 and 75", function()
			local half = newRig()
			half.slam(1, Vector3.new(37.5, 0, 0))
			local halfBiggest = half.biggestAfter(0.5)
			expect(halfBiggest >= 0.4 and halfBiggest <= 0.5 + 1e-4).toBe(true)
			for _, far in { 60, 75 } do
				local rig = newRig()
				rig.slam(1, Vector3.new(far, 0, 0))
				expect(rig.step:count()).toBe(0)
				expect(rig.biggestAfter(0.5)).toBe(0)
				expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			end
		end)
	end)

	describe("a second slam", function()
		it("replaces the first one still shaking: the offset is the new shake alone", function()
			local rig = newRig()
			rig.slam(1, POINT_10)
			rig.advance(0.1875)
			rig.slam(2, POINT_20)
			rig.advance(0.0625)
			expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.slamShakeOffset(0.0625, 20))).toBe(true)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
		end)

		it("ends exactly 0.4 s after the second landing, on the saved offset", function()
			-- The clock reaches 0 exactly at the second landing, so 0.4 s later it reads exactly 0.4.
			local rig = newRig({ clockStart = -0.1875 })
			rig.slam(1, POINT_10)
			rig.advance(0.1875)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
			rig.slam(2, POINT_20)
			rig.advance(SLAM_SECONDS)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			expect(rig.step:count()).toBe(0)
		end)
	end)

	describe("what it ignores", function()
		it("does nothing with no character, or a character with no HumanoidRootPart", function()
			for _, kind in { "none", "noRoot" } do
				local rig = newRig({ character = kind })
				rig.slam(1, POINT_10)
				for _ = 1, 8 do
					rig.advance(0.0625)
					expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
				end
				expect(rig.step:count()).toBe(0)
			end
		end)

		it("ignores a bad point and a bad landsAt", function()
			local rig = newRig()
			rig.warning:Fire(1, "not a point", rig.serverNow() + 1)
			rig.warning:Fire(2, POINT_10, 0 / 0)
			rig.landed:Fire(1, "not a point")
			rig.landed:Fire(2, POINT_10)
			for _ = 1, 8 do
				rig.advance(0.5)
				expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			end
			expect(rig.step:count()).toBe(0)
		end)
	end)

	describe("stop", function()
		it("mid-shake puts the saved offset back and lets go of the step", function()
			local rig = newRig()
			rig.slam(1, POINT_10)
			rig.advance(0.125)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
			rig.handle.stop()
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			expect(rig.step:count()).toBe(0)
		end)

		it("makes a SlamLanded after it do nothing", function()
			local rig = newRig()
			rig.warn(1, POINT_10, LANDS_IN)
			rig.handle.stop()
			rig.landed:Fire(1, POINT_10)
			rig.advance(0.125)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			expect(rig.step:count()).toBe(0)
		end)
	end)

	describe("the step connection", function()
		it("exists between the warning and the end of the shake, and not after", function()
			local rig = newRig()
			expect(rig.step:count()).toBe(0)
			rig.warn(1, POINT_10, LANDS_IN)
			expect(rig.step:count()).toBe(1)
			rig.landed:Fire(1, POINT_10)
			rig.advance(0.125)
			expect(rig.step:count()).toBe(1)
			rig.advance(0.5)
			expect(rig.step:count()).toBe(0)
		end)

		it("is cleared of a pending slam by a new wake", function()
			local rig = newRig()
			rig.warn(1, POINT_10, LANDS_IN)
			expect(rig.step:count()).toBe(1)
			rig.setPhase("Awake")
			-- The wake ends within 1 s; the cleared slam would have landed at 1.5 s and shaken again.
			rig.advance(0.5)
			rig.advance(0.5)
			rig.advance(0.5)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			rig.advance(0.5)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			expect(rig.step:count()).toBe(0)
		end)
	end)

	describe("Reduce Motion", function()
		it("keeps the wake shake off: no offset in any frame and no step connection", function()
			local rig = newRig({ reduced = true })
			rig.setPhase("Awake")
			for _ = 1, 24 do
				rig.advance(0.0625)
				expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
				expect(rig.step:count()).toBe(0)
			end
		end)

		it("keeps the slam shake off: no offset in any frame and no step connection", function()
			local rig = newRig({ reduced = true })
			rig.slam(1, POINT_10)
			expect(rig.step:count()).toBe(0)
			for _ = 1, 8 do
				rig.advance(0.0625)
				expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
				expect(rig.step:count()).toBe(0)
			end
		end)

		it("is read at each shake start: off for one slam, on for the next", function()
			local rig = newRig()
			rig.slam(1, POINT_10)
			rig.advance(0.0625)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
			rig.advance(0.5)
			expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			rig.flags.reduced = true
			rig.slam(2, POINT_10)
			for _ = 1, 8 do
				rig.advance(0.0625)
				expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
			end
			expect(rig.step:count()).toBe(0)
		end)
	end)

	describe("the WakeRumble hook", function()
		it("plays once per wake, not for joining mid-wake and not for slams", function()
			local rig = newRig({ startPhase = "Awake" })
			expect(#rig.sounds).toBe(0)
			rig.setPhase("Asleep")
			rig.setPhase("Awake")
			expect(rig.sounds).toEqual({ "WakeRumble" })
			rig.slam(1, POINT_10)
			rig.advance(0.125)
			expect(#rig.sounds).toBe(1)
		end)

		it("plays once per wake with Reduce Motion on", function()
			local rig = newRig({ reduced = true })
			rig.setPhase("Awake")
			expect(rig.sounds).toEqual({ "WakeRumble" })
		end)

		it("plays once per wake with no character", function()
			local rig = newRig({ character = "none" })
			rig.setPhase("Awake")
			expect(rig.sounds).toEqual({ "WakeRumble" })
		end)

		it("does nothing wrong when there is no playSound", function()
			local rig = newRig({ noSound = true })
			rig.setPhase("Awake")
			rig.advance(0.0625)
			expect(rig.sounds).toEqual({})
		end)
	end)
end)
