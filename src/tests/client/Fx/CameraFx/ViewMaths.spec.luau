--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)
local Helpers = require(script.Parent.Helpers)
local pitchOf = Helpers.pitchOf

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
