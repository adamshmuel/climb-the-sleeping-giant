--!strict
-- The look of the screen: colours, font and the meter's looks. The values are copied from the style guide
-- (docs/design/climb-the-sleeping-giant/style-guide.md) and the mockup core-hud.html, so they match it exactly.

local Theme = {}

-- Palette
Theme.ink = Color3.fromHex("2B2340") -- every outline
Theme.cream = Color3.fromHex("FFF6E4")
Theme.sleepBlueDark = Color3.fromHex("2F3B8F") -- the words on the meter
Theme.sleepBlue = Color3.fromHex("4A5BC4") -- the Tiptoe button
Theme.sleepBlueLight = Color3.fromHex("8F9CF0") -- the top of the Tiptoe button
Theme.track = Color3.fromHex("2F2A4A") -- the empty part of the bar
Theme.white = Color3.new(1, 1, 1)

Theme.gold = Color3.fromHex("FFE27A") -- "Grab" in the grab prompt
Theme.warningOrange = Color3.fromHex("FF8A3D") -- the glow round the Tiptoe button at the 85% warning

-- Fredoka One for everything.
Theme.font = Font.fromEnum(Enum.Font.FredokaOne)

-- The colours of each meter row: the panel behind the words and the words.
export type RowLook = {
	panel: Color3,
	label: Color3,
}

Theme.rows = {
	Sleeping = { panel = Theme.cream, label = Theme.sleepBlueDark },
	Stirring = { panel = Theme.cream, label = Theme.sleepBlueDark },
	WakingUp = { panel = Color3.fromHex("FFE9D6"), label = Color3.fromHex("D8651A") }, -- peach and orange
	Awake = { panel = Color3.fromHex("FFE3E6"), label = Color3.fromHex("C4142A") },
	HeavySleep = { panel = Color3.fromHex("E3E8FF"), label = Theme.sleepBlueDark },
} :: { [string]: RowLook } -- by MeterView.Row

-- The two blues of the Heavy Sleep stripes: the bar itself is the dark one.
Theme.stripeLight = Color3.fromHex("6F80E8")
Theme.stripeDark = Color3.fromHex("5466D6")

-- How each bar style is painted.
--  `color`: the bar's own colour (white when a gradient paints it).
--  `gradient`: colours across the bar, or nil for one solid colour.
--  `reveal`: the gradient is drawn over the whole bar and the fill uncovers part of it, so green stays at the
--            start and yellow only shows when the meter nears 60 (like the mockup).
--  `stripes`: slanted stripes of Theme.stripeLight are drawn over the bar's own colour.
export type BarPaint = {
	color: Color3,
	gradient: ColorSequence?,
	reveal: boolean,
	stripes: boolean,
}

Theme.bars = {
	GreenToYellow = {
		color = Theme.white,
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("6EE07A")),
			ColorSequenceKeypoint.new(0.6, Color3.fromHex("FFE066")),
			ColorSequenceKeypoint.new(0.85, Color3.fromHex("FF8A3D")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("FF3B4E")),
		}),
		reveal = true,
		stripes = false,
	},
	Yellow = { color = Color3.fromHex("FFE066"), gradient = nil, reveal = false, stripes = false },
	Orange = {
		color = Theme.white,
		gradient = ColorSequence.new(Color3.fromHex("FFB25C"), Color3.fromHex("FF8A3D")),
		reveal = false,
		stripes = false,
	},
	Red = { color = Color3.fromHex("FF3B4E"), gradient = nil, reveal = false, stripes = false },
	BlueStripes = { color = Theme.stripeDark, gradient = nil, reveal = false, stripes = true },
} :: { [string]: BarPaint } -- by MeterView.BarStyle

-- The Tiptoe button's fill: light at the top, darker towards the bottom (core-hud.html, .btn).
Theme.tiptoeGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.sleepBlueLight),
	ColorSequenceKeypoint.new(0.55, Theme.sleepBlue),
	ColorSequenceKeypoint.new(1, Theme.sleepBlueDark),
})

-- Eggs: a highlight, the main colour and a shade, from the mockups' egg pictures (core-hud.html, hud.html). The main
-- colour is the rarity's colour from the style guide (Common cream white, Uncommon leaf green, Rare sky blue).
export type RarityLook = {
	light: Color3,
	main: Color3,
	dark: Color3,
}

Theme.rarity = {
	Common = { light = Color3.fromHex("FFFFFF"), main = Color3.fromHex("EDE6D6"), dark = Color3.fromHex("BFB49C") },
	Uncommon = { light = Color3.fromHex("C8F7BE"), main = Color3.fromHex("5BD45B"), dark = Color3.fromHex("2E9E3A") },
	Rare = { light = Color3.fromHex("CDEBFF"), main = Color3.fromHex("3FA9FF"), dark = Color3.fromHex("1F78D1") },
} :: { [string]: RarityLook } -- by rarity name

-- The dark, see-through plates behind the grab prompt, the carry pill and the tips (core-hud.html, hud.html).
Theme.promptTransparency = 0.15 -- the grab prompt and the carry pill are 85% solid
Theme.tipTransparency = 0.18 -- the bottom tips are 82% solid

-- The green safe-home card: light at the top, darker towards the bottom (core-hud.html, .msg.green: #A6F29A, then
-- --leaf at 55%, then --leaf-d).
Theme.cardGreenLight = Color3.fromHex("A6F29A")
Theme.cardGreen = Color3.fromHex("5BD45B")
Theme.cardGreenDark = Color3.fromHex("2E9E3A")
Theme.cardGreenMainAt = 0.55

-- The red wake banner: light at the top, darker towards the bottom (hud.html, .banner.red: #FF7A86, then --wake at 55%,
-- then --wake-d).
Theme.bannerRedLight = Color3.fromHex("FF7A86")
Theme.bannerRed = Color3.fromHex("FF3B4E")
Theme.bannerRedDark = Color3.fromHex("C4142A")
Theme.bannerRedMainAt = 0.55

-- The slam circle on the ground (style guide, "The slams"): small pieces that hug the surface under it (see SlamCircle),
-- red with a 1.5-stud gold rim. The red is its own deeper red, not the banner's: the pieces are Neon, so the blue lights of
-- the Rare eggs can't wash it out.
Theme.slamGold = Color3.fromHex("FFC93C")
Theme.slamRed = Color3.fromHex("E0233A")

-- The white marks on the bar at 60% and 85%.
Theme.tickColor = Color3.new(1, 1, 1)
Theme.tickTransparency = 0.2

return Theme
