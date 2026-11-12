--!strict
-- The face when he wakes (spec Rule 66 and Rule 69): the "!" pops in beside his head, the Z Z Z bubble pops, and the
-- sound hooks play. The mouth and the head tip are in Pose; the sounds go to deps.playSound when it is set.

local Shared = require(script.Parent.Shared)
local Find = require(script.Parent.Find)

-- The "!" over its time since the wake: it grows from nothing to OVERSHOOT, settles to its own size, holds, then fades.
local OVERSHOOT = 1.15
local OVERSHOOT_AT = 0.15
local SETTLED_AT = 0.3
local FADE_START = 1.65
local FADE_END = 1.95
-- The bubble pop shows until this many seconds after the wake.
local POP_END = 0.4

local WakeFace = {}

export type Face = {
	-- He woke: the "!" and the pop start, and the wake sounds play.
	start: (now: number) -> (),
	-- Sets the "!" and the pop for `now`. Ends the face by itself at the end of the fade.
	update: (now: number) -> (),
	-- He lay down or the module stopped: plays LieDown when `lieDown` is true, and puts everything back at once.
	finish: (lieDown: boolean) -> (),
}

function WakeFace.new(state: Shared.State, deps: Shared.Deps, find: Find.Finders): Face
	local function play(name: string, at: Vector3?)
		local playSound = deps.playSound
		if playSound ~= nil then
			playSound(name, at)
		end
	end

	local function guis(): (BillboardGui?, BillboardGui?)
		local anchor = find.bang()
		local bang = find.child(anchor, "Bang")
		local zpop = find.child(anchor, "ZPop")
		return if bang ~= nil and bang:IsA("BillboardGui") then bang else nil,
			if zpop ~= nil and zpop:IsA("BillboardGui") then zpop else nil
	end

	-- Saves how the "!" looks the first time, so the fade and the pop can put it back.
	local function saveLook(bang: BillboardGui)
		local saved: UDim2? = state.faceSize[bang]
		if saved ~= nil then
			return
		end
		state.faceSize[bang] = bang.Size
		for _, piece in bang:GetDescendants() do
			if piece:IsA("GuiObject") then
				state.faceLook[piece] = piece.BackgroundTransparency
			elseif piece:IsA("UIStroke") then
				state.faceLook[piece] = piece.Transparency
			end
		end
	end

	-- `fade` of the way from each piece's own look to fully see-through (0 is its own look).
	local function paint(fade: number)
		for piece, look in state.faceLook do
			local value = look + (1 - look) * fade
			if piece:IsA("UIStroke") then
				piece.Transparency = value
			else
				(piece :: GuiObject).BackgroundTransparency = value
			end
		end
	end

	local function scaleAt(age: number): number
		if age < OVERSHOOT_AT then
			return OVERSHOOT * Shared.smooth(age / OVERSHOOT_AT)
		elseif age < SETTLED_AT then
			return OVERSHOOT + (1 - OVERSHOOT) * Shared.smooth((age - OVERSHOOT_AT) / (SETTLED_AT - OVERSHOOT_AT))
		end
		return 1
	end

	local function setScale(bang: BillboardGui, scale: number)
		local size: UDim2? = state.faceSize[bang]
		if size ~= nil then
			bang.Size =
				UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
		end
	end

	-- Everything off, every look and size as it was.
	local function putBack()
		state.faceAt = nil
		local bang, zpop = guis()
		if bang ~= nil then
			paint(0)
			local size: UDim2? = state.faceSize[bang]
			if size ~= nil then
				bang.Size = size
			end
			bang.Enabled = false
		end
		if zpop ~= nil then
			zpop.Enabled = false
		end
		table.clear(state.faceLook)
		table.clear(state.faceSize)
	end

	local function start(now: number)
		state.faceAt = now
		local bang, zpop = guis()
		if bang ~= nil then
			saveLook(bang)
			setScale(bang, 0)
			bang.Enabled = true
		end
		if zpop ~= nil then
			zpop.Enabled = true
		end
		play("WakeEyes", nil)
		play("WakeRoar", find.mouthAt())
		local anchor = find.bang()
		play("ZzzPop", if anchor ~= nil and anchor:IsA("BasePart") then anchor.Position else nil)
	end

	local function update(now: number)
		local at = state.faceAt
		if at == nil then
			return
		end
		local age = now - at
		local bang, zpop = guis()
		if zpop ~= nil and age >= POP_END then
			zpop.Enabled = false
		end
		if age >= FADE_END then
			putBack()
			return
		end
		if bang ~= nil then
			setScale(bang, scaleAt(age))
			paint(if age > FADE_START then (age - FADE_START) / (FADE_END - FADE_START) else 0)
		end
	end

	local function finish(lieDown: boolean)
		putBack()
		if lieDown then
			play("LieDown", find.mouthAt())
		end
	end

	return { start = start, update = update, finish = finish }
end

return WakeFace
