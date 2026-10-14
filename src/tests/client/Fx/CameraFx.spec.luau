--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)

-- How far the view points above (positive) or below (negative) the horizon, in degrees.
local function pitchOf(cframe: CFrame): number
	return math.deg(math.asin(cframe.LookVector.Y))
end

-- Roblox's normal start: behind the player, 15 degrees looking down, 12.5 studs away.
local function defaultCamera(focus: Vector3): CFrame
	local look = (CFrame.Angles(0, math.rad(40), 0) * CFrame.Angles(math.rad(-15), 0, 0)).LookVector
	return CFrame.lookAt(focus - look * 12.5, focus)
end

describe("CameraFx.spawnView", function()
	local focus = Vector3.new(10, 6, -20)

	it("looks the way the character faces", function()
		local characterLook = Vector3.new(0.6, 0, 0.8)
		local view = CameraFx.spawnView(focus, characterLook, 12.5, 15)
		local flatLook = Vector3.new(view.LookVector.X, 0, view.LookVector.Z).Unit
		expect(flatLook:Dot(characterLook.Unit) > 0.9999).toBe(true)
	end)

	it("is 15 degrees up", function()
		local view = CameraFx.spawnView(focus, Vector3.new(0.6, 0, 0.8), 12.5, 15)
		expect(math.abs(pitchOf(view) - 15) < 0.5).toBe(true)
	end)

	it("keeps the given distance from the focus", function()
		local view = CameraFx.spawnView(focus, Vector3.new(0.6, 0, 0.8), 12.5, 15)
		expect(math.abs((view.Position - focus).Magnitude - 12.5) < 0.01).toBe(true)
	end)

	it("keeps looking at the focus", function()
		local view = CameraFx.spawnView(focus, Vector3.new(0.6, 0, 0.8), 12.5, 15)
		local toFocus = (focus - view.Position).Unit
		expect(view.LookVector:Dot(toFocus) > 0.9999).toBe(true)
	end)
end)

describe("CameraFx.placeCamera", function()
	it("puts a camera behind the character, 15 degrees up, at the distance it already had", function()
		local focus = Vector3.new(0, 5, 0)
		local camera = { CFrame = defaultCamera(focus), Focus = CFrame.new(focus) }
		local characterLook = Vector3.new(0.6, 0, 0.8)
		CameraFx.placeCamera(camera :: any, characterLook, 15)
		local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
		expect(flatLook:Dot(characterLook.Unit) > 0.9999).toBe(true)
		expect(math.abs(pitchOf(camera.CFrame) - 15) < 0.5).toBe(true)
		expect(math.abs((camera.CFrame.Position - focus).Magnitude - 12.5) < 0.01).toBe(true)
	end)
end)

describe("CameraFx.viewJumped", function()
	local before = Vector3.new(0, 0, -1)

	it("sees a sudden jump of the view in one frame", function()
		local after = (CFrame.Angles(math.rad(30), 0, 0) * CFrame.new(before)).Position
		expect(CameraFx.viewJumped(before, after)).toBe(true)
	end)

	it("does not mistake the player's own slow turn for a jump", function()
		local after = (CFrame.Angles(0, math.rad(3), 0) * CFrame.new(before)).Position
		expect(CameraFx.viewJumped(before, after)).toBe(false)
	end)
end)

describe("CameraFx.isSteady", function()
	it("is steady when the camera is on the player's head and has stopped moving in or out", function()
		expect(CameraFx.isSteady(12.5, 12.5, 0.2)).toBe(true)
		expect(CameraFx.isSteady(12.49, 12.5, 0.3)).toBe(true)
	end)

	it("is not steady while the camera is still zooming", function()
		expect(CameraFx.isSteady(10.8, 12.2, 0.2)).toBe(false)
	end)

	it("is not steady while the camera looks somewhere other than the player's head", function()
		expect(CameraFx.isSteady(12.5, 12.5, 40)).toBe(false)
	end)
end)

describe("CameraFx.newViewSetter", function()
	local focus = Vector3.new(0, 5, 0)
	local characterLook = Vector3.new(0.6, 0, 0.8)

	local function flatDot(cframe: CFrame, look: Vector3): number
		local flat = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z).Unit
		return flat:Dot(look.Unit)
	end

	local function fakeCamera(cameraType: Enum.CameraType)
		return { CFrame = defaultCamera(focus), Focus = CFrame.new(focus), CameraType = cameraType }
	end

	it("holds the camera Scriptable while the view is set for one frame, then gives it back as Custom", function()
		local camera = fakeCamera(Enum.CameraType.Custom)
		local typeDuringFrame: Enum.CameraType? = nil
		local facingDuringFrame = 0
		local setter = CameraFx.newViewSetter(function()
			typeDuringFrame = camera.CameraType
			facingDuringFrame = flatDot(camera.CFrame, characterLook)
		end)
		setter.apply(camera :: any, characterLook, 15)
		expect(typeDuringFrame).toBe(Enum.CameraType.Scriptable)
		expect(facingDuringFrame > 0.9999).toBe(true)
		expect(camera.CameraType).toBe(Enum.CameraType.Custom)
		expect(flatDot(camera.CFrame, characterLook) > 0.9999).toBe(true)
		expect(math.abs(pitchOf(camera.CFrame) - 15) < 0.5).toBe(true)
	end)

	it("gives the camera back as Custom when released in the middle of the frame", function()
		local camera = fakeCamera(Enum.CameraType.Custom)
		local setter = CameraFx.newViewSetter(function()
			coroutine.yield()
		end)
		local thread = coroutine.create(function()
			setter.apply(camera :: any, characterLook, 15)
		end)
		coroutine.resume(thread)
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		setter.release()
		expect(camera.CameraType).toBe(Enum.CameraType.Custom)
	end)

	it("does nothing when released while no frame is being waited for", function()
		local camera = fakeCamera(Enum.CameraType.Fixed)
		local setter = CameraFx.newViewSetter(function() end)
		setter.release()
		expect(camera.CameraType).toBe(Enum.CameraType.Fixed)
	end)

	it("sets the view directly and keeps the type when the camera is not on Custom", function()
		local camera = fakeCamera(Enum.CameraType.Scriptable)
		local waited = false
		local setter = CameraFx.newViewSetter(function()
			waited = true
		end)
		setter.apply(camera :: any, characterLook, 15)
		expect(waited).toBe(false)
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		expect(flatDot(camera.CFrame, characterLook) > 0.9999).toBe(true)
	end)
end)

describe("CameraFx.pitchOf", function()
	it("is the number of degrees a look points up, and negative when it points down", function()
		local up = CFrame.Angles(math.rad(21), 0, 0).LookVector
		local down = CFrame.Angles(math.rad(-15), 0, 0).LookVector
		expect(math.abs(CameraFx.pitchOf(up) - 21) < 0.01).toBe(true)
		expect(math.abs(CameraFx.pitchOf(down) - -15) < 0.01).toBe(true)
	end)

	it("does not depend on how long the look vector is", function()
		local look = CFrame.Angles(math.rad(21), 0, 0).LookVector * 7
		expect(math.abs(CameraFx.pitchOf(look) - 21) < 0.01).toBe(true)
	end)
end)

describe("CameraFx.hasTurned", function()
	local spawnLook = CFrame.Angles(math.rad(21), math.rad(30), 0).LookVector

	local function turnedBy(degrees: number): Vector3
		return (CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(spawnLook)).Position
	end

	it("is not turned when the look is the same, as when the player only zooms", function()
		expect(CameraFx.hasTurned(spawnLook, spawnLook)).toBe(false)
	end)

	it("is not turned by 1 degree", function()
		expect(CameraFx.hasTurned(spawnLook, turnedBy(1))).toBe(false)
	end)

	it("is turned by 3 degrees", function()
		expect(CameraFx.hasTurned(spawnLook, turnedBy(3))).toBe(true)
	end)

	it("is turned by 3 degrees up or down as well as sideways", function()
		local tilted = (CFrame.Angles(math.rad(3), 0, 0) * CFrame.lookAt(Vector3.zero, spawnLook)).LookVector
		expect(CameraFx.hasTurned(spawnLook, tilted)).toBe(true)
	end)
end)

describe("CameraFx.firstMove", function()
	it("waits while the player neither moves nor turns", function()
		expect(CameraFx.firstMove(false, false)).toBe("wait")
	end)

	it("eases back when the player moves without having turned the camera", function()
		expect(CameraFx.firstMove(true, false)).toBe("ease")
	end)

	it("stops for good when the player turned the camera, moving or not", function()
		expect(CameraFx.firstMove(false, true)).toBe("stop")
		expect(CameraFx.firstMove(true, true)).toBe("stop")
	end)
end)

describe("CameraFx.awayFromEgg", function()
	local DEGREES = 20
	local FROM = Vector3.new(5, 7, -3)

	-- The flat direction `degreesRight` to the right of `look` (negative is to the left). Roblox: a turn about +Y by a
	-- positive angle turns left, so a right turn is a negative angle.
	local function rotated(look: Vector3, degreesRight: number): Vector3
		return (CFrame.Angles(0, -math.rad(degreesRight), 0) * CFrame.new(look)).Position
	end

	-- An egg 30 studs away, `degreesRight` of the way `look` points (negative is left), `up` studs higher than FROM.
	local function eggAt(look: Vector3, degreesRight: number, up: number?): Vector3
		return FROM + rotated(Vector3.new(look.X, 0, look.Z).Unit, degreesRight) * 30 + Vector3.new(0, up or 0, 0)
	end

	-- Where `egg` sits when standing at FROM and looking along `newLook`: degrees to the right (negative is left).
	local function eggSide(newLook: Vector3, egg: Vector3): number
		local local_ = CFrame.lookAt(Vector3.zero, newLook)
			:PointToObjectSpace(Vector3.new(egg.X - FROM.X, 0, egg.Z - FROM.Z))
		return math.deg(math.atan2(local_.X, -local_.Z))
	end

	-- How far `newLook` is turned from `look`: degrees to the right (negative is left).
	local function turned(look: Vector3, newLook: Vector3): number
		return eggSide(newLook, FROM + look) * -1
	end

	local LOOKS = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0.6, 0, 0.8), Vector3.new(-0.3, 0, -0.9) }

	it("turns an egg 10 degrees to the right until it sits 20 degrees to the right (the look turns 10 left)", function()
		for _, look in LOOKS do
			local egg = eggAt(look, 10)
			local result = CameraFx.awayFromEgg(look, FROM, egg, DEGREES)
			expect(math.abs(eggSide(result, egg) - 20) < 0.01).toBe(true)
			expect(math.abs(turned(look, result) - -10) < 0.01).toBe(true)
		end
	end)

	it("turns an egg 14 degrees to the left until it sits 20 degrees to the left (the look turns 6 right)", function()
		for _, look in LOOKS do
			local egg = eggAt(look, -14)
			local result = CameraFx.awayFromEgg(look, FROM, egg, DEGREES)
			expect(math.abs(eggSide(result, egg) - -20) < 0.01).toBe(true)
			expect(math.abs(turned(look, result) - 6) < 0.01).toBe(true)
		end
	end)

	it("leaves an egg 25 degrees off alone, on either side", function()
		for _, side in { 25, -25 } do
			local look = Vector3.new(0.6, 0, 0.8)
			local result = CameraFx.awayFromEgg(look, FROM, eggAt(look, side), DEGREES)
			expect((result - look).Magnitude < 1e-6).toBe(true)
		end
	end)

	it("leaves an egg exactly 20 degrees off alone, on either side", function()
		for _, side in { 20, -20 } do
			local look = Vector3.new(0.6, 0, 0.8)
			local result = CameraFx.awayFromEgg(look, FROM, eggAt(look, side), DEGREES)
			expect((result - look).Magnitude < 1e-6).toBe(true)
		end
	end)

	it("puts an egg dead ahead 20 degrees to the left (the look turns 20 right)", function()
		for _, look in LOOKS do
			local egg = eggAt(look, 0)
			local result = CameraFx.awayFromEgg(look, FROM, egg, DEGREES)
			expect(math.abs(eggSide(result, egg) - -20) < 0.01).toBe(true)
			expect(math.abs(turned(look, result) - 20) < 0.01).toBe(true)
		end
	end)

	it("treats an egg within 0.01 degrees of dead ahead as dead ahead, even a hair to the right", function()
		local look = Vector3.new(0, 0, -1)
		local egg = eggAt(look, 0.005)
		local result = CameraFx.awayFromEgg(look, FROM, egg, DEGREES)
		expect(math.abs(eggSide(result, egg) - -20) < 0.01).toBe(true)
	end)

	it("keeps an egg just right of dead ahead (0.5 degrees) on the right", function()
		local look = Vector3.new(0, 0, -1)
		local egg = eggAt(look, 0.5)
		local result = CameraFx.awayFromEgg(look, FROM, egg, DEGREES)
		expect(math.abs(eggSide(result, egg) - 20) < 0.01).toBe(true)
	end)

	it("leaves an egg behind the player alone", function()
		local look = Vector3.new(0, 0, -1)
		local result = CameraFx.awayFromEgg(look, FROM, eggAt(look, 170), DEGREES)
		expect((result - look).Magnitude < 1e-6).toBe(true)
	end)

	it("uses the number of degrees it is given", function()
		local look = Vector3.new(0, 0, -1)
		local egg = eggAt(look, 10)
		local result = CameraFx.awayFromEgg(look, FROM, egg, 30)
		expect(math.abs(eggSide(result, egg) - 30) < 0.01).toBe(true)
	end)

	it("ignores differences in height: the egg's, the player's and the look's", function()
		local look = Vector3.new(0.6, 0, 0.8)
		local flatEgg = eggAt(look, 10)
		local expected = CameraFx.awayFromEgg(look, FROM, flatEgg, DEGREES)
		local tiltedLook = Vector3.new(0.6, -0.5, 0.8)
		for _, up in { -40, 25 } do
			local result = CameraFx.awayFromEgg(tiltedLook, FROM, eggAt(look, 10, up), DEGREES)
			expect((result - expected).Magnitude < 1e-6).toBe(true)
		end
	end)

	it("gives a flat look of length 1, also when the look it was given was tilted or long", function()
		local cases: { { look: Vector3, side: number } } = {
			{ look = Vector3.new(0.6, -0.5, 0.8), side = 10 },
			{ look = Vector3.new(0, 0, -7), side = 0 },
			{ look = Vector3.new(3, 2, 0), side = -25 },
			{ look = Vector3.new(1, 0, 1), side = 12 },
		}
		for _, case in cases do
			local result = CameraFx.awayFromEgg(case.look, FROM, eggAt(case.look, case.side), DEGREES)
			expect(result.Y).toBe(0)
			expect(math.abs(result.Magnitude - 1) < 1e-6).toBe(true)
		end
	end)

	it("changes nothing for an egg at the player's own place (no direction to turn from)", function()
		local look = Vector3.new(0.6, 0, 0.8)
		local result = CameraFx.awayFromEgg(look, FROM, FROM + Vector3.new(0, 4, 0), DEGREES)
		expect((result - look).Magnitude < 1e-6).toBe(true)
	end)
