--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

-- The foot is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Theme = require(Hud.Theme)
local TiptoeButton = require(Hud.TiptoeButton)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A tiny stand-in for UserInputService.InputBegan: Connect, Fire and Disconnect, all in plain Luau.
local function newInputSignal()
	local handlers: { (any, boolean) -> () } = {}
	return {
		Connect = function(_self: any, callback: (any, boolean) -> ())
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
		Fire = function(_self: any, input: any, gameProcessed: boolean)
			for _, handler in table.clone(handlers) do
				handler(input, gameProcessed)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

-- A tiny stand-in for a RemoteEvent's OnClientEvent or RenderStepped: Connect, Fire and Disconnect, in plain Luau.
local function newSignal(): any
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
		count = function(_self: any): number
			return #handlers
		end,
	}
end

type Rig = {
	parent: Folder,
	attributes: Folder,
	sent: { boolean },
	inputBegan: any,
	warning: any,
	step: any,
	advance: (seconds: number) -> (),
	handle: TiptoeButton.Handle,
	setTiptoe: (value: any) -> (),
	pressKey: (key: Enum.KeyCode, gameProcessed: boolean) -> (),
	setViewport: (size: Vector2) -> (),
	hud: () -> ScreenGui,
	root: () -> Frame,
	button: () -> TextButton,
	ring: () -> Frame,
	glow: () -> Frame,
	glowStroke: () -> UIStroke,
	word: () -> TextLabel,
	emoji: () -> TextLabel,
	key: () -> TextLabel,
}

