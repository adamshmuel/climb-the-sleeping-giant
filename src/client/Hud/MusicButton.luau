--!strict
-- The music button (plan 7 Task 16; spec 7 Rule 98): a small round button beside Roblox's top-left buttons that turns the
-- music off and on. It sits in HudTop, which starts at the very top of the screen. The spot comes from Layout.musicButton:
-- beside Roblox's buttons, or under the first one when the sleep meter at its biggest would come within 8 px. It only
-- asks the music to switch; the sound itself is the music player's (Music.setOn).

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local MusicButton = {}

local NOTE = "🎵"
local NOTE_SHARE = 0.6 -- of the button's height
local NOTE_OFF_TRANSPARENCY = 0.5
local FAR_AWAY = math.huge -- where the meter is assumed to be before it has told its left edge
local BACKGROUND_TRANSPARENCY = 0.08
local RING_THICKNESS = 2
local SLASH_LENGTH_SHARE = 0.78 -- of the button's width
local SLASH_THICKNESS = 4
local SLASH_OUTLINE = 1
local SLASH_ROTATION = -45

export type TopbarRect = { minX: number, height: number }

export type Deps = {
	parent: Instance, -- the HudTop screen
	topbar: {
		get: () -> TopbarRect, -- GuiService.TopbarInset: Min.X and Height
		connect: (callback: () -> ()) -> () -> (), -- called when it changes; gives back the way to let go
	},
	hudLeft: () -> number, -- HudTop's own left edge (AbsolutePosition.X), taken off the inset's Min.X
	music: { setOn: (on: boolean) -> () },
	send: (on: boolean) -> (), -- tells the server the answer (the SetMusic remote), once per tap
	click: () -> (), -- plays the "Music button click" row
}

export type Handle = {
	toggle: () -> (), -- what a tap does
	setMeterLeft: (x: number) -> (), -- the meter's left edge at its biggest, from SleepMeterUi's onLayout
	stop: () -> (), -- takes the button off the screen; safe to call twice
}

function MusicButton.start(deps: Deps): Handle
	local leftOver = deps.parent:FindFirstChild("MusicButton")
	if leftOver then
		leftOver:Destroy() -- never two buttons
	end

	local button = Instance.new("TextButton")
	button.Name = "MusicButton"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.ink
	button.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	button.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	Ui.outline(button, Theme.white, RING_THICKNESS)

	local note = Ui.text("Note", button, NOTE, 1, Theme.white)
	note.Size = UDim2.fromScale(1, 1)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextYAlignment = Enum.TextYAlignment.Center

	local slash = Ui.panel("Slash", button, Theme.bannerRed, UDim.new(0, 0))
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Rotation = SLASH_ROTATION
	slash.Visible = false
	slash.ZIndex = 2
	Ui.outline(slash, Theme.ink, SLASH_OUTLINE)

	local on = true
	local meterLeft = FAR_AWAY

	local function place()
		local rect = deps.topbar.get()
		local edge = rect.minX - deps.hudLeft()
		local spot = Layout.musicButton(rect.height, edge, Layout.MUSIC_FIRST_LEFT, meterLeft)
		button.Position = UDim2.fromOffset(spot.x, spot.y)
		button.Size = UDim2.fromOffset(spot.size, spot.size)
		note.TextSize = math.round(NOTE_SHARE * spot.size)
		slash.Size = UDim2.fromOffset(math.round(SLASH_LENGTH_SHARE * spot.size), SLASH_THICKNESS)
	end

	local function paintLook()
		slash.Visible = not on
		note.TextTransparency = if on then 0 else NOTE_OFF_TRANSPARENCY
	end

	local function toggle()
		on = not on
		paintLook()
		deps.music.setOn(on)
		deps.send(on)
		deps.click()
	end

	place()
	paintLook()
	button.Parent = deps.parent
	local letGoOfTopbar: (() -> ())? = deps.topbar.connect(place)
	local activated: RBXScriptConnection? = button.Activated:Connect(toggle)

	local function setMeterLeft(x: number)
		meterLeft = x
		place()
	end

	local function stop()
		if letGoOfTopbar then
			letGoOfTopbar()
			letGoOfTopbar = nil
		end
		if activated then
			activated:Disconnect()
			activated = nil
		end
		button:Destroy()
	end

	return { toggle = toggle, setMeterLeft = setMeterLeft, stop = stop }
end

return MusicButton
