--!strict
-- The short messages at the bottom centre of the screen, in the place the mockups give them (core-hud.html, .pill
-- and hud.html, .hint):
--  * the carry pill, shown for as long as the server says the player carries an egg (spec Rule 4 and the
--    "Carrying" row of section 6);
--  * the tip "Follow the glowing footprints!" (the "Spawn" row of section 6), from the start until the player's
--    first grab of the session: the first time Carrying becomes a rarity. After that it never comes back, not even
--    after a respawn;
--  * the tip "Someone else got it!" for 2 seconds after a grab was missed (the "Someone else got the egg" row).
--    Before the first grab, the footprints tip comes back when the 2 seconds are over.
--  * the tip "Stand still or tiptoe!" for 3 seconds at the 85% warning (spec Rule 10), also while carrying: it takes
--    the carry pill's place, and the pill comes back after.
-- All of them stand in the same place, so only one shows at a time. The 85% warning wins over everything. Then the
-- carry pill wins: a player who carries an egg has an egg, and that matters more than a grab they missed. (The other
-- messages, the cards and the wake banner, come in later tasks.)
-- The green card "Safe! [Rarity] egg is home" is the third message. It stands under the sleep meter (on HudTop, so it
-- lines up with it) for 3 seconds after this player's own egg comes home, from the EggHome remote (spec Rule 5 and the
-- "Egg safe at home" row of section 6). Another player's egg shows nothing.
-- The red wake banner ("[Name] woke the Giant!", spec Rule 12) is the fourth. When GiantState's Phase turns Awake it shows
-- to every player for 3 seconds, with the second line "Run home with your egg!" on computers (on phones it is one line).
-- [Name] is the display name the server wrote into GiantState.WokenBy; the words follow it if it changes while the
-- banner shows. It stands low and right of centre on every screen (on phones it is one line), clear of his face. While
-- he is awake, a carrier's pill says "Dodge the red circles!", and the 85% tip ends when he wakes.
-- The cream "Caught!" card is the fifth. When the server fires Caught for this player (a hand slam sent them home, spec
-- Rule 13 and the "Caught" row of section 6), it shows for 3 seconds at the bottom of the Hud screen, left of centre on a
-- computer and in the middle on a phone: the 💫, "Caught!" and the second line "The egg went back. You lost nothing
-- else." It is its own frame, not the pill's or the tips' place, because a caught player carries nothing. Another
-- player's catch shows nothing here (everyone sees the star puff, which lives in Fx/Celebrations).
-- It only shows what the server says: it reads the player's Carrying attribute and GiantState, and listens for
-- GrabMissed and EggHome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Messages = {}

local HOME = "🏡"
-- The egg's colours run from the top left (light) to the bottom right (dark), like the mockup's shine.
local EGG_GRADIENT_ROTATION = 60
local EGG_MAIN_AT = 0.6

Messages.footprintsText = "👣 Follow the glowing footprints!"
Messages.missedText = "Someone else got it!"
Messages.missedSeconds = 2
-- The tip at the 85% warning (spec Rule 10 and the "85% warning" row of section 6): it wins over everything else in
-- the bottom centre, even the carry pill, for 3 seconds.
Messages.standStillText = "🤫 Stand still or tiptoe!"
Messages.standStillSeconds = 3
local WARNING_MARK = 85

-- The red wake banner's words, and the carry pill's words while he is awake.
Messages.runHomeText = "Run home with your egg!"
Messages.dodgeText = "Dodge the red circles!"
local WAKE_EMOJI = "💥"

-- The banner's first line for the player the server names. Nobody named (an empty name, or something that isn't text):
-- the line doesn't name anyone.
function Messages.wokeText(name: any): string
	if type(name) == "string" and name ~= "" then
		return `{name} woke the Giant!`
	end
	return "The Giant woke up!"
end

-- The Caught! card (spec section 6, "Caught"): the words, the second line and how long it shows.
Messages.caughtTitle = "Caught!"
Messages.caughtLine = "The egg went back. You lost nothing else."
Messages.caughtSeconds = 3
local CAUGHT_EMOJI = "💫"

-- The words in the carry pill for an egg of this rarity.
function Messages.carryText(rarity: string): string
	return `{rarity} egg! Get it home`
end

-- The words on the green card for an egg of this rarity.
function Messages.safeText(rarity: string): string
	return `Safe! {rarity} egg is home`
end

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

-- The GrabMissed remote, as far as this module uses it.
export type GrabMissedLike = { OnClientEvent: SignalLike }

-- The EggHome remote, as far as this module uses it: it fires (player, rarity, position of the new egg).
export type EggHomeLike = { OnClientEvent: SignalLike }

