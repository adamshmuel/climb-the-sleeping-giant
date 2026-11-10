--!strict
-- The Z Z Z on the sleep meter (plan 3 Task 8f, style guide meter-zs.md), built on the Hud screen at the meter's
-- right end. Where they go and how they look is MeterZsView; this builds the three letters, moves them into place
-- and plays the snore: each Z rises a little and fades out, one after another. With Reduce Motion on they stand still.

local TweenService = game:GetService("TweenService")

local Layout = require(script.Parent.Layout)
local MeterZsView = require(script.Parent.MeterZsView)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local MeterZs = {}

-- Room round each letter so its edge and its drop are not cut off by the group they are drawn in.
MeterZs.padding = 12

local LETTERS = 3
local RISE_POINTS = 8 -- meter-zs.md, "Motion": each Z rises about 8 points
local START_GAP_SECONDS = 0.6 -- the three start 0.6 s apart

export type Deps = {
	reducedMotion: () -> boolean, -- GuiService.ReducedMotionEnabled
	play: ((target: Instance, info: TweenInfo, goals: { [string]: any }) -> () -> ())?, -- plays a tween; returns its cancel
	delay: ((seconds: number, callback: () -> ()) -> () -> ())?, -- runs later; returns its cancel
}

export type Handle = {
	setLook: (look: MeterZsView.Look) -> (),
	place: (screen: Layout.Screen, meterRight: number) -> (),
	destroy: () -> (),
}

-- Plays a real tween.
local function playTween(target: Instance, info: TweenInfo, goals: { [string]: any }): () -> ()
	local tween = TweenService:Create(target, info, goals)
	tween:Play()
	return function()
		tween:Cancel()
		tween:Destroy()
	end
end

-- Runs the callback after the wait.
local function delayCall(seconds: number, callback: () -> ()): () -> ()
	local thread = task.delay(seconds, callback)
	return function()
		pcall(task.cancel, thread)
	end
end

type Letter = {
	group: CanvasGroup,
	letter: TextLabel,
	drop: TextLabel,
	basePosition: UDim2,
}

-- One white Z with a Sleep-blue edge and an Ink copy 3 points below it, drawn in a group that fades as one.
local function buildLetter(parent: Instance, index: number): Letter
	local pad = MeterZs.padding
	local group = Instance.new("CanvasGroup")
	group.Name = `Z{index}`
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.Visible = false
	group.Parent = parent

	local function text(name: string, color: Color3, edge: Color3, zIndex: number): TextLabel
		local label = Ui.text(name, group, "Z", 1, color)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.ZIndex = zIndex
		local stroke = Instance.new("UIStroke")
		stroke.Color = edge
		stroke.Parent = label
		return label
	end
	local drop = text("Drop", Theme.ink, Theme.ink, 1)
	local letter = text("Letter", Theme.white, Theme.sleepBlueDark, 2)
	drop.Position = UDim2.fromOffset(pad, pad)
	letter.Position = UDim2.fromOffset(pad, pad)
	return { group = group, letter = letter, drop = drop, basePosition = UDim2.new() }
end

function MeterZs.new(gui: ScreenGui, deps: Deps): Handle
	local play: (Instance, TweenInfo, { [string]: any }) -> () -> () = deps.play or playTween
	local delay: (number, () -> ()) -> () -> () = deps.delay or delayCall

	local frame = Ui.group("MeterZs", gui)
	frame.Size = UDim2.fromScale(1, 1)
	local letters: { Letter } = {}
	for index = 1, LETTERS do
		table.insert(letters, buildLetter(frame, index))
	end

	local screen: Layout.Screen? = nil
	local meterRight = 0
	local current: MeterZsView.Look? = nil
	local cancels: { () -> () } = {}

	local function cancelAll()
		local running = cancels
		cancels = {}
		for _, cancel in running do
			cancel()
		end
	end

	-- Moves and sizes the three letters for the look (Heavy Sleep has bigger ones).
	local function arrange(look: MeterZsView.Look)
		if screen == nil then
			return
		end
		local pad = MeterZs.padding
		local zs = screen.zs
		for index, box in MeterZsView.boxes(screen, meterRight, look.heavy) do
			local entry = letters[index]
			local full = box.textSize + 2 * pad
			entry.group.Size = UDim2.fromOffset(full, full)
			entry.group.Rotation = zs.tilt
			entry.basePosition = UDim2.fromOffset(box.x - pad, box.y - pad)
			entry.group.Position = entry.basePosition
			entry.letter.TextSize = math.round(box.textSize) -- TextSize is a whole number
			entry.letter.Size = UDim2.fromOffset(box.textSize, box.textSize)
			entry.drop.TextSize = math.round(box.textSize)
			entry.drop.Size = UDim2.fromOffset(box.textSize, box.textSize)
			entry.drop.Position = UDim2.fromOffset(pad, pad + zs.dropOffset);
			(entry.letter:FindFirstChildWhichIsA("UIStroke") :: UIStroke).Thickness = zs.strokeThickness;
			(entry.drop:FindFirstChildWhichIsA("UIStroke") :: UIStroke).Thickness = zs.strokeThickness
		end
	end

	-- One Z rises and fades out, again and again.
	local function rise(entry: Letter, look: MeterZsView.Look)
		entry.group.Position = entry.basePosition
		entry.group.GroupTransparency = look.transparency
		local info = TweenInfo.new(look.riseSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
		local goals = {
			Position = entry.basePosition - UDim2.fromOffset(0, RISE_POINTS),
			GroupTransparency = 1,
		}
		table.insert(cancels, play(entry.group, info, goals))
	end

	local function setLook(look: MeterZsView.Look)
		cancelAll()
		current = look
		for _, entry in letters do
			entry.group.Visible = look.visible
		end
		if not look.visible then
			return
		end
		arrange(look)
		local moving = not deps.reducedMotion()
		for index, entry in letters do
			entry.group.Position = entry.basePosition
			entry.group.GroupTransparency = look.transparency
			if moving then
				if index == 1 then
					rise(entry, look)
				else
					entry.group.GroupTransparency = 1 -- waits its turn, unseen
					table.insert(
						cancels,
						delay((index - 1) * START_GAP_SECONDS, function()
							rise(entry, look)
						end)
					)
				end
			end
		end
	end

	return {
		setLook = setLook,
		place = function(newScreen: Layout.Screen, newMeterRight: number)
			screen = newScreen
			meterRight = newMeterRight
			if current ~= nil then
				setLook(current)
			end
		end,
		destroy = function()
			cancelAll()
			frame:Destroy()
		end,
	}
end

return MeterZs
