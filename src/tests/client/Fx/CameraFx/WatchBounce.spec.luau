--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)
local Helpers = require(script.Parent.Helpers)
local BOUNCE_UP = Helpers.BOUNCE_UP
local EASE_SECONDS = Helpers.EASE_SECONDS
local FRAME = Helpers.FRAME
local SPAWN_UP = Helpers.SPAWN_UP
local cleanUp = Helpers.cleanUp
local flatOf = Helpers.flatOf
local newCharacter = Helpers.newCharacter
local newSettledRig = Helpers.newSettledRig

afterEach(cleanUp)

-- CameraFx.watch: the spawn view and, from Task 27, the bounce view. Everything real is replaced by a stand-in: a fake
-- camera, a fake render binder, a fake clock, a fake frame wait and a fake camera-turn signal. The character is a real
-- Model that is never parented anywhere. The things a Humanoid cannot be told to hold in Edit mode (MoveDirection and
-- FloorMaterial) are read through `parts`.
describe("CameraFx.watch", function()
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
end)
