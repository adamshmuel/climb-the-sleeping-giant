--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Layout = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Layout)

describe("Layout.isPhone", function()
	it("is false on a 1280x720 computer screen", function()
		expect(Layout.isPhone(Vector2.new(1280, 720))).toBe(false)
	end)

	it("is true on a 750x390 phone play area", function()
		expect(Layout.isPhone(Vector2.new(750, 390))).toBe(true)
	end)

	it("is true on a wide screen whose short side is under 500 (1280x390)", function()
		expect(Layout.isPhone(Vector2.new(1280, 390))).toBe(true)
	end)

	it("is true when the phone is held upright (390x750)", function()
		expect(Layout.isPhone(Vector2.new(390, 750))).toBe(true)
	end)

	it("is false when the short side is exactly 500", function()
		expect(Layout.isPhone(Vector2.new(900, 500))).toBe(false)
	end)

	it("is true when the short side is 499", function()
		expect(Layout.isPhone(Vector2.new(900, 499))).toBe(true)
	end)
end)

describe("Layout.forScreen", function()
	it("gives a 400x62 meter on a 1280x720 screen", function()
		local layout = Layout.forScreen(Vector2.new(1280, 720))
		expect(layout.phone).toBe(false)
		expect(layout.meter.width).toBe(400)
		expect(layout.meter.height).toBe(62)
	end)

	it("gives a 260x46 meter with a 14 px label on a 750x390 screen", function()
		local layout = Layout.forScreen(Vector2.new(750, 390))
		expect(layout.phone).toBe(true)
		expect(layout.meter.width).toBe(260)
		expect(layout.meter.height).toBe(46)
		expect(layout.meter.labelTextSize).toBe(14)
	end)

	it("gives a 260x46 meter on a 1280x390 screen", function()
		local layout = Layout.forScreen(Vector2.new(1280, 390))
		expect(layout.meter.width).toBe(260)
		expect(layout.meter.height).toBe(46)
	end)

	it("never uses text under 14 px on a phone", function()
		local meter = Layout.forScreen(Vector2.new(750, 390)).meter
		expect(meter.labelTextSize >= 14).toBe(true)
		expect(meter.lockTextSize >= 14).toBe(true)
	end)
end)

describe("Layout.forScreen: the Tiptoe button", function()
	it("is 92 px round with a 17 px word and the key shown on a 1280x720 computer screen", function()
		local tiptoe = Layout.forScreen(Vector2.new(1280, 720)).tiptoe
		expect(tiptoe.diameter).toBe(92)
		expect(tiptoe.wordTextSize).toBe(17)
		expect(tiptoe.emojiTextSize).toBe(36)
		expect(tiptoe.keyTextSize).toBe(13)
		expect(tiptoe.showKey).toBe(true)
	end)

	it("is 60 px round with a 14 px word and no key on a 750x390 phone screen", function()
		local tiptoe = Layout.forScreen(Vector2.new(750, 390)).tiptoe
		expect(tiptoe.diameter).toBe(60)
		expect(tiptoe.wordTextSize).toBe(14)
		expect(tiptoe.emojiTextSize).toBe(22)
		expect(tiptoe.showKey).toBe(false)
	end)

	it("is the phone size on a wide but short 1280x390 screen", function()
		expect(Layout.forScreen(Vector2.new(1280, 390)).tiptoe.diameter).toBe(60)
	end)

	it("never uses text under 14 px on a phone", function()
		local tiptoe = Layout.forScreen(Vector2.new(750, 390)).tiptoe
		expect(tiptoe.wordTextSize >= 14).toBe(true)
		expect(tiptoe.emojiTextSize >= 14).toBe(true)
	end)

	it("has the mockup's outline, shadow and lit-up ring on both sizes", function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(750, 390) } do
			local tiptoe = Layout.forScreen(size).tiptoe
			expect(tiptoe.borderThickness).toBe(4)
			expect(tiptoe.shadowOffset).toBe(6)
			expect(tiptoe.onThickness).toBe(5)
			expect(tiptoe.onGap).toBe(2)
			expect(tiptoe.rightMargin).toBe(18)
		end
	end)
end)

describe("Layout.forScreen: the Tiptoe orange glow", function()
	it("is 10 px wide on a computer screen and 6 px wide on a phone screen", function()
		expect(Layout.forScreen(Vector2.new(1280, 720)).tiptoe.glowThickness).toBe(10)
		expect(Layout.forScreen(Vector2.new(750, 390)).tiptoe.glowThickness).toBe(6)
	end)
end)