-- The Warning remote, as far as this module uses it: it fires the mark (60 or 85).
export type WarningLike = { OnClientEvent: SignalLike }

-- The Caught remote, as far as this module uses it: it fires the player who was caught.
export type CaughtLike = { OnClientEvent: SignalLike }

export type PlayerLike = {
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
}

-- The screen size: `get` reads it, and `connect` calls `callback` whenever it may have changed and returns a
-- function that stops that.
export type ViewportLike = {
	get: () -> Vector2,
	connect: (callback: () -> ()) -> () -> (),
}

export type Deps = {
	parent: Instance, -- the player's screen (PlayerGui): Hud goes in it
	player: PlayerLike, -- the local player: their Carrying attribute is the server's answer
	grabMissed: GrabMissedLike, -- the GrabMissed remote
	eggHome: EggHomeLike, -- the EggHome remote
	warning: WarningLike, -- the Warning remote
	caught: CaughtLike, -- the Caught remote
	giantState: Instance, -- ReplicatedStorage.GiantState: its Phase says when he wakes and WokenBy who woke him
	viewport: ViewportLike,
	-- Runs `callback` after `seconds` and returns a function that cancels it. Left out, the real clock is used.
	after: ((seconds: number, callback: () -> ()) -> () -> ())?,
}

-- What start gives back: `stop` takes the messages off again and cleans everything up.
export type Handle = {
	stop: () -> (),
}

type Parts = {
	pill: Frame,
	pillPadding: UIPadding,
	pillList: UIListLayout,
	pillStroke: UIStroke,
	egg: Frame,
	eggStroke: UIStroke,
	eggGradient: UIGradient,
	text: TextLabel,
	textStroke: UIStroke,
	home: TextLabel,
	tip: Frame,
	tipPadding: UIPadding,
	tipStroke: UIStroke,
	tipText: TextLabel,
	tipTextStroke: UIStroke,
	card: Frame,
	cardShadow: Frame,
	cardShadowStroke: UIStroke,
	cardShadowCorner: UICorner,
	cardBody: Frame,
	cardBodyStroke: UIStroke,
	cardBodyCorner: UICorner,
	cardPadding: UIPadding,
	cardList: UIListLayout,
	cardEgg: Frame,
	cardEggStroke: UIStroke,
	cardEggGradient: UIGradient,
	cardText: TextLabel,
	cardTextStroke: UIStroke,
	banner: Frame,
	bannerShadow: Frame,
	bannerShadowStroke: UIStroke,
	bannerShadowCorner: UICorner,
	bannerBody: Frame,
	bannerBodyStroke: UIStroke,
	bannerBodyCorner: UICorner,
	bannerPadding: UIPadding,
	bannerList: UIListLayout,
	bannerLine: Frame,
	bannerLineList: UIListLayout,
	bannerEmoji: TextLabel,
	bannerText: TextLabel,
	bannerTextStroke: UIStroke,
	bannerSecond: TextLabel,
	bannerSecondStroke: UIStroke,
	caughtCard: Frame,
	caughtShadow: Frame,
	caughtShadowStroke: UIStroke,
	caughtShadowCorner: UICorner,
	caughtBody: Frame,
	caughtBodyStroke: UIStroke,
	caughtBodyCorner: UICorner,
	caughtPadding: UIPadding,
	caughtList: UIListLayout,
	caughtEmoji: TextLabel,
	caughtColumn: Frame,
	caughtTitle: TextLabel,
	caughtLine: TextLabel,
}

-- The real clock: runs the callback after `seconds` and can cancel it.
function Messages.realAfter(seconds: number, callback: () -> ()): () -> ()
	local done = false
	local thread = task.delay(seconds, function()
		done = true
		callback()
	end)
	return function()
		if not done then
			done = true
			task.cancel(thread)
		end
	end
end

-- Words in white with an Ink outline, like every word that sits over the world.
local function outlinedText(name: string, parent: Instance, text: string): (TextLabel, UIStroke)
	local label = Ui.text(name, parent, text, 1, Theme.white)
	label.AutomaticSize = Enum.AutomaticSize.XY
	local stroke = Ui.outline(label, Theme.ink, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return label, stroke
end

-- A dark, round plate in the bottom centre. Its size comes from what is in it.
local function bottomPlate(name: string, parent: Instance, transparency: number): (Frame, UIStroke, UIPadding)
	local plate = Ui.panel(name, parent, Theme.ink, UDim.new(0.5, 0))
	plate.BackgroundTransparency = transparency
	plate.AnchorPoint = Vector2.new(0.5, 1)
	plate.AutomaticSize = Enum.AutomaticSize.XY
	plate.Visible = false
	local stroke = Ui.outline(plate, Theme.ink, 1)
	local padding = Instance.new("UIPadding")
	padding.Parent = plate
	return plate, stroke, padding
end

-- The egg's picture, painted with a rarity's colours: light at the top left, the main colour, then a shade.
local function eggColors(look: Theme.RarityLook): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, look.light),
		ColorSequenceKeypoint.new(EGG_MAIN_AT, look.main),
		ColorSequenceKeypoint.new(1, look.dark),
	})
