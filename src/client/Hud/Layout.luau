--!strict
-- Picks the computer or the phone sizes for the screen (spec section 6, "Phone sizes"). Pure: it only does maths
-- on the screen size it is given, so a test can pass any size.

local Layout = {}

-- A screen whose short side is under this many pixels is a phone (Studio's iPhone 14 simulator gives 390).
local PHONE_SHORT_SIDE = 500

-- Roblox's Jump button column on a phone: pixels from the right edge of the safe area to the column's left edge
-- (style guide wake-up.md, "Wake banner on phones"). The phone wake banner ends `banner.jumpGap` left of it. 138 is the
-- style guide's design value (the designer owns it), not a measurement: in Play the real Jump button sits 95 px from the
-- right edge.
Layout.jumpColumn = 138

-- The red edges while he hunts (style guide wake-up.md, "Red edges"; spec 6 Rule 68). Every size is a fraction of the screen.
--  `depth`: how deep each band is, as a fraction of the screen height, on every edge (the side bands use RelativeYY).
--  `phoneSideHeight`: the side bands on a phone stop this far down, 45% above the bottom, so the thumbstick and Jump button
--                     corners get no red.
--  `phoneBottomFrom`, `phoneBottomTo`: the phone's bottom band covers only the middle, 28% to 72% of the width.
--  `fadeSeconds`: the time to fade fully in or out.  `pulseSeconds`: one pulse, full strength to 40% and back.
--  `displayOrder`: below the Hud and HudTop screens (0), so every button and pill is drawn over the red.
Layout.redEdges = table.freeze({
	depth = 0.14,
	phoneSideHeight = 0.55,
	phoneBottomFrom = 0.28,
	phoneBottomTo = 0.72,
	-- Phone only: each faded end is `stripCount` strips (designer ruling, style guide wake-up.md "Red edges on phones").
	-- The side bands fade over their last `sideFadeShare` of the length, the bottom band over the first and the last
	-- `bottomFadeShare` of its width.
	stripCount = 4,
	sideFadeShare = 0.2,
	bottomFadeShare = 0.25,
	fadeSeconds = 0.5,
	pulseSeconds = 1,
	displayOrder = -1,
})

-- A phone shows a name on the wake banner up to this many letters whole; a longer one is cut to one letter fewer and an
-- ellipsis, so the banner stays on one line, left of the Jump column.
Layout.phoneNameLetters = 12

-- Where the phone grab pill leaves the egg and sits at a fixed spot (Task 56). The two lines are pixels above the
-- safe area's bottom: the pill pins when its box is lower than the first, and follows the egg again only above the
-- second. The 20 px between them stops it flickering. A pinned pill's bottom edge sits `bottomGap` above the bottom.
Layout.pin = table.freeze({
	pinLine = 64,
	unpinLine = 84,
	bottomGap = 12,
})

export type Meter = {
	width: number,
	height: number,
	topOffset: number, -- pixels from the top of the safe area to the meter
	borderThickness: number, -- the Ink outline around the meter
	shadowOffset: number, -- how far the Ink shadow shows under the meter
	padding: number, -- space between the meter's edge and its face and bar
	gap: number, -- space between the face and the words and bar
	rowGap: number, -- space between the words and the bar
	faceTextSize: number,
	labelTextSize: number,
	lockTextSize: number,
	barHeight: number, -- the whole bar, outline included
	barStrokeThickness: number,
	tickWidth: number, -- the white marks at 60 and 85
	stripePeriod: number, -- pixels from one Heavy Sleep stripe to the next
}

-- The round Tiptoe button on the right side of the screen.
export type Tiptoe = {
	diameter: number, -- the whole button, outline included
	borderThickness: number, -- the Ink outline
	shadowOffset: number, -- how far the Ink shadow shows under the button
	emojiTextSize: number, -- the foot
	wordTextSize: number, -- "Tiptoe"
	keyTextSize: number, -- the key letter
	showKey: boolean, -- computers show the key "C", phones have no keyboard
	onThickness: number, -- the white ring that shows Tiptoe is on
	onGap: number, -- space between the button's outline and that ring
	glowThickness: number, -- the orange ring of the 85% warning
	rightMargin: number, -- pixels from the right edge of the safe area
}

-- The "Hold to Grab" prompt that floats next to an egg: a round key (or a hand on touch screens) and the words.
export type Prompt = {
	keyDiameter: number, -- the white round key
	keyTextSize: number, -- the letter or the hand inside it
	textSize: number, -- "Hold to Grab"
	textOutline: number, -- the Ink outline around the words, so they read over the fill
	borderThickness: number, -- the white outline around the prompt
	cornerRadius: number,
	paddingLeft: number,
	paddingRight: number,
	paddingY: number,
	gap: number, -- space between the key and the words
	billboardWidth: number, -- the room the prompt floats in; the prompt itself is centred in it
	billboardHeight: number,
}

-- The carry pill at the bottom centre: the egg's picture, "[Rarity] egg! Get it home" and the little house.
export type Pill = {
	bottomOffset: number, -- pixels from the bottom of the safe area
	paddingLeft: number,
	paddingRight: number,
	paddingY: number,
	gap: number,
	borderThickness: number, -- the Ink outline around the pill
	textSize: number,
	textOutline: number, -- the Ink outline around the words
	eggWidth: number,
	eggHeight: number,
	eggBorderThickness: number,
	homeTextSize: number, -- the little house
}

-- A short tip at the bottom centre ("Someone else got it!"), in the same place as the carry pill.
export type Tip = {
	bottomOffset: number,
	paddingX: number,
	paddingY: number,
	borderThickness: number,
	textSize: number,
	textOutline: number,
	circleSize: number, -- the no-egg tip's red circle icon, across (the carrier's egg icon is the pill's)
	circleRim: number, -- the circle's gold rim, inside its edge
	circleRing: number, -- the circle's Ink ring, outside its edge
	circleGap: number, -- between the circle and the words
}

-- The green card under the meter ("Safe! Common egg is home"): the egg's picture and the words, on a green plate.
export type Card = {
	top: number, -- pixels from the top of the safe area to the card's outer edge (outline included)
	paddingLeft: number,
	paddingRight: number,
	paddingY: number,
	gap: number, -- space between the egg and the words
	borderThickness: number, -- the Ink outline around the card
	shadowOffset: number, -- how far the Ink shadow shows under the card
	cornerRadius: number,
	textSize: number,
	textOutline: number, -- the Ink outline around the words
	eggWidth: number,
	eggHeight: number,
	eggBorderThickness: number,
}

-- The red wake banner ("Leo woke the Giant!"). On every screen it stands low and right of centre (on the Hud screen), so
-- it never covers his face or the red slam circles. It is one line on every screen. A phone pins its right edge left of
-- the Jump column.
export type Banner = {
	bottomOffset: number, -- pixels from the bottom of the safe area to the banner's outer edge (outline included)
	centerX: number, -- where the banner's middle is, across the screen: 0.5 is the middle, 0.66 is two thirds of the way
	paddingX: number,
	paddingY: number,
	gap: number, -- space between the 💥 and the words
	secondGap: number, -- space between the words and the second line
	showSecondLine: boolean, -- false on every screen: the banner is one line (the words under it live in the bottom tip)
	jumpGap: number?, -- phone only: the banner's right edge stands this many pixels left of the Jump column (nil: no pin)
	nameLetters: number?, -- phone only: a name over this many letters is cut (nil: never cut)
	borderThickness: number, -- the Ink outline around the banner
	shadowOffset: number, -- how far the Ink shadow shows under the banner
	cornerRadius: number,
	rotation: number, -- the banner is turned this many degrees (negative: the right side is higher)
	textSize: number, -- the words, and the 💥
	textOutline: number, -- the Ink outline around the words
	secondTextSize: number,
	secondTextOutline: number,
}

-- The cream "Caught!" card at the bottom: the 💫, the words and a smaller second line under them. It is the cream message of
-- the mockup (core-hud.html: .msg.cream, in its "caught" state), low and left of centre on a computer and bottom centre
-- on a phone, so his face stays clear.
export type Caught = {
	bottomOffset: number, -- pixels from the bottom of the safe area to the card's outer edge (outline included)
	centerX: number, -- where the card's middle is, across the screen: 0.5 is the middle, 0.3 is 30% of the way
	paddingLeft: number,
	paddingRight: number,
	paddingY: number,
	gap: number, -- space between the 💫 and the words
	borderThickness: number, -- the Ink outline around the card
	shadowOffset: number, -- how far the Ink shadow shows under the card
	cornerRadius: number,
	emojiTextSize: number, -- the 💫
	textSize: number, -- "Caught!"
	secondTextSize: number, -- "The egg went back. You lost nothing else."
}

-- The red "RUN HOME!" pill at the top, right of the sleep meter (style guide wake-up.md, "RUN HOME!" and "Where RUN HOME!
-- sits"; mockup wake-hud.html: #runhome). Sizes in pixels; the pill is a fixed size so its box is known without drawing it.
export type RunHomePill = {
	width: number,
	height: number,
	leftGap: number, -- from the meter's right edge to the pill's left edge
	topOffset: number, -- from the top of the screen to the pill's top edge
	borderThickness: number, -- the Ink outline
	shadowOffset: number, -- how far the Ink shadow shows under the pill
	textSize: number, -- "RUN HOME!"
	textOutline: number, -- the Ink outline round the words
	emojiTextSize: number, -- the runner picture
	gap: number, -- between the picture and the words
	tilt: number, -- degrees (negative: the right side is higher)
}

-- One Z of the Z Z Z on the sleep meter (style guide: meter-zs.md). `dx` and `dy` are points from the meter's right
-- edge and its top edge to the corner of the letter's text box; `height` is the letter's own height.
export type ZLetter = {
	dx: number,
	dy: number,
	height: number,
}

export type Zs = {
	calm: { ZLetter },
	heavy: { ZLetter }, -- Heavy Sleep: bigger, same place
	letterPerTextSize: number, -- a letter is this much of its TextSize tall (TextSize = height / 0.74)
	strokeThickness: number, -- the Sleep-blue edge
	dropOffset: number, -- how far below the Ink copy sits
	tilt: number, -- degrees each letter is turned
}

export type Screen = {
	phone: boolean,
	meter: Meter,
	tiptoe: Tiptoe,
	prompt: Prompt,
	pill: Pill,
	tip: Tip,
	card: Card,
	banner: Banner,
	caught: Caught,
	runHome: RunHomePill,
	zs: Zs,
}

local computerMeter: Meter = {
	width = 400,
	height = 62,
	topOffset = 12,
	borderThickness = 4,
	shadowOffset = 5,
	padding = 10,
	gap = 10,
	rowGap = 3,
	faceTextSize = 38,
	labelTextSize = 17,
	lockTextSize = 14,
	barHeight = 20,
	barStrokeThickness = 3,
	tickWidth = 3,
	stripePeriod = 28,
}

local phoneMeter: Meter = {
	width = 260,
	height = 46,
	topOffset = 8,
	borderThickness = 3,
	shadowOffset = 3,
	padding = 8,
	gap = 6,
	rowGap = 2,
	faceTextSize = 26,
	labelTextSize = 14,
	lockTextSize = 14,
	barHeight = 16,
	barStrokeThickness = 2,
	tickWidth = 2,
	stripePeriod = 20,
}

-- The values are the mockup's (core-hud.html: .btn, .key, .on). Phones are 60 px with the word at 14 px (spec section 6).
local computerTiptoe: Tiptoe = {
	diameter = 92,
	borderThickness = 4,
	shadowOffset = 6,
	emojiTextSize = 36,
	wordTextSize = 17,
	keyTextSize = 13,
	showKey = true,
	onThickness = 5,
	onGap = 2,
	glowThickness = 10,
	rightMargin = 18,
}

local phoneTiptoe: Tiptoe = {
	diameter = 60,
	borderThickness = 4,
	shadowOffset = 6,
	emojiTextSize = 22,
	wordTextSize = 14,
	keyTextSize = 13,
	showKey = false,
	onThickness = 5,
	onGap = 2,
	glowThickness = 6,
	rightMargin = 18,
}

-- The computer values are the mockup's (hud.html: .prompt and .k). On phones the pill is 44 px tall (a 34 px key with
-- 5 px above and below), the smallest comfortable touch target, with 16 px words.
local computerPrompt: Prompt = {
	keyDiameter = 38,
	keyTextSize = 20,
	textSize = 20,
	textOutline = 2,
	borderThickness = 3,
	cornerRadius = 14,
	paddingLeft = 6,
	paddingRight = 14,
	paddingY = 6,
	gap = 8,
	billboardWidth = 240,
	billboardHeight = 70,
}

local phonePrompt: Prompt = {
	keyDiameter = 34,
	keyTextSize = 18,
	textSize = 16,
	textOutline = 1.5,
	borderThickness = 2,
	cornerRadius = 10,
	paddingLeft = 5,
	paddingRight = 12,
	paddingY = 5,
	gap = 6,
	billboardWidth = 200,
	billboardHeight = 60,
}

-- The values are the mockup's (core-hud.html: .pill). Phones: 14 px text and a 24x30 egg (spec section 6).
local computerPill: Pill = {
	bottomOffset = 18,
	paddingLeft = 8,
	paddingRight = 18,
	paddingY = 6,
	gap = 10,
	borderThickness = 4,
	textSize = 22,
	textOutline = 2,
	eggWidth = 40,
	eggHeight = 50,
	eggBorderThickness = 3,
	homeTextSize = 22,
}

local phonePill: Pill = {
	bottomOffset = 12,
	paddingLeft = 5,
	paddingRight = 11,
	paddingY = 4,
	gap = 6,
	borderThickness = 3,
	textSize = 14,
	textOutline = 1.5,
	eggWidth = 24,
	eggHeight = 30,
	eggBorderThickness = 2,
	homeTextSize = 14,
}

-- The values are the mockup's (hud.html: .hint). It stands in the carry pill's place, so the bottom is the same.
local computerTip: Tip = {
	bottomOffset = 18,
	paddingX = 20,
	paddingY = 8,
	borderThickness = 4,
	textSize = 24,
	textOutline = 2,
	circleSize = 40,
	circleRim = 5,
	circleRing = 3,
	circleGap = 10,
}

local phoneTip: Tip = {
	bottomOffset = 12,
	paddingX = 14,
	paddingY = 5,
	borderThickness = 3,
	textSize = 15,
	textOutline = 1.5,
	circleSize = 24,
	circleRim = 3,
	circleRing = 2,
	circleGap = 6,
}

-- The values are the mockup's (core-hud.html: .msg), except the phone's top: 62 px, 6 px lower than the mockup's 56, so
-- the card clears the meter's shadow. The phone card is the computer card at 0.62 times the size (the mockup's --s),
-- with the text kept at 14 px, the least the spec allows.
local computerCard: Card = {
	top = 96,
	paddingLeft = 10,
	paddingRight = 22,
	paddingY = 8,
	gap = 12,
	borderThickness = 4,
	shadowOffset = 6,
	cornerRadius = 20,
	textSize = 24,
	textOutline = 2,
	eggWidth = 32,
	eggHeight = 40,
	eggBorderThickness = 3,
}