describe("Layout.meterCenterX", function()
	local PULSE = 1.1

	it("keeps the meter centred on a 1280 screen with Roblox's buttons ending at 164", function()
		expect(Layout.meterCenterX(1280, 400, 164, PULSE)).toBe(640)
	end)

	it("keeps the meter centred on a 750 phone screen with the buttons ending at 164", function()
		expect(Layout.meterCenterX(750, 260, 164, PULSE)).toBe(375)
	end)

	it("keeps the meter centred when there are no buttons at all", function()
		expect(Layout.meterCenterX(750, 260, 0, PULSE)).toBe(375)
	end)

	it(
		"slides right on a very small 568 screen, just enough to stay 8 px from the buttons at the pulse size",
		function()
			-- At the pulse the meter is 286 wide, so its centre is 164 + 8 + 143 from the left edge.
			expect(Layout.meterCenterX(568, 260, 164, PULSE)).toBeCloseTo(315, 5)
		end
	)

	it("slides right when extra buttons (voice chat) end at 250 on a 750 screen", function()
		expect(Layout.meterCenterX(750, 260, 250, PULSE)).toBeCloseTo(401, 5)
	end)

	it("stays centred when the pulse-sized meter is exactly 8 px from the buttons", function()
		-- Centred at 375 the pulse-sized meter's left edge is 375 - 143 = 232, which is 8 px from 224.
		expect(Layout.meterCenterX(750, 260, 224, PULSE)).toBe(375)
	end)

	it("slides as soon as the gap is under 8 px", function()
		expect(Layout.meterCenterX(750, 260, 225, PULSE) > 375).toBe(true)
	end)

	it("uses the pulse size, not the normal size, to keep clear", function()
		-- At the normal size the left edge is 245, 21 px from 224. Only the pulse size needs the slide to start.
		expect(Layout.meterCenterX(750, 260, 230, PULSE) > 375).toBe(true)
		expect(Layout.meterCenterX(750, 260, 230, 1) == 375).toBe(true)
	end)
end)

describe("Layout.forScreen: the grab prompt", function()
	it("has a 38 px key and 20 px text on a 1280x720 computer screen", function()
		local prompt = Layout.forScreen(Vector2.new(1280, 720)).prompt
		expect(prompt.keyDiameter).toBe(38)
		expect(prompt.keyTextSize).toBe(20)
		expect(prompt.textSize).toBe(20)
		expect(prompt.borderThickness).toBe(3)
	end)

	it("outlines its words in Ink so they stay readable over the fill, thinner on a phone", function()
		local computer = Layout.forScreen(Vector2.new(1280, 720)).prompt
		local phone = Layout.forScreen(Vector2.new(750, 390)).prompt
		expect(computer.textOutline).toBe(2)
		expect(phone.textOutline > 0).toBe(true)
		expect(phone.textOutline < computer.textOutline).toBe(true)
	end)

	it("has the phone's sizes on a 750x390 phone screen: 34 px key, 18 px letter, 16 px words", function()
		local prompt = Layout.forScreen(Vector2.new(750, 390)).prompt
		expect(prompt.keyDiameter).toBe(34)
		expect(prompt.keyTextSize).toBe(18)
		expect(prompt.textSize).toBe(16)
	end)

	it("has the phone's padding: 5 px top and bottom, 5 px left, 12 px right, 6 px gap", function()
		local prompt = Layout.forScreen(Vector2.new(750, 390)).prompt
		expect(prompt.paddingY).toBe(5)
		expect(prompt.paddingLeft).toBe(5)
		expect(prompt.paddingRight).toBe(12)
		expect(prompt.gap).toBe(6)
	end)

	it("floats the phone's pill in a 200x60 space", function()
		local prompt = Layout.forScreen(Vector2.new(750, 390)).prompt
		expect(prompt.billboardWidth).toBe(200)
		expect(prompt.billboardHeight).toBe(60)
	end)

	it("makes the phone's pill 44 px tall: the key plus the padding above and below", function()
		local prompt = Layout.forScreen(Vector2.new(750, 390)).prompt
		expect(prompt.keyDiameter + prompt.paddingY * 2).toBe(44)
		expect(prompt.billboardHeight >= 44).toBe(true)
	end)

	it("leaves the computer's pill as it was", function()
		local prompt = Layout.forScreen(Vector2.new(1280, 720)).prompt
		expect(prompt.paddingLeft).toBe(6)
		expect(prompt.paddingRight).toBe(14)
		expect(prompt.paddingY).toBe(6)
		expect(prompt.gap).toBe(8)
		expect(prompt.billboardWidth).toBe(240)
		expect(prompt.billboardHeight).toBe(70)
		expect(prompt.cornerRadius).toBe(14)
	end)
end)

