--!strict
-- Decides whether the phone grab pill follows the egg or is pinned to a fixed place on the screen (Task 56).
-- Pure maths on boxes: no Roblox services.

export type Box = { left: number, top: number, right: number, bottom: number }
export type State = "following" | "pinned"
export type Input = {
	touch: boolean,
	pressed: boolean,
	current: State,
	-- The box the pill would have if it followed the egg, or nil when the egg's point is behind the camera.
	box: Box?,
	safe: Box,
}

local Layout = require(script.Parent.Layout)

local PIN_LINE = Layout.pin.pinLine
local UNPIN_LINE = Layout.pin.unpinLine
local PINNED_BOTTOM_GAP = Layout.pin.bottomGap

local PillPin = {}

local function isInside(box: Box, safe: Box): boolean
	return box.left >= safe.left and box.right <= safe.right and box.top >= safe.top
end

function PillPin.decide(input: Input): State
	local current = input.current
	-- A computer keeps the following pill, and a held pill never moves under the finger.
	if not input.touch then
		return "following"
	end
	if input.pressed then
		return current
	end
	local box = input.box
	if box == nil then
		return "pinned"
	end
	local safe = input.safe
	if not isInside(box, safe) or box.bottom > safe.bottom - PIN_LINE then
		return "pinned"
	end
	if box.bottom <= safe.bottom - UNPIN_LINE then
		return "following"
	end
	return current
end

function PillPin.pinnedBox(safe: Box, width: number, height: number): Box
	local left = (safe.left + safe.right) / 2
	local bottom = safe.bottom - PINNED_BOTTOM_GAP
	return { left = left, top = bottom - height, right = left + width, bottom = bottom }
end

return PillPin