local phoneCard: Card = {
	top = 62,
	paddingLeft = 6,
	paddingRight = 14,
	paddingY = 5,
	gap = 7,
	borderThickness = 3,
	shadowOffset = 4,
	cornerRadius = 12,
	textSize = 14,
	textOutline = 1.5,
	eggWidth = 21,
	eggHeight = 26,
	eggBorderThickness = 2,
}

-- The values are the mockup's (hud.html: .banner.red, in its "wakeup" state): 34 px words on a computer with the second
-- line at half that size, low and right of centre. The phone has one line of 14 px words, the least the spec allows, in
-- the same low place. The first plan put the phone banner at the top, under the sleep meter (where the mockup has it),
-- but at landing spot 6, mid-float, on the iPhone 14, it covered his eyes.
local computerBanner: Banner = {
	bottomOffset = 100,
	centerX = 0.66,
	paddingX = 28,
	paddingY = 10,
	gap = 8,
	secondGap = 2,
	showSecondLine = false,
	borderThickness = 5,
	shadowOffset = 7,
	cornerRadius = 18,
	rotation = -2,
	textSize = 34,
	textOutline = 3,
	secondTextSize = 17,
	secondTextOutline = 2,
}

local phoneBanner: Banner = {
	bottomOffset = 100,
	centerX = 0.66,
	paddingX = 12,
	paddingY = 4,
	gap = 4,
	secondGap = 0,
	showSecondLine = false,
	jumpGap = 12,
	nameLetters = Layout.phoneNameLetters,
	borderThickness = 3,
	shadowOffset = 5,
	cornerRadius = 13,
	rotation = -2,
	textSize = 14,
	textOutline = 1.5,
	secondTextSize = 14,
	secondTextOutline = 1.5,
}