end

-- Builds the pieces (sizes and the egg's colours come later). The pill and the tips go on `hud`, the green card
-- on `hudTop`.
local function build(hud: ScreenGui, hudTop: ScreenGui): Parts
	local pill, pillStroke, pillPadding = bottomPlate("CarryPill", hud, Theme.promptTransparency)
	local pillList = Instance.new("UIListLayout")
	pillList.FillDirection = Enum.FillDirection.Horizontal
	pillList.VerticalAlignment = Enum.VerticalAlignment.Center
	pillList.SortOrder = Enum.SortOrder.LayoutOrder
	pillList.Parent = pill

	local egg = Ui.panel("CarryEgg", pill, Theme.white, UDim.new(0.5, 0))
	egg.LayoutOrder = 1
	local eggStroke = Ui.outline(egg, Theme.ink, 1)
	local eggGradient = Instance.new("UIGradient")
	eggGradient.Rotation = EGG_GRADIENT_ROTATION
	eggGradient.Parent = egg

	local text, textStroke = outlinedText("CarryText", pill, "")
	text.LayoutOrder = 2
	local home = Ui.text("CarryHome", pill, HOME, 1, Theme.white)
	home.AutomaticSize = Enum.AutomaticSize.XY
	home.LayoutOrder = 3

	local tip, tipStroke, tipPadding = bottomPlate("Tip", hud, Theme.tipTransparency)
	local tipText, tipTextStroke = outlinedText("TipText", tip, Messages.footprintsText)

	-- The green card: an Ink shadow (the same shape, shifted down) behind a green body that is as big as its words.
	local card = Ui.group("SafeCard", hudTop)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Visible = false

	local cardShadow = Ui.panel("SafeCardShadow", card, Theme.ink, UDim.new(0, 1))
	cardShadow.Size = UDim2.fromScale(1, 1)
	local cardShadowStroke = Ui.outline(cardShadow, Theme.ink, 1)
	local cardShadowCorner = cardShadow:FindFirstChildOfClass("UICorner") :: UICorner

	local cardBody = Ui.panel("SafeCardBody", card, Theme.white, UDim.new(0, 1))
	cardBody.AutomaticSize = Enum.AutomaticSize.XY
	local cardBodyStroke = Ui.outline(cardBody, Theme.ink, 1)
	local cardBodyCorner = cardBody:FindFirstChildOfClass("UICorner") :: UICorner
	local bodyGradient = Instance.new("UIGradient")
	bodyGradient.Rotation = 90 -- light at the top, dark at the bottom
	bodyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.cardGreenLight),
		ColorSequenceKeypoint.new(Theme.cardGreenMainAt, Theme.cardGreen),
		ColorSequenceKeypoint.new(1, Theme.cardGreenDark),
	})
	bodyGradient.Parent = cardBody
	local cardPadding = Instance.new("UIPadding")
	cardPadding.Parent = cardBody
	local cardList = Instance.new("UIListLayout")
	cardList.FillDirection = Enum.FillDirection.Horizontal
	cardList.VerticalAlignment = Enum.VerticalAlignment.Center
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Parent = cardBody

	local cardEgg = Ui.panel("SafeCardEgg", cardBody, Theme.white, UDim.new(0.5, 0))
	cardEgg.LayoutOrder = 1
	local cardEggStroke = Ui.outline(cardEgg, Theme.ink, 1)
	local cardEggGradient = Instance.new("UIGradient")
	cardEggGradient.Rotation = EGG_GRADIENT_ROTATION
	cardEggGradient.Parent = cardEgg
	local cardText, cardTextStroke = outlinedText("SafeCardText", cardBody, "")
	cardText.LayoutOrder = 2

	-- The red wake banner: the same build as the green card (an Ink shadow behind a body that is as big as its words),
	-- turned a little. The body holds the first line (the 💥 and the words) and the second line under it.
	local banner = Ui.group("WakeBanner", hud)
	banner.AutomaticSize = Enum.AutomaticSize.XY
	banner.Visible = false

	local bannerShadow = Ui.panel("WakeBannerShadow", banner, Theme.ink, UDim.new(0, 1))
	bannerShadow.Size = UDim2.fromScale(1, 1)
	local bannerShadowStroke = Ui.outline(bannerShadow, Theme.ink, 1)
	local bannerShadowCorner = bannerShadow:FindFirstChildOfClass("UICorner") :: UICorner

	local bannerBody = Ui.panel("WakeBannerBody", banner, Theme.white, UDim.new(0, 1))
	bannerBody.AutomaticSize = Enum.AutomaticSize.XY
	local bannerBodyStroke = Ui.outline(bannerBody, Theme.ink, 1)
	local bannerBodyCorner = bannerBody:FindFirstChildOfClass("UICorner") :: UICorner
	local bannerGradient = Instance.new("UIGradient")
	bannerGradient.Rotation = 90 -- light at the top, dark at the bottom
	bannerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.bannerRedLight),
		ColorSequenceKeypoint.new(Theme.bannerRedMainAt, Theme.bannerRed),
		ColorSequenceKeypoint.new(1, Theme.bannerRedDark),
	})
	bannerGradient.Parent = bannerBody
	local bannerPadding = Instance.new("UIPadding")
	bannerPadding.Parent = bannerBody
	local bannerList = Instance.new("UIListLayout")
	bannerList.FillDirection = Enum.FillDirection.Vertical
	bannerList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bannerList.SortOrder = Enum.SortOrder.LayoutOrder
	bannerList.Parent = bannerBody

	local bannerLine = Ui.group("WakeBannerLine", bannerBody)
	bannerLine.AutomaticSize = Enum.AutomaticSize.XY
	bannerLine.LayoutOrder = 1
	local bannerLineList = Instance.new("UIListLayout")
	bannerLineList.FillDirection = Enum.FillDirection.Horizontal
	bannerLineList.VerticalAlignment = Enum.VerticalAlignment.Center
	bannerLineList.SortOrder = Enum.SortOrder.LayoutOrder
	bannerLineList.Parent = bannerLine
	local bannerEmoji = Ui.text("WakeBannerEmoji", bannerLine, WAKE_EMOJI, 1, Theme.white)
	bannerEmoji.LayoutOrder = 1
	local bannerText, bannerTextStroke = outlinedText("WakeBannerText", bannerLine, "")
	bannerText.LayoutOrder = 2
	local bannerSecond, bannerSecondStroke = outlinedText("WakeBannerSecond", bannerBody, Messages.runHomeText)
	bannerSecond.LayoutOrder = 2

	-- The cream Caught! card: the same build as the green card (an Ink shadow behind a body that is as big as its words).
	-- The body holds the 💫 and a column with the words and the second line under them.
	local caughtCard = Ui.group("CaughtCard", hud)
	caughtCard.AnchorPoint = Vector2.new(0.5, 1)
	caughtCard.AutomaticSize = Enum.AutomaticSize.XY
	caughtCard.Visible = false

	local caughtShadow = Ui.panel("CaughtCardShadow", caughtCard, Theme.ink, UDim.new(0, 1))
	caughtShadow.Size = UDim2.fromScale(1, 1)
	local caughtShadowStroke = Ui.outline(caughtShadow, Theme.ink, 1)
	local caughtShadowCorner = caughtShadow:FindFirstChildOfClass("UICorner") :: UICorner

	local caughtBody = Ui.panel("CaughtCardBody", caughtCard, Theme.cream, UDim.new(0, 1))
	caughtBody.AutomaticSize = Enum.AutomaticSize.XY
	local caughtBodyStroke = Ui.outline(caughtBody, Theme.ink, 1)
	local caughtBodyCorner = caughtBody:FindFirstChildOfClass("UICorner") :: UICorner
	local caughtPadding = Instance.new("UIPadding")
	caughtPadding.Parent = caughtBody
	local caughtList = Instance.new("UIListLayout")
	caughtList.FillDirection = Enum.FillDirection.Horizontal
	caughtList.VerticalAlignment = Enum.VerticalAlignment.Center
	caughtList.SortOrder = Enum.SortOrder.LayoutOrder
	caughtList.Parent = caughtBody

	local caughtEmoji = Ui.text("CaughtCardEmoji", caughtBody, CAUGHT_EMOJI, 1, Theme.ink)
	caughtEmoji.AutomaticSize = Enum.AutomaticSize.X
	caughtEmoji.LayoutOrder = 1
	local caughtColumn = Ui.group("CaughtCardColumn", caughtBody)
	caughtColumn.AutomaticSize = Enum.AutomaticSize.XY
	caughtColumn.LayoutOrder = 2
	local columnList = Instance.new("UIListLayout")
	columnList.FillDirection = Enum.FillDirection.Vertical
	columnList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	columnList.SortOrder = Enum.SortOrder.LayoutOrder
	columnList.Parent = caughtColumn
	local caughtTitle = Ui.text("CaughtCardTitle", caughtColumn, Messages.caughtTitle, 1, Theme.ink)
	caughtTitle.AutomaticSize = Enum.AutomaticSize.X
	caughtTitle.TextXAlignment = Enum.TextXAlignment.Left
	caughtTitle.LayoutOrder = 1
	local caughtLine = Ui.text("CaughtCardLine", caughtColumn, Messages.caughtLine, 1, Theme.ink)
	caughtLine.AutomaticSize = Enum.AutomaticSize.X
	caughtLine.TextXAlignment = Enum.TextXAlignment.Left
	caughtLine.LayoutOrder = 2

	return {
		caughtCard = caughtCard,
		caughtShadow = caughtShadow,
		caughtShadowStroke = caughtShadowStroke,
		caughtShadowCorner = caughtShadowCorner,
		caughtBody = caughtBody,
		caughtBodyStroke = caughtBodyStroke,
		caughtBodyCorner = caughtBodyCorner,
		caughtPadding = caughtPadding,
		caughtList = caughtList,
		caughtEmoji = caughtEmoji,
		caughtColumn = caughtColumn,
		caughtTitle = caughtTitle,
		caughtLine = caughtLine,
		banner = banner,
		bannerShadow = bannerShadow,
		bannerShadowStroke = bannerShadowStroke,
		bannerShadowCorner = bannerShadowCorner,
		bannerBody = bannerBody,
		bannerBodyStroke = bannerBodyStroke,
		bannerBodyCorner = bannerBodyCorner,
		bannerPadding = bannerPadding,
		bannerList = bannerList,
		bannerLine = bannerLine,
		bannerLineList = bannerLineList,
		bannerEmoji = bannerEmoji,
		bannerText = bannerText,
		bannerTextStroke = bannerTextStroke,
		bannerSecond = bannerSecond,
		bannerSecondStroke = bannerSecondStroke,
		card = card,
		cardShadow = cardShadow,
		cardShadowStroke = cardShadowStroke,
		cardShadowCorner = cardShadowCorner,
		cardBody = cardBody,
		cardBodyStroke = cardBodyStroke,
		cardBodyCorner = cardBodyCorner,
		cardPadding = cardPadding,
		cardList = cardList,
		cardEgg = cardEgg,
		cardEggStroke = cardEggStroke,
		cardEggGradient = cardEggGradient,
		cardText = cardText,
		cardTextStroke = cardTextStroke,
		pill = pill,
		pillPadding = pillPadding,
		pillList = pillList,
		pillStroke = pillStroke,
		egg = egg,
		eggStroke = eggStroke,
		eggGradient = eggGradient,
		text = text,
		textStroke = textStroke,
		home = home,
		tip = tip,
		tipPadding = tipPadding,
		tipStroke = tipStroke,
		tipText = tipText,
		tipTextStroke = tipTextStroke,
	}