end)

describe("CameraFx.withPitch", function()
	local focus = Vector3.new(10, 6, -20)
	-- A camera 14.5 studs from its focus, looking 8 degrees down, turned to a yaw of 50 degrees.
	local current = CameraFx.spawnView(focus, Vector3.new(0.6, 0, 0.8), 14.5, -8)

	local function flatLook(view: CFrame): Vector3
		return Vector3.new(view.LookVector.X, 0, view.LookVector.Z).Unit
	end

	it("sets the given pitch", function()
		for _, pitch in { 21, 3, -15 } do
			local view = CameraFx.withPitch(current, focus, pitch)
			expect(math.abs(CameraFx.pitchOf(view.LookVector) - pitch) < 0.01).toBe(true)
		end
	end)

	it("keeps the left-right direction and the distance from the focus", function()
		local view = CameraFx.withPitch(current, focus, 21)
		expect(flatLook(view):Dot(flatLook(current)) > 0.99999).toBe(true)
		expect(math.abs((view.Position - focus).Magnitude - 14.5) < 0.001).toBe(true)
	end)

	it("keeps looking at the focus", function()
		local view = CameraFx.withPitch(current, focus, -15)
		expect((focus - view.Position).Unit:Dot(view.LookVector) > 0.99999).toBe(true)
	end)
end)

