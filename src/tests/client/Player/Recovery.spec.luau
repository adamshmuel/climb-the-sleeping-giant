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
		table.insert(started, Recovery.start({ rescued = rescued :: any, localPlayer = me :: any }))
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
		table.insert(started, Recovery.start({ rescued = rescued :: any, localPlayer = me :: any }))

		rescued:Fire(someoneElse, Vector3.new(90, 30, 0), CFrame.new(10, 8, 0))

		expect(rootOf(me.Character).Position).toEqual(Vector3.new(0, 30, 0))
		expect(rootOf(me.Character).AssemblyLinearVelocity).toEqual(Vector3.new(0, -20, 0))
	end)
end)
