--!strict
-- Picks the computer or the phone sizes for the screen (spec section 6, "Phone sizes"). Pure: it only does maths
-- on the screen size it is given, so a test can pass any size.

local Layout = {}

-- A screen whose short side is under this many pixels is a phone (Studio's iPhone 14 simulator gives 390).
local PHONE_SHORT_SIDE = 500

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
-- it never covers his face or the red slam circles. A computer has a smaller second line under the words; a phone has
-- one small line.
export type Banner = {
	bottomOffset: number, -- pixels from the bottom of the safe area to the banner's outer edge (outline included)
	centerX: number, -- where the banner's middle is, across the screen: 0.5 is the middle, 0.66 is two thirds of the way
	paddingX: number,
	paddingY: number,
	gap: number, -- space between the 💥 and the words
	secondGap: number, -- space between the words and the second line
	showSecondLine: boolean, -- "Run home with your egg!" shows on computers only
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
}

local phoneTip: Tip = {
	bottomOffset = 12,
	paddingX = 14,
	paddingY = 5,
	borderThickness = 3,
	textSize = 15,
	textOutline = 1.5,
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
	showSecondLine = true,
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
	}
end

return Layout