end

-- Sets every size and text size for a computer or a phone screen.
local function applyLayout(parts: Parts, pill: Layout.Pill, tip: Layout.Tip, card: Layout.Card)
	parts.pill.Position = UDim2.new(0.5, 0, 1, -pill.bottomOffset)
	parts.pillStroke.Thickness = pill.borderThickness
	parts.pillPadding.PaddingLeft = UDim.new(0, pill.paddingLeft)
	parts.pillPadding.PaddingRight = UDim.new(0, pill.paddingRight)
	parts.pillPadding.PaddingTop = UDim.new(0, pill.paddingY)
	parts.pillPadding.PaddingBottom = UDim.new(0, pill.paddingY)
	parts.pillList.Padding = UDim.new(0, pill.gap)
	parts.egg.Size = UDim2.fromOffset(pill.eggWidth, pill.eggHeight)
	parts.eggStroke.Thickness = pill.eggBorderThickness
	parts.text.TextSize = pill.textSize
	parts.textStroke.Thickness = pill.textOutline
	parts.home.TextSize = pill.homeTextSize

	parts.tip.Position = UDim2.new(0.5, 0, 1, -tip.bottomOffset)
	parts.tipStroke.Thickness = tip.borderThickness
	parts.tipPadding.PaddingLeft = UDim.new(0, tip.paddingX)
	parts.tipPadding.PaddingRight = UDim.new(0, tip.paddingX)
	parts.tipPadding.PaddingTop = UDim.new(0, tip.paddingY)
	parts.tipPadding.PaddingBottom = UDim.new(0, tip.paddingY)
	parts.tipText.TextSize = tip.textSize
	parts.tipTextStroke.Thickness = tip.textOutline

	-- The outline is drawn outside the card, so the card starts one outline's thickness lower to keep its outer edge
	-- at `card.top`. The shadow has the same outline, shifted down.
	local radius = UDim.new(0, card.cornerRadius)
	parts.card.Position = UDim2.new(0.5, 0, 0, card.top + card.borderThickness)
	parts.cardShadow.Position = UDim2.fromOffset(0, card.shadowOffset)
	parts.cardShadowStroke.Thickness = card.borderThickness
	parts.cardShadowCorner.CornerRadius = radius
	parts.cardBodyStroke.Thickness = card.borderThickness
	parts.cardBodyCorner.CornerRadius = radius
	parts.cardPadding.PaddingLeft = UDim.new(0, card.paddingLeft)
	parts.cardPadding.PaddingRight = UDim.new(0, card.paddingRight)
	parts.cardPadding.PaddingTop = UDim.new(0, card.paddingY)
	parts.cardPadding.PaddingBottom = UDim.new(0, card.paddingY)
	parts.cardList.Padding = UDim.new(0, card.gap)
	parts.cardEgg.Size = UDim2.fromOffset(card.eggWidth, card.eggHeight)
	parts.cardEggStroke.Thickness = card.eggBorderThickness
	parts.cardText.TextSize = card.textSize
	parts.cardTextStroke.Thickness = card.textOutline
