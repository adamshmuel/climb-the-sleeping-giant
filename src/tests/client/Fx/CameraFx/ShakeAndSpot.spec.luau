--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)

describe("CameraFx.whenSpotIsThere", function()
	local FRAME = 1 / 60
	local madeInstances: { Instance } = {}

	afterEach(function()
		for _, instance in madeInstances do
			instance:Destroy()
		end
		table.clear(madeInstances)
	end)

	-- A spawn spot as the world has it: 6 x 1 x 6, so its top is half a stud above its middle.
	local function newSpot(): Part
		local spot = Instance.new("Part")
		spot.Size = Vector3.new(6, 1, 6)
		spot.Position = Vector3.new(10, 5, -20)
		table.insert(madeInstances, spot)
		return spot
	end

	-- Fake frames and a fake clock: nothing carries on until the test says so.
	local function newRig()
		local rig: any = { clock = 100, waiting = {} :: { thread }, found = {} :: { Vector3 }, spot = nil :: Part? }
		function rig.frame(seconds: number)
			rig.clock += seconds
			local list = rig.waiting
			rig.waiting = {}
			for _, parked in list do
				task.spawn(parked)
			end
		end
		function rig.start()
			return CameraFx.whenSpotIsThere(function()
				return rig.spot
			end, function(top: Vector3)
				table.insert(rig.found, top)
			end, function()
				table.insert(rig.waiting, coroutine.running())
				coroutine.yield()
			end, function()
				return rig.clock
			end)
		end
		return rig
	end

	it("gives the top centre of the spot at once when it is there", function()
		local rig = newRig()
		rig.spot = newSpot()
		rig.start()
		expect(#rig.found).toBe(1)
		expect(rig.found[1]).toBe(Vector3.new(10, 5.5, -20))
		expect(#rig.waiting).toBe(0)
	end)

	it("waits for a spot that is not there yet, and gives it when it streams in", function()
		local rig = newRig()
		rig.start()
		rig.frame(0.5)
		expect(#rig.found).toBe(0)
		rig.spot = newSpot()
		rig.frame(FRAME)
		expect(#rig.found).toBe(1)
		expect(rig.found[1]).toBe(Vector3.new(10, 5.5, -20))
		rig.frame(1)
		expect(#rig.found).toBe(1)
		expect(#rig.waiting).toBe(0)
	end)

	it("gives up after 2 seconds, with nothing left waiting", function()
		local rig = newRig()
		rig.start()
		rig.frame(1.9)
		expect(#rig.waiting).toBe(1)
		rig.frame(0.2)
		expect(#rig.waiting).toBe(0)
		rig.spot = newSpot()
		rig.frame(1)
		expect(#rig.found).toBe(0)
	end)

	it("still gives a spot that streams in at 1.9 seconds", function()
		local rig = newRig()
		rig.start()
		rig.frame(1.9)
		rig.spot = newSpot()
		rig.frame(FRAME)
		expect(#rig.found).toBe(1)
	end)

	it("gives nothing after it is cancelled", function()
		local rig = newRig()
		local cancel = rig.start()
		rig.frame(0.5)
		cancel()
		rig.spot = newSpot()
		rig.frame(FRAME)
		expect(#rig.found).toBe(0)
		expect(#rig.waiting).toBe(0)
	end)

	it("can be cancelled twice, and after it has finished", function()
		local rig = newRig()
		rig.spot = newSpot()
		local cancel = rig.start()
		cancel()
		cancel()
		expect(#rig.found).toBe(1)
	end)

	it("says the wait is 2 seconds", function()
		expect(CameraFx.caughtWaitSeconds).toBe(2)
	end)
end)

describe("CameraFx.shakeOffset", function()
	local STEP = 0.005

	-- The offset at every STEP seconds from `from` to `to`, with the time it was taken at.
	local function samples(from: number, to: number): { { seconds: number, offset: Vector3 } }
		local found = {}
		local count = math.floor((to - from) / STEP + 0.5)
		for index = 0, count do
			local seconds = from + index * STEP
			table.insert(found, { seconds = seconds, offset = CameraFx.shakeOffset(seconds) })
		end
		return found
	end

	it("never moves the camera more than 0.5 studs, from -0.1 s to 0.7 s", function()
		for _, sample in samples(-0.1, 0.7) do
			expect(sample.offset.Magnitude <= Config.Wake.ShakeStuds + 1e-9).toBe(true)
		end
	end)

	it("is exactly zero before the start", function()
		expect(CameraFx.shakeOffset(-0.1)).toBe(Vector3.zero)
		expect(CameraFx.shakeOffset(-0.001)).toBe(Vector3.zero)
	end)

	it("is exactly zero from 0.5 seconds on", function()
		expect(Config.Wake.ShakeSeconds).toBe(0.5)
		expect(CameraFx.shakeOffset(0.5)).toBe(Vector3.zero)
		expect(CameraFx.shakeOffset(0.6)).toBe(Vector3.zero)
		expect(CameraFx.shakeOffset(30)).toBe(Vector3.zero)
	end)

	it("really shakes: it is above 0.3 studs somewhere in the first 0.1 seconds", function()
		local biggest = 0
		for _, sample in samples(0, 0.1) do
			biggest = math.max(biggest, sample.offset.Magnitude)
		end
		expect(biggest > 0.3).toBe(true)
	end)

	it("fades out: it never goes above what is left of the 0.5 studs", function()
		for _, sample in samples(0, 0.495) do
			local left = Config.Wake.ShakeStuds * (1 - sample.seconds / Config.Wake.ShakeSeconds)
			expect(sample.offset.Magnitude <= left + 1e-9).toBe(true)
		end
	end)

	it("moves only sideways and up and down, never forward or back", function()
		for _, sample in samples(0, 0.5) do
			expect(sample.offset.Z).toBe(0)
		end
	end)

	it("moves both ways, left and right and up and down", function()
		local sawLeft, sawRight, sawUp, sawDown = false, false, false, false
		for _, sample in samples(0, 0.3) do
			sawLeft = sawLeft or sample.offset.X < -0.05
			sawRight = sawRight or sample.offset.X > 0.05
			sawUp = sawUp or sample.offset.Y > 0.05
			sawDown = sawDown or sample.offset.Y < -0.05
		end
		expect(sawLeft and sawRight and sawUp and sawDown).toBe(true)
	end)
end)

describe("CameraFx.shakeOnWake", function()
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

	local function newSignal()
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

	local function newCharacter(offset: Vector3): (Model, Humanoid)
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.CameraOffset = offset
		humanoid.Parent = character
		table.insert(madeInstances, character)
		return character, humanoid
	end

	-- A giant's state folder, a player with a character, the frame step and a clock the test moves by hand.
	local SAVED = Vector3.new(0, 1, 0)
	local function newRig(startPhase: string?, withCharacter: boolean?)
		local state = Instance.new("Folder")
		state:SetAttribute("Phase", startPhase or "Asleep")
		table.insert(madeInstances, state)
		local character, humanoid = newCharacter(SAVED)
		local characterAdded = newSignal()
		local player = {
			Character = if withCharacter == false then nil else character,
			CharacterAdded = characterAdded,
		}
		local step = newSignal()
		local clock = 50
		local handle = CameraFx.shakeOnWake({
			giantState = state,
			player = player :: any,
			step = step,
			now = function()
				return clock
			end,
		})
		table.insert(stops, handle.stop)
		return {
			state = state,
			humanoid = humanoid,
			player = player,
			characterAdded = characterAdded,
			step = step,
			handle = handle,
			setPhase = function(phase: string)
				state:SetAttribute("Phase", phase)
				task.wait() -- attribute changes reach listeners a moment after they are set
			end,
			advance = function(seconds: number)
				clock += seconds
				step:Fire(seconds)
			end,
		}
	end

	local function near(first: Vector3, second: Vector3): boolean
		return (first - second).Magnitude < 1e-4
	end

	it("does nothing until he wakes", function()
		local rig = newRig()
		rig.advance(0.1)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("sets the camera offset to the saved offset plus the shake while it shakes", function()
		local rig = newRig()
		rig.setPhase("Awake")
		rig.advance(0.01)
		expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.shakeOffset(0.01))).toBe(true)
		rig.advance(0.09)
		expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.shakeOffset(0.1))).toBe(true)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
	end)

	it("never moves the camera offset more than 0.5 studs from the saved one", function()
		local rig = newRig()
		rig.setPhase("Awake")
		for _ = 1, 60 do
			rig.advance(0.01)
			expect((rig.humanoid.CameraOffset - SAVED).Magnitude <= Config.Wake.ShakeStuds + 1e-4).toBe(true)
		end
	end)

	it("puts the saved offset back exactly at 0.5 seconds and lets go of the step", function()
		local rig = newRig()
		rig.setPhase("Awake")
		rig.advance(0.25)
		expect(rig.step:count()).toBe(1)
		rig.advance(0.25)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("takes 0.5 seconds of the clock, however many frames that is", function()
		local rig = newRig()
		rig.setPhase("Awake")
		-- 1/16 of a second is exact in binary, so eight frames are exactly 0.5 seconds.
		for _ = 1, 7 do
			rig.advance(0.0625)
		end
		expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
		rig.advance(0.0625)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
	end)

	it("does not shake when he is already awake at the start", function()
		local rig = newRig("Awake")
		rig.advance(0.1)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("does not shake for Heavy Sleep", function()
		local rig = newRig()
		rig.setPhase("HeavySleep")
		rig.advance(0.1)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("puts the offset back and lets go of the step when stopped in the middle of the shake", function()
		local rig = newRig()
		rig.setPhase("Awake")
		rig.advance(0.1)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(false)
		rig.handle.stop()
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
		rig.advance(0.1)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
	end)

	it("shakes nothing after it is stopped", function()
		local rig = newRig()
		rig.handle.stop()
		rig.setPhase("Awake")
		rig.advance(0.1)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("can be stopped twice", function()
		local rig = newRig()
		rig.handle.stop()
		rig.handle.stop()
		expect(rig.step:count()).toBe(0)
	end)

	it("ends the shake and puts the offset back when a new character arrives", function()
		local rig = newRig()
		rig.setPhase("Awake")
		rig.advance(0.1)
		local _, newHumanoid = newCharacter(Vector3.zero)
		rig.characterAdded:Fire(newHumanoid.Parent)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
		expect(rig.step:count()).toBe(0)
		rig.advance(0.1)
		expect(newHumanoid.CameraOffset == Vector3.zero).toBe(true)
	end)

	it("shakes the new character at the next wake-up", function()
		local rig = newRig()
		local newCharacterModel, newHumanoid = newCharacter(Vector3.zero)
		rig.player.Character = newCharacterModel
		rig.characterAdded:Fire(newCharacterModel)
		rig.setPhase("Awake")
		rig.advance(0.01)
		expect(near(newHumanoid.CameraOffset, CameraFx.shakeOffset(0.01))).toBe(true)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
	end)

	it("shakes again at the next wake-up, from the offset the humanoid has then", function()
		local rig = newRig()
		rig.setPhase("Awake")
		rig.advance(0.5)
		rig.setPhase("HeavySleep")
		rig.setPhase("Asleep")
		rig.setPhase("Awake")
		rig.advance(0.01)
		expect(near(rig.humanoid.CameraOffset, SAVED + CameraFx.shakeOffset(0.01))).toBe(true)
		rig.advance(0.49)
		expect(rig.humanoid.CameraOffset == SAVED).toBe(true)
	end)

	it("does not fail when the player has no character at the wake-up", function()
		local rig = newRig(nil, false)
		rig.setPhase("Awake")
		rig.advance(0.1)
		expect(rig.step:count()).toBe(0)
	end)

	it("does not fail when the character has no humanoid at the wake-up", function()
		local rig = newRig()
		rig.humanoid.Parent = nil
		rig.setPhase("Awake")
		rig.advance(0.1)
		expect(rig.step:count()).toBe(0)
	end)
end)
