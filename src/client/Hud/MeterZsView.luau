--!strict
-- The Z Z Z on the sleep meter (plan 3 Task 8f, style guide meter-zs.md): where the three letters go and how they
-- look in each state. Pure: it does maths on the sizes it is given and builds no instances.

local Layout = require(script.Parent.Layout)

local MeterZsView = {}

-- meter-zs.md, "Motion": each Z rises about 8 points, so the letters keep this much room above them.
MeterZsView.RISE_POINTS = 8

-- The three looks of the world's Z Z Z, plus Heavy Sleep. `hidden` is the 85% warning and when he is awake.
export type Sign = "shown" | "faded" | "hidden" | "heavy"

export type Look = {
	visible: boolean,
	transparency: number, -- 0 is solid, 0.5 is half see-through
	heavy: boolean, -- Heavy Sleep: the bigger letters, rising faster
	riseSeconds: number, -- how long one Z takes to rise and fade out
}

-- One letter's place on the safe area, in points. `x` and `y` are the corner of its text box (TextSize on each
-- side); `height` is the letter's own height; `letterTop` is where the letter itself starts, under that corner.
export type Box = {
	x: number,
	y: number,
	textSize: number,
	height: number,
	letterTop: number,
}

local CALM_RISE_SECONDS = 2 -- meter-zs.md, "Motion"
local HEAVY_RISE_SECONDS = 1.4 -- meter-zs.md, "Heavy Sleep"
local FADED_TRANSPARENCY = 0.5 -- meter-zs.md, "60-84 (stirring)": 50% see-through

local LOOKS: { [Sign]: Look } = {
	shown = { visible = true, transparency = 0, heavy = false, riseSeconds = CALM_RISE_SECONDS },
	faded = { visible = true, transparency = FADED_TRANSPARENCY, heavy = false, riseSeconds = CALM_RISE_SECONDS },
	hidden = { visible = false, transparency = 1, heavy = false, riseSeconds = CALM_RISE_SECONDS },
	heavy = { visible = true, transparency = 0, heavy = true, riseSeconds = HEAVY_RISE_SECONDS },
}

for _, look in LOOKS do
	table.freeze(look)
end
table.freeze(LOOKS)

-- What the Zs show for a sign.
function MeterZsView.look(sign: Sign): Look
	return LOOKS[sign]
end

-- The three letters' boxes for a screen. `meterRight` is the meter's right edge across the safe area (the Zs
-- start there), and the meter's top is `screen.meter.topOffset`. The letter's text is centred in its box.
function MeterZsView.boxes(screen: Layout.Screen, meterRight: number, heavy: boolean): { Box }
	local zs = screen.zs
	local meterTop = screen.meter.topOffset
	local boxes: { Box } = {}
	local row: { Layout.ZLetter } = if heavy then zs.heavy else zs.calm
	for _, letter in row do
		local textSize = letter.height / zs.letterPerTextSize
		local y = meterTop + letter.dy
		table.insert(boxes, {
			x = meterRight + letter.dx,
			y = y,
			textSize = textSize,
			height = letter.height,
			letterTop = y + (textSize - letter.height) / 2,
		})
	end
	return boxes
end

return MeterZsView