end

-- Puts the Caught! card at the bottom, and sets its sizes, text sizes and outline. Each line is as tall as its text size,
-- so the card's height is known.
local function applyCaught(parts: Parts, caught: Layout.Caught)
	-- The outline is drawn outside the card, so the card's body ends one outline's thickness higher, to keep its outer edge
	-- where the layout says.
	parts.caughtCard.Position = UDim2.new(caught.centerX, 0, 1, -(caught.bottomOffset + caught.borderThickness))
	local radius = UDim.new(0, caught.cornerRadius)
	parts.caughtShadow.Position = UDim2.fromOffset(0, caught.shadowOffset)
	parts.caughtShadowStroke.Thickness = caught.borderThickness
	parts.caughtShadowCorner.CornerRadius = radius
	parts.caughtBodyStroke.Thickness = caught.borderThickness
	parts.caughtBodyCorner.CornerRadius = radius
	parts.caughtPadding.PaddingLeft = UDim.new(0, caught.paddingLeft)
	parts.caughtPadding.PaddingRight = UDim.new(0, caught.paddingRight)
	parts.caughtPadding.PaddingTop = UDim.new(0, caught.paddingY)
	parts.caughtPadding.PaddingBottom = UDim.new(0, caught.paddingY)
	parts.caughtList.Padding = UDim.new(0, caught.gap)
	parts.caughtEmoji.Size = UDim2.fromOffset(0, caught.emojiTextSize)
	parts.caughtEmoji.TextSize = caught.emojiTextSize
	parts.caughtTitle.Size = UDim2.fromOffset(0, caught.textSize)
	parts.caughtTitle.TextSize = caught.textSize
	parts.caughtLine.Size = UDim2.fromOffset(0, caught.secondTextSize)
	parts.caughtLine.TextSize = caught.secondTextSize