-- The values are the mockup's (core-hud.html: .msg, .msg .e and .msg small): 24 px words, a 40 px emoji and a second line
-- at 0.62 of the words (14.88 px, rounded to 15). The phone card has the green card's phone sizes (the mockup's --s of
-- 0.62), with the words and the second line both at 14 px, the least the spec allows.
local computerCaught: Caught = {
	bottomOffset = 22,
	centerX = 0.3,
	paddingLeft = 10,
	paddingRight = 22,
	paddingY = 8,
	gap = 12,
	borderThickness = 4,
	shadowOffset = 6,
	cornerRadius = 20,
	emojiTextSize = 40,
	textSize = 24,
	secondTextSize = 15,
}

local phoneCaught: Caught = {
	bottomOffset = 14,
	centerX = 0.5,
	paddingLeft = 6,
	paddingRight = 14,
	paddingY = 5,
	gap = 7,
	borderThickness = 3,
	shadowOffset = 4,
	cornerRadius = 12,
	emojiTextSize = 26,
	textSize = 14,
	secondTextSize = 14,
}

table.freeze(computerMeter)
table.freeze(phoneMeter)
table.freeze(computerTiptoe)
table.freeze(phoneTiptoe)
table.freeze(computerPrompt)
table.freeze(phonePrompt)
table.freeze(computerPill)
table.freeze(phonePill)
table.freeze(computerTip)
table.freeze(phoneTip)
table.freeze(computerCard)
table.freeze(phoneCard)
table.freeze(computerBanner)
table.freeze(phoneBanner)
table.freeze(computerCaught)
table.freeze(phoneCaught)

