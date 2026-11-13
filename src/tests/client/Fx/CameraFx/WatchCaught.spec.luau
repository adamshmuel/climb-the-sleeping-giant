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

describe("CameraFx.watch", function()
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
end)
