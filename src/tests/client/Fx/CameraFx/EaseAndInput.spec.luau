--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)
local Helpers = require(script.Parent.Helpers)
local pitchOf = Helpers.pitchOf

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