-- Starts the button on fake stand-ins for the player's screen, the player, the remote and the screen size,
-- so a test can drive all of them.
local function newRig(viewport: Vector2?): Rig
	local parent = made(Instance.new("Folder"))
	local attributes = made(Instance.new("Folder"))
	local viewportEvent = made(Instance.new("BindableEvent"))
	local viewportSize = viewport or Vector2.new(1280, 720)
	local sent: { boolean } = {}
	local inputBegan = newInputSignal()
	local warning = newSignal()
	local step = newSignal()
	local clock = 100

	local handle = TiptoeButton.start({
		parent = parent,
		player = {
			GetAttribute = function(_self: any, name: string): any
				return attributes:GetAttribute(name)
			end,
			GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
				return attributes:GetAttributeChangedSignal(name)
			end,
		},
		send = function(on: boolean)
			table.insert(sent, on)
		end,
		input = { InputBegan = inputBegan },
		warning = { OnClientEvent = warning },
		step = step,
		now = function()
			return clock
		end,
		viewport = {
			get = function()
				return viewportSize
			end,
			connect = function(callback: () -> ())
				local connection = viewportEvent.Event:Connect(callback)
				return function()
					connection:Disconnect()
				end
			end,
		},
	})
	table.insert(stops, handle.stop)

	local function find<T>(name: string): T
		local hud = parent:FindFirstChild("Hud") :: Instance
		return hud:FindFirstChild(name, true) :: any
	end
	return {
		parent = parent,
		attributes = attributes,
		sent = sent,
		inputBegan = inputBegan,
		warning = warning,
		step = step,
		advance = function(seconds: number)
			clock += seconds
			step:Fire(seconds)
		end,
		handle = handle,
		setTiptoe = function(value: any)
			attributes:SetAttribute("Tiptoe", value)
			task.wait() -- attribute changes reach listeners a moment after they are set
		end,
		pressKey = function(key: Enum.KeyCode, gameProcessed: boolean)
			inputBegan:Fire({ KeyCode = key }, gameProcessed)
		end,
		setViewport = function(size: Vector2)
			viewportSize = size
			viewportEvent:Fire()
			task.wait()
		end,
		hud = function()
			return parent:FindFirstChild("Hud") :: ScreenGui
		end,
		root = function()
			return find("Tiptoe")
		end,
		button = function()
			return find("Button")
		end,
		ring = function()
			return find("OnRing")
		end,
		glow = function()
			return find("WarnGlow")
		end,
		glowStroke = function()
			return (find("WarnGlow") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
		end,
		word = function()
			return find("Word")
		end,
		emoji = function()
			return find("Emoji")
		end,
		key = function()
			return find("Key")
		end,
	}
end

describe("TiptoeButton.start: the screen", function()
	it("puts the button on Hud, which survives respawn and keeps clear of Roblox's buttons", function()
		local rig = newRig()
		local hud = rig.hud()
		expect(hud).never.toBeNil()
		expect(hud.ClassName).toBe("ScreenGui")
		expect(hud.ResetOnSpawn).toBe(false)
		expect(hud.ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
		expect(rig.root().Parent).toBe(hud)
	end)

	it("sits at the right side, in the middle, 18 px from the edge", function()
		local root = newRig().root()
		expect(root.AnchorPoint).toBe(Vector2.new(1, 0.5))
		expect(root.Position.X.Scale).toBe(1)
		expect(root.Position.X.Offset).toBe(-18)
		expect(root.Position.Y.Scale).toBe(0.5)
		expect(root.Position.Y.Offset).toBe(0)
	end)

	it("makes no second Hud or button when started again on the same screen", function()
		local rig = newRig()
		local second = TiptoeButton.start({
			parent = rig.parent,
			player = {
				GetAttribute = function(): any
					return nil
				end,
				GetAttributeChangedSignal = function(): RBXScriptSignal
					return made(Instance.new("BindableEvent")).Event
				end,
			},
			send = function() end,
			input = { InputBegan = newInputSignal() },
			warning = { OnClientEvent = newSignal() },
			step = newSignal(),
			now = function()
				return 0
			end,
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function()
					return function() end
				end,
			},
		})
		table.insert(stops, second.stop)
		local huds = 0
		local buttons = 0
		for _, child in rig.parent:GetChildren() do
			if child.Name == "Hud" then
				huds += 1
			end
		end
		for _, descendant in rig.parent:GetDescendants() do
			if descendant.Name == "Tiptoe" and descendant:IsA("Frame") then
				buttons += 1
			end
		end
		expect(huds).toBe(1)
		expect(buttons).toBe(1)
	end)
end)

describe("TiptoeButton.start: the look", function()
	it("is a round button with the foot, the word Tiptoe and the key C on a computer screen", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.button():IsA("GuiButton")).toBe(true)
		expect(rig.emoji().Text == "🦶").toBe(true)
		expect(rig.word().Text).toBe("Tiptoe")
		expect(rig.key().Text).toBe("C")
	end)

	it("is 92 px round on a 1280x720 screen, with the key shown", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.root().Size).toBe(UDim2.fromOffset(92, 92))
		expect(rig.key().Visible).toBe(true)
		expect(rig.word().TextSize).toBe(17)
		expect(rig.emoji().TextSize).toBe(36)
	end)

	it("is 60 px round on a 750x390 screen, with a 14 px word and no key", function()
		local rig = newRig(Vector2.new(750, 390))
		expect(rig.root().Size).toBe(UDim2.fromOffset(60, 60))
		expect(rig.key().Visible).toBe(false)
		expect(rig.word().TextSize).toBe(14)
	end)

	it("picks the size again when the screen size changes", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.setViewport(Vector2.new(750, 390))
		expect(rig.root().Size).toBe(UDim2.fromOffset(60, 60))
		expect(rig.key().Visible).toBe(false)
		rig.setViewport(Vector2.new(1280, 720))
		expect(rig.root().Size).toBe(UDim2.fromOffset(92, 92))
		expect(rig.key().Visible).toBe(true)
	end)

	it("has a 4 px Ink outline, round corners and a top-to-bottom sleep-blue gradient", function()
		local button = newRig().button()
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Thickness).toBe(4)
		expect(stroke.Color == Theme.ink).toBe(true)
		local corner = button:FindFirstChildOfClass("UICorner") :: UICorner
		expect(corner.CornerRadius).toBe(UDim.new(0.5, 0))
		local gradient = button:FindFirstChildOfClass("UIGradient") :: UIGradient
		expect(gradient.Rotation).toBe(90)
		local keypoints = gradient.Color.Keypoints
		expect(keypoints[1].Value == Color3.fromHex("8F9CF0")).toBe(true)
		expect(keypoints[#keypoints].Value == Color3.fromHex("2F3B8F")).toBe(true)
	end)

	it("has a 6 px Ink shadow under it", function()
		local rig = newRig()
		local shadow = rig.root():FindFirstChild("Shadow") :: Frame
		expect(shadow.BackgroundColor3 == Theme.ink).toBe(true)
		expect(shadow.Position.Y.Offset).toBe(6)
		expect(shadow.Size).toBe(UDim2.fromScale(1, 1))
	end)

	it("outlines the word in Ink so it reads on the button", function()
		local rig = newRig()
		local stroke = rig.word():FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.ink).toBe(true)
		expect(rig.word().TextColor3 == Theme.white).toBe(true)
	end)