describe("CameraFx.renderBinder", function()
	-- A stand-in for RunService that records what it is asked.
	local function fakeRunService()
		local record = {
			binds = {} :: { { name: string, priority: number, callback: (number) -> () } },
			unbinds = {} :: { string },
		}
		local service = {
			BindToRenderStep = function(_self: any, name: string, priority: number, callback: (number) -> ())
				table.insert(record.binds, { name = name, priority = priority, callback = callback })
			end,
			UnbindFromRenderStep = function(_self: any, name: string)
				table.insert(record.unbinds, name)
			end,
		}
		return service, record
	end

	it("binds the step by name, right after Roblox's camera", function()
		local service, record = fakeRunService()
		local ran = 0
		CameraFx.renderBinder(service :: any)(function()
			ran += 1
		end)
		expect(#record.binds).toBe(1)
		expect(record.binds[1].name).toBe("CameraFxEaseBack")
		expect(record.binds[1].priority).toBe(Enum.RenderPriority.Camera.Value + 1)
		-- The bound function runs the step.
		record.binds[1].callback(1 / 60)
		expect(ran).toBe(1)
	end)

	it("binds and unbinds under another name when it is given one", function()
		local service, record = fakeRunService()
		local unbind = CameraFx.renderBinder(service :: any, "SomeOtherName")(function() end)
		expect(record.binds[1].name).toBe("SomeOtherName")
		unbind()
		expect(record.unbinds).toEqual({ "SomeOtherName" })
	end)

	it("gives back a function that unbinds that name", function()
		local service, record = fakeRunService()
		local unbind = CameraFx.renderBinder(service :: any)(function() end)
		expect(#record.unbinds).toBe(0)
		unbind()
		expect(record.unbinds).toEqual({ "CameraFxEaseBack" })
	end)
end)

describe("CameraFx.newEaseBack", function()
	local focus = Vector3.new(0, 5, 0)
	local characterLook = Vector3.new(0.6, 0, 0.8)
	local FRAME = 1 / 60

	local function flatLook(cframe: CFrame): Vector3
		return Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z).Unit
	end

	-- A camera at the spawn view (21 degrees up, 12.5 studs from its focus), on the given camera type.
	local function fakeCamera(cameraType: Enum.CameraType)
		return {
			CFrame = CameraFx.spawnView(focus, characterLook, 12.5, 21),
			Focus = CFrame.new(focus),
			CameraType = cameraType,
		}
	end

	-- Everything an ease needs, faked: a clock that only moves when `frame` is called, a binder that keeps the bound
	-- step so the test can call it frame by frame, and a turning switch.
	local function newRig(cameraType: Enum.CameraType?)
		local rig = {
			camera = fakeCamera(cameraType or Enum.CameraType.Custom),
			clock = 100,
			turning = false,
			binds = 0,
			unbinds = 0,
			active = 0,
			mostActive = 0,
			step = nil :: (() -> ())?,
			everBound = nil :: (() -> ())?,
		}
		local function bind(step: () -> ()): () -> ()
			rig.binds += 1
			rig.active += 1
			rig.mostActive = math.max(rig.mostActive, rig.active)
			rig.step = step
			rig.everBound = step
			return function()
				rig.unbinds += 1
				rig.active -= 1
				rig.step = nil
			end
		end
		local function now(): number
			return rig.clock
		end
		local function isTurning(): boolean
			return rig.turning
		end
		local easer = CameraFx.newEaseBack(bind, now, isTurning)
		-- One frame: time passes, then the bound step runs (right after Roblox's camera, which the test plays by
		-- changing the fake camera before calling `frame`). Does nothing when no step is bound.
		local function frame(seconds: number)
			rig.clock += seconds
			if rig.step then
				rig.step()
			end
		end
		-- Frames until the ease unbinds itself (at most 2 seconds' worth).
		local function runToEnd(seconds: number)
			local frames = 0
			while rig.step and frames < 2 / seconds do
				frame(seconds)
				frames += 1
			end
		end
		return rig, easer, frame, runToEnd
	end

	it("never changes the camera type, on any frame or after the end", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		local frames = 0
		while rig.step and frames < 200 do
			frame(FRAME)
			expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
			frames += 1
		end
		expect(frames > 10).toBe(true)
		expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
	end)

	it("ends exactly at the end pitch and then unbinds", function()
		local rig, easer, _frame, runToEnd = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		runToEnd(FRAME)
		expect(math.abs(pitchOf(rig.camera.CFrame) - -15) < 0.001).toBe(true)
		expect(rig.unbinds).toBe(1)
		expect(rig.step).toBeNil()
		expect(easer.isRunning()).toBe(false)
		-- If a step still came after that, it would write nothing.
		local finalView = rig.camera.CFrame
		local stale = rig.everBound :: () -> ()
		rig.clock += FRAME
		stale()
		expect(rig.camera.CFrame).toBe(finalView)
	end)

	it("reports that it is running from run until it ends", function()
		local rig, easer, frame, runToEnd = newRig()
		expect(easer.isRunning()).toBe(false)
		easer.run(rig.camera :: any, 0.6, -15)
		expect(easer.isRunning()).toBe(true)
		frame(FRAME)
		expect(easer.isRunning()).toBe(true)
		runToEnd(FRAME)
		expect(easer.isRunning()).toBe(false)
	end)

	it("takes 0.6 seconds of the clock, however many frames that is", function()
		for _, step in { 1 / 120, 0.05, 1 / 30, 0.2 } do
			local rig, easer, _frame, runToEnd = newRig()
			easer.run(rig.camera :: any, 0.6, -15)
			runToEnd(step)
			local elapsed = rig.clock - 100
			-- It ends on the first frame at or past 0.6 s.
			expect(elapsed >= 0.6 - 1e-9).toBe(true)
			expect(elapsed < 0.6 + step + 1e-9).toBe(true)
			expect(rig.unbinds).toBe(1)
		end
	end)

	it("eases: slow at the start and the end, fastest in the middle", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		local pitches: { number } = {}
		while rig.step do
			frame(FRAME)
			table.insert(pitches, pitchOf(rig.camera.CFrame))
		end
		local count = #pitches
		local firstThree = 21 - pitches[3]
		local middleThree = pitches[math.round(count / 2) - 1] - pitches[math.round(count / 2) + 2]
		local lastThree = pitches[count - 3] - pitches[count]
		expect(middleThree > firstThree * 3).toBe(true)
		expect(middleThree > lastThree * 3).toBe(true)
		for index = 2, count do
			expect(pitches[index] <= pitches[index - 1] + 1e-6).toBe(true)
		end
		-- Halfway through the time, the pitch is halfway: (21 + -15) / 2 = 3.
		expect(math.abs(pitches[math.round(count / 2)] - 3) < 2).toBe(true)
	end)

	it("keeps the yaw and the distance that Roblox's camera has on each frame", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		local distance = 12.5
		local lastPitch = 21
		for index = 1, 12 do
			-- Roblox's camera acts first: here it turns the yaw 5 degrees (as the phone's follow camera does) and, on
			-- frame 4, zooms out by 2 studs.
			local turned = CFrame.new(focus)
				* CFrame.Angles(0, math.rad(5), 0)
				* CFrame.new(focus):Inverse()
				* rig.camera.CFrame
			distance += if index == 4 then 2 else 0
			local look = turned.LookVector
			rig.camera.CFrame = CFrame.lookAt(focus - look * distance, focus)
			local yawBefore = flatLook(rig.camera.CFrame)
			frame(FRAME)
			expect(flatLook(rig.camera.CFrame):Dot(yawBefore) > 0.99999).toBe(true)
			expect(math.abs((rig.camera.CFrame.Position - focus).Magnitude - distance) < 0.001).toBe(true)
			-- Only the pitch is ours: it keeps easing down.
			local pitch = pitchOf(rig.camera.CFrame)
			expect(pitch <= lastPitch + 1e-6 and pitch >= -15 - 1e-6).toBe(true)
			lastPitch = pitch
		end
		expect(lastPitch < 21 - 0.1).toBe(true)
	end)

	it("follows the focus as Roblox's camera moves it", function()
		local rig, easer, frame = newRig()
		local startX = rig.camera.CFrame.Position.X
		easer.run(rig.camera :: any, 0.6, -15)
		for _ = 1, 20 do
			-- The character walks: Roblox's camera moves with it, focus and camera together.
			local shift = Vector3.new(0.3, 0, 0.1)
			rig.camera.Focus = rig.camera.Focus + shift
			rig.camera.CFrame = rig.camera.CFrame + shift
			frame(FRAME)
			local nowFocus = rig.camera.Focus.Position
			expect((nowFocus - rig.camera.CFrame.Position).Unit:Dot(rig.camera.CFrame.LookVector) > 0.99999).toBe(true)
			expect(math.abs((rig.camera.CFrame.Position - nowFocus).Magnitude - 12.5) < 0.001).toBe(true)
		end
		-- And the camera really moved along with it: 20 frames of 0.3 studs.
		expect(rig.camera.CFrame.Position.X - startX > 5).toBe(true)
	end)

	it("does not write the focus, which belongs to Roblox's camera", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		local focusBefore = rig.camera.Focus
		frame(FRAME)
		frame(FRAME)
		expect(rig.camera.Focus).toBe(focusBefore)
	end)

	it("stops at once when the player turns, and never writes again", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		for _ = 1, 5 do
			frame(FRAME)
		end
		-- Roblox's camera applies the player's turn this frame; the ease must leave it as it is.
		rig.camera.CFrame = CFrame.new(focus)
			* CFrame.Angles(0, math.rad(3), 0)
			* CFrame.new(focus):Inverse()
			* rig.camera.CFrame
		local turnedView = rig.camera.CFrame
		rig.turning = true
		frame(FRAME)
		expect(rig.camera.CFrame).toBe(turnedView)
		expect(rig.unbinds).toBe(1)
		expect(easer.isRunning()).toBe(false)
		expect(rig.step).toBeNil()
		-- The player lets go: still nothing is written for this run.
		rig.turning = false
		local stale = rig.everBound :: () -> ()
		for _ = 1, 5 do
			rig.clock += FRAME
			stale()
		end
		expect(rig.camera.CFrame).toBe(turnedView)
		expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
	end)

	it("stops when someone else takes the camera, and writes nothing", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		frame(FRAME)
		frame(FRAME)
		local view = rig.camera.CFrame
		rig.camera.CameraType = Enum.CameraType.Scriptable
		frame(FRAME)
		expect(rig.camera.CFrame).toBe(view)
		expect(rig.camera.CameraType).toBe(Enum.CameraType.Scriptable)
		expect(rig.unbinds).toBe(1)
		expect(rig.step).toBeNil()
	end)

	it("leaves a camera that is not on Custom alone, since someone else controls it", function()
		local rig, easer = newRig(Enum.CameraType.Scriptable)
		local view = rig.camera.CFrame
		easer.run(rig.camera :: any, 0.6, -15)
		expect(rig.binds).toBe(0)
		expect(easer.isRunning()).toBe(false)
		expect(rig.camera.CFrame).toBe(view)
		expect(rig.camera.CameraType).toBe(Enum.CameraType.Scriptable)
	end)

	it("unbinds at once when cancelled, and writes nothing after that", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		for _ = 1, 5 do
			frame(FRAME)
		end
		local view = rig.camera.CFrame
		easer.cancel()
		expect(rig.unbinds).toBe(1)
		expect(easer.isRunning()).toBe(false)
		local stale = rig.everBound :: () -> ()
		rig.clock += FRAME
		stale()
		expect(rig.camera.CFrame).toBe(view)
		expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
	end)

	it("does nothing when cancelled while it is not easing", function()
		local rig, easer = newRig(Enum.CameraType.Fixed)
		easer.cancel()
		expect(rig.unbinds).toBe(0)
		expect(rig.camera.CameraType).toBe(Enum.CameraType.Fixed)
	end)

	it("a second run cancels the first, so there is only one binding at a time", function()
		local rig, easer, frame = newRig()
		easer.run(rig.camera :: any, 0.6, -15)
		frame(FRAME)
		local firstStep = rig.everBound :: () -> ()
		easer.run(rig.camera :: any, 0.6, -15)
		expect(rig.binds).toBe(2)
		expect(rig.unbinds).toBe(1)
		expect(rig.mostActive).toBe(1)
		expect(easer.isRunning()).toBe(true)
		-- The first run's step is dead: it writes nothing even if called.
		local view = rig.camera.CFrame
		rig.clock += FRAME
		firstStep()
		expect(rig.camera.CFrame).toBe(view)
	end)

	it("can ease again after it finished", function()
		local rig, easer, _frame, runToEnd = newRig()
		for _ = 1, 2 do
			rig.camera.CFrame = CameraFx.spawnView(focus, characterLook, 12.5, 21)
			easer.run(rig.camera :: any, 0.6, -15)
			runToEnd(FRAME)
			expect(math.abs(pitchOf(rig.camera.CFrame) - -15) < 0.001).toBe(true)
		end
		expect(rig.binds).toBe(2)
		expect(rig.unbinds).toBe(2)
	end)

	it("remembers the look it wrote last, for the fallback that spots a turn", function()
		local rig, easer, frame = newRig()
		expect(easer.lastLook()).toBeNil()
		easer.run(rig.camera :: any, 0.6, -15)
		expect(easer.lastLook()).toBe(rig.camera.CFrame.LookVector)
		frame(FRAME)
		frame(FRAME)
		expect(easer.lastLook()).toBe(rig.camera.CFrame.LookVector)
		easer.cancel()
		expect(easer.lastLook()).toBeNil()
	end)
end)

describe("CameraFx.rotationInput", function()
	-- A tree like Roblox's: <root>.PlayerModule.InputContexts.CameraContext.CameraRotationAction.
	local function treeWith(child: Instance): Folder
		local root = Instance.new("Folder")
		local playerModule = Instance.new("Folder")
		playerModule.Name = "PlayerModule"
		playerModule.Parent = root
		local contexts = Instance.new("Folder")
		contexts.Name = "InputContexts"
		contexts.Parent = playerModule
		local cameraContext = Instance.new("Folder")
		cameraContext.Name = "CameraContext"
		cameraContext.Parent = contexts
		child.Name = "CameraRotationAction"
		child.Parent = cameraContext
		return root
	end

	local function newAction(): InputAction
		local action = Instance.new("InputAction")
		action.Type = Enum.InputActionType.Direction2D
		return action
	end

	-- Edit mode cannot make an InputAction hold a state (Fire does nothing there), so the state is read through this.
	local function readFrom(states: { [Instance]: unknown }): (InputAction) -> unknown
		return function(action: InputAction): unknown
			return states[action]
		end
	end

	it("is turning only while the action's state is a Vector2 that is not zero", function()
		local action = newAction()
		local root = treeWith(action)
		local states: { [Instance]: unknown } = {}
		local isTurning = CameraFx.rotationInput({ root }, function()
			return false
		end, nil, readFrom(states))
		states[action] = Vector2.zero
		expect(isTurning()).toBe(false)
		states[action] = Vector2.new(-2, 0)
		expect(isTurning()).toBe(true)
		states[action] = Vector2.new(0, 0.5)
		expect(isTurning()).toBe(true)
		states[action] = Vector2.zero
		expect(isTurning()).toBe(false)
		root:Destroy()
	end)

	it("is not turning when the state is something other than a Vector2", function()
		local action = newAction()
		local root = treeWith(action)
		local states: { [Instance]: unknown } = { [action] = nil }
		local isTurning = CameraFx.rotationInput({ root }, function()
			return true
		end, nil, readFrom(states))
		expect(isTurning()).toBe(false)
		states[action] = 5
		expect(isTurning()).toBe(false)
		root:Destroy()
	end)

	it("reads the real action's state with no fake: still, it is not turning", function()
		local root = treeWith(newAction())
		local isTurning = CameraFx.rotationInput({ root }, function()
			return true
		end)
		expect(isTurning()).toBe(false)
		root:Destroy()
	end)

	it("uses the action under the first container that has one", function()
		local firstAction = newAction()
		local secondAction = newAction()
		local empty = Instance.new("Folder")
		local first = treeWith(firstAction)
		local second = treeWith(secondAction)
		local states: { [Instance]: unknown } = { [firstAction] = Vector2.zero, [secondAction] = Vector2.new(1, 0) }
		local isTurning = CameraFx.rotationInput({ empty, first, second }, function()
			return false
		end, nil, readFrom(states))
		expect(isTurning()).toBe(false)
		states[firstAction] = Vector2.new(1, 1)
		expect(isTurning()).toBe(true)
		empty:Destroy()
		first:Destroy()
		second:Destroy()
	end)

	it("with no action anywhere, uses the fallback, and warns once", function()
		local warnings: { string } = {}
		local fallbackAnswer = false
		local isTurning = CameraFx.rotationInput({ Instance.new("Folder") }, function()
			return fallbackAnswer
		end, function(message: string)
			table.insert(warnings, message)
		end)
		expect(#warnings).toBe(0)
		expect(isTurning()).toBe(false)
		fallbackAnswer = true
		expect(isTurning()).toBe(true)
		expect(isTurning()).toBe(true)
		expect(#warnings).toBe(1)
		expect(string.find(warnings[1], "CameraRotationAction", 1, true) ~= nil).toBe(true)
	end)

	it("uses the fallback when the thing with that name is not an InputAction", function()
		local notAnAction = Instance.new("Folder")
		local root = treeWith(notAnAction)
		local warnings = 0
		local isTurning = CameraFx.rotationInput({ root }, function()
			return true
		end, function()
			warnings += 1
		end)
		expect(isTurning()).toBe(true)
		expect(warnings).toBe(1)
		root:Destroy()
	end)

	it("skips a container that is nil", function()
		local action = newAction()
		local root = treeWith(action)
		local states: { [Instance]: unknown } = { [action] = Vector2.new(3, 0) }
		local isTurning = CameraFx.rotationInput({ nil, root }, function()
			return false
		end, nil, readFrom(states))
		expect(isTurning()).toBe(true)
		root:Destroy()
	end)
end)

describe("CameraFx.shouldReplace", function()
	it(
		"puts the spawn view back when the view jumped inside the settle window, under the limit, and nobody is turning",
		function()
			expect(CameraFx.shouldReplace(true, 1, true, false)).toBe(true)
			expect(CameraFx.shouldReplace(true, 4, true, false)).toBe(true)
		end
	)

	it("never puts it back while the player is turning, whatever else is true", function()
		expect(CameraFx.shouldReplace(true, 1, true, true)).toBe(false)
		expect(CameraFx.shouldReplace(true, 0, true, true)).toBe(false)
	end)

	it("does not put it back outside the settle window", function()
		expect(CameraFx.shouldReplace(false, 1, true, false)).toBe(false)
	end)

	it("does not put it back once the limit of placements is reached", function()
		expect(CameraFx.shouldReplace(true, 5, true, false)).toBe(false)
		expect(CameraFx.shouldReplace(true, 6, true, false)).toBe(false)
	end)

	it("does not put it back when the view did not jump", function()
		expect(CameraFx.shouldReplace(true, 1, false, false)).toBe(false)
	end)
end)

-- CameraFx.watch: the spawn view and, from Task 27, the bounce view. Everything real is replaced by a stand-in: a fake
-- camera, a fake render binder, a fake clock, a fake frame wait and a fake camera-turn signal. The character is a real
-- Model that is never parented anywhere. The things a Humanoid cannot be told to hold in Edit mode (MoveDirection and
-- FloorMaterial) are read through `parts`.
describe("CameraFx.watch", function()
	local FRAME = 1 / 60
	local BOUNCE_UP = 30
	local SPAWN_UP = 21 -- Roblox's -15 plus the 36 degree tilt
	local EASE_SECONDS = 0.6

	local rigs: { any } = {}
	local madeInstances: { Instance } = {}

	afterEach(function()
		for _, rig in rigs do
			rig.watcher.stop()
		end
		table.clear(rigs)
		for _, instance in madeInstances do
			instance:Destroy()
		end
		table.clear(madeInstances)
	end)

	local function track(instance: Instance): Instance
		table.insert(madeInstances, instance)
		return instance
	end

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
		}
	end

	local function waitUntil(condition: () -> boolean)
		local deadline = os.clock() + 3
		while not condition() and os.clock() < deadline do
			task.wait()
		end
	end

	local function flatOf(look: Vector3): Vector3
		return Vector3.new(look.X, 0, look.Z).Unit
	end

	-- A character with a Humanoid, a root that faces `facing` and a head 2 studs above it.
	local function newCharacter(facing: Vector3): (Model, Humanoid, Part)
		local character = Instance.new("Model")
		track(character)
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(0, 5, 0) + facing)
		root.Parent = character
		local head = Instance.new("Part")
		head.Name = "Head"
		head.CFrame = CFrame.new(0, 7, 0)
		head.Parent = character
		return character, humanoid, root
	end

	-- The tree Roblox's camera input lives in, so the turn signal can be found (and read through `readState`).
	local function inputTree(): Folder
		local tree = Instance.new("Folder")
		track(tree)
		local names = { "PlayerModule", "InputContexts", "CameraContext" }
		local parent: Instance = tree
		for _, name in names do
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = parent
			parent = folder
		end
		local action = Instance.new("InputAction")
		action.Name = "CameraRotationAction"
		action.Type = Enum.InputActionType.Direction2D
		action.Parent = parent
		return tree
	end

	-- Starts a watcher on a player with one character that faces +X. `frame(seconds)` plays one frame: the clock moves,
	-- everything waiting for a frame carries on, then the bound ease step (if any) runs.
	-- `options.eggDegrees`: the first egg sits that many degrees to the right of the way the root faces (negative is left),
	-- 30 studs away; without it no egg waits. `options.noFinder`: the watcher is given no egg finder at all.
	-- `options.realTurn`: the watcher is given no stand-in for turning the character, so it uses its own.
	type RigOptions = { eggDegrees: number?, noFinder: boolean?, realTurn: boolean? }

	-- The place of an egg `degreesRight` to the right of the way `root` faces, `distance` studs away, flat with the root.
	local function eggBeside(root: BasePart, degreesRight: number, distance: number?): Vector3
		local far = distance or 30
		local radians = math.rad(degreesRight)
		return (root.CFrame * CFrame.new(math.sin(radians) * far, 0, -math.cos(radians) * far)).Position
	end

	-- Where `egg` sits when standing at `root` and looking the way it faces: degrees to the right (negative is left).
	local function eggSideOf(root: BasePart, egg: Vector3): number
		local local_ = root.CFrame:PointToObjectSpace(Vector3.new(egg.X, root.Position.Y, egg.Z))
		return math.deg(math.atan2(local_.X, -local_.Z))
	end

	local function newRig(options: RigOptions?)
		local settings: RigOptions = options or {}
		local character, humanoid, root = newCharacter(Vector3.xAxis)
		local focus = Vector3.new(0, 7, 0)
		local rig: any = {
			egg = if settings.eggDegrees ~= nil then eggBeside(root, settings.eggDegrees) else nil,
			eggCalls = 0,
			turns = {} :: { Vector3 },
			cameraAtTurn = nil :: CFrame?,
			heightBinds = 0,
			heightActive = 0,
			heightStep = nil :: (() -> ())?,
			clock = 100,
			moving = false,
			floor = Enum.Material.Grass,
			turning = false,
			waiting = {} :: { thread },
			binds = 0,
			unbinds = 0,
			active = 0,
			step = nil :: (() -> ())?,
			character = character,
			humanoid = humanoid,
			root = root,
			camera = {
				CFrame = CameraFx.spawnView(focus, Vector3.new(0.6, 0, 0.8), 12.5, -15),
				Focus = CFrame.new(focus),
				CameraSubject = humanoid,
				CameraType = Enum.CameraType.Custom,
			},
			characterAdded = newSignal(),
			player = nil :: any,
		}
		rig.player = { Character = character, CharacterAdded = rig.characterAdded }

		function rig.frame(seconds: number)
			rig.clock += seconds
			local list = rig.waiting
			rig.waiting = {}
			for _, parked in list do
				task.spawn(parked)
			end
			if rig.step then
				rig.step()
			end
			if rig.heightStep then
				rig.heightStep()
			end
		end

		function rig.frames(count: number)
			for _ = 1, count do
				rig.frame(FRAME)
			end
		end

		local function bind(step: () -> ()): () -> ()
			rig.binds += 1
			rig.active += 1
			rig.step = step
			return function()
				rig.unbinds += 1
				rig.active -= 1
				rig.step = nil
			end
		end

		-- The watcher is waiting for its first frame once the normal camera has "settled" (the real wait for that is a
		-- few real frames) and the view is placed; one more frame puts it in the waiting loop.
		function rig.settle()
			waitUntil(function()
				return #rig.waiting > 0
			end)
			rig.frame(FRAME)
		end

		-- The server's float: the push on the root, the player in the air.
		function rig.takeOff()
			local push = Instance.new("LinearVelocity")
			push.Name = "BounceFloat"
			push.Parent = rig.root
			rig.floor = Enum.Material.Air
		end

		function rig.land()
			for _, child in rig.root:GetChildren() do
				if child.Name == "BounceFloat" then
					child:Destroy()
				end
			end
			rig.floor = Enum.Material.Grass
		end

		-- A bounce as the player's device sees it: the push is on the root, then the remote arrives. One frame later the
		-- view is placed and the watcher waits for the landing.
		function rig.float(look: Vector3)
			rig.takeOff()
			rig.watcher.bounce(look)
			rig.frame(FRAME)
		end

		function rig.distance(): number
			return (rig.camera.CFrame.Position - rig.camera.Focus.Position).Magnitude
		end

		function rig.pitch(): number
			return pitchOf(rig.camera.CFrame)
		end

		local function bindHeight(step: () -> ()): () -> ()
			rig.heightBinds += 1
			rig.heightActive += 1
			rig.heightStep = step
			return function()
				rig.heightActive -= 1
				rig.heightStep = nil
			end
		end

		local tree = inputTree()
		local parts: any = {
			bindAfterCamera = bind,
			bindHeight = bindHeight,
			containers = { tree :: Instance? },
			readState = function(_action: InputAction): unknown
				return if rig.turning then Vector2.new(1, 0) else Vector2.zero
			end,
			moveDirection = function(_humanoid: Humanoid): Vector3
				return if rig.moving then Vector3.new(0, 0, -1) else Vector3.zero
			end,
			floorMaterial = function(_humanoid: Humanoid): Enum.Material
				return rig.floor
			end,
		}
		if not settings.noFinder then
			parts.firstEgg = function(): Vector3?
				rig.eggCalls += 1
				return rig.egg
			end
		end
		if not settings.realTurn then
			-- Turns the root like the real piece does (about the vertical, keeping its place) and notes what the camera was.
			parts.turnCharacter = function(turnedCharacter: Model, look: Vector3)
				table.insert(rig.turns, look)
				rig.cameraAtTurn = rig.camera.CFrame
				local turnedRoot = turnedCharacter:FindFirstChild("HumanoidRootPart") :: BasePart
				turnedRoot.CFrame = CFrame.lookAt(turnedRoot.Position, turnedRoot.Position + look)
			end
		end
		rig.watcher = CameraFx.watch(
			rig.player,
			function()
				return rig.camera :: any
			end,
			36,
			EASE_SECONDS,
			function()
				table.insert(rig.waiting, coroutine.running())
				coroutine.yield()
			end,
			function()
				return rig.clock
			end,
			parts
		)
		table.insert(rigs, rig)
		return rig
	end

	local function newSettledRig(options: RigOptions?)
		local rig = newRig(options)
		rig.settle()
		return rig
	end

	describe("the spawn view (unchanged by the bounce)", function()
		it("puts the camera behind the character, 21 degrees up, looking the way the root faces", function()
			local rig = newSettledRig()
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
			expect(flatOf(rig.camera.CFrame.LookVector):Dot(Vector3.xAxis) > 0.999).toBe(true)
			expect(math.abs(rig.distance() - 12.5) < 0.01).toBe(true)
		end)

		it("eases to 15 degrees down over 0.6 s on the first move", function()
			local rig = newSettledRig()
			rig.frames(3)
			expect(rig.binds).toBe(0)
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
			rig.moving = false
			rig.frames(40)
			expect(math.abs(rig.pitch() - -15) < 0.05).toBe(true)
		end)

		it("does not ease when the player turned the camera first", function()
			local rig = newSettledRig()
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.moving = true
			rig.frames(3)
			expect(rig.binds).toBe(0)
		end)
	end)

	describe("bounce: the view", function()
		it(
			"places the camera behind the character along the given look, 30 degrees up, whichever way the root faces",
			function()
				local rig = newSettledRig()
				local look = Vector3.new(0.6, 0, -0.8) -- the root faces +X
				rig.float(look)
				expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
				expect(flatOf(rig.camera.CFrame.LookVector):Dot(look) > 0.999).toBe(true)
				expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
			end
		)

		it("keeps the camera's own distance, so a zoomed camera stays zoomed", function()
			local rig = newSettledRig()
			rig.camera.CFrame = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 7, 10)
			rig.float(Vector3.new(0, 0, -1))
			expect(math.abs(rig.distance() - 7) < 0.01).toBe(true)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
		end)

		it("works from a flat look given as a longer or tilted vector", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 4, -3)) -- only the flat part counts: straight -Z
			expect(flatOf(rig.camera.CFrame.LookVector):Dot(Vector3.new(0, 0, -1)) > 0.999).toBe(true)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
		end)

		it("puts the view back if Roblox's camera moves it in the settle window", function()
			local rig = newSettledRig()
			local look = Vector3.new(0, 0, -1)
			rig.float(look)
			-- Roblox's camera script turns the view away in one frame.
			rig.camera.CFrame = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 12.5, 10)
			rig.frame(FRAME)
			expect(flatOf(rig.camera.CFrame.LookVector):Dot(look) > 0.999).toBe(true)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
		end)

		it("does not put the view back after the settle window", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frame(2.5)
			local turned = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 12.5, 10)
			rig.camera.CFrame = turned
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(turned)
		end)

		it("leaves the view alone when the player is turning the camera at that moment", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.turning = true
			rig.takeOff()
			rig.watcher.bounce(Vector3.new(0, 0, -1))
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
		end)

		it("does nothing when the camera is not following this character", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.camera.CameraSubject = nil
			rig.float(Vector3.new(0, 0, -1))
			expect(rig.camera.CFrame).toBe(before)
		end)

		it("does nothing after stop", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.watcher.stop()
			rig.float(Vector3.new(0, 0, -1))
			expect(rig.camera.CFrame).toBe(before)
		end)
	end)

	describe("bounce: a bad look", function()
		it("does nothing for NaN, a table, nil, infinity, a zero look or a look straight up", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			local bad: { any } = {
				Vector3.new(0 / 0, 0, -1),
				Vector3.new(0, 0, 0 / 0),
				Vector3.new(math.huge, 0, 0),
				{ X = 0, Y = 0, Z = -1 },
				"0,0,-1",
				Vector3.zero,
				Vector3.new(0, 1, 0),
				Vector3.new(0, -1, 0),
			}
			for _, look in bad do
				rig.takeOff()
				rig.watcher.bounce(look)
				rig.frame(FRAME)
				rig.land()
				expect(rig.camera.CFrame).toBe(before)
			end
			rig.watcher.bounce(nil :: any)
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			-- The spawn watcher was not cancelled: the first move still eases.
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
		end)
	end)

	describe("bounce: waiting for the landing", function()
		it("starts no ease on a move during the float", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.moving = true
			rig.frames(30)
			expect(rig.binds).toBe(0)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
		end)

		it(
			"does not count the player as landed while the push is still on the root, even with ground under them",
			function()
				local rig = newSettledRig()
				rig.float(Vector3.new(0, 0, -1))
				rig.floor = Enum.Material.Grass -- the push is still there
				rig.moving = true
				rig.frames(10)
				expect(rig.binds).toBe(0)
			end
		)

		it("does not count the player as landed while they are in the air, even with the push gone", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			local push = rig.root:FindFirstChild("BounceFloat")
			expect(push).never.toBeNil();
			(push :: Instance):Destroy() -- the push ends 2.5 studs up and the player drops the last bit
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)

		it("eases to 15 degrees down over 0.6 s on the first move after landing", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(20)
			rig.land()
			rig.frames(5)
			expect(rig.binds).toBe(0)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
			local startClock = rig.clock
			rig.moving = false
			while rig.step do
				rig.frame(FRAME)
				if math.abs(rig.clock - startClock - 0.3) < FRAME / 2 then
					-- Halfway through the time the pitch is halfway: (30 + -15) / 2 = 7.5.
					expect(math.abs(rig.pitch() - 7.5) < 1.5).toBe(true)
				end
			end
			expect(math.abs(rig.pitch() - -15) < 0.05).toBe(true)
			expect(rig.clock - startClock >= EASE_SECONDS - 1e-9).toBe(true)
			expect(rig.clock - startClock < EASE_SECONDS + 2 * FRAME).toBe(true)
			expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
		end)

		it("does not take a grounded state from before the float for a landing", function()
			local rig = newSettledRig()
			-- The remote arrives before the push and the air state have reached the device.
			rig.moving = true
			rig.watcher.bounce(Vector3.new(0, 0, -1))
			rig.frames(5)
			expect(rig.binds).toBe(0)
		end)

		it("counts moves again after 5 seconds, if the landing was never seen", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1)) -- floor Air and the push stay forever
			rig.moving = true
			rig.frame(4.9)
			expect(rig.binds).toBe(0)
			rig.frame(0.2)
			expect(rig.binds).toBe(1)
		end)
	end)

	describe("bounce: the player turns the camera", function()
		it("a turn during the float means no ease after landing", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(5)
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.frames(5)
			rig.land()
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)

		it("a turn after landing and before the first move means no ease", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(5)
			rig.land()
			rig.frames(3)
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)

		it("a turn during the ease stops it at once", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.land()
			rig.frames(2)
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
			rig.frames(5)
			expect(rig.active).toBe(1)
			local before = rig.camera.CFrame
			rig.turning = true
			rig.frame(FRAME)
			expect(rig.active).toBe(0)
			expect(rig.camera.CFrame).toBe(before)
			rig.turning = false
			rig.frames(60)
			expect(rig.camera.CFrame).toBe(before)
		end)
	end)

	describe("bounce: cancelling", function()
		it("a bounce cancels a spawn ease that is running", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.active).toBe(1)
			rig.frames(5)
			rig.moving = false
			rig.float(Vector3.new(0, 0, -1))
			expect(rig.active).toBe(0)
			rig.frames(60)
			expect(rig.binds).toBe(1)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
		end)

		it("a bounce cancels the wait for the spawn's first move", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.moving = true -- the spawn watcher would ease now
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)

		it("a second bounce replaces the first, and only one wait is left", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(3)
			rig.float(Vector3.new(-1, 0, 0)) -- the opposite way from where the root faces, so the old view can't pass
			expect(flatOf(rig.camera.CFrame.LookVector):Dot(Vector3.new(-1, 0, 0)) > 0.999).toBe(true)
			expect(#rig.waiting).toBe(2) -- the camera's wait and the footprint trail's wait, one of each
			rig.land()
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
			rig.frames(40)
			expect(rig.binds).toBe(1)
		end)

		it("a respawn cancels a bounce that is waiting", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(3)
			-- A new character arrives; the camera has not started following it yet.
			local replacement = newCharacter(Vector3.xAxis)
			rig.player.Character = replacement
			rig.characterAdded:Fire(replacement)
			rig.land()
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)

		it("stop cancels a bounce that is waiting", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.watcher.stop()
			rig.land()
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)
	end)

	describe("bounce: the footprint trail", function()
		-- Listens to the trail on a rig. The list grows with every change the watcher announces.
		local function listen(rig: any): { string }
			local heard: { string } = {}
			rig.watcher.onTrail(function(change: string)
				table.insert(heard, change)
			end)
			return heard
		end

		local function expectHeard(heard: { string }, expected: { string })
			expect(table.concat(heard, ",")).toBe(table.concat(expected, ","))
		end

		it("a bounce tells the trail to hide at once", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.takeOff()
			rig.watcher.bounce(Vector3.new(0, 0, -1))
			expectHeard(heard, { "hide" }) -- before any frame has passed
		end)

		it("an ignored bounce (a bad look) tells the trail nothing", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			local bad: { any } = { Vector3.new(0 / 0, 0, -1), Vector3.zero, Vector3.new(0, 1, 0), "0,0,-1" }
			for _, look in bad do
				rig.takeOff()
				rig.watcher.bounce(look)
				rig.frame(FRAME)
				rig.land()
			end
			rig.watcher.bounce(nil :: any)
			expectHeard(heard, {})
		end)

		it("a bounce that finds no character, no camera or a camera on someone else tells the trail nothing", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.camera.CameraSubject = nil
			rig.float(Vector3.new(0, 0, -1))
			rig.camera.CameraSubject = rig.humanoid
			local character = rig.player.Character
			rig.player.Character = nil
			rig.float(Vector3.new(0, 0, -1))
			rig.player.Character = character
			expectHeard(heard, {})
		end)

		it("a move during the float does not bring the trail back", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.moving = true
			rig.frames(30)
			expectHeard(heard, { "hide" })
		end)

		it("the first move after landing fades the trail in, once", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(20)
			rig.land()
			rig.frames(5)
			expectHeard(heard, { "hide" })
			rig.moving = true
			rig.frame(FRAME)
			expectHeard(heard, { "hide", "fadeIn" })
			rig.frames(60)
			expectHeard(heard, { "hide", "fadeIn" })
			expect(#rig.waiting).toBe(0) -- the wait has ended
		end)

		it("a camera turn during the float still brings the trail back at the first move after landing", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(5)
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.frames(5)
			rig.land()
			rig.frames(5)
			expectHeard(heard, { "hide" })
			rig.moving = true
			rig.frame(FRAME)
			expectHeard(heard, { "hide", "fadeIn" })
			expect(rig.binds).toBe(0) -- the camera eases nothing
		end)

		it("a turn after landing and before the first move: the same", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(5)
			rig.land()
			rig.frames(3)
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.frames(3)
			expectHeard(heard, { "hide" })
			rig.moving = true
			rig.frame(FRAME)
			expectHeard(heard, { "hide", "fadeIn" })
			expect(rig.binds).toBe(0)
		end)

		it("after 5 seconds a move brings the trail back even if the landing was never seen", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1)) -- floor Air and the push stay forever
			rig.moving = true
			rig.frame(4.9)
			expectHeard(heard, { "hide" })
			rig.frame(0.2)
			expectHeard(heard, { "hide", "fadeIn" })
		end)

		it("a second bounce: one fadeIn in all, after the second landing", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(3)
			rig.land()
			rig.frames(3)
			rig.float(Vector3.new(-1, 0, 0)) -- bounced again before the first move
			expectHeard(heard, { "hide", "hide" })
			rig.moving = true
			rig.frames(10) -- floating again: the old wait is gone and the new one has not seen a landing
			expectHeard(heard, { "hide", "hide" })
			rig.land()
			rig.frame(FRAME)
			expectHeard(heard, { "hide", "hide", "fadeIn" })
			rig.frames(60)
			expectHeard(heard, { "hide", "hide", "fadeIn" })
		end)

		it("a respawn while hidden shows the trail at once", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(3)
			local replacement = newCharacter(Vector3.xAxis)
			rig.player.Character = replacement
			rig.characterAdded:Fire(replacement)
			expectHeard(heard, { "hide", "show" })
			rig.land()
			rig.moving = true
			rig.frames(10)
			expectHeard(heard, { "hide", "show" }) -- the old wait is over: no fadeIn comes later
		end)

		it("a respawn when the trail is not hidden tells nobody", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			local replacement = newCharacter(Vector3.xAxis)
			rig.player.Character = replacement
			rig.characterAdded:Fire(replacement)
			expectHeard(heard, {})
		end)

		it("stop ends the wait: nothing more is sent", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.float(Vector3.new(0, 0, -1))
			rig.watcher.stop()
			rig.land()
			rig.moving = true
			rig.frames(10)
			expectHeard(heard, { "hide" })
			local late = {}
			rig.watcher.onTrail(function(change: string)
				table.insert(late, change)
			end)
			expect(#late).toBe(0)
		end)

		it("a listener added while hidden is told hide at once, and a removed listener hears nothing", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			local heard = listen(rig)
			expectHeard(heard, { "hide" })
			local removedHeard: { string } = {}
			local remove = rig.watcher.onTrail(function(change: string)
				table.insert(removedHeard, change)
			end)
			expectHeard(removedHeard, { "hide" })
			remove()
			rig.land()
			rig.moving = true
			rig.frame(FRAME)
			expectHeard(heard, { "hide", "fadeIn" })
			expectHeard(removedHeard, { "hide" })
		end)

		it("a listener added when the trail is not hidden is told nothing", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			expectHeard(heard, {})
			rig.float(Vector3.new(0, 0, -1))
			rig.land()
			rig.moving = true
			rig.frame(FRAME)
			local lateHeard = listen(rig) -- the trail is on its way back: not hidden any more
			expectHeard(lateHeard, {})
		end)
	end)

	describe("circleAt: a red circle appears under a player on the low bounce camera", function()
		-- The root is at (0, 5, 0), so the feet are at height 2. This point is under the player: 5 studs away flat, at feet height.
		local UNDER = Vector3.new(3, 2, 4)

		local function listen(rig: any): { string }
			local heard: { string } = {}
			rig.watcher.onTrail(function(change: string)
				table.insert(heard, change)
			end)
			return heard
		end

		-- A bounced player who has landed and stands still, on the low bounce camera.
		local function newLandedRig()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(20)
			rig.land()
			rig.frames(3)
			return rig
		end

		it("starts the ease at once, in the same call, and it ends at 15 degrees down after 0.6 s", function()
			local rig = newLandedRig()
			expect(rig.binds).toBe(0)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(1)
			expect(rig.active).toBe(1)
			local startClock = rig.clock
			while rig.step do
				rig.frame(FRAME)
				if math.abs(rig.clock - startClock - 0.3) < FRAME / 2 then
					-- Halfway through the time the pitch is halfway: (30 + -15) / 2 = 7.5.
					expect(math.abs(rig.pitch() - 7.5) < 1.5).toBe(true)
				end
			end
			expect(math.abs(rig.pitch() - -15) < 0.05).toBe(true)
			expect(rig.clock - startClock >= EASE_SECONDS - 1e-9).toBe(true)
			expect(rig.clock - startClock < EASE_SECONDS + 2 * FRAME).toBe(true)
			expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
		end)

		it("does nothing before the landing: the camera stays at 30 degrees up until the first move", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(10) -- still floating
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(0)
			rig.frames(30)
			expect(rig.binds).toBe(0)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
			rig.land()
			rig.frames(5)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1) -- the first move still eases, as before
		end)

		it("does nothing for a point 16 studs away flat, and works for one 14 studs away", function()
			local rig = newLandedRig()
			rig.watcher.circleAt(Vector3.new(16, 2, 0))
			rig.watcher.circleAt(Vector3.new(-11.5, 2, -11.5)) -- 16.3 away, on the diagonal
			expect(rig.binds).toBe(0)
			rig.watcher.circleAt(Vector3.new(0, 2, 14))
			expect(rig.binds).toBe(1)
		end)

		it("does nothing for a point 7 studs above or below their feet, and works for one 5 studs off", function()
			local rig = newLandedRig()
			rig.watcher.circleAt(Vector3.new(2, 9, 2))
			rig.watcher.circleAt(Vector3.new(2, -5, 2))
			expect(rig.binds).toBe(0)
			rig.watcher.circleAt(Vector3.new(2, 7, 2)) -- 5 above the feet
			expect(rig.binds).toBe(1)
		end)

		it("measures the distance from the player, not from the world's middle", function()
			local rig = newLandedRig()
			rig.root.Position = Vector3.new(100, 5, 100)
			rig.watcher.circleAt(UNDER) -- far from the player now
			expect(rig.binds).toBe(0)
			rig.watcher.circleAt(Vector3.new(103, 2, 104))
			expect(rig.binds).toBe(1)
		end)

		it("does nothing after the player turned the camera", function()
			local rig = newLandedRig()
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(0)
		end)

		it("does nothing while the player is turning the camera at that moment", function()
			local rig = newLandedRig()
			rig.turning = true
			rig.watcher.circleAt(UNDER) -- before the next frame has seen the turn
			expect(rig.binds).toBe(0)
		end)

		it("does nothing after the player moved: the first move already started the ease", function()
			local rig = newLandedRig()
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(1)
		end)

		it("does nothing while the player is moving at that moment", function()
			local rig = newLandedRig()
			rig.moving = true
			rig.watcher.circleAt(UNDER) -- before the next frame has seen the move
			expect(rig.binds).toBe(0)
		end)

		it("starts only one ease when it is called twice", function()
			local rig = newLandedRig()
			rig.watcher.circleAt(UNDER)
			rig.frames(5)
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(1)
		end)

		it("lets a camera turn during the circle's ease stop it at once, and the turn works", function()
			local rig = newLandedRig()
			rig.watcher.circleAt(UNDER)
			rig.frames(5)
			expect(rig.active).toBe(1)
			local before = rig.camera.CFrame
			rig.turning = true
			rig.frame(FRAME)
			expect(rig.active).toBe(0)
			expect(rig.camera.CFrame).toBe(before)
			rig.turning = false
			rig.frames(60)
			expect(rig.camera.CFrame).toBe(before)
		end)

		it(
			"leaves the footprint trail hidden after the circle's ease, and fades it in only at the first move",
			function()
				local rig = newSettledRig()
				local heard = listen(rig)
				rig.float(Vector3.new(0, 0, -1))
				rig.frames(20)
				rig.land()
				rig.frames(3)
				rig.watcher.circleAt(UNDER)
				rig.frames(60) -- the ease is over
				expect(math.abs(rig.pitch() - -15) < 0.05).toBe(true)
				expect(table.concat(heard, ",")).toBe("hide")
				rig.moving = true
				rig.frame(FRAME)
				expect(table.concat(heard, ",")).toBe("hide,fadeIn")
				rig.frames(30)
				expect(table.concat(heard, ",")).toBe("hide,fadeIn")
			end
		)

		it("does not start a second ease at the first move after the circle's ease (one binding in all)", function()
			local rig = newLandedRig()
			rig.watcher.circleAt(UNDER)
			rig.frames(5)
			rig.moving = true
			rig.frames(60)
			expect(rig.binds).toBe(1)
		end)

		it("ends the camera's wait for the first move, but not the footprint trail's", function()
			local rig = newLandedRig()
			expect(#rig.waiting).toBe(2) -- the camera's wait and the trail's wait
			rig.watcher.circleAt(UNDER)
			rig.frames(2)
			expect(#rig.waiting).toBe(1)
		end)

		it("does nothing at the spawn wait, which is not a bounce", function()
			local rig = newSettledRig()
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(0)
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
		end)

		it("does nothing for a point that is not a finite Vector3", function()
			local rig = newLandedRig()
			local bad: { any } = {
				Vector3.new(0 / 0, 2, 0),
				Vector3.new(0, 0 / 0, 0),
				Vector3.new(0, 2, 0 / 0),
				Vector3.new(math.huge, 2, 0),
				Vector3.new(0, -math.huge, 0),
				{ X = 0, Y = 2, Z = 0 },
				"0,2,0",
				42,
			}
			for _, point in bad do
				rig.watcher.circleAt(point)
			end
			rig.watcher.circleAt(nil :: any)
			expect(rig.binds).toBe(0)
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(1)
		end)

		it("does nothing after stop", function()
			local rig = newLandedRig()
			rig.watcher.stop()
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(0)
		end)

		it("does nothing after a respawn, which cancels the bounce's wait", function()
			local rig = newLandedRig()
			local replacement = newCharacter(Vector3.xAxis)
			rig.player.Character = replacement
			rig.characterAdded:Fire(replacement)
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(0)
		end)

		it("lets a second bounce wait again: a circle after it still starts the ease", function()
			local rig = newLandedRig()
			rig.watcher.circleAt(UNDER)
			rig.frames(3)
			rig.float(Vector3.new(-1, 0, 0))
			expect(rig.active).toBe(0)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
			rig.frames(10)
			rig.land()
			rig.frames(3)
			rig.watcher.circleAt(UNDER)
			expect(rig.binds).toBe(2)
			expect(rig.active).toBe(1)
		end)
	end)

	describe("caught: the camera snaps behind the player at their spawn spot", function()
		-- The top-centre of the player's spawn spot. The rig's root stands over it, at (0, 5, 0).
		local SPOT = Vector3.new(0, 1, 0)
		local TOWARD_GIANT = Vector3.new(0, 0, -1)

		-- A player the server just sent home: the root is turned toward the giant, and their camera is their own view
		-- (looking along +X, 5 degrees up, 9 studs away), which is not the spawn view.
		local function newCaughtRig()
			local rig = newSettledRig()
			rig.root.CFrame = CFrame.lookAt(rig.root.Position, rig.root.Position + TOWARD_GIANT)
			rig.camera.CFrame = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 9, 5)
			return rig
		end

		it(
			"with the root already on the spot, places the camera behind the root's look, 21 degrees up, at once",
			function()
				local rig = newCaughtRig()
				rig.watcher.caught(SPOT)
				expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
				expect(flatOf(rig.camera.CFrame.LookVector):Dot(TOWARD_GIANT) > 0.999).toBe(true)
			end
		)

		it("keeps the player's own zoom distance", function()
			local rig = newCaughtRig()
			rig.watcher.caught(SPOT)
			expect(math.abs(rig.distance() - 9) < 0.01).toBe(true)
		end)

		it("gives the camera back as Custom after one frame", function()
			local rig = newCaughtRig()
			rig.watcher.caught(SPOT)
			rig.frame(FRAME)
			expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
		end)

		it("puts the view back if Roblox's camera moves it in the settle window", function()
			local rig = newCaughtRig()
			rig.watcher.caught(SPOT)
			rig.frame(FRAME) -- the view is set, and the camera is given back
			rig.camera.CFrame = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 9, 10)
			rig.frame(FRAME)
			expect(flatOf(rig.camera.CFrame.LookVector):Dot(TOWARD_GIANT) > 0.999).toBe(true)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("leaves the view alone when the player is turning the camera at that moment", function()
			local rig = newCaughtRig()
			local before = rig.camera.CFrame
			rig.turning = true
			rig.watcher.caught(SPOT)
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
		end)

		it(
			"with the root still far away, does nothing until the root reaches the spot, then places the camera",
			function()
				local rig = newCaughtRig()
				rig.root.Position = Vector3.new(60, 5, 0)
				local before = rig.camera.CFrame
				rig.watcher.caught(SPOT)
				rig.frames(30) -- 0.5 s
				expect(rig.camera.CFrame).toBe(before)
				rig.root.CFrame = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(0, 5, -1))
				rig.frame(FRAME)
				expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
				expect(flatOf(rig.camera.CFrame.LookVector):Dot(TOWARD_GIANT) > 0.999).toBe(true)
			end
		)

		it("still places the camera when the root arrives 1.9 seconds later", function()
			local rig = newCaughtRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			rig.watcher.caught(SPOT)
			rig.frame(1.9)
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.frame(FRAME)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("counts the root as arrived within 4 studs, measured flat, and not at 4.2 studs", function()
			local rig = newCaughtRig()
			local before = rig.camera.CFrame
			rig.root.Position = Vector3.new(4.2, 5, 0)
			rig.watcher.caught(SPOT)
			rig.frames(3)
			expect(rig.camera.CFrame).toBe(before)
			rig.root.Position = Vector3.new(3.9, 5, 0)
			rig.frame(FRAME)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("ignores height when it measures the arrival", function()
			local rig = newCaughtRig()
			rig.root.Position = Vector3.new(0, 80, 0) -- far above the spot, flat distance 0
			rig.watcher.caught(SPOT)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("with the root never arriving, does nothing within 2 seconds and stops waiting", function()
			local rig = newCaughtRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			local before = rig.camera.CFrame
			rig.watcher.caught(SPOT)
			rig.frames(130) -- a little over 2 s
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(0)
			expect(rig.active).toBe(0)
			expect(rig.binds).toBe(0)
			-- Arriving after the wait is over does not place anything, and a move does not ease.
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.moving = true
			rig.frames(10)
			expect(rig.camera.CFrame).toBe(before)
			expect(rig.binds).toBe(0)
		end)
	end)

	describe("caught: the ease back and the player's turn", function()
		local SPOT = Vector3.new(0, 1, 0)

		local function newCaughtRig()
			local rig = newSettledRig()
			rig.root.CFrame = CFrame.lookAt(rig.root.Position, rig.root.Position + Vector3.new(0, 0, -1))
			rig.camera.CFrame = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 9, 5)
			rig.watcher.caught(SPOT)
			rig.frames(2)
			return rig
		end

		it("eases to 15 degrees down over 0.6 s on the first move", function()
			local rig = newCaughtRig()
			expect(rig.binds).toBe(0)
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
			local startClock = rig.clock
			rig.moving = false
			while rig.step do
				rig.frame(FRAME)
				if math.abs(rig.clock - startClock - 0.3) < FRAME / 2 then
					-- Halfway through the time the pitch is halfway: (21 + -15) / 2 = 3.
					expect(math.abs(rig.pitch() - 3) < 1.5).toBe(true)
				end
			end
			expect(math.abs(rig.pitch() - -15) < 0.05).toBe(true)
			expect(rig.clock - startClock >= EASE_SECONDS - 1e-9).toBe(true)
			expect(rig.clock - startClock < EASE_SECONDS + 2 * FRAME).toBe(true)
			expect(math.abs(rig.distance() - 9) < 0.01).toBe(true)
			expect(rig.camera.CameraType).toBe(Enum.CameraType.Custom)
		end)

		it("waits for the move: the view stays at 21 degrees up while the player stands still", function()
			local rig = newCaughtRig()
			rig.frames(60)
			expect(rig.binds).toBe(0)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("stops the ease at once when the player turns the camera during it, and the turn works", function()
			local rig = newCaughtRig()
			rig.moving = true
			rig.frame(FRAME)
			rig.frames(5)
			expect(rig.active).toBe(1)
			local before = rig.camera.CFrame
			rig.turning = true
			rig.frame(FRAME)
			expect(rig.active).toBe(0)
			expect(rig.camera.CFrame).toBe(before)
			rig.turning = false
			rig.frames(60)
			expect(rig.camera.CFrame).toBe(before)
		end)

		it("keeps the player's own view when they turn the camera before the first move (no ease)", function()
			local rig = newCaughtRig()
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)
	end)

	describe("caught: cancelling what the watcher was doing", function()
		local SPOT = Vector3.new(0, 1, 0)

		local function listen(rig: any): { string }
			local heard: { string } = {}
			rig.watcher.onTrail(function(change: string)
				table.insert(heard, change)
			end)
			return heard
		end

		it(
			"ends the wait of a bounce: a later circleAt does nothing, and the first move starts one ease only",
			function()
				local rig = newSettledRig()
				rig.float(Vector3.new(0, 0, -1))
				rig.frames(20)
				rig.land()
				rig.frames(3)
				rig.watcher.caught(SPOT)
				rig.frames(2)
				rig.watcher.circleAt(Vector3.new(3, 2, 4)) -- under the player: it would start the bounce's ease
				expect(rig.binds).toBe(0)
				rig.moving = true
				rig.frames(60)
				expect(rig.binds).toBe(1)
			end
		)

		it("ends the wait of a bounce that is still floating: caught places the 21 degree view at once", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			rig.frames(5)
			expect(math.abs(rig.pitch() - BOUNCE_UP) < 0.5).toBe(true)
			rig.watcher.caught(SPOT)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("ends the wait for the spawn's first move", function()
			local rig = newSettledRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			rig.watcher.caught(SPOT)
			rig.moving = true
			rig.frames(10) -- the spawn watcher would ease now
			expect(rig.binds).toBe(0)
		end)

		it("stops an ease that is running", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.active).toBe(1)
			rig.frames(5)
			rig.moving = false
			rig.watcher.caught(SPOT)
			expect(rig.active).toBe(0)
			rig.frames(60)
			expect(rig.binds).toBe(1)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("a second catch replaces the first, and only one wait is left", function()
			local rig = newSettledRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			rig.watcher.caught(SPOT)
			rig.watcher.caught(SPOT)
			rig.frame(FRAME)
			expect(#rig.waiting).toBe(1)
		end)

		it("does not tell the trail anything (no hide, show or fadeIn from caught itself)", function()
			local rig = newSettledRig()
			local heard = listen(rig)
			rig.watcher.caught(SPOT)
			rig.frames(3)
			rig.moving = true
			rig.frames(60)
			expect(table.concat(heard, ",")).toBe("")
		end)

		it(
			"leaves the trail's own wait after a bounce alone, and the trail still fades in at the first move",
			function()
				local rig = newSettledRig()
				local heard = listen(rig)
				rig.float(Vector3.new(0, 0, -1))
				rig.frames(20)
				rig.land()
				rig.frames(3)
				rig.watcher.caught(SPOT)
				rig.frames(3)
				expect(table.concat(heard, ",")).toBe("hide")
				rig.moving = true
				rig.frame(FRAME)
				expect(table.concat(heard, ",")).toBe("hide,fadeIn")
			end
		)
	end)

	describe("caught: things it ignores", function()
		local SPOT = Vector3.new(0, 1, 0)

		it("does nothing after stop", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.watcher.stop()
			rig.watcher.caught(SPOT)
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(0)
		end)

		it("does nothing for a spot that is not a finite Vector3", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.frame(FRAME)
			local waitingBefore = #rig.waiting -- the spawn watcher's wait
			local bad: { any } = {
				Vector3.new(0 / 0, 1, 0),
				Vector3.new(0, 0 / 0, 0),
				Vector3.new(0, 1, 0 / 0),
				Vector3.new(math.huge, 1, 0),
				{ X = 0, Y = 1, Z = 0 },
				"0,1,0",
				42,
			}
			for _, spot in bad do
				rig.watcher.caught(spot)
			end
			rig.watcher.caught(nil :: any)
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(waitingBefore)
			-- The spawn watcher was not cancelled: the first move still eases.
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.binds).toBe(1)
		end)

		it("does nothing when the camera is not following this character", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.frame(FRAME)
			local waitingBefore = #rig.waiting -- the spawn watcher's wait
			rig.camera.CameraSubject = nil
			rig.watcher.caught(SPOT)
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(waitingBefore)
		end)

		it("does nothing when the player has no character", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.frame(FRAME)
			local waitingBefore = #rig.waiting -- the spawn watcher's wait
			rig.player.Character = nil
			rig.watcher.caught(SPOT)
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(waitingBefore)
		end)

		it("does nothing when the character has no root part or no Humanoid", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.frame(FRAME)
			local waitingBefore = #rig.waiting -- the spawn watcher's wait
			local root = rig.root
			root.Name = "NotTheRoot"
			rig.watcher.caught(SPOT)
			root.Name = "HumanoidRootPart"
			local humanoid = rig.humanoid
			humanoid.Name = "NotAHumanoid"
			rig.watcher.caught(SPOT)
			humanoid.Name = "Humanoid"
			rig.frame(FRAME)
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(waitingBefore)
		end)

		it("does nothing when there is no camera", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			local camera = rig.camera
			rig.camera = nil
			rig.watcher.caught(SPOT)
			rig.camera = camera
			expect(rig.camera.CFrame).toBe(before)
		end)

		it("is cancelled by a respawn while it waits for the root", function()
			local rig = newSettledRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			rig.watcher.caught(SPOT)
			local replacement = newCharacter(Vector3.xAxis)
			rig.player.Character = replacement
			rig.characterAdded:Fire(replacement)
			rig.frames(5)
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
		end)

		it("is cancelled by stop while it waits for the root", function()
			local rig = newSettledRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			local before = rig.camera.CFrame
			rig.watcher.caught(SPOT)
			rig.watcher.stop()
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.frames(10)
			expect(rig.camera.CFrame).toBe(before)
			expect(#rig.waiting).toBe(0)
		end)
	end)

	describe("spawn: turning away from the first egg", function()
		-- How far (degrees) the root's way and the camera's flat way differ: the camera follows the root.
		local function cameraFollowsRoot(rig: any): boolean
			return flatOf(rig.camera.CFrame.LookVector):Dot(flatOf(rig.root.CFrame.LookVector)) > 0.999
		end

		it(
			"turns an egg 10 degrees to the right until it sits 20 degrees to the right, before the view is placed",
			function()
				local rig = newSettledRig({ eggDegrees = 10 })
				expect(#rig.turns).toBe(1)
				expect(math.abs(eggSideOf(rig.root, rig.egg) - 20) < 0.01).toBe(true)
				-- The camera was still the rig's first view (looking along 0.6, 0, 0.8, 15 degrees down) when the character turned.
				expect(flatOf((rig.cameraAtTurn :: CFrame).LookVector):Dot(Vector3.new(0.6, 0, 0.8)) > 0.999).toBe(true)
				-- Then the view was placed along the new look, 21 degrees up.
				expect(cameraFollowsRoot(rig)).toBe(true)
				expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
			end
		)

		it("puts an egg 14 degrees to the left 20 degrees to the left", function()
			local rig = newSettledRig({ eggDegrees = -14 })
			expect(#rig.turns).toBe(1)
			expect(math.abs(eggSideOf(rig.root, rig.egg) - -20) < 0.01).toBe(true)
			expect(cameraFollowsRoot(rig)).toBe(true)
		end)

		it("puts an egg dead ahead 20 degrees to the left", function()
			local rig = newSettledRig({ eggDegrees = 0 })
			expect(math.abs(eggSideOf(rig.root, rig.egg) - -20) < 0.01).toBe(true)
			expect(cameraFollowsRoot(rig)).toBe(true)
		end)

		it("turns nobody for an egg already 25 degrees off", function()
			local rig = newSettledRig({ eggDegrees = 25 })
			expect(#rig.turns).toBe(0)
			expect(flatOf(rig.root.CFrame.LookVector):Dot(Vector3.xAxis) > 0.9999).toBe(true)
			expect(cameraFollowsRoot(rig)).toBe(true)
		end)

		it("turns nobody when no egg waits", function()
			local rig = newSettledRig()
			expect(rig.eggCalls).toBe(1)
			expect(#rig.turns).toBe(0)
			expect(cameraFollowsRoot(rig)).toBe(true)
		end)

		it("turns nobody when the watcher was given no egg finder", function()
			local rig = newSettledRig({ noFinder = true })
			expect(#rig.turns).toBe(0)
			expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
		end)

		it("turns the player's own character, about the vertical, keeping the root where it is", function()
			local rig = newRig({ eggDegrees = 10, realTurn = true })
			-- A hat 2 studs in front of the root (the root faces +X), to see the whole character turn with it.
			local hat = Instance.new("Part")
			hat.Name = "Hat"
			hat.CFrame = CFrame.new(2, 5, 0)
			hat.Parent = rig.character
			rig.settle()
			expect((rig.root.Position - Vector3.new(0, 5, 0)).Magnitude < 1e-4).toBe(true)
			expect(math.abs(eggSideOf(rig.root, rig.egg) - 20) < 0.01).toBe(true)
			expect(math.abs(rig.root.CFrame.LookVector.Y) < 1e-4).toBe(true)
			local hatBeside = rig.root.CFrame:PointToObjectSpace(hat.Position)
			expect((hatBeside - Vector3.new(0, 0, -2)).Magnitude < 1e-3).toBe(true)
		end)

		it("does not turn or place anything for a player who is already turning the camera", function()
			local rig = newRig({ eggDegrees = 10 })
			rig.turning = true
			waitUntil(function()
				return rig.eggCalls > 0
			end)
			task.wait()
			expect(#rig.turns).toBe(0)
			expect(rig.humanoid.CameraOffset == Vector3.zero).toBe(true)
		end)

		it("asks again for every new character and turns that one", function()
			local rig = newSettledRig()
			expect(#rig.turns).toBe(0)
			local character, humanoid, root = newCharacter(Vector3.xAxis)
			rig.egg = eggBeside(root, 10)
			rig.character, rig.humanoid, rig.root = character, humanoid, root
			rig.player.Character = character
			rig.camera.CameraSubject = humanoid
			local askedBefore = rig.eggCalls
			rig.characterAdded:Fire(character)
			waitUntil(function()
				return rig.eggCalls > askedBefore
			end)
			rig.frame(FRAME)
			expect(#rig.turns).toBe(1)
			expect(math.abs(eggSideOf(root, rig.egg) - 20) < 0.01).toBe(true)
		end)
	end)

	describe("caught: turning away from the first egg", function()
		local SPOT = Vector3.new(0, 1, 0)
		local TOWARD_GIANT = Vector3.new(0, 0, -1)

		local function newCaughtRig(options: RigOptions?)
			local rig = newSettledRig(options)
			rig.root.CFrame = CFrame.lookAt(rig.root.Position, rig.root.Position + TOWARD_GIANT)
			rig.camera.CFrame = CameraFx.spawnView(rig.camera.Focus.Position, Vector3.xAxis, 9, 5)
			return rig
		end

		it(
			"turns the character so the egg at that moment sits 20 degrees off, then places the view along the new look",
			function()
				local rig = newCaughtRig() -- no egg waited at spawn
				rig.egg = eggBeside(rig.root, 10) -- a different egg waits now
				rig.watcher.caught(SPOT)
				expect(#rig.turns).toBe(1)
				expect(math.abs(eggSideOf(rig.root, rig.egg) - 20) < 0.01).toBe(true)
				expect(flatOf(rig.camera.CFrame.LookVector):Dot(flatOf(rig.root.CFrame.LookVector)) > 0.999).toBe(true)
				expect(math.abs(rig.pitch() - SPAWN_UP) < 0.5).toBe(true)
			end
		)

		it("puts an egg dead ahead on the left after a catch too", function()
			local rig = newCaughtRig()
			rig.egg = eggBeside(rig.root, 0)
			rig.watcher.caught(SPOT)
			expect(math.abs(eggSideOf(rig.root, rig.egg) - -20) < 0.01).toBe(true)
		end)

		it("turns nobody after a catch when no egg waits or the egg is far enough off", function()
			local rig = newCaughtRig()
			rig.watcher.caught(SPOT)
			expect(#rig.turns).toBe(0)
			rig.egg = eggBeside(rig.root, -30)
			rig.watcher.caught(SPOT)
			expect(#rig.turns).toBe(0)
		end)

		it("asks for the egg only once the root is on the spot", function()
			local rig = newCaughtRig()
			rig.root.Position = Vector3.new(60, 5, 0)
			local before = rig.eggCalls
			rig.watcher.caught(SPOT)
			rig.frames(30)
			expect(rig.eggCalls).toBe(before)
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.egg = eggBeside(rig.root, 10)
			rig.frame(FRAME)
			expect(rig.eggCalls).toBe(before + 1)
			expect(#rig.turns).toBe(1)
		end)

		it("never turns anyone for a bounce, and does not even ask for the egg", function()
			local rig = newSettledRig()
			rig.egg = eggBeside(rig.root, 5)
			local before = rig.eggCalls
			rig.float(Vector3.new(0, 0, -1))
			expect(rig.eggCalls).toBe(before)
			expect(#rig.turns).toBe(0)
		end)
	end)

	describe("the raised camera", function()
		local RAISE = Vector3.new(0, 1.5, 0)

		-- The offset the spec's numbers describe: exactly 0 when the ease is over.
		local function offsetOf(rig: any): Vector3
			return rig.humanoid.CameraOffset
		end

		-- Plays frames until the height ease is over (at most a few seconds); gives the seconds it took from `startClock`.
		local function playHeightEase(rig: any, startClock: number): number
			local frames = 0
			while rig.heightStep and frames < 600 do
				rig.frame(FRAME)
				frames += 1
			end
			return rig.clock - startClock
		end

		it("is 1.5 studs up once the spawn view is placed, and stays while the player stands still", function()
			local rig = newSettledRig()
			expect(offsetOf(rig) == RAISE).toBe(true)
			rig.frames(120)
			expect(offsetOf(rig) == RAISE).toBe(true)
			expect(rig.heightBinds).toBe(0)
		end)

		it("is raised again after a catch, once the root is on the spot", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frame(FRAME)
			playHeightEase(rig, rig.clock)
			rig.moving = false
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			rig.root.Position = Vector3.new(60, 5, 0)
			rig.watcher.caught(Vector3.new(0, 1, 0))
			rig.frames(5)
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.frame(FRAME)
			expect(offsetOf(rig) == RAISE).toBe(true)
		end)

		it("is not raised by a bounce", function()
			local rig = newSettledRig()
			rig.float(Vector3.new(0, 0, -1))
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			rig.land()
			rig.frames(5)
			rig.moving = true
			rig.frames(60)
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			expect(rig.heightBinds).toBe(0)
		end)

		it("eases to exactly 0 over 0.6 s from the first move, ending with the tilt", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frame(FRAME)
			expect(rig.heightBinds).toBe(1)
			local startClock = rig.clock
			rig.moving = false
			local last = offsetOf(rig).Y
			local sawHalf = false
			while rig.heightStep do
				rig.frame(FRAME)
				local height = offsetOf(rig).Y
				expect(height <= last + 1e-9).toBe(true)
				last = height
				expect(offsetOf(rig).X).toBe(0)
				expect(offsetOf(rig).Z).toBe(0)
				if math.abs(rig.clock - startClock - 0.3) < FRAME / 2 then
					-- Halfway through the time the height is halfway: 0.75 (the tilt's easing, Sine in and out).
					sawHalf = true
					expect(math.abs(height - 0.75) < 0.05).toBe(true)
				end
			end
			expect(sawHalf).toBe(true)
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			expect(rig.clock - startClock >= EASE_SECONDS - 1e-9).toBe(true)
			expect(rig.clock - startClock < EASE_SECONDS + 2 * FRAME).toBe(true)
			-- The tilt ended in the same frame.
			expect(rig.active).toBe(0)
			expect(math.abs(rig.pitch() - -15) < 0.05).toBe(true)
		end)

		it("starts easing at the first camera turn when the player has not moved, and leaves the tilt alone", function()
			local rig = newSettledRig()
			local before = rig.camera.CFrame
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			expect(rig.binds).toBe(0)
			expect(rig.heightBinds).toBe(1)
			local startClock = rig.clock
			local took = playHeightEase(rig, startClock)
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			expect(took >= EASE_SECONDS - 1e-9).toBe(true)
			expect(took < EASE_SECONDS + 2 * FRAME).toBe(true)
			expect(rig.camera.CFrame).toBe(before)
			-- A later move starts nothing new.
			rig.moving = true
			rig.frames(10)
			expect(rig.binds).toBe(0)
			expect(rig.heightBinds).toBe(1)
		end)

		it(
			"starts easing at the first move even when the player is turning at the same time (the turn wins the tilt)",
			function()
				local rig = newSettledRig()
				rig.turning = true
				rig.moving = true
				rig.frame(FRAME)
				expect(rig.binds).toBe(0)
				expect(rig.heightBinds).toBe(1)
			end
		)

		it("keeps easing to 0 when the player turns the camera during the tilt ease, which stops the tilt", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frame(FRAME)
			local startClock = rig.clock
			rig.frames(5)
			expect(rig.active).toBe(1)
			local heightBefore = offsetOf(rig).Y
			local cameraBefore = rig.camera.CFrame
			rig.turning = true
			rig.frame(FRAME)
			rig.turning = false
			expect(rig.active).toBe(0) -- the tilt ease stopped
			expect(rig.heightActive).toBe(1) -- the height ease did not
			expect(rig.camera.CFrame).toBe(cameraBefore)
			expect(offsetOf(rig).Y < heightBefore).toBe(true)
			local took = playHeightEase(rig, startClock)
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			-- It carried on from where it was: it ends 0.6 s after the first move, not 0.6 s after the turn.
			expect(took >= EASE_SECONDS - 1e-9).toBe(true)
			expect(took < EASE_SECONDS + 2 * FRAME).toBe(true)
			expect(rig.camera.CFrame).toBe(cameraBefore)
		end)

		it("is put straight back to 0 by a bounce, also in the middle of the ease", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frames(8)
			expect(offsetOf(rig).Y > 0).toBe(true)
			expect(rig.heightActive).toBe(1)
			rig.moving = false
			rig.float(Vector3.new(0, 0, -1))
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			expect(rig.heightActive).toBe(0)
			rig.frames(10)
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
		end)

		it("is put straight back to 0 by a bounce before the player has moved", function()
			local rig = newSettledRig()
			expect(offsetOf(rig) == RAISE).toBe(true)
			rig.float(Vector3.new(0, 0, -1))
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
		end)

		it("is put straight back to 0 on the old character when a new character arrives", function()
			local rig = newSettledRig()
			expect(offsetOf(rig) == RAISE).toBe(true)
			local oldHumanoid = rig.humanoid
			local character = newCharacter(Vector3.xAxis)
			rig.characterAdded:Fire(character)
			expect(oldHumanoid.CameraOffset == Vector3.zero).toBe(true)
		end)

		it("is put straight back to 0 when the watcher is stopped, also in the middle of the ease", function()
			local rig = newSettledRig()
			rig.moving = true
			rig.frames(8)
			expect(offsetOf(rig).Y > 0).toBe(true)
			rig.watcher.stop()
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			expect(rig.heightActive).toBe(0)
		end)

		it("is put straight back to 0 when a catch begins, and raised again at the spot", function()
			local rig = newSettledRig()
			expect(offsetOf(rig) == RAISE).toBe(true)
			rig.root.Position = Vector3.new(60, 5, 0)
			rig.watcher.caught(Vector3.new(0, 1, 0))
			expect(offsetOf(rig) == Vector3.zero).toBe(true)
			rig.root.Position = Vector3.new(0, 5, 0)
			rig.frame(FRAME)
			expect(offsetOf(rig) == RAISE).toBe(true)
		end)
	end)

	describe("the raised camera and the wake shake together", function()
		local RAISE = Vector3.new(0, 1.5, 0)
		local STEP = 0.0625 -- 1/16 of a second is exact in binary

		-- A giant that can wake, and the shake on the rig's player. Each `frame` plays one frame for the watcher and the shake.
		local function newShaker(rig: any)
			local state = Instance.new("Folder")
			state:SetAttribute("Phase", "Asleep")
			track(state)
			local step = newSignal()
			local shaker = CameraFx.shakeOnWake({
				giantState = state,
				player = rig.player,
				step = step,
				now = function()
					return rig.clock
				end,
			})
			table.insert(rigs, { watcher = shaker }) -- stopped after the test, like the watchers
			local shake = { startedAt = 0 }
			function shake.wake()
				state:SetAttribute("Phase", "Awake")
				task.wait() -- attribute changes reach listeners a moment after they are set
				shake.startedAt = rig.clock
			end
			function shake.frame(seconds: number)
				rig.frame(seconds)
				step:Fire(seconds)
			end
			function shake.seconds(): number
				return rig.clock - shake.startedAt
			end
			return shake
		end

		local function near(first: Vector3, second: Vector3): boolean
			return (first - second).Magnitude < 1e-4
		end

		it("a wake shake during the spawn view wiggles around the raise and ends on it, not on 0", function()
			local rig = newSettledRig()
			local shake = newShaker(rig)
			shake.wake()
			shake.frame(STEP)
			expect(near(rig.humanoid.CameraOffset, RAISE + CameraFx.shakeOffset(shake.seconds()))).toBe(true)
			expect(rig.humanoid.CameraOffset == RAISE).toBe(false)
			for _ = 1, 8 do
				shake.frame(STEP)
			end
			expect(rig.humanoid.CameraOffset == RAISE).toBe(true)
			-- And it stays until the player moves.
			shake.frame(STEP)
			expect(rig.humanoid.CameraOffset == RAISE).toBe(true)
		end)

		it("a first move during a shake: both run together, and the offset is exactly 0 after both are over", function()
			local rig = newSettledRig()
			local shake = newShaker(rig)
			shake.wake()
			shake.frame(STEP)
			rig.moving = true
			shake.frame(STEP)
			rig.moving = false
			local easeStart = rig.clock
			local last = RAISE.Y
			while rig.heightStep or shake.seconds() < Config.Wake.ShakeSeconds + STEP do
				shake.frame(1 / 60)
				local offset = rig.humanoid.CameraOffset
				local shaking = shake.seconds() < Config.Wake.ShakeSeconds
				-- What is left when the shake's own wiggle is taken away is the height: straight up, never more than before.
				local rest = offset - (if shaking then CameraFx.shakeOffset(shake.seconds()) else Vector3.zero)
				expect(near(Vector3.new(0, rest.Y, 0), rest)).toBe(true)
				expect(rest.Y <= last + 1e-4).toBe(true)
				expect(rest.Y >= -1e-4).toBe(true)
				last = rest.Y
				if not shaking and rig.heightStep then
					-- The shake is over and the height is still easing: no wiggle is left.
					expect(offset.X).toBe(0)
					expect(offset.Z).toBe(0)
				end
			end
			expect(rig.clock - easeStart >= EASE_SECONDS - 1e-9).toBe(true)
			expect(rig.humanoid.CameraOffset == Vector3.zero).toBe(true)
		end)

		it(
			"a shake that begins late in the ease: the ease ends on 0 and the shake then ends on 0, with nothing left",
			function()
				local rig = newSettledRig()
				local shake = newShaker(rig)
				rig.moving = true
				rig.frame(FRAME)
				rig.moving = false
				local easeStart = rig.clock
				while rig.clock - easeStart < 0.3 do
					rig.frame(FRAME)
				end
				shake.wake()
				-- The ease ends (0.6 s) while the shake (until 0.8 s) goes on: the offset is then only the wiggle.
				while rig.heightStep do
					shake.frame(FRAME)
				end
				expect(near(rig.humanoid.CameraOffset, CameraFx.shakeOffset(shake.seconds()))).toBe(true)
				while shake.seconds() < Config.Wake.ShakeSeconds + STEP do
					shake.frame(FRAME)
				end
				expect(rig.humanoid.CameraOffset == Vector3.zero).toBe(true)
			end
		)
	end)
end)

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
