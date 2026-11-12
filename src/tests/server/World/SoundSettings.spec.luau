--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local SoundSettings = require(ServerScriptService.Server.World.SoundSettings)

-- Plan 7 Task 4: SoundSettings.read on made-up services. Roblox's character sounds need CharacterSoundsUseNewApi = Enabled
-- (Default is a problem too) and a listener that is not None (spec 7 Rule 96).

local function fake(api: Enum.RolloutState, listener: Enum.ListenerLocation): SoundSettings.Service
	return { CharacterSoundsUseNewApi = api, DefaultListenerLocation = listener }
end

describe("SoundSettings.read", function()
	it("gives no problems for Enabled and Camera", function()
		expect(SoundSettings.read(fake(Enum.RolloutState.Enabled, Enum.ListenerLocation.Camera))).toEqual({})
	end)

	it("names CharacterSoundsUseNewApi when it is Default", function()
		local problems = SoundSettings.read(fake(Enum.RolloutState.Default, Enum.ListenerLocation.Camera))
		expect(#problems).toBe(1)
		expect((string.find(problems[1], "CharacterSoundsUseNewApi", 1, true))).never.toBeNil()
	end)

	it("names CharacterSoundsUseNewApi when it is Disabled", function()
		local problems = SoundSettings.read(fake(Enum.RolloutState.Disabled, Enum.ListenerLocation.Camera))
		expect(#problems).toBe(1)
		expect((string.find(problems[1], "CharacterSoundsUseNewApi", 1, true))).never.toBeNil()
	end)

	it("names DefaultListenerLocation when the listener is None", function()
		local problems = SoundSettings.read(fake(Enum.RolloutState.Enabled, Enum.ListenerLocation.None))
		expect(#problems).toBe(1)
		expect((string.find(problems[1], "DefaultListenerLocation", 1, true))).never.toBeNil()
	end)

	it("accepts the Character and Default listeners", function()
		expect(SoundSettings.read(fake(Enum.RolloutState.Enabled, Enum.ListenerLocation.Character))).toEqual({})
		expect(SoundSettings.read(fake(Enum.RolloutState.Enabled, Enum.ListenerLocation.Default))).toEqual({})
	end)
end)