end

-- Puts the red banner low and right of centre, and sets its sizes, text sizes and outlines.
local function applyBanner(parts: Parts, banner: Layout.Banner)
	-- The outline is drawn outside the banner, so the banner's body ends one outline's thickness higher, to keep its
	-- outer edge where the layout says.
	parts.banner.AnchorPoint = Vector2.new(0.5, 1)
	parts.banner.Position = UDim2.new(banner.centerX, 0, 1, -(banner.bottomOffset + banner.borderThickness))
	parts.banner.Rotation = banner.rotation
	local radius = UDim.new(0, banner.cornerRadius)
	parts.bannerShadow.Position = UDim2.fromOffset(0, banner.shadowOffset)
	parts.bannerShadowStroke.Thickness = banner.borderThickness
	parts.bannerShadowCorner.CornerRadius = radius
	parts.bannerBodyStroke.Thickness = banner.borderThickness
	parts.bannerBodyCorner.CornerRadius = radius
	parts.bannerPadding.PaddingLeft = UDim.new(0, banner.paddingX)
	parts.bannerPadding.PaddingRight = UDim.new(0, banner.paddingX)
	parts.bannerPadding.PaddingTop = UDim.new(0, banner.paddingY)
	parts.bannerPadding.PaddingBottom = UDim.new(0, banner.paddingY)
	parts.bannerList.Padding = UDim.new(0, banner.secondGap)
	parts.bannerLineList.Padding = UDim.new(0, banner.gap)
	-- Each line is as tall as its text size, so the banner's height is known.
	for _, label in { parts.bannerEmoji, parts.bannerText } do
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, banner.textSize)
		label.TextSize = banner.textSize
	end
	parts.bannerTextStroke.Thickness = banner.textOutline
	parts.bannerSecond.AutomaticSize = Enum.AutomaticSize.X
	parts.bannerSecond.Size = UDim2.fromOffset(0, banner.secondTextSize)
	parts.bannerSecond.TextSize = banner.secondTextSize
	parts.bannerSecondStroke.Thickness = banner.secondTextOutline
	parts.bannerSecond.Visible = banner.showSecondLine