end)

describe("TiptoeButton.start: lighting up", function()
	it("is not lit when the player has no Tiptoe attribute yet", function()
		expect(newRig().ring().Visible).toBe(false)
	end)

	it("lights up with a 5 px white ring, 2 px outside the button, when Tiptoe is true", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.setTiptoe(true)
		local ring = rig.ring()
		expect(ring.Visible).toBe(true)
		local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Thickness).toBe(5)
		expect(stroke.Color == Theme.white).toBe(true)
		expect(ring.Size).toBe(UDim2.fromOffset(96, 96)) -- the button plus 2 px on each side
	end)

	it("goes dark again when Tiptoe goes back to false", function()
		local rig = newRig()
		rig.setTiptoe(true)
		rig.setTiptoe(false)
		expect(rig.ring().Visible).toBe(false)
	end)

	it("is lit only for exactly true, not for 'yes' or 1", function()
		local rig = newRig()
		rig.setTiptoe("yes")
		expect(rig.ring().Visible).toBe(false)
		rig.setTiptoe(1)
		expect(rig.ring().Visible).toBe(false)
	end)

	it("is already lit when it starts for a player whose Tiptoe is on", function()
		local parent = made(Instance.new("Folder"))
		local attributes = made(Instance.new("Folder"))
		attributes:SetAttribute("Tiptoe", true)
		local handle = TiptoeButton.start({
			parent = parent,
			player = {
				GetAttribute = function(_self: any, name: string): any
					return attributes:GetAttribute(name)
				end,
				GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
					return attributes:GetAttributeChangedSignal(name)
				end,
			},
			send = function() end,
			input = { InputBegan = newInputSignal() },
			warning = { OnClientEvent = newSignal() },
			step = newSignal(),
			now = function()
				return 0
			end,
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function()
					return function() end
				end,
			},
		})
		table.insert(stops, handle.stop)
		local ring = (parent:FindFirstChild("Hud") :: Instance):FindFirstChild("OnRing", true) :: Frame
		expect(ring.Visible).toBe(true)
	end)

	it("never lights up from a click alone: only the server's answer does", function()
		local rig = newRig()
		rig.handle.toggle()
		task.wait()
		expect(rig.sent[1]).toBe(true)
		expect(rig.ring().Visible).toBe(false)
		rig.pressKey(Enum.KeyCode.C, false)
		task.wait()
		expect(rig.ring().Visible).toBe(false)
	end)
end)