-- The values are the style guide's (wake-up.md lines 39 to 44): 34 px words on a computer and 20 px on a phone, a 4 px
-- outline and 5 px shadow (phone 3 and 3), turned -2 degrees, level with the meter, 14 px from the top (phone 12) and
-- 14 px right of the meter (phone 10). The width and height fit the picture, the words and the mockup's padding (6 px
-- above and below, 14 px left, 22 px right), and are scaled like the phone's other pieces.
local computerRunHome: RunHomePill = {
	width = 270,
	height = 60,
	leftGap = 14,
	topOffset = 14,
	borderThickness = 4,
	shadowOffset = 5,
	textSize = 34,
	textOutline = 3,
	emojiTextSize = 36,
	gap = 8,
	tilt = -2,
}

local phoneRunHome: RunHomePill = {
	width = 160,
	height = 38,
	leftGap = 10,
	topOffset = 12,
	borderThickness = 3,
	shadowOffset = 3,
	textSize = 20,
	textOutline = 2,
	emojiTextSize = 21,
	gap = 5,
	tilt = -2,
}
table.freeze(computerRunHome)
table.freeze(phoneRunHome)

-- The values are the style guide's (meter-zs.md, "Where", "Size" and "Heavy Sleep"): (dx, dy, letter height).
-- The top Z sits 5 points lower than the mockup so it stays on screen at the top of its 8-point rise (plan 4 Task 13d).
local function letters(rows: { { number } }): { ZLetter }
	local result: { ZLetter } = {}
	for _, row in rows do
		table.insert(result, table.freeze({ dx = row[1], dy = row[2], height = row[3] }))
	end
	return table.freeze(result)