describe("Layout.forScreen: the carry pill", function()
	it("has the mockup's 22 px text and 40x50 egg on a 1280x720 computer screen", function()
		local pill = Layout.forScreen(Vector2.new(1280, 720)).pill
		expect(pill.textSize).toBe(22)
		expect(pill.eggWidth).toBe(40)
		expect(pill.eggHeight).toBe(50)
		expect(pill.homeTextSize).toBe(22)
		expect(pill.bottomOffset).toBe(18)
	end)

	it("has 14 px text and a 24x30 egg on a 750x390 phone screen", function()
		local pill = Layout.forScreen(Vector2.new(750, 390)).pill
		expect(pill.textSize).toBe(14)
		expect(pill.eggWidth).toBe(24)
		expect(pill.eggHeight).toBe(30)
		expect(pill.homeTextSize >= 14).toBe(true)
	end)
end)

describe("Layout.forScreen: the bottom tip", function()
	it("has 24 px text on a 1280x720 computer screen", function()
		expect(Layout.forScreen(Vector2.new(1280, 720)).tip.textSize).toBe(24)
	end)

	it("has text of at least 14 px on a 750x390 phone screen", function()
		local tip = Layout.forScreen(Vector2.new(750, 390)).tip
		expect(tip.textSize >= 14).toBe(true)
		expect(tip.textSize < 24).toBe(true)
	end)

	it("sits at the same height as the carry pill on both screens", function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(750, 390) } do
			local layout = Layout.forScreen(size)
			expect(layout.tip.bottomOffset).toBe(layout.pill.bottomOffset)
		end
	end)
end)

describe("Layout.forScreen: the safe-home card", function()
	it("has the mockup's sizes on a 1280x720 computer screen", function()
		local card = Layout.forScreen(Vector2.new(1280, 720)).card
		expect(card.top).toBe(96)
		expect(card.textSize).toBe(24)
		expect(card.eggHeight).toBe(40)
		expect(card.paddingLeft).toBe(10)
		expect(card.paddingRight).toBe(22)
		expect(card.paddingY).toBe(8)
		expect(card.gap).toBe(12)
		expect(card.borderThickness).toBe(4)
		expect(card.shadowOffset).toBe(6)
		expect(card.cornerRadius).toBe(20)
	end)

	it("sits 62 px down with 14 px text and a 26 px egg on a 750x390 phone screen", function()
		local card = Layout.forScreen(Vector2.new(750, 390)).card
		expect(card.top).toBe(62)
		expect(card.textSize).toBe(14)
		expect(card.eggHeight).toBe(26)
	end)

	it("shrinks the phone card's padding to about 0.62 times the computer's", function()
		local computer = Layout.forScreen(Vector2.new(1280, 720)).card
		local phone = Layout.forScreen(Vector2.new(750, 390)).card
		for _, name in { "paddingLeft", "paddingRight", "paddingY", "gap", "cornerRadius" } do
			expect(math.abs((phone :: any)[name] - 0.62 * (computer :: any)[name]) <= 0.5).toBe(true)
		end
	end)

	it("never uses text under 14 px", function()
		expect(Layout.forScreen(Vector2.new(750, 390)).card.textSize >= 14).toBe(true)
	end)

	it("starts below the meter on both screens (the mockup lets it touch the meter's shadow)", function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(750, 390) } do
			local layout = Layout.forScreen(size)
			expect(layout.card.top >= layout.meter.topOffset + layout.meter.height).toBe(true)
		end
	end)
end)

