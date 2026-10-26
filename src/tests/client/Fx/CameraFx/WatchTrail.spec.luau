--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
local BOUNCE_UP = Helpers.BOUNCE_UP
local EASE_SECONDS = Helpers.EASE_SECONDS
local FRAME = Helpers.FRAME
local cleanUp = Helpers.cleanUp
local newCharacter = Helpers.newCharacter
local newSettledRig = Helpers.newSettledRig

afterEach(cleanUp)

describe("CameraFx.watch", function()
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
end)