end

local computerZs: Zs = {
	calm = letters({ { 8, 30, 30 }, { 40, 4, 36 }, { 78, -7, 42 } }),
	heavy = letters({ { 8, 22, 40 }, { 52, -4, 46 }, { 102, -7, 52 } }),
	letterPerTextSize = 0.74,
	strokeThickness = 4,
	dropOffset = 3,
	tilt = -12, -- counter-clockwise, like the mockup's rotate(-12deg)
}

local phoneZs: Zs = {
	calm = letters({ { 6, 20, 24 }, { 32, 0, 28 }, { 62, -19, 32 } }),
	heavy = letters({ { 6, 14, 32 }, { 40, -10, 38 }, { 80, -19, 44 } }),
	letterPerTextSize = 0.74,
	strokeThickness = 4,
	dropOffset = 3,
	tilt = -12, -- counter-clockwise, like the mockup's rotate(-12deg)
}
table.freeze(computerZs)
table.freeze(phoneZs)

-- True when the screen counts as a phone: its short side is under 500 pixels, held either way up.
function Layout.isPhone(screenSize: Vector2): boolean
	return math.min(screenSize.X, screenSize.Y) < PHONE_SHORT_SIDE
end

-- The sleep meter stays at least this many pixels away from Roblox's buttons, even at its biggest (the pulse).
local BUTTON_GAP = 8