describe("Layout.forScreen: the wake banner", function()
	it("is low and right of centre on a computer: bottom 100 px up, middle at 66% of the width", function()
		local banner = Layout.forScreen(Vector2.new(1280, 720)).banner
		expect(banner.bottomOffset).toBe(100)
		expect(banner.centerX).toBe(0.66)
	end)

	it("has the mockup's sizes on a computer: 34 px words, a 17 px second line, padding 10 and 28", function()
		local banner = Layout.forScreen(Vector2.new(1280, 720)).banner
		expect(banner.textSize).toBe(34)
		expect(banner.secondTextSize).toBe(17)
		expect(banner.showSecondLine).toBe(true)
		expect(banner.paddingY).toBe(10)
		expect(banner.paddingX).toBe(28)
		expect(banner.borderThickness).toBe(5)
		expect(banner.shadowOffset).toBe(7)
		expect(banner.cornerRadius).toBe(18)
		expect(banner.rotation).toBe(-2)
	end)

	it("has outlines on the words that fit their size on a computer", function()
		local banner = Layout.forScreen(Vector2.new(1280, 720)).banner
		expect(banner.textOutline).toBe(3)
		expect(banner.secondTextOutline).toBe(2)
		expect(banner.gap).toBe(8)
		expect(banner.secondGap).toBe(2)
	end)

	it(
		"is low and right of centre on a phone too, where it stays clear of his eyes: bottom 100 px up, 66% across",
		function()
			-- At landing spot 6, mid-float, a banner under the sleep meter covered his eyes on the iPhone 14.
			local banner = Layout.forScreen(Vector2.new(750, 390)).banner
			expect(banner.bottomOffset).toBe(100)
			expect(banner.centerX).toBe(0.66)
		end
	)

	it("is small on a phone: one line of 14 px words, padding 4 and 12, outline 3, shadow 5, corner 13", function()
		local banner = Layout.forScreen(Vector2.new(750, 390)).banner
		expect(banner.textSize).toBe(14)
		expect(banner.showSecondLine).toBe(false)
		expect(banner.paddingY).toBe(4)
		expect(banner.paddingX).toBe(12)
		expect(banner.borderThickness).toBe(3)
		expect(banner.shadowOffset).toBe(5)
		expect(banner.cornerRadius).toBe(13)
		expect(banner.rotation).toBe(-2)
	end)

	it("never uses text under 14 px, on either screen", function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(750, 390) } do
			local banner = Layout.forScreen(size).banner
			expect(banner.textSize >= 14).toBe(true)
			expect(banner.secondTextSize >= 14).toBe(true)
		end
	end)

	it("leaves the green card where it is: the banner never stands in its place", function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(750, 390) } do
			local layout = Layout.forScreen(size)
			expect((layout.banner :: any).cardShift).toBeNil()
			expect((layout.banner :: any).onTop).toBeNil()
		end
	end)
end)

describe("Layout.forScreen: the Caught! card", function()
	it("stands bottom left of centre on a computer: middle at 30% of the width, bottom 22 px up", function()
		local caught = Layout.forScreen(Vector2.new(1280, 720)).caught
		expect(caught.centerX).toBe(0.3)
		expect(caught.bottomOffset).toBe(22)
	end)

	it("stands bottom centre on a phone: middle at 50% of the width, bottom 14 px up", function()
		local caught = Layout.forScreen(Vector2.new(750, 390)).caught
		expect(caught.centerX).toBe(0.5)
		expect(caught.bottomOffset).toBe(14)
	end)

	it(
		"has the mockup's sizes on a computer: 24 px words, a 15 px second line, a 40 px emoji, padding 8 and 10 and 22",
		function()
			local caught = Layout.forScreen(Vector2.new(1280, 720)).caught
			expect(caught.textSize).toBe(24)
			expect(caught.secondTextSize).toBe(15) -- 0.62 of 24, rounded
			expect(caught.emojiTextSize).toBe(40)
			expect(caught.paddingY).toBe(8)
			expect(caught.paddingLeft).toBe(10)
			expect(caught.paddingRight).toBe(22)
			expect(caught.gap).toBe(12)
			expect(caught.borderThickness).toBe(4)
			expect(caught.shadowOffset).toBe(6)
			expect(caught.cornerRadius).toBe(20)
		end
	)

	it("has the green card's phone sizes on a phone: 14 px words, a 26 px emoji, padding 5 and 6 and 14", function()
		local caught = Layout.forScreen(Vector2.new(750, 390)).caught
		expect(caught.textSize).toBe(14)
		expect(caught.secondTextSize).toBe(14)
		expect(caught.emojiTextSize).toBe(26)
		expect(caught.paddingY).toBe(5)
		expect(caught.paddingLeft).toBe(6)
		expect(caught.paddingRight).toBe(14)
		expect(caught.gap).toBe(7)
		expect(caught.borderThickness).toBe(3)
		expect(caught.shadowOffset).toBe(4)
		expect(caught.cornerRadius).toBe(12)
	end)

	it("never uses text under 14 px, on either screen", function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(750, 390) } do
			local caught = Layout.forScreen(size).caught
			expect(caught.textSize >= 14).toBe(true)
			expect(caught.secondTextSize >= 14).toBe(true)
			expect(caught.emojiTextSize >= 14).toBe(true)
		end
	end)

	it("is the same on a phone held the other way up", function()
		expect(Layout.forScreen(Vector2.new(390, 750)).caught.centerX).toBe(0.5)
	end)
end)
