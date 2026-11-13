--!strict
-- The Z Z Z sign and the snore puffs: turning them on and off, painting the letters, the Heavy Sleep size and the snort bursts.

local Shared = require(script.Parent.Shared)
local Motion = require(script.Parent.Motion)
local Find = require(script.Parent.Find)

local smooth = Shared.smooth

-- How big the Z Z Z sign is, from 0 (its normal size) to 1 (full Heavy Sleep size), `seconds` after Heavy Sleep ended.
local function heavyLetterShare(seconds: number): number
	return 1 - smooth(seconds / Shared.heavyShrinkSeconds)
end

-- The size and the StudsOffset of a sign that normally has `size` and `offset`, `share` of the way to the Heavy Sleep
-- size. Both parts of the size grow (the studs and the pixels), and the offset moves so that the fixed corner stays
-- where it was: the sign's middle moves half of the growth away from that corner. Only the studs count for that.
local function heavySign(size: UDim2, offset: Vector3, share: number): (UDim2, Vector3)
	if share <= 0 then
		return size, offset
	end
	local factor = 1 + (Shared.heavyLetterScale - 1) * share
	local grown =
		UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
	local corner = Shared.heavyFixedCorner
	local moveX = -corner.X * (grown.X.Scale - size.X.Scale) / 2
	local moveY = -corner.Y * (grown.Y.Scale - size.Y.Scale) / 2
	return grown, offset + Vector3.new(moveX, moveY, 0)
end

-- A puff size curve with every value and every envelope (the random spread) `scale` times bigger.
local function scaledPuffSize(sequence: NumberSequence, scale: number): NumberSequence
	local keypoints: { NumberSequenceKeypoint } = {}
	for _, keypoint in sequence.Keypoints do
		table.insert(
			keypoints,
			NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale)
		)
	end
	return NumberSequence.new(keypoints)
end

local SleepSigns = {}

function SleepSigns.new(state: Shared.State, deps: Shared.Deps, find: Find.Finders)
	-- Turns something on or off, remembering how it was before.
	local function setEnabled(target: Instance, on: boolean)
		local piece: any = target
		if state.startEnabled[target] == nil then
			state.startEnabled[target] = piece.Enabled
		end
		piece.Enabled = on
	end

	local function restoreEnabled(target: Instance?)
		local was: boolean? = if target ~= nil then state.startEnabled[target] else nil
		if target ~= nil and was ~= nil then
			local piece: any = target
			piece.Enabled = was
		end
	end

	-- Every Z letter with its outline, and the transparencies they normally have (saved the first time).
	local function letters(): { { label: TextLabel, outline: UIStroke? } }
		local found: { { label: TextLabel, outline: UIStroke? } } = {}
		local sign = find.floatingZ()
		if sign == nil then
			return found
		end
		for _, label in sign:GetChildren() do
			if label:IsA("TextLabel") then
				if state.startLetter[label] == nil then
					state.startLetter[label] = label.TextTransparency
				end
				local outline = label:FindFirstChildOfClass("UIStroke")
				if outline ~= nil and state.startOutline[outline] == nil then
					state.startOutline[outline] = outline.Transparency
				end
				table.insert(found, { label = label, outline = outline })
			end
		end
		return found
	end

	-- Paints every letter and outline `seconds` into the fade, or back to normal when `seconds` is nil.
	local function paintLetters(seconds: number?)
		for _, letter in letters() do
			local normal = state.startLetter[letter.label]
			letter.label.TextTransparency = if seconds == nil then normal else Motion.fadedTransparency(normal, seconds)
			local outline = letter.outline
			if outline ~= nil then
				local normalOutline = state.startOutline[outline]
				outline.Transparency = if seconds == nil
					then normalOutline
					else Motion.fadedTransparency(normalOutline, seconds)
			end
		end
	end

	-- Paints every letter and outline `seconds` into the fade-in after a replay, or back to normal when `seconds` is nil.
	local function paintFadeIn(seconds: number?)
		for _, letter in letters() do
			local normal = state.startLetter[letter.label]
			letter.label.TextTransparency = if seconds == nil
				then normal
				else Motion.fadedInTransparency(normal, seconds)
			local outline = letter.outline
			if outline ~= nil then
				local normalOutline = state.startOutline[outline]
				outline.Transparency = if seconds == nil
					then normalOutline
					else Motion.fadedInTransparency(normalOutline, seconds)
			end
		end
	end

	-- How big the sign is now: 1 in Heavy Sleep, falling to 0 over the shrink after it, then 0.
	local function letterShare(now: number): number
		if state.heavy then
			return 1
		elseif state.shrinkAt ~= nil then
			return heavyLetterShare(now - state.shrinkAt)
		end
		return 0
	end

	-- Sizes the Z Z Z sign for `now`, from the size it had before Heavy Sleep touched it (saved the first time). A sign
	-- that was never touched and has nothing to change is left alone.
	local function placeSign(now: number)
		local sign = find.floatingZ()
		if sign == nil then
			return
		end
		local share = letterShare(now)
		local oldSize: UDim2? = state.startSignSize[sign]
		local oldOffset: Vector3? = state.startSignOffset[sign]
		local savedSize: UDim2 = if oldSize ~= nil then oldSize else sign.Size
		local savedOffset: Vector3 = if oldOffset ~= nil then oldOffset else sign.StudsOffset
		if oldSize == nil or oldOffset == nil then
			if share <= 0 then
				return
			end
			state.startSignSize[sign] = savedSize
			state.startSignOffset[sign] = savedOffset
		end
		sign.Size, sign.StudsOffset = heavySign(savedSize, savedOffset, share)
	end

	-- Gives the puff its Heavy Sleep rate and size, or its saved ones. The puffs change at once, not over time.
	local function placePuff()
		local puff = find.snorePuff()
		if puff == nil then
			return
		end
		if state.startRate[puff] == nil then
			if not state.heavy then
				return
			end
			state.startRate[puff] = puff.Rate
			state.startPuffSize[puff] = puff.Size
		end
		if state.heavy then
			puff.Rate = state.startRate[puff] * Shared.heavyPuffRateScale
			puff.Size = scaledPuffSize(state.startPuffSize[puff], Shared.heavyPuffSizeScale)
		else
			puff.Rate = state.startRate[puff]
			puff.Size = state.startPuffSize[puff]
		end
	end

	-- One snort burst, from the nose as it is now: it streams in and out on a player's device, so it is looked up each
	-- time, and a burst is skipped (with no error) while it isn't there.
	local function snortBurst()
		local emitter = find.snortPuff()
		if emitter == nil then
			return
		end
		if deps.burst ~= nil then
			deps.burst(emitter, Shared.snortPuffs)
		else
			emitter:Emit(Shared.snortPuffs)
		end
	end

	-- Clears the snort cloud at once, from the nose as it is now (skipped, with no error, while it isn't there). The
	-- puffs of a burst live about 2.3 seconds, so at a wake they would still cover his open eyes.
	local function clearSnort()
		local emitter = find.snortPuff()
		if emitter == nil then
			return
		end
		if deps.clear ~= nil then
			deps.clear(emitter)
		else
			emitter:Clear()
		end
	end

	return {
		setEnabled = setEnabled,
		restoreEnabled = restoreEnabled,
		letters = letters,
		paintLetters = paintLetters,
		paintFadeIn = paintFadeIn,
		placeSign = placeSign,
		placePuff = placePuff,
		snortBurst = snortBurst,
		clearSnort = clearSnort,
	}
end

return SleepSigns
