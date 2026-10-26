--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Config = require(ReplicatedStorage.Shared.Config)
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)
local Helpers = require(script.Parent.Helpers)
type RigOptions = Helpers.RigOptions
local EASE_SECONDS = Helpers.EASE_SECONDS
local FRAME = Helpers.FRAME
local SPAWN_UP = Helpers.SPAWN_UP
local cleanUp = Helpers.cleanUp
local eggBeside = Helpers.eggBeside
local flatOf = Helpers.flatOf
local newCharacter = Helpers.newCharacter
local newRig = Helpers.newRig
local newSettledRig = Helpers.newSettledRig
local newSignal = Helpers.newSignal
local rigs = Helpers.rigs
local track = Helpers.track
local waitUntil = Helpers.waitUntil

afterEach(cleanUp)

-- Where `egg` sits when standing at `root` and looking the way it faces: degrees to the right (negative is left).
local function eggSideOf(root: BasePart, egg: Vector3): number
	local local_ = root.CFrame:PointToObjectSpace(Vector3.new(egg.X, root.Position.Y, egg.Z))
	return math.deg(math.atan2(local_.X, -local_.Z))
end

describe("CameraFx.watch", function()
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
