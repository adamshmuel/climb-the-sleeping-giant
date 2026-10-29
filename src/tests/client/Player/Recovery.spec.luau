--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Recovery = require(StarterPlayer.StarterPlayerScripts.Client.Player.Recovery)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
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

local started: { Recovery.Recovery } = {}
local made: { Instance } = {}

-- The deps for the Reset button, with plain-Luau stand-ins. `setCoreResults` says, call by call, whether setCore works
-- (false: it errors, like Roblox's own scripts not being ready yet). Everything it was asked is written down.
local function resetDeps(me: any, setCoreResults: { boolean }?)
	if me.CharacterAdded == nil then
		me.CharacterAdded = newSignal() -- the real player has this event
	end
	local log = {
		setCoreCalls = {} :: { { name: string, value: any } },
		requests = 0,
		waits = {} :: { number },
		pressing = {} :: { boolean },
	}
	local deps = {
		rescued = newSignal() :: any,
		localPlayer = me :: any,
		setCore = function(name: string, value: any)
			table.insert(log.setCoreCalls, { name = name, value = value })
			local results = setCoreResults
			if results ~= nil and results[#log.setCoreCalls] == false then
				error("not ready yet")
			end
		end,
		requestReset = function()
			log.requests += 1
		end,
		wait = function(seconds: number)
			table.insert(log.waits, seconds)
		end,
		setPressing = function(on: boolean)
			table.insert(log.pressing, on)
		end,
		humanoidOf = function(_character: Model): any?
			return nil -- the pressing tests below say which stand-in Humanoid a character has
		end,
	}
	return deps, log
end

-- A character with no parent, a root part and a Humanoid, standing at `position`.
local function makeCharacter(position: Vector3): Model
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
	root.Parent = character
	character.PrimaryPart = root
	table.insert(made, character)
	return character
end

-- A stand-in Humanoid: a real one only changes MoveDirection from the player's input.
local function makeHumanoid()
	local changed = newSignal()
	local humanoid = {
		MoveDirection = Vector3.zero,
		GetPropertyChangedSignal = function(_self: any, _name: string)
			return changed
		end,
	}
	local function steer(direction: Vector3)
		humanoid.MoveDirection = direction
		changed:Fire()
	end
	return humanoid, steer
end

local function rootOf(character: Model): BasePart
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

afterEach(function()
	for _, recovery in started do
		recovery:destroy()
	end
	table.clear(started)
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end)

describe("client Recovery", function()
	it("places the local player's character on the rescue spot", function()
		local rescued = newSignal()
		local me = { Character = makeCharacter(Vector3.new(0, 30, 0)) }
		local deps = resetDeps(me)
		deps.rescued = rescued :: any
		table.insert(started, Recovery.start(deps))
		local target = CFrame.lookAt(Vector3.new(10, 8, 0), Vector3.new(11, 8, 0))

		rescued:Fire(me, Vector3.new(0, 30, 0), target)

		expect((rootOf(me.Character).Position - target.Position).Magnitude < 0.01).toBe(true)
		expect((rootOf(me.Character).CFrame.LookVector - Vector3.xAxis).Magnitude < 0.01).toBe(true)
		expect(rootOf(me.Character).AssemblyLinearVelocity).toEqual(Vector3.zero)
	end)

	it("ignores another player's rescue", function()
		local rescued = newSignal()
		local me = { Character = makeCharacter(Vector3.new(0, 30, 0)) }
		local someoneElse = { Character = makeCharacter(Vector3.new(90, 30, 0)) }
		local deps = resetDeps(me)
		deps.rescued = rescued :: any
		table.insert(started, Recovery.start(deps))

		rescued:Fire(someoneElse, Vector3.new(90, 30, 0), CFrame.new(10, 8, 0))

		expect(rootOf(me.Character).Position).toEqual(Vector3.new(0, 30, 0))
		expect(rootOf(me.Character).AssemblyLinearVelocity).toEqual(Vector3.new(0, -20, 0))
	end)

	it("Roblox's Reset button sends RequestReset", function()
		local deps, log = resetDeps({ Character = makeCharacter(Vector3.zero) })
		table.insert(started, Recovery.start(deps))
		local bindable = log.setCoreCalls[1].value :: BindableEvent

		expect(log.setCoreCalls[1].name).toBe("ResetButtonCallback")
		expect(typeof(bindable)).toBe("Instance")
		bindable:Fire()
		task.wait() -- a BindableEvent hands its event over on the next frame

		expect(log.requests).toBe(1)
	end)

	it("tries SetCore again until Roblox is ready", function()
		local deps, log = resetDeps({ Character = makeCharacter(Vector3.zero) }, { false, false, true })
		table.insert(started, Recovery.start(deps))

		expect(#log.setCoreCalls).toBe(3)
		expect(#log.waits).toBe(2)
		expect(log.waits[1]).toBe(1)
	end)

	it("gives Roblox its own Reset back when destroyed", function()
		local deps, log = resetDeps({ Character = makeCharacter(Vector3.zero) })
		local recovery = Recovery.start(deps)
		local bindable = log.setCoreCalls[1].value :: BindableEvent

		recovery:destroy()
		bindable:Fire()
		task.wait()

		expect(log.setCoreCalls[2].name).toBe("ResetButtonCallback")
		expect(log.setCoreCalls[2].value).toBe(true)
		expect(log.requests).toBe(0)
	end)

	describe("pressing to move", function()
		it("sends true when the player starts pressing to move", function()
			local me = { Character = makeCharacter(Vector3.zero) }
			local humanoid, steer = makeHumanoid()
			local deps, log = resetDeps(me)
			deps.humanoidOf = function(_character: Model): any?
				return humanoid
			end
			table.insert(started, Recovery.start(deps))

			steer(Vector3.xAxis)

			expect(log.pressing).toEqual({ true })
		end)

		it("sends nothing while the direction changes but stays non-zero", function()
			local me = { Character = makeCharacter(Vector3.zero) }
			local humanoid, steer = makeHumanoid()
			local deps, log = resetDeps(me)
			deps.humanoidOf = function(_character: Model): any?
				return humanoid
			end
			table.insert(started, Recovery.start(deps))

			steer(Vector3.xAxis)
			steer(Vector3.new(1, 0, 1).Unit)
			steer(Vector3.zAxis)

			expect(log.pressing).toEqual({ true })
		end)

		it("sends false when the player stops", function()
			local me = { Character = makeCharacter(Vector3.zero) }
			local humanoid, steer = makeHumanoid()
			local deps, log = resetDeps(me)
			deps.humanoidOf = function(_character: Model): any?
				return humanoid
			end
			table.insert(started, Recovery.start(deps))

			steer(Vector3.xAxis)
			steer(Vector3.zero)

			expect(log.pressing).toEqual({ true, false })
		end)

		it("follows a new character and forgets the old one", function()
			local first = makeCharacter(Vector3.zero)
			local second = makeCharacter(Vector3.new(50, 0, 0))
			local me: any = { Character = first }
			local oldHumanoid, steerOld = makeHumanoid()
			local newHumanoid, steerNew = makeHumanoid()
			local deps, log = resetDeps(me)
			deps.humanoidOf = function(character: Model): any?
				return if character == first then oldHumanoid else newHumanoid
			end
			table.insert(started, Recovery.start(deps))
			steerOld(Vector3.xAxis)

			me.Character = second
			me.CharacterAdded:Fire(second)
			steerOld(Vector3.zero) -- the old character is gone: nothing from it
			steerNew(Vector3.zAxis)

			expect(log.pressing).toEqual({ true, true })
		end)

		it("stops watching when destroyed", function()
			local me: any = { Character = makeCharacter(Vector3.zero) }
			local humanoid, steer = makeHumanoid()
			local deps, log = resetDeps(me)
			deps.humanoidOf = function(_character: Model): any?
				return humanoid
			end
			local recovery = Recovery.start(deps)
			steer(Vector3.xAxis)

			recovery:destroy()
			steer(Vector3.zero)
			me.CharacterAdded:Fire(makeCharacter(Vector3.zero))

			expect(log.pressing).toEqual({ true })
		end)
	end)
end)
