--!strict
-- Small helpers that build the screen's pieces the same way every time: the Hud screen, plain frames, rounded
-- outlined panels and text in the game's font. No game rules here.

local Theme = require(script.Parent.Theme)

local Ui = {}

local HUD_NAME = "Hud"
local HUD_TOP_NAME = "HudTop"
local WORLD_LAYER_NAME = "WorldPrompts"

-- Gives back the screen with this name, making it the first time. It stays when the character respawns.
local function screenNamed(parent: Instance, name: string, insets: Enum.ScreenInsets): ScreenGui
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = insets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	return gui
end

-- The screen for the game's buttons, cards and banners. It keeps clear of Roblox's own buttons and the phone
-- notch: it starts below Roblox's top bar.
function Ui.hud(parent: Instance): ScreenGui
	return screenNamed(parent, HUD_NAME, Enum.ScreenInsets.CoreUISafeInsets)
end

-- The screen for the sleep meter only. It keeps clear of the phone notch but starts at the very top of the
-- screen, so the meter sits where the mockups put it and doesn't cover the giant. Roblox's buttons take only
-- the top left, so whatever goes here must keep out of that corner itself (see Layout.meterCenterX).
function Ui.hudTop(parent: Instance): ScreenGui
	return screenNamed(parent, HUD_TOP_NAME, Enum.ScreenInsets.DeviceSafeInsets)
end

-- The screen for things pinned to a spot in the world, such as the grab prompt. It has no insets, because the
-- pieces on it follow the world and not the edge of the screen.
function Ui.worldLayer(parent: Instance): ScreenGui
	return screenNamed(parent, WORLD_LAYER_NAME, Enum.ScreenInsets.None)
end

-- A frame with no background, to place and group other pieces.
function Ui.group(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- A frame with a colour and rounded corners (`radius` as a UDim: scale 0.5 makes a pill).
function Ui.panel(name: string, parent: Instance, color: Color3, radius: UDim): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
	return frame
end

-- A thick outline around a frame, following its rounded corners.
function Ui.outline(target: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
	return stroke
end

-- Text in Fredoka One, with no background.
function Ui.text(name: string, parent: Instance, text: string, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = Theme.font
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextWrapped = false
	label.RichText = false
	label.Parent = parent
	return label
end

return Ui