describe("TiptoeButton.start: sending", function()
	it("sends true when the button is clicked and Tiptoe is off", function()
		local rig = newRig()
		rig.setTiptoe(false)
		rig.handle.toggle()
		expect(#rig.sent).toBe(1)
		expect(rig.sent[1]).toBe(true)
	end)

	it("sends true when the button is clicked and the player has no Tiptoe attribute yet", function()
		local rig = newRig()
		rig.handle.toggle()
		expect(rig.sent[1]).toBe(true)
	end)

	it("sends false when the button is clicked and Tiptoe is on", function()
		local rig = newRig()
		rig.setTiptoe(true)
		rig.handle.toggle()
		expect(#rig.sent).toBe(1)
		expect(rig.sent[1]).toBe(false)
	end)

	it("sends the opposite of the server's answer each time, not of what it sent before", function()
		local rig = newRig()
		rig.handle.toggle() -- Tiptoe still off at the server: asks for on again
		rig.handle.toggle()
		expect(rig.sent[1]).toBe(true)
		expect(rig.sent[2]).toBe(true)
	end)

	it("sends true when C is pressed and Tiptoe is off", function()
		local rig = newRig()
		rig.pressKey(Enum.KeyCode.C, false)
		expect(#rig.sent).toBe(1)
		expect(rig.sent[1]).toBe(true)
	end)

	it("sends false when C is pressed and Tiptoe is on", function()
		local rig = newRig()
		rig.setTiptoe(true)
		rig.pressKey(Enum.KeyCode.C, false)
		expect(rig.sent[1]).toBe(false)
	end)

	it("does nothing for C while the player is typing in chat (gameProcessedEvent is true)", function()
		local rig = newRig()
		rig.pressKey(Enum.KeyCode.C, true)
		expect(#rig.sent).toBe(0)
	end)

	it("does nothing for any other key", function()
		local rig = newRig()
		rig.pressKey(Enum.KeyCode.V, false)
		rig.pressKey(Enum.KeyCode.E, false)
		rig.pressKey(Enum.KeyCode.Space, false)
		expect(#rig.sent).toBe(0)
	end)
end)

describe("TiptoeButton.start: cleanup", function()
	it("takes the button off the screen and stops listening when it is stopped", function()
		local rig = newRig()
		expect(rig.inputBegan:count()).toBe(1)
		rig.handle.stop()
		expect(rig.hud():FindFirstChild("Tiptoe")).toBeNil()
		expect(rig.inputBegan:count()).toBe(0)
		rig.pressKey(Enum.KeyCode.C, false)
		rig.attributes:SetAttribute("Tiptoe", true)
		task.wait()
		expect(#rig.sent).toBe(0)
	end)

	it("can be stopped twice without an error", function()
		local rig = newRig()
		rig.handle.stop()
		rig.handle.stop()
		expect(rig.inputBegan:count()).toBe(0)
	end)
end)

describe("TiptoeButton.glowTransparency", function()
	it("is 0.15 (15% see-through) when the glow starts and for the first 0.4 s", function()
		expect(TiptoeButton.glowTransparency(0)).toBe(0.15)
		expect(TiptoeButton.glowTransparency(0.2)).toBe(0.15)
		expect(TiptoeButton.glowTransparency(0.4)).toBe(0.15)
	end)

	it("fades evenly to fully see-through between 0.4 s and 1.2 s", function()
		expect(TiptoeButton.glowTransparency(0.8)).toBeCloseTo(0.575, 6)
		expect(TiptoeButton.glowTransparency(1.19)).toBeCloseTo(1, 1)
	end)

	it("is gone (nil) from 1.2 s on", function()
		expect(TiptoeButton.glowTransparency(1.2)).toBeNil()
		expect(TiptoeButton.glowTransparency(5)).toBeNil()
	end)
end)

describe("TiptoeButton.start: the orange glow of the 85 warning", function()
	it("is not there before a warning", function()
		local rig = newRig()
		expect(rig.glow().Visible).toBe(false)
		expect(rig.step:count()).toBe(0)
	end)

	it("lights up orange #FF8A3D, 10 px wide, 15% see-through, when 85 fires on a computer screen", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.warning:Fire(85)
		expect(rig.glow().Visible).toBe(true)
		local stroke = rig.glowStroke()
		expect(stroke.Thickness).toBe(10)
		expect(stroke.Color == Theme.warningOrange).toBe(true)
		expect(stroke.Color == Color3.fromHex("FF8A3D")).toBe(true)
		expect(stroke.Transparency).toBeCloseTo(0.15, 6)
	end)

	it("is 6 px wide on a phone screen", function()
		local rig = newRig(Vector2.new(750, 390))
		rig.warning:Fire(85)
		expect(rig.glowStroke().Thickness).toBe(6)
	end)

	it("is a round ring with no fill, the size of the button, drawn outside", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.warning:Fire(85)
		local glow = rig.glow()
		expect(glow.BackgroundTransparency).toBe(1)
		expect((glow:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toBe(UDim.new(0.5, 0))
		expect(glow.Size).toBe(UDim2.fromOffset(92, 92))
		expect(rig.glowStroke().ApplyStrokeMode).toBe(Enum.ApplyStrokeMode.Border)
	end)

	it("holds full strength at 0.4 s, fades after it, and is hidden at 1.2 s", function()
		local rig = newRig()
		rig.warning:Fire(85)
		rig.advance(0.4)
		expect(rig.glowStroke().Transparency).toBeCloseTo(0.15, 6)
		rig.advance(0.4)
		expect(rig.glowStroke().Transparency).toBeCloseTo(0.575, 6)
		expect(rig.glow().Visible).toBe(true)
		rig.advance(0.4)
		expect(rig.glow().Visible).toBe(false)
	end)

	it("sits behind the white on ring and behind the button", function()
		local rig = newRig()
		expect(rig.glow().ZIndex < rig.ring().ZIndex).toBe(true)
		expect(rig.glow().ZIndex < rig.button().ZIndex).toBe(true)
	end)

	it("starts again from full strength when a second 85 comes at 1.0 s", function()
		local rig = newRig()
		rig.warning:Fire(85)
		rig.advance(1)
		expect(rig.glowStroke().Transparency).toBeCloseTo(0.7875, 4)
		rig.warning:Fire(85)
		expect(rig.glowStroke().Transparency).toBeCloseTo(0.15, 6)
		rig.advance(0.4)
		expect(rig.glowStroke().Transparency).toBeCloseTo(0.15, 6)
		rig.advance(0.7)
		expect(rig.glow().Visible).toBe(true)
		rig.advance(0.2)
		expect(rig.glow().Visible).toBe(false)
	end)

	it("does nothing for a 60", function()
		local rig = newRig()
		rig.warning:Fire(60)
		expect(rig.glow().Visible).toBe(false)
		expect(rig.step:count()).toBe(0)
	end)

	it("listens to the frame step only while the glow plays", function()
		local rig = newRig()
		expect(rig.step:count()).toBe(0)
		rig.warning:Fire(85)
		expect(rig.step:count()).toBe(1)
		rig.warning:Fire(85)
		expect(rig.step:count()).toBe(1)
		rig.advance(1.2)
		expect(rig.step:count()).toBe(0)
	end)

	it("starts at the outer edge of the white on ring (7 px out) when Tiptoe is on, so both rings show", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.setTiptoe(true)
		rig.warning:Fire(85)
		expect(rig.glow().Size).toBe(UDim2.fromOffset(106, 106)) -- 92 + 2 x 7
		expect(rig.glowStroke().Thickness).toBe(10)
		-- the white ring's outer edge: its size plus its own thickness on each side
		local ring = rig.ring()
		local whiteOuter = ring.Size.X.Offset + 2 * 5
		expect(rig.glow().Size.X.Offset).toBe(whiteOuter)
	end)

	it("keeps the full 6 px orange ring outside the white one on a phone with Tiptoe on", function()
		local rig = newRig(Vector2.new(750, 390))
		rig.setTiptoe(true)
		rig.warning:Fire(85)
		expect(rig.glow().Size).toBe(UDim2.fromOffset(74, 74)) -- 60 + 2 x 7
		expect(rig.glowStroke().Thickness).toBe(6)
	end)

	it("moves back to the button edge when Tiptoe goes off during the glow, and out when it goes on", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.warning:Fire(85)
		expect(rig.glow().Size).toBe(UDim2.fromOffset(92, 92))
		rig.setTiptoe(true)
		expect(rig.glow().Size).toBe(UDim2.fromOffset(106, 106))
		rig.setTiptoe(false)
		expect(rig.glow().Size).toBe(UDim2.fromOffset(92, 92))
	end)

	it("takes the new size when the screen changes during the glow", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.warning:Fire(85)
		rig.setViewport(Vector2.new(750, 390))
		expect(rig.glow().Size).toBe(UDim2.fromOffset(60, 60))
		expect(rig.glowStroke().Thickness).toBe(6)
	end)

	it("is removed when stopped: nothing listens to the warning or the step any more", function()
		local rig = newRig()
		rig.warning:Fire(85)
		expect(rig.step:count()).toBe(1)
		rig.handle.stop()
		expect(rig.step:count()).toBe(0)
		expect(rig.warning:count()).toBe(0)
		expect(rig.hud():FindFirstChild("WarnGlow", true)).toBeNil()
	end)
end)
