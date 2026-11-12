--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local SoundSettings = require(ServerScriptService.Server.World.SoundSettings)

-- Plan 7 Task 4: these tests only READ the real SoundService and the place. They change nothing.
describe("the real sound setup", function()
	it("the real SoundService gives no problems", function()
		local service = game:GetService("SoundService")
		expect(SoundSettings.read(service)).toEqual({})
	end)

	-- Spec 7 Rule 99: "No file, script, place or saved setting may hold the mute."
	it("no Sound, SoundGroup or AudioFader with Volume 0 is saved in the place", function()
		local roots: { Instance } = {
			game:GetService("Workspace"),
			game:GetService("ReplicatedStorage"),
			game:GetService("ServerStorage"),
			game:GetService("ServerScriptService"),
			game:GetService("StarterPlayer"),
			game:GetService("StarterGui"),
			game:GetService("SoundService"),
		}
		local found: { string } = {}
		for _, root in roots do
			for _, item in root:GetDescendants() do
				if item:IsA("Sound") or item:IsA("SoundGroup") or item:IsA("AudioFader") then
					local volume = (item :: any).Volume
					if volume == 0 then
						table.insert(found, item:GetFullName())
					end
				end
			end
		end
		expect(table.concat(found, "; ")).toBe("")
	end)
end)