-- Where the sleep meter's centre goes across the screen, in pixels from the left edge. `buttonsRightEdge` is where
-- Roblox's own buttons at the top left end (GuiService.TopbarInset.Min.X). The meter stays in the middle of the
-- screen unless, at its pulse size (`meterWidth * pulseScale`, still centred on the same point), its left edge
-- would come within 8 px of those buttons. Then it slides right just far enough to keep 8 px clear.
function Layout.meterCenterX(
	screenWidth: number,
	meterWidth: number,
	buttonsRightEdge: number,
	pulseScale: number
): number
	local center = screenWidth / 2
	local biggestHalfWidth = meterWidth * pulseScale / 2
	local closestCenter = buttonsRightEdge + BUTTON_GAP + biggestHalfWidth
	return math.max(center, closestCenter)
end

-- The music button (plan 7 Task 16; spec 7 Rule 98), all in HudTop pixels. Numbers measured in Play (work/p7/task16-ruling.md).
local MUSIC_SIZE_SHARE = 0.76 -- of the top-bar band: 44 px in Roblox's 58 px band, like Roblox's own buttons
Layout.MUSIC_FIRST_LEFT = 16 -- Roblox's first button's left edge: where the button goes when it moves down
local MUSIC_ROW_TOP = 12 -- Roblox's buttons sit 12 px from the top of the band
local MUSIC_DOWN_GAP = 6 -- when it moves down, it sits this far below the band

export type MusicSpot = { size: number, x: number, y: number, movedDown: boolean }

-- Where the music button goes. It sits right of Roblox's buttons (`edge` is where their free space starts), level with
-- their top. If the sleep meter at its biggest (`meterLeft`) would come within 8 px of it, it moves under Roblox's
-- first button (`firstLeft` is that button's left edge), 6 px below the band.
function Layout.musicButton(band: number, edge: number, firstLeft: number, meterLeft: number): MusicSpot
	local size = math.round(MUSIC_SIZE_SHARE * band)
	if edge + size + BUTTON_GAP > meterLeft then
		return { size = size, x = firstLeft, y = band + MUSIC_DOWN_GAP, movedDown = true }
	end
	return { size = size, x = edge, y = MUSIC_ROW_TOP, movedDown = false }
end

-- All the sizes for a screen of this size.
function Layout.forScreen(screenSize: Vector2): Screen
	local phone = Layout.isPhone(screenSize)
	return {
		phone = phone,
		meter = if phone then phoneMeter else computerMeter,
		tiptoe = if phone then phoneTiptoe else computerTiptoe,
		prompt = if phone then phonePrompt else computerPrompt,
		pill = if phone then phonePill else computerPill,
		tip = if phone then phoneTip else computerTip,
		card = if phone then phoneCard else computerCard,
		banner = if phone then phoneBanner else computerBanner,
		caught = if phone then phoneCaught else computerCaught,
		runHome = if phone then phoneRunHome else computerRunHome,
		zs = if phone then phoneZs else computerZs,
	}
end

return Layout
