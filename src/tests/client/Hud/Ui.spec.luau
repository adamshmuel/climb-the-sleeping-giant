--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Ui = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Ui)

-- Every fake screen made by a test is destroyed afterwards, so the real place is never changed.
local made: { Instance } = {}
local function newParent(): Folder
	local folder = Instance.new("Folder")
	table.insert(made, folder)
	return folder
end

afterEach(function()
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end)

describe("Ui.hud", function()
	it("is a screen that survives respawn and keeps clear of Roblox's own buttons (CoreUISafeInsets)", function()
		local hud = Ui.hud(newParent())
		expect(hud.Name).toBe("Hud")
		expect(hud.ResetOnSpawn).toBe(false)
		expect(hud.ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
	end)

	it("gives back the same screen the second time", function()
		local parent = newParent()
		expect(Ui.hud(parent)).toBe(Ui.hud(parent))
	end)
end)

describe("Ui.hudTop", function()
	it("is a screen that survives respawn and only avoids the phone notch (DeviceSafeInsets)", function()
		local hudTop = Ui.hudTop(newParent())
		expect(hudTop.Name).toBe("HudTop")
		expect(hudTop.ResetOnSpawn).toBe(false)
		expect(hudTop.ScreenInsets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
	end)

	it("gives back the same screen the second time", function()
		local parent = newParent()
		expect(Ui.hudTop(parent)).toBe(Ui.hudTop(parent))
	end)

	it("is a different screen from Hud", function()
		local parent = newParent()
		expect(Ui.hudTop(parent)).never.toBe(Ui.hud(parent))
	end)
end)

describe("Ui.worldLayer", function()
	it(
		"is a screen for things pinned to the world (like the grab prompt) that survives respawn and has no insets",
		function()
			local layer = Ui.worldLayer(newParent())
			expect(layer.Name).toBe("WorldPrompts")
			expect(layer.ResetOnSpawn).toBe(false)
			expect(layer.ScreenInsets).toBe(Enum.ScreenInsets.None)
		end
	)

	it("gives back the same screen the second time", function()
		local parent = newParent()
		expect(Ui.worldLayer(parent)).toBe(Ui.worldLayer(parent))
	end)
end)