end

-- Puts the messages on the player's screen. Returns a handle: `stop` takes them off again and cleans up
-- everything it made (every connection, every timer and the pieces themselves).
function Messages.start(deps: Deps): Handle
	local hud = Ui.hud(deps.parent)
	for _, name in { "CarryPill", "Tip", "WakeBanner", "CaughtCard" } do
		local leftOver = hud:FindFirstChild(name)
		if leftOver then
			leftOver:Destroy() -- never two of each
		end
	end

	local hudTop = Ui.hudTop(deps.parent)
	local leftOverCard = hudTop:FindFirstChild("SafeCard")
	if leftOverCard then
		leftOverCard:Destroy() -- never two cards
	end

	local trove = Trove.new()
	local parts = build(hud, hudTop)
	trove:Add(parts.pill)
	trove:Add(parts.tip)
	trove:Add(parts.card)
	trove:Add(parts.banner)
	trove:Add(parts.caughtCard)
	local after = deps.after or Messages.realAfter

	local cancelMissed: (() -> ())? = nil
	local stopped = false
	-- Set for good at the first grab of the session. Until then, the tip tells the player to follow the footprints.
	local grabbedOnce = false
	-- True for the 2 seconds after a missed grab.
	local missedShowing = false

	-- Stops the 2-second timer of the missed tip, if one is running.
	local function stopMissedTimer()
		if cancelMissed then
			cancelMissed()
			cancelMissed = nil
		end
		missedShowing = false
	end
	trove:Add(stopMissedTimer)

	-- True for the 3 seconds after an 85% warning. The tip then takes the carry pill's place.
	local warningShowing = false
	local cancelWarning: (() -> ())? = nil

	local function stopWarningTimer()
		if cancelWarning then
			cancelWarning()
			cancelWarning = nil
		end
		warningShowing = false
	end
	trove:Add(stopWarningTimer)

	-- True while Phase is Awake. A player who joins while he is awake sees no banner, but the pill's words are right.
	local awake = deps.giantState:GetAttribute("Phase") == "Awake"
	local bannerShowing = false
	local cancelBanner: (() -> ())? = nil

	local function hideBanner()
		if cancelBanner then
			cancelBanner()
			cancelBanner = nil
		end
		bannerShowing = false
		parts.banner.Visible = false
	end
	trove:Add(hideBanner)

	local function updateBannerWords()
		parts.bannerText.Text = Messages.wokeText(deps.giantState:GetAttribute("WokenBy"))
	end

	-- Shows the banner for Config.Wake.BannerSeconds. A banner that is already showing starts its seconds again.
	local function showBanner()
		hideBanner()
		updateBannerWords()
		bannerShowing = true
		parts.banner.Visible = true
		cancelBanner = after(Config.Wake.BannerSeconds, function()
			cancelBanner = nil
			bannerShowing = false
			parts.banner.Visible = false
		end)
	end

	local cancelCaught: (() -> ())? = nil

	local function hideCaught()
		if cancelCaught then
			cancelCaught()
			cancelCaught = nil
		end
		parts.caughtCard.Visible = false
	end
	trove:Add(hideCaught)

	local cancelCard: (() -> ())? = nil

	local function hideCard()
		if cancelCard then
			cancelCard()
			cancelCard = nil
		end
		parts.card.Visible = false
	end
	trove:Add(hideCard)

	-- The rarity the server says the player carries, or nil if they carry nothing (or something unknown).
	local function carriedRarity(): string?
		local value = deps.player:GetAttribute("Carrying")
		if type(value) == "string" and Theme.rarity[value] ~= nil then
			return value
		end
		return nil
	end

	-- Shows the tip that fits now, or none. The 85% warning wins over everything; then the carry pill; then a missed
	-- grab; then the footprints tip, until the first grab.
	local function renderTip()
		local words: string? = nil
		if warningShowing then
			words = Messages.standStillText
		elseif carriedRarity() == nil then
			if missedShowing then
				words = Messages.missedText
			elseif not grabbedOnce then
				words = Messages.footprintsText
			end
		end
		if words ~= nil then
			parts.tipText.Text = words
		end
		parts.tip.Visible = words ~= nil
	end

	local function renderCarry()
		local rarity = carriedRarity()
		if rarity == nil then
			parts.pill.Visible = false
			renderTip()
			return
		end
		local look = Theme.rarity[rarity]
		-- While he is awake, the carrier is told what to do, instead of where to go.
		parts.text.Text = if awake then Messages.dodgeText else Messages.carryText(rarity)
		parts.eggGradient.Color = eggColors(look)
		parts.pill.Visible = not warningShowing -- the warning tip takes its place for 3 seconds
		grabbedOnce = true
		stopMissedTimer()
		renderTip() -- they stand in the same place, and the carry pill wins
	end

	-- The 85% warning: the tip shows for 3 seconds, also for a player who carries an egg (the pill comes back after).
	-- A second 85 starts the 3 seconds again. Any other mark shows nothing.
	local function onWarning(mark: any)
		-- A late 85 that arrives after he woke shows nothing: the warnings are over.
		if stopped or mark ~= WARNING_MARK or awake then
			return
		end
		stopWarningTimer()
		warningShowing = true
		renderCarry()
		cancelWarning = after(Messages.standStillSeconds, function()
			cancelWarning = nil
			warningShowing = false
			renderCarry()
		end)
	end

	local function onGrabMissed()
		if stopped or carriedRarity() ~= nil then
			return
		end
		stopMissedTimer() -- a second miss starts the 2 seconds again
		missedShowing = true
		renderTip()
		cancelMissed = after(Messages.missedSeconds, function()
			cancelMissed = nil
			missedShowing = false
			renderTip()
		end)
	end

	-- An egg came home. Only this player's own egg shows the card; a second one while it shows replaces the words and
	-- starts the 3 seconds again.
	local function onEggHome(player: any, rarity: any, _position: any)
		if stopped or player ~= deps.player then
			return
		end
		if type(rarity) ~= "string" or Theme.rarity[rarity] == nil then
			return
		end
		hideCard()
		parts.cardText.Text = Messages.safeText(rarity)
		parts.cardEggGradient.Color = eggColors(Theme.rarity[rarity])
		parts.card.Visible = true
		cancelCard = after(Config.Home.CardSeconds, function()
			cancelCard = nil
			parts.card.Visible = false
		end)
	end

	-- A hand slam caught a player. Only this player's own catch shows the card; a second one while it shows starts the
	-- 3 seconds again.
	local function onCaught(player: any)
		if stopped or player ~= deps.player then
			return
		end
		hideCaught()
		parts.caughtCard.Visible = true
		cancelCaught = after(Messages.caughtSeconds, function()
			cancelCaught = nil
			parts.caughtCard.Visible = false
		end)
	end

	-- Phase turned Awake or left it. The banner shows to everyone when he wakes; the 85% tip ends then, and the carry
	-- pill's words change either way.
	local function onPhaseChanged()
		if stopped then
			return
		end
		local nowAwake = deps.giantState:GetAttribute("Phase") == "Awake"
		if nowAwake == awake then
			return
		end
		awake = nowAwake
		if nowAwake then
			stopWarningTimer()
			showBanner()
		end
		renderCarry()
	end

	-- Phase can reach a device before WokenBy: the words follow it while the banner shows.
	local function onWokenByChanged()
		if not stopped and bannerShowing then
			updateBannerWords()
		end
	end

	local function relayout()
		local layout = Layout.forScreen(deps.viewport.get())
		applyLayout(parts, layout.pill, layout.tip, layout.card)
		applyBanner(parts, layout.banner)
		applyCaught(parts, layout.caught)
	end

	relayout()
	renderCarry()
	trove:Add(deps.giantState:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged))
	trove:Add(deps.giantState:GetAttributeChangedSignal("WokenBy"):Connect(onWokenByChanged))
	trove:Add(deps.player:GetAttributeChangedSignal("Carrying"):Connect(renderCarry))
	trove:Add(deps.grabMissed.OnClientEvent:Connect(onGrabMissed))
	trove:Add(deps.eggHome.OnClientEvent:Connect(onEggHome))
	trove:Add(deps.warning.OnClientEvent:Connect(onWarning))
	trove:Add(deps.caught.OnClientEvent:Connect(onCaught))
	trove:Add(deps.viewport.connect(relayout))

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			trove:Destroy()
		end,
	}
end

return Messages
