--!strict
-- How the bottom-centre messages look: the pieces of the carry pill, the tips, the green Safe! card, the red wake banner
-- and the cream Caught! card, and the sizes they take on a computer or a phone. Messages.luau decides what they say and
-- when they show. This file never requires Messages (the words it needs are passed to `build`).

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local MessageParts = {}

local HOME = "🏡"
-- The egg's colours run from the top left (light) to the bottom right (dark), like the mockup's shine.
local EGG_GRADIENT_ROTATION = 60
local EGG_MAIN_AT = 0.6
local WAKE_EMOJI = "💥"
local CAUGHT_EMOJI = "💫"

-- The words `build` puts on the pieces at the start. Messages owns them.
export type Words = {
	footprintsText: string,
	runHomeText: string,
	caughtTitle: string,
	caughtLine: string,
}

export type Parts = {
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
function MessageParts.eggColors(look: Theme.RarityLook): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, look.light),
		ColorSequenceKeypoint.new(EGG_MAIN_AT, look.main),
		ColorSequenceKeypoint.new(1, look.dark),
	})
end

-- Builds the pieces (sizes and the egg's colours come later). The pill and the tips go on `hud`, the green card
-- on `hudTop`.
function MessageParts.build(hud: ScreenGui, hudTop: ScreenGui, words: Words): Parts
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
	local tipText, tipTextStroke = outlinedText("TipText", tip, words.footprintsText)

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
	local bannerSecond, bannerSecondStroke = outlinedText("WakeBannerSecond", bannerBody, words.runHomeText)
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
	local caughtTitle = Ui.text("CaughtCardTitle", caughtColumn, words.caughtTitle, 1, Theme.ink)
	caughtTitle.AutomaticSize = Enum.AutomaticSize.X
	caughtTitle.TextXAlignment = Enum.TextXAlignment.Left
	caughtTitle.LayoutOrder = 1
	local caughtLine = Ui.text("CaughtCardLine", caughtColumn, words.caughtLine, 1, Theme.ink)
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
function MessageParts.applyLayout(parts: Parts, pill: Layout.Pill, tip: Layout.Tip, card: Layout.Card)
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
function MessageParts.applyCaught(parts: Parts, caught: Layout.Caught)
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
function MessageParts.applyBanner(parts: Parts, banner: Layout.Banner)
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

return MessageParts
